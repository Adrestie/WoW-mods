# -*- coding: utf-8 -*-
r"""Barème de puissance des sorts customs — FICHIER GÉNÉRÉ.

Écrit par `gen_ratios_classes.py --ecris`. Ne pas éditer à la
main : la passe suivante l'écrase en entier. Le dessin des sorts
vit dans `sorts_classes.py`, les mesures ici.

RATIOS : (direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus), le
P75 du kit de la spécialisation majoré de 10 %.

BASES : la valeur à écrire dans l'effet, par nature — la cadence
P75 du kit portée sur le temps que le sort occupe, majorée de sa
prime de recharge.
"""

RATIOS = {
    8600001: (0.0000, 0.0000, 0.5500, 0.0000),   # warrior Armes, dps physique
    8600002: (0.0000, 0.0000, 0.1886, 0.0000),   # warrior Fureur, dps physique
    8600003: (0.4714, 0.0000, 0.3697, 0.0000),   # warrior Protection, tank
    8600011: (0.4141, 0.0143, 0.2852, 0.0275),   # paladin Vindicte, dps hybride
    8600012: (0.4714, 0.0000, 0.0809, 0.0000),   # paladin Protection, tank
    8600013: (0.5347, 0.4825, 0.0000, 0.0000),   # paladin Sacré, soigneur
    8600022: (0.0000, 0.0000, 0.2338, 0.0440),   # hunter Précision, dps physique
    8600023: (0.0000, 0.0000, 0.1100, 0.1100),   # hunter Survie, dps physique
    8600031: (0.0000, 0.0000, 0.4258, 0.0770),   # rogue Assassinat, dps physique
    8600032: (0.0000, 0.0000, 0.2829, 0.0000),   # rogue Combat, dps physique
    8600034: (0.0000, 0.0000, 0.2829, 0.0000),   # rogue Combat, dps physique
    8600035: (0.0000, 0.0000, 0.2829, 0.0000),   # rogue Combat, dps physique
    8600036: (0.0000, 0.0000, 0.2829, 0.0000),   # rogue Combat, dps physique
    8600037: (0.0000, 0.0000, 0.2829, 0.0000),   # rogue Combat, dps physique
    8600038: (0.0000, 0.0000, 0.2829, 0.0000),   # rogue Combat, dps physique
    8600033: (0.0000, 0.0000, 0.1720, 0.0000),   # rogue Finesse, dps physique
    8600041: (0.3143, 0.4400, 0.0000, 0.0000),   # priest Ombre, dps magique
    8600042: (0.2357, 0.0000, 0.0000, 0.0000),   # priest Discipline, soigneur
    8600043: (0.8863, 0.4136, 0.0000, 0.0000),   # priest Sacré, soigneur
    8600051: (0.8863, 0.2567, 0.2475, 0.0000),   # deathknight Impie, dps hybride
    8600052: (0.4950, 0.0000, 0.0715, 0.0000),   # deathknight Sang, tank
    8600053: (0.0000, 0.0000, 0.2829, 0.0000),   # deathknight Givre, dps physique
    8600054: (0.0000, 0.0000, 0.2200, 0.0000),   # deathknight Givre, dps physique
    8600064: (1.5508, 0.4653, 0.0000, 0.0000),   # shaman Restauration, soigneur
    8600069: (1.5508, 0.4653, 0.0000, 0.0000),   # shaman Restauration, soigneur
    8600068: (0.4864, 0.0000, 0.1886, 0.0000),   # shaman Amélioration, dps hybride
    8600061: (0.4864, 0.0000, 0.1886, 0.0000),   # shaman Amélioration, dps hybride
    8600062: (0.6281, 0.1100, 0.0000, 0.0000),   # shaman Élémentaire, dps magique
    8600063: (1.5508, 0.4653, 0.0000, 0.0000),   # shaman Restauration, soigneur
    8600071: (0.7854, 0.0000, 0.0000, 0.0000),   # mage Arcanes, dps magique
    8600072: (0.3948, 0.1797, 0.0000, 0.0000),   # mage Feu, dps magique
    8600073: (1.1391, 0.0000, 0.0000, 0.0000),   # mage Givre, dps magique
    8600081: (0.2342, 0.1045, 0.0000, 0.0000),   # warlock Affliction, dps magique
    8600082: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8600083: (0.2890, 0.2200, 0.0000, 0.0000),   # warlock Destruction, dps magique
    8610000: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610001: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610002: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610003: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610004: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610005: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610006: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610007: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610008: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610009: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610010: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610011: (0.5307, 0.5918, 0.0000, 0.0000),   # warlock Démonologie, dps magique
    8610012: (0.9034, 0.2200, 0.0000, 0.0000),   # warlock Destruction, dps magique
    8610016: (0.0000, 0.0000, 0.6158, 0.0660),   # druid Farouche, dps physique
    8610017: (0.0000, 0.0000, 0.6158, 0.0660),   # druid Farouche, dps physique
    8610018: (0.0000, 0.0000, 0.6158, 0.0660),   # druid Farouche, dps physique
    8610019: (1.1075, 0.4136, 0.0000, 0.0000),   # druid Restauration, soigneur
    8610020: (0.9820, 0.2200, 0.0000, 0.0000),   # druid Équilibre, dps magique
    8610032: (0.9820, 0.2200, 0.0000, 0.0000),   # druid Équilibre, dps magique
    8610033: (0.9820, 0.2200, 0.0000, 0.0000),   # druid Équilibre, dps magique
    8610029: (0.9820, 0.2200, 0.0000, 0.0000),   # druid Équilibre, dps magique
    8610030: (0.9820, 0.2200, 0.0000, 0.0000),   # druid Équilibre, dps magique
    8610034: (0.9820, 0.2200, 0.0000, 0.0000),   # druid Équilibre, dps magique
    8610035: (0.9820, 0.2200, 0.0000, 0.0000),   # druid Équilibre, dps magique
    8610031: (0.9820, 0.2200, 0.0000, 0.0000),   # druid Équilibre, dps magique
    8610036: (0.5918, 0.1265, 0.0000, 0.0000),   # druid Restauration, soigneur
    8610026: (0.0000, 0.0000, 0.6158, 0.0660),   # druid Farouche, dps physique
    8610027: (0.0000, 0.0000, 0.6158, 0.0660),   # druid Farouche, dps physique
    8610028: (0.0000, 0.0000, 0.6158, 0.0660),   # druid Farouche, dps physique
    8600091: (0.0000, 0.0000, 0.6158, 0.0660),   # druid Farouche, dps physique
    8600092: (0.9820, 0.2200, 0.0000, 0.0000),   # druid Équilibre, dps magique
    8600093: (1.1075, 0.4136, 0.0000, 0.0000),   # druid Restauration, soigneur
    8600055: (0.0000, 0.0000, 0.5500, 0.0000),   # warrior Armes, dps physique
    8600056: (0.3948, 0.1797, 0.0000, 0.0000),   # mage Feu, dps magique
    8600057: (1.0607, 0.1797, 0.0000, 0.0000),   # mage Feu, dps magique
    8600096: (0.0000, 0.0000, 0.2338, 0.0440),   # hunter Précision, dps physique
    8600098: (0.0000, 0.0000, 0.0921, 0.0440),   # hunter Précision, dps physique
    8600059: (0.9004, 0.0000, 0.0000, 0.0000),   # priest Discipline, soigneur
    8600044: (0.8863, 0.4136, 0.0000, 0.0000),   # priest Sacré, soigneur
    8600045: (0.8863, 0.4136, 0.0000, 0.0000),   # priest Sacré, soigneur
    8600048: (0.8863, 0.2567, 0.2475, 0.0000),   # deathknight Impie, dps hybride
}

BASES = {
    8600001: {"degats_direct": 2775, "degats_duree": 1282},   # warrior Armes, prime 3.83
    8600002: {"degats_direct": 1382, "soin_direct": 116},   # warrior Fureur, prime 3.50
    8600003: {"degats_direct": 3598},   # warrior Protection, prime 1.80
    8600011: {"degats_direct": 3566},   # paladin Vindicte, prime 3.83
    8600012: {"degats_direct": 9992},   # paladin Protection, prime 6.50
    8600013: {"degats_direct": 3858, "soin_direct": 8865, "soin_duree": 429},   # paladin Sacré, prime 2.60
    8600021: {"soin_duree": 59675},   # hunter Maîtrise des bêtes, prime 5.17
    8600022: {"degats_direct": 2105, "degats_duree": 821, "degats_duree_tic": 137},   # hunter Précision, prime 3.08
    8600023: {"degats_direct": 1756, "degats_duree": 8253, "degats_duree_tic": 1376},   # hunter Survie, prime 3.05
    8600031: {"degats_direct": 2623, "degats_duree": 3515, "degats_duree_tic": 586},   # rogue Assassinat, prime 3.83
    8600032: {"degats_direct": 1777},   # rogue Combat, prime 3.00
    8600034: {"degats_direct": 592},   # rogue Combat, prime 1.00
    8600035: {"degats_direct": 592},   # rogue Combat, prime 1.00
    8600036: {"degats_direct": 592},   # rogue Combat, prime 1.00
    8600037: {"degats_direct": 592},   # rogue Combat, prime 1.00
    8600038: {"degats_direct": 592},   # rogue Combat, prime 1.00
    8600033: {"degats_direct": 1238},   # rogue Finesse, prime 3.25
    8600041: {"degats_direct": 6765, "degats_duree": 380},   # priest Ombre, prime 3.00
    8600042: {"degats_direct": 3552, "soin_direct": 18471},   # priest Discipline, prime 5.17
    8600043: {"degats_direct": 2875, "soin_direct": 15221, "degats_duree": 282, "soin_duree": 5295},   # priest Sacré, prime 3.42
    8600051: {"degats_direct": 3042, "soin_direct": 4789, "degats_duree": 2289},   # deathknight Impie, prime 4.50
    8600052: {"degats_direct": 1665, "soin_direct": 169},   # deathknight Sang, prime 3.83
    8600053: {"degats_direct": 3060},   # deathknight Givre, prime 5.17
    8600054: {"degats_direct": 3060},   # deathknight Givre, prime 5.17
    8600064: {"soin_direct": 1893, "soin_duree": 184},   # shaman Restauration, prime 1.00
    8600069: {"soin_direct": 1893, "soin_duree": 1959},   # shaman Restauration, prime 1.00
    8600068: {"degats_direct": 412},   # shaman Amélioration, prime 1.00
    8600061: {"degats_direct": 1244},   # shaman Amélioration, prime 3.02
    8600062: {"degats_direct": 6195, "degats_duree": 5301},   # shaman Élémentaire, prime 6.50
    8600063: {"soin_direct": 12305, "soin_duree": 12737, "soin_duree_tic": 796},   # shaman Restauration, prime 6.50
    8600071: {"degats_direct": 3527},   # mage Arcanes, prime 3.08
    8600072: {"degats_direct": 4533, "degats_duree": 2947, "degats_duree_tic": 368},   # mage Feu, prime 3.50
    8600073: {"degats_direct": 2089},   # mage Givre, prime 3.25
    8600081: {"degats_direct": 7635, "degats_duree": 6859, "degats_duree_tic": 457},   # warlock Affliction, prime 3.42
    8600082: {"degats_direct": 631, "soin_duree": 77220},   # warlock Démonologie, prime 4.50
    8600083: {"degats_direct": 4773, "degats_duree": 26908},   # warlock Destruction, prime 4.50
    8610000: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610001: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610002: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610003: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610004: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610005: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610006: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610007: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610008: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610009: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610010: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610011: {"degats_direct": 140, "soin_duree": 858},   # warlock Démonologie, prime 1.00
    8610012: {"degats_direct": 902, "degats_duree": 747},   # warlock Destruction, prime 1.00
    8610016: {"degats_direct": 4886, "degats_duree": 587},   # druid Farouche, prime 3.00
    8610017: {"degats_direct": 4886, "degats_duree": 587},   # druid Farouche, prime 3.00
    8610018: {"degats_direct": 4886, "degats_duree": 587},   # druid Farouche, prime 3.00
    8610019: {"soin_direct": 6766, "soin_duree": 558},   # druid Restauration, prime 3.00
    8610020: {"degats_direct": 533, "degats_duree": 177},   # druid Équilibre, prime 1.00
    8610032: {"degats_direct": 533, "degats_duree": 177},   # druid Équilibre, prime 1.00
    8610033: {"degats_direct": 533, "degats_duree": 177},   # druid Équilibre, prime 1.00
    8610029: {"degats_direct": 533, "degats_duree": 710},   # druid Équilibre, prime 1.00
    8610030: {"degats_direct": 533, "degats_duree": 710},   # druid Équilibre, prime 1.00
    8610034: {"degats_direct": 533, "degats_duree": 177},   # druid Équilibre, prime 1.00
    8610035: {"degats_direct": 533, "degats_duree": 177},   # druid Équilibre, prime 1.00
    8610031: {"degats_direct": 533, "degats_duree": 591},   # druid Équilibre, prime 1.00
    8610036: {"soin_direct": 10148, "soin_duree": 6692, "soin_duree_tic": 558},   # druid Restauration, prime 4.50
    8610026: {"degats_direct": 5700, "degats_duree": 2741, "degats_duree_tic": 457},   # druid Farouche, prime 3.50
    8610027: {"degats_direct": 1629, "degats_duree": 783},   # druid Farouche, prime 1.00
    8610028: {"degats_direct": 1629, "degats_duree": 196},   # druid Farouche, prime 1.00
    8600091: {"degats_direct": 3800, "degats_duree": 685},   # druid Farouche, prime 3.50
    8600092: {"degats_direct": 1598, "degats_duree": 532},   # druid Équilibre, prime 3.00
    8600093: {"soin_direct": 3383, "soin_duree": 279},   # druid Restauration, prime 4.50
    8600055: {"degats_direct": 2775, "degats_duree": 160},   # warrior Armes, prime 3.83
    8600056: {"degats_direct": 4533, "degats_duree": 552},   # mage Feu, prime 3.50
    8600057: {"degats_direct": 1925, "degats_duree": 2947, "degats_duree_tic": 368},   # mage Feu, prime 3.50
    8600094: {"soin_duree": 29838, "soin_duree_tic": 1989},   # hunter Maîtrise des bêtes, prime 5.17
    8600095: {"soin_duree": 11550},   # hunter Maîtrise des bêtes, prime 1.00
    8600096: {"degats_direct": 2105, "degats_duree": 2189},   # hunter Précision, prime 3.08
    8600098: {"degats_direct": 2105, "degats_duree": 410},   # hunter Précision, prime 3.08
    8600059: {"degats_direct": 412, "soin_direct": 2145},   # priest Discipline, prime 1.00
    8600044: {"degats_direct": 1438, "soin_direct": 7611, "degats_duree": 141, "soin_duree": 2647},   # priest Sacré, prime 3.42
    8600045: {"degats_direct": 1438, "soin_direct": 7611, "degats_duree": 141, "soin_duree": 2647},   # priest Sacré, prime 3.42
    8600048: {"degats_direct": 676, "soin_direct": 1064, "degats_duree": 40},   # deathknight Impie, prime 1.00
}
