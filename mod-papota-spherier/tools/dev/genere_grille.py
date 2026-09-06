# -*- coding: utf-8 -*-
r"""Fabrique la disposition complète d'une classe : clusters, places, liaisons.

Écrit d'après la grille du guerrier telle que vous l'avez retouchée. Trois
enseignements en sont tirés, et ils commandent tout :

**UN CLUSTER EST UN ARBRE.** Vous avez retiré cent liaisons de mes nexus, de tous
genres — arcs, rayons, diagonales —, jusqu'à ce que plus aucune boucle interne ne
subsiste : vingt clusters sur vingt-neuf sont des arbres exacts. Une boucle offre
deux chemins vers la même place et défait le labyrinthe ; on tire donc un arbre
couvrant au hasard plutôt que de poser des liaisons par règle.

**UN TRAIT PEUT ALLER OÙ IL VEUT S'IL PASSE AU LARGE.** Vos ajouts comprennent
une corde de diamètre et trois sauts d'anneau — des traits que la règle de
l'éditeur n'aurait jamais posés, et qui sont propres parce que la place du milieu
est absente. Le critère n'est donc pas le genre du trait mais son DÉGAGEMENT :
tout couple de places est candidat pourvu que le segment reste à distance des
autres. Le plus serré que vous ayez gardé passe à cinquante pixels.

**CHAQUE CLUSTER A SON VISAGE.** Les vôtres vont de onze à vingt-cinq places, avec
des anneaux pleins, troués, des secteurs, des couronnes seules. On tire donc le
motif d'occupation au sort parmi une dizaine de familles, puis on le troue.

Le départ est au CENTRE de la grille : la place centrale du cluster central.

    python genere_grille.py paladin 2
"""
import io
import math
import os
import random
import sys
from collections import defaultdict, deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import profils_classes

sys.stdout.reconfigure(encoding="utf-8")

LAYOUTS = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\lua_scripts\Spherier\layouts"
RAYONS = {0: 0.0, 1: 1.1, 2: 2.1, 3: 3.1}
BRANCHES = 8

PAS = 8.0                 # écart entre deux clusters voisins du maillage
NB_SLOTS = 8
NB_SORTS = 3

# --- la taille de la grille -------------------------------------------------
# Le total de points ne dépend que du nombre de pierres et de la pyramide des
# qualités ; il se partage ensuite entre les statistiques utiles. Pour que
# chacune en reçoive POINTS_VISES, il faut donc autant de pierres que la classe
# a de statistiques : une grille de mage n'a pas à être aussi vaste qu'une
# grille de druide.
POINTS_VISES = 300
# Ce que rapporte une pierre en moyenne, sous la pyramide 48/29/15/8 et les
# montants 5/7/10/15/30, plus ce qu'ajoutent les légendaires promues.
POINTS_PAR_PIERRE = 7.13
BONUS_LEGENDAIRES = 120
NB_VIDES = 35             # comme la grille du guerrier
PLACES_PAR_CLUSTER = 17.4
CLUSTERS_MIN, CLUSTERS_MAX = 18, 32


def dimensions(classe):
    """Combien de places et de clusters pour que chaque statistique ait son dû."""
    stats = len(profils_classes.CLASSES[classe]["utiles"])
    pierres = max(120, int(round((POINTS_VISES * stats - BONUS_LEGENDAIRES)
                                 / POINTS_PAR_PIERRE)))
    places = pierres + NB_VIDES
    clusters = min(CLUSTERS_MAX, max(CLUSTERS_MIN,
                                     int(round(places / PLACES_PAR_CLUSTER))))
    return places, clusters, stats
# Un trait interne doit rester à cette distance de toute place qu'il ne relie
# pas. Le plus serré de la grille du guerrier passe à 0,78 ; en deçà de 0,70 le
# trait frôle la place et le dessin se brouille.
DEGAGEMENT = 0.70
# Au-delà, un trait traverse tout le cluster et ne se lit plus comme un couloir.
LONGUEUR_MAX = 2.50
# Part des clusters coupés en deux réseaux qui ne communiquent pas.
PART_DIVISES = 0.20
# Longueur maximale d'un pont. Les plus longs de la grille du guerrier font sept
# unités ; au-delà, le trait ne relie plus deux voisins, il traverse le vide.
PONT_MAX = 7.0


# ---------------------------------------------------------------------------
# Les motifs d'occupation
# ---------------------------------------------------------------------------
# Chacun rend la liste des places occupées. Ils sont tirés au sort, puis troués :
# c'est de là que vient la variété d'un cluster à l'autre.
def motif_plein(de):
    return [(r, b) for r in (1, 2, 3) for b in range(1, 9)]


def motif_secteurs(de):
    """Deux ou trois secteurs de branches contiguës, séparés par des murs."""
    largeur = de.choice((2, 3, 3, 4))
    depart = de.randint(1, 8)
    combien = de.choice((2, 2, 3))
    gardees = set()
    for k in range(combien):
        base = (depart + k * (8 // combien) - 1) % 8 + 1
        for j in range(largeur):
            gardees.add((base + j - 1) % 8 + 1)
    return [(r, b) for r in (1, 2, 3) for b in sorted(gardees)]


def motif_couronnes(de):
    """Une ou deux couronnes seulement — le cœur reste vide."""
    anneaux = de.choice(((1, 3), (2, 3), (1, 2), (3,), (1, 3)))
    return [(r, b) for r in anneaux for b in range(1, 9)]


def motif_rayons(de):
    """Des rayons complets, une branche sur deux ou sur trois."""
    pas = de.choice((2, 2, 3))
    depart = de.randint(1, 8)
    bs = sorted(set((depart + k * pas - 1) % 8 + 1 for k in range(8 // pas + 1)))
    return [(0, 1)] + [(r, b) for r in (1, 2, 3) for b in bs]


def motif_spirale(de):
    """Chaque anneau occupe un arc, décalé d'un cran sur le suivant."""
    depart = de.randint(1, 8)
    largeur = de.choice((4, 5, 5, 6))
    places = []
    for r in (1, 2, 3):
        for j in range(largeur):
            places.append((r, (depart + (r - 1) * 2 + j - 1) % 8 + 1))
    return places


def motif_croissant(de):
    """Une couronne extérieure pleine, un cœur réduit."""
    petit = de.sample(range(1, 9), de.randint(2, 4))
    return [(0, 1)] + [(1, b) for b in petit] + \
           [(2, b) for b in de.sample(range(1, 9), de.randint(4, 7))] + \
           [(3, b) for b in range(1, 9)]


def motif_noyau(de):
    """L'inverse : un cœur dense, quelques dents vers le bord."""
    dents = de.sample(range(1, 9), de.randint(2, 4))
    return [(0, 1)] + [(1, b) for b in range(1, 9)] + \
           [(2, b) for b in de.sample(range(1, 9), de.randint(5, 8))] + \
           [(3, b) for b in dents]


def motif_demi(de):
    """Une moitié du cluster, franchement coupée."""
    depart = de.randint(1, 8)
    bs = [(depart + j - 1) % 8 + 1 for j in range(de.choice((4, 5)))]
    return [(0, 1)] + [(r, b) for r in (1, 2, 3) for b in bs]


def motif_damier(de):
    """Une branche sur deux, décalée d'un anneau à l'autre."""
    depart = de.randint(1, 8)
    places = []
    for r in (1, 2, 3):
        for k in range(4):
            places.append((r, (depart + (r % 2) + 2 * k - 1) % 8 + 1))
    return places


MOTIFS = [motif_plein, motif_secteurs, motif_couronnes, motif_rayons,
          motif_spirale, motif_croissant, motif_noyau, motif_demi, motif_damier]


# ---------------------------------------------------------------------------
def position(x, y, anneau, branche):
    r = RAYONS[anneau]
    a = (branche - 1) * 2 * math.pi / BRANCHES
    return x + r * math.cos(a), y + r * math.sin(a)


def pos_locale(place):
    return position(0.0, 0.0, place[0], place[1])


def degagement(a, b, places):
    """Distance du segment a-b à la place la plus proche qu'il ne relie pas."""
    (ax, ay), (bx, by) = pos_locale(a), pos_locale(b)
    dx, dy = bx - ax, by - ay
    long2 = dx * dx + dy * dy
    pire = 99.0
    for p in places:
        if p == a or p == b:
            continue
        px, py = pos_locale(p)
        t = 0.0 if long2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / long2))
        pire = min(pire, math.hypot(px - (ax + t * dx), py - (ay + t * dy)))
    return pire


def candidats(places):
    """Tout couple de places qu'un trait peut relier proprement.

    Ni le genre du trait ni la règle de l'éditeur n'entrent en compte : seules
    comptent sa longueur et le fait qu'il passe au large des autres places.
    """
    liste = sorted(places)
    out = []
    for i in range(len(liste)):
        for j in range(i + 1, len(liste)):
            a, b = liste[i], liste[j]
            (ax, ay), (bx, by) = pos_locale(a), pos_locale(b)
            L = math.hypot(bx - ax, by - ay)
            if L > LONGUEUR_MAX or L < 1e-9:
                continue
            if degagement(a, b, places) < DEGAGEMENT:
                continue
            out.append((L, a, b))
    return out


def arbre(places, aretes, de):
    """Un arbre couvrant tiré au hasard, les traits courts favorisés.

    Kruskal sur des poids brouillés : la longueur donne le fond — un cluster
    reste lisible —, le hasard donne le visage.
    """
    poids = sorted((L * de.uniform(0.6, 1.8), a, b) for (L, a, b) in aretes)
    pere = dict((p, p) for p in places)

    def racine(p):
        while pere[p] != p:
            pere[p] = pere[pere[p]]
            p = pere[p]
        return p

    pris = []
    for _, a, b in poids:
        ra, rb = racine(a), racine(b)
        if ra != rb:
            pere[ra] = rb
            pris.append((a, b))
    return pris


def morceaux(places, liens):
    vois = defaultdict(list)
    for a, b in liens:
        vois[a].append(b)
        vois[b].append(a)
    vus, blocs = set(), []
    for p in sorted(places):
        if p in vus:
            continue
        bloc, f = {p}, deque([p])
        while f:
            n = f.popleft()
            for m in vois[n]:
                if m not in bloc:
                    bloc.add(m)
                    f.append(m)
        vus |= bloc
        blocs.append(sorted(bloc))
    return blocs


def fabrique_cluster(de, divise, vise=17):
    """Les places d'un cluster et son réseau : un arbre, ou deux si divisé.

    `vise` est la taille demandée ; on l'accepte à quatre places près, ce qui
    laisse aux motifs de quoi respirer sans laisser filer le total.
    """
    bas, haut = max(10, vise - 4), min(25, vise + 4)
    for essai in range(60):
        places = sorted(set(de.choice(MOTIFS)(de)))
        # On troue : c'est ce qui écarte deux clusters de même motif. Peu, en
        # revanche — un premier réglage vidait les clusters à quinze places de
        # moyenne quand la grille du guerrier en compte vingt.
        # On troue jusqu'à la mesure demandée, et un peu au-delà pour la variété.
        while len(places) > haut:
            p = de.choice([q for q in places if q[0] != 0] or places)
            places.remove(p)
        creux = de.randint(0, max(0, (len(places) - bas) // 3))
        for _ in range(creux):
            p = de.choice([q for q in places if q[0] != 0] or places)
            places.remove(p)
        if not (bas <= len(places) <= haut):
            continue
        aretes = candidats(places)
        if not aretes:
            continue
        if not divise:
            liens = arbre(places, aretes, de)
            if len(morceaux(places, liens)) == 1:
                return places, liens, 1
            continue
        # Divisé : deux réseaux qui ne communiquent pas. On coupe par branches,
        # ce qui donne deux moitiés franches plutôt que deux miettes.
        coupe = de.randint(1, 8)
        moitie = set((coupe + j - 1) % 8 + 1 for j in range(4))
        A = [p for p in places if p[0] != 0 and p[1] in moitie]
        B = [p for p in places if p[0] != 0 and p[1] not in moitie]
        if len(A) < 5 or len(B) < 5:
            continue
        places = sorted(A + B)
        liens = []
        ok = True
        for part in (A, B):
            ar = [(L, a, b) for (L, a, b) in candidats(part)]
            if not ar:
                ok = False
                break
            t = arbre(part, ar, de)
            if len(morceaux(part, t)) != 1:
                ok = False
                break
            liens += t
        if ok and bas <= len(places) <= haut:
            return places, liens, 2
    return None


# ---------------------------------------------------------------------------
# Le maillage des clusters
# ---------------------------------------------------------------------------
def maillage(de, combien):
    """Des cellules d'un quadrillage de pas 8, autour du centre.

    Toutes alignées entre elles par construction — même abscisse, même ordonnée
    ou diagonale exacte —, et le centre en fait toujours partie : c'est là que le
    départ se pose.
    """
    cellules = [(i, j) for i in range(-3, 4) for j in range(-3, 4)
                if i * i + j * j <= 10]
    de.shuffle(cellules)
    cellules.sort(key=lambda c: (c != (0, 0), c[0] * c[0] + c[1] * c[1]))
    return cellules[:combien]


def voisines(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1])) == 1


def morceaux_cellules(cells, aretes):
    vois = defaultdict(list)
    for a, b in aretes:
        vois[a].append(b)
        vois[b].append(a)
    vus, blocs = set(), []
    for c in cells:
        if c in vus:
            continue
        bloc, f = {c}, deque([c])
        while f:
            n = f.popleft()
            for m in vois[n]:
                if m not in bloc:
                    bloc.add(m)
                    f.append(m)
        vus |= bloc
        blocs.append(bloc)
    return blocs


def graphe_clusters(cells, de, mesure=None):
    """Les ponts : un arbre couvrant, plus quelques boucles.

    Un arbre seul ferait de la grille entière un labyrinthe sans retour ; les
    boucles se posent entre clusters, jamais dedans.

    `mesure` rend la longueur du pont le plus court entre deux clusters : les
    trop longs sont écartés d'emblée. Si cela coupe la grille, on relâche — mieux
    vaut un pont long qu'un morceau inatteignable.
    """
    aretes = [(a, b) for i, a in enumerate(cells) for b in cells[i + 1:]
              if voisines(a, b)]
    if mesure:
        courts = [(a, b) for (a, b) in aretes if mesure(a, b) <= PONT_MAX]
        if len(morceaux_cellules(cells, courts)) == 1:
            aretes = courts
        else:
            aretes = sorted(aretes, key=lambda e: mesure(*e))
    de.shuffle(aretes)
    pere = dict((c, c) for c in cells)

    def racine(p):
        while pere[p] != p:
            pere[p] = pere[pere[p]]
            p = pere[p]
        return p

    pris, restants = [], []
    for a, b in aretes:
        ra, rb = racine(a), racine(b)
        if ra != rb:
            pere[ra] = rb
            pris.append((a, b))
        else:
            restants.append((a, b))
    de.shuffle(restants)
    pris += restants[:int(len(pris) * 0.35)]
    return pris




# ---------------------------------------------------------------------------
# Assemblage
# ---------------------------------------------------------------------------
def bati(de, divise, vise):
    """Insiste jusqu'à obtenir un cluster valable : les motifs sont tirés au
    sort, et tous ne se prêtent pas à toutes les contraintes."""
    while True:
        r = fabrique_cluster(de, divise, vise)
        if r:
            return r


def ajoute_centre(places, liens):
    """Pose la place centrale et la rattache au premier anneau, comme l'éditeur.

    Elle ne change pas le nombre de morceaux : elle s'accroche à l'un d'eux.
    """
    if (0, 1) in places:
        return places, liens
    voisin = sorted(((math.hypot(*pos_locale(q)), q) for q in places if q[0] == 1))
    if not voisin:
        voisin = sorted(((math.hypot(*pos_locale(q)), q) for q in places))
    return sorted(places + [(0, 1)]), liens + [((0, 1), voisin[0][1])]


def fabrique(nom, graine):
    de = random.Random(graine)
    places_visees, combien, _stats = dimensions(nom)
    vise = int(round(places_visees / float(combien)))
    cells = maillage(de, combien)
    centre = (0, 0)

    # 1. Les clusters d'abord, entiers. Il faut les connaître pour mesurer les
    #    ponts, et les ponts pour savoir lesquels peuvent se permettre d'être
    #    divisés — deux morceaux réclament chacun le leur.
    # Les motifs rendent en moyenne un peu moins que la mesure demandée — ils
    # se troublent plus volontiers qu'ils ne se remplissent. On corrige le tir
    # plutôt que d'espérer : on bâtit, on compte, et l'on relance d'un cran tant
    # que le total reste sous la cible.
    places_de, liens_de = {}, {}
    for essai in range(6):
        de2 = random.Random(graine * 1000 + essai)
        places_de, liens_de = {}, {}
        for c in cells:
            places_de[c], liens_de[c], _ = bati(de2, False, vise + essai)
        total = sum(len(places_de[c]) for c in cells)
        if total >= places_visees * 0.97:
            break

    def mesure(a, b):
        court = 99.0
        for pa in places_de[a]:
            ax, ay = position(a[0] * PAS, a[1] * PAS, pa[0], pa[1])
            for pb in places_de[b]:
                bx, by = position(b[0] * PAS, b[1] * PAS, pb[0], pb[1])
                court = min(court, math.hypot(ax - bx, ay - by))
        return court

    ponts = graphe_clusters(cells, de, mesure)
    ponts_de = defaultdict(list)
    for e in ponts:
        ponts_de[e[0]].append(e)
        ponts_de[e[1]].append(e)

    # 2. Les emplacements de sort aux trois extrémités, les slots ailleurs. La
    #    place centrale s'ajoute là où le motif ne l'avait pas tirée : exiger
    #    qu'elle y soit déjà ne laissait que neuf clusters pour onze emplacements.
    bord = [c for c in cells if c != centre]
    sorts = []
    for cible in (90.0, 210.0, 330.0):
        meilleur = None
        for c in bord:
            if c in sorts:
                continue
            a = math.degrees(math.atan2(c[1], c[0])) % 360.0
            ecart = abs((a - cible + 180.0) % 360.0 - 180.0)
            note = ecart - 6.0 * math.hypot(c[0], c[1])
            if meilleur is None or note < meilleur[0]:
                meilleur = (note, c)
        sorts.append(meilleur[1])
    restants = [c for c in bord if c not in sorts]
    de.shuffle(restants)
    slots = restants[:NB_SLOTS]

    # 3. Les divisions, là où il y a de quoi nourrir les deux moitiés.
    divisibles = [c for c in cells if c != centre and len(ponts_de[c]) >= 4]
    de.shuffle(divisibles)
    for c in divisibles[:int(len(cells) * PART_DIVISES)]:
        places_de[c], liens_de[c], _ = bati(de, True, vise)

    def repartit(morceaux_de):
        """À quel morceau chaque pont s'accroche.

        Chaque morceau en reçoit un d'abord — sans quoi il resterait sans issue —
        puis on raccourcit : on énumère les répartitions d'un cluster divisé, au
        plus deux cent cinquante-six, et l'on retient la plus courte qui serve
        les deux moitiés. Un pont touchant deux clusters, on repasse.
        """
        part = {}
        for c in cells:
            for k, e in enumerate(ponts_de[c]):
                part[(c, e)] = k % len(morceaux_de[c])

        def longueur(e, ia, ib):
            ca, cb = e
            court = 99.0
            for pa in morceaux_de[ca][ia]:
                ax, ay = position(ca[0] * PAS, ca[1] * PAS, pa[0], pa[1])
                for pb in morceaux_de[cb][ib]:
                    bx, by = position(cb[0] * PAS, cb[1] * PAS, pb[0], pb[1])
                    court = min(court, math.hypot(ax - bx, ay - by))
            return court

        for _ in range(6):
            bouge = False
            for c in cells:
                n = len(morceaux_de[c])
                liste = ponts_de[c]
                if n < 2 or len(liste) > 10:
                    continue
                actuel = tuple(part[(c, e)] for e in liste)
                meilleur, note = actuel, None
                for combo in range(n ** len(liste)):
                    choix, reste = [], combo
                    for _k in liste:
                        choix.append(reste % n)
                        reste //= n
                    if len(set(choix)) < n:
                        continue
                    total = sum(
                        longueur(e, m if e[0] == c else part[(e[0], e)],
                                 part[(e[1], e)] if e[0] == c else m)
                        for e, m in zip(liste, choix))
                    if note is None or total < note - 1e-9:
                        note, meilleur = total, tuple(choix)
                if meilleur != actuel:
                    for e, m in zip(liste, meilleur):
                        part[(c, e)] = m
                    bouge = True
            if not bouge:
                break
        return part

    def coupures(morceaux_de, part):
        """Les clusters dont un morceau n'est pas atteignable depuis le départ.

        Le graphe des ponts est connexe entre CLUSTERS ; diviser un cluster le
        dédouble, et rien ne garantit que ses deux moitiés restent du même côté.
        C'est le piège de la division, et il se paie par une région entière
        coupée du reste — cent quatre-vingt-sept places, la première fois.
        """
        vois = defaultdict(list)
        for e in ponts:
            ca, cb = e
            vois[(ca, part[(ca, e)])].append((cb, part[(cb, e)]))
            vois[(cb, part[(cb, e)])].append((ca, part[(ca, e)]))
        depuis = None
        for i, m in enumerate(morceaux_de[centre]):
            if (0, 1) in m:
                depuis = (centre, i)
        vus, f = {depuis}, deque([depuis])
        while f:
            n = f.popleft()
            for m in vois[n]:
                if m not in vus:
                    vus.add(m)
                    f.append(m)
        return sorted((c for c in cells for i in range(len(morceaux_de[c]))
                       if (c, i) not in vus),
                      key=lambda c: -len(ponts_de[c]))

    # 4. On défait une division tant que la grille reste coupée. Défaire ne peut
    #    que rapprocher : au pire la boucle s'arrête quand plus rien n'est divisé.
    morceaux_de, part = None, None
    for _ in range(len(cells) + 1):
        places_de[centre], liens_de[centre] = ajoute_centre(places_de[centre],
                                                            liens_de[centre])
        for c in sorts + slots:
            places_de[c], liens_de[c] = ajoute_centre(places_de[c], liens_de[c])
        morceaux_de = dict((c, morceaux(places_de[c], liens_de[c])) for c in cells)
        part = repartit(morceaux_de)
        mauvais = [c for c in coupures(morceaux_de, part)
                   if len(morceaux_de[c]) > 1]
        if not mauvais:
            break
        places_de[mauvais[0]], liens_de[mauvais[0]], _ = bati(de, False, vise)

    return (cells, ponts, ponts_de, places_de, liens_de, morceaux_de, part,
            sorts, slots)


def ecrit(nom, graine):
    (cells, ponts, ponts_de, places_de, liens_de, morceaux_de, part,
     sorts, slots) = fabrique(nom, graine)

    clusters = dict((c, k + 1) for k, c in enumerate(cells))
    ids, idn = {}, 1
    for c in cells:
        for p in places_de[c]:
            ids[(c, p)] = idn
            idn += 1

    types = {}
    for c in sorts:
        types[(c, (0, 1))] = 'type="sort" sort="0"'
    for c in slots:
        types[(c, (0, 1))] = 'type="slot"'

    lignes_cl, lignes_em, lignes_li = [], [], []
    for c in cells:
        lignes_cl.append('    <cluster id="%d" x="%.4f" y="%.4f" rot="0.0000"/>'
                         % (clusters[c], c[0] * PAS, c[1] * PAS))
        for p in places_de[c]:
            lignes_em.append('    <emplacement id="%d" cluster="%d" anneau="%d" '
                             'branche="%d" %s/>'
                             % (ids[(c, p)], clusters[c], p[0], p[1],
                                types.get((c, p), 'type="noeud"')))
        for a, b in liens_de[c]:
            lignes_li.append('    <liaison a="%d" b="%d"/>'
                             % (ids[(c, a)], ids[(c, b)]))

    longueurs = []
    for e in ponts:
        ca, cb = e
        meilleur = None
        for pa in morceaux_de[ca][part[(ca, e)]]:
            ax, ay = position(ca[0] * PAS, ca[1] * PAS, pa[0], pa[1])
            for pb in morceaux_de[cb][part[(cb, e)]]:
                bx, by = position(cb[0] * PAS, cb[1] * PAS, pb[0], pb[1])
                d = math.hypot(ax - bx, ay - by)
                if meilleur is None or d < meilleur[0]:
                    meilleur = (d, pa, pb)
        d, pa, pb = meilleur
        longueurs.append(d)
        lignes_li.append('    <liaison a="%d" b="%d"/>'
                         % (ids[(ca, pa)], ids[(cb, pb)]))

    corps = ('<?xml version="1.0" encoding="UTF-8"?>\n'
             '<spherier version="1" nom="%s">\n'
             '  <clusters>\n%s\n  </clusters>\n'
             '  <emplacements>\n%s\n  </emplacements>\n'
             '  <liaisons>\n%s\n  </liaisons>\n'
             '  <depart id="%d"/>\n'
             '</spherier>\n'
             % (nom, "\n".join(lignes_cl), "\n".join(lignes_em),
                "\n".join(lignes_li), ids[((0, 0), (0, 1))]))
    io.open(os.path.join(LAYOUTS, nom + ".xml"), "w",
            encoding="utf-8", newline="\n").write(corps)
    return (len(cells), len(lignes_em), len(lignes_li), ids[((0, 0), (0, 1))],
            len([c for c in cells if len(morceaux_de[c]) > 1]),
            min(longueurs), max(longueurs))


if __name__ == "__main__":
    nom, graine = sys.argv[1], int(sys.argv[2])
    vise, combien, stats = dimensions(nom)
    nc, ne, nl, dep, div, lmin, lmax = ecrit(nom, graine)
    print("%-11s %2d stats -> %3d places visées en %2d clusters ; obtenu "
          "%2d clusters (%d divisés), %3d emplacements, %3d liaisons, "
          "ponts %.1f..%.1f"
          % (nom, stats, vise, combien, nc, div, ne, nl, lmin, lmax))
