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

"""Les decors des ecrans d'accueil, personnage ramene a sa taille.

POURQUOI. Le client limite la scene 3D de la creation et de la selection au
16:9 (GlueParent_OnLoad) ; nos ecrans d'accueil l'etendent au 2:1
(G.RAPPORT_MAX, ForeverUIGlue.lua). Or la camera d'un decor a un champ
DIAGONAL : le client en tire la hauteur vue par fov / racine(1 + rapport^2)
(Wow.exe, 0x6BFE00). Une scene plus large grossit donc tout, de
racine(5) / racine(1 + (16/9)^2) = 1,096 : les personnages paraissent trop
pres (constate le 2026-09-27 ; patch-Z desactive, ils reprennent leur
taille).

LE LEVIER. La camera est celle du modele de decor
(Interface\\Glues\\Models\\UI_<race>\\UI_<race>.m2) et aucune fonction Lua
ne la regle. Le personnage se tient sur l'attache 0 du decor, dont l'os
porte une echelle fixe, propre a chaque decor (0,768 pour le draenei,
1,876 pour l'humain...) : c'est ainsi que le client le dimensionne.

CE QU'IL FAIT. Ecrit dans data/art/Interface/Glues/Models/ les decors de la
creation et de la selection, l'echelle de l'os de l'attache 0 multipliee
par ECHELLE = 1 / 1,096 ; tools/deployer.py les verse a leur propre chemin
dans patch-Z, a la place de ceux du client. Le personnage rapetisse sur
place (l'os pivote sur le point ou il se tient : les pieds ne bougent pas) ;
decor et camera restent ceux du client.
  * Quand l'os ne porte que le personnage, ses cles d'echelle sont
    multipliees sur place : meme taille de fichier, rien d'autre ne change.
  * Quand il porte aussi le decor (celui du mort-vivant tient 19 297
    sommets de la crypte : il figure dans la table de correspondance des
    os), l'attache 0 est rebranchee sur un os de plus, copie de l'original,
    seul a etre reduit. Les os sont recopies en fin de fichier, suivis des
    pistes du nouvel os. PISTES A PART : au chargement, le client convertit
    sur place les tables d'un modele (decalages -> adresses) ; une table
    partagee par deux os le serait deux fois et le modele ne se chargerait
    plus (creation toute noire, constate le 2026-09-27). Les decors du client
    ne partagent jamais une table entre os.
Les .skin du client servent tels quels (le nombre d'os ne les concerne pas).

LIMITE. La reduction vaut pour un ecran de 2:1 ou plus large. Sur un ecran
plus etroit, nos ecrans d'accueil ont le meme cadre que le client, et les
personnages seraient plus petits que les siens.
"""
import argparse
import io
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import mpq  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIENT_DEFAUT = r"E:\world of warcraft 3.3.5a hd"
SORTIE = os.path.join(RACINE, "data", "art")
BS = chr(92)
# les noms que rendent GetCreateBackgroundModel et GetSelectBackgroundModel
# (le gnome prend le decor du nain, le troll celui de l'orc)
DECORS = ("Human", "Orc", "Dwarf", "NightElf", "Scourge", "Tauren", "BloodElf", "Draenei", "DeathKnight")
# le 2:1 de nos ecrans d'accueil ramene au 16:9 du client
ECHELLE = math.sqrt(1 + (16 / 9.0) ** 2) / math.sqrt(1 + 2.0 ** 2)
# M2 version 264 : entete, os (M2CompBone, 88 octets), attaches (40 octets)
M2_OS, M2_ATTACHES = 0x2C, 0xF0
M2_CORRESPONDANCE = 0x78    # bone lookup : les os que les sommets designent
TAILLE_OS, TAILLE_ATTACHE = 88, 40
OS_ECHELLE = 56             # M2Track<C3Vector> scale dans M2CompBone
# les pistes d'un os : decalage dans M2CompBone, taille d'une cle
PISTES = ((16, 12), (36, 8), (OS_ECHELLE, 12))   # C3Vector, M2CompQuat, C3Vector


def aligner(d):
    d.extend(bytes(-len(d) % 16))


def copier_piste(d, piste, taille, facteur=None):
    """Recopie en fin de fichier les tables et les cles d'une piste (M2Track
    : interpolation, sequence globale, temps, valeurs), les valeurs
    multipliees par facteur s'il est donne. Rend la premiere valeur."""
    if struct.unpack_from("<h", d, piste)[0] in (2, 3):
        taille *= 3                 # hermite, bezier : valeur et deux tangentes
    premiere = None
    for champ, t in ((4, 4), (12, taille)):
        n, o = struct.unpack_from("<II", d, piste + champ)
        aligner(d)
        table = len(d)
        d.extend(bytes(8 * n))
        for k in range(n):
            m, q = struct.unpack_from("<II", d, o + 8 * k)
            bloc = bytes(d[q:q + m * t])
            if champ == 12 and facteur is not None and m:
                valeurs = struct.unpack("<%df" % (len(bloc) // 4), bloc)
                premiere = premiere or valeurs[0]
                bloc = struct.pack("<%df" % len(valeurs), *(x * facteur for x in valeurs))
            aligner(d)
            donnees = len(d) if m else 0
            d.extend(bloc)
            struct.pack_into("<II", d, table + 8 * k, m, donnees)
        struct.pack_into("<I", d, piste + champ + 4, table if n else 0)
    return premiere


def reduire(d):
    """Reduit le personnage d'un decor ; rend (os, sur place ?, echelle d'avant)."""
    nb_os, os_ = struct.unpack_from("<II", d, M2_OS)
    nb_att, att = struct.unpack_from("<II", d, M2_ATTACHES)
    rang = numero = None
    for i in range(nb_att):
        ident, n = struct.unpack_from("<IH", d, att + TAILLE_ATTACHE * i)
        if ident == 0:
            rang, numero = i, n
            break
    if rang is None or numero >= nb_os:
        raise ValueError("pas d'attache 0")
    piste = os_ + TAILLE_OS * numero + OS_ECHELLE
    if not struct.unpack_from("<I", d, piste + 12)[0]:
        raise ValueError("l'os %d n'a pas d'echelle a reduire" % numero)
    nb_corr, corr = struct.unpack_from("<II", d, M2_CORRESPONDANCE)
    porte_le_decor = numero in struct.unpack_from("<%dH" % nb_corr, d, corr)

    if not porte_le_decor:
        taille = 36 if struct.unpack_from("<h", d, piste)[0] in (2, 3) else 12
        n_seq, tables = struct.unpack_from("<II", d, piste + 12)
        avant = None
        for k in range(n_seq):
            m, q = struct.unpack_from("<II", d, tables + 8 * k)
            valeurs = struct.unpack_from("<%df" % (m * taille // 4), d, q)
            avant = avant or (valeurs[0] if valeurs else None)
            struct.pack_into("<%df" % len(valeurs), d, q, *(x * ECHELLE for x in valeurs))
        return numero, True, avant

    nouvel_os = bytearray(d[os_ + TAILLE_OS * numero:os_ + TAILLE_OS * (numero + 1)])
    struct.pack_into("<i", nouvel_os, 0, -1)        # pas d'os cle
    aligner(d)
    nouveaux_os = len(d)
    d.extend(d[os_:os_ + TAILLE_OS * nb_os])
    d.extend(nouvel_os)
    ici = nouveaux_os + TAILLE_OS * nb_os
    avant = None
    for decalage, taille in PISTES:
        v = copier_piste(d, ici + decalage, taille, ECHELLE if decalage == OS_ECHELLE else None)
        avant = avant or v
    struct.pack_into("<II", d, M2_OS, nb_os + 1, nouveaux_os)
    struct.pack_into("<H", d, att + TAILLE_ATTACHE * rang + 4, nb_os)
    return nb_os, False, avant


def main():
    analyseur = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    analyseur.add_argument("--client", default=CLIENT_DEFAUT, help="dossier du client 3.3.5")
    options = analyseur.parse_args()
    # le client tel qu'il est, sans notre archive : on part des decors d'origine
    client = mpq.open_client(os.path.join(options.client, "Data"), "enUS", ignore=("patch-Z.MPQ",))

    for decor in DECORS:
        interne = BS.join(["Interface", "Glues", "Models", "UI_" + decor, "UI_" + decor + ".m2"])
        d = bytearray(client.read(interne))
        if d[:4] != b"MD20" or struct.unpack_from("<I", d, 4)[0] != 264:
            raise SystemExit("%s : pas un M2 de version 264" % interne)
        try:
            os_perso, sur_place, avant = reduire(d)
        except ValueError as e:
            raise SystemExit("%s : %s" % (interne, e))
        cible = os.path.join(SORTIE, *interne.split(BS))
        os.makedirs(os.path.dirname(cible), exist_ok=True)
        io.open(cible, "wb").write(bytes(d))
        print("   %-12s os %d%s : echelle %.3f -> %.3f" % (
            decor, os_perso, " (sur place)" if sur_place else " (os de plus)", avant, avant * ECHELLE))
    print("echelle %.4f -> %s" % (ECHELLE, os.path.relpath(os.path.join(SORTIE, "Interface", "Glues", "Models"), RACINE)))


if __name__ == "__main__":
    main()
