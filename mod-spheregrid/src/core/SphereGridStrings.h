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
 * mod-spheregrid — message string ids.
 *
 * The texts themselves live in the database: `module_string` (English, the
 * default) and `module_string_locale` (one row per locale), served according to
 * the session locale and falling back to English. They are shipped in
 * data/sql/world.
 *
 * Every id used here MUST exist there: the core logs an error and returns the
 * literal "error" for a missing one.
 */

#ifndef MOD_SPHEREGRID_STRINGS_H_
#define MOD_SPHEREGRID_STRINGS_H_

#include "Define.h"

constexpr char SPHEREGRID_MODULE[] = "mod-spheregrid";

enum SphereGridStrings : uint32
{
    SPHEREGRID_STR_INFO_HEADER        = 1,
    SPHEREGRID_STR_INFO_CLASS        = 2,
    // 3 and 4 (cost table, cost bracket) are retired. Ids are never reused:
    // they live in the database, where an old row could still carry them.
    SPHEREGRID_STR_INFO_SOURCE_COUNT        = 5,     // {} point sources
    SPHEREGRID_STR_INFO_SOURCE_LINE        = 6,
    SPHEREGRID_STR_RELOAD_OK          = 7,
    SPHEREGRID_STR_PLAYER_NOT_FOUND = 8,
    SPHEREGRID_STR_STATUS_POINTS      = 9,
    SPHEREGRID_STR_STATUS_ACTIVE      = 10,
    SPHEREGRID_STR_NO_STATE_FOR     = 11,
    SPHEREGRID_STR_POINTS_USAGE       = 12,
    SPHEREGRID_STR_POINTS_TARGET       = 13,
    SPHEREGRID_STR_POINTS_HELP_ADD    = 14,
    SPHEREGRID_STR_POINTS_HELP_REMOVE = 15,
    SPHEREGRID_STR_POINTS_HELP_SET    = 16,
    SPHEREGRID_STR_POINTS_ADDED     = 17,
    SPHEREGRID_STR_POINTS_REMOVED      = 18,
    SPHEREGRID_STR_POINTS_SET       = 19,
    SPHEREGRID_STR_ACTIVATE_OK          = 20,
    SPHEREGRID_STR_NO_STATE_SELF    = 21,
    SPHEREGRID_STR_ACT_UNKNOWN        = 22,
    SPHEREGRID_STR_ACT_WRONG_CLASS         = 23,
    SPHEREGRID_STR_ACT_ALREADY           = 24,
    SPHEREGRID_STR_ACT_NOT_ADJACENT   = 25,
    SPHEREGRID_STR_ACT_NOT_ENOUGH    = 26,
    SPHEREGRID_STR_RESET_OK           = 27,
    SPHEREGRID_STR_SHOW_FALLBACK         = 28,
    SPHEREGRID_STR_EDITOR_FALLBACK       = 29,
    SPHEREGRID_STR_GAIN_GENERIC        = 30,
    SPHEREGRID_STR_LOSS_GENERIC       = 31,
    SPHEREGRID_STR_SET_GENERIC        = 32,
    SPHEREGRID_STR_SOURCE_UNKNOWN    = 33,
    SPHEREGRID_STR_SOCKETED              = 34,
    SPHEREGRID_STR_UNSOCKETED            = 35,
    SPHEREGRID_STR_SOCKET_NOT_ACTIVE     = 36,
    SPHEREGRID_STR_SOCKET_FILLED        = 37,
    SPHEREGRID_STR_SOCKET_EMPTY          = 38,
    SPHEREGRID_STR_SOCKET_WRONG_KIND  = 39,
    SPHEREGRID_STR_SOCKET_ITEM_MISSING  = 40,
    SPHEREGRID_STR_STATS_HEADER       = 41,
    SPHEREGRID_STR_STATS_LINE        = 42,
    SPHEREGRID_STR_STATS_EMPTY         = 43,
    SPHEREGRID_STR_SOCKET_TOO_MANY_RUNES    = 44,   // three identical runes at most
    // The workbench recipes. They say nothing when they work -- the item is
    // in the bag and a sound has answered -- with one exception: reforging is
    // the only one that draws lots, so it names what came out.
    SPHEREGRID_STR_BENCH_REFORGED   = 45,
    SPHEREGRID_STR_BENCH_NOT_STONE  = 46,
    SPHEREGRID_STR_BENCH_NOT_RUNE    = 47,
    SPHEREGRID_STR_BENCH_EFFECTS      = 48,   // fuse: three times the SAME stone
    SPHEREGRID_STR_BENCH_QUALITIES    = 49,   // reroll: both stones must share a quality
    SPHEREGRID_STR_BENCH_MAX_QUALITY = 50,   // nothing above the last quality
    SPHEREGRID_STR_BENCH_NOTHING        = 51,
    SPHEREGRID_STR_BENCH_ITEM_MISSING      = 52,
    SPHEREGRID_STR_BENCH_BAG_FULL   = 53,
    SPHEREGRID_STR_SOCKET_WRONG_CLASS        = 54,   // rank rune of another class
    SPHEREGRID_STR_WIPEALL_OK         = 55,   // .spheregrid wipeall
    SPHEREGRID_STR_PRISM             = 56,   // prismatic Nexus absorbed: +N %
    SPHEREGRID_STR_STATUS_PRISMS     = 57,   // .spheregrid status: prisms and their boost

    // Bad-luck protection: one message per threshold crossed, never twice for
    // the same one.
    SPHEREGRID_STR_PITY_25           = 58,
    SPHEREGRID_STR_PITY_50           = 59,
    SPHEREGRID_STR_PITY_75           = 60,
    SPHEREGRID_STR_PITY_100          = 61,

    // Grinding: the fourth workbench recipe, the one that returns Spherite
    // instead of an item.
    SPHEREGRID_STR_BENCH_NOT_GRINDABLE = 63,  // neither a stone nor a rune

    // EVERY GAIN SAYS WHERE IT COMES FROM: no single generic message, each
    // source names itself. ALL of these strings take the same two arguments, IN
    // THIS ORDER: {0} the name (empty when there is none), {1} the amount. A
    // string with nothing to name uses {1} only.
    SPHEREGRID_STR_GAIN_LEVEL        = 64,
    SPHEREGRID_STR_GAIN_ACHIEVEMENT     = 65,
    SPHEREGRID_STR_GAIN_BOSS          = 66,
    SPHEREGRID_STR_GAIN_GRIND_STONE = 67,
    SPHEREGRID_STR_GAIN_GRIND_RUNE  = 68,
    SPHEREGRID_STR_GAIN_DUNGEON        = 69,
    SPHEREGRID_STR_GAIN_NEXUS         = 70,
    SPHEREGRID_STR_GAIN_QUEST         = 71,
    SPHEREGRID_STR_GAIN_MYTHIC      = 72,

    // Player-triggered reset: {0} is the Spherite given back.
    SPHEREGRID_STR_RESPEC_OK          = 73
};

#endif
