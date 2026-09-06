# -*- coding: utf-8 -*-
r"""Ratios de puissance des sorts du sphèrier, déduits des kits Blizzard.

PRINCIPE. Chaque sort custom doit monter avec le personnage comme montent les
sorts de sa spécialisation. On ne l'invente pas : on mesure le kit d'origine.

QUATRE PRÉCAUTIONS, prises le 2026-09-04 après une première version qui ne
reposait que sur `spell_bonus_data` :

1. **On calcule le coefficient par défaut** au lieu de sauter les sorts qui
   n'ont pas de ligne. `spell_bonus_data` n'est pas la table des coefficients,
   c'est la table des EXCEPTIONS : le cœur ne la lit que si une ligne existe,
   sinon il applique `Unit::CalculateDefaultCoefficient` (temps d'incantation
   / 3500, moitié pour les zones, ×1,88 pour les soins). Ne mesurer que les
   lignes, c'est faire la moyenne de ce qui sort de l'ordinaire — et sur un
   sort de la spécialisation sur cinq.

2. **Le pourcentage d'arme devient un équivalent de puissance d'attaque.** En
   3.3.5 les compétences physiques ne montent presque jamais par un
   coefficient de PA : elles montent par un pourcentage de dégâts d'arme, et
   la PA y entre par `PA / 14 × vitesse normalisée`. Une compétence à 110 %
   d'arme vaut donc 0,236 de PA sur une arme à deux mains. C'est ce qui
   débloque Fureur, Maîtrise des bêtes et Finesse, vides autrement.

3. **Les sorts de TALENT comptent.** `SkillLineAbility` ne les porte pas :
   Frappe mortelle, Sanguinaire, Mutilation, Mangle en sont absents, c'est-à-
   dire les sorts qui FONT la spécialisation. `Talent.dbc` + `TalentTab.dbc`
   les rattachent à la bonne spé (appariement par le nom de l'onglet).

4. **Médiane, et appariement par nature.** La moyenne se fait tirer par les
   valeurs isolées (le prêtre Sacré a un 1,61 contre des soins à 0,3) ; la
   médiane ne bouge pas d'un sort. Et un effet de ZONE reçoit la moitié du
   coefficient par construction : on tient deux jeux séparés, mono-cible et
   zone, pour comparer un sort custom à ceux de sa nature.

RANG MAXIMUM SEULEMENT, et nos propres rangs de runes écartés : elles ont
allongé les chaînes Blizzard (Tir des arcanes monte au rang 14) et
deviendraient les sommets.

    python gen_ratios_classes.py            (tableau à l'écran)
    python gen_ratios_classes.py --csv      (+ ratios_classes.csv)
    python gen_ratios_classes.py --detail   (+ les appuis, sort par sort)
"""
import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import MYSQL_HOTE, MYSQL_PORT, MYSQL_UTILISATEUR, MYSQL_MDP, BASE_WORLD  # ce qui décrit le poste, hors du dépôt
import ctypes as C
import io
import os
import statistics
import struct
import subprocess
import sys
import tempfile
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
import gen_sla_classes as SLA
import sorts_classes as SC
from gen_visuel_aube import Dbc, stormlib, lit
from gen_visuel_voleur import lit_effectif

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
BASE = BASE_WORLD
MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"

# --- rôles -----------------------------------------------------------------
SOIGNEUR, TANK, MAGIQUE, PHYSIQUE, HYBRIDE = ("soigneur", "tank", "dps magique",
                                              "dps physique", "dps hybride")
ROLES = {
    "warrior": {"Armes": PHYSIQUE, "Fureur": PHYSIQUE, "Protection": TANK},
    "paladin": {"Vindicte": HYBRIDE, "Protection": TANK, "Sacré": SOIGNEUR},
    "hunter": {"Maîtrise des bêtes": PHYSIQUE, "Précision": PHYSIQUE,
               "Survie": PHYSIQUE},
    "rogue": {"Assassinat": PHYSIQUE, "Combat": PHYSIQUE, "Finesse": PHYSIQUE},
    "priest": {"Discipline": SOIGNEUR, "Sacré": SOIGNEUR, "Ombre": MAGIQUE},
    "deathknight": {"Sang": TANK, "Givre": PHYSIQUE, "Impie": HYBRIDE},
    "shaman": {"Amélioration": HYBRIDE, "Élémentaire": MAGIQUE,
               "Restauration": SOIGNEUR},
    "mage": {"Arcanes": MAGIQUE, "Feu": MAGIQUE, "Givre": MAGIQUE},
    "warlock": {"Affliction": MAGIQUE, "Démonologie": MAGIQUE,
                "Destruction": MAGIQUE},
    "druid": {"Farouche": PHYSIQUE, "Équilibre": MAGIQUE,
              "Restauration": SOIGNEUR},
}
RETENUES = {
    SOIGNEUR: ("ps_direct", "ps_duree"),
    MAGIQUE: ("ps_direct", "ps_duree"),
    PHYSIQUE: ("pa_direct", "pa_duree"),
    HYBRIDE: ("ps_direct", "ps_duree", "pa_direct", "pa_duree"),
    TANK: ("ps_direct", "ps_duree", "pa_direct", "pa_duree"),
}
MESURES = ("ps_direct", "ps_duree", "pa_direct", "pa_duree")

# LA VITESSE NORMALISÉE de l'arme type de chaque spécialisation. C'est ce que
# `Unit::GetAPMultiplier` applique : deux mains 3,3 — à distance 2,8 — une
# main 2,4 — dague 1,7. Un choix de notre part, assumé : il fixe la conversion
# « pourcentage d'arme -> puissance d'attaque ».
VITESSES = {
    ("warrior", "Armes"): 3.3, ("warrior", "Fureur"): 2.4,
    ("warrior", "Protection"): 2.4,
    ("paladin", "Vindicte"): 3.3, ("paladin", "Protection"): 2.4,
    ("paladin", "Sacré"): 2.4,
    ("hunter", "Maîtrise des bêtes"): 2.8, ("hunter", "Précision"): 2.8,
    ("hunter", "Survie"): 2.8,
    ("rogue", "Assassinat"): 1.7, ("rogue", "Combat"): 2.4,
    ("rogue", "Finesse"): 1.7,
    ("deathknight", "Sang"): 3.3, ("deathknight", "Givre"): 2.4,
    ("deathknight", "Impie"): 3.3,
    ("shaman", "Amélioration"): 2.4,
    ("druid", "Farouche"): 3.3,
}
VITESSE_DEFAUT = 2.4

# LES DÉGÂTS D'ARME DE RÉFÉRENCE au niveau 80, relevés dans item_template :
# armes de qualité rare et mieux, niveau requis 78+, niveau d'objet 200 à 284.
# Ils servent à convertir « 110 % d'arme » en points de dégâts — sans quoi la
# cadence d'une spécialisation physique ne voit presque rien, ses compétences
# n'infligeant pas de dégâts d'école mais un pourcentage de l'arme.
ARMES_REFERENCE = {3.3: 658, 2.8: 584, 2.4: 359, 1.7: 269}
PAR_POINT_AP = 14.0        # PA/14 par seconde d'arme, règle de 3.3.5

# --- effets ----------------------------------------------------------------
E_DEGATS_DIRECT = {2, 9, 10, 62, 64}      # dégâts d'école, ponction, soin...
E_ARME = {17, 31, 58, 121}                # les quatre effets d'arme
E_ARME_PCT = 31                           # celui qui porte le pourcentage
A_PERIODIQUE = {3, 8, 53}                 # dégâts, soin, ponction sur la durée
E_SOIN = {10}
A_SOIN = {8}
FACTEUR_SOIN = 1.88                       # « C = (Cast Time / 3.5) × 1.88 »


def sans_accent(t):
    return "".join(c for c in unicodedata.normalize("NFD", t)
                   if unicodedata.category(c) != "Mn").lower()


def interroge(requete):
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False,
                                     encoding="utf-8") as f:
        f.write(requete)
        chemin = f.name
    try:
        r = subprocess.run([MYSQL, "-h" + MYSQL_HOTE, "-u" + MYSQL_UTILISATEUR, "-p" + MYSQL_MDP,
                            "--default-character-set=utf8mb4", "-N", "-B", BASE,
                            "-e", "source %s" % chemin.replace("\\", "/")],
                           capture_output=True, text=True, encoding="utf-8")
    finally:
        os.unlink(chemin)
    if r.returncode:
        raise SystemExit(r.stderr.strip())
    return [l.split("\t") for l in r.stdout.splitlines() if l.strip()]


def rangs_maximaux():
    """(sommets, tous) — nos propres rangs de runes écartés des chaînes."""
    chaines = {}
    for premier, sort, rang in interroge(
            "SELECT first_spell_id, spell_id, `rank` FROM spell_ranks;"):
        if int(sort) >= 8500000:
            continue
        chaines.setdefault(int(premier), []).append((int(rang), int(sort)))
    sommets, tous = set(), set()
    for chaine in chaines.values():
        chaine.sort()
        sommets.add(chaine[-1][1])
        tous.update(s for _r, s in chaine)
    return sommets, tous


# ---------------------------------------------------------------------------
# Le coefficient par défaut du cœur, porté à l'identique
# ---------------------------------------------------------------------------
def temps_pour_bonus(sp, sur_la_duree, temps):
    """Port de `Unit::GetCastingTimeForBonus`."""
    temps = min(max(temps, 1500), 7000)
    if sur_la_duree and not sp["canalise"]:
        temps = 3500

    sur_temps, effets, direct, zone = 0, 0, False, False
    for i in range(3):
        e, a = sp["effets"][i], sp["auras"][i]
        if e in E_DEGATS_DIRECT:
            direct = True
        elif e == 6:                                   # APPLY_AURA
            if a in A_PERIODIQUE:
                if sp["duree"]:
                    sur_temps = sp["duree"]
            else:
                effets += 1                            # -5 % par effet en plus
        if e and sp["rayons"][i]:
            zone = True

    if sur_temps > 0 and direct:
        original = min(max(sp["incantation"], 1500), 7000)
        part = (sur_temps / 15000.0) / ((sur_temps / 15000.0)
                                        + (original / 3500.0))
        if sur_la_duree:
            temps = int(temps * part)
        elif part < 1.0:
            temps = int(temps * (1 - part))
        else:
            temps = 0

    if zone:
        temps //= 2
    for i in range(3):
        if sp["effets"][i] == 9 or (sp["effets"][i] == 6
                                    and sp["auras"][i] == 53):
            temps //= 2
            break
    for _ in range(effets):
        temps *= 0.95
    return temps


def coefficient_defaut(sp, sur_la_duree):
    """Port de `Unit::CalculateDefaultCoefficient`."""
    facteur = 1.0
    if sur_la_duree:
        if not sp["canalise"] and sp["duree"] > 0:
            facteur = sp["duree"] / 15000.0
        tics = sp["tics"]
        if tics:
            facteur /= tics
    temps = sp["duree"] if sp["canalise"] else sp["incantation"]
    return temps_pour_bonus(sp, sur_la_duree, temps) / 3500.0 * facteur


# ---------------------------------------------------------------------------
# Lecture des DBC
# ---------------------------------------------------------------------------
def lis_sorts(dll, h):
    cols, IDX = G.carte_des_champs()
    sp = Dbc(lit(dll, h, "DBFilesClient" + BS + "Spell.dbc"))

    def table(nom, champ):
        d = Dbc(lit_effectif(dll, h, nom)[0])
        out = {}
        for i in range(d.nrec):
            o = i * d.rsize
            out[struct.unpack_from("<i", d.enr, o)[0]] = \
                struct.unpack_from("<i", d.enr, o + champ * 4)[0]
        return out

    incantations = table("SpellCastTimes.dbc", 1)
    durees = table("SpellDuration.dbc", 1)

    sorts = {}
    for i in range(sp.nrec):
        o = i * sp.rsize
        g = lambda c: struct.unpack_from("<i", sp.enr, o + IDX[c] * 4)[0]
        f = lambda c: struct.unpack_from("<f", sp.enr, o + IDX[c] * 4)[0]
        ident = struct.unpack_from("<I", sp.enr, o)[0]
        n = struct.unpack_from("<I", sp.enr, o + IDX["Name_Lang_koKR"] * 4)[0]
        nom = (sp.chaines[n:sp.chaines.index(b"\0", n)]
               .decode("utf-8", "replace") if n else "")
        duree = max(durees.get(g("DurationIndex"), 0), 0)
        periodes = [g("EffectAuraPeriod_%d" % k) for k in (1, 2, 3)]
        tics = 0
        for p in periodes:
            if p and duree:
                tics = duree // p
                break
        ex = g("AttributesEx")
        sorts[ident] = {
            "id": ident, "nom": nom,
            "incantation": max(incantations.get(g("CastingTimeIndex"), 0), 0),
            "duree": duree, "tics": tics,
            "canalise": bool(ex & 0x4 or ex & 0x40),
            "effets": [g("Effect_%d" % k) for k in (1, 2, 3)],
            "auras": [g("EffectAura_%d" % k) for k in (1, 2, 3)],
            "rayons": [g("EffectRadiusIndex_%d" % k) for k in (1, 2, 3)],
            "points": [g("EffectBasePoints_%d" % k) + 1 for k in (1, 2, 3)],
            "des": [g("EffectDieSides_%d" % k) for k in (1, 2, 3)],
            "par_niveau": [f("EffectRealPointsPerLevel_%d" % k)
                           for k in (1, 2, 3)],
            "periodes": [g("EffectAuraPeriod_%d" % k) for k in (1, 2, 3)],
            "recharge": max(g("RecoveryTime"), g("CategoryRecoveryTime")),
            "niveau": g("SpellLevel"),
            "niveau_max": g("MaxLevel"),
        }
    return sorts


def spe_par_sort(dll, h):
    """sort -> ensemble de (classe, spé), lignes de compétence ET talents."""
    appartenance = {}

    carte_ligne = {}
    for classe, onglets in SLA.LIGNES.items():
        for spe, ligne in onglets.items():
            if spe != "mobilité":
                carte_ligne[ligne] = (classe, spe)
    d = Dbc(lit(dll, h, "DBFilesClient" + BS + "SkillLineAbility.dbc"))
    for i in range(d.nrec):
        o = i * d.rsize
        ligne, sort = struct.unpack_from("<2I", d.enr, o + 4)
        if ligne in carte_ligne:
            appartenance.setdefault(sort, set()).add(carte_ligne[ligne])

    # LES TALENTS. L'onglet porte son nom ; on l'apparie au nôtre sans tenir
    # compte des accents (le DBC écrit « Elémentaire », nous « Élémentaire »).
    noms = {}
    for classe, onglets in ROLES.items():
        for spe in onglets:
            noms[sans_accent(spe)] = (classe, spe)
    tabs = {}
    d = Dbc(lit_effectif(dll, h, "TalentTab.dbc")[0])
    for i in range(d.nrec):
        o = i * d.rsize
        ident = struct.unpack_from("<i", d.enr, o)[0]
        n = struct.unpack_from("<I", d.enr, o + 3 * 4)[0]
        nom = (d.chaines[n:d.chaines.index(b"\0", n)]
               .decode("utf-8", "replace") if n else "")
        cle = noms.get(sans_accent(nom))
        if cle:
            tabs[ident] = cle
    d = Dbc(lit_effectif(dll, h, "Talent.dbc")[0])
    for i in range(d.nrec):
        o = i * d.rsize
        v = struct.unpack_from("<%di" % d.nfield, d.enr, o)
        cle = tabs.get(v[1])
        if not cle:
            continue
        for sort in v[4:13]:
            if sort:
                appartenance.setdefault(sort, set()).add(cle)
    return appartenance, len(tabs)


# ---------------------------------------------------------------------------
# Les quatre mesures d'un sort
# ---------------------------------------------------------------------------
def mesure(sp, bonus, vitesse):
    """Rend {mesure: valeur} et si le sort est de ZONE."""
    zone = any(sp["rayons"][i] and sp["effets"][i] for i in range(3))
    out = {}
    b = bonus.get(sp["id"])

    direct = any(e in E_DEGATS_DIRECT for e in sp["effets"])
    duree = any(sp["effets"][i] == 6 and sp["auras"][i] in A_PERIODIQUE
                for i in range(3))
    soin = (any(e in E_SOIN for e in sp["effets"])
            or any(a in A_SOIN for a in sp["auras"]))

    if direct:
        if b and b["direct_bonus"]:
            out["ps_direct"] = b["direct_bonus"]
        else:
            c = coefficient_defaut(sp, False)
            if c > 0:
                out["ps_direct"] = c * (FACTEUR_SOIN if soin else 1.0)
    if duree:
        if b and b["dot_bonus"]:
            out["ps_duree"] = b["dot_bonus"]
        else:
            c = coefficient_defaut(sp, True)
            if c > 0:
                out["ps_duree"] = c * (FACTEUR_SOIN if soin else 1.0)

    if b and b["ap_bonus"]:
        out["pa_direct"] = b["ap_bonus"]
    else:
        # ÉQUIVALENT D'ARME : le pourcentage s'il est écrit, 100 % sinon.
        pct = None
        for i in range(3):
            if sp["effets"][i] == E_ARME_PCT:
                pct = sp["points"][i] / 100.0
            elif sp["effets"][i] in E_ARME and pct is None:
                pct = 1.0
        if pct:
            out["pa_direct"] = pct * vitesse / PAR_POINT_AP
    if b and b["ap_dot_bonus"]:
        out["pa_duree"] = b["ap_dot_bonus"]
    return out, zone


NIVEAU = 80                 # le niveau auquel on compare
GCD = 1500                  # ms : l'immobilisation plancher, le temps global

# DEUX GARDE-FOUS SUR LES CADENCES (2026-09-04) :
#
#   PLANCHER  un sort dont le DBC ne porte aucune valeur — porteur de proc,
#             écho, aura de service — rend une cadence de l'ordre de 1 par
#             seconde. Ce n'est pas un soin faible, c'est l'absence de chiffre :
#             le compter tire la médiane vers zéro (les soins du paladin
#             tombaient de 2 000 à 0,7 par seconde).
#   APPUIS    les seaux « zone » sont souvent presque vides ; en dessous de
#             trois appuis on ne s'y fie pas et on retombe sur le mono-cible.
PLANCHER_CADENCE = 10.0
APPUIS_MIN = 3
MARGE_HAUT = 1.10           # « moyen-haut » : un cran au-dessus du P75


def seau(bacs, nature, portee):
    """Le jeu d'appuis à retenir : celui de la portée s'il tient debout, le
    mono-cible sinon, l'union en dernier ressort."""
    propre = bacs.get((nature, portee), [])
    if len(propre) >= APPUIS_MIN:
        return propre
    mono = bacs.get((nature, "mono"), [])
    if len(mono) >= APPUIS_MIN:
        return mono
    tous = propre + [x for x in mono if x not in propre]
    autre = bacs.get((nature, "zone" if portee == "mono" else "mono"), [])
    tous += [x for x in autre if x not in tous]
    return tous


def p75(valeurs):
    """Le troisième quartile — au-dessus des trois quarts du panier."""
    v = sorted(valeurs)
    if not v:
        return None
    if len(v) == 1:
        return v[0]
    return statistics.quantiles(v, n=4)[2]


def montant(sp, k):
    """La valeur MOYENNE de l'effet k au niveau 80, dé et montée comprises.

    Le DBC donne un socle, un dé et une pente par niveau ; le client et le
    serveur les additionnent. Ne lire que le socle sous-estime lourdement les
    sorts de bas rang montés au niveau du joueur."""
    base = sp["points"][k]
    de = sp["des"][k]
    moyen = base + (de - 1) / 2.0 if de > 1 else base
    # LA MONTÉE PAR NIVEAU n'a de sens que si le sort dit à partir de quel
    # niveau il monte. À zéro — le cas de beaucoup de sorts de déclenchement —
    # on compterait quatre-vingts niveaux de croissance et la valeur explose
    # (l'Empalement ressortait à 82 000). On s'abstient alors.
    if sp["par_niveau"][k] and sp["niveau"]:
        haut = sp["niveau_max"] or NIVEAU
        gagnes = max(0, min(NIVEAU, haut) - sp["niveau"])
        moyen += sp["par_niveau"][k] * gagnes
    return moyen


def lancement(sp):
    """Ce qu'un LANCER coûte au joueur, en secondes : son incantation, ou à
    défaut le temps de recharge global. La RECHARGE n'entre pas ici — voir
    PRIME_RECHARGE."""
    return max(sp["incantation"], GCD) / 1000.0


def etalement(sp):
    """La durée sur laquelle un effet périodique se dépose, en secondes."""
    return max(sp["duree"], GCD) / 1000.0


# LA PRIME DE RECHARGE. Rapporter les dégâts à la recharge et remultiplier par
# la nôtre donnait des monstres — un Cataclysme à 37 000 —, parce que ce
# modèle suppose qu'un sort de 90 s vaut soixante lancers : il oublie que le
# joueur continue de lancer ses sorts de remplissage pendant la recharge. Un
# sort à recharge ne vaut qu'UN lancer, majoré de ce que sa rareté justifie.
#
# LES POINTS D'ANCRAGE viennent de l'utilisateur (2026-09-04). Entre deux, on
# interpole en ligne droite ; en dessous du premier on part de 1 (un sort
# qu'on lance à volonté ne mérite aucune prime) ; au-delà du dernier on
# prolonge la dernière pente.
ANCRES_PRIME = ((0.0, 1.0), (15.0, 3.0), (45.0, 3.5), (90.0, 4.5))

# TROIS CORRECTIONS À LA MAIN (décisions de l'utilisateur, 2026-09-04). Elles
# vivent ici plutôt que dans les valeurs écrites : le calcul reste rejouable,
# et l'écart au barème se lit.
#
#   8600092  Solstice et Équinoxe n'a AUCUNE recharge, donc aucune prime — mais
#            il est rationné par la fenêtre de cinq secondes qui suit chaque
#            limite, soit un lancer toutes les six incantations. On lui compte
#            une recharge ÉQUIVALENTE de 15 s, le temps de traverser la jauge.
#   8600093  Floraison ressortait à 15 300 de soin direct, cohérent avec le kit
#            mais hors de proportion en jeu : soins divisés par trois.
#   8600091  Frénésie farouche a porté un doublement du 2026-09-04, retiré le
#            jour même : sa faiblesse venait de la conversion « pourcentage
#            d'arme » qui manquait à la cadence, non de son dessin.
RECHARGE_EQUIVALENTE = {8600092: 15000}

# LES PORTEURS prennent la recharge de leur parent : un écho, une onde, une
# zone posée par un script n'a pas de recharge à lui, et la prime la plus
# basse ne dirait rien de ce qu'il coûte réellement au joueur.
PARENTS = {sp["id"]: sp["parent"] for sp in SC.SORTS if sp.get("parent")}
# La fraction qui revient à chaque porteur quand plusieurs se partagent
# la valeur du parent.
PARTS = {sp["id"]: sp["part"] for sp in SC.SORTS
         if sp.get("part", 1.0) != 1.0}
FACTEURS_MAIN = {
    8600093: {"soin_direct": 1 / 3.0, "soin_duree": 1 / 3.0},
    # La Frénésie ressortait à 5 700 une fois la conversion « pourcentage
    # d'arme » en place : ramenée aux 3 800 voulus (2026-09-04). Seul le coup
    # direct est touché — le saignement vient du script, par palier.
    8600091: {"degats_direct": 2 / 3.0},
}


def prime_recharge(sp, sorts=None):
    ident = sp["id"]
    brute = sp["recharge"]
    parent = PARENTS.get(ident)
    if parent and sorts and sorts.get(parent):
        brute = sorts[parent]["recharge"]
    recharge = max(RECHARGE_EQUIVALENTE.get(ident, brute), 0) / 1000.0
    if recharge <= 0:
        return ANCRES_PRIME[0][1]
    for (x0, y0), (x1, y1) in zip(ANCRES_PRIME, ANCRES_PRIME[1:]):
        if recharge <= x1:
            return y0 + (y1 - y0) * (recharge - x0) / (x1 - x0)
    (x0, y0), (x1, y1) = ANCRES_PRIME[-2], ANCRES_PRIME[-1]
    return y1 + (y1 - y0) * (recharge - x1) / (x1 - x0)


def cadence(sp, vitesse=VITESSE_DEFAUT):
    """Rend {nature: valeur par seconde}. Le direct se rapporte au temps de
    LANCEMENT, l'effet sur la durée à SA DURÉE — les mélanger faisait dire à
    un poison de 18 secondes qu'il inflige 5 700 points par seconde."""
    direct, sur_duree = {}, {}
    duree = sp["duree"]
    for k in range(3):
        e, a = sp["effets"][k], sp["auras"][k]
        v = montant(sp, k)
        if v <= 0:
            continue
        if e == 2:
            direct["degats_direct"] = direct.get("degats_direct", 0) + v
        elif e == 10:
            direct["soin_direct"] = direct.get("soin_direct", 0) + v
        elif e == 6 and a in (3, 53) and duree and sp["periodes"][k]:
            sur_duree["degats_duree"] = sur_duree.get("degats_duree", 0) +                 v * (duree // sp["periodes"][k])
        elif e == 6 and a == 8 and duree and sp["periodes"][k]:
            sur_duree["soin_duree"] = sur_duree.get("soin_duree", 0) +                 v * (duree // sp["periodes"][k])
    # LA PART D'ARME. Une compétence physique inflige « x % de l'arme » plus
    # un bonus plat : sans cette conversion, la cadence ne voyait que le
    # bonus plat et rendait des valeurs absurdes (le guerrier à 1 point par
    # seconde).
    pct = None
    for k in range(3):
        if sp["effets"][k] == E_ARME_PCT:
            pct = sp["points"][k] / 100.0
        elif sp["effets"][k] in E_ARME and pct is None:
            pct = 1.0
    if pct:
        direct["degats_direct"] = (direct.get("degats_direct", 0)
                                   + pct * ARMES_REFERENCE.get(vitesse, 359))

    out = {n: t / lancement(sp) for n, t in direct.items()}
    out.update({n: t / etalement(sp) for n, t in sur_duree.items()})
    return out


def main():
    detail = "--detail" in sys.argv
    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0x00000100, C.byref(h)):
        raise SystemExit("archive non ouverte")
    try:
        sorts = lis_sorts(dll, h)
        appartenance, nb_tabs = spe_par_sort(dll, h)
    finally:
        dll.SFileCloseArchive(h)

    bonus = {}
    for r in interroge("SELECT entry, direct_bonus, dot_bonus, ap_bonus,"
                       " ap_dot_bonus FROM spell_bonus_data;"):
        bonus[int(r[0])] = dict(zip(("direct_bonus", "dot_bonus", "ap_bonus",
                                     "ap_dot_bonus"),
                                    (float(v) for v in r[1:])))
    sommets, enchaines = rangs_maximaux()

    # --- récolte ----------------------------------------------------------
    echantillons = {}          # (classe, spé) -> {mesure: {'mono': [], 'zone': []}}
    cadences = {}              # (classe, spé) -> {(nature, portée): [par sec]}
    appuis = {}
    for sort, cles in appartenance.items():
        sp = sorts.get(sort)
        if not sp:
            continue
        # NOS PROPRES SORTS NE MESURENT PAS LE KIT. Ils y figurent pourtant :
        # ils portent une ligne de compétence, et depuis que le barème leur
        # écrit des valeurs, ils se mesuraient EUX-MÊMES — chaque passe
        # gonflait la suivante (le Météore pesait 8 519/s dans le kit du mage,
        # avec le chiffre que la passe précédente lui avait donné). Tout
        # identifiant >= 8500000 est à nous : rangs de runes compris.
        if sort >= 8500000:
            continue
        if sort in enchaines and sort not in sommets:
            continue
        for cle in cles:
            if cle[0] not in ROLES or cle[1] not in ROLES[cle[0]]:
                continue
            vals, zone = mesure(sp, bonus, VITESSES.get(cle, VITESSE_DEFAUT))
            if not vals:
                continue
            bac = echantillons.setdefault(cle, {m: {"mono": [], "zone": []}
                                                for m in MESURES})
            for m, v in vals.items():
                bac[m]["zone" if zone else "mono"].append(v)
                appuis.setdefault((cle, m), []).append((sp["nom"], v, zone))
            # LES NOMBRES DE BASE, rapportés au temps d'immobilisation.
            for nature, taux in cadence(
                    sp, VITESSES.get(cle, VITESSE_DEFAUT)).items():
                if taux < PLANCHER_CADENCE:
                    continue          # le DBC ne porte pas de chiffre ici
                cadences.setdefault(cle, {}).setdefault(
                    (nature, "zone" if zone else "mono"), []).append(taux)
    return afficher(echantillons, cadences, appuis, nb_tabs, detail, sorts)


def resume(valeurs):
    """(médiane, moyenne, maximum, nombre) — ou None si le bac est vide."""
    if not valeurs:
        return None
    return (statistics.median(valeurs), sum(valeurs) / len(valeurs),
            max(valeurs), len(valeurs))


def ecris_bareme(echantillons, cadences, sorts):
    """Écrit `ratios_sorts.py` — le barème mesuré, que gen_sorts_classes relit.

    Il vit à part de `sorts_classes.py` À DESSEIN : la table de vérité porte
    le DESSIN des sorts, écrit à la main ; ce fichier-ci porte des MESURES,
    réécrites en entier à chaque passe. Les mêler rendrait le diff illisible
    et exposerait le dessin à un écrasement."""
    lignes = ["# -*- coding: utf-8 -*-",
              'r"""Barème de puissance des sorts customs — FICHIER GÉNÉRÉ.',
              "",
              "Écrit par `gen_ratios_classes.py --ecris`. Ne pas éditer à la",
              "main : la passe suivante l'écrase en entier. Le dessin des sorts",
              "vit dans `sorts_classes.py`, les mesures ici.",
              "",
              "RATIOS : (direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus), le",
              "P75 du kit de la spécialisation majoré de %d %%."
              % round((MARGE_HAUT - 1) * 100),
              "",
              "BASES : la valeur à écrire dans l'effet, par nature — la cadence",
              "P75 du kit portée sur le temps que le sort occupe, majorée de sa",
              'prime de recharge.',
              '"""',
              "",
              "RATIOS = {"]
    bases = ["BASES = {"]
    for sp_def in SC.SORTS:
        ident = sp_def["id"]
        classe, spe = sp_def["classe"], sp_def["spec"]
        role = ROLES.get(classe, {}).get(spe)
        sp = sorts.get(ident)
        if role is None or not sp:
            continue
        zone = any(sp["rayons"][i] and sp["effets"][i] for i in range(3))
        portee = "zone" if zone else "mono"
        bac = echantillons.get((classe, spe), {})
        quatre = []
        for m in ("ps_direct", "ps_duree", "pa_direct", "pa_duree"):
            if m not in RETENUES[role]:
                quatre.append(0.0)
                continue
            v = bac.get(m, {}).get(portee) or bac.get(m, {}).get("mono")
            quatre.append(round(p75(v) * MARGE_HAUT, 4) if v else 0.0)
        if any(quatre):
            lignes.append("    %d: (%s),   # %s %s, %s"
                          % (ident, ", ".join("%.4f" % q for q in quatre),
                             classe, spe, role))

        prime = prime_recharge(sp, sorts)
        bacs = cadences.get((classe, spe), {})
        valeurs = {}
        for nature in ("degats_direct", "soin_direct", "degats_duree",
                       "soin_duree"):
            v = seau(bacs, nature, portee)
            if not v:
                continue
            t = lancement(sp) if nature.endswith("direct") else etalement(sp)
            main = FACTEURS_MAIN.get(ident, {}).get(nature, 1.0)
            total = p75(v) * MARGE_HAUT * t * prime * main * PARTS.get(ident, 1.0)
            valeurs[nature] = int(round(total))
            # LA VALEUR PAR BATTEMENT, pour les effets périodiques : c'est
            # elle que porte l'effet, le total n'existant que dans notre
            # tête. Le générateur n'a que l'INDEX de durée, pas les
            # millisecondes — il ne saurait pas la recalculer.
            if nature.endswith("duree"):
                periode = next((sp["periodes"][i] for i in range(3)
                                if sp["periodes"][i]), 0)
                if periode and sp["duree"]:
                    tics = max(1, sp["duree"] // periode)
                    valeurs[nature + "_tic"] = int(round(total / tics))
        if valeurs:
            bases.append("    %d: {%s},   # %s %s, prime %.2f"
                         % (ident, ", ".join('"%s": %d' % (n, v)
                                             for n, v in valeurs.items()),
                            classe, spe, prime))
    lignes.append("}")
    lignes.append("")
    bases.append("}")
    chemin = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "ratios_sorts.py")
    io.open(chemin, "w", encoding="utf-8", newline="").write(
        chr(10).join(lignes + bases) + chr(10))
    print(chr(10) + "Barème écrit : %s (%d ratios, %d jeux de bases)"
          % (chemin, len(lignes) - 16, len(bases) - 2))


def afficher(echantillons, cadences, appuis, nb_tabs, detail, sorts):
    print("=" * 104)
    print("1. RÔLES PAR SPÉCIALISATION   (%d onglets de talents appariés)"
          % nb_tabs)
    print("=" * 104)
    for classe, onglets in ROLES.items():
        print("  %-12s %s" % (classe, "   ".join(
            "%s : %s" % (s, r) for s, r in onglets.items())))

    print()
    print("=" * 104)
    print("2. RATIOS RELEVÉS   (P75 majoré de %d %%, et les appuis)"
          % round((MARGE_HAUT - 1) * 100))
    print("=" * 104)
    for classe, onglets in ROLES.items():
        for spe, role in onglets.items():
            bac = echantillons.get((classe, spe))
            print("  %-12s %-20s %-12s" % (classe, spe, role))
            if not bac:
                print("        aucun appui")
                continue
            for m in RETENUES[role]:
                for nature in ("mono", "zone"):
                    v = bac[m][nature]
                    if not v:
                        continue
                    q = p75(v)
                    print("        %-10s %-5s  P75 %.4f  ->  RETENU %.4f"
                          "   (méd %.4f, max %.4f, %d appuis)"
                          % (m, nature, q, q * MARGE_HAUT,
                             statistics.median(v), max(v), len(v)))

    print()
    print("=" * 104)
    print("3. CADENCES DU KIT   (valeur par seconde d'immobilisation, P75)")
    print("=" * 104)
    for classe, onglets in ROLES.items():
        for spe, _role in onglets.items():
            bacs = cadences.get((classe, spe))
            if not bacs:
                continue
            morceaux = []
            for (nature, portee), v in sorted(bacs.items()):
                morceaux.append("%s/%s %.0f (%d)"
                                % (nature, portee, p75(v), len(v)))
            print("  %-12s %-20s %s" % (classe, spe, "   ".join(morceaux)))

    # --- 4. les sorts du sphèrier -----------------------------------------
    print()
    print("=" * 104)
    print("4. À APPLIQUER AUX SORTS DU SPHÈRIER")
    print("=" * 104)
    for sp_def in SC.SORTS:
        ident = sp_def["id"]
        if not (SC.PLAGE_CLASSES[0] <= ident <= SC.PLAGE_CLASSES[1]):
            continue
        classe, spe = sp_def["classe"], sp_def["spec"]
        role = ROLES.get(classe, {}).get(spe)
        sp = sorts.get(ident)
        if role is None or not sp:
            print("  %-12s %-8d %-28s hors spécialisation (%s)"
                  % (classe, ident, sp_def["fr"][:28], spe))
            continue
        zone = any(sp["rayons"][i] and sp["effets"][i] for i in range(3))
        portee = "zone" if zone else "mono"
        print("  %-12s %-14s %-8d %-28s [%s, %s]"
              % (classe, spe, ident, sp_def["fr"][:28], role, portee))

        bac = echantillons.get((classe, spe), {})
        for m in RETENUES[role]:
            v = bac.get(m, {}).get(portee) or bac.get(m, {}).get("mono")
            if not v:
                continue
            print("        ratio %-10s %.4f" % (m, p75(v) * MARGE_HAUT))

        # LES NOMBRES DE BASE : la cadence du kit, portée sur le temps que
        # NOTRE sort occupe, puis majorée par sa prime de recharge.
        prime = prime_recharge(sp, sorts)
        bacs = cadences.get((classe, spe), {})
        for nature in ("degats_direct", "soin_direct", "degats_duree",
                       "soin_duree"):
            v = seau(bacs, nature, portee)
            if not v:
                continue
            t = lancement(sp) if nature.endswith("direct") else etalement(sp)
            main = FACTEURS_MAIN.get(ident, {}).get(nature, 1.0)
            valeur = p75(v) * MARGE_HAUT * t * prime * main
            print("        base  %-13s %7.0f   (%.0f/s x %.1f s x prime %.2f"
                  "%s, %d appuis)"
                  % (nature, valeur, p75(v), t, prime,
                     "" if main == 1.0 else " x main %.2f" % main, len(v)))

    if "--ecris" in sys.argv:
        ecris_bareme(echantillons, cadences, sorts)

    if detail:
        print()
        print("=" * 104)
        print("APPUIS, SORT PAR SORT")
        print("=" * 104)
        for (cle, m), liste in sorted(appuis.items()):
            print("  %s / %s — %s" % (cle[0], cle[1], m))
            for nom, v, zone in sorted(liste, key=lambda x: -x[1]):
                print("        %.4f  %-4s %s" % (v, "zone" if zone else "mono",
                                                 nom))
    return echantillons, cadences


if __name__ == "__main__":
    main()
