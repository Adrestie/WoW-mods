# -*- coding: utf-8 -*-
r"""Monte les visuels du mage : l'Orbe des arcanes (8600071, refonte du
2026-08-30 — le VRAI orbe voyageur).

Sources préparées dans `art_mage\` : le modèle 11fx_arcaneorb02 (converti
v264, chemins inscrits depuis le brut MD21, lods écartés — le client 3.3.5
ne les nomme pas ainsi), ses textures, l'icône moderne inv_112_arcane_orb et
le son d'impact converti en WAV 22050 mono.

  - CreatureModelData + CreatureDisplayInfo 802103 : l'orbe est une CRÉATURE
    habillée du modèle (le sort l'invoque, l'IA la fait voyager —
    SpherierSorts.cpp). Client ET serveur (le worldserver valide les
    displayids contre SES copies, précédent de l'ancre 802101).
  - SpellVisualKit 30033 : le SON d'impact seul, joué sur chaque victime au
    passage de l'orbe (SendPlaySpellVisual — patron du Shunpo).
  - SpellIcon 8055 : inv_112_arcane_orb.

    python gen_visuel_mage.py          (JEU FERMÉ requis : écrit dans patch-z)
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
from gen_visuel_paladin import repare_texunit
from gen_visuel_voleur import lit_effectif, texte

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_mage")
DBC_SERVEUR_DIR = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc"

DISPLAY_ORBE = 802103        # CreatureModelData ET CreatureDisplayInfo
ECHELLE_ORBE = 1.0 / 3.0     # « 3 fois trop gros » constaté en jeu (2026-08-30)
KIT_ORBE_IMPACT = 30033      # le son d'impact seul, joué sur la victime
SON_ORBE = 990107
ICONE_ORBE = 8055
# Icônes du Météore (8600056) et de son dot Liquéfaction (8600057),
# exportées par l'utilisateur le 2026-08-31.
ICONES = [
    (8055, "inv_112_arcane_orb"),
    (8056, "spell_mage_meteor"),
    (8057, "spell_shaman_lavasurge"),
    (8058, "spell_mage_evanesce"),      # Miroitement (8600070) et son témoin
    (8059, "ability_mage_rayoffrost"),  # Rayon de givre (8600073)
]

# --- le Rayon de givre (8600073, montage du 2026-08-31) ----------------------
# « LITTÉRALEMENT le même effet visuel que le Drain de vie, avec la texture
# importée. » Le montage est donc une COPIE FIDÈLE du relevé natif, et non
# une reconstruction — c'est ce qui manquait aux deux premières tentatives :
#   visuel 12655 : {2: 341 (kit de lancer), 4: 293 (état), 6: 11762 (CANAL),
#                   10: 1, 16: -1}
#   kit 11762    : {2: 124 (animation), 6: 298 (effet à la main),
#                   15: 3087 (son), 18/19/20: -1, 21: 719.0 (LA CHAÎNE, en
#                   FLOTTANT), 25/29/33: 1.0 (LES ÉCHELLES — à zéro, comme
#                   dans ma première version, la chaîne est invisible)}
# Seuls la chaîne et le son changent ; les kits de lancer et d'état natifs
# sont réutilisés tels quels (jamais modifiés).
CHAINE_RAYON = 2001
GABARIT_CHAINE = 719         # la chaîne DU DRAIN DE VIE
# La texture vit dans le dossier NATIF des chaînes : sous spells\, le client
# ne la chargeait pas et la chaîne restait invisible (test du 2026-08-31 —
# le visuel natif 12655 s'affichait, notre clone identique champ par champ
# non : la texture était la seule différence restante).
FICHIER_TEXTURE_RAYON = "8fx_jaina_glacialraybeam.blp"
TEXTURE_RAYON = ("Textures" + BS + "SpellChainEffects" + BS
                 + FICHIER_TEXTURE_RAYON)
# Champ 4 (octet 16) du gabarit : l'échelle des coordonnées de texture, à
# -2,0 chez le drain — le signe porte le SENS de défilement. Retourné à
# +2,0 : « l'offset de la texture sur le drain est inversé » (2026-08-31).
CHAINE_TEXCOORD = 2.0
KIT_RAYON = 30037            # notre clone du kit de canal 11762
VISUEL_RAYON = 30037
ANIM_DRAIN_CANAL = 124       # l'animation du kit natif : LA POSTURE de
                             # canalisation, gardée
# LIEN 100 % CUSTOM (2026-08-31) : les emprunts au drain sont retirés — le
# kit de lancer 341, le kit d'état 293 et surtout l'effet 298, qui n'est
# autre que « Life Tap State Chest » (Spells\Lifetap_State_Chest.mdx), LE
# VERT du drain au torse.
# LA TEINTE DE LA CHAÎNE, décodée sur le catalogue natif : octets 156-159 =
# A,R,G,B ; octet 160 = MODE DE RENDU (2 ou 3) ; 161-163 = un offset, à ne
# pas toucher. Le gabarit 719 porte 33 3a f7 5b — alpha 51, RGB (58,247,91),
# le vert du drain. On pose ff ff ff ff : blanc opaque, teinte NEUTRE, la
# texture importée parle seule. (Une première tentative avait mis 255 aux
# octets 156-158 ET 160-162, écrasant le mode de rendu : noir opaque.)
CHAINE_TEINTE = (0xFF, 0xFF, 0xFF, 0xFF)
# Les octets 161-163 : un SECOND RENVOI, non nul chez le 719 (5d 19 00) là
# où toutes les chaînes simples du catalogue portent 00 00 00 — c'est le
# deuxième brin du drain, celui qui remonte de la cible vers le lanceur
# (« des traits verts qui vont dans le mauvais sens », 2026-08-31). Mis à
# zéro : il ne reste que notre trait.
CHAINE_SECOND_BRIN = False
SON_RAYON = 990111
GABARIT_SON_BOUCLE = 3087    # le bourdon du Drain de vie : il BOUCLE
FICHIER_SON_RAYON = "spell_ma_rayoffrost_loop.wav"
EMOTE_ORBE_DECAY = 990001    # emote custom one-shot : l'anim Decay (159)
GABARIT_EMOTE = 3            # EMOTE_ONESHOT_WAVE, un one-shot natif
ANIM_HOLD, ANIM_RUN, ANIM_DECAY = 158, 5, 159

# (Le RÉTROPORT du Météore — displays 802104-06, sons 990108-10, kits
# 30034-36, emote d'état 990002, coutures et retimages — a été RETIRÉ le
# 2026-08-31 : le sort 8600072 est revenu à sa forme DBC d'origine. Ce qui
# était déjà injecté reste dormant dans patch-z et Data\dbc.)

DISPLAY_MARQUE_MIROITEMENT = 802107
# La marque du Miroitement (2026-08-31) : la rune bleue au sol NATIVE du
# client — aucun fichier à injecter, le chemin suffit (relevé
# SpellVisualEffectName 3198).
MODELE_MARQUE = ("World" + BS + "Goober" + BS + "G_RuneGroundBlue01.mdx")

DISPLAYS = [
    (DISPLAY_ORBE, "spells" + BS + "11fx_arcaneorb02.mdx", None),
    (DISPLAY_MARQUE_MIROITEMENT, MODELE_MARQUE, 1.0),
]
MODELE_ORBE = "spells" + BS + "11fx_arcaneorb02.mdx"
FICHIER_SON = "spell_ma_arcaneorb_impact_02.wav"
GABARIT_SON = 3011           # un son de sort one-shot (la Boule de feu)

MODELES = {                  # m2 -> son .skin, pour le contrôle texUnitLookup
    "11fx_arcaneorb02.m2": "11fx_arcaneorb0200.skin",
    "8fx_jaina_glacialray_cast.m2": "8fx_jaina_glacialray_cast00.skin",
}


def fichiers_a_injecter():
    paires = []
    for nom in sorted(os.listdir(os.path.join(ART, "spells"))):
        if "_lod0" in nom or nom.endswith((".ogg", ".json")):
            continue
        if nom.endswith((".m2", ".skin", ".blp")):
            paires.append((os.path.join(ART, "spells", nom), "spells" + BS + nom))
    for _ident, nom_icone in ICONES:
        ic = os.path.join(ART, "interface", "icons", nom_icone + ".blp")
        paires.append((ic, "Interface" + BS + "Icons" + BS
                       + nom_icone + ".blp"))
    # Le faisceau du rayon, EN PLUS, sous le dossier natif des chaînes.
    paires.append((os.path.join(ART, "spells", FICHIER_TEXTURE_RAYON),
                   TEXTURE_RAYON))
    for nom in sorted(os.listdir(os.path.join(ART, "sound", "spells"))):
        if nom.endswith(".wav"):
            paires.append((os.path.join(ART, "sound", "spells", nom),
                           "Sound" + BS + "Spells" + BS + nom))
    return paires


def prepare_orbe(donnees):
    """Le cycle d'animations voulu (2026-08-30) : naître sur Stand, boucler
    sur Hold, disparaître sur Decay. Relevé du converti : Stand (0, 1000 ms),
    Hold (158, 1000 ms), Decay (159, 333 ms) — l'AnimationData de 3.3.5
    connaît les trois. L'orbe VOYAGE toute sa vie : le client demande Run (5)
    en mouvement — la séquence Hold est donc RETAGUÉE en Run (et la table de
    correspondance animID -> séquence repointée), Stand joue à l'arrêt de
    naissance (départ retardé par l'IA), Decay part par emote custom à
    l'arrivée."""
    donnees = bytearray(donnees)
    nSeq, ofsSeq = struct.unpack_from("<2I", donnees, 0x1C)
    nLook, ofsLook = struct.unpack_from("<2I", donnees, 0x24)
    for i in range(nSeq):
        off = ofsSeq + i * 64
        if struct.unpack_from("<H", donnees, off)[0] == ANIM_HOLD:
            struct.pack_into("<H", donnees, off, ANIM_RUN)
            if ANIM_RUN < nLook:
                struct.pack_into("<h", donnees, ofsLook + ANIM_RUN * 2, i)
            print("prepare_orbe : séquence %d retaguée Hold -> Run" % i)
    return bytes(donnees)


def retime_sequence(donnees, seq, facteur, nom):
    """Retime la séquence `seq` d'un M2 v264 : longueur ET timestamps de
    toutes ses pistes ×facteur. Les timestamps d'une piste sont un M2Array
    PAR SÉQUENCE (nT = nombre de séquences) ; les pistes à séquence globale
    (gseq != -1) ne bougent pas. Blocs : os (0x2C, +16/+36/+56), couleurs
    (0x48, +0/+20), transparences (0x58, +0), anims UV (0x60, +0/+20/+40),
    émetteurs (0x128, pistes principales + enabledIn — relevé du cône).

    (La table du 2026-08-30 est en 60 fps : le Stand de la marque garde sa
    seconde native — le retimage ×2 de la veille est retiré — et seule la
    CHUTE passe de 2500 à 2000 ms, ×0,8.)"""
    donnees = bytearray(donnees)

    nSeq, ofsSeq = struct.unpack_from("<2I", donnees, 0x1C)
    off = ofsSeq + seq * 64 + 4
    avant = struct.unpack_from("<I", donnees, off)[0]
    struct.pack_into("<I", donnees, off, int(avant * facteur + 0.5))

    def etire(piste):
        _interp, gseq = struct.unpack_from("<2h", donnees, piste)
        if gseq != -1:
            return
        nT, oT = struct.unpack_from("<2I", donnees, piste + 4)
        if nT <= seq:
            return
        n0, o0 = struct.unpack_from("<2I", donnees, oT + seq * 8)
        for k in range(n0):
            t = struct.unpack_from("<I", donnees, o0 + k * 4)[0]
            struct.pack_into("<I", donnees, o0 + k * 4,
                             int(t * facteur + 0.5))

    blocs = [(0x2C, 88, (16, 36, 56)), (0x48, 40, (0, 20)),
             (0x58, 20, (0,)), (0x60, 60, (0, 20, 40))]
    for entete, pas, pistes in blocs:
        n, ofs = struct.unpack_from("<2I", donnees, entete)
        for i in range(n):
            for p in pistes:
                etire(ofs + i * pas + p)
    np_, ofsp = struct.unpack_from("<2I", donnees, 0x128)
    for i in range(np_):
        base = ofsp + i * 476
        for p in (52, 72, 92, 112, 132, 152, 176, 200, 220, 240, 456):
            etire(base + p)
    print("retime_sequence : %s seq %d, %d -> %d ms"
          % (nom, seq, avant, int(avant * facteur + 0.5)))
    return bytes(donnees)


# (couture_marque — la couture des séquences du Météore — retirée le
# 2026-08-31 avec le rétroport ; retime_sequence est conservée, outil
# générique. L'acquis reste : les phases d'un effet 3.3.5 se cousent dans
# UNE séquence, façon consecration_impact_base.)


def pose_sons(d):
    """Le son de l'orbe dans un Dbc SoundEntries (gabarit 3011, la Boule de
    feu). Posé côté CLIENT (patch-z) et côté SERVEUR (Data\\dbc — les ids de
    PlayDirectSound sont validés contre le magasin du worldserver)."""
    if d.nfield != 30:
        raise SystemExit("SoundEntries : %d champs, 30 attendus" % d.nfield)
    gabarit = None
    for i in range(d.nrec):
        off = i * d.rsize
        if struct.unpack_from("<I", d.enr, off)[0] == GABARIT_SON:
            gabarit = [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                       for k in range(30)]
    if gabarit is None:
        raise SystemExit("gabarit sonore %d absent" % GABARIT_SON)
    d.retire({SON_ORBE})

    def entree_son(ident, nom_son, fichier):
        v = list(gabarit)
        v[0] = ident
        v[2] = d.chaine(nom_son)
        for k in range(10):
            v[3 + k] = d.chaine(fichier) if k == 0 else 0
            v[13 + k] = 1 if k == 0 else 0
        v[23] = d.chaine("Sound" + BS + "Spells")
        return v

    d.pose(entree_son(SON_ORBE, "PapotaOrbeImpact", FICHIER_SON))

    # La boucle du Rayon de givre : gabarit 3087 (le bourdon du drain), le
    # seul dont on sait qu'il tourne tant que le kit vit.
    boucle = None
    for i in range(d.nrec):
        off = i * d.rsize
        if struct.unpack_from("<I", d.enr, off)[0] == GABARIT_SON_BOUCLE:
            boucle = [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                      for k in range(30)]
    if boucle is None:
        raise SystemExit("gabarit sonore %d absent" % GABARIT_SON_BOUCLE)
    d.retire({SON_RAYON})
    v = list(boucle)
    v[0] = SON_RAYON
    v[2] = d.chaine("PapotaRayonGivre")
    for k in range(10):
        v[3 + k] = d.chaine(FICHIER_SON_RAYON) if k == 0 else 0
        v[13 + k] = 1 if k == 0 else 0
    v[23] = d.chaine("Sound" + BS + "Spells")
    d.pose(v)


def pose_emote_decay(d):
    """L'emote custom dans un Dbc Emotes : le one-shot Decay (159, clone du
    Salut) joué par l'orbe avant sa disparition."""
    if d.nfield != 7:
        raise SystemExit("Emotes : %d champs, 7 attendus" % d.nfield)

    def gabarit_de(ident):
        for i in range(d.nrec):
            off = i * d.rsize
            if struct.unpack_from("<I", d.enr, off)[0] == ident:
                return [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                        for k in range(7)]
        raise SystemExit("gabarit d'emote %d absent" % ident)

    oneshot = gabarit_de(GABARIT_EMOTE)
    d.retire({EMOTE_ORBE_DECAY})
    oneshot[0] = EMOTE_ORBE_DECAY
    oneshot[1] = d.chaine("PAPOTAORBEDECAY")
    oneshot[2] = ANIM_DECAY
    oneshot[6] = 0                       # pas de son : les kits s'en chargent
    d.pose(oneshot)


def pose_orbe(cmd, cdi):
    """Les habillages customs (table DISPLAYS) dans CreatureModelData +
    CreatureDisplayInfo — patron de l'ancre du grappin (pose_crochet_sol) :
    clone du Poulet, chemin remplacé, échelle modèle 1, champs
    sonores/empreintes à zéro ; habillage opacité 255 sans variation de
    texture (chemins inscrits dans les M2)."""
    if cmd.nfield != 28:
        raise SystemExit("CreatureModelData : %d champs, 28 attendus" % cmd.nfield)
    if cdi.nfield != 16:
        raise SystemExit("CreatureDisplayInfo : %d champs, 16 attendus" % cdi.nfield)

    poulet = None
    for i in range(cmd.nrec):
        off = i * cmd.rsize
        chemin = texte(cmd, struct.unpack_from("<I", cmd.enr, off + 8)[0]).lower()
        if chemin.endswith("chicken.mdx") or chemin.endswith("chicken.m2"):
            poulet = [struct.unpack_from("<I", cmd.enr, off + k * 4)[0]
                      for k in range(28)]
            break
    if poulet is None:
        raise SystemExit("gabarit Chicken absent de CreatureModelData")

    cmd.retire({ident for ident, _c, _e in DISPLAYS})
    cdi.retire({ident for ident, _c, _e in DISPLAYS})
    for ident, chemin, echelle in DISPLAYS:
        gabarit = list(poulet)
        gabarit[0] = ident
        gabarit[2] = cmd.chaine(chemin)
        gabarit[4] = struct.unpack("<I", struct.pack("<f", 1.0))[0]
        for k in range(5, 14):
            gabarit[k] = 0
        cmd.pose(gabarit)
        cdi.pose([ident, ident, 0, 0,
                  ECHELLE_ORBE if echelle is None else echelle, 255,
                  0, 0, 0, 0, 0, 0, 0, 0, 0, 0])


def main():
    sauvegarde = G.ARCHIVE + ".avant_art_mage"
    if not os.path.exists(sauvegarde):
        print("sauvegarde de l'archive (une fois) : %s" % sauvegarde)
        shutil.copy2(G.ARCHIVE, sauvegarde)

    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        paires = fichiers_a_injecter()
        tailles = {}
        for local, interne in paires:
            donnees = io.open(local, "rb").read()
            nom = os.path.basename(local)
            if nom == "11fx_arcaneorb02.m2":
                donnees = prepare_orbe(donnees)
            if nom in MODELES:
                donnees = repare_texunit(donnees, os.path.join(
                    ART, "spells", MODELES[nom]))
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

        # --- SoundEntries : l'impact de l'orbe --------------------------------
        brut, source = lit_effectif(dll, h, "SoundEntries.dbc")
        d = Dbc(brut)
        pose_sons(d)
        ecrit(dll, h, prefixe + "SoundEntries.dbc", d.octets())
        print("SoundEntries : %d (impact de l'orbe) posé — base %s"
              % (SON_ORBE, source))

        # --- SpellChainEffects : la chaîne du drain, texture remplacée --------
        # Enregistrements NON alignés sur 4 : travail en brut. Clone du
        # gabarit 719 (celui du Drain de vie), identifiant et offset de
        # texture (décalage 28) réécrits — TOUT LE RESTE conservé.
        brut, source = lit_effectif(dll, h, "SpellChainEffects.dbc")
        d = Dbc(brut)
        garde, gabarit = bytearray(), None
        for i in range(d.nrec):
            off = i * d.rsize
            ident = struct.unpack_from("<I", d.enr, off)[0]
            rec = bytes(d.enr[off:off + d.rsize])
            if ident == GABARIT_CHAINE:
                gabarit = rec
            if ident == CHAINE_RAYON:
                continue
            garde.extend(rec)
        if gabarit is None:
            raise SystemExit("chaîne gabarit %d absente" % GABARIT_CHAINE)
        rec = bytearray(gabarit)
        struct.pack_into("<I", rec, 0, CHAINE_RAYON)
        struct.pack_into("<I", rec, 28, d.chaine(TEXTURE_RAYON))
        struct.pack_into("<f", rec, 16, CHAINE_TEXCOORD)
        for k, valeur in enumerate(CHAINE_TEINTE):
            rec[156 + k] = valeur
        if not CHAINE_SECOND_BRIN:
            for k in (161, 162, 163):
                rec[k] = 0
        garde.extend(rec)
        d.enr, d.nrec = garde, len(garde) // d.rsize
        ecrit(dll, h, prefixe + "SpellChainEffects.dbc", d.octets())
        print("SpellChainEffects : %d posé (clone de %d, texture %s) — base %s"
              % (CHAINE_RAYON, GABARIT_CHAINE, TEXTURE_RAYON, source))

        # --- SpellVisualKit : le son de l'orbe, le canal du rayon -------------
        # Le kit de canal garde du natif 11762 sa STRUCTURE (animation de
        # canalisation 124, chaîne en FLOTTANT au champ 21, les trois
        # échelles à 1,0 aux champs 25/29/33) mais PLUS AUCUN de ses effets :
        # le 298 aux mains était le vert du drain.
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_ORBE_IMPACT, KIT_RAYON})
        d.pose([KIT_ORBE_IMPACT, -1, -1, 0, 0] + [0] * 10
               + [SON_ORBE, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_RAYON, -1, ANIM_DRAIN_CANAL, 0, 0, 0, 0]
               + [0] * 8 + [SON_RAYON, 0]
               + [0, -1, -1, -1]
               + [float(CHAINE_RAYON), 0.0, 0.0, 0.0, 1.0]
               + [0.0, 0.0, 0.0, 1.0]
               + [0.0, 0.0, 0.0, 1.0] + [0] * 4)
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (son de l'orbe) et %d (canal CUSTOM :"
              " anim %d, chaîne %d, boucle %d — aucun effet du drain) posés"
              % (KIT_ORBE_IMPACT, KIT_RAYON, ANIM_DRAIN_CANAL, CHAINE_RAYON,
                 SON_RAYON))

        # --- SpellVisual : NOTRE canal seul -----------------------------------
        # Les kits de lancer (341) et d'état (293) du drain sont retirés : ils
        # portaient ses effets verts. Il ne reste que notre kit de canal, avec
        # les champs 10=1 et 16=-1 relevés sur le natif.
        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL_RAYON})
        v = [0] * 32
        v[0] = VISUEL_RAYON
        v[6] = KIT_RAYON
        v[10] = 1
        v[16] = -1
        d.pose(v)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : visuel %d (canal CUSTOM %d seul) posé"
              % (VISUEL_RAYON, KIT_RAYON))

        # --- SpellIcon --------------------------------------------------------
        brut, source = lit_effectif(dll, h, "SpellIcon.dbc")
        d = Dbc(brut)
        d.retire({ident for ident, _n in ICONES})
        for ident, nom_icone in ICONES:
            d.pose([ident, d.chaine("Interface" + BS + "Icons" + BS
                                    + nom_icone)])
        ecrit(dll, h, prefixe + "SpellIcon.dbc", d.octets())
        print("SpellIcon : %s posées — base %s"
              % (", ".join("%d -> %s" % p for p in ICONES), source))

        # --- CreatureModelData + CreatureDisplayInfo : l'orbe (client) --------
        brut_cmd, source_cmd = lit_effectif(dll, h, "CreatureModelData.dbc")
        brut_cdi, source_cdi = lit_effectif(dll, h, "CreatureDisplayInfo.dbc")
        cmd, cdi = Dbc(brut_cmd), Dbc(brut_cdi)
        pose_orbe(cmd, cdi)
        ecrit(dll, h, prefixe + "CreatureModelData.dbc", cmd.octets())
        ecrit(dll, h, prefixe + "CreatureDisplayInfo.dbc", cdi.octets())
        print("Orbe (client) : modèle et habillage %d (échelle %.2f) posés"
              " — bases %s / %s"
              % (DISPLAY_ORBE, ECHELLE_ORBE, source_cmd, source_cdi))

        # --- Emotes : le Decay de l'orbe (client) -----------------------------
        brut_em, source_em = lit_effectif(dll, h, "Emotes.dbc")
        em = Dbc(brut_em)
        pose_emote_decay(em)
        ecrit(dll, h, prefixe + "Emotes.dbc", em.octets())
        print("Emotes (client) : %d (anim Decay %d) posée — base %s"
              % (EMOTE_ORBE_DECAY, ANIM_DECAY, source_em))
    finally:
        dll.SFileCloseArchive(h)

    # --- les mêmes DBC côté SERVEUR -----------------------------------------
    for nom in ("CreatureModelData.dbc", "CreatureDisplayInfo.dbc",
                "Emotes.dbc", "SoundEntries.dbc"):
        chemin = os.path.join(DBC_SERVEUR_DIR, nom)
        if not os.path.exists(chemin):
            raise SystemExit("DBC serveur absent : %s" % chemin)
        sauvegarde = chemin + ".avant_orbe"
        if not os.path.exists(sauvegarde):
            shutil.copy2(chemin, sauvegarde)
    chemin_cmd = os.path.join(DBC_SERVEUR_DIR, "CreatureModelData.dbc")
    chemin_cdi = os.path.join(DBC_SERVEUR_DIR, "CreatureDisplayInfo.dbc")
    chemin_em = os.path.join(DBC_SERVEUR_DIR, "Emotes.dbc")
    chemin_sons = os.path.join(DBC_SERVEUR_DIR, "SoundEntries.dbc")
    cmd = Dbc(io.open(chemin_cmd, "rb").read())
    cdi = Dbc(io.open(chemin_cdi, "rb").read())
    em = Dbc(io.open(chemin_em, "rb").read())
    sons = Dbc(io.open(chemin_sons, "rb").read())
    pose_orbe(cmd, cdi)
    pose_emote_decay(em)
    pose_sons(sons)
    with io.open(chemin_cmd, "wb") as f:
        f.write(cmd.octets())
    with io.open(chemin_cdi, "wb") as f:
        f.write(cdi.octets())
    with io.open(chemin_em, "wb") as f:
        f.write(em.octets())
    with io.open(chemin_sons, "wb") as f:
        f.write(sons.octets())
    print("Orbe (serveur) : modèle, habillage %d et emote %d posés dans"
          " Data%sdbc" % (DISPLAY_ORBE, EMOTE_ORBE_DECAY, BS))

    print("\nLe sort 8600071 et la créature 803806 pointent ces ids :"
          "\n  python gen_sorts_classes.py --deploy   puis rejouer le SQL au démarrage.")


if __name__ == "__main__":
    main()
