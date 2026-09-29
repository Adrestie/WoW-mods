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

"""Bake the two glyph page sheets from the reworked art.

Sources, in SOURCE:
    UI-GlyphFrame2.png          bare parchment (1122 x 1402)
    UI-GlyphFrame-Drawings.png  drawn circle (1173 x 1341)
    UI-GlyphFrame-corners.png   the four gold corners
    UI-GlyphFrame-Glow2.png     glows: runic ring, thorn ring, double ring, orange ring,
                                star, rays
    UI-GlyphFrame-symbols.png   engraved symbols (not used)

Output, in data/art/interface/ForeverUI/glyphs/, each with a .png preview:
    glyphes-fond.blp    1024 x 1024: parchment, circle, four corners
    glyphes-lueurs.blp  1024 x 1024: rings, rays, star
The tool prints the rectangle table (pixels) to copy into Talents.lua (GLYPHS_RECTS).

Scale: everything follows the WotLK glyph sockets, whose centers are 121 from the star
center (GlyphFrame, Blizzard_GlyphUI.xml). In the old disk that radius is 0.896 times the
hexagon vertex radius; in the new drawing the vertices are 439 px from the center
(584, 658), hence a scale of 121 / (0.896 x 439). Sheets are baked at 4/3 of the displayed
size (uiScale 0.64 on 1600 lines: one interface point is 1.33 pixels) and shrunk in
premultiplied alpha.
"""
import io
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

SOURCE = r"C:\Users\Arthe\wow.export\_glyphes_wotlk\feuilles\Rework"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "data", "art", "interface", "ForeverUI", "glyphes")

DENSITY = 4.0 / 3.0                     # pixels per interface point
SOCKET_RADIUS = 121.0                  # Blizzard_GlyphUI.xml
HEXAGON_RADIUS = 439.0                  # in the drawing, center (584, 658)
DRAWING_CENTER = (584.0, 658.0)
DRAWING_SCALE = SOCKET_RADIUS / (0.896 * HEXAGON_RADIUS)

# Displayed size in interface points. The parchment covers the whole small window under the
# inner frame: the Talents.lua art frame (page 404 wide; stone 701 minus 70 at the top and
# 36 at the bottom), stretched to these proportions
PARCHMENT_W, PARCHMENT_H = 404.0, 595.0
MAP_CORNER_SCALE = 0.125


def source(name):
    return Image.open(os.path.join(SOURCE, name)).convert("RGBA")


def shrink(im, width, height):
    """Shrink in premultiplied alpha: no dark fringe."""
    return im.convert("RGBa").resize((width, height), Image.LANCZOS).convert("RGBA")


def soften_edges(im, margin):
    """Fade the alpha to zero near the edges: a piece of the glow sheet carries its
    neighbors' halo, which the crop would cut sharply.
    """
    w, h = im.size
    mask = Image.new("L", (w, h), 0)
    inner = Image.new("L", (max(1, w - 2 * margin), max(1, h - 2 * margin)), 255)
    mask.paste(inner, (margin, margin))
    mask = mask.filter(ImageFilter.GaussianBlur(margin / 2.0))
    r, v, b, a = im.split()
    a = Image.composite(a, Image.new("L", (w, h), 0), mask)
    return Image.merge("RGBA", (r, v, b, a))


# Crop the square of half side `half` centered on (cx, cy)
def square(im, cx, cy, half):
    return im.crop((int(round(cx - half)), int(round(cy - half)),
                    int(round(cx + half)), int(round(cy + half))))


# Output sheet. place() composites a piece and records its rectangle (pixels) and its
# displayed size (interface points).
class Sheet:
    def __init__(self, name, size=1024):
        self.name = name
        self.image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        self.rects = {}

    def place(self, key, im, x, y, display):
        assert x + im.size[0] <= self.image.size[0] and y + im.size[1] <= self.image.size[1], key
        self.image.alpha_composite(im, (x, y))
        self.rects[key] = (x, y, im.size[0], im.size[1], display[0], display[1])

    def write(self):
        os.makedirs(OUTPUT, exist_ok=True)
        w, h = self.image.size
        path = os.path.join(OUTPUT, self.name + ".blp")
        io.open(path, "wb").write(blp.encode(w, h, self.image.tobytes()))
        self.image.save(os.path.join(OUTPUT, self.name + ".png"))
        print("%-60s %8d o" % (os.path.relpath(path, ROOT), os.path.getsize(path)))


# Interface points to sheet pixels
def px(points):
    return int(round(points * DENSITY))


def main():
    # ---------- Background sheet
    background = Sheet("glyphes-fond")

    # Parchment: the whole window
    p = source("UI-GlyphFrame2.png")
    pl, ph = PARCHMENT_W, PARCHMENT_H
    background.place("parchment", shrink(p, px(pl), px(ph)), 0, 0, (pl, ph))
    circle_x = px(pl) + 4

    # Circle: at socket scale; its center in the displayed piece is kept too. It fills the
    # rest of the sheet, right of the parchment (a bit under 4/3 density)
    d = source("UI-GlyphFrame-Drawings.png")
    dw, dh = d.size[0] * DRAWING_SCALE, d.size[1] * DRAWING_SCALE
    wpx = min(px(dw), 1024 - circle_x)
    background.place("circle", shrink(d, wpx, int(round(wpx * dh / dw))), circle_x, 0, (dw, dh))
    center = (DRAWING_CENTER[0] * DRAWING_SCALE, DRAWING_CENTER[1] * DRAWING_SCALE)

    # The four corners (boxes measured on the sheet alpha)
    c = source("UI-GlyphFrame-corners.png")
    boxes = {"coin-hg": (34, 23, 566, 584), "coin-hd": (688, 23, 1220, 584),
              "coin-bg": (36, 666, 561, 1206), "coin-bd": (694, 666, 1217, 1206)}
    x = 0
    for key, (x0, y0, x1, y1) in boxes.items():
        m = c.crop((x0, y0, x1 + 1, y1 + 1))
        al, ah = m.size[0] * MAP_CORNER_SCALE, m.size[1] * MAP_CORNER_SCALE
        r = shrink(m, px(al), px(ah))
        background.place(key, r, x, px(ph) + 8, (al, ah))
        x += r.size[0] + 4
    background.write()

    # ---------- Glow sheet
    glows = Sheet("glyphes-lueurs")
    g = source("UI-GlyphFrame-Glow2.png")
    k = DRAWING_SCALE

    def ring(key, cx, cy, half, source_radius, drawing_radius, x, y):
        """Place a ring of the sheet, scaled to a circle of the drawing.
        cx, cy, half: source square; source_radius, drawing_radius: ring radius in the sheet
        and in the drawing (px); x, y: position on the glow sheet

        The rings rotate (Talents.lua: concentric circles). 3.3.5 rotates a texture only by
        rotating its texture coordinates, so the corners of the read square reach sqrt(2) times
        its half side. Each ring sits in the middle of an empty area of that radius; the stored
        rectangle stays the ring's. Returns the side of that area.
        """
        m = soften_edges(square(g, cx, cy, half), 24)
        e = drawing_radius * k / source_radius          # points per source pixel
        side = 2 * half * e
        r = shrink(m, px(side), px(side))
        margin = int(math.ceil(r.size[0] * (math.sqrt(2) - 1) / 2)) + 2
        glows.place(key, r, x + margin, y + margin, (side, side))
        return r.size[0] + 2 * margin

    # Runic ring: band 289 to 335 px (middle 312) -> drawing band 445 to 472 (middle 458)
    w = ring("anneau-runique", 369, 360, 368, 312.0, 458.5, 0, 0)
    # Thorn ring (middle 200 px): around the six center runes (207 px); placed at 260 px,
    # outside the runes like the WotLK inscription band
    we = ring("anneau-epines", 968.5, 379.5, 240, 200.0, 260.0, w + 4, 0)
    # Double ring: 100 and 136 px -> the drawing's double center circle, 126 and 150
    wd = ring("anneau-double", 1363, 260.5, 160, 136.0, 150.0, w + 4, we + 4)

    # Orange ring: a socket highlight at the size of its frame (108 for a major socket);
    # the ring (edge at 124 px) spans 45 points
    m = soften_edges(square(g, 1364, 544, 150), 20)
    side = 150 * 2 * 45.0 / 124.0
    r = shrink(m, px(side), px(side))
    xo = w + 4 + wd + 4
    glows.place("anneau-orange", r, xo, we + 4, (side, side))

    # Sparkle star. The raw piece holds a solid 40 px disk and part of the runic ring halo:
    # keep its colors, and keep from its alpha only the core, the four rays and a soft halo
    m = np.array(g.crop((50, 695, 350, 995))).astype(float)
    yy, xx = np.mgrid[0:300, 0:300]
    dx, dy = xx - 150.0, yy - 150.0
    r2 = np.hypot(dx, dy)
    f = (np.exp(-(r2 / 9.0) ** 2)
         + np.exp(-(np.minimum(abs(dx), abs(dy)) / 4.0) ** 2) * np.exp(-(r2 / 100.0) ** 2)
         + 0.35 * np.exp(-(r2 / 28.0) ** 2))
    m[:, :, 3] = m[:, :, 3] * np.clip(f, 0, 1)
    star = Image.fromarray(m.astype(np.uint8), "RGBA")
    glows.place("star", shrink(star, 64, 64), xo, we + 4 + r.size[1] + 4, (48.0, 48.0))

    # Rays: the vertical flare (x 440, y 720..970) stretched along the star's three diameters
    # (vertical, 60 and 120 degrees), on both sides of the center out to the sockets
    m = soften_edges(g.crop((405, 700, 476, 991)), 12)
    length_pts = 2 * SOCKET_RADIUS + 40
    width_pts = length_pts * m.size[0] / m.size[1]
    radius = shrink(m, px(width_pts), px(length_pts))
    rays_y = w + 4
    glows.place("rayon-0", radius, 0, rays_y, (width_pts, length_pts))
    x = radius.size[0] + 8
    for i, angle in ((1, -60), (2, 60)):
        t = radius.rotate(angle, resample=Image.BICUBIC, expand=True)
        lw = t.size[0] / DENSITY
        lh = t.size[1] / DENSITY
        glows.place("rayon-%d" % i, t, x, rays_y, (lw, lh))
        x += t.size[0] + 8
    glows.write()

    # ---------- Rectangle table
    print()
    print("-- GLYPHS_RECTS (Talents.lua): sheet, x, y, w, h in pixels; displayed size")
    for f in (background, glows):
        for key, (x, y, l, h, al, ah) in f.rects.items():
            print('\t["%s"] = { "%s", %d, %d, %d, %d, %.2f, %.2f },' % (key, f.name, x, y, l, h, al, ah))
    print("-- circle center in its displayed piece: (%.2f, %.2f)" % center)


if __name__ == "__main__":
    main()
