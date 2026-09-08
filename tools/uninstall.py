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
interface under lua_scripts/, the configuration, and the client's own
patch-Z.MPQ -- which is removed whole, since nothing existing was ever written
into. A rebuild of the core is then yours, as it was after installing.

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

from install import Target, ARCHIVE, is_ours   # noqa: E402

WORLD_SQL = os.path.join(MODULE, "data", "sql", "world")
CHARACTERS_SQL = os.path.join(MODULE, "data", "sql", "characters")

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
    print("  %-11s %d delete(s) from the module's own SQL, %d table(s) of its own"
          % (which, len(deletes), len(own)))
    lines = [piece for _, piece in reversed(deletes)]
    lines += ["DROP TABLE IF EXISTS `%s`" % t for t in own]
    if dry_run:
        for line in lines:
            print("      %s" % line[:100])
        return
    target.run_sql(which, statement=";\n".join(lines) + ";\n")


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

    print("DATABASE")
    undo_database(target, "world", WORLD_SQL, args.dry_run)
    if args.drop_characters:
        undo_database(target, "characters", CHARACTERS_SQL, args.dry_run)
    else:
        print("  %-11s kept: the Spherite and the cells players bought stay"
              % "characters")

    print("FILES")
    remove(os.path.join(target.core, "modules", "mod-spheregrid"),
           args.dry_run, "sources")
    remove(target.lua_dir, args.dry_run, "interface")
    remove(os.path.join(target.server, "configs", "modules", "mod-spheregrid.conf"),
           args.dry_run, "config")

    if args.client:
        path = os.path.join(args.client, ARCHIVE)
        found = None
        for name in os.listdir(args.client):
            if name.lower() == ARCHIVE.lower():
                found = os.path.join(args.client, name)
        if found is None:
            print("  %-11s no %s in %s" % ("client", ARCHIVE, args.client))
        elif not is_ours(found):
            print("  %-11s %s IS NOT OURS -- left alone" % ("client", found))
        else:
            remove(found, args.dry_run, "client")

    print("Done. Rebuild the core so the module is compiled out, then start the "
          "server." if not args.dry_run else "(dry run: nothing was changed)")


if __name__ == "__main__":
    main()
