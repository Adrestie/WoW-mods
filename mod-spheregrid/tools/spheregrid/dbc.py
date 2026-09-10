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
    # Almost every table of 3.3.5a is fields x 4 bytes. SpellChainEffects is
    # not: five single-byte fields sit in the middle of its 177 bytes, and
    # the fields after them are not aligned. Records are carried as bytes,
    # and a field is read at index x 4 wherever that lands inside the record
    # -- which is all the tools need: the identifier, and a texture path.
    if fields * 4 != size and not (fields * 4 > size > (fields - 8) * 4):
        raise ValueError("%s: %d fields do not fill %d bytes"
                         % (path, fields, size))
    start = HEADER.size
    records = [raw[start + i * size: start + (i + 1) * size] for i in range(count)]
    strings = raw[start + count * size: start + count * size + string_size]
    if len(strings) != string_size:
        raise ValueError("%s: string block truncated" % path)
    return Dbc(fields, size, records, strings)


def to_bytes(dbc):
    """The file a DBC would be written to, as bytes.

    A caller that must decide whether to write at all -- a shift, which is
    all of it or none of it -- builds the files first and lays them down
    afterwards.
    """
    return b"".join([HEADER.pack(MAGIC, len(dbc.records), dbc.field_count,
                                 dbc.record_size, len(dbc.strings))]
                    + list(dbc.records) + [dbc.strings])


def write(path, dbc):
    with open(path, "wb") as f:
        f.write(to_bytes(dbc))


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
    # A field past the record's end -- SpellChainEffects's unaligned tail --
    # cannot be read as four bytes, and is no string anyway.
    for index in range(1, min(dbc.field_count, dbc.record_size // 4)):
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


# WHERE THE FORM IS KNOWN, IT IS SAID RATHER THAN GUESSED.
#
# `string_fields` asks that a field be a valid offset in EVERY record. That is
# strong evidence on a whole file and weak on a small one: in a string block
# of thirty bytes, an integer worth 1 is a valid offset, and a merge would
# then read that integer as a text and rewrite it. It errs on whole files too
# -- ItemDisplayInfo's GeosetGroup_3 is only ever 0 or 1, and 1 is a valid
# offset in any block.
#
# The tables the module merges into a client have a fixed, known form, so it
# is written down here once. Read from the 3.3.5a layouts, checked against
# the reference client's own files (tens of thousands of rows each) and,
# where the core reads them, against its format strings (`DBCfmt.h`): the
# core marks Spell's Name and NameSubtext as sixteen strings each, and
# ItemDisplayInfo's InventoryIcon_1 as one.
#
# An empty set is a table with no string at all, and says so on purpose.
KNOWN_STRING_FIELDS = {
    # four texts of sixteen locales each, every one followed by its mask
    "Spell.dbc": (set(range(136, 152)) | set(range(153, 169))
                  | set(range(170, 186)) | set(range(187, 203))),
    "Item.dbc": set(),
    # ModelName x2, ModelTexture x2, InventoryIcon x2, then Texture x8
    "ItemDisplayInfo.dbc": {1, 2, 3, 4, 5, 6} | set(range(15, 23)),
    "SpellIcon.dbc": {1},
    "SpellVisual.dbc": set(),
    "SpellVisualKit.dbc": set(),
    "SpellVisualEffectName.dbc": {1, 2},          # the name, and the model
    # the name, ten files, and the folder holding them
    "SoundEntries.dbc": {2} | set(range(3, 13)) | {23},
    "SpellDuration.dbc": set(),
    "CreatureDisplayInfo.dbc": {6, 7, 8, 9},      # three skins and a portrait
    "CreatureModelData.dbc": {2},                 # the model
    "GameObjectDisplayInfo.dbc": {1},             # the model
    "Emotes.dbc": {1},                            # the slash command
    "SpellChainEffects.dbc": {7},                 # the beam's texture
}


def string_fields_of(name, dbc):
    """The string fields of a table known by its file name -- declared when
    the file is one the heuristic must not be trusted on, deduced otherwise."""
    known = KNOWN_STRING_FIELDS.get(name.replace("spheregrid_", ""))
    return set(known) if known is not None else string_fields(dbc)


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


def derive(source, from_id, new_id, strings_at, ints=None, strings=None,
           bytes_at=None):
    """A copy of one record under a new identifier, some fields changed.

    A MODULE MAY NEED A ROW THE GAME DOES NOT HAVE: a visual that is the
    game's meteor with a fire cast in front of it, a display that is one of
    ours wearing another model. Rather than hand-write thirty-two fields, the
    row is derived from the one it is nearest to -- a row of the game or of
    the module -- and only what differs is said: `ints` maps a field index to
    a 32 bit value, `strings` a field index to a text, and `bytes_at` a BYTE
    OFFSET to a byte -- for the few tables, SpellChainEffects among them,
    whose fields are not all four bytes wide. The text is added to the block;
    nothing else in the block moves.

    The record joins the table in identifier order. A `new_id` already in the
    table is a mistake, and is reported rather than doubled.
    """
    if new_id in set(source.ids()):
        raise ValueError("identifier %d is already in the table" % new_id)
    rows = source.by_id()
    if from_id not in rows:
        raise ValueError("no record %d to derive from" % from_id)
    record = bytearray(rows[from_id])
    block = bytearray(source.strings)
    struct.pack_into("<I", record, 0, new_id)
    for index, value in sorted((ints or {}).items()):
        struct.pack_into("<I", record, index * 4, int(value) & 0xFFFFFFFF)
    for offset, value in sorted((bytes_at or {}).items()):
        record[offset] = int(value) & 0xFF
    for index, text in sorted((strings or {}).items()):
        if index not in strings_at:
            raise ValueError("field %d is not a string field" % index)
        offset = len(block)
        block += text.encode("utf-8") + b"\0"
        struct.pack_into("<I", record, index * 4, offset)
    out = list(source.records) + [bytes(record)]
    out.sort(key=lambda r: struct.unpack_from("<I", r, 0)[0])
    return Dbc(source.field_count, source.record_size, out, bytes(block))


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
