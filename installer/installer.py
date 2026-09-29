# -*- coding: utf-8 -*-
"""WoW-mods installer (MIT licence): installs a module, or removes it if it is present.

    installer.exe [module folder] [options]

The module folder is the one that holds its manifest, installer.json; without
it, the installer asks for it (the folder can also be dropped on
installer.exe). Built by build.cmd; also runs as is:
python installer\\installer.py [folder]."""
import core
import manifest

if __name__ == "__main__":
    core.main(manifest.load)
