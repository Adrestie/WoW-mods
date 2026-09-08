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

"""Moves a whole family of the module's identifiers, everywhere at once.

    python tools/shift.py --family spells --by 100000 [--dry-run]
    python tools/shift.py --list

THE MODULE'S IDENTIFIERS ARE NOT SETTINGS. They are written in the DBC rows it
ships, in its SQL, in its C++ and in its Lua, and every one of those must say
the same number. So they are not moved one file at a time: a family -- the
spells, the items, the displays -- is moved as a block, by one offset, in every
file of the module, and the module is then what it was, one block over.

WHY A FAMILY CAN BE MOVED BY LOOKING AT NUMBERS ALONE. Each family owns a
range no other number in the module falls into: a seven-digit spell, a
six-digit item. A number in that range, wherever it stands, is one of ours. The
one family this is NOT true of is the visual kits (30000-30299), whose numbers
are the size of a duration in milliseconds: they are moved only where a kit is
known to be -- the DBC fields that hold one, and the C++ constants named for
one -- and never by sight.

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
from spheregrid import dbc  # noqa: E402

DBCS = os.path.join(MODULE, "data", "dbc")

# THE FAMILIES. `low`..`high` is the range a number must fall into to be one of
# ours; `size` is how far a shift must at least go so the whole block moves off
# itself. Every number of the module in that range moves -- in DBC fields, in
# SQL, in C++, in Lua -- except for the kits, moved by position only.
FAMILIES = {
    "spells": dict(low=8500000, high=8699999, size=200000,
                   tables=("Spell.dbc",),
                   sql_tables=("spell_dbc", "spell_ranks", "spell_script_names",
                               "spell_bonus_data", "spell_custom_attr")),
    "items": dict(low=803100, high=803699, size=600,
                  tables=("Item.dbc",), sql_tables=("item_template", "item_dbc")),
    "templates": dict(low=803800, high=803899, size=100,
                      tables=(), sql_tables=("creature_template",
                                             "gameobject_template")),
    "displays": dict(low=802001, high=802199, size=200,
                     tables=("CreatureDisplayInfo.dbc", "CreatureModelData.dbc",
                             "ItemDisplayInfo.dbc", "GameObjectDisplayInfo.dbc"),
                     sql_tables=("creaturedisplayinfo_dbc",
                                 "creaturemodeldata_dbc", "creature_model_info")),
    "effects": dict(low=8200206, high=8200399, size=200,
                    tables=("SpellVisualEffectName.dbc",), sql_tables=()),
    "sounds": dict(low=990001, high=990199, size=200,
                   tables=("SoundEntries.dbc", "Emotes.dbc"), sql_tables=()),
    "durations": dict(low=900019, high=900099, size=100,
                      tables=("SpellDuration.dbc",), sql_tables=()),
    "kits": dict(low=30000, high=30299, size=300,
                 tables=("SpellVisual.dbc", "SpellVisualKit.dbc"), sql_tables=(),
                 by_position=True),
}

# WHERE A KIT OR A VISUAL IS KNOWN TO BE, by position.
KIT_FIELDS = {
    "Spell.dbc": (131, 132),                          # SpellVisualID_1, _2
    "SpellVisual.dbc": (1, 2, 3, 4, 5, 6, 14, 15, 22, 23, 24, 25),
}
KIT_CONSTANT = re.compile(r"(constexpr\s+uint32\s+\w*(?:KIT|VISUAL)\w*\s*=\s*)(\d+)")
# The 05_spells.sql insert names 234 columns; two of them hold a visual.
KIT_SQL_COLUMNS = (131, 132)

TEXT = (".sql", ".cpp", ".h", ".lua", ".xml", ".json")


def in_family(family, value):
    return FAMILIES[family]["low"] <= value <= FAMILIES[family]["high"]


# ------------------------------------------------------------------ the DBCs

def shift_dbc(path, family, by, dry_run):
    """Every field holding one of the family's numbers moves, id included.

    A DBC field is thirty-two bits with no type written down. A float whose
    bits happen to spell one of our numbers would be a value in the region of
    1e-39: nothing in a DBC is that. So a field IN the range is an identifier.
    """
    table = dbc.read(path)
    strings = dbc.string_fields(table)
    name = os.path.basename(path).replace("spheregrid_", "")
    positions = KIT_FIELDS.get(name) if FAMILIES[family].get("by_position") else None
    records, moved = [], 0
    for record in table.records:
        record = bytearray(record)
        fields = positions if positions is not None else range(table.field_count)
        if positions is None or name in FAMILIES[family]["tables"]:
            for index in fields:
                if index in strings:
                    continue
                value = struct.unpack_from("<I", record, index * 4)[0]
                if in_family(family, value):
                    struct.pack_into("<I", record, index * 4, value + by)
                    moved += 1
        if positions is not None and name in FAMILIES[family]["tables"]:
            # the identifier itself, and the kit fields
            value = struct.unpack_from("<I", record, 0)[0]
            if in_family(family, value):
                struct.pack_into("<I", record, 0, value + by)
                moved += 1
        records.append(bytes(record))
    records.sort(key=lambda r: struct.unpack_from("<I", r, 0)[0])
    if moved and not dry_run:
        dbc.write(path, dbc.Dbc(table.field_count, table.record_size,
                                records, table.strings))
    return moved


# -------------------------------------------------------------- the text files

def shift_text(path, family, by, dry_run):
    """Every number of the family, wherever it stands in the file."""
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

    pattern = re.compile(r"(?<![\w.])\d{%d,%d}(?![\w.])" % (width, len(str(high))))
    out = pattern.sub(bump, text)
    if counter[0] and not dry_run:
        io.open(path, "w", encoding="utf-8", newline="").write(out)
    return counter[0]


def shift_kits_in_text(path, family, by, dry_run):
    """Kits are moved by position only: named constants, and the two SQL columns."""
    text = io.open(path, encoding="utf-8", newline="").read()
    counter = [0]

    def bump_constant(match):
        value = int(match.group(2))
        if in_family(family, value):
            counter[0] += 1
            return match.group(1) + str(value + by)
        return match.group(0)

    out = KIT_CONSTANT.sub(bump_constant, text)

    if path.endswith("05_spells.sql"):
        lines = out.split("\n")
        for i, line in enumerate(lines):
            if not re.match(r"^\(8[56]\d{5}, ", line):
                continue
            parts = split_values(line)
            if len(parts) != 234:
                continue
            changed = False
            for at in KIT_SQL_COLUMNS:
                value = int(parts[at])
                if in_family(family, value):
                    parts[at] = str(value + by)
                    counter[0] += 1
                    changed = True
            if changed:
                tail = line[len(line.rstrip(",;")):]
                lines[i] = "(" + ", ".join(parts) + ")" + tail
        out = "\n".join(lines)

    if counter[0] and not dry_run:
        io.open(path, "w", encoding="utf-8", newline="").write(out)
    return counter[0]


def split_values(line):
    """The values of one `(a, b, 'c', ...)` row, quotes respected."""
    parts, current, quoted, depth = [], "", False, 0
    for c in line[1:]:
        if quoted:
            current += c
            if c == "'":
                quoted = False
            continue
        if c == "'":
            quoted, current = True, current + c
        elif c == "," and depth == 0:
            parts.append(current.strip())
            current = ""
        elif c == "(":
            depth, current = depth + 1, current + c
        elif c == ")":
            if depth == 0:
                break
            depth, current = depth - 1, current + c
        else:
            current += c
    parts.append(current.strip())
    return parts


# ------------------------------------------------------------------ the module

def files():
    for folder in ("data", "src", "conf"):
        for base, _, names in os.walk(os.path.join(MODULE, folder)):
            for name in sorted(names):
                yield os.path.join(base, name)


def shift(family, by, dry_run):
    if family not in FAMILIES:
        raise SystemExit("no family called %r; try --list" % family)
    if by % FAMILIES[family]["size"]:
        raise SystemExit("%s moves by multiples of %d" % (family, FAMILIES[family]["size"]))
    positional = FAMILIES[family].get("by_position", False)
    print("shifting %s by %+d%s" % (family, by, " (dry run)" if dry_run else ""))
    total = 0
    for path in files():
        if path.endswith(".dbc"):
            moved = shift_dbc(path, family, by, dry_run)
        elif path.endswith(TEXT):
            moved = (shift_kits_in_text if positional else shift_text)(
                path, family, by, dry_run)
        else:
            continue
        if moved:
            print("  %-60s %5d" % (os.path.relpath(path, MODULE), moved))
            total += moved
    print("%d number(s) moved" % total)
    # The family's range moves with it: the next shift must know where it is.
    if not dry_run and total:
        record_shift(family, by)
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
    main()
