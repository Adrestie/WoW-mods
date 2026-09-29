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

"""Minimal reader for the modern client's .db2 tables (WDC5 format).

Returns each row's id and the raw list of its fields; a text field returns its string.
Storage kinds handled: none, bitpacked, bitpacked signed, common data, pallet, pallet array.
Encrypted or sparse tables (flag 1) are not handled.
"""
import io
import struct


def _bits(data, start_byte, bit_offset, bit_count):
    byte = start_byte + bit_offset // 8
    n = (bit_offset % 8 + bit_count + 7) // 8
    raw = int.from_bytes(data[byte:byte + n], "little")
    return (raw >> (bit_offset % 8)) & ((1 << bit_count) - 1)


# text_fields: indexes of the fields that hold a string offset
def read(path, text_fields=()):
    d = io.open(path, "rb").read()
    if d[:4] != b"WDC5":
        raise ValueError("pas un WDC5 : %s" % path)
    o = 4 + 4 + 128
    (count, field_count, row_size, strings_size, _, _, _, _, _) = struct.unpack_from("<9I", d, o)
    o += 36
    flags, id_index = struct.unpack_from("<HH", d, o)
    o += 4
    (total_fields, _, _, storage_size, common_size, palette_size, section_count) = struct.unpack_from("<7I", d, o)
    o += 28
    if flags & 1:
        raise ValueError("table eparse non geree")
    sections = []
    for _ in range(section_count):
        sections.append(struct.unpack_from("<QIIIIIIII", d, o))
        o += 40
    o += 4 * field_count
    storage = [struct.unpack_from("<HHIIIII", d, o + 24 * i) for i in range(total_fields)]
    o += storage_size
    palette = d[o:o + palette_size]
    o += palette_size
    raw_common = d[o:o + common_size]
    o += common_size

    # Split the pallet and common data per field.
    pal, com = [], []
    p = c = 0
    for (_, _, extra, kind, v1, v2, v3) in storage:
        if kind in (3, 4):
            pal.append(p)
            p += extra
        else:
            pal.append(None)
        if kind == 2:
            table = {}
            for k in range(extra // 8):
                ident, val = struct.unpack_from("<II", raw_common, c + 8 * k)
                table[ident] = val
            com.append(table)
            c += extra
        else:
            com.append(None)

    rows = []
    for (_, start, n, _, _, ids_size, _, _, copy_count) in sections:
        ids = []
        rows_end = start + n * row_size
        strings_end = rows_end + strings_size
        if ids_size:
            ids = list(struct.unpack_from("<%dI" % (ids_size // 4), d, strings_end))
        copies_start = strings_end + ids_size
        for i in range(n):
            base = start + i * row_size
            values = []
            for k, (bits, nbits, extra, kind, v1, v2, v3) in enumerate(storage):
                if kind == 0:
                    byte = bits // 8
                    v = int.from_bytes(d[base + byte: base + byte + nbits // 8], "little")
                    if k in text_fields:
                        pos = base + byte + v
                        v = d[pos:d.index(b"\x00", pos)].decode("utf-8", "replace")
                elif kind in (1, 5):
                    v = _bits(d, base, bits, nbits)
                    if kind == 5 and v & (1 << (nbits - 1)):
                        v -= 1 << nbits
                elif kind == 2:
                    v = None  # filled below, by record id
                elif kind == 3:
                    idx = _bits(d, base, bits, nbits)
                    v = struct.unpack_from("<I", palette, pal[k] + 4 * idx)[0]
                elif kind == 4:
                    idx = _bits(d, base, bits, nbits)
                    v = list(struct.unpack_from("<%dI" % v3, palette, pal[k] + 4 * idx * v3))
                else:
                    raise ValueError("stockage %d non gere" % kind)
                values.append(v)
            ident = ids[i] if ids else values[id_index]
            for k, (bits, nbits, extra, kind, v1, v2, v3) in enumerate(storage):
                if kind == 2:
                    values[k] = com[k].get(ident, v1)
            rows.append((ident, values))
        # Copy table: (new id, copied id)
        by_id = dict(rows)
        for j in range(copy_count):
            new, old = struct.unpack_from("<II", d, copies_start + 8 * j)
            if old in by_id:
                rows.append((new, list(by_id[old])))
    return rows
