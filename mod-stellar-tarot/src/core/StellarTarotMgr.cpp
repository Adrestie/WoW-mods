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
 * mod-stellar-tarot — loading and checking the catalogue.
 */

#include "StellarTarotMgr.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Field.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "QueryResult.h"
#include "SpellMgr.h"
#include "StellarTarotLoot.h"
#include "StellarTarotScript.h"
#include "Tokenize.h"

StellarTarotMgr* StellarTarotMgr::instance()
{
    static StellarTarotMgr instance;
    return &instance;
}

namespace
{
    bool ValidNumber(uint8 n)
    {
        return n >= STELLAR_TAROT_MIN_NUMBER && n <= STELLAR_TAROT_MAX_NUMBER;
    }

    bool ValidSide(uint8 n)
    {
        return n >= STELLAR_TAROT_MIN_SIDE && n <= STELLAR_TAROT_MAX_SIDE;
    }

    // `name` or `name:param:param`, spaces trimmed.
    StellarTarotScriptSpec ParseScript(std::string const& column)
    {
        StellarTarotScriptSpec spec;
        spec.text = column;
        bool first = true;
        for (std::string_view piece : Acore::Tokenize(column, ':', false))
        {
            std::string part(piece);
            while (!part.empty() && part.back() == ' ')
                part.pop_back();
            while (!part.empty() && part.front() == ' ')
                part.erase(part.begin());
            if (first)
                spec.name = part;
            else
                spec.params.push_back(part);
            first = false;
        }
        return spec;
    }

    // Why a card cannot be played, or an empty string when it can.
    std::string Check(StellarTarotCard const& card)
    {
        for (uint8 level = 1; level <= STELLAR_TAROT_LEVELS; ++level)
        {
            StellarTarotEffect const& effect = card.effects[level - 1];
            if (!effect.spellId && effect.script.Empty())
                return "level " + std::to_string(level) + " has neither a spell nor a script";
            if (effect.spellId && !sSpellMgr->GetSpellInfo(effect.spellId))
                return "level " + std::to_string(level) + " names spell " + std::to_string(effect.spellId)
                       + ", which the server does not have";
            if (!effect.script.Empty())
            {
                std::string error;
                if (!StellarTarotScripts::Check(effect.script, error))
                    return "level " + std::to_string(level) + ": " + error;
            }
        }
        return "";
    }
}

void StellarTarotMgr::Load()
{
    _cards.clear();
    _boards.clear();
    _tags.clear();
    _refused.clear();
    _effectSpells.clear();

    _enabled = sConfigMgr->GetOption<bool>("StellarTarot.Enabled", true);
    if (!_enabled)
    {
        LOG_INFO("module", "StellarTarot: disabled by configuration (StellarTarot.Enabled = 0).");
        return;
    }

    // -- the tags ----------------------------------------------------------
    if (QueryResult result = WorldDatabase.Query("SELECT tag_id, name FROM mod_stellar_tarot_tag"))
    {
        do
        {
            Field* f = result->Fetch();
            StellarTarotTag tag;
            tag.id = f[0].Get<uint32>();
            tag.name = f[1].Get<std::string>();
            _tags[tag.id] = std::move(tag);
        } while (result->NextRow());
    }

    // -- the cards ---------------------------------------------------------
    if (QueryResult result = WorldDatabase.Query(
        "SELECT card_id, name, edge_top, edge_right, edge_bottom, edge_left, tag_id, cumulative, "
        "card_spell_1, card_spell_2, card_spell_3, card_spell_4, "
        "card_script_1, card_script_2, card_script_3, card_script_4, art FROM mod_stellar_tarot_card"))
    {
        do
        {
            Field* f = result->Fetch();
            StellarTarotCard card;
            card.id = f[0].Get<uint32>();
            card.name = f[1].Get<std::string>();
            for (uint8 i = 0; i < STELLAR_TAROT_EDGES; ++i)
                card.edges[i] = f[2 + i].Get<uint8>();
            card.tagId = f[6].Get<uint32>();
            card.cumulative = f[7].Get<uint8>() != 0;
            for (uint8 level = 0; level < STELLAR_TAROT_LEVELS; ++level)
            {
                card.effects[level].spellId = f[8 + level].Get<uint32>();
                card.effects[level].script = ParseScript(f[12 + level].Get<std::string>());
            }
            card.art = f[16].Get<std::string>();

            if (card.id == 0 || card.id > STELLAR_TAROT_CARD_MAX)
            {
                LOG_ERROR("module", "StellarTarot: card {} ignored, its number is out of 1..{}.",
                          card.id, STELLAR_TAROT_CARD_MAX);
                continue;
            }
            bool edgesOk = true;
            for (uint8 e : card.edges)
                edgesOk = edgesOk && ValidNumber(e);
            if (!edgesOk)
            {
                _refused[card.id] = "an edge is out of 1..9";
                LOG_ERROR("module", "StellarTarot: card {} \"{}\" REFUSED, an edge is out of {}..{} ({}/{}/{}/{}).",
                          card.id, card.name, STELLAR_TAROT_MIN_NUMBER, STELLAR_TAROT_MAX_NUMBER,
                          card.edges[0], card.edges[1], card.edges[2], card.edges[3]);
                continue;
            }
            std::string why = Check(card);
            if (why.empty() && _tags.find(card.tagId) == _tags.end())
                why = "tag " + std::to_string(card.tagId) + " does not exist";
            if (!why.empty())
            {
                _refused[card.id] = why;
                LOG_ERROR("module", "StellarTarot: card {} \"{}\" REFUSED: {}.", card.id, card.name, why);
                continue;
            }
            ItemTemplate const* item = sObjectMgr->GetItemTemplate(ItemForCard(card.id));
            if (!item)
                LOG_WARN("module", "StellarTarot: card {} has no item template at {} -- it cannot be looted.",
                         card.id, ItemForCard(card.id));
            else if (item->Name1 != card.name)
                LOG_WARN("module", "StellarTarot: card {} is named \"{}\" in the catalogue but its item {} is \"{}\".",
                         card.id, card.name, item->ItemId, item->Name1);
            for (StellarTarotEffect const& effect : card.effects)
                if (effect.spellId)
                    _effectSpells.insert(effect.spellId);
            _cards[card.id] = std::move(card);
        } while (result->NextRow());
    }

    // -- the boards --------------------------------------------------------
    if (QueryResult result = WorldDatabase.Query(
        "SELECT board_id, row_count, col_count, art FROM mod_stellar_tarot_board"))
    {
        do
        {
            Field* f = result->Fetch();
            StellarTarotBoard board;
            board.id = f[0].Get<uint32>();
            board.rows = f[1].Get<uint8>();
            board.cols = f[2].Get<uint8>();
            board.art = f[3].Get<std::string>();

            if (board.id == 0 || board.id > STELLAR_TAROT_BOARD_MAX)
            {
                LOG_ERROR("module", "StellarTarot: board {} ignored, its number is out of 1..{}.",
                          board.id, STELLAR_TAROT_BOARD_MAX);
                continue;
            }
            if (!ValidSide(board.rows) || !ValidSide(board.cols))
            {
                LOG_ERROR("module", "StellarTarot: board {} ignored, {} row(s) x {} column(s) is out of {}..{}.",
                          board.id, board.rows, board.cols, STELLAR_TAROT_MIN_SIDE, STELLAR_TAROT_MAX_SIDE);
                continue;
            }
            if (!sObjectMgr->GetItemTemplate(ItemForBoard(board.id)))
                LOG_WARN("module", "StellarTarot: board {} has no item template at {} -- it cannot be looted.",
                         board.id, ItemForBoard(board.id));
            _boards[board.id] = std::move(board);
        } while (result->NextRow());
    }

    // -- the numbers around each board -------------------------------------
    if (QueryResult result = WorldDatabase.Query(
        "SELECT board_id, axis, idx, side, number FROM mod_stellar_tarot_board_line"))
    {
        do
        {
            Field* f = result->Fetch();
            uint32 const boardId = f[0].Get<uint32>();
            uint8 const axis = f[1].Get<uint8>();
            uint8 const index = f[2].Get<uint8>();
            uint8 const side = f[3].Get<uint8>();
            uint8 const number = f[4].Get<uint8>();
            auto it = _boards.find(boardId);
            if (it == _boards.end())
            {
                LOG_WARN("module", "StellarTarot: line ignored (board {}): no such board.", boardId);
                continue;
            }
            StellarTarotBoard& board = it->second;
            uint8 const count = axis == STELLAR_TAROT_AXIS_ROW ? board.rows : board.cols;
            if ((axis != STELLAR_TAROT_AXIS_ROW && axis != STELLAR_TAROT_AXIS_COLUMN)
                || (side != STELLAR_TAROT_SIDE_FIRST && side != STELLAR_TAROT_SIDE_SECOND)
                || index < 1 || index > count || !ValidNumber(number))
            {
                LOG_WARN("module", "StellarTarot: line ignored (board {}, axis {}, index {}, side {}, number {}): out of range.",
                         boardId, axis, index, side, number);
                continue;
            }
            if (axis == STELLAR_TAROT_AXIS_ROW)
                (side == STELLAR_TAROT_SIDE_FIRST ? board.rowLeft : board.rowRight)[index - 1] = number;
            else
                (side == STELLAR_TAROT_SIDE_FIRST ? board.colTop : board.colBottom)[index - 1] = number;
        } while (result->NextRow());
    }
    for (auto it = _boards.begin(); it != _boards.end();)
    {
        StellarTarotBoard const& board = it->second;
        bool complete = true;
        for (uint8 i = 0; i < board.rows; ++i)
            complete = complete && board.rowLeft[i] != 0 && board.rowRight[i] != 0;
        for (uint8 j = 0; j < board.cols; ++j)
            complete = complete && board.colTop[j] != 0 && board.colBottom[j] != 0;
        if (!complete)
        {
            LOG_ERROR("module", "StellarTarot: board {} ignored, a row or a column lacks a number on one side.", board.id);
            it = _boards.erase(it);
        }
        else
            ++it;
    }

    LOG_INFO("module", "StellarTarot: {} card(s), {} board(s), {} tag(s) loaded{}.",
             _cards.size(), _boards.size(), _tags.size(),
             _refused.empty() ? "" : ", " + std::to_string(_refused.size()) + " card(s) REFUSED (see above)");

    // -- A CARD THE CATALOGUE NO LONGER HOLDS -- refused, or gone from the
    // table -- COMES OFF EVERY BOARD: a placement the server would grant
    // nothing for must not linger. Presets keep their rows; loading one
    // skips what the catalogue lacks. Nothing is touched when no card
    // loaded at all: that is a failed load, not an empty catalogue.
    if (!_cards.empty())
    {
        std::string ids;
        for (auto const& [id, card] : _cards)
            ids += (ids.empty() ? "" : ",") + std::to_string(id);
        CharacterDatabase.DirectExecute("DELETE FROM mod_stellar_tarot_character_cell WHERE card_id NOT IN ({})", ids);
    }

    // -- where it all drops from: checked against the catalogue just read --
    StellarTarotLoot::Load();
}

StellarTarotCard const* StellarTarotMgr::Card(uint32 cardId) const
{
    auto it = _cards.find(cardId);
    return it == _cards.end() ? nullptr : &it->second;
}

StellarTarotBoard const* StellarTarotMgr::Board(uint32 boardId) const
{
    auto it = _boards.find(boardId);
    return it == _boards.end() ? nullptr : &it->second;
}

StellarTarotTag const* StellarTarotMgr::Tag(uint32 tagId) const
{
    auto it = _tags.find(tagId);
    return it == _tags.end() ? nullptr : &it->second;
}

StellarTarotCard const* StellarTarotMgr::CardForItem(uint32 itemEntry) const
{
    if (itemEntry <= STELLAR_TAROT_CARD_ITEM_BASE
        || itemEntry > STELLAR_TAROT_CARD_ITEM_BASE + STELLAR_TAROT_CARD_MAX)
        return nullptr;
    return Card(itemEntry - STELLAR_TAROT_CARD_ITEM_BASE);
}

StellarTarotBoard const* StellarTarotMgr::BoardForItem(uint32 itemEntry) const
{
    if (itemEntry <= STELLAR_TAROT_BOARD_ITEM_BASE
        || itemEntry > STELLAR_TAROT_BOARD_ITEM_BASE + STELLAR_TAROT_BOARD_MAX)
        return nullptr;
    return Board(itemEntry - STELLAR_TAROT_BOARD_ITEM_BASE);
}

std::string StellarTarotMgr::CardName(uint32 cardId) const
{
    ItemTemplate const* item = sObjectMgr->GetItemTemplate(ItemForCard(cardId));
    if (item)
        return item->Name1;
    StellarTarotCard const* card = Card(cardId);
    return card ? card->name : std::string("?");
}

std::string StellarTarotMgr::BoardName(uint32 boardId) const
{
    ItemTemplate const* item = sObjectMgr->GetItemTemplate(ItemForBoard(boardId));
    return item ? item->Name1 : std::string("?");
}
