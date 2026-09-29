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

"""Upscales small modern-client atlas sheets (login field borders, slider, check box) x4.

These sheets are one-texel lines, DXT5 without mipmaps; the login screens stretch them to
screen scale, so their corners look pixelated. For each sheet, the BLP placed by
add_sheets.py is decoded and each element (regions from tools/atlas_dump.json) is padded
with its own edge pixels, upscaled with Lanczos in premultiplied alpha, and written
uncompressed (BGRA) with all mipmaps, so the client shrinks the image instead of enlarging it.

Writes <sheet>-hd next to the original. Coordinates do not change (same proportions):
tools/glue_atlas.py only points to the -hd file.
"""
import io
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "data", "art", "interface", "ForeverUI")
INDEX = os.path.join(ROOT, "tools", "atlas_dump.json")
FACTOR = 4
BORDER = 3
# Element margin in the upscaled sheet, in its pixels. The client blends each pixel with its
# neighbour when it stretches an image, so an element's end fades into the empty sheet and
# leaves a small gap between corners and edges. Each element overflows by 2 pixels of its
# own color; elements are 8 apart in the sheet, so nothing overlaps.
MARGIN = 2

# modern client sheet -> workspace path, without extension
SHEETS = {
    "interface/glues/common/uiframetooltipgluesc60.blp": "glues/common/uiframetooltipgluesc60",
    "interface/glues/common/uiframetooltipgluesverticalc60.blp": "glues/common/uiframetooltipgluesverticalc60",
    "interface/buttons/minimalsliderbarc60.blp": "buttons/minimalsliderbarc60",
    # options tooltip: 7-pixel corners
    "interface/tooltips/uiframetooltipc60.blp": "tooltips/uiframetooltipc60",
    "interface/tooltips/uiframetooltipverticalc60.blp": "tooltips/uiframetooltipverticalc60",
    # check box mark (checkmark-minimal): 30 x 29, camelot has no -2x variant
    "interface/common/minimalcheckbox.blp": "common/minimalcheckbox",
    # character list bronze frame (heavybronze-*-c60): a sheet the listfile does not name,
    # referenced by its file data id
    "fdid:8203429": "unknown/8203429",
}


def enlarge_element(image, r):
    """Region r, padded with its own edge pixels, upscaled, then cropped back."""
    x, y, w, h = r["left"], r["top"], r["width"], r["height"]
    piece = image.crop((x, y, x + w, y + h))
    bordered = Image.new("RGBa", (w + 2 * BORDER, h + 2 * BORDER))
    bordered.paste(piece, (BORDER, BORDER))
    # copy the edges outward, corners included
    for i in range(BORDER):
        bordered.paste(piece.crop((0, 0, w, 1)), (BORDER, i))
        bordered.paste(piece.crop((0, h - 1, w, h)), (BORDER, BORDER + h + i))
    for i in range(BORDER):
        bordered.paste(bordered.crop((BORDER, 0, BORDER + 1, h + 2 * BORDER)), (i, 0))
        bordered.paste(bordered.crop((BORDER + w - 1, 0, BORDER + w, h + 2 * BORDER)), (BORDER + w + i, 0))
    large = bordered.resize((bordered.width * FACTOR, bordered.height * FACTOR), Image.LANCZOS)
    b = BORDER * FACTOR - MARGIN
    return large.crop((b, b, b + w * FACTOR + 2 * MARGIN, b + h * FACTOR + 2 * MARGIN))


def main():
    index = json.load(io.open(INDEX, encoding="utf-8"))["results"]
    for sheet, workspace in sorted(SHEETS.items()):
        source = os.path.join(ART, *workspace.split("/")) + ".blp"
        with io.open(source, "rb") as f:
            width, height, rgba, _ = blp.decode(f.read())
        image = Image.frombytes("RGBA", (width, height), bytes(rgba)).convert("RGBa")

        if sheet.startswith("fdid:"):
            fdid = int(sheet[5:])
            regions = [r["region"] for r in index if r.get("fileDataID") == fdid]
        else:
            regions = [r["region"] for r in index if (r.get("file") or "").lower() == sheet]
        if not regions:
            raise SystemExit("aucun element pour %s dans l'index" % sheet)

        W, H = width * FACTOR, height * FACTOR
        canvas = Image.new("RGBa", (W, H))
        seen = set()
        for r in regions:
            key = (r["left"], r["top"], r["width"], r["height"])
            if key in seen:
                continue
            seen.add(key)
            canvas.paste(enlarge_element(image, r), (r["left"] * FACTOR - MARGIN, r["top"] * FACTOR - MARGIN))

        mips = []
        mw, mh = W, H
        while mw > 1 or mh > 1:
            mw, mh = max(1, mw // 2), max(1, mh // 2)
            mips.append((mw, mh, canvas.resize((mw, mh), Image.LANCZOS).convert("RGBA").tobytes()))
        full = canvas.convert("RGBA")
        output = os.path.join(ART, *workspace.split("/")) + "-hd"
        with io.open(output + ".blp", "wb") as f:
            f.write(blp.encode(W, H, full.tobytes(), mips))
        full.save(output + ".png")
        print("   %-50s %d x %d -> %d x %d, %d elements" % (
            workspace + "-hd", width, height, W, H, len(seen)))


if __name__ == "__main__":
    main()
