# mod-spheregrid

A second progression for AzerothCore 3.3.5a: a grid of cells the character walks
through, buying what it passes with a currency the content awards. Cells grant
statistics, hold sockets for stones and runes, or teach a spell. It sits beside
Blizzard's talent tree without touching it.

The grid, the currency, the items and the interface are all data or Lua — a
server changes them without recompiling.

Published at <https://github.com/Adrestie/WoW-mods/tree/main/mod-spheregrid>,
one folder of the WoW-mods repository. Issues and questions go there.

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
| Python 3 and the `mysql` client | for the installer, and for the layout editor |
| Pillow and numpy | for the layout editor only: `pip install pillow numpy` |
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

**A client is not optional.** The module's spells exist in no client: without
its rows a player sees no name, no icon and no effect, and cannot cast them.
The installer asks for one, and lets you go on without it only if you say so —
for a server that has no client on it, which is most Linux ones. Patch a client
where it lives, afterwards:

```
python tools/install.py --client-only --client <client Data dir>
```

That mode needs no server and touches no database: it reads the module's own
rows, merges them into that client's DBC files, and writes the archive.

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
   writes them, with the module's art, into `patch-Z.MPQ`: a new archive when
   the client has none, the client's own when it already has one — see
   [below](#a-client-that-already-has-a-patch-z).

Three things are left to you afterwards. **Rebuild the core**, so the module
is compiled in. Install **AIO** on both sides — the survey says whether it
found it, and without it no window ever opens. And **put down a workbench**:
the module ships the object, not a place for it, since where it stands is a
decision about your world and not about the module. Stand where you want one,
as a game master:

```
.gobject add 803700
```

As many as you like, wherever you like — a capital of each faction is the
usual choice. The object is a window, not a gate: `fuse`, `reroll`, `reforge`
and `grind` are commands, and a player who never walks past a workbench can
still use them.

Run again on a server that already has the module, the installer does not
install: it becomes the remover — see [Removing](#removing). To update the
module, remove it, then install it again. Everything it writes is nonetheless
written to be run twice: every SQL file deletes what it inserts, the module's
own archive is set aside before the client is read, and in a shared one the
module's earlier rows are taken out before its current ones go in.

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

Two families are moved by position rather than by sight: the visual kits,
whose numbers are the size of a duration in milliseconds, and the spell icons,
whose numbers are the size of anything. They are moved only where one is known
to be — the DBC fields that hold one, the columns of a `spell_dbc` row, the C++
constants named for one — and never guessed at.

### A client that already has a `patch-Z`

`patch-Z.MPQ` and `patch-z.MPQ` are the same file on Windows, and a server
that ships its own patch usually ships it under that name. The installer tells
three cases apart, and says which one it is in:

| | |
|---|---|
| **no `patch-Z`** | a new archive is created holding only what the module adds — the module's **own**. The next run sets it aside and writes it again; the uninstaller deletes it whole. |
| **the module's own**, from an earlier run | recognised by a mark inside it, whatever identifiers the module carried then. |
| **the client's own** — another server's patch, perhaps gigabytes of it | the module is written **into** it. |

Written into means: the survey reads the DBC files that archive holds, as it
reads any other, and a taken identifier is a clash like any other — moved with
`--shift`, or you stop. Then each file the module is about to replace is copied
aside (the receipt says where), the module's rows are merged into the archive's
own DBC files, and those files, with the module's art, are written into the
archive **in place**: the new data goes at the end, the archive's tables are
updated to point at it, and nothing else in the archive moves. A DBC in the
archive holds the server's rows AND the module's. The archive stays the
client's; it is now **shared**, and a record inside it lists exactly which rows
and which files are the module's.

That record is what the next run and the uninstaller read. Running the
installer again takes the module's earlier rows out of each DBC before merging
its current ones in — so a module updated, or shifted, between two runs leaves
nothing behind. Uninstalling takes those rows out and puts nothing in, removes
every file the module added, and puts back from the copies every file of the
client's it wrote over: the archive is the client's again.

Two things to know. An archive written into never shrinks: what a replaced file
used to occupy stays in it, unreadable, as with every MPQ tool — a run adds
about 45 MB, and a compaction tool reclaims it if it matters. And a checksum
file some tools keep in an archive, `(attributes)`, is removed the first time,
because its entries could no longer match; the game never reads it, and its
copy is in the backups.

This writer stops at 4 GB: an archive larger than that keeps a second table
this module does not handle, and the installer says so before writing a byte.

### Removing

Run the installer. `install.bat` and `install.sh` look first — the module's
sources under `modules/`, its interface, its configuration, its tables in the
world database, its rows in the client's archive — and when any of it is there
they say so and switch to removing: they ask what becomes of what players
earned, whether to rehearse first, and go. So does `tools/install.py`, told
what to do with the characters tables:

```
python tools/install.py --server <dir> --core <dir> [--client <Data dir>]
                        --keep-characters | --drop-characters [--dry-run]
python tools/install.py --server <dir> --core <dir> [--client <Data dir>] --presence
```

`--presence` only answers the question — exit code 3 when the module is there,
0 when it is not — and writes nothing. `tools/uninstall.py`, with the same
flags, is the removal without the detection.

The database is undone by the module's own SQL: every file deletes what it
inserts, and those statements replayed in reverse are the uninstaller. The
module's own tables are dropped, and the spells it TAUGHT are taken back from
the core's own tables — a learnt spell lands in `character_spell`, not in
anything the module owns, and left behind it names a spell that no longer
exists. A reinstall teaches them again at the next login, from the cells the
player still owns. What players earned — the characters tables —
is kept unless you say otherwise. The placed files are removed. So is the
client's archive when it is the module's own; when it is the client's, written
into, the module is taken out of it — see above. The core is yours to rebuild.

### By hand

The installer is a convenience, not a requirement. `python tools/install.py
--help` takes the same steps one flag at a time, and every one of them is
something you can do yourself: copy the module into `modules/`, apply
`data/sql/world/` then `data/sql/characters/` in order, copy
`conf/mod-spheregrid.conf.dist` to `configs/modules/mod-spheregrid.conf`, and
copy `data/lua/SphereGrid/` into `lua_scripts/`. The client half — merging
fourteen DBC files and packing an archive — is what the tools are for.

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
target already uses, shifted if one is taken, and merged into the client's own
files. Server side, no file is touched at all: the core reads DBC rows from its
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
| spells | 8 500 001 – 8 610 037 | class spells, Nexus spells, rank spells |
| items | 803 100 – 803 615 | stones, Nexuses, the pin, runes |
| creatures and objects | 803 800 – 803 821 | summons, props, the gate |
| displays | 802 001 – 802 157 | item, creature and object displays |
| visuals and kits | 30 014 – 30 211 | moved by position, never by sight |
| spell icons | 8 002 – 8 076 | moved by position, never by sight |
| beams | 2 001 | named by a kit as a float; moved by position |
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
docs/                     what the interface draws, and what the grid says
src/                      the C++ — core, crafting, loot, spells
tools/                    install.py, uninstall.py, shift.py, and the collector
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

A server that wants its own grid replaces `data/sql/world/08_grid.sql` and
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
