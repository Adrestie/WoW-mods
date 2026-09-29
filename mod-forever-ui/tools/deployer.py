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
  dbc   : ajoute aux hauts faits (Achievement.dbc, Achievement_Criteria.dbc)
          les statistiques de data/dbc/statistiques.json, que l'onglet
          Statistics montre et que le coeur suit de lui-meme. Le DBC du jeu
          (celui que la chaine d'archives rend) recoit ces lignes, les siennes
          d'abord retirees, et va dans patch-Z ; puis le DBC du serveur en
          devient la copie octet pour octet (le client est la source de
          verite) -- seulement s'il etait deja la copie de celui du client.
          --retirer-dbc retire ces seules lignes des deux cotes ; une copie de
          patch-Z revenue a la version d'origine est retiree de l'archive.
          Les criteres qui en demandent (une creature tuee n'est comptee que
          si son critere y a une ligne) ont aussi leurs lignes dans
          achievement_criteria_data (base world, par le client mysql et les
          identifiants de worldserver.conf), effacees et reposees par
          identifiant de critere. Le serveur lit tout cela au demarrage : le
          redemarrer ensuite.

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
from foreverui import dbc  # noqa: E402

CLIENT_DEFAUT = r"E:\world of warcraft 3.3.5a hd"
SERVEUR_DEFAUT = r"E:\Serveur\bin\RelWithDebInfo"     # le dossier de worldserver.exe
STATISTIQUES = os.path.join(RACINE, "data", "dbc", "statistiques.json")
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


# ------------------------------------------------------------------ les statistiques

NB_LANGUES = 16
MASQUE_TEXTE = 0xFF01FE            # celui des lignes du 3.3.5
MASQUE_RECOMPENSE = 0xFF01EE
ICONE = 1                          # celle des statistiques du 3.3.5 sans icone propre
FICHIERS_DBC = ("Achievement.dbc", "Achievement_Criteria.dbc")


def _textes(t):
    # dans les seize colonnes de langue : un client d'une autre langue lit la
    # sienne, et y trouve le nom plutot qu'un vide
    return [t] * NB_LANGUES


def lignes_statistiques():
    """{fichier: dbc.Lignes} d'apres data/dbc/statistiques.json."""
    import json
    d = json.load(io.open(STATISTIQUES, encoding="utf-8"))
    if d.get("_format") != "foreverui-statistiques-dbc-1":
        raise SystemExit("%s : format inconnu" % STATISTIQUES)
    hauts, criteres = [], []
    for s in d["statistiques"]:
        # Achievement.dbc (62 champs) : ID, faction, carte, prerequis, titre x16
        # + masque, description x16 + masque, categorie, points, ordre,
        # drapeaux, icone, recompense x16 + masque, criteres minimum, partage
        hauts.append([s["id"], -1, s["carte"], 0] + _textes(s["nom"]) + [MASQUE_TEXTE] +
                     _textes(s["nom"]) + [MASQUE_TEXTE] +
                     [s["categorie"], s["points"], s["ordre"], s["drapeaux"], ICONE] +
                     _textes("") + [MASQUE_RECOMPENSE, 0, 0])
        for c in s["criteres"]:
            # Achievement_Criteria.dbc (31 champs) : ID, haut fait, type, cible,
            # quantite, debut (evenement, cible), echec (evenement, cible),
            # description x16 + masque, drapeaux, chronometre (evenement,
            # cible, duree), ordre
            criteres.append([c["id"], s["id"], c["type"], c["cible"], c["quantite"], 0, 0, 0, 0] +
                            _textes(c["texte"]) + [MASQUE_TEXTE, 0, 0, 0, 0, 1])
    return {"Achievement.dbc": dbc.Lignes(62, list(range(4, 20)) + list(range(21, 37)) + list(range(43, 59)),
                                          hauts),
            "Achievement_Criteria.dbc": dbc.Lignes(31, list(range(9, 25)), criteres)}


def _dossier_data(client):
    for n in os.listdir(client):
        if n.lower() == "data" and os.path.isdir(os.path.join(client, n)):
            return os.path.join(client, n)
    raise SystemExit("pas de dossier Data dans %s" % client)


def _langue(data):
    """le dossier de langue du client : celui de Data qui porte des archives"""
    for n in sorted(os.listdir(data)):
        d = os.path.join(data, n)
        if os.path.isdir(d) and any(f.lower().endswith(".mpq") for f in os.listdir(d)):
            return n
    return None


def dbc_serveur(serveur):
    """le dossier des DBC du serveur : DataDir de son worldserver.conf, + dbc"""
    conf = next((c for c in (os.path.join(serveur, "configs", "worldserver.conf"),
                             os.path.join(serveur, "worldserver.conf")) if os.path.isfile(c)), None)
    if not conf:
        raise SystemExit("worldserver.conf introuvable dans %s" % serveur)
    donnees = "."
    for ligne in io.open(conf, encoding="utf-8", errors="replace"):
        ligne = ligne.strip()
        if ligne.startswith("DataDir") and "=" in ligne:
            donnees = ligne.split("=", 1)[1].strip().strip('"')
    if not os.path.isabs(donnees):
        donnees = os.path.join(serveur, donnees)
    return os.path.join(os.path.normpath(donnees), "dbc")


def _fermer(chaine):
    for a in chaine.archives:
        a.close()


def poser_dbc(client, serveur, retirer=False, bavard=True):
    """Les statistiques dans les DBC du client (patch-Z) puis du serveur."""
    lignes = lignes_statistiques()
    data = _dossier_data(client)
    langue = _langue(data)
    archive_z = _archive_z(client)
    dossier_serveur = dbc_serveur(serveur)
    chaine = mpq.open_client(data, langue)
    dessous = mpq.open_client(data, langue, ignore=(os.path.basename(archive_z),))
    z = mpq.Archive(archive_z)
    a_verser, a_retirer, pour_serveur = {}, [], {}
    try:
        for fichier in FICHIERS_DBC:
            nom = "DBFilesClient\\" + fichier
            actuel = chaine.read(nom)
            d = lignes[fichier]
            if retirer:
                neuf, n = dbc.retirer(actuel, nom, d)
            else:
                neuf, n = dbc.ajouter(actuel, nom, d), len(d.ids)
            if neuf == dessous.read(nom):
                # rien de plus que la version d'origine : la copie de patch-Z
                # n'a plus lieu d'etre
                if z.has(nom):
                    a_retirer.append(nom)
            elif neuf != actuel:
                a_verser[nom] = neuf
            pour_serveur[fichier] = (actuel, neuf)
            if bavard:
                print("dbc : %s, %d ligne(s) %s" % (fichier, n, "retiree(s)" if retirer else "posee(s)"))
    finally:
        _fermer(chaine)
        _fermer(dessous)
        z.close()
    if a_verser or a_retirer:
        try:
            mpq.patch_archive(archive_z, a_verser, remove=a_retirer)
        except PermissionError:
            raise SystemExit("patch-Z.MPQ est verrouille : fermer le client avant de verser.")
        if bavard:
            print("dbc : patch-Z, %d ecrit(s), %d retire(s)" % (len(a_verser), len(a_retirer)))
    elif bavard:
        print("dbc : patch-Z deja conforme")
    # le serveur, copie du client : seulement s'il l'etait deja
    for fichier, (avant, apres) in pour_serveur.items():
        p = os.path.join(dossier_serveur, fichier)
        actuel = io.open(p, "rb").read() if os.path.isfile(p) else None
        if actuel == apres:
            continue
        if actuel != avant:
            print("dbc : %s n'est pas la copie de celui du client : laisse tel quel" % p)
            continue
        io.open(p + ".foreverui-tmp", "wb").write(apres)
        os.replace(p + ".foreverui-tmp", p)
        if bavard:
            print("dbc : %s recopie du client (redemarrer le worldserver)" % p)
    poser_donnees(serveur, retirer, bavard)


def _conf_serveur(serveur):
    conf = next((c for c in (os.path.join(serveur, "configs", "worldserver.conf"),
                             os.path.join(serveur, "worldserver.conf")) if os.path.isfile(c)), None)
    if not conf:
        raise SystemExit("worldserver.conf introuvable dans %s" % serveur)
    valeurs = {}
    for ligne in io.open(conf, encoding="utf-8", errors="replace"):
        ligne = ligne.strip()
        if "=" in ligne and not ligne.startswith("#"):
            cle, valeur = ligne.split("=", 1)
            valeurs[cle.strip()] = valeur.strip().strip('"')
    return valeurs


def _mysql(serveur):
    """le client mysql : celui de worldserver.conf, celui qu'ont retenu les
    installeurs du depot, ou celui du PATH"""
    import json
    import shutil
    candidats = [_conf_serveur(serveur).get("MySQLExecutable")]
    try:
        memoire = os.path.join(os.environ.get("APPDATA") or "", "WoW-mods", "installeur.json")
        candidats.append(json.load(io.open(memoire, encoding="utf-8")).get("mysql"))
    except (OSError, ValueError):
        pass
    candidats.append(shutil.which("mysql"))
    for c in candidats:
        if c and os.path.isfile(c):
            return c
    raise SystemExit("client mysql introuvable (MySQLExecutable dans worldserver.conf)")


def _sql(serveur, requete):
    """une requete sur la base world du serveur ; rend les lignes (texte)"""
    import subprocess
    info = _conf_serveur(serveur).get("WorldDatabaseInfo", "").split(";")
    if len(info) != 5:
        raise SystemExit("WorldDatabaseInfo illisible dans worldserver.conf")
    hote, port, utilisateur, mot_de_passe, base = info
    env = dict(os.environ, MYSQL_PWD=mot_de_passe)
    r = subprocess.run([_mysql(serveur), "-h", hote, "-P", port, "-u", utilisateur, base, "-N", "-B",
                        "-e", requete], capture_output=True, text=True, env=env)
    if r.returncode != 0:
        raise SystemExit("mysql : %s" % r.stderr.strip())
    return [l.split("\t") for l in r.stdout.splitlines() if l]


def donnees_statistiques():
    """[(critere, type, valeur1, valeur2)] : les lignes d'achievement_criteria_data"""
    import json
    d = json.load(io.open(STATISTIQUES, encoding="utf-8"))
    lignes = []
    for s in d["statistiques"]:
        for c in s["criteres"]:
            for x in c.get("donnees", []):
                lignes.append((c["id"], x["type"], x["valeur1"], x["valeur2"]))
    return lignes


def _criteres_statistiques():
    import json
    d = json.load(io.open(STATISTIQUES, encoding="utf-8"))
    return [c["id"] for s in d["statistiques"] for c in s["criteres"]]


def poser_donnees(serveur, retirer=False, bavard=True):
    """Les lignes d'achievement_criteria_data de nos criteres : les notres
    d'abord effacees (par identifiant de critere), puis posees, sauf au
    retrait. Le coeur les lit au demarrage (ou par .reload
    achievement_criteria_data)."""
    ids = ", ".join(str(i) for i in _criteres_statistiques())
    lignes = [] if retirer else donnees_statistiques()
    requete = "DELETE FROM achievement_criteria_data WHERE criteria_id IN (%s);" % ids
    if lignes:
        requete += " INSERT INTO achievement_criteria_data (criteria_id, type, value1, value2, ScriptName) VALUES %s;" % (
            ", ".join("(%d, %d, %d, %d, '')" % l for l in lignes))
    _sql(serveur, requete)
    if bavard:
        print("dbc : achievement_criteria_data, %d ligne(s) %s" % (
            len(donnees_statistiques()) if retirer else len(lignes), "retiree(s)" if retirer else "posee(s)"))


def verifier_donnees(serveur):
    ids = ", ".join(str(i) for i in _criteres_statistiques())
    lues = sorted(tuple(int(v) for v in l) for l in _sql(
        serveur, "SELECT criteria_id, type, value1, value2 FROM achievement_criteria_data WHERE criteria_id IN (%s)" % ids))
    if lues != sorted(donnees_statistiques()):
        return ["achievement_criteria_data : lignes des statistiques absentes ou differentes"]
    return []


def verifier_dbc(client, serveur):
    """Les statistiques sont-elles dans les DBC du client, et le serveur en est-il la copie ?"""
    ecarts = []
    lignes = lignes_statistiques()
    data = _dossier_data(client)
    chaine = mpq.open_client(data, _langue(data))
    try:
        for fichier in FICHIERS_DBC:
            nom = "DBFilesClient\\" + fichier
            actuel = chaine.read(nom)
            if dbc.ajouter(actuel, nom, lignes[fichier]) != actuel:
                ecarts.append("statistiques absentes ou differentes dans le DBC du client : %s" % fichier)
            p = os.path.join(dbc_serveur(serveur), fichier)
            if not os.path.isfile(p) or io.open(p, "rb").read() != actuel:
                ecarts.append("DBC du serveur different de celui du client : %s" % fichier)
    finally:
        _fermer(chaine)
    return ecarts + verifier_donnees(serveur)


def verifier(client, serveur=SERVEUR_DEFAUT):
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

    ecarts += verifier_dbc(client, serveur)

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
    analyseur.add_argument("--dbc", action="store_true",
                           help="ne poser que les statistiques dans les DBC du client et du serveur")
    analyseur.add_argument("--retirer-dbc", action="store_true",
                           help="retirer les statistiques des DBC du client et du serveur")
    analyseur.add_argument("--serveur", default=SERVEUR_DEFAUT, help="dossier du worldserver")
    analyseur.add_argument("--verifier", action="store_true",
                           help="ne rien ecrire, seulement comparer")
    options = analyseur.parse_args()

    if options.verifier:
        verifier(options.client, options.serveur)
        return
    if options.retirer_dbc:
        poser_dbc(options.client, options.serveur, retirer=True)
        return

    tout = not (options.addon or options.art or options.glue or options.dbc)
    if tout or options.addon:
        poser_addon(options.client)
    if tout or options.art:
        poser_art(options.client)
    if tout or options.glue:
        poser_glue(options.client)
    if tout or options.dbc:
        poser_dbc(options.client, options.serveur)


if __name__ == "__main__":
    main()
