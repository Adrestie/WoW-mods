# -*- coding: utf-8 -*-
r"""Rend à patch-z les lignes de DBC qu'il a perdues en route.

LE DÉFAUT, établi le 2026-09-03 en cherchant pourquoi le Feu de l'âme (47825)
n'avait plus ni visuel ni animation d'incantation : son `SpellVisualID` vaut
20013, et cette ligne ÉTAIT ABSENTE de `SpellVisual.dbc`.

Le client de ce serveur est feuilleté : `locale-frFR.MPQ` s'arrête à l'id
12383, `patch-frFR-3.MPQ` va jusqu'à 16679, et `patch-frFR-z.mpq` — le patch
du chantier — jusqu'à 20015. Le 20013 ne vit que dans le dernier.

Or les générateurs de visuel relisent leur table DEPUIS PATCH-Z (`lit`, et non
`lit_effectif`), puis la réécrivent en entier. Il a donc suffi qu'une seule
passe, un jour, sème patch-z depuis une archive incomplète : les lignes
absentes de celle-là ont disparu, et chaque passe suivante a recopié le
manque. Six tables en portaient les traces, jusqu'à 228 lignes pour une seule.

Cet outil ne touche PAS aux lignes déjà présentes — les nôtres comprises. Il
ne fait qu'ajouter celles qui manquent, en reprenant pour chaque identifiant
la version de la PREMIÈRE archive de SOURCES_DBC qui la porte, donc la plus
autoritaire. Il est idempotent : une seconde exécution ne trouve plus rien.

    python repare_dbc_perdus.py            (constate, n'écrit rien)
    python repare_dbc_perdus.py --repare   (écrit ; JEU FERMÉ requis)
"""
import ctypes as C
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
from gen_visuel_aube import Dbc, stormlib, lit, ecrit
from gen_visuel_voleur import SOURCES_DBC

sys.stdout.reconfigure(encoding="utf-8")
BS = chr(92)

# Les colonnes qui portent un DÉCALAGE dans le bloc de chaînes. Réinsérer une
# ligne venue d'un autre fichier exige de recopier ses chaînes et de recalculer
# ces décalages : un décalage brut désignerait n'importe quoi.
TABLES = {
    "SpellVisual.dbc": (),
    "SpellVisualKit.dbc": (),
    "SpellVisualEffectName.dbc": (1, 2),
    "SoundEntries.dbc": (2,) + tuple(range(3, 13)) + (23,),
    "CreatureDisplayInfo.dbc": (6, 7, 8),
    "CreatureModelData.dbc": (2,),
}
# SkillLineAbility.dbc est ÉCARTÉE À DESSEIN : elle décide de ce qu'un joueur
# peut apprendre, et le chantier y retire des lignes exprès. Ses 654 « lignes
# perdues » n'en sont d'ailleurs pas (audit du 2026-09-06) : elles ne vivent que
# dans locale-frFR.MPQ et manquent à patch-frFR-3.MPQ, le DBC officiel 3.3.5
# qui remplace le fichier EN ENTIER — Blizzard les a retirées. RÉSERVE sur la
# méthode de cet outil : l'UNION des archives n'est pas la référence d'un DBC
# (chaque patch remplace le fichier), la première archive qui le porte l'est ;
# sur les six tables ci-dessus, l'union a pu rendre des lignes obsolètes de
# locale-frFR, jamais référencées, donc sans effet.


def chaine_de(d, decalage):
    """La chaîne à ce décalage, ou la chaîne vide si le décalage est nul."""
    if not decalage or decalage >= len(d.chaines):
        return b""
    fin = d.chaines.index(b"\x00", decalage)
    return bytes(d.chaines[decalage:fin])


def lignes_de(d):
    """{identifiant: (octets de la ligne, l'objet Dbc)} pour un DBC lu."""
    table = {}
    for i in range(d.nrec):
        off = i * d.rsize
        ident = struct.unpack_from("<I", d.enr, off)[0]
        table.setdefault(ident, off)
    return table


def main(repare):
    dll = stormlib()
    h = C.c_void_p()
    drapeau = 0 if repare else 0x00000100
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, drapeau, C.byref(h)):
        raise SystemExit("archive non ouverte%s"
                         % (" en écriture — JEU FERMÉ requis" if repare else ""))
    try:
        total = 0
        for nom, colonnes_chaines in sorted(TABLES.items()):
            chemin = "DBFilesClient" + BS + nom
            fh = C.c_void_p()
            if not dll.SFileOpenFileEx(h, chemin.encode("latin-1"), 0, C.byref(fh)):
                print("%-28s absente de patch-z, rien à faire" % nom)
                continue
            dll.SFileCloseFile(fh)
            cible = Dbc(lit(dll, h, chemin))
            presentes = set(lignes_de(cible))

            # LA PLUS AUTORITAIRE D'ABORD : le premier fichier qui porte un
            # identifiant fait foi pour lui.
            manquantes = {}
            for archive in SOURCES_DBC:
                if not os.path.exists(archive):
                    continue
                hs = C.c_void_p()
                if not dll.SFileOpenArchive(archive, 0, 0x00000100, C.byref(hs)):
                    continue
                try:
                    fh = C.c_void_p()
                    if not dll.SFileOpenFileEx(hs, chemin.encode("latin-1"),
                                               0, C.byref(fh)):
                        continue
                    dll.SFileCloseFile(fh)
                    src = Dbc(lit(dll, hs, chemin))
                    if src.nfield != cible.nfield:
                        print("%-28s %s : %d champs contre %d, écartée"
                              % (nom, os.path.basename(archive),
                                 src.nfield, cible.nfield))
                        continue
                    for ident, off in lignes_de(src).items():
                        if ident in presentes or ident in manquantes:
                            continue
                        valeurs = [struct.unpack_from("<i", src.enr, off + k * 4)[0]
                                   for k in range(src.nfield)]
                        textes = {k: chaine_de(src, valeurs[k])
                                  for k in colonnes_chaines}
                        manquantes[ident] = (valeurs, textes,
                                             os.path.basename(archive))
                finally:
                    dll.SFileCloseArchive(hs)

            if not manquantes:
                print("%-28s %5d lignes, rien à rendre" % (nom, cible.nrec))
                continue
            print("%-28s %5d lignes, %d à rendre (ex. %s)"
                  % (nom, cible.nrec, len(manquantes),
                     sorted(manquantes)[:6]))
            if not repare:
                total += len(manquantes)
                continue

            for ident in sorted(manquantes):
                valeurs, textes, _src = manquantes[ident]
                # Les chaînes sont recopiées dans NOTRE bloc, et le décalage
                # réécrit : c'est tout l'objet de cette manœuvre.
                for k, texte in textes.items():
                    valeurs[k] = cible.chaine(texte.decode("latin-1")) if texte else 0
                cible.pose(valeurs)
            ecrit(dll, h, chemin, cible.octets())
            print("%-28s -> %d lignes" % ("", cible.nrec))
            total += len(manquantes)
        print()
        if repare:
            print("%d ligne(s) rendue(s)." % total)
        elif total:
            print("%d ligne(s) manquante(s). Relancer avec --repare, JEU FERMÉ."
                  % total)
        else:
            print("Rien à réparer.")
    finally:
        dll.SFileCloseArchive(h)


if __name__ == "__main__":
    main("--repare" in sys.argv)
