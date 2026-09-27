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

"""La table d'atlas des ecrans d'accueil.

POURQUOI. Aucun addon ne tourne dans les ecrans d'accueil (GlueXML) : ils ont
leur propre table, reduite aux elements qu'ils posent.

D'OU VIENT CHAQUE CHOSE.
  * Les COORDONNEES et le fichier : des tables de l'addon (UIAtlas_*.lua),
    une seule source, qui pointe les feuilles de l'atelier.
  * La TAILLE D'AFFICHAGE et la MOSAIQUE : de UiTextureAtlasMember.db2 du
    client moderne -- la taille imposee (OverrideWidth/Height) si elle
    existe, sinon celle de l'element ; une variante -2x, taille imposee
    comprise, compte en double densite et s'affiche a moitie. Drapeaux :
    4 = mosaique horizontale, 2 = verticale. (Releve du 2026-09-27 : les
    coins UI-Frame-DiamondMetal font 32 x 32 -- 128 texels, taille imposee
    64 en double densite ; le coin d'en-tete sort a 32 x 39, la taille que
    DialogHeaderTemplate lui donne en dur.)
  * LA VARIANTE : le code de camelot nomme ses elements sans suffixe ; le
    client prend la variante de camelot (c60) et, a l'echelle des ecrans
    d'accueil (1,33 px par unite), la double densite (2x). Ordre essaye :
    nom-c60-2x, nom-c60, nom-2x, nom.

CE QU'IL FAIT. Prend les noms de tools/atlas_accueil.txt et ecrit
data/glue/Interface/GlueXML/ForeverUIGlueAtlas.lua :
  ["nom de camelot"] = { fichier, u1, u2, v1, v2, largeur, hauteur,
                         mosaiqueH, mosaiqueV, decoupe }
decoupe = { gauche, haut, droite, bas, mode } (UiTextureAtlasElementSliceData :
les marges de la decoupe en neuf que le client moderne applique d'office a
l'element, reportees en proportion depuis sa variante simple, en unites ;
mode 0 = etire, 1 = mosaique), ou nil.
Un nom absent, ou une feuille que 3.3.5 n'affiche pas (plus de 1024 de
cote), arrete tout.
"""
import glob
import io
import os
import struct
import sys

from lupa import LuaRuntime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import db2  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(RACINE, "data", "addon", "ForeverUI")
ART = os.path.join(RACINE, "data", "art")
LISTE = os.path.join(RACINE, "tools", "atlas_accueil.txt")
MEMBRES = os.path.join(os.path.expanduser("~"), "wow.export", "dbfilesclient", "uitextureatlasmember.db2")
DECOUPES = os.path.join(os.path.expanduser("~"), "wow.export", "dbfilesclient", "uitextureatlaselementslicedata.db2")
SORTIE = os.path.join(RACINE, "data", "glue", "Interface", "GlueXML", "ForeverUIGlueAtlas.lua")
BS = chr(92)
VARIANTES = ("-c60-2x", "-c60", "-2x", "")
COTE_MIN = 8    # celui de tools/decouper_elements.py


def decoupes():
    """identifiant d'element -> (gauche, haut, droite, bas, mode) : les marges
    de la decoupe en neuf (UiTextureAtlasElementSliceData), en unites de
    l'element ; mode 0 = etire, 1 = mosaique."""
    res = {}
    for _, v in db2.lire(DECOUPES):
        res[v[1]] = (v[2], v[3], v[4], v[5], v[6])
    return res


def _reference(lignes):
    """Taille de reference de chaque element pour ses marges de decoupe : sa
    variante simple (sans suffixe), sinon -c60, sinon la premiere. Les marges
    sont partagees par toutes les variantes d'un element, qui n'ont pas la
    meme taille (tophud-selected-left : 181 de large, 120 en c60, marge de
    121) : elles se rapportent a la variante simple et se reportent en
    proportion sur les autres."""
    ref = {}
    rang = {}
    for _, v in lignes:
        nom = v[0].lower()
        r = 0 if not (nom.endswith("-c60") or nom.endswith("-2x")) else (1 if nom.endswith("-c60") else 2)
        if v[9] not in rang or r < rang[v[9]]:
            rang[v[9]] = r
            ref[v[9]] = (v[3], v[4])
    return ref


def membres():
    """nom en minuscules -> (largeur, hauteur, mosaiqueH, mosaiqueV, texels L,
    decoupe ou None)."""
    marges = decoupes()
    lignes = db2.lire(MEMBRES, (0,))
    reference = _reference(lignes)
    res = {}
    for _, v in lignes:
        nom = v[0].lower()
        largeur, hauteur = v[3], v[4]
        texels = v[6] - v[5]
        impose_l, impose_h, drapeaux = v[10], v[11], v[12]
        if impose_l or impose_h:
            largeur, hauteur = impose_l or largeur, impose_h or hauteur
        # une variante -2x compte en double densite, taille imposee comprise :
        # dans la table, la taille imposee d'une -2x est toujours le double de
        # celle de sa variante simple (anneau de portrait 20 / 40, griffon
        # 100 x 94 / 200 x 188) et les deux s'affichent pareil
        if nom.endswith("-2x"):
            largeur, hauteur = largeur / 2.0, hauteur / 2.0
        decoupe = marges.get(v[9])
        if decoupe:
            rl, rh = reference[v[9]]
            g, h, d, b, mode = decoupe
            decoupe = (round(g * largeur / rl, 2), round(h * hauteur / rh, 2),
                       round(d * largeur / rl, 2), round(b * hauteur / rh, 2), mode)
        res[nom] = (largeur, hauteur, bool(drapeaux & 4), bool(drapeaux & 2), texels, decoupe)
    return res


def dimensions_blp(chemin_interne):
    """Largeur et hauteur de la feuille dans l'atelier (entete BLP2)."""
    rel = chemin_interne.split(BS)
    fichier = os.path.join(ART, *rel) + ".blp"
    if not os.path.exists(fichier):
        raise SystemExit("feuille absente de l'atelier : %s" % fichier)
    d = io.open(fichier, "rb").read(20)
    return struct.unpack_from("<II", d, 12)


def main():
    lua = LuaRuntime()
    for chemin in sorted(glob.glob(os.path.join(ADDON, "UIAtlas_*.lua"))):
        lua.execute(io.open(chemin, encoding="utf-8").read())
    donnees = lua.globals().UIAtlas.data
    tailles = membres()

    noms = []
    for ligne in io.open(LISTE, encoding="utf-8"):
        ligne = ligne.split("#")[0].strip().lower()
        if ligne:
            noms.append(ligne)

    lignes = [
        "-- les elements d'atlas des ecrans d'accueil",
        "-- genere par tools/atlas_accueil.py (coordonnees : tables de l'addon ;",
        "-- tailles et mosaique : UiTextureAtlasMember du client moderne)",
        "",
        "ForeverUIGlue = ForeverUIGlue or {}",
        "ForeverUIGlue.atlas = {",
    ]
    erreurs = []
    for n in noms:
        # la variante : la premiere que le client moderne connait et dont
        # l'atelier a les coordonnees -- sous son nom brut, ou sous le nom
        # logique si celui-ci pointe bien la meme region (meme largeur en
        # texels)
        choisi = e = None
        for suffixe in VARIANTES:
            v = n + suffixe
            if v not in tailles:
                continue
            for cle in (v, n):
                cand = donnees[cle]
                if cand is None:
                    continue
                lw, lh = dimensions_blp(cand[1])
                # une bande de moins de COTE_MIN texels a ete recopiee sur
                # COTE_MIN par tools/decouper_elements.py (sinon verte)
                lue, texels = (cand[3] - cand[2]) * lw, tailles[v][4]
                if abs(lue - texels) <= 1 or (texels < COTE_MIN and abs(lue - COTE_MIN) <= 1):
                    choisi, e = v, cand
                    break
            if choisi:
                break
        if not choisi:
            erreurs.append("absent : %s" % n)
            continue
        largeur, hauteur, mh, mv, _, marges = tailles[choisi]
        lw, lh = dimensions_blp(e[1])
        if lw > 1024 or lh > 1024:
            erreurs.append("feuille de %dx%d, illisible en 3.3.5 : %s (%s) -> tools/decouper_elements.py" % (lw, lh, choisi, e[1]))
            continue
        decoupe = "nil"
        if marges:
            decoupe = "{ %g, %g, %g, %g, %d }" % marges
        lignes.append('\t["%s"] = { "%s", %.6f, %.6f, %.6f, %.6f, %g, %g, %s, %s, %s }, -- %s' % (
            n, e[1].replace(BS, BS + BS), e[2], e[3], e[4], e[5], largeur, hauteur,
            "true" if mh else "false", "true" if mv else "false", decoupe, choisi))
    if erreurs:
        raise SystemExit("\n".join(erreurs))
    lignes += ["}", ""]

    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    io.open(SORTIE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print("table des ecrans d'accueil : %d elements -> %s" % (len(noms), os.path.relpath(SORTIE, RACINE)))


if __name__ == "__main__":
    main()
