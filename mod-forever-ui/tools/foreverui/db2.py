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

"""Lecteur minimal des tables .db2 du client moderne (format WDC5).

Rend, pour chaque ligne, son identifiant et la liste brute de ses champs ;
un champ texte rend sa chaine. Formats de stockage geres : brut, compacte,
compacte signe, donnee commune, palette, palette en tableau. Les tables
chiffrees ou eparses (drapeau 1) ne sont pas gerees.
"""
import io
import struct


def _bits(donnees, debut_octets, decalage_bits, nombre_bits):
    octet = debut_octets + decalage_bits // 8
    n = (decalage_bits % 8 + nombre_bits + 7) // 8
    brut = int.from_bytes(donnees[octet:octet + n], "little")
    return (brut >> (decalage_bits % 8)) & ((1 << nombre_bits) - 1)


def lire(chemin, champs_texte=()):
    d = io.open(chemin, "rb").read()
    if d[:4] != b"WDC5":
        raise ValueError("pas un WDC5 : %s" % chemin)
    o = 4 + 4 + 128
    (nb, nb_champs, taille_ligne, taille_textes, _, _, _, _, _) = struct.unpack_from("<9I", d, o)
    o += 36
    drapeaux, index_id = struct.unpack_from("<HH", d, o)
    o += 4
    (total_champs, _, _, taille_stockage, taille_communs, taille_palette, nb_sections) = struct.unpack_from("<7I", d, o)
    o += 28
    if drapeaux & 1:
        raise ValueError("table eparse non geree")
    sections = []
    for _ in range(nb_sections):
        sections.append(struct.unpack_from("<QIIIIIIII", d, o))
        o += 40
    o += 4 * nb_champs
    stockage = [struct.unpack_from("<HHIIIII", d, o + 24 * i) for i in range(total_champs)]
    o += taille_stockage
    palette = d[o:o + taille_palette]
    o += taille_palette
    communs_brut = d[o:o + taille_communs]
    o += taille_communs

    # decoupe palette et donnees communes champ par champ
    pal, com = [], []
    p = c = 0
    for (_, _, extra, genre, v1, v2, v3) in stockage:
        if genre in (3, 4):
            pal.append(p)
            p += extra
        else:
            pal.append(None)
        if genre == 2:
            table = {}
            for k in range(extra // 8):
                ident, val = struct.unpack_from("<II", communs_brut, c + 8 * k)
                table[ident] = val
            com.append(table)
            c += extra
        else:
            com.append(None)

    lignes = []
    for (_, debut, n, _, _, taille_ids, _, _, nb_copies) in sections:
        ids = []
        fin_lignes = debut + n * taille_ligne
        fin_textes = fin_lignes + taille_textes
        if taille_ids:
            ids = list(struct.unpack_from("<%dI" % (taille_ids // 4), d, fin_textes))
        copies_debut = fin_textes + taille_ids
        for i in range(n):
            base = debut + i * taille_ligne
            valeurs = []
            for k, (bits, nbits, extra, genre, v1, v2, v3) in enumerate(stockage):
                if genre == 0:
                    octet = bits // 8
                    v = int.from_bytes(d[base + octet: base + octet + nbits // 8], "little")
                    if k in champs_texte:
                        pos = base + octet + v
                        v = d[pos:d.index(b"\x00", pos)].decode("utf-8", "replace")
                elif genre in (1, 5):
                    v = _bits(d, base, bits, nbits)
                    if genre == 5 and v & (1 << (nbits - 1)):
                        v -= 1 << nbits
                elif genre == 2:
                    v = None  # rempli apres, par identifiant
                elif genre == 3:
                    idx = _bits(d, base, bits, nbits)
                    v = struct.unpack_from("<I", palette, pal[k] + 4 * idx)[0]
                elif genre == 4:
                    idx = _bits(d, base, bits, nbits)
                    v = list(struct.unpack_from("<%dI" % v3, palette, pal[k] + 4 * idx * v3))
                else:
                    raise ValueError("stockage %d non gere" % genre)
                valeurs.append(v)
            ident = ids[i] if ids else valeurs[index_id]
            for k, (bits, nbits, extra, genre, v1, v2, v3) in enumerate(stockage):
                if genre == 2:
                    valeurs[k] = com[k].get(ident, v1)
            lignes.append((ident, valeurs))
        # copies : (nouvel id, id copie)
        par_id = dict(lignes)
        for j in range(nb_copies):
            nouveau, ancien = struct.unpack_from("<II", d, copies_debut + 8 * j)
            if ancien in par_id:
                lignes.append((nouveau, list(par_id[ancien])))
    return lignes
