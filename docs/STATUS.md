# Where things stand

What the module must do to be installed by someone whose only line to its
author is an issue on GitHub; what of that is done, what is done but not yet
seen in a game, and what is still missing. Kept with the module, and meant to
be edited as points close.

**Done** was verified on this machine. **To verify** is done on paper and never
observed in play. **Missing** is missing.

## The requirements

1. Installs on any AzerothCore 3.3.5a server by someone who only has GitHub.
2. The repository is the module: `git clone` into `modules/mod-spheregrid`.
3. Ships everything it needs — sources, SQL, Lua, DBC, art, sounds — and
   depends on no particular client or server.
4. Writes DBC rows without clashing: surveys the server, its database and the
   client; moves its own identifiers when one is taken.
5. Rewrites no row of the game, in a DBC or in SQL.
6. A guided installer: survey, backup with a choice, place, SQL, client patch;
   safe to run again; undone by an uninstaller.
7. English throughout, no trace of the server it grew up in, tables named
   `mod_spheregrid_*`, settings in `mod-spheregrid.conf`.
8. The spells behave as they did on the original server.
9. Dependencies stated, licence, README, versions.

## Done

- Repository = module; GPL-2.0-or-later; README; `.gitignore`; first commit
  and `CHANGELOG.md`.
- Lua, C++, SQL, art file names: English; no origin name in any shipped file.
  The author's own rename maps live in `tools/local/`, ignored by git.
- Tables `mod_spheregrid_*`; settings in the conf; the Lua reads the shipped
  schema and the conf (20 keys, fallbacks equal to the C++'s), replayed
  against an installed database.
- 13 DBC files, 322 art files; every skin, texture, model and icon the rows
  name is served by a stock client plus the module's archive.
- Server side: 621 spells in `spell_dbc`, creature displays and models in the
  `*_dbc` tables — the two gaps the start-up log revealed.
- The collector reads the identifiers the C++ names (kits it plays, shapes it
  morphs into, emotes), collects `Emotes.dbc` and `GameObjectDisplayInfo.dbc`,
  carries its own corrections (Shunpo's range), and COPIES every altered row of
  the game the module reached — 54 visuals, 12 kits, 3 effects, the gate's
  display — under identifiers of the module's own, repointing the module's rows
  and the SQL (`data/dbc/borrowed.json`).
- Installer: `install.bat` and `install.sh`; survey of DBC files, world tables
  and client archives, telling the module's own earlier rows from a clash;
  `--shift` moves a family in clash and surveys again; refuses to write over a
  `patch-Z` that is not the module's (a mark inside the archive says which);
  says whether AIO was found; safe to run twice. Full cycle place / analyse /
  revert at 0 differences on 27 tables and every watched file.
- `tools/uninstall.py`: the module's own DELETEs replayed in reverse, its
  tables dropped, characters kept or dropped on request, files and archive
  removed.
- `tools/shift.py`: a family moved everywhere at once; verified on a copy of the
  module (spells +200 000, items +600): 0 numbers left in the old ranges, SQL
  intact, C++ compiles.
- Corrections found in play: Shunpo 30 m, Meteor 8600056, Spartan Shield's
  message removed, `spell_bonus_data` labels, the transparent texture rebuilt
  as DXT5 with mipmaps, the gate's display copied to 802100.

## To verify

- **In play, after a rebuild**: Heroic Leap's flight and impact, Ascendance's
  three shapes, Arcane Orb's impact, Death Tunnel's portal, Light of Dawn,
  Ray of Frost, Shunpo, Meteor — corrected on paper, never watched.
- **Divine Steed** reported at +150 %: the module declares +100 % on both
  sides. The tooltip says which of the two is wrong.
- **Never tried**: buying, socketing, the pin, the reset, the workbench, the
  editor — and the rank runes, inert until the server-side spells shipped.
- A clean start-up log: no `spell_ranks` orphan, no unknown display.
- The 27 spells the new collection added (594 → 621): trigger targets of the
  module's own spells, presumably.
- `spell_ranks` rewrites 18 of the game's own rank chains (Divine Shield,
  Whirlwind...): the one place the module touches the game's rows in SQL.
  Acceptable, or to be reserved?
- `--shift` end to end on a server where something IS taken: the tool is
  proven on a copy, the installer's choice of offset is not yet exercised
  against a real clash.
- The C++ is compiled by the operator; the module's own check is syntactic.
- `install.sh` on an actual Linux server (written POSIX, run only under
  Git Bash on Windows).

## Missing

- The kits family (30 000–30 299) is moved by position only; a clash there on
  a server whose other modules use those numbers is detected but the shift
  covers only the fields and constants it knows.
- `05_spells.sql` leaves the 16th locale slot empty where the DBC fills it:
  harmless, and the last divergence between the module's two faces.
- Icons the module names that a stock client lacks: two, both the game's own
  gaps (`Ability_Druid_Mangle.tga`, `DEATHWINGCORRUPTED02`).
