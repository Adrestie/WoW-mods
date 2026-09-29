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

"""Cuts atlas elements out on their own, at their original resolution.

The 3.3.5 client shows no sheet wider than 1024 (see foreverui/blp.py) and needs power-of-two
sides; several Camelot sheets are 2048. Each element keeps its size: it sits at the top left of
a power-of-two image, the rest transparent, and the atlas table holds the used part's
coordinates (cut_marks.py instead shrinks its marks to a square).

For each sheet of ELEMENTS: exports it through the wow.export bridge, reads each element's
region from tools/atlas_dump.json, writes it uncompressed with mipmaps to
data/art/interface/ForeverUI/<sheet folder>/<element>.blp (+ .png), then regenerates
data/addon/ForeverUI/UIAtlas_07_cutouts.lua so ForeverUI.SetAtlas finds them by Camelot name.

wow.export must run with its source loaded (bridge on port 9455).
"""
import io
import json
import os
import re
import sys
import urllib.parse
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

BRIDGE = "http://127.0.0.1:9455"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(ROOT, "tools", "atlas_dump.json")
ART = os.path.join(ROOT, "data", "art", "interface", "ForeverUI")
TABLE = os.path.join(ROOT, "data", "addon", "ForeverUI", "UIAtlas_07_cutouts.lua")
STAGING = os.path.join(os.environ.get("TEMP", "."), "foreverui_export")
BS = "\\"

# sheet -> elements to cut from it
ELEMENTS = {
    # group finder (blizzard_groupfinder_vanillastyle)
    "interface/lfgframe/groupfinder.blp": [
        "groupfinder-background", "groupfinder-button-cover",
        "groupfinder-button-dungeons", "groupfinder-button-custom-pve",
        "groupfinder-button-questing", "groupfinder-button-raids-warlords",
        # raid browser: row selection and hover, roles, wait dot, WotLK classes
        "groupfinder-highlightbar-blue", "groupfinder-highlightbar-yellow",
        "groupfinder-icon-role-micro-tank", "groupfinder-icon-role-micro-heal",
        "groupfinder-icon-role-micro-dps", "groupfinder-waitdot",
    ] + ["groupfinder-icon-class-" + c for c in (
        "deathknight", "druid", "hunter", "mage", "paladin",
        "priest", "rogue", "shaman", "warlock", "warrior")],
    "interface/hud/uigroupfinderflipbook.blp": ["groupfinder-eye-frame"],
    "interface/shop/catalogshop.blp": ["shop-list-rule"],
    # glue screens red button (ThreeSliceButtonTemplate, 128-RedButton): three slices per
    # state; the glow exists only in the non-c60 sheet
    "interface/buttons/128redbuttonc60.blp": [
        "128-redbutton-left-c60", "128-redbutton-left-pressed-c60", "128-redbutton-left-disabled-c60",
        "_128-redbutton-center-c60", "_128-redbutton-center-pressed-c60", "_128-redbutton-center-disabled-c60",
        "128-redbutton-right-c60", "128-redbutton-right-pressed-c60", "128-redbutton-right-disabled-c60",
        # character list collapse arrow (ListToggle)
        "128-redbutton-arrowdown-c60", "128-redbutton-arrowdown-pressed-c60", "128-redbutton-arrowdown-disabled-c60",
        "128-redbutton-arrowupglow-c60", "128-redbutton-arrowupglow-pressed-c60", "128-redbutton-arrowupglow-disabled-c60",
        # realm list close button (BigRedExitButtonTemplate)
        "128-redbutton-exit-c60", "128-redbutton-exit-pressed-c60", "128-redbutton-exit-disabled-c60",
    ],
    "interface/buttons/128redbutton.blp": [
        "128-redbutton-highlight",
        "128-redbutton-arrowdown-highlight", "128-redbutton-arrowupglow-highlight",
        "128-redbutton-exit-highlight",
    ],
    # glue screens credits (blizzard_gluexml/mainline/creditsframe.xml): top and bottom
    # gradient, speed icons (2048 high sheet) and the gray square button holding them
    "interface/credits/creditsscreenassets.blp": [
        "_creditsscreen-gradient-tile",
        "creditsscreen-assets-buttons-rewind", "creditsscreen-assets-buttons-pause",
        "creditsscreen-assets-buttons-play", "creditsscreen-assets-buttons-fastforward",
        # expansion list (CreditsFrameExpansionsButtonTemplate)
        "creditsscreen-selected", "creditsscreen-highlight",
    ],
    "interface/common/commonbuttonsc60.blp": [
        "common-button-square-gray-up-c60", "common-button-square-gray-down-c60",
    ],
    # character list delete button (UIButtonTemplate, 128-RedButton-Delete); its glow exists
    # only in the non-c60 sheet
    "interface/buttons/128redbuttonpart2c60.blp": [
        "128-redbutton-delete-c60", "128-redbutton-delete-pressed-c60", "128-redbutton-delete-disabled-c60",
    ],
    "interface/buttons/128redbuttonpart2.blp": ["128-redbutton-delete-highlight"],
    # character select: Back button arrow and model rotation icons (2048 wide sheet)
    "interface/common/commonicons.blp": [
        "common-icon-backarrow", "common-icon-rotateleft", "common-icon-rotateright",
        "common-icon-backarrow-disable", "common-icon-forwardarrow", "common-icon-forwardarrow-disable",
        # customization: reset camera (CustomizationResetCameraButton)
        "common-icon-undo",
    ],
    # character creation (blizzard_charactercreate/camelot): faction emblems and vignettes;
    # race and class icons, which tools/bake_creation.py then cuts with Camelot's mask
    "interface/glues/charactercreate/charactercreate.blp": [
        "charactercreate-icon-alliance", "charactercreate-icon-horde",
        "charactercreate-vignette-top", "charactercreate-vignette-sides",
        "charactercreate-vignette-bottom", "charactercreate-vignette-sides-widescreen",
        # customization dice (CustomizationRandomizeAppearanceButton)
        "charactercreate-icon-dice",
        # choice color swatches (CustomizationElementDetailsTemplate)
        "charactercreate-customize-palette", "charactercreate-customize-palette-glow",
        "charactercreate-customize-palette-selected",
    ],
    "interface/glues/charactercreate/charactercreateicons.blp": [
        "raceicon128-%s-%s" % (r, s)
        for r in ("human", "dwarf", "nightelf", "gnome", "draenei",
                  "orc", "undead", "tauren", "troll", "bloodelf")
        for s in ("male", "female")
    ] + ["classicon-" + c for c in (
        "warrior", "paladin", "hunter", "rogue", "priest",
        "deathknight", "shaman", "mage", "warlock", "druid")],
    # character select paid service buttons: the double density version (116 x 116), as the
    # single one looks pixelated on screen
    "interface/glues/characterselect/uicharacterselectglues2x.blp": [
        "glues-characterselect-icon-factionchange-2x", "glues-characterselect-icon-factionchange-hover-2x",
        "glues-characterselect-icon-racechange-2x", "glues-characterselect-icon-racechange-hover-2x",
        "glues-characterselect-icon-appearancechange-2x", "glues-characterselect-icon-appearancechange-hover-2x",
    ],
    # auction house panel backgrounds (2048 wide sheet): categories, results and lists,
    # sell panel
    "interface/auctionframe/auctionhousebackgrounds.blp": [
        "auctionhouse-background-categories", "auctionhouse-background-index",
        "auctionhouse-background-sell-left",
    ],
    # trainer category header (TrainerUICategoryTemplate), 2048 sheet
    "interface/professions/professions.blp": [
        "professions-recipe-header-left", "professions-recipe-header-middle",
        "professions-recipe-header-right", "professions-recipe-header-expand",
        "professions-recipe-header-collapse",
        # professions: rank bar, skill-up icons, list rows, list background, reagent slots
        "professions-skillbar-bg", "professions-skillbar-frame",
        "skillbar_fill_flipbook_defaultblue",
        "professions-icon-skill-high", "professions-icon-skill-medium", "professions-icon-skill-low",
        "professions_recipe_active", "professions_recipe_hover",
        "professions-background-summarylist",
        "professions-slot-bg", "professions-slot-frame", "professions-slot-frame-green",
        "professions-slot-frame-blue", "professions-slot-frame-epic", "professions-slot-frame-legendary",
    ],
    # each profession's rank bar: its animated strip (Skillbar_Fill_Flipbook_<profession>,
    # 2 columns of 34 high frames) does not fit 3.3.5, so only its first frame is kept
    # (FIRST_FRAME); and its flare
    "interface/professions/professionsfxalchemyc60.blp": ["skillbar_fill_flipbook_alchemy_c60", "skillbar_flare_alchemy_c60"],
    "interface/professions/professionsfxblacksmithing.blp": ["skillbar_fill_flipbook_blacksmithing", "skillbar_flare_blacksmithing"],
    "interface/professions/professionsfxcooking.blp": ["skillbar_fill_flipbook_cooking", "skillbar_flare_cooking"],
    "interface/professions/professionsfxenchantingc60.blp": ["skillbar_fill_flipbook_enchanting_c60", "skillbar_flare_enchanting_c60"],
    "interface/professions/professionsfxengineering.blp": ["skillbar_fill_flipbook_engineering", "skillbar_flare_engineering"],
    "interface/professions/professionsfxfirstaidc60.blp": ["skillbar_fill_flipbook_firstaid_c60", "skillbar_flare_firstaid_c60"],
    "interface/professions/professionsfxinscription.blp": ["skillbar_fill_flipbook_inscription", "skillbar_flare_inscription"],
    "interface/professions/professionsfxjewelcrafting.blp": ["skillbar_fill_flipbook_jewelcrafting", "skillbar_flare_jewelcrafting"],
    "interface/professions/professionsfxleatherworking.blp": ["skillbar_fill_flipbook_leatherworking", "skillbar_flare_leatherworking"],
    "interface/professions/professionsfxmining.blp": ["skillbar_fill_flipbook_mining", "skillbar_flare_mining"],
    "interface/professions/professionsfxtailoring.blp": ["skillbar_fill_flipbook_tailoring", "skillbar_flare_tailoring"],
    # professions book: professions without a crafting page
    "interface/professions/professionsfxherbalism.blp": ["skillbar_fill_flipbook_herbalism", "skillbar_flare_herbalism"],
    "interface/professions/professionsfxskinningc60.blp": ["skillbar_fill_flipbook_skinning_c60", "skillbar_flare_skinning_c60"],
    "interface/professions/professionsfxfishing.blp": ["skillbar_fill_flipbook_fishing", "skillbar_flare_fishing"],
    # stable: scene background by pet specialization, and the shadow under the pet (2048 sheets)
    "interface/petstableframe/hunterpetstable.blp": [
        "hunter-stable-bg-art_cunning", "hunter-stable-bg-art_ferocity",
        "hunter-stable-bg-art_tenacity",
    ],
    "interface/store/perks.blp": ["perks-char-shadow"],
    # professions: shadow of the crafted count on the output icon
    # (ProfessionsOutputButtonTemplate, CountShadow)
    "interface/petbattles/petbattlehudatlas.blp": ["battlebar-swappetshadow"],
}


_VARIANT = re.compile("^(2x|4x|c[0-9]+)$")


def _logical(name):
    """Name without its variant suffixes, as Camelot's code writes it."""
    parts = name.lower().split("-")
    while len(parts) > 1 and _VARIANT.match(parts[-1]):
        parts.pop()
    return "-".join(parts)


# Sheets wow.export no longer exports as .blp ("[BLTE] Invalid MD5 hash"): read from a PNG
# RGBA export of the same client instead.
PREVIEWS = {
    "interface/glues/charactercreate/charactercreateicons.blp": os.path.join(
        os.path.expanduser("~"), "wow.export", "interface", "glues", "charactercreate", "charactercreateicons.png"),
}

MIN_SIDE = 8

# animated strips (FlipBook) of which only the first frame is kept: 2 columns of 34 high
# frames (ProfessionsRankBarMixin:Update)
FIRST_FRAME = ("skillbar_fill_flipbook_",)

# Slices that join: the client blends each pixel with its neighbor when scaling, so the end of
# an element alone in a wider image fades into the void. The red button slices touch end to
# end, so they sit MARGIN from the left edge with their outer columns copied on each side.
OVERFLOW = {"interface/buttons/128redbuttonc60.blp", "interface/buttons/128redbutton.blp"}
MARGIN = 2


# GET request to the wow.export bridge; returns the decoded JSON answer
def _request(path, params):
    url = BRIDGE + path + "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=900) as r:
        return json.loads(r.read().decode("utf-8"))


# smallest power of two >= n
def _pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


# region of each element in the atlas index, by (sheet, lowercase element name)
def regions():
    data = json.load(io.open(INDEX, encoding="utf-8"))
    match = {}
    for r in data["results"]:
        sheet = (r.get("file") or "").lower()
        if sheet in ELEMENTS and r["atlas"].lower() in [e.lower() for e in ELEMENTS[sheet]]:
            match[(sheet, r["atlas"].lower())] = r["region"]
    missing = [(f, e) for f, l in ELEMENTS.items() for e in l if (f, e.lower()) not in match]
    if missing:
        raise SystemExit("absents de l'index : %s" % missing)
    return match


def main():
    if not _request("/status", {})["ready"]:
        _request("/load-source", {})
        raise SystemExit("la source de wow.export se charge, relancer dans une minute")
    os.makedirs(STAGING, exist_ok=True)
    match = regions()
    entries = []
    for sheet in sorted(ELEMENTS):
        if sheet in PREVIEWS:
            image = Image.open(PREVIEWS[sheet]).convert("RGBA")
        else:
            res = _request("/export", [("dest", STAGING), ("file", sheet)])
            if res["failed"]:
                raise SystemExit("export en echec : %s" % res)
            with io.open(os.path.join(STAGING, sheet.replace("/", os.sep)), "rb") as f:
                width, height, rgba, _ = blp.decode(f.read())
            image = Image.frombytes("RGBA", (width, height), bytes(rgba))
        folder = sheet.split("/")[1]
        os.makedirs(os.path.join(ART, folder), exist_ok=True)
        for name in ELEMENTS[sheet]:
            r = match[(sheet, name.lower())]
            if name.lower().startswith(FIRST_FRAME) and name.lower() != "skillbar_fill_flipbook_defaultblue":
                r = dict(r, width=r["width"] // 2, height=34)
            w, h = r["width"], r["height"]
            piece = image.crop((r["left"], r["top"], r["left"] + w, r["top"] + h))
            # a one-texel strip (creation vignettes, 1 x 451 or 703 x 1) is not shown by 3.3.5,
            # which paints a green rectangle instead. It is copied over MIN_SIDE identical texels;
            # stretched, it looks the same.
            wi, hi = max(w, MIN_SIDE), max(h, MIN_SIDE)
            if (wi, hi) != (w, h):
                piece = piece.resize((wi, hi), Image.NEAREST)
            m = MARGIN if sheet in OVERFLOW else 0
            W, H = _pow2(wi + 2 * m), _pow2(hi)
            canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            canvas.paste(piece, (m, 0))
            for i in range(m):
                canvas.paste(piece.crop((0, 0, 1, hi)), (i, 0))
                canvas.paste(piece.crop((wi - 1, 0, wi, hi)), (m + wi + i, 0))
            # mipmaps in premultiplied alpha: no dark fringes
            full = canvas.convert("RGBa")
            mips = []
            mw, mh = W, H
            while mw > 1 or mh > 1:
                mw, mh = max(1, mw // 2), max(1, mh // 2)
                mips.append((mw, mh, full.resize((mw, mh), Image.LANCZOS).convert("RGBA").tobytes()))
            base = os.path.join(ART, folder, name.lower())
            with io.open(base + ".blp", "wb") as f:
                f.write(blp.encode(W, H, canvas.tobytes(), mips))
            canvas.save(base + ".png")
            path = BS.join(["interface", "ForeverUI", folder, name.lower()])
            entries.append((name.lower(), path, m / float(W), (m + wi) / float(W), hi / float(H), w, h))
            print("   %-36s %d x %d dans %d x %d" % (name, w, h, W, H))

    rows = [
        "-- elements cut out on their own, at their original resolution (sheets too",
        "-- wide for the 3.3.5 client).",
        "-- generated by tools/cut_elements.py from tools/atlas_dump.json",
        "",
        "UIAtlas = UIAtlas or { sheets = {}, data = {} }",
        "",
    ]
    already = set()
    for name, path, u1, u2, v2, w, h in entries:
        # raw name, and the logical name Camelot's code uses
        for key in (name, _logical(name)):
            if key in already:
                continue
            already.add(key)
            rows.append('UIAtlas.data["%s"] = { "%s", %s, %.6f, 0, %.6f, %d, %d }' % (
                key, path.replace(BS, BS + BS), "%.6f" % u1 if u1 else "0", u2, v2, w, h))
    rows.append("")
    io.open(TABLE, "w", encoding="utf-8", newline="\n").write("\n".join(rows))
    print("table : %d elements -> %s" % (len(entries), os.path.relpath(TABLE, ROOT)))


if __name__ == "__main__":
    main()
