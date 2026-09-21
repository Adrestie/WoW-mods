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

"""Composer un panneau de sac comme l'addon le pose, et le regarder.

La decoupe en neuf de HeldBagLayout est refaite ici a l'identique : chaque coin
a sa taille d'image, ancre sur le coin du cadre avec son decalage ; chaque bord
tendu entre deux coins.
"""
import os
import sys

from PIL import Image

OUTILS = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(OUTILS)
sys.path.insert(0, OUTILS)
from foreverui.atlas import Atlas  # noqa: E402

SORTIE = os.path.join(RACINE, "docs", "apercu")
os.makedirs(SORTIE, exist_ok=True)

ATLAS = Atlas()


def image(nom):
    return ATLAS.image(nom)


def etire(nom, w, h):
    return ATLAS.image(nom, w, h)


# RELEVE -- mainline/NineSliceLayouts.lua, HeldBagLayout, avec les corrections
# de camelot/NineSliceLayoutOverrides.lua (TopRight x -2, BottomLeft y = -8,
# BottomRight x -2 et y = -8).
COINS = {
    "hautgauche": ("ui-frame-portraitmetal-cornertopleftsmall", "TOPLEFT", -13, 16),
    "hautdroit": ("ui-frame-metal-cornertopright", "TOPRIGHT", 2, 16),
    "basgauche": ("ui-frame-metal-cornerbottomleft", "BOTTOMLEFT", -13, -8),
    "basdroit": ("ui-frame-metal-cornerbottomright", "BOTTOMRIGHT", 2, -8),
}

LARGEUR, HAUTEUR = 192, 240      # CONTAINER_WIDTH et BACKPACK_HEIGHT de 3.3.5
MARGE = 120                      # les coins debordent largement du cadre

toile = Image.new("RGBA", (LARGEUR + 2 * MARGE, HAUTEUR + 2 * MARGE), (24, 26, 32, 255))


def poser(img, gauche, haut):
    toile.alpha_composite(img, (int(round(MARGE + gauche)), int(round(MARGE + haut))))


# le fond plat : couleur de panneau, deux coins arrondis en bas
FOND = (20, 18, 16, 230)         # PANEL_BACKGROUND_COLOR, teinte sombre
fond = Image.new("RGBA", (LARGEUR - 4, HAUTEUR - 23), FOND)
poser(fond, 2, 20)

# les quatre coins, a leur taille d'image
places = {}
for cle, (nom, point, dx, dy) in COINS.items():
    im = image(nom)
    w, h = im.size
    x = dx if "gauche" in cle else LARGEUR - w + dx
    y = -dy if "haut" in cle else HAUTEUR - h - dy
    places[cle] = (x, y, w, h)
    poser(im, x, y)

# les bords, tendus entre deux coins
xg, yg, wg, hg = places["hautgauche"]
xd, yd, wd, hd = places["hautdroit"]
largeur_haut = xd - (xg + wg)
if largeur_haut > 0:
    poser(etire("_ui-frame-metal-edgetop", largeur_haut, hg), xg + wg, yg)

xbg, ybg, wbg, hbg = places["basgauche"]
xbd, ybd, wbd, hbd = places["basdroit"]
largeur_bas = xbd - (xbg + wbg)
if largeur_bas > 0:
    poser(etire("_ui-frame-metal-edgebottom", largeur_bas, hbg), xbg + wbg, ybg)

hauteur_gauche = ybg - (yg + hg)
if hauteur_gauche > 0:
    poser(etire("!ui-frame-metal-edgeleft", wg, hauteur_gauche), xg, yg + hg)
    poser(etire("!ui-frame-metal-edgeright", wd, hauteur_gauche), xd, yd + hd)

print("cadre %d x %d" % (LARGEUR, HAUTEUR))
for cle, (x, y, w, h) in sorted(places.items()):
    print("   %-12s %4d,%4d  %3dx%-3d" % (cle, x, y, w, h))
print("   bord haut %d de large, bord gauche %d de haut" % (largeur_haut, hauteur_gauche))

chemin = os.path.join(SORTIE, "apercu_panneau.png")
toile.save(chemin)
print(chemin)
