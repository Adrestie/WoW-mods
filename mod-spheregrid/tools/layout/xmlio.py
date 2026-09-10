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

r"""The layout file, read and written the way the in-game editor writes it.

ONE FILE, TWO HANDS. A layout is edited in game with `.spheregrid editor` and
out of game with this tool, and both write the same XML in the same folder. So
this reader and this writer are held to the letter of the editor's own
(`data/lua/SphereGrid/editor/Editor.lua`): same tags, same attributes, same
order, same four decimals. A layout that goes through here and back comes out
byte for byte, or the game and the tool would be quarrelling over a file
instead of sharing it.

    <spheregrid version="1" name="...">
      <clusters>  <cluster id x y rot/>
      <cells>     <cell id cluster ring branch type="node|slot|spell"
                        [stat quality] [spell]/>
      <links>     <link a b/>
      <spells>    <spell cell class id/>      one line per class that differs
                  <start class id/>           one per class
"""
import io
import os
import re

NODE, SLOT, SPELL = "node", "slot", "spell"

# The statistics, in the order the module allocates them -- the same list as
# the editor's and the interface's. The key is what the XML carries; it never
# changes.
STATS = ("stamina", "intellect", "spirit", "agility", "strength",
         "parry", "block", "dodge", "haste", "crit", "hit",
         "spell_power", "attack_power", "armor_penetration", "expertise",
         "bonus_healing")

QUALITIES = ("Common", "Uncommon", "Rare", "Epic", "Legendary")

# The ten classes of Wrath. Ten is nobody: the druid wears eleven.
CLASSES = (1, 2, 3, 4, 5, 6, 7, 8, 9, 11)
CLASS_NAMES = {1: "Warrior", 2: "Paladin", 3: "Hunter", 4: "Rogue", 5: "Priest",
               6: "Death knight", 7: "Shaman", 8: "Mage", 9: "Warlock",
               11: "Druid"}

_ATTRS = re.compile(r'(\w+)="([^"]*)"')


class Cell(object):
    """One cell: where it sits in its cluster, and what it holds."""

    __slots__ = ("id", "cluster", "ring", "branch", "kind", "stat", "quality",
                 "spell", "spells")

    def __init__(self, id, cluster, ring, branch, kind=NODE, stat=None,
                 quality=1, spell=0, spells=None):
        self.id = id
        self.cluster = cluster
        self.ring = ring
        self.branch = branch
        self.kind = kind
        self.stat = stat                   # a key of STATS, or None: an empty node
        self.quality = quality             # 1..5
        self.spell = spell                 # a spell cell's fallback spell
        self.spells = dict(spells or {})   # class -> spell, where it differs


class Layout(object):
    def __init__(self, name="untitled"):
        self.name = name
        self.clusters = []              # dicts: id, x, y, rot
        self.cells = []
        self.links = []                 # (a, b) pairs of cell ids
        self.starts = {}                # class -> cell id

    def by_id(self):
        return dict((c.id, c) for c in self.cells)

    def cluster_by_id(self):
        return dict((c["id"], c) for c in self.clusters)

    def counts(self):
        kinds = {NODE: 0, SLOT: 0, SPELL: 0}
        for c in self.cells:
            kinds[c.kind] = kinds.get(c.kind, 0) + 1
        return kinds


def read(path):
    """The layout in that file. An attribute nobody knows is ignored rather
    than refused: the editor may grow one, and this must not choke on it."""
    text = io.open(path, encoding="utf-8").read()
    name = os.path.splitext(os.path.basename(path))[0]
    head = re.search(r'<spheregrid[^>]*>', text)
    if head:
        a = dict(_ATTRS.findall(head.group(0)))
        name = a.get("name", name)

    out = Layout(name)
    for m in re.finditer(r'<cluster ([^/]*)/>', text):
        a = dict(_ATTRS.findall(m.group(1)))
        out.clusters.append({"id": int(a["id"]), "x": float(a["x"]),
                             "y": float(a["y"]), "rot": float(a.get("rot", 0))})

    for m in re.finditer(r'<cell ([^/]*)/>', text):
        a = dict(_ATTRS.findall(m.group(1)))
        out.cells.append(Cell(
            int(a["id"]), int(a["cluster"]), int(a["ring"]), int(a["branch"]),
            kind=a.get("type", NODE),
            stat=a.get("stat") or None,
            quality=int(a.get("quality", 1) or 1),
            spell=int(a.get("spell", 0) or 0)))

    for m in re.finditer(r'<link a="(\d+)" b="(\d+)"', text):
        out.links.append((int(m.group(1)), int(m.group(2))))

    cells = out.by_id()
    for m in re.finditer(r'<spell cell="(\d+)" class="(\d+)" id="(\d+)"', text):
        cell = cells.get(int(m.group(1)))
        if cell is not None:
            cell.spells[int(m.group(2))] = int(m.group(3))

    for m in re.finditer(r'<start ([^/]*)/>', text):
        a = dict(_ATTRS.findall(m.group(1)))
        out.starts[int(a.get("class", 0))] = int(a["id"])
    return out


def write(layout, path):
    """The same file the editor would have written."""
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<spheregrid version="1" name="%s">' % layout.name,
             '  <clusters>']
    for c in sorted(layout.clusters, key=lambda c: c["id"]):
        lines.append('    <cluster id="%d" x="%.4f" y="%.4f" rot="%.4f"/>'
                     % (c["id"], c["x"], c["y"], c.get("rot", 0.0)))
    lines.append('  </clusters>')

    lines.append('  <cells>')
    for n in sorted(layout.cells, key=lambda n: n.id):
        head = '    <cell id="%d" cluster="%d" ring="%d" branch="%d"' % (
            n.id, n.cluster, n.ring, n.branch)
        if n.kind == SLOT:
            lines.append(head + ' type="slot"/>')
        elif n.kind == SPELL:
            lines.append(head + ' type="spell" spell="%d"/>' % (n.spell or 0))
        elif n.stat:
            lines.append(head + ' type="node" stat="%s" quality="%d"/>'
                         % (n.stat, n.quality or 1))
        else:
            lines.append(head + ' type="node"/>')      # an empty node
    lines.append('  </cells>')

    lines.append('  <links>')
    for a, b in layout.links:
        lines.append('    <link a="%d" b="%d"/>' % (a, b))
    lines.append('  </links>')

    spells = []
    for n in sorted(layout.cells, key=lambda n: n.id):
        if n.kind != SPELL:
            continue
        for klass in sorted(n.spells):
            spells.append('    <spell cell="%d" class="%d" id="%d"/>'
                          % (n.id, klass, n.spells[klass]))
    if spells:
        lines.append('  <spells>')
        lines.extend(spells)
        lines.append('  </spells>')

    for klass in sorted(layout.starts):
        lines.append('  <start class="%d" id="%d"/>' % (klass, layout.starts[klass]))

    lines.append('</spheregrid>')
    lines.append('')
    io.open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    return path
