-- mod-papota-spherier : la BETE DE MEUTE de la Ruee sauvage (8600021).
--
-- Les copies portaient jusqu'ici l'entree du familier : gabarit sauvage, IA
-- du template — et donc AUCUNE attaque (une creature ne frappe que si son IA
-- appelle DoMeleeAttackIfReady a chaque tick). On reprend le patron DEJA
-- EPROUVE du module (goule 803801, garde funeste 803802) : notre creature
-- avec ScriptName = npc_papota_invocation, que le script habille ensuite de
-- l'apparence et des chiffres du familier du chasseur.
--
-- Cette IA fait tout ce qui est demande : elle attaque la cible de son
-- maitre au spawn, et REPREND CELLE DU MAITRE des que la sienne tombe.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803811;
DELETE FROM `creature_template` WHERE `entry` = 803811;

DROP TEMPORARY TABLE IF EXISTS `papota_clone`;
CREATE TEMPORARY TABLE `papota_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 22515;
-- Attaquable et selectionnable, contrairement aux marqueurs : c'est une bete
-- de combat. faction 35 par defaut, le script pose celle du chasseur.
UPDATE `papota_clone` SET `entry` = 803811, `name` = 'Bete de meute',
    `subname` = '', `faction` = 35, `npcflag` = 0, `unit_flags` = 0,
    `flags_extra` = 0, `AIName` = '',
    `ScriptName` = 'npc_papota_meute',
    `minlevel` = 80, `maxlevel` = 80, `unit_class` = 1, `speed_run` = 1.2;
INSERT INTO `creature_template` SELECT * FROM `papota_clone`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone`;

-- Display 802102 (opacite 0) : le script le REMPLACE au spawn par celui du
-- familier. Une bete invisible signalerait l'echec de ce remplacement.
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803811, 0, 802102, 1, 1);
