# -*- coding: utf-8 -*-
r"""Génère la GRILLE COMMUNE à toutes les classes, depuis la banque et la carte.

Trois entrées, rien d'autre :

  * la BANQUE (`layouts\banque.xml`) — les formes de cluster prélevées sur vos
    dix feuilles corrigées, arbre interne compris ; c'est `extrait_banque.py`
    qui la produit, et l'éditeur en jeu qui la retouche ;
  * la CARTE (`carte_seed.png`) — l'image que vous peignez avec `peint_carte.py`,
    où chaque pixel dit quelles statistiques peuvent tomber là ;
  * le NOMBRE de clusters.

CE QUE LES DIX FEUILLES ONT DICTÉ (relevé du 2026-09-05, `analyse_grilles.py`) :

  maillage      quadrillage de pas 8, huit voisins, aucune rotation de cluster ;
                178 ponts orthogonaux pour 106 diagonaux
  intérieur     202 clusters sur 247 sont des arbres exacts ; 90 % des liaisons
                sont des rayons ou des arcs — on garde l'arbre de la banque
  ponts         partent de l'anneau 3 à 84 %, de l'anneau 2 sinon ; longueur
                1,5 à 7,1 ; UN SEUL croisement sur 4 675 liaisons
  structure     arbre couvrant + ~25 % de boucles ; 21 % de clusters-feuilles
  vides         322 sur 349 sur l'anneau 1 — un tampon autour du centre
  qualité       suit la PROFONDEUR, pas l'anneau : 1,07 près du départ,
                2,0 vers 30 pas, 3,0 au-delà de 60

LA PROFONDEUR se mesure ici depuis le BORD de la grille : les dix départs se
poseront sur le pourtour, le centre est l'endgame. Une fois les départs posés
dans l'éditeur, une passe de requalification pourra reprendre la mesure depuis
les vrais départs.

LE CADRE : la carte couvre le carré qui entoure le maillage, avec une marge d'un
demi-pas. `cadre()` est la seule définition de cette correspondance — le
pinceau l'emploie pour poser l'impostor au même endroit.

    python genere_commune.py [nb_clusters] [graine] [nom]
"""
import io
import json
import math
import os
import random
import re
import sys
from collections import defaultdict, deque

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette_carte import CLE_QUALITES, LIANT, decode, lit_qualites, qualite_au_pixel  # noqa: E402

LAYOUTS = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\lua_scripts\Spherier\layouts"
ICI = os.path.dirname(os.path.abspath(__file__))
CARTE = os.path.join(ICI, "carte_seed.png")
POIDS = os.path.join(ICI, "banque_poids.json")

B = 8
RAYONS = {0: 0.0, 1: 1.1, 2: 2.1, 3: 3.1}
PAS = 8.0
MARGE = 4.0                 # un demi-pas autour du maillage
SEP_MIN = 0.70              # l'écart de l'éditeur entre deux emplacements
DEGAGEMENT = 0.60           # distance minimale d'un pont aux emplacements qu'il frôle
PART_BOUCLES = 0.25         # ponts ajoutés à l'arbre couvrant
PART_VIDES_ANNEAU_1 = 0.22  # → ~7,5 % de nœuds vides, comme les feuilles
GIGUE_CARTE = 6             # pixels de brassage à la lecture de la carte
# qualité moyenne par profondeur, relevée ; la profondeur est ramenée sur 0..60
COURBE_QUALITE = [(0, 1.07), (10, 1.22), (20, 1.43), (30, 2.0), (40, 2.25), (50, 2.74), (60, 3.01)]


# ---------------------------------------------------------------------------
# Géométrie
# ---------------------------------------------------------------------------
def position(cx, cy, anneau, branche):
    r = RAYONS[anneau]
    if r == 0.0:
        return cx, cy
    a = (branche - 1) * 2 * math.pi / B
    return cx + r * math.cos(a), cy + r * math.sin(a)


def croise(p1, p2, p3, p4):
    def o(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    return (o(p3, p4, p1) * o(p3, p4, p2) < 0) and (o(p1, p2, p3) * o(p1, p2, p4) < 0)


def distance_segment(p, a, b):
    ax, ay, bx, by = a[0], a[1], b[0], b[1]
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    if l2 == 0:
        return math.hypot(p[0] - ax, p[1] - ay)
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / l2))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (ay + t * dy))


def vers_pixel(x, y, cadre_, taille):
    """Un point de la grille → un pixel de la carte.

    L'AXE Y DE LA GRILLE MONTE — l'éditeur ancre ses emplacements en bas à
    gauche et `rend_grille.lua` le dit en toutes lettres —, celui d'une image
    descend. La première version lisait la ligne y directement : la carte était
    lue à l'envers, l'esprit peint en bas sortait en haut (2026-09-05). Le
    retournement vit ICI et nulle part ailleurs : le générateur et l'impostor
    passent tous deux par cette fonction.
    """
    x0, y0, cote = cadre_
    return (x - x0) / cote * taille, (1.0 - (y - y0) / cote) * taille


def cadre(clusters):
    """Le carré (x0, y0, côté) que la carte recouvre."""
    xs = [c[0] for c in clusters]
    ys = [c[1] for c in clusters]
    x0, x1 = min(xs) - RAYONS[3] - MARGE, max(xs) + RAYONS[3] + MARGE
    y0, y1 = min(ys) - RAYONS[3] - MARGE, max(ys) + RAYONS[3] + MARGE
    cote = max(x1 - x0, y1 - y0)
    return (x0 + x1 - cote) / 2, (y0 + y1 - cote) / 2, cote


# ---------------------------------------------------------------------------
# La banque
# ---------------------------------------------------------------------------
def lit_banque():
    t = io.open(os.path.join(LAYOUTS, "banque.xml"), encoding="utf-8").read()
    em = {}
    for m in re.finditer(r'<emplacement ([^/]*)/>', t):
        a = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        em[int(a["id"])] = (int(a["cluster"]), int(a["anneau"]), int(a["branche"]))
    motifs = defaultdict(lambda: {"places": [], "liens": []})
    for i, (c, a, b) in em.items():
        motifs[c]["places"].append((a, b))
    for m in re.finditer(r'<liaison a="(\d+)" b="(\d+)"', t):
        a, b = int(m.group(1)), int(m.group(2))
        if em[a][0] == em[b][0]:       # les ponts de la chaîne sont ignorés
            motifs[em[a][0]]["liens"].append((em[a][1:], em[b][1:]))
    poids = {}
    if os.path.exists(POIDS):
        poids = {int(k): v for k, v in json.load(io.open(POIDS, encoding="utf-8")).items()}
    banque = []
    for c in sorted(motifs):
        banque.append((motifs[c]["places"], motifs[c]["liens"], poids.get(c, 1)))
    return banque


def tourne(place, k):
    a, b = place
    return (a, 1 if a == 0 else ((b - 1 + k) % B) + 1)


def morceaux(places, liens):
    adj = defaultdict(list)
    for a, b in liens:
        adj[a].append(b)
        adj[b].append(a)
    vus, blocs = set(), []
    for p in places:
        if p in vus:
            continue
        bloc, f = {p}, deque([p])
        while f:
            u = f.popleft()
            for v in adj[u]:
                if v not in bloc:
                    bloc.add(v)
                    f.append(v)
        vus |= bloc
        blocs.append(sorted(bloc))
    return blocs


# ---------------------------------------------------------------------------
# Le maillage : un disque irrégulier de N cellules
# ---------------------------------------------------------------------------
def maillage(de, n):
    cellules = {(0, 0)}
    while len(cellules) < n:
        front = set()
        for (i, j) in cellules:
            for di in (-1, 0, 1):
                for dj in (-1, 0, 1):
                    if (di or dj) and (i + di, j + dj) not in cellules:
                        front.add((i + di, j + dj))
        # la plus proche du centre, avec un peu de bruit : rond mais pas lisse
        choix = min(front, key=lambda c: math.hypot(*c) + de.random() * 1.6)
        cellules.add(choix)
    return sorted(cellules)


def voisines(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1])) == 1


# ---------------------------------------------------------------------------
# Génération
# ---------------------------------------------------------------------------
def genere(nb_clusters=128, graine=1, carte_png=CARTE, nom="commune"):
    de = random.Random(graine)
    banque = lit_banque()
    cells = maillage(de, nb_clusters)

    # 1. un motif par cellule, pondéré, tourné au hasard (rot=0 dans le XML :
    #    la rotation est un décalage de branches, comme dans vos feuilles).
    total_poids = float(sum(p for _, _, p in banque))
    places_de, liens_de = {}, {}
    for c in cells:
        tirage, cumul = de.random() * total_poids, 0.0
        for places, liens, p in banque:
            cumul += p
            if cumul >= tirage:
                break
        k = de.randrange(B)
        places_de[c] = sorted(tourne(q, k) for q in places)
        liens_de[c] = [(tourne(a, k), tourne(b, k)) for a, b in liens]

    def xy(c, q):
        return position(c[0] * PAS, c[1] * PAS, q[0], q[1])

    tous_points = [xy(c, q) for c in cells for q in places_de[c]]
    segments = [(xy(c, a), xy(c, b)) for c in cells for a, b in liens_de[c]]

    # 2. les ponts — L'UNITÉ EST LE MORCEAU, PAS LE CLUSTER (2026-09-05).
    #    Un cluster divisé a deux morceaux sans lien interne : un pont sur
    #    chacun relie bien le cluster au reste, mais ses deux moitiés restent
    #    étrangères, et la grille se coupe le long de ces clusters — le piège de
    #    la division, déjà rencontré par genere_grille.py, retrouvé ici avec
    #    cinq morceaux sur la première grille tirée de la carte. L'arbre
    #    couvrant se tire donc sur les MORCEAUX, et la connexité se vérifie sur
    #    eux ; on relâche les contraintes par paliers jusqu'à ce que tout se
    #    tienne — le croisement, lui, n'est jamais relâché.
    morceaux_de = {c: morceaux(places_de[c], liens_de[c]) for c in cells}
    pieces = [(c, k) for c in cells for k in range(len(morceaux_de[c]))]
    piece_de = {}
    for c in cells:
        for k, bloc in enumerate(morceaux_de[c]):
            for q in bloc:
                piece_de[(c, q)] = k

    def realise(ca, cb, exige_a=None, exige_b=None, anneau_min=2,
                longueur_max=7.5, degagement=DEGAGEMENT):
        cands = []
        for pa in places_de[ca]:
            if pa[0] < anneau_min or (exige_a is not None and pa not in exige_a):
                continue
            for pb in places_de[cb]:
                if pb[0] < anneau_min or (exige_b is not None and pb not in exige_b):
                    continue
                A, Bp = xy(ca, pa), xy(cb, pb)
                d = math.hypot(A[0] - Bp[0], A[1] - Bp[1])
                penalite = (0.0 if pa[0] == 3 else 0.8) + (0.0 if pb[0] == 3 else 0.8)
                cands.append((d + penalite, d, pa, pb, A, Bp))
        cands.sort()
        for _, d, pa, pb, A, Bp in cands:
            if d > longueur_max:
                break
            if any(croise(A, Bp, s[0], s[1]) for s in segments):
                continue
            if any(distance_segment(p, A, Bp) < degagement for p in tous_points
                   if p != A and p != Bp):
                continue
            return pa, pb
        return None

    pere = {p: p for p in pieces}

    def racine(p):
        while pere[p] != p:
            pere[p] = pere[pere[p]]
            p = pere[p]
        return p

    ponts = []
    compteurs = defaultdict(int)

    def pose_pont(a, b, pa, pb):
        ponts.append((a, b, pa, pb))
        segments.append((xy(a, pa), xy(b, pb)))
        ra, rb = racine((a, piece_de[(a, pa)])), racine((b, piece_de[(b, pb)]))
        if ra != rb:
            pere[ra] = rb

    def separes():
        return len(set(racine(p) for p in pieces))

    # L'arbre : les paires de clusters voisins, l'orthogonal favorisé ; pour
    # chaque paire, chaque couple de morceaux encore séparés reçoit son pont.
    paires = [(a, b) for i, a in enumerate(cells) for b in cells[i + 1:] if voisines(a, b)]

    def poids_arete(e):
        diag = abs(e[0][0] - e[1][0]) == 1 and abs(e[0][1] - e[1][1]) == 1
        return de.random() + (0.6 if diag else 0.0)

    paires.sort(key=poids_arete)
    for a, b in paires:
        for ka, ba in enumerate(morceaux_de[a]):
            for kb, bb in enumerate(morceaux_de[b]):
                if racine((a, ka)) == racine((b, kb)):
                    continue
                r = realise(a, b, exige_a=set(ba), exige_b=set(bb))
                if r is not None:
                    pose_pont(a, b, r[0], r[1])

    # Le raccordement par paliers : tant qu'il reste des morceaux séparés.
    paliers = ((2, 7.5, DEGAGEMENT, 1), (1, 8.5, 0.5, 1), (1, 10.0, 0.4, 1),
               (0, 12.0, 0.3, 1), (1, 18.0, 0.4, 2), (0, 20.0, 0.3, 2))
    for anneau_min, longueur_max, degagement, portee in paliers:
        while separes() > 1:
            pose = None
            for (a, ka) in pieces:
                for (b, kb) in pieces:
                    if a == b or racine((a, ka)) == racine((b, kb)):
                        continue
                    if max(abs(a[0] - b[0]), abs(a[1] - b[1])) > portee:
                        continue
                    r = realise(a, b, exige_a=set(morceaux_de[a][ka]),
                                exige_b=set(morceaux_de[b][kb]), anneau_min=anneau_min,
                                longueur_max=longueur_max, degagement=degagement)
                    if r is not None:
                        pose = (a, b, r)
                        break
                if pose:
                    break
            if pose is None:
                break
            a, b, r = pose
            pose_pont(a, b, r[0], r[1])
            compteurs["raccord_%d_%d" % (anneau_min, portee)] += 1
        if separes() == 1:
            break

    # Dernier recours : deux morceaux d'un MÊME cluster encore séparés sont
    # recousus par le plus court segment interne qui ne croise rien.
    if separes() > 1:
        for c in cells:
            for ka in range(len(morceaux_de[c])):
                for kb in range(ka + 1, len(morceaux_de[c])):
                    if racine((c, ka)) == racine((c, kb)):
                        continue
                    ba, bb = morceaux_de[c][ka], morceaux_de[c][kb]
                    cands = sorted((math.hypot(xy(c, p_)[0] - xy(c, q_)[0],
                                               xy(c, p_)[1] - xy(c, q_)[1]), p_, q_)
                                   for p_ in ba for q_ in bb)
                    points_c = [xy(c, q_) for q_ in places_de[c]]
                    couture = None
                    for _, p_, q_ in cands:
                        A, Bp = xy(c, p_), xy(c, q_)
                        if any(croise(A, Bp, s[0], s[1]) for s in segments):
                            continue
                        if any(distance_segment(pt, A, Bp) < DEGAGEMENT for pt in points_c
                               if pt != A and pt != Bp):
                            continue
                        couture = (p_, q_)
                        break
                    if couture is None:
                        couture = cands[0][1:]
                        compteurs["coutures_forcees"] += 1
                    liens_de[c].append(couture)
                    segments.append((xy(c, couture[0]), xy(c, couture[1])))
                    pere[racine((c, ka))] = racine((c, kb))
                    compteurs["coutures"] += 1
    morceaux_restants = separes()
    compteurs_raccord = {k: v for k, v in compteurs.items() if k.startswith("raccord")}

    degre = defaultdict(int)
    for a, b, _, _ in ponts:
        degre[a] += 1
        degre[b] += 1

    # LES BOUCLES : 25 % de ponts en plus, entre clusters voisins déjà
    # reliés, jamais sur une feuille — un cul-de-sac est voulu.
    deja = set()
    for a, b, _, _ in ponts:
        deja.add((a, b))
        deja.add((b, a))
    restants = [(a, b) for a, b in paires if (a, b) not in deja]
    de.shuffle(restants)
    voulu = int(len(ponts) * PART_BOUCLES)
    for a, b in restants:
        if voulu <= 0:
            break
        if degre[a] <= 1 or degre[b] <= 1:
            continue
        r = realise(a, b)
        if r is None:
            continue
        pose_pont(a, b, r[0], r[1])
        degre[a] += 1
        degre[b] += 1
        voulu -= 1

    for c in cells:
        morceaux_de[c] = morceaux(places_de[c], liens_de[c])

    # 4. la profondeur, depuis le bord du maillage
    ids, idn, noeuds = {}, 1, []
    for c in cells:
        for q in places_de[c]:
            ids[(c, q)] = idn
            noeuds.append((c, q))
            idn += 1
    adj = defaultdict(list)
    for c in cells:
        for a, b in liens_de[c]:
            adj[ids[(c, a)]].append(ids[(c, b)])
            adj[ids[(c, b)]].append(ids[(c, a)])
    for a, b, pa, pb in ponts:
        adj[ids[(a, pa)]].append(ids[(b, pb)])
        adj[ids[(b, pb)]].append(ids[(a, pa)])
    bord = [c for c in cells
            if sum(1 for v in cells if voisines(c, v)) < 8]
    prof = {}
    f = deque()
    for c in bord:
        for q in places_de[c]:
            if q[0] == 3:
                prof[ids[(c, q)]] = 0
                f.append(ids[(c, q)])
    while f:
        u = f.popleft()
        for v in adj[u]:
            if v not in prof:
                prof[v] = prof[u] + 1
                f.append(v)
    # LA QUALITÉ SUIT LE RANG DE PROFONDEUR, pas la profondeur brute : les dix
    # départs périphériques rendent toute la grille peu profonde en pas, et une
    # courbe en pas ne produisait presque que du commun (61 % / 33 % / 5 % au
    # premier jet). On impose donc la PYRAMIDE relevée sur vos feuilles —
    # 48 % commun, 29 % peu commun, 15 % rare, 8 % épique et légendaire —, les
    # plus profonds recevant les meilleures, avec un brassage d'un rang.
    ordre = sorted(prof, key=lambda i: (prof[i], de.random()))
    rang_de = {i: k / float(max(1, len(ordre) - 1)) for k, i in enumerate(ordre)}

    def qualite(i):
        r = rang_de.get(i, 0.0) + de.gauss(0.0, 0.05)
        q = 1 if r < 0.48 else 2 if r < 0.77 else 3 if r < 0.92 else 4 if r < 0.985 else 5
        return q

    # 5. les statistiques, lues sur la carte
    x0, y0, cote = cadre([(c[0] * PAS, c[1] * PAS) for c in cells])
    img, anneaux = None, None
    if os.path.exists(carte_png):
        brut = Image.open(carte_png)
        # LES ANNEAUX DE QUALITÉ voyagent dans le PNG. S'ils y sont, la qualité
        # d'un nœud est celle de l'anneau où il tombe ; sinon, la pyramide par
        # profondeur ci-dessus reste en vigueur.
        if CLE_QUALITES in getattr(brut, "text", {}):
            anneaux = lit_qualites(brut)
        img = brut.convert("RGB")
    largeur = img.size[0] if img else 2048

    def stat_en(x, y):
        if img is None:
            return de.choice(LIANT)
        fx, fy = vers_pixel(x, y, (x0, y0, cote), largeur)
        px = int(fx + de.uniform(-GIGUE_CARTE, GIGUE_CARTE))
        py = int(fy + de.uniform(-GIGUE_CARTE, GIGUE_CARTE))
        px, py = max(0, min(largeur - 1, px)), max(0, min(largeur - 1, py))
        cands = decode(img.getpixel((px, py)))
        if not cands:
            return de.choice(LIANT)
        tirage, cumul = de.random() * sum(w for _, w in cands), 0.0
        for s, w in cands:
            cumul += w
            if cumul >= tirage:
                return s
        return cands[-1][0]

    contenu = {}
    for c, q in noeuds:
        i = ids[(c, q)]
        if q[0] == 1 and de.random() < PART_VIDES_ANNEAU_1:
            contenu[i] = None
        else:
            x, y = xy(c, q)
            if anneaux is not None:
                fx, fy = vers_pixel(x, y, (x0, y0, cote), largeur)
                contenu[i] = (stat_en(x, y), qualite_au_pixel(fx, fy, largeur, anneaux))
            else:
                contenu[i] = (stat_en(x, y), qualite(i))

    # 6. le départ provisoire : le centre du cluster central
    centre = min(cells, key=lambda c: math.hypot(*c))
    depart = ids.get((centre, (0, 1))) or ids[(centre, places_de[centre][0])]

    return dict(nom=nom, cells=cells, places_de=places_de, liens_de=liens_de,
                ponts=ponts, ids=ids, contenu=contenu, prof=prof, depart=depart,
                cadre=(x0, y0, cote), degre=dict(degre), compteurs=dict(compteurs),
                raccords=dict(compteurs_raccord), morceaux_clusters=morceaux_restants)


def ecrit_xml(g, chemin=None):
    chemin = chemin or os.path.join(LAYOUTS, g["nom"] + ".xml")
    clusters = {c: k + 1 for k, c in enumerate(g["cells"])}
    lc, le, ll = [], [], []
    for c in g["cells"]:
        lc.append('    <cluster id="%d" x="%.4f" y="%.4f" rot="0.0000"/>'
                  % (clusters[c], c[0] * PAS, c[1] * PAS))
        for q in g["places_de"][c]:
            i = g["ids"][(c, q)]
            v = g["contenu"][i]
            attr = ('type="noeud"' if v is None
                    else 'type="noeud" stat="%s" qualite="%d"' % v)
            le.append('    <emplacement id="%d" cluster="%d" anneau="%d" branche="%d" %s/>'
                      % (i, clusters[c], q[0], q[1], attr))
        for a, b in g["liens_de"][c]:
            ll.append('    <liaison a="%d" b="%d"/>' % (g["ids"][(c, a)], g["ids"][(c, b)]))
    for a, b, pa, pb in g["ponts"]:
        ll.append('    <liaison a="%d" b="%d"/>' % (g["ids"][(a, pa)], g["ids"][(b, pb)]))
    corps = ('<?xml version="1.0" encoding="UTF-8"?>\n'
             '<spherier version="1" nom="%s">\n'
             '  <clusters>\n%s\n  </clusters>\n'
             '  <emplacements>\n%s\n  </emplacements>\n'
             '  <liaisons>\n%s\n  </liaisons>\n'
             '  <depart id="%d"/>\n'
             '</spherier>\n' % (g["nom"], "\n".join(lc), "\n".join(le), "\n".join(ll), g["depart"]))
    io.open(chemin, "w", encoding="utf-8", newline="\n").write(corps)
    index = os.path.join(LAYOUTS, "index.txt")
    if os.path.exists(index) and g["nom"] not in io.open(index, encoding="utf-8").read().split():
        io.open(index, "a", encoding="utf-8", newline="\n").write(g["nom"] + "\n")
    return chemin


def bilan(g):
    n = len(g["ids"])
    feuilles = sum(1 for c in g["cells"] if g["degre"].get(c, 0) == 1)
    vides = sum(1 for v in g["contenu"].values() if v is None)
    stats = defaultdict(int)
    for v in g["contenu"].values():
        if v:
            stats[v[0]] += 1
    q = defaultdict(int)
    for v in g["contenu"].values():
        if v:
            q[v[1]] += 1
    return ("%d clusters (%d morceau(x), raccords %s), %d emplacements (%d vides), %d liaisons dont %d ponts ; "
            "%d clusters-feuilles (%d %%) ; profondeur max %d ; qualités %s ; "
            "morceaux pontés %d, coutures %d (forcées %d)"
            % (len(g["cells"]), g["morceaux_clusters"], g["raccords"] or "aucun", n, vides,
               sum(len(l) for l in g["liens_de"].values()) + len(g["ponts"]), len(g["ponts"]),
               feuilles, 100 * feuilles // max(1, len(g["cells"])),
               max(g["prof"].values()) if g["prof"] else 0, dict(sorted(q.items())),
               g["compteurs"].get("morceaux_pontes", 0), g["compteurs"].get("coutures", 0),
               g["compteurs"].get("coutures_forcees", 0)), dict(stats))


if __name__ == "__main__":
    nb = int(sys.argv[1]) if len(sys.argv) > 1 else 128
    graine = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    nom = sys.argv[3] if len(sys.argv) > 3 else "commune"
    sys.stdout.reconfigure(encoding="utf-8")
    g = genere(nb, graine, nom=nom)
    chemin = ecrit_xml(g)
    texte, stats = bilan(g)
    print(texte)
    print("stats :", stats)
    print("écrit :", chemin)
