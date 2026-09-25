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
LargeSideTabButtonTemplate la declare sur common-sidetab-mask   # et 3.3.5
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

OU VONT LES FICHIERS. L'icone brute reste dans icons/   # c'est la provenance,
et l'entree de cette cuisson. La version cuite va dans tabicons/, et c'est
elle que l'addon affiche. Relancer cet outil refait la seconde a partir de
la premiere, sans wow.export.
"""
import io
import math
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(RACINE, "data", "art", "interface", "ForeverUI")
MASQUE = os.path.join(ART, "common", "commonsidetabmask2xc60.blp")
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

# Les onglets des specialisations (ecran des talents) : l'icone de l'arbre
# principal de chaque classe, et l'icone hybride de WotLK.
ICONES += ["%s.blp" % n for n in (
    "ability_backstab",
    "ability_hunter_beasttaming",
    "ability_hunter_swiftstrike",
    "ability_marksmanship",
    "ability_racial_bearform",
    "ability_rogue_eviscerate",
    "ability_stealth",
    "ability_warrior_innerrage",
    "inv_shield_06",
    "spell_deathknight_bloodpresence",
    "spell_deathknight_frostpresence",
    "spell_deathknight_unholypresence",
    "spell_fire_firebolt02",
    "spell_frost_frostbolt02",
    "spell_holy_auraoflight",
    "spell_holy_devotionaura",
    "spell_holy_guardianspirit",
    "spell_holy_holybolt",
    "spell_holy_magicalsentry",
    "spell_holy_wordfortitude",
    "spell_nature_healingtouch",
    "spell_nature_lightning",
    "spell_nature_lightningshield",
    "spell_nature_magicimmunity",
    "spell_nature_starfall",
    "spell_shadow_deathcoil",
    "spell_shadow_metamorphosis",
    "spell_shadow_rainoffire",
    "spell_shadow_shadowwordpain",
    "ability_dualwieldspecialization")]

# L'onglet des glyphes (ecran des talents) : l'icone de la calligraphie,
# WotLK n'en donnant aucune a son onglet du bas.
ICONES += ["inv_inscription_tradeskill01.blp"]

# L'onglet du familier de la feuille de personnage (camelot n'en a pas) : une
# icone par classe, a la demande (le chasseur reprend ability_hunter_beasttaming,
# deja cuite plus haut).
ICONES += ["spell_shadow_summonimp.blp", "spell_shadow_animatedead.blp"]

# L'onglet du personnage porte l'icone de SA classe : un fichier par
# classe, cuit comme les autres.
ICONES += ["classicon_%s.blp" % c for c in (
    "deathknight", "druid", "hunter", "mage", "paladin",
    "priest", "rogue", "shaman", "warlock", "warrior")]

ONGLET_L, ONGLET_H = 55.0, 55.0
MASQUE_L, MASQUE_H = 55.0, 60.0
ICONE = 50.0
ICONE_X, ICONE_Y = -3.0, 0.0
ROGNAGE = 0.03125

# LE MASQUE EST BINAIRE, ET C'EST LE PROBLEME.
#
# Releve sur l'art : sa ligne du milieu passe de 0 a 255 d'un texel a
# l'autre, sans le moindre degrade. Le client, lui, l'applique a la
# RESOLUTION DE L'ECRAN, ou cette marche est fine ; cuite a 64 px elle
# devient un escalier, que l'agrandissement de l'interface etale ensuite sur
# deux ou trois pixels reels. D'ou des icones "tres pixelisees" alors que
# leur contenu n'avait pas bouge.
#
# Deux remedes, et un constat.
#   * On cuit a ECHELLE fois la taille de la source : le contour a de quoi
#     s'adoucir.
#   * On INTERPOLE le masque au lieu de le lire au texel le plus proche.
#     C'est lui, et lui seul, qui porte la marche : sur-echantillonner sans
#     interpoler ne servait a rien -- a l'echelle ou l'on cuit, seize
#     echantillons tombaient tous dans le meme texel du masque. On prend au
#     passage sa version 2x, deux fois plus fine.
#   * Le CONTENU de l'icone, lui, ne gagne rien : 64 x 64 est tout ce que le
#     client possede -- verifie sur les 14 fichiers voisins, tous de cette
#     taille -- et camelot affiche exactement les memes.
ECHELLE = 2
SUPER = 4


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


def _ecrire(chemin, largeur, hauteur, pixels):
    """Ecrire un BLP et son apercu, apres verification de la taille.

    LE CLIENT VEUT DES PUISSANCES DE DEUX. Tout son art d'interface en est --
    256 x 256, 256 x 64, 16 x 16 -- et une cuisson en 320 x 30 ne s'affichait
    pas correctement : il ne sait visiblement pas echantillonner autre chose,
    et rendait la texture d'un bloc. Le defaut est silencieux a l'ecriture et
    ne se voit qu'en jeu ; on le refuse donc ici.
    """
    for nom, taille in (("largeur", largeur), ("hauteur", hauteur)):
        if taille <= 0 or (taille & (taille - 1)) != 0:
            raise SystemExit("%s : %s de %d n'est pas une puissance de deux"
                             % (os.path.basename(chemin), nom, taille))

    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    io.open(chemin, "wb").write(blp.encoder(largeur, hauteur, bytes(pixels)))
    _png(chemin[:-4] + ".png", largeur, hauteur, pixels)


def _lire(chemin):
    largeur, hauteur, rgba, _ = blp.decoder(io.open(chemin, "rb").read())
    return largeur, hauteur, bytearray(rgba)


def _alpha_du_masque(mx, my, largeur, hauteur, pixels):
    """L'alpha du masque a une position donnee, interpole.

    Le masque est en niveaux de gris : sa couleur porte l'information autant
    que son alpha, on prend le plus petit des deux. Et il est BINAIRE --
    releve sur l'art, sa ligne du milieu passe de 0 a 255 d'un texel a
    l'autre. Lu au texel le plus proche, son contour serait un escalier ;
    interpole, il devient le degrade que le client obtient en l'appliquant a
    la resolution de l'ecran.
    """
    x = mx * largeur - 0.5
    y = my * hauteur - 0.5
    i0 = int(x) if x >= 0 else -1
    j0 = int(y) if y >= 0 else -1
    fx, fy = x - i0, y - j0

    def texel(i, j):
        if i < 0 or i >= largeur or j < 0 or j >= hauteur:
            return 0                   # CLAMPTOBLACKADDITIVE : dehors, rien
        base = (j * largeur + i) * 4
        return min(pixels[base], pixels[base + 3])

    a, b = texel(i0, j0), texel(i0 + 1, j0)
    c, d = texel(i0, j0 + 1), texel(i0 + 1, j0 + 1)
    haut = a + (b - a) * fx
    bas = c + (d - c) * fx
    return haut + (bas - haut) * fy


def _lire_bilineaire(u, v, largeur, hauteur, pixels):
    """Les quatre composantes de la source, interpolees."""
    x = u * largeur - 0.5
    y = v * hauteur - 0.5
    i0 = int(x) if x >= 0 else -1
    j0 = int(y) if y >= 0 else -1
    fx, fy = x - i0, y - j0

    def texel(i, j):
        i = 0 if i < 0 else (largeur - 1 if i >= largeur else i)
        j = 0 if j < 0 else (hauteur - 1 if j >= hauteur else j)
        b = (j * largeur + i) * 4
        return pixels[b], pixels[b + 1], pixels[b + 2], pixels[b + 3]

    a, b, c, d = (texel(i0, j0), texel(i0 + 1, j0),
                  texel(i0, j0 + 1), texel(i0 + 1, j0 + 1))
    sortie = []
    for k in range(4):
        haut = a[k] + (b[k] - a[k]) * fx
        bas = c[k] + (d[k] - c[k]) * fx
        sortie.append(int(haut + (bas - haut) * fy + 0.5))
    return sortie


def cuire(nom, masque):
    source = os.path.join(ENTREE, nom)
    if not os.path.exists(source):
        return None

    src_l, src_h, source_px = _lire(source)
    ml, mh, mpix = masque

    largeur, hauteur = src_l * ECHELLE, src_h * ECHELLE
    pixels = bytearray(largeur * hauteur * 4)

    demi_l = ONGLET_L / 2.0
    gauche = ICONE_X - ICONE / 2.0
    haut = ICONE_Y + ICONE / 2.0
    etendue = 1.0 - 2.0 * ROGNAGE
    pas = 1.0 / (largeur * SUPER)       # un pas de sur-echantillon, en u

    for j in range(hauteur):
        v = (j + 0.5) / hauteur
        for i in range(largeur):
            u = (i + 0.5) / largeur
            base = (j * largeur + i) * 4

            if u < ROGNAGE or u > 1.0 - ROGNAGE or v < ROGNAGE or v > 1.0 - ROGNAGE:
                continue                # jamais affiche : laisse a zero

            r, vert, b, a = _lire_bilineaire(u, v, src_l, src_h, source_px)
            pixels[base:base + 3] = bytes((r, vert, b))
            if a == 0:
                continue

            # LE CONTOUR SE MOYENNE. Un seul echantillon rendrait la marche
            # du masque telle quelle ; SUPER x SUPER en font un degrade.
            somme = 0
            for sj in range(SUPER):
                vv = v + (sj - (SUPER - 1) / 2.0) * pas
                y = haut - (vv - ROGNAGE) / etendue * ICONE
                my = (MASQUE_H / 2.0 - y) / MASQUE_H
                for si in range(SUPER):
                    uu = u + (si - (SUPER - 1) / 2.0) * pas
                    x = gauche + (uu - ROGNAGE) / etendue * ICONE
                    mx = (x + demi_l) / MASQUE_L
                    somme += _alpha_du_masque(mx, my, ml, mh, mpix)

            pixels[base + 3] = int(a * somme / (255.0 * SUPER * SUPER) + 0.5)

    cible = os.path.join(SORTIE, nom)
    _ecrire(cible, largeur, hauteur, pixels)
    return cible


# ---------------------------------------------------------------------------
# LE REMPLISSAGE DES JAUGES
#
# camelot le decoupe par common-stat-bar-Mask, une MaskTexture ancree LEFT et
# RIGHT sur la barre -- donc tendue sur toute sa largeur -- a sa hauteur
# d'atlas, 29, celle de la barre. Le remplissage, lui, fait 15 de haut et
# s'ancre a LEFT : il occupe donc la bande centrale, de 7 a 22.
#
# MAIS NOTRE FOND EST DECOUPE, PAS TENDU. Le sien s'etire avec la barre, le
# notre garde ses bouts a 10 px et n'etire que le milieu. Un masque tendu ne
# coinciderait donc plus avec lui : il est decoupe de la meme facon, et les
# deux contours se superposent exactement.
JAUGE_L, JAUGE_H = 160.0, 29.0   # largeur et hauteur de la barre
JAUGE_COIN = 10.0   # le meme que le fond
JAUGE_REMPLISSAGE_H = 15.0
# LA TAILLE SE PREND EN PUISSANCE DE DEUX.
#
# Tout l'art d'interface du client d'origine l'est -- verifie sur un
# echantillon : 256 x 256, 256 x 64, 16 x 16. Une premiere cuisson en
# 320 x 30 ne s'affichait pas correctement ; le client ne sait visiblement
# pas echantillonner une texture qui ne l'est pas, et la rendait d'un bloc
# que la teinte de la faction coloriait ensuite. 512 x 32 tient largement le
# double de la taille affichee, 160 x 15, et garde la lecture en 0..1.
JAUGE_SORTIE_L, JAUGE_SORTIE_H = 512, 32

MASQUE_JAUGE = os.path.join(ART, "common", "commonstatbarmaskc60.blp")
REMPLISSAGE = os.path.join(ART, "common", "commonstatbarc60.blp")
# LES REMPLISSAGES, dans leur feuille. camelot en a quatre --
# SetFillTextureByColorType : rouge, vert, bleu, blanc. La reputation teinte
# le blanc par FACTION_BAR_COLORS ; les competences prennent le BLEU tel
# quel, UpdateBarColor n'y posant que du blanc.
REMPLISSAGES = {
    "statbarfill": (0.003906, 0.941406, 0.406250, 0.523438),      # white
    "statbarfillblue": (0.003906, 0.941406, 0.007812, 0.125000),  # blue
}
SORTIE_JAUGE = os.path.join(ART, "bars")


def _decoupe(x, longueur, coin, source):
    """Ou lire, dans une image de `source` de large, un point pose a `x` sur
    une bande de `longueur`, quand l'image est DECOUPEE : ses deux bouts de
    `coin` restent a l'echelle, seul le milieu s'etire."""
    if x < coin:
        return x / source
    if x > longueur - coin:
        return (source - (longueur - x)) / source
    milieu = (x - coin) / (longueur - 2.0 * coin)
    return (coin + milieu * (source - 2.0 * coin)) / source


def cuire_jauge(nom, rect):
    if not os.path.exists(MASQUE_JAUGE) or not os.path.exists(REMPLISSAGE):
        print("   le masque ou la feuille de jauge manque")
        return None

    ml, mh, mpix = _lire(MASQUE_JAUGE)
    fl, fh, fpix = _lire(REMPLISSAGE)

    u1, u2, v1, v2 = rect
    largeur, hauteur = JAUGE_SORTIE_L, JAUGE_SORTIE_H
    pixels = bytearray(largeur * hauteur * 4)

    haut = (JAUGE_H - JAUGE_REMPLISSAGE_H) / 2.0

    for j in range(hauteur):
        v = (j + 0.5) / hauteur
        y = haut + v * JAUGE_REMPLISSAGE_H          # en repere de la barre
        my = y / JAUGE_H
        for i in range(largeur):
            u = (i + 0.5) / largeur
            base = (i + j * largeur) * 4

            # La couleur vient du remplissage, lu dans sa feuille.
            r, vert, b, a = _lire_bilineaire(u1 + (u2 - u1) * u,
                                             v1 + (v2 - v1) * v, fl, fh, fpix)
            pixels[base:base + 3] = bytes((r, vert, b))
            if a == 0:
                continue

            mx = _decoupe(u * JAUGE_L, JAUGE_L, JAUGE_COIN, ml)
            m = _alpha_du_masque(mx, my, ml, mh, mpix)
            pixels[base + 3] = int(a * m / 255.0 + 0.5)

    cible = os.path.join(SORTIE_JAUGE, nom + ".blp")
    _ecrire(cible, largeur, hauteur, pixels)
    return cible


# --------------------------------------------------------------------------
# LA JAUGE CIRCULAIRE DU PVP.
#
# camelot la fait avec un Cooldown dont il remplace la texture de balayage :
#   <Cooldown parentKey="RankProgressBarDisplay" reverse="true"
#             rotation="180">
#     <SwipeTexture file="Interface/PVPFrame/pvpqueue-sidebar-honorbar-fill"/>
# 3.3.5 n'a pas SetSwipeTexture -- verifie dans le binaire -- et la texture de
# balayage de son Cooldown est cablee dans le moteur.
#
# ON REFAIT DONC LE BALAYAGE A LA MAIN, par quadrants. L'addon pose quatre
# textures, une par quart de cercle ; un quart entierement rempli montre le
# quart de l'anneau tel quel, et le quart ou s'arrete la jauge montre un DEMI
# anneau qu'on fait TOURNER par SetTexCoord a huit arguments. Un demi anneau
# tourne de phi couvre les 180 degres qui finissent a phi : coupe par le
# rectangle du quadrant, il donne exactement l'arc voulu.
#
# CE QUE LA CUISSON DOIT GARANTIR, et que la source ne garantit pas :
#   * LE CENTRE DU CERCLE EST LE CENTRE DE L'IMAGE. La rotation se fait
#     autour du centre du quadrilatere ; un cercle decentre tournerait en
#     decrivant une boucle. Releve sur la source : son centre de gravite est
#     a (64.0, 63.5) pour un canevas de 128, soit un demi texel trop haut.
#     On le recale.
#   * LES BORDS RESTENT TRANSPARENTS. Une fois tournee, la texture est lue
#     hors de [0,1] dans les coins du quadrilatere ; le client y recopie le
#     texel du bord. Il doit donc etre vide. Rayon exterieur 51 sur 64 de
#     demi-canevas : la marge existe, on la garde.
#   * LA COUPE PASSE PAR LE CENTRE. Le demi anneau garde la moitie GAUCHE --
#     les angles de 180 a 360 en comptant depuis le haut dans le sens des
#     aiguilles -- et sa coupe tombe exactement sur l'axe.
JAUGE_PVP_SOURCE = os.path.join(ART, "pvpframe",
                                "pvpqueue-sidebar-honorbar-fill.blp")
SORTIE_PVP = os.path.join(ART, "pvp")
JAUGE_PVP_SORTIE = 256      # puissance de deux, deux fois la source


def _centre_de_gravite(largeur, hauteur, pixels):
    """Le centre de l'anneau, pondere par l'alpha."""
    sx = sy = sa = 0.0
    for j in range(hauteur):
        for i in range(largeur):
            a = pixels[(i + j * largeur) * 4 + 3]
            if a:
                sx += a * (i + 0.5)
                sy += a * (j + 0.5)
                sa += a
    if sa == 0.0:
        return largeur / 2.0, hauteur / 2.0
    return sx / sa, sy / sa


def _lire_premultiplie(x, y, largeur, hauteur, pixels):
    """Un texel interpole, la couleur PONDEREE PAR L'ALPHA.

    x et y sont en texels de la source, centres sur (i + 0.5, j + 0.5).

    POURQUOI PONDERER. Les texels vides de cette image sont blancs -- releve :
    (255, 255, 255, 0). Interpoler la couleur sans tenir compte de l'alpha
    ferait remonter ce blanc au contour de l'anneau, qui s'y borderait d'un
    liseré clair. On interpole donc la couleur multipliee par l'alpha, puis on
    la redivise.
    """
    i0 = int(math.floor(x - 0.5))
    j0 = int(math.floor(y - 0.5))
    fx = x - 0.5 - i0
    fy = y - 0.5 - j0

    def texel(i, j):
        i = 0 if i < 0 else (largeur - 1 if i >= largeur else i)
        j = 0 if j < 0 else (hauteur - 1 if j >= hauteur else j)
        b = (j * largeur + i) * 4
        return pixels[b], pixels[b + 1], pixels[b + 2], pixels[b + 3]

    coins = (texel(i0, j0), texel(i0 + 1, j0),
             texel(i0, j0 + 1), texel(i0 + 1, j0 + 1))
    poids = ((1.0 - fx) * (1.0 - fy), fx * (1.0 - fy),
             (1.0 - fx) * fy, fx * fy)

    r = v = b = a = 0.0
    for coin, p in zip(coins, poids):
        a += p * coin[3]
        r += p * coin[0] * coin[3]
        v += p * coin[1] * coin[3]
        b += p * coin[2] * coin[3]
    if a <= 0.0:
        return 0, 0, 0, 0
    return (int(r / a + 0.5), int(v / a + 0.5), int(b / a + 0.5),
            int(a + 0.5))


def cuire_jauge_pvp():
    """Les deux morceaux de la jauge : l'anneau entier, et sa moitie gauche."""
    if not os.path.exists(JAUGE_PVP_SOURCE):
        print("   le remplissage de la jauge pvp manque")
        return []

    sl, sh, spix = _lire(JAUGE_PVP_SOURCE)
    cx, cy = _centre_de_gravite(sl, sh, spix)
    print("   anneau pvp : %d x %d, centre (%.2f, %.2f)" % (sl, sh, cx, cy))

    taille = JAUGE_PVP_SORTIE
    echelle = float(sl) / taille          # texels de source par texel de sortie
    entier = bytearray(taille * taille * 4)
    moitie = bytearray(taille * taille * 4)

    for j in range(taille):
        y = (j + 0.5 - taille / 2.0) * echelle + cy
        for i in range(taille):
            x = (i + 0.5 - taille / 2.0) * echelle + cx
            r, v, b, a = _lire_premultiplie(x, y, sl, sh, spix)
            base = (i + j * taille) * 4
            entier[base:base + 4] = bytes((r, v, b, a))
            # LA MOITIE GAUCHE, coupee sur l'axe : les colonnes dont le
            # centre tombe avant le milieu du canevas.
            if i + 0.5 < taille / 2.0:
                moitie[base:base + 4] = bytes((r, v, b, a))

    faits = []
    for nom, pixels in (("honorfill", entier), ("honorfillhalf", moitie)):
        cible = os.path.join(SORTIE_PVP, nom + ".blp")
        _ecrire(cible, taille, taille, pixels)
        faits.append(cible)
    return faits


# --------------------------------------------------------------------------
# LE PORTRAIT DU GRIMOIRE.
#
# camelot (PortraitFrameTemplate) : le portrait fait 62 x 62 et prend l'icone
# entiere -- SetSpellBookPortrait pose SetPortraitTexCoord(0, 1, 0, 1). Son
# CircleMask, TempPortraitAlphaMask, s'ancre TOPLEFT (2, 0) et BOTTOMRIGHT
# (-2, 4) : un disque de 58 x 58, decale de 2 a droite, colle en haut. Hors du
# masque, CLAMPTOBLACKADDITIVE : rien.
#
# L'image cuite couvre le carre de 62 x 62 tout entier : l'addon la pose a la
# place du portrait, en coordonnees 0..1, et le disque tombe ou camelot le met.
PORTRAIT = 62.0
PORTRAIT_MASQUE = (2.0, 0.0, 60.0, 58.0)    # gauche, haut, droite, bas
PORTRAIT_SORTIE = 128
PORTRAIT_MASQUE_FICHIER = os.path.join(ART, "characterframe",
                                       "tempportraitalphamask.blp")
PORTRAITS = {"inv_misc_book_09.blp": os.path.join(ART, "spellbook",
                                                  "portrait.blp")}
# LE PORTRAIT DES TALENTS : l'icone de la classe (SetTalentPortrait,
# SetPortraitToClassIcon), dans le meme masque
for _classe in ("deathknight", "druid", "hunter", "mage", "paladin",
                "priest", "rogue", "shaman", "warlock", "warrior"):
    PORTRAITS["classicon_%s.blp" % _classe] = os.path.join(
        ART, "talents", "portrait_%s.blp" % _classe)


def cuire_portrait(nom, cible):
    source = os.path.join(ENTREE, nom)
    if not os.path.exists(source) or not os.path.exists(PORTRAIT_MASQUE_FICHIER):
        print("   l'icone ou le masque du portrait manque")
        return None

    sl, sh, spix = _lire(source)
    ml, mh, mpix = _lire(PORTRAIT_MASQUE_FICHIER)
    g, h, d, b = PORTRAIT_MASQUE
    taille = PORTRAIT_SORTIE
    pixels = bytearray(taille * taille * 4)
    pas = 1.0 / (taille * SUPER)

    for j in range(taille):
        v = (j + 0.5) / taille
        for i in range(taille):
            u = (i + 0.5) / taille
            base = (j * taille + i) * 4
            r, vert, bl, a = _lire_bilineaire(u, v, sl, sh, spix)
            pixels[base:base + 3] = bytes((r, vert, bl))
            if a == 0:
                continue
            somme = 0
            for sj in range(SUPER):
                y = (v + (sj - (SUPER - 1) / 2.0) * pas) * PORTRAIT
                for si in range(SUPER):
                    x = (u + (si - (SUPER - 1) / 2.0) * pas) * PORTRAIT
                    mx, my = (x - g) / (d - g), (y - h) / (b - h)
                    # hors du masque : rien (et pas d'extrapolation)
                    if 0.0 <= mx <= 1.0 and 0.0 <= my <= 1.0:
                        somme += _alpha_du_masque(mx, my, ml, mh, mpix)
            pixels[base + 3] = int(a * somme / (255.0 * SUPER * SUPER) + 0.5)

    _ecrire(cible, taille, taille, pixels)
    return cible


def main():
    if not os.path.exists(MASQUE):
        raise SystemExit("le masque manque : %s   # le faire entrer avec "
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

    for nom in sorted(REMPLISSAGES):
        jauge = cuire_jauge(nom, REMPLISSAGES[nom])
        if jauge:
            print("   %-60s %8d o" % (os.path.relpath(jauge, RACINE),
                                      os.path.getsize(jauge)))

    for jauge in cuire_jauge_pvp():
        print("   %-60s %8d o" % (os.path.relpath(jauge, RACINE),
                                  os.path.getsize(jauge)))

    for nom in sorted(PORTRAITS):
        cible = cuire_portrait(nom, PORTRAITS[nom])
        if cible:
            print("   %-60s %8d o" % (os.path.relpath(cible, RACINE),
                                      os.path.getsize(cible)))

    print("%d icone(s) cuite(s) ; poser dans le client avec tools/deployer.py" % faits)


if __name__ == "__main__":
    main()
