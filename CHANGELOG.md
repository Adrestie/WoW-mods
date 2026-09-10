# Changelog

The version is the first word of the newest heading; the installer writes it
into the mark it leaves in the client's archive.

## 0.2.0 (unreleased)

- A client that already has a `patch-Z` of its own is written INTO, in place:
  the module's rows merged into the archive's DBC files, its art added, every
  replaced file copied aside first, a record inside the archive saying what is
  the module's. The next run takes the earlier rows out before merging; the
  uninstaller takes the module out and puts the client's files back.
- The survey reads the client's `patch-Z` like any other archive: what it
  holds can clash, and `--shift` moves the module off it.
- The spell icons are a family of their own, moved by position; the kits are
  now moved in `Spell.dbc` too, and in every `spell_dbc` INSERT by column name.
- Duplicated identifiers in a client's hand-edited DBC no longer stop the
  merge: the last row is kept, as the game does.
- The installer, run on a server that already has the module, says what it
  found and removes it instead of installing over it; `--presence` asks the
  question alone. The interactive installers switch menus accordingly.
- The tools' exit code says whether they succeeded.
- Removing the module now takes back the spells it TAUGHT. They live in the
  core's own tables -- `character_spell`, its cooldowns, its auras, the action
  bars -- not in the module's, so its SQL could not reach them; left behind,
  they named spells that no longer existed and the core said so at every
  login. What players earned is untouched, and a reinstall teaches the spells
  again at the next login, from the cells they still own.
- A TOOLTIP THAT NAMES ANOTHER SPELL now moves with it. Seven of the module's
  descriptions read a neighbour's figures -- `$8600097s1` its value,
  `$8600097d` its duration -- and a shift left every one of them pointing at a
  spell that no longer existed, so the client showed what it could make of
  them: "1 to 6%" for a value, "until cancelled" for a duration. A number
  after a `$` is a reference, and the shift moves it; the fourteen texts were
  put right.
- Angelic Feather, its speed buff and its reserve say their French. They held
  the English sentence in every locale.
- A CLIENT IS NO LONGER OPTIONAL. The module's spells exist in no client, so
  without its rows they have no name, no icon and no effect: the installer
  asks for one and goes on without it only when told to (`--no-client`),
  saying what it costs. And because a server rarely has a client on it,
  `--client-only` patches a client alone -- no server, no database.
- A shift is now all of it or none of it: everything is computed before
  anything is written, so a file that cannot be read leaves the module
  exactly as it was. Before, a failure half way left the DBC rows moved and
  the SQL, the C++ and the Lua saying the old numbers -- with nothing to say
  so.
- A shift by sight no longer reads past the end of a record: `SpellChainEffects`
  declares 48 fields in 177 bytes, five of them single bytes, and its last
  fields do not begin on a four-byte boundary.
- Writing into a client's archive grows its hash table when what is being
  added does not fit -- a patch of fifteen files has thirty-two slots. The
  table is rebuilt from the names its `(listfile)` declares; an archive whose
  listfile does not account for every file it holds is left alone, and says
  so.
- The sixteen statistic icons of the interface are named after the
  statistic's key (`stat_strength`), as the interface has asked for them
  since the translation; they were still shipped under their French names,
  and the window showed no icon.
- Spells, found in play: Meteor casts with the fire cast animation and sound
  (a visual of the module's own, the game's meteor with the classic fire
  kits); Divine Steed grants +150 %; the Arcane Orb wears the orb model
  instead of the druid's red star, on a display of its own; the Death Tunnel's
  gate model is shipped (it was named and missing); Light of Dawn's
  transparent texture is DXT5 with mipmaps (palettized without them, the
  client drew green squares); Ray of Frost's kit asked for a beam that existed
  nowhere -- a `SpellChainEffects` row is shipped, the fourteenth DBC file,
  with the frost beam texture. The collector reproduces every one of these
  (corrections, derived rows, extra files, and the one texture the module
  carries itself instead of taking it from a client: the transparent square,
  which every client kept palettized and without a mipmap chain -- which is
  what drew the green squares).
- Ascendance no longer lets the shaman cast while moving (that came from a
  patch to the core on the server the module was written for, and from the
  game's own rows rewritten in its client -- neither of which a module can
  ship). Instead, every Fire spell cast under Ascendance stacks +3 % critical
  strike chance and every Nature spell +3 % haste, until Ascendance ends; two
  spells of the module's own (8610038, 8610039), an `AllSpellScript` that
  watches the casts, tooltips rewritten in both languages.
- Angelic Feather's count stays on the priest and reads at both ends: three
  when none is missing, zero when none is left. The aura used to be removed at
  both, which took the number away exactly when it was worth reading; it is
  now placed at login and on learning -- placed, not cast: casting it meant
  reading it back, and a reading that came back empty left the count at the
  one a fresh aura carries. A login fills the reserve, whatever the database
  kept: a feather returns through an event posted on the player, and those do
  not outlive a session. The aura cannot be dismissed by a right click, and
  the module's own client code gives back the figure the game hides below
  two.
- The Arcane Orb's model at half its size.
- Shadow Word: Despair lays its shadow at the point aimed at, not on the
  priest. It is built exactly like the game's Shadowfury -- instant, its
  effects on whatever stands around the point -- and now wears its visual the
  same way: one kit on the caster for his gesture, one kit at the point for
  the shadow, named in the visual's instant-area slot. The module had a single
  kit, mixing both, in the slot that plays on the caster.
- Spell power raises spell damage only. The core's `ApplySpellPowerBonus`
  raises healing with it -- that is what the stat means on a piece of gear in
  Wrath -- and the grid has a healing bonus of its own to buy.
- Four creature displays of the module's had no `creature_model_info`: the
  core said so at every start, and those creatures had neither a bounding
  radius nor a combat reach.
- The druid's Moon and Sun bar drags with the mouse and remembers its place
  per character (AIO's saved positions).
- What every loot source drops is a setting: `SphereGrid.Loot.<source>`, one
  per kind of monster, vein, herb, skinning bracket and chest, written as
  `object:quantity:percent`, `,` for a fallback, `;` between independent
  rolls; the built-in tables are the defaults and the shipped values. On top
  of it, how often each object drops wherever it appears:
  `SphereGrid.Drop.Nexus.<name>`, `SphereGrid.Drop.Stone.<quality>`,
  `SphereGrid.Drop.Rune`, percentages; 0 turns an object off and hands its
  place to the fallback written after it.

- THE FRENCH WAS IN THE WRONG SLOT. A text block of 3.3.5 holds sixteen
  slots and Britain has none of its own -- it shares the United States'. The
  real order is 0 enUS, 1 koKR, 2 frFR, 3 deDE, and the columns of
  AzerothCore's `spell_dbc` name one more, `_Lang_enGB` at 1, sliding by one
  from there: the column that really holds the French is called `_Lang_koKR`.
  The module's own French was right all along, at slot 2; what had been
  retranslated since -- Angelic Feather, Ascendance and its two stacks -- had
  gone to the German. Twelve texts moved back, the German slot given the
  English again. Nine groups of rank spells carried a FRENCH name in the
  English slot, and their own text says which spells they are: Whirlwind,
  Mutilate twice, Stormstrike twice, Arcane Missiles, Hurricane, Mangle (Bear)
  and Mangle (Cat). Nothing French remains in an English slot.
- THE BUFF BAR CAME BACK. The module's own client file, the one that shows the
  feathers left, wrapped `AuraButton_Update` and swallowed what it returns.
  That value is not a courtesy: `BuffFrame_Update` counts the buffs with it,
  and places exactly as many buttons as it counted. The count stayed at zero
  and the whole bar went blank -- every buff of the game with it, which is why
  Roll the Bones, the celestial gauge and the Demonic Tyrant all looked as if
  they granted nothing. Their auras had been there all along.
- EVERY RESET NOW TAKES THE SPELLS BACK. Three paths empty a grid and only one
  of them unlearned what a spell cell had taught: the recomputation never
  removes anything, it only learns what the ACTIVE cells ask for, so a reset
  that merely emptied the state left the spells in the book for ever. The
  wiping of a whole account reaches its offline characters too, in the
  database, since nobody holds their state.
- SPELLS SIT IN THEIR CLASS TAB. The spell book does not read the class from
  `Spell.dbc`: it reads the SKILL LINE a spell is tied to, and a spell no line
  names falls into "General". The module ships that table now, a fifteenth DBC
  file: one row per spell it can teach, the ranks taking the line of their own
  base spell, the cells the tree written for each of them. Light Stride has no
  row at all, which is what puts it in "General".
- The heroic leap wears its dressing again: the table naming its kits was not
  moved by a shift, because the rule only read `constexpr uint32 NAME = n` and
  a braced table escaped it. A constant is now known by its NAME and
  everything it is given is read, tables included.
- Ray of Frost, one for one with the source. Its chain EXISTS there, with a
  texture of its own -- Jaina's glacial ray, which is not a texture of 3.3.5 --
  and the row is copied rather than rebuilt. Two attempts at inventing it,
  from Mind Flay's beam and from the game's chain 1, had both missed.
- Found in play: Halo takes a priest out of Shadowform, as a holy spell does;
  Heroic Leap, Sweeping Strikes and Kingsbane wear icons no ability of their
  class already uses; Spartan Shield asks for a shield, as Spell Reflection
  does; Shunpo no longer breaks stealth; Ascendance makes Lightning Bolt,
  Chain Lightning and Lava Burst instant, and its two stacks last twelve
  seconds of their own and outlive the ascendance that granted them; the death
  tunnel is a fifth smaller; Earthquake sits in Enhancement.
- A SHIFT REWRITES THE COPY, NEVER THE SOURCE. `--shift` used to move
  identifiers in the module's own files, where the installer was launched
  from: six thousand numbers rewritten in someone's checkout to suit the
  server in front of it, and a repository published afterwards carried
  another server's numbers. The module is copied into the core's `modules/`
  folder first -- which the installer already did, only later -- and the shift
  applies there. Everything after reads the copy: the interface, the
  configuration, the SQL, the rows written into the client. So does the
  removal, since the copy is what the database and the client were given.
- A value too wide for its column is said BEFORE the database is touched.
  MySQL stops on the first row it cannot take, in the middle of a file, and
  leaves the module half posed; AzerothCore does not give the same width to
  columns holding the same kind of text, so a text that fits everywhere else
  can still be refused.

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
