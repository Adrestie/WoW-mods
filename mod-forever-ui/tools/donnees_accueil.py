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

"""Les donnees du client moderne dont les ecrans d'accueil ont besoin.

LES COULEURS DE CLASSE. camelot colore la classe d'une carte de personnage
par GetClassColor(classFilename), qui lit ChrClasses.db2 (ClassColorR/G/B).
3.3.5 n'a pas cette fonction dans ses ecrans d'accueil, et GetCharacterInfo
n'y rend que le nom de la classe dans la langue du client : la table est
donc indexee par ce nom (celui de ChrClasses, en anglais) et donne le jeton
et la couleur.

CE QU'IL ECRIT. data/glue/Interface/GlueXML/ForeverUIGlueDonnees.lua.
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import db2  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLASSES = os.path.join(os.path.expanduser("~"), "wow.export", "dbfilesclient", "chrclasses.db2")
SORTIE = os.path.join(RACINE, "data", "glue", "Interface", "GlueXML", "ForeverUIGlueDonnees.lua")

# les classes de 3.3.5
CLASSES_335 = ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
               "SHAMAN", "MAGE", "WARLOCK", "DRUID")


def main():
    lignes = [
        "-- donnees du client moderne pour les ecrans d'accueil",
        "-- genere par tools/donnees_accueil.py",
        "",
        "ForeverUIGlue = ForeverUIGlue or {}",
        "-- nom de la classe (ChrClasses, anglais) -> jeton, couleur (ClassColorR/G/B)",
        "ForeverUIGlue.CLASSES = {",
    ]
    n = 0
    for _, v in db2.lire(CLASSES, (0, 1, 2, 3)):
        jeton = v[1]
        if jeton not in CLASSES_335:
            continue
        r, g, b = v[-6], v[-5], v[-4]
        noms = sorted(set(x for x in (v[0], v[2], v[3]) if x))
        for nom in noms:
            lignes.append('\t["%s"] = { "%s", %.4f, %.4f, %.4f },' % (nom, jeton, r / 255.0, g / 255.0, b / 255.0))
        n += 1
    # le chevalier de la mort n'existe pas chez camelot (absent de ChrClasses
    # du client moderne) : sa couleur est celle du client 3.3.5 lui-meme
    # (RAID_CLASS_COLORS, Interface/FrameXML/Constants.lua de patch-enus-2)
    lignes.append('	["Death Knight"] = { "DEATHKNIGHT", 0.7700, 0.1200, 0.2300 },')
    n += 1
    lignes += ["}", ""]
    io.open(SORTIE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print("donnees : %d classes -> %s" % (n, os.path.relpath(SORTIE, RACINE)))


if __name__ == "__main__":
    main()
