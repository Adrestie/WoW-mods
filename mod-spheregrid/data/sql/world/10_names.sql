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

UPDATE `creature_template` SET `name` = 'Apocalypse Ghoul'      WHERE `entry` = 803801;
UPDATE `creature_template` SET `name` = 'Demonic Tyrant'        WHERE `entry` = 803802;
UPDATE `creature_template` SET `name` = 'Spirit Link Totem'     WHERE `entry` = 803803;
UPDATE `creature_template` SET `name` = 'Grapple Anchor'        WHERE `entry` = 803804;
UPDATE `creature_template` SET `name` = 'Arcane Orb'            WHERE `entry` = 803806;
UPDATE `creature_template` SET `name` = 'Shimmer Marker'        WHERE `entry` = 803810;
UPDATE `creature_template` SET `name` = 'Pack Beast'            WHERE `entry` = 803811;
UPDATE `creature_template` SET `name` = 'Angelic Feather'       WHERE `entry` = 803812;
UPDATE `creature_template` SET `name` = 'Barrier'               WHERE `entry` = 803813;
UPDATE `creature_template` SET `name` = 'Halo'                  WHERE `entry` = 803814;
UPDATE `creature_template` SET `name` = 'Halo'                  WHERE `entry` = 803815;
UPDATE `creature_template` SET `name` = 'Star'                  WHERE `entry` = 803816;
UPDATE `creature_template` SET `name` = 'Stellar Departure'     WHERE `entry` = 803817;

UPDATE `gameobject_template` SET `name` = 'Death Tunnel'        WHERE `entry` = 803820;

-- The French names, where they came from. Any other locale is added the same
-- way, and none of it changes the rows above.
DELETE FROM `creature_template_locale` WHERE `entry` BETWEEN 803800 AND 803899 AND `locale` = 'frFR';
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`, `VerifiedBuild`) VALUES
(803801, 'frFR', 'Goule d''apocalypse',   '', 0),
(803802, 'frFR', 'Tyran démoniaque',      '', 0),
(803803, 'frFR', 'Totem de lien d''esprit', '', 0),
(803804, 'frFR', 'Ancre de grappin',      '', 0),
(803806, 'frFR', 'Orbe des arcanes',      '', 0),
(803810, 'frFR', 'Marque de miroitement', '', 0),
(803811, 'frFR', 'Bête de meute',         '', 0),
(803812, 'frFR', 'Plume angélique',       '', 0),
(803813, 'frFR', 'Barrière',              '', 0),
(803814, 'frFR', 'Halo',                  '', 0),
(803815, 'frFR', 'Halo',                  '', 0),
(803816, 'frFR', 'Étoile',                '', 0),
(803817, 'frFR', 'Départ stellaire',      '', 0);

-- The workbench (803700) is not named here: it is shared, see 02_strings.sql.
DELETE FROM `gameobject_template_locale` WHERE `entry` = 803820 AND `locale` = 'frFR';
INSERT INTO `gameobject_template_locale` (`entry`, `locale`, `name`, `castBarCaption`, `VerifiedBuild`) VALUES
(803820, 'frFR', 'Tunnel de la mort',  '', 0);
