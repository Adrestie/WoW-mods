-- mod-papota-spherier : les DEUX ANNEAUX du Halo (8600043).
--
-- Le sort se joue en deux temps autour de la position du lanceur au moment
-- du lancer : l'anneau s'ouvre (803814, display 802110, modele
-- cfx_priest_halo_cast02), puis trois secondes plus tard il se referme
-- (803815, display 802111, modele cfx_priest_halo_cast). Deux entrees et un
-- seul modele chacune : le changement d'habillage se fait par l'invocation.
-- Leur IA (npc_papota_halo) fait PASSER L'ONDE au rythme de l'anneau, chaque
-- cible etant touchee a l'instant ou le front l'atteint (2026-09-01) ; elle
-- distingue les deux temps a l'entree. Clone du World Trigger 22515, comme le dome de
-- la Barriere : intouchable, non selectionnable, SANS drapeau trigger (sinon
-- les clients non-MJ ne recoivent pas l'unite).

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (803814, 803815);
DELETE FROM `creature_template` WHERE `entry` IN (803814, 803815);

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `papota_clone` SET `entry` = 803814, `name` = 'Halo',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = '', `ScriptName` = 'npc_papota_halo';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
UPDATE `papota_clone` SET `entry` = 803815;
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803814, 0, 802110, 1, 1),
       (803815, 0, 802111, 1, 1);

-- Le coeur exige une ligne creature_model_info par displayid charge.
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (802110, 802111);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802110, 0.5, 0, 2, 0),
       (802111, 0.5, 0, 2, 0);
