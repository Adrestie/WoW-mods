-- Extrait de acore_world_hard.spell_cooldown_overrides, tel quel, le 2026-09-28.
-- Clause : Id BETWEEN 84300 AND 84999
DELETE FROM `spell_cooldown_overrides` WHERE Id BETWEEN 84300 AND 84999;
INSERT INTO `spell_cooldown_overrides` (`Id`, `RecoveryTime`, `CategoryRecoveryTime`, `StartRecoveryTime`, `StartRecoveryCategory`, `Comment`) VALUES (84421,3000,0,0,0,'Corruption de Xer\'Thul (Proc) - objet 84008');
INSERT INTO `spell_cooldown_overrides` (`Id`, `RecoveryTime`, `CategoryRecoveryTime`, `StartRecoveryTime`, `StartRecoveryCategory`, `Comment`) VALUES (84682,10000,0,0,0,'Holy Shield - objet 84021 Vindictus : aligne sur les 10 s des deux autres procs');
