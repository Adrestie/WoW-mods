-- mod-papota-spherier : chaîne de `.spherier wipeall` (2026-09-04).
-- Défaut anglais + locale frFR, comme les 54 précédentes.

DELETE FROM `module_string` WHERE `module` = 'mod-papota-spherier' AND `id` = 55;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-papota-spherier', 55, 'Sphere grid: account of {} wiped — {} character(s) reset, Spherite back to zero.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-papota-spherier' AND `id` = 55;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-papota-spherier', 55, 'frFR', 'Sphèrier : compte de {} effacé — {} personnage(s) remis à zéro, Spherite à zéro.');
