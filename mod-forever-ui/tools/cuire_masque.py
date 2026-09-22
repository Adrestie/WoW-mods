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

"""Cuire le masque des onglets lateraux dans l'alpha de leurs icones.

POURQUOI. camelot decoupe l'icone d'un onglet par une MaskTexture --
LargeSideTabButtonTemplate la declare sur common-sidetab-mask -- et 3.3.5
n'en a pas. Ses angles restaient donc carres la ou la source les arrondit.
Ce que le client ne sait pas faire a l'ecran, on le fait AVANT : l'alpha du
masque est multiplie dans celui de l'icone, une fois pour toutes.

LA GEOMETRIE, prise sur la source et non estimee. En repere de l'onglet --
origine au centre, x vers la droite, y vers le haut :

  onglet   55 x 55       CalculateTabSizeBasedOnTabArt : la largeur de l'art,
                         et sa hauteur sans la bande transparente du bas
  masque   55 x 60       common-sidetab-mask-c60, useAtlasSize, ancre CENTER
                         -- il deborde donc de 2,5 px en haut et en bas
  icone    50 x 50       UpdateIconInterior : SetSize(interiorExtent, ...)
           en (-3, 0)    GetIconAnchorOffsetsForTabArt
           rognee a      SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
           0,03125

Un texel de l'icone se place donc ainsi :

  u, v -> visible seulement dans [0,03125 ; 0,96875]
  x = -28 + (u - 0,03125) / 0,9375 * 50
  y =  25 - (v - 0,03125) / 0,9375 * 50

puis on lit le masque en (x + 27,5) / 55 et (30 - y) / 60. Hors du masque,
son wrap est CLAMPTOBLACKADDITIVE : noir, donc rien.

CE QUI RESTE CARRE. L'onglet du personnage porte le PORTRAIT du joueur, pose
par SetPortraitTexture a chaque changement d'apparence : il n'y a pas de
fichier a cuire. Ses angles restent donc vifs.

OU VONT LES FICHIERS. L'icone brute reste dans icons/ -- c'est la provenance,
et l'entree de cette cuisson. La version cuite va dans tabicons/, et c'est
elle que l'addon affiche. Relancer cet outil refait la seconde a partir de
la premiere, sans wow.export.
"""
import io
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(RACINE, "data", "art", "interface", "ForeverUI")
MASQUE = os.path.join(ART, "common", "commonsidetabmaskc60.blp")
ENTREE = os.path.join(ART, "icons")
SORTIE = os.path.join(ART, "tabicons")

# Les icones que camelot pose sur un onglet lateral, telles que
# CHARACTER_MODE_TAB_ICONS les nomme. Le portrait du personnage n'y est pas :
# il n'a pas de fichier.
ICONES = [
    "inv_sidetab_reputation2_c60.blp",
    "ability_racial_jackofalltrades.blp",
    "inv_sidetab_currency_c60.blp",
    "inv_sidetab_honor_alliance_c60.blp",
    "inv_sidetab_honor_horde_c60.blp",
    "inv_sidetab_stats_c60.blp",
]

ONGLET_L, ONGLET_H = 55.0, 55.0
MASQUE_L, MASQUE_H = 55.0, 60.0
ICONE = 50.0
ICONE_X, ICONE_Y = -3.0, 0.0
ROGNAGE = 0.03125


# L'APERCU. L'atelier veut un .png a cote de chaque .blp, pour qu'on voie ce
# qu'il contient sans ouvrir le jeu. Les autres viennent de wow.export ; ceux
# d'une image que NOUS fabriquons n'ont personne pour les produire, d'ou ce
# petit ecrivain PNG -- sans dependance, zlib suffit.
def _png(chemin, largeur, hauteur, rgba):
    lignes = bytearray()
    for j in range(hauteur):
        lignes.append(0)                        # filtre : aucun
        debut = j * largeur * 4
        lignes += rgba[debut:debut + largeur * 4]

    def bloc(nom, donnees):
        corps = nom + donnees
        return (struct.pack(">I", len(donnees)) + corps
                + struct.pack(">I", zlib.crc32(corps) & 0xFFFFFFFF))

    entete = struct.pack(">IIBBBBB", largeur, hauteur, 8, 6, 0, 0, 0)
    io.open(chemin, "wb").write(
        # La signature PNG, octet par octet : l'ecrire en echappements
        # dans une chaine se prete trop aux accidents de transport.
        bytes((137, 80, 78, 71, 13, 10, 26, 10))
        + bloc(b"IHDR", entete)
        + bloc(b"IDAT", zlib.compress(bytes(lignes), 9))
        + bloc(b"IEND", b""))


def _lire(chemin):
    largeur, hauteur, rgba, _ = blp.decoder(io.open(chemin, "rb").read())
    return largeur, hauteur, bytearray(rgba)


def _alpha_du_masque(mx, my, largeur, hauteur, pixels):
    """L'alpha du masque a une position donnee, en fraction de sa surface."""
    if mx < 0.0 or mx >= 1.0 or my < 0.0 or my >= 1.0:
        return 0                       # CLAMPTOBLACKADDITIVE : dehors, rien
    i = int(mx * largeur)
    j = int(my * hauteur)
    if i >= largeur:
        i = largeur - 1
    if j >= hauteur:
        j = hauteur - 1
    # Le masque est en niveaux de gris : sa couleur porte l'information
    # autant que son alpha. On prend le plus petit des deux, pour qu'un
    # masque ecrit d'une facon ou de l'autre donne le meme resultat.
    base = (j * largeur + i) * 4
    return min(pixels[base], pixels[base + 3])


def cuire(nom, masque):
    source = os.path.join(ENTREE, nom)
    if not os.path.exists(source):
        return None

    largeur, hauteur, pixels = _lire(source)
    ml, mh, mpix = masque

    demi_l, demi_h = ONGLET_L / 2.0, ONGLET_H / 2.0
    gauche = ICONE_X - ICONE / 2.0
    haut = ICONE_Y + ICONE / 2.0
    etendue = 1.0 - 2.0 * ROGNAGE

    for j in range(hauteur):
        v = (j + 0.5) / hauteur
        for i in range(largeur):
            u = (i + 0.5) / largeur
            base = (j * largeur + i) * 4

            if u < ROGNAGE or u > 1.0 - ROGNAGE or v < ROGNAGE or v > 1.0 - ROGNAGE:
                pixels[base + 3] = 0    # jamais affiche : autant l'effacer
                continue

            x = gauche + (u - ROGNAGE) / etendue * ICONE
            y = haut - (v - ROGNAGE) / etendue * ICONE

            mx = (x + demi_l) / MASQUE_L
            my = (MASQUE_H / 2.0 - y) / MASQUE_H

            a = _alpha_du_masque(mx, my, ml, mh, mpix)
            pixels[base + 3] = (pixels[base + 3] * a) // 255

    cible = os.path.join(SORTIE, nom)
    os.makedirs(SORTIE, exist_ok=True)
    io.open(cible, "wb").write(blp.encoder(largeur, hauteur, bytes(pixels)))
    _png(cible[:-4] + ".png", largeur, hauteur, pixels)
    return cible


def main():
    if not os.path.exists(MASQUE):
        raise SystemExit("le masque manque : %s -- le faire entrer avec "
                         "tools/ajouter_feuilles.py" % MASQUE)

    masque = _lire(MASQUE)
    print("masque : %d x %d" % (masque[0], masque[1]))

    faits = 0
    for nom in ICONES:
        cible = cuire(nom, masque)
        if cible is None:
            print("   ABSENTE %s" % nom)
            continue
        print("   %-60s %8d o" % (os.path.relpath(cible, RACINE),
                                  os.path.getsize(cible)))
        faits += 1

    print("%d icone(s) cuite(s) ; poser dans le client avec tools/deployer.py" % faits)


if __name__ == "__main__":
    main()
