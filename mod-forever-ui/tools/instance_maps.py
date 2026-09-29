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

"""Dungeon and raid maps by name, for SetMapByID: writes ForeverUI.InstanceMaps to
data/addon/ForeverUI/WorldMapInstances.lua (lowercase map or zone name -> WorldMapArea ID).
3.3.5 has SetMapByID but does not link a world map portal to a map, hence the table.

Source: client DBCs through the archive chain (patches included):
  Map.dbc           0 ID, 2 InstanceType (1 dungeon, 2 raid), 5 enUS name
  WorldMapArea.dbc  0 ID (the SetMapByID one), 1 MapID, 2 AreaID
  AreaTable.dbc     0 ID, 11 enUS name
An instance with several maps (Scarlet Monastery wings) has each under its zone name;
the map name goes to the first.
Other languages come from WDM's LibBabble-Zone-3.0 (the names its portals show), lowercased
as Lua 5.1 string.lower does (ASCII only).
"""
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import mpq  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "data", "addon", "ForeverUI", "WorldMapInstances.lua")
CLIENT = sys.argv[1] if len(sys.argv) > 1 else r"E:\world of warcraft 3.3.5a hd\Data"
SEP = chr(92)

# Portal names: WDM ("WoW Dungeon Maps - HD client", shipped in patch-enus-n.mpq) names its
# portal icons through LibBabble-Zone. All are in the DBCs but one.
ALIAS = {
    "the eye": "tempest keep",          # Tempest Keep, the raid (map 550)
}


# Reads a client DBC: (rows of uint32 fields, text(offset) for the string block).
def read(chain, name):
    d = chain.read("DBFilesClient" + SEP + name)
    n, fields, size, string_block_size = struct.unpack_from("<IIII", d, 4)
    start = 20 + n * size
    rows = [struct.unpack_from("<%dI" % fields, d, 20 + i * size) for i in range(n)]

    def text(o):
        if o >= string_block_size:
            return ""
        finish = d.index(b"\0", start + o)
        return d[start + o:finish].decode("utf-8", "replace")
    return rows, text


BABBLE = SEP.join(["Interface", "AddOns", "WDM", "libs", "LibBabble-Zone-3.0", "LibBabble-Zone-3.0.lua"])


def lua_lower(s):
    """Lua 5.1 string.lower (C locale): ASCII letters only."""
    return "".join(c.lower() if "A" <= c <= "Z" else c for c in s)


def babble_languages(chain):
    """{language: {lowercase English name: translated name}} from LibBabble-Zone."""
    name = next((n for n in chain.names() if n.lower() == BABBLE.lower()), None)
    if not name:
        return {}
    src = chain.read(name).decode("utf-8", "replace")
    res = {}
    markers = list(re.finditer(r'GAME_LOCALE == "(\w+)"', src))
    for i, m in enumerate(markers):
        block = src[m.end():markers[i + 1].start() if i + 1 < len(markers) else len(src)]
        names = {}
        for e in re.finditer(r'(?:\["((?:[^"\\]|\\.)*)"\]|([A-Za-z_][A-Za-z0-9_]*))\s*=\s*"((?:[^"\\]|\\.)*)"', block):
            english = e.group(1) if e.group(1) is not None else e.group(2)
            names[english.lower()] = e.group(3).replace('\\"', '"')
        res[m.group(1)] = names
    return res


def main():
    chain = mpq.open_client(CLIENT, "enUS")
    maps, map_text = read(chain, "Map.dbc")
    instances = {r[0]: map_text(r[5]) for r in maps if r[2] in (1, 2)}
    zones, zone_text = read(chain, "AreaTable.dbc")
    zone_name = {r[0]: zone_text(r[11]) for r in zones}
    areas, area_text = read(chain, "WorldMapArea.dbc")

    table = {}
    views = set()
    for r in sorted(areas, key=lambda r: r[0]):
        ident, map_, zone = r[0], r[1], r[2]
        if map_ not in instances:
            continue
        for name in (zone_name.get(zone, ""), instances[map_] if map_ not in views else ""):
            key = name.strip().lower()
            if key and key not in table:
                table[key] = ident
        views.add(map_)
    for alias, name in ALIAS.items():
        if name in table and alias not in table:
            table[alias] = table[name]
    english = dict(table)
    translated = 0
    for language, names in sorted(babble_languages(chain).items()):
        for key, ident in sorted(english.items()):
            name = names.get(key)
            if name:
                key2 = lua_lower(name.strip())
                if key2 not in table:
                    table[key2] = ident
                    translated += 1

    rows = [
        "-- ForeverUI: dungeon and raid maps (SetMapByID), by name.",
        "-- GENERATED by tools/instance_maps.py from the client DBCs -- do not",
        "-- edit by hand. Lowercase map or zone name -> WorldMapArea ID. English",
        "-- names come from the DBCs, other languages from WDM's",
        "-- LibBabble-Zone (the names its portals carry).",
        "",
        "ForeverUI = ForeverUI or {}",
        "ForeverUI.InstanceMaps = {",
    ]
    for key in sorted(table):
        rows.append('\t["%s"] = %d,' % (key.replace('"', '\\"'), table[key]))
    rows.append("}")
    open(OUTPUT, "w", encoding="utf-8", newline="\n").write("\n".join(rows) + "\n")
    print("%d noms (%d traduits) pour %d instances -> %s" % (len(table), translated, len(views), os.path.relpath(OUTPUT, ROOT)))


if __name__ == "__main__":
    main()
