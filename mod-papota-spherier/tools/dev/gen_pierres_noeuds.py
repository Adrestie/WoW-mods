# -*- coding: utf-8 -*-
r"""Les PIERRES DES NŒUDS (2026-09-05) : la famille d'entrées que portent les
emplacements pré-alloués de la grille, distincte des pierres-objets.

Décision utilisateur : un nœud donne +1 / +2 / +3 / +5 / +7 selon sa qualité (révision du 2026-09-05 soir)
(commun → légendaire), les pierres serties par le joueur gardent
+5 / +7 / +10 / +15 / +30. Un nœud et une pierre sertie partageaient jusqu'ici
la même entrée (803100 + (stat − 1) × 5 + (qualité − 1)) : le montant vivant
dans papota_sphere_stone PAR ENTRÉE, il faut une seconde famille.

  entrée d'un nœud = 803310 + (stat − 1) × 5 + (qualité − 1)   (803310-803389)

Ces entrées ne sont PAS des objets : elles n'existent que dans
papota_sphere_stone (le module y lit stat et montant à l'activation), jamais
dans item_template ni dans les sacs. Elles vivent HORS de la plage 803100-803300
que le SQL des objets efface avant de se réécrire.

    python gen_pierres_noeuds.py      -> data\sql\world\2026_09_05_01_…pierres_noeuds.sql
"""
import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

BASE = 803310
NB_STATS = 16
MONTANTS = [1, 2, 3, 5, 7]          # commun, inhabituel, rare, épique, légendaire
SORTIE = (r"D:\Serveur WoW\azerothcore-wotlk\modules\mod-papota-spherier\data\sql\world"
          r"\2026_09_05_01_mod_papota_spherier_pierres_noeuds.sql")

lignes = [
    "-- Spherier Papota : PIERRES DES NOEUDS (2026-09-05).",
    "--",
    "-- Un emplacement pre-alloue de la grille donne +%s selon sa qualite ;" % "/+".join(map(str, MONTANTS)),
    "-- les pierres-objets serties par le joueur gardent leurs montants (803100-803179).",
    "-- Entree d'un noeud = %d + (stat - 1) * 5 + (qualite - 1). Ces entrees ne sont" % BASE,
    "-- pas des objets : elles ne vivent que dans papota_sphere_stone.",
    "-- REGENERABLE : gen_pierres_noeuds.py ; efface et reecrit SA plage seulement.",
    "DELETE FROM `papota_sphere_stone` WHERE `item_entry` BETWEEN %d AND %d;" % (BASE, BASE + NB_STATS * 5 - 1),
    "INSERT INTO `papota_sphere_stone` (`item_entry`, `stat_id`, `amount`) VALUES",
]
valeurs = []
for stat in range(1, NB_STATS + 1):
    for q, montant in enumerate(MONTANTS, start=1):
        valeurs.append("(%d, %d, %d)" % (BASE + (stat - 1) * 5 + (q - 1), stat, montant))
lignes.append(",\n".join(valeurs) + ";")

os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
io.open(SORTIE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes) + "\n")
print("%d pierres de noeud (%d-%d) -> %s" % (len(valeurs), BASE, BASE + len(valeurs) - 1, SORTIE))
