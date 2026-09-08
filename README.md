# mod-spheregrid

A second progression for AzerothCore 3.3.5a: a grid of cells the character walks
through, buying what it passes with a currency the content awards. Cells grant
statistics, hold sockets for stones and runes, or teach a spell. It sits beside
Blizzard's talent tree without touching it.

The grid, the currency, the items and the interface are all data or Lua — a
server changes them without recompiling.

## What it is made of

| | |
|---|---|
| **the grid** | 2 451 cells, 2 493 links, one entry per class into a single shared layout |
| **the currency** | Spherite, awarded by quests, levels, achievements, dungeons and raids |
| **the price of a cell** | its distance in links from the class entry, times a step, capped |
| **stones** | 16 statistics × 5 qualities, socketed into a cell |
| **runes** | rank runes that push a spell past its last rank, and statistic runes |
| **the workbench** | fuse, reroll, reforge and grind, for stones and runes |
| **41 class spells** | taught by the grid, with their own visuals, sounds and scripts |
| **the interface** | 8 200 lines of Lua, sent to the client by AIO — nothing for players to install |

Earned Spherite and the content of stone cells belong to the ACCOUNT; what is
spent and which cells are lit belong to the CHARACTER. A character resets its own
grid and gets every point back; the account keeps what it earned.

## Requirements

| | |
|---|---|
| [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) | 3.3.5a, built with the module in `modules/` |
| [ALE](https://github.com/azerothcore/mod-ale) or Eluna | the Lua engine that runs the interface |
| [AIO](https://github.com/Rochet2/AIO) | server AND client — the interface is sent over it |
| Python 3 and the `mysql` client | for the installer only |
| a patched client | the installer does it; see [The client](#the-client) |

Optional: [MythicPlus](https://github.com/huptiq/MythicPlus). Without it the
keystone section of the configuration is inert and costs nothing.

Nothing in the client's `FrameXML` has to be changed: the interface hooks the
stock talent window and the stock frames, through AIO.

## Installing

`install.bat` on Windows, `install.sh` elsewhere. Both ask the same things —
where the server is, where the core sources are, where the client is, where to
keep the copies, what to do, and whether to move the module's identifiers if
one is already taken — then do the rest and print every step.

Three ways to run:

| | |
|---|---|
| **Look only** | reads the server, its database and the client; says which identifiers are free; writes nothing |
| **Rehearse** | announces every step it would take, and still writes nothing |
| **Install** | does it |

Start with the first. It costs nothing and tells you whether this server has
room for the module.

**Nothing is written before a copy of it exists.** You choose where those copies
go: a `Backups/` folder inside the module reproducing each file's own path, or
a copy beside each original. Each backup leaves a receipt saying what was kept
and where it came from.

What the installer does, in order:

1. **Survey** — which identifiers the target already uses: in the server's DBC
   files, in the world database's tables, and inside the client's archives.
   Rows the module itself wrote on an earlier install are recognised and do not
   count as taken.
2. **Shift**, if you allowed it and something was taken — see below.
3. **Backup** — every file it is about to write, and a dump of every table it
   is about to change.
4. **Place** — the sources into `<core>/modules/mod-spheregrid`, the interface
   into `<server>/lua_scripts/SphereGrid`, the configuration into
   `<server>/configs/modules`.
5. **SQL** — the world files, then the characters files, in order.
6. **Client** — merges the module's rows into the client's own DBC files and
   writes them, with the module's art, into a new `patch-Z.MPQ`. Nothing
   existing is rewritten; the archive is read after every other, and deleting
   it undoes the whole client half.

Two things are left to you afterwards: **rebuild the core**, so the module is
compiled in, and install **AIO** on both sides — the survey says whether it
found it, and without it no window ever opens.

Running the installer again is safe: it sets its own archive aside before
reading the client, and every SQL file deletes what it is about to write.

### When an identifier is taken

The module allocates its identifiers in blocks — its spells, its items, its
creatures, its displays, its visuals — and a server may already use some of
them: another module, a custom patch. The survey says so, table by table.

Told to move them, the installer picks for every family in clash the smallest
step that puts the whole family on identifiers nobody holds — in the DBC
files, in the database, in the client — and rewrites **every file of the
module** to the new numbers: DBC rows, SQL, C++ and Lua alike. The module is
then what it was, one block over, and you rebuild the core with it.
`data/dbc/shifts.json` records what moved and by how much, so the next survey
looks where things now are.

The same can be done by hand, before installing:

```
python tools/shift.py --list
python tools/shift.py --family spells --by 200000
```

One family is moved by position rather than by sight: the visual kits, whose
numbers are the size of a duration in milliseconds. They are moved only where a
kit is known to be — the DBC fields that hold one and the C++ constants named
for one — and never guessed at.

### A client that already has a `patch-Z`

`patch-Z.MPQ` and `patch-z.MPQ` are the same file on Windows. If the client
already holds an archive of that name that is **not** the module's — another
server's whole patch, perhaps gigabytes of it — the survey says so and stops.
The module's own archive carries a mark inside it and is always recognised,
whatever identifiers the module was installed with.

### Removing

```
python tools/uninstall.py --server <dir> --core <dir> [--client <Data dir>]
                          --keep-characters | --drop-characters [--dry-run]
```

The database is undone by the module's own SQL: every file deletes what it
inserts, and those statements replayed in reverse are the uninstaller. The
module's own tables are dropped. What players earned — the characters tables —
is kept unless you say otherwise. The placed files and the client's archive are
removed, and the core is yours to rebuild.

### By hand

The installer is a convenience, not a requirement. `python tools/install.py
--help` takes the same steps one flag at a time, and every one of them is
something you can do yourself: copy the module into `modules/`, apply
`data/sql/world/` then `data/sql/characters/` in order, copy
`conf/mod-spheregrid.conf.dist` to `configs/modules/mod-spheregrid.conf`, and
copy `data/lua/SphereGrid/` into `lua_scripts/`. The client half — merging
thirteen DBC files and packing an archive — is what the tools are for.

## Configuring

Everything an operator tunes is in `mod-spheregrid.conf`, and nothing else is:

* what a stone grants, per quality, and what a pre-filled cell grants
* what a statistic rune adds, as a percentage of what the grid already gives
* what every kind of content awards — quests, levels, achievements, dungeon
  bosses and clears by tier, raid bosses by content tier, the workbench
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
| `spheregrid_SpellVisual.dbc` | 89 | |
| `spheregrid_SpellVisualKit.dbc` | 57 | |
| `spheregrid_SpellVisualEffectName.dbc` | 28 | |
| `spheregrid_SoundEntries.dbc` | 22 | |
| `spheregrid_SpellDuration.dbc` | 1 | |
| `spheregrid_CreatureDisplayInfo.dbc` | 19 | the summons, and the shapes a spell turns a player into |
| `spheregrid_CreatureModelData.dbc` | 13 | |
| `spheregrid_GameObjectDisplayInfo.dbc` | 1 | the gate |
| `spheregrid_Emotes.dbc` | 3 | animations the module's scripts play |

**These are not files to drop into an archive.** Each holds only what the module
adds, so that their CONTENT can be read, checked against the identifiers a
target already uses, shifted if one is taken, and merged into the client's own
files. Server side, no file is touched at all: the core reads DBC rows from its
`*_dbc` tables, and the module's SQL fills them from the same source.

**The module rewrites none of the game's rows.** Where one of its spells
leaned on a row of the game that had been altered — a visual, a kit, an effect,
a game object display — that row is shipped as a COPY under an identifier of
the module's own, and the module's rows point at the copy. `data/dbc/borrowed.json`
lists them: 54 visuals, 12 kits, 3 effects and one display. The game keeps its
own.

`data/art/` holds the 322 files a stock client has no copy of — models, skins,
textures, sounds and icons — laid out exactly as they must sit inside an
archive. Everything else the interface draws is borrowed from the game.

### The identifiers

| family | range | |
|---|---|---|
| spells | 8 500 001 – 8 610 037 | class spells, Nexus spells, rank spells |
| items | 803 100 – 803 615 | stones, Nexuses, the pin, runes |
| creatures and objects | 803 800 – 803 821 | summons, props, the gate |
| displays | 802 001 – 802 157 | item, creature and object displays |
| visuals and kits | 30 014 – 30 211 | |
| effect names | 8 200 206 – 8 200 302 | |
| sounds and emotes | 990 001 – 990 125 | |
| module strings | 1 – 73 | keyed by the module's name, never in clash |

`python tools/shift.py --list` prints them as they stand, shifts included.

## What is in the repository

```
install.bat, install.sh   the installer, for Windows and for everything else
conf/                     the one configuration file
data/art/                 the art a client has no copy of
data/dbc/                 the module's own DBC rows, and what was borrowed
data/lua/                 the interface: editor, player window, workbench, spells
data/sql/                 world and characters
docs/                     what the interface draws, what the grid says, where things stand
src/                      the C++ — core, crafting, loot, spells
tools/                    install.py, uninstall.py, shift.py, and the collector
```

`tools/collect_client.py` is what PRODUCES `data/dbc` and `data/art`: it reads
a client where the module runs, follows every reference from the module's spells
down to the last texture, and keeps what a stock client lacks. It is here so the
data can be rebuilt, not because installing needs it.

## The grid is data

The layout editor (`.spheregrid editor`) composes a grid in game and saves it as
XML; the importer turns that into the SQL this module ships. A server that wants
its own grid replaces `data/sql/world/08_grid.sql` and nothing else.

A cell says where it sits, which statistic and quality it comes pre-filled with,
and whether it is a node, a socket or a spell cell. It carries no name and no
icon: a name is a language and an icon is art the client already owns, so both
belong to the interface. See `docs/PRESENTATION.md`.

## Reporting a problem

Open an issue with the server's start-up log (the lines mentioning
`SphereGrid` or `spell_ranks`), the output of the installer's **Look only**
run, and — for anything about a spell's look or sound — the spell's name and the
client's locale. `docs/STATUS.md` says what has been verified in game and what
has not.

## Licence

GPL-2.0-or-later — the licence of AzerothCore, which this module is compiled
into, and of AIO, which carries its interface. The full text is in `LICENSE`.
