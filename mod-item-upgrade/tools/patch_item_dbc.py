# -*- coding: utf-8 -*-
"""
Papota - mod-item-upgrade : inscription des jetons de puissance dans Item.dbc

POURQUOI. Le client 3.3.5 résout l'apparence d'un objet par SON PROPRE
Item.dbc : un objet qui n'y figure pas s'affiche avec le point d'interrogation
rouge, même si le serveur l'envoie correctement. Côté serveur, AzerothCore
ignore purement et simplement toute entrée d'item_template absente du Item.dbc
(la table de surcharge SQL `item_dbc`, posée par 03_sql/01_world_objets_pnj.sql,
suffit au cœur ; ce script aligne aussi le fichier binaire, par convention).

CE QUE FAIT LE SCRIPT. Il retire des Item.dbc visés les cinq entrées 801050 à
801054 si elles y sont, puis les ajoute à la fin (rejouable sans doublon) :
  --serveur  CHEMIN\\Item.dbc         : fichier du serveur (Data\\dbc\\Item.dbc)
  --client   CHEMIN\\patch-X.MPQ      : archive du client, écrite via StormLib
  --source   CHEMIN\\Item.dbc         : Item.dbc de départ si l'archive n'en
                                       contient pas (extrait d'une archive
                                       officielle, p. ex. avec MPQEditor)
  --dll      CHEMIN\\StormLib.dll     : par défaut, StormLib.dll à côté du script
Une sauvegarde `.avant_item_upgrade` est faite avant chaque écriture.

CONTRAINTES. Le jeu (et tout éditeur MPQ) doit être FERMÉ : une archive ouverte
est verrouillée. L'archive doit être chargée APRÈS celle qui porte l'Item.dbc
officiel (lettre supérieure : patch-z l'emporte sur patch-3). Python 3, Windows
(StormLib.dll 64 bits fournie, licence MIT dans StormLib_LICENSE.txt).

Format Item.dbc : 8 champs de 4 octets, aucune chaîne. Les identifiants
d'affichage sont ceux d'objets existants, déjà présents dans ItemDisplayInfo.dbc.
"""
import argparse
import os
import shutil
import struct
import sys

# ID, ClassID, SubclassID, Sound_Override_Subclassid, Material, DisplayInfoID,
# InventoryType, SheatheType — valeurs exactes du Item.dbc serveur Papota.
ENTREES = [
    (801050, 15, 4, -1, 1, 24572, 0, 0),   # Éclat de Puissance
    (801051, 15, 4, -1, 1, 25054, 0, 0),   # Fragment de Puissance
    (801052, 15, 4, -1, 1, 45849, 0, 0),   # Noyau de Puissance
    (801053, 15, 4, -1, 1, 40051, 0, 0),   # Gemme de Puissance
    (801054, 15, 4, -1, 1, 43759, 0, 0),   # Couronne de Puissance
]
NOM_DBC = "DBFilesClient\\Item.dbc"
SUFFIXE_SAUVEGARDE = ".avant_item_upgrade"


def refaire_item_dbc(brut):
    """Retire nos entrées si elles y sont, puis les (ré)ajoute à la fin."""
    if brut[:4] != b"WDBC":
        raise ValueError("format inattendu : ce n'est pas un DBC")
    nrec, nfield, rsize, ssize = struct.unpack_from("<4I", brut, 4)
    debut_str = 20 + nrec * rsize
    recs = brut[20:debut_str]
    chaines = brut[debut_str:debut_str + ssize]

    ids = set(e[0] for e in ENTREES)
    garde, retires = bytearray(), 0
    for i in range(nrec):
        off = i * rsize
        if struct.unpack_from("<I", recs, off)[0] in ids:
            retires += 1
            continue
        garde.extend(recs[off:off + rsize])
    nrec -= retires

    for champs in ENTREES:
        rec = bytearray(rsize)
        for k, v in enumerate(champs[:nfield]):
            struct.pack_into("<i", rec, k * 4, v)
        garde.extend(rec)
        nrec += 1

    entete = bytearray(brut[:20])
    struct.pack_into("<4I", entete, 4, nrec, nfield, rsize, ssize)
    return bytes(entete) + bytes(garde) + chaines, nrec, retires


def sauvegarder(chemin):
    s = chemin + SUFFIXE_SAUVEGARDE
    if not os.path.exists(s):
        shutil.copyfile(chemin, s)
        print("  sauvegarde :", s)


def patcher_serveur(chemin):
    with open(chemin, "rb") as f:
        brut = f.read()
    neuf, n, r = refaire_item_dbc(brut)
    sauvegarder(chemin)
    with open(chemin, "wb") as f:
        f.write(neuf)
    print("Item.dbc du serveur : %d objets (%d remplacés, %d ajoutés) -> %s"
          % (n, r, len(ENTREES), chemin))


def charger_stormlib(dll):
    import ctypes as C
    st = C.WinDLL(dll)
    st.SFileOpenArchive.argtypes = [C.c_wchar_p, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    st.SFileOpenArchive.restype = C.c_bool
    st.SFileCreateArchive.argtypes = [C.c_wchar_p, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    st.SFileCreateArchive.restype = C.c_bool
    st.SFileCloseArchive.argtypes = [C.c_void_p]
    st.SFileHasFile.argtypes = [C.c_void_p, C.c_char_p]
    st.SFileHasFile.restype = C.c_bool
    st.SFileOpenFileEx.argtypes = [C.c_void_p, C.c_char_p, C.c_uint, C.POINTER(C.c_void_p)]
    st.SFileOpenFileEx.restype = C.c_bool
    st.SFileGetFileSize.argtypes = [C.c_void_p, C.POINTER(C.c_uint)]
    st.SFileGetFileSize.restype = C.c_uint
    st.SFileReadFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint, C.POINTER(C.c_uint), C.c_void_p]
    st.SFileReadFile.restype = C.c_bool
    st.SFileCloseFile.argtypes = [C.c_void_p]
    st.SFileCreateFile.argtypes = [C.c_void_p, C.c_char_p, C.c_ulonglong, C.c_uint,
                                   C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    st.SFileCreateFile.restype = C.c_bool
    st.SFileWriteFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint, C.c_uint]
    st.SFileWriteFile.restype = C.c_bool
    st.SFileFinishFile.argtypes = [C.c_void_p]
    st.SFileFinishFile.restype = C.c_bool
    return st, C


def lire_dans_archive(st, C, archive):
    """Retourne le contenu de l'Item.dbc de l'archive, ou None s'il n'y est pas."""
    if not os.path.exists(archive):
        return None
    h = C.c_void_p()
    if not st.SFileOpenArchive(archive, 0, 0x100, C.byref(h)):       # STREAM_FLAG_READ_ONLY
        raise SystemExit("lecture impossible : " + archive)
    try:
        nom = NOM_DBC.encode("latin-1")
        if not st.SFileHasFile(h, nom):
            return None
        fh = C.c_void_p()
        if not st.SFileOpenFileEx(h, nom, 0, C.byref(fh)):
            return None
        hi = C.c_uint(0)
        taille = st.SFileGetFileSize(fh, C.byref(hi))
        buf = C.create_string_buffer(taille)
        lu = C.c_uint(0)
        st.SFileReadFile(fh, buf, taille, C.byref(lu), None)
        st.SFileCloseFile(fh)
        return buf.raw[:lu.value]
    finally:
        st.SFileCloseArchive(h)


def ecrire_dans_archive(st, C, archive, contenu):
    h = C.c_void_p()
    if os.path.exists(archive):
        sauvegarder(archive)
        if not st.SFileOpenArchive(archive, 0, 0, C.byref(h)):
            raise SystemExit("écriture impossible — le jeu ou un éditeur MPQ est-il ouvert ?")
    else:
        # MPQ_CREATE_LISTFILE | MPQ_CREATE_ATTRIBUTES, format v1, 1024 fichiers.
        if not st.SFileCreateArchive(archive, 0x00100000 | 0x00200000, 1024, C.byref(h)):
            raise SystemExit("création impossible : " + archive)
        print("  archive créée :", archive)
    try:
        fh = C.c_void_p()
        # MPQ_FILE_COMPRESS | MPQ_FILE_REPLACEEXISTING, puis MPQ_COMPRESSION_ZLIB.
        if not st.SFileCreateFile(h, NOM_DBC.encode("latin-1"), 0, len(contenu), 0,
                                  0x00000200 | 0x80000000, C.byref(fh)):
            raise SystemExit("SFileCreateFile a échoué")
        b = C.create_string_buffer(contenu, len(contenu))
        if not st.SFileWriteFile(fh, b, len(contenu), 0x02):
            raise SystemExit("SFileWriteFile a échoué")
        st.SFileFinishFile(fh)
    finally:
        st.SFileCloseArchive(h)


def patcher_client(archive, source, dll):
    st, C = charger_stormlib(dll)
    brut = lire_dans_archive(st, C, archive)
    if brut is None:
        if not source:
            raise SystemExit("l'archive ne contient pas Item.dbc : fournir --source CHEMIN\\Item.dbc "
                             "(extrait d'une archive officielle du client)")
        with open(source, "rb") as f:
            brut = f.read()
        print("  Item.dbc de départ :", source)
    neuf, n, r = refaire_item_dbc(brut)
    ecrire_dans_archive(st, C, archive, neuf)
    print("Item.dbc du client : %d objets (%d remplacés, %d ajoutés) -> %s"
          % (n, r, len(ENTREES), archive))


def main():
    p = argparse.ArgumentParser(description="Inscrit les jetons de puissance dans Item.dbc (serveur et/ou client).")
    p.add_argument("--serveur", help="Item.dbc du serveur (Data\\dbc\\Item.dbc)")
    p.add_argument("--client", help="archive MPQ du client à patcher (créée si absente)")
    p.add_argument("--source", help="Item.dbc de départ si l'archive n'en contient pas")
    p.add_argument("--dll", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "StormLib.dll"),
                   help="StormLib.dll (défaut : à côté du script)")
    a = p.parse_args()
    if not a.serveur and not a.client:
        p.error("indiquer --serveur et/ou --client")
    if a.serveur:
        patcher_serveur(a.serveur)
    if a.client:
        if not os.path.exists(a.dll):
            raise SystemExit("StormLib.dll introuvable : " + a.dll)
        patcher_client(a.client, a.source, a.dll)
    return 0


if __name__ == "__main__":
    sys.exit(main())
