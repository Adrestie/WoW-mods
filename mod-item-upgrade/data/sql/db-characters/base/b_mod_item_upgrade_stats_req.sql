-- Replayable: the core's updater replays this file alone when it changes, so
-- it creates the table only when missing and empties nothing.
CREATE TABLE IF NOT EXISTS `mod_item_upgrade_stats_req`(
	`id` int unsigned not null AUTO_INCREMENT,
	`stat_id` int unsigned not null,
    `req_type` tinyint unsigned not null,
    `req_val1` float not null,
    `req_val2` float,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `mod_item_upgrade_stats_req` (`stat_id`, `req_type`, `req_val1`, `req_val2`)
SELECT * FROM (
  SELECT 1 AS `stat_id`, 1 AS `req_type`, 10000000 AS `req_val1`, NULL AS `req_val2`
  UNION ALL SELECT 2, 1, 10000000, NULL
  UNION ALL SELECT 3, 1, 10000000, NULL
  UNION ALL SELECT 4, 1, 10000000, NULL
  UNION ALL SELECT 5, 1, 10000000, NULL
  UNION ALL SELECT 6, 1, 10000000, NULL
  UNION ALL SELECT 7, 1, 10000000, NULL
  UNION ALL SELECT 8, 1, 10000000, NULL
  UNION ALL SELECT 9, 1, 10000000, NULL
  UNION ALL SELECT 10, 1, 10000000, NULL
  UNION ALL SELECT 11, 1, 10000000, NULL
  UNION ALL SELECT 12, 1, 10000000, NULL
  UNION ALL SELECT 13, 1, 10000000, NULL
  UNION ALL SELECT 14, 1, 10000000, NULL
  UNION ALL SELECT 15, 1, 10000000, NULL
  UNION ALL SELECT 16, 1, 10000000, NULL
  UNION ALL SELECT 9, 4, 29434, 100
  UNION ALL SELECT 10, 4, 29434, 100
  UNION ALL SELECT 11, 4, 29434, 100
  UNION ALL SELECT 12, 4, 29434, 100
  UNION ALL SELECT 13, 4, 29434, 100
  UNION ALL SELECT 14, 4, 29434, 100
  UNION ALL SELECT 15, 4, 29434, 100
  UNION ALL SELECT 16, 4, 29434, 100
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM `mod_item_upgrade_stats_req`);
