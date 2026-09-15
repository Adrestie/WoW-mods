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
 * mod-stellar-tarot — message string ids.
 *
 * The texts themselves live in the database: `module_string` (English, the
 * default) and `module_string_locale` (one row per locale), served according to
 * the session locale and falling back to English. They are shipped in
 * data/sql/world/stellar_tarot_02_strings.sql.
 *
 * Every id used here MUST exist there: the core logs an error and returns the
 * literal "error" for a missing one. Ids are never reused once retired.
 */

#ifndef MOD_STELLAR_TAROT_STRINGS_H_
#define MOD_STELLAR_TAROT_STRINGS_H_

#include "Define.h"

constexpr char STELLAR_TAROT_MODULE[] = "mod-stellar-tarot";

enum StellarTarotStrings : uint32
{
    STELLAR_TAROT_STR_INFO_HEADER       = 1,   // {} card(s), {} board(s), {} tag(s)
    STELLAR_TAROT_STR_INFO_CARD         = 2,   // one card
    STELLAR_TAROT_STR_INFO_BOARD        = 3,   // one board
    STELLAR_TAROT_STR_RELOAD_OK         = 4,
    STELLAR_TAROT_STR_DISABLED          = 5,
    // The binder
    STELLAR_TAROT_STR_STUDY_NOT_OURS    = 6,   // item {} is neither a card nor a board
    STELLAR_TAROT_STR_STUDY_NOT_CARRIED = 7,   // you do not carry {}
    STELLAR_TAROT_STR_STUDY_KNOWN       = 8,   // already known: {}
    STELLAR_TAROT_STR_STUDY_OK          = 9,   // {} joins your binder
    STELLAR_TAROT_STR_BINDER_HEADER     = 10,  // {}'s binder: {} card(s), {} board(s)
    STELLAR_TAROT_STR_BINDER_CARDS      = 11,  //   cards: {}
    STELLAR_TAROT_STR_BINDER_BOARDS     = 12,  //   boards: {}
    STELLAR_TAROT_STR_PLAYER_NOT_FOUND  = 13,
    // The layout
    STELLAR_TAROT_STR_BOARD_UNKNOWN     = 14,  // board {} does not exist
    STELLAR_TAROT_STR_BOARD_NOT_KNOWN   = 15,  // your account does not own {}
    STELLAR_TAROT_STR_BOARD_EQUIPPED    = 16,  // {} equipped, cards taken off
    STELLAR_TAROT_STR_BOARD_REMOVED     = 17,  // no board, cards taken off
    STELLAR_TAROT_STR_NO_BOARD          = 18,
    STELLAR_TAROT_STR_OUT_OF_BOUNDS     = 19,  // no cell {},{}
    STELLAR_TAROT_STR_CELL_TAKEN        = 20,
    STELLAR_TAROT_STR_CELL_EMPTY        = 21,
    STELLAR_TAROT_STR_CARD_UNKNOWN      = 22,  // card {} does not exist
    STELLAR_TAROT_STR_CARD_NOT_KNOWN    = 23,  // your account does not know {}
    STELLAR_TAROT_STR_CARD_TWICE        = 24,  // {} is already on the board
    STELLAR_TAROT_STR_PLACED            = 25,  // {} laid on {},{}
    STELLAR_TAROT_STR_REMOVED           = 26,  // {} taken off {},{}
    STELLAR_TAROT_STR_CLEARED           = 27,
    STELLAR_TAROT_STR_PRESET_SAVED      = 28,  // "{}" saved, {} card(s)
    STELLAR_TAROT_STR_PRESET_UNKNOWN    = 29,  // no preset {}
    STELLAR_TAROT_STR_PRESET_LOADED     = 30,  // "{}" loaded: {} laid, {} skipped
    STELLAR_TAROT_STR_PRESET_DELETED    = 31,  // "{}" deleted
    STELLAR_TAROT_STR_PRESET_NAME       = 32,  // 1 to 32 characters
    STELLAR_TAROT_STR_LAYOUT_HEADER     = 33,  // {}'s board: {} ({}x{}), {} card(s)
    STELLAR_TAROT_STR_LAYOUT_CELL       = 34,  //   {},{}: {} level {} ({})
    // The effects
    STELLAR_TAROT_STR_EFFECTS_HEADER    = 35,  // {}'s active effects: {}
    STELLAR_TAROT_STR_EFFECTS_LINE      = 36,  //   {} level {}: spell {}, script {}
    STELLAR_TAROT_STR_INFO_REFUSED      = 37,  //   card {} REFUSED: {}
    STELLAR_TAROT_STR_INFO_CARD_LEVELS  = 38,  //     {} - 1: {} | 2: {} | 3: {} | 4: {}
    STELLAR_TAROT_STR_INFO_SCRIPTS      = 39,  // scripts: {}
    // The workbench
    STELLAR_TAROT_STR_FUSE_NOT_THREE    = 40,  // three cards, or three boards
    STELLAR_TAROT_STR_FUSE_NOT_CARRIED  = 41,
    STELLAR_TAROT_STR_FUSE_BAG_FULL     = 42,
    STELLAR_TAROT_STR_FUSE_NOTHING      = 43,  // nothing to draw
    STELLAR_TAROT_STR_FUSE_OK           = 44,  // the three become {}
    // The loot sources
    STELLAR_TAROT_STR_SOURCES_HEADER    = 45,  // {} source(s); loot {}, rate {} %, known items {}
    STELLAR_TAROT_STR_SOURCES_LINE      = 46,  //   #{}: {}
    STELLAR_TAROT_STR_SOURCES_NONE      = 47,
    // Replacing, moving, swapping
    STELLAR_TAROT_STR_REPLACED          = 48,  // {} takes the place of {} on {},{}
    STELLAR_TAROT_STR_MOVED             = 49,  // {} moved to {},{}
    STELLAR_TAROT_STR_SWAPPED           = 50,  // {} and {} swap places
    // What a card says of itself, in the chat, as it happens
    STELLAR_TAROT_STR_BINGO             = 51,  // Bingo! You get {}g {}s {}c
    STELLAR_TAROT_STR_JACKPOT           = 52,  // a purse full of coin: the loot was multiplied by more than two
    STELLAR_TAROT_STR_LUCKY             = 53,  // Lucky! You have found {}g {}s {}c
    STELLAR_TAROT_STR_REBATE            = 54,  // the vendor gives part of the price back
    STELLAR_TAROT_STR_SPOILS            = 55,  // coin found on the victim
    STELLAR_TAROT_STR_FROM_CARD         = 56,  // [{card}] : {what it says}
    STELLAR_TAROT_STR_QUEST_GOLD        = 57,  // quest reward increased by {}g {}s {}c
    // 1001 and up: what each script says of itself (mod_stellar_tarot_script).
};

#endif
