-- mod-papota-spherier : la GOULE d'Apocalypse (8600051), refonte du
-- 2026-09-02.
--
-- L'IA passe de npc_papota_invocation (qui reprenait la cible du maitre) a
-- npc_papota_goule : chaque goule est levee AU PIED de sa proie et mord LE
-- PLUS PROCHE d'elle. Elle majore ses coups de 12,5 % par maladie du
-- chevalier sur la victime, et le proprietaire pose par le script fait
-- afficher ses degats au joueur.
--
-- NIVEAU 80 dans le gabarit (le meme defaut que la bete de meute avait
-- montre) : la goule 26125 clonee est de bas niveau, et une invocation
-- restee au niveau du modele arrive sans mordant. Le script pose ensuite le
-- niveau REEL du chevalier.
--
-- APPARENCES A NOUS (802112-802115, gen_visuel_dk.py) : l'ombre de la goule
-- s'etirait sur le terrain pendant sa sortie de terre. Cause relevee :
-- l'animation Birth fait plonger sa geometrie a -1,77 alors que le GeoBox
-- du modele natif (CreatureModelData 2794) s'arrete a -0,047 — le client
-- borne son volume d'ombre sur cette boite, et ce qui en sort projette une
-- ombre degeneree. Nos apparences designent un clone du modele au GeoBox
-- elargi ; le familier du chevalier, lui, garde les siennes intactes.

UPDATE `creature_template`
   SET `ScriptName` = 'npc_papota_goule',
       `minlevel` = 80, `maxlevel` = 80
 WHERE `entry` = 803801;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803801;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (803801, 0, 802112, 1, 1),
       (803801, 1, 802113, 1, 1),
       (803801, 2, 802114, 1, 1),
       (803801, 3, 802115, 1, 1);

-- Le coeur exige une ligne creature_model_info par displayid charge ; on
-- reprend celles des apparences natives (rayon 0,31 / allonge 1 / genre 2).
DELETE FROM `creature_model_info`
 WHERE `DisplayID` IN (802112, 802113, 802114, 802115);
INSERT INTO `creature_model_info`
    (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
VALUES (802112, 0.31, 1, 2, 0),
       (802113, 0.31, 1, 2, 0),
       (802114, 0.31, 1, 2, 0),
       (802115, 0.31, 1, 2, 0);
