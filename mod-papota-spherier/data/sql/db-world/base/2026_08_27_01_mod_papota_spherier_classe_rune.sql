-- mod-papota-spherier : une rune de rang ne se sertit que dans le spherier de
-- SA classe (2026-08-27).
--
-- Elle se LOOTE toujours sans condition de classe — c'est le §6 et c'est voulu,
-- un guerrier peut trouver une rune de druide — mais elle n'entre pas dans sa
-- grille pour autant : l'etabli est la pour la refondre. La classe vit dans
-- `papota_sphere_rune.class_id`, ecrite par gen_rangs_sorts.py.
--
-- Les runes de STATISTIQUE ne sont pas concernees : elles majorent ce que la
-- grille donne, quelle que soit la classe.

DELETE FROM `module_string` WHERE `module` = 'mod-papota-spherier' AND `id` = 54;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-papota-spherier', 54, 'Sphere grid: that rune belongs to another class.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-papota-spherier' AND `id` = 54;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-papota-spherier', 54, 'frFR', 'Sphèrier : cette rune appartient à une autre classe.');
