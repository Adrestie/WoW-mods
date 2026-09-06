-- mod-papota-spherier : le tyran demoniaque (sort 8600082).
--
-- La creature 803802 existait deja sous le nom « Garde funeste du tyran » :
-- un clone du garde funeste 11859, apparence empruntee, pose par le fichier
-- 2026_08_27_04_mod_papota_invocations.sql. Celui-la ne peut pas etre rejoue
-- (INSERT ... SELECT sans DELETE prealable), d'ou ce fichier a part.
--
-- Elle devient LE TYRAN : son propre nom, son propre modele (802130, pose
-- dans CreatureModelData / CreatureDisplayInfo par gen_visuel_demoniste.py,
-- cote client ET cote serveur), et l'IA npc_papota_tyran qui porte les degats
-- de zone et les bonus aux demons.

UPDATE `creature_template`
SET `name` = 'Tyran demoniaque',
    `subname` = '',
    `ScriptName` = 'npc_papota_tyran'
WHERE `entry` = 803802;

-- L'apparence : une seule ligne, la notre. Le clone en avait herite plusieurs
-- du garde funeste, tirees au sort a chaque invocation.
DELETE FROM `creature_template_model` WHERE `CreatureID` = 803802;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803802, 0, 802130, 1, 1);

-- Le nom francais, pour le client frFR.
DELETE FROM `creature_template_locale` WHERE `entry` = 803802 AND `locale` = 'frFR';
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`)
VALUES (803802, 'frFR', 'Tyran démoniaque', '');

-- LE GABARIT ETAIT CELUI D'UN GARDE FUNESTE DE NIVEAU 57, et il portait un
-- deplacement ALEATOIRE (MovementType 1) qui se battait avec la poursuite de
-- l'IA. Les deux expliquent qu'il restait plante la. Le niveau est desormais
-- aligne sur le joueur par npc_papota_tyran (SetLevel), mais le gabarit doit
-- l'annoncer aussi, sans quoi ses points de vie sont calcules sur 57.
--
-- PV MAX x10 (demande du 2026-09-03) : HealthModifier passe de 1,3 a 13. Avec
-- basehp2 = 12 600 au niveau 80 (creature_classlevelstats, exp = 2), cela
-- donne 163 800 PV, contre 5 790 auparavant au niveau 57.
UPDATE `creature_template`
SET `minlevel` = 80,
    `maxlevel` = 80,
    `MovementType` = 0,
    `HealthModifier` = 13
WHERE `entry` = 803802;
