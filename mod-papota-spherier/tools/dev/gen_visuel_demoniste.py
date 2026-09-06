# -*- coding: utf-8 -*-
r"""Monte le visuel de la Singularité fantomatique du démoniste (8600081).

Art exporté par l'utilisateur le 2026-09-03 depuis un client moderne :

  - `spells\mannoroth_gooflowshadow_state_projected.m2` — un DÉCAL AU SOL
    PROJETÉ, en remplacement du premier essai (`7fx_targetground_shadow`,
    retiré le jour même) : DEUX quads superposés de 4 sommets chacun, sans
    particule ni ruban, trois textures et quatre séquences (127, 0, 158, 159)
    toutes EMBARQUÉES (bit 0x20 des drapeaux) — aucun `.anim` à convertir,
    aucune séquence hors du barème 3.3.5 (qui s'arrête à 505). Chaque lot lit
    DEUX unités de texture (`textureCombos` = [0, 1, 2], combo 0), ce que le
    client 3.3.5 sait faire nativement. Converti en MD20 v264 par
    MultiConverter, chemins de textures réinscrits par inscrit_textures.py.
  - `spells\impact_shadow_chest.m2` — L'ÉCLAT SUR LES ENNEMIS DRAINÉS :
    aucune géométrie, trois émetteurs de particules sur quatre os, quatre
    textures, UNE séquence de 2 000 ms qui NE BOUCLE PAS (drapeaux 0xA0, bit
    0x1 absent). Sa boîte englobante est la sentinelle 1e7 des effets de
    particules — « toujours visible », à ne pas prendre pour une mesure.
    Accroché au TORSE par le champ 4 du kit (`ChestEffect`), qui est
    exactement l'emplacement que son nom annonce.
  - `interface\icons\spell_shadow_mindtwisting.blp` — l'icône ;
  - `sound\spells\spell_wl_focusshadow_impact_03.ogg` — le son, transcodé en
    WAV PCM 16 bits mono 22 050 Hz (le format des sons déjà posés).

ÉCHELLE — SE MESURE AU MILIEU D'UN BORD, JAMAIS AUX SOMMETS. Le halo est un
disque peint sur un CARRÉ : le cercle visible est celui INSCRIT dans le carré,
et son rayon est la distance du centre au milieu d'un bord (l'apothème), pas
au coin. Le coin est plus loin d'un facteur racine de deux, et s'y fier avait
donné un effet une fois et demie trop grand (8,882 m au lieu de 6,574 m).

Relevé sur le modèle converti, en ne gardant que les arêtes appartenant à UN
SEUL triangle — celles partagées par deux triangles sont les diagonales du
quad, dont le milieu tombe sur le centre :

    carré du bas (section 0, z = 0)      : bords à 6,5743 m du centre
    carré du haut (section 1, z = 0,106) : bords à 6,3902 m du centre

C'est le plus grand qui borne ce qu'on voit : RAYON_MODELE_SINGULARITE.

SOULÈVEMENT : le carré du bas est exactement à z = 0 et se battait avec le sol
(z-fighting). On relève toute la géométrie de SOULEVEMENT_SINGULARITE mètres
DE JEU — donc divisés par l'échelle avant d'être écrits dans le modèle, qui
vit en unités d'avant mise à l'échelle.

ÉCHELLE DES UV — LE VRAI COUPABLE. La géométrie ne suffit pas : une
`M2TextureTransform` multiplie les coordonnées de texture, et une valeur
SUPÉRIEURE À 1 RÉTRÉCIT le motif d'autant. La couche extérieure (unité 0,
`creepingmoss_shadow_radial_blendadd`) portait une échelle UV comprise entre
1,039 et 1,196 : son halo ne couvrait que 0,84 à 0,96 du cercle inscrit, soit
8,4 à 9,6 m au lieu de 10. La géométrie avait beau être exacte, l'effet
paraissait trop petit.

Pire, cette piste est pilotée par la SÉQUENCE GLOBALE 1, qui ne dure que
2 976 ms alors que la piste s'étend sur 29 988 ms : seules les deux premières
clés sont jamais atteintes, et l'échelle reste bloquée autour de 1,19. Le
« battement » ne bat pas. On la remet donc à 1,0 (`neutralise_echelle_uv`) :
le halo colle alors exactement au cercle inscrit, donc au rayon du sort.

La transformation 1 (unité 1, la vague violette) N'EST PAS touchée : sa
séquence globale 3 dure 20 933 ms, exactement la longueur de sa piste, elle
respire donc pour de vrai, et sa texture s'éteint dès 0,94 en UV — elle reste
largement à l'intérieur de l'anneau extérieur. Y toucher ne ferait que
détruire l'animation voulue par l'artiste.

    python gen_visuel_demoniste.py     (JEU FERMÉ requis : écrit dans patch-z)
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
from gen_visuel_voleur import lit_effectif
# Le retroportage d'un modele de creature est le meme travail que pour
# l'ascendant du chaman : on reprend ses fonctions plutot que de les recopier.
# Voir RETROPORTAGE_M2.md pour le detail de chaque etape.
from gen_visuel_chaman import (anims_convertis, neutralise_sequences_impossibles,
                               repare_bonecountmax, texte)

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_demoniste")

# --- la Singularité fantomatique (8600081) ---------------------------------
MODELE_SINGULARITE = ("spells" + BS
                      + "mannoroth_gooflowshadow_state_projected.mdx")
TEXTURES_SINGULARITE = ("creepingmoss_shadow_radial_blendadd.blp",
                        "radial_wave_purple_blendadd.blp",
                        "defile1.blp")
RAYON_SINGULARITE = 8.0            # le rayon du sort (R_8, sorts_classes.py)
RAYON_MODELE_SINGULARITE = 6.5743  # milieu d'un bord du grand carré au centre
# DÉBORDEMENT VOULU (2026-09-03) : le halo colle au rayon du sort au pixel
# près, mais son bord s'éteint en fondu — l'œil place la limite un peu en
# deçà. On le fait donc déborder, à la demande : trois hausses de 10 %
# successives, soit 1,10 puissance 3. C'est un réglage de confort, pas une
# correction — le rapport ci-dessus reste exact, et il n'agit QUE sur le
# décal : le rayon du sort et le réticule viennent de SpellRadius.dbc
# (index 13 = 10 m), auquel ce fichier ne touche pas.
MARGE_SINGULARITE = 1.10 ** 3
ECHELLE_SINGULARITE = (RAYON_SINGULARITE / RAYON_MODELE_SINGULARITE
                       * MARGE_SINGULARITE)
SOULEVEMENT_SINGULARITE = 0.10     # mètres de jeu au-dessus du sol
# La transformation UV de la couche EXTÉRIEURE, à remettre à 1,0 : c'est elle
# qui décidait de la taille apparente du halo. La 1 (vague intérieure) reste.
TRANSFOS_UV_A_PLAT = (0,)

EFFET_SINGULARITE = 8200234
KIT_SINGULARITE_SON = 30079   # le son, au lancement
KIT_SINGULARITE_ZONE = 30080  # le décal, tant que la zone vit
VISUEL_SINGULARITE = 30079

# --- l'éclat porté par les ennemis drainés ---------------------------------
# Le décal dit OÙ frappe la zone ; l'éclat dit QUI elle frappe. C'est le KIT
# D'ÉTAT du visuel de la zone (champ 4 de SpellVisual) : le client pose alors
# le modèle sur CHAQUE unité portant l'aura et l'y laisse tant qu'elle dure,
# une source par unité. Rien à scripter.
#
# C'est la mécanique NATIVE : 128 sorts de Blizzard à aura de zone persistante
# (effet 27) portent un kit d'état — la Pluie de feu (4629) le kit 235
# (Immolate_State_Base), les nuages toxiques le 1805 (GreenGhost_state), tous
# accrochés comme ici par un champ d'emplacement du kit. Le nôtre prend le
# champ 4 (Chest), exactement ce que le nom du modèle annonce.
#
# Deux essais ont précédé, tous deux abandonnés le 2026-09-03 : un sort porteur
# lancé sur chaque ennemi (le client suit les visuels par couple lanceur/sort,
# donc deux ennemis touchés dans le même instant n'en montraient qu'un), puis
# SMSG_PLAY_SPELL_VISUAL relancé par script. Le kit d'état fait les deux mieux
# et sans code, la séquence du modèle étant un Stand (id 0) que le client
# rejoue en boucle.
MODELE_ECLAT = "spells" + BS + "impact_shadow_chest.mdx"
TEXTURES_ECLAT = ("smoke_puffy_mask_verysoft.blp",
                  "dirt_scroll_wispy_purple1.blp",
                  "t_vfx_flar_blur_64.blp",
                  "fire_2x2_sharp_mod4x_blurred.blp")
EFFET_ECLAT = 8200235
KIT_ECLAT = 30081      # kit d'ÉTAT : le client le pose sur chaque unité sous
                       # l'aura, et l'y laisse tant qu'elle dure.
VISUEL_ECLAT = 30080   # RETIRÉ : posé le 2026-09-03 pour un sort porteur qui
                       # n'existe plus. On le retire de la table pour ne pas y
                       # laisser une ligne morte.

ICONE_SINGULARITE = 8072
NOM_ICONE_SINGULARITE = "spell_shadow_mindtwisting"
SON_SINGULARITE = 990122
FICHIER_SON_SINGULARITE = "singularite_cast.wav"

GABARIT_SON = 3011            # « un coup » : le gabarit sonore du chantier

# --- le tyran demoniaque (8600082) -----------------------------------------
# Modele exporte le 2026-09-03 : `DemonicTyrant.m2`, dont l'art vit sous
# `creature\eredarbrutemalearmored`. TOUT porte le meme radical parce que le
# client deduit du nom du .m2 celui des .skin et des .anim.
#
# Bien plus sain que l'ascendant du chaman : 51 os par section au maximum,
# LARGEMENT sous la limite fatale de 75 (RETROPORTAGE_M2.md §1), et les cinq
# sequences externes ont toutes leur .anim. Restent deux corrections :
#   - 9 sequences portent un identifiant au-dela de 505, la ou s'arrete
#     AnimationData.dbc : le client les cherche au chargement, ne les trouve
#     pas, et tombe. Elles sont rendues inatteignables ;
#   - les .anim modernes commencent par un chunk `AFM2` de huit octets, que
#     3.3.5 ne connait pas.
DOSSIER_TYRAN = "creature" + BS + "eredarbrutemalearmored"
RADICAL_TYRAN = "eredarbrutemalearmored"
MODELE_TYRAN = DOSSIER_TYRAN + BS + RADICAL_TYRAN + ".mdx"
# Les deux textures VARIABLES (types 11 et 12 du M2) que CreatureDisplayInfo
# remplit. La troisieme, le reflet d'armure, est de type 0 : son chemin est
# inscrit dans le modele lui-meme (inscrit_textures.py).
TEXTURES_TYRAN = ("eredarbrutemalearmor_green",
                  "eredarbrutemalearmor_glow_green")
ECHELLE_TYRAN = 1.0
MODELE_DATA_TYRAN = 802130
DISPLAY_TYRAN = 802130
CREATURE_TYRAN = 803802       # « Garde funeste du tyran », renommee

ICONE_TYRAN = 8073
NOM_ICONE_TYRAN = "ability_demonhunter_torment"

# --- les visuels des bonus du tyran ----------------------------------------
# Tous en kit d'ETAT (champ 4 du SpellVisual) : le client pose le modele sur
# l'unite portant l'aura et l'y laisse tant qu'elle dure. Les kits sont NATIFS
# et jamais modifies, seulement references.
# (L'ANNEAU DE FEU — kit 30086, modele Spells\HellFire_Area_Base.mdx au point
# Base — a ete RETIRE le 2026-09-03 avec la zone de degats qu'il annoncait.
# Les deux identifiants restent listes plus bas pour que leurs lignes soient
# EFFACEES des tables, et non laissees mortes.)
KIT_ANNEAU_FEU = 30086
KIT_MAINS_FEU = 38       # Fire_Cast_Hand, les deux mains (Trait de feu)
KIT_RAGE = 12178         # BeastRageState, a la tete (Enrager)
EFFET_BOUCLIER_OMBRE = 834   # shadowshield_state_base

VISUEL_FLAMMES = 30082   # sur le tyran : l'anneau, SANS canalisation
VISUEL_MAINS = 30083     # sur le diablotin
VISUEL_BOUCLIER = 30084  # sur le marcheur du vide
KIT_BOUCLIER = 30084
VISUEL_RAGE = 30085      # sur les demons de Xer'thul et le demon asservi

# --- le Cataclysme (8600083) ------------------------------------------------
# LE MISSILE DU CATACLYSME, quatrieme essai (2026-09-03). Les trois
# premiers ont ete ecartes ; le defaut commun aux deux derniers a fini
# par se voir : leurs RUBANS declarent TROIS indices de texture pour UN
# SEUL materiau, et le client 3.3.5 parcourt les deux tableaux ensemble.
# Il lisait donc deux materiaux hors des bornes et rendait la trainee
# avec un fondu pris au hasard de la memoire — le « probleme de blend ».
# gen_visuel_aube.ecrit() accorde desormais les deux tableaux pour TOUT
# modele qui entre dans l'archive, celui-ci comme les suivants.
MODELE_CATACLYSME = ("spells" + BS
                     + "cfx_azerite_crucibleofflame_major_rank4_missile.mdx")
TEXTURES_CATACLYSME = (
    "papota_7fx_alphamask_glow_donut2.blp",
    "papota_7fx_wind_rift_double_thick_ba.blp",
    "papota_8fx_azerite_glow.blp",
    "papota_8fx_rage_mask_azerite.blp",
    "papota_cfx_azerite_purificationblast_major_rank4_state_hostile_25_2983925.blp",
    "papota_cfx_azerite_purificationblast_major_rank4_state_hostile_27_2983927.blp",
    "papota_cfx_azerite_unboundforce_major_2991592.blp",
    "papota_ember_offset_grey.blp",
    "papota_fb_azeriteshimmer_colored_ba_512x256.blp",
    "papota_flare1_tc_green3.blp",
    "papota_flare1_tc_shadowcombo_priest2.blp",
    "papota_fx_vilebreath_precast_2958226.blp",
    "papota_generic_maskbasic_warlock_ba.blp",
    "papota_grey50percentsquare16x16.blp",
    "papota_shockwave_spikey_bright_ba.blp",
    "papota_smoke_loose_02_256_blend_contrast.blp",
    "papota_urn_mist_flipped_azerite_thicker.blp",
    "papota_white8x8.blp",
    "papota_wispymagic_vert_azeritemist_blue_128_greyrotate_blend.blp",
    "papota_wispymagic_vert_azeritemist_blue_128_greyrotate_solid.blp",
    "papota_wispymagic_vert_azeritemist_blue_128_lessalpha_sphere_grey.blp",
    "papota_wispymagic_vert_azeritemist_yellow_128.blp",
    "papota_wispymagic_vert_azeritemist_yellow_128_thickalpha.blp",
    "papota_wispymagic_vert_azeritemist_yellowrotate_128.blp",
)
# BISSECTION (2026-09-03) : les rubans du missile sont ETEINTS le temps de
# savoir s'ils portent le defaut de blend. Trois hypotheses ont deja ete
# ecartees par la mesure — boneCountMax (repare, mais ce n'etait pas cela), le
# desaccord texture/materiau des rubans (repare aussi, insuffisant) et le
# blendingType des particules (4 partout, soit la valeur dominante des
# natifs : 294 occurrences sur 319 relevees). Il reste les rubans eux-memes.
# Mettre a zero le nombre de bords emis par seconde les coupe VRAIMENT — la
# duree de vie a 0,01 laissait encore une trainee (releve du 2026-08-29 sur le
# grappin). A remettre a False si le defaut persiste : ce sera les particules.
RUBANS_ETEINTS = True


def eteint_rubans(donnees_m2):
    """Coupe l'emission de tous les rubans : zero bord par seconde."""
    m2 = bytearray(donnees_m2)
    nr, orb = struct.unpack_from("<2I", m2, 0x120)
    for i in range(nr):
        struct.pack_into("<f", m2, orb + i * 176 + 116, 0.0)
    if nr:
        print("rubans éteints : %d (bissection)" % nr)
    return bytes(m2)


EFFET_CATACLYSME = 8200236     # le missile
KIT_CATACLYSME_SON = 30087     # le son, au lancement
VISUEL_CATACLYSME = 30087

ICONE_CATACLYSME = 8074
NOM_ICONE_CATACLYSME = "ability_warlock_shadowfurytga"
SON_CATACLYSME = 990123
FICHIER_SON_CATACLYSME = "cataclysme_cast.wav"

DBC_SERVEUR_DIR = os.path.join(
    r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo", "Data", "dbc")


def pose_tyran(cmd, cdi):
    """Le modele et l'apparence du tyran : clone du Poulet — le gabarit du
    chantier, deja employe pour l'ascendant —, dont on ne change que le
    chemin, l'echelle et les deux textures de variante."""
    if cmd.nfield != 28 or cdi.nfield != 16:
        raise SystemExit("CreatureModelData/DisplayInfo : champs inattendus")
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

    cmd.retire({MODELE_DATA_TYRAN})
    modele = list(poulet)
    modele[0] = MODELE_DATA_TYRAN
    modele[2] = cmd.chaine(MODELE_TYRAN)
    modele[4] = struct.unpack("<I", struct.pack("<f", ECHELLE_TYRAN))[0]
    # Sang, empreintes et sons du poulet : rien a voir avec un eredar.
    for k in range(5, 14):
        modele[k] = 0
    cmd.pose(modele)

    cdi.retire({DISPLAY_TYRAN})
    cdi.pose([DISPLAY_TYRAN, MODELE_DATA_TYRAN, 0, 0,
              struct.unpack("<I", struct.pack("<f", 1.0))[0], 255,
              cdi.chaine(TEXTURES_TYRAN[0]),
              cdi.chaine(TEXTURES_TYRAN[1]),
              0, 0, 0, 0, 0, 0, 0, 0])


def prepare_tyran():
    """Le modele, les skins et les .anim du tyran, corriges en memoire.

    Le dossier source n'est JAMAIS modifie : on rend le contenu a injecter."""
    dossier = os.path.join(ART, "creature", RADICAL_TYRAN)
    prepares = {}

    m2 = io.open(os.path.join(dossier, RADICAL_TYRAN + ".m2"), "rb").read()
    if m2[:4] != b"MD20" or struct.unpack_from("<I", m2, 4)[0] != 264:
        raise SystemExit("%s n'est pas du MD20 v264 : passer MultiConverter"
                         " puis inscrit_textures.py" % RADICAL_TYRAN)
    prepares[DOSSIER_TYRAN + BS + RADICAL_TYRAN + ".m2"] = \
        neutralise_sequences_impossibles(m2, dossier)

    for nom, contenu in anims_convertis(dossier).items():
        prepares[DOSSIER_TYRAN + BS + nom] = contenu

    for nom in os.listdir(dossier):
        if nom.endswith(".skin") and "_lod" not in nom:
            brut = io.open(os.path.join(dossier, nom), "rb").read()
            prepares[DOSSIER_TYRAN + BS + nom] = repare_bonecountmax(brut)
    return prepares


PREFIXE = "papota_"

# Le remappage de teinte est defini UNE FOIS, dans recolore_cataclysme : les
# textures et les emetteurs doivent virer ensemble, sans quoi le missile
# melangerait deux palettes.
from recolore_cataclysme import BANDES, ECLAT, RESSERRE, ecart_cyclique

# LES BLANCS PURS DEVIENNENT VIOLETS (demande du 2026-09-03). Un blanc n'a pas
# de teinte : on ne peut pas la faire tourner, il faut lui en DONNER une, et
# donc une saturation. Les noirs — les fins de fondu — restent noirs : les
# teinter ne se verrait pas et fausserait l'extinction.
VIOLET = 280.0 / 360.0
VIOLET_SATURATION = 0.55
VALEUR_MIN_VIOLET = 0.05   # en deca, c'est un noir de fondu : intact


def recolore_emetteurs(donnees_m2):
    """Reteinte les pistes de couleur des emetteurs de particules.

    Un `M2Particle` de 3.3.5 fait 476 octets et porte sa piste de couleur en
    `M2PartTrack` : les temps a +0x104, les valeurs a +0x10C — trois flottants
    de 0 a 255 par cle. C'est LA que vivent le bleu et le jaune du missile ;
    les textures des emetteurs sont des masques gris. Les cles sans saturation
    (les blancs, les noirs) gardent leur teinte : elles n'en ont pas."""
    import colorsys
    m2 = bytearray(donnees_m2)
    np_, op = struct.unpack_from("<2I", m2, 0x128)
    cles = blancs = 0
    for i in range(np_):
        n, ofs = struct.unpack_from("<2I", m2, op + i * 476 + 0x10C)
        for k in range(n):
            o = ofs + k * 12
            if o + 12 > len(m2):
                break
            r, v, b = struct.unpack_from("<3f", m2, o)
            h, sat, val = colorsys.rgb_to_hsv(min(r, 255.0) / 255.0,
                                              min(v, 255.0) / 255.0,
                                              min(b, 255.0) / 255.0)
            if sat >= 0.10:
                pivot, cible, _nom = min(
                    BANDES, key=lambda z: abs(ecart_cyclique(h, z[0])))
                h = (cible + ecart_cyclique(h, pivot) * RESSERRE) % 1.0
                cles += 1
            elif val > VALEUR_MIN_VIOLET:
                # Blanc ou gris clair : on lui DONNE la teinte violette.
                h, sat = VIOLET, VIOLET_SATURATION
                blancs += 1
            nr, nv, nb = colorsys.hsv_to_rgb(h, sat, val * ECLAT)
            struct.pack_into("<3f", m2, o, nr * 255.0, nv * 255.0, nb * 255.0)
    if cles or blancs:
        print("émetteurs reteintés : %d clé(s) colorée(s) remappée(s) et %d"
              " blanc(s) passé(s) au violet, sur %d émetteur(s)"
              % (cles, blancs, np_))
    return bytes(m2)


def prefixe_textures(donnees_m2, prefixe=PREFIXE):
    """Reecrit les chemins de texture du modele avec un prefixe a nous.

    NECESSAIRE, et pas seulement propre : `patch-c.mpq` porte deja, sous
    leurs noms d'origine, les textures de plusieurs effets modernes. Le
    client lit CELLES-LA et ignore les notres, ecrites dans patch-z sous
    les memes noms — les recolorations n'apparaissaient pas (releve du
    2026-09-03). Un nom qui n'appartient qu'a nous met fin a la question.

    Les chaines sont AJOUTEES en fin de fichier et les couples
    longueur/decalage reecrits, comme le fait inscrit_textures : on ne
    touche pas au bloc existant, dont d'autres decalages dependent."""
    m2 = bytearray(donnees_m2)
    nt, ot = struct.unpack_from("<2I", m2, 0x50)
    faits = 0
    for i in range(nt):
        off = ot + i * 16
        typ, _fl, lg, ofs = struct.unpack_from("<4I", m2, off)
        if typ != 0 or lg <= 1:
            continue                      # texture variable : pas de chemin
        ancien = bytes(m2[ofs:ofs + lg - 1]).decode("latin-1")
        base = ancien.rsplit(chr(92), 1)[-1]
        if base.startswith(prefixe):
            continue                      # deja fait, on est idempotent
        neuf = (ancien.rsplit(chr(92), 1)[0] + chr(92) + prefixe + base
                if chr(92) in ancien else prefixe + base)
        octets = neuf.encode("latin-1") + b"\x00"
        struct.pack_into("<2I", m2, off + 8, len(octets), len(m2))
        m2.extend(octets)
        faits += 1
    if faits:
        print("textures prefixees dans le modele : %d" % faits)
    return bytes(m2)


def souleve_decal(donnees, hauteur):
    """Relève toute la géométrie de `hauteur` mètres de jeu, pour que le décal
    ne se batte plus avec le sol. Le modèle vit en unités d'AVANT mise à
    l'échelle : on divise donc par l'échelle pour que le décalage vaille bien
    `hauteur` une fois le modèle agrandi. La boîte englobante suit."""
    m2 = bytearray(donnees)
    pas = hauteur / ECHELLE_SINGULARITE
    nv, ov = struct.unpack_from("<2I", m2, 0x3C)
    for i in range(nv):
        o = ov + i * 48 + 8            # le z du M2Vertex
        struct.pack_into("<f", m2, o,
                         struct.unpack_from("<f", m2, o)[0] + pas)
    for o in (0xA0 + 8, 0xA0 + 20):    # z du minimum, puis du maximum
        struct.pack_into("<f", m2, o,
                         struct.unpack_from("<f", m2, o)[0] + pas)
    return bytes(m2)


def neutralise_echelle_uv(donnees, indices):
    """Remet à 1,0 l'échelle UV des transformations `indices`, sans toucher à
    leur rotation ni à leur translation. Une échelle UV supérieure à 1 rétrécit
    le motif : c'est ce qui faisait un halo plus petit que la zone d'effet."""
    m2 = bytearray(donnees)
    nt, ot = struct.unpack_from("<2I", m2, 0x60)
    touchees = 0
    for i in indices:
        if i >= nt:
            raise SystemExit("transformation UV %d absente (il y en a %d)"
                             % (i, nt))
        # M2TextureTransform = translation(20) rotation(20) echelle(20).
        # M2Track = interp(2) gseq(2) temps(8) valeurs(8) ; les valeurs sont un
        # tableau de tableaux, un par séquence.
        piste = ot + i * 60 + 40
        nvs, ovs = struct.unpack_from("<2I", m2, piste + 12)
        for k in range(nvs):
            n, ofs = struct.unpack_from("<2I", m2, ovs + k * 8)
            for j in range(n):
                struct.pack_into("<2f", m2, ofs + j * 12, 1.0, 1.0)
                touchees += 1
    return bytes(m2), touchees


def fichiers_a_injecter():
    """Les fichiers locaux et leur chemin dans l'archive."""
    paires = []
    for nom in (("mannoroth_gooflowshadow_state_projected.m2",
                 "mannoroth_gooflowshadow_state_projected00.skin",
                 "impact_shadow_chest.m2", "impact_shadow_chest00.skin",
                 "cfx_azerite_crucibleofflame_major_rank4_missile.m2",
                 "cfx_azerite_crucibleofflame_major_rank4_missile00.skin")
                + TEXTURES_SINGULARITE + TEXTURES_ECLAT
                + TEXTURES_CATACLYSME):
        paires.append((os.path.join(ART, "spells", nom), "spells" + BS + nom))
    paires.append((os.path.join(ART, "interface", "icons",
                                NOM_ICONE_SINGULARITE + ".blp"),
                   "Interface" + BS + "Icons" + BS
                   + NOM_ICONE_SINGULARITE + ".blp"))
    paires.append((os.path.join(ART, "sound", "spells",
                                FICHIER_SON_SINGULARITE),
                   "Sound" + BS + "Spells" + BS + FICHIER_SON_SINGULARITE))
    for nom_icone in (NOM_ICONE_TYRAN, NOM_ICONE_CATACLYSME):
        paires.append((os.path.join(ART, "interface", "icons",
                                    nom_icone + ".blp"),
                       "Interface" + BS + "Icons" + BS + nom_icone + ".blp"))
    paires.append((os.path.join(ART, "sound", "spells",
                                FICHIER_SON_CATACLYSME),
                   "Sound" + BS + "Spells" + BS + FICHIER_SON_CATACLYSME))
    # Le tyran : modele, skins (sans les LOD, que 3.3.5 ne lit pas), .anim et
    # textures. Les trois premiers passent par prepare_tyran ; les .blp sont
    # copies tels quels.
    dossier = os.path.join(ART, "creature", RADICAL_TYRAN)
    for nom in sorted(os.listdir(dossier)):
        if nom.endswith(".manifest.json") or "_lod" in nom:
            continue
        if nom.endswith((".m2", ".skin", ".anim", ".blp")):
            paires.append((os.path.join(dossier, nom),
                           DOSSIER_TYRAN + BS + nom))
    return paires


def main():
    # GARDE-FOU : le client 3.3.5 ne lit que le MD20 v264. Un export brut
    # (MD21) recopié par-dessus le converti passerait inaperçu jusqu'au crash.
    for nom in ("mannoroth_gooflowshadow_state_projected.m2",
                "impact_shadow_chest.m2",
                "cfx_azerite_crucibleofflame_major_rank4_missile.m2"):
        m2 = os.path.join(ART, "spells", nom)
        with io.open(m2, "rb") as f:
            entete = f.read(8)
        if entete[:4] != b"MD20" or struct.unpack_from("<I", entete, 4)[0] != 264:
            raise SystemExit("%s n'est pas du MD20 v264 : passer MultiConverter"
                             " puis inscrit_textures.py avant de déployer" % m2)

    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        paires = fichiers_a_injecter()
        prepares = prepare_tyran()
        tailles = {}
        for local, interne in paires:
            donnees = prepares.get(interne)
            if donnees is None:
                donnees = io.open(local, "rb").read()
                # TOUT skin injecte passe par la. `boneCountMax` est laisse a
                # ZERO par l'export, et le client dimensionne sur ce champ le
                # tampon des matrices d'os avant d'y ecrire une entree par os
                # de la section : a zero, il ecrit hors de l'allocation.
                # C'est la cause du plantage de l'ascendant du chaman
                # (RETROPORTAGE_M2.md, section 1) ; sur un effet de sort, cela
                # se voit comme des materiaux casses. Les skins du tyran sont
                # deja passes par prepare_tyran, d'ou le `prepares.get` avant.
                if local.endswith(".skin"):
                    donnees = repare_bonecountmax(donnees)
            if local.endswith("crucibleofflame_major_rank4_missile.m2"):
                donnees = prefixe_textures(donnees)
                donnees = recolore_emetteurs(donnees)
                if RUBANS_ETEINTS:
                    donnees = eteint_rubans(donnees)
            if local.endswith("mannoroth_gooflowshadow_state_projected.m2"):
                donnees = souleve_decal(donnees, SOULEVEMENT_SINGULARITE)
                donnees, cles = neutralise_echelle_uv(donnees,
                                                      TRANSFOS_UV_A_PLAT)
                print("échelle UV remise à 1,0 : %d clé(s) sur la ou les"
                      " transformation(s) %s"
                      % (cles, list(TRANSFOS_UV_A_PLAT)))
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
        icones = ((ICONE_SINGULARITE, NOM_ICONE_SINGULARITE),
                  (ICONE_TYRAN, NOM_ICONE_TYRAN),
                  (ICONE_CATACLYSME, NOM_ICONE_CATACLYSME))
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
                break
        if gabarit is None:
            raise SystemExit("gabarit sonore %d absent" % GABARIT_SON)
        sons = ((SON_SINGULARITE, "PapotaSingularite", FICHIER_SON_SINGULARITE),
                (SON_CATACLYSME, "PapotaCataclysme", FICHIER_SON_CATACLYSME))
        d.retire({ident for ident, _n, _f in sons})
        for ident, nom_son, fichier in sons:
            v = list(gabarit)
            v[0] = ident
            v[2] = d.chaine(nom_son)
            for k in range(10):
                v[3 + k] = d.chaine(fichier) if k == 0 else 0
                v[13 + k] = 1 if k == 0 else 0
            v[23] = d.chaine("Sound" + BS + "Spells")
            d.pose(v)
        ecrit(dll, h, prefixe + "SoundEntries.dbc", d.octets())
        print("SoundEntries : %s — base %s"
              % (", ".join("%d -> %s" % (i, f) for i, _n, f in sons), source))

        # --- SpellVisualEffectName --------------------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        d.retire({EFFET_SINGULARITE, EFFET_ECLAT, EFFET_CATACLYSME})
        d.pose([EFFET_SINGULARITE, d.chaine("Singularite fantomatique"),
                d.chaine(MODELE_SINGULARITE), 0.0, ECHELLE_SINGULARITE,
                0.01, 100.0])
        # L'éclat garde son échelle d'origine : il est taillé pour un torse,
        # pas pour couvrir une zone, et rien ne le lie au rayon du sort.
        d.pose([EFFET_ECLAT, d.chaine("Singularite - eclat"),
                d.chaine(MODELE_ECLAT), 0.0, 1.0, 0.01, 100.0])
        # Le missile garde son echelle d'origine : il est taille pour voler.
        d.pose([EFFET_CATACLYSME, d.chaine("Cataclysme - missile"),
                d.chaine(MODELE_CATACLYSME), 0.0, 1.0, 0.01, 100.0])
        ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())
        print("SpellVisualEffectName : effet %d, échelle %.4f — bord à %.4f m"
              " du centre porté à %.2f m (rayon du sort %.1f m, débordement"
              " voulu de %.0f %%), décal relevé de %.2f m"
              % (EFFET_SINGULARITE, ECHELLE_SINGULARITE,
                 RAYON_MODELE_SINGULARITE,
                 RAYON_SINGULARITE * MARGE_SINGULARITE, RAYON_SINGULARITE,
                 (MARGE_SINGULARITE - 1) * 100, SOULEVEMENT_SINGULARITE))

        # --- SpellVisualKit ---------------------------------------------------
        # 38 champs : champ 2 = animation, champ 5 = effet au point d'attache
        # Base (le sol, comme le Séisme), champ 15 = son.
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_SINGULARITE_SON, KIT_SINGULARITE_ZONE, KIT_ECLAT,
                  KIT_BOUCLIER, KIT_ANNEAU_FEU, KIT_CATACLYSME_SON})
        d.pose([KIT_SINGULARITE_SON, -1, -1] + [0] * 12
               + [SON_SINGULARITE, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_SINGULARITE_ZONE, -1, -1, 0, 0, EFFET_SINGULARITE]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Champ 4 = ChestEffect : le modèle s'accroche au TORSE de la cible.
        d.pose([KIT_ECLAT, -1, -1, 0, EFFET_ECLAT]
               + [0] * 10 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Le seul kit qu'il faille batir : les autres sont natifs, on ne
        # fait que les pointer. Champ 5 = Base, le modele au sol sous le
        # demon, comme tous les boucliers natifs.
        d.pose([KIT_BOUCLIER, -1, -1, 0, 0, EFFET_BOUCLIER_OMBRE]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Le son du Cataclysme, au lancement, sans modele ni animation : le
        # missile porte deja son propre eclat (sa sequence 191).
        d.pose([KIT_CATACLYSME_SON, -1, -1] + [0] * 12
               + [SON_CATACLYSME, 0] + [-1, -1, -1, -1] + [0] * 17)
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (son), %d (décal au sol), %d (éclat"
              " au torse) et %d (bouclier d'ombre) posés ; %d retiré"
              % (KIT_SINGULARITE_SON, KIT_SINGULARITE_ZONE, KIT_ECLAT,
                 KIT_BOUCLIER, KIT_ANNEAU_FEU))

        # --- SpellVisual ------------------------------------------------------
        # Le champ 25 est le kit de ZONE PERSISTANTE : il vit aussi longtemps
        # que la zone du sort, exactement comme la flaque du Séisme.
        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL_SINGULARITE, VISUEL_ECLAT, VISUEL_FLAMMES,
                  VISUEL_MAINS, VISUEL_BOUCLIER, VISUEL_RAGE,
                  VISUEL_CATACLYSME})
        v = [0] * 32
        v[0] = VISUEL_SINGULARITE
        v[2] = KIT_SINGULARITE_SON
        v[4] = KIT_ECLAT              # kit d'ÉTAT : sur chaque ennemi drainé
        v[25] = KIT_SINGULARITE_ZONE
        d.pose(v)
        # Les quatre visuels des bonus du tyran : rien QUE le champ 4, le
        # kit d'ETAT. Un kit de CANAL (champ 6) aurait impose la
        # canalisation aux flammes et empeche le tyran de frapper.
        for ident, kit in ((VISUEL_MAINS, KIT_MAINS_FEU),
                           (VISUEL_BOUCLIER, KIT_BOUCLIER),
                           (VISUEL_RAGE, KIT_RAGE)):
            e = [0] * 32
            e[0] = ident
            e[4] = kit
            d.pose(e)
        # LE MISSILE DU CATACLYSME : charpente de la Boule de feu, deja
        # employee pour la Bombe incendiaire. La vitesse vit sur le sort.
        c = [0] * 32
        c[0] = VISUEL_CATACLYSME
        c[2] = KIT_CATACLYSME_SON     # le son, au lancement
        c[7] = 1                      # HasMissile
        c[8] = EFFET_CATACLYSME       # le modele qui vole
        c[10] = 1                     # attache a destination
        c[16] = -1                    # depart : la main
        d.pose(c)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : %d (singularité) ; %d et %d retirés ; bonus du"
              " tyran : %d (mains, kit %d), %d (bouclier, %d), %d (rage, %d)"
              % (VISUEL_SINGULARITE, VISUEL_ECLAT, VISUEL_FLAMMES,
                 VISUEL_MAINS, KIT_MAINS_FEU,
                 VISUEL_BOUCLIER, KIT_BOUCLIER, VISUEL_RAGE, KIT_RAGE))
        # --- L'apparence du tyran, client PUIS serveur --------------------
        brut_cmd, source_cmd = lit_effectif(dll, h, "CreatureModelData.dbc")
        brut_cdi, source_cdi = lit_effectif(dll, h, "CreatureDisplayInfo.dbc")
        cmd, cdi = Dbc(brut_cmd), Dbc(brut_cdi)
        pose_tyran(cmd, cdi)
        ecrit(dll, h, prefixe + "CreatureModelData.dbc", cmd.octets())
        ecrit(dll, h, prefixe + "CreatureDisplayInfo.dbc", cdi.octets())
        print("Tyran (client) : modèle %d, apparence %d — bases %s / %s"
              % (MODELE_DATA_TYRAN, DISPLAY_TYRAN, source_cmd, source_cdi))

        # Le serveur VALIDE les displayid qu'on lui demande de poser : sans
        # ces memes lignes cote serveur, la creature reste invisible.
        for nom in ("CreatureModelData.dbc", "CreatureDisplayInfo.dbc"):
            chemin = os.path.join(DBC_SERVEUR_DIR, nom)
            if not os.path.exists(chemin):
                raise SystemExit("DBC serveur absent : %s" % chemin)
            if not os.path.exists(chemin + ".avant_demoniste"):
                shutil.copy2(chemin, chemin + ".avant_demoniste")
        p_cmd = os.path.join(DBC_SERVEUR_DIR, "CreatureModelData.dbc")
        p_cdi = os.path.join(DBC_SERVEUR_DIR, "CreatureDisplayInfo.dbc")
        with io.open(p_cmd, "rb") as f:
            s_cmd = Dbc(f.read())
        with io.open(p_cdi, "rb") as f:
            s_cdi = Dbc(f.read())
        pose_tyran(s_cmd, s_cdi)
        with io.open(p_cmd, "wb") as f:
            f.write(s_cmd.octets())
        with io.open(p_cdi, "wb") as f:
            f.write(s_cdi.octets())
        print("Tyran (serveur) : posés dans Data%sdbc" % BS)
    finally:
        dll.SFileCloseArchive(h)
    print("\nLe sort 8600081 pointe ce visuel et cette icône"
          " (sorts_classes.py) :\n  python gen_sorts_classes.py --deploy")


if __name__ == "__main__":
    main()
