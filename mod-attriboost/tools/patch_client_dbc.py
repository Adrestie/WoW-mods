# -*- coding: utf-8 -*-
"""mod-attriboost — patch des DBC du CLIENT.

Ajoute les 10 sorts (890000-890009) et les 2 objets (890010-890011) du module
dans un Spell.dbc et un Item.dbc extraits du client, et écrit le résultat dans
un dossier prêt à empaqueter en MPQ.

Le SERVEUR n'a pas besoin de ce patch : il lit les mêmes lignes depuis les
tables `spell_dbc` et `item_dbc` (fichier 01_attriboost_dbc.sql). Le client,
lui, ne lit que ses fichiers : sans ce patch, les auras du module s'appliquent
mais n'ont ni nom, ni icône, ni infobulle, et les deux livres apparaissent avec
un point d'interrogation.

Usage :
    python patch_client_dbc.py <dossier_source> [dossier_sortie]

    dossier_source : contient Spell.dbc et Item.dbc extraits du client
    dossier_sortie : par défaut « out\\DBFilesClient » à côté de ce script

Sans argument, le script demande les chemins. Il ne modifie jamais les fichiers
d'entrée. Partez toujours des DBC d'ORIGINE : relancé sur sa propre sortie, le
script reste correct mais laisse grossir le pool de chaînes.
"""
import json
import os
import struct
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
DEFS = os.path.join(ICI, "attriboost_dbc.json")
NAME, RANK, DESC, TIP = 136, 153, 170, 187      # début des quatre blocs localisés
LOCALES = 16                                    # 16 langues, puis un masque, par bloc
ID_SORTS = range(890000, 890010)
ID_OBJETS = (890010, 890011)


class Erreur(Exception):
    pass


def lire_dbc(chemin, champs_attendus, nom):
    """Rend (enregistrements, pool de chaînes)."""
    if not os.path.isfile(chemin):
        raise Erreur("fichier introuvable : %s" % chemin)
    brut = open(chemin, "rb").read()
    if brut[:4] != b"WDBC":
        raise Erreur("%s n'est pas un DBC (signature WDBC absente)" % nom)
    nb, champs, taille, taille_chaines = struct.unpack_from("<4I", brut, 4)
    if champs != champs_attendus or taille != champs_attendus * 4:
        raise Erreur("%s a %d champs, %d attendus : version de client inattendue"
                     % (nom, champs, champs_attendus))
    recs = [list(struct.unpack_from("<%di" % champs, brut, 20 + i * taille))
            for i in range(nb)]
    debut = 20 + nb * taille
    return recs, bytearray(brut[debut:debut + taille_chaines])


def ecrire_dbc(chemin, recs, chaines, champs):
    """Écrit un DBC trié par identifiant, comme le fait le client."""
    recs = sorted(recs, key=lambda r: r[0])
    sortie = bytearray(b"WDBC")
    sortie += struct.pack("<4I", len(recs), champs, champs * 4, len(chaines))
    for r in recs:
        sortie += struct.pack("<%di" % champs, *r)
    sortie += chaines
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    open(chemin, "wb").write(bytes(sortie))


def ajouter_chaine(chaines, texte):
    """Ajoute une chaîne au pool et rend son offset. L'offset 0 vaut « vide »."""
    if not texte:
        return 0
    offset = len(chaines)
    chaines.extend(texte.encode("utf-8") + b"\0")
    return offset


def patcher_sorts(recs, chaines, defs):
    recs = [r for r in recs if r[0] not in ID_SORTS]
    for s in defs["spells"]:
        rec = [0] * defs["spell_fields"]
        for index, valeur in s["champs"].items():
            rec[int(index)] = valeur
        rec[0] = s["id"]
        for base, cle in ((NAME, "name"), (RANK, "rank"),
                          (DESC, "description"), (TIP, "tooltip")):
            bloc = s[cle]
            rec[base + 0] = ajouter_chaine(chaines, bloc["enUS"])
            rec[base + 2] = ajouter_chaine(chaines, bloc["frFR"])
            rec[base + LOCALES] = bloc["masque"]
        recs.append(rec)
    return recs


def patcher_objets(recs, defs):
    recs = [r for r in recs if r[0] not in ID_OBJETS]
    for it in defs["items"]:
        recs.append(list(it["champs"]))
    return recs


def demander(invite, defaut=""):
    reponse = input(invite).strip().strip('"')
    return reponse or defaut


def main():
    print("mod-attriboost - patch des DBC du client")
    print("-" * 56)
    if not os.path.isfile(DEFS):
        raise Erreur("attriboost_dbc.json manquant a cote de ce script")
    defs = json.load(open(DEFS, encoding="utf-8"))
    if defs.get("_format") != "attriboost-dbc-1":
        raise Erreur("attriboost_dbc.json d'un format inconnu")

    if len(sys.argv) > 1:
        source = sys.argv[1]
        sortie = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ICI, "out", "DBFilesClient")
    else:
        source = demander("Dossier contenant Spell.dbc et Item.dbc : ")
        sortie = demander("Dossier de sortie [out\\DBFilesClient] : ",
                          os.path.join(ICI, "out", "DBFilesClient"))
    if not source:
        raise Erreur("aucun dossier source indique")
    if not os.path.isdir(source):
        raise Erreur("dossier source introuvable : %s" % source)

    print("source : %s" % source)
    print("sortie : %s" % sortie)
    print()

    recs, chaines = lire_dbc(os.path.join(source, "Spell.dbc"), defs["spell_fields"], "Spell.dbc")
    avant = len(recs)
    recs = patcher_sorts(recs, chaines, defs)
    ecrire_dbc(os.path.join(sortie, "Spell.dbc"), recs, chaines, defs["spell_fields"])
    print("Spell.dbc : %d sorts lus, %d ecrits (10 sorts du module)" % (avant, len(recs)))

    recs, chaines = lire_dbc(os.path.join(source, "Item.dbc"), defs["item_fields"], "Item.dbc")
    avant = len(recs)
    recs = patcher_objets(recs, defs)
    ecrire_dbc(os.path.join(sortie, "Item.dbc"), recs, chaines, defs["item_fields"])
    print("Item.dbc  : %d objets lus, %d ecrits (2 objets du module)" % (avant, len(recs)))

    # Relecture de contrôle : on vérifie ce qui est sur le disque, pas ce qu'on
    # croit avoir écrit.
    verif, _ = lire_dbc(os.path.join(sortie, "Spell.dbc"), defs["spell_fields"], "Spell.dbc")
    ids = set(r[0] for r in verif)
    manquants = [i for i in ID_SORTS if i not in ids]
    verif, _ = lire_dbc(os.path.join(sortie, "Item.dbc"), defs["item_fields"], "Item.dbc")
    ids = set(r[0] for r in verif)
    manquants += [i for i in ID_OBJETS if i not in ids]
    if manquants:
        raise Erreur("relecture : identifiants absents %s" % manquants)

    print()
    print("Termine. Relecture des deux fichiers : les 12 identifiants sont presents.")
    print()
    print("Etape suivante : empaqueter le dossier de sortie dans une archive MPQ")
    print("dont le nom passe APRES les archives officielles du client, par exemple")
    print("patch-4.MPQ, en conservant l'arborescence DBFilesClient\\<fichier>.dbc.")
    print("Voir la section \"Installation cote client\" du README.")


if __name__ == "__main__":
    try:
        main()
    except Erreur as e:
        print()
        print("ECHEC : %s" % e)
        sys.exit(1)
