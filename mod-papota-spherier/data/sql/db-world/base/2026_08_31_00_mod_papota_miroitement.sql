-- mod-papota-spherier : la MARQUE du Miroitement (8600070, refonte en deux
-- temps du 2026-08-31).
--
-- Le premier lancer teleporte le mage et laisse cette creature au point de
-- depart ; un second lancer dans les 5 s l'y ramene. Habillage 802107 : la
-- rune bleue au sol NATIVE du client (World\Goober\G_RuneGroundBlue01.mdx,
-- posee dans les DBC par gen_visuel_mage.py — aucun fichier a injecter).
-- Clone du World Trigger 22515 comme les autres marqueurs : intouchable,
-- non selectionnable, SANS drapeau trigger (sinon les clients non-MJ ne
-- recoivent pas l'unite). Aucune IA : elle ne fait que se montrer.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803810;
DELETE FROM `creature_template` WHERE `entry` = 803810;

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `papota_clone` SET `entry` = 803810, `name` = 'Marque de miroitement',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = 'NullCreatureAI', `ScriptName` = '';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803810, 0, 802107, 1, 1);

-- Le coeur exige une ligne creature_model_info par displayid charge.
DELETE FROM `creature_model_info` WHERE `DisplayID` = 802107;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802107, 0.5, 0, 2, 0);
