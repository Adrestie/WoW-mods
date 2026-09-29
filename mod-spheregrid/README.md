# mod-spheregrid

A second progression for AzerothCore 3.3.5a: a grid of cells the character walks
through, buying what it passes with a currency the content awards. Cells grant
statistics, hold sockets for stones and runes, or teach a spell. It sits beside
Blizzard's talent tree without touching it.

**[docs/HOWTO.md](docs/HOWTO.md)** answers "I want to ..." -- install it, draw a
grid of my own, change what a stone grants, put a workbench down -- and says
what to do when something is wrong.

Earned Spherite and the content of stone cells belong to the ACCOUNT; what is
spent and which cells are lit belong to the CHARACTER. A character resets its own
grid and gets every point back; the account keeps what it earned.

## Requirements

| | |
|---|---|
| [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) | 3.3.5a, built with the module in `modules/` |
| [ALE](https://github.com/azerothcore/mod-ale) or Eluna | the Lua engine that runs the interface |
| [AIO](https://github.com/Rochet2/AIO) | server AND client — the interface is sent over it |
| the WoW-mods installer | `installer.exe`, from the `installer/` folder of this repository; MySQL running |
| Python 3 and the `mysql` client | for the layout editor only |
| Pillow and numpy | for the layout editor only: `pip install pillow numpy` |
| a patched client | the installer does it; see [The client](#the-client) |

Optional: [MythicPlus](https://github.com/huptiq/MythicPlus). Without it the
keystone section of the configuration is inert and costs nothing.

Nothing in the client's `FrameXML` has to be changed: the interface hooks the
stock talent window and the stock frames, through AIO.

## Installing

Stop the world server and close the game, then run `installer.exe`, the
WoW-mods installer (`installer/` folder of this repository), and give it this
folder, or drop the folder on `installer.exe`. Keep the package where you
downloaded it: the installer refuses to run from your server's `modules`
folder. Its window asks for the world server folder and the game folder, finds
the rest (the sources, the databases, `mysql.exe`, the Lua scripts folder),
shows what it found of the module, and offers the one action that fits:
**Install** when there is no trace of it, **Remove** when there is.
`installer.json` declares everything it puts in place.

Installing puts in place:

- the sources, into `modules/mod-spheregrid` of your AzerothCore sources;
- `mod-spheregrid.conf` and its `.dist`, into the module configuration folder;
- the interface, `data/lua/SphereGrid/`, into `lua_scripts/SphereGrid/`;
- the workbench, `data/lua/Workbench/`, into `lua_scripts/Workbench/`, unless
  the same or a newer version is already there;
- the module's rows of fifteen DBC files, merged into the game's own files
  inside its archives, and the 372 files of `data/art`: into the last custom
  archive the game reads, or into a new `Data\patch-Z.MPQ` when there is none.

**A client is not optional.** The module's spells exist in no client: without
its rows a player sees no name, no icon and no effect, and cannot cast them.

Three things are left to you afterwards. **Rebuild the core**, the world
server stopped: the installer prints the commands. On first start, the core
updater applies `data/sql/world` and `data/sql/characters` (the installer
applies them itself when `Updates.EnableDatabases` leaves a database out).
Install **AIO** on both sides: without it no window ever opens. And **put down
a workbench**: the module ships the object, not a place for it, since where it
stands is a decision about your world and not about the module. The workbench
is SHARED with the other modules of this repository that have recipes -- one
object, one window, one `lua_scripts/Workbench/` folder -- and each module
brings its own recipes to it. Stand where you want one, as a game master:

```
.gobject add 810000
```

As many as you like, wherever you like — a capital of each faction is the
usual choice. The object is a window, not a gate: `fuse`, `reroll`, `reforge`
and `grind` are commands, and a player who never walks past a workbench can
still use them.

### When an identifier is taken

The module's numbers sit in tranches 85 and 86 of the repository's register,
`ID_RANGES.md`. When a server already uses one of them for something else --
another module, a custom patch -- the installer lists each one and installs
nothing: the numbers of one of the two have to change.

### Removing

Run the installer again on this folder, the world server stopped and the game
closed. Finding the module, even in part, it lists what it found and, once you
confirm, removes all of it: the sources, the configuration, the interface, the
module's rows in the game's archives and its art, and in the database its
tables -- the Spherite and the cells players bought included --, its rows in
the core's tables, the spells it taught (`character_spell`, `character_aura`,
the action bars) and the updater's record of its files. The workbench stays
while another module still uses it; the last one to go takes it away, with the
object 810000 and its spawns. Layouts the in-game editor saved in
`lua_scripts/SphereGrid/editor/layouts` are yours: they stay, and so does the
folder that holds them. Then rebuild the core.

To update the module, remove it, then install it again. The removal takes what
players earned with it: to keep it, save the four `mod_spheregrid_*` tables of
the characters database before, and put them back after.

### By hand

Every server step is something you can do yourself: copy the module into
`modules/`, apply `data/sql/world/` then `data/sql/characters/` in order, copy
`conf/mod-spheregrid.conf.dist` to `configs/modules/mod-spheregrid.conf`, and
copy `data/lua/SphereGrid/` and `data/lua/Workbench/` into `lua_scripts/`. The
client half -- merging fifteen DBC files and packing an archive -- is what the
installer is for.

## Configuring

Everything an operator tunes is in `mod-spheregrid.conf`, and nothing else is:

* what a stone grants, per quality, and what a pre-filled cell grants
* what a statistic rune adds, as a percentage of what the grid already gives
* what every kind of content awards — quests, levels, achievements, dungeon
  bosses and clears by tier, raid bosses by content tier, the workbench
* what every source drops — each kind of monster, each vein and herb, each
  skinning bracket, each kind of chest: its rolls, their fallbacks, quantities
  and rates, one setting per source; and on top of it how often each object
  drops wherever it appears. What makes a source is not a setting
* the price of a step, its cap, and how many identical runes stack

The interface reads the same file, so what it announces is what the module
charges. `.spheregrid reload` reads the configuration and the tables again,
without restarting.

The identifiers the module allocates are NOT settings. They are part of the
module, and adapting them to a server that already uses those ranges is the
installer's job.

## Commands

`.spheregrid <sub> help` explains each one in game, in the player's language.

| for players | |
|---|---|
| `show` | opens the window |
| `activate` | buys a cell |
| `socket` / `unsocket` | fills or empties a cell |
| `fuse` / `reroll` / `reforge` / `grind` | the workbench |
| `respec` | hands the grid back and returns every point spent |

| for game masters | |
|---|---|
| `info` | the state of the loaded definition |
| `status` / `stats` | a player's points, and what the grid grants them |
| `points add\|remove\|set` | changes a player's Spherite |
| `reset` / `wipeall` | wipes one character, or a whole account |
| `reload` | reads the definition again |
| `editor` | the layout editor |

## The client

A player installs nothing: the interface is Lua the server sends. But the client
must know what the module adds — a spell it has no row for has no name, no icon
and no visual.

`data/dbc/` holds the module's own rows, and only those:

| | rows | |
|---|---:|---|
| `spheregrid_Spell.dbc` | 621 | the class spells, their ranks, and the rank spells the runes grant |
| `spheregrid_Item.dbc` | 257 | stones, runes, Nexuses, the pin |
| `spheregrid_ItemDisplayInfo.dbc` | 154 | |
| `spheregrid_SpellIcon.dbc` | 32 | |
| `spheregrid_SpellVisual.dbc` | 90 | |
| `spheregrid_SpellVisualKit.dbc` | 58 | |
| `spheregrid_SpellVisualEffectName.dbc` | 28 | |
| `spheregrid_SoundEntries.dbc` | 22 | |
| `spheregrid_SpellDuration.dbc` | 1 | |
| `spheregrid_CreatureDisplayInfo.dbc` | 20 | the summons, and the shapes a spell turns a player into |
| `spheregrid_CreatureModelData.dbc` | 14 | |
| `spheregrid_GameObjectDisplayInfo.dbc` | 1 | the gate |
| `spheregrid_Emotes.dbc` | 3 | animations the module's scripts play |
| `spheregrid_SpellChainEffects.dbc` | 1 | the beam of Ray of Frost |

**These are not files to drop into an archive.** Each holds only what the module
adds, so that their CONTENT can be read, checked against the identifiers a
target already uses, and merged by the installer into the client's own files. Server side, no file is touched at all: the core reads DBC rows from its
`*_dbc` tables, and the module's SQL fills them from the same source.

**The module rewrites none of the game's rows.** Where one of its spells
leaned on a row of the game that had been altered — a visual, a kit, an effect,
a game object display — that row is shipped as a COPY under an identifier of
the module's own, and the module's rows point at the copy. `data/dbc/borrowed.json`
lists them: 54 visuals, 12 kits, 3 effects and one display. The game keeps its
own.

`data/art/` holds the 372 files a stock client has no copy of — models, skins,
textures, sounds and icons — laid out exactly as they must sit inside an
archive. Everything else the interface draws is borrowed from the game.

### The identifiers

| family | range | |
|---|---|---|
| spells | 85 000 – 86 508 | class spells, Nexus spells, rank spells |
| items | 85 000 – 85 515 | stones, Nexuses, the pin, runes |
| creatures | 85 800 – 85 817 | summons, props |
| objects | 850 820 – 850 821 | the gate |
| displays | 85 001 – 85 157 | item, creature and object displays |
| visuals and kits | 85 014 – 85 211 | |
| spell icons | 85 002 – 85 076 | |
| beams | 85 001 | named by a kit as a float |
| effect names | 85 206 – 85 302 | |
| sounds and emotes | 85 001 – 85 125 | |
| module strings | 1 – 73 | keyed by the module's name, never in clash |

## What is in the repository

```
installer.json            what the WoW-mods installer puts in place, and removes
conf/                     the one configuration file
data/art/                 the art a client has no copy of
data/dbc/                 the module's own DBC rows, and what was borrowed
data/lua/                 the interface: editor, player window, workbench, spells
data/sql/                 world and characters
docs/                     what the interface draws, and what the grid says
src/                      the C++ — core, crafting, loot, spells
tools/                    the client collector and the layout editor
```

`tools/collect_client.py` is what PRODUCES `data/dbc` and `data/art`: it reads
a client where the module runs, follows every reference from the module's spells
down to the last texture, and keeps what a stock client lacks. It is here so the
data can be rebuilt, not because installing needs it.

## The grid is data

A cell says where it sits, which statistic and quality it comes pre-filled with,
and whether it is a node, a socket or a spell cell. It carries no name and no
icon: a name is a language and an icon is art the client already owns, so both
belong to the interface. See `docs/PRESENTATION.md`.

A server that wants its own grid replaces `data/sql/world/spheregrid_08_grid.sql` and
nothing else. Two editors write it, and they share one file.

### In game

`.spheregrid editor`, for administrators. It lays clusters down, joins cells,
sets what each one grants and marks the door each class comes in by, and saves
the whole as a readable XML under `lua_scripts/SphereGrid/editor/layouts`.

### Out of game

`layout.cmd` opens the same layouts in a window of its own, and does what the
game cannot:

* **Generate** a grid from the bank of cluster shapes -- a seed, how many
  clusters, how big they may be, and it says about how many cells that makes.
  The drawing only: what the cells grant comes after.
* **Paint** what they grant. One layer per statistic, several at once, an eye
  to hide one; the brush softens the DENSITY and never the value, so nothing
  outside the palette is ever written. The map lives beside the layout, same
  name with `.png`, and carries the quality rings inside itself.
* **Rarity**: five bands from a centre you can move, each in the colour of its
  quality.
* **Edit**: make and unmake links, change what a cell is, give a spell cell its
  spell class by class, set the starts, and see the shortest path from every
  door at once. It says when the grid is cut in two, when links lie over one
  another, and when a class has no door yet.
* **Export**: the SQL written beside the layout AND applied to the world
  database of the server the layout belongs to. One thing is then left to do in
  game: `.spheregrid reload`.

WHAT THE GAME WRITES, THE WINDOW READS. Save a layout in game with the window
open and it reloads by itself; it asks first if there is unsaved work in it.

## Reporting a problem

Open an issue with the server's start-up log (the lines mentioning
`SphereGrid` or `spell_ranks`), the output of the installer's **Look only**
run, and — for anything about a spell's look or sound — the spell's name and the
client's locale.

## Licence

GPL-2.0-or-later — the licence of AzerothCore, which this module is compiled
into, and of AIO, which carries its interface. The full text is in `LICENSE`.
