-- Spherier Papota : sorts par classe des emplacements de sort (2026-09-05).
--
-- Sur la GRILLE COMMUNE, un emplacement de sort est a tout le monde : chaque
-- classe y apprend LE SIEN. Cette table porte le sort de chaque classe ;
-- papota_sphere_node.spell_id reste le repli « toutes classes », lu quand une
-- classe n'a rien ici. Ecrite par importe_layout.lua (balises <sort> du XML).
CREATE TABLE IF NOT EXISTS `papota_sphere_node_spell` (
  `node_id` INT UNSIGNED NOT NULL COMMENT 'emplacement de sort (papota_sphere_node)',
  `class_id` TINYINT UNSIGNED NOT NULL COMMENT 'classe du joueur qui apprend ce sort',
  `spell_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`node_id`, `class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : sort appris a un emplacement de sort, par classe';
