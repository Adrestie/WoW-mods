# mod-forever-ui

The modern World of Warcraft interface, rebuilt for a 3.3.5a client.

This is not a module the server loads: it is a client addon plus the art it
needs. The art comes from a modern client, read sheet by sheet, and is served
to 3.3.5 the way the modern client serves it -- one texture, a rectangle read
inside it -- because 3.3.5 has no `SetAtlas`.

One section is one whole piece of the interface. A section is `done` when the
game has shown it right and it has been accepted, which also makes it a piece
nothing else is allowed to disturb.

| Section | What it holds | State |
|---|---|---|
| Player frame | Frame and portrait, health and power bars, rest and combat states, threat, vehicle art, PvP icon, raid subgroup indicator, play time, incoming damage, and the death knight rune bar. | done |
| Target frame | Frame and portrait, health and power bars, the reputation band, and the art each classification calls for: ordinary, minus, rare, elite and rare elite dragons, world boss ring. | done |
| Cast bar | Standard, channelled and uninterruptable casts, the interrupted state and the shield. | done |
| Action bar | The button and all of its states, the page number block, the two gryphon end caps. The button art reaches every action button the client carries, the secondary bars included. | done |
| Stance bar | Forms, auras and aspects, on the smaller button they share with the pet bar. | done |
| Pet bar | The familiar's buttons and their states. | done |
| Micro menu and bags bar | The micro buttons, and beside them the backpack, the bag slots and the keyring. | done |
| Experience and reputation bars | Both bars, their fills, and the reputation colour per standing. | done |
| Bags | Panel, slots, search box, sort button, round portrait in its ring, and under the money the currencies the player has chosen to watch. | done |
| Character sheet | The window and its two panes, the 3D model, the equipment slots, the side tabs, the level and class line, resistances, and the stat lines -- now on a banded background under a framed category header. The right pane opens on three tabs: character stats, the equipment manager (set cards in the player's own order, the worn-set check, rename and delete, `New Set`, and the icon picker beside the sheet), and the titles the character has earned, the worn one ticked. The right pane folds away, and the side tabs stay where they are. | done, except the titles tab and the new look of the stat lines, which are waiting to be accepted |
| Reputation | The factions the player knows, their blocks folded and unfolded, a standing bar per faction, and beside it the faction's own description with its three switches. A faction at war wears its own colour. | done |
| Skills | The skill lines the player knows, their blocks folded and unfolded, a bar per skill, and beside it the skill's description. | done |
| PvP | The season, the rank and its badge, and the ring filling towards the next rank. The ranks come from the titles the server awards, the honourable kills being what moves the ring. Beside it, what the client still knows of honour. | done |
| Currency | Everything the player carries, by category, folded and unfolded, with the icon each currency uses, and beside it the two switches the client offers. | done |
| Pet | The familiar in three dimensions, turned with the same arrows as the player, and beside it its level and name, its general statistics and its resistances as icons. | done |
| Statistics | -- | the tab exists, its screen is left empty on request |
| Dropdown lists | The list a dropdown opens, which is one and the same for every menu in the game: background, rows, font, check box and tick, and a width that follows the menu that opened it. | done |
| Minimap | The map in its modern frame, the clock and the calendar, the player's coordinates, and the arrows on the edge. | done |
| World map and quest log | The map in a window the player can move, the quest log as a pane beside it with the list and each quest's page, the maximized map, and the floor selector of dungeons. | done |
| Quest tracker | Quests and achievements under their headers, folded and unfolded, the objectives ticked as they are met, the sort and filter menu, a left click opening the quest on the map. | done |
| Chat | -- | not started |
| Tooltips | -- | not started |
| Buffs and debuffs | -- | not started |
| Party and raid frames | -- | not started |
| Spellbook | The book on one page or two, a category per tab, the spells in a grid under the category's name, passives round, similar spells grouped on flyouts, the settings menu, and the search with its preview. Pages, categories, flyouts, the size and the settings all work in combat. | done |
| Talents | -- | not started |
| Character select and creation | -- | not started |

Everything ForeverUI places is a movable system: `/fui` opens the edit mode,
`/fui reset` puts a piece -- or all of them -- back where the reference puts it.

## Layout of this folder

    data/addon/ForeverUI/     the addon itself, .lua and .toc -- the source
    data/art/interface/       the .blp that go into the client patch, each with
                              a .png beside it to see what it holds
    docs/AMELIORATIONS.md     the points asked for, and nothing else
    docs/NOTES.md             working notes: departures, traps, tooling
    docs/reference/           screenshots of the real thing, to check against
    tools/deployer.py         puts the addon in a client and the art in patch-Z
    tools/test_addon.py       a mock client that loads the addon and checks it
    tools/ajouter_feuilles.py brings an atlas sheet in with its preview, and
                              regenerates the atlas table
    tools/cuire_masque.py     bakes a mask into an icon's alpha, for the cuts
                              3.3.5 cannot make on screen

## Working on it

**This folder is the workspace, and the only place anything is edited.** The
addon in the client and the art in `patch-Z.MPQ` are copies the deployer makes;
editing either of them directly means the work is lost the next time anything
is deployed, and nobody can say afterwards what the game is actually showing.
The rule holds both ways: what sits under `Interface\ForeverUI` in the patch is
exactly what `data/art` holds, file for file, byte for byte. `--verifier`
reports what is missing, what differs and what is left over, and a deploy
removes from the archive anything this folder no longer carries.

New art follows the same path: the `.blp` and its `.png` preview land in
`data/art` first, then the deployer puts the `.blp` in the patch.

    python tools/deployer.py --verifier      compare the client with this folder
    python tools/deployer.py                 addon and art
    python tools/deployer.py --addon         the addon alone, client may stay open
    python tools/deployer.py --art           the art alone, close the client first

The addon files are read at login: after `--addon`, a `/reload` in game is
enough -- *unless a file was ADDED*. The client lists an addon's files when it
starts, and `/reload` replays the ones it already knows without discovering a
new one: a new `.lua` needs the game closed and reopened, however plainly it
sits in the `.toc`. The art lives in `patch-Z.MPQ`, which the client keeps locked while it
runs: close the game before `--art`, and start it again afterwards.

Before delivering anything, run the mock client -- it loads the whole addon and
checks the measurements taken from the reference:

    python tools/test_addon.py

It checks numbers, nothing else. **What a thing looks like is settled in the
game, and only there.** Composing the art in Python and looking at the picture
was tried and thrown away: such a picture only proves the arithmetic, since it
knows nothing of draw order, of what the client draws over it, or of the scale
it ends up at -- it showed windows as correct that the game showed wrong. The
screenshots under `docs/reference/` are the other half: they are the real
client, and they are what a result is compared against.

## Where the reference comes from

Every size, offset and texture name is read from the interface code of a modern
client, not guessed. Each file of the addon opens with the survey it was built
from: the file, the template and the line that gives each number. When this
addon departs from that reference -- because 3.3.5 cannot do it, or because the
result was wrong on screen -- the departure is written down at that spot, with
what was measured.

The art set is the one that client actually displays: sheets whose names carry
the `c60` suffix, and the `camelot` suffix for the status bars.

## Licence

GPL-2.0-or-later, see `LICENSE`. `tools/foreverui/mpq.py` reads and writes MPQ
archives; it is the copy this module carries, as each module in this repository
carries its own.
