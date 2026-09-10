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

r"""A layout, written as the SQL the module ships.

THE GRID IS DATA, and this is where a drawing becomes it: `08_grid.sql`, the
very file in `data/sql/world`, so a server that wants its own grid replaces
that one file and nothing else.

WHAT A CELL CARRIES IN THE DATABASE is what it grants, never the item that
follows from it: `stone_stat` and `stone_quality`, and the entry of the stone
comes from the module's allocation -- which the installer may move.

ALL OR NOTHING: the whole thing is wrapped in a transaction, and each block
deletes what it is about to write. Applied through `mysql < file`, the client
stops at the first error and the connection closes before COMMIT, so InnoDB
rolls it all back and no half-written grid is ever left behind.
"""
import io

from . import geometry, xmlio

# The kinds, as the module's C++ reads them.
KIND = {xmlio.NODE: 0, xmlio.SLOT: 1, xmlio.SPELL: 2}

HEADER = """-- mod-spheregrid — the grid that ships with the module.
--
-- A single SHARED grid (class 0) with one start per class: every class walks the
-- same cells but each one enters through its own door. A server may replace it
-- entirely — it is data, and the layout editor plus the importer that ship with
-- the module are what produce this file.
--
-- A cell says which STATISTIC and which QUALITY it comes pre-filled with, never
-- the item entry that follows from them: the entry depends on an allocation the
-- installer may move, the choice does not. Nor does it carry a name: the
-- interface composes one in the CLIENT'S language, from those same two fields,
-- and picks the icon the same way. See docs/PRESENTATION.md.
--
-- ALL OR NOTHING: the whole thing is wrapped in a transaction, and each block
-- deletes what it is about to write. Applied through `mysql < file`, the client
-- stops at the first error and the connection closes without reaching COMMIT:
-- InnoDB then rolls everything back, so no half-written grid.
--
-- Do not introduce any DDL here (CREATE, ALTER, TRUNCATE): MySQL commits
-- implicitly before executing one, which would cut the transaction in two
-- without saying so.

START TRANSACTION;

-- Generated from the « {name} » layout of the editor, class {klass}.
-- Regenerable: class {klass} is replaced whole (DELETE, then INSERT).
-- node_id = class_id * 10000 + the id in the XML. A cell's pre-filled stone is
-- not stored: `stone_stat` and `stone_quality` are, and the entry follows from
-- the module's allocation.

-- THE SHARED GRID stands in for the ten class grids: the module falls back on
-- class 0 whenever a class has no grid of its own.
"""


def node_id(cell_id, klass):
    """node_id = class_id * 10000 + the id in the XML. The shared grid is
    class 0, so its cells keep the numbers the editor gave them."""
    return klass * 10000 + cell_id


def _rows(prefix, rows, per_line=1):
    """An INSERT with its tuples, one per line, ending on a semicolon."""
    out = [prefix]
    for i, row in enumerate(rows):
        out.append(row + ("," if i + 1 < len(rows) else ";"))
    return out


def build(layout, klass=0):
    """The whole file, as text."""
    stat_index = dict((key, i + 1) for i, key in enumerate(xmlio.STATS))
    places = geometry.positions(layout)

    lines = [HEADER.format(name=layout.name, klass=klass).rstrip(chr(10))]

    if klass:
        # A class grid replaces only itself; the shared one wipes the lot.
        for table, column in (("mod_spheregrid_node_spell", "class_id"),
                              ("mod_spheregrid_edge", "class_id"),
                              ("mod_spheregrid_start", "class_id"),
                              ("mod_spheregrid_node", "class_id"),
                              ("mod_spheregrid_cluster", "class_id")):
            lines.append("DELETE FROM `%s` WHERE `%s` = %d;" % (table, column, klass))
    else:
        for table in ("mod_spheregrid_node_spell", "mod_spheregrid_edge",
                      "mod_spheregrid_start", "mod_spheregrid_node",
                      "mod_spheregrid_cluster"):
            lines.append("DELETE FROM `%s`;" % table)
    lines.append("")

    lines.extend(_rows(
        "INSERT INTO `mod_spheregrid_cluster` (`class_id`, `cluster_id`, `x`, `y`, `rot`) VALUES",
        ["(%d, %d, %.4f, %.4f, %.4f)" % (klass, c["id"], c["x"], c["y"], c.get("rot", 0.0))
         for c in sorted(layout.clusters, key=lambda c: c["id"])]))
    lines.append("")

    rows = []
    for cell in sorted(layout.cells, key=lambda c: c.id):
        x, y = places.get(cell.id, (0.0, 0.0))
        rows.append("(%d, %d, %d, %.4f, %.4f, %d, %d, %d, %d, %d, %d)" % (
            node_id(cell.id, klass), klass, KIND.get(cell.kind, 0), x, y,
            stat_index.get(cell.stat or "", 0) if cell.kind == xmlio.NODE else 0,
            (cell.quality or 0) if (cell.kind == xmlio.NODE and cell.stat) else 0,
            cell.spell if cell.kind == xmlio.SPELL else 0,
            cell.cluster, cell.ring, cell.branch))
    lines.extend(_rows(
        "INSERT INTO `mod_spheregrid_node` (`node_id`, `class_id`, `kind`, `grid_x`, "
        "`grid_y`, `stone_stat`, `stone_quality`, `spell_id`, `cluster`, `ring`, "
        "`branch`) VALUES", rows))
    lines.append("")

    rows = []
    for cell in sorted(layout.cells, key=lambda c: c.id):
        if cell.kind != xmlio.SPELL:
            continue
        for one in sorted(cell.spells):
            rows.append("(%d, %d, %d)" % (node_id(cell.id, klass), one, cell.spells[one]))
    if rows:
        lines.extend(_rows(
            "INSERT INTO `mod_spheregrid_node_spell` (`node_id`, `class_id`, "
            "`spell_id`) VALUES", rows))
        lines.append("")

    lines.extend(_rows(
        "INSERT INTO `mod_spheregrid_edge` (`class_id`, `node_a`, `node_b`) VALUES",
        ["(%d, %d, %d)" % (klass, node_id(a, klass), node_id(b, klass))
         for a, b in layout.links]))
    lines.append("")

    starts = ", ".join("(%d, %d)" % (one, node_id(layout.starts[one], klass))
                       for one in sorted(layout.starts))
    lines.append("INSERT INTO `mod_spheregrid_start` (`class_id`, `node_id`) VALUES %s;"
                 % starts)
    lines.append("")
    lines.append("COMMIT;")
    lines.append("")
    return "\n".join(lines)


def write(layout, path, klass=0):
    io.open(path, "w", encoding="utf-8", newline="\n").write(build(layout, klass))
    return path
