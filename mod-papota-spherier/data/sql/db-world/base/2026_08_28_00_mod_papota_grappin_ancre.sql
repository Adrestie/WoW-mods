-- mod-papota-spherier : le dummy du DASH FUMEE (ex-ancre du grappin).
--
-- Pivot du 2026-08-29 : le grappin est abandonne, le sort 8600030 est un
-- dash — le script invoque ce dummy INVISIBLE au point vise et le
-- personnage le charge, masque par la fumee (SpherierSorts.cpp). Clone du
-- World Trigger 22515, intouchable, non selectionnable, SANS drapeau
-- trigger (sinon les clients non-MJ ne recoivent pas l'unite), habille du
-- display 802102 — opacite 0, invisible pour tous (gen_visuel_voleur.py ;
-- le modele trigger nu 11686 rend une silhouette blanche, constate en jeu).
-- Le display 802101 (crochet plante) reste pose dans les DBC, dormant.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803804;
DELETE FROM `creature_template` WHERE `entry` = 803804;

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `papota_clone` SET `entry` = 803804, `name` = 'Ancre de grappin',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = 'NullCreatureAI', `ScriptName` = '';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803804, 0, 802102, 1, 1);

-- Le coeur exige une ligne creature_model_info par displayid charge.
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (802101, 802102);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802101, 0.5, 0, 2, 0), (802102, 0.5, 0, 2, 0);

-- L'ancien crochet volant (803805), retire avec le projectile du grappin.
DELETE FROM `creature_template_model` WHERE `CreatureID` = 803805;
DELETE FROM `creature_template` WHERE `entry` = 803805;
