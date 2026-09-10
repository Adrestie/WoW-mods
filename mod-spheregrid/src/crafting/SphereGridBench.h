/*
 * This file is part of mod-spheregrid.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * mod-spheregrid — the workbench and its recipes.
 *
 *   Fuse stones      3 identical stones          -> 1 stone, one quality above
 *   Reroll a stone   2 stones of equal quality   -> 1 stone, same quality, other effect
 *   Reforge runes    3 runes, any of them        -> 1 rune drawn from the whole catalogue
 *
 * A rune does NOT upgrade: it is reforged. That is what the workbench is for —
 * a druid rune found by a warrior eventually becomes useful to him.
 *
 * NO NUMBERS HERE. The quality of a stone is not read from its entry but from
 * its AMOUNT: the catalogue gives the same amount to every stone of a quality,
 * so "same quality" reads as "same amount", and "one quality above" as "the
 * next amount up, at equal effect". Nothing is derived from a formula on the
 * entries.
 */

#ifndef MOD_SPHEREGRID_BENCH_H_
#define MOD_SPHEREGRID_BENCH_H_

#include "Define.h"
#include <vector>

class Player;

enum class SphereGridBenchResult : uint8
{
    Ok,
    NotAStone,              // one of the entries is not a stone
    NotARune,               // one of the entries is not a rune
    DifferentEffects,       // fuse: it takes three times the SAME stone
    DifferentQualities,     // reroll: both stones must share a quality
    MaxQuality,             // nothing above the last quality
    NothingToDraw,          // no possible result in the catalogue
    ItemMissing,            // the player does not carry the items
    BagFull,
    NotGrindable            // grind: the entry is neither a stone nor a rune
};

namespace SphereGridBench
{
    // The three crafting recipes. `crafted` receives the crafted entry on success.
    SphereGridBenchResult Fuse(Player* player, uint32 entry, uint32& crafted);
    SphereGridBenchResult RerollStone(Player* player, uint32 a, uint32 b, uint32& crafted);
    SphereGridBenchResult ReforgeRunes(Player* player, uint32 a, uint32 b, uint32 c,
                                         uint32& crafted);

    // GRINDING, the fourth recipe: ONE item, destroyed, returned as Spherite.
    // It is the only one that produces no item — `earned` receives the amount
    // credited.
    //
    // It gives a floor value to what had none: a rune of another class could
    // otherwise only be reforged into a rune just as useless.
    //
    // The amounts are configuration, per stone QUALITY and a single value for
    // runes — a rune has no quality.
    SphereGridBenchResult Grind(Player* player, uint32 entry, uint32& earned);
}

#endif
