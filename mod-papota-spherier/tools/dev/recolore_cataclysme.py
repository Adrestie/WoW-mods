# -*- coding: utf-8 -*-
r"""Recolore les textures du missile du Cataclysme et en baisse l'éclat.

  python recolore_cataclysme.py

DEMANDE DU 2026-09-03 : « jaune -> rouge, bleu -> vert, en gardant les mêmes
niveaux dans les canaux (ne touche qu'à la Hue) », et « le sort est toujours
trop lumineux ».

Même machinerie que dore_textures (bleu -> doré) et rougit_textures (violet ->
rouge sang) : rotation de teinte des pixels SATURÉS seulement — les gris, les
masques et les fumées neutres ne bougent pas —, saturation et valeur laissées
intactes par l'opération de teinte, et variation RESSERRÉE autour de la cible
pour garder des nuances vivantes plutôt qu'un aplat.

DEUX BANDES, et non une : le relevé des teintes dominantes montre que le
« jaune » et le « bleu » ne demandent pas la même rotation.

    bande chaude   centrée sur  30°  ->  rouge  (0°)     soit -30°
    bande froide   centrée sur 200°  ->  vert  (120°)    soit -80°

Une rotation unique ne pouvait donc pas satisfaire les deux. Chaque pixel est
rattaché à la bande dont il est le plus proche, puis ramené autour de sa cible.

L'ÉCLAT est une opération SÉPARÉE, appliquée après la teinte : la valeur est
multipliée par ECLAT. Les particules du missile sont en fondu ADDITIF (blend 4,
relevé conforme aux natifs), donc chaque couche s'ajoute aux précédentes et
dix-neuf émetteurs se cumulent vite. Baisser la valeur des textures est le
levier le plus direct — et le plus facile à doser.
"""
import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import DOSSIER_EXPORT_WOW  # ce qui décrit le poste, hors du dépôt
import colorsys
import io
import json
import os
import shutil
import sys

from PIL import Image

from dore_textures import ecrit_blp2_dxt5

sys.stdout.reconfigure(encoding="utf-8")

EXPORT = DOSSIER_EXPORT_WOW
MODELE = "cfx_azerite_crucibleofflame_major_rank4_missile"
MANIFEST = os.path.join(EXPORT, MODELE + ".manifest.json")
SORTIE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "art_demoniste", "spells")

# Les deux bandes, relevées sur les textures elles-mêmes (part des pixels
# saturés par tranche de 15°) : le chaud tient entre 15° et 60°, le froid
# entre 180° et 210°.
BANDES = (
    (30.0 / 360.0, 0.0 / 360.0, "chaude -> rouge"),
    (200.0 / 360.0, 120.0 / 360.0, "froide -> verte"),
)
RESSERRE = 0.25          # part de variation conservée autour de la cible
SATURATION_MIN = 24      # en deçà, c'est un gris : on ne touche pas
ECLAT = 0.65             # facteur appliqué à la VALEUR, pour l'éclat
PREFIXE = "papota_"      # nos noms, que nulle autre archive ne masque


def ecart_cyclique(a, b):
    """L'écart signé de `a` à `b` sur le cercle des teintes, dans [-0,5 ; 0,5]."""
    e = a - b
    if e > 0.5:
        e -= 1.0
    elif e < -0.5:
        e += 1.0
    return e


def recolore(im):
    """Teinte remappée par bande, puis valeur atténuée. Alpha intact."""
    im = im.convert("RGBA")
    h, s, v = im.convert("HSV").split()
    px_h, px_s, px_v = h.load(), s.load(), v.load()
    touches = 0
    for y in range(im.height):
        for x in range(im.width):
            px_v[x, y] = int(px_v[x, y] * ECLAT + 0.5)
            if px_s[x, y] < SATURATION_MIN:
                continue                      # gris, masque, fumée : intacts
            teinte = px_h[x, y] / 255.0
            pivot, cible, _nom = min(
                BANDES, key=lambda b: abs(ecart_cyclique(teinte, b[0])))
            ecart = ecart_cyclique(teinte, pivot)
            px_h[x, y] = int(((cible + ecart * RESSERRE) % 1.0) * 255.0 + 0.5)
            touches += 1
    neuf = Image.merge("HSV", (h, s, v)).convert("RGBA")
    neuf.putalpha(im.getchannel("A"))
    return neuf, touches


def main():
    man = json.load(io.open(MANIFEST, encoding="utf-8"))
    noms = sorted({t["file"] for t in man["textures"]})
    os.makedirs(SORTIE, exist_ok=True)
    for nom in noms:
        source = os.path.join(EXPORT, nom)
        # PREFIXE : `patch-c.mpq` porte deja ces textures sous leurs noms
        # d'origine et le client lit les siennes. Un nom a nous met fin
        # a la question (voir prefixe_textures, gen_visuel_demoniste).
        cible = os.path.join(SORTIE, PREFIXE + nom)
        try:
            im = Image.open(source)
        except Exception as e:
            print("%-62s illisible (%s), copiée telle quelle" % (nom, e))
            shutil.copy2(source, cible)
            continue
        neuf, touches = recolore(im)
        ecrit_blp2_dxt5(neuf, cible)
        print("%-62s %s, valeur x%.2f"
              % (nom,
                 "%d pixel(s) reteinté(s)" % touches if touches
                 else "neutre, teinte inchangée",
                 ECLAT))
    print("\n%d texture(s) écrite(s) dans %s" % (len(noms), SORTIE))
    print("Déployer par : python gen_visuel_demoniste.py   (JEU FERMÉ)")


if __name__ == "__main__":
    main()
