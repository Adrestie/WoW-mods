-- mod-spheregrid — the names of the creatures and game objects, in English.
--
-- The module ships its content in English by default, like the items do, and
-- carries the other languages in the `*_locale` tables. A server that speaks
-- another language adds its own rows there without touching these.
--
-- These creatures are summons and props: a player sees their name in a tooltip,
-- a floating damage number or a right click, so they must read like the rest of
-- his game.
--
-- Regenerable: every row is rewritten, nothing else is touched.

UPDATE `creature_template` SET `name` = 'Apocalypse Ghoul'      WHERE `entry` = 85801;
UPDATE `creature_template` SET `name` = 'Demonic Tyrant'        WHERE `entry` = 85802;
UPDATE `creature_template` SET `name` = 'Spirit Link Totem'     WHERE `entry` = 85803;
UPDATE `creature_template` SET `name` = 'Grapple Anchor'        WHERE `entry` = 85804;
UPDATE `creature_template` SET `name` = 'Arcane Orb'            WHERE `entry` = 85806;
UPDATE `creature_template` SET `name` = 'Shimmer Marker'        WHERE `entry` = 85810;
UPDATE `creature_template` SET `name` = 'Pack Beast'            WHERE `entry` = 85811;
UPDATE `creature_template` SET `name` = 'Angelic Feather'       WHERE `entry` = 85812;
UPDATE `creature_template` SET `name` = 'Barrier'               WHERE `entry` = 85813;
UPDATE `creature_template` SET `name` = 'Halo'                  WHERE `entry` = 85814;
UPDATE `creature_template` SET `name` = 'Halo'                  WHERE `entry` = 85815;
UPDATE `creature_template` SET `name` = 'Star'                  WHERE `entry` = 85816;
UPDATE `creature_template` SET `name` = 'Stellar Departure'     WHERE `entry` = 85817;

UPDATE `gameobject_template` SET `name` = 'Death Tunnel'        WHERE `entry` = 850820;

-- The French names, where they came from. Any other locale is added the same
-- way, and none of it changes the rows above.
DELETE FROM `creature_template_locale` WHERE `entry` BETWEEN 85800 AND 85899 AND `locale` = 'frFR';
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`, `VerifiedBuild`) VALUES
(85801, 'frFR', 'Goule d''apocalypse',   '', 0),
(85802, 'frFR', 'Tyran démoniaque',      '', 0),
(85803, 'frFR', 'Totem de lien d''esprit', '', 0),
(85804, 'frFR', 'Ancre de grappin',      '', 0),
(85806, 'frFR', 'Orbe des arcanes',      '', 0),
(85810, 'frFR', 'Marque de miroitement', '', 0),
(85811, 'frFR', 'Bête de meute',         '', 0),
(85812, 'frFR', 'Plume angélique',       '', 0),
(85813, 'frFR', 'Barrière',              '', 0),
(85814, 'frFR', 'Halo',                  '', 0),
(85815, 'frFR', 'Halo',                  '', 0),
(85816, 'frFR', 'Étoile',                '', 0),
(85817, 'frFR', 'Départ stellaire',      '', 0);

-- The workbench (810000) is not named here: it is shared, see 02_strings.sql.
DELETE FROM `gameobject_template_locale` WHERE `entry` = 850820 AND `locale` = 'frFR';
INSERT INTO `gameobject_template_locale` (`entry`, `locale`, `name`, `castBarCaption`, `VerifiedBuild`) VALUES
(850820, 'frFR', 'Tunnel de la mort',  '', 0);
