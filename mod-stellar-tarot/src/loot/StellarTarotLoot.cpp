/*
 * This file is part of mod-stellar-tarot.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "StellarTarotLoot.h"

#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Field.h"
#include "Log.h"
#include "LootMgr.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "ObjectGuid.h"
#include "Player.h"
#include "QueryResult.h"
#include "Random.h"
#include "SharedDefines.h"
#include "StellarTarotBinder.h"
#include "StellarTarotMgr.h"
#include "WorldSession.h"

#include <fmt/format.h>

namespace
{
    std::vector<StellarTarotSource> sources;
    bool enabled = true;
    float rate = 100.0f;
    bool knownMayDrop = true;

    // What a creature's loot says of itself, read once per loot.
    struct Facts
    {
        uint32 entry = 0;
        uint32 level = 0;
        bool boss = false;
        bool elite = false;
        int8 expansion = -1;
        bool dungeon = false;
        bool raid = false;
        bool heroic = false;
    };

    Facts Read(Creature* creature)
    {
        Facts f;
        f.entry = creature->GetEntry();
        f.level = creature->GetLevel();
        uint32 const rank = creature->GetCreatureTemplate()->rank;
        f.boss = creature->IsDungeonBoss() || creature->isWorldBoss() || rank == CREATURE_ELITE_WORLDBOSS;
        f.elite = !f.boss && (rank == CREATURE_ELITE_ELITE || rank == CREATURE_ELITE_RAREELITE);
        if (Map* map = creature->GetMap())
        {
            f.raid = map->IsRaid();
            f.dungeon = map->IsDungeon() && !f.raid;
            f.heroic = map->IsHeroic();
            if (MapEntry const* entry = map->GetEntry())
                f.expansion = int8(entry->Expansion());
        }
        return f;
    }

    bool Matches(StellarTarotSource const& s, Facts const& f)
    {
        if (s.creatureEntry && s.creatureEntry != f.entry)
            return false;
        if (s.expansion >= 0 && s.expansion != f.expansion)
            return false;
        if (s.place == "world" && (f.dungeon || f.raid))
            return false;
        if (s.place == "dungeon" && !f.dungeon)
            return false;
        if (s.place == "raid" && !f.raid)
            return false;
        if (s.heroic >= 0 && (s.heroic == 1) != f.heroic)
            return false;
        if (s.rank == "boss" && !f.boss)
            return false;
        if (s.rank == "elite" && !f.elite)
            return false;
        if (s.rank == "normal" && (f.boss || f.elite))
            return false;
        if (s.minLevel && f.level < s.minLevel)
            return false;
        if (s.maxLevel && f.level > s.maxLevel)
            return false;
        return true;
    }

    // The item that drops: the one named, or one drawn uniformly from the
    // catalogue -- from what the account does not know yet, when a known
    // card may not drop again. 0 when nothing can.
    uint32 Resolve(StellarTarotSource const& s, uint32 accountId)
    {
        if (s.targetId)
        {
            if (!knownMayDrop)
            {
                bool const known = s.board ? StellarTarotBinder::KnowsBoard(accountId, s.targetId)
                                           : StellarTarotBinder::KnowsCard(accountId, s.targetId);
                if (known)
                    return 0;
            }
            return s.board ? StellarTarotMgr::ItemForBoard(s.targetId) : StellarTarotMgr::ItemForCard(s.targetId);
        }
        std::vector<uint32> pool;
        if (s.board)
        {
            for (auto const& [id, board] : sStellarTarotMgr->Boards())
                if (knownMayDrop || !StellarTarotBinder::KnowsBoard(accountId, id))
                    pool.push_back(StellarTarotMgr::ItemForBoard(id));
        }
        else
        {
            for (auto const& [id, card] : sStellarTarotMgr->Cards())
                if (knownMayDrop || !StellarTarotBinder::KnowsCard(accountId, id))
                    pool.push_back(StellarTarotMgr::ItemForCard(id));
        }
        if (pool.empty())
            return 0;
        return pool[urand(0, uint32(pool.size()) - 1)];
    }

    // Into the loot window, one item per draw so that a random source may
    // yield different cards. The window is capped: beyond it Loot::AddItem
    // gives up silently, so it is said here instead.
    void Place(Loot* loot, StellarTarotSource const& s, uint32 accountId)
    {
        for (uint8 i = 0; i < s.quantity; ++i)
        {
            uint32 const entry = Resolve(s, accountId);
            if (!entry)
            {
                LOG_DEBUG("module", "StellarTarot loot: source {} won its roll but nothing could be drawn.", s.id);
                return;
            }
            if (loot->items.size() >= MAX_NR_LOOT_ITEMS)
            {
                LOG_DEBUG("module", "StellarTarot loot: loot full, {} not added (source {}).", entry, s.id);
                return;
            }
            loot->AddItem(LootStoreItem(entry, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
            LOG_DEBUG("module", "StellarTarot loot: {} added (source {}).", entry, s.id);
        }
    }

    bool OneOf(std::string const& value, std::initializer_list<char const*> allowed)
    {
        for (char const* a : allowed)
            if (value == a)
                return true;
        return false;
    }
}

void StellarTarotLoot::Load()
{
    sources.clear();
    enabled = sConfigMgr->GetOption<bool>("StellarTarot.Loot.Enabled", true);
    rate = sConfigMgr->GetOption<float>("StellarTarot.Loot.Rate", 100.0f);
    knownMayDrop = sConfigMgr->GetOption<bool>("StellarTarot.Loot.Known", true);
    if (rate < 0.0f)
        rate = 0.0f;

    uint32 refused = 0;
    if (QueryResult result = WorldDatabase.Query(
        "SELECT source_id, origin, what, target_id, creature_entry, expansion, place, heroic, creature_rank, "
        "min_level, max_level, chance, quantity, comment FROM mod_stellar_tarot_source ORDER BY source_id"))
    {
        do
        {
            Field* f = result->Fetch();
            StellarTarotSource s;
            s.id = f[0].Get<uint32>();
            s.origin = f[1].Get<std::string>();
            std::string const what = f[2].Get<std::string>();
            s.board = what == "board";
            s.targetId = f[3].Get<uint32>();
            s.creatureEntry = f[4].Get<uint32>();
            s.expansion = f[5].Get<int8>();
            s.place = f[6].Get<std::string>();
            s.heroic = f[7].Get<int8>();
            s.rank = f[8].Get<std::string>();
            s.minLevel = f[9].Get<uint32>();
            s.maxLevel = f[10].Get<uint32>();
            s.chance = f[11].Get<float>();
            s.quantity = f[12].Get<uint8>();
            s.comment = f[13].Get<std::string>();

            std::string why;
            if (s.origin != "creature")
                why = "origin must be 'creature'";
            else if (!OneOf(what, { "card", "board" }))
                why = "what must be 'card' or 'board'";
            else if (s.targetId && !s.board && !sStellarTarotMgr->Card(s.targetId))
                why = fmt::format("card {} is not in the catalogue", s.targetId);
            else if (s.targetId && s.board && !sStellarTarotMgr->Board(s.targetId))
                why = fmt::format("board {} is not in the catalogue", s.targetId);
            else if (s.expansion < -1 || s.expansion > 2)
                why = "expansion must be -1, 0, 1 or 2";
            else if (!OneOf(s.place, { "", "world", "dungeon", "raid" }))
                why = "place must be empty, 'world', 'dungeon' or 'raid'";
            else if (s.heroic < -1 || s.heroic > 1)
                why = "heroic must be -1, 0 or 1";
            else if (!OneOf(s.rank, { "", "normal", "elite", "boss" }))
                why = "creature_rank must be empty, 'normal', 'elite' or 'boss'";
            else if (s.maxLevel && s.minLevel > s.maxLevel)
                why = "min_level is above max_level";
            else if (s.chance <= 0.0f || s.chance > 100.0f)
                why = "chance must be in ]0, 100]";
            else if (s.quantity == 0)
                why = "quantity must be at least 1";

            if (!why.empty())
            {
                LOG_ERROR("module", "StellarTarot: loot source {} ignored: {}.", s.id, why);
                ++refused;
                continue;
            }
            sources.push_back(std::move(s));
        } while (result->NextRow());
    }
    LOG_INFO("module", "StellarTarot: {} loot source(s) loaded, {} refused; loot {}, rate {} %, known items {}.",
             sources.size(), refused, enabled ? "on" : "off", rate, knownMayDrop ? "may drop" : "never drop");
}

std::vector<StellarTarotSource> const& StellarTarotLoot::Sources() { return sources; }
bool StellarTarotLoot::Enabled() { return enabled; }
float StellarTarotLoot::Rate() { return rate; }
bool StellarTarotLoot::KnownMayDrop() { return knownMayDrop; }

void StellarTarotLoot::Fill(Loot* loot, LootStore const& store, Player* player)
{
    // This fires on EVERY loot the server fills: the cheap tests come first.
    if (&store != &LootTemplates_Creature)
        return;
    if (!enabled || sources.empty() || !player || !loot || !sStellarTarotMgr->Enabled())
        return;
    if (!loot->sourceWorldObjectGUID.IsCreature())
        return;
    Creature* creature = ObjectAccessor::GetCreature(*player, loot->sourceWorldObjectGUID);
    if (!creature)
        return;

    Facts const facts = Read(creature);
    uint32 const accountId = player->GetSession()->GetAccountId();
    for (StellarTarotSource const& s : sources)
    {
        if (!Matches(s, facts))
            continue;
        if (!roll_chance_f(s.chance * rate / 100.0f))
            continue;
        Place(loot, s, accountId);
    }
}

std::string StellarTarotLoot::Describe(StellarTarotSource const& s)
{
    std::string what;
    if (s.targetId)
        what = s.board ? fmt::format("board {} \"{}\"", s.targetId, sStellarTarotMgr->BoardName(s.targetId))
                       : fmt::format("card {} \"{}\"", s.targetId, sStellarTarotMgr->CardName(s.targetId));
    else
        what = s.board ? "a board drawn at random" : "a card drawn at random";

    std::string from = "creature";
    from += s.creatureEntry ? fmt::format(" {}", s.creatureEntry) : std::string(" (any)");
    if (s.expansion >= 0)
        from += fmt::format(", expansion {}", s.expansion);
    if (!s.place.empty())
        from += ", " + s.place;
    if (s.heroic >= 0)
        from += s.heroic ? ", heroic" : ", non-heroic";
    if (!s.rank.empty())
        from += ", " + s.rank;
    if (s.minLevel || s.maxLevel)
        from += fmt::format(", level {}-{}", s.minLevel, s.maxLevel ? std::to_string(s.maxLevel) : std::string("max"));

    std::string line = fmt::format("{} x{} at {}% from {}", what, s.quantity, s.chance, from);
    if (!s.comment.empty())
        line += " -- " + s.comment;
    return line;
}
