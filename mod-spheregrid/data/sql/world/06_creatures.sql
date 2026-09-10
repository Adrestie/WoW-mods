-- mod-spheregrid — The creatures and game objects the spells summon or place.
--
-- Regenerable: every block deletes its own range before writing it
-- again, so the file may be replayed at will.

-- ------------------------------------------------------------------
-- The guardian
-- ------------------------------------------------------------------
-- Nothing is created here any more: 803800 is a creature the module no
-- longer summons, and its rows are cleared so that replaying the file
-- leaves nothing of it behind.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803800;
DELETE FROM `creature_template` WHERE `entry` = 803800;

-- ------------------------------------------------------------------
-- The summons
-- ------------------------------------------------------------------
-- Our own creatures, cloned from native ones. The borrowed templates were
-- enemies: hostile factions and scripts of their own. The clones take their
-- models and their figures without their past: faction 35, friendly to
-- everyone, no npc flag, and an AI of our own.
--
--   803801  ghoul (Apocalypse)       AI npc_spheregrid_summon
--   803802  dreadguard (Tyrant)      AI npc_spheregrid_summon
--   803803  healing tide totem       a prop, NullCreatureAI

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (803801, 803802, 803803);
DELETE FROM `creature_template` WHERE `entry` IN (803801, 803802, 803803);

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 26125;
UPDATE `spheregrid_clone` SET `entry` = 803801, `name` = 'Goule d''apocalypse',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 0,
    `AIName` = '', `ScriptName` = 'npc_spheregrid_summon';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 11859;
UPDATE `spheregrid_clone` SET `entry` = 803802, `name` = 'Garde funeste du tyran',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 0,
    `AIName` = '', `ScriptName` = 'npc_spheregrid_summon';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 3527;
UPDATE `spheregrid_clone` SET `entry` = 803803, `name` = 'Totem de maree de soins',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 768,
    `AIName` = 'NullCreatureAI', `ScriptName` = '';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;

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

-- THE DREADGUARD WEARS A DISPLAY OF THE MODULE'S OWN, and a display the core
-- knows nothing of has neither a bounding radius nor a combat reach: it says
-- so at every start ("No model data exist for CreatureDisplayID"), the
-- creature collides with nothing and nothing reaches it at the right
-- distance. The figures are those of display 1912, the one creature 11859
-- wears -- the creature this one is cloned from.
DELETE FROM `creature_model_info` WHERE `DisplayID` = 802130;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802130, 0.9168, 1.8, 0, 0);

-- ---------------------------------------------------------------------------
-- WHAT CAME LATER. What follows was added after the blocks above and repeats
-- some of them. Replayed in order it makes no difference: the later rows are
-- already applied, and applying them again changes nothing.
-- ---------------------------------------------------------------------------

-- Displays 802112-802115: the ghoul's four models, on a widened bounding box.
UPDATE `creature_template`
   SET `ScriptName` = 'npc_spheregrid_ghoul',
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

UPDATE `creature_template` SET `name` = 'Totem de lien d''esprit'
WHERE `entry` = 803803;

-- Level 80, no wandering, and thirteen times the base health.
UPDATE `creature_template`
SET `name` = 'Tyran demoniaque',
    `subname` = '',
    `ScriptName` = 'npc_spheregrid_tyrant',
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

-- ------------------------------------------------------------------
-- The grapple anchor
-- ------------------------------------------------------------------
-- Cloned from World Trigger 22515: untouchable, unselectable, and with its
-- extra flags cleared. A mark the grapple flies to, and nothing else.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803804;
DELETE FROM `creature_template` WHERE `entry` = 803804;

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `spheregrid_clone` SET `entry` = 803804, `name` = 'Ancre de grappin',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = 'NullCreatureAI', `ScriptName` = '';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803804, 0, 802102, 1, 1);

DELETE FROM `creature_model_info` WHERE `DisplayID` IN (802101, 802102);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802101, 0.5, 0, 2, 0), (802102, 0.5, 0, 2, 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803805;
DELETE FROM `creature_template` WHERE `entry` = 803805;

-- ------------------------------------------------------------------
-- The arcane orb
-- ------------------------------------------------------------------
-- A trigger cloned from 22515, wearing display 802103 -- a model the module
-- ships -- and driven by npc_spheregrid_arcane_orb.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803806;
DELETE FROM `creature_template` WHERE `entry` = 803806;

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `spheregrid_clone` SET `entry` = 803806, `name` = 'Orbe des arcanes',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = '',
    `ScriptName` = 'npc_spheregrid_arcane_orb';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803806, 0, 802158, 1, 1);

-- The orb is a prop that flies and strikes: the same figures as the module's
-- other props, which touch nothing themselves.
DELETE FROM `creature_model_info` WHERE `DisplayID` = 802158;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802158, 0.5, 0, 2, 0);

DELETE FROM `creature_model_info` WHERE `DisplayID` = 802103;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802103, 0.5, 0, 2, 0);

-- ------------------------------------------------------------------
-- The meteor
-- ------------------------------------------------------------------
-- Nothing is created here. The meteor went back to its DBC form -- a ground
-- area and a burn, on a visual borrowed from 2253 -- so its creatures and its
-- displays are only cleared.

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (803807, 803808, 803809);
DELETE FROM `creature_template` WHERE `entry` IN (803807, 803808, 803809);
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (802104, 802105, 802106);

-- ------------------------------------------------------------------
-- The shimmer marker
-- ------------------------------------------------------------------
-- The mark the shimmer leaves behind: a trigger, unselectable, with no AI.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803810;
DELETE FROM `creature_template` WHERE `entry` = 803810;

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `spheregrid_clone` SET `entry` = 803810, `name` = 'Marque de miroitement',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = 'NullCreatureAI', `ScriptName` = '';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803810, 0, 802107, 1, 1);

DELETE FROM `creature_model_info` WHERE `DisplayID` = 802107;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802107, 0.5, 0, 2, 0);

-- ------------------------------------------------------------------
-- The pack beast
-- ------------------------------------------------------------------
-- Unlike the props, it fights: a level, a class and a running speed of its
-- own, driven by npc_spheregrid_pack.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803811;
DELETE FROM `creature_template` WHERE `entry` = 803811;

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
UPDATE `spheregrid_clone` SET `entry` = 803811, `name` = 'Bete de meute',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 0,
    `flags_extra` = 0, `AIName` = '',
    `ScriptName` = 'npc_spheregrid_pack',
    `minlevel` = 80, `maxlevel` = 80, `unit_class` = 1, `speed_run` = 1.2;
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803811, 0, 802102, 1, 1);

-- ------------------------------------------------------------------
-- The angelic feather
-- ------------------------------------------------------------------
-- Laid on the ground and waiting to be walked over: a trigger, unselectable,
-- driven by npc_spheregrid_feather.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803812;
DELETE FROM `creature_template` WHERE `entry` = 803812;

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `spheregrid_clone` SET `entry` = 803812, `name` = 'Plume angelique',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = '', `ScriptName` = 'npc_spheregrid_feather';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803812, 0, 802108, 1, 1);

DELETE FROM `creature_model_info` WHERE `DisplayID` = 802108;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802108, 0.5, 0, 2, 0);

-- ------------------------------------------------------------------
-- The barrier
-- ------------------------------------------------------------------
-- A trigger, unselectable, driven by npc_spheregrid_barrier.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803813;
DELETE FROM `creature_template` WHERE `entry` = 803813;

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `spheregrid_clone` SET `entry` = 803813, `name` = 'Barriere',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = '', `ScriptName` = 'npc_spheregrid_barrier';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803813, 0, 802109, 1, 1);

DELETE FROM `creature_model_info` WHERE `DisplayID` = 802109;
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802109, 0.5, 0, 2, 0);

-- ------------------------------------------------------------------
-- The halo
-- ------------------------------------------------------------------
-- Two of them, one per display -- the halo grows and shrinks -- and both are
-- driven by npc_spheregrid_halo.

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (803814, 803815);
DELETE FROM `creature_template` WHERE `entry` IN (803814, 803815);

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `spheregrid_clone` SET `entry` = 803814, `name` = 'Halo',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = '', `ScriptName` = 'npc_spheregrid_halo';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
UPDATE `spheregrid_clone` SET `entry` = 803815;
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803814, 0, 802110, 1, 1),
       (803815, 0, 802111, 1, 1);

DELETE FROM `creature_model_info` WHERE `DisplayID` IN (802110, 802111);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802110, 0.5, 0, 2, 0),
       (802111, 0.5, 0, 2, 0);

-- ------------------------------------------------------------------
-- The gates
-- ------------------------------------------------------------------
-- The gate is a game object of the "spell caster" type, the only one verified in
-- game to hand a right click to the module. Its data fields carry: the native
-- spell it points at, unlimited charges (the gate holds its own duration), and
-- "party only", so that the owner and his group alone may click it.
--
-- Going through one gate carries the player to the other. Only 803820 is
-- created here: the pair is placed by the module itself, and 803821 is only
-- cleared.

DELETE FROM `gameobject_template` WHERE `entry` IN (803820, 803821);

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone_go`;
CREATE TEMPORARY TABLE `spheregrid_clone_go` AS
    SELECT * FROM `gameobject_template` WHERE `entry` = 190942;
-- THE DISPLAY IS THE MODULE'S OWN. It used to be 8500, one of the game's --
-- a Dalaran chair -- which the client it grew up in had quietly rewritten into
-- a portal. A module cannot do that: the row is copied into
-- spheregrid_GameObjectDisplayInfo.dbc under 802100, and the gate wears that.
UPDATE `spheregrid_clone_go` SET `entry` = 803820, `name` = 'Tunnel de la mort',
    `type` = 22, `displayId` = 802100, `size` = 0.08,
    `Data0` = 52751, `Data1` = 0, `Data2` = 1,
    `ScriptName` = 'go_spheregrid_gate';
INSERT INTO `gameobject_template` SELECT * FROM `spheregrid_clone_go`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone_go`;

-- ------------------------------------------------------------------
-- The ghoul
-- ------------------------------------------------------------------
-- The ghoul again, with the four models the module ships and its own script,
-- which is what shows its damage to the player.

UPDATE `creature_template`
   SET `ScriptName` = 'npc_spheregrid_ghoul',
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

-- ------------------------------------------------------------------
-- The spirit link totem
-- ------------------------------------------------------------------
-- Its name only. 10_names.sql has the last word on it, in English.
UPDATE `creature_template` SET `name` = 'Totem de lien d''esprit'
WHERE `entry` = 803803;

-- ------------------------------------------------------------------
-- The demonic tyrant
-- ------------------------------------------------------------------
-- Its script, its display, and its French name in the locale table.

UPDATE `creature_template`
SET `name` = 'Tyran demoniaque',
    `subname` = '',
    `ScriptName` = 'npc_spheregrid_tyrant'
WHERE `entry` = 803802;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803802;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803802, 0, 802130, 1, 1);

DELETE FROM `creature_template_locale` WHERE `entry` = 803802 AND `locale` = 'frFR';
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`)
VALUES (803802, 'frFR', 'Tyran démoniaque', '');

-- basehp2 = 12 600 at level 80 (creature_classlevelstats, exp = 2), which
-- gives 163 800 health, against 5 790 before at level 57.
UPDATE `creature_template`
SET `minlevel` = 80,
    `maxlevel` = 80,
    `MovementType` = 0,
    `HealthModifier` = 13
WHERE `entry` = 803802;

-- ------------------------------------------------------------------
-- The star
-- ------------------------------------------------------------------
-- Two triggers -- the star itself and the point it departs from -- used by
-- Stellar Return (8610020).

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (803816, 803817);
DELETE FROM `creature_template` WHERE `entry` IN (803816, 803817);

DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;
CREATE TEMPORARY TABLE `spheregrid_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `spheregrid_clone` SET `entry` = 803816, `name` = 'Etoile',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = 'NullCreatureAI', `ScriptName` = '';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
UPDATE `spheregrid_clone` SET `entry` = 803817, `name` = 'Depart stellaire';
INSERT INTO `creature_template` SELECT * FROM `spheregrid_clone`;
DROP TEMPORARY TABLE IF EXISTS `spheregrid_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803816, 0, 802105, 1, 1),
       (803817, 0, 802106, 1, 1);

-- The figures of display 16925, the second of the two creature 22515 wears --
-- the creature both of these are cloned from.
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (802105, 802106);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802105, 0.5, 1, 2, 0),
       (802106, 0.5, 1, 2, 0);

DELETE FROM `creature_template_locale`
    WHERE `entry` IN (803816, 803817) AND `locale` = 'frFR';
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`)
VALUES (803816, 'frFR', 'Étoile', ''),
       (803817, 'frFR', 'Départ stellaire', '');

