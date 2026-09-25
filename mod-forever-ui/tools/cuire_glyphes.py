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

"""Cuit les deux feuilles de la page des glyphes a partir de l'art refait.

SOURCE. Les PNG fournis par l'utilisateur le 2026-09-25, dans
C:/Users/Arthe/wow.export/_glyphes_wotlk/feuilles/Rework :
    UI-GlyphFrame2.png          le parchemin nu (1122 x 1402)
    UI-GlyphFrame-Drawings.png  le cercle trace (1173 x 1341)
    UI-GlyphFrame-corners.png   les quatre coins dores
    UI-GlyphFrame-Glow2.png     les lueurs : anneau runique, anneau d'epines,
                                double anneau, anneau orange, etoile, eclats
    UI-GlyphFrame-symbols.png   les symboles graves (PAS ENCORE EMPLOYES)

SORTIE. data/art/interface/ForeverUI/glyphes/ :
    glyphes-fond.blp    1024 x 1024 : parchemin, cercle, quatre coins
    glyphes-lueurs.blp  1024 x 1024 : anneaux, rayons, etoile
chacune avec son apercu .png, et la table des rectangles (en pixels) qu'il
faut recopier dans Talents.lua (GLYPHES_RECTS) -- l'outil l'imprime.

ECHELLE. Tout se regle sur les alveoles de WotLK, qui ne bougent pas : leurs
centres sont a 121 du centre de l'etoile (GlyphFrame, Blizzard_GlyphUI.xml).
Dans le vieux disque, ce rayon vaut 0,896 fois celui des sommets de
l'hexagone ; dans le nouveau dessin, les sommets sont a 439 px du centre
(584, 658), d'ou une echelle de 121 / (0,896 x 439). Les feuilles sont
cuites a 4/3 de la taille affichee (uiScale 0,64 sur 1600 lignes : un point
d'interface y vaut 1,33 pixel), et reduites en alpha premultiplie.
"""
import io
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

SOURCE = r"C:\Users\Arthe\wow.export\_glyphes_wotlk\feuilles\Rework"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(RACINE, "data", "art", "interface", "ForeverUI", "glyphes")

DENSITE = 4.0 / 3.0                     # pixels par point d'interface
RAYON_ALVEOLES = 121.0                  # Blizzard_GlyphUI.xml
RAYON_HEXAGONE = 439.0                  # dessin, centre (584, 658)
CENTRE_DESSIN = (584.0, 658.0)
ECHELLE_DESSIN = RAYON_ALVEOLES / (0.896 * RAYON_HEXAGONE)

# tailles affichees (points d'interface). Le parchemin couvre toute la
# fenetre reduite, sous le cadre interieur (demande du 2026-09-25) : le cadre
# de l'illustration de Talents.lua (page 404 de large ; pierre de 701 moins 70
# en haut et 36 en bas), etire a ces proportions
PARCHEMIN_L, PARCHEMIN_H = 404.0, 595.0
CARTE_ECHELLE_COIN = 0.125


def source(nom):
    return Image.open(os.path.join(SOURCE, nom)).convert("RGBA")


def reduire(im, largeur, hauteur):
    """Reduction en alpha premultiplie : pas de liseré sombre."""
    return im.convert("RGBa").resize((largeur, hauteur), Image.LANCZOS).convert("RGBA")


def adoucir_bords(im, marge):
    """Fond l'alpha vers zero sur les bords : un morceau de la feuille de
    lueurs emporte le halo de ses voisins, que le decoupage trancherait net."""
    w, h = im.size
    masque = Image.new("L", (w, h), 0)
    interieur = Image.new("L", (max(1, w - 2 * marge), max(1, h - 2 * marge)), 255)
    masque.paste(interieur, (marge, marge))
    masque = masque.filter(ImageFilter.GaussianBlur(marge / 2.0))
    r, v, b, a = im.split()
    a = Image.composite(a, Image.new("L", (w, h), 0), masque)
    return Image.merge("RGBA", (r, v, b, a))


def carre(im, cx, cy, demi):
    return im.crop((int(round(cx - demi)), int(round(cy - demi)),
                    int(round(cx + demi)), int(round(cy + demi))))


class Feuille:
    def __init__(self, nom, taille=1024):
        self.nom = nom
        self.image = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
        self.rects = {}

    def poser(self, cle, im, x, y, affiche):
        assert x + im.size[0] <= self.image.size[0] and y + im.size[1] <= self.image.size[1], cle
        self.image.alpha_composite(im, (x, y))
        self.rects[cle] = (x, y, im.size[0], im.size[1], affiche[0], affiche[1])

    def ecrire(self):
        os.makedirs(SORTIE, exist_ok=True)
        w, h = self.image.size
        chemin = os.path.join(SORTIE, self.nom + ".blp")
        io.open(chemin, "wb").write(blp.encoder(w, h, self.image.tobytes()))
        self.image.save(os.path.join(SORTIE, self.nom + ".png"))
        print("%-60s %8d o" % (os.path.relpath(chemin, RACINE), os.path.getsize(chemin)))


def px(points):
    return int(round(points * DENSITE))


def main():
    # ---------------------------------------------------------------- le fond
    fond = Feuille("glyphes-fond")

    # le parchemin : toute la fenetre
    p = source("UI-GlyphFrame2.png")
    pl, ph = PARCHEMIN_L, PARCHEMIN_H
    fond.poser("parchemin", reduire(p, px(pl), px(ph)), 0, 0, (pl, ph))
    x_cercle = px(pl) + 4

    # le cercle : a l'echelle des alveoles ; on retient aussi ou tombe son
    # centre dans le morceau affiche. Il prend la place qui reste a droite
    # du parchemin (un peu moins de 4/3 de densite)
    d = source("UI-GlyphFrame-Drawings.png")
    dl, dh = d.size[0] * ECHELLE_DESSIN, d.size[1] * ECHELLE_DESSIN
    lpx = min(px(dl), 1024 - x_cercle)
    fond.poser("cercle", reduire(d, lpx, int(round(lpx * dh / dl))), x_cercle, 0, (dl, dh))
    centre = (CENTRE_DESSIN[0] * ECHELLE_DESSIN, CENTRE_DESSIN[1] * ECHELLE_DESSIN)

    # les quatre coins (boites mesurees sur l'alpha de la feuille)
    c = source("UI-GlyphFrame-corners.png")
    boites = {"coin-hg": (34, 23, 566, 584), "coin-hd": (688, 23, 1220, 584),
              "coin-bg": (36, 666, 561, 1206), "coin-bd": (694, 666, 1217, 1206)}
    x = 0
    for cle, (x0, y0, x1, y1) in boites.items():
        m = c.crop((x0, y0, x1 + 1, y1 + 1))
        al, ah = m.size[0] * CARTE_ECHELLE_COIN, m.size[1] * CARTE_ECHELLE_COIN
        r = reduire(m, px(al), px(ah))
        fond.poser(cle, r, x, px(ph) + 8, (al, ah))
        x += r.size[0] + 4
    fond.ecrire()

    # ------------------------------------------------------------- les lueurs
    lueurs = Feuille("glyphes-lueurs")
    g = source("UI-GlyphFrame-Glow2.png")
    k = ECHELLE_DESSIN

    def anneau(cle, cx, cy, demi, rayon_source, rayon_dessin, x, y):
        """Un anneau de la feuille, mis a l'echelle d'un cercle du dessin.

        LES ANNEAUX TOURNENT (Talents.lua : cercles concentriques). 3.3.5 ne
        tourne une texture qu'en tournant ses coordonnees : les coins du carre
        lu s'en vont alors jusqu'a racine de 2 fois son demi-cote. Chaque
        anneau est donc pose au milieu d'une reserve vide de ce rayon ; le
        rectangle retenu reste celui de l'anneau. Rend le cote de la reserve."""
        m = adoucir_bords(carre(g, cx, cy, demi), 24)
        e = rayon_dessin * k / rayon_source          # points par pixel source
        cote = 2 * demi * e
        r = reduire(m, px(cote), px(cote))
        marge = int(math.ceil(r.size[0] * (math.sqrt(2) - 1) / 2)) + 2
        lueurs.poser(cle, r, x + marge, y + marge, (cote, cote))
        return r.size[0] + 2 * marge

    # anneau runique : bande de 289 a 335 px (milieu 312) -> bande du dessin,
    # 445 a 472 (milieu 458)
    w = anneau("anneau-runique", 369, 360, 368, 312.0, 458.5, 0, 0)
    # anneau d'epines (milieu 200 px) : autour des six runes du centre (207
    # px) ; place a 260 px, comme le fil d'ecriture de WotLK passait au-dela
    # des runes
    we = anneau("anneau-epines", 968.5, 379.5, 240, 200.0, 260.0, w + 4, 0)
    # double anneau : 100 et 136 px -> double cercle du centre, 126 et 150
    wd = anneau("anneau-double", 1363, 260.5, 160, 136.0, 150.0, w + 4, we + 4)

    # anneau orange : la surbrillance d'une alveole, a la taille de sa
    # monture (108 majeure) -- l'anneau (bord a 124 px) y occupe 45 points
    m = adoucir_bords(carre(g, 1364, 544, 150), 20)
    cote = 150 * 2 * 45.0 / 124.0
    r = reduire(m, px(cote), px(cote))
    xo = w + 4 + wd + 4
    lueurs.poser("anneau-orange", r, xo, we + 4, (cote, cote))

    # l'etoile des etincelles. Le morceau brut portait un disque plein de
    # 40 px de rayon (la "grosse boule") et un bout du halo de l'anneau
    # runique : on garde ses couleurs, et l'on ne garde de son alpha que le
    # coeur, les quatre rais et un halo doux
    m = np.array(g.crop((50, 695, 350, 995))).astype(float)
    yy, xx = np.mgrid[0:300, 0:300]
    dx, dy = xx - 150.0, yy - 150.0
    r2 = np.hypot(dx, dy)
    f = (np.exp(-(r2 / 9.0) ** 2)
         + np.exp(-(np.minimum(abs(dx), abs(dy)) / 4.0) ** 2) * np.exp(-(r2 / 100.0) ** 2)
         + 0.35 * np.exp(-(r2 / 28.0) ** 2))
    m[:, :, 3] = m[:, :, 3] * np.clip(f, 0, 1)
    etoile = Image.fromarray(m.astype(np.uint8), "RGBA")
    lueurs.poser("etoile", reduire(etoile, 64, 64), xo, we + 4 + r.size[1] + 4, (48.0, 48.0))

    # les rayons : l'eclat vertical (x 440, y 720..970) tire le long des trois
    # diametres de l'etoile (vertical, puis a 60 et 120 degres), de part et
    # d'autre du centre jusqu'aux alveoles
    m = adoucir_bords(g.crop((405, 700, 476, 991)), 12)
    long_pts = 2 * RAYON_ALVEOLES + 40
    larg_pts = long_pts * m.size[0] / m.size[1]
    rayon = reduire(m, px(larg_pts), px(long_pts))
    y_rayons = w + 4
    lueurs.poser("rayon-0", rayon, 0, y_rayons, (larg_pts, long_pts))
    x = rayon.size[0] + 8
    for i, angle in ((1, -60), (2, 60)):
        t = rayon.rotate(angle, resample=Image.BICUBIC, expand=True)
        lw = t.size[0] / DENSITE
        lh = t.size[1] / DENSITE
        lueurs.poser("rayon-%d" % i, t, x, y_rayons, (lw, lh))
        x += t.size[0] + 8
    lueurs.ecrire()

    # ------------------------------------------------------------ la table
    print()
    print("-- GLYPHES_RECTS (Talents.lua) : feuille, x, y, l, h en pixels ; taille affichee")
    for f in (fond, lueurs):
        for cle, (x, y, l, h, al, ah) in f.rects.items():
            print('\t["%s"] = { "%s", %d, %d, %d, %d, %.2f, %.2f },' % (cle, f.nom, x, y, l, h, al, ah))
    print("-- centre du cercle dans son morceau affiche : (%.2f, %.2f)" % centre)


if __name__ == "__main__":
    main()
