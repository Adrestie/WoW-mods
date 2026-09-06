# -*- coding: utf-8 -*-
r"""Monte les visuels du druide : les étoiles, la marque de départ, le son.

POURQUOI DES APPARENCES DE CRÉATURE ET PLUS DES KITS D'ÉTAT. Les deux premiers
essais posaient le modèle par une aura à kit d'état sur la créature-étoile, et
RIEN ne s'affichait — ni avec `cfx_druid_starfall_areabase`, ni avec
`moonfire_impact_base`. Deux modèles, même silence : la cause n'était pas le
modèle. Relevé du 2026-09-03 : la créature 803816 porte l'apparence 802102,
c'est-à-dire `Creature\InvisibleStalker\InvisibleStalker.mdx`. Le client n'a
donc aucun corps sur quoi accrocher le kit.

On renverse le procédé : la créature EST l'étoile. Son apparence pointe
directement sur le modèle de l'effet, et changer de couleur n'est plus qu'un
`SetDisplayId`. Plus d'aura, plus de kit, plus de question.

LES ÉTOILES : `fx_spark_cast`, export MODERNE, donc chaîne complète —
MultiConverter (MD21 -> MD20 v264) puis inscrit_textures.py pour les treize
chemins que la conversion laisse vides. Trois copies reteintées en rouge,
jaune et vert, la couleur disant l'âge. La teinte est imposée DEUX FOIS :

  * aux seize clés des cinq émetteurs (piste de couleur du `M2Particle`,
    +0x10C, trois flottants de 0 à 255 par clé) ;
  * aux textures qui ont de la couleur à elles — six des treize, saturation
    moyenne relevée entre 0,27 et 0,83. Le mélange étant multiplicatif, une
    texture jaune vif rendrait tout vert impossible. Les sept autres sont
    grises, partagées entre les trois copies, et prennent la teinte de
    l'émetteur.

LA MARQUE DE DÉPART : `starfall_state_nosun`, joué à la position que le druide
quitte, deux secondes. Celui-là EXISTE en natif 3.3.5 (common-2.mpq, MD20
v264) : on pointe le natif, rien à injecter.

LE SON DU BOSQUET. L'Appel du bosquet (8610019) doit sonner comme le Transfert
du mage. Relevé sur le sort 1953 : kit d'incantation 267 de son 1641, kit
d'impact 3394 de son 3226. On ne reprend pas son visuel — juste ses deux sons,
portés par deux kits qui ne font rien d'autre.

    python gen_visuel_druide.py     (JEU FERMÉ requis : écrit dans patch-z)
"""
import colorsys
import ctypes as C
import io
import json
import os
import struct
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
from dore_textures import ecrit_blp2_dxt5
from gen_visuel_aube import Dbc, stormlib, lit, ecrit
from gen_visuel_demoniste import prefixe_textures
from gen_visuel_voleur import lit_effectif

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)
RACINE_ART = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "art_druide")
ART = os.path.join(RACINE_ART, "spells")
PREFIXE = "papota_"

# --- l'étoile ---------------------------------------------------------------
ETOILE_SOURCE = "fx_spark_cast"
ETOILE_NOM = "papota_etoile_"          # + rouge / jaune / verte
SEUIL_SATURATION = 0.15                # au-delà, la texture a sa couleur

# Rouge, jaune, verte : de la plus ancienne à la plus récente.
COULEURS = (
    ("rouge", 0.00, 802103),
    ("jaune", 0.13, 802104),
    ("verte", 0.33, 802105),
)
SATURATION_MIN = 0.55     # les clés grises doivent PRENDRE la teinte

# --- la marque de départ ----------------------------------------------------
DEPART_MODELE = "spells" + BS + "starfall_state_nosun.mdx"
DEPART_DISPLAY = 802106

ECHELLE = 1.00            # les deux boîtes font 1 à 2 m : taille naturelle

# --- Solstice et Équinoxe ---------------------------------------------------
# Export MODERNE : MultiConverter (MD21 -> MD20 v264) puis inscrit_textures.py
# pour les vingt-sept chemins que la conversion laisse vides. Vingt et une de
# ces textures sont partagées avec d'autres effets du client — le préfixe
# n'est donc pas une coquetterie, c'est ce qui empêche patch-c de nous les
# masquer (relevé du 2026-09-03, missile du Cataclysme).
SOLSTICE_SOURCE = "9fx_lunar_dark_moonfire_impact_base"
SOLSTICE_NOM = "papota_solstice"
EFFET_SOLSTICE = 8200242
KIT_SOLSTICE = 30095
VISUEL_SOLSTICE = 30095
ECHELLE_SOLSTICE = 1.00   # la boîte fait ~10 m : c'est une frappe, pas un point
ICONE_SOLSTICE = 8075     # après 8073 le tyran et 8074 le cataclysme
SON_SOLSTICE = 990124     # après 990122 et 990123
GABARIT_SON = 3011        # « un coup » : le gabarit sonore du chantier
FICHIER_ICONE_SOLSTICE = "papota_solstice.blp"
FICHIER_SON_SOLSTICE = "papota_solstice.ogg"

# --- Floraison --------------------------------------------------------------
# La zone de soins, importée elle aussi : quatre textures seulement, et un
# modèle taillé pour couvrir une aire. Le kit la pose en ZONE PERSISTANTE
# (champ 25 de SpellVisual) : c'est le champ que le client lit pour l'objet
# dynamique d'un effet 27, et lui seul.
FLORAISON_SOURCE = "druid_fungal_growth_area_state"
FLORAISON_NOM = "papota_floraison"
EFFET_FLORAISON = 8200243
KIT_FLORAISON = 30096
VISUEL_FLORAISON = 30096
# La boîte du modèle fait ~10,5 m de rayon, la zone en veut 15. Le facteur est
# un PREMIER CHOIX : les boîtes mentent quand l'effet est fait de particules
# (RETROPORTAGE_M2.md, section 3 bis), il faudra sans doute le reprendre.
ECHELLE_FLORAISON = 1.40
ICONE_FLORAISON = 8076
SON_FLORAISON = 990125
FICHIER_ICONE_FLORAISON = "papota_floraison.blp"
FICHIER_SON_FLORAISON = "papota_floraison.ogg"

# --- le son du Transfert ----------------------------------------------------
SON_INCANTATION = 1641    # kit 267 du sort 1953
SON_IMPACT = 3226         # kit 3394 du sort 1953
KIT_SON_CAST = 30092
KIT_SON_IMPACT = 30093
VISUEL_BOSQUET = 30092

# --- Retour stellaire : le son du Transfert sur le visuel de la Forme de félin
# (demande du 2026-09-06). Le visuel 4228 garde tout son aspect ; seul son kit
# d'impact 3610 — son 4121 « CatAttack », un rugissement — est remplacé par
# une COPIE qui joue le son 3226 « Teleport » du Transfert. Le visuel 30097
# est une copie de 4228 pointant ce kit ; sorts_classes.py le désigne.
VISUEL_FELIN = 4228
KIT_IMPACT_FELIN = 3610
KIT_RETOUR = 30097
VISUEL_RETOUR = 30097
CHAMP_SON_KIT = 15          # SoundID de SpellVisualKit
CHAMP_IMPACT_VISUEL = 3     # ImpactKit de SpellVisual

# Ce que les essais précédents avaient posé, et qu'on retire : les kits
# d'état ne servent plus, l'apparence de créature les remplace.
ANCIENS_EFFETS = {8200237, 8200238, 8200239, 8200240, 8200241}
ANCIENS_KITS = {30088, 30089, 30090, 30091, 30094}
ANCIENS_VISUELS = {30088, 30089, 30090, 30091, 30094}


def texte(d, offset):
    return d.chaines[offset:d.chaines.index(b"\0", offset)].decode("latin-1")


def saturation_moyenne(image):
    """Saturation moyenne des pixels non transparents."""
    somme = compte = 0
    for r, v, b, a in image.convert("RGBA").getdata():
        if a < 8:
            continue
        somme += colorsys.rgb_to_hsv(r / 255.0, v / 255.0, b / 255.0)[1]
        compte += 1
    return somme / max(compte, 1)


def reteinte_image(image, teinte):
    """Impose la teinte aux pixels QUI EN ONT UNE ; les gris restent gris."""
    im = image.convert("RGBA")
    pixels = list(im.getdata())
    neufs = []
    for r, v, b, a in pixels:
        _h, sat, val = colorsys.rgb_to_hsv(r / 255.0, v / 255.0, b / 255.0)
        if sat >= 0.10:
            nr, nv, nb = colorsys.hsv_to_rgb(teinte, sat, val)
            neufs.append((int(nr * 255), int(nv * 255), int(nb * 255), a))
        else:
            neufs.append((r, v, b, a))
    im.putdata(neufs)
    return im


def reteinte_emetteurs(donnees_m2, teinte):
    """Impose la teinte aux clés de couleur des émetteurs de particules.

    On garde la LUMINOSITÉ de chaque clé — c'est elle qui dessine l'apparition
    et l'extinction — et on remonte la saturation des clés grises pour
    qu'elles prennent la couleur au lieu de rester blanches. Une clé noire
    reste noire : sa luminosité est nulle."""
    m2 = bytearray(donnees_m2)
    nb_emetteurs, offset = struct.unpack_from("<2I", m2, 0x128)
    cles = 0
    for i in range(nb_emetteurs):
        n, ofs = struct.unpack_from("<2I", m2, offset + i * 476 + 0x10C)
        for k in range(n):
            o = ofs + k * 12
            if o + 12 > len(m2):
                break
            r, v, b = struct.unpack_from("<3f", m2, o)
            _h, sat, val = colorsys.rgb_to_hsv(min(r, 255.0) / 255.0,
                                               min(v, 255.0) / 255.0,
                                               min(b, 255.0) / 255.0)
            nr, nv, nb = colorsys.hsv_to_rgb(teinte, max(sat, SATURATION_MIN),
                                             val)
            struct.pack_into("<3f", m2, o, nr * 255.0, nv * 255.0, nb * 255.0)
            cles += 1
    return bytes(m2), nb_emetteurs, cles


def reecrit_textures(donnees_m2, noms):
    """Réécrit les chemins de texture, chacun par son nouveau nom.

    `noms` associe le nom de fichier d'origine au nouveau. Les chaînes sont
    AJOUTÉES en fin de fichier et les couples longueur/décalage réécrits :
    on ne touche pas au bloc existant, dont d'autres décalages dépendent."""
    m2 = bytearray(donnees_m2)
    nt, ot = struct.unpack_from("<2I", m2, 0x50)
    faits = 0
    for i in range(nt):
        off = ot + i * 16
        typ, _fl, lg, ofs = struct.unpack_from("<4I", m2, off)
        if typ != 0 or lg <= 1:
            continue                      # texture variable : pas de chemin
        ancien = bytes(m2[ofs:ofs + lg - 1]).decode("latin-1")
        base = ancien.rsplit(BS, 1)[-1]
        if base not in noms:
            continue
        octets = ("spells" + BS + noms[base]).encode("latin-1") + b"\x00"
        struct.pack_into("<2I", m2, off + 8, len(octets), len(m2))
        m2.extend(octets)
        faits += 1
    return bytes(m2), faits


def enregistrement(d, ident):
    """Les champs d'une ligne du DBC, tels quels (entiers signés : un flottant
    ou un -1 repasse par `pose` avec les mêmes bits)."""
    for i in range(d.nrec):
        off = i * d.rsize
        if struct.unpack_from("<I", d.enr, off)[0] == ident:
            return list(struct.unpack_from("<%di" % d.nfield, d.enr, off))
    raise SystemExit("enregistrement %d absent" % ident)


def pose_retour_stellaire(dll, h, prefixe):
    """Le kit et le visuel de Retour stellaire : la Forme de félin avec le
    son du Transfert à l'impact."""
    d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
    kit = enregistrement(d, KIT_IMPACT_FELIN)
    kit[0], kit[CHAMP_SON_KIT] = KIT_RETOUR, SON_IMPACT
    d.retire({KIT_RETOUR})
    d.pose(kit)
    ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())

    d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
    v = enregistrement(d, VISUEL_FELIN)
    v[0], v[CHAMP_IMPACT_VISUEL] = VISUEL_RETOUR, KIT_RETOUR
    d.retire({VISUEL_RETOUR})
    d.pose(v)
    ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
    print("Retour stellaire : visuel %d = copie de %d, impact par le kit %d "
          "(copie de %d, son %d « Teleport » au lieu de 4121 « CatAttack »)"
          % (VISUEL_RETOUR, VISUEL_FELIN, KIT_RETOUR, KIT_IMPACT_FELIN, SON_IMPACT))


def kit_sonore(ident, son):
    """Un kit qui ne fait QUE jouer un son : champ 15, tout le reste vide."""
    return ([ident, -1, -1, 0, 0, 0] + [0] * 9 + [son, 0]
            + [-1, -1, -1, -1] + [0] * 17)


def pose_apparence(cmd, cdi, ident, chemin, echelle=ECHELLE):
    """Une apparence de créature sur un modèle à nous.

    Clone du Poulet, le gabarit du chantier : il porte déjà des valeurs
    saines partout, on ne change que le chemin et l'échelle. Sang, empreintes
    et sons du poulet sont remis à zéro — un effet de sort n'en a que faire."""
    if cmd.nfield != 28 or cdi.nfield != 16:
        raise SystemExit("CreatureModelData/DisplayInfo : champs inattendus")
    poulet = None
    for i in range(cmd.nrec):
        off = i * cmd.rsize
        p = texte(cmd, struct.unpack_from("<I", cmd.enr, off + 8)[0]).lower()
        if p.endswith("chicken.mdx") or p.endswith("chicken.m2"):
            poulet = [struct.unpack_from("<I", cmd.enr, off + k * 4)[0]
                      for k in range(28)]
            break
    if poulet is None:
        raise SystemExit("gabarit Chicken absent de CreatureModelData")

    cmd.retire({ident})
    modele = list(poulet)
    modele[0] = ident
    modele[2] = cmd.chaine(chemin)
    modele[4] = struct.unpack("<I", struct.pack("<f", echelle))[0]
    for k in range(5, 14):
        modele[k] = 0
    cmd.pose(modele)

    cdi.retire({ident})
    cdi.pose([ident, ident, 0, 0,
              struct.unpack("<I", struct.pack("<f", 1.0))[0], 255,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0])


def prepare_etoiles():
    """Les trois modèles reteintés et la liste des fichiers à injecter.

    Rend (fichiers, rapport) : `fichiers` associe le chemin dans l'archive au
    contenu, `rapport` sert à l'affichage."""
    source = io.open(os.path.join(ART, ETOILE_SOURCE + ".m2"), "rb").read()
    # GARDE-FOU : le client 3.3.5 ne lit que le MD20 v264. Un export brut
    # recopié par-dessus le converti passerait inaperçu jusqu'au plantage.
    if source[:4] != b"MD20" or struct.unpack_from("<I", source, 4)[0] != 264:
        raise SystemExit("%s n'est pas du MD20 v264 : passer MultiConverter"
                         % ETOILE_SOURCE)
    skin = io.open(os.path.join(ART, ETOILE_SOURCE + "00.skin"), "rb").read()

    # LES SIENNES SEULEMENT : la liste vient du manifeste, pas du dossier —
    # celui-ci porte aussi les textures de Solstice et Équinoxe, et les
    # reteinter toutes gonflerait l'archive de copies que rien ne lit.
    manifeste = json.load(io.open(
        os.path.join(ART, ETOILE_SOURCE + ".manifest.json"), encoding="utf-8"))
    siennes = sorted({os.path.basename(t["file"].replace("\\", "/"))
                      for t in manifeste["textures"]})

    # Quelles textures ont une couleur à elles, et lesquelles sont grises ?
    colorees, grises = {}, {}
    for nom in siennes:
        image = Image.open(os.path.join(ART, nom))
        if saturation_moyenne(image) >= SEUIL_SATURATION:
            colorees[nom] = image
        else:
            grises[nom] = image

    fichiers = {}
    # Les grises sont PARTAGÉES : un seul exemplaire pour les trois couleurs.
    for nom in grises:
        fichiers["spells" + BS + PREFIXE + nom] = io.open(
            os.path.join(ART, nom), "rb").read()

    rapport = []
    for nom, teinte, _display in COULEURS:
        noms = {b: PREFIXE + b for b in grises}
        for base, image in colorees.items():
            neuf = PREFIXE + nom + "_" + base
            noms[base] = neuf
            chemin = os.path.join(ART, "reteinte_" + nom + "_" + base)
            ecrit_blp2_dxt5(reteinte_image(image, teinte), chemin)
            fichiers["spells" + BS + neuf] = io.open(chemin, "rb").read()
        m2, nb, cles = reteinte_emetteurs(source, teinte)
        m2, faits = reecrit_textures(m2, noms)
        fichiers["spells" + BS + ETOILE_NOM + nom + ".m2"] = m2
        fichiers["spells" + BS + ETOILE_NOM + nom + "00.skin"] = skin
        rapport.append((nom, teinte, nb, cles, faits))
    return fichiers, rapport, len(colorees), len(grises)


def prepare_solstice():
    """Le modèle de Solstice et Équinoxe, ses textures préfixées.

    La liste des textures vient du MANIFESTE et non du dossier : art_druide
    porte aussi celles de l'éclat du retour, et deviner par le contenu du
    dossier reviendrait à tout injecter deux fois."""
    dossier = ART
    m2 = io.open(os.path.join(dossier, SOLSTICE_SOURCE + ".m2"), "rb").read()
    # GARDE-FOU : le client 3.3.5 ne lit que le MD20 v264. Un export brut
    # recopié par-dessus le converti passerait inaperçu jusqu'au plantage.
    if m2[:4] != b"MD20" or struct.unpack_from("<I", m2, 4)[0] != 264:
        raise SystemExit("%s n'est pas du MD20 v264 : passer MultiConverter"
                         % SOLSTICE_SOURCE)
    manifeste = json.load(io.open(
        os.path.join(dossier, SOLSTICE_SOURCE + ".manifest.json"),
        encoding="utf-8"))

    fichiers = {"spells" + BS + SOLSTICE_NOM + ".m2": prefixe_textures(m2),
                "spells" + BS + SOLSTICE_NOM + "00.skin": io.open(
                    os.path.join(dossier, SOLSTICE_SOURCE + "00.skin"),
                    "rb").read()}
    for t in manifeste["textures"]:
        nom = os.path.basename(t["file"].replace("\\", "/"))
        fichiers["spells" + BS + PREFIXE + nom] = io.open(
            os.path.join(dossier, nom), "rb").read()
    # L'icône et le son, sous des noms à nous.
    fichiers["Interface" + BS + "Icons" + BS + FICHIER_ICONE_SOLSTICE] = \
        io.open(os.path.join(RACINE_ART, "interface", "icons",
                             FICHIER_ICONE_SOLSTICE), "rb").read()
    fichiers["Sound" + BS + "Spells" + BS + FICHIER_SON_SOLSTICE] = \
        io.open(os.path.join(RACINE_ART, "sound", "spells",
                             FICHIER_SON_SOLSTICE), "rb").read()
    return fichiers, len(manifeste["textures"])


def prepare_importe(source, nom, icone, son):
    """Un effet importé : le modèle converti, ses textures préfixées, son
    icône et son son. La liste des textures vient du MANIFESTE et non du
    dossier — art_druide en porte plusieurs jeux, et deviner par le contenu
    du dossier reviendrait à tout injecter plusieurs fois."""
    m2 = io.open(os.path.join(ART, source + ".m2"), "rb").read()
    # GARDE-FOU : le client 3.3.5 ne lit que le MD20 v264. Un export brut
    # recopié par-dessus le converti passerait inaperçu jusqu'au plantage.
    if m2[:4] != b"MD20" or struct.unpack_from("<I", m2, 4)[0] != 264:
        raise SystemExit("%s n'est pas du MD20 v264 : passer MultiConverter"
                         % source)
    manifeste = json.load(io.open(
        os.path.join(ART, source + ".manifest.json"), encoding="utf-8"))

    fichiers = {"spells" + BS + nom + ".m2": prefixe_textures(m2),
                "spells" + BS + nom + "00.skin": io.open(
                    os.path.join(ART, source + "00.skin"), "rb").read()}
    for t in manifeste["textures"]:
        base = os.path.basename(t["file"].replace("\\", "/"))
        fichiers["spells" + BS + PREFIXE + base] = io.open(
            os.path.join(ART, base), "rb").read()
    fichiers["Interface" + BS + "Icons" + BS + icone] = io.open(
        os.path.join(RACINE_ART, "interface", "icons", icone), "rb").read()
    fichiers["Sound" + BS + "Spells" + BS + son] = io.open(
        os.path.join(RACINE_ART, "sound", "spells", son), "rb").read()
    return fichiers, len(manifeste["textures"])


def pose_son(d, ident, nom_son, fichier):
    """Une entrée sonore, clonée du gabarit du chantier."""
    gabarit = None
    for i in range(d.nrec):
        off = i * d.rsize
        if struct.unpack_from("<I", d.enr, off)[0] == GABARIT_SON:
            gabarit = [struct.unpack_from("<I", d.enr, off + k * 4)[0]
                       for k in range(d.nfield)]
            break
    if gabarit is None:
        raise SystemExit("gabarit sonore %d absent" % GABARIT_SON)
    d.retire({ident})
    v = list(gabarit)
    v[0] = ident
    v[2] = d.chaine(nom_son)
    for k in range(10):
        v[3 + k] = d.chaine(fichier) if k == 0 else 0
        v[13 + k] = 1 if k == 0 else 0
    v[23] = d.chaine("Sound" + BS + "Spells")
    d.pose(v)


def main():
    fichiers, rapport, nb_col, nb_gris = prepare_etoiles()
    solstice, nb_tex = prepare_solstice()
    fichiers.update(solstice)
    floraison, nb_flor = prepare_importe(FLORAISON_SOURCE, FLORAISON_NOM,
                                         FICHIER_ICONE_FLORAISON,
                                         FICHIER_SON_FLORAISON)
    fichiers.update(floraison)
    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        prefixe = "DBFilesClient" + BS

        for chemin, donnees in sorted(fichiers.items()):
            ecrit(dll, h, chemin, donnees)
        print("etoiles : %d texture(s) coloree(s) x3 + %d grise(s) partagee(s)"
              % (nb_col, nb_gris))
        for nom, teinte, nb, cles, faits in rapport:
            print("  %-6s teinte %.2f : %d emetteur(s), %d cle(s), %d chemin(s)"
                  % (nom, teinte, nb, cles, faits))

        # --- les apparences de créature -----------------------------------
        cmd = Dbc(lit(dll, h, prefixe + "CreatureModelData.dbc"))
        cdi = Dbc(lit(dll, h, prefixe + "CreatureDisplayInfo.dbc"))
        for nom, _t, display in COULEURS:
            pose_apparence(cmd, cdi, display,
                           "spells" + BS + ETOILE_NOM + nom + ".mdx")
        pose_apparence(cmd, cdi, DEPART_DISPLAY, DEPART_MODELE)
        ecrit(dll, h, prefixe + "CreatureModelData.dbc", cmd.octets())
        ecrit(dll, h, prefixe + "CreatureDisplayInfo.dbc", cdi.octets())
        print("apparences : %s pour les etoiles, %d pour le depart"
              % (", ".join(str(c[2]) for c in COULEURS), DEPART_DISPLAY))

        print("solstice : %s + %d texture(s) prefixee(s), icone et son"
              % (SOLSTICE_NOM, nb_tex))
        print("floraison : %s + %d texture(s) prefixee(s), icone et son"
              % (FLORAISON_NOM, nb_flor))

        # --- l'icône et le son de Solstice et Équinoxe ---------------------
        brut, source = lit_effectif(dll, h, "SpellIcon.dbc")
        d = Dbc(brut)
        d.retire({ICONE_SOLSTICE, ICONE_FLORAISON})
        for ident, fichier in ((ICONE_SOLSTICE, FICHIER_ICONE_SOLSTICE),
                               (ICONE_FLORAISON, FICHIER_ICONE_FLORAISON)):
            d.pose([ident, d.chaine("Interface" + BS + "Icons" + BS
                                    + fichier[:-4])])
        ecrit(dll, h, prefixe + "SpellIcon.dbc", d.octets())
        print("SpellIcon : %d -> %s (base %s)"
              % (ICONE_SOLSTICE, FICHIER_ICONE_SOLSTICE, source))

        brut, source = lit_effectif(dll, h, "SoundEntries.dbc")
        d = Dbc(brut)
        pose_son(d, SON_SOLSTICE, "PapotaSolstice", FICHIER_SON_SOLSTICE)
        pose_son(d, SON_FLORAISON, "PapotaFloraison", FICHIER_SON_FLORAISON)
        ecrit(dll, h, prefixe + "SoundEntries.dbc", d.octets())
        print("SoundEntries : %d -> %s (base %s)"
              % (SON_SOLSTICE, FICHIER_SON_SOLSTICE, source))

        # --- l'effet, le kit et le visuel ---------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        d.retire(ANCIENS_EFFETS | {EFFET_SOLSTICE, EFFET_FLORAISON})
        d.pose([EFFET_SOLSTICE, d.chaine("Solstice et Equinoxe"),
                d.chaine("spells" + BS + SOLSTICE_NOM + ".mdx"),
                0.0, ECHELLE_SOLSTICE, 0.01, 100.0])
        d.pose([EFFET_FLORAISON, d.chaine("Floraison"),
                d.chaine("spells" + BS + FLORAISON_NOM + ".mdx"),
                0.0, ECHELLE_FLORAISON, 0.01, 100.0])
        ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())

        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire(ANCIENS_KITS | {KIT_SON_CAST, KIT_SON_IMPACT, KIT_SOLSTICE,
                                 KIT_FLORAISON})
        # La zone au point BASE, avec son son : elle s'ouvre sous les pieds
        # de la cible et s'annonce au moment de paraitre.
        d.pose([KIT_FLORAISON, -1, -1, 0, 0, EFFET_FLORAISON] + [0] * 9
               + [SON_FLORAISON, 0] + [-1, -1, -1, -1] + [0] * 17)
        # Le modèle au point BASE — c'est un « impact_base », il se pose au
        # sol sous la cible — et le son dans le champ 15.
        d.pose([KIT_SOLSTICE, -1, -1, 0, 0, EFFET_SOLSTICE] + [0] * 9
               + [SON_SOLSTICE, 0] + [-1, -1, -1, -1] + [0] * 17)
        d.pose(kit_sonore(KIT_SON_CAST, SON_INCANTATION))
        d.pose(kit_sonore(KIT_SON_IMPACT, SON_IMPACT))
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())

        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire(ANCIENS_VISUELS | {VISUEL_BOSQUET, VISUEL_SOLSTICE,
                                    VISUEL_FLORAISON})
        # Champ 25 : la ZONE PERSISTANTE. C'est le champ que le client lit
        # pour l'objet dynamique d'un effet 27 — ni l'impact ni l'etat.
        v = [0] * 32
        v[0], v[25] = VISUEL_FLORAISON, KIT_FLORAISON
        d.pose(v)
        v = [0] * 32
        v[0], v[2], v[3] = VISUEL_BOSQUET, KIT_SON_CAST, KIT_SON_IMPACT
        d.pose(v)
        # Champ 3 : l'IMPACT. Le sort frappe une cible à quarante mètres,
        # l'effet doit donc éclore sur elle et non sur le lanceur.
        v = [0] * 32
        v[0], v[3] = VISUEL_SOLSTICE, KIT_SOLSTICE
        d.pose(v)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : l'impact %d de Solstice, le son %d du bosquet"
              % (VISUEL_SOLSTICE, VISUEL_BOSQUET))

        pose_retour_stellaire(dll, h, prefixe)
    finally:
        dll.SFileCloseArchive(h)


def retour_seul():
    """`--retour` : seulement le kit et le visuel de Retour stellaire."""
    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        pose_retour_stellaire(dll, h, "DBFilesClient" + BS)
    finally:
        dll.SFileCloseArchive(h)
    print("\nLes creatures portent ces apparences (SQL du module) :\n"
          "  python gen_sorts_classes.py --deploy")


if __name__ == "__main__":
    if "--retour" in sys.argv:
        retour_seul()
    else:
        main()
