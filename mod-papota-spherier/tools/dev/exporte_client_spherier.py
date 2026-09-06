# -*- coding: utf-8 -*-
r"""Exporte le CÔTÉ CLIENT de notre travail (sphérier + sorts de classe), pour le
package GitHub : les lignes de DBC et les fichiers (modèles, textures, sons,
icônes) que nous avons ajoutés au client, ni plus ni moins.

Méthode : FERMETURE TRANSITIVE depuis nos identifiants. On part des sorts de nos
plages (8500000-8549999 et 8600000-8619999), de nos objets (803xxx) et des
modèles de nos créatures (lus en base), puis on suit les références de table en
table (visuels, kits, effets, sons, icônes, affichages d'objets et de créatures,
chaînes, durées…) et de ligne en fichier (M2, .skin, .anim, BLP, sons). Une ligne
ou un fichier n'est retenu que s'il N'EST PAS dans le client Blizzard d'origine
(archives common/expansion/lichking/patch-*/locale-*) : le reste, un autre client
l'a déjà. Ce qui vient d'une autre archive custom de ce client (patch-a/b/c,
patch-frFR-z) est retenu aussi, et signalé : sans lui le montage serait cassé.

Sortie (dossier passé en argument, par défaut packages\export_client_spherier) :
    dbc_rows.json   toutes les lignes à poser, table par table, chaînes résolues
    files\...       les fichiers, sous leur chemin d'archive
    rapport.txt     ce qui a été retenu, ignoré, et les références cassées

    python exporte_client_spherier.py [dossier_sortie]
"""
import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import MYSQL_HOTE, MYSQL_PORT, MYSQL_UTILISATEUR, MYSQL_MDP, BASE_WORLD  # ce qui décrit le poste, hors du dépôt
import ctypes as C
import hashlib
import io
import json
import os
import shutil
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G  # noqa: E402
from gen_visuel_aube import stormlib  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")
BS = chr(92)
DATA = G.DATA
LOCALE = "frFR"
SORTIE = sys.argv[1] if len(sys.argv) > 1 else r"D:\Serveur WoW\packages\export_client_spherier"
MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"

# Nos plages d'identifiants.
PLAGES_SORTS = ((8500000, 8549999), (8600000, 8619999))
PLAGE_OBJETS = (803000, 803999)
PLAGE_CREATURES = (803800, 803899)
PLAGE_EMOTES = (990000, 990099)

# Archives Blizzard d'origine, de la plus prioritaire à la moins prioritaire.
STOCK = ["%s/patch-%s-3.mpq" % (LOCALE, LOCALE), "%s/patch-%s-2.mpq" % (LOCALE, LOCALE),
         "%s/patch-%s.mpq" % (LOCALE, LOCALE), "%s/lichking-locale-%s.mpq" % (LOCALE, LOCALE),
         "%s/expansion-locale-%s.mpq" % (LOCALE, LOCALE), "%s/locale-%s.mpq" % (LOCALE, LOCALE),
         "%s/lichking-speech-%s.mpq" % (LOCALE, LOCALE), "%s/expansion-speech-%s.mpq" % (LOCALE, LOCALE),
         "%s/speech-%s.mpq" % (LOCALE, LOCALE), "%s/base-%s.mpq" % (LOCALE, LOCALE),
         "patch-3.mpq", "patch-2.mpq", "patch.mpq", "lichking.mpq", "expansion.mpq", "common-2.mpq", "common.mpq"]
# Les archives customs de CE client, de la plus prioritaire à la moins : la nôtre en tête.
CUSTOM = ["patch-z.MPQ", "%s/patch-%s-z.mpq" % (LOCALE, LOCALE), "patch-c.mpq", "patch-b.mpq", "patch-a.mpq"]

# Colonnes portant une chaîne, par table (disposition 3.3.5, champs de 4 octets).
CHAINES = {
    "Spell.dbc": list(range(136, 152)) + list(range(153, 169)) + list(range(170, 186)) + list(range(187, 203)),
    "SpellVisualEffectName.dbc": [1, 2],
    "SoundEntries.dbc": [2] + list(range(3, 13)) + [23],
    "SpellIcon.dbc": [1],
    "ItemDisplayInfo.dbc": [1, 2, 3, 4, 5, 6] + list(range(15, 23)),
    "CreatureDisplayInfo.dbc": [6, 7, 8, 9],
    "CreatureModelData.dbc": [2],
    "Emotes.dbc": [1],
    "AnimationData.dbc": [1],
    "SpellShapeshiftForm.dbc": [1],
    "GameObjectDisplayInfo.dbc": [1],
    "SkillLine.dbc": list(range(3, 19)) + list(range(20, 36)) + list(range(37, 53)),
    "SpellRange.dbc": list(range(6, 22)) + list(range(23, 39)),
    "SpellVisual.dbc": [], "SpellVisualKit.dbc": [], "Item.dbc": [], "SkillLineAbility.dbc": [],
    "SpellDuration.dbc": [], "SpellRadius.dbc": [], "SpellCastTimes.dbc": [], "SpellCategory.dbc": [],
    "SpellVisualKitModelAttach.dbc": [], "SkillRaceClassInfo.dbc": [], "SpellMissile.dbc": [],
    "SpellMissileMotion.dbc": [1, 2], "SpellEffectCameraShakes.dbc": [], "SpellRuneCost.dbc": [],
    "SpellDescriptionVariables.dbc": [1], "CreatureDisplayInfoExtra.dbc": [20],
}
# Tables aux enregistrements non alignés sur 4 octets : traitées en brut, avec la
# position en OCTETS des décalages de chaîne.
BRUTES = {"SpellChainEffects.dbc": [28]}

# Références de table en table : colonne(s) -> table cible.
REFERENCES = {
    "Spell.dbc": [([1], "SpellCategory.dbc"), ([28], "SpellCastTimes.dbc"), ([40], "SpellDuration.dbc"),
                  ([46], "SpellRange.dbc"), ([92, 93, 94], "SpellRadius.dbc"), ([116, 117, 118], "Spell.dbc"),
                  ([107, 108, 109], "Item.dbc"), ([131, 132], "SpellVisual.dbc"), ([133, 134], "SpellIcon.dbc"),
                  ([227], "SpellMissile.dbc"), ([226], "SpellRuneCost.dbc"), ([232], "SpellDescriptionVariables.dbc")],
    "SpellVisual.dbc": [([1, 2, 3, 4, 5, 6, 14, 15, 22, 23, 24, 25], "SpellVisualKit.dbc"),
                        ([8], "SpellVisualEffectName.dbc"), ([11, 12], "SoundEntries.dbc"), ([21], "SpellMissileMotion.dbc")],
    "SpellVisualKit.dbc": [([1, 2], "AnimationData.dbc"), (list(range(3, 15)), "SpellVisualEffectName.dbc"),
                           ([15], "SoundEntries.dbc"), ([16], "SpellEffectCameraShakes.dbc")],
    "SpellVisualKitModelAttach.dbc": [([2], "SpellVisualEffectName.dbc")],
    "Item.dbc": [([5], "ItemDisplayInfo.dbc")],
    "ItemDisplayInfo.dbc": [([11], "SpellVisual.dbc")],
    "CreatureDisplayInfo.dbc": [([1], "CreatureModelData.dbc"), ([3], "CreatureDisplayInfoExtra.dbc")],
    "Emotes.dbc": [([2], "AnimationData.dbc"), ([6], "SoundEntries.dbc")],
    "SkillLineAbility.dbc": [([1], "SkillLine.dbc")],
}
AURA_FORME = 36  # SPELL_AURA_MOD_SHAPESHIFT : EffectMiscValue -> SpellShapeshiftForm
# Les lignes Blizzard que NOS outils retouchent (exception à la règle « rien de
# Blizzard n'est modifié ») : exportées avec leur version de patch-z.
MODIFIEES_A_NOUS = {"GameObjectDisplayInfo.dbc": {8500}}   # la Porte de la mort, gen_visuel_dk.pose_portail
# Nos sources d'art : un fichier Blizzard remplacé dans patch-z par l'un d'eux est
# une retouche à nous (texture ou modèle rétroporté sous son nom d'origine).
DOSSIERS_ART = [os.path.join(os.path.dirname(os.path.abspath(__file__)), d)
                for d in os.listdir(os.path.dirname(os.path.abspath(__file__))) if d.startswith("art_")]


class FIND(C.Structure):
    _fields_ = [("cFileName", C.c_char * 260), ("szPlainName", C.c_char_p), ("dwHashIndex", C.c_uint),
                ("dwBlockIndex", C.c_uint), ("dwFileSize", C.c_uint), ("dwFileFlags", C.c_uint),
                ("dwCompSize", C.c_uint), ("dwFileTimeLo", C.c_uint), ("dwFileTimeHi", C.c_uint), ("lcLocale", C.c_uint)]


class Archives:
    """Les archives du client, ouvertes en lecture seule, par priorité."""

    def __init__(self, dll):
        self.dll = dll
        dll.SFileHasFile.argtypes = [C.c_void_p, C.c_char_p]
        dll.SFileHasFile.restype = C.c_bool
        dll.SFileFindFirstFile.argtypes = [C.c_void_p, C.c_char_p, C.POINTER(FIND), C.c_wchar_p]
        dll.SFileFindFirstFile.restype = C.c_void_p
        dll.SFileFindNextFile.argtypes = [C.c_void_p, C.POINTER(FIND)]
        dll.SFileFindNextFile.restype = C.c_bool
        dll.SFileFindClose.argtypes = [C.c_void_p]
        self.stock, self.custom = [], []
        for liste, noms in ((self.stock, STOCK), (self.custom, CUSTOM)):
            for nom in noms:
                chemin = os.path.join(DATA, nom.replace("/", os.sep))
                if not os.path.exists(chemin):
                    continue
                h = C.c_void_p()
                if not dll.SFileOpenArchive(chemin, 0, 0x100, C.byref(h)):
                    raise SystemExit("archive illisible : " + chemin)
                liste.append((os.path.basename(chemin), h))
        # La liste des fichiers de patch-z, pour retrouver la casse et chercher par nom nu.
        self.noms_patchz = {}
        fd = FIND()
        hf = dll.SFileFindFirstFile(self.custom[0][1], b"*", C.byref(fd), None)
        while hf:
            nom = fd.cFileName.decode("latin-1")
            self.noms_patchz[nom.lower()] = nom
            if not dll.SFileFindNextFile(hf, C.byref(fd)):
                break
        dll.SFileFindClose(hf)

    def _lit(self, h, chemin):
        fh = C.c_void_p()
        if not self.dll.SFileOpenFileEx(h, chemin.encode("latin-1"), 0, C.byref(fh)):
            return None
        taille = self.dll.SFileGetFileSize(fh, None)
        tampon = C.create_string_buffer(max(taille, 1))
        lu = C.c_uint(0)
        ok = self.dll.SFileReadFile(fh, tampon, taille, C.byref(lu), None) if taille else True
        self.dll.SFileCloseFile(fh)
        return tampon.raw[:taille] if ok else None

    def lit(self, liste, chemin):
        """(archive, octets) depuis la première archive de la liste qui porte le fichier."""
        for nom, h in liste:
            if self.dll.SFileHasFile(h, chemin.encode("latin-1")):
                return nom, self._lit(h, chemin)
        return None, None

    def ferme(self):
        for _, h in self.stock + self.custom:
            self.dll.SFileCloseArchive(h)


class Table:
    """Un DBC lu : lignes par identifiant, chaînes résolues."""

    def __init__(self, brut):
        self.nrec, self.nfield, self.rsize, taille_chaines = struct.unpack_from("<4I", brut, 4)
        self.enr = brut[20:20 + self.nrec * self.rsize]
        self.chaines = brut[20 + self.nrec * self.rsize:20 + self.nrec * self.rsize + taille_chaines]
        self.lignes = {}
        for i in range(self.nrec):
            rec = self.enr[i * self.rsize:(i + 1) * self.rsize]
            self.lignes.setdefault(struct.unpack_from("<I", rec, 0)[0], rec)

    def chaine(self, off):
        if not off or off >= len(self.chaines):
            return ""
        fin = self.chaines.find(b"\x00", off)
        return self.chaines[off:fin].decode("utf-8", "replace")

    def champs(self, rec):
        return list(struct.unpack_from("<%dI" % (self.rsize // 4), rec, 0))


def dans_plage(ident, plage):
    return plage[0] <= ident <= plage[1]


def flottant(u):
    return struct.unpack("<f", struct.pack("<I", u))[0]


def main():
    dll = stormlib()
    arch = Archives(dll)
    rapport = []
    tables_eff, tables_stock = {}, {}

    def table(nom, ou):
        cache, liste = (tables_eff, arch.custom + arch.stock) if ou == "eff" else (tables_stock, arch.stock)
        if nom not in cache:
            src, brut = arch.lit(liste, "DBFilesClient" + BS + nom)
            cache[nom] = (src, Table(brut)) if brut else (None, None)
        return cache[nom]

    # --- 1. Les graines ---------------------------------------------------------------
    retenues = {}      # table -> {id: (archive, rec)}
    a_visiter = []     # (table, id)
    def retenir(nom, ident, pourquoi):
        if ident == 0 or ident == 0xFFFFFFFF:
            return
        if nom in retenues and ident in retenues[nom]:
            return
        src, t_eff = table(nom, "eff")
        if t_eff is None or ident not in t_eff.lignes:
            rapport.append("RÉFÉRENCE CASSÉE : %s %d (%s) absent du client" % (nom, ident, pourquoi))
            return
        _, t_stock = table(nom, "stock")
        rec = t_eff.lignes[ident]
        if t_stock is not None and ident in t_stock.lignes:
            if t_stock.lignes[ident] == rec:
                return  # ligne Blizzard intacte : rien à livrer
            if ident in MODIFIEES_A_NOUS.get(nom, ()):
                retenues.setdefault(nom, {})[ident] = (src, rec)  # notre retouche d'une ligne Blizzard
                a_visiter.append((nom, ident))
                return
            # Ligne Blizzard MODIFIÉE dans ce client par autre chose que nos outils
            # (retouches antérieures du client Papota) : non exportée, signalée.
            rapport.append("ligne Blizzard modifiée, NON exportée : %s %d (%s)" % (nom, ident, pourquoi))
            return
        retenues.setdefault(nom, {})[ident] = (src, rec)
        a_visiter.append((nom, ident))

    _, spell = table("Spell.dbc", "eff")
    for ident in sorted(spell.lignes):
        if any(dans_plage(ident, p) for p in PLAGES_SORTS):
            retenir("Spell.dbc", ident, "sort de nos plages")
    _, item = table("Item.dbc", "eff")
    for ident in sorted(item.lignes):
        if dans_plage(ident, PLAGE_OBJETS):
            retenir("Item.dbc", ident, "objet de notre plage")
    _, emotes = table("Emotes.dbc", "eff")
    for ident in sorted(emotes.lignes):
        if dans_plage(ident, PLAGE_EMOTES):
            retenir("Emotes.dbc", ident, "emote de notre plage")
    # Les modèles de nos créatures, lus en base.
    sortie = subprocess.run([MYSQL, "-h" + MYSQL_HOTE, "-P" + MYSQL_PORT, "-u" + MYSQL_UTILISATEUR, "-p" + MYSQL_MDP, "-N", BASE_WORLD, "-e",
                             "SELECT DISTINCT CreatureDisplayID FROM creature_template_model WHERE CreatureID BETWEEN %d AND %d"
                             % PLAGE_CREATURES], capture_output=True, text=True)
    for ligne in sortie.stdout.split():
        retenir("CreatureDisplayInfo.dbc", int(ligne), "modèle d'une de nos créatures")
    sortie = subprocess.run([MYSQL, "-h" + MYSQL_HOTE, "-P" + MYSQL_PORT, "-u" + MYSQL_UTILISATEUR, "-p" + MYSQL_MDP, "-N", BASE_WORLD, "-e",
                             "SELECT DISTINCT displayId FROM gameobject_template WHERE entry BETWEEN %d AND %d"
                             % PLAGE_CREATURES], capture_output=True, text=True)
    for ligne in sortie.stdout.split():
        retenir("GameObjectDisplayInfo.dbc", int(ligne), "affichage d'un de nos objets de monde")

    # --- 2. La fermeture sur les tables -----------------------------------------------
    nos_sorts = set(retenues.get("Spell.dbc", {}))
    while a_visiter:
        nom, ident = a_visiter.pop()
        src, t = table(nom, "eff")
        champs = t.champs(retenues[nom][ident][1]) if nom not in BRUTES else None
        if champs is None:
            continue
        for colonnes, cible in REFERENCES.get(nom, []):
            for col in colonnes:
                retenir(cible, champs[col], "référencé par %s %d col %d" % (nom, ident, col))
        if nom == "Spell.dbc":
            for k in range(3):
                if champs[95 + k] == AURA_FORME:
                    retenir("SpellShapeshiftForm.dbc", champs[110 + k], "forme du sort %d" % ident)
        if nom == "SpellVisualKit.dbc":
            # Les chaînes (SpellChainEffects) sont désignées en FLOTTANT dans les
            # paramètres de personnage du kit (CharParamZero[k]) quand CharProc[k] est posé.
            for k in range(4):
                if champs[17 + k] != 0xFFFFFFFF:
                    valeur = flottant(champs[21 + k])
                    if valeur and abs(valeur - round(valeur)) < 1e-3:
                        _, tc = table("SpellChainEffects.dbc", "eff")
                        if tc is not None and int(round(valeur)) in tc.lignes:
                            retenir("SpellChainEffects.dbc", int(round(valeur)), "chaîne du kit %d" % ident)
    # Références INVERSES : les lignes qui pointent vers les nôtres.
    _, sla = table("SkillLineAbility.dbc", "eff")
    for ident, rec in sla.lignes.items():
        if sla.champs(rec)[2] in nos_sorts:
            retenir("SkillLineAbility.dbc", ident, "onglet de grimoire d'un de nos sorts")
    nos_kits = set(retenues.get("SpellVisualKit.dbc", {}))
    _, attach = table("SpellVisualKitModelAttach.dbc", "eff")
    if attach is not None:
        for ident, rec in attach.lignes.items():
            if attach.champs(rec)[1] in nos_kits:
                retenir("SpellVisualKitModelAttach.dbc", ident, "attache d'un de nos kits")
    while a_visiter:  # ce que les inverses ont ajouté (skill lines, effets)
        nom, ident = a_visiter.pop()
        _, t = table(nom, "eff")
        champs = t.champs(retenues[nom][ident][1])
        for colonnes, cible in REFERENCES.get(nom, []):
            for col in colonnes:
                retenir(cible, champs[col], "référencé par %s %d col %d" % (nom, ident, col))
    nos_skills = set(retenues.get("SkillLine.dbc", {}))
    if nos_skills:
        _, srci = table("SkillRaceClassInfo.dbc", "eff")
        for ident, rec in srci.lignes.items():
            if srci.champs(rec)[1] in nos_skills:
                retenir("SkillRaceClassInfo.dbc", ident, "classes d'une de nos lignes de compétence")

    # --- 3. Les fichiers désignés par les lignes retenues -----------------------------
    fichiers_voulus = {}   # chemin normalisé (minuscules) -> pourquoi
    def vouloir(chemin, pourquoi):
        if not chemin:
            return
        chemin = chemin.replace("/", BS).strip()
        bas = chemin.lower()
        if bas.endswith(".mdx") or bas.endswith(".mdl"):
            bas = bas[:-4] + ".m2"
        fichiers_voulus.setdefault(bas, pourquoi)

    for nom, lignes in retenues.items():
        src, t = table(nom, "eff")
        for ident, (_, rec) in lignes.items():
            if nom in BRUTES:
                for pos in BRUTES[nom]:
                    ch = t.chaine(struct.unpack_from("<I", rec, pos)[0])
                    if ch:
                        vouloir(ch if ch.lower().endswith(".blp") else ch + ".blp", "%s %d" % (nom, ident))
                continue
            champs = t.champs(rec)
            texte = {col: t.chaine(champs[col]) for col in CHAINES.get(nom, [])}
            if nom == "SpellVisualEffectName.dbc":
                vouloir(texte[2], "effet %d" % ident)
            elif nom == "SoundEntries.dbc":
                base = texte[23]
                for k in range(3, 13):
                    if texte[k]:
                        vouloir(base + BS + texte[k] if base else texte[k], "son %d" % ident)
            elif nom == "SpellIcon.dbc":
                vouloir(texte[1] + ".blp", "icône %d" % ident)
            elif nom == "CreatureModelData.dbc":
                vouloir(texte[2], "modèle de créature %d" % ident)
            elif nom == "CreatureDisplayInfo.dbc":
                modele = table("CreatureModelData.dbc", "eff")[1]
                chemin_modele = modele.chaine(modele.champs(modele.lignes[champs[1]])[2]) if champs[1] in modele.lignes else ""
                dossier = chemin_modele.rsplit(BS, 1)[0] + BS if BS in chemin_modele else ""
                for col in (6, 7, 8):
                    if texte[col]:
                        vouloir(dossier + texte[col] + ".blp", "peau de l'affichage %d" % ident)
                if texte[9]:
                    vouloir("Interface" + BS + "Icons" + BS + texte[9] + ".blp", "portrait %d" % ident)
            elif nom == "ItemDisplayInfo.dbc":
                for col in (5, 6):
                    if texte[col]:
                        vouloir("Interface" + BS + "Icons" + BS + texte[col] + ".blp", "icône d'objet %d" % ident)
                for col in (1, 2, 3, 4):
                    if texte[col]:
                        # Les modèles et textures d'objet se cherchent par nom nu sous item\
                        fichiers_voulus.setdefault("?" + texte[col].lower(), "modèle/texture de l'affichage d'objet %d" % ident)
                for col in range(15, 23):
                    if texte[col]:
                        fichiers_voulus.setdefault("?" + texte[col].lower() + ".blp", "texture d'armure de l'affichage %d" % ident)
            elif nom == "GameObjectDisplayInfo.dbc":
                vouloir(texte[1], "modèle d'objet de monde %d" % ident)
    # Nos textures d'interface, par convention de nom.
    for bas, nom in arch.noms_patchz.items():
        if bas.startswith("interface" + BS + "papota" + BS):
            vouloir(nom, "art d'interface du sphérier")

    # Résolution des noms nus (objets) dans la liste de patch-z.
    for cle in [c for c in fichiers_voulus if c.startswith("?")]:
        pourquoi = fichiers_voulus.pop(cle)
        nu = cle[1:]
        candidats = [n for b, n in arch.noms_patchz.items() if b.rsplit(BS, 1)[-1] in (nu, nu.replace(".mdx", ".m2"), nu + ".m2", nu + ".blp")]
        if candidats:
            for c in candidats:
                vouloir(c, pourquoi)
        else:
            rapport.append("nom nu non trouvé dans patch-z (probablement Blizzard) : %s (%s)" % (nu, pourquoi))

    # Fermeture sur les M2 : textures, skins, animations externes.
    def contenu_effectif(bas):
        nom = arch.noms_patchz.get(bas)
        if nom is not None:
            return arch.lit(arch.custom, nom)
        src, brut = arch.lit(arch.custom, bas)
        if brut is None:
            src, brut = arch.lit(arch.stock, bas)
        return src, brut

    a_lire = list(fichiers_voulus)
    while a_lire:
        bas = a_lire.pop()
        if not bas.endswith(".m2"):
            continue
        src, brut = contenu_effectif(bas)
        if brut is None or brut[:4] != b"MD20":
            continue
        n_tex, ofs_tex = struct.unpack_from("<II", brut, 0x50)
        for i in range(n_tex):
            typ, flags, n_nom, ofs_nom = struct.unpack_from("<4I", brut, ofs_tex + i * 16)
            if typ == 0 and n_nom > 1 and ofs_nom < len(brut):
                # Lu comme une chaîne C (jusqu'au NUL) : le client fait de même, et
                # certains M2 convertis portent une longueur inexacte.
                nom_tex = brut[ofs_nom:ofs_nom + 512].split(b"\x00")[0].decode("latin-1")
                if nom_tex and nom_tex.lower() not in fichiers_voulus:
                    vouloir(nom_tex, "texture du modèle %s" % bas)
        n_vues = struct.unpack_from("<I", brut, 0x44)[0]
        base = bas[:-3]
        for v in range(n_vues):
            vouloir("%s%02d.skin" % (base, v), "skin du modèle %s" % bas)
        n_anim, ofs_anim = struct.unpack_from("<II", brut, 0x1C)
        for i in range(n_anim):
            anim_id, sub_id = struct.unpack_from("<HH", brut, ofs_anim + i * 64)
            flags = struct.unpack_from("<I", brut, ofs_anim + i * 64 + 12)[0]
            if not flags & 0x20:
                vouloir("%s%04d-%02d.anim" % (base, anim_id, sub_id), "animation externe du modèle %s" % bas)

    # --- 4. Ne livrer que ce qui n'est pas Blizzard -----------------------------------
    dossier_fichiers = os.path.join(SORTIE, "files")
    if os.path.isdir(dossier_fichiers):
        shutil.rmtree(dossier_fichiers)   # jamais de reste d'un export précédent
    os.makedirs(dossier_fichiers, exist_ok=True)
    empreintes_art = set()
    for dossier in DOSSIERS_ART:
        for racine, _, noms in os.walk(dossier):
            for n in noms:
                empreintes_art.add(hashlib.md5(open(os.path.join(racine, n), "rb").read()).hexdigest())
    livres, herites, blizzard, introuvables, ecrases, retouches = [], [], [], [], [], []
    for bas in sorted(fichiers_voulus):
        pourquoi = fichiers_voulus[bas]
        src_c, brut_c = contenu_effectif(bas)
        if brut_c is None and "." not in bas.rsplit(BS, 1)[-1]:
            bas_blp = bas + ".blp"          # nom de texture sans extension dans un M2 converti
            src_c, brut_c = contenu_effectif(bas_blp)
            if brut_c is not None:
                bas = bas_blp
        src_s, brut_s = arch.lit(arch.stock, bas)
        if brut_c is None and brut_s is None:
            introuvables.append("%s (%s)" % (bas, pourquoi))
            continue
        if brut_s is not None:
            # Le fichier existe chez Blizzard : un autre client l'a. S'il est remplacé
            # dans patch-z par une de NOS sources d'art (texture ou modèle rétroporté
            # sous son nom d'origine), ou s'il s'agit d'un modèle (.m2/.skin/.anim)
            # désigné par nos lignes, c'est notre retouche : on la livre. Un
            # remplacement venu d'une autre archive (modèle HD de patch-b) ou une
            # icône retail posée avant nous ne l'est pas.
            if brut_c is not None and brut_c != brut_s:
                notre = src_c == "patch-z.MPQ" and (hashlib.md5(brut_c).hexdigest() in empreintes_art
                                                    or bas.rsplit(".", 1)[-1] in ("m2", "skin", "anim"))
                if notre:
                    retouches.append(bas)
                else:
                    ecrases.append("%s (remplacé par %s)" % (bas, src_c))
                    continue
            else:
                blizzard.append(bas)
                continue
        if brut_c is None:
            blizzard.append(bas)
            continue
        if src_c not in (None, "patch-z.MPQ"):
            herites.append("%s (depuis %s)" % (bas, src_c))
        nom = arch.noms_patchz.get(bas, bas)
        cible = os.path.join(dossier_fichiers, *nom.split(BS))
        os.makedirs(os.path.dirname(cible), exist_ok=True)
        with open(cible, "wb") as f:
            f.write(brut_c)
        livres.append(nom)

    # --- 5. Le manifeste des lignes ---------------------------------------------------
    manifeste = {"_format": "papota-dbc-rows-1", "locale_source": LOCALE, "tables": {}}
    for nom in sorted(retenues):
        src, t = table(nom, "eff")
        entree = {"fields": t.rsize // 4 if nom not in BRUTES else None, "record_size": t.rsize,
                  "string_columns": CHAINES.get(nom, []) if nom not in BRUTES else None,
                  "string_offsets": BRUTES.get(nom), "rows": []}
        for ident in sorted(retenues[nom]):
            src_l, rec = retenues[nom][ident]
            if nom in BRUTES:
                entree["rows"].append({"id": ident, "raw": rec.hex(),
                                       "strings": {str(pos): t.chaine(struct.unpack_from("<I", rec, pos)[0]) for pos in BRUTES[nom]}})
            else:
                champs = t.champs(rec)
                chaines = {str(col): t.chaine(champs[col]) for col in CHAINES.get(nom, []) if champs[col]}
                if nom not in CHAINES:
                    # Table sans disposition connue : on vérifie qu'aucun champ ne ressemble à une chaîne.
                    for col, v in enumerate(champs):
                        if col and 0 < v < len(t.chaines) and t.chaines[v - 1:v] == b"\x00" and t.chaine(v):
                            rapport.append("ATTENTION %s %d : le champ %d ressemble à une chaîne (%r), disposition à décrire" % (nom, ident, col, t.chaine(v)[:30]))
                entree["rows"].append({"id": ident, "ints": champs, "strings": chaines})
        manifeste["tables"][nom] = entree
    with io.open(os.path.join(SORTIE, "dbc_rows.json"), "w", encoding="utf-8") as f:
        json.dump(manifeste, f, ensure_ascii=False, indent=1)

    # --- 6. Le rapport ----------------------------------------------------------------
    lignes = ["EXPORT CLIENT DU SPHÉRIER — %s" % SORTIE, ""]
    lignes.append("Lignes de DBC retenues :")
    for nom in sorted(retenues):
        srcs = sorted({s for s, _ in retenues[nom].values()})
        lignes.append("  %-32s %5d  (%s)" % (nom, len(retenues[nom]), ", ".join(srcs)))
    lignes.append("")
    lignes.append("Fichiers livrés : %d" % len(livres))
    lignes.append("Fichiers désignés mais Blizzard (non livrés) : %d" % len(blizzard))
    lignes.append("Fichiers hérités d'une autre archive custom : %d" % len(herites))
    for h in herites:
        lignes.append("  " + h)
    lignes.append("Fichiers Blizzard que nos outils remplacent (livrés, version de patch-z) : %d" % len(retouches))
    for r in retouches:
        lignes.append("  " + r)
    lignes.append("Fichiers Blizzard remplacés dans ce client par autre chose que nous (non livrés) : %d" % len(ecrases))
    for e in ecrases:
        lignes.append("  " + e)
    lignes.append("Fichiers introuvables : %d" % len(introuvables))
    for i in introuvables:
        lignes.append("  " + i)
    lignes.append("")
    lignes.append("Remarques (%d) :" % len(rapport))
    lignes.extend("  " + r for r in rapport)
    lignes.append("")
    lignes.append("Fichiers livrés :")
    lignes.extend("  " + l for l in livres)
    with io.open(os.path.join(SORTIE, "rapport.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lignes) + "\n")
    print("\n".join(lignes[:lignes.index("Fichiers livrés :")]))
    arch.ferme()


if __name__ == "__main__":
    main()
