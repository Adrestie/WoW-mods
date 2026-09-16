-- mod-stellar-tarot — the help of every command.
--
-- AzerothCore reads it from the `command` table, and logs a warning at startup
-- for any command that has none. It is shown by `.tarot <sub> help` -- in fact
-- by any argument that does not parse -- and by `.help tarot <sub>`.
--
-- The `security` column is only there for the listing: what really gates a
-- command is the level declared in the C++ table.
--
-- Regenerable: the block deletes its own rows before writing them again.

DELETE FROM `command` WHERE `name` = 'tarot' OR `name` LIKE 'tarot %';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('tarot',               0, 'Syntax: .tarot $subcommand\n\nThe stellar tarot: cards laid on a board, matched edge to edge. Type .tarot to list the subcommands, and .tarot $subcommand help for one of them.'),
('tarot info',          2, 'Syntax: .tarot info\n\nLists the loaded catalogue: every card with its four edges and its tags, every board with its rows, its columns and their numbers. To hand one out, use .additem with the item entry shown here.'),
('tarot reload',        3, 'Syntax: .tarot reload\n\nReads the mod_stellar_tarot_* tables again, without restarting the server. Everything the module holds is data, so this is how any change to it is applied.'),
('tarot study',         0, 'Syntax: .tarot study $item_entry\n\nStudies a card or a board you carry: it joins the binder of every character of your account, and the item is destroyed. One already in the binder is refused and stays in your bags. This is the path a right-click on the item takes.'),
('tarot binder',        2, 'Syntax: .tarot binder [$player]\n\nLists what a player''s account has studied: the named player, else your target, else yourself.'),
('tarot board',         0, 'Syntax: .tarot board $board_id\n\nEquips one of the boards your account owns, or takes the board off with 0. Every card is taken off the board either way.'),
('tarot place',         0, 'Syntax: .tarot place $row $column $card_id\n\nLays a card of your binder on a cell of the equipped board; a card already on that cell gives way to it. Rows and columns count from 1, top to bottom and left to right. A card sits on one cell at most.'),
('tarot remove',        0, 'Syntax: .tarot remove $row $column\n\nTakes the card off a cell of the equipped board.'),
('tarot move',          0, 'Syntax: .tarot move $row $column $to_row $to_column\n\nMoves the card of a cell to another cell of the equipped board: onto a free cell it moves, onto a taken cell the two cards swap places.'),
('tarot clear',         0, 'Syntax: .tarot clear\n\nTakes every card off the equipped board.'),
('tarot preset',        0, 'Syntax: .tarot preset save|load|delete ...\n\nA preset is a layout saved under a name -- the board and the cards laid on it -- for the whole account.'),
('tarot preset save',   0, 'Syntax: .tarot preset save $name\n\nSaves the equipped board and the cards laid on it under a name of 1 to 32 characters.'),
('tarot preset load',   0, 'Syntax: .tarot preset load $preset_id\n\nEquips the preset''s board and lays its cards again; a card the account no longer knows is skipped.'),
('tarot preset delete', 0, 'Syntax: .tarot preset delete $preset_id\n\nForgets a saved preset. The board and the cards laid today are not touched.'),
('tarot layout',        2, 'Syntax: .tarot layout [$player]\n\nShows a player''s equipped board, every card laid on it and the activation level of each -- the named player, else your target, else yourself.'),
('tarot effects',       2, 'Syntax: .tarot effects [$player]\n\nLists the effects in force on a player: for every laid card, each active level with its spell and its script -- the named player, else your target, else yourself.'),
('tarot xp',            2, 'Syntax: .tarot xp [$player]

Says what the cards make of a reference experience: a thousand points are passed through the module''s own hook, and the result is shown with the share it adds. The named player, else your target, else yourself.'),
('tarot fuse',          0, 'Syntax: .tarot fuse $item_entry $item_entry $item_entry\n\nThe workbench: three cards you carry, any of them, become one card drawn at random from the whole catalogue; three boards become one board. This is the path the shared workbench takes.'),
('tarot sources',       2, 'Syntax: .tarot sources

Lists where cards and boards drop from, as loaded from mod_stellar_tarot_source: every source with what it drops, at what chance, from what -- and the three settings that govern the loot.');
