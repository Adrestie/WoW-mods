# -*- coding: utf-8 -*-
# This file is part of mod-forever-ui.
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

"""Deploy ForeverUI to a 3.3.5 client: the addon folder, and the art and login screens in patch-Z.

The repository is the source; the client only holds a copy.
  addon: copies data/addon/ForeverUI to the client, removing files no longer in the repository.
  art:   packs data/art/**.blp and the login scenery (Interface/Glues/Models) into patch-Z.MPQ;
         .png previews are not packed.
  glue:  packs data/glue/Interface/GlueXML/** (login screens, where no addon runs).
  dbc:   adds data/dbc/statistics.json to Achievement.dbc and Achievement_Criteria.dbc in
         patch-Z, copies them to the server (only if it held a copy of the client's), and
         writes their achievement_criteria_data rows. Restart the server afterwards.
Under each archive prefix, patch-Z holds exactly the repository: identical files are skipped,
extra files are removed. The archive is locked while the client runs: close the game first.
"""
import argparse
import hashlib
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from foreverui import mpq  # noqa: E402
from foreverui import dbc  # noqa: E402

DEFAULT_CLIENT = r"E:\world of warcraft 3.3.5a hd"
DEFAULT_SERVER = r"E:\Serveur\bin\RelWithDebInfo"     # folder of worldserver.exe
STATISTICS_FILE = os.path.join(ROOT, "data", "dbc", "statistics.json")
ADDON_NAME = "ForeverUI"
ARCHIVE_PREFIX = "interface" + os.sep + "ForeverUI" + os.sep
GLUE_PREFIX = "Interface" + os.sep + "GlueXML" + os.sep
SCENERY_PREFIX = "Interface" + os.sep + "Glues" + os.sep + "Models" + os.sep

# Addon files the login screens also use: one source, packed under its own name in
# Interface\GlueXML (addon file -> name in the archive).
SHARED_WITH_GLUE = {
    "ScrollBar.lua": "ForeverUIScrollBar.lua",
}


def _fingerprint(data):
    return hashlib.sha1(data).hexdigest()


def install_addon(client, verbose=True):
    source = os.path.join(ROOT, "data", "addon", ADDON_NAME)
    target = os.path.join(client, "Interface", "AddOns", ADDON_NAME)
    os.makedirs(target, exist_ok=True)

    expected = set()
    placed, unchanged = 0, 0
    for name in sorted(os.listdir(source)):
        if not (name.endswith(".lua") or name.endswith(".toc")):
            continue
        expected.add(name)
        raw = io.open(os.path.join(source, name), "rb").read()
        path = os.path.join(target, name)
        if os.path.exists(path) and io.open(path, "rb").read() == raw:
            unchanged += 1
            continue
        io.open(path, "wb").write(raw)
        placed += 1

    removed = []
    for name in sorted(os.listdir(target)):
        if (name.endswith(".lua") or name.endswith(".toc")) and name not in expected:
            os.remove(os.path.join(target, name))
            removed.append(name)

    if verbose:
        print("addon : %d pose(s), %d inchange(s), %d retire(s) %s" % (
            placed, unchanged, len(removed), removed or ""))
    return placed, removed


def _archive_art(archive, prefix=ARCHIVE_PREFIX):
    """Paths the archive holds under prefix (Interface/ForeverUI by default), from its listfile."""
    if not archive.has("(listfile)"):
        return set()
    text = archive.read("(listfile)").decode("utf-8", "replace")
    contents = set()
    for row in text.splitlines():
        name = row.strip().replace("/", os.sep)
        if name.lower().startswith(prefix.lower()):
            contents.add(name)
    return contents


def _art_files(prefix=ARCHIVE_PREFIX):
    """Archive path -> disk path, for the data/art files under prefix."""
    base = os.path.join(ROOT, "data", "art")
    matches = {}
    for root, _dirs, files in os.walk(base):
        for name in files:
            # art, and the login screen scenery (tools/glue_scenery.py)
            if not name.lower().endswith((".blp", ".m2", ".skin")):
                continue
            path = os.path.join(root, name)
            internalPath = os.path.relpath(path, base).replace("/", os.sep)
            if internalPath.lower().startswith(prefix.lower()):
                matches[internalPath] = path
    return matches


def _glue_files():
    """Archive path -> disk path, for the login screen files."""
    base = os.path.join(ROOT, "data", "glue")
    matches = {}
    # No login screens in the repository: nothing, not even the shared files,
    # so the archive goes back to the client's
    if not os.path.isdir(base):
        return matches
    for root, _dirs, files in os.walk(base):
        for name in files:
            if not name.lower().endswith((".lua", ".xml", ".toc")):
                continue
            path = os.path.join(root, name)
            internalPath = os.path.relpath(path, base).replace("/", os.sep)
            assert internalPath.lower().startswith(GLUE_PREFIX.lower()), internalPath
            matches[internalPath] = path
    for source, name in SHARED_WITH_GLUE.items():
        matches[GLUE_PREFIX + name] = os.path.join(ROOT, "data", "addon", ADDON_NAME, source)
    return matches


# Path of the client's patch-Z.MPQ.
def _archive_z(client):
    archive_path = os.path.join(client, "data", "patch-Z.MPQ")
    if not os.path.exists(archive_path):
        archive_path = os.path.join(client, "Data", "patch-Z.MPQ")
    if not os.path.exists(archive_path):
        raise SystemExit("patch-Z.MPQ introuvable dans %s" % client)
    return archive_path


def install_art(client, verbose=True):
    return (_push(client, _art_files(), ARCHIVE_PREFIX, "art", verbose)
            + _push(client, _art_files(SCENERY_PREFIX), SCENERY_PREFIX, "decors", verbose))


def install_glue(client, verbose=True):
    return _push(client, _glue_files(), GLUE_PREFIX, "glue", verbose)


# Makes patch-Z hold exactly the art files under prefix; title labels the output.
def _push(client, art, prefix, title, verbose=True):
    archive_path = _archive_z(client)

    # Push only what changed, and list what no longer belongs.
    to_push = {}
    to_remove = []
    archive = mpq.Archive(archive_path)
    try:
        for internalPath, path in sorted(art.items()):
            raw = io.open(path, "rb").read()
            if archive.has(internalPath) and _fingerprint(archive.read(internalPath)) == _fingerprint(raw):
                continue
            to_push[internalPath] = raw

        expected = set(n.lower() for n in art)
        to_remove = sorted(n for n in _archive_art(archive, prefix)
                           if n.lower() not in expected)
    finally:
        archive.close()

    if not to_push and not to_remove:
        if verbose:
            print("%s : %d fichiers, l'archive est deja le calque du depot" % (title, len(art)))
        return 0

    before = os.path.getsize(archive_path)
    try:
        mpq.patch_archive(archive_path, to_push, remove=to_remove)
    except PermissionError:
        raise SystemExit("patch-Z.MPQ est verrouille : fermer le client avant de verser.")

    archive = mpq.Archive(archive_path)
    try:
        anomalies = [n for n, raw in to_push.items()
                     if _fingerprint(archive.read(n)) != _fingerprint(raw)]
    finally:
        archive.close()

    if verbose:
        print("%s : %d verse(s) sur %d, %d retire(s) | archive %.3f -> %.3f Gio | relecture : %d anomalie(s)" % (
            title, len(to_push), len(art), len(to_remove), before / (1024.0 ** 3),
            os.path.getsize(archive_path) / (1024.0 ** 3), len(anomalies)))
        for n in to_remove:
            print("   retire : %s" % n)
    if anomalies:
        raise SystemExit("relecture fausse : %s" % ", ".join(anomalies))
    return len(to_push) + len(to_remove)


# ------------------------------------------------------------------ statistics

LOCALE_COUNT = 16
TEXT_MASK = 0xFF01FE            # mask of the 3.3.5 rows
REWARD_MASK = 0xFF01EE
ICON = 1                          # icon of the 3.3.5 statistics without their own
DBC_FILES = ("Achievement.dbc", "Achievement_Criteria.dbc")


def _texts(t):
    # Same text in all sixteen locale columns: a client in another language reads its own column
    # and finds the name instead of nothing
    return [t] * LOCALE_COUNT


def statistics_rows():
    """{file: dbc.Rows} built from data/dbc/statistics.json."""
    import json
    d = json.load(io.open(STATISTICS_FILE, encoding="utf-8"))
    if d.get("_format") != "foreverui-statistics-dbc-1":
        raise SystemExit("%s : format inconnu" % STATISTICS_FILE)
    achievements, criteria = [], []
    for s in d["statistics"]:
        # Achievement.dbc (62 fields): ID, faction, map, previous, title x16 + mask,
        # description x16 + mask, category, points, order, flags, icon, reward x16 + mask,
        # minimum criteria, shares criteria
        achievements.append([s["id"], -1, s["map"], 0] + _texts(s["name"]) + [TEXT_MASK] +
                     _texts(s["name"]) + [TEXT_MASK] +
                     [s["category"], s["points"], s["order"], s["flags"], ICON] +
                     _texts("") + [REWARD_MASK, 0, 0])
        for c in s["criteria"]:
            # Achievement_Criteria.dbc (31 fields): ID, achievement, type, target, quantity,
            # start (event, target), fail (event, target), description x16 + mask, flags,
            # timer (event, target, duration), order
            criteria.append([c["id"], s["id"], c["type"], c["target"], c["quantity"], 0, 0, 0, 0] +
                            _texts(c["text"]) + [TEXT_MASK, 0, 0, 0, 0, 1])
    return {"Achievement.dbc": dbc.Rows(62, list(range(4, 20)) + list(range(21, 37)) + list(range(43, 59)),
                                          achievements),
            "Achievement_Criteria.dbc": dbc.Rows(31, list(range(9, 25)), criteria)}


def _data_dir(client):
    for n in os.listdir(client):
        if n.lower() == "data" and os.path.isdir(os.path.join(client, n)):
            return os.path.join(client, n)
    raise SystemExit("pas de dossier Data dans %s" % client)


def _locale(data):
    """The client's locale folder: the Data subfolder that holds archives."""
    for n in sorted(os.listdir(data)):
        d = os.path.join(data, n)
        if os.path.isdir(d) and any(f.lower().endswith(".mpq") for f in os.listdir(d)):
            return n
    return None


def server_dbc_dir(server):
    """The server DBC folder: DataDir from its worldserver.conf, + dbc."""
    conf = next((c for c in (os.path.join(server, "configs", "worldserver.conf"),
                             os.path.join(server, "worldserver.conf")) if os.path.isfile(c)), None)
    if not conf:
        raise SystemExit("worldserver.conf introuvable dans %s" % server)
    data = "."
    for row in io.open(conf, encoding="utf-8", errors="replace"):
        row = row.strip()
        if row.startswith("DataDir") and "=" in row:
            data = row.split("=", 1)[1].strip().strip('"')
    if not os.path.isabs(data):
        data = os.path.join(server, data)
    return os.path.join(os.path.normpath(data), "dbc")


def _close(chain):
    for a in chain.archives:
        a.close()


def install_dbc(client, server, remove=False, verbose=True):
    """Writes the statistics into the client DBCs (patch-Z), then the server's.
    remove: take them out instead.
    """
    rows = statistics_rows()
    data = _data_dir(client)
    language = _locale(data)
    archive_z = _archive_z(client)
    server_dir = server_dbc_dir(server)
    chain = mpq.open_client(data, language)
    below = mpq.open_client(data, language, ignore=(os.path.basename(archive_z),))
    z = mpq.Archive(archive_z)
    to_push, to_remove, for_server = {}, [], {}
    try:
        for file in DBC_FILES:
            name = "DBFilesClient\\" + file
            current = chain.read(name)
            d = rows[file]
            if remove:
                fresh, n = dbc.remove(current, name, d)
            else:
                fresh, n = dbc.add(current, name, d), len(d.ids)
            if fresh == below.read(name):
                # Nothing beyond the original version: the patch-Z copy is no longer needed
                if z.has(name):
                    to_remove.append(name)
            elif fresh != current:
                to_push[name] = fresh
            for_server[file] = (current, fresh)
            if verbose:
                print("dbc : %s, %d ligne(s) %s" % (file, n, "retiree(s)" if remove else "posee(s)"))
    finally:
        _close(chain)
        _close(below)
        z.close()
    if to_push or to_remove:
        try:
            mpq.patch_archive(archive_z, to_push, remove=to_remove)
        except PermissionError:
            raise SystemExit("patch-Z.MPQ est verrouille : fermer le client avant de verser.")
        if verbose:
            print("dbc : patch-Z, %d ecrit(s), %d retire(s)" % (len(to_push), len(to_remove)))
    elif verbose:
        print("dbc : patch-Z deja conforme")
    # The server becomes a copy of the client, only if it already was one
    for file, (before, after) in for_server.items():
        p = os.path.join(server_dir, file)
        current = io.open(p, "rb").read() if os.path.isfile(p) else None
        if current == after:
            continue
        if current != before:
            print("dbc : %s n'est pas la copie de celui du client : laisse tel quel" % p)
            continue
        io.open(p + ".foreverui-tmp", "wb").write(after)
        os.replace(p + ".foreverui-tmp", p)
        if verbose:
            print("dbc : %s recopie du client (redemarrer le worldserver)" % p)
    install_data(server, remove, verbose)


# worldserver.conf settings as a dict.
def _server_conf(server):
    conf = next((c for c in (os.path.join(server, "configs", "worldserver.conf"),
                             os.path.join(server, "worldserver.conf")) if os.path.isfile(c)), None)
    if not conf:
        raise SystemExit("worldserver.conf introuvable dans %s" % server)
    values = {}
    for row in io.open(conf, encoding="utf-8", errors="replace"):
        row = row.strip()
        if "=" in row and not row.startswith("#"):
            key, value = row.split("=", 1)
            values[key.strip()] = value.strip().strip('"')
    return values


def _mysql(server):
    """The mysql client: from worldserver.conf, the one saved by the repository installers,
    or the one on PATH.
    """
    import json
    import shutil
    candidates = [_server_conf(server).get("MySQLExecutable")]
    try:
        memory_file = os.path.join(os.environ.get("APPDATA") or "", "WoW-mods", "installeur.json")
        candidates.append(json.load(io.open(memory_file, encoding="utf-8")).get("mysql"))
    except (OSError, ValueError):
        pass
    candidates.append(shutil.which("mysql"))
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    raise SystemExit("client mysql introuvable (MySQLExecutable dans worldserver.conf)")


def _sql(server, query):
    """Runs a query on the server's world database; returns the rows as text fields."""
    import subprocess
    info = _server_conf(server).get("WorldDatabaseInfo", "").split(";")
    if len(info) != 5:
        raise SystemExit("WorldDatabaseInfo illisible dans worldserver.conf")
    host, port, user, password, base = info
    env = dict(os.environ, MYSQL_PWD=password)
    r = subprocess.run([_mysql(server), "-h", host, "-P", port, "-u", user, base, "-N", "-B",
                        "-e", query], capture_output=True, text=True, env=env)
    if r.returncode != 0:
        raise SystemExit("mysql : %s" % r.stderr.strip())
    return [l.split("\t") for l in r.stdout.splitlines() if l]


def statistics_data():
    """[(criterion, type, value1, value2)]: our achievement_criteria_data rows."""
    import json
    d = json.load(io.open(STATISTICS_FILE, encoding="utf-8"))
    rows = []
    for s in d["statistics"]:
        for c in s["criteria"]:
            for x in c.get("data", []):
                rows.append((c["id"], x["type"], x["value1"], x["value2"]))
    return rows


# Criterion ids of all statistics.
def _statistic_criteria():
    import json
    d = json.load(io.open(STATISTICS_FILE, encoding="utf-8"))
    return [c["id"] for s in d["statistics"] for c in s["criteria"]]


def install_data(server, remove=False, verbose=True):
    """Our achievement_criteria_data rows: deleted by criterion id, then inserted unless removing.
    Some criteria count only with a row there (a creature kill, for example). The core reads
    them at startup (or with .reload achievement_criteria_data).
    """
    ids = ", ".join(str(i) for i in _statistic_criteria())
    rows = [] if remove else statistics_data()
    query = "DELETE FROM achievement_criteria_data WHERE criteria_id IN (%s);" % ids
    if rows:
        query += " INSERT INTO achievement_criteria_data (criteria_id, type, value1, value2, ScriptName) VALUES %s;" % (
            ", ".join("(%d, %d, %d, %d, '')" % l for l in rows))
    _sql(server, query)
    if verbose:
        print("dbc : achievement_criteria_data, %d ligne(s) %s" % (
            len(statistics_data()) if remove else len(rows), "retiree(s)" if remove else "posee(s)"))


# Are our achievement_criteria_data rows in the world database, unchanged?
def verify_data(server):
    ids = ", ".join(str(i) for i in _statistic_criteria())
    loaded = sorted(tuple(int(v) for v in l) for l in _sql(
        server, "SELECT criteria_id, type, value1, value2 FROM achievement_criteria_data WHERE criteria_id IN (%s)" % ids))
    if loaded != sorted(statistics_data()):
        return ["achievement_criteria_data : lignes des statistiques absentes ou differentes"]
    return []


def verify_dbc(client, server):
    """Are the statistics in the client DBCs, and is the server a copy of them?"""
    mismatches = []
    rows = statistics_rows()
    data = _data_dir(client)
    chain = mpq.open_client(data, _locale(data))
    try:
        for file in DBC_FILES:
            name = "DBFilesClient\\" + file
            current = chain.read(name)
            if dbc.add(current, name, rows[file]) != current:
                mismatches.append("statistiques absentes ou differentes dans le DBC du client : %s" % file)
            p = os.path.join(server_dbc_dir(server), file)
            if not os.path.isfile(p) or io.open(p, "rb").read() != current:
                mismatches.append("DBC du serveur different de celui du client : %s" % file)
    finally:
        _close(chain)
    return mismatches + verify_data(server)


def check(client, server=DEFAULT_SERVER):
    """Does what is deployed still match the repository?"""
    source = os.path.join(ROOT, "data", "addon", ADDON_NAME)
    target = os.path.join(client, "Interface", "AddOns", ADDON_NAME)
    mismatches = []
    for name in sorted(os.listdir(source)):
        if not (name.endswith(".lua") or name.endswith(".toc")):
            continue
        installed = os.path.join(target, name)
        if not os.path.exists(installed):
            mismatches.append("absent du client : %s" % name)
        elif io.open(installed, "rb").read() != io.open(os.path.join(source, name), "rb").read():
            mismatches.append("different : %s" % name)

    archive_path = os.path.join(client, "data", "patch-Z.MPQ")
    if os.path.exists(archive_path):
        archive = mpq.Archive(archive_path)
        try:
            for art, prefix in ((_art_files(), ARCHIVE_PREFIX), (_glue_files(), GLUE_PREFIX),
                                 (_art_files(SCENERY_PREFIX), SCENERY_PREFIX)):
                for internalPath, path in sorted(art.items()):
                    raw = io.open(path, "rb").read()
                    if not archive.has(internalPath):
                        mismatches.append("absent de l'archive : %s" % internalPath)
                    elif _fingerprint(archive.read(internalPath)) != _fingerprint(raw):
                        mismatches.append("different dans l'archive : %s" % internalPath)

                expected = set(n.lower() for n in art)
                for n in sorted(_archive_art(archive, prefix)):
                    if n.lower() not in expected:
                        mismatches.append("en trop dans l'archive : %s" % n)
        finally:
            archive.close()

    mismatches += verify_dbc(client, server)

    if mismatches:
        print("ecarts entre le depot et le client : %d" % len(mismatches))
        for e in mismatches:
            print("   %s" % e)
    else:
        print("le client est conforme au depot")
    return mismatches


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--client", default=DEFAULT_CLIENT, help="dossier du client 3.3.5")
    parser.add_argument("--addon", action="store_true", help="ne poser que l'addon")
    parser.add_argument("--art", action="store_true", help="ne verser que l'art")
    parser.add_argument("--glue", action="store_true", help="ne verser que les ecrans d'accueil")
    parser.add_argument("--dbc", action="store_true",
                           help="ne poser que les statistiques dans les DBC du client et du serveur")
    parser.add_argument("--remove-dbc", action="store_true",
                           help="retirer les statistiques des DBC du client et du serveur")
    parser.add_argument("--server", default=DEFAULT_SERVER, help="dossier du worldserver")
    parser.add_argument("--check", action="store_true",
                           help="ne rien ecrire, seulement comparer")
    options = parser.parse_args()

    if options.check:
        check(options.client, options.server)
        return
    if options.remove_dbc:
        install_dbc(options.client, options.server, remove=True)
        return

    all_ = not (options.addon or options.art or options.glue or options.dbc)
    if all_ or options.addon:
        install_addon(options.client)
    if all_ or options.art:
        install_art(options.client)
    if all_ or options.glue:
        install_glue(options.client)
    if all_ or options.dbc:
        install_dbc(options.client, options.server)


if __name__ == "__main__":
    main()
