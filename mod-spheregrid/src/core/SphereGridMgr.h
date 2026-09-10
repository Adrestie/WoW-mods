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
 * mod-spheregrid — the custom talent system known as the sphere grid.
 *
 * In-memory definition, loaded from the world database and reloadable with
 * .spheregrid reload. The vocabulary (node, socket, stone, rune) and the data
 * model are described in docs/CONCEPTION.md, shipped with the module.
 *
 * Guiding principle: no figure in the code, everything lives in the
 * spheregrid_* tables and reloads without a restart.
 */

#ifndef MOD_SPHEREGRID_MGR_H_
#define MOD_SPHEREGRID_MGR_H_

#include "Define.h"
#include <map>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

// How many statistics the catalogue holds. Every stone, every statistic rune and
// every aggregated block is indexed 1..N by it.
constexpr uint8 SPHEREGRID_STAT_COUNT = 16;

// How many qualities a stone comes in, in the order the game uses them.
constexpr uint8 SPHEREGRID_QUALITY_COUNT = 5;

// THE IDENTIFIERS THE MODULE ALLOCATES. They are not settings: an operator has
// no reason to move them, and moving them on a live server would leave every
// grid already played pointing at entries that no longer exist. Adapting them to
// a server that already uses these ranges is the installer's job, and these
// three constants are what it rewrites.
//
//   a stone         = STONE_BASE + (statistic - 1) x qualities + (quality - 1)
//   a node stone    = NODE_STONE_BASE, laid out the same way
//   a statistic rune = STAT_RUNE_BASE + (statistic - 1)
constexpr uint32 SPHEREGRID_STONE_BASE = 803100;
constexpr uint32 SPHEREGRID_NODE_STONE_BASE = 803310;
constexpr uint32 SPHEREGRID_STAT_RUNE_BASE = 803600;
constexpr uint32 SPHEREGRID_PIN_ENTRY = 803300;

// The Nexuses, the items that grant Spherite. Five qualities, plus the
// prismatic one, which boosts every gain instead of granting any.
constexpr uint32 SPHEREGRID_NEXUS_DEPLETED = 803200;
constexpr uint32 SPHEREGRID_NEXUS_FLICKERING = 803201;
constexpr uint32 SPHEREGRID_NEXUS_LUMINOUS = 803202;
constexpr uint32 SPHEREGRID_NEXUS_IRRADIANT = 803203;
constexpr uint32 SPHEREGRID_NEXUS_SOLAR = 803204;
constexpr uint32 SPHEREGRID_NEXUS_PRISMATIC = 803205;

enum SphereGridCellType : uint8
{
    SPHEREGRID_NODE   = 0,     // stone cell — pre-filled, or empty
    SPHEREGRID_SOCKET = 1,     // empty on creation, accepts runes only
    SPHEREGRID_SPELL  = 2      // carries a custom spell, fixed in the grid
};

struct SphereGridCell
{
    uint32 nodeId = 0;
    uint8  classId = 0;
    uint8  kind = SPHEREGRID_NODE;
    float  gridX = 0.0f;
    float  gridY = 0.0f;
    uint32 defaultStoneEntry = 0;       // NODE only, 0 = empty node
    uint32 spellId = 0;                 // SPELL only
    std::vector<uint32> neighbours;     // adjacency, filled from mod_spheregrid_edge
};

// The figures behind a stone: rank in the catalogue of the 16 statistics, and
// amount. Both live in the data, never in the code.
struct SphereGridStone
{
    uint8 statId = 0;
    int32 amount = 0;
    // True for an ITEM stone (an item_template row exists): what the player
    // loots, sockets and fuses. False for a NODE stone, an entry carried only by
    // pre-filled cells — the workbench must never produce one.
    bool isItem = false;
};

// What a rank rune improves. `baseRank` is BLIZZARD's number of ranks: the first
// rune socketed grants rank baseRank + 1, the second the next one, the third the
// last. The custom ranks themselves are found through the spell_ranks chain,
// never recomputed.
struct SphereGridRune
{
    uint32 firstSpellId = 0;
    uint8  baseRank = 0;
    // Only this class may SOCKET it. It drops with no class condition, though —
    // the workbench is what will make it useful.
    uint8  classId = 0;
};

// What a STATISTIC rune boosts. It grants no points of its own: it increases by
// a percentage what the GRID already gives in that statistic. The percentage is
// data, never code, and stacks up to RUNES_PER_SPELL.
struct SphereGridStatRune
{
    uint8  statId = 0;
    uint16 percent = 0;
};

class Map;

class SphereGridMgr
{
public:
    static SphereGridMgr* instance();

    // Reloads the whole definition from the world database. Called at startup
    // (before the world opens) and by .spheregrid reload.
    void Load();

    [[nodiscard]] SphereGridCell const* Cell(uint32 nodeId) const;
    [[nodiscard]] uint32 Start(uint8 classId) const;               // 0 if none
    // SPELLS PER CLASS: on a shared grid, a spell cell teaches each class ITS
    // OWN spell (mod_spheregrid_node_spell); the cell's spell_id stays the
    // "all classes" fallback. 0 when there is nothing.
    [[nodiscard]] uint32 SpellFor(SphereGridCell const& cell, uint8 classId) const;

    // COST BY DISTANCE: the price of a cell does not depend on how many nodes
    // are already active but on its POSITION — its distance in edges from the
    // class start. The start is therefore free, and every step away from it adds
    // COST_PER_STEP, up to COST_CAP. The purchase order has no influence on the
    // total.
    // The distance is the shortest path through the grid VISIBLE to the class (a
    // spell cell with no spell for it does not exist, nor do its edges),
    // computed once at load time by ComputeDistances().
    // Read from the configuration at load time, so `.spheregrid reload` picks up
    // a change. Not constexpr for that very reason.
    static uint32 COST_PER_STEP;
    static uint32 COST_CAP;

    // Distance in edges from the class start. 0 for the start itself,
    // UNKNOWN_DISTANCE when the cell is not connected to it.
    static constexpr uint32 UNKNOWN_DISTANCE = 0xFFFFFFFF;
    [[nodiscard]] uint32 Distance(uint8 classId, uint32 nodeId) const;

    // Activation price of THIS cell for THAT class. A cell not connected to the
    // start is charged the cap: it should not be reachable at all, and Validate()
    // has already reported it at load time.
    [[nodiscard]] uint32 ActivationCost(uint8 classId, uint32 nodeId) const;
    // Looks up (type, value) then falls back to (type, 0), the type's default.
    [[nodiscard]] uint32 PointsForSource(std::string const& type, uint32 value) const;
    // (type, value) with NO fallback: 0 when the row does not exist.
    [[nodiscard]] uint32 ExactPointsForSource(std::string const& type, uint32 value) const;
    // The award for an INSTANCE: exact (type, map x 10 + difficulty + 1), then
    // (type, map x 10) for any difficulty, then — dungeons only — the expansion
    // tier (value < 10: expansion x 3 + difficulty + 1, so 1 vanilla, 4 BC,
    // 5 BC heroic, 7 WotLK, 8 WotLK heroic), then (type, 0).
    [[nodiscard]] uint32 PointsForInstance(std::string const& type, Map const* map) const;
    // A stone's effect, nullptr when the entry is not one.
    [[nodiscard]] SphereGridStone const* Stone(uint32 itemEntry) const;
    // The spell a rune improves, nullptr when the entry is not one.
    [[nodiscard]] SphereGridRune const* Rune(uint32 itemEntry) const;
    // The statistic a rune boosts, nullptr when the entry is not one.
    [[nodiscard]] SphereGridStatRune const* StatRune(uint32 itemEntry) const;
    // Highest number of identical runes allowed in a single grid.
    static uint8 RUNES_PER_SPELL;

    // HOW OFTEN EACH OBJECT DROPS, as a factor on the rate the loot brackets
    // write: 1 leaves it as written, 0 turns the object off, 2 doubles it.
    // One value per Nexus, one per stone quality, one for the runes -- read
    // from the configuration as percentages, like everything an operator
    // tunes, and reloaded with it. An entry that is not a Nexus, or a quality
    // out of range, answers 1: the brackets never asked for something the
    // configuration does not name.
    [[nodiscard]] float NexusDropFactor(uint32 itemEntry) const;
    [[nodiscard]] float StoneDropFactor(uint8 quality) const;     // 1..5
    [[nodiscard]] float RuneDropFactor() const { return _runeDropFactor; }
    [[nodiscard]] uint32 PinEntry() const { return SPHEREGRID_PIN_ENTRY; }

    [[nodiscard]] std::unordered_map<uint32, SphereGridCell> const& Cells() const { return _cells; }
    [[nodiscard]] std::map<uint8, uint32> const& Starts() const { return _starts; }
    [[nodiscard]] std::map<std::pair<uint32, uint8>, uint32> const& ClassSpells() const { return _classSpells; }
    [[nodiscard]] std::map<std::pair<std::string, uint32>, uint32> const& PointSources() const { return _pointSources; }
    [[nodiscard]] uint32 EdgeCount() const { return _edgeCount; }
    // The workbench needs the catalogues WHOLE: it looks for "the stone of the
    // same statistic whose amount is just above", or draws a rune at random
    // among all of them.
    [[nodiscard]] std::unordered_map<uint32, SphereGridStone> const& Stones() const { return _stones; }
    [[nodiscard]] std::unordered_map<uint32, SphereGridRune> const& Runes() const { return _runes; }
    [[nodiscard]] std::unordered_map<uint32, SphereGridStatRune> const& StatRunes() const { return _statRunes; }

private:
    SphereGridMgr() = default;

    // Integrity checks after loading: starts, node/stone consistency, pieces not
    // connected to the start. Reported through LOG_WARN, never blocking.
    void Validate() const;

    // Reads the awards, the stones and the statistic runes from the module
    // configuration. Called by Load(), so `.spheregrid reload` picks up a
    // changed configuration as well.
    void LoadFromConfig();

    // Breadth-first search from each class start, over the grid it can see.
    // Called by Load(), before Validate().
    void ComputeDistances();

    std::unordered_map<uint32, SphereGridCell> _cells;
    std::map<uint8, uint32> _starts;                                // class_id -> node_id
    // class_id -> (node_id -> distance in edges from the start)
    std::map<uint8, std::unordered_map<uint32, uint32>> _distances;
    std::map<std::pair<uint32, uint8>, uint32> _classSpells;        // (node_id, class_id) -> spell_id
    std::map<std::pair<std::string, uint32>, uint32> _pointSources;
    std::map<uint32, float> _nexusDropFactors;                      // item_entry -> factor
    float _stoneDropFactors[SPHEREGRID_QUALITY_COUNT] = { 1, 1, 1, 1, 1 };
    float _runeDropFactor = 1.0f;
    std::unordered_map<uint32, SphereGridStone> _stones;            // item_entry -> effect
    std::unordered_map<uint32, SphereGridRune> _runes;              // item_entry -> spell
    std::unordered_map<uint32, SphereGridStatRune> _statRunes;      // item_entry -> statistic
    uint32 _edgeCount = 0;
};

#define sSphereGridMgr SphereGridMgr::instance()

#endif
