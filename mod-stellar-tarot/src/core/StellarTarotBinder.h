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
 * mod-stellar-tarot — the binder.
 *
 * What an ACCOUNT knows: the cards and the boards any of its characters has
 * studied, present or future. A card is studied by using the item: it joins
 * the binder for good and the item is destroyed. A card already in the binder
 * cannot be studied twice -- the item stays in the bags, as a recipe already
 * known does.
 *
 * The binder lives in the characters database (mod_stellar_tarot_account_card,
 * mod_stellar_tarot_account_board) and is read from there: studying is a rare
 * gesture, and the interface reads the same rows, so nothing is cached that
 * could drift. Writes are SYNCHRONOUS, so what the Lua reads back right after
 * a command is what the command wrote.
 */

#ifndef MOD_STELLAR_TAROT_BINDER_H_
#define MOD_STELLAR_TAROT_BINDER_H_

#include "Define.h"
#include <vector>

class Player;

enum class StellarTarotStudyResult : uint8
{
    Ok,
    NotOurs,            // the entry is neither a card nor a board of the module
    NotCarried,         // the player does not carry the item
    AlreadyKnown        // the account already has it in its binder
};

namespace StellarTarotBinder
{
    [[nodiscard]] bool KnowsCard(uint32 accountId, uint32 cardId);
    [[nodiscard]] bool KnowsBoard(uint32 accountId, uint32 boardId);
    [[nodiscard]] std::vector<uint32> Cards(uint32 accountId);
    [[nodiscard]] std::vector<uint32> Boards(uint32 accountId);

    // Studies the item `entry` the player carries: it joins the account's
    // binder and the item is destroyed. `isBoard` and `id` receive what was
    // studied when the answer is Ok or AlreadyKnown.
    StellarTarotStudyResult Study(Player* player, uint32 entry, bool& isBoard, uint32& id);
}

// THE WORKBENCH: three cards become one card drawn at random from the whole
// catalogue, the account's known ones included; three boards likewise.
enum class StellarTarotFuseResult : uint8
{
    Ok,
    NotThreeOfAKind,    // not three cards, nor three boards
    NotCarried,         // the player does not carry them all
    BagFull,
    NothingToDraw       // an empty catalogue
};

namespace StellarTarotFuse
{
    // `crafted` receives the item handed over, `isBoard` what kind it was.
    StellarTarotFuseResult Fuse(Player* player, uint32 a, uint32 b, uint32 c, uint32& crafted, bool& isBoard);
}

#endif
