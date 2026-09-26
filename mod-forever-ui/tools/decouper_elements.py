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

"""Des elements d'atlas decoupes a part, a leur resolution d'origine.

POURQUOI. Le client 3.3.5 n'affiche pas une feuille de plus de 1024 de large
(voir foreverui/blp.py), et exige des cotes en puissances de deux. Plusieurs
feuilles de camelot font 2048 (interface/lfgframe/groupfinder.blp...).
decouper_marques.py reduit ses marques a un carre ; ici l'element garde SA
taille : il est pose en haut a gauche d'une image aux cotes en puissances de
deux, le reste transparent, et la table d'atlas porte les coordonnees de la
partie utile.

CE QU'IL FAIT. Pour chaque feuille de ELEMENTS : l'exporte par le pont de
wow.export, lit la region de chaque element dans tools/atlas_dump.json
(jamais de memoire), l'ecrit NON COMPRESSEE avec ses mipmaps dans
data/art/interface/ForeverUI/<dossier de la feuille>/<element>.blp (+ .png),
puis regenere data/addon/ForeverUI/UIAtlas_07_decoupes.lua : ForeverUI.SetAtlas
trouve ces elements sous leur nom de camelot.

wow.export doit tourner avec sa source chargee (pont sur le port 9455).
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

PONT = "http://127.0.0.1:9455"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(RACINE, "tools", "atlas_dump.json")
ART = os.path.join(RACINE, "data", "art", "interface", "ForeverUI")
TABLE = os.path.join(RACINE, "data", "addon", "ForeverUI", "UIAtlas_07_decoupes.lua")
STAGING = os.path.join(os.environ.get("TEMP", "."), "foreverui_export")
BS = "\\"

# feuille -> les elements a en tirer
ELEMENTS = {
    # le chercheur de groupe (blizzard_groupfinder_vanillastyle, 2026-09-26)
    "interface/lfgframe/groupfinder.blp": [
        "groupfinder-background", "groupfinder-button-cover",
        "groupfinder-button-dungeons", "groupfinder-button-custom-pve",
        "groupfinder-button-questing", "groupfinder-button-raids-warlords",
        # le navigateur de raid (etape 2) : selection et survol des lignes,
        # roles, attente, classes de WotLK
        "groupfinder-highlightbar-blue", "groupfinder-highlightbar-yellow",
        "groupfinder-icon-role-micro-tank", "groupfinder-icon-role-micro-heal",
        "groupfinder-icon-role-micro-dps", "groupfinder-waitdot",
    ] + ["groupfinder-icon-class-" + c for c in (
        "deathknight", "druid", "hunter", "mage", "paladin",
        "priest", "rogue", "shaman", "warlock", "warrior")],
    "interface/hud/uigroupfinderflipbook.blp": ["groupfinder-eye-frame"],
    "interface/shop/catalogshop.blp": ["shop-list-rule"],
}


def _demander(chemin, params):
    url = PONT + chemin + "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=900) as r:
        return json.loads(r.read().decode("utf-8"))


def _puissance(n):
    p = 1
    while p < n:
        p *= 2
    return p


def regions():
    donnees = json.load(io.open(INDEX, encoding="utf-8"))
    trouve = {}
    for r in donnees["results"]:
        feuille = (r.get("file") or "").lower()
        if feuille in ELEMENTS and r["atlas"].lower() in [e.lower() for e in ELEMENTS[feuille]]:
            trouve[(feuille, r["atlas"].lower())] = r["region"]
    manquants = [(f, e) for f, l in ELEMENTS.items() for e in l if (f, e.lower()) not in trouve]
    if manquants:
        raise SystemExit("absents de l'index : %s" % manquants)
    return trouve


def main():
    if not _demander("/status", {})["ready"]:
        _demander("/load-source", {})
        raise SystemExit("la source de wow.export se charge, relancer dans une minute")
    os.makedirs(STAGING, exist_ok=True)
    trouve = regions()
    entrees = []
    for feuille in sorted(ELEMENTS):
        res = _demander("/export", [("dest", STAGING), ("file", feuille)])
        if res["failed"]:
            raise SystemExit("export en echec : %s" % res)
        with io.open(os.path.join(STAGING, feuille.replace("/", os.sep)), "rb") as f:
            largeur, hauteur, rgba, _ = blp.decoder(f.read())
        image = Image.frombytes("RGBA", (largeur, hauteur), bytes(rgba))
        dossier = feuille.split("/")[1]
        os.makedirs(os.path.join(ART, dossier), exist_ok=True)
        for nom in ELEMENTS[feuille]:
            r = trouve[(feuille, nom.lower())]
            w, h = r["width"], r["height"]
            morceau = image.crop((r["left"], r["top"], r["left"] + w, r["top"] + h))
            W, H = _puissance(w), _puissance(h)
            toile = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            toile.paste(morceau, (0, 0))
            # les mipmaps en alpha premultiplie : pas de franges sombres
            plein = toile.convert("RGBa")
            mips = []
            mw, mh = W, H
            while mw > 1 or mh > 1:
                mw, mh = max(1, mw // 2), max(1, mh // 2)
                mips.append((mw, mh, plein.resize((mw, mh), Image.LANCZOS).convert("RGBA").tobytes()))
            base = os.path.join(ART, dossier, nom.lower())
            with io.open(base + ".blp", "wb") as f:
                f.write(blp.encoder(W, H, toile.tobytes(), mips))
            toile.save(base + ".png")
            chemin = BS.join(["interface", "ForeverUI", dossier, nom.lower()])
            entrees.append((nom.lower(), chemin, w / float(W), h / float(H), w, h))
            print("   %-36s %d x %d dans %d x %d" % (nom, w, h, W, H))

    lignes = [
        "-- elements decoupes a part, a leur resolution d'origine (feuilles trop",
        "-- larges pour le client 3.3.5).",
        "-- genere par tools/decouper_elements.py depuis tools/atlas_dump.json",
        "",
        "UIAtlas = UIAtlas or { sheets = {}, data = {} }",
        "",
    ]
    for nom, chemin, u2, v2, w, h in entrees:
        lignes.append('UIAtlas.data["%s"] = { "%s", 0, %.6f, 0, %.6f, %d, %d }' % (
            nom, chemin.replace(BS, BS + BS), u2, v2, w, h))
    lignes.append("")
    io.open(TABLE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print("table : %d elements -> %s" % (len(entrees), os.path.relpath(TABLE, RACINE)))


if __name__ == "__main__":
    main()
