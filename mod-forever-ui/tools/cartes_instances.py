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

"""Les cartes des donjons et des raids, par nom, pour SetMapByID.

POURQUOI (demande du 2026-09-25). Cliquer le portail d'un donjon ou d'un raid
sur la carte du monde doit ouvrir la carte de l'instance. 3.3.5 a SetMapByID
(la chaine est dans Wow.exe) mais ne relie pas un repere a une carte : il
faut la table.

SOURCE : les DBC du CLIENT, par la chaine d'archives (patchs compris) :
  Map.dbc           0 ID, 2 InstanceType (1 donjon, 2 raid), 5 nom enUS
  WorldMapArea.dbc  0 ID (celui de SetMapByID), 1 MapID, 2 AreaID, 3 nom
                    interne
  AreaTable.dbc     0 ID, 11 nom enUS

SORTIE : data/addon/ForeverUI/WorldMapInstances.lua, ForeverUI.CartesInstances :
le nom en minuscules (celui de la carte, celui de la zone) -> l'ID de
WorldMapArea. Une instance a plusieurs cartes (les ailes du Monastere
Ecarlate) : chacune sous le nom de sa zone ; le nom de la carte va a la
premiere.

LES AUTRES LANGUES (2026-09-28, « aucun texte en dur ») : les portails
portent le nom que WDM leur donne dans la langue du client, par sa
LibBabble-Zone-3.0 (Interface/AddOns/WDM/libs, dans les archives du client).
Chacune de ses sections de langue (frFR, deDE, esES...) ajoute ses noms
traduits, en minuscules comme string.lower de Lua 5.1 les rend (ASCII
seulement), vers la meme carte que le nom anglais.
"""
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import mpq  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(RACINE, "data", "addon", "ForeverUI", "WorldMapInstances.lua")
CLIENT = sys.argv[1] if len(sys.argv) > 1 else r"E:\world of warcraft 3.3.5a hd\Data"
SEP = chr(92)

# LES NOMS DES PORTAILS. Les icones de portail de la carte viennent de WDM
# ("WoW Dungeon Maps - HD client", addon livre dans patch-enus-n.mpq), qui
# les nomme par LibBabble-Zone : tous se retrouvent dans les DBC sauf un.
ALIAS = {
    "the eye": "tempest keep",          # Tempest Keep, le raid (carte 550)
}


def lire(chaine, nom):
    d = chaine.read("DBFilesClient" + SEP + nom)
    n, champs, taille, taille_chaines = struct.unpack_from("<IIII", d, 4)
    debut = 20 + n * taille
    lignes = [struct.unpack_from("<%dI" % champs, d, 20 + i * taille) for i in range(n)]

    def texte(o):
        if o >= taille_chaines:
            return ""
        fin = d.index(b"\0", debut + o)
        return d[debut + o:fin].decode("utf-8", "replace")
    return lignes, texte


BABBLE = SEP.join(["Interface", "AddOns", "WDM", "libs", "LibBabble-Zone-3.0", "LibBabble-Zone-3.0.lua"])


def minuscules_lua(s):
    """string.lower de Lua 5.1 (locale C) : seules les lettres ASCII."""
    return "".join(c.lower() if "A" <= c <= "Z" else c for c in s)


def langues_babble(chaine):
    """{langue: {nom anglais en minuscules: nom traduit}} de LibBabble-Zone."""
    nom = next((n for n in chaine.names() if n.lower() == BABBLE.lower()), None)
    if not nom:
        return {}
    src = chaine.read(nom).decode("utf-8", "replace")
    res = {}
    marques = list(re.finditer(r'GAME_LOCALE == "(\w+)"', src))
    for i, m in enumerate(marques):
        bloc = src[m.end():marques[i + 1].start() if i + 1 < len(marques) else len(src)]
        noms = {}
        for e in re.finditer(r'(?:\["((?:[^"\\]|\\.)*)"\]|([A-Za-z_][A-Za-z0-9_]*))\s*=\s*"((?:[^"\\]|\\.)*)"', bloc):
            anglais = e.group(1) if e.group(1) is not None else e.group(2)
            noms[anglais.lower()] = e.group(3).replace('\\"', '"')
        res[m.group(1)] = noms
    return res


def main():
    chaine = mpq.open_client(CLIENT, "enUS")
    cartes, texte_carte = lire(chaine, "Map.dbc")
    instances = {r[0]: texte_carte(r[5]) for r in cartes if r[2] in (1, 2)}
    zones, texte_zone = lire(chaine, "AreaTable.dbc")
    nom_zone = {r[0]: texte_zone(r[11]) for r in zones}
    aires, texte_aire = lire(chaine, "WorldMapArea.dbc")

    table = {}
    vues = set()
    for r in sorted(aires, key=lambda r: r[0]):
        ident, carte, zone = r[0], r[1], r[2]
        if carte not in instances:
            continue
        for nom in (nom_zone.get(zone, ""), instances[carte] if carte not in vues else ""):
            cle = nom.strip().lower()
            if cle and cle not in table:
                table[cle] = ident
        vues.add(carte)
    for alias, nom in ALIAS.items():
        if nom in table and alias not in table:
            table[alias] = table[nom]
    anglais = dict(table)
    traduits = 0
    for langue, noms in sorted(langues_babble(chaine).items()):
        for cle, ident in sorted(anglais.items()):
            nom = noms.get(cle)
            if nom:
                cle2 = minuscules_lua(nom.strip())
                if cle2 not in table:
                    table[cle2] = ident
                    traduits += 1

    lignes = [
        "-- ForeverUI : les cartes des donjons et des raids (SetMapByID), par nom.",
        "-- GENERE par tools/cartes_instances.py depuis les DBC du client -- ne pas",
        "-- modifier a la main. Le nom en minuscules (carte ou zone) -> l'ID de",
        "-- WorldMapArea. Les noms anglais viennent des DBC, les autres langues de",
        "-- la LibBabble-Zone de WDM (le nom que ses portails portent).",
        "",
        "ForeverUI = ForeverUI or {}",
        "ForeverUI.CartesInstances = {",
    ]
    for cle in sorted(table):
        lignes.append('\t["%s"] = %d,' % (cle.replace('"', '\\"'), table[cle]))
    lignes.append("}")
    open(SORTIE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes) + "\n")
    print("%d noms (%d traduits) pour %d instances -> %s" % (len(table), traduits, len(vues), os.path.relpath(SORTIE, RACINE)))


if __name__ == "__main__":
    main()
