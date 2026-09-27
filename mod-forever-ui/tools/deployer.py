# -*- coding: utf-8 -*-
# This file is part of mod-forever-ui.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

"""Poser ForeverUI dans un client 3.3.5 : l'addon d'un cote, l'art et les ecrans d'accueil dans patch-Z.

POURQUOI CE SCRIPT EXISTE. Le depot est la source, le client n'en est qu'une
copie. Editer dans Interface\\AddOns revient a travailler dans la copie : le
jour ou on verse depuis le depot, le travail disparait. On developpe donc ici,
et on pose la avec ce script.

CE QU'IL FAIT.
  addon : recopie data/addon/ForeverUI dans le client, et retire du client les
          fichiers qui ne sont plus dans le depot.
  art   : verse data/art/**.blp dans patch-Z.MPQ sous leur propre chemin, et
          les decors des ecrans d'accueil (data/art/Interface/Glues/Models,
          tools/decors_accueil.py) a la place de ceux du client. Les
          .png voisins sont des apercus pour l'oeil humain : ils ne partent
          pas dans l'archive. Un fichier deja identique n'est pas reverse, et
          un fichier de ForeverUI que le depot ne porte plus est RETIRE de
          l'archive.
  glue  : verse data/glue/Interface/GlueXML/** dans patch-Z sous
          Interface\\GlueXML : les ecrans d'accueil, ou aucun addon ne tourne.
          Meme regle que l'art : sous ce chemin, l'archive porte exactement le
          depot, rien de plus.

LA REGLE. Ce qui est sous Interface\\ForeverUI et sous Interface\\Glues\\Models
dans le patch doit etre le calque exact de data/art : ni fichier en plus, ni
fichier different. Editer
directement dans le client ou laisser trainer une feuille versee autrefois
casse cette egalite, et plus personne ne sait ce que le jeu affiche.

L'archive est verrouillee tant que le client tourne : fermer le jeu avant.
"""
import argparse
import hashlib
import io
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "tools"))

from foreverui import mpq  # noqa: E402

CLIENT_DEFAUT = r"E:\world of warcraft 3.3.5a hd"
NOM_ADDON = "ForeverUI"
PREFIXE_ARCHIVE = "interface" + os.sep + "ForeverUI" + os.sep
PREFIXE_GLUE = "Interface" + os.sep + "GlueXML" + os.sep
PREFIXE_DECORS = "Interface" + os.sep + "Glues" + os.sep + "Models" + os.sep

# Les fichiers de l'addon que les ecrans d'accueil emploient aussi : une seule
# source, versee sous un nom a elle dans Interface\GlueXML (fichier de
# l'addon -> nom dans l'archive).
PARTAGES_GLUE = {
    "ScrollBar.lua": "ForeverUIScrollBar.lua",
}


def _empreinte(donnees):
    return hashlib.sha1(donnees).hexdigest()


def poser_addon(client, bavard=True):
    source = os.path.join(RACINE, "data", "addon", NOM_ADDON)
    cible = os.path.join(client, "Interface", "AddOns", NOM_ADDON)
    os.makedirs(cible, exist_ok=True)

    attendus = set()
    poses, inchanges = 0, 0
    for nom in sorted(os.listdir(source)):
        if not (nom.endswith(".lua") or nom.endswith(".toc")):
            continue
        attendus.add(nom)
        brut = io.open(os.path.join(source, nom), "rb").read()
        chemin = os.path.join(cible, nom)
        if os.path.exists(chemin) and io.open(chemin, "rb").read() == brut:
            inchanges += 1
            continue
        io.open(chemin, "wb").write(brut)
        poses += 1

    retires = []
    for nom in sorted(os.listdir(cible)):
        if (nom.endswith(".lua") or nom.endswith(".toc")) and nom not in attendus:
            os.remove(os.path.join(cible, nom))
            retires.append(nom)

    if bavard:
        print("addon : %d pose(s), %d inchange(s), %d retire(s) %s" % (
            poses, inchanges, len(retires), retires or ""))
    return poses, retires


def _art_de_l_archive(archive, prefixe=PREFIXE_ARCHIVE):
    """Ce que l'archive porte sous un prefixe (Interface\\ForeverUI par
    defaut), d'apres son listfile."""
    if not archive.has("(listfile)"):
        return set()
    texte = archive.read("(listfile)").decode("utf-8", "replace")
    porte = set()
    for ligne in texte.splitlines():
        nom = ligne.strip().replace("/", os.sep)
        if nom.lower().startswith(prefixe.lower()):
            porte.add(nom)
    return porte


def _fichiers_art(prefixe=PREFIXE_ARCHIVE):
    """Chemin interne dans l'archive -> chemin sur le disque, sous prefixe."""
    base = os.path.join(RACINE, "data", "art")
    trouves = {}
    for racine, _dossiers, fichiers in os.walk(base):
        for nom in fichiers:
            # l'art, et les decors des ecrans d'accueil (tools/decors_accueil.py)
            if not nom.lower().endswith((".blp", ".m2", ".skin")):
                continue
            chemin = os.path.join(racine, nom)
            interne = os.path.relpath(chemin, base).replace("/", os.sep)
            if interne.lower().startswith(prefixe.lower()):
                trouves[interne] = chemin
    return trouves


def _fichiers_glue():
    """Chemin interne dans l'archive -> chemin sur le disque."""
    base = os.path.join(RACINE, "data", "glue")
    trouves = {}
    # sans ecrans d'accueil dans le depot, rien -- pas meme les fichiers
    # partages : l'archive redevient celle du client
    if not os.path.isdir(base):
        return trouves
    for racine, _dossiers, fichiers in os.walk(base):
        for nom in fichiers:
            if not nom.lower().endswith((".lua", ".xml", ".toc")):
                continue
            chemin = os.path.join(racine, nom)
            interne = os.path.relpath(chemin, base).replace("/", os.sep)
            assert interne.lower().startswith(PREFIXE_GLUE.lower()), interne
            trouves[interne] = chemin
    for source, nom in PARTAGES_GLUE.items():
        trouves[PREFIXE_GLUE + nom] = os.path.join(RACINE, "data", "addon", NOM_ADDON, source)
    return trouves


def _archive_z(client):
    archive_chemin = os.path.join(client, "data", "patch-Z.MPQ")
    if not os.path.exists(archive_chemin):
        archive_chemin = os.path.join(client, "Data", "patch-Z.MPQ")
    if not os.path.exists(archive_chemin):
        raise SystemExit("patch-Z.MPQ introuvable dans %s" % client)
    return archive_chemin


def poser_art(client, bavard=True):
    return (_verser(client, _fichiers_art(), PREFIXE_ARCHIVE, "art", bavard)
            + _verser(client, _fichiers_art(PREFIXE_DECORS), PREFIXE_DECORS, "decors", bavard))


def poser_glue(client, bavard=True):
    return _verser(client, _fichiers_glue(), PREFIXE_GLUE, "glue", bavard)


def _verser(client, art, prefixe, titre, bavard=True):
    archive_chemin = _archive_z(client)

    # Ne reverser que ce qui a change, et relever ce qui n'a plus lieu d'etre.
    a_verser = {}
    a_retirer = []
    archive = mpq.Archive(archive_chemin)
    try:
        for interne, chemin in sorted(art.items()):
            brut = io.open(chemin, "rb").read()
            if archive.has(interne) and _empreinte(archive.read(interne)) == _empreinte(brut):
                continue
            a_verser[interne] = brut

        attendus = set(n.lower() for n in art)
        a_retirer = sorted(n for n in _art_de_l_archive(archive, prefixe)
                           if n.lower() not in attendus)
    finally:
        archive.close()

    if not a_verser and not a_retirer:
        if bavard:
            print("%s : %d fichiers, l'archive est deja le calque du depot" % (titre, len(art)))
        return 0

    avant = os.path.getsize(archive_chemin)
    try:
        mpq.patch_archive(archive_chemin, a_verser, remove=a_retirer)
    except PermissionError:
        raise SystemExit("patch-Z.MPQ est verrouille : fermer le client avant de verser.")

    archive = mpq.Archive(archive_chemin)
    try:
        anomalies = [n for n, brut in a_verser.items()
                     if _empreinte(archive.read(n)) != _empreinte(brut)]
    finally:
        archive.close()

    if bavard:
        print("%s : %d verse(s) sur %d, %d retire(s) | archive %.3f -> %.3f Gio | relecture : %d anomalie(s)" % (
            titre, len(a_verser), len(art), len(a_retirer), avant / (1024.0 ** 3),
            os.path.getsize(archive_chemin) / (1024.0 ** 3), len(anomalies)))
        for n in a_retirer:
            print("   retire : %s" % n)
    if anomalies:
        raise SystemExit("relecture fausse : %s" % ", ".join(anomalies))
    return len(a_verser) + len(a_retirer)


def verifier(client):
    """Ce qui est pose correspond-il encore au depot ?"""
    source = os.path.join(RACINE, "data", "addon", NOM_ADDON)
    cible = os.path.join(client, "Interface", "AddOns", NOM_ADDON)
    ecarts = []
    for nom in sorted(os.listdir(source)):
        if not (nom.endswith(".lua") or nom.endswith(".toc")):
            continue
        pose = os.path.join(cible, nom)
        if not os.path.exists(pose):
            ecarts.append("absent du client : %s" % nom)
        elif io.open(pose, "rb").read() != io.open(os.path.join(source, nom), "rb").read():
            ecarts.append("different : %s" % nom)

    archive_chemin = os.path.join(client, "data", "patch-Z.MPQ")
    if os.path.exists(archive_chemin):
        archive = mpq.Archive(archive_chemin)
        try:
            for art, prefixe in ((_fichiers_art(), PREFIXE_ARCHIVE), (_fichiers_glue(), PREFIXE_GLUE),
                                 (_fichiers_art(PREFIXE_DECORS), PREFIXE_DECORS)):
                for interne, chemin in sorted(art.items()):
                    brut = io.open(chemin, "rb").read()
                    if not archive.has(interne):
                        ecarts.append("absent de l'archive : %s" % interne)
                    elif _empreinte(archive.read(interne)) != _empreinte(brut):
                        ecarts.append("different dans l'archive : %s" % interne)

                attendus = set(n.lower() for n in art)
                for n in sorted(_art_de_l_archive(archive, prefixe)):
                    if n.lower() not in attendus:
                        ecarts.append("en trop dans l'archive : %s" % n)
        finally:
            archive.close()

    if ecarts:
        print("ecarts entre le depot et le client : %d" % len(ecarts))
        for e in ecarts:
            print("   %s" % e)
    else:
        print("le client est conforme au depot")
    return ecarts


def main():
    analyseur = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    analyseur.add_argument("--client", default=CLIENT_DEFAUT, help="dossier du client 3.3.5")
    analyseur.add_argument("--addon", action="store_true", help="ne poser que l'addon")
    analyseur.add_argument("--art", action="store_true", help="ne verser que l'art")
    analyseur.add_argument("--glue", action="store_true", help="ne verser que les ecrans d'accueil")
    analyseur.add_argument("--verifier", action="store_true",
                           help="ne rien ecrire, seulement comparer")
    options = analyseur.parse_args()

    if options.verifier:
        verifier(options.client)
        return

    tout = not (options.addon or options.art or options.glue)
    if tout or options.addon:
        poser_addon(options.client)
    if tout or options.art:
        poser_art(options.client)
    if tout or options.glue:
        poser_glue(options.client)


if __name__ == "__main__":
    main()
