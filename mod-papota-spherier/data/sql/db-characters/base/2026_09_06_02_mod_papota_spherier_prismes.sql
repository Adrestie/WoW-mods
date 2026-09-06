-- mod-papota-spherier : les NEXUS PRISMATIQUES du compte (2026-09-06).
--
-- Chaque Nexus prismatique absorbe par un personnage du compte majore de 25 %
-- tous les gains de Spherite du compte, sans plafond : `prismes` compte les
-- absorptions. Remis a zero par `.spherier wipeall` (la ligne est effacee).
-- IDEMPOTENT : la colonne n'est ajoutee que si elle manque.
SET @colonne := (SELECT COUNT(*) FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE()
                   AND TABLE_NAME  = 'account_sphere_points'
                   AND COLUMN_NAME = 'prismes');
SET @ajout := IF(@colonne = 0,
  'ALTER TABLE `account_sphere_points` ADD COLUMN `prismes` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Nexus prismatiques absorbes : +25 % de gains chacun''',
  'DO 0');
PREPARE s FROM @ajout; EXECUTE s; DEALLOCATE PREPARE s;
