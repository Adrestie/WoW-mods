# -*- coding: utf-8 -*-
r"""Ajoute des nexus à une disposition, sans toucher à ce qui existe.

Un nexus est un cluster : trois anneaux de huit places autour d'une place
centrale. Les liaisons internes suivent la règle de l'éditeur sans exception —
deux places voisines d'un même anneau se touchent, deux places de même branche
sur deux anneaux consécutifs se touchent, la place centrale touche tout le
premier anneau. Un nexus fabriqué ici se modifie donc dans l'éditeur comme les
autres.

Trois principes, et le troisième est le plus important :

**Le maillage est aligné.** Chaque nexus partage son abscisse, son ordonnée ou sa
diagonale exacte avec un autre nexus, et aucun n'est tourné. Un placement libre
donne un semis qui se lit comme du désordre ; un maillage se lit comme un plan.

**Les nexus sont fournis.** Dix-huit à vingt et une places sur vingt-cinq. Des
branches isolées font une géométrie pauvre et un dessin dégarni ; ce sont les
MURS qu'on choisit, pas les couloirs — on part du plein et l'on creuse.

**Un nexus peut être DIVISÉ.** Son réseau interne se coupe en deux morceaux qui
ne communiquent pas. Il porte quatre ponts, deux par morceau : venant du cluster
A on entre dans le premier morceau et l'on n'atteint que B ; pour aller vers D il
faut arriver par C. Le nexus a l'air d'un carrefour et n'en est pas un — c'est de
là que vient le labyrinthe, bien plus que des couloirs internes.

Ce qui existe n'est jamais réécrit — ni cluster, ni emplacement, ni liaison, ni
départ. Le fichier ne fait que grossir.

    python ajoute_nexus.py warrior
"""
import io
import math
import os
import re
import sys
from collections import defaultdict, deque

sys.stdout.reconfigure(encoding="utf-8")

LAYOUTS = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\lua_scripts\Spherier\layouts"
RAYONS = {0: 0.0, 1: 1.1, 2: 2.1, 3: 3.1}
BRANCHES = 8
PREMIER_ID = 700          # au-delà de tout ce que l'éditeur a écrit
ECART_MIN = 6.80          # les plus serrés des clusters existants sont à 6,43


def anneaux(rings, branches):
    return [(r, b) for r in rings for b in branches]


# ---------------------------------------------------------------------------
# Les formes
# ---------------------------------------------------------------------------
# On part du plein et l'on creuse : chaque forme dit les places OCCUPÉES, et ce
# qu'on n'y trouve pas est un mur.
FORMES = {
    # --- les deux carrefours qui n'en sont pas ---------------------------
    # Trois branches à l'est et au nord d'un côté, trois à l'ouest et au sud de
    # l'autre, séparées par deux murs pleins en b4 et b8. Aucune place centrale :
    # elle toucherait tout le premier anneau et ressouderait les deux moitiés.
    "carrefour_est": anneaux((1, 2, 3), (1, 2, 3)) + anneaux((1, 2, 3), (5, 6, 7)),
    # Le même, tourné d'un quart — mais par le choix des branches, jamais par une
    # rotation du cluster : deux morceaux, l'un vers l'ouest et le nord, l'autre
    # vers le sud et l'est.
    "carrefour_ouest": anneaux((1, 2, 3), (3, 4, 5)) + anneaux((1, 2, 3), (7, 8, 1)),

    # --- les nexus pleins -------------------------------------------------
    # Deux couronnes complètes reliées par quatre rayons seulement : on tourne
    # longtemps avant de trouver par où passer.
    "peigne": anneaux((1,), range(1, 9)) + anneaux((2,), (1, 3, 5, 7)) +
              anneaux((3,), range(1, 9)),
    # Une couronne intérieure pleine, deux failles décalées dans les anneaux
    # extérieurs : les couloirs ne se font jamais face.
    "faille": anneaux((1,), range(1, 9)) + anneaux((2,), (2, 3, 4, 6, 7, 8)) +
              anneaux((3,), (1, 2, 4, 5, 6, 8)),
    # Un cœur relié à six branches, quatre rayons vers une couronne extérieure
    # pleine : le tour extérieur se fait, le tour intérieur non.
    "chicane": [(0, 1)] + anneaux((1,), (1, 2, 3, 4, 5, 6)) +
               anneaux((2,), (2, 4, 6, 8)) + anneaux((3,), range(1, 9)),
    # Le plus dense : vingt et une places, un mur par anneau, jamais au même
    # endroit, si bien qu'il faut traverser trois fois pour ressortir.
    # Un couloir unique qui se fend en deux au deuxième anneau, chaque moitié
    # repartant dans un sens différent le long du bord.
    "meandre": anneaux((1,), (1, 2, 3, 5, 6, 7, 8)) +
               anneaux((2,), (1, 2, 3, 4, 5, 7, 8)) +
               anneaux((3,), (2, 3, 4, 5, 6, 7, 8)),
}

# ---------------------------------------------------------------------------
# Les variations
# ---------------------------------------------------------------------------
# Ce que chaque forme retire et ajoute à la règle de l'éditeur. Retirer allonge
# un trajet et ouvre une impasse — la variation la plus utile au labyrinthe, et
# la plus discrète, puisqu'elle fait moins de traits et non davantage. Ajouter
# une diagonale ouvre un passage oblique parmi les arcs et les rayons ; on les
# prend sur les anneaux EXTÉRIEURS, où les places sont assez écartées pour que le
# trait passe au large des autres.
VARIANTES = {
    "carrefour_est": {
        # Une oblique par moitié, et jamais entre les deux : les branches 1-2-3
        # d'un côté, 5-6-7 de l'autre, le mur de b4 et b8 reste entier.
        "ajoute": [((2, 1), (3, 2)), ((2, 5), (3, 6))],
        # L'anneau intérieur se coupe : on n'atteint plus (1,3) qu'en passant par
        # le deuxième anneau.
        "retire": [((1, 2), (1, 3)), ((1, 6), (1, 7))],
    },
    "carrefour_ouest": {
        "ajoute": [((2, 3), (3, 4)), ((2, 7), (3, 8))],
        "retire": [((1, 4), (1, 5)), ((1, 8), (1, 1))],
    },
    "peigne": {
        # Un passage oblique de plus entre les deux couronnes, et un rayon en
        # moins : trois passages seulement, et une place en cul-de-sac.
        "ajoute": [((2, 1), (3, 2)), ((2, 5), (3, 6))],
        "retire": [((2, 7), (3, 7))],
    },
    "faille": {
        # La couronne intérieure cesse d'être une boucle.
        "ajoute": [((2, 3), (3, 4))],
        "retire": [((1, 4), (1, 5))],
    },
    "chicane": {
        # La couronne extérieure aussi.
        "ajoute": [((2, 6), (3, 7))],
        "retire": [((3, 4), (3, 5))],
    },
    "meandre": {
        "ajoute": [((2, 5), (3, 6))],
        "retire": [((2, 4), (2, 5))],
    },
}

# Distance minimale, en unités de grille, entre un trait ajouté et le centre
# d'une place qu'il ne relie pas. Une place se dessine sur environ 0,72 unité de
# large ; en deçà de cette marge, le trait lui passe dessus.
DEGAGEMENT = 0.45

# ---------------------------------------------------------------------------
# Le maillage
# ---------------------------------------------------------------------------
# Trois quartiers, un par spécialisation, chacun en losange : un carrefour au
# milieu, trois satellites autour, et le quatrième côté ouvert sur la disposition
# existante. Le pas est de huit — l'écart entre deux clusters voisins de la
# disposition d'origine —, si bien que tout est aligné, y compris sur les
# clusters d'accroche : le carrefour des Armes partage l'ordonnée du cluster 17,
# celui de Protection celle du 19, celui de Fureur celle du 9.
#
# Les quatre ponts du carrefour se répartissent DEUX PAR MORCEAU, et c'est là
# tout le propos : le morceau qui regarde la disposition existante ne mène qu'au
# satellite nord ; pour atteindre les deux autres, il faut faire le tour par les
# diagonales.
NEXUS = [
    # id,   x,      y,      forme,             composantes, ponts (morceau, cible)
    # --- quartier des Armes, accroché au cluster 17 (-8.25, -94.25) -------
    (22, -16.25,  -94.25, "carrefour_est",  2, [(0, "17"), (0, "23"), (1, "24"), (1, "25")]),
    (23, -16.25,  -86.25, "faille",         1, [(0, "25")]),
    (24, -16.25, -102.25, "chicane",        1, [(0, "25")]),
    (25, -24.25,  -94.25, "meandre",        1, []),
    # --- quartier de Protection, accroché au cluster 19 (-8.25, -118) ----
    (26, -16.25, -118.00, "carrefour_est",  2, [(0, "19"), (0, "27"), (1, "28"), (1, "29")]),
    (27, -16.25, -110.00, "peigne",         1, [(0, "29")]),
    (28, -16.25, -126.00, "faille",         1, [(0, "29")]),
    (29, -24.25, -118.00, "chicane",        1, []),
    # --- quartier de Fureur, accroché au cluster 9 (22.25, -109) ---------
    # Le morceau 0 tient les branches 7-8-1 (sud, sud-est, est) et le morceau 1
    # les branches 3-4-5 (nord, nord-ouest, ouest) : l'ordre vient du tri des
    # places, et (1,1) passe avant (1,3). Le cluster 9 est à l'OUEST de ce
    # carrefour, il revient donc au morceau 1 — s'y tromper fait partir les ponts
    # de l'anneau intérieur, à cinq de long au lieu de deux.
    (30,  30.25, -109.00, "carrefour_ouest", 2, [(1, "9"), (1, "31"), (0, "32"), (0, "33")]),
    (31,  30.25, -101.00, "meandre",        1, [(0, "33")]),
    (32,  30.25, -117.00, "peigne",         1, [(0, "33")]),
    (33,  38.25, -109.00, "faille",         1, []),
]


# ---------------------------------------------------------------------------
def lire(chemin):
    brut = io.open(chemin, encoding="utf-8").read()
    clusters = {}
    for i, x, y, r in re.findall(
            r'<cluster id="(\d+)" x="([-\d.]+)" y="([-\d.]+)" rot="([-\d.]+)"', brut):
        clusters[i] = (float(x), float(y), float(r))
    cellules = {}
    for attrs in re.findall(r'<emplacement ([^/]*)/>', brut):
        d = dict(re.findall(r'(\w+)="([^"]*)"', attrs))
        cellules[int(d["id"])] = d
    liaisons = [(int(a), int(b)) for a, b in
                re.findall(r'<liaison a="(\d+)" b="(\d+)"/>', brut)]
    depart = int(re.search(r'<depart id="(\d+)"/>', brut).group(1))
    return brut, clusters, cellules, liaisons, depart


def position(clusters, cid, anneau, branche):
    x, y, rot = clusters[cid]
    r = RAYONS[anneau]
    a = rot + (branche - 1) * 2 * math.pi / BRANCHES
    return x + r * math.cos(a), y + r * math.sin(a)


def liens_internes(places):
    """La règle de l'éditeur, appliquée aux seules places présentes.

    Une place absente ne se saute pas : elle sépare. C'est ce qui creuse les
    couloirs, et c'est aussi ce qui divise un carrefour en deux moitiés.
    """
    ici = set(places)
    aretes = []
    for (r, b) in places:
        if r == 0:
            for bb in range(1, BRANCHES + 1):
                if (1, bb) in ici:
                    aretes.append(((0, b), (1, bb)))
            continue
        if (r, (b % BRANCHES) + 1) in ici:
            aretes.append(((r, b), (r, (b % BRANCHES) + 1)))
        if (r + 1, b) in ici:
            aretes.append(((r, b), (r + 1, b)))
    return aretes


def applique_variantes(forme, places, aretes):
    """Retire et ajoute ce que la forme demande, en refusant l'impossible."""
    v = VARIANTES.get(forme)
    if not v:
        return aretes
    ici = set(places)
    normal = set(tuple(sorted(a)) for a in aretes)
    for lien in v.get("retire", []):
        cle = tuple(sorted(lien))
        if cle not in normal:
            sys.exit("%s : liaison à retirer absente %s" % (forme, lien))
        normal.discard(cle)
    for lien in v.get("ajoute", []):
        for bout in lien:
            if bout not in ici:
                sys.exit("%s : liaison à ajouter vers une place absente %s"
                         % (forme, bout))
        cle = tuple(sorted(lien))
        if cle in normal:
            sys.exit("%s : liaison à ajouter déjà présente %s" % (forme, lien))
        normal.add(cle)
    return sorted(normal)


def degagement(lien, places):
    """Distance du trait à la place la plus proche qu'il ne relie pas.

    Une corde à travers un anneau passerait par-dessus la place du milieu : on
    mesure plutôt que d'espérer.
    """
    def pos(pl):
        r = RAYONS[pl[0]]
        a = (pl[1] - 1) * 2 * math.pi / BRANCHES
        return r * math.cos(a), r * math.sin(a)

    (ax, ay), (bx, by) = pos(lien[0]), pos(lien[1])
    dx, dy = bx - ax, by - ay
    long2 = dx * dx + dy * dy
    pire = 99.0
    for pl in places:
        if pl in lien:
            continue
        px, py = pos(pl)
        t = 0.0 if long2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / long2))
        pire = min(pire, math.hypot(px - (ax + t * dx), py - (ay + t * dy)))
    return pire


def composantes(places, aretes):
    """Les morceaux du réseau interne, ordonnés par leur première place.

    L'ordre doit être stable : c'est lui qui donne son numéro à chaque morceau
    dans la table des ponts.
    """
    voisins = defaultdict(list)
    for u, v in aretes:
        voisins[u].append(v)
        voisins[v].append(u)
    vus, morceaux = set(), []
    for p in sorted(places):
        if p in vus:
            continue
        bloc, f = {p}, deque([p])
        while f:
            n = f.popleft()
            for m in voisins[n]:
                if m not in bloc:
                    bloc.add(m)
                    f.append(m)
        vus |= bloc
        morceaux.append(sorted(bloc))
    return morceaux


def aligne(a, b):
    """Même abscisse, même ordonnée, ou diagonale exacte."""
    dx, dy = abs(a[0] - b[0]), abs(a[1] - b[1])
    return dx < 1e-6 or dy < 1e-6 or abs(dx - dy) < 1e-6


# ---------------------------------------------------------------------------
nom = sys.argv[1] if len(sys.argv) > 1 else "warrior"
chemin = os.path.join(LAYOUTS, nom + ".xml")
brut, clusters, cellules, liaisons, depart = lire(chemin)

deja = [str(n[0]) for n in NEXUS if str(n[0]) in clusters]
if deja:
    sys.exit("Les nexus %s existent déjà : rien à faire." % ", ".join(deja))

print("%s : %d clusters, %d emplacements, %d liaisons"
      % (nom, len(clusters), len(cellules), len(liaisons)))

# --- écarts et alignements -------------------------------------------------
tous = dict((c, (v[0], v[1])) for c, v in clusters.items())
for cid, x, y, forme, ncomp, ponts in NEXUS:
    tous[str(cid)] = (x, y)
for cid, x, y, forme, ncomp, ponts in NEXUS:
    for autre, (ax, ay) in tous.items():
        if autre != str(cid) and math.hypot(x - ax, y - ay) < ECART_MIN:
            sys.exit("nexus %d trop près du cluster %s : %.2f"
                     % (cid, autre, math.hypot(x - ax, y - ay)))
    voisins = [n[0] for n in NEXUS
               if n[0] != cid and aligne((x, y), (n[1], n[2]))]
    if not voisins:
        sys.exit("nexus %d n'est aligné avec aucun autre" % cid)

# --- fabrication -----------------------------------------------------------
prochain = PREMIER_ID
neufs_clusters, neufs_emplacements, neufs_liaisons = [], [], []
par_place, morceaux_de = {}, {}

for cid, x, y, forme, ncomp, ponts in NEXUS:
    places = sorted(set(FORMES[forme]))
    aretes = liens_internes(places)
    for lien in VARIANTES.get(forme, {}).get("ajoute", []):
        d = degagement(lien, places)
        if d < DEGAGEMENT:
            sys.exit("%s : la diagonale %s frôle une place à %.2f" % (forme, lien, d))
    aretes = applique_variantes(forme, places, aretes)
    morceaux = composantes(places, aretes)
    if len(morceaux) != ncomp:
        sys.exit("nexus %d (%s) : %d morceau(x) au lieu de %d"
                 % (cid, forme, len(morceaux), ncomp))
    clusters[str(cid)] = (x, y, 0.0)
    neufs_clusters.append('    <cluster id="%d" x="%.4f" y="%.4f" rot="0.0000"/>'
                          % (cid, x, y))
    for (r, b) in places:
        par_place[(cid, r, b)] = prochain
        cellules[prochain] = {"id": str(prochain), "cluster": str(cid),
                              "anneau": str(r), "branche": str(b), "type": "noeud"}
        neufs_emplacements.append(
            '    <emplacement id="%d" cluster="%d" anneau="%d" branche="%d" type="noeud"/>'
            % (prochain, cid, r, b))
        prochain += 1
    for (u, v) in aretes:
        neufs_liaisons.append('    <liaison a="%d" b="%d"/>'
                              % (par_place[(cid, u[0], u[1])],
                                 par_place[(cid, v[0], v[1])]))
    morceaux_de[cid] = [[par_place[(cid, r, b)] for (r, b) in m] for m in morceaux]
    detail = " | ".join("%d:%d places br%s"
                        % (k, len(m), "".join(str(b) for b in sorted(set(b for _, b in m))))
                        for k, m in enumerate(morceaux))
    print("  nexus %-3d %-16s %2d places, %2d liaisons   %s"
          % (cid, forme, len(places), len(aretes), detail))

# --- ponts -----------------------------------------------------------------
paires = set()
for a, b in liaisons:
    paires.add(tuple(sorted((cellules[a]["cluster"], cellules[b]["cluster"]), key=int)))

par_cluster = defaultdict(list)
for i, d in cellules.items():
    par_cluster[d["cluster"]].append(i)

print("\nponts :")
for cid, x, y, forme, ncomp, ponts in NEXUS:
    for (morceau, cible) in ponts:
        paire = tuple(sorted((str(cid), cible), key=int))
        if paire in paires:
            sys.exit("pont déjà présent entre %s et %s" % paire)
        paires.add(paire)
        # Le pont part du MORCEAU désigné, et de sa place la plus proche de la
        # cible : c'est ce choix qui décide de ce que le joueur pourra atteindre.
        meilleur = None
        for i in morceaux_de[cid][morceau]:
            pi = position(clusters, str(cid), int(cellules[i]["anneau"]),
                          int(cellules[i]["branche"]))
            for j in par_cluster[cible]:
                pj = position(clusters, cible, int(cellules[j]["anneau"]),
                              int(cellules[j]["branche"]))
                d = math.hypot(pi[0] - pj[0], pi[1] - pj[1])
                if meilleur is None or d < meilleur[0]:
                    meilleur = (d, i, j)
        d, i, j = meilleur
        neufs_liaisons.append('    <liaison a="%d" b="%d"/>' % (i, j))
        print("   %-3s morceau %d - %-3s   %d (a%s b%s) -> %d (a%s b%s)   longueur %.2f"
              % (cid, morceau, cible, i, cellules[i]["anneau"], cellules[i]["branche"],
                 j, cellules[j]["anneau"], cellules[j]["branche"], d))

# --- tout doit rester atteignable depuis le départ -------------------------
liens = defaultdict(list)
for a, b in liaisons:
    liens[a].append(b)
    liens[b].append(a)
for l in neufs_liaisons:
    a, b = (int(v) for v in re.findall(r'"(\d+)"', l))
    liens[a].append(b)
    liens[b].append(a)
vus, f = {depart}, deque([depart])
while f:
    n = f.popleft()
    for m in liens[n]:
        if m not in vus:
            vus.add(m)
            f.append(m)
perdus = [i for i in cellules if i not in vus]
if perdus:
    sys.exit("%d emplacement(s) hors d'atteinte du départ : %s"
             % (len(perdus), perdus[:8]))
print("\ntout est atteignable depuis le départ (%d emplacements)." % len(vus))


# --- écriture : on insère, on ne réécrit rien ------------------------------
def insere(texte, fermeture, lignes):
    i = texte.index(fermeture)
    return texte[:i] + "\n".join(lignes) + "\n" + texte[i:]


brut = insere(brut, "  </clusters>", neufs_clusters)
brut = insere(brut, "  </emplacements>", neufs_emplacements)
brut = insere(brut, "  </liaisons>", neufs_liaisons)
io.open(chemin, "w", encoding="utf-8", newline="\n").write(brut)

print("%d nexus, %d emplacements, %d liaisons ajoutés."
      % (len(NEXUS), len(neufs_emplacements), len(neufs_liaisons)))
print("%s réécrit. Chaîne : regle_pierres.py -> importe_layout.lua -> SQL -> .spherier reload"
      % chemin)
