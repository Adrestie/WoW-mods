-- mod-papota-spherier : les creatures invoquees par les sorts de classe.
--
-- TOUTES A NOUS. L'audit a montre que les empruntees etaient des ennemis : la
-- goule 26125 est faction 14 — hostile a tous — et porte le script des pets de
-- chevalier ; le garde funeste 11859 est un demon en SmartAI ; le totem 3527
-- porte sa propre faction. On CLONE leurs templates — stats et modeles compris,
-- c'est tout l'interet du SELECT — en ne changeant que l'identite, la faction
-- et l'IA.
--
-- 803801  goule (Apocalypse)         IA npc_papota_invocation
-- 803802  garde funeste (Tyran)      IA npc_papota_invocation
-- 803803  totem de maree             immobile et intouchable, le soin vient du
--                                    sort (zone persistante), pas de lui

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (803801, 803802, 803803);
DELETE FROM `creature_template` WHERE `entry` IN (803801, 803802, 803803);

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 26125;
UPDATE `papota_clone` SET `entry` = 803801, `name` = 'Goule d''apocalypse',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 0,
    `AIName` = '', `ScriptName` = 'npc_papota_invocation';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 11859;
UPDATE `papota_clone` SET `entry` = 803802, `name` = 'Garde funeste du tyran',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 0,
    `AIName` = '', `ScriptName` = 'npc_papota_invocation';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 3527;
-- 768 = intouchable par joueurs et creatures : personne n'a a taper un totem
-- qui ne fait rien par lui-meme.
UPDATE `papota_clone` SET `entry` = 803803, `name` = 'Totem de maree de soins',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 768,
    `AIName` = 'NullCreatureAI', `ScriptName` = '';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
SELECT 803801, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`
FROM `creature_template_model` WHERE `CreatureID` = 26125;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
SELECT 803802, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`
FROM `creature_template_model` WHERE `CreatureID` = 11859;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
SELECT 803803, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`
FROM `creature_template_model` WHERE `CreatureID` = 3527;

-- ---------------------------------------------------------------------------
-- ETAT FINAL DES TROIS CREATURES (consolidation du 2026-09-06).
--
-- Trois fichiers plus tardifs les ont retouchees par UPDATE (goule 09_02_00,
-- totem de lien 09_03_00, tyran 09_03_01). Rejouer ce fichier-ci — l'updater
-- le fait des que son empreinte change — recreait les clones d'origine et
-- effacait ces retouches. Elles sont donc reprises ICI, a la suite, pour que
-- le fichier laisse toujours la base dans l'etat final. Les trois fichiers
-- tardifs restent tels quels : deja appliques, sans effet nouveau.
-- ---------------------------------------------------------------------------

-- 803801 la goule d'Apocalypse : IA npc_papota_goule, niveau 80, apparences
-- 802112-802115 (GeoBox elargi, gen_visuel_dk.py).
UPDATE `creature_template`
   SET `ScriptName` = 'npc_papota_goule',
       `minlevel` = 80, `maxlevel` = 80
 WHERE `entry` = 803801;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 803801;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803801, 0, 802112, 1, 1),
       (803801, 1, 802113, 1, 1),
       (803801, 2, 802114, 1, 1),
       (803801, 3, 802115, 1, 1);
DELETE FROM `creature_model_info`
 WHERE `DisplayID` IN (802112, 802113, 802114, 802115);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802112, 0.31, 1, 2, 0),
       (802113, 0.31, 1, 2, 0),
       (802114, 0.31, 1, 2, 0),
       (802115, 0.31, 1, 2, 0);

-- 803803 le totem : Totem de lien d'esprit (refonte du sort 8600063).
UPDATE `creature_template` SET `name` = 'Totem de lien d''esprit'
WHERE `entry` = 803803;

-- 803802 le tyran demoniaque : nom, IA npc_papota_tyran, apparence 802130,
-- nom francais, niveau 80, sans errance, PV x10.
UPDATE `creature_template`
SET `name` = 'Tyran demoniaque',
    `subname` = '',
    `ScriptName` = 'npc_papota_tyran',
    `minlevel` = 80,
    `maxlevel` = 80,
    `MovementType` = 0,
    `HealthModifier` = 13
WHERE `entry` = 803802;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 803802;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803802, 0, 802130, 1, 1);
DELETE FROM `creature_template_locale` WHERE `entry` = 803802 AND `locale` = 'frFR';
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`)
VALUES (803802, 'frFR', 'Tyran démoniaque', '');
