# -*- coding: utf-8 -*-
r"""mod-papota-spherier — construit le patch CLIENT (et, au besoin, les DBC du serveur).

Le module ajoute au jeu des sorts, des objets, des visuels, des sons, des icônes
et l'art de son interface. Le serveur lit tout cela en base (spell_dbc, item_dbc)
ou dans ses propres fichiers ; le client, lui, ne connaît que ses archives MPQ.
Cet outil fabrique `Data\patch-<lettre>.MPQ` pour un client 3.3.5a (12340) de
N'IMPORTE QUELLE langue :

  1. il lit les DBC EFFECTIFS du client (l'archive la plus prioritaire qui porte
     chaque fichier, vos patchs customs compris — nos lignes s'AJOUTENT aux vôtres) ;
  2. il y pose nos lignes, décrites dans dbc_rows.json (les chaînes sont
     re-poolées, les identifiants existants remplacés) ;
  3. il y range tous les fichiers du dossier files\ ;
  4. il relit l'archive produite et vérifie que tout y est.

    python build_client_patch.py <dossier du jeu>            (patch-S.MPQ par défaut)
    python build_client_patch.py <dossier du jeu> --lettre Z
    python build_client_patch.py --serveur <dossier Data\dbc du serveur>

Le dossier du jeu est celui qui contient Wow.exe et Data\. Fermez le jeu avant :
il verrouille ses archives. Relancé, l'outil reconstruit l'archive de zéro (il
ne lit jamais sa propre sortie). La lettre doit trier APRÈS vos autres patchs,
le client charge dans l'ordre alphabétique et le dernier gagne.

--serveur : AzerothCore charge SpellDuration, Emotes, CreatureDisplayInfo et
CreatureModelData depuis ses fichiers Data\dbc (il n'a pas de table SQL pour
eux) : l'option pose nos lignes dans ces quatre fichiers, après une copie
`.avant_spherier`. Les sorts et objets du serveur viennent du SQL du module.

Prérequis : Python 3.8+ (64 bits) et StormLib.dll (fournie) à côté du script.
"""
import ctypes as C
import io
import json
import os
import shutil
import struct
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
MANIFESTE = os.path.join(ICI, "dbc_rows.json")
FICHIERS = os.path.join(ICI, "files")
DLL = os.path.join(ICI, "StormLib.dll")
BS = "\\"

TABLES_SERVEUR = ("SpellDuration.dbc", "Emotes.dbc", "CreatureDisplayInfo.dbc", "CreatureModelData.dbc")

# Ordre de chargement du client : Blizzard d'abord, puis les patchs customs par
# suffixe croissant ; pour un même suffixe, l'archive de Data\ l'emporte sur
# celle du dossier de langue.
BASE = ["common.mpq", "common-2.mpq", "expansion.mpq", "lichking.mpq", "patch.mpq", "patch-2.mpq", "patch-3.mpq"]
LOCALE = ["locale-{l}.mpq", "expansion-locale-{l}.mpq", "lichking-locale-{l}.mpq", "patch-{l}.mpq", "patch-{l}-2.mpq", "patch-{l}-3.mpq"]
SUFFIXES = [str(n) for n in range(4, 10)] + [chr(c) for c in range(ord("a"), ord("z") + 1)]

MPQ_OPEN_READ_ONLY = 0x00000100
MPQ_CREATE_LISTFILE = 0x00100000
MPQ_CREATE_ATTRIBUTES = 0x00200000
MPQ_CREATE_ARCHIVE_V2 = 0x01000000
MPQ_FILE_COMPRESS = 0x00000200
MPQ_FILE_REPLACEEXISTING = 0x80000000
MPQ_COMPRESSION_ZLIB = 0x02


class Erreur(Exception):
    pass


def stormlib():
    if not os.path.isfile(DLL):
        raise Erreur("StormLib.dll introuvable à côté du script : " + DLL)
    dll = C.WinDLL(DLL)
    dll.SFileOpenArchive.argtypes = [C.c_wchar_p, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    dll.SFileOpenArchive.restype = C.c_bool
    dll.SFileCreateArchive.argtypes = [C.c_wchar_p, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    dll.SFileCreateArchive.restype = C.c_bool
    dll.SFileCloseArchive.argtypes = [C.c_void_p]
    dll.SFileHasFile.argtypes = [C.c_void_p, C.c_char_p]
    dll.SFileHasFile.restype = C.c_bool
    dll.SFileOpenFileEx.argtypes = [C.c_void_p, C.c_char_p, C.c_uint, C.POINTER(C.c_void_p)]
    dll.SFileOpenFileEx.restype = C.c_bool
    dll.SFileGetFileSize.argtypes = [C.c_void_p, C.POINTER(C.c_uint)]
    dll.SFileGetFileSize.restype = C.c_uint
    dll.SFileReadFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint, C.POINTER(C.c_uint), C.c_void_p]
    dll.SFileReadFile.restype = C.c_bool
    dll.SFileCloseFile.argtypes = [C.c_void_p]
    dll.SFileCreateFile.argtypes = [C.c_void_p, C.c_char_p, C.c_ulonglong, C.c_uint, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    dll.SFileCreateFile.restype = C.c_bool
    dll.SFileWriteFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint, C.c_uint]
    dll.SFileWriteFile.restype = C.c_bool
    dll.SFileFinishFile.argtypes = [C.c_void_p]
    dll.SFileFinishFile.restype = C.c_bool
    dll.SFileCompactArchive.argtypes = [C.c_void_p, C.c_wchar_p, C.c_bool]
    dll.SFileCompactArchive.restype = C.c_bool
    return dll


def lit_fichier(dll, h, chemin):
    fh = C.c_void_p()
    if not dll.SFileOpenFileEx(h, chemin.encode("latin-1"), 0, C.byref(fh)):
        return None
    taille = dll.SFileGetFileSize(fh, None)
    tampon = C.create_string_buffer(max(taille, 1))
    lu = C.c_uint(0)
    ok = dll.SFileReadFile(fh, tampon, taille, C.byref(lu), None) if taille else True
    dll.SFileCloseFile(fh)
    return tampon.raw[:taille] if ok else None


def ecrit_fichier(dll, h, chemin, donnees):
    fh = C.c_void_p()
    if not dll.SFileCreateFile(h, chemin.encode("latin-1"), 0, len(donnees), 0,
                               MPQ_FILE_COMPRESS | MPQ_FILE_REPLACEEXISTING, C.byref(fh)):
        raise Erreur("SFileCreateFile a refusé " + chemin)
    if donnees and not dll.SFileWriteFile(fh, donnees, len(donnees), MPQ_COMPRESSION_ZLIB):
        raise Erreur("SFileWriteFile a refusé " + chemin)
    if not dll.SFileFinishFile(fh):
        raise Erreur("SFileFinishFile a refusé " + chemin)


# ------------------------------------------------------------------ les DBC
class Dbc:
    def __init__(self, brut, nom):
        if brut[:4] != b"WDBC":
            raise Erreur("%s : signature WDBC absente" % nom)
        self.nom = nom
        self.nrec, self.nfield, self.rsize, taille = struct.unpack_from("<4I", brut, 4)
        debut = 20 + self.nrec * self.rsize
        self.records = [brut[20 + i * self.rsize:20 + (i + 1) * self.rsize] for i in range(self.nrec)]
        self.chaines = bytearray(brut[debut:debut + taille])
        if not self.chaines:
            self.chaines = bytearray(b"\x00")
        self._pool = {}

    def chaine(self, texte):
        """Décalage d'une chaîne, ajoutée au bloc si besoin (0 = vide)."""
        if not texte:
            return 0
        if texte in self._pool:
            return self._pool[texte]
        off = len(self.chaines)
        self.chaines.extend(texte.encode("utf-8") + b"\x00")
        self._pool[texte] = off
        return off

    def retire(self, ids):
        self.records = [r for r in self.records if struct.unpack_from("<I", r, 0)[0] not in ids]

    def ajoute(self, rec):
        self.records.append(rec)

    def octets(self):
        self.records.sort(key=lambda r: struct.unpack_from("<I", r, 0)[0])
        entete = b"WDBC" + struct.pack("<4I", len(self.records), self.nfield, self.rsize, len(self.chaines))
        return entete + b"".join(self.records) + bytes(self.chaines)

    def ids(self):
        return {struct.unpack_from("<I", r, 0)[0] for r in self.records}


def pose_lignes(dbc, table):
    """Nos lignes dans un DBC lu : retrait des identifiants, puis ajout."""
    if dbc.rsize != table["record_size"]:
        raise Erreur("%s : enregistrements de %d octets, %d attendus (client inattendu ?)"
                     % (dbc.nom, dbc.rsize, table["record_size"]))
    dbc.retire({l["id"] for l in table["rows"]})
    for ligne in table["rows"]:
        if "raw" in ligne:
            rec = bytearray.fromhex(ligne["raw"])
            for pos, texte in ligne["strings"].items():
                struct.pack_into("<I", rec, int(pos), dbc.chaine(texte))
            dbc.ajoute(bytes(rec))
        else:
            valeurs = list(ligne["ints"])
            for col in table["string_columns"]:
                valeurs[col] = dbc.chaine(ligne["strings"].get(str(col), ""))
            dbc.ajoute(struct.pack("<%dI" % len(valeurs), *valeurs))


# ------------------------------------------------------------------ le client
def archives_du_client(jeu, lettre, locale):
    data = os.path.join(jeu, "Data")
    if not os.path.isdir(data):
        raise Erreur("pas de dossier Data dans " + jeu)
    if locale is None:
        for d in os.listdir(data):
            if len(d) == 4 and os.path.isfile(os.path.join(data, d, "locale-%s.mpq" % d)):
                locale = d
                break
        else:
            raise Erreur("dossier de langue introuvable dans " + data)
    ordre = [os.path.join(data, n) for n in BASE]
    ordre += [os.path.join(data, locale, n.format(l=locale)) for n in LOCALE]
    for s in SUFFIXES:
        if s.lower() == lettre.lower():
            continue  # notre propre sortie, jamais lue
        ordre.append(os.path.join(data, locale, "patch-%s-%s.mpq" % (locale, s)))
        ordre.append(os.path.join(data, "patch-%s.mpq" % s))
    return data, locale, [p for p in ordre if os.path.isfile(p)]


def trouve(chemins):
    """Résolution insensible à la casse d'un fichier existant."""
    for p in chemins:
        if os.path.isfile(p):
            return p
    return None


def construit_client(jeu, lettre, locale):
    manifeste = json.load(io.open(MANIFESTE, encoding="utf-8"))
    dll = stormlib()
    data, locale, ordre = archives_du_client(jeu, lettre, locale)
    print("client : %s (langue %s), %d archives lues" % (jeu, locale, len(ordre)))
    ouvertes = []
    for chemin in ordre:
        h = C.c_void_p()
        if not dll.SFileOpenArchive(chemin, 0, MPQ_OPEN_READ_ONLY, C.byref(h)):
            raise Erreur("archive illisible (jeu ouvert ?) : " + chemin)
        ouvertes.append((chemin, h))

    def effectif(chemin_interne):
        for chemin, h in reversed(ouvertes):
            if dll.SFileHasFile(h, chemin_interne.encode("latin-1")):
                return os.path.basename(chemin), lit_fichier(dll, h, chemin_interne)
        return None, None

    # 1. les DBC
    dbcs = {}
    for nom, table in manifeste["tables"].items():
        src, brut = effectif("DBFilesClient" + BS + nom)
        if brut is None:
            raise Erreur("le client n'a pas de %s" % nom)
        dbc = Dbc(brut, nom)
        pose_lignes(dbc, table)
        dbcs[nom] = dbc.octets()
        print("  %-30s %5d ligne(s) posée(s) sur la version de %s" % (nom, len(table["rows"]), src))
    for _, h in ouvertes:
        dll.SFileCloseArchive(h)

    # 2. les fichiers
    fichiers = []
    for racine, _, noms in os.walk(FICHIERS):
        for n in noms:
            complet = os.path.join(racine, n)
            interne = os.path.relpath(complet, FICHIERS).replace("/", BS)
            fichiers.append((interne, complet))
    total = len(dbcs) + len(fichiers)

    # 3. l'archive
    sortie = os.path.join(data, "patch-%s.MPQ" % lettre)
    if os.path.exists(sortie):
        os.remove(sortie)
    capacite = 16
    while capacite < total + 8:
        capacite *= 2
    h = C.c_void_p()
    if not dll.SFileCreateArchive(sortie, MPQ_CREATE_LISTFILE | MPQ_CREATE_ATTRIBUTES | MPQ_CREATE_ARCHIVE_V2, capacite, C.byref(h)):
        raise Erreur("impossible de créer " + sortie)
    try:
        for nom, brut in dbcs.items():
            ecrit_fichier(dll, h, "DBFilesClient" + BS + nom, brut)
        for interne, complet in fichiers:
            ecrit_fichier(dll, h, interne, open(complet, "rb").read())
    finally:
        dll.SFileCloseArchive(h)
    print("écrit : %s (%d DBC, %d fichiers, %.1f Mo)" % (sortie, len(dbcs), len(fichiers), os.path.getsize(sortie) / 2 ** 20))

    # 4. relecture
    h = C.c_void_p()
    if not dll.SFileOpenArchive(sortie, 0, MPQ_OPEN_READ_ONLY, C.byref(h)):
        raise Erreur("l'archive produite ne se rouvre pas")
    manquants = 0
    for nom, table in manifeste["tables"].items():
        dbc = Dbc(lit_fichier(dll, h, "DBFilesClient" + BS + nom), nom)
        absents = {l["id"] for l in table["rows"]} - dbc.ids()
        if absents:
            manquants += len(absents)
            print("  ÉCHEC %s : %d identifiant(s) absent(s), ex. %s" % (nom, len(absents), sorted(absents)[:5]))
    for interne, _ in fichiers:
        if not dll.SFileHasFile(h, interne.encode("latin-1")):
            manquants += 1
            print("  ÉCHEC fichier absent : " + interne)
    dll.SFileCloseArchive(h)
    if manquants:
        raise Erreur("%d élément(s) manquent à la relecture" % manquants)
    print("Terminé. Relecture : toutes les lignes et tous les fichiers sont présents.")


# ------------------------------------------------------------------ le serveur
def construit_serveur(dossier_dbc):
    manifeste = json.load(io.open(MANIFESTE, encoding="utf-8"))
    for nom in TABLES_SERVEUR:
        table = manifeste["tables"].get(nom)
        chemin = trouve([os.path.join(dossier_dbc, nom), os.path.join(dossier_dbc, nom.lower())])
        if table is None:
            print("  %-30s rien à poser" % nom)
            continue
        if chemin is None:
            raise Erreur("%s introuvable dans %s" % (nom, dossier_dbc))
        sauvegarde = chemin + ".avant_spherier"
        if not os.path.exists(sauvegarde):
            shutil.copyfile(chemin, sauvegarde)
        dbc = Dbc(open(chemin, "rb").read(), nom)
        pose_lignes(dbc, table)
        open(chemin, "wb").write(dbc.octets())
        relu = Dbc(open(chemin, "rb").read(), nom)
        absents = {l["id"] for l in table["rows"]} - relu.ids()
        if absents:
            raise Erreur("%s : %d identifiant(s) absent(s) après écriture" % (nom, len(absents)))
        print("  %-30s %5d ligne(s) posée(s), sauvegarde %s" % (nom, len(table["rows"]), os.path.basename(sauvegarde)))
    print("Terminé. Redémarrez le worldserver.")


def main(argv):
    if "--serveur" in argv:
        i = argv.index("--serveur")
        if i + 1 >= len(argv):
            raise Erreur("--serveur attend le dossier Data\\dbc du serveur")
        construit_serveur(argv[i + 1])
        return
    if not argv or argv[0].startswith("--"):
        print(__doc__)
        raise Erreur("indiquez le dossier du jeu")
    lettre = "S"
    locale = None
    if "--lettre" in argv:
        lettre = argv[argv.index("--lettre") + 1]
    if "--locale" in argv:
        locale = argv[argv.index("--locale") + 1]
    if len(lettre) != 1 or not lettre.isalnum():
        raise Erreur("la lettre doit être un seul caractère alphanumérique")
    construit_client(argv[0], lettre, locale)


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    try:
        main(sys.argv[1:])
    except Erreur as e:
        print("ERREUR : %s" % e)
        sys.exit(1)
