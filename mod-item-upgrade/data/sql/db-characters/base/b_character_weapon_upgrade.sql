-- Replayable: the core's updater replays this file alone when it changes, so
-- it creates the table only when missing and empties nothing.
CREATE TABLE IF NOT EXISTS `character_weapon_upgrade`(
	`guid` int unsigned not null,
	`item_guid` int unsigned not null,
    `upgrade_perc` float not null,
    PRIMARY KEY (`guid`, `item_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;