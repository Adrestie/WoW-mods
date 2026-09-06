# -*- coding: utf-8 -*-
r"""Monte le visuel rétroporté de la Lumière de l'aube (sort 8600013).

Les modèles viennent du client moderne — wow.export les sort déjà en MD20 —
et vivent dans patch-z sous spells\. Trois DBC les font exister aux yeux du
client, et la chaîne est TOUJOURS la même :

  Spell.SpellVisualID → SpellVisual (quel kit à quel moment)
                       → SpellVisualKit (quel effet à quel point d'attache)
                        → SpellVisualEffectName (le chemin du modèle)

Le montage suit le motif des imports précédents, relu dans l'archive :
  - effets nommés dans la plage 82002xx (la leur), kits et visuel en 300xx ;
  - le chemin s'écrit en .mdx — le client fait la correspondance vers .m2 ;
  - un kit qui ne joue pas d'animation porte -1 dans ses deux premiers champs.

Le visuel 30014 : le CÔNE part du lanceur au lancer (BaseEffect du kit de
lancer — la base suit l'orientation du personnage, et le modèle est dessiné
pour se projeter devant), et chaque allié touché reçoit l'impact de soin au
buste (ChestEffect du kit d'impact).

Deux réparations au passage, idempotentes comme le reste :
  - le cône référence « alpha grad4_paladin.blp » AVEC UNE ESPACE — artefact de
    la listfile de FixTXID. On dépose la texture sous ce nom-là aussi : le M2
    est autoritaire, c'est ce chemin que le client demandera.
  - rien d'autre : skins et textures étaient déjà en place.

    python gen_visuel_aube.py          (JEU FERMÉ requis : écrit dans patch-z)
"""
import ctypes as C
import io
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)

# --- les identifiants -------------------------------------------------------
EFFET_CONE = 8200206
EFFET_IMPACT = 8200207
EFFET_BASE = 8200208
KIT_LANCER = 30014
KIT_IMPACT = 30015
VISUEL = 30014

# Le castworld, essayé d'abord, n'était pas le bon rendu en jeu : c'est le
# coneimpact qui porte l'onde dorée voulue.
MODELE_CONE = "spells" + BS + "paladin_lightofdawn_coneimpact_01.mdx"
MODELE_IMPACT = "spells" + BS + "cfx_paladin_lightofdawn_heal_impact.mdx"
# L'éclat au sol, sous les pieds du lanceur au moment du lancer.
MODELE_BASE = "spells" + BS + "paladin_lightofdawn_impact_base_v2.mdx"


def stormlib():
    dll = C.WinDLL(G.DLL)
    dll.SFileOpenArchive.argtypes = [C.c_wchar_p, C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    dll.SFileOpenArchive.restype = C.c_bool
    dll.SFileCloseArchive.argtypes = [C.c_void_p]
    dll.SFileOpenFileEx.argtypes = [C.c_void_p, C.c_char_p, C.c_uint, C.POINTER(C.c_void_p)]
    dll.SFileOpenFileEx.restype = C.c_bool
    dll.SFileGetFileSize.argtypes = [C.c_void_p, C.POINTER(C.c_uint)]
    dll.SFileGetFileSize.restype = C.c_uint
    dll.SFileReadFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint, C.POINTER(C.c_uint), C.c_void_p]
    dll.SFileReadFile.restype = C.c_bool
    dll.SFileCloseFile.argtypes = [C.c_void_p]
    dll.SFileCreateFile.argtypes = [C.c_void_p, C.c_char_p, C.c_ulonglong, C.c_uint,
                                    C.c_uint, C.c_uint, C.POINTER(C.c_void_p)]
    dll.SFileCreateFile.restype = C.c_bool
    dll.SFileWriteFile.argtypes = [C.c_void_p, C.c_void_p, C.c_uint, C.c_uint]
    dll.SFileWriteFile.restype = C.c_bool
    dll.SFileFinishFile.argtypes = [C.c_void_p]
    dll.SFileFinishFile.restype = C.c_bool
    return dll


def lit(dll, h, chemin):
    fh = C.c_void_p()
    if not dll.SFileOpenFileEx(h, chemin.encode("latin-1"), 0, C.byref(fh)):
        raise SystemExit("absent de l'archive : %s" % chemin)
    taille = dll.SFileGetFileSize(fh, None)
    tampon = (C.c_ubyte * taille)()
    lus = C.c_uint(0)
    dll.SFileReadFile(fh, tampon, taille, C.byref(lus), None)
    dll.SFileCloseFile(fh)
    return bytes(bytearray(tampon))


def repare_bonecountmax(donnees_skin):
    """Renseigne `boneCountMax` s'il est trop bas, et rend le skin tel quel
    sinon. La regle vient d'un skin natif comparable — la goule du Norfendre
    annonce 53 pour 52 os employes : le maximum, plus un."""
    skin = bytearray(donnees_skin)
    if len(skin) < 48 or skin[:4] != b"SKIN":
        return bytes(skin)
    ns, ofs = struct.unpack_from("<2I", skin, 28)
    pire = 0
    for i in range(ns):
        pire = max(pire, struct.unpack_from("<10H", skin, ofs + i * 48)[6])
    if struct.unpack_from("<I", skin, 44)[0] > pire:
        return bytes(skin)
    struct.pack_into("<I", skin, 44, pire + 1)
    return bytes(skin)


def accorde_rubans(donnees_m2):
    """Ramene le nombre de textures d'un ruban a son nombre de materiaux.

    Un `M2Ribbon` (176 octets) porte `textureIndices` a +0x14 et
    `materialIndices` a +0x1C, deux tableaux que le client 3.3.5 parcourt
    ENSEMBLE. Les modeles modernes declarent trois textures pour un seul
    materiau : le client lit alors deux materiaux HORS du tableau et rend la
    trainee avec un fondu pris au hasard de la memoire. On reduit le COMPTE,
    sans deplacer le tableau : la premiere couche, la principale, reste."""
    m2 = bytearray(donnees_m2)
    if len(m2) < 0x130 or m2[:4] != b"MD20":
        return bytes(m2)
    nr, orb = struct.unpack_from("<2I", m2, 0x120)
    accordes = 0
    for i in range(nr):
        o = orb + i * 176
        if o + 176 > len(m2):
            break
        nti = struct.unpack_from("<I", m2, o + 0x14)[0]
        nmi = struct.unpack_from("<I", m2, o + 0x1C)[0]
        if nmi and nti > nmi:
            struct.pack_into("<I", m2, o + 0x14, nmi)
            accordes += 1
    if accordes:
        print("rubans accordés : %d sur %d (textures ramenées au nombre de "
              "matériaux)" % (accordes, nr))
    return bytes(m2)


def ecrit(dll, h, chemin, donnees):
    # TOUT MODELE QUI ENTRE DANS L'ARCHIVE passe par ici, comme les skins
    # ci-dessous : c'est le seul point que les dix generateurs partagent.
    if chemin.lower().endswith(".m2"):
        donnees = accorde_rubans(donnees)
    # TOUT SKIN QUI ENTRE DANS L'ARCHIVE passe par ici : c'est le seul point
    # que les dix generateurs partagent. Reparer `boneCountMax` a cet endroit
    # vaut pour ceux d'aujourd'hui comme pour ceux de demain, et ne peut rien
    # casser — un tampon correctement dimensionne n'a jamais nui.
    if chemin.lower().endswith(".skin"):
        donnees = repare_bonecountmax(donnees)
    fh = C.c_void_p()
    if not dll.SFileCreateFile(h, chemin.encode("latin-1"), 0, len(donnees), 0,
                               0x00000200 | 0x80000000, C.byref(fh)):
        raise SystemExit("écriture impossible : %s (jeu ouvert ?)" % chemin)
    tampon = (C.c_ubyte * len(donnees)).from_buffer_copy(donnees)
    if not dll.SFileWriteFile(fh, tampon, len(donnees), 0):
        raise SystemExit("écriture interrompue : %s" % chemin)
    dll.SFileFinishFile(fh)


class Dbc:
    """Un DBC en mémoire : retirer nos lignes (idempotence), en poser de
    nouvelles, réécrire l'en-tête."""

    def __init__(self, brut):
        magic, self.nrec, self.nfield, self.rsize, ssize = struct.unpack_from("<4s4I", brut, 0)
        if magic != b"WDBC":
            raise SystemExit("pas un DBC")
        self.enr = bytearray(brut[20:20 + self.nrec * self.rsize])
        self.chaines = bytearray(brut[20 + self.nrec * self.rsize:])

    def retire(self, ids):
        garde = bytearray()
        for i in range(self.nrec):
            off = i * self.rsize
            if struct.unpack_from("<I", self.enr, off)[0] not in ids:
                garde.extend(self.enr[off:off + self.rsize])
        self.nrec = len(garde) // self.rsize
        self.enr = garde

    def chaine(self, txt):
        pos = len(self.chaines)
        self.chaines.extend(txt.encode("latin-1") + b"\x00")
        return pos

    def pose(self, valeurs):
        if len(valeurs) != self.nfield:
            raise SystemExit("%d champs fournis, %d attendus" % (len(valeurs), self.nfield))
        rec = bytearray(self.rsize)
        for k, v in enumerate(valeurs):
            if isinstance(v, float):
                struct.pack_into("<f", rec, k * 4, v)
            else:
                struct.pack_into("<i" if v < 0 else "<I", rec, k * 4, v)
        self.enr.extend(rec)
        self.nrec += 1

    def octets(self):
        entete = struct.pack("<4s4I", b"WDBC", self.nrec, self.nfield,
                             self.rsize, len(self.chaines))
        return entete + bytes(self.enr) + bytes(self.chaines)


def blp_transparent():
    """Un BLP2 de 8x8, entièrement transparent : la texture qui ne dessine rien.

    Format PALETTISÉ (compression 1) avec alpha sur 8 bits : c'est celui que
    tout lecteur de 3.3.5 sait lire. Le format BGRA brut (compression 3),
    essayé d'abord, rendait la texture ILLISIBLE — et une texture illisible
    s'affiche en vert, ce qui remplaçait la fumée par de la fumée verte.

    Après l'en-tête : la palette de 256 couleurs (toutes nulles), puis 64
    index de pixels (tous 0) et 64 octets d'alpha (tous 0).
    """
    entete = struct.pack("<4sI4B2I", b"BLP2", 1, 1, 8, 0, 0, 8, 8)
    offsets = [20 + 128 + 1024] + [0] * 15
    tailles = [128] + [0] * 15
    return (entete + struct.pack("<16I", *offsets) + struct.pack("<16I", *tailles)
            + bytes(1024) + bytes(128))


def _ancien():
    return (b"\x00" * 1024 + b"\x00\x00\x00\x00")


def main():
    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        prefixe = "DBFilesClient" + BS

        # --- SpellVisualEffectName : les deux modèles -----------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        d.retire({EFFET_CONE, EFFET_IMPACT, EFFET_BASE})
        d.pose([EFFET_CONE, d.chaine("Lumiere de l'aube - cone"),
                d.chaine(MODELE_CONE), 1.0, 1.0, 0.01, 100.0])
        d.pose([EFFET_IMPACT, d.chaine("Lumiere de l'aube - impact"),
                d.chaine(MODELE_IMPACT), 1.0, 1.0, 0.01, 100.0])
        d.pose([EFFET_BASE, d.chaine("Lumiere de l'aube - sol"),
                d.chaine(MODELE_BASE), 1.0, 1.0, 0.01, 100.0])
        ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())
        print("SpellVisualEffectName : effets %d et %d posés" % (EFFET_CONE, EFFET_IMPACT))

        # --- SpellVisualKit : lancer (base) et impact (buste) ---------------
        # 38 champs : ID, StartAnim, Anim, Head, Chest, Base, LeftHand,
        # RightHand, Breath, LWeapon, RWeapon, Special x3, World, Sound,
        # Shake, puis les blocs de proc — tous à zéro ici.
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_LANCER, KIT_IMPACT})
        # Le onzième champ est le premier emplacement « spécial » : il se rend à
        # l'origine du personnage — c'est lui qui porte l'éclat au sol.
        #
        # Le CÔNE s'accroche au BUSTE, pas à la base : ancré aux pieds, il
        # partait du sol. Et l'animation 54 est celle des kits Blizzard de sorts
        # instantanés — Choc sacré, Consécration, Bénédiction de puissance la
        # portent tous ; sans elle le personnage restait de marbre.
        kit = lambda ident, anim, chest, base, special=0: (
            [ident, -1, anim, 0, chest, base, 0, 0, 0, 0, 0, special] + [0] * 26)
        d.pose(kit(KIT_LANCER, 54, EFFET_CONE, 0, EFFET_BASE))
        d.pose(kit(KIT_IMPACT, -1, EFFET_IMPACT, 0))   # le soin fleurit au buste
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (lancer) et %d (impact) posés" % (KIT_LANCER, KIT_IMPACT))

        # --- SpellVisual : le kit de lancer au lancer, l'impact sur chaque cible
        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL})
        d.pose([VISUEL, 0, KIT_LANCER, KIT_IMPACT] + [0] * 28)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : visuel %d posé" % VISUEL)

        # --- la fumée du modèle de soin -------------------------------------
        # L'émetteur 2 de heal_impact emploie une texture de fumée ; les trois
        # autres font l'éclat doré. On repointe cette seule texture vers un BLP
        # entièrement transparent, plutôt que de perdre le modèle : l'émetteur
        # tourne toujours, mais ne dessine plus rien.
        VIDE = "spells" + BS + "papota_vide.blp"
        fh = C.c_void_p()
        if not dll.SFileOpenFileEx(h, VIDE.encode("latin-1"), 0, C.byref(fh)):
            ecrit(dll, h, VIDE, blp_transparent())
            print("BLP transparent créé : %s" % VIDE)
        else:
            dll.SFileCloseFile(fh)
        m2 = bytearray(lit(dll, h, "spells" + BS + "cfx_paladin_lightofdawn_heal_impact.m2"))
        ntex, otex = struct.unpack_from("<2I", m2, 0x50)
        typ, fl, ln, on = struct.unpack_from("<4I", m2, otex + 2 * 16)
        actuel = bytes(m2[on:on + ln]).split(b"\x00")[0].decode("latin-1")
        if "papota_vide" not in actuel:
            pos = len(m2)
            m2.extend(VIDE.encode("latin-1") + b"\x00")
            struct.pack_into("<2I", m2, otex + 2 * 16 + 8, len(VIDE) + 1, pos)
            ecrit(dll, h, "spells" + BS + "cfx_paladin_lightofdawn_heal_impact.m2", bytes(m2))
            print("fumée neutralisée : texture 2 de heal_impact -> BLP transparent")
        else:
            print("fumée déjà neutralisée")

        # --- la texture au nom fautif ---------------------------------------
        # Le M2 demande « alpha grad4_paladin.blp », avec une espace : artefact
        # de la listfile de FixTXID. Le M2 est autoritaire — on dépose la
        # texture sous ce nom-là aussi.
        blp = lit(dll, h, "spells" + BS + "alphagrad4_paladin.blp")
        ecrit(dll, h, "spells" + BS + "alpha grad4_paladin.blp", blp)
        print("texture dupliquée sous le nom à espace que demande le M2")
    finally:
        dll.SFileCloseArchive(h)
    print("\nReste à pointer le sort : visuel %d dans sorts_classes.py." % VISUEL)


if __name__ == "__main__":
    main()
