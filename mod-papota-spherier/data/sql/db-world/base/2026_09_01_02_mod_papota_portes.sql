-- mod-papota-spherier : LA PORTE de la Marche spectrale (8600050).
--
-- Clone de la Porte de la mort du chevalier (190942), modele 8046 : type 22
-- (« lanceur de sort »), le seul type dont on ait verifie en jeu qu'il
-- accepte le clic droit. Le travail est fait par le crochet de clic
-- (go_papota_porte), appele AVANT le traitement du type : franchir une
-- porte transporte a l'autre, efface celle qu'on franchit et rallonge
-- l'autre de 45 secondes. Le Data0 n'est donc jamais atteint ; il reste
-- renseigne pour que le coeur ne se plaigne pas d'un lanceur sans sort.
--
-- Data1 = 0 : charges illimitees, la porte tient sa duree.
-- Data2 = 1 : « partyOnly », seuls le proprietaire et son groupe cliquent.
--
-- Les deux portes d'une paire sont le MEME objet (2026-09-01) : elles sont
-- interchangeables, on franchit indifferemment l'une ou l'autre. L'ancienne
-- porte d'arrivee 803821 n'a plus lieu d'etre.

DELETE FROM `gameobject_template` WHERE `entry` IN (803820, 803821);

DROP TEMPORARY TABLE IF EXISTS `papota_clone_go`;
CREATE TEMPORARY TABLE `papota_clone_go` AS
    SELECT * FROM `gameobject_template` WHERE `entry` = 190942;
-- Data0 pointe le sort de la Porte de la mort d'origine (52751) : il n'est
-- JAMAIS atteint, le crochet de clic traitant l'objet avant le type, mais un
-- lanceur de sort sans sort fait rouspeter le coeur au chargement.
-- APPARENCE ET NOM DU 2026-09-02 : le sort devient « Tunnel de la mort »
-- et ses portes prennent le portail retroporte (GameObjectDisplayInfo 8500,
-- gen_visuel_dk.py). Le modele fait 55 m de rayon : `size` = 0,1, la
-- reduction de 90 % demandee, le ramene a 5,5 m.
UPDATE `papota_clone_go` SET `entry` = 803820, `name` = 'Tunnel de la mort',
    `type` = 22, `displayId` = 8500, `size` = 0.1,
    `Data0` = 52751, `Data1` = 0, `Data2` = 1,
    `ScriptName` = 'go_papota_porte';
INSERT INTO `gameobject_template` SELECT * FROM `papota_clone_go`;
DROP TEMPORARY TABLE IF EXISTS `papota_clone_go`;
