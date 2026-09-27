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

"""L'encadrement des champs de la connexion, affine pour 3.3.5.

POURQUOI. Tooltip-Glues-NineSlice (uiframetooltipgluesc60 et sa feuille
verticale) est un trait d'UN texel, avec un arrondi de deux, compresse en
DXT5 et SANS MIPMAP. Les ecrans d'accueil l'agrandissent a l'echelle de
l'ecran : les coins paraissent pixelises (constate en jeu le 2026-09-27).
Meme lecon que le portrait de la fenetre Social (tools/affiner_portrait.py).
Meme cas pour le curseur des options (Minimal_SliderBar, minimalsliderbarc60 :
bouton de 20 x 19), pixelise en jeu le 2026-09-27.

CE QU'IL FAIT. Pour chaque feuille, il decode le BLP verse par
ajouter_feuilles.py et l'agrandit une fois pour toutes, x4, ELEMENT PAR
ELEMENT (les regions de tools/atlas_dump.json) : chaque element est d'abord
borde de ses propres pixels, pour que le filtre ne tire rien de son voisin
dans la feuille. Lanczos en alpha premultiplie, puis ecriture NON
COMPRESSEE (BGRA) avec toute la chaine de mipmaps : le client REDUIT
l'image au lieu de l'agrandir.

Il ecrit <feuille>-hd a cote de l'original, qui reste tel que le client
moderne le donne. Les coordonnees ne changent pas (l'image garde ses
proportions) : tools/atlas_accueil.py pointe seulement vers le fichier -hd.
"""
import io
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(RACINE, "data", "art", "interface", "ForeverUI")
INDEX = os.path.join(RACINE, "tools", "atlas_dump.json")
FACTEUR = 4
BORDURE = 3
# Marge de l'element dans la feuille affinee, en pixels de celle-ci. Le client
# lit une image agrandie en melangeant chaque pixel avec son voisin : au bout
# d'un element, ce voisin est le vide de la feuille, et le bout s'estompe --
# un leger trou entre les coins droits et les bords horizontaux (constate en
# jeu le 2026-09-27). L'element deborde donc de 2 pixels de sa propre
# couleur ; les elements sont separes de 8 dans la feuille, rien ne se touche.
MARGE = 2

# feuille du client moderne -> chemin dans l'atelier, sans extension
FEUILLES = {
    "interface/glues/common/uiframetooltipgluesc60.blp": "glues/common/uiframetooltipgluesc60",
    "interface/glues/common/uiframetooltipgluesverticalc60.blp": "glues/common/uiframetooltipgluesverticalc60",
    "interface/buttons/minimalsliderbarc60.blp": "buttons/minimalsliderbarc60",
    # l'infobulle des options : des coins de 7
    "interface/tooltips/uiframetooltipc60.blp": "tooltips/uiframetooltipc60",
    "interface/tooltips/uiframetooltipverticalc60.blp": "tooltips/uiframetooltipverticalc60",
    # la coche des cases (checkmark-minimal) : 30 x 29, pas de variante
    # -2x chez camelot, pixelisee en jeu (constate le 2026-09-27)
    "interface/common/minimalcheckbox.blp": "common/minimalcheckbox",
    # le cadre bronze de la liste des personnages (heavybronze-*-c60) : une
    # feuille que le listfile ne nomme pas, designee par son identifiant
    "fdid:8203429": "unknown/8203429",
}


def agrandir_element(image, r):
    """La region r, bordee de ses propres pixels, agrandie, puis recoupee."""
    x, y, w, h = r["left"], r["top"], r["width"], r["height"]
    morceau = image.crop((x, y, x + w, y + h))
    borde = Image.new("RGBa", (w + 2 * BORDURE, h + 2 * BORDURE))
    borde.paste(morceau, (BORDURE, BORDURE))
    # les bords recopies vers l'exterieur, coins compris
    for i in range(BORDURE):
        borde.paste(morceau.crop((0, 0, w, 1)), (BORDURE, i))
        borde.paste(morceau.crop((0, h - 1, w, h)), (BORDURE, BORDURE + h + i))
    for i in range(BORDURE):
        borde.paste(borde.crop((BORDURE, 0, BORDURE + 1, h + 2 * BORDURE)), (i, 0))
        borde.paste(borde.crop((BORDURE + w - 1, 0, BORDURE + w, h + 2 * BORDURE)), (BORDURE + w + i, 0))
    grand = borde.resize((borde.width * FACTEUR, borde.height * FACTEUR), Image.LANCZOS)
    b = BORDURE * FACTEUR - MARGE
    return grand.crop((b, b, b + w * FACTEUR + 2 * MARGE, b + h * FACTEUR + 2 * MARGE))


def main():
    index = json.load(io.open(INDEX, encoding="utf-8"))["results"]
    for feuille, atelier in sorted(FEUILLES.items()):
        source = os.path.join(ART, *atelier.split("/")) + ".blp"
        with io.open(source, "rb") as f:
            largeur, hauteur, rgba, _ = blp.decoder(f.read())
        image = Image.frombytes("RGBA", (largeur, hauteur), bytes(rgba)).convert("RGBa")

        if feuille.startswith("fdid:"):
            fdid = int(feuille[5:])
            regions = [r["region"] for r in index if r.get("fileDataID") == fdid]
        else:
            regions = [r["region"] for r in index if (r.get("file") or "").lower() == feuille]
        if not regions:
            raise SystemExit("aucun element pour %s dans l'index" % feuille)

        W, H = largeur * FACTEUR, hauteur * FACTEUR
        toile = Image.new("RGBa", (W, H))
        vus = set()
        for r in regions:
            cle = (r["left"], r["top"], r["width"], r["height"])
            if cle in vus:
                continue
            vus.add(cle)
            toile.paste(agrandir_element(image, r), (r["left"] * FACTEUR - MARGE, r["top"] * FACTEUR - MARGE))

        mips = []
        mw, mh = W, H
        while mw > 1 or mh > 1:
            mw, mh = max(1, mw // 2), max(1, mh // 2)
            mips.append((mw, mh, toile.resize((mw, mh), Image.LANCZOS).convert("RGBA").tobytes()))
        plein = toile.convert("RGBA")
        sortie = os.path.join(ART, *atelier.split("/")) + "-hd"
        with io.open(sortie + ".blp", "wb") as f:
            f.write(blp.encoder(W, H, plein.tobytes(), mips))
        plein.save(sortie + ".png")
        print("   %-50s %d x %d -> %d x %d, %d elements" % (
            atelier + "-hd", largeur, hauteur, W, H, len(vus)))


if __name__ == "__main__":
    main()
