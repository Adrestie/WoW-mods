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

Lists where cards and boards drop from, as loaded from mod_stellar_tarot_source: every source with what it drops, at what chance, from what -- and the three settings that govern the loot.'),
('tarot test',          2, 'Syntax: .tarot test card|clear|force|hour|hp|mana|trace|status|fire|snapshot|aura ...\n\nThe test bench: one card level alone on a character, test values armed, states and the hour forced, and probes that write every effect that fires. Held in memory only.'),
('tarot test card',     2, 'Syntax: .tarot test card $player $card_id $level [cumulative]\n\nPuts one card level alone on the player, in place of the board, with the test values armed: no chance roll, no cooldown. With cumulative, the levels below come too when the card is cumulative, as the board gives them.'),
('tarot test clear',    2, 'Syntax: .tarot test clear $player\n\nGives the player back the board, and releases the forced states, the forced hour and the probes.'),
('tarot test force',    2, 'Syntax: .tarot test force $player $state on|off|free\n\nHolds a state (on) or fails it (off) whatever the game says, or gives it back to the game (free). States: combat, nocombat, solo, rested, water, indoors, outdoors, mounted, walking, running, still, shield, twohand, dualwield, unarmed, heirloom, stunned, controlled, charmed, slowed, burning, humanoid, alone, back.'),
('tarot test hour',     2, 'Syntax: .tarot test hour $hour\n\nThe hour every card reads, 0 to 23, for the whole realm (night, day, dawn, hour). -1 gives back the server''s clock.'),
('tarot test hp',       2, 'Syntax: .tarot test hp $player $percent\n\nSets the player''s health to a share of the maximum.'),
('tarot test mana',     2, 'Syntax: .tarot test mana $player $percent\n\nSets the player''s mana to a share of the maximum.'),
('tarot test trace',    2, 'Syntax: .tarot test trace $player on|off\n\nThe probes: every effect of the player that fires writes a line to the server log and to the player''s chat.'),
('tarot test status',   2, 'Syntax: .tarot test status $player\n\nWhat the bench holds for the player: the card level under test, the probes, the forced hour and states.'),
('tarot test fire',      2, 'Syntax: .tarot test fire $player $event [$n]

Hands an event of the game to the player''s cards. Real, through the core: swing [count], spell [spell], cast [spell] (as the player casts, not triggered), far [spell] (on a unit 25 yards away), mobs [count], newtarget, targethp [percent], targetone, killtarget, selfhit [spell], struck|struckback|struckcrit [count] (blows taken in front, in the back, or critical), struckspell [spell], heal [spell], healother|healfull|healedby [spell], allylow [percent], kill [creature_entry], corpse, buy|sell|additem|useitem [item_entry], wear, repairall, lootgo [gameobject_entry], lootfish|lootskin|lootprospect [loot_id], mount [spell], dismount, pet [spell], pethit [count], pethp [percent], healpet, petdie, shoot [wand_entry], die, revive, nudge. Through the module''s relay: dealt|taken|takenspell [damage], healed [amount], trigger [amount], combat, leave, xp|xpquest|xpexplore|xpbg|rep|repquest|money|sold|auction|auctionpost|auctionwon [amount], quest $quest_id, zone, capital, repair, vendor, jump, spinleft|spinright [turns], death, resurrect, level.'),
('tarot test snapshot',  2, 'Syntax: .tarot test snapshot $player

What can be measured of the player: health, mana, money, combat, and the auras of the module and those the player cast (spell:stacks:amounts:seconds); then the same of the bench''s target and of the pet, the durability worn, the cooldowns, life, mount and position.'),
('tarot test aura',      2, 'Syntax: .tarot test aura $player $spell [self|target] [$stacks]

Lays an aura on the player (self), or on the bench''s target: what a card needs around it, a critical strike, a dodge, a parry, the stacks another level would have built. A negative spell removes it.');
