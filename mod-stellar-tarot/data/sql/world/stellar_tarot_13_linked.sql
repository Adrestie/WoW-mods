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
(903356, 903982, 2, 'The Paranoia level 1: the rest of the aura'),
(903358, 903981, 2, 'The Paranoia level 3: the rest of the aura'),
(903449, 903980, 2, 'The Hysteria level 2: the rest of the aura'),
(903451, 903979, 2, 'The Hysteria level 4: the rest of the aura'),
(903772, 903974, 2, 'The Oblivion level 1: the rest of the aura'),
(903773, 903973, 2, 'The Oblivion level 2: the rest of the aura'),
(903774, 903972, 2, 'The Oblivion level 3: the rest of the aura'),
(903775, 903971, 2, 'The Oblivion level 4: the rest of the aura');
