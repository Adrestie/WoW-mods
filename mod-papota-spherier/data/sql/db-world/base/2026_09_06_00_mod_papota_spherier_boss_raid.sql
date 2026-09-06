-- mod-papota-spherier : Spherite gagnee par boss de RAID, par carte et difficulte
-- (decision utilisateur du 2026-09-06).
--
-- source_value = carte x 10 + rang de difficulte :
--   0 = toute difficulte, 1 = 10 joueurs normal, 2 = 25 joueurs normal,
--   3 = 10 joueurs heroique, 4 = 25 joueurs heroique.
-- CrediterBoss cherche la ligne exacte, puis « toute difficulte », puis le
-- defaut (type, 0) — absent ici : un raid non tarife ne credite rien.
-- Non tarifes, sur decision utilisateur : Oeil de l'Eternite (616, raid absent
-- du serveur) et les boss de monde hors instance (type boss_monde) — ils ne
-- donnent RIEN, aucune ligne a ajouter.
DELETE FROM `papota_sphere_point_source` WHERE `source_type` IN ('boss_raid', 'boss_monde');
INSERT INTO `papota_sphere_point_source` (`source_type`, `source_value`, `points`) VALUES
-- Vanilla : 250
('boss_raid', 4090, 250),   -- Coeur du Magma
('boss_raid', 4690, 250),   -- Repaire de l'Aile noire
('boss_raid', 3090, 250),   -- Zul'Gurub
('boss_raid', 5090, 250),   -- Ruines d'Ahn'Qiraj
('boss_raid', 5310, 250),   -- Temple d'Ahn'Qiraj
-- Burning Crusade : 450
('boss_raid', 5320, 450),   -- Karazhan
('boss_raid', 5650, 450),   -- Repaire de Gruul
('boss_raid', 5440, 450),   -- Repaire de Magtheridon
('boss_raid', 5480, 450),   -- Caverne du sanctuaire du Serpent
('boss_raid', 5500, 450),   -- Donjon de la Tempete (l'Oeil)
('boss_raid', 5340, 450),   -- Bataille du mont Hyjal
('boss_raid', 5640, 450),   -- Temple noir
('boss_raid', 5680, 450),   -- Zul'Aman
('boss_raid', 5800, 450),   -- Plateau du Puits de soleil
-- Wrath of the Lich King
('boss_raid', 5330, 650),   -- Naxxramas
('boss_raid', 6150, 650),   -- Sanctum d'Obsidienne (comme Naxxramas)
('boss_raid', 6030, 750),   -- Ulduar
('boss_raid', 2490, 750),   -- Repaire d'Onyxia (comme Ulduar)
('boss_raid', 6240, 750),   -- Caveau d'Archavon (comme Ulduar)
('boss_raid', 6490, 850),   -- Epreuve du croise
('boss_raid', 6311, 1000),  -- Citadelle de la Couronne de glace, 10 normal
('boss_raid', 6312, 1100),  -- Citadelle de la Couronne de glace, 25 normal
('boss_raid', 6313, 1500),  -- Citadelle de la Couronne de glace, 10 heroique
('boss_raid', 6314, 2000),  -- Citadelle de la Couronne de glace, 25 heroique
('boss_raid', 7240, 1100);  -- Sanctum Rubis (comme ICC 25 normal)
