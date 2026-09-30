-- creature_text texts in the other languages; creature_text holds the English ones.
-- Clause : CreatureID BETWEEN 84002 AND 84034
DELETE FROM `creature_text_locale` WHERE CreatureID BETWEEN 84002 AND 84034;
INSERT INTO `creature_text_locale` (`CreatureID`, `GroupID`, `ID`, `Locale`, `Text`) VALUES
(84002, 0, 0, 'frFR', 'Nya ha ha !');
