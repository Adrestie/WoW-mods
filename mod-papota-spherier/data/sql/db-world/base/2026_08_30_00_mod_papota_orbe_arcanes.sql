-- mod-papota-spherier : l'ORBE DES ARCANES (8600071, refonte du 2026-08-30).
--
-- Le sort invoque cette creature VISIBLE, habillee du modele de l'orbe
-- (display 802103, gen_visuel_mage.py) ; son IA (npc_papota_orbe_arcanes,
-- SpherierSorts.cpp) la fait filer droit devant sur 40 m et frappe chaque
-- ennemi croise une fois. Clone du World Trigger 22515 comme l'ancre 803804 :
-- intouchable, non selectionnable, SANS drapeau trigger (sinon les clients
-- non-MJ ne recoivent pas l'unite).

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803806;
DELETE FROM `creature_template` WHERE `entry` = 803806;

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `papota_clone` SET `entry` = 803806, `name` = 'Orbe des arcanes',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = '',
    `ScriptName` = 'npc_papota_orbe_arcanes';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803806, 0, 802103, 1, 1);

-- Le coeur exige une ligne creature_model_info par displayid charge.
DELETE FROM `creature_model_info` WHERE `DisplayID` = 802103;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802103, 0.5, 0, 2, 0);
