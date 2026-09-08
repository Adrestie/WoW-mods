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

"""Reads the rows out of an INSERT statement.

Enough SQL to read what this module writes, and no more: a column list, then
tuples of numbers, quoted strings and NULL. It exists so that the authoring
tools can take the module's own SQL as their source rather than a running
database -- the SQL is what the module ships, and it is the same on any machine.
"""
import io
import re

INSERT = re.compile(r"INSERT\s+INTO\s+`(\w+)`\s*\(([^)]*)\)\s*VALUES", re.I)


def _values(text, start):
    """The tuples that follow a VALUES keyword, up to the statement's end."""
    rows, row, current, quoted, depth = [], [], [], False, 0
    i = start
    while i < len(text):
        c = text[i]
        if quoted:
            if c == "\\":                     # \' \\ \n ... one escaped char
                current.append(text[i:i + 2])
                i += 2
                continue
            if c == "'":
                if text[i:i + 2] == "''":     # the SQL way of writing a quote
                    current.append("''")
                    i += 2
                    continue
                quoted = False
            current.append(c)
        elif c == "'":
            quoted = True
            current.append(c)
        elif c == "(":
            depth += 1
            if depth == 1:
                row, current = [], []
            else:
                current.append(c)
        elif c == ")":
            depth -= 1
            if depth == 0:
                row.append("".join(current).strip())
                rows.append(row)
                current = []
            else:
                current.append(c)
        elif c == "," and depth == 1:
            row.append("".join(current).strip())
            current = []
        elif c == ";" and depth == 0:
            break
        else:
            current.append(c)
        i += 1
    return rows, i


def unquote(raw):
    """One SQL literal as a Python value: int, float, str or None."""
    if raw.upper() == "NULL":
        return None
    if raw.startswith("'"):
        body = raw[1:-1].replace("''", "'")
        for a, b in (("\\'", "'"), ('\\"', '"'), ("\\n", "\n"),
                     ("\\r", "\r"), ("\\t", "\t"), ("\\0", "\0"),
                     ("\\\\", "\\")):
            body = body.replace(a, b)
        return body
    try:
        return int(raw)
    except ValueError:
        return float(raw)


def insertions(path, table):
    """Every insertion into `table`, as (columns, rows of literals)."""
    text = io.open(path, encoding="utf-8", newline="").read()
    out = []
    for match in INSERT.finditer(text):
        if match.group(1) != table:
            continue
        columns = [c.strip().strip("`") for c in match.group(2).split(",")]
        rows, _ = _values(text, match.end())
        out.append((columns, [[unquote(v) for v in r] for r in rows]))
    return out
