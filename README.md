# WoW-mods

AzerothCore modules for World of Warcraft 3.3.5a (Wrath of the Lich King).

Each folder is a self-contained module: sources, configuration, SQL and, where
needed, the tooling to patch the client. Follow the README inside the folder.

| Module | What it does |
|---|---|
| [mod-attriboost](mod-attriboost/) | Attribute and talent points players earn from tradeable books and spend across ten statistics, through an NPC or a dedicated interface. Extended fork of [AnchyDev/Attriboost](https://github.com/AnchyDev/Attriboost). |
| [mod-item-upgrade](mod-item-upgrade/) | Rank-by-rank stat upgrades on gear, bought with gold and tokens, plus separate tracks for weapon damage and swing speed and a chance for looted items to arrive already upgraded. Extended fork of [silviu20092/mod-item-upgrade](https://github.com/silviu20092/mod-item-upgrade). |

Each module keeps the licence of the project it forks; see the `LICENSE` file in
its folder. Both are MIT at the time of writing. AzerothCore itself is AGPL v3.
