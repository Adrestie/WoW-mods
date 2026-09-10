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
 * mod-spheregrid — the loot brackets.
 *
 * WHAT A SOURCE IS -- an Icecrown boss, a titanium vein, a beast of level 80,
 * a raid chest -- is decided HERE, by the predicates below, and nowhere else.
 * WHAT IT DROPS is the operator's: every source has a setting,
 * `SphereGrid.Loot.<key>`, that writes its rolls in a grammar of its own
 * (see "the loot grammar" below), and the tables written here are what a
 * setting left out means -- the defaults, and what the configuration file
 * ships. On top of that, one factor per object (SphereGridMgr::*DropFactor)
 * multiplies every rate at which it appears.
 *
 * Adding a source demands a recompilation; changing what one drops does not.
 *
 * TWO RULES, not to be confused:
 *
 *  1. THE FIRST MATCHING CASE WINS. The cases are ordered from the most precise
 *     to the most general; the boss of the latest raid is also a raid boss, and
 *     the first case takes it, alone.
 *
 *  2. EVERY LINE OF THE CHOSEN CASE IS PLAYED, each with its own roll. A raid
 *     boss therefore yields a Nexus AND a stone: two independent rolls, not an
 *     alternative.
 *
 * A line is itself a SEQUENCE OF ATTEMPTS played in order, the first winning one
 * taking it. That is how fallbacks are written, chained ones included.
 */

#include "SphereGridLoot.h"

#include "Creature.h"
#include "DBCStores.h"
#include "Formulas.h"
#include "GameObject.h"
#include "Log.h"
#include "LootMgr.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "Chat.h"
#include "Config.h"
#include "ObjectGuid.h"
#include "SharedDefines.h"
#include "SphereGridMgr.h"
#include "SphereGridStrings.h"

#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <iterator>
#include <string>
#include <unordered_map>
#include <vector>

namespace
{
    // --- the items, as the module item generator creates them
    // THE ALLOCATION IS DECLARED ONCE, in SphereGridMgr.h: these are aliases, not
    // a second copy. Two lists of the same numbers is how they drift apart.
    constexpr uint32 NEXUS_DEPLETED = SPHEREGRID_NEXUS_DEPLETED;
    constexpr uint32 NEXUS_FLICKERING = SPHEREGRID_NEXUS_FLICKERING;
    constexpr uint32 NEXUS_LUMINOUS = SPHEREGRID_NEXUS_LUMINOUS;
    constexpr uint32 NEXUS_IRRADIANT = SPHEREGRID_NEXUS_IRRADIANT;
    constexpr uint32 NEXUS_SOLAR = SPHEREGRID_NEXUS_SOLAR;
    constexpr uint32 NEXUS_PRISM = SPHEREGRID_NEXUS_PRISMATIC;

    // A stone entry = base + (statistic - 1) x qualities + (quality - 1).
    constexpr uint32 STONE_BASE = SPHEREGRID_STONE_BASE;
    constexpr uint32 STONE_STATS = SPHEREGRID_STAT_COUNT;

    // The lines asking for a rune are written and stay silent until the rune
    // catalogue exists — better to see them in the table than to have forgotten
    // them.
    constexpr uint32 DROP_RUNE = 0xFFFFFFFEu;

    constexpr uint32 MAP_LAST_RAID    = 631;
    constexpr uint32 GOB_SARONITE_PURE = 195036;    // the same lock as titanium

    // What a line drops: a precise entry, or a stone whose statistic is drawn at
    // random among the sixteen.
    struct Drop
    {
        uint32 entry;
        uint8  quality;
    };

    constexpr Drop Nexus(uint32 e) { return { e, 0 }; }
    constexpr Drop Stone(uint8 q) { return { 0, q }; }
    constexpr Drop Rune()          { return { DROP_RUNE, 0 }; }
    constexpr Drop Nothing()          { return { 0, 0 }; }

    struct Attempt
    {
        Drop drop;
        uint8 quantity;
        float chance;                   // en pourcent
    };

    constexpr Attempt T(Drop o, uint8 q, float c) { return { o, q, c }; }
    constexpr Attempt End()                        { return { Nothing(), 0, 0.0f }; }

    // A line: up to three attempts played in order, stopping at the first
    // winning roll. An attempt with a zero chance ends the chain.
    constexpr size_t MAX_ATTEMPTS = 3;

    struct Line
    {
        Attempt attempts[MAX_ATTEMPTS];
    };

    struct Case
    {
        char const*  name;      // what it is, for the logs
        char const*  key;       // its setting: SphereGrid.Loot.<key>
        bool (*matches)(SphereGridLootSource const&);
        Line const* defaults;   // what a setting left out means
        size_t       count;
    };

    // ==================================================================
    // MONSTERS
    // ==================================================================
    Line const M_ICC_BOSS[] =
    {
        { { T(Nexus(NEXUS_PRISM), 1, 2.0f),      End(), End() } },   // 2 %, any WotLK raid boss
        { { T(Nexus(NEXUS_SOLAR), 1, 25.0f),
            T(Nexus(NEXUS_IRRADIANT), 1, 100.0f), End() } },
        { { T(Stone(5), 1, 25.0f),
            T(Stone(4), 2, 50.0f),
            T(Stone(4), 1, 100.0f) } },
        { { T(Rune(), 1, 33.0f), End(), End() } },
    };

    Line const M_RAID_WRATH_BOSS[] =
    {
        { { T(Nexus(NEXUS_PRISM), 1, 2.0f),      End(), End() } },   // 2 %, any WotLK raid boss
        { { T(Nexus(NEXUS_IRRADIANT), 1, 100.0f), End(), End() } },
        { { T(Stone(4), 1, 100.0f),              End(), End() } },
        { { T(Rune(), 1, 10.0f),                  End(), End() } },
    };

    Line const M_RAID_WRATH[] =
    {
        { { T(Nexus(NEXUS_LUMINOUS), 1, 5.0f), End(), End() } },
        { { T(Stone(4), 1, 2.0f),             End(), End() } },
        { { T(Rune(), 1, 2.0f),                End(), End() } },
    };

    Line const M_HERO_BOSS[] =
    {
        { { T(Nexus(NEXUS_LUMINOUS), 1, 25.0f), End(), End() } },
        { { T(Stone(3), 1, 25.0f),             End(), End() } },
    };

    // DUNGEON MONSTERS, NOT THE BOSSES.
    //
    // Trash is killed by the hundred, a boss once per visit, so trash is what
    // makes the bulk of the loot — hence rates far below the boss ones.
    //
    // In vanilla and BC dungeons the trash nonetheless yields MORE than its own
    // boss (5.5 % against 5 %). That inversion is deliberate: the boss of a low
    // dungeon is not worth much, and the trash is where the time goes.
    Line const M_HERO[] =
    {
        { { T(Nexus(NEXUS_LUMINOUS), 1, 6.0f), End(), End() } },
        { { T(Stone(3), 1, 6.0f),             End(), End() } },
    };

    Line const M_DUNGEON_WRATH_BOSS[] =
    {
        { { T(Nexus(NEXUS_LUMINOUS), 2, 20.0f), End(), End() } },
        { { T(Stone(3), 1, 15.0f),             End(), End() } },
    };

    Line const M_DUNGEON_WRATH[] =
    {
        { { T(Nexus(NEXUS_LUMINOUS), 1, 5.0f), End(), End() } },
        { { T(Stone(2), 1, 4.0f),             End(), End() } },
    };

    Line const M_MONDE_WRATH[] =
    {
        { { T(Nexus(NEXUS_LUMINOUS), 1, 5.0f), End(), End() } },
        { { T(Stone(2), 1, 3.0f),             End(), End() } },
    };

    Line const M_RAID_BC_BOSS[] =
    {
        { { T(Nexus(NEXUS_FLICKERING), 2, 7.0f), End(), End() } },
        { { T(Stone(2), 1, 15.0f),             End(), End() } },
    };

    Line const M_RAID_BC[] =
    {
        { { T(Nexus(NEXUS_FLICKERING), 1, 8.0f), End(), End() } },
        { { T(Stone(2), 1, 5.0f),              End(), End() } },
    };

    // BC DUNGEONS USED TO BE A SINGLE CASE for their bosses and their trash.
    // Lowering that case would have taken the bosses down with it, so it is split
    // in two, the boss keeping its own rate.
    Line const M_DUNGEON_BC_BOSS[] =
    {
        { { T(Nexus(NEXUS_FLICKERING), 1, 5.0f), End(), End() } },
        { { T(Stone(1), 1, 5.0f),              End(), End() } },
    };

    Line const M_DUNGEON_BC[] =
    {
        { { T(Nexus(NEXUS_FLICKERING), 1, 5.5f), End(), End() } },
        { { T(Stone(1), 1, 5.0f),              End(), End() } },
    };

    Line const M_MONDE_BC[] =
    {
        { { T(Nexus(NEXUS_FLICKERING), 1, 5.0f), End(), End() } },
        { { T(Stone(1), 1, 3.0f),              End(), End() } },
    };

    Line const M_RAID_VANILLA_BOSS[] =
    {
        { { T(Nexus(NEXUS_FLICKERING), 2, 7.0f), End(), End() } },
    };

    Line const M_RAID_VANILLA[] =
    {
        { { T(Nexus(NEXUS_DEPLETED), 1, 8.0f), End(), End() } },
    };

    Line const M_DUNGEON_VANILLA_BOSS[] =
    {
        { { T(Nexus(NEXUS_DEPLETED), 1, 5.0f), End(), End() } },
    };

    Line const M_DUNGEON_VANILLA[] =
    {
        { { T(Nexus(NEXUS_DEPLETED), 1, 5.5f), End(), End() } },
    };

    Line const M_MONDE_VANILLA[] =
    {
        { { T(Nexus(NEXUS_DEPLETED), 1, 5.0f), End(), End() } },
    };

    // A dungeon is recognised as "an instance that is not a raid": the core's
    // IsDungeon covers both.
    Case const CASE_MONSTER[] =
    {
        { "Icecrown raid bosses", "IcecrownRaidBoss", [](SphereGridLootSource const& s)
          { return s.boss && s.map == MAP_LAST_RAID; },
          M_ICC_BOSS, std::size(M_ICC_BOSS) },

        { "Wrath raid bosses, Icecrown aside", "WrathRaidBoss", [](SphereGridLootSource const& s)
          { return s.expansion == 2 && s.raid && s.boss; },
          M_RAID_WRATH_BOSS, std::size(M_RAID_WRATH_BOSS) },

        { "Wrath raid monsters, Icecrown included", "WrathRaidTrash", [](SphereGridLootSource const& s)
          { return s.expansion == 2 && s.raid; },
          M_RAID_WRATH, std::size(M_RAID_WRATH) },

        { "Wrath heroic dungeon bosses", "WrathHeroicBoss", [](SphereGridLootSource const& s)
          { return s.expansion == 2 && s.dungeon && !s.raid && s.heroic && s.boss; },
          M_HERO_BOSS, std::size(M_HERO_BOSS) },

        { "Wrath heroic dungeon monsters", "WrathHeroicTrash", [](SphereGridLootSource const& s)
          { return s.expansion == 2 && s.dungeon && !s.raid && s.heroic; },
          M_HERO, std::size(M_HERO) },

        { "Wrath dungeon bosses", "WrathDungeonBoss", [](SphereGridLootSource const& s)
          { return s.expansion == 2 && s.dungeon && !s.raid && s.boss; },
          M_DUNGEON_WRATH_BOSS, std::size(M_DUNGEON_WRATH_BOSS) },

        { "Wrath dungeon monsters", "WrathDungeonTrash", [](SphereGridLootSource const& s)
          { return s.expansion == 2 && s.dungeon && !s.raid; },
          M_DUNGEON_WRATH, std::size(M_DUNGEON_WRATH) },

        { "Wrath ordinary monsters", "WrathWorld", [](SphereGridLootSource const& s)
          { return s.expansion == 2; },
          M_MONDE_WRATH, std::size(M_MONDE_WRATH) },

        { "Burning Crusade raid bosses", "BcRaidBoss", [](SphereGridLootSource const& s)
          { return s.expansion == 1 && s.raid && s.boss; },
          M_RAID_BC_BOSS, std::size(M_RAID_BC_BOSS) },

        { "Burning Crusade raid monsters", "BcRaidTrash", [](SphereGridLootSource const& s)
          { return s.expansion == 1 && s.raid; },
          M_RAID_BC, std::size(M_RAID_BC) },

        { "Burning Crusade dungeon bosses", "BcDungeonBoss", [](SphereGridLootSource const& s)
          { return s.expansion == 1 && s.dungeon && !s.raid && s.boss; },
          M_DUNGEON_BC_BOSS, std::size(M_DUNGEON_BC_BOSS) },

        { "Burning Crusade dungeon monsters", "BcDungeonTrash", [](SphereGridLootSource const& s)
          { return s.expansion == 1 && s.dungeon && !s.raid; },
          M_DUNGEON_BC, std::size(M_DUNGEON_BC) },

        { "Burning Crusade ordinary monsters", "BcWorld", [](SphereGridLootSource const& s)
          { return s.expansion == 1; },
          M_MONDE_BC, std::size(M_MONDE_BC) },

        { "Vanilla raid bosses", "VanillaRaidBoss", [](SphereGridLootSource const& s)
          { return s.raid && s.boss; },
          M_RAID_VANILLA_BOSS, std::size(M_RAID_VANILLA_BOSS) },

        { "Vanilla raid monsters", "VanillaRaidTrash", [](SphereGridLootSource const& s)
          { return s.raid; },
          M_RAID_VANILLA, std::size(M_RAID_VANILLA) },

        { "Vanilla dungeon bosses", "VanillaDungeonBoss", [](SphereGridLootSource const& s)
          { return s.dungeon && s.boss; },
          M_DUNGEON_VANILLA_BOSS, std::size(M_DUNGEON_VANILLA_BOSS) },

        { "Vanilla dungeon monsters", "VanillaDungeonTrash", [](SphereGridLootSource const& s)
          { return s.dungeon; },
          M_DUNGEON_VANILLA, std::size(M_DUNGEON_VANILLA) },

        { "Vanilla ordinary monsters", "VanillaWorld", [](SphereGridLootSource const& /*s*/)
          { return true; },
          M_MONDE_VANILLA, std::size(M_MONDE_VANILLA) },
    };

    // ==================================================================
    // GATHERING
    //
    // A kind of vein or herb is recognised by the pair (skill required,
    // expansion of the map): the skill alone is not enough, since two ores of
    // different expansions can demand the very same value.
    // ==================================================================
    // BEWARE OF THE NAMES: the number suffixing these constants is the ORIGINAL
    // rate, not the current one. A later raise shifted them all — R_DEPLETED_3
    // now yields 5 %. Renaming them would have caused a chain of collisions, the
    // old _5 becoming a _7, a name already taken. Trust the value, never the
    // name.
    Line const R_DEPLETED_3[]  = { { { T(Nexus(NEXUS_DEPLETED),  1,  5.0f), End(), End() } } };
    Line const R_FLICKERING_3[] = { { { T(Nexus(NEXUS_FLICKERING), 1,  5.0f), End(), End() } } };
    Line const R_LUMINOUS_3[]  = { { { T(Nexus(NEXUS_LUMINOUS),  1,  5.0f), End(), End() } } };
    Line const R_LUMINOUS_5[]  = { { { T(Nexus(NEXUS_LUMINOUS),  1,  7.0f), End(), End() } } };
    Line const R_LUMINOUS_7[]  = { { { T(Nexus(NEXUS_LUMINOUS),  1,  9.0f), End(), End() } } };
    Line const R_LUMINOUS_8[]  = { { { T(Nexus(NEXUS_LUMINOUS),  1,  10.0f), End(), End() } } };
    Line const R_IRRADIANT_10[] = { { { T(Nexus(NEXUS_IRRADIANT), 1, 12.0f), End(), End() } } };

    // Titanium vein: failing an irradiant one, a luminous one at 10 %.
    Line const R_TITANIUM[] =
    {
        { { T(Nexus(NEXUS_IRRADIANT), 1, 5.0f),
            T(Nexus(NEXUS_LUMINOUS), 1, 12.0f), End() } },
    };

    bool IsMining(SphereGridLootSource const& s) { return s.profession == LOCKTYPE_MINING; }
    bool IsHerbalism(SphereGridLootSource const& s)  { return s.profession == LOCKTYPE_HERBALISM; }

    Case const CASE_GATHERING[] =
    {
        // --- mining ---------------------------------------------------
        // The rich saronite deposit shares the titanium lock: only its entry
        // tells them apart. It yields nothing, deliberately.
        { "Pure Saronite Deposit", "PureSaronite", [](SphereGridLootSource const& s)
          { return s.gob && s.gob->GetEntry() == GOB_SARONITE_PURE; },
          nullptr, 0 },

        { "Titanium Vein", "Titanium", [](SphereGridLootSource const& s)
          { return IsMining(s) && s.skill == 450; },
          R_TITANIUM, std::size(R_TITANIUM) },

        { "Rich Saronite Deposit", "RichSaronite", [](SphereGridLootSource const& s)
          { return IsMining(s) && s.skill == 425; },
          R_LUMINOUS_8, std::size(R_LUMINOUS_8) },

        { "Saronite Deposit", "Saronite", [](SphereGridLootSource const& s)
          { return IsMining(s) && s.skill == 400; },
          R_LUMINOUS_7, std::size(R_LUMINOUS_7) },

        { "Rich Cobalt Deposit", "RichCobalt", [](SphereGridLootSource const& s)
          { return IsMining(s) && s.skill == 375 && s.expansion == 2; },
          R_LUMINOUS_5, std::size(R_LUMINOUS_5) },

        { "Cobalt Deposit", "Cobalt", [](SphereGridLootSource const& s)
          { return IsMining(s) && s.skill == 350 && s.expansion == 2; },
          R_LUMINOUS_3, std::size(R_LUMINOUS_3) },

        { "Burning Crusade ores", "BcOres", [](SphereGridLootSource const& s)
          { return IsMining(s) && s.skill >= 275; },
          R_FLICKERING_3, std::size(R_FLICKERING_3) },

        { "Vanilla ores", "VanillaOres", IsMining,
          R_DEPLETED_3, std::size(R_DEPLETED_3) },

        // --- herbalism ------------------------------------------------
        { "Frost Lotus", "FrostLotus", [](SphereGridLootSource const& s)
          { return IsHerbalism(s) && s.skill == 450 && s.expansion == 2; },
          R_IRRADIANT_10, std::size(R_IRRADIANT_10) },

        { "Icethorn", "Icethorn", [](SphereGridLootSource const& s)
          { return IsHerbalism(s) && s.skill == 435; },
          R_LUMINOUS_7, std::size(R_LUMINOUS_7) },

        { "Lichbloom", "Lichbloom", [](SphereGridLootSource const& s)
          { return IsHerbalism(s) && s.skill == 425; },
          R_LUMINOUS_7, std::size(R_LUMINOUS_7) },

        { "Adder's Tongue", "AddersTongue", [](SphereGridLootSource const& s)
          { return IsHerbalism(s) && s.skill == 400 && s.expansion == 2; },
          R_LUMINOUS_5, std::size(R_LUMINOUS_5) },

        { "Talandra's Rose", "TalandrasRose", [](SphereGridLootSource const& s)
          { return IsHerbalism(s) && s.skill == 385; },
          R_LUMINOUS_5, std::size(R_LUMINOUS_5) },

        { "Tiger Lily", "TigerLily", [](SphereGridLootSource const& s)
          { return IsHerbalism(s) && s.skill == 375 && s.expansion == 2; },
          R_LUMINOUS_5, std::size(R_LUMINOUS_5) },

        { "Fire Leaf", "FireLeaf", [](SphereGridLootSource const& s)
          { return IsHerbalism(s) && s.skill == 360; },
          R_LUMINOUS_3, std::size(R_LUMINOUS_3) },

        { "Goldclover", "Goldclover", [](SphereGridLootSource const& s)
          { return IsHerbalism(s) && s.skill == 350 && s.expansion == 2; },
          R_LUMINOUS_3, std::size(R_LUMINOUS_3) },

        { "Frozen Herb", "FrozenHerb", [](SphereGridLootSource const& s)
          { return IsHerbalism(s) && s.skill == 300 && s.expansion == 2; },
          R_LUMINOUS_3, std::size(R_LUMINOUS_3) },

        // Two herbs of different expansions share the same skill requirement:
        // the map is what tells them apart.
        { "Burning Crusade herbs", "BcHerbs", [](SphereGridLootSource const& s)
          { return IsHerbalism(s)
                   && (s.skill > 300 || (s.skill == 300 && s.expansion == 1)); },
          R_FLICKERING_3, std::size(R_FLICKERING_3) },

        { "Vanilla herbs", "VanillaHerbs", IsHerbalism,
          R_DEPLETED_3, std::size(R_DEPLETED_3) },
    };

    // ==================================================================
    // SKINNING
    // ==================================================================
    Line const D_80[] = { { { T(Nexus(NEXUS_IRRADIANT), 1, 9.0f), End(), End() } } };
    Line const D_71[] = { { { T(Nexus(NEXUS_LUMINOUS),  1, 5.0f), End(), End() } } };
    Line const D_61[] = { { { T(Nexus(NEXUS_FLICKERING), 1, 5.0f), End(), End() } } };
    Line const D_1[]  = { { { T(Nexus(NEXUS_DEPLETED),  1, 5.0f), End(), End() } } };

    Case const CASE_SKINNING[] =
    {
        { "Skinning 80-83", "Skinning80", [](SphereGridLootSource const& s) { return s.level >= 80; },
          D_80, std::size(D_80) },
        { "Skinning 71-79", "Skinning71", [](SphereGridLootSource const& s) { return s.level >= 71; },
          D_71, std::size(D_71) },
        { "Skinning 61-70", "Skinning61", [](SphereGridLootSource const& s) { return s.level >= 61; },
          D_61, std::size(D_61) },
        { "Skinning 1-60", "Skinning1", [](SphereGridLootSource const& /*s*/) { return true; },
          D_1, std::size(D_1) },
    };

    // ==================================================================
    // CHESTS
    // ==================================================================
    Line const C_RAID[]   = { { { T(Nexus(NEXUS_FLICKERING), 2, 10.0f), End(), End() } } };
    Line const C_HERO[]   = { { { T(Nexus(NEXUS_DEPLETED),  5, 10.0f), End(), End() } } };
    Line const C_DUNGEON[] = { { { T(Nexus(NEXUS_DEPLETED),  3, 10.0f), End(), End() } } };
    Line const C_MONDE[]  = { { { T(Nexus(NEXUS_DEPLETED),  1, 12.0f), End(), End() } } };

    Case const CASE_CHEST[] =
    {
        { "Raid chest", "RaidChest", [](SphereGridLootSource const& s) { return s.raid; },
          C_RAID, std::size(C_RAID) },
        { "Heroic dungeon chest", "HeroicDungeonChest", [](SphereGridLootSource const& s)
          { return s.dungeon && s.heroic; }, C_HERO, std::size(C_HERO) },
        { "Dungeon chest", "DungeonChest", [](SphereGridLootSource const& s) { return s.dungeon; },
          C_DUNGEON, std::size(C_DUNGEON) },
        { "World chest", "WorldChest", [](SphereGridLootSource const& /*s*/) { return true; },
          C_MONDE, std::size(C_MONDE) },
    };

    // ==================================================================
    // THE LOOT GRAMMAR
    //
    // A source's setting writes its rolls: every roll is played, each with
    // its own dice, and the rolls are separated by ";". Inside a roll, the
    // attempts are played in order until one wins, separated by ",": that is
    // a fallback. An attempt is object:quantity:percent.
    //
    //   Prismatic:1:2 ; Solar:1:25, Irradiant:1:100 ; Rune:1:33
    //
    // Whitespace is free and the object's name is not case-sensitive. An
    // empty setting is a source that yields nothing; a setting that cannot
    // be read is reported at start-up and the built-in table is used.
    //
    // WRITTEN IN STD ALONE, between the two markers, so that it can be cut
    // out, compiled on its own and tried against every default and a few
    // mistakes without a server -- which is how it was checked.
    // ==================================================================
    // >>> the loot grammar
    using Roll = std::vector<Attempt>;      // attempts in order, the first winner takes it
    using Table = std::vector<Roll>;        // every roll of a source, all played

    struct Word { char const* name; Drop drop; };
    Word const WORDS[] =
    {
        { "Depleted",       Nexus(NEXUS_DEPLETED) },
        { "Flickering",     Nexus(NEXUS_FLICKERING) },
        { "Luminous",       Nexus(NEXUS_LUMINOUS) },
        { "Irradiant",      Nexus(NEXUS_IRRADIANT) },
        { "Solar",          Nexus(NEXUS_SOLAR) },
        { "Prismatic",      Nexus(NEXUS_PRISM) },
        { "CommonStone",    Stone(1) },
        { "UncommonStone",  Stone(2) },
        { "RareStone",      Stone(3) },
        { "EpicStone",      Stone(4) },
        { "LegendaryStone", Stone(5) },
        { "Rune",           Rune() },
    };

    std::string Trimmed(std::string const& s)
    {
        size_t a = 0, b = s.size();
        while (a < b && std::isspace(static_cast<unsigned char>(s[a])))
            ++a;
        while (b > a && std::isspace(static_cast<unsigned char>(s[b - 1])))
            --b;
        return s.substr(a, b - a);
    }

    std::vector<std::string> Split(std::string const& s, char separator)
    {
        std::vector<std::string> out;
        std::string current;
        for (char c : s)
        {
            if (c == separator)
            {
                out.push_back(current);
                current.clear();
            }
            else
                current += c;
        }
        out.push_back(current);
        return out;
    }

    bool SameWord(std::string const& a, char const* b)
    {
        size_t i = 0;
        for (; i < a.size() && b[i]; ++i)
            if (std::tolower(static_cast<unsigned char>(a[i]))
                != std::tolower(static_cast<unsigned char>(b[i])))
                return false;
        return i == a.size() && !b[i];
    }

    Word const* WordFor(std::string const& name)
    {
        for (Word const& w : WORDS)
            if (SameWord(name, w.name))
                return &w;
        return nullptr;
    }

    char const* NameOf(Drop const& drop)
    {
        for (Word const& w : WORDS)
            if (w.drop.entry == drop.entry && w.drop.quality == drop.quality)
                return w.name;
        return "?";
    }

    // Reads a source's setting into a table. On a mistake, says which piece
    // in `problem` and returns false; `out` is then not to be used.
    bool ParseTable(std::string const& raw, Table& out, std::string& problem)
    {
        out.clear();
        for (std::string const& rollText : Split(raw, ';'))
        {
            if (Trimmed(rollText).empty())
                continue;
            Roll roll;
            for (std::string const& piece : Split(rollText, ','))
            {
                std::string const text = Trimmed(piece);
                std::vector<std::string> const parts = Split(text, ':');
                if (parts.size() != 3)
                {
                    problem = "\"" + text + "\" is not object:quantity:percent";
                    return false;
                }
                std::string const name = Trimmed(parts[0]);
                Word const* word = WordFor(name);
                if (!word)
                {
                    problem = "\"" + name + "\" is not an object";
                    return false;
                }
                char* end = nullptr;
                std::string const q = Trimmed(parts[1]);
                long const quantity = std::strtol(q.c_str(), &end, 10);
                if (q.empty() || *end || quantity < 1 || quantity > 255)
                {
                    problem = "\"" + q + "\" is not a quantity from 1 to 255";
                    return false;
                }
                std::string const p = Trimmed(parts[2]);
                double const percent = std::strtod(p.c_str(), &end);
                if (p.empty() || *end || percent < 0.0 || percent > 100.0)
                {
                    problem = "\"" + p + "\" is not a percentage from 0 to 100";
                    return false;
                }
                roll.push_back(T(word->drop, uint8(quantity), float(percent)));
            }
            out.push_back(roll);
        }
        return true;
    }

    // A table written back as its setting: what the log shows, and what the
    // configuration file ships as the default.
    std::string Describe(Table const& table)
    {
        std::string out;
        for (Roll const& roll : table)
        {
            if (!out.empty())
                out += " ; ";
            bool first = true;
            for (Attempt const& t : roll)
            {
                if (!first)
                    out += ", ";
                first = false;
                char buffer[32];
                std::snprintf(buffer, sizeof buffer, "%g", double(t.chance));
                out += NameOf(t.drop);
                out += ':';
                out += std::to_string(t.quantity);
                out += ':';
                out += buffer;
            }
        }
        return out;
    }
    // <<< the loot grammar

    // THE TABLES AT RUN TIME, one per source, by key. Filled from the
    // configuration by SphereGridLoadLootConfig(), which the manager calls
    // whenever it reads the configuration -- at start-up, and on
    // `.spheregrid reload`.
    std::unordered_map<std::string, Table> tables;

    // The built-in table of a source, in the run-time shape: a chain stops at
    // its End().
    Table FromDefaults(Case const& c)
    {
        Table out;
        for (size_t j = 0; j < c.count; ++j)
        {
            Roll roll;
            for (Attempt const& t : c.defaults[j].attempts)
            {
                if (t.chance <= 0.0f)
                    break;
                roll.push_back(t);
            }
            out.push_back(roll);
        }
        return out;
    }

    Table const& TableFor(Case const& c)
    {
        auto it = tables.find(c.key);
        if (it == tables.end())
            it = tables.emplace(c.key, FromDefaults(c)).first;
        return it->second;
    }

    size_t changed = 0;             // sources the configuration set otherwise

    void LoadCases(Case const* cases, size_t count)
    {
        // A value the configuration cannot hold, so that a setting left out
        // can be told from one left empty: the first is the built-in table,
        // the second a source that yields nothing.
        static std::string const ABSENT = "\x01";
        for (size_t i = 0; i < count; ++i)
        {
            Case const& c = cases[i];
            std::string const key = std::string("SphereGrid.Loot.") + c.key;
            std::string const raw = sConfigMgr->GetOption<std::string>(key, ABSENT, false);
            Table table;
            std::string problem;
            if (raw == ABSENT)
                table = FromDefaults(c);
            else if (!ParseTable(raw, table, problem))
            {
                LOG_WARN("module", "SphereGrid: {} cannot be read -- {}. "
                         "The built-in table is used.", key, problem);
                table = FromDefaults(c);
            }
            // A source the configuration changed is said at start-up, as it
            // was read: an operator who wonders whether a setting was taken
            // finds the answer in the log, not in a kill.
            std::string const written = Describe(table);
            if (written != Describe(FromDefaults(c)))
            {
                LOG_INFO("module", "SphereGrid: loot, {} = {}", c.key,
                         written.empty() ? "nothing" : written);
                ++changed;
            }
            LOG_DEBUG("module", "SphereGrid loot: {} = {}", c.key, written);
            tables[c.key] = table;
        }
    }

    // ------------------------------------------------------------------
    // Mechanics
    // ------------------------------------------------------------------

    // A stone at random among the 16 statistics, in the quality asked for.
    uint32 RandomStone(uint8 quality)
    {
        if (!quality || quality > 5)
            return 0;
        uint32 const stat = urand(1, STONE_STATS);
        return STONE_BASE + (stat - 1) * 5 + (quality - 1);
    }

    // A RUNE AT RANDOM from the whole catalogue, ALL CLASSES TOGETHER. A warrior
    // may therefore pick up a druid rune: it is of no use to him, but it can be
    // traded — and reforged.
    //
    // The catalogue lives in SphereGridMgr and reloads (.spheregrid reload): it
    // is walked at every roll rather than copied into something that would age in
    // silence. A few hundred entries cost nothing.
    uint32 RandomRune()
    {
        auto const& runes = sSphereGridMgr->Runes();
        if (runes.empty())
            return 0;
        auto it = runes.begin();
        std::advance(it, urand(0, uint32(runes.size()) - 1));
        return it->first;
    }

    // The actual entry of an item, or 0 when there is nothing to place.
    uint32 Resolve(Drop const& drop)
    {
        if (drop.entry == DROP_RUNE)
            return RandomRune();
        return drop.entry ? drop.entry : RandomStone(drop.quality);
    }

    // A quantity of a PRECISE item gives a stack; a quantity of STONE gives that
    // many distinct rolls, each on its own statistic — two identical stones would
    // be of no interest.
    void Place(Loot* loot, Drop const& drop, uint8 quantity, char const* label)
    {
        if (!quantity)
            return;

        bool const random = (drop.entry == 0);
        uint8 const tirages  = random ? quantity : 1;
        uint8 const parPile  = random ? 1 : quantity;

        for (uint8 t = 0; t < tirages; ++t)
        {
            uint32 const entry = Resolve(drop);
            if (!entry)
                return;

            // The loot window is capped: beyond it, Loot::AddItem gives up
            // silently. We say so rather than let it pass for an unlucky roll.
            if (loot->items.size() >= MAX_NR_LOOT_ITEMS)
            {
                LOG_DEBUG("module", "SphereGrid: loot full, {} not added ({}).", entry, label);
                return;
            }

            loot->AddItem(LootStoreItem(entry, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0,
                                        parPile, parPile));

            // Enough to know what produced an item: without it, a lucky roll
            // cannot be told from a badly written bracket. Read it by raising the
            // module logger to debug in worldserver.conf.
            LOG_DEBUG("module", "SphereGrid loot: {} x{} - case \"{}\".",
                      entry, parPile, label);
        }
    }

    // Keeps the first matching case, then plays ALL of its lines; each line
    // stops at its first winning attempt.
    //
    // A GREY MONSTER YIELDS FAR LESS. The Nexus tiers follow the expansion of the
    // MAP, never the real difficulty: without this brake, a max-level player
    // walks an old raid alone and harvests there at the rate of a raid of his own
    // level. The door is not closed, it is narrowed — old content stays playable,
    // it stops being a farm.
    //
    // GREY IS THE GAME'S OWN NOTION (Acore::XP::GetGrayLevel), the one that
    // already cuts experience: above level 59 it is `level - 9`. Vanilla raid
    // bosses fall into it for a max-level player, BC ones do not.
    //
    // A FEW BOSSES OF THE SAME RAID sit right on the boundary and therefore fall
    // into the brake while their neighbours do not. The irregularity is KNOWN AND
    // ACCEPTED: do not "fix" it believing it an oversight.
    //
    // BOSSES ONLY. What is slowed down is old raid content, not the ordinary
    // world: skinning a grey beast, or killing a passing monster, is none of this
    // rule's business. A vein or a herb has no level anyway.
    constexpr float GREY_DIVISOR = 5.0f;

    // What the configuration says of this object: a factor on the written
    // rate. 0 is an object turned off.
    float DropFactor(Drop const& drop)
    {
        if (drop.entry == DROP_RUNE)
            return sSphereGridMgr->RuneDropFactor();
        if (drop.entry == 0)
            return sSphereGridMgr->StoneDropFactor(drop.quality);
        return sSphereGridMgr->NexusDropFactor(drop.entry);
    }

    float LevelFactor(SphereGridLootSource const& source)
    {
        if (!source.creature || !source.player || !source.boss)
            return 1.0f;
        if (source.level > Acore::XP::GetGrayLevel(source.player->GetLevel()))
            return 1.0f;
        return 1.0f / GREY_DIVISOR;
    }

    // ------------------------------------------------------------------
    // Bad-luck protection
    // ------------------------------------------------------------------
    //
    // Two counters per player, expressed in PERCENTAGE POINTS and added to the
    // written chance of the Nexus attempts only:
    //
    //   world : a small step per monster killed OUTSIDE an instance that yielded
    //           no Nexus.
    //   raid  : a larger step per RAID BOSS killed that yielded no Nexus.
    //
    // Either one falls back to zero as soon as a Nexus drops within its own
    // scope. Dungeons have no protection at all, bosses included. Gathering,
    // skinning and chests are outside the mechanism — it only bears on monsters.
    //
    // IN MEMORY ONLY, by design: a logout puts both counters back to zero.
    // Nothing goes to the database, and the table is purged at logout
    // (SphereGridForgetPity) so that it does not grow without end.
    //
    // THE PRISM IS OUTSIDE THE MECHANISM: neither boosted, nor counted as a Nexus
    // for the reset. The question is theoretical anyway — it only drops from the
    // bosses that yield a guaranteed Nexus, which can therefore never accumulate
    // any protection.
    struct Pity
    {
        float world = 0.0f;
        float raid  = 0.0f;
    };

    std::unordered_map<ObjectGuid, Pity> pities;

    constexpr float PITY_WORLD_STEP = 1.0f;
    constexpr float PITY_RAID_STEP  = 2.5f;

    bool IsPlainNexus(Drop const& o)
    {
        return o.entry >= NEXUS_DEPLETED && o.entry <= NEXUS_SOLAR;
    }

    // Which counter applies here: the world one, the raid one, or none.
    float Pity::* CounterFor(SphereGridLootSource const& source, bool onMonster)
    {
        if (!onMonster || !source.player)
            return nullptr;
        if (source.raid)
            return source.boss ? &Pity::raid : nullptr;   // raid: bosses only
        if (source.dungeon)
            return nullptr;                                // dungeon: nothing, bosses included
        return &Pity::world;                              // full world
    }

    // "Crossed" in the strict sense: the message fires on the crossing, once,
    // and only the highest threshold crossed speaks.
    void AnnounceThreshold(Player* player, float before, float after)
    {
        if (!player || !player->GetSession())
            return;

        struct Threshold { float threshold; uint32 text; };
        static constexpr Threshold THRESHOLDS[] =
        {
            { 100.0f, SPHEREGRID_STR_PITY_100 },
            {  75.0f, SPHEREGRID_STR_PITY_75  },
            {  50.0f, SPHEREGRID_STR_PITY_50  },
            {  25.0f, SPHEREGRID_STR_PITY_25  },
        };

        for (Threshold const& p : THRESHOLDS)
            if (before <= p.threshold && after > p.threshold)
            {
                ChatHandler(player->GetSession())
                    .PSendModuleSysMessage(SPHEREGRID_MODULE, p.text);
                return;
            }
    }

    void Apply(Loot* loot, SphereGridLootSource const& source,
                   Case const* label, size_t count, bool onMonster = false)
    {
        float const facteur = LevelFactor(source);

        float Pity::* const counter = CounterFor(source, onMonster);
        Pity* state = nullptr;
        float bonus = 0.0f;
        if (counter)
        {
            state  = &pities[source.player->GetGUID()];
            bonus = state->*counter;
        }

        for (size_t i = 0; i < count; ++i)
        {
            if (!label[i].matches(source))
                continue;

            bool gotNexus = false;
            bool nexusPossible = false;     // a Nexus the configuration allows

            for (Roll const& roll : TableFor(label[i]))
                for (Attempt const& t : roll)
                {
                    if (t.chance <= 0.0f)
                        continue;       // written as never: the next attempt
                    // AN OBJECT TURNED OFF in the configuration is not rolled
                    // at all: the chain goes on to the fallback written after
                    // it, and the bad-luck protection cannot bring it back.
                    float const configured = DropFactor(t.drop);
                    if (configured <= 0.0f)
                        continue;
                    // The factors bear on the ROLL, not on the end of the chain
                    // above: a reduced attempt is still an attempt, and it is
                    // always the WRITTEN chance that says where the chain stops.
                    //
                    // The protection is ADDED after the factors: it is a bonus
                    // in points, not a multiplier, and neither a grey monster
                    // nor a rarer object must divide it.
                    bool const nexus = IsPlainNexus(t.drop);
                    if (nexus)
                        nexusPossible = true;
                    if (roll_chance_f(t.chance * facteur * configured + (nexus ? bonus : 0.0f)))
                    {
                        Place(loot, t.drop, t.quantity, label[i].name);
                        if (nexus)
                            gotNexus = true;
                        break;
                    }
                }

            // No Nexus could have dropped here -- the configuration turned
            // them all off for this case -- so there is no bad luck to make up
            // for, and nothing to announce.
            if (counter && nexusPossible)
            {
                float const before = state->*counter;
                if (gotNexus)
                    state->*counter = 0.0f;
                else
                {
                    state->*counter = before
                        + (counter == &Pity::raid ? PITY_RAID_STEP : PITY_WORLD_STEP);
                    AnnounceThreshold(source.player, before, state->*counter);
                }
            }

            return;                     // one label only, never two
        }
    }

    // The loot of an item in the bags (prospecting, milling, disenchanting...)
    // has no world object for a source: sourceWorldObjectGUID stays empty and
    // there is nothing to tell apart. Those loots are none of our business.
    Creature* CreatureSource(Loot* loot, Player* player)
    {
        if (!loot->sourceWorldObjectGUID.IsCreature())
            return nullptr;
        return ObjectAccessor::GetCreature(*player, loot->sourceWorldObjectGUID);
    }

    GameObject* GobSource(Loot* loot, Player* player)
    {
        if (!loot->sourceWorldObjectGUID.IsGameObject())
            return nullptr;
        return ObjectAccessor::GetGameObject(*player, loot->sourceWorldObjectGUID);
    }

    // The expansion comes from the MAP (Map.dbc), not from the creature: the map
    // is what says a dungeon belongs to one expansion or another, whatever models
    // its occupants reuse.
    void FillFromMap(SphereGridLootSource& s, Map* map)
    {
        if (!map)
            return;

        s.dungeon   = map->IsDungeon();
        s.raid     = map->IsRaid();
        s.heroic = map->IsHeroic();

        if (MapEntry const* entry = map->GetEntry())
            s.expansion = entry->Expansion();
    }

    void FillFromCreature(SphereGridLootSource& s, Creature* crea)
    {
        s.creature = crea;
        s.level   = crea->GetLevel();
        s.rank     = crea->GetCreatureTemplate()->rank;
        s.boss     = crea->IsDungeonBoss() || crea->isWorldBoss()
                     || s.rank == CREATURE_ELITE_WORLDBOSS;
        s.map    = crea->GetMapId();
        s.zone     = crea->GetZoneId();

        FillFromMap(s, crea->GetMap());
    }

    // What a game object is to us and — when it is a gathering node — the
    // profession and the skill required. The latter lives in the lock (Lock.dbc),
    // neither in the entry nor in the zone.
    //
    // BEWARE: a skill of ZERO is legitimate and common. The starting ore and herbs
    // demand the profession without demanding any level — checked in Lock.dbc.
    // Confusing "no requirement" with "this is not a gathering node" would make
    // all the starting content disappear.
    void FillFromGameObject(SphereGridLootSource& s, GameObject* gob)
    {
        s.gob   = gob;
        s.map = gob->GetMapId();
        s.zone  = gob->GetZoneId();
        FillFromMap(s, gob->GetMap());

        GameObjectTemplate const* modele = gob->GetGOInfo();
        if (modele->type == GAMEOBJECT_TYPE_FISHINGHOLE)
        {
            s.gobKind = SPHEREGRID_GOB_FISHING_POOL;
            return;
        }

        if (uint32 lockId = modele->GetLockId())
            if (LockEntry const* lock = sLockStore.LookupEntry(lockId))
                for (uint8 i = 0; i < MAX_LOCK_CASE; ++i)
                    if (lock->Type[i] == LOCK_KEY_SKILL
                        && (lock->Index[i] == LOCKTYPE_HERBALISM
                            || lock->Index[i] == LOCKTYPE_MINING))
                    {
                        s.gobKind      = SPHEREGRID_GOB_GATHERING;
                        s.profession     = lock->Index[i];
                        s.skill = lock->Skill[i];
                        return;
                    }

        if (modele->type == GAMEOBJECT_TYPE_CHEST)
            s.gobKind = SPHEREGRID_GOB_CHEST;
    }
}

void SphereGridLoadLootConfig()
{
    tables.clear();
    changed = 0;
    LoadCases(CASE_MONSTER, std::size(CASE_MONSTER));
    LoadCases(CASE_GATHERING, std::size(CASE_GATHERING));
    LoadCases(CASE_SKINNING, std::size(CASE_SKINNING));
    LoadCases(CASE_CHEST, std::size(CASE_CHEST));
    LOG_INFO("module", "SphereGrid: loot read - {} source(s), {} set by the "
             "configuration.", tables.size(), changed);
}

void SphereGridFillLoot(Loot* loot, LootStore const& store, Player* player)
{
    // Performance guard: this hook fires on EVERY loot filled on the server. The
    // loot store test comes first, it discards all the rest without reading
    // anything. LootTemplates_Fishing is deliberately NOT part of it: fishing
    // yields nothing.
    bool const monster  = (&store == &LootTemplates_Creature);
    bool const gameObject = (&store == &LootTemplates_Gameobject);
    bool const skinning = (&store == &LootTemplates_Skinning);

    if (!monster && !gameObject && !skinning)
        return;
    if (!player || !loot)
        return;

    SphereGridLootSource source;
    source.player = player;

    if (monster || skinning)
    {
        Creature* crea = CreatureSource(loot, player);
        if (!crea)
            return;
        FillFromCreature(source, crea);

        if (monster)
            // This case alone feeds the bad-luck protection: skinning,
            // gathering and chests are excluded from it.
            Apply(loot, source, CASE_MONSTER, std::size(CASE_MONSTER), true);
        else
            Apply(loot, source, CASE_SKINNING, std::size(CASE_SKINNING));
        return;
    }

    GameObject* gob = GobSource(loot, player);
    if (!gob)
        return;

    FillFromGameObject(source, gob);

    // The game object store covers three distinct things. Fishing pools yield
    // nothing, by design.
    if (source.gobKind == SPHEREGRID_GOB_GATHERING)
        Apply(loot, source, CASE_GATHERING, std::size(CASE_GATHERING));
    else if (source.gobKind == SPHEREGRID_GOB_CHEST)
        Apply(loot, source, CASE_CHEST, std::size(CASE_CHEST));
}

// The bad-luck counters do NOT survive a logout, by design. Forgetting them here
// therefore serves two ends at once: applying that rule, and keeping the table
// from growing without end.
void SphereGridForgetPity(Player* player)
{
    if (player)
        pities.erase(player->GetGUID());
}
