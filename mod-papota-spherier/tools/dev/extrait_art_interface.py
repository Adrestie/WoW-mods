# -*- coding: utf-8 -*-
r"""Sort l'art d'interface des archives customs du client, sous ses vrais noms.

Sert à choisir un habillage sur pièces plutôt que de mémoire. Écrit un PNG par
planche dans `apercu_interface\`, puis une planche-contact qui les montre toutes
avec leur nom.

Les icônes sont écartées : elles se comptent par milliers et ne servent pas ici.

Deux pièges vérifiés :
  - `SFILE_FIND_DATA.cFileName` fait **260** octets (MAX_PATH), pas 1024 —
    sinon taille et locale ressortent à zéro ;
  - Pillow refuse l'encodage 3 des planches de ces mods (BGRA brut) : on décode
    alors à la main, en-tête BLP2, largeur/hauteur à 12, offsets à 20, tailles
    à 84.

    python extrait_art_interface.py
"""
import ctypes as C
import io
import os
import struct
import sys
from ctypes import wintypes

from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")

DLL = r"D:\Serveur WoW\tools\StormLib_build\Release\StormLib.dll"
# Le dossier du client se CHERCHE, version comprise (2026-09-06) : ecrit en dur,
# il avait fait echouer l'injection en silence au renommage 1.1.0 -> 1.2.0.
from gen_sorts_classes import dossier_client as _dossier_client
DATA = _dossier_client()
ARCHIVES = ["patch-z.MPQ", r"frFR\patch-frFR-z.mpq"]
SORTIE = r"D:\Serveur WoW\outils_spherier\apercu_interface"
CONTACT = os.path.join(SORTIE, "_planche_contact.png")

# Ce qui ne sert à rien pour un habillage de fenêtre : les icônes, les écrans de
# chargement, les modèles 3D de l'écran de connexion, le reste de l'interface de
# base que les archives recopient.
ECARTES = ("interface\\icons\\", "\\loadingscreens\\", "\\glues\\models\\",
           "\\cursor\\", "\\worldmap\\", "\\taxiframe\\", "\\calendar\\")
TAILLE_MIN = 3000          # en octets : sous cela, c'est un détail, pas un fond

VIGNETTE = 200
COLONNES = 12


class FindData(C.Structure):
    _fields_ = [("cFileName", C.c_char * 260), ("szPlainName", C.c_char_p),
                ("lpNameAlloc", C.c_char_p), ("dwHashIndex", C.c_uint),
                ("dwBlockIndex", C.c_uint), ("dwFileSize", C.c_uint),
                ("dwFileFlags", C.c_uint), ("dwCompSize", C.c_uint),
                ("dwFileTimeLo", C.c_uint), ("dwFileTimeHi", C.c_uint),
                ("lcLocale", C.c_uint)]


def stormlib():
    s = C.WinDLL(DLL)
    s.SFileOpenArchive.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                   C.POINTER(C.c_void_p)]
    s.SFileOpenArchive.restype = C.c_bool
    s.SFileOpenFileEx.argtypes = [C.c_void_p, C.c_char_p, wintypes.DWORD,
                                  C.POINTER(C.c_void_p)]
    s.SFileOpenFileEx.restype = C.c_bool
    s.SFileGetFileSize.argtypes = [C.c_void_p, C.POINTER(wintypes.DWORD)]
    s.SFileGetFileSize.restype = wintypes.DWORD
    s.SFileReadFile.argtypes = [C.c_void_p, C.c_void_p, wintypes.DWORD,
                                C.POINTER(wintypes.DWORD), C.c_void_p]
    s.SFileReadFile.restype = C.c_bool
    s.SFileFindFirstFile.argtypes = [C.c_void_p, C.c_char_p, C.POINTER(FindData),
                                     C.c_char_p]
    s.SFileFindFirstFile.restype = C.c_void_p
    s.SFileFindNextFile.argtypes = [C.c_void_p, C.POINTER(FindData)]
    s.SFileFindNextFile.restype = C.c_bool
    return s


def blp_en_image(brut):
    if brut[:4] != b"BLP2":
        raise ValueError("pas un BLP2")
    encodage = brut[8]
    largeur, hauteur = struct.unpack_from("<II", brut, 12)
    offsets = struct.unpack_from("<16I", brut, 20)
    tailles = struct.unpack_from("<16I", brut, 84)
    if encodage == 3:
        donnees = brut[offsets[0]:offsets[0] + tailles[0]]
        return Image.frombytes("RGBA", (largeur, hauteur), donnees, "raw", "BGRA")
    return Image.open(io.BytesIO(brut)).convert("RGBA")


def rogner(img):
    """Ne garder que ce qui est peint : ces planches sont le plus souvent un
    dessin dans un coin d'un carré de 1024 ou 2048, le reste transparent."""
    boite = img.getbbox()
    return img.crop(boite) if boite else img


def damier(taille, pas=12):
    """Un fond en damier : sans lui, on ne distingue pas le transparent du
    blanc, et la moitié de ces planches sont des cadres évidés."""
    fond = Image.new("RGBA", taille, (60, 60, 60, 255))
    d = ImageDraw.Draw(fond)
    for y in range(0, taille[1], pas):
        for x in range(0, taille[0], pas):
            if (x // pas + y // pas) % 2 == 0:
                d.rectangle([x, y, x + pas - 1, y + pas - 1], fill=(80, 80, 80, 255))
    return fond


s = stormlib()
os.makedirs(SORTIE, exist_ok=True)
retenus = []

for rel in ARCHIVES:
    chemin = os.path.join(DATA, rel)
    if not os.path.exists(chemin):
        continue
    h = C.c_void_p()
    if not s.SFileOpenArchive(chemin, 0, 0x00000100, C.byref(h)):
        print("archive illisible :", rel)
        continue

    fd = FindData()
    poignee = s.SFileFindFirstFile(h, b"Interface\\*.blp", C.byref(fd), None)
    noms = []
    if poignee:
        while True:
            noms.append((fd.cFileName.decode("latin-1", "replace"), fd.dwFileSize))
            if not s.SFileFindNextFile(poignee, C.byref(fd)):
                break

    for nom, taille in noms:
        bas = nom.lower()
        if taille < TAILLE_MIN or any(e in bas for e in ECARTES):
            continue
        fh = C.c_void_p()
        if not s.SFileOpenFileEx(h, nom.encode("latin-1"), 0, C.byref(fh)):
            continue
        haut = wintypes.DWORD(0)
        t = s.SFileGetFileSize(fh, C.byref(haut))
        buf = C.create_string_buffer(t)
        lu = wintypes.DWORD(0)
        s.SFileReadFile(fh, buf, t, C.byref(lu), None)
        try:
            img = rogner(blp_en_image(buf.raw[:lu.value]))
        except Exception as e:
            print("  illisible : %s (%s)" % (nom, e))
            continue
        plat = nom.replace("\\", "_").rsplit(".", 1)[0] + ".png"
        img.save(os.path.join(SORTIE, plat))
        retenus.append((nom, img))

    s.SFileCloseArchive(h)

retenus.sort(key=lambda x: x[0].lower())
print("%d planche(s) écrite(s) dans %s" % (len(retenus), SORTIE))

# --- planche-contact --------------------------------------------------------
lignes = (len(retenus) + COLONNES - 1) // COLONNES
case_h = VIGNETTE + 26
feuille = Image.new("RGBA", (COLONNES * VIGNETTE, lignes * case_h), (24, 24, 24, 255))
dessin = ImageDraw.Draw(feuille)

for i, (nom, img) in enumerate(retenus):
    col, lig = i % COLONNES, i // COLONNES
    x0, y0 = col * VIGNETTE, lig * case_h
    vignette = img.copy()
    vignette.thumbnail((VIGNETTE - 8, VIGNETTE - 8))
    fond = damier(vignette.size)
    fond.alpha_composite(vignette)
    feuille.paste(fond, (x0 + (VIGNETTE - fond.width) // 2,
                         y0 + (VIGNETTE - 8 - fond.height) // 2 + 4))
    court = nom.split("\\")[-1]
    if len(court) > 34:
        court = court[:33] + "…"
    dessin.text((x0 + 4, y0 + VIGNETTE + 2), court, fill=(230, 230, 230, 255))
    dossier = "\\".join(nom.split("\\")[:-1])
    if len(dossier) > 34:
        dossier = "…" + dossier[-33:]
    dessin.text((x0 + 4, y0 + VIGNETTE + 13), dossier, fill=(140, 140, 140, 255))

feuille.convert("RGB").save(CONTACT)
print("planche-contact :", CONTACT)
