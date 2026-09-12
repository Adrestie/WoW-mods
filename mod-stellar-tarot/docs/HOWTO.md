# How to do things with mod-stellar-tarot

The README says what the module is. This guide answers "I want to ...", one
section each, in the order a server operator meets them. Every path below is
relative to the module's folder unless it says otherwise.

## Put the module on a server

1. Copy the folder into `modules/` of the AzerothCore source tree.
2. Run `cmake .` in the build tree, then build `worldserver`.
3. Run `install.bat` (or `python tools\install.py`) from the module's folder.
   It reads `worldserver.conf` to find the databases and the client, checks
   that the module's identifiers are free (`--survey` does only that), applies
   the SQL, copies the configuration, places the shared workbench under
   `lua_scripts/Workbench/` if no other module did, and writes the module's
   DBC rows and art into the client's `patch-Z.MPQ` -- into an existing one if
   the client already has it. Everything it replaces is copied aside first,
   under `Backups/`, with a receipt.
4. Start the server. The world updater applies `data/sql/world/` and
   `data/sql/characters/` by itself at every start; `.tarot info` lists the
   catalogue loaded.

The client must be closed while its archive is written.

## Patch a client that is not on the server

`python tools\install.py --client-only --client "D:\World of Warcraft\Data"`
on the machine where the client lives. Nothing else is touched.

## Make room when the identifiers are taken

`python tools\install.py --survey` says which of the module's items, spells
and displays a server already uses. `python tools\shift.py --list` prints the
families and their ranges; `install.py --shift` moves a family in one block to
the first free range and rewrites the SQL, the DBC rows and the Lua that name
them. The rule inside a family never changes: card N stays item base + N.

## Hand a card or a board to a player

`.additem <entry>`, the core's own command; `.tarot info` gives every entry.
The module adds no command the core already has.

## Add a card

A card is one row of `mod_stellar_tarot_card`, plus its item, plus the
spells its levels apply. The test catalogue is written by a generator that is
not shipped; by hand:

1. Pick a number N that is free (1 to 499). The item is `902000 + N`, in
   `item_template` (a copy of a shipped card's row does), with a row in the
   module's `Item.dbc` data for the client.
2. Insert the card: its four edges (1 to 9), its one `tag_id`, `cumulative`,
   and for each of the four levels a `card_spell_N` and/or a `card_script_N`.
   A level with neither, a spell the server lacks or a script it does not
   know REFUSES the card at load: `.tarot info` says why.
3. A spell applied as an aura should carry `SPELL_ATTR1_NO_AURA_ICON`
   (`AttributesEx` bit 0x10000000): the player sees one aura, *Stellar
   Tarot*, and the window lists the effects.
4. `hint` (and `mod_stellar_tarot_card_locale` per language) is what the deck
   says of a card the account does not know yet: where to find it.
5. `art` is the path, without extension, of the card's illustration -- see
   *Give a card an illustration* below -- or empty for the item's icon.
6. `.tarot reload`. Every layout is computed again from the new catalogue.

## Add a board

A row of `mod_stellar_tarot_board` -- number B (1 to 99, item `902500 + B`),
`row_count` and `col_count` (2 to 4) -- and its numbers in
`mod_stellar_tarot_board_line`: one row per row-or-column, per side (`axis`
1 rows / 2 columns, `idx` from 1, `side` 1 first / 2 second, `number` 1 to
9). A row's first side faces the left edge of its first card, its second the
right edge of its last; a column's first side faces the top edge of its
first card, its second the bottom edge of its last. A board with a number
missing is refused. `.tarot reload`.

## Change what a card does

Edit its `card_spell_N` / `card_script_N` columns and `.tarot reload`. A
script is named as `name` or `name:param:param`; the shipped ones are
`gold_on_kill:<copper>` and `heal_on_kill:<percent>`. What a script says of
itself in the window is a row of `module_string` (and `module_string_locale`)
named by `mod_stellar_tarot_script`, with `{}` for each parameter: text
changes in the database, no rebuild.

## Add a script

Derive from `StellarTarotScript` (`src/effects/StellarTarotScript.h`),
register the class in `StellarTarotScripts.cpp`, give it a description row in
`mod_stellar_tarot_script` and `module_string`, rebuild. A card may then name
it.

## Change what drops, and how often

One row of `mod_stellar_tarot_source` per source: what drops (`what` card or
board, `target_id` the number, or 0 for one drawn at random from the whole
catalogue), and from what -- for now a creature killed, sorted by
`creature_entry`, `expansion` of its map, `place` (world, dungeon, raid),
`heroic`, `creature_rank` (normal, elite, boss) and its level. A filter left
at its default matches anything. Every row is played on its own, at its
`chance` in percent, each time a creature's loot is filled; what wins joins
the loot window. `.tarot sources` lists what is loaded, `.tarot reload` reads
it again.

Three settings in `mod-stellar-tarot.conf`: `StellarTarot.Loot.Enabled`,
`StellarTarot.Loot.Rate` (a percentage on every chance -- 1000 for a test),
`StellarTarot.Loot.Known` (whether a card the account already knows may drop
again). `.reload config` after a change, then `.tarot reload`.

## Put a workbench in the world

The workbench is shared with the other modules of the repository: one game
object, 803700, whose template the installer inserts when absent. Where it
stands is your decision: as a game master, at the spot, `.gobject add 803700`.
The tarot brings two recipes to it: three cards become one drawn at random,
three boards likewise -- known cards included, so that duplicates have a use.
With mod-spheregrid installed as well, the same bench serves both: the first
item placed decides which craft it is locked to until it is emptied.

## Give a card an illustration

The window composes a card from three textures, all under
`data/art/Interface/mod-Tarot/`:

- `UI/card_frame.blp`: the frame, shipped. A 2:3 template with a transparent
  window at the top, a banner for the name, a box for the levels and four
  trapezoids on the edges for the numbers.
- `Cards/<name>.blp`: the illustration, 512 x 512, DXT1 with mipmaps. The
  window shows it behind the frame's window, cut top and bottom to the
  window's proportions.
- `Cards/<name>_icon.blp`: the icon, 256 x 256, DXT1 with 1-bit alpha and
  mipmaps: a square cut from the illustration on the card's subject, with the
  4-pixel frame of the game's own icons around it. The deck, the board and
  the drag ghost use it.

Set the card's `art` to `Interface\mod-Tarot\Cards\<name>` (no extension),
put the two files in the folder, run the installer's client step again, and
`.tarot reload`. A card without `art` shows its item's icon everywhere.

The tooling that cuts, frames and encodes the shipped illustrations is the
author's and is not part of the module; any BLP2 writer that produces the
formats above will do.

## Add a language

Every text the module shows comes from three places: `module_string_locale`
for what the commands and the scripts say, `mod_stellar_tarot_card_locale`
and `mod_stellar_tarot_tag_locale` for the hints and the tags, and the
`_Lang_` columns of the module's spells for their names. Add rows for the
locale; the window's own labels are in `data/lua/StellarTarot/Tarot_Client.lua`,
English and French, keyed by `GetLocale()`.

## Update the module

Replace the folder, `cmake .`, rebuild, run `install.bat` again: it takes its
earlier rows out of the client's archive before merging the new ones, and the
world updater applies changed SQL files at the next start.

## Take the module off

`install.bat` offers the removal; it is `python tools\uninstall.py`. It drops
the module's tables, takes its rows out of the shared tables, removes its
configuration, takes the shared workbench folder and object away only if no
other module still registers a provider, and takes the module's files out of
the client's archive, putting back the client's own files from the receipt of
the run that replaced them. Then rebuild the core without the folder.

## When something is wrong

### `.tarot info` lists a card as REFUSED

The reason follows: an edge out of 1..9, a level with neither spell nor
script, a spell the server does not have, a script it does not know, a tag
that does not exist. The card is taken off every board it was on. Fix the
row, `.tarot reload`; the deck showed it all along, and lays it again.

### A card's aura shows in the aura bar

The spell lacks `SPELL_ATTR1_NO_AURA_ICON`. Only *Stellar Tarot* is meant to
show.

### The window does not open

The client did not receive the addon: check that `lua_scripts/StellarTarot/`
holds `Tarot.lua` and `Tarot_Client.lua`, and `lua_scripts/AIO_Server/` the
AIO transport, then `.reload ale`.

### A card has no illustration, or a black square

The texture is not in the client's archive, or the client was running when
it was written. Close the client, run the client step of the installer again.
A card whose `art` names a missing file shows a black square.

### The workbench refuses an item

"Nothing on this workbench takes that item": no installed module owns it.
"That item belongs to another craft": the bench holds items of another
module; empty it. "That item does not go with what is on the bench": no
recipe with room left admits it with what is placed.

### Nothing drops

`.tarot sources` first: the loot may be off, the rate at 0, or every row
refused (the log says why). Then the row's filters: a creature in a raid map
never matches `place = 'dungeon'`; `expansion` is the map's, not the
creature's.
