# -*- coding: utf-8 -*-
r"""La palette de la CARTE DES STATS — un MASQUE DE BITS par canal.

Le générateur de la grille commune ne décide pas où vont les statistiques : il
LIT une image que vous peignez. Chaque nœud du futur layout tombe sur un pixel
de cette carte, et le pixel dit quelles statistiques peuvent tomber là.

L'ENCODAGE — une statistique = UN BIT dans un canal. Un pixel porte donc autant
de statistiques qu'on veut : intelligence + puissance des sorts + esprit, c'est
le bleu à 1 | 2 | 4 = 7. (Une première version donnait une VALEUR par canal, et
deux stats bleues ne pouvaient pas cohabiter — corrigé le 2026-09-05.)

    canal ROUGE  (offensif physique)   canal VERT (défense, puis liant)
      bit 0   1  force                  bit 0    1  endurance
      bit 1   2  dextérité              bit 1    2  esquive
      bit 2   4  puissance d'attaque    bit 2    4  parade
      bit 3   8  expertise              bit 3    8  blocage
      bit 4  16  pénétration d'armure   bit 4   16  hâte
                                        bit 5   32  critique
    canal BLEU   (magie et soins)       bit 6   64  toucher
      bit 0   1  intelligence
      bit 1   2  puissance des sorts
      bit 2   4  esprit
      bit 3   8  bonus aux soins

Le noir (aucun bit) signifie « sans préférence » : le générateur y pose le liant
(hâte, critique, toucher). Un pixel qui porte plusieurs statistiques les offre à
parts égales ; c'est la DENSITÉ de la peinture — falloff, scatter, pointillé —
qui fait le dosage entre zones.

Les valeurs brutes sont presque noires à l'œil (un bit vaut 1, 2, 4…) : le
pinceau AFFICHE une fausse couleur — d'autant plus vive qu'il y a de bits — et
surligne la statistique sélectionnée. L'image enregistrée, elle, porte les bits.

    python palette_carte.py
      → carte_legende.png   la palette, à garder ouverte à côté
      → carte_seed.png      le fond noir vierge, 2 048², à peindre (n'écrase
                            pas un fichier déjà présent)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding="utf-8")
ICI = os.path.dirname(os.path.abspath(__file__))
TAILLE = 2048

# (statistique, canal, bit) — LA table que lisent le pinceau et le générateur.
PALETTE = [
    ("force",              "R", 1),
    ("dexterite",          "R", 2),
    ("puissance_attaque",  "R", 4),
    ("expertise",          "R", 8),
    ("penetration_armure", "R", 16),
    ("endurance",          "G", 1),
    ("esquive",            "G", 2),
    ("parade",             "G", 4),
    ("blocage",            "G", 8),
    ("hate",               "G", 16),
    ("critique",           "G", 32),
    ("touche",             "G", 64),
    ("intelligence",       "B", 1),
    ("puissance_sorts",    "B", 2),
    ("esprit",             "B", 4),
    ("bonus_soins",        "B", 8),
]
LIANT = ("hate", "critique", "touche")
CANAUX = {"R": 0, "G": 1, "B": 2}
BITS_PAR_CANAL = {"R": 5, "G": 7, "B": 4}
TEINTE = {"R": (255, 70, 70), "G": (70, 255, 70), "B": (90, 140, 255)}


# ---------------------------------------------------------------------------
# LA QUALITÉ PAR ANNEAUX CONCENTRIQUES (2026-09-05)
# ---------------------------------------------------------------------------
# Cinq anneaux centrés sur le centre de la texture. Chaque valeur est
# l'ÉPAISSEUR d'un anneau, en pour cent du rayon maximal (la moitié du côté).
# Le premier est le disque central ; les suivants s'emboîtent sans trou. Au-delà
# du dernier, tout est de sa qualité. L'anneau CENTRAL porte la qualité 1 (la
# plus faible), le plus EXTÉRIEUR la qualité 5 (la plus haute) — arbitrage du
# 2026-09-05 : une première version faisait l'inverse.
#
# Les cinq valeurs voyagent DANS le PNG (chunk texte « qualites »), jamais dans
# un fichier à côté : une carte copiée emporte ses anneaux.
QUALITES_DEFAUT = [20.0, 20.0, 20.0, 20.0, 20.0]
CLE_QUALITES = "qualites"
COULEURS_QUALITE = {1: (157, 157, 157), 2: (30, 255, 0), 3: (0, 112, 221),
                    4: (163, 53, 238), 5: (255, 128, 0)}


def lit_qualites(image):
    """Les cinq épaisseurs portées par une image PIL ouverte (avant convert),
    ou la valeur par défaut si elle n'en porte pas."""
    texte = getattr(image, "text", {}).get(CLE_QUALITES)
    if not texte:
        return list(QUALITES_DEFAUT)
    try:
        valeurs = [max(0.0, float(v)) for v in texte.split(",")]
    except ValueError:
        return list(QUALITES_DEFAUT)
    return (valeurs + list(QUALITES_DEFAUT))[:5]


def pnginfo_qualites(epaisseurs):
    from PIL import PngImagePlugin
    info = PngImagePlugin.PngInfo()
    info.add_text(CLE_QUALITES, ",".join("%.3f" % v for v in epaisseurs))
    return info


def rayons_qualite(epaisseurs, taille):
    """Les rayons EXTÉRIEURS des cinq anneaux, en pixels, du centre vers le bord."""
    r_max = taille / 2.0
    rayons, cumul = [], 0.0
    for e in epaisseurs:
        cumul += e / 100.0 * r_max
        rayons.append(cumul)
    return rayons


def qualite_au_pixel(px, py, taille, epaisseurs):
    """La qualité (1 au centre → 5 au bord) du pixel (px, py)."""
    import math
    d = math.hypot(px - taille / 2.0, py - taille / 2.0)
    for k, r in enumerate(rayons_qualite(epaisseurs, taille)):
        if d <= r:
            return k + 1
    return 5


def bits_de(stat):
    for s, canal, bit in PALETTE:
        if s == stat:
            return canal, bit
    raise KeyError(stat)


def decode(pixel):
    """Les statistiques portées par un pixel : une par bit posé, à poids égal.
    Rend une liste (stat, poids) ; vide pour du noir."""
    r, g, b = pixel[:3]
    valeur = {"R": int(r), "G": int(g), "B": int(b)}
    return [(stat, 1.0) for stat, canal, bit in PALETTE if valeur[canal] & bit]


def couleur(canal, bit):
    """La FAUSSE COULEUR d'une statistique seule, pour la légende et les boutons :
    la teinte du canal, d'autant plus claire que le bit est haut."""
    rang = bit.bit_length() - 1
    n = BITS_PAR_CANAL[canal]
    t = 0.45 + 0.55 * rang / float(max(1, n - 1))
    base = TEINTE[canal]
    return tuple(int(c * t) for c in base)


def table_affichage():
    """Pour chaque canal, la table valeur brute → intensité affichée (0..255) :
    zéro reste noir, un bit donne une teinte déjà lisible, et l'intensité monte
    avec le nombre de bits."""
    tables = {}
    for canal, n in BITS_PAR_CANAL.items():
        lut = np.zeros(256, dtype=np.uint8)
        for v in range(1, 256):
            k = bin(v & ((1 << n) - 1)).count("1")
            lut[v] = 0 if k == 0 else int(110 + 145 * min(1.0, (k - 1) / float(max(1, n - 1))))
        tables[canal] = lut
    return tables


def affiche(plans):
    """Les trois plans bruts (H, W) → une image RGB en fausse couleur."""
    luts = table_affichage()
    r, g, b = (luts[c][p] for c, p in zip(("R", "G", "B"), plans))
    rgb = np.dstack([
        np.clip(r.astype(np.int32) * TEINTE["R"][0] // 255 + g.astype(np.int32) * TEINTE["G"][0] // 255 + b.astype(np.int32) * TEINTE["B"][0] // 255, 0, 255),
        np.clip(r.astype(np.int32) * TEINTE["R"][1] // 255 + g.astype(np.int32) * TEINTE["G"][1] // 255 + b.astype(np.int32) * TEINTE["B"][1] // 255, 0, 255),
        np.clip(r.astype(np.int32) * TEINTE["R"][2] // 255 + g.astype(np.int32) * TEINTE["G"][2] // 255 + b.astype(np.int32) * TEINTE["B"][2] // 255, 0, 255),
    ]).astype(np.uint8)
    return Image.fromarray(rgb)


def main():
    h = 34
    img = Image.new("RGB", (780, h * len(PALETTE) + 60), (24, 24, 24))
    d = ImageDraw.Draw(img)
    try:
        police = ImageFont.truetype("consola.ttf", 16)
        titre = ImageFont.truetype("consola.ttf", 18)
    except OSError:
        police = titre = ImageFont.load_default()
    d.text((14, 12), "Carte des stats - une statistique = un bit de son canal (fausse couleur)",
           fill=(220, 220, 220), font=titre)
    for i, (stat, canal, bit) in enumerate(PALETTE):
        y = 50 + i * h
        d.rectangle([14, y, 94, y + h - 8], fill=couleur(canal, bit), outline=(200, 200, 200))
        d.text((110, y + 6), "%-20s canal %s  bit %d  (valeur %3d)"
               % (stat, canal, bit.bit_length() - 1, bit), fill=(230, 230, 230), font=police)
    img.save(os.path.join(ICI, "carte_legende.png"))

    seed = os.path.join(ICI, "carte_seed.png")
    if not os.path.exists(seed):
        Image.new("RGB", (TAILLE, TAILLE), (0, 0, 0)).save(seed)
        print("carte_seed.png : fond noir %dx%d créé" % (TAILLE, TAILLE))
    else:
        print("carte_seed.png : déjà présent, laissé tel quel")
    print("carte_legende.png : %d statistiques, en bits" % len(PALETTE))


if __name__ == "__main__":
    main()
