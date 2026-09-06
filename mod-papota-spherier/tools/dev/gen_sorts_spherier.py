# -*- coding: utf-8 -*-
r"""Sorts d'utilisation des sphères (jalon 3).

Une sphère se consomme comme n'importe quel consommable du jeu : clic droit,
le cœur lance le sort de l'objet, l'objet est détruit par sa charge. Aucun
détournement — le sort custom porte lui-même le nombre de points, et un script
de sort lit cette valeur pour créditer le joueur.

  sort     effet muet (DUMMY) sur le lanceur, `EffectBasePoints_1 = N - 1` et
           `EffectDieSides_1 = 1` : le client affiche donc N via $s1, et le
           serveur lit N par GetEffectValue(). Une seule valeur, deux lectures.
  script   `spell_script_names` -> spell_spherier_sphere (module C++)
  objet    `spellid_1` = le sort, `spelltrigger_1` = 0, `spellcharges_1` = -1
           (consommé à l'usage, comme une potion)

Modèle cloné : 59061 « Charge Shield » — instantané, ciblant le lanceur, effet
muet, sans exigence d'équipement, et dont la description affiche déjà $s1.

Deux dépôts : la table `spell_dbc` pour le serveur (AzerothCore charge Spell.dbc
AVEC cette surcharge SQL) et le Spell.dbc de patch-frFR-z.mpq pour le client,
d'où vient l'infobulle. L'injection dans l'archive exige le JEU FERMÉ.

Usage :
    python gen_sorts_spherier.py            (Spell.dbc de travail + SQL)
    python gen_sorts_spherier.py --deploy   (injecte aussi dans le MPQ client)
"""

import ctypes as C
import io
import os
import struct
import sys

DLL = r"D:\Serveur WoW\tools\StormLib_build\Release\StormLib.dll"
# Le dossier du client se CHERCHE, version comprise (2026-09-06) : ecrit en dur,
# il avait fait echouer l'injection en silence au renommage 1.1.0 -> 1.2.0.
from gen_sorts_classes import dossier_client as _dossier_client
DATA = _dossier_client()
NOM_DBC = r"DBFilesClient\Spell.dbc"

# LE Spell.dbc du client est celui de patch-z.MPQ : c'est lui qui porte les 144
# sorts customs du serveur (armes 803xxxx…), et ce sont eux qui fonctionnent en
# jeu. patch-frFR-z en contient une autre copie, SANS aucun custom : y ajouter
# un sort revient à l'écrire dans un fichier que le client n'ouvre pas. On lit
# et on écrit donc ici, là où vivent les sorts qui marchent.
ARCHIVE_CIBLE = os.path.join(DATA, "patch-z.MPQ")

TRAVAIL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sorts_spherier")
SQL_SORTIE = (r"D:\Serveur WoW\azerothcore-wotlk\modules\mod-papota-spherier"
              r"\data\sql\world\2026_08_24_02_mod_papota_spherier_sorts_sphere.sql")

GABARIT = 59061
SORT_BASE = 8500001
SPHERE_BASE = 803200
SCRIPT = "spell_spherier_sphere"

# Noms des Nexus, alignés sur gen_objets_spherier.py.
NEXUS_EN = ["Depleted Nexus", "Flickering Nexus", "Luminous Nexus",
            "Irradiant Nexus", "Solar Nexus"]
NEXUS_FR = ["Nexus appauvri", "Nexus vacillant", "Nexus lumineux",
            "Nexus irradiant", "Nexus solaire"]

# Spherite octroyée par qualité — ce ne sont plus des sentinelles mais les
# valeurs arrêtées le 2026-08-24. Elles vivent dans le sort lui-même
# (EffectBasePoints) : le client les affiche par $s1, le serveur les lit par
# GetEffectValue().
POINTS = [50, 100, 250, 500, 1000]
# NEXUS PRISMATIQUE (2026-09-06) : sixième sort, +25 % de gains de Spherite du
# compte par utilisation, script a part. $s1 affiche 25.
SORT_PRISME = SORT_BASE + 5
SCRIPT_PRISME = "spell_spherier_prisme"
SORTS = [(SORT_BASE + qi, POINTS[qi], NEXUS_EN[qi], NEXUS_FR[qi],
          "Adds $s1 Spherite.", "Ajoute $s1 Spherites.", SCRIPT) for qi in range(5)]
SORTS.append((SORT_PRISME, 25, "Prismatic Nexus", "Nexus prismatique",
              "Raises all Spherite gains of your account by $s1%. Stacks without limit.",
              "Majore de $s1 % tous les gains de Spherite de votre compte. Cumulable sans limite.",
              SCRIPT_PRISME))

# Index des champs du Spell.dbc 3.3.5, relevés sur les colonnes de spell_dbc.
IDX = {"ID": 0, "Attributes": 4, "CastingTimeIndex": 28, "ProcChance": 35,
       "MaxLevel": 37, "BaseLevel": 38, "SpellLevel": 39, "DurationIndex": 40,
       "RangeIndex": 46, "EquippedItemClass": 68, "Effect_1": 71,
       "EffectDieSides_1": 74, "EffectBasePoints_1": 80, "ImplicitTargetA_1": 86,
       "SpellVisualID_1": 131, "SpellIconID": 133}

# Effet visuel joué sur le joueur à la consommation. Ce n'est pas un kit
# inventé : c'est celui de Power Infusion (sort 10060), une déflagration de
# lumière dorée sur la cible — le registre convient à l'absorption d'une
# sphère, et il est instantané, donc rien à retirer ensuite. Paragon, lui,
# passe par une aura (« Random Lightning Visual ») qu'il doit nettoyer après
# trois secondes ; inutile ici, le sort portant son propre visuel.
VISUEL = 7553
BLOCS_TEXTE = {"Name": 136, "Description": 170}
# Ordre des locales dans un DBC 3.3.5 : 0 enUS, 1 koKR, 2 frFR, 3 deDE, 4 zhCN,
# 5 zhTW, 6 esES, 7 esMX, 8 ruRU. Verifie sur le sort 47471 « Exécution » du
# Spell.dbc du serveur : l'index 2 rend « Exécution », le 3 « Hinrichten ».
# Ce fut 3 jusqu'au 2026-08-26 : les textes francais atterrissaient donc en
# allemand, et un client francais affichait l'anglais.
LOC_FRFR = 2


def stormlib():
    s = C.WinDLL(DLL)
    s.SFileOpenArchive.argtypes = [C.c_wchar_p, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    s.SFileOpenArchive.restype = C.c_bool
    s.SFileCloseArchive.argtypes = [C.c_void_p]
    s.SFileCloseArchive.restype = C.c_bool
    s.SFileOpenFileEx.argtypes = [C.c_void_p, C.c_char_p, C.c_uint, C.POINTER(C.c_void_p)]
    s.SFileOpenFileEx.restype = C.c_bool
    s.SFileGetFileSize.argtypes = [C.c_void_p, C.POINTER(C.c_uint)]
    s.SFileGetFileSize.restype = C.c_uint
    s.SFileReadFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint, C.POINTER(C.c_uint), C.c_void_p]
    s.SFileReadFile.restype = C.c_bool
    s.SFileCloseFile.argtypes = [C.c_void_p]
    s.SFileCloseFile.restype = C.c_bool
    s.SFileCreateFile.argtypes = [C.c_void_p, C.c_char_p, C.c_ulonglong, C.c_uint,
                                  C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    s.SFileCreateFile.restype = C.c_bool
    s.SFileWriteFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint, C.c_uint]
    s.SFileWriteFile.restype = C.c_bool
    s.SFileFinishFile.argtypes = [C.c_void_p]
    s.SFileFinishFile.restype = C.c_bool
    return s


def lire_dbc_du_client(s):
    """Lit le Spell.dbc de l'archive cible — celle qui porte les customs."""
    h = C.c_void_p()
    if not s.SFileOpenArchive(ARCHIVE_CIBLE, 0, 0x00000100, C.byref(h)):
        raise SystemExit("ouverture impossible : %s" % ARCHIVE_CIBLE)
    try:
        fh = C.c_void_p()
        if not s.SFileOpenFileEx(h, NOM_DBC.encode("latin-1"), 0, C.byref(fh)):
            raise SystemExit("Spell.dbc absent de %s" % ARCHIVE_CIBLE)
        haut = C.c_uint(0)
        taille = s.SFileGetFileSize(fh, C.byref(haut))
        buf = C.create_string_buffer(taille)
        lu = C.c_uint(0)
        s.SFileReadFile(fh, buf, taille, C.byref(lu), None)
        s.SFileCloseFile(fh)
        return (os.path.basename(ARCHIVE_CIBLE), buf.raw[:lu.value])
    finally:
        s.SFileCloseArchive(h)


def main():
    os.makedirs(TRAVAIL, exist_ok=True)
    s = stormlib()

    trouve = lire_dbc_du_client(s)
    if not trouve:
        raise SystemExit("Spell.dbc introuvable dans les archives du client")
    archive, brut = trouve
    if brut[:4] != b"WDBC":
        raise SystemExit("ce n'est pas un WDBC")

    nrec, nfield, rsize, ssize = struct.unpack_from("<4I", brut, 4)
    debut_str = 20 + nrec * rsize
    print("Spell.dbc lu dans %s : %d sorts" % (archive, nrec))

    enregistrements = bytearray(brut[20:debut_str])
    chaines = bytearray(brut[debut_str:debut_str + ssize])

    gab = None
    ids = set()
    for i in range(nrec):
        off = i * rsize
        ident = struct.unpack_from("<I", enregistrements, off)[0]
        ids.add(ident)
        if ident == GABARIT:
            gab = bytearray(enregistrements[off:off + rsize])
    if gab is None:
        raise SystemExit("gabarit %d absent" % GABARIT)

    # Les sorts déjà posés par une exécution précédente sont retirés : le
    # générateur doit pouvoir tourner deux fois de suite.
    anciens = [t[0] for t in SORTS]
    if any(a in ids for a in anciens):
        garde = bytearray()
        retires = 0
        for i in range(nrec):
            off = i * rsize
            ident = struct.unpack_from("<I", enregistrements, off)[0]
            if ident in anciens:
                retires += 1
                continue
            garde.extend(enregistrements[off:off + rsize])
        enregistrements = garde
        nrec -= retires
        print("  %d sort(s) d'une exécution précédente retiré(s)" % retires)

    def ajouter_chaine(txt):
        pos = len(chaines)
        chaines.extend(txt.encode("utf-8") + b"\x00")
        return pos

    def poser_texte(rec, bloc, texte_en, texte_fr):
        base = BLOCS_TEXTE[bloc]
        off_en, off_fr = ajouter_chaine(texte_en), ajouter_chaine(texte_fr)
        for loc in range(16):
            struct.pack_into("<I", rec, (base + loc) * 4,
                             off_fr if loc == LOC_FRFR else off_en)
        struct.pack_into("<I", rec, (base + 16) * 4, 0xFF)

    def champ(rec, nom, valeur, signe=False):
        struct.pack_into("<i" if signe else "<I", rec, IDX[nom] * 4, valeur)

    sql = []
    for ident, pts, nom_en, nom_fr, desc_en, desc_fr, script in SORTS:
        rec = bytearray(gab)
        champ(rec, "ID", ident)
        champ(rec, "Effect_1", 3)                 # SPELL_EFFECT_DUMMY
        champ(rec, "ImplicitTargetA_1", 1)        # le lanceur
        champ(rec, "EffectDieSides_1", 1)
        # $s1 = BasePoints + DieSides : N - 1 affiche donc N, et le serveur
        # lit la même valeur par GetEffectValue().
        champ(rec, "EffectBasePoints_1", pts - 1, signe=True)
        champ(rec, "SpellIconID", 208)
        champ(rec, "SpellVisualID_1", VISUEL)

        poser_texte(rec, "Name", nom_en, nom_fr)
        poser_texte(rec, "Description", desc_en, desc_fr)

        enregistrements.extend(rec)
        nrec += 1

        lu = struct.unpack_from("<%dI" % nfield, bytes(rec), 0)
        sql.append(dict(
            ID=ident, pts=pts,
            Attributes=lu[IDX["Attributes"]],
            CastingTimeIndex=lu[IDX["CastingTimeIndex"]],
            ProcChance=lu[IDX["ProcChance"]],
            MaxLevel=lu[IDX["MaxLevel"]], BaseLevel=lu[IDX["BaseLevel"]],
            SpellLevel=lu[IDX["SpellLevel"]], DurationIndex=lu[IDX["DurationIndex"]],
            RangeIndex=lu[IDX["RangeIndex"]],
            EquippedItemClass=struct.unpack_from("<i", bytes(rec), IDX["EquippedItemClass"] * 4)[0],
            nom_en=nom_en, nom_fr=nom_fr, desc_en=desc_en, desc_fr=desc_fr,
            script=script))

    entete = bytearray(brut[:20])
    struct.pack_into("<4I", entete, 4, nrec, nfield, rsize, len(chaines))
    neuf = bytes(entete) + bytes(enregistrements) + bytes(chaines)

    local = os.path.join(TRAVAIL, "Spell.dbc")
    with open(local, "wb") as f:
        f.write(neuf)
    print("Spell.dbc écrit : %s (%d sorts, %.1f Mo)" % (local, nrec, len(neuf) / 1048576.0))

    # --- SQL -----------------------------------------------------------------
    def q(t):
        return t.replace("'", "''")

    L = ["-- mod-papota-spherier : sorts d'utilisation des spheres.",
         "-- GENERE par outils_spherier\\gen_sorts_spherier.py — ne pas editer.",
         "-- Le meme Spell.dbc est injecte dans patch-z.MPQ cote client :",
         "-- c'est de la que vient l'infobulle « Utiliser : Ajoute N Spherites ».",
         "",
         "DELETE FROM `spell_dbc` WHERE `ID` BETWEEN %d AND %d;" % (SORT_BASE, SORT_BASE + 5),
         "INSERT INTO `spell_dbc` (`ID`, `Attributes`, `CastingTimeIndex`, `ProcChance`,",
         "    `MaxLevel`, `BaseLevel`, `SpellLevel`, `DurationIndex`, `RangeIndex`,",
         "    `EquippedItemClass`, `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`,",
         "    `ImplicitTargetA_1`, `SpellVisualID_1`, `SpellIconID`, `Name_Lang_enUS`, `Name_Lang_frFR`,",
         "    `Name_Lang_Mask`, `Description_Lang_enUS`, `Description_Lang_frFR`,",
         "    `Description_Lang_Mask`) VALUES"]
    corps = []
    for r in sql:
        corps.append("(%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, 3, 1, %d, 1, %d, 208, '%s', '%s', 255, '%s', '%s', 255)"
                     % (r["ID"], r["Attributes"], r["CastingTimeIndex"], r["ProcChance"],
                        r["MaxLevel"], r["BaseLevel"], r["SpellLevel"], r["DurationIndex"],
                        r["RangeIndex"], r["EquippedItemClass"], r["pts"] - 1, VISUEL,
                        q(r["nom_en"]), q(r["nom_fr"]), q(r["desc_en"]), q(r["desc_fr"])))
    L.append(",\n".join(corps) + ";")
    L.append("")
    L.append("-- Le sort appelle le script du module, qui lit la valeur portee par l'effet.")
    L.append("DELETE FROM `spell_script_names` WHERE `spell_id` BETWEEN %d AND %d;"
             % (SORT_BASE, SORT_BASE + 5))
    L.append("INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES")
    L.append(",\n".join("(%d, '%s')" % (r["ID"], r["script"]) for r in sql) + ";")
    L.append("")
    L.append("-- La sphere se consomme comme une potion : sort a l'usage, une charge,")
    L.append("-- et plus AUCUN script d'objet — le coeur fait tout.")
    for qi in range(6):
        L.append("UPDATE `item_template` SET `spellid_1` = %d, `spelltrigger_1` = 0, "
                 "`spellcharges_1` = -1, `ScriptName` = '' WHERE `entry` = %d;"
                 % (SORT_BASE + qi, SPHERE_BASE + qi))

    os.makedirs(os.path.dirname(SQL_SORTIE), exist_ok=True)
    with io.open(SQL_SORTIE, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print("SQL écrit :", SQL_SORTIE)

    # --- Spell.dbc du serveur ------------------------------------------------
    # Même travail sur le DBC du serveur : la table `spell_dbc` suffirait au
    # cœur, mais la convention du serveur veut que les sorts customs vivent
    # dans le DBC (144 y sont déjà). Le clonage repart du gabarit DE CE
    # fichier-là, sans quoi les décalages de chaînes ne vaudraient rien.
    dbc_serveur = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc\Spell.dbc"
    if os.path.exists(dbc_serveur):
        srv = open(dbc_serveur, "rb").read()
        s_nrec, s_nfield, s_rsize, s_ssize = struct.unpack_from("<4I", srv, 4)
        s_recs = bytearray(srv[20:20 + s_nrec * s_rsize])
        s_str = bytearray(srv[20 + s_nrec * s_rsize:20 + s_nrec * s_rsize + s_ssize])

        s_gab, retires = None, 0
        garde = bytearray()
        for i in range(s_nrec):
            off = i * s_rsize
            ident = struct.unpack_from("<I", s_recs, off)[0]
            if ident == GABARIT:
                s_gab = bytearray(s_recs[off:off + s_rsize])
            if SORT_BASE <= ident <= SORT_BASE + 5:
                retires += 1
                continue
            garde.extend(s_recs[off:off + s_rsize])
        s_recs = garde
        s_nrec -= retires

        if s_gab is None:
            print("Spell.dbc du serveur : gabarit absent — étape ignorée.")
        else:
            def ajouter_srv(txt):
                pos = len(s_str)
                s_str.extend(txt.encode("utf-8") + b"\x00")
                return pos

            for ident, pts, nom_en, nom_fr, desc_en, desc_fr, _script in SORTS:
                rec = bytearray(s_gab)
                struct.pack_into("<I", rec, IDX["ID"] * 4, ident)
                struct.pack_into("<I", rec, IDX["Effect_1"] * 4, 3)
                struct.pack_into("<I", rec, IDX["ImplicitTargetA_1"] * 4, 1)
                struct.pack_into("<I", rec, IDX["EffectDieSides_1"] * 4, 1)
                struct.pack_into("<i", rec, IDX["EffectBasePoints_1"] * 4, pts - 1)
                struct.pack_into("<I", rec, IDX["SpellIconID"] * 4, 208)
                struct.pack_into("<I", rec, IDX["SpellVisualID_1"] * 4, VISUEL)
                for bloc, (te, tf) in (("Name", (nom_en, nom_fr)),
                                       ("Description", (desc_en, desc_fr))):
                    base_b = BLOCS_TEXTE[bloc]
                    oe, of = ajouter_srv(te), ajouter_srv(tf)
                    for loc in range(16):
                        struct.pack_into("<I", rec, (base_b + loc) * 4,
                                         of if loc == LOC_FRFR else oe)
                    struct.pack_into("<I", rec, (base_b + 16) * 4, 0xFF)
                s_recs.extend(rec)
                s_nrec += 1

            sauvegarde_srv = dbc_serveur + ".avant_spherier"
            if not os.path.exists(sauvegarde_srv):
                import shutil
                shutil.copyfile(dbc_serveur, sauvegarde_srv)
                print("  sauvegarde :", sauvegarde_srv)

            e = bytearray(srv[:20])
            struct.pack_into("<4I", e, 4, s_nrec, s_nfield, s_rsize, len(s_str))
            with open(dbc_serveur, "wb") as f:
                f.write(bytes(e) + bytes(s_recs) + bytes(s_str))
            print("Spell.dbc du serveur : %d sorts (%d remplacés, %d ajoutés)"
                  % (s_nrec, retires, len(SORTS)))

    # --- injection dans l'archive du client -----------------------------------
    if "--deploy" not in sys.argv:
        print("\nInjection dans le MPQ NON faite (ajouter --deploy). Jeu FERMÉ requis.")
        return

    sauvegarde = ARCHIVE_CIBLE + ".avant_sorts_spherier"
    if not os.path.exists(sauvegarde):
        import shutil
        print("sauvegarde de l'archive…")
        shutil.copyfile(ARCHIVE_CIBLE, sauvegarde)
        print("  ->", sauvegarde)

    h = C.c_void_p()
    if not s.SFileOpenArchive(ARCHIVE_CIBLE, 0, 0, C.byref(h)):
        raise SystemExit("ouverture en écriture impossible — le jeu est-il fermé ?")
    try:
        fh = C.c_void_p()
        if not s.SFileCreateFile(h, NOM_DBC.encode("latin-1"), 0, len(neuf), 0,
                                 0x00000200 | 0x80000000, C.byref(fh)):
            raise SystemExit("SFileCreateFile a échoué")
        buf = C.create_string_buffer(neuf, len(neuf))
        if not s.SFileWriteFile(fh, buf, len(neuf), 0x02):
            raise SystemExit("SFileWriteFile a échoué")
        s.SFileFinishFile(fh)
        print("Spell.dbc injecté dans", ARCHIVE_CIBLE)
    finally:
        s.SFileCloseArchive(h)


if __name__ == "__main__":
    main()
