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

"""Login screen sceneries with the character brought back to its size.

The client limits the create/select scene to 16:9 and our glue screens widen it to 2:1.
The scenery camera has a diagonal field of view (height = fov / sqrt(1 + ratio^2), Wow.exe
0x6BFE00), so the wider scene enlarges everything by 1.096. No Lua sets that camera: instead
the scale of the bone holding attachment 0 (where the character stands) is multiplied by
1 / 1.096, and the models are written to data/art/Interface/Glues/Models/ for patch-Z.
When that bone also carries scenery vertices (bone lookup), attachment 0 moves to an extra
copy of the bone with its own track tables: the client converts table offsets in place on
load, so a table shared by two bones breaks the model. The client .skin files are unchanged.
Only screens of 2:1 or wider get the right size; narrower ones show smaller characters.
"""
import argparse
import io
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import mpq  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CLIENT = r"E:\world of warcraft 3.3.5a hd"
OUTPUT = os.path.join(ROOT, "data", "art")
BS = chr(92)
# names returned by GetCreateBackgroundModel and GetSelectBackgroundModel
# (gnomes use the dwarf scenery, trolls the orc one)
SCENERIES = ("Human", "Orc", "Dwarf", "NightElf", "Scourge", "Tauren", "BloodElf", "Draenei", "DeathKnight")
# our 2:1 glue screens brought back to the client's 16:9
SCALE = math.sqrt(1 + (16 / 9.0) ** 2) / math.sqrt(1 + 2.0 ** 2)
# M2 version 264: header offsets of bones (M2CompBone, 88 bytes) and attachments (40 bytes)
M2_BONES, M2_ATTACHMENTS = 0x2C, 0xF0
M2_BONE_LOOKUP = 0x78    # bone lookup: the bones that vertices refer to
BONE_SIZE, ATTACHMENT_SIZE = 88, 40
BONE_SCALE = 56             # M2Track<C3Vector> scale in M2CompBone
# bone tracks: offset in M2CompBone, key size
TRACKS = ((16, 12), (36, 8), (BONE_SCALE, 12))   # C3Vector, M2CompQuat, C3Vector


# pads the buffer to a 16-byte boundary
def align(d):
    d.extend(bytes(-len(d) % 16))


def copy_track(d, track, size, factor=None):
    """Copies a track's tables and keys (M2Track: interpolation, global sequence, timestamps,
    values) to the end of the file, values multiplied by factor if given. Returns the first
    value.
    """
    if struct.unpack_from("<h", d, track)[0] in (2, 3):
        size *= 3                 # hermite, bezier: value and two tangents
    initial = None
    for field, t in ((4, 4), (12, size)):
        n, o = struct.unpack_from("<II", d, track + field)
        align(d)
        table = len(d)
        d.extend(bytes(8 * n))
        for k in range(n):
            m, q = struct.unpack_from("<II", d, o + 8 * k)
            block = bytes(d[q:q + m * t])
            if field == 12 and factor is not None and m:
                values = struct.unpack("<%df" % (len(block) // 4), block)
                initial = initial or values[0]
                block = struct.pack("<%df" % len(values), *(x * factor for x in values))
            align(d)
            data = len(d) if m else 0
            d.extend(block)
            struct.pack_into("<II", d, table + 8 * k, m, data)
        struct.pack_into("<I", d, track + field + 4, table if n else 0)
    return initial


def shrink(d):
    """Shrinks a scenery's character; returns (bone, in place?, previous scale)."""
    bone_count, bones = struct.unpack_from("<II", d, M2_BONES)
    att_count, att = struct.unpack_from("<II", d, M2_ATTACHMENTS)
    rank = number = None
    for i in range(att_count):
        ident, n = struct.unpack_from("<IH", d, att + ATTACHMENT_SIZE * i)
        if ident == 0:
            rank, number = i, n
            break
    if rank is None or number >= bone_count:
        raise ValueError("pas d'attache 0")
    track = bones + BONE_SIZE * number + BONE_SCALE
    if not struct.unpack_from("<I", d, track + 12)[0]:
        raise ValueError("l'os %d n'a pas d'echelle a reduire" % number)
    lookup_count, lookup = struct.unpack_from("<II", d, M2_BONE_LOOKUP)
    carries_scenery = number in struct.unpack_from("<%dH" % lookup_count, d, lookup)

    if not carries_scenery:
        size = 36 if struct.unpack_from("<h", d, track)[0] in (2, 3) else 12
        n_seq, tables = struct.unpack_from("<II", d, track + 12)
        before = None
        for k in range(n_seq):
            m, q = struct.unpack_from("<II", d, tables + 8 * k)
            values = struct.unpack_from("<%df" % (m * size // 4), d, q)
            before = before or (values[0] if values else None)
            struct.pack_into("<%df" % len(values), d, q, *(x * SCALE for x in values))
        return number, True, before

    new_bone = bytearray(d[bones + BONE_SIZE * number:bones + BONE_SIZE * (number + 1)])
    struct.pack_into("<i", new_bone, 0, -1)        # no key bone
    align(d)
    new_bones = len(d)
    d.extend(d[bones:bones + BONE_SIZE * bone_count])
    d.extend(new_bone)
    write_pos = new_bones + BONE_SIZE * bone_count
    before = None
    for offset, size in TRACKS:
        v = copy_track(d, write_pos + offset, size, SCALE if offset == BONE_SCALE else None)
        before = before or v
    struct.pack_into("<II", d, M2_BONES, bone_count + 1, new_bones)
    struct.pack_into("<H", d, att + ATTACHMENT_SIZE * rank + 4, bone_count)
    return bone_count, False, before


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--client", default=DEFAULT_CLIENT, help="dossier du client 3.3.5")
    options = parser.parse_args()
    # the client as shipped, without our archive: start from the original sceneries
    client = mpq.open_client(os.path.join(options.client, "Data"), "enUS", ignore=("patch-Z.MPQ",))

    for scenery in SCENERIES:
        internalPath = BS.join(["Interface", "Glues", "Models", "UI_" + scenery, "UI_" + scenery + ".m2"])
        d = bytearray(client.read(internalPath))
        if d[:4] != b"MD20" or struct.unpack_from("<I", d, 4)[0] != 264:
            raise SystemExit("%s : pas un M2 de version 264" % internalPath)
        try:
            character_bone, in_place, before = shrink(d)
        except ValueError as e:
            raise SystemExit("%s : %s" % (internalPath, e))
        target = os.path.join(OUTPUT, *internalPath.split(BS))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        io.open(target, "wb").write(bytes(d))
        print("   %-12s os %d%s : echelle %.3f -> %.3f" % (
            scenery, character_bone, " (sur place)" if in_place else " (os de plus)", before, before * SCALE))
    print("echelle %.4f -> %s" % (SCALE, os.path.relpath(os.path.join(OUTPUT, "Interface", "Glues", "Models"), ROOT)))


if __name__ == "__main__":
    main()
