-- Replayable: the core's updater replays this file alone when it changes, so
-- it creates the table only when missing and empties nothing.
CREATE TABLE IF NOT EXISTS `mod_item_upgrade_stats`(
	`id` int unsigned not null,
    `stat_type` tinyint unsigned NOT NULL,
    `stat_mod_pct` float not null,
    `stat_rank` smallint unsigned NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `mod_item_upgrade_stats` (`id`, `stat_type`, `stat_mod_pct`, `stat_rank`)
SELECT * FROM (
  SELECT 1 AS `id`, 3 AS `stat_type`, 5 AS `stat_mod_pct`, 1 AS `stat_rank`
  UNION ALL SELECT 2, 4, 5, 1
  UNION ALL SELECT 3, 5, 5, 1
  UNION ALL SELECT 4, 6, 5, 1
  UNION ALL SELECT 5, 7, 5, 1
  UNION ALL SELECT 6, 32, 5, 1
  UNION ALL SELECT 7, 36, 5, 1
  UNION ALL SELECT 8, 45, 5, 1
  UNION ALL SELECT 9, 3, 10, 2
  UNION ALL SELECT 10, 4, 10, 2
  UNION ALL SELECT 11, 5, 10, 2
  UNION ALL SELECT 12, 6, 10, 2
  UNION ALL SELECT 13, 7, 10, 2
  UNION ALL SELECT 14, 32, 10, 2
  UNION ALL SELECT 15, 36, 10, 2
  UNION ALL SELECT 16, 45, 10, 2
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM `mod_item_upgrade_stats`);
