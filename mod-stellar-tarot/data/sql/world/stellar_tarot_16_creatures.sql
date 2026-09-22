-- mod-stellar-tarot — the creatures the cards summon.
--
-- TWO GUARDIANS, cloned from native templates so that they carry a real model,
-- a real skeleton and real animations. What the clone changes is only what
-- makes it OURS: a friendly faction, no npcflag, no unit_flags, and the
-- module's own AI. Everything else -- level, health, display -- the AI sets at
-- summon time, from the master.
--
--   902650  the boar      (card 139, level 4)  cloned from Stonetusk Boar
--   902651  the double    (card 74, level 2)   cloned from a plain humanoid
--
-- A CREATURE ENTRY IS NOT AN ITEM ENTRY: these numbers live in their own id
-- space and cross nothing.
--
-- GENERATED ONCE, by hand: the workbook says nothing of creatures.

DROP TEMPORARY TABLE IF EXISTS `stellar_tarot_clone`;
CREATE TEMPORARY TABLE `stellar_tarot_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 113;
UPDATE `stellar_tarot_clone` SET `entry` = 902650, `name` = 'Sanglier du Tarot',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 0, `unit_flags2` = 0,
    `AIName` = '', `ScriptName` = 'npc_stellar_tarot_guardian',
    `minlevel` = 1, `maxlevel` = 1, `RegenHealth` = 0, `flags_extra` = 0;
DELETE FROM `creature_template` WHERE `entry` = 902650;
INSERT INTO `creature_template` SELECT * FROM `stellar_tarot_clone`;

DROP TEMPORARY TABLE IF EXISTS `stellar_tarot_clone`;
CREATE TEMPORARY TABLE `stellar_tarot_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 113;
UPDATE `stellar_tarot_clone` SET `entry` = 902651, `name` = 'Double du Tarot',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 0, `unit_flags2` = 0,
    `AIName` = '', `ScriptName` = 'npc_stellar_tarot_guardian',
    `minlevel` = 1, `maxlevel` = 1, `RegenHealth` = 0, `flags_extra` = 0;
DELETE FROM `creature_template` WHERE `entry` = 902651;
INSERT INTO `creature_template` SELECT * FROM `stellar_tarot_clone`;

DROP TEMPORARY TABLE IF EXISTS `stellar_tarot_clone`;

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (902650, 902651);
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 902650, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 0
    FROM `creature_template_model` WHERE `CreatureID` = 113;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 902651, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 0
    FROM `creature_template_model` WHERE `CreatureID` = 113;
