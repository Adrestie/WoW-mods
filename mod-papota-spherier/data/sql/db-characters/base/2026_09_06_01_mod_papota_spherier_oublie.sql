-- mod-papota-spherier : la colonne `oublie` des emplacements (2026-09-06).
--
-- Sur un emplacement de sort, content_entry = 0 avait deux sens : « achete
-- alors que la classe n'y avait pas encore de sort » et « sort oublie par
-- l'epingle ». Le premier doit apprendre le sort des qu'il existe, sans
-- repayer ; le second exige un nouvel achat. `oublie` = 1 marque le second.
-- IDEMPOTENT : la colonne n'est ajoutee que si elle manque.
SET @colonne := (SELECT COUNT(*) FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE()
                   AND TABLE_NAME  = 'character_sphere_node'
                   AND COLUMN_NAME = 'oublie');
SET @ajout := IF(@colonne = 0,
  'ALTER TABLE `character_sphere_node` ADD COLUMN `oublie` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''sort oublie a l''''epingle : un nouvel achat le rapprend''',
  'DO 0');
PREPARE s FROM @ajout; EXECUTE s; DEALLOCATE PREPARE s;
