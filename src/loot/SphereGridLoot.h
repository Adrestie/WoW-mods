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
 * mod-spheregrid — handing out the sphere grid items through loot.
 *
 * The principle: NO row is added to the loot tables of the database. The items
 * are injected on the fly into the loot being filled, and the brackets that say
 * where and at what rate live in the server CODE — neither in the database nor
 * in Lua: nothing that decides a drop should be readable or editable anywhere
 * but in the binary.
 *
 * This is the one deliberate exception to the rule that no figure belongs in the
 * code. Its price is known: rebalancing demands a recompilation.
 *
 * The hook is MiscScript::OnAfterLootTemplateProcess, called by Loot::FillLoot
 * right after the template has been processed and BEFORE group rights and
 * quality thresholds are assigned: an item added there is indistinguishable from
 * one that came out of the template.
 */

#ifndef MOD_SPHEREGRID_LOOT_H_
#define MOD_SPHEREGRID_LOOT_H_

#include "Define.h"

class Creature;
class GameObject;
class Loot;
class LootStore;
class Player;

// What a game object is to us. The "game object" loot store actually covers
// three very different things, which have to be told apart.
enum SphereGridGobKind : uint8
{
    SPHEREGRID_GOB_OTHER = 0,
    SPHEREGRID_GOB_GATHERING,        // a vein or a herb: a profession lock
    SPHEREGRID_GOB_FISHING_POOL,     // a fishing pool
    SPHEREGRID_GOB_CHEST             // a treasure chest
};

// What the source of the loot says about itself. Not every field is filled for
// every source: a fishing pool has no level, a vein has no rank. Each bracket
// only reads what concerns it.
struct SphereGridLootSource
{
    Player*     player      = nullptr;
    Creature*   creature    = nullptr;  // the monster killed, or the beast skinned
    GameObject* gob         = nullptr;  // vein, herb, pool, chest

    uint32 level      = 0;              // the actual level of the creature
    uint8  rank       = 0;              // CreatureEliteType
    bool   boss       = false;          // dungeon boss or world boss
    uint32 map        = 0;
    uint32 zone       = 0;
    uint32 expansion  = 0;              // Map.dbc: 0 vanilla, 1 BC, 2 WotLK
    bool   dungeon    = false;
    bool   raid       = false;
    bool   heroic     = false;

    uint8  gobKind    = SPHEREGRID_GOB_OTHER;
    uint32 profession = 0;              // LOCKTYPE_HERBALISM or LOCKTYPE_MINING
    uint32 skill      = 0;              // skill required; 0 = no requirement
};

// Called for EVERY loot filled, whatever its nature. It filters on the loot
// store itself (creature, fishing, gathering, skinning) and does nothing for the
// others.
void SphereGridFillLoot(Loot* loot, LootStore const& store, Player* player);

// BAD-LUCK PROTECTION. Two counters per player, in memory only: every WORLD
// monster killed without a Nexus raises the chance of the next one, every RAID
// BOSS killed without a Nexus raises the chance of the next boss by more, and
// either one falls back to zero as soon as a Nexus drops in its own scope.
// Dungeons have none, bosses included.
//
// TO BE CALLED AT LOGOUT: the counters do not outlive the session, by design,
// and without this forgetting the table would grow without end.
void SphereGridForgetPity(Player* player);

#endif
