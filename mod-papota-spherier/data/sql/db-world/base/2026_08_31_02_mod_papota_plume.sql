-- mod-papota-spherier : la PLUME ANGELIQUE du pretre (8600040).
--
-- Une creature posee au sol, habillee du modele exporte (display 802108,
-- gen_visuel_pretre.py). Son IA (npc_papota_plume) donne le bienfait de
-- vitesse au premier allie qui la touche, puis la plume s'efface. Clone du
-- World Trigger 22515 comme les autres marqueurs : intouchable, non
-- selectionnable, SANS drapeau trigger (sinon les clients non-MJ ne
-- recoivent pas l'unite).

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803812;
DELETE FROM `creature_template` WHERE `entry` = 803812;

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `papota_clone` SET `entry` = 803812, `name` = 'Plume angelique',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = '', `ScriptName` = 'npc_papota_plume';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803812, 0, 802108, 1, 1);

-- Le coeur exige une ligne creature_model_info par displayid charge.
DELETE FROM `creature_model_info` WHERE `DisplayID` = 802108;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802108, 0.5, 0, 2, 0);
