-- mod-spheregrid — world schema.
--
-- The tables that carry the definition of the grid and its catalogues.
--
-- What an operator TUNES is not here: the awards, the stone amounts and the
-- statistic rune percentage live in conf/mod-spheregrid.conf, which the module
-- and its interface both read. What is left here is CONTENT — the shape of the
-- grid, and the catalogue of the rank runes, which no formula can express.
--
-- AND NO ROW STORES AN IDENTIFIER THE MODULE ALLOCATES WHEN IT CAN STORE THE
-- CHOICE BEHIND IT. A cell says which STATISTIC and which QUALITY it comes
-- pre-filled with, not the item entry that follows from them: the entry depends
-- on a base the installer may move, the choice does not. `mod_spheregrid_rune`
-- is the one exception — its entries are allocated one by one, with gaps, so
-- they are listed; the installer rewrites them together with the items.
--
-- NOR DOES A CELL CARRY ITS PRESENTATION — neither its name nor its icon. A name
-- is a language and an icon is art the client already owns: both depend on the
-- client, so both belong to the interface, which composes them from the
-- statistic, the quality and the kind the cell declares. Storing them meant
-- 2 451 rows repeating one language and seventeen distinct textures.
--
-- See docs/PRESENTATION.md.
--
-- Idempotent: the file may be replayed, it creates nothing that already exists.

-- ---------------------------------------------------------------------------
-- The grid itself
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `mod_spheregrid_node` (
  `node_id` INT UNSIGNED NOT NULL COMMENT 'global id, all classes together',
  `class_id` TINYINT UNSIGNED NOT NULL COMMENT '0 = the shared grid, else a class',
  `kind` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = node (pre-filled stone), 1 = socket (empty, runes), 2 = spell cell',
  `grid_x` FLOAT NOT NULL DEFAULT 0,
  `grid_y` FLOAT NOT NULL DEFAULT 0,
  `stone_stat` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'the statistic of the pre-filled stone, nodes only; 0 = an empty node',
  `stone_quality` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'its quality, 1 = common .. 5 = legendary',
  `cluster` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cluster it belongs to (drawing)',
  `ring` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ring (drawing)',
  `branch` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'branch (drawing)',
  `spell_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'custom spell taught, kind 2 only',
  PRIMARY KEY (`node_id`),
  KEY `idx_class` (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: the cells of the grid';

CREATE TABLE IF NOT EXISTS `mod_spheregrid_edge` (
  `class_id` TINYINT UNSIGNED NOT NULL,
  `node_a` INT UNSIGNED NOT NULL,
  `node_b` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`node_a`, `node_b`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: adjacency between cells';

CREATE TABLE IF NOT EXISTS `mod_spheregrid_start` (
  `class_id` TINYINT UNSIGNED NOT NULL,
  `node_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: the starting cell of each class';

CREATE TABLE IF NOT EXISTS `mod_spheregrid_node_spell` (
  `node_id` INT UNSIGNED NOT NULL COMMENT 'a spell cell (mod_spheregrid_node)',
  `class_id` TINYINT UNSIGNED NOT NULL COMMENT 'the class that learns this spell there',
  `spell_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`node_id`, `class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: the spell a cell teaches, per class';

CREATE TABLE IF NOT EXISTS `mod_spheregrid_cluster` (
  `class_id` TINYINT UNSIGNED NOT NULL,
  `cluster_id` INT UNSIGNED NOT NULL,
  `x` FLOAT NOT NULL DEFAULT 0,
  `y` FLOAT NOT NULL DEFAULT 0,
  `rot` FLOAT NOT NULL DEFAULT 0,
  PRIMARY KEY (`class_id`, `cluster_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: clusters, read by the interface to draw the arcs';

-- ---------------------------------------------------------------------------
-- The catalogues
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `mod_spheregrid_rune` (
  `item_entry` INT UNSIGNED NOT NULL,
  `first_spell_id` INT UNSIGNED NOT NULL COMMENT 'the first rank of the family',
  `base_rank` TINYINT UNSIGNED NOT NULL COMMENT 'how many ranks Blizzard has',
  `base_spell_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'the last Blizzard rank: the prerequisite',
  `is_talent` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 when the spell comes from a talent',
  `class_id` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'the only class allowed to socket it',
  PRIMARY KEY (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='SphereGrid: rank rune';

