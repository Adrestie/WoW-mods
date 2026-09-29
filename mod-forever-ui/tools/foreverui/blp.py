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

"""BLP2 reader (palette, DXT1, DXT3, DXT5) returning raw RGBA, and writer for uncompressed BGRA.

The client's interface art is in Data/enus/locale-enus.mpq, not in the common archives:
mpq.open_client does not see it, so open the locale archive directly.
The client draws sheets wider than 1024 as noise; the encoder lets a piece of a sheet be
saved as a small separate image.
"""
import struct


# Colors, alphas and 2-bit indices of an 8-byte DXT color block.
def _dxt_colors(block):
    c0, c1 = struct.unpack_from("<HH", block, 0)

    def expand(c):
        r = (c >> 11) & 0x1F
        v = (c >> 5) & 0x3F
        b = c & 0x1F
        return ((r * 255 + 15) // 31, (v * 255 + 31) // 63, (b * 255 + 15) // 31)

    a, b = expand(c0), expand(c1)
    if c0 > c1:
        c2 = tuple((2 * a[i] + b[i]) // 3 for i in range(3))
        c3 = tuple((a[i] + 2 * b[i]) // 3 for i in range(3))
        alphas = (255, 255, 255, 255)
    else:
        c2 = tuple((a[i] + b[i]) // 2 for i in range(3))
        c3 = (0, 0, 0)
        alphas = (255, 255, 255, 0)
    return (a, b, c2, c3), alphas, struct.unpack_from("<I", block, 4)[0]


# Decodes BLP2 bytes into (width, height, rgba, format info).
def decode(data):
    magic, type_, encoding, alphaDepth, encAlpha, mips = struct.unpack_from("<4sIBBBB", data, 0)
    assert magic == b"BLP2", magic
    width, height = struct.unpack_from("<II", data, 12)
    offsets = struct.unpack_from("<16I", data, 20)
    sizes = struct.unpack_from("<16I", data, 84)
    palette = struct.unpack_from("<256I", data, 148)
    start, size = offsets[0], sizes[0]
    raw = data[start:start + size]
    px = bytearray(width * height * 4)

    if encoding == 1:
        for i in range(width * height):
            c = palette[raw[i]]
            px[i*4+0] = (c >> 16) & 0xFF      # the palette is BGRA
            px[i*4+1] = (c >> 8) & 0xFF
            px[i*4+2] = c & 0xFF
            px[i*4+3] = 255
        if alphaDepth == 8:
            base = width * height
            for i in range(width * height):
                px[i*4+3] = raw[base + i]
        elif alphaDepth == 1:
            base = width * height
            for i in range(width * height):
                byte = raw[base + (i >> 3)]
                px[i*4+3] = 255 if (byte >> (i & 7)) & 1 else 0
    elif encoding == 2:
        dxt5 = (encAlpha == 7)
        dxt3 = (encAlpha == 1)
        step = 16 if (dxt5 or dxt3) else 8
        n = 0
        for by in range(0, height, 4):
            for bx in range(0, width, 4):
                block = raw[n:n+step]
                n += step
                if dxt5:
                    a0, a1 = block[0], block[1]
                    bits = int.from_bytes(block[2:8], "little")
                    if a0 > a1:
                        table = [a0, a1] + [((7-i)*a0 + i*a1)//7 for i in range(1, 7)]
                    else:
                        table = [a0, a1] + [((5-i)*a0 + i*a1)//5 for i in range(1, 5)] + [0, 255]
                    colors, _, indices = _dxt_colors(block[8:16])
                elif dxt3:
                    alphas4 = block[0:8]
                    colors, _, indices = _dxt_colors(block[8:16])
                else:
                    colors, alphasDXT1, indices = _dxt_colors(block[0:8])
                for j in range(16):
                    x, y = bx + (j % 4), by + (j // 4)
                    if x >= width or y >= height:
                        continue
                    idx = (indices >> (2 * j)) & 3
                    r, v, b = colors[idx]
                    if dxt5:
                        a = table[(bits >> (3 * j)) & 7]
                    elif dxt3:
                        o = alphas4[j // 2]
                        a = ((o & 0x0F) if j % 2 == 0 else (o >> 4)) * 17
                    else:
                        a = alphasDXT1[idx] if idx == 3 else 255
                    p = (y * width + x) * 4
                    px[p], px[p+1], px[p+2], px[p+3] = r, v, b, a
    elif encoding == 3:
        for i in range(width * height):
            b, v, r, a = raw[i*4:i*4+4]
            px[i*4:i*4+4] = bytes((r, v, b, a))
    else:
        raise ValueError("encodage %d inconnu" % encoding)

    return width, height, bytes(px), dict(encoding=encoding, alphaDepth=alphaDepth,
                                             encAlpha=encAlpha, mips=mips)


# The BLP2 header is 148 bytes, followed by a 1024-byte palette, present even in BGRA where
# it is unused. Data starts at 1172.
DATA_START = 148 + 1024


# RGBA bytes to BGRA.
def _bgra(width, height, rgba):
    assert len(rgba) == width * height * 4, "taille d'image incoherente"
    body = bytearray(width * height * 4)
    for i in range(width * height):
        r, v, b, a = rgba[i*4:i*4+4]
        body[i*4:i*4+4] = bytes((b, v, r, a))
    return bytes(body)


def encode(width, height, rgba, mipmaps=None):
    """Writes an uncompressed BGRA BLP2.

    rgba: R, G, B, A bytes, row by row from the top.
    mipmaps: reduced levels, largest first, each (width, height, rgba); at most 15.
    An image the client draws smaller than its size needs them (the original minimap arrows
    have six levels).
    """
    levels = [(width, height, rgba)] + list(mipmaps or [])
    assert len(levels) <= 16, "un BLP2 porte au plus 16 niveaux"

    header = bytearray(DATA_START)
    header[0:4] = b"BLP2"
    struct.pack_into("<I", header, 4, 1)            # type: uncompressed
    header[8] = 3                                   # encoding: BGRA
    header[9] = 8                                   # alpha depth
    header[10] = 8                                  # alpha encoding
    header[11] = 1 if mipmaps else 0                # has mipmaps
    struct.pack_into("<II", header, 12, width, height)

    body = bytearray()
    for i, (l, h, pixels) in enumerate(levels):
        data = _bgra(l, h, pixels)
        struct.pack_into("<I", header, 20 + 4 * i, DATA_START + len(body))  # mipOffsets[i]
        struct.pack_into("<I", header, 84 + 4 * i, len(data))               # mipSizes[i]
        body += data
    return bytes(header) + bytes(body)
