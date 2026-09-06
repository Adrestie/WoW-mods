# -*- coding: utf-8 -*-
r"""Extrait la BANQUE DE CLUSTERS des feuilles corrigées à la main.

Les dix grilles de classe ont été retouchées cluster par cluster : leurs formes
et leurs arbres internes sont le meilleur dessin dont on dispose. Plutôt que de
les réinventer, on les prélève tels quels — positions ET liaisons internes —,
on les dédouble, et l'on pèse chaque motif par sa fréquence d'apparition.

LA BANQUE EST ELLE-MÊME UNE DISPOSITION (`layouts\banque.xml`), lisible et
modifiable dans l'éditeur en jeu comme n'importe quelle grille : `.spherier
editor`, charger « banque ». Ajouter, retirer ou retoucher un cluster s'y fait
avec les outils que vous connaissez déjà. Les clusters y sont posés sur un
quadrillage de pas 8, sans stats — la banque ne connaît que les formes.

UNE CHAÎNE DE PONTS relie les clusters entre eux dans la banque, uniquement pour
que le contrôle de l'éditeur reste vert : le générateur ne lit que les liaisons
INTERNES (les deux extrémités dans le même cluster) et ignore tout pont.

Les poids vivent à part, dans `banque_poids.json` : le motif k (l'ordre des
clusters dans le XML) et le nombre de fois où il paraît dans les dix feuilles.
Un cluster ajouté à la main dans l'éditeur, absent du JSON, pèse 1.

Un motif est identifié par sa forme ET son arbre, à rotation près : deux
clusters de mêmes places mais de liaisons différentes sont deux motifs.

    python extrait_banque.py
"""
import io
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict, deque

sys.stdout.reconfigure(encoding="utf-8")

LAYOUTS = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\lua_scripts\Spherier\layouts"
CLASSES = ["warrior", "paladin", "hunter", "rogue", "priest",
           "deathknight", "shaman", "mage", "warlock", "druid"]
B = 8
PAS = 8.0
COLONNES = 16                 # clusters par rangée dans la banque
ICI = os.path.dirname(os.path.abspath(__file__))
POIDS = os.path.join(ICI, "banque_poids.json")


def lit(chemin):
    t = io.open(chemin, encoding="utf-8").read()
    em = {}
    for m in re.finditer(r'<emplacement ([^/]*)/>', t):
        a = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        em[int(a["id"])] = (int(a["cluster"]), int(a["anneau"]), int(a["branche"]))
    li = [(int(m.group(1)), int(m.group(2)))
          for m in re.finditer(r'<liaison a="(\d+)" b="(\d+)"', t)]
    return em, li


def tourne(place, k):
    a, b = place
    return (a, 1 if a == 0 else ((b - 1 + k) % B) + 1)


def normalise(places, liens):
    """La plus petite des huit écritures (places + arbre), à rotation près."""
    meilleur = None
    for k in range(B):
        p = tuple(sorted(tourne(x, k) for x in places))
        l = tuple(sorted(tuple(sorted((tourne(a, k), tourne(b, k)))) for a, b in liens))
        if meilleur is None or (p, l) < meilleur:
            meilleur = (p, l)
    return meilleur


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


def main():
    compte = Counter()
    for nom in CLASSES:
        em, li = lit(os.path.join(LAYOUTS, nom + ".xml"))
        par_cluster = defaultdict(list)
        for i, (c, a, b) in em.items():
            par_cluster[c].append(i)
        for c, ids in par_cluster.items():
            places = [(em[i][1], em[i][2]) for i in ids]
            liens = [((em[a][1], em[a][2]), (em[b][1], em[b][2]))
                     for a, b in li if em[a][0] == c and em[b][0] == c]
            compte[normalise(places, liens)] += 1

    motifs = sorted(compte.items(), key=lambda x: (-x[1], len(x[0][0])))

    # --- la banque, disposition de l'éditeur ---------------------------------
    lignes_cl, lignes_em, lignes_li = [], [], []
    ids, idn = {}, 1
    poids = {}
    for k, ((places, liens), n) in enumerate(motifs):
        cid = k + 1
        x, y = (k % COLONNES) * PAS, -(k // COLONNES) * PAS
        lignes_cl.append('    <cluster id="%d" x="%.4f" y="%.4f" rot="0.0000"/>' % (cid, x, y))
        for p in places:
            ids[(cid, p)] = idn
            lignes_em.append('    <emplacement id="%d" cluster="%d" anneau="%d" '
                             'branche="%d" type="noeud"/>' % (idn, cid, p[0], p[1]))
            idn += 1
        for a, b in liens:
            lignes_li.append('    <liaison a="%d" b="%d"/>' % (ids[(cid, a)], ids[(cid, b)]))
        poids[str(cid)] = n

    # --- la chaîne, pour un contrôle vert : chaque MORCEAU de chaque cluster
    #     est accroché au cluster PRÉCÉDENT — jamais à un morceau frère.
    #
    # PIÈGE ÉVITÉ (2026-09-05) : une première chaîne reliait les deux morceaux
    # d'un cluster divisé entre eux. Ce lien, interne au cluster, était relu par
    # le générateur comme une corde du motif — 28 croisements sur 28 venaient
    # de là. Un lien de chaîne doit TOUJOURS joindre deux clusters différents :
    # c'est à cela que lit_banque() le reconnaît et l'écarte.
    def pos(p):
        r = {0: 0.0, 1: 1.1, 2: 2.1, 3: 3.1}[p[0]]
        ang = (p[1] - 1) * 2 * math.pi / B
        return r * math.cos(ang), r * math.sin(ang)
    blocs_de = [morceaux(list(places), list(liens)) for (places, liens), _n in motifs]
    for k in range(len(motifs)):
        cid = k + 1
        if k == 0:
            # le premier cluster : ses morceaux supplémentaires s'accrochent au
            # deuxième cluster, faute de précédent
            if len(blocs_de[0]) > 1 and len(motifs) > 1:
                ancre = ids[(2, min(blocs_de[1][0], key=lambda p: pos(p)[0]))]
                for bloc in blocs_de[0][1:]:
                    lignes_li.append('    <liaison a="%d" b="%d"/>'
                                     % (ids[(cid, max(bloc, key=lambda p: pos(p)[0]))], ancre))
            continue
        ancre = ids[(k, max(blocs_de[k - 1][-1], key=lambda p: pos(p)[0]))]
        for bloc in blocs_de[k]:
            lignes_li.append('    <liaison a="%d" b="%d"/>'
                             % (ancre, ids[(cid, min(bloc, key=lambda p: pos(p)[0]))]))

    depart = ids[(1, motifs[0][0][0][0])]
    corps = ('<?xml version="1.0" encoding="UTF-8"?>\n'
             '<spherier version="1" nom="banque">\n'
             '  <clusters>\n%s\n  </clusters>\n'
             '  <emplacements>\n%s\n  </emplacements>\n'
             '  <liaisons>\n%s\n  </liaisons>\n'
             '  <depart id="%d"/>\n'
             '</spherier>\n'
             % ("\n".join(lignes_cl), "\n".join(lignes_em), "\n".join(lignes_li), depart))
    io.open(os.path.join(LAYOUTS, "banque.xml"), "w", encoding="utf-8",
            newline="\n").write(corps)
    io.open(POIDS, "w", encoding="utf-8", newline="\n").write(
        json.dumps(poids, indent=1))

    index = os.path.join(LAYOUTS, "index.txt")
    noms = io.open(index, encoding="utf-8").read().split()
    if "banque" not in noms:
        io.open(index, "a", encoding="utf-8", newline="\n").write("banque\n")

    divises = sum(1 for (places, liens), _ in motifs
                  if len(morceaux(list(places), list(liens))) > 1)
    print("banque : %d motifs distincts (forme + arbre, à rotation près), "
          "dont %d divisés, tirés de %d clusters" % (len(motifs), divises, sum(compte.values())))
    print("  %d emplacements, écrite dans layouts\\banque.xml ; poids dans banque_poids.json"
          % (idn - 1))
    print("  les 5 motifs les plus fréquents pèsent : %s"
          % ", ".join(str(n) for _, n in motifs[:5]))


if __name__ == "__main__":
    main()
