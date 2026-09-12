-- mod-stellar-tarot — what each script says of itself.
--
-- One row per script the C++ registers (StellarTarotScripts.cpp): the id of
-- the module_string row that describes it, with {} for each parameter in the
-- order they are written in the card's column. The texts themselves are in
-- stellar_tarot_02_strings.sql, ids 1001 and up, English and per locale.
--
-- Regenerable: the block deletes its own rows before writing them again.

DELETE FROM `mod_stellar_tarot_script` WHERE `name` IN ('gold_on_kill', 'heal_on_kill');
INSERT INTO `mod_stellar_tarot_script` (`name`, `string_id`) VALUES
('gold_on_kill', 1001),
('heal_on_kill', 1002);
