-- mod-papota-spherier : le Gardien des anciens rois — RETIRE (2026-08-30).
--
-- Le PNJ (803800, modele 31021 de Terenas) est supprime a la demande de
-- l'utilisateur : le sort 8600012 ne garde que sa reduction de degats,
-- portee par le DBC seul. Ce fichier ne fait plus que nettoyer le clone
-- des bases qui l'avaient applique. (Historique : PNJ sans passe, cree
-- apres l'essai du Champion d'Argent 30188 qui trainait l'evenement du
-- Tournoi.)

DELETE FROM `creature_template_model` WHERE `CreatureID` = 803800;
DELETE FROM `creature_template` WHERE `entry` = 803800;
