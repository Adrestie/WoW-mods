-- mod-stellar-tarot — the companion auras, linked by the core.
--
-- A spell carries but THREE effects. When a card level asks for more, the
-- surplus goes into a companion spell, and this table tells the core to lay it
-- with the level's own aura and to take it off with it (type 2, SPELL_LINK_AURA):
-- `caster->AddAura(companion, target)` on apply, `target->RemoveAura(companion)`
-- on removal, and the stack count kept in step. No module code is involved.
--
-- GENERATED from the design workbook by the author's tooling. Regenerable.

DELETE FROM `spell_linked_spell` WHERE ABS(`spell_trigger`) BETWEEN 87000 AND 88999;
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(88213, 88978, 2, 'The Grin level 2: the rest of the aura'),
(88239, 88977, 2, 'The Familiar level 4: the rest of the aura'),
(88356, 88973, 2, 'The Paranoia level 1: the rest of the aura'),
(88358, 88972, 2, 'The Paranoia level 3: the rest of the aura'),
(88420, 88971, 2, 'The Patron level 1: the rest of the aura'),
(88420, 88970, 2, 'The Patron level 1: the rest of the aura'),
(88449, 88969, 2, 'The Hysteria level 2: the rest of the aura'),
(88451, 88968, 2, 'The Hysteria level 4: the rest of the aura'),
(88613, 88950, 2, 'The Hanged Man level 2: the price'),
(88617, 88948, 2, 'The Tower level 2: the price'),
(88772, 88938, 2, 'The Oblivion level 1: the rest of the aura'),
(88773, 88937, 2, 'The Oblivion level 2: the rest of the aura'),
(88774, 88936, 2, 'The Oblivion level 3: the rest of the aura'),
(88775, 88935, 2, 'The Oblivion level 4: the rest of the aura');
