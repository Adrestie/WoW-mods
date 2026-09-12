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

"""Removes mod-spheregrid from a server, and says everything it does.

    python tools/uninstall.py --server <server dir> --core <azerothcore dir>
                              [--client <client Data dir>] [--mysql <dir>]
                              [--keep-characters] [--dry-run]

THE DATABASE IS UNDONE BY THE MODULE'S OWN SQL. Every file under data/sql
deletes what it is about to insert -- that is what makes it replayable.
Collected on their own, those DELETE statements are exactly an uninstaller,
and one that cannot drift from the module: change what a file writes, and the
way to remove it changes with it. Two things are added: the module's OWN
tables are dropped rather than emptied, because they belong to nobody else;
and the statements run in reverse file order, so what a later file added is
gone before an earlier one is undone.

WHAT PLAYERS EARNED IS KEPT unless you say otherwise. The characters database
holds the Spherite and the cells they bought; `--keep-characters` (the default
is to ask) leaves those four tables where they are, so that a reinstall finds
them again.

THE FILES are the ones the installer placed: the sources under modules/, the
interface under lua_scripts/, the configuration, and the client's patch-Z.MPQ.
When that archive is the module's own it is removed whole. When it is the
client's -- the installer wrote INTO a patch the client already had -- the
archive stays: the module's rows are taken out of each DBC it merged into,
and the files it added are removed, from the record the installer left inside
the archive. A rebuild of the core is then yours, as it was after installing.

`--dry-run` prints every statement and every path, and touches nothing.
"""
import argparse
import io
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from install import (Target, ARCHIVE, MODULE, OWN, SHARED,   # noqa: E402
                     archive_kind, written_record, top_archive,
                     dbc_from_bytes, dbc_to_bytes)
from spheregrid import dbc, mpq, backup as backup_lib   # noqa: E402

def installed_root(target):
    """The module AS IT WAS INSTALLED, under the core's `modules/`.

    That copy is what carries the identifiers actually written: a shift moves
    them there, never in the source the installer was launched from. Reading
    the source instead would delete rows that do not exist and leave the ones
    that do. With no copy left, the source answers, and it is said.
    """
    copy = getattr(target, "module_dir", None)
    if copy and os.path.isdir(os.path.join(copy, "data", "sql", "world")):
        return copy
    print("  the installed copy is gone: reading %s instead, which may name "
          "other identifiers" % MODULE)
    return MODULE

DELETE = re.compile(r"^\s*DELETE\s+FROM\s+`?(\w+)`?\b", re.I)
OWN_TABLE = re.compile(
    r"CREATE\s+TABLE(?:\s+IF\s+NOT\s+EXISTS)?\s+`?(mod_spheregrid_\w+)`?", re.I)


def statements(folder):
    """Every statement of every file, in order, comments stripped."""
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".sql"):
            continue
        text = io.open(os.path.join(folder, name), encoding="utf-8").read()
        text = re.sub(r"--[^\n]*", "", text)
        for piece in text.split(";"):
            piece = piece.strip()
            if piece:
                yield name, piece


def plan(folder):
    """The DELETE statements to replay, and the module's own tables."""
    deletes, own = [], []
    for name, piece in statements(folder):
        found = OWN_TABLE.search(piece)
        if found and found.group(1) not in own:
            own.append(found.group(1))
        if DELETE.match(piece):
            # A temporary table lives and dies inside its own script.
            if "TEMPORARY" in piece.upper():
                continue
            deletes.append((name, re.sub(r"\s+", " ", piece)))
    return deletes, own


def undo_database(target, which, folder, dry_run):
    deletes, own = plan(folder)
    # A TABLE THAT IS NOT THERE HOLDS NOTHING TO DELETE. An install may have
    # been taken apart by hand, or a removal run twice, or a server may not
    # have every optional table; the statement is left out rather than
    # stopping the whole removal on the first one that has no target.
    here = target.existing_tables(which)
    absent = sorted({DELETE.match(piece).group(1) for _, piece in deletes
                     if DELETE.match(piece)} - here)
    deletes = [(name, piece) for name, piece in deletes
               if not DELETE.match(piece) or DELETE.match(piece).group(1) in here]
    print("  %-11s %d delete(s) from the module's own SQL, %d table(s) of its own"
          % (which, len(deletes), len(own)))
    if absent:
        print("  %-11s %d table(s) named by those statements are not on this "
              "server: %s" % ("", len(absent), ", ".join(absent[:6])))
    lines = [piece for _, piece in reversed(deletes)]
    lines += ["DROP TABLE IF EXISTS `%s`" % t for t in own]
    if dry_run:
        for line in lines:
            print("      %s" % line[:100])
        return
    target.run_sql(which, statement=";\n".join(lines) + ";\n")




# THE SHARED WORKBENCH goes with the last provider. Another module is a
# provider when one of its Lua files, outside this module's own folder,
# registers itself with `Workbench.Register(`.
def other_providers(target):
    scripts = os.path.dirname(target.lua_dir)
    own = os.path.normcase(target.lua_dir)
    found = []
    for base, folders, names in os.walk(scripts):
        if os.path.normcase(base).startswith(own):
            continue
        for name in names:
            if not name.endswith((".lua", ".ext")):
                continue
            try:
                text = io.open(os.path.join(base, name), encoding="utf-8", errors="replace").read()
            except IOError:
                continue
            if "Workbench.Register(" in text:
                found.append(os.path.relpath(os.path.join(base, name), scripts))
    return found


def remove_workbench(target, dry_run):
    others = other_providers(target)
    if others:
        print("  %-11s kept: still used by %s" % ("workbench", ", ".join(others)))
        return
    remove(os.path.join(os.path.dirname(target.lua_dir), "Workbench"), dry_run, "workbench")
    lines = [
        "DELETE FROM `gameobject` WHERE `id` = 803700",
        "DELETE FROM `gameobject_template_locale` WHERE `entry` = 803700",
        "DELETE FROM `gameobject_template` WHERE `entry` = 803700",
    ]
    print("  %-11s the object 803700 and its spawns, nobody else uses them" % "workbench")
    if dry_run:
        for line in lines:
            print("      %s" % line)
        return
    target.run_sql("world", statement=";\n".join(lines) + ";\n")


def remove(path, dry_run, what):
    if not os.path.exists(path):
        print("  %-11s %s (not there)" % (what, path))
        return
    print("  %-11s %s" % (what, path))
    if dry_run:
        return
    if os.path.isdir(path):
        shutil.rmtree(path)
    else:
        os.remove(path)


# WHERE THE MODULE'S SPELLS SIT IN THE CORE'S OWN TABLES. A spell the grid
# taught is learnt like any other: it lands in `character_spell`, its cooldown
# in `character_spell_cooldown`, an aura it left in `character_aura`, and the
# button a player put it on in `character_action`. None of those belong to the
# module, so its own SQL cannot delete them -- and left behind they name a
# spell that no longer exists, which the core says at every login.
CHARACTER_SPELL_TABLES = (
    ("character_spell", "spell"),
    ("character_spell_cooldown", "spell"),
    ("character_aura", "spell"),
)
# The action bars keep a type alongside the number: 0 is a spell.
CHARACTER_ACTIONS = ("character_action", "action")


def taught_spells(root):
    """The spells the module can have taught: its own rows, exactly.

    Read from the file the client is given, which is the same source the
    server's rows come from -- and by identifier rather than by range, so
    that a neighbour's spell in the same block is never touched.
    """
    path = os.path.join(root, "data", "dbc", "spheregrid_Spell.dbc")
    return sorted(dbc.read(path).ids()) if os.path.isfile(path) else []


def undo_characters(target, root, dry_run):
    """Takes back what the module taught, from the core's own tables."""
    spells = taught_spells(root)
    if not spells:
        print("  %-11s no spell file to read: nothing taken back" % "characters")
        return
    here = target.existing_tables("characters")
    inside = ", ".join(str(i) for i in spells)
    lines, touched = [], []
    for table, column in CHARACTER_SPELL_TABLES:
        if table not in here:
            continue
        lines.append("DELETE FROM `%s` WHERE `%s` IN (%s)" % (table, column, inside))
        touched.append(table)
    table, column = CHARACTER_ACTIONS
    if table in here:
        lines.append("DELETE FROM `%s` WHERE `type` = 0 AND `%s` IN (%s)"
                     % (table, column, inside))
        touched.append(table)
    print("  %-11s %d spell(s) taken back from %s"
          % ("characters", len(spells), ", ".join(touched) or "nothing"))
    if dry_run:
        for line in lines:
            print("      %s" % (line[:100] + " ..." if len(line) > 100 else line))
        return
    if lines:
        target.run_sql("characters", statement=";\n".join(lines) + ";\n")


def original_copy(archive, inside, stamp):
    """Where the backup of a file the module wrote over inside an archive
    is -- from the receipt of the run that first replaced it, or None."""
    if not stamp:
        return None
    receipt = backup_lib.read_receipt(os.path.join(MODULE, "Backups", stamp))
    if not receipt:
        return None
    for entry in receipt.get("entries", ()):
        if (entry.get("existed") and entry.get("copy")
                and os.path.normcase(entry.get("inside", "")) == os.path.normcase(archive)
                and entry.get("path", "").lower() == inside.lower()
                and os.path.isfile(entry["copy"])):
            return entry["copy"]
    return None


def unwrite(path, dry_run):
    """Takes the module out of an archive it was written INTO.

    The archive is the client's: it stays. What the module added -- its art,
    its mark, its record -- is removed. Each DBC it merged rows into is read
    back, the module's rows taken out, and written in again: the client's rows
    are exactly what they were, in a file rebuilt around them. A file of the
    client's that the module wrote over is put back from the copy the
    installer took, when that copy is still where the receipt says.
    """
    archive = mpq.Archive(path)
    try:
        record = written_record(archive)
        stripped, removals, left = {}, [], []
        for inside, ids in sorted(record.get("dbc", {}).items()):
            if inside in record.get("added", ()) or not archive.has(inside):
                continue
            table = dbc_from_bytes(archive.read(inside))
            keep = set(table.ids()) - set(ids)
            gone = len(table) - len(keep)
            strings_at = dbc.string_fields_of(os.path.basename(inside), table)
            stripped[inside] = dbc_to_bytes(dbc.subset(table, keep, strings_at))
            print("  %-11s %-28s %d row(s) out, %d stay"
                  % ("client", os.path.basename(inside), gone, len(keep)))
        removals = [n for n in record.get("added", ()) if archive.has(n)]
        for name in record.get("replaced", ()):
            if name in record.get("dbc", {}) or not archive.has(name):
                continue
            copy = original_copy(path, name, record.get("backups"))
            if copy:
                with open(copy, "rb") as f:
                    stripped[name] = f.read()
            else:
                left.append(name)
    finally:
        archive.close()
    print("  %-11s %s: %d file(s) put back, %d removed"
          % ("client", os.path.basename(path), len(stripped), len(removals)))
    for name in left:
        print("  %-11s %s was the client's, the module wrote over it, and "
              "its copy is not where the receipt of backup %s says: LEFT "
              "AS THE MODULE WROTE IT" % ("client", name, record.get("backups")))
    if dry_run:
        return
    mpq.patch_archive(path, stripped, remove=removals)


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--server", required=True)
    parser.add_argument("--core", required=True)
    parser.add_argument("--client", help="a client's Data directory")
    parser.add_argument("--mysql", help="the folder holding mysql")
    parser.add_argument("--keep-characters", action="store_true",
                        help="leave what players earned in the characters database")
    parser.add_argument("--drop-characters", action="store_true",
                        help="remove it too -- the Spherite and the cells bought")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.keep_characters == args.drop_characters:
        raise SystemExit("say which: --keep-characters or --drop-characters")

    target = Target(args.server, args.core, args.mysql)
    print("mod-spheregrid, removal%s" % (" (dry run)" if args.dry_run else ""))
    print("  server   %s" % target.server)
    print("  core     %s" % target.core)
    remove_module(target, args.client, args.drop_characters, args.dry_run)


def remove_module(target, client_dir, drop_characters, dry_run):
    """The removal itself: the installer calls this when it finds the module
    already there, and `main` when this file is run on its own."""
    # WHAT WAS INSTALLED, not what the source says today: a shift moves the
    # identifiers in the copy, and the copy is what the database and the
    # client were given.
    root = installed_root(target)
    print("DATABASE")
    undo_database(target, "world", os.path.join(root, "data", "sql", "world"),
                  dry_run)
    # WHATEVER BECOMES OF WHAT PLAYERS EARNED, the spells the module taught go
    # back: they live in the core's tables, they name rows that are being
    # removed, and the core complains at every login until they are gone. A
    # reinstall teaches them again, from the cells the player still owns.
    undo_characters(target, root, dry_run)
    if drop_characters:
        undo_database(target, "characters",
                      os.path.join(root, "data", "sql", "characters"), dry_run)
    else:
        print("  %-11s kept: the Spherite and the cells players bought stay"
              % "characters")

    print("FILES")
    remove(os.path.join(target.core, "modules", "mod-spheregrid"),
           dry_run, "sources")
    remove(target.lua_dir, dry_run, "interface")
    remove_workbench(target, dry_run)
    remove(os.path.join(target.server, "configs", "modules", "mod-spheregrid.conf"),
           dry_run, "config")

    if client_dir:
        found = top_archive(client_dir)
        kind = archive_kind(found) if found else None
        if found is None:
            print("  %-11s no %s in %s" % ("client", ARCHIVE, client_dir))
        elif kind == OWN:
            remove(found, dry_run, "client")
        elif kind == SHARED:
            unwrite(found, dry_run)
        else:
            print("  %-11s %s is the client's own and carries nothing of the "
                  "module's -- left alone" % ("client", found))

    print("Done. Rebuild the core so the module is compiled out, then start the "
          "server." if not dry_run else "(dry run: nothing was changed)")


if __name__ == "__main__":
    sys.exit(main())
