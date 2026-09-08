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
 * mod-spheregrid — loading and checking the definition.
 */

#include "SphereGridMgr.h"
#include "Config.h"
#include "Tokenize.h"
#include "DatabaseEnv.h"
#include "Field.h"
#include "Log.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "QueryResult.h"

#include <algorithm>
#include <deque>
#include <unordered_map>
#include <vector>
#include <unordered_set>

uint32 SphereGridMgr::COST_PER_STEP = 75;
uint32 SphereGridMgr::COST_CAP = 2500;
uint8 SphereGridMgr::RUNES_PER_SPELL = 3;

SphereGridMgr* SphereGridMgr::instance()
{
    static SphereGridMgr instance;
    return &instance;
}

void SphereGridMgr::Load()
{
    _cells.clear();
    _starts.clear();
    _distances.clear();
    _pointSources.clear();
    _stones.clear();
    _runes.clear();
    _statRunes.clear();
    _classSpells.clear();
    _edgeCount = 0;

    if (QueryResult result = WorldDatabase.Query(
        "SELECT node_id, class_id, kind, grid_x, grid_y, stone_stat, stone_quality, spell_id FROM mod_spheregrid_node"))
    {
        do
        {
            Field* f = result->Fetch();
            SphereGridCell e;
            e.nodeId  = f[0].Get<uint32>();
            e.classId = f[1].Get<uint8>();
            e.kind    = f[2].Get<uint8>();
            e.gridX   = f[3].Get<float>();
            e.gridY   = f[4].Get<float>();
            // THE GRID SAYS WHAT THE DESIGNER CHOSE, not what follows from it: a
            // statistic and a quality. The entry is computed from the allocation,
            // so moving the base moves every pre-filled stone with it, and no row
            // of the shipped grid has to be rewritten.
            uint8 const stat = f[5].Get<uint8>();
            uint8 const quality = f[6].Get<uint8>();
            e.defaultStoneEntry = (stat && quality)
                ? SPHEREGRID_NODE_STONE_BASE + (stat - 1) * SPHEREGRID_QUALITY_COUNT + (quality - 1)
                : 0;
            e.spellId = f[7].Get<uint32>();
            _cells[e.nodeId] = std::move(e);
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query("SELECT class_id, node_a, node_b FROM mod_spheregrid_edge"))
    {
        do
        {
            Field* f = result->Fetch();
            uint8 classId = f[0].Get<uint8>();
            uint32 a = f[1].Get<uint32>();
            uint32 b = f[2].Get<uint32>();

            auto itA = _cells.find(a);
            auto itB = _cells.find(b);
            if (a == b || itA == _cells.end() || itB == _cells.end()
                || itA->second.classId != classId || itB->second.classId != classId)
            {
                LOG_WARN("module", "SphereGrid: invalid edge ignored (class {}, {} - {}).", classId, a, b);
                continue;
            }

            itA->second.neighbours.push_back(b);
            itB->second.neighbours.push_back(a);
            ++_edgeCount;
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query("SELECT class_id, node_id FROM mod_spheregrid_start"))
    {
        do
        {
            Field* f = result->Fetch();
            _starts[f[0].Get<uint8>()] = f[1].Get<uint32>();
        } while (result->NextRow());
    }

    // SPELLS PER CLASS: a shared grid places its spell cells at fixed
    // positions; each class learns its own there.
    if (QueryResult result = WorldDatabase.Query("SELECT node_id, class_id, spell_id FROM mod_spheregrid_node_spell"))
    {
        do
        {
            Field* f = result->Fetch();
            _classSpells[{ f[0].Get<uint32>(), f[1].Get<uint8>() }] = f[2].Get<uint32>();
        } while (result->NextRow());
    }

    // The awards, the stones and the statistic runes are CONFIGURATION, not data:
    // they are a handful of numbers an operator tunes, not a catalogue. See
    // LoadFromConfig below.
    LoadFromConfig();

    if (QueryResult result = WorldDatabase.Query(
        "SELECT item_entry, first_spell_id, base_rank, class_id FROM mod_spheregrid_rune"))
    {
        do
        {
            Field* f = result->Fetch();
            SphereGridRune r;
            r.firstSpellId = f[1].Get<uint32>();
            r.baseRank = f[2].Get<uint8>();
            r.classId = f[3].Get<uint8>();
            _runes[f[0].Get<uint32>()] = r;
        } while (result->NextRow());
    }

    uint32 nodes = 0, sockets = 0, spells = 0;
    for (auto const& [id, e] : _cells)
    {
        if (e.kind == SPHEREGRID_NODE)      ++nodes;
        else if (e.kind == SPHEREGRID_SOCKET)  ++sockets;
        else if (e.kind == SPHEREGRID_SPELL)  ++spells;
    }

    LOG_INFO("module", "SphereGrid: {} cells ({} nodes, {} sockets, {} spell cells), {} edges, {} start(s), "
        "{} stone(s), {} rank rune(s), {} statistic rune(s), "
        "{} point source(s).",
        _cells.size(), nodes, sockets, spells, _edgeCount, _starts.size(),
        _stones.size(), _runes.size(), _statRunes.size(), _pointSources.size());

    ComputeDistances();
    Validate();
}

// COST BY DISTANCE. One breadth-first search per class, from its start, over
// the grid it can SEE — the same rule as Validate(): a spell cell with no spell
// for the class does not exist for it, nor do its edges, so the search does not
// go through it. Whatever is not reached stays out of the table and will be
// charged at the cap.
namespace
{
    // A comma separated list of numbers, as the configuration writes them. Only
    // the lists of MAPS use it: everywhere a concept has a name, it gets a
    // setting of its own.
    std::vector<uint32> Numbers(std::string const& raw)
    {
        std::vector<uint32> out;
        for (std::string_view piece : Acore::Tokenize(raw, ',', false))
            out.push_back(uint32(atoi(std::string(piece).c_str())));
        return out;
    }

    std::string Option(std::string const& key, std::string const& fallback)
    {
        return sConfigMgr->GetOption<std::string>(key, fallback, false);
    }

    uint32 Number(std::string const& key, uint32 fallback)
    {
        return sConfigMgr->GetOption<uint32>(key, fallback, false);
    }

    // THE FIVE QUALITIES, in the order the game uses them — a stone of quality 1
    // is common, one of quality 5 legendary. The names are what an operator
    // reads in the configuration, and their ORDER is what maps them onto the
    // entries.
    constexpr char const* QUALITIES[SPHEREGRID_QUALITY_COUNT] = {
        "Common", "Uncommon", "Rare", "Epic", "Legendary"
    };

    // THE DUNGEON TIERS. The tier of a dungeon is computed from its map, as
    // expansion x 3 + difficulty + 1; each of those numbers has a name here, and
    // that name is the setting an operator writes.
    struct DungeonTier { char const* name; uint32 tier; };
    constexpr DungeonTier DUNGEON_TIERS[] = {
        { "Vanilla", 1 }, { "Bc", 4 }, { "BcHeroic", 5 },
        { "Wotlk", 7 }, { "WotlkHeroic", 8 }
    };

    // The raid tiers, in the order the configuration declares them. A server
    // with content of its own adds its maps to one of them.
    constexpr char const* RAID_TIERS[] = {
        "Vanilla", "Bc", "Tier7", "Tier8", "Tier9",
        "Tier10", "Tier10Hc", "Tier25", "Tier25Hc"
    };
}

// EVERYTHING AN OPERATOR TUNES COMES FROM THE CONFIGURATION, and nothing else
// does. The awards used to live in a table of 94 rows, the stones in one of 160
// and the statistic runes in one of 16 — but those tables were the expansion of
// a handful of numbers: the statistic of a stone is written in its entry, and
// its amount comes from its quality alone.
//
// ONE SETTING PER NAMED CONCEPT. A quality has a name, so it has a setting;
// a dungeon tier has a name, so it has a setting. Only the lists of maps stay
// lists, because a map is not a concept — it is content, and a server adds its
// own.
//
// The in-memory shape does not change: the awards are still (type, value) pairs,
// so every lookup that reads them is untouched.
void SphereGridMgr::LoadFromConfig()
{
    // --- what a stone grants ------------------------------------------------
    auto layStones = [&](uint32 base, char const* prefix, uint32 const* defaults)
    {
        for (uint8 stat = 1; stat <= SPHEREGRID_STAT_COUNT; ++stat)
            for (uint8 q = 0; q < SPHEREGRID_QUALITY_COUNT; ++q)
            {
                uint32 const entry = base + (stat - 1) * SPHEREGRID_QUALITY_COUNT + q;
                SphereGridStone stone;
                stone.statId = stat;
                stone.amount = int32(Number(std::string(prefix) + QUALITIES[q], defaults[q]));
                // An ITEM stone is one the player can hold; a node stone exists
                // only in this computation, and the workbench must never make one.
                stone.isItem = sObjectMgr->GetItemTemplate(entry) != nullptr;
                _stones[entry] = stone;
            }
    };
    constexpr uint32 STONE_DEFAULTS[] = { 5, 7, 10, 15, 30 };
    constexpr uint32 NODE_DEFAULTS[] = { 1, 2, 3, 5, 7 };
    layStones(SPHEREGRID_STONE_BASE, "SphereGrid.Stone.StatBonus.", STONE_DEFAULTS);
    layStones(SPHEREGRID_NODE_STONE_BASE, "SphereGrid.NodeStone.StatBonus.", NODE_DEFAULTS);

    // --- what a statistic rune boosts ---------------------------------------
    uint16 const statRunePct = uint16(Number("SphereGrid.StatRune.Percent", 10));
    for (uint8 stat = 1; stat <= SPHEREGRID_STAT_COUNT; ++stat)
    {
        SphereGridStatRune rune;
        rune.statId = stat;
        rune.percent = statRunePct;
        _statRunes[SPHEREGRID_STAT_RUNE_BASE + stat - 1] = rune;
    }

    // --- what the content awards --------------------------------------------
    // They keep the (type, value) shape the lookups expect: a single value goes
    // to value 0, the default of its type.
    _pointSources[{ "quest", 0 }] = Number("SphereGrid.Points.Quest", 25);
    _pointSources[{ "level", 0 }] = Number("SphereGrid.Points.Level", 10);
    _pointSources[{ "achievement", 0 }] = Number("SphereGrid.Points.Achievement", 10);
    _pointSources[{ "grind_rune", 0 }] = Number("SphereGrid.Points.Grind.Rune", 750);

    constexpr uint32 GRIND_DEFAULTS[] = { 100, 250, 500, 1000, 2500 };
    for (uint8 q = 0; q < SPHEREGRID_QUALITY_COUNT; ++q)
        _pointSources[{ "grind_stone", uint32(q) + 1 }] =
            Number(std::string("SphereGrid.Points.Grind.Stone.") + QUALITIES[q], GRIND_DEFAULTS[q]);

    // Dungeons: the tier is computed from the map, so only the prices are here.
    struct { char const* type; char const* prefix; uint32 const* defaults; }
    const dungeons[] = {
        { "dungeon_boss",  "SphereGrid.Points.DungeonBoss.",  nullptr },
        { "dungeon_clear", "SphereGrid.Points.DungeonClear.", nullptr },
    };
    constexpr uint32 BOSS_DEFAULTS[] = { 75, 100, 125, 125, 150 };
    constexpr uint32 CLEAR_DEFAULTS[] = { 50, 75, 100, 125, 150 };
    for (size_t d = 0; d < 2; ++d)
    {
        uint32 const* defaults = d == 0 ? BOSS_DEFAULTS : CLEAR_DEFAULTS;
        for (size_t i = 0; i < std::size(DUNGEON_TIERS); ++i)
            _pointSources[{ dungeons[d].type, DUNGEON_TIERS[i].tier }] =
                Number(std::string(dungeons[d].prefix) + DUNGEON_TIERS[i].name, defaults[i]);
        _pointSources[{ dungeons[d].type, 0 }] =
            Number(std::string(dungeons[d].prefix) + "Unknown", 1234);
    }

    // Raids: one price per content tier, and the maps that make up each tier.
    for (char const* tier : RAID_TIERS)
    {
        uint32 const points = Number(std::string("SphereGrid.Points.Raid.") + tier, 0);
        if (!points)
            continue;
        for (uint32 map : Numbers(Option(std::string("SphereGrid.Raid.") + tier + ".Maps", "")))
            _pointSources[{ "raid_boss", map }] = points;
    }
    _pointSources[{ "raid_boss", 0 }] = Number("SphereGrid.Points.Raid.Unknown", 1234);

    // Mythic+ keys: a scale rather than a list. NOTHING IN THE MODULE EVER
    // CREDITS THIS TYPE — an outside system does, by calling
    // `.spheregrid points source mythic_plus <level>`. Without it, these rows sit
    // there and are never read, which costs nothing.
    {
        uint32 const base = Number("SphereGrid.Points.MythicPlus.Base", 150);
        uint32 const step = Number("SphereGrid.Points.MythicPlus.Step", 50);
        uint32 const max = Number("SphereGrid.Points.MythicPlus.Max", 50);
        for (uint32 level = 1; level <= max; ++level)
            _pointSources[{ "mythic_plus", level }] = base + step * level;
    }

    // --- the rules ----------------------------------------------------------
    COST_PER_STEP = Number("SphereGrid.Cost.PerStep", 75);
    COST_CAP = Number("SphereGrid.Cost.Cap", 2500);
    RUNES_PER_SPELL = uint8(Number("SphereGrid.Runes.PerSpell", 3));

    LOG_INFO("module", "SphereGrid: configuration read - {} stone(s), {} statistic rune(s), "
        "{} award(s).", _stones.size(), _statRunes.size(), _pointSources.size());
}

void SphereGridMgr::ComputeDistances()
{
    _distances.clear();

    for (auto const& [classId, start] : _starts)
    {
        auto itStart = _cells.find(start);
        if (itStart == _cells.end())
            continue;   // Validate() reports it

        auto hidden = [&](uint32 nodeId)
        {
            auto it = _cells.find(nodeId);
            if (it == _cells.end())
                return true;
            return it->second.kind == SPHEREGRID_SPELL && !SpellFor(it->second, classId);
        };
        if (hidden(start))
            continue;   // Validate() reports it

        std::unordered_map<uint32, uint32> dist;
        dist[start] = 0;
        std::deque<uint32> queue { start };
        while (!queue.empty())
        {
            uint32 const current = queue.front();
            queue.pop_front();
            uint32 const next = dist[current] + 1;
            for (uint32 neighbour : _cells.at(current).neighbours)
                if (!hidden(neighbour) && dist.emplace(neighbour, next).second)
                    queue.push_back(neighbour);
        }

        uint32 longest = 0;
        for (auto const& [id, d] : dist)
            longest = std::max(longest, d);
        LOG_INFO("module", "SphereGrid: class {} — {} cell(s) reached from start {}, "
            "longest distance {} (cost capped at {}).",
            classId, dist.size(), start, longest, COST_CAP);

        _distances[classId] = std::move(dist);
    }
}

void SphereGridMgr::Validate() const
{
    // The classes present in the grid.
    std::unordered_set<uint8> classes;
    for (auto const& [id, e] : _cells)
    {
        classes.insert(e.classId);

        // An empty node is legal; a socket, on the other hand, never carries a
        // stone, and a spell cell without a spell is a hole in the content.
        if (e.kind == SPHEREGRID_SOCKET && e.defaultStoneEntry)
            LOG_WARN("module", "SphereGrid: socket {} (class {}) carries a pre-filled stone.", id, e.classId);
        else if (e.kind == SPHEREGRID_SPELL)
        {
            // With no spell for a class, the cell is simply invisible to it.
            // With no spell for ANYONE, it exists for nobody: that deserves a
            // word.
            bool useful = e.spellId != 0;
            for (auto const& [classId, nodeId] : _starts)
                if (SpellFor(e, classId))
                    useful = true;
            if (!useful)
                LOG_WARN("module", "SphereGrid: spell cell {} has a spell for no class at all.", id);
        }
    }

    // THE SHARED GRID (class 0): its cells belong to everyone, and its starts
    // are the class starts — one per class, placed on it. A start may therefore
    // aim at a cell of its own class OR of class 0.
    bool const shared = classes.count(0) > 0;
    for (auto const& [classId, nodeId] : _starts)
    {
        auto it = _cells.find(nodeId);
        if (it == _cells.end()
            || (it->second.classId != classId && it->second.classId != 0))
            LOG_WARN("module", "SphereGrid: the start of class {} points at unknown cell {}.", classId, nodeId);
    }

    // Connectivity: every cell of a class must be reachable from its start —
    // the easiest defect to let through while editing a grid. For a shared grid,
    // we check from EVERY class start that all the class 0 cells are reached.
    std::vector<std::pair<uint8, uint8>> toCheck;   // (class of the start, class of the cells)
    for (uint8 classId : classes)
        if (classId != 0)
            toCheck.emplace_back(classId, classId);
    if (shared)
        for (auto const& [classId, nodeId] : _starts)
            toCheck.emplace_back(classId, 0);

    for (auto const& [startClass, gridClass] : toCheck)
    {
        auto itStart = _starts.find(startClass);
        if (itStart == _starts.end())
        {
            LOG_WARN("module", "SphereGrid: class {} has cells but no start.", startClass);
            continue;
        }
        if (!_cells.count(itStart->second))
            continue;   // already reported above
        uint8 const classId = gridClass;

        // VISIBILITY PER CLASS: a spell cell with no spell for the class does
        // not exist for it, nor do its edges. The search neither goes through it
        // nor counts it.
        auto hidden = [&](uint32 nodeId)
        {
            SphereGridCell const& e = _cells.at(nodeId);
            return e.kind == SPHEREGRID_SPELL && !SpellFor(e, startClass);
        };
        if (hidden(itStart->second))
        {
            LOG_WARN("module", "SphereGrid: the start of class {} ({}) is a spell cell with no spell for it.",
                startClass, itStart->second);
            continue;
        }

        std::unordered_set<uint32> seen;
        std::deque<uint32> queue { itStart->second };
        seen.insert(itStart->second);
        while (!queue.empty())
        {
            uint32 current = queue.front();
            queue.pop_front();
            for (uint32 neighbour : _cells.at(current).neighbours)
                if (!hidden(neighbour) && seen.insert(neighbour).second)
                    queue.push_back(neighbour);
        }

        uint32 total = 0;
        for (auto const& [id, e] : _cells)
            if (e.classId == classId && !hidden(id))
                ++total;

        if (seen.size() < total)
            LOG_WARN("module", "SphereGrid: class {} (start of class {}) — {} cell(s) out of {} not connected to the start.",
                classId, startClass, total - seen.size(), total);
    }
}

SphereGridCell const* SphereGridMgr::Cell(uint32 nodeId) const
{
    auto it = _cells.find(nodeId);
    return it != _cells.end() ? &it->second : nullptr;
}

uint32 SphereGridMgr::SpellFor(SphereGridCell const& e, uint8 classId) const
{
    auto it = _classSpells.find({ e.nodeId, classId });
    if (it != _classSpells.end() && it->second)
        return it->second;
    return e.spellId;
}

uint32 SphereGridMgr::Start(uint8 classId) const
{
    auto it = _starts.find(classId);
    return it != _starts.end() ? it->second : 0;
}

uint32 SphereGridMgr::Distance(uint8 classId, uint32 nodeId) const
{
    auto itClass = _distances.find(classId);
    if (itClass == _distances.end())
        return UNKNOWN_DISTANCE;
    auto it = itClass->second.find(nodeId);
    return it != itClass->second.end() ? it->second : UNKNOWN_DISTANCE;
}

uint32 SphereGridMgr::ActivationCost(uint8 classId, uint32 nodeId) const
{
    uint32 const distance = Distance(classId, nodeId);

    // Not connected to the start: charged at the cap rather than given away.
    // Validate() has already reported the anomaly at load time.
    if (distance == UNKNOWN_DISTANCE)
        return COST_CAP;

    // The start is free; every step away from it adds its own, up to the cap.
    uint64 const raw = uint64(distance) * COST_PER_STEP;
    return raw > COST_CAP ? COST_CAP : uint32(raw);
}

SphereGridStone const* SphereGridMgr::Stone(uint32 itemEntry) const
{
    auto it = _stones.find(itemEntry);
    return it != _stones.end() ? &it->second : nullptr;
}

SphereGridStatRune const* SphereGridMgr::StatRune(uint32 itemEntry) const
{
    auto it = _statRunes.find(itemEntry);
    return it != _statRunes.end() ? &it->second : nullptr;
}

SphereGridRune const* SphereGridMgr::Rune(uint32 itemEntry) const
{
    auto it = _runes.find(itemEntry);
    return it != _runes.end() ? &it->second : nullptr;
}

uint32 SphereGridMgr::PointsForSource(std::string const& type, uint32 value) const
{
    auto it = _pointSources.find({ type, value });
    if (it == _pointSources.end() && value)
        it = _pointSources.find({ type, 0 });
    return it != _pointSources.end() ? it->second : 0;
}

uint32 SphereGridMgr::ExactPointsForSource(std::string const& type, uint32 value) const
{
    auto it = _pointSources.find({ type, value });
    return it != _pointSources.end() ? it->second : 0;
}

uint32 SphereGridMgr::PointsForInstance(std::string const& type, Map const* map) const
{
    if (!map)
        return ExactPointsForSource(type, 0);
    uint32 const difficulty = uint32(map->GetDifficulty());
    uint32 const mapKey = map->GetId() * 10;
    uint32 points = ExactPointsForSource(type, mapKey + difficulty + 1);
    if (!points)
        points = ExactPointsForSource(type, mapKey);
    if (!points && !map->IsRaid() && map->GetEntry())
        points = ExactPointsForSource(type, map->GetEntry()->Expansion() * 3 + difficulty + 1);
    if (!points)
        points = ExactPointsForSource(type, 0);
    return points;
}
