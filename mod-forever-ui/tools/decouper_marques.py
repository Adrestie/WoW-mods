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

"""Les marques de l'appel (pret / pas pret / en attente), decoupees.

POURQUOI. Camelot pose UI-LFG-ReadyMark, -DeclineMark et -PendingMark
(readycheck.lua) ; ces elements vivent sur interface/lfgframe/uilfgprompts.blp,
une feuille de 2048 x 2048 -- et le client 3.3.5 n'affiche pas une feuille de
plus de 1024 (constate le 2026-09-22, voir foreverui/blp.py). On decoupe donc
chaque element en une petite image a part.

CE QU'IL FAIT. Il exporte la feuille par le pont de wow.export, lit la region
de chaque element dans tools/atlas_dump.json (jamais de memoire), la reduit
a son cote (64 ou 32, Lanczos, alpha premultiplie) et l'ecrit NON COMPRESSEE avec sa chaine
de mipmaps : affichee en 36 x 36 par le cadre de groupe, elle est reduite,
pas agrandie.

Sortie : data/art/interface/ForeverUI/lfgframe/<nom en minuscules>.blp (+ .png).
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
SORTIE = os.path.join(RACINE, "data", "art", "interface", "ForeverUI", "lfgframe")
STAGING = os.path.join(os.environ.get("TEMP", "."), "foreverui_export")
FEUILLE = "interface/lfgframe/uilfgprompts.blp"

# element -> cote de sortie (une puissance de deux : le client 3.3.5 l'exige)
ELEMENTS = {
    # etape 1, cadre de groupe : marques de l'appel, affichees en 36
    "UI-LFG-ReadyMark": 64, "UI-LFG-DeclineMark": 64, "UI-LFG-PendingMark": 64,
    # etape 2, raid compact : marques "-Raid" (24,4) et roles "micro" (17)
    "UI-LFG-ReadyMark-Raid": 64, "UI-LFG-DeclineMark-Raid": 64, "UI-LFG-PendingMark-Raid": 64,
    "UI-LFG-RoleIcon-Tank-Micro-GroupFinder": 32, "UI-LFG-RoleIcon-Healer-Micro-GroupFinder": 32,
    "UI-LFG-RoleIcon-DPS-Micro-GroupFinder": 32,
}


def _demander(chemin, params):
    url = PONT + chemin + "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=900) as r:
        return json.loads(r.read().decode("utf-8"))


def regions():
    donnees = json.load(io.open(INDEX, encoding="utf-8"))
    trouve = {}
    for r in donnees["results"]:
        # l'index ecrit ses noms en minuscules, camelot avec des capitales
        nom = {e.lower(): e for e in ELEMENTS}.get(r["atlas"].lower())
        if nom and (r.get("file") or "").lower() == FEUILLE:
            trouve[nom] = r["region"]
    manquants = [e for e in ELEMENTS if e not in trouve]
    if manquants:
        raise SystemExit("absents de l'index : %s" % manquants)
    return trouve


def main():
    if not _demander("/status", {})["ready"]:
        _demander("/load-source", {})
        raise SystemExit("la source de wow.export se charge, relancer dans une minute")
    os.makedirs(STAGING, exist_ok=True)
    res = _demander("/export", [("dest", STAGING), ("file", FEUILLE)])
    if res["failed"]:
        raise SystemExit("export en echec : %s" % res)
    with io.open(os.path.join(STAGING, FEUILLE.replace("/", os.sep)), "rb") as f:
        largeur, hauteur, rgba, _ = blp.decoder(f.read())
    feuille = Image.frombytes("RGBA", (largeur, hauteur), bytes(rgba)).convert("RGBa")
    os.makedirs(SORTIE, exist_ok=True)
    for nom, r in sorted(regions().items()):
        COTE = ELEMENTS[nom]
        morceau = feuille.crop((r["left"], r["top"], r["left"] + r["width"], r["top"] + r["height"]))
        plein = morceau.resize((COTE, COTE), Image.LANCZOS)
        mips = []
        cote = COTE
        while cote > 1:
            cote //= 2
            mips.append((cote, cote, plein.resize((cote, cote), Image.LANCZOS).convert("RGBA").tobytes()))
        sortie = plein.convert("RGBA")
        base = os.path.join(SORTIE, nom.lower())
        with io.open(base + ".blp", "wb") as f:
            f.write(blp.encoder(COTE, COTE, sortie.tobytes(), mips))
        sortie.save(base + ".png")
        print("   %-22s region %d x %d -> %d x %d + %d mipmaps" % (nom, r["width"], r["height"], COTE, COTE, len(mips)))


if __name__ == "__main__":
    main()
