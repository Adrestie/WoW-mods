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

Needs a 3.3.5a client (build 12340) and an MPQ editor that adds files to an
archive, such as Ladik's MPQ Editor. Close the game before touching its
archives: it locks them while it runs.

1. **The addon.** Copy the folder `data/addon/ForeverUI` into the client's
   `Interface\AddOns`, which gives `Interface\AddOns\ForeverUI\ForeverUI.toc`.
2. **The art.** The addon draws with its own textures, read from an archive.
   Open `Data\patch-Z.MPQ` in the client folder, or create an empty archive
   with that name if there is none. At the root of the archive, create a folder
   `interface`, then drop into it the folders `foreverui` and `Minimap`
   themselves (not their content), taken from `data/art/interface`.
   At the end the archive shows, under `interface`:
   - `foreverui\`, and in it 58 folders (`auctionframe`, `bankframe`, `bars`...
     `unknown`) holding 645 `.blp` files, for example
     `interface\foreverui\editmode\editmodeui.blp`;
   - `Minimap\ROTATING-MINIMAPGROUPARROW.blp`, the arrow of a group member at
     the edge of the minimap, resized for the larger map.
3. Start the game and check that **ForeverUI** is enabled in the AddOns list of
   the character selection screen.

### Optional

**Login screens.** Login, character selection and creation, realm list, AddOns
list, options, cinematics and credits in the camelot style; without them these
screens keep the client's look. In `patch-Z.MPQ`, add:

- every file of `data/glue/Interface/GlueXML` to `Interface\GlueXML\` (its
  `GlueXML.toc` replaces the client's list of login screen files);
- every `.m2` of `data/art/interface/Glues/Models` at the same path
  (`Interface\Glues\Models\UI_Human\UI_Human.m2`...). These screens show a wider
  scene than the client's, which would enlarge the characters; these scenery
  models are scaled down so the characters keep their size.

**Numbered appearance choices.** The 3.3.5 interface cannot know which skin,
face, hair or facial hair is applied. With `Wow.exe` patched, character
creation and the barber number the choices, show the color swatches and open
each setting as a list of its choices by name; without the patch, each setting
shows its name and changes with its arrows. Run
`tools/patcher/ForeverUIPatcher.exe` (Windows; it proposes the `Wow.exe` found
beside it), choose the client's `Wow.exe` and click **Patch**. It changes only a
`Wow.exe` 12340 it recognizes byte for byte, saves `Wow.exe.foreverui.bak`
first, and **Restore** gives back the original file.

**More statistics.** The Statistics tab of the character sheet lists the
client's statistics. `data/dbc/statistics.json` adds 18 that the camelot client
has and 3.3.5 lacks, on content 3.3.5 has: boss kills in classic dungeons, raids
entered by size, deaths in 20 and 40 player raids. It needs a DBC editor and the
server:

1. Take `DBFilesClient\Achievement.dbc` and `DBFilesClient\Achievement_Criteria.dbc`
   as the client reads them now (from the last archive that holds them).
2. For each statistic of the file, add a row to `Achievement.dbc`: its `id`,
   faction -1, its `map`, no previous achievement, title and description set to
   its `name` in every locale, its `category`, `points`, `order` and `flags`,
   icon 1, no reward, minimum criteria 0, no shared criteria. For each of its
   `criteria`, add a row to `Achievement_Criteria.dbc`: its `id`, the
   statistic's id, its `type`, its `target` as asset, its `quantity`, its
   `text` as description in every locale, order 1, every other field 0. Fill
   the locale mask columns as in the client's own statistics.
3. Add both files to `patch-Z.MPQ` under `DBFilesClient\`, and copy them into
   the server's `dbc` folder (in the `DataDir` of `worldserver.conf`): the
   server must read the same files as the client.
4. In the world database, for each `data` entry of a criterion:
   `INSERT INTO achievement_criteria_data (criteria_id, type, value1, value2, ScriptName) VALUES (<criterion id>, <type>, <value1>, <value2>, '');`
   Without these rows the server does not count the boss kills.
5. Restart the server.

**PvP ranks.** The PvP tab reads its rank thresholds and the Dishonored state
from a server running
[mod-pvp-titles-ext](https://github.com/Adrestie/mod-pvp-titles-ext); without it,
it shows the kill count alone.

## Languages

No text is written in the code. Texts the 3.3.5 client already knows come from
its own strings; the others come from `data/addon/ForeverUI/Texts_<locale>.lua`
(and `ForeverUIGlueTexts_<locale>.lua` for the login screens). English is the
base, French is provided. To add a language, copy the `enUS` file to the
client's locale, translate the values only, and list it after the English one
in the `.toc` (or in `ForeverUIGlue.xml`).

## Licence

GPL-2.0-or-later, see `LICENSE`.
