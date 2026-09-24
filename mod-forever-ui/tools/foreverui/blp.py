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

"""Lecture d'un BLP2 : palette, DXT1, DXT3, DXT5. Rend du RGBA brut.

POURQUOI. L'art du client 3.3.5 ne se juge pas de memoire. Ce module a ete
ecrit pour repondre a une question precise -- comment le client fait-il
tenir une icone carree dans un rond ? -- et la reponse est dans son art :
Interface/ContainerFrame/UI-Bag-4x4.blp porte un TROU CIRCULAIRE d'environ
32 px, et l'icone est simplement posee derriere. Aucun masque.

L'art d'interface du client est dans Data/enus/locale-enus.mpq, pas dans les
archives communes : mpq.open_client ne le voit pas, il faut ouvrir l'archive
de langue directement.

Il lit, et il sait ecrire une seule forme : BLP2 non compresse en BGRA
(encodage 3), sans mipmap -- exactement celle qu'ont les feuilles deja
versees dans le patch et que le client affiche sans broncher.

CE QUE LE CLIENT N'AFFICHE PAS. Une feuille de 2048 de large sort en bruit
(vu le 2026-09-22 sur uiactionbarfx et son anneau d'autolancement) : toutes
celles qu'il affiche correctement font 1024 au plus. D'ou l'encodeur, qui
permet de retailler un morceau de feuille en une petite image a part.
"""
import struct


def _dxt_couleurs(bloc):
    c0, c1 = struct.unpack_from("<HH", bloc, 0)

    def etendre(c):
        r = (c >> 11) & 0x1F
        v = (c >> 5) & 0x3F
        b = c & 0x1F
        return ((r * 255 + 15) // 31, (v * 255 + 31) // 63, (b * 255 + 15) // 31)

    a, b = etendre(c0), etendre(c1)
    if c0 > c1:
        c2 = tuple((2 * a[i] + b[i]) // 3 for i in range(3))
        c3 = tuple((a[i] + 2 * b[i]) // 3 for i in range(3))
        alphas = (255, 255, 255, 255)
    else:
        c2 = tuple((a[i] + b[i]) // 2 for i in range(3))
        c3 = (0, 0, 0)
        alphas = (255, 255, 255, 0)
    return (a, b, c2, c3), alphas, struct.unpack_from("<I", bloc, 4)[0]


def decoder(donnees):
    magic, type_, encodage, profAlpha, encAlpha, mips = struct.unpack_from("<4sIBBBB", donnees, 0)
    assert magic == b"BLP2", magic
    largeur, hauteur = struct.unpack_from("<II", donnees, 12)
    offsets = struct.unpack_from("<16I", donnees, 20)
    tailles = struct.unpack_from("<16I", donnees, 84)
    palette = struct.unpack_from("<256I", donnees, 148)
    debut, taille = offsets[0], tailles[0]
    brut = donnees[debut:debut + taille]
    px = bytearray(largeur * hauteur * 4)

    if encodage == 1:
        for i in range(largeur * hauteur):
            c = palette[brut[i]]
            px[i*4+0] = (c >> 16) & 0xFF      # la palette est en BGRA
            px[i*4+1] = (c >> 8) & 0xFF
            px[i*4+2] = c & 0xFF
            px[i*4+3] = 255
        if profAlpha == 8:
            base = largeur * hauteur
            for i in range(largeur * hauteur):
                px[i*4+3] = brut[base + i]
        elif profAlpha == 1:
            base = largeur * hauteur
            for i in range(largeur * hauteur):
                octet = brut[base + (i >> 3)]
                px[i*4+3] = 255 if (octet >> (i & 7)) & 1 else 0
    elif encodage == 2:
        dxt5 = (encAlpha == 7)
        dxt3 = (encAlpha == 1)
        pas = 16 if (dxt5 or dxt3) else 8
        n = 0
        for by in range(0, hauteur, 4):
            for bx in range(0, largeur, 4):
                bloc = brut[n:n+pas]
                n += pas
                if dxt5:
                    a0, a1 = bloc[0], bloc[1]
                    bits = int.from_bytes(bloc[2:8], "little")
                    if a0 > a1:
                        table = [a0, a1] + [((7-i)*a0 + i*a1)//7 for i in range(1, 7)]
                    else:
                        table = [a0, a1] + [((5-i)*a0 + i*a1)//5 for i in range(1, 5)] + [0, 255]
                    couleurs, _, indices = _dxt_couleurs(bloc[8:16])
                elif dxt3:
                    alphas4 = bloc[0:8]
                    couleurs, _, indices = _dxt_couleurs(bloc[8:16])
                else:
                    couleurs, alphasDXT1, indices = _dxt_couleurs(bloc[0:8])
                for j in range(16):
                    x, y = bx + (j % 4), by + (j // 4)
                    if x >= largeur or y >= hauteur:
                        continue
                    idx = (indices >> (2 * j)) & 3
                    r, v, b = couleurs[idx]
                    if dxt5:
                        a = table[(bits >> (3 * j)) & 7]
                    elif dxt3:
                        o = alphas4[j // 2]
                        a = ((o & 0x0F) if j % 2 == 0 else (o >> 4)) * 17
                    else:
                        a = alphasDXT1[idx] if idx == 3 else 255
                    p = (y * largeur + x) * 4
                    px[p], px[p+1], px[p+2], px[p+3] = r, v, b, a
    elif encodage == 3:
        for i in range(largeur * hauteur):
            b, v, r, a = brut[i*4:i*4+4]
            px[i*4:i*4+4] = bytes((r, v, b, a))
    else:
        raise ValueError("encodage %d inconnu" % encodage)

    return largeur, hauteur, bytes(px), dict(encodage=encodage, profAlpha=profAlpha,
                                             encAlpha=encAlpha, mips=mips)


# L'en-tete BLP2 fait 148 octets, suivis de 1024 octets de palette -- presents
# meme en BGRA, ou ils ne servent pas. Les donnees commencent donc a 1172.
DEBUT_DONNEES = 148 + 1024


def _bgra(largeur, hauteur, rgba):
    assert len(rgba) == largeur * hauteur * 4, "taille d'image incoherente"
    corps = bytearray(largeur * hauteur * 4)
    for i in range(largeur * hauteur):
        r, v, b, a = rgba[i*4:i*4+4]
        corps[i*4:i*4+4] = bytes((b, v, r, a))
    return bytes(corps)


def encoder(largeur, hauteur, rgba, mipmaps=None):
    """Ecrit un BLP2 non compresse en BGRA.

    rgba : une suite d'octets R, V, B, A, ligne par ligne depuis le haut.
    mipmaps : les niveaux reduits, du plus grand au plus petit, chacun en
    (largeur, hauteur, rgba) -- au plus 15. Sans eux, le fichier n'a que son
    image pleine, comme avant. Une image que le client affiche plus petite
    que sa taille en a besoin : les fleches de la minimap d'origine en
    portent six niveaux.
    """
    niveaux = [(largeur, hauteur, rgba)] + list(mipmaps or [])
    assert len(niveaux) <= 16, "un BLP2 porte au plus 16 niveaux"

    entete = bytearray(DEBUT_DONNEES)
    entete[0:4] = b"BLP2"
    struct.pack_into("<I", entete, 4, 1)            # type : non compresse
    entete[8] = 3                                   # encodage : BGRA
    entete[9] = 8                                   # profondeur d'alpha
    entete[10] = 8                                  # encodage d'alpha
    entete[11] = 1 if mipmaps else 0                # mipmaps presents
    struct.pack_into("<II", entete, 12, largeur, hauteur)

    corps = bytearray()
    for i, (l, h, pixels) in enumerate(niveaux):
        donnees = _bgra(l, h, pixels)
        struct.pack_into("<I", entete, 20 + 4 * i, DEBUT_DONNEES + len(corps))  # mipOffsets[i]
        struct.pack_into("<I", entete, 84 + 4 * i, len(donnees))               # mipSizes[i]
        corps += donnees
    return bytes(entete) + bytes(corps)
