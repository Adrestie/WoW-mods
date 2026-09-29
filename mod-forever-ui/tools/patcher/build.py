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

"""Builds the ForeverUI patcher with the Windows C# compiler.

The .NET Framework 4 compiler (csc.exe) ships with Windows: no Visual Studio is needed,
and the executable runs on any Windows 10 or 11 without installation.

Output: tools/patcher/ForeverUIPatcher.exe, beside its source.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CSC = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Microsoft.NET", "Framework", "v4.0.30319", "csc.exe")
OUTPUT = os.path.join(HERE, "ForeverUIPatcher.exe")


def main():
    command = [CSC, "/nologo", "/target:winexe", "/platform:anycpu", "/optimize+", "/codepage:65001",
                "/r:System.Windows.Forms.dll", "/r:System.Drawing.dll",
                "/out:" + OUTPUT, os.path.join(HERE, "ForeverUIPatcher.cs")]
    r = subprocess.run(command, capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode != 0:
        raise SystemExit("echec de la compilation (%d)" % r.returncode)
    print("patcheur : %s (%d octets)" % (os.path.relpath(OUTPUT, os.path.dirname(os.path.dirname(HERE))), os.path.getsize(OUTPUT)))


if __name__ == "__main__":
    main()
