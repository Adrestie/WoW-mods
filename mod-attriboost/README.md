# mod-attriboost

An AzerothCore module (WotLK 3.3.5a) that grants players **attribute points** to
spend freely across ten statistics, plus extra **talent points**. Points are
earned by trading in two items, the *Tome of Knowledge* and the *Book of
Talents*, which you hand out however you like: loot, vendor, event reward, quest.

This is an extended fork of [AnchyDev/Attriboost](https://github.com/AnchyDev/Attriboost).

Two ways to spend points, either or both:

* **the librarian**, an NPC with a gossip menu, which needs nothing beyond the
  module itself;
* **a user interface** opened from a minimap button or a slash command, which
  trades several books at once and lets you lay out your points before
  committing. It needs Eluna and AIO (see requirements).

Every point spent on a statistic adds one stack to a permanent aura: the core
multiplies the aura's amount by its stack count. Nothing is recomputed on a
timer, so the runtime cost is nil.

---

## 1. What the package contains

```
mod-attriboost/
├── README.md                        this guide
├── LICENSE                          AGPL v3
├── conf/
│   └── attriboost.conf.dist         caps, reset cost, on/off switch
├── src/                             the C++ module (3 files)
├── data/
│   ├── sql/
│   │   ├── db-world/base/
│   │   │   ├── 01_attriboost_dbc.sql     the 10 spells and 2 items, server side
│   │   │   └── 02_attriboost_world.sql   items, NPC, quests, gossip texts
│   │   └── db-characters/base/
│   │       └── 01_attriboost_characters.sql   the points table
│   └── lua/
│       ├── Attriboost_Serveur.lua   bridge between the interface and the module
│       └── Attriboost_Client.lua    the interface, shipped to the client by AIO
└── tools/
    ├── patch_client_dbc.cmd         client DBC patcher (double-click)
    ├── patch_client_dbc.py          the patcher itself
    └── attriboost_dbc.json          definition of the 10 spells and 2 items
```

### Identifiers used

| What | Identifiers |
|---|---|
| Aura spells | 890000 to 890009 |
| Items | 890010 (Tome of Knowledge), 890011 (Book of Talents) |
| NPC | 441153 |
| Quests | 441153, 441154 |
| NPC texts | 441190, 441191, 441192 |

No Blizzard identifier is reused. If one of these numbers is already taken on
your server, see section 6.5.

---

## 2. Requirements

| For | You need |
|---|---|
| The module and the NPC | AzerothCore, WotLK branch, up to date |
| The user interface | [mod-eluna](https://github.com/azerothcore/mod-eluna) and [AIO](https://github.com/Rochet2/AIO), installed and working |
| Patching the client DBCs | Python 3, no extra library |
| Packing the client patch | an MPQ editor, for instance *Ladik's MPQ Editor* |

The interface is optional. Without Eluna and AIO everything else still works:
the librarian, the quests, the chat commands.

---

## 3. Server installation

### 3.1 Drop the module in

Place the folder under `modules/` in your AzerothCore tree:

```
azerothcore-wotlk/modules/mod-attriboost/
```

### 3.2 Build

From your build directory, re-run the configuration step, then build. CMake must
list `mod-attriboost` among the modules.

```
cmake ..
```

Then build as usual. On Windows, linking the world server requires that it be
**stopped**.

### 3.3 Configure

Copy `conf/attriboost.conf.dist` into your server's `configs/modules/` folder,
name it `attriboost.conf`, open it and set:

```
Attriboost.Enable = 1
```

The module ships disabled so that nothing changes until you have applied the SQL.

### 3.4 Apply the SQL

Three files, two databases. If your server applies module SQL automatically,
leave them in place and start up: the updater will run them. Otherwise run them
by hand:

```
mysql -u root -p --default-character-set=utf8mb4 acore_world      < data/sql/db-world/base/01_attriboost_dbc.sql
mysql -u root -p --default-character-set=utf8mb4 acore_world      < data/sql/db-world/base/02_attriboost_world.sql
mysql -u root -p --default-character-set=utf8mb4 acore_characters < data/sql/db-characters/base/01_attriboost_characters.sql
```

Replace `acore_world` and `acore_characters` with your own database names. The
character set option is not optional: without it the accented characters of the
French translations are mangled.

All three files can be re-run safely: each one deletes what it is about to write.

> **Why no DBC file has to be patched server side.** AzerothCore loads
> `Spell.dbc` and `Item.dbc`, then tops them up from the `spell_dbc` and
> `item_dbc` tables, growing its index table as needed. `01_attriboost_dbc.sql`
> fills those two tables, so the server knows the ten spells and the two items
> without a single file being touched.

### 3.5 Install the interface (optional)

Copy both files from `data/lua/` into your server's Lua script folder, the one
`Eluna.ScriptPath` points at:

```
lua_scripts/Attriboost/Attriboost_Serveur.lua
lua_scripts/Attriboost/Attriboost_Client.lua
```

The server-side script reads your caps straight from `attriboost.conf`. If your
configuration file is not in the usual place, adjust the
`local CONF = "configs/modules/attriboost.conf"` line at the top of the file;
the path is relative to the world server's working directory.

### 3.6 Start up and check

Start the server. The log must show the module loading and no error mentioning
`attriboost`. In game, as a game master:

```
.lookup spell Increased Stamina
```

must return spell `890007`. If nothing comes back, `01_attriboost_dbc.sql` was
not applied to the right database.

### 3.7 Spawn the librarian

Stand where you want the NPC and type:

```
.npc add 441153
```

The NPC offers both trade-in quests and its gossip menu. You can skip it
entirely if you only use the interface.

### 3.8 Hand out the books

Nothing is wired up by default: how players get the books is your call. To try
it right away:

```
.additem 890010 5
.additem 890011 2
```

See section 6.4 to put them on loot tables or on a vendor.

---

## 4. Client installation

This step changes nothing on the server, but without it players see unnamed
auras with no icon, and two books marked with a question mark.

### 4.1 Extract the two DBCs from the client

With an MPQ editor, open your client archives and extract, from the
`DBFilesClient` folder:

* `Spell.dbc`
* `Item.dbc`

Take them from the archive that **wins** on your setup: if you already have
custom patches, extract from the last of them, otherwise from the stock
archives. Drop both files into an empty working folder.

### 4.2 Run the patcher

Double-click `tools/patch_client_dbc.cmd` and give it your working folder, or
pass it as an argument:

```
tools\patch_client_dbc.cmd C:\work\dbc
```

The script writes `tools\out\DBFilesClient\Spell.dbc` and `Item.dbc`, never
touching the input files, then reads its own output back to confirm all twelve
identifiers are there. It must end with:

```
Termine. Relecture des deux fichiers : les 12 identifiants sont presents.
```

Always start from the original DBCs, never from a previous output.

### 4.3 Pack and install

Build an MPQ archive holding the `DBFilesClient\Spell.dbc` and
`DBFilesClient\Item.dbc` layout, and drop it in the client's `Data` folder under
a name that sorts **after** the official archives. The 3.3.5 client loads in
alphabetical order and the last one wins: `patch-4.MPQ` will do if you have
nothing else, `patch-Z.MPQ` to be certain.

Close the game before writing into an archive: the client locks it.

### 4.4 Check

Log back in and type `.additem 890010`. The book must show its name and icon.
Once a point is spent, the matching aura must appear with its name and tooltip.

---

## 5. Full check

Run this once, in order, on a test character.

| # | Do this | Expect |
|---|---|---|
| 1 | `.lookup spell Increased Stamina` | returns spell 890007 |
| 2 | `.additem 890010 3` | three *Tomes of Knowledge*, correct name and icon |
| 3 | Talk to the NPC, hand in the quest | three attribute points credited |
| 4 | NPC menu, spend one point on Stamina | the *Increased Stamina* aura appears, stamina goes up |
| 5 | `.attriboost allocate stamina 2` | two more points, the aura reaches three stacks |
| 6 | Character sheet | stamina up by 15, that is three stacks of five points |
| 7 | `.attriboost reset` | everything returns to the pool, money is charged |
| 8 | With the interface: `/attributs` | the window opens, a minimap button appears |

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
| Stamina | 890007 | +5 |
| Strength | 890002 | +5 |
| Agility | 890000 | +5 |
| Intellect | 890001 | +5 |
| Spirit | 890003 | +5 |
| Spell damage | 890006 | +5 |
| Critical strike damage | 890004 | +1% |
| All resistances | 890008 | +1 |
| Spell penetration | 890009 | +1 |
| Healing power | 890005 | +10 |

To change a value, say stamina to 20 per point:

1. in `tools/attriboost_dbc.json`, find the object with `"id": 890007` and set
   its `"80"` field to **19**. The applied amount is always that field **plus
   one**: `EffectBasePoints` is 19 for a bonus of 20. A field missing from the
   list is zero; add it if you need to, as with spell 890004 whose `"80"` field
   is not written since it grants 1%;
2. in the same object, fix the `name`, `description` and `tooltip` texts, which
   show the number to the player;
3. re-run the client patcher (section 4.2) and rebuild your MPQ archive;
4. server side, change the same value in `01_attriboost_dbc.sql`, column
   `EffectBasePoints_1` of that spell, and re-run the file.

One warning about **critical strike damage**: the percentage applies to the
whole critical hit, not just to the bonus part. At +50%, a melee critical goes
from twice to three times normal damage. Raise that one carefully.

### 6.3 Points per book

A *Tome of Knowledge* gives three attribute points, a *Book of Talents* gives one
talent point. To change the former, edit `ATTR_POINTS_PER_BOOK` in
`src/Attriboost.h` and rebuild. If you use the interface, keep
`POINTS_PAR_LIVRE` at the top of `Attriboost_Serveur.lua` in step.

### 6.4 How players get the books

The module hands out nothing. A few ways to do it, to adapt:

```sql
-- On a vendor (replace 12345 with your NPC's entry)
INSERT INTO npc_vendor (entry, item, maxcount, incrtime, ExtendedCost)
VALUES (12345, 890010, 0, 0, 0);

-- On a creature's loot table, one time in five
INSERT INTO creature_loot_template (Entry, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount)
VALUES (12345, 890010, 20, 0, 1, 0, 1, 1);
```

Remember to blacklist both books from your auction house bot if you run one,
otherwise it will put them up for sale.

### 6.5 Moving the identifiers

If one number is already taken on your server, change it everywhere at once:

| Identifier | Where to change it |
|---|---|
| An aura spell | `src/Attriboost.h`, `01_attriboost_dbc.sql`, `tools/attriboost_dbc.json`, the `STATS` table in `Attriboost_Serveur.lua` |
| An item | `src/Attriboost.h`, both SQL files, `attriboost_dbc.json`, `Attriboost_Serveur.lua`, the `RC` table in `Attriboost_Client.lua` |
| The NPC, quests, texts | `src/Attriboost.h` and `02_attriboost_world.sql` |

After changing a spell identifier, **delete the rows carrying the old number
from `character_aura`, with the server stopped**. The module's auras are saved
there: otherwise the old one comes back on login with its old amount.

### 6.6 Texts and languages

* **Librarian menu**: literal strings in `src/Attriboost.cpp`, functions
  `SendAllocateMenu` and `SendSettingsMenu`. Rebuild required.
* **Interface**: the `L` table at the top of `Attriboost_Client.lua`, a French
  and an English version, picked from the client's locale.
* **Item names**: `02_attriboost_world.sql`, table `item_template` for English,
  `item_template_locale` for translations.
* **Aura names and tooltips**: `01_attriboost_dbc.sql` and
  `attriboost_dbc.json`. Careful, AzerothCore's column names are off by one
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

Remove the module folder and rebuild, then:

```sql
DELETE FROM spell_dbc WHERE ID BETWEEN 890000 AND 890009;
DELETE FROM item_dbc WHERE ID IN (890010, 890011);
DELETE FROM item_template WHERE entry IN (890010, 890011);
DELETE FROM creature_template WHERE entry = 441153;
DELETE FROM quest_template WHERE ID IN (441153, 441154);
DELETE FROM npc_text WHERE ID IN (441190, 441191, 441192);
-- characters database, server stopped
DELETE FROM character_aura WHERE spell BETWEEN 890000 AND 890009;
DROP TABLE attriboost_attributes;
```

Also delete any book left in players' bags unless you want orphaned entries.

---

## 7. Troubleshooting

| Symptom | Usual cause |
|---|---|
| Auras apply but have no name and no icon | the client patch is not installed, or its archive does not win over the others |
| Books show a question mark | same, or `item_dbc` was not filled server side |
| Nothing happens at the librarian | `Attriboost.Enable` is zero, or the config file is not in `configs/modules/` |
| The `.attriboost` command is refused | the server was not rebuilt, or linking failed because it was still running |
| The interface does not open | Eluna or AIO missing; check that both Lua files are in the script folder |
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
item and spell identifiers, and the tooling in this package.

Licensed under AGPL v3, like AzerothCore.
