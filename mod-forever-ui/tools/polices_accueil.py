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

"""Les polices de camelot pour les ecrans d'accueil de 3.3.5, aplaties.

POURQUOI. Dans 3.3.5, une police qui en herite une autre (<Font
inherits="X">) garde la TAILLE de X meme si elle declare sa propre
<FontHeight> : la surcharge est ignoree (mesure du 2026-09-27 : « Back »
declare en 22 dessine en 15, « Alliance » declare en 18 dessine en 12). Les
styles de camelot sont presque tous des heritages. On resout donc l'heritage
ICI, une fois pour toutes, et chaque police est ecrite complete : fichier,
taille, contour, ombre, couleur, justification, espacement.

CE QU'IL LIT. Les definitions de camelot, dans l'ordre de chargement des
ecrans d'accueil (blizzard_fonts_shared.toc) : [Family]\\Fonts.xml,
Shared\\Fonts.xml, Shared\\GlueFonts.xml, Shared\\FontStyles.xml,
[Family]\\FontStyles.xml, [Family]\\GlueFontStyles.xml,
Shared\\GlueFontStyles.xml ([Family] = mainline pour camelot). D'une
FontFamily, le membre de l'alphabet latin (roman). Les couleurs nommees
(color="NORMAL_FONT_COLOR") sont lues dans GlobalColor.db2 du client moderne.

CE QU'IL ECRIT. data/glue/Interface/GlueXML/ForeverUIGlueFonts.xml : une
<Font virtual> par police de camelot, nommee ForeverUIGlue_<nom de camelot>
(aucune globale du client n'est ecrasee). Les tailles sont celles de camelot,
en unites de camelot : l'echelle des ecrans d'accueil (ForeverUIGlue.lua)
fait le reste.
"""
import io
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(os.path.expanduser("~"), "Desktop", "addons", "blizzard_fonts_shared")
COULEURS = os.path.join(os.path.expanduser("~"), "wow.export", "dbfilesclient", "globalcolor.db2")
POLICES_CLIENT = r"E:\world of warcraft 3.3.5a hd\fonts"
SORTIE = os.path.join(RACINE, "data", "glue", "Interface", "GlueXML", "ForeverUIGlueFonts.xml")
PREFIXE = "ForeverUIGlue_"

ORDRE = [
    ("mainline", "fonts.xml"),
    ("shared", "fonts.xml"),
    ("shared", "gluefonts.xml"),
    ("shared", "fontstyles.xml"),
    ("mainline", "fontstyles.xml"),
    ("mainline", "gluefontstyles.xml"),
    ("shared", "gluefontstyles.xml"),
]


def couleurs_nommees():
    """GlobalColor.db2 (WDC5, une section) : nom -> (r, g, b, a)."""
    d = io.open(COULEURS, "rb").read()
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
    stockage = [struct.unpack_from("<HHIIIII", d, o + 24 * i) for i in range(total_fields)]
    _, debut, nombre = sections[0][:3]
    res = {}
    for i in range(nombre):
        base = debut + i * rec_size
        valeurs = []
        for bits, taille, _, _, _, _, _ in stockage:
            octet = bits // 8
            valeurs.append((octet, int.from_bytes(d[base + octet: base + octet + taille // 8], "little")))
        o0, v0 = valeurs[0]
        p = base + o0 + v0
        nom = d[p:d.index(b"\x00", p)].decode("utf-8")
        c = valeurs[1][1]
        res[nom] = (((c >> 16) & 255) / 255.0, ((c >> 8) & 255) / 255.0, (c & 255) / 255.0, ((c >> 24) & 255) / 255.0)
    return res


def _nombre(v, defaut=None):
    return float(v) if v is not None else defaut


def lire_couleur(el, nommees):
    nom = el.get("color")
    if nom:
        if nom not in nommees:
            raise SystemExit("couleur nommee inconnue : %s" % nom)
        return nommees[nom]
    return (_nombre(el.get("r"), 0.0), _nombre(el.get("g"), 0.0), _nombre(el.get("b"), 0.0), _nombre(el.get("a"), 1.0))


def lire_ombre(el, nommees):
    ombre = {"x": 0.0, "y": 0.0, "couleur": (0.0, 0.0, 0.0, 1.0)}
    dim = el.find("Offset/AbsDimension")
    if dim is not None:
        ombre["x"] = _nombre(dim.get("x"), 0.0)
        ombre["y"] = _nombre(dim.get("y"), 0.0)
    elif el.find("Offset") is not None:
        off = el.find("Offset")
        ombre["x"] = _nombre(off.get("x"), 0.0)
        ombre["y"] = _nombre(off.get("y"), 0.0)
    c = el.find("Color")
    if c is not None:
        ombre["couleur"] = lire_couleur(c, nommees)
    return ombre


ATTRIBUTS = ("font", "outline", "monochrome", "justifyH", "justifyV", "spacing", "height")


def appliquer(fiche, el, nommees):
    """Les attributs et enfants d'un <Font> par-dessus une fiche heritee."""
    for a in ATTRIBUTS:
        if el.get(a) is not None:
            fiche[a] = el.get(a)
    fh = el.find("FontHeight/AbsValue")
    if fh is not None:
        fiche["height"] = fh.get("val")
    c = el.find("Color")
    if c is not None:
        fiche["couleur"] = lire_couleur(c, nommees)
    s = el.find("Shadow")
    if s is not None:
        fiche["ombre"] = lire_ombre(s, nommees)
    return fiche


def lire_tout(nommees):
    polices = {}
    for dossier, fichier in ORDRE:
        chemin = os.path.join(SOURCE, dossier, fichier)
        if not os.path.exists(chemin):
            continue
        texte = io.open(chemin, encoding="utf-8").read()
        texte = re.sub(r'\sxmlns(:\w+)?="[^"]*"', "", texte)
        texte = re.sub(r'\sxsi:schemaLocation="[^"]*"', "", texte)
        racine = ET.fromstring(texte)
        for el in racine:
            nom = el.get("name")
            if not nom:
                continue
            if el.tag == "FontFamily":
                membre = el.find("Member[@alphabet='roman']/Font")
                if membre is None:
                    continue
                polices[nom] = appliquer({}, membre, nommees)
            elif el.tag == "Font":
                parent = el.get("inherits")
                if parent:
                    if parent not in polices:
                        raise SystemExit("%s herite de %s, inconnue a ce stade" % (nom, parent))
                    fiche = dict(polices[parent])
                else:
                    fiche = {}
                polices[nom] = appliquer(fiche, el, nommees)
    return polices


def fichier_client(chemin):
    """Le fichier de police tel que 3.3.5 l'a (fonts\\ en minuscules)."""
    base = os.path.basename(chemin.replace("\\", "/")).lower()
    return os.path.exists(os.path.join(POLICES_CLIENT, base))


def ecrire(polices):
    lignes = [
        '<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.blizzard.com/wow/ui/',
        '..\\FrameXML\\UI.xsd">',
        "\t<!-- les polices de camelot, heritage resolu : genere par tools/polices_accueil.py -->",
    ]
    absentes = set()
    n = 0
    for nom in sorted(polices):
        f = polices[nom]
        if "font" not in f or "height" not in f:
            continue
        if not fichier_client(f["font"]):
            absentes.add(f["font"])
            continue
        attrs = ['name="%s%s"' % (PREFIXE, nom), 'font="%s"' % f["font"]]
        for a in ("outline", "monochrome", "justifyH", "justifyV", "spacing"):
            if f.get(a) is not None:
                attrs.append('%s="%s"' % (a, f[a]))
        attrs.append('virtual="true"')
        lignes.append("\t<Font %s>" % " ".join(attrs))
        lignes.append('\t\t<FontHeight><AbsValue val="%s"/></FontHeight>' % f["height"])
        if "ombre" in f:
            o = f["ombre"]
            r, g, b, a = o["couleur"]
            lignes.append('\t\t<Shadow><Offset><AbsDimension x="%g" y="%g"/></Offset><Color r="%.4f" g="%.4f" b="%.4f" a="%.4f"/></Shadow>'
                          % (o["x"], o["y"], r, g, b, a))
        if "couleur" in f:
            r, g, b, a = f["couleur"]
            lignes.append('\t\t<Color r="%.4f" g="%.4f" b="%.4f" a="%.4f"/>' % (r, g, b, a))
        lignes.append("\t</Font>")
        n += 1
    lignes += ["</Ui>", ""]
    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    io.open(SORTIE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print("polices : %d ecrites -> %s" % (n, os.path.relpath(SORTIE, RACINE)))
    if absentes:
        print("   fichiers absents du client 3.3.5 (polices ecartees) : %s" % ", ".join(sorted(absentes)))


def main():
    nommees = couleurs_nommees()
    polices = lire_tout(nommees)
    ecrire(polices)
    for nom in sys.argv[1:]:
        print("   %s : %s" % (nom, polices.get(nom)))


if __name__ == "__main__":
    main()
