# -*- coding: utf-8 -*-
r"""Cuit une fois pour toutes les ICÔNES RONDES des statistiques du sphérier.

Le masque rond des emplacements était fait AU VOL par `SetPortraitToTexture`,
une texture par bouton, la première fois qu'il paraissait : 2 442 masques sur
la grille commune, et des à-coups tant que tous n'étaient pas passés
(2026-09-05). Il n'y a pourtant que SEIZE statistiques : on cuit donc seize
icônes rondes en fichiers, que les interfaces posent par un simple SetTexture.
Le client ne charge chaque fichier qu'une fois — plus aucun masque au vol.

  * la liste stat → icône est LUE dans Spherier_Server.lua (table STATS), pour
    ne pas la dupliquer ;
  * l'icône source est prise dans l'archive la plus prioritaire qui la porte
    (patch-z d'abord — c'est la version que le client affiche), décodée par PIL ;
  * le masque est un disque anticrénelé ; le résultat va dans
    <client>\Interface\AddOns\SpherierArt\rond_<stat>.tga — À PLAT, à côté des
    arcs et des traits. Le client ne lit PAS un sous-dossier (rond\) d'un dossier
    d'AddOn sans .toc, même après redémarrage : les arcs au premier niveau se
    chargeaient, les mêmes TGA dans rond\ restaient invisibles (2026-09-05).

    python gen_icones_rondes.py
"""
import ctypes as C
import glob
import io
import os
import re
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G  # noqa: E402
from gen_visuel_aube import lit, stormlib  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")
SERVEUR = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\lua_scripts\Spherier\Spherier_Server.lua"
TAILLE = 64
BS = chr(92)


def statistiques():
    """(clé, chemin d'icône) pour chaque ligne de la table STATS du serveur."""
    t = io.open(SERVEUR, encoding="utf-8").read()
    motif = re.compile(r'key\s*=\s*"([a-z_]+)".*?icon\s*=\s*"((?:[^"\\]|\\.)*)"')
    return [(m.group(1), m.group(2).replace("\\\\", BS)) for m in motif.finditer(t)]


def archives(dll):
    """Les archives du client ouvertes en lecture, patch-z en tête."""
    noms = glob.glob(os.path.join(G.DATA, "*.MPQ")) + glob.glob(os.path.join(G.DATA, "*.mpq"))
    noms.sort(key=lambda n: (0 if "patch-z" in n.lower() else 1, n.lower()))
    ouvertes = []
    for n in noms:
        h = C.c_void_p()
        if dll.SFileOpenArchive(n, 0, 0x100, C.byref(h)):
            ouvertes.append((n, h))
    return ouvertes


def masque_rond(taille):
    """Un disque plein anticrénelé : rendu à 4× puis réduit."""
    k = 4
    m = Image.new("L", (taille * k, taille * k), 0)
    ImageDraw.Draw(m).ellipse([k, k, taille * k - k - 1, taille * k - k - 1], fill=255)
    return m.resize((taille, taille), Image.LANCZOS)


def main():
    dll = stormlib()
    dll.SFileHasFile.argtypes = [C.c_void_p, C.c_char_p]
    dll.SFileHasFile.restype = C.c_bool
    stats = statistiques()
    if not stats:
        raise SystemExit("aucune statistique lue dans " + SERVEUR)

    # JALON 7 (2026-09-06) : les icones sont des SOURCES dans spherier_art\ ;
    # gen_spherier_art_mpq.py les cuit en BLP et les injecte dans patch-z.
    dossier = os.path.join(os.path.dirname(os.path.abspath(__file__)), "spherier_art")
    os.makedirs(dossier, exist_ok=True)
    ouvertes = archives(dll)
    masque = masque_rond(TAILLE)
    planche = Image.new("RGBA", (TAILLE * 8, TAILLE * ((len(stats) + 7) // 8)), (30, 30, 30, 255))
    try:
        for k, (cle, icone) in enumerate(stats):
            chemin = icone + ".blp"
            octets = None
            for nom, h in ouvertes:
                if dll.SFileHasFile(h, chemin.encode("latin-1")):
                    octets = lit(dll, h, chemin)
                    break
            if octets is None:
                print("  ABSENTE : %-20s %s" % (cle, chemin))
                continue
            im = Image.open(io.BytesIO(octets)).convert("RGBA").resize((TAILLE, TAILLE), Image.LANCZOS)
            im.putalpha(masque)
            im.save(os.path.join(dossier, "rond_" + cle + ".tga"))
            planche.paste(im, ((k % 8) * TAILLE, (k // 8) * TAILLE), im)
            print("  %-20s <- %s" % (cle, os.path.basename(nom)))
    finally:
        for _, h in ouvertes:
            dll.SFileCloseArchive(h)
    planche.save(os.path.join(dossier, "planche_icones_rondes.png"))
    print("%d icônes rondes (sources) dans %s ; planche : planche_icones_rondes.png" % (len(stats), dossier))
    print("puis : python gen_spherier_art_mpq.py   (jeu fermé, injecte dans patch-z)")


if __name__ == "__main__":
    main()
