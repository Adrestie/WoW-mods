# -*- coding: utf-8 -*-
r"""Courbes de puissance des sorts retenus, rang par rang.

Lit les sorts cochés dans sorts_ameliorables.xlsx, reconstitue la chaîne de
rangs de chacun (table `spell_ranks` pour les sorts de maître, Talent.dbc pour
les talents), puis relève dans Spell.dbc les nombres qui font la puissance d'un
rang. Sert de base à l'extrapolation des rangs supplémentaires.

Trois pièges vérifiés à la sonde avant d'écrire quoi que ce soit :

  - **les dégâts ne sont pas toujours dans l'effet 1.** L'Éclair de givre porte
    son ralentissement en effet 1 et ses dégâts en effet 2. Il faut donc chercher
    l'effet utile parmi les trois, jamais présumer.
  - **EffectRealPointsPerLevel est un FLOTTANT**, pas un entier : le lire en
    entier donne des valeurs absurdes de l'ordre du milliard.
  - le coût est en unités internes : 150 pour 15 points de rage.

Les index de champs viennent de gen_sorts_spherier.py, dont le clonage
fonctionne en jeu, et sont recontrôlés ici sur des sorts connus.
"""

import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import MYSQL_HOTE, MYSQL_PORT, MYSQL_UTILISATEUR, MYSQL_MDP, BASE_WORLD  # ce qui décrit le poste, hors du dépôt
import io
import json
import os
import struct
import subprocess
import tempfile
from collections import defaultdict

from openpyxl import load_workbook

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
BASE = BASE_WORLD
DOSSIER_DBC = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc"
CLASSEUR = r"D:\Serveur WoW\outils_spherier\sorts_ameliorables.xlsx"
SORTIE = r"D:\Serveur WoW\outils_spherier\courbes_sorts.json"

LOC_FRFR = 2
IDX = {"ID": 0, "MaxLevel": 37, "BaseLevel": 38, "SpellLevel": 39,
       "DurationIndex": 40, "PowerType": 41, "ManaCost": 42,
       "Effect_1": 71, "EffectDieSides_1": 74, "EffectRealPointsPerLevel_1": 77,
       "EffectBasePoints_1": 80, "EffectAura_1": 95, "EffectAmplitude_1": 98,
       # Le sort déclenché est à 116, PAS à 110 : à 110 on lit zéro partout et
       # l'on conclut à tort que le cœur câble les déclenchements en dur.
       "EffectTriggerSpell_1": 116,
       "Name": 136, "Rank": 153}

# Effets qui portent une valeur chiffrée digne d'être mise à l'échelle.
EFFETS_UTILES = {
    2: "dégâts", 10: "soins", 30: "énergie", 62: "drain de puissance",
    6: "aura", 27: "invocation", 64: "déclenchement", 77: "script",
}
AURAS_UTILES = {3: "dégâts périodiques", 8: "soins périodiques",
                20: "régénération", 22: "réduction de dégâts",
                69: "absorption", 89: "dégâts périodiques (%)"}


def requete(sql):
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False,
                                     encoding="utf-8") as f:
        f.write(sql)
        chemin = f.name
    try:
        r = subprocess.run([MYSQL, "-h" + MYSQL_HOTE, "-u" + MYSQL_UTILISATEUR, "-p" + MYSQL_MDP,
                            "--default-character-set=utf8mb4", "-N", "-B", BASE,
                            "-e", "source %s" % chemin.replace("\\", "/")],
                           capture_output=True, text=True, encoding="utf-8")
        # Une requête fautive ne renvoie rien sur la sortie standard : sans ce
        # contrôle, l'erreur passerait pour un résultat vide.
        if "ERROR" in (r.stderr or ""):
            raise RuntimeError("requête refusée : %s" % r.stderr.strip())
        return [l.split("\t") for l in r.stdout.splitlines() if l.strip()]
    finally:
        os.unlink(chemin)


# --- Spell.dbc ---------------------------------------------------------------
brut = open(os.path.join(DOSSIER_DBC, "Spell.dbc"), "rb").read()
nrec, nfield, rsize, ssize = struct.unpack_from("<4I", brut, 4)
chaines_dbc = brut[20 + nrec * rsize:]
SORTS = {}
for i in range(nrec):
    off = 20 + i * rsize
    SORTS[struct.unpack_from("<I", brut, off)[0]] = off


def texte(off):
    if off <= 0 or off >= len(chaines_dbc):
        return ""
    return chaines_dbc[off:chaines_dbc.index(b"\x00", off)].decode("utf-8", "replace")


def lire(sid):
    """Tous les champs utiles d'un sort, effets compris."""
    off = SORTS.get(sid)
    if off is None:
        return None
    u = struct.unpack_from("<%dI" % nfield, brut, off)
    s = struct.unpack_from("<%di" % nfield, brut, off)
    f = struct.unpack_from("<%df" % nfield, brut, off)

    effets = []
    for e in range(3):
        type_effet = u[IDX["Effect_1"] + e]
        if not type_effet:
            continue
        effets.append({
            "n": e + 1, "type": type_effet,
            "libelle": EFFETS_UTILES.get(type_effet, "effet %d" % type_effet),
            "aura": u[IDX["EffectAura_1"] + e],
            "base": s[IDX["EffectBasePoints_1"] + e],
            "des": u[IDX["EffectDieSides_1"] + e],
            "parniveau": round(f[IDX["EffectRealPointsPerLevel_1"] + e], 4),
            "periode": u[IDX["EffectAmplitude_1"] + e],
            "declenche": u[IDX["EffectTriggerSpell_1"] + e],
            # Une base d'effet factice contient parfois un IDENTIFIANT DE SORT
            # et non une puissance : les Météores y logent 53194, le sort de
            # dégâts qu'ils appellent. Le signaler ici évite de le faire croître
            # plus loin, ce qui fabriquerait un identifiant qui n'existe pas.
            "reference_sort": s[IDX["EffectBasePoints_1"] + e] in SORTS,
        })

    return {
        "spell": sid,
        "nom": texte(u[IDX["Name"] + LOC_FRFR]) or texte(u[IDX["Name"]]),
        "libelle_rang": texte(u[IDX["Rank"] + LOC_FRFR]) or texte(u[IDX["Rank"]]),
        "niveau": u[IDX["SpellLevel"]],
        "niveau_base": u[IDX["BaseLevel"]],
        "niveau_max": u[IDX["MaxLevel"]],
        "cout": u[IDX["ManaCost"]],
        "type_cout": u[IDX["PowerType"]],
        "duree_index": u[IDX["DurationIndex"]],
        "effets": effets,
    }


# --- chaînes de rangs --------------------------------------------------------
chaines = defaultdict(dict)                 # famille -> rang -> spell
# `rank` est un MOT RÉSERVÉ de MySQL 8 : sans les accents graves, il est lu
# comme la fonction de fenêtrage RANK() et la requête échoue — en silence, ici,
# puisqu'on ne lit que la sortie standard.
# NOS PROPRES RANGS SONT DANS CETTE TABLE. Les relever comme s'ils etaient de
# Blizzard fausserait toutes les courbes : Frappe heroique passerait pour un
# sort a seize rangs et l'on extrapolerait a partir de nos propres chiffres.
# Tout ce qui vit au-dessus de cette borne est a nous, et se saute.
SORT_CUSTOM_MIN = 8500000
for p in requete("SELECT first_spell_id, `rank`, spell_id FROM spell_ranks;"):
    if len(p) == 3 and int(p[2]) < SORT_CUSTOM_MIN:
        chaines[int(p[0])][int(p[1])] = int(p[2])


def lire_dbc(nom):
    b = open(os.path.join(DOSSIER_DBC, nom), "rb").read()
    n, nf, rs, _ = struct.unpack_from("<4I", b, 4)
    for i in range(n):
        yield struct.unpack_from("<%dI" % nf, b, 20 + i * rs)


for c in lire_dbc("Talent.dbc"):
    rangs = [s for s in c[4:13] if s]
    if len(rangs) > 1 and rangs[0] not in chaines:
        for r, spell in enumerate(rangs, start=1):
            chaines[rangs[0]][r] = spell

# Index inverse : dernier rang -> famille.
par_dernier = {rangs[max(rangs)]: fam for fam, rangs in chaines.items()}

# --- corrections de la sélection, arrêtées le 2026-08-26 ---------------------
# « Coup de bouclier » (sort 72) est une interruption sans le moindre chiffre ;
# c'est « Heurt de bouclier » (Shield Slam) qui était visé, et qui porte bien
# une base de 293. Substitution plutôt que retouche du classeur : la saisie de
# l'utilisateur reste intacte et la correction se lit ici.
SUBSTITUTIONS = {("Guerrier", "Coup de bouclier"): "Heurt de bouclier"}

# Écartés faute de pouvoir faire croître quoi que ce soit : la Morsure de vipère
# rend un pourcentage de la mana drainée, l'Ordre de tuer n'est qu'un
# déclencheur pour le familier, et les totems comme les enchantements d'arme du
# chaman logent leur puissance dans une créature ou une entrée
# d'enchantement — un autre chantier.
ECARTES = {
    ("Chasseur", "Morsure de vipère"), ("Chasseur", "Ordre de tuer"),
    ("Chaman", "Totem incendiaire"), ("Chaman", "Totem Fontaine de mana"),
    ("Chaman", "Totem de magma"), ("Chaman", "Arme Langue de feu"),
    ("Chaman", "Arme Furie-des-vents"), ("Chaman", "Arme Viveterre"),
}

# --- chaines paralleles ------------------------------------------------------
# Un script du coeur traduit le rang du sort lance en un rang d'une AUTRE
# chaine. Etendre l'un sans l'autre fait planter le serveur — GetSpellWithRank
# remonte de rang en rang et dereference `node->next` sans le verifier — et le
# rang supplementaire ne ferait de toute facon rien, la puissance vivant la-bas.
# Releve par grep de `GetSpellWithRank` dans src/, croise avec nos familles.
CHAINES_PARALLELES = {
    20473: [(25912, "dégâts"), (25914, "soins")],    # Horion sacré
    47540: [(47758, "dégâts"), (47757, "soins")],    # Pénitence
    1535:  [(8349, "déclenchée")],                    # Nova de feu
    27243: [(27285, "détonation")],                   # Semence de corruption
    49998: [(66188, "main gauche")],                  # Frappe de mort
    49143: [(66196, "main gauche")],                  # Frappe de givre
    49020: [(66198, "main gauche")],                  # Oblitération
    45902: [(66215, "main gauche")],                  # Frappe de sang
}

# --- sorts retenus -----------------------------------------------------------
wb = load_workbook(CLASSEUR)
resultat = {}
for feuille in wb.sheetnames:
    if feuille == "Mode d'emploi":
        continue
    ws = wb[feuille]
    # De quoi retrouver un sort par son nom, pour les substitutions.
    par_nom = {ws.cell(r, 1).value: ws.cell(r, 6).value
               for r in range(2, ws.max_row + 1)}
    liste = []
    for r in range(2, ws.max_row + 1):
        choix = ws.cell(r, 8).value
        if not (choix and str(choix).strip().lower().startswith("o")):
            continue

        nom_sort = ws.cell(r, 1).value
        if (feuille, nom_sort) in ECARTES:
            continue
        remplacant = SUBSTITUTIONS.get((feuille, nom_sort))
        if remplacant and remplacant in par_nom:
            nom_sort = remplacant

        smax = par_nom.get(nom_sort) or ws.cell(r, 6).value
        famille = par_dernier.get(smax)
        rangs = chaines[famille] if famille else {1: smax}
        profil = [lire(rangs[k]) for k in sorted(rangs) if lire(rangs[k])]

        # Un sort qui ne porte aucune valeur mais qui en DÉCLENCHE un autre :
        # la puissance vit dans le sort appelé. On relève sa courbe en parallèle,
        # rang par rang, pour pouvoir la faire monter elle aussi.
        for rang in profil:
            for e in rang["effets"]:
                if e["declenche"] and e["declenche"] in SORTS:
                    e["sous_sort"] = lire(e["declenche"])

        liste.append({
            "nom": nom_sort,
            "origine": ws.cell(r, 2).value,
            "famille": famille or smax,
            "rangs": len(profil),
            "profil": profil,
        })

        # Les chaines que des scripts du coeur indexent par le rang de celle-ci.
        # Elles suivent le meme chemin — releve, extrapolation, generation —
        # mais ne donnent aucune rune : c'est le sort parent qui en porte une.
        for famille_p, etiquette in CHAINES_PARALLELES.get(famille or smax, []):
            rangs_p = chaines.get(famille_p)
            if not rangs_p:
                print("  chaine parallele %d introuvable dans spell_ranks" % famille_p)
                continue
            profil_p = [lire(rangs_p[k]) for k in sorted(rangs_p) if lire(rangs_p[k])]
            for rang in profil_p:
                for e in rang["effets"]:
                    if e["declenche"] and e["declenche"] in SORTS:
                        e["sous_sort"] = lire(e["declenche"])
            liste.append({
                "nom": "%s (%s)" % (nom_sort, etiquette),
                "origine": ws.cell(r, 2).value,
                "famille": famille_p,
                "rangs": len(profil_p),
                "profil": profil_p,
                "parallele": True,
                "parent": famille or smax,
            })
    liste.sort(key=lambda d: -d["rangs"])
    resultat[feuille] = liste

with io.open(SORTIE, "w", encoding="utf-8") as f:
    json.dump(resultat, f, ensure_ascii=False, indent=1)

total = sum(len(v) for v in resultat.values())
rangs = sum(s["rangs"] for v in resultat.values() for s in v)
print("courbes_sorts.json écrit")
print("  %d sorts retenus, %d rangs existants, %d rangs à créer"
      % (total, rangs, total * 3))
courts = [s for v in resultat.values() for s in v if s["rangs"] < 5]
print("  dont %d sorts à moins de 5 rangs, à traiter en dernier" % len(courts))
