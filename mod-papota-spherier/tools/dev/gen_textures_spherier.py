# -*- coding: utf-8 -*-
r"""Textures de l'éditeur de sphèrier — ligne et arcs d'anneau.

Produit dans Interface\AddOns\SpherierArt\ du client (lu directement sur le
disque par le client 3.3.5, sans MPQ) :

  line.tga   trait blanc anti-aliasé, horizontal, remplaçant UI-Taxi-Line dont
             le cœur est quasi noir (RGB 18) — c'était le trait sombre visible
             au milieu de chaque segment une fois la texture teintée en gris.
             Contenu en colonnes 1..126 pour le facteur (128/126)/2 du client.

  arcN.tga   l'arc de 45° entre deux emplacements voisins de l'anneau N, cuit
             en une seule image : corde de 240 texels entre (8,100) et
             (248,100), bombé vers le haut, épaisseur constante À L'ÉCRAN
             (EDGE_THICK px) donc différente en texels selon le rayon.

Ces valeurs sont couplées aux constantes de Spherier_Client.lua
(ARC_TEX_W/H, ARC_CHORD_U0/V, ARC_CHORD_TEXELS, EDGE_THICK) et à la géométrie
des clusters (rayons 1.1/2.1/3.1, SPACING 64, 8 branches → arcs de 45°).
"""

import math
import os
import shutil
import sys

from PIL import Image

# Le dossier du client se CHERCHE, version comprise (2026-09-06) : ecrit en dur,
# il avait fait echouer l'injection en silence au renommage 1.1.0 -> 1.2.0.
from gen_sorts_classes import dossier_client as _dossier_client
# JALON 7 (2026-09-06) : plus rien n'est pose dans le client. Les TGA sont des
# SOURCES, dans spherier_art\ ; gen_spherier_art_mpq.py les cuit en BLP2 DXT5
# et les injecte dans patch-z sous Interface\Papota\SpherierArt\.
CLIENT_ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "spherier_art")
LOCAL_OUT = CLIENT_ART   # un seul dossier : les sources (2026-09-06)

SPACING = 64
RADII = [1.1, 2.1, 3.1]
EDGE_THICK = 5.0            # épaisseur écran visée, en pixels — aligner sur
                            # EDGE_THICK de Spherier_Client.lua
FEATHER_SCREEN = 0.75       # adoucissement du bord, en pixels écran

# --- line.tga : 128×128, bande horizontale centrée --------------------------

LINE_SIZE = 128
LINE_HALF_SOLID = 38.0      # demi-épaisseur pleine, en texels (sur 128 → ~6 px)
LINE_FEATHER = 12.0         # texels de fondu (→ ~0,9 px à l'écran)


# --- profils de section : le style d'une liaison ----------------------------
#
# Un profil décrit ce qu'on voit en COUPE d'une liaison : pour une distance à
# l'axe donnée EN PIXELS ÉCRAN, il rend (luminosité, alpha). La luminosité est
# multipliée par la teinte posée en Lua — un cœur blanc prend donc pleinement la
# couleur d'état, tandis qu'une bordure noire reste noire quelle que soit la
# teinte. Ligne droite et arcs partagent le même profil, d'où des liaisons
# identiques quel que soit leur tracé.
#
# Le halo sombre du filet de Paragon (planche JourneysFrame2x) n'est pas repris
# tel quel : il sert à détacher le trait d'un panneau CLAIR, alors que notre
# canevas est presque noir — il y serait invisible. Les profils ci-dessous en
# gardent l'idée (cœur fin et net, flancs marqués) en l'adaptant au fond sombre.


def profil_plein(d):
    """Trait uni adouci — le style d'origine."""
    a = (LINE_HALF_SOLID + LINE_FEATHER - d * LINE_SIZE / EDGE_THICK) / LINE_FEATHER
    return 1.0, max(0.0, min(1.0, a))


def profil_rail(d):
    """Gouttière gravée : deux rails vifs, creux assombri entre les deux."""
    rail = max(0.0, min(1.0, (0.85 - abs(d - 1.35)) / 0.45))
    creux = max(0.0, min(1.0, (0.75 - d) / 0.35))
    if rail >= creux:
        return 1.0, rail
    return 0.35, creux * 0.75           # le fond du creux, sombre mais présent


def profil_conduit(d):
    """Cœur plein et lumineux, noyé dans une lueur large et douce."""
    coeur = max(0.0, min(1.0, (1.45 - d) / 0.45))
    lueur = math.exp(-(d / 2.9) ** 2) * 0.40
    if coeur >= lueur:
        return 1.0, coeur
    return 0.85, lueur


PROFILS = {"plein": profil_plein, "rail": profil_rail, "conduit": profil_conduit}


def gen_line(profil=profil_plein, epaisseur=EDGE_THICK):
    img = Image.new("RGBA", (LINE_SIZE, LINE_SIZE), (255, 255, 255, 0))
    px = img.load()
    cy = (LINE_SIZE - 1) / 2.0
    for y in range(LINE_SIZE):
        # la texture entière est plaquée sur un quad de `epaisseur` pixels
        d = abs(y - cy) * epaisseur / LINE_SIZE
        lum, a = profil(d)
        v = int(round(lum * 255))
        for x in range(1, LINE_SIZE - 1):
            px[x, y] = (v, v, v, int(round(a * 255)))
    # bords transparents : l'échantillonnage hors [0,1] retombe dessus
    for x in range(LINE_SIZE):
        px[x, 0] = (255, 255, 255, 0)
        px[x, LINE_SIZE - 1] = (255, 255, 255, 0)
    return img


# --- arcN.tga : 256×128, arc de 45° -----------------------------------------

ARC_W, ARC_H = 256, 128
CHORD_U0, CHORD_U1, CHORD_V = 8.0, 248.0, 100.0
CHORD_TEXELS = CHORD_U1 - CHORD_U0
HALF_ANGLE = math.pi / 8            # 22,5°

R_TEX = CHORD_TEXELS / (2 * math.sin(HALF_ANGLE))          # ≈ 313,57
CENTER_U = (CHORD_U0 + CHORD_U1) / 2                        # 128
CENTER_V = CHORD_V + R_TEX * math.cos(HALF_ANGLE)           # ≈ 389,68


def gen_arc(ring_radius_units, profil=profil_plein, epaisseur=EDGE_THICK):
    r_screen = ring_radius_units * SPACING
    chord_screen = 2 * r_screen * math.sin(HALF_ANGLE)
    s = chord_screen / CHORD_TEXELS                 # pixels écran par texel

    img = Image.new("RGBA", (ARC_W, ARC_H), (255, 255, 255, 0))
    px = img.load()
    for y in range(1, ARC_H - 1):
        for x in range(1, ARC_W - 1):
            du = (x + 0.5) - CENTER_U
            dv = CENTER_V - (y + 0.5)               # positif vers le haut
            dist = math.hypot(du, dv)
            ang = math.atan2(du, dv)                # 0 = plein haut
            if abs(ang) > HALF_ANGLE:
                continue
            # distance à l'axe de l'arc, convertie en pixels écran : le profil
            # est donc le même que celui des segments droits.
            lum, a = profil(abs(dist - R_TEX) * s)
            if a > 0:
                v = int(round(lum * 255))
                px[x, y] = (v, v, v, int(round(a * 255)))
    return img


# Note : le pourtour des icônes rondes n'est PAS masqué par une texture d'ici.
# Le masque du moteur (SetPortraitToTexture) n'est pas réglable et un
# SetTexCoord posé ensuite le détruit ; on recouvre donc le bord de l'icône par
# l'anneau du client `Interface\Journeys\JourneysFrame2x` — la technique du
# plugin Paragon, voir RC.FRAME_* dans les deux clients Lua.


# --- spark.tga : le point qui court le long des liaisons actives ------------
#
# Cœur SERRÉ et vif, lueur LARGE et douce — le dégradé circulaire du client
# (gradientCircle), dont le cœur occupe 42 % de la texture, donnait un point
# plat. Rendu en fusion ADD, donc le noir disparaît et seul le blanc éclaire.
# Rayons exprimés en fraction du demi-côté : à 28 px d'affichage (demi = 14 px),
# le cœur est plein sur 2 px, s'éteint à 3,5 px, et la lueur porte à ~4,5 px.

SPARK_SIZE = 64
SPARK_COEUR, SPARK_FONDU = 0.14, 0.11       # cœur plein, puis fondu
SPARK_LUEUR, SPARK_INTENSITE = 0.32, 0.45   # écart-type et amplitude de la lueur


def gen_spark():
    img = Image.new("RGBA", (SPARK_SIZE, SPARK_SIZE), (255, 255, 255, 0))
    px = img.load()
    c = (SPARK_SIZE - 1) / 2.0
    demi = SPARK_SIZE / 2.0
    for y in range(SPARK_SIZE):
        for x in range(SPARK_SIZE):
            r = math.hypot(x - c, y - c) / demi
            coeur = max(0.0, min(1.0, (SPARK_COEUR + SPARK_FONDU - r) / SPARK_FONDU))
            lueur = math.exp(-(r / SPARK_LUEUR) ** 2) * SPARK_INTENSITE
            a = max(coeur, lueur)
            # extinction franche avant le bord : pas d'arête au coin du quad
            a *= max(0.0, min(1.0, (1.0 - r) / 0.12))
            if a > 0:
                px[x, y] = (255, 255, 255, int(round(a * 255)))
    return img


# Épaisseur du quad, par style : le profil est COUPÉ au-delà, le quad ne faisant
# que cette hauteur. Choisir un style impose donc RC.EDGE_THICK dans les deux
# clients Lua.
EPAISSEURS = {"plein": 5, "rail": 6, "conduit": 11}


def apercu(chemin, zoom=5):
    """Comparatif des styles, dans les couleurs d'état, sur le fond du canevas."""
    etats = [("verrouillé", (0.45, 0.45, 0.45)), ("frontière", (0.62, 0.62, 0.62)),
             ("actif", (0.20, 0.88, 0.96)), ("éteint", (0.14, 0.14, 0.14))]
    styles = list(PROFILS.keys())
    larg, haut = 140, 22
    img = Image.new("RGB", (larg * len(etats), haut * len(styles)), (8, 8, 8))
    px = img.load()

    for si, nom in enumerate(styles):
        profil, ep = PROFILS[nom], EPAISSEURS[nom]
        for ei, (_, teinte) in enumerate(etats):
            x0, y0 = ei * larg, si * haut
            cy = y0 + haut / 2.0
            for y in range(y0, y0 + haut):
                d = abs(y + 0.5 - cy)
                if d > ep / 2.0:                # hors du quad : rien
                    continue
                lum, a = profil(d)
                if a <= 0:
                    continue
                for x in range(x0 + 12, x0 + larg - 12):
                    fond = px[x, y]
                    px[x, y] = tuple(
                        int(round(fond[k] * (1 - a) + 255 * lum * teinte[k] * a))
                        for k in range(3))

    img = img.resize((img.width * zoom, img.height * zoom), Image.NEAREST)
    img.save(chemin)
    print("aperçu écrit :", chemin)
    print("  lignes  :", " / ".join(styles))
    print("  colonnes:", " / ".join(e[0] for e in etats))


def main():
    args = [a for a in sys.argv[1:]]
    if "--apercu" in args:
        os.makedirs(LOCAL_OUT, exist_ok=True)
        apercu(os.path.join(LOCAL_OUT, "apercu_liens.png"))
        return

    # « conduit » est le style retenu (2026-08-24) : c'est lui que régénère une
    # exécution sans argument.
    style = args[0] if args else "conduit"
    if style not in PROFILS:
        raise SystemExit("style inconnu : %s (choix : %s)" % (style, ", ".join(PROFILS)))
    profil, ep = PROFILS[style], EPAISSEURS[style]

    os.makedirs(LOCAL_OUT, exist_ok=True)
    os.makedirs(CLIENT_ART, exist_ok=True)

    files = {"line.tga": gen_line(profil, ep), "spark.tga": gen_spark()}
    for i, r in enumerate(RADII, start=1):
        files["arc%d.tga" % i] = gen_arc(r, profil, ep)

    for name, img in files.items():
        img.save(os.path.join(CLIENT_ART, name))
        print("écrit :", name, img.size)
    print("sources écrites dans :", CLIENT_ART)
    print("puis : python gen_spherier_art_mpq.py   (jeu fermé, injecte dans patch-z)")
    print("style « %s » — mettre RC.EDGE_THICK = %d dans les deux clients Lua." % (style, ep))


if __name__ == "__main__":
    main()
