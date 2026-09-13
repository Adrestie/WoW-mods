-- mod-stellar-tarot — where cards and boards come from.
--
-- One row per SOURCE: what drops -- a given card or board, or one drawn at
-- random from the whole catalogue -- and from what. The only origin so far is
-- a creature killed; its loot is sorted by the creature's entry, the
-- expansion of its map, the kind of place, the heroic mode, its rank and its
-- level. A filter left at its default matches anything. Every row is played
-- on its own, at its own chance, each time a creature's loot is filled, and
-- what wins joins the loot window like an item of the creature's own table.
--
-- CONTENT, not settings: edit, then `.tarot reload`. The configuration only
-- turns the loot off (StellarTarot.Loot.Enabled), scales every chance
-- (StellarTarot.Loot.Rate) and says whether a known card may drop again
-- (StellarTarot.Loot.Known).
--
-- A row that names a card or a board missing from the catalogue, or a value
-- out of its list, is refused at load time and said so in the log.
--
-- Idempotent: the file may be replayed.

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_source` (
  `source_id` INT UNSIGNED NOT NULL,
  `origin` VARCHAR(16) NOT NULL DEFAULT 'creature' COMMENT 'creature',
  `what` VARCHAR(8) NOT NULL DEFAULT 'card' COMMENT 'card or board',
  `target_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'the card or board number; 0 = drawn at random from the catalogue',
  `creature_entry` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = any creature',
  `expansion` TINYINT NOT NULL DEFAULT -1 COMMENT '-1 any; 0 classic, 1 Burning Crusade, 2 Wrath (of the map)',
  `place` VARCHAR(8) NOT NULL DEFAULT '' COMMENT 'empty = any; world, dungeon, raid',
  `heroic` TINYINT NOT NULL DEFAULT -1 COMMENT '-1 any; 0 normal, 1 heroic',
  `creature_rank` VARCHAR(8) NOT NULL DEFAULT '' COMMENT 'empty = any; normal, elite, boss',
  `min_level` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'creature level floor; 0 = none',
  `max_level` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'creature level ceiling; 0 = none',
  `chance` FLOAT NOT NULL DEFAULT 0 COMMENT 'percent, before StellarTarot.Loot.Rate',
  `quantity` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'how many when the roll wins',
  `comment` VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`source_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: where cards and boards drop from';

-- The sources of the test catalogue. 12.34 is the placeholder rate, as
-- 1234 is the placeholder amount elsewhere: nothing is balanced yet.
DELETE FROM `mod_stellar_tarot_source` WHERE `source_id` BETWEEN 1 AND 4;
INSERT INTO `mod_stellar_tarot_source`
  (`source_id`, `origin`, `what`, `target_id`, `creature_entry`, `expansion`, `place`, `heroic`, `creature_rank`, `min_level`, `max_level`, `chance`, `quantity`, `comment`) VALUES
(1, 'creature', 'card',  0, 0, -1, 'world',   -1, '',      0, 0, 12.34, 1, 'any creature of the open world: a card drawn at random'),
(2, 'creature', 'board', 0, 0, -1, 'dungeon', -1, 'boss',  0, 0, 12.34, 1, 'a dungeon boss: a board drawn at random'),
(3, 'creature', 'card',  0, 0, -1, 'raid',    -1, 'boss',  0, 0, 12.34, 2, 'a raid boss: two cards drawn at random'),
(4, 'creature', 'card', 43, 0,  2, '',        -1, 'elite', 0, 0, 12.34, 1, 'an elite of a Wrath map: card 43, The Star');
