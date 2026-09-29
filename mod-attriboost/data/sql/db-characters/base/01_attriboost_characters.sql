-- mod-attriboost — points d'attribut par personnage.
-- Une ligne par personnage ; `unallocated` = points en réserve, les autres
-- colonnes = points posés sur chaque statistique. Purger cette table remet
-- tout le serveur à zéro (les auras suivent au prochain passage en jeu).

CREATE TABLE IF NOT EXISTS `attriboost_attributes` (
  `guid` int unsigned NOT NULL,
  `unallocated` int DEFAULT 0,
  `stamina` int unsigned DEFAULT 0,
  `strength` int unsigned DEFAULT 0,
  `agility` int unsigned DEFAULT 0,
  `intellect` int unsigned DEFAULT 0,
  `spirit` int unsigned DEFAULT 0,
  `spellpower` int unsigned DEFAULT 0,
  `criticalstrikedamage` int unsigned DEFAULT 0,
  `allresists` int unsigned DEFAULT 0,
  `spellpenetration` int unsigned DEFAULT 0,
  `healingpower` int unsigned DEFAULT 0,
  `settings` int DEFAULT 1,
  `comment` varchar(50) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `talentpoints` int unsigned DEFAULT 0 COMMENT 'talent points granted by Books of Talents, taken back on uninstall',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- A server that ran the original module (AnchyDev/Attriboost) already has this
-- table, without the columns this fork added: CREATE TABLE IF NOT EXISTS leaves
-- it as it is. Each missing column is added here, IN ITS PLACE: the module
-- reads the table by column position, so a column appended at the end would
-- shift every value after it. MySQL has no ADD COLUMN IF NOT EXISTS, hence one
-- prepared statement per column. Harmless where the columns already exist.

SET @missing := (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attriboost_attributes' AND COLUMN_NAME = 'spellpower');
SET @sql := IF(@missing, 'ALTER TABLE `attriboost_attributes` ADD COLUMN `spellpower` int unsigned DEFAULT 0 AFTER `spirit`', 'DO 0');
PREPARE attriboost_step FROM @sql; EXECUTE attriboost_step; DEALLOCATE PREPARE attriboost_step;

SET @missing := (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attriboost_attributes' AND COLUMN_NAME = 'criticalstrikedamage');
SET @sql := IF(@missing, 'ALTER TABLE `attriboost_attributes` ADD COLUMN `criticalstrikedamage` int unsigned DEFAULT 0 AFTER `spellpower`', 'DO 0');
PREPARE attriboost_step FROM @sql; EXECUTE attriboost_step; DEALLOCATE PREPARE attriboost_step;

SET @missing := (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attriboost_attributes' AND COLUMN_NAME = 'allresists');
SET @sql := IF(@missing, 'ALTER TABLE `attriboost_attributes` ADD COLUMN `allresists` int unsigned DEFAULT 0 AFTER `criticalstrikedamage`', 'DO 0');
PREPARE attriboost_step FROM @sql; EXECUTE attriboost_step; DEALLOCATE PREPARE attriboost_step;

SET @missing := (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attriboost_attributes' AND COLUMN_NAME = 'spellpenetration');
SET @sql := IF(@missing, 'ALTER TABLE `attriboost_attributes` ADD COLUMN `spellpenetration` int unsigned DEFAULT 0 AFTER `allresists`', 'DO 0');
PREPARE attriboost_step FROM @sql; EXECUTE attriboost_step; DEALLOCATE PREPARE attriboost_step;

SET @missing := (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attriboost_attributes' AND COLUMN_NAME = 'healingpower');
SET @sql := IF(@missing, 'ALTER TABLE `attriboost_attributes` ADD COLUMN `healingpower` int unsigned DEFAULT 0 AFTER `spellpenetration`', 'DO 0');
PREPARE attriboost_step FROM @sql; EXECUTE attriboost_step; DEALLOCATE PREPARE attriboost_step;

-- Talent points granted by Books of Talents, so that uninstalling takes back
-- exactly those (the core keeps one counter that other modules may feed too).
-- Last column: nothing reads the table by its position beyond `comment`.
SET @missing := (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attriboost_attributes' AND COLUMN_NAME = 'talentpoints');
SET @sql := IF(@missing, 'ALTER TABLE `attriboost_attributes` ADD COLUMN `talentpoints` int unsigned DEFAULT 0 COMMENT ''talent points granted by Books of Talents, taken back on uninstall'' AFTER `comment`', 'DO 0');
PREPARE attriboost_step FROM @sql; EXECUTE attriboost_step; DEALLOCATE PREPARE attriboost_step;
