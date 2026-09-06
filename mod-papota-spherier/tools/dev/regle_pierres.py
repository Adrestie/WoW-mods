# -*- coding: utf-8 -*-
r"""Règle les pierres d'une disposition : qualités, statistiques, nœuds vides.

Ne touche QUE les emplacements de type « noeud ». Les slots, les emplacements de
sort, les clusters, les liaisons et le départ ressortent inchangés, à l'octet
près — c'est la condition pour qu'une disposition validée à l'écran le reste.

Trois règles, dans cet ordre :

  1. **La qualité suit l'éloignement**, mesuré en nombre de LIAISONS depuis le
     départ — le chemin que le joueur paie réellement. QUATRE bandes de distance,
     de la commune à l'épique, plus une légendaire par cluster au plus, PROMUE et
     non posée par une bande : une bande de distance en déposerait une douzaine
     dans un cluster profond.

     C'est cette forme, et elle seule, qui garantit la transition : deux nœuds
     voisins ne diffèrent que d'une liaison de distance, donc au plus d'un cran
     de qualité. Jamais de légendaire après une rare — il y a forcément une
     épique entre les deux. Un critère qui regarderait autre chose que la
     distance, « être en bout de ligne » par exemple, romprait la garantie : une
     feuille légendaire pourrait toucher un nœud rare.
  2. **Seules les statistiques utiles à la classe** sont proposées.
  3. **Les totaux s'équilibrent, et les qualités suivent la géométrie.** Chaque
     statistique atteint la même somme, mais pas par le même chemin : celle qui
     vit au bord la fait en peu de grosses pierres, celle qui vit au centre en
     beaucoup de petites. Exiger en plus la même RÉPARTITION de qualités pour
     toutes abîme le sphérier — les pierres communes vivant toutes près du
     départ, réclamer seize communes pour la parade la fait remonter au centre,
     que la règle veut générique.
  5. **Trois d'affilée au plus.** En suivant les liaisons, on ne rencontre
     jamais quatre fois de suite la même statistique. Trois sont permises : une
     veine se laisse suivre un moment, elle ne traverse pas la grille.
  4. **La grille se partage en trois zones**, une par spécialisation, autour de
     son centre géométrique. Près du départ rien n'est marqué ; plus on s'en
     éloigne, plus les statistiques de la zone l'emportent, jusqu'aux clusters
     du bord qui ne proposent plus que celles de leur spécialisation. Un cluster
     à cheval sur deux zones propose un mélange des deux.

Puis les nœuds vides sont posés, répartis entre les clusters, sans jamais
prendre la place d'un slot ni d'un sort — ils n'en sont pas — ni celle du départ,
ni celle d'un légendaire de bout de ligne, qui perdrait sa raison d'être.

    python regle_pierres.py warrior
"""
import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import MYSQL_HOTE, MYSQL_PORT, MYSQL_UTILISATEUR, MYSQL_MDP, BASE_WORLD  # ce qui décrit le poste, hors du dépôt
import io
import math
import os
import random
import re
import subprocess
import sys
import tempfile
from collections import defaultdict, deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import profils_classes

sys.stdout.reconfigure(encoding="utf-8")

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
BASE = BASE_WORLD
LAYOUTS = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\lua_scripts\Spherier\layouts"

# Catalogue des seize statistiques, dans l'ordre du §8 : c'est cet ordre qui
# donne son indice à chacune, et donc l'entrée de sa pierre.
STAT_ORDRE = [
    "endurance", "intelligence", "esprit", "dexterite", "force",
    "parade", "blocage", "esquive", "hate", "critique", "touche",
    "puissance_sorts", "puissance_attaque", "penetration_armure",
    "expertise", "bonus_soins",
]

# Ce qu'une classe sait employer. Un guerrier ne tire rien de l'intelligence, de
# l'esprit, de la puissance des sorts ni du bonus des soins.
#
# La DEXTÉRITÉ est écartée elle aussi. Elle rendait quelque chose à un guerrier
# Protection — esquive et armure — et à peu près rien aux deux autres, si bien
# qu'exiger d'elle autant de points que des autres la faisait refluer vers le
# centre, là où le joueur attend de la force et du critique. Onze statistiques
# qui servent valent mieux que douze dont une encombre. La remettre tient en un
# mot ici, et à un profil par spécialisation plus bas.
UTILES = {
    "warrior": ["endurance", "force", "parade", "blocage",
                "esquive", "hate", "critique", "touche", "puissance_attaque",
                "penetration_armure", "expertise"],
}


# ---------------------------------------------------------------------------
# Zonage par spécialisation
# ---------------------------------------------------------------------------
# La grille se partage en trois secteurs autour du départ, un par
# spécialisation. Les axes ne sont pas saisis : ce sont les CLUSTERS PORTEURS DE
# SORT, que la disposition place aux extrémités, et qu'on apparie aux trois
# spécialisations par angle croissant. Chaque zone se termine donc sur son sort,
# et la règle vaut pour toutes les classes sans rien écrire de particulier.
#
# Les profils vivent dans profils_classes.py, écrits par archétypes de rôle.

# La montée en spécialisation, en fraction du rayon maximal. En deçà de R0 rien
# n'est marqué ; au-delà de R1 la zone parle seule. Entre les deux, une courbe
# en S : la bascule se fait dans la moitié du trajet, sans marche d'escalier.
R0, R1 = 0.20, 0.88
# Netteté angulaire : à faible rayon un cluster voisine avec les trois zones, au
# bord il n'entend plus que la sienne. C'est ce qui laisse aux clusters à cheval
# leur mélange, tant qu'ils ne sont pas au bout.
NETTETE = 7.0
# Épuration : au bord, les statistiques sans intérêt pour la zone tombent à
# rien. Sans elle, une trace de blocage subsisterait au bout de la branche Armes.
EPURATION = 3.5
# L'équilibrage se règle par des PRIX, un par statistique, et non par un ordre
# de passage. Une statistique qui traîne voit son prix monter jusqu'à ce qu'elle
# emporte des nœuds ; une statistique servie voit le sien baisser. Le procédé ne
# dépend d'aucun ordre — c'est tout son intérêt : un glouton, qui sert les nœuds
# du bord en premier parce qu'ils sont les plus contraints, laissait au centre
# les seules statistiques encore en manque, c'est-à-dire les défensives. Le
# centre se retrouvait couvert de parade et de blocage, l'inverse de ce qu'on
# lui demande.
TOURS = 1200         # itérations de réglage
ETA = 0.10           # vitesse de correction d'un prix
# Le prix est BORNÉ : passé ce rapport, l'équilibrage cesse de peser contre
# l'affinité. C'est un arbitrage assumé — parade, blocage et esquive n'ont qu'un
# tiers de la grille où vivre, si bien que les égaliser parfaitement les ferait
# ressortir au centre. Mieux vaut un écart honnête que des zones brouillées.
#
# La borne est SERRÉE, et c'est un choix : une borne large amenait bien chaque
# case à sa cible du premier coup, mais au prix des zones — la pénétration
# d'armure allait se loger jusqu'au bout de la branche de Fureur, où elle n'a
# rien à faire. On laisse donc le prix trancher les cas faciles et la correction
# finale placer les vingt dernières pierres, en zone-connaissance de cause.
PRIX_MAX = 8.0
# Chaque nœud TIRE sa statistique au sort, avec les chances que lui donne son
# profil : c'est la formulation même de la règle — les statistiques utiles à la
# zone ont plus de CHANCES d'y apparaître, pas la certitude d'y régner. Prendre
# à chaque fois la mieux notée donnait des clusters d'une monotonie absurde,
# vingt nœuds de pénétration d'armure à la file.
#
# BETA creuse l'écart entre les chances : à 1, un profil de 0,5 vaut la moitié
# d'un profil de 1 ; à 3, il n'en vaut plus que le huitième. C'est ce qui rend
# une préférence lisible sans la rendre exclusive.
BETA = 2.6
# Le tirage est reproductible : un nombre par nœud, tiré d'une graine fixe. Il ne
# change pas d'un tour de réglage à l'autre, faute de quoi les prix
# poursuivraient une cible mouvante et ne convergeraient jamais.
GRAINE = 20260827
# Le plus long enfilement toléré, en nœuds. Corriger un nœud peut en faire
# basculer un autre : on repasse jusqu'à ce que plus rien ne bouge.
SUITE_MAX = 3
PASSES = 40


def lissage(t):
    """Courbe en S : plate aux deux bouts, franche au milieu."""
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def ecart_angulaire(a, b):
    return abs((a - b + 180.0) % 360.0 - 180.0)


def profils_par_cluster(cellules, clusters, classe, depart):
    """Rend, pour chaque cluster, son profil de statistiques et sa pureté.

    **Le centre est le DÉPART**, et non le barycentre des clusters. Le barycentre
    a l'air plus juste et ne l'est pas : il se déplace dès qu'on ajoute des
    nexus. Neuf nexus posés à l'ouest l'ont tiré vers l'ouest, si bien que les
    clusters de l'ouest sont devenus « centraux » — la zone qu'on voulait
    enrichir s'est appauvrie de ce seul fait. Le départ, lui, ne bouge pas, et
    c'est de lui que le joueur s'éloigne.
    """
    utiles_, commun, liste = profils_classes.profil(classe)
    cd = cellules[depart]["cluster"]
    cx, cy = clusters[cd][0], clusters[cd][1]

    rayon = {c: math.hypot(clusters[c][0] - cx, clusters[c][1] - cy) for c in clusters}
    angle = {c: math.degrees(math.atan2(clusters[c][1] - cy, clusters[c][0] - cx)) % 360.0
             for c in clusters}
    rmax = max(rayon.values()) or 1.0

    # Les axes : les clusters porteurs de sort, ordonnés par angle croissant et
    # appariés aux spécialisations dans l'ordre de la table.
    porteurs = sorted(set(a["cluster"] for a in cellules.values()
                          if a.get("type") == "sort"),
                      key=lambda c: angle[c])
    if len(porteurs) != len(liste):
        raise SystemExit("%d emplacement(s) de sort pour %d spécialisation(s)"
                         % (len(porteurs), len(liste)))
    specs = dict((c, liste[k]) for k, c in enumerate(porteurs))

    profils, puretes, dominantes, poids_zone = {}, {}, {}, {}
    for c in clusters:
        p = lissage((rayon[c] / rmax - R0) / (R1 - R0))

        # Poids angulaires : (1 + cos écart) / 2, jamais nul sauf à l'opposé,
        # élevé à une puissance qui croît avec le rayon. Près du centre les trois
        # zones se répondent ; au bord, une seule subsiste.
        k = 1.0 + NETTETE * p
        w = {}
        for cle in specs:
            cosinus = math.cos(math.radians(ecart_angulaire(angle[c], angle[cle])))
            w[cle] = ((1.0 + cosinus) / 2.0) ** k
        somme = sum(w.values()) or 1.0
        w = {cle: v / somme for cle, v in w.items()}

        melange = {}
        for s in utiles_:
            zone = sum(w[cle] * specs[cle][1][s] for cle in specs)
            melange[s] = (1.0 - p) * commun[s] + p * zone

        # Épuration : au bord, ce qui ne sert pas à la zone disparaît.
        expo = 1.0 + EPURATION * p
        melange = {s: v ** expo for s, v in melange.items()}
        haut = max(melange.values()) or 1.0
        profils[c] = {s: v / haut for s, v in melange.items()}
        puretes[c] = p
        poids_zone[c] = w
        dominantes[c] = max(w, key=lambda cle: w[cle])
    noms = {cle: specs[cle][0] for cle in specs}
    return profils, puretes, dominantes, noms, poids_zone, rmax

NB_VIDES = 35
QUALITES = 5
# Part des QUATRE premières qualités, de la commune à l'épique — la légendaire
# ne vient pas d'une bande. Les seuils qui en découlent portent sur la DISTANCE,
# jamais sur un rang : tous les nœuds à la même distance du départ reçoivent la
# même qualité, sans quoi la garantie de transition tomberait. Les effectifs
# obtenus s'écartent donc un peu de ces parts, du gradin que forme l'histogramme
# des distances.
#
# La pyramide penche vers le bas : beaucoup de communes et d'inhabituelles, peu
# d'épiques. C'est ce qui règle le volume de statistiques — pas les montants des
# pierres, qui sont un réglage d'objet et non de grille.
PARTS = [0.48, 0.29, 0.15, 0.08]


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
        return [l.split("\t") for l in r.stdout.splitlines() if l.strip()]
    finally:
        os.unlink(chemin)


def montants_par_qualite():
    """Ce que vaut une pierre de chaque qualité, lu dans le catalogue : le
    tableau d'équilibrage ne doit pas recopier des chiffres qui vivent en base.
    """
    montants = {}
    for entree, montant, qualite in requete(
            "SELECT s.item_entry, s.amount, t.Quality FROM papota_sphere_stone s "
            "JOIN item_template t ON t.entry = s.item_entry;"):
        montants[int(qualite)] = int(montant)
    return montants


# --------------------------------------------------------------------- lecture
nom = sys.argv[1] if len(sys.argv) > 1 else "warrior"
classe = sys.argv[2] if len(sys.argv) > 2 else "warrior"
chemin = os.path.join(LAYOUTS, nom + ".xml")
brut = io.open(chemin, encoding="utf-8").read()

RE_EMP = re.compile(r'( *)<emplacement ([^/]*)/>')
RE_ATTR = re.compile(r'(\w+)="([^"]*)"')

cellules = {}
for indent, attrs in RE_EMP.findall(brut):
    a = dict(RE_ATTR.findall(attrs))
    cellules[int(a["id"])] = a

clusters = {}
for i, x, y in re.findall(r'<cluster id="(\d+)" x="([-\d.]+)" y="([-\d.]+)"', brut):
    clusters[i] = (float(x), float(y))

liens = defaultdict(list)
for x, y in re.findall(r'<liaison a="(\d+)" b="(\d+)"/>', brut):
    x, y = int(x), int(y)
    liens[x].append(y)
    liens[y].append(x)

depart = int(re.search(r'<depart id="(\d+)"/>', brut).group(1))

noeuds = [i for i, a in cellules.items() if a.get("type") == "noeud"]
print("%s : %d emplacements dont %d nœuds, %d liaisons, départ %d"
      % (nom, len(cellules), len(noeuds), sum(len(v) for v in liens.values()) // 2,
         depart))

# ------------------------------------------------------- éloignement et bouts
# Le nombre de liaisons depuis le départ : le chemin que le joueur paie.
dist = {depart: 0}
file = deque([depart])
while file:
    ici = file.popleft()
    for la in liens[ici]:
        if la not in dist:
            dist[la] = dist[ici] + 1
            file.append(la)

orphelins = [i for i in noeuds if i not in dist]
if orphelins:
    print("  %d nœud(s) hors d'atteinte du départ, laissés à la qualité la plus "
          "basse : %s" % (len(orphelins), orphelins[:8]))

degre = {i: len(liens[i]) for i in cellules}
dmax = max((dist[i] for i in noeuds if i in dist), default=0)

# ------------------------------------------------------------------ qualités
# Les bouts de ligne les plus éloignés : légendaires. Pris au pied de la lettre,
# « à la distance maximale » n'en désignerait qu'UN — la grille compte 56 bouts
# de ligne mais une seule branche file jusqu'au bout. On retient donc le haut du
# classement des bouts de ligne, ce qui récompense chaque branche poussée à son
# terme sans brader la qualité.
#
# Le reste se répartit en quatre bandes d'EFFECTIFS comparables, et non de
# distances : les nœuds se pressent entre quinze et vingt-cinq liaisons du
# départ, si bien que des bandes taillées sur les distances videraient les
# qualités hautes.
# Les seuils : on remonte les distances en accumulant les effectifs, et l'on
# coupe dès que la part visée est atteinte. La coupure tombe TOUJOURS entre deux
# distances, jamais au milieu d'une.
effectif = defaultdict(int)
for i in noeuds:
    effectif[dist.get(i, 0)] += 1
seuils, cumul, vise = [], 0, 0.0
for q in range(len(PARTS) - 1):
    vise += PARTS[q]
    for d in sorted(effectif):
        if seuils and d <= seuils[-1]:
            continue
        cumul += effectif[d]
        if cumul >= vise * len(noeuds):
            seuils.append(d)
            break
    else:
        seuils.append(max(effectif))

qualite = {}
for i in noeuds:
    d = dist.get(i, 0)
    q = len(PARTS)
    for rang, seuil in enumerate(seuils):
        if d <= seuil:
            q = rang + 1
            break
    qualite[i] = q

# La légendaire : UNE par cluster au plus, promue AVEC SON HALO.
#
# Exiger qu'elle soit déjà entourée d'épiques liait deux choses sans rapport :
# plus la bande épique se resserre — et on la veut resserrée — moins de clusters
# pouvaient en porter une, deux ou trois sur vingt-neuf. On promeut donc le nœud
# le plus éloigné du cluster ET l'on fait passer ses voisins en épique, juste ce
# qu'il faut pour qu'aucune légendaire ne touche une rare. Chaque promotion coûte
# un à trois épiques au lieu d'exiger une bande entière.
#
# La promotion se pose à l'essai et se défait si elle casse quoi que ce soit :
# un halo peut toucher une inhabituelle en contrebas, et le saut serait de deux
# crans. Les emplacements sans pierre — slots, sorts — ne comptent pas, ils n'ont
# pas de qualité à contredire.
legendaires = set()
halo = 0
par_cluster_l = defaultdict(list)
for i in noeuds:
    par_cluster_l[cellules[i]["cluster"]].append(i)
for c in sorted(par_cluster_l, key=int):
    for i in sorted(par_cluster_l[c], key=lambda k: (-dist.get(k, 0), k)):
        if qualite[i] < len(PARTS) - 1:
            break        # triés par éloignement : au-delà, même plus rare
        essai = {i: QUALITES}
        for j in liens[i]:
            if j in qualite and qualite[j] < len(PARTS):
                essai[j] = len(PARTS)
        provisoire = dict(qualite)
        provisoire.update(essai)
        casse = False
        for a in essai:
            for b in liens[a]:
                if b in provisoire and abs(provisoire[a] - provisoire[b]) > 1:
                    casse = True
                    break
            if casse:
                break
        if not casse:
            halo += len(essai) - 1
            qualite.update(essai)
            legendaires.add(i)
            break

# Vérification : deux nœuds voisins ne peuvent différer de plus d'un cran. Elle
# ne peut pas échouer tant que la qualité ne dépend que de la distance — c'est
# précisément ce qu'elle surveille.
for i in noeuds:
    for j in liens[i]:
        if j in qualite and abs(qualite[i] - qualite[j]) > 1:
            raise SystemExit("saut de qualité entre %d (%d) et %d (%d)"
                             % (i, qualite[i], j, qualite[j]))

# --------------------------------------------------------------------- vides
# Répartis entre les clusters, en épargnant le départ et les légendaires de bout
# de ligne, qui perdraient leur raison d'être.
par_cluster = defaultdict(list)
for i in noeuds:
    if i != depart and i not in legendaires:
        par_cluster[cellules[i]["cluster"]].append(i)
for v in par_cluster.values():
    v.sort()

vides = set()
tour = 0
while len(vides) < NB_VIDES:
    pose = False
    for cl in sorted(par_cluster, key=lambda c: int(c)):
        libres = par_cluster[cl]
        # Un pas irrégulier plutôt que les premiers de la liste : les trous se
        # dispersent dans le cluster au lieu de se coller les uns aux autres.
        k = (tour * 3 + 1) % max(1, len(libres))
        for essai in range(len(libres)):
            cand = libres[(k + essai * 5) % len(libres)]
            if cand not in vides:
                vides.add(cand)
                pose = True
                break
        if len(vides) >= NB_VIDES:
            break
    tour += 1
    if not pose:
        print("  impossible de poser %d vides, %d seulement" % (NB_VIDES, len(vides)))
        break

# ---------------------------------------------------------------- statistiques
montants = montants_par_qualite()
utiles = profils_classes.profil(classe)[0]
total = {s: 0 for s in utiles}
stat = {}

profils, puretes, dominantes, noms_zone, poids_zone, rmax = profils_par_cluster(
    cellules, clusters, classe, depart)

a_garnir = [i for i in noeuds if i not in vides]

# Une case par couple statistique / qualité, et sa cible — UN ENTIER.
#
# Chaque bande donne à toutes les statistiques son plancher, puis il reste
# quelques pierres à placer : c'est à qui on les donne que se joue l'écart final.
# Un reste d'épique vaut trois restes de commune, si bien qu'il ne faut ni les
# donner tous aux mêmes, ni les donner au hasard. On part d'un placement glouton
# — le reste va à la somme la plus basse — puis on améliore par échanges tant
# qu'un déplacement resserre les sommes.
cases = [(st, q) for st in utiles for q in range(1, QUALITES + 1)]
par_qualite = defaultdict(int)
for i in a_garnir:
    par_qualite[qualite[i]] += 1

n = len(utiles)

# La répartition NATURELLE : combien de fois chaque statistique sortirait à
# chaque qualité si les prix n'existaient pas. C'est la forme que la géométrie
# commande, et c'est elle qu'on veut conserver.
naturel = dict((cle, 0.0) for cle in cases)
for i in a_garnir:
    profil = profils[cellules[i]["cluster"]]
    poids = dict((st, profil[st] ** BETA) for st in utiles)
    somme = sum(poids.values()) or 1.0
    for st in utiles:
        naturel[(st, qualite[i])] += poids[st] / somme

# Ajustement biproportionnel : on met alternativement les colonnes puis les
# lignes à leur marge, jusqu'à ce que les deux tombent juste. Les colonnes disent
# combien de pierres porte chaque bande, les lignes que toutes les statistiques
# atteignent la même somme.
PLANCHER = 1e-9
x = dict((cle, max(naturel[cle], PLANCHER)) for cle in cases)
cible_somme = sum(montants[qualite[i]] for i in a_garnir) / float(n)
for _ in range(400):
    for q in range(1, QUALITES + 1):
        col = sum(x[(st, q)] for st in utiles) or 1.0
        for st in utiles:
            x[(st, q)] *= par_qualite[q] / col
    for st in utiles:
        ligne = sum(x[(st, q)] * montants[q] for q in range(1, QUALITES + 1)) or 1.0
        for q in range(1, QUALITES + 1):
            x[(st, q)] *= cible_somme / ligne

# Arrondi : le plancher pour tout le monde, puis les restes de chaque bande aux
# plus fortes parties fractionnaires — c'est la colonne qui doit tomber juste.
cible = dict((cle, int(x[cle])) for cle in cases)
for q in range(1, QUALITES + 1):
    reste = par_qualite[q] - sum(cible[(st, q)] for st in utiles)
    ordre = sorted(utiles, key=lambda st: (-(x[(st, q)] - int(x[(st, q)])), st))
    for k in range(reste):
        cible[(ordre[k % n], q)] += 1


def sommes():
    return dict((st, sum(cible[(st, q)] * montants[q]
                         for q in range(1, QUALITES + 1))) for st in utiles)


def dispersion(s):
    moyenne = sum(s.values()) / float(n)
    return sum((v - moyenne) ** 2 for v in s.values())


# L'arrondi laisse quelques points d'écart : on déplace une pierre d'une
# statistique à l'autre DANS UNE MÊME BANDE — la colonne reste donc juste — tant
# que cela resserre les sommes.
for _ in range(400):
    s, mieux = sommes(), None
    depart = dispersion(s)
    for q in range(1, QUALITES + 1):
        for a in utiles:
            if cible[(a, q)] <= 0:
                continue
            for b in utiles:
                if b == a:
                    continue
                cible[(a, q)] -= 1
                cible[(b, q)] += 1
                d = dispersion(sommes())
                cible[(a, q)] += 1
                cible[(b, q)] -= 1
                if d < depart - 1e-9 and (mieux is None or d < mieux[0]):
                    mieux = (d, a, b, q)
    if not mieux:
        break
    _, a, b, q = mieux
    cible[(a, q)] -= 1
    cible[(b, q)] += 1

s = sommes()
print("   cibles : %d à %d points par statistique (écart théorique %d)"
      % (min(s.values()), max(s.values()), max(s.values()) - min(s.values())))


de_ = dict((i, random.Random(GRAINE + i).random()) for i in a_garnir)


def groupe(choix, i, st):
    """Les nœuds reliés à i qui portent st, i compris."""
    vus, pile = set([i]), [i]
    while pile:
        n = pile.pop()
        for j in liens[n]:
            if j not in vus and choix.get(j) == st:
                vus.add(j)
                pile.append(j)
    return vus


def plus_longue_ligne(grp):
    """Nombre de nœuds de la plus longue LIGNE du groupe — un chemin qui ne
    repasse jamais par le même nœud.

    C'est bien une ligne qu'il faut mesurer, et non la taille du groupe : quatre
    pierres identiques en étoile autour d'une cinquième ne font jamais quatre
    d'affilée, puisque tout trajet qui les traverse repasse par le centre. Les
    interdire serait plus sévère que la règle.

    La recherche s'arrête dès qu'une ligne dépasse : il n'y a rien à gagner à
    mesurer combien elle dépasse.
    """
    plus_long = 0
    for depart in grp:
        pile = [(depart, frozenset([depart]))]
        while pile:
            n, vus = pile.pop()
            if len(vus) > plus_long:
                plus_long = len(vus)
                if plus_long > SUITE_MAX:
                    return plus_long
            for j in liens[n]:
                if j in grp and j not in vus:
                    pile.append((j, vus | frozenset([j])))
    return plus_long


def acceptable(choix, i, st):
    """Le nœud i peut-il porter st sans allonger une ligne au-delà du permis ?

    Seul le groupe où i ATTERRIT est examiné : celui qu'il quitte ne peut que
    raccourcir, jamais s'allonger.
    """
    ancien = choix[i]
    choix[i] = st
    trop_long = plus_longue_ligne(groupe(choix, i, st)) > SUITE_MAX
    choix[i] = ancien
    return not trop_long


def fautifs_de(choix):
    """Les nœuds des groupes où une ligne dépasse le permis."""
    faux, vus = [], set()
    for i in a_garnir:
        if i in vus:
            continue
        grp = groupe(choix, i, choix[i])
        vus |= grp
        if plus_longue_ligne(grp) > SUITE_MAX:
            faux.extend(sorted(grp))
    return faux


def tire(profil, prix, u, permises, q):
    poids = [(st, (profil[st] ** BETA) * prix[(st, q)]) for st in permises]
    somme = sum(w for _, w in poids)
    if somme <= 0.0:
        return poids[-1][0]
    seuil = u * somme
    for st, w in poids:
        seuil -= w
        if seuil <= 0.0:
            return st
    return poids[-1][0]


def repare(choix, prix):
    """Lève les chaînes de trois. Rend le nombre de nœuds déplacés et ce qui
    resterait de fautif — normalement rien."""
    bouges = 0
    for passe in range(PASSES):
        fautifs = fautifs_de(choix)
        if not fautifs:
            return bouges, 0
        for i in fautifs:
            # Un nœud corrigé plus tôt dans la même passe a pu régler le cas :
            # rien ne sert de déplacer tout un groupe quand un seul suffit.
            if acceptable(choix, i, choix[i]):
                continue
            profil = profils[cellules[i]["cluster"]]
            u = random.Random(GRAINE * 7 + i * 131 + passe).random()
            permises = [st for st in utiles if acceptable(choix, i, st)]
            if not permises:
                continue        # aucune issue : on laisse, le rapport le dira
            choix[i] = tire(profil, prix, u, permises, qualite[i])
            bouges += 1
    return bouges, len(fautifs_de(choix))


def attribue(prix):
    """Chaque nœud tire sa statistique selon ses chances, sans regarder ses
    voisins ni ce qui a déjà été posé : l'attribution ne dépend que des prix."""
    choix = {}
    for i in a_garnir:
        choix[i] = tire(profils[cellules[i]["cluster"]], prix, de_[i], utiles,
                        qualite[i])
    # La correction fait partie de l'attribution, et non d'une retouche après
    # coup : les prix doivent voir les totaux TELS QU'ILS SERONT, sinon
    # l'équilibrage se règle sur une répartition qui n'existe plus.
    bouges, restants = repare(choix, prix)
    cumul = dict((cle, 0) for cle in cases)
    for i in a_garnir:
        cumul[(choix[i], qualite[i])] += 1
    return choix, cumul, bouges, restants


prix = dict((cle, 1.0) for cle in cases)
for _ in range(TOURS):
    _, cumul, _, _ = attribue(prix)
    for cle in cases:
        if cible[cle] <= 0:
            continue
        prix[cle] *= (cible[cle] / max(0.5, cumul[cle])) ** ETA
        prix[cle] = min(PRIX_MAX, max(1.0 / PRIX_MAX, prix[cle]))
stat, effectifs, bouges, restants = attribue(prix)


def compte_cases(choix):
    c = dict((cle, 0) for cle in cases)
    for i in a_garnir:
        c[(choix[i], qualite[i])] += 1
    return c


# Les prix mènent chaque case à sa cible à une pierre près, et cette pierre-là
# compte : une légendaire déplacée vaut trente points, de quoi faire passer
# l'écart entre statistiques de quatre à cinquante-huit. On termine donc à la
# main, en choisissant le nœud dont le déplacement COÛTE LE MOINS D'AFFINITÉ —
# celui pour lequel la statistique d'arrivée est presque aussi légitime que celle
# de départ. Les bandes chères d'abord : ce sont elles qui pèsent.
deplaces = 0
for _ in range(80):
    compte = compte_cases(stat)
    trop = [cle for cle in cases if compte[cle] > cible[cle]]
    if not trop:
        break
    bouge = False
    for (sa, q) in sorted(trop, key=lambda cle: -montants[cle[1]]):
        if compte[(sa, q)] <= cible[(sa, q)]:
            continue
        manque = [sb for sb in utiles if compte[(sb, q)] < cible[(sb, q)]]
        meilleur = None
        for i in a_garnir:
            if stat[i] != sa or qualite[i] != q:
                continue
            profil = profils[cellules[i]["cluster"]]
            for sb in manque:
                if not acceptable(stat, i, sb):
                    continue
                cout = profil[sa] - profil[sb]
                if meilleur is None or cout < meilleur[0]:
                    meilleur = (cout, i, sb)
        if meilleur:
            _, i, sb = meilleur
            compte[(stat[i], q)] -= 1
            compte[(sb, q)] += 1
            stat[i] = sb
            deplaces += 1
            bouge = True
    if not bouge:
        break

reste = sum(max(0, compte_cases(stat)[cle] - cible[cle]) for cle in cases)
print("   cases : %d pierre(s) replacée(s), %d case(s) encore au-dessus de la cible"
      % (deplaces, reste))

total = dict((st, 0) for st in utiles)
for i in a_garnir:
    total[stat[i]] += montants[qualite[i]]
print("   suites : %d nœud(s) déplacé(s), %d nœud(s) encore en ligne trop longue"
      % (bouges, restants))

# ------------------------------------------------------------------- écriture
def recrire(m):
    indent, attrs = m.group(1), m.group(2)
    a = dict(RE_ATTR.findall(attrs))
    i = int(a["id"])
    if a.get("type") != "noeud":
        return m.group(0)               # slot, sort : rien n'y est touché
    bout = '%s<emplacement id="%d" cluster="%s" anneau="%s" branche="%s" type="noeud"' % (
        indent, i, a["cluster"], a["anneau"], a["branche"])
    if i in vides:
        return bout + "/>"
    return bout + ' stat="%s" qualite="%d"/>' % (stat[i], qualite[i])


neuf = RE_EMP.sub(recrire, brut)
io.open(chemin, "w", encoding="utf-8", newline="\n").write(neuf)

# ------------------------------------------------------------------ rapport
print("\nQualités :   (%d légendaire(s) promue(s), %d épique(s) de halo)"
      % (len(legendaires), halo))
for q in range(1, QUALITES + 1):
    n = sum(1 for i in noeuds if i not in vides and qualite[i] == q)
    borne = ("jusqu'à %d liaisons" % seuils[q - 1]) if q <= len(seuils) \
        else ("au-delà de %d liaisons" % seuils[-1])
    print("   %d (%2d points) : %3d nœud(s)   %s" % (q, montants[q], n, borne))
print("   vides          : %3d nœud(s), répartis sur %d cluster(s)"
      % (len(vides), len({cellules[i]["cluster"] for i in vides})))

print("\nStatistiques, du plus fourni au moins fourni :")
for s in sorted(utiles, key=lambda k: -total[k]):
    n = sum(1 for i in a_garnir if stat[i] == s)
    print("   %-20s %4d points sur %2d nœud(s)" % (s, total[s], n))
obtenu = compte_cases(stat)
print("%sPierres par statistique et par qualité — cible / obtenu :" % chr(10))
print("   %-19s %8s %8s %8s %8s %8s" % ("", "comm", "inhab", "rare", "épiq", "légend"))
for st in sorted(utiles, key=lambda k: -total[k]):
    ligne = "   %-19s" % st
    for q in range(1, QUALITES + 1):
        ligne += " %8s" % ("%d/%d" % (cible[(st, q)], obtenu[(st, q)]))
    print(ligne)

ecart = max(total.values()) - min(total.values())
print("\n   écart entre la mieux et la moins bien servie : %d point(s)" % ecart)

print("\nZones, du centre vers le bord :")
print("   %-6s %-12s %-7s %s" % ("clust", "zone", "pureté", "statistiques proposées"))
for c in sorted(clusters, key=lambda k: puretes[k]):
    dedans = [i for i in a_garnir if cellules[i]["cluster"] == c]
    if not dedans:
        continue
    compte = defaultdict(int)
    for i in dedans:
        compte[stat[i]] += 1
    liste = ", ".join("%s x%d" % (n, k)
                      for n, k in sorted(compte.items(), key=lambda kv: -kv[1]))
    print("   %-6s %-12s %5.0f%%   %s"
          % (c, noms_zone[dominantes[c]], puretes[c] * 100, liste))

# Compter un cluster entier pour sa zone dominante exagère : à 0 % de pureté un
# cluster n'appartient à personne. On pèse donc chaque nœud par la pureté de son
# cluster et par le poids de la zone, et l'on montre à part ce qui reste commun.
print("\nPoints par zone, pondérés par la pureté :")
oriente = dict((cle, 0.0) for cle in noms_zone)
commun_pts = 0.0
for i in a_garnir:
    c = cellules[i]["cluster"]
    m, p = montants[qualite[i]], puretes[c]
    commun_pts += m * (1.0 - p)
    for cle in noms_zone:
        oriente[cle] += m * p * poids_zone[c][cle]
total_pts = commun_pts + sum(oriente.values())
for cle, nom in sorted(noms_zone.items(), key=lambda kv: -oriente[kv[0]]):
    print("   %-12s %5.0f points  (%2.0f %%)"
          % (nom, oriente[cle], 100.0 * oriente[cle] / total_pts))
print("   %-12s %5.0f points  (%2.0f %%)   — près du départ, sans orientation"
      % ("commun", commun_pts, 100.0 * commun_pts / total_pts))
print("\n%s réécrit. Chaîne à rejouer : importe_layout.lua -> SQL -> .spherier reload"
      % chemin)
