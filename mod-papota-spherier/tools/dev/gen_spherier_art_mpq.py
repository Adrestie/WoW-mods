# -*- coding: utf-8 -*-
r"""JALON 7 — les textures du sphérier EMPAQUETÉES dans patch-z (2026-09-06).

Jusqu'ici les 21 textures (traits, arcs, étincelle, 16 icônes rondes) étaient
lues sur le disque du client, dans Interface\AddOns\SpherierArt : un joueur
sans ce dossier n'avait ni liaisons ni icônes. Elles vivent désormais dans
patch-z, sous Interface\Papota\SpherierArt\ — un chemin propre au MPQ, qu'aucun
fichier posé sur un disque ne peut masquer —, en BLP2 DXT5 avec mipmaps :
le format natif du client, quatre fois plus compact qu'un TGA 32 bits et moins
lourd en mémoire vidéo (encodeur dore_textures.ecrit_blp2_dxt5, au profil des
imports sains).

Sources : outils_spherier\spherier_art\*.tga, écrites par gen_textures_spherier.py
(traits, arcs, étincelle) et gen_icones_rondes.py (icônes). Les clients Lua
posent `RC.ART_DIR .. "nom"` SANS extension : le client résout le .blp.

    python gen_spherier_art_mpq.py        (JEU FERMÉ requis : écrit dans patch-z)
"""
import ctypes as C
import glob
import io
import os
import shutil
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G  # noqa: E402
from dore_textures import ecrit_blp2_dxt5  # noqa: E402
from gen_visuel_aube import ecrit, stormlib  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")
BS = chr(92)
SOURCES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "spherier_art")
CHEMIN_MPQ = "Interface" + BS + "Papota" + BS + "SpherierArt" + BS
ARCHIVE = os.path.join(G.DATA, "patch-z.MPQ")


def main():
    sources = sorted(glob.glob(os.path.join(SOURCES, "*.tga")))
    if not sources:
        raise SystemExit("aucune source dans " + SOURCES)
    TRAVAIL = tempfile.mkdtemp(prefix="spherier_art_")

    fichiers, total_tga, total_blp = {}, 0, 0
    for tga in sources:
        nom = os.path.splitext(os.path.basename(tga))[0]
        im = Image.open(tga).convert("RGBA")
        if im.width % 4 or im.height % 4:
            raise SystemExit("%s : %dx%d, DXT exige des côtés multiples de 4" % (nom, im.width, im.height))
        blp = os.path.join(TRAVAIL, nom + ".blp")
        ecrit_blp2_dxt5(im, blp)
        donnees = open(blp, "rb").read()
        fichiers[CHEMIN_MPQ + nom + ".blp"] = donnees
        total_tga += os.path.getsize(tga)
        total_blp += len(donnees)
        print("  %-24s %4dx%-4d  %7d o -> %6d o" % (nom, im.width, im.height, os.path.getsize(tga), len(donnees)))

    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis : " + ARCHIVE)
    try:
        for chemin, donnees in sorted(fichiers.items()):
            ecrit(dll, h, chemin, donnees)
    finally:
        dll.SFileCloseArchive(h)
    shutil.rmtree(TRAVAIL, ignore_errors=True)
    print("%d texture(s) : %d o en TGA -> %d o en BLP2 DXT5, injectées dans %s sous %s"
          % (len(fichiers), total_tga, total_blp, os.path.basename(ARCHIVE), CHEMIN_MPQ))


if __name__ == "__main__":
    main()
