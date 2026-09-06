# -*- coding: utf-8 -*-
r"""Extrait un fichier du client depuis la pile d'archives MPQ.

Ouverture en LECTURE SEULE : sans danger jeu ouvert. On parcourt les archives
de la plus prioritaire a la moins prioritaire et on garde la premiere qui
contient le fichier — c'est l'ordre qu'applique le client lui-meme.
"""

import ctypes
import os
import sys
from ctypes import wintypes

DLL = r"D:\Serveur WoW\tools\StormLib_build\Release\StormLib.dll"
# Le dossier du client se CHERCHE, version comprise (2026-09-06) : ecrit en dur,
# il avait fait echouer l'injection en silence au renommage 1.1.0 -> 1.2.0.
from gen_sorts_classes import dossier_client as _dossier_client
DATA = _dossier_client()

# Du plus prioritaire au moins prioritaire (patch-z porte les customs).
ARCHIVES = [
    r"frFR\patch-frFR-z.mpq", "patch-z.MPQ",
    r"frFR\patch-frfr-3.mpq", "patch-3.mpq",
    r"frFR\patch-frfr-2.mpq", "patch-2.mpq",
    r"frFR\patch-frfr.mpq", "patch.mpq",
    "patch-c.mpq", "patch-b.mpq", "patch-a.mpq",
    "lichking.mpq", "expansion.mpq", "common-2.mpq", "common.mpq",
    r"frFR\locale-frfr.mpq", r"frFR\base-frfr.mpq",
]

STREAM_FLAG_READ_ONLY = 0x00000100

s = ctypes.WinDLL(DLL)
s.SFileOpenArchive.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                               ctypes.POINTER(ctypes.c_void_p)]
s.SFileOpenFileEx.argtypes = [ctypes.c_void_p, wintypes.LPCSTR, wintypes.DWORD,
                              ctypes.POINTER(ctypes.c_void_p)]
s.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
s.SFileGetFileSize.restype = wintypes.DWORD
# PIEGE : ces deux-la renvoient un `bool` C++, donc UN SEUL octet.
# Sans restype, un FAUX passe pour un VRAI et la taille sort a
# 0xFFFFFFFF — le fichier est alors declare introuvable a tort.
s.SFileOpenArchive.restype = ctypes.c_bool
s.SFileOpenFileEx.restype = ctypes.c_bool
s.SFileReadFile.restype = ctypes.c_bool
s.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD,
                            ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]


def extraire(interne, sortie):
    for nom in ARCHIVES:
        chemin = os.path.join(DATA, nom)
        if not os.path.exists(chemin):
            continue
        mpq = ctypes.c_void_p()
        if not s.SFileOpenArchive(chemin, 0, STREAM_FLAG_READ_ONLY, ctypes.byref(mpq)):
            continue
        fic = ctypes.c_void_p()
        if s.SFileOpenFileEx(mpq, interne.encode("ascii"), 0, ctypes.byref(fic)):
            haut = wintypes.DWORD(0)
            taille = s.SFileGetFileSize(fic, ctypes.byref(haut))
            print("  trouve dans %s : %d octets" % (nom, taille))
            if taille in (0, 0xFFFFFFFF):
                s.SFileCloseFile(fic)
                s.SFileCloseArchive(mpq)
                continue
            tampon = ctypes.create_string_buffer(taille)
            lu = wintypes.DWORD(0)
            s.SFileReadFile(fic, tampon, taille, ctypes.byref(lu), None)
            s.SFileCloseFile(fic)
            s.SFileCloseArchive(mpq)
            with open(sortie, "wb") as f:
                f.write(tampon.raw[:lu.value])
            print("%s <- %s (%d octets)" % (sortie, nom, lu.value))
            return True
        s.SFileCloseArchive(mpq)
    print("introuvable :", interne)
    return False


if __name__ == "__main__":
    interne = sys.argv[1]
    sortie = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(interne.replace("\\", "/"))
    extraire(interne, sortie)
