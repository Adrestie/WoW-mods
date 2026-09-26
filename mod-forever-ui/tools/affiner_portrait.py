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

"""Le portrait de la fenetre Social, affine pour 3.3.5.

POURQUOI. Battlenet-Portrait n'existe qu'en 64 x 64 dans le client moderne,
compresse en DXT5 et SANS MIPMAP. Pose en 60 x 60 unites d'interface, il est
agrandi sur un ecran de haute resolution : les blocs 4 x 4 du DXT et
l'echantillonnage d'une petite image s'y voient -- l'icone parait pixelisee
(constate en jeu le 2026-09-26). Meme lecon que les fleches de la minimap
(tools/reduire_fleches.py).

CE QU'IL FAIT. Il decode le BLP verse par ajouter_feuilles.py, l'agrandit
une fois pour toutes en 128 x 128 (Lanczos, en alpha premultiplie : le bord
transparent ne bave pas dans le disque noir), et l'ecrit NON COMPRESSE
(BGRA) avec sa chaine de mipmaps jusqu'a 1 x 1 : le client le REDUIT au lieu
de l'agrandir, sans artefact de compression.

Il ecrit battlenet-portrait-hd a cote de l'original, qui reste tel que le
client moderne le donne (ajouter_feuilles.py le reecrirait sinon).
"""
import io
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foreverui import blp  # noqa: E402

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOSSIER = os.path.join(RACINE, "data", "art", "interface", "ForeverUI", "friendsframe")
SOURCE = os.path.join(DOSSIER, "battlenet-portrait.blp")
SORTIE = os.path.join(DOSSIER, "battlenet-portrait-hd")
COTE = 128


def main():
    with io.open(SOURCE, "rb") as f:
        largeur, hauteur, rgba, _ = blp.decoder(f.read())
    image = Image.frombytes("RGBA", (largeur, hauteur), bytes(rgba)).convert("RGBa")
    plein = image.resize((COTE, COTE), Image.LANCZOS)
    mips = []
    cote = COTE
    while cote > 1:
        cote //= 2
        mips.append((cote, cote, plein.resize((cote, cote), Image.LANCZOS).convert("RGBA").tobytes()))
    sortie = plein.convert("RGBA")
    with io.open(SORTIE + ".blp", "wb") as f:
        f.write(blp.encoder(COTE, COTE, sortie.tobytes(), mips))
    sortie.save(SORTIE + ".png")
    print("battlenet-portrait : %d x %d -> %d x %d + %d mipmaps, non compresse" % (
        largeur, hauteur, COTE, COTE, len(mips)))


if __name__ == "__main__":
    main()
