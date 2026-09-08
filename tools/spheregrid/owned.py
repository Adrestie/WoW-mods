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

"""What the module owns, read from the module's own SQL.

Nothing else can say it. A range would be a guess -- the allocation has holes
where content was dropped, and neighbouring ranges belong to other modules. But
the SQL is the module declaring, statement by statement, which identifiers it
puts in the world; anything it never writes is not its business.

DELETE statements are skipped on purpose. The SQL removes what an earlier
version had allocated and abandoned; those identifiers appear there and nowhere
else, and shipping them would be shipping rows nothing references.
"""
import io
import os
import re

NUMBER = re.compile(r"\b(\d{4,9})\b")


def statements(path):
    """The SQL statements of a file, comments removed."""
    text = io.open(path, encoding="utf-8", newline="").read()
    text = re.sub(r"--[^\n]*", "", text)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    for piece in text.split(";"):
        piece = piece.strip()
        if piece:
            yield piece


def identifiers(sql_dir, low, high, tables=None):
    """Every identifier in [low, high] the SQL WRITES, sorted.

    `tables` narrows the reading to the statements that touch them. A spell
    identifier is unmistakable -- nothing else in this module is an eight digit
    number -- but a display identifier is six digits, and so are a price and a
    number of hit points. Where the range alone does not tell them apart, the
    table does.
    """
    out = set()
    for name in sorted(os.listdir(sql_dir)):
        if not name.endswith(".sql"):
            continue
        for piece in statements(os.path.join(sql_dir, name)):
            if piece.upper().startswith("DELETE"):
                continue
            if tables and not any(t in piece for t in tables):
                continue
            for found in NUMBER.findall(piece):
                value = int(found)
                if low <= value <= high:
                    out.add(value)
    return sorted(out)
