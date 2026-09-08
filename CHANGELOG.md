# Changelog

The version is the first word of the newest heading; the installer writes it
into the mark it leaves in the client's archive.

## 0.1.0

The module as it leaves the server it was written for.

- A shared grid of 2 451 cells and 2 493 links, one entry per class; Spherite
  awarded by quests, levels, achievements, dungeons and raids; stones, rank
  runes and statistic runes; the workbench; 41 class spells with their own
  visuals, sounds and scripts.
- The interface — player window, layout editor, workbench — in Lua over AIO.
- Everything an operator tunes in `mod-spheregrid.conf`.
- An installer for Windows and POSIX that surveys, backs up, places, applies
  the SQL, patches the client into a new `patch-Z.MPQ`, moves the module's
  identifiers on request when one is taken, and can be run again; an
  uninstaller; a tool that shifts a family of identifiers everywhere at once.
- Thirteen DBC files holding only the module's rows, with copies of the
  game's rows it depends on under identifiers of its own; 322 art files.
