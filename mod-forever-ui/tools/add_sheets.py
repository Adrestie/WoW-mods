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

"""Adds atlas sheets to the workspace, with a PNG preview and the atlas table.

Whole sheets rather than single elements: one import brings every element of a sheet, and
the client binds one texture per frame, which is the point of atlases.

For each line of tools/extra_sheets.txt (and tools/simple_files.txt): export the .blp from
the modern client through the wow.export bridge, export the same file as .png, and store
both in data/art/interface/ForeverUI/. Then regenerate
data/addon/ForeverUI/UIAtlas_06_extras.lua from the atlas index.
Does not write to the client: tools/deploy.py does that.

wow.export must be running with its source loaded (bridge on port 9455).
"""
import io
import json
import os
import re
import shutil
import urllib.parse
import urllib.request

BRIDGE = "http://127.0.0.1:9455"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
ART = os.path.join(ROOT, "data", "art")
ADDON = os.path.join(ROOT, "data", "addon", "ForeverUI")
LIST = os.path.join(TOOLS, "extra_sheets.txt")
SIMPLE_LIST = os.path.join(TOOLS, "simple_files.txt")
INDEX = os.path.join(TOOLS, "atlas_dump.json")
PREFIX = "ForeverUI"
BS = chr(92)

# Export staging folder, outside the workspace.
STAGING = os.path.join(os.environ.get("TEMP", "."), "foreverui_export")

_VARIANT = re.compile("^(2x|4x|c[0-9]+)$")


# GET request to the wow.export bridge; returns the decoded JSON reply.
def _request(path, params):
    url = BRIDGE + path + "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=900) as r:
        return json.loads(r.read().decode("utf-8"))


def _logical(name):
    """The name without its variant suffixes (2x, 4x, cNN), as camelot code writes it."""
    parts = name.lower().split("-")
    while len(parts) > 1 and _VARIANT.match(parts[-1]):
        parts.pop()
    return "-".join(parts)


# Aliases for files the community listfile does not name (wow.export calls them
# "unknown_<id>"). A list line "source => workspace name" exports by FileDataID and stores
# the file under the name camelot code uses; the id stays in the list to find the file later.
# source -> workspace name.
_ALIAS = {}


# Reads a sheet list: one path per line, '#' comments, optional "source => name" alias.
def _read(list_):
    wanted_sheets = []
    for row in io.open(list_, encoding="utf-8"):
        row = row.split("#")[0].strip()
        if not row:
            continue
        if "=>" in row:
            source, wanted = [part.strip().lower() for part in row.split("=>", 1)]
            _ALIAS[source] = wanted
            wanted_sheets.append(source)
        else:
            wanted_sheets.append(row.lower())
    return wanted_sheets


def list_wanted_sheets():
    return _read(LIST)


def list_simple_files():
    """Standalone images: imported, but not added to the atlas table."""
    if not os.path.exists(SIMPLE_LIST):
        return []
    return _read(SIMPLE_LIST)


def workspace_path(sheet, extension=".blp"):
    """interface/hud/x.blp -> data/art/interface/ForeverUI/hud/x.blp

    A file the listfile does not name is stored under its alias, not its "unknown_<id>".
    """
    sheet = _ALIAS.get(sheet, sheet)
    pieces = sheet.split("/")
    assert pieces[0] == "interface", sheet
    return os.path.join(ART, "interface", PREFIX, *pieces[1:])[:-4] + extension


# Exports missing sheets and previews into the workspace; returns the number of sheets placed.
def export(wanted_sheets):
    missing = [f for f in wanted_sheets if not os.path.exists(workspace_path(f))]
    no_preview = [f for f in wanted_sheets
                   if os.path.exists(workspace_path(f))
                   and not os.path.exists(workspace_path(f, ".png"))]
    if not missing and not no_preview:
        print("art : les %d feuilles sont deja dans l'atelier, avec leur apercu" % len(wanted_sheets))
        return 0

    status = _request("/status", {})
    if not status["ready"]:
        _request("/load-source", {})
        raise SystemExit("la source de wow.export se charge, relancer dans une minute")

    os.makedirs(STAGING, exist_ok=True)
    placed = 0

    if missing:
        params = [("dest", STAGING)]
        for f in missing:
            if f.startswith("fdid:"):
                params.append(("fdid", f[5:].split(".")[0]))
            else:
                params.append(("file", f))
        res = _request("/export", params)
        if res["failed"]:
            raise SystemExit("export en echec : %s" % res)
        for f in missing:
            target = workspace_path(f)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            if f.startswith("fdid:"):
                # Exported by id: the bridge returns the exact path
                match = None
                for e in res["exported"]:
                    if str(e.get("fileDataID")) == f[5:].split(".")[0]:
                        match = e["path"]
                        break
                if not match:
                    raise SystemExit("export par identifiant sans chemin : %s" % f)
                shutil.copyfile(match, target)
            else:
                shutil.copyfile(os.path.join(STAGING, f.replace("/", os.sep)), target)
            print("   %-60s %8d o" % (os.path.relpath(target, ROOT), os.path.getsize(target)))
            placed += 1

    for f in missing + no_preview:
        # mask 15 keeps the alpha channel (the user setting, 7, gives an opaque preview).
        # The preview goes through the texture exporter, whose parameter is always "file": an id is
        # passed as is.
        key = ("file", f[5:].split(".")[0]) if f.startswith("fdid:") else ("file", f)
        res = _request("/export-textures", [("dest", STAGING), ("format", "png"),
                                             ("mask", "15"), key])
        if res["failed"]:
            print("   PAS D'APERCU pour %s : %s" % (f, res["exported"]))
            continue
        source = res["exported"][0]["path"]
        target = workspace_path(f, ".png")
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copyfile(source, target)

    return placed


def regenerate_table(wanted_sheets):
    """Regenerates the atlas table for the wanted sheets.

    A sheet the listfile does not name has no `file` in the index: its elements are listed by
    FileDataID only. It is found through the id in its alias ("fdid:8198433 => interface/...")
    and gets the chosen workspace path.
    """
    index = json.load(io.open(INDEX, encoding="utf-8"))["results"]

    # A sheet requested under an alias is matched by its workspace name, not its source.
    wanted_sheets = [_ALIAS.get(f, f) for f in wanted_sheets]

    # Sheets requested by id: fdid -> wanted path.
    by_id = {}
    for source, wanted in _ALIAS.items():
        if source.startswith("fdid:"):
            by_id[int(source[5:].split(".")[0])] = wanted.lower()

    by_sheet = {}
    for r in index:
        if not r["atlas"]:
            continue
        # An alias by id wins over the index path: the listfile is sometimes wrong (uiframe.blp is
        # listed under interface/interface/framegeneral/).
        name = by_id.get(r.get("fileDataID")) or (r.get("file") or "").lower()
        if name in wanted_sheets:
            by_sheet.setdefault(name, []).append(r)

    missing = [f for f in wanted_sheets if f not in by_sheet]
    if missing:
        raise SystemExit("feuilles absentes de l'index des atlas : %s" % missing)

    rows = [
        "-- extras: atlas sheets used outside the five inventoried screens.",
        "-- generated by tools/add_sheets.py from tools/atlas_dump.json",
        "",
        "UIAtlas = UIAtlas or { sheets = {}, data = {} }",
        "",
        "local S = {",
    ]
    order = sorted(by_sheet)
    number = {}
    for i, f in enumerate(order, 1):
        number[f] = i
        t = by_sheet[f][0]["sheet"]
        path = ("interface/" + PREFIX + "/" + f[len("interface/"):])[:-4].replace("/", BS + BS)
        rows.append('\t[%d] = "%s", -- %d x %d' % (i, path, t["width"], t["height"]))
    rows += ["}", "", "local D = {"]

    # A logical name already served by another table keeps its sheet: a 2x sheet (such as
    # uiactionbar2xc60) would otherwise take over the logical names of the 1x sheet in use.
    # Only its raw names are added then.
    elsewhere = set()
    for p in os.listdir(ADDON):
        if p.startswith("UIAtlas") and p.endswith(".lua") and p != "UIAtlas_06_extras.lua":
            elsewhere.update(re.findall(r'\["([^"]+)"\] = \{', io.open(os.path.join(ADDON, p), encoding="utf-8").read()))
    table = os.path.join(ADDON, "UIAtlas_06_extras.lua")
    if os.path.exists(table):
        elsewhere -= set(re.findall(r'\["([^"]+)"\] = \{', io.open(table, encoding="utf-8").read()))

    total = 0
    already = set()
    for f in order:
        # A double-density image shows at half its size.
        factor = 0.5 if "2x" in os.path.basename(f) else 1
        for r in sorted(by_sheet[f], key=lambda x: x["atlas"].lower()):
            sw, sh = r["sheet"]["width"], r["sheet"]["height"]
            reg = r["region"]
            u1 = reg["left"] / float(sw)
            u2 = (reg["left"] + reg["width"]) / float(sw)
            v1 = reg["top"] / float(sh)
            v2 = (reg["top"] + reg["height"]) / float(sh)
            width = int(round(reg["width"] * factor))
            height = int(round(reg["height"] * factor))

            # The raw name, and the logical name camelot code uses.
            raw = r["atlas"].lower()
            for name in (raw, _logical(r["atlas"])):
                if name in already or (name != raw and name in elsewhere):
                    continue
                already.add(name)
                rows.append('\t["%s"] = {%d, %.6f, %.6f, %.6f, %.6f, %d, %d},' % (
                    name, number[f], u1, u2, v1, v2, width, height))
                total += 1

    rows += ["}", "",
               "for name, entry in pairs(D) do",
               "\tentry[1] = S[entry[1]]",
               "\tUIAtlas.data[name] = entry",
               "end",
               ""]

    dest = os.path.join(ADDON, "UIAtlas_06_extras.lua")
    io.open(dest, "w", encoding="utf-8", newline="\n").write("\n".join(rows))
    print("table des complements : %d feuilles, %d noms, %d octets" % (
        len(order), total, os.path.getsize(dest)))


def main():
    wanted_sheets = list_wanted_sheets()
    simple_files = list_simple_files()
    export(wanted_sheets + simple_files)
    regenerate_table(wanted_sheets)
    print("l'atelier est a jour ; poser dans le client avec tools/deploy.py")


if __name__ == "__main__":
    main()
