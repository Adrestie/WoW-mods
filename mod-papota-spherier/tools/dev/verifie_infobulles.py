# -*- coding: utf-8 -*-
r"""Contrôle des infobulles des sorts customs : les nombres s'affichent-ils ?

Le client remplace les jetons du texte par des valeurs LUES DANS LE DBC, pas
par ce qu'un script calcule à l'exécution. Un jeton qui pointe vers un effet
vide affiche « 0 » ou « 1 » sans rien signaler, et l'infobulle ment.

Jetons contrôlés :

  $s<k> / $m<k> / $M<k>  la valeur de l'effet k        -> l'effet doit exister
                                                          et porter un montant
  $o<k>                  le total sur la durée de k    -> effet périodique
  $t<k>                  la période de l'effet k       -> EffectAuraPeriod
  $d                     la durée du sort              -> DurationIndex
  $a<k> / $A<k>          le rayon de l'effet k         -> EffectRadiusIndex
  $n                     le nombre de charges          -> ProcCharges
  $u                     le nombre de piles            -> CumulativeAura
  $i                     le nombre de cibles           -> EffectChainTargets

Rendu : une ligne par défaut trouvé, avec le sort, le jeton et la raison.

    python verifie_infobulles.py
"""
import ctypes as C
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
import sorts_classes as SC
from gen_visuel_aube import Dbc, stormlib, lit

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
# Un jeton peut être préfixé du sort visé ($123s1) : on le capture aussi.
JETON = re.compile(r"\$(?:(\d+))?([a-zA-Z])(\d)?")
CONNUS = set("sSmMoOtTdaAnuiIrRexzgGlLhpqbcvwEFCPHXVW")


def main():
    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0x00000100, C.byref(h)):
        raise SystemExit("archive non ouverte")
    try:
        cols, IDX = G.carte_des_champs()
        sp = Dbc(lit(dll, h, "DBFilesClient" + BS + "Spell.dbc"))
        base = {}
        for i in range(sp.nrec):
            o = i * sp.rsize
            ident = struct.unpack_from("<I", sp.enr, o)[0]
            if not any(a <= ident <= b for a, b in G.PLAGES):
                continue
            g = lambda c: struct.unpack_from("<i", sp.enr, o + IDX[c] * 4)[0]

            def txt(c):
                n = struct.unpack_from("<I", sp.enr, o + IDX[c] * 4)[0]
                return (sp.chaines[n:sp.chaines.index(b"\0", n)]
                        .decode("utf-8", "replace") if n else "")
            base[ident] = {
                "nom": txt("Name_Lang_koKR"),
                "desc": txt("Description_Lang_koKR"),
                "aura": txt("AuraDescription_Lang_koKR"),
                "effets": [g("Effect_%d" % k) for k in (1, 2, 3)],
                "auras": [g("EffectAura_%d" % k) for k in (1, 2, 3)],
                "points": [g("EffectBasePoints_%d" % k) + 1 for k in (1, 2, 3)],
                "des": [g("EffectDieSides_%d" % k) for k in (1, 2, 3)],
                "periodes": [g("EffectAuraPeriod_%d" % k) for k in (1, 2, 3)],
                "rayons": [g("EffectRadiusIndex_%d" % k) for k in (1, 2, 3)],
                "chaines": [g("EffectChainTargets_%d" % k) for k in (1, 2, 3)],
                "duree": g("DurationIndex"),
                "charges": g("ProcCharges"),
                "piles": g("CumulativeAura"),
            }
    finally:
        dll.SFileCloseArchive(h)

    defauts = []
    for ident in sorted(base):
        d = base[ident]
        for quoi, texte in (("description", d["desc"]), ("aura", d["aura"])):
            if not texte:
                continue
            for autre, lettre, index in JETON.findall(texte):
                jeton = "$%s%s%s" % (autre or "", lettre, index or "")
                if autre:
                    continue          # renvoi à un AUTRE sort : hors périmètre
                if lettre not in CONNUS:
                    defauts.append((ident, d["nom"], quoi, jeton,
                                    "jeton inconnu"))
                    continue
                if lettre in "sSmMoO":
                    if not index:
                        defauts.append((ident, d["nom"], quoi, jeton,
                                        "sans numéro d'effet"))
                        continue
                    k = int(index) - 1
                    if k > 2 or not d["effets"][k]:
                        defauts.append((ident, d["nom"], quoi, jeton,
                                        "l'effet %s n'existe pas" % index))
                    elif d["points"][k] in (0, 1) and not d["des"][k]:
                        defauts.append((ident, d["nom"], quoi, jeton,
                                        "affichera « %d » — l'effet %s n'a pas"
                                        " de montant" % (d["points"][k], index)))
                    elif lettre in "oO" and d["auras"][k] not in (3, 8, 20, 21,
                                                                 23, 53, 226):
                        defauts.append((ident, d["nom"], quoi, jeton,
                                        "l'effet %s n'est pas périodique"
                                        % index))
                elif lettre in "tT":
                    k = int(index or 1) - 1
                    if k > 2 or not d["periodes"][k]:
                        defauts.append((ident, d["nom"], quoi, jeton,
                                        "l'effet %s n'a pas de période"
                                        % (index or 1)))
                elif lettre == "d":
                    if not d["duree"]:
                        defauts.append((ident, d["nom"], quoi, jeton,
                                        "le sort n'a pas de durée"))
                elif lettre in "aA":
                    k = int(index or 1) - 1
                    if k > 2 or not d["rayons"][k]:
                        defauts.append((ident, d["nom"], quoi, jeton,
                                        "l'effet %s n'a pas de rayon"
                                        % (index or 1)))
                elif lettre == "n" and not d["charges"]:
                    defauts.append((ident, d["nom"], quoi, jeton,
                                    "le sort n'a pas de charges"))
                elif lettre == "u" and d["piles"] < 2:
                    defauts.append((ident, d["nom"], quoi, jeton,
                                    "le sort ne se cumule pas"))
                elif lettre in "iI":
                    k = int(index or 1) - 1
                    if k > 2 or not d["chaines"][k]:
                        defauts.append((ident, d["nom"], quoi, jeton,
                                        "l'effet %s n'enchaîne pas"
                                        % (index or 1)))

    print("%d sort(s) custom relus." % len(base))
    if not defauts:
        print("Aucune infobulle en défaut.")
        return
    print("%d défaut(s) :\n" % len(defauts))
    for ident, nom, quoi, jeton, raison in defauts:
        print("  %-8d %-26s %-12s %-6s %s"
              % (ident, nom[:26], quoi, jeton, raison))


if __name__ == "__main__":
    main()
