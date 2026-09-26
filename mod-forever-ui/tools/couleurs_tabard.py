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

"""Les couleurs des tabards de guilde, lues dans les textures du client 3.3.5.

POURQUOI. Camelot teinte le bouton Social de la couleur de fond du tabard, et
son petit embleme de la couleur de l'embleme (C_GuildInfo.GetGuildTabardInfo
rend ces couleurs). Le client 3.3.5 n'a pas cette fonction : il ne donne que
les NOMS des textures du tabard (GetGuildTabardFileNames), dont les couleurs
sont peintes dans l'image -- Background_<fond>_TU_U,
Emblem_<motif>_<couleur>_TU_U. On lit donc chaque couleur dans ces images.

LA MESURE. Les textures portent un ombrage (plis de l'etoffe, relief de
l'embleme) : la moyenne serait trop sombre. On garde la moyenne du quart le
plus lumineux des pixels opaques -- la teinte telle qu'elle apparait sous la
lumiere.

Sortie : data/addon/ForeverUI/TabardColors.lua, regenere a chaque passage.
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp, mpq  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIENT = r"E:\world of warcraft 3.3.5a hd\Data"
SORTIE = os.path.join(RACINE, "data", "addon", "ForeverUI", "TabardColors.lua")


def couleur(chaine, nom):
    largeur, hauteur, rgba, _ = blp.decoder(chaine.read(nom))
    pixels = []
    for i in range(0, len(rgba), 4):
        r, v, b, a = rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]
        if a > 200:
            pixels.append((0.299 * r + 0.587 * v + 0.114 * b, r, v, b))
    pixels.sort(reverse=True)
    haut = pixels[:max(1, len(pixels) // 4)]
    n = float(len(haut))
    return tuple(round(sum(p[k] for p in haut) / n / 255.0, 3) for k in (1, 2, 3))


def main():
    chaine = mpq.open_client(CLIENT, "enUS")
    fonds, emblemes = {}, {}
    for nom in chaine.names():
        bas = nom.lower()
        m = re.search(r"guildemblems.background_(\d+)_tu_u\.blp$", bas)
        if m:
            fonds.setdefault(int(m.group(1)), nom)
        m = re.search(r"guildemblems.emblem_(\d+)_(\d+)_tu_u\.blp$", bas)
        if m:
            emblemes.setdefault(int(m.group(2)), nom)
    lignes = [
        "-- genere par tools/couleurs_tabard.py depuis les textures du client 3.3.5",
        "-- (Background_<fond>_TU_U, Emblem_<motif>_<couleur>_TU_U) : ne pas modifier",
        "-- a la main.",
        "",
        "local ForeverUI = ForeverUI or {}",
        "_G.ForeverUI = ForeverUI",
        "",
        "ForeverUI.TabardCouleurs = {",
        "\tfond = {",
    ]
    for k in sorted(fonds):
        r, v, b = couleur(chaine, fonds[k])
        lignes.append("\t\t[%d] = { %s, %s, %s }," % (k, r, v, b))
    lignes += ["\t},", "\tembleme = {"]
    for k in sorted(emblemes):
        r, v, b = couleur(chaine, emblemes[k])
        lignes.append("\t\t[%d] = { %s, %s, %s }," % (k, r, v, b))
    lignes += ["\t},", "}", ""]
    with io.open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lignes))
    print("tabards : %d fonds, %d couleurs d'embleme -> %s" % (len(fonds), len(emblemes), os.path.relpath(SORTIE, RACINE)))


if __name__ == "__main__":
    main()
