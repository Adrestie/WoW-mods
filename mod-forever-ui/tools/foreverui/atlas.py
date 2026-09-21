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

"""Lire les tables d'atlas de l'addon, et en tirer des images.

POURQUOI LIRE LES TABLES ET NON L'INDEX DU CLIENT. Un apercu qui part de
l'index brut peut montrer autre chose que ce que l'addon affiche : c'est la
table generee qui decide quelle variante, quel rectangle et quelle taille le
jeu recoit. En la lisant, l'apercu ne peut pas diverger.
"""
import io
import os
import re

from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADDON = os.path.join(RACINE, "data", "addon", "ForeverUI")
ART = os.path.join(RACINE, "data", "art")

_FEUILLE = re.compile(r'^\t\[(\d+)\] = "([^"]+)"')
_ENTREE = re.compile(r'^\t\["([^"]+)"\] = \{(\d+), ([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+), (\d+), (\d+)\}')


def charger():
    """nom d'atlas -> (chemin du png, u1, u2, v1, v2, largeur, hauteur)."""
    table = {}
    for nom in sorted(os.listdir(ADDON)):
        if not nom.startswith("UIAtlas"):
            continue
        feuilles = {}
        for ligne in io.open(os.path.join(ADDON, nom), encoding="utf-8"):
            m = _FEUILLE.match(ligne)
            if m:
                chemin = m.group(2).replace(chr(92) + chr(92), os.sep)
                feuilles[int(m.group(1))] = os.path.join(ART, chemin + ".png")
                continue
            m = _ENTREE.match(ligne)
            if m:
                table[m.group(1)] = (feuilles[int(m.group(2))],
                                     float(m.group(3)), float(m.group(4)),
                                     float(m.group(5)), float(m.group(6)),
                                     int(m.group(7)), int(m.group(8)))
    return table


class Atlas(object):
    """Les images de l'addon, decoupees comme le jeu les decoupe."""

    def __init__(self):
        self.table = charger()
        self._feuilles = {}

    def _feuille(self, chemin):
        if chemin not in self._feuilles:
            self._feuilles[chemin] = Image.open(chemin).convert("RGBA")
        return self._feuilles[chemin]

    def taille(self, nom):
        e = self.table[nom.lower()]
        return e[5], e[6]

    def image(self, nom, largeur=None, hauteur=None):
        """L'element, a sa taille d'affichage ou a la taille demandee."""
        e = self.table[nom.lower()]
        f = self._feuille(e[0])
        w, h = f.size
        coupe = f.crop((int(round(e[1] * w)), int(round(e[3] * h)),
                        int(round(e[2] * w)), int(round(e[4] * h))))
        cible = (int(round(largeur if largeur is not None else e[5])),
                 int(round(hauteur if hauteur is not None else e[6])))
        if coupe.size != cible:
            coupe = coupe.resize((max(1, cible[0]), max(1, cible[1])), Image.LANCZOS)
        return coupe

    def neuf(self, nom, largeur, hauteur, marge_image, taille_image, marge):
        """La decoupe en neuf de ForeverUI.SetAtlasNineSlice, a l'identique."""
        e = self.table[nom.lower()]
        f = self._feuille(e[0])
        w, h = f.size
        src = f.crop((int(round(e[1] * w)), int(round(e[3] * h)),
                      int(round(e[2] * w)), int(round(e[4] * h))))
        m = marge_image
        W, H = src.size
        largeur, hauteur = int(round(largeur)), int(round(hauteur))
        sortie = Image.new("RGBA", (largeur, hauteur), (0, 0, 0, 0))

        def bout(boite, taille, pos):
            morceau = src.crop(boite).resize((max(1, taille[0]), max(1, taille[1])), Image.LANCZOS)
            sortie.alpha_composite(morceau, pos)

        mi_w, mi_h = largeur - 2 * marge, hauteur - 2 * marge
        bout((0, 0, m, m), (marge, marge), (0, 0))
        bout((W - m, 0, W, m), (marge, marge), (largeur - marge, 0))
        bout((0, H - m, m, H), (marge, marge), (0, hauteur - marge))
        bout((W - m, H - m, W, H), (marge, marge), (largeur - marge, hauteur - marge))
        bout((m, 0, W - m, m), (mi_w, marge), (marge, 0))
        bout((m, H - m, W - m, H), (mi_w, marge), (marge, hauteur - marge))
        bout((0, m, m, H - m), (marge, mi_h), (0, marge))
        bout((W - m, m, W, H - m), (marge, mi_h), (largeur - marge, marge))
        bout((m, m, W - m, H - m), (mi_w, mi_h), (marge, marge))
        return sortie
