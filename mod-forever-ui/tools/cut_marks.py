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

"""Cuts the ready-check marks and micro role icons out of interface/lfgframe/uilfgprompts.blp.

The sheet is 2048 x 2048 and the 3.3.5 client shows no texture over 1024 (see
foreverui/blp.py), so each element becomes its own image. Regions come from
tools/atlas_dump.json. Each piece is shrunk to its side (Lanczos, premultiplied alpha), never
enlarged, and written uncompressed with its mipmaps to
data/art/interface/ForeverUI/lfgframe/<lowercase name>.blp (+ .png).
Needs wow.export running with its source loaded (bridge on port 9455).
"""
import io
import json
import os
import sys
import urllib.parse
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

BRIDGE = "http://127.0.0.1:9455"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(ROOT, "tools", "atlas_dump.json")
OUTPUT = os.path.join(ROOT, "data", "art", "interface", "ForeverUI", "lfgframe")
STAGING = os.path.join(os.environ.get("TEMP", "."), "foreverui_export")
SHEET = "interface/lfgframe/uilfgprompts.blp"

# element -> output side (a power of two, required by the 3.3.5 client)
ELEMENTS = {
    # party frames: ready-check marks, shown at 36
    "UI-LFG-ReadyMark": 64, "UI-LFG-DeclineMark": 64, "UI-LFG-PendingMark": 64,
    # compact raid: "-Raid" marks (shown at 24.4) and "micro" role icons (17)
    "UI-LFG-ReadyMark-Raid": 64, "UI-LFG-DeclineMark-Raid": 64, "UI-LFG-PendingMark-Raid": 64,
    "UI-LFG-RoleIcon-Tank-Micro-GroupFinder": 32, "UI-LFG-RoleIcon-Healer-Micro-GroupFinder": 32,
    "UI-LFG-RoleIcon-DPS-Micro-GroupFinder": 32,
}


# GET on the wow.export bridge, returns the decoded JSON. params: dict or list of pairs
def _request(path, params):
    url = BRIDGE + path + "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=900) as r:
        return json.loads(r.read().decode("utf-8"))


# Region of each element on SHEET, read from the atlas index.
def regions():
    data = json.load(io.open(INDEX, encoding="utf-8"))
    match = {}
    for r in data["results"]:
        # the index writes names in lower case, camelot with capitals
        name = {e.lower(): e for e in ELEMENTS}.get(r["atlas"].lower())
        if name and (r.get("file") or "").lower() == SHEET:
            match[name] = r["region"]
    missing = [e for e in ELEMENTS if e not in match]
    if missing:
        raise SystemExit("absents de l'index : %s" % missing)
    return match


def main():
    if not _request("/status", {})["ready"]:
        _request("/load-source", {})
        raise SystemExit("la source de wow.export se charge, relancer dans une minute")
    os.makedirs(STAGING, exist_ok=True)
    res = _request("/export", [("dest", STAGING), ("file", SHEET)])
    if res["failed"]:
        raise SystemExit("export en echec : %s" % res)
    with io.open(os.path.join(STAGING, SHEET.replace("/", os.sep)), "rb") as f:
        width, height, rgba, _ = blp.decode(f.read())
    sheet = Image.frombytes("RGBA", (width, height), bytes(rgba)).convert("RGBa")
    os.makedirs(OUTPUT, exist_ok=True)
    for name, r in sorted(regions().items()):
        SIDE = ELEMENTS[name]
        piece = sheet.crop((r["left"], r["top"], r["left"] + r["width"], r["top"] + r["height"]))
        full = piece.resize((SIDE, SIDE), Image.LANCZOS)
        mips = []
        side = SIDE
        while side > 1:
            side //= 2
            mips.append((side, side, full.resize((side, side), Image.LANCZOS).convert("RGBA").tobytes()))
        output = full.convert("RGBA")
        base = os.path.join(OUTPUT, name.lower())
        with io.open(base + ".blp", "wb") as f:
            f.write(blp.encode(SIDE, SIDE, output.tobytes(), mips))
        output.save(base + ".png")
        print("   %-22s region %d x %d -> %d x %d + %d mipmaps" % (name, r["width"], r["height"], SIDE, SIDE, len(mips)))


if __name__ == "__main__":
    main()
