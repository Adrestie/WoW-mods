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

r"""The map one paints, and the pass that reads it into the grid.

A DRAWING TOOL WOULD NOT DO. Its soft brushes make intermediate values that
answer to no statistic, and nothing stops it laying down red 137. Here one does
not choose a colour, one chooses a STATISTIC: the channel and the bit follow,
and nothing else can be written into the image.

THE BRUSH DOES NOT SOFTEN THE VALUE, IT SOFTENS THE DENSITY. At a falloff of
zero the dab is a hard disc; at one, the chance of laying a pixel falls from
the middle to the rim, and the rim becomes a stipple -- which is the transition
the reading pass wants, without ever writing a shade that is not in the
palette. The scatter throws each dab about the cursor, like an airbrush.

PAINTING A STATISTIC LAYS ITS BIT ONLY. Critical strike over attack power, or
spirit over intellect, leaves the rest where it was and the pixel carries both:
that is how a mixed zone is made. Erasing takes back the one bit chosen.

THE MAP TRAVELS WITH THE LAYOUT: same folder, same name, `.png` instead of
`.xml`. The quality rings and their centre travel inside the png itself.
"""
import math
import os
import random
from collections import defaultdict, deque

from . import geometry, palette, xmlio

JITTER = 6                  # pixels of shuffle when a cell reads the map
EMPTY_INNER_RING = 0.22     # the buffer of empty cells around a cluster's heart

# Without a map, the quality follows the depth: the pyramid the hand-drawn
# sheets showed -- 48 % common, 29 % uncommon, 15 % rare, 8 % epic and the rest
# legendary -- the deepest cells taking the best.
PYRAMID = (0.48, 0.77, 0.92, 0.985)


def map_path(layout_path):
    """The map that belongs to that layout."""
    return os.path.splitext(layout_path)[0] + ".png"


class StatMap(object):
    """The painted image: three planes of bits, five bands, and a centre."""

    def __init__(self, pixels, bands=None, centre=(0.5, 0.5)):
        self.pixels = pixels                       # numpy (size, size, 3) uint8
        self.bands = list(bands or palette.DEFAULT_BANDS)
        self.centre = tuple(centre)

    @property
    def size(self):
        return self.pixels.shape[0]

    @classmethod
    def blank(cls, size=palette.SIZE):
        import numpy as np
        return cls(np.zeros((size, size, 3), dtype=np.uint8))

    @classmethod
    def load(cls, path):
        import numpy as np
        from PIL import Image
        raw = Image.open(path)
        bands, centre = palette.read_bands(raw), palette.read_centre(raw)
        return cls(np.array(raw.convert("RGB"), dtype=np.uint8), bands, centre)

    def save(self, path):
        from PIL import Image
        Image.fromarray(self.pixels, "RGB").save(
            path, pnginfo=palette.png_info(self.bands, self.centre))
        return path

    # -- the brush ----------------------------------------------------------
    def dab(self, x, y, radius, stats, falloff=1.0, scatter=0.0, remove=False,
            rng=None):
        """One touch of the brush, in pixels. Returns how many pixels changed.

        SEVERAL STATISTICS AT ONCE lay their bits on the SAME pixels: the
        stipple is drawn once and every layer selected takes it, so a zone
        painted with three of them offers all three in equal measure rather
        than three patterns laid over one another.
        """
        if isinstance(stats, str):
            stats = [stats]
        marks = []
        for stat in stats:
            channel, bit = palette.bits_of(stat)
            if bit:
                marks.append((palette.CHANNELS[channel], bit))
        if not marks:
            return 0
        rng = rng or random
        size = self.size
        if scatter:
            angle = rng.random() * 2 * math.pi
            reach = rng.random() * scatter * radius
            x += reach * math.cos(angle)
            y += reach * math.sin(angle)
        left, right = int(max(0, x - radius)), int(min(size - 1, x + radius))
        top, bottom = int(max(0, y - radius)), int(min(size - 1, y + radius))
        touched = 0
        for py in range(top, bottom + 1):
            for px in range(left, right + 1):
                distance = math.hypot(px - x, py - y)
                if distance > radius:
                    continue
                if falloff > 0 and radius > 0:
                    # The density falls from the middle to the rim; the rim
                    # becomes a stipple rather than a shade.
                    keep = 1.0 - falloff * (distance / radius)
                    if rng.random() > max(0.0, keep):
                        continue
                for plane, bit in marks:
                    before = self.pixels[py, px, plane]
                    self.pixels[py, px, plane] = ((before & ~bit) if remove
                                                  else (before | bit))
                    touched += int(self.pixels[py, px, plane] != before)
        return touched

    def quality_at(self, px, py):
        return palette.quality_at(px, py, self.size, self.bands, self.centre)

    def preview(self, mask=None):
        """The whole map in false colour, as a PIL image. `mask` leaves the
        hidden layers out of the drawing."""
        return palette.display([self.pixels[:, :, i] for i in range(3)], mask)


# ---------------------------------------------------------------------------
# The map, read into a grid
# ---------------------------------------------------------------------------
def lattice_of(layout):
    """Each cluster back on the lattice it was laid on."""
    out = {}
    for cluster in layout.clusters:
        out[cluster["id"]] = (int(round(cluster["x"] / geometry.STEP)),
                              int(round(cluster["y"] / geometry.STEP)))
    return out


def depth(layout):
    """How far a cell stands from the EDGE of the grid, in links.

    The doors are on the rim and the heart is the endgame, so depth is counted
    inwards: a cell of the outer ring of an edge cluster is at zero.
    """
    seats = lattice_of(layout)
    around = defaultdict(int)
    for a in seats.values():
        for b in seats.values():
            if a != b and max(abs(a[0] - b[0]), abs(a[1] - b[1])) == 1:
                around[a] += 1
    edge = set(cluster for cluster, seat in seats.items() if around[seat] < 8)

    near = geometry.adjacency(layout)
    out, queue = {}, deque()
    for cell in layout.cells:
        if cell.cluster in edge and cell.ring == 3:
            out[cell.id] = 0
            queue.append(cell.id)
    if not queue:                       # a grid too small to have an inside
        for cell in layout.cells:
            out[cell.id] = 0
        return out
    while queue:
        here = queue.popleft()
        for other in near.get(here, ()):
            if other not in out:
                out[other] = out[here] + 1
                queue.append(other)
    return out


def assign(layout, stat_map=None, seed=1, overwrite_spells=False,
           empty_inner=EMPTY_INNER_RING):
    """What every cell grants, drawn again. THE LINKS ARE NOT TOUCHED.

    A socket is left alone -- it holds no statistic and it is part of the
    drawing. A spell cell is left alone too unless it is given up on purpose:
    a spell was placed by hand, and a repaint should not sweep it away.
    """
    rng = random.Random(seed)
    box = geometry.frame(layout.clusters)
    places = geometry.positions(layout)
    size = stat_map.size if stat_map is not None else palette.SIZE

    def statistic(x, y):
        if stat_map is None:
            return rng.choice(palette.BINDERS)
        px, py = geometry.to_map(x, y, box, size)
        px += int(rng.uniform(-JITTER, JITTER))
        py += int(rng.uniform(-JITTER, JITTER))
        px = max(0, min(size - 1, px))
        py = max(0, min(size - 1, py))
        carried = palette.decode(stat_map.pixels[py, px])
        # Black is no preference: the binders live there.
        return rng.choice(carried) if carried else rng.choice(palette.BINDERS)

    # Without a map, the quality follows the depth rank rather than a ring.
    ranks = {}
    if stat_map is None:
        deep = depth(layout)
        order = sorted(deep, key=lambda i: (deep[i], rng.random()))
        for index, cell_id in enumerate(order):
            ranks[cell_id] = index / float(max(1, len(order) - 1))

    def quality(cell_id, x, y):
        if stat_map is not None:
            px, py = geometry.to_map(x, y, box, size)
            return stat_map.quality_at(px, py)
        rank = ranks.get(cell_id, 0.0) + rng.gauss(0.0, 0.05)
        for index, edge in enumerate(PYRAMID):
            if rank < edge:
                return index + 1
        return 5

    changed = 0
    for cell in layout.cells:
        if cell.kind == xmlio.SLOT:
            continue
        if cell.kind == xmlio.SPELL:
            if not overwrite_spells:
                continue
            cell.kind = xmlio.NODE
            cell.spell, cell.spells = 0, {}
        place = places.get(cell.id)
        if not place:
            continue
        # A BUFFER AROUND THE HEART: a share of the inner ring is left empty,
        # as the hand-drawn sheets had it.
        if cell.ring == 1 and rng.random() < empty_inner:
            cell.stat, cell.quality = None, 1
        else:
            cell.stat = statistic(place[0], place[1])
            cell.quality = quality(cell.id, place[0], place[1])
        changed += 1
    return changed
