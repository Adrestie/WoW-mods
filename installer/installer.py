# -*- coding: utf-8 -*-
"""WoW-mods installer (MIT licence): installs a module, or removes it if it is present.

    installer.exe [module folder]                     the window
    installer.exe module folder --status | --yes ...  the console, no questions

A module folder dropped on installer.exe opens the window on it. Built by
build.cmd; also runs as is: python installer\\installer.py [folder]."""
import sys

import core
import manifest


def console_output():
    """A windowed build starts without console: in console mode it writes into the console of the
    program that started it, if there is one; text piped to another program is written in UTF-8."""
    if sys.stdout is None:
        import ctypes
        if ctypes.windll.kernel32.AttachConsole(-1):          # the parent's console
            sys.stdout = sys.stderr = open("CONOUT$", "w", encoding="utf-8", errors="replace")
    elif not sys.stdout.isatty():
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")


if __name__ == "__main__":
    if "--status" in sys.argv or "--yes" in sys.argv:
        console_output()
    core.main(manifest.load)
