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

"""Cuire un portrait rond, pour l'anneau d'une fenetre.

POURQUOI. camelot arrondit le portrait d'une fenetre par SetPortraitToAsset.
Son equivalent 3.3.5, SetPortraitToTexture, laissait carre le portrait du
livre des metiers (constate en jeu le 2026-09-28) : l'icone debordait de
l'anneau. Ce que le client ne fait pas a l'ecran, on le fait avant : le disque
inscrit dans l'image devient son alpha, une fois pour toutes (demande du
2026-09-28 : « doit etre bake afin d'etre ronde et de rentrer dans
l'anneau »).

CE QU'IL FAIT. Il decode l'icone versee par ajouter_feuilles.py (64 x 64),
l'agrandit en 128 x 128 (Lanczos, en alpha premultiplie, comme
affiner_portrait.py), multiplie son alpha par le disque inscrit -- lisse,
calcule sur 4 x 4 echantillons par texel --, et l'ecrit NON COMPRESSEE avec
sa chaine de mipmaps. Le fichier cuit va A COTE de l'icone, suffixe -rond :
l'icone brute reste l'entree, ajouter_feuilles.py la reecrit.
"""
import io
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONES = os.path.join(RACINE, "data", "art", "interface", "ForeverUI", "icons")
PORTRAITS = ["inv_sidetab_professions_c60"]
COTE = 128
ECHANTILLONS = 4


def disque(cote):
    """L'alpha du disque inscrit, lisse : la part de chaque texel dedans."""
    rayon = cote / 2.0
    pas = 1.0 / ECHANTILLONS
    valeurs = bytearray(cote * cote)
    for y in range(cote):
        for x in range(cote):
            dedans = 0
            for sy in range(ECHANTILLONS):
                for sx in range(ECHANTILLONS):
                    dx = x + (sx + 0.5) * pas - rayon
                    dy = y + (sy + 0.5) * pas - rayon
                    if dx * dx + dy * dy <= rayon * rayon:
                        dedans += 1
            valeurs[y * cote + x] = round(255 * dedans / (ECHANTILLONS * ECHANTILLONS))
    return Image.frombytes("L", (cote, cote), bytes(valeurs))


def cuire(nom):
    source = os.path.join(ICONES, nom + ".blp")
    sortie = os.path.join(ICONES, nom + "-rond")
    with io.open(source, "rb") as f:
        largeur, hauteur, rgba, _ = blp.decoder(f.read())
    image = Image.frombytes("RGBA", (largeur, hauteur), bytes(rgba)).convert("RGBa")
    plein = image.resize((COTE, COTE), Image.LANCZOS).convert("RGBA")
    rouge, vert, bleu, alpha = plein.split()
    alpha = Image.frombytes(
        "L", (COTE, COTE), bytes(a * m // 255 for a, m in zip(alpha.tobytes(), disque(COTE).tobytes())))
    rond = Image.merge("RGBA", (rouge, vert, bleu, alpha))
    premul = rond.convert("RGBa")
    mips = []
    cote = COTE
    while cote > 1:
        cote //= 2
        mips.append((cote, cote, premul.resize((cote, cote), Image.LANCZOS).convert("RGBA").tobytes()))
    with io.open(sortie + ".blp", "wb") as f:
        f.write(blp.encoder(COTE, COTE, rond.tobytes(), mips))
    rond.save(sortie + ".png")
    print("%s : %d x %d -> %d x %d rond + %d mipmaps, non compresse" % (
        nom, largeur, hauteur, COTE, COTE, len(mips)))


def main():
    for nom in PORTRAITS:
        cuire(nom)


if __name__ == "__main__":
    main()
