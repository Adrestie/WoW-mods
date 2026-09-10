-- mod-spheregrid — the help of every command.
--
-- AzerothCore reads it from the `command` table, and logs a warning at startup
-- for any command that has none. It is shown by `.spheregrid <sub> help` — in
-- fact by any argument that does not parse — and by `.help spheregrid <sub>`.
--
-- The `security` column is only there for the listing: what really gates a
-- command is the level declared in the C++ table.
--
-- Regenerable: the block deletes its own rows before writing them again.

DELETE FROM `command` WHERE `name` = 'spheregrid' OR `name` LIKE 'spheregrid %';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('spheregrid',              0, 'Syntax: .spheregrid $subcommand\n\nThe sphere grid: a custom talent grid living beside the Blizzard talents. Type .spheregrid to list the subcommands, and .spheregrid $subcommand help for one of them.'),
('spheregrid info',         2, 'Syntax: .spheregrid info\n\nShows the state of the loaded definition: how many cells, edges and classes, and the award of every content source.'),
('spheregrid reload',       3, 'Syntax: .spheregrid reload\n\nReads the spheregrid_* tables again, without restarting the server. Everything the module holds is data, so this is how any change to it is applied.'),
('spheregrid status',       2, 'Syntax: .spheregrid status [$player]\n\nShows the points of a player: earned, spent, available, how many cells are active and the price of the cheapest one he can reach.'),
('spheregrid points',       3, 'Syntax: .spheregrid points add|remove|set $amount [$player]\n\nChanges the Spherite of a player. Type one of the subcommands with no amount to see what it does.'),
('spheregrid points add',   3, 'Syntax: .spheregrid points add $amount [$player]\n\nCredits Spherite to a player, raw: unlike a content award, it is not boosted by the prisms of his account.'),
('spheregrid points remove',3, 'Syntax: .spheregrid points remove $amount [$player]\n\nDebits Spherite from a player. Capped at what he has available: it never goes negative.'),
('spheregrid points set',   3, 'Syntax: .spheregrid points set $amount [$player]\n\nSets the AVAILABLE Spherite of a player to $amount. What he has already spent is left alone.'),
('spheregrid activate',     0, 'Syntax: .spheregrid activate $node_id\n\nBuys a cell of your own grid, with every game rule applied: the class, the adjacency to what you already own, and the price. This is the path the interface uses.'),
('spheregrid socket',       0, 'Syntax: .spheregrid socket $node_id $item_entry\n\nSockets a stone or a rune you carry into one of your active cells. A node only takes stones, a socket only runes.'),
('spheregrid unsocket',     0, 'Syntax: .spheregrid unsocket $node_id\n\nEmpties one of your cells with a Pin of Oblivion, which is consumed. The stone or the rune inside is DESTROYED. On a spell cell the spell is forgotten, and the cell stays yours.'),
('spheregrid fuse',         0, 'Syntax: .spheregrid fuse $item_entry\n\nWorkbench: three identical stones become one stone of the quality above.'),
('spheregrid reroll',       0, 'Syntax: .spheregrid reroll $item_entry $item_entry\n\nWorkbench: two stones of the same quality become one stone of that quality, with another effect.'),
('spheregrid reforge',      0, 'Syntax: .spheregrid reforge $item_entry $item_entry $item_entry\n\nWorkbench: three runes, any of them, become one rune drawn from the whole catalogue. This is how a rune of another class becomes useful.'),
('spheregrid grind',        0, 'Syntax: .spheregrid grind $item_entry\n\nWorkbench: destroys one stone or rune and returns Spherite for it. The only recipe that gives no item back.'),
('spheregrid respec',       0, 'Syntax: .spheregrid respec\n\nHands your whole grid back and returns every Spherite you spent on this character. The stones and runes stay in their cells and come back when you buy them again; the spells taught by a spell cell are forgotten.'),
('spheregrid reset',        3, 'Syntax: .spheregrid reset [$player]\n\nWipes the grid of one character: every cell and every row of it. Unlike respec, the rows are erased, so the stones and runes socketed are lost. The Spherite of the account is left untouched.'),
('spheregrid wipeall',      3, 'Syntax: .spheregrid wipeall [$player]\n\nWipes the WHOLE ACCOUNT of a player: the Spherite earned and the grids of every one of his characters, online or not. Irreversible.'),
('spheregrid stats',        2, 'Syntax: .spheregrid stats [$player]\n\nLists what the grid currently grants a player, statistic by statistic.'),
('spheregrid show',         0, 'Syntax: .spheregrid show\n\nOpens the sphere grid window.'),
('spheregrid editor',       3, 'Syntax: .spheregrid editor\n\nOpens the layout editor, which composes a grid and saves it as XML.');
