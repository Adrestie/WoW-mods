# -*- coding: utf-8 -*-
# This file is part of mod-spheregrid.
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

r"""The statistic map: ONE BIT PER STATISTIC, and rings for the qualities.

The generator does not decide where the statistics go: it READS an image. Every
cell of a layout falls on a pixel of that image, and the pixel says which
statistics may land there.

A STATISTIC IS ONE BIT of one channel, so a pixel carries as many as you like:
intellect + spell power + spirit is blue at 1 | 2 | 4 = 7. Black -- no bit at
all -- means "no preference", and the generator lays the binding statistics
there (haste, critical strike, hit).

    RED (offence, physical)          GREEN (defence, then the binders)
      1  strength                      1  stamina        16  haste
      2  agility                       2  dodge          32  crit
      4  attack power                  4  parry          64  hit
      8  expertise                     8  block
     16  armor penetration
                                     BLUE (magic and healing)
                                       1  intellect       4  spirit
                                       2  spell power     8  healing bonus

A pixel that carries several offers them in equal measure; it is the DENSITY of
the paint -- falloff, scatter, stipple -- that doses one zone against another.

THE QUALITY IS NOT PAINTED. It follows the distance to a centre, in five bands
whose thicknesses travel INSIDE the png (a text chunk), so a map copied carries
its rings with it. The centre travels with them: the middle of the map is only
the default, and a grid whose heart sits off-centre wants its rings there too.

The saved image is almost black to the eye -- a bit is worth 1, 2, 4 -- so the
editor shows a FALSE COLOUR, the brighter the more bits a pixel carries.
"""
import math

SIZE = 2048

# (statistic, channel, bit) -- THE table the brush and the generator read. The
# keys are the module's own, the ones the XML carries.
PALETTE = [
    ("strength",          "R", 1),
    ("agility",           "R", 2),
    ("attack_power",      "R", 4),
    ("expertise",         "R", 8),
    ("armor_penetration", "R", 16),
    ("stamina",           "G", 1),
    ("dodge",             "G", 2),
    ("parry",             "G", 4),
    ("block",             "G", 8),
    ("haste",             "G", 16),
    ("crit",              "G", 32),
    ("hit",               "G", 64),
    ("intellect",         "B", 1),
    ("spell_power",       "B", 2),
    ("spirit",            "B", 4),
    ("bonus_healing",     "B", 8),
]

CHANNELS = {"R": 0, "G": 1, "B": 2}
BITS_PER_CHANNEL = {"R": 5, "G": 7, "B": 4}

# What a channel looks like on screen: red for offence, green for defence,
# blue for magic. The false colour mixes the three.
TINT = {"R": (255, 90, 70), "G": (90, 230, 120), "B": (110, 160, 255)}

# EACH STATISTIC ITS OWN SHADE, inside the family of its channel. A pixel that
# carries one of them is drawn in that shade, so a painted map can be read
# statistic by statistic instead of channel by channel; a pixel that carries
# several takes the average of theirs, brightened by how many it holds.
STAT_COLOURS = {
    "strength":          (255, 90, 70),
    "agility":           (255, 154, 60),
    "attack_power":      (255, 59, 107),
    "expertise":         (255, 184, 107),
    "armor_penetration": (217, 79, 43),
    "stamina":           (74, 222, 128),
    "dodge":             (126, 231, 135),
    "parry":             (46, 194, 126),
    "block":             (163, 230, 53),
    "haste":             (52, 211, 153),
    "crit":              (134, 239, 172),
    "hit":               (22, 200, 90),
    "intellect":         (106, 169, 255),
    "spell_power":       (167, 139, 250),
    "spirit":            (56, 189, 248),
    "bonus_healing":     (196, 181, 253),
}

# The statistics the generator lays on unpainted ground.
BINDERS = ("haste", "crit", "hit")

# Five bands, as a percentage of the radius, from the centre outwards.
DEFAULT_BANDS = [20.0, 20.0, 20.0, 20.0, 20.0]
BANDS_KEY = "qualities"
CENTRE_KEY = "quality_centre"
QUALITY_COLOURS = {1: (157, 157, 157), 2: (30, 255, 0), 3: (0, 112, 221),
                   4: (163, 53, 238), 5: (255, 128, 0)}


def bits_of(stat):
    """The channel and the bit that carry that statistic."""
    for key, channel, bit in PALETTE:
        if key == stat:
            return channel, bit
    return None, 0


def decode(pixel):
    """The statistics a raw pixel carries."""
    out = []
    for key, channel, bit in PALETTE:
        if pixel[CHANNELS[channel]] & bit:
            out.append(key)
    return out


# ---------------------------------------------------------------------------
# The quality rings
# ---------------------------------------------------------------------------
def read_bands(image):
    """The five thicknesses an open image carries, or the default."""
    text = getattr(image, "text", {}).get(BANDS_KEY)
    if not text:
        return list(DEFAULT_BANDS)
    try:
        values = [max(0.0, float(v)) for v in text.split(",")]
    except ValueError:
        return list(DEFAULT_BANDS)
    return (values + list(DEFAULT_BANDS))[:5]


def read_centre(image):
    """Where the rings are centred, in fractions of the map (0..1), the middle
    by default."""
    text = getattr(image, "text", {}).get(CENTRE_KEY)
    if not text:
        return (0.5, 0.5)
    try:
        x, y = (float(v) for v in text.split(","))
        return (min(1.0, max(0.0, x)), min(1.0, max(0.0, y)))
    except ValueError:
        return (0.5, 0.5)


def png_info(bands, centre=(0.5, 0.5)):
    from PIL import PngImagePlugin
    info = PngImagePlugin.PngInfo()
    info.add_text(BANDS_KEY, ",".join("%.3f" % v for v in bands))
    info.add_text(CENTRE_KEY, "%.5f,%.5f" % (centre[0], centre[1]))
    return info


def quality_radii(bands, size):
    """The OUTER radius of each of the five rings, in pixels."""
    top = size / 2.0
    radii, running = [], 0.0
    for thickness in bands:
        running += thickness / 100.0 * top
        radii.append(running)
    return radii


def quality_at(px, py, size, bands, centre=(0.5, 0.5)):
    """The quality of a pixel: 1 at the heart, 5 at the edge."""
    distance = math.hypot(px - centre[0] * size, py - centre[1] * size)
    for index, radius in enumerate(quality_radii(bands, size)):
        if distance <= radius:
            return index + 1
    return 5


# ---------------------------------------------------------------------------
# Seeing it
# ---------------------------------------------------------------------------
def display_tables():
    """Per channel, raw value -> the colour it is drawn in.

    Zero stays black. One bit takes the statistic's own shade, so a map can be
    read statistic by statistic; several take the average of theirs, brightened
    and washed towards white as the count climbs -- which is how a mixed zone
    tells itself apart from a plain one.
    """
    import numpy as np
    tables = {}
    for channel, count in BITS_PER_CHANNEL.items():
        held = [(bit, STAT_COLOURS[key]) for key, where, bit in PALETTE
                if where == channel]
        lut = np.zeros((256, 3), dtype=np.uint8)
        for value in range(1, 256):
            carried = [colour for bit, colour in held if value & bit]
            if not carried:
                continue
            share = (len(carried) - 1) / float(max(1, count - 1))
            for index in range(3):
                average = sum(colour[index] for colour in carried) / len(carried)
                # One statistic is drawn in its own colour, exactly; a mixture
                # is their average, washed towards white as it thickens.
                lut[value, index] = min(255, int(average + 70 * share))
        tables[channel] = lut
    return tables


def mask_of(stats):
    """The bits those statistics hold, channel by channel: what is left when a
    layer is hidden."""
    out = dict((channel, 0) for channel in CHANNELS)
    for stat in stats:
        channel, bit = bits_of(stat)
        if bit:
            out[channel] |= bit
    return out


def display(planes, mask=None):
    """The three raw planes (H, W) -> an RGB image in false colour.

    `mask` says which bits of a channel may be seen. A statistic whose layer is
    hidden keeps its bit in the image -- looking at a map does not change it --
    but nothing of it is drawn.
    """
    import numpy as np
    from PIL import Image
    luts = display_tables()
    if mask is not None:
        planes = [np.bitwise_and(plane, mask.get(channel, 0))
                  for channel, plane in zip(("R", "G", "B"), planes)]
    mixed = None
    for channel, plane in zip(("R", "G", "B"), planes):
        painted = luts[channel][plane].astype(np.int32)
        mixed = painted if mixed is None else mixed + painted
    return Image.fromarray(np.clip(mixed, 0, 255).astype(np.uint8))


def blank(size=SIZE):
    """A map with nothing painted on it."""
    import numpy as np
    from PIL import Image
    return Image.fromarray(np.zeros((size, size, 3), dtype=np.uint8), "RGB")
