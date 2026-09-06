-- mod-papota-spherier : Spherite des DONJONS et du MYTHIQUE+ (decision
-- utilisateur du 2026-09-06). Remplace les trois sentinelles 1234.
--
-- boss_donjon et donjon_termine : la chaine de PointsPourInstance —
--   (type, carte x 10 + difficulte + 1) exacte, puis (type, carte x 10) toute
--   difficulte, puis le PALIER D'EXTENSION (valeur < 10) :
--     1 = vanilla, 4 = BC normal, 5 = BC heroique, 7 = WotLK normal,
--     8 = WotLK heroique  (extension x 3 + difficulte + 1)
--   puis (type, 0). Un donjon particulier se tarife en ajoutant sa ligne
--   carte x 10 (+ difficulte + 1).
-- mythique_plus : valeur = palier de la cle, 150 + 50 x palier, chronometre
--   rate compris (c'est la commande .spherier points source qui passe le
--   palier). Au-dela du palier 50 : rien.
DELETE FROM `papota_sphere_point_source` WHERE `source_type` IN ('boss_donjon', 'donjon_termine', 'mythique_plus');
INSERT INTO `papota_sphere_point_source` (`source_type`, `source_value`, `points`) VALUES
('boss_donjon', 1, 75),     -- boss de donjon vanilla
('boss_donjon', 4, 100),    -- boss de donjon BC
('boss_donjon', 5, 125),    -- boss de donjon BC heroique
('boss_donjon', 7, 125),    -- boss de donjon WotLK
('boss_donjon', 8, 150),    -- boss de donjon WotLK heroique
('donjon_termine', 1, 50),  -- donjon vanilla termine
('donjon_termine', 4, 75),  -- donjon BC termine
('donjon_termine', 5, 100), -- donjon BC heroique termine
('donjon_termine', 7, 125), -- donjon WotLK termine
('donjon_termine', 8, 150), -- donjon WotLK heroique termine
('mythique_plus', 1, 200), ('mythique_plus', 2, 250), ('mythique_plus', 3, 300), ('mythique_plus', 4, 350), ('mythique_plus', 5, 400),
('mythique_plus', 6, 450), ('mythique_plus', 7, 500), ('mythique_plus', 8, 550), ('mythique_plus', 9, 600), ('mythique_plus', 10, 650),
('mythique_plus', 11, 700), ('mythique_plus', 12, 750), ('mythique_plus', 13, 800), ('mythique_plus', 14, 850), ('mythique_plus', 15, 900),
('mythique_plus', 16, 950), ('mythique_plus', 17, 1000), ('mythique_plus', 18, 1050), ('mythique_plus', 19, 1100), ('mythique_plus', 20, 1150),
('mythique_plus', 21, 1200), ('mythique_plus', 22, 1250), ('mythique_plus', 23, 1300), ('mythique_plus', 24, 1350), ('mythique_plus', 25, 1400),
('mythique_plus', 26, 1450), ('mythique_plus', 27, 1500), ('mythique_plus', 28, 1550), ('mythique_plus', 29, 1600), ('mythique_plus', 30, 1650),
('mythique_plus', 31, 1700), ('mythique_plus', 32, 1750), ('mythique_plus', 33, 1800), ('mythique_plus', 34, 1850), ('mythique_plus', 35, 1900),
('mythique_plus', 36, 1950), ('mythique_plus', 37, 2000), ('mythique_plus', 38, 2050), ('mythique_plus', 39, 2100), ('mythique_plus', 40, 2150),
('mythique_plus', 41, 2200), ('mythique_plus', 42, 2250), ('mythique_plus', 43, 2300), ('mythique_plus', 44, 2350), ('mythique_plus', 45, 2400),
('mythique_plus', 46, 2450), ('mythique_plus', 47, 2500), ('mythique_plus', 48, 2550), ('mythique_plus', 49, 2600), ('mythique_plus', 50, 2650);
