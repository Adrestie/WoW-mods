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

"""Reading just enough of an M2 model to know what it drags along with it.

A model is never alone. It names its own TEXTURES, and the client looks for its
mesh in separate SKIN files whose names it derives from the model's own. Ship
the model and forget either, and the game draws a pink chequerboard or nothing
at all.

Only the header is read -- counts and offsets -- and the two lists that matter.
Nothing here understands geometry, and nothing needs to.
"""
import struct

MAGIC = b"MD20"

# Where the header keeps what this module needs. The layout is the one every
# 3.3.5 model uses; a file that does not start with MD20 is not read at all.
NAME = 0x08          # length, offset
VIEWS = 0x44         # how many skin files accompany the model
TEXTURES = 0x50      # count, offset -- then 16 bytes per texture

TEXTURE_ON_DISK = 0  # a texture of any other type is supplied by the game


def _string(raw, offset, length):
    """One name out of the model.

    READ TO THE ZERO, NOT TO THE LENGTH. The declared length is unreliable in
    both directions: usually it is the room the name was given, padded with
    zeroes -- and taking it whole yields a path no archive answers for, which
    is how a hundred textures nearly failed to ship. But some models, ported
    from a later game, declare LESS than the name they hold: one says 25 for
    `spells/vary_spores_splash.blp`, and trusting it loses the file.

    So the length only bounds the search, generously, and the terminator
    decides. That is what the client itself does.
    """
    window = max(length, 260)
    end = raw.find(b"\x00", offset, offset + window)
    if end < 0:
        end = offset + length
    return raw[offset:end].decode("ascii", "replace").strip()


def is_model(raw):
    return raw[:4] == MAGIC


def name(raw):
    length, offset = struct.unpack_from("<II", raw, NAME)
    return _string(raw, offset, length) if length > 1 else ""


def textures(raw):
    """The texture files the model names.

    A texture whose type is not zero is one the game fills in itself -- a
    creature's skin, a player's armour -- and carries no file name. Those are
    skipped rather than reported as missing.
    """
    count, offset = struct.unpack_from("<II", raw, TEXTURES)
    out = []
    for index in range(count):
        kind, _, length, where = struct.unpack_from("<IIII", raw, offset + index * 16)
        if kind == TEXTURE_ON_DISK and length > 1:
            out.append(_string(raw, where, length))
    return out


def skins(path, raw):
    """The skin files that go with a model, named after it.

    The client does not read these names from anywhere: it builds them, one per
    view, as `<model without extension><two digits>.skin`.
    """
    count = struct.unpack_from("<I", raw, VIEWS)[0]
    stem = path.rsplit(".", 1)[0]
    return ["%s%02d.skin" % (stem, i) for i in range(count)]


def rename_textures(raw, rename):
    """A copy of the model whose texture names are put through `rename`.

    NOTHING IS MOVED. A model is a web of offsets into itself: shortening or
    lengthening a name in place would shift everything after it, and every
    offset past that point would point at the wrong byte. So a new name is
    APPENDED at the end of the file and the entry made to point there. The old
    name stays where it is, unread -- a few dozen wasted bytes against a model
    that still works.
    """
    count, offset = struct.unpack_from("<II", raw, TEXTURES)
    out = bytearray(raw)
    changed = 0
    for index in range(count):
        at = offset + index * 16
        kind, _, length, where = struct.unpack_from("<IIII", out, at)
        if kind != TEXTURE_ON_DISK or length <= 1:
            continue
        was = _string(out, where, length)
        now = rename(was)
        if now == was:
            continue
        while len(out) % 4:
            out += b"\x00"
        landing = len(out)
        out += now.encode("ascii") + b"\x00"
        struct.pack_into("<II", out, at + 8, len(now) + 1, landing)
        # THE OLD NAME IS BLANKED. Nothing points at it any more, but it is
        # still in the file -- and it is the name of the server the model came
        # from, which must not travel. Zeros are what an unread string may be.
        for i in range(where, where + length):
            if i < len(out):
                out[i] = 0
        changed += 1
    return bytes(out), changed
