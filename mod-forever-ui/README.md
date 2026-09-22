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
| Action bar | The 45 x 45 button and all of its states, the page number block, the two gryphon end caps. The button art reaches every action button the client carries, the secondary bars included. | done |
| Stance bar | Forms, auras and aspects on the 30 x 30 small button. | done |
| Pet bar | The familiar's ten buttons, same small button as the stances. | done |
| Micro menu and bags bar | The ten micro buttons, and beside them the backpack, the four bag slots and the keyring. | done |
| Experience and reputation bars | Both bars, their fills, and the reputation colour per standing. | done |
| Bags | Panel, slots, search box, sort button, round portrait in its ring. | done |
| Character sheet | The 631 x 484 window and its two panes, the 3D model, the equipment slots, the side tabs, the level and class line, resistances, the twelve stat lines and their two category selectors; and in the right pane the two tabs it opens on -- character stats, and the equipment manager: set cards in the player's own order, the worn-set check, rename and delete, `New Set`, and the icon picker beside the sheet. | done, except the pane's collapse to 398 and the reputation / skills / PvP / currency tabs |
| Dropdown lists | `DropDownList1` and `DropDownList2`, which every menu in the game opens: background, rows, font, check box and tick, width aligned on the menu that opened it. | done |
| Minimap | -- | not started |
| Chat | -- | not started |
| Tooltips | -- | not started |
| Buffs and debuffs | -- | not started |
| Party and raid frames | -- | not started |
| Spellbook and talents | -- | not started |
| Character select and creation | -- | not started |

Everything ForeverUI places is a movable system: `/fui` opens the edit mode,
`/fui reset` puts a piece -- or all of them -- back where the reference puts it.

## Layout of this folder

    data/addon/ForeverUI/     the addon itself, .lua and .toc -- the source
    data/art/interface/       the .blp that go into the client patch, each with
                              a .png beside it to see what it holds
    docs/AMELIORATIONS.md     what is known to be improvable, and why
    docs/reference/           screenshots of the real thing, to check against
    tools/deployer.py         puts the addon in a client and the art in patch-Z
    tools/test_addon.py       a mock client that loads the addon and checks it
    tools/ajouter_feuilles.py brings an atlas sheet in with its preview, and
                              regenerates the atlas table

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
enough. The art lives in `patch-Z.MPQ`, which the client keeps locked while it
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
