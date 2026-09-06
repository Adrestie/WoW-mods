# mod-papota-spherier

A custom progression system for **AzerothCore 3.3.5a**, written for the Papota
server: a **sphere grid** ("sphérier") shared by every class, bought node by
node with **Spherite** earned from raid bosses, dungeons and Mythic+ runs. Nodes
carry stat stones, spell slots and runes; spell nodes unlock **96 custom class
spells** (ten classes, mobility spell plus three per specialisation, each with
its own backported visual, sound and icon) and **519 extra spell ranks**. Nodes,
stones and Spherite are **account-bound**; slot content and spell choices stay
per character. The grid is drawn in-game by a graphical **editor** (GM side) and
used through a **player interface**, both delivered by [AIO](https://github.com/Rochet2/AIO):
players install nothing but a client patch for names, icons and visuals.

Everything below was validated on the Papota server (mod-playerbots fork of
AzerothCore, French client). Game texts are in **French**; spells and items also
carry English names in the `enUS` column, so any client locale shows something
sensible. Code comments and tooling are in French.

---

## 1. What the package contains

```
mod-papota-spherier/
├── src/                          C++ module (13 files): state, points, loot, workbench,
│                                 class-spell scripts, console commands
├── data/sql/db-world/base/       44 files, applied by the AzerothCore updater in name order:
│                                 42 dated files (tables, spells, items, creatures, strings…)
│                                 + 2026_09_06_90 spell_dbc (all 621 spells, final state)
│                                 + 2026_09_06_91 grille (the common grid and tuning tables)
├── data/sql/db-characters/base/  5 files: character and account state tables
├── data/lua/Spherier/            7 Lua files (server logic + AIO interfaces) and the grid
│                                 layouts (commune.xml = the live grid, banque.xml = cluster bank)
├── tools/                        client patch builder: build_client_patch.py / .cmd,
│                                 patch_server_dbc.cmd, StormLib.dll, dbc_rows.json (the
│                                 DBC rows to add), files/ (428 models, textures, sounds,
│                                 icons and interface art), export_report.txt
├── tools/dev/                    the generators and benches that produced all of it
│                                 (French, tied to the author's workstation paths)
├── optional/                     two core patches, one for mod-dungeon-clear, one Lua
│                                 snippet for Mythic+ — see optional/README.md
├── docs/                         SPHERIER_CONCEPTION.md (design document, French),
│                                 RETROPORTAGE_M2.md (how retail models were backported)
├── include.sh, LICENSE (MIT), README.md
```

### Identifiers used

| What | Range |
|---|---|
| Spells (sphere, Nexus, class spells, ranks, gauges) | 8500001–8549999 and 8600000–8619999 (621 spells) |
| Items (stones, Nexus, prism, pin, runes) | 803100–803615 (257 items) |
| Creatures (summons of class spells) | 803801–803817 |
| Game objects (workbench 803700, Death Gate 803820) | 803700, 803820 |
| Item displays / creature displays | 802001–802157 / 802101–802130 |
| Spell visuals, kits, effects, sounds, emotes, icons | 30001+, 30001+, 30011+ and 8200200+, 990100+, 990001–990004, 8050+ |
| World tables | `papota_sphere_*` (12 tables) |
| Characters tables | `character_sphere_points`, `character_sphere_node`, `account_sphere_points`, `account_sphere_node` |
| Console strings | `module_string` rows of module `mod-papota-spherier` (57) |

Every row is an addition, with one exception: the display row 8500 of the
Death Gate is retouched for the death knight's portal. 26 Blizzard files are
replaced by their retail versions (textures and two models used by the
backported visuals); `tools/export_report.txt` lists them.

---

## 2. Requirements

* **AzerothCore 3.3.5a**, any recent revision. The module was built on the
  [mod-playerbots fork](https://github.com/mod-playerbots/azerothcore-wotlk)
  (`efe123fab5`, 2026-08-14); it only uses standard ScriptMgr hooks. With
  mod-playerbots present, bots are ignored (guarded by `MOD_PLAYERBOTS`); without
  it the module compiles unchanged.
* **mod-ale** (or Eluna) with **AIO** installed in `lua_scripts/AIO_Server`
  (Rochet2's AIO, GPL). The interfaces are AIO addons: the server sends them to
  the client, players install nothing.
* **MySQL 8** (the SQL uses `utf8mb4`).
* **Python 3.8+ (64-bit) on Windows** for the client patch builder (it drives
  the bundled `StormLib.dll`). Linux users can run it under Wine or build the
  MPQ with any StormLib-based tool from `tools/files` and the DBCs the script
  produces.
* A **3.3.5a client (build 12340)** of any locale.

---

## 3. Server installation

### 3.1 Drop the module in

Copy the `mod-papota-spherier` folder into `modules/` of your AzerothCore
checkout. If you use mod-dungeon-clear and want dungeon-completion Spherite,
apply `optional/mod-dungeon-clear/dungeon_completed_credit.diff` now (it
includes a header from this module).

### 3.2 Build

Re-run CMake and build as usual. `modules.lib` picks the module up
automatically (`src/spherier_loader.cpp`). Two class spells need a two-hunk
core patch to be cast while moving: `optional/core/spell_cast_while_moving.diff`
— see `optional/README.md`. Without it they work, standing still.

### 3.3 Apply the SQL

Nothing to do by hand: the updater applies `data/sql/db-world/base` and
`data/sql/db-characters/base` at the first start, in **name order**. The two
files dated `2026_09_06_90` and `_91` come last on purpose: they hold the
**final state** of every custom spell (`spell_dbc`) and of the grid
(`papota_sphere_*`), and replace what the dated history left. Replaying the
whole folder on a stock `acore_world` reproduces the Papota production tables
row for row (this was checked with `packages/valide_sql_spherier.py` before
publishing).

The server needs **no patched Spell.dbc or Item.dbc**: AzerothCore loads the
`spell_dbc` and `item_dbc` tables on top of its DBC files, and both tables can
add rows.

### 3.4 Patch four server DBC files

Four things the server reads only from files: a spell duration, four emotes,
the display and model rows of the summoned creatures. Stop the worldserver and
run:

```
tools\patch_server_dbc.cmd  <server>\Data\dbc
```

It adds our rows to `SpellDuration.dbc`, `Emotes.dbc`, `CreatureDisplayInfo.dbc`
and `CreatureModelData.dbc`, keeping a `.avant_spherier` copy of each. It is
idempotent.

### 3.5 Install the Lua

Copy `data/lua/Spherier` into your `lua_scripts` folder, next to `AIO_Server`.
It contains:

| File | Side | Role |
|---|---|---|
| `Spherier_Joueur.lua` / `Spherier_Joueur_Client.lua` | server / client | the player interface (`/spherier`, `.spherier show`) |
| `Spherier_Server.lua` / `Spherier_Client.lua` | server / client | the grid editor (`.spherier editor`, administrators) |
| `Spherier_Etabli.lua` / `Spherier_Etabli_Client.lua` | server / client | the workbench (game object 803700: socket, unsocket, fuse, reroll, reforge stones) |
| `Solstice_Client.lua` | client | the celestial gauge of the druid, drawn on the Eclipse bar |
| `layouts/commune.xml`, `layouts/banque.xml` | data | the live grid and the cluster bank, for the editor |

Client-side files are minified by AIO (LuaSrcDiet) before being sent; the
whole definition of the grid travels once per session in a compact format.

### 3.6 Start up and check

Start the worldserver. In the console:

```
.spherier info
```

must report the loaded definition (4 683 nodes, 4 675 edges, 247 clusters,
10 starts, 41 class-spell assignments). Log in with a character and type
`/spherier`: the grid opens on the class start node.

### 3.7 Place the workbench

The workbench is game object 803700. Spawn it where you want players to work
their stones: `.gobject add 803700`.

---

## 4. Client installation

Without this step players see unnamed spells with question-mark icons, no
grid art, and no visuals for the class spells.

### 4.1 Build the patch

Close the game, then run (Python 3.8+ 64-bit on the PATH):

```
tools\build_client_patch.cmd  "C:\Games\World of Warcraft 3.3.5a"
```

The script reads the client's own archives in load order (Blizzard first, then
any custom patch you already have), inserts the module's rows into the
effective `Spell.dbc`, `Item.dbc`, `ItemDisplayInfo.dbc`, `SpellVisual*.dbc`,
`SoundEntries.dbc`, `SpellIcon.dbc`, `SkillLineAbility.dbc`, `Emotes.dbc`,
`CreatureDisplayInfo.dbc`, `CreatureModelData.dbc`, `SpellChainEffects.dbc`,
`SpellDuration.dbc` and `GameObjectDisplayInfo.dbc` (15 tables), adds the 428
files, writes
`Data\patch-S.MPQ`, and reads it back to confirm every row and file is there.
It must end with:

```
Terminé. Relecture : toutes les lignes et tous les fichiers sont présents.
```

Pick another letter with a second argument (`... "C:\Games\WoW" Z`) if `S`
would sort before one of your existing patches: the client loads archives in
alphabetical order and the last one wins. Rows are **added** to whatever your
other patches already carry, so the patches compose; rebuild ours after
changing theirs.

### 4.2 Check

Log in, `.additem 803205` (Prismatic Nexus): the item must show its name and
icon. Open `/spherier`: links, arcs and round stat icons must be drawn. Learn
a class spell from the grid: its icon, tooltip and visual must appear.

---

## 5. Full check

1. `.spherier points add 3000` then `/spherier`: the start node of the class is
   lit; buying an adjacent node costs the first tier (100 Spherite) and applies
   its stone (+1 to +7 of a statistic, shown in the character sheet).
2. Buy a spell node of your class: the spell appears in the spellbook tab of its
   specialisation and in the left panel of the interface (red = not learned,
   green = learned).
3. Kill a raid boss: Spherite arrives according to `papota_sphere_point_source`
   (250 Vanilla … 2000 ICC 25 heroic); dungeon bosses 75–150; a completed
   dungeon 50–150 with the optional mod-dungeon-clear patch.
4. `.additem 803205` and use it: each Prismatic Nexus raises every future
   Spherite gain of the account by 25 %, and is destroyed.
5. Use the workbench: socket a stone, unsocket it, fuse two, reroll.
6. Log a second character of the account: the Spherite and the node stones are
   already there; slot content is not.
7. As administrator, `.spherier editor`: the grid opens in the editor; the
   "Par classe…" button of a spell node lists the spell of each class.
8. `.spherier wipeall` resets every character and account (also clears the
   prisms).

---

## 6. Customisation

* **Spherite sources**: table `papota_sphere_point_source` (type + key + amount).
  Raid bosses by map × 10 + difficulty rank, dungeon bosses and completions by
  expansion tier, Mythic+ by key tier. `.spherier reload` after editing.
* **Node prices**: `papota_sphere_cost` (254 tiers, 100 → 5 000). Regenerate
  with `tools/dev/gen_bareme_couts.py`.
* **Stones**: `papota_sphere_stone` (+1/+2/+3/+5/+7 for node stones, +5 to +30
  for item stones), `papota_sphere_rune`, `papota_sphere_stat_rune`.
* **Prism bonus**: `$s1` of spell 8500006 (25 %) in `spell_dbc` and the client
  patch.
* **The grid itself**: open the editor, edit, "Vérifier", "Enregistrer"
  (writes `layouts/<name>.xml`), then import into the tables with
  `tools/dev/importe_layout.lua` (see `tools/dev/exporte_grilles.bat` for the
  invocation) and `.spherier reload`. The per-class spells of spell nodes are
  set in the editor ("Par classe…") and stored in `papota_sphere_node_spell`; a
  class with no spell on a node does not see the node.
* **Texts**: `module_string` / `module_string_locale` rows of
  `mod-papota-spherier` (console and chat), `item_template_locale`,
  `creature_template_locale`; client texts through the generators in
  `tools/dev` (`sorts_classes.py` holds the 96 class spells).
* **Class spells**: `tools/dev/sorts_classes.py` is the single source of truth;
  `gen_sorts_classes.py --deploy` regenerates `spell_dbc`, the client
  `Spell.dbc` and the spellbook tabs. The generators write into the author's
  client (`patch-z.MPQ`) and are kept as documentation of how everything was
  made rather than as a turnkey pipeline.

---

## 7. Troubleshooting

* **Unknown spell / question-mark icons in game**: the client patch is not
  loaded (wrong folder, a later letter overriding it, game not restarted).
* **Spells are cast but do nothing / "spell not found" on the server**: the
  `2026_09_06_90` file did not apply; check `updates` in the world database.
* **A summoned creature has no model** or a class spell's buff has no duration:
  step 3.4 (server DBC) was skipped.
* **Missing visuals but correct names**: `tools/files` did not go into the
  archive; re-run the builder and read its report.
* **`Playerbots.h` not found at build time**: you have an old copy of
  `SpherierPlayerMgr.cpp`; the published one guards the include with
  `MOD_PLAYERBOTS`.
* **Interfaces never open**: AIO is not loaded (`lua_scripts/AIO_Server` missing
  or errors in the ALE log), or the Lua folder was not copied.
* **"record size" error in the client builder**: the client is not build 12340.

---

## 8. Technical notes

* The C++ module owns all state: points and prisms per account, node
  activations per character, node content per account. Writes are immediate.
  The Lua side only presents and calls console commands (`.spherier activate`,
  `socket`, `unsocket`, `fusion`, `relance`, `refonte`, opened to `SEC_PLAYER`
  with the same rules as the interface).
* Spherite gains go through one function (`Gagner`), so the prism bonus
  applies to every source; GM `points add/set` stay raw.
* The grid definition is cached by fingerprint and sent once per session in a
  compact wire format (139 KB); the player interface virtualises its drawing
  (button and texture pools by 256-px cells), which keeps a 4 683-node grid
  fluid at any zoom.
* Spell nodes learn the spell for free when the character already owns the node
  and has not "forgotten" it with the pin (`character_sphere_node.oublie`).
* Gauge auras of the druid are non-cancellable, non-stealable and not saved
  across logouts (`spell_custom_attr` 0x01000000 + login cleanup).
* The 26 textures of two backported models (`cfx_azerite_crucibleofflame…`,
  `cfx_paladin_lightofdawn…`) are shipped from the author's art sources.
* `tools/export_report.txt` lists exactly what was exported and why, and the
  69 files that come from the Papota client's earlier custom patches (older
  warlock effects and sounds reused by the new class spells).

## Credits

Design and validation: the Papota server. Implementation: written with
Claude (Anthropic). Interfaces built on [AIO](https://github.com/Rochet2/AIO)
by Rochet2. Backported models and textures are Blizzard Entertainment's
assets from later expansions, redistributed for private-server use only.
