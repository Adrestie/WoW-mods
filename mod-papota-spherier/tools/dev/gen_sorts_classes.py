# -*- coding: utf-8 -*-
r"""Fabrique les quarante sorts de classe, des deux côtés.

Le procédé est celui des sorts de Nexus, généralisé : on CLONE un enregistrement
existant du Spell.dbc, on écrit par-dessus les champs qui comptent, et l'on
dépose le résultat aux deux endroits qui en ont besoin — la table `spell_dbc`
pour le serveur, le Spell.dbc de patch-z.MPQ pour le client, d'où vient
l'infobulle.

**La carte des champs n'est pas devinée.** Les 234 colonnes de `spell_dbc`
suivent exactement l'ordre des 234 champs du DBC : on la lit donc dans
`information_schema` et l'on écrit toutes les colonnes, plutôt que d'en choisir
vingt et de s'en remettre aux valeurs par défaut de la table pour le reste. Un
sort qui saute, canalise ou absorbe met en jeu bien plus de champs qu'un
consommable.

**Le gabarit** est le sort 59061, déjà éprouvé ici : instantané, sur le lanceur,
sans exigence d'équipement. Tout ce qui le distingue d'un sort de classe est
réécrit champ par champ ; ce qu'on ne réécrit pas — famille de sorts, masques
divers — reste à zéro, ce qui convient à des sorts autonomes sans interaction
avec les talents.

Usage :
    python gen_sorts_classes.py            (SQL + Spell.dbc de travail)
    python gen_sorts_classes.py --deploy   (injecte aussi dans le MPQ client)
"""
import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import MYSQL_HOTE, MYSQL_PORT, MYSQL_UTILISATEUR, MYSQL_MDP, BASE_WORLD  # ce qui décrit le poste, hors du dépôt
import ctypes as C
import io
import glob
import os
import struct
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sorts_classes as SC
try:
    import ratios_sorts as RS          # barème mesuré, écrit par
except ImportError:                    # gen_ratios_classes.py --ecris
    RS = None

sys.stdout.reconfigure(encoding="utf-8")

DLL = r"D:\Serveur WoW\tools\StormLib_build\Release\StormLib.dll"
def dossier_client():
    """Le dossier `data` du client, quelle que soit la version du jeu.

    LE CHEMIN ÉTAIT ÉCRIT EN DUR, VERSION COMPRISE. Renommer le dossier du jeu
    de 1.1.0 en 1.2.0 a suffi à faire échouer l'injection — et à la faire
    échouer DISCRÈTEMENT : le générateur écrit son SQL et son DBC de travail
    avant de toucher au client, si bien que tout paraissait normal jusqu'à la
    dernière ligne (2026-09-04).

    On cherche donc le dossier au lieu de le supposer, en retenant la version la
    plus haute si plusieurs cohabitent.
    """
    racine = os.path.join(os.path.expanduser("~"), "Desktop")
    for base in reversed(sorted(glob.glob(os.path.join(racine, "WoW Papota *")))):
        for nom in ("data", "Data"):
            chemin = os.path.join(base, nom)
            if os.path.isdir(chemin):
                return chemin
    raise SystemExit("aucun client « WoW Papota * » trouvé sous %s" % racine)


DATA = dossier_client()
ARCHIVE = os.path.join(DATA, "patch-z.MPQ")
NOM_DBC = r"DBFilesClient\Spell.dbc"
TRAVAIL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sorts_classes_out")
SORTIE_SQL = (r"D:\Serveur WoW\azerothcore-wotlk\modules\mod-papota-spherier"
              r"\data\sql\world\2026_08_27_00_mod_papota_sorts_classes.sql")
MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
BASE = BASE_WORLD
GABARIT = 59061

BLOCS = {"Name": 136, "NameSubtext": 153, "Description": 170,
         "AuraDescription": 187}
LOC_FRFR = 2      # 0 enUS, 1 koKR, 2 frFR, 3 deDE — vérifié sur le sort 47471


# ---------------------------------------------------------------------------
# Les plages que ce generateur possede, des deux cotes : le SQL les efface en
# entier avant de les reecrire, le client en fait autant. Voir sorts_classes.py
# pour le schema 86000CS (C = classe, S = emplacement) et pour la plage
# AUXILIAIRE, ou vivent les auras que les scripts posent en coulisse.
PLAGES = (SC.PLAGE_CLASSES, SC.PLAGE_AUXILIAIRE)


def possede(ident):
    """Vrai si `ident` appartient a une plage de ce generateur."""
    return any(a <= ident <= b for a, b in PLAGES)


E_DEGATS_ECOLE = 2          # SPELL_EFFECT_SCHOOL_DAMAGE
E_SOIN_DIRECT = 10          # SPELL_EFFECT_HEAL

# LES EFFETS QUI POSENT UNE AURA, la simple comme celles de zone. La règle
# d'écriture ne connaissait que la première : la zone de soins de la Floraison
# (effet 27, objet dynamique) n'a jamais reçu sa valeur de base, alors qu'elle
# porte bel et bien une aura périodique et que le cœur lui applique le
# coefficient qu'on lui a écrit.
EFFETS_AURA = {6,      # APPLY_AURA
               27,     # PERSISTENT_AREA_AURA — l'objet dynamique au sol
               35,     # APPLY_AREA_AURA_PARTY
               65,     # APPLY_AREA_AURA_RAID
               128}    # APPLY_AREA_AURA_FRIEND


def carte_des_champs():
    """L'index de chaque champ, lu dans le schéma plutôt que deviné."""
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False,
                                     encoding="utf-8") as f:
        # `column_type` et non `data_type` : seul le premier porte le
        # « unsigned », dont depend le signe de relecture.
        f.write("SELECT ordinal_position-1, column_name, column_type "
                "FROM information_schema.columns WHERE table_schema='%s' "
                "AND table_name='spell_dbc' ORDER BY ordinal_position;" % BASE)
        chemin = f.name
    try:
        r = subprocess.run([MYSQL, "-h" + MYSQL_HOTE, "-u" + MYSQL_UTILISATEUR, "-p" + MYSQL_MDP,
                            "--default-character-set=utf8mb4", "-N", "-B", BASE,
                            "-e", "source %s" % chemin.replace("\\", "/")],
                           capture_output=True, text=True, encoding="utf-8")
    finally:
        os.unlink(chemin)
    cols = [l.split("\t") for l in r.stdout.splitlines() if l.strip()]
    if len(cols) != 234:
        raise SystemExit("%d colonnes lues, 234 attendues" % len(cols))
    return ([(n, t) for _i, n, t in cols],
            dict((n, int(i)) for i, n, _t in cols))


def stormlib():
    s = C.WinDLL(DLL)
    s.SFileOpenArchive.argtypes = [C.c_wchar_p, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    s.SFileOpenArchive.restype = C.c_bool
    s.SFileCloseArchive.argtypes = [C.c_void_p]
    s.SFileCloseArchive.restype = C.c_bool
    s.SFileOpenFileEx.argtypes = [C.c_void_p, C.c_char_p, C.c_uint, C.POINTER(C.c_void_p)]
    s.SFileOpenFileEx.restype = C.c_bool
    s.SFileGetFileSize.argtypes = [C.c_void_p, C.POINTER(C.c_uint)]
    s.SFileGetFileSize.restype = C.c_uint
    s.SFileReadFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint,
                                C.POINTER(C.c_uint), C.c_void_p]
    s.SFileReadFile.restype = C.c_bool
    s.SFileCloseFile.argtypes = [C.c_void_p]
    s.SFileCloseFile.restype = C.c_bool
    s.SFileCreateFile.argtypes = [C.c_void_p, C.c_char_p, C.c_ulonglong, C.c_uint,
                                  C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    s.SFileCreateFile.restype = C.c_bool
    s.SFileWriteFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint, C.c_uint]
    s.SFileWriteFile.restype = C.c_bool
    s.SFileFinishFile.argtypes = [C.c_void_p]
    s.SFileFinishFile.restype = C.c_bool
    return s


def lire_du_client(s):
    h = C.c_void_p()
    if not s.SFileOpenArchive(ARCHIVE, 0, 0x00000100, C.byref(h)):
        raise SystemExit("ouverture impossible : %s" % ARCHIVE)
    try:
        fh = C.c_void_p()
        if not s.SFileOpenFileEx(h, NOM_DBC.encode("latin-1"), 0, C.byref(fh)):
            raise SystemExit("Spell.dbc absent de l'archive")
        try:
            taille = s.SFileGetFileSize(fh, None)
            tampon = (C.c_ubyte * taille)()
            lus = C.c_uint(0)
            s.SFileReadFile(fh, tampon, taille, C.byref(lus), None)
            return bytes(bytearray(tampon))
        finally:
            s.SFileCloseFile(fh)
    finally:
        s.SFileCloseArchive(h)


# ---------------------------------------------------------------------------
def construire():
    colonnes, IDX = carte_des_champs()
    print("carte des champs : %d colonnes lues dans le schéma" % len(colonnes))

    brut = lire_du_client(stormlib())
    magic, nrec, nfield, rsize, ssize = struct.unpack_from("<4s4I", brut, 0)
    if magic != b"WDBC" or nfield != 234:
        raise SystemExit("Spell.dbc inattendu : %s, %d champs" % (magic, nfield))
    debut = 20
    enr = bytearray(brut[debut:debut + nrec * rsize])
    chaines = bytearray(brut[debut + nrec * rsize:])
    print("Spell.dbc du client : %d sorts, %d champs" % (nrec, nfield))

    # TOUTE LA PLAGE, comme le SQL (« DELETE FROM spell_dbc WHERE ID BETWEEN
    # ... »). Ne retirer que les ids qu'on s'apprete a ecrire
    # laissait ORPHELIN tout sort supprime de sorts_classes.py : il survivait
    # dans le client alors que le serveur l'avait oublie. Six s'etaient
    # accumules ainsi avant qu'on s'en apercoive le 2026-09-03.
    gabarit = None
    garde, retires = bytearray(), 0
    for i in range(nrec):
        off = i * rsize
        ident = struct.unpack_from("<I", enr, off)[0]
        if ident == GABARIT:
            gabarit = bytes(enr[off:off + rsize])
        if possede(ident):
            retires += 1
            continue
        garde.extend(enr[off:off + rsize])
    if gabarit is None:
        raise SystemExit("gabarit %d absent" % GABARIT)
    if retires:
        print("  %d sort(s) d'une exécution précédente retiré(s)" % retires)
    enr, nrec = garde, nrec - retires

    def ajoute_chaine(txt):
        pos = len(chaines)
        chaines.extend(txt.encode("utf-8") + b"\x00")
        return pos

    def pose_texte(rec, bloc, en, fr):
        base = BLOCS[bloc]
        oe, of = ajoute_chaine(en), ajoute_chaine(fr)
        for loc in range(16):
            struct.pack_into("<I", rec, (base + loc) * 4, of if loc == LOC_FRFR else oe)
        struct.pack_into("<I", rec, (base + 16) * 4, 0xFF)

    def met(rec, nom, valeur, signe=False):
        struct.pack_into("<i" if signe else "<I", rec, IDX[nom] * 4, int(valeur))

    lignes_sql = []
    for sp in SC.SORTS:
        rec = bytearray(gabarit)
        met(rec, "ID", sp["id"])
        met(rec, "SchoolMask", sp["ecole"])
        # La mécanique du sort : 14 = « assommé », celle qui jette à la
        # renverse au lieu de figer sur place. Écrite pour TOUS (zéro par
        # défaut), sinon un reliquat de gabarit s'inviterait.
        met(rec, "Mechanic", sp.get("mecanique", 0))
        # AttributesEx2 : écrit pour TOUS (zéro par défaut), sinon un
        # reliquat de gabarit s'inviterait.
        met(rec, "AttributesEx2", sp.get("attributs_ex2", 0))
        # AttributesEx3 et AttributesEx6 : ecrits pour TOUS (zero par
        # defaut), sinon un reliquat de gabarit s'inviterait.
        met(rec, "AttributesEx3", sp.get("attributs_ex3", 0))
        met(rec, "AttributesEx4", sp.get("attributs_ex4", 0))
        met(rec, "AttributesEx6", sp.get("attributs_ex6", 0))
        # Le réticule au sol et la canalisation : les deux se disent par des
        # drapeaux, relevés sur Pluie de feu et Flèches des arcanes. Sans le
        # premier, la zone tombe aux pieds du lanceur ; sans les seconds, la
        # « canalisation » n'est qu'un dégât sur la durée.
        met(rec, "Targets", 0x40 if sp.get("cible_sol") else 0)
        if sp.get("canal"):
            iv, cf = sp.get("interrompu"), sp.get("canal_flags")
            met(rec, "AttributesEx", 0x4 | sp.get("attributs_ex", 0))
            met(rec, "InterruptFlags", 0xF if iv is None else iv)
            met(rec, "ChannelInterruptFlags", 0x7C0C if cf is None else cf)
        else:
            met(rec, "AttributesEx", sp.get("attributs_ex", 0))
            met(rec, "InterruptFlags", 0)
            met(rec, "ChannelInterruptFlags", 0)
        # Les procs d'aura : masque des événements déclencheurs (mêlée...),
        # chance 101 = toujours. Écrits pour TOUS les sorts (zéro par
        # défaut), sinon un reliquat de gabarit ferait des procs fantômes.
        met(rec, "ProcTypeMask", sp.get("proc_flags", 0))
        met(rec, "ProcChance", 101 if sp.get("proc_flags") else 0)
        # LES CHARGES : un nombre d'emplois, pas une duree. L'aura se retire
        # d'elle-meme a la derniere. Zero par defaut, comme avant : un
        # reliquat de gabarit ferait des consommations fantomes.
        met(rec, "ProcCharges", sp.get("charges", 0))
        # LE REACTIF : un objet consomme au lancement (le fragment d'ame du
        # Cataclysme). Ecrit pour tous, a zero par defaut.
        reactif, nombre = sp.get("reactif", (0, 0))
        met(rec, "Reagent_1", reactif, signe=True)
        met(rec, "ReagentCount_1", nombre)
        met(rec, "CastingTimeIndex", sp["cast"])
        met(rec, "RangeIndex", sp["portee"])
        met(rec, "RecoveryTime", sp["recharge"])
        met(rec, "CategoryRecoveryTime", 0)

        # LE TEMPS DE RECHARGE GLOBAL. Aucun de nos sorts ne le déclenchait ni
        # ne s'y soumettait (relevé du 2026-09-04) : on pouvait en enchaîner
        # plusieurs dans le même instant et les glisser entre deux sorts
        # normaux sans rien payer. Catégorie 133 = la générale, celle de tous
        # les sorts de joueur. Les sorts qui NE S'APPRENNENT PAS n'en ont pas :
        # ce sont des échos, des porteurs de visuel et des bienfaits que les
        # scripts posent — ils ne coûtent pas un tour au joueur.
        lance = (SC.PLAGE_CLASSES[0] <= sp["id"] <= SC.PLAGE_CLASSES[1]
                 and sp["id"] not in SC.SANS_ONGLET) or sp.get("grimoire")
        # DEUX NOTIONS DISTINCTES, à ne pas confondre : `lance` dit que le sort
        # est APPRIS — il gouverne aussi l'injection du barème plus bas — quand
        # `gcd` dit qu'il PAIE un tour. Les affranchis de SANS_GCD sont appris
        # comme les autres ; les mélanger priverait le Retour stellaire de ses
        # valeurs mesurées.
        gcd = lance and sp["id"] not in SC.SANS_GCD
        met(rec, "StartRecoveryCategory", 133 if gcd else 0)
        met(rec, "StartRecoveryTime", 1500 if gcd else 0)

        # LA CLASSE DE DÉGÂTS. À zéro, `Unit::SpellDoneCritChance` ne calcule
        # rien : le sort ne peut PAS faire de coup critique. On la pose sur
        # tout sort qui inflige des dégâts directs ou qui soigne — les deux
        # cas que l'utilisateur a nommés. L'école décide du genre : physique
        # au corps à corps, à distance chez le chasseur, magique sinon.
        direct = any(e["effet"] in (E_DEGATS_ECOLE, E_SOIN_DIRECT)
                     for e in sp["effets"][:3])
        if sp.get("classe_degats"):
            classe = sp["classe_degats"]        # valeur posée à la main
        elif direct:
            if sp["ecole"] == SC.PHYSIQUE:
                classe = 3 if sp["classe"] == "hunter" else 2
            else:
                classe = 1
        else:
            classe = 0
        met(rec, "DefenseType", classe)

        # LE TYPE DE PRÉVENTION. À zéro, ni silence ni contresort ne bloquait
        # nos sorts. 1 = SILENCE pour les sorts magiques, 2 = PACIFY pour les
        # compétences physiques — la convention des sorts natifs.
        met(rec, "PreventionType", sp.get("blocage")
            or (1 if classe == 1 else (2 if classe in (2, 3) else 0)))

        # LA FAMILLE DE SORTS, celle de la classe : sans elle les talents qui
        # ciblent une famille ne voient pas le sort.
        met(rec, "SpellClassSet",
            sp.get("famille") or SC.FAMILLES.get(sp["classe"], 0))
        # LA FORME EXIGEE : un bit par forme, 1 << (forme - 1). A zero,
        # le sort se lance dans toutes. Voir sorts_classes (FORME_*).
        met(rec, "ShapeshiftMask", sp.get("formes", 0))
        # L'AURA EXIGEE DU LANCEUR : le client refuse le sort tant
        # qu'elle manque, et il le grise. Aucun script requis.
        met(rec, "CasterAuraSpell", sp.get("aura_requise", 0))
        met(rec, "DurationIndex", sp["duree"])
        met(rec, "SpellIconID", sp["icone"])
        met(rec, "ActiveIconID", 0)
        met(rec, "SpellLevel", 0)
        met(rec, "BaseLevel", 0)
        met(rec, "MaxLevel", 0)
        met(rec, "PowerType", sp["ressource"] if sp["ressource"] is not None else 0)
        met(rec, "ManaCost", sp["cout"])
        # cout_pct : pourcentage du mana de BASE (le régime du Blizzard :
        # ManaCostPct 74) — plombé le 2026-08-31 pour le Météore 8600056.
        met(rec, "ManaCostPct", sp.get("cout_pct", 0))
        # famille : SpellClassSet (3 = mage...) + les trois masques de
        # famille — c'est par eux que les TALENTS ciblés (spellmods, procs)
        # attrapent un sort. Plombé le 2026-08-31 (spé Feu sur le Météore).
        for k, masque in enumerate(sp.get("famille_masque", (0, 0, 0))):
            met(rec, "SpellClassMask_%d" % (k + 1), masque)
        # (DefenseType et PreventionType sont écrits plus haut, POUR TOUS les
        # sorts : les deux lignes qui vivaient ici ne servaient que les rares
        # sorts portant `classe_degats`/`blocage`, et surtout elles écrasaient
        # le calcul général puisqu'elles passaient après lui.)
        # arme = (EquippedItemClass, EquippedItemSubclass) : l'arme EXIGÉE.
        # Les tirs natifs portent (2, 0x4004C) — armes, arcs/fusils/
        # arbalètes. Le gabarit met -1 : on l'écrit toujours pour qu'un
        # reliquat ne réclame pas une arme au hasard.
        classe_arme, sous_arme = sp.get("arme", (-1, 0))
        met(rec, "EquippedItemClass", classe_arme, signe=True)
        met(rec, "EquippedItemSubclass", sous_arme, signe=True)
        # Le nombre de piles : sans lui, un sort dont le script empile son aura
        # ne peut jamais depasser une seule application.
        met(rec, "CumulativeAura", sp.get("pile", 0))
        # L'attribut qui range l'aura parmi les malus. Sans lui le client
        # l'affiche comme un bienfait, quel que soit ce qu'elle fait.
        met(rec, "Attributes", sp.get("attributs", 0))
        # Rang unique : le bloc de texte du rang — NameSubtext, index 153 à 169 —
        # est vidé, et rien n'entre dans `spell_ranks`. Ce bloc n'est PAS à 204 :
        # là se trouve ManaCostPct, et le confondre effacerait le coût du sort.

        # Les trois emplacements d'effet sont d'abord vidés : le gabarit en
        # porte un, et un reliquat ferait un effet fantôme.
        for k in (1, 2, 3):
            for champ in ("Effect_%d", "EffectDieSides_%d", "EffectBasePoints_%d",
                          "EffectAura_%d", "ImplicitTargetA_%d", "ImplicitTargetB_%d",
                          "EffectRadiusIndex_%d", "EffectAuraPeriod_%d",
                          "EffectMiscValue_%d", "EffectMiscValueB_%d",
                          "EffectMechanic_%d",
                          "EffectChainTargets_%d", "EffectItemType_%d"):
                met(rec, champ % k, 0)
            met(rec, "SpellVisualID_%d" % k if k <= 2 else "SpellVisualID_2", sp["visuel"])

        # LE BARÈME MESURÉ entre ici, pour les sorts que le JOUEUR LANCE et
        # pour les PORTEURS qui déclarent un parent — écho, onde, zone : ils
        # n'ont pas de recharge à eux, et prennent celle du parent. Les
        # auras de service, elles, restent à la valeur de la table : leur
        # montant vient du script.
        bases = (RS.BASES.get(sp["id"], {})
                 if RS and (lance or sp.get("parent")) else {})

        def valeur_mesuree(e, defaut):
            """La valeur du barème pour cet effet, ou celle de la table."""
            if not bases:
                return defaut
            if e["effet"] == E_DEGATS_ECOLE:
                return bases.get("degats_direct", defaut)
            if e["effet"] == E_SOIN_DIRECT:
                return bases.get("soin_direct", defaut)
            if e["effet"] in EFFETS_AURA and e["periode"]:
                # LES VALEURS SUR LA DURÉE : l'effet porte UN battement, et
                # c'est le barème qui l'a calculé — ici on n'a que l'index de
                # durée, pas les millisecondes.
                if e["aura"] in (3, 53):
                    return bases.get("degats_duree_tic", defaut)
                if e["aura"] == 8:
                    return bases.get("soin_duree_tic", defaut)
            return defaut

        for k, e in enumerate(sp["effets"][:3], start=1):
            met(rec, "Effect_%d" % k, e["effet"])
            met(rec, "ImplicitTargetA_%d" % k, e["cible"])
            met(rec, "ImplicitTargetB_%d" % k, e["cibleB"])
            met(rec, "EffectAura_%d" % k, e["aura"])
            met(rec, "EffectRadiusIndex_%d" % k, e["rayon"])
            # LA CIBLE D'UN MODIFICATEUR vit ici, et non dans les drapeaux du
            # sort : EffectSpellClassMask<A|B|C>_<mot>, la lettre étant
            # l'EFFET et le chiffre le mot. Un masque nul vaut « toute la
            # famille » (SpellInfo::IsAffected).
            for mot, valeur in enumerate(e.get("masque", (0, 0, 0)), start=1):
                met(rec, "EffectSpellClassMask%s_%d" % ("ABC"[k - 1], mot),
                    valeur)
            met(rec, "EffectAuraPeriod_%d" % k, e["periode"])
            met(rec, "EffectMiscValue_%d" % k, e["misc"], signe=True)
            met(rec, "EffectMechanic_%d" % k, e.get("mecanique", 0))
            # Le second misc : pour une invocation, l'entrée SummonProperties
            # qui décide du genre de créature levée.
            met(rec, "EffectMiscValueB_%d" % k, e.get("miscB", 0), signe=True)
            met(rec, "EffectTriggerSpell_%d" % k, e.get("declenche", 0))
            # $s1 = BasePoints + DieSides : N - 1 affiche donc N, et le serveur
            # lit la même valeur par GetEffectValue(). POUR TOUT SIGNE :
            # « -50 % » se stocke -51 (le relevé d'origine). La branche
            # « N + 1 si négatif », introduite par erreur, affichait et
            # APPLIQUAIT N + 2 — le « 28 % » constaté en jeu le 2026-08-30
            # sur le -30 du Bouclier de l'Inquisition.
            if e["points"]:
                # des : une FOURCHETTE de dégâts (plombé le 2026-08-31 pour
                # le Météore 2500-3200) — min = points, max = points-1+des ;
                # l'infobulle les rend par $m1/$M1.
                met(rec, "EffectDieSides_%d" % k, e.get("des", 0) or 1)
                met(rec, "EffectBasePoints_%d" % k,
                valeur_mesuree(e, e["points"]) - 1, signe=True)
        met(rec, "SpellVisualID_1", sp["visuel"])
        # La vitesse du missile — un FLOTTANT. dist/vitesse = délai d'impact,
        # que le serveur applique aux effets (phase immédiate différée pour un
        # sort à destination) et que le client emploie pour faire voler le
        # missile du visuel : une seule valeur, deux lectures, comme $s1.
        struct.pack_into("<f", rec, IDX["Speed"] * 4, float(sp.get("vitesse", 0)))

        pose_texte(rec, "NameSubtext", "", "")
        # La description de l'AURA : c'est elle que lit l'infobulle du malus sur
        # la barre de la cible. Vide, le joueur voit une icône muette.
        pose_texte(rec, "AuraDescription",
                   sp.get("aura_en") or sp["desc_en"],
                   sp.get("aura_fr") or sp["desc_fr"])
        pose_texte(rec, "Name", sp["en"], sp["fr"])
        pose_texte(rec, "Description", sp["desc_en"], sp["desc_fr"])

        enr.extend(rec)
        nrec += 1
        lignes_sql.append((sp, bytes(rec)))

    libere_incantation_en_marchant(enr, rsize, nrec, IDX)

    entete = bytearray(brut[:20])
    struct.pack_into("<4I", entete, 4, nrec, nfield, rsize, len(chaines))
    neuf = bytes(entete) + bytes(enr) + bytes(chaines)
    os.makedirs(TRAVAIL, exist_ok=True)
    local = os.path.join(TRAVAIL, "Spell.dbc")
    io.open(local, "wb").write(neuf)
    print("Spell.dbc écrit : %s (%d sorts, %.1f Mo)"
          % (local, nrec, len(neuf) / 1048576.0))
    return colonnes, IDX, lignes_sql, neuf


# Le chaman sous Ascendance (8600062) lance l'Éclair, la Chaîne d'éclairs et
# l'Explosion de lave EN MARCHANT. Le serveur le sait déjà — PapotaCasteEnMarchant
# dans Spell.cpp neutralise ses deux contrôles de mouvement pour ces sorts, et
# seulement quand l'aura est là. Mais le CLIENT interrompt le cast de son côté,
# sur le bit 0x01 d'InterruptFlags lu dans SON Spell.dbc, et il coupe avant que
# le serveur ait son mot à dire : le correctif serveur ne pouvait jamais
# s'exprimer. On retire donc ce bit côté client et on laisse le serveur arbitrer.
#
# Contrepartie assumée : HORS Ascendance, un chaman qui bouge en incantant voit
# désormais la barre partir puis être annulée PAR LE SERVEUR, au lieu d'être
# refusée d'emblée par le client. Le sort échoue dans les deux cas.
#
# Les sorts sont désignés par leur FAMILLE et leurs masques, jamais par une
# liste de rangs : les 59 concernés incluent tous les rangs Blizzard, les
# surcharges et les rangs customs du sphèrier (8510891 et suivants).
FAMILLE_CHAMAN = 11
FAMILLE_DEMONISTE = 5
INTERRUPT_MOUVEMENT = 0x01

# (famille, masque sur le mot 1, masque sur le mot 2, ce que c'est, l'aura qui
# arbitre côté serveur). Les sorts sont désignés par leur FAMILLE et leurs
# masques, jamais par une liste de rangs : tous les rangs Blizzard, les
# surcharges et les rangs customs du sphèrier en bénéficient sans liste à tenir.
LIBRES_EN_MARCHANT = (
    (FAMILLE_CHAMAN, 0x3, 0x1000,
     "Éclair, Chaîne d'éclairs, Explosion de lave", 8600062),
    # Le démoniste sous Cataclysme : ses deux prochains Feu de l'âme (0x80) et
    # Trait du Chaos (0x20000) sont INSTANTANÉS, mais le client refuse quand
    # même de les ouvrir en marchant — il lit le bit du DBC, pas la durée
    # réelle que le modificateur ramène à zéro. Relevé en jeu le 2026-09-03.
    (FAMILLE_DEMONISTE, 0x0, 0x80 | 0x20000,
     "Feu de l'âme, Trait du Chaos", 8610012),
)


def libere_incantation_en_marchant(enr, rsize, nrec, IDX):
    """Retire le bit « le mouvement interrompt » aux sorts concernés."""
    i_int = IDX["InterruptFlags"] * 4
    i_fam = IDX["SpellClassSet"] * 4
    i_m1 = IDX["SpellClassMask_1"] * 4
    i_m2 = IDX["SpellClassMask_2"] * 4
    touches = []
    for famille, masque1, masque2, quoi, aura in LIBRES_EN_MARCHANT:
        combien = 0
        for k in range(nrec):
            o = k * rsize
            if struct.unpack_from("<I", enr, o + i_fam)[0] != famille:
                continue
            m1 = struct.unpack_from("<I", enr, o + i_m1)[0]
            m2 = struct.unpack_from("<I", enr, o + i_m2)[0]
            if not ((m1 & masque1) or (m2 & masque2)):
                continue
            drapeaux = struct.unpack_from("<I", enr, o + i_int)[0]
            if not (drapeaux & INTERRUPT_MOUVEMENT):
                continue
            struct.pack_into("<I", enr, o + i_int,
                             drapeaux & ~INTERRUPT_MOUVEMENT)
            touches.append(struct.unpack_from("<I", enr, o)[0])
            combien += 1
        print("incantation en marchant : bit de mouvement retiré à %d sort(s) "
              "(%s, tous rangs) — le serveur arbitre via l'aura %d"
              % (combien, quoi, aura))
    return touches


def bloc_ratios():
    """L'INSERT des coefficients, ou un commentaire si le bareme manque."""
    if not RS or not getattr(RS, "RATIOS", None):
        return "-- (aucun bareme : lancer gen_ratios_classes.py --ecris)"
    noms = {sp["id"]: sp["fr"] for sp in SC.SORTS}
    corps = ["(%d, %.4f, %.4f, %.4f, %.4f, '%s')"
             % (ident, d, dot, ap, apdot,
                noms.get(ident, "").replace("'", "''"))
             for ident, (d, dot, ap, apdot) in sorted(RS.RATIOS.items())]
    return ("INSERT INTO `spell_bonus_data` (`entry`, `direct_bonus`,"
            " `dot_bonus`, `ap_bonus`, `ap_dot_bonus`, `comments`) VALUES\n"
            + ",\n".join(corps) + ";")


def ecrit_sql(colonnes, IDX, lignes):
    def q(t):
        return t.replace("\\", "\\\\").replace("'", "''")

    noms = ", ".join("`%s`" % n for n, _t in colonnes)

    # LES NOMS DE COLONNES MENTENT SUR LES LOCALES.
    #
    # La table nomme ses seize créneaux enUS, enGB, koKR, frFR, deDE… mais le
    # DBC de 3.3.5 n'a pas de créneau enGB : chez lui c'est enUS, koKR, frFR,
    # deDE. La colonne nommée `Name_Lang_frFR` est donc le créneau 3, l'ALLEMAND,
    # et le serveur — dont LOCALE_frFR vaut 2 — y lit ce que porte la colonne
    # nommée `koKR`. Vérifié sur le sort 47471 : son créneau 2 rend « Exécution ».
    #
    # On repère donc les créneaux par leur RANG dans le bloc de texte, jamais par
    # le nom de la colonne. Le client, lui, était déjà juste : son écriture passe
    # par LOC_FRFR = 2.
    blocs = {}
    for base, (cle_en, cle_fr) in {
            136: ("en", "fr"), 153: (None, None), 170: ("desc_en", "desc_fr"),
            187: ("aura_en", "aura_fr")}.items():
        for k in range(17):
            blocs[base + k] = (cle_en, cle_fr, k)

    valeurs = []
    for sp, rec in lignes:
        champs = []
        for i, (nom, typ) in enumerate(colonnes):
            # Le seizième créneau de locale, « _Unk », est un varchar(100) là où
            # les autres font 550 : un texte long y échoue, et l'échec APRÈS le
            # DELETE laisse la table vide. Personne ne lit ce créneau — vide.
            if nom.endswith("_Unk"):
                champs.append("''")
            elif i in blocs:
                cle_en, cle_fr, rang = blocs[i]
                if rang == 16:                       # le masque de locales
                    champs.append("255")
                elif cle_en is None:                 # le rang du sort : vide
                    champs.append("''")
                else:
                    en = sp[cle_en] if cle_en in sp else ""
                    fr = sp[cle_fr] if cle_fr in sp else ""
                    if cle_en == "aura_en":
                        en, fr = en or sp["desc_en"], fr or sp["desc_fr"]
                    champs.append("'%s'" % q(fr if rang == LOC_FRFR else en))
            elif typ.startswith(("float", "double")):
                champs.append("%.4f" % struct.unpack_from("<f", rec, i * 4)[0])
            else:
                # LE SIGNE VIENT DU SCHEMA : un masque de famille est
                # `int unsigned`, et 0xFFFFFFFF relu en signe donnerait -1,
                # que MySQL refuse.
                fmt = "<I" if "unsigned" in typ else "<i"
                champs.append("%d" % struct.unpack_from(fmt, rec, i * 4)[0])
        valeurs.append("(%s)" % ", ".join(champs))

    scripts = [(sp["id"], sp["script"]) for sp, _ in lignes if sp["script"]]
    L = ["-- mod-papota-spherier : les quarante sorts de classe.",
         "-- GENERE par outils_spherier\\gen_sorts_classes.py — ne pas editer.",
         "-- Le meme Spell.dbc est injecte dans patch-z.MPQ cote client : c'est de",
         "-- la que viennent le nom et l'infobulle.",
         "",
         # Les DEUX plages, nommees et non deduites des ids ecrits : un sort
         # RETIRE de la table doit disparaitre de la base, ce que « du plus
         # petit au plus grand id ecrit » ne garantit pas.
         "\n".join("DELETE FROM `spell_dbc` WHERE `ID` BETWEEN %d AND %d;" % r
                   for r in PLAGES),
         "INSERT INTO `spell_dbc` (%s) VALUES" % noms,
         ",\n".join(valeurs) + ";",
         "",
         # LES RATIOS. `spell_bonus_data` est la SEULE table ou le coeur
         # va chercher un coefficient : sans ligne, il applique sa formule
         # par defaut (temps d'incantation / 3500), qui ne connait ni la
         # classe ni le role. Valeurs : gen_ratios_classes.py --ecris.
         "\n".join("DELETE FROM `spell_bonus_data` WHERE `entry` BETWEEN"
                   " %d AND %d;" % r for r in PLAGES),
         bloc_ratios(),
         "",
         "\n".join("DELETE FROM `spell_script_names` WHERE `spell_id`"
                   " BETWEEN %d AND %d;" % r for r in PLAGES)]
    if scripts:
        L.append("INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES")
        L.append(",\n".join("(%d, '%s')" % (i, n) for i, n in scripts) + ";")
    os.makedirs(os.path.dirname(SORTIE_SQL), exist_ok=True)
    io.open(SORTIE_SQL, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
    print("SQL écrit : %s (%d sorts, %d script(s))"
          % (SORTIE_SQL, len(lignes), len(scripts)))


def injecte(neuf):
    s = stormlib()
    h = C.c_void_p()
    if not s.SFileOpenArchive(ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        fh = C.c_void_p()
        if not s.SFileCreateFile(h, NOM_DBC.encode("latin-1"), 0, len(neuf), 0,
                                 0x00000200 | 0x80000000, C.byref(fh)):
            raise SystemExit("création impossible dans l'archive")
        tampon = (C.c_ubyte * len(neuf)).from_buffer_copy(neuf)
        if not s.SFileWriteFile(fh, tampon, len(neuf), 0):
            raise SystemExit("écriture impossible")
        s.SFileFinishFile(fh)
    finally:
        s.SFileCloseArchive(h)
    print("Spell.dbc injecté dans %s" % ARCHIVE)


if __name__ == "__main__":
    colonnes, IDX, lignes, neuf = construire()
    ecrit_sql(colonnes, IDX, lignes)
    if "--deploy" in sys.argv:
        injecte(neuf)
    else:
        print("\nSpell.dbc du CLIENT non injecté (ajouter --deploy). JEU FERMÉ requis.")
