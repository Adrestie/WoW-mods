# -*- coding: utf-8 -*-
# This file is part of mod-spheregrid.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

"""Reading and writing WDBC files, the client database format of 3.3.5a.

A DBC is four header integers, then fixed size records, then one block of
NUL terminated strings. A record holds only integers, floats and OFFSETS INTO
THAT BLOCK -- a string field is an offset, never text.

Which fields are offsets is not written anywhere in the file, and the core's own
format strings do not say either: they mark with `x` every field they ignore,
and some of those are strings (the spell description and tooltip, for instance).
So the layout is DEDUCED from the file, by `string_fields` below, and the
deduction is checked against thousands of records before it is trusted.
"""
import struct

MAGIC = b"WDBC"
HEADER = struct.Struct("<4sIIII")


class Dbc(object):
    """One DBC in memory: its records, and the block their strings live in."""

    def __init__(self, field_count, record_size, records, strings):
        self.field_count = field_count
        self.record_size = record_size
        self.records = records          # list of bytes, one per record
        self.strings = strings          # the string block, verbatim

    def __len__(self):
        return len(self.records)

    def field(self, record, index):
        """The raw 32 bit value of one field, unsigned."""
        return struct.unpack_from("<I", record, index * 4)[0]

    def ids(self):
        """The identifier of every record. Field 0, in every DBC of 3.3.5a."""
        return [self.field(r, 0) for r in self.records]

    def by_id(self):
        return dict(zip(self.ids(), self.records))


def read(path):
    with open(path, "rb") as f:
        raw = f.read()
    magic, count, fields, size, string_size = HEADER.unpack_from(raw, 0)
    if magic != MAGIC:
        raise ValueError("%s is not a DBC (magic %r)" % (path, magic))
    if fields * 4 != size:
        raise ValueError("%s: %d fields do not fill %d bytes"
                         % (path, fields, size))
    start = HEADER.size
    records = [raw[start + i * size: start + (i + 1) * size] for i in range(count)]
    strings = raw[start + count * size: start + count * size + string_size]
    if len(strings) != string_size:
        raise ValueError("%s: string block truncated" % path)
    return Dbc(fields, size, records, strings)


def write(path, dbc):
    with open(path, "wb") as f:
        f.write(HEADER.pack(MAGIC, len(dbc.records), dbc.field_count,
                            dbc.record_size, len(dbc.strings)))
        for r in dbc.records:
            f.write(r)
        f.write(dbc.strings)


def string_fields(dbc):
    """Which fields hold an offset into the string block.

    A field qualifies only if EVERY record agrees: the value is inside the
    block, and the byte before it terminates the previous string -- which is
    what an offset always satisfies and what an ordinary number satisfies only
    by accident. Field 0 is the identifier and never a string.

    A field that is zero in every record is left out: nothing distinguishes it
    from an unused integer, and it costs nothing either way.

    SO THE ANSWER DEPENDS ON THE FILE, and a partial file gives a smaller one:
    the module's own 498 spells prove 62 of the 64 string fields, the two others
    being empty in all of them. Whoever merges a partial file into a full one
    must therefore detect on the FULL file and read the partial one with that
    answer -- which is right in both directions, an empty field being offset 0
    in either.
    """
    size = len(dbc.strings)
    out = set()
    for index in range(1, dbc.field_count):
        seen = False
        for record in dbc.records:
            value = dbc.field(record, index)
            if value == 0:
                continue
            if value >= size or dbc.strings[value - 1] != 0:
                break
            seen = True
        else:
            if seen:
                out.add(index)
    return out


def read_string(dbc, record, index):
    offset = dbc.field(record, index)
    end = dbc.strings.index(b"\0", offset)
    return dbc.strings[offset:end].decode("utf-8", "replace")


def concat(parts, strings_at):
    """One DBC from several of the same shape, sorted by identifier.

    Each part carries its own string block, so the offsets of one mean nothing
    in another: the block is built afresh and every offset rewritten. Two rows
    with the same identifier would be a mistake upstream, and it is reported
    rather than silently kept.
    """
    parts = [p for p in parts if len(p)]
    if not parts:
        raise ValueError("nothing to join")
    first = parts[0]
    for p in parts[1:]:
        if (p.field_count, p.record_size) != (first.field_count, first.record_size):
            raise ValueError("these DBC do not have the same shape")

    seen, rows = set(), []
    for part in parts:
        for record in part.records:
            identifier = part.field(record, 0)
            if identifier in seen:
                raise ValueError("identifier %d appears twice" % identifier)
            seen.add(identifier)
            rows.append((identifier, part, record))
    rows.sort(key=lambda t: t[0])

    block = bytearray(b"\0")
    placed = {b"": 0}
    out = []
    for _, part, record in rows:
        record = bytearray(record)
        for index in sorted(strings_at):
            offset = struct.unpack_from("<I", record, index * 4)[0]
            end = part.strings.index(b"\0", offset)
            text = bytes(part.strings[offset:end])
            if text not in placed:
                placed[text] = len(block)
                block += text + b"\0"
            struct.pack_into("<I", record, index * 4, placed[text])
        out.append(bytes(record))

    return Dbc(first.field_count, first.record_size, out, bytes(block))


def build(field_count, rows, floats_at, strings_at):
    """A DBC from plain Python values, one list per record.

    A field is a float where it is said to be, an offset where the value is a
    string, and a 32 bit integer otherwise -- negative values included, which
    the format stores as they are.
    """
    block = bytearray(b"\0")
    placed = {"": 0}
    out = []
    for values in rows:
        if len(values) != field_count:
            raise ValueError("a record of %d fields, expected %d"
                             % (len(values), field_count))
        record = bytearray(field_count * 4)
        for index, value in enumerate(values):
            if index in strings_at:
                text = value or ""
                if text not in placed:
                    placed[text] = len(block)
                    block += text.encode("utf-8") + b"\0"
                struct.pack_into("<I", record, index * 4, placed[text])
            elif index in floats_at:
                struct.pack_into("<f", record, index * 4, float(value or 0))
            else:
                # Four bytes hold either sign, and the format does not say
                # which: a base point is negative, a locale mask fills the
                # word. Both are written as they are.
                struct.pack_into("<I", record, index * 4,
                                 int(value or 0) & 0xFFFFFFFF)
        out.append(bytes(record))
    return Dbc(field_count, field_count * 4, out, bytes(block))


def subset(dbc, ids, strings_at):
    """A new DBC holding only the records named, and only the strings they use.

    Keeping the original block would be correct but absurd: the one in
    Spell.dbc weighs tens of megabytes, and a handful of records reference a
    few kilobytes of it. So the block is rebuilt, and the offsets with it.
    """
    wanted = set(ids)
    # A hand-edited DBC can hold the same identifier twice, and a client that
    # meets one keeps whichever it read last. So does this -- and it says so,
    # because carrying an ambiguity forward is worse than resolving it.
    kept, seen = [], {}
    for record in dbc.records:
        identifier = dbc.field(record, 0)
        if identifier not in wanted:
            continue
        if identifier in seen:
            kept[seen[identifier]] = record
        else:
            seen[identifier] = len(kept)
            kept.append(record)

    block = bytearray(b"\0")          # offset 0 is the empty string, always
    placed = {b"": 0}
    out = []
    for record in kept:
        record = bytearray(record)
        for index in sorted(strings_at):
            offset = struct.unpack_from("<I", record, index * 4)[0]
            end = dbc.strings.index(b"\0", offset)
            text = bytes(dbc.strings[offset:end])
            if text not in placed:
                placed[text] = len(block)
                block += text + b"\0"
            struct.pack_into("<I", record, index * 4, placed[text])
        out.append(bytes(record))

    return Dbc(dbc.field_count, dbc.record_size, out, bytes(block))


def renumber(source, mapping):
    """A copy where each record takes the identifier the mapping gives it.

    A MODULE MUST NOT REWRITE A ROW OF THE GAME. When it needs one of the
    game's rows changed -- a game object display turned into a portal, a visual
    kit given another effect -- it ships a COPY under an identifier of its own
    and points its own rows at the copy. The game keeps its row, and two
    servers running two modules do not fight over it.

    Field 0 is the identifier in every DBC of 3.3.5a. Nothing else is touched:
    the string block is carried over as it stands.
    """
    out = []
    for record in source.records:
        identifier = struct.unpack_from("<I", record, 0)[0]
        if identifier in mapping:
            record = bytearray(record)
            struct.pack_into("<I", record, 0, mapping[identifier])
            record = bytes(record)
        out.append(record)
    out.sort(key=lambda r: struct.unpack_from("<I", r, 0)[0])
    return Dbc(source.field_count, source.record_size, out, source.strings)


def rename_strings(source, strings_at, changes):
    """A copy where the strings named on the left become the ones on the right.

    A DBC path is data like any other, and some of it has to be renamed when a
    module changes hands -- a model that carried one server's name cannot ship
    under it. Doing the rename HERE rather than on the shipped file means a
    regeneration cannot quietly undo it.

    The comparison ignores case and slash direction, because a client is
    indifferent to both and the sources are not.
    """
    def key(text):
        return text.lower().replace("/", "\\")

    wanted = {key(a): b for a, b in changes.items()}
    seen = set()

    block = bytearray(b"\0")
    placed = {b"": 0}
    out = []
    for record in source.records:
        record = bytearray(record)
        for index in sorted(strings_at):
            offset = struct.unpack_from("<I", record, index * 4)[0]
            end = source.strings.index(b"\0", offset)
            text = bytes(source.strings[offset:end])
            replacement = wanted.get(key(text.decode("utf-8", "replace")))
            if replacement is not None:
                seen.add(key(text.decode("utf-8", "replace")))
                text = replacement.encode("utf-8")
            if text not in placed:
                placed[text] = len(block)
                block += text + b"\0"
            struct.pack_into("<I", record, index * 4, placed[text])
        out.append(bytes(record))

    missed = sorted(set(wanted) - seen)
    if missed:
        raise ValueError("nothing to rename: %s" % ", ".join(missed))
    return Dbc(source.field_count, source.record_size, out, bytes(block))
