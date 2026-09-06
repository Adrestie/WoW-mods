-- mod-papota-spherier : quitter la forme de selenien efface le sillage.
--
-- Le script s'accroche au sort NATIF 24858 (Forme de selenien), dont l'effet 0
-- porte SPELL_AURA_MOD_SHAPESHIFT vers la forme 31. Le generateur
-- gen_sorts_classes.py ne nomme que nos propres sorts, l'accroche vit donc
-- ici.
--
-- Pourquoi une accroche et pas le battement de l'aura 8610014 : celui-ci ne
-- passe que toutes les cinq secondes, alors que l'infobulle du Retour
-- stellaire promet que les etoiles s'en vont DES que le druide n'est plus
-- selenien. Le battement reste en filet de securite.

DELETE FROM `spell_script_names`
    WHERE `spell_id` = 24858 AND `ScriptName` = 'spell_papota_forme_selenien';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`)
VALUES (24858, 'spell_papota_forme_selenien');
