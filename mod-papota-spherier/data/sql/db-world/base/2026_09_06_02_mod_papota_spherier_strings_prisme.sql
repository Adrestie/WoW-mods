-- mod-papota-spherier : chaînes du Nexus prismatique (2026-09-06).
-- Défaut anglais + locale frFR, comme les 55 précédentes.

DELETE FROM `module_string` WHERE `module` = 'mod-papota-spherier' AND `id` IN (56, 57);
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-papota-spherier', 56, 'Prismatic Nexus absorbed: {} prism(s) — all Spherite gains of your account are now +{}%.'),
('mod-papota-spherier', 57, 'Prismatic Nexus: {} absorbed — Spherite gains +{}%.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-papota-spherier' AND `id` IN (56, 57);
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-papota-spherier', 56, 'frFR', 'Nexus prismatique absorbé : {} prisme(s) — tous les gains de Spherite de votre compte sont majorés de {} %.'),
('mod-papota-spherier', 57, 'frFR', 'Nexus prismatiques : {} absorbé(s) — gains de Spherite majorés de {} %.');
