# mod-attriboost

An AzerothCore module (WotLK 3.3.5a) that grants players **attribute points** to
spend freely across ten statistics, plus extra **talent points**. Points are
earned by trading in two items, the *Tome of Knowledge* and the *Book of
Talents*, which you hand out however you like: loot, vendor, event reward, quest.

This is an extended fork of [AnchyDev/Attriboost](https://github.com/AnchyDev/Attriboost).

Points are spent through **a user interface**, an ALE addon opened from a
minimap button or a slash command, which trades several books at once and lets
you lay out your points before committing. It needs ALE and AIO (see
requirements). There is no NPC. When the client runs the ForeverUI interface
(mod-forever-ui), the window and the minimap button give way to an
"Attributes" tab of a Progression window in the Camelot style, which Item
Upgrade shares when it is installed too. The module draws that window itself,
with the textures ForeverUI installs, and only asks ForeverUI to add its button
to the micro menu. Without ForeverUI nothing changes.

Every point spent on a statistic adds one stack to a permanent aura: the core
multiplies the aura's amount by its stack count. Nothing is recomputed on a
timer, so the runtime cost is nil. Those ten auras are hidden; the player sees a
single aura, *Attributes*, whose tooltip lists every bonus.

---

## 1. What the package contains

```
mod-attriboost/
├── README.md                        this guide
├── LICENSE                          MIT, the licence of the original module
├── conf/
│   └── attriboost.conf.dist         caps, reset cost, on/off switch
├── src/                             the C++ module (3 files)
├── data/
│   ├── sql/
│   │   ├── db-world/base/
│   │   │   ├── 01_attriboost_dbc.sql     the 10 spells and 2 items, server side
│   │   │   ├── 02_attriboost_world.sql   the 2 items
│   │   │   ├── 03_attriboost_strings.sql every text of the module, in each language
│   │   │   └── 04_attriboost_commands.sql the help of the chat commands
│   │   └── db-characters/base/
│   │       └── 01_attriboost_characters.sql   the points table
│   ├── lua/
│   │   ├── Attriboost_Serveur.lua   bridge between the interface and the module
│   │   └── Attriboost_Client.lua    the interface, shipped to the client by AIO
│   └── art/Interface/Attriboost/    the images of the Progression window, its tab
│                                    and its gauge, written into the game by the installer
└── installer.json                   what the WoW-mods installer puts in place and removes:
                                     the spells and items in the DBC files, the files,
                                     the database rows
```

### Identifiers used

| What | Identifiers |
|---|---|
| Aura spells | 82000 to 82009, hidden; 82012, the visible *Attributes* aura |
| Items | 82010 (Tome of Knowledge), 82011 (Book of Talents) |
| Texts (`module_string`) | module `mod-attriboost`: 1 to 99 messages, 101 and up the interface |
| Chat commands (`command`) | `attriboost` and its four subcommands |

No Blizzard identifier is reused. If one of these numbers is already taken on
your server, see section 6.5.

---

## 2. Requirements

| For | You need |
|---|---|
| The module | AzerothCore, WotLK branch, up to date |
| The user interface | [mod-ale](https://github.com/azerothcore/mod-ale) (the AzerothCore Lua Engine, formerly mod-eluna) and [AIO](https://github.com/Rochet2/AIO), installed and working: AIO's server part on the server, its client addon on every player's client (section 4) |
| Running the installer | the WoW-mods installer, `installer.exe`, from the `installer/` folder of this repository; MySQL running, and its command-line client `mysql.exe`, which comes with MySQL Server |

The interface is how players spend their points. Without ALE and AIO, only the
chat commands (`.attriboost ...`) remain.

---

## 3. Server installation

### 3.1 Run the installer

Stop the world server and close the game, then run `installer.exe`, the
WoW-mods installer (`installer/` folder of this repository), and give it this package's
folder, or drop the folder on `installer.exe`. Keep the package where you
downloaded it: the installer refuses to run from your server's `modules`
folder.

Its window asks for two folders the first time, then remembers them:

* the world server folder, the one holding `worldserver.exe`;
* the game folder, the one holding `Wow.exe` and `Data`.

It finds the rest from there: the configuration folder and the databases in
`worldserver.conf`, the Lua script folder in `mod_ale.conf` (`lua_scripts` by
default), your AzerothCore sources in the build folder's `CMakeCache.txt`, and
`mysql.exe`. It shows whatever it found of the module before changing
anything.

Finding nothing of the module, it offers **Install**, which puts in place:

* the module is copied to `modules/mod-attriboost` in your sources;
* `attriboost.conf`, with `Attriboost.Enable = 1`, and `attriboost.conf.dist`
  are written to the module configuration folder;
* both Lua files go to `lua_scripts/Attriboost/`; if your configuration folder
  is not the usual one, the path at the top of `Attriboost_Serveur.lua`
  follows it;
* the eleven spells and the two items are added to `Spell.dbc` and `Item.dbc`,
  directly inside the game archive those files come from, and the module's
  images (`data/art`) are written under `Interface\Attriboost` (section 4).

It reads everything back from the disk and ends with `Installation complete.`,
followed by the build commands.

### 3.2 Build

Run the commands the installer printed, from your build folder, the world
server stopped: linking fails while it runs.

```
cmake .
cmake --build . --config RelWithDebInfo --target worldserver
```

`cmake .` is what makes the build notice the new module.

### 3.3 Start up

Start the server. On this first start the updater applies the five SQL files of
`data/sql`: the spells and items (`spell_dbc`, `item_dbc`, `item_template`), the
texts, the command help and the points table. If `Updates.EnableDatabases` in
`worldserver.conf` does not cover the world and characters databases, the
installer has applied them itself.

If the server already ran the original Attriboost, its `attriboost_attributes`
table is kept, with every player's points: the characters file adds the columns
this fork needs, each in its place. See section 6.9 for the rest of an upgrade.

> **Why no DBC file has to be patched server side.** AzerothCore loads
> `Spell.dbc` and `Item.dbc`, then tops them up from the `spell_dbc` and
> `item_dbc` tables, growing its index table as needed. `01_attriboost_dbc.sql`
> fills those two tables, so the server knows the ten spells and the two items
> without a single file being touched.

### 3.4 Check the server

The log must show the module loading and no error mentioning
`attriboost`. In game, as a game master:

```
.lookup spell Increased Stamina
```

must return spell `82007`. If nothing comes back, `01_attriboost_dbc.sql` was
not applied to the right database.

### 3.5 Hand out the books

Nothing is wired up by default: how players get the books is your call. To try
it right away:

```
.additem 82010 5
.additem 82011 2
```

See section 6.4 to put them on loot tables or on a vendor.

---

## 4. Client side

The installer has already written the spells and the items into the game folder
you gave it. It writes into the archive that provides `Spell.dbc` and `Item.dbc`
when that archive is one of yours, `patch-Z.MPQ` for instance; when they come
from an official archive, into your last custom archive, or into a new
`Data\patch-Z.MPQ` if you have none. The module's images go into your last
custom archive, under `Interface\Attriboost`. Official archives are never
modified, and only the module's rows are added: everything else in those files
stays as it was.

Every player also needs AIO's client addon, `AIO_Client`, in the client's
`Interface\AddOns` folder, as AIO's own instructions describe. Without it the
interface never reaches the player; the chat commands still work.

Other players' clients need the same rows: give them the archive the installer
wrote to, whose path its output shows.

### 4.1 Check

Log back in and type `.additem 82010`. The book must show its name and icon.
Once a point is spent, the *Attributes* aura must appear, its tooltip listing
the bonus.

---

## 5. Full check

Run this once, in order, on a test character.

| # | Do this | Expect |
|---|---|---|
| 1 | `.lookup spell Increased Stamina` | returns spell 82007 |
| 2 | `.additem 82010 1` | one *Tome of Knowledge*, correct name and icon |
| 3 | Right-click the tome in your bags | the window opens and a minimap button appears (with ForeverUI: the Progression window opens on the "Attributes" tab, no minimap button); nothing else happens, the tome stays in the bags |
| 4 | Close the window, type `/attributs` | the window opens again |
| 5 | In the window, trade the tome | three attribute points credited |
| 6 | In the window, put one point on Stamina and confirm | the *Attributes* aura appears, its tooltip reads +5 Stamina, stamina goes up; no *Increased Stamina* aura in the buff bar |
| 7 | `.attriboost allocate stamina 2`, then hover the *Attributes* aura | two more points; the tooltip reads +15 Stamina |
| 8 | Character sheet | stamina up by 15, that is three stacks of five points |
| 9 | `.attriboost reset` | everything returns to the pool, money is charged, *Attributes reset.* |
| 10 | `.attriboost exchange 999` on a French client | *Nombre de livres invalide.*, the message in the client's language |
| 11 | `.help attriboost exchange` | *Syntax: .attriboost exchange $count* and its explanation |

If a step fails, section 7 lists the usual causes.

---

## 6. Customisation

### 6.1 Caps, cost, on/off

All of it lives in `attriboost.conf`, re-read on every restart:

```
Attriboost.Enable = 1              # 0 turns everything off without uninstalling
Attriboost.ResetCost = 2500000     # cost of one reset, in copper
Attriboost.DisablePvP = 1          # inherited from the original module, no effect
Attriboost.Max.Stamina = 100       # maximum points per statistic
Attriboost.Max.Strength = 50
Attriboost.Max.Agility = 50
Attriboost.Max.Intellect = 50
Attriboost.Max.Spirit = 50
Attriboost.Max.SpellPower = 100
Attriboost.Max.CriticalStrikeDamage = 50
Attriboost.Max.AllResists = 50
Attriboost.Max.SpellPenetration = 100
Attriboost.Max.HealingPower = 100
```

Lowering a cap takes nothing away from players already above it: their points
stay applied until they reset.

### 6.2 What one point is worth

That is the aura's amount, and it lives in two places that must agree: the
`spell_dbc` table on the server, the `Spell.dbc` file on the client. Shipped
values:

| Statistic | Spell | Per point |
|---|---|---|
| Stamina | 82007 | +5 |
| Strength | 82002 | +5 |
| Agility | 82000 | +5 |
| Intellect | 82001 | +5 |
| Spirit | 82003 | +5 |
| Spell damage | 82006 | +5 |
| Critical strike damage | 82004 | +1% |
| All resistances | 82008 | +1 |
| Spell penetration | 82009 | +1 |
| Healing power | 82005 | +10 |

To change a value, say stamina to 20 per point:

1. in `installer.json`, entry `Spell.dbc`, find the row whose `"0"` field is
   82007 and set its `"80"` field to **19**. The applied amount is always that field **plus
   one**: `EffectBasePoints` is 19 for a bonus of 20. A field missing from the
   list is zero; add it if you need to, as with spell 82004 whose `"80"` field
   is not written since it grants 1%;
2. the texts need no change: the name carries no number, and the description
   and tooltip read the amount through `$s1`;
3. the installer writes that file into the game when it installs the module:
   on a server where the module is already installed, that means running it
   twice, which also erases the players' points (see section 6.9);
4. server side, change the same value in `01_attriboost_dbc.sql`, column
   `EffectBasePoints_1` of that spell, and re-run the file.

One warning about **critical strike damage**: the percentage applies to the
whole critical hit, not just to the bonus part. At +50%, a melee critical goes
from twice to three times normal damage. Raise that one carefully.

### 6.3 Points per book

A *Tome of Knowledge* gives three attribute points, a *Book of Talents* gives one
talent point. To change the former, edit `ATTR_POINTS_PER_BOOK` in
`src/Attriboost.h` and rebuild. Keep `POINTS_PAR_LIVRE` at the top of
`Attriboost_Serveur.lua` in step.

### 6.4 How players get the books

The module hands out nothing. A few ways to do it, to adapt:

```sql
-- On a vendor (replace 12345 with your NPC's entry)
INSERT INTO npc_vendor (entry, item, maxcount, incrtime, ExtendedCost)
VALUES (12345, 82010, 0, 0, 0);

-- On a creature's loot table, one time in five
INSERT INTO creature_loot_template (Entry, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount)
VALUES (12345, 82010, 20, 0, 1, 0, 1, 1);
```

Remember to blacklist both books from your auction house bot if you run one,
otherwise it will put them up for sale.

### 6.5 Moving the identifiers

If one number is already taken on your server, change it everywhere at once:

| Identifier | Where to change it |
|---|---|
| An aura spell | `src/Attriboost.h`, `01_attriboost_dbc.sql`, `installer.json`, the `STATS` table in `Attriboost_Serveur.lua` |
| The *Attributes* aura | `ATTR_SPELL_SUMMARY` in `src/Attriboost.h`, `01_attriboost_dbc.sql`, `installer.json`, `RC.RESUME` in `Attriboost_Client.lua` |
| An item | `src/Attriboost.h`, `01_attriboost_dbc.sql`, `02_attriboost_world.sql`, `installer.json`, `Attriboost_Serveur.lua`, the `RC` table in `Attriboost_Client.lua` |

After changing a spell identifier, **delete the rows carrying the old number
from `character_aura`, with the server stopped**. The module's auras are saved
there: otherwise the old one comes back on login with its old amount.

### 6.6 Texts and languages

* **Messages and interface**: one source for every text the module shows,
  `03_attriboost_strings.sql`, table `module_string` for English,
  `module_string_locale` for every other language. The C++ module reads its chat
  messages there, the server-side Lua script its refusals, and the interface
  receives its own texts from that script, sent with its code when the player
  logs in. Each player gets the texts of their client's language, English when
  there is no row for it. Numbers 1 to 99 are messages, 101 and up the
  interface. To add a language, add one row per number to
  `module_string_locale` with that client's locale code (`deDE`, `esES`,
  `ruRU`...), apply it and restart: no rebuild. Keep every `{}`, which stands
  for a value.
* **Item names**: `02_attriboost_world.sql`, table `item_template` for English,
  `item_template_locale` for translations.
* **Aura names and tooltips**: `01_attriboost_dbc.sql` and
  `installer.json`. Careful, AzerothCore's column names are off by one
  slot: the `Name_Lang_koKR` column actually holds the DBC file's third
  language, which is **French** on a 3.3.5 client. Writing into `Name_Lang_frFR`
  would show German.

### 6.7 How the interface looks

Everything sits in the `RC` table at the top of `Attriboost_Client.lua`:

* `MM_ANGLE` places the button around the minimap, in degrees, zero at the right
  and ninety at the top;
* `MM_ICONE` changes its icon;
* `LARGEUR`, `LIGNE_H`, `CARTE_H` set the window's dimensions;
* `ICONES` maps a fallback icon to each statistic;
* `AMORTI`, `FONDU`, `FLOTTANT` set animation speeds.

Every texture used comes from the stock 3.3.5 client.

### 6.8 Uninstalling

Stop the world server, close the game, and run the installer again on this
folder. Finding the module, even in part, it lists what it found and, once you
confirm **Remove**, removes all of it:

* in the characters database, the talent points the Books of Talents granted
  are taken back first, then the saved auras and the points table go;
* in the world database, the module's rows in `spell_dbc`, `item_dbc`,
  `item_template`, `item_template_locale`, `module_string`,
  `module_string_locale` and `command`, and the updater's record of its files
  in `updates`, so that a later installation applies them again;
* the module's rows in `Spell.dbc` and `Item.dbc`, in every custom archive of
  the game and in the server's DBC folder, with the texts its spells added, and
  every file under `Interface\Attriboost` in those archives;
  everything else in those files is left as it is, and an archive that no
  longer changes anything, such as one the installation created, is deleted;
* the module folder in `modules/`, whatever its name, `attriboost.conf` and
  `attriboost.conf.dist`, both Lua files wherever they are in the script
  folder, and the `Attriboost` folder unless it holds files of your own.

It then checks that nothing is left and prints the build commands: rebuild, and
the module is gone from the world server. If you had started removing the
module by hand, run the installer anyway: it removes whatever is left.

Only the points this module granted are taken back: the core keeps a single
counter of extra talent points, which other modules may feed too. A character
who had spent them gets their talents reset at the next login, by the core
itself. Points granted by a version of this module older than the
`talentpoints` column were not recorded; if Attriboost is the only source of
extra talent points on your server, `UPDATE characters SET
extraBonusTalentCount = 0;` takes those back as well.

Books left in a player's bags, bank or mail are deleted by the core itself when
that character next logs in, since their item no longer exists. Auctions and
guild banks are not covered by that: if books may be there, clear them out
before uninstalling.

### 6.9 Upgrading

**Every upgrade.** The installer only installs or removes: run on an installed
module, it removes it, players' points included. An upgrade therefore follows
the steps below by hand, and the new rows of `installer.json` have to
reach the game archive the same way. The *Tome of Knowledge*, for one, is now a
plain miscellaneous item with no use.

**From the original Attriboost.** Nothing to do for the points: the characters
file keeps the existing table and adds the missing columns (section 3.3).

**From a version of this module that had the librarian** (NPC 441153). The NPC,
its two quests and its texts are gone, and the module no longer carries the
script they called. Remove what an earlier install left behind, in the world
database:

```sql
DELETE FROM creature WHERE id = 441153;
DELETE FROM creature_template WHERE entry = 441153;
DELETE FROM creature_template_model WHERE CreatureID = 441153;
DELETE FROM creature_queststarter WHERE id = 441153;
DELETE FROM creature_questender WHERE id = 441153;
DELETE FROM quest_template WHERE ID IN (441153, 441154);
DELETE FROM quest_template_addon WHERE ID IN (441153, 441154);
DELETE FROM quest_request_items WHERE ID IN (441153, 441154);
DELETE FROM quest_offer_reward WHERE ID IN (441153, 441154);
DELETE FROM npc_text WHERE ID IN (441190, 441191, 441192);
```

---

## 7. Troubleshooting

| Symptom | Usual cause |
|---|---|
| The *Attributes* aura has no name and no icon, or the ten auras show in the buff bar | the client patch is not installed, or its archive does not win over the others |
| The *Attributes* tooltip lists no bonus | ALE or AIO missing, or `AIO_Client` not ticked: the list comes from the interface |
| Books show a question mark | same, or `item_dbc` was not filled server side |
| Every command answers *The attribute system is disabled.* | `Attriboost.Enable` is zero, or the config file is not in `configs/modules/` |
| The `.attriboost` command is refused | the server was not rebuilt, or linking failed because it was still running |
| Messages come in English on another client | `03_attriboost_strings.sql` holds no row for that language (section 6.6) |
| The interface shows bare words (`titre`, `valider`...), messages read `#15` or `[mod-attriboost] missing text 3` | `03_attriboost_strings.sql` was not applied, or the server-side Lua script failed to load: see the ALE log |
| The interface does not open | ALE or AIO missing; check that both Lua files are in the script folder |
| Accents are mangled | the SQL was run without `--default-character-set=utf8mb4` |
| A player keeps an old bonus | their aura was saved in `character_aura`; delete the row with the server stopped |
| Points are there but have no effect | the character was dead when they were applied; auras are laid back on at the next login |

---

## 8. Technical notes

**How it works.** One point spent adds a stack to that statistic's aura.
`AuraEffect::CalculateAmount` multiplies the effect's amount by the stack count.
The module writes that count directly through `Aura::SetStackAmount`, which
**bypasses the DBC's `CumulativeAura` limit**: the only real bounds are the
`Attriboost.Max.*` settings.

**One aura in sight.** The ten auras carry the attributes that hide a spell from
the client (`SPELL_ATTR0_DO_NOT_DISPLAY`, `SPELL_ATTR0_DO_NOT_LOG`,
`SPELL_ATTR1_NO_AURA_ICON`, the ones Stellar Tarot uses); they only concern the
client, and the auras apply all the same. The module keeps a dummy aura,
*Attributes* (82012), on the player while any point is spent. The interface adds
one line per statistic under its tooltip: the statistic spell's own text, with
the amount of all its points. The server sends the points at login, and again
whenever that tooltip shows, since chat commands change them without the
interface.

**Damage and healing are two separate paths.** Aura type 13 feeds the spell
damage bonus, type 135 the healing bonus. The *Spell damage* and *Healing power*
statistics carry one each, so they really are independent. The old item mods 41
and 42, flagged deprecated in the core, concern items only and have nothing to
do with these auras.

**The auras persist.** They are written to `character_aura` on logout and
reloaded as they were, carrying that day's base amount. Changing a value only
reaches a player who already has points after a reset, or after their row in
that table is deleted.

**The interface decides nothing.** It sends requests that the server-side Lua
script validates, then carries out through the module's commands, whose database
writes are synchronous. The state displayed is always read back from the
database afterwards.

---

## Credits

* **[AnchyDev/Attriboost](https://github.com/AnchyDev/Attriboost)** — the
  original module this one is built on.
* **Foe** — the idea of using auras as attributes, credited by the original
  module.

This fork adds four statistics, the user interface, the chat commands, its own
item and spell identifiers, and the tooling in this package. The interface
replaces the original module's librarian NPC.

Licensed under the MIT licence, like the original module it forks: see `LICENSE`.
