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

"""Camelot's fonts for the 3.3.5 login screens, with inheritance flattened.

In 3.3.5 a font that inherits another (<Font inherits="X">) keeps X's size even if it
declares its own <FontHeight>. Nearly all camelot styles inherit, so inheritance is
resolved here and each font is written in full: file, size, outline, shadow, color,
justification, spacing.

Reads camelot's definitions in the login screens' load order (blizzard_fonts_shared.toc):
[Family]/Fonts.xml, Shared/Fonts.xml, Shared/GlueFonts.xml, Shared/FontStyles.xml,
[Family]/FontStyles.xml, [Family]/GlueFontStyles.xml, Shared/GlueFontStyles.xml
([Family] = mainline). From a FontFamily, the roman member. Named colors
(color="NORMAL_FONT_COLOR") come from the modern client's GlobalColor.db2.

Writes data/glue/Interface/GlueXML/ForeverUIGlueFonts.xml: one virtual <Font> per camelot
font, named ForeverUIGlue_<camelot name>, so no client global is overwritten. Sizes are in
camelot units; the login screen scale (ForeverUIGlue.lua) does the rest.
"""
import io
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(os.path.expanduser("~"), "Desktop", "addons", "blizzard_fonts_shared")
COLORS = os.path.join(os.path.expanduser("~"), "wow.export", "dbfilesclient", "globalcolor.db2")
CLIENT_FONTS = r"E:\world of warcraft 3.3.5a hd\fonts"
OUTPUT = os.path.join(ROOT, "data", "glue", "Interface", "GlueXML", "ForeverUIGlueFonts.xml")
PREFIX = "ForeverUIGlue_"

ORDER = [
    ("mainline", "fonts.xml"),
    ("shared", "fonts.xml"),
    ("shared", "gluefonts.xml"),
    ("shared", "fontstyles.xml"),
    ("mainline", "fontstyles.xml"),
    ("mainline", "gluefontstyles.xml"),
    ("shared", "gluefontstyles.xml"),
]


def read_named_colors():
    """GlobalColor.db2 (WDC5, one section): name -> (r, g, b, a)."""
    d = io.open(COLORS, "rb").read()
    o = 4 + 4 + 128
    rec_count, field_count, rec_size, str_size = struct.unpack_from("<4I", d, o)
    o += 36 + 4
    total_fields, _, _, fsi_size, _, _, section_count = struct.unpack_from("<7I", d, o)
    o += 28
    sections = []
    for _ in range(section_count):
        sections.append(struct.unpack_from("<QIIIIIIII", d, o))
        o += 40
    o += 4 * total_fields
    storage = [struct.unpack_from("<HHIIIII", d, o + 24 * i) for i in range(total_fields)]
    _, start, count = sections[0][:3]
    res = {}
    for i in range(count):
        base = start + i * rec_size
        values = []
        for bits, size, _, _, _, _, _ in storage:
            byte = bits // 8
            values.append((byte, int.from_bytes(d[base + byte: base + byte + size // 8], "little")))
        o0, v0 = values[0]
        p = base + o0 + v0
        name = d[p:d.index(b"\x00", p)].decode("utf-8")
        c = values[1][1]
        res[name] = (((c >> 16) & 255) / 255.0, ((c >> 8) & 255) / 255.0, (c & 255) / 255.0, ((c >> 24) & 255) / 255.0)
    return res


def _number(v, default=None):
    return float(v) if v is not None else default


def read_color(el, named_colors):
    name = el.get("color")
    if name:
        if name not in named_colors:
            raise SystemExit("couleur nommee inconnue : %s" % name)
        return named_colors[name]
    return (_number(el.get("r"), 0.0), _number(el.get("g"), 0.0), _number(el.get("b"), 0.0), _number(el.get("a"), 1.0))


def read_shadow(el, named_colors):
    shadow = {"x": 0.0, "y": 0.0, "color": (0.0, 0.0, 0.0, 1.0)}
    dim = el.find("Offset/AbsDimension")
    if dim is not None:
        shadow["x"] = _number(dim.get("x"), 0.0)
        shadow["y"] = _number(dim.get("y"), 0.0)
    elif el.find("Offset") is not None:
        off = el.find("Offset")
        shadow["x"] = _number(off.get("x"), 0.0)
        shadow["y"] = _number(off.get("y"), 0.0)
    c = el.find("Color")
    if c is not None:
        shadow["color"] = read_color(c, named_colors)
    return shadow


ATTRIBUTES = ("font", "outline", "monochrome", "justifyH", "justifyV", "spacing", "height")


def apply(card, el, named_colors):
    """Applies a <Font>'s attributes and children over an inherited card."""
    for a in ATTRIBUTES:
        if el.get(a) is not None:
            card[a] = el.get(a)
    fh = el.find("FontHeight/AbsValue")
    if fh is not None:
        card["height"] = fh.get("val")
    c = el.find("Color")
    if c is not None:
        card["color"] = read_color(c, named_colors)
    s = el.find("Shadow")
    if s is not None:
        card["shadow"] = read_shadow(s, named_colors)
    return card


# Reads every camelot font in load order, inheritance resolved: name -> card.
def read_all(named_colors):
    fonts = {}
    for folder, file in ORDER:
        path = os.path.join(SOURCE, folder, file)
        if not os.path.exists(path):
            continue
        text = io.open(path, encoding="utf-8").read()
        text = re.sub(r'\sxmlns(:\w+)?="[^"]*"', "", text)
        text = re.sub(r'\sxsi:schemaLocation="[^"]*"', "", text)
        root = ET.fromstring(text)
        for el in root:
            name = el.get("name")
            if not name:
                continue
            if el.tag == "FontFamily":
                member = el.find("Member[@alphabet='roman']/Font")
                if member is None:
                    continue
                fonts[name] = apply({}, member, named_colors)
            elif el.tag == "Font":
                parent = el.get("inherits")
                if parent:
                    if parent not in fonts:
                        raise SystemExit("%s herite de %s, inconnue a ce stade" % (name, parent))
                    card = dict(fonts[parent])
                else:
                    card = {}
                fonts[name] = apply(card, el, named_colors)
    return fonts


def client_has_file(path):
    """Whether the 3.3.5 client has this font file (basename, lower case, in its fonts folder)."""
    base = os.path.basename(path.replace("\\", "/")).lower()
    return os.path.exists(os.path.join(CLIENT_FONTS, base))


# Writes the XML; fonts whose file the 3.3.5 client lacks are skipped and listed.
def write(fonts):
    rows = [
        '<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.blizzard.com/wow/ui/',
        '..\\FrameXML\\UI.xsd">',
        "\t<!-- Camelot's fonts, inheritance resolved: generated by tools/glue_fonts.py -->",
    ]
    missing = set()
    n = 0
    for name in sorted(fonts):
        f = fonts[name]
        if "font" not in f or "height" not in f:
            continue
        if not client_has_file(f["font"]):
            missing.add(f["font"])
            continue
        attrs = ['name="%s%s"' % (PREFIX, name), 'font="%s"' % f["font"]]
        for a in ("outline", "monochrome", "justifyH", "justifyV", "spacing"):
            if f.get(a) is not None:
                attrs.append('%s="%s"' % (a, f[a]))
        attrs.append('virtual="true"')
        rows.append("\t<Font %s>" % " ".join(attrs))
        rows.append('\t\t<FontHeight><AbsValue val="%s"/></FontHeight>' % f["height"])
        if "shadow" in f:
            o = f["shadow"]
            r, g, b, a = o["color"]
            rows.append('\t\t<Shadow><Offset><AbsDimension x="%g" y="%g"/></Offset><Color r="%.4f" g="%.4f" b="%.4f" a="%.4f"/></Shadow>'
                          % (o["x"], o["y"], r, g, b, a))
        if "color" in f:
            r, g, b, a = f["color"]
            rows.append('\t\t<Color r="%.4f" g="%.4f" b="%.4f" a="%.4f"/>' % (r, g, b, a))
        rows.append("\t</Font>")
        n += 1
    rows += ["</Ui>", ""]
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    io.open(OUTPUT, "w", encoding="utf-8", newline="\n").write("\n".join(rows))
    print("polices : %d ecrites -> %s" % (n, os.path.relpath(OUTPUT, ROOT)))
    if missing:
        print("   fichiers absents du client 3.3.5 (polices ecartees) : %s" % ", ".join(sorted(missing)))


def main():
    named_colors = read_named_colors()
    fonts = read_all(named_colors)
    write(fonts)
    for name in sys.argv[1:]:
        print("   %s : %s" % (name, fonts.get(name)))


if __name__ == "__main__":
    main()
