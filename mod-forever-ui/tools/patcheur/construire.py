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

"""Compiler le patcheur ForeverUI avec le compilateur C# de Windows.

Le compilateur de .NET Framework 4 (csc.exe) est livre avec Windows : aucun
Visual Studio n'est necessaire, et l'executable produit tourne sur tout
Windows 10 ou 11 sans installation.

CE QU'IL ECRIT. tools/patcheur/bin/ForeverUIPatcher.exe
"""
import os
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
CSC = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Microsoft.NET", "Framework", "v4.0.30319", "csc.exe")
SORTIE = os.path.join(ICI, "bin", "ForeverUIPatcher.exe")


def main():
    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    commande = [CSC, "/nologo", "/target:winexe", "/platform:anycpu", "/optimize+", "/codepage:65001",
                "/r:System.Windows.Forms.dll", "/r:System.Drawing.dll",
                "/out:" + SORTIE, os.path.join(ICI, "ForeverUIPatcher.cs")]
    r = subprocess.run(commande, capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode != 0:
        raise SystemExit("echec de la compilation (%d)" % r.returncode)
    print("patcheur : %s (%d octets)" % (os.path.relpath(SORTIE, os.path.dirname(os.path.dirname(ICI))), os.path.getsize(SORTIE)))


if __name__ == "__main__":
    main()
