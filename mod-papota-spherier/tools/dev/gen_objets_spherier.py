# -*- coding: utf-8 -*-
r"""Objets du sphèrier — pierres, Nexus et épingle de l'oubli (jalon 3).

Produit le SQL du module dans
  azerothcore-wotlk\modules\mod-papota-spherier\data\sql\world\

Rien n'est écrit à la main : les 80 pierres sont le produit du catalogue des
16 statistiques par les 5 qualités, avec l'allocation d'entrées figée dans
SPHERIER_CONCEPTION.md §8 :

    pierre = 803100 + (stat - 1) * 5 + (qualite - 1)

Les noms par défaut sont en ANGLAIS (item_template), le français vit dans
item_template_locale — même règle que les messages du module. L'effet chiffré
d'une pierre n'est pas dans son nom mais dans la table papota_sphere_stone,
rechargeable par .spherier reload.
"""

import io
import os
import sys

SORTIE = (r"D:\Serveur WoW\azerothcore-wotlk\modules\mod-papota-spherier"
          r"\data\sql\world\2026_08_24_00_mod_papota_spherier_objets.sql")

PIERRE_BASE = 803100
SPHERE_BASE = 803200
EPINGLE     = 803300
# Runes de statistique : une par statistique du catalogue, 803600 a 803615.
# La plage 803400-803599 appartient aux runes de RANG (gen_rangs_sorts.py) :
# on n'y touche pas, et les DELETE d'ici la sautent.
RUNE_STAT_BASE = 803600
# Le pourcentage est ecrit en base et relu par .spherier reload ; cette
# valeur-ci n'est que la graine du fichier SQL.
RUNE_STAT_PCT = 10
DISPLAY_RUNE_STAT = 20984      # INV_Misc_Rune_06 : un galet grave

# (clé, nom EN, fragment FR — préposition comprise)
STATS = [
    ("endurance",          "Stamina",           "d'Endurance"),
    ("intelligence",       "Intellect",         "d'Intelligence"),
    ("esprit",             "Spirit",            "d'Esprit"),
    ("dexterite",          "Agility",           "de Dextérité"),
    ("force",              "Strength",          "de Force"),
    ("parade",             "Parry",             "de Parade"),
    ("blocage",            "Block",             "de Blocage"),
    ("esquive",            "Dodge",             "d'Esquive"),
    ("hate",               "Haste",             "de Hâte"),
    ("critique",           "Critical Strike",   "de Critique"),
    ("touche",             "Hit",               "de Toucher"),
    ("puissance_sorts",    "Spell Power",       "de Puissance des sorts"),
    ("puissance_attaque",  "Attack Power",      "de Puissance d'attaque"),
    ("penetration_armure", "Armor Penetration", "de Pénétration d'armure"),
    ("expertise",          "Expertise",         "d'Expertise"),
    ("bonus_soins",        "Healing",           "de Soins"),
]

# (nom EN, nom FR, bonus, identifiant d'affichage) — bonus arrêtés au §7, ce ne
# sont PAS des sentinelles.
#
# NE PAS y toucher pour régler le volume de statistiques : c'est la RÉPARTITION
# DES QUALITÉS qui s'en charge (voir regle_pierres.py, PARTS). Un essai du
# 2026-08-27 les avait ramenés à 3/4/6/9/18 pour faire baisser les totaux ; c'est
# le mauvais levier, et il a été annulé.
QUALITES = [
    ("Common",    "Commune",    5,  6673),
    ("Uncommon",  "Uncommon",   7,  1262),
    ("Rare",      "Rare",       10, 7053),
    ("Epic",      "Épique",     15, 4777),
    ("Legendary", "Légendaire", 30, 4777),
]
QUALITE_FR = ["Commune", "Inhabituelle", "Rare", "Épique", "Légendaire"]

# Les objets qui octroient de la Spherite ne s'appellent pas « sphères » mais
# NEXUS, nommés par intensité croissante (décision du 2026-08-24). Les montants
# vivent dans le sort d'utilisation, voir gen_sorts_spherier.py.
NEXUS_EN = ["Depleted Nexus", "Flickering Nexus", "Luminous Nexus",
            "Irradiant Nexus", "Solar Nexus"]
NEXUS_FR = ["Nexus appauvri", "Nexus vacillant", "Nexus lumineux",
            "Nexus irradiant", "Nexus solaire"]

DISPLAY_SPHERE  = 22923      # Arcane Orb
DISPLAY_EPINGLE = 21207      # Runed Copper Rod

# LE SORT D'UTILISATION D'UN NEXUS, écrit ICI et non plus laissé à un autre
# fichier (2026-09-04). Il y avait une valeur d'attente — le « Dummy Spell »
# 18282 — que `2026_08_24_02_..._sorts_sphere.sql` corrigeait ensuite par cinq
# UPDATE.
#
# CE MONTAGE A CASSÉ, et il ne pouvait que casser : l'updater rejoue un fichier
# dont l'empreinte a changé, et lui seul. Le _00_ a été retouché puis rejoué le
# 2026-08-27, trois jours après le _02_ ; son INSERT a remis le bouche-trou, le
# _02_ n'a pas été rejoué faute d'avoir changé, et PLUS AUCUN NEXUS N'ÉTAIT
# UTILISABLE pendant une semaine.
#
# La règle qu'on en tire : UN FICHIER GÉNÉRÉ DOIT SE SUFFIRE À LUI-MÊME. Aucun
# ordre d'application ne doit être supposé entre deux fichiers du module.
#
# Les cinq sorts (8500001-8500005) sont produits par gen_sorts_spherier.py dans
# l'ordre des qualités et portent chacun son montant de Spherite.
SORT_NEXUS_BASE = 8500001

L = []
DBC = []          # lignes de item_dbc, voir plus bas

def ligne(s=""):
    L.append(s)


def sql(t):
    return t.replace("\\", "\\\\").replace("'", "''")


ligne("-- mod-papota-spherier : objets du jalon 3 — pierres, Nexus, épingle.")
ligne("-- GÉNÉRÉ par outils_spherier\\gen_objets_spherier.py, ne pas éditer à la main.")
ligne("-- Entrées : pierres 803100-803179, Nexus 803200-803205, épingle 803300,")
ligne("-- runes de statistique 803600-803615.")
ligne()

# --- schéma ----------------------------------------------------------------
ligne("""CREATE TABLE IF NOT EXISTS `papota_sphere_stone` (
  `item_entry` INT UNSIGNED NOT NULL,
  `stat_id` TINYINT UNSIGNED NOT NULL COMMENT 'rang dans le catalogue des 16 statistiques',
  `amount` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : effet chiffre d une pierre, rechargeable';

CREATE TABLE IF NOT EXISTS `papota_sphere_config` (
  `cle` VARCHAR(32) NOT NULL,
  `valeur` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`cle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : reglages du module, rechargeables';

REPLACE INTO `papota_sphere_config` (`cle`, `valeur`) VALUES ('epingle_entry', %d);

-- Une rune de statistique majore ce que la GRILLE donne dans cette
-- statistique : elle s'applique sur la somme des pierres, jamais sur une
-- valeur brute. Le pourcentage vit ici, pas dans le code (§3).
CREATE TABLE IF NOT EXISTS `papota_sphere_stat_rune` (
  `item_entry` INT UNSIGNED NOT NULL,
  `stat_id` TINYINT UNSIGNED NOT NULL COMMENT 'rang dans le catalogue des 16 statistiques',
  `percent` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'majoration en %%, cumulable',
  PRIMARY KEY (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Spherier Papota : rune de statistique, rechargeable';
""" % EPINGLE)

# --- pierres ---------------------------------------------------------------
entrees_pierres = []
lignes_item, lignes_locale, lignes_effet = [], [], []

for si, (cle, nom_en, frag_fr) in enumerate(STATS, start=1):
    for qi, (q_en, _q_fr, bonus, display) in enumerate(QUALITES, start=1):
        entry = PIERRE_BASE + (si - 1) * 5 + (qi - 1)
        entrees_pierres.append(entry)
        nom = "%s Stone of %s" % (q_en, nom_en)
        nom_fr = "Pierre %s (%s)" % (frag_fr, QUALITE_FR[qi - 1])
        desc = "+%d %s. Socket it into a node of your sphere grid." % (bonus, nom_en)
        desc_fr = "+%d %s. À sertir dans un nœud de votre sphèrier." % (bonus, frag_fr.split(" ", 1)[-1])
        lignes_item.append(
            "(%d, 3, 0, '%s', %d, %d, 0, 1, 0, 0, 0, 1, 1, 0, 20, 0, '%s', '', 0, 0)"
            % (entry, sql(nom), display, qi, sql(desc)))
        lignes_locale.append("(%d, 'frFR', '%s', '%s')" % (entry, sql(nom_fr), sql(desc_fr)))
        lignes_effet.append("(%d, %d, %d)" % (entry, si, bonus))
        DBC.append("(%d, 3, 0, -1, 0, %d, 0, 0)" % (entry, display))

# --- runes de statistique --------------------------------------------------
# « de Force » -> « Force », « d'Endurance » -> « Endurance ». On tourne la
# phrase avec « en » (« accorde en Endurance ») : cela evite d'avoir a gerer le
# genre et l'elision pour seize libelles.
def nom_simple(frag):
    if frag.startswith("d'"):
        return frag[2:]
    if frag.startswith("de "):
        return frag[3:]
    return frag


entrees_runes_stat, lignes_rune_stat = [], []
for si, (cle, nom_en, frag_fr) in enumerate(STATS, start=1):
    entry = RUNE_STAT_BASE + (si - 1)
    entrees_runes_stat.append(entry)
    simple = nom_simple(frag_fr)
    nom = "Rune of %s" % nom_en
    nom_fr = "Rune %s" % frag_fr
    desc = ("Increases by %d%% what your sphere grid grants in %s. "
            "Three at most per statistic." % (RUNE_STAT_PCT, nom_en))
    desc_fr = ("Augmente de %d %% ce que votre sphèrier accorde en %s. "
               "Trois au maximum par statistique." % (RUNE_STAT_PCT, simple))
    lignes_item.append(
        "(%d, 3, 0, '%s', %d, 4, 0, 1, 0, 0, 0, 1, 1, 0, 20, 0, '%s', '', 0, 0)"
        % (entry, sql(nom), DISPLAY_RUNE_STAT, sql(desc)))
    lignes_locale.append("(%d, 'frFR', '%s', '%s')" % (entry, sql(nom_fr), sql(desc_fr)))
    lignes_rune_stat.append("(%d, %d, %d)" % (entry, si, RUNE_STAT_PCT))
    DBC.append("(%d, 3, 0, -1, 0, %d, 0, 0)" % (entry, DISPLAY_RUNE_STAT))

# --- Nexus -----------------------------------------------------------------
entrees_nexus = []
for qi, (q_en, _q_fr, _bonus, _display) in enumerate(QUALITES, start=1):
    entry = SPHERE_BASE + (qi - 1)
    entrees_nexus.append(entry)
    nom = NEXUS_EN[qi - 1]
    nom_fr = NEXUS_FR[qi - 1]
    desc = "A knot of raw Spherite, ready to be absorbed."
    desc_fr = "Un nœud de Spherite brute, prêt à être absorbé."
    lignes_item.append(
        "(%d, 0, 0, '%s', %d, %d, 0, 1, 0, 0, 0, 1, 1, 0, 20, 0, '%s', '', %d, 0)"
        % (entry, sql(nom), DISPLAY_SPHERE, qi, sql(desc),
           SORT_NEXUS_BASE + (qi - 1)))
    lignes_locale.append("(%d, 'frFR', '%s', '%s')" % (entry, sql(nom_fr), sql(desc_fr)))
    DBC.append("(%d, 0, 0, -1, 0, %d, 0, 0)" % (entry, DISPLAY_SPHERE))

# --- Nexus prismatique (2026-09-06) -----------------------------------------
# Artefact (qualité 6, niveau d'objet 999) : chaque utilisation majore de 25 %
# TOUS les gains de Spherite du COMPTE, sans plafond. Détruit à l'usage comme
# un Nexus ; son sort 8500006 appelle spell_spherier_prisme. Lié quand ramassé
# (bonding 1) : l'effet étant au compte, l'objet n'a pas à circuler.
NEXUS_PRISME = SPHERE_BASE + 5
entrees_nexus.append(NEXUS_PRISME)
lignes_item.append(
    "(%d, 0, 0, '%s', %d, 6, 0, 1, 0, 0, 0, 999, 1, 1, 20, 0, '%s', '', %d, 0)"
    % (NEXUS_PRISME, sql("Prismatic Nexus"), DISPLAY_SPHERE,
       "",      # pas de texte d'ambiance : l'effet du sort dit tout (2026-09-06)
       SORT_NEXUS_BASE + 5))
lignes_locale.append(
    "(%d, 'frFR', '%s', '%s')"
    % (NEXUS_PRISME, sql("Nexus prismatique"), ""))
DBC.append("(%d, 0, 0, -1, 0, %d, 0, 0)" % (NEXUS_PRISME, DISPLAY_SPHERE))

# --- épingle de l'oubli ----------------------------------------------------
lignes_item.append(
    "(%d, 0, 0, '%s', %d, 4, 0, 1, 0, 0, 0, 1, 1, 0, 20, 0, '%s', '', 0, 0)"
    % (EPINGLE, sql("Pin of Oblivion"), DISPLAY_EPINGLE,
       sql("Empties a cell of your sphere grid. What it held is destroyed.")))
lignes_locale.append(
    "(%d, 'frFR', '%s', '%s')"
    % (EPINGLE, sql("Épingle de l'oubli"),
       sql("Vide un emplacement du sphèrier. Ce qu'il contenait est détruit.")))
DBC.append("(%d, 0, 0, -1, 0, %d, 0, 0)" % (EPINGLE, DISPLAY_EPINGLE))

# --- écriture --------------------------------------------------------------
toutes = entrees_pierres + entrees_nexus + [EPINGLE]
ligne("DELETE FROM `item_template` WHERE `entry` BETWEEN %d AND %d;" % (PIERRE_BASE, EPINGLE))
ligne("DELETE FROM `item_template_locale` WHERE `ID` BETWEEN %d AND %d;" % (PIERRE_BASE, EPINGLE))
ligne("DELETE FROM `papota_sphere_stone` WHERE `item_entry` BETWEEN %d AND %d;" % (PIERRE_BASE, EPINGLE))
ligne("DELETE FROM `papota_sphere_item` WHERE `item_entry` BETWEEN %d AND %d;" % (PIERRE_BASE, EPINGLE))
# Plage a part : entre les deux vivent les runes de RANG, qui ne sont pas a nous.
ligne("DELETE FROM `item_template` WHERE `entry` BETWEEN %d AND %d;"
      % (RUNE_STAT_BASE, RUNE_STAT_BASE + 99))
ligne("DELETE FROM `item_template_locale` WHERE `ID` BETWEEN %d AND %d;"
      % (RUNE_STAT_BASE, RUNE_STAT_BASE + 99))
ligne("DELETE FROM `papota_sphere_stat_rune` WHERE `item_entry` BETWEEN %d AND %d;"
      % (RUNE_STAT_BASE, RUNE_STAT_BASE + 99))
ligne()

ligne("INSERT INTO `item_template`")
ligne("  (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyCount`,")
ligne("   `BuyPrice`, `SellPrice`, `InventoryType`, `ItemLevel`, `RequiredLevel`, `bonding`,")
ligne("   `stackable`, `MaxDurability`, `description`, `ScriptName`,")
ligne("   `spellid_1`, `spelltrigger_1`) VALUES")
ligne(",\n".join(lignes_item) + ";")
ligne()

# UNE CHARGE, et l'objet part avec elle. La colonne ne peut pas entrer dans
# l'INSERT ci-dessus : elle vaudrait -1 pour les Nexus et 0 pour tout le reste.
# On la pose donc a part, sur les seuls Nexus — mais DANS CE FICHIER, pour qu'il
# se suffise a lui-meme.
ligne("-- Un Nexus se consomme comme une potion : une charge, et l'objet part.")
ligne("UPDATE `item_template` SET `spellcharges_1` = -1")
ligne("  WHERE `entry` BETWEEN %d AND %d;" % (SPHERE_BASE, SPHERE_BASE + 5))
ligne()

ligne("INSERT INTO `item_template_locale` (`ID`, `locale`, `Name`, `Description`) VALUES")
ligne(",\n".join(lignes_locale) + ";")
ligne()

ligne("INSERT INTO `papota_sphere_stone` (`item_entry`, `stat_id`, `amount`) VALUES")
ligne(",\n".join(lignes_effet) + ";")
ligne()

ligne("INSERT INTO `papota_sphere_stat_rune` (`item_entry`, `stat_id`, `percent`) VALUES")
ligne(",\n".join(lignes_rune_stat) + ";")
ligne()

ligne("-- La Spherite d'un Nexus ne vit PAS ici : elle est portée par son sort")
ligne("-- d'utilisation (EffectBasePoints), affichée par $s1 dans l'infobulle et lue")
ligne("-- par le script. Une seule valeur, définie dans gen_sorts_spherier.py.")
ligne()

# --- Item.dbc -------------------------------------------------------------
# SANS CECI LES OBJETS N'EXISTENT PAS : ObjectMgr::LoadItemTemplates IGNORE
# purement et simplement toute entrée d'item_template absente d'Item.dbc
# (le `continue` de ObjectMgr.cpp, sur un simple LOG_DEBUG). AzerothCore
# charge ce DBC AVEC une table de surcharge SQL — `LOAD_DBC(sItemStore,
# "Item.dbc", "item_dbc")` —, ce qui évite d'éditer le fichier binaire : les
# entrées ajoutées ici survivent donc à une ré-extraction des DBC.
# Les valeurs reflètent exactement item_template : sans quoi, si
# `enforceDBCAttributes` est actif, le cœur les corrigerait en journalisant
# une erreur à chaque démarrage. Les identifiants d'affichage sont ceux
# d'objets existants, donc déjà présents dans ItemDisplayInfo.dbc du client.
ligne("DELETE FROM `item_dbc` WHERE `ID` BETWEEN %d AND %d;" % (PIERRE_BASE, EPINGLE))
# Les runes de statistique vivent au-dela : sans ce second DELETE, toute
# re-application du fichier echoue sur une cle primaire dupliquee.
ligne("DELETE FROM `item_dbc` WHERE `ID` BETWEEN %d AND %d;"
      % (RUNE_STAT_BASE, RUNE_STAT_BASE + 99))
ligne("INSERT INTO `item_dbc`")
ligne("  (`ID`, `ClassID`, `SubclassID`, `Sound_Override_Subclassid`, `Material`,")
ligne("   `DisplayInfoID`, `InventoryType`, `SheatheType`) VALUES")
ligne(",\n".join(DBC) + ";")

os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
with io.open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(L) + "\n")

print("SQL écrit :", SORTIE)
print("  %d pierres, %d Nexus, 1 épingle, %d runes de statistique — %d objets."
      % (len(entrees_pierres), len(entrees_nexus), len(entrees_runes_stat),
         len(toutes) + len(entrees_runes_stat)))


# --- Item.dbc : serveur ET client -------------------------------------------
#
# LE CLIENT EN A BESOIN AUSSI. Il ne se sert pas de l'identifiant d'affichage
# que le serveur lui envoie : il résout l'apparence d'un objet par SON PROPRE
# Item.dbc. Un objet absent de ce fichier s'affiche avec le point
# d'interrogation rouge, même si tout le reste est correct — c'est ce qui est
# arrivé aux Nexus. Les 247 objets customs du serveur y sont déjà, dans
# patch-z.MPQ : nos entrées vont au même endroit.
#
# Côté serveur, la table `item_dbc` suffirait au cœur, mais la convention est
# que les objets customs vivent dans le DBC lui-même. Les deux dépôts sortent
# d'ici, ils ne peuvent donc pas diverger.
#
# Format : 8 champs de 4 octets, aucune chaîne.

import struct

DBC_SERVEUR = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc\Item.dbc"
# Le dossier du client se CHERCHE, version comprise (2026-09-06) : ecrit en dur,
# il avait fait echouer l'injection en silence au renommage 1.1.0 -> 1.2.0.
from gen_sorts_classes import dossier_client as _dossier_client
ARCHIVE_CLIENT = os.path.join(_dossier_client(), "patch-z.MPQ")
NOM_DBC = r"DBFilesClient\Item.dbc"
DLL = r"D:\Serveur WoW\tools\StormLib_build\Release\StormLib.dll"

NOTRES = [[int(x) for x in ligne.strip("()").split(",")] for ligne in DBC]


def refaire_item_dbc(brut):
    """Retire nos entrées si elles y sont, puis les (ré)ajoute à la fin."""
    if brut[:4] != b"WDBC":
        raise ValueError("format inattendu")

    nrec, nfield, rsize, ssize = struct.unpack_from("<4I", brut, 4)
    debut_str = 20 + nrec * rsize
    recs = bytearray(brut[20:debut_str])
    chaines = brut[debut_str:debut_str + ssize]

    ids = set(c[0] for c in NOTRES)
    garde, retires = bytearray(), 0
    for i in range(nrec):
        off = i * rsize
        if struct.unpack_from("<I", recs, off)[0] in ids:
            retires += 1
            continue
        garde.extend(recs[off:off + rsize])
    recs = garde
    nrec -= retires

    for champs in NOTRES:
        rec = bytearray(rsize)
        for k, v in enumerate(champs[:nfield]):
            struct.pack_into("<i", rec, k * 4, v)
        recs.extend(rec)
        nrec += 1

    entete = bytearray(brut[:20])
    struct.pack_into("<4I", entete, 4, nrec, nfield, rsize, ssize)
    return bytes(entete) + bytes(recs) + chaines, nrec, retires


def sauver(chemin):
    s = chemin + ".avant_spherier"
    if not os.path.exists(s):
        import shutil
        shutil.copyfile(chemin, s)
        print("  sauvegarde :", s)


# serveur
if os.path.exists(DBC_SERVEUR):
    neuf, n, r = refaire_item_dbc(open(DBC_SERVEUR, "rb").read())
    sauver(DBC_SERVEUR)
    with open(DBC_SERVEUR, "wb") as f:
        f.write(neuf)
    print("Item.dbc du serveur : %d objets (%d remplacés, %d ajoutés)" % (n, r, len(NOTRES)))

# client — le jeu doit être FERMÉ, une archive ouverte est verrouillée
if "--deploy" in sys.argv:
    import ctypes as C

    st = C.WinDLL(DLL)
    st.SFileOpenArchive.argtypes = [C.c_wchar_p, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    st.SFileOpenArchive.restype = C.c_bool
    st.SFileCloseArchive.argtypes = [C.c_void_p]
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

    h = C.c_void_p()
    if not st.SFileOpenArchive(ARCHIVE_CLIENT, 0, 0x100, C.byref(h)):
        raise SystemExit("lecture impossible : " + ARCHIVE_CLIENT)
    fh = C.c_void_p()
    if not st.SFileOpenFileEx(h, NOM_DBC.encode("latin-1"), 0, C.byref(fh)):
        raise SystemExit("Item.dbc absent de l'archive client")
    hi = C.c_uint(0)
    t = st.SFileGetFileSize(fh, C.byref(hi))
    buf = C.create_string_buffer(t)
    lu = C.c_uint(0)
    st.SFileReadFile(fh, buf, t, C.byref(lu), None)
    st.SFileCloseFile(fh)
    st.SFileCloseArchive(h)

    neuf, n, r = refaire_item_dbc(buf.raw[:lu.value])
    sauver(ARCHIVE_CLIENT)

    h = C.c_void_p()
    if not st.SFileOpenArchive(ARCHIVE_CLIENT, 0, 0, C.byref(h)):
        raise SystemExit("écriture impossible — le jeu est-il fermé ?")
    try:
        fh = C.c_void_p()
        if not st.SFileCreateFile(h, NOM_DBC.encode("latin-1"), 0, len(neuf), 0,
                                  0x00000200 | 0x80000000, C.byref(fh)):
            raise SystemExit("SFileCreateFile a échoué")
        b = C.create_string_buffer(neuf, len(neuf))
        if not st.SFileWriteFile(fh, b, len(neuf), 0x02):
            raise SystemExit("SFileWriteFile a échoué")
        st.SFileFinishFile(fh)
        print("Item.dbc du client : %d objets (%d remplacés, %d ajoutés) -> %s"
              % (n, r, len(NOTRES), os.path.basename(ARCHIVE_CLIENT)))
    finally:
        st.SFileCloseArchive(h)
else:
    print("\nItem.dbc du CLIENT non injecté (ajouter --deploy). Jeu FERMÉ requis.")
