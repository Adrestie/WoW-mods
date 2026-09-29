-- Equilibrage des armes custom par courbes de progression (ilvl 200-284, PvP exclu).
-- Cible : puissance = 1,25 x celle de l'ilvl 284 de la meme typologie (mains, role).
-- Degats a l'echelle du dps cible, vitesse conservee ; puissance des sorts lue sur la courbe ;
-- autres statistiques a l'echelle du budget cible, proportions conservees.
-- Indice P = budget + 8.25 x dps + puissance des sorts.   NON EXECUTE.

-- 801002 Ezh’ra, Voix du Tonnerre : dps 211 -> 296, budget 780 -> 796, puissance -1 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 733, `dmg_max1` = 1341, `stat_value1` = 251, `stat_value2` = 284, `stat_value3` = 100, `stat_value4` = 67, `stat_value5` = 94, `stat_value6` = 1134 WHERE `entry` = 801002;
-- 801003 Nairūn, Souffle des Anciens : dps 194 -> 191, budget 399 -> 377, puissance +22 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 375, `dmg_max1` = 618, `stat_value1` = 117, `stat_value2` = 112, `stat_value3` = 83, `stat_value4` = 65, `stat_value5` = 1138 WHERE `entry` = 801003;
-- 801005 Drokhan, Poing des Tempêtes : dps 281 -> 327, budget 508 -> 415, puissance +14 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 623, `dmg_max1` = 1076, `stat_value1` = 105, `stat_value2` = 105, `stat_value3` = 122, `stat_value4` = 55, `stat_value5` = 51, `stat_value6` = 11, `stat_value7` = 27 WHERE `entry` = 801005;
-- 801006 Mak'hor, Frappe des Esprits : dps 281 -> 327, budget 827 -> 416, puissance +26 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 611, `dmg_max1` = 1088, `stat_value1` = 38, `stat_value2` = 15, `stat_value3` = 40, `stat_value4` = 18, `stat_value5` = 24, `stat_value6` = 25, `stat_value7` = 60, `stat_value8` = 226 WHERE `entry` = 801006;
-- 801007 Kael’Thorr, Hurlement Sanglant : dps 362 -> 387, budget 1053 -> 844, puissance +25 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 779, `dmg_max1` = 1390, `stat_value1` = 199, `stat_value2` = 223, `stat_value3` = 92, `stat_value4` = 60, `stat_value5` = 53, `stat_value6` = 298, `stat_value7` = 68 WHERE `entry` = 801007;
-- 801008 Xer’thul, Maître des Chaînes : dps 208 -> 296, budget 737 -> 796, puissance -1 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 924, `dmg_max1` = 1209, `stat_value1` = 268, `stat_value2` = 230, `stat_value3` = 78, `stat_value4` = 124, `stat_value5` = 96, `stat_value6` = 1134 WHERE `entry` = 801008;
-- 801009 Varkhal, Lame du Silence Glacé : dps 281 -> 327, budget 524 -> 416, puissance +14 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 623, `dmg_max1` = 1076, `stat_value1` = 98, `stat_value2` = 105, `stat_value3` = 46, `stat_value4` = 64, `stat_value5` = 121, `stat_value6` = 42 WHERE `entry` = 801009;
-- 801010 Skorrn, Morsure de l’Hiver Noir : dps 281 -> 327, budget 450 -> 416, puissance +11 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 623, `dmg_max1` = 1076, `stat_value1` = 89, `stat_value2` = 96, `stat_value3` = 45, `stat_value4` = 78, `stat_value5` = 23, `stat_value6` = 170 WHERE `entry` = 801010;
-- 801011 Vorthalak, Fléau des Vivants : dps 346 -> 425, budget 1056 -> 882, puissance +11 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 1178, `dmg_max1` = 1884, `stat_value1` = 252, `stat_value2` = 232, `stat_value3` = 105, `stat_value4` = 68, `stat_value5` = 44, `stat_value6` = 26, `stat_value7` = 185, `stat_value8` = 63 WHERE `entry` = 801011;
-- 801012 Drethmâr, Trône de Sang : dps 309 -> 425, budget 1101 -> 883, puissance +4 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 1163, `dmg_max1` = 1899, `stat_value1` = 173, `stat_value2` = 301, `stat_value3` = 71, `stat_value4` = 74, `stat_value5` = 36, `stat_value6` = 362, `stat_value7` = 47 WHERE `entry` = 801012;
-- 801013 Elun'dor, Voix des Cieux Silencieux : dps 208 -> 296, budget 1126 -> 797, puissance +33 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 924, `dmg_max1` = 1209, `stat_value1` = 212, `stat_value2` = 248, `stat_value3` = 163, `stat_value4` = 81, `stat_value5` = 93, `stat_value6` = 1134 WHERE `entry` = 801013;
-- 801014 Liora, Berceuse des Racines : dps 208 -> 312, budget 1258 -> 792, puissance +33 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 974, `dmg_max1` = 1274, `stat_value1` = 189, `stat_value2` = 126, `stat_value3` = 220, `stat_value4` = 72, `stat_value5` = 83, `stat_value6` = 1125, `stat_value7` = 41 WHERE `entry` = 801014;
-- 801015 Tharnok, Échine du Monde : dps 309 -> 425, budget 1402 -> 884, puissance +12 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 1163, `dmg_max1` = 1899, `stat_value1` = 189, `stat_value2` = 220, `stat_value3` = 79, `stat_value4` = 86, `stat_value5` = 86, `stat_value6` = 145, `stat_value7` = 157 WHERE `entry` = 801015;
-- 801016 Brakk, Fracture Totale : dps 346 -> 425, budget 1626 -> 882, puissance +28 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 1178, `dmg_max1` = 1884, `stat_value1` = 163, `stat_value2` = 190, `stat_value3` = 125, `stat_value4` = 62, `stat_value5` = 71, `stat_value6` = 54, `stat_value7` = 271, `stat_value8` = 81 WHERE `entry` = 801016;
-- 801017 Drakthor, Le Brise-Écaille : dps 238 -> 325, budget 844 -> 445, puissance +12 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 622, `dmg_max1` = 1069, `stat_value1` = 105, `stat_value2` = 132, `stat_value3` = 24, `stat_value4` = 43, `stat_value5` = 43, `stat_value6` = 32, `stat_value7` = 132 WHERE `entry` = 801017;
-- 801019 Vaelthis, Brise-sortilège : dps 208 -> 296, budget 1126 -> 797, puissance +33 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 924, `dmg_max1` = 1209, `stat_value1` = 212, `stat_value2` = 248, `stat_value3` = 163, `stat_value4` = 81, `stat_value5` = 93, `stat_value6` = 1134 WHERE `entry` = 801019;
-- 801020 Ashbringer, Fléau des morts : dps 346 -> 425, budget 1626 -> 882, puissance +28 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 1178, `dmg_max1` = 1884, `stat_value1` = 163, `stat_value2` = 190, `stat_value3` = 125, `stat_value4` = 62, `stat_value5` = 71, `stat_value6` = 54, `stat_value7` = 271, `stat_value8` = 81 WHERE `entry` = 801020;
-- 801021 Vindictus, Châtiment-ardent : dps 238 -> 325, budget 1120 -> 444, puissance +23 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 622, `dmg_max1` = 1069, `stat_value1` = 79, `stat_value2` = 99, `stat_value3` = 69, `stat_value4` = 18, `stat_value5` = 33, `stat_value6` = 33, `stat_value7` = 30, `stat_value8` = 24, `stat_value9` = 119 WHERE `entry` = 801021;
-- 801023 Solareth,  Souffle-de-vie : dps 194 -> 191, budget 756 -> 376, puissance +36 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 375, `dmg_max1` = 618, `stat_value1` = 100, `stat_value2` = 125, `stat_value3` = 33, `stat_value4` = 38, `stat_value5` = 1138, `stat_value6` = 32 WHERE `entry` = 801023;
-- 801025 Sha'haggul, Voix des tourments : dps 208 -> 296, budget 1126 -> 797, puissance +33 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 924, `dmg_max1` = 1209, `stat_value1` = 212, `stat_value2` = 248, `stat_value3` = 163, `stat_value4` = 81, `stat_value5` = 93, `stat_value6` = 1134 WHERE `entry` = 801025;
-- 801026 Luminaris, Bénédiction éternelle : dps 208 -> 312, budget 1058 -> 794, puissance +27 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 974, `dmg_max1` = 1274, `stat_value1` = 225, `stat_value2` = 262, `stat_value3` = 86, `stat_value4` = 98, `stat_value5` = 1125, `stat_value6` = 49 WHERE `entry` = 801026;
-- 801027 Sanguineus, la silencieuse : dps 281 -> 327, budget 918 -> 415, puissance +30 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 623, `dmg_max1` = 1076, `stat_value1` = 91, `stat_value2` = 113, `stat_value3` = 79, `stat_value4` = 30, `stat_value5` = 34, `stat_value6` = 136 WHERE `entry` = 801027;
-- 801028 Carnifex, la pernicieuse : dps 281 -> 327, budget 610 -> 415, puissance +18 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 623, `dmg_max1` = 1076, `stat_value1` = 68, `stat_value2` = 68, `stat_value3` = 37, `stat_value4` = 33, `stat_value5` = 39, `stat_value6` = 102, `stat_value7` = 68 WHERE `entry` = 801028;
-- 801029 Shuor'ror, Crépuscule du savoir : dps 281 -> 327, budget 1018 -> 415, puissance +34 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 623, `dmg_max1` = 1076, `stat_value1` = 82, `stat_value2` = 102, `stat_value3` = 71, `stat_value4` = 27, `stat_value5` = 31, `stat_value6` = 204 WHERE `entry` = 801029;
-- 801030 Shuadslayern, Aube de l'oubli : dps 281 -> 327, budget 610 -> 415, puissance +18 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 623, `dmg_max1` = 1076, `stat_value1` = 68, `stat_value2` = 68, `stat_value3` = 37, `stat_value4` = 33, `stat_value5` = 39, `stat_value6` = 102, `stat_value7` = 68 WHERE `entry` = 801030;
-- 801031 Vorgath, plaie des dragons : dps 346 -> 425, budget 1626 -> 882, puissance +28 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 1178, `dmg_max1` = 1884, `stat_value1` = 163, `stat_value2` = 190, `stat_value3` = 125, `stat_value4` = 62, `stat_value5` = 71, `stat_value6` = 54, `stat_value7` = 271, `stat_value8` = 81 WHERE `entry` = 801031;
-- 801032 Draemorr, Brise-Monde : dps 346 -> 425, budget 1626 -> 882, puissance +28 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 1178, `dmg_max1` = 1884, `stat_value1` = 163, `stat_value2` = 190, `stat_value3` = 125, `stat_value4` = 62, `stat_value5` = 71, `stat_value6` = 54, `stat_value7` = 271, `stat_value8` = 81 WHERE `entry` = 801032;
-- 801034 Crocs-de-Sang l'Écorcheur : dps 346 -> 425, budget 1626 -> 882, puissance +28 % -> +25 %
UPDATE `item_template` SET `dmg_min1` = 1178, `dmg_max1` = 1884, `stat_value1` = 163, `stat_value2` = 190, `stat_value3` = 125, `stat_value4` = 62, `stat_value5` = 71, `stat_value6` = 54, `stat_value7` = 271, `stat_value8` = 81 WHERE `entry` = 801034;
