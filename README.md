# WoW-mods

AzerothCore modules for World of Warcraft 3.3.5a (Wrath of the Lich King).

> **The modules have moved.** Each one now lives in its own repository, listed
> below: download or fork only the one you want.

## Modules

| Module | What it does |
|---|---|
| [mod-attriboost](https://github.com/Adrestie/mod-attriboost) | Attribute and talent points, earned from books and spent across ten statistics. |
| [mod-item-upgrade](https://github.com/Adrestie/mod-item-upgrade) | Upgrades the stats of gear rank by rank, for gold and tokens. |
| [mod-stellar-tarot](https://github.com/Adrestie/mod-stellar-tarot) | Cards laid on a board: matching numbers level them up and grant their effects. |
| [mod-spheregrid](https://github.com/Adrestie/mod-spheregrid) | A second progression on a grid: stats, spell ranks and new class spells. |
| [mod-limit-break](https://github.com/Adrestie/mod-limit-break) | A Limit Break gauge shared by the group, after Final Fantasy XIV. Specification only. |
| [mod-forever-ui](https://github.com/Adrestie/mod-forever-ui) | A modern user interface for the 3.3.5a client. |
| [mod-artifact-weapons](https://github.com/Adrestie/mod-artifact-weapons) | Class-bound artifact weapons with effects of their own. |
| [mod-acp-fix](https://github.com/Adrestie/mod-acp-fix) | Fixes the Addon Control Panel of the HD client packs, whose window stays empty in six of its languages. |
| [dynamicloot](https://github.com/Adrestie/WoW-mods-dynamicloot) | A shared loot extension: modules spread their drops across the game without editing loot tables. In progress. |
| [UniWoW](https://github.com/Adrestie/UniWoW) | A multipurpose WoW editor (map, quest, DB, WMO, etc.) |
| [mod-wow-fates](https://github.com/Adrestie/mod-wow-fates) | Expeditions: events that appear on the world map, with objectives, rewards by level and a debuff that brings overpowered players down to the event's level. |
| [mod-guild-level](https://github.com/Adrestie/mod-guild-level) | Guild levels after Cataclysm: guild experience earned together, 25 levels of perks, then a Paragon progression with a guild house to furnish. |
| [mod-aoe-loot](https://github.com/Adrestie/mod-aoe-loot) | Area loot: looting one corpse loots every nearby corpse in a single window, without changing loot rules or rolls. |
| [mod-profession-xp](https://github.com/Adrestie/mod-profession-xp) | Experience from gathering and crafting, by difficulty and for each first time; Spherite at maximum level with mod-spheregrid. |
| [mod-craft-speed](https://github.com/Adrestie/mod-craft-speed) | Crafting speed for each profession: the cast time of every craft multiplied by a value set per profession. |
| [mod-companion-mount](https://github.com/Adrestie/mod-companion-mount) | The player's mount as a companion that fights and loots, levels up, and has its own talents, spells and inventory. |
| [mod-pvp-titles-ext](https://github.com/Adrestie/mod-pvp-titles-ext) | The PvP titles of mod-pvp-titles, with an addon channel and a Dishonored state for players who kill too many civilians. |
| [mod-claude-mcp](https://github.com/Adrestie/mod-claude-mcp) | Lets an assistant such as Claude act on the worldserver beside SOAP: every GM command as any character, characters logged in without a client, answers in JSON, through an MCP server. |
| [mod-find-resources](https://github.com/Adrestie/mod-find-resources) | Find Resources: one tracking spell that shows herbs, mineral veins and schools of fish on the minimap at once, learned by a quest from the gathering trainers of the capitals. |
| [mod-dungeon-quests](https://github.com/Adrestie/mod-dungeon-quests) | A neutral quest giver at the entrance and at the end of every 5-player dungeon: it gives and takes back the dungeon's quests, whatever the race, the faction or the chain. |
| [mod-arac](https://github.com/Adrestie/mod-arac) | All Races, All Classes: every playable race with every playable class, generated from the game's own files, so that the classes and races other mods add get every pair too. |
| [mod-custom-classes](https://github.com/Adrestie/mod-custom-classes) | Five new playable classes: Monk, Demon Hunter, Evoker, Mercenary and Sage. For now a client mock-up: each class copies a Blizzard class. |
| [mod-shared-professions](https://github.com/Adrestie/mod-shared-professions) | No limit of two primary professions, and professions shared across the account: each character gets the best skill and every recipe it could learn from the others. |

Every module takes its identifiers from the registry in
[ID_RANGES.md](ID_RANGES.md).

Each module has its licence in its repository: mod-attriboost,
mod-item-upgrade and mod-craft-speed are MIT, like the projects they are
based on; mod-acp-fix is MIT for
its own files and its changes, the files of ACP it carries staying under their
authors' terms; mod-pvp-titles-ext is AGPL-3.0, like mod-pvp-titles, which it
forks; mod-arac is AGPL-3.0, like heyitsbench/mod-arac, after which it is made;
the other modules are GPL-2.0-or-later, the licence of
AzerothCore.

## Installer

[WoW-mods-installer](https://github.com/Adrestie/WoW-mods-installer) installs
and removes these modules, on the server and in the game client.
