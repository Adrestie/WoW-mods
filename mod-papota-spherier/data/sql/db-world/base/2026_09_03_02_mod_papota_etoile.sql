-- mod-papota-spherier : l'etoile du selenien et la marque de depart
-- (Retour stellaire, 8610020).
--
-- REFONTE DU 2026-09-03, troisieme temps. L'etoile portait le display 802102
-- — InvisibleStalker, opacite nulle — et son visuel venait d'une aura a kit
-- d'ETAT posee par le script. Rien ne s'affichait, ni avec un modele ni avec
-- un autre : le client n'avait aucun corps sur quoi accrocher le kit.
--
-- La creature EST desormais l'etoile. Son apparence pointe directement sur le
-- modele de l'effet (802103 rouge, 802104 jaune, 802105 verte, montees par
-- gen_visuel_druide.py depuis fx_spark_cast), et changer de couleur n'est
-- qu'un SetDisplayId. Elle nait VERTE, la couleur de la plus recente.
--
-- Elle ne se depop pas d'elle-meme : les etoiles ne s'effacent pas avec le
-- temps. C'est spell_papota_etoiles qui les reprend, a la quatrieme ou au
-- retour du druide.
--
-- 803817 est la MARQUE DE DEPART : la meme creature, l'apparence de
-- starfall_state_nosun (802106), posee a l'endroit que le druide quitte et
-- reprise au bout de deux secondes par son minuteur d'invocation.

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (803816, 803817);
DELETE FROM `creature_template` WHERE `entry` IN (803816, 803817);

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- 33554434 = NON_ATTACKABLE (0x2) + NOT_SELECTABLE (0x2000000).
UPDATE `papota_clone` SET `entry` = 803816, `name` = 'Etoile',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 33554434,
    `flags_extra` = 0, `AIName` = 'NullCreatureAI', `ScriptName` = '';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
UPDATE `papota_clone` SET `entry` = 803817, `name` = 'Depart stellaire';
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone`;

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803816, 0, 802105, 1, 1),
       (803817, 0, 802106, 1, 1);

DELETE FROM `creature_template_locale`
    WHERE `entry` IN (803816, 803817) AND `locale` = 'frFR';
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`)
VALUES (803816, 'frFR', 'Étoile', ''),
       (803817, 'frFR', 'Départ stellaire', '');
