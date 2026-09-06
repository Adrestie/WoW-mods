# -*- coding: utf-8 -*-
r"""Compacte patch-z.MPQ : rend l'espace mort laissé par les réécritures (2026-09-06).

Chaque réinjection d'un fichier (Spell.dbc à chaque `--deploy`, textures, ADT…)
laisse l'ancienne copie en place dans l'archive : StormLib n'écrase jamais, il
ajoute et oublie. À force, patch-z pesait 20,55 Gio pour 3,54 Gio de contenu.
`SFileCompactArchive` réécrit l'archive en ne gardant que les données vivantes,
secteurs copiés tels quels (aucune recompression, contenu identique à l'octet).

Déroulement, dans l'ordre et sans raccourci :
  1. refus si Wow.exe tourne (l'archive doit être libre) ;
  2. sauvegarde : copie de patch-z dans data\backup\ (convention
     `.avant_<motif>_<date>`) — StormLib SUPPRIME l'original avant de poser la
     nouvelle archive, la sauvegarde est la seule bouée ;
  3. compactage ;
  4. vérification COMPLÈTE : chaque fichier de la sauvegarde est relu dans les
     deux archives et comparé octet à octet ; même nombre d'entrées exigé.

    python compacte_patch_z.py                 (sauvegarde + compactage + vérification)
    python compacte_patch_z.py --verifie-seul  (compare l'archive à la dernière sauvegarde)

La sauvegarde n'est pas supprimée par l'outil : à jeter à la main une fois le
jeu validé.
"""
import ctypes as C
import datetime
import glob
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G  # noqa: E402
from gen_visuel_aube import stormlib  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")
ARCHIVE = os.path.join(G.DATA, "patch-z.MPQ")
DOSSIER_SAUVEGARDE = os.path.join(G.DATA, "backup")
LECTURE_SEULE = 0x100  # STREAM_FLAG_READ_ONLY


class FIND(C.Structure):
    _fields_ = [("cFileName", C.c_char * 260), ("szPlainName", C.c_char_p),
                ("dwHashIndex", C.c_uint), ("dwBlockIndex", C.c_uint), ("dwFileSize", C.c_uint),
                ("dwFileFlags", C.c_uint), ("dwCompSize", C.c_uint), ("dwFileTimeLo", C.c_uint),
                ("dwFileTimeHi", C.c_uint), ("lcLocale", C.c_uint)]


def dll_complete():
    dll = stormlib()
    dll.SFileFindFirstFile.argtypes = [C.c_void_p, C.c_char_p, C.POINTER(FIND), C.c_wchar_p]
    dll.SFileFindFirstFile.restype = C.c_void_p
    dll.SFileFindNextFile.argtypes = [C.c_void_p, C.POINTER(FIND)]
    dll.SFileFindNextFile.restype = C.c_bool
    dll.SFileFindClose.argtypes = [C.c_void_p]
    dll.SFileCompactArchive.argtypes = [C.c_void_p, C.c_wchar_p, C.c_bool]
    dll.SFileCompactArchive.restype = C.c_bool
    dll.GetLastError = C.windll.kernel32.GetLastError
    return dll


def ouvre(dll, chemin, drapeaux):
    h = C.c_void_p()
    if not dll.SFileOpenArchive(chemin, 0, drapeaux, C.byref(h)):
        raise SystemExit("archive non ouverte (erreur %d) : %s" % (dll.GetLastError(), chemin))
    return h


def inventaire(dll, h):
    """{nom: (taille, taille compressée, drapeaux)} de toute l'archive."""
    fd = FIND()
    hf = dll.SFileFindFirstFile(h, b"*", C.byref(fd), None)
    if not hf:
        raise SystemExit("énumération impossible (erreur %d)" % dll.GetLastError())
    entrees = {}
    while True:
        entrees[fd.cFileName] = (fd.dwFileSize, fd.dwCompSize, fd.dwFileFlags)
        if not dll.SFileFindNextFile(hf, C.byref(fd)):
            break
    dll.SFileFindClose(hf)
    return entrees


def lit(dll, h, nom):
    fh = C.c_void_p()
    if not dll.SFileOpenFileEx(h, nom, 0, C.byref(fh)):
        return None
    taille = dll.SFileGetFileSize(fh, None)
    tampon = C.create_string_buffer(taille) if taille else C.create_string_buffer(1)
    lu = C.c_uint(0)
    ok = dll.SFileReadFile(fh, tampon, taille, C.byref(lu), None) if taille else True
    dll.SFileCloseFile(fh)
    if not ok or lu.value != taille:
        return None
    return tampon.raw[:taille]


def repare_hi_block_table():
    """PIÈGE StormLib (constaté le 2026-09-06) : quand l'archive compactée passe
    sous 4 Gio, la table haute des positions (hi-block table) n'est plus écrite,
    mais `SFileCompactArchive` laisse dans l'en-tête v2 l'ancien champ
    HiBlockTablePos64, qui pointe au-delà de la fin du fichier : StormLib ET le
    client refusent alors l'archive (erreur 1392, « fichier corrompu »). On remet
    ce champ à zéro si — et seulement si — il pointe hors du fichier."""
    taille = os.path.getsize(ARCHIVE)
    with open(ARCHIVE, "r+b") as f:
        entete = f.read(0x2C)
        signature, version = entete[:4], int.from_bytes(entete[12:14], "little")
        if signature != b"MPQ\x1a" or version != 1:
            return  # pas un en-tête v2 posé à l'offset 0 : on ne touche à rien
        hi_pos = int.from_bytes(entete[0x20:0x28], "little")
        if hi_pos and hi_pos >= taille:
            f.seek(0x20)
            f.write((0).to_bytes(8, "little"))
            print("en-tête : HiBlockTablePos64 périmé (%d, fichier de %d o) remis à 0" % (hi_pos, taille), flush=True)


def jeu_ferme():
    sortie = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    return "wow.exe" not in sortie


def derniere_sauvegarde():
    candidats = sorted(glob.glob(os.path.join(DOSSIER_SAUVEGARDE, "patch-z.MPQ.avant_compactage_*")))
    if not candidats:
        raise SystemExit("aucune sauvegarde patch-z.MPQ.avant_compactage_* dans " + DOSSIER_SAUVEGARDE)
    return candidats[-1]


def verifie(dll, sauvegarde):
    """Chaque fichier de la sauvegarde relu dans les deux archives, comparé
    octet à octet. Renvoie (nombre vérifié, liste des écarts)."""
    ha = ouvre(dll, sauvegarde, LECTURE_SEULE)
    hb = ouvre(dll, ARCHIVE, LECTURE_SEULE)
    avant, apres = inventaire(dll, ha), inventaire(dll, hb)
    ecarts = []
    internes = {b"(listfile)", b"(attributes)", b"(signature)"}
    for nom in sorted(set(avant) | set(apres)):
        if nom in internes:
            continue  # régénérés par le compactage, par construction différents
        if nom not in apres:
            ecarts.append("perdu : " + nom.decode("latin-1"))
        elif nom not in avant:
            ecarts.append("apparu : " + nom.decode("latin-1"))
    t0, n = time.time(), 0
    noms = [nom for nom in sorted(avant) if nom not in internes and nom in apres]
    for nom in noms:
        a, b = lit(dll, ha, nom), lit(dll, hb, nom)
        if a is None or b is None or a != b:
            ecarts.append("différent : " + nom.decode("latin-1"))
        n += 1
        if n % 25000 == 0:
            print("  … %d / %d fichiers comparés (%.0f s)" % (n, len(noms), time.time() - t0), flush=True)
    dll.SFileCloseArchive(ha)
    dll.SFileCloseArchive(hb)
    return n, ecarts, len(avant), len(apres)


def main():
    dll = dll_complete()
    if "--verifie-seul" in sys.argv:
        sauvegarde = derniere_sauvegarde()
    else:
        if not jeu_ferme():
            raise SystemExit("Wow.exe tourne : fermer le jeu avant de compacter")
        os.makedirs(DOSSIER_SAUVEGARDE, exist_ok=True)
        sauvegarde = os.path.join(DOSSIER_SAUVEGARDE, "patch-z.MPQ.avant_compactage_"
                                  + datetime.date.today().isoformat())
        avant = os.path.getsize(ARCHIVE)
        t0 = time.time()
        print("sauvegarde : %s (%.2f Gio)…" % (sauvegarde, avant / 2 ** 30), flush=True)
        shutil.copyfile(ARCHIVE, sauvegarde)
        if os.path.getsize(sauvegarde) != avant:
            raise SystemExit("sauvegarde incomplète, rien n'est touché")
        print("  copiée en %.0f s" % (time.time() - t0), flush=True)

        t0 = time.time()
        h = ouvre(dll, ARCHIVE, 0)
        ok = dll.SFileCompactArchive(h, None, False)
        erreur = dll.GetLastError()
        dll.SFileCloseArchive(h)
        if not ok:
            raise SystemExit("compactage refusé (erreur %d) ; la sauvegarde est intacte : %s" % (erreur, sauvegarde))
        apres = os.path.getsize(ARCHIVE)
        print("compactage : %.2f Gio -> %.2f Gio (-%.1f %%) en %.0f s"
              % (avant / 2 ** 30, apres / 2 ** 30, 100.0 * (avant - apres) / avant, time.time() - t0), flush=True)
        repare_hi_block_table()

    print("vérification octet à octet contre %s…" % os.path.basename(sauvegarde), flush=True)
    n, ecarts, na, nb = verifie(dll, sauvegarde)
    print("entrées : %d avant, %d après ; %d fichiers comparés" % (na, nb, n))
    if ecarts:
        for e in ecarts[:40]:
            print("  ÉCART " + e)
        raise SystemExit("%d écart(s) : NE PAS GARDER, restaurer la sauvegarde %s" % (len(ecarts), sauvegarde))
    print("archive compactée IDENTIQUE à la sauvegarde, fichier par fichier. Sauvegarde conservée : " + sauvegarde)


if __name__ == "__main__":
    main()
