# -*- coding: utf-8 -*-
r"""L'art du chaman — Bourrasque (8600060) et Séisme (8600061).

Sources exportées le 2026-09-02 :
  - Bourrasque : l'icône `spell_druid_astralstorm` et le son
    `spell_dru_windburst05` ;
  - Séisme : l'icône `spell_shaman_earthquake`, le son
    `earthquakecamerashake` et le modèle `shaman_earthquake` (six mille
    sommets à plat, trois temps — Stand, Hold, Decay — la forme même d'une
    zone qui s'ouvre, tremble et s'apaise).

Le Séisme est une ZONE PERSISTANTE : son modèle est porté par le champ 25
du visuel, le kit de zone, qui vit aussi longtemps qu'elle. La Bourrasque
garde le visuel natif du loup fantomatique (311) et n'y ajoute que son son.

    python gen_visuel_chaman.py   (JEU FERMÉ requis : écrit dans patch-z)
"""
import ctypes as C
import io
import os
import re
import shutil
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
from gen_visuel_aube import Dbc, stormlib, lit, ecrit
from gen_visuel_voleur import lit_effectif, texte

DBC_SERVEUR_DIR = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc"

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_chaman")

# --- Séisme ----------------------------------------------------------------
MODELE_SEISME = "spells" + BS + "shaman_earthquake.mdx"
FICHIER_M2_SEISME = "shaman_earthquake.m2"
FICHIER_SKIN_SEISME = "shaman_earthquake00.skin"
# Le maillage porte 1,27 m de rayon, la zone du sort en fait 7 : le facteur
# est donc d'un peu plus de cinq.
ECHELLE_SEISME = 5.5
EFFET_SEISME = 8200231
ICONE_SEISME = 8068
NOM_ICONE_SEISME = "spell_shaman_earthquake"
SON_SEISME = 990118
FICHIER_SON_SEISME = "earthquake_cast.wav"
KIT_SEISME_LANCER = 30070    # le son, au lancement
KIT_SEISME_ZONE = 30071      # le modèle, tant que la zone tremble
VISUEL_SEISME = 30070

# --- Bourrasque ------------------------------------------------------------
ICONE_BOURRASQUE = 8069
NOM_ICONE_BOURRASQUE = "spell_druid_astralstorm"
SON_BOURRASQUE = 990119
FICHIER_SON_BOURRASQUE = "bourrasque_cast.wav"
KIT_BOURRASQUE_SON = 30072
VISUEL_BOURRASQUE = 30072
# Le visuel natif du loup fantomatique, dont la Bourrasque se sert déjà :
# on le clone pour lui greffer notre son sans rien perdre de son vent.
GABARIT_VISUEL_BOURRASQUE = 311

# --- Totem de lien d'esprit (8600063, montage du 2026-09-03) ----------------
# DEUX effets ont été exportés et sont montés TOUS LES DEUX, pour choisir en
# jeu. Ils ne diffèrent pas par le style mais par l'ÉCHELLE, relevée sur leur
# boîte englobante :
#   - `shaman_spiritlink`            10 émetteurs, rayon 4,8 m — compact, à
#                                    l'échelle du totem lui-même ;
#   - `shaman_spiritlink_state_base`  7 émetteurs, rayon 21 m — vaste, il
#                                    couvre toute la zone d'effet.
# Les deux bouclent sur 1 167 ms, donc ils tiennent les 10 secondes du sort.
# Pour changer, il suffit de pointer `visuel=` du sort 8600063 (sorts_classes)
# sur l'autre identifiant, puis de relancer gen_sorts_classes.py --deploy :
# aucune recompilation serveur, c'est du Spell.dbc.
MODELE_LIEN = "spells" + BS + "shaman_spiritlink.mdx"
MODELE_LIEN_ZONE = "spells" + BS + "shaman_spiritlink_state_base.mdx"
FICHIERS_LIEN = ("shaman_spiritlink.m2", "shaman_spiritlink00.skin",
                 "shaman_spiritlink_state_base.m2",
                 "shaman_spiritlink_state_base00.skin")
# L'ECHELLE DERIVE DU RAYON, pour que les deux ne divergent plus : le modele
# vaste mesure 12,3 m de demi-largeur à l'échelle 1 (releve sur sa boite
# englobante apres conversion). RAYON_LIEN doit rester egal a LIEN_RAYON dans
# SpherierSorts.cpp — c'est la seule valeur a changer si la zone bouge.
RAYON_LIEN = 7.0
# RELEVE EN JEU (2026-09-03), et c'est ce qui compte : a l'echelle 1 le modele
# couvre 6,15 m de RAYON. Sa boite englobante annonce 12,3 m de demi-largeur —
# soit exactement le double : la boite enferme la course maximale des
# particules, pas le halo visible. S'y fier avait donne un effet deux fois
# trop petit.
RAYON_MODELE_LIEN = 6.15
ECHELLE_LIEN_ZONE = RAYON_LIEN / RAYON_MODELE_LIEN
EFFET_LIEN = 8200232          # le compact
EFFET_LIEN_ZONE = 8200233     # le vaste
KIT_LIEN = 30075
KIT_LIEN_ZONE = 30076
VISUEL_LIEN = 30075           # porteur : effet compact
VISUEL_LIEN_ZONE = 30076      # porteur : effet vaste  <- celui du totem aujourd'hui
VISUEL_LIEN_SORT = 30078      # le sort lui-meme : le son du lancement, rien d'autre
ICONE_LIEN = 8071
NOM_ICONE_LIEN = "spell_shaman_spiritlink"
SON_LIEN = 990121
FICHIER_SON_LIEN = "lien_esprit_cast.wav"
KIT_LIEN_SON = 30077          # le son, greffé au lancement des deux visuels

# --- Ascendance (8600062, montage du 2026-09-02) ---------------------------
# Le modèle d'ascendant remplace celui du chaman le temps du bienfait. Il
# vit dans `creature\shamanascendant_energetic\`, à sa place naturelle : ses
# 55 fichiers d'ANIMATION EXTERNES (.anim) et ses trois textures de variante
# doivent être posés À CÔTÉ de lui, le client les y cherche par nom.
# Le nommage exporté — `Modele0060-00.anim` — est exactement celui de 3.3.5
# (relevé sur les 10 000 .anim des archives natives) : rien à renommer.
DOSSIER_ASCENDANT = "creature" + BS + "shamanascendant_energetic"
# BISSECTION DU 2026-09-02 : l'apparence pointée sur un modèle NATIF connu
# bon — la goule du Norfendre — n'a pas planté, là où le modèle rétroporté
# tombait à chaque fois. Le changement d'apparence sur un joueur est donc
# innocent, et le défaut était bien dans le modèle : voir
# `neutralise_sequences_impossibles`. L'interrupteur est laissé en place,
# éteint, pour pouvoir refaire l'expérience sans rien réécrire.
# 2026-09-02, 23 h 50 — CAUSE ÉTABLIE au point d'arrêt matériel : le client
# recopie `M2SkinSection.boneCount` matrices d'os (12 flottants chacune) dans un
# tampon STATIQUE de 0x00C5F1D8 à 0x00C5FFE8, soit 3600 octets = 75 matrices,
# SANS aucun contrôle de borne (fonction 0x00829C00, écriture en 0x00829D6C).
# L'ascendant déclare 107 os par section : les 32 matrices en trop débordent sur
# les descripteurs de constantes de nuanceur en 0x00C60240, et le premier modèle
# animé dessiné ensuite tombe en erreur 132. Aucun réglage d'en-tête ne peut y
# changer quoi que ce soit : il faut que CHAQUE section tienne sous 75 os.
# En attendant, l'apparence repointe sur un modèle natif (décision du 2026-09-02).
BISSECTION_MODELE_NATIF = False
MODELE_ASCENDANT = ("Creature" + BS + "NorthrendGhoul" + BS
                    + "NorthrendGhoul.mdx" if BISSECTION_MODELE_NATIF
                    else DOSSIER_ASCENDANT + BS
                    + "shamanascendant_energetic.mdx")
FICHIER_M2_ASCENDANT = "shamanascendant_energetic.m2"
FICHIER_SKIN_ASCENDANT = "shamanascendant_energetic00.skin"
# Les trois emplacements REMPLAÇABLES du modèle (textures de type 11, 12 et
# 13) : c'est ainsi que WoW fait ses variantes d'apparence, et c'est
# CreatureDisplayInfo qui les nomme.
# UNE LIGNE PAR COULEUR : identifiant d'apparence -> les trois textures
# remplaçables, DANS L'ORDRE DES TYPES 11, 12, 13 (voir plus bas : ce n'est
# pas l'ordre des index de texture du M2). Le .m2, le .skin et les .anim sont
# communs à toutes les couleurs ; seules ces trois BLP changent, et il suffit
# de les déposer dans le dossier du modèle pour qu'elles soient injectées.
# Le tirage au sort est côté serveur : ASCENDANCE_FORMES dans SpherierSorts.cpp
# doit lister les mêmes identifiants.
VARIANTES_ASCENDANT = (
    {802120: ("NorthrendGhoul01", "", "")} if BISSECTION_MODELE_NATIF else {
        802120: ("shamanascendant_energetic_6118992",
                 "shamanascendant_energetic_6118990",
                 "shamanascendant_energetic_6118991"),
        802121: ("shamanascendant_energetic_6118995",
                 "shamanascendant_energetic_6118993",
                 "shamanascendant_energetic_6118994"),
        802122: ("shamanascendant_energetic_6118998",
                 "shamanascendant_energetic_6118996",
                 "shamanascendant_energetic_6118997"),
    })
# --- Réglages de rendu, tous validés en jeu le 2026-09-03 -------------------
# Les groupes 1 (variantes 101/102) et 2 (201/203) : `CreatureGeosetData` porte
# un quartet par groupe et 0 vaut « variante x00 », que ce modèle n'a pas — le
# renseigner ne montrait rien. On promeut donc les sections retenues dans le
# geoset 0, dessiné sans condition ; les concurrentes restent muettes.
GEOSETS_ASCENDANT = 0
GEOSETS_RETENUS = (101, 201)
# La crinière (section 1). Ses deux étages échantillonnent la même texture
# d'énergie ; la paire d'origine [1, 1] = `Mod_Mod` multiplie AUSSI les alphas
# (0,79 x 0,32 = 0,25), sous le seuil du test `AlphaKey` : toutes les lames
# disparaissaient. `Mod_Opaque` (1, 0) donne EXACTEMENT la même couleur,
# t0 x t1, avec l'alpha du seul premier étage. Matériaux inchangés.
SECTIONS_FLUX = (1,)                  # pour combinaison_flux
COMBINAISON_FLUX = (1, 0)             # Mod_Opaque
MATERIAUX_FONDUS = {}                 # index -> (drapeaux, mode de fusion)
# Les UV1 balaient tout l'atlas, colonnes NOIRES comprises (u 0,56-0,75), que
# `Mod_Opaque` multiplie dans la couleur — plaques noires en travers des lames.
# La bande u 0,750-0,840 est la seule large plage sans aucun noir : luminance
# minimale 157, moyenne 212/255 (modulation douce x0,83), raccord vertical
# 1/255 donc le défilement en V reste continu. Seuls les UV1 de la section 1
# sont ramenés dedans ; les UV0 des lames ne bougent pas.
BANDE_FLUX = (0.75, 0.84)
# Essais conservés mais neutralisés : ils resserviront pour un autre modèle.
SECTIONS_MONO_TEXTURE = ()            # mono_texture
SECTIONS_PASSE_FLUX = ()              # superpose_flux
MATERIAU_FLUX = 5                     # 0x15 : sans éclairage, deux faces, fondu
MATERIAU_DES_SECTIONS = {}            # section -> index de matériau
MODELE_DATA_ASCENDANT = 802120
DISPLAYS_ASCENDANT = tuple(sorted(VARIANTES_ASCENDANT))
ICONE_ASCENDANCE = 8070
NOM_ICONE_ASCENDANCE = "inv121_ability_shaman_ascendance_fire"
SON_ASCENDANCE = 990120
FICHIER_SON_ASCENDANCE = "ascendance_cast.wav"
KIT_ASCENDANCE_LANCER = 30074
VISUEL_ASCENDANCE = 30074
GABARIT_MODELE_CREATURE = 892   # le Poulet, patron du chantier

GABARIT_SON = 3011           # « un coup », le gabarit du chantier

# --- La chute du Séisme (8600068) ------------------------------------------
# Le kit d'ÉTAT natif des étourdissements — animation 14 et le modèle
# `StunSwirl_State_Head`, les étoiles qui tournent au-dessus de la tête. Il
# est partagé par le Marteau de la justice, le Coup de rein et le Coup bas
# (relevé le 2026-09-02) ; on le reprend tel quel, porté par un visuel à
# nous qui ne garde QUE lui : ni incantation ni impact, la chute est
# déclenchée par le script et n'a rien d'autre à montrer.
KIT_ETAT_ETOURDI = 349
VISUEL_CHUTE = 30073


def rallonge_transparence(donnees, donnees_skin):
    """La table de transparence, portée à ce que les lots réclament. Une
    entrée manquante, c'est une lecture hors bornes — maillage dégénéré ou
    erreur 132. La table est ajoutée en fin de fichier et l'en-tête
    repointé : rien d'existant ne bouge, et l'outil est idempotent."""
    m2 = bytearray(donnees)
    nb, ob = struct.unpack_from("<2I", donnees_skin, 36)
    besoin = 0
    for i in range(nb):
        o = ob + i * 24
        n = struct.unpack_from("<H", donnees_skin, o + 14)[0]
        besoin = max(besoin,
                     struct.unpack_from("<H", donnees_skin, o + 20)[0] + n)
    na, oa = struct.unpack_from("<2I", m2, 0x90)
    if na >= besoin:
        return bytes(m2)
    table = list(struct.unpack_from("<%dh" % na, m2, oa)) if na else []
    while len(table) < besoin:
        # La deuxième couche partage l'alpha de la première.
        table.append(table[-1] if table else 0)
    struct.pack_into("<2I", m2, 0x90, besoin, len(m2))
    m2.extend(struct.pack("<%dh" % besoin, *table))
    print("table de transparence portée à %d entrée(s) %s" % (besoin, table))
    return bytes(m2)


def anims_du_client():
    """Les identifiants d'animation que le client 3.3.5 sait nommer."""
    donnees = io.open(os.path.join(DBC_SERVEUR_DIR, "AnimationData.dbc"),
                      "rb").read()
    nrec, _nchamp, rsize, _ssize = struct.unpack_from("<4I", donnees, 4)
    return set(struct.unpack_from("<I", donnees, 20 + i * rsize)[0]
               for i in range(nrec))


def neutralise_sequences_impossibles(donnees, dossier):
    """Rend INATTEIGNABLES les séquences que le client 3.3.5 ne peut pas lire.

    LA CAUSE DU PLANTAGE, établie le 2026-09-02 par bissection : l'apparence
    pointée sur un modèle natif ne tombe plus, le modèle rétroporté tombe.
    Deux défauts, tous deux mortels au CHARGEMENT du modèle :

    1. Sur les 358 séquences, 201 portent un identifiant d'animation ABSENT
       d'`AnimationData.dbc` — qui s'arrête à 505, quand le modèle va jusqu'à
       1786. Le client interroge cette table pour chaque séquence au
       chargement ; enregistrement introuvable, pointeur nul, violation
       d'accès en lecture. Ce sont les animations de combat des extensions
       postérieures : rien, dans 3.3.5, ne saura jamais les réclamer.

    2. Les 62 séquences EXTERNES sont irrécupérables : les 55 fichiers .anim
       fournis commencent par `AFM2`, l'en-tête à blocs des versions
       modernes, là où 3.3.5 attend des données brutes ; et les 7 autres
       n'ont pas été exportés du tout. Ce sont les émotes, les poses assises,
       le sommeil, la furtivité et la pêche — celles qu'un joueur déclenche
       lui-même, donc le plus sûr moyen de tomber en jeu.

    On ne retire rien du fichier : on rend ces séquences introuvables. Leur
    identifiant est réécrit sur un REFUGE — un identifiant que la dbc connaît
    et que le modèle n'emploie pas —, la table de correspondance qui menait à
    elles est coupée, et les chaînes de variantes et d'alias qui y menaient
    depuis les séquences saines sont défaites. Le client ne peut plus les
    nommer, donc plus les jouer, donc plus lire ce qu'elles pointent.

    Restent les 296 séquences embarquées et connues : la station debout, la
    marche, la course, les attaques, la mort — tout ce que la silhouette doit
    savoir faire."""
    m2 = bytearray(donnees)
    n, ofs = struct.unpack_from("<2I", m2, 0x1C)
    nl, ol = struct.unpack_from("<2I", m2, 0x24)
    connus = anims_du_client()
    fournis = set()
    for f in os.listdir(dossier):
        m = re.match(r".*?(\d{4})-(\d{2})\.anim$", f)
        if m:
            fournis.add((int(m.group(1)), int(m.group(2))))

    condamnees, employes = set(), set()
    inconnues = externes = rendues = 0
    for i in range(n):
        anim, sous = struct.unpack_from("<2H", m2, ofs + i * 64)
        drapeaux = struct.unpack_from("<I", m2, ofs + i * 64 + 12)[0]
        employes.add(anim)
        if anim not in connus:
            condamnees.add(i)
            inconnues += 1
        elif not (drapeaux & 0x20):
            # Une sequence EXTERNE est recuperable si son .anim est fourni :
            # le format moderne est un simple chunk `AFM2` — huit octets
            # d'en-tete puis EXACTEMENT la disposition attendue par 3.3.5.
            # Verifie le 2026-09-03 sur les 46 fichiers presents : tous les
            # decalages du M2 tombent dans la charge utile et les horodatages
            # finissent sur la duree declaree. Elles restent donc externes,
            # leurs pistes sont intactes, et `anims_convertis` injecte la
            # charge utile sous le nom que le client cherche.
            if (anim, sous) in fournis:
                rendues += 1
                continue
            condamnees.add(i)
            externes += 1
    if not condamnees:
        return bytes(m2)

    libres = sorted(a for a in connus if a not in employes)
    if not libres:
        raise SystemExit("aucun identifiant d'animation libre pour le refuge")
    refuge = max([a for a in libres if a < nl] or libres)

    # Les condamnées : identifiant de refuge, données déclarées embarquées
    # (le client ne cherchera plus de fichier), ni variante ni alias.
    for i in sorted(condamnees):
        o = ofs + i * 64
        drapeaux = struct.unpack_from("<I", m2, o + 12)[0]
        struct.pack_into("<2H", m2, o, refuge, i)
        struct.pack_into("<I", m2, o + 12, (drapeaux | 0x20) & ~0x40)
        struct.pack_into("<hH", m2, o + 60, -1, i)

    # Les saines : on défait ce qui menait encore aux condamnées.
    chaines = 0
    for i in range(n):
        if i in condamnees:
            continue
        o = ofs + i * 64
        drapeaux = struct.unpack_from("<I", m2, o + 12)[0]
        if struct.unpack_from("<h", m2, o + 60)[0] in condamnees:
            struct.pack_into("<h", m2, o + 60, -1)
            chaines += 1
        if (drapeaux & 0x40) and struct.unpack_from("<H", m2,
                                                    o + 62)[0] in condamnees:
            struct.pack_into("<I", m2, o + 12, (drapeaux | 0x20) & ~0x40)
            chaines += 1

    # La table de correspondance : plus une seule entrée vers une condamnée.
    coupees = 0
    if nl:
        table = list(struct.unpack_from("<%dh" % nl, m2, ol))
        for a in range(nl):
            if table[a] >= 0 and table[a] in condamnees:
                table[a] = -1
                coupees += 1
        if refuge < nl:
            table[refuge] = -1
        struct.pack_into("<%dh" % nl, m2, ol, *table)

    # Rendre l'identifiant introuvable NE SUFFIT PAS. Chaque piste du fichier
    # porte un sous-tableau PAR SÉQUENCE ; ceux des condamnées pointent
    # toujours vers leurs données. Pour les 53 externes ce sont des décalages
    # relatifs au fichier .anim (dont zéro) : déclarées embarquées, le client
    # les lirait comme des décalages dans le M2 — l'en-tête relu comme des
    # clés d'animation. On les vide, sur TOUTES les pistes du fichier.
    pistes = []
    nb_os, ob_os = struct.unpack_from("<2I", m2, 0x2C)
    for i in range(nb_os):
        pistes += [ob_os + i * 88 + k for k in (16, 36, 56)]
    nb_c, ob_c = struct.unpack_from("<2I", m2, 0x48)          # couleurs
    for i in range(nb_c):
        pistes += [ob_c + i * 40, ob_c + i * 40 + 20]
    nb_t, ob_t = struct.unpack_from("<2I", m2, 0x58)          # transparences
    pistes += [ob_t + i * 20 for i in range(nb_t)]
    nb_u, ob_u = struct.unpack_from("<2I", m2, 0x60)          # transformations UV
    for i in range(nb_u):
        pistes += [ob_u + i * 60 + k for k in (0, 20, 40)]
    nb_a, ob_a = struct.unpack_from("<2I", m2, 0xF0)          # attaches
    pistes += [ob_a + i * 40 + 20 for i in range(nb_a)]
    videes = 0
    for o in pistes:
        for champ in (4, 12):                                 # horodatages, valeurs
            nsub, osub = struct.unpack_from("<2I", m2, o + champ)
            if nsub != n or not osub:      # piste à séquence globale : un seul
                continue                   # sous-tableau, aucune séquence visée
            for i in condamnees:
                if struct.unpack_from("<I", m2, osub + i * 8)[0]:
                    struct.pack_into("<2I", m2, osub + i * 8, 0, 0)
                    videes += 1
    print("sous-tableaux de piste vidés : %d sur %d piste(s)" % (videes, len(pistes)))

    print("séquences : %d conservées sur %d — %d rendues inatteignables "
          "(%d au nom inconnu de la dbc, %d sans fichier .anim), dont "
          "%d séquences externes CONSERVÉES ; refuge %d, %d entrée(s) de "
          "correspondance coupée(s), %d chaîne(s) défaite(s)"
          % (n - len(condamnees), n, len(condamnees), inconnues, externes,
             rendues, refuge, coupees, chaines))
    return bytes(m2)


def repare_bonecountmax(donnees_skin):
    """Renseigne `boneCountMax`, laissé à ZÉRO par l'export.

    LA CAUSE DU PLANTAGE (2026-09-02, erreur 132, violation d'accès en
    lecture au même point à chaque fois) : le client dimensionne sur ce
    champ le tampon des matrices d'os, puis y écrit une entrée par os de la
    section en cours. À zéro, le tampon est vide et l'écriture sort de la
    mémoire allouée. Les sous-maillages de l'ascendant emploient jusqu'à
    107 os ; un skin natif comparable — la goule du Norfendre — annonce 53
    pour 52 os employés, soit le maximum plus un. On applique la même
    règle."""
    skin = bytearray(donnees_skin)
    ns, ofs = struct.unpack_from("<2I", skin, 28)
    pire = 0
    for i in range(ns):
        pire = max(pire, struct.unpack_from("<10H", skin, ofs + i * 48)[6])
    avant = struct.unpack_from("<I", skin, 44)[0]
    if avant > pire:
        return bytes(skin)
    struct.pack_into("<I", skin, 44, pire + 1)
    print("boneCountMax : %d -> %d (os max par section : %d)"
          % (avant, pire + 1, pire))
    return bytes(skin)


def degraisse_modele(donnees):
    """Vide les blocs DÉCORATIFS du modèle : émetteurs de particules,
    événements et caméras.

    Deuxième piste du plantage (2026-09-02) : ce sont les trois blocs dont
    la structure a le plus changé entre la version d'origine du modèle et
    3.3.5, et aucun n'est nécessaire à la silhouette ni à ses animations.
    Les vider ne coûte que les étincelles ; le squelette, la géométrie et
    les 55 séquences externes restent intacts."""
    m2 = bytearray(donnees)
    retires = []
    for nom, off in (("émetteurs", 0x128), ("événements", 0x100),
                     ("caméras", 0x110), ("recherche de caméra", 0x118)):
        n = struct.unpack_from("<I", m2, off)[0]
        if n:
            struct.pack_into("<2I", m2, off, 0, 0)
            retires.append("%s : %d" % (nom, n))
    if retires:
        print("blocs décoratifs vidés — %s" % ", ".join(retires))
    return bytes(m2)


# Le gabarit du client, RELEVÉ le 2026-09-02 sur 2993 modèles des archives
# d'origine (common, expansion, lichking, patch 1 à 3) : au-delà, on sort de
# ce que le client sait tenir.
ATTACHE_MAX_335 = 49    # identifiant d'attache le plus grand jamais employé
OS_CLES_335 = 27        # taille de la table d'os-clés (31 au plus, 27 partout)
DRAPEAUX_335 = 0x1F     # union de TOUS les bits de drapeaux globaux rencontrés


def ramene_au_gabarit_335(donnees):
    """Ramène le modèle dans l'enveloppe que le client 3.3.5 sait tenir.

    LA CAUSE DU PLANTAGE (2026-09-02). L'instruction fautive, toujours la
    même, est `cmp [edx + ecx*4 + 0x2870], esi` : une table à emplacement
    fixe dans un gros objet, indexée par un IDENTIFIANT lu dans une
    structure. L'adresse lue n'était jamais nulle mais toujours un peu
    au-delà d'un tampon — la signature d'un index hors bornes.

    Le modèle rétroporté sort du gabarit sur trois points, chacun mesuré
    contre 2993 modèles d'origine :

      - il déclare 45 ATTACHES allant jusqu'au numéro 74, quand le client
        n'en a jamais connu au-delà de 49. C'est le point mortel : pour
        habiller un JOUEUR, le client parcourt les attaches du modèle et
        s'en sert pour indexer ses propres tables d'emplacements ;
      - sa table d'OS-CLÉS compte 291 entrées, contre 31 au plus ;
      - ses DRAPEAUX GLOBAUX valent 0x212030B8, quand l'union de tous les
        bits jamais rencontrés dans 3.3.5 tient dans 0x1F.

    On coupe ce qui dépasse : les attaches au-delà de 49 sont retirées et
    leur table de correspondance refaite à la bonne taille, la table
    d'os-clés est ramenée à 27 entrées, les drapeaux masqués. Les attaches
    retirées sont celles des extensions postérieures — rien de ce qu'un
    personnage de 3.3.5 porte ne s'y accroche."""
    m2 = bytearray(donnees)
    corrections = []

    drapeaux = struct.unpack_from("<I", m2, 0x10)[0]
    if drapeaux & ~DRAPEAUX_335:
        struct.pack_into("<I", m2, 0x10, drapeaux & DRAPEAUX_335)
        corrections.append("drapeaux 0x%08X -> 0x%08X"
                           % (drapeaux, drapeaux & DRAPEAUX_335))

    nk = struct.unpack_from("<I", m2, 0x34)[0]
    if nk > OS_CLES_335:
        struct.pack_into("<I", m2, 0x34, OS_CLES_335)
        corrections.append("os-clés %d -> %d" % (nk, OS_CLES_335))

    na, oa = struct.unpack_from("<2I", m2, 0xF0)
    gardees = [i for i in range(na)
               if struct.unpack_from("<I", m2, oa + i * 40)[0]
               <= ATTACHE_MAX_335]
    if len(gardees) < na:
        retirees = [struct.unpack_from("<I", m2, oa + i * 40)[0]
                    for i in range(na) if i not in gardees]
        while len(m2) % 4:
            m2.append(0)
        base = len(m2)
        for i in gardees:
            m2.extend(m2[oa + i * 40:oa + i * 40 + 40])
        struct.pack_into("<2I", m2, 0xF0, len(gardees), base)
        table = [-1] * (ATTACHE_MAX_335 + 1)
        for neuf, i in enumerate(gardees):
            table[struct.unpack_from("<I", donnees, oa + i * 40)[0]] = neuf
        depart = len(m2)
        m2.extend(struct.pack("<%dh" % len(table), *table))
        struct.pack_into("<2I", m2, 0xF8, len(table), depart)
        corrections.append("attaches %d -> %d (retirées : %s), "
                           "correspondance refaite à %d entrées"
                           % (na, len(gardees),
                              ", ".join(str(x) for x in retirees), len(table)))

    if corrections:
        print("modèle ramené au gabarit 3.3.5 — %s" % " ; ".join(corrections))
    return bytes(m2)


# LA limite du client 3.3.5, MESURÉE (2026-09-02, point d'arrêt matériel en
# écriture) : la palette de matrices d'os est un tampon STATIQUE de wow.exe,
# 0x00C5F1D8 à 0x00C5FFE8, soit 3600 octets = 75 matrices de 12 flottants. La
# boucle qui la remplit (0x00829D02..0x00829D93) recopie `boneCount` matrices
# de la section EN COURS, sans le moindre contrôle de borne. Au-delà de 75, elle
# écrit dans les descripteurs de constantes de nuanceur qui suivent, et le
# premier modèle animé dessiné ensuite tombe en erreur 132.
LIMITE_OS_SECTION = 75


def limite_os_par_section(donnees, donnees_skin, limite=LIMITE_OS_SECTION):
    """Ramène chaque section sous la limite d'os du client.

    L'export moderne donne à TOUTES les sections la table d'os entière
    (boneCount = 107, boneComboIndex = 0) alors qu'aucune n'en emploie autant.
    On donne à chacune sa propre tranche, réduite aux os qu'elle emploie
    vraiment ; si une section en emploie tout de même plus que la limite, ses
    os les moins portants sont repliés sur leur PREMIER ANCÊTRE déjà présent
    (les os à poids nul, eux, se replient n'importe où : ils ne déforment rien).

    Le client écrase `bone_indices` de chaque sommet avec le tableau de la skin
    (relevé en 0x0083641B) : la renumérotation ne touche donc que la skin, et la
    table `bone_combos` du M2, réécrite en fin de fichier."""
    m2 = bytearray(donnees)
    sk = bytearray(donnees_skin)
    nsec, osec = struct.unpack_from("<2I", sk, 28)
    _nbi, obi = struct.unpack_from("<2I", sk, 20)     # 4 indices d'os par sommet
    _nix, oix = struct.unpack_from("<2I", sk, 4)      # sommet local -> sommet M2
    _nv, ov = struct.unpack_from("<2I", m2, 0x3C)
    nos, oos = struct.unpack_from("<2I", m2, 0x2C)
    ncb, ocb = struct.unpack_from("<2I", m2, 0x78)
    combos = list(struct.unpack_from("<%dH" % ncb, m2, ocb))
    parent = [struct.unpack_from("<h", m2, oos + i * 88 + 8)[0] for i in range(nos)]
    neuf = list(combos)
    lignes = []
    for s in range(nsec):
        o = osec + s * 48
        v = struct.unpack_from("<10H", sk, o)
        vs, vc, bc, bci = v[2], v[3], v[6], v[7]
        poids = {}
        for k in range(vs, vs + vc):
            idx = struct.unpack_from("<4B", sk, obi + k * 4)
            g = struct.unpack_from("<H", sk, oix + k * 2)[0]
            w = struct.unpack_from("<4B", m2, ov + g * 48 + 12)
            for j in range(4):
                poids[idx[j]] = poids.get(idx[j], 0) + w[j]
        employes = sorted(poids)
        vers = {l: l for l in employes}
        vivants = set(employes)
        replis = 0
        if len(vivants) > limite:
            par_os = {}
            for l in employes:
                par_os.setdefault(combos[bci + l], l)
            for l in sorted(employes, key=lambda x: (poids[x], x)):
                if len(vivants) <= limite:
                    break
                if l not in vivants:
                    continue
                cible = None
                if poids[l] == 0:
                    cible = min(x for x in vivants if x != l)
                else:
                    p = parent[combos[bci + l]]
                    while p != -1 and 0 <= p < nos:
                        lp = par_os.get(p)
                        if lp is not None and lp in vivants and lp != l:
                            cible = lp
                            break
                        p = parent[p]
                if cible is None:
                    continue
                for a, b in list(vers.items()):
                    if b == l:
                        vers[a] = cible
                vivants.discard(l)
                replis += 1
        if len(vivants) > limite:
            raise SystemExit("section %d : %d os irreductibles (limite %d)"
                             % (s, len(vivants), limite))
        restants = sorted(vivants)
        place = dict((l, i) for i, l in enumerate(restants))
        base = len(neuf)
        neuf.extend(combos[bci + l] for l in restants)
        for k in range(vs, vs + vc):
            idx = struct.unpack_from("<4B", sk, obi + k * 4)
            struct.pack_into("<4B", sk, obi + k * 4,
                             *[place[vers[x]] for x in idx])
        struct.pack_into("<2H", sk, o + 12, len(restants), base)
        lignes.append("%d:%d->%d%s" % (s, bc, len(restants),
                                       "(%d replis)" % replis if replis else ""))
    while len(m2) % 4:
        m2.append(0)
    depart = len(m2)
    m2.extend(struct.pack("<%dH" % len(neuf), *neuf))
    struct.pack_into("<2I", m2, 0x78, len(neuf), depart)
    pire = max(struct.unpack_from("<10H", sk, osec + i * 48)[6]
               for i in range(nsec))
    struct.pack_into("<I", sk, 44, pire + 1)
    print("os par section ramenes sous %d : %s ; bone_combos %d -> %d entrees,"
          " boneCountMax -> %d"
          % (limite, " ".join(lignes), ncb, len(neuf), pire + 1))
    return bytes(m2), bytes(sk)


def promeut_geosets(donnees_skin, retenus=None):
    """Promeut les sections retenues dans le geoset 0 (toujours dessiné)."""
    if retenus is None:
        retenus = GEOSETS_RETENUS
    sk = bytearray(donnees_skin)
    ns, ofs = struct.unpack_from("<2I", sk, 28)
    promus, restants = [], []
    for i in range(ns):
        o = ofs + i * 48
        ident = struct.unpack_from("<H", sk, o)[0]
        if ident in retenus:
            struct.pack_into("<H", sk, o, 0)
            promus.append("%d(geoset %d)" % (i, ident))
        elif ident:
            restants.append("%d(geoset %d)" % (i, ident))
    print("sections promues en geoset 0 : %s ; laissees muettes : %s"
          % (", ".join(promus) or "aucune", ", ".join(restants) or "aucune"))
    return bytes(sk)


def mono_texture(donnees_skin, sections=None):
    """Un seul étage de texture sur les lots des sections désignées."""
    if sections is None:
        sections = SECTIONS_MONO_TEXTURE
    sk = bytearray(donnees_skin)
    nb, ob = struct.unpack_from("<2I", sk, 36)
    faits = []
    for i in range(nb):
        o = ob + i * 24
        sec = struct.unpack_from("<H", sk, o + 4)[0]
        ntex = struct.unpack_from("<H", sk, o + 14)[0]
        if sec in sections and ntex > 1:
            struct.pack_into("<H", sk, o + 14, 1)
            faits.append("lot %d (section %d) %d->1" % (i, sec, ntex))
    print("etages de texture reduits : %s" % (", ".join(faits) or "aucun"))
    return bytes(sk)


def combinaison_flux(donnees, donnees_skin, sections=None, paire=None):
    """Donne aux lots des sections désignées leur propre paire de combinaison
    (ajoutée en fin de texture_combiner_combos, table réécrite en fin de M2)."""
    if sections is None:
        sections = SECTIONS_FLUX
    if paire is None:
        paire = COMBINAISON_FLUX
    if not sections:
        return donnees, donnees_skin
    m2 = bytearray(donnees)
    sk = bytearray(donnees_skin)
    if not struct.unpack_from("<I", m2, 0x10)[0] & 0x8:
        raise SystemExit("le modele n'emploie pas texture_combiner_combos")
    n, o = struct.unpack_from("<2I", m2, 0x130)
    combos = list(struct.unpack_from("<%dH" % n, m2, o)) + list(paire)
    while len(m2) % 4:
        m2.append(0)
    depart = len(m2)
    m2.extend(struct.pack("<%dH" % len(combos), *combos))
    struct.pack_into("<2I", m2, 0x130, len(combos), depart)
    nb, ob = struct.unpack_from("<2I", sk, 36)
    faits = []
    for i in range(nb):
        b = ob + i * 24
        sec = struct.unpack_from("<H", sk, b + 4)[0]
        if sec in sections:
            struct.pack_into("<H", sk, b + 2, n)      # shader_id -> la paire ajoutee
            faits.append("lot %d (section %d)" % (i, sec))
    print("paire de combinaison %s ajoutee en %d ; lots pointes : %s"
          % (list(paire), n, ", ".join(faits) or "aucun"))
    return bytes(m2), bytes(sk)


def fond_materiaux(donnees, materiaux=None):
    """Impose drapeaux et mode de fusion aux matériaux désignés (M2Material)."""
    if materiaux is None:
        materiaux = MATERIAUX_FONDUS
    m2 = bytearray(donnees)
    n, o = struct.unpack_from("<2I", m2, 0x70)
    faits = []
    for idx, (drapeaux, fusion) in sorted(materiaux.items()):
        if idx >= n:
            raise SystemExit("materiau %d absent (%d)" % (idx, n))
        avant = struct.unpack_from("<2H", m2, o + idx * 4)
        struct.pack_into("<2H", m2, o + idx * 4, drapeaux, fusion)
        faits.append("%d : 0x%02X/%d -> 0x%02X/%d" % (idx, avant[0], avant[1], drapeaux, fusion))
    print("materiaux fondus : %s" % "; ".join(faits))
    return bytes(m2)


def materiau_des_sections(donnees_skin, table=None):
    """Impose un index de materiau aux lots des sections designees."""
    if table is None:
        table = MATERIAU_DES_SECTIONS
    sk = bytearray(donnees_skin)
    nb, ob = struct.unpack_from("<2I", sk, 36)
    faits = []
    for i in range(nb):
        b = ob + i * 24
        sec = struct.unpack_from("<H", sk, b + 4)[0]
        if sec in table:
            avant = struct.unpack_from("<H", sk, b + 10)[0]
            struct.pack_into("<H", sk, b + 10, table[sec])
            faits.append("lot %d (section %d) materiau %d -> %d" % (i, sec, avant, table[sec]))
    print("materiaux des lots : %s" % (", ".join(faits) or "aucun"))
    return bytes(sk)


def flux_dans_la_bande(donnees, donnees_skin, sections=None, bande=None):
    """Ramene les U des UV1 des sections designees dans la bande de flux."""
    if sections is None:
        sections = SECTIONS_FLUX
    if bande is None:
        bande = BANDE_FLUX
    if bande is None:
        return donnees
    m2 = bytearray(donnees)
    ns, osec = struct.unpack_from("<2I", donnees_skin, 28)
    _ni, oix = struct.unpack_from("<2I", donnees_skin, 4)
    _nv, ov = struct.unpack_from("<2I", m2, 0x3C)
    globaux = set()
    for si in range(ns):
        v = struct.unpack_from("<10H", donnees_skin, osec + si * 48)
        if si in sections:
            for k in range(v[2], v[2] + v[3]):
                globaux.add(struct.unpack_from("<H", donnees_skin, oix + k * 2)[0])
    us = [struct.unpack_from("<f", m2, ov + g * 48 + 40)[0] for g in globaux]
    umin, umax = min(us), max(us)
    etendue = (umax - umin) or 1.0
    for g in globaux:
        u = struct.unpack_from("<f", m2, ov + g * 48 + 40)[0]
        struct.pack_into("<f", m2, ov + g * 48 + 40,
                         bande[0] + (u - umin) / etendue * (bande[1] - bande[0]))
    print("UV1 de %d sommets (sections %s) : u %.2f..%.2f -> %.2f..%.2f"
          % (len(globaux), list(sections), umin, umax, bande[0], bande[1]))
    return bytes(m2)


def superpose_flux(donnees_skin, sections=None, materiau=None):
    """Ajoute, pour chaque lot des sections designees, un lot additif a une
    texture : celle et les indices du SECOND etage du lot source (texture,
    UV1, transformation UV animee), sur le materiau additif. Le tableau des
    lots est reecrit en fin de skin."""
    if sections is None:
        sections = SECTIONS_PASSE_FLUX
    if materiau is None:
        materiau = MATERIAU_FLUX
    if not sections:
        return donnees_skin
    sk = bytearray(donnees_skin)
    nb, ob = struct.unpack_from("<2I", sk, 36)
    lots = [bytes(sk[ob + i * 24:ob + i * 24 + 24]) for i in range(nb)]
    ajoutes = []
    for i, lot in enumerate(lots[:nb]):      # pas les lots ajoutes en cours de route
        (fl, prio, shader, sec, geo, couleur, mat, couche, ntex,
         tc, cc, wc, trc) = struct.unpack("<BbHHHHHHHHHHH", lot)
        if sec not in sections:
            continue
        neuf = struct.pack("<BbHHHHHHHHHHH", 0, prio, 0, sec, geo, couleur,
                           materiau, couche + 1, 1,
                           tc + 1, cc + 1, wc + 1, trc + 1)
        lots.append(neuf)
        ajoutes.append("lot %d (section %d) -> lot %d" % (i, sec, len(lots) - 1))
    while len(sk) % 4:
        sk.append(0)
    depart = len(sk)
    for lot in lots:
        sk.extend(lot)
    struct.pack_into("<2I", sk, 36, len(lots), depart)
    print("lots additifs de flux : %s (%d lots au total)"
          % (", ".join(ajoutes) or "aucun", len(lots)))
    return bytes(sk)


def anims_convertis(dossier):
    """Les .anim du modele, en-tete de chunk `AFM2` retire.

    Le format moderne enveloppe la charge utile dans un unique chunk : quatre
    octets de signature, quatre de taille, puis les donnees telles que 3.3.5
    les attend — les decalages inscrits dans le M2 sont relatifs a cette
    charge. Retirer les huit octets suffit donc a rendre les fichiers
    lisibles, et le nommage d'export (`Modele0060-00.anim`) est deja celui
    que le client cherche."""
    convertis = {}
    for nom in sorted(os.listdir(dossier)):
        if not nom.endswith(".anim"):
            continue
        brut = io.open(os.path.join(dossier, nom), "rb").read()
        if brut[:4] == b"AFM2":
            taille = struct.unpack_from("<I", brut, 4)[0]
            convertis[nom] = brut[8:8 + taille]
    if convertis:
        print("fichiers .anim convertis (en-tete AFM2 retire) : %d"
              % len(convertis))
    return convertis


def pose_ascendant(cmd, cdi):
    """Le modèle et l'apparence de l'ascendant : clone du Poulet — le
    patron du chantier — dont on ne change que le chemin, l'échelle et les
    trois textures de variante."""
    if cmd.nfield != 28 or cdi.nfield != 16:
        raise SystemExit("CreatureModelData/DisplayInfo : champs inattendus")
    poulet = None
    for i in range(cmd.nrec):
        off = i * cmd.rsize
        chemin = texte(cmd, struct.unpack_from("<I", cmd.enr,
                                               off + 8)[0]).lower()
        if chemin.endswith("chicken.mdx") or chemin.endswith("chicken.m2"):
            poulet = [struct.unpack_from("<I", cmd.enr, off + k * 4)[0]
                      for k in range(28)]
            break
    if poulet is None:
        raise SystemExit("gabarit Chicken absent de CreatureModelData")

    cmd.retire({MODELE_DATA_ASCENDANT})
    modele = list(poulet)
    modele[0] = MODELE_DATA_ASCENDANT
    modele[2] = cmd.chaine(MODELE_ASCENDANT)
    modele[4] = struct.unpack("<I", struct.pack("<f", 1.0))[0]
    for k in range(5, 14):
        modele[k] = 0
    cmd.pose(modele)

    cdi.retire(set(DISPLAYS_ASCENDANT))
    for ident in DISPLAYS_ASCENDANT:
        textures = VARIANTES_ASCENDANT[ident]
        v = [ident, MODELE_DATA_ASCENDANT, 0, 0,
             struct.unpack("<I", struct.pack("<f", 1.0))[0], 255,
             cdi.chaine(textures[0]),
             cdi.chaine(textures[1]),
             cdi.chaine(textures[2]),
             0, 0, 0, 0, 0, GEOSETS_ASCENDANT, 0]
        cdi.pose(v)


def fichiers_a_injecter():
    paires = []
    for nom in sorted(os.listdir(os.path.join(ART, "spells"))):
        if nom.endswith((".m2", ".skin", ".blp")):
            paires.append((os.path.join(ART, "spells", nom),
                           "spells" + BS + nom))
    # L'ascendant : modèle, skin, animations externes et textures, tous à
    # côté les uns des autres. Les textures que le M2 nomme lui-même sont
    # inscrites en « spells\ » (c'est ce que fait inscrit_textures) et vont
    # donc AUSSI dans spells\ ; celles des trois emplacements remplaçables,
    # nommées par CreatureDisplayInfo, restent ici.
    # Les 55 fichiers .anim ne sont PAS injectés : ils sont au format moderne
    # `AFM2`, illisible par 3.3.5, et les séquences qui s'en servaient ont été
    # rendues inatteignables. Les rafraîchir n'ajouterait que onze mégaoctets
    # de lest, sur des données que plus rien ne peut ouvrir.
    dossier = os.path.join(ART, "creature", "shamanascendant_energetic")
    for nom in sorted(os.listdir(dossier)):
        if nom.endswith(".anim"):
            paires.append((os.path.join(dossier, nom),
                           DOSSIER_ASCENDANT + BS + nom))
        elif nom.endswith((".m2", ".skin")):
            paires.append((os.path.join(dossier, nom),
                           DOSSIER_ASCENDANT + BS + nom))
        elif nom.endswith(".blp"):
            paires.append((os.path.join(dossier, nom),
                           DOSSIER_ASCENDANT + BS + nom))
            paires.append((os.path.join(dossier, nom), "spells" + BS + nom))
    for nom_icone in (NOM_ICONE_SEISME, NOM_ICONE_BOURRASQUE,
                      NOM_ICONE_ASCENDANCE, NOM_ICONE_LIEN):
        paires.append((os.path.join(ART, "interface", "icons",
                                    nom_icone + ".blp"),
                       "Interface" + BS + "Icons" + BS + nom_icone + ".blp"))
    for nom in sorted(os.listdir(os.path.join(ART, "sound", "spells"))):
        if nom.endswith(".wav"):
            paires.append((os.path.join(ART, "sound", "spells", nom),
                           "Sound" + BS + "Spells" + BS + nom))
    return paires


def main():
    sauvegarde = G.ARCHIVE + ".avant_art_chaman"
    if not os.path.exists(sauvegarde):
        print("sauvegarde de l'archive (une fois) : %s" % sauvegarde)
        shutil.copy2(G.ARCHIVE, sauvegarde)

    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        # La table de transparence de l'ascendant est trop courte à l'export.
        dossier = os.path.join(ART, "creature", "shamanascendant_energetic")
        # GARDE-FOU. Les fichiers de ce dossier sont CONVERTIS en MD20 v264 ;
        # un export brut de wow.export est un M2 moderne chunké que toute la
        # chaîne lirait de travers. Une recopie accidentelle s'arrête ici.
        entete = io.open(os.path.join(dossier, FICHIER_M2_ASCENDANT),
                         "rb").read(8)
        if entete[:4] != b"MD20" or struct.unpack_from("<I", entete, 4)[0] != 264:
            raise SystemExit(
                "%s n'est pas un MD20 v264 (lu : %r v%d) — le dossier a-t-il "
                "recu un export brut ? Seuls les .blp doivent y etre recopies."
                % (FICHIER_M2_ASCENDANT, entete[:4],
                   struct.unpack_from("<I", entete, 4)[0]))
        skin_asc = repare_bonecountmax(
            io.open(os.path.join(dossier, FICHIER_SKIN_ASCENDANT),
                    "rb").read())
        ascendant = rallonge_transparence(
            io.open(os.path.join(dossier, FICHIER_M2_ASCENDANT), "rb").read(),
            skin_asc)
        ascendant = neutralise_sequences_impossibles(ascendant, dossier)
        ascendant = degraisse_modele(ascendant)
        ascendant = ramene_au_gabarit_335(ascendant)
        ascendant, skin_asc = limite_os_par_section(ascendant, skin_asc)
        skin_asc = promeut_geosets(skin_asc)
        skin_asc = mono_texture(skin_asc)
        ascendant, skin_asc = combinaison_flux(ascendant, skin_asc)
        ascendant = fond_materiaux(ascendant)
        skin_asc = materiau_des_sections(skin_asc)
        ascendant = flux_dans_la_bande(ascendant, skin_asc)
        skin_asc = superpose_flux(skin_asc)
        prepares = {DOSSIER_ASCENDANT + BS + FICHIER_M2_ASCENDANT: ascendant,
                    DOSSIER_ASCENDANT + BS + FICHIER_SKIN_ASCENDANT: skin_asc}
        for nom_anim, charge in anims_convertis(dossier).items():
            prepares[DOSSIER_ASCENDANT + BS + nom_anim] = charge

        # Le Séisme porte LE MÊME défaut que l'ascendant : ses skins sortent
        # de l'export avec boneCountMax à ZÉRO alors que ses sections
        # emploient jusqu'à 101 os (voir repare_bonecountmax — le tampon des
        # matrices d'os est dimensionné sur ce champ, à zéro l'écriture sort
        # de la mémoire allouée). Le modèle déclare QUATRE niveaux de détail :
        # les quatre .skin sont injectés, les quatre doivent être réparés.
        dossier_sorts = os.path.join(ART, "spells")
        for nom in sorted(os.listdir(dossier_sorts)):
            if nom.startswith("shaman_earthquake") and nom.endswith(".skin"):
                prepares["spells" + BS + nom] = repare_bonecountmax(
                    io.open(os.path.join(dossier_sorts, nom), "rb").read())

        paires = fichiers_a_injecter()
        tailles = {}
        for local, interne in paires:
            donnees = prepares.get(interne)
            if donnees is None:
                donnees = io.open(local, "rb").read()
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
        icones = ((ICONE_SEISME, NOM_ICONE_SEISME),
                  (ICONE_BOURRASQUE, NOM_ICONE_BOURRASQUE),
                  (ICONE_ASCENDANCE, NOM_ICONE_ASCENDANCE),
                  (ICONE_LIEN, NOM_ICONE_LIEN))
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
        d.retire({SON_SEISME, SON_BOURRASQUE, SON_ASCENDANCE, SON_LIEN})
        for ident, nom_son, fichier in (
                (SON_SEISME, "PapotaSeisme", FICHIER_SON_SEISME),
                (SON_BOURRASQUE, "PapotaBourrasque",
                 FICHIER_SON_BOURRASQUE),
                (SON_ASCENDANCE, "PapotaAscendance",
                 FICHIER_SON_ASCENDANCE),
                (SON_LIEN, "PapotaLienEsprit", FICHIER_SON_LIEN)):
            v = list(gabarit)
            v[0] = ident
            v[2] = d.chaine(nom_son)
            for k in range(10):
                v[3 + k] = d.chaine(fichier) if k == 0 else 0
                v[13 + k] = 1 if k == 0 else 0
            v[23] = d.chaine("Sound" + BS + "Spells")
            d.pose(v)
        ecrit(dll, h, prefixe + "SoundEntries.dbc", d.octets())
        print("SoundEntries : %d (séisme) et %d (bourrasque) posés — base %s"
              % (SON_SEISME, SON_BOURRASQUE, source))

        # --- SpellVisualEffectName --------------------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        d.retire({EFFET_SEISME, EFFET_LIEN, EFFET_LIEN_ZONE})
        d.pose([EFFET_SEISME, d.chaine("Seisme - zone"),
                d.chaine(MODELE_SEISME), 0.0, ECHELLE_SEISME, 0.01, 100.0])
        # Les deux effets du lien d'esprit, à l'échelle 1 : ils sont déjà
        # dimensionnés à leur usage, le compact pour le totem, le vaste pour
        # la zone. Aucun facteur à appliquer.
        d.pose([EFFET_LIEN, d.chaine("Lien esprit - totem"),
                d.chaine(MODELE_LIEN), 0.0, 1.0, 0.01, 100.0])
        # ÉCHELLE du vaste : sa boîte englobante mesure 12,3 m de
        # demi-largeur (relevé sur le modèle converti) pour une zone de 10 m
        # de rayon. On le ramène donc à 0,81 pour qu'il couvre exactement la
        # zone d'effet, ni plus ni moins.
        d.pose([EFFET_LIEN_ZONE, d.chaine("Lien esprit - zone"),
                d.chaine(MODELE_LIEN_ZONE), 0.0, ECHELLE_LIEN_ZONE, 0.01, 100.0])
        ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())
        print("SpellVisualEffectName : effet %d (séisme, échelle %.2f) posé"
              % (EFFET_SEISME, ECHELLE_SEISME))

        # --- SpellVisualKit ---------------------------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_SEISME_LANCER, KIT_SEISME_ZONE, KIT_BOURRASQUE_SON,
                  KIT_ASCENDANCE_LANCER, KIT_LIEN, KIT_LIEN_ZONE,
                  KIT_LIEN_SON})
        d.pose([KIT_ASCENDANCE_LANCER, -1, -1] + [0] * 12
               + [SON_ASCENDANCE, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_SEISME_LANCER, -1, -1] + [0] * 12
               + [SON_SEISME, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Le modèle au point d'attache Base : la zone est plate, au sol.
        d.pose([KIT_SEISME_ZONE, -1, -1, 0, 0, EFFET_SEISME]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_BOURRASQUE_SON, -1, -1] + [0] * 12
               + [SON_BOURRASQUE, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Le lien d'esprit : le modèle au point d'attache Base, comme le
        # Séisme — l'effet se pose au sol, sous le totem.
        d.pose([KIT_LIEN, -1, -1, 0, 0, EFFET_LIEN]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_LIEN_ZONE, -1, -1, 0, 0, EFFET_LIEN_ZONE]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_LIEN_SON, -1, -1] + [0] * 12
               + [SON_LIEN, 0] + [-1, -1, -1, -1] + [0] * 17)
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (son du séisme), %d (zone) et %d"
              " (son de la bourrasque) posés"
              % (KIT_SEISME_LANCER, KIT_SEISME_ZONE, KIT_BOURRASQUE_SON))

        # --- SpellVisual ------------------------------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        gabarit_v = None
        for i in range(d.nrec):
            off = i * d.rsize
            if struct.unpack_from("<I", d.enr, off)[0] \
                    == GABARIT_VISUEL_BOURRASQUE:
                gabarit_v = [struct.unpack_from("<i", d.enr, off + k * 4)[0]
                             for k in range(d.nfield)]
                break
        if gabarit_v is None:
            raise SystemExit("visuel %d absent" % GABARIT_VISUEL_BOURRASQUE)
        d.retire({VISUEL_SEISME, VISUEL_BOURRASQUE, VISUEL_CHUTE,
                  VISUEL_ASCENDANCE, VISUEL_LIEN, VISUEL_LIEN_ZONE,
                  VISUEL_LIEN_SORT})
        a = [0] * 32
        a[0] = VISUEL_ASCENDANCE
        a[2] = KIT_ASCENDANCE_LANCER
        d.pose(a)
        # Le séisme : le son au lancement, le modèle au champ 25 — le kit de
        # ZONE PERSISTANTE, qui vit aussi longtemps que la zone du sort.
        v = [0] * 32
        v[0] = VISUEL_SEISME
        v[2] = KIT_SEISME_LANCER
        v[25] = KIT_SEISME_ZONE
        d.pose(v)
        # La bourrasque : le visuel natif tel quel, avec notre son greffé au
        # champ 1, le précast, qui était libre.
        b = list(gabarit_v)
        b[0] = VISUEL_BOURRASQUE
        b[1] = KIT_BOURRASQUE_SON
        d.pose(b)
        # La chute : rien que le kit d'ÉTAT natif des étourdissements, au
        # champ 4 — il vit tant que l'aura tient.
        c = [0] * 32
        c[0] = VISUEL_CHUTE
        c[4] = KIT_ETAT_ETOURDI
        d.pose(c)
        # Le lien d'esprit se joue en DEUX visuels distincts, parce que le
        # son et l'effet ne vivent pas au même endroit :
        #   - le SORT (30078) ne porte que le son, au lancement ;
        #   - le PORTEUR (30075 ou 30076) porte le modèle en kit d'ÉTAT, et
        #     c'est lui que le script pose sur le TOTEM : l'effet suit donc
        #     la créature et non le chaman, et vit ses 16 secondes.
        l = [0] * 32
        l[0] = VISUEL_LIEN_SORT
        l[2] = KIT_LIEN_SON
        d.pose(l)
        for ident, kit in ((VISUEL_LIEN, KIT_LIEN),
                           (VISUEL_LIEN_ZONE, KIT_LIEN_ZONE)):
            l = [0] * 32
            l[0] = ident
            l[4] = kit
            d.pose(l)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : visuels %d (séisme : lancer %d, zone %d), %d"
              " (bourrasque : clone du %d + son %d) et %d (chute : état"
              " natif %d) posés"
              % (VISUEL_SEISME, KIT_SEISME_LANCER, KIT_SEISME_ZONE,
                 VISUEL_BOURRASQUE, GABARIT_VISUEL_BOURRASQUE,
                 KIT_BOURRASQUE_SON, VISUEL_CHUTE, KIT_ETAT_ETOURDI))

        # --- L'apparence de l'ascendant, client PUIS serveur -------------------
        brut_cmd, source_cmd = lit_effectif(dll, h, "CreatureModelData.dbc")
        brut_cdi, source_cdi = lit_effectif(dll, h, "CreatureDisplayInfo.dbc")
        cmd, cdi = Dbc(brut_cmd), Dbc(brut_cdi)
        pose_ascendant(cmd, cdi)
        ecrit(dll, h, prefixe + "CreatureModelData.dbc", cmd.octets())
        ecrit(dll, h, prefixe + "CreatureDisplayInfo.dbc", cdi.octets())
        print("Ascendant (client) : modèle %d et apparence(s) %r posés —"
              " bases %s / %s" % (MODELE_DATA_ASCENDANT,
                                  list(DISPLAYS_ASCENDANT), source_cmd,
                                  source_cdi))

        # Le serveur valide les displayids qu'on lui demande de poser.
        for nom in ("CreatureModelData.dbc", "CreatureDisplayInfo.dbc"):
            p = os.path.join(DBC_SERVEUR_DIR, nom)
            if not os.path.exists(p):
                raise SystemExit("DBC serveur absent : %s" % p)
            if not os.path.exists(p + ".avant_chaman"):
                shutil.copy2(p, p + ".avant_chaman")
        p_cmd = os.path.join(DBC_SERVEUR_DIR, "CreatureModelData.dbc")
        p_cdi = os.path.join(DBC_SERVEUR_DIR, "CreatureDisplayInfo.dbc")
        with io.open(p_cmd, "rb") as f:
            s_cmd = Dbc(f.read())
        with io.open(p_cdi, "rb") as f:
            s_cdi = Dbc(f.read())
        pose_ascendant(s_cmd, s_cdi)
        with io.open(p_cmd, "wb") as f:
            f.write(s_cmd.octets())
        with io.open(p_cdi, "wb") as f:
            f.write(s_cdi.octets())
        print("Ascendant (serveur) : posés dans Data%sdbc" % BS)
    finally:
        dll.SFileCloseArchive(h)


if __name__ == "__main__":
    main()
