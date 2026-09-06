# -*- coding: utf-8 -*-
r"""Retire de patch-z les fichiers `papota_` que plus rien ne désigne.

Un chantier d'art laisse des restes : modèles essayés puis abandonnés,
textures reteintées sous un nom intermédiaire, copies d'une bissection. Elles
ne gênent pas le client — il ne les ouvre jamais — mais elles s'accumulent.

CE QUI EST CONSIDÉRÉ VIVANT :

  * tout modèle désigné par `SpellVisualEffectName.dbc` ou
    `CreatureModelData.dbc` (et le `.skin` qui va avec) ;
  * toute texture qu'un de ces modèles réclame, lue dans son bloc de textures ;
  * tout ce qui vit sous `Interface\` ou `Sound\` : ce sont les icônes et les
    sons, désignés par SpellIcon et SoundEntries, que ce contrôle ne lit pas.

Le reste est orphelin.

L'ESPACE N'EST PAS RENDU : un MPQ marque l'entrée libre sans se recompacter.
Il faudrait `SFileCompactArchive` sur 19 Go pour cela — long, et sans intérêt
tant que la place ne manque pas.

    python retire_orphelins.py            (liste seulement)
    python retire_orphelins.py --retire   (retire — JEU FERMÉ requis)
"""
import ctypes as C
import os
import struct
import sys
from ctypes import wintypes

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
from gen_visuel_aube import Dbc, stormlib, lit

sys.stdout.reconfigure(encoding="utf-8")
BS = chr(92)


class FIND(C.Structure):
    _fields_ = [("cFileName", C.c_char * 260), ("szPlainName", C.c_char_p),
                ("szHashName", C.c_char * 260), ("dwHashIndex", wintypes.DWORD),
                ("dwBlockIndex", wintypes.DWORD), ("dwFileSize", wintypes.DWORD),
                ("dwFileFlags", wintypes.DWORD), ("dwCompSize", wintypes.DWORD),
                ("dwFileTimeLo", wintypes.DWORD), ("dwFileTimeHi", wintypes.DWORD),
                ("lcLocale", wintypes.DWORD)]


def main():
    retire = "--retire" in sys.argv
    dll = stormlib()
    dll.SFileFindFirstFile.argtypes = [C.c_void_p, C.c_char_p,
                                       C.POINTER(FIND), C.c_char_p]
    dll.SFileFindFirstFile.restype = C.c_void_p
    dll.SFileFindNextFile.argtypes = [C.c_void_p, C.POINTER(FIND)]
    dll.SFileFindNextFile.restype = C.c_bool
    dll.SFileFindClose.argtypes = [C.c_void_p]
    dll.SFileFindClose.restype = C.c_bool
    dll.SFileRemoveFile.argtypes = [C.c_void_p, C.c_char_p, wintypes.DWORD]
    dll.SFileRemoveFile.restype = C.c_bool

    h = C.c_void_p()
    # En retrait il faut l'ÉCRITURE (drapeaux au troisième argument, priorité
    # au second — les inverser ouvre en écriture sans le vouloir).
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0 if retire else 0x100,
                                C.byref(h)):
        raise SystemExit("archive non ouverte"
                         + (" — JEU FERMÉ requis" if retire else ""))
    try:
        tous = []
        d = FIND()
        t = dll.SFileFindFirstFile(h, b"*papota_*", C.byref(d), None)
        while t:
            tous.append(d.cFileName.decode("latin-1"))
            if not dll.SFileFindNextFile(t, C.byref(d)):
                break
        dll.SFileFindClose(t)

        designes = set()
        for nom in ("SpellVisualEffectName.dbc", "CreatureModelData.dbc"):
            dbc = Dbc(lit(dll, h, "DBFilesClient" + BS + nom))
            for i in range(dbc.nrec):
                o = i * dbc.rsize
                n = struct.unpack_from("<I", dbc.enr, o + 2 * 4)[0]
                if not n:
                    continue
                chemin = (dbc.chaines[n:dbc.chaines.index(b"\0", n)]
                          .decode("latin-1"))
                # TOUT modèle désigné compte, pas seulement ceux dont le nom porte
                # « papota_ » : un modèle rétroporté sous son nom d'origine
                # (cfx_azerite_crucibleofflame…, cfx_paladin_lightofdawn…) réclame
                # des textures « papota_ ». Le filtre sur le nom du modèle a fait
                # passer 26 textures vivantes pour orphelines et les a retirées le
                # 2026-09-04 — réparé le 2026-09-06. Les modèles absents de patch-z
                # sont ignorés plus bas (lit() échoue).
                designes.add(chemin.lower().replace(".mdx", ".m2"))

        vivants = set(designes)
        for modele in list(designes):
            vivants.add(modele.replace(".m2", "00.skin"))
            try:
                b = lit(dll, h, modele)
            except SystemExit:
                continue
            nt, ot = struct.unpack_from("<2I", b, 0x50)
            for i in range(nt):
                typ, _fl, lg, ofs = struct.unpack_from("<4I", b, ot + i * 16)
                if typ == 0 and lg > 1:
                    vivants.add(b[ofs:ofs + lg - 1].decode("latin-1").lower())

        orphelins = [f for f in sorted(tous)
                     if f.lower() not in vivants
                     and not f.lower().startswith(("interface", "sound"))]

        print("%d fichier(s) « papota_ » dans l'archive" % len(tous))
        print("%d modèle(s) désigné(s), %d fichier(s) vivant(s)"
              % (len([x for x in designes if x.endswith('.m2')]), len(vivants)))
        print("%d ORPHELIN(S)" % len(orphelins))
        if not retire:
            for f in orphelins:
                print("   %s" % f)
            print("\n(liste seulement — ajouter --retire pour les enlever)")
            return

        enleves = 0
        for f in orphelins:
            if dll.SFileRemoveFile(h, f.encode("latin-1"), 0):
                enleves += 1
            else:
                print("   ÉCHEC : %s" % f)
        print("%d fichier(s) retiré(s)" % enleves)
    finally:
        dll.SFileCloseArchive(h)


if __name__ == "__main__":
    main()
