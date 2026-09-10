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
 * mod-spheregrid — the sphere grid state of the characters.
 *
 * Rules: activation spreads step by step from the class start; the price comes
 * from the DISTANCE in edges from that start (SphereGridMgr::ActivationCost);
 * activating a node applies its pre-filled stone, activating a socket produces
 * nothing until a rune is set in it.
 *
 * Bots have no state at all: they are set aside at login and never earn points.
 * On a server running thousands of them, walking their spell books at every
 * reset is enough to freeze the world.
 */

#ifndef MOD_SPHEREGRID_PLAYER_MGR_H_
#define MOD_SPHEREGRID_PLAYER_MGR_H_

#include "Define.h"
#include "ObjectGuid.h"
#include "SphereGridMgr.h"            // SPHEREGRID_STAT_COUNT
#include "SphereGridStrings.h"        // the default value of `text` below
#include <array>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>

class Creature;
class Map;
class Player;
class Quest;
struct AchievementEntry;

// The name of an item IN THE PLAYER'S OWN LANGUAGE, empty when the entry is
// unknown. Used by the origin messages: a stone ground, a Nexus consumed.
std::string SphereGridItemName(Player const* player, uint32 entry);
// The title of a quest in the player's language. GetTitle alone would return the
// SERVER default locale, the same one for everybody.
std::string SphereGridQuestName(Player const* player, Quest const* quest);

struct SphereGridPlayerState
{
    uint32 earned = 0;
    uint32 spent = 0;
    // PRISMATIC NEXUSES absorbed by the ACCOUNT: each one boosts every Spherite
    // gain, with no cap.
    uint32 prisms = 0;
    // node_id -> { entry of the applied item (the node stone, 0 for an empty
    // socket), upgrade level (runes) }
    std::unordered_map<uint32, std::pair<uint32, uint8>> actives;
    // THE CONTENT OF STONE NODES BELONGS TO THE ACCOUNT: what one character of
    // the account put there, or emptied (0), holds for all of them.
    // node_id -> { entry, upgrade }; absent = the node's original stone. Sockets
    // and spell cells stay per character.
    std::unordered_map<uint32, std::pair<uint32, uint8>> accountContent;
    // CELLS GIVEN BACK BY A RESET: the player handed his whole grid back and got
    // his Spherite returned, but the stone or the rune a cell carried did NOT
    // leave that cell. The row survives in the database with active = 0; we keep
    // here what it carries, to hand it back untouched at the next purchase.
    // node_id -> { entry, upgrade }.
    std::unordered_map<uint32, std::pair<uint32, uint8>> inactiveContent;
    // Spell cells whose spell was FORGOTTEN with the pin: those demand a new
    // purchase. A spell cell at 0 that is not in here was bought before the class
    // had a spell for it: it learns it without paying again, as soon as it
    // exists.
    std::unordered_set<uint32> forgotten;

    [[nodiscard]] uint32 Available() const { return earned > spent ? earned - spent : 0; }
};

enum class SphereGridActivation : uint8
{
    Ok,
    NoState,                // state not loaded: a bot, or offline
    UnknownCell,
    WrongClass,
    AlreadyActive,
    NotAdjacent,
    NotEnoughPoints
};

enum class SphereGridSocketing : uint8
{
    Ok,
    NoState,
    UnknownCell,
    NotActive,              // the cell has not been bought yet
    AlreadyFilled,
    WrongKind,              // a stone in a socket, a rune in a node...
    ItemMissing,            // the player does not carry the item
    TooManyRunes,           // three identical runes are already socketed
    WrongClass              // a rank rune of another class
};

// Aggregated statistic block: the index is the rank in the catalogue of the 16
// statistics (1..16), slot 0 staying unused. The count itself belongs to the
// definition, and lives in SphereGridMgr.h.
using SphereGridStatBlock = std::array<int32, SPHEREGRID_STAT_COUNT + 1>;

class SphereGridPlayerMgr
{
public:
    static SphereGridPlayerMgr* instance();

    void Load(Player* player);       // login (bots are set aside)
    void Unload(Player* player);     // logout

    [[nodiscard]] SphereGridPlayerState* State(Player* player);

    SphereGridActivation Activate(Player* player, uint32 nodeId);
    // EVERY GAIN SAYS WHERE IT COMES FROM. `text` is the id of the string
    // announced to the player, `name` what it quotes — a boss, a quest, a stone.
    // All those strings take {0} the name then {1} the amount; the ones with
    // nothing to quote use {1} only and leave `name` empty.
    //
    // The default stays the generic message: a caller that says nothing keeps
    // working, without lying about where the points came from.
    bool AddPoints(Player* player, uint32 amount,
                       uint32 text = SPHEREGRID_STR_GAIN_GENERIC,
                       std::string const& name = "");        // false if no state
    // A Spherite GAIN (loot, boss, dungeon, Nexus): boosted by the account
    // prisms, then AddPoints. The game master tools add raw amounts.
    bool Earn(Player* player, uint32 amount,
                uint32 text = SPHEREGRID_STR_GAIN_GENERIC,
                std::string const& name = "");
    // What a gain will be worth once boosted by the account prisms.
    [[nodiscard]] uint32 Boosted(Player* player, uint32 amount);
    // A prismatic Nexus absorbed: one more prism on the account.
    bool AbsorbPrism(Player* player);
    // Removes up to `amount` available points (capped, never negative);
    // `removed` receives what was actually debited. False if no state.
    bool RemovePoints(Player* player, uint32 amount, uint32& removed);
    // Sets the AVAILABLE points to `available` (earned = spent + N).
    bool SetPoints(Player* player, uint32 available);
    void CreditBoss(Player* killer, Creature* creature);   // whole group, same map
    // Credits the award of a content source (the settings read into
    // _pointSources, falling back on value 0 of the type). False when the award or the state is
    // missing. This is the entry point for other systems, either calling it
    // directly or going through the console command `.spheregrid points source`.
    bool CreditSource(Player* player, std::string const& type, uint32 value,
                        uint32 text = SPHEREGRID_STR_GAIN_GENERIC,
                        std::string const& name = "");
    // The award of an INSTANCE, by map, difficulty and expansion tier
    // (SphereGridMgr::PointsForInstance): a dungeon completed.
    bool CreditInstance(Player* player, std::string const& type, Map const* map);
    // A LEVEL GAINED awards "points x the new level" of Spherite, where `points`
    // is the (level, 0) row (10: level 2 is worth 20). Every level crossed at
    // once is counted. With no row, nothing. Boosted by the prisms like any
    // source.
    bool CreditLevel(Player* player, uint8 oldLevel);
    // An ACHIEVEMENT awards "its own score x the multiplier", the multiplier
    // being the (achievement, 0) row. The score comes from AchievementEntry::points:
    // the difficulty hierarchy is Blizzard's, nothing to enter by hand.
    //
    // ANTI-REROLL: a module granting account-wide achievements gives every
    // character all the achievements of the account, by calling
    // CompletedAchievement — so our hook fires for those too. We only credit when
    // NO OTHER character of the account already owns it.
    bool CreditAchievement(Player* player, AchievementEntry const* achievement);
    void Reset(Player* player);                     // game master tool: full wipe
    // EVERY SPELL THE GRID TAUGHT THIS CHARACTER, taken back. The state is what
    // says which: a spell cell keeps in its content the spell it granted.
    // `Recompute` never removes anything -- it only learns what the active
    // cells ask for -- so a reset that merely emptied the state left the
    // spells in the book with no cell left to justify them.
    static void ForgetSpells(Player* player, SphereGridPlayerState const& state);
    // Every spell a spell cell can teach, as an SQL list: what reaches the
    // characters of an account who are not connected.
    static std::string TaughtSpellList();
    // PLAYER-TRIGGERED RESET: this character hands every one of its cells back
    // and recovers the Spherite it had spent on them. The stones and runes
    // socketed STAY in their cells; the spells taught by a spell cell are
    // forgotten, as with the pin — without that, the refund would be a gift. What
    // was earned belongs to the account: untouched. Returns the refunded amount.
    uint32 ResetProgression(Player* player);
    // The WHOLE account: earned Spherite erased and every grid of every one of
    // its characters reset. Returns the number of characters touched.
    uint32 WipeAccount(Player* player);

    // --- the effects -------------------------------------------------------
    // TOTAL recomputation, never incremental: every active cell is summed again,
    // the previous block is removed, the new one applied. Called at login and on
    // every activation, socketing and use of the pin.
    void Recompute(Player* player);
    [[nodiscard]] SphereGridStatBlock const* StatBlock(Player* player) const;

    // The extra ranks granted by runes. Called by Recompute, and by the talent
    // hooks: a talent lost must disable its runes WITHOUT the player having to
    // open anything.
    void SyncRunes(Player* player, SphereGridPlayerState const& state);
    void SyncRunes(Player* player);         // from the loaded state

    SphereGridSocketing Socket(Player* player, uint32 nodeId, uint32 itemEntry);
    // Empties the cell: the stone or the rune is DESTROYED. On a spell cell, the
    // spell is forgotten but stays in the grid.
    SphereGridSocketing Unsocket(Player* player, uint32 nodeId, bool consumePin = true);

private:
    SphereGridPlayerMgr() = default;

    std::unordered_map<ObjectGuid, SphereGridPlayerState> _states;
    // The last block APPLIED to each player: that is what gets removed before
    // applying again, otherwise the bonuses would stack at every recomputation.
    std::unordered_map<ObjectGuid, SphereGridStatBlock> _statBlocks;
    // The custom ranks currently known thanks to the runes, per player: those are
    // what gets removed when a rune stops applying.
    std::unordered_map<ObjectGuid, std::unordered_set<uint32>> _grantedRanks;
};

#define sSphereGridPlayerMgr SphereGridPlayerMgr::instance()

#endif
