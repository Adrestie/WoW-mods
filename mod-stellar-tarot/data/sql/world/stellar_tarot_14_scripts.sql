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

DELETE FROM `spell_script_names` WHERE `spell_id` BETWEEN 87000 AND 88999;
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(87700, 'spell_stellar_tarot_line'),
(87701, 'spell_stellar_tarot_line'),
(87702, 'spell_stellar_tarot_line'),
(87703, 'spell_stellar_tarot_line'),
(87704, 'spell_stellar_tarot_line'),
(87705, 'spell_stellar_tarot_line'),
(87706, 'spell_stellar_tarot_line'),
(87707, 'spell_stellar_tarot_line'),
(87708, 'spell_stellar_tarot_line'),
(88046, 'spell_stellar_tarot_line'),
(88098, 'spell_stellar_tarot_line'),
(88206, 'spell_stellar_tarot_line'),
(88334, 'spell_stellar_tarot_line'),
(88366, 'spell_stellar_tarot_line'),
(88570, 'spell_stellar_tarot_line'),
(88820, 'spell_stellar_tarot_line'),
(88821, 'spell_stellar_tarot_line'),
(88822, 'spell_stellar_tarot_line'),
(88823, 'spell_stellar_tarot_line'),
(88824, 'spell_stellar_tarot_line'),
(88825, 'spell_stellar_tarot_line'),
(88826, 'spell_stellar_tarot_line'),
(88827, 'spell_stellar_tarot_line'),
(88828, 'spell_stellar_tarot_line'),
(88829, 'spell_stellar_tarot_line'),
(88830, 'spell_stellar_tarot_line'),
(88831, 'spell_stellar_tarot_line'),
(88832, 'spell_stellar_tarot_line'),
(88833, 'spell_stellar_tarot_line'),
(88834, 'spell_stellar_tarot_line'),
(88835, 'spell_stellar_tarot_line'),
(88836, 'spell_stellar_tarot_line'),
(88837, 'spell_stellar_tarot_line'),
(88838, 'spell_stellar_tarot_line'),
(88839, 'spell_stellar_tarot_line'),
(88840, 'spell_stellar_tarot_line'),
(88841, 'spell_stellar_tarot_line'),
(88842, 'spell_stellar_tarot_line'),
(88843, 'spell_stellar_tarot_line'),
(88844, 'spell_stellar_tarot_line'),
(88845, 'spell_stellar_tarot_line'),
(88846, 'spell_stellar_tarot_line'),
(88847, 'spell_stellar_tarot_line'),
(88848, 'spell_stellar_tarot_line');
