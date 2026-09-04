-- mod-attriboost — points d'attribut par personnage.
-- Une ligne par personnage ; `unallocated` = points en réserve, les autres
-- colonnes = points posés sur chaque statistique. Purger cette table remet
-- tout le serveur à zéro (les auras suivent au prochain passage en jeu).

CREATE TABLE IF NOT EXISTS `attriboost_attributes` (
  `guid` int unsigned NOT NULL,
  `unallocated` int DEFAULT 0,
  `stamina` int unsigned DEFAULT 0,
  `strength` int unsigned DEFAULT 0,
  `agility` int unsigned DEFAULT 0,
  `intellect` int unsigned DEFAULT 0,
  `spirit` int unsigned DEFAULT 0,
  `spellpower` int unsigned DEFAULT 0,
  `criticalstrikedamage` int unsigned DEFAULT 0,
  `allresists` int unsigned DEFAULT 0,
  `spellpenetration` int unsigned DEFAULT 0,
  `healingpower` int unsigned DEFAULT 0,
  `settings` int DEFAULT 1,
  `comment` varchar(50) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
