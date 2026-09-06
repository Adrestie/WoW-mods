# -*- coding: utf-8 -*-
r"""L'IMPOSTOR d'une disposition : son dessin cuit en une image, à poser sur la
carte des stats.

Ce n'est pas le vrai layout — c'est une image de ses emplacements et de ses
liaisons, projetée dans le CADRE de la carte (le même que celui du générateur,
`genere_commune.cadre`), pour voir d'un coup d'œil où chaque nœud est tombé et
quelle statistique il a reçue.

Couleurs : un emplacement prend la fausse couleur de sa statistique dans la
palette — teinte du canal (rouge : offensif physique, vert : défense et liant,
bleu : magie et soins), d'autant plus claire que le bit est haut ; gris pour un
nœud vide, carré bleu pour un slot, or pour un sort, anneau d'or pour le départ.
Une carte donnée en fond est elle aussi affichée en fausse couleur : ses valeurs
brutes sont des bits, presque noirs à l'œil.

    python impostor.py <disposition> <sortie.png> [carte.png]
      cuit l'impostor de layouts\<disposition>.xml, sur la carte si elle est
      donnée, sur du noir sinon.
"""
import io
import math
import os
import re
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from genere_commune import LAYOUTS, PAS, RAYONS, cadre, position, vers_pixel  # noqa: E402
from palette_carte import PALETTE, affiche, couleur  # noqa: E402

CANAL_DE = {stat: (canal, bit) for stat, canal, bit in PALETTE}


def lit_layout(chemin):
    t = io.open(chemin, encoding="utf-8").read()
    clusters = {int(m.group(1)): (float(m.group(2)), float(m.group(3)))
                for m in re.finditer(r'<cluster id="(\d+)" x="([-\d.]+)" y="([-\d.]+)"', t)}
    noeuds = {}
    for m in re.finditer(r'<emplacement ([^/]*)/>', t):
        a = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        noeuds[int(a["id"])] = dict(
            cluster=int(a["cluster"]), anneau=int(a["anneau"]), branche=int(a["branche"]),
            type=a.get("type", "noeud"), stat=a.get("stat"),
            qualite=int(a.get("qualite", 0) or 0), sort=int(a.get("sort", 0) or 0))
    liaisons = [(int(m.group(1)), int(m.group(2)))
                for m in re.finditer(r'<liaison a="(\d+)" b="(\d+)"', t)]
    m = re.search(r'<depart id="(\d+)"', t)
    return dict(clusters=clusters, noeuds=noeuds, liaisons=liaisons,
                depart=int(m.group(1)) if m else None)


def positions(layout):
    P = {}
    for i, n in layout["noeuds"].items():
        cx, cy = layout["clusters"][n["cluster"]]
        P[i] = position(cx, cy, n["anneau"], n["branche"])
    return P


def couleur_noeud(n):
    if n["type"] == "slot":
        return (80, 170, 255, 235)
    if n["type"] == "sort":
        return (255, 210, 60, 245)
    if not n["stat"] or n["stat"] not in CANAL_DE:
        return (120, 120, 120, 200)
    canal, bit = CANAL_DE[n["stat"]]
    return couleur(canal, bit) + (235,)     # la fausse couleur de la palette


def bake(layout, taille=2048, fond=None):
    """L'image RGBA de la disposition, dans le cadre de la carte."""
    cadre_ = cadre(list(layout["clusters"].values()))
    k = taille / float(cadre_[2])            # pixels par unité de grille

    def px(p):
        return vers_pixel(p[0], p[1], cadre_, taille)

    img = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    P = positions(layout)
    for a, b in layout["liaisons"]:
        if a in P and b in P:
            d.line([px(P[a]), px(P[b])], fill=(255, 255, 255, 150), width=max(1, int(0.10 * k)))
    r = max(2.0, 0.30 * k)
    for i, n in layout["noeuds"].items():
        x, y = px(P[i])
        c = couleur_noeud(n)
        if n["type"] == "slot":
            d.rectangle([x - r, y - r, x + r, y + r], fill=c, outline=(255, 255, 255, 220))
        else:
            d.ellipse([x - r, y - r, x + r, y + r], fill=c, outline=(20, 20, 20, 220))
    if layout["depart"] in P:
        x, y = px(P[layout["depart"]])
        d.ellipse([x - 2 * r, y - 2 * r, x + 2 * r, y + 2 * r],
                  outline=(255, 210, 60, 255), width=max(2, int(0.08 * k)))
    if fond is not None:
        base = fond.convert("RGBA").resize((taille, taille), Image.NEAREST)
        return Image.alpha_composite(base, img)
    return img


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    nom, sortie = sys.argv[1], sys.argv[2]
    if len(sys.argv) > 3:
        import numpy as np
        fond = affiche([np.array(b) for b in Image.open(sys.argv[3]).convert("RGB").split()])
    else:
        fond = Image.new("RGB", (2048, 2048), (0, 0, 0))
    layout = lit_layout(os.path.join(LAYOUTS, nom + ".xml"))
    bake(layout, 2048, fond).convert("RGB").save(sortie)
    print("impostor écrit :", sortie, "(%d emplacements, %d liaisons)"
          % (len(layout["noeuds"]), len(layout["liaisons"])))
