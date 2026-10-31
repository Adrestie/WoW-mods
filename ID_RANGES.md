# Identifier ranges

_Registry in force since 31/10/2026 (chosen by Maitre on 30/10/2026). The modules were renumbered from the old registry (81 000-99 999, kept in `_analyse_ids_coa/ID_RANGES_ancien.md`); the map of every old identifier to its new one is `_analyse_ids_coa/csv/mods_ancien_vers_nouveau.csv`._

Every WoW-mods module takes its identifiers from one window, **580 000-879 999**, cut into **30 blocks of 10 000**. A module gets one block (more if it ever needs them) and keeps all its identifiers in it, in every space at once: items, spells, creatures, quests, texts, reference loot, and every DBC file. The same number may therefore be an item and a spell of the same module.

The window sits just above the Conquest of Azeroth blocks: in every family, the game's numbers come first, then Conquest of Azeroth's block (consecutive, in the order of CoA's own numbers; items reach 579 690), then the modules.

## Derived spaces

| Space | Numbers | Module in block k (start S = 580 000 + k × 10 000) |
|---|---|---|
| everything else (items, spells, creatures, quests, texts, loot, DBC rows…) | n | S to S + 9 999 |
| gameobject templates, gossip menus, pools | n × 10 (+ 0-9) | S × 10 to S × 10 + 99 999 |
| creature and gameobject spawns (guid) | 6 000 000 + k × 100 000 + rank | 6 000 000 + k × 100 000, 100 000 guids |
| waypoint_data paths | guid × 10 + point | the module's guids × 10 |
| limited spaces (see below) | base + k × 100 + (n − S), only for n − S < 100 | 100 numbers |

The guids no longer take n × 100: from 580 000 up, n × 100 would pass the 24-bit guid counter (16 777 215). A module numbers its spawns by rank inside its own 100 000 guids.

### Limited spaces

Spaces the client or the database holds in 16 bits or less. A module uses only the first 100 numbers of its block there (n from S to S + 99), mapped as below. Talent, achievements, criteria, factions, faction templates and maps can be widened to 32 bits on the server side (Conquest of Azeroth already did it for talents and achievements); once widened, they take n like every other space.

| Space | Base | Range | Why limited |
|---|---|---|---|
| SkillLine | 2 000 | 2 000-4 999 | client (PLAYER_SKILL_INFO, 16 bits) |
| GlyphProperties | 1 000 | 1 000-3 999 | client (talent packet, uint16) |
| Talent | 4 000 | 4 000-6 999 | core type uint16 (widenable) |
| Achievement | 26 000 | 26 000-28 999 | character DB smallint (widenable) |
| Achievement_Criteria | 40 000 | 40 000-42 999 | character DB smallint (widenable) |
| Faction | 3 000 | 3 000-5 999 | DB smallint (widenable); the client lists 128 reputations, CoA uses 118 |
| FactionTemplate | 3 000 | 3 000-5 999 | DB smallint (widenable) |
| Map | 5 000 | 5 000-7 999 | DB smallint (widenable) |

`game_event` (1-255, tinyint) stays outside the scheme: UniWoW's events take 246-255, from 255 down; widening it is possible on the server side. TaxiNodes (448), titles (bit < 192) and explored zones (bit < 4 096) are full or nearly full and have no module range.

A module's cleanup clauses (`DELETE ... BETWEEN`, the installer's `where`) stop at the end of its own block.

## Blocks

| Numbers | Block k | Owner | Old numbers |
|---|---|---|---|
| 580 000-589 999 | 0 | shared components | 81000-81099 |
| 590 000-599 999 | 1 | mod-attriboost | 82000-82099 |
| 600 000-609 999 | 2 | UniWoW editor | 82100-82199 |
| 610 000-619 999 | 3 | vfx-lab | 82700-82799 |
| 620 000-629 999 | 4 | UniWoW, prefabs PNJ | 82800-82999 |
| 630 000-639 999 | 5 | mod-item-upgrade | 83000-83099 |
| 640 000-649 999 | 6 | mod-artifact-weapons | 84000-84999 |
| 650 000-659 999 | 7 | mod-spheregrid | 85000-86999 |
| 660 000-669 999 | 8 | mod-stellar-tarot | 87000-89999 |
| 670 000-679 999 | 9 | mod-limit-break | 90000-90299 |
| 680 000-689 999 | 10 | mod-companion-mount | 91000-91099 |
| 690 000-699 999 | 11 | mod-guild-level | 92000-94599 |
| 700 000-709 999 | 12 | mod-dungeon-quests | 94600-94699 |
| 710 000-719 999 | 13 | mod-find-resources | 95000-95099 |
| 730 000-739 999 | 15 | mod-wow-fates | 96000-96399 |
| 740 000-749 999 | 16 | mod-transmog-retail | 97000-97099 |
| 750 000-759 999 | 17 | mod-arac | 98000-98299 |
| 760 000-769 999 | 18 | mod-coa-classes (ajouts propres) | outside the old window |
| 770 000-779 999 | 19 | mod-forever-ui | outside the old window |
| 720 000-729 999 | 14 | **left empty**: AzerothCore's npc_text 724001-724006 lie in it | |
| free | 20, 21, 22, 23, 24, 25, 26, 27, 28, 29 | every other block | |

mod-forever-ui moves into its block: its statistics (achievements 6137-64300, criteria 64301-64321) collided with Conquest of Azeroth's achievement block (4 825-25 611); they take the limited-space rule (or n once widened).

mod-coa-classes keeps Conquest of Azeroth's numbers for CoA content (renumbered in CoA's blocks); what the module adds itself (trainers 2362000-2362001, spawns 9900000-9900199, SkillLineAbility 770000+) moves into its block.
