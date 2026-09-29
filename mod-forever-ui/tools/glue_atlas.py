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

"""Builds the atlas table of the login screens (ForeverUIGlueAtlas.lua).

No addon runs in GlueXML, so the login screens have their own table, limited to the
elements they use. Coordinates and file come from the addon's UIAtlas_*.lua tables; display
size, tiling and nine-slice margins come from the modern client's UiTextureAtlasMember and
UiTextureAtlasElementSliceData. Variants tried: name-c60-2x, name-c60, name-2x, name
(a -2x variant is double density and displays at half size).

Reads the names of tools/glue_atlas.txt; each output row is
  ["name"] = { file, u1, u2, v1, v2, width, height, tileH, tileV, slice }
with slice = { left, top, right, bottom, mode } (mode 0 = stretch, 1 = tile) or nil.
A missing name, or a sheet over 1024 px (unreadable in 3.3.5), stops the build.
"""
import glob
import io
import os
import struct
import sys

from lupa import LuaRuntime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import db2  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "data", "addon", "ForeverUI")
ART = os.path.join(ROOT, "data", "art")
LIST = os.path.join(ROOT, "tools", "glue_atlas.txt")
MEMBERS = os.path.join(os.path.expanduser("~"), "wow.export", "dbfilesclient", "uitextureatlasmember.db2")
SLICE_DATA = os.path.join(os.path.expanduser("~"), "wow.export", "dbfilesclient", "uitextureatlaselementslicedata.db2")
OUTPUT = os.path.join(ROOT, "data", "glue", "Interface", "GlueXML", "ForeverUIGlueAtlas.lua")
BS = chr(92)
VARIANTS = ("-c60-2x", "-c60", "-2x", "")
MIN_SIDE = 8    # same as tools/cut_elements.py
# Sheets refined x4 by tools/refine_fields.py (<sheet>-hd, same coordinates) that the
# login screens use instead of the original. Listed only where needed (the options
# slider thumb looks pixelated otherwise).
REFINED = {
    "interface" + BS + "foreverui" + BS + "buttons" + BS + "minimalsliderbarc60",
}


def load_slicing():
    """element id -> (left, top, right, bottom, mode): nine-slice margins
    (UiTextureAtlasElementSliceData) in element units; mode 0 = stretch, 1 = tile.
    """
    res = {}
    for _, v in db2.read(SLICE_DATA):
        res[v[1]] = (v[2], v[3], v[4], v[5], v[6])
    return res


def _reference(rows):
    """Reference size of each element for its slice margins: its plain variant (no suffix),
    else -c60, else the first one. All variants share the same margins but not the same
    size, so the margins are relative to the plain variant and scaled for the others.
    """
    ref = {}
    rank = {}
    for _, v in rows:
        name = v[0].lower()
        r = 0 if not (name.endswith("-c60") or name.endswith("-2x")) else (1 if name.endswith("-c60") else 2)
        if v[9] not in rank or r < rank[v[9]]:
            rank[v[9]] = r
            ref[v[9]] = (v[3], v[4])
    return ref


def members():
    """lowercase name -> (width, height, tileH, tileV, width in texels, slice or None)."""
    margins = load_slicing()
    rows = db2.read(MEMBERS, (0,))
    reference = _reference(rows)
    res = {}
    for _, v in rows:
        name = v[0].lower()
        width, height = v[3], v[4]
        texels = v[6] - v[5]
        forced_w, forced_h, flags = v[10], v[11], v[12]
        if forced_w or forced_h:
            width, height = forced_w or width, forced_h or height
        # A -2x variant is double density, override size included: its override size is
        # always twice that of its plain variant, and both display the same.
        if name.endswith("-2x"):
            width, height = width / 2.0, height / 2.0
        slicing = margins.get(v[9])
        if slicing:
            rw, rh = reference[v[9]]
            g, h, d, b, mode = slicing
            slicing = (round(g * width / rw, 2), round(h * height / rh, 2),
                       round(d * width / rw, 2), round(b * height / rh, 2), mode)
        res[name] = (width, height, bool(flags & 4), bool(flags & 2), texels, slicing)
    return res


def blp_dimensions(internal_path):
    """Width and height of the sheet in data/art (BLP2 header)."""
    rel = internal_path.split(BS)
    file = os.path.join(ART, *rel) + ".blp"
    if not os.path.exists(file):
        raise SystemExit("feuille absente de l'atelier : %s" % file)
    d = io.open(file, "rb").read(20)
    return struct.unpack_from("<II", d, 12)


def main():
    lua = LuaRuntime()
    for path in sorted(glob.glob(os.path.join(ADDON, "UIAtlas_*.lua"))):
        lua.execute(io.open(path, encoding="utf-8").read())
    data = lua.globals().UIAtlas.data
    sizes = members()

    names = []
    for row in io.open(LIST, encoding="utf-8"):
        row = row.split("#")[0].strip().lower()
        if row:
            names.append(row)

    rows = [
        "-- atlas elements of the login screens",
        "-- generated by tools/glue_atlas.py (coordinates: the addon's tables;",
        "-- sizes and tiling: UiTextureAtlasMember of the modern client)",
        "",
        "ForeverUIGlue = ForeverUIGlue or {}",
        "ForeverUIGlue.atlas = {",
    ]
    errors = []
    for n in names:
        # Variant: the first one the modern client knows and whose coordinates the addon
        # has, under its raw name or under the logical name if that one points to the same
        # region (same width in texels).
        selected = e = None
        for suffix in VARIANTS:
            v = n + suffix
            if v not in sizes:
                continue
            for key in (v, n):
                cand = data[key]
                if cand is None:
                    continue
                lw, lh = blp_dimensions(cand[1])
                # A strip under MIN_SIDE texels is copied onto MIN_SIDE by
                # tools/cut_elements.py (it shows green otherwise); a sheet in density
                # 2 or 4 (minimalcheckbox-hd: checkmark-minimal, 120 texels for 30)
                # points to the same region.
                read, texels = (cand[3] - cand[2]) * lw, sizes[v][4]
                if any(abs(read - k * texels) <= k for k in (1, 2, 4)) or (texels < MIN_SIDE and abs(read - MIN_SIDE) <= 1):
                    selected, e = v, cand
                    break
            if selected:
                break
        if not selected:
            errors.append("absent : %s" % n)
            continue
        width, height, mh, mv, _, margins = sizes[selected]
        lw, lh = blp_dimensions(e[1])
        if lw > 1024 or lh > 1024:
            errors.append("feuille de %dx%d, illisible en 3.3.5 : %s (%s) -> tools/cut_elements.py" % (lw, lh, selected, e[1]))
            continue
        slicing = "nil"
        if margins:
            slicing = "{ %g, %g, %g, %g, %d }" % margins
        file = e[1]
        if file.lower() in REFINED:
            blp_dimensions(file + "-hd")
            file = file + "-hd"
        rows.append('\t["%s"] = { "%s", %.6f, %.6f, %.6f, %.6f, %g, %g, %s, %s, %s }, -- %s' % (
            n, file.replace(BS, BS + BS), e[2], e[3], e[4], e[5], width, height,
            "true" if mh else "false", "true" if mv else "false", slicing, selected))
    if errors:
        raise SystemExit("\n".join(errors))
    rows += ["}", ""]

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    io.open(OUTPUT, "w", encoding="utf-8", newline="\n").write("\n".join(rows))
    print("table des ecrans d'accueil : %d elements -> %s" % (len(names), os.path.relpath(OUTPUT, ROOT)))


if __name__ == "__main__":
    main()
