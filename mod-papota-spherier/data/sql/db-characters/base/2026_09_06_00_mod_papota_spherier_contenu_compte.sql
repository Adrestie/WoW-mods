-- mod-papota-spherier : le CONTENU des noeuds a pierres appartient au COMPTE
-- (decision utilisateur du 2026-09-05, livree le 2026-09-06).
--
-- Ce qu'un personnage du compte met dans un noeud a pierres, ou en retire a
-- l'epingle (content_entry = 0), vaut pour tous ses personnages. Absent de la
-- table = pierre d'origine du noeud. Les slots (runes) et les emplacements de
-- sort restent propres au personnage (character_sphere_node).
CREATE TABLE IF NOT EXISTS `account_sphere_node` (
  `account_id` INT UNSIGNED NOT NULL,
  `node_id` INT UNSIGNED NOT NULL COMMENT 'emplacement (papota_sphere_node)',
  `content_entry` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'pierre serti par un personnage du compte, 0 = vide',
  `content_upgrade` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`account_id`, `node_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : contenu des noeuds a pierres, au compte';
