# -*- coding: utf-8 -*-
"""Reads and checks a module's manifest, installer.json (MIT licence).

The manifest declares what the module puts in place and removes; its format
is described in MANIFEST.md. Everything is checked here, before the
engine touches anything: an incomplete manifest or a file missing from the
package stops the installer with a message that names it."""
import glob
import json
import os
import re

from core import InstallerError, MANIFEST_NAME, dbc_split, row_values, sql_list

FORMAT = "wow-mods-installer/1"


class DbcDef(object):
    """The module's rows in one DBC file.

    fields: field count; text: indices of the text fields; client / server:
    the rows to write on that side (None: that side is not touched), each row
    being the list of its values, a string for a text field, an integer
    otherwise."""

    def __init__(self, file, fields, text, client, server):
        self.file, self.fields, self.text = file, fields, text
        self.client, self.server = client, server
        self.client_ids = [r[0] for r in client or []]
        self.server_ids = [r[0] for r in server or []]
        self.ids = sorted(set(self.client_ids) | set(self.server_ids))


class Module(object):
    pass


def _error(where, why):
    raise InstallerError("%s: %s (%s)" % (MANIFEST_NAME, why, where))


def _indices(value, where):
    """Indices, or [first, last] ranges, as a set."""
    out = set()
    for v in value or []:
        if isinstance(v, int):
            out.add(v)
        elif isinstance(v, list) and len(v) == 2 and all(isinstance(x, int) for x in v):
            out.update(range(v[0], v[1] + 1))
        else:
            _error(where, "index or [first, last] range expected, not %r" % (v,))
    return out


def _row(value, fields, text, where):
    """A row declared in the manifest, as a list of values: an object
    {index: value} (missing fields are 0 or the empty string) or a full list."""
    if isinstance(value, dict):
        row = [0] * fields
        for k, v in value.items():
            try:
                i = int(k)
            except ValueError:
                _error(where, "field index %r" % k)
            if not 0 <= i < fields:
                _error(where, "field %d outside the file (%d fields)" % (i, fields))
            row[i] = v
    elif isinstance(value, list):
        if len(value) != fields:
            _error(where, "%d values for %d fields" % (len(value), fields))
        row = list(value)
    else:
        _error(where, "a row is an object or a list")
    out = []
    for i, v in enumerate(row):
        if i in text:
            if v in (0, None):
                v = ""
            if not isinstance(v, str):
                _error(where, "text field %d expects a string, not %r" % (i, v))
            out.append(v)
        else:
            if isinstance(v, bool) or not isinstance(v, int):
                _error(where, "field %d expects an integer, not %r" % (i, v))
            out.append(v & 0xFFFFFFFF)
    if not out[0]:
        _error(where, "a row without identifier (field 0)")
    return out


def _reduced_dbc(path, fields, text, where):
    """The rows of a reduced DBC of the package (holding only the module's rows)."""
    if not os.path.isfile(path):
        _error(where, "file missing from the package: %s" % path)
    with open(path, "rb") as f:
        raw = f.read()
    n, recs, strings = dbc_split(raw, path)
    if n != fields:
        _error(where, "%s has %d fields, %d declared" % (path, n, fields))
    return [row_values(r, strings, fields, text) for r in recs]


def _dbc(root, entry, i):
    where = "dbc[%d]" % i
    if not isinstance(entry, dict):
        _error(where, "object expected")
    file = entry.get("file")
    fields = entry.get("fields")
    if not isinstance(file, str) or not file.lower().endswith(".dbc"):
        _error(where, '"file": the DBC file name')
    if not isinstance(fields, int) or fields < 1:
        _error(where, '"fields": the field count of the file')
    where = "dbc %s" % file
    text = _indices(entry.get("text_fields"), where)
    rows = entry.get("rows")
    sides = {}
    for side in ("client", "server"):
        v = entry.get(side, False)
        if v is False or v is None:
            sides[side] = None
        elif v is True:
            if rows is None:
                _error(where, '"%s" is true: the rows go in "rows"' % side)
            sides[side] = [_row(r, fields, text, "%s, row %d" % (where, k)) for k, r in enumerate(rows)]
        elif isinstance(v, str):
            sides[side] = _reduced_dbc(os.path.join(root, v), fields, text, "%s, %s" % (where, side))
        else:
            _error(where, '"%s": true, false, or the path of a reduced DBC of the package' % side)
        if sides[side] is not None:
            ids = [r[0] for r in sides[side]]
            if len(set(ids)) != len(ids):
                _error(where, "duplicate identifier on the %s side" % side)
    if sides["client"] is None and sides["server"] is None:
        _error(where, 'neither "client" nor "server"')
    return DbcDef(file, fields, text, sides["client"], sides["server"])


def _game_files(root, entry):
    """({name in the archive: path}, [owned folders, lower case, ending with a backslash])."""
    files, owned = {}, []
    if not entry:
        return files, owned
    # extensions: only these files of the source folders (previews and notes stay out)
    extensions = tuple(e.lower() for e in entry.get("extensions", []))
    if any(not e.startswith(".") for e in extensions):
        _error("game_files", '"extensions": file extensions such as ".blp"')
    for source in entry.get("sources", []):
        base = os.path.join(root, source)
        if not os.path.isdir(base):
            _error("game_files", "folder missing from the package: %s" % source)
        for d, _, names in os.walk(base):
            for n in names:
                if extensions and not n.lower().endswith(extensions):
                    continue
                path = os.path.join(d, n)
                name = os.path.relpath(path, base).replace("/", "\\")
                if name.lower() in {k.lower() for k in files}:
                    _error("game_files", "%s provided twice" % name)
                files[name] = path
    for d in entry.get("owned_folders", []):
        d = d.replace("/", "\\").strip("\\")
        if d.count("\\") < 1:
            _error("game_files", '"owned_folders": a folder of the module only, such as Interface\\Module, not %r' % d)
        owned.append(d.lower() + "\\")
    return files, owned


def _addons(root, entry):
    """{addon name: package folder}: folders copied as they are into Interface\\AddOns of the
    game; each holds the .toc named after it."""
    addons = {}
    for source in entry or []:
        base = os.path.normpath(os.path.join(root, source))
        name = os.path.basename(base)
        if not os.path.isfile(os.path.join(base, name + ".toc")):
            _error("addons", "%s is not an addon folder (no %s.toc in it)" % (source, name))
        if name.lower() in {n.lower() for n in addons}:
            _error("addons", "addon %s declared twice" % name)
        addons[name] = base
    return addons


def _substitute(text, M, root, where):
    """Replaces the {ids:File.dbc} and {sql_files:db-world} placeholders of a condition."""
    def one(m):
        kind, value = m.group(1), m.group(2)
        if kind == "ids":
            d = [x for x in M.dbc if x.file.lower() == value.lower()]
            if not d:
                _error(where, "{ids:%s}: this DBC is not declared" % value)
            ids = d[0].ids
        else:
            folder = os.path.join(root, "data", "sql", value)
            ids = sorted({os.path.basename(p) for p in glob.glob(os.path.join(folder, "**", "*.sql"), recursive=True)})
        return sql_list(ids) if ids else "NULL"
    return re.sub(r"\{(ids|sql_files):([^}]+)\}", one, text)


def _databases(root, M, entry):
    dbs = {}
    for key, desc in (entry or {}).items():
        if key not in ("world", "characters"):
            _error("database", 'database %r: "world" or "characters"' % key)
        where = "database.%s" % key
        d = {"tables": list(desc.get("tables", [])), "rows": [], "before": []}
        for k, r in enumerate(desc.get("rows", [])):
            if not isinstance(r, dict) or "table" not in r or "where" not in r:
                _error(where, 'rows[%d]: { "table": ..., "where": ... }' % k)
            d["rows"].append((r["table"], _substitute(r["where"], M, root, where)))
        for k, b in enumerate(desc.get("before", [])):
            if not isinstance(b, dict) or "sql" not in b:
                _error(where, 'before[%d]: { "if_column": "table.column", "sql": ... }' % k)
            table, _, column = (b.get("if_column") or "").partition(".")
            if not table or not column:
                _error(where, 'before[%d]: "if_column" is table.column' % k)
            d["before"].append(((table, column), _substitute(b["sql"], M, root, where)))
        dbs[key] = d
    return dbs


def load(root):
    """The Module described by root/installer.json."""
    path = os.path.join(root, MANIFEST_NAME)
    try:
        with open(path, encoding="utf-8") as f:
            m = json.load(f)
    except ValueError as e:
        raise InstallerError("%s unreadable: %s" % (path, e))
    if not isinstance(m, dict) or m.get("format") != FORMAT:
        raise InstallerError("%s: unknown format %r (%s expected)"
                             % (path, m.get("format") if isinstance(m, dict) else None, FORMAT))
    M = Module()
    M.root = os.path.normpath(os.path.abspath(root))
    M.name = m.get("module")
    if not isinstance(M.name, str) or not re.match(r"^[A-Za-z0-9_.-]+$", M.name):
        _error("module", "the name of the module folder in modules/")
    M.title = m.get("title") or M.name
    # server_module false: a package for the game only (plus the server DBC rows); nothing goes
    # into the server's sources, configuration, scripts or databases
    M.server_module = m.get("server_module", True)
    if not isinstance(M.server_module, bool):
        _error("server_module", "true or false")
    if not M.server_module:
        server_keys = [k for k in ("signature", "exclude_from_sources", "configuration", "lua", "database")
                       if k in m]
        if server_keys:
            _error(server_keys[0], "a package without server module has no %s" % ", ".join(server_keys))
    M.signature = m.get("signature") or []
    if M.server_module and not M.signature:
        _error("signature", "at least one file that identifies the module in modules/")
    M.excluded = list(m.get("exclude_from_sources", []))
    M.conf = None
    if m.get("configuration"):
        c = m["configuration"]
        M.conf = {"file": c.get("file"), "template": c.get("template"), "values": c.get("values", {})}
        if not M.conf["file"] or not M.conf["template"]:
            _error("configuration", '"file" and "template"')
    M.lua = None
    if m.get("lua"):
        lua = m["lua"]
        M.lua = {"folder": lua.get("folder"), "files": list(lua.get("files", [])), "config_path": None}
        if not M.lua["folder"] or not M.lua["files"]:
            _error("lua", '"folder" and "files"')
        if lua.get("config_path"):
            M.lua["config_path"] = {"file": lua["config_path"].get("file"),
                                    "variable": lua["config_path"].get("variable")}
            if not M.conf:
                _error("lua", '"config_path" needs a "configuration"')
    M.dbc = [_dbc(M.root, e, i) for i, e in enumerate(m.get("dbc", []))]
    if len({d.file.lower() for d in M.dbc}) != len(M.dbc):
        _error("dbc", "a DBC file declared twice")
    M.game_files, M.owned_folders = _game_files(M.root, m.get("game_files"))
    M.addons = _addons(M.root, m.get("addons"))
    M.backups = list(m.get("backups", []))
    M.databases = _databases(M.root, M, m.get("database"))
    missing = [p for p in list(M.signature) + ([M.conf["template"]] if M.conf else []) +
               (M.lua["files"] if M.lua else []) if not os.path.isfile(os.path.join(M.root, p))]
    if missing:
        raise InstallerError("incomplete package (%s): %s missing" % (M.root, ", ".join(missing)))
    return M
