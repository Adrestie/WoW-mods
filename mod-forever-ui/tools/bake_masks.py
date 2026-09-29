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

"""Bakes camelot's MaskTextures into texture alpha, since 3.3.5 has no MaskTexture:
side tab icons, stat bar fills, the PvP ring gauge, and the spellbook and talent portraits.

Side tabs: LargeSideTabButtonTemplate clips the icon with common-sidetab-mask. Geometry from
the source, in tab space (origin at the center, x right, y up):

  tab    55 x 55     CalculateTabSizeBasedOnTabArt: art width, height without the
                     transparent bottom strip
  mask   55 x 60     common-sidetab-mask-c60, useAtlasSize, anchored CENTER
                     (overflows 2.5 px at the top and bottom)
  icon   50 x 50     UpdateIconInterior: SetSize(interiorExtent, ...)
         at (-3, 0)  GetIconAnchorOffsetsForTabArt
         cropped     SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)

An icon texel (u, v), visible only in [0.03125, 0.96875], maps to
  x = -28 + (u - 0.03125) / 0.9375 * 50
  y =  25 - (v - 0.03125) / 0.9375 * 50
and the mask is read at ((x + 27.5) / 55, (30 - y) / 60). Outside the mask, its wrap is
CLAMPTOBLACKADDITIVE: nothing.

Raw icons stay in icons/ (the input); baked ones go to tabicons/, which the addon shows.
"""
import io
import math
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "data", "art", "interface", "ForeverUI")
MASK = os.path.join(ART, "common", "commonsidetabmask2xc60.blp")
INPUT = os.path.join(ART, "icons")
OUTPUT = os.path.join(ART, "tabicons")

# Icons camelot puts on side tabs, as CHARACTER_MODE_TAB_ICONS names them.
# The character portrait is not listed: it has no file.
ICONS = [
    "inv_sidetab_reputation2_c60.blp",
    "ability_racial_jackofalltrades.blp",
    "inv_sidetab_currency_c60.blp",
    "inv_sidetab_honor_alliance_c60.blp",
    "inv_sidetab_honor_horde_c60.blp",
    "inv_sidetab_stats_c60.blp",
]

# Specialization tabs (talents screen): the main tree icon of each class,
# plus the WotLK hybrid icon.
ICONS += ["%s.blp" % n for n in (
    "ability_backstab",
    "ability_hunter_beasttaming",
    "ability_hunter_swiftstrike",
    "ability_marksmanship",
    "ability_racial_bearform",
    "ability_rogue_eviscerate",
    "ability_stealth",
    "ability_warrior_innerrage",
    "inv_shield_06",
    "spell_deathknight_bloodpresence",
    "spell_deathknight_frostpresence",
    "spell_deathknight_unholypresence",
    "spell_fire_firebolt02",
    "spell_frost_frostbolt02",
    "spell_holy_auraoflight",
    "spell_holy_devotionaura",
    "spell_holy_guardianspirit",
    "spell_holy_holybolt",
    "spell_holy_magicalsentry",
    "spell_holy_wordfortitude",
    "spell_nature_healingtouch",
    "spell_nature_lightning",
    "spell_nature_lightningshield",
    "spell_nature_magicimmunity",
    "spell_nature_starfall",
    "spell_shadow_deathcoil",
    "spell_shadow_metamorphosis",
    "spell_shadow_rainoffire",
    "spell_shadow_shadowwordpain",
    "ability_dualwieldspecialization")]

# Glyph tab (talents screen): the inscription icon, as WotLK gives its bottom tab none.
ICONS += ["inv_inscription_tradeskill01.blp"]

# Pet tab of the character sheet (camelot has none): one icon per pet class
# (the hunter reuses ability_hunter_beasttaming, baked above).
ICONS += ["spell_shadow_summonimp.blp", "spell_shadow_animatedead.blp"]

# Group finder tabs: dungeons and raid browser
ICONS += ["inv_helmet_08.blp", "achievement_general_stayclassy.blp"]

# The character tab shows the icon of the player's class: one file per class.
ICONS += ["classicon_%s.blp" % c for c in (
    "deathknight", "druid", "hunter", "mage", "paladin",
    "priest", "rogue", "shaman", "warlock", "warrior")]

# Bank: page tabs of BankPageTabTemplate
ICONS += ["inv_sidetab_bank_c60.blp", "achievement_guildperk_mobilebanking.blp",
           "trade_archaeology_chestoftinyglassanimals.blp", "ability_racial_packhobgoblin.blp"]

# Professions: the overview tab and one tab per profession
# (inscription reuses inv_inscription_tradeskill01, baked above)
ICONS += ["%s.blp" % n for n in (
    "inv_sidetab_professions_c60", "trade_alchemy", "trade_blacksmithing", "trade_engraving",
    "trade_engineering", "trade_leatherworking", "trade_mining", "trade_tailoring",
    "inv_misc_food_15", "spell_holy_sealofsacrifice", "inv_misc_gem_01")]

TAB_W, TAB_H = 55.0, 55.0
MASK_W, MASK_H = 55.0, 60.0
ICON = 50.0
ICON_X, ICON_Y = -3.0, 0.0
CROP = 0.03125

# The mask is binary: its middle row jumps from 0 to 255 in one texel. The client applies it
# at screen resolution; baked at 64 px it becomes a staircase that UI scaling enlarges.
# So we bake at SCALE times the source size, read the 2x mask with interpolation, and
# average SUPER x SUPER samples per texel. The icon content stays 64 x 64, all the client has.
SCALE = 2
SUPER = 4


# Writes the .png preview the workspace keeps next to each .blp.
# Dependency-free: zlib is enough.
def _png(path, width, height, rgba):
    rows = bytearray()
    for j in range(height):
        rows.append(0)                        # filter: none
        start = j * width * 4
        rows += rgba[start:start + width * 4]

    def block(name, data):
        body = name + data
        return (struct.pack(">I", len(data)) + body
                + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    io.open(path, "wb").write(
        # PNG signature as byte values: escapes in a string are easily mangled when copied.
        bytes((137, 80, 78, 71, 13, 10, 26, 10))
        + block(b"IHDR", header)
        + block(b"IDAT", zlib.compress(bytes(rows), 9))
        + block(b"IEND", b""))


def _write(path, width, height, pixels):
    """Writes a BLP and its PNG preview; refuses sizes that are not powers of two.

    The client does not sample non-power-of-two textures correctly (it draws them as one
    flat block), and the error only shows in game.
    """
    for name, size in (("width", width), ("height", height)):
        if size <= 0 or (size & (size - 1)) != 0:
            raise SystemExit("%s : %s de %d n'est pas une puissance de deux"
                             % (os.path.basename(path), name, size))

    os.makedirs(os.path.dirname(path), exist_ok=True)
    io.open(path, "wb").write(blp.encode(width, height, bytes(pixels)))
    _png(path[:-4] + ".png", width, height, pixels)


def _read(path):
    width, height, rgba, _ = blp.decode(io.open(path, "rb").read())
    return width, height, bytearray(rgba)


def _mask_alpha(mx, my, width, height, pixels):
    """Interpolated mask alpha at (mx, my) in [0, 1].

    The mask is grayscale: color carries as much as alpha, so the smaller of the two is used.
    It is binary, so bilinear reading turns its staircase edge into the gradient the client
    gets by applying it at screen resolution.
    """
    x = mx * width - 0.5
    y = my * height - 0.5
    i0 = int(x) if x >= 0 else -1
    j0 = int(y) if y >= 0 else -1
    fx, fy = x - i0, y - j0

    def texel(i, j):
        if i < 0 or i >= width or j < 0 or j >= height:
            return 0                   # CLAMPTOBLACKADDITIVE: nothing outside
        base = (j * width + i) * 4
        return min(pixels[base], pixels[base + 3])

    a, b = texel(i0, j0), texel(i0 + 1, j0)
    c, d = texel(i0, j0 + 1), texel(i0 + 1, j0 + 1)
    top = a + (b - a) * fx
    down = c + (d - c) * fx
    return top + (down - top) * fy


def _read_bilinear(u, v, width, height, pixels):
    """Bilinear read of the four source channels at (u, v); edges clamp."""
    x = u * width - 0.5
    y = v * height - 0.5
    i0 = int(x) if x >= 0 else -1
    j0 = int(y) if y >= 0 else -1
    fx, fy = x - i0, y - j0

    def texel(i, j):
        i = 0 if i < 0 else (width - 1 if i >= width else i)
        j = 0 if j < 0 else (height - 1 if j >= height else j)
        b = (j * width + i) * 4
        return pixels[b], pixels[b + 1], pixels[b + 2], pixels[b + 3]

    a, b, c, d = (texel(i0, j0), texel(i0 + 1, j0),
                  texel(i0, j0 + 1), texel(i0 + 1, j0 + 1))
    output = []
    for k in range(4):
        top = a[k] + (b[k] - a[k]) * fx
        down = c[k] + (d[k] - c[k]) * fx
        output.append(int(top + (down - top) * fy + 0.5))
    return output


# Bakes the side tab mask into icon `name`; mask: (width, height, pixels) of MASK.
def bake(name, mask):
    source = os.path.join(INPUT, name)
    if not os.path.exists(source):
        return None

    src_w, src_h, source_px = _read(source)
    mw, mh, mpix = mask

    width, height = src_w * SCALE, src_h * SCALE
    pixels = bytearray(width * height * 4)

    half_w = TAB_W / 2.0
    left = ICON_X - ICON / 2.0
    top = ICON_Y + ICON / 2.0
    span = 1.0 - 2.0 * CROP
    step = 1.0 / (width * SUPER)       # one supersample step, in u

    for j in range(height):
        v = (j + 0.5) / height
        for i in range(width):
            u = (i + 0.5) / width
            base = (j * width + i) * 4

            if u < CROP or u > 1.0 - CROP or v < CROP or v > 1.0 - CROP:
                continue                # never shown: left at zero

            r, green, b, a = _read_bilinear(u, v, src_w, src_h, source_px)
            pixels[base:base + 3] = bytes((r, green, b))
            if a == 0:
                continue

            # Average SUPER x SUPER samples so the mask step becomes a gradient.
            total = 0
            for sj in range(SUPER):
                vv = v + (sj - (SUPER - 1) / 2.0) * step
                y = top - (vv - CROP) / span * ICON
                my = (MASK_H / 2.0 - y) / MASK_H
                for si in range(SUPER):
                    uu = u + (si - (SUPER - 1) / 2.0) * step
                    x = left + (uu - CROP) / span * ICON
                    mx = (x + half_w) / MASK_W
                    total += _mask_alpha(mx, my, mw, mh, mpix)

            pixels[base + 3] = int(a * total / (255.0 * SUPER * SUPER) + 0.5)

    target = os.path.join(OUTPUT, name)
    _write(target, width, height, pixels)
    return target


# ---------- Stat bar fills
#
# camelot clips the fill with common-stat-bar-Mask, anchored LEFT and RIGHT on the bar
# (stretched over its width) at its atlas height, 29. The fill is 15 high and covers the
# middle band, 7 to 22. Our bar background is sliced (10 px ends, stretched middle), not
# stretched, so the mask is sliced the same way and both outlines match.
GAUGE_W, GAUGE_H = 160.0, 29.0   # bar width and height
GAUGE_CORNER = 10.0   # same as the bar background
GAUGE_FILL_H = 15.0
# Output size must be a power of two (see _write). 512 x 32 holds more than twice the
# shown size, 160 x 15, and keeps texture coordinates at 0..1.
GAUGE_OUTPUT_W, GAUGE_OUTPUT_H = 512, 32

GAUGE_MASK = os.path.join(ART, "common", "commonstatbarmaskc60.blp")
FILL = os.path.join(ART, "common", "commonstatbarc60.blp")
# Fills in their sheet. camelot has four (SetFillTextureByColorType: red, green, blue,
# white). Reputation tints the white one with FACTION_BAR_COLORS; skills use the blue one
# as is, since UpdateBarColor only sets white.
FILLS = {
    "statbarfill": (0.003906, 0.941406, 0.406250, 0.523438),      # white
    "statbarfillblue": (0.003906, 0.941406, 0.007812, 0.125000),  # blue
}
GAUGE_OUTPUT_DIR = os.path.join(ART, "bars")


def _slice_coord(x, length, corner, source):
    """Texture coordinate of point `x` on a strip of `length`, in an image `source` wide that is
    sliced: its two `corner` ends keep their scale, only the middle stretches.
    """
    if x < corner:
        return x / source
    if x > length - corner:
        return (source - (length - x)) / source
    middle = (x - corner) / (length - 2.0 * corner)
    return (corner + middle * (source - 2.0 * corner)) / source


# Bakes fill `name` under the stat bar mask; rect: fill texcoords (u1, u2, v1, v2).
def bake_gauge(name, rect):
    if not os.path.exists(GAUGE_MASK) or not os.path.exists(FILL):
        print("   le masque ou la feuille de jauge manque")
        return None

    mw, mh, mpix = _read(GAUGE_MASK)
    fl, fh, fpix = _read(FILL)

    u1, u2, v1, v2 = rect
    width, height = GAUGE_OUTPUT_W, GAUGE_OUTPUT_H
    pixels = bytearray(width * height * 4)

    top = (GAUGE_H - GAUGE_FILL_H) / 2.0

    for j in range(height):
        v = (j + 0.5) / height
        y = top + v * GAUGE_FILL_H          # in bar space
        my = y / GAUGE_H
        for i in range(width):
            u = (i + 0.5) / width
            base = (i + j * width) * 4

            # Color comes from the fill, read in its sheet.
            r, green, b, a = _read_bilinear(u1 + (u2 - u1) * u,
                                             v1 + (v2 - v1) * v, fl, fh, fpix)
            pixels[base:base + 3] = bytes((r, green, b))
            if a == 0:
                continue

            mx = _slice_coord(u * GAUGE_W, GAUGE_W, GAUGE_CORNER, mw)
            m = _mask_alpha(mx, my, mw, mh, mpix)
            pixels[base + 3] = int(a * m / 255.0 + 0.5)

    target = os.path.join(GAUGE_OUTPUT_DIR, name + ".blp")
    _write(target, width, height, pixels)
    return target


# ---------- PvP ring gauge
#
# camelot uses a Cooldown with a custom SwipeTexture (pvpqueue-sidebar-honorbar-fill,
# reverse, rotation 180). 3.3.5 has no SetSwipeTexture and its Cooldown swipe is built into
# the engine, so the addon rebuilds the sweep with four quadrant textures: a full quadrant
# shows its quarter of the ring, and the last one shows a half ring rotated with the
# 8-argument SetTexCoord. A half ring rotated by phi covers the 180 degrees ending at phi;
# clipped by the quadrant rect, it gives the wanted arc.
#
# The bake guarantees what the source does not:
#   * The ring center is the image center, as rotation is around the quad center. The
#     source centroid is (64.0, 63.5) on 128, half a texel too high, so it is re-centered.
#   * The edges stay transparent: a rotated texture is read outside [0, 1] in the quad
#     corners, where the client repeats the edge texel. Outer radius 51 of 64 leaves a margin.
#   * The half ring keeps the left half (180 to 360 degrees clockwise from the top), cut
#     exactly on the axis.
PVP_GAUGE_SOURCE = os.path.join(ART, "pvpframe",
                                "pvpqueue-sidebar-honorbar-fill.blp")
PVP_OUTPUT_DIR = os.path.join(ART, "pvp")
PVP_GAUGE_OUTPUT_SIZE = 256      # power of two, twice the source


def _centroid(width, height, pixels):
    """Alpha-weighted center of the ring."""
    sx = sy = sa = 0.0
    for j in range(height):
        for i in range(width):
            a = pixels[(i + j * width) * 4 + 3]
            if a:
                sx += a * (i + 0.5)
                sy += a * (j + 0.5)
                sa += a
    if sa == 0.0:
        return width / 2.0, height / 2.0
    return sx / sa, sy / sa


def _read_premultiplied(x, y, width, height, pixels):
    """Bilinear texel with alpha-weighted color.

    x, y are in source texels, centered on (i + 0.5, j + 0.5). Empty texels of this image are
    white (255, 255, 255, 0); plain color interpolation would give the ring a light fringe,
    so color is interpolated premultiplied by alpha, then divided back.
    """
    i0 = int(math.floor(x - 0.5))
    j0 = int(math.floor(y - 0.5))
    fx = x - 0.5 - i0
    fy = y - 0.5 - j0

    def texel(i, j):
        i = 0 if i < 0 else (width - 1 if i >= width else i)
        j = 0 if j < 0 else (height - 1 if j >= height else j)
        b = (j * width + i) * 4
        return pixels[b], pixels[b + 1], pixels[b + 2], pixels[b + 3]

    corners = (texel(i0, j0), texel(i0 + 1, j0),
             texel(i0, j0 + 1), texel(i0 + 1, j0 + 1))
    weight = ((1.0 - fx) * (1.0 - fy), fx * (1.0 - fy),
             (1.0 - fx) * fy, fx * fy)

    r = v = b = a = 0.0
    for corner, p in zip(corners, weight):
        a += p * corner[3]
        r += p * corner[0] * corner[3]
        v += p * corner[1] * corner[3]
        b += p * corner[2] * corner[3]
    if a <= 0.0:
        return 0, 0, 0, 0
    return (int(r / a + 0.5), int(v / a + 0.5), int(b / a + 0.5),
            int(a + 0.5))


def bake_pvp_gauge():
    """Bakes the two gauge pieces: the whole ring and its left half."""
    if not os.path.exists(PVP_GAUGE_SOURCE):
        print("   le remplissage de la jauge pvp manque")
        return []

    sl, sh, spix = _read(PVP_GAUGE_SOURCE)
    cx, cy = _centroid(sl, sh, spix)
    print("   anneau pvp : %d x %d, centre (%.2f, %.2f)" % (sl, sh, cx, cy))

    size = PVP_GAUGE_OUTPUT_SIZE
    scale = float(sl) / size          # source texels per output texel
    whole = bytearray(size * size * 4)
    half = bytearray(size * size * 4)

    for j in range(size):
        y = (j + 0.5 - size / 2.0) * scale + cy
        for i in range(size):
            x = (i + 0.5 - size / 2.0) * scale + cx
            r, v, b, a = _read_premultiplied(x, y, sl, sh, spix)
            base = (i + j * size) * 4
            whole[base:base + 4] = bytes((r, v, b, a))
            # Left half, cut on the axis: columns whose center lies left of the canvas middle.
            if i + 0.5 < size / 2.0:
                half[base:base + 4] = bytes((r, v, b, a))

    done = []
    for name, pixels in (("honorfill", whole), ("honorfillhalf", half)):
        target = os.path.join(PVP_OUTPUT_DIR, name + ".blp")
        _write(target, size, size, pixels)
        done.append(target)
    return done


# ---------- Spellbook portrait
#
# camelot (PortraitFrameTemplate): the 62 x 62 portrait shows the whole icon
# (SetSpellBookPortrait: SetPortraitTexCoord(0, 1, 0, 1)). Its CircleMask,
# TempPortraitAlphaMask, is anchored TOPLEFT (2, 0) and BOTTOMRIGHT (-2, 4): a 58 x 58 disc,
# 2 px to the right, flush with the top. Outside the mask: CLAMPTOBLACKADDITIVE, nothing.
# The baked image covers the whole 62 x 62 square and is drawn at 0..1 in place of the portrait.
PORTRAIT = 62.0
PORTRAIT_MASK = (2.0, 0.0, 60.0, 58.0)    # left, top, right, bottom
PORTRAIT_OUTPUT_SIZE = 128
PORTRAIT_MASK_FILE = os.path.join(ART, "characterframe",
                                       "tempportraitalphamask.blp")
PORTRAITS = {"inv_misc_book_09.blp": os.path.join(ART, "spellbook",
                                                  "portrait.blp")}
# Talent portraits: the class icon (SetTalentPortrait, SetPortraitToClassIcon),
# in the same mask
for _class_name in ("deathknight", "druid", "hunter", "mage", "paladin",
                "priest", "rogue", "shaman", "warlock", "warrior"):
    PORTRAITS["classicon_%s.blp" % _class_name] = os.path.join(
        ART, "talents", "portrait_%s.blp" % _class_name)


# Bakes icon `name` into the round portrait mask and writes it to `target`.
def bake_portrait(name, target):
    source = os.path.join(INPUT, name)
    if not os.path.exists(source) or not os.path.exists(PORTRAIT_MASK_FILE):
        print("   l'icone ou le masque du portrait manque")
        return None

    sl, sh, spix = _read(source)
    mw, mh, mpix = _read(PORTRAIT_MASK_FILE)
    g, h, d, b = PORTRAIT_MASK
    size = PORTRAIT_OUTPUT_SIZE
    pixels = bytearray(size * size * 4)
    step = 1.0 / (size * SUPER)

    for j in range(size):
        v = (j + 0.5) / size
        for i in range(size):
            u = (i + 0.5) / size
            base = (j * size + i) * 4
            r, green, bl, a = _read_bilinear(u, v, sl, sh, spix)
            pixels[base:base + 3] = bytes((r, green, bl))
            if a == 0:
                continue
            total = 0
            for sj in range(SUPER):
                y = (v + (sj - (SUPER - 1) / 2.0) * step) * PORTRAIT
                for si in range(SUPER):
                    x = (u + (si - (SUPER - 1) / 2.0) * step) * PORTRAIT
                    mx, my = (x - g) / (d - g), (y - h) / (b - h)
                    # outside the mask: nothing (no extrapolation)
                    if 0.0 <= mx <= 1.0 and 0.0 <= my <= 1.0:
                        total += _mask_alpha(mx, my, mw, mh, mpix)
            pixels[base + 3] = int(a * total / (255.0 * SUPER * SUPER) + 0.5)

    _write(target, size, size, pixels)
    return target


def main():
    if not os.path.exists(MASK):
        raise SystemExit("le masque manque : %s   # le faire entrer avec "
                         "tools/add_sheets.py" % MASK)

    mask = _read(MASK)
    print("masque : %d x %d" % (mask[0], mask[1]))

    done = 0
    for name in ICONS:
        target = bake(name, mask)
        if target is None:
            print("   ABSENTE %s" % name)
            continue
        print("   %-60s %8d o" % (os.path.relpath(target, ROOT),
                                  os.path.getsize(target)))
        done += 1

    for name in sorted(FILLS):
        gauge = bake_gauge(name, FILLS[name])
        if gauge:
            print("   %-60s %8d o" % (os.path.relpath(gauge, ROOT),
                                      os.path.getsize(gauge)))

    for gauge in bake_pvp_gauge():
        print("   %-60s %8d o" % (os.path.relpath(gauge, ROOT),
                                  os.path.getsize(gauge)))

    for name in sorted(PORTRAITS):
        target = bake_portrait(name, PORTRAITS[name])
        if target:
            print("   %-60s %8d o" % (os.path.relpath(target, ROOT),
                                      os.path.getsize(target)))

    print("%d icone(s) cuite(s) ; poser dans le client avec tools/deploy.py" % done)


if __name__ == "__main__":
    main()
