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

"""Bake round window portraits for the portrait ring.

camelot rounds a window portrait with SetPortraitToAsset. Its 3.3.5 equivalent,
SetPortraitToTexture, leaves the professions book portrait square, so the icon overflows
the ring. The inscribed disk is baked into the image alpha instead.

Decodes the 64 x 64 icon written by add_sheets.py, upscales it to 128 x 128 (Lanczos, in
premultiplied alpha, like refine_portrait.py), multiplies its alpha by the smoothed disk
and writes it uncompressed with its mipmaps. The baked file goes next to the icon with a
-rond suffix: the raw icon stays the input, and add_sheets.py rewrites it.
"""
import io
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "data", "art", "interface", "ForeverUI", "icons")
PORTRAITS = ["inv_sidetab_professions_c60"]
# SIDE: baked size in pixels; SWATCHES: disk samples per texel side (4 x 4 per texel)
SIDE = 128
SWATCHES = 4


def disk(side):
    """Alpha of the smoothed inscribed disk: the share of each texel inside it."""
    radius = side / 2.0
    step = 1.0 / SWATCHES
    values = bytearray(side * side)
    for y in range(side):
        for x in range(side):
            inside = 0
            for sy in range(SWATCHES):
                for sx in range(SWATCHES):
                    dx = x + (sx + 0.5) * step - radius
                    dy = y + (sy + 0.5) * step - radius
                    if dx * dx + dy * dy <= radius * radius:
                        inside += 1
            values[y * side + x] = round(255 * inside / (SWATCHES * SWATCHES))
    return Image.frombytes("L", (side, side), bytes(values))


# Writes <name>-rond.blp and .png next to the icon. name: icon file name, no extension
def bake(name):
    source = os.path.join(ICONS, name + ".blp")
    output = os.path.join(ICONS, name + "-rond")
    with io.open(source, "rb") as f:
        width, height, rgba, _ = blp.decode(f.read())
    image = Image.frombytes("RGBA", (width, height), bytes(rgba)).convert("RGBa")
    full = image.resize((SIDE, SIDE), Image.LANCZOS).convert("RGBA")
    red, green, blue, alpha = full.split()
    alpha = Image.frombytes(
        "L", (SIDE, SIDE), bytes(a * m // 255 for a, m in zip(alpha.tobytes(), disk(SIDE).tobytes())))
    circle = Image.merge("RGBA", (red, green, blue, alpha))
    premul = circle.convert("RGBa")
    mips = []
    side = SIDE
    while side > 1:
        side //= 2
        mips.append((side, side, premul.resize((side, side), Image.LANCZOS).convert("RGBA").tobytes()))
    with io.open(output + ".blp", "wb") as f:
        f.write(blp.encode(SIDE, SIDE, circle.tobytes(), mips))
    circle.save(output + ".png")
    print("%s : %d x %d -> %d x %d rond + %d mipmaps, non compresse" % (
        name, width, height, SIDE, SIDE, len(mips)))


def main():
    for name in PORTRAITS:
        bake(name)


if __name__ == "__main__":
    main()
