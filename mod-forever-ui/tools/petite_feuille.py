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

"""Retailler des elements d'atlas dans une petite feuille a eux.

POURQUOI. Un element qu'on fait TOURNER ne peut pas rester dans une grande
feuille partagee. La rotation se fait par SetTexCoord a huit arguments, dont
les quatre coins balaient le carre CIRCONSCRIT a l'element -- 1,41 fois son
cote. Tout ce qui se trouve autour dans la feuille entre alors dans le cadre :
c'est ainsi que l'anneau d'autolancement du familier montrait ses deux sprites
a la fois, le 2026-09-22.

L'element tournant est donc pose SEUL et AU MILIEU de sa feuille, avec de la
marge transparente tout autour.

CE QUE FAIT L'OUTIL. Il decoupe les elements demandes dans l'apercu PNG de
leur grande feuille, les range dans une image en puissance de deux, ecrit le
.blp (BGRA non compresse, la forme des autres feuilles) avec son apercu .png,
et genere une table d'atlas qui REDEFINIT ces noms. Elle se charge en dernier :
UIAtlas.data est une table plate, la derniere definition gagne.

USAGE
    python tools/petite_feuille.py
Les feuilles a produire sont decrites dans FEUILLES, ci-dessous.
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp                                    # noqa: E402

try:
    from PIL import Image
except ImportError:
    raise SystemExit("Pillow est necessaire : python -m pip install pillow")

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(RACINE, "data", "addon", "ForeverUI")
ART = os.path.join(RACINE, "data", "art")
PREFIXE = "ForeverUI"
TABLE = os.path.join(ADDON, "UIAtlas_07_petites_feuilles.lua")

# Chaque petite feuille : son chemin (sous interface/ForeverUI/), sa taille,
# et les noms d'atlas qu'elle reprend.
# "centre" : l'element est pose au MILIEU, avec de la marge transparente
# autour. C'est indispensable a tout element qu'on fera TOURNER : la
# rotation se fait par SetTexCoord a huit arguments, dont les quatre coins
# balaient le carre circonscrit -- 1,41 fois le cote. Sans marge, la
# rotation irait chercher les pixels du voisin.
FEUILLES = [
    {
        "chemin": "hud/petautocastants",
        "taille": 128,
        "centre": True,
        "elements": ["ui-hud-actionbar-petautocast-ants"],
    },
    {
        "chemin": "hud/petautocastcorners",
        "taille": 64,
        "elements": ["ui-hud-actionbar-petautocast-corners"],
    },
]


def lire_tables():
    """Les entrees d'atlas et les feuilles, telles que l'addon les declare."""
    entrees, feuilles = {}, {}
    for nom in sorted(os.listdir(ADDON)):
        if not nom.startswith("UIAtlas_") or nom == os.path.basename(TABLE):
            continue
        t = io.open(os.path.join(ADDON, nom), encoding="utf-8").read()
        locales = {}
        for m in re.finditer(r'\[(\d+)\]\s*=\s*"([^"]+)"', t):
            locales[int(m.group(1))] = m.group(2).replace("\\\\", "\\")
        for m in re.finditer(r'\["([^"]+)"\]\s*=\s*\{([^}]*)\}', t):
            champs = [x.strip() for x in m.group(2).split(",")]
            idx = int(champs[0])
            entrees[m.group(1)] = {
                "feuille": locales.get(idx),
                "uv": [float(x) for x in champs[1:5]],
                "taille": [float(champs[5]), float(champs[6])],
            }
        feuilles.update(locales)
    return entrees, feuilles


def chemin_art(chemin, extension):
    return os.path.join(ART, "interface", PREFIXE, *chemin.split("/")) + extension


def construire(feuille, entrees):
    cote = feuille["taille"]
    image = Image.new("RGBA", (cote, cote), (0, 0, 0, 0))
    poses, x = [], 0
    centre = feuille.get("centre")

    for nom in feuille["elements"]:
        e = entrees.get(nom)
        if not e:
            raise SystemExit("nom d'atlas inconnu : %s" % nom)

        source = chemin_art(e["feuille"].split("\\", 2)[2].replace("\\", "/"), ".png")
        if not os.path.exists(source):
            raise SystemExit("apercu introuvable : %s" % source)

        grande = Image.open(source).convert("RGBA")
        L, H = grande.size
        u1, u2, v1, v2 = e["uv"]
        boite = (int(round(u1 * L)), int(round(v1 * H)),
                 int(round(u2 * L)), int(round(v2 * H)))
        morceau = grande.crop(boite)
        l, h = morceau.size

        if centre:
            besoin = int(round(l * 1.4143))
            if besoin > cote:
                raise SystemExit(
                    "%s tourne sur %d : il faut une feuille de %d au moins"
                    % (nom, l, besoin))
            px, py = (cote - l) // 2, (cote - h) // 2
        else:
            if x + l > cote or h > cote:
                raise SystemExit("%s ne tient pas dans %d : %d x %d" % (nom, cote, l, h))
            px, py = x, 0

        image.paste(morceau, (px, py))
        poses.append((nom, px, py, l, h, e["taille"]))
        marge = centre and "  (centre, marge de %d pour la rotation)" % px or ""
        print("   %-42s %3d x %-3d pose en (%d, %d)%s" % (nom, l, h, px, py, marge))
        x += l

    return image, poses


def main():
    entrees, _ = lire_tables()
    lignes = [
        "-- 07_petites_feuilles : des elements retailles a part.",
        "--",
        "-- POURQUOI. Un element qu'on fait tourner ne peut pas rester dans une",
        "-- grande feuille partagee : la rotation balaie le carre circonscrit, et tout",
        "-- ce qui l'entoure entre dans le cadre. Ces elements ont donc ete recoupes",
        "-- seuls, au milieu de leur feuille, par tools/petite_feuille.py. Ce fichier",
        "-- se charge EN DERNIER : UIAtlas.data est une table plate, sa definition",
        "-- gagne sur celle d'origine.",
        "",
        "UIAtlas = UIAtlas or { sheets = {}, data = {} }",
        "",
        "local S = {",
    ]
    corps = []
    index = 1

    for feuille in FEUILLES:
        print("feuille %s :" % feuille["chemin"])
        image, poses = construire(feuille, entrees)
        cote = feuille["taille"]

        blp_cible = chemin_art(feuille["chemin"], ".blp")
        png_cible = chemin_art(feuille["chemin"], ".png")
        os.makedirs(os.path.dirname(blp_cible), exist_ok=True)
        image.save(png_cible)
        open(blp_cible, "wb").write(blp.encoder(cote, cote, image.tobytes()))
        print("   -> %s (%d octets) et son apercu" % (
            os.path.relpath(blp_cible, RACINE), os.path.getsize(blp_cible)))

        chemin_lua = ("interface\\\\%s\\\\%s" % (PREFIXE, feuille["chemin"].replace("/", "\\\\")))
        lignes.append('\t[%d] = "%s", -- %d x %d' % (index, chemin_lua, cote, cote))
        for nom, x, y, l, h, taille in poses:
            corps.append('\t["%s"] = {%d, %.6f, %.6f, %.6f, %.6f, %g, %g},' % (
                nom, index, x / float(cote), (x + l) / float(cote),
                y / float(cote), (y + h) / float(cote), taille[0], taille[1]))
        index += 1

    lignes.append("}")
    lignes.append("")
    lignes.append("local D = {")
    lignes.extend(corps)
    lignes.append("}")
    lignes.append("")
    lignes.append("for i, chemin in pairs(S) do UIAtlas.sheets[chemin] = true end")
    lignes.append("for nom, e in pairs(D) do")
    lignes.append("\tUIAtlas.data[nom] = { S[e[1]], e[2], e[3], e[4], e[5], e[6], e[7] }")
    lignes.append("end")
    lignes.append("")

    io.open(TABLE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print("table : %s" % os.path.relpath(TABLE, RACINE))


if __name__ == "__main__":
    main()
