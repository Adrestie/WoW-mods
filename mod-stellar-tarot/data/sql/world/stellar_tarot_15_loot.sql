-- mod-stellar-tarot — what a place gives, by expansion.
--
-- These identifiers used to live in the module's code, in three functions that
-- each read the age of the map their own way. A gem more, a crate from another
-- expansion: it took a rebuild. Not any more.
--
-- GENERATED from the module's tooling. Regenerable.

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_loot_pool` (
  `pool` VARCHAR(32) NOT NULL COMMENT 'gem, chest, pearl',
  `age` TINYINT UNSIGNED NOT NULL COMMENT '0 = old world, 1 = Outland, 2 = Northrend and beyond',
  `entry` INT UNSIGNED NOT NULL COMMENT 'item_template.entry',
  PRIMARY KEY (`pool`, `age`, `entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: what a place gives, by expansion';

DELETE FROM `mod_stellar_tarot_loot_pool`;
INSERT INTO `mod_stellar_tarot_loot_pool` (`pool`, `age`, `entry`) VALUES
('chest', 0, 6352),
('chest', 1, 27513),
('chest', 2, 44475),
('gem', 0, 12800),
('gem', 1, 32227),
('gem', 1, 32228),
('gem', 1, 32229),
('gem', 1, 32230),
('gem', 1, 32231),
('gem', 1, 32249),
('gem', 2, 36919),
('gem', 2, 36922),
('gem', 2, 36925),
('gem', 2, 36928),
('gem', 2, 36931),
('gem', 2, 36934),
('pearl', 0, 5498),
('pearl', 0, 5500),
('pearl', 0, 7971),
('pearl', 0, 13926),
('pearl', 1, 24478),
('pearl', 1, 24479),
('pearl', 2, 36783);
