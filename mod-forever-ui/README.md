# mod-forever-ui

The modern World of Warcraft interface, rebuilt for a 3.3.5a client.

This is not a module the server loads: it is a client addon plus the art it
needs. The art comes from a modern client, read sheet by sheet, and is served
to 3.3.5 the way the modern client serves it -- one texture, a rectangle read
inside it -- because 3.3.5 has no `SetAtlas`.

| What is rebuilt | State |
|---|---|
| Player frame, its portrait, threat and combat states, vehicle art | done |
| Death knight runes | done |
| Target frame, classification rings, target of target | done |
| Cast bar | done |
| Action bar, page block, end caps | done |
| Micro menu, bags bar | done |
| Experience and reputation bars | done |
| Bags: panel, slots, search box, sort button | done |
| Minimap, chat, tooltips, auras, party and raid frames, panels | not started |

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
    tools/apercu_rangee.py    composes the bottom row as a picture, to look at
                              it before trying it in game
    tools/apercu_sacs.py      the same for the backpack window

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
