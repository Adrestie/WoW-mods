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
 * Persistence is immediate: every mutation (points gained, a cell activated, a
 * reset) goes to the database straight away — an activation is a rare event and
 * simplicity wins. The in-memory state only lives between login and logout.
 */

#include "SphereGridPlayerMgr.h"
#include "SphereGridMgr.h"
#include "SphereGridStrings.h"

#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStructure.h"        // AchievementEntry::points, MapEntry::name
#include "ItemTemplate.h"        // ItemLocale
#include "ObjectMgr.h"           // GetItemTemplate, GetItemLocale, GetLocaleString
#include "QuestDef.h"            // QuestLocale::Title
#include "Field.h"
#include "Group.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "Opcodes.h"
#include "SpellMgr.h"
#include "QueryResult.h"
#include "WorldPacket.h"
#include "WorldSession.h"

#include <algorithm>

// OPTIONAL INTEROPERABILITY. A module that fills the world with bots creates
// Player objects that log in like anybody else; without this guard the module
// would build a state and write database rows for every one of them, at every
// login. When that module is absent, everyone is a real player and this compiles
// away to nothing.
#if defined(MOD_PLAYERBOTS)
#include "Playerbots.h"
static bool IsBot(Player* player) { return GET_PLAYERBOT_AI(player) != nullptr; }
#else
static bool IsBot(Player* /*player*/) { return false; }
#endif

SphereGridPlayerMgr* SphereGridPlayerMgr::instance()
{
    static SphereGridPlayerMgr instance;
    return &instance;
}

// THE ACCOUNT OF A PLAYER. With no session — a case that does not happen in
// practice but that the core allows — we return zero, which yields an account
// with no Spherite rather than a crash.
static uint32 AccountOf(Player const* player)
{
    WorldSession const* session = player ? player->GetSession() : nullptr;
    return session ? session->GetAccountId() : 0;
}

// THE LOCALE OF THE SESSION. Every gain message quotes a name — a boss, a
// quest, a stone — and that name must be in the language of WHOEVER reads it,
// not in the server's. A mixed group therefore receives as many versions as it
// has languages.
//
// THERE ARE TWO OF THEM, AND CONFUSING THEM DOES NOT SHOW AT ONCE:
//
//   DbLocaleOf  : the one of the TABLES — item_template_locale,
//                 creature_template_locale, quest_template_locale. It is what
//                 the core uses to answer item queries (ItemHandler.cpp).
//   DbcLocaleOf : the one of the DBC FILES — Achievement.dbc, Map.dbc. It is
//                 bounded by the DBC actually loaded, and therefore falls back
//                 to English when the language is not in them.
//
// Mixing them up showed the English item name to a French client: the localized
// row did exist in the table, but it was looked up at the DBC index.
static LocaleConstant DbLocaleOf(Player const* player)
{
    WorldSession const* session = player ? player->GetSession() : nullptr;
    return session ? session->GetSessionDbLocaleIndex() : DEFAULT_LOCALE;
}

static LocaleConstant DbcLocaleOf(Player const* player)
{
    WorldSession const* session = player ? player->GetSession() : nullptr;
    return session ? session->GetSessionDbcLocale() : DEFAULT_LOCALE;
}

// A localized DBC string, falling back on English: several tables do not carry
// every language, and an empty cell is better read in English than empty.
static std::string FromDbc(char const* const* names, LocaleConstant locale)
{
    if (!names)
        return "";
    if (names[locale] && *names[locale])
        return names[locale];
    return (names[LOCALE_enUS] && *names[LOCALE_enUS]) ? names[LOCALE_enUS] : "";
}

std::string SphereGridItemName(Player const* player, uint32 entry)
{
    ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry);
    if (!proto)
        return "";

    std::string name = proto->Name1;
    if (ItemLocale const* loc = sObjectMgr->GetItemLocale(entry))
        ObjectMgr::GetLocaleString(loc->Name, DbLocaleOf(player), name);
    return name;
}

std::string SphereGridQuestName(Player const* player, Quest const* quest)
{
    if (!quest)
        return "";

    // GetTitle returns the SERVER DEFAULT locale: without this detour through
    // quest_template_locale, a player would read the title in someone else's
    // language.
    std::string title = quest->GetTitle();
    if (QuestLocale const* loc = sObjectMgr->GetQuestLocale(quest->GetQuestId()))
        ObjectMgr::GetLocaleString(loc->Title, DbLocaleOf(player), title);
    return title;
}

void SphereGridPlayerMgr::Load(Player* player)
{
    if (!player || IsBot(player))
        return;

    uint32 const guid = player->GetGUID().GetCounter();
    SphereGridPlayerState state;


    // TWO SOURCES: what is EARNED belongs to the ACCOUNT — a boss killed on one
    // character credits all the others, and a character created tomorrow is born
    // with the whole of it. What is SPENT stays per character: each one has its
    // own grid and its own purchases.
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT earned, prisms FROM mod_spheregrid_account_points WHERE account_id = {}",
        AccountOf(player)))
    {
        state.earned  = result->Fetch()[0].Get<uint32>();
        state.prisms = result->Fetch()[1].Get<uint32>();
    }

    if (QueryResult result = CharacterDatabase.Query(
        "SELECT spent FROM mod_spheregrid_character_points WHERE guid = {}", guid))
    {
        state.spent = result->Fetch()[0].Get<uint32>();
    }

    if (QueryResult result = CharacterDatabase.Query(
        "SELECT node_id, content_entry, content_upgrade, forgotten, active FROM mod_spheregrid_character_node WHERE guid = {}", guid))
    {
        do
        {
            Field* f = result->Fetch();
            // active = 0: a cell GIVEN BACK by a reset. It is not bought any
            // more, but it keeps what it carried — the stone or the rune waits
            // there for the next purchase, it was not destroyed.
            if (!f[4].Get<uint8>())
            {
                state.inactiveContent[f[0].Get<uint32>()] = { f[1].Get<uint32>(), f[2].Get<uint8>() };
                continue;
            }
            state.actives[f[0].Get<uint32>()] = { f[1].Get<uint32>(), f[2].Get<uint8>() };
            if (f[3].Get<uint8>())
                state.forgotten.insert(f[0].Get<uint32>());
        } while (result->NextRow());
    }

    // A SPELL ADDED AFTER THE PURCHASE: a spell cell bought while the class had
    // nothing there has been given a spell since; it learns it without paying
    // again. Only a spell forgotten with the pin demands a new purchase.
    for (auto& [nodeId, content] : state.actives)
    {
        SphereGridCell const* def = sSphereGridMgr->Cell(nodeId);
        if (!def || def->kind != SPHEREGRID_SPELL || content.first || state.forgotten.count(nodeId))
            continue;
        uint32 const spell = sSphereGridMgr->SpellFor(*def, player->getClass());
        if (!spell)
            continue;
        content.first = spell;
        CharacterDatabase.DirectExecute(
            "UPDATE mod_spheregrid_character_node SET content_entry = {} WHERE guid = {} AND node_id = {}",
            spell, guid, nodeId);
    }

    // THE CONTENT OF STONE NODES BELONGS TO THE ACCOUNT: the account row wins,
    // otherwise the original stone. The character row is no longer authoritative
    // for them — it stays true for sockets and spell cells.
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT node_id, content_entry, content_upgrade FROM mod_spheregrid_account_node WHERE account_id = {}",
        AccountOf(player)))
    {
        do
        {
            Field* f = result->Fetch();
            state.accountContent[f[0].Get<uint32>()] = { f[1].Get<uint32>(), f[2].Get<uint8>() };
        } while (result->NextRow());
    }
    for (auto& [nodeId, content] : state.actives)
    {
        SphereGridCell const* def = sSphereGridMgr->Cell(nodeId);
        if (!def || def->kind != SPHEREGRID_NODE)
            continue;
        auto accountRow = state.accountContent.find(nodeId);
        if (accountRow != state.accountContent.end())
            content = accountRow->second;
        else
            content = { def->defaultStoneEntry, uint8(0) };
    }

    _states[player->GetGUID()] = std::move(state);

    // The statistic modifiers do not survive a logout: the block is applied
    // again at every login.
    _statBlocks.erase(player->GetGUID());
    Recompute(player);
}

void SphereGridPlayerMgr::Unload(Player* player)
{
    if (!player)
        return;
    _states.erase(player->GetGUID());
    _statBlocks.erase(player->GetGUID());
}

SphereGridPlayerState* SphereGridPlayerMgr::State(Player* player)
{
    if (!player)
        return nullptr;
    auto it = _states.find(player->GetGUID());
    return it != _states.end() ? &it->second : nullptr;
}

SphereGridActivation SphereGridPlayerMgr::Activate(Player* player, uint32 nodeId)
{
    SphereGridPlayerState* state = State(player);
    if (!state)
        return SphereGridActivation::NoState;

    SphereGridCell const* def = sSphereGridMgr->Cell(nodeId);
    if (!def)
        return SphereGridActivation::UnknownCell;
    // CLASS 0 IS THE SHARED GRID: it belongs to everyone.
    if (def->classId && def->classId != player->getClass())
        return SphereGridActivation::WrongClass;

    // The spell of a spell cell is the one of THE PLAYER'S CLASS on a shared
    // grid; the entry recorded is that spell.
    uint32 const spell = (def->kind == SPHEREGRID_SPELL) ? sSphereGridMgr->SpellFor(*def, player->getClass()) : 0;
    // With no spell for his class, the cell does not exist for this player — the
    // interface does not show it, and it cannot be bought either.
    if (def->kind == SPHEREGRID_SPELL && !spell)
        return SphereGridActivation::WrongClass;

    if (auto already = state->actives.find(nodeId); already != state->actives.end())
    {
        // A spell cell emptied with the pin lights up again on a new click, at
        // the USUAL price of a cell: the spell is part of the grid, only the
        // learning was lost. Without this path, forgetting would be final — the
        // cell being already active, there was no way back.
        if (def->kind == SPHEREGRID_SPELL && !already->second.first && spell)
        {
            uint32 const guid = player->GetGUID().GetCounter();

            // Not forgotten: the spell arrived after the purchase, it is
            // learned without paying again (the case login usually settles).
            if (!state->forgotten.count(nodeId))
            {
                already->second.first = spell;
                CharacterDatabase.DirectExecute(
                    "UPDATE mod_spheregrid_character_node SET content_entry = {} WHERE guid = {} AND node_id = {}",
                    spell, guid, nodeId);
                Recompute(player);
                return SphereGridActivation::Ok;
            }

            // COST BY DISTANCE: relearning costs the price of the cell itself,
            // just like activating it.
            uint32 const price = sSphereGridMgr->ActivationCost(player->getClass(), nodeId);
            if (state->Available() < price)
                return SphereGridActivation::NotEnoughPoints;

            state->spent += price;
            already->second.first = spell;
            state->forgotten.erase(nodeId);

            auto trans = CharacterDatabase.BeginTransaction();
            trans->Append("UPDATE mod_spheregrid_character_node SET content_entry = {}, forgotten = 0 WHERE guid = {} AND node_id = {}",
                spell, guid, nodeId);
            trans->Append("REPLACE INTO mod_spheregrid_account_points (account_id, earned, prisms) VALUES ({}, {}, {})",
                AccountOf(player), state->earned, state->prisms);
            trans->Append("REPLACE INTO mod_spheregrid_character_points (guid, spent) VALUES ({}, {})",
                guid, state->spent);
            CharacterDatabase.DirectCommitTransaction(trans);

            Recompute(player);
            return SphereGridActivation::Ok;
        }
        return SphereGridActivation::AlreadyActive;
    }

    // Reachable: the class start, or a neighbour of an active cell. The start is
    // ALWAYS the one of the player's class: on a shared grid, every class shares
    // the cells but each one has its own start.
    bool accessible = (sSphereGridMgr->Start(player->getClass()) == nodeId);
    if (!accessible)
        for (uint32 voisin : def->neighbours)
            if (state->actives.count(voisin))
            {
                accessible = true;
                break;
            }
    if (!accessible)
        return SphereGridActivation::NotAdjacent;

    // COST BY DISTANCE: the price depends on the POSITION of the cell, not on
    // how many nodes are already active. The start, at distance zero, is
    // therefore free.
    uint32 const cout = sSphereGridMgr->ActivationCost(player->getClass(), nodeId);
    if (state->Available() < cout)
        return SphereGridActivation::NotEnoughPoints;

    // Activating a node applies its pre-filled stone (nothing for an empty
    // node); a socket stays empty; a spell cell records its spell — the actual
    // learning comes with the recomputation of the effects.
    uint32 content = 0;
    if (def->kind == SPHEREGRID_NODE)
    {
        // The account may already have filled or emptied this node: that is
        // what the character receives, not the original stone.
        auto accountRow = state->accountContent.find(nodeId);
        content = (accountRow != state->accountContent.end()) ? accountRow->second.first : def->defaultStoneEntry;
    }
    else if (def->kind == SPHEREGRID_SPELL)
        content = spell;

    // BUYING BACK AFTER A RESET: the rune the socket carried never left it, it
    // comes back with it, upgrade included. Stone nodes follow their ACCOUNT row,
    // read just above; a spell cell takes the class spell again.
    uint8 upgrade = 0;
    if (def->kind == SPHEREGRID_SOCKET)
    {
        auto inactive = state->inactiveContent.find(nodeId);
        if (inactive != state->inactiveContent.end())
        {
            content = inactive->second.first;
            upgrade = inactive->second.second;
        }
    }
    state->inactiveContent.erase(nodeId);

    state->spent += cout;
    state->actives[nodeId] = { content, upgrade };

    // Synchronous, like the points writes: the interface reads the database
    // back immediately.
    uint32 const guid = player->GetGUID().GetCounter();
    auto trans = CharacterDatabase.BeginTransaction();
    trans->Append("REPLACE INTO mod_spheregrid_character_node (guid, node_id, content_entry, content_upgrade, active) "
        "VALUES ({}, {}, {}, {}, 1)", guid, nodeId, content, upgrade);
    trans->Append("REPLACE INTO mod_spheregrid_account_points (account_id, earned, prisms) VALUES ({}, {}, {})",
        AccountOf(player), state->earned, state->prisms);
    trans->Append("REPLACE INTO mod_spheregrid_character_points (guid, spent) VALUES ({}, {})",
        guid, state->spent);
    CharacterDatabase.DirectCommitTransaction(trans);

    // A node applies its pre-filled stone on the spot; a spell cell learns its
    // own spell.
    Recompute(player);
    return SphereGridActivation::Ok;
}

// Immediate AND synchronous write of the counters, shared by every points
// mutation. Synchronous on purpose: the player interface reads the database back
// right after a purchase — an asynchronous write would show it the state from
// before. These mutations are rare, the cost is negligible.
static void SavePoints(Player* player, SphereGridPlayerState const& state)
{
    CharacterDatabase.DirectExecute(
        "REPLACE INTO mod_spheregrid_account_points (account_id, earned, prisms) VALUES ({}, {}, {})",
        AccountOf(player), state.earned, state.prisms);
    CharacterDatabase.DirectExecute(
        "REPLACE INTO mod_spheregrid_character_points (guid, spent) VALUES ({}, {})",
        player->GetGUID().GetCounter(), state.spent);
}

bool SphereGridPlayerMgr::AddPoints(Player* player, uint32 amount,
                                      uint32 text, std::string const& name)
{
    SphereGridPlayerState* state = State(player);
    if (!state || !amount)
        return false;

    state->earned += amount;
    SavePoints(player, *state);

    // ALWAYS both arguments, in the same order, whatever the string: {0} the
    // name, {1} the amount. A string with no name uses {1} only — a spare
    // argument does not bother the formatter.
    ChatHandler(player->GetSession()).PSendModuleSysMessage(SPHEREGRID_MODULE, text, name, amount);
    return true;
}

uint32 SphereGridPlayerMgr::Boosted(Player* player, uint32 amount)
{
    SphereGridPlayerState* state = State(player);
    if (!state)
        return amount;
    // PRISMATIC NEXUS: every prism absorbed by the account boosts the gains,
    // with no cap — the second one adds as much as the first, and so on.
    uint64 const majore = uint64(amount) * (100ull + 25ull * state->prisms) / 100ull;
    return uint32(std::min<uint64>(majore, 0xFFFFFFFFull));
}

bool SphereGridPlayerMgr::Earn(Player* player, uint32 amount,
                               uint32 text, std::string const& name)
{
    if (!State(player) || !amount)
        return false;
    return AddPoints(player, Boosted(player, amount), text, name);
}

bool SphereGridPlayerMgr::AbsorbPrism(Player* player)
{
    SphereGridPlayerState* state = State(player);
    if (!state)
        return false;
    ++state->prisms;
    SavePoints(player, *state);
    ChatHandler(player->GetSession()).PSendModuleSysMessage(SPHEREGRID_MODULE, SPHEREGRID_STR_PRISM,
        state->prisms, 25 * state->prisms);
    return true;
}

bool SphereGridPlayerMgr::RemovePoints(Player* player, uint32 amount, uint32& removed)
{
    removed = 0;
    SphereGridPlayerState* state = State(player);
    if (!state)
        return false;

    removed = std::min(amount, state->Available());
    if (removed)
    {
        state->earned -= removed;
        SavePoints(player, *state);
        ChatHandler(player->GetSession()).PSendModuleSysMessage(SPHEREGRID_MODULE, SPHEREGRID_STR_LOSS_GENERIC, removed);
    }
    return true;
}

bool SphereGridPlayerMgr::SetPoints(Player* player, uint32 available)
{
    SphereGridPlayerState* state = State(player);
    if (!state)
        return false;

    state->earned = state->spent + available;
    SavePoints(player, *state);

    ChatHandler(player->GetSession()).PSendModuleSysMessage(SPHEREGRID_MODULE, SPHEREGRID_STR_SET_GENERIC, available);
    return true;
}

void SphereGridPlayerMgr::CreditBoss(Player* killer, Creature* creature)
{
    if (!killer || !creature)
        return;

    // Performance guard: this hook fires on EVERY creature killed on the whole
    // server. Two flag tests discard anything that is not a boss.
    bool const dungeonBoss = creature->IsDungeonBoss();
    bool const bossMonde  = creature->isWorldBoss();
    if (!dungeonBoss && !bossMonde)
        return;

    Map* map = creature->FindMap();
    if (!map)
        return;

    // THE AWARD IS READ BY MAP AND DIFFICULTY: the value of an instance is
    // map x 10 + difficulty rank (1 = 10 normal, 2 = 25 normal, 3 = 10 heroic,
    // 4 = 25 heroic). We look for the exact row, then for "any difficulty"
    // (map x 10), then for the default of the type. A world boss outside an
    // instance has its own type, looked up by creature entry.
    char const* type;
    uint32 points = 0;
    if (map->IsDungeon())
    {
        type = map->IsRaid() ? "raid_boss" : "dungeon_boss";
        points = sSphereGridMgr->PointsForInstance(type, map);
    }
    else if (bossMonde)
    {
        type = "boss_monde";
        points = sSphereGridMgr->PointsForSource(type, creature->GetEntry());
    }
    else
        return;

    if (!points)
        return;

    // The whole group present in the same map is credited: the killing blow
    // often belongs to another member, or even to a pet. Players with no loaded
    // state are discarded naturally, since AddPoints requires one. The boss name
    // is read again FOR EACH MEMBER: in a mixed group everyone reads it in his
    // own language.
    if (Group* group = killer->GetGroup())
    {
        for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
        {
            Player* membre = ref->GetSource();
            if (membre && membre->FindMap() == map)
                Earn(membre, points, SPHEREGRID_STR_GAIN_BOSS,
                       creature->GetNameForLocaleIdx(DbLocaleOf(membre)));
        }
    }
    else
        Earn(killer, points, SPHEREGRID_STR_GAIN_BOSS,
               creature->GetNameForLocaleIdx(DbLocaleOf(killer)));
}

bool SphereGridPlayerMgr::CreditSource(Player* player, std::string const& type, uint32 value,
                                       uint32 text, std::string const& name)
{
    uint32 const points = sSphereGridMgr->PointsForSource(type, value);
    if (!points)
        return false;
    return Earn(player, points, text, name);
}

bool SphereGridPlayerMgr::CreditInstance(Player* player, std::string const& type, Map const* map)
{
    uint32 const points = sSphereGridMgr->PointsForInstance(type, map);
    if (!points)
        return false;

    // The only use is a dungeon completed, so the message quotes the dungeon,
    // named from Map.dbc in the player's language.
    std::string const name = map && map->GetEntry()
        ? FromDbc(map->GetEntry()->name, DbcLocaleOf(player)) : "";
    return Earn(player, points, SPHEREGRID_STR_GAIN_DUNGEON, name);
}

// A LEVEL GAINED: "the award x the new level". The award is not in the code, it
// is the (level, 0) row like every other one. A jump of several levels (a
// command, a quest with a large experience reward) credits each level crossed,
// not only the last. The core calls the hook once per GiveLevel, after setting
// the new level.
bool SphereGridPlayerMgr::CreditLevel(Player* player, uint8 oldLevel)
{
    if (!player || !State(player))
        return false;
    uint8 const nouveau = player->GetLevel();
    if (nouveau <= oldLevel)
        return false;                       // a level lost (a GM tool): nothing
    uint32 const parNiveau = sSphereGridMgr->ExactPointsForSource("level", 0);
    if (!parNiveau)
        return false;
    uint32 total = 0;
    for (uint32 n = uint32(oldLevel) + 1; n <= nouveau; ++n)
        total += parNiveau * n;
    // Nothing to quote: the string uses the amount only.
    return Earn(player, total, SPHEREGRID_STR_GAIN_LEVEL);
}

// Has an achievement ALREADY been earned by ANOTHER character of the account?
//
// There is no "account achievements" table: a module granting them account-wide
// keeps none, it reads character_achievement of every character of the account
// at each login. That same union is what is authoritative here.
//
// The CURRENT character is excluded on purpose. When the hook fires, the core
// has just recorded the achievement in memory but not yet in the database —
// excluding it avoids depending on that detail, and answers the real question:
// "did somebody else already have it?".
static bool AlreadyEarnedOnAccount(Player* player, uint32 achievementId)
{
    return CharacterDatabase.Query(
        "SELECT 1 FROM character_achievement ca "
        "JOIN characters c ON c.guid = ca.guid "
        "WHERE c.account = {} AND ca.achievement = {} AND ca.guid <> {} LIMIT 1",
        AccountOf(player), achievementId, player->GetGUID().GetCounter()) != nullptr;
}

bool SphereGridPlayerMgr::CreditAchievement(Player* player, AchievementEntry const* achievement)
{
    if (!player || !achievement)
        return false;

    // Three filters BEFORE the query, from the cheapest to the dearest. This
    // hook fires in bursts at the first login of a fresh character, when a module
    // hands it the whole account history at once — and the database must not be
    // queried hundreds of times for nothing.
    if (!State(player))
        return false;                       // bots, and players with no state loaded
    if (!achievement->points)
        return false;                       // an achievement with no score is worth nothing

    uint32 const multiplicateur = sSphereGridMgr->ExactPointsForSource("achievement", 0);
    if (!multiplicateur)
        return false;                       // source disabled: no row

    if (AlreadyEarnedOnAccount(player, achievement->ID))
        return false;                       // already paid for on another character

    return Earn(player, achievement->points * multiplicateur, SPHEREGRID_STR_GAIN_ACHIEVEMENT,
                  FromDbc(achievement->name.data(), DbcLocaleOf(player)));
}

// ---------------------------------------------------------------------------
// Applying the statistics
// ---------------------------------------------------------------------------
// The catalogue of the 16 statistics is mapped here onto the core API. This is
// the ONLY hardcoded correspondence of the module — the amounts themselves all
// come from the data. No aura, no DBC: direct modifiers, applied and removed by
// hand. They do not survive a logout, hence the recomputation at every login.
static void ApplyStat(Player* p, uint8 stat, int32 v, bool put)
{
    if (!v)
        return;

    switch (stat)
    {
        case 1:  p->HandleStatFlatModifier(UNIT_MOD_STAT_STAMINA,   TOTAL_VALUE, float(v), put); break;
        case 2:  p->HandleStatFlatModifier(UNIT_MOD_STAT_INTELLECT, TOTAL_VALUE, float(v), put); break;
        case 3:  p->HandleStatFlatModifier(UNIT_MOD_STAT_SPIRIT,    TOTAL_VALUE, float(v), put); break;
        case 4:  p->HandleStatFlatModifier(UNIT_MOD_STAT_AGILITY,   TOTAL_VALUE, float(v), put); break;
        case 5:  p->HandleStatFlatModifier(UNIT_MOD_STAT_STRENGTH,  TOTAL_VALUE, float(v), put); break;
        case 6:  p->ApplyRatingMod(CR_PARRY, v, put); break;
        case 7:  p->ApplyRatingMod(CR_BLOCK, v, put); break;
        case 8:  p->ApplyRatingMod(CR_DODGE, v, put); break;
        // Haste, critical strike and hit cover the three schools: a single
        // sphere grid statistic, three combat ratings.
        case 9:
            p->ApplyRatingMod(CR_HASTE_MELEE,  v, put);
            p->ApplyRatingMod(CR_HASTE_RANGED, v, put);
            p->ApplyRatingMod(CR_HASTE_SPELL,  v, put);
            break;
        case 10:
            p->ApplyRatingMod(CR_CRIT_MELEE,  v, put);
            p->ApplyRatingMod(CR_CRIT_RANGED, v, put);
            p->ApplyRatingMod(CR_CRIT_SPELL,  v, put);
            break;
        case 11:
            p->ApplyRatingMod(CR_HIT_MELEE,  v, put);
            p->ApplyRatingMod(CR_HIT_RANGED, v, put);
            p->ApplyRatingMod(CR_HIT_SPELL,  v, put);
            break;
        // SPELL POWER RAISES DAMAGE ONLY. The core's ApplySpellPowerBonus
        // raises healing as well -- that is what "spell power" means on a
        // piece of gear in Wrath, one stat for both. The grid has TWO
        // statistics, spell power and healing bonus, and a player who buys
        // one must not be given the other: the damage-only call is the one
        // that keeps them apart.
        case 12: p->ApplySpellDamageBonus(v, put); break;
        case 13: p->HandleStatFlatModifier(UNIT_MOD_ATTACK_POWER, TOTAL_VALUE, float(v), put); break;
        case 14: p->ApplyRatingMod(CR_ARMOR_PENETRATION, v, put); break;
        case 15: p->ApplyRatingMod(CR_EXPERTISE, v, put); break;
        case 16: p->ApplySpellHealingBonus(v, put); break;
        default: break;
    }
}

// The extra ranks granted by the runes, for a given player.
//
// The rule: runes add up, and the player KNOWS every rank — two runes of the
// same spell grant ranks 11 AND 12. But a custom rank only exists as long as the
// player knows the last Blizzard rank it follows: a talent forgotten disables
// its runes on the spot, without losing them. That is what HasSpell checks on
// the base rank.
namespace
{
    // Our ranks live above this bound; below it, everything is Blizzard's.
    constexpr uint32 SPHEREGRID_CUSTOM_RANK_MIN = 8500000;

    // The last Blizzard rank of a family, walking the chain up from any of ours.
    // Used when the LAST rune of a family has just been removed: there is nothing
    // left in hand to find the rank the player must fall back to.
    uint32 LastBlizzardRank(uint32 spellId)
    {
        while (spellId >= SPHEREGRID_CUSTOM_RANK_MIN)
        {
            uint32 const precedent = sSpellMgr->GetPrevSpellInChain(spellId);
            if (!precedent)
                return 0;
            spellId = precedent;
        }
        return spellId;
    }
}

void SphereGridPlayerMgr::SyncRunes(Player* player, SphereGridPlayerState const& state)
{
    // How many runes of each family are socketed.
    std::unordered_map<uint32, uint8> counts;
    for (auto const& [nodeId, content] : state.actives)
    {
        if (!content.first)
            continue;
        if (sSphereGridMgr->Rune(content.first))
            ++counts[content.first];
    }

    // `tops` keeps, per family, the highest rank the player must SEE: the last
    // of ours he keeps, or the last Blizzard rank when he has no rune left.
    std::unordered_set<uint32> toKnow;
    std::unordered_map<uint32, uint32> tops;

    for (auto const& [itemEntry, count] : counts)
    {
        SphereGridRune const* rune = sSphereGridMgr->Rune(itemEntry);
        if (!rune || !rune->firstSpellId)
            continue;

        // The Blizzard rank must be known, otherwise the rune stays inert.
        uint32 const baseRank = sSpellMgr->GetSpellWithRank(rune->firstSpellId, rune->baseRank, true);
        if (!baseRank || !player->HasSpell(baseRank))
            continue;

        uint32 top = baseRank;
        uint8 const granted = std::min<uint8>(count, SphereGridMgr::RUNES_PER_SPELL);
        for (uint8 i = 1; i <= granted; ++i)
            if (uint32 spellId = sSpellMgr->GetSpellWithRank(rune->firstSpellId,
                                                             rune->baseRank + i, true))
            {
                toKnow.insert(spellId);
                top = spellId;
            }
        tops[rune->firstSpellId] = top;
    }

    auto& applied = _grantedRanks[player->GetGUID()];

    // The PREVIOUS top, family by family: it is the id the client is displaying
    // right now, and therefore the one it must be told to replace if we go back
    // down.
    std::unordered_map<uint32, uint32> previous;
    for (uint32 spellId : applied)
    {
        uint32 const bliz = LastBlizzardRank(spellId);
        if (!bliz)
            continue;
        uint32 const firstRank = sSpellMgr->GetFirstSpellInChain(bliz);
        uint32& former = previous[firstRank];
        if (spellId > former)
            former = spellId;
    }

    // A family whose LAST rune has just been removed is not in `counts` any
    // more: its top goes back to the Blizzard rank, found by walking the chain up
    // from the rank we are about to remove.
    for (uint32 spellId : applied)
    {
        if (toKnow.count(spellId))
            continue;
        uint32 const bliz = LastBlizzardRank(spellId);
        if (!bliz)
            continue;
        uint32 const firstRank = sSpellMgr->GetFirstSpellInChain(bliz);
        if (!tops.count(firstRank))
            tops[firstRank] = bliz;
    }

    // THE CLIENT DOES NOT GUESS THAT A RANK GOES BACK DOWN. Learning a higher
    // rank is announced to it by SMSG_SUPERCEDED_SPELL — "this spell becomes that
    // one" — and nothing exists the other way round: the spell book stayed on its
    // old display, the damage of the lower rank under the label of the higher
    // one, until a /reload. We send it the same packet reversed, and BEFORE the
    // removal: afterwards it would no longer know the id to replace. That is also
    // what makes the action bar button follow.
    for (auto const& [firstRank, top] : tops)
    {
        auto const former = previous.find(firstRank);
        if (former == previous.end() || !top || former->second <= top)
            continue;   // going up, or nothing moves: addSpell sees to it

        WorldPacket data(SMSG_SUPERCEDED_SPELL, 8);
        data << uint32(former->second);
        data << uint32(top);
        player->SendDirectMessage(&data);
    }

    // What the player must know, and nothing more: whatever no longer belongs is
    // removed first — the removal from the top of the stack, which falls out
    // naturally since we start again from the wanted set.
    for (uint32 spellId : applied)
        if (!toKnow.count(spellId) && player->HasSpell(spellId))
            player->removeSpell(spellId, SPEC_MASK_ALL, false);

    for (uint32 spellId : toKnow)
        if (!player->HasSpell(spellId))
            player->learnSpell(spellId);

    // HANDING CONTROL BACK TO THE PREVIOUS RANK. Learning a higher rank
    // DISABLES the lower ones (Player::addSpell: Active = false plus
    // SMSG_SUPERCEDED_SPELL) and Player::removeSpell never does the opposite — it
    // says so in as many words: "can't be replaced by previous rank". Removing a
    // rune therefore left the player with NO rank at all, and for good, since
    // SendInitialSpells skips inactive spells.
    // addSpell cannot be used, it refuses to touch a spell already known in the
    // right spec; nor can removeSpell + learnSpell, which would take away the
    // spells REQUIRING that one (spell_required) without giving them back. So the
    // flag is turned back on by hand.
    PlayerSpellMap& spells = player->GetSpellMap();
    for (auto const& [firstRank, top] : tops)
    {
        if (!top)
            continue;
        auto it = spells.find(top);
        if (it == spells.end() || !it->second)
            continue;
        if (it->second->Active || it->second->State == PLAYERSPELL_REMOVED)
            continue;

        it->second->Active = true;
        if (it->second->State != PLAYERSPELL_NEW && it->second->State != PLAYERSPELL_TEMPORARY)
            it->second->State = PLAYERSPELL_CHANGED;
        // Belt and braces after the replacement announced above: should the
        // client have ignored it, this packet still puts the spell back in its
        // book. It has no effect when the client already knows it.
        player->SendLearnPacket(top, true);
    }

    applied = std::move(toKnow);
}

// From the talent hooks: the state is already loaded, nothing to do but set the
// ranks straight again.
void SphereGridPlayerMgr::SyncRunes(Player* player)
{
    if (SphereGridPlayerState* state = State(player))
        SyncRunes(player, *state);
}

void SphereGridPlayerMgr::Recompute(Player* player)
{
    SphereGridPlayerState* state = State(player);
    if (!state)
        return;

    SphereGridStatBlock fresh{};
    for (auto const& [nodeId, content] : state->actives)
    {
        SphereGridCell const* def = sSphereGridMgr->Cell(nodeId);
        if (!def || !content.first)
            continue;

        if (def->kind == SPHEREGRID_SPELL)
        {
            // A spell cell brings no statistic: it teaches its spell. Nothing is
            // ever removed here — forgetting is what the pin does, explicitly.
            if (!player->HasSpell(content.first))
                player->learnSpell(content.first);
            continue;
        }

        if (SphereGridStone const* stone = sSphereGridMgr->Stone(content.first))
            if (stone->statId >= 1 && stone->statId <= SPHEREGRID_STAT_COUNT)
                fresh[stone->statId] += stone->amount;
    }

    // STATISTIC runes boost what the grid has just given: they therefore apply
    // AFTER the sum of the stones, and never on a raw value. They stack, capped
    // like the rank runes.
    uint8 nbParStat[SPHEREGRID_STAT_COUNT + 1] = {};
    uint32 pctParStat[SPHEREGRID_STAT_COUNT + 1] = {};
    for (auto const& [nodeId, content] : state->actives)
    {
        if (!content.first)
            continue;
        SphereGridStatRune const* rs = sSphereGridMgr->StatRune(content.first);
        if (!rs || rs->statId < 1 || rs->statId > SPHEREGRID_STAT_COUNT)
            continue;
        if (nbParStat[rs->statId] >= SphereGridMgr::RUNES_PER_SPELL)
            continue;
        ++nbParStat[rs->statId];
        pctParStat[rs->statId] += rs->percent;
    }
    for (uint8 st = 1; st <= SPHEREGRID_STAT_COUNT; ++st)
        if (pctParStat[st] && fresh[st])
            fresh[st] += int32(int64(fresh[st]) * pctParStat[st] / 100);

    SyncRunes(player, *state);

    // The old block removed, the new one applied: never incremental.
    auto it = _statBlocks.find(player->GetGUID());
    if (it != _statBlocks.end())
        for (uint8 s = 1; s <= SPHEREGRID_STAT_COUNT; ++s)
            ApplyStat(player, s, it->second[s], false);

    for (uint8 s = 1; s <= SPHEREGRID_STAT_COUNT; ++s)
        ApplyStat(player, s, fresh[s], true);

    _statBlocks[player->GetGUID()] = fresh;
    player->UpdateAllStats();
}

SphereGridStatBlock const* SphereGridPlayerMgr::StatBlock(Player* player) const
{
    if (!player)
        return nullptr;
    auto it = _statBlocks.find(player->GetGUID());
    return it != _statBlocks.end() ? &it->second : nullptr;
}

SphereGridSocketing SphereGridPlayerMgr::Socket(Player* player, uint32 nodeId, uint32 itemEntry)
{
    SphereGridPlayerState* state = State(player);
    if (!state)
        return SphereGridSocketing::NoState;

    SphereGridCell const* def = sSphereGridMgr->Cell(nodeId);
    if (!def)
        return SphereGridSocketing::UnknownCell;

    auto active = state->actives.find(nodeId);
    if (active == state->actives.end())
        return SphereGridSocketing::NotActive;
    if (active->second.first)
        return SphereGridSocketing::AlreadyFilled;

    // A node accepts stones only, a socket runes only; a spell cell cannot be
    // socketed at all. A socket accepts BOTH kinds of rune: those granting a
    // rank, and those boosting a statistic.
    SphereGridRune const* rune = sSphereGridMgr->Rune(itemEntry);
    SphereGridStatRune const* runeStat = sSphereGridMgr->StatRune(itemEntry);
    bool const stone = sSphereGridMgr->Stone(itemEntry) != nullptr;
    if (def->kind == SPHEREGRID_NODE && !stone)
        return SphereGridSocketing::WrongKind;
    if (def->kind == SPHEREGRID_SOCKET && !rune && !runeStat)
        return SphereGridSocketing::WrongKind;
    if (def->kind != SPHEREGRID_NODE && def->kind != SPHEREGRID_SOCKET)
        return SphereGridSocketing::WrongKind;

    // A RANK rune belongs to a class: it drops with no condition, but it can
    // only be socketed in the grid of its own class. Statistic runes have no such
    // tie, they boost what the grid gives whatever the class.
    if (rune && rune->classId && rune->classId != player->getClass())
        return SphereGridSocketing::WrongClass;

    // Three identical runes at most in the whole grid: beyond that the fourth
    // rank does not exist and the rune would be lost for nothing. The same cap
    // applies to statistic runes, by the same rule.
    if (rune || runeStat)
    {
        uint8 already = 0;
        for (auto const& [other, content] : state->actives)
            if (content.first == itemEntry)
                ++already;
        if (already >= SphereGridMgr::RUNES_PER_SPELL)
            return SphereGridSocketing::TooManyRunes;
    }

    if (!player->HasItemCount(itemEntry, 1))
        return SphereGridSocketing::ItemMissing;

    player->DestroyItemCount(itemEntry, 1, true);
    active->second.first = itemEntry;

    CharacterDatabase.DirectExecute(
        "UPDATE mod_spheregrid_character_node SET content_entry = {} WHERE guid = {} AND node_id = {}",
        itemEntry, player->GetGUID().GetCounter(), nodeId);
    // A stone in a node holds for the whole account.
    if (def->kind == SPHEREGRID_NODE)
    {
        state->accountContent[nodeId] = { itemEntry, uint8(0) };
        CharacterDatabase.DirectExecute(
            "REPLACE INTO mod_spheregrid_account_node (account_id, node_id, content_entry, content_upgrade) "
            "VALUES ({}, {}, {}, 0)", AccountOf(player), nodeId, itemEntry);
    }

    Recompute(player);
    player->PlayDirectSound(def->kind == SPHEREGRID_NODE ? SPHEREGRID_SOUND_STONE
                                                         : SPHEREGRID_SOUND_RUNE, player);
    return SphereGridSocketing::Ok;
}

SphereGridSocketing SphereGridPlayerMgr::Unsocket(Player* player, uint32 nodeId, bool consumePin)
{
    SphereGridPlayerState* state = State(player);
    if (!state)
        return SphereGridSocketing::NoState;

    SphereGridCell const* def = sSphereGridMgr->Cell(nodeId);
    if (!def)
        return SphereGridSocketing::UnknownCell;

    auto active = state->actives.find(nodeId);
    if (active == state->actives.end())
        return SphereGridSocketing::NotActive;
    if (!active->second.first)
        return SphereGridSocketing::AlreadyFilled;    // already empty: nothing to clear

    uint32 const pin = sSphereGridMgr->PinEntry();
    if (consumePin)
    {
        if (!pin || !player->HasItemCount(pin, 1))
            return SphereGridSocketing::ItemMissing;
        player->DestroyItemCount(pin, 1, true);
    }

    // On a spell cell, the spell is forgotten but stays in the grid: the cell
    // remains active and can be learned again.
    if (def->kind == SPHEREGRID_SPELL)
    {
        player->removeSpell(active->second.first, SPEC_MASK_ALL, false);
        state->forgotten.insert(nodeId);       // a new purchase teaches it again
    }

    active->second.first = 0;
    active->second.second = 0;

    CharacterDatabase.DirectExecute(
        "UPDATE mod_spheregrid_character_node SET content_entry = 0, content_upgrade = 0, forgotten = {} "
        "WHERE guid = {} AND node_id = {}", (def->kind == SPHEREGRID_SPELL) ? 1 : 0,
        player->GetGUID().GetCounter(), nodeId);
    // A node emptied with the pin is empty for the whole account.
    if (def->kind == SPHEREGRID_NODE)
    {
        state->accountContent[nodeId] = { 0, uint8(0) };
        CharacterDatabase.DirectExecute(
            "REPLACE INTO mod_spheregrid_account_node (account_id, node_id, content_entry, content_upgrade) "
            "VALUES ({}, {}, 0, 0)", AccountOf(player), nodeId);
    }

    Recompute(player);
    player->PlayDirectSound(def->kind == SPHEREGRID_SPELL ? SPHEREGRID_SOUND_FORGET
                                                          : SPHEREGRID_SOUND_UNDONE, player);
    return SphereGridSocketing::Ok;
}

// EVERY SPELL THE GRID TAUGHT THIS CHARACTER, taken back. The state is what
// says which: a spell cell keeps in its content the spell it granted.
// `Recompute` never removes anything -- it only learns what the ACTIVE cells
// ask for -- so a reset that merely emptied the state left every spell in the
// book with no cell left to justify it.
void SphereGridPlayerMgr::ForgetSpells(Player* player,
                                       SphereGridPlayerState const& state)
{
    if (!player)
        return;
    for (auto const& [nodeId, content] : state.actives)
    {
        SphereGridCell const* def = sSphereGridMgr->Cell(nodeId);
        if (def && def->kind == SPHEREGRID_SPELL && content.first)
            player->removeSpell(content.first, SPEC_MASK_ALL, false);
    }
}

// Every spell a spell cell of the grid can teach, as an SQL list. Used to
// reach the characters of an account who are not connected: nobody holds
// their state, and their next login removes nothing.
std::string SphereGridPlayerMgr::TaughtSpellList()
{
    std::string out;
    for (auto const& [nodeId, cell] : sSphereGridMgr->Cells())
    {
        if (cell.kind != SPHEREGRID_SPELL || !cell.spellId)
            continue;
        if (!out.empty())
            out += ",";
        out += std::to_string(cell.spellId);
    }
    return out;
}

void SphereGridPlayerMgr::Reset(Player* player)
{
    if (!player)
        return;

    // THE SPELLS FIRST, while the state still says which ones were given.
    if (SphereGridPlayerState const* state = State(player))
        ForgetSpells(player, *state);

    uint32 const guid = player->GetGUID().GetCounter();
    auto trans = CharacterDatabase.BeginTransaction();
    trans->Append("DELETE FROM mod_spheregrid_character_node WHERE guid = {}", guid);
    // THE ACCOUNT SPHERITE SURVIVES: only what THIS character spent is erased.
    // Erasing the account row here would ruin all its other characters for the
    // sake of resetting one.
    trans->Append("DELETE FROM mod_spheregrid_character_points WHERE guid = {}", guid);
    CharacterDatabase.DirectCommitTransaction(trans);

    auto it = _states.find(player->GetGUID());
    if (it != _states.end())
    {
        uint32 const earned = it->second.earned;   // the account's, not the character's
        auto accountContent = std::move(it->second.accountContent);   // au accountRow aussi
        it->second = SphereGridPlayerState();
        it->second.earned = earned;
        it->second.accountContent = std::move(accountContent);
    }

    // Recomputation on an empty state: removes everything the grid had applied.
    Recompute(player);
    player->PlayDirectSound(SPHEREGRID_SOUND_RESET, player);
}

// PLAYER-TRIGGERED RESET — the interface button, through `.spheregrid respec`.
// It concerns ONLY the connected character.
//
// What goes: every activation, and the spells the spell cells had taught —
// unlearned here as with the pin, failing which the refund would make them a
// permanent gift.
// What stays: the stones and runes socketed. The cell row is not erased, it goes
// to active = 0 keeping its content; the next purchase of the cell finds it
// untouched.
// What comes back: the Spherite spent by THIS character (spent back to zero).
// What was earned lives on the account and is not touched.
uint32 SphereGridPlayerMgr::ResetProgression(Player* player)
{
    SphereGridPlayerState* state = State(player);
    if (!state)
        return 0;

    uint32 const refunded = state->spent;

    // The spells first: the state is what says which ones the grid taught.
    ForgetSpells(player, *state);
    for (auto const& [nodeId, content] : state->actives)
        state->inactiveContent[nodeId] = content;
    state->actives.clear();
    // A cell given back is not bought any more: forgetting with the pin, which
    // only made sense for an active cell, no longer has an object.
    state->forgotten.clear();
    state->spent = 0;

    uint32 const guid = player->GetGUID().GetCounter();
    auto trans = CharacterDatabase.BeginTransaction();
    trans->Append("UPDATE mod_spheregrid_character_node SET active = 0, forgotten = 0 WHERE guid = {}", guid);
    // Nothing spent any more: the spending row disappears — it will be born
    // again at the first purchase — and the account Spherite becomes wholly
    // available.
    trans->Append("DELETE FROM mod_spheregrid_character_points WHERE guid = {}", guid);
    CharacterDatabase.DirectCommitTransaction(trans);

    // Recomputation on an empty grid: everything the grid had applied falls,
    // rune ranks included (SyncRunes).
    Recompute(player);
    // THE BUTTON'S OWN PATH. `Reset` is the game master's command; this is what
    // the player presses, so this is where he must hear his grid go.
    player->PlayDirectSound(SPHEREGRID_SOUND_RESET, player);
    return refunded;
}

// THE WHOLE ACCOUNT, at once: the Spherite earned and the grids of ALL its
// characters, online or not.
//
// THREE DELETIONS AND NOT TWO. `Reset` touches a single character and leaves the
// account Spherite alone on purpose — here we want it as well. The joins on
// `characters` are what reaches the offline characters: their state lives only in
// the database, nobody holds it in memory.
//
// THE IN-MEMORY STATE is only cleared for the player passed in: an account has a
// single session, its other characters will read the database again at their next
// login.
uint32 SphereGridPlayerMgr::WipeAccount(Player* player)
{
    if (!player)
        return 0;

    uint32 const accountRow = AccountOf(player);
    if (!accountRow)
        return 0;

    // The connected character hands his spells back at once; the others are
    // reached in the database, below.
    if (SphereGridPlayerState const* state = State(player))
        ForgetSpells(player, *state);

    uint32 count = 0;
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT COUNT(*) FROM characters WHERE account = {}", accountRow))
    {
        count = result->Fetch()[0].Get<uint32>();
    }

    auto trans = CharacterDatabase.BeginTransaction();
    trans->Append("DELETE n FROM mod_spheregrid_character_node n "
        "JOIN characters c ON c.guid = n.guid WHERE c.account = {}", accountRow);
    trans->Append("DELETE p FROM mod_spheregrid_character_points p "
        "JOIN characters c ON c.guid = p.guid WHERE c.account = {}", accountRow);
    trans->Append("DELETE FROM mod_spheregrid_account_points WHERE account_id = {}", accountRow);
    trans->Append("DELETE FROM mod_spheregrid_account_node WHERE account_id = {}", accountRow);
    // THE OFFLINE CHARACTERS. Their state lives only in the database and their
    // next login takes nothing away. Only the spells a spell cell can teach are
    // removed, and only from this account.
    std::string const taught = TaughtSpellList();
    if (!taught.empty())
    {
        trans->Append("DELETE s FROM character_spell s "
            "JOIN characters c ON c.guid = s.guid "
            "WHERE c.account = {} AND s.spell IN ({})", accountRow, taught);
    }
    CharacterDatabase.DirectCommitTransaction(trans);

    auto it = _states.find(player->GetGUID());
    if (it != _states.end())
        it->second = SphereGridPlayerState();   // earned included, this time

    Recompute(player);
    return count;
}
