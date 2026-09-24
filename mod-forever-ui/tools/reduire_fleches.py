# -*- coding: utf-8 -*-
# This file is part of mod-forever-ui.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

"""Reduire le motif des fleches du bord de la minimap.

POURQUOI. Le moteur de 3.3.5 pose lui-meme les fleches des points hors de
portee, a un rayon FIXE dans les unites de la carte -- celui d'une carte de
140, la taille de Minimap.xml. Constate en jeu le 2026-09-24 : agrandir la
carte par sa TAILLE laisse les fleches a l'interieur ; l'agrandir par son
ECHELLE (198 / 140) les porte au bord du trou, comme chez camelot, mais les
grossit du meme facteur. On rend donc au client des images dont le motif est
reduit de 140 / 198 au centre d'une image de meme taille : a l'ecran, la
fleche retrouve sa taille d'avant.

LES TROIS IMAGES ET LEUR METHODE, relevees dans Wow.exe et non supposees : la
fonction de chargement range chaque fichier dans une globale, et chaque
methode de Minimap ecrit dans la sienne.

  Rotating-MinimapArrow        0xbeba24   SetStaticPOIArrowTexture
  Rotating-MinimapGuideArrow   0xbeba2c   SetPOIArrowTexture
  Rotating-MinimapCorpseArrow  0xbeba28   SetCorpsePOIArrowTexture

La quatrieme, Rotating-MinimapGroupArrow (0xbeba20), n'a AUCUNE methode :
le seul moyen de la reduire est de REMPLACER LE FICHIER D'ORIGINE, a son
propre chemin, dans patch-Z. C'est une EXCEPTION a la regle du prefixe
Interface\\ForeverUI, accordee par l'utilisateur le 2026-09-24. Deux
consequences :
  - la fleche de groupe reste reduite meme addon desactive ;
  - tools/deployer.py ne retire de l'archive que ce qui est sous
    Interface\\ForeverUI : si ce fichier quitte data/art, il faut le retirer
    de patch-Z a la main.

La source est le client 3.3.5 lui-meme, lu par sa chaine d'archives SANS
patch-Z : une fois la fleche de groupe versee, c'est notre version que la
chaine rendrait, et relancer l'outil la reduirait une seconde fois. Les
sorties vont dans data/art/, chacune avec son apercu PNG ; tools/deployer.py
les verse ensuite.
"""
import io
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp, mpq  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(RACINE, "data", "art")
SORTIE = os.path.join(ART, "interface", "ForeverUI", "minimap")
# L'exception : la fleche de groupe, a son chemin d'origine.
SORTIE_ORIGINE = os.path.join(ART, "Interface", "Minimap")
ARCHIVE_DU_PROJET = "patch-Z.MPQ"
CLIENT = r"E:\world of warcraft 3.3.5a hd\Data"
BS = chr(92)

# LA RESOLUTION. Reduire le motif dans une image de 32 lui laissait 22,6
# texels, que l'echelle de la carte etirait ensuite de 1,414 : la fleche
# etait AGRANDIE a l'ecran, donc pixelisee (constate en jeu le 2026-09-24).
# L'image sortie fait donc le double -- 64 -- et le motif y tient 45 texels,
# plus que les 32 de l'original : le client le REDUIT au lieu de l'agrandir.
# Et comme les originaux, elle porte sa chaine de mipmaps jusqu'a 1 x 1.
MULTIPLE = 2

CARTE_CLIENT = 140      # Minimap.xml de 3.3.5
CARTE_CAMELOT = 198     # mainline/Minimap.xml
FACTEUR = CARTE_CLIENT / CARTE_CAMELOT

# nom du fichier d'origine -> (dossier de sortie, nom de sortie)
FLECHES = [
    ("Rotating-MinimapArrow", SORTIE, "rotating-minimaparrow"),
    ("Rotating-MinimapGuideArrow", SORTIE, "rotating-minimapguidearrow"),
    ("Rotating-MinimapCorpseArrow", SORTIE, "rotating-minimapcorpsearrow"),
    ("Rotating-MinimapGroupArrow", SORTIE_ORIGINE, "ROTATING-MINIMAPGROUPARROW"),
]


def reduire(nom, chaine, dossier, sortie_nom):
    chemin = BS.join(["Interface", "Minimap", nom + ".blp"])
    largeur, hauteur, rgba, _ = blp.decoder(chaine.read(chemin))
    image = Image.frombytes("RGBA", (largeur, hauteur), bytes(rgba))

    # Reduction AUTOUR DU CENTRE de l'image, et non collage d'une vignette :
    # 32 x 0,7071 ne tombe pas sur un nombre entier, et une vignette de 23
    # serait decalee d'un demi-pixel -- la fleche tournerait alors en
    # oscillant. La transformation affine garde le centre exact.
    # En alpha premultiplie : sinon le bord transparent, souvent noir, bave
    # dans le motif.
    lo, ho = largeur * MULTIPLE, hauteur * MULTIPLE
    echelle = FACTEUR * MULTIPLE        # texels de sortie par texel d'origine
    inverse = 1.0 / echelle
    donnees = (inverse, 0, largeur / 2.0 - (lo / 2.0) * inverse,
               0, inverse, hauteur / 2.0 - (ho / 2.0) * inverse)
    plein = image.convert("RGBa").transform((lo, ho), Image.AFFINE, donnees,
                                             resample=Image.BICUBIC)
    sortie = plein.convert("RGBA")
    l2, h2 = largeur * echelle, hauteur * echelle

    # Les mipmaps, en alpha premultiplie eux aussi, jusqu'a 1 x 1.
    mips = []
    l, h = lo, ho
    while l > 1 or h > 1:
        l, h = max(1, l // 2), max(1, h // 2)
        mips.append((l, h, plein.resize((l, h), Image.LANCZOS).convert("RGBA").tobytes()))

    os.makedirs(dossier, exist_ok=True)
    base = os.path.join(dossier, sortie_nom)
    with io.open(base + ".blp", "wb") as f:
        f.write(blp.encoder(lo, ho, sortie.tobytes(), mips))
    sortie.save(base + ".png")
    print("   %-30s %d x %d -> %d x %d + %d mipmaps, motif %.1f texels" % (
        nom, largeur, hauteur, lo, ho, len(mips), l2))


def main():
    chaine = mpq.open_client(CLIENT, "enUS", ignore=(ARCHIVE_DU_PROJET,))
    print("facteur %d / %d = %.4f" % (CARTE_CLIENT, CARTE_CAMELOT, FACTEUR))
    try:
        for nom, dossier, sortie_nom in FLECHES:
            reduire(nom, chaine, dossier, sortie_nom)
    finally:
        chaine.close()


if __name__ == "__main__":
    main()
