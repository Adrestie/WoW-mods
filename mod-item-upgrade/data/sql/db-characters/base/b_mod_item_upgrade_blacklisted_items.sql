-- Replayable: the core's updater replays this file alone when it changes, so
-- it creates the table only when missing and empties nothing.
CREATE TABLE IF NOT EXISTS `mod_item_upgrade_blacklisted_items`(
	`entry` int unsigned not null,
    PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;