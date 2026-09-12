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
 * mod-stellar-tarot — the layout, read and written in the characters database.
 */

#include "StellarTarotLayout.h"
#include "DatabaseEnv.h"
#include "StringFormat.h"
#include "Field.h"
#include "Player.h"
#include "QueryResult.h"
#include "StellarTarotBinder.h"
#include "WorldSession.h"

namespace
{
    uint32 Guid(Player* player) { return player->GetGUID().GetCounter(); }
    uint32 Account(Player* player) { return player->GetSession()->GetAccountId(); }

    void ClearCells(uint32 guid)
    {
        CharacterDatabase.DirectExecute("DELETE FROM mod_stellar_tarot_character_cell WHERE guid = {}", guid);
    }

    // The board equipped, or nullptr with the reason.
    StellarTarotBoard const* EquippedBoard(StellarTarotLayout const& layout, StellarTarotLayoutResult& why)
    {
        if (!layout.boardId)
        {
            why = StellarTarotLayoutResult::NoBoard;
            return nullptr;
        }
        StellarTarotBoard const* board = sStellarTarotMgr->Board(layout.boardId);
        if (!board)
            why = StellarTarotLayoutResult::NoSuchBoard;
        return board;
    }

    StellarTarotPlacement const* At(StellarTarotLayout const& layout, uint8 row, uint8 col)
    {
        for (auto const& p : layout.cells)
            if (p.row == row && p.col == col)
                return &p;
        return nullptr;
    }
}

StellarTarotLayout StellarTarotLayouts::Load(Player* player)
{
    StellarTarotLayout layout;
    uint32 const guid = Guid(player);
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT board_id FROM mod_stellar_tarot_character_board WHERE guid = {}", guid))
        layout.boardId = result->Fetch()[0].Get<uint32>();
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT row_idx, col_idx, card_id FROM mod_stellar_tarot_character_cell WHERE guid = {} ORDER BY row_idx, col_idx", guid))
    {
        do
        {
            Field* f = result->Fetch();
            layout.cells.push_back({ f[0].Get<uint8>(), f[1].Get<uint8>(), f[2].Get<uint32>() });
        } while (result->NextRow());
    }
    return layout;
}

StellarTarotLayoutResult StellarTarotLayouts::Equip(Player* player, uint32 boardId)
{
    if (boardId)
    {
        if (!sStellarTarotMgr->Board(boardId))
            return StellarTarotLayoutResult::NoSuchBoard;
        if (!StellarTarotBinder::KnowsBoard(Account(player), boardId))
            return StellarTarotLayoutResult::BoardNotKnown;
    }
    uint32 const guid = Guid(player);
    // CHANGING THE BOARD TAKES EVERY CARD OFF, even for the same board again:
    // the rule is one and the same, and simpler to trust.
    ClearCells(guid);
    CharacterDatabase.DirectExecute(
        "REPLACE INTO mod_stellar_tarot_character_board (guid, board_id) VALUES ({}, {})", guid, boardId);
    return StellarTarotLayoutResult::Ok;
}

StellarTarotLayoutResult StellarTarotLayouts::Place(Player* player, uint8 row, uint8 col, uint32 cardId, uint32& replaced)
{
    replaced = 0;
    StellarTarotLayout const layout = Load(player);
    StellarTarotLayoutResult why = StellarTarotLayoutResult::Ok;
    StellarTarotBoard const* board = EquippedBoard(layout, why);
    if (!board)
        return why;
    if (row < 1 || row > board->rows || col < 1 || col > board->cols)
        return StellarTarotLayoutResult::OutOfBounds;
    if (!sStellarTarotMgr->Card(cardId))
        return StellarTarotLayoutResult::NoSuchCard;
    if (!StellarTarotBinder::KnowsCard(Account(player), cardId))
        return StellarTarotLayoutResult::CardNotKnown;
    // ONE CARD, ONE CELL: the binder holds each card once, and so does the
    // board. A card already laid is moved with Move, not laid again.
    for (auto const& p : layout.cells)
        if (p.cardId == cardId)
            return StellarTarotLayoutResult::CardAlreadyPlaced;
    // A TAKEN CELL IS NOT A REFUSAL: its card gives way, in the same action.
    if (StellarTarotPlacement const* there = At(layout, row, col))
        replaced = there->cardId;
    CharacterDatabase.DirectExecute(
        "REPLACE INTO mod_stellar_tarot_character_cell (guid, row_idx, col_idx, card_id) VALUES ({}, {}, {}, {})",
        Guid(player), row, col, cardId);
    return StellarTarotLayoutResult::Ok;
}

StellarTarotLayoutResult StellarTarotLayouts::Move(Player* player, uint8 fromRow, uint8 fromCol, uint8 toRow, uint8 toCol,
                                                   uint32& cardId, uint32& swappedWith)
{
    cardId = 0;
    swappedWith = 0;
    StellarTarotLayout const layout = Load(player);
    StellarTarotLayoutResult why = StellarTarotLayoutResult::Ok;
    StellarTarotBoard const* board = EquippedBoard(layout, why);
    if (!board)
        return why;
    if (toRow < 1 || toRow > board->rows || toCol < 1 || toCol > board->cols)
        return StellarTarotLayoutResult::OutOfBounds;
    StellarTarotPlacement const* from = At(layout, fromRow, fromCol);
    if (!from)
        return StellarTarotLayoutResult::CellEmpty;
    cardId = from->cardId;
    if (fromRow == toRow && fromCol == toCol)
        return StellarTarotLayoutResult::Ok;
    uint32 const guid = Guid(player);
    StellarTarotPlacement const* to = At(layout, toRow, toCol);
    if (to)
        swappedWith = to->cardId;
    // Both rows go, then both come back exchanged: one transaction, so that
    // a layout read in between never sees a card on two cells or on none.
    CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
    trans->Append(Acore::StringFormat(
        "DELETE FROM mod_stellar_tarot_character_cell WHERE guid = {} AND ((row_idx = {} AND col_idx = {}) OR (row_idx = {} AND col_idx = {}))",
        guid, fromRow, fromCol, toRow, toCol).c_str());
    trans->Append(Acore::StringFormat(
        "INSERT INTO mod_stellar_tarot_character_cell (guid, row_idx, col_idx, card_id) VALUES ({}, {}, {}, {})",
        guid, toRow, toCol, cardId).c_str());
    if (to)
        trans->Append(Acore::StringFormat(
            "INSERT INTO mod_stellar_tarot_character_cell (guid, row_idx, col_idx, card_id) VALUES ({}, {}, {}, {})",
            guid, fromRow, fromCol, swappedWith).c_str());
    CharacterDatabase.DirectCommitTransaction(trans);
    return StellarTarotLayoutResult::Ok;
}

StellarTarotLayoutResult StellarTarotLayouts::Remove(Player* player, uint8 row, uint8 col, uint32& cardId)
{
    StellarTarotLayout const layout = Load(player);
    StellarTarotLayoutResult why = StellarTarotLayoutResult::Ok;
    if (!EquippedBoard(layout, why))
        return why;
    StellarTarotPlacement const* placed = At(layout, row, col);
    if (!placed)
        return StellarTarotLayoutResult::CellEmpty;
    cardId = placed->cardId;
    CharacterDatabase.DirectExecute(
        "DELETE FROM mod_stellar_tarot_character_cell WHERE guid = {} AND row_idx = {} AND col_idx = {}",
        Guid(player), row, col);
    return StellarTarotLayoutResult::Ok;
}

void StellarTarotLayouts::Clear(Player* player)
{
    ClearCells(Guid(player));
}

StellarTarotLayoutResult StellarTarotLayouts::SavePreset(Player* player, std::string name, uint32& presetId, uint32& count)
{
    // A name of 1 to 32 characters, with nothing the database or the
    // interface would misread.
    while (!name.empty() && name.back() == ' ')
        name.pop_back();
    while (!name.empty() && name.front() == ' ')
        name.erase(name.begin());
    if (name.empty() || name.size() > 32 || name.find_first_of("\"\\|") != std::string::npos)
        return StellarTarotLayoutResult::BadPresetName;

    StellarTarotLayout const layout = Load(player);
    StellarTarotLayoutResult why = StellarTarotLayoutResult::Ok;
    if (!EquippedBoard(layout, why))
        return why;

    uint32 const account = Account(player);
    presetId = 1;
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT COALESCE(MAX(preset_id), 0) + 1 FROM mod_stellar_tarot_preset WHERE account_id = {}", account))
        presetId = result->Fetch()[0].Get<uint32>();

    std::string safe = name;
    CharacterDatabase.EscapeString(safe);
    CharacterDatabase.DirectExecute(
        "INSERT INTO mod_stellar_tarot_preset (account_id, preset_id, name, board_id) VALUES ({}, {}, '{}', {})",
        account, presetId, safe, layout.boardId);
    count = 0;
    for (auto const& p : layout.cells)
    {
        CharacterDatabase.DirectExecute(
            "INSERT INTO mod_stellar_tarot_preset_cell (account_id, preset_id, row_idx, col_idx, card_id) VALUES ({}, {}, {}, {}, {})",
            account, presetId, p.row, p.col, p.cardId);
        ++count;
    }
    return StellarTarotLayoutResult::Ok;
}

StellarTarotLayoutResult StellarTarotLayouts::LoadPreset(Player* player, uint32 presetId, std::string& name, uint32& laid, uint32& skipped)
{
    uint32 const account = Account(player);
    uint32 boardId = 0;
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT name, board_id FROM mod_stellar_tarot_preset WHERE account_id = {} AND preset_id = {}", account, presetId))
    {
        Field* f = result->Fetch();
        name = f[0].Get<std::string>();
        boardId = f[1].Get<uint32>();
    }
    else
        return StellarTarotLayoutResult::NoSuchPreset;

    // The board first: a board the account no longer owns, or the catalogue
    // no longer has, stops everything and changes nothing.
    StellarTarotLayoutResult equipped = Equip(player, boardId);
    if (equipped != StellarTarotLayoutResult::Ok)
        return equipped;

    laid = skipped = 0;
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT row_idx, col_idx, card_id FROM mod_stellar_tarot_preset_cell WHERE account_id = {} AND preset_id = {} ORDER BY row_idx, col_idx",
        account, presetId))
    {
        do
        {
            Field* f = result->Fetch();
            uint32 dummy = 0;
            if (Place(player, f[0].Get<uint8>(), f[1].Get<uint8>(), f[2].Get<uint32>(), dummy) == StellarTarotLayoutResult::Ok)
                ++laid;
            else
                ++skipped;
        } while (result->NextRow());
    }
    return StellarTarotLayoutResult::Ok;
}

StellarTarotLayoutResult StellarTarotLayouts::DeletePreset(Player* player, uint32 presetId, std::string& name)
{
    uint32 const account = Account(player);
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT name FROM mod_stellar_tarot_preset WHERE account_id = {} AND preset_id = {}", account, presetId))
        name = result->Fetch()[0].Get<std::string>();
    else
        return StellarTarotLayoutResult::NoSuchPreset;
    CharacterDatabase.DirectExecute(
        "DELETE FROM mod_stellar_tarot_preset_cell WHERE account_id = {} AND preset_id = {}", account, presetId);
    CharacterDatabase.DirectExecute(
        "DELETE FROM mod_stellar_tarot_preset WHERE account_id = {} AND preset_id = {}", account, presetId);
    return StellarTarotLayoutResult::Ok;
}

std::vector<StellarTarotActivation> StellarTarotLayouts::Activations(StellarTarotLayout const& layout)
{
    std::vector<StellarTarotActivation> out;
    StellarTarotBoard const* board = layout.boardId ? sStellarTarotMgr->Board(layout.boardId) : nullptr;
    if (!board)
        return out;

    // The grid, for the neighbours: [row][col], 1-based, 0 = empty.
    uint32 grid[STELLAR_TAROT_MAX_SIDE + 2][STELLAR_TAROT_MAX_SIDE + 2] = {};
    for (auto const& p : layout.cells)
        if (p.row >= 1 && p.row <= board->rows && p.col >= 1 && p.col <= board->cols)
            grid[p.row][p.col] = p.cardId;

    // The number a card's edge faces: the neighbour's opposite edge, the
    // board's number on the rim, 0 where an inner neighbour is missing.
    auto facing = [&](uint8 row, uint8 col, uint8 edge) -> uint8
    {
        int const dr[STELLAR_TAROT_EDGES] = { -1, 0, 1, 0 };
        int const dc[STELLAR_TAROT_EDGES] = { 0, 1, 0, -1 };
        int const nr = int(row) + dr[edge];
        int const nc = int(col) + dc[edge];
        if (nr < 1)
            return board->colTop[col - 1];              // top rim
        if (nr > board->rows)
            return board->colBottom[col - 1];           // bottom rim
        if (nc < 1)
            return board->rowLeft[row - 1];             // left rim
        if (nc > board->cols)
            return board->rowRight[row - 1];            // right rim
        StellarTarotCard const* other = sStellarTarotMgr->Card(grid[nr][nc]);
        if (!other)
            return 0;
        uint8 const opposite[STELLAR_TAROT_EDGES] = {
            STELLAR_TAROT_EDGE_BOTTOM, STELLAR_TAROT_EDGE_LEFT, STELLAR_TAROT_EDGE_TOP, STELLAR_TAROT_EDGE_RIGHT };
        return other->edges[opposite[edge]];
    };

    for (auto const& p : layout.cells)
    {
        StellarTarotCard const* card = sStellarTarotMgr->Card(p.cardId);
        if (!card || !grid[p.row][p.col])
            continue;
        StellarTarotActivation a;
        a.placement = p;
        for (uint8 edge = 0; edge < STELLAR_TAROT_EDGES; ++edge)
        {
            a.matched[edge] = card->edges[edge] != 0 && card->edges[edge] == facing(p.row, p.col, edge);
            if (a.matched[edge])
                ++a.level;
        }
        out.push_back(a);
    }
    return out;
}
