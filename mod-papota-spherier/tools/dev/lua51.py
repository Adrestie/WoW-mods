# -*- coding: utf-8 -*-
r"""Exécute un fichier Lua avec le Lua 5.1 embarqué de lupa (celui du client WoW).

    python lua51.py <fichier.lua> [répertoire de travail] [args...]

Le répertoire de travail est celui que les bancs d'essai attendent (le
bin\RelWithDebInfo du serveur, d'où « lua_scripts/… » se résout). Les
arguments restants sont exposés au script dans la table globale `arg`.
"""
import os
import sys

import lupa.lua51 as L

sys.stdout.reconfigure(encoding="utf-8")
fichier = os.path.abspath(sys.argv[1])
if len(sys.argv) > 2:
    os.chdir(sys.argv[2])
lua = L.LuaRuntime(unpack_returned_tuples=True, encoding="utf-8")
lua.globals().arg = lua.table(*sys.argv[3:])
with open(fichier, encoding="utf-8") as f:
    code = f.read()
lua.execute(code, fichier)
