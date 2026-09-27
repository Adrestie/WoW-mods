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

"""Cuire les masques de la creation de personnage dans l'alpha des icones.

POURQUOI. camelot decoupe les icones de la creation par des MaskTexture, que
3.3.5 n'a pas. Meme remede que tools/cuire_masque.py : l'alpha du masque est
multiplie dans celui de l'icone, une fois pour toutes.

LA GEOMETRIE, prise sur la source (RingedMaskedButtonMixin:OnLoad,
blizzard_sharedxml/shared/frametemplate/ringedframetemplate.lua:93-94 ;
blizzard_charactercreate/camelot/*.xml) :

  bouton de race    79 x 79, icone sur tout le bouton, masque
                    character-create-icon-mask a 2 px du bord (75 x 75)
  bouton de classe  66 x 66, meme masque a 2 px du bord (62 x 62)
  portrait          62 x 62 (CharacterCreateDetaislListTemplate), masque
                    character-create-icon-circle-mask de (2, 0) a (-2, 4)
                    du portrait, soit le rectangle 2..60 x 0..58

Hors du masque, son wrap est CLAMPTOBLACKADDITIVE : rien.

CE QU'IL LIT. Les icones decoupees par tools/decouper_elements.py
(glues/raceicon128-*.png, glues/classicon-*.png), les fonds de faction et les
masques dans la feuille c60 unknown/8203433.png, aux regions de
tools/atlas_dump.json.

CE QU'IL ECRIT. charactercreate/bouton-<icone>.blp et
charactercreate/portrait-<icone>.blp (+ .png), 128 x 128, non compresses,
avec leurs mipmaps en alpha premultiplie.
"""
import glob
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
FEUILLE_C60 = os.path.join(ART, "unknown", "8203433.png")
SORTIE = os.path.join(ART, "charactercreate")
TAILLE = 128

BOUTONS = {"raceicon128-": (79.0, 2.0), "classicon-": (66.0, 2.0)}
PORTRAIT = 62.0
PORTRAIT_MASQUE = (2.0, 0.0, 60.0, 58.0)    # gauche, haut, droite, bas


def _region(nom):
    for r in json.load(io.open(INDEX, encoding="utf-8"))["results"]:
        if r["atlas"].lower() == nom and r.get("fileDataID") == 8203433:
            return r["region"]
    raise SystemExit("absent de l'index : %s" % nom)


def _masque(feuille, nom):
    r = _region(nom)
    return feuille.crop((r["left"], r["top"], r["left"] + r["width"], r["top"] + r["height"])).getchannel("A")


def _alpha(masque, u, v):
    """L'alpha du masque en (u, v) de [0, 1], lu en bilineaire ; 0 dehors."""
    if u < 0 or v < 0 or u > 1 or v > 1:
        return 0.0
    w, h = masque.size
    x = min(max(u * w - 0.5, 0), w - 1)
    y = min(max(v * h - 0.5, 0), h - 1)
    x0, y0 = int(x), int(y)
    x1, y1 = min(x0 + 1, w - 1), min(y0 + 1, h - 1)
    fx, fy = x - x0, y - y0
    p = masque.load()
    haut = p[x0, y0] * (1 - fx) + p[x1, y0] * fx
    bas = p[x0, y1] * (1 - fx) + p[x1, y1] * fx
    return (haut * (1 - fy) + bas * fy) / 255.0


def _cuire(icone, masque, cote, rect):
    """icone : image TAILLE x TAILLE posee sur un cadre de `cote` ; rect : le
    masque dans ce cadre (gauche, haut, droite, bas)."""
    g, h, d, b = rect
    sortie = icone.copy()
    px = sortie.load()
    for y in range(TAILLE):
        for x in range(TAILLE):
            cx = (x + 0.5) * cote / TAILLE
            cy = (y + 0.5) * cote / TAILLE
            a = _alpha(masque, (cx - g) / (d - g), (cy - h) / (b - h))
            r_, v_, b_, a_ = px[x, y]
            px[x, y] = (r_, v_, b_, int(round(a_ * a)))
    return sortie


def _ecrire(image, nom):
    plein = image.convert("RGBa")
    mips = []
    mw, mh = image.size
    while mw > 1 or mh > 1:
        mw, mh = max(1, mw // 2), max(1, mh // 2)
        mips.append((mw, mh, plein.resize((mw, mh), Image.LANCZOS).convert("RGBA").tobytes()))
    base = os.path.join(SORTIE, nom)
    with io.open(base + ".blp", "wb") as f:
        f.write(blp.encoder(image.size[0], image.size[1], image.tobytes(), mips))
    image.save(base + ".png")


def main():
    os.makedirs(SORTIE, exist_ok=True)
    feuille = Image.open(FEUILLE_C60).convert("RGBA")
    carre = _masque(feuille, "character-create-icon-mask-c60")
    rond = _masque(feuille, "character-create-icon-circle-mask-c60")

    n = 0
    for prefixe, (cote, marge) in sorted(BOUTONS.items()):
        for chemin in sorted(glob.glob(os.path.join(ART, "glues", prefixe + "*.png"))):
            nom = os.path.splitext(os.path.basename(chemin))[0]
            icone = Image.open(chemin).convert("RGBA").resize((TAILLE, TAILLE), Image.LANCZOS)
            _ecrire(_cuire(icone, carre, cote, (marge, marge, cote - marge, cote - marge)), "bouton-" + nom)
            n += 1
            if prefixe == "raceicon128-":
                _ecrire(_cuire(icone, rond, PORTRAIT, PORTRAIT_MASQUE), "portrait-" + nom)
                n += 1

    # les portraits de faction : charactercreate-icon-alliancebg / -hordebg
    for nom in ("charactercreate-icon-alliancebg-c60", "charactercreate-icon-hordebg-c60"):
        r = _region(nom)
        icone = feuille.crop((r["left"], r["top"], r["left"] + r["width"], r["top"] + r["height"]))
        icone = icone.resize((TAILLE, TAILLE), Image.LANCZOS)
        _ecrire(_cuire(icone, rond, PORTRAIT, PORTRAIT_MASQUE), "portrait-" + nom[:-len("-c60")])
        n += 1

    print("creation : %d images cuites -> %s" % (n, os.path.relpath(SORTIE, RACINE)))


if __name__ == "__main__":
    main()
