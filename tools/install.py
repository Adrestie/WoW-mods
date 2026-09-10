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
                            --client <client Data dir> | --no-client
                            [--locale enUS] [--backup vault|beside]
                            [--survey] [--dry-run]
    python tools/install.py --client-only --client <client Data dir>

`--server` is the directory holding `worldserver.exe`, `configs/` and
`lua_scripts/`. `--core` is the AzerothCore source tree, the one with a
`modules/` folder: the module's sources go there and the operator rebuilds.

A CLIENT IS NOT OPTIONAL. The module's spells exist in no client: without its
rows a player sees no name, no icon and no effect, and cannot cast them. So
`--client` is asked for, and the only way past it is to SAY so with
`--no-client` -- for a server that has no client on it, which is most Linux
ones. That server's operator then patches a client of his own, on the machine
where it lives, with `--client-only`: that mode needs no server and touches
no database.

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
              ships, into `patch-Z.MPQ` -- a NEW archive holding only that when
              the client has none, or INTO the client's own when it already
              has one. In the second case each file it replaces is copied
              aside first, nothing else in the archive moves, and the archive
              keeps a record of what the module put in it.

WHEN THE MODULE IS ALREADY THERE -- its sources under modules/, its
interface, its configuration, its tables in the world database, or its rows in
the client's archive -- the installer does not install: it says what it found
and REMOVES the module instead, with `--keep-characters` or
`--drop-characters` saying what becomes of what players earned. To update the
module, remove it, then install it again. `--presence` only asks the question:
exit code 3 when the module is there, 0 when it is not, nothing written.

`--shift` allows the survey's answer to be acted on: when an identifier is
taken -- on the server, in its database, or in the client, the client's own
`patch-Z` included -- the module's own are moved out of the way, in every
file of the module, before anything is written. Without it the installer
stops and says what is taken.

WHAT IT DOES NOT DO

  Merge `FrameXML.toc` and `PetActionBarFrame.lua`. Those are the client's own
  files, and a module must not overwrite them.
"""
import argparse
import io
import json
import os
import re
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
    "spheregrid_SpellChainEffects.dbc": "SpellChainEffects.dbc",
    # WHICH TAB A SPELL SITS IN. The spell book does not read the class from
    # Spell.dbc: it reads the SKILL LINE a spell is tied to, and a spell no
    # line names falls into "General". One row per spell the module can teach
    # -- the forty-one of its cells and the four hundred and ninety-two ranks
    # its runes grant.
    "spheregrid_SkillLineAbility.dbc": "SkillLineAbility.dbc",
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


def module_ids(family, root=None):
    """The identifiers the module ships for that family, from its own DBC.

    `root` is the copy being installed once there is one: after a shift its
    rows carry the new numbers, and the checkout still carries the old.
    """
    import shift as shifting
    low, high = shifting.current_ranges()[family]
    out = set()
    folder = os.path.join(root or MODULE, "data", "dbc")
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

# THE ARCHIVE THIS INSTALLER WRITES. `patch-Z` is read after every other
# archive of the client, so what it says wins. When the client has no such
# file the installer creates one holding only what the module adds -- the
# module's OWN archive, set aside and rewritten by every later run, deleted
# whole by the uninstaller. When the client already has one -- another
# server's whole patch, perhaps gigabytes of it -- the module's rows are
# merged INTO its files and written back into it: the archive is SHARED, it
# stays the client's, and what the module replaced was copied aside first.
ARCHIVE = "patch-Z.MPQ"
# Two files the installer writes inside the archive: a line for people, and a
# record for the tools -- which kind of archive this is, and what the module
# put in it, row by row and file by file. The record is what lets a later run
# tell the module's earlier rows from the client's, and what lets the
# uninstaller take exactly those out again.
MARK = r"SphereGrid\module.txt"
WRITTEN = r"SphereGrid\written.json"
OWN, SHARED = "own", "shared"


def dbc_from_bytes(raw):
    """A DBC read from an archive: the reader wants a path, so it gets one
    for as long as the read takes. Nothing is left on disk."""
    import tempfile
    handle = tempfile.NamedTemporaryFile(suffix=".dbc", delete=False)
    handle.write(raw)
    handle.close()
    try:
        return dbc.read(handle.name)
    finally:
        os.unlink(handle.name)


def dbc_to_bytes(table):
    """The bytes of a DBC, written the same way and kept nowhere."""
    import tempfile
    handle = tempfile.NamedTemporaryFile(suffix=".dbc", delete=False)
    handle.close()
    try:
        dbc.write(handle.name, table)
        with open(handle.name, "rb") as f:
            return f.read()
    finally:
        os.unlink(handle.name)


def written_record(archive):
    """What the module wrote into an open archive, or None if nothing.

    An archive with the record is read from it. One with the mark but no
    record was written by an installer older than the record, when the only
    kind was the module's own. One with neither carries nothing of ours,
    whatever identifiers it holds: a server's patch that happens to use the
    module's ranges is a clash for the survey to find, not an archive to
    claim.
    """
    if archive.has(WRITTEN):
        return json.loads(archive.read(WRITTEN).decode("utf-8"))
    if archive.has(MARK):
        return {"kind": OWN, "version": "unknown", "dbc": {},
                "added": [], "replaced": []}
    return None


def written_record_at(path):
    try:
        archive = mpq.Archive(path)
    except Exception:
        return None
    try:
        return written_record(archive)
    finally:
        archive.close()


def archive_kind(path):
    """OWN, SHARED, or None for an archive that carries nothing of ours."""
    record = written_record_at(path)
    return record["kind"] if record else None


def is_ours(path):
    return archive_kind(path) == OWN


def top_archive(client_dir):
    """The client's file named like ARCHIVE, in whatever case, or None."""
    for name in os.listdir(client_dir):
        if name.lower() == ARCHIVE.lower():
            return os.path.join(client_dir, name)
    return None


class ClientView(object):
    """A client's archives, and what its `patch-Z` is to the module.

    `chain` is the archives in reading order. `top` is the path of the file
    named like ARCHIVE, or None. `kind` says what that file is: None for no
    file or the client's own untouched, OWN for the module's, SHARED for the
    client's with the module written into it. `record` is what an earlier run
    wrote there, or None.

    The module's OWN archive is left out of the chain: it holds nothing but
    what this run is about to write again, and reading it would show every
    identifier taken -- by us. A SHARED one is the client's, and is read like
    any other: its rows are the client's, minus those the record says are the
    module's.
    """

    def __init__(self, client_dir, locale):
        self.top = top_archive(client_dir)
        self.record = written_record_at(self.top) if self.top else None
        self.kind = self.record["kind"] if self.record else None
        ignore = (ARCHIVE,) if self.kind == OWN else ()
        self.chain = mpq.open_client(client_dir, locale=locale, ignore=ignore)

    def earlier(self, inside):
        """The identifiers an earlier run put into this DBC of the client."""
        if self.kind != SHARED:
            return set()
        return set(self.record.get("dbc", {}).get(inside, ()))

    def describe(self):
        base = os.path.basename(self.top) if self.top else ARCHIVE
        if self.kind == OWN:
            return "%s is the module's own, from an earlier run: set aside" % base
        if self.kind == SHARED:
            return ("%s is the client's own, with mod-spheregrid %s written "
                    "into it earlier: those rows are the module's, not taken"
                    % (base, self.record.get("version", "?")))
        if self.top:
            return ("%s is the client's own: the module will be written INTO "
                    "it, each file it replaces copied aside first" % base)
        return "no %s: the module's own will be created" % ARCHIVE

    def close(self):
        self.chain.close()


def read_client(client_dir, locale):
    return ClientView(client_dir, locale)


def survey(target, client_dir, locale, root=None):
    """What the target already uses, against what the module needs."""
    print("SURVEY")
    ours = {}
    folder = os.path.join(root or MODULE, "data", "dbc")
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
        mine = module_ids(family, root)
        for table, found in sorted(taken_in_database(target, family).items()):
            taken_by.setdefault(table, set()).update(found)
            hit = found & mine
            clashes.setdefault(table, set()).update(hit)
            print("    %-26s %6d of the range in use, %d of ours already taken"
                  % (table, len(found), len(hit)))

    if client_dir:
        print("  the client's archives:")
        view = read_client(client_dir, locale)
        chain = view.chain
        print("    %d archive(s), %s answers last"
              % (len(chain.archives),
                 os.path.basename(chain.archives[-1].path)))
        print("    %s" % view.describe())
        for name, wanted in sorted(ours.items()):
            inside = r"DBFilesClient\%s" % name
            try:
                raw = chain.read(inside)
            except (KeyError, NotImplementedError) as problem:
                print("    %-26s unreadable: %s" % (name, problem))
                continue
            found = set(dbc_from_bytes(raw).ids())
            # Rows an earlier run of this installer put there are the
            # module's own: the next write takes them out before merging.
            earlier = found & view.earlier(inside)
            taken = found - earlier
            taken_by.setdefault(name, set()).update(taken)
            hit = taken & wanted
            clashes.setdefault(name, set()).update(hit)
            print("    %-26s %6d rows, %d of ours already taken%s"
                  % (name, len(found), len(hit),
                     ", %d of ours from the earlier run" % len(earlier)
                     if earlier else ""))
        view.close()
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


def free_offset(family, taken_by, root=None):
    """The smallest shift that puts the whole family on identifiers nobody
    holds -- in any DBC of the family and in any table of the world database.
    """
    import shift as shifting
    spec = shifting.FAMILIES[family]
    low, high = shifting.current_ranges()[family]
    mine = module_ids(family, root) or set(range(low, high + 1))
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


def shift_module(clashes, dry_run, root):
    """Moves every family in clash, IN THE COPY, then says where things are.

    `root` is the module as it was just laid in the core's `modules/` folder.
    Nothing here touches the checkout the installer was launched from: it
    keeps the numbers the module was written with, whatever a server demands.
    """
    import shift as shifting
    shifting.use(root)
    taken_by = getattr(survey, "taken_by", {})
    print("SHIFT")
    print("  in %s" % root)
    for family in sorted(families_in_clash(clashes)):
        by = free_offset(family, taken_by, root)
        low, high = shifting.current_ranges()[family]
        print("  %-10s %d..%d is taken: moving by %+d"
              % (family, low, high, by))
        if not dry_run:
            shifting.FAMILIES[family]["low"], shifting.FAMILIES[family]["high"] = low, high
            shifting.shift(family, by, dry_run=False)
    if not dry_run:
        print("  the copy now carries the new identifiers, and the module you "
              "installed from is untouched: rebuild the core when the "
              "installer is done.")


# --------------------------------------------------------------- presence

CREATE_TABLE = re.compile(r"CREATE TABLE(?: IF NOT EXISTS)? `(\w+)`")


def own_tables(which):
    """The tables the module creates in that database, from its own SQL."""
    out = set()
    folder = os.path.join(MODULE, "data", "sql", which)
    if not os.path.isdir(folder):
        return out
    for name in os.listdir(folder):
        if name.endswith(".sql"):
            text = io.open(os.path.join(folder, name), encoding="utf-8").read()
            out.update(CREATE_TABLE.findall(text))
    return out


def presence(target, client_dir):
    """What of the module is already on this target, place by place.

    Returns the list of (what, where) found, and the module's tables in the
    characters database, which count for nothing here: they are what players
    earned, and a removal told to keep them leaves them on purpose.
    """
    found = []
    if os.path.isdir(target.module_dir):
        found.append(("sources", target.module_dir))
    if os.path.isdir(target.lua_dir):
        found.append(("interface", target.lua_dir))
    conf = os.path.join(target.conf_dir, "mod-spheregrid.conf")
    if os.path.isfile(conf):
        found.append(("config", conf))
    tables = own_tables("world") & target.existing_tables("world")
    if tables:
        found.append(("world", "%d of the module's own tables in %s"
                      % (len(tables), target.databases["world"]["name"])))
    earned = own_tables("characters") & target.existing_tables("characters")
    if client_dir:
        top = top_archive(client_dir)
        kind = archive_kind(top) if top else None
        if kind == OWN:
            found.append(("client", "%s, the module's own archive" % top))
        elif kind == SHARED:
            found.append(("client", "%s, the client's archive with the "
                          "module written into it" % top))
    return found, earned


def report_presence(found, earned, target):
    print("PRESENCE")
    if not found:
        print("  the module is not installed here")
    for what, where in found:
        print("  %-11s %s" % (what, where))
    if earned:
        print("  %-11s %d of the module's tables in %s -- what players "
              "earned, kept from an earlier install"
              % ("characters", len(earned), target.databases["characters"]["name"]))


# ----------------------------------------------------------------- the steps

def place_sources(target, keeper, dry_run):
    """The module, copied into the core's `modules/` folder.

    THIS COMES FIRST, and what follows works on the copy: a shift rewrites
    identifiers in the module's own files, and it must never rewrite the ones
    the installer was launched from. Returns the folder everything else reads.
    """
    print("PLACE")
    return copy_tree(
        "sources", MODULE, target.module_dir,
        {".git", "Backups", "__pycache__"}, keeper, dry_run)


def place_interface(root, target, keeper, dry_run):
    """The interface and the configuration, taken FROM THE COPY."""
    copy_tree("interface", os.path.join(root, "data", "lua", "SphereGrid"),
              target.lua_dir, set(), keeper, dry_run)

    source = os.path.join(root, "conf", "mod-spheregrid.conf.dist")
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


def copy_tree(what, source, destination, skip, keeper, dry_run):
    """One folder onto another, every file kept aside before it is replaced."""
    count = 0
    for base, folders, names in os.walk(source):
        folders[:] = [d for d in folders if d not in skip]
        for name in names:
            origin = os.path.join(base, name)
            landing = os.path.join(destination, os.path.relpath(origin, source))
            if not dry_run:
                keeper.keep(landing)
                os.makedirs(os.path.dirname(landing), exist_ok=True)
                shutil.copy2(origin, landing)
            count += 1
    print("  %-10s %4d file(s) -> %s" % (what, count, destination))
    return destination


def patch_client(client_dir, locale, keeper, dry_run, root=None):
    """Writes the module into the client: its DBC rows merged into the
    client's own files, and its art.

    A client reads ONE Spell.dbc -- the one the highest archive answers with.
    So what is written is never the module's rows alone: it is the client's
    own file WITH those rows merged in, the only shape the game can use.

    Where it goes depends on what the client has. No `patch-Z`: a new archive
    is created holding only these files -- the module's OWN, set aside and
    rewritten by the next run, deleted whole by the uninstaller. A `patch-Z`
    that is the client's: the files are written INTO it. Each file the archive
    already holds is copied aside before it is replaced, the archive's other
    files are not moved, and a record inside the archive says which rows and
    which files came from the module -- so a later run knows to take its
    earlier rows out before merging again, and the uninstaller knows exactly
    what to remove. The identifiers were checked, and moved if need be, by the
    survey before this: nothing here decides them.
    """
    print("CLIENT")
    view = read_client(client_dir, locale)
    chain = view.chain
    print("  %d archive(s) read, %s answers last"
          % (len(chain.archives), os.path.basename(chain.archives[-1].path)))
    print("  %s" % view.describe())
    into = view.top if view.kind in (None, SHARED) and view.top else None
    have = None
    if into:
        have = next(a for a in chain.archives
                    if os.path.normcase(a.path) == os.path.normcase(into))

    contents, merged_icons, known_icons = {}, None, None
    written_dbc = {}
    folder = os.path.join(root or MODULE, "data", "dbc")
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
        theirs_dbc = dbc_from_bytes(raw)

        # The string fields are worked out on the FULL file: a partial one
        # cannot prove the two that are empty in all of its rows.
        strings_at = dbc.string_fields_of(theirs, theirs_dbc)
        # What an earlier run merged in comes out first, whatever identifiers
        # the module had then: the file goes back to the client's own rows,
        # and the module's current rows go in. A hand-edited file can also
        # hold the same identifier twice; the client keeps the one it read
        # last, and so does the merge -- it cannot keep both.
        found = list(theirs_dbc.ids())
        stale = set(found) & view.earlier(inside)
        if stale or len(set(found)) != len(found):
            theirs_dbc = dbc.subset(theirs_dbc, set(found) - stale, strings_at)
        whole = dbc.concat([theirs_dbc, ours], strings_at)
        contents[inside] = dbc_to_bytes(whole)
        written_dbc[inside] = sorted(ours.ids())
        notes = []
        if stale:
            notes.append("%d of the earlier run's taken out first" % len(stale))
        if len(set(found)) != len(found):
            notes.append("%d duplicate row(s) in the client's file, the last "
                         "of each kept" % (len(found) - len(set(found))))
        print("    %-26s %6d + %d = %d rows%s"
              % (theirs, len(theirs_dbc), len(ours), len(whole),
                 " (%s)" % "; ".join(notes) if notes else ""))
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

    art = os.path.join(root or MODULE, "data", "art")
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

    # The mark and the record, so that the next run and the uninstaller know
    # this archive, and what in it is the module's.
    version = "unknown"
    changelog = os.path.join(root or MODULE, "CHANGELOG.md")
    if os.path.isfile(changelog):
        for line in io.open(changelog, encoding="utf-8", errors="replace"):
            if line.startswith("## "):
                version = line[3:].strip().split()[0]
                break
    kind = SHARED if into else OWN
    contents[MARK] = (
        "mod-spheregrid %s\r\narchive: %s\r\nwritten by tools/install.py: "
        "the module's rows merged into this client's own DBC files, and its "
        "art.%s\r\n" % (version, kind,
                         " This archive is the client's; SphereGrid/written.json "
                         "says what in it is the module's." if into else "")
        ).encode("utf-8")
    record = {"kind": kind, "version": version, "dbc": written_dbc,
              "added": [], "replaced": [], "backups": keeper.stamp}
    contents[WRITTEN] = b""          # classified below, then filled in
    removals = []
    if into:
        before = view.record or {}
        # A file the earlier run added stays the module's whatever the
        # archive holds now; one it replaced stays the client's, and the
        # copies taken THEN are the originals.
        earlier_added = set(before.get("added", ()))
        earlier_replaced = set(before.get("replaced", ()))
        record["backups"] = before.get("backups") or keeper.stamp
        for name in sorted(contents):
            if name in earlier_replaced:
                record["replaced"].append(name)
            elif name in earlier_added or not have.has(name):
                record["added"].append(name)
            else:
                record["replaced"].append(name)
        # What the earlier run added and this one no longer writes -- a file
        # renamed between versions -- comes out.
        removals = sorted(n for n in earlier_added - set(contents)
                          if have.has(n))
        # A checksum file some tools keep and the game never reads: its
        # entries would no longer match the archive's blocks, so it goes
        # rather than mislead. The copy is in the backups.
        if have.has("(attributes)"):
            removals.append("(attributes)")
    contents[WRITTEN] = json.dumps(record, indent=1,
                                   sort_keys=True).encode("utf-8")

    if into:
        replaced = [n for n in record["replaced"] if have.has(n)]
        print("  -> INTO %s" % into)
        print("     %d file(s) replaced, each copied aside first; %d added; "
              "%d removed" % (len(replaced), len(record["added"]),
                              len(removals)))
        for name in replaced:
            if name.startswith("DBFilesClient"):
                print("        %s" % name)
        if dry_run:
            print("     (dry run: not written)")
            view.close()
            return
        for name in replaced:
            keeper.keep_bytes(into, name, have.read(name))
        for name in removals:
            keeper.keep_bytes(into, name, have.read(name))
        for name in record["added"]:
            keeper.note_added(into, name)
        was = os.path.getsize(into)
        view.close()
        mpq.patch_archive(into, contents, remove=removals)
        print("     %.1f MB -> %.1f MB" % (was / 1048576.0,
                                          os.path.getsize(into) / 1048576.0))
        return

    view.close()
    landing = os.path.join(client_dir, ARCHIVE)
    print("  -> %s" % landing)
    if dry_run:
        print("     (dry run: not written)")
        return
    keeper.keep(landing)
    mpq.write_archive(landing, contents)
    print("     %.1f MB" % (os.path.getsize(landing) / 1048576.0))


def too_wide(target, which, folder):
    """Every value the module's SQL writes, against the width of its column.

    MySQL stops on the FIRST row it cannot take, in the middle of a file, and
    leaves the database half written. AzerothCore does not give the same width
    to columns holding the same kind of text -- `AuraDescription_Lang_Unk` is a
    varchar(100) where its neighbours are varchar(550) -- so a text that fits
    everywhere else can still be refused. The widths are read from the table
    itself and every value measured against them, before anything is touched.

    Returns a list of (file, line, table, column, room, given)."""
    import shift as shifting
    widths = {}
    answer = target.run_sql(which, statement=(
        "SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_MAXIMUM_LENGTH "
        "FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() "
        "AND CHARACTER_MAXIMUM_LENGTH IS NOT NULL"))
    for line in (answer or "").splitlines()[1:]:
        bits = line.split("\t")
        if len(bits) == 3 and bits[2].isdigit():
            widths[(bits[0].lower(), bits[1].lower())] = int(bits[2])
    if not widths:
        return []
    out = []
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".sql"):
            continue
        text = io.open(os.path.join(folder, name), encoding="utf-8",
                       newline="").read()
        for header in shifting.INSERT_HEADER.finditer(text):
            table = text[header.start():header.end()].split("`")[1]
            columns = [c.strip("` \r\n") for c in header.group(1).split(",")]
            for spans in shifting.value_spans(text, header.end(),
                                              until_statement_end=True):
                for column, (start, end) in zip(columns, spans):
                    room = widths.get((table.lower(), column.lower()))
                    raw = text[start:end].strip()
                    if room is None or not raw.startswith("'"):
                        continue
                    value = raw[1:-1].replace("''", "'")
                    if len(value) > room:
                        out.append((name, text[:start].count("\n") + 1,
                                    table, column, room, len(value)))
    return out

def apply_sql(target, dry_run, root=None):
    print("SQL")
    for which in ("world", "characters"):
        folder = os.path.join(root or MODULE, "data", "sql", which)
        if not os.path.isdir(folder):
            continue
        # BEFORE ANYTHING IS WRITTEN: a value that will not fit its column
        # stops MySQL half way through a file and leaves the database posed by
        # halves. Everything that would overflow is named here instead.
        wide = too_wide(target, which, folder)
        if wide:
            for name, line, table, column, room, given in wide:
                print("  %-12s %s line %d: %s.%s takes %d, given %d"
                      % (which, name, line, table, column, room, given))
            raise SystemExit(
                "%d value(s) will not fit their column. Nothing was written."
                % len(wide))
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".sql"):
                continue
            print("  %-12s %s" % (which, name))
            if not dry_run:
                target.run_sql(which, source=os.path.join(folder, name))


def take_backup(target, policy, dry_run):
    """The copies taken before anything is written.

    `target` is None when only a client is being patched: there is no server
    to dump, and the files the client half copies aside are kept by
    patch_client itself.
    """
    print("BACKUP")
    keeper = backup_lib.Backup(MODULE, policy=policy)
    if dry_run:
        print("  (dry run: nothing copied)")
        return keeper
    if target is None:
        print("  no server: only what the client's archive gives up is kept")
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
    parser.add_argument("--server",
                        help="the directory holding worldserver.exe")
    parser.add_argument("--core",
                        help="the AzerothCore source tree, with its modules/")
    parser.add_argument("--client", help="a client's Data directory")
    parser.add_argument("--no-client", action="store_true",
                        help="install the server half alone, and say so on "
                             "purpose: without a patched client the module's "
                             "spells have no name, no icon and no effect")
    parser.add_argument("--client-only", action="store_true",
                        help="patch a client and nothing else: no server, no "
                             "database. For the machine where the client "
                             "lives, which is rarely the server's")
    parser.add_argument("--locale", default="enUS")
    parser.add_argument("--backup", default=backup_lib.VAULT,
                        choices=[backup_lib.VAULT, backup_lib.BESIDE])
    parser.add_argument("--mysql", help="the folder holding mysql.exe")
    parser.add_argument("--shift", action="store_true",
                        help="when an identifier is taken, move the module's "
                             "own out of the way instead of stopping")
    parser.add_argument("--presence", action="store_true",
                        help="say whether the module is already installed "
                             "here (exit code 3) or not (0), and stop")
    parser.add_argument("--keep-characters", action="store_true",
                        help="when removing: leave what players earned")
    parser.add_argument("--drop-characters", action="store_true",
                        help="when removing: take it out too")
    parser.add_argument("--survey", action="store_true",
                        help="read and report, write nothing")
    parser.add_argument("--dry-run", action="store_true",
                        help="announce every step, write nothing")
    args = parser.parse_args()

    # --- a client is not optional --------------------------------------------
    if args.client_only:
        if not args.client:
            parser.error("--client-only needs --client <client Data dir>")
        print("mod-spheregrid, the client half alone")
        print("  client   %s" % args.client)
        print()
        keeper = take_backup(None, args.backup, args.dry_run)
        patch_client(args.client, args.locale, keeper, args.dry_run)
        if not args.dry_run:
            print()
            print("BACKUP: %s" % keeper.describe())
            print("  receipt %s" % keeper.write_receipt("client only"))
        return 0
    for name in ("server", "core"):
        if not getattr(args, name):
            parser.error("--%s is required" % name)
    if not args.client and not args.no_client:
        parser.error(
            "a client's Data directory is needed: the module's spells exist in "
            "no client, and without its rows they have no name, no icon and no "
            "effect. Pass --client <dir>, or --no-client if this server has no "
            "client on it -- and then patch one with --client-only where it "
            "lives.")
    if args.client and args.no_client:
        parser.error("--client and --no-client say the opposite")

    target = Target(args.server, args.core, args.mysql)
    print("mod-spheregrid")
    print("  server   %s" % target.server)
    print("  core     %s" % target.core)
    print("  world    %s" % target.databases["world"]["name"])
    print("  client   %s" % (args.client or "NONE -- said on purpose"))
    print()
    if args.no_client:
        print("  WITHOUT A PATCHED CLIENT the module's spells have no name, no")
        print("  icon and no effect: a client has no row for them. Patch one")
        print("  where it lives:")
        print("      python tools/install.py --client-only --client <Data dir>")
        print()

    found, earned = presence(target, args.client)
    report_presence(found, earned, target)
    if args.presence:
        return 3 if found else 0
    if found:
        print("  THE MODULE IS ALREADY INSTALLED HERE: this run REMOVES it. "
              "To update it, install again once it is gone.")
        if args.survey:
            print("  (look only: nothing removed)")
            return 3
        if args.keep_characters == args.drop_characters:
            print("  Say what becomes of what players earned: "
                  "--keep-characters or --drop-characters.")
            return 3
        import uninstall
        print()
        uninstall.remove_module(target, args.client, args.drop_characters,
                                args.dry_run)
        return 0
    print()

    clashes = survey(target, args.client, args.locale)
    if any(clashes.values()) and not args.shift:
        print("  Stopping. Run again with --shift to move the module's own "
              "identifiers out of the way, or free them on this server.")
        return 2
    if args.survey:
        return 0

    print()
    keeper = take_backup(target, args.backup, args.dry_run)
    print()
    # THE COPY COMES FIRST, and everything after it works on the copy. A shift
    # rewrites identifiers in the module's own DBC, SQL, C++ and Lua; the
    # module the installer was launched from must come out of this untouched,
    # still carrying the numbers it was written with.
    root = place_sources(target, keeper, args.dry_run)
    if args.dry_run:
        root = MODULE                   # nothing was copied: read the source
    if any(clashes.values()):
        print()
        shift_module(clashes, args.dry_run, root)
        if not args.dry_run:
            print()
            clashes = survey(target, args.client, args.locale, root)
            if any(clashes.values()):
                print("  Still taken after the shift: stopping.")
                return 2
        print()
        print("PLACE")
    place_interface(root, target, keeper, args.dry_run)
    print()
    apply_sql(target, args.dry_run, root)
    if args.client:
        print()
        patch_client(args.client, args.locale, keeper, args.dry_run, root)

    if not args.dry_run:
        receipt = keeper.write_receipt("install")
        print()
        print("BACKUP: %s" % keeper.describe())
        print("  receipt %s" % receipt)
        print()
        print("Rebuild the core so the module is compiled in, then start the "
              "server.")


if __name__ == "__main__":
    sys.exit(main())
