# -*- coding: utf-8 -*-
r"""Passe les textures de l'effet d'Odyn (arcane_spikecone_impactworld,
violet arcane) dans des nuances de ROUGE SANG.

  python rougit_textures.py

Même machinerie que dore_textures (le précédent doré du Jugement dernier) :
rotation de teinte des pixels SATURÉS seulement (les gris et masques ne
bougent pas), bande violette ramenée autour du rouge sang en conservant un
quart de sa variation — des nuances vivantes, pas un aplat. Écrit des BLP2
DXT5 au profil des imports sains, mips complets, sous les noms d'origine,
dans art_guerrier\spells.
"""
import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import DOSSIER_EXPORT_WOW  # ce qui décrit le poste, hors du dépôt
import json
import os
import sys

from PIL import Image

from dore_textures import ecrit_blp2_dxt5

sys.stdout.reconfigure(encoding="utf-8")

EXPORT = DOSSIER_EXPORT_WOW
MANIFEST = os.path.join(EXPORT, "arcane_spikecone_impactworld.manifest.json")
SORTIE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "art_guerrier", "spells")

# Relevé : cinq textures portent le violet/arcane, le masque de fumée est
# neutre et ne bouge pas.
COLOREES = {
    "arcane_wisps_purple3.blp",
    "cloud_poison_thin_purple.blp",
    "dragonblight_cliffshard_arcane.blp",
    "weaponimpact_streak_coolhues.blp",
    "weaponimpact_streak_purple_arcane.blp",
}
ROUGE_TEINTE = 355.0 / 360.0    # le rouge sang (juste sous le rouge pur)
VIOLET_PIVOT = 272.0 / 360.0    # le centre de la bande violette-arcane
RESSERRE = 0.25                 # part de variation conservée autour du rouge


def rougit(im):
    im = im.convert("RGBA")
    h, s, v = im.convert("HSV").split()
    px_h, px_s = h.load(), s.load()
    for y in range(im.height):
        for x in range(im.width):
            if px_s[x, y] < 24:
                continue                      # gris : on ne touche pas
            teinte = px_h[x, y] / 255.0
            ecart = teinte - VIOLET_PIVOT
            if ecart > 0.5:
                ecart -= 1.0
            elif ecart < -0.5:
                ecart += 1.0
            neuf = (ROUGE_TEINTE + ecart * RESSERRE) % 1.0
            px_h[x, y] = int(neuf * 255.0 + 0.5)
    recolore = Image.merge("HSV", (h, s, v)).convert("RGBA")
    recolore.putalpha(im.getchannel("A"))
    return recolore


def main():
    os.makedirs(SORTIE, exist_ok=True)
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    for t in manifest["textures"]:
        nom = t["file"]
        source = os.path.join(EXPORT, nom)
        cible = os.path.join(SORTIE, nom)
        if nom in COLOREES:
            im = Image.open(source)
            ecrit_blp2_dxt5(rougit(im), cible)
            print("rougi  : %s (%dx%d, BLP2 DXT5 + mips)"
                  % (nom, im.width, im.height))
        else:
            with open(source, "rb") as s, open(cible, "wb") as c:
                c.write(s.read())
            print("copié  : %s" % nom)


if __name__ == "__main__":
    main()
