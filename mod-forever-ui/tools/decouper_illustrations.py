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

"""Les grandes illustrations des credits, coupees en tuiles pour 3.3.5.

POURQUOI. CreditsScreen-KeyArt-<n> fait 1425 x 966 sur une feuille de
2048 x 1024 ; le client 3.3.5 n'affiche pas une image de plus de 1024 de
large (voir foreverui/blp.py). La reduire a 1024 perdrait un tiers de sa
finesse sur un ecran ou elle est agrandie. Elle est donc coupee, a pleine
resolution, en tuiles d'au plus 1024 de large, posees cote a cote a l'ecran.

CE QU'IL FAIT. Pour chaque illustration de ILLUSTRATIONS : l'exporte par le
pont de wow.export, lit sa region dans tools/atlas_dump.json (jamais de
memoire), la coupe en tuiles, chacune posee en haut a gauche d'une image aux
cotes en puissances de deux (le reste transparent), ecrite NON COMPRESSEE
avec ses mipmaps dans data/art/interface/ForeverUI/credits/ (+ .png) ; puis
ecrit data/glue/Interface/GlueXML/ForeverUIGlueIllustrations.lua.

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
ART = os.path.join(RACINE, "data", "art", "interface", "ForeverUI", "credits")
TABLE = os.path.join(RACINE, "data", "glue", "Interface", "GlueXML", "ForeverUIGlueIllustrations.lua")
STAGING = os.path.join(os.environ.get("TEMP", "."), "foreverui_export")
BS = chr(92)
TUILE = 1024

# numero d'extension -> element d'atlas (la variante c60 quand camelot en a une)
ILLUSTRATIONS = {
    0: "creditsscreen-keyart-0-c60",
    1: "creditsscreen-keyart-1",
    2: "creditsscreen-keyart-2",
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


def main():
    if not _demander("/status", {})["ready"]:
        _demander("/load-source", {})
        raise SystemExit("la source de wow.export se charge, relancer dans une minute")
    os.makedirs(STAGING, exist_ok=True)
    os.makedirs(ART, exist_ok=True)
    index = json.load(io.open(INDEX, encoding="utf-8"))["results"]
    trouves = {r["atlas"].lower(): r for r in index}

    lignes = [
        "-- les grandes illustrations des credits, coupees en tuiles",
        "-- genere par tools/decouper_illustrations.py depuis tools/atlas_dump.json",
        "",
        "ForeverUIGlue = ForeverUIGlue or {}",
        "ForeverUIGlue.illustrations = {",
    ]
    for extension, nom in sorted(ILLUSTRATIONS.items()):
        r = trouves.get(nom)
        if not r:
            raise SystemExit("absent de l'index : %s" % nom)
        feuille = r["file"].lower()
        res = _demander("/export", [("dest", STAGING), ("file", feuille)])
        if res["failed"]:
            raise SystemExit("export en echec : %s" % res)
        with io.open(os.path.join(STAGING, feuille.replace("/", os.sep)), "rb") as f:
            largeur, hauteur, rgba, _ = blp.decoder(f.read())
        image = Image.frombytes("RGBA", (largeur, hauteur), bytes(rgba))
        reg = r["region"]
        w, h = reg["width"], reg["height"]
        entiere = image.crop((reg["left"], reg["top"], reg["left"] + w, reg["top"] + h))

        tuiles = []
        x = 0
        while x < w:
            lt = min(TUILE, w - x)
            morceau = entiere.crop((x, 0, x + lt, h))
            W, H = _puissance(lt), _puissance(h)
            toile = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            toile.paste(morceau, (0, 0))
            plein = toile.convert("RGBa")
            mips = []
            mw, mh = W, H
            while mw > 1 or mh > 1:
                mw, mh = max(1, mw // 2), max(1, mh // 2)
                mips.append((mw, mh, plein.resize((mw, mh), Image.LANCZOS).convert("RGBA").tobytes()))
            base = "%s-%d" % (nom, len(tuiles) + 1)
            with io.open(os.path.join(ART, base + ".blp"), "wb") as f:
                f.write(blp.encoder(W, H, toile.tobytes(), mips))
            toile.save(os.path.join(ART, base + ".png"))
            chemin = BS.join(["interface", "ForeverUI", "credits", base])
            tuiles.append((chemin, lt / float(W), h / float(H), lt))
            print("   %-36s %d x %d dans %d x %d" % (base, lt, h, W, H))
            x += lt

        lignes.append("\t[%d] = { largeur = %d, hauteur = %d, tuiles = {" % (extension, w, h))
        for chemin, u2, v2, lt in tuiles:
            lignes.append('\t\t{ "%s", %.6f, %.6f, %d },' % (chemin.replace(BS, BS + BS), u2, v2, lt))
        lignes.append("\t} },")
    lignes += ["}", ""]
    io.open(TABLE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print("table : %d illustrations -> %s" % (len(ILLUSTRATIONS), os.path.relpath(TABLE, RACINE)))


if __name__ == "__main__":
    main()
