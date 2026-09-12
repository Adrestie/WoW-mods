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
 * mod-stellar-tarot — the catalogue: cards, boards and tags.
 *
 * In-memory definition, loaded from the world database before the world
 * opens and reloadable with .tarot reload. Everything the module knows about
 * a card or a board is data: the four edges, the numbers around a board, the
 * spell and the script of each activation level, the tags. Nothing here is a
 * setting.
 *
 * A card is known by its number N, a board by its number B. The ITEM the
 * player loots follows from that number and nothing else -- card N is item
 * CARD_ITEM_BASE + N, board B is item BOARD_ITEM_BASE + B -- so no row of the
 * catalogue stores an item entry: moving the base moves every item with it,
 * and the installer rewrites these two constants when it has to.
 *
 * A CARD THAT CANNOT BE PLAYED IS REFUSED AT LOAD: a level with neither a
 * spell nor a script, a spell the server does not have, a script the module
 * does not know or a parameter it cannot read. The refusal is logged, listed
 * by .tarot info, and the card is not in the catalogue -- it cannot be laid.
 */

#ifndef MOD_STELLAR_TAROT_MGR_H_
#define MOD_STELLAR_TAROT_MGR_H_

#include "Define.h"
#include <array>
#include <map>
#include <set>
#include <string>
#include <vector>

// THE IDENTIFIERS THE MODULE ALLOCATES. One block, 902000..903999, one number
// per asset. They are not settings: adapting them to a server that already
// uses the block is the installer's job, and these constants are what its
// shift rewrites.
constexpr uint32 STELLAR_TAROT_CARD_ITEM_BASE  = 902000;   // card N  -> item 902000 + N
constexpr uint32 STELLAR_TAROT_BOARD_ITEM_BASE = 902500;   // board B -> item 902500 + B
constexpr uint32 STELLAR_TAROT_CARD_MAX  = 499;            // 902001..902499
constexpr uint32 STELLAR_TAROT_BOARD_MAX = 99;             // 902501..902599
// THE BANNER: the one aura the player sees while any effect of the board is in
// force. The effects' own auras are hidden from the aura bar; this one says
// that something is, and points at the window.
constexpr uint32 STELLAR_TAROT_BANNER_SPELL = 903002;

// A card has four edges and four activation levels; a board has 2 to 4 rows
// and 2 to 4 columns; every number on an edge or around a board is 1 to 9.
constexpr uint8 STELLAR_TAROT_EDGES    = 4;
constexpr uint8 STELLAR_TAROT_LEVELS   = 4;
constexpr uint8 STELLAR_TAROT_MIN_SIDE = 2;
constexpr uint8 STELLAR_TAROT_MAX_SIDE = 4;
constexpr uint8 STELLAR_TAROT_MIN_NUMBER = 1;
constexpr uint8 STELLAR_TAROT_MAX_NUMBER = 9;

// The edges of a card, in the order the catalogue stores them.
enum StellarTarotEdge : uint8
{
    STELLAR_TAROT_EDGE_TOP    = 0,
    STELLAR_TAROT_EDGE_RIGHT  = 1,
    STELLAR_TAROT_EDGE_BOTTOM = 2,
    STELLAR_TAROT_EDGE_LEFT   = 3
};

// The two axes a board's numbers run along, and the two sides of each.
enum StellarTarotAxis : uint8
{
    STELLAR_TAROT_AXIS_ROW    = 0,   // two numbers per row: left and right
    STELLAR_TAROT_AXIS_COLUMN = 1    // two numbers per column: top and bottom
};

enum StellarTarotSide : uint8
{
    STELLAR_TAROT_SIDE_FIRST  = 0,   // a row's left, a column's top
    STELLAR_TAROT_SIDE_SECOND = 1    // a row's right, a column's bottom
};

// A script named by a card: its registered name and its parameters, as
// written in the column -- `gold_on_kill:500` is name "gold_on_kill" with
// one parameter "500". Empty name = no script at that level.
struct StellarTarotScriptSpec
{
    std::string name;
    std::vector<std::string> params;
    std::string text;                   // the column as written, for the interface
    [[nodiscard]] bool Empty() const { return name.empty(); }
};

// What a card does at one activation level: an aura, a script, or both.
struct StellarTarotEffect
{
    uint32 spellId = 0;
    StellarTarotScriptSpec script;
};

struct StellarTarotCard
{
    uint32 id = 0;
    std::string name;                                                  // English, of reference
    std::array<uint8, STELLAR_TAROT_EDGES> edges = { 0, 0, 0, 0 };     // top, right, bottom, left
    uint32 tagId = 0;                                                  // the one tag: the deck tab it sits under
    bool cumulative = false;                                           // level L grants 1..L, or L alone
    std::string art;                                                   // texture path, client side
    std::array<StellarTarotEffect, STELLAR_TAROT_LEVELS> effects;      // [0] = level 1 .. [3] = level 4
};

struct StellarTarotBoard
{
    uint32 id = 0;
    uint8 rows = 0;
    uint8 cols = 0;
    std::array<uint8, STELLAR_TAROT_MAX_SIDE> rowLeft   = { 0, 0, 0, 0 };   // [i] faces the left edge of row i's first card
    std::array<uint8, STELLAR_TAROT_MAX_SIDE> rowRight  = { 0, 0, 0, 0 };   // [i] faces the right edge of row i's last card
    std::array<uint8, STELLAR_TAROT_MAX_SIDE> colTop    = { 0, 0, 0, 0 };   // [j] faces the top edge of column j's first card
    std::array<uint8, STELLAR_TAROT_MAX_SIDE> colBottom = { 0, 0, 0, 0 };   // [j] faces the bottom edge of column j's last card
    std::string art;
};

struct StellarTarotTag
{
    uint32 id = 0;
    std::string name;
};

class StellarTarotMgr
{
public:
    static StellarTarotMgr* instance();

    // Reloads the whole catalogue from the world database. Called at startup
    // (before the world opens) and by .tarot reload.
    void Load();

    [[nodiscard]] bool Enabled() const { return _enabled; }

    [[nodiscard]] std::map<uint32, StellarTarotCard> const& Cards() const { return _cards; }
    [[nodiscard]] std::map<uint32, StellarTarotBoard> const& Boards() const { return _boards; }
    [[nodiscard]] std::map<uint32, StellarTarotTag> const& Tags() const { return _tags; }
    // The cards refused at load, with the reason: card id -> why.
    [[nodiscard]] std::map<uint32, std::string> const& Refused() const { return _refused; }
    // Every spell any card names, at any level: what a login purges before
    // applying the layout, so that nothing the core saved survives a change.
    [[nodiscard]] std::set<uint32> const& EffectSpells() const { return _effectSpells; }

    [[nodiscard]] StellarTarotCard const* Card(uint32 cardId) const;
    [[nodiscard]] StellarTarotBoard const* Board(uint32 boardId) const;
    [[nodiscard]] StellarTarotTag const* Tag(uint32 tagId) const;

    // The item behind a card or a board, and back. nullptr when the entry is
    // neither.
    static constexpr uint32 ItemForCard(uint32 cardId) { return STELLAR_TAROT_CARD_ITEM_BASE + cardId; }
    static constexpr uint32 ItemForBoard(uint32 boardId) { return STELLAR_TAROT_BOARD_ITEM_BASE + boardId; }
    [[nodiscard]] StellarTarotCard const* CardForItem(uint32 itemEntry) const;
    [[nodiscard]] StellarTarotBoard const* BoardForItem(uint32 itemEntry) const;

    // The name a player reads: the item's, in English. The catalogue's own
    // name is the reference the author wrote; the item's is what shows.
    [[nodiscard]] std::string CardName(uint32 cardId) const;
    [[nodiscard]] std::string BoardName(uint32 boardId) const;

private:
    bool _enabled = true;
    std::map<uint32, StellarTarotCard> _cards;
    std::map<uint32, StellarTarotBoard> _boards;
    std::map<uint32, StellarTarotTag> _tags;
    std::map<uint32, std::string> _refused;
    std::set<uint32> _effectSpells;
};

#define sStellarTarotMgr StellarTarotMgr::instance()

#endif
