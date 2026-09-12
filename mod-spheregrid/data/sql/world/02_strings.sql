--
-- Regenerable: every block deletes its own range before writing it
-- again, so the file may be replayed at will.

-- ------------------------------------------------------------------
-- The command's messages
-- ------------------------------------------------------------------
-- English by default; every other language is served from module_string_locale,
-- falling back on English.

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` BETWEEN 1 AND 33;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid',  1, 'Sphere grid: {} cells, {} links, {} class(es) defined.'),
('mod-spheregrid',  2, '  Class {}: {} node(s), {} socket(s), {} spell(s), start {}.'),
('mod-spheregrid',  3, 'Cost scale: {} bracket(s).'),
('mod-spheregrid',  4, '  From {} cell(s) bought: {} Spherite.'),
('mod-spheregrid',  5, 'Nexus items: {}. Content hooks: {}.'),
('mod-spheregrid',  6, '  {} ({}): {} Spherite.'),
('mod-spheregrid',  7, 'Sphere grid: definition reloaded - {} cells, {} links.'),
('mod-spheregrid',  8, 'Sphere grid: player not found or offline.'),
('mod-spheregrid',  9, '{}''s sphere grid: {} Spherite available ({} earned, {} spent).'),
('mod-spheregrid', 10, 'Active: {} cell(s) out of {} (class {}). Next cost: {} Spherite.'),
('mod-spheregrid', 11, 'Sphere grid: no state loaded for {} (playerbot?).'),
('mod-spheregrid', 12, 'Usage: .spheregrid points {} <amount> [player]'),
('mod-spheregrid', 13, 'Target: the named player, else your target, else yourself.'),
('mod-spheregrid', 14, 'Adds <amount> Spherite.'),
('mod-spheregrid', 15, 'Removes <amount> Spherite, capped at the available amount.'),
('mod-spheregrid', 16, 'Sets AVAILABLE Spherite to <amount> (0 allowed).'),
('mod-spheregrid', 17, 'Sphere grid: {} credited {} Spherite, available: {}.'),
('mod-spheregrid', 18, 'Sphere grid: {} debited {} Spherite (requested: {}), available: {}.'),
('mod-spheregrid', 19, 'Sphere grid: {}''s available Spherite set to {}.'),
('mod-spheregrid', 20, 'Sphere grid: cell {} activated ({} active, {} Spherite left).'),
('mod-spheregrid', 21, 'Sphere grid: no state loaded for this character.'),
('mod-spheregrid', 22, 'Sphere grid: cell {} does not exist.'),
('mod-spheregrid', 23, 'Sphere grid: cell {} does not belong to your class grid.'),
('mod-spheregrid', 24, 'Sphere grid: cell {} is already active.'),
('mod-spheregrid', 25, 'Sphere grid: cell {} is neither the start nor adjacent to an active cell.'),
('mod-spheregrid', 26, 'Sphere grid: not enough Spherite.'),
('mod-spheregrid', 27, 'Sphere grid: {}''s state wiped (Spherite and activations).'),
('mod-spheregrid', 28, 'Sphere grid: interface unavailable (Lua script not loaded).'),
('mod-spheregrid', 29, 'Sphere grid: editor unavailable (Lua script not loaded).'),
('mod-spheregrid', 30, 'You gain {} Spherite.'),
('mod-spheregrid', 31, 'You lose {} Spherite.'),
('mod-spheregrid', 32, 'Your available Spherite is now {}.'),
('mod-spheregrid', 33, 'Sphere grid: no Spherite configured for source {} ({}).');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` BETWEEN 1 AND 33;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid',  1, 'frFR', 'Sphèrier : {} emplacements, {} liaisons, {} classe(s) définies.'),
('mod-spheregrid',  2, 'frFR', '  Classe {} : {} nœud(s), {} slot(s), {} sort(s), départ {}.'),
('mod-spheregrid',  3, 'frFR', 'Barème de coût : {} tranche(s).'),
('mod-spheregrid',  4, 'frFR', '  À partir de {} emplacement(s) acheté(s) : {} Spherites.'),
('mod-spheregrid',  5, 'frFR', 'Nexus : {}. Sources d''accroche : {}.'),
('mod-spheregrid',  6, 'frFR', '  {} ({}) : {} Spherites.'),
('mod-spheregrid',  7, 'frFR', 'Sphèrier : définition rechargée - {} emplacements, {} liaisons.'),
('mod-spheregrid',  8, 'frFR', 'Sphèrier : joueur introuvable ou hors ligne.'),
('mod-spheregrid',  9, 'frFR', 'Sphèrier de {} : {} Spherites disponibles ({} gagnées, {} dépensées).'),
('mod-spheregrid', 10, 'frFR', 'Actifs : {} emplacement(s) sur {} (classe {}). Prochain coût : {} Spherites.'),
('mod-spheregrid', 11, 'frFR', 'Sphèrier : pas d''état chargé pour {} (playerbot ?).'),
('mod-spheregrid', 12, 'frFR', 'Usage : .spheregrid points {} <montant> [joueur]'),
('mod-spheregrid', 13, 'frFR', 'Cible : le joueur nommé, sinon la cible, sinon soi-même.'),
('mod-spheregrid', 14, 'frFR', 'Ajoute <montant> Spherites.'),
('mod-spheregrid', 15, 'frFR', 'Retire <montant> Spherites, plafonné à ce qui est disponible.'),
('mod-spheregrid', 16, 'frFR', 'Fixe les Spherites DISPONIBLES à <montant> (0 permis).'),
('mod-spheregrid', 17, 'frFR', 'Sphèrier : {} crédité de {} Spherites, disponibles : {}.'),
('mod-spheregrid', 18, 'frFR', 'Sphèrier : {} débité de {} Spherites (demandé : {}), disponibles : {}.'),
('mod-spheregrid', 19, 'frFR', 'Sphèrier : Spherites disponibles de {} fixées à {}.'),
('mod-spheregrid', 20, 'frFR', 'Sphèrier : emplacement {} activé ({} actifs, {} Spherites restantes).'),
('mod-spheregrid', 21, 'frFR', 'Sphèrier : pas d''état chargé pour ce personnage.'),
('mod-spheregrid', 22, 'frFR', 'Sphèrier : l''emplacement {} n''existe pas.'),
('mod-spheregrid', 23, 'frFR', 'Sphèrier : l''emplacement {} n''appartient pas à la grille de votre classe.'),
('mod-spheregrid', 24, 'frFR', 'Sphèrier : l''emplacement {} est déjà activé.'),
('mod-spheregrid', 25, 'frFR', 'Sphèrier : l''emplacement {} n''est ni le départ ni voisin d''un emplacement actif.'),
('mod-spheregrid', 26, 'frFR', 'Sphèrier : Spherite insuffisante.'),
('mod-spheregrid', 27, 'frFR', 'Sphèrier : état de {} remis à zéro (Spherites et activations).'),
('mod-spheregrid', 28, 'frFR', 'Sphèrier : interface indisponible (script Lua non chargé).'),
('mod-spheregrid', 29, 'frFR', 'Sphèrier : éditeur indisponible (script Lua non chargé).'),
('mod-spheregrid', 30, 'frFR', 'Vous gagnez {} Spherites.'),
('mod-spheregrid', 31, 'frFR', 'Vous perdez {} Spherites.'),
('mod-spheregrid', 32, 'frFR', 'Vos Spherites disponibles sont désormais {}.'),
('mod-spheregrid', 33, 'frFR', 'Sphèrier : aucune Spherite configurée pour la source {} ({}).');

-- ------------------------------------------------------------------
-- Socketing and emptying
-- ------------------------------------------------------------------

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` BETWEEN 34 AND 44;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid', 34, 'Sphere grid: {} socketed into cell {}.'),
('mod-spheregrid', 35, 'Sphere grid: cell {} emptied — what it held is destroyed.'),
('mod-spheregrid', 36, 'Sphere grid: cell {} is not active yet.'),
('mod-spheregrid', 37, 'Sphere grid: cell {} already holds something.'),
('mod-spheregrid', 38, 'Sphere grid: cell {} is already empty.'),
('mod-spheregrid', 39, 'Sphere grid: that item cannot go into cell {}.'),
('mod-spheregrid', 40, 'Sphere grid: you do not carry that item.'),
('mod-spheregrid', 41, '{}''s sphere grid bonuses:'),
('mod-spheregrid', 42, '  stat {}: +{}'),
('mod-spheregrid', 43, 'Sphere grid: no bonus applied.'),
('mod-spheregrid', 44, 'Sphere grid: three identical runes at most per spell.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` BETWEEN 34 AND 44;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid', 34, 'frFR', 'Sphèrier : {} serti dans l''emplacement {}.'),
('mod-spheregrid', 35, 'frFR', 'Sphèrier : emplacement {} vidé — son contenu est détruit.'),
('mod-spheregrid', 36, 'frFR', 'Sphèrier : l''emplacement {} n''est pas encore activé.'),
('mod-spheregrid', 37, 'frFR', 'Sphèrier : l''emplacement {} contient déjà quelque chose.'),
('mod-spheregrid', 38, 'frFR', 'Sphèrier : l''emplacement {} est déjà vide.'),
('mod-spheregrid', 39, 'frFR', 'Sphèrier : cet objet ne peut pas aller dans l''emplacement {}.'),
('mod-spheregrid', 40, 'frFR', 'Sphèrier : vous ne portez pas cet objet.'),
('mod-spheregrid', 41, 'frFR', 'Bonus de sphèrier de {} :'),
('mod-spheregrid', 42, 'frFR', '  statistique {} : +{}'),
('mod-spheregrid', 43, 'frFR', 'Sphèrier : aucun bonus appliqué.'),
('mod-spheregrid', 44, 'frFR', 'Sphèrier : trois runes identiques au maximum par sort.');

-- ------------------------------------------------------------------
-- A rune of another class
-- ------------------------------------------------------------------
-- A rune may be socketed only by the class it was made for.

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` = 54;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid', 54, 'Sphere grid: that rune belongs to another class.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` = 54;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid', 54, 'frFR', 'Sphèrier : cette rune appartient à une autre classe.');

-- ------------------------------------------------------------------
-- Wiping an account
-- ------------------------------------------------------------------

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` = 55;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid', 55, 'Sphere grid: account of {} wiped — {} character(s) reset, Spherite back to zero.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` = 55;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid', 55, 'frFR', 'Sphèrier : compte de {} effacé — {} personnage(s) remis à zéro, Spherite à zéro.');

-- ------------------------------------------------------------------
-- The prismatic Nexus
-- ------------------------------------------------------------------

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` IN (56, 57);
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid', 56, 'Prismatic Nexus absorbed: {} prism(s) — all Spherite gains of your account are now +{}%.'),
('mod-spheregrid', 57, 'Prismatic Nexus: {} absorbed — Spherite gains +{}%.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` IN (56, 57);
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid', 56, 'frFR', 'Nexus prismatique absorbé : {} prisme(s) — tous les gains de Spherite de votre compte sont majorés de {} %.'),
('mod-spheregrid', 57, 'frFR', 'Nexus prismatiques : {} absorbé(s) — gains de Spherite majorés de {} %.');

-- ------------------------------------------------------------------
-- Mercy on the drop rate
-- ------------------------------------------------------------------
--

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` IN (58, 59, 60, 61);
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid', 58, 'Fate encourages you. Your chance of finding a Nexus is increased.'),
('mod-spheregrid', 59, 'Fortune smiles upon you. You have a strong chance of finding a Nexus.'),
('mod-spheregrid', 60, 'History will remember you as gloriously unlucky... but the wheel is about to turn!'),
('mod-spheregrid', 61, 'please, go see a witch doctor or an exorcist, because at this point it is getting scary...');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` IN (58, 59, 60, 61);
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid', 58, 'frFR', 'Le destin vous encourage. Vous avez une chance accrue de trouver un Nexus'),
('mod-spheregrid', 59, 'frFR', 'La chance vous sourit. Vous avez de grandes chances de trouver un Nexus'),
('mod-spheregrid', 60, 'frFR', 'L''histoire se souviendra de vous comme d''un grand malchanceux... mais la roue va bientôt tourner !'),
('mod-spheregrid', 61, 'frFR', 's''il te plait, va voir un marabou ou un exorciste car là, c''est flippant...');

-- ------------------------------------------------------------------
-- Grinding a stone or a rune
-- ------------------------------------------------------------------

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` IN (62, 63);
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid', 63, 'Only a stone or a rune can be ground down.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` IN (62, 63);
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid', 63, 'frFR', 'Seule une pierre ou une rune peut être broyée.');

-- ------------------------------------------------------------------
-- Where an award comes from
-- ------------------------------------------------------------------
-- Every gain of Spherite says what earned it, so that a player never has to
-- guess. Id 30 is the plain wording, used when the source has no line of its own.

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` IN (30, 64, 65, 66, 67, 68, 69, 70, 71, 72);
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid', 30, 'You gain {1} Spherite.'),
('mod-spheregrid', 64, 'Your level up grants you {1} Spherite.'),
('mod-spheregrid', 65, 'Your achievement "{0}" grants you {1} Spherite.'),
('mod-spheregrid', 66, 'Your victory over "{0}" grants you {1} Spherite.'),
('mod-spheregrid', 67, 'Recycling your stone "{0}" grants you {1} Spherite.'),
('mod-spheregrid', 68, 'Recycling your rune "{0}" grants you {1} Spherite.'),
('mod-spheregrid', 69, 'Completing the dungeon "{0}" grants you {1} Spherite.'),
('mod-spheregrid', 70, 'Using the "{0}" grants you {1} Spherite.'),
('mod-spheregrid', 71, 'Completing the quest "{0}" grants you {1} Spherite.'),
('mod-spheregrid', 72, 'Your Mythic+ key of tier {0} grants you {1} Spherite.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` IN (30, 64, 65, 66, 67, 68, 69, 70, 71, 72);
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid', 30, 'frFR', 'Vous gagnez {1} Spherites.'),
('mod-spheregrid', 64, 'frFR', 'Votre montée de niveau vous octroie {1} Spherites.'),
('mod-spheregrid', 65, 'frFR', 'Votre haut fait « {0} » vous octroie {1} Spherites.'),
('mod-spheregrid', 66, 'frFR', 'Votre victoire sur « {0} » vous octroie {1} Spherites.'),
('mod-spheregrid', 67, 'frFR', 'Le recyclage de votre pierre « {0} » vous octroie {1} Spherites.'),
('mod-spheregrid', 68, 'frFR', 'Le recyclage de votre rune « {0} » vous octroie {1} Spherites.'),
('mod-spheregrid', 69, 'frFR', 'La complétion du donjon « {0} » vous octroie {1} Spherites.'),
('mod-spheregrid', 70, 'frFR', 'L''utilisation du « {0} » vous octroie {1} Spherites.'),
('mod-spheregrid', 71, 'frFR', 'La réussite de la quête « {0} » vous octroie {1} Spherites.'),
('mod-spheregrid', 72, 'frFR', 'Votre clé mythique de rang {0} vous octroie {1} Spherites.');

-- ------------------------------------------------------------------
-- Handing the progression back
-- ------------------------------------------------------------------

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` = 73;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid', 73, 'Sphere grid: progression reset — {} Spherite returned. Stones and runes stay in their cells.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` = 73;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid', 73, 'frFR', 'Sphèrier : progression réinitialisée — {} Spherite rendue. Les pierres et les runes restent dans leurs emplacements.');

-- ------------------------------------------------------------------
-- The workbench
-- ------------------------------------------------------------------
-- Its four recipes refuse in its own words: what the item is, what quality it
-- is, and whether the bags can take what comes out.

DELETE FROM `module_string` WHERE `module` = 'mod-spheregrid' AND `id` BETWEEN 45 AND 53;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-spheregrid', 46, 'Workbench: that is not a sphere grid stone.'),
('mod-spheregrid', 47, 'Workbench: that is not a sphere grid rune.'),
('mod-spheregrid', 48, 'Workbench: merging takes three times the same stone.'),
('mod-spheregrid', 49, 'Workbench: both stones must be of the same quality.'),
('mod-spheregrid', 50, 'Workbench: there is nothing above that quality.'),
('mod-spheregrid', 51, 'Workbench: nothing could be drawn.'),
('mod-spheregrid', 52, 'Workbench: you do not carry those items.'),
('mod-spheregrid', 53, 'Workbench: your bags are full.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-spheregrid' AND `id` BETWEEN 45 AND 53;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-spheregrid', 46, 'frFR', 'Établi : ceci n''est pas une pierre du sphèrier.'),
('mod-spheregrid', 47, 'frFR', 'Établi : ceci n''est pas une rune du sphèrier.'),
('mod-spheregrid', 48, 'frFR', 'Établi : la fusion demande trois fois la même pierre.'),
('mod-spheregrid', 49, 'frFR', 'Établi : les deux pierres doivent être de même qualité.'),
('mod-spheregrid', 50, 'frFR', 'Établi : il n''y a rien au-dessus de cette qualité.'),
('mod-spheregrid', 51, 'frFR', 'Établi : rien à tirer.'),
('mod-spheregrid', 52, 'frFR', 'Établi : vous ne portez pas ces objets.'),
('mod-spheregrid', 53, 'frFR', 'Établi : vos sacs sont pleins.');

-- THE WORKBENCH IS SHARED with the other modules of the repository that
-- have recipes: one template, the same in every module, inserted ONLY WHEN
-- ABSENT -- whoever installs first puts it down, nobody rewrites it -- and
-- no DELETE here, on purpose: the remover replays the deletes of this SQL,
-- and the object must outlive this module when another provider still
-- uses it. The remover takes it out itself, when it is the last to go.
INSERT IGNORE INTO `gameobject_template`
  (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`,
   `size`, `Data0`, `Data1`, `Data2`, `Data3`, `ScriptName`) VALUES
(803700, 3, 8176, 'Workbench', '', '', '', 1.6, 0, 0, 0, 0, '');

INSERT IGNORE INTO `gameobject_template_locale` (`entry`, `locale`, `name`, `castBarCaption`) VALUES
(803700, 'frFR', 'Établi', '');

-- ------------------------------------------------------------------
-- The wording of the spell counts
-- ------------------------------------------------------------------
UPDATE `module_string` SET `string` = '  Class {}: {} node(s), {} socket(s), {} spell(s), start {}.'
  WHERE `module` = 'mod-spheregrid' AND `id` = 2;
UPDATE `module_string_locale` SET `string` = '  Classe {} : {} nœud(s), {} slot(s), {} sort(s), départ {}.'
  WHERE `module` = 'mod-spheregrid' AND `id` = 2 AND `locale` = 'frFR';

