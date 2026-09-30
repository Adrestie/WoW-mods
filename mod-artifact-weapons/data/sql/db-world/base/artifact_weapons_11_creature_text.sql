-- Extrait de acore_world_hard.creature_text, tel quel, le 2026-09-28.
-- Clause : CreatureID BETWEEN 84002 AND 84034
DELETE FROM `creature_text` WHERE CreatureID BETWEEN 84002 AND 84034;
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES (84002,0,0,'Nya ha ha!',12,0,100,0,0,0,0,0,'Nya ha ha !');
