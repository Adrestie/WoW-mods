# -*- coding: utf-8 -*-
r"""L'art du chevalier de la mort — Apocalypse (8600051).

Sources exportées le 2026-09-02 : le tourbillon au sol
`8fx_drustvar_witch_groundswirl` (sept textures), l'icône
`spell_deathknight_defile` et le son `spell_dk_apocalypse_summon02`.

Le montage suit celui du prêtre :
  - le modèle et ses textures vont dans patch-z, tables de correspondance
    rallongées au passage (l'export en laisse une trop courte) ;
  - un SpellVisualEffectName porte le modèle, deux SpellVisualKit portent
    l'un l'animation et le son du lancement, l'autre le tourbillon à
    l'impact, et un SpellVisual les rassemble ;
  - la CRÉATION DES GOULES, elle, n'a rien de custom : elle rejoue le kit
    d'impact natif d'Invocation d'une goule (7775, relevé sur le visuel 9311
    de 46585/52150 — son 743 « DeathCoil Impact »), joué par l'IA sur
    chaque goule.

    python gen_visuel_dk.py     (JEU FERMÉ requis : écrit dans patch-z)
"""
import ctypes as C
import io
import os
import shutil
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
from gen_visuel_aube import Dbc, stormlib, lit, ecrit
from gen_visuel_voleur import lit_effectif, texte

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_dk")

# --- Apocalypse (8600051, montage du 2026-09-02) ----------------------------
MODELE_TOURBILLON = "spells" + BS + "8fx_drustvar_witch_groundswirl.mdx"
FICHIER_M2 = "8fx_drustvar_witch_groundswirl.m2"
FICHIER_SKIN = "8fx_drustvar_witch_groundswirl00.skin"
# Le maillage porte 16 m de rayon ; la zone du sort en fait 8 : demi-échelle.
ECHELLE_TOURBILLON = 0.5
EFFET_TOURBILLON = 8200222
ICONE_APOCALYPSE = 8064
NOM_ICONE_APOCALYPSE = "spell_deathknight_defile"
SON_APOCALYPSE = 990115
FICHIER_SON_APOCALYPSE = "spell_dk_apocalypse_summon02.wav"
GABARIT_SON = 3011           # le gabarit « un coup », partagé par tout le
                             # chantier (relevé gen_visuel_mage)
# L'animation d'attaque à deux mains CRITIQUE : Special2H, relevée pour le
# Bond héroïque (CombatCritical, lui, est la réaction de la VICTIME).
ANIM_SPECIAL2H = 58
KIT_APOCALYPSE_LANCER = 30052   # l'animation et le son, sur le chevalier
KIT_APOCALYPSE_ZONE = 30053     # le tourbillon, au sol sous la cible
VISUEL_APOCALYPSE = 30052
# LA LEVÉE D'UNE GOULE : le visuel de Réanimation morbide lui-même (9311,
# relevé sur son sort d'invocation 46585/52150), porté par le sort
# auxiliaire 8600048 que le chevalier lance sur chaque goule. Un visuel à
# nous, qui n'en gardait que l'impact, ne rendait rien de visible
# (2026-09-02) : on prend le natif entier.
# Et la goule S'EXTIRPE DU SOL : anim 127 « Birth », relevée dans
# Creature\NorthrendGhoul (4166 ms), jouée par une emote custom — le canal
# déjà éprouvé pour l'orbe du mage et le dôme du prêtre. C'est bien elle
# qui fait sortir de terre : ses os descendent jusqu'à −2,23 yards puis
# remontent. « EmergeGround » (131), essayée d'abord, ne bouge le modèle
# que de 18 centimètres — « les goules ont l'animation mais ne viennent pas
# de sous le sol » (2026-09-02).
ANIM_EMERGE = 127
EMOTE_EMERGE = 990004
GABARIT_EMOTE = 375          # « ONESHOT_KNEEL », gabarit d'emote un-coup
# La durée de vie des goules (2026-09-02 : 16 s + 3 s). SpellDuration.dbc
# n'a aucune entrée de 19 000 ms — on en pose une, côté client pour
# l'infobulle et côté serveur, qui résout l'index à son tour.
DUREE_GOULE = 900019
DUREE_GOULE_MS = 19000
DBC_SERVEUR_DIR = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc"

# --- L'OMBRE QUI S'ÉTIRE (2026-09-02) --------------------------------------
# Diagnostic : le modèle de la goule (CreatureModelData 2794) déclare une
# boîte englobante — le GeoBox — qui descend à −0,047, c'est-à-dire le ras du
# sol. Or l'animation Birth fait PLONGER sa géométrie jusqu'à −1,77 (relevé
# des bornes de séquence). Le client borne son volume d'ombre sur cette
# boîte : la géométrie qui en sort projette une ombre dégénérée, étirée sur
# le terrain vers ce qu'elle rencontre. Réanimation morbide ne joue jamais
# Birth — d'où un défaut visible avec Apocalypse SEULEMENT.
# Le remède : un modèle À NOUS, clone du 2794 dont le GeoBox couvre la
# plongée, et quatre apparences à nous qui le désignent. Les goules seules en
# héritent ; le familier du chevalier garde les siennes.
MODELE_GOULE = 802112
DISPLAYS_GOULE = ((24992, 802112), (24993, 802113),
                  (24994, 802114), (24995, 802115))
# L'union des bornes de Birth (−0,93 −1,37 −1,77)-(1,38 1,48 2,22) et du
# GeoBox d'origine, avec un peu de marge.
#
# DEUX FAUSSES PISTES, gardées ici pour mémoire (2026-09-02) :
#   - élargir le GeoBox n'a rien changé, et pour cause : la boîte inscrite
#     dans le M2 lui-même (0xA0) descend déjà à −2,61, donc la plongée de
#     Birth était couverte depuis le début ;
#   - le drapeau 0x100, relevé sur les quatre seuls modèles du jeu qui le
#     portent (ossements, quartiers de viande — des objets posés à plat), ne
#     supprime pas l'ombre : les goules en gardaient une.
# Le clone reste en place, il ne nuit pas et sert de point d'appui si une
# retouche du modèle s'avère nécessaire.
GEOBOX_GOULE = (-1.0, -1.4, -2.0, 1.4, 1.7, 2.3)
FLAGS_GOULE = 0


def rallonge_tables(donnees, donnees_skin):
    """Les tables d'unité et de transparence, portées à ce que les lots
    réclament. Une entrée manquante, c'est une lecture hors bornes : erreur
    132 dans un cas, maillage dégénéré dans l'autre. La table est ajoutée en
    fin de fichier et l'en-tête repointé — rien d'existant ne bouge, et
    l'outil est idempotent."""
    m2 = bytearray(donnees)
    nb, ob = struct.unpack_from("<2I", donnees_skin, 4 + 32)
    # 0x88 = table des unités (indexée par texCoordCombo), 0x90 = table de
    # transparence (indexée par texWeightCombo).
    for entete, champ, prolonge in ((0x88, 18, False), (0x90, 20, True)):
        besoin = 0
        for i in range(nb):
            o = ob + i * 24
            n = struct.unpack_from("<H", donnees_skin, o + 14)[0]
            besoin = max(besoin, struct.unpack_from("<H", donnees_skin,
                                                    o + champ)[0] + n)
        na, oa = struct.unpack_from("<2I", m2, entete)
        if na >= besoin:
            continue
        table = list(struct.unpack_from("<%dh" % na, m2, oa)) if na else []
        while len(table) < besoin:
            # L'unité de rang k lit son propre jeu de coordonnées ; la
            # deuxième couche partage l'alpha de la première (la table de
            # transparence prolonge donc sa dernière entrée).
            table.append(table[-1] if prolonge and table else len(table))
        struct.pack_into("<2I", m2, entete, besoin, len(m2))
        m2.extend(struct.pack("<%dh" % besoin, *table))
        print("table 0x%X portée à %d entrée(s) %s" % (entete, besoin, table))
    return bytes(m2)


# --- Tempête d'os (8600052, montage du 2026-09-02) -------------------------
# Sources exportées : le modèle d'état `cfx_deathknight_bonestorm_state`
# (sept textures, trois rubans, cinq émetteurs), l'icône
# `achievement_boss_lordmarrowgar` et le son `bonestorm_cast`.
# Le modèle est bâti en TROIS TEMPS — Stand 667 ms, Hold 3333 ms, Decay
# 666 ms : la forme même d'un effet d'état, qui paraît, tourne et s'éteint.
# Il est donc porté par le champ 4 du visuel, le kit d'ÉTAT, qui vit aussi
# longtemps que l'aura.
FICHIER_M2_OS = "cfx_deathknight_bonestorm_state.m2"
FICHIER_SKIN_OS = "cfx_deathknight_bonestorm_state00.skin"
MODELE_OS = "spells" + BS + "cfx_deathknight_bonestorm_state.mdx"
# Le maillage porte 2,34 m de rayon, la zone du sort en fait 8 : de quoi
# couvrir le pourtour sans noyer le chevalier. Réglable.
ECHELLE_OS = 3.0
EFFET_OS = 8200223
ICONE_OS = 8065
NOM_ICONE_OS = "achievement_boss_lordmarrowgar"
SON_OS = 990116
FICHIER_SON_OS = "bonestorm_cast.wav"
KIT_OS_LANCER = 30054       # le son, sur le chevalier
KIT_OS_ETAT = 30055         # la tempête, tant que l'aura tient
VISUEL_OS = 30055

# --- Souffle de Sindragosa (8600053/54, montage du 2026-09-02) -------------
# Trois sources : la TÊTE DE DRAGON qui souffle (`_cast`, 793 sommets, trois
# temps, deux émetteurs), l'effet AU SOL (`_state`, particules seules,
# 3333 ms) et l'effet SUR LES TOUCHÉS (`_impact`, particules seules,
# 667 ms). Le premier et le deuxième vivent dans le kit de CANALISATION du
# sort mère — la tête au point d'attache Head, le givre au point Base — et
# tiennent donc tant que le souffle dure ; le troisième est l'impact de la
# morsure 8600054, joué sur chaque ennemi du cône.
#
# Une texture de l'impact vivait hors de `spells\` (item\objectcomponents) :
# ramenée sous son seul nom et le manifeste corrigé AVANT inscription, sans
# quoi le client rend des carrés verts.
MODELES_SINDRAGOSA = {
    "deathknight_breathofsindragosa_cast.m2":
        "deathknight_breathofsindragosa_cast00.skin",
}
# LE SOUFFLE INTÉGRÉ À LA TÊTE EST COUPÉ (2026-09-02, « j'ai les deux en
# même temps ») : le modèle de tête porte cinq sections de géométrie — la
# tête elle-même — ET deux émetteurs de particules posés au même point,
# qui sont son jet. On vide la table des émetteurs : la tête reste, son
# souffle s'en va, et `dragonbreath_frost` prend seul la place.
TETE_SANS_EMETTEURS = True
MODELE_TETE = "spells" + BS + "deathknight_breathofsindragosa_cast.mdx"
# LE SOUFFLE : `dragonbreath_frost`, retenu le 2026-09-02 parmi quatre
# animations comparées en jeu. Il remplace `_state`, l'effet au sol
# d'origine, qui ne rendait rien.
MODELE_GIVRE = "spells" + BS + "dragonbreath_frost.mdx"
MODELE_MORSURE = "spells" + BS + "deathknight_breathofsindragosa_impact.mdx"
ECHELLE_SINDRAGOSA = 1.0
EFFET_TETE = 8200224
EFFET_GIVRE = 8200225
EFFET_MORSURE = 8200226
ICONE_SINDRAGOSA = 8066
NOM_ICONE_SINDRAGOSA = "achievement_boss_sindragosa"
SON_SINDRAGOSA = 990117
FICHIER_SON_SINDRAGOSA = "breathofsindragosa_cast.wav"
KIT_SINDRAGOSA_LANCER = 30056    # le son, au debut du souffle
KIT_SINDRAGOSA_CANAL = 30057     # la tete et le souffle, tant que l'aura tient
KIT_SINDRAGOSA_MORSURE = 30058   # sur chaque ennemi du cone
VISUEL_SINDRAGOSA = 30056        # le sort mere
VISUEL_MORSURE = 30057           # la morsure declenchee

# (Le banc d'essai des souffles — quatre sorts factices et leurs visuels
# 30060-63 — est RETIRÉ le 2026-09-02, le choix étant arrêté sur
# `dragonbreath_frost`. Les modèles écartés restent dans l'archive, inertes.)
SOUFFLES = ()

# --- Tunnel de la mort (8600050, montage du 2026-09-02) --------------------
# L'ancienne Marche spectrale, devenue le jeu de deux portes, prend son nom
# et son visage : le portail `11fx_phaseportal01` remplace la Porte de la
# mort native sur nos objets 803820. Le modèle est ÉNORME — 55 m de rayon,
# 75 m de haut — d'où la réduction de 90 % demandée : à l'échelle 0,1 il
# devient un passage de 5,5 m, à la mesure d'un personnage.
MODELE_PORTAIL = "spells" + BS + "11fx_phaseportal01.mdx"
FICHIER_M2_PORTAIL = "11fx_phaseportal01.m2"
FICHIER_SKIN_PORTAIL = "11fx_phaseportal0100.skin"
DISPLAY_PORTAIL = 8500       # GameObjectDisplayInfo, à nous
ECHELLE_PORTAIL = 0.1        # « réduit de 90 % »
ICONE_PORTAIL = 8067
NOM_ICONE_PORTAIL = "inv_netherportal"
# La boîte du display 8046 (la Porte de la mort) est reprise telle quelle :
# elle borne l'objet cliquable, pas le modèle.
GABARIT_DISPLAY_GO = 8046

FONDU = 450        # ms de fondu en fin de séquence
# LES GEOSETS 2 ET 3 SONT RETIRÉS (2026-09-02, à la demande). Ils ne se
# dessinaient pas, et le diagnostic est resté sans remède satisfaisant : le
# modèle est bon partout — géométrie, os, tables de correspondance,
# fichiers BLP, DEUX jeux d'UV bien formés — mais ces deux lots-là posent
# en seconde couche le même fichier sombre (energy1b, index 3), et le
# client de 3.3.5 combine deux couches en MULTIPLIANT (son seul mode pour
# shader 0, la table de combinaison de la version d'origine lui étant
# inconnue). Couche claire × couche sombre donne du noir, invisible en
# mélange additif. Ramenés à une texture ils réapparaissaient, mais
# éblouissants ; teintés en noir, toujours pas satisfaisants. On les
# supprime : leurs lots sont retirés du skin, le reste du modèle est intact.
LOTS_RETIRES = (1, 3)
# Matériau 0 : mélangeait en ALPHA_KEY (mode 1), où l'alpha est un seuil et
# non un dégradé — il disparaissait d'un coup malgré la piste posée. Passé
# en mode 2, « Alpha », pour qu'il fonde.
MATERIAU_ALPHA = {0: 2}
# Les teintes, un bloc de couleur par nuance, et le bloc que lit chaque lot.
TEINTES = ((1.0, 1.0, 1.0),)
TEINTE_DU_LOT = {}
# L'effet TIENT TROIS SECONDES (2026-09-02) : sa séquence native n'en fait
# qu'un peu plus d'une, toutes ses pistes sont donc étirées d'autant.
DUREE_VOULUE = 3000


def pose_fondu(donnees, donnees_skin):
    """Ajoute au modèle un bloc de couleur PAR TEINTE, dont l'ALPHA S'ÉTEINT
    en fin de séquence, et accroche chaque lot sur le sien.

    Relevé du 2026-09-02 : l'export ne porte AUCUN bloc de couleur (champ
    0x48 à zéro, tous les lots à colorIndex 65535) — rien ne module donc ni
    son opacité ni sa teinte, et l'effet disparaît d'un coup à la fin de son
    Stand. Les modèles qui s'éteignent proprement (relevé sur les halos du
    prêtre) ont tous un bloc par matériau : une piste de couleur constante
    et une piste d'alpha interpolée.

    Les blocs sont APPENDUS en fin de fichier et l'en-tête repointé dessus —
    rien d'existant ne bouge. Idempotent : un modèle qui en a déjà est
    laissé tel quel."""
    m2 = bytearray(donnees)
    if struct.unpack_from("<I", m2, 0x48)[0]:
        return bytes(m2), bytes(donnees_skin)

    # La durée de la séquence 0, celle que le kit joue.
    _n, ofs_seq = struct.unpack_from("<2I", m2, 0x1C)
    duree = struct.unpack_from("<I", m2, ofs_seq + 4)[0]
    debut = max(0, int(duree) - FONDU)

    while len(m2) % 4:
        m2.append(0)
    base = len(m2)
    n = len(TEINTES)
    structs = bytearray(n * 40)
    charges = bytearray(n * 68)
    for i, teinte in enumerate(TEINTES):
        o = base + n * 40 + i * 68          # début de la charge du bloc i
        # Les quatre tableaux externes, puis les clés elles-mêmes.
        struct.pack_into("<2I", charges, i * 68 + 0, 1, o + 32)   # 1 clé
        struct.pack_into("<2I", charges, i * 68 + 8, 1, o + 36)
        struct.pack_into("<2I", charges, i * 68 + 16, 3, o + 48)  # 3 clés
        struct.pack_into("<2I", charges, i * 68 + 24, 3, o + 60)
        struct.pack_into("<I", charges, i * 68 + 32, 0)
        struct.pack_into("<3f", charges, i * 68 + 36, *teinte)
        struct.pack_into("<3I", charges, i * 68 + 48, 0, debut, duree)
        struct.pack_into("<3H", charges, i * 68 + 60, 32767, 32767, 0)
        # La piste de COULEUR : constante (interpolation 0). La piste
        # d'ALPHA : pleine, puis éteinte (interpolation 1, linéaire).
        struct.pack_into("<2H4I", structs, i * 40 + 0,
                         0, 0xFFFF, 1, o + 0, 1, o + 8)
        struct.pack_into("<2H4I", structs, i * 40 + 20,
                         1, 0xFFFF, 1, o + 16, 1, o + 24)
    m2.extend(structs)
    m2.extend(charges)
    struct.pack_into("<2I", m2, 0x48, n, base)

    # Sans cette accroche, les blocs existent mais aucun lot ne les lit.
    skin = bytearray(donnees_skin)
    nb, ob = struct.unpack_from("<2I", skin, 4 + 32)
    for i in range(nb):
        struct.pack_into("<H", skin, ob + i * 24 + 8,
                         TEINTE_DU_LOT.get(i, 0))
    print("fondu posé : %d teinte(s), alpha pleine jusqu'à %d ms, éteinte à"
          " %d ms ; lots -> teintes %r"
          % (n, debut, duree,
             [TEINTE_DU_LOT.get(i, 0) for i in range(nb)]))
    return bytes(m2), bytes(skin)


def repare_lots(donnees, donnees_skin):
    """Retire les lots indésirables du skin et corrige les mélanges.

    Un lot retiré, c'est un geoset qui ne se dessine plus : on RÉÉCRIT le
    tableau des lots sans lui et on ajuste le compte. Les sections, elles,
    restent en place — rien ne les lit plus."""
    m2 = bytearray(donnees)
    skin = bytearray(donnees_skin)
    nb, ob = struct.unpack_from("<2I", skin, 36)
    gardes = [i for i in range(nb) if i not in LOTS_RETIRES]
    if len(gardes) != nb:
        lots = b"".join(bytes(skin[ob + i * 24:ob + i * 24 + 24])
                        for i in gardes)
        skin[ob:ob + nb * 24] = lots + bytes(24 * (nb - len(gardes)))
        struct.pack_into("<I", skin, 36, len(gardes))
        print("lots retirés : %r (il en reste %d)"
              % (list(LOTS_RETIRES), len(gardes)))
    nm, om = struct.unpack_from("<2I", m2, 0x70)
    for i, mode in MATERIAU_ALPHA.items():
        if i >= nm:
            continue
        avant = struct.unpack_from("<H", m2, om + i * 4 + 2)[0]
        if avant != mode:
            struct.pack_into("<H", m2, om + i * 4 + 2, mode)
            print("matériau %d : mélange %d -> %d" % (i, avant, mode))
    return bytes(m2), bytes(skin)


def sans_emetteurs(donnees):
    """Vide la table des émetteurs de particules — la géométrie reste."""
    m2 = bytearray(donnees)
    n = struct.unpack_from("<I", m2, 0x128)[0]
    if n:
        struct.pack_into("<2I", m2, 0x128, 0, 0)
        print("émetteurs de particules retirés : %d" % n)
    return bytes(m2)


def etire_sequence(donnees, duree_voulue):
    """Étire la séquence 0 et TOUTES ses pistes jusqu'à la durée voulue.

    Les horodatages d'une piste sont un tableau PAR SÉQUENCE ; les pistes
    accrochées à une séquence globale ne bougent pas. Patron repris de
    retime_sequence (gen_visuel_mage), réduit à ce dont ce modèle a besoin :
    os, couleurs, transparences et transformations UV — il n'a ni émetteur
    ni ruban."""
    m2 = bytearray(donnees)
    _n, ofs_seq = struct.unpack_from("<2I", m2, 0x1C)
    avant = struct.unpack_from("<I", m2, ofs_seq + 4)[0]
    if not avant or avant == duree_voulue:
        return bytes(m2)
    facteur = float(duree_voulue) / float(avant)
    struct.pack_into("<I", m2, ofs_seq + 4, duree_voulue)

    def etire(piste):
        _interp, gseq = struct.unpack_from("<2h", m2, piste)
        if gseq != -1:
            return
        nT, oT = struct.unpack_from("<2I", m2, piste + 4)
        if nT < 1:
            return
        n0, o0 = struct.unpack_from("<2I", m2, oT)
        for k in range(n0):
            t = struct.unpack_from("<I", m2, o0 + k * 4)[0]
            struct.pack_into("<I", m2, o0 + k * 4, int(t * facteur + 0.5))

    for entete, pas, pistes in ((0x2C, 88, (16, 36, 56)), (0x48, 40, (0, 20)),
                                (0x58, 20, (0,)), (0x60, 60, (0, 20, 40))):
        n, ofs = struct.unpack_from("<2I", m2, entete)
        for i in range(n):
            for p in pistes:
                etire(ofs + i * pas + p)
    print("séquence étirée : %d -> %d ms (×%.2f)"
          % (avant, duree_voulue, facteur))
    return bytes(m2)


def pose_goule(cmd, cdi):
    """Le modèle et les apparences de NOTRE goule : clone du 2794 au GeoBox
    élargi, et quatre apparences clonées des natives qui le désignent."""
    if cmd.nfield != 28:
        raise SystemExit("CreatureModelData : %d champs, 28 attendus"
                         % cmd.nfield)
    if cdi.nfield != 16:
        raise SystemExit("CreatureDisplayInfo : %d champs, 16 attendus"
                         % cdi.nfield)
    source = None
    for i in range(cmd.nrec):
        off = i * cmd.rsize
        if struct.unpack_from("<I", cmd.enr, off)[0] == 2794:
            source = [struct.unpack_from("<I", cmd.enr, off + k * 4)[0]
                      for k in range(28)]
            break
    if source is None:
        raise SystemExit("CreatureModelData 2794 (goule) absent")

    cmd.retire({MODELE_GOULE})
    modele = list(source)
    modele[0] = MODELE_GOULE
    # Le chemin est un décalage dans le magasin de chaînes de la SOURCE : il
    # faut le réécrire dans celui qu'on est en train de bâtir.
    modele[2] = cmd.chaine(texte(cmd, source[2]))
    modele[1] = FLAGS_GOULE
    for k, borne in zip(range(17, 23), GEOBOX_GOULE):
        modele[k] = borne
    cmd.pose(modele)

    cdi.retire({neuf for _vieux, neuf in DISPLAYS_GOULE})
    for vieux, neuf in DISPLAYS_GOULE:
        gabarit = None
        for i in range(cdi.nrec):
            off = i * cdi.rsize
            if struct.unpack_from("<I", cdi.enr, off)[0] == vieux:
                gabarit = [struct.unpack_from("<I", cdi.enr, off + k * 4)[0]
                           for k in range(16)]
                break
        if gabarit is None:
            raise SystemExit("CreatureDisplayInfo %d absent" % vieux)
        # Les trois chemins de texture sont eux aussi des décalages.
        for k in (6, 7, 8):
            if gabarit[k]:
                gabarit[k] = cdi.chaine(texte(cdi, gabarit[k]))
        gabarit[0] = neuf
        gabarit[1] = MODELE_GOULE
        cdi.pose(gabarit)


def pose_portail(d, ecrire):
    """L'apparence d'objet de jeu qui porte le portail : clone de la Porte
    de la mort native, chemin de modèle remplacé."""
    if d.nfield != 19:
        raise SystemExit("GameObjectDisplayInfo : %d champs, 19 attendus"
                         % d.nfield)
    gabarit = None
    for i in range(d.nrec):
        off = i * d.rsize
        if struct.unpack_from("<I", d.enr, off)[0] == GABARIT_DISPLAY_GO:
            gabarit = [struct.unpack_from("<i", d.enr, off + k * 4)[0]
                       for k in range(19)]
            break
    if gabarit is None:
        raise SystemExit("apparence d'objet %d absente" % GABARIT_DISPLAY_GO)
    d.retire({DISPLAY_PORTAIL})
    v = list(gabarit)
    v[0] = DISPLAY_PORTAIL
    v[1] = d.chaine(MODELE_PORTAIL)
    d.pose(v)
    ecrire(d.octets())


def pose_duree(d, ecrire):
    """L'entrée de SpellDuration qui manquait : base, par niveau, maximum."""
    if d.nfield != 4:
        raise SystemExit("SpellDuration : %d champs, 4 attendus" % d.nfield)
    d.retire({DUREE_GOULE})
    d.pose([DUREE_GOULE, DUREE_GOULE_MS, 0, DUREE_GOULE_MS])
    ecrire(d.octets())


def pose_emote(d, ecrire):
    """L'emote custom qui joue EmergeGround, clonée d'une emote un-coup."""
    gab = None
    for i in range(d.nrec):
        off = i * d.rsize
        if struct.unpack_from("<I", d.enr, off)[0] == GABARIT_EMOTE:
            gab = [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                   for k in range(d.nfield)]
    if gab is None:
        raise SystemExit("gabarit d'emote %d absent" % GABARIT_EMOTE)
    d.retire({EMOTE_EMERGE})
    gab[0] = EMOTE_EMERGE
    gab[1] = d.chaine("PAPOTAEMERGE")
    gab[2] = ANIM_EMERGE
    gab[6] = 0                    # aucun son
    d.pose(gab)
    ecrire(d.octets())


def fichiers_a_injecter():
    paires = []
    for nom in sorted(os.listdir(os.path.join(ART, "spells"))):
        if nom.endswith((".m2", ".skin", ".blp")):
            paires.append((os.path.join(ART, "spells", nom),
                           "spells" + BS + nom))
    for nom_icone in (NOM_ICONE_APOCALYPSE, NOM_ICONE_OS,
                      NOM_ICONE_SINDRAGOSA, NOM_ICONE_PORTAIL):
        ic = os.path.join(ART, "interface", "icons", nom_icone + ".blp")
        paires.append((ic, "Interface" + BS + "Icons" + BS
                       + nom_icone + ".blp"))
    for nom in sorted(os.listdir(os.path.join(ART, "sound", "spells"))):
        if nom.endswith(".wav"):
            paires.append((os.path.join(ART, "sound", "spells", nom),
                           "Sound" + BS + "Spells" + BS + nom))
    return paires


def main():
    sauvegarde = G.ARCHIVE + ".avant_art_dk"
    if not os.path.exists(sauvegarde):
        print("sauvegarde de l'archive (une fois) : %s" % sauvegarde)
        shutil.copy2(G.ARCHIVE, sauvegarde)

    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        m2 = io.open(os.path.join(ART, "spells", FICHIER_M2), "rb").read()
        skin = io.open(os.path.join(ART, "spells", FICHIER_SKIN), "rb").read()
        m2 = rallonge_tables(m2, skin)
        m2, skin = repare_lots(m2, skin)
        # L'étirement AVANT le fondu : celui-ci lit la durée dans l'en-tête
        # et pose ses clés dessus.
        m2 = etire_sequence(m2, DUREE_VOULUE)
        m2, skin = pose_fondu(m2, skin)
        prepares = {FICHIER_M2: m2, FICHIER_SKIN: skin}

        # La tempête d'os : rien à retoucher qu'une table trop courte à
        # l'export. Elle a déjà ses blocs de couleur et ses trois temps.
        os_skin = io.open(os.path.join(ART, "spells", FICHIER_SKIN_OS),
                          "rb").read()
        prepares[FICHIER_M2_OS] = rallonge_tables(
            io.open(os.path.join(ART, "spells", FICHIER_M2_OS), "rb").read(),
            os_skin)

        # Le souffle : seule la tête a de la géométrie, et donc des tables à
        # rallonger ; le givre et la morsure sont des particules pures.
        for nom_m2, nom_skin in MODELES_SINDRAGOSA.items():
            brut_m2 = rallonge_tables(
                io.open(os.path.join(ART, "spells", nom_m2), "rb").read(),
                io.open(os.path.join(ART, "spells", nom_skin), "rb").read())
            if TETE_SANS_EMETTEURS:
                brut_m2 = sans_emetteurs(brut_m2)
            prepares[nom_m2] = brut_m2

        paires = fichiers_a_injecter()
        tailles = {}
        for local, interne in paires:
            nom = os.path.basename(local)
            donnees = prepares.get(nom) or io.open(local, "rb").read()
            tailles[interne] = len(donnees)
            ecrit(dll, h, interne, donnees)
        defauts = 0
        for _local, interne in paires:
            if len(lit(dll, h, interne)) != tailles[interne]:
                print("ECART %s" % interne)
                defauts += 1
        print("%d fichier(s) injecté(s) et relus conformes (%d écart(s))"
              % (len(paires), defauts))
        if defauts:
            raise SystemExit("injection non conforme")

        prefixe = "DBFilesClient" + BS

        # --- SpellIcon --------------------------------------------------------
        brut, source = lit_effectif(dll, h, "SpellIcon.dbc")
        d = Dbc(brut)
        icones = ((ICONE_APOCALYPSE, NOM_ICONE_APOCALYPSE),
                  (ICONE_OS, NOM_ICONE_OS),
                  (ICONE_SINDRAGOSA, NOM_ICONE_SINDRAGOSA),
                  (ICONE_PORTAIL, NOM_ICONE_PORTAIL))
        d.retire({ident for ident, _n in icones})
        for ident, nom_icone in icones:
            d.pose([ident, d.chaine("Interface" + BS + "Icons" + BS
                                    + nom_icone)])
        ecrit(dll, h, prefixe + "SpellIcon.dbc", d.octets())
        print("SpellIcon : %s — base %s"
              % (", ".join("%d -> %s" % i for i in icones), source))

        # --- SoundEntries -----------------------------------------------------
        brut, source = lit_effectif(dll, h, "SoundEntries.dbc")
        d = Dbc(brut)
        gabarit = None
        for i in range(d.nrec):
            off = i * d.rsize
            if struct.unpack_from("<I", d.enr, off)[0] == GABARIT_SON:
                gabarit = [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                           for k in range(d.nfield)]
        if gabarit is None:
            raise SystemExit("gabarit sonore %d absent" % GABARIT_SON)
        d.retire({SON_APOCALYPSE, SON_OS, SON_SINDRAGOSA})
        for ident, nom_son, fichier in (
                (SON_APOCALYPSE, "PapotaApocalypse", FICHIER_SON_APOCALYPSE),
                (SON_OS, "PapotaTempeteOs", FICHIER_SON_OS),
                (SON_SINDRAGOSA, "PapotaSindragosa",
                 FICHIER_SON_SINDRAGOSA)):
            v = list(gabarit)
            v[0] = ident
            v[2] = d.chaine(nom_son)
            for k in range(10):
                v[3 + k] = d.chaine(fichier) if k == 0 else 0
                v[13 + k] = 1 if k == 0 else 0
            v[23] = d.chaine("Sound" + BS + "Spells")
            d.pose(v)
        ecrit(dll, h, prefixe + "SoundEntries.dbc", d.octets())
        print("SoundEntries : %d (apocalypse), %d (tempête d'os) et %d"
              " (souffle) posés — base %s"
              % (SON_APOCALYPSE, SON_OS, SON_SINDRAGOSA, source))

        # --- SpellVisualEffectName --------------------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        effets = ((EFFET_TOURBILLON, "Apocalypse - tourbillon",
                   MODELE_TOURBILLON, ECHELLE_TOURBILLON),
                  (EFFET_OS, "Tempete d'os", MODELE_OS, ECHELLE_OS),
                  (EFFET_TETE, "Sindragosa - tete", MODELE_TETE,
                   ECHELLE_SINDRAGOSA),
                  (EFFET_GIVRE, "Sindragosa - givre au sol", MODELE_GIVRE,
                   ECHELLE_SINDRAGOSA),
                  (EFFET_MORSURE, "Sindragosa - morsure", MODELE_MORSURE,
                   ECHELLE_SINDRAGOSA)) + tuple(
            (eid, "Essai - " + nom, "spells" + BS + nom + ".mdx",
             ECHELLE_SINDRAGOSA) for _s, _k, eid, nom in SOUFFLES)
        d.retire({ident for ident, _n, _m, _e in effets})
        for ident, nom, modele, echelle in effets:
            d.pose([ident, d.chaine(nom), d.chaine(modele), 0.0, echelle,
                    0.01, 100.0])
        ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())
        print("SpellVisualEffectName : effets %s posés"
              % ", ".join("%d (%s)" % (i, n) for i, n, _m, _e in effets))

        # --- SpellVisualKit ---------------------------------------------------
        # 38 champs : le lancer porte l'ANIMATION (champ 2) et le SON (15) ;
        # la zone porte le modèle au point d'attache Base (champ 5).
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_APOCALYPSE_LANCER, KIT_APOCALYPSE_ZONE,
                  KIT_OS_LANCER, KIT_OS_ETAT})
        d.pose([KIT_APOCALYPSE_LANCER, -1, ANIM_SPECIAL2H] + [0] * 12
               + [SON_APOCALYPSE, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_APOCALYPSE_ZONE, -1, -1, 0, 0, EFFET_TOURBILLON]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        # La tempête d'os : le son au lancer, puis le modèle au point
        # d'attache Base tant que l'aura tient.
        d.pose([KIT_OS_LANCER, -1, -1] + [0] * 12
               + [SON_OS, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_OS_ETAT, -1, -1, 0, 0, EFFET_OS]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Le souffle : le son au debut ; puis, tant qu'il dure, la TETE au
        # point d'attache Head (champ 3) et le GIVRE au point Base (champ
        # 5) ; enfin la morsure sur chaque ennemi du cone, au torse.
        d.retire({KIT_SINDRAGOSA_LANCER, KIT_SINDRAGOSA_CANAL,
                  KIT_SINDRAGOSA_MORSURE})
        d.pose([KIT_SINDRAGOSA_LANCER, -1, -1] + [0] * 12
               + [SON_SINDRAGOSA, 0] + [-1, -1, -1, -1] + [0] * 17)
        # LE SOUFFLE AU POINT « BREATH » (champ 8, 2026-09-02) : au champ 14,
        # l'effet monde, il restait planté dans le décor au lieu de suivre le
        # personnage ; au champ 5, le point Base, il ne rendait rien. Le
        # champ 8 est celui de la BOUCHE — le point prévu pour un souffle,
        # accroché au personnage. La tête garde le champ 3.
        d.pose([KIT_SINDRAGOSA_CANAL, -1, -1, EFFET_TETE, 0, 0, 0, 0,
                EFFET_GIVRE] + [0] * 8 + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_SINDRAGOSA_MORSURE, -1, -1, 0, EFFET_MORSURE, 0]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Le banc d'essai : un kit par souffle, le modèle au point Head —
        # le même accrochage que la tête de Sindragosa, pour comparer à
        # armes égales.
        d.retire({kit for _s, kit, _e, _n in SOUFFLES})
        for _sort, kit, effet, _nom in SOUFFLES:
            d.pose([kit, -1, -1, effet, 0, 0] + [0] * 9 + [0, 0]
                   + [-1, -1, -1, -1] + [0] * 17)
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (anim %d + son %d), %d (tourbillon),"
              " %d (son de la tempête), %d (tempête, état), %d (son du"
              " souffle), %d (tête + givre) et %d (morsure) posés"
              % (KIT_APOCALYPSE_LANCER, ANIM_SPECIAL2H, SON_APOCALYPSE,
                 KIT_APOCALYPSE_ZONE, KIT_OS_LANCER, KIT_OS_ETAT,
                 KIT_SINDRAGOSA_LANCER, KIT_SINDRAGOSA_CANAL,
                 KIT_SINDRAGOSA_MORSURE))

        # --- SpellVisual ------------------------------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL_APOCALYPSE, VISUEL_OS, VISUEL_SINDRAGOSA,
                  VISUEL_MORSURE} | {kit for _s, kit, _e, _n in SOUFFLES})
        v = [0] * 32
        v[0] = VISUEL_APOCALYPSE
        v[2] = KIT_APOCALYPSE_LANCER   # le lancer : l'anim et le son
        v[3] = KIT_APOCALYPSE_ZONE     # l'impact : le tourbillon au sol
        d.pose(v)
        # La tempête d'os : le champ 4 est le kit d'ÉTAT, celui qui vit
        # aussi longtemps que l'aura — le canal du dôme de la Barrière.
        o = [0] * 32
        o[0] = VISUEL_OS
        o[2] = KIT_OS_LANCER
        o[4] = KIT_OS_ETAT
        d.pose(o)
        # Le souffle : le champ 4 est le kit d'ÉTAT, qui tient tant que
        # l'aura tient. Il portait le champ 6, celui de la CANALISATION —
        # mais le sort n'est plus canalisé (2026-09-02), et un kit de canal
        # ne se joue plus.
        s = [0] * 32
        s[0] = VISUEL_SINDRAGOSA
        s[2] = KIT_SINDRAGOSA_LANCER
        s[4] = KIT_SINDRAGOSA_CANAL
        d.pose(s)
        # La morsure : rien que son impact, sur chaque ennemi du cône.
        mo = [0] * 32
        mo[0] = VISUEL_MORSURE
        mo[3] = KIT_SINDRAGOSA_MORSURE
        d.pose(mo)
        # Le banc d'essai : un visuel par souffle, qui ne porte que son kit
        # de lancer. Même identifiant que le kit, pour s'y retrouver.
        for _sort, kit, _effet, _nom in SOUFFLES:
            e = [0] * 32
            e[0] = kit
            e[2] = kit
            d.pose(e)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : visuels %d (lancer %d, impact %d), %d (lancer"
              " %d, état %d), %d (souffle : lancer %d, canal %d) et %d"
              " (morsure : impact %d) posés — le souffle en kit d'ÉTAT"
              % (VISUEL_APOCALYPSE, KIT_APOCALYPSE_LANCER,
                 KIT_APOCALYPSE_ZONE, VISUEL_OS, KIT_OS_LANCER, KIT_OS_ETAT,
                 VISUEL_SINDRAGOSA, KIT_SINDRAGOSA_LANCER,
                 KIT_SINDRAGOSA_CANAL, VISUEL_MORSURE,
                 KIT_SINDRAGOSA_MORSURE))
        print("Banc d'essai : %s"
              % ", ".join("%s -> sort %d, visuel %d"
                          % (n, s, k) for s, k, _e, n in SOUFFLES))

        # --- Emotes et durées : côté client puis côté serveur ------------------
        # Le serveur valide les emotes qu'on lui demande de jouer et résout
        # lui-même les index de durée : les mêmes entrées lui sont posées.
        for nom, pose, quoi in (("Emotes.dbc", pose_emote,
                                 "emote %d (Birth %d)"
                                 % (EMOTE_EMERGE, ANIM_EMERGE)),
                                ("SpellDuration.dbc", pose_duree,
                                 "durée %d (%d ms)"
                                 % (DUREE_GOULE, DUREE_GOULE_MS)),
                                ("GameObjectDisplayInfo.dbc", pose_portail,
                                 "apparence %d (portail)"
                                 % DISPLAY_PORTAIL)):
            # lit_effectif : patch-z d'abord, les archives de base ensuite —
            # SpellDuration.dbc n'a jamais été copié dans le patch.
            brut, source = lit_effectif(dll, h, nom)
            pose(Dbc(brut),
                 lambda octets, n=nom: ecrit(dll, h, prefixe + n, octets))
            chemin = os.path.join(DBC_SERVEUR_DIR, nom)
            if not os.path.exists(chemin):
                raise SystemExit("DBC serveur absent : %s" % chemin)
            if not os.path.exists(chemin + ".avant_dk"):
                shutil.copy2(chemin, chemin + ".avant_dk")
            with io.open(chemin, "rb") as f:
                serveur = Dbc(f.read())

            def ecrit_serveur(octets, p=chemin):
                with io.open(p, "wb") as g:
                    g.write(octets)

            pose(serveur, ecrit_serveur)
            print("%-20s : %s posée — base %s, écrite dans patch-z et"
                  " Data%sdbc" % (nom, quoi, source, BS))

        # --- Le modèle de la goule, au GeoBox élargi ---------------------------
        brut_cmd, source_cmd = lit_effectif(dll, h, "CreatureModelData.dbc")
        brut_cdi, source_cdi = lit_effectif(dll, h, "CreatureDisplayInfo.dbc")
        cmd, cdi = Dbc(brut_cmd), Dbc(brut_cdi)
        pose_goule(cmd, cdi)
        ecrit(dll, h, prefixe + "CreatureModelData.dbc", cmd.octets())
        ecrit(dll, h, prefixe + "CreatureDisplayInfo.dbc", cdi.octets())
        print("Goule (client) : modèle %d (flags 0x%X, GeoBox %r) et"
              " apparences %r posés — bases %s / %s"
              % (MODELE_GOULE, FLAGS_GOULE, GEOBOX_GOULE,
                 [n for _v, n in DISPLAYS_GOULE], source_cmd, source_cdi))

        # Le SERVEUR valide les displayids : les mêmes entrées chez lui.
        for nom in ("CreatureModelData.dbc", "CreatureDisplayInfo.dbc"):
            p = os.path.join(DBC_SERVEUR_DIR, nom)
            if not os.path.exists(p):
                raise SystemExit("DBC serveur absent : %s" % p)
            if not os.path.exists(p + ".avant_dk"):
                shutil.copy2(p, p + ".avant_dk")
        p_cmd = os.path.join(DBC_SERVEUR_DIR, "CreatureModelData.dbc")
        p_cdi = os.path.join(DBC_SERVEUR_DIR, "CreatureDisplayInfo.dbc")
        with io.open(p_cmd, "rb") as f:
            s_cmd = Dbc(f.read())
        with io.open(p_cdi, "rb") as f:
            s_cdi = Dbc(f.read())
        pose_goule(s_cmd, s_cdi)
        with io.open(p_cmd, "wb") as f:
            f.write(s_cmd.octets())
        with io.open(p_cdi, "wb") as f:
            f.write(s_cdi.octets())
        print("Goule (serveur) : modèle %d et apparences %r posés dans"
              " Data%sdbc" % (MODELE_GOULE, [n for _v, n in DISPLAYS_GOULE], BS))
    finally:
        dll.SFileCloseArchive(h)


if __name__ == "__main__":
    main()
