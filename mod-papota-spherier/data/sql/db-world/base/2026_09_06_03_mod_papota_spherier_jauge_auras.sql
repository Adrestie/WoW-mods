-- mod-papota-spherier : les auras de la JAUGE CELESTE ne sont jamais sauvees
-- (2026-09-06).
--
-- Le coeur enregistre les auras du personnage AVANT d'appeler le crochet de
-- deconnexion qui vide la jauge (WorldSession::LogoutPlayer : SaveToDB puis
-- OnPlayerLogout). Une aura de verrou (astre epuise, permanente) revenait donc
-- a la connexion, fleche comprise, alors que la jauge repartait du centre.
-- SPELL_ATTR0_CU_AURA_CANNOT_BE_SAVED (0x01000000, spell_custom_attr) :
-- Aura::CanBeSaved les ecarte de la sauvegarde. Lu au demarrage du serveur.
--   8610029 Solstice, 8610030 Equinoxe (bouts atteints, 6 s)
--   8610031 Alignement (fenetre de 5 s)
--   8610032 Jauge lunaire, 8610033 Jauge solaire (piles)
--   8610034 Soleil epuise, 8610035 Lune epuisee (verrous)
DELETE FROM `spell_custom_attr` WHERE `spell_id` BETWEEN 8610029 AND 8610035;
INSERT INTO `spell_custom_attr` (`spell_id`, `attributes`) VALUES
(8610029, 0x01000000), (8610030, 0x01000000), (8610031, 0x01000000),
(8610032, 0x01000000), (8610033, 0x01000000), (8610034, 0x01000000),
(8610035, 0x01000000);
