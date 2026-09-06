-- Spherite LIÉE AU COMPTE (2026-09-04).
--
-- Ce qui est GAGNÉ appartient désormais au compte : un boss tué sur un
-- personnage crédite tous les autres, et un personnage créé demain naît avec
-- la totalité de ce que le compte a amassé.
--
-- Ce qui est DÉPENSÉ reste PROPRE AU PERSONNAGE : chacun a sa grille et ses
-- achats. Le disponible se lit donc « gagné du compte moins dépensé de ce
-- personnage-ci ».
--
-- MIGRATION : la colonne `earned` de `character_sphere_points` est versée au
-- compte puis RETIRÉE. La laisser en place aurait été un piège dormant — une
-- colonne qui a l'air de faire autorité et que plus rien ne lit. C'est
-- exactement ce qui a rendu les Nexus inutilisables une semaine durant.
--
-- Le tout est IDEMPOTENT : rejouer ce fichier après le retrait ne refait ni la
-- copie (qui écraserait le compte avec des valeurs périmées) ni l'ALTER (qui
-- échouerait). L'updater d'AzerothCore rejoue un fichier dont l'empreinte
-- change ; on ne suppose pas qu'il ne le fera jamais.

CREATE TABLE IF NOT EXISTS `account_sphere_points` (
  `account_id` INT UNSIGNED NOT NULL,
  `earned`     INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : Spherite gagnee, commune a tout le compte';

SET @colonne := (SELECT COUNT(*) FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE()
                   AND TABLE_NAME  = 'character_sphere_points'
                   AND COLUMN_NAME = 'earned');

-- LA SOMME, et non le maximum : tout ce que le compte a gagné lui revient,
-- quel que soit le personnage qui l'a gagné. Sur les données d'aujourd'hui les
-- deux se valent — un seul compte porte des points, sur un seul personnage.
SET @copie := IF(@colonne > 0,
  'INSERT INTO `account_sphere_points` (`account_id`, `earned`)
     SELECT c.account, SUM(p.earned)
     FROM `character_sphere_points` p
     JOIN `characters` c ON c.guid = p.guid
     GROUP BY c.account
   ON DUPLICATE KEY UPDATE `earned` = VALUES(`earned`)',
  'DO 0');
PREPARE s FROM @copie; EXECUTE s; DEALLOCATE PREPARE s;

SET @retrait := IF(@colonne > 0,
  'ALTER TABLE `character_sphere_points` DROP COLUMN `earned`',
  'DO 0');
PREPARE s FROM @retrait; EXECUTE s; DEALLOCATE PREPARE s;
