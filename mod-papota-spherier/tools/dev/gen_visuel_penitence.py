# -*- coding: utf-8 -*-
r"""Le « hold » de l'Aura de pénitence (8240100) : les sceaux tournoyants.

L'aura de soin de Nairūn n'avait aucun visuel. Elle reçoit le modèle rétroporté
`paladin_empoweredseals_base01` en **StateKit** — le kit d'état, joué en boucle
tant que l'aura tient sur le porteur, ce que le jargon des kits appelle le hold.
Le modèle est un anneau au sol : il s'accroche à la base.

Même grammaire que gen_visuel_aube.py, dont on réutilise l'outillage : effet
nommé en 82002xx, kit et visuel en 300xx, chemin en .mdx. Aucun sort de ce
montage n'est généré par gen_sorts_classes : le champ SpellVisualID du sort se
patch directement, des deux côtés — le Spell.dbc du client, la table spell_dbc
du serveur.

    python gen_visuel_penitence.py     (JEU et MPQEditor FERMÉS)
"""
import os as _os_local, sys as _sys_local
_sys_local.path.insert(0, _os_local.path.dirname(_os_local.path.abspath(__file__)))
from config_local import MYSQL_HOTE, MYSQL_PORT, MYSQL_UTILISATEUR, MYSQL_MDP, BASE_WORLD  # ce qui décrit le poste, hors du dépôt
import ctypes as C
import os
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_visuel_aube as V

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)

SORT = 8240100
EFFET = 8200209
KIT = 30016
VISUEL = 30016
MODELE = "spells" + BS + "paladin_empoweredseals_base01.mdx"
MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"


def main():
    dll = V.stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(V.G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        prefixe = "DBFilesClient" + BS

        d = V.Dbc(V.lit(dll, h, prefixe + "SpellVisualEffectName.dbc"))
        d.retire({EFFET})
        d.pose([EFFET, d.chaine("Aura de penitence - sceaux"),
                d.chaine(MODELE), 1.0, 1.0, 0.01, 100.0])
        V.ecrit(dll, h, prefixe + "SpellVisualEffectName.dbc", d.octets())

        d = V.Dbc(V.lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT})
        # Un anneau au sol : la base, et aucune animation — l'aura est un état,
        # pas un geste.
        d.pose([KIT, -1, -1, 0, 0, EFFET] + [0] * 32)
        V.ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())

        d = V.Dbc(V.lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL})
        # Le cinquième champ est le StateKit : le hold, joué tant que dure l'aura.
        d.pose([VISUEL, 0, 0, 0, KIT] + [0] * 27)
        V.ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("chaîne posée : visuel %d -> kit %d (state) -> effet %d" % (VISUEL, KIT, EFFET))

        # --- le sort, côté client -------------------------------------------
        brut = bytearray(V.lit(dll, h, prefixe + "Spell.dbc"))
        magic, nrec, nfield, rsize, ssize = struct.unpack_from("<4s4I", brut, 0)
        for i in range(nrec):
            off = 20 + i * rsize
            if struct.unpack_from("<I", brut, off)[0] == SORT:
                struct.pack_into("<I", brut, off + 131 * 4, VISUEL)
                V.ecrit(dll, h, prefixe + "Spell.dbc", bytes(brut))
                print("Spell.dbc client : %d -> visuel %d" % (SORT, VISUEL))
                break
        else:
            raise SystemExit("sort %d absent du Spell.dbc client" % SORT)
    finally:
        dll.SFileCloseArchive(h)

    # --- le sort, côté serveur ---------------------------------------------
    r = subprocess.run([MYSQL, "-h" + MYSQL_HOTE, "-u" + MYSQL_UTILISATEUR, "-p" + MYSQL_MDP,
                        BASE_WORLD, "-e",
                        "UPDATE spell_dbc SET SpellVisualID_1 = %d WHERE ID = %d;"
                        % (VISUEL, SORT)], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit("MySQL : " + r.stderr.strip())
    print("spell_dbc serveur : %d -> visuel %d" % (SORT, VISUEL))


if __name__ == "__main__":
    main()
