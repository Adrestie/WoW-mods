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

"""Cuit les deux emblemes du joueur « Deshonore » : le blason brise.

LA DEMANDE (2026-09-28). Deshonore, le joueur perd le symbole de sa faction
au centre du cadran de l'onglet JcJ. L'icone du debuff, carree, montrait ses
bords et se faisait couper aux coins : « il faut surement en dessiner 2
nouvelles (une pour la horde et une pour l'alliance afin de blend
correctement avec le contour) ».

LE PARTI. Chaque embleme de faction de camelot, BRISE : la meme silhouette --
son canal alpha est garde tel quel, c'est lui qui le fond dans le cadran --
ternie vers une teinte sourde de sa faction, fendue d'une diagonale en zigzag,
les deux moitiees ecartees ; le fond de faction du cadran se voit dans la
faille, et une lueur rouge sourde en borde les levres.

SOURCE. data/art/interface/foreverui/pvpframe/uicharacterinfohonorc60.blp,
les elements ui-character-info-honor-icon-alliance / -horde (75 x 75,
UIAtlas_06_complements.lua).

SORTIE. data/art/interface/foreverui/pvpframe/ :
    honor-dishonored-alliance.blp   128 x 128, niveaux reduits jusqu'a 1 x 1
    honor-dishonored-horde.blp
avec leurs apercus .png. PvPTab.lua les pose a la taille des emblemes
(72 x 84).

    python tools/cuire_deshonneur.py
"""
import io
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from foreverui import blp

ICI = os.path.dirname(os.path.abspath(__file__))
ATELIER = os.path.dirname(ICI)
DOSSIER = os.path.join(ATELIER, "data", "art", "interface", "foreverui", "pvpframe")
FEUILLE = os.path.join(DOSSIER, "uicharacterinfohonorc60.blp")

# u1, u2, v1, v2 dans la feuille (UIAtlas_06_complements.lua)
EMBLEMES = {
    "alliance": (0.642578, 0.789062, 0.824219, 0.970703),
    "horde": (0.792969, 0.939453, 0.673828, 0.820312),
}

# la teinte sourde de chaque faction, et ce qu'on garde de la couleur d'origine
TEINTES = {
    "alliance": (92, 102, 124),
    "horde": (104, 84, 78),
}
COULEUR_GARDEE = 0.18
ASSOMBRI = 0.72

TRAVAIL = 4          # l'embleme est travaille a quatre fois sa taille
SORTIE = 128         # puis rendu en 128 x 128
ECART = 16           # l'ecart des deux moitiees, en pixels de travail
LEVRE = 9            # la faille elle-meme, en pixels de travail
LUEUR = (235, 70, 25)
LUEUR_FLOU = 6
LUEUR_FORCE = 0.85


def lire_feuille():
    largeur, hauteur, rgba, _ = blp.decoder(io.open(FEUILLE, "rb").read())
    return Image.frombytes("RGBA", (largeur, hauteur), bytes(rgba))


def decouper(feuille, rect):
    w, h = feuille.size
    u1, u2, v1, v2 = rect
    return feuille.crop((round(u1 * w), round(v1 * h), round(u2 * w), round(v2 * h)))


def ternir(image, teinte):
    """La couleur de l'embleme vers une teinte sourde de sa faction, a
    luminance gardee ; l'alpha ne bouge pas."""
    r, v, b, a = image.split()
    gris = Image.merge("RGB", (r, v, b)).convert("L")
    teinte_img = Image.merge("RGB", [gris.point(lambda x, c=c: x * c / 255.0) for c in teinte])
    origine = Image.merge("RGB", (r, v, b))
    melange = Image.blend(teinte_img, origine, COULEUR_GARDEE)
    melange = melange.point(lambda x: x * ASSOMBRI)
    return Image.merge("RGBA", (*melange.split(), a))


def faille(taille, graine):
    """La ligne de fracture : du haut a droite vers le bas a gauche, en
    zigzag regulier (la graine la fige d'une cuisson a l'autre)."""
    alea = random.Random(graine)
    n = 9
    points = []
    for i in range(n + 1):
        t = i / n
        x = taille * (0.80 - 0.60 * t)
        y = taille * (0.02 + 0.96 * t)
        if 0 < i < n:
            ecart = taille * 0.055 * (1 if i % 2 else -1) * (0.6 + 0.8 * alea.random())
            x += ecart
        points.append((x, y))
    return points


def briser(image, points):
    """Les deux moitiees, de part et d'autre de la faille, ecartees ; la
    faille evidee ; une lueur rouge sur ses levres, dans la silhouette."""
    taille = image.size[0]
    cote = Image.new("L", image.size, 0)
    # la moitie droite : la faille, puis le bord droit de l'image
    ImageDraw.Draw(cote).polygon(points + [(taille * 2, taille * 2), (taille * 2, -taille)], fill=255)
    droite = Image.new("RGBA", image.size, (0, 0, 0, 0))
    droite.paste(image, (0, 0), cote)
    gauche = Image.new("RGBA", image.size, (0, 0, 0, 0))
    gauche.paste(image, (0, 0), ImageChops.invert(cote))

    # l'ecart : perpendiculaire a la diagonale, de part et d'autre
    d = ECART // 2
    brise = Image.new("RGBA", image.size, (0, 0, 0, 0))
    brise.alpha_composite(gauche, (-d, -d // 2))
    brise.alpha_composite(droite, (d, d // 2))

    # la faille evidee, meme la ou les moities se recouvrent
    trait = Image.new("L", image.size, 0)
    ImageDraw.Draw(trait).line(points, fill=255, width=LEVRE, joint="curve")
    r, v, b, a = brise.split()
    a = ImageChops.subtract(a, trait)

    # la lueur des levres, gardee dans la silhouette
    halo = Image.new("L", image.size, 0)
    ImageDraw.Draw(halo).line(points, fill=255, width=LEVRE + 2 * ECART, joint="curve")
    halo = halo.filter(ImageFilter.GaussianBlur(LUEUR_FLOU))
    halo = ImageChops.multiply(halo, a).point(lambda x: x * LUEUR_FORCE)
    rouge = Image.new("RGB", image.size, LUEUR)
    couleur = Image.composite(rouge, Image.merge("RGB", (r, v, b)), halo)
    return Image.merge("RGBA", (*couleur.split(), a))


def niveaux(image):
    """Les niveaux reduits : l'image s'affiche plus petite que sa taille."""
    out = []
    w = image.size[0] // 2
    while w >= 1:
        reduit = image.resize((w, w), Image.LANCZOS)
        out.append((w, w, reduit.tobytes()))
        w //= 2
    return out


def cuire(faction, feuille, graine):
    embleme = decouper(feuille, EMBLEMES[faction])
    grand = embleme.resize((embleme.size[0] * TRAVAIL, embleme.size[1] * TRAVAIL), Image.LANCZOS)
    grand = ternir(grand, TEINTES[faction])
    grand = briser(grand, faille(grand.size[0], graine))
    final = grand.resize((SORTIE, SORTIE), Image.LANCZOS)
    nom = "honor-dishonored-%s" % faction
    chemin = os.path.join(DOSSIER, nom + ".blp")
    io.open(chemin, "wb").write(blp.encoder(SORTIE, SORTIE, final.tobytes(), niveaux(final)))
    final.save(os.path.join(DOSSIER, nom + ".png"))
    print("ecrit :", chemin)


def main():
    feuille = lire_feuille()
    for graine, faction in enumerate(sorted(EMBLEMES)):
        cuire(faction, feuille, 1234 + graine)


if __name__ == "__main__":
    main()
