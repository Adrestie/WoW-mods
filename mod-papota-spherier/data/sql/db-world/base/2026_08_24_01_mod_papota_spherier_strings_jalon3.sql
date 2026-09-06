-- mod-papota-spherier : chaines du jalon 3 (sertissage, epingle, statistiques).
-- Defaut anglais + locale frFR, comme les 33 premieres.

DELETE FROM `module_string` WHERE `module` = 'mod-papota-spherier' AND `id` BETWEEN 34 AND 44;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-papota-spherier', 34, 'Sphere grid: {} socketed into cell {}.'),
('mod-papota-spherier', 35, 'Sphere grid: cell {} emptied — what it held is destroyed.'),
('mod-papota-spherier', 36, 'Sphere grid: cell {} is not active yet.'),
('mod-papota-spherier', 37, 'Sphere grid: cell {} already holds something.'),
('mod-papota-spherier', 38, 'Sphere grid: cell {} is already empty.'),
('mod-papota-spherier', 39, 'Sphere grid: that item cannot go into cell {}.'),
('mod-papota-spherier', 40, 'Sphere grid: you do not carry that item.'),
('mod-papota-spherier', 41, '{}''s sphere grid bonuses:'),
('mod-papota-spherier', 42, '  stat {}: +{}'),
('mod-papota-spherier', 43, 'Sphere grid: no bonus applied.'),
-- Ajoutee au jalon 5 : trois runes identiques au plus par sort (§6).
('mod-papota-spherier', 44, 'Sphere grid: three identical runes at most per spell.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-papota-spherier' AND `id` BETWEEN 34 AND 44;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-papota-spherier', 34, 'frFR', 'Sphèrier : {} serti dans l''emplacement {}.'),
('mod-papota-spherier', 35, 'frFR', 'Sphèrier : emplacement {} vidé — son contenu est détruit.'),
('mod-papota-spherier', 36, 'frFR', 'Sphèrier : l''emplacement {} n''est pas encore activé.'),
('mod-papota-spherier', 37, 'frFR', 'Sphèrier : l''emplacement {} contient déjà quelque chose.'),
('mod-papota-spherier', 38, 'frFR', 'Sphèrier : l''emplacement {} est déjà vide.'),
('mod-papota-spherier', 39, 'frFR', 'Sphèrier : cet objet ne peut pas aller dans l''emplacement {}.'),
('mod-papota-spherier', 40, 'frFR', 'Sphèrier : vous ne portez pas cet objet.'),
('mod-papota-spherier', 41, 'frFR', 'Bonus de sphèrier de {} :'),
('mod-papota-spherier', 42, 'frFR', '  statistique {} : +{}'),
('mod-papota-spherier', 43, 'frFR', 'Sphèrier : aucun bonus appliqué.'),
('mod-papota-spherier', 44, 'frFR', 'Sphèrier : trois runes identiques au maximum par sort.');
