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

"""Print the nine-slice margins of camelot client atlas elements.

The camelot engine nine-slices an atlas stretched over a rectangle when the atlas has
margins. They live in the client tables, not in the code; without them the whole image
stretches and its corners deform.

Usage: python tools/atlas_slices.py questlog-frame common-dropdown-bg
Export both tables through the wow.export bridge:
  /export?file=dbfilesclient/uitextureatlaselement.db2
  /export?file=dbfilesclient/uitextureatlaselementslicedata.db2
Output: [id, element, left, top, right, bottom, mode]. Margin order matches
common-dropdown-bg (16, 13, 16, 19: the shadow is at the bottom).
"""
import struct
import sys

BASE = r"C:\Users\Arthe\wow.export\dbfilesclient\%s.db2"


# Parse a db2 header: record count, field count, record size, sections, fields,
# field storage info.
def header(d):
    pos = 4 + 4 + 128
    rc, fc, rs, sts, th, lh, mn, mx, loc = struct.unpack_from("<IIIIIIIII", d, pos); pos += 36
    fl, ii = struct.unpack_from("<HH", d, pos); pos += 4
    tfc, bdo, lcc, fsis, cds, pds, sc = struct.unpack_from("<IIIIIII", d, pos); pos += 28
    secs = []
    for _ in range(sc):
        secs.append(struct.unpack_from("<QIIIIIIII", d, pos)); pos += 40
    fields = [struct.unpack_from("<hH", d, pos + 4 * i) for i in range(fc)]; pos += 4 * fc
    infos = [struct.unpack_from("<HHIIIII", d, pos + 24 * i) for i in range(fsis // 24)]
    return rc, fc, rs, secs, fields, infos


# Element names
d = open(BASE % "uitextureatlaselement", "rb").read()
rc, fc, rs, secs, fields, infos = header(d)
names = {}
base = secs[0][1]
for r in range(rc):
    ro = base + r * rs
    v, = struct.unpack_from("<I", d, ro)
    p = ro + v
    e = d.find(b"\x00", p)
    ident, = struct.unpack_from("<I", d, ro + 4)
    names[ident] = d[p:e].decode("utf-8", "replace")
by_name = {v.lower(): k for k, v in names.items()}

# Slice margins
d = open(BASE % "uitextureatlaselementslicedata", "rb").read()
rc, fc, rs, secs, fields, infos = header(d)
base = secs[0][1]
slices = {}
for r in range(rc):
    ro = base + r * rs
    bits = int.from_bytes(d[ro:ro + rs], "little")
    vals = []
    for (offbits, nbits, add, typ, a, b, c) in infos:
        v = (bits >> offbits) & ((1 << nbits) - 1)
        if typ == 5 and v >> (nbits - 1):
            v -= 1 << nbits
        vals.append(v)
    slices[vals[1]] = vals

for name in sys.argv[1:]:
    ident = by_name.get(name.lower())
    print("%-40s element %s -> %s" % (name, ident, slices.get(ident)))
