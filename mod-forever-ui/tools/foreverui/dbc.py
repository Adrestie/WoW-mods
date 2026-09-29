# -*- coding: utf-8 -*-
# This file is part of mod-forever-ui.
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
#
# The DBC row functions follow the shared installer of the WoW-mods repository
# (mod-item-upgrade/installer/noyau.py, MIT license): append our rows, remove only
# ours, leave the rest intact.

"""Add and remove a module's own rows in a DBC file.

ADD: the module's rows are first removed if present (with their strings), then appended;
their strings go to the end of the string block. Adding twice gives the same bytes.
REMOVE: only the module's rows go; the string block is cut after the last string a
remaining row uses. Nothing to remove: the original file is returned byte for byte.
"""
import struct


class Rows(object):
    """A module's rows in a DBC: field count, indices of the string fields,
    rows (integers or strings; an empty string is 0).
    """

    def __init__(self, fields, text_fields, rows):
        self.fields = fields
        self.text_fields = list(text_fields)
        self.rows = [list(l) for l in rows]
        self.ids = [l[0] for l in self.rows]
        for l in self.rows:
            if len(l) != fields:
                raise ValueError("ligne %s : %d champs au lieu de %d" % (l[0], len(l), fields))


# Split a DBC into (field count, rows as bytes, string block). name: file name for errors.
def cut(raw, name):
    if raw[:4] != b"WDBC":
        raise ValueError("%s n'est pas un DBC (signature WDBC absente)" % name)
    count, fields, size, string_block_size = struct.unpack_from("<4I", raw, 4)
    if size != fields * 4 or len(raw) < 20 + count * size + string_block_size:
        raise ValueError("%s : en-tete DBC incoherent" % name)
    rows = [raw[20 + i * size:20 + (i + 1) * size] for i in range(count)]
    start = 20 + count * size
    return fields, rows, bytearray(raw[start:start + string_block_size])


def assemble(fields, rows, strings):
    return b"WDBC" + struct.pack("<4I", len(rows), fields, fields * 4, len(strings)) + \
        b"".join(rows) + bytes(strings)


def _id(row):
    return struct.unpack_from("<I", row)[0]


# Number of rows in the DBC whose id is in ids.
def tally(raw, name, ids):
    ids = set(ids)
    return sum(1 for l in cut(raw, name)[1] if _id(l) in ids)


# Return the DBC with the rows of d (a Rows) appended. name: file name for errors.
def add(raw, name, d):
    # Remove fully first, strings included: otherwise old strings stay in the block
    # and it grows on each run. Adding twice then gives the same bytes.
    raw, _ = remove(raw, name, d)
    fields, rows, strings = cut(raw, name)
    if fields != d.fields:
        raise ValueError("%s a %d champs, %d attendus : version de client inattendue" % (name, fields, d.fields))
    for values in d.rows:
        rec = []
        for v in values:
            if isinstance(v, str):
                if not v:
                    rec.append(0)
                    continue
                if not strings:
                    strings.extend(b"\0")          # offset 0 is the empty string
                rec.append(len(strings))
                strings.extend(v.encode("utf-8") + b"\0")
            else:
                rec.append(int(v) & 0xFFFFFFFF)
        rows.append(struct.pack("<%dI" % fields, *rec))
    return assemble(fields, rows, strings)


def remove(raw, name, d):
    """Return (DBC without the module's rows, number of rows removed)."""
    fields, rows, strings = cut(raw, name)
    ids = set(d.ids)
    keep = [l for l in rows if _id(l) not in ids]
    n = len(rows) - len(keep)
    if not n:
        return raw, 0
    if d.text_fields and strings:
        finish = 1
        for l in keep:
            values = struct.unpack_from("<%dI" % fields, l)
            for c in d.text_fields:
                off = values[c]
                if 0 < off < len(strings):
                    zero = strings.find(b"\0", off)
                    finish = max(finish, (zero if zero >= 0 else len(strings) - 1) + 1)
        strings = strings[:finish]
    return assemble(fields, keep, strings), n
