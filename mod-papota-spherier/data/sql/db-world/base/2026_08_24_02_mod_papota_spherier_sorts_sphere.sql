-- mod-papota-spherier : sorts d'utilisation des spheres.
-- GENERE par outils_spherier\gen_sorts_spherier.py — ne pas editer.
-- Le meme Spell.dbc est injecte dans patch-z.MPQ cote client :
-- c'est de la que vient l'infobulle « Utiliser : Ajoute N Spherites ».

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 8500001 AND 8500006;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `CastingTimeIndex`, `ProcChance`,
    `MaxLevel`, `BaseLevel`, `SpellLevel`, `DurationIndex`, `RangeIndex`,
    `EquippedItemClass`, `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,
    `ImplicitTargetA_1`, `SpellVisualID_1`, `SpellIconID`, `Name_Lang_enUS`, `Name_Lang_frFR`,
    `Name_Lang_Mask`, `Description_Lang_enUS`, `Description_Lang_frFR`,
    `Description_Lang_Mask`) VALUES
(8500001, 0, 1, 101, 0, 0, 0, 0, 1, -1, 3, 1, 49, 1, 7553, 208, 'Depleted Nexus', 'Nexus appauvri', 255, 'Adds $s1 Spherite.', 'Ajoute $s1 Spherites.', 255),
(8500002, 0, 1, 101, 0, 0, 0, 0, 1, -1, 3, 1, 99, 1, 7553, 208, 'Flickering Nexus', 'Nexus vacillant', 255, 'Adds $s1 Spherite.', 'Ajoute $s1 Spherites.', 255),
(8500003, 0, 1, 101, 0, 0, 0, 0, 1, -1, 3, 1, 249, 1, 7553, 208, 'Luminous Nexus', 'Nexus lumineux', 255, 'Adds $s1 Spherite.', 'Ajoute $s1 Spherites.', 255),
(8500004, 0, 1, 101, 0, 0, 0, 0, 1, -1, 3, 1, 499, 1, 7553, 208, 'Irradiant Nexus', 'Nexus irradiant', 255, 'Adds $s1 Spherite.', 'Ajoute $s1 Spherites.', 255),
(8500005, 0, 1, 101, 0, 0, 0, 0, 1, -1, 3, 1, 999, 1, 7553, 208, 'Solar Nexus', 'Nexus solaire', 255, 'Adds $s1 Spherite.', 'Ajoute $s1 Spherites.', 255),
(8500006, 0, 1, 101, 0, 0, 0, 0, 1, -1, 3, 1, 24, 1, 7553, 208, 'Prismatic Nexus', 'Nexus prismatique', 255, 'Raises all Spherite gains of your account by $s1%. Stacks without limit.', 'Majore de $s1 % tous les gains de Spherite de votre compte. Cumulable sans limite.', 255);

-- Le sort appelle le script du module, qui lit la valeur portee par l'effet.
DELETE FROM `spell_script_names` WHERE `spell_id` BETWEEN 8500001 AND 8500006;
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(8500001, 'spell_spherier_sphere'),
(8500002, 'spell_spherier_sphere'),
(8500003, 'spell_spherier_sphere'),
(8500004, 'spell_spherier_sphere'),
(8500005, 'spell_spherier_sphere'),
(8500006, 'spell_spherier_prisme');

-- La sphere se consomme comme une potion : sort a l'usage, une charge,
-- et plus AUCUN script d'objet — le coeur fait tout.
UPDATE `item_template` SET `spellid_1` = 8500001, `spelltrigger_1` = 0, `spellcharges_1` = -1, `ScriptName` = '' WHERE `entry` = 803200;
UPDATE `item_template` SET `spellid_1` = 8500002, `spelltrigger_1` = 0, `spellcharges_1` = -1, `ScriptName` = '' WHERE `entry` = 803201;
UPDATE `item_template` SET `spellid_1` = 8500003, `spelltrigger_1` = 0, `spellcharges_1` = -1, `ScriptName` = '' WHERE `entry` = 803202;
UPDATE `item_template` SET `spellid_1` = 8500004, `spelltrigger_1` = 0, `spellcharges_1` = -1, `ScriptName` = '' WHERE `entry` = 803203;
UPDATE `item_template` SET `spellid_1` = 8500005, `spelltrigger_1` = 0, `spellcharges_1` = -1, `ScriptName` = '' WHERE `entry` = 803204;
UPDATE `item_template` SET `spellid_1` = 8500006, `spelltrigger_1` = 0, `spellcharges_1` = -1, `ScriptName` = '' WHERE `entry` = 803205;
