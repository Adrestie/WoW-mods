# -*- coding: utf-8 -*-
r"""Engendre les rangs supplémentaires et leurs runes.

Rien n'est créé à partir de rien : chaque rang est le **clone** du dernier rang
de Blizzard, avec ses valeurs remplacées par celles de rangs_extrapoles.json.
C'est le motif déjà éprouvé par gen_sorts_spherier.py pour les Nexus.

Ce qui est produit :

  - les entrées de `Spell.dbc`, dans celui du serveur ET dans celui du client
    (patch-z.MPQ, `--deploy`, **jeu fermé obligatoire**) ;
  - le SQL : `spell_dbc` pour le cœur, `spell_ranks` pour chaîner les rangs ;
  - une rune par sort, objet lootable qui donnera ce rang.

Allocation des identifiants, à ne plus bouger :
  - rangs customs : 8510000 + 10 × index du sort + numéro du rang (1 à 3),
    ce qui laisse de la place pour les sous-sorts déclenchés au même index ;
  - sous-sorts déclenchés : le même identifiant + 5 ;
  - runes : 803400 + index du sort.
"""

import io
import json
import os
import struct
import sys

SOURCE = r"D:\Serveur WoW\outils_spherier\rangs_extrapoles.json"
DBC_SERVEUR = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc\Spell.dbc"
# Le dossier du client se CHERCHE, version comprise (2026-09-06) : ecrit en dur,
# il avait fait echouer l'injection en silence au renommage 1.1.0 -> 1.2.0.
from gen_sorts_classes import dossier_client as _dossier_client
ARCHIVE = os.path.join(_dossier_client(), "patch-z.MPQ")
NOM_DBC = r"DBFilesClient\Spell.dbc"
DLL = r"D:\Serveur WoW\tools\StormLib_build\Release\StormLib.dll"
TRAVAIL = r"D:\Serveur WoW\outils_spherier\rangs_sorts"
SQL_SORTIE = (r"D:\Serveur WoW\azerothcore-wotlk\modules\mod-papota-spherier"
              r"\data\sql\world\2026_08_26_02_mod_papota_spherier_rangs.sql")

SORT_BASE = 8510000
RUNE_BASE = 803400
# Borne HAUTE des runes de rang. Elle n'est pas cosmetique : au-dela
# commencent les runes de STATISTIQUE (803600), qu'un nettoyage trop
# large effacait a chaque generation — de item_template, de item_dbc et
# de l'Item.dbc du client.
RUNE_MAX = 803599
DECALAGE_SOUS_SORT = 5
# Un rang dispose d'un bloc de dix identifiants, dont un seul reste libre pour
# un sous-sort. Or Mutilation en a deux — l'ours et le felin —, Estropier aussi
# — la main droite et la main gauche —, aux valeurs distinctes. Le SECOND va
# donc dans une plage a part, batie sur le meme calcul.
SOUS_SORT_2_BASE = 8520000
# Les chaines paralleles ont leur propre plage : elles ne doivent PAS entrer
# dans le compte de l'index principal, sans quoi tous les identifiants des sorts
# suivants glisseraient. L'ordre est celui des familles triees, donc stable tant
# que la liste ne change pas.
PARALLELE_BASE = 8540000

LOC_FRFR = 2                    # 0 enUS, 1 koKR, 2 frFR, 3 deDE…
IDX = {"ID": 0, "Effect_1": 71, "EffectDieSides_1": 74,
       "EffectBasePoints_1": 80, "EffectTriggerSpell_1": 116,
       "Name": 136, "Rank": 153}
BLOCS = {"Name": 136, "Rank": 153, "Description": 170, "AuxiliaryText": 187}

# SORTS ÉCARTÉS — l'index N'EST PAS décalé pour autant : il continue de
# compter, sinon tous les identifiants de rangs et de runes glisseraient.
#
# 1) Chaînes PARALLÈLES trop courtes. Plusieurs scripts du cœur traduisent le
#    rang du sort lancé en un rang d'une AUTRE chaîne — les dégâts du Horion
#    sacré, la main gauche du chevalier de la mort… `SpellMgr::GetSpellWithRank`
#    y remonte de rang en rang et déréférence `node->next` SANS vérifier qu'il
#    est non nul (SpellMgr.cpp:647) : un rang au-delà du dernier fait planter le
#    serveur, au démarrage pour ceux dont le script a un Validate, en jeu pour
#    les autres. Écartés tant que ces chaînes ne sont pas étendues elles aussi.
# 2) Rangs sans aucun effet : le rang custom est le clone EXACT du rang de
#    Blizzard, rien n'y varie. Retirés du catalogue le 2026-08-26.
EXCLUS = {
    25899: "rang custom identique au rang de Blizzard — rune sans effet",
    49222: "rang custom identique au rang de Blizzard — rune sans effet",
    48505: "puissance à DEUX niveaux : l'effet appelle un sort muet qui porte "
           "l'identifiant du vrai sort de dégâts — rien à mettre à l'échelle "
           "sans descendre d'un cran de plus",
}

# --- HABILLAGE CLIENT : icône de la rune, onglet du grimoire ---------------
#
# Deux manques constatés en jeu le 2026-08-26, trois dépôts CLIENT à remplir.
#
# a) Les runes n'avaient aucune icône. Deux causes cumulées : elles étaient
#    absentes de l'`Item.dbc` du client — sans quoi c'est le point
#    d'interrogation rouge, le client résolvant l'apparence par SON dbc et non
#    par ce que le serveur envoie — et leur `displayid` 20860 n'existe pas dans
#    `ItemDisplayInfo.dbc`. On crée donc une entrée d'affichage PAR RUNE, qui
#    porte l'icône du sort amélioré : une Rune de Frappe héroïque montre
#    l'icône de Frappe héroïque. L'icône se lit dans `SpellIcon.dbc`, à
#    l'identifiant que le sort porte déjà (Spell.dbc, champ 133) — aucun chemin
#    codé en dur, et le nom de fichier seul, sans le dossier, comme le veut
#    ItemDisplayInfo.
#
# b) Un rang custom tombait dans l'onglet « Général » du grimoire au lieu de
#    celui de sa catégorie. L'onglet vient de `SkillLineAbility.dbc`, côté
#    CLIENT : un sort qui n'y figure pas n'appartient à aucune ligne de
#    compétence. On clone la ligne du dernier rang de Blizzard — les 147 sorts
#    retenus en ont une et une seule, vérifié — en remettant à zéro
#    `SupercededBySpell` (le joueur doit CONNAÎTRE tous les rangs, pas voir
#    seulement le dernier) et `AcquireMethod` (rien ne s'apprend tout seul).
#    Le serveur, lui, n'en a pas besoin : il n'y lit rien qui nous concerne.
#
# Tout va dans patch-z.MPQ. `SkillLineAbility.dbc` vient de patch-frfr-3.mpq et
# `SpellIcon.dbc` de patch-frFR-z.mpq, mais la PREUVE que patch-z l'emporte est
# sous nos yeux : nos rangs customs, qui ne vivent que là, s'affichent en jeu.
DISPLAY_BASE = 802000           # au-dessus des 801xxx déjà pris par le serveur
GABARIT_DISPLAY = 20984         # « Rune of Escape » : une entrée nue, sans modèle
SLA_BASE = 30000                # au-dessus du 21980 de Blizzard
ITEM_DBC_SERVEUR = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc\Item.dbc"
IDX_SPELL_ICON = 133            # SpellIconID, dans Spell.dbc
# Ordre de priorité des archives du client, du plus fort au plus faible.
ARCHIVES = [r"frFR\patch-frFR-z.mpq", "patch-z.MPQ",
            r"frFR\patch-frfr-3.mpq", "patch-3.mpq",
            r"frFR\patch-frfr-2.mpq", "patch-2.mpq",
            r"frFR\patch-frfr.mpq", "patch.mpq",
            "patch-c.mpq", "patch-b.mpq", "patch-a.mpq",
            "lichking.mpq", "expansion.mpq", "common-2.mpq", "common.mpq",
            r"frFR\locale-frfr.mpq", r"frFR\base-frfr.mpq"]
DOSSIER_CLIENT = _dossier_client()

QUALITE_RUNE = 4                # épique

# Identifiant de classe par feuille du classeur. Une rune de rang ne se sertit
# que dans le sphèrier de sa classe ; elle se LOOTE en revanche sans condition,
# et c'est l'établi qui la rendra utile (§6).
CLASSES = {
    "Guerrier": 1, "Paladin": 2, "Chasseur": 3, "Voleur": 4, "Prêtre": 5,
    "Chevalier de la mort": 6, "Chaman": 7, "Mage": 8, "Démoniste": 9,
    "Druide": 11,
}


def charger_dbc(chemin):
    brut = open(chemin, "rb").read()
    nrec, nfield, rsize, ssize = struct.unpack_from("<4I", brut, 4)
    entete = bytearray(brut[:20])
    enregs = bytearray(brut[20:20 + nrec * rsize])
    chaines = bytearray(brut[20 + nrec * rsize:20 + nrec * rsize + ssize])
    return entete, enregs, chaines, nrec, nfield, rsize


def index_par_id(enregs, nrec, rsize):
    return {struct.unpack_from("<I", enregs, i * rsize)[0]: i for i in range(nrec)}


def texte(chaines, off):
    if off <= 0 or off >= len(chaines):
        return ""
    return bytes(chaines[off:chaines.index(0, off)]).decode("utf-8", "replace")


def ajouter_chaine(chaines, txt):
    pos = len(chaines)
    chaines.extend(txt.encode("utf-8") + b"\x00")
    return pos


def poser_bloc(rec, nfield, chaines, bloc, texte_fr, texte_en):
    base = BLOCS[bloc]
    off_en = ajouter_chaine(chaines, texte_en)
    off_fr = ajouter_chaine(chaines, texte_fr)
    for loc in range(16):
        struct.pack_into("<I", rec, (base + loc) * 4,
                         off_fr if loc == LOC_FRFR else off_en)
    struct.pack_into("<I", rec, (base + 16) * 4, 0xFF)


def fabriquer(enregs, chaines, nfield, rsize, position, modele_idx, ident,
              effets, sous_ids, numero_rang, nom_fr, nom_en):
    """Un enregistrement de sort, cloné puis retouché.

    `sous_ids` associe un NUMÉRO D'EFFET au sous-sort qui lui a été créé. Un
    effet déclencheur sans sous-sort à lui garde celui du modèle, c'est-à-dire
    celui de Blizzard : mieux vaut le rang précédent qu'un sort étranger.
    """
    rec = bytearray(enregs[modele_idx * rsize:(modele_idx + 1) * rsize])
    struct.pack_into("<I", rec, IDX["ID"] * 4, ident)

    for e in effets:
        i = e["n"] - 1
        struct.pack_into("<i", rec, (IDX["EffectBasePoints_1"] + i) * 4, e["base"])
        struct.pack_into("<I", rec, (IDX["EffectDieSides_1"] + i) * 4, e["des"])
        if e.get("declenche") and sous_ids.get(e["n"]):
            struct.pack_into("<I", rec, (IDX["EffectTriggerSpell_1"] + i) * 4,
                             sous_ids[e["n"]])

    poser_bloc(rec, nfield, chaines, "Rank",
               "Rang %d" % numero_rang, "Rank %d" % numero_rang)
    poser_bloc(rec, nfield, chaines, "Name", nom_fr, nom_en)
    return rec


def engendrer(chemin_dbc, donnees, pour_client):
    entete, enregs, chaines, nrec, nfield, rsize = charger_dbc(chemin_dbc)
    par_id = index_par_id(enregs, nrec, rsize)

    # Retrait d'une exécution précédente.
    garde, retires = bytearray(), 0
    for i in range(nrec):
        ident = struct.unpack_from("<I", enregs, i * rsize)[0]
        if SORT_BASE <= ident < SORT_BASE + 2000000:
            retires += 1
            continue
        garde.extend(enregs[i * rsize:(i + 1) * rsize])
    enregs, nrec = garde, nrec - retires
    par_id = index_par_id(enregs, nrec, rsize)

    lignes_sql, chaine_sql, runes, habillage = [], [], [], []
    index = 0
    # Ordre stable des chaines paralleles, independant de l'index principal.
    paralleles = sorted({s["famille"] for l in donnees.values() for s in l
                         if s.get("parallele")})
    rang_parallele = {f: i for i, f in enumerate(paralleles)}

    for classe, liste in donnees.items():
        for sort in liste:
            if sort.get("parallele"):
                index_p = rang_parallele[sort["famille"]]
                modele_p = sort["dernier_spell"]
                if modele_p not in par_id:
                    continue
                nom_p = texte(chaines, struct.unpack_from(
                    "<I", enregs, par_id[modele_p] * rsize
                    + (IDX["Name"] + LOC_FRFR) * 4)[0])
                nom_p_en = texte(chaines, struct.unpack_from(
                    "<I", enregs, par_id[modele_p] * rsize + IDX["Name"] * 4)[0])
                for n, rang in enumerate(sort["rangs"], start=1):
                    ident_p = PARALLELE_BASE + index_p * 10 + n
                    rec = fabriquer(enregs, chaines, nfield, rsize, index_p,
                                    par_id[modele_p], ident_p, rang["effets"],
                                    {}, rang["rang"], nom_p, nom_p_en)
                    enregs.extend(rec)
                    nrec += 1
                    lignes_sql.append((ident_p, modele_p, nom_p, rang["rang"]))
                    chaine_sql.append((sort["famille"], ident_p, rang["rang"]))
                if not pour_client:
                    print("  chaîne parallèle : %s, %d rang(s)"
                          % (sort["nom"], len(sort["rangs"])))
                continue

            index += 1
            if sort["famille"] in EXCLUS:
                if not pour_client:
                    print("  écarté : %d — %s" % (sort["famille"], EXCLUS[sort["famille"]]))
                continue
            modele = sort["dernier_spell"]
            if modele not in par_id:
                continue
            nom_fr = texte(chaines, struct.unpack_from(
                "<I", enregs, par_id[modele] * rsize + (IDX["Name"] + LOC_FRFR) * 4)[0])
            nom_en = texte(chaines, struct.unpack_from(
                "<I", enregs, par_id[modele] * rsize + IDX["Name"] * 4)[0])
            # L'icône du sort amélioré, que la rune reprendra à son compte.
            icone = struct.unpack_from(
                "<I", enregs, par_id[modele] * rsize + IDX_SPELL_ICON * 4)[0]
            rangs_ids = []

            # Le premier rang d'une chaîne que nous venons de créer doit
            # s'annoncer. Blizzard laisse le texte de rang VIDE sur un sort
            # unique ; le client, en redescendant d'un rang, écrirait alors du
            # vide par-dessus « Rang 2 » et garderait l'ancienne étiquette.
            if sort["rangs_existants"] == 1:
                base_rang = BLOCS["Rank"]
                depart = par_id[modele] * rsize
                off_en = ajouter_chaine(chaines, "Rank 1")
                off_fr = ajouter_chaine(chaines, "Rang 1")
                for loc in range(16):
                    struct.pack_into("<I", enregs, depart + (base_rang + loc) * 4,
                                     off_fr if loc == LOC_FRFR else off_en)
                struct.pack_into("<I", enregs, depart + (base_rang + 16) * 4, 0xFF)

            # `spell_ranks` décrit une chaîne ENTIÈRE : le rang 1 doit y
            # figurer. Blizzard n'y met rien pour les sorts à rang unique, si
            # bien que nos rangs 2-3-4 formaient une chaîne commençant à 2, que
            # LoadSpellRanks rejette en bloc. On pose donc le sort lui-même en
            # rang 1. Vérifié le 2026-08-26 : les familles à `rangs_existants`
            # égal à 1 sont EXACTEMENT celles qui n'ont aucune ligne.
            if sort["rangs_existants"] == 1:
                chaine_sql.append((sort["famille"], sort["famille"], 1))

            for n, rang in enumerate(sort["rangs"], start=1):
                ident = SORT_BASE + index * 10 + n
                # Un identifiant PAR sous-sort, associé à l'effet qui l'appelle.
                # Les fondre en un seul faisait prendre au félin les chiffres de
                # l'ours — constaté sur Mutilation le 2026-08-26.
                sous_ids = {}
                for numero, sd in sorted((rang.get("sous_sorts") or {}).items()):
                    if sd["modele"] not in par_id:
                        continue
                    if len(sous_ids) == 0:
                        sous_id = ident + DECALAGE_SOUS_SORT
                    elif len(sous_ids) == 1:
                        sous_id = SOUS_SORT_2_BASE + index * 10 + n
                    else:
                        print("  %s : plus de deux sous-sorts, le reste est ignore"
                              % nom_fr)
                        break
                    rec = fabriquer(enregs, chaines, nfield, rsize, index,
                                    par_id[sd["modele"]], sous_id,
                                    sd["effets"], {}, rang["rang"],
                                    sd["nom"], sd["nom"])
                    enregs.extend(rec)
                    nrec += 1
                    lignes_sql.append((sous_id, sd["modele"], sd["nom"], rang["rang"]))
                    sous_ids[int(numero)] = sous_id

                rec = fabriquer(enregs, chaines, nfield, rsize, index,
                                par_id[modele], ident, rang["effets"], sous_ids,
                                rang["rang"], nom_fr, nom_en)
                enregs.extend(rec)
                nrec += 1
                lignes_sql.append((ident, modele, nom_fr, rang["rang"]))
                chaine_sql.append((sort["famille"], ident, rang["rang"]))
                rangs_ids.append(ident)

            # Deux noms : l'anglais pour item_template, le français pour la
            # locale. Les confondre donnerait « Rune of Frappe héroïque ».
            runes.append((RUNE_BASE + index, classe, nom_fr, nom_en,
                          sort["famille"], sort["rangs_existants"],
                          DISPLAY_BASE + index, modele,
                          1 if sort.get("origine") == "Talent" else 0,
                          CLASSES.get(classe, 0)))
            habillage.append({"rune": RUNE_BASE + index,
                              "display": DISPLAY_BASE + index,
                              "icone": icone, "modele": modele,
                              "rangs": rangs_ids})

    struct.pack_into("<4I", entete, 4, nrec, nfield, rsize, len(chaines))
    sortie = os.path.join(TRAVAIL, "Spell.dbc") if pour_client else chemin_dbc
    os.makedirs(TRAVAIL, exist_ok=True)
    if not pour_client:
        sauvegarde = chemin_dbc + ".avant_rangs"
        if not os.path.exists(sauvegarde):
            import shutil
            shutil.copyfile(chemin_dbc, sauvegarde)
    with open(sortie, "wb") as f:
        f.write(bytes(entete) + bytes(enregs) + bytes(chaines))
    print("  %s : %d sorts (%d retirés, %d ajoutés)"
          % (os.path.basename(sortie), nrec, retires, len(lignes_sql)))
    return lignes_sql, chaine_sql, runes, habillage


def extraire_du_mpq():
    """Le Spell.dbc du client vit dans patch-z.MPQ — pas dans patch-frFR-z,
    qui n'en contient aucun custom. Leçon acquise à la dure le 2026-08-24."""
    import ctypes
    from ctypes import wintypes

    s = ctypes.WinDLL(DLL)
    s.SFileOpenArchive.argtypes = [wintypes.LPCWSTR, wintypes.DWORD,
                                   wintypes.DWORD, ctypes.POINTER(ctypes.c_void_p)]
    s.SFileOpenFileEx.argtypes = [ctypes.c_void_p, wintypes.LPCSTR, wintypes.DWORD,
                                  ctypes.POINTER(ctypes.c_void_p)]
    s.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
    s.SFileGetFileSize.restype = wintypes.DWORD
    s.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD,
                                ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]

    mpq = ctypes.c_void_p()
    if not s.SFileOpenArchive(ARCHIVE, 0, 0x00000100, ctypes.byref(mpq)):
        raise SystemExit("archive illisible : %s" % ARCHIVE)
    fic = ctypes.c_void_p()
    if not s.SFileOpenFileEx(mpq, NOM_DBC.encode("ascii"), 0, ctypes.byref(fic)):
        raise SystemExit("Spell.dbc absent de l'archive")
    haut = wintypes.DWORD(0)
    taille = s.SFileGetFileSize(fic, ctypes.byref(haut))
    tampon = ctypes.create_string_buffer(taille)
    lu = wintypes.DWORD(0)
    s.SFileReadFile(fic, tampon, taille, ctypes.byref(lu), None)
    s.SFileCloseFile(fic)
    s.SFileCloseArchive(mpq)

    os.makedirs(TRAVAIL, exist_ok=True)
    local = os.path.join(TRAVAIL, "Spell_client_source.dbc")
    with open(local, "wb") as f:
        f.write(tampon.raw[:lu.value])
    return local


def injecter(fichier, nom=None):
    import ctypes
    from ctypes import wintypes
    import shutil

    nom = nom or NOM_DBC
    sauvegarde = ARCHIVE + ".avant_rangs"
    if not os.path.exists(sauvegarde):
        print("  sauvegarde de l'archive…")
        shutil.copyfile(ARCHIVE, sauvegarde)

    s = ctypes.WinDLL(DLL)
    s.SFileOpenArchive.argtypes = [wintypes.LPCWSTR, wintypes.DWORD,
                                   wintypes.DWORD, ctypes.POINTER(ctypes.c_void_p)]
    s.SFileAddFileEx.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR, wintypes.LPCSTR,
                                 wintypes.DWORD, wintypes.DWORD, wintypes.DWORD]
    mpq = ctypes.c_void_p()
    if not s.SFileOpenArchive(ARCHIVE, 0, 0, ctypes.byref(mpq)):
        raise SystemExit("archive verrouillée — le jeu est-il fermé ?")
    ok = s.SFileAddFileEx(mpq, fichier, nom.encode("ascii"),
                          0x80000000 | 0x0200, 0x02, 0)
    s.SFileCloseArchive(mpq)
    if not ok:
        raise SystemExit("injection refusée : " + nom)
    print("  %s injecté dans %s"
          % (os.path.basename(nom.replace("\\", "/")), os.path.basename(ARCHIVE)))


def ecrire_sql(chaine_sql, runes):
    def q(t):
        return t.replace("\\", "\\\\").replace("'", "''")

    L = ["-- mod-papota-spherier : rangs supplementaires et runes de sort.",
         "-- GENERE par outils_spherier\\gen_rangs_sorts.py — ne pas editer.",
         "--",
         "-- Les sorts eux-memes vivent dans Spell.dbc (serveur et client) : le",
         "-- coeur les y lit directement, la table de surcharge n'ajouterait rien",
         "-- pour 471 entrees. Ce fichier ne porte que le CHAINAGE des rangs et",
         "-- les objets-runes.",
         "",
         "DELETE FROM `spell_ranks` WHERE `spell_id` BETWEEN %d AND %d;"
         % (SORT_BASE, SORT_BASE + 2000000)]

    # Le rang 1 que nous posons porte l'identifiant de Blizzard : le DELETE
    # ci-dessus, borné à nos identifiants, ne le reprendrait pas.
    familles_seules = sorted({c[0] for c in chaine_sql if c[0] == c[1]})
    if familles_seules:
        L.append("DELETE FROM `spell_ranks` WHERE `first_spell_id` IN (%s);"
                 % ", ".join(str(f) for f in familles_seules))
    L.append("INSERT INTO `spell_ranks` (`first_spell_id`, `spell_id`, `rank`) VALUES")
    L.append(",\n".join("(%d, %d, %d)" % c for c in chaine_sql) + ";")
    L.append("")

    L.append("DELETE FROM `item_template` WHERE `entry` BETWEEN %d AND %d;"
             % (RUNE_BASE, RUNE_MAX))
    L.append("DELETE FROM `item_template_locale` WHERE `ID` BETWEEN %d AND %d;"
             % (RUNE_BASE, RUNE_MAX))
    L.append("DELETE FROM `item_dbc` WHERE `ID` BETWEEN %d AND %d;"
             % (RUNE_BASE, RUNE_MAX))
    L.append("")
    L.append("INSERT INTO `item_template`")
    L.append("  (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`,")
    L.append("   `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`, `ItemLevel`,")
    L.append("   `RequiredLevel`, `bonding`, `stackable`, `MaxDurability`, `description`,")
    L.append("   `ScriptName`, `spellid_1`, `spelltrigger_1`) VALUES")
    items, locales, dbc, table = [], [], [], []
    def de(nom_sort):
        """« Rune de Frappe heroique », mais « Rune d'Onde de choc » : en
        francais, « de » s'elide devant une voyelle ou un h muet."""
        return ("d'" if nom_sort[:1] in "aeiouyhAEIOUYHàâäéèêëîïôöùûüÿœÀÂÄÉÈÊËÎÏÔÖÙÛÜŒ"
                else "de ") + nom_sort

    for (entree, classe, nom, nom_anglais, famille, rangs_blizzard, display,
         dernier_bliz, talent, class_id) in runes:
        table.append("(%d, %d, %d, %d, %d, %d)"
                     % (entree, famille, rangs_blizzard, dernier_bliz, talent,
                        class_id))
        nom_en = "Rune of %s" % nom_anglais
        nom_fr = "Rune %s" % de(nom)
        desc = "Adds one rank to %s. Three at most per spell." % nom_anglais
        desc_fr = ("Ajoute un rang à %s. Trois au maximum par sort." % nom)
        items.append("(%d, 3, 0, '%s', %d, %d, 0, 1, 0, 0, 0, 1, 1, 0, 20, 0, '%s', '', 0, 0)"
                     % (entree, q(nom_en), display, QUALITE_RUNE, q(desc)))
        locales.append("(%d, 'frFR', '%s', '%s')" % (entree, q(nom_fr), q(desc_fr)))
        dbc.append("(%d, 3, 0, -1, 0, %d, 0, 0)" % (entree, display))
    L.append(",\n".join(items) + ";")
    L.append("")
    L.append("INSERT INTO `item_template_locale` (`ID`, `locale`, `Name`, `Description`) VALUES")
    L.append(",\n".join(locales) + ";")
    L.append("")
    L.append("-- Sans entree dans Item.dbc, ObjectMgr::LoadItemTemplates IGNORE la ligne.")
    L.append("INSERT INTO `item_dbc`")
    L.append("  (`ID`, `ClassID`, `SubclassID`, `Sound_Override_Subclassid`, `Material`,")
    L.append("   `DisplayInfoID`, `InventoryType`, `SheatheType`) VALUES")
    L.append(",\n".join(dbc) + ";")
    L.append("")

    L.append("""-- Ce qu'une rune ameliore. `base_rank` est le nombre de rangs de
-- BLIZZARD : la premiere rune donne le rang base_rank + 1, la deuxieme le
-- suivant, la troisieme le dernier. Les rangs customs sont retrouves par
-- spell_ranks, chaine plus haut.
--
-- `base_spell_id` est le dernier rang de Blizzard, celui que le joueur doit
-- DEJA connaitre pour que la rune agisse — sans quoi elle reste inerte. C'est
-- le pre-requis que l'interface annonce avant de sertir. `is_talent` dit si ce
-- sort vient d'un talent : c'est le seul cas ou le pre-requis peut manquer, et
-- donc le seul ou il vaut la peine de l'afficher.
--
-- DROP plutot qu'ALTER : MySQL ne connait pas `ADD COLUMN IF NOT EXISTS`, et
-- le contenu est integralement reengendre juste en dessous.
DROP TABLE IF EXISTS `papota_sphere_rune`;
CREATE TABLE `papota_sphere_rune` (
  `item_entry` INT UNSIGNED NOT NULL,
  `first_spell_id` INT UNSIGNED NOT NULL COMMENT 'premier rang de la famille',
  `base_rank` TINYINT UNSIGNED NOT NULL COMMENT 'nombre de rangs de Blizzard',
  `base_spell_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'dernier rang de Blizzard : le pre-requis',
  `is_talent` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 si le sort vient d un talent',
  `class_id` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'classe seule autorisee a la sertir',
  PRIMARY KEY (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : rune de rang, rechargeable';""")
    L.append("INSERT INTO `papota_sphere_rune`\n  (`item_entry`, `first_spell_id`, `base_rank`, `base_spell_id`, `is_talent`,\n   `class_id`) VALUES")
    L.append(",\n".join(table) + ";")

    os.makedirs(os.path.dirname(SQL_SORTIE), exist_ok=True)
    with io.open(SQL_SORTIE, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print("SQL ecrit :", SQL_SORTIE)


# ---------------------------------------------------------------------------
# Habillage client : Item.dbc, ItemDisplayInfo.dbc, SkillLineAbility.dbc
# ---------------------------------------------------------------------------

def lire_du_client(nom):
    """Le DBC tel que le client le voit : la premiere archive qui le porte,
    dans l'ordre de priorite. Ouverture en LECTURE SEULE, le jeu peut tourner."""
    import ctypes
    from ctypes import wintypes

    s = ctypes.WinDLL(DLL)
    s.SFileOpenArchive.argtypes = [wintypes.LPCWSTR, wintypes.DWORD,
                                   wintypes.DWORD, ctypes.POINTER(ctypes.c_void_p)]
    s.SFileOpenFileEx.argtypes = [ctypes.c_void_p, wintypes.LPCSTR, wintypes.DWORD,
                                  ctypes.POINTER(ctypes.c_void_p)]
    s.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
    s.SFileGetFileSize.restype = wintypes.DWORD
    s.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD,
                                ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]
    # PIEGE : ces trois-la renvoient un `bool` C++, donc UN SEUL octet. Sans
    # restype, ctypes lit quatre octets et les bits de poids fort, laisses tels
    # quels, font passer un FAUX pour un VRAI. On croit alors avoir ouvert un
    # fichier que l'archive ne contient pas, et la taille ressort a zero.
    s.SFileOpenArchive.restype = ctypes.c_bool
    s.SFileOpenFileEx.restype = ctypes.c_bool
    s.SFileReadFile.restype = ctypes.c_bool
    for rel in ARCHIVES:
        chemin = os.path.join(DOSSIER_CLIENT, rel)
        if not os.path.exists(chemin):
            continue
        mpq = ctypes.c_void_p()
        if not s.SFileOpenArchive(chemin, 0, 0x00000100, ctypes.byref(mpq)):
            continue
        fic = ctypes.c_void_p()
        if s.SFileOpenFileEx(mpq, ("DBFilesClient\\" + nom).encode("ascii"),
                             0, ctypes.byref(fic)):
            haut = wintypes.DWORD(0)
            taille = s.SFileGetFileSize(fic, ctypes.byref(haut))
            tampon = ctypes.create_string_buffer(taille)
            lu = wintypes.DWORD(0)
            s.SFileReadFile(fic, tampon, taille, ctypes.byref(lu), None)
            s.SFileCloseFile(fic)
            s.SFileCloseArchive(mpq)
            return rel, tampon.raw[:lu.value]
        s.SFileCloseArchive(mpq)
    raise SystemExit("%s introuvable dans les archives du client" % nom)


def decoupe(brut):
    nrec, nfield, rsize, ssize = struct.unpack_from("<4I", brut, 4)
    debut = 20 + nrec * rsize
    return (bytearray(brut[:20]), bytearray(brut[20:debut]),
            bytearray(brut[debut:debut + ssize]), nrec, nfield, rsize)


def recoud(entete, enregs, chaines, nrec, nfield, rsize):
    e = bytearray(entete)
    struct.pack_into("<4I", e, 4, nrec, nfield, rsize, len(chaines))
    return bytes(e) + bytes(enregs) + bytes(chaines)


def sans_les_notres(enregs, nrec, rsize, bas, haut):
    """Retire nos lignes, pour que le generateur puisse tourner deux fois."""
    garde, retires = bytearray(), 0
    for i in range(nrec):
        ident = struct.unpack_from("<I", enregs, i * rsize)[0]
        if bas <= ident <= haut:
            retires += 1
            continue
        garde.extend(enregs[i * rsize:(i + 1) * rsize])
    return garde, nrec - retires, retires


def icones_des_sorts():
    """SpellIconID -> nom de fichier, sans le dossier : c'est ce que
    ItemDisplayInfo attend, alors que SpellIcon.dbc porte le chemin entier."""
    _, brut = lire_du_client("SpellIcon.dbc")
    _, enregs, chaines, nrec, nfield, rsize = decoupe(brut)
    noms = {}
    for i in range(nrec):
        off = i * rsize
        ident = struct.unpack_from("<I", enregs, off)[0]
        chemin = texte(chaines, struct.unpack_from("<I", enregs, off + 4)[0])
        noms[ident] = chemin.replace("/", "\\").rsplit("\\", 1)[-1]
    return noms


def habiller(habillage, deployer):
    """Les trois depots CLIENT qui manquaient, plus l'Item.dbc du serveur."""
    noms = icones_des_sorts()
    sans_icone = [h for h in habillage if not noms.get(h["icone"])]
    if sans_icone:
        print("  %d rune(s) sans icone connue - repli sur le gabarit"
              % len(sans_icone))

    # --- ItemDisplayInfo.dbc : une entree par rune, l'icone de son sort ------
    rel, brut = lire_du_client("ItemDisplayInfo.dbc")
    entete, enregs, chaines, nrec, nfield, rsize = decoupe(brut)
    gabarit = None
    for i in range(nrec):
        if struct.unpack_from("<I", enregs, i * rsize)[0] == GABARIT_DISPLAY:
            gabarit = bytearray(enregs[i * rsize:(i + 1) * rsize])
            break
    if gabarit is None:
        raise SystemExit("gabarit d'affichage %d absent" % GABARIT_DISPLAY)
    enregs, nrec, retires = sans_les_notres(enregs, nrec, rsize,
                                            DISPLAY_BASE, DISPLAY_BASE + 999)
    deja = {}
    for h in habillage:
        icone = noms.get(h["icone"]) or ""
        if icone not in deja:
            deja[icone] = ajouter_chaine(chaines, icone)
        rec = bytearray(gabarit)
        struct.pack_into("<I", rec, 0, h["display"])
        struct.pack_into("<I", rec, 5 * 4, deja[icone])
        enregs.extend(rec)
        nrec += 1
    local = os.path.join(TRAVAIL, "ItemDisplayInfo.dbc")
    open(local, "wb").write(recoud(entete, enregs, chaines, nrec, nfield, rsize))
    print("  ItemDisplayInfo.dbc (%s) : %d lignes (%d retirees, %d ajoutees)"
          % (rel, nrec, retires, len(habillage)))
    if deployer:
        injecter(local, r"DBFilesClient\ItemDisplayInfo.dbc")

    # --- Item.dbc : sans lui, point d'interrogation rouge --------------------
    lignes = [[h["rune"], 3, 0, -1, 0, h["display"], 0, 0] for h in habillage]

    def refaire_item(brut):
        entete, enregs, chaines, nrec, nfield, rsize = decoupe(brut)
        enregs, nrec, retires = sans_les_notres(enregs, nrec, rsize,
                                                RUNE_BASE, RUNE_MAX)
        for champs in lignes:
            rec = bytearray(rsize)
            for k, v in enumerate(champs[:nfield]):
                struct.pack_into("<i", rec, k * 4, v)
            enregs.extend(rec)
            nrec += 1
        return recoud(entete, enregs, chaines, nrec, nfield, rsize), nrec, retires

    if os.path.exists(ITEM_DBC_SERVEUR):
        sauvegarde = ITEM_DBC_SERVEUR + ".avant_rangs"
        if not os.path.exists(sauvegarde):
            import shutil
            shutil.copyfile(ITEM_DBC_SERVEUR, sauvegarde)
        neuf, n, r = refaire_item(open(ITEM_DBC_SERVEUR, "rb").read())
        open(ITEM_DBC_SERVEUR, "wb").write(neuf)
        print("  Item.dbc du serveur : %d objets (%d retires, %d ajoutes)"
              % (n, r, len(lignes)))

    rel, brut = lire_du_client("Item.dbc")
    neuf, n, r = refaire_item(brut)
    local = os.path.join(TRAVAIL, "Item.dbc")
    open(local, "wb").write(neuf)
    print("  Item.dbc du client (%s) : %d objets (%d retires, %d ajoutes)"
          % (rel, n, r, len(lignes)))
    if deployer:
        injecter(local, r"DBFilesClient\Item.dbc")

    # --- SkillLineAbility.dbc : l'onglet du grimoire -------------------------
    rel, brut = lire_du_client("SkillLineAbility.dbc")
    entete, enregs, chaines, nrec, nfield, rsize = decoupe(brut)
    par_sort = {}
    for i in range(nrec):
        off = i * rsize
        par_sort.setdefault(struct.unpack_from("<I", enregs, off + 2 * 4)[0],
                            enregs[off:off + rsize])
    enregs, nrec, retires = sans_les_notres(enregs, nrec, rsize,
                                            SLA_BASE, SLA_BASE + 9999)
    pose, orphelins = 0, 0
    for h in habillage:
        gab = par_sort.get(h["modele"])
        if gab is None:
            orphelins += 1
            continue
        for rang in h["rangs"]:
            rec = bytearray(gab)
            struct.pack_into("<I", rec, 0, SLA_BASE + pose)
            struct.pack_into("<I", rec, 2 * 4, rang)
            struct.pack_into("<I", rec, 8 * 4, 0)    # SupercededBySpell
            struct.pack_into("<I", rec, 9 * 4, 0)    # AcquireMethod
            enregs.extend(rec)
            nrec += 1
            pose += 1
    if orphelins:
        print("  %d sort(s) sans ligne de competence a cloner" % orphelins)
    local = os.path.join(TRAVAIL, "SkillLineAbility.dbc")
    open(local, "wb").write(recoud(entete, enregs, chaines, nrec, nfield, rsize))
    print("  SkillLineAbility.dbc (%s) : %d lignes (%d retirees, %d ajoutees)"
          % (rel, nrec, retires, pose))
    if deployer:
        injecter(local, r"DBFilesClient\SkillLineAbility.dbc")


donnees = json.load(io.open(SOURCE, encoding="utf-8"))

print("Spell.dbc du serveur")
lignes_sql, chaine_sql, runes, habillage = engendrer(DBC_SERVEUR, donnees, False)

print("Spell.dbc du client")
source_client = extraire_du_mpq()
engendrer(source_client, donnees, True)

ecrire_sql(chaine_sql, runes)

print("Habillage du client")
habiller(habillage, "--deploy" in sys.argv)
print("Rangs : %d sorts crees, %d entrees de chaine, %d runes"
      % (len(lignes_sql), len(chaine_sql), len(runes)))

if "--deploy" in sys.argv:
    injecter(os.path.join(TRAVAIL, "Spell.dbc"))
else:
    print("\nInjection dans le MPQ NON faite (ajouter --deploy). Jeu FERME requis.")
