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

"""Des elements d'atlas decoupes a part, a leur resolution d'origine.

POURQUOI. Le client 3.3.5 n'affiche pas une feuille de plus de 1024 de large
(voir foreverui/blp.py), et exige des cotes en puissances de deux. Plusieurs
feuilles de camelot font 2048 (interface/lfgframe/groupfinder.blp...).
decouper_marques.py reduit ses marques a un carre ; ici l'element garde SA
taille : il est pose en haut a gauche d'une image aux cotes en puissances de
deux, le reste transparent, et la table d'atlas porte les coordonnees de la
partie utile.

CE QU'IL FAIT. Pour chaque feuille de ELEMENTS : l'exporte par le pont de
wow.export, lit la region de chaque element dans tools/atlas_dump.json
(jamais de memoire), l'ecrit NON COMPRESSEE avec ses mipmaps dans
data/art/interface/ForeverUI/<dossier de la feuille>/<element>.blp (+ .png),
puis regenere data/addon/ForeverUI/UIAtlas_07_decoupes.lua : ForeverUI.SetAtlas
trouve ces elements sous leur nom de camelot.

wow.export doit tourner avec sa source chargee (pont sur le port 9455).
"""
import io
import json
import os
import re
import sys
import urllib.parse
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

PONT = "http://127.0.0.1:9455"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(RACINE, "tools", "atlas_dump.json")
ART = os.path.join(RACINE, "data", "art", "interface", "ForeverUI")
TABLE = os.path.join(RACINE, "data", "addon", "ForeverUI", "UIAtlas_07_decoupes.lua")
STAGING = os.path.join(os.environ.get("TEMP", "."), "foreverui_export")
BS = "\\"

# feuille -> les elements a en tirer
ELEMENTS = {
    # le chercheur de groupe (blizzard_groupfinder_vanillastyle, 2026-09-26)
    "interface/lfgframe/groupfinder.blp": [
        "groupfinder-background", "groupfinder-button-cover",
        "groupfinder-button-dungeons", "groupfinder-button-custom-pve",
        "groupfinder-button-questing", "groupfinder-button-raids-warlords",
        # le navigateur de raid (etape 2) : selection et survol des lignes,
        # roles, attente, classes de WotLK
        "groupfinder-highlightbar-blue", "groupfinder-highlightbar-yellow",
        "groupfinder-icon-role-micro-tank", "groupfinder-icon-role-micro-heal",
        "groupfinder-icon-role-micro-dps", "groupfinder-waitdot",
    ] + ["groupfinder-icon-class-" + c for c in (
        "deathknight", "druid", "hunter", "mage", "paladin",
        "priest", "rogue", "shaman", "warlock", "warrior")],
    "interface/hud/uigroupfinderflipbook.blp": ["groupfinder-eye-frame"],
    "interface/shop/catalogshop.blp": ["shop-list-rule"],
    # le bouton rouge des ecrans d'accueil (ThreeSliceButtonTemplate,
    # 128-RedButton) : trois tranches par etat ; la lueur n'existe que dans
    # la feuille sans c60
    "interface/buttons/128redbuttonc60.blp": [
        "128-redbutton-left-c60", "128-redbutton-left-pressed-c60", "128-redbutton-left-disabled-c60",
        "_128-redbutton-center-c60", "_128-redbutton-center-pressed-c60", "_128-redbutton-center-disabled-c60",
        "128-redbutton-right-c60", "128-redbutton-right-pressed-c60", "128-redbutton-right-disabled-c60",
        # la fleche de repli de la liste des personnages (ListToggle)
        "128-redbutton-arrowdown-c60", "128-redbutton-arrowdown-pressed-c60", "128-redbutton-arrowdown-disabled-c60",
        "128-redbutton-arrowupglow-c60", "128-redbutton-arrowupglow-pressed-c60", "128-redbutton-arrowupglow-disabled-c60",
        # la croix de la liste des royaumes (BigRedExitButtonTemplate)
        "128-redbutton-exit-c60", "128-redbutton-exit-pressed-c60", "128-redbutton-exit-disabled-c60",
    ],
    "interface/buttons/128redbutton.blp": [
        "128-redbutton-highlight",
        "128-redbutton-arrowdown-highlight", "128-redbutton-arrowupglow-highlight",
        "128-redbutton-exit-highlight",
    ],
    # les credits des ecrans d'accueil (blizzard_gluexml/mainline/
    # creditsframe.xml) : degrade du haut et du bas, icones de vitesse
    # (feuille de 2048 de haut), et le bouton carre gris qui les porte
    "interface/credits/creditsscreenassets.blp": [
        "_creditsscreen-gradient-tile",
        "creditsscreen-assets-buttons-rewind", "creditsscreen-assets-buttons-pause",
        "creditsscreen-assets-buttons-play", "creditsscreen-assets-buttons-fastforward",
        # la liste des extensions (CreditsFrameExpansionsButtonTemplate)
        "creditsscreen-selected", "creditsscreen-highlight",
    ],
    "interface/common/commonbuttonsc60.blp": [
        "common-button-square-gray-up-c60", "common-button-square-gray-down-c60",
    ],
    # la liste des personnages : le bouton de suppression (UIButtonTemplate,
    # 128-RedButton-Delete) ; sa lueur n'existe que dans la feuille sans c60
    "interface/buttons/128redbuttonpart2c60.blp": [
        "128-redbutton-delete-c60", "128-redbutton-delete-pressed-c60", "128-redbutton-delete-disabled-c60",
    ],
    "interface/buttons/128redbuttonpart2.blp": ["128-redbutton-delete-highlight"],
    # la selection des personnages : fleche du bouton Back et icones de
    # rotation du modele (feuille de 2048 de large)
    "interface/common/commonicons.blp": [
        "common-icon-backarrow", "common-icon-rotateleft", "common-icon-rotateright",
        "common-icon-backarrow-disable", "common-icon-forwardarrow", "common-icon-forwardarrow-disable",
        # la personnalisation : reinitialiser la camera (CustomizationResetCameraButton)
        "common-icon-undo",
    ],
    # la creation de personnage (blizzard_charactercreate/camelot) : les
    # emblemes et les vignettes ; les icones de race et de classe, que
    # tools/cuire_creation.py decoupe ensuite par le masque de camelot
    "interface/glues/charactercreate/charactercreate.blp": [
        "charactercreate-icon-alliance", "charactercreate-icon-horde",
        "charactercreate-vignette-top", "charactercreate-vignette-sides",
        "charactercreate-vignette-bottom", "charactercreate-vignette-sides-widescreen",
        # le de de la personnalisation (CustomizationRandomizeAppearanceButton)
        "charactercreate-icon-dice",
        # les echantillons de couleur des choix (CustomizationElementDetailsTemplate)
        "charactercreate-customize-palette", "charactercreate-customize-palette-glow",
        "charactercreate-customize-palette-selected",
    ],
    "interface/glues/charactercreate/charactercreateicons.blp": [
        "raceicon128-%s-%s" % (r, s)
        for r in ("human", "dwarf", "nightelf", "gnome", "draenei",
                  "orc", "undead", "tauren", "troll", "bloodelf")
        for s in ("male", "female")
    ] + ["classicon-" + c for c in (
        "warrior", "paladin", "hunter", "rogue", "priest",
        "deathknight", "shaman", "mage", "warlock", "druid")],
    # les boutons de service payant des cartes : la version double densite
    # (116 x 116), la simple etant pixelisee a l'ecran (2026-09-27)
    "interface/glues/characterselect/uicharacterselectglues2x.blp": [
        "glues-characterselect-icon-factionchange-2x", "glues-characterselect-icon-factionchange-hover-2x",
        "glues-characterselect-icon-racechange-2x", "glues-characterselect-icon-racechange-hover-2x",
        "glues-characterselect-icon-appearancechange-2x", "glues-characterselect-icon-appearancechange-hover-2x",
    ],
    # l'hotel des ventes : les fonds des encadres (feuille de 2048 de large) --
    # categories, resultats et listes, panneau de mise en vente
    "interface/auctionframe/auctionhousebackgrounds.blp": [
        "auctionhouse-background-categories", "auctionhouse-background-index",
        "auctionhouse-background-sell-left",
    ],
    # les PNJ, etape 3 : l'en-tete de categorie du maitre (TrainerUICategory-
    # Template), feuille de 2048
    "interface/professions/professions.blp": [
        "professions-recipe-header-left", "professions-recipe-header-middle",
        "professions-recipe-header-right", "professions-recipe-header-expand",
        "professions-recipe-header-collapse",
        # les metiers (etape 4) : barre de rang, icones de progression, lignes
        # de la liste, fond de la liste, emplacements des reactifs
        "professions-skillbar-bg", "professions-skillbar-frame",
        "skillbar_fill_flipbook_defaultblue",
        "professions-icon-skill-high", "professions-icon-skill-medium", "professions-icon-skill-low",
        "professions_recipe_active", "professions_recipe_hover",
        "professions-background-summarylist",
        "professions-slot-bg", "professions-slot-frame", "professions-slot-frame-green",
        "professions-slot-frame-blue", "professions-slot-frame-epic", "professions-slot-frame-legendary",
    ],
    # la barre de rang de chaque metier : sa bande animee (Skillbar_Fill_
    # Flipbook_<metier>, 2 colonnes d'images de 34) n'entre pas dans 3.3.5 --
    # seule sa PREMIERE image est gardee (PREMIERE_IMAGE) ; et son eclat
    "interface/professions/professionsfxalchemyc60.blp": ["skillbar_fill_flipbook_alchemy_c60", "skillbar_flare_alchemy_c60"],
    "interface/professions/professionsfxblacksmithing.blp": ["skillbar_fill_flipbook_blacksmithing", "skillbar_flare_blacksmithing"],
    "interface/professions/professionsfxcooking.blp": ["skillbar_fill_flipbook_cooking", "skillbar_flare_cooking"],
    "interface/professions/professionsfxenchantingc60.blp": ["skillbar_fill_flipbook_enchanting_c60", "skillbar_flare_enchanting_c60"],
    "interface/professions/professionsfxengineering.blp": ["skillbar_fill_flipbook_engineering", "skillbar_flare_engineering"],
    "interface/professions/professionsfxfirstaidc60.blp": ["skillbar_fill_flipbook_firstaid_c60", "skillbar_flare_firstaid_c60"],
    "interface/professions/professionsfxinscription.blp": ["skillbar_fill_flipbook_inscription", "skillbar_flare_inscription"],
    "interface/professions/professionsfxjewelcrafting.blp": ["skillbar_fill_flipbook_jewelcrafting", "skillbar_flare_jewelcrafting"],
    "interface/professions/professionsfxleatherworking.blp": ["skillbar_fill_flipbook_leatherworking", "skillbar_flare_leatherworking"],
    "interface/professions/professionsfxmining.blp": ["skillbar_fill_flipbook_mining", "skillbar_flare_mining"],
    "interface/professions/professionsfxtailoring.blp": ["skillbar_fill_flipbook_tailoring", "skillbar_flare_tailoring"],
    # le livre des metiers : les metiers qui n'ont pas de page de fabrication
    "interface/professions/professionsfxherbalism.blp": ["skillbar_fill_flipbook_herbalism", "skillbar_flare_herbalism"],
    "interface/professions/professionsfxskinningc60.blp": ["skillbar_fill_flipbook_skinning_c60", "skillbar_flare_skinning_c60"],
    "interface/professions/professionsfxfishing.blp": ["skillbar_fill_flipbook_fishing", "skillbar_flare_fishing"],
    # l'etable : le fond de la scene selon la specialisation du familier, et
    # l'ombre sous le familier (feuilles de 2048)
    "interface/petstableframe/hunterpetstable.blp": [
        "hunter-stable-bg-art_cunning", "hunter-stable-bg-art_ferocity",
        "hunter-stable-bg-art_tenacity",
    ],
    "interface/store/perks.blp": ["perks-char-shadow"],
    # les metiers : l'ombre du nombre fabrique sur l'icone du resultat
    # (ProfessionsOutputButtonTemplate, CountShadow)
    "interface/petbattles/petbattlehudatlas.blp": ["battlebar-swappetshadow"],
    # le portrait de LegacySystemFrame (Legacy-up-c60, 198 x 273, feuille de
    # 2048)
    "interface/hud/uiradialmenuc60.blp": ["legacy-up-c60"],
}


_VARIANTE = re.compile("^(2x|4x|c[0-9]+)$")


def _logique(nom):
    """Le nom sans ses suffixes de variante, tel que le code de camelot l'ecrit."""
    parts = nom.lower().split("-")
    while len(parts) > 1 and _VARIANTE.match(parts[-1]):
        parts.pop()
    return "-".join(parts)


# LES TRANCHES QUI SE JOIGNENT. Le client lit une image agrandie en melangeant
# chaque pixel avec son voisin : au bout d'un element pose seul dans une image
# plus large, ce voisin est le vide, et le bout s'estompe. Pour les trois
# tranches du bouton rouge, qui se touchent bout a bout, cela faisait un
# decalage d'un pixel entre la tranche gauche et le centre (constate en jeu le
# 2026-09-27). Ces elements-la sont donc poses a MARGE du bord gauche, et
# leurs colonnes extremes recopiees de chaque cote.
# Feuilles que wow.export n'exporte plus en .blp ("[BLTE] Invalid MD5 hash",
# constate le 2026-09-27 sur charactercreateicons.blp) : on lit l'export PNG
# RGBA de l'inventaire du 2026-09-21, fait sur le meme client.
APERCUS = {
    "interface/glues/charactercreate/charactercreateicons.blp": os.path.join(
        os.path.expanduser("~"), "wow.export", "interface", "glues", "charactercreate", "charactercreateicons.png"),
}

COTE_MIN = 8

# les bandes animees (FlipBook) dont on ne garde que la premiere image : 2
# colonnes d'images de 34 de haut (ProfessionsRankBarMixin:Update)
PREMIERE_IMAGE = ("skillbar_fill_flipbook_",)

DEBORDER = {"interface/buttons/128redbuttonc60.blp", "interface/buttons/128redbutton.blp"}
MARGE = 2


def _demander(chemin, params):
    url = PONT + chemin + "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=900) as r:
        return json.loads(r.read().decode("utf-8"))


def _puissance(n):
    p = 1
    while p < n:
        p *= 2
    return p


def regions():
    donnees = json.load(io.open(INDEX, encoding="utf-8"))
    trouve = {}
    for r in donnees["results"]:
        feuille = (r.get("file") or "").lower()
        if feuille in ELEMENTS and r["atlas"].lower() in [e.lower() for e in ELEMENTS[feuille]]:
            trouve[(feuille, r["atlas"].lower())] = r["region"]
    manquants = [(f, e) for f, l in ELEMENTS.items() for e in l if (f, e.lower()) not in trouve]
    if manquants:
        raise SystemExit("absents de l'index : %s" % manquants)
    return trouve


def main():
    if not _demander("/status", {})["ready"]:
        _demander("/load-source", {})
        raise SystemExit("la source de wow.export se charge, relancer dans une minute")
    os.makedirs(STAGING, exist_ok=True)
    trouve = regions()
    entrees = []
    for feuille in sorted(ELEMENTS):
        if feuille in APERCUS:
            image = Image.open(APERCUS[feuille]).convert("RGBA")
        else:
            res = _demander("/export", [("dest", STAGING), ("file", feuille)])
            if res["failed"]:
                raise SystemExit("export en echec : %s" % res)
            with io.open(os.path.join(STAGING, feuille.replace("/", os.sep)), "rb") as f:
                largeur, hauteur, rgba, _ = blp.decoder(f.read())
            image = Image.frombytes("RGBA", (largeur, hauteur), bytes(rgba))
        dossier = feuille.split("/")[1]
        os.makedirs(os.path.join(ART, dossier), exist_ok=True)
        for nom in ELEMENTS[feuille]:
            r = trouve[(feuille, nom.lower())]
            if nom.lower().startswith(PREMIERE_IMAGE) and nom.lower() != "skillbar_fill_flipbook_defaultblue":
                r = dict(r, width=r["width"] // 2, height=34)
            w, h = r["width"], r["height"]
            morceau = image.crop((r["left"], r["top"], r["left"] + w, r["top"] + h))
            # une bande d'un texel (les vignettes de la creation, 1 x 451 ou
            # 703 x 1) : 3.3.5 ne l'affiche pas, il peint un rectangle vert a
            # sa place (constate le 2026-09-27). Elle est recopiee sur
            # COTE_MIN texels identiques ; etiree, elle rend la meme chose.
            wi, hi = max(w, COTE_MIN), max(h, COTE_MIN)
            if (wi, hi) != (w, h):
                morceau = morceau.resize((wi, hi), Image.NEAREST)
            m = MARGE if feuille in DEBORDER else 0
            W, H = _puissance(wi + 2 * m), _puissance(hi)
            toile = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            toile.paste(morceau, (m, 0))
            for i in range(m):
                toile.paste(morceau.crop((0, 0, 1, hi)), (i, 0))
                toile.paste(morceau.crop((wi - 1, 0, wi, hi)), (m + wi + i, 0))
            # les mipmaps en alpha premultiplie : pas de franges sombres
            plein = toile.convert("RGBa")
            mips = []
            mw, mh = W, H
            while mw > 1 or mh > 1:
                mw, mh = max(1, mw // 2), max(1, mh // 2)
                mips.append((mw, mh, plein.resize((mw, mh), Image.LANCZOS).convert("RGBA").tobytes()))
            base = os.path.join(ART, dossier, nom.lower())
            with io.open(base + ".blp", "wb") as f:
                f.write(blp.encoder(W, H, toile.tobytes(), mips))
            toile.save(base + ".png")
            chemin = BS.join(["interface", "ForeverUI", dossier, nom.lower()])
            entrees.append((nom.lower(), chemin, m / float(W), (m + wi) / float(W), hi / float(H), w, h))
            print("   %-36s %d x %d dans %d x %d" % (nom, w, h, W, H))

    lignes = [
        "-- elements decoupes a part, a leur resolution d'origine (feuilles trop",
        "-- larges pour le client 3.3.5).",
        "-- genere par tools/decouper_elements.py depuis tools/atlas_dump.json",
        "",
        "UIAtlas = UIAtlas or { sheets = {}, data = {} }",
        "",
    ]
    deja = set()
    for nom, chemin, u1, u2, v2, w, h in entrees:
        # le nom brut, et le nom logique que le code de camelot emploie
        for cle in (nom, _logique(nom)):
            if cle in deja:
                continue
            deja.add(cle)
            lignes.append('UIAtlas.data["%s"] = { "%s", %s, %.6f, 0, %.6f, %d, %d }' % (
                cle, chemin.replace(BS, BS + BS), "%.6f" % u1 if u1 else "0", u2, v2, w, h))
    lignes.append("")
    io.open(TABLE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print("table : %d elements -> %s" % (len(entrees), os.path.relpath(TABLE, RACINE)))


if __name__ == "__main__":
    main()
