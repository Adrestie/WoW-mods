# mod-item-upgrade

An AzerothCore module (WotLK 3.3.5a) that lets players raise the stats on their
gear, rank by rank, in exchange for gold and tokens. At the top rank a stat is
worth twice its original value.

This is an extended fork of
**[silviu20092/mod-item-upgrade](https://github.com/silviu20092/mod-item-upgrade)**.
The whole upgrade engine is that author's work; see [Credits](#11-credits) and
[section 10](#10-differences-from-the-original-module) for what we added.

Two ways to upgrade, either or both:

* **the upgrade master**, an NPC with a gossip menu, which needs nothing beyond
  the module itself;
* **a user interface** opened from a minimap button or a slash command, which
  shows every stat at once, prices the whole selection, and buys several ranks
  in one click. It needs ALE or Eluna, and AIO (see requirements).

Weapons have their own two tracks, damage and swing speed, and looted items can
arrive already upgraded.

> **One thing to know before you start.** This fork's in-game text is in French:
> the upgrade master's menus, the module's messages and the token names. The
> graphical interface is bilingual and follows each client's language, but the
> rest is not. Section 6.13 shows where to change it.

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
│   │   │   └── 01_item_upgrade_world.sql    tokens, item_dbc rows, the NPC
│   │   ├── db-characters/base/
│   │   │   ├── b_*.sql                      the module's own tables
│   │   │   └── c_item_upgrade_scale.sql     ranks, gains and prices
│   │   └── */updates/                       upstream update files
│   └── lua/
│       ├── ItemUpgrade_Client.lua           the window, pushed by AIO
│       └── ItemUpgrade_Serveur.lua          scale, prices, validation
├── tools/
│   ├── patch_item_dbc.py             declares the tokens to the client
│   ├── StormLib.dll                  library used by that script
│   └── StormLib_LICENSE.txt
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
| Upgrade master (NPC) | 200003 |
| Power tokens | 801050 to 801054 |
| Spawn guids | the three after the highest one already in your `creature` table |

If any of these clash with your own content, section 6.14 explains how to move
them.

---

## 2. Requirements

**A working AzerothCore 3.3.5 server that you know how to rebuild.** Installing
adds a module to the source tree, so `worldserver` must be recompiled. If you
have never compiled your server, do that once without this module first.

**Command-line access to MySQL**, only for the checks and for applying changes
without a restart. On Windows the program is `mysql.exe`, usually in
`C:\Program Files\MySQL\MySQL Server 8.4\bin`; it is not in the default path, so
call it with its full path, quotes included. On Linux, `mysql` is enough.

This guide calls the databases `acore_world`, `acore_characters` and
`acore_auth`, which are the default names. If yours differ, replace them
throughout.

**Python 3**, for the tool that edits DBC files in step 4. Check with
`python --version`. The script targets Windows.

**Two dependencies, only for the graphical interface.** The module and its
upgrade master work without them.

| Dependency | What it is | Where to get it |
|---|---|---|
| ALE, or Eluna | engine that runs Lua on the server side | `github.com/azerothcore/mod-ale` |
| AIO | pushes interface code to players, nothing to install client side | `github.com/Rochet2/AIO`, version 1.75 or later |

If your server already runs a Lua-based system, both are probably present: look
for a `lua_scripts` folder next to `worldserver`, with `AIO_Server` inside it.

**A 3.3.5a client whose archives you can edit.** Step 4 adds items to the
client. Skip it and the tokens show up as a red question mark.

---

## 3. Server installation

### 3.1 Drop the module in

Copy the `mod-item-upgrade` folder into the `modules` folder of your AzerothCore
sources. You should end up with a path like
`…/azerothcore-wotlk/modules/mod-item-upgrade/src/item_upgrade.cpp`.

### 3.2 Build

Stop the server, then, from your build folder:

```
cmake .
cmake --build . --config RelWithDebInfo --target worldserver
```

On Linux, `cmake .` then `make -j$(nproc)`.

Stopping the server is mandatory: while `worldserver` runs, its file is locked
and linking fails. The `cmake .` step is what makes the build system notice the
new module; skipping it is the usual reason a module seems to do nothing.

> **Check.** The build ends without errors and the `worldserver` file is dated
> today. Proof that the module really made it into the binary comes at startup,
> in 3.4.

### 3.3 Configure

The build copies `conf/mod_item_upgrade.conf.dist` next to your other module
configuration files, and the server reads it as it is. You only need to act if
you want to change a setting: copy it in the same folder under the name
`mod_item_upgrade.conf` and edit that copy, which takes precedence and survives
updates.

The shipped values are the Papota ones. Section 6 explains each of them.

### 3.4 Start the server

Start the server normally and let it finish loading. On this first start the
updater applies every SQL file in `data/sql`: the module's tables, the tokens,
the NPC, and the upgrade scale.

> **Check.** In `Server.log`, three things:
> - a line `Loading item upgrade mod custom tables...`, which proves the module
>   is compiled in;
> - lines mentioning the applied SQL files, among them
>   `01_item_upgrade_world.sql` and `c_item_upgrade_scale.sql`;
> - no error line containing `mod_item_upgrade`.
>
> Then the scale is in place:
> ```
> "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p acore_characters -e "SELECT COUNT(DISTINCT stat_type) AS stats, MAX(stat_rank) AS max_rank, COUNT(*) AS rows_total FROM mod_item_upgrade_stats;"
> ```
> Expected: 41 stats, maximum rank 20, 820 rows. If you get 8 stats over
> 2 ranks, only the module's own files were applied and
> `c_item_upgrade_scale.sql` was not; see section 8.

### 3.5 Install the interface (optional)

Without it, players upgrade their gear by talking to the upgrade master.

Copy the two files from `data/lua` into a folder named `ItemUpgrade` inside your
server's `lua_scripts` folder, next to `AIO_Server`. You should end up with
`lua_scripts/ItemUpgrade/ItemUpgrade_Client.lua`.

Do not give the folder a name that sorts before `AIO_Server` alphabetically:
scripts load in that order and AIO must come first.

Players have nothing to install. Restart the server, or type `.reload ale` in
game.

### 3.6 Give the tokens a source

Without tokens, players stop at rank 3. It is up to you to decide where they
come from. Three ways, from the simplest to the most integrated.

**A vendor.** Add the tokens to the shop of an existing NPC whose entry you
know. The price comes from `BuyPrice` in `item_template`; here, 5 000 gold.

```sql
UPDATE item_template SET BuyPrice = 50000000 WHERE entry BETWEEN 801050 AND 801054;
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost)
VALUES (YOUR_VENDOR_ENTRY, 0, 801050, 0, 0, 0);
```

**A boss drop.** The token drops with the given chance, here 25 %, from the
creature whose entry you give.

```sql
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount)
VALUES (YOUR_CREATURE_ENTRY, 801050, 0, 25, 0, 1, 0, 1, 1);
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

## 4. Client installation

This is the step people forget, and nothing displays correctly without it.

An item only truly exists if it appears in `Item.dbc`. The server ignores, at
load time, any item missing from its copy, and the client shows a red question
mark for any item missing from its own. The SQL of step 3.4 has already filled
the server-side override table; two files remain, the server's `Item.dbc` and
the client's archive.

**Close the game and any MPQ editor.** An open archive is locked.

```
python tools\patch_item_dbc.py --serveur "C:\path\to\server\Data\dbc\Item.dbc" --client "C:\path\to\WoW\Data\patch-z.MPQ"
```

Two notes on those paths.

The server file lives in the `Data\dbc` subfolder next to `worldserver`. If you
cannot find it, look up `DataDir` in `worldserver.conf`.

The client archive is a `.MPQ` file in your client's `Data` folder. Use the one
where you already keep custom content. The client loads archives in alphabetical
order and the last one wins, so `patch-z.MPQ` comes after the official archives,
which is what we want. If you have no custom archive yet, the script creates
one, but it then needs a starting `Item.dbc` extracted from an official archive
with an MPQ editor:

```
python tools\patch_item_dbc.py --client "…\Data\patch-z.MPQ" --source "…\Item.dbc"
```

The script backs up every file it edits, under the same name followed by
`.avant_item_upgrade`, and can be replayed: it removes its own rows before
writing them again. An MPQ archive does not reclaim the space of a replaced
file, so it grows slightly on each run, with no consequence.

> **Check.** The script prints two lines, one for the server and one for the
> client, each ending in `5 ajoutés`, French for five added. The real check
> happens in game, at test 3 below.

---

## 5. Full check

**Test 1, the upgrade master exists.** In game, on a game master account, type
`.go creature id 200003`, then talk to the character.

> Expected: you are teleported next to a character named "Master", subtitled
> "Item Upgrades", who offers an upgrade menu in French.

**Test 2, tokens display properly.** Still as a game master:
`.additem 801050 1`

> Expected: an item named "Éclat de Puissance" appears in your bag, with a
> normal icon. A red question mark means section 4 was skipped, or that the
> archive you edited is not the one the client loads.

**Test 3, an upgrade can be bought.** Equip a piece carrying stats and note one
of them, say 60 stamina. Talk to the upgrade master, pick the item, then the
stat, then rank 1.

> Expected: rank 1 is offered at +5 % for 350 gold, no token. After the
> purchase your character sheet shows 63 stamina instead of 60, and you are
> 350 gold poorer.

The remaining tests only concern the graphical interface.

**Test 4, the window opens.** Click the anvil button on the minimap rim, or type
`/iu`. The commands `/amelioration` and `/ameliorer` do the same thing, in every
client language.

> Expected: an "Item Upgrades" window fades in. With no item selected it reads
> "Drop an item here". A strip shows your equipped pieces.

**Test 5, the window reads an item.** Click an equipped piece in the strip, or
drag an item from a bag onto the window.

> Expected: the item name in its quality colour, then one line per upgradeable
> stat. Each line shows the current value, an arrow, the value at the next rank,
> the gain, and a bar of the rank reached out of 20. Hovering a line details the
> price of the next rank.

**Test 6, buying from the window.** Tick a stat, check the price at the bottom,
click "Upgrade".

> Expected: "+1 rank(s)" floats up in the middle of the window, the bar
> advances, the value rises, your gold drops.

**Test 7, the resource check.** Pick an item whose stat sits at rank 3 and tick
it, while owning no Éclat de Puissance.

> Expected: the token appears in red in the price area, with the missing amount
> in its tooltip, and the "Upgrade" button stays greyed out.

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
it, and each purchase costs the price of its own rank only.

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
  ( 4,  7, 801050),   -- Shard of Power    : 1, 2, 3 then 4
  ( 8, 11, 801051),   -- Fragment of Power : 1, 2, 3 then 4
  (12, 15, 801052),   -- Core of Power     : 1, 2, 3 then 4
  (16, 19, 801053),   -- Gem of Power      : 1, 2, 3 then 4
  (20, 20, 801054);   -- Crown of Power    : 1
```

The quantity starts at 1 on the range's first rank and rises by one at each
following rank. Ranks 1 to 3 appear nowhere: they only cost gold.

**Remove tokens altogether**: replace the whole `INSERT` statement with nothing.
Upgrades then cost gold only.

**Require a token from rank 1**: replace `( 4, 7, 801050)` with
`( 1, 4, 801050)` and shift the others.

**Use your own items**: replace 801050 to 801054 with your own entries. Any
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
configuration alone and work only in the SQL file.

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

To switch either off, set `ItemUpgrade.UpgradeWeaponDamage` or
`ItemUpgrade.UpgradeWeaponSpeed` to `0`.

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

1. In game, as a game master: `.item_upgrade lock`. The upgrade master stops
   answering, so nobody buys mid-change.
2. Run your edited file by hand:
   ```
   "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p acore_characters < "data\sql\db-characters\base\c_item_upgrade_scale.sql"
   ```
   Run the whole file in one go: it uses temporary tables that vanish when the
   connection closes.
3. In game: `.item_upgrade reload`. The message "Item Upgrade module data
   successfully reloaded." confirms it and releases the lock.
4. With the graphical interface installed, add `.reload ale`: it keeps its own
   copy of the scale.

Anything living in the configuration file needs a full restart instead.

### 6.13 Translating the in-game text

Three separate places.

**The upgrade master's menus and the module's messages** are strings written
directly in the C++ sources, mostly `src/item_upgrade.cpp` and
`src/npc_item_upgrade.cpp`. About a hundred of them. Edit and rebuild.
`docs/changes_vs_upstream.diff` shows what we changed against the original,
whose text is in English: you can also start from the original module and
reapply only the changes you want.

**The token names**, in French in the database:

```sql
UPDATE item_template SET name = 'Shard of Power'    WHERE entry = 801050;
UPDATE item_template SET name = 'Fragment of Power' WHERE entry = 801051;
UPDATE item_template SET name = 'Core of Power'     WHERE entry = 801052;
UPDATE item_template SET name = 'Gem of Power'      WHERE entry = 801053;
UPDATE item_template SET name = 'Crown of Power'    WHERE entry = 801054;
```

Item templates are only read at startup, so restart the server. Players may also
need to clear their `Cache` folder, since the client caches item data it has
already seen. Editing the names directly in
`data/sql/db-world/base/01_item_upgrade_world.sql` keeps them across a
reinstall.

**The graphical interface** needs nothing: it carries both languages and picks
the one matching each client.

### 6.14 Moving the identifiers

If 200003 or 801050 to 801054 clash with your own content, edit
`data/sql/db-world/base/01_item_upgrade_world.sql` and replace them there. Three
other places refer to the same numbers and must follow: the token list in
section 3 of `c_item_upgrade_scale.sql`, the `ENTREES` list at the top of
`tools/patch_item_dbc.py`, and the `JETONS` list at the top of
`data/lua/ItemUpgrade_Serveur.lua`. Those two files are commented in French,
like the rest of the tooling in this repository.

Do this before players start upgrading. Afterwards, purchased upgrades would
point at identifiers that no longer exist.

---

## 7. Understanding the tables

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

**`item_template` and `item_dbc`**, in the world database, describe the tokens.

Two in-game commands for game masters: `.item_upgrade list` followed by a player
name lists their upgrades, and `.item_upgrade reload` reloads the scale.

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

**The upgrade master cannot be found with `.go creature id 200003`.** The world
SQL was not applied. Check with:
```
"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p acore_world -e "SELECT entry, name FROM creature_template WHERE entry = 200003;"
```

**The upgrade master's menu is empty.** The scale is not loaded in memory. Run
`.item_upgrade reload`.

**`Server.log` holds `sql.sql` errors mentioning `mod_item_upgrade`.** The scale
holds rows the module refuses, most often a `stat_mod_pct` of zero or less.
Restore the shipped file and apply it again.

**Purchased upgrades stopped applying.** A stat was probably removed from
`ItemUpgrade.AllowedStats`, or from the scale. Put it back and they work again.

**The window does not open in game.** Check that ALE and AIO are installed, that
the `ItemUpgrade` folder really is in `lua_scripts`, and look for a Lua error in
`Server.log` at startup.

**An item's tooltip does not show the upgraded stats although the character is
upgraded.** A 3.3.5 client limitation, not an installation fault: a tooltip
cannot show different stats per owner for an item with a random suffix. The
stats apply all the same.

---

## 9. Uninstalling

Remove the `mod-item-upgrade` folder from your sources and rebuild. Nothing
breaks: purchased upgrades simply stop applying.

To erase the data as well, on the characters database:

```sql
DROP TABLE IF EXISTS character_item_upgrade, character_weapon_upgrade,
  character_weapon_speed_upgrade, mod_item_upgrade_stats,
  mod_item_upgrade_stats_req, mod_item_upgrade_stats_req_override,
  mod_item_upgrade_allowed_items, mod_item_upgrade_blacklisted_items,
  mod_item_upgrade_allowed_stats_items, mod_item_upgrade_blacklisted_stats_items;
```

And on the world database:

```sql
DELETE FROM creature WHERE id = 200003;
DELETE FROM creature_template_model WHERE CreatureID = 200003;
DELETE FROM creature_template WHERE entry = 200003;
DELETE FROM item_template WHERE entry BETWEEN 801050 AND 801054;
DELETE FROM item_dbc WHERE ID BETWEEN 801050 AND 801054;
```

DBC files can be restored from the `.avant_item_upgrade` backups made in
section 4. If you installed the interface, delete `lua_scripts/ItemUpgrade`.

---

## 10. Differences from the original module

`docs/changes_vs_upstream.diff` holds the full detail. In short:

- **French in-game text** throughout the upgrade master's menus and messages.
- **Four player-level commands** added, `getstats`, `getcost`, `doupgrade` and
  `validate`, which let an interface drive the module. They apply the same
  checks and the same prices as the NPC.
- **A far wider default scale**, laid down by `c_item_upgrade_scale.sql`:
  41 stats over 20 ranks, where the original ships 8 stats over 2 ranks.
- **Tokens, an NPC and its spawns** in `01_item_upgrade_world.sql`.
- **An AIO interface**, which the original does not have.

Everything else, and in particular the whole upgrade engine, is the original
author's work.

---

## 11. Credits

**[mod-item-upgrade](https://github.com/silviu20092/mod-item-upgrade)** by
**[silviu20092](https://github.com/silviu20092)** is the original module, and the
entire upgrade system comes from it. This is a fork with additions; all credit
for the underlying work goes to its author.

**[AzerothCore](https://github.com/azerothcore/azerothcore-wotlk)** is the server
this module builds on, and the copyright holder named in the MIT licence.

**[AIO](https://github.com/Rochet2/AIO)** by **Rochet2**, GPL v2, pushes the
interface to players. Named as a dependency, not included here.

**[StormLib](https://github.com/ladislav-zezula/StormLib)** by **Ladislav
Zezula**, MIT, reads and writes MPQ archives. The compiled library is in
`tools/`, with its licence text.

---

## 12. Licence

MIT, as the original module. The text is in `LICENSE`. The SQL and Lua scripts
here follow the same licence. StormLib, in `tools/`, comes under its own MIT
licence in `tools/StormLib_LICENSE.txt`.
