-- mod-papota-spherier : emplacements de sort custom (revision du 2026-08-23).
-- Un troisieme type d'emplacement (kind 2) porte un sort custom inedit, fixe
-- dans la grille. Un noeud (kind 0) peut desormais etre vide
-- (default_stone_entry = 0). Application unique, consignee dans `updates`.

ALTER TABLE `papota_sphere_node`
  ADD COLUMN `spell_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'sort custom appris (kind 2 uniquement)';

-- La ligne d'info par classe compte desormais les sorts.
UPDATE `module_string` SET `string` = '  Class {}: {} node(s), {} socket(s), {} spell(s), start {}.'
  WHERE `module` = 'mod-papota-spherier' AND `id` = 2;
UPDATE `module_string_locale` SET `string` = '  Classe {} : {} nœud(s), {} slot(s), {} sort(s), départ {}.'
  WHERE `module` = 'mod-papota-spherier' AND `id` = 2 AND `locale` = 'frFR';
