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

#include "SphereGridBench.h"
#include "SphereGridMgr.h"
#include "SphereGridPlayerMgr.h"      // Earn, SphereGridItemName
#include "SphereGridStrings.h"        // the origin announced to the player

#include "Item.h"
#include "ItemTemplate.h"
#include "ObjectMgr.h"              // GetItemTemplate: the item quality is authoritative
#include "Player.h"
#include "Random.h"

#include <algorithm>

namespace
{
    // Does the player really carry what he just put on the bench? Entries can
    // repeat — three times the same stone to fuse — hence a count per entry
    // rather than a one-by-one test.
    bool CarriesAll(Player* player, std::vector<uint32> const& entries)
    {
        for (uint32 e : entries)
        {
            uint32 count = uint32(std::count(entries.begin(), entries.end(), e));
            if (!player->HasItemCount(e, count))
                return false;
        }
        return true;
    }

    // Consumes the entries then hands over the result. The order matters: bag
    // room is checked BEFORE anything is destroyed, otherwise a full bag would
    // eat the components and give nothing back.
    SphereGridBenchResult Exchange(Player* player, std::vector<uint32> const& entries,
                                    uint32 crafted)
    {
        if (!CarriesAll(player, entries))
            return SphereGridBenchResult::ItemMissing;

        ItemPosCountVec dest;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, crafted, 1) != EQUIP_ERR_OK)
            return SphereGridBenchResult::BagFull;

        for (uint32 e : entries)
            player->DestroyItemCount(e, 1, true);

        player->AddItem(crafted, 1);
        return SphereGridBenchResult::Ok;
    }

    // A uniform draw among the candidates.
    uint32 PickAtRandom(std::vector<uint32> const& candidates)
    {
        if (candidates.empty())
            return 0;
        return candidates[urand(0, uint32(candidates.size()) - 1)];
    }
}

namespace SphereGridBench
{

SphereGridBenchResult Fuse(Player* player, uint32 entry, uint32& crafted)
{
    SphereGridStone const* stone = sSphereGridMgr->Stone(entry);
    if (!stone)
        return SphereGridBenchResult::NotAStone;

    // "One quality up, same effect" is read from the data: the stone of the same
    // statistic whose amount is the smallest one above ours.
    uint32 best = 0;
    int32 bestAmount = 0;
    for (auto const& [otherEntry, other] : sSphereGridMgr->Stones())
    {
        // Never a node stone: it is not an item, we could not hand it over.
        if (!other.isItem || other.statId != stone->statId || other.amount <= stone->amount)
            continue;
        if (!best || other.amount < bestAmount)
        {
            best = otherEntry;
            bestAmount = other.amount;
        }
    }
    if (!best)
        return SphereGridBenchResult::MaxQuality;

    crafted = best;
    SphereGridBenchResult const r = Exchange(player, { entry, entry, entry }, crafted);
    if (r == SphereGridBenchResult::Ok)
        player->PlayDirectSound(SPHEREGRID_SOUND_CRAFT, player);
    return r;
}

SphereGridBenchResult RerollStone(Player* player, uint32 a, uint32 b, uint32& crafted)
{
    SphereGridStone const* pa = sSphereGridMgr->Stone(a);
    SphereGridStone const* pb = sSphereGridMgr->Stone(b);
    if (!pa || !pb)
        return SphereGridBenchResult::NotAStone;

    // Every stone of a quality carries the same amount: that is what lets two
    // qualities be compared without ever reading an entry.
    if (pa->amount != pb->amount)
        return SphereGridBenchResult::DifferentQualities;

    std::vector<uint32> candidates;
    for (auto const& [entry, other] : sSphereGridMgr->Stones())
        if (other.isItem && other.amount == pa->amount
            && other.statId != pa->statId && other.statId != pb->statId)
            candidates.push_back(entry);

    crafted = PickAtRandom(candidates);
    if (!crafted)
        return SphereGridBenchResult::NothingToDraw;

    SphereGridBenchResult const r = Exchange(player, { a, b }, crafted);
    if (r == SphereGridBenchResult::Ok)
        player->PlayDirectSound(SPHEREGRID_SOUND_CRAFT, player);
    return r;
}

SphereGridBenchResult ReforgeRunes(Player* player, uint32 a, uint32 b, uint32 c,
                                     uint32& crafted)
{
    // Both kinds of rune are reforged together and drawn together: the bench is
    // precisely there to get rid of what is of no use.
    for (uint32 e : { a, b, c })
        if (!sSphereGridMgr->Rune(e) && !sSphereGridMgr->StatRune(e))
            return SphereGridBenchResult::NotARune;

    std::vector<uint32> candidates;
    for (auto const& [entry, _] : sSphereGridMgr->Runes())
        candidates.push_back(entry);
    for (auto const& [entry, _] : sSphereGridMgr->StatRunes())
        candidates.push_back(entry);

    crafted = PickAtRandom(candidates);
    if (!crafted)
        return SphereGridBenchResult::NothingToDraw;

    SphereGridBenchResult const r = Exchange(player, { a, b, c }, crafted);
    if (r == SphereGridBenchResult::Ok)
        player->PlayDirectSound(SPHEREGRID_SOUND_REFORGE, player);
    return r;
}

// AN ITEM'S QUALITY IS THE ONE IN item_template, and nothing else — the same
// rule as the catalogue sent to the client. These are the WoW qualities (0 grey,
// 2 green, 3 blue, 4 purple, 5 orange), so the colours the player sees, not a
// rank computed from the amounts.
static uint32 ItemQuality(uint32 entry)
{
    ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry);
    return proto ? proto->Quality : 0;
}

SphereGridBenchResult Grind(Player* player, uint32 entry, uint32& earned)
{
    if (!player)
        return SphereGridBenchResult::NotGrindable;

    earned = 0;
    uint32 text = SPHEREGRID_STR_GAIN_GRIND_STONE;

    // A rune first — BOTH kinds, as for reforging. It has no quality: a single
    // price, read at value 0.
    if (sSphereGridMgr->Rune(entry) || sSphereGridMgr->StatRune(entry))
    {
        earned = sSphereGridMgr->ExactPointsForSource("grind_rune", 0);
        text = SPHEREGRID_STR_GAIN_GRIND_RUNE;
    }
    else if (SphereGridStone const* stone = sSphereGridMgr->Stone(entry))
    {
        // A NODE stone is not an item: the player cannot hold it, so he cannot
        // grind it.
        if (!stone->isItem)
            return SphereGridBenchResult::NotGrindable;
        // EXACT read, no fallback: value 0 means the grey quality, which forbids
        // using it as the default of the type.
        earned = sSphereGridMgr->ExactPointsForSource("grind_stone", ItemQuality(entry));
    }
    else
        return SphereGridBenchResult::NotGrindable;

    // Nothing configured for this case: the recipe is disabled, and above all
    // nothing is destroyed.
    if (!earned)
        return SphereGridBenchResult::NothingToDraw;

    if (!CarriesAll(player, { entry }))
        return SphereGridBenchResult::ItemMissing;

    // SAME ORDER AS Exchange: destroy only once the payment is certain. Earn
    // fails when the sphere grid state is not loaded (bots). The name is read
    // BEFORE the destruction — afterwards the item no longer exists.
    if (!sSphereGridPlayerMgr->Earn(player, earned, text, SphereGridItemName(player, entry)))
        return SphereGridBenchResult::NothingToDraw;

    player->DestroyItemCount(entry, 1, true);
    player->PlayDirectSound(SPHEREGRID_SOUND_GRIND, player);
    return SphereGridBenchResult::Ok;
}

}   // namespace SphereGridBench
