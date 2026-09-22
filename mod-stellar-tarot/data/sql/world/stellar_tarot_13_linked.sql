-- mod-stellar-tarot — the companion auras, linked by the core.
--
-- A spell carries but THREE effects. When a card level asks for more, the
-- surplus goes into a companion spell, and this table tells the core to lay it
-- with the level's own aura and to take it off with it (type 2, SPELL_LINK_AURA):
-- `caster->AddAura(companion, target)` on apply, `target->RemoveAura(companion)`
-- on removal, and the stack count kept in step. No module code is involved.
--
-- GENERATED from the design workbook by the author's tooling. Regenerable.

DELETE FROM `spell_linked_spell` WHERE ABS(`spell_trigger`) BETWEEN 902000 AND 903999;
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(903213, 903978, 2, 'The Grin level 2: the rest of the aura'),
(903239, 903977, 2, 'The Familiar level 4: the rest of the aura'),
(903356, 903973, 2, 'The Paranoia level 1: the rest of the aura'),
(903358, 903972, 2, 'The Paranoia level 3: the rest of the aura'),
(903420, 903971, 2, 'The Patron level 1: the rest of the aura'),
(903420, 903970, 2, 'The Patron level 1: the rest of the aura'),
(903449, 903969, 2, 'The Hysteria level 2: the rest of the aura'),
(903451, 903968, 2, 'The Hysteria level 4: the rest of the aura'),
(903613, 903950, 2, 'The Hanged Man level 2: the price'),
(903617, 903948, 2, 'The Tower level 2: the price'),
(903772, 903938, 2, 'The Oblivion level 1: the rest of the aura'),
(903773, 903937, 2, 'The Oblivion level 2: the rest of the aura'),
(903774, 903936, 2, 'The Oblivion level 3: the rest of the aura'),
(903775, 903935, 2, 'The Oblivion level 4: the rest of the aura');
