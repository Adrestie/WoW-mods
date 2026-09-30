# -*- coding: utf-8 -*-
r"""Wow.exe of the 3.3.5a client (build 12340): whether it accepts changed
interface files, and the patch that makes it accept them (MIT licence).

The client computes a digest of the files that Interface\GlueXML\GlueXML.toc
lists (on start) and Interface\FrameXML\FrameXML.toc lists (on entering the
world), and compares it with Blizzard's signature. Any result but "valid" is
written to Logs\GlueXML.log or FrameXML.log ("... is modified or corrupt",
"... has corrupt signature", "... missing signature") and the game quits,
saying the interface files are corrupt and the game must be reinstalled.

The patch replaces the test of that result with a short jump to the "valid"
case: two bytes per check, written only over the exact original code and
recognised byte for byte afterwards. WarcraftXL (the loader of the HD client
packs: a .wxl section in Wow.exe, WarcraftXL.dll beside it) already skips the
check in memory.
"""
import os
import struct

# Per check: file offset of "cmp eax, 3 / ja / jmp [table]" after the digest
# call, the code before it (push of the .toc name, call, stack cleanup), the
# jump table whose 4th entry is the "valid" case, and the patched bytes
# ("jmp short" to that case).
CHECKS = {
    "GlueXML": {
        "context": (0xD9BD8, bytes.fromhex("6820439f00e8febd330083c414")),
        "site": (0xD9BE5, bytes.fromhex("83f8037734ff2485b4a94d00")),
        "table": (0xD9DB4, bytes.fromhex("f1a74d00fea74d000ba84d0035a84d00")),
        "patch": bytes.fromhex("eb4e"),
    },
    "FrameXML": {
        "context": (0x129FC7, bytes.fromhex("68ec2fa00068cc2fa000e80aba2e0083c418")),
        "site": (0x129FD9, bytes.fromhex("83f8037734ff2485b4ae5200")),
        "table": (0x12A2B4, bytes.fromhex("e5ab5200f2ab5200ffab52001cac5200")),
        "patch": bytes.fromhex("eb41"),
    },
}

BACKUP_SUFFIX = ".wow-mods.bak"


def find(folder):
    """The game's Wow.exe (any letter case), or None."""
    if os.path.isdir(folder):
        for n in os.listdir(folder):
            if n.lower() == "wow.exe" and os.path.isfile(os.path.join(folder, n)):
                return os.path.join(folder, n)
    return None


def _read(path):
    with open(path, "rb") as f:
        return f.read()


def _at(data, offset, expected):
    return data[offset:offset + len(expected)] == expected


def check_state(path, check):
    """"original" (the check runs), "patched" (turned off by this patch) or
    "unknown" (not the code of build 12340 the installer knows)."""
    data = _read(path)
    c = CHECKS[check]
    if not (_at(data, *c["context"]) and _at(data, *c["table"])):
        return "unknown"
    offset, original = c["site"]
    if _at(data, offset, original):
        return "original"
    if _at(data, offset, c["patch"] + original[len(c["patch"]):]):
        return "patched"
    return "unknown"


def section_names(data):
    """Names of the sections of a PE file, [] if it is not one."""
    if data[:2] != b"MZ" or len(data) < 0x40:
        return []
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        return []
    count, optional = struct.unpack_from("<H", data, pe + 6)[0], struct.unpack_from("<H", data, pe + 20)[0]
    first = pe + 24 + optional
    return [data[first + 40 * i:first + 40 * i + 8].rstrip(b"\0").decode("latin-1") for i in range(count)]


def runs_warcraftxl(path):
    """True if this Wow.exe loads WarcraftXL, which skips the interface checks in memory."""
    return ".wxl" in section_names(_read(path)) and \
        any(n.lower() == "warcraftxl.dll" for n in os.listdir(os.path.dirname(path)))


def _write(path, data):
    temporary = path + ".installer-tmp"
    try:
        with open(temporary, "wb") as f:
            f.write(data)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.remove(temporary)


def patch(path, checks):
    """Turns the given checks off. Copies Wow.exe beside itself first (BACKUP_SUFFIX) unless such a
    copy exists. Returns the path of the copy. Every check must be in the "original" state."""
    data = bytearray(_read(path))
    for check in checks:
        if check_state(path, check) != "original":
            raise ValueError("%s: the %s check is not in its original state" % (path, check))
        data[CHECKS[check]["site"][0]:CHECKS[check]["site"][0] + len(CHECKS[check]["patch"])] = CHECKS[check]["patch"]
    backup = path + BACKUP_SUFFIX
    if not os.path.exists(backup):
        _write(backup, _read(path))
    _write(path, bytes(data))
    return backup


def restore(path, checks):
    """Puts the original code of the given checks back; each must be in the "patched" state."""
    data = bytearray(_read(path))
    for check in checks:
        if check_state(path, check) != "patched":
            raise ValueError("%s: the %s check is not patched" % (path, check))
        offset, original = CHECKS[check]["site"]
        data[offset:offset + len(original)] = original
    _write(path, bytes(data))
