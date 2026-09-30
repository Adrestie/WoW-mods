-- creature_template texts in the other languages; creature_template holds the English ones.
-- Clause : entry BETWEEN 84002 AND 84034 OR entry BETWEEN 84200 AND 84204
DELETE FROM `creature_template_locale` WHERE entry BETWEEN 84002 AND 84034 OR entry BETWEEN 84200 AND 84204;
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`, `VerifiedBuild`) VALUES
(84200, 'frFR', 'Sentinelle enchaînée', 'Xer\'Thul', 0),
(84201, 'frFR', 'Harpie gangrenée', 'Xer\'Thul', 0),
(84202, 'frFR', 'Dévoreur d\'âmes', 'Xer\'Thul', 0),
(84203, 'frFR', 'Abomination man\'ari', 'Xer\'Thul', 0),
(84204, 'frFR', 'Faucheur nervin', 'Xer\'Thul', 0);
