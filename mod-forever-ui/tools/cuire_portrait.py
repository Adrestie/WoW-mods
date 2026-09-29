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


# LE PORTRAIT DE LegacySystemFrame (2026-09-29). Cette fenetre de
# camelot pose l'atlas Legacy-up-c60 a 45 x 62 dans le portrait de
# PortraitFrameTemplate, dont le CircleMask (TempPortraitAlphaMask : un disque
# inscrit dans son image, verifie a l'export) le suit de (2, 0) a (-2, 4) --
# une ellipse de 41 x 58. 3.3.5 n'a pas de masque : l'ellipse est cuite dans
# l'element que decouper_elements.py a pose en haut a gauche de sa toile, et
# le resultat va a cote, suffixe -masque, sur une toile de meme taille (la
# table d'atlas de l'element vaut pour lui).
#   element : (dossier/nom, largeur, hauteur de la region utile)
#   boite   : la taille a l'ecran ; ancres : gauche, haut, droite, bas du
#             masque, comme les ancres de camelot (x, y des coins)
MASQUES = [
    {"element": ("hud", "legacy-up-c60", 198, 273), "boite": (45, 62), "ancres": (2, 0, -2, 4)},
]
ART = os.path.dirname(ICONES)


def ellipse(largeur, hauteur, x0, y0, x1, y1):
    """L'alpha de l'ellipse inscrite dans (x0, y0)-(x1, y1), en texels, lisse."""
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    rx, ry = (x1 - x0) / 2.0, (y1 - y0) / 2.0
    pas = 1.0 / ECHANTILLONS
    valeurs = bytearray(largeur * hauteur)
    for y in range(hauteur):
        for x in range(largeur):
            dedans = 0
            for sy in range(ECHANTILLONS):
                for sx in range(ECHANTILLONS):
                    dx = (x + (sx + 0.5) * pas - cx) / rx
                    dy = (y + (sy + 0.5) * pas - cy) / ry
                    if dx * dx + dy * dy <= 1.0:
                        dedans += 1
            valeurs[y * largeur + x] = round(255 * dedans / (ECHANTILLONS * ECHANTILLONS))
    return Image.frombytes("L", (largeur, hauteur), bytes(valeurs))


def masquer(m):
    dossier, nom, w, h = m["element"]
    bw, bh = m["boite"]
    g, hh, d, b = m["ancres"]
    base = os.path.join(ART, dossier, nom)
    with io.open(base + ".blp", "rb") as f:
        W, H, rgba, _ = blp.decoder(f.read())
    toile = Image.frombytes("RGBA", (W, H), bytes(rgba))
    sx, sy = w / float(bw), h / float(bh)
    masque = ellipse(w, h, g * sx, -hh * sy, (bw + d) * sx, (bh - b) * sy)
    element = toile.crop((0, 0, w, h))
    rouge, vert, bleu, alpha = element.split()
    alpha = Image.frombytes("L", (w, h), bytes(a * k // 255 for a, k in zip(alpha.tobytes(), masque.tobytes())))
    sortie = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sortie.paste(Image.merge("RGBA", (rouge, vert, bleu, alpha)), (0, 0))
    plein = sortie.convert("RGBa")
    mips = []
    mw, mh = W, H
    while mw > 1 or mh > 1:
        mw, mh = max(1, mw // 2), max(1, mh // 2)
        mips.append((mw, mh, plein.resize((mw, mh), Image.LANCZOS).convert("RGBA").tobytes()))
    with io.open(base + "-masque.blp", "wb") as f:
        f.write(blp.encoder(W, H, sortie.tobytes(), mips))
    sortie.save(base + "-masque.png")
    print("%s/%s : ellipse %d x %d de la boite %d x %d cuite, toile %d x %d + %d mipmaps" % (
        dossier, nom, bw - g + d, bh + hh - b, bw, bh, W, H, len(mips)))


def main():
    for nom in PORTRAITS:
        cuire(nom)
    for m in MASQUES:
        masquer(m)


if __name__ == "__main__":
    main()
