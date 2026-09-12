/*
 * This file is part of mod-stellar-tarot.
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
 * mod-stellar-tarot — the binder, read and written in the characters database.
 */

#include "StellarTarotBinder.h"
#include "DatabaseEnv.h"
#include "Field.h"
#include "Player.h"
#include "QueryResult.h"
#include "Random.h"
#include "StellarTarotMgr.h"
#include "WorldSession.h"
#include <algorithm>
#include <vector>

namespace
{
    bool Knows(char const* table, char const* column, uint32 accountId, uint32 id)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT 1 FROM {} WHERE account_id = {} AND {} = {}", table, accountId, column, id);
        return result != nullptr;
    }

    std::vector<uint32> Listed(char const* table, char const* column, uint32 accountId)
    {
        std::vector<uint32> out;
        if (QueryResult result = CharacterDatabase.Query(
            "SELECT {} FROM {} WHERE account_id = {} ORDER BY {}", column, table, accountId, column))
        {
            do
                out.push_back(result->Fetch()[0].Get<uint32>());
            while (result->NextRow());
        }
        return out;
    }
}

bool StellarTarotBinder::KnowsCard(uint32 accountId, uint32 cardId)
{
    return Knows("mod_stellar_tarot_account_card", "card_id", accountId, cardId);
}

bool StellarTarotBinder::KnowsBoard(uint32 accountId, uint32 boardId)
{
    return Knows("mod_stellar_tarot_account_board", "board_id", accountId, boardId);
}

std::vector<uint32> StellarTarotBinder::Cards(uint32 accountId)
{
    return Listed("mod_stellar_tarot_account_card", "card_id", accountId);
}

std::vector<uint32> StellarTarotBinder::Boards(uint32 accountId)
{
    return Listed("mod_stellar_tarot_account_board", "board_id", accountId);
}

StellarTarotStudyResult StellarTarotBinder::Study(Player* player, uint32 entry, bool& isBoard, uint32& id)
{
    StellarTarotCard const* card = sStellarTarotMgr->CardForItem(entry);
    StellarTarotBoard const* board = sStellarTarotMgr->BoardForItem(entry);
    if (!card && !board)
        return StellarTarotStudyResult::NotOurs;

    isBoard = board != nullptr;
    id = isBoard ? board->id : card->id;

    if (!player->HasItemCount(entry, 1))
        return StellarTarotStudyResult::NotCarried;

    uint32 const accountId = player->GetSession()->GetAccountId();
    if (isBoard ? KnowsBoard(accountId, id) : KnowsCard(accountId, id))
        return StellarTarotStudyResult::AlreadyKnown;

    // THE ROW FIRST, THE ITEM AFTER: a write that fails leaves the item in the
    // bags, where the player can try again; the other order could lose it.
    if (isBoard)
        CharacterDatabase.DirectExecute(
            "INSERT INTO mod_stellar_tarot_account_board (account_id, board_id) VALUES ({}, {})", accountId, id);
    else
        CharacterDatabase.DirectExecute(
            "INSERT INTO mod_stellar_tarot_account_card (account_id, card_id) VALUES ({}, {})", accountId, id);
    player->DestroyItemCount(entry, 1, true);
    return StellarTarotStudyResult::Ok;
}

// ---------------------------------------------------------------------------
// The workbench
// ---------------------------------------------------------------------------

StellarTarotFuseResult StellarTarotFuse::Fuse(Player* player, uint32 a, uint32 b, uint32 c, uint32& crafted, bool& isBoard)
{
    std::vector<uint32> const entries = { a, b, c };
    bool cards = true, boards = true;
    for (uint32 e : entries)
    {
        cards = cards && sStellarTarotMgr->CardForItem(e) != nullptr;
        boards = boards && sStellarTarotMgr->BoardForItem(e) != nullptr;
    }
    if (!cards && !boards)
        return StellarTarotFuseResult::NotThreeOfAKind;
    isBoard = boards;

    // Entries can repeat -- three times the same card -- hence a count per
    // entry rather than a one-by-one test.
    for (uint32 e : entries)
        if (!player->HasItemCount(e, uint32(std::count(entries.begin(), entries.end(), e))))
            return StellarTarotFuseResult::NotCarried;

    // A uniform draw over the whole catalogue, the known ones included.
    std::vector<uint32> candidates;
    if (isBoard)
        for (auto const& [id, board] : sStellarTarotMgr->Boards())
            candidates.push_back(StellarTarotMgr::ItemForBoard(id));
    else
        for (auto const& [id, card] : sStellarTarotMgr->Cards())
            candidates.push_back(StellarTarotMgr::ItemForCard(id));
    if (candidates.empty())
        return StellarTarotFuseResult::NothingToDraw;
    crafted = candidates[urand(0, uint32(candidates.size()) - 1)];

    // Bag room is checked BEFORE anything is destroyed, otherwise a full bag
    // would eat the components and give nothing back.
    ItemPosCountVec dest;
    if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, crafted, 1) != EQUIP_ERR_OK)
        return StellarTarotFuseResult::BagFull;
    for (uint32 e : entries)
        player->DestroyItemCount(e, 1, true);
    player->AddItem(crafted, 1);
    return StellarTarotFuseResult::Ok;
}
