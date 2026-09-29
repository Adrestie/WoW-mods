# installer.json, format 1

The manifest sits at the root of the module folder and declares everything the
installer puts in place, and therefore everything it looks for and removes.
The installer checks it in full before touching anything: a missing key, a
malformed row or a file missing from the package stops it with a message that
names the problem.

Paths inside the package are relative to the module folder, with `/`.

## Keys

| Key | Required | Content |
|---|---|---|
| `format` | yes | `"wow-mods-installer/1"` |
| `module` | yes | name of the module folder under `modules/` in the server sources (letters, digits, `_`, `.`, `-`); the name its receipts carry |
| `title` | no | display name |
| `server_module` | no | `false`: a package without server module, see below (`true` by default) |
| `signature` | yes, unless `server_module` is `false` | package files that identify the module: a folder of `modules/` that contains all of them is the module, whatever its name |
| `exclude_from_sources` | no | package folders or files not copied into `modules/` (client data, for instance); `.git` and `__pycache__` never are |
| `configuration` | no | the module's `.conf`, see below |
| `lua` | no | the module's Lua scripts, see below |
| `dbc` | no | the module's DBC rows, see below |
| `game_files` | no | files written into the game archives, see below |
| `addons` | no | addon folders copied into the game's `Interface\AddOns`, see below |
| `backups` | no | suffixes of backup files left by older tools (e.g. `".avant_item_upgrade"`), deleted on removal |
| `database` | no | what the module leaves in the database, see below |

The SQL files are not declared: they are the module's `data/sql/db-world` and
`data/sql/db-characters` folders, applied by the core updater on the next
start. When `Updates.EnableDatabases` in `worldserver.conf` disables the
updater for a database, the installer applies them itself. The updater
records files by name only: prefix every SQL file name with the module name.

The AzerothCore module loader must be named after the folder:
`Add<module, with - replaced by _>Scripts`.

### configuration

```json
"configuration": {
  "file": "attriboost.conf",
  "template": "conf/attriboost.conf.dist",
  "values": { "Attriboost.Enable": "1" }
}
```

`template` is copied as is into `configs/modules/<file>.dist`, and into
`configs/modules/<file>` with each setting of `values` replaced (each must
exist in the template).

### lua

```json
"lua": {
  "folder": "Attriboost",
  "files": ["data/lua/Attriboost_Serveur.lua", "data/lua/Attriboost_Client.lua"],
  "config_path": { "file": "Attriboost_Serveur.lua", "variable": "CONF" }
}
```

The files go into `<scripts>/<folder>`, where `<scripts>` is `ALE.ScriptPath`
of `mod_ale.conf` (or `Eluna.ScriptPath` of `mod_eluna.conf`), `lua_scripts`
by default. With `config_path`, the line `local CONF = "..."` of that file
receives the path of the module's `.conf`, relative to the worldserver folder.

On removal, files with these names are removed wherever they are under
`<scripts>`; the folder is removed if nothing else is left in it.

### dbc

One entry per DBC file:

| Key | Content |
|---|---|
| `file` | file name, e.g. `"Spell.dbc"` (`DBFilesClient\Spell.dbc` in the game) |
| `fields` | number of fields; a file with another count stops the installer (unexpected client version) |
| `text_fields` | indices of the string fields, or `[first, last]` ranges |
| `client` | `true`: the rows of `rows`; a package path: a reduced DBC that holds only the module's rows; `false` or absent: the game is not touched |
| `server` | same, for the server file in `<DataDir>/dbc` |
| `rows` | with `true`: one row per element, either an object `{"index": value}` whose missing fields are 0 or the empty string, or a full list; field 0 is the identifier |

`text_fields` must list **every** string field of the file, used by the
module or not: rows are compared by content, strings as text, and a string
field read as a number would never match.

On install, the server file gets the rows appended. On the game side, the file
is read from the archive the game reads it from and rewritten, rows appended,
into that archive if it is a custom one, otherwise into the last custom
archive read, if the game reads it after (a new `Data\patch-Z.MPQ`
otherwise). On removal, the
rows go, and so do the strings the install appended at the end of the file.

### game_files

```json
"game_files": {
  "sources": ["data/art"],
  "owned_folders": ["Interface/Attriboost"]
}
```

`sources`: package folders whose tree is the game's tree
(`data/art/Interface/Attriboost/x.blp` is `Interface\Attriboost\x.blp`). The
files are written into the last custom archive read (a new
`Data\patch-Z.MPQ` when there is none). A file that archive
already holds is left alone and is not the module's.

`extensions` (optional): only the files of `sources` with these extensions
are written (`[".blp", ".m2"]`); previews or notes kept beside them stay out.

`owned_folders`: game folders (at least two levels) that only the module
uses: whatever a custom archive holds in them is the module's.

### addons

```json
"addons": ["data/addon/ForeverUI"]
```

Package folders copied as they are into `Interface\AddOns` of the game folder
(`Interface\AddOns\ForeverUI`); each holds the `.toc` named after it. On
removal the folder is deleted.

### Package without server module

With `"server_module": false`, the package is for the game only: the
installer writes its game files and its addons, and adds its DBC rows (game
side, and server side for the entries whose `server` is set). Nothing goes into
the server's sources, configuration, Lua scripts or databases, no SQL is run,
and the server needs no rebuild; the sources folder and `mysql.exe` are not
asked. `signature`, `exclude_from_sources`, `configuration`, `lua` and
`database` are refused. The worldserver folder is still asked: it gives the
server DBC folder, and nothing is written while the worldserver runs.

### database

```json
"database": {
  "characters": {
    "before": [{ "if_column": "attriboost_attributes.talentpoints", "sql": "UPDATE characters c JOIN ..." }],
    "tables": ["attriboost_attributes"],
    "rows": [{ "table": "character_aura", "where": "spell IN ({ids:Spell.dbc})" },
             { "table": "updates", "where": "name IN ({sql_files:db-characters})" }]
  },
  "world": {
    "rows": [{ "table": "spell_dbc", "where": "ID IN ({ids:Spell.dbc})" }]
  }
}
```

| Key | Content |
|---|---|
| `tables` | tables that belong to the module: dropped on removal |
| `rows` | rows of shared tables: deleted on removal (`DELETE FROM <table> WHERE <where>`) |
| `before` | statements run before the deletions, each only if the column `if_column` exists; e.g. giving back points before the table that counts them is dropped |

Order on removal: `characters`, then `world`; in each, `before`, `rows`,
`tables`. Tables that do not exist are skipped.

Placeholders in `where` and `sql`:

| Placeholder | Becomes |
|---|---|
| `{ids:File.dbc}` | the identifiers of that `dbc` entry, client and server, comma-separated |
| `{sql_files:db-world}` | the quoted names of every `.sql` file under `data/sql/db-world` (the names the updater records in `updates`); same for `db-characters` |

An empty list becomes `NULL`.

## Presence, conflicts, receipts

What proves the module is there, and what only carries its identifiers:

| Proves the module is there | Carries its identifiers without proof |
|---|---|
| a folder of `modules/` named `module` or holding every `signature` file | |
| its `.conf` or `.conf.dist`; its Lua files; its Lua folder holding nothing else | |
| a server DBC row identical to the module's | a server DBC row with the same identifier and other content |
| a receipt in a custom archive | |
| a client DBC row identical to the module's, or named by the receipt | a client DBC row with the same identifier and other content (Blizzard's rows included) |
| a game file named by the receipt, or under an owned folder | a game file the game reads, from a custom archive, in another version |
| an addon folder of the module in `Interface\AddOns` | |
| a backup | |
| a module table; a row of `updates` | a row of another shared table |

Any proof: the run removes everything that is the module's, shared-table rows
included; rows and files that only carry its identifiers stay. Nothing but
identifiers: conflict, no install; the user may declare them leftovers, and
the database rows and DBC rows go (game files never do).

In each archive it writes to, the installer leaves a receipt,
`WoW-mods\<module>.receipt`, listing what it put there (`file <name>`,
`dbc <File.dbc> <ids>`). An archive left holding only DBC files identical to
the ones the game would read without it is deleted.
