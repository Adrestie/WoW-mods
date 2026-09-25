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

"""Marges de decoupe en neuf des atlas du client camelot.

POURQUOI. Le moteur de camelot decoupe lui-meme en neuf un atlas pose sur
un rectangle quand l'atlas a des marges : le code ne les ecrit nulle part,
elles sont dans les tables du client. Sans elles, on etire l'image entiere
et ses coins se deforment (questlog-frame, 2026-09-25).

Usage : python tools/tranches_atlas.py questlog-frame common-dropdown-bg
Les deux tables s'exportent par le pont de wow.export :
  /export?file=dbfilesclient/uitextureatlaselement.db2
  /export?file=dbfilesclient/uitextureatlaselementslicedata.db2
Sortie : [id, element, gauche, haut, droite, bas, mode] -- l'ordre des marges
a ete recoupe sur common-dropdown-bg (16, 13, 16, 19 : l'ombre en bas).

"""
import struct
import sys

BASE = r"C:\Users\Arthe\wow.export\dbfilesclient\%s.db2"


def entete(d):
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


# les noms
d = open(BASE % "uitextureatlaselement", "rb").read()
rc, fc, rs, secs, fields, infos = entete(d)
noms = {}
base = secs[0][1]
for r in range(rc):
    ro = base + r * rs
    v, = struct.unpack_from("<I", d, ro)
    p = ro + v
    e = d.find(b"\x00", p)
    ident, = struct.unpack_from("<I", d, ro + 4)
    noms[ident] = d[p:e].decode("utf-8", "replace")
par_nom = {v.lower(): k for k, v in noms.items()}

# les tranches
d = open(BASE % "uitextureatlaselementslicedata", "rb").read()
rc, fc, rs, secs, fields, infos = entete(d)
base = secs[0][1]
tranches = {}
for r in range(rc):
    ro = base + r * rs
    bits = int.from_bytes(d[ro:ro + rs], "little")
    vals = []
    for (offbits, nbits, add, typ, a, b, c) in infos:
        v = (bits >> offbits) & ((1 << nbits) - 1)
        if typ == 5 and v >> (nbits - 1):
            v -= 1 << nbits
        vals.append(v)
    tranches[vals[1]] = vals

for nom in sys.argv[1:]:
    ident = par_nom.get(nom.lower())
    print("%-40s element %s -> %s" % (nom, ident, tranches.get(ident)))
