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
 * mod-stellar-tarot — the layout: a board equipped, cards laid on it.
 *
 * What a CHARACTER plays: which board it has equipped and which card sits on
 * which cell. The binder is the account's; the layout is the character's --
 * the effects apply to one character. A preset is a layout saved under a
 * name, at ACCOUNT level: it names cards of the binder, which the whole
 * account shares.
 *
 * THE RULES OF A CELL. A card faces four numbers: its neighbours' edges, or,
 * on the rim, the board's own -- the number of its row on the left and right
 * edges of the row's first and last cards, the number of its column on the top
 * and bottom edges of the column's first and last cards. Every equality is a
 * match; the number of matches, 0 to 4, is the card's activation level.
 *
 * Everything is read from and written to the characters database
 * synchronously: a click is rare, and what the interface reads back right
 * after a command is what the command wrote.
 */

#ifndef MOD_STELLAR_TAROT_LAYOUT_H_
#define MOD_STELLAR_TAROT_LAYOUT_H_

#include "Define.h"
#include "StellarTarotMgr.h"
#include <array>
#include <string>
#include <vector>

class Player;

struct StellarTarotPlacement
{
    uint8 row = 0;          // 1-based
    uint8 col = 0;          // 1-based
    uint32 cardId = 0;
};

struct StellarTarotLayout
{
    uint32 boardId = 0;                            // 0 = no board equipped
    std::vector<StellarTarotPlacement> cells;
};

// One placed card, once the matches are counted.
struct StellarTarotActivation
{
    StellarTarotPlacement placement;
    std::array<bool, STELLAR_TAROT_EDGES> matched = { false, false, false, false };   // top, right, bottom, left
    uint8 level = 0;
};

enum class StellarTarotLayoutResult : uint8
{
    Ok,
    NoSuchBoard,
    BoardNotKnown,
    NoBoard,            // nothing equipped
    OutOfBounds,
    CellTaken,
    CellEmpty,
    NoSuchCard,
    CardNotKnown,
    CardAlreadyPlaced,
    NoSuchPreset,
    BadPresetName
};

namespace StellarTarotLayouts
{
    [[nodiscard]] StellarTarotLayout Load(Player* player);

    // Equips a board (0 takes it off). Every card comes off the board either way.
    StellarTarotLayoutResult Equip(Player* player, uint32 boardId);
    // Lays a card of the binder on a cell. A card already on the cell comes
    // off it and is reported in `replaced` -- one action, not two.
    StellarTarotLayoutResult Place(Player* player, uint8 row, uint8 col, uint32 cardId, uint32& replaced);
    StellarTarotLayoutResult Remove(Player* player, uint8 row, uint8 col, uint32& cardId);
    // Moves the card of a cell to another: onto a free cell it moves, onto
    // a taken cell the two cards swap (`swappedWith` says which). The same
    // cell twice changes nothing.
    StellarTarotLayoutResult Move(Player* player, uint8 fromRow, uint8 fromCol, uint8 toRow, uint8 toCol,
                                  uint32& cardId, uint32& swappedWith);
    void Clear(Player* player);

    // Presets, at account level. Loading equips the preset's board and lays
    // every card the account still knows; `skipped` counts the others.
    StellarTarotLayoutResult SavePreset(Player* player, std::string name, uint32& presetId, uint32& count);
    StellarTarotLayoutResult LoadPreset(Player* player, uint32 presetId, std::string& name, uint32& laid, uint32& skipped);
    StellarTarotLayoutResult DeletePreset(Player* player, uint32 presetId, std::string& name);

    // The matches of every placed card, from the layout and the board it is
    // laid on. Placements whose card the catalogue no longer has are left out.
    [[nodiscard]] std::vector<StellarTarotActivation> Activations(StellarTarotLayout const& layout);
}

#endif
