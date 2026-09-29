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

"""Bakes the character creation masks into the alpha of the icons.

camelot clips these icons with MaskTexture, which 3.3.5 lacks; as in tools/bake_masks.py,
the mask alpha is multiplied into the icon alpha once and for all.

Geometry (RingedMaskedButtonMixin:OnLoad,
blizzard_sharedxml/shared/frametemplate/ringedframetemplate.lua:93-94;
blizzard_charactercreate/camelot/*.xml):
  race button   79 x 79, character-create-icon-mask 2 px inside the edge (75 x 75)
  class button  66 x 66, same mask 2 px inside the edge (62 x 62)
  portrait      62 x 62 (CharacterCreateDetaislListTemplate),
                character-create-icon-circle-mask from (2, 0) to (-2, 4),
                i.e. the rect 2..60 x 0..58

Reads the icons cut by tools/cut_elements.py (glues/raceicon128-*.png,
glues/classicon-*.png) and the faction backgrounds and masks of the c60 sheet
unknown/8203433.png (regions from tools/atlas_dump.json). Writes
charactercreate/bouton-<icon> and portrait-<icon> (.blp + .png), 128 x 128, uncompressed,
with premultiplied-alpha mipmaps.
"""
import glob
import io
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "data", "art", "interface", "ForeverUI")
INDEX = os.path.join(ROOT, "tools", "atlas_dump.json")
SHEET_C60 = os.path.join(ART, "unknown", "8203433.png")
OUTPUT = os.path.join(ART, "charactercreate")
SIZE = 128

# icon file prefix -> (button side, mask inset)
BUTTONS = {"raceicon128-": (79.0, 2.0), "classicon-": (66.0, 2.0)}
PORTRAIT = 62.0
PORTRAIT_MASK = (2.0, 0.0, 60.0, 58.0)    # left, top, right, bottom


def _region(name):
    for r in json.load(io.open(INDEX, encoding="utf-8"))["results"]:
        if r["atlas"].lower() == name and r.get("fileDataID") == 8203433:
            return r["region"]
    raise SystemExit("absent de l'index : %s" % name)


def _mask(sheet, name):
    r = _region(name)
    return sheet.crop((r["left"], r["top"], r["left"] + r["width"], r["top"] + r["height"])).getchannel("A")


def _alpha(mask, u, v):
    """Mask alpha at (u, v) in [0, 1], read bilinearly; 0 outside (the mask wraps with
    CLAMPTOBLACKADDITIVE).
    """
    if u < 0 or v < 0 or u > 1 or v > 1:
        return 0.0
    w, h = mask.size
    x = min(max(u * w - 0.5, 0), w - 1)
    y = min(max(v * h - 0.5, 0), h - 1)
    x0, y0 = int(x), int(y)
    x1, y1 = min(x0 + 1, w - 1), min(y0 + 1, h - 1)
    fx, fy = x - x0, y - y0
    p = mask.load()
    top = p[x0, y0] * (1 - fx) + p[x1, y0] * fx
    down = p[x0, y1] * (1 - fx) + p[x1, y1] * fx
    return (top * (1 - fy) + down * fy) / 255.0


def _bake(icon, mask, side, rect):
    """Multiplies the mask alpha into the icon alpha.
    icon: SIZE x SIZE image laid on a frame of size `side`; rect: the mask in that frame
    (left, top, right, bottom).
    """
    g, h, d, b = rect
    output = icon.copy()
    px = output.load()
    for y in range(SIZE):
        for x in range(SIZE):
            cx = (x + 0.5) * side / SIZE
            cy = (y + 0.5) * side / SIZE
            a = _alpha(mask, (cx - g) / (d - g), (cy - h) / (b - h))
            r_, g_, b_, a_ = px[x, y]
            px[x, y] = (r_, g_, b_, int(round(a_ * a)))
    return output


# Writes <name>.blp (uncompressed, with mipmaps) and <name>.png into OUTPUT.
def _write(image, name):
    full = image.convert("RGBa")
    mips = []
    mw, mh = image.size
    while mw > 1 or mh > 1:
        mw, mh = max(1, mw // 2), max(1, mh // 2)
        mips.append((mw, mh, full.resize((mw, mh), Image.LANCZOS).convert("RGBA").tobytes()))
    base = os.path.join(OUTPUT, name)
    with io.open(base + ".blp", "wb") as f:
        f.write(blp.encode(image.size[0], image.size[1], image.tobytes(), mips))
    image.save(base + ".png")


def main():
    os.makedirs(OUTPUT, exist_ok=True)
    sheet = Image.open(SHEET_C60).convert("RGBA")
    square = _mask(sheet, "character-create-icon-mask-c60")
    circle = _mask(sheet, "character-create-icon-circle-mask-c60")

    n = 0
    for prefix, (side, margin) in sorted(BUTTONS.items()):
        for path in sorted(glob.glob(os.path.join(ART, "glues", prefix + "*.png"))):
            name = os.path.splitext(os.path.basename(path))[0]
            icon = Image.open(path).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
            _write(_bake(icon, square, side, (margin, margin, side - margin, side - margin)), "bouton-" + name)
            n += 1
            if prefix == "raceicon128-":
                _write(_bake(icon, circle, PORTRAIT, PORTRAIT_MASK), "portrait-" + name)
                n += 1

    # faction portraits: charactercreate-icon-alliancebg / -hordebg
    for name in ("charactercreate-icon-alliancebg-c60", "charactercreate-icon-hordebg-c60"):
        r = _region(name)
        icon = sheet.crop((r["left"], r["top"], r["left"] + r["width"], r["top"] + r["height"]))
        icon = icon.resize((SIZE, SIZE), Image.LANCZOS)
        _write(_bake(icon, circle, PORTRAIT, PORTRAIT_MASK), "portrait-" + name[:-len("-c60")])
        n += 1

    print("creation : %d images cuites -> %s" % (n, os.path.relpath(OUTPUT, ROOT)))


if __name__ == "__main__":
    main()
