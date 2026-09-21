# -*- coding: utf-8 -*-
"""Composer la rangee du bas telle que l'addon la pose, et la regarder.

Les coordonnees sont celles du code : positions de camelot, tailles de camelot.
Si l'image ne ressemble pas a la capture du jeu, c'est le code qui est faux.
"""
import io
import json
import os

from PIL import Image

# Tout vient du depot : l'index des atlas a cote de ce script, les apercus PNG
# a cote des .blp qu'ils montrent, et l'image composee dans docs/apercu.
OUTILS = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(OUTILS)
PNG = os.path.join(RACINE, "data", "art", "interface", "ForeverUI")
BASE = os.path.join(RACINE, "docs", "apercu")
os.makedirs(BASE, exist_ok=True)

index = json.load(io.open(os.path.join(OUTILS, "atlas_dump.json"), encoding="utf-8"))["results"]
par_nom = {}
for e in index:
    if e.get("file"):
        par_nom[e["atlas"].lower()] = e

_feuilles = {}


def _apercu(fichier):
    """interface/hud/x.blp -> l'apercu PNG verse a cote du .blp dans le depot."""
    return os.path.join(PNG, os.path.relpath(fichier, "interface").replace(".blp", ".png"))


def image(nom):
    """L'element, a sa taille d'affichage (les feuilles 2x comptent double)."""
    e = par_nom[nom.lower()]
    chemin = _apercu(e["file"])
    if chemin not in _feuilles:
        _feuilles[chemin] = Image.open(chemin).convert("RGBA")
    f = _feuilles[chemin]
    r = e["region"]
    coupe = f.crop((r["left"], r["top"], r["left"] + r["width"], r["top"] + r["height"]))
    if "2x" in os.path.basename(chemin):
        coupe = coupe.resize((max(1, r["width"] // 2), max(1, r["height"] // 2)), Image.LANCZOS)
    return coupe


def etire(nom, w, h):
    return image(nom).resize((max(1, int(round(w))), max(1, int(round(h)))), Image.LANCZOS)


def neuf(nom, w, h, marge_image=20, marge=10):
    """La decoupe en neuf de SetAtlasNineSlice, refaite ici a l'identique."""
    e = par_nom[nom.lower()]
    chemin = _apercu(e["file"])
    if chemin not in _feuilles:
        _feuilles[chemin] = Image.open(chemin).convert("RGBA")
    r = e["region"]
    src = _feuilles[chemin].crop((r["left"], r["top"], r["left"] + r["width"], r["top"] + r["height"]))
    m = marge_image
    W, H = src.size
    w, h = int(round(w)), int(round(h))
    sortie = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def bout(boite, taille, pos):
        morceau = src.crop(boite).resize((max(1, taille[0]), max(1, taille[1])), Image.LANCZOS)
        sortie.alpha_composite(morceau, pos)

    mi_w, mi_h = w - 2 * marge, h - 2 * marge
    bout((0, 0, m, m), (marge, marge), (0, 0))
    bout((W - m, 0, W, m), (marge, marge), (w - marge, 0))
    bout((0, H - m, m, H), (marge, marge), (0, h - marge))
    bout((W - m, H - m, W, H), (marge, marge), (w - marge, h - marge))
    bout((m, 0, W - m, m), (mi_w, marge), (marge, 0))
    bout((m, H - m, W - m, H), (mi_w, marge), (marge, h - marge))
    bout((0, m, m, H - m), (marge, mi_h), (0, marge))
    bout((W - m, m, W, H - m), (marge, mi_h), (w - marge, marge))
    bout((m, m, W - m, H - m), (mi_w, mi_h), (marge, marge))
    return sortie


# ------------------------------------------------------------ geometrie
BOUTON, MARGE = 45, 2
BARRE_W = 12 * BOUTON + 11 * MARGE            # 562
MICRO_W, MICRO_H, MICRO_PAS = 32, 40, 27
MICRO_ART_H = 46
MICRO_N = 10
MICRO_RALLONGE = BOUTON + MARGE               # place rendue par l emplacement retire
MICRO_BOUTONS = MICRO_N * MICRO_W - (MICRO_N - 1) * 5   # 275
MICRO_LARGEUR = MICRO_BOUTONS + MICRO_RALLONGE          # 322
SACS_W = 5 * BOUTON + 33 + 5 * MARGE          # 268

micro_gauche = 116.5 - MICRO_LARGEUR / 2.0    # -21
micro_bas = 6
barre_droite = micro_gauche - 4.5             # -25.5
barre_gauche = barre_droite - BARRE_W
barre_bas = 2
sacs_gauche = micro_gauche + MICRO_LARGEUR + 7
sacs_bas = 2

GRYPHON_W, GRYPHON_H = 154, 95
gryphon_g_droite = barre_gauche + 30
gryphon_d_gauche = sacs_gauche + SACS_W - 30
# les embouts sont cales par le bas : bas de l image = bas de la barre
gryphon_bas = barre_bas - 2      # les embouts descendent de 2 px
gryphon_centre_y = gryphon_bas + GRYPHON_H / 2.0

X0 = gryphon_g_droite - GRYPHON_W - 10
X1 = gryphon_d_gauche + GRYPHON_W + 10
HAUT = gryphon_centre_y + GRYPHON_H / 2.0 + 6

LARGEUR = int(round(X1 - X0))
HAUTEUR = int(round(HAUT))
toile = Image.new("RGBA", (LARGEUR, HAUTEUR), (24, 26, 32, 255))


def poser(img, gauche, bas):
    """Coordonnees du jeu (y vers le haut) vers l'image (y vers le bas)."""
    x = int(round(gauche - X0))
    y = int(round(HAUTEUR - bas - img.size[1]))
    toile.alpha_composite(img, (x, y))


# ------------------------------------------------------- barre d'action
poser(neuf("ui-hud-actionbar-frame-c60-2x", BARRE_W + 10, BOUTON + 11),
      barre_gauche - 6, barre_bas - 5)
for i in range(12):
    x = barre_gauche + i * (BOUTON + MARGE)
    poser(etire("ui-hud-actionbar-iconframe-background", BOUTON, BOUTON), x, barre_bas)
    poser(etire("ui-hud-actionbar-iconframe-slot-c60", BOUTON, BOUTON), x, barre_bas)
    poser(etire("ui-hud-actionbar-iconframe-c60", 46, 45), x, barre_bas)
    if i > 0:
        haut = image("ui-hud-actionbar-frame-divider-threeslice-edgetop-c60")
        bas = image("ui-hud-actionbar-frame-divider-threeslice-edgebottom-c60")
        centre = image("!ui-hud-actionbar-frame-divider-threeslice-center-c60")
        sep_x = x - 12 + 5
        poser(bas, sep_x, barre_bas)
        poser(centre, sep_x, barre_bas + 15)
        poser(haut, sep_x, barre_bas + 31)

poser(etire("ui-hud-actionbar-gryphon-left-c60", GRYPHON_W, GRYPHON_H),
      gryphon_g_droite - GRYPHON_W, gryphon_centre_y - GRYPHON_H / 2.0)

# bloc de pagination : 17 x 34, BOTTOMRIGHT sur le BOTTOMLEFT de la barre (-4, 9)
page_droite = barre_gauche - 4
page_bas = barre_bas + 9
poser(etire("ui-hud-actionbar-pageuparrow-up", 17, 14), page_droite - 17, page_bas + 20)
poser(etire("ui-hud-actionbar-pagedownarrow-up", 17, 14), page_droite - 17, page_bas)


# ----------------------------------------------------------- micro-menu
poser(etire("ui-hud-actionbar-iconframe-background",
            MICRO_LARGEUR + 16 + 27, MICRO_H + 16 + 4),
      micro_gauche - 8 - 13, micro_bas - 8 - 4)
poser(neuf("ui-hud-actionbar-frame-c60-2x", MICRO_LARGEUR + 16, MICRO_H + 16),
      micro_gauche - 8, micro_bas - 8)

JEUX = [None, "spellbookabilities", "spectalents", "achievements", "questlog",
        "guildcommunities", None, "groupfinder", "adventureguide", "gamemenu"]
for i, jeu in enumerate(JEUX):
    x = micro_gauche + i * MICRO_PAS
    bas_art = micro_bas + (MICRO_H - MICRO_ART_H) / 2.0
    poser(etire("ui-hud-micromenu-buttonbg-up-c60-2x", MICRO_W, MICRO_ART_H), x, bas_art)
    if jeu:
        nom = "ui-hud-micromenu-%s-up-c60-2x" % jeu
        if nom.lower() not in par_nom:
            nom = "ui-hud-micromenu-%s-up-2x" % jeu
        poser(etire(nom, MICRO_W, MICRO_ART_H), x, bas_art)
    elif i == 0:
        poser(etire("ui-hud-micromenu-portrait-shadow-2x", MICRO_W, MICRO_ART_H), x, bas_art)

# ------------------------------------------------------- barre des sacs
poser(neuf("ui-hud-actionbar-frame-c60-2x", SACS_W + 11, BOUTON + 11),
      sacs_gauche - 6, sacs_bas - 5)
cellules = [33] + [BOUTON] * 5           # de gauche a droite : trousseau, 4 sacs, sac a dos
x = sacs_gauche
for i, largeur in enumerate(cellules):
    if largeur == 33:
        poser(etire("ui-hud-actionbar-iconframe-slot-small-c60", 27, 40), x + 3, sacs_bas + 2)
        poser(etire("ui-hud-actionbar-iconframe-small-c60", 33, 46), x, sacs_bas - 1)
    else:
        poser(etire("ui-hud-actionbar-iconframe-bags-c60", 46, 46), x, sacs_bas - 1)
    if i > 0:
        haut = image("ui-hud-actionbar-frame-divider-threeslice-edgetop-c60")
        bas = image("ui-hud-actionbar-frame-divider-threeslice-edgebottom-c60")
        centre = image("!ui-hud-actionbar-frame-divider-threeslice-center-c60")
        sep_x = x - MARGE - 5
        poser(bas, sep_x, sacs_bas)
        poser(centre, sep_x, sacs_bas + 15)
        poser(haut, sep_x, sacs_bas + 31)
    x += largeur + MARGE

poser(etire("ui-hud-actionbar-gryphon-right-c60", GRYPHON_W, GRYPHON_H),
      gryphon_d_gauche, gryphon_centre_y - GRYPHON_H / 2.0)

# ------------------------------------------- barres d experience et de reputation
BARRE_H = 13
barres_gauche = barre_gauche
barres_largeur = (sacs_gauche + SACS_W) - barre_gauche
haut_rangee = max(barre_bas + BOUTON + 6, micro_bas + MICRO_H + 8, sacs_bas + BOUTON + 6)

xp_bas = haut_rangee
rep_bas = xp_bas + BARRE_H
for bas, remplissage in ((xp_bas, "ui-hud-experiencebar-fill-experience-camelot"),
                         (rep_bas, "ui-hud-experiencebar-fill-reputation-camelot")):
    poser(etire("ui-hud-experiencebar-background-camelot", barres_largeur, BARRE_H),
          barres_gauche, bas)
    part = etire(remplissage, barres_largeur, BARRE_H)
    poser(part.crop((0, 0, int(barres_largeur * 0.6), BARRE_H)), barres_gauche, bas)
    poser(etire("ui-hud-experiencebar-frame-camelot", barres_largeur, BARRE_H),
          barres_gauche, bas)
# les griffons repassent devant : c est leur niveau de cadre dans le jeu
poser(etire("ui-hud-actionbar-gryphon-left-c60", GRYPHON_W, GRYPHON_H),
      gryphon_g_droite - GRYPHON_W, gryphon_bas)
poser(etire("ui-hud-actionbar-gryphon-right-c60", GRYPHON_W, GRYPHON_H),
      gryphon_d_gauche, gryphon_bas)
print("barres : %.1f -> %.1f, experience a %d, reputation a %d, haut a %d" % (
    barres_gauche, barres_gauche + barres_largeur, xp_bas, rep_bas, rep_bas + BARRE_H))

sortie = os.path.join(BASE, "apercu_rangee.png")
toile.save(sortie)
print("rangee : %d x %d px" % toile.size)
print("barre  : %.1f -> %.1f | micro : %.1f -> %.1f | sacs : %.1f -> %.1f" % (
    barre_gauche, barre_droite, micro_gauche, micro_gauche + MICRO_LARGEUR,
    sacs_gauche, sacs_gauche + SACS_W))
toile.crop((int(round(-60 - X0)), 0, LARGEUR, HAUTEUR)).resize(
    (2 * (LARGEUR - int(round(-60 - X0))), 2 * HAUTEUR), Image.LANCZOS).save(
    os.path.join(BASE, "apercu_rangee_droite.png"))
print(sortie)
