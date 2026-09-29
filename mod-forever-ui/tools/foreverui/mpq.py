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

"""Reads MPQ archives, the 3.3.5 client's data format, and patches files into an existing one.

Pure Python, so the installer needs no StormLib (a 32-bit library that needs a matching
interpreter). An archive is a header, a hash table and a block table, then the files.
Both tables are encrypted with a key derived from their name. Names are not stored: a
path is hashed three times, once to pick a slot and twice to confirm it.
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

    In both directions the running seed is fed the PLAIN value: read after unmasking when
    decrypting, before masking when encrypting. Getting it backwards still yields a correct
    first word.
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
    """PKWARE implode, the compression used before zlib.

    Not implemented: such a file is reported as unreadable rather than returned wrong.
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
        # An executable may sit in front of the archive; the header is on a 512-byte boundary.
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

    The game does not merge archives: the highest-priority archive that has a path answers
    for it, so later patches win over base files.
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
        """Every path the archives list in their `(listfile)`.

        An archive may lack a listfile and still be read by name, so this is what can be
        enumerated, not everything that exists.
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
    """Sort key of an archive in the reading order, from its file name.

    Three groups, lowest first:
      0  base data: common, expansion, lichking and their locale halves
      1  locale patches: patch-enUS, patch-enUS-2 ... patch-enUS-Z
      2  plain patches: patch, patch-2 ... patch-Z
    A plain patch beats the locale patch of the same rank, so a server archive named
    `patch-Z` sits on top. Within a group: unsuffixed first, then digits, then letters.
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

    `locale`: locale subfolder of `data_dir` to include. `ignore`: archive file names to
    leave out. Put the module's own archive there when asking what the stock client holds;
    otherwise every identifier it adds reads as already taken.
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


# ------------------------------------------------------ Writing into an archive

def patch_archive(path, files, remove=(), compress=True, keep_free=8):
    """Adds, replaces or removes files in an existing archive, in place.

    `files` maps archive paths to bytes (replaced if present, added otherwise); `remove`
    lists paths to delete; the listfile is kept in step. `keep_free`: at least
    slots // keep_free hash slots stay free. Returns (files written, len(remove)).

    New data and both tables are appended; replaced blocks point at the new data and
    nothing existing moves, so the caller keeps its own backup. A hash table that is too
    small is rebuilt bigger from the names in `(listfile)`, which must name every occupied
    slot. Raises ValueError before writing if the table cannot grow or the result would
    cross 4 GB (the high-word table is not handled).
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
        # Archive-internal files are never in the listfile; name them so a rebuild keeps them.
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
