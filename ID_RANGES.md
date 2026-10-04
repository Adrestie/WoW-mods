# Identifier ranges

Every WoW-mods module takes its identifiers from one window,
**81000-99999**, cut into tranches of a thousand. A module keeps all its
identifiers in its tranches, in every space at once: items, spells, creatures,
quests, texts, reference loot, and every DBC file (item and creature displays,
spell icons, visuals, kits, effect names, model attachments, sounds, durations,
skill lines...). The same number may therefore be an item and a spell of the
same module.

The window sits just above the game's highest numbers (spells 80864, items
56806, item displays 68742, broadcast texts 77865), and stays low on purpose:
the core and the client size their DBC stores by the highest identifier they
hold, so a spell numbered in the millions costs tens of megabytes of memory.

Two exceptions, for database tables where the game already uses the window.
The core keeps these in maps, so a larger number costs nothing:

| Space | Numbers | Tranche 84, for instance |
|---|---|---|
| gameobject templates, gossip menus, pools | tranche × 10 | 840000-849999 |
| creature and gameobject spawns (guid) | tranche × 100000 | 8400000-8499999 |

Game files go in folders of the module's own (`Interface\<Module>\...`); a
file that has to sit in a shared folder, such as `Spells\`, carries a prefix
of the module in its name.

Not concerned: `module_string` (keyed by the module's name), a module's own
tables (`mod_<module>_*`), and the SQL file names (prefixed by the module).

## Tranches

| Tranche | Numbers | Owner |
|---|---|---|
| 81 | 81000-81999 | shared components: the workbench (gameobject 810000) |
| 82 | 82000-82999 | mod-attriboost |
| 83 | 83000-83999 | mod-item-upgrade |
| 84 | 84000-84999 | mod-artifact-weapons |
| 85-86 | 85000-86999 | mod-spheregrid |
| 87-88 | 87000-88999 | mod-stellar-tarot |
| 89 | 89000-89999 | mod-stellar-tarot (levels of cards 198 and up) |
| 90 | 90000-90999 | mod-limit-break |
| 91-99 | 91000-99999 | free |

mod-forever-ui is not in the window: the statistics it adds keep the numbers
of the client they come from (Achievement 6137-64300, Achievement_Criteria
64301-64321), above the game's own.
