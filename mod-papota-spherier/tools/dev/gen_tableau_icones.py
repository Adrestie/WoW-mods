# -*- coding: utf-8 -*-
r"""Classeur d'arbitrage des icônes du sphèrier.

Une ligne par objet — pierres, Nexus, épingle, runes de rang, runes de
statistique —, avec ce qu'il porte AUJOURD'HUI et une colonne à remplir.

Ce fichier ne décide de rien : il présente l'existant. C'est l'utilisateur qui
choisit, et un générateur reprendra ensuite la colonne « Icône souhaitée ».

    python gen_tableau_icones.py

ATTENTION : la sortie ÉCRASE `icones_objets.xlsx`. Une fois la colonne remplie,
ne relancer ce script que pour repartir d'un gabarit vierge.
"""

import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import MYSQL_HOTE, MYSQL_PORT, MYSQL_UTILISATEUR, MYSQL_MDP, BASE_WORLD  # ce qui décrit le poste, hors du dépôt
import ctypes
import os
import struct
import subprocess
import tempfile
from ctypes import wintypes

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
BASE = BASE_WORLD
SORTIE = r"D:\Serveur WoW\outils_spherier\icones_objets.xlsx"
DLL = r"D:\Serveur WoW\tools\StormLib_build\Release\StormLib.dll"
# Le dossier du client se CHERCHE, version comprise (2026-09-06) : ecrit en dur,
# il avait fait echouer l'injection en silence au renommage 1.1.0 -> 1.2.0.
from gen_sorts_classes import dossier_client as _dossier_client
DOSSIER_CLIENT = _dossier_client()

# Ordre de priorité des archives du client, du plus fort au plus faible.
ARCHIVES = [r"frFR\patch-frFR-z.mpq", "patch-z.MPQ",
            r"frFR\patch-frfr-3.mpq", "patch-3.mpq",
            r"frFR\patch-frfr-2.mpq", "patch-2.mpq",
            r"frFR\patch-frfr.mpq", "patch.mpq",
            "patch-c.mpq", "patch-b.mpq", "patch-a.mpq",
            "lichking.mpq", "expansion.mpq", "common-2.mpq", "common.mpq",
            r"frFR\locale-frfr.mpq", r"frFR\base-frfr.mpq"]

# (feuille, borne basse, borne haute) — les plages sont celles du §8.
FAMILLES = [
    ("Pierres",              803100, 803179),
    ("Runes de rang",        803400, 803599),
    ("Runes de statistique", 803600, 803699),
    ("Nexus",                803200, 803204),
    ("Épingle",              803300, 803300),
]

TITRE = Font(bold=True, color="FFFFFF", size=11)
FOND_TITRE = PatternFill("solid", fgColor="4F3A6B")
FOND_SAISIE = PatternFill("solid", fgColor="FFF2CC")
BORDURE = Border(*(Side(style="thin", color="BFBFBF"),) * 4)

ENTETES = ["Entrée", "Nom (FR)", "Nom (EN)", "Qualité",
           "DisplayInfoID actuel", "Icône actuelle", "Icône souhaitée"]
LARGEURS = [10, 34, 34, 11, 20, 30, 30]

QUALITES = {0: "Pauvre", 1: "Commune", 2: "Inhabituelle", 3: "Rare",
            4: "Épique", 5: "Légendaire"}


def requete(sql):
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False,
                                     encoding="utf-8") as f:
        f.write(sql)
        chemin = f.name
    try:
        sortie = subprocess.run(
            [MYSQL, "-h" + MYSQL_HOTE, "-u" + MYSQL_UTILISATEUR, "-p" + MYSQL_MDP,
             "--default-character-set=utf8mb4", "-N", "-B", BASE,
             "-e", "source %s" % chemin.replace("\\", "/")],
            capture_output=True, text=True, encoding="utf-8")
        return [l.split("\t") for l in sortie.stdout.splitlines() if l.strip()]
    finally:
        os.unlink(chemin)


def lire_du_client(nom):
    """Le DBC tel que le client le voit, en LECTURE SEULE.

    PIÈGE : SFileOpenArchive, SFileOpenFileEx et SFileReadFile renvoient un
    `bool` C++, donc UN SEUL octet. Sans `restype = c_bool`, ctypes en lit
    quatre et les bits de poids fort font passer un FAUX pour un VRAI : on croit
    avoir ouvert un fichier que l'archive ne contient pas, et la taille ressort
    à zéro.
    """
    s = ctypes.WinDLL(DLL)
    s.SFileOpenArchive.argtypes = [wintypes.LPCWSTR, wintypes.DWORD,
                                   wintypes.DWORD, ctypes.POINTER(ctypes.c_void_p)]
    s.SFileOpenFileEx.argtypes = [ctypes.c_void_p, wintypes.LPCSTR, wintypes.DWORD,
                                  ctypes.POINTER(ctypes.c_void_p)]
    s.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
    s.SFileGetFileSize.restype = wintypes.DWORD
    s.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD,
                                ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]
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
            return tampon.raw[:lu.value]
        s.SFileCloseArchive(mpq)
    raise SystemExit("%s introuvable dans les archives du client" % nom)


def icones_par_display():
    """DisplayInfoID -> nom du fichier d'icône (champ 5 d'ItemDisplayInfo)."""
    brut = lire_du_client("ItemDisplayInfo.dbc")
    nrec, nfield, rsize, ssize = struct.unpack_from("<4I", brut, 4)
    debut = 20 + nrec * rsize
    enregs = brut[20:debut]
    chaines = brut[debut:debut + ssize]

    def texte(off):
        if off <= 0 or off >= len(chaines):
            return ""
        return chaines[off:chaines.index(b"\x00", off)].decode("utf-8", "replace")

    noms = {}
    for i in range(nrec):
        off = i * rsize
        ident = struct.unpack_from("<I", enregs, off)[0]
        noms[ident] = texte(struct.unpack_from("<I", enregs, off + 5 * 4)[0])
    return noms


icones = icones_par_display()

lignes = requete("""
SELECT t.entry, COALESCE(l.Name, ''), t.name, t.Quality, t.displayid
FROM item_template t
LEFT JOIN item_template_locale l ON l.ID = t.entry AND l.locale = 'frFR'
WHERE t.entry BETWEEN 803100 AND 803699
ORDER BY t.entry;
""")

par_entree = {}
for e, nom_fr, nom_en, qualite, display in lignes:
    par_entree[int(e)] = (nom_fr, nom_en, int(qualite), int(display))

classeur = Workbook()
classeur.remove(classeur.active)

mode = classeur.create_sheet("Mode d'emploi")
for i, texte in enumerate([
    "Icônes des objets du sphèrier",
    "",
    "Une ligne par objet. Ne remplir que la dernière colonne, « Icône souhaitée ».",
    "Les autres décrivent l'existant et servent de repère.",
    "",
    "Deux façons de désigner une icône, au choix, colonne par colonne :",
    "  • un NOMBRE : un DisplayInfoID existant, l'objet reprendra alors",
    "    exactement l'apparence de celui qui le porte déjà ;",
    "  • un NOM d'icône, par exemple INV_Misc_Rune_06 : une entrée",
    "    d'affichage sera créée pour lui, comme pour les runes de rang.",
    "",
    "Une cellule laissée vide veut dire « on ne touche pas ».",
    "",
    "ATTENTION : relancer gen_tableau_icones.py ÉCRASE ce fichier.",
    "Ne le faire que pour repartir d'un gabarit vierge.",
], start=1):
    c = mode.cell(row=i, column=1, value=texte)
    if i == 1:
        c.font = Font(bold=True, size=13)
mode.column_dimensions["A"].width = 78

total = 0
for nom_feuille, bas, haut in FAMILLES:
    f = classeur.create_sheet(nom_feuille)
    for col, (entete, largeur) in enumerate(zip(ENTETES, LARGEURS), start=1):
        c = f.cell(row=1, column=col, value=entete)
        c.font = TITRE
        c.fill = FOND_TITRE
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border = BORDURE
        f.column_dimensions[get_column_letter(col)].width = largeur
    f.freeze_panes = "A2"

    r = 2
    for entree in sorted(par_entree):
        if not (bas <= entree <= haut):
            continue
        nom_fr, nom_en, qualite, display = par_entree[entree]
        valeurs = [entree, nom_fr, nom_en, QUALITES.get(qualite, qualite),
                   display, icones.get(display, "(inconnue)"), ""]
        for col, v in enumerate(valeurs, start=1):
            c = f.cell(row=r, column=col, value=v)
            c.border = BORDURE
            if col == len(ENTETES):
                c.fill = FOND_SAISIE
        r += 1
        total += 1
    print("  %-22s %d ligne(s)" % (nom_feuille, r - 2))

classeur.save(SORTIE)
print("Classeur écrit : %s (%d objets)" % (SORTIE, total))
