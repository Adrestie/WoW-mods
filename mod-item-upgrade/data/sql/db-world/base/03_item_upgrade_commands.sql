-- mod-item-upgrade — the help of the chat commands.
--
-- AzerothCore reads it from the `command` table, shows it through
-- `.help item_upgrade <subcommand>`, and logs a warning at startup for any
-- command that has none. This table has no translation column: the help is in
-- English.
--
-- The `security` column is only there for the listing: what really gates a
-- command is the level declared in the C++ table
-- (src/item_upgrade_commandscript.cpp).
--
-- Re-runnable: the block deletes its own rows, those of the former versions
-- included, before writing them again.

DELETE FROM `command` WHERE `name` = 'item_upgrade' OR `name` LIKE 'item_upgrade %';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('item_upgrade',         0, 'Syntax: .item_upgrade $subcommand\n\nItem upgrades: statistic ranks, weapon damage and weapon speed, bought through the upgrade window (/iu).'),
('item_upgrade reload',  3, 'Syntax: .item_upgrade reload\n\nReloads all the data of the Item Upgrades module and releases the lock set by .item_upgrade lock.'),
('item_upgrade lock',    3, 'Syntax: .item_upgrade lock\n\nLocks item upgrades so that the database tables can be edited safely: nobody can upgrade until .item_upgrade reload releases the lock.'),
('item_upgrade list',    0, 'Syntax: .item_upgrade list [$playername]\n\nLists the upgrades of the equipped items of the named player, of your target, or your own.'),
('item_upgrade state',   0, 'Syntax: .item_upgrade state $container $slot\n\nUsed by the upgrade window: describes the item at that place, one line per upgrade. Containers 0-4 are the bags, 100 is the equipment.'),
('item_upgrade upgrade', 0, 'Syntax: .item_upgrade upgrade $container $slot $itemguid $targets\n\nUsed by the upgrade window: buys the next rank of each target (statistic types, dmg, spd, separated by commas) for their total cost, all of them or none.');
