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
#
# Les fonctions de lignes DBC reprennent celles de l'installeur commun du
# depot WoW-mods (mod-item-upgrade/installer/noyau.py, licence MIT) : ajouter
# ses lignes a la fin, les retirer seules, le reste intact.

"""Ajouter et retirer ses propres lignes d'un fichier DBC.

AJOUTER : les lignes du module sont d'abord retirees si elles y sont (leurs
textes avec), puis posees a la fin ; leurs textes vont a la fin du bloc de
chaines. Rejouable : un second ajout rend les memes octets.
RETIRER : seules les lignes du module partent ; le bloc de chaines est coupe
apres la derniere chaine qu'une ligne restante emploie. Rien a retirer : le
fichier rendu est l'original, octet pour octet.
"""
import struct


class Lignes(object):
    """Les lignes d'un module dans un DBC : nombre de champs, indices des champs
    texte, lignes (entiers ou textes ; un texte vide vaut 0)."""

    def __init__(self, champs, champs_texte, lignes):
        self.champs = champs
        self.champs_texte = list(champs_texte)
        self.lignes = [list(l) for l in lignes]
        self.ids = [l[0] for l in self.lignes]
        for l in self.lignes:
            if len(l) != champs:
                raise ValueError("ligne %s : %d champs au lieu de %d" % (l[0], len(l), champs))


def decouper(brut, nom):
    if brut[:4] != b"WDBC":
        raise ValueError("%s n'est pas un DBC (signature WDBC absente)" % nom)
    nb, champs, taille, taille_chaines = struct.unpack_from("<4I", brut, 4)
    if taille != champs * 4 or len(brut) < 20 + nb * taille + taille_chaines:
        raise ValueError("%s : en-tete DBC incoherent" % nom)
    lignes = [brut[20 + i * taille:20 + (i + 1) * taille] for i in range(nb)]
    debut = 20 + nb * taille
    return champs, lignes, bytearray(brut[debut:debut + taille_chaines])


def assembler(champs, lignes, chaines):
    return b"WDBC" + struct.pack("<4I", len(lignes), champs, champs * 4, len(chaines)) + \
        b"".join(lignes) + bytes(chaines)


def _id(ligne):
    return struct.unpack_from("<I", ligne)[0]


def compter(brut, nom, ids):
    ids = set(ids)
    return sum(1 for l in decouper(brut, nom)[1] if _id(l) in ids)


def ajouter(brut, nom, d):
    # d'abord le retrait complet, textes compris : sinon les anciens textes
    # restent dans le bloc, et chaque passage le ferait grossir -- ajouter
    # deux fois rend alors les memes octets
    brut, _ = retirer(brut, nom, d)
    champs, lignes, chaines = decouper(brut, nom)
    if champs != d.champs:
        raise ValueError("%s a %d champs, %d attendus : version de client inattendue" % (nom, champs, d.champs))
    for valeurs in d.lignes:
        rec = []
        for v in valeurs:
            if isinstance(v, str):
                if not v:
                    rec.append(0)
                    continue
                if not chaines:
                    chaines.extend(b"\0")          # l'offset 0 est la chaine vide
                rec.append(len(chaines))
                chaines.extend(v.encode("utf-8") + b"\0")
            else:
                rec.append(int(v) & 0xFFFFFFFF)
        lignes.append(struct.pack("<%dI" % champs, *rec))
    return assembler(champs, lignes, chaines)


def retirer(brut, nom, d):
    """(DBC sans les lignes du module, nombre retire)."""
    champs, lignes, chaines = decouper(brut, nom)
    ids = set(d.ids)
    garde = [l for l in lignes if _id(l) not in ids]
    n = len(lignes) - len(garde)
    if not n:
        return brut, 0
    if d.champs_texte and chaines:
        fin = 1
        for l in garde:
            valeurs = struct.unpack_from("<%dI" % champs, l)
            for c in d.champs_texte:
                off = valeurs[c]
                if 0 < off < len(chaines):
                    zero = chaines.find(b"\0", off)
                    fin = max(fin, (zero if zero >= 0 else len(chaines) - 1) + 1)
        chaines = chaines[:fin]
    return assembler(champs, garde, chaines), n
