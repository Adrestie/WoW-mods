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

"""Composer la fenetre du sac a dos comme l'addon la pose, et la regarder.

Les coordonnees sont celles du code : celles de 3.3.5 pour la grille
d'emplacements, celles de camelot pour l'encadrement, le champ de recherche et
le bouton de tri.
"""
import os
import sys

from PIL import Image, ImageDraw

OUTILS = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(OUTILS)
sys.path.insert(0, OUTILS)
from foreverui.atlas import Atlas  # noqa: E402

SORTIE = os.path.join(RACINE, "docs", "apercu")
os.makedirs(SORTIE, exist_ok=True)
ATLAS = Atlas()

# La mise en page que Bags.lua calcule : entete, grille, bourse, marge.
COLONNES, EMPLACEMENT = 4, 37
PAS_X, PAS_Y = 42, 41
RANGEES = 4
ENTETE = 60          # bande de titre + bande du champ de recherche
BOURSE = 24 + 8      # la bourse et son air
MARGE_BAS = 9
GRILLE_H = RANGEES * PAS_Y - (PAS_Y - EMPLACEMENT)
GRILLE_L = COLONNES * EMPLACEMENT + (COLONNES - 1) * (PAS_X - EMPLACEMENT)
LARGEUR = 192
HAUTEUR = ENTETE + GRILLE_H + BOURSE + MARGE_BAS
MARGE_COTE = (LARGEUR - GRILLE_L) / 2.0

# camelot : HeldBagLayout, avec les corrections de NineSliceLayoutOverrides
COINS = (
    ("ui-frame-portraitmetal-cornertopleftsmall", "gauche", "haut", -13, 16),
    ("ui-frame-metal-cornertopright", "droit", "haut", 2, 16),
    ("ui-frame-metal-cornerbottomleft", "gauche", "bas", -13, -8),
    ("ui-frame-metal-cornerbottomright", "droit", "bas", 2, -8),
)
FOND = (0, 0, 0, 168)          # mesure dans l'art, sous le coin de metal

MARGE = 110
toile = Image.new("RGBA", (LARGEUR + 2 * MARGE, HAUTEUR + 2 * MARGE), (26, 28, 34, 255))


def poser(img, gauche, haut):
    toile.alpha_composite(img, (int(round(MARGE + gauche)), int(round(MARGE + haut))))


# ------------------------------------------------------------- le fond plat
corps = Image.new("RGBA", (LARGEUR - 4, HAUTEUR - 23), FOND)
poser(corps, 2, 20)
for nom, cote, bord in (("uiframebackground-nineslice-cornerbottomleft", "gauche", "bas"),
                        ("uiframebackground-nineslice-cornerbottomright", "droit", "bas")):
    im = ATLAS.image(nom)
    teinte = Image.new("RGBA", im.size, FOND)
    teinte.putalpha(Image.eval(im.getchannel("A"), lambda a: int(a * FOND[3] / 255.0)))
    x = 2 if cote == "gauche" else LARGEUR - im.size[0] - 2
    poser(teinte, x, HAUTEUR - im.size[1] - 3)

# --------------------------------------------------------- les emplacements
# 3.3.5 : le premier bouton en BOTTOMRIGHT (-12, -208) du haut du cadre, puis
# -5 vers la gauche et +4 vers le haut d'une rangee a l'autre.
slot = ATLAS.image("bags-item-slot64", EMPLACEMENT, EMPLACEMENT)
contour = ATLAS.image("ui-hud-actionbar-iconframe-bags", EMPLACEMENT, EMPLACEMENT)
for rangee in range(RANGEES):
    for colonne in range(COLONNES):
        x = LARGEUR - MARGE_COTE - EMPLACEMENT - colonne * PAS_X
        y = ENTETE + rangee * PAS_Y
        poser(slot, x, y)
        poser(contour, x, y)

# ------------------------------------------------------------ l'encadrement
places = {}
for nom, cote, bord, dx, dy in COINS:
    im = ATLAS.image(nom)
    w, h = im.size
    x = dx if cote == "gauche" else LARGEUR - w + dx
    y = -dy if bord == "haut" else HAUTEUR - h - dy
    places[(cote, bord)] = (x, y, w, h)
    poser(im, x, y)

xg, yg, wg, hg = places[("gauche", "haut")]
xd, yd, wd, hd = places[("droit", "haut")]
xbg, ybg, wbg, hbg = places[("gauche", "bas")]
xbd, ybd, wbd, hbd = places[("droit", "bas")]
poser(ATLAS.image("_ui-frame-metal-edgetop", xd - (xg + wg), hg), xg + wg, yg)
poser(ATLAS.image("_ui-frame-metal-edgebottom", xbd - (xbg + wbg), hbg), xbg + wbg, ybg)
poser(ATLAS.image("!ui-frame-metal-edgeleft", wg, ybg - (yg + hg)), xg, yg + hg)
poser(ATLAS.image("!ui-frame-metal-edgeright", wd, ybd - (yd + hd)), xd, yd + hd)

# ------------------------------------------ le champ et le bouton de tri
dessin = ImageDraw.Draw(toile)
# le champ : 96 x 18 en TOPLEFT (42, -37), bordure de saisie du client
dessin.rectangle([MARGE + 42, MARGE + 37, MARGE + 42 + 96, MARGE + 37 + 18],
                 fill=(10, 10, 12, 220), outline=(90, 78, 60, 255))
poser(ATLAS.image("common-search-magnifyingglass", 10, 10), 43, 41)
dessin.text((MARGE + 60, MARGE + 41), "Rechercher", fill=(140, 140, 140, 255))

# le bouton de tri : 28 x 26 en TOPRIGHT (-9, -34)
tri = ATLAS.image("bags-button-autosort-up", 28, 26)
poser(tri, LARGEUR - 9 - 28, 34)

# le portrait, dans l'anneau du coin
dessin.ellipse([MARGE + 13.5 - 17, MARGE + 14 - 17, MARGE + 13.5 + 17, MARGE + 14 + 17],
               fill=(60, 45, 30, 255))
dessin.text((MARGE + 90, MARGE + 6), "Sac a dos", fill=(255, 210, 140, 255))

dessin.text((MARGE + LARGEUR - 80, MARGE + HAUTEUR - 26), "12g 34a 56c",
            fill=(255, 220, 150, 255))

chemin = os.path.join(SORTIE, "apercu_sacs.png")
toile.save(chemin)
print("fenetre %d x %d" % (LARGEUR, HAUTEUR))
print(chemin)
