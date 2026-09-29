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

"""Colors of the character customization swatches.

Camelot tints each color swatch (ColorSwatch1, SetVertexColor) with the color of its
ChrCustomizationChoice. 3.3.5 has no such colors: its choices are textures
(CharSections.dbc), so the color of a choice is read from the texture the client applies.

Reads CharSections.dbc and ChrRaces.dbc through the client's archive chain. For each
playable race and sex it takes the skin texture of each skin color (option 1, section 0)
and, for each hair color (option 4, section 3), the hair texture most hairstyles use.
Per group (one race, one sex, one option):
- mask: pixels that change from one color to another (std dev above DEVIATION_THRESHOLD).
Jewels, feathers, bands and the grey filler of hair textures are the same for every color
and drop out; hair strands (tauren horns) and the whole skin remain;
- tint: mean of the mask pixels whose luminance lies between the STRIP percentiles
(lit tones, without the dark gaps between strands and the white highlights).
A group with a single texture uses the whole image.

Writes data/glue/Interface/GlueXML/ForeverUIGlueColors.lua:
ForeverUIGlue.colors["RACE FILE"][sex 0/1].skinColor[index] = { r, g, b }
ForeverUIGlue.colors["RACE FILE"][sex 0/1].hair[index] = { r, g, b }
where index is the engine's (CharSections ColorIndex). The same table goes to
ForeverUI.AppearanceColors in data/addon/ForeverUI/BarberShopColors.lua for the in-game
barber shop (the addon cannot read glue files).
"""
import argparse
import io
import os
import struct
import sys
from collections import Counter

import numpy
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import mpq  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CLIENT = r"E:\world of warcraft 3.3.5a hd"
OUTPUT = os.path.join(ROOT, "data", "glue", "Interface", "GlueXML", "ForeverUIGlueColors.lua")
ADDON_OUTPUT = os.path.join(ROOT, "data", "addon", "ForeverUI", "BarberShopColors.lua")
BS = chr(92)
# Playable races of 3.3.5 (ChrRaces: goblin, 9, is not playable)
PLAYABLE = (1, 2, 3, 4, 5, 6, 7, 8, 10, 11)
SECTION_SKIN, SECTION_HAIR = 0, 3
SIZE = 128            # textures are compared at this size
DEVIATION_THRESHOLD = 12        # out of 255
STRIP = (60, 95)        # luminance percentiles
LUMINANCE = numpy.array([0.299, 0.587, 0.114])


# Returns the DBC rows and a function reading a string at an offset
def read_dbc(client, name):
    d = client.read("DBFilesClient" + BS + name)
    if d[:4] != b"WDBC":
        raise SystemExit("%s illisible" % name)
    n, fields, size, _ = struct.unpack("<4I", d[4:20])
    strings = d[20 + n * size:]

    def chain(o):
        return strings[o:strings.index(b"\0", o)].decode("utf-8", "replace")
    rows = [struct.unpack_from("<%dI" % fields, d, 20 + i * size) for i in range(n)]
    return rows, chain


def load(client, texture):
    """The texture as a SIZE x SIZE x 3 array, or None if unreadable."""
    try:
        im = Image.open(io.BytesIO(client.read(texture))).convert("RGB")
    except Exception:
        return None
    return numpy.asarray(im.resize((SIZE, SIZE), Image.BOX), dtype=numpy.float64)


def compute_tints(images):
    """texture -> (r, g, b) in 0..1, for the textures of one group."""
    stack = numpy.stack(list(images.values()))
    if len(images) > 1:
        mask = stack.std(axis=0).mean(axis=2) > DEVIATION_THRESHOLD
    else:
        mask = numpy.ones((SIZE, SIZE), dtype=bool)
    if not mask.any():
        mask[:] = True
    res = {}
    for texture, a in images.items():
        px = a[mask]
        lum = px @ LUMINANCE
        down, top = numpy.percentile(lum, STRIP[0]), numpy.percentile(lum, STRIP[1])
        selected = px[(lum >= down) & (lum <= top)]
        if len(selected) == 0:
            selected = px
        res[texture] = tuple(float(v) / 255.0 for v in selected.mean(axis=0))
    return res


def textures(client):
    """(race file, sex, 'skinColor' | 'hair', index) -> texture."""
    races, chain = read_dbc(client, "ChrRaces.dbc")
    file = {v[0]: chain(v[11]).upper() for v in races if v[0] in PLAYABLE}
    sections, chain = read_dbc(client, "CharSections.dbc")
    skinColor, hair = {}, {}
    for v in sections:
        race, sex, section, tex1, variation, color = v[1], v[2], v[3], chain(v[4]), v[8], v[9]
        if race not in file or not tex1:
            continue
        if section == SECTION_SKIN and variation == 0:
            skinColor[(file[race], sex, color)] = tex1
        elif section == SECTION_HAIR:
            hair.setdefault((file[race], sex, color), Counter())[tex1] += 1
    res = {}
    for (r, s, c), t in skinColor.items():
        res[(r, s, "skinColor", c)] = t
    for (r, s, c), count in hair.items():
        # The most used one; on a tie, the first by name
        res[(r, s, "hair", c)] = sorted(count.items(), key=lambda x: (-x[1], x[0].lower()))[0][0]
    return res


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--client", default=DEFAULT_CLIENT, help="dossier du client 3.3.5")
    options = parser.parse_args()
    client = mpq.open_client(os.path.join(options.client, "Data"), "enUS")

    groups = {}
    for (race, sex, kind, index), texture in textures(client).items():
        groups.setdefault((race, sex, kind), {})[index] = texture
    colors, missing, loaded = {}, [], 0
    for (race, sex, kind), choice in sorted(groups.items()):
        images = {}
        for texture in sorted(set(choice.values())):
            a = load(client, texture)
            if a is None:
                missing.append(texture)
            else:
                images[texture] = a
        loaded += len(images)
        if not images:
            continue
        t = compute_tints(images)
        for index, texture in choice.items():
            if texture in t:
                colors.setdefault(race, {}).setdefault(sex, {}).setdefault(kind, {})[index] = t[texture]

    header = [
        "-- swatch colors of the appearance choices (skin, hair)",
        "-- generated by tools/customization_colors.py: tint of the texture that",
        "-- CharSections.dbc gives each choice of the 3.3.5 client",
    ]
    rows = []
    for race in sorted(colors):
        rows.append('\t["%s"] = {' % race)
        for sex in sorted(colors[race]):
            rows.append("\t\t[%d] = {" % sex)
            for kind in ("skinColor", "hair"):
                table = colors[race][sex].get(kind, {})
                rows.append("\t\t\t%s = {" % kind)
                for index in sorted(table):
                    r, g, b = table[index]
                    rows.append("\t\t\t\t[%d] = { %.3f, %.3f, %.3f }," % (index, r, g, b))
                rows.append("\t\t\t},")
            rows.append("\t\t},")
        rows.append("\t},")
    rows += ["}", ""]
    io.open(OUTPUT, "w", encoding="utf-8", newline="\n").write("\n".join(
        header + ["", "ForeverUIGlue = ForeverUIGlue or {}", "ForeverUIGlue.colors = {"] + rows))
    io.open(ADDON_OUTPUT, "w", encoding="utf-8", newline="\n").write("\n".join(
        header + ["-- (copy for the in-game barber shop)", "", "ForeverUI = ForeverUI or {}",
                  "ForeverUI.AppearanceColors = {"] + rows))
    total = sum(len(t) for r in colors.values() for s in r.values() for t in s.values())
    print("couleurs : %d choix, %d textures lues -> %s, %s" % (total, loaded, os.path.relpath(OUTPUT, ROOT),
                                                              os.path.relpath(ADDON_OUTPUT, ROOT)))
    for a in missing:
        print("   sans echantillon : " + a)


if __name__ == "__main__":
    main()
