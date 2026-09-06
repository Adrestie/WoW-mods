# -*- coding: utf-8 -*-
r"""Rattrape dans patch-z les deux défauts d'export que le client ne pardonne pas.

LE DÉFAUT, établi le 2026-09-02 sur l'ascendant du chaman puis retrouvé le
2026-09-03 sur le missile du Cataclysme : l'export d'un client moderne laisse
`boneCountMax` (offset 44 du `.skin`) à ZÉRO. Le client 3.3.5 dimensionne sur
ce champ le tampon des matrices d'os, puis y écrit une entrée par os de la
section en cours. À zéro, il écrit hors de l'allocation — plantage sur un
modèle chargé, matériaux cassés sur un effet de sort.

`gen_visuel_aube.ecrit()` répare désormais tout skin qui entre dans l'archive,
donc le défaut ne peut plus se produire. Cet outil ne sert qu'à rattraper ceux
qui y sont DÉJÀ, sans avoir à rejouer les dix générateurs. Il est idempotent.

    python repare_skins_patchz.py            (constate, n'écrit rien)
    python repare_skins_patchz.py --repare   (écrit ; JEU FERMÉ requis)
"""
import ctypes as C
import glob
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
from gen_visuel_aube import stormlib, lit, ecrit

sys.stdout.reconfigure(encoding="utf-8")
BS = chr(92)
RACINE = os.path.dirname(os.path.abspath(__file__))


def modeles_du_chantier():
    """Les chemins d'archive des .m2 que nos dossiers d'art fournissent."""
    chemins = set()
    for dossier in sorted(glob.glob(os.path.join(RACINE, "art_*"))):
        for p in glob.glob(os.path.join(dossier, "**", "*.m2"), recursive=True):
            rel = os.path.relpath(p, dossier).replace(os.sep, BS)
            chemins.add(rel if BS in rel else "spells" + BS + rel)
    return sorted(chemins)


def rubans_discordants(m2):
    """Le nombre de rubans qui declarent plus de textures que de materiaux.

    Le client 3.3.5 parcourt les deux tableaux ENSEMBLE : un ruban qui annonce
    trois textures pour un materiau lui fait lire deux materiaux hors bornes,
    et rendre la trainee avec un fondu pris au hasard de la memoire."""
    if len(m2) < 0x130 or m2[:4] != b"MD20":
        return 0
    nr, orb = struct.unpack_from("<2I", m2, 0x120)
    mauvais = 0
    for i in range(nr):
        o = orb + i * 176
        if o + 176 > len(m2):
            break
        nti = struct.unpack_from("<I", m2, o + 0x14)[0]
        nmi = struct.unpack_from("<I", m2, o + 0x1C)[0]
        if nmi and nti > nmi:
            mauvais += 1
    return mauvais


def skins_du_chantier():
    """Les chemins d'archive des skins que nos dossiers d'art fournissent.

    Les LOD sont écartés : 3.3.5 ne les lit pas et nous ne les injectons pas."""
    chemins = set()
    for dossier in sorted(glob.glob(os.path.join(RACINE, "art_*"))):
        for p in glob.glob(os.path.join(dossier, "**", "*.skin"), recursive=True):
            rel = os.path.relpath(p, dossier).replace(os.sep, BS)
            if "_lod" in rel.lower():
                continue
            # Un skin range a plat vient du dossier des sorts ; un skin range
            # en sous-dossier porte deja son chemin (les creatures).
            chemins.add(rel if BS in rel else "spells" + BS + rel)
    return sorted(chemins)


def defaut(skin):
    """(os max, boneCountMax) si le champ est trop bas, None sinon."""
    if len(skin) < 48 or skin[:4] != b"SKIN":
        return None
    ns, ofs = struct.unpack_from("<2I", skin, 28)
    pire = 0
    for i in range(ns):
        pire = max(pire, struct.unpack_from("<10H", skin, ofs + i * 48)[6])
    bcm = struct.unpack_from("<I", skin, 44)[0]
    return None if bcm > pire else (pire, bcm)


def main(repare):
    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0 if repare else 0x00000100,
                                C.byref(h)):
        raise SystemExit("archive non ouverte%s"
                         % (" en écriture — JEU FERMÉ requis" if repare else ""))
    try:
        touches = 0
        # --- les modeles : les rubans en desaccord -------------------------
        for rel in modeles_du_chantier():
            fh = C.c_void_p()
            if not dll.SFileOpenFileEx(h, rel.encode("latin-1"), 0, C.byref(fh)):
                continue
            dll.SFileCloseFile(fh)
            m2 = lit(dll, h, rel)
            mauvais = rubans_discordants(m2)
            if not mauvais:
                continue
            print("%-56s %d ruban(s) en désaccord texture/matériau"
                  % (rel, mauvais))
            touches += 1
            if repare:
                # ecrit() accorde de lui-meme : on lui rend le modele tel quel.
                ecrit(dll, h, rel, m2)

        # --- les skins : boneCountMax laisse a zero ------------------------
        for rel in skins_du_chantier():
            fh = C.c_void_p()
            if not dll.SFileOpenFileEx(h, rel.encode("latin-1"), 0, C.byref(fh)):
                continue                      # pas encore injecté, rien à faire
            dll.SFileCloseFile(fh)
            skin = lit(dll, h, rel)
            mal = defaut(skin)
            if mal is None:
                continue
            pire, bcm = mal
            print("%-56s os max %-3d boneCountMax %d -> %d"
                  % (rel, pire, bcm, pire + 1))
            touches += 1
            if repare:
                # ecrit() repare de lui-meme : on lui rend le skin tel quel.
                ecrit(dll, h, rel, skin)
        print()
        if not touches:
            print("Rien à réparer.")
        elif repare:
            print("%d fichier(s) réparé(s)." % touches)
        else:
            print("%d fichier(s) à réparer. Relancer avec --repare, JEU"
                  " FERMÉ." % touches)
    finally:
        dll.SFileCloseArchive(h)


if __name__ == "__main__":
    main("--repare" in sys.argv)
