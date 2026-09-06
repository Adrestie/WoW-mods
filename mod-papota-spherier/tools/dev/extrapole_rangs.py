# -*- coding: utf-8 -*-
r"""Extrapole les trois rangs supplémentaires de chaque sort retenu.

Méthode, tirée de la mesure des 1095 rangs existants (voir analyse_courbes.py) :

  - la croissance d'un rang au suivant, mesurée en FIN de courbe, a pour médiane
    **×1,211** — soit +21 % par rang. Les quartiles vont de ×1,144 à ×1,296 ;
  - chaque sort garde SA propre croissance quand il a de quoi la mesurer : on
    prend la **médiane** de ses trois derniers pas, pas leur moyenne, parce
    qu'une refonte d'extension laisse parfois un saut isolé (la Barrière de
    glace passe de 1074 à 2800 d'un rang à l'autre) qui fausserait une moyenne ;
  - cette croissance est bornée à [1,10 ; 1,35] : au-delà, on sort de ce que
    Blizzard fait, et l'extrapolation deviendrait une invention ;
  - **les sorts trop courts pour être mesurés reçoivent la médiane générale**,
    ce qui est exactement l'usage prévu pour eux — ils passent en dernier et
    profitent de la tendance des autres.

Ce qui NE bouge pas d'un rang custom à l'autre :

  - le **niveau requis** reste celui du dernier rang de Blizzard. Ces rangs
    s'obtiennent par une rune, pas chez un maître ; un niveau supérieur à 80 les
    rendrait incastables ;
  - le **coût** reste identique. Chez Blizzard, le coût en rage ou en énergie ne
    varie pas d'un rang à l'autre, et les sorts à mana coûtent un pourcentage de
    la mana de base, donc rien à mettre à l'échelle.
"""

import io
import json
import statistics

COURBES = r"D:\Serveur WoW\outils_spherier\courbes_sorts.json"
SORTIE = r"D:\Serveur WoW\outils_spherier\rangs_extrapoles.json"

CROISSANCE_MEDIANE = 1.211
BORNE_BASSE, BORNE_HAUTE = 1.10, 1.35
RANGS_A_CREER = 3

# Sorts dont toute la puissance est un POURCENTAGE : rien à mesurer d'un rang à
# l'autre puisqu'ils n'en ont qu'un, ou que leur valeur ne bouge pas. Règle
# donnée par l'utilisateur le 2026-08-26 : +15 %, +30 %, +50 % RELATIFS à la
# valeur du dernier rang. « Réduit de 50 % » devient donc 57,5 %, 65 %, 75 %.
POURCENTAGE_PAR_RANG = (1.15, 1.30, 1.50)

# Ce qui, dans les données, porte un pourcentage. Relevé sur les sorts concernés,
# pas supposé : type 31 = pourcentage d'arme ; aura 79 = dégâts infligés (%) ;
# aura 137 = statistiques totales (%) ; aura 220 et 197 = dégâts subis (%).
POURCENTAGES = {("type", 31), ("aura", 79), ("aura", 137), ("aura", 220),
                ("aura", 197), ("aura", 136), ("aura", 166)}

# L'aura 4 est une aura FACTICE : le cœur y met ce qu'il veut. La Bénédiction du
# sanctuaire supérieure y loge sa réduction de 3 % des dégâts subis — un vrai
# pourcentage —, mais Fulgurance et Projectiles des arcanes y logent de tout
# autre chose. Ranger l'aura 4 parmi les pourcentages capturait ces deux-là par
# erreur, et délogeait Projectiles des arcanes de sa chaîne de déclenchement,
# qui le traitait correctement. On nomme donc le cas au lieu de généraliser.
POURCENTAGES_NOMMES = {"Bénédiction du sanctuaire supérieure"}


def est_pourcentage(effet):
    if ("type", effet["type"]) in POURCENTAGES:
        return True
    return effet["type"] == 6 and ("aura", effet["aura"]) in POURCENTAGES

# QUEL EFFET FAUT-IL METTRE À L'ÉCHELLE ? La question s'est révélée piégeuse.
#
# Une liste blanche de types d'effet ne marche pas : la Frappe de givre porte
# ses dégâts plats dans un effet de type 121 (249 au rang 6) ET un pourcentage
# d'arme dans un effet de type 31 (54, identique à tous les rangs). Mettre les
# deux à l'échelle gonflerait le pourcentage ; n'en mettre aucun laisserait le
# sort inchangé. Les dégâts se cachent d'ailleurs dans des types très divers :
# 2 pour les sorts, 3 pour l'Exécution, 58 pour la Frappe héroïque, 121 pour la
# Frappe de givre.
#
# La règle retenue ne présume donc rien du type : **un effet se met à l'échelle
# s'il a effectivement varié d'un rang à l'autre chez Blizzard.** C'est mesuré,
# pas décrété, et cela traite d'un coup les pourcentages constants, les durées
# fixes et les valeurs plates qui montent.
#
# Pour les sorts à rang unique, il n'y a rien à comparer : on retombe alors sur
# une liste de types connus pour porter une valeur, en écartant le type 31, qui
# est toujours un pourcentage d'arme.
TYPES_A_ECHELLE = {2, 3, 10, 30, 58, 62, 121}
AURAS_A_ECHELLE = {3, 8, 20, 22, 69, 89}


# Un champ de base peut contenir autre chose qu'une puissance : un IDENTIFIANT
# de sort, un drapeau, un numéro d'emplacement. Deux garde-fous, tirés de deux
# erreurs constatées :
#
#   - les Météores portent dans un effet factice la valeur 53194, qui est
#     l'identifiant du sort de dégâts. D'un rang à l'autre elle passe de 53193 à
#     53194 : une croissance de 0,002 %, sans commune mesure avec une montée en
#     puissance. **En dessous de 2 % de croissance, ce n'est pas une valeur.**
#   - la Tempête de lames déclenche un Tourbillon dont la base vaut -1, soit
#     zéro de dégâts plats. **Une valeur réelle de 0 ou ±1 est un drapeau**, pas
#     une puissance à faire croître.
CROISSANCE_MINIMALE = 1.02
VALEUR_MINIMALE = 2


def porte_une_puissance(effet):
    # Ne PAS écarter un effet au seul motif que sa base coïncide avec un
    # identifiant de sort existant : les identifiants couvrant 1 à 80 000,
    # presque toute valeur de dégâts en croise un. Les 1455 de l'Exécution en
    # sont un. Ce qui trahit une référence, c'est son immobilité d'un rang à
    # l'autre — c'est donc la croissance qui tranche, plus bas.
    return abs(effet["base"] + 1) >= VALEUR_MINIMALE


def variables(profil):
    """Rangs d'effet dont la valeur a crû de façon significative."""
    if len(profil) < 2:
        return None
    bouge = set()
    for i in range(len(profil) - 1):
        for a in profil[i]["effets"]:
            b = next((x for x in profil[i + 1]["effets"] if x["n"] == a["n"]), None)
            if not b or not porte_une_puissance(b):
                continue
            if a["base"] and b["base"]:
                rapport = abs(b["base"]) / float(abs(a["base"]))
                if rapport < CROISSANCE_MINIMALE and a["des"] == b["des"]:
                    continue            # identifiant ou constante, pas une puissance
            if a["base"] != b["base"] or a["des"] != b["des"]:
                bouge.add(a["n"])
    return bouge


def a_echelle_par_defaut(effet):
    if effet["type"] == 31 or not porte_une_puissance(effet):
        return False
    if effet["type"] in TYPES_A_ECHELLE:
        return True
    return effet["type"] == 6 and effet["aura"] in AURAS_A_ECHELLE


def ampleur(rang, retenus=None):
    """De quoi comparer deux rangs : le plus gros effet mis à l'échelle."""
    valeurs = []
    for e in rang["effets"]:
        if not porte_une_puissance(e):
            continue
        garde = (e["n"] in retenus) if retenus is not None else a_echelle_par_defaut(e)
        if garde:
            valeurs.append(abs(e["base"]) + abs(e["des"]) / 2.0)
    return max(valeurs) if valeurs else 0.0


def croissance(profil, retenus):
    """Croissance propre au sort, ou la médiane générale s'il est trop court."""
    valeurs = [ampleur(r, retenus) for r in profil]
    pas = [valeurs[i + 1] / valeurs[i]
           for i in range(len(valeurs) - 1) if valeurs[i] > 0 and valeurs[i + 1] > 0]
    if len(pas) < 3:
        return CROISSANCE_MEDIANE, "tendance générale"
    mesure = statistics.median(pas[-3:])
    borne = min(BORNE_HAUTE, max(BORNE_BASSE, mesure))
    return borne, ("mesurée" if abs(borne - mesure) < 1e-9 else "mesurée puis bornée")


def extrapoler_pourcentage(profil, dernier, pourcents):
    """Les trois rangs d'un sort dont la puissance est un pourcentage.

    ATTENTION à la convention de stockage : avec un dé à une face, la valeur
    réelle vaut base + 1. « Réduit de 50 % » est donc écrit -51, et +20 % est
    écrit 19. On applique le facteur à la valeur RÉELLE, puis on réécrit.
    """
    nouveaux = []
    for n, facteur in enumerate(POURCENTAGE_PAR_RANG, start=1):
        effets = []
        for e in dernier["effets"]:
            neuf = dict(e)
            if e["n"] in pourcents:
                reel = e["base"] + 1
                signe = -1 if reel < 0 else 1
                neuf["base"] = signe * int(round(abs(reel) * facteur)) - 1
            effets.append(neuf)
        nouveaux.append({
            "rang": len(profil) + n,
            "modele": dernier["spell"],
            "niveau": dernier["niveau"],
            "cout": dernier["cout"],
            "effets": effets,
            "ampleur": max([abs(e["base"] + 1) for e in effets
                            if e["n"] in pourcents] or [0.0]),
        })
    return {"taux": facteur, "origine_taux": "pourcentage +15/30/50 %",
            "effets_a_echelle": sorted(pourcents),
            "ampleur_derniere": max([abs(e["base"] + 1) for e in dernier["effets"]
                                     if e["n"] in pourcents] or [0.0]),
            "rangs": nouveaux}


def extrapoler_sous_sort(profil, dernier):
    """Le sort ne porte rien mais en déclenche un autre : on monte celui-là.

    La chaîne des sorts déclenchés suit celle du sort principal — Estropier
    rang 5 appelle un sort de main à 152, le rang 6 un autre à 180. On mesure
    donc la croissance sur cette chaîne parallèle.
    """
    porteurs = [e for e in dernier["effets"]
                if e.get("sous_sort") and ampleur(e["sous_sort"]) > 0]
    if not porteurs:
        return None

    # Courbe du sous-sort, rang par rang du sort principal.
    valeurs = []
    for rang in profil:
        v = [ampleur(e["sous_sort"]) for e in rang["effets"]
             if e.get("sous_sort") and ampleur(e["sous_sort"]) > 0]
        valeurs.append(max(v) if v else 0.0)

    pas = [valeurs[i + 1] / valeurs[i]
           for i in range(len(valeurs) - 1) if valeurs[i] > 0 and valeurs[i + 1] > 0]
    if len(pas) >= 3:
        mesure = statistics.median(pas[-3:])
        # Une valeur qui ne bouge quasiment pas d'un rang à l'autre n'est pas une
        # puissance : les Météores logent là l'identifiant du sort qu'ils
        # appellent, 53193 puis 53194. On refuse plutôt que de fabriquer un
        # identifiant qui n'existe pas.
        if mesure < CROISSANCE_MINIMALE:
            return None
        taux = min(BORNE_HAUTE, max(BORNE_BASSE, mesure))
        origine = "sous-sort, mesurée"
    else:
        taux, origine = CROISSANCE_MEDIANE, "sous-sort, tendance générale"

    nouveaux = []
    references = {e["n"]: dict(e["sous_sort"]) for e in porteurs}
    for n in range(1, RANGS_A_CREER + 1):
        sous = {}
        for numero, ref in references.items():
            effets = []
            for e in ref["effets"]:
                neuf = dict(e)
                if a_echelle_par_defaut(e) and e["base"]:
                    signe = -1 if e["base"] < 0 else 1
                    neuf["base"] = signe * max(abs(e["base"]) + 1,
                                               int(abs(e["base"]) * taux + 0.5))
                effets.append(neuf)
            sous[numero] = {"modele": ref["spell"], "nom": ref["nom"], "effets": effets}
            references[numero] = {**ref, "effets": effets}
        nouveaux.append({
            "rang": len(profil) + n,
            "modele": dernier["spell"],
            "niveau": dernier["niveau"],
            "cout": dernier["cout"],
            "effets": [dict(e) for e in dernier["effets"]],
            "sous_sorts": sous,
            "ampleur": max(ampleur({"effets": v["effets"]}) for v in sous.values()),
        })

    return {"taux": round(taux, 3), "origine_taux": origine,
            "effets_a_echelle": sorted(references),
            "ampleur_derniere": round(max(ampleur(e["sous_sort"]) for e in porteurs), 1),
            "rangs": nouveaux}


def extrapoler(sort):
    profil = sort["profil"]
    if not profil:
        return None
    dernier = profil[-1]

    if sort.get("nom") in POURCENTAGES_NOMMES:
        porteurs = {e["n"] for e in dernier["effets"] if abs(e["base"] + 1) >= 1}
        if porteurs:
            return extrapoler_pourcentage(profil, dernier, porteurs)

    retenus = variables(profil)
    if not retenus:
        # Rang unique, ou aucun effet n'a bougé : on retombe sur les types
        # connus pour porter une valeur.
        retenus = {e["n"] for e in dernier["effets"] if a_echelle_par_defaut(e)}

    # Rien de chiffré ne bouge, mais le sort porte un pourcentage : c'est le cas
    # que la règle des +15/30/50 traite.
    pourcents = {e["n"] for e in dernier["effets"] if est_pourcentage(e)}
    if ampleur(dernier, retenus) == 0 and pourcents:
        return extrapoler_pourcentage(profil, dernier, pourcents)

    # Toujours rien, mais le sort en DÉCLENCHE un autre : c'est là qu'est la
    # puissance. On mesure la courbe du sort appelé et on la fait monter — il
    # faudra cloner les deux et faire pointer le neuf sur le neuf.
    if ampleur(dernier, retenus) == 0:
        sous = extrapoler_sous_sort(profil, dernier)
        if sous:
            return sous

    taux, origine_taux = croissance(profil, retenus)

    nouveaux = []
    reference = dernier
    for n in range(1, RANGS_A_CREER + 1):
        effets = []
        for e in reference["effets"]:
            neuf = dict(e)
            if e["n"] in retenus:
                # Arrondi au plus proche, mais jamais en dessous du rang
                # précédent : un rang supérieur ne doit pas valoir moins.
                signe = -1 if e["base"] < 0 else 1
                monte = max(abs(e["base"]) + 1, int(abs(e["base"]) * taux + 0.5))
                neuf["base"] = signe * monte if e["base"] else e["base"]
                if e["des"] > 1:
                    neuf["des"] = max(e["des"] + 1, int(e["des"] * taux + 0.5))
            effets.append(neuf)
        rang = {
            "rang": len(profil) + n,
            "modele": dernier["spell"],
            "niveau": dernier["niveau"],
            "cout": dernier["cout"],
            "effets": effets,
        }
        rang["ampleur"] = ampleur(rang, retenus)
        nouveaux.append(rang)
        reference = rang

    return {"taux": round(taux, 3), "origine_taux": origine_taux,
            "effets_a_echelle": sorted(retenus),
            "ampleur_derniere": round(ampleur(dernier, retenus), 1),
            "rangs": nouveaux}


def valeur_identifiante(profil, numero):
    """Vrai si le sous-sort de cet effet porte un IDENTIFIANT, pas une puissance.

    Le signe est le meme que celui retenu par `extrapoler_sous_sort` : une
    valeur qui ne bouge quasiment pas d'un rang a l'autre tout en restant non
    nulle. Les Meteores logent la le sort de degats qu'ils appellent, 53193 puis
    53194 ; lui ajouter un bonus plat ferait appeler un sort quelconque —
    « Crystal of Unstable Energy », constate en jeu le 2026-08-26.
    """
    serie = []
    for rang in profil:
        for e in rang["effets"]:
            if e["n"] != numero:
                continue
            ss = e.get("sous_sort")
            if not ss:
                continue
            v = max((abs(x["base"]) for x in ss["effets"]
                     if x["type"] in TYPES_A_ECHELLE), default=0)
            if v:
                serie.append(v)
    if len(serie) < 2:
        return False
    pas = [serie[i + 1] / serie[i] for i in range(len(serie) - 1) if serie[i]]
    if not pas:
        return False
    # La MEDIANE, pas le maximum : deux identifiants consecutifs ne se suivent
    # pas forcement. Les Meteores passent de 50287 a 53190 — +5,8 % — puis a
    # 53193 et 53194, ou plus rien ne bouge. Meme statistique que le garde-fou
    # de extrapoler_sous_sort, pour que les deux disent la meme chose.
    return statistics.median(pas[-3:]) < CROISSANCE_MINIMALE


def bonus_plat(profil, dernier, reference, taux_classe):
    """Sorts dont rien n'est chiffrable : on leur invente un bonus PLAT.

    Le montant n'est pas tiré au hasard : c'est ce qu'un rang apporte
    habituellement dans la classe — la valeur médiane de ses sorts chiffrables
    multipliée par sa croissance médiane moins un. Un guerrier gagne ainsi +61,
    puis +76, puis +95, ce qui est l'ordre de grandeur de la Frappe héroïque,
    dont un rang vaut « dégâts d'arme + 494 ».

    Le bonus se pose sur le premier effet capable de porter une valeur — de
    préférence un effet de dégâts, sur le sort lui-même ou sur celui qu'il
    déclenche.
    """
    cible = next((e for e in dernier["effets"] if e["type"] in TYPES_A_ECHELLE), None)
    # TOUS les effets qui declenchent un sort chiffrable, pas seulement le
    # premier : Frappe-tempete en a deux, la main droite et la main gauche, et
    # n'en servir qu'une donnerait un rang bancal. Les identifiants sont
    # ecartes : ce ne sont pas des puissances.
    porteurs = []
    if not cible:
        for e in dernier["effets"]:
            ss = e.get("sous_sort")
            if not ss or not any(x["type"] in TYPES_A_ECHELLE for x in ss["effets"]):
                continue
            if valeur_identifiante(profil, e["n"]):
                continue
            porteurs.append((e, ss))
        if porteurs:
            cible = porteurs[0][0]
    if not cible:
        return None

    nouveaux = []
    montant = reference
    for n in range(1, RANGS_A_CREER + 1):
        effets = [dict(e) for e in dernier["effets"]]
        if porteurs:
            sous_sorts = {}
            for e_porteur, ss in porteurs:
                copie = {"modele": ss["spell"], "nom": ss["nom"],
                         "effets": [dict(x) for x in ss["effets"]]}
                for x in copie["effets"]:
                    if x["type"] in TYPES_A_ECHELLE:
                        x["base"] = x["base"] + int(round(montant))
                        break
                sous_sorts[e_porteur["n"]] = copie
        else:
            sous_sorts = None
            for e in effets:
                if e["n"] == cible["n"]:
                    e["base"] = e["base"] + int(round(montant))
                    break
        rang = {"rang": len(profil) + n, "modele": dernier["spell"],
                "niveau": dernier["niveau"], "cout": dernier["cout"],
                "effets": effets, "ampleur": round(montant, 1)}
        if sous_sorts:
            rang["sous_sorts"] = sous_sorts
        nouveaux.append(rang)
        montant *= taux_classe

    return {"taux": round(taux_classe, 3), "origine_taux": "bonus plat de classe",
            "effets_a_echelle": sorted(e["n"] for e, _ in porteurs) or [cible["n"]],
            "ampleur_derniere": 0.0, "rangs": nouveaux}


courbes = json.load(io.open(COURBES, encoding="utf-8"))

# Premier passage : ce qu'un rang vaut dans chaque classe, mesuré sur ses sorts
# chiffrables. Sert de référence aux sorts qui n'ont rien à faire croître.
premier = {classe: [extrapoler(s) for s in liste] for classe, liste in courbes.items()}
REFERENCE = {}
for classe, liste in premier.items():
    vals = [e["ampleur_derniere"] for e in liste if e and e["ampleur_derniere"] > 0]
    taux = [e["taux"] for e in liste if e and e["ampleur_derniere"] > 0 and e["taux"] < 2]
    if vals:
        v, g = statistics.median(vals), statistics.median(taux)
        REFERENCE[classe] = (v * (g - 1), g)

resultat = {}
mesures, generales, plats = 0, 0, 0
for classe, liste in courbes.items():
    resultat[classe] = []
    for s, ext in zip(liste, premier[classe]):
        if ext and ext["ampleur_derniere"] == 0 and classe in REFERENCE:
            remplacement = bonus_plat(s["profil"], s["profil"][-1], *REFERENCE[classe])
            if remplacement:
                ext = remplacement
        if not ext:
            continue
        if ext["origine_taux"] == "bonus plat de classe":
            plats += 1
        elif ext["origine_taux"] == "tendance générale":
            generales += 1
        else:
            mesures += 1
        resultat[classe].append({
            "nom": s["nom"], "origine": s["origine"], "famille": s["famille"],
            "rangs_existants": s["rangs"],
            "dernier_spell": s["profil"][-1]["spell"],
            "parallele": s.get("parallele", False),
            "parent": s.get("parent"),
            **ext,
        })

with io.open(SORTIE, "w", encoding="utf-8") as f:
    json.dump(resultat, f, ensure_ascii=False, indent=1)

total = sum(len(v) for v in resultat.values())
print("rangs_extrapoles.json écrit")
print("  %d sorts, %d rangs créés" % (total, total * RANGS_A_CREER))
print("  %d avec leur croissance propre, %d à la tendance générale, %d au bonus plat"
      % (mesures, generales, plats))
restants = [(c, d["nom"]) for c, l in resultat.items() for d in l
            if d["origine_taux"] != "bonus plat de classe" and d["ampleur_derniere"] == 0]
if restants:
    print("  %d sorts restent sans rien : %s"
          % (len(restants), ", ".join("%s/%s" % r for r in restants)))
