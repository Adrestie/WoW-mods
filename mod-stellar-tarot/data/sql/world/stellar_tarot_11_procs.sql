-- mod-stellar-tarot — the proc conditions of the engine's trigger auras.
--
-- A card level that fires on a critical hit, a dodge, a parry, a block or a
-- miss carries a passive aura (903820 and up) that the core's proc system
-- watches; this table says on which hits it fires (HitMask). The aura then
-- casts a marker spell (903810..903817) the module recognises.
-- The core reads `spell_proc`; `spell_proc_event` is only cleaned of the
-- rows an earlier version of this file wrote there.
DELETE FROM `spell_proc_event` WHERE `entry` BETWEEN 903820 AND 903999;
DELETE FROM `spell_proc` WHERE `SpellId` BETWEEN 903820 AND 903999;
INSERT INTO `spell_proc`
  (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`,
   `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`,
   `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(903820, 0, 0, 0, 0, 0, 69632, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903821, 4, 0, 0, 0, 0, 69632, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903822, 0, 0, 0, 0, 0, 69972, 0, 2, 108, 0, 0, 0, 100, 0, 0),
(903823, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903824, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903825, 0, 0, 0, 0, 0, 17408, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903826, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903827, 0, 0, 0, 0, 0, 40, 0, 0, 16, 0, 0, 0, 100, 0, 0),
(903828, 0, 0, 0, 0, 0, 131752, 0, 0, 2, 0, 0, 0, 100, 0, 0),
(903829, 0, 0, 0, 0, 0, 40, 0, 0, 64, 0, 0, 0, 100, 0, 0),
(903830, 0, 0, 0, 0, 0, 17408, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903831, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903832, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903833, 0, 0, 0, 0, 0, 40, 0, 0, 16, 0, 0, 0, 100, 0, 0),
(903834, 0, 0, 0, 0, 0, 40, 0, 0, 16, 0, 0, 0, 100, 0, 0),
(903835, 0, 0, 0, 0, 0, 40, 0, 0, 16, 0, 0, 0, 100, 0, 0),
(903836, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903837, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903838, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903839, 0, 0, 0, 0, 0, 17408, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903840, 0, 0, 0, 0, 0, 69632, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903841, 0, 0, 0, 0, 0, 131752, 0, 0, 2, 0, 0, 0, 100, 0, 0),
(903842, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903843, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903844, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903845, 0, 0, 0, 0, 0, 17408, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903846, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903847, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0),
(903848, 0, 0, 0, 0, 0, 69972, 0, 2, 2, 0, 0, 0, 100, 0, 0);
