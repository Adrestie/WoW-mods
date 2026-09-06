# -*- coding: utf-8 -*-
r"""Vérifie que chaque crochet de script correspond bien à l'effet du DBC.

Une liaison fausse ne se voit PAS à la compilation. Le cœur la refuse au
démarrage, écrit une ligne dans le journal, et le crochet ne s'exécute jamais —
le sort part, ne fait rien de ce qu'on attendait, et rien ne le dit en jeu :

    Spell 8600031 Effect Index: EFFECT_0 AuraName: 3 of script
    spell_papota_fleau_des_rois did not match dbc effect data

C'est le genre de faute qu'on ne trouve qu'en lisant le journal ligne à ligne.
On la cherche donc ici, en confrontant ce que le C++ déclare écouter à ce que la
table des sorts déclare poser.

    python verifie_sorts.py
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sorts_classes as SC

sys.stdout.reconfigure(encoding="utf-8")

SOURCE = (r"D:\Serveur WoW\azerothcore-wotlk\modules\mod-papota-spherier"
          r"\src\SpherierSorts.cpp")

INDEX = {"EFFECT_0": 0, "EFFECT_1": 1, "EFFECT_2": 2}
NOM_EFFET = {
    SC.E_DEGATS: "SPELL_EFFECT_SCHOOL_DAMAGE", SC.E_SOIN: "SPELL_EFFECT_HEAL",
    SC.E_AURA: "SPELL_EFFECT_APPLY_AURA", SC.E_SAUT: "SPELL_EFFECT_JUMP_DEST",
    SC.E_DUMMY: "SPELL_EFFECT_DUMMY", SC.E_ENERGIE: "SPELL_EFFECT_ENERGIZE",
    SC.E_ZONE: "SPELL_EFFECT_PERSISTENT_AREA_AURA", SC.E_SUMMON: "SPELL_EFFECT_SUMMON",
}
NOM_AURA = {
    SC.A_PERIODIQUE: "SPELL_AURA_PERIODIC_DAMAGE",
    SC.A_SOIN_PERIODIQUE: "SPELL_AURA_PERIODIC_HEAL",
    SC.A_DECLENCHEUR: "SPELL_AURA_PERIODIC_TRIGGER_SPELL",
    SC.A_ABSORPTION: "SPELL_AURA_SCHOOL_ABSORB",
    SC.A_VITESSE: "SPELL_AURA_MOD_INCREASE_SPEED",
    SC.A_DEGATS_PCT: "SPELL_AURA_MOD_DAMAGE_PERCENT_DONE",
    SC.A_DEGATS_SUBIS: "SPELL_AURA_MOD_DAMAGE_PERCENT_TAKEN",
    SC.A_DRAIN: "SPELL_AURA_PERIODIC_LEECH",
    SC.A_RESISTANCE_PCT: "SPELL_AURA_MOD_RESISTANCE_PCT",
    SC.A_ETOURDI: "SPELL_AURA_MOD_STUN", SC.A_DUMMY: "SPELL_AURA_DUMMY",
    SC.A_PERIODIQUE_FACTICE: "SPELL_AURA_PERIODIC_DUMMY",
    SC.A_PROC_DECLENCHE: "SPELL_AURA_PROC_TRIGGER_SPELL",
}


SQL_MODULE = (r"D:\Serveur WoW\azerothcore-wotlk\modules\mod-papota-spherier"
              r"\data\sql\world")


def accroches_sql():
    """Les scripts que le SQL du module accroche à des sorts NATIFS (hors de
    nos plages), comme spell_papota_forme_selenien sur la Forme de sélénien
    24858 : le générateur ne les nomme pas, ce sont pourtant des accroches
    vivantes (2026-09-06)."""
    import glob
    import os
    trouves = {}
    for chemin in glob.glob(os.path.join(SQL_MODULE, "*.sql")):
        texte = io.open(chemin, encoding="utf-8", errors="replace").read()
        if "spell_script_names" not in texte:
            continue
        for m in re.finditer(r"\(\s*(\d+)\s*,\s*'(spell_papota_[a-z0-9_]+)'\s*\)", texte):
            ident = int(m.group(1))
            if ident < 8500000:
                trouves.setdefault(m.group(2), set()).add(ident)
    return trouves


def liaisons_du_code():
    """Ce que chaque classe de script déclare écouter."""
    cpp = io.open(SOURCE, encoding="utf-8").read()
    # [a-z0-9_] : les noms peuvent porter des chiffres (spell_papota_
    # meteore_28884 — invisible avec [a-z_] seul, corrigé le 2026-08-31).
    blocs = re.split(r"class (spell_papota_[a-z0-9_]+) : public (SpellScript|AuraScript)", cpp)
    out = []
    for i in range(1, len(blocs) - 2, 3):
        nom, genre, corps = blocs[i], blocs[i + 1], blocs[i + 2]
        for m in re.finditer(r"\w+Fn\([^,]+,\s*(EFFECT_\d)\s*,\s*(\w+)\)", corps):
            out.append((nom, genre, INDEX[m.group(1)], m.group(2)))
    # Deux macros d'enregistrement : le sort seul, et la PAIRE
    # SpellScript + AuraScript (RegisterSpellAndAuraScriptPair), où le nom
    # inscrit en base est celui du PREMIER argument. Ne connaitre que la
    # premiere faisait déclarer absent un script bel et bien présent.
    noms = set(re.findall(r"RegisterSpellScript\((spell_papota_[a-z0-9_]+)\)", cpp))
    noms |= set(re.findall(r"RegisterSpellAndAuraScriptPair\(\s*(spell_papota_[a-z0-9_]+)", cpp))
    return out, noms


def main():
    liaisons, enregistres = liaisons_du_code()
    par_script = {}
    for s in SC.SORTS:
        if s["script"]:
            par_script.setdefault(s["script"], []).append(s)

    defauts = []
    for nom, genre, idx, attendu in liaisons:
        for sp in par_script.get(nom, []):
            effets = sp["effets"]
            if idx >= len(effets):
                reel = "aucun effet à cet index"
            else:
                e = effets[idx]
                # Un AuraScript se lie à l'AURA de l'effet, un SpellScript à
                # l'effet lui-même : ce n'est pas la même colonne du DBC.
                reel = (NOM_AURA.get(e["aura"], "aura %d" % e["aura"])
                        if genre == "AuraScript" and e["aura"]
                        else NOM_EFFET.get(e["effet"], "effet %d" % e["effet"]))
            # SPELL_EFFECT_ANY couvre TOUT effet non nul : un même script
            # servant deux sorts dont l'effet diffère s'y accroche ainsi.
            if attendu == "SPELL_EFFECT_ANY":
                continue
            if reel != attendu:
                defauts.append((nom, idx, attendu, reel, sp["fr"], sp["id"]))

    # Un script accroché en base mais absent du code, ou l'inverse. Les
    # accroches posées par SQL sur des sorts natifs comptent comme voulues.
    natifs = accroches_sql()
    voulus = set(par_script) | set(natifs)
    orphelins = sorted(voulus - enregistres)
    inutiles = sorted(enregistres - voulus)
    for nom, ids in sorted(natifs.items()):
        print("  accroche SQL sur sort natif : %s -> %s" % (nom, ", ".join(str(i) for i in sorted(ids))))

    print("%d liaison(s) d'effet vérifiée(s)" % len(liaisons))
    for nom, idx, attendu, reel, fr, ident in defauts:
        print("  DÉFAUT  %s  EFFECT_%d attend %s, le DBC pose %s  (%s, %d)"
              % (nom, idx, attendu, reel, fr, ident))
    if orphelins:
        print("  Scripts demandés par la table mais absents du C++ : %s" % ", ".join(orphelins))
    if inutiles:
        print("  Scripts enregistrés en C++ mais que rien n'accroche : %s" % ", ".join(inutiles))
    if not defauts and not orphelins and not inutiles:
        print("Tout concorde.")
    return 1 if (defauts or orphelins or inutiles) else 0


if __name__ == "__main__":
    sys.exit(main())
