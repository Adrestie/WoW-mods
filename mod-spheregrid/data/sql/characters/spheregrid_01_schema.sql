-- mod-spheregrid — characters schema.
--
-- What a player owns. Two levels, and the split is deliberate:
--
--   ACCOUNT     what is EARNED — a boss killed on one character credits all the
--               others, and a character created tomorrow is born with the whole
--               of it. The content of the stone nodes belongs here too: what one
--               character put in a node, or took out of it, holds for all.
--   CHARACTER   what is SPENT, and which cells are bought. Each character has
--               its own grid.
--
-- Idempotent: the file may be replayed, it creates nothing that already exists.

CREATE TABLE IF NOT EXISTS `mod_spheregrid_account_points` (
  `account_id` INT UNSIGNED NOT NULL,
  `earned` INT UNSIGNED NOT NULL DEFAULT 0,
  `prisms` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'prismatic Nexuses absorbed: each one boosts every gain',
  PRIMARY KEY (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: Spherite earned, shared by the whole account';

CREATE TABLE IF NOT EXISTS `mod_spheregrid_account_node` (
  `account_id` INT UNSIGNED NOT NULL,
  `node_id` INT UNSIGNED NOT NULL COMMENT 'a cell (mod_spheregrid_node)',
  `content_entry` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'the stone one character of the account socketed, 0 = empty',
  `content_upgrade` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`account_id`, `node_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: the content of the stone nodes, at account level';

CREATE TABLE IF NOT EXISTS `mod_spheregrid_character_points` (
  `guid` INT UNSIGNED NOT NULL,
  `spent` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: Spherite spent by one character';

CREATE TABLE IF NOT EXISTS `mod_spheregrid_character_node` (
  `guid` INT UNSIGNED NOT NULL,
  `node_id` INT UNSIGNED NOT NULL,
  `content_entry` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'entry of the socketed item, 0 when empty',
  `content_upgrade` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'upgrade level, runes only',
  `forgotten` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'spell forgotten with the pin: a new purchase teaches it again',
  `active` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0 = cell given back by a reset: it keeps its content, it is no longer bought',
  PRIMARY KEY (`guid`, `node_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: the cells one character has bought';
