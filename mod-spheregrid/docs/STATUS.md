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
- 14 DBC files (58 visual kits since Despair's ground kit), 372 art files; every skin, texture, model and icon the rows
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
  `--shift` moves a family in clash and surveys again; says whether AIO was
  found; safe to run twice. Full cycle place / analyse / revert at 0
  differences on 27 tables and every watched file.
- A client that already has a `patch-Z` of its own: the module is written INTO
  it, in place (`mpq.patch_archive`: data appended, tables rewritten, nothing
  moved), each replaced file copied aside first, a record inside the archive
  saying what is the module's. Verified against a 3.6 GB server patch that
  held the module's whole ranges: survey finds 1 227 taken, `--shift` moves
  eight families (icons included), the archive goes 3 635 → 3 681 MB, StormLib
  reads it back with the same bytes as the module's own reader, 4 000
  untouched files byte-identical to the original; a second run takes the
  earlier rows out first; the uninstaller leaves every one of the thirteen DBC
  files row-identical to the original, the 203 art files it had written over
  byte-identical, the 121 it had added gone, and the archive unmarked.
- The interface's statistic icons: found in play by the author (no icon
  shown), the files were still `rond_<french>.blp` while the interface asks
  `stat_<key>`; renamed. To verify in play after a reinstall.
- Angelic Feather's charge count (2026-09-09): the reserve aura is kept at
  0..3 instead of being removed at both ends, applied at login, marked
  uncancellable, and `Feather_Client.lua` wraps the game's own
  `AuraButton_Update` so the figure shows at one and zero. TO VERIFY IN PLAY:
  three feathers shown on login, the number falling to zero and climbing back,
  and the buff refusing a right click.
- Spell fixes of 2026-09-09 (see CHANGELOG), all TO VERIFY IN PLAY after a
  reinstall: Meteor's cast animation and sound (kits 30/38 on visual 30154);
  Divine Steed +150 %; the Arcane Orb's model (display 802158); the Death
  Tunnel's gate (11fx_phaseportal01 shipped); Light of Dawn without green
  squares; Ray of Frost's beam (SpellChainEffects 2001 -- the number the
  kit's CharParamZero holds -- derived from Mind Flay's straight beam with
  the frost texture and a width of 0.5); the Moon/Sun bar dragging and
  remembering.
  Verified offline: every skin and texture the two new models name is
  shipped or in the stock client; the collector's dry run reproduces every
  correction, derived row and shipped file.
- Validated in play by the author on 2026-09-09: Death Tunnel, Meteor,
  Divine Steed, Light of Dawn, the Moon/Sun bar, the grid's icons. Then
  changed and TO VERIFY again: Ray of Frost's beam at full intensity. It was
  drawn dark and see-through because the row it was derived from, Mind Flay's,
  carries an alpha of 51 out of 255 -- the beam was painted at a fifth of
  itself; it is 255 and white now, still blended additively, which is what a
  texture with a bright core and black edges is drawn with. The texture is
  the source's own, untouched. Validated on
  the same day, second pass: the Arcane Orb at half size (display 802158,
  scale 0.5); the beam under 2001 shows; Ascendance's two stacks
  (8610038 Fire: +3 % critical strike per stack; 8610039 Nature: +3 % haste
  per stack; fed by the shaman's own casts, triggered casts excluded; removed
  with Ascendance) and its rewritten tooltips. Casting while moving was
  dropped by the author's decision: on the server the module came from it
  was a core patch plus the game's rows rewritten in the client, neither of
  which a module can ship.
- Loot per source in the configuration (`SphereGrid.Loot.<source>`, 45
  sources) with a grammar of its own, and per-object factors on top
  (`SphereGrid.Drop.*`). The grammar is compiled on its own and tried against
  every default (each reads back as itself) and the mistakes it must refuse;
  the C++ compiles. NOT yet seen in play -- to verify: a changed source drops
  what it says, an unreadable one is reported at start-up and falls back,
  a Nexus at 0 never drops and its fallback takes over, `.spheregrid reload`
  picks up a change.
- `--shift` exercised END TO END against a client that holds every one of the
  module's identifiers (a fixture: the reference client's DBC files with the
  module's rows added at its own numbers, and for five families one block
  further as well). The survey found 1 303 taken; the nine families moved --
  spells +400 000, items +1 200, displays +400, kits +600, icons/effects/
  sounds +200, durations/chains +100 -- the survey then found everything
  free, and the module's two faces agree: 623 spells in the DBC and in the
  SQL, the display SQL equal to the display DBC, 257 items with no orphan,
  no old number left in the C++, the Lua or the XML. Three defects were found
  and fixed in the doing (see the changelog): the unaligned table, the shift
  that was not atomic, and the hash table that could not grow.
- The removal takes the module's spells out of `character_spell`,
  `character_spell_cooldown`, `character_aura` and the action bars: found in
  play by the author (`Player::addSpell: Non-existed in SpellStore spell
  #9000060`), fixed, and run against 42 rows left by an earlier removal --
  0 remain. Removing BEFORE renumbering stays the rule: the tool takes back
  what the module currently declares.
- The client half can be run on its own (`--client-only`), and a run without a
  client has to say so (`--no-client`): tried both ways, and `install.bat`
  driven with no client, which asks for a spoken yes before going on. That
  change first broke the removal menu -- the new question jumped over the
  presence check when a client WAS given -- found by the author and fixed;
  `install.bat` is now driven both ways at every change, with a client and
  without.
- The installer detects the module already there (sources, interface, config,
  world tables, client archive) and removes it instead; verified: install,
  `--presence` 3, plain run refuses without a characters flag, `--dry-run`
  removal, removal, `--presence` 0, from `install.py` and from `install.bat`.
- The `icons` family (SpellIcon 8 002–8 076), moved by position like the kits;
  the kits' positions in `Spell.dbc` and in every `spell_dbc` INSERT of the SQL,
  found by column name whatever the INSERT's shape.
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

## Decided, and waiting

- `tools/collect_client.py` and the author's `tools/local/origin.py` ARE ON
  THEIR WAY OUT. `data/` is the module: every fix since it became a module of
  its own was written there by hand, never collected. The collector has one
  purpose left -- bringing something new across from the server the module
  grew up in -- and the day nothing more is to come, it leaves the published
  repository, `origin.py` with it. Kept for now, and kept faithful: each
  hand-made row and file is named in its tables (7 derived rows, 6
  corrections, 3 extra files, 1 of the module's own) so that a collection
  reproduces what is shipped instead of undoing it.

## Missing

- The kits family (30 000–30 299) is moved by position only; a clash there on
  a server whose other modules use those numbers is detected but the shift
  covers only the fields and constants it knows.
- `05_spells.sql` leaves the 16th locale slot empty where the DBC fills it:
  harmless, and the last divergence between the module's two faces.
- Icons the module names that a stock client lacks: two, both the game's own
  gaps (`Ability_Druid_Mangle.tga`, `DEATHWINGCORRUPTED02`).
