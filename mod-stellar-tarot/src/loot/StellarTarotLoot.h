/*
 * This file is part of mod-stellar-tarot.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef MOD_STELLAR_TAROT_LOOT_H_
#define MOD_STELLAR_TAROT_LOOT_H_

#include "Define.h"

#include <string>
#include <vector>

class Loot;
class LootStore;
class Player;

// WHERE A CARD OR A BOARD COMES FROM: one row of mod_stellar_tarot_source.
// A row names what drops -- a given card or board, or one drawn at random
// from the catalogue -- and from what: for now a creature killed, sorted by
// its entry, the expansion of its map, the kind of place, the heroic mode,
// its rank and its level. A filter left at its default matches anything.
// Every row is played on its own, at its own chance, whenever a creature's
// loot is filled; what wins joins that loot, in the loot window, like any
// item of the creature's own table.
struct StellarTarotSource
{
    uint32 id = 0;
    std::string origin;                 // "creature" -- the only origin so far
    bool board = false;                 // what drops: a card, or a board
    uint32 targetId = 0;                // its number; 0 = drawn at random
    uint32 creatureEntry = 0;           // 0 = any creature
    int8 expansion = -1;                // -1 any; 0 classic, 1 Burning Crusade, 2 Wrath -- of the MAP
    std::string place;                  // "" any; world, dungeon, raid
    int8 heroic = -1;                   // -1 any; 0 normal, 1 heroic
    std::string rank;                   // "" any; normal, elite, boss
    uint32 minLevel = 0;                // 0 = no floor
    uint32 maxLevel = 0;                // 0 = no ceiling
    float chance = 0.0f;                // percent, before the configured rate
    uint8 quantity = 1;                 // how many when the roll wins
    std::string comment;
};

namespace StellarTarotLoot
{
    // Reads the sources from the world database and the settings from the
    // configuration. Called by the manager's Load, so `.tarot reload` reads
    // them again.
    void Load();

    [[nodiscard]] std::vector<StellarTarotSource> const& Sources();
    [[nodiscard]] bool Enabled();
    [[nodiscard]] float Rate();                 // percent: 100 leaves the chances as written
    [[nodiscard]] bool KnownMayDrop();          // a card the account already knows may drop again

    // Called for EVERY loot the server fills; leaves at once unless the
    // loot is a creature's.
    void Fill(Loot* loot, LootStore const& store, Player* player);

    // One line saying what a source is, for `.tarot sources`.
    [[nodiscard]] std::string Describe(StellarTarotSource const& source);
}

#endif
