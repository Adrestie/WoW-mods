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

"""Keeping a copy of everything before it is touched.

NOTHING IS WRITTEN BEFORE ITS PREVIOUS STATE IS KEPT. That is the whole rule,
and it holds for files and for database tables alike. What the installer cannot
put back, it does not touch.

Two places to keep them, and the operator chooses:

  vault     a `Backups/` folder inside the module's own directory, reproducing
            the path of each file underneath it. Everything in one place, easy
            to keep or to throw away in one gesture.
  beside    a copy next to the original, under the same name with a suffix.
            Nothing to look for: the copy is where the file is.

The second is what makes an archive safe to overwrite. A client archive is
copied FIRST, beside itself, and only then written into -- so a conflict inside
it is resolved on a file whose previous state is already on disk.

Every backup writes a receipt saying what was kept and where it came from, so a
restore needs nothing but the backup folder.
"""
import json
import os
import shutil
import time

VAULT = "vault"
BESIDE = "beside"

RECEIPT = "backup.json"


class Backup(object):
    """One installation's worth of copies, and the receipt that describes it."""

    def __init__(self, module_dir, policy=VAULT, stamp=None):
        if policy not in (VAULT, BESIDE):
            raise ValueError("unknown backup policy: %s" % policy)
        self.policy = policy
        self.stamp = stamp or time.strftime("%Y%m%d-%H%M%S")
        self.root = os.path.join(module_dir, "Backups", self.stamp)
        self.entries = []

    # -- files ------------------------------------------------------------

    def keep(self, path):
        """Copies one file aside. Returns where the copy went, or None.

        A file that does not exist yet needs no copy -- but it is recorded all
        the same, because putting things back means DELETING it, and only the
        receipt can say that it was not there before.
        """
        if not os.path.exists(path):
            self.entries.append({"path": path, "copy": None, "existed": False})
            return None

        if self.policy == BESIDE:
            copy = "%s.before-spheregrid-%s" % (path, self.stamp)
        else:
            # The path is reproduced under the vault, drive letter included, so
            # that two files of the same name never land on each other.
            drive, rest = os.path.splitdrive(os.path.abspath(path))
            copy = os.path.join(self.root, drive.replace(":", ""),
                                rest.lstrip("\\/"))
            os.makedirs(os.path.dirname(copy), exist_ok=True)

        shutil.copy2(path, copy)
        self.entries.append({"path": path, "copy": copy, "existed": True})
        return copy

    def keep_bytes(self, archive, inside, data):
        """Keeps a file that lives INSIDE an archive, before it is replaced.

        `archive` is the archive's path on disk, `inside` the file's path in
        it. The copy lands under the archive's own path in the vault (or
        beside it), and the receipt says which archive it came from: putting
        it back means writing it into that archive again.
        """
        if self.policy == BESIDE:
            # A folder named after the archive, beside it. The client only
            # reads files named `*.MPQ`, and a folder is neither.
            copy = os.path.join("%s.before-spheregrid-%s" % (archive, self.stamp),
                                inside.replace("\\", os.sep))
        else:
            drive, rest = os.path.splitdrive(os.path.abspath(archive))
            copy = os.path.join(self.root, drive.replace(":", ""),
                                rest.lstrip("\\/"), inside.replace("\\", os.sep))
        os.makedirs(os.path.dirname(copy), exist_ok=True)
        with open(copy, "wb") as out:
            out.write(data)
        self.entries.append({"path": inside, "copy": copy, "existed": True,
                             "inside": archive})
        return copy

    def note_added(self, archive, inside):
        """Records a file the module ADDS to an archive: nothing to copy, but
        putting things back means taking it out, and only the receipt says
        it was not there before."""
        self.entries.append({"path": inside, "copy": None, "existed": False,
                             "inside": archive})

    def keep_tree(self, folder):
        """Copies aside every file of a folder that already exists."""
        if not os.path.isdir(folder):
            self.entries.append({"path": folder, "copy": None,
                                 "existed": False, "tree": True})
            return
        for base, _, names in os.walk(folder):
            for name in names:
                self.keep(os.path.join(base, name))

    # -- database ---------------------------------------------------------

    def keep_tables(self, dump_path, schema, tables):
        """Records that a dump of these tables was written to `dump_path`.

        The dump itself is taken by whoever has the connection; the backup only
        remembers that it exists and what it holds, so that a restore knows
        what to replay and into which schema.
        """
        self.entries.append({"dump": dump_path, "schema": schema,
                             "tables": list(tables)})

    def dump_path(self, schema):
        """Where a dump of one schema belongs inside this backup."""
        folder = os.path.join(self.root, "sql")
        os.makedirs(folder, exist_ok=True)
        return os.path.join(folder, "%s.sql" % schema)

    # -- the receipt ------------------------------------------------------

    def write_receipt(self, note=""):
        os.makedirs(self.root, exist_ok=True)
        path = os.path.join(self.root, RECEIPT)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump({"stamp": self.stamp, "policy": self.policy,
                       "note": note, "entries": self.entries},
                      f, indent=2, ensure_ascii=False)
        return path

    def describe(self):
        files = [e for e in self.entries if "path" in e]
        kept = [e for e in files if e.get("existed")]
        dumps = [e for e in self.entries if "dump" in e]
        where = ("the module's Backups folder" if self.policy == VAULT
                 else "beside each original")
        return ("%d file(s) copied to %s, %d recorded as not yet existing, "
                "%d database dump(s)" % (len(kept), where,
                                         len(files) - len(kept), len(dumps)))


def read_receipt(folder):
    with open(os.path.join(folder, RECEIPT), encoding="utf-8") as f:
        return json.load(f)


def latest(module_dir):
    """The most recent backup under a module directory, or None."""
    root = os.path.join(module_dir, "Backups")
    if not os.path.isdir(root):
        return None
    stamps = sorted(d for d in os.listdir(root)
                    if os.path.isfile(os.path.join(root, d, RECEIPT)))
    return os.path.join(root, stamps[-1]) if stamps else None
