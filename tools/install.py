# -*- coding: utf-8 -*-
# This file is part of mod-spheregrid.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

"""Installs mod-spheregrid into a server, and says everything it does.

    python tools/install.py --server <server dir> --core <azerothcore dir>
                            [--client <client Data dir>] [--locale enUS]
                            [--backup vault|beside] [--survey] [--dry-run]

`--server` is the directory holding `worldserver.exe`, `configs/` and
`lua_scripts/`. `--core` is the AzerothCore source tree, the one with a
`modules/` folder: the module's sources go there and the operator rebuilds.

WHAT IT DOES, IN ORDER

  1. SURVEY   reads which identifiers the target already uses -- in the
              server's DBC files and, if a client is given, inside its
              archives -- and compares them with the module's own.
  2. BACKUP   copies aside every file it is about to write, and dumps every
              table it is about to change. Nothing is written before this.
  3. PLACE    the sources, the interface and the configuration.
  4. SQL      the world files, then the characters files, in order.

`--survey` stops after the first step: it reads and reports, and writes
nothing at all. `--dry-run` goes through every step announcing what it would
do, and writes nothing either.

  5. CLIENT   when one is given: merges the module's DBC rows into the
              client's own files and writes them, with whatever art the module
              ships, into a new `patch-Z.MPQ`. Nothing existing is rewritten,
              and deleting that one archive undoes all of it.

WHAT IT DOES NOT DO YET

  Shift identifiers. If the survey finds one taken, it stops rather than
  guessing. On a stock server and a stock client nothing of the module's is
  taken, so that path is the exception -- but it is not written.

  Merge `FrameXML.toc` and `PetActionBarFrame.lua`. Those are the client's own
  files, and a module must not overwrite them.
"""
import argparse
import io
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = os.path.normpath(os.path.join(HERE, os.pardir))
sys.path.insert(0, HERE)
from spheregrid import backup as backup_lib
from spheregrid import dbc, mpq

# Which of the module's DBC files answers for which of the client's.
OURS = {
    "spheregrid_Spell.dbc": "Spell.dbc",
    "spheregrid_Item.dbc": "Item.dbc",
    "spheregrid_CreatureDisplayInfo.dbc": "CreatureDisplayInfo.dbc",
    "spheregrid_CreatureModelData.dbc": "CreatureModelData.dbc",
    "spheregrid_SpellIcon.dbc": "SpellIcon.dbc",
    "spheregrid_ItemDisplayInfo.dbc": "ItemDisplayInfo.dbc",
    # The visual chain. A server reads none of these -- they are what makes a
    # spell look like something, and that happens only on a client.
    "spheregrid_SpellVisual.dbc": "SpellVisual.dbc",
    "spheregrid_SpellVisualKit.dbc": "SpellVisualKit.dbc",
    "spheregrid_SpellVisualEffectName.dbc": "SpellVisualEffectName.dbc",
    "spheregrid_SoundEntries.dbc": "SoundEntries.dbc",
    "spheregrid_SpellDuration.dbc": "SpellDuration.dbc",
    # The animations the module's own scripts play, and the display its gate
    # wears -- a copy of one of the game's, under an identifier of ours.
    "spheregrid_Emotes.dbc": "Emotes.dbc",
    "spheregrid_GameObjectDisplayInfo.dbc": "GameObjectDisplayInfo.dbc",
}

# The tables the module writes into, and which must be kept before it does.
# The six of its own in the world database, the four in characters, and the
# shared ones it adds rows to -- `spell_ranks` above all, where it does more
# than add: it gives eighteen of the game's own spells a rank chain they did
# not have, and no range of identifiers could say what was there before.
TABLES = {
    "world": [
        "command", "creature_model_info", "creature_template",
        "creature_template_locale", "creature_template_model",
        "gameobject_template", "gameobject_template_locale",
        "item_dbc", "item_template", "item_template_locale",
        "module_string", "module_string_locale",
        "spell_bonus_data", "spell_custom_attr", "spell_dbc",
        "spell_ranks", "spell_script_names",
    ],
    "characters": [],
}

MYSQL_GUESSES = [
    r"C:\Program Files\MySQL\MySQL Server 8.4\bin",
    r"C:\Program Files\MySQL\MySQL Server 8.0\bin",
    r"C:\Program Files\MariaDB 10.6\bin",
    r"C:\xampp\mysql\bin",
]


# ---------------------------------------------------------------- the target

class Target(object):
    """A server, read from its own configuration."""

    def __init__(self, server_dir, core_dir, mysql_dir=None):
        self.server = os.path.abspath(server_dir)
        self.core = os.path.abspath(core_dir)
        self.conf = os.path.join(self.server, "configs", "worldserver.conf")
        if not os.path.isfile(self.conf):
            self.conf += ".dist"
        if not os.path.isfile(self.conf):
            raise SystemExit("no worldserver.conf under %s"
                             % os.path.join(self.server, "configs"))
        self.databases = self._read_databases()
        self.mysql, self.mysqldump = self._find_mysql(mysql_dir)

    def _read_databases(self):
        """The three connections, as the server itself declares them."""
        wanted = {"LoginDatabaseInfo": "auth",
                  "WorldDatabaseInfo": "world",
                  "CharacterDatabaseInfo": "characters"}
        out = {}
        for line in open(self.conf, encoding="utf-8", errors="replace"):
            key = line.split("=")[0].strip()
            if key in wanted and '"' in line:
                host, port, user, password, name = line.split('"')[1].split(";")
                out[wanted[key]] = dict(host=host, port=port, user=user,
                                        password=password, name=name)
        missing = set(wanted.values()) - set(out)
        if missing:
            raise SystemExit("%s says nothing about: %s"
                             % (self.conf, ", ".join(sorted(missing))))
        return out

    @staticmethod
    def _find_mysql(given):
        folders = ([given] if given else []) + MYSQL_GUESSES
        for folder in folders:
            client = os.path.join(folder, "mysql.exe")
            dump = os.path.join(folder, "mysqldump.exe")
            if os.path.isfile(client) and os.path.isfile(dump):
                return client, dump
        for name in ("mysql", "mysqldump"):
            if shutil.which(name) is None:
                raise SystemExit("mysql client not found -- pass --mysql <dir>")
        return shutil.which("mysql"), shutil.which("mysqldump")

    def run_sql(self, which, source=None, statement=None):
        """Feeds a file or a statement to one of the databases."""
        info = self.databases[which]
        command = [self.mysql, "-h", info["host"], "-P", info["port"],
                   "-u", info["user"], "--default-character-set=utf8mb4",
                   info["name"]]
        environment = dict(os.environ, MYSQL_PWD=info["password"])
        if source:
            with open(source, "rb") as handle:
                done = subprocess.run(command, stdin=handle, env=environment,
                                      stderr=subprocess.PIPE)
        else:
            done = subprocess.run(command, input=statement.encode("utf-8"),
                                  env=environment, stderr=subprocess.PIPE,
                                  stdout=subprocess.PIPE)
        if done.returncode:
            raise SystemExit(done.stderr.decode("utf-8", "replace")[:600])
        return (done.stdout or b"").decode("utf-8")

    def dump(self, which, tables, path):
        info = self.databases[which]
        present = self.existing_tables(which)
        here = [t for t in tables if t in present]
        if not here:
            open(path, "w").close()      # naming none would dump the WHOLE base
            return []
        command = [self.mysqldump, "-h", info["host"], "-P", info["port"],
                   "-u", info["user"], "--default-character-set=utf8mb4",
                   "--single-transaction", "--no-tablespaces",
                   "--add-drop-table", info["name"]] + here
        with open(path, "wb") as out:
            done = subprocess.run(command, stdout=out, stderr=subprocess.PIPE,
                                  env=dict(os.environ, MYSQL_PWD=info["password"]))
        if done.returncode:
            raise SystemExit(done.stderr.decode("utf-8", "replace")[:600])
        return here

    def existing_tables(self, which):
        info = self.databases[which]
        answer = self.run_sql(which, statement=(
            "SELECT TABLE_NAME FROM information_schema.TABLES "
            "WHERE TABLE_SCHEMA = '%s';" % info["name"]))
        return set(answer.split())

    # where things go
    @property
    def module_dir(self):
        return os.path.join(self.core, "modules", "mod-spheregrid")

    @property
    def lua_dir(self):
        return os.path.join(self.server, "lua_scripts", "SphereGrid")

    @property
    def conf_dir(self):
        return os.path.join(self.server, "configs", "modules")

    @property
    def dbc_dir(self):
        return os.path.join(self.server, "Data", "dbc")


# WHAT THE WORLD DATABASE MUST NOT ALREADY HOLD. A DBC file is one place an
# identifier can be taken; the tables the module writes into are the other,
# and the one where two modules meet. Each family: the tables, and the column
# that is the key.
DB_KEYS = {
    "spells": (("spell_dbc", "ID"),),
    "items": (("item_template", "entry"), ("item_dbc", "ID")),
    "templates": (("creature_template", "entry"), ("gameobject_template", "entry")),
    "displays": (("creature_model_info", "DisplayID"),
                 ("creaturedisplayinfo_dbc", "ID"), ("creaturemodeldata_dbc", "ID")),
}


def module_ids(family):
    """The identifiers the module ships for that family, from its own DBC."""
    import shift as shifting
    low, high = shifting.current_ranges()[family]
    out = set()
    folder = os.path.join(MODULE, "data", "dbc")
    for mine, theirs in OURS.items():
        path = os.path.join(folder, mine)
        if theirs in shifting.FAMILIES[family]["tables"] and os.path.isfile(path):
            out |= {i for i in dbc.read(path).ids() if low <= i <= high}
    return out


def ours_in_database(target, table, ids):
    """Which of those rows the module itself wrote, on an earlier install.

    A row at one of our identifiers is a clash only if it is NOT ours. The
    module's own rows are known by what they say of themselves: a spell by
    its English name, an item by its name, a creature or an object by its
    script. Tables with nothing to say are left to the DBC checks.
    """
    if not ids:
        return set()
    listed = ", ".join(str(i) for i in sorted(ids))
    folder = os.path.join(MODULE, "data", "dbc")
    if table == "spell_dbc":
        mine = dbc.read(os.path.join(folder, "spheregrid_Spell.dbc"))
        names = {mine.field(r, 0): dbc.read_string(mine, r, 136)
                 for r in mine.records}
        rows = target.run_sql("world", statement=(
            "SELECT ID, Name_Lang_enUS FROM spell_dbc WHERE ID IN (%s)" % listed))
        out = set()
        for line in rows.splitlines():
            parts = line.split("\t", 1)
            if len(parts) == 2 and parts[0].isdigit() and names.get(int(parts[0])) == parts[1]:
                out.add(int(parts[0]))
        return out
    if table == "item_template":
        from spheregrid import sqlrows
        # Every world file: the stones come from one, the runes from another.
        names = {}
        world = os.path.join(MODULE, "data", "sql", "world")
        for name in sorted(os.listdir(world)):
            if not name.endswith(".sql"):
                continue
            for columns, values in sqlrows.insertions(
                    os.path.join(world, name), "item_template"):
                if "entry" not in columns or "name" not in columns:
                    continue
                at, name_at = columns.index("entry"), columns.index("name")
                for row in values:
                    if str(row[at]).isdigit():
                        names[int(row[at])] = row[name_at]
        rows = target.run_sql("world", statement=(
            "SELECT entry, name FROM item_template WHERE entry IN (%s)" % listed))
        out = set()
        for line in rows.splitlines():
            parts = line.split("\t", 1)
            if len(parts) == 2 and parts[0].isdigit() and names.get(int(parts[0])) == parts[1]:
                out.add(int(parts[0]))
        return out
    if table in ("creature_template", "gameobject_template"):
        rows = target.run_sql("world", statement=(
            "SELECT entry FROM %s WHERE entry IN (%s) AND "
            "(ScriptName LIKE '%%spheregrid%%' OR AIName = 'NullCreatureAI' "
            "OR name IN ('Death Tunnel', 'Halo', 'Star', 'Barrier'))"
            % (table, listed)) if table == "creature_template" else (
            "SELECT entry FROM %s WHERE entry IN (%s) AND "
            "ScriptName LIKE '%%spheregrid%%'" % (table, listed)))
        return {int(v) for v in rows.split() if v.isdigit()}
    # item_dbc and the display tables: the module's own rows are exactly the
    # identifiers it ships, and nothing else writes at those numbers without
    # also clashing in a DBC file, where it is caught.
    return set(ids)


def taken_in_database(target, family):
    """Which of the module's identifiers the world database already holds,
    NOT counting the rows the module itself wrote on an earlier install."""
    import shift as shifting
    low, high = shifting.current_ranges()[family]
    out = {}
    present = target.existing_tables("world")
    for table, column in DB_KEYS.get(family, ()):
        if table not in present:
            continue
        rows = target.run_sql("world", statement=(
            "SELECT `%s` FROM `%s` WHERE `%s` BETWEEN %d AND %d"
            % (column, table, column, low, high)))
        found = {int(v) for v in rows.split() if v.isdigit()}
        found -= ours_in_database(target, table, found & module_ids(family))
        if found:
            out[table] = found
    return out


# ---------------------------------------------------------------- the survey

# THE ARCHIVE THIS INSTALLER WRITES. It is not the client's: it is what a
# previous run left, and what this one is about to replace. Reading the chain
# with it would show every identifier taken -- by us -- and would fold the
# module's rows into a file that already holds them.
ARCHIVE = "patch-Z.MPQ"
# A file the installer writes INSIDE the archive, so the archive can be told
# from another server's whatever identifiers the module carries at the time.
MARK = r"SphereGrid\module.txt"


def is_ours(path):
    """Whether an archive named like ours IS ours.

    The module's archive carries the module's DBC rows: Spell.dbc with one of
    the module's own spells in it. An archive of that name WITHOUT them is
    somebody else's -- a server's whole patch, perhaps gigabytes of it -- and
    must not be written over.
    """
    try:
        archive = mpq.Archive(path)
    except Exception:
        return False
    try:
        if archive.has(MARK):
            return True
        # Archives written before the mark existed: one of our spells is in it.
        if not archive.has(r"DBFilesClient\Spell.dbc"):
            return False
        raw = archive.read(r"DBFilesClient\Spell.dbc")
        import tempfile
        handle = tempfile.NamedTemporaryFile(suffix=".dbc", delete=False)
        handle.write(raw)
        handle.close()
        try:
            ids = set(dbc.read(handle.name).ids())
        finally:
            os.unlink(handle.name)
        mine = dbc.read(os.path.join(MODULE, "data", "dbc", "spheregrid_Spell.dbc"))
        return bool(ids & set(mine.ids()))
    finally:
        archive.close()


def foreign_archive(client_dir):
    """The path of an archive of our name that is not ours, or None."""
    for name in os.listdir(client_dir):
        if name.lower() == ARCHIVE.lower():
            path = os.path.join(client_dir, name)
            return None if is_ours(path) else path
    return None


def read_client(client_dir, locale):
    """The client's archives, WITHOUT the module's own.

    Returns the chain and whether one of ours was set aside, so the caller can
    say so: an operator reinstalling deserves to know his previous archive was
    ignored rather than merged into.
    """
    before = mpq.open_client(client_dir, locale=locale)
    mine = any(os.path.basename(a.path).lower() == ARCHIVE.lower()
               for a in before.archives)
    before.close()
    return mpq.open_client(client_dir, locale=locale, ignore=(ARCHIVE,)), mine


def survey(target, client_dir, locale):
    """What the target already uses, against what the module needs."""
    print("SURVEY")
    ours = {}
    folder = os.path.join(MODULE, "data", "dbc")
    for mine, theirs in sorted(OURS.items()):
        path = os.path.join(folder, mine)
        if os.path.isfile(path):
            ours[theirs] = set(dbc.read(path).ids())

    clashes = {}
    taken_by = {}          # what each table holds, for a shift to steer clear of
    print("  the server's own DBC files:")
    for name, wanted in sorted(ours.items()):
        path = os.path.join(target.dbc_dir, name)
        if not os.path.isfile(path):
            print("    %-26s not there -- nothing to clash with" % name)
            continue
        taken = set(dbc.read(path).ids())
        taken_by.setdefault(name, set()).update(taken)
        hit = taken & wanted
        clashes.setdefault(name, set()).update(hit)
        print("    %-26s %6d rows, %d of ours already taken"
              % (name, len(taken), len(hit)))

    # The world database: the tables the module writes into, and where another
    # module would already have written.
    import shift as shifting
    print("  the world database:")
    for family in sorted(DB_KEYS):
        mine = module_ids(family)
        for table, found in sorted(taken_in_database(target, family).items()):
            taken_by.setdefault(table, set()).update(found)
            hit = found & mine
            clashes.setdefault(table, set()).update(hit)
            print("    %-26s %6d of the range in use, %d of ours already taken"
                  % (table, len(found), len(hit)))

    if client_dir:
        print("  the client's archives:")
        stranger = foreign_archive(client_dir)
        if stranger:
            print("    %s IS NOT OURS: it carries none of the module's rows."
                  % os.path.basename(stranger))
            print("    On Windows it is the file this installer would write "
                  "over. Move it, or install into another client.")
            clashes.setdefault(ARCHIVE, set()).add(0)
            return clashes
        chain, mine = read_client(client_dir, locale)
        print("    %d archive(s), %s answers last"
              % (len(chain.archives),
                 os.path.basename(chain.archives[-1].path)))
        if mine:
            print("    %s is ours, from an earlier run: set aside" % ARCHIVE)
        import tempfile
        for name, wanted in sorted(ours.items()):
            try:
                raw = chain.read(r"DBFilesClient\%s" % name)
            except (KeyError, NotImplementedError) as problem:
                print("    %-26s unreadable: %s" % (name, problem))
                continue
            handle = tempfile.NamedTemporaryFile(suffix=".dbc", delete=False)
            handle.write(raw)
            handle.close()
            taken = set(dbc.read(handle.name).ids())
            os.unlink(handle.name)
            taken_by.setdefault(name, set()).update(taken)
            hit = taken & wanted
            clashes.setdefault(name, set()).update(hit)
            print("    %-26s %6d rows, %d of ours already taken"
                  % (name, len(taken), len(hit)))
        chain.close()
    else:
        print("  no client given -- its archives were not read")

    # AIO is not installed here, but its absence is the first question every
    # issue would ask: the interface is sent over it, and without it no window
    # ever opens. Say now what will be missing later.
    aio = os.path.join(os.path.dirname(target.lua_dir), "AIO_Server")
    print("  AIO on the server: %s" % (
        "found (lua_scripts/AIO_Server)" if os.path.isdir(aio)
        else "NOT FOUND -- install it on both sides, or no window opens"))

    total = sum(len(v) for v in clashes.values())
    if total:
        print("  %d IDENTIFIER(S) ARE TAKEN." % total)
    else:
        print("  every identifier the module needs is free.")
    survey.taken_by = taken_by
    return clashes


# ----------------------------------------------------------------- the shift

def families_in_clash(clashes):
    """Which families the taken identifiers belong to."""
    import shift as shifting
    out = set()
    ranges = shifting.current_ranges()
    for ids in clashes.values():
        for i in ids:
            for family, (low, high) in ranges.items():
                if low <= i <= high:
                    out.add(family)
    return out


def free_offset(family, taken_by):
    """The smallest shift that puts the whole family on identifiers nobody
    holds -- in any DBC of the family and in any table of the world database.
    """
    import shift as shifting
    spec = shifting.FAMILIES[family]
    low, high = shifting.current_ranges()[family]
    mine = module_ids(family) or set(range(low, high + 1))
    busy = set()
    for table in spec["tables"]:
        busy |= taken_by.get(table, set())
    for table, _ in DB_KEYS.get(family, ()):
        busy |= taken_by.get(table, set())
    step = spec["size"]
    for k in range(1, 5000):
        by = k * step
        if all((i + by) not in busy for i in mine):
            return by
    raise SystemExit("no free block found for %s" % family)


def shift_module(clashes, dry_run):
    """Moves every family in clash, then says where things now are."""
    import shift as shifting
    taken_by = getattr(survey, "taken_by", {})
    print("SHIFT")
    for family in sorted(families_in_clash(clashes)):
        by = free_offset(family, taken_by)
        low, high = shifting.current_ranges()[family]
        print("  %-10s %d..%d is taken: moving by %+d"
              % (family, low, high, by))
        if not dry_run:
            shifting.FAMILIES[family]["low"], shifting.FAMILIES[family]["high"] = low, high
            shifting.shift(family, by, dry_run=False)
    if not dry_run:
        print("  the module's sources now carry the new identifiers: rebuild "
              "the core when the installer is done.")


# ----------------------------------------------------------------- the steps

def place(target, keeper, dry_run):
    """The sources, the interface and the configuration."""
    print("PLACE")
    jobs = [
        ("sources", MODULE, target.module_dir,
         {".git", "Backups", "__pycache__"}),
        ("interface", os.path.join(MODULE, "data", "lua", "SphereGrid"),
         target.lua_dir, set()),
    ]
    for what, source, destination, skip in jobs:
        count = 0
        for base, folders, names in os.walk(source):
            folders[:] = [d for d in folders if d not in skip]
            for name in names:
                origin = os.path.join(base, name)
                landing = os.path.join(destination,
                                       os.path.relpath(origin, source))
                if not dry_run:
                    keeper.keep(landing)
                    os.makedirs(os.path.dirname(landing), exist_ok=True)
                    shutil.copy2(origin, landing)
                count += 1
        print("  %-10s %4d file(s) -> %s" % (what, count, destination))

    source = os.path.join(MODULE, "conf", "mod-spheregrid.conf.dist")
    landing = os.path.join(target.conf_dir, "mod-spheregrid.conf")
    print("  %-10s %4d file(s) -> %s" % ("config", 1, landing))
    if not dry_run:
        keeper.keep(landing)
        os.makedirs(target.conf_dir, exist_ok=True)
        # A configuration already there is left alone: it holds an operator's
        # own numbers, and every one of them also has a built-in default.
        if not os.path.exists(landing):
            shutil.copy2(source, landing)
        else:
            print("             (kept: a configuration was already there)")


def patch_client(client_dir, locale, keeper, dry_run):
    """Builds the client's archive: the module's DBC rows, and its art.

    A client reads ONE Spell.dbc -- the one the highest archive answers with.
    So the archive written here does not hold the module's rows alone: it holds
    the client's own file WITH those rows merged in, which is the only shape
    the game can use.

    Nothing existing is rewritten. The archive is new, and named so that it is
    read after every other: what it says wins, and removing it undoes all of
    this in one gesture.
    """
    print("CLIENT")
    chain, mine = read_client(client_dir, locale)
    print("  %d archive(s) read, %s answers last"
          % (len(chain.archives), os.path.basename(chain.archives[-1].path)))
    if mine:
        print("  %s is ours, from an earlier run: set aside and rewritten"
              % ARCHIVE)

    import tempfile
    contents, merged_icons, known_icons = {}, None, None
    folder = os.path.join(MODULE, "data", "dbc")
    for mine, theirs in sorted(OURS.items()):
        path = os.path.join(folder, mine)
        if not os.path.isfile(path):
            continue
        ours = dbc.read(path)
        inside = r"DBFilesClient\%s" % theirs
        try:
            raw = chain.read(inside)
        except (KeyError, NotImplementedError) as problem:
            print("    %-26s SKIPPED, the client's own is unreadable: %s"
                  % (theirs, problem))
            continue
        handle = tempfile.NamedTemporaryFile(suffix=".dbc", delete=False)
        handle.write(raw)
        handle.close()
        theirs_dbc = dbc.read(handle.name)
        os.unlink(handle.name)

        # The string fields are worked out on the FULL file: a partial one
        # cannot prove the two that are empty in all of its rows.
        whole = dbc.concat([theirs_dbc, ours], dbc.string_fields(theirs_dbc))
        buffer = tempfile.NamedTemporaryFile(suffix=".dbc", delete=False)
        buffer.close()
        dbc.write(buffer.name, whole)
        contents[inside] = open(buffer.name, "rb").read()
        os.unlink(buffer.name)
        print("    %-26s %6d + %d = %d rows"
              % (theirs, len(theirs_dbc), len(ours), len(whole)))
        if theirs == "Spell.dbc":
            merged_icons = ours
        if theirs == "SpellIcon.dbc":
            known_icons = set(whole.ids())

    # Every icon a spell names must exist, or the client shows a blank square.
    # The check runs against what this archive WILL hold, not against what the
    # client holds now: otherwise it would report as missing the very rows
    # being added a few lines above.
    if merged_icons is not None and known_icons is not None:
        wanted = {merged_icons.field(r, 133) for r in merged_icons.records}
        wanted |= {merged_icons.field(r, 134) for r in merged_icons.records}
        missing = sorted(i for i in wanted - known_icons if i)
        if missing:
            print("    SpellIcon.dbc              %d icon(s) the module's "
                  "spells name will still be MISSING: %s%s"
                  % (len(missing), ", ".join(str(i) for i in missing[:8]),
                     " ..." if len(missing) > 8 else ""))
            print("                               those spells show a blank "
                  "square until the icons are supplied.")
        else:
            print("    SpellIcon.dbc              every icon the module's "
                  "spells name is accounted for")

    art = os.path.join(MODULE, "data", "art")
    if os.path.isdir(art):
        for base, _, names in os.walk(art):
            for name in names:
                full = os.path.join(base, name)
                inside = os.path.relpath(full, art).replace("/", "\\")
                contents[inside] = open(full, "rb").read()
        print("    art                        %d file(s)"
              % sum(1 for k in contents if not k.startswith("DBFilesClient")))
    else:
        print("    art                        none shipped (data/art is empty)")

    chain.close()
    # The mark, so that the next run knows this archive for ours.
    version = "unknown"
    changelog = os.path.join(MODULE, "CHANGELOG.md")
    if os.path.isfile(changelog):
        for line in io.open(changelog, encoding="utf-8", errors="replace"):
            if line.startswith("## "):
                version = line[3:].strip().split()[0]
                break
    contents[MARK] = ("mod-spheregrid %s\r\nwritten by tools/install.py: "
                      "the module's rows merged into this client's own DBC "
                      "files, and its art.\r\n" % version).encode("utf-8")
    landing = os.path.join(client_dir, ARCHIVE)
    print("  -> %s" % landing)
    if dry_run:
        print("     (dry run: not written)")
        return
    keeper.keep(landing)
    mpq.write_archive(landing, contents)
    print("     %.1f MB" % (os.path.getsize(landing) / 1048576.0))


def apply_sql(target, dry_run):
    print("SQL")
    for which in ("world", "characters"):
        folder = os.path.join(MODULE, "data", "sql", which)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".sql"):
                continue
            print("  %-12s %s" % (which, name))
            if not dry_run:
                target.run_sql(which, source=os.path.join(folder, name))


def take_backup(target, policy, dry_run):
    print("BACKUP")
    keeper = backup_lib.Backup(MODULE, policy=policy)
    if dry_run:
        print("  (dry run: nothing copied)")
        return keeper
    for which, tables in TABLES.items():
        if not tables:
            continue
        path = keeper.dump_path(target.databases[which]["name"])
        kept = target.dump(which, tables, path)
        keeper.keep_tables(path, target.databases[which]["name"], kept)
        print("  %-12s %2d table(s) -> %.1f MB"
              % (which, len(kept), os.path.getsize(path) / 1048576.0))
    # The module's own tables do not need dumping: they do not exist yet on a
    # server that has never had it, and on one that has, the SQL rebuilds them.
    return keeper


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--server", required=True,
                        help="the directory holding worldserver.exe")
    parser.add_argument("--core", required=True,
                        help="the AzerothCore source tree, with its modules/")
    parser.add_argument("--client", help="a client's Data directory")
    parser.add_argument("--locale", default="enUS")
    parser.add_argument("--backup", default=backup_lib.VAULT,
                        choices=[backup_lib.VAULT, backup_lib.BESIDE])
    parser.add_argument("--mysql", help="the folder holding mysql.exe")
    parser.add_argument("--shift", action="store_true",
                        help="when an identifier is taken, move the module's "
                             "own out of the way instead of stopping")
    parser.add_argument("--survey", action="store_true",
                        help="read and report, write nothing")
    parser.add_argument("--dry-run", action="store_true",
                        help="announce every step, write nothing")
    args = parser.parse_args()

    target = Target(args.server, args.core, args.mysql)
    print("mod-spheregrid")
    print("  server   %s" % target.server)
    print("  core     %s" % target.core)
    print("  world    %s" % target.databases["world"]["name"])
    print("  client   %s" % (args.client or "not given"))
    print()

    clashes = survey(target, args.client, args.locale)
    if any(clashes.values()):
        if not args.shift:
            print("  Stopping. Run again with --shift to move the module's own "
                  "identifiers out of the way, or free them on this server.")
            return 2
        shift_module(clashes, args.dry_run)
        if not args.dry_run:
            clashes = survey(target, args.client, args.locale)
            if any(clashes.values()):
                print("  Still taken after the shift: stopping.")
                return 2
    if args.survey:
        return 0
    if any(clashes.values()):
        raise SystemExit(1)

    print()
    keeper = take_backup(target, args.backup, args.dry_run)
    print()
    place(target, keeper, args.dry_run)
    print()
    apply_sql(target, args.dry_run)
    if args.client:
        print()
        patch_client(args.client, args.locale, keeper, args.dry_run)

    if not args.dry_run:
        receipt = keeper.write_receipt("install")
        print()
        print("BACKUP: %s" % keeper.describe())
        print("  receipt %s" % receipt)
        print()
        print("Rebuild the core so the module is compiled in, then start the "
              "server.")


if __name__ == "__main__":
    main()
