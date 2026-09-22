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

"""Faire entrer une feuille d'atlas dans l'atelier, avec son apercu et sa table.

POURQUOI PAR FEUILLE ET NON PAR ELEMENT. Une feuille versee apporte tous ses
elements d'un coup : le prochain cadre qui en a besoin n'exige plus de toucher
a l'archive. Et le client ne lie qu'une texture par cadre, ce qui est tout
l'interet des atlas.

CE QU'IL FAIT. Pour chaque ligne de tools/feuilles_complements.txt :
  1. exporte le .blp depuis le client moderne, par le pont de wow.export ;
  2. exporte le meme fichier en .png, l'apercu qui se range a cote ;
  3. les depose tous les deux dans data/art/interface/ForeverUI/... ;
puis regenere data/addon/ForeverUI/UIAtlas_06_complements.lua a partir de
l'index des atlas.

IL N'ECRIT PAS DANS LE CLIENT. L'atelier d'abord ; tools/deployer.py ensuite.

wow.export doit tourner avec sa source chargee (pont sur le port 9455).
"""
import io
import json
import os
import re
import shutil
import sys
import urllib.parse
import urllib.request

PONT = "http://127.0.0.1:9455"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTILS = os.path.join(RACINE, "tools")
ART = os.path.join(RACINE, "data", "art")
ADDON = os.path.join(RACINE, "data", "addon", "ForeverUI")
LISTE = os.path.join(OUTILS, "feuilles_complements.txt")
LISTE_SIMPLE = os.path.join(OUTILS, "fichiers_simples.txt")
INDEX = os.path.join(OUTILS, "atlas_dump.json")
PREFIXE = "ForeverUI"
BS = chr(92)

# Le temporaire de l'export, hors de l'atelier.
STAGING = os.path.join(os.environ.get("TEMP", "."), "foreverui_export")

_VARIANTE = re.compile("^(2x|4x|c[0-9]+)$")


def _demander(chemin, params):
    url = PONT + chemin + "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=900) as r:
        return json.loads(r.read().decode("utf-8"))


def _logique(nom):
    """Le nom sans ses suffixes de variante, tel que le code de camelot l'ecrit."""
    parts = nom.lower().split("-")
    while len(parts) > 1 and _VARIANTE.match(parts[-1]):
        parts.pop()
    return "-".join(parts)


# QUAND LE CLIENT NE NOMME PAS SON FICHIER.
#
# Le listfile est communautaire : il ne donne un nom qu'aux fichiers que
# quelqu'un a identifies. Les autres n'existent que par leur FileDataID, et
# wow.export les appelle "unknown_<id>". Le code de camelot, lui, connait le
# vrai nom -- il l'ecrit en clair -- mais rien ne permet de l'exporter par ce
# nom-la.
#
# Une ligne peut donc s'ecrire "source => nom voulu dans l'atelier" : on
# exporte par l'identifiant, et on range sous le nom de la source. L'atelier
# reste lisible, et l'identifiant demeure dans la liste pour retrouver le
# fichier plus tard.
_ALIAS = {}


def _lire(liste):
    voulues = []
    for ligne in io.open(liste, encoding="utf-8"):
        ligne = ligne.split("#")[0].strip()
        if not ligne:
            continue
        if "=>" in ligne:
            source, voulu = [part.strip().lower() for part in ligne.split("=>", 1)]
            _ALIAS[source] = voulu
            voulues.append(source)
        else:
            voulues.append(ligne.lower())
    return voulues


def feuilles_voulues():
    return _lire(LISTE)


def fichiers_simples():
    """Des images a part entiere : elles entrent, mais ne sont pas decoupees."""
    if not os.path.exists(LISTE_SIMPLE):
        return []
    return _lire(LISTE_SIMPLE)


def chemin_atelier(feuille, extension=".blp"):
    """interface/hud/x.blp -> data/art/interface/ForeverUI/hud/x.blp

    Un fichier sans nom dans le listfile se range sous celui que la source
    lui donne, pas sous son "unknown_<id>".
    """
    feuille = _ALIAS.get(feuille, feuille)
    morceaux = feuille.split("/")
    assert morceaux[0] == "interface", feuille
    return os.path.join(ART, "interface", PREFIXE, *morceaux[1:])[:-4] + extension


def exporter(voulues):
    manquantes = [f for f in voulues if not os.path.exists(chemin_atelier(f))]
    sans_apercu = [f for f in voulues
                   if os.path.exists(chemin_atelier(f))
                   and not os.path.exists(chemin_atelier(f, ".png"))]
    if not manquantes and not sans_apercu:
        print("art : les %d feuilles sont deja dans l'atelier, avec leur apercu" % len(voulues))
        return 0

    statut = _demander("/status", {})
    if not statut["ready"]:
        _demander("/load-source", {})
        raise SystemExit("la source de wow.export se charge, relancer dans une minute")

    os.makedirs(STAGING, exist_ok=True)
    poses = 0

    if manquantes:
        res = _demander("/export", [("dest", STAGING)] + [("file", f) for f in manquantes])
        if res["failed"]:
            raise SystemExit("export en echec : %s" % res)
        for f in manquantes:
            cible = chemin_atelier(f)
            os.makedirs(os.path.dirname(cible), exist_ok=True)
            shutil.copyfile(os.path.join(STAGING, f.replace("/", os.sep)), cible)
            print("   %-60s %8d o" % (os.path.relpath(cible, RACINE), os.path.getsize(cible)))
            poses += 1

    for f in manquantes + sans_apercu:
        # mask 15 : garder la couche alpha. La configuration de l'utilisateur
        # est a 7, ce qui donnerait un apercu opaque, inutilisable pour juger
        # d'un art d'interface.
        res = _demander("/export-textures", [("dest", STAGING), ("format", "png"),
                                             ("mask", "15"), ("file", f)])
        if res["failed"]:
            print("   PAS D'APERCU pour %s : %s" % (f, res["exported"]))
            continue
        source = res["exported"][0]["path"]
        cible = chemin_atelier(f, ".png")
        os.makedirs(os.path.dirname(cible), exist_ok=True)
        shutil.copyfile(source, cible)

    return poses


def regenerer_table(voulues):
    index = json.load(io.open(INDEX, encoding="utf-8"))["results"]
    par_feuille = {}
    for r in index:
        if (r.get("file") or "").lower() in voulues and r["atlas"]:
            par_feuille.setdefault(r["file"].lower(), []).append(r)

    absentes = [f for f in voulues if f not in par_feuille]
    if absentes:
        raise SystemExit("feuilles absentes de l'index des atlas : %s" % absentes)

    lignes = [
        "-- complements : feuilles ajoutees hors des cinq ecrans inventories.",
        "-- genere par tools/ajouter_feuilles.py depuis tools/atlas_dump.json",
        "",
        "UIAtlas = UIAtlas or { sheets = {}, data = {} }",
        "",
        "local S = {",
    ]
    ordre = sorted(par_feuille)
    numero = {}
    for i, f in enumerate(ordre, 1):
        numero[f] = i
        t = par_feuille[f][0]["sheet"]
        chemin = ("interface/" + PREFIXE + "/" + f[len("interface/"):])[:-4].replace("/", BS + BS)
        lignes.append('\t[%d] = "%s", -- %d x %d' % (i, chemin, t["width"], t["height"]))
    lignes += ["}", "", "local D = {"]

    total = 0
    deja = set()
    for f in ordre:
        # Une image en double densite s'affiche a la moitie de sa taille.
        facteur = 0.5 if "2x" in os.path.basename(f) else 1
        for r in sorted(par_feuille[f], key=lambda x: x["atlas"].lower()):
            sw, sh = r["sheet"]["width"], r["sheet"]["height"]
            reg = r["region"]
            u1 = reg["left"] / float(sw)
            u2 = (reg["left"] + reg["width"]) / float(sw)
            v1 = reg["top"] / float(sh)
            v2 = (reg["top"] + reg["height"]) / float(sh)
            largeur = int(round(reg["width"] * facteur))
            hauteur = int(round(reg["height"] * facteur))

            # Le nom brut, et le nom logique que le code de camelot emploie.
            for nom in (r["atlas"].lower(), _logique(r["atlas"])):
                if nom in deja:
                    continue
                deja.add(nom)
                lignes.append('\t["%s"] = {%d, %.6f, %.6f, %.6f, %.6f, %d, %d},' % (
                    nom, numero[f], u1, u2, v1, v2, largeur, hauteur))
                total += 1

    lignes += ["}", "",
               "for name, entry in pairs(D) do",
               "\tentry[1] = S[entry[1]]",
               "\tUIAtlas.data[name] = entry",
               "end",
               ""]

    dest = os.path.join(ADDON, "UIAtlas_06_complements.lua")
    io.open(dest, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print("table des complements : %d feuilles, %d noms, %d octets" % (
        len(ordre), total, os.path.getsize(dest)))


def main():
    voulues = feuilles_voulues()
    simples = fichiers_simples()
    exporter(voulues + simples)
    regenerer_table(voulues)
    print("l'atelier est a jour ; poser dans le client avec tools/deployer.py")


if __name__ == "__main__":
    main()
