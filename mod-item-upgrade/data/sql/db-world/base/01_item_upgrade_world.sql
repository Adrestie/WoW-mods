-- ---------------------------------------------------------------------------
-- mod-item-upgrade : the power tokens (WORLD database)
--
-- 1. The five power tokens (83050-83054), the items the upgrade ranks ask
--    for, in English, with their French names in item_template_locale.
-- 2. Their item_dbc rows (the SQL override of the server's Item.dbc: without
--    them, ObjectMgr::LoadItemTemplates simply IGNORES any item missing from
--    Item.dbc). The client needs those rows too: see tools/patch_item_dbc.py.
-- 3. The upgrade master of the former versions (NPC, script npc_item_upgrade)
--    is gone: its spawns and template are removed, found by that script name
--    only. Nothing happens on a server that never had it.
--
-- The descriptions name no rank, so that the scale
-- (db-characters/base/c_item_upgrade_scale.sql) can change without them.
-- Adding a language: one row per token in item_template_locale.
--
-- Idempotent: replayable without creating duplicates.
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- --- Power tokens ----------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` BETWEEN 83050 AND 83054;
INSERT INTO `item_template` (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`, `Quality`, `Flags`, `FlagsExtra`, `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `AllowableRace`, `ItemLevel`, `RequiredLevel`, `RequiredSkill`, `RequiredSkillRank`, `requiredspell`, `requiredhonorrank`, `RequiredCityRank`, `RequiredReputationFaction`, `RequiredReputationRank`, `maxcount`, `stackable`, `ContainerSlots`, `stat_type1`, `stat_value1`, `stat_type2`, `stat_value2`, `stat_type3`, `stat_value3`, `stat_type4`, `stat_value4`, `stat_type5`, `stat_value5`, `stat_type6`, `stat_value6`, `stat_type7`, `stat_value7`, `stat_type8`, `stat_value8`, `stat_type9`, `stat_value9`, `stat_type10`, `stat_value10`, `ScalingStatDistribution`, `ScalingStatValue`, `dmg_min1`, `dmg_max1`, `dmg_type1`, `dmg_min2`, `dmg_max2`, `dmg_type2`, `armor`, `holy_res`, `fire_res`, `nature_res`, `frost_res`, `shadow_res`, `arcane_res`, `delay`, `ammo_type`, `RangedModRange`, `spellid_1`, `spelltrigger_1`, `spellcharges_1`, `spellppmRate_1`, `spellcooldown_1`, `spellcategory_1`, `spellcategorycooldown_1`, `spellid_2`, `spelltrigger_2`, `spellcharges_2`, `spellppmRate_2`, `spellcooldown_2`, `spellcategory_2`, `spellcategorycooldown_2`, `spellid_3`, `spelltrigger_3`, `spellcharges_3`, `spellppmRate_3`, `spellcooldown_3`, `spellcategory_3`, `spellcategorycooldown_3`, `spellid_4`, `spelltrigger_4`, `spellcharges_4`, `spellppmRate_4`, `spellcooldown_4`, `spellcategory_4`, `spellcategorycooldown_4`, `spellid_5`, `spelltrigger_5`, `spellcharges_5`, `spellppmRate_5`, `spellcooldown_5`, `spellcategory_5`, `spellcategorycooldown_5`, `bonding`, `description`, `PageText`, `LanguageID`, `PageMaterial`, `startquest`, `lockid`, `Material`, `sheath`, `RandomProperty`, `RandomSuffix`, `block`, `itemset`, `MaxDurability`, `area`, `Map`, `BagFamily`, `TotemCategory`, `socketColor_1`, `socketContent_1`, `socketColor_2`, `socketContent_2`, `socketColor_3`, `socketContent_3`, `socketBonus`, `GemProperties`, `RequiredDisenchantSkill`, `ArmorDamageModifier`, `duration`, `ItemLimitCategory`, `HolidayId`, `ScriptName`, `DisenchantID`, `FoodType`, `minMoneyLoot`, `maxMoneyLoot`, `flagsCustom`, `VerifiedBuild`) VALUES
(83050,15,4,-1,'Shard of Power',24572,4,134217736,0,1,0,0,0,-1,-1,350,0,0,0,0,0,0,0,0,0,9999,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1000,0,0,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,1,'Used to upgrade statistics.',0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,'',0,0,0,0,0,0),
(83051,15,4,-1,'Fragment of Power',25054,4,134217736,0,1,0,0,0,-1,-1,390,0,0,0,0,0,0,0,0,0,9999,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1000,0,0,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,1,'Used to upgrade statistics.',0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,'',0,0,0,0,0,0),
(83052,15,4,-1,'Core of Power',45849,4,134217736,0,1,0,0,0,-1,-1,430,0,0,0,0,0,0,0,0,0,999,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1000,0,0,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,1,'Used to upgrade statistics.',0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,'',0,0,0,0,0,0),
(83053,15,4,-1,'Gem of Power',40051,4,134217736,0,1,0,0,0,-1,-1,470,0,0,0,0,0,0,0,0,0,9999,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1000,0,0,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,1,'Used to upgrade statistics.',0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,'',0,0,0,0,0,0),
(83054,15,4,-1,'Crown of Power',43759,5,134217736,0,1,0,0,0,-1,-1,999,0,0,0,0,0,0,0,0,0,9999,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1000,0,0,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,0,0,0,0,-1,0,-1,1,'Used to upgrade statistics.',0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,'',0,0,0,0,0,0);

DELETE FROM `item_template_locale` WHERE `ID` BETWEEN 83050 AND 83054;
INSERT INTO `item_template_locale` (`ID`, `locale`, `Name`, `Description`, `VerifiedBuild`) VALUES
  (83050, 'frFR', 'Éclat de Puissance', 'Permet d''améliorer des statistiques.', 0),
  (83051, 'frFR', 'Fragment de Puissance', 'Permet d''améliorer des statistiques.', 0),
  (83052, 'frFR', 'Noyau de Puissance', 'Permet d''améliorer des statistiques.', 0),
  (83053, 'frFR', 'Gemme de Puissance', 'Permet d''améliorer des statistiques.', 0),
  (83054, 'frFR', 'Couronne de Puissance', 'Permet d''améliorer des statistiques.', 0);

DELETE FROM `item_dbc` WHERE `ID` BETWEEN 83050 AND 83054;
INSERT INTO `item_dbc` (`ID`, `ClassID`, `SubclassID`, `Sound_Override_Subclassid`, `Material`, `DisplayInfoID`, `InventoryType`, `SheatheType`) VALUES
  (83050, 15, 4, -1, 1, 24572, 0, 0),
  (83051, 15, 4, -1, 1, 25054, 0, 0),
  (83052, 15, 4, -1, 1, 45849, 0, 0),
  (83053, 15, 4, -1, 1, 40051, 0, 0),
  (83054, 15, 4, -1, 1, 43759, 0, 0);

-- --- Former upgrade master ---------------------------------------------------
DELETE FROM `creature` WHERE `id` IN (SELECT `entry` FROM `creature_template` WHERE `ScriptName` = 'npc_item_upgrade');
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (SELECT `entry` FROM `creature_template` WHERE `ScriptName` = 'npc_item_upgrade');
DELETE FROM `creature_template` WHERE `ScriptName` = 'npc_item_upgrade';
