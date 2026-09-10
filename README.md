# WoW-mods

AzerothCore modules for World of Warcraft 3.3.5a (Wrath of the Lich King).

Each folder is a self-contained module: sources, configuration, SQL and, where
needed, the tooling to patch the client. Follow the README inside the folder.

| Module | What it does |
|---|---|
| [mod-attriboost](mod-attriboost/) | Attribute and talent points players earn from tradeable books and spend across ten statistics, through an NPC or a dedicated interface. Extended fork of [AnchyDev/Attriboost](https://github.com/AnchyDev/Attriboost). |
| [mod-item-upgrade](mod-item-upgrade/) | Rank-by-rank stat upgrades on gear, bought with gold and tokens, plus separate tracks for weapon damage and swing speed and a chance for looted items to arrive already upgraded. Extended fork of [silviu20092/mod-item-upgrade](https://github.com/silviu20092/mod-item-upgrade). |
| [mod-spheregrid](mod-spheregrid/) | A second progression on a grid of cells the character walks through, bought with a currency the content awards: stat stones, runes that add ranks to the game's own spells, and cells teaching custom class spells with backported visuals. An in-game grid editor and a player interface over AIO. Ships its own client patch and writes into a client that already has one, moving its identifiers aside when a server has taken them. Original module. **[How to do things with it](mod-spheregrid/docs/HOWTO.md)**, screenshots included. |

Each module keeps the licence of the project it forks, or MIT when original; see
the `LICENSE` file in its folder. All three are MIT at the time of writing.
AzerothCore itself is AGPL v3.
