-- mod-stellar-tarot — the script the core calls when a line's aura procs.
--
-- The core's proc system can only cast a spell when an aura fires. The module
-- used to make it cast an empty MARKER it recognised on the fly. It needs no
-- such thing: an AuraScript's `OnEffectProc` is called on the accepted procs
-- only -- the chance and the cooldown of `spell_proc` filter before it -- and
-- it hands over the actor, the action target, the damage or heal amount, and
-- the hit mask. Measured in game: ten occasions, seven departures, seven calls.
--
-- GENERATED from the design workbook by the author's tooling. Regenerable.

DELETE FROM `spell_script_names` WHERE `spell_id` BETWEEN 902000 AND 903999;
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(902700, 'spell_stellar_tarot_line'),
(902701, 'spell_stellar_tarot_line'),
(902702, 'spell_stellar_tarot_line'),
(902703, 'spell_stellar_tarot_line'),
(902704, 'spell_stellar_tarot_line'),
(902705, 'spell_stellar_tarot_line'),
(902706, 'spell_stellar_tarot_line'),
(902707, 'spell_stellar_tarot_line'),
(902708, 'spell_stellar_tarot_line'),
(903820, 'spell_stellar_tarot_line'),
(903821, 'spell_stellar_tarot_line'),
(903822, 'spell_stellar_tarot_line'),
(903823, 'spell_stellar_tarot_line'),
(903824, 'spell_stellar_tarot_line'),
(903825, 'spell_stellar_tarot_line'),
(903826, 'spell_stellar_tarot_line'),
(903827, 'spell_stellar_tarot_line'),
(903828, 'spell_stellar_tarot_line'),
(903829, 'spell_stellar_tarot_line'),
(903830, 'spell_stellar_tarot_line'),
(903831, 'spell_stellar_tarot_line'),
(903832, 'spell_stellar_tarot_line'),
(903833, 'spell_stellar_tarot_line'),
(903834, 'spell_stellar_tarot_line'),
(903835, 'spell_stellar_tarot_line'),
(903836, 'spell_stellar_tarot_line'),
(903837, 'spell_stellar_tarot_line'),
(903838, 'spell_stellar_tarot_line'),
(903839, 'spell_stellar_tarot_line'),
(903840, 'spell_stellar_tarot_line'),
(903841, 'spell_stellar_tarot_line'),
(903842, 'spell_stellar_tarot_line'),
(903843, 'spell_stellar_tarot_line'),
(903844, 'spell_stellar_tarot_line'),
(903845, 'spell_stellar_tarot_line'),
(903846, 'spell_stellar_tarot_line'),
(903847, 'spell_stellar_tarot_line');
