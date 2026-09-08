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

This module READS. Writing an archive is another matter, and the installer does
not need it: what it adds to a client goes into a patch archive of its own.
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
