# WoW-mods

AzerothCore modules for World of Warcraft 3.3.5a (Wrath of the Lich King).

Each folder is a self-contained module: sources, configuration, SQL and, where
needed, the tooling to patch the client. Follow the README inside the folder.

| Module | What it does |
|---|---|
| [mod-attriboost](mod-attriboost/) | Attribute and talent points players earn from tradeable books and spend across ten statistics, through an NPC or a dedicated interface. Extended fork of [AnchyDev/Attriboost](https://github.com/AnchyDev/Attriboost). |
| [mod-item-upgrade](mod-item-upgrade/) | Rank-by-rank stat upgrades on gear, bought with gold and tokens, plus separate tracks for weapon damage and swing speed and a chance for looted items to arrive already upgraded. Extended fork of [silviu20092/mod-item-upgrade](https://github.com/silviu20092/mod-item-upgrade). |
| [mod-stellar-tarot](mod-stellar-tarot/) | Cards with a number on each edge, laid on a board whose rows and columns carry numbers too: every edge that matches its neighbour or the board raises the card's level, 1 to 4, and each level applies an aura or runs a script. An account-wide binder, presets, a window over AIO that composes each card from its illustration, and loot sources per creature. Original module, work in progress. **[How to do things with it](mod-stellar-tarot/docs/HOWTO.md)**. |
| [mod-spheregrid](mod-spheregrid/) | A second progression on a grid of cells the character walks through, bought with a currency the content awards: stat stones, runes that add ranks to the game's own spells, and cells teaching custom class spells with backported visuals. An in-game grid editor and a player interface over AIO. Ships its own client patch and writes into a client that already has one, moving its identifiers aside when a server has taken them. Original module. **[How to do things with it](mod-spheregrid/docs/HOWTO.md)**, screenshots included. |
| [mod-limit-break](mod-limit-break/) | A gauge shared by a party or a raid, after Final Fantasy XIV's Limit Break: damage dealt, damage taken and healing from every member fill one common bar, and any of them can spend it on an effect whose strength follows the bar and whose archetype -- healing, physical damage, magic damage, tank -- each player picks tier by tier. The gauge lives wherever most of the group actually is, by map, instance, zone and phase, with no distance measured anywhere. Original module. **Specification only, no code yet: [cahier des charges](mod-limit-break/docs/CAHIER_DES_CHARGES.md)**, in French. |

| [mod-forever-ui](mod-forever-ui/) | The modern interface rebuilt for a 3.3.5a client: player and target frames, death knight runes, cast bar, action bar, micro menu, bags, experience and reputation bars, each of them a piece the player can move. Not a server module but a client addon and the art it needs, read sheet by sheet from a modern client and served through texture coordinates, since 3.3.5 has no atlas. Original module, work in progress. **[What is known to be improvable](mod-forever-ui/docs/AMELIORATIONS.md)**, in French. |
The `workbench/` folder is not a module but a component the modules share: one
object in the world and one window, to which each installed module brings its
recipes. Every module that uses it ships an identical copy under
`data/lua/Workbench/`; `workbench/` is where it is edited.

Each module keeps the licence of the project it forks, or MIT when original; see
the `LICENSE` file in its folder. mod-stellar-tarot and mod-limit-break are
GPL-2.0-or-later, the licence of AzerothCore they are compiled into; the others
are MIT at the time of writing. AzerothCore itself is AGPL v3.
