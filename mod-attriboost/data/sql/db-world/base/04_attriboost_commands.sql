-- mod-attriboost — the help of the chat commands.
--
-- AzerothCore reads it from the `command` table, shows it through
-- `.help attriboost <subcommand>`, and logs a warning at startup for any command
-- that has none. This table has no translation column: the help is in English.
--
-- The `security` column is only there for the listing: what really gates a
-- command is the level declared in the C++ table (SEC_PLAYER for all four).
--
-- Re-runnable: the block deletes its own rows before writing them again.

DELETE FROM `command` WHERE `name` = 'attriboost' OR `name` LIKE 'attriboost %';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('attriboost',          0, 'Syntax: .attriboost $subcommand\n\nAttribute points: trade Tomes of Knowledge and Books of Talents in, spend points on statistics, reset them. The /attributs window does all of it through these commands.'),
('attriboost exchange', 0, 'Syntax: .attriboost exchange $count\n\nTrades $count Tomes of Knowledge from your bags for attribute points, three per tome.'),
('attriboost talents',  0, 'Syntax: .attriboost talents $count\n\nTrades $count Books of Talents from your bags for talent points, one per book.'),
('attriboost allocate', 0, 'Syntax: .attriboost allocate $statistic $count\n\nSpends $count available points on one statistic: stamina, strength, agility, intellect, spirit, spellpower, critdamage, resists, penetration or healing.'),
('attriboost reset',    0, 'Syntax: .attriboost reset\n\nReturns every allocated point to the pool, for the cost set by Attriboost.ResetCost in attriboost.conf.');
