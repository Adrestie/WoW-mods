-- mod-papota-spherier : l'etabli (§9, revision du 2026-08-27).
--
-- Trois recettes, et non quatre : une rune ne s'ameliore pas, elle se refond.
--   fusion   3 pierres identiques      -> 1 pierre de la qualite au-dessus
--   relance  2 pierres de meme qualite -> 1 pierre, meme qualite, autre effet
--   refonte  3 runes quelconques       -> 1 rune tiree dans tout le catalogue
--
-- L'etabli est un OBJET DE MONDE. Ce fichier pose son gabarit ; les apparitions
-- se posent en jeu, a la main, avec `.gobject add 803700`.

DELETE FROM `module_string` WHERE `module` = 'mod-papota-spherier' AND `id` BETWEEN 45 AND 53;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-papota-spherier', 45, 'Workbench: item {} crafted.'),
('mod-papota-spherier', 46, 'Workbench: that is not a sphere grid stone.'),
('mod-papota-spherier', 47, 'Workbench: that is not a sphere grid rune.'),
('mod-papota-spherier', 48, 'Workbench: merging takes three times the same stone.'),
('mod-papota-spherier', 49, 'Workbench: both stones must be of the same quality.'),
('mod-papota-spherier', 50, 'Workbench: there is nothing above that quality.'),
('mod-papota-spherier', 51, 'Workbench: nothing could be drawn.'),
('mod-papota-spherier', 52, 'Workbench: you do not carry those items.'),
('mod-papota-spherier', 53, 'Workbench: your bags are full.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-papota-spherier' AND `id` BETWEEN 45 AND 53;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-papota-spherier', 45, 'frFR', 'Établi : objet {} fabriqué.'),
('mod-papota-spherier', 46, 'frFR', 'Établi : ceci n''est pas une pierre du sphèrier.'),
('mod-papota-spherier', 47, 'frFR', 'Établi : ceci n''est pas une rune du sphèrier.'),
('mod-papota-spherier', 48, 'frFR', 'Établi : la fusion demande trois fois la même pierre.'),
('mod-papota-spherier', 49, 'frFR', 'Établi : les deux pierres doivent être de même qualité.'),
('mod-papota-spherier', 50, 'frFR', 'Établi : il n''y a rien au-dessus de cette qualité.'),
('mod-papota-spherier', 51, 'frFR', 'Établi : rien à tirer.'),
('mod-papota-spherier', 52, 'frFR', 'Établi : vous ne portez pas ces objets.'),
('mod-papota-spherier', 53, 'frFR', 'Établi : vos sacs sont pleins.');

-- L'objet de monde. Type 3 et un identifiant d'affichage de forge de runes :
-- le meme montage que le coffre hebdomadaire du mythique+, dont on sait qu'il
-- repond bien a l'evenement d'utilisation cote Lua sur ce serveur.
DELETE FROM `gameobject_template` WHERE `entry` = 803700;
INSERT INTO `gameobject_template`
  (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`,
   `size`, `Data0`, `Data1`, `Data2`, `Data3`, `ScriptName`) VALUES
(803700, 3, 8176, 'Sphere Grid Workbench', '', '', '', 1.6, 0, 0, 0, 0, '');

DELETE FROM `gameobject_template_locale` WHERE `entry` = 803700;
INSERT INTO `gameobject_template_locale` (`entry`, `locale`, `name`, `castBarCaption`) VALUES
(803700, 'frFR', 'Établi du sphèrier', '');
