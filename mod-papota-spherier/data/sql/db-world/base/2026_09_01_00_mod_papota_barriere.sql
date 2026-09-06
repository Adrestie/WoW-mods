-- mod-papota-spherier : le DOME de Mot de pouvoir : Barriere (8600042).
--
-- Une creature posee au reticule, habillee du dome exporte (display 802109,
-- gen_visuel_pretre.py). Son IA (npc_papota_barriere) tient LA RESERVE
-- D'ABSORPTION COMMUNE et distribue la protection aux allies presents dans
-- les 15 m — le partage d'un meme pot, a la maniere du Bouclier anti-magie
-- mais pour tous les degats et pour tout le groupe. Clone du World Trigger
-- 22515 : intouchable, non selectionnable, SANS drapeau trigger (sinon les
-- clients non-MJ ne recoivent pas l'unite).

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803813;
DELETE FROM `creature_template` WHERE `entry` = 803813;

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `papota_clone` SET `entry` = 803813, `name` = 'Barriere',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = '', `ScriptName` = 'npc_papota_barriere';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803813, 0, 802109, 1, 1);

-- Le coeur exige une ligne creature_model_info par displayid charge.
DELETE FROM `creature_model_info` WHERE `DisplayID` = 802109;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802109, 0.5, 0, 2, 0);
