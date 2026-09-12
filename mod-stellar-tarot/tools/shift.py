# -*- coding: utf-8 -*-
# This file is part of mod-stellar-tarot.
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

"""Moves a whole family of the module's identifiers, everywhere at once.

    python tools/shift.py --family spells --by 100000 [--dry-run]
    python tools/shift.py --list

THE MODULE'S IDENTIFIERS ARE NOT SETTINGS. They are written in the DBC rows it
ships, in its SQL, in its C++ and in its Lua, and every one of those must say
the same number. So they are not moved one file at a time: a family -- the
spells, the items, the displays -- is moved as a block, by one offset, in every
file of the module, and the module is then what it was, one block over.

WHY A FAMILY CAN BE MOVED BY LOOKING AT NUMBERS ALONE. The items and the
spells each own a thousand no other number in the module falls into. A number
in that range, wherever it stands, is one of ours. Two families this is NOT
true of: the item displays and the spell icons, which wear the SAME numbers as
the items on purpose -- one number per card. Those are moved only where one is
known to be -- the DBC fields that hold one, the columns of an SQL row, the C++
constants named for one -- and never by sight.

The installer calls this when its survey finds an identifier taken and it was
told to shift (`--shift`). It can also be run by hand, before installing, on a
server whose ranges are known to be busy.
"""
import argparse
import io
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from stellartarot import dbc  # noqa: E402

DBCS = os.path.join(MODULE, "data", "dbc")


def use(root):
    """Point the tool at a COPY of the module rather than at this checkout.

    An installation must never rewrite the source it was launched from. The
    installer copies the module into the core's `modules/` folder first, and
    the shift applies there; what stays here keeps the numbers the module was
    written with. Called with no copy in sight, the tool works where it lives,
    which is what `--family ... --by ...` by hand is for.
    """
    global MODULE, DBCS, SHIFTS
    MODULE = os.path.abspath(root)
    DBCS = os.path.join(MODULE, "data", "dbc")
    SHIFTS = os.path.join(DBCS, "shifts.json")

# THE FAMILIES. `low`..`high` is the range a number must fall into to be one of
# ours; `size` is how far a shift must at least go so the whole block moves off
# itself. Every number of the module in that range moves -- in DBC fields, in
# SQL, in C++, in Lua -- except in a family moved `by_position`, which says
# WHERE one of its numbers is: the DBC fields that hold one (`fields`, by
# table -- the identifier itself, field 0, is implied in the family's own
# tables; `float_fields` for the few that hold one as a float), the columns
# of an SQL row that hold one (`sql_columns`, by name: whatever table and
# whatever column list the INSERT declares), and a word in the name of a C++
# constant (`constant`).
FAMILIES = {
    # ONE BLOCK, 902000..903999, and one number per asset: card N is item
    # 902000 + N and wears item display 902000 + N; board B is item 902500 + B.
    # The items and the displays therefore share their numbers, and only one
    # of the two can be moved by sight: the displays are moved by POSITION --
    # the field of Item.dbc and the columns of the SQL that hold one -- so
    # that moving them never touches an item's entry.
    "items": dict(low=902000, high=902999, size=1000,
                  tables=("Item.dbc",),
                  sql_tables=("item_template", "item_template_locale", "item_dbc")),
    "displays": dict(low=902000, high=902999, size=1000,
                     tables=("ItemDisplayInfo.dbc",), sql_tables=(),
                     by_position=dict(
                         fields={"Item.dbc": (5,)},          # DisplayInfoID
                         sql_columns=("displayid", "DisplayInfoID"),
                         constant="DISPLAY")),
    # The spells sit in the thousand above: 903000 studies a card, 903001 a
    # board, and the aura of card N at level L is 903000 + 4 x N + (L - 1).
    "spells": dict(low=903000, high=903999, size=1000,
                   tables=("Spell.dbc",),
                   sql_tables=("spell_dbc", "mod_stellar_tarot_card_effect")),
    "icons": dict(low=902000, high=902999, size=1000,
                  tables=("SpellIcon.dbc",), sql_tables=(),
                  by_position=dict(
                      fields={"Spell.dbc": (133, 134)},   # SpellIconID, ActiveIconID
                      sql_columns=("SpellIconID", "ActiveIconID"),
                      constant="ICON")),
}

TEXT = (".sql", ".cpp", ".h", ".lua", ".xml", ".json", ".md")
INSERT_HEADER = re.compile(r"INSERT INTO `\w+`\s*\(([^)]*)\)\s*VALUES")


def in_family(family, value):
    return FAMILIES[family]["low"] <= value <= FAMILIES[family]["high"]


# ------------------------------------------------------------------ the DBCs

def shift_dbc(path, family, by):
    """Every field holding one of the family's numbers moves, id included.

    Returns how many numbers moved and the file to write, or None when
    nothing moved. NOTHING IS WRITTEN HERE -- see `shift`.

    A DBC field is thirty-two bits with no type written down. A float whose
    bits happen to spell one of our numbers would be a value in the region of
    1e-39: nothing in a DBC is that. So a field IN the range is an identifier
    -- for a family moved by sight. For one moved by position, only the fields
    the family declares for this table are looked at, and the identifier
    itself in the family's own tables.
    """
    table = dbc.read(path)
    strings = dbc.string_fields(table)
    name = os.path.basename(path).replace("stellartarot_", "")
    spec = FAMILIES[family]
    positional = spec.get("by_position")
    floats = []
    if positional:
        fields = list(positional["fields"].get(name, ()))
        floats = list(positional.get("float_fields", {}).get(name, ()))
        if name in spec["tables"]:
            fields = [0] + fields
    else:
        # A FIELD MUST FIT INSIDE THE RECORD to be read as four bytes.
        # Nearly every table of 3.3.5a is field_count x 4 bytes and this
        # changes nothing; SpellChainEffects is 48 fields in 177 bytes --
        # five of them single bytes -- and its last fields do not begin on a
        # four byte boundary. Reading past the record is what a shift by
        # sight would otherwise do on every family that is not its own.
        usable = min(table.field_count, table.record_size // 4)
        fields = [i for i in range(usable) if i not in strings]
    if not fields and not floats:
        return 0, None
    records, moved = [], 0
    for record in table.records:
        record = bytearray(record)
        for index in fields:
            value = struct.unpack_from("<I", record, index * 4)[0]
            if in_family(family, value):
                struct.pack_into("<I", record, index * 4, value + by)
                moved += 1
        # A reference carried as a float: whole numbers only, read as such.
        for index in floats:
            value = struct.unpack_from("<f", record, index * 4)[0]
            if value == int(value) and in_family(family, int(value)):
                struct.pack_into("<f", record, index * 4, float(int(value) + by))
                moved += 1
        records.append(bytes(record))
    records.sort(key=lambda r: struct.unpack_from("<I", r, 0)[0])
    if not moved:
        return 0, None
    grown = dbc.Dbc(table.field_count, table.record_size, records, table.strings)
    return moved, dbc.to_bytes(grown)


# -------------------------------------------------------------- the text files

def shift_text(path, family, by):
    """Every number of the family, wherever it stands in the file.

    A NUMBER GLUED TO A LETTER IS NOT ONE OF OURS -- except after a `$`, which
    is how a spell's tooltip names ANOTHER spell: `$8600097s1` reads that
    spell's value, `$8600097d` its duration. Those move with the rest, or the
    text would point at a spell that no longer exists and the client would
    show whatever it could make of it.

    Returns how many moved and the text to write, or None when none did."""
    text = io.open(path, encoding="utf-8", newline="").read()
    low, high = FAMILIES[family]["low"], FAMILIES[family]["high"]
    width = len(str(low))
    counter = [0]

    def bump(match):
        value = int(match.group(0))
        if low <= value <= high:
            counter[0] += 1
            return str(value + by)
        return match.group(0)

    pattern = re.compile(r"(?<![\w.])\d{%d,%d}(?![\w.])"
                         r"|(?<=\$)\d{%d,%d}(?=[a-zA-Z])"
                         % (width, len(str(high)), width, len(str(high))))
    out = pattern.sub(bump, text)
    return (counter[0], out) if counter[0] else (0, None)


def shift_positional_text(path, family, by):
    """A family moved by position only: the C++ constants named for it, and
    its columns in every `spell_dbc` row of the SQL.

    Returns how many moved and the text to write, or None when none did."""
    text = io.open(path, encoding="utf-8", newline="").read()
    positional = FAMILIES[family]["by_position"]
    counter = [0]

    def bump_number(match):
        value = int(match.group(0))
        if in_family(family, value):
            counter[0] += 1
            return str(value + by)
        return match.group(0)

    # A CONSTANT IS KNOWN BY ITS NAME, and everything it is given is read --
    # `constexpr uint32 X_KIT = 30026;` as much as
    # `constexpr Dressing X_KITS[] = { { 30028, 30026, 30027 } };`. Reading
    # only the first form once left a table of kits behind while the data it
    # named moved: the numbers of a positional family carry no sign of their
    # own, and the name of what holds them is the only thing that says so.
    declaration = re.compile(r"constexpr\s+\w+\s+\w*(?:%s)\w*\s*"
                             r"(?:\[[^\]]*\])?\s*=\s*" % positional["constant"])
    edits = []
    for match in declaration.finditer(text):
        start = match.end()
        if start < len(text) and text[start] == "{":
            depth, at = 0, start
            while at < len(text):
                if text[at] == "{":
                    depth += 1
                elif text[at] == "}":
                    depth -= 1
                    if not depth:
                        at += 1
                        break
                at += 1
            end = at
        else:
            end = start
            while end < len(text) and text[end].isdigit():
                end += 1
        if end > start:
            edits.append((start, end))
    out = text
    for start, end in reversed(edits):
        piece = re.sub(r"(?<![\w.])\d+(?![\w.])", bump_number, out[start:end])
        out = out[:start] + piece + out[end:]

    if path.endswith(".sql") and positional["sql_columns"]:
        # An INSERT declares its columns; the tuples that follow, up to the
        # statement's end, are read against that list -- a tuple may run
        # over several lines when a string in it does. A row is known by
        # the statement it belongs to, never by its number: the number is
        # what a shift changes, and not every INSERT of the same table lists
        # the same columns.
        wanted = set(positional["sql_columns"])
        edits = []
        for header in INSERT_HEADER.finditer(out):
            columns = [c.strip("` \r\n") for c in header.group(1).split(",")]
            at = [columns.index(c) for c in columns if c in wanted]
            if not at:
                continue
            for spans in value_spans(out, header.end(), until_statement_end=True):
                for index in at:
                    if index >= len(spans):
                        continue
                    start, end = spans[index]
                    text = out[start:end]
                    try:
                        value = int(text.strip())
                    except ValueError:
                        continue
                    if in_family(family, value):
                        edits.append((start, end,
                                      text.replace(str(value), str(value + by))))
        # From the last edit to the first, so that the offsets of the edits
        # still to do are not moved by the ones already done.
        for start, end, text in sorted(edits, reverse=True):
            out = out[:start] + text + out[end:]
            counter[0] += 1

    return (counter[0], out) if counter[0] else (0, None)


def value_spans(text, start=0, until_statement_end=False):
    """Where each value of each `(a, b, 'c', ...)` tuple of a text stands:
    a list of tuples, each a list of (start, end) offsets into the text.

    Quotes are respected -- inside a string a backslash escapes the next
    character, two quotes stand for one, and a newline is a character like
    any other -- and so are parentheses inside a value. Nothing is rebuilt
    from this: a caller replaces the spans it means to change, from the last
    to the first, and the rest of the text is the text. With
    `until_statement_end` the scan stops at the first `;` outside a string
    and outside a tuple: the end of one INSERT.
    """
    tuples, spans, first = [], None, None
    quoted, escaped, depth = False, False, 0
    i = start
    while i < len(text):
        c = text[i]
        i += 1
        if quoted:
            if escaped:
                escaped = False
            elif c == "\\":
                escaped = True
            elif c == "'":
                quoted = False
            continue
        if c == "'":
            quoted = True
        elif c == "(":
            depth += 1
            if depth == 1:
                spans, first = [], i
        elif c == ")":
            depth -= 1
            if depth == 0 and spans is not None:
                spans.append((first, i - 1))
                tuples.append(spans)
                spans = None
        elif c == "," and depth == 1:
            spans.append((first, i - 1))
            first = i
        elif c == ";" and depth == 0 and until_statement_end:
            break
    return tuples


def split_values(line):
    """The values of the first tuple of a line, stripped."""
    tuples = value_spans(line)
    return [line[a:b].strip() for a, b in tuples[0]] if tuples else []


# ------------------------------------------------------------------ the module

def files():
    for folder in ("data", "src", "conf"):
        for base, _, names in os.walk(os.path.join(MODULE, folder)):
            for name in sorted(names):
                yield os.path.join(base, name)
    # THE README NAMES SOME OF THEM, in its table of identifiers. The
    # changelog stays out of this: it says what happened, at the numbers it
    # happened at.
    readme = os.path.join(MODULE, "README.md")
    if os.path.isfile(readme):
        yield readme


def leftovers(family):
    """What still names a number of the family's range, once it has moved.

    A POSITIONAL FAMILY CANNOT BE MOVED BY SIGHT: a visual kit's number is an
    integer like any other -- a duration in milliseconds looks exactly the same
    -- so the shift moves only the places it is TOLD hold one. Where it was
    never told, it leaves the old number where it stands and says nothing. That
    is how the heroic leap lost its dressing: its kits sat in a braced table
    and the rule read single values only.

    So once the move is done, every TEXT file of the module is read again and
    every line still falling in the old range is listed. Most of what comes
    back is innocent -- this check can tell a kit from a duration no better
    than the shift could -- but a human reads ten lines in ten seconds, and the
    tool no longer keeps that doubt to itself. The DBC files are out of reach
    here: a record is numbers all the way down, and every one of them would
    answer.
    """
    low, high = FAMILIES[family]["low"], FAMILIES[family]["high"]
    pattern = re.compile(r"(?<![\w.])\d{%d,%d}(?![\w.])"
                         % (len(str(low)), len(str(high))))
    out = []
    for path in files():
        if not path.endswith(TEXT):
            continue
        for number, line in enumerate(
                io.open(path, encoding="utf-8", newline="").read().splitlines(), 1):
            if any(low <= int(m.group(0)) <= high for m in pattern.finditer(line)):
                out.append((path, number, line.strip()))
    return out


def shift(family, by, dry_run):
    if family not in FAMILIES:
        raise SystemExit("no family called %r; try --list" % family)
    if by % FAMILIES[family]["size"]:
        raise SystemExit("%s moves by multiples of %d" % (family, FAMILIES[family]["size"]))
    positional = FAMILIES[family].get("by_position", False)
    print("shifting %s by %+d%s" % (family, by, " (dry run)" if dry_run else ""))

    # EVERYTHING IS COMPUTED BEFORE ANYTHING IS WRITTEN. A shift touches the
    # DBC rows, the SQL, the C++ and the Lua; stopping half way would leave
    # the module saying two different numbers for the same thing, and the
    # record of what moved -- written last -- would not even know. So a file
    # that cannot be read or understood aborts the whole shift, and the
    # module is exactly as it was.
    total, pending = 0, []
    for path in files():
        if path.endswith(".dbc"):
            moved, payload = shift_dbc(path, family, by)
        elif path.endswith(TEXT):
            moved, payload = (shift_positional_text if positional else shift_text)(
                path, family, by)
        else:
            continue
        if moved:
            print("  %-60s %5d" % (os.path.relpath(path, MODULE), moved))
            total += moved
            pending.append((path, payload))

    if not dry_run:
        for path, payload in pending:
            if isinstance(payload, bytes):
                with open(path, "wb") as out:
                    out.write(payload)
            else:
                io.open(path, "w", encoding="utf-8", newline="").write(payload)
    print("%d number(s) moved%s" % (total, " (dry run: nothing written)" if dry_run else ""))
    # The family's range moves with it: the next shift must know where it is.
    if not dry_run and total:
        record_shift(family, by)
        rest = leftovers(family)
        if rest:
            # BY FILE, not line by line. The first run of this check printed six
            # hundred lines an operator would never read: the layout's cells are
            # numbered like chains, a game spell can wear an icon's number. What
            # is worth knowing is WHERE to look.
            per_file = {}
            for path, number, _ in rest:
                seen = per_file.setdefault(os.path.relpath(path, MODULE), [0, number])
                seen[0] += 1
            print("  numbers still between %d and %d. What the shift knows to hold "
                  "one has moved; check that none of these is ours:"
                  % (FAMILIES[family]["low"], FAMILIES[family]["high"]))
            for name, (count, first) in sorted(per_file.items(),
                                               key=lambda kv: -kv[1][0]):
                print("    %-58s %4d line(s), first at %d" % (name, count, first))
    return total


SHIFTS = os.path.join(DBCS, "shifts.json")


def record_shift(family, by):
    """Shifts add up, and the survey must know the module's CURRENT ranges."""
    import json
    done = {}
    if os.path.isfile(SHIFTS):
        done = json.load(io.open(SHIFTS, encoding="utf-8"))
    done[family] = done.get(family, 0) + by
    with io.open(SHIFTS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(done, f, indent=2, sort_keys=True)
        f.write("\n")


def current_ranges():
    """Each family's range as it stands, previous shifts included."""
    import json
    done = {}
    if os.path.isfile(SHIFTS):
        done = json.load(io.open(SHIFTS, encoding="utf-8"))
    out = {}
    for name, spec in FAMILIES.items():
        by = done.get(name, 0)
        out[name] = (spec["low"] + by, spec["high"] + by)
    return out


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--family")
    parser.add_argument("--by", type=int)
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.list:
        for name, (low, high) in sorted(current_ranges().items()):
            print("  %-10s %9d .. %-9d  moves by multiples of %d"
                  % (name, low, high, FAMILIES[name]["size"]))
        return
    if not args.family or args.by is None:
        parser.error("--family and --by, or --list")
    # A family that was already shifted is looked for where it now stands.
    low, high = current_ranges()[args.family]
    FAMILIES[args.family]["low"], FAMILIES[args.family]["high"] = low, high
    shift(args.family, args.by, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
