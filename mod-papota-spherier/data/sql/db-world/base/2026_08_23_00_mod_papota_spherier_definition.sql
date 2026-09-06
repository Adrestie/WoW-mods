-- mod-papota-spherier : tables de definition (base world).
-- Jalon 1. Le chiffre 1234 est la sentinelle d'equilibrage du serveur : tout
-- montant a 1234 reste a calibrer. Rechargeable en jeu par .spherier reload.

CREATE TABLE IF NOT EXISTS `papota_sphere_node` (
  `node_id` INT UNSIGNED NOT NULL COMMENT 'identifiant global, toutes classes confondues',
  `class_id` TINYINT UNSIGNED NOT NULL,
  `kind` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = noeud (pierre pre-allouee), 1 = slot (vide, runes)',
  `grid_x` FLOAT NOT NULL DEFAULT 0,
  `grid_y` FLOAT NOT NULL DEFAULT 0,
  `icon` VARCHAR(255) NOT NULL DEFAULT '',
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `default_stone_entry` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'entree de la pierre pre-allouee, noeuds uniquement',
  PRIMARY KEY (`node_id`),
  KEY `idx_class` (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : emplacements de la grille, une grille par classe';

CREATE TABLE IF NOT EXISTS `papota_sphere_edge` (
  `class_id` TINYINT UNSIGNED NOT NULL,
  `node_a` INT UNSIGNED NOT NULL,
  `node_b` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`node_a`, `node_b`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : liaisons d adjacence entre emplacements';

CREATE TABLE IF NOT EXISTS `papota_sphere_start` (
  `class_id` TINYINT UNSIGNED NOT NULL,
  `node_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : point de depart de chaque classe';

CREATE TABLE IF NOT EXISTS `papota_sphere_point_source` (
  `source_type` VARCHAR(32) NOT NULL COMMENT 'boss_donjon, boss_raid, mythique_plus, donjon_termine',
  `source_value` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'precision propre au type (palier M+, entree de boss...), 0 = defaut du type',
  `points` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`source_type`, `source_value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : bareme des points par accroche de contenu';

CREATE TABLE IF NOT EXISTS `papota_sphere_item` (
  `item_entry` INT UNSIGNED NOT NULL COMMENT 'entree item_template de la sphere consommable',
  `points` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'points credites a la consommation',
  PRIMARY KEY (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : points credites par sphere consommee (rempli au jalon 3)';

CREATE TABLE IF NOT EXISTS `papota_sphere_cost` (
  `activated_min` INT UNSIGNED NOT NULL COMMENT 'tranche applicable a partir de N emplacements deja actives',
  `cost` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`activated_min`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : bareme du prix croissant, identique noeuds et slots';

-- Amorces avec sentinelles, pour que .spherier info ait matiere et que le
-- rechargement soit testable. Les vraies valeurs viendront de l equilibrage.
REPLACE INTO `papota_sphere_cost` (`activated_min`, `cost`) VALUES
(0, 1234);

REPLACE INTO `papota_sphere_point_source` (`source_type`, `source_value`, `points`) VALUES
('boss_donjon',    0, 1234),
('boss_raid',      0, 1234),
('mythique_plus',  0, 1234),
('donjon_termine', 0, 1234);
