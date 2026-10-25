# Identifier ranges

Every WoW-mods module takes its identifiers from one window,
**81000-99999**, cut into blocks of a hundred. A module gets as many blocks
as it needs, side by side, and keeps all its identifiers in them, in every
space at once: items, spells, creatures, quests, texts, reference loot, and
every DBC file (item and creature displays, spell icons, visuals, kits, effect
names, model attachments, sounds, durations, skill lines...). The same number
may therefore be an item and a spell of the same module.

The window sits just above the game's highest numbers (spells 80864, items
56806, item displays 68742, broadcast texts 77865), and stays low on purpose:
the core and the client size their DBC stores by the highest identifier they
hold, so a spell numbered in the millions costs tens of megabytes of memory.

Two exceptions, for database tables where the game already uses the window.
The core keeps these in maps, so a larger number costs nothing. For a module
holding A-B:

| Space | Numbers | Block 94000-94099, for instance |
|---|---|---|
| gameobject templates, gossip menus, pools | A × 10 to B × 10 + 9 | 940000-940999 |
| creature and gameobject spawns (guid) | A × 100 to B × 100 + 99 | 9400000-9409999 |

One more exception, the other way, for the spaces the game holds in 16 bits
(at most 65535): they take the module's numbers **minus 60000**, so the window
81000-99999 becomes 21000-39999, above the game's own (talents up to 2285).

| Space | Numbers | Block 94000-94099, for instance |
|---|---|---|
| `Talent.dbc` rows, `GlyphProperties.dbc` rows | A − 60000 to B − 60000 | 34000-34099 |

Why: the core keeps a talent's row ID in 16 bits (azerothcore
`DBCStructure.h:2272`, `TalentSpellPos::talent_id` is a `uint16`): a talent
numbered 81140 is looked up as 15604, finds no row, and is never kept
(`Player::addTalent`), though the player was told it was learned and paid its
points. A glyph's `GlyphProperties` ID goes in 16 bits to the client
(`SMSG_TALENTS_INFO`) and to the database (`character_glyphs.glyph1-6`,
`smallint unsigned`). Talent tabs (`TalentTab.dbc`) stay in the window: the
core holds them in 32 bits.

A module's cleanup clauses (`DELETE ... BETWEEN`, the installer's `where`)
stop at the end of its own blocks, never at the end of a thousand: past that
end lie another module's rows.

Game files go in folders of the module's own (`Interface\<Module>\...`); a
file that has to sit in a shared folder, such as `Spells\`, carries a prefix
of the module in its name.

Not concerned: `module_string` (keyed by the module's name), a module's own
tables (`mod_<module>_*`), and the SQL file names (prefixed by the module).

## Blocks

| Numbers | Owner |
|---|---|
| 81000-81099 | shared components: the workbench (gameobject 810000) |
| 81100-81999 | mod-custom-classes (the Monk: spells and DBC rows; full, continued in 82200-82699) |
| 82000-82099 | mod-attriboost |
| 82100-82199 | UniWoW editor (quests created in the editor, mod-uniwow-content) |
| 82200-82699 | mod-custom-classes (the Monk, continued: spells 82200-82646, creatures 82200-82205) |
| 83000-83099 | mod-item-upgrade |
| 84000-84999 | mod-artifact-weapons |
| 85000-86999 | mod-spheregrid |
| 87000-88999 | mod-stellar-tarot |
| 89000-89999 | mod-stellar-tarot (levels of cards 198 and up) |
| 90000-90299 | mod-limit-break |
| 91000-91099 | mod-companion-mount (creature 91000) |
| 92000-94599 | mod-guild-level |
| 94600-94699 | mod-dungeon-quests (creature 94600) |
| 95000-95099 | mod-find-resources (spells 95000-95001, quests 95000-95002) |
| 96000-96399 | mod-wow-fates (spells 96000-96004, creatures 96100-96300, gameobjects 960000-960100) |
| 97000-97099 | mod-transmog-retail (creature 97000, npc_text 97000) |
| 98000-98299 | mod-arac (CharStartOutfit and SkillRaceClassInfo rows) |
| 99000-99599 | mod-custom-classes (CharStartOutfit rows: 99000 + class × 32 + race × 2 + sex) |

Every other block of the window is free: a new module takes the first free
blocks it needs and adds its line here.

mod-forever-ui is not in the window: the statistics it adds keep the numbers
of the client they come from (Achievement 6137-64300, Achievement_Criteria
64301-64321), above the game's own.

mod-custom-classes has rows outside the window too: `SkillLine.dbc` 800-803
(the class's skill lines) and `AnimationData.dbc` 660-774 (the animation
numbers of the Mists of Pandaria models it uses, which the models expect as
they are). In 16 bits (see above), its talents and glyphs take 21100-21999 and
22200-22699 (talents 21100-21177 and glyphs 21100-21122 today).

mod-arac has a second exception, for `SkillLineAbility.dbc` only: from
100000 up. It copies there the rows a class mod widens (one copy per row,
holding only the added classes: 1046 for mod-custom-classes), more than a
block holds.
