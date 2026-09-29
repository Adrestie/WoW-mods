# mod-item-upgrade

An AzerothCore module (WotLK 3.3.5a) that lets players raise the stats on their
gear, rank by rank, in exchange for gold and tokens. At the top rank a stat is
worth twice its original value. Weapons have their own two tracks, damage and
swing speed, and looted items can arrive already upgraded.

This is an extended fork of
**[silviu20092/mod-item-upgrade](https://github.com/silviu20092/mod-item-upgrade)**.
The whole upgrade engine is that author's work; see [Credits](#12-credits) and
[section 11](#11-differences-from-the-original-module) for what we changed.

Players upgrade through **a window** opened from a minimap button, a slash
command or a right click on a token. It shows every stat of an item and the
weapon's damage and speed at once, prices the whole selection, and buys several
ranks in one click. All the rules stay in the C++ module: the window only shows
what the module tells it and sends back what the player picked. There is no NPC.
When the client runs the ForeverUI interface (mod-forever-ui), the window and
the minimap button give way to an "Item Upgrades" tab of a Progression window in
the Camelot style, which Attriboost shares when it is installed too. The module
draws that window itself, with the textures ForeverUI installs, and only asks
ForeverUI to add its button to the micro menu. Without ForeverUI nothing
changes.

Every text the module shows, in the chat or in the window, is in English and in
French, and follows the language of each player's client. Adding a language
takes a few SQL rows, no rebuild (section 6.13).

The guide below is written for someone who has never installed this module. It
gives complete commands and states what you should see after each step.
Following it without changing anything reproduces the configuration of the
Papota server: 41 stats, 20 ranks, +5 % per rank, 350 gold per rank.

---

## 1. What the package contains

```
mod-item-upgrade/
├── README.md                     this guide
├── LICENSE                       MIT
├── include.sh
├── conf/
│   └── mod_item_upgrade.conf.dist    weapons, random upgrades, allowed stats
├── src/                              the C++ module (10 files)
├── data/
│   ├── sql/                          applied by the server on its own
│   │   ├── db-world/base/
│   │   │   ├── 01_item_upgrade_world.sql     tokens and their item_dbc rows
│   │   │   ├── 02_item_upgrade_strings.sql   every text, English and French
│   │   │   └── 03_item_upgrade_commands.sql  help of the chat commands
│   │   └── db-characters/
│   │       ├── base/b_*.sql                  the module's own tables
│   │       ├── base/c_item_upgrade_scale.sql ranks, gains and prices
│   │       └── updates/                      upstream update files
│   ├── lua/
│   │   ├── ItemUpgrade_Client.lua           the window, pushed by AIO
│   │   └── ItemUpgrade_Serveur.lua          sends the window its texts
│   └── art/Interface/ItemUpgrade/           the portrait of the Progression window,
│                                            written into the game by the installer
├── installer.json                    what the WoW-mods installer puts in place and
│                                     removes: the tokens' rows in Item.dbc, the files,
│                                     the database tables and rows
├── optional/
│   └── mythic_plus_token_loot.sql    token drops for a Mythic+ system
└── docs/
    └── changes_vs_upstream.diff      our changes against the original
```

Everything under `data/sql` is applied by the server itself at startup, so there
are no SQL commands to type. `optional/` sits outside on purpose: the server
never touches it.

### Identifiers used

| What | Id |
|---|---|
| Power tokens (`item_template`, `item_dbc`) | 83050 to 83054 |
| Texts (`module_string`, `module_string_locale`) | module `mod-item-upgrade` |
| Chat commands (`command`) | `item_upgrade` and its subcommands |

If the tokens clash with your own content, section 6.14 explains how to move
them.

---

## 2. Requirements

**A working AzerothCore 3.3.5 server that you know how to rebuild.** Installing
adds a module to the source tree, so `worldserver` must be recompiled. If you
have never compiled your server, do that once without this module first.

**ALE and AIO on the server, the AIO addon on every client.** The window is the
only way to upgrade, and it needs them.

| Dependency | What it is | Where to get it |
|---|---|---|
| ALE, or Eluna | engine that runs Lua on the server side | `github.com/azerothcore/mod-ale` |
| AIO, server part | pushes the window's code to players | `github.com/Rochet2/AIO`, version 1.75 or later, `AIO_Server` |
| AIO, client part | receives that code in the game | same repository, the `AIO_Client` addon |

If your server already runs a Lua-based system, all three are probably present:
look for a `lua_scripts` folder next to `worldserver` with `AIO_Server` inside,
and for `Interface\AddOns\AIO_Client` in the clients.

**Command-line access to MySQL**, for the installer, for the checks and for
applying changes without a restart; MySQL must be running when the installer
runs. On Windows the program is `mysql.exe`, usually in
`C:\Program Files\MySQL\MySQL Server 8.4\bin`; it is not in the default path, so
call it with its full path, quotes included. On Linux, `mysql` is enough.

This guide calls the databases `acore_world`, `acore_characters` and
`acore_auth`, which are the default names. If yours differ, replace them
throughout.

**The WoW-mods installer**, `installer.exe`, from the `installer/` folder of
this repository. It carries what it needs; nothing else to install.

**A 3.3.5a client**, closed while the installer runs: it writes the tokens into
the game's archives.

---

## 3. Server installation

### 3.1 Run the installer

Stop the world server and close the game, then run `installer.exe`, the
WoW-mods installer (`installer/` folder of this repository), and give it this package's
folder, or drop the folder on `installer.exe`. Keep the package where you
downloaded it: the installer refuses to run from your server's `modules`
folder.

Its window asks for two folders the first time, then remembers them:

- the world server folder, the one holding `worldserver.exe`;
- the game folder, the one holding `Wow.exe` and `Data`.

It finds the rest from there: the configuration folder, the `Data\dbc` folder
and the databases in `worldserver.conf`, the Lua script folder in
`mod_ale.conf` (`lua_scripts` by default), your AzerothCore sources in the
build folder's `CMakeCache.txt`, and `mysql.exe`. It shows whatever it found
of the module before changing anything.

Finding nothing of the module, it offers **Install**, which puts in place:

- the module is copied to `modules/mod-item-upgrade` in your sources;
- `mod_item_upgrade.conf` and `mod_item_upgrade.conf.dist` are written to the
  module configuration folder;
- both Lua files go to `lua_scripts/ItemUpgrade/`, which sorts after
  `AIO_Server` as it must;
- the five tokens are added to the server's `Item.dbc` and to the game's,
  directly inside the archive it comes from, and the module's image
  (`data/art`) is written under `Interface\ItemUpgrade` (section 4).

It reads everything back from the disk and ends with `Installation complete.`,
followed by the build commands.

### 3.2 Build

Stop the server, then, from your build folder:

```
cmake .
cmake --build . --config RelWithDebInfo --target worldserver
```

On Linux, `cmake .` then `make -j$(nproc)`.

Stopping the server is mandatory: while `worldserver` runs, its file is locked
and linking fails. The `cmake .` step is what makes the build system notice the
module's files; skipping it is the usual reason a module seems to do nothing.

> **Check.** The build ends without errors and the `worldserver` file is dated
> today. Proof that the module really made it into the binary comes at startup,
> in 3.4.

### 3.3 Configure

The installer has written `mod_item_upgrade.conf`, a copy of the shipped
`.dist`, which is the file the server reads. Without it the module would run on
the defaults written in its code, which differ from the shipped values (9 stats
instead of 41, free weapon upgrades).

> **Check.** At startup, `Server.log` lists `mod_item_upgrade.conf` under "Using
> modules configuration", and holds no line `Missing property ItemUpgrade.`.

The shipped values are the Papota ones. Section 6 explains each of them.

### 3.4 Start the server

Start the server normally and let it finish loading. On this first start the
updater applies every SQL file in `data/sql`: the module's tables, the tokens,
the texts, the command help and the upgrade scale.

> **Check.** In `Server.log`, three things:
> - a line `Loading item upgrade mod custom tables...`, which proves the module
>   is compiled in;
> - lines mentioning the applied SQL files, among them
>   `01_item_upgrade_world.sql`, `02_item_upgrade_strings.sql` and
>   `c_item_upgrade_scale.sql`;
> - no error line containing `mod_item_upgrade` or `mod-item-upgrade`.
>
> Then the scale and the texts are in place:
> ```
> "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p acore_characters -e "SELECT COUNT(DISTINCT stat_type) AS stats, MAX(stat_rank) AS max_rank, COUNT(*) AS rows_total FROM mod_item_upgrade_stats;"
> "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p acore_world -e "SELECT (SELECT COUNT(*) FROM module_string WHERE module = 'mod-item-upgrade') AS english, (SELECT COUNT(*) FROM module_string_locale WHERE module = 'mod-item-upgrade' AND locale = 'frFR') AS french;"
> ```
> Expected: 41 stats, maximum rank 20, 820 rows; then 113 English texts and
> 113 French ones. If you get 8 stats over 2 ranks, only the module's own files
> were applied and `c_item_upgrade_scale.sql` was not; see section 8.

### 3.5 Give the tokens a source

Without tokens, players stop at rank 3. It is up to you to decide where they
come from. Three ways, from the simplest to the most integrated.

**A vendor.** Add the tokens to the shop of an existing NPC whose entry you
know. The price comes from `BuyPrice` in `item_template`; here, 5 000 gold.

```sql
UPDATE item_template SET BuyPrice = 50000000 WHERE entry BETWEEN 83050 AND 83054;
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost)
VALUES (YOUR_VENDOR_ENTRY, 0, 83050, 0, 0, 0);
```

**A boss drop.** The token drops with the given chance, here 25 %, from the
creature whose entry you give.

```sql
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount)
VALUES (YOUR_CREATURE_ENTRY, 83050, 0, 25, 0, 1, 0, 1, 1);
```

**A Mythic+ system.** If your server runs the Papota Mythic+ scripts,
`optional/mythic_plus_token_loot.sql` reproduces our distribution: on each
completed run, a number of tokens that depends on the keystone tier. Apply it by
hand:

```
"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p acore_world < "optional\mythic_plus_token_loot.sql"
```

Without that system the file does nothing useful. Skip it.

---

## 4. Client side

Two things on each client: the AIO addon, and the tokens in `Item.dbc`.

**The AIO addon.** Copy the `AIO_Client` folder of the AIO repository into the
client's `Interface\AddOns` folder, then tick it in the AddOns list of the
character screen. Without it the window never appears.

**The tokens.** An item only truly exists if it appears in `Item.dbc`: the
server ignores, at load time, any item missing from its copy, and the client
shows a red question mark for any item missing from its own. The installer has
already added the five tokens to both. In the game, it writes into the archive
that provides `Item.dbc` when that archive is one of yours, `patch-Z.MPQ` for
instance; when it comes from an official archive, into your last custom
archive, or into a new `Data\patch-Z.MPQ` if you have none. The module's image
goes into your last custom archive, under `Interface\ItemUpgrade`. Official
archives are never modified, and only the five rows are added: everything else
stays as it was.

Other players' clients need the same rows: give them the archive the installer
wrote to, whose path its output shows.

---

## 5. Full check

**Test 1, tokens display properly.** On a game master account:
`.additem 83050 1`

> Expected: an item named "Shard of Power" on an English client, "Éclat de
> Puissance" on a French one, appears in your bag with a normal icon. Its
> tooltip reads "Used to upgrade statistics." A red question
> mark means the tokens are missing from the archive the client loads
> (section 4).

**Test 2, the window opens.** Click the anvil button on the minimap rim, or type
`/iu`. The commands `/amelioration` and `/ameliorer` do the same thing, in every
client language. A right click on a token opens it too.

> Expected: an "Item Upgrades" window fades in. With no item selected it reads
> "Drop an item here". A strip shows your equipped pieces. (With ForeverUI: the
> Progression window opens on the "Item Upgrades" tab, items listed on the left.)

**Test 3, the window reads an item.** Click an equipped piece in the strip, or
drag an item from a bag onto the window.

> Expected: the item name in its quality colour, then one line per upgradeable
> stat. Each line shows the current value, an arrow, the value at the next rank,
> the gain, and a bar of the rank reached out of 20. Hovering a line details the
> price of the next rank.

**Test 4, buying a rank.** Equip a piece carrying stats and note one of them,
say 60 stamina. Select it in the window, tick stamina, check the price at the
bottom, click "Upgrade".

> Expected: rank 1 costs 350 gold and no token. "+1 rank(s)" floats up in the
> middle of the window, the bar advances, and your character sheet shows
> 63 stamina instead of 60. You are 350 gold poorer.

**Test 5, the weapon lines.** Select the weapon in your main hand.

> Expected: below its stats, two more lines, "Weapon damage" with the damage
> range before and after the next step, and "Weapon speed" with the swing time
> before and after. They are ticked and bought like the stats; the price of a
> step is set in the configuration (section 6.9). A weapon in a bag shows the
> damage line only: speed applies to a weapon in hand.

**Test 6, the resource check.** Pick an item whose stat sits at rank 3 and tick
it, while owning no Shard of Power.

> Expected: the token appears in red in the price area, with the missing amount
> in its tooltip, and the "Upgrade" button stays greyed out.

**Test 7, the language.** Repeat test 3 on a client of the other language.

> Expected: every text of the window, the stat names included, is in that
> client's language.

**Test 8, the commands of the window.** Type `.item_upgrade state 0 1` in the
chat.

> Expected: "This command belongs to the item upgrade window: open it with
> /iu." Nothing else happens: those commands only answer the window.

If a result differs, see section 8.

---

## 6. Customisation

### 6.1 Where each thing is set

| What you want to change | Where | Applied |
|---|---|---|
| Gain per rank, number of ranks, gold price, tokens, stats covered | `data/sql/db-characters/base/c_item_upgrade_scale.sql` | on restart, or see 6.12 |
| Price specific to one item | `mod_item_upgrade_stats_req_override` table | see 6.12 |
| Weapons, random upgrades on loot, allowed stats | `mod_item_upgrade.conf` | on restart |
| Which items can be upgraded | `..._allowed_items`, `..._blacklisted_items` tables | see 6.12 |
| Texts, languages | `data/sql/db-world/base/02_item_upgrade_strings.sql` | on restart, see 6.13 |

Edit the SQL file and restart: the updater notices the change and applies it
again. Section 6.12 shows how to apply a change without a restart.

The scale lives in the **characters** database, not in world. That is unusual,
but that is how the module is built.

### 6.2 The rule of calculation, worth knowing first

A rank's gain is worked out from the item's **base** value, never from the
already upgraded one. Ranks do not stack, they replace one another: moving to
rank 2 does not add 5 % on top of rank 1's 5 %, it applies 10 % to the starting
value.

One exception: the gain is never smaller than the rank number, in absolute
terms. At rank 20 a stat therefore gains at least 20 points. On a large value
that rule is invisible, 60 stamina becoming 120. On a small one it dominates:
12 spell penetration becomes 32, not 24. Small stats therefore grow
proportionally more than large ones.

Finally, ranks are bought in order. Nobody buys rank 5 without the four before
it, and each purchase costs the price of its own rank only. Several stats bought
together cost the sum of their prices, paid at once: either every ticked line
moves up a rank, or none does.

### 6.3 Changing the gain per rank

Open `data/sql/db-characters/base/c_item_upgrade_scale.sql`. Near the top,
change one line:

```sql
SET @PCT_PER_RANK := 5;
```

This is the percentage gained at each rank. Rank 1 gives that value, rank 2
twice as much, and so on.

| Value | Rank 1 | Rank 20 | Item at maximum |
|---|---|---|---|
| 2 | +2 % | +40 % | 1.4 times its value |
| 5 | +5 % | +100 % | twice its value |
| 10 | +10 % | +200 % | three times its value |

### 6.4 Changing the number of ranks

In the same place:

```sql
SET @MAX_RANK := 20;
```

Mind the two settings together: the maximum bonus is
`@MAX_RANK × @PCT_PER_RANK` percent. Doubling the ranks without touching the
percentage doubles the final power.

If you **lower** the number of ranks while players have bought beyond it, their
upgrades are brought down to the new maximum automatically. Those players lose
the difference with no refund, so warn them. If you **raise** it, existing
purchases are untouched and the new ranks open up.

Remember to cover the new ranks in the token table, in 6.6.

### 6.5 Changing the gold price

```sql
SET @GOLD_PER_RANK := 350;
```

The price is in gold and applies to every rank. Taking one stat all the way
therefore costs `@GOLD_PER_RANK × @MAX_RANK`, and a whole item multiplies that
by its number of stats. With the shipped values: 350 gold per rank, 7 000 for a
full stat, 35 000 for an item with five stats.

For a price that rises with the rank, replace this line in section 5 of the
file:

```sql
SELECT id, 1, @GOLD_PER_RANK * 10000, NULL
```

with:

```sql
SELECT id, 1, @GOLD_PER_RANK * 10000 * stat_rank, NULL
```

Rank 1 then costs 350 gold, rank 20 costs 7 000, and the full stat comes to
73 500. The 10 000 factor converts gold to copper, the module's unit; keep it.

### 6.6 Changing the tokens required

In section 3 of the same file, this table says which token is required over
which range of ranks:

```sql
INSERT INTO tmp_tokens (rank_min, rank_max, item) VALUES
  ( 4,  7, 83050),   -- Shard of Power    : 1, 2, 3 then 4
  ( 8, 11, 83051),   -- Fragment of Power : 1, 2, 3 then 4
  (12, 15, 83052),   -- Core of Power     : 1, 2, 3 then 4
  (16, 19, 83053),   -- Gem of Power      : 1, 2, 3 then 4
  (20, 20, 83054);   -- Crown of Power    : 1
```

The quantity starts at 1 on the range's first rank and rises by one at each
following rank. Ranks 1 to 3 appear nowhere: they only cost gold.

**Remove tokens altogether**: replace the whole `INSERT` statement with nothing.
Upgrades then cost gold only.

**Require a token from rank 1**: replace `( 4, 7, 83050)` with
`( 1, 4, 83050)` and shift the others.

**Use your own items**: replace 83050 to 83054 with your own entries. Any
existing item works, an Emblem of Frost or a custom currency included.

**A fixed rather than rising quantity**: in section 5 of the file, replace

```sql
SELECT s.id, 4, t.item, s.stat_rank - t.rank_min + 1
```

with the quantity you want, here 3 per rank:

```sql
SELECT s.id, 4, t.item, 3
```

The module also takes honor and arena points, with `2` and `3` in place of the
`4`. The amount then goes in the fourth column and the fifth is `NULL`.

### 6.7 Choosing which stats can be upgraded

The list is in section 1 of the same file. Delete a row to drop that stat, or
keep only the rows you want.

One rule: never renumber the `pos` column on a live server. It determines the
scale's identifiers, which purchased upgrades point at. Deleting a row in the
middle is safe; renumbering the others is not.

The configuration file holds a second list, `ItemUpgrade.AllowedStats`, and a
stat must appear in both to work. The simplest course is to leave the
configuration alone and work only in the SQL file. A value of that list which is
not a stat code is reported in `Server.log` and skipped.

Careful when dropping a stat: upgrades players bought on it stop applying, with
no refund. They come back if you restore it.

### 6.8 A different price for one specific item

`mod_item_upgrade_stats_req_override` sets a price for one item without touching
the general scale. It is empty by default.

Below, rank 1 of stamina costs ten times more on item 40395. The `1` means gold,
and the amount is in copper.

```sql
INSERT INTO mod_item_upgrade_stats_req_override (stat_id, item_entry, req_type, req_val1, req_val2)
SELECT id, 40395, 1, 35000000, NULL
FROM mod_item_upgrade_stats WHERE stat_type = 7 AND stat_rank = 1;
```

A price set this way replaces the scale's price entirely for that rank on that
item: to keep the token requirement as well, add it on a second row.

### 6.9 Tuning weapons

In `mod_item_upgrade.conf`, no SQL. Needs a restart.

```
ItemUpgrade.UpgradeWeaponDamagePercents = 5,10,15,20,25
ItemUpgrade.UpgradeWeaponDamageToken = 49426
ItemUpgrade.UpgradeWeaponDamageTokenCount = 750
ItemUpgrade.UpgradeWeaponDamageMoney = 30000000
```

The first line lists the steps, as added damage percentages, bought in order.
The next three price one step: an item, a quantity, and an amount in copper.
Here, 750 Emblems of Frost and 3 000 gold per step.

Four matching lines exist for speed, under `UpgradeWeaponSpeedPercents` and
those after it, where the percentage **reduces** the delay between swings.
A step that is not a percentage above 0, and below 100 for speed, is reported
in `Server.log` and skipped.

To switch either off, set `ItemUpgrade.UpgradeWeaponDamage` or
`ItemUpgrade.UpgradeWeaponSpeed` to `0`: its line then leaves the window.

### 6.10 Tuning random upgrades on loot

```
ItemUpgrade.RandomUpgradesOnLoot = 1
ItemUpgrade.RandomUpgradeChance = 10
ItemUpgrade.RandomUpgradeMaxStatCount = 3
ItemUpgrade.RandomUpgradeMaxRank = 3
```

In order: the feature is on, one item in ten arrives upgraded, on one to three
randomly chosen stats, each at a rank drawn between 1 and 3. Set the first line
to `0` to switch it all off. Five further settings say on which occasions it
applies: looted, won on a roll, quest reward, crafted, bought. Only buying is
off by default.

`ItemUpgrade.RandomUpgradesLoginMessage = 1` tells players at login that the
feature is on; `0` keeps quiet. The message itself is text 11 (section 6.13).

### 6.11 Restricting which items can be upgraded

By default any item carrying at least one stat qualifies, heirlooms excepted.

To allow only certain items, list them in `mod_item_upgrade_allowed_items`; as
soon as it holds one row, everything else is refused.

```sql
INSERT INTO mod_item_upgrade_allowed_items (entry) VALUES (40395), (40628);
```

To forbid a few items only, list them in `mod_item_upgrade_blacklisted_items`
and leave the first table empty.

### 6.12 Applying a change without restarting

1. In game, as a game master: `.item_upgrade lock`. The window refuses every
   upgrade until the lock is released, so nobody buys mid-change.
2. Run your edited file by hand:
   ```
   "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p acore_characters < "data\sql\db-characters\base\c_item_upgrade_scale.sql"
   ```
   Run the whole file in one go: it uses temporary tables that vanish when the
   connection closes.
3. In game: `.item_upgrade reload`. The message "Item Upgrade module data
   successfully reloaded." confirms it and releases the lock.

The window reads everything from the module as it opens an item: nothing to
reload on its side. Anything living in the configuration file needs a full
restart instead.

### 6.13 Texts and languages

Every text lives in `data/sql/db-world/base/02_item_upgrade_strings.sql`: in
English in the core's `module_string` table, in every other language in
`module_string_locale`. Each player gets the row of their client's language,
English when there is none. The C++ module reads its messages there and the
window receives its own from there, through the server-side Lua script. The
numbers: 1 to 99 the module's messages, 101 to 199 the window, 1000 plus a stat
code the name of that stat, 1100 plus a slot number the name of that equipment
slot.

**Adding a language** takes one row per number in `module_string_locale`, with
that client's locale code: `deDE`, `esES`, `esMX`, `ruRU`, `koKR`, `zhCN` or
`zhTW`. Copy the French block, change the code and translate. Keep every `{}`,
as many times as in English: each stands for a value. Add the rows to the file
so a reinstall keeps them, then restart. Without a restart:
`.reload module_string` for the chat messages, then `.reload ale` for the
window.

**The token names** are in `01_item_upgrade_world.sql`: English in
`item_template`, French in `item_template_locale`. A new language takes one row
per token in the latter. The client caches item names, so players may need to
clear their `Cache` folder to see a change.

**The command help** (`.help item_upgrade`) is in English only: the core's
`command` table has no translation column.

### 6.14 Moving the identifiers

If 83050 to 83054 clash with your own content, edit
`data/sql/db-world/base/01_item_upgrade_world.sql` and replace them there. Three
other places refer to the same numbers and must follow: the token list in
section 3 of `c_item_upgrade_scale.sql`, the `rows` of the
`Item.dbc` entry in `installer.json`, and `RC.JETONS` near the top of
`data/lua/ItemUpgrade_Client.lua`, which opens the window on a right click.
Those files are commented in French, like the rest of the tooling in this
repository.

Do this before players start upgrading. Afterwards, purchased upgrades would
point at identifiers that no longer exist.

---

## 7. Understanding the tables and commands

All in the characters database unless stated otherwise.

**`mod_item_upgrade_stats`** is the scale. One row per stat and per rank.
`stat_type` is the stat code, `stat_rank` the rank number, `stat_mod_pct` the
percentage gained. `id` follows the rule
`id = position of the stat + number of stats × (rank − 1)`.

**`mod_item_upgrade_stats_req`** holds the prices. One row per requirement,
several possible for one rank. `req_type` is 1 for gold, 2 for honor, 3 for
arena, 4 for an item. For gold, honor and arena the amount is in `req_val1`.
For an item, `req_val1` is its entry and `req_val2` the quantity.

**`mod_item_upgrade_stats_req_override`** holds prices specific to one item.

**`character_item_upgrade`** records what players bought: who, on which specific
copy of an item, and which rank. Two sister tables do the same for weapons.

**`item_template`, `item_template_locale` and `item_dbc`**, in the world
database, describe the tokens; **`module_string`** and
**`module_string_locale`** hold the texts.

The commands:

| Command | Who | What it does |
|---|---|---|
| `.item_upgrade list [name]` | anyone | lists the upgrades on the equipped items of a player, your target or yourself |
| `.item_upgrade lock` | administrator | locks upgrades while tables are edited |
| `.item_upgrade reload` | administrator | reloads the scale and releases the lock |
| `.item_upgrade state` | the window | describes an item, line by line |
| `.item_upgrade upgrade` | the window | buys the ticked ranks |

The last two travel through the core's addon command channel: the window sends
them as addon messages and the module answers it line by line. Typed in the
chat, they only say what they are for. A player can send them without the
window all the same, and gains nothing by it: the module takes from them only
the item's place, its guid and the targets, then works out the next ranks and
their prices itself, checks them and takes them.

---

## 8. Troubleshooting

**The scale shows 8 stats over 2 ranks instead of 41 over 20.** Only the
module's own SQL was applied, not `c_item_upgrade_scale.sql`. Check that the
file is in `data/sql/db-characters/base/`, that `Updates.EnableDatabases` in
`worldserver.conf` covers the characters database, and look in `Server.log` for
an error on that file. You can always apply it by hand, as in 6.12.

**Tokens show as a red question mark.** Section 4 was skipped on the client
side, or the archive you edited is not the one the client loads. Check that it
sits in the client's `Data` folder and that its name sorts after the official
archives.

**The window does not open in game.** Check that the client has the
`AIO_Client` addon ticked, that ALE and AIO run on the server, that the
`ItemUpgrade` folder really is in `lua_scripts`, and look for a Lua error in
`Server.log` at startup.

**The window shows "There is no such command." under the item.** The server
does not know the module's commands: the module is not compiled in. Go back to
3.2, `cmake .` included.

**The window shows raw numbers or text keys, such as `titre`.** Its texts did
not arrive: `02_item_upgrade_strings.sql` was not applied, or the server was
not restarted since. Check with the query of 3.4.

**A chat message reads `[mod-item-upgrade] missing text` followed by a
number.** That row is missing from `module_string`. Apply
`02_item_upgrade_strings.sql` again, then `.reload module_string`.

**"Item upgrades are locked" stays on.** A game master used `.item_upgrade lock`
without releasing it. Run `.item_upgrade reload`.

**`Server.log` holds `sql.sql` errors mentioning `mod_item_upgrade`.** The scale
holds rows the module refuses, most often a `stat_mod_pct` of zero or less.
Restore the shipped file and apply it again.

**Purchased upgrades stopped applying.** A stat was probably removed from
`ItemUpgrade.AllowedStats`, or from the scale. Put it back and they work again.

**An item's tooltip does not show the upgraded stats although the character is
upgraded.** A 3.3.5 client limitation, not an installation fault: a tooltip
cannot show different stats per owner for an item with a random suffix. The
stats apply all the same.

---

## 9. Uninstalling

Stop the world server, close the game, and run the installer again on this
folder. Finding the module, even in part, it lists what it found and, once you
confirm **Remove**, removes all of it:

- in the characters database, the module's ten tables, purchased upgrades
  included, and the updater's record of its files in `updates`;
- in the world database, the tokens in `item_template`,
  `item_template_locale` and `item_dbc`, the texts in `module_string` and
  `module_string_locale`, the command help, the updater's record of the
  module's files, those of former versions included, and the token drops of
  `optional/mythic_plus_token_loot.sql` if that table exists;
- the five token rows in the server's `Item.dbc` and in every custom archive
  of the game, and every file under `Interface\ItemUpgrade` in those archives;
  everything else in those files is left as it is, and an archive
  that no longer changes anything, such as one the installation created, is
  deleted;
- the module folder in `modules/`, whatever its name,
  `mod_item_upgrade.conf` and `mod_item_upgrade.conf.dist`, both Lua files
  wherever they are in the script folder, the `ItemUpgrade` folder unless it
  holds files of your own, and the `.avant_item_upgrade` backups the former
  installation tool left next to `Item.dbc` and in the game's `Data` folder.

It then checks that nothing is left and prints the build commands: rebuild, and
the module is gone from the world server. If you had started removing the
module by hand, run the installer anyway: it removes whatever is left.

The installer only installs or removes: run on an installed module, it removes
it, purchased upgrades included. It has no upgrade mode.

Tokens players still hold vanish at their next login: the core removes items it
no longer knows from bags, banks and mail.

---

## 10. Upgrading from the version with the upgrade master

Earlier versions of this fork sold upgrades through an NPC, entry 200003. Moving
to this one:

1. Replace the `mod-item-upgrade` folder in your sources, run `cmake .` and
   rebuild: the NPC's source file is gone and the build must forget it.
2. In your `mod_item_upgrade.conf`, if you have one, delete
   `ItemUpgrade.AllowUpgradesPurge`, `ItemUpgrade.UpgradePurgeToken`,
   `ItemUpgrade.UpgradePurgeTokenCount`, `ItemUpgrade.RefundAllOnPurge` and
   `ItemUpgrade.RandomUpgradesBroadcastLoginMsg`, which no longer exist. The
   login message is now switched by `ItemUpgrade.RandomUpgradesLoginMessage`
   (section 6.10), on by default.
3. Replace the two files of `lua_scripts/ItemUpgrade` and ensure every client
   has `AIO_Client` (section 4).
4. Start the server. The updater applies the new world files on its own:
   `01_item_upgrade_world.sql` removes the NPC, its model and its spawns,
   recognised by their script name `npc_item_upgrade` only, and gives the tokens
   their English names with the French ones alongside.

Purchased upgrades are kept: the characters tables do not change. The four
world update files of the former versions are gone from the package; their rows
in the `updates` table stay behind, harmless, and the installer removes them when
it uninstalls the module (section 9). Players may need to clear their `Cache` folder to see the tokens'
new names.

---

## 11. Differences from the original module

`docs/changes_vs_upstream.diff` holds the full detail for `src/`, `conf/` and
`data/sql/`, against the original's commit 4ffef2e. In short:

- **No NPC.** The gossip menus, their pages and the upgrade purge they offered
  are removed; upgrades go through the window.
- **Two commands for the window**, `state` and `upgrade`, reached through the
  core's addon command channel. `upgrade` buys the next rank of several stats
  and of the weapon's damage and speed at once, for the sum of their prices,
  all or nothing, with the same checks as the NPC had.
- **Every text in `module_string`**, English and French, following each client's
  language; the stat and slot names included.
- **A far wider default scale**, laid down by `c_item_upgrade_scale.sql`:
  41 stats over 20 ranks, where the original ships 8 stats over 2 ranks.
- **Five tokens** in `01_item_upgrade_world.sql`.
- **An AIO window**, which the original does not have.
- **Fixes**: `.item_upgrade list` on an offline player no longer crashes the
  server; a speed check no longer reads outside the weapon damage table for an
  item that is not in a weapon slot; a mistyped value in `ItemUpgrade.AllowedStats`
  or in the weapon percentages is reported and skipped instead of being read as
  a value it does not hold; upgrades bought together cost their exact sum, and a
  sum above what a player can hold is refused, where the original's bulk
  purchase lowered it to that ceiling. The original's later fix b367cd2 (weapon
  speed lost under Stealth) is included.

Everything else, and in particular the whole upgrade engine, is the original
author's work.

---

## 12. Credits

**[mod-item-upgrade](https://github.com/silviu20092/mod-item-upgrade)** by
**[silviu20092](https://github.com/silviu20092)** is the original module, and the
entire upgrade system comes from it. This is a fork with additions; all credit
for the underlying work goes to its author.

**[AzerothCore](https://github.com/azerothcore/azerothcore-wotlk)** is the server
this module builds on, and the copyright holder named in the MIT licence.

**[AIO](https://github.com/Rochet2/AIO)** by **Rochet2**, GPL v2, pushes the
window to players. Named as a dependency, not included here.

---

## 13. Licence

MIT, as the original module. The text is in `LICENSE`. The SQL, Lua and Python
scripts here follow the same licence.
