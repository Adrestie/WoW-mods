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

"""Shrink the pattern of the minimap edge arrows.

The 3.3.5 engine draws out-of-range arrows at a fixed radius in map units (140, Minimap.xml).
The map is enlarged by scale (198 / 140) to put them on camelot's edge, which enlarges them
too, so the pattern is shrunk by 140 / 198 around the image center.

Arrows set by a Minimap method (globals found in Wow.exe):

  Rotating-MinimapArrow        0xbeba24   SetStaticPOIArrowTexture
  Rotating-MinimapGuideArrow   0xbeba2c   SetPOIArrowTexture
  Rotating-MinimapCorpseArrow  0xbeba28   SetCorpsePOIArrowTexture

Rotating-MinimapGroupArrow (0xbeba20) has no method: its original file is replaced at its own
path in patch-Z. It stays shrunk with the addon disabled, and tools/deploy.py, which only
removes files under the ForeverUI folder, does not remove it.

Source: the 3.3.5 client read without patch-Z, so a rerun never shrinks an arrow twice.
Outputs go to data/art/ with a PNG preview; tools/deploy.py deploys them.
"""
import io
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp, mpq  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "data", "art")
OUTPUT = os.path.join(ART, "interface", "ForeverUI", "minimap")
# Exception: the group arrow, at its original path.
ORIGINAL_OUTPUT = os.path.join(ART, "Interface", "Minimap")
PROJECT_ARCHIVE = "patch-Z.MPQ"
CLIENT = r"E:\world of warcraft 3.3.5a hd\Data"
BS = chr(92)

# Resolution: in a 32 image the shrunk pattern is 22.6 texels, which the map scale then
# stretches by 1.414 (pixelated). A 64 output holds it in 45 texels, so the client scales it
# down. Like the originals, it carries mipmaps down to 1 x 1.
MULTIPLE = 2

CLIENT_MAP = 140      # 3.3.5 Minimap.xml
CAMELOT_MAP = 198     # mainline/Minimap.xml
FACTOR = CLIENT_MAP / CAMELOT_MAP

# original file name -> (output folder, output name)
ARROWS = [
    ("Rotating-MinimapArrow", OUTPUT, "rotating-minimaparrow"),
    ("Rotating-MinimapGuideArrow", OUTPUT, "rotating-minimapguidearrow"),
    ("Rotating-MinimapCorpseArrow", OUTPUT, "rotating-minimapcorpsearrow"),
    ("Rotating-MinimapGroupArrow", ORIGINAL_OUTPUT, "ROTATING-MINIMAPGROUPARROW"),
]


# Shrinks one arrow read from chain; writes folder/output_name as .blp and .png.
def shrink(name, chain, folder, output_name):
    path = BS.join(["Interface", "Minimap", name + ".blp"])
    width, height, rgba, _ = blp.decode(chain.read(path))
    image = Image.frombytes("RGBA", (width, height), bytes(rgba))

    # Shrink around the image center with an affine transform, not by pasting a thumbnail:
    # 32 x 0.7071 is not an integer, and a 23 thumbnail would be off by half a pixel, making the
    # arrow wobble as it rotates. Premultiplied alpha keeps the often black transparent edge from
    # bleeding into the pattern.
    lo, ho = width * MULTIPLE, height * MULTIPLE
    scale = FACTOR * MULTIPLE        # output texels per original texel
    inverse = 1.0 / scale
    data = (inverse, 0, width / 2.0 - (lo / 2.0) * inverse,
               0, inverse, height / 2.0 - (ho / 2.0) * inverse)
    full = image.convert("RGBa").transform((lo, ho), Image.AFFINE, data,
                                             resample=Image.BICUBIC)
    output = full.convert("RGBA")
    l2 = width * scale

    # Mipmaps, also in premultiplied alpha, down to 1 x 1.
    mips = []
    l, h = lo, ho
    while l > 1 or h > 1:
        l, h = max(1, l // 2), max(1, h // 2)
        mips.append((l, h, full.resize((l, h), Image.LANCZOS).convert("RGBA").tobytes()))

    os.makedirs(folder, exist_ok=True)
    base = os.path.join(folder, output_name)
    with io.open(base + ".blp", "wb") as f:
        f.write(blp.encode(lo, ho, output.tobytes(), mips))
    output.save(base + ".png")
    print("   %-30s %d x %d -> %d x %d + %d mipmaps, motif %.1f texels" % (
        name, width, height, lo, ho, len(mips), l2))


def main():
    chain = mpq.open_client(CLIENT, "enUS", ignore=(PROJECT_ARCHIVE,))
    print("facteur %d / %d = %.4f" % (CLIENT_MAP, CAMELOT_MAP, FACTOR))
    try:
        for name, folder, output_name in ARROWS:
            shrink(name, chain, folder, output_name)
    finally:
        chain.close()


if __name__ == "__main__":
    main()
