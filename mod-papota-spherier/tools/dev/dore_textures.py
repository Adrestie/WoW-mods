# -*- coding: utf-8 -*-
r"""Dore les textures kyrianes du Jugement dernier (bleu -> doré/sacré).

  python dore_textures.py

Lit les BLP de l'export wow.export, applique une rotation de teinte aux
pixels SATURÉS (les gris ne bougent pas) : la bande bleue-cyan est ramenée
autour de l'or (42°) en CONSERVANT un quart de sa variation — un doré vivant,
pas un aplat. Écrit des BLP2 au PROFIL EXACT des imports sains (relevé : comp
2 = DXT5, alphaDepth 8, alphaEnc 7, hasMips 1 — l'encodage BGRA 3, essayé
d'abord, n'a pas de référence native ici), chaîne de mips COMPLÈTE — la
leçon papota_vide : les mips absents faisaient les BLP faits main
défaillants. L'encodeur DXT5 est à extrémités min/max : largement suffisant
pour des textures de lueur. Les textures neutres sont copiées telles
quelles. Tout atterrit dans art_paladin\spells sous les NOMS D'ORIGINE : le
client 3.3.5 n'a aucun autre utilisateur de ces fichiers.
"""
import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import DOSSIER_EXPORT_WOW  # ce qui décrit le poste, hors du dépôt
import json
import os
import struct
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

EXPORT = DOSSIER_EXPORT_WOW
MANIFEST = os.path.join(EXPORT, "cfx_kyrian_priest_holy_statechest.manifest.json")
SORTIE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "art_paladin", "spells")

# Relevé (analyse du 2026-08-30) : cinq textures portent le bleu, les autres
# sont neutres (gris/masques) et ne bougent pas.
BLEUES = {
    "cfx_kyrian_warrior_3154187.blp",
    "cfx_kyrian_warrior_3154188.blp",
    "11fx_voidroot_aura_3154189.blp",
    "8fx_hearthstone_aether_base_3059019.blp",
    "cfx_kyrian_shaman_3155089.blp",
}
OR_TEINTE = 42.0 / 360.0        # l'or
BLEU_PIVOT = 195.0 / 360.0      # le centre de la bande bleue-cyan relevée
RESSERRE = 0.25                 # part de variation conservée autour de l'or


def dore(im):
    im = im.convert("RGBA")
    h, s, v = im.convert("HSV").split()
    px_h, px_s = h.load(), s.load()
    for y in range(im.height):
        for x in range(im.width):
            if px_s[x, y] < 24:
                continue                      # gris : on ne touche pas
            teinte = px_h[x, y] / 255.0
            ecart = teinte - BLEU_PIVOT
            if ecart > 0.5:
                ecart -= 1.0
            elif ecart < -0.5:
                ecart += 1.0
            neuf = (OR_TEINTE + ecart * RESSERRE) % 1.0
            px_h[x, y] = int(neuf * 255.0 + 0.5)
    recolore = Image.merge("HSV", (h, s, v)).convert("RGBA")
    recolore.putalpha(im.getchannel("A"))
    return recolore


def _bloc_dxt5(px, x0, y0, largeur, hauteur):
    """Un bloc 4x4 en DXT5 (16 octets) : alpha interpolé 8 niveaux à
    extrémités max/min, couleurs 4 niveaux à extrémités par luminance."""
    pixels = []
    for dy in range(4):
        for dx in range(4):
            x = min(x0 + dx, largeur - 1)
            y = min(y0 + dy, hauteur - 1)
            pixels.append(px[x, y])

    alphas = [p[3] for p in pixels]
    a0, a1 = max(alphas), min(alphas)
    if a0 == a1:
        indices_a = [0] * 16
    else:
        niveaux = [a0, a1] + [((7 - k) * a0 + k * a1) // 7 for k in range(1, 7)]
        indices_a = [min(range(8), key=lambda i, a=a: abs(niveaux[i] - a))
                     for a in alphas]
    bits_a = 0
    for k, ia in enumerate(indices_a):
        bits_a |= ia << (3 * k)
    alpha_mot = struct.pack("<2B", a0, a1) + bits_a.to_bytes(6, "little")

    def lum(p):
        return p[0] * 3 + p[1] * 6 + p[2]

    clair = max(pixels, key=lum)
    sombre = min(pixels, key=lum)

    def c565(p):
        return ((p[0] >> 3) << 11) | ((p[1] >> 2) << 5) | (p[2] >> 3)

    c0, c1 = c565(clair), c565(sombre)
    e0, e1 = clair, sombre
    if c0 < c1:
        c0, c1, e0, e1 = c1, c0, e1, e0
    if c0 == c1:
        indices_c = [0] * 16
    else:
        paliers = [e0, e1,
                   tuple((2 * e0[i] + e1[i]) // 3 for i in range(3)),
                   tuple((e0[i] + 2 * e1[i]) // 3 for i in range(3))]
        # ordre DXT : 0 = c0, 1 = c1, 2 = 2/3 c0, 3 = 1/3 c0
        paliers = [paliers[0], paliers[1], paliers[2], paliers[3]]
        def plus_proche(p):
            return min(range(4), key=lambda i: sum(
                (paliers[i][j] - p[j]) ** 2 for j in range(3)))
        indices_c = [plus_proche(p) for p in pixels]
    bits_c = 0
    for k, ic in enumerate(indices_c):
        bits_c |= ic << (2 * k)
    return alpha_mot + struct.pack("<2HI", c0, c1, bits_c)


def ecrit_blp2_dxt5(im, chemin):
    """BLP2 au profil des imports sains : comp 2 (DXT), alphaDepth 8,
    alphaEnc 7 (DXT5), hasMips 1, palette réservée vide, mips complets."""
    im = im.convert("RGBA")
    mips = [im]
    while mips[-1].width > 1 or mips[-1].height > 1:
        m = mips[-1]
        mips.append(m.resize((max(1, m.width // 2), max(1, m.height // 2)),
                             Image.LANCZOS))
    mips = mips[:16]

    entete = struct.pack("<4sI4B2I", b"BLP2", 1, 2, 8, 7, 1,
                         im.width, im.height)
    debut_donnees = len(entete) + 64 + 64 + 1024
    offsets, tailles, blocs = [], [], []
    pos = debut_donnees
    for m in mips:
        px = m.load()
        brut = bytearray()
        for y0 in range(0, m.height, 4):
            for x0 in range(0, m.width, 4):
                brut += _bloc_dxt5(px, x0, y0, m.width, m.height)
        offsets.append(pos)
        tailles.append(len(brut))
        blocs.append(bytes(brut))
        pos += len(brut)
    offsets += [0] * (16 - len(offsets))
    tailles += [0] * (16 - len(tailles))

    with open(chemin, "wb") as f:
        f.write(entete)
        f.write(struct.pack("<16I", *offsets))
        f.write(struct.pack("<16I", *tailles))
        f.write(b"\x00" * 1024)
        for b in blocs:
            f.write(b)


def main():
    os.makedirs(SORTIE, exist_ok=True)
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    for t in manifest["textures"]:
        nom = t["file"]
        source = os.path.join(EXPORT, nom)
        cible = os.path.join(SORTIE, nom)
        if nom in BLEUES:
            im = Image.open(source)
            ecrit_blp2_dxt5(dore(im), cible)
            print("doré     : %s (%dx%d, BLP2 DXT5 + mips)"
                  % (nom, im.width, im.height))
        else:
            with open(source, "rb") as s, open(cible, "wb") as c:
                c.write(s.read())
            print("copié    : %s" % nom)


if __name__ == "__main__":
    main()
