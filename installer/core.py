# -*- coding: utf-8 -*-
r"""WoW-mods installer engine (MIT licence).

One program installs and removes any module that carries a manifest
(installer.json at its root, format described in MANIFEST.md).

No trace of the module: it installs. It copies the module into the server
sources (modules/), puts its configuration and Lua scripts in place, adds its
rows to the server DBC files and writes them, with its game files, directly
into the game's MPQ archives. The server is then rebuilt; on first start the
core updater applies the module's SQL.

Any trace: it removes everything that is left, wherever it is (sources,
configuration, Lua scripts anywhere in the scripts folder, server DBC rows,
DBC rows and files of every game archive, database data read and deleted
through the mysql client). An uninstall started by hand is therefore
finished by running the program again.

Items that carry the module's identifiers with nothing proving they are its
own (a DBC row with the same identifier and other content, a game file
provided in another version by another archive, database rows without the
rest of the module) are a conflict: no install, and they are removed only
when the user confirms they are leftovers of the module (never a game file).

Other modules' rows, files and tables are never touched. In each game archive
it writes to, the installer leaves a receipt (WoW-mods\<module>.receipt)
listing what it put there; removal takes what its receipts name, the DBC rows
identical to its own and the files stored under the module's own folders. An
identical file provided by another archive is never its own.
"""
import argparse
import array
import glob
import json
import os
import re
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import traceback

import mpq_archive

# Package entries never copied into modules/.
NEVER_COPIED = {".git", "__pycache__"}

NEW_ARCHIVE_NAME = "patch-Z.MPQ"
MANIFEST_NAME = "installer.json"
RECEIPT_FOLDER = "WoW-mods"
CREATE_NO_WINDOW = 0x08000000


class InstallerError(Exception):
    pass


def sql_list(values):
    """Values as a SQL list: strings quoted, numbers as integers."""
    return ", ".join(("'%s'" % v.replace("'", "''")) if isinstance(v, str) else str(int(v)) for v in values)


# ------------------------------------------------------------------ console

def say(text=""):
    print(text, flush=True)


def heading(text):
    say()
    say(text)
    say("-" * len(text))


def ask_path(prompt, folder=True, initial=None):
    """Asks for a folder (folder=True) or for mysql.exe through a dialog, or on
    the keyboard when no dialog can open. Returns None if the user gives up."""
    say(prompt)
    try:
        import tkinter
        from tkinter import filedialog
        window = tkinter.Tk()
        window.withdraw()
        window.attributes("-topmost", True)
        if folder:
            path = filedialog.askdirectory(title=prompt, initialdir=initial or "", mustexist=True, parent=window)
        else:
            path = filedialog.askopenfilename(title=prompt, initialdir=initial or "", parent=window,
                                              filetypes=[("mysql.exe", "mysql.exe"), ("*.exe", "*.exe")])
        window.destroy()
    except Exception:
        path = input("  path: ").strip().strip('"')
    if not path:
        return None
    path = os.path.normpath(path)
    say("  -> %s" % path)
    return path


# ------------------------------------------------------------------ remembered paths

def settings_path():
    return os.path.join(os.environ.get("APPDATA") or os.path.expanduser("~"), "WoW-mods", "installer-settings.json")


def load_settings():
    try:
        with open(settings_path(), encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_settings(settings):
    try:
        os.makedirs(os.path.dirname(settings_path()), exist_ok=True)
        with open(settings_path(), "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=1, ensure_ascii=False)
    except OSError:
        pass


# ------------------------------------------------------------------ configuration files

def read_conf(path):
    """{key: value} of an AzerothCore .conf file (quotes removed)."""
    values = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.lstrip().startswith("#"):
                continue
            m = re.match(r"\s*([A-Za-z0-9_.]+)\s*=\s*(.*?)\s*$", line)
            if m:
                v = m.group(2)
                if len(v) >= 2 and v[0] == v[-1] == '"':
                    v = v[1:-1]
                values[m.group(1)] = v
    return values


def is_inside(path, folder):
    path = os.path.normcase(os.path.abspath(path))
    folder = os.path.normcase(os.path.abspath(folder))
    return path == folder or path.startswith(folder.rstrip("\\/") + os.sep)


# ------------------------------------------------------------------ the server

class Server(object):
    """Everything the installer derives from the worldserver folder: configuration
    files, DBC folder, Lua scripts folder, databases, build folder and sources.

    bin_dir: folder of worldserver.exe; sources: AzerothCore sources, or None
    to read them from the build folder's CMakeCache.txt."""

    def __init__(self, bin_dir, sources=None):
        self.bin = os.path.normpath(os.path.abspath(bin_dir))
        if not os.path.isfile(os.path.join(self.bin, "worldserver.exe")):
            raise InstallerError("no worldserver.exe in %s" % self.bin)
        candidates = [os.path.join(self.bin, "configs", "worldserver.conf"),
                      os.path.join(self.bin, "worldserver.conf"),
                      os.path.join(self.bin, "..", "etc", "worldserver.conf")]
        self.conf = next((os.path.normpath(c) for c in candidates if os.path.isfile(c)), None)
        if not self.conf:
            raise InstallerError("worldserver.conf not found (searched in configs\\ and next to worldserver.exe)")
        self.module_confs = os.path.join(os.path.dirname(self.conf), "modules")
        c = read_conf(self.conf)
        self.data = self._resolve(c.get("DataDir") or ".")
        self.dbc = os.path.join(self.data, "dbc")
        self.lua = self._resolve(self._lua_folder())
        self.databases = {"world": self._db_info(c, "WorldDatabaseInfo"),
                          "characters": self._db_info(c, "CharacterDatabaseInfo")}
        try:
            self.updates_mask = int(c.get("Updates.EnableDatabases") or 0)
        except ValueError:
            self.updates_mask = 0
        self.mysql_conf = c.get("MySQLExecutable") or ""
        self.build_dir, self.build_config = self._find_build()
        self.sources = os.path.normpath(sources) if sources else self._sources_from_cache()

    def _resolve(self, p):
        return os.path.normpath(p if os.path.isabs(p) else os.path.join(self.bin, p))

    def _lua_folder(self):
        # The core reads only the .conf file: without it, ALE uses its default.
        for name, key in (("mod_ale.conf", "ALE.ScriptPath"), ("mod_eluna.conf", "Eluna.ScriptPath")):
            p = os.path.join(self.module_confs, name)
            if os.path.isfile(p):
                v = read_conf(p).get(key)
                if v:
                    return v
        return "lua_scripts"

    @staticmethod
    def _db_info(c, key):
        parts = (c.get(key) or "").split(";")
        if len(parts) != 5:
            raise InstallerError("%s unreadable in worldserver.conf" % key)
        host, port, user, password, name = parts
        return {"host": host, "port": port, "user": user, "password": password, "name": name}

    def _find_build(self):
        """(build folder holding CMakeCache.txt, configuration name) or (None, None)."""
        d = self.bin
        for _ in range(6):
            if os.path.isfile(os.path.join(d, "CMakeCache.txt")):
                config = os.path.basename(self.bin)
                if config not in ("Debug", "Release", "RelWithDebInfo", "MinSizeRel"):
                    config = None
                return d, config
            parent = os.path.dirname(d)
            if parent == d:
                break
            d = parent
        return None, None

    def _sources_from_cache(self):
        if not self.build_dir:
            return None
        with open(os.path.join(self.build_dir, "CMakeCache.txt"), encoding="utf-8", errors="replace") as f:
            for line in f:
                if line.startswith("CMAKE_HOME_DIRECTORY:"):
                    return os.path.normpath(line.split("=", 1)[1].strip())
        return None

    def has_valid_sources(self):
        return bool(self.sources) and os.path.isdir(os.path.join(self.sources, "modules")) and \
            os.path.isdir(os.path.join(self.sources, "src"))

    @property
    def modules(self):
        return os.path.join(self.sources, "modules")


# ------------------------------------------------------------------ the game and its archives

def archive_rank(name):
    """(load rank, is official) of an archive, from its file name.

    The client reads base archives first (group 0), then locale patches
    patch-xxXX-* (group 1), then plain patches patch-* (group 2); within a
    group, the one without suffix, then digits, then letters. The last one
    read wins."""
    stem = name.lower().rsplit(".", 1)[0]
    if not stem.startswith("patch"):
        return (0, 0, stem), True
    parts = [p for p in stem[5:].split("-") if p]
    locale = bool(parts) and len(parts[0]) > 1 and not parts[0].isdigit()
    suffix = parts[-1] if parts and not (locale and len(parts) == 1) else ""
    rank = (1 if locale else 2, 0 if not suffix else (1 if suffix.isdigit() else 2), suffix)
    return rank, suffix in ("", "2", "3")


class Client(object):
    """The game folder: its archives, in the order the client reads them."""

    def __init__(self, folder):
        self.folder = os.path.normpath(os.path.abspath(folder))
        self.data = next((os.path.join(self.folder, n) for n in os.listdir(self.folder)
                          if n.lower() == "data" and os.path.isdir(os.path.join(self.folder, n))), None) \
            if os.path.isdir(self.folder) else None
        if not self.data or not any(n.lower().endswith(".mpq") for n in os.listdir(self.data)):
            raise InstallerError("no Data folder with .MPQ archives in %s" % self.folder)
        self.locale_dir = self._find_locale_dir()
        self._open = {}
        self.unreadable = []

    def _find_locale_dir(self):
        wanted = None
        wtf = os.path.join(self.folder, "WTF", "Config.wtf")
        if os.path.isfile(wtf):
            with open(wtf, encoding="latin-1") as f:
                m = re.search(r'^SET locale "(\w+)"', f.read(), re.M | re.I)
                wanted = m.group(1).lower() if m else None
        folders = [n for n in os.listdir(self.data) if os.path.isdir(os.path.join(self.data, n)) and
                   glob.glob(os.path.join(self.data, n, "*.mpq"))]
        for n in folders:
            if wanted and n.lower() == wanted:
                return os.path.join(self.data, n)
        return os.path.join(self.data, folders[0]) if len(folders) == 1 else None

    def archives(self):
        """[(rank, path)] of every archive the game reads, from weakest to strongest."""
        found = []
        for folder in (self.data, self.locale_dir):
            if folder:
                for n in os.listdir(folder):
                    p = os.path.join(folder, n)
                    if n.lower().endswith(".mpq") and os.path.isfile(p):
                        found.append((archive_rank(n)[0], p))
        return sorted(found)

    def custom_archives(self):
        return [p for r, p in self.archives() if not archive_rank(os.path.basename(p))[1]]

    def open(self, path):
        """The archive, or None if it cannot be read (recorded in unreadable)."""
        if path not in self._open:
            try:
                self._open[path] = mpq_archive.Archive(path)
            except (mpq_archive.MpqError, OSError, struct.error) as e:
                self._open[path] = None
                self.unreadable.append((path, str(e)))
        return self._open[path]

    def forget(self, path):
        self._open.pop(path, None)

    def winner(self, name, below=None):
        """The archive the game reads this file from; below=path: the winner
        among the archives read before that one."""
        paths = [p for r, p in self.archives()]
        if below is not None:
            paths = paths[:paths.index(below)]
        for path in reversed(paths):
            a = self.open(path)
            if a is not None and a.contains(name):
                return path
        return None

    def write_target(self, winner):
        """Where to write a changed file: into its winning archive if that one is
        custom; otherwise into the last custom archive, if read after it;
        otherwise into a new archive."""
        if winner and not archive_rank(os.path.basename(winner))[1]:
            return winner
        ranks = dict((p, r) for r, p in self.archives())
        custom = self.custom_archives()
        if custom and (winner is None or ranks[custom[-1]] > ranks[winner]):
            return custom[-1]
        return os.path.join(self.data, NEW_ARCHIVE_NAME)


# ------------------------------------------------------------------ DBC

def dbc_split(raw, name):
    """(field count, [row bytes], string block) of a DBC file."""
    if raw[:4] != b"WDBC":
        raise InstallerError("%s is not a DBC file (no WDBC signature)" % name)
    count, fields, size, string_size = struct.unpack_from("<4I", raw, 4)
    if size != fields * 4 or len(raw) < 20 + count * size + string_size:
        raise InstallerError("%s: inconsistent DBC header" % name)
    rows = [raw[20 + i * size:20 + (i + 1) * size] for i in range(count)]
    start = 20 + count * size
    return fields, rows, bytearray(raw[start:start + string_size])


def dbc_join(fields, rows, strings):
    return b"WDBC" + struct.pack("<4I", len(rows), fields, fields * 4, len(strings)) + \
        b"".join(rows) + bytes(strings)


def _row_id(row):
    return struct.unpack_from("<I", row)[0]


def read_string(strings, offset):
    """The string starting at this offset of the string block (empty for 0)."""
    if not offset or offset >= len(strings):
        return ""
    end = strings.find(b"\0", offset)
    return bytes(strings[offset:end if end >= 0 else len(strings)]).decode("utf-8", "surrogateescape")


def row_values(row, strings, fields, text):
    """The values of a DBC row, in the form of the module's rows: text fields
    (indices in text) read from the string block, the others as unsigned integers."""
    values = struct.unpack_from("<%dI" % fields, row)
    return [read_string(strings, v) if i in text else v for i, v in enumerate(values)]


def dbc_survey(raw, name, d, rows):
    """(our ids, conflicting ids): rows of this DBC that carry one of the module's
    identifiers, identical to the module's rows or not.

    d: the manifest's DBC entry; rows: the module's rows for this side."""
    fields, recs, strings = dbc_split(raw, name)
    if fields != d.fields:
        raise InstallerError("%s has %d fields, %d expected: unexpected client version" % (name, fields, d.fields))
    expected = {r[0]: r for r in rows}
    ours, others = [], []
    for r in recs:
        i = _row_id(r)
        if i in expected:
            (ours if row_values(r, strings, fields, d.text) == expected[i] else others).append(i)
    return sorted(ours), sorted(others)


def dbc_add(raw, name, d, rows):
    """The DBC with the module's rows appended (rows already carrying their
    identifiers removed first); their strings appended to the string block."""
    fields, recs, strings = dbc_split(raw, name)
    if fields != d.fields:
        raise InstallerError("%s has %d fields, %d expected: unexpected client version" % (name, fields, d.fields))
    ids = set(r[0] for r in rows)
    recs = [r for r in recs if _row_id(r) not in ids]
    for values in rows:
        rec = []
        for i, v in enumerate(values):
            if i in d.text:
                if not v:
                    rec.append(0)
                    continue
                if not strings:
                    strings.extend(b"\0")          # offset 0 is the empty string
                rec.append(len(strings))
                strings.extend(v.encode("utf-8", "surrogateescape") + b"\0")
            else:
                rec.append(int(v) & 0xFFFFFFFF)
        recs.append(struct.pack("<%dI" % fields, *rec))
    return dbc_join(fields, recs, strings)


def dbc_remove(raw, name, ids, text):
    """(DBC without the rows of these identifiers, rows removed).

    The string block is cut after the last string a remaining row still
    reads: through a declared text field (text), and, to be safe, through any
    other field whose value points at a string start further on (a text field
    the manifest would not declare). Strings the install appended at the end
    go; nothing still in use does. With nothing removed, the original bytes
    are returned."""
    fields, recs, strings = dbc_split(raw, name)
    ids = set(ids)
    kept = [r for r in recs if _row_id(r) not in ids]
    n = len(recs) - len(kept)
    if not n:
        return raw, 0
    if strings:
        size = len(strings)

        def end_of(offset):
            zero = strings.find(b"\0", offset)
            return (zero if zero >= 0 else size - 1) + 1

        end = 1
        for r in kept:
            values = struct.unpack_from("<%dI" % fields, r)
            for c in text:
                if 0 < values[c] < size:
                    end = max(end, end_of(values[c]))
        all_values = array.array("I")
        all_values.frombytes(b"".join(kept))
        for v in {x for x in all_values if end <= x < size}:
            if strings[v - 1] == 0:
                end = max(end, end_of(v))
        strings = strings[:min(end, size)]
    return dbc_join(fields, kept, strings), n


def write_file_atomic(path, content):
    """Writes a sibling file, then replaces the target in one step."""
    temporary = path + ".installer-tmp"
    try:
        with open(temporary, "wb") as f:
            f.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.remove(temporary)


# ------------------------------------------------------------------ running processes

def running_processes():
    """[(name, full path or None)] of the running processes."""
    import ctypes
    from ctypes import wintypes

    class PROCESSENTRY32W(ctypes.Structure):
        _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
                    ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.c_void_p),
                    ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                    ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", ctypes.c_long),
                    ("dwFlags", wintypes.DWORD), ("szExeFile", ctypes.c_wchar * 260)]

    k = ctypes.WinDLL("kernel32", use_last_error=True)
    k.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    k.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    k.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    k.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    k.OpenProcess.restype = wintypes.HANDLE
    k.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    k.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR,
                                             ctypes.POINTER(wintypes.DWORD)]
    k.CloseHandle.argtypes = [wintypes.HANDLE]
    result = []
    snapshot = k.CreateToolhelp32Snapshot(2, 0)
    if not snapshot or snapshot == wintypes.HANDLE(-1).value:
        return result
    e = PROCESSENTRY32W()
    e.dwSize = ctypes.sizeof(PROCESSENTRY32W)
    ok = k.Process32FirstW(snapshot, ctypes.byref(e))
    while ok:
        path = None
        h = k.OpenProcess(0x1000, False, e.th32ProcessID)      # PROCESS_QUERY_LIMITED_INFORMATION
        if h:
            buffer = ctypes.create_unicode_buffer(32768)
            size = wintypes.DWORD(32768)
            if k.QueryFullProcessImageNameW(h, 0, buffer, ctypes.byref(size)):
                path = buffer.value
            k.CloseHandle(h)
        result.append((e.szExeFile, path))
        ok = k.Process32NextW(snapshot, ctypes.byref(e))
    k.CloseHandle(snapshot)
    return result


def running_worldservers(server):
    return [(n, p) for n, p in running_processes()
            if n.lower() == "worldserver.exe" and (p is None or is_inside(p, server.bin))]


def running_game(client):
    me = os.path.normcase(os.path.abspath(sys.executable))
    return [(n, p) for n, p in running_processes()
            if p and is_inside(p, client.folder) and os.path.normcase(p) != me]


# ------------------------------------------------------------------ the database, through the mysql client

class Database(object):
    """One database, queried through mysql.exe. info: connection fields read
    from worldserver.conf (host, port, user, password, name)."""

    def __init__(self, mysql, info):
        self.mysql = mysql
        self.info = info
        self.name = info["name"]

    def _options_text(self):
        i = self.info
        lines = ["[client]", "user=%s" % i["user"],
                 'password="%s"' % i["password"].replace("\\", "\\\\").replace('"', '\\"')]
        if i["host"] == ".":
            lines += ["protocol=PIPE", "socket=%s" % i["port"]]
        else:
            lines += ["host=%s" % i["host"], "port=%s" % i["port"]]
        return "\n".join(lines) + "\n"

    def run(self, sql):
        """Runs the statements; returns the result rows, split into columns."""
        fd, options = tempfile.mkstemp(suffix=".cnf")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(self._options_text())
            r = subprocess.run([self.mysql, "--defaults-extra-file=" + options, "--default-character-set=utf8mb4",
                                "--batch", "--skip-column-names", self.name],
                               input=sql.encode("utf-8"), capture_output=True, creationflags=CREATE_NO_WINDOW)
        finally:
            os.remove(options)
        if r.returncode:
            raise InstallerError("MySQL, database %s: %s" % (self.name, r.stderr.decode("utf-8", "replace").strip()))
        return [line.split("\t") for line in r.stdout.decode("utf-8", "replace").splitlines() if line]

    def existing_tables(self, names):
        """The given table names that exist, in lower case."""
        if not names:
            return set()
        r = self.run("SELECT LOWER(table_name) FROM information_schema.tables WHERE table_schema = "
                     "DATABASE() AND LOWER(table_name) IN (%s);" % sql_list([n.lower() for n in names]))
        return {row[0] for row in r}

    def has_column(self, table, column):
        r = self.run("SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() "
                     "AND LOWER(table_name) = '%s' AND LOWER(column_name) = '%s';" % (table.lower(), column.lower()))
        return r[0][0] != "0"


def find_mysql(server, settings, forced=None):
    """Path of mysql.exe: forced, then worldserver.conf, the remembered one, the PATH, usual folders."""
    candidates = [forced, server.mysql_conf, settings.get("mysql"), shutil.which("mysql")]
    for pattern in (r"C:\Program Files\MySQL\MySQL Server *\bin\mysql.exe",
                    r"C:\Program Files\MariaDB *\bin\mysql.exe",
                    r"C:\Program Files (x86)\MySQL\MySQL Server *\bin\mysql.exe"):
        candidates += sorted(glob.glob(pattern), reverse=True)
    for c in candidates:
        if c and os.path.isfile(c):
            return os.path.normpath(c)
    return None


# ------------------------------------------------------------------ receipts

def receipt_name(M):
    return RECEIPT_FOLDER + "\\" + M.name + ".receipt"


def receipt_text(M, files, dbc):
    """The receipt of one archive: files ([names]) and dbc ({file: [ids]}) the installer put there."""
    lines = ["# WoW-mods installer: what %s wrote into this archive" % M.name]
    lines += ["file %s" % n for n in sorted(files)]
    lines += ["dbc %s %s" % (f, ",".join(str(i) for i in sorted(ids))) for f, ids in sorted(dbc.items())]
    return ("\r\n".join(lines) + "\r\n").encode("utf-8")


def read_receipt(M, a):
    """{"files": [...], "dbc": {file: [ids]}} if archive a carries a receipt of the module, else None."""
    name = receipt_name(M)
    if not a.contains(name):
        return None
    receipt = {"files": [], "dbc": {}}
    for line in a.read(name).decode("utf-8", "replace").splitlines():
        parts = line.strip().split(" ", 2)
        if len(parts) >= 2 and parts[0] == "file":
            receipt["files"].append(line.strip()[5:])
        elif len(parts) == 3 and parts[0] == "dbc":
            receipt["dbc"][parts[1]] = [int(x) for x in parts[2].split(",") if x.strip()]
    return receipt


# ------------------------------------------------------------------ current state

class State(object):
    """What was found of the module: strong traces prove it is there, weak items
    only carry its identifiers."""

    def __init__(self):
        # strong traces
        self.sources = []            # module folders in modules/
        self.confs = []              # configuration files
        self.lua = []                # the module's Lua scripts, wherever they are
        self.lua_dir = None          # the module's folder in the scripts folder
        self.server_dbc = []         # (path, file, ids identical to the module's)
        self.receipts = []           # (archive, receipt)
        self.client_dbc = []         # (archive, file, ids to remove: identical, or named by the receipt)
        self.files = []              # (archive, name): named by the receipt, or under an owned folder
        self.backups = []            # backups left by older tools
        self.db_strong = {}          # {database: [(text, count)]}: module tables, updater rows
        # weak items
        self.server_conflicts = []   # (path, file, ids with other content)
        self.client_conflicts = []   # (archive, file, ids with other content)
        self.file_conflicts = []     # (archive, name): the game reads another version, from a custom archive
        self.db_weak = {}            # {database: [(text, count)]}: rows of shared tables

    def strong(self):
        return bool(self.sources or self.confs or self.lua or self.lua_dir or self.server_dbc or
                    self.receipts or self.client_dbc or self.files or self.backups or self.db_strong)

    def weak(self):
        return bool(self.server_conflicts or self.client_conflicts or self.file_conflicts or self.db_weak)

    def lines(self):
        """[(area, text)] of the module's traces."""
        out = [("sources", d) for d in self.sources]
        out += [("configuration", c) for c in self.confs]
        out += [("Lua script", c) for c in self.lua]
        if self.lua_dir:
            out.append(("Lua folder", self.lua_dir))
        out += [("server DBC", "%s: %d module row(s)" % (p, len(ids))) for p, f, ids in self.server_dbc]
        out += [("receipt", "%s: installation receipt" % a) for a, r in self.receipts]
        out += [("client", "%s, %s: %d module row(s)" % (a, f, len(ids))) for a, f, ids in self.client_dbc]
        by_archive = {}
        for a, n in self.files:
            by_archive.setdefault(a, []).append(n)
        for a, names in sorted(by_archive.items()):
            detail = names[0] if len(names) == 1 else "%d files (%s, ...)" % (len(names), names[0])
            out.append(("game files", "%s: %s" % (a, detail)))
        out += [("backup", s) for s in self.backups]
        for db, traces in sorted(self.db_strong.items()):
            out += [("database %s" % db, "%s: %s" % (t, n)) for t, n in traces]
        # the module is there: the database rows in its name go with it
        if self.strong():
            for db, traces in sorted(self.db_weak.items()):
                out += [("database %s" % db, "%s: %s" % (t, n)) for t, n in traces]
        return out

    def conflict_lines(self):
        """[(area, text)] of what carries the module's identifiers without being its own."""
        out = [("server DBC", "%s: %s, same identifier, other content" % (p, _id_summary(ids)))
               for p, f, ids in self.server_conflicts]
        out += [("client", "%s, %s: %s, same identifier, other content" % (a, f, _id_summary(ids)))
                for a, f, ids in self.client_conflicts]
        out += [("game file", "%s: %s, provided in another version" % (a, n)) for a, n in self.file_conflicts]
        if not self.strong():
            for db, traces in sorted(self.db_weak.items()):
                out += [("database %s" % db, "%s: %s" % (t, n)) for t, n in traces]
        return out

    def has_conflicts(self):
        """True if something stays in place because it is not the module's (module present or not)."""
        return bool(self.conflict_lines())


def _id_summary(ids):
    ids = list(ids)
    return ", ".join(str(i) for i in ids[:8]) + (" (+%d)" % (len(ids) - 8) if len(ids) > 8 else "")


def module_source_dirs(M, server):
    """Folders of modules/ named after the module or holding all its signature files."""
    found = []
    if not os.path.isdir(server.modules):
        return found
    for n in sorted(os.listdir(server.modules)):
        d = os.path.join(server.modules, n)
        if not os.path.isdir(d):
            continue
        if n.lower() == M.name.lower() or all(os.path.isfile(os.path.join(d, s)) for s in M.signature):
            found.append(d)
    return found


def module_lua_files(M, server):
    """The module's Lua files, wherever they are under the scripts folder."""
    if not M.lua:
        return []
    names = {os.path.basename(p).lower() for p in M.lua["files"]}
    found = []
    if os.path.isdir(server.lua):
        for d, _, files in os.walk(server.lua):
            found += [os.path.join(d, f) for f in files if f.lower() in names]
    return sorted(found)


def module_backups(M, server, client):
    found = []
    for suffix in M.backups:
        for folder in (server.dbc, client.data, client.locale_dir):
            if folder and os.path.isdir(folder):
                found += [os.path.join(folder, n) for n in sorted(os.listdir(folder))
                          if n.lower().endswith(suffix.lower())]
    return found


def survey_database(db, desc):
    """([(text, count)] strong, [(text, count)] weak): what the module left in
    this database. Its tables and the updater's rows (`updates`) prove it is
    there; rows of shared tables do not. desc: the manifest's entry for this database."""
    all_tables = list(desc.get("tables", [])) + [t for t, _ in desc.get("rows", [])]
    existing = db.existing_tables(all_tables)
    queries, labels = [], []
    for t in desc.get("tables", []):
        if t.lower() in existing:
            queries.append("SELECT COUNT(*) FROM `%s`" % t)
            labels.append(("table", t))
    for t, condition in desc.get("rows", []):
        if t.lower() in existing:
            queries.append("SELECT COUNT(*) FROM `%s` WHERE %s" % (t, condition))
            labels.append(("rows", t))
    if not queries:
        return [], []
    r = db.run(" UNION ALL ".join(queries) + ";")
    strong, weak = [], []
    for (kind, t), row in zip(labels, r):
        n = int(row[0])
        if kind == "table":
            strong.append(("table %s" % t, "present, %d row(s)" % n))
        elif n:
            (strong if t.lower() == "updates" else weak).append(("rows of %s" % t, "%d" % n))
    return strong, weak


def in_owned_folder(M, name):
    n = name.replace("/", "\\").lower()
    return any(n.startswith(d) for d in M.owned_folders)


def module_files_in(M, a, receipt):
    """The module's files present in archive a: those its receipt names, and
    everything stored under a folder owned by the module."""
    found = {}
    for n in (receipt or {}).get("files", []):
        if a.contains(n):
            found.setdefault(n.lower(), n)
    if M.owned_folders:
        if a.contains("(listfile)"):
            for n in a.read("(listfile)").decode("latin-1").replace(";", "\n").splitlines():
                n = n.strip().replace("/", "\\")
                if n and in_owned_folder(M, n) and a.contains(n):
                    found.setdefault(n.lower(), n)
        for n in M.game_files:
            if in_owned_folder(M, n) and a.contains(n):
                found.setdefault(n.lower(), n)
    return sorted(found.values())


def survey(M, server, client, dbs):
    """The State of the module on this server, game and databases."""
    s = State()
    s.sources = module_source_dirs(M, server)
    if M.conf:
        s.confs = [p for p in (os.path.join(server.module_confs, M.conf["file"]),
                               os.path.join(server.module_confs, M.conf["file"] + ".dist"))
                   if os.path.isfile(p)]
    s.lua = module_lua_files(M, server)
    if M.lua:
        # The module's folder is a trace only if it holds nothing but its scripts:
        # a file of the user's stored there makes it theirs.
        d = os.path.join(server.lua, M.lua["folder"])
        names = {os.path.basename(p).lower() for p in M.lua["files"]}
        if os.path.isdir(d) and all(n.lower() in names for n in os.listdir(d)):
            s.lua_dir = d

    # Server DBC: rows identical to the module's, or same identifier and other content.
    for d in M.dbc:
        if d.server is None:
            continue
        p = os.path.join(server.dbc, d.file)
        if os.path.isfile(p):
            with open(p, "rb") as f:
                ours, others = dbc_survey(f.read(), p, d, d.server)
            if ours:
                s.server_dbc.append((p, d.file, ours))
            if others:
                s.server_conflicts.append((p, d.file, others))

    # Custom game archives: receipts, rows, files.
    for path in client.custom_archives():
        a = client.open(path)
        if a is None:
            continue
        receipt = read_receipt(M, a)
        if receipt is not None:
            s.receipts.append((path, receipt))
        for d in M.dbc:
            if d.client is None:
                continue
            name = "DBFilesClient\\" + d.file
            if not a.contains(name):
                continue
            ours, others = dbc_survey(a.read(name), name, d, d.client)
            named = set((receipt or {}).get("dbc", {}).get(d.file, []))
            mine = sorted(set(ours) | (set(others) & named))
            others = [i for i in others if i not in named]
            if mine:
                s.client_dbc.append((path, d.file, mine))
            if others:
                s.client_conflicts.append((path, d.file, others))
        s.files += [(path, n) for n in module_files_in(M, a, receipt)]

    # What the game reads: rows of an official archive with the same identifier
    # (Blizzard's rows) and files provided in another version.
    for d in M.dbc:
        if d.client is None:
            continue
        name = "DBFilesClient\\" + d.file
        w = client.winner(name)
        if w and archive_rank(os.path.basename(w))[1]:
            ours, others = dbc_survey(client.open(w).read(name), name, d, d.client)
            if others:
                s.client_conflicts.append((w, d.file, others))
    mine = {(c.lower(), n.lower()) for c, n in s.files}
    for name, source in M.game_files.items():
        w = client.winner(name)
        if not w or archive_rank(os.path.basename(w))[1] or (w.lower(), name.lower()) in mine:
            continue
        with open(source, "rb") as f:
            if client.open(w).read(name) != f.read():
                s.file_conflicts.append((w, name))

    s.backups = module_backups(M, server, client)
    for key, db in dbs.items():
        strong, weak = survey_database(db, M.databases.get(key, {}))
        if strong:
            s.db_strong[key] = strong
        if weak:
            s.db_weak[key] = weak
    return s


# ------------------------------------------------------------------ removal

def remove_tree(d):
    def force(function, path, _):
        os.chmod(path, stat.S_IWRITE)           # read-only files of a git checkout
        function(path)
    shutil.rmtree(d, onexc=force)


def archive_is_redundant(client, path):
    """True if the archive holds only DBC files, each identical to the one the
    game would read without it: it no longer changes anything (the archive an
    install created on a client that had none)."""
    a = client.open(path)
    if a is None or not a.contains("(listfile)"):
        return False
    names = [n.strip() for n in a.read("(listfile)").decode("latin-1").replace(";", "\n").splitlines()
             if n.strip()]
    if not names or len(names) > 50 or \
            any(not n.replace("/", "\\").lower().startswith("dbfilesclient\\") for n in names):
        return False
    for n in names:
        if not a.contains(n):
            continue
        below = client.winner(n, below=path)
        if below is None or client.open(below).read(n) != a.read(n):
            return False
    return True


def remove(M, server, client, dbs, state, leftovers=False):
    """Removes everything that is the module's.

    state: the survey; leftovers: the user said the conflicting items are
    leftovers of the module, so DBC rows with its identifiers go too (never a
    game file)."""
    heading("Removal")
    # Database: characters first (what is taken back, such as talent points, is
    # taken back before the table that counts them is dropped), then world.
    for key in ("characters", "world"):
        desc = M.databases.get(key)
        if not desc or key not in dbs or (key not in state.db_strong and key not in state.db_weak):
            continue
        db = dbs[key]
        existing = db.existing_tables(list(desc.get("tables", [])) + [t for t, _ in desc.get("rows", [])])
        script = []
        for (table, column), sql in desc.get("before", []):
            if table.lower() in existing and db.has_column(table, column):
                script.append(sql)
        for t, condition in desc.get("rows", []):
            if t.lower() in existing:
                script.append("DELETE FROM `%s` WHERE %s" % (t, condition))
        for t in desc.get("tables", []):
            if t.lower() in existing:
                script.append("DROP TABLE IF EXISTS `%s`" % t)
        if script:
            db.run(";\n".join(script) + ";\n")
            say("  database %s: %d statement(s) run" % (db.name, len(script)))

    # Server DBC: the module's rows (and, for leftovers, those with its identifiers).
    defs = {d.file: d for d in M.dbc}
    to_remove = {}
    for p, f, ids in state.server_dbc + (state.server_conflicts if leftovers else []):
        to_remove.setdefault((p, f), set()).update(ids)
    for (p, f), ids in sorted(to_remove.items()):
        with open(p, "rb") as fh:
            new, n = dbc_remove(fh.read(), p, ids, defs[f].text)
        if n:
            write_file_atomic(p, new)
            say("  %s: %d row(s) removed" % (p, n))

    # Game archives: the module's rows, files and receipt, in each archive.
    by_archive = {}
    for path, f, ids in state.client_dbc + [c for c in state.client_conflicts
                                            if leftovers and not archive_rank(os.path.basename(c[0]))[1]]:
        by_archive.setdefault(path, ({}, set()))[0].setdefault(f, set()).update(ids)
    for path, name in state.files:
        by_archive.setdefault(path, ({}, set()))[1].add(name)
    for path, r in state.receipts:
        by_archive.setdefault(path, ({}, set()))[1].add(receipt_name(M))
    for path, (rows, names) in sorted(by_archive.items()):
        a = client.open(path)
        written = {}
        for f, ids in sorted(rows.items()):
            name = "DBFilesClient\\" + f
            new, n = dbc_remove(a.read(name), name, ids, defs[f].text)
            if n:
                written[name] = new
                say("  %s, %s: %d row(s) removed" % (path, f, n))
        leaving = sorted(n for n in names if a.contains(n))
        for name in leaving:
            if name != receipt_name(M):
                say("  %s: %s removed" % (path, name))
        if written or leaving:
            mpq_archive.write_into_archive(path, written, remove=leaving)
            client.forget(path)
            if archive_is_redundant(client, path):
                client.forget(path)
                os.remove(path)
                say("  %s held nothing but unchanged copies: archive deleted" % path)

    # Server files.
    for d in state.sources:
        remove_tree(d)
        say("  deleted: %s" % d)
    for p in state.confs + state.lua + state.backups:
        os.remove(p)
        say("  deleted: %s" % p)
    if M.lua:
        d = os.path.join(server.lua, M.lua["folder"])
        if os.path.isdir(d):
            if os.listdir(d):
                say("  kept: %s, which holds files foreign to the module:" % d)
                for n in sorted(os.listdir(d)):
                    say("      %s" % n)
            else:
                os.rmdir(d)
                say("  deleted: %s" % d)


# ------------------------------------------------------------------ installation

def configured_conf(M):
    """The .conf text: the template with the manifest's values."""
    with open(os.path.join(M.root, M.conf["template"]), encoding="utf-8") as f:
        text = f.read()
    for key, value in M.conf["values"].items():
        text, n = re.subn(r"(?m)^(%s\s*=\s*).*$" % re.escape(key), lambda m: m.group(1) + value, text)
        if not n:
            raise InstallerError("%s: setting %s missing from the template" % (M.conf["template"], key))
    return text


def install(M, server, client, dbs):
    heading("Installation")
    # What must exist before the first write.
    for d in M.dbc:
        if d.server is not None and not os.path.isfile(os.path.join(server.dbc, d.file)):
            raise InstallerError("%s not found (DataDir of worldserver.conf)" % os.path.join(server.dbc, d.file))
        if d.client is not None and client.winner("DBFilesClient\\" + d.file) is None:
            raise InstallerError("no game archive contains DBFilesClient\\%s" % d.file)

    # 1. Game: each DBC rewritten into the archive that provides it (or above),
    #    files into the last custom archive read (a new one if there is none);
    #    a receipt in each archive written.
    writes, created, receipts = {}, set(), {}
    for d in M.dbc:
        if d.client is None:
            continue
        name = "DBFilesClient\\" + d.file
        w = client.winner(name)
        target = client.write_target(w)
        writes.setdefault(target, {})[name] = dbc_add(client.open(w).read(name), name, d, d.client)
        receipts.setdefault(target, ([], {}))[1][d.file] = d.client_ids
    if M.game_files:
        target = client.write_target(None)
        a = client.open(target) if os.path.exists(target) else None
        for name, source in sorted(M.game_files.items()):
            # already in that archive (identical, or it would be a conflict): not ours
            if a is not None and a.contains(name):
                continue
            with open(source, "rb") as f:
                writes.setdefault(target, {})[name] = f.read()
            receipts.setdefault(target, ([], {}))[0].append(name)
    for target in writes:
        if not os.path.exists(target):
            created.add(target)
        files, dbc = receipts.get(target, ([], {}))
        writes[target][receipt_name(M)] = receipt_text(M, files, dbc)
    for target, files in writes.items():
        if target in created:
            mpq_archive.create_archive(target, files, hash_entries=max(1024, 1 << (2 * len(files) + 16).bit_length()))
            say("  archive created: %s" % target)
        else:
            mpq_archive.write_into_archive(target, files)
        client.forget(target)
        dbc_names = [n for n in files if n.startswith("DBFilesClient\\")]
        for name in dbc_names:
            f = name.split("\\")[-1]
            say("  %s, %s: %d row(s) added" % (target, f, len([d for d in M.dbc if d.file == f][0].client)))
        game_file_count = len(files) - len(dbc_names) - 1
        if game_file_count:
            say("  %s: %d game file(s) written" % (target, game_file_count))

    # 2. Server DBC.
    for d in M.dbc:
        if d.server is None:
            continue
        p = os.path.join(server.dbc, d.file)
        with open(p, "rb") as f:
            raw = f.read()
        write_file_atomic(p, dbc_add(raw, p, d, d.server))
        say("  %s: %d row(s) added" % (p, len(d.server)))

    # 3. Lua scripts.
    if M.lua:
        d = os.path.join(server.lua, M.lua["folder"])
        os.makedirs(d, exist_ok=True)
        for p in M.lua["files"]:
            with open(os.path.join(M.root, p), "rb") as f:
                content = f.read()
            name = os.path.basename(p)
            cp = M.lua.get("config_path")
            if cp and cp["file"] == name:
                content = set_conf_path(M, server, content)
            with open(os.path.join(d, name), "wb") as f:
                f.write(content)
            say("  written: %s" % os.path.join(d, name))

    # 4. Configuration: the .dist as is, the .conf with the manifest's values.
    if M.conf:
        os.makedirs(server.module_confs, exist_ok=True)
        shutil.copyfile(os.path.join(M.root, M.conf["template"]),
                        os.path.join(server.module_confs, M.conf["file"] + ".dist"))
        with open(os.path.join(server.module_confs, M.conf["file"]), "w", encoding="utf-8", newline="") as f:
            f.write(configured_conf(M))
        say("  written: %s (and .dist)" % os.path.join(server.module_confs, M.conf["file"]))

    # 5. Sources: the package, minus what the manifest excludes.
    destination = os.path.join(server.modules, M.name)
    excluded = {os.path.normcase(os.path.join(M.root, x)) for x in M.excluded}

    def ignore(folder, names):
        return [n for n in names if n in NEVER_COPIED or os.path.normcase(os.path.join(folder, n)) in excluded]

    shutil.copytree(M.root, destination, ignore=ignore)
    say("  copied: %s" % destination)

    # 6. SQL: the core updater applies it on start; when it is off for a
    #    database, the installer applies it itself.
    for key, bit, folder in (("characters", 2, "db-characters"), ("world", 4, "db-world")):
        if server.updates_mask & bit or key not in dbs:
            continue
        for sub in ("base", "updates", "custom"):
            for p in sorted(glob.glob(os.path.join(M.root, "data", "sql", folder, sub, "*.sql"))):
                with open(p, encoding="utf-8") as f:
                    dbs[key].run(f.read())
                say("  applied (updater off): %s" % os.path.relpath(p, M.root))


def set_conf_path(M, server, content):
    """The Lua script that reads the .conf gets its real path, relative to the worldserver folder."""
    cp = M.lua["config_path"]
    target = os.path.join(server.module_confs, M.conf["file"])
    try:
        path = os.path.relpath(target, server.bin)
    except ValueError:                          # another drive
        path = target
    path = path.replace("\\", "/")
    text = content.decode("utf-8")
    text, n = re.subn(r'(?m)^(local %s = )".*"' % re.escape(cp["variable"]),
                      lambda m: '%s"%s"' % (m.group(1), path), text, count=1)
    if not n:
        raise InstallerError('%s: line "local %s = ..." not found' % (cp["file"], cp["variable"]))
    return text.encode("utf-8")


def missing_after_install(M, server, client):
    """What is missing after an install (empty if everything is in place)."""
    missing = []
    d = os.path.join(server.modules, M.name)
    if not all(os.path.isfile(os.path.join(d, s)) for s in M.signature):
        missing.append("sources in %s" % d)
    if M.conf:
        for n in (M.conf["file"], M.conf["file"] + ".dist"):
            if not os.path.isfile(os.path.join(server.module_confs, n)):
                missing.append(n)
    if M.lua:
        for p in M.lua["files"]:
            if not os.path.isfile(os.path.join(server.lua, M.lua["folder"], os.path.basename(p))):
                missing.append(os.path.basename(p))
    for dd in M.dbc:
        if dd.server is not None:
            p = os.path.join(server.dbc, dd.file)
            with open(p, "rb") as f:
                if len(dbc_survey(f.read(), p, dd, dd.server)[0]) != len(dd.server):
                    missing.append("%s rows (server)" % dd.file)
        if dd.client is not None:
            name = "DBFilesClient\\" + dd.file
            w = client.winner(name)
            if w is None or len(dbc_survey(client.open(w).read(name), name, dd, dd.client)[0]) != len(dd.client):
                missing.append("%s rows in the archive the game reads" % dd.file)
    for name, source in M.game_files.items():
        w = client.winner(name)
        with open(source, "rb") as f:
            if w is None or client.open(w).read(name) != f.read():
                missing.append("%s in the archive the game reads" % name)
    return missing


# ------------------------------------------------------------------ run

def print_state(state):
    lines = state.lines()
    if not lines:
        say("  no trace of the module")
    for area, text in lines:
        say("  %-19s %s" % (area, text))


def print_conflicts(state):
    for area, text in state.conflict_lines():
        say("  %-19s %s" % (area, text))


def print_build_steps(server):
    say("The server must now be rebuilt, with the worldserver stopped:")
    if server.build_dir:
        say('    cd /d "%s"' % server.build_dir)
        say("    cmake .")
        say("    cmake --build . --config %s --target worldserver" % (server.build_config or "RelWithDebInfo"))
    else:
        say("    run the CMake configuration again, then build worldserver")


def prepare(M, args, settings, interactive):
    """(server, client, databases), from the options, the remembered paths or the user."""
    change = False
    while True:
        server = client = None
        folder = None if change else (args.server or settings.get("server"))
        while server is None:
            if folder:
                try:
                    server = Server(folder, args.sources)
                    break
                except InstallerError as e:
                    say("  %s" % e)
            if not interactive:
                raise InstallerError("the worldserver folder must be given (--server)")
            folder = ask_path("Worldserver folder (the one that contains worldserver.exe)?",
                              initial=settings.get("server"))
            if folder is None:
                raise InstallerError("no worldserver folder chosen")
        if not server.has_valid_sources() and settings.get("sources") and not change:
            server.sources = settings["sources"]
        while not server.has_valid_sources():
            if not interactive:
                raise InstallerError("AzerothCore sources not found (--sources)")
            d = ask_path("AzerothCore sources folder (the one that contains modules and src)?")
            if d is None:
                raise InstallerError("no sources folder chosen")
            server.sources = d
        folder = None if change else (args.client or settings.get("client"))
        while client is None:
            if folder:
                try:
                    client = Client(folder)
                    break
                except InstallerError as e:
                    say("  %s" % e)
            if not interactive:
                raise InstallerError("the game folder must be given (--client)")
            folder = ask_path("Game folder (the one that contains Wow.exe and Data)?", initial=settings.get("client"))
            if folder is None:
                raise InstallerError("no game folder chosen")
        heading("Folders")
        say("  worldserver      %s" % server.bin)
        say("  sources          %s" % server.sources)
        say("  configuration    %s" % server.module_confs)
        say("  Lua scripts      %s" % server.lua)
        say("  server DBC       %s" % server.dbc)
        say("  game             %s" % client.folder)
        say("  databases        %s, %s" % (server.databases["world"]["name"], server.databases["characters"]["name"]))
        if interactive:
            r = input("Enter: continue; C then Enter: change folders. ").strip().lower()
            if r == "c":
                change = True
                continue
        break
    settings.update({"server": server.bin, "sources": server.sources, "client": client.folder})

    mysql = find_mysql(server, settings, args.mysql)
    while mysql is None:
        if not interactive:
            raise InstallerError("mysql client not found (--mysql)")
        mysql = ask_path("mysql.exe program (MySQL client, in the bin folder of MySQL Server)?", folder=False)
        if mysql is None:
            raise InstallerError("mysql client not given: the database can be neither read nor cleaned")
    settings["mysql"] = mysql
    dbs = {key: Database(mysql, info) for key, info in server.databases.items()}
    try:
        dbs["world"].run("SELECT 1;")
    except InstallerError as e:
        raise InstallerError("the database does not answer (is MySQL running?) - %s" % e)
    return server, client, dbs


def run_module(M, args, settings):
    """Installs or removes module M; returns the exit code."""
    interactive = not args.yes
    say("%s - WoW-mods installer" % M.title)
    say("=" * 60)
    say("First run: installs the module. Run again while the module (or part of it)")
    say("is present: removes everything that is left.")
    server, client, dbs = prepare(M, args, settings, interactive)
    save_settings(settings)
    if is_inside(M.root, server.modules):
        raise InstallerError("this package is stored in the server's modules folder (%s): put it somewhere else, "
                             "for example in Downloads, and run the installer from there" % M.root)

    heading("Current state")
    say("  (reading the game archives, a few seconds)")
    state = survey(M, server, client, dbs)
    print_state(state)
    if state.has_conflicts():
        say("  Carry its identifiers without proof that they are its own:")
        print_conflicts(state)
    for path, message in client.unreadable:
        say("  archive ignored, unreadable: %s (%s)" % (path, message))
    if args.status:
        return 0

    # Nothing is written while the worldserver or the game runs.
    ws = running_worldservers(server)
    if ws:
        raise InstallerError("the worldserver is running (%s): stop it, then run the installer again"
                             % ", ".join(p or n for n, p in ws))
    game = running_game(client)
    if game:
        raise InstallerError("the game is open (%s): close it, then run the installer again"
                             % ", ".join(p for n, p in game))

    say()
    if state.strong():
        say("The module is present, in whole or in part: this run will REMOVE everything that is")
        say("left of it: files, DBC rows and database data (players' data included).")
        if state.server_conflicts or state.client_conflicts or state.file_conflicts:
            say("DBC rows and game files that carry its identifiers without being its own stay in place.")
        if interactive:
            r = input("Type YES then Enter to remove everything; anything else to cancel. ").strip()
            if r.upper() != "YES":
                say("Cancelled: nothing was changed.")
                return 0
        remove(M, server, client, dbs, state)
        return check_removal(M, server, client, dbs)
    if state.weak():
        say("CONFLICT: these items carry the module's identifiers, but nothing proves they are")
        say("its own. Installation is impossible while they are there.")
        say("If they are LEFTOVERS of an installation of the module, they can be removed (the")
        say("database rows and DBC rows; never a game file provided by another archive). If they")
        say("belong to other content, its identifiers or the module's have to change.")
        if interactive:
            r = input("Type LEFTOVERS then Enter to remove them; anything else to stop. ").strip()
            leftovers = r.upper() == "LEFTOVERS"
        else:
            leftovers = args.leftovers
        if not leftovers:
            say("Stopped: nothing was changed.")
            return 1
        remove(M, server, client, dbs, state, leftovers=True)
        return check_removal(M, server, client, dbs)

    say("No trace of the module: this run will INSTALL it.")
    if interactive:
        input("Enter: install; close the window to cancel. ")
    try:
        install(M, server, client, dbs)
    except Exception:
        say()
        say("The installation stopped midway. Run the installer again: it removes what was put")
        say("in place; run it once more to install.")
        raise
    client = Client(client.folder)
    missing = missing_after_install(M, server, client)
    heading("Check")
    if missing:
        raise InstallerError("after installation, missing: %s" % "; ".join(missing))
    say("  sources, configuration, scripts, DBC rows and game files in place, read back from disk")
    say()
    say("Installation complete.")
    print_build_steps(server)
    if server.updates_mask & 6 == 6:
        say("On first start, the core updater applies the module's SQL.")
    else:
        say("The installer applied the module's SQL itself: the core updater is off")
        say("(Updates.EnableDatabases in worldserver.conf).")
    return 0


def check_removal(M, server, client, dbs):
    left = survey(M, server, Client(client.folder), dbs)
    heading("Check")
    if left.strong():
        print_state(left)
        raise InstallerError("traces remain (above)")
    say("  no trace of the module left, state read again from disk and database")
    if left.has_conflicts():
        say("  stay in place, because they are not its own:")
        print_conflicts(left)
    say()
    say("Uninstallation complete.")
    print_build_steps(server)
    say("Then the module is gone from the worldserver.")
    return 0


def choose_module(args, settings, interactive):
    """The module folder: from the command line (a folder dropped on
    installer.exe arrives that way), otherwise asked."""
    folder = args.module
    while True:
        if folder:
            folder = os.path.normpath(os.path.abspath(folder))
            if os.path.isfile(folder) and os.path.basename(folder).lower() == MANIFEST_NAME:
                folder = os.path.dirname(folder)
            if os.path.isfile(os.path.join(folder, MANIFEST_NAME)):
                return folder
            say("  no %s in %s" % (MANIFEST_NAME, folder))
        if not interactive:
            raise InstallerError("the module folder must be given (the one that contains %s)" % MANIFEST_NAME)
        folder = ask_path("Module folder to install or remove (the one that contains %s)?" % MANIFEST_NAME,
                          initial=settings.get("module"))
        if folder is None:
            raise InstallerError("no module folder chosen")


def main(load_manifest):
    """Entry point. load_manifest(folder) returns the module description."""
    if not sys.stdout.isatty():
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Installs a module, or removes it if it is present.")
    p.add_argument("module", nargs="?", help="module folder (the one that contains %s)" % MANIFEST_NAME)
    p.add_argument("--server", help="worldserver folder (the one that contains worldserver.exe)")
    p.add_argument("--sources", help="AzerothCore sources folder")
    p.add_argument("--client", help="game folder")
    p.add_argument("--mysql", help="path of mysql.exe")
    p.add_argument("--status", action="store_true", help="show the current state, change nothing")
    p.add_argument("--yes", action="store_true", help="ask nothing (paths from the options or remembered)")
    p.add_argument("--leftovers", action="store_true",
                   help="with --yes: the conflicting items are leftovers of the module, remove them")
    args = p.parse_args()
    code = 1
    settings = load_settings()
    try:
        folder = choose_module(args, settings, not args.yes)
        settings["module"] = folder
        code = run_module(load_manifest(folder), args, settings)
    except InstallerError as e:
        say()
        say("FAILED: %s" % e)
    except mpq_archive.MpqError as e:
        say()
        say("FAILED (MPQ archive): %s" % e)
    except PermissionError as e:
        say()
        say("FAILED: access denied to %s (file open in another program?)" % e.filename)
    except KeyboardInterrupt:
        say()
        say("Interrupted.")
    except Exception:
        say()
        say("UNEXPECTED ERROR:")
        say(traceback.format_exc())
        code = 2
    if not args.yes:
        try:
            input("\nEnter to close. ")
        except (EOFError, KeyboardInterrupt):
            pass
    sys.exit(code)
