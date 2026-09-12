# mod-stellar-tarot

Cards laid on a board, for AzerothCore 3.3.5a. A card carries a number from
1 to 9 on each of its four edges; a board is a grid of 2 to 4 rows by 2 to 4
columns, with a number on every row and every column. Where two edges meet on
the same number, both cards wake: the more edges a card matches -- 1 to 4 --
the stronger or the wider its effect. A crossing of Hades II's arcana cards
and Final Fantasy VIII's Triple Triad.

**Work in progress.** What is here today: the catalogue and the commands that
read it, the installer, the binder -- a card or a board used from the bags
joins the collection of the whole account -- the board: the `/tarot` window
equips a board, lays cards on it by drag and drop, shows the level of each
and saves layouts as presets -- the effects: at each level a card applies an
aura and/or runs a script of the module -- the workbench, shared with the
other modules, where three cards or three boards become one -- the loot,
one row per source -- and the cards' art: an illustration and an icon per
card, composed in the window on a frame. The cards themselves are a test set
of twelve. **[How to do things with it](docs/HOWTO.md).**

## Requirements

| | |
|---|---|
| [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) | 3.3.5a, built with the module in `modules/` |
| [ALE](https://github.com/azerothcore/mod-ale) or Eluna | the Lua engine that will run the interface |
| [AIO](https://github.com/Rochet2/AIO) | server AND client -- the interface is sent over it |
| Python 3 and the `mysql` client | for the installer |

## Installing

`install.bat` asks where the server is, where the core sources are, where the
client is and where to keep the copies, then does the rest and prints every
step (`python tools/install.py --help` is the same, one flag at a time, on any
system). Three ways to run: **look only** (reads and reports, writes nothing),
**rehearse** (announces every step, writes nothing), **install**.

Nothing is written before a copy of it exists. Run again on a server that
already has the module, the installer removes it instead; to update, remove
then install again.

By hand: copy the module into `modules/`, apply `data/sql/world/` then
`data/sql/characters/` in order, copy `conf/mod-stellar-tarot.conf.dist` to
`configs/modules/mod-stellar-tarot.conf`, rebuild the core. The client half --
merging the module's rows into the client's `Item.dbc` -- is what
`tools/install.py --client-only --client <Data dir>` is for.

## Commands

| | | |
|---|---|---|
| `.tarot info` | game master | the loaded catalogue, with the item entry of every card and board |
| `.tarot reload` | administrator | reads the tables again |
| `.tarot binder [player]` | game master | what a player's account has studied |
| `.tarot layout [player]` | game master | a player's board, and the level of every card on it |
| `.tarot effects [player]` | game master | the effects in force on a player |
| `.tarot study <entry>` | player | studies a card or a board from the bags -- the path a right-click takes |
| `.tarot board <id|0>` | player | equips a board, or takes it off; every card comes off |
| `.tarot place <row> <col> <card>` | player | lays a card on a cell; a card already there gives way |
| `.tarot remove <row> <col>` | player | takes a card off |
| `.tarot move <row> <col> <row> <col>` | player | moves a laid card to a free cell, or swaps it with the card there |
| `.tarot clear` | player | takes every card off |
| `.tarot preset save <name>` / `load <id>` / `delete <id>` | player | the saved layouts of the account |
| `.tarot fuse <a> <b> <c>` | player | three cards, or three boards, become one drawn at random -- the workbench's path |

The player commands are the paths the window takes; they can be typed as well.
To hand a card or a board to a player, use the core's own `.additem <entry>`:
the module adds no command the core already has.

## The binder

A card or a board is an item, found anywhere. **Using it** studies it: it
joins the binder of the ACCOUNT -- every character, present or future -- and
the item is destroyed. One the account already knows is refused and stays in
the bags; its tooltip says *Already known*, in red, as a recipe's does.

`/tarot` opens the window. The deck, on the left, has an "All" tab and one tab per tag -- every
card carries exactly one -- and shows every card of the tab: a known card
free to lay, a known card already on the board (dimmed), or a card not yet
known (a red question mark). Every card carries a number for the players,
"1." onwards in catalogue order, in front of its name -- a name to point at a
card by, known or not; the module never reads it. Hovering a known card shows
its name, *Cumulative* when it is, and what each of its four levels does;
hovering an unknown one shows only its number and the card's `hint` -- where
to find it, localised through `mod_stellar_tarot_card_locale`.

## The board

The slot in the middle of the window equips one of the boards the account
owns; changing it, or taking it off, takes every card off. The board's numbers
stand around the grid, two per row and two per column, all of them free to
differ: a row's left number faces the left edge of its first card and its
right number the right edge of its last; a column's top number faces the top
edge of its first card and its bottom number the bottom edge of its last.

A card is laid by dragging it from the deck onto a cell -- a free one, or a
taken one whose card then gives way -- and taken off by a right-click, or by
dragging it off the board; **Remove all** empties the board. A laid card is
dragged as well: onto a free cell it moves, onto a taken cell the two cards
swap places. Each of these is one action for the server, so the effects
never blink. While a card is held over the board, before it is let go, the
window shows what letting go would do: on the board, the numbers that would
match in cyan and those that would stop matching in red; in the hand and in
the list of effects, the levels gained in cyan and those lost in red. A
card sits on one cell at most. On a laid card, every edge that matches its neighbour -- or the
board's number on the rim -- lights up in green, and the count of matches,
1 to 4, is its activation level, shown in the corner. A card with no match is
inert. Hovering a card, in the deck or on the board, shows it on the right
as a card: its illustration in the frame's window, its four numbers in the
trapezoids on the frame's edges, its name in the banner, and in the box the
four levels -- *Pairs:* above them, the levels in force in green, the rest
faded, *Cumulative* under them when it is. The list under the card names
every active effect on the board, as an equipment set reads.

A **preset** saves the board and the cards laid on it under a name, for the
whole account; loading one equips its board and lays its cards again.

## The effects

A card is one row of `mod_stellar_tarot_card`: its four edges, its one tag
(`tag_id`, the deck tab it sits under), and for each of its four levels a
spell (`card_spell_N`, applied as an aura) and/or a script
(`card_script_N`, a C++ class of the module named as `name` or
`name:param:param`). `cumulative` says whether reaching level 3 grants levels
1, 2 and 3 together, or level 3 alone. A level with neither a spell nor a
script, a spell the server does not have or a script it does not know is an
error at load: the card is REFUSED, logged, listed by `.tarot info`, and
cannot be laid -- the deck still shows it, the server declines it. One
already on a board is taken off every board at that load, as is a card
whose row was deleted.

What is in force follows the layout: it is computed again at every change,
at login (every aura of the module is removed first, so a card changed while
the character was away is not carried over) and at `.tarot reload`.
`.tarot effects [player]` lists it. The player sees ONE aura, *Stellar
Tarot*, while anything is in force; the effects' own auras are hidden from
the aura bar (a spell a card names should carry `SPELL_ATTR1_NO_AURA_ICON`,
as the shipped ones do), and the window lists them.

The scripts shipped: `gold_on_kill:<copper>` and `heal_on_kill:<percent>`.
What a script says of itself is a row of `module_string` (and
`module_string_locale` per language) named by `mod_stellar_tarot_script`, with
`{}` for each parameter -- a description changes in the database, without a
rebuild. A spell describes itself through its own tooltip. To add a script,
derive from `StellarTarotScript`, register it in `StellarTarotScripts.cpp`,
add its rows to the SQL.

## The loot

Where cards and boards come from is content, in `mod_stellar_tarot_source`:
one row per source. A row says what drops -- a given card or board by its
number, or one drawn at random from the whole catalogue (`target_id` 0) --
and from what. The only origin so far is a creature killed, sorted by its
entry, the expansion of its map (classic, Burning Crusade, Wrath), the kind of
place (world, dungeon, raid), the heroic mode, its rank (normal, elite, boss)
and its level; a filter left at its default matches anything. Every row is
played on its own, at its own chance, each time a creature's loot is filled,
and what wins joins the loot window like an item of the creature's own table.
A row naming a card missing from the catalogue, or a value out of its list,
is refused at load time and said so in the log.

Three settings in `mod-stellar-tarot.conf`: `StellarTarot.Loot.Enabled`
turns the loot off without unloading the sources; `StellarTarot.Loot.Rate` is
a percentage applied to every chance (1000 multiplies them by ten, for a
test); `StellarTarot.Loot.Known` says whether a card or a board the account
already knows may drop again -- for the workbench, or for trade. `.tarot
sources` lists what is loaded; `.tarot reload` reads the sources again with
the catalogue, and `.reload config` first if a setting changed.

## The workbench

Three cards, any of them, become one card drawn at random from the whole
catalogue, the account's known ones included; three boards become one board.
This happens at the WORKBENCH, an object shared with the other modules of
this repository that have recipes (`mod-spheregrid` among them): one object
in the world (803700), one window, and each module's recipes on it. The first
item placed decides which craft the bench is locked to; taking everything off
frees it.

The bench is a component, `data/lua/Workbench/`, that every such module
ships as an identical copy: the installer places it in `lua_scripts/Workbench/`
when it is absent or older, and the remover takes it out, with the object,
when no other provider remains. The object is shipped the same way -- inserted
only when absent -- and placed in the world by hand, as a game master:

```
.gobject add 803700
```

`.tarot fuse <a> <b> <c>` is the command the bench relays to; it can be typed
as well.

## The cards' art

A card is composed in the window from three textures under
`data/art/Interface/mod-Tarot/`: the frame (`UI/card_frame.blp`, a 2:3
template with a transparent window, a banner, a box and four trapezoids),
the card's illustration (`Cards/<name>.blp`, 512 x 512, DXT1 with mipmaps,
shown behind the window) and its icon (`Cards/<name>_icon.blp`, 256 x 256,
a square cut from the illustration on the card's subject, framed like the
game's icons, used in the deck, on the board and while dragging). The card's
`art` column names the pair, without extension; a card without one shows
its item's icon. The twelve test cards ship with theirs. The tooling that
makes them is the author's; the guide gives the formats.

## The identifiers

One block, 902000 to 903999, one number per asset. They are not settings;
`python tools/shift.py --list` prints them as they stand, and the installer
moves them when a server has taken them.

| family | range | rule |
|---|---|---|
| cards (items) | 902001 – 902499 | card N is item 902000 + N |
| boards (items) | 902501 – 902599 | board B is item 902500 + B |
| item displays, spell icons | same number as the item | |
| spells | 903000 – 903999 | 903000 studies a card, 903001 a board; the aura of card N at level L is 903000 + 4·N + (L − 1) |
| module strings | keyed by the module's name | never in clash |

## What is in the repository

```
install.bat               the installer, which is also the remover
conf/                     the one configuration file
data/art/                 the textures, laid out as they sit in the client's archive
data/dbc/                 the module's own DBC rows, merged into the client's files
data/lua/StellarTarot/    the server script and the window, sent over AIO
data/lua/Workbench/       the shared workbench, identical in every module that uses it
data/sql/                 world and characters
docs/HOWTO.md             how to do things with the module
src/                      the C++: core, effects, loot
tools/                    install.py, uninstall.py, shift.py
```

## Licence

GPL-2.0-or-later -- the licence of AzerothCore, which this module is compiled
into. The full text is in `LICENSE`.
