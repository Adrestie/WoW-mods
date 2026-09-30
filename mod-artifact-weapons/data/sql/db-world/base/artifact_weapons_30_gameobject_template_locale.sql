-- gameobject_template texts in the other languages; gameobject_template holds the English ones.
-- Clause : entry BETWEEN 840000 AND 849999
DELETE FROM `gameobject_template_locale` WHERE entry BETWEEN 840000 AND 849999;
INSERT INTO `gameobject_template_locale` (`entry`, `locale`, `name`, `castBarCaption`, `VerifiedBuild`) VALUES
(840019, 'frFR', 'Vaelthis, Brise-sortilège', '', 0);
