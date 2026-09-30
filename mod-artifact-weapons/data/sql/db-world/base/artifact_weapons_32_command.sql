-- Help of the module's command, shown by .help aw bonus.
-- Clause : name = 'aw' OR name LIKE 'aw %'
DELETE FROM `command` WHERE `name` = 'aw' OR `name` LIKE 'aw %';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('aw', 2, 'Syntax: .aw $subcommand\n\nTools of the artifact weapons module.'),
('aw bonus', 2, 'Syntax: .aw bonus [$playername]\n\nShows the damage done bonus by school (weapon attacks and spells), the healing done bonus, the spell power and the healing power of the named player, else the selected player, else yourself: the values to enter in the balance simulator.');
