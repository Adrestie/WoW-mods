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

"""Bakes the two "Dishonored" player emblems: a broken faction crest.

While dishonored, the player loses the faction symbol at the center of the PvP tab dial.
A square debuff icon shows its edges and is clipped there, so each faction gets its own
emblem: the camelot faction emblem with its alpha channel unchanged (it blends the emblem
into the dial), tarnished toward a dull faction tint, split along a zigzag diagonal with
the two halves pushed apart. The dial's faction background shows through the crack, and a
dull red glow lines its edges.

Source: data/art/interface/foreverui/pvpframe/uicharacterinfohonorc60.blp, entries
ui-character-info-honor-icon-alliance / -horde (75 x 75, UIAtlas_06_extras.lua).

Output, in data/art/interface/foreverui/pvpframe/:
    honor-dishonored-alliance.blp   128 x 128, mipmaps down to 1 x 1
    honor-dishonored-horde.blp
with .png previews. PvPTab.lua shows them at the emblem size (72 x 84).

    python tools/bake_dishonor.py
"""
import io
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from foreverui import blp

HERE = os.path.dirname(os.path.abspath(__file__))
WORKSPACE = os.path.dirname(HERE)
FOLDER = os.path.join(WORKSPACE, "data", "art", "interface", "foreverui", "pvpframe")
SHEET = os.path.join(FOLDER, "uicharacterinfohonorc60.blp")

# u1, u2, v1, v2 in the sheet (UIAtlas_06_extras.lua)
EMBLEMS = {
    "alliance": (0.642578, 0.789062, 0.824219, 0.970703),
    "horde": (0.792969, 0.939453, 0.673828, 0.820312),
}

# dull tint of each faction, and how much of the original color is kept
TINTS = {
    "alliance": (92, 102, 124),
    "horde": (104, 84, 78),
}
KEPT_COLOR = 0.18
DARKENED = 0.72

WORK_SCALE = 4          # the emblem is processed at four times its size
OUTPUT = 128         # then rendered at 128 x 128
GAP = 16           # gap between the two halves, in work pixels
CRACK_WIDTH = 9            # width of the crack, in work pixels
GLOW = (235, 70, 25)
GLOW_BLUR = 6
GLOW_STRENGTH = 0.85


def read_sheet():
    width, height, rgba, _ = blp.decode(io.open(SHEET, "rb").read())
    return Image.frombytes("RGBA", (width, height), bytes(rgba))


# Crops an atlas entry from the sheet; rect: u1, u2, v1, v2
def cut(sheet, rect):
    w, h = sheet.size
    u1, u2, v1, v2 = rect
    return sheet.crop((round(u1 * w), round(v1 * h), round(u2 * w), round(v2 * h)))


def tarnish(image, tint):
    """Moves the emblem color toward a dull faction tint, keeping its luminance;
    alpha is unchanged.
    """
    r, v, b, a = image.split()
    gray = Image.merge("RGB", (r, v, b)).convert("L")
    tint_img = Image.merge("RGB", [gray.point(lambda x, c=c: x * c / 255.0) for c in tint])
    original = Image.merge("RGB", (r, v, b))
    blended = Image.blend(tint_img, original, KEPT_COLOR)
    blended = blended.point(lambda x: x * DARKENED)
    return Image.merge("RGBA", (*blended.split(), a))


def crack(size, seed):
    """Fracture line from top right to bottom left, in a regular zigzag
    (the seed keeps it identical between runs).
    """
    rng = random.Random(seed)
    n = 9
    points = []
    for i in range(n + 1):
        t = i / n
        x = size * (0.80 - 0.60 * t)
        y = size * (0.02 + 0.96 * t)
        if 0 < i < n:
            gap = size * 0.055 * (1 if i % 2 else -1) * (0.6 + 0.8 * rng.random())
            x += gap
        points.append((x, y))
    return points


def shatter(image, points):
    """Splits the emblem along the crack and pushes the halves apart; hollows the crack
    and adds a red glow on its edges, inside the silhouette.
    """
    size = image.size[0]
    side = Image.new("L", image.size, 0)
    # right half: the crack, then the right edge of the image
    ImageDraw.Draw(side).polygon(points + [(size * 2, size * 2), (size * 2, -size)], fill=255)
    right = Image.new("RGBA", image.size, (0, 0, 0, 0))
    right.paste(image, (0, 0), side)
    left = Image.new("RGBA", image.size, (0, 0, 0, 0))
    left.paste(image, (0, 0), ImageChops.invert(side))

    # gap: perpendicular to the diagonal, on both sides
    d = GAP // 2
    shattered = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shattered.alpha_composite(left, (-d, -d // 2))
    shattered.alpha_composite(right, (d, d // 2))

    # hollow the crack, even where the halves overlap
    line = Image.new("L", image.size, 0)
    ImageDraw.Draw(line).line(points, fill=255, width=CRACK_WIDTH, joint="curve")
    r, v, b, a = shattered.split()
    a = ImageChops.subtract(a, line)

    # edge glow, kept inside the silhouette
    halo = Image.new("L", image.size, 0)
    ImageDraw.Draw(halo).line(points, fill=255, width=CRACK_WIDTH + 2 * GAP, joint="curve")
    halo = halo.filter(ImageFilter.GaussianBlur(GLOW_BLUR))
    halo = ImageChops.multiply(halo, a).point(lambda x: x * GLOW_STRENGTH)
    red = Image.new("RGB", image.size, GLOW)
    color = Image.composite(red, Image.merge("RGB", (r, v, b)), halo)
    return Image.merge("RGBA", (*color.split(), a))


def levels(image):
    """Mipmap levels: the image is drawn smaller than its size."""
    out = []
    w = image.size[0] // 2
    while w >= 1:
        reduced = image.resize((w, w), Image.LANCZOS)
        out.append((w, w, reduced.tobytes()))
        w //= 2
    return out


# Writes the .blp and the .png preview of one faction emblem; seed: fixes the crack shape
def bake(faction, sheet, seed):
    emblem = cut(sheet, EMBLEMS[faction])
    large = emblem.resize((emblem.size[0] * WORK_SCALE, emblem.size[1] * WORK_SCALE), Image.LANCZOS)
    large = tarnish(large, TINTS[faction])
    large = shatter(large, crack(large.size[0], seed))
    final = large.resize((OUTPUT, OUTPUT), Image.LANCZOS)
    name = "honor-dishonored-%s" % faction
    path = os.path.join(FOLDER, name + ".blp")
    io.open(path, "wb").write(blp.encode(OUTPUT, OUTPUT, final.tobytes(), levels(final)))
    final.save(os.path.join(FOLDER, name + ".png"))
    print("ecrit :", path)


def main():
    sheet = read_sheet()
    for seed, faction in enumerate(sorted(EMBLEMS)):
        bake(faction, sheet, 1234 + seed)


if __name__ == "__main__":
    main()
