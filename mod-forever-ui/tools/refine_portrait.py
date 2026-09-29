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

"""Refines the Social window portrait for 3.3.5.

Battlenet-Portrait exists only at 64 x 64 in the modern client, DXT5-compressed and without
mipmaps. Shown at 60 x 60 interface units, it is enlarged on a high-resolution screen, where
the 4 x 4 DXT blocks and the sampling of a small image make the icon look pixelated (same
issue as the minimap arrows, tools/shrink_arrows.py).

Decodes the BLP placed by add_sheets.py, upscales it once to 128 x 128 (Lanczos, with
premultiplied alpha so the transparent edge does not bleed into the black disc) and writes
it uncompressed (BGRA) with its mipmap chain down to 1 x 1: the client then scales it down
instead of up, with no compression artifacts.

Writes battlenet-portrait-hd next to the original, which stays as the modern client gives it
(add_sheets.py would overwrite it otherwise).
"""
import io
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "data", "art", "interface", "ForeverUI", "friendsframe")
SOURCE = os.path.join(FOLDER, "battlenet-portrait.blp")
OUTPUT = os.path.join(FOLDER, "battlenet-portrait-hd")
SIDE = 128


def main():
    with io.open(SOURCE, "rb") as f:
        width, height, rgba, _ = blp.decode(f.read())
    image = Image.frombytes("RGBA", (width, height), bytes(rgba)).convert("RGBa")
    full = image.resize((SIDE, SIDE), Image.LANCZOS)
    mips = []
    side = SIDE
    while side > 1:
        side //= 2
        mips.append((side, side, full.resize((side, side), Image.LANCZOS).convert("RGBA").tobytes()))
    output = full.convert("RGBA")
    with io.open(OUTPUT + ".blp", "wb") as f:
        f.write(blp.encode(SIDE, SIDE, output.tobytes(), mips))
    output.save(OUTPUT + ".png")
    print("battlenet-portrait : %d x %d -> %d x %d + %d mipmaps, non compresse" % (
        width, height, SIDE, SIDE, len(mips)))


if __name__ == "__main__":
    main()
