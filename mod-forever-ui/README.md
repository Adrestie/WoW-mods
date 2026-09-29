# mod-forever-ui

The modern World of Warcraft interface (the "camelot" client), rebuilt for a
3.3.5a client: a client addon, the art it needs in `patch-Z.MPQ`, the login
screens, and a small server part for the statistics.

## What it covers

- **On screen:** player, target, party and raid frames, cast bar, action,
  stance and pet bars, micro menu and bags bar, experience and reputation
  bars, buffs, minimap, quest tracker, chat, tooltips.
- **Windows:** bags and bank, character sheet (with every tab), spellbook,
  talents and glyphs, world map and quest log, social, group finder, merchant,
  trade, mail, guild bank, auction house, trainers and NPC dialogs, professions,
  barber shop, guild tabard, inspection, dressing room, game menu and settings.
- **Login screens:** login, character select and creation, realm list, AddOns
  list, options, cinematics and credits.

The calendar, the help window and the other login screens keep the client's
look.

## Customize UI

**Esc > Customize UI** (or `/fui`) shows a grid and puts every element of the
interface under a blue veil:

- drag an element to move it; click it to select it: nine handles appear on
  its box, and the one held is the reference while dragging;
- the window beside the selected element sets its size, 50 to 200 %;
- the main window sets the grid spacing and origin, and two toggles: **Snap on
  Grid** (attracted by nearby grid lines) and **Sticky UI** (attracted by the
  edges of nearby elements);
- **Validate** saves, **Cancel** (or Esc) restores the layout found on opening,
  **Reset** puts everything back to default after a confirmation.

`/fui reset` puts every element back to default outside the editor. Entering
combat closes the editor and cancels its changes.

## Installation

Needs a 3.3.5a client (build 12340) and its AzerothCore server. Close the game
and stop the worldserver first: the game locks its archives while it runs, and
the server reads its DBC files only when it starts.

### With the installer

Download `installer.exe` from the
[releases of this repository](https://github.com/Adrestie/WoW-mods/releases),
run it and give it this folder, the one that contains `installer.json` (or drop
the folder on `installer.exe`). The first time, it asks for the worldserver
folder (the one that contains `worldserver.exe`) and the game folder (the one
that contains `Wow.exe` and `Data`), and remembers them. It shows what it finds,
then installs after Enter:

- it copies `data/addon/ForeverUI` into the game's `Interface\AddOns\ForeverUI`;
- it writes into the last custom archive the game reads (a new
  `Data\patch-Z.MPQ` when there is none): the art (`Interface\ForeverUI`, and
  the group member arrow of the minimap), the login screens
  (`Interface\GlueXML`) and their scenery models (`Interface\Glues\Models`,
  over those of another archive, such as an HD pack), with a receipt,
  `WoW-mods\mod-forever-ui.receipt`, listing what it wrote;
- it adds the 18 statistics to `Achievement.dbc` and `Achievement_Criteria.dbc`,
  in the game's archive and in the server's `dbc` folder;
- it reads everything back to check it.

It does not patch `Wow.exe`, runs no SQL, and touches neither the server's
sources, configuration nor database: nothing to rebuild. Start the worldserver
and the game afterwards, and check that **ForeverUI** is enabled in the AddOns
list of the character selection screen.

### By hand

Needs an MPQ editor that adds files to an archive, such as Ladik's MPQ Editor,
and a DBC editor for step 3. This gives the same result as the installer.

1. **The addon.** Copy the folder `data/addon/ForeverUI` into the game's
   `Interface\AddOns`, which gives `Interface\AddOns\ForeverUI\ForeverUI.toc`.
2. **The files of the archive.** Open `Data\patch-Z.MPQ` in the game folder, or
   create an empty archive with that name if there is none. At the root of the
   archive, create a folder `interface`, then drop into it these folders
   themselves (not their content): `foreverui`, `Minimap` and `Glues`, taken
   from `data/art/interface`, and `GlueXML`, taken from `data/glue/Interface`.
   At the end the archive shows, under `interface`:
   - `foreverui\`, and in it 58 folders (`auctionframe`, `bankframe`, `bars`...
     `unknown`) holding 645 `.blp` files, for example
     `interface\foreverui\editmode\editmodeui.blp`: the art of the interface;
   - `Minimap\ROTATING-MINIMAPGROUPARROW.blp`: the arrow of a group member at
     the edge of the minimap, resized for the larger map;
   - `GlueXML\`, holding 24 files (`GlueXML.toc`, `ForeverUIGlue.xml`...): the
     login screens in the camelot style;
   - `Glues\Models\`, holding 9 folders (`UI_BloodElf`... `UI_Tauren`), each with
     its `.m2`: the login screens show a wider scene than the client's, which
     would enlarge the characters, so these scenery models are scaled down.
3. **The statistics.** The Statistics tab of the character sheet lists the
   client's statistics; `data/dbc/statistics.json` adds 18 that the camelot
   client has and 3.3.5 lacks, on content 3.3.5 has: boss kills in classic
   dungeons, raids entered by size, deaths in 20 and 40 player raids.
   1. Take `DBFilesClient\Achievement.dbc` and
      `DBFilesClient\Achievement_Criteria.dbc` as the game reads them now (from
      the last archive that holds them).
   2. For each statistic of the file, add a row to `Achievement.dbc`: its `id`,
      faction -1, its `map`, no previous achievement, title and description set
      to its `name` in every locale, its `category`, `points`, `order` and
      `flags`, icon 1, no reward, minimum criteria 0, no shared criteria. For
      each of its `criteria`, add a row to `Achievement_Criteria.dbc`: its
      `id`, the statistic's id, its `type`, its `target` as asset, its
      `quantity`, its `text` as description in every locale, order 1, every
      other field 0. Fill the locale mask columns as in the client's own
      statistics.
   3. Add both files to `patch-Z.MPQ` under `DBFilesClient\`, and copy them into
      the server's `dbc` folder (in the `DataDir` of `worldserver.conf`): the
      server must read the same files as the game.
4. Start the worldserver and the game, and check that **ForeverUI** is enabled
   in the AddOns list of the character selection screen.

### Optional

**The SQL file.** The server counts a creature kill for a statistic only when
its criterion has a row in `achievement_criteria_data`: without these rows, the
boss kill statistics added above stay at 0 (raids entered and deaths are counted
anyway). `sql/foreverui_statistics.sql` adds them. Once the statistics are
installed, run it on the world database (`acore_world` by default) with your
MySQL client, such as HeidiSQL or MySQL Workbench, then restart the worldserver.
It can be run again safely.

**The `Wow.exe` patch.** The 3.3.5 interface cannot know which skin, face, hair
or facial hair is applied. With `Wow.exe` patched, character creation and the
barber number the choices, show the color swatches and open each setting as a
list of its choices by name; without the patch, each setting shows its name and
changes with its arrows. Run `tools/patcher/ForeverUIPatcher.exe` (Windows; it
proposes the `Wow.exe` found beside it), choose the game's `Wow.exe` and click
**Patch**. It changes only a `Wow.exe` 12340 it recognizes byte for byte, and
saves a copy of it first, `Wow.exe.foreverui.bak`.

**PvP ranks.** The PvP tab reads its rank thresholds and the Dishonored state
from a server running
[mod-pvp-titles-ext](https://github.com/Adrestie/mod-pvp-titles-ext); without it,
it shows the kill count alone.

## Uninstallation

Close the game and stop the worldserver first.

### With the installer

Run `installer.exe` again on this folder. It finds ForeverUI and, after you type
`YES` then Enter, removes everything that is left of it: the folder
`Interface\AddOns\ForeverUI`, its files in the game's archives (those its
receipt lists, and everything under `Interface\ForeverUI`), and the statistics'
rows in the game's and the server's DBC files. An archive it no longer changes
is deleted, and scenery models of another archive show again. It also finishes
an uninstallation started by hand. It removes neither the optional parts (see
below) nor the addon's settings (step 4 below).

### By hand

1. Delete the folder `Interface\AddOns\ForeverUI` of the game.
2. In `patch-Z.MPQ`, under `interface`, delete the folder `foreverui`, the file
   `Minimap\ROTATING-MINIMAPGROUPARROW.blp`, the 9 `UI_...` folders of
   `Glues\Models` and the 24 files of `GlueXML` added at installation. If the
   installer was used, delete its receipt too, `WoW-mods\mod-forever-ui.receipt`.
3. Delete the statistics' rows, in the copies of the two files inside
   `patch-Z.MPQ` and in the server's `dbc` folder: in `Achievement.dbc` the rows
   6137, 6139 to 6146, 6786, 15027 to 15030, 64183 to 64185 and 64300; in
   `Achievement_Criteria.dbc` the rows 64301 to 64321.
4. The addon's settings (positions, sizes, grid) stay in
   `WTF\Account\<account>\SavedVariables\ForeverUI.lua`: delete that file to
   forget them.

### Removing the optional parts

- **The SQL rows.** Run only the first statement of
  `sql/foreverui_statistics.sql`, the `DELETE`, on the world database, then
  restart the worldserver.
- **The `Wow.exe` patch.** Run `tools/patcher/ForeverUIPatcher.exe`, choose the
  game's `Wow.exe` and click **Restore**: the file becomes the original again,
  byte for byte. The copy `Wow.exe.foreverui.bak` stays; it can be deleted.

## Languages

No text is written in the code. Texts the 3.3.5 client already knows come from
its own strings; the others come from `data/addon/ForeverUI/Texts_<locale>.lua`
(and `ForeverUIGlueTexts_<locale>.lua` for the login screens). English is the
base, French is provided. To add a language, copy the `enUS` file to the
client's locale, translate the values only, and list it after the English one
in the `.toc` (or in `ForeverUIGlue.xml`).

## Licence

GPL-2.0-or-later, see `LICENSE`.
