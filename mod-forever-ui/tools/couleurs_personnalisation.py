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

"""Les couleurs des echantillons de la personnalisation.

POURQUOI. Camelot peint chaque choix de couleur d'un echantillon
(ColorSwatch1, teinte par SetVertexColor avec la couleur que porte son
ChrCustomizationChoice). Le 3.3.5 n'a pas ces couleurs : ses choix sont des
textures (CharSections.dbc). La couleur d'un choix est donc lue dans la
texture que le client pose pour lui.

CE QU'IL FAIT. Lit par la chaine d'archives du client CharSections.dbc et
ChrRaces.dbc ; pour chaque race jouable et chaque sexe :
  * peau (reglage 1, section 0) : la texture de peau de chaque couleur ;
  * couleur des cheveux (reglage 4, section 3) : pour chaque couleur, la
    texture de cheveux que portent le plus de coiffures ;
et en tire la couleur ainsi, par groupe (une race, un sexe, un reglage) :
  * LE MASQUE : les pixels qui changent d'une couleur a l'autre du groupe
    (ecart type au-dessus de SEUIL_ECART). Les bijoux, plumes, bandeaux et le
    gris de remplissage des textures de cheveux sont les memes pour toutes
    les couleurs : ils sortent du masque ; restent les meches (les cornes du
    tauren), et toute la peau ;
  * LA TEINTE : la moyenne des pixels du masque dont la luminosite est entre
    les centiles BANDE (les tons eclaires : les creux sombres entre les
    meches et les reflets blancs n'y entrent pas).
Un groupe d'une seule texture prend l'image entiere.
Ecrit data/glue/Interface/GlueXML/ForeverUIGlueCouleurs.lua :
  ForeverUIGlue.couleurs["FICHIER DE LA RACE"][sexe 0/1].peau[indice]
  ForeverUIGlue.couleurs["FICHIER DE LA RACE"][sexe 0/1].cheveux[indice]
= { r, g, b } ; l'indice est celui du moteur (ColorIndex de CharSections).
"""
import argparse
import io
import os
import struct
import sys
from collections import Counter

import numpy
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import mpq  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIENT_DEFAUT = r"E:\world of warcraft 3.3.5a hd"
SORTIE = os.path.join(RACINE, "data", "glue", "Interface", "GlueXML", "ForeverUIGlueCouleurs.lua")
BS = chr(92)
# les races jouables du 3.3.5 (ChrRaces : le gobelin, 9, ne l'est pas)
JOUABLES = (1, 2, 3, 4, 5, 6, 7, 8, 10, 11)
SECTION_PEAU, SECTION_CHEVEUX = 0, 3
TAILLE = 128            # les textures sont comparees a cette taille
SEUIL_ECART = 12        # sur 255
BANDE = (60, 95)        # centiles de luminosite
LUMINANCE = numpy.array([0.299, 0.587, 0.114])


def lire_dbc(client, nom):
    d = client.read("DBFilesClient" + BS + nom)
    if d[:4] != b"WDBC":
        raise SystemExit("%s illisible" % nom)
    n, champs, taille, _ = struct.unpack("<4I", d[4:20])
    chaines = d[20 + n * taille:]

    def chaine(o):
        return chaines[o:chaines.index(b"\0", o)].decode("utf-8", "replace")
    lignes = [struct.unpack_from("<%dI" % champs, d, 20 + i * taille) for i in range(n)]
    return lignes, chaine


def charger(client, texture):
    """La texture en tableau TAILLE x TAILLE x 3, ou None si illisible."""
    try:
        im = Image.open(io.BytesIO(client.read(texture))).convert("RGB")
    except Exception:
        return None
    return numpy.asarray(im.resize((TAILLE, TAILLE), Image.BOX), dtype=numpy.float64)


def teintes(images):
    """texture -> (r, g, b) entre 0 et 1, pour les textures d'un groupe."""
    pile = numpy.stack(list(images.values()))
    if len(images) > 1:
        masque = pile.std(axis=0).mean(axis=2) > SEUIL_ECART
    else:
        masque = numpy.ones((TAILLE, TAILLE), dtype=bool)
    if not masque.any():
        masque[:] = True
    res = {}
    for texture, a in images.items():
        px = a[masque]
        lum = px @ LUMINANCE
        bas, haut = numpy.percentile(lum, BANDE[0]), numpy.percentile(lum, BANDE[1])
        choisis = px[(lum >= bas) & (lum <= haut)]
        if len(choisis) == 0:
            choisis = px
        res[texture] = tuple(float(v) / 255.0 for v in choisis.mean(axis=0))
    return res


def textures(client):
    """(fichier de la race, sexe, 'peau' | 'cheveux', indice) -> texture."""
    races, chaine = lire_dbc(client, "ChrRaces.dbc")
    fichier = {v[0]: chaine(v[11]).upper() for v in races if v[0] in JOUABLES}
    sections, chaine = lire_dbc(client, "CharSections.dbc")
    peau, cheveux = {}, {}
    for v in sections:
        race, sexe, section, tex1, variation, couleur = v[1], v[2], v[3], chaine(v[4]), v[8], v[9]
        if race not in fichier or not tex1:
            continue
        if section == SECTION_PEAU and variation == 0:
            peau[(fichier[race], sexe, couleur)] = tex1
        elif section == SECTION_CHEVEUX:
            cheveux.setdefault((fichier[race], sexe, couleur), Counter())[tex1] += 1
    res = {}
    for (r, s, c), t in peau.items():
        res[(r, s, "peau", c)] = t
    for (r, s, c), compte in cheveux.items():
        # la plus portee ; a egalite, la premiere dans l'ordre des noms
        res[(r, s, "cheveux", c)] = sorted(compte.items(), key=lambda x: (-x[1], x[0].lower()))[0][0]
    return res


def main():
    analyseur = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    analyseur.add_argument("--client", default=CLIENT_DEFAUT, help="dossier du client 3.3.5")
    options = analyseur.parse_args()
    client = mpq.open_client(os.path.join(options.client, "Data"), "enUS")

    groupes = {}
    for (race, sexe, genre, indice), texture in textures(client).items():
        groupes.setdefault((race, sexe, genre), {})[indice] = texture
    couleurs, absentes, lues = {}, [], 0
    for (race, sexe, genre), choix in sorted(groupes.items()):
        images = {}
        for texture in sorted(set(choix.values())):
            a = charger(client, texture)
            if a is None:
                absentes.append(texture)
            else:
                images[texture] = a
        lues += len(images)
        if not images:
            continue
        t = teintes(images)
        for indice, texture in choix.items():
            if texture in t:
                couleurs.setdefault(race, {}).setdefault(sexe, {}).setdefault(genre, {})[indice] = t[texture]

    lignes = [
        "-- les couleurs des echantillons de la personnalisation (peau, cheveux)",
        "-- genere par tools/couleurs_personnalisation.py : teinte de la texture que",
        "-- CharSections.dbc pose pour chaque choix du client 3.3.5",
        "",
        "ForeverUIGlue = ForeverUIGlue or {}",
        "ForeverUIGlue.couleurs = {",
    ]
    for race in sorted(couleurs):
        lignes.append('\t["%s"] = {' % race)
        for sexe in sorted(couleurs[race]):
            lignes.append("\t\t[%d] = {" % sexe)
            for genre in ("peau", "cheveux"):
                table = couleurs[race][sexe].get(genre, {})
                lignes.append("\t\t\t%s = {" % genre)
                for indice in sorted(table):
                    r, g, b = table[indice]
                    lignes.append("\t\t\t\t[%d] = { %.3f, %.3f, %.3f }," % (indice, r, g, b))
                lignes.append("\t\t\t},")
            lignes.append("\t\t},")
        lignes.append("\t},")
    lignes += ["}", ""]
    io.open(SORTIE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    total = sum(len(t) for r in couleurs.values() for s in r.values() for t in s.values())
    print("couleurs : %d choix, %d textures lues -> %s" % (total, lues, os.path.relpath(SORTIE, RACINE)))
    for a in absentes:
        print("   sans echantillon : " + a)


if __name__ == "__main__":
    main()
