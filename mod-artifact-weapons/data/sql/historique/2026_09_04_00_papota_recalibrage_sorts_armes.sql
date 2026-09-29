-- Recalibrage des montants de sorts d'armes (cibles utilisateur du 2026-09-04).
-- Base retouchee en priorite ; le ratio ne bouge que quand la base seule
-- ne peut pas atteindre la fourchette. Estimations pour un personnage
-- full stuff ICC 25 HM : puissance des sorts 3039, PA plaque 4448, PA cuir 4136.

-- 8020100 Grondement d'Ezh'ra : 3267-3484 -> 2800-3099 (cible 2800-3100)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 1064, `EffectDieSides_1` = 300 WHERE `ID` = 8020100;
-- 8020200 Ascension d'Ezh'ra : 664-707 -> 451-550 (cible 450-550)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 222, `EffectDieSides_1` = 100 WHERE `ID` = 8020200;
-- 8030110 Chaine de soins des Anciens : 5136-5286 -> 3154-3247 (cible 3100-3300)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 646, `EffectDieSides_1` = 94 WHERE `ID` = 8030110;
-- 8030120 Vague de soins des Anciens : 5253-5901 -> 2800-3099 (cible 2800-3100)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 2097, `EffectDieSides_1` = 300 WHERE `ID` = 8030120;
-- 8040110 Voile des Esprits : 222-224 -> 301-350 (cible 300-350)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 174, `EffectDieSides_1` = 50 WHERE `ID` = 8040110;
-- 8060100 Rage de Mak'hor (tick) : 221-223 -> 251-275 (cible 250-275)
UPDATE `spell_dbc` SET `EffectBasePoints_2` = 174, `EffectDieSides_2` = 25 WHERE `ID` = 8060100;
-- 8080211 Corruption de Xer'Thul (tick) : 6940-6940 -> 5990-6040 (cible 5950-6050)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 115, `EffectDieSides_1` = 2 WHERE `ID` = 8080211;
-- 8080212 Immolation de Xer'Thul (tick) : 6076-6076 -> 4976-5026 (cible 4950-5050)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 95, `EffectDieSides_1` = 2 WHERE `ID` = 8080212;
-- 8090210 Hiver Noir : 4691-4822 -> 2801-3200 (cible 2800-3200)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 1910, `EffectDieSides_1` = 400 WHERE `ID` = 8090210;
-- 8110100 Rune de Vorthalak (tick) : 645-699 -> 501-600 (cible 500-600)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 393, `EffectDieSides_1` = 100 WHERE `ID` = 8110100;
-- 8110210 Fievre de givre necrotique : 1893-1893 -> 950-950 (cible 900-1000)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 6, `EffectDieSides_1` = 1 WHERE `ID` = 8110210;
-- 8110220 Peste necrotique : 884-884 -> 759-884 (cible 700-900)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 5, `EffectDieSides_1` = 2 WHERE `ID` = 8110220;
-- 8120110 Poigne du Trone de sang : 1868-1999 -> 700-799 (cible 700-800)
UPDATE `spell_dbc` SET `EffectBasePoints_2` = 32, `EffectDieSides_2` = 100 WHERE `ID` = 8120110;
-- 8130120 Eclat lunaire d'Elun'Dor : 767-872 -> 500-599 (cible 500-600)
UPDATE `spell_dbc` SET `EffectBasePoints_2` = 341, `EffectDieSides_2` = 100 WHERE `ID` = 8130120;
-- 8130130 Rayon de Soleil : 767-872 -> 500-599 (cible 500-600)
UPDATE `spell_dbc` SET `EffectBasePoints_2` = 341, `EffectDieSides_2` = 100 WHERE `ID` = 8130130;
-- 8200200 Epee de justice : 20824-22883 -> 6000-6999 (cible 6000-7000)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 4876, `EffectDieSides_1` = 1000 WHERE `ID` = 8200200;
-- 8210100 Bouclier du Seraphin : 1925-2171 -> 800-899 (cible 800-900)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 275, `EffectDieSides_1` = 100 WHERE `ID` = 8210100;
-- 8250210 Missile des Ombres : 8279-8941 -> 6001-7000 (cible 6000-7000)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 4697, `EffectDieSides_1` = 1000 WHERE `ID` = 8250210;
-- 8340200 Ecorchement : 5768-6287 -> 3000-3999 (cible 3000-4000)
UPDATE `spell_dbc` SET `EffectBasePoints_1` = 2172, `EffectDieSides_1` = 1000 WHERE `ID` = 8340200;
-- ratio rabattu : direct_bonus 1.3428 -> 0.8248 (Chaine de soins des Anciens)
UPDATE `spell_bonus_data` SET `direct_bonus` = 0.8248 WHERE `entry` = 8030110;
-- ratio rabattu : ap_dot_bonus 0.0040 -> 0.0169 (Fievre de givre necrotique)
UPDATE `spell_bonus_data` SET `ap_dot_bonus` = 0.0169 WHERE `entry` = 8110210;
