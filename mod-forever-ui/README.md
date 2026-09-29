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

Needs Python 3 on the machine that holds the client.

    python tools/deploy.py                  addon, art, login screens, statistics
    python tools/deploy.py --addon          the addon alone (the game may stay open)
    python tools/deploy.py --check          compare the client with this folder

`--client <folder>` and `--server <folder>` (the folder of `worldserver.exe`)
point to other installs. Close the game before deploying the art, the login
screens or the statistics (`--art`, `--glue`, `--dbc`): the client locks
`patch-Z.MPQ` while it runs. The statistics also write to the server's DBC and
database: restart the server afterwards. After `--addon` alone, `/reload` is
enough, except when a file was added: then restart the game.

The PvP tab reads its rank thresholds and the Dishonored state from a server
running [mod-pvp-titles-ext](https://github.com/Adrestie/mod-pvp-titles-ext);
without it, it shows the kill count alone.

## Languages

No text is written in the code. Texts the 3.3.5 client already knows come from
its own strings; the others come from `data/addon/ForeverUI/Texts_<locale>.lua`
(and `ForeverUIGlueTexts_<locale>.lua` for the login screens). English is the
base, French is provided. To add a language, copy the `enUS` file to the
client's locale, translate the values only, and list it after the English one
in the `.toc` (or in `ForeverUIGlue.xml`).

## Working on it

This folder is the only place anything is edited: the client's addon folder
and `patch-Z.MPQ` are copies made by `tools/deploy.py`.

    data/addon/ForeverUI/   the addon
    data/glue/              the login screens
    data/art/               the .blp packed into patch-Z, each with a .png preview
    data/dbc/               the statistics added to the DBC
    tools/test_addon.py     a mock client that loads the addon and checks it
    tools/add_sheets.py     imports an atlas sheet (tools/extra_sheets.txt) through
                            wow.export and regenerates the atlas table

Run `python tools/test_addon.py` before any delivery; how a screen looks is
settled in the game. Another addon adds its own micro-menu button with
`ForeverUI.AddMicroButton`; ForeverUI knows no module.

## Licence

GPL-2.0-or-later, see `LICENSE`.
