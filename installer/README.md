# WoW-mods installer

One program that installs, and removes, any AzerothCore module that carries a
manifest: an `installer.json` file at the root of the module folder, which
declares what the module needs. The format is described in
[MANIFEST.md](MANIFEST.md). It serves the modules of this repository that carry
one.

## Usage

Download `installer.exe` once, then run it and give it the module folder, the
one that contains `installer.json`, or drop that folder on `installer.exe`.
The first time, it also asks for the worldserver folder, the game folder and,
if it cannot find it, `mysql.exe`; it remembers them in
`%APPDATA%\WoW-mods\installer-settings.json`.

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
A removal is confirmed by typing `YES`, a removal of leftovers by typing
`LEFTOVERS`.

| Option | Effect |
|---|---|
| `module` | module folder (the one that contains `installer.json`) |
| `--server DIR` | worldserver folder (the one that contains `worldserver.exe`) |
| `--sources DIR` | AzerothCore sources, when `CMakeCache.txt` does not lead to them |
| `--client DIR` | game folder (the one that contains `Wow.exe` and `Data`) |
| `--mysql FILE` | path of `mysql.exe` |
| `--status` | show the current state, change nothing |
| `--yes` | ask nothing (paths from the options or remembered) |
| `--leftovers` | with `--yes`: the conflicting items are leftovers of the module, remove them |

It also runs without being compiled: `python installer\installer.py [module]`
(Python 3.12 or later, standard library only).

## Building installer.exe

`build.cmd` builds `installer.exe` in this folder with PyInstaller
(`python -m pip install pyinstaller`). A change to a module's manifest needs
no rebuild: the manifest is read at run time.

## Licence

MIT, see [LICENSE](LICENSE).
