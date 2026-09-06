-- mod-papota-spherier : etat des personnages (base characters).
-- Jalon 1 : structures seulement, aucun code ne les remplit encore.
-- Seuls les emplacements actives ont une ligne ; les points disponibles se
-- deduisent (earned - spent), jamais stockes en double.

CREATE TABLE IF NOT EXISTS `character_sphere_node` (
  `guid` INT UNSIGNED NOT NULL,
  `node_id` INT UNSIGNED NOT NULL,
  `content_entry` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'entree de l objet serti, 0 si vide',
  `content_upgrade` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'niveau d amelioration, runes uniquement',
  PRIMARY KEY (`guid`, `node_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : emplacements actives par personnage';

CREATE TABLE IF NOT EXISTS `character_sphere_points` (
  `guid` INT UNSIGNED NOT NULL,
  `earned` INT UNSIGNED NOT NULL DEFAULT 0,
  `spent` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : points de spherier par personnage';
