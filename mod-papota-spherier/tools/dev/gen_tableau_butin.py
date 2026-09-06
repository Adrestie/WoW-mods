# -*- coding: utf-8 -*-
r"""Classeur des cas de butin du sphèrier, à remplir par l'utilisateur.

Structure arrêtée par l'utilisateur le 2026-08-24. Une feuille par source ;
chaque ligne est un cas que le module sait distinguer à l'exécution.

Rien n'y est théorique. Les types de filons et de plantes de Wrath viennent du
croisement de Lock.dbc (métier et compétence exigée), de Map.dbc (extension de
la carte) et des apparitions réelles de la base — c'est ainsi qu'on découvre par
exemple que l'épine-de-feu est de Wrath et non de Burning Crusade.

La pêche ne donne rien : décision de l'utilisateur, elle n'a pas de feuille.
"""

import os

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

SORTIE = r"D:\Serveur WoW\outils_spherier\butin_spherier.xlsx"

# --- objets disponibles ------------------------------------------------------
# Entrées figées par gen_objets_spherier.py. Les pierres ne sont pas listées
# entrée par entrée (80) : on choisit une QUALITÉ, la statistique étant tirée
# au hasard parmi les seize au moment du butin.
OBJETS = [
    ("Nexus appauvri",       "803200", "50 Spherite"),
    ("Nexus vacillant",      "803201", "100 Spherite"),
    ("Nexus lumineux",       "803202", "250 Spherite"),
    ("Nexus irradiant",      "803203", "500 Spherite"),
    ("Nexus solaire",        "803204", "1000 Spherite"),
    ("Pierre commune",       "803100 + stat", "+5 à une statistique"),
    ("Pierre inhabituelle",  "803101 + stat", "+7 à une statistique"),
    ("Pierre rare",          "803102 + stat", "+10 à une statistique"),
    ("Pierre épique",        "803103 + stat", "+15 à une statistique"),
    ("Pierre légendaire",    "803104 + stat", "+30 à une statistique"),
    ("Épingle de l'oubli",   "803300", "vide un emplacement"),
    ("(rien)",               "",       "aucun butin pour ce cas"),
]

NOMS_OBJETS = [o[0] for o in OBJETS]

# --- monstres : les 16 cas demandés ------------------------------------------
MONSTRES = [
    ("Monstres normaux Vanilla",
     "Extension 0, hors instance", "Élwynn, Durotar, Fléau de l'Est…"),
    ("Monstres et boss de donjons Vanilla",
     "Extension 0, donjon", "Mortemines, Stratholme — piétaille et boss confondus"),
    ("Monstres de raids Vanilla",
     "Extension 0, raid, hors boss", "Cœur du Magma, Ahn'Qiraj, Zul'Gurub"),
    ("Boss de raids Vanilla",
     "Extension 0, raid, boss", "Ragnaros, Onyxia, Nefarian, C'Thun"),

    ("Monstres normaux Burning Crusade",
     "Extension 1, hors instance", "Outreterre, carte 530"),
    ("Monstres et boss de donjons Burning Crusade",
     "Extension 1, donjon", "piétaille et boss confondus, normal et héroïque"),
    ("Monstres de raids Burning Crusade",
     "Extension 1, raid, hors boss", "Karazhan, Œil, Temple noir, Puits de soleil"),
    ("Boss de raids Burning Crusade",
     "Extension 1, raid, boss", "Illidan, Kil'jaeden"),

    ("Monstres normaux Wrath",
     "Extension 2, hors instance", "Norfendre, carte 571"),
    ("Monstres de donjons Wrath",
     "Extension 2, donjon normal, hors boss", ""),
    ("Boss de donjons Wrath",
     "Extension 2, donjon normal, boss", ""),
    ("Monstres de donjons héroïques Wrath",
     "Extension 2, donjon héroïque, hors boss", ""),
    ("Boss de donjons héroïques Wrath",
     "Extension 2, donjon héroïque, boss", ""),
    ("Monstres de raids Wrath",
     "Extension 2, raid, hors boss", "Icecrown comprise"),
    ("Boss de raids Wrath sauf Icecrown",
     "Extension 2, raid, boss, carte ≠ 631", "Naxxramas, Ulduar, Épreuve du croisé, Sanctum rubis"),
    ("Boss de raid Icecrown",
     "Carte 631, boss", "INTERPRÉTATION : la ligne précédente excluant Icecrown, "
     "celle-ci la couvre. Corriger si vous vouliez autre chose."),
]

# --- récolte -----------------------------------------------------------------
# Le module reconnaît un type de filon ou de plante par le couple
# (compétence exigée, extension de la carte) : la compétence seule ne suffit
# pas, le cobalt de Wrath et la riche adamantite de BC exigeant tous deux 350.
MINERAIS = [
    ("Minage", "Minerais de Vanilla", "0 à 255",
     "Cuivre, étain, argent, fer, or, mithril, vrai-argent, thorium, fer sombre"),
    ("Minage", "Minerais de Burning Crusade", "275 à 375",
     "Fer gangrené, néantacier, adamantite, riche adamantite, khorium, gemme ancienne"),
    ("Minage", "Gisement de cobalt", "350", "Wrath — 595 apparitions"),
    ("Minage", "Riche gisement de cobalt", "375", "Wrath — 593 apparitions"),
    ("Minage", "Gisement de saronite", "400", "Wrath — 1190 apparitions"),
    ("Minage", "Riche gisement de saronite", "425", "Wrath — 1017 apparitions"),
    ("Minage", "Filon de titane", "450", "Wrath — 1017 apparitions"),
    ("Minage", "Gisement de saronite pure", "450", "Wrath — 1 seule apparition"),
]

PLANTES = [
    ("Herboristerie", "Plantes de Vanilla", "0 à 300",
     "Pacifique, feuillargent, terrestrine… jusqu'au lotus noir"),
    ("Herboristerie", "Plantes de Burning Crusade", "300 à 375",
     "Gangrehete, gloire-de-rêve, ragveil, térocone, calotte de flammes, "
     "lichen ancien, néantfleur, poussière-du-Vide, vigne cauchemardesque, chardon-de-mana"),
    ("Herboristerie", "Herbe gelée", "300", "Wrath — 405 apparitions"),
    ("Herboristerie", "Trèfle-d'or", "350", "Wrath — 357 apparitions"),
    ("Herboristerie", "Épine-de-feu", "360", "Wrath — 32 apparitions"),
    ("Herboristerie", "Lis-tigre", "375", "Wrath — 189 apparitions"),
    ("Herboristerie", "Rose de Talandra", "385", "Wrath — 118 apparitions"),
    ("Herboristerie", "Langue-de-vipère", "400", "Wrath — 157 apparitions"),
    ("Herboristerie", "Fléau-de-liche", "425", "Wrath — 675 apparitions"),
    ("Herboristerie", "Givrépine", "435", "Wrath — 672 apparitions"),
    ("Herboristerie", "Lotus de givre", "450", "Wrath — 90 apparitions"),
]

RECOLTE = MINERAIS + PLANTES

# --- dépeçage ----------------------------------------------------------------
DEPECAGE = [
    ("1-60",  "Bêtes de Vanilla"),
    ("61-70", "Bêtes d'Outreterre"),
    ("71-79", "Bêtes de Norfendre"),
    ("80-83", "Bêtes de fin de jeu, élites de raid comprises"),
]

# --- coffres -----------------------------------------------------------------
COFFRES = [
    ("Extérieur", "coffres et caisses du monde ouvert"),
    ("Donjon normal", ""),
    ("Donjon héroïque", ""),
    ("Raid", ""),
]

# --- mise en forme -----------------------------------------------------------
TITRE = Font(bold=True, color="FFFFFF", size=11)
FOND_TITRE = PatternFill("solid", fgColor="4F3A6B")
FOND_SAISIE = PatternFill("solid", fgColor="FFF2CC")
BORDURE = Border(*(Side(style="thin", color="BFBFBF"),) * 4)
HAUT = Alignment(vertical="center", wrap_text=True)

SAISIE = ["Objet", "Quantité", "Chance (%)"]


def feuille(classeur, nom, entetes, lignes, largeurs, note):
    ws = classeur.create_sheet(nom)

    ws["A1"] = note
    ws["A1"].font = Font(italic=True, size=9, color="595959")
    ws["A1"].alignment = Alignment(wrap_text=True, vertical="top")
    ws.merge_cells(start_row=1, start_column=1, end_row=1,
                   end_column=len(entetes) + len(SAISIE))
    ws.row_dimensions[1].height = 34

    for i, titre in enumerate(list(entetes) + SAISIE, start=1):
        c = ws.cell(row=2, column=i, value=titre)
        c.font, c.fill, c.border = TITRE, FOND_TITRE, BORDURE
        c.alignment = Alignment(vertical="center", horizontal="center", wrap_text=True)
    ws.row_dimensions[2].height = 28

    for r, ligne in enumerate(lignes, start=3):
        for i, valeur in enumerate(ligne, start=1):
            c = ws.cell(row=r, column=i, value=valeur)
            c.border, c.alignment = BORDURE, HAUT
        for i in range(len(entetes) + 1, len(entetes) + len(SAISIE) + 1):
            c = ws.cell(row=r, column=i)
            c.border, c.fill = BORDURE, FOND_SAISIE
            c.alignment = Alignment(horizontal="center", vertical="center")

    colonne_objet = get_column_letter(len(entetes) + 1)
    dv = DataValidation(type="list",
                        formula1='"%s"' % ",".join(NOMS_OBJETS),
                        allow_blank=True, showDropDown=False)
    dv.error = "Choisir un objet dans la liste."
    ws.add_data_validation(dv)
    dv.add("%s3:%s%d" % (colonne_objet, colonne_objet, len(lignes) + 2))

    for i, largeur in enumerate(list(largeurs) + [22, 10, 12], start=1):
        ws.column_dimensions[get_column_letter(i)].width = largeur

    ws.freeze_panes = "A3"
    return ws


wb = Workbook()
wb.remove(wb.active)

# --- feuille de référence ----------------------------------------------------
ws = wb.create_sheet("Objets")
ws["A1"] = ("Objets que le sphèrier peut faire tomber. Pour une pierre, on choisit une "
            "QUALITÉ : la statistique est tirée au hasard parmi les seize au moment du "
            "butin. « Quantité » est le nombre d'exemplaires ; « Chance » le pourcentage "
            "de tirage. Laisser Objet vide, ou choisir « (rien) », pour qu'un cas ne "
            "donne aucun butin.")
ws["A1"].font = Font(italic=True, size=9, color="595959")
ws["A1"].alignment = Alignment(wrap_text=True, vertical="top")
ws.merge_cells("A1:C1")
ws.row_dimensions[1].height = 46
for i, titre in enumerate(["Objet", "Entrée", "Effet"], start=1):
    c = ws.cell(row=2, column=i, value=titre)
    c.font, c.fill, c.border = TITRE, FOND_TITRE, BORDURE
for r, o in enumerate(OBJETS, start=3):
    for i, v in enumerate(o, start=1):
        c = ws.cell(row=r, column=i, value=v)
        c.border, c.alignment = BORDURE, HAUT
for col, largeur in zip("ABC", (24, 16, 26)):
    ws.column_dimensions[col].width = largeur
ws.freeze_panes = "A3"

feuille(wb, "Monstres",
        ["Cas", "Ce que le module regarde", "Repères"],
        MONSTRES, [44, 36, 52],
        "Les seize cas demandés. L'extension vient de la CARTE (Map.dbc), pas de la "
        "créature : c'est elle qui dit qu'un donjon est de Vanilla, de BC ou de Wrath, "
        "quels que soient les modèles réutilisés par ses occupants. Règle d'arbitrage : "
        "la PREMIÈRE ligne qui convient l'emporte, du plus précis au plus général — les "
        "boss d'Icecrown sont donc traités avant les boss de raid.")

feuille(wb, "Récolte",
        ["Métier", "Cas", "Compétence exigée", "Repères"],
        RECOLTE, [16, 34, 18, 62],
        "Le module reconnaît un type par le couple (compétence exigée par le verrou, "
        "extension de la carte). La compétence seule ne suffirait pas : le cobalt de "
        "Wrath et la riche adamantite de BC exigent tous deux 350. ATTENTION : une "
        "compétence de zéro est légitime — le cuivre et les herbes de départ n'imposent "
        "aucun niveau, seulement le métier.")

feuille(wb, "Dépeçage",
        ["Niveau de la bête", "Repères"],
        DEPECAGE, [22, 52],
        "Le dépeçage réutilise l'objet de butin de la bête : niveau, zone, carte et rang "
        "restent connus. C'est le niveau qui sert de palier.")

feuille(wb, "Coffres",
        ["Contexte", "Repères"],
        COFFRES, [26, 52],
        "Coffres et caisses du monde et des instances. Ils passent par le magasin des "
        "objets de jeu, comme la récolte, mais n'exigent aucun métier. Feuille "
        "facultative : la laisser vide revient à ne rien faire tomber des coffres.")

os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
wb.save(SORTIE)
print("Classeur écrit :", SORTIE)
print("  %d cas de monstres, %d de récolte (%d minerais, %d plantes), "
      "%d de dépeçage, %d de coffres — %d au total."
      % (len(MONSTRES), len(RECOLTE), len(MINERAIS), len(PLANTES),
         len(DEPECAGE), len(COFFRES),
         len(MONSTRES) + len(RECOLTE) + len(DEPECAGE) + len(COFFRES)))
