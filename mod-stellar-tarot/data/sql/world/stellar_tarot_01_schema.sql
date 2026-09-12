-- mod-stellar-tarot — world schema.
--
-- The catalogue: what a card is, what a board is, what a tag is, what a
-- script says of itself. CONTENT, not settings -- an operator who wants other
-- cards edits these tables and types `.tarot reload`.
--
-- NO ROW STORES AN IDENTIFIER THE MODULE ALLOCATES. A card is known by its
-- number, and its item entry FOLLOWS from that number (902000 + card_id, see
-- StellarTarotMgr.h); a board likewise (902500 + board_id). The installer may
-- move the base; the numbers do not move.
--
-- A CARD IS ONE ROW. Its four edges, and what it does at each of its four
-- activation levels: a spell applied as an aura, a C++ script of the module,
-- or both. `cumulative` says whether reaching level 3 grants levels 1, 2 and
-- 3 together, or level 3 alone. A level with neither a spell nor a script, an
-- unknown spell or an unknown script is an error at load time: the card is
-- refused and cannot be laid.
--
-- Idempotent: the file may be replayed, it creates nothing that already exists.

-- The one-row-per-level tables of the first versions, never published.
DROP TABLE IF EXISTS `mod_stellar_tarot_card_effect_locale`;
DROP TABLE IF EXISTS `mod_stellar_tarot_card_effect`;
-- The card table changed shape with them: rebuilt, and filled again by
-- stellar_tarot_05_cards.sql which follows. A card carries ONE tag, in its
-- own row: the link table of the first versions goes too.
DROP TABLE IF EXISTS `mod_stellar_tarot_card`;
DROP TABLE IF EXISTS `mod_stellar_tarot_card_tag`;

-- ---------------------------------------------------------------------------
-- The cards
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_card` (
  `card_id` INT UNSIGNED NOT NULL COMMENT 'the card number, 1..499; its item is 902000 + card_id',
  `name` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'the English name of reference; the item carries the one the player reads',
  `edge_top` TINYINT UNSIGNED NOT NULL COMMENT '1..9',
  `edge_right` TINYINT UNSIGNED NOT NULL COMMENT '1..9',
  `edge_bottom` TINYINT UNSIGNED NOT NULL COMMENT '1..9',
  `edge_left` TINYINT UNSIGNED NOT NULL COMMENT '1..9',
  `tag_id` INT UNSIGNED NOT NULL COMMENT 'the one tag of the card (mod_stellar_tarot_tag): the tab it sits under in the deck',
  `cumulative` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = level L grants levels 1..L together; 0 = level L alone',
  `card_spell_1` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'aura applied at level 1, 0 = none',
  `card_spell_2` INT UNSIGNED NOT NULL DEFAULT 0,
  `card_spell_3` INT UNSIGNED NOT NULL DEFAULT 0,
  `card_spell_4` INT UNSIGNED NOT NULL DEFAULT 0,
  `card_script_1` VARCHAR(64) NOT NULL DEFAULT '' COMMENT 'module script at level 1: name, or name:param:param; empty = none',
  `card_script_2` VARCHAR(64) NOT NULL DEFAULT '',
  `card_script_3` VARCHAR(64) NOT NULL DEFAULT '',
  `card_script_4` VARCHAR(64) NOT NULL DEFAULT '',
  `hint` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'where to find the card: what the deck shows for a card not yet known, English',
  `art` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'texture of the card face, client side, under Interface\\mod-Tarot\\Cards',
  PRIMARY KEY (`card_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the cards -- four edges, and a spell and/or a script per level';

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_card_locale` (
  `card_id` INT UNSIGNED NOT NULL,
  `locale` VARCHAR(4) NOT NULL,
  `hint` VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`card_id`, `locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the hint of a card, per locale';

-- What a script says of itself: the row of `module_string` (English) and
-- `module_string_locale` that describes it, formatted by the interface with
-- the script's parameters in order ({} for each). A description changes in the
-- database, without a rebuild; a script without a row shows its column as is.
CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_script` (
  `name` VARCHAR(64) NOT NULL COMMENT 'the name the C++ registers, as written in card_script_N before the colon',
  `string_id` INT UNSIGNED NOT NULL COMMENT 'id in module_string for module mod-stellar-tarot; 1001 and up are reserved for scripts',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the description of each script';

-- ---------------------------------------------------------------------------
-- The tags: the tabs of the deck, one per tag, in tag_id order. Every card
-- sits under exactly one.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_tag` (
  `tag_id` INT UNSIGNED NOT NULL,
  `name` VARCHAR(64) NOT NULL COMMENT 'English',
  PRIMARY KEY (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the tags, the tabs of the deck';

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_tag_locale` (
  `tag_id` INT UNSIGNED NOT NULL,
  `locale` VARCHAR(4) NOT NULL,
  `name` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`tag_id`, `locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the tag names, per locale';

-- ---------------------------------------------------------------------------
-- The boards
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_board` (
  `board_id` INT UNSIGNED NOT NULL COMMENT 'the board number, 1..99; its item is 902500 + board_id',
  `row_count` TINYINT UNSIGNED NOT NULL COMMENT '2..4',
  `col_count` TINYINT UNSIGNED NOT NULL COMMENT '2..4',
  `art` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'texture of the board, client side, under Interface\\mod-Tarot\\Boards',
  PRIMARY KEY (`board_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the boards';

-- The numbers around a board: two per row -- on the left, faced by the left
-- edge of the row's first card, and on the right, faced by the right edge of
-- its last -- and two per column -- on top, faced by the top edge of the
-- column's first card, and at the bottom, faced by the bottom edge of its
-- last. Every one of them may differ.
-- Rebuilt: the first versions had one number per row and per column.
DROP TABLE IF EXISTS `mod_stellar_tarot_board_line`;
CREATE TABLE IF NOT EXISTS `mod_stellar_tarot_board_line` (
  `board_id` INT UNSIGNED NOT NULL,
  `axis` TINYINT UNSIGNED NOT NULL COMMENT '0 = row, 1 = column',
  `idx` TINYINT UNSIGNED NOT NULL COMMENT '1-based, top to bottom or left to right',
  `side` TINYINT UNSIGNED NOT NULL COMMENT 'row: 0 = left, 1 = right; column: 0 = top, 1 = bottom',
  `number` TINYINT UNSIGNED NOT NULL COMMENT '1..9',
  PRIMARY KEY (`board_id`, `axis`, `idx`, `side`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='StellarTarot: the numbers on each side of each row and column of a board';
