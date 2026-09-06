# -*- coding: utf-8 -*-
r"""Barème du prix des emplacements du sphèrier.

Règle arrêtée par l'utilisateur le 2026-08-26 :
  - grilles de 254 emplacements ;
  - le premier emplacement est GRATUIT ;
  - le deuxième coûte 50 Spherite ;
  - le dernier coûte 5 000, la croissance étant régulière entre les deux
    (plafond abaissé de 100 000 à 50 000 le 2026-08-26, puis à 5 000 le
    2026-09-06 pour la grille commune : au-delà du 254e, le prix reste à 5 000).

Le taux s'en déduit : 50 × r^252 = 50 000, soit r = 1000^(1/252), c'est-à-dire
**+2,7791 % par emplacement**.

Deux façons d'appliquer cette croissance, qui ne donnent pas le même résultat :

  A. composer sur la valeur DÉJÀ ARRONDIE — « le prix précédent majoré de x % ».
     L'arrondi vers le haut s'accumule et pousse la fin de courbe bien au-dessus
     de la cible.
  B. arrondir la formule fermée — prix(n) = ceil(50 × r^(n-2)). Aucune dérive,
     le dernier tombe exactement sur la cible.

**B est retenu.** La contrepartie est que deux prix voisins ne montent pas
d'exactement le taux au début, où l'arrondi pèse lourd. Passer à A ne demande
qu'à changer `FERMEE` ci-dessous, mais il faudrait alors rabaisser le taux pour
compenser la dérive.
"""

import io
import math
import os

SORTIE = (r"D:\Serveur WoW\azerothcore-wotlk\modules\mod-papota-spherier"
          r"\data\sql\world\2026_08_26_00_mod_papota_spherier_couts.sql")

NOMBRE   = 254      # emplacements par grille
PREMIER  = 0        # le premier est gratuit
DEUXIEME = 50
CIBLE    = 5000     # prix du dernier (50 000 -> 5 000 le 2026-09-06, grille commune)
FERMEE   = True     # False = composer sur l'arrondi (variante A)

TAUX = (float(CIBLE) / DEUXIEME) ** (1.0 / (NOMBRE - 2)) - 1.0


# L'arrondi supérieur mord sur l'erreur de virgule flottante : 50 × r^252 vaut
# 50000.000000001 et donnerait 50001. Une tolérance d'un milliardième suffit à
# faire tomber le dernier emplacement pile sur la cible.
EPSILON = 1e-9


def plafond(valeur):
    return int(math.ceil(valeur - EPSILON))


def bareme():
    couts = [PREMIER, DEUXIEME]
    if FERMEE:
        for i in range(2, NOMBRE):
            couts.append(plafond(DEUXIEME * (1.0 + TAUX) ** (i - 1)))
    else:
        while len(couts) < NOMBRE:
            couts.append(plafond(couts[-1] * (1.0 + TAUX)))
    return couts


couts = bareme()

L = [
    "-- mod-papota-spherier : bareme du prix des emplacements.",
    "-- GENERE par outils_spherier\\gen_bareme_couts.py — ne pas editer a la main.",
    "--",
    "-- Grilles de %d emplacements. Le premier est gratuit, le deuxieme coute %d," % (NOMBRE, DEUXIEME),
    "-- le dernier %d ; la croissance est reguliere entre les deux, soit" % CIBLE,
    "-- +%.4f %% par emplacement (decision du 2026-08-26)." % (TAUX * 100),
    "-- Une ligne par emplacement : chacun a son propre prix.",
    "",
    "DELETE FROM `papota_sphere_cost`;",
    "INSERT INTO `papota_sphere_cost` (`activated_min`, `cost`) VALUES",
]
L.append(",\n".join("(%d, %d)" % (i, c) for i, c in enumerate(couts)) + ";")

os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
with io.open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(L) + "\n")

print("SQL ecrit :", SORTIE)
print("  %d tranches, taux %.4f %% par emplacement, de %d a %d Spherite."
      % (len(couts), TAUX * 100, couts[0], couts[-1]))
print("  cout total de la grille : %d Spherite" % sum(couts))
print()
print("  emplacement      prix        cumul")
cumul = 0
for i, c in enumerate(couts, start=1):
    cumul += c
    if i in (1, 2, 3, 5, 10, 20, 30, 50, 75, 100, 127, 150, 200, 254):
        print("  %11d %9d %12d" % (i, c, cumul))
