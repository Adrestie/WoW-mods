# -*- coding: utf-8 -*-
r"""Monte les visuels rétroportés du Bond héroïque (8600000).

Sources préparées dans `art_guerrier\` (montage du 2026-08-30) : deux modèles
convertis en v264 par MultiConverter, chemins inscrits par inscrit_textures.py
depuis les bruts MD21 de wow.export, et le son d'impact converti en WAV
22050 mono (le format des éprouvés) :

  - cfx_warrior_charge_state       l'état de charge, joué sur le joueur
                                   PENDANT le vol (demande du 2026-08-30) ;
  - cfx_warrior_heroicleap_cast02  l'impact au sol, joué à l'ATTERRISSAGE
                                   avec le son spell_wr_heroicleap_
                                   areaeffectimpact_01.

Les deux kits sont joués PAR LE SCRIPT (SendPlaySpellVisual, le patron prouvé
du Shunpo — kit 404) : le vol au départ du saut, l'impact à l'échéance de la
durée réelle de la spline. Le son vit DANS le kit d'impact (champ SoundID) :
un seul envoi joue l'effet et le son. Le visuel 11927 du sort (l'emprunt
Marteau du juste) n'est pas touché.

La table texUnitLookup de chaque modèle est garantie à l'injection
(repare_texunit — le contrôle OBLIGATOIRE de tout rétroport : erreur 132 si
vide, mesh dégénéré si trop courte).

    python gen_visuel_guerrier.py      (JEU FERMÉ requis : écrit dans patch-z)
"""
import ctypes as C
import io
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
from gen_visuel_aube import Dbc, stormlib, lit, ecrit
from gen_visuel_paladin import repare_texunit
from gen_visuel_voleur import lit_effectif

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_guerrier")

EFFET_BOND_VOL = 8200217
EFFET_BOND_IMPACT = 8200218
KIT_BOND_VOL = 30026        # joué par le script au départ du saut
KIT_BOND_IMPACT = 30027     # joué par le script à l'atterrissage (+ son)
SON_BOND_IMPACT = 990105
VISUEL_BOND = 30028         # le visuel du sort : impact victimes SEUL
KIT_IMPACT_NATIF = 11014    # l'impact du Marteau du juste (11927), réutilisé
                            # par référence — jamais modifié. Le reste du
                            # 11927 (précast 52, lancer 11015, missile 4654)
                            # jouait l'anim d'incantation et l'éclat jaune
                            # sur les mains PAR-DESSUS la pose du script
                            # (constaté en jeu le 2026-08-30) : supprimé.

MODELE_VOL = "spells" + BS + "cfx_warrior_charge_state.mdx"
MODELE_IMPACT = "spells" + BS + "cfx_warrior_heroicleap_cast02.mdx"
FICHIER_SON = "spell_wr_heroicleap_areaeffectimpact_01.wav"
GABARIT_SON_IMPACT = 3011   # un son de sort one-shot (la Boule de feu)

# --- Fureur d'Odyn (8600002, montage du 2026-08-30) --------------------------
# Le cône sethrak au lancer (converti v264, 11 chemins inscrits), le son
# d'impact de pierre, l'icône achievement_boss_odyn. Relevé du visuel 372
# (l'emprunt Déchirure) : lancer = kit 324 (anim 57 Special1H + son, AUCUN
# modèle), impact victimes = kit 220 (éclat sanglant au torse). Le montage
# garde l'anim du lancer et l'impact natif 220 TEL QUEL, et n'ajoute que le
# cône + le son dans un kit de lancer à nous.
EFFET_ODYN_CONE = 8200219
KIT_ODYN_LANCER = 30030      # anim + son + cone au champ 14 — l'emplacement
                             # « EFFET MONDE » : le modèle apparaît DANS LE
                             # MONDE à la position du lancement et y reste,
                             # fixe par nature. C'est le mécanisme de l'Onde
                             # de choc native (relevé 10703/kit 9854 du
                             # 2026-08-30) — les tentatives par attache Base
                             # puis par dummy-socle sont retirées.
VISUEL_ODYN = 30031
ICONE_ODYN = 8054
SON_ODYN = 990106
# Effet CHANGÉ par l'utilisateur le 2026-08-30 : le cône sethrak cède la
# place à arcane_spikecone_impactworld (pointes du sol), textures passées en
# nuances de ROUGE SANG par rougit_textures.py. Les fichiers sethrak restent
# dormants dans patch-z.
MODELE_ODYN = "spells" + BS + "arcane_spikecone_impactworld.mdx"
FICHIER_SON_ODYN = "go_explodingstoneimpact01_07.wav"
ANIM_SPECIAL1H = 57          # l'anim du lancer actuel (relevé kit 324)
KIT_ODYN_IMPACT_NATIF = 220  # l'impact sanglant de la Déchirure — jamais modifié

MODELES = {                 # m2 -> son .skin, pour le contrôle texUnitLookup
    "cfx_warrior_charge_state.m2": "cfx_warrior_charge_state00.skin",
    "cfx_warrior_heroicleap_cast02.m2": "cfx_warrior_heroicleap_cast0200.skin",
    "arcane_spikecone_impactworld.m2": "arcane_spikecone_impactworld00.skin",
}

# Préparation du cône (mesures du 2026-08-30 : bâti vers −X sur 29 m, 4
# émetteurs de particules, 0 ruban, 8 os) :
CONE_EN_L_ETAT = True        # sources RÉEXPORTÉES ET REFIXÉES par
                             # l'utilisateur le 2026-08-30, injectées TELLES
                             # QUELLES : prepare_cone débranchée (le
                             # retournement, l'échelle et les particules
                             # vivent désormais dans la source) ; seul le
                             # contrôle texUnitLookup (anti-crash 132) reste.
CONE_ECHELLE = 16.0 / 29.0   # 29 m -> 16 m (demande du 2026-08-30)
# Autopsie du 2026-08-30 (hexdump, pas RÉEL de 476 octets, pistes de 20
# octets à +52, avec lifespanVary à +172 et rateVary à +196 intercalés) :
# la structure des émetteurs est saine mais les DIX paramètres d'émission
# sont à ZÉRO — le convertisseur n'a pas su transposer les pistes modernes,
# et un émetteur tout à zéro crache le filet en ligne constaté. Réparation :
# des valeurs physiques plausibles de cône de sable, pokées dans les
# emplacements existants (nV=1 partout) — LES CADRANS du réglage en jeu.
CONE_PISTES = [              # (offset de piste dans l'émetteur, valeur)
    (52, 5.0),               # emissionSpeed : 5 m/s (le sens vient des OS,
                             # retournés proprement ci-dessous — le signe
                             # négatif essayé le 2026-08-30 ne pilotait pas)
    (72, 0.4),               # speedVariation
    (92, 0.15),              # verticalRange : gerbe rasante
    (112, 0.6),              # horizontalRange : l'éventail (rad)
    (132, 2.0),              # gravity : le sable retombe
    (152, 1.0),              # lifespan : 1 s
    (176, 30.0),             # emissionRate : 30/s
    (200, 2.0),              # emissionAreaLength
    (220, 4.0),              # emissionAreaWidth
    (240, 0.0),              # zSource
]
CONE_PAS_EMETTEUR = 476


def prepare_cone(donnees):
    """Le cône prêt à poser : retourné de 180° autour de Z (le modèle est
    bâti vers −X, l'avant de 3.3.5 est +X — « part vers l'arrière » constaté
    en jeu), géométrie ×CONE_ECHELLE, émetteurs de particules retirés
    (compte à zéro, 0x128), boîte et rayon recalculés.

    Le retournement : positions et normales des sommets, translations des
    os RACINES (espace modèle — celles des enfants vivent dans le repère du
    parent, déjà retourné) et TOUS les pivots (espace modèle, relevé
    prepare_zone). L'échelle s'applique partout (elle commute avec la
    rotation). Offsets M2 264 : sommets 0x3C (pas 48, normale +20), os 0x2C
    (pas 88, parent +8, valeurs de translation +24, pivot +76)."""
    import struct
    donnees = bytearray(donnees)

    def transforme(off, retourne=True, echelle=CONE_ECHELLE):
        x, y, z = struct.unpack_from("<3f", donnees, off)
        s = -1.0 if retourne else 1.0
        struct.pack_into("<3f", donnees, off, x * echelle * s,
                         y * echelle * s, z * echelle)

    n, ofs = struct.unpack_from("<2I", donnees, 0x3C)
    for i in range(n):
        transforme(ofs + i * 48)
        transforme(ofs + i * 48 + 20, echelle=1.0)      # la normale

    nb, ofsb = struct.unpack_from("<2I", donnees, 0x2C)
    for i in range(nb):
        off = ofsb + i * 88
        parent = struct.unpack_from("<h", donnees, off + 8)[0]
        nV, ofsV = struct.unpack_from("<2I", donnees, off + 24)
        for k in range(nV):
            transforme(ofsV + k * 12, retourne=(parent == -1))
        transforme(off + 76)

        # Les REPÈRES des os portent la direction d'émission des particules
        # — le retournement de la géométrie ne les touche pas. CALIBRÉ sur
        # l'étalon natif warrior_shockwave_area (2026-08-30) : la piste de
        # rotation est à +36 (interp/gseq +36/38, timestamps +40, valeurs
        # nV/oV +48/52 — la tentative à +32 écrivait dans la TRANSLATION et
        # a tué le modèle). Les quaternions résiduels de la conversion sont
        # IRRÉCUPÉRABLES (retournés en Rz(180°), ils pointaient encore de
        # travers — relevé OBJ : axe (0.35, 0.90, -0.25)) : chaque clé est
        # ÉCRASÉE par le repère propre Ry(90°) — +Z, l'axe d'émission,
        # basculé sur +X, l'avant.
        nQ, oQ = struct.unpack_from("<2I", donnees, off + 48)
        for k in range(nQ):
            struct.pack_into("<4h", donnees, oQ + k * 8,
                             32767, -9598, 32767, -9598)

    # Émetteurs : positions RELATIVES à leur os — échelle seule (précédent
    # prepare_zone) — et RÉPARATION des dix paramètres à zéro.
    np_, ofsp = struct.unpack_from("<2I", donnees, 0x128)
    for i in range(np_):
        base = ofsp + i * CONE_PAS_EMETTEUR
        transforme(base + 8, retourne=False)
        for toff, valeur in CONE_PISTES:
            nV, oV = struct.unpack_from("<2I", donnees, base + toff + 12)
            if nV:
                struct.pack_into("<f", donnees, oV, valeur)

        # Les os d'émetteur SANS clé de rotation (5/6) ont un repère
        # identité : émission le long de +Z = LE HAUT (« vers le haut
        # plutôt que l'avant », constaté après le retournement des os à
        # clés). On leur pose UNE clé statique Ry(90°) — +Z bascule sur +X,
        # l'avant — aux offsets CALIBRÉS sur l'étalon natif (+36/+40/+48).
        # Compression M2 : c>0 -> c*32767-32768 ; c<=0 -> c*32767+32767
        # (0,7071 -> -9598 ; 0 -> 32767).
        porteur = struct.unpack_from("<h", donnees, base + 20)[0]
        boff = ofsb + porteur * 88
        if struct.unpack_from("<I", donnees, boff + 48)[0] == 0:
            oT = len(donnees)
            donnees.extend(struct.pack("<I", 0))
            oV = len(donnees)
            donnees.extend(struct.pack("<4h", 32767, -9598, 32767, -9598))
            struct.pack_into("<2h", donnees, boff + 36, 0, -1)
            struct.pack_into("<2I", donnees, boff + 40, 1, oT)
            struct.pack_into("<2I", donnees, boff + 48, 1, oV)

    mins, maxs, rayon = [1e9] * 3, [-1e9] * 3, 0.0
    for i in range(n):
        v = struct.unpack_from("<3f", donnees, ofs + i * 48)
        for k in range(3):
            mins[k] = min(mins[k], v[k])
            maxs[k] = max(maxs[k], v[k])
        rayon = max(rayon, (v[0] ** 2 + v[1] ** 2 + v[2] ** 2) ** 0.5)
    struct.pack_into("<6f", donnees, 0xA0, *(mins + maxs))
    struct.pack_into("<f", donnees, 0xB8, rayon)
    return bytes(donnees)


def fichiers_a_injecter():
    paires = []
    for nom in sorted(os.listdir(os.path.join(ART, "spells"))):
        if nom.endswith((".m2", ".skin", ".blp")):
            paires.append((os.path.join(ART, "spells", nom), "spells" + BS + nom))
    for nom in sorted(os.listdir(os.path.join(ART, "sound", "spells"))):
        if nom.endswith(".wav"):
            paires.append((os.path.join(ART, "sound", "spells", nom),
                           "Sound" + BS + "Spells" + BS + nom))
    # ability_warrior_bloodnova remplace achievement_boss_odyn le 2026-08-30
    # (renommage Empalement) — l'ancienne icône reste dormante dans patch-z.
    ic = os.path.join(ART, "interface", "icons", "ability_warrior_bloodnova.blp")
    paires.append((ic, "Interface" + BS + "Icons" + BS
                   + "ability_warrior_bloodnova.blp"))
    return paires


def main():
    sauvegarde = G.ARCHIVE + ".avant_art_guerrier"
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
            if nom == "8fx_voldun_sethrak_cone.m2" and not CONE_EN_L_ETAT:
                donnees = prepare_cone(donnees)
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

        # --- SoundEntries : l'impact (one-shot) -------------------------------
        import struct
        brut, source = lit_effectif(dll, h, "SoundEntries.dbc")
        d = Dbc(brut)
        if d.nfield != 30:
            raise SystemExit("SoundEntries : %d champs, 30 attendus" % d.nfield)
        gabarit = None
        for i in range(d.nrec):
            off = i * d.rsize
            if struct.unpack_from("<I", d.enr, off)[0] == GABARIT_SON_IMPACT:
                gabarit = [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                           for k in range(30)]
        if gabarit is None:
            raise SystemExit("gabarit sonore %d absent" % GABARIT_SON_IMPACT)
        d.retire({SON_BOND_IMPACT})
        d.retire({SON_ODYN})

        def entree_son(ident, nom, fichier):
            v = list(gabarit)
            v[0] = ident
            v[2] = d.chaine(nom)
            for k in range(10):
                v[3 + k] = d.chaine(fichier) if k == 0 else 0
                v[13 + k] = 1 if k == 0 else 0
            v[23] = d.chaine("Sound" + BS + "Spells")
            return v

        d.pose(entree_son(SON_BOND_IMPACT, "PapotaBondImpact", FICHIER_SON))
        d.pose(entree_son(SON_ODYN, "PapotaOdynLancer", FICHIER_SON_ODYN))
        ecrit(dll, h, prefixe + "SoundEntries.dbc", d.octets())
        print("SoundEntries : %d (impact du bond) et %d (lancer d'Odyn)"
              " posés — base %s" % (SON_BOND_IMPACT, SON_ODYN, source))

        # --- SpellVisualEffectName --------------------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        d.retire({EFFET_BOND_VOL, EFFET_BOND_IMPACT, EFFET_ODYN_CONE})
        d.pose([EFFET_BOND_VOL, d.chaine("Bond heroique - vol"),
                d.chaine(MODELE_VOL), 1.0, 1.0, 0.01, 100.0])
        d.pose([EFFET_BOND_IMPACT, d.chaine("Bond heroique - impact"),
                d.chaine(MODELE_IMPACT), 1.0, 1.0, 0.01, 100.0])
        d.pose([EFFET_ODYN_CONE, d.chaine("Fureur d'Odyn - cone"),
                d.chaine(MODELE_ODYN), 0.0, 1.0, 0.01, 100.0])
        ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())
        print("SpellVisualEffectName : effets %d (vol), %d (impact) et %d"
              " (cone d'Odyn) posés"
              % (EFFET_BOND_VOL, EFFET_BOND_IMPACT, EFFET_ODYN_CONE))

        # --- SpellVisualKit ---------------------------------------------------
        # 38 champs (relevé gen_visuel_voleur) : effet au point d'attache Base
        # (champ 5), le son d'impact DANS le kit d'impact (champ 15), et les
        # ANIMATIONS au champ 2 (AnimationData) — le canal prouvé par le
        # lancer de la Marque (kit 30017, AttackThrown 107) puis par la passe
        # Ready2H/Attack2H (« ça fonctionne », 2026-08-30). Choix arrêté le
        # même jour (option 1) : Ready2H (27) TENU au vol, et la frappe
        # critique Special2H (58 — CombatCritical est la réaction de la
        # VICTIME) fondue dans le kit d'impact, à l'atterrissage. La caler
        # pour FINIR à l'impact est impossible : toutes les frappes font
        # 900-1500 ms (mesure M2 du 2026-08-30) contre 750 ms de vol maximal,
        # et aucun canal de 3.3.5 ne module la vitesse d'une animation. Le
        # kit 30029 de cette tentative est retiré.
        ANIM_READY2H = 27
        ANIM_SPECIAL2H = 58
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_BOND_VOL, KIT_BOND_IMPACT, KIT_ODYN_LANCER,
                  30029, 30032})
        d.pose([KIT_BOND_VOL, -1, ANIM_READY2H, 0, 0, EFFET_BOND_VOL]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_BOND_IMPACT, -1, ANIM_SPECIAL2H, 0, 0, EFFET_BOND_IMPACT]
               + [0] * 9 + [SON_BOND_IMPACT, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_ODYN_LANCER, -1, ANIM_SPECIAL1H] + [0] * 11
               + [EFFET_ODYN_CONE, SON_ODYN, 0] + [-1, -1, -1, -1]
               + [0] * 17)
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (vol, Ready2H), %d (impact + son"
              " + Special2H) et %d (lancer d'Odyn : anim + son + cone en"
              " EFFET MONDE) posés" % (KIT_BOND_VOL, KIT_BOND_IMPACT,
                                       KIT_ODYN_LANCER))

        # --- SpellVisual ------------------------------------------------------
        # Bond : l'impact sur les victimes, et rien d'autre. Odyn : la
        # charpente du 372 relevée telle quelle (champs 10=1 et 16=-1), notre
        # kit de lancer, l'impact sanglant natif 220 conservé.
        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL_BOND, VISUEL_ODYN})
        v = [0] * 32
        v[0] = VISUEL_BOND
        v[3] = KIT_IMPACT_NATIF
        d.pose(v)
        v = [0] * 32
        v[0] = VISUEL_ODYN
        v[2] = KIT_ODYN_LANCER
        v[3] = KIT_ODYN_IMPACT_NATIF
        v[10] = 1
        v[16] = 2               # la charpente de l'Onde de choc (10703)
        d.pose(v)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : visuels %d (impact natif %d seul) et %d (Odyn :"
              " lancer %d, impact natif %d) posés"
              % (VISUEL_BOND, KIT_IMPACT_NATIF, VISUEL_ODYN,
                 KIT_ODYN_LANCER, KIT_ODYN_IMPACT_NATIF))

        # --- SpellIcon --------------------------------------------------------
        brut, source = lit_effectif(dll, h, "SpellIcon.dbc")
        d = Dbc(brut)
        d.retire({ICONE_ODYN})
        d.pose([ICONE_ODYN, d.chaine("Interface" + BS + "Icons" + BS
                                     + "ability_warrior_bloodnova")])
        ecrit(dll, h, prefixe + "SpellIcon.dbc", d.octets())
        print("SpellIcon : %d -> ability_warrior_bloodnova — base %s"
              % (ICONE_ODYN, source))
    finally:
        dll.SFileCloseArchive(h)
    print("\nLes kits sont joués par SpherierSorts.cpp (spell_papota_bond_"
          "heroique) :\n  vol au départ du saut, impact à l'échéance de la spline.")


if __name__ == "__main__":
    main()
