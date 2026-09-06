# -*- coding: utf-8 -*-
r"""Répare la table texUnitLookup des M2 rétroportés — la cause de l'erreur 132.

Un lot de rendu (batch, dans le .skin) dit combien de textures il pose et à
partir de quel index de la table texUnitLookup du M2 il lit ses unités. Sur les
modèles rétroportés de la Lumière de l'aube, cette table est VIDE alors que des
lots réclament une à deux entrées : le client de 3.3.5 déréférence alors une
table à l'adresse nulle — ACCESS_VIOLATION « referenced memory at 0x00000000 »,
l'erreur 132 constatée au lancer du sort.

Les imports qui fonctionnent montrent la forme attendue : une entrée par unité,
valant son propre rang — [0] pour un lot à une texture, [0, 1] pour deux.

La réparation APPEND la table en fin de fichier et pointe l'en-tête dessus :
rien d'existant ne bouge, et l'outil est idempotent — une table déjà suffisante
est laissée telle quelle.

    python repare_m2_texunit.py     (JEU FERMÉ requis : écrit dans patch-z)
"""
import ctypes as C
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_visuel_aube as V

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)

MODELES = [
    "cfx_paladin_lightofdawn_cone_castworld",
    "cfx_paladin_lightofdawn_heal_impact",
    "paladin_lightofdawn_coneimpact_01",
    "paladin_lightofdawn_impact_01",
    "paladin_lightofdawn_impact_base_v2",
    "paladin_lightofdawn_impact_base_v2_low",
]


def main():
    dll = V.stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(V.G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        for m in MODELES:
            m2 = bytearray(V.lit(dll, h, "spells" + BS + m + ".m2"))
            sk = V.lit(dll, h, "spells" + BS + m + "00.skin")

            # Ce que les lots exigent : l'index d'unité le plus haut, plus un.
            nb, ob = struct.unpack_from("<2I", sk, 4 + 32)
            besoin = 0
            for i in range(nb):
                v = struct.unpack_from("<Bb11H", sk, ob + i * 24)
                ntex, coord = v[8], v[10]
                besoin = max(besoin, coord + ntex)

            ntu = struct.unpack_from("<I", m2, 0x88)[0]
            if besoin <= ntu:
                print("%-46s table %d, requis %d : rien à faire" % (m, ntu, besoin))
                continue

            # La table s'ajoute en fin de fichier — rien d'existant ne bouge —
            # et vaut [0, 1, ...] : chaque unité lit son propre jeu de
            # coordonnées, la forme relevée sur les imports qui fonctionnent.
            ofs = len(m2)
            m2.extend(struct.pack("<%dh" % besoin, *range(besoin)))
            struct.pack_into("<2I", m2, 0x88, besoin, ofs)
            V.ecrit(dll, h, "spells" + BS + m + ".m2", bytes(m2))
            print("%-46s table de %d entrée(s) ajoutée à 0x%X" % (m, besoin, ofs))
    finally:
        dll.SFileCloseArchive(h)


if __name__ == "__main__":
    main()
