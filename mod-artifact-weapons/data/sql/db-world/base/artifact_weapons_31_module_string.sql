-- Texts of the module's command, English in module_string, the other languages in module_string_locale.
-- Clause : module = 'mod-artifact-weapons'
DELETE FROM `module_string` WHERE `module` = 'mod-artifact-weapons';
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-artifact-weapons', 1, 'Damage and healing bonuses of {}:'),
('mod-artifact-weapons', 2, '  Weapon attacks (physical): {:+.1f} %'),
('mod-artifact-weapons', 3, '  Spell damage, by school: Physical {:+.1f} %, Holy {:+.1f} %, Fire {:+.1f} %, Nature {:+.1f} %, Frost {:+.1f} %, Shadow {:+.1f} %, Arcane {:+.1f} %'),
('mod-artifact-weapons', 4, '  Healing done: {:+.1f} %'),
('mod-artifact-weapons', 5, '  Spell power (damage), by school: Holy {}, Fire {}, Nature {}, Frost {}, Shadow {}, Arcane {}'),
('mod-artifact-weapons', 6, '  Healing power: {}'),
('mod-artifact-weapons', 7, '  Only the Damage done % and Healing done % auras count: class talents that change given spells are not included.');
DELETE FROM `module_string_locale` WHERE `module` = 'mod-artifact-weapons';
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-artifact-weapons', 1, 'frFR', 'Bonus aux dégâts et aux soins de {} :'),
('mod-artifact-weapons', 2, 'frFR', '  Attaques à l\'arme (physique) : {:+.1f} %'),
('mod-artifact-weapons', 3, 'frFR', '  Dégâts des sorts, par école : Physique {:+.1f} %, Sacré {:+.1f} %, Feu {:+.1f} %, Nature {:+.1f} %, Givre {:+.1f} %, Ombre {:+.1f} %, Arcanes {:+.1f} %'),
('mod-artifact-weapons', 4, 'frFR', '  Soins prodigués : {:+.1f} %'),
('mod-artifact-weapons', 5, 'frFR', '  Puissance des sorts (dégâts), par école : Sacré {}, Feu {}, Nature {}, Givre {}, Ombre {}, Arcanes {}'),
('mod-artifact-weapons', 6, 'frFR', '  Puissance des soins : {}'),
('mod-artifact-weapons', 7, 'frFR', '  Seules les auras « dégâts infligés % » et « soins prodigués % » comptent : les talents de classe qui modifient des sorts précis ne sont pas inclus.');
