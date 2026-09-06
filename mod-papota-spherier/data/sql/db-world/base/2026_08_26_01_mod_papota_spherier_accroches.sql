-- mod-papota-spherier : retrait du credit direct sur la mort des boss de raid.
--
-- Depuis que le butin couvre les monstres (§14), un boss de raid rendait DEUX
-- fois : un Nexus par la table de butin, et 1234 Spherite par l'accroche de
-- contenu du jalon 2 — la valeur sentinelle, jamais reequilibree. Le credit
-- direct fait double emploi, il est retire (demande du 2026-08-26).
--
-- Supprimer la ligne suffit : PointsPourSource renvoie alors 0 et CrediterBoss
-- s'arrete avant tout credit et tout message. Rechargeable par .spherier reload,
-- sans redemarrage.
--
-- LES TROIS AUTRES ACCROCHES RESTENT ACTIVES, toutes a 1234 :
--   boss_donjon      credite a chaque boss de donjon tue
--   donjon_termine   credite a la fin d'un donjon (mod-dungeon-clear)
--   mythique_plus    credite a la completion d'un mythique+
-- Elles font le meme double emploi que boss_raid pour les deux premieres.

DELETE FROM `papota_sphere_point_source` WHERE `source_type` = 'boss_raid';
