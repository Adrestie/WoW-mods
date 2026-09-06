# -*- coding: utf-8 -*-
r"""Range les sorts de classe dans les onglets du grimoire.

L'onglet vient de SkillLineAbility.dbc, côté CLIENT — un sort qui n'y figure
pas tombe dans « Général ». Même mécanique que pour les runes de rang : on
CLONE une ligne Blizzard de la ligne de compétence voulue — elle porte déjà les
bons masques de race et de classe — en ne changeant que l'identifiant et le
sort, et en remettant à zéro SupercededBySpell et AcquireMethod.

Chaque sort de spécialisation rejoint l'onglet de sa spécialisation ; le sort
de mobilité rejoint le premier onglet de sa classe ; la spécialisation
« Général » n'écrit aucune ligne, puisque c'est justement là que tombe ce qui
n'en a pas. Les bienfaits du Coup de
dés et le battement du Souffle ne s'apprennent pas : pas de ligne pour eux.

    python gen_sla_classes.py          (JEU FERMÉ requis : écrit dans patch-z)
"""
import ctypes as C
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_visuel_aube as V
import sorts_classes as SC

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
SLA_BASE = 41000        # au-dessus des 30000+ des runes de rang

# Les lignes de compétence de 3.3.5, par classe et par onglet.
LIGNES = {
    "warrior": {"Armes": 26, "Fureur": 256, "Protection": 257, "mobilité": 26},
    "paladin": {"Vindicte": 184, "Protection": 267, "Sacré": 594, "mobilité": 184},
    "hunter": {"Maîtrise des bêtes": 50, "Précision": 163, "Survie": 51,
               "mobilité": 50},
    "rogue": {"Assassinat": 253, "Combat": 38, "Finesse": 39, "mobilité": 38},
    "priest": {"Ombre": 78, "Discipline": 613, "Sacré": 56, "mobilité": 613},
    "deathknight": {"Impie": 772, "Sang": 770, "Givre": 771, "mobilité": 770},
    "shaman": {"Amélioration": 373, "Élémentaire": 375, "Restauration": 374,
               "mobilité": 373},
    "mage": {"Arcanes": 237, "Feu": 8, "Givre": 6, "mobilité": 237},
    "warlock": {"Affliction": 355, "Démonologie": 354, "Destruction": 593,
                "mobilité": 354},
    "druid": {"Farouche": 134, "Équilibre": 574, "Restauration": 573,
              "mobilité": 134},
}

# Seuls les sorts qui s'APPRENNENT ont un onglet. La liste vit désormais dans
# la table de vérité : gen_sorts_classes en a besoin aussi, pour le temps de
# recharge global.
SANS_ONGLET = SC.SANS_ONGLET


def main():
    dll = V.stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(V.G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        chemin = "DBFilesClient" + BS + "SkillLineAbility.dbc"
        brut = V.lit(dll, h, chemin)
        magic, nrec, nfield, rsize, ssize = struct.unpack_from("<4s4I", brut, 0)
        enr = bytearray(brut[20:20 + nrec * rsize])
        chaines = brut[20 + nrec * rsize:]

        # Idempotence, et un gabarit par ligne de compétence.
        garde, retires = bytearray(), 0
        gabarits = {}
        for i in range(nrec):
            off = i * rsize
            ident, ligne = struct.unpack_from("<2I", enr, off)
            if SLA_BASE <= ident < SLA_BASE + 1000:
                retires += 1
                continue
            gabarits.setdefault(ligne, bytes(enr[off:off + rsize]))
            garde.extend(enr[off:off + rsize])
        enr, nrec = garde, nrec - retires

        pose = 0
        for sp in SC.SORTS:
            # La plage AUXILIAIRE ne s'apprend jamais : la regle vaut pour
            # toute la plage, on n'a donc pas a tenir SANS_ONGLET a jour a
            # chaque aura ajoutee par un script.
            # `grimoire=True` l'emporte sur la regle de plage : les sorts de
            # forme de la Charge sauvage vivent dans la plage auxiliaire faute
            # de place, mais doivent paraitre au grimoire pour qu'on puisse
            # les mettre a la barre.
            if sp["id"] in SANS_ONGLET:
                continue
            if SC.auxiliaire(sp["id"]) and not sp.get("grimoire"):
                continue
            # « Général » n'est pas une ligne de competence : c'est l'onglet
            # ou le client range ce qu'il ne rattache a aucune (le docstring
            # le dit plus haut). On n'ecrit donc PAS de ligne, et le sort y
            # tombe tout seul.
            if sp["spec"] == "Général":
                continue
            ligne = LIGNES[sp["classe"]][sp["spec"]]
            gab = gabarits.get(ligne)
            if gab is None:
                print("  aucune ligne à cloner pour la compétence %d (%s %s)"
                      % (ligne, sp["classe"], sp["spec"]))
                continue
            rec = bytearray(gab)
            struct.pack_into("<I", rec, 0, SLA_BASE + pose)
            struct.pack_into("<I", rec, 2 * 4, sp["id"])
            struct.pack_into("<I", rec, 8 * 4, 0)     # SupercededBySpell
            struct.pack_into("<I", rec, 9 * 4, 0)     # AcquireMethod
            enr.extend(rec)
            nrec += 1
            pose += 1

        entete = struct.pack("<4s4I", b"WDBC", nrec, nfield, rsize, ssize)
        V.ecrit(dll, h, chemin, entete + bytes(enr) + bytes(chaines))
        print("SkillLineAbility.dbc : %d ligne(s) retirée(s), %d posée(s)"
              % (retires, pose))
    finally:
        dll.SFileCloseArchive(h)


if __name__ == "__main__":
    main()
