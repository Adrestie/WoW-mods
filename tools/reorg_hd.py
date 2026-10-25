"""Regroups the HD pack's archives of Data by theme, into archives whose letters follow each other.

Each file goes once, in the version the game shows today (the last archive read wins), into the
archive of its theme: no file is in two of them, so their order among themselves no longer matters
and the game shows exactly the same thing, as long as they stay between Blizzard's (patch-2, patch-3)
and the mods' (patch-Y, patch-Z). Stored bytes are copied as they are (same sector size, no
encryption: checked before anything is written).

  python tools/reorg_hd.py build  <client> <out>   writes the new archives into <out>
  python tools/reorg_hd.py verify <client> <out>   compares every file with today's version

Writes nothing into the game folder: the swap is done by hand, game closed.
"""
import hashlib
import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "installer"))
import mpq_archive as M  # noqa: E402

# Today's HD archives of Data, in the order the game reads them.
SOURCES = ["patch-5", "patch-6", "patch-7", "patch-8", "patch-a", "patch-b", "patch-e", "patch-f",
           "patch-s", "patch-t", "patch-w", "patch-x"]
TARGETS = {"monde": "patch-4", "personnages": "patch-5", "creatures": "patch-6", "armures": "patch-7",
           "armes": "patch-8", "sorts": "patch-9", "sons": "patch-a", "interface": "patch-b"}
# DBC files go with the theme of the archive that carries them today.
TABLES = {"patch-s": "sorts", "patch-b": "sorts", "patch-x": "monde", "patch-w": "monde"}


def theme(name, source):
    p = name.lower().split("\\")
    top, sub = p[0], (p[1] if len(p) > 2 else "")
    if name.lower().endswith(".dbc"):
        return TABLES[source]
    if top == "textures" and sub == "bakednpctextures" or top in ("character", "alternate"):
        return "personnages"
    if top in ("world", "tileset", "dungeons", "xtextures", "environments", "textures"):
        return "monde"
    if top in ("creature", "models"):
        return "creatures"
    if top == "item":
        return "armes" if len(p) > 3 and sub == "objectcomponents" and p[2] in ("weapon", "shield") else "armures"
    if top in ("spells", "particles"):
        return "sorts"
    if top == "sound":
        return "sons"
    if top in ("interface", "fonts"):
        return "interface"
    raise SystemExit("no theme for %s (%s)" % (name, source))


def listed(a):
    text = a.read("(listfile)").decode("utf-8", "replace")
    names = [n.strip() for n in text.replace(";", "\n").splitlines() if n.strip()]
    return [n for n in dict.fromkeys(names) if a.contains(n) and n.lower() not in ("(listfile)", "(attributes)")]


def plan(client):
    """{theme: {lower name: (source, name)}}: today's winner of each file, by theme."""
    data = os.path.join(client, "Data")
    archives = {s: M.Archive(os.path.join(data, s + ".mpq")) for s in SOURCES}
    for s, a in archives.items():
        if a.sector_size != 4096 or any(a.hi_blocks):
            raise SystemExit("%s: sector size %d or hi-block table, not handled" % (s, a.sector_size))
    winner = {}
    for s in SOURCES:
        for n in listed(archives[s]):
            winner[n.lower()] = (s, n)
    themes = {t: {} for t in TARGETS}
    for key, (s, n) in winner.items():
        themes[theme(n, s)][key] = (s, n)
    return archives, themes


def entry(a, name):
    i = a._hash_index(name)
    e = a.hash_table[i]
    return e, a.block_table[e[4]]


def build(client, out):
    archives, themes = plan(client)
    os.makedirs(out, exist_ok=True)
    for t, files in themes.items():
        path = os.path.join(out, TARGETS[t] + ".MPQ")
        names = sorted(n for _, n in files.values())
        listfile = ("\r\n".join(names) + "\r\n").encode("utf-8")
        size = 1024
        while (len(names) + 1) * 4 > size * 3:
            size *= 2
        hash_table = [[M.M32, M.M32, 0xFFFF, 0xFFFF, M.HASH_ENTRY_EMPTY] for _ in range(size)]
        blocks = []

        def place(name, locale, platform):
            i = M.hash_string(name, 0) & (size - 1)
            while hash_table[i][4] != M.HASH_ENTRY_EMPTY:
                i = (i + 1) & (size - 1)
            hash_table[i] = [M.hash_string(name, 1), M.hash_string(name, 2), locale, platform, len(blocks)]

        handles = {}
        with open(path + ".tmp", "wb") as f:
            f.write(b"\0" * 32)
            pos = 32
            for key in sorted(files):
                s, n = files[key]
                a = archives[s]
                e, (position, packed, usize, flags) = entry(a, n)
                if flags & (M.FILE_ENCRYPTED | M.FILE_IMPLODE):
                    raise SystemExit("%s in %s: encrypted or imploded, not handled" % (n, s))
                src = handles.setdefault(s, open(a.path, "rb"))
                src.seek(a.offset + position)
                data = src.read(packed)
                f.write(data)
                place(n, e[2], e[3])
                blocks.append([pos, packed, usize, flags])
                pos += packed
            packed = M._compress_sectors(listfile, 4096)
            f.write(packed)
            place("(listfile)", 0, 0)
            blocks.append([pos, len(packed), len(listfile), M.FILE_EXISTS | M.FILE_COMPRESS])
            pos += len(packed)
            hash_pos, block_pos = pos, pos + size * 16
            end = block_pos + len(blocks) * 16
            if end > M.M32:
                raise SystemExit("%s: more than 4 GB" % path)
            f.write(M.encrypt(b"".join(struct.pack("<IIHHI", *e) for e in hash_table), M.HASH_TABLE_KEY))
            f.write(M.encrypt(b"".join(struct.pack("<IIII", *b) for b in blocks), M.BLOCK_TABLE_KEY))
            f.seek(0)
            f.write(struct.pack("<4sIIHHIIII", M.MPQ_SIGNATURE, 32, end, 0, 3, hash_pos, block_pos, size, len(blocks)))
        for h in handles.values():
            h.close()
        os.replace(path + ".tmp", path)
        print("%s  %-12s %6d files  %.2f GB" % (TARGETS[t], t, len(names), os.path.getsize(path) / 1e9), flush=True)


def digest(a, name):
    """MD5 of the file; an empty one (stored as 0 bytes, which the reader refuses) hashes as b""."""
    if entry(a, name)[1][2] == 0:
        return hashlib.md5(b"").digest()
    return hashlib.md5(a.read(name)).digest()


def verify(client, out):
    archives, themes = plan(client)
    bad = 0
    for t, files in themes.items():
        new = M.Archive(os.path.join(out, TARGETS[t] + ".MPQ"))
        names = {n.lower() for n in listed(new)}
        if names != set(files):
            print("%s: %d files missing, %d extra" % (t, len(set(files) - names), len(names - set(files))))
            bad += 1
        for key, (s, n) in files.items():
            if digest(new, n) != digest(archives[s], n):
                print("%s: %s differs from %s" % (t, n, s))
                bad += 1
        # the same file must be in no other new archive
        print("%s %-12s %d files checked" % (TARGETS[t], t, len(files)), flush=True)
    keys = [k for files in themes.values() for k in files]
    if len(keys) != len(set(keys)):
        print("a file is in two archives")
        bad += 1
    print("OK" if not bad else "%d problem(s)" % bad)
    return bad


if __name__ == "__main__":
    mode, client, out = sys.argv[1:4]
    sys.exit(build(client, out) if mode == "build" else (1 if verify(client, out) else 0))
