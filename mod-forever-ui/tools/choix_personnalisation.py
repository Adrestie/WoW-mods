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

"""Les choix valides de la personnalisation, sans faire tourner le moteur.

POURQUOI. Le numero d'un choix est son rang parmi les choix valides. Les
recenser en faisant parcourir un reglage au moteur (CycleCharCustomization)
redessine le personnage a chaque cran : on voyait les visages defiler en
changeant la peau, et les FPS chutaient (constate le 2026-09-27). Les regles
du moteur sont donc reprises ici, sur ses propres donnees.

LES REGLES (Wow.exe, releve le 2026-09-27). Le moteur range CharSections en
cases [race][sexe][section][variation][couleur] (0x4F3BA0 ; section 0 peau,
1 visage, 2 pilosite, 3 cheveux, 4 sous-vetements). Une case est bonne si
sa ligne existe et si ses drapeaux passent (0x4F39A0) : bit 1 present, bits
4 et 8 absents -- chevalier de la mort (classe 6, 0x4F3A40) : bit 1
present, bit 4 ou 16 present, bit 8 absent.
  * peau c (0x4EB150) : peau (0, 0, c), visage (1, visage courant, c) et
    sous-vetements (4, 0, c) bons ;
  * visage v (0x4EB710) : une couleur c au moins avec visage (1, v, c),
    peau (0, 0, c) et sous-vetements (4, 0, c) bons ;
  * coiffure s (0x4F0490) : une couleur c au moins avec (3, s, c) bonne ;
  * couleur des cheveux c (0x4EB500) : (3, coiffure courante, c) bonne ;
  * pilosite (0x4EBCA0) : si la case (2, pilosite courante, couleur des
    cheveux) existe, les v qui ont une couleur au moins avec (2, v, c)
    bonne ; sinon tous les styles de CharacterFacialHairStyles.

CE QU'IL FAIT. Ecrit data/glue/Interface/GlueXML/ForeverUIGlueChoix.lua :
  ForeverUIGlue.choix["FICHIER DE LA RACE"][sexe 0/1] = {
      [section] = { [variation] = "chaine" }, barbes = n }
une chaine par variation, un caractere par couleur : "." pas de ligne,
sinon 0 a 3 = 1 (bonne hors chevalier de la mort) + 2 (bonne pour lui).
"""
import argparse
import io
import os
import struct
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import mpq  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIENT_DEFAUT = r"E:\world of warcraft 3.3.5a hd"
SORTIE = os.path.join(RACINE, "data", "glue", "Interface", "GlueXML", "ForeverUIGlueChoix.lua")
BS = chr(92)
JOUABLES = (1, 2, 3, 4, 5, 6, 7, 8, 10, 11)
SECTIONS = 5


def lire_dbc(client, nom):
    d = client.read("DBFilesClient" + BS + nom)
    if d[:4] != b"WDBC":
        raise SystemExit("%s illisible" % nom)
    n, champs, taille, _ = struct.unpack("<4I", d[4:20])
    chaines = d[20 + n * taille:]

    def chaine(o):
        return chaines[o:chaines.index(b"\0", o)].decode("utf-8", "replace")
    return [struct.unpack_from("<%dI" % champs, d, 20 + i * taille) for i in range(n)], chaine


def bonne(drapeaux, chevalier):
    if chevalier:
        return bool(drapeaux & 1) and bool(drapeaux & 0x14) and not drapeaux & 8
    return bool(drapeaux & 1) and not drapeaux & 0xC


def main():
    analyseur = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    analyseur.add_argument("--client", default=CLIENT_DEFAUT, help="dossier du client 3.3.5")
    options = analyseur.parse_args()
    # le client tel qu'il est, sans notre archive
    client = mpq.open_client(os.path.join(options.client, "Data"), "enUS", ignore=("patch-Z.MPQ",))

    races, chaine = lire_dbc(client, "ChrRaces.dbc")
    fichier = {v[0]: chaine(v[11]).upper() for v in races if v[0] in JOUABLES}
    cases = defaultdict(dict)          # (race, sexe, section) -> {(variation, couleur): drapeaux}
    for v in lire_dbc(client, "CharSections.dbc")[0]:
        race, sexe, section, drapeaux, variation, couleur = v[1], v[2], v[3], v[7], v[8], v[9]
        if race in fichier and section < SECTIONS:
            cases[(race, sexe, section)][(variation, couleur)] = drapeaux
    barbes = defaultdict(int)
    for v in lire_dbc(client, "CharacterFacialHairStyles.dbc")[0]:
        if v[0] in fichier:
            barbes[(v[0], v[1])] += 1

    lignes = [
        "-- les choix valides de la personnalisation, par race, sexe, section,",
        "-- variation ; un caractere par couleur (\".\" pas de ligne, sinon 1 : bonne",
        "-- hors chevalier de la mort, + 2 : bonne pour lui)",
        "-- genere par tools/choix_personnalisation.py depuis CharSections.dbc et",
        "-- CharacterFacialHairStyles.dbc du client 3.3.5",
        "",
        "ForeverUIGlue = ForeverUIGlue or {}",
        "ForeverUIGlue.choix = {",
    ]
    total = 0
    for race in sorted(fichier, key=lambda r: fichier[r]):
        lignes.append('\t["%s"] = {' % fichier[race])
        for sexe in (0, 1):
            lignes.append("\t\t[%d] = {" % sexe)
            for section in range(SECTIONS):
                c = cases.get((race, sexe, section), {})
                nb_var = max((var for var, _ in c), default=-1) + 1
                variations = []
                for var in range(nb_var):
                    couleurs = [col for v2, col in c if v2 == var]
                    n = max(couleurs, default=-1) + 1
                    texte = ""
                    for col in range(n):
                        d = c.get((var, col))
                        texte += "." if d is None else str((1 if bonne(d, False) else 0) + (2 if bonne(d, True) else 0))
                    variations.append('[%d] = "%s"' % (var, texte))
                    total += n
                lignes.append("\t\t\t[%d] = { n = %d, %s }," % (section, nb_var, ", ".join(variations)))
            lignes.append("\t\t\tbarbes = %d," % barbes[(race, sexe)])
            lignes.append("\t\t},")
        lignes.append("\t},")
    lignes += ["}", ""]
    io.open(SORTIE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print("choix : %d races, %d cases -> %s" % (len(fichier), total, os.path.relpath(SORTIE, RACINE)))


if __name__ == "__main__":
    main()
