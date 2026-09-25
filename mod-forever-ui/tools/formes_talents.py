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

"""La forme de chaque talent de WotLK, pour l'ecran de camelot.

CAMELOT dessine un noeud CARRE pour un talent qui donne un sort actif
(SpendSquare) et ROND pour un passif (SpendCircle). 3.3.5 ne le dit pas a
l'interface : GetTalentInfo rend nom, icone, palier, colonne, rangs -- pas le
sort. La reponse est dans les DBC du serveur :

  TalentTab.dbc  l'onglet et son fond (BackgroundFile : "MageArcane"...), le
                 meme nom que le 4e retour de GetTalentTabInfo
  Talent.dbc     onglet, palier et colonne (a partir de 0), le sort du rang 1
  Spell.dbc      Attributes (champ 4) : SPELL_ATTR0_PASSIVE = 0x40 ; un
                 passif qui apprend un sort (effet 36, LEARN_SPELL) donne un
                 sort actif -- il est carre aussi

SORTIE : data/addon/ForeverUI/TalentsData.lua, la liste des talents CARRES,
par fond d'onglet puis "palier:colonne" (a partir de 1, comme GetTalentInfo).
Tout le reste est rond.

LES SORTS (demande du 2026-09-25 : glisser un talent actif appris vers une
barre). Pour chaque talent carre, les sorts qu'il met dans le grimoire : ceux
de ses rangs (Talent.dbc, champs 4 a 12), et, pour un talent qui APPREND un
sort, les sorts appris (EffectTriggerSpell, champs 116 a 118, la ou l'effet
vaut 36) -- Mangle apprend Mangle (Bear) et Mangle (Cat). L'interface les
retrouve dans le grimoire par GetSpellLink.
"""
import os
import struct
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(RACINE, "data", "addon", "ForeverUI", "TalentsData.lua")
DBC = sys.argv[1] if len(sys.argv) > 1 else r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc"

PASSIF = 0x40
APPRENDRE = 36          # SPELL_EFFECT_LEARN_SPELL
DECLENCHE = 116         # Spell.dbc : EffectTriggerSpell[3], 116 a 118


def lire(nom):
    d = open(os.path.join(DBC, nom), "rb").read()
    assert d[:4] == b"WDBC", nom
    n, champs, taille, _ = struct.unpack_from("<IIII", d, 4)
    debut_chaines = 20 + n * taille

    def chaine(o):
        fin = d.index(b"\0", debut_chaines + o)
        return d[debut_chaines + o:fin].decode("utf-8")

    lignes = [struct.unpack_from("<%dI" % champs, d, 20 + i * taille) for i in range(n)]
    return lignes, chaine


def main():
    onglets, chaine_onglet = lire("TalentTab.dbc")
    fonds = {o[0]: chaine_onglet(o[23]) for o in onglets}

    sorts, _ = lire("Spell.dbc")
    par_id = {s[0]: s for s in sorts}

    talents, _ = lire("Talent.dbc")
    carres = {}
    sorts_talent = {}
    for t in talents:
        onglet, palier, colonne, rang1 = t[1], t[2], t[3], t[4]
        fond = fonds.get(onglet)
        sort = par_id.get(rang1)
        if not fond or not sort:
            continue
        actif = not (sort[4] & PASSIF) or APPRENDRE in sort[71:74]
        if actif:
            cle = "%d:%d" % (palier + 1, colonne + 1)
            carres.setdefault(fond, set()).add(cle)
            ids = []
            for rang in t[4:13]:
                s = par_id.get(rang)
                if not s:
                    continue
                if APPRENDRE in s[71:74]:
                    for e in range(3):
                        if s[71 + e] == APPRENDRE and s[DECLENCHE + e]:
                            ids.append(s[DECLENCHE + e])
                else:
                    ids.append(rang)
            if ids:
                sorts_talent.setdefault(fond, {}).setdefault(cle, [])
                for i in ids:
                    if i not in sorts_talent[fond][cle]:
                        sorts_talent[fond][cle].append(i)

    lignes = [
        "-- ForeverUI : la forme des noeuds de talents (ecran de camelot).",
        "-- GENERE par tools/formes_talents.py depuis les DBC du serveur -- ne pas",
        "-- modifier a la main. Les talents CARRES (un sort actif), par fond",
        "-- d'onglet (GetTalentTabInfo, 4e retour) puis \"palier:colonne\" ; les",
        "-- autres sont RONDS (passifs).",
        "",
        "ForeverUI = ForeverUI or {}",
        "ForeverUI.TalentsCarres = {",
    ]
    for fond in sorted(carres):
        # une place peut porter plusieurs entrees (les arbres du familier) : une
        # seule cle
        cles = ", ".join('["%s"] = true' % c for c in sorted(carres[fond]))
        lignes.append('\t["%s"] = { %s },' % (fond, cles))
    lignes.append("}")
    lignes += [
        "",
        "-- les sorts que chaque talent carre met dans le grimoire (rangs, ou sorts",
        "-- appris), par fond d'onglet puis \"palier:colonne\"",
        "ForeverUI.TalentsSorts = {",
    ]
    for fond in sorted(sorts_talent):
        cles = ", ".join('["%s"] = { %s }' % (c, ", ".join(str(i) for i in sorts_talent[fond][c]))
                         for c in sorted(sorts_talent[fond]))
        lignes.append('	["%s"] = { %s },' % (fond, cles))
    lignes.append("}")
    open(SORTIE, "w", encoding="utf-8", newline="\n").write("\n".join(lignes) + "\n")
    total = sum(len(v) for v in carres.values())
    print("%d talents carres sur %d, dans %d onglets -> %s" % (total, len(talents), len(carres),
                                                               os.path.relpath(SORTIE, RACINE)))


if __name__ == "__main__":
    main()
