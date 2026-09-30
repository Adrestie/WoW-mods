# WoW-mods installer

One program that installs, and removes, any AzerothCore module that carries a
manifest: an `installer.json` file at the root of the module folder, which
declares what the module needs. The format is described in
[MANIFEST.md](MANIFEST.md). It serves the modules of this repository that carry
one.

## Usage

Download `installer.exe` once, then run it, or drop a module folder (the one
that contains `installer.json`) on it. Its window holds the module folder, the
worldserver folder and the game folder; the AzerothCore sources and
`mysql.exe` are found by themselves when left empty. Under each field, a line
says what goes there and whether the path given is the expected one. It
remembers them in
`%APPDATA%\WoW-mods\installer-settings.json`. **Check** reads the server, the
game archives and the database, then shows the module's state and the traces
found, and the one button that fits: **Install**, **Remove** or **Remove
leftovers**, each confirmed before anything is written. What the installer
does goes to the log at the bottom of the window.

- **No trace of the module**: it INSTALLS. It copies the module into the
  server sources (`modules/`), puts its configuration and Lua scripts in
  place, adds its rows to the server DBC files, writes its rows and game files
  directly into the game's MPQ archives, and copies its addons into the game's
  `Interface\AddOns`. The server must then be recompiled; on first start, the
  core updater applies the module's SQL. A package without server module
  (`"server_module": false`) only writes the game files, the addons and the DBC
  rows: no sources, no configuration, no scripts, no SQL, no rebuild.
- **Any trace of the module**: it REMOVES everything that is left, wherever it
  is, database included (read and cleaned through `mysql.exe`, with the
  credentials of `worldserver.conf`). An uninstall started by hand is finished
  by running the program again.
- **Only items that carry the module's identifiers without proof that they
  belong to it** (a DBC row with the same identifier and other content, a game
  file shipped in another version by another archive, database rows without
  the rest of the module): it is a CONFLICT. It does not install. It removes
  them only if the user confirms they are leftovers of the module, and never a
  game file.

It refuses to write anything while the worldserver or the game is running.

Only the archives the game loads count: in `Data`, the base archives,
`patch.MPQ` and `patch-?.MPQ` (one character); in the language folder, its base
archives, `patch-xxXX.MPQ` and `patch-xxXX-?.MPQ`. Another `.mpq` file is never
written into; what a module left in one is removed with the rest.

An archive without room left for the module (hash table full, or a v1 archive
past 4 GB) is not written into: its share goes into `Data\patch-Z.MPQ`, the
archive the game reads last, created if there is none. When `patch-Z.MPQ` itself
has no room left, it refuses, before writing anything.

Before a game archive changes, it offers to copy it beside itself
(`<name>.backup-<date>-<time>`), ticked by default, once it has checked that the
drive holds the copies and the data about to be written.

A module that changes `Interface\GlueXML` or `Interface\FrameXML` needs a
`Wow.exe` that does not check these files against Blizzard's signature:
otherwise the game quits at start, saying its interface files are corrupt.
When `Wow.exe` (3.3.5a, build 12340) still checks them and WarcraftXL does not
load, the installer offers to patch it: 2 bytes per check, after a copy,
`Wow.exe.wow-mods.bak`. Removal turns the check back on once no archive the
game loads changes these files. It refuses a `Wow.exe` it does not know.

With `--status` or `--yes`, it runs without window, in the console of the
program that started it, and asks nothing: the paths come from the options or
from the remembered ones. From a batch file, `start /wait installer.exe ...`
waits for it and gets its exit code (0 done, 1 stopped or failed, 2
unexpected error).

| Option | Effect |
|---|---|
| `module` | module folder (the one that contains `installer.json`) |
| `--server DIR` | worldserver folder (the one that contains `worldserver.exe`) |
| `--sources DIR` | AzerothCore sources, when `CMakeCache.txt` does not lead to them |
| `--client DIR` | game folder (the one that contains `Wow.exe` and `Data`) |
| `--mysql FILE` | path of `mysql.exe` |
| `--status` | show the current state, change nothing |
| `--yes` | install or remove without window |
| `--leftovers` | with `--yes`: the conflicting items are leftovers of the module, remove them |
| `--patch-wow-exe` | with `--yes`: patch `Wow.exe` when it would refuse the module's interface files |
| `--no-backup` | with `--yes`: do not copy the game archives about to change |

It also runs without being compiled: `python installer\installer.py [module]`
(Python 3.12 or later, standard library only, tkinter included).

## Building installer.exe

`build.cmd` builds `installer.exe` in this folder with PyInstaller
(`python -m pip install pyinstaller`). A change to a module's manifest needs
no rebuild: the manifest is read at run time.

## Licence

MIT, see [LICENSE](LICENSE).
