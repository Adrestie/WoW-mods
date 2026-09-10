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

r"""A layout drawn from the bank: the shapes and the links, and nothing else.

WHAT COMES OUT HAS NO STATISTICS AND NO QUALITIES. A grid is made in two
breaths -- the drawing first, what it grants afterwards -- and this is the
first: clusters laid on the lattice, each wearing a shape taken from the bank,
their internal links kept as they were drawn, and bridges enough that the whole
thing is ONE island. The statistics are painted and read later.

THE UNIT IS THE PIECE, NOT THE CLUSTER. A bank shape can fall in two halves
with no link between them; a bridge to each half joins the cluster to the rest,
but the two halves stay strangers and the grid tears along them. So the
spanning tree is drawn over the PIECES, and the connectivity is checked on
them.

A BRIDGE NEVER CROSSES ANOTHER LINK, and never brushes past a cell closer than
the clearance. Everything else is relaxed by steps until the grid holds
together: the ring a bridge may leave from, its length, the clearance, and how
far a neighbour may be. The crossing is the one rule that never gives.
"""
import math
import random
from collections import defaultdict, deque

from . import geometry, xmlio

BRANCHES = geometry.BRANCHES
STEP = geometry.STEP
CLEARANCE = geometry.CLEARANCE   # how close a bridge may pass to a cell it does not join
LOOP_SHARE = 0.25            # bridges added on top of the spanning tree


# ---------------------------------------------------------------------------
# The bank
# ---------------------------------------------------------------------------
def read_bank(path):
    """The shapes, weighted by how often they were drawn.

    The bank is a layout like any other and opens in the editor. Only its
    INTERNAL links are read: the bridges it carries are there to keep the
    check green, and say nothing about a shape.
    """
    bank = xmlio.read(path)
    seat_of = dict((c.id, (c.cluster, c.ring, c.branch)) for c in bank.cells)
    places = defaultdict(list)
    links = defaultdict(list)
    for cell in bank.cells:
        places[cell.cluster].append((cell.ring, cell.branch))
    for a, b in bank.links:
        first, second = seat_of.get(a), seat_of.get(b)
        if first and second and first[0] == second[0]:
            links[first[0]].append((first[1:], second[1:]))

    weighed = {}
    for cluster, seats in places.items():
        key = (tuple(sorted(seats)),
               tuple(sorted(tuple(sorted(pair)) for pair in links.get(cluster, []))))
        weighed[key] = weighed.get(key, 0) + 1
    return [(list(seats), list(inside), float(weight))
            for (seats, inside), weight in weighed.items()]


def sizes(bank):
    """How many cells each shape holds: what the bounds are chosen from."""
    return sorted(set(len(seats) for seats, _, _ in bank))


def within(bank, low, high):
    """The shapes that hold between low and high cells."""
    return [shape for shape in bank if low <= len(shape[0]) <= high]


def estimate(bank, count, low, high):
    """About how many cells a grid of that many clusters would hold. The bank
    is weighted, so the average is weighted too."""
    kept = within(bank, low, high)
    if not kept:
        return 0
    total = sum(len(seats) * weight for seats, _, weight in kept)
    weight = sum(weight for _, _, weight in kept)
    return int(round(count * total / weight))


# ---------------------------------------------------------------------------
# The lattice, and the geometry of a bridge
# ---------------------------------------------------------------------------
def lattice(rng, count):
    """Where the clusters stand: a blob grown around the origin, round but not
    smooth. Without the noise the edge would be a circle drawn with a compass.
    """
    taken = {(0, 0)}
    while len(taken) < count:
        edge = set()
        for (i, j) in taken:
            for di in (-1, 0, 1):
                for dj in (-1, 0, 1):
                    if (di or dj) and (i + di, j + dj) not in taken:
                        edge.add((i + di, j + dj))
        taken.add(min(edge, key=lambda c: math.hypot(*c) + rng.random() * 1.6))
    return sorted(taken)


def neighbours(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1])) == 1


def rotate(seat, turns):
    ring, branch = seat
    return (ring, 1 if ring == 0 else ((branch - 1 + turns) % BRANCHES) + 1)


def pieces_of(seats, links):
    """The chunks of a shape: seats that reach each other and nobody else."""
    near = defaultdict(list)
    for a, b in links:
        near[a].append(b)
        near[b].append(a)
    seen, blocks = set(), []
    for seat in seats:
        if seat in seen:
            continue
        block, queue = {seat}, deque([seat])
        while queue:
            for other in near[queue.popleft()]:
                if other not in block:
                    block.add(other)
                    queue.append(other)
        seen |= block
        blocks.append(sorted(block))
    return blocks


def _side(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def crosses(p1, p2, p3, p4):
    """Two segments that meet anywhere but at an end they share."""
    if p1 in (p3, p4) or p2 in (p3, p4):
        return False
    d1, d2 = _side(p3, p4, p1), _side(p3, p4, p2)
    d3, d4 = _side(p1, p2, p3), _side(p1, p2, p4)
    return ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0))


def segment_distance(point, a, b):
    """How close a point passes to a segment."""
    ax, ay = a
    bx, by = b
    px, py = point
    dx, dy = bx - ax, by - ay
    span = dx * dx + dy * dy
    if span <= 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / span))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


# ---------------------------------------------------------------------------
# The drawing
# ---------------------------------------------------------------------------
def generate(bank, count=128, seed=1, low=None, high=None, name="untitled"):
    """A layout of `count` clusters, wearing shapes drawn from the bank."""
    every = sizes(bank)
    low = every[0] if low is None else low
    high = every[-1] if high is None else high
    kept = within(bank, low, high)
    if not kept:
        raise ValueError("no shape in the bank holds between %d and %d cells"
                         % (low, high))

    rng = random.Random(seed)
    cells = lattice(rng, count)

    weight = sum(w for _, _, w in kept)
    seats_of, links_of = {}, {}
    for lattice_cell in cells:
        draw, running = rng.random() * weight, 0.0
        for seats, inside, one in kept:
            running += one
            if running >= draw:
                break
        turns = rng.randrange(BRANCHES)
        seats_of[lattice_cell] = sorted(rotate(s, turns) for s in seats)
        links_of[lattice_cell] = [(rotate(a, turns), rotate(b, turns))
                                  for a, b in inside]

    def place(lattice_cell, seat):
        cluster = {"x": lattice_cell[0] * STEP, "y": lattice_cell[1] * STEP,
                   "rot": 0.0}
        return geometry.position(cluster, seat[0], seat[1])

    points = [place(c, s) for c in cells for s in seats_of[c]]
    segments = [(place(c, a), place(c, b)) for c in cells for a, b in links_of[c]]

    chunks = dict((c, pieces_of(seats_of[c], links_of[c])) for c in cells)
    parts = [(c, k) for c in cells for k in range(len(chunks[c]))]
    parent = dict((p, p) for p in parts)

    def root(part):
        while parent[part] != part:
            parent[part] = parent[parent[part]]
            part = parent[part]
        return part

    def apart():
        return len(set(root(p) for p in parts))

    def find(ca, cb, only_a=None, only_b=None, ring_min=2, longest=7.5,
             clearance=CLEARANCE):
        """The best pair of seats to bridge, or nothing. A bridge leaves the
        outer ring where it can, as the hand-drawn sheets did, and never
        crosses a link."""
        candidates = []
        for sa in seats_of[ca]:
            if sa[0] < ring_min or (only_a is not None and sa not in only_a):
                continue
            for sb in seats_of[cb]:
                if sb[0] < ring_min or (only_b is not None and sb not in only_b):
                    continue
                a, b = place(ca, sa), place(cb, sb)
                span = math.hypot(a[0] - b[0], a[1] - b[1])
                penalty = (0.0 if sa[0] == 3 else 0.8) + (0.0 if sb[0] == 3 else 0.8)
                candidates.append((span + penalty, span, sa, sb, a, b))
        candidates.sort()
        for _, span, sa, sb, a, b in candidates:
            if span > longest:
                break
            if any(crosses(a, b, s[0], s[1]) for s in segments):
                continue
            if any(segment_distance(p, a, b) < clearance for p in points
                   if p != a and p != b):
                continue
            return sa, sb
        return None

    bridges = []

    def lay(ca, cb, sa, sb):
        bridges.append((ca, cb, sa, sb))
        segments.append((place(ca, sa), place(cb, sb)))
        ka = next(k for k, block in enumerate(chunks[ca]) if sa in block)
        kb = next(k for k, block in enumerate(chunks[cb]) if sb in block)
        ra, rb = root((ca, ka)), root((cb, kb))
        if ra != rb:
            parent[ra] = rb

    pairs = [(a, b) for i, a in enumerate(cells) for b in cells[i + 1:]
             if neighbours(a, b)]

    def weigh(edge):
        diagonal = (abs(edge[0][0] - edge[1][0]) == 1
                    and abs(edge[0][1] - edge[1][1]) == 1)
        return rng.random() + (0.6 if diagonal else 0.0)

    pairs.sort(key=weigh)
    for a, b in pairs:
        for ka, block_a in enumerate(chunks[a]):
            for kb, block_b in enumerate(chunks[b]):
                if root((a, ka)) == root((b, kb)):
                    continue
                found = find(a, b, only_a=set(block_a), only_b=set(block_b))
                if found is not None:
                    lay(a, b, found[0], found[1])

    # Joining what is left, by steps, each looser than the one before.
    for ring_min, longest, clearance, reach in (
            (2, 7.5, CLEARANCE, 1), (1, 8.5, 0.5, 1), (1, 10.0, 0.4, 1),
            (0, 12.0, 0.3, 1), (1, 18.0, 0.4, 2), (0, 20.0, 0.3, 2)):
        while apart() > 1:
            laid = None
            for (a, ka) in parts:
                for (b, kb) in parts:
                    if a == b or root((a, ka)) == root((b, kb)):
                        continue
                    if max(abs(a[0] - b[0]), abs(a[1] - b[1])) > reach:
                        continue
                    found = find(a, b, only_a=set(chunks[a][ka]),
                                 only_b=set(chunks[b][kb]), ring_min=ring_min,
                                 longest=longest, clearance=clearance)
                    if found is not None:
                        laid = (a, b, found)
                        break
                if laid:
                    break
            if laid is None:
                break
            lay(laid[0], laid[1], laid[2][0], laid[2][1])
        if apart() == 1:
            break

    # Last resort: two pieces of the SAME cluster still apart are sewn back
    # together by the shortest inside line that crosses nothing.
    if apart() > 1:
        for c in cells:
            for ka in range(len(chunks[c])):
                for kb in range(ka + 1, len(chunks[c])):
                    if root((c, ka)) == root((c, kb)):
                        continue
                    block_a, block_b = chunks[c][ka], chunks[c][kb]
                    candidates = sorted(
                        (math.hypot(place(c, p)[0] - place(c, q)[0],
                                    place(c, p)[1] - place(c, q)[1]), p, q)
                        for p in block_a for q in block_b)
                    here = [place(c, s) for s in seats_of[c]]
                    seam = None
                    for _, p, q in candidates:
                        a, b = place(c, p), place(c, q)
                        if any(crosses(a, b, s[0], s[1]) for s in segments):
                            continue
                        if any(segment_distance(pt, a, b) < CLEARANCE for pt in here
                               if pt != a and pt != b):
                            continue
                        seam = (p, q)
                        break
                    if seam is None:
                        seam = candidates[0][1:]
                    links_of[c].append(seam)
                    segments.append((place(c, seam[0]), place(c, seam[1])))
                    parent[root((c, ka))] = root((c, kb))

    # THE LOOPS: a quarter more bridges, between neighbours already joined,
    # never on a leaf, since a dead end is wanted.
    degree = defaultdict(int)
    already = set()
    for a, b, _, _ in bridges:
        degree[a] += 1
        degree[b] += 1
        already.add((a, b))
        already.add((b, a))
    left = [(a, b) for a, b in pairs if (a, b) not in already]
    rng.shuffle(left)
    wanted = int(len(bridges) * LOOP_SHARE)
    for a, b in left:
        if wanted <= 0:
            break
        if degree[a] <= 1 or degree[b] <= 1:
            continue
        found = find(a, b)
        if found is None:
            continue
        lay(a, b, found[0], found[1])
        degree[a] += 1
        degree[b] += 1
        wanted -= 1

    # ---- the layout itself -------------------------------------------------
    out = xmlio.Layout(name)
    number = {}
    next_id = 1
    for index, lattice_cell in enumerate(cells, 1):
        out.clusters.append({"id": index, "x": lattice_cell[0] * STEP,
                             "y": lattice_cell[1] * STEP, "rot": 0.0})
        for seat in seats_of[lattice_cell]:
            number[(lattice_cell, seat)] = next_id
            out.cells.append(xmlio.Cell(next_id, index, seat[0], seat[1],
                                        kind=xmlio.NODE))
            next_id += 1
    for lattice_cell in cells:
        for a, b in links_of[lattice_cell]:
            out.links.append((number[(lattice_cell, a)], number[(lattice_cell, b)]))
    for ca, cb, sa, sb in bridges:
        out.links.append((number[(ca, sa)], number[(cb, sb)]))
    out.links.sort()
    return out
