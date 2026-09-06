# -*- coding: utf-8 -*-
r"""Monte les visuels du prêtre : la Plume angélique (8600040).

Sources préparées dans `art_pretre\` (montage du 2026-08-31) : le modèle
priest_angelicfeather_state converti en v264 par MultiConverter, chemins de
texture inscrits par inscrit_textures.py depuis le brut MD21, ses sept
textures et l'icône moderne ability_priest_angelicfeather.

La plume est une CRÉATURE habillée du modèle (patron de l'ancre du grappin
et de l'orbe du mage) : c'est le seul moyen d'avoir un objet posé au sol qui
DÉTECTE le passage d'un allié — son IA (npc_papota_plume) donne le bienfait
au premier qui la touche et s'efface aussitôt.

    python gen_visuel_pretre.py        (JEU FERMÉ requis : écrit dans patch-z)
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
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_pretre")
DBC_SERVEUR_DIR = r"D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc"

DISPLAY_PLUME = 802108
MODELE_PLUME = "spells" + BS + "priest_angelicfeather_state.mdx"
ECHELLE_PLUME = 1.0          # cadran de taille, réglable en jeu
ICONE_PLUME = 8061
NOM_ICONE_PLUME = "ability_priest_angelicfeather"

MODELES = {                  # m2 -> son .skin, contrôle texUnitLookup
    "priest_angelicfeather_state.m2": "priest_angelicfeather_state00.skin",
    "shadow_nova_area.m2": "shadow_nova_area00.skin",
    "7fx_paladin_holybubble.m2": "7fx_paladin_holybubble00.skin",
}

# --- les deux halos : leurs lots ont perdu une unité de texture -------------
# « Il manque des textures dans les effets » (2026-09-01). Relevé : les deux
# tables de correspondance du modèle, texLookup ET uvanimLookup, valent
# TOUTES DEUX [0, 1, 2, 3, 2, 4] — six entrées bâties par PAIRES, pour trois
# lots à deux textures : (0,1), (2,3) et (2,4). Or l'export ne déclare qu'UNE
# unité aux lots 1 et 2 : les textures 3 et 4, les deux 1024 et 512 nommées
# d'après le modèle — son art propre — ne sont jamais liées, et les couches
# concernées se retrouvent nues. On rend leur deuxième unité à ces lots, puis
# on rallonge les tables que cette unité en plus fait déborder.
HALOS = {"cfx_priest_halo_cast02.m2": "cfx_priest_halo_cast0200.skin",
         "cfx_priest_halo_cast.m2": "cfx_priest_halo_cast00.skin"}
SKINS_HALO = set(HALOS.values())


def paires_de_textures(donnees_skin):
    """Rend sa deuxième unité à tout lot qui n'en déclare qu'une."""
    s = bytearray(donnees_skin)
    nb, ob = struct.unpack_from("<2I", s, 4 + 32)
    rendus = 0
    for i in range(nb):
        o = ob + i * 24
        if struct.unpack_from("<H", s, o + 14)[0] == 1:
            struct.pack_into("<H", s, o + 14, 2)
            rendus += 1
    return bytes(s), rendus


def rallonge_tables(donnees, donnees_skin):
    """Les tables d'unité et de transparence, portées à ce que les lots
    PROMUS réclament. Une entrée manquante, c'est une lecture hors bornes :
    l'erreur 132 dans un cas, le mesh dégénéré dans l'autre. La table est
    ajoutée en fin de fichier et l'en-tête repointé — rien d'existant ne
    bouge, et l'outil est idempotent."""
    m2 = bytearray(donnees)
    nb, ob = struct.unpack_from("<2I", donnees_skin, 4 + 32)
    # 0x88 = table des unités (indexée par texCoordCombo), 0x90 = table de
    # transparence (indexée par texWeightCombo).
    for entete, champ, defaut in ((0x88, 18, None), (0x90, 20, "dernier")):
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
            table.append(table[-1] if defaut and table else len(table))
        struct.pack_into("<2I", m2, entete, besoin, len(m2))
        m2.extend(struct.pack("<%dh" % besoin, *table))
        print("table 0x%X portée à %d entrée(s) %s" % (entete, besoin, table))
    return bytes(m2)

# --- Halo (8600043, montage du 2026-09-01) ----------------------------------
# Deux modèles, deux temps : l'anneau S'OUVRE (cast02) puis SE REFERME
# (cast), chacun 3334 ms de Stand — d'où les trois secondes entre les deux
# vagues. Ils habillent une même créature-ancre posée à la position du
# lanceur : le halo reste où il est né, même si le prêtre s'en va.
DISPLAY_HALO_OUVRE = 802110
DISPLAY_HALO_FERME = 802111
MODELE_HALO_OUVRE = "spells" + BS + "cfx_priest_halo_cast02.mdx"
MODELE_HALO_FERME = "spells" + BS + "cfx_priest_halo_cast.mdx"
ECHELLE_HALO = 1.0
SON_HALO = 990114
FICHIER_SON_HALO = "spell_velenshalo_cast.wav"
KIT_SON_HALO = 30050         # le son du lancement, joué sur le prêtre
ICONE_HALO = 8063
NOM_ICONE_HALO = "ability_priest_halo"
# Les impacts NATIFS sur les cibles (relevés : Châtiment 128 -> kit 291,
# Soins inférieurs 285 -> kit 442), portés par deux visuels à nous qui ne
# gardent QUE l'impact — le lancement se joue sur l'ancre invisible.
KIT_IMPACT_DEGATS_SACRE = 291
KIT_IMPACT_SOIN_SACRE = 442
VISUEL_HALO_DEGATS = 30048
VISUEL_HALO_SOIN = 30049
VISUEL_HALO_LANCER = 30051

# --- Mot de pouvoir : Barrière (8600042, montage du 2026-09-01) -------------
# Le dôme exporté habille une CRÉATURE posée au réticule (display 802109),
# comme la plume : c'est elle qui tient la réserve d'absorption commune et
# distribue la protection aux alliés. Le son de boucle vit dans un kit joué
# sur elle (gabarit 3087, le bourdon du drain : il tourne tant que le kit
# vit). Les protégés portent le kit d'ÉTAT de Protection divine (11101,
# natif) — un effet sacré, et surtout PAS celui de Mot de pouvoir :
# Bouclier (847), écarté à la demande.
DISPLAY_BARRIERE = 802109
MODELE_BARRIERE = "spells" + BS + "7fx_paladin_holybubble.mdx"
ECHELLE_BARRIERE = 1.0       # cadran de taille, réglable en jeu
SON_BARRIERE = 990113
FICHIER_SON_BARRIERE = "holy_drone_loop.wav"
GABARIT_SON_BOUCLE = 3087
KIT_SON_BARRIERE = 30045     # le bourdon, joué sur le dôme
# Kit d'état des protégés : le 11101 (Protection divine) ne rendait RIEN en
# jeu — son effet est accroché au torse (champ 4) et ne s'est pas vu. On
# prend le 252, l'état du BOUCLIER DIVIN : effet au point de base, halo doré
# franc. Ce n'est pas celui de Mot de pouvoir : Bouclier (847), écarté à la
# demande.
KIT_ETAT_PROTECTION = 252
VISUEL_PROTECTION = 30046    # notre visuel, qui ne porte que ce kit d'état
# Le précast SACRÉ (champ 1 du visuel) : le kit 99, partagé par l'Éclair
# sacré, les Soins inférieurs et la Prière de guérison — anim 52, mains de
# Lumière, son 740. Porté par un visuel à nous, le sort n'en ayant aucun.
KIT_PRECAST_SACRE = 99
VISUEL_BARRIERE_LANCER = 30047
# L'apparition et la disparition du dôme : ses séquences Birth (127) et
# Decay (159), jouées par emotes customs — le modèle dure 17 s en Stand, il
# ne les joue pas de lui-même.
EMOTE_BIRTH = 990003
EMOTE_DECAY = 990001         # déjà posée par gen_visuel_mage (anim 159)
GABARIT_EMOTE = 3            # EMOTE_ONESHOT_WAVE, un one-shot natif
ANIM_BIRTH = 127

# --- Mot de l'ombre : désespoir (8600041, montage du 2026-09-01) ------------
# La nova d'ombre exportée, jouée AU SOL sous le prêtre au lancement, avec le
# son exporté dans le même kit. Rien d'autre : les deux maléfices posés sur
# les ennemis gardent leurs propres visuels natifs.
EFFET_DESESPOIR = 8200221
KIT_DESESPOIR = 30044
VISUEL_DESESPOIR = 30044
SON_DESESPOIR = 990112
ICONE_DESESPOIR = 8062
NOM_ICONE_DESESPOIR = "spell_shadow_painandsuffering"
MODELE_DESESPOIR = "spells" + BS + "shadow_nova_area.mdx"
FICHIER_SON_DESESPOIR = "hauntimpact3.wav"
GABARIT_SON = 3011           # un son de sort one-shot (la Boule de feu)
ANIM_LANCER_OMBRE = 54       # l'animation de lancer, comme le paladin
# Le kit de PRÉCAST des sorts d'Ombre (champ 1 du visuel) : celui que
# partagent Mot de l'ombre : Douleur (visuel 71) et Toucher vampirique
# (3582) — anim 52, mains ténébreuses, son 745. NATIF, jamais modifié : sans
# lui, le prêtre restait immobile pendant les 3 s d'incantation.
KIT_PRECAST_OMBRE = 217


def fichiers_a_injecter():
    paires = []
    for nom in sorted(os.listdir(os.path.join(ART, "spells"))):
        if nom.endswith((".m2", ".skin", ".blp")):
            paires.append((os.path.join(ART, "spells", nom),
                           "spells" + BS + nom))
    for nom_icone in (NOM_ICONE_PLUME, NOM_ICONE_DESESPOIR, NOM_ICONE_HALO):
        ic = os.path.join(ART, "interface", "icons", nom_icone + ".blp")
        paires.append((ic, "Interface" + BS + "Icons" + BS
                       + nom_icone + ".blp"))
    for nom in sorted(os.listdir(os.path.join(ART, "sound", "spells"))):
        if nom.endswith(".wav"):
            paires.append((os.path.join(ART, "sound", "spells", nom),
                           "Sound" + BS + "Spells" + BS + nom))
    return paires


def pose_plume(cmd, cdi):
    """L'habillage DISPLAY_PLUME dans CreatureModelData +
    CreatureDisplayInfo — patron de l'ancre du grappin : clone du Poulet,
    chemin remplacé, échelle 1, champs sonores/empreintes à zéro."""
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

    habillages = ((DISPLAY_PLUME, MODELE_PLUME, ECHELLE_PLUME),
                  (DISPLAY_BARRIERE, MODELE_BARRIERE, ECHELLE_BARRIERE),
                  (DISPLAY_HALO_OUVRE, MODELE_HALO_OUVRE, ECHELLE_HALO),
                  (DISPLAY_HALO_FERME, MODELE_HALO_FERME, ECHELLE_HALO))
    cmd.retire({ident for ident, _m, _e in habillages})
    cdi.retire({ident for ident, _m, _e in habillages})
    for ident, modele, echelle in habillages:
        gabarit = list(poulet)
        gabarit[0] = ident
        gabarit[2] = cmd.chaine(modele)
        gabarit[4] = struct.unpack("<I", struct.pack("<f", 1.0))[0]
        for k in range(5, 14):
            gabarit[k] = 0
        cmd.pose(gabarit)
        cdi.pose([ident, ident, 0, 0, echelle, 255,
                  0, 0, 0, 0, 0, 0, 0, 0, 0, 0])


def main():
    sauvegarde = G.ARCHIVE + ".avant_art_pretre"
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
            if nom in MODELES:
                donnees = repare_texunit(donnees, os.path.join(
                    ART, "spells", MODELES[nom]))
            elif nom in HALOS:
                skin, _ = paires_de_textures(io.open(os.path.join(
                    ART, "spells", HALOS[nom]), "rb").read())
                donnees = rallonge_tables(donnees, skin)
            elif nom in SKINS_HALO:
                donnees, rendus = paires_de_textures(donnees)
                print("%s : deuxième unité de texture rendue à %d lot(s)"
                      % (nom, rendus))
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

        brut, source = lit_effectif(dll, h, "SpellIcon.dbc")
        d = Dbc(brut)
        d.retire({ICONE_PLUME, ICONE_DESESPOIR, ICONE_HALO})
        for ident, nom_icone in ((ICONE_PLUME, NOM_ICONE_PLUME),
                                 (ICONE_DESESPOIR, NOM_ICONE_DESESPOIR),
                                 (ICONE_HALO, NOM_ICONE_HALO)):
            d.pose([ident, d.chaine("Interface" + BS + "Icons" + BS
                                    + nom_icone)])
        ecrit(dll, h, prefixe + "SpellIcon.dbc", d.octets())
        print("SpellIcon : %d -> %s et %d -> %s — base %s"
              % (ICONE_PLUME, NOM_ICONE_PLUME, ICONE_DESESPOIR,
                 NOM_ICONE_DESESPOIR, source))

        # --- SoundEntries : le son du désespoir -------------------------------
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
        if gabarit is None:
            raise SystemExit("gabarit sonore %d absent" % GABARIT_SON)
        boucle = None
        for i in range(d.nrec):
            off = i * d.rsize
            if struct.unpack_from("<I", d.enr, off)[0] == GABARIT_SON_BOUCLE:
                boucle = [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                          for k in range(30)]
        if boucle is None:
            raise SystemExit("gabarit sonore %d absent" % GABARIT_SON_BOUCLE)
        d.retire({SON_DESESPOIR, SON_BARRIERE, SON_HALO})

        def entree_son(gab, ident, nom_son, fichier):
            v = list(gab)
            v[0] = ident
            v[2] = d.chaine(nom_son)
            for k in range(10):
                v[3 + k] = d.chaine(fichier) if k == 0 else 0
                v[13 + k] = 1 if k == 0 else 0
            v[23] = d.chaine("Sound" + BS + "Spells")
            return v

        d.pose(entree_son(gabarit, SON_DESESPOIR, "PapotaDesespoir",
                          FICHIER_SON_DESESPOIR))
        d.pose(entree_son(boucle, SON_BARRIERE, "PapotaBarriere",
                          FICHIER_SON_BARRIERE))
        d.pose(entree_son(gabarit, SON_HALO, "PapotaHalo",
                          FICHIER_SON_HALO))
        ecrit(dll, h, prefixe + "SoundEntries.dbc", d.octets())
        print("SoundEntries : %d (désespoir) et %d (barrière, gabarit %d —"
              " il boucle) posés — base %s"
              % (SON_DESESPOIR, SON_BARRIERE, GABARIT_SON_BOUCLE, source))

        # --- SpellVisualEffectName / Kit / Visual : la nova d'ombre -----------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        d.retire({EFFET_DESESPOIR})
        d.pose([EFFET_DESESPOIR, d.chaine("Desespoir - nova"),
                d.chaine(MODELE_DESESPOIR), 1.0, 1.0, 0.01, 100.0])
        ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())
        print("SpellVisualEffectName : effet %d (nova d'ombre) posé"
              % EFFET_DESESPOIR)

        # Le modèle au point d'attache Base (champ 5) : la nova s'ouvre au
        # sol sous le prêtre ; l'animation de lancer et le son avec.
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_DESESPOIR, KIT_SON_BARRIERE})
        d.pose([KIT_DESESPOIR, -1, ANIM_LANCER_OMBRE, 0, 0, EFFET_DESESPOIR]
               + [0] * 9 + [SON_DESESPOIR, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Le bourdon de la barrière : SON SEUL, joué sur le dôme.
        d.pose([KIT_SON_BARRIERE, -1, -1, 0, 0] + [0] * 10
               + [SON_BARRIERE, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Le lancement du halo : SON SEUL, joué sur le prêtre.
        d.pose([KIT_SON_HALO, -1, -1, 0, 0] + [0] * 10
               + [SON_HALO, 0] + [-1, -1, -1, -1] + [0] * 17)
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (nova + son + anim %d) et %d (bourdon"
              " de la barrière) posés"
              % (KIT_DESESPOIR, ANIM_LANCER_OMBRE, KIT_SON_BARRIERE))

        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL_DESESPOIR, VISUEL_PROTECTION,
                  VISUEL_BARRIERE_LANCER, VISUEL_HALO_DEGATS,
                  VISUEL_HALO_SOIN, VISUEL_HALO_LANCER})
        v = [0] * 32
        v[0] = VISUEL_DESESPOIR
        v[1] = KIT_PRECAST_OMBRE      # l'incantation, mains ténébreuses
        v[2] = KIT_DESESPOIR          # le lancer : la nova et le son
        d.pose(v)
        # La protection : rien que le kit d'ÉTAT sacré sur le porteur.
        p = [0] * 32
        p[0] = VISUEL_PROTECTION
        p[4] = KIT_ETAT_PROTECTION
        d.pose(p)
        # Le lancer de la barrière : rien que le précast sacré.
        b = [0] * 32
        b[0] = VISUEL_BARRIERE_LANCER
        b[1] = KIT_PRECAST_SACRE
        d.pose(b)
        # Le halo : le son au lancement, et deux visuels qui ne gardent QUE
        # l'impact natif — sinon le lancer se jouerait sur l'ancre invisible.
        for ident, champ, kit in ((VISUEL_HALO_LANCER, 2, KIT_SON_HALO),
                                  (VISUEL_HALO_DEGATS, 3,
                                   KIT_IMPACT_DEGATS_SACRE),
                                  (VISUEL_HALO_SOIN, 3, KIT_IMPACT_SOIN_SACRE)):
            hv = [0] * 32
            hv[0] = ident
            hv[champ] = kit
            d.pose(hv)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : visuels %d (halo, son %d), %d (impact dégâts"
              " sacrés %d) et %d (impact soin sacré %d) posés"
              % (VISUEL_HALO_LANCER, KIT_SON_HALO, VISUEL_HALO_DEGATS,
                 KIT_IMPACT_DEGATS_SACRE, VISUEL_HALO_SOIN,
                 KIT_IMPACT_SOIN_SACRE))
        print("SpellVisual : visuels %d (désespoir : précast %d, lancer %d),"
              " %d (protection : état natif %d) et %d (barrière : précast"
              " sacré %d) posés"
              % (VISUEL_DESESPOIR, KIT_PRECAST_OMBRE, KIT_DESESPOIR,
                 VISUEL_PROTECTION, KIT_ETAT_PROTECTION,
                 VISUEL_BARRIERE_LANCER, KIT_PRECAST_SACRE))

        # --- Emotes : l'apparition du dôme (Birth) ----------------------------
        # (le Decay 990001 est posé par gen_visuel_mage ; on ne retire ici
        # que la nôtre, les deux générateurs cohabitent dans le même DBC.)
        brut, source = lit_effectif(dll, h, "Emotes.dbc")
        em = Dbc(brut)
        if em.nfield != 7:
            raise SystemExit("Emotes : %d champs, 7 attendus" % em.nfield)
        gab = None
        for i in range(em.nrec):
            off = i * em.rsize
            if struct.unpack_from("<I", em.enr, off)[0] == GABARIT_EMOTE:
                gab = [struct.unpack_from("<I", em.enr, off + k * 4)[0]
                       for k in range(7)]
        if gab is None:
            raise SystemExit("gabarit d'emote %d absent" % GABARIT_EMOTE)
        em.retire({EMOTE_BIRTH})
        gab[0] = EMOTE_BIRTH
        gab[1] = em.chaine("PAPOTABIRTH")
        gab[2] = ANIM_BIRTH
        gab[6] = 0
        em.pose(gab)
        ecrit(dll, h, prefixe + "Emotes.dbc", em.octets())
        print("Emotes : %d (Birth %d) posée — base %s"
              % (EMOTE_BIRTH, ANIM_BIRTH, source))

        brut_cmd, source_cmd = lit_effectif(dll, h, "CreatureModelData.dbc")
        brut_cdi, source_cdi = lit_effectif(dll, h, "CreatureDisplayInfo.dbc")
        cmd, cdi = Dbc(brut_cmd), Dbc(brut_cdi)
        pose_plume(cmd, cdi)
        ecrit(dll, h, prefixe + "CreatureModelData.dbc", cmd.octets())
        ecrit(dll, h, prefixe + "CreatureDisplayInfo.dbc", cdi.octets())
        print("Plume (client) : modèle et habillage %d posés — bases %s / %s"
              % (DISPLAY_PLUME, source_cmd, source_cdi))
    finally:
        dll.SFileCloseArchive(h)

    # --- les mêmes DBC côté SERVEUR (il valide displayids et emotes) --------
    for nom in ("CreatureModelData.dbc", "CreatureDisplayInfo.dbc",
                "Emotes.dbc"):
        chemin = os.path.join(DBC_SERVEUR_DIR, nom)
        if not os.path.exists(chemin):
            raise SystemExit("DBC serveur absent : %s" % chemin)
        sauvegarde = chemin + ".avant_plume"
        if not os.path.exists(sauvegarde):
            shutil.copy2(chemin, sauvegarde)
    chemin_cmd = os.path.join(DBC_SERVEUR_DIR, "CreatureModelData.dbc")
    chemin_cdi = os.path.join(DBC_SERVEUR_DIR, "CreatureDisplayInfo.dbc")
    chemin_em = os.path.join(DBC_SERVEUR_DIR, "Emotes.dbc")
    cmd = Dbc(io.open(chemin_cmd, "rb").read())
    cdi = Dbc(io.open(chemin_cdi, "rb").read())
    em = Dbc(io.open(chemin_em, "rb").read())
    pose_plume(cmd, cdi)
    gab = None
    for i in range(em.nrec):
        off = i * em.rsize
        if struct.unpack_from("<I", em.enr, off)[0] == GABARIT_EMOTE:
            gab = [struct.unpack_from("<I", em.enr, off + k * 4)[0]
                   for k in range(7)]
    if gab is None:
        raise SystemExit("gabarit d'emote %d absent (serveur)" % GABARIT_EMOTE)
    em.retire({EMOTE_BIRTH})
    gab[0] = EMOTE_BIRTH
    gab[1] = em.chaine("PAPOTABIRTH")
    gab[2] = ANIM_BIRTH
    gab[6] = 0
    em.pose(gab)
    with io.open(chemin_cmd, "wb") as f:
        f.write(cmd.octets())
    with io.open(chemin_cdi, "wb") as f:
        f.write(cdi.octets())
    with io.open(chemin_em, "wb") as f:
        f.write(em.octets())
    print("Prêtre (serveur) : habillages %d/%d/%d/%d et emote %d posés dans"
          " Data%sdbc" % (DISPLAY_PLUME, DISPLAY_BARRIERE, DISPLAY_HALO_OUVRE,
                          DISPLAY_HALO_FERME, EMOTE_BIRTH, BS))


if __name__ == "__main__":
    main()
