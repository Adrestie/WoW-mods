-- mod-stellar-tarot — characters schema.
--
-- What a player owns. Two levels, and the split is deliberate:
--
--   ACCOUNT     the binder -- every card and every board studied by any
--               character of the account, present or future -- and the
--               presets, which name cards of that binder.
--   CHARACTER   the board equipped and the cards laid on it: the effects
--               apply to one character.
--
-- Idempotent: the file may be replayed, it creates nothing that already exists.

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_account_card` (
  `account_id` INT UNSIGNED NOT NULL,
  `card_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`account_id`, `card_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the binder, the cards an account has studied';

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_account_board` (
  `account_id` INT UNSIGNED NOT NULL,
  `board_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`account_id`, `board_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the boards an account has studied';

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_character_board` (
  `guid` INT UNSIGNED NOT NULL,
  `board_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = no board equipped',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the board one character has equipped';

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_character_cell` (
  `guid` INT UNSIGNED NOT NULL,
  `row_idx` TINYINT UNSIGNED NOT NULL COMMENT '1-based',
  `col_idx` TINYINT UNSIGNED NOT NULL COMMENT '1-based',
  `card_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`, `row_idx`, `col_idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the cards one character laid on its board';

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_preset` (
  `account_id` INT UNSIGNED NOT NULL,
  `preset_id` INT UNSIGNED NOT NULL,
  `name` VARCHAR(32) NOT NULL DEFAULT '',
  `board_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`account_id`, `preset_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: a saved layout, a board and its cards';

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_preset_cell` (
  `account_id` INT UNSIGNED NOT NULL,
  `preset_id` INT UNSIGNED NOT NULL,
  `row_idx` TINYINT UNSIGNED NOT NULL,
  `col_idx` TINYINT UNSIGNED NOT NULL,
  `card_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`account_id`, `preset_id`, `row_idx`, `col_idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the cards of a saved layout';
