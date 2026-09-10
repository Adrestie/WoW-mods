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

r"""Where a cell stands, and how the grid meets the map.

A CLUSTER IS THREE RINGS OF EIGHT. The eight cells of a ring share their angles
with the other rings, so they line up along eight branches radiating from the
centre, like a star. Ring 0 is the middle and has one cell, branch 1.

    chord within a ring: 2 R sin(22.5 deg)  ->  0.84 / 1.61 / 2.37
    gap between rings:                          1.00 / 1.00

The tightest point is the chord of the inner ring, at 0.84, which is why two
cells are never allowed closer than SEPARATION. THESE RADII ARE THE EDITOR'S
(`Editor.lua`): changing one moves every cell of every layout already saved.

THE MAP covers the square the grid sits in, with half a step of margin. That
correspondence is defined once, here, and both the painter and the generator
read it -- a map painted against one frame and read against another would put
every statistic in the wrong place.
"""
import math
from collections import deque

RADII = (0.0, 1.1, 2.1, 3.1)        # by ring; ring 0 is the centre
BRANCHES = 8
STEP = 8.0                          # the lattice the clusters are laid on
SEPARATION = 0.70                   # the smallest gap tolerated between cells
CLEARANCE = 0.60                    # how close a link may pass to a cell it does not join
MARGIN = STEP / 2.0


def position(cluster, ring, branch):
    """A cell's place in the world, from its cluster and its seat in it."""
    if ring <= 0:
        return cluster["x"], cluster["y"]
    angle = (branch - 1) * (2.0 * math.pi / BRANCHES) + cluster.get("rot", 0.0)
    radius = RADII[ring] if ring < len(RADII) else RADII[-1]
    return (cluster["x"] + radius * math.cos(angle),
            cluster["y"] + radius * math.sin(angle))


def positions(layout):
    """Every cell's place, by cell id."""
    clusters = layout.cluster_by_id()
    out = {}
    for cell in layout.cells:
        c = clusters.get(cell.cluster)
        if c is not None:
            out[cell.id] = position(c, cell.ring, cell.branch)
    return out


def frame(clusters):
    """The square (x0, y0, side) the map covers."""
    if not clusters:
        return -MARGIN, -MARGIN, 2 * MARGIN
    xs = [c["x"] for c in clusters]
    ys = [c["y"] for c in clusters]
    x0, x1 = min(xs) - RADII[-1] - MARGIN, max(xs) + RADII[-1] + MARGIN
    y0, y1 = min(ys) - RADII[-1] - MARGIN, max(ys) + RADII[-1] + MARGIN
    side = max(x1 - x0, y1 - y0)
    return (x0 + x1 - side) / 2.0, (y0 + y1 - side) / 2.0, side


def to_map(x, y, box, size):
    """A place in the world -> a pixel of the map.

    THE WORLD'S Y GOES UP, AN IMAGE'S GOES DOWN. The game anchors its cells to
    the bottom left of its canvas, so a cell of greater y stands HIGHER, while
    a picture numbers its rows from the top. The turn is made here, once, and
    everything that paints or reads the map goes through it -- the map, the
    window and the game then agree on which way is up.
    """
    x0, y0, side = box
    return (int((x - x0) / side * size),
            int((1.0 - (y - y0) / side) * size))


def to_world(px, py, box, size):
    """A pixel of the map -> a place in the world."""
    x0, y0, side = box
    return (x0 + (px + 0.5) / size * side,
            y0 + (1.0 - (py + 0.5) / size) * side)


# ---------------------------------------------------------------------------
# The graph
# ---------------------------------------------------------------------------
def adjacency(layout):
    out = dict((c.id, []) for c in layout.cells)
    for a, b in layout.links:
        if a in out and b in out:
            out[a].append(b)
            out[b].append(a)
    return out


def reachable(layout, roots):
    """Every cell one can walk to from those cells, following the links."""
    near = adjacency(layout)
    seen = set(r for r in roots if r in near)
    queue = deque(seen)
    while queue:
        for other in near[queue.popleft()]:
            if other not in seen:
                seen.add(other)
                queue.append(other)
    return seen


def components(layout):
    """The islands: cells that can reach each other and nobody else."""
    near = adjacency(layout)
    seen, out = set(), []
    for cell in layout.cells:
        if cell.id in seen:
            continue
        island = reachable(layout, [cell.id])
        seen |= island
        out.append(island)
    return out


def overlapping_links(layout, tolerance=1e-3):
    """Links that lie on top of one another over a stretch, not merely at an
    end they share.

    THREE CELLS IN A ROW ARE THE USUAL CASE: A to B, B to C, and A to C as
    well. The long one runs over both short ones, and a player reading the
    grid cannot tell what is joined to what. Two links that only touch at a
    cell they have in common are not overlapping -- that is every junction in
    the grid.

    Segments are gathered by the INFINITE LINE they lie on, which is what
    makes this cheap: only the handful sharing a line are ever compared.
    """
    places = positions(layout)
    lines = {}
    for a, b in layout.links:
        if a not in places or b not in places:
            continue
        (x1, y1), (x2, y2) = places[a], places[b]
        dx, dy = x2 - x1, y2 - y1
        length = math.hypot(dx, dy)
        if length <= 0:
            continue
        dx, dy = dx / length, dy / length
        # One direction per line, so that A to B and B to A land together.
        if (dx < 0) or (abs(dx) < 1e-9 and dy < 0):
            dx, dy = -dx, -dy
        key = (round(dx / tolerance), round(dy / tolerance),
               round((dx * y1 - dy * x1) / tolerance))
        first, second = dx * x1 + dy * y1, dx * x2 + dy * y2
        lines.setdefault(key, []).append(
            (min(first, second), max(first, second), a, b))

    out = []
    for group in lines.values():
        if len(group) < 2:
            continue
        group.sort()
        for index, (low, high, a, b) in enumerate(group):
            for other in group[index + 1:]:
                if other[0] >= high - tolerance:
                    break               # sorted: the rest start even further
                shared = {a, b} & {other[2], other[3]}
                if min(high, other[1]) - max(low, other[0]) > tolerance:
                    out.append(((a, b), (other[2], other[3]), bool(shared)))
    return out


def links_over_cells(layout, clearance=CLEARANCE):
    """Links that pass over a cell they do not join -- the same fault seen
    from the cell's side: a line drawn straight through a place a player is
    meant to be able to stop at."""
    places = positions(layout)
    grid = {}
    for cell_id, (x, y) in places.items():
        grid.setdefault((int(x // 4), int(y // 4)), []).append(cell_id)
    out = []
    for a, b in layout.links:
        if a not in places or b not in places:
            continue
        first, second = places[a], places[b]
        low_x, high_x = sorted((first[0], second[0]))
        low_y, high_y = sorted((first[1], second[1]))
        near = set()
        for i in range(int(low_x // 4) - 1, int(high_x // 4) + 2):
            for j in range(int(low_y // 4) - 1, int(high_y // 4) + 2):
                near.update(grid.get((i, j), ()))
        for cell_id in near:
            if cell_id in (a, b):
                continue
            if _distance_to(places[cell_id], first, second) < clearance:
                out.append(((a, b), cell_id))
    return out


def _distance_to(point, a, b):
    """How close a point passes to a segment."""
    (ax, ay), (bx, by), (px, py) = a, b, point
    dx, dy = bx - ax, by - ay
    span = dx * dx + dy * dy
    if span <= 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / span))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def shortest_path(layout, source, target):
    """The fewest cells from one to the other, source and target included, or
    an empty list when no chain of links joins them."""
    if source == target:
        return [source]
    near = adjacency(layout)
    if source not in near or target not in near:
        return []
    came = {source: None}
    queue = deque([source])
    while queue:
        here = queue.popleft()
        for other in near[here]:
            if other in came:
                continue
            came[other] = here
            if other == target:
                path = [other]
                while came[path[-1]] is not None:
                    path.append(came[path[-1]])
                path.reverse()
                return path
            queue.append(other)
    return []
