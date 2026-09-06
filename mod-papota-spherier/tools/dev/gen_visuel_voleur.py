# -*- coding: utf-8 -*-
r"""Monte les visuels rétroportés du voleur : Grappin (8600030) et Coup de dés
(8600032), plus l'icône moderne du grappin et les sons.

Les fichiers préparés vivent dans `art_voleur\` (M2 en version 264, chemins de
texture inscrits, texUnitLookup et rotations de tuile déjà contrôlés). Le
montage suit la chaîne habituelle :

  Spell.SpellVisualID → SpellVisual → SpellVisualKit → SpellVisualEffectName

et y ajoute des DBC que les montages précédents n'avaient pas touchés :

  - SoundEntries.dbc — une entrée peut porter DIX fichiers avec leurs
    fréquences : le client en TIRE UN AU HASARD à chaque lecture. Les trois
    sons du Coup de dés partagent donc une seule entrée — la variation
    aléatoire est native, aucun script n'est nécessaire.
  - SpellIcon.dbc — l'icône moderne du grappin (8050).
  - CreatureModelData.dbc et CreatureDisplayInfo.dbc — l'habillage 802101 :
    une CRÉATURE qui porte le modèle du crochet, pour le poser au sol
    (l'ancre 803804 du grappin, étape 1 de la reconstruction). Le serveur
    valide les displayids contre SES copies : les deux fichiers de
    Data\dbc sont complétés aussi, comme Item.dbc (gen_objets_spherier).
  Ces DBC ne sont pas encore dans patch-z : on lit la copie EFFECTIVE
  (patch-frFR-z), on la complète, on écrit dans patch-z — qui l'emporte pour
  les DBC, c'est prouvé par les sorts custom qui ne vivent que là.

Le GRAPPIN — RECONSTRUCTION PAS À PAS (2026-08-29), une exigence à la fois :
le visuel 30017 porte le kit de lancer réduit à l'animation AttackThrown
(107) et le MISSILE (le modèle du moine, non réorienté, ruban étouffé) qui
part de la main vers le point visé — sans son, sans impact. À l'arrivée, le
crochet posé au sol est l'ancre 803804 habillée du modèle planté (802101,
copie debout dérivée du même missile). Le CÂBLE main -> projectile (étape 4)
est le mécanisme des DRAINS : kit de canalisation 30019 à chaîne custom 2000
(clone raide de la corde 525, texture fer), joué par le client quand le
script pose UNIT_CHANNEL_SPELL = 8600039 et CHANNEL_OBJECT = le crochet
volant invisible (803805) — les deux bouts suivent en direct. Restent posés, DORMANTS, pour les étapes suivantes : le
son SON_GRAPPIN, le kit d'impact natif 5930. L'historique des mécanismes de
corde rejetés est dans sorts_classes.py (8600039).

Le COUP DE DÉS : les dés (`cfx_rogue_rollthebones_castbasedice`) roulent au
point d'ancrage de base du personnage pendant le lancer, un des trois sons part
au hasard.

Les modèles Death Mark exportés en même temps sont injectés (disponibles pour
un montage futur) mais aucun DBC ne les référence encore.

    python gen_visuel_voleur.py        (JEU FERMÉ requis : écrit dans patch-z)
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

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_voleur")

# --- les identifiants (8200209 / 30016 : pris par la Pénitence) --------------
EFFET_GRAPPIN = 8200210
EFFET_DES = 8200211
KIT_GRAPPIN = 30017
KIT_DES = 30018
KIT_LIEN = 30019             # le CÂBLE : kit de CANALISATION, chaîne native 525
VISUEL_GRAPPIN = 30017
VISUEL_DES = 30018
VISUEL_LIEN = 30019          # porté par 8600039 via UNIT_CHANNEL_SPELL (jamais lancé)
CHAINE_CABLE = 2000          # NOTRE câble : CLONE DU DRAIN DE VIE (719) en
                             # FER Beam_ChainIron, vagues 20/21 à zéro. Le
                             # 719 est le SEUL enregistrement au rendu
                             # instantané/persistant/suivi VALIDÉ en jeu ;
                             # le gabarit 525 a résisté à la domestication
                             # (croissance progressive du joueur vers
                             # l'ancre et extinction précoce, malgré durées
                             # 30000/1 et retrait du drapeau 0x100).
                             # Bannies : cordes (ribbon_rope, 525 nue) ;
                             # rejetés : 257, 495 et fers natifs.
GABARIT_CHAINE = 719
TEXTURE_CABLE = "Spells" + BS + "Textures" + BS + "Beam_ChainIron.blp"
DISPLAY_VOLANT = 802102      # crochet volant : opacité 0, invisible POUR TOUS
SON_GRAPPIN = 990100
SON_DES = 990101
ICONE_GRAPPIN = 8050
GABARIT_SON = 3011        # le son de vol de la Boule de feu : un son de sort

MODELE_GRAPPIN = "spells" + BS + "monk_grappleweapon_missile.mdx"
MODELE_DES = "spells" + BS + "cfx_rogue_rollthebones_castbasedice.mdx"

# --- restes DORMANTS d'anciennes étapes (relevés conservés) ------------------
#   - impact : le kit natif 5930 (DustCloud_Land + son Giant Boulder Impact,
#     le « Dust Cloud Impact » de Wing Buffet) — se pose en ImpactKit du
#     visuel du missile quand une étape le demandera. Repli sans son : 11108.
KIT_IMPACT_GRAPPIN = 5930    # natif : poussière + choc sourd
RUBAN_VIE = 0.0              # ruban ÉTEINT (edgesPerSecond=0 dans regle_ruban)
RUBAN_GRAVITE = 0.0

# --- la Marque de la mort (8600033, Symboles de mort) ------------------------
# Montage du 2026-08-30, sources rétroportées fournies par l'utilisateur
# (wow.export ; les M2 préparés — v264, textures inscrites — étaient déjà
# dans art_voleur, seule l'ICÔNE manquait). Le LANCER joue
# cfx_rogue_deathmark_cast aux pieds du lanceur ; la MARQUE est
# cfx_rogue_deathmark_aura, accrochée au TORSE de la cible tant que l'aura
# tient — le client joue le kit d'ÉTAT du visuel du sort sur le porteur de
# l'aura (le mécanisme des points de Récupération). Le grand modèle aura01
# (1 Mo, variante) est injecté EN RÉSERVE, non référencé.
EFFET_MARQUE_CAST = 8200212
EFFET_MARQUE_AURA = 8200213     # la marque du HOLD : échelle 0,15, à la tête
EFFET_MARQUE_IMPACT = 8200214   # la même, PLEINE échelle, pour l'impact
KIT_MARQUE_CAST = 30020
KIT_MARQUE_AURA = 30021
KIT_MARQUE_IMPACT = 30022       # one-shot au TORSE de la cible à l'impact
                                # (réglage utilisateur du 2026-08-30)
VISUEL_MARQUE = 30020
ICONE_MARQUE = 8051
MODELE_MARQUE_CAST = "spells" + BS + "cfx_rogue_deathmark_cast.mdx"
MODELE_MARQUE_AURA = "spells" + BS + "cfx_rogue_deathmark_aura.mdx"

# --- le crochet au sol : l'habillage de l'ancre 803804 -----------------------
# Étape 1 de la reconstruction du grappin : le sort n'a PLUS de visuel
# (visuel=0, sorts_classes.py) ; ce qui apparaît au point visé est l'ANCRE,
# une créature habillée du modèle du crochet. Même identifiant dans
# CreatureModelData et CreatureDisplayInfo (nouvelle sous-plage 8021xx).
# Le CreatureModelData est un clone du Poulet (collisions plausibles), chemin
# remplacé, échelle forcée à 1, champs sonores/empreintes mis à zéro — le
# crochet ne caquette pas. L'habillage est bâti de zéro : opacité 255,
# échelle 1, aucune variation de texture (chemins inscrits dans le M2).
MODELE_ANCRE_ID = 802101
DBC_SERVEUR_DIR = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc"

# --- le crochet PLANTÉ : copie DEBOUT du missile -----------------------------
# Le missile est modélisé COUCHÉ le long de +X (l'axe de vol) : posé au sol
# tel quel, il s'allonge. LA POINTE EST À x=0,77 — prouvé EN JEU : la copie
# tournée +X vers le haut montrait la pointe en l'air (l'histogramme de
# densité désignait l'origine à tort : le côté large est l'œillet de corde).
# papota_crochet_sol est la copie debout dérivée À L'INJECTION (la source
# reste l'export intact) : rotation +90° autour de Y (+X -> -Z : la pointe
# descend), recentrage en X, remontée réglée pour l'assiette voulue en jeu
# (0,66 = pointe à peine mordante ; abaissé de 25 % de la hauteur du modèle
# à la demande de l'utilisateur, 2026-08-29). Le .skin ne contient que des
# indices : simple copie renommée (le client cherche <nom du M2>00.skin).
MODELE_CROCHET_SOL = "spells" + BS + "papota_crochet_sol.mdx"
CROCHET_SOL_M2 = "papota_crochet_sol.m2"
CROCHET_SOL_SKIN = "papota_crochet_sol00.skin"
CROCHET_LEVE = 0.47
CROCHET_RECENTRE = 0.20

# --- le crochet en VOL : copie remontée du missile ---------------------------
# Toute la géométrie du missile est SOUS son origine (z de -0,28 à -0,12,
# relevé) : l'origine suit la trajectoire, donc le modèle passait sous le sol
# en fin de course (constaté en jeu, 2026-08-29). papota_crochet_vol est la
# copie translatée pour que son point le plus BAS soit à l'origine : le
# projectile arrive AU NIVEAU du sol. C'est CE modèle que référence
# EFFET_GRAPPIN ; l'export d'origine reste intact.
MODELE_CROCHET_VOL = "spells" + BS + "papota_crochet_vol.mdx"
CROCHET_VOL_M2 = "papota_crochet_vol.m2"
CROCHET_VOL_SKIN = "papota_crochet_vol00.skin"

SONS_GRAPPIN = ["spell_ro_grapplinghook_whoosh_cast_01.wav"]
SONS_DES = ["spell_ro_rollthebones_cast_01.wav",
            "spell_ro_rollthebones_cast_02.wav",
            "spell_ro_rollthebones_cast_03.wav"]

# Les archives où chercher un DBC qui n'est pas encore dans patch-z, dans
# l'ordre où le client les ferait gagner.
SOURCES_DBC = [
    os.path.join(G.DATA, "frFR", "patch-frFR-z.mpq"),
    os.path.join(G.DATA, "patch-c.mpq"),
    os.path.join(G.DATA, "frFR", "patch-frFR-3.MPQ"),
    os.path.join(G.DATA, "frFR", "locale-frFR.MPQ"),
]


def lit_effectif(dll, h_patchz, nom):
    """Le DBC depuis patch-z s'il y est, sinon depuis la première archive
    de SOURCES_DBC qui le porte (lecture seule)."""
    chemin = "DBFilesClient" + BS + nom
    fh = C.c_void_p()
    if dll.SFileOpenFileEx(h_patchz, chemin.encode("latin-1"), 0, C.byref(fh)):
        dll.SFileCloseFile(fh)
        return lit(dll, h_patchz, chemin), "patch-z"
    for archive in SOURCES_DBC:
        if not os.path.exists(archive):
            continue
        h = C.c_void_p()
        if not dll.SFileOpenArchive(archive, 0, 0x00000100, C.byref(h)):
            continue
        try:
            fh = C.c_void_p()
            if dll.SFileOpenFileEx(h, chemin.encode("latin-1"), 0, C.byref(fh)):
                dll.SFileCloseFile(fh)
                return lit(dll, h, chemin), os.path.basename(archive)
        finally:
            dll.SFileCloseArchive(h)
    raise SystemExit("%s introuvable dans toutes les archives" % nom)


def regle_ruban(donnees, vie):
    """ÉTEINT le ruban : zéro bord émis par seconde, durée de vie `vie`,
    gravité nulle. L'émetteur de ruban fait 176 octets ; après id, os,
    position, textures et matériaux (36) puis quatre pistes de 20,
    edgesPerSecond est à +116, edgeLifetime à +120, gravity à +124 — relevé
    sur le modèle et vérifié par les valeurs lues (45 bords/s, 0,25 s, 3.0).
    L'étouffement à vie 0,01 laissait encore un bout de traînée visible en
    vol (constaté en jeu, 2026-08-29) : c'est edgesPerSecond=0 qui coupe
    vraiment l'émission."""
    donnees = bytearray(donnees)
    n, ofs = struct.unpack_from("<2I", donnees, 0x120)
    if n != 1:
        raise SystemExit("modèle à ruban : %d ruban(s), 1 attendu" % n)
    struct.pack_into("<3f", donnees, ofs + 116, 0.0, vie, RUBAN_GRAVITE)
    return bytes(donnees)


def texte(d, ofs):
    """Une chaîne du bloc de chaînes d'un Dbc."""
    fin = d.chaines.find(b"\x00", ofs)
    return d.chaines[ofs:fin].decode("latin-1", "replace")


def plante_crochet(donnees):
    """La copie DEBOUT du missile : (x, y, z) -> (z + CROCHET_RECENTRE, y,
    -x + CROCHET_LEVE) sur sommets, pivots d'os et émetteur de ruban ; les
    normales tournent SANS se translater ; bornes et rayon recalculés.
    Offsets du M2 264 : sommets 0x3C (pas 48, normale à +20), os 0x2C
    (pas 88, pivot à +76), rubans 0x120 (pas 176, position à +8),
    boîte englobante 0xA0, rayon 0xB8."""
    donnees = bytearray(donnees)

    def tourne(off, translate):
        x, y, z = struct.unpack_from("<3f", donnees, off)
        nx, ny, nz = z, y, -x
        if translate:
            nx, nz = nx + CROCHET_RECENTRE, nz + CROCHET_LEVE
        struct.pack_into("<3f", donnees, off, nx, ny, nz)

    n, ofs = struct.unpack_from("<2I", donnees, 0x3C)
    for i in range(n):
        tourne(ofs + i * 48, True)
        tourne(ofs + i * 48 + 20, False)
    nb, ofsb = struct.unpack_from("<2I", donnees, 0x2C)
    for i in range(nb):
        tourne(ofsb + i * 88 + 76, True)
    nr, ofsr = struct.unpack_from("<2I", donnees, 0x120)
    for i in range(nr):
        tourne(ofsr + i * 176 + 8, True)

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


def leve_crochet_vol(donnees):
    """La copie de VOL du missile : translation en Z pour amener le point le
    plus bas de la géométrie à l'origine (dz = -min z, mesuré sur le
    fichier) — sommets, pivots d'os et émetteur de ruban ; bornes et rayon
    recalculés. Mêmes offsets M2 264 que plante_crochet."""
    donnees = bytearray(donnees)
    n, ofs = struct.unpack_from("<2I", donnees, 0x3C)
    dz = -min(struct.unpack_from("<3f", donnees, ofs + i * 48)[2]
              for i in range(n))

    def leve(off):
        x, y, z = struct.unpack_from("<3f", donnees, off)
        struct.pack_into("<3f", donnees, off, x, y, z + dz)

    for i in range(n):
        leve(ofs + i * 48)
    nb, ofsb = struct.unpack_from("<2I", donnees, 0x2C)
    for i in range(nb):
        leve(ofsb + i * 88 + 76)
    nr, ofsr = struct.unpack_from("<2I", donnees, 0x120)
    for i in range(nr):
        leve(ofsr + i * 176 + 8)

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


def pose_crochet_sol(cmd, cdi):
    """Pose le modèle du crochet et son habillage MODELE_ANCRE_ID dans deux
    Dbc (CreatureModelData, CreatureDisplayInfo) — mêmes lignes côté client
    et côté serveur, mais les offsets de chaînes sont PROPRES à chaque
    fichier : tout se refait par instance."""
    if cmd.nfield != 28:
        raise SystemExit("CreatureModelData : %d champs, 28 attendus" % cmd.nfield)
    if cdi.nfield != 16:
        raise SystemExit("CreatureDisplayInfo : %d champs, 16 attendus" % cdi.nfield)

    gabarit = None
    for i in range(cmd.nrec):
        off = i * cmd.rsize
        chemin = texte(cmd, struct.unpack_from("<I", cmd.enr, off + 8)[0]).lower()
        if chemin.endswith("chicken.mdx") or chemin.endswith("chicken.m2"):
            gabarit = [struct.unpack_from("<I", cmd.enr, off + k * 4)[0]
                       for k in range(28)]
            break
    if gabarit is None:
        raise SystemExit("gabarit Chicken absent de CreatureModelData")

    cmd.retire({MODELE_ANCRE_ID})
    gabarit[0] = MODELE_ANCRE_ID
    gabarit[2] = cmd.chaine(MODELE_CROCHET_SOL)
    # Échelle du modèle forcée à 1 (bits du flottant), champs 5..13 — sang,
    # empreintes, foley, secousses, son — à zéro : un marqueur muet.
    gabarit[4] = struct.unpack("<I", struct.pack("<f", 1.0))[0]
    for k in range(5, 14):
        gabarit[k] = 0
    cmd.pose(gabarit)

    cdi.retire({MODELE_ANCRE_ID, DISPLAY_VOLANT})
    cdi.pose([MODELE_ANCRE_ID, MODELE_ANCRE_ID, 0, 0, 1.0, 255,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    # L'habillage du CROCHET VOLANT : INVISIBLE POUR TOUS. Le modèle du
    # World Trigger rend une silhouette blanche à quiconque REÇOIT l'unité
    # (constaté en jeu : le drapeau trigger retiré, le fantôme se voyait
    # sans .gm — ce drapeau ne cache qu'en filtrant l'envoi côté serveur).
    # Même modèle que le display 11686, mais opacité 0.
    modele_trigger = None
    for i in range(cdi.nrec):
        if struct.unpack_from("<I", cdi.enr, i * cdi.rsize)[0] == 11686:
            modele_trigger = struct.unpack_from("<I", cdi.enr,
                                                i * cdi.rsize + 4)[0]
            break
    if modele_trigger is None:
        raise SystemExit("display 11686 (World Trigger) absent de CreatureDisplayInfo")
    cdi.pose([DISPLAY_VOLANT, modele_trigger, 0, 0, 1.0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0])




def fichiers_a_injecter():
    """(chemin local, chemin dans l'archive) — les lod modernes sont écartés,
    le client 3.3.5 ne les nomme pas ainsi."""
    paires = []
    for nom in sorted(os.listdir(os.path.join(ART, "spells"))):
        if "_lod0" in nom or nom.endswith(".ogg"):
            continue
        if nom.endswith((".m2", ".skin", ".blp")):
            paires.append((os.path.join(ART, "spells", nom), "spells" + BS + nom))
    ic = os.path.join(ART, "interface", "icons", "ability_rogue_grapplinghook.blp")
    paires.append((ic, "Interface" + BS + "Icons" + BS + "ability_rogue_grapplinghook.blp"))
    ic = os.path.join(ART, "interface", "icons", "ability_rogue_deathmark.blp")
    paires.append((ic, "Interface" + BS + "Icons" + BS + "ability_rogue_deathmark.blp"))
    for nom in sorted(os.listdir(os.path.join(ART, "sound", "spells"))):
        if nom.endswith(".wav"):
            paires.append((os.path.join(ART, "sound", "spells", nom),
                           "Sound" + BS + "Spells" + BS + nom))
    return paires


def main():
    sauvegarde = G.ARCHIVE + ".avant_art_voleur"
    if not os.path.exists(sauvegarde):
        print("sauvegarde de l'archive (une fois) : %s" % sauvegarde)
        shutil.copy2(G.ARCHIVE, sauvegarde)

    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        # --- les fichiers, puis leur relecture --------------------------------
        # Le missile du grappin reçoit son réglage de ruban AU PASSAGE : la
        # copie d'art_voleur reste l'export intact, le réglage est rejouable.
        paires = fichiers_a_injecter()
        for local, interne in paires:
            donnees = io.open(local, "rb").read()
            if interne.endswith("monk_grappleweapon_missile.m2"):
                donnees = regle_ruban(donnees, RUBAN_VIE)
            ecrit(dll, h, interne, donnees)

        defauts = 0
        for local, interne in paires:
            attendu = os.path.getsize(local)
            relu = len(lit(dll, h, interne))
            if relu != attendu:
                print("ECART %s : %d relu, %d attendu" % (interne, relu, attendu))
                defauts += 1
        print("%d fichier(s) injecté(s) et relus conformes (%d écart(s))"
              % (len(paires), defauts))
        if defauts:
            raise SystemExit("injection non conforme")

        # --- les crochets dérivés du missile à l'injection --------------------
        brut = io.open(os.path.join(ART, "spells",
                                    "monk_grappleweapon_missile.m2"), "rb").read()
        ecrit(dll, h, "spells" + BS + CROCHET_SOL_M2,
              plante_crochet(regle_ruban(brut, RUBAN_VIE)))
        ecrit(dll, h, "spells" + BS + CROCHET_VOL_M2,
              leve_crochet_vol(regle_ruban(brut, RUBAN_VIE)))
        brut = io.open(os.path.join(ART, "spells",
                                    "monk_grappleweapon_missile00.skin"), "rb").read()
        ecrit(dll, h, "spells" + BS + CROCHET_SOL_SKIN, brut)
        ecrit(dll, h, "spells" + BS + CROCHET_VOL_SKIN, brut)
        print("crochets dérivés : %s (planté) et %s (vol, remonté au ras du sol)"
              % (CROCHET_SOL_M2, CROCHET_VOL_M2))

        prefixe = "DBFilesClient" + BS

        # --- SpellChainEffects : NOTRE chaîne de fer RECTILIGNE ---------------
        # Enregistrements de 177 octets, NON alignés sur 4 : travail en brut —
        # clone du gabarit 525 (corde tendue : rectiligne, bruit nul,
        # apparition immédiate), identifiant et offset de texture (décalage
        # 28, relevé) réécrits vers le fer Beam_ChainIron. Les chaînes de fer
        # NATIVES (495 Harpoon...) ondulent, s'étirent avec un délai et
        # dérivent — rejetées en jeu (2026-08-29).
        brut, source = lit_effectif(dll, h, "SpellChainEffects.dbc")
        d = Dbc(brut)
        garde, gabarit = bytearray(), None
        for i in range(d.nrec):
            off = i * d.rsize
            ident = struct.unpack_from("<I", d.enr, off)[0]
            rec = bytes(d.enr[off:off + d.rsize])
            if ident == GABARIT_CHAINE:
                gabarit = rec
            if ident == CHAINE_CABLE:
                continue
            garde.extend(rec)
        if gabarit is None:
            raise SystemExit("chaîne gabarit %d absente" % GABARIT_CHAINE)
        rec = bytearray(gabarit)
        struct.pack_into("<I", rec, 0, CHAINE_CABLE)
        struct.pack_into("<I", rec, 28, d.chaine(TEXTURE_CABLE))
        # DEUX retouches et rien d'autre : les champs de vague 20/21
        # (3,142 / -50 — l'ondulation du drain, identifiée en jeu par
        # l'utilisateur) à zéro pour un trait rectiligne. Le reste du 719
        # (durées, drapeaux 0x48, AvgSegLen 4, champs 36/37...) est conservé
        # TEL QUEL : c'est lui qui porte l'apparition instantanée et la
        # persistance. Si les MAILLONS GLISSENT le long du trait (le
        # défilement du drain), le prochain levier est 36/37 (-24/4).
        struct.pack_into("<I", rec, 20 * 4, 0)
        struct.pack_into("<I", rec, 21 * 4, 0)
        garde.extend(rec)
        d.enr, d.nrec = garde, len(garde) // d.rsize
        ecrit(dll, h, prefixe + "SpellChainEffects.dbc", d.octets())
        print("SpellChainEffects : %d posé (gabarit %d, fer Beam_ChainIron) — base %s"
              % (CHAINE_CABLE, GABARIT_CHAINE, source))

        # --- SpellVisualEffectName : les modèles ------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        d.retire({EFFET_GRAPPIN, EFFET_DES, EFFET_MARQUE_CAST,
                  EFFET_MARQUE_AURA, EFFET_MARQUE_IMPACT})
        d.pose([EFFET_GRAPPIN, d.chaine("Grappin - missile"),
                d.chaine(MODELE_CROCHET_VOL), 1.0, 1.0, 0.01, 100.0])
        d.pose([EFFET_DES, d.chaine("Coup de des - lancer"),
                d.chaine(MODELE_DES), 1.0, 1.0, 0.01, 100.0])
        d.pose([EFFET_MARQUE_CAST, d.chaine("Marque - lancer"),
                d.chaine(MODELE_MARQUE_CAST), 1.0, 1.0, 0.01, 100.0])
        # Échelle 0,15 : la marque d'état à taille native était trop grosse
        # (réduction de 85 % demandée par l'utilisateur, 2026-08-30).
        d.pose([EFFET_MARQUE_AURA, d.chaine("Marque - aura"),
                d.chaine(MODELE_MARQUE_AURA), 1.0, 0.15, 0.01, 100.0])
        # Le même modèle, PLEINE échelle : l'impact au torse.
        d.pose([EFFET_MARQUE_IMPACT, d.chaine("Marque - impact"),
                d.chaine(MODELE_MARQUE_AURA), 1.0, 1.0, 0.01, 100.0])
        ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())
        print("SpellVisualEffectName : effets %d, %d, %d, %d et %d posés"
              % (EFFET_GRAPPIN, EFFET_DES, EFFET_MARQUE_CAST,
                 EFFET_MARQUE_AURA, EFFET_MARQUE_IMPACT))

        # --- SoundEntries : le tirage aléatoire est natif ---------------------
        brut, source = lit_effectif(dll, h, "SoundEntries.dbc")
        d = Dbc(brut)
        if d.nfield != 30:
            raise SystemExit("SoundEntries : %d champs, 30 attendus" % d.nfield)
        gabarit = None
        for i in range(d.nrec):
            off = i * d.rsize
            if struct.unpack_from("<I", d.enr, off)[0] == GABARIT_SON:
                gabarit = [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                           for k in range(30)]
                break
        if gabarit is None:
            raise SystemExit("gabarit sonore %d absent" % GABARIT_SON)
        d.retire({SON_GRAPPIN, SON_DES})

        def entree_son(ident, nom, fichiers):
            v = list(gabarit)              # type, volume, distances, EAX du gabarit
            v[0] = ident
            v[2] = d.chaine(nom)
            for k in range(10):
                v[3 + k] = d.chaine(fichiers[k]) if k < len(fichiers) else 0
                v[13 + k] = 1 if k < len(fichiers) else 0
            v[23] = d.chaine("Sound" + BS + "Spells")
            return v

        d.pose(entree_son(SON_GRAPPIN, "PapotaGrappin", SONS_GRAPPIN))
        d.pose(entree_son(SON_DES, "PapotaCoupDeDes", SONS_DES))
        ecrit(dll, h, prefixe + "SoundEntries.dbc", d.octets())
        print("SoundEntries : %d (grappin) et %d (dés, 3 fichiers au hasard) posés"
              " — base lue dans %s" % (SON_GRAPPIN, SON_DES, source))

        # --- SpellVisualKit ---------------------------------------------------
        # 38 champs : ID, StartAnim, Anim, Head, Chest, Base, LeftHand,
        # RightHand, Breath, LWeapon, RWeapon, Special x3, World, Sound, Shake,
        # CharProc x4 (-1 = libre), CharParamZero x4.
        # Kit du grappin (étape 2) : l'anim AttackThrown (107, relevée dans
        # AnimationData) et RIEN d'autre, son compris (le sifflement
        # SON_GRAPPIN reviendra plus tard ; il partait du champ 15 du kit,
        # le MissileSound du visuel restant muet en jeu).
        # Kit du CÂBLE (étape 4) : le patron des DRAINS, relevé sur Drain de
        # vie (kit canal 11762 : CharProc[0]=0, CharParam[0]=chaîne 719) —
        # ici la corde tendue native CHAINE_CABLE, sans anim ni son.
        # Kits de la MARQUE : le lancer (anim 54, modèle aux pieds du
        # lanceur, sans son) et l'ÉTAT de la marque (modèle À LA TÊTE de la
        # cible — le torse, essayé d'abord, la noyait dans le corps —, ni
        # anim ni son : il vit avec l'aura).
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_GRAPPIN, KIT_DES, KIT_LIEN, KIT_MARQUE_CAST,
                  KIT_MARQUE_AURA, KIT_MARQUE_IMPACT})
        d.pose([KIT_GRAPPIN, -1, 107] + [0] * 12 + [0, 0]
               + [-1, -1, -1, -1] + [0.0, 0.0, 0.0, 0.0] + [0] * 13)
        d.pose([KIT_DES, -1, 54, 0, 0, EFFET_DES] + [0] * 9 + [SON_DES, 0]
               + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_LIEN, -1, -1] + [0] * 12 + [0, 0]
               + [0, -1, -1, -1] + [float(CHAINE_CABLE), 0.0, 0.0, 0.0]
               + [0] * 13)
        d.pose([KIT_MARQUE_CAST, -1, 54, 0, 0, EFFET_MARQUE_CAST]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_MARQUE_AURA, -1, -1, EFFET_MARQUE_AURA, 0, 0]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_MARQUE_IMPACT, -1, -1, 0, EFFET_MARQUE_IMPACT, 0]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (anim 107), %d (dés), %d (câble %d),"
              " %d (marque lancer), %d (marque état) et %d (marque impact)"
              " posés"
              % (KIT_GRAPPIN, KIT_DES, KIT_LIEN, CHAINE_CABLE,
                 KIT_MARQUE_CAST, KIT_MARQUE_AURA, KIT_MARQUE_IMPACT))

        # --- SpellVisual ------------------------------------------------------
        # 32 champs, positions relevées sur la Boule de feu (visuel 67) :
        # 2 = kit de lancer, 3 = kit d'IMPACT (avec l'attache à destination,
        # il joue au point d'arrivée du missile — le comportement Boule de
        # feu), 7 = HasMissile, 8 = modèle du missile, 10 = attache à
        # destination, 11 = son du missile, 13 = drapeaux, 16 = attache de
        # départ (-1 = main, comme la Boule de feu). Le visuel 30019 de
        # l'ancien lien est purgé et n'est plus posé.
        # Visuel du grappin : kit de lancer SEUL (l'animation de jet) — le
        # MISSILE est retiré avec l'abandon du projectile (design courant :
        # ancre instantanée + lien, voir sorts_classes.py). Pour le remettre
        # un jour : champs 7=1, 8=EFFET_GRAPPIN, 10=1, 13=1, 16=-1 (départ
        # main, comme la Boule de feu). Ni son, ni kit d'impact.
        # Visuel du CÂBLE : le kit canal SEUL (champ 6, comme les drains) —
        # le client le joue quand UNIT_CHANNEL_SPELL vaut 8600039 (dormant :
        # 8600039 pointe l'étalon 12655 tant que la matière n'est pas
        # choisie).
        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL_GRAPPIN, VISUEL_DES, VISUEL_LIEN, VISUEL_MARQUE})
        grappin = [0] * 32
        grappin[0] = VISUEL_GRAPPIN
        grappin[2] = KIT_GRAPPIN
        d.pose(grappin)
        des = [0] * 32
        des[0] = VISUEL_DES
        des[2] = KIT_DES
        d.pose(des)
        lien = [0] * 32
        lien[0] = VISUEL_LIEN
        lien[6] = KIT_LIEN
        d.pose(lien)
        # La Marque : kit de lancer (2) sur le lanceur, kit d'IMPACT (3)
        # joué sur la CIBLE au moment où le sort touche — la marque pleine
        # échelle au torse —, kit d'ÉTAT (4) joué sur le PORTEUR de l'aura
        # tant que le débuff tient — la marque réduite à la tête.
        marque = [0] * 32
        marque[0] = VISUEL_MARQUE
        marque[2] = KIT_MARQUE_CAST
        marque[3] = KIT_MARQUE_IMPACT
        marque[4] = KIT_MARQUE_AURA
        d.pose(marque)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : visuels %d (anim seule), %d (dés), %d (câble)"
              " et %d (marque : lancer + impact + état) posés"
              % (VISUEL_GRAPPIN, VISUEL_DES, VISUEL_LIEN, VISUEL_MARQUE))

        # --- SpellIcon : les icônes modernes (grappin, Marque) ----------------
        brut, source = lit_effectif(dll, h, "SpellIcon.dbc")
        d = Dbc(brut)
        d.retire({ICONE_GRAPPIN, ICONE_MARQUE})
        d.pose([ICONE_GRAPPIN,
                d.chaine("Interface" + BS + "Icons" + BS + "ability_rogue_grapplinghook")])
        d.pose([ICONE_MARQUE,
                d.chaine("Interface" + BS + "Icons" + BS + "ability_rogue_deathmark")])
        ecrit(dll, h, prefixe + "SpellIcon.dbc", d.octets())
        print("SpellIcon : %d -> ability_rogue_grapplinghook, %d ->"
              " ability_rogue_deathmark — base lue dans %s"
              % (ICONE_GRAPPIN, ICONE_MARQUE, source))

        # --- CreatureModelData + CreatureDisplayInfo : le crochet au sol ------
        brut_cmd, source_cmd = lit_effectif(dll, h, "CreatureModelData.dbc")
        brut_cdi, source_cdi = lit_effectif(dll, h, "CreatureDisplayInfo.dbc")
        cmd, cdi = Dbc(brut_cmd), Dbc(brut_cdi)
        pose_crochet_sol(cmd, cdi)
        ecrit(dll, h, prefixe + "CreatureModelData.dbc", cmd.octets())
        ecrit(dll, h, prefixe + "CreatureDisplayInfo.dbc", cdi.octets())
        print("Crochets (client) : modèle %d, habillages %d (planté) et %d"
              " (volant, opacité 0) posés — bases %s / %s"
              % (MODELE_ANCRE_ID, MODELE_ANCRE_ID, DISPLAY_VOLANT,
                 source_cmd, source_cdi))
    finally:
        dll.SFileCloseArchive(h)

    # --- les mêmes deux DBC côté SERVEUR ------------------------------------
    # Le worldserver valide creature_template_model.CreatureDisplayID contre
    # SES CreatureDisplayInfo/CreatureModelData : sans ces lignes, l'habillage
    # 802101 serait rejeté au chargement. Même convention qu'Item.dbc
    # (gen_objets_spherier) : fichiers complétés en place, sauvegarde posée.
    for nom in ("CreatureModelData.dbc", "CreatureDisplayInfo.dbc"):
        chemin = os.path.join(DBC_SERVEUR_DIR, nom)
        if not os.path.exists(chemin):
            raise SystemExit("DBC serveur absent : %s" % chemin)
        sauvegarde = chemin + ".avant_ancre"
        if not os.path.exists(sauvegarde):
            shutil.copy2(chemin, sauvegarde)
    chemin_cmd = os.path.join(DBC_SERVEUR_DIR, "CreatureModelData.dbc")
    chemin_cdi = os.path.join(DBC_SERVEUR_DIR, "CreatureDisplayInfo.dbc")
    cmd = Dbc(io.open(chemin_cmd, "rb").read())
    cdi = Dbc(io.open(chemin_cdi, "rb").read())
    pose_crochet_sol(cmd, cdi)
    with io.open(chemin_cmd, "wb") as f:
        f.write(cmd.octets())
    with io.open(chemin_cdi, "wb") as f:
        f.write(cdi.octets())
    print("Crochets (serveur) : modèle %d, habillages %d et %d posés dans Data%sdbc"
          % (MODELE_ANCRE_ID, MODELE_ANCRE_ID, DISPLAY_VOLANT, BS))

    print("\nLes sorts pointent déjà ces ids (sorts_classes.py) : régénérer par"
          "\n  python gen_sorts_classes.py --deploy   puis rejouer le SQL au démarrage.")


if __name__ == "__main__":
    main()
