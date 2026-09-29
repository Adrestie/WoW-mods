-- mod-attriboost — EVERY text the module shows, in each language.
--
-- This file is the single source of the module's texts: the C++ module, the
-- server-side Lua script and the interface all read them from here, and none
-- of them carries a text of its own.
--
-- English in `module_string`; every other language in `module_string_locale`.
-- Each player gets the row of their client's language, English when it has
-- none. Numbers:
--   1-99   messages: the chat commands (src/Attriboost.h, AttriboostStrings)
--          and the server-side Lua script (MSG in Attriboost_Serveur.lua);
--   101+   the interface (ID and ID_NOMS in Attriboost_Client.lua).
-- A number is never reused once retired.
--
-- Adding a language takes one INSERT per number into `module_string_locale`,
-- with the locale code of that client (deDE, esES, ruRU...): no rebuild, only a
-- restart. `{}` stands for a value and must be kept, as many times as in English.

DELETE FROM `module_string` WHERE `module` = 'mod-attriboost';
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-attriboost',   1, 'The attribute system is disabled.'),
('mod-attriboost',   2, 'Invalid number of books.'),
('mod-attriboost',   3, 'You do not have enough Tomes of Knowledge.'),
('mod-attriboost',   4, 'You receive {} attribute point(s).'),
('mod-attriboost',   5, 'You do not have enough Books of Talents.'),
('mod-attriboost',   6, 'You receive {} talent point(s).'),
('mod-attriboost',   7, 'Unknown statistic.'),
('mod-attriboost',   8, 'Invalid number of points.'),
('mod-attriboost',   9, 'You do not have enough points available.'),
('mod-attriboost',  10, 'This attribute is already at its maximum.'),
('mod-attriboost',  11, '{} point(s) allocated: the maximum has been reached.'),
('mod-attriboost',  12, 'No points to reset.'),
('mod-attriboost',  13, 'You do not have enough money.'),
('mod-attriboost',  14, 'Attributes reset.'),
('mod-attriboost',  15, 'The cap of this statistic would be exceeded.'),
('mod-attriboost', 101, 'Attributes'),
('mod-attriboost', 102, 'available'),
('mod-attriboost', 103, 'Tome of Knowledge'),
('mod-attriboost', 104, 'Book of Talents'),
('mod-attriboost', 105, 'In bags: {}'),
('mod-attriboost', 106, '{} attribute points per book'),
('mod-attriboost', 107, '1 talent point per book'),
('mod-attriboost', 108, 'Exchange'),
('mod-attriboost', 109, 'All'),
('mod-attriboost', 110, 'Confirm'),
('mod-attriboost', 111, 'Cancel'),
('mod-attriboost', 112, 'Reset'),
('mod-attriboost', 113, '{} per point'),
('mod-attriboost', 114, '(+{})'),
('mod-attriboost', 115, '+{} attribute point(s)'),
('mod-attriboost', 116, '+{} talent point(s)'),
('mod-attriboost', 117, 'Reset all attributes for {}?\nPoints return to the pool.'),
('mod-attriboost', 118, 'Click: 1 point — Shift: 5 — Ctrl: 10'),
('mod-attriboost', 119, 'Click: open or close the window'),
('mod-attriboost', 120, 'Progression'),
('mod-attriboost', 131, 'Stamina'),
('mod-attriboost', 132, 'Strength'),
('mod-attriboost', 133, 'Agility'),
('mod-attriboost', 134, 'Intellect'),
('mod-attriboost', 135, 'Spirit'),
('mod-attriboost', 136, 'Spell damage'),
('mod-attriboost', 137, 'Critical strike damage'),
('mod-attriboost', 138, 'All resistances'),
('mod-attriboost', 139, 'Spell penetration'),
('mod-attriboost', 140, 'Healing power');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-attriboost';
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-attriboost',   1, 'frFR', 'Le système d''attributs est désactivé.'),
('mod-attriboost',   2, 'frFR', 'Nombre de livres invalide.'),
('mod-attriboost',   3, 'frFR', 'Vous n''avez pas assez de Tomes du Savoir.'),
('mod-attriboost',   4, 'frFR', 'Vous obtenez {} point(s) d''attribut.'),
('mod-attriboost',   5, 'frFR', 'Vous n''avez pas assez de Livres des talents.'),
('mod-attriboost',   6, 'frFR', 'Vous obtenez {} point(s) de talent.'),
('mod-attriboost',   7, 'frFR', 'Statistique inconnue.'),
('mod-attriboost',   8, 'frFR', 'Nombre de points invalide.'),
('mod-attriboost',   9, 'frFR', 'Vous n''avez pas assez de points disponibles.'),
('mod-attriboost',  10, 'frFR', 'Cet attribut est déjà au maximum.'),
('mod-attriboost',  11, 'frFR', '{} point(s) attribué(s) : le maximum est atteint.'),
('mod-attriboost',  12, 'frFR', 'Aucun point à réinitialiser.'),
('mod-attriboost',  13, 'frFR', 'Vous n''avez pas assez d''argent.'),
('mod-attriboost',  14, 'frFR', 'Attributs réinitialisés.'),
('mod-attriboost',  15, 'frFR', 'Le plafond de cette statistique serait dépassé.'),
('mod-attriboost', 101, 'frFR', 'Attributs'),
('mod-attriboost', 102, 'frFR', 'disponible(s)'),
('mod-attriboost', 103, 'frFR', 'Tome du Savoir'),
('mod-attriboost', 104, 'frFR', 'Livre des talents'),
('mod-attriboost', 105, 'frFR', 'En sac : {}'),
('mod-attriboost', 106, 'frFR', '{} points d''attribut par livre'),
('mod-attriboost', 107, 'frFR', '1 point de talent par livre'),
('mod-attriboost', 108, 'frFR', 'Échanger'),
('mod-attriboost', 109, 'frFR', 'Tout'),
('mod-attriboost', 110, 'frFR', 'Valider'),
('mod-attriboost', 111, 'frFR', 'Annuler'),
('mod-attriboost', 112, 'frFR', 'Réinitialiser'),
('mod-attriboost', 113, 'frFR', '{} par point'),
('mod-attriboost', 114, 'frFR', '(+{})'),
('mod-attriboost', 115, 'frFR', '+{} point(s) d''attribut'),
('mod-attriboost', 116, 'frFR', '+{} point(s) de talent'),
('mod-attriboost', 117, 'frFR', 'Réinitialiser tous les attributs pour {} ?\nLes points reviendront dans la réserve.'),
('mod-attriboost', 118, 'frFR', 'Clic : 1 point — Maj : 5 — Ctrl : 10'),
('mod-attriboost', 119, 'frFR', 'Clic : ouvrir ou fermer la fenêtre'),
('mod-attriboost', 120, 'frFR', 'Progression'),
('mod-attriboost', 131, 'frFR', 'Endurance'),
('mod-attriboost', 132, 'frFR', 'Force'),
('mod-attriboost', 133, 'frFR', 'Agilité'),
('mod-attriboost', 134, 'frFR', 'Intelligence'),
('mod-attriboost', 135, 'frFR', 'Esprit'),
('mod-attriboost', 136, 'frFR', 'Dégâts des sorts'),
('mod-attriboost', 137, 'frFR', 'Dégâts des coups critiques'),
('mod-attriboost', 138, 'frFR', 'Toutes les résistances'),
('mod-attriboost', 139, 'frFR', 'Pénétration des sorts'),
('mod-attriboost', 140, 'frFR', 'Puissance des soins');
