#!/bin/sh
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
#
# The same questions as install.bat, for a server that runs on Linux or
# macOS -- which is most of them. Plain POSIX sh: nothing here needs bash.

set -u
cd "$(dirname "$0")" || exit 1

echo
echo "  mod-spheregrid"
echo "  --------------"
echo "  A sphere grid for AzerothCore 3.3.5a."
echo
echo "  This looks at your server, keeps a copy of everything it is about to"
echo "  touch, then places the module and applies its SQL. Nothing is written"
echo "  before the copies exist."
echo

# --- Python ---------------------------------------------------------------
# Asked to RUN, not merely to exist: on Windows a `python3` stub answers to
# `command -v` and then opens the Store instead of running anything.
PY=""
for candidate in python3 python; do
    if "$candidate" -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" >/dev/null 2>&1; then
        PY="$candidate"
        break
    fi
done
if [ -z "$PY" ]; then
    echo "  Python 3 was not found. Install it (python3), then run this again."
    exit 1
fi

ask() {
    # ask <variable name> <prompt> [default]
    printf '      %s' "$2"
    read -r answer
    if [ -z "$answer" ] && [ $# -ge 3 ]; then
        answer="$3"
    fi
    eval "$1=\$answer"
}

# --- 1. the server --------------------------------------------------------
echo "  1. The SERVER directory: the one holding worldserver, with its"
echo "     etc/ (or configs/) and lua_scripts/ beside it."
ask SERVER "path: "
if [ -z "$SERVER" ]; then echo "  Nothing entered."; exit 1; fi
if [ ! -d "$SERVER" ]; then echo "  $SERVER is not a directory."; exit 1; fi

# --- 2. the core ----------------------------------------------------------
echo
echo "  2. The AZEROTHCORE SOURCE directory: the one with a modules/ folder."
echo "     The module's sources go there, and you rebuild afterwards."
ask CORE "path: "
if [ -z "$CORE" ]; then echo "  Nothing entered."; exit 1; fi
if [ ! -d "$CORE/modules" ]; then echo "  $CORE has no modules/ folder."; exit 1; fi

# --- 3. the client --------------------------------------------------------
echo
echo "  3. The CLIENT's Data directory, the one holding the .MPQ archives."
echo "     Leave blank to skip the client; the server half is installed anyway."
ask CLIENT "path (optional): "
LOCALE=enUS
if [ -n "$CLIENT" ]; then
    echo
    echo "     Which locale is that client? enUS, frFR, deDE..."
    ask LOCALE "locale [enUS]: " enUS
fi

# --- 4. mysql -------------------------------------------------------------
echo
echo "  4. The mysql client. Leave blank if 'mysql' and 'mysqldump' are on"
echo "     your PATH; otherwise the directory that holds them."
ask MYSQLDIR "path (optional): "

# --- 5. where the copies go -----------------------------------------------
echo
echo "  5. WHERE TO KEEP THE COPIES."
echo
echo "     [1] In a Backups/ folder inside this module, reproducing each file's"
echo "         own path underneath it."
echo "     [2] Beside each original, same name with a suffix."
echo
ask PICK "choice [1]: " 1
BACKUP=vault
if [ "$PICK" = "2" ]; then BACKUP=beside; fi

# --- 6. what to do --------------------------------------------------------
echo
echo "  6. WHAT TO DO NOW."
echo
echo "     [1] Look only. Reads the server and the client, writes nothing."
echo "     [2] Rehearse. Announces every step it would take, writes nothing."
echo "     [3] Install."
echo
ask MODE "choice [1]: " 1
FLAGS=""
case "$MODE" in
    1) FLAGS="--survey" ;;
    2) FLAGS="--dry-run" ;;
    3) ;;
    *) echo "  Unknown choice."; exit 1 ;;
esac

# --- 7. if an identifier is taken ----------------------------------------
echo
echo "  7. IF AN IDENTIFIER IS ALREADY TAKEN on this server or this client,"
echo "     the module can move its own out of the way -- every file of the"
echo "     module is rewritten to the new numbers, and you rebuild afterwards."
echo "     Say no to be told instead, and decide yourself."
ask SHIFT "move them if needed? [y/N]: " n
case "$SHIFT" in
    y|Y) FLAGS="$FLAGS --shift" ;;
esac

case "$MODE" in
    1|2) ;;
    3)
        echo
        echo "  About to write to:"
        echo "    $CORE/modules/mod-spheregrid"
        echo "    $SERVER/lua_scripts/SphereGrid"
        echo "    the module's configuration, beside the server's"
        echo "    the world and characters databases"
        if [ -n "$CLIENT" ]; then echo "    $CLIENT/patch-Z.MPQ"; fi
        echo
        ask GO "Type yes to go ahead: "
        if [ "$GO" != "yes" ]; then echo "  Nothing was done."; exit 0; fi
        ;;
    *) echo "  Unknown choice."; exit 1 ;;
esac

# --- run ------------------------------------------------------------------
echo
echo "  ------------------------------------------------------------------"
set -- --server "$SERVER" --core "$CORE" --backup "$BACKUP"
if [ -n "$CLIENT" ]; then set -- "$@" --client "$CLIENT" --locale "$LOCALE"; fi
if [ -n "$MYSQLDIR" ]; then set -- "$@" --mysql "$MYSQLDIR"; fi
if [ -n "$FLAGS" ]; then set -- "$@" $FLAGS; fi
"$PY" tools/install.py "$@"
RESULT=$?
echo "  ------------------------------------------------------------------"
echo
if [ "$RESULT" -ne 0 ]; then
    echo "  It stopped. Nothing beyond what is printed above was done."
    exit "$RESULT"
fi
if [ "$MODE" = "3" ]; then
    echo "  Done. Two things are left to you:"
    echo "    - rebuild the core, so the module is compiled in;"
    echo "    - AIO must be installed, server side and client side, or no window"
    echo "      ever opens. See the README."
fi
