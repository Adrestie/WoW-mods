# -*- coding: utf-8 -*-
r"""Prépare les sources du Bouclier de l'Inquisition (8600012).

  python prepare_bouclier.py <m2 converti (v264)>

- Recolore EN DORÉ et RENOMME (_dore) les trois textures désignées par
  l'utilisateur (paladin_flare_01/02, blessingofspellwarding_runeplane) —
  réutilise la rotation de teinte et l'encodeur DXT5 de dore_textures.
- Copie les dix autres textures telles quelles.
- Écrit le manifeste ÉDITÉ (noms _dore) puis inscrit les chemins dans le M2
  converti via inscrit_textures.
- Copie modèle et skin dans art_paladin\spells.
"""
import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import DOSSIER_EXPORT_WOW  # ce qui décrit le poste, hors du dépôt
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dore_textures import dore, ecrit_blp2_dxt5
from PIL import Image
import inscrit_textures

sys.stdout.reconfigure(encoding="utf-8")

EXPORT = DOSSIER_EXPORT_WOW
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "art_paladin", "spells")
MANIFEST = os.path.join(
    EXPORT, "cfx_paladin_blessingofspellwarding_impactbase.manifest.json")
BRUT = os.path.join(EXPORT, "cfx_paladin_blessingofspellwarding_impactbase.m2")
SKIN = os.path.join(EXPORT, "cfx_paladin_blessingofspellwarding_impactbase00.skin")

A_DORER = {
    "paladin_flare_01.blp",
    "paladin_flare_02.blp",
    "paladin_blessingofspellwarding_runeplane.blp",
}


def renomme(nom):
    return nom[:-4] + "_dore.blp" if nom in A_DORER else nom


def main(chemin_converti):
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    for t in manifest["textures"]:
        nom = t["file"]
        source = os.path.join(EXPORT, nom)
        cible = os.path.join(ART, renomme(nom))
        if nom in A_DORER:
            im = Image.open(source)
            ecrit_blp2_dxt5(dore(im), cible)
            print("doré + renommé : %s -> %s" % (nom, renomme(nom)))
        else:
            shutil.copy2(source, cible)
            print("copié          : %s" % nom)
        t["file"] = renomme(nom)

    manifest_edite = os.path.join(ART, "bouclier.manifest_edite.json")
    json.dump(manifest, open(manifest_edite, "w", encoding="utf-8"), indent=1)

    inscrit_textures.main(BRUT, chemin_converti, manifest_edite)
    shutil.copy2(chemin_converti, os.path.join(
        ART, "cfx_paladin_blessingofspellwarding_impactbase.m2"))
    shutil.copy2(SKIN, os.path.join(
        ART, "cfx_paladin_blessingofspellwarding_impactbase00.skin"))
    os.remove(manifest_edite)
    print("modèle et skin poses dans art_paladin")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
