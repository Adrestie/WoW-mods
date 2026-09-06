# -*- coding: utf-8 -*-
r"""Monte le visuel rétroporté du Jugement dernier (8600011) : la zone dorée.

Sources préparées dans `art_paladin\` (montage du 2026-08-30) : le modèle
kyrian cfx_kyrian_priest_holy_statechest (v264, chemins inscrits par
inscrit_textures.py, texUnitLookup sain), ses dix textures — les CINQ
porteuses de bleu redorées par dore_textures.py (DXT5, profil des imports
sains) —, l'icône moderne spell_holy_holyprotection et deux sons convertis
en WAV 22050 mono (le format des éprouvés).

Le montage s'appuie sur les RELEVÉS du 2026-08-30 :
  - le visuel 11182 (Consécration déchaînée, l'emprunt actuel) : Cast=165,
    Impact=121, missile 4197 (champs 7/8/10 = 1/4197/2, champ 13... brut
    relevé), attache -1, champ 21=13, et surtout le champ 25 — LE KIT DE
    ZONE PERSISTANTE (9366 chez elle) : c'est lui que le client joue sur la
    zone au sol pendant toute la vie de l'aura persistante.
  - le kit natif 165 (lancer sacré : anim 54, Base 211 Holy Precast Uber,
    mains 131) — CLONÉ en 30023 pour porter NOTRE son d'impact au lancement
    (on ne modifie jamais un kit natif partagé).
  - le son d'un kit PERSISTANT joue tant que le kit vit (précédent prouvé :
    le bourdon 3087 du Drain de vie) : la nappe est donc posée sur le kit de
    zone, gabarit SoundEntries 3087.

    python gen_visuel_paladin.py       (JEU FERMÉ requis : écrit dans patch-z)
"""
import ctypes as C
import io
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
from gen_visuel_aube import Dbc, stormlib, lit, ecrit
from gen_visuel_voleur import lit_effectif

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_paladin")

EFFET_JUGEMENT_ZONE = 8200215
KIT_JUGEMENT_LANCER = 30023
KIT_JUGEMENT_ZONE = 30024
VISUEL_JUGEMENT = 30023
ICONE_JUGEMENT = 8052
SON_JUGEMENT_IMPACT = 990102
SON_JUGEMENT_NAPPE = 990103

MODELE_ZONE = "spells" + BS + "cfx_kyrian_priest_holy_statechest.mdx"
# L'échelle du DBC est IGNORÉE par le rendu des kits de ZONE (constaté en
# jeu le 2026-08-30 — elle marche pourtant sur les kits d'état, cf. la
# marque à 0,15) : l'agrandissement se fait DANS LA GÉOMÉTRIE, à
# l'injection (ZONE_ECHELLE), et le bas du modèle est remonté au ras du sol
# (il pendait de -3,40 à +0,48 — un effet de torse, enterré en zone).
# CALIBRÉ PAR L'OBSERVATION (2026-08-30, cinq passes) — le mécanisme exact
# du rendu des kits de zone reste partiellement opaque, mais deux points de
# mesure encadrent la cible : la config (champ3=4,2 ; champ4=4,2 ;
# géométrie ×4,2) rendait une zone « quasiment bonne, un peu trop grande » ;
# en retirer champ4 et géométrie la rendait MINUSCULE (ces deux-là
# multiplient). On repart donc de la config calibrée en abaissant le seul
# champ 4 : ~−17 %. AJUSTEMENT = le cadran fin de la taille.
ECHELLE_ZONE = 4.2           # AreaEffectSize (champ 3) — tenu constant
ECHELLE_AJUSTEMENT = 4.2     # Scale (champ 4) — rendu à la référence : ses
                             # baisses (3,5 puis 3,15) mordaient a peine
ZONE_ECHELLE = 2.17          # LA GÉOMÉTRIE est le cadran : levier prouvé
                             # (4,2 -> 3,55 -> 3,0 -> 2,55 -> 2,17 : taille
                             # VALIDÉE en jeu le 2026-08-30)
ZONE_HAUTEUR = 0.125         # remontée SUPPLÉMENTAIRE au-dessus du ras du
                             # sol, en unités monde (0,5 -> 0,25 -> 0,125,
                             # réglé en jeu le 2026-08-30)
ZONE_SANS_PARTICULES = True  # quads en espace écran, 1re partie : l'unique
                             # émetteur de particules. Compte à zéro (0x128).
ZONE_SANS_RUBANS = True      # 2e partie (le résiduel constaté) : LES SEIZE
                             # RUBANS pendent tous sous l'os 1, drapeau
                             # 0x240 = BILLBOARD CYLINDRIQUE Z — tout le
                             # gréement se réoriente face à la caméra, d'où
                             # les traînées écran. Matériaux des rubans
                             # (0-2) disjoints du disque (3-4) : suppression
                             # sans perte pour le maillage. Compte à zéro
                             # (0x120). Alternative gardée en note : effacer
                             # le drapeau billboard de l'os 1 pour garder
                             # des rayons fixes dans le monde.

# Relevés natifs réutilisés tels quels (jamais modifiés) :
KIT_IMPACT_NATIF = 121       # l'impact sacré de la Consécration
EFFET_PRECAST_BASE = 211     # Holy Precast Uber Base (l'éclat au sol du lancer)
EFFET_PRECAST_MAIN = 131     # Holy Precast High Hand (les deux mains)
MISSILE_DECHAINEE = 4197     # le missile de la Consécration déchaînée
GABARIT_SON_IMPACT = 3011    # un son de sort one-shot (la Boule de feu)
GABARIT_SON_NAPPE = 3087     # le bourdon du Drain de vie : il BOUCLE

# --- le Bouclier de l'Inquisition (8600012, montage du 2026-08-30) -----------
# L'animation d'impact de la Bénédiction de garde-sorts (préparée par
# prepare_bouclier.py : trois textures dorées ET renommées _dore à la
# demande de l'utilisateur — flare_01/02, runeplane —, chemins inscrits),
# jouée aux pieds au LANCEMENT avec le son d'impact du Bouclier du
# vertueux ; icône moderne spell_holy_lastingdefense. La réduction de
# dégâts (-30 %) vit dans le DBC du sort (sorts_classes.py).
EFFET_BOUCLIER = 8200216
KIT_BOUCLIER = 30025
VISUEL_BOUCLIER = 30025
ICONE_BOUCLIER = 8053
SON_BOUCLIER = 990104
MODELE_BOUCLIER = ("spells" + BS
                   + "cfx_paladin_blessingofspellwarding_impactbase.mdx")
FICHIER_SON_BOUCLIER = "spell_pa_shieldoftherightious_impact.wav"

FICHIER_IMPACT = "spell_pr_revamp_holy_word_serenity_impact_02.wav"
FICHIER_NAPPE = "fx_holy_magic_missile_loop_01.wav"
# (remplace spell_pr_revamp_holy_precast_large_01.wav le 2026-08-30 — le
# fichier reste dans art_paladin, dormant, si retour en arrière voulu)


def repare_texunit(donnees, chemin_skin):
    """Garantit une table texUnitLookup suffisante pour les lots du skin —
    la cause de l'erreur 132 (table vide) et du mesh dégénéré (table trop
    courte), rencontrées TOUTES LES DEUX sur ce chantier. La forme attendue
    (relevé repare_m2_texunit) : table[texCombo + k] = k pour chaque unité k
    d'un lot. Calculée GÉNÉRIQUEMENT depuis le .skin, appliquée seulement si
    la table actuelle est trop courte (idempotent, append en fin de
    fichier + en-tête repointé à 0x88)."""
    import struct
    s = io.open(chemin_skin, "rb").read()
    _nI, _oI, _nT, _oT, _nP, _oP, nS, oS, nB, oB = struct.unpack_from("<10I", s, 4)
    table = {}
    for i in range(nB):
        champs = struct.unpack_from("<2BH5H2H2HH", s, oB + i * 24)
        opCount, texCombo = champs[8], champs[9]
        for k in range(opCount):
            table[texCombo + k] = k
    besoin = max(table) + 1 if table else 0

    donnees = bytearray(donnees)
    nT, _oT2 = struct.unpack_from("<2I", donnees, 0x88)
    if nT >= besoin:
        return bytes(donnees)
    valeurs = [table.get(i, 0) for i in range(besoin)]
    struct.pack_into("<2I", donnees, 0x88, besoin, len(donnees))
    donnees.extend(struct.pack("<%dH" % besoin, *valeurs))
    print("texUnitLookup réparée : %d -> %d entrées %s"
          % (nT, besoin, valeurs))
    return bytes(donnees)


def prepare_zone(donnees):
    """La zone prête à poser : géométrie ×ZONE_ECHELLE, bas remonté au ras
    du sol, rubans mis à l'échelle, et table texUnitLookup ÉTENDUE.

    Le glitch du 2026-08-30 (mesh dégénéré apparaissant en deux points,
    grossissant puis disparaissant, toutes les secondes) : le lot 1 du .skin
    lit ses DEUX unités au combo 2 d'une table texUnitLookup qui n'a que
    DEUX entrées — lecture hors bornes, la pathologie de l'erreur 132 en
    version rendu. La forme attendue (relevé repare_m2_texunit) : une entrée
    par unité, valant son propre rang — ici [0, 1, 0, 1] pour deux lots à
    deux unités. La table est APPENDUE en fin de fichier, l'en-tête repointé.

    Offsets M2 264 : sommets 0x3C (pas 48), os 0x2C (pas 88, pivot +76),
    rubans 0x120 (pas 176 : position +8, pistes heightAbove +76 et
    heightBelow +96 — LARGEURS des rubans, à mettre à l'échelle avec la
    géométrie), particules 0x128 (position +8), boîte 0xA0, rayon 0xB8,
    texUnitLookup 0x88."""
    import struct
    donnees = bytearray(donnees)

    n, ofs = struct.unpack_from("<2I", donnees, 0x3C)
    minz = min(struct.unpack_from("<3f", donnees, ofs + i * 48)[2]
               for i in range(n)) * ZONE_ECHELLE
    dz = -minz + ZONE_HAUTEUR

    def transforme(off, avec_dz=True):
        x, y, z = struct.unpack_from("<3f", donnees, off)
        struct.pack_into("<3f", donnees, off, x * ZONE_ECHELLE,
                         y * ZONE_ECHELLE,
                         z * ZONE_ECHELLE + (dz if avec_dz else 0.0))

    for i in range(n):
        transforme(ofs + i * 48)

    # LES OS PORTENT LE VISIBLE : le maillage n'est qu'un fin disque — les
    # seize rubans suivent des os ANIMÉS, et l'amplitude de leurs rayons
    # vient des PISTES DE TRANSLATION (constaté en jeu le 2026-08-30 :
    # sommets ×4,2 sans effet perceptible). On met donc à l'échelle les
    # VALEURS de translation de chaque os (piste à +12, valeurs vec3), avec
    # la remontée pour les os RACINES seulement (translation en espace
    # modèle) ; les pivots (+76, espace modèle) prennent échelle + remontée.
    nb, ofsb = struct.unpack_from("<2I", donnees, 0x2C)
    for i in range(nb):
        off = ofsb + i * 88
        parent = struct.unpack_from("<h", donnees, off + 8)[0]
        nV, ofsV = struct.unpack_from("<2I", donnees, off + 12 + 12)
        for k in range(nV):
            transforme(ofsV + k * 12, avec_dz=(parent == -1))
        transforme(off + 76)

    # Positions d'émetteurs : RELATIVES à leur os — échelle seule.
    np_, ofsp = struct.unpack_from("<2I", donnees, 0x128)
    for i in range(np_):
        transforme(ofsp + i * 492 + 8, avec_dz=False)
    if ZONE_SANS_PARTICULES:
        struct.pack_into("<I", donnees, 0x128, 0)

    nr, ofsr = struct.unpack_from("<2I", donnees, 0x120)
    for i in range(nr):
        transforme(ofsr + i * 176 + 8, avec_dz=False)
        for piste in (76, 96):          # largeurs au-dessus / au-dessous
            nV, ofsV = struct.unpack_from("<2I", donnees,
                                          ofsr + i * 176 + piste + 12)
            for k in range(nV):
                v = struct.unpack_from("<f", donnees, ofsV + k * 4)[0]
                struct.pack_into("<f", donnees, ofsV + k * 4,
                                 v * ZONE_ECHELLE)
    if ZONE_SANS_RUBANS:
        struct.pack_into("<I", donnees, 0x120, 0)

    mins, maxs, rayon = [1e9] * 3, [-1e9] * 3, 0.0
    for i in range(n):
        v = struct.unpack_from("<3f", donnees, ofs + i * 48)
        for k in range(3):
            mins[k] = min(mins[k], v[k])
            maxs[k] = max(maxs[k], v[k])
        rayon = max(rayon, (v[0] ** 2 + v[1] ** 2 + v[2] ** 2) ** 0.5)
    struct.pack_into("<6f", donnees, 0xA0, *(mins + maxs))
    struct.pack_into("<f", donnees, 0xB8, rayon)

    table = struct.pack("<4H", 0, 1, 0, 1)
    struct.pack_into("<2I", donnees, 0x88, 4, len(donnees))
    donnees.extend(table)
    return bytes(donnees)


def fichiers_a_injecter():
    paires = []
    for nom in sorted(os.listdir(os.path.join(ART, "spells"))):
        if nom.endswith((".m2", ".skin", ".blp")):
            paires.append((os.path.join(ART, "spells", nom), "spells" + BS + nom))
    ic = os.path.join(ART, "interface", "icons", "spell_holy_holyprotection.blp")
    paires.append((ic, "Interface" + BS + "Icons" + BS + "spell_holy_holyprotection.blp"))
    ic = os.path.join(ART, "interface", "icons", "spell_holy_lastingdefense.blp")
    paires.append((ic, "Interface" + BS + "Icons" + BS + "spell_holy_lastingdefense.blp"))
    for nom in sorted(os.listdir(os.path.join(ART, "sound", "spells"))):
        if nom.endswith(".wav"):
            paires.append((os.path.join(ART, "sound", "spells", nom),
                           "Sound" + BS + "Spells" + BS + nom))
    return paires


def main():
    sauvegarde = G.ARCHIVE + ".avant_art_paladin"
    if not os.path.exists(sauvegarde):
        print("sauvegarde de l'archive (une fois) : %s" % sauvegarde)
        shutil.copy2(G.ARCHIVE, sauvegarde)

    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        # Le M2 de la zone reçoit sa préparation AU PASSAGE (échelle, ras du
        # sol, table texUnitLookup) : la copie d'art_paladin reste l'export
        # préparé intact, le réglage est rejouable.
        paires = fichiers_a_injecter()
        tailles = {}
        for local, interne in paires:
            donnees = io.open(local, "rb").read()
            if interne.endswith("cfx_kyrian_priest_holy_statechest.m2"):
                donnees = prepare_zone(donnees)
            if interne.endswith("cfx_paladin_blessingofspellwarding_impactbase.m2"):
                donnees = repare_texunit(donnees, os.path.join(
                    ART, "spells",
                    "cfx_paladin_blessingofspellwarding_impactbase00.skin"))
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

        # --- SoundEntries : l'impact (one-shot) et la nappe (boucle) ----------
        import struct
        brut, source = lit_effectif(dll, h, "SoundEntries.dbc")
        d = Dbc(brut)
        if d.nfield != 30:
            raise SystemExit("SoundEntries : %d champs, 30 attendus" % d.nfield)

        def gabarit_de(ident):
            for i in range(d.nrec):
                off = i * d.rsize
                if struct.unpack_from("<I", d.enr, off)[0] == ident:
                    return [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                            for k in range(30)]
            raise SystemExit("gabarit sonore %d absent" % ident)

        gab_impact = gabarit_de(GABARIT_SON_IMPACT)
        gab_nappe = gabarit_de(GABARIT_SON_NAPPE)
        d.retire({SON_JUGEMENT_IMPACT, SON_JUGEMENT_NAPPE, SON_BOUCLIER})

        def entree_son(gabarit, ident, nom, fichier):
            v = list(gabarit)
            v[0] = ident
            v[2] = d.chaine(nom)
            for k in range(10):
                v[3 + k] = d.chaine(fichier) if k == 0 else 0
                v[13 + k] = 1 if k == 0 else 0
            v[23] = d.chaine("Sound" + BS + "Spells")
            return v

        d.pose(entree_son(gab_impact, SON_JUGEMENT_IMPACT,
                          "PapotaJugementImpact", FICHIER_IMPACT))
        d.pose(entree_son(gab_nappe, SON_JUGEMENT_NAPPE,
                          "PapotaJugementNappe", FICHIER_NAPPE))
        d.pose(entree_son(gab_impact, SON_BOUCLIER,
                          "PapotaBouclierImpact", FICHIER_SON_BOUCLIER))
        ecrit(dll, h, prefixe + "SoundEntries.dbc", d.octets())
        print("SoundEntries : %d (impact jugement), %d (nappe, gabarit %d — le"
              " bourdon du drain, il boucle) et %d (impact bouclier) posés"
              " — base %s"
              % (SON_JUGEMENT_IMPACT, SON_JUGEMENT_NAPPE, GABARIT_SON_NAPPE,
                 SON_BOUCLIER, source))

        # --- SpellVisualEffectName : la zone dorée ----------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        d.retire({EFFET_JUGEMENT_ZONE, EFFET_BOUCLIER})
        d.pose([EFFET_JUGEMENT_ZONE, d.chaine("Jugement dernier - zone"),
                d.chaine(MODELE_ZONE), ECHELLE_ZONE, ECHELLE_AJUSTEMENT,
                0.01, 100.0])
        d.pose([EFFET_BOUCLIER, d.chaine("Bouclier de l'Inquisition"),
                d.chaine(MODELE_BOUCLIER), 1.0, 1.0, 0.01, 100.0])
        ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())
        print("SpellVisualEffectName : effets %d (zone, échelle %.2f) et %d"
              " (bouclier) posés"
              % (EFFET_JUGEMENT_ZONE, ECHELLE_ZONE, EFFET_BOUCLIER))

        # --- SpellVisualKit ---------------------------------------------------
        # 38 champs (voir gen_visuel_voleur). Le LANCER clone le kit natif 165
        # (anim 54, Base 211, mains 131) avec NOTRE son d'impact ; la ZONE
        # porte le modèle doré en Base et la nappe en son — un kit PERSISTANT
        # fait boucler son entrée sonore (précédent du drain).
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_JUGEMENT_LANCER, KIT_JUGEMENT_ZONE, KIT_BOUCLIER})
        d.pose([KIT_JUGEMENT_LANCER, -1, 54, 0, 0, EFFET_PRECAST_BASE,
                EFFET_PRECAST_MAIN, EFFET_PRECAST_MAIN] + [0] * 7
               + [SON_JUGEMENT_IMPACT, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_JUGEMENT_ZONE, -1, -1, 0, 0, EFFET_JUGEMENT_ZONE]
               + [0] * 9 + [SON_JUGEMENT_NAPPE, 0]
               + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_BOUCLIER, -1, 54, 0, 0, EFFET_BOUCLIER]
               + [0] * 9 + [SON_BOUCLIER, 0]
               + [-1, -1, -1, -1] + [0] * 17)
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (lancer + impact sonore), %d (zone"
              " + nappe) et %d (bouclier) posés"
              % (KIT_JUGEMENT_LANCER, KIT_JUGEMENT_ZONE, KIT_BOUCLIER))

        # --- SpellVisual ------------------------------------------------------
        # La structure du 11182 relevée telle quelle : lancer, impact natif
        # 121, missile de la déchaînée (7/8/10), attache -1 (16), champ 21=13,
        # et NOTRE kit de zone persistante au champ 25.
        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL_JUGEMENT, VISUEL_BOUCLIER})
        v = [0] * 32
        v[0] = VISUEL_JUGEMENT
        v[2] = KIT_JUGEMENT_LANCER
        v[3] = KIT_IMPACT_NATIF
        v[7] = 1
        v[8] = MISSILE_DECHAINEE
        v[10] = 2
        v[16] = -1
        v[21] = 13
        v[25] = KIT_JUGEMENT_ZONE
        d.pose(v)
        b = [0] * 32
        b[0] = VISUEL_BOUCLIER
        b[2] = KIT_BOUCLIER
        d.pose(b)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : visuels %d (zone persistante au champ 25) et %d"
              " (bouclier, kit de lancer seul) posés"
              % (VISUEL_JUGEMENT, VISUEL_BOUCLIER))

        # --- SpellIcon --------------------------------------------------------
        brut, source = lit_effectif(dll, h, "SpellIcon.dbc")
        d = Dbc(brut)
        d.retire({ICONE_JUGEMENT, ICONE_BOUCLIER})
        d.pose([ICONE_JUGEMENT,
                d.chaine("Interface" + BS + "Icons" + BS + "spell_holy_holyprotection")])
        d.pose([ICONE_BOUCLIER,
                d.chaine("Interface" + BS + "Icons" + BS + "spell_holy_lastingdefense")])
        ecrit(dll, h, prefixe + "SpellIcon.dbc", d.octets())
        print("SpellIcon : %d -> spell_holy_holyprotection, %d ->"
              " spell_holy_lastingdefense — base %s"
              % (ICONE_JUGEMENT, ICONE_BOUCLIER, source))
    finally:
        dll.SFileCloseArchive(h)
    print("\nLe sort pointe ces ids via sorts_classes.py : régénérer par"
          "\n  python gen_sorts_classes.py --deploy   puis rejouer le SQL au démarrage.")


if __name__ == "__main__":
    main()
