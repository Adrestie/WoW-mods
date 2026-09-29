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

from core import InstallerError, MANIFEST_NAME, dbc_split, read_version, row_values, sql_list

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
    n, size, recs, strings = dbc_split(raw, path)
    if n != fields:
        _error(where, "%s has %d fields, %d declared" % (path, n, fields))
    return [row_values(r, strings, text) for r in recs]


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


def _replaced(files, entry):
    """Lower-case names of the module's game files that replace, on purpose, the version another
    custom archive provides: `replaces` lists files or folders, each naming at least one of them."""
    out = set()
    for item in (entry or {}).get("replaces", []):
        wanted = item.replace("/", "\\").strip("\\").lower()
        matched = {n.lower() for n in files if n.lower() == wanted or n.lower().startswith(wanted + "\\")}
        if not matched:
            _error("game_files", '"replaces": %r names none of the module\'s game files' % item)
        out |= matched
    return out


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


def _lua(root, entry, has_conf):
    """The module's Lua scripts: {"folder", "files": {path under the folder: package path},
    "config_path"}. `files` are copied flat into the folder, `sources` are package folders
    whose tree is copied into it."""
    lua = {"folder": entry.get("folder"), "files": {}, "anywhere": [], "config_path": None}
    if not isinstance(lua["folder"], str) or not lua["folder"].strip("/\\") or \
            any(c in lua["folder"] for c in "/\\:"):
        _error("lua", '"folder": the name of the module\'s folder in the scripts folder')
    found = []
    for p in entry.get("files", []):
        found.append((os.path.basename(p), os.path.join(root, p)))
        lua["anywhere"].append(os.path.basename(p))
    for source in entry.get("sources", []):
        base = os.path.join(root, source)
        if not os.path.isdir(base):
            _error("lua", "folder missing from the package: %s" % source)
        for d, _, names in os.walk(base):
            found += [(os.path.relpath(os.path.join(d, n), base), os.path.join(d, n)) for n in names]
    if not found:
        _error("lua", '"files" or "sources": the scripts to copy')
    for name, path in found:
        if name.lower() in {k.lower() for k in lua["files"]}:
            _error("lua", "%s provided twice" % name)
        lua["files"][name] = path
    if entry.get("config_path"):
        cp = entry["config_path"]
        lua["config_path"] = {"file": os.path.normpath(cp.get("file") or ""), "variable": cp.get("variable")}
        if not has_conf:
            _error("lua", '"config_path" needs a "configuration"')
        if lua["config_path"]["file"].lower() not in {k.lower() for k in lua["files"]}:
            _error("lua", '"config_path": %r is none of the module\'s scripts' % cp.get("file"))
    return lua


def _shared(root, M, entries):
    """Components several modules carry (the workbench): [{"folder", "source", "version",
    "provider_mark", "databases"}]. The folder goes into the scripts folder unless a copy of the same
    or a newer version is there; it goes, with its database rows, with the last module that uses it."""
    out = []
    for k, e in enumerate(entries or []):
        where = "shared[%d]" % k
        if not isinstance(e, dict):
            _error(where, "object expected")
        folder, source, mark = e.get("folder"), e.get("source"), e.get("provider_mark")
        if not isinstance(folder, str) or not folder or any(c in folder for c in "/\\:"):
            _error(where, '"folder": the name of the component\'s folder in the scripts folder')
        if M.lua and folder.lower() == M.lua["folder"].lower():
            _error(where, "the component's folder is the module's own Lua folder")
        if not isinstance(source, str) or not os.path.isdir(os.path.join(root, source)):
            _error(where, '"source": a folder of the package (%r)' % source)
        if not isinstance(mark, str) or not mark:
            _error(where, '"provider_mark": the text a script of a module that uses the component holds')
        version = e.get("version_file", "VERSION")
        if read_version(os.path.join(root, source), version) is None:
            _error(where, "%s/%s: a whole number expected" % (source, version))
        dbs = _databases(root, M, e.get("database"))
        if any(d["tables"] or d["before"] for d in dbs.values()):
            _error(where, 'the component\'s "database" holds "rows" only')
        out.append({"folder": folder, "source": os.path.join(root, source), "version_file": version,
                    "provider_mark": mark, "databases": dbs})
    return out


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
        server_keys = [k for k in ("signature", "exclude_from_sources", "configuration", "lua", "database",
                                   "shared") if k in m]
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
    M.lua = _lua(M.root, m["lua"], bool(M.conf)) if m.get("lua") else None
    M.dbc = [_dbc(M.root, e, i) for i, e in enumerate(m.get("dbc", []))]
    if len({d.file.lower() for d in M.dbc}) != len(M.dbc):
        _error("dbc", "a DBC file declared twice")
    M.game_files, M.owned_folders = _game_files(M.root, m.get("game_files"))
    M.replaced = _replaced(M.game_files, m.get("game_files"))
    M.addons = _addons(M.root, m.get("addons"))
    M.backups = list(m.get("backups", []))
    M.databases = _databases(M.root, M, m.get("database"))
    M.shared = _shared(M.root, M, m.get("shared"))
    missing = [p for p in list(M.signature) + ([M.conf["template"]] if M.conf else [])
               if not os.path.isfile(os.path.join(M.root, p))]
    missing += [os.path.relpath(p, M.root) for p in (M.lua["files"].values() if M.lua else [])
                if not os.path.isfile(p)]
    if missing:
        raise InstallerError("incomplete package (%s): %s missing" % (M.root, ", ".join(missing)))
    return M
