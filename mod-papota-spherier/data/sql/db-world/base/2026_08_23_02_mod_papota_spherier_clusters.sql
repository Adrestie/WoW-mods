-- mod-papota-spherier : geometrie des clusters en base, pour le rendu de
-- l'interface joueur (arcs d'anneau). Le module C++ ignore ces donnees ;
-- l'interface Lua les lit directement. Rempli par importe_layout.lua.

CREATE TABLE IF NOT EXISTS `papota_sphere_cluster` (
  `class_id` TINYINT UNSIGNED NOT NULL,
  `cluster_id` INT UNSIGNED NOT NULL,
  `x` FLOAT NOT NULL DEFAULT 0,
  `y` FLOAT NOT NULL DEFAULT 0,
  `rot` FLOAT NOT NULL DEFAULT 0,
  PRIMARY KEY (`class_id`, `cluster_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : clusters des grilles, pour le rendu des arcs';

-- Application unique (consignee dans `updates`) : MySQL ne connait pas
-- ADD COLUMN IF NOT EXISTS.
ALTER TABLE `papota_sphere_node`
  ADD COLUMN `cluster` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cluster d appartenance (rendu)',
  ADD COLUMN `ring` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'anneau 1-3 (rendu)',
  ADD COLUMN `branch` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'branche 1-8 (rendu)';
