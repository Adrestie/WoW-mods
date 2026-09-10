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

"""Reading MPQ archives, the format the 3.3.5 client keeps its data in.

WHY THIS EXISTS. The installer cannot decide anything about a client without
looking inside it: which identifiers are already taken, whether a texture is
there, whether an interface file has been modified. StormLib does that, but it
is a 32 bit library and nothing guarantees a matching interpreter on the
machine of whoever installs the module. So the reading is done here, in the
language the rest of the installer is written in, and it depends on nothing.

WHAT AN ARCHIVE IS. A header, a hash table and a block table, then the files.
The two tables are encrypted with a key derived from their own name, using a
table of numbers the format generates from a single seed. A file is found by
hashing its path three times: once to pick a slot, twice more to confirm the
name, because the archive does not store names at all.

This module reads, writes a new archive, and writes INTO an existing one -- the
last for a client that already carries a patch of its own in the top slot.
"""
import os
import struct
import zlib

MAGIC = b"MPQ\x1a"
HEADER = struct.Struct("<4sIIHHIIII")

HASH_TABLE_KEY = "(hash table)"
BLOCK_TABLE_KEY = "(block table)"

# What a block entry says about its file.
FILE_IMPLODE = 0x00000100      # compressed the old way, PKWARE
FILE_COMPRESS = 0x00000200     # compressed, the method written in each sector
FILE_ENCRYPTED = 0x00010000
FILE_FIX_KEY = 0x00020000      # the key depends on where the file sits
FILE_SINGLE_UNIT = 0x01000000  # one piece, no sector table
FILE_EXISTS = 0x80000000

EMPTY_NEVER_USED = 0xFFFFFFFF
EMPTY_DELETED = 0xFFFFFFFE


def _crypt_table():
    """The table of numbers every hash and every key is drawn from."""
    table = [0] * 0x500
    seed = 0x00100001
    for index in range(0x100):
        position = index
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            first = (seed & 0xFFFF) << 16
            seed = (seed * 125 + 3) % 0x2AAAAB
            second = seed & 0xFFFF
            table[position] = first | second
            position += 0x100
    return table


CRYPT = _crypt_table()


def hash_string(text, kind):
    """The archive's hash of a path. `kind` picks which of the three it is."""
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for character in text.upper().replace("/", "\\"):
        value = ord(character)
        seed1 = CRYPT[(kind << 8) + value] ^ ((seed1 + seed2) & 0xFFFFFFFF)
        seed2 = (value + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1


def decrypt(data, key):
    """Undoes the archive's encryption over a whole number of words."""
    out = bytearray(len(data))
    seed = 0xEEEEEEEE
    for offset in range(0, len(data) - 3, 4):
        seed = (seed + CRYPT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        value = struct.unpack_from("<I", data, offset)[0]
        value = value ^ ((key + seed) & 0xFFFFFFFF)
        struct.pack_into("<I", out, offset, value)
        key = (((~key << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        seed = (value + seed + (seed << 5) + 3) & 0xFFFFFFFF
    out[len(data) - len(data) % 4:] = data[len(data) - len(data) % 4:]
    return bytes(out)


def encrypt(data, key):
    """The mirror of `decrypt`.

    The two differ in one place: the running seed is fed the PLAIN value in
    both directions -- which decryption reads after unmasking and encryption
    reads before masking. Get that backwards and the first word still comes out
    right, which is what makes the mistake worth naming here.
    """
    out = bytearray(len(data))
    seed = 0xEEEEEEEE
    for offset in range(0, len(data) - 3, 4):
        seed = (seed + CRYPT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        value = struct.unpack_from("<I", data, offset)[0]
        struct.pack_into("<I", out, offset, value ^ ((key + seed) & 0xFFFFFFFF))
        key = (((~key << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        seed = (value + seed + (seed << 5) + 3) & 0xFFFFFFFF
    out[len(data) - len(data) % 4:] = data[len(data) - len(data) % 4:]
    return bytes(out)


def _explode(data, expected):
    """PKWARE implode, the compression Blizzard used before zlib.

    Not implemented. A file compressed this way is reported as unreadable
    rather than silently returned wrong -- an installer that mistakes garbage
    for a DBC would write nonsense into a client.
    """
    raise NotImplementedError("PKWARE implode is not supported")


DECOMPRESS = {
    0x02: lambda data, expected: zlib.decompress(data),
    0x08: _explode,
}


class Archive(object):
    """One MPQ, open for reading."""

    def __init__(self, path):
        self.path = path
        self._file = open(path, "rb")
        self._read_header()
        self._read_tables()

    def close(self):
        self._file.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    def _read_header(self):
        # An archive does not have to start at offset zero: an executable may
        # sit in front of it. The header is looked for on 512 byte boundaries,
        # which is where the format says it can be.
        self._file.seek(0, 2)
        size = self._file.tell()
        offset = 0
        while offset < size:
            self._file.seek(offset)
            head = self._file.read(HEADER.size)
            if head[:4] == MAGIC:
                break
            offset += 512
        else:
            raise ValueError("%s: no MPQ header" % self.path)

        (_, header_size, _, self.version, self.sector_shift,
         hash_position, block_position,
         self.hash_count, self.block_count) = HEADER.unpack(head)
        self.base = offset
        self.hash_position = offset + hash_position
        self.block_position = offset + block_position
        if self.version >= 1:
            self._file.seek(offset + 32)
            extra = self._file.read(12)
            high_block, hash_high, block_high = struct.unpack("<QHH", extra)
            self.hash_position += hash_high << 32
            self.block_position += block_high << 32

    def _read_tables(self):
        self._file.seek(self.hash_position)
        raw = decrypt(self._file.read(self.hash_count * 16),
                      hash_string(HASH_TABLE_KEY, 3))
        self.hash_table = [struct.unpack_from("<IIHHI", raw, i * 16)
                           for i in range(self.hash_count)]

        self._file.seek(self.block_position)
        raw = decrypt(self._file.read(self.block_count * 16),
                      hash_string(BLOCK_TABLE_KEY, 3))
        self.block_table = [struct.unpack_from("<IIII", raw, i * 16)
                            for i in range(self.block_count)]

    def _slot(self, name):
        """The hash entry for a path, or None."""
        start = hash_string(name, 0) & (self.hash_count - 1)
        name_a, name_b = hash_string(name, 1), hash_string(name, 2)
        for step in range(self.hash_count):
            entry = self.hash_table[(start + step) % self.hash_count]
            if entry[4] == EMPTY_NEVER_USED:
                return None
            if entry[0] == name_a and entry[1] == name_b and entry[4] != EMPTY_DELETED:
                return entry
        return None

    def has(self, name):
        return self._slot(name) is not None

    def read(self, name):
        """The bytes of one file. Raises if it is not there, or unreadable."""
        entry = self._slot(name)
        if entry is None:
            raise KeyError("%s is not in %s" % (name, self.path))
        position, packed, unpacked, flags = self.block_table[entry[4]]
        position += self.base
        if not flags & FILE_EXISTS:
            raise KeyError("%s is marked as gone in %s" % (name, self.path))

        key = None
        if flags & FILE_ENCRYPTED:
            short = name.replace("/", "\\").rsplit("\\", 1)[-1]
            key = hash_string(short, 3)
            if flags & FILE_FIX_KEY:
                key = ((key + (position - self.base)) ^ unpacked) & 0xFFFFFFFF

        if flags & FILE_SINGLE_UNIT:
            self._file.seek(position)
            piece = self._file.read(packed)
            if key is not None:
                piece = decrypt(piece, key)
            return self._expand(piece, unpacked, flags)

        sector = 512 << self.sector_shift
        count = (unpacked + sector - 1) // sector
        self._file.seek(position)
        raw = self._file.read((count + 1) * 4)
        if key is not None:
            raw = decrypt(raw, (key - 1) & 0xFFFFFFFF)
        offsets = struct.unpack("<%dI" % (count + 1), raw)

        out = bytearray()
        for index in range(count):
            self._file.seek(position + offsets[index])
            piece = self._file.read(offsets[index + 1] - offsets[index])
            if key is not None:
                piece = decrypt(piece, (key + index) & 0xFFFFFFFF)
            wanted = min(sector, unpacked - len(out))
            out += self._expand(piece, wanted, flags)
        return bytes(out)

    @staticmethod
    def _expand(piece, wanted, flags):
        if len(piece) >= wanted:
            return piece[:wanted]          # stored as it is
        if flags & FILE_COMPRESS:
            method, body = piece[0], piece[1:]
            if method not in DECOMPRESS:
                raise NotImplementedError("compression 0x%02x" % method)
            return DECOMPRESS[method](body, wanted)
        if flags & FILE_IMPLODE:
            return _explode(piece, wanted)
        return piece


class Chain(object):
    """The archives of a client, in the order the game reads them.

    The game does not merge archives: it asks each in turn and keeps the first
    answer, with the later patches winning over the base files. So does this --
    which is the only way to know what a player actually sees.
    """

    def __init__(self, archives):
        self.archives = list(archives)     # lowest priority first

    def has(self, name):
        return any(a.has(name) for a in self.archives)

    def where(self, name):
        """Which archive answers for a path -- the last one that has it."""
        for archive in reversed(self.archives):
            if archive.has(name):
                return archive
        return None

    def read(self, name):
        archive = self.where(name)
        if archive is None:
            raise KeyError(name)
        return archive.read(name)

    def names(self):
        """Every path the archives declare, as far as they declare any.

        An archive does not have to carry a `(listfile)`, and one that does not
        can still be read -- a path can always be asked for by name. So this
        answers what CAN be enumerated, never what exists.
        """
        out = set()
        for archive in self.archives:
            if not archive.has("(listfile)"):
                continue
            text = archive.read("(listfile)").decode("utf-8", "replace")
            out.update(name.strip() for name in text.splitlines()
                       if name.strip())
        return out

    def close(self):
        for archive in self.archives:
            archive.close()


def priority(name):
    """Where an archive sits in the reading order, from its file name.

    The client asks the archives in turn and keeps the FIRST answer, so the
    order decides what a player sees. Three groups, lowest first:

      0  the base data -- common, expansion, lichking, and their locale halves
      1  the locale patches -- patch-enUS, patch-enUS-2 ... patch-enUS-Z
      2  the plain patches -- patch, patch-2 ... patch-Z

    A plain patch therefore beats the locale patch of the same rank, which is
    why a server's own archive is called `patch-Z`: nothing sits above it.

    Within a group: the unsuffixed archive first, then the digits, then the
    letters. `patch-2` before `patch-9`, and both before `patch-A`.
    """
    stem = name.lower().rsplit(".", 1)[0]
    if not stem.startswith("patch"):
        return (0, 0, stem)

    parts = [p for p in stem[5:].split("-") if p]
    # A single part that is neither a digit nor one letter is a locale:
    # `patch-enus` is the locale's own base patch.
    locale = bool(parts) and (len(parts[0]) > 1 and not parts[0].isdigit())
    tag = parts[-1] if parts and not (locale and len(parts) == 1) else ""

    group = 1 if locale else 2
    rank = 0 if not tag else (1 if tag.isdigit() else 2)
    return (group, rank, tag)


def open_client(data_dir, locale=None, ignore=()):
    """Every archive of a client, ordered, ready to be asked.

    `ignore` names archives to leave out, by file name. THE MODULE'S OWN
    ARCHIVE BELONGS THERE whenever a tool is asking what the CLIENT holds: a
    collector comparing against a stock client would find nothing left to add,
    and an installer would read every identifier as taken -- by itself.
    """
    skip = {n.lower() for n in ignore}

    def keep(name):
        return name.lower().endswith(".mpq") and name.lower() not in skip

    names = [n for n in os.listdir(data_dir) if keep(n)]
    found = [(priority(n), os.path.join(data_dir, n)) for n in names]
    if locale:
        folder = os.path.join(data_dir, locale)
        if os.path.isdir(folder):
            found += [(priority(n), os.path.join(folder, n))
                      for n in os.listdir(folder) if keep(n)]
    found.sort(key=lambda pair: pair[0])
    return Chain(Archive(path) for _, path in found)


# --------------------------------------------------------------- writing one

def write_archive(path, files, compress=True):
    """Writes a NEW archive holding the given files.

    `files` maps a path inside the archive to its bytes. Everything is stored
    as a single unit -- no sector table, no encryption -- which is all a patch
    archive needs and is what makes the result easy to read back and to check.

    Modifying an EXISTING archive is deliberately not offered. A module has no
    business rewriting a client's own files: what it adds goes into an archive
    of its own, read before them.
    """
    entries = list(files.items())
    entries.append(("(listfile)",
                    "\r\n".join(name for name, _ in entries).encode("utf-8")))

    # The hash table is a power of two and never full: a table with no free
    # slot cannot say "not here", and lookup would walk it forever.
    slots = 4
    while slots < len(entries) * 2:
        slots *= 2

    header_size = 32
    blocks, blob = [], bytearray()
    for name, raw in entries:
        stored, flags = raw, FILE_EXISTS | FILE_SINGLE_UNIT
        if compress:
            packed = b"\x02" + zlib.compress(raw, 9)
            if len(packed) < len(raw):
                stored, flags = packed, flags | FILE_COMPRESS
        blocks.append((header_size + len(blob), len(stored), len(raw), flags))
        blob += stored

    hash_table = [[EMPTY_NEVER_USED, EMPTY_NEVER_USED, 0xFFFF, 0xFFFF,
                   EMPTY_NEVER_USED] for _ in range(slots)]
    for index, (name, _) in enumerate(entries):
        start = hash_string(name, 0) & (slots - 1)
        for step in range(slots):
            slot = (start + step) % slots
            if hash_table[slot][4] == EMPTY_NEVER_USED:
                hash_table[slot] = [hash_string(name, 1), hash_string(name, 2),
                                    0, 0, index]
                break
        else:
            raise ValueError("the hash table filled up")

    raw_hash = b"".join(struct.pack("<IIHHI", *row) for row in hash_table)
    raw_block = b"".join(struct.pack("<IIII", *row) for row in blocks)
    hash_at = header_size + len(blob)
    block_at = hash_at + len(raw_hash)

    with open(path, "wb") as out:
        out.write(HEADER.pack(MAGIC, header_size,
                              block_at + len(raw_block), 0, 3,
                              hash_at, block_at, slots, len(blocks)))
        out.write(blob)
        out.write(encrypt(raw_hash, hash_string(HASH_TABLE_KEY, 3)))
        out.write(encrypt(raw_block, hash_string(BLOCK_TABLE_KEY, 3)))
    return path


# ------------------------------------------------------ writing into one

def patch_archive(path, files, remove=(), compress=True, keep_free=8):
    """Adds, replaces or removes files IN an existing archive, in place.

    `files` maps a path inside the archive to its bytes: a path already there
    is replaced, a new one added. `remove` names paths to take out. The
    listfile is kept in step, so the archive can still be enumerated.

    HOW. New data is appended after everything the archive holds, the block
    of a replaced file is pointed at the new data, a new file takes a free
    hash slot and a new block, and the two tables are written again after the
    data. Nothing existing moves, so the archive is never in a half-written
    state for longer than the tables take to write -- and it is the caller's
    job to have kept a copy of what it replaces.

    A HASH TABLE TOO SMALL FOR WHAT IS BEING ADDED IS REBUILT BIGGER. That
    needs the name of every file already there -- a slot keeps a name's
    fingerprints, never the name, and where a name belongs depends on the
    table's size -- so the names are read from the `(listfile)`. An archive
    whose listfile does not account for every occupied slot cannot be grown,
    and is left alone.

    WHAT IT WILL NOT DO. Cross the 4 GB line: positions are thirty-two bits,
    and the high-word table of larger archives is not handled here. Fill the
    hash table: a table with no free slot cannot say "not here", so at least
    one slot in `keep_free` is left empty. Either refusal is a ValueError,
    raised before a byte is written.
    """
    archive = Archive(path)
    try:
        base = archive.base
        version = archive.version
        hash_table = [list(row) for row in archive.hash_table]
        block_table = [list(row) for row in archive.block_table]
        listed = set()
        if archive.has("(listfile)"):
            text = archive.read("(listfile)").decode("utf-8", "replace")
            listed = {n.strip() for n in text.splitlines() if n.strip()}
    finally:
        archive.close()

    # --- room in the hash table, grown if need be ---------------------------
    def occupied(table):
        return [row for row in table
                if row[4] not in (EMPTY_NEVER_USED, EMPTY_DELETED)]

    def grown(table, wanted):
        """The same entries in a bigger table, placed from their names."""
        # The files an archive keeps for itself are never in its own
        # listfile, and their names are known: they are named here so that a
        # rebuild does not lose them.
        known = set(listed) | {"(listfile)", "(attributes)", "(signature)"}
        by_pair = {(hash_string(n, 1), hash_string(n, 2)): n for n in known}
        staying = occupied(table)
        unknown = [row for row in staying if (row[0], row[1]) not in by_pair]
        if unknown:
            raise ValueError(
                "%s: the hash table has no room for %d more file(s), and it "
                "cannot be rebuilt bigger: %d of the %d file(s) it holds are "
                "not named by its (listfile)"
                % (path, wanted, len(unknown), len(staying)))
        size = len(table)
        while size < (len(staying) + wanted) * 2:
            size *= 2
        out = [[EMPTY_NEVER_USED, EMPTY_NEVER_USED, 0xFFFF, 0xFFFF,
                EMPTY_NEVER_USED] for _ in range(size)]
        for row in staying:
            name = by_pair[(row[0], row[1])]
            start = hash_string(name, 0) & (size - 1)
            for step in range(size):
                at = (start + step) % size
                if out[at][4] == EMPTY_NEVER_USED:
                    out[at] = list(row)
                    break
            else:
                raise ValueError("%s: the rebuilt hash table filled up" % path)
        return out

    slots = len(hash_table)

    def find(name):
        start = hash_string(name, 0) & (slots - 1)
        a, b = hash_string(name, 1), hash_string(name, 2)
        for step in range(slots):
            at = (start + step) % slots
            row = hash_table[at]
            if row[4] == EMPTY_NEVER_USED:
                return None
            if row[0] == a and row[1] == b and row[4] != EMPTY_DELETED:
                return at
        return None

    def free_slot(name):
        start = hash_string(name, 0) & (slots - 1)
        for step in range(slots):
            at = (start + step) % slots
            if hash_table[at][4] in (EMPTY_NEVER_USED, EMPTY_DELETED):
                return at
        return None

    # --- removals: the slot is marked deleted, the block marked gone ---------
    for name in remove:
        at = find(name)
        if at is None:
            continue
        index = hash_table[at][4]
        block_table[index][3] &= ~FILE_EXISTS & 0xFFFFFFFF
        hash_table[at][4] = EMPTY_DELETED
        listed.discard(name)

    # --- the listfile travels with the change --------------------------------
    for name in files:
        listed.add(name)
    files = dict(files)
    files["(listfile)"] = "\r\n".join(sorted(listed)).encode("utf-8")

    # --- room ----------------------------------------------------------------
    free = sum(1 for row in hash_table
               if row[4] in (EMPTY_NEVER_USED, EMPTY_DELETED))
    new_names = [n for n in files if find(n) is None]
    if free - len(new_names) < slots // keep_free:
        was = slots
        hash_table = grown(hash_table, len(new_names))
        slots = len(hash_table)
        print("    the archive's hash table grew from %d slots to %d"
              % (was, slots))

    end = os.path.getsize(path)
    blob = bytearray()
    for name, raw in files.items():
        stored, flags = raw, FILE_EXISTS | FILE_SINGLE_UNIT
        if compress:
            packed = b"\x02" + zlib.compress(raw, 9)
            if len(packed) < len(raw):
                stored, flags = packed, flags | FILE_COMPRESS
        position = end + len(blob) - base
        block = [position, len(stored), len(raw), flags]
        at = find(name)
        if at is not None:
            block_table[hash_table[at][4]] = block
        else:
            slot = free_slot(name)
            hash_table[slot] = [hash_string(name, 1), hash_string(name, 2),
                                0, 0, len(block_table)]
            block_table.append(block)
        blob += stored

    raw_hash = b"".join(struct.pack("<IIHHI", *row) for row in hash_table)
    raw_block = b"".join(struct.pack("<IIII", *row) for row in block_table)
    hash_at = end + len(blob) - base
    block_at = hash_at + len(raw_hash)
    total = block_at + len(raw_block)
    if total >= 1 << 32:
        raise ValueError("%s: the result would cross 4 GB, which this writer "
                         "does not handle" % path)

    with open(path, "r+b") as out:
        out.seek(end)
        out.write(blob)
        out.write(encrypt(raw_hash, hash_string(HASH_TABLE_KEY, 3)))
        out.write(encrypt(raw_block, hash_string(BLOCK_TABLE_KEY, 3)))
        # The header: where the tables now are, how many blocks, how big.
        out.seek(base)
        head = bytearray(out.read(HEADER.size))
        struct.pack_into("<I", head, 8, total)             # archive size
        struct.pack_into("<I", head, 16, hash_at)
        struct.pack_into("<I", head, 20, block_at)
        struct.pack_into("<I", head, 24, len(hash_table))
        struct.pack_into("<I", head, 28, len(block_table))
        out.seek(base)
        out.write(bytes(head))
        if version >= 1:
            # no high-word table, and the high halves of both positions are 0
            out.seek(base + 32)
            out.write(struct.pack("<QHH", 0, 0, 0))
    return len(files), len(remove)
