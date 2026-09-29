/*
 * Credits: silviu20092
 */

#include <numeric>
#include <iomanip>
#include <cmath>
#include <limits>
#include "Item.h"
#include "Config.h"
#include "Tokenize.h"
#include "StringConvert.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Chat.h"
#include "ObjectMgr.h"
#include "SpellMgr.h"
#include "WorldSessionMgr.h"
#include "item_upgrade.h"

ItemUpgrade::ItemUpgrade()
{
    reloading = false;
}

ItemUpgrade::~ItemUpgrade()
{
}

ItemUpgrade* ItemUpgrade::instance()
{
    static ItemUpgrade instance;
    return &instance;
}

bool ItemUpgrade::IsAllowedStatType(uint32 statType) const
{
    return FindInContainer(allowedStats, statType) != nullptr;
}

// One value of a comma-separated list of the configuration, without the
// spaces around it.
static std::string_view TrimConfigValue(std::string_view value)
{
    while (!value.empty() && (value.front() == ' ' || value.front() == '\t'))
        value.remove_prefix(1);
    while (!value.empty() && (value.back() == ' ' || value.back() == '\t' || value.back() == '\r'))
        value.remove_suffix(1);
    return value;
}

// A mistyped value of the configuration is reported and skipped, never used.
void ItemUpgrade::LoadAllowedStats(const std::string& stats)
{
    allowedStats.clear();
    for (std::string_view token : Acore::Tokenize(stats, ',', false))
    {
        std::string_view value = TrimConfigValue(token);
        if (value.empty())
            continue;

        Optional<uint32> statType = Acore::StringTo<uint32>(value);
        if (!statType || !IsValidStatType(*statType))
        {
            LOG_ERROR("server.loading", "ItemUpgrade.AllowedStats: `{}` is not a stat type (ItemModType), skipped", value);
            continue;
        }

        allowedStats.push_back(*statType);
    }
}

bool ItemUpgrade::GetBoolConfig(ItemUpgradeBoolConfigs index) const
{
    return cfg.GetBoolConfig(index);
}

std::string ItemUpgrade::GetStringConfig(ItemUpgradeStringConfigs index) const
{
    return cfg.GetStringConfig(index);
}

float ItemUpgrade::GetFloatConfig(ItemUpgradeFloatConfigs index) const
{
    return cfg.GetFloatConfig(index);
}

int32 ItemUpgrade::GetIntConfig(ItemUpgradeIntConfigs index) const
{
    return cfg.GetIntConfig(index);
}

void ItemUpgrade::LoadConfig(bool reload)
{
    cfg.Initialize();
    LoadAllowedStats(cfg.GetStringConfig(CONFIG_ITEM_UPGRADE_ALLOWED_STATS));
    // Damage: any gain above 0 %. Speed: below 100 %, which would leave no time between swings.
    LoadWeaponUpgradePercents(weaponUpgradeStats, characterWeaponUpgradeData, cfg.GetStringConfig(CONFIG_ITEM_UPGRADE_WEAPON_DAMAGE_PERCENTS),
        "ItemUpgrade.UpgradeWeaponDamagePercents", 0.0f);
    LoadWeaponUpgradePercents(weaponSpeedUpgradeStats, characterWeaponSpeedUpgradeData, cfg.GetStringConfig(CONFIG_ITEM_UPGRADE_WEAPON_SPEED_PERCENTS),
        "ItemUpgrade.UpgradeWeaponSpeedPercents", 100.0f);
    if (reload)
    {
        BuildWeaponUpgradeReqs();
        BuildWeaponSpeedUpgradeReqs();
    }
}

void ItemUpgrade::LoadFromDB(bool reload)
{
    LOG_INFO("server.loading", " ");
    LOG_INFO("server.loading", "Loading item upgrade mod custom tables...");

    CleanupDB(reload);

    LoadAllowedItems();
    LoadBlacklistedItems();
    LoadAllowedStatsItems();
    LoadBlacklistedStatsItems();
    LoadStatRequirements();
    LoadStatRequirementsOverrides();

    LoadUpgradeStats();
    if (!CheckDataValidity())
    {
        LOG_ERROR("server.loading", "Found data validity errors while loading item upgrade mod tables. Check the FATAL error messages and fix the issues before attempting to restart the server");
        World::StopNow(ERROR_EXIT_CODE);
        return;
    }

    LoadCharacterUpgradeData();

    LoadCharacterWeaponUpgradeData();
    LoadCharacterWeaponSpeedUpgradeData();

    CreateUpgradesPctMap();
}

void ItemUpgrade::LoadAllowedItems()
{
    allowedItems.clear();

    QueryResult result = CharacterDatabase.Query("SELECT entry FROM mod_item_upgrade_allowed_items");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();

        uint32 entry = fields[0].Get<uint32>();
        const ItemTemplate* itemTemplate = sObjectMgr->GetItemTemplate(entry);
        if (!itemTemplate)
        {
            LOG_ERROR("sql.sql", "Table `mod_item_upgrade_allowed_items` has invalid item entry {}, skip", entry);
            continue;
        }

        allowedItems.insert(entry);
    } while (result->NextRow());
}

void ItemUpgrade::LoadAllowedStatsItems()
{
    allowedStatItems.clear();

    QueryResult result = CharacterDatabase.Query("SELECT stat_id, entry FROM mod_item_upgrade_allowed_stats_items");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();

        uint32 stat_id = fields[0].Get<uint32>();
        uint32 entry = fields[1].Get<uint32>();
        const ItemTemplate* itemTemplate = sObjectMgr->GetItemTemplate(entry);
        if (!itemTemplate)
        {
            LOG_ERROR("sql.sql", "Table `mod_item_upgrade_allowed_stats_items` has invalid item entry {}, skip", entry);
            continue;
        }

        allowedStatItems[stat_id].insert(entry);
    } while (result->NextRow());
}

void ItemUpgrade::LoadBlacklistedItems()
{
    blacklistedItems.clear();

    QueryResult result = CharacterDatabase.Query("SELECT entry FROM mod_item_upgrade_blacklisted_items");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();

        uint32 entry = fields[0].Get<uint32>();
        const ItemTemplate* itemTemplate = sObjectMgr->GetItemTemplate(entry);
        if (!itemTemplate)
        {
            LOG_ERROR("sql.sql", "Table `mod_item_upgrade_blacklisted_items` has invalid item entry {}, skip", entry);
            continue;
        }

        blacklistedItems.insert(entry);
    } while (result->NextRow());
}

void ItemUpgrade::LoadBlacklistedStatsItems()
{
    blacklistedStatItems.clear();

    QueryResult result = CharacterDatabase.Query("SELECT stat_id, entry FROM mod_item_upgrade_blacklisted_stats_items");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();

        uint32 stat_id = fields[0].Get<uint32>();
        uint32 entry = fields[1].Get<uint32>();
        const ItemTemplate* itemTemplate = sObjectMgr->GetItemTemplate(entry);
        if (!itemTemplate)
        {
            LOG_ERROR("sql.sql", "Table `mod_item_upgrade_blacklisted_stats_items` has invalid item entry {}, skip", entry);
            continue;
        }

        blacklistedStatItems[stat_id].insert(entry);
    } while (result->NextRow());
}

void ItemUpgrade::CleanupDB(bool reload)
{
    CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
    trans->Append("DELETE FROM mod_item_upgrade_stats_req WHERE stat_id NOT IN (SELECT id FROM mod_item_upgrade_stats)");
    trans->Append("DELETE FROM mod_item_upgrade_stats_req_override WHERE stat_id NOT IN (SELECT id FROM mod_item_upgrade_stats)");
    trans->Append("DELETE FROM character_item_upgrade WHERE stat_id NOT IN (SELECT id FROM mod_item_upgrade_stats)");
    if (!reload)
    {
        trans->Append("DELETE FROM character_item_upgrade WHERE NOT EXISTS (SELECT 1 FROM item_instance WHERE item_instance.guid = character_item_upgrade.item_guid)");
        trans->Append("DELETE FROM character_weapon_upgrade WHERE NOT EXISTS (SELECT 1 FROM item_instance WHERE item_instance.guid = character_weapon_upgrade.item_guid)");
        trans->Append("DELETE FROM character_weapon_speed_upgrade WHERE NOT EXISTS (SELECT 1 FROM item_instance WHERE item_instance.guid = character_weapon_speed_upgrade.item_guid)");
    }
    trans->Append("DELETE FROM mod_item_upgrade_allowed_stats_items WHERE stat_id NOT IN (SELECT id FROM mod_item_upgrade_stats)");
    trans->Append("DELETE FROM mod_item_upgrade_blacklisted_stats_items WHERE stat_id NOT IN (SELECT id FROM mod_item_upgrade_stats)");
    CharacterDatabase.DirectCommitTransaction(trans);
}

void ItemUpgrade::MergeStatRequirements(std::unordered_map<uint32, StatRequirementContainer>& statRequirementMap, bool validate)
{
    for (auto& statPair : statRequirementMap)
    {
        StatRequirementContainer newStatReq;

        float copperTotal = std::accumulate(statPair.second.begin(), statPair.second.end(), 0.0f,
            [](float a, const UpgradeStatReq& req) { return a + (req.reqType == REQ_TYPE_COPPER ? req.reqVal1 : 0.0f); });
        if (copperTotal > 0.0f)
        {
            int32 val = static_cast<int32>(copperTotal);
            if (validate && (val < 1 || val > MAX_MONEY_AMOUNT))
                LOG_ERROR("sql.sql", "Stat requirement has invalid total copper amount for stat id {}, skip", statPair.first);
            else
                newStatReq.push_back(UpgradeStatReq(statPair.first, REQ_TYPE_COPPER, copperTotal));
        }

        float honorTotal = std::accumulate(statPair.second.begin(), statPair.second.end(), 0.0f,
            [](float a, const UpgradeStatReq& req) { return a + (req.reqType == REQ_TYPE_HONOR ? req.reqVal1 : 0.0f); });
        if (honorTotal > 0.0f)
        {
            int32 val = static_cast<int32>(honorTotal);
            if (validate && (val < 1 || val > sWorld->getIntConfig(CONFIG_MAX_HONOR_POINTS)))
                LOG_ERROR("sql.sql", "Stat requirement has invalid total honor points for stat id {}, skip", statPair.first);
            else
                newStatReq.push_back(UpgradeStatReq(statPair.first, REQ_TYPE_HONOR, honorTotal));
        }

        float arenaTotal = std::accumulate(statPair.second.begin(), statPair.second.end(), 0.0f,
            [](float a, const UpgradeStatReq& req) { return a + (req.reqType == REQ_TYPE_ARENA ? req.reqVal1 : 0.0f); });
        if (arenaTotal > 0.0f)
        {
            int32 val = static_cast<int32>(arenaTotal);
            if (validate && (val < 1 || val > sWorld->getIntConfig(CONFIG_MAX_ARENA_POINTS)))
                LOG_ERROR("sql.sql", "Stat requirement has invalid total arena points for stat id {}, skip", statPair.first);
            else
                newStatReq.push_back(UpgradeStatReq(statPair.first, REQ_TYPE_ARENA, arenaTotal));
        }

        std::unordered_map<uint32, uint32> itemCountMap;
        for (const UpgradeStatReq& req : statPair.second)
        {
            if (req.reqType != REQ_TYPE_ITEM)
                continue;

            itemCountMap[(uint32)req.reqVal1] += (uint32)req.reqVal2;
        }
        if (!itemCountMap.empty())
        {
            for (const auto& itemPair : itemCountMap)
                newStatReq.push_back(UpgradeStatReq(statPair.first, REQ_TYPE_ITEM, itemPair.first, itemPair.second));
        }

        StatRequirementContainer::const_iterator citer = std::find_if(statPair.second.begin(), statPair.second.end(),
            [&](const UpgradeStatReq& req) { return req.reqType == REQ_TYPE_NONE; });
        if (citer != statPair.second.end()) {
            newStatReq.push_back(UpgradeStatReq(statPair.first, REQ_TYPE_NONE));
        }

        statPair.second = newStatReq;
    }
}

void ItemUpgrade::LoadStatRequirements()
{
    baseStatRequirements.clear();

    QueryResult result = CharacterDatabase.Query("SELECT id, stat_id, req_type, req_val1, req_val2 FROM mod_item_upgrade_stats_req");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();

        uint32 statId = fields[1].Get<uint32>();
        uint8 reqType = fields[2].Get<uint8>();
        if (!IsValidReqType(reqType))
        {
            LOG_ERROR("sql.sql", "Table `mod_item_upgrade_stats_req` has invalid `req_type` {}, skip", reqType);
            continue;
        }
        float reqVal1 = fields[3].Get<float>();
        float reqVal2 = fields[4].Get<float>();
        if (!ValidateReq(fields[0].Get<uint32>(), (UpgradeStatReqType)reqType, reqVal1, reqVal2, "mod_item_upgrade_stats_req"))
            continue;

        UpgradeStatReq statReq;
        statReq.statId = statId;
        statReq.reqType = (UpgradeStatReqType)reqType;
        statReq.reqVal1 = reqVal1;
        statReq.reqVal2 = reqVal2;
        baseStatRequirements[statId].push_back(statReq);
    } while (result->NextRow());

    MergeStatRequirements(baseStatRequirements);
}

void ItemUpgrade::LoadStatRequirementsOverrides()
{
    overrideStatRequirements.clear();

    QueryResult result = CharacterDatabase.Query("SELECT id, stat_id, item_entry, req_type, req_val1, req_val2 FROM mod_item_upgrade_stats_req_override");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();

        uint32 statId = fields[1].Get<uint32>();
        uint8 reqType = fields[3].Get<uint8>();
        if (!IsValidReqType(reqType))
        {
            LOG_ERROR("sql.sql", "Table `mod_item_upgrade_stats_req_override` has invalid `req_type` {}, skip", reqType);
            continue;
        }
        uint32 entry = fields[2].Get<uint32>();
        const ItemTemplate* proto = sObjectMgr->GetItemTemplate(entry);
        if (proto == nullptr) {
            LOG_ERROR("sql.sql", "Table `mod_item_upgrade_stats_req_override` has invalid `item_entry` {}, skip", entry);
            continue;
        }
        float reqVal1 = fields[4].Get<float>();
        float reqVal2 = fields[5].Get<float>();
        if (!ValidateReq(fields[0].Get<uint32>(), (UpgradeStatReqType)reqType, reqVal1, reqVal2, "mod_item_upgrade_stats_req_override"))
            continue;

        UpgradeStatReq statReq;
        statReq.statId = statId;
        statReq.reqType = (UpgradeStatReqType)reqType;
        statReq.reqVal1 = reqVal1;
        statReq.reqVal2 = reqVal2;

        overrideStatRequirements[entry][statId].push_back(statReq);
    } while (result->NextRow());

    for (auto& pair : overrideStatRequirements)
        MergeStatRequirements(pair.second);
}

void ItemUpgrade::LoadUpgradeStats()
{
    upgradeStatList.clear();

    QueryResult result = CharacterDatabase.Query("SELECT id, stat_type, stat_mod_pct, stat_rank FROM mod_item_upgrade_stats");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();

        uint32 id = fields[0].Get<uint32>();
        uint32 statType = fields[1].Get<uint32>();
        float statModPct = fields[2].Get<float>();
        uint16 statRank = fields[3].Get<uint16>();

        UpgradeStat upgradeStat;
        upgradeStat.statId = id;
        upgradeStat.statType = statType;
        upgradeStat.statModPct = statModPct;
        upgradeStat.statRank = statRank;
        upgradeStatList.push_back(upgradeStat);
    } while (result->NextRow());
}

void ItemUpgrade::LoadCharacterUpgradeData()
{
    characterUpgradeData.clear();

    uint32 oldMSTime = getMSTime();

    QueryResult result = CharacterDatabase.Query("SELECT guid, item_guid, stat_id FROM character_item_upgrade");
    if (!result)
    {
        LOG_INFO("server.loading", ">> Loaded 0 character item upgrades.");
        LOG_INFO("server.loading", " ");
        return;
    }

    uint32 count = 0;
    do
    {
        Field* fields = result->Fetch();

        uint32 guidLow = fields[0].Get<uint32>();
        ObjectGuid itemGuid = ObjectGuid::Create<HighGuid::Item>(fields[1].Get<uint32>());
        uint32 statId = fields[2].Get<uint32>();

        CharacterUpgrade characterUpgrade;
        characterUpgrade.guid = guidLow;
        characterUpgrade.itemGuid = itemGuid;
        characterUpgrade.upgradeStat = FindUpgradeStat(statId);
        if (characterUpgrade.upgradeStat == nullptr)
        {
            LOG_ERROR("sql.sql", "Table `character_item_upgrade` has invalid `stat_id` {}, this should never happen, skip", statId);
            continue;
        }
        characterUpgradeData[guidLow].push_back(characterUpgrade);
        count++;
    } while (result->NextRow());

    LOG_INFO("server.loading", ">> Loaded {} character item upgrades in {} ms", count, GetMSTimeDiffToNow(oldMSTime));
    LOG_INFO("server.loading", " ");
}

void ItemUpgrade::LoadCharacterWeaponUpgradeData()
{
    characterWeaponUpgradeData.clear();

    uint32 oldMSTime = getMSTime();

    QueryResult result = CharacterDatabase.Query("SELECT guid, item_guid, upgrade_perc FROM character_weapon_upgrade");
    if (!result)
    {
        LOG_INFO("server.loading", ">> Loaded 0 character weapon item upgrades.");
        LOG_INFO("server.loading", " ");
        return;
    }

    uint32 count = 0;
    do
    {
        Field* fields = result->Fetch();

        uint32 guidLow = fields[0].Get<uint32>();
        ObjectGuid itemGuid = ObjectGuid::Create<HighGuid::Item>(fields[1].Get<uint32>());
        float perc = fields[2].Get<float>();

        CharacterUpgrade characterUpgrade;
        characterUpgrade.guid = guidLow;
        characterUpgrade.itemGuid = itemGuid;
        characterUpgrade.upgradeStat = FindWeaponUpgradeStat(weaponUpgradeStats, perc);
        if (characterUpgrade.upgradeStat == nullptr)
        {
            characterUpgrade.upgradeStat = FindNearestWeaponUpgradeStat(weaponUpgradeStats, perc);
            if (characterUpgrade.upgradeStat == nullptr) {
                LOG_ERROR("sql.sql", "Table `character_weapon_upgrade` has invalid `upgrade_perc` {}, there is no other near percent that can be chosen, skip", perc);
                continue;
            }
            else
                LOG_INFO("sql.sql", "Table `character_weapon_upgrade` has invalid `upgrade_perc` {} but a near percentage was chosen: {}", perc, characterUpgrade.upgradeStat->statModPct);
        }
        characterUpgrade.upgradeStatModPct = perc;
        characterWeaponUpgradeData[guidLow].push_back(characterUpgrade);
        count++;
    } while (result->NextRow());

    LOG_INFO("server.loading", ">> Loaded {} character weapon item upgrades in {} ms", count, GetMSTimeDiffToNow(oldMSTime));
    LOG_INFO("server.loading", " ");
}

void ItemUpgrade::LoadCharacterWeaponSpeedUpgradeData()
{
    characterWeaponSpeedUpgradeData.clear();

    uint32 oldMSTime = getMSTime();

    QueryResult result = CharacterDatabase.Query("SELECT guid, item_guid, upgrade_perc FROM character_weapon_speed_upgrade");
    if (!result)
    {
        LOG_INFO("server.loading", ">> Loaded 0 character weapon speed upgrades.");
        LOG_INFO("server.loading", " ");
        return;
    }

    uint32 count = 0;
    do
    {
        Field* fields = result->Fetch();

        uint32 guidLow = fields[0].Get<uint32>();
        ObjectGuid itemGuid = ObjectGuid::Create<HighGuid::Item>(fields[1].Get<uint32>());
        float perc = fields[2].Get<float>();

        CharacterUpgrade characterUpgrade;
        characterUpgrade.guid = guidLow;
        characterUpgrade.itemGuid = itemGuid;
        characterUpgrade.upgradeStat = FindWeaponUpgradeStat(weaponSpeedUpgradeStats, perc);
        if (characterUpgrade.upgradeStat == nullptr)
        {
            characterUpgrade.upgradeStat = FindNearestWeaponUpgradeStat(weaponSpeedUpgradeStats, perc);
            if (characterUpgrade.upgradeStat == nullptr) {
                LOG_ERROR("sql.sql", "Table `character_weapon_speed_upgrade` has invalid `upgrade_perc` {}, there is no other near percent that can be chosen, skip", perc);
                continue;
            }
            else
                LOG_INFO("sql.sql", "Table `character_weapon_speed_upgrade` has invalid `upgrade_perc` {} but a near percentage was chosen: {}", perc, characterUpgrade.upgradeStat->statModPct);
        }
        characterUpgrade.upgradeStatModPct = perc;
        characterWeaponSpeedUpgradeData[guidLow].push_back(characterUpgrade);
        count++;
    } while (result->NextRow());

    LOG_INFO("server.loading", ">> Loaded {} character weapon speed upgrades in {} ms", count, GetMSTimeDiffToNow(oldMSTime));
    LOG_INFO("server.loading", " ");
}

bool ItemUpgrade::IsValidReqType(uint8 reqType) const
{
    return reqType >= REQ_TYPE_COPPER && reqType < MAX_REQ_TYPE;
}

bool ItemUpgrade::ValidateReq(uint32 id, UpgradeStatReqType reqType, float val1, float val2, const std::string& table) const
{
    int32 val1Int = static_cast<int32>(val1);
    switch (reqType)
    {
    case ItemUpgrade::REQ_TYPE_COPPER:
        if (val1Int >= 1 && val1Int <= MAX_MONEY_AMOUNT)
            return true;
        LOG_ERROR("sql.sql", "Table `{}` has invalid `req_val1` {} (copper amount) for `id` {}, skip", table, val1, id);
        return false;
    case ItemUpgrade::REQ_TYPE_HONOR:
        if (val1Int >= 1 && val1Int <= sWorld->getIntConfig(CONFIG_MAX_HONOR_POINTS))
            return true;
        LOG_ERROR("sql.sql", "Table `{}` has invalid `req_val1` {} (honor points) for `id` {}, skip", table, val1, id);
        return false;
    case ItemUpgrade::REQ_TYPE_ARENA:
        if (val1Int >= 1 && val1Int <= sWorld->getIntConfig(CONFIG_MAX_ARENA_POINTS))
            return true;
        LOG_ERROR("sql.sql", "Table `{}` has invalid `req_val1` {} (arena points) for `id` {}, skip", table, val1, id);
        return false;
    case ItemUpgrade::REQ_TYPE_ITEM:
    {
        const ItemTemplate* itemTemplate = sObjectMgr->GetItemTemplate(val1Int);
        if (!itemTemplate)
        {
            LOG_ERROR("sql.sql", "Table `{}` has invalid `req_val1` {} (item entry not found) for `id` {}, skip", table, val1, id);
            return false;
        }
        int32 val2Int = static_cast<int32>(val2);
        if (val2Int >= 1)
            return true;
        LOG_ERROR("sql.sql", "Table `{}` has invalid `req_val2` {} (item count invalid) for `id` {}, skip", table, val2, id);
        return false;
    }
    case ItemUpgrade::REQ_TYPE_NONE:
        return true;
    }
    return false;
}

/*static*/ std::string ItemUpgrade::ItemNameWithLocale(const Player* player, const ItemTemplate* itemTemplate, int32 randomPropertyId)
{
    LocaleConstant loc_idx = player->GetSession()->GetSessionDbLocaleIndex();
    std::string name = itemTemplate->Name1;
    if (ItemLocale const* il = sObjectMgr->GetItemLocale(itemTemplate->ItemId))
        ObjectMgr::GetLocaleString(il->Name, loc_idx, name);

    std::array<char const*, 16> const* suffix = nullptr;
    if (randomPropertyId < 0)
    {
        if (const ItemRandomSuffixEntry* itemRandEntry = sItemRandomSuffixStore.LookupEntry(-randomPropertyId))
            suffix = &itemRandEntry->Name;
    }
    else
    {
        if (const ItemRandomPropertiesEntry* itemRandEntry = sItemRandomPropertiesStore.LookupEntry(randomPropertyId))
            suffix = &itemRandEntry->Name;
    }
    if (suffix)
    {
        std::string_view test((*suffix)[(name != itemTemplate->Name1) ? loc_idx : DEFAULT_LOCALE]);
        if (!test.empty())
        {
            name += ' ';
            name += test;
        }
    }

    return name;
}

/*static*/ std::string ItemUpgrade::ItemLink(const Player* player, const ItemTemplate* itemTemplate, int32 randomPropertyId)
{
    std::stringstream oss;
    oss << "|c";
    oss << std::hex << ItemQualityColors[itemTemplate->Quality] << std::dec;
    oss << "|Hitem:";
    oss << itemTemplate->ItemId;
    oss << ":0:0:0:0:0:0:0:0:0|h[";
    oss << ItemNameWithLocale(player, itemTemplate, randomPropertyId);
    oss << "]|h|r";

    return oss.str();
}

/*static*/ std::string ItemUpgrade::ItemLink(const Player* player, const Item* item)
{
    const ItemTemplate* itemTemplate = item->GetTemplate();
    std::stringstream oss;
    oss << "|c";
    oss << std::hex << ItemQualityColors[itemTemplate->Quality] << std::dec;
    oss << "|Hitem:";
    oss << itemTemplate->ItemId;
    oss << ":" << item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT);
    oss << ":" << item->GetEnchantmentId(SOCK_ENCHANTMENT_SLOT);
    oss << ":" << item->GetEnchantmentId(SOCK_ENCHANTMENT_SLOT_2);
    oss << ":" << item->GetEnchantmentId(SOCK_ENCHANTMENT_SLOT_3);
    oss << ":" << item->GetEnchantmentId(BONUS_ENCHANTMENT_SLOT);
    oss << ":" << item->GetItemRandomPropertyId();
    oss << ":" << item->GetItemSuffixFactor();
    oss << ":" << (uint32)item->GetOwner()->GetLevel();
    oss << "|h[" << ItemNameWithLocale(player, itemTemplate, item->GetItemRandomPropertyId());
    oss << "]|h|r";

    return oss.str();
}

/*static*/ void ItemUpgrade::SendMessage(const Player* player, const std::string& message)
{
    ChatHandler(player->GetSession()).SendSysMessage(message);
}

/*static*/ std::string ItemUpgrade::Text(const WorldSession* session, uint32 id)
{
    // Asked for a row it does not have, the core hands back a pointer that
    // must not be read: look for the row first.
    if (!sObjectMgr->GetModuleString(ITEM_UPGRADE_MODULE, id))
        return Acore::StringFormat("[" ITEM_UPGRADE_MODULE "] missing text {}", id);

    LocaleConstant locale = session ? session->GetSessionDbLocaleIndex() : DEFAULT_LOCALE;
    return *sObjectMgr->GetModuleString(ITEM_UPGRADE_MODULE, id, locale);
}

/*static*/ std::string ItemUpgrade::StatName(const WorldSession* session, uint32 statType)
{
    return Text(session, IU_TEXT_STAT + statType);
}

/*static*/ std::string ItemUpgrade::SlotName(const WorldSession* session, uint8 slot)
{
    return Text(session, IU_TEXT_SLOT + slot);
}

bool ItemUpgrade::IsValidItemForUpgrade(const Item* item, const Player* player) const
{
    if (!item)
        return false;

    if (item->GetOwnerGUID() != player->GetGUID())
        return false;

    if (LoadItemStatInfo(item).empty())
        return false;

    const ItemTemplate* proto = item->GetTemplate();
    if (proto->Quality == ITEM_QUALITY_HEIRLOOM)
        return false;

    if (item->IsBroken())
        return false;

    return true;
}

bool ItemUpgrade::IsValidWeaponForUpgrade(const Item* item, const Player* player) const
{
    if (!item)
        return false;

    if (item->GetOwnerGUID() != player->GetGUID())
        return false;

    const ItemTemplate* proto = item->GetTemplate();
    if (proto->Quality == ITEM_QUALITY_HEIRLOOM)
        return false;

    if (item->IsBroken())
        return false;

    std::pair<float, float> dmg = GetItemProtoDamage(proto);
    if (dmg.first > 0 && dmg.second > 0)
        return true;

    return false;
}

bool ItemUpgrade::IsValidWeaponForSpeedUpgrade(const Item* item, const Player* player) const
{
    if (!item)
        return false;

    if (item->GetOwnerGUID() != player->GetGUID())
        return false;

    const ItemTemplate* proto = item->GetTemplate();
    if (proto->Quality == ITEM_QUALITY_HEIRLOOM)
        return false;

    if (!proto->Delay)
        return false;

    if (!item->IsEquipped() || Player::GetAttackBySlot(item->GetSlot()) == MAX_ATTACK)
        return false;

    if (!player->GetWeaponDamageRange(WeaponAttackType(Player::GetAttackBySlot(item->GetSlot())), MAXDAMAGE))
        return false;

    if (item->IsBroken())
        return false;

    return true;
}

bool ItemUpgrade::HandlePurchaseRank(Player* player, Item* item, const UpgradeStat* upgrade)
{
    const UpgradeStat* foundUpgrade = FindUpgradeForItem(player, item, upgrade->statType);
    std::vector<CharacterUpgrade>& upgrades = characterUpgradeData[player->GetGUID().GetCounter()];
    if (foundUpgrade != nullptr)
    {
        std::vector<CharacterUpgrade>::const_iterator citer = std::remove_if(upgrades.begin(), upgrades.end(),
            [&](const CharacterUpgrade& upgrade) { return upgrade.itemGuid == item->GetGUID() && upgrade.upgradeStat->statId == foundUpgrade->statId; });
        if (citer == upgrades.end())
            return false;
        upgrades.erase(citer, upgrades.end());

        CharacterDatabase.Execute("UPDATE character_item_upgrade SET stat_id = {} WHERE guid = {} AND item_guid = {} AND stat_id = {}",
            upgrade->statId, player->GetGUID().GetCounter(), item->GetGUID().GetCounter(), foundUpgrade->statId);
    }
    else
        AddItemUpgradeToDB(player, item, upgrade);

    CharacterUpgrade newUpgrade;
    newUpgrade.guid = player->GetGUID().GetCounter();
    newUpgrade.itemGuid = item->GetGUID();
    newUpgrade.upgradeStat = upgrade;
    upgrades.push_back(newUpgrade);

    return true;
}

bool ItemUpgrade::HandlePurchaseWeaponUpgrade(Player* player, Item* item, const UpgradeStat* upgrade, bool speedUpgrade)
{
    std::vector<CharacterUpgrade>& upgrades = !speedUpgrade ? characterWeaponUpgradeData[player->GetGUID().GetCounter()] : characterWeaponSpeedUpgradeData[player->GetGUID().GetCounter()];
    std::vector<CharacterUpgrade>::const_iterator citer = std::remove_if(upgrades.begin(), upgrades.end(),
        [&](const CharacterUpgrade& upgrade) { return upgrade.itemGuid == item->GetGUID(); });
    upgrades.erase(citer, upgrades.end());

    CharacterDatabase.Execute("REPLACE INTO {} (guid, item_guid, upgrade_perc) VALUES ({}, {}, {})", !speedUpgrade ? "character_weapon_upgrade" : "character_weapon_speed_upgrade",
        player->GetGUID().GetCounter(), item->GetGUID().GetCounter(), upgrade->statModPct);

    CharacterUpgrade newUpgrade;
    newUpgrade.guid = player->GetGUID().GetCounter();
    newUpgrade.itemGuid = item->GetGUID();
    newUpgrade.upgradeStat = upgrade;
    newUpgrade.upgradeStatModPct = upgrade->statModPct;
    upgrades.push_back(newUpgrade);

    return true;
}

int32 ItemUpgrade::HandleStatModifier(const Player* player, uint8 slot, uint32 statType, int32 amount) const
{
    if (amount == 0)
        return 0;

    Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
    if (!item)
        return amount;

    return HandleStatModifier(player, item, statType, amount, MAX_ENCHANTMENT_SLOT);
}

int32 ItemUpgrade::HandleStatModifier(const Player* player, Item* item, uint32 statType, int32 amount, EnchantmentSlot slot) const
{
    if (!GetBoolConfig(CONFIG_ITEM_UPGRADE_ENABLED) || !IsAllowedItem(item) || IsBlacklistedItem(item) || !IsAllowedStatType(statType))
        return amount;

    if (slot < MAX_INSPECTED_ENCHANTMENT_SLOT)
        return amount;

    const UpgradeStat* foundUpgrade = FindUpgradeForItem(player, item, statType);
    if (foundUpgrade != nullptr && CanApplyUpgradeForItem(item, foundUpgrade))
        return CalculateModPct(amount, foundUpgrade);

    return amount;
}

std::pair<float, float> ItemUpgrade::HandleWeaponModifier(const Player* player, uint8 slot, float minDamage, float maxDamage) const
{
    return HandleWeaponModifier(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot), minDamage, maxDamage);
}

std::pair<float, float> ItemUpgrade::HandleWeaponModifier(const Player* player, const Item* item, float minDamage, float maxDamage) const
{
    if (!GetBoolConfig(CONFIG_ITEM_UPGRADE_ENABLED))
        return std::make_pair(minDamage, maxDamage);

    if (!GetBoolConfig(CONFIG_ITEM_UPGRADE_WEAPON_DAMAGE))
        return std::make_pair(minDamage, maxDamage);

    if (!item)
        return std::make_pair(minDamage, maxDamage);

    if (minDamage == 0.0f || maxDamage == 0.0f)
        return std::make_pair(minDamage, maxDamage);

    const UpgradeStat* weaponUpgrade = FindUpgradeForWeapon(characterWeaponUpgradeData, player, item);
    if (weaponUpgrade == nullptr)
        return std::make_pair(minDamage, maxDamage);

    float upgradedMinDamage = std::floor(CalculateModPctF(minDamage, weaponUpgrade));
    float upgradedMaxDamage = std::ceil(CalculateModPctF(maxDamage, weaponUpgrade));
    return std::make_pair(upgradedMinDamage, upgradedMaxDamage);
}

uint32 ItemUpgrade::HandleWeaponSpeedModifier(const Player* player, const Item* item) const
{
    uint32 originalDelay = GetItemProtoDelay(item);
    if (!originalDelay)
        return originalDelay;

    if (!GetBoolConfig(CONFIG_ITEM_UPGRADE_ENABLED))
        return originalDelay;

    if (!GetBoolConfig(CONFIG_ITEM_UPGRADE_WEAPON_SPEED))
        return originalDelay;

    if (!item)
        return originalDelay;

    const UpgradeStat* weaponUpgrade = FindUpgradeForWeapon(characterWeaponSpeedUpgradeData, player, item);
    if (weaponUpgrade == nullptr)
        return originalDelay;

    return CalculatePctDecrease(originalDelay, weaponUpgrade->statModPct);
}

void ItemUpgrade::HandleItemRemove(Player* player, Item* item)
{
    bool hasItemUpgrades = !FindUpgradesForItem(player, item).empty();
    bool hasWeaponUpgrade = FindUpgradeForWeapon(characterWeaponUpgradeData, player, item) != nullptr;
    bool hasWeaponSpeedUpgrade = FindUpgradeForWeaponSpeed(player, item) != nullptr;
    if (hasItemUpgrades || hasWeaponUpgrade || hasWeaponSpeedUpgrade)
    {
        player->_ApplyItemMods(item, item->GetSlot(), false);
        if (hasItemUpgrades)
            RemoveItemUpgrade(player, item);
        if (hasWeaponUpgrade)
            RemoveWeaponUpgrade(player, item);
        if (hasWeaponSpeedUpgrade)
            RemoveWeaponSpeedUpgrade(player, item);
        player->_ApplyItemMods(item, item->GetSlot(), true);

        RefreshWeaponSpeed(player);
    }
}

void ItemUpgrade::RemoveItemUpgradeFromContainer(CharacterUpgradeContainer& upgradesContainer, Player* player, Item* item)
{
    std::vector<CharacterUpgrade>& upgrades = upgradesContainer[player->GetGUID().GetCounter()];
    std::vector<CharacterUpgrade>::const_iterator citer = std::remove_if(upgrades.begin(), upgrades.end(),
        [&](const CharacterUpgrade& upgrade) { return upgrade.itemGuid == item->GetGUID(); });
    upgrades.erase(citer, upgrades.end());
}

void ItemUpgrade::RemoveItemUpgrade(Player* player, Item* item)
{
    RemoveItemUpgradeFromContainer(characterUpgradeData, player, item);
    CharacterDatabase.Execute("DELETE FROM character_item_upgrade WHERE guid = {} AND item_guid = {}", player->GetGUID().GetCounter(), item->GetGUID().GetCounter());
}

void ItemUpgrade::RemoveWeaponUpgrade(Player* player, Item* item)
{
    RemoveItemUpgradeFromContainer(characterWeaponUpgradeData, player, item);
    CharacterDatabase.Execute("DELETE FROM character_weapon_upgrade WHERE guid = {} AND item_guid = {}", player->GetGUID().GetCounter(), item->GetGUID().GetCounter());
}

void ItemUpgrade::RemoveWeaponSpeedUpgrade(Player* player, Item* item)
{
    RemoveItemUpgradeFromContainer(characterWeaponSpeedUpgradeData, player, item);
    CharacterDatabase.Execute("DELETE FROM character_weapon_speed_upgrade WHERE guid = {} AND item_guid = {}", player->GetGUID().GetCounter(), item->GetGUID().GetCounter());
}

void ItemUpgrade::HandleCharacterRemove(uint32 guid)
{
    characterUpgradeData[guid].clear();
    characterWeaponUpgradeData[guid].clear();
    characterWeaponSpeedUpgradeData[guid].clear();
}

bool ItemUpgrade::MeetsRequirement(const Player* player, const UpgradeStatReq& req) const
{
    switch (req.reqType)
    {
    case REQ_TYPE_COPPER:
        return player->HasEnoughMoney((int32)req.reqVal1);
    case REQ_TYPE_HONOR:
        return player->GetHonorPoints() >= (uint32)req.reqVal1;
    case REQ_TYPE_ARENA:
        return player->GetArenaPoints() >= (uint32)req.reqVal1;
    case REQ_TYPE_ITEM:
        return player->HasItemCount((uint32)req.reqVal1, (uint32)req.reqVal2);
    case REQ_TYPE_NONE:
        return true;
    }

    return false;
}

bool ItemUpgrade::MeetsRequirement(const Player* player, const UpgradeStat* upgradeStat, const Item* item) const
{
    return MeetsRequirement(player, GetStatRequirements(upgradeStat, item));
}

bool ItemUpgrade::MeetsRequirement(const Player* player, const StatRequirementContainer* reqs) const
{
    if (EmptyRequirements(reqs))
        return true;

    for (const auto& req : *reqs)
        if (!MeetsRequirement(player, req))
            return false;

    return true;
}

void ItemUpgrade::TakeRequirements(Player* player, const UpgradeStat* upgradeStat, const Item* item)
{
    TakeRequirements(player, GetStatRequirements(upgradeStat, item));
}

void ItemUpgrade::TakeRequirements(Player* player, const StatRequirementContainer* reqs)
{
    if (EmptyRequirements(reqs))
        return;

    for (const auto& req : *reqs)
    {
        switch (req.reqType)
        {
        case REQ_TYPE_COPPER:
            player->ModifyMoney(-(int32)req.reqVal1);
            break;
        case REQ_TYPE_HONOR:
            player->ModifyHonorPoints(-(int32)req.reqVal1);
            break;
        case REQ_TYPE_ARENA:
            player->ModifyArenaPoints(-(int32)req.reqVal1);
            break;
        case REQ_TYPE_ITEM:
            player->DestroyItemCount((uint32)req.reqVal1, (uint32)req.reqVal2, true);
            break;
        }
    }
}

void ItemUpgrade::TakeWeaponUpgradeRequirements(Player* player)
{
    TakeRequirements(player, &weaponUpgradeReqs);
}

void ItemUpgrade::TakeWeaponSpeedUpgradeRequirements(Player* player)
{
    TakeRequirements(player, &weaponSpeedUpgradeReqs);
}

void ItemUpgrade::CreateUpgradesPctMap()
{
    upgradesPctMap.clear();
    for (const UpgradeStat& ustat : upgradeStatList)
        upgradesPctMap[ustat.statModPct].push_back(&ustat);
}

ItemUpgrade::TotalCost ItemUpgrade::SumRequirements(const std::vector<const StatRequirementContainer*>& parts) const
{
    TotalCost total;
    for (const StatRequirementContainer* ureq : parts)
    {
        if (EmptyRequirements(ureq))
            continue;

        for (const UpgradeStatReq& statReq : *ureq)
        {
            switch (statReq.reqType)
            {
            case REQ_TYPE_COPPER:
                total.copper += (uint32)statReq.reqVal1;
                break;
            case REQ_TYPE_HONOR:
                total.honor += (uint32)statReq.reqVal1;
                break;
            case REQ_TYPE_ARENA:
                total.arena += (uint32)statReq.reqVal1;
                break;
            case REQ_TYPE_ITEM:
                total.items[(uint32)statReq.reqVal1] += (uint32)statReq.reqVal2;
                break;
            case REQ_TYPE_NONE:
                break;
            default:
                // Unknown requirement: never read as free.
                total.invalid = true;
                break;
            }
        }
    }

    return total;
}

bool ItemUpgrade::MeetsCost(const Player* player, const TotalCost& cost) const
{
    if (cost.invalid)
        return false;

    // A sum above what a player can ever hold is refused, never lowered.
    if (cost.copper > MAX_MONEY_AMOUNT || !player->HasEnoughMoney(uint32(cost.copper)))
        return false;

    if (cost.honor > player->GetHonorPoints() || cost.arena > player->GetArenaPoints())
        return false;

    for (const auto& [entry, count] : cost.items)
        if (count > std::numeric_limits<uint32>::max() || !player->HasItemCount(entry, uint32(count)))
            return false;

    return true;
}

void ItemUpgrade::TakeCost(Player* player, const TotalCost& cost)
{
    // Only after MeetsCost: every amount fits what the core takes.
    if (cost.copper)
        player->ModifyMoney(-int32(cost.copper));
    if (cost.honor)
        player->ModifyHonorPoints(-int32(cost.honor));
    if (cost.arena)
        player->ModifyArenaPoints(-int32(cost.arena));
    for (const auto& [entry, count] : cost.items)
        player->DestroyItemCount(entry, uint32(count), true);
}

/*static*/ int32 ItemUpgrade::CalculateModPct(int32 value, const UpgradeStat* upgradeStat)
{
    int32 newAmount = (int32)(value * (1 + upgradeStat->statModPct / 100.0f));
    return std::max(newAmount, value + upgradeStat->statRank);
}

/*static*/ float ItemUpgrade::CalculateModPctF(float value, const UpgradeStat* upgradeStat)
{
    float newAmount = value * (1.0f + upgradeStat->statModPct / 100.0f);
    return std::max(newAmount, value + upgradeStat->statRank);
}

/*static*/ uint32 ItemUpgrade::CalculatePctDecrease(uint32 value, float pct)
{
    if (pct >= 100.0f)
        return 0;

    float newAmount = value - (pct / 100.0f * value);
    return static_cast<uint32>(std::trunc(newAmount));
}

/*static*/ const _ItemStat* ItemUpgrade::GetStatByType(const std::vector<_ItemStat>& statInfo, uint32 statType)
{
    std::vector<_ItemStat>::const_iterator citer = std::find_if(statInfo.begin(), statInfo.end(), [&](const _ItemStat& stat) { return stat.ItemStatType == statType; });
    if (citer != statInfo.end())
        return &*citer;
    return nullptr;
}

/*static*/ std::vector<_ItemStat> ItemUpgrade::LoadItemStatInfo(const Item* item)
{
    std::vector<_ItemStat> statInfo;
    ItemTemplate const* proto = item->GetTemplate();

    for (uint8 i = 0; i < MAX_ITEM_PROTO_STATS; ++i)
    {
        if (i >= proto->StatsCount)
            continue;

        uint32 statType = proto->ItemStat[i].ItemStatType;
        if (proto->ItemStat[i].ItemStatValue > 0)
        {
            _ItemStat stat;
            stat.ItemStatType = statType;
            stat.ItemStatValue = proto->ItemStat[i].ItemStatValue;
            statInfo.push_back(stat);
        }
    }

    for (uint32 slot = PROP_ENCHANTMENT_SLOT_0; slot < MAX_ENCHANTMENT_SLOT; ++slot)
    {
        uint32 enchant_id = item->GetEnchantmentId(EnchantmentSlot(slot));
        if (!enchant_id)
            continue;

        SpellItemEnchantmentEntry const* pEnchant = sSpellItemEnchantmentStore.LookupEntry(enchant_id);
        if (!pEnchant)
            continue;

        for (int s = 0; s < MAX_SPELL_ITEM_ENCHANTMENT_EFFECTS; ++s)
        {
            uint32 enchant_display_type = pEnchant->type[s];
            uint32 enchant_amount = pEnchant->amount[s];
            uint32 enchant_spell_id = pEnchant->spellid[s];

            if (enchant_display_type == ITEM_ENCHANTMENT_TYPE_STAT)
            {
                if (!enchant_amount)
                {
                    ItemRandomSuffixEntry const* item_rand_suffix = sItemRandomSuffixStore.LookupEntry(std::abs(item->GetItemRandomPropertyId()));
                    if (item_rand_suffix)
                    {
                        for (int k = 0; k < MAX_ITEM_ENCHANTMENT_EFFECTS; ++k)
                        {
                            if (item_rand_suffix->Enchantment[k] == enchant_id)
                            {
                                enchant_amount = uint32((item_rand_suffix->AllocationPct[k] * item->GetItemSuffixFactor()) / 10000);
                                break;
                            }
                        }
                    }
                }
                _ItemStat stat;
                stat.ItemStatType = enchant_spell_id;
                stat.ItemStatValue = enchant_amount;
                statInfo.push_back(stat);
            }
        }
    }

    return statInfo;
}

bool ItemUpgrade::IsValidStatType(uint32 statType) const
{
    // The stats an item carries in 3.3.5, without the two deprecated spell
    // healing / spell damage values. Their names: rows 1000 + stat type.
    static const std::set<uint32> validStatTypes =
    {
        ITEM_MOD_MANA, ITEM_MOD_HEALTH, ITEM_MOD_AGILITY, ITEM_MOD_STRENGTH, ITEM_MOD_INTELLECT, ITEM_MOD_SPIRIT,
        ITEM_MOD_STAMINA, ITEM_MOD_DEFENSE_SKILL_RATING, ITEM_MOD_DODGE_RATING, ITEM_MOD_PARRY_RATING,
        ITEM_MOD_BLOCK_RATING, ITEM_MOD_HIT_MELEE_RATING, ITEM_MOD_HIT_RANGED_RATING, ITEM_MOD_HIT_SPELL_RATING,
        ITEM_MOD_CRIT_MELEE_RATING, ITEM_MOD_CRIT_RANGED_RATING, ITEM_MOD_CRIT_SPELL_RATING,
        ITEM_MOD_HIT_TAKEN_MELEE_RATING, ITEM_MOD_HIT_TAKEN_RANGED_RATING, ITEM_MOD_HIT_TAKEN_SPELL_RATING,
        ITEM_MOD_CRIT_TAKEN_MELEE_RATING, ITEM_MOD_CRIT_TAKEN_RANGED_RATING, ITEM_MOD_CRIT_TAKEN_SPELL_RATING,
        ITEM_MOD_HASTE_MELEE_RATING, ITEM_MOD_HASTE_RANGED_RATING, ITEM_MOD_HASTE_SPELL_RATING, ITEM_MOD_HIT_RATING,
        ITEM_MOD_CRIT_RATING, ITEM_MOD_HIT_TAKEN_RATING, ITEM_MOD_CRIT_TAKEN_RATING, ITEM_MOD_RESILIENCE_RATING,
        ITEM_MOD_HASTE_RATING, ITEM_MOD_EXPERTISE_RATING, ITEM_MOD_ATTACK_POWER, ITEM_MOD_RANGED_ATTACK_POWER,
        ITEM_MOD_MANA_REGENERATION, ITEM_MOD_ARMOR_PENETRATION_RATING, ITEM_MOD_SPELL_POWER, ITEM_MOD_HEALTH_REGEN,
        ITEM_MOD_SPELL_PENETRATION, ITEM_MOD_BLOCK_VALUE
    };

    return validStatTypes.find(statType) != validStatTypes.end();
}

uint16 ItemUpgrade::MaxRankForStat(uint32 statType) const
{
    uint16 maxRank = 0;
    for (const UpgradeStat& stat : upgradeStatList)
        if (stat.statType == statType && stat.statRank > maxRank)
            maxRank = stat.statRank;

    return maxRank;
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindUpgradeStat(uint32 statId) const
{
    return _FindUpgradeStat(upgradeStatList, [&](const UpgradeStat& stat) { return stat.statId == statId; });
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindUpgradeStat(uint32 statType, uint16 rank) const
{
    return _FindUpgradeStat(upgradeStatList, [&](const UpgradeStat& stat) { return stat.statType == statType && stat.statRank == rank; });
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindWeaponUpgradeStat(const UpgradeStatContainer& upgradeStatContainer, float pct) const
{
    return _FindUpgradeStat(upgradeStatContainer, [&](const UpgradeStat& stat) { return stat.statModPct == pct; });
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindNearestWeaponUpgradeStat(const UpgradeStatContainer& upgradeStatContainer, float pct) const
{
    if (upgradeStatContainer.empty())
        return nullptr;

    for (int i = upgradeStatContainer.size() - 1; i >= 0; i--)
        if (upgradeStatContainer[i].statModPct < pct)
            return &upgradeStatContainer[i];

    for (int i = 0; i < upgradeStatContainer.size(); i++)
        if (upgradeStatContainer[i].statModPct > pct)
            return &upgradeStatContainer[i];

    return nullptr;
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindNextWeaponUpgradeStat(const UpgradeStatContainer& upgradeStatContainer, float pct) const
{
    if (upgradeStatContainer.empty())
        return nullptr;

    for (int i = 0; i < upgradeStatContainer.size(); i++)
        if (upgradeStatContainer[i].statModPct > pct)
            return &upgradeStatContainer[i];

    return nullptr;
}

std::vector<const ItemUpgrade::UpgradeStat*> ItemUpgrade::_FindUpgradesForItem(const CharacterUpgradeContainer& characterUpgradeDataContainer, const Player* player, const Item* item) const
{
    std::vector<const UpgradeStat*> statsForItem;
    if (characterUpgradeDataContainer.find(player->GetGUID().GetCounter()) == characterUpgradeDataContainer.end())
        return statsForItem;

    const std::vector<CharacterUpgrade>& upgrades = characterUpgradeDataContainer.at(player->GetGUID().GetCounter());
    for (auto const& upgrade : upgrades)
        if (upgrade.itemGuid == item->GetGUID())
            statsForItem.push_back(upgrade.upgradeStat);

    return statsForItem;
}

std::vector<const ItemUpgrade::UpgradeStat*> ItemUpgrade::FindUpgradesForItem(const Player* player, const Item* item) const
{
    return _FindUpgradesForItem(characterUpgradeData, player, item);
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindUpgradeForItem(const Player* player, const Item* item, uint32 statType) const
{
    std::vector<const UpgradeStat*> statsForItem = FindUpgradesForItem(player, item);
    if (statsForItem.empty())
        return nullptr;

    std::vector<const UpgradeStat*>::const_iterator citer = std::find_if(statsForItem.begin(), statsForItem.end(), [&](const UpgradeStat* upgradeStat) { return upgradeStat->statType == statType; });
    if (citer != statsForItem.end())
        return *citer;

    return nullptr;
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindUpgradeForWeapon(const CharacterUpgradeContainer& characterUpgradeContainer, const Player* player, const Item* item) const
{
    std::vector<const UpgradeStat*> weaponUpgrades = _FindUpgradesForItem(characterUpgradeContainer, player, item);
    if (weaponUpgrades.empty())
        return nullptr;

    return weaponUpgrades[0];
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindUpgradeForWeaponDamage(const Player* player, const Item* item) const
{
    return FindUpgradeForWeapon(characterWeaponUpgradeData, player, item);
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindUpgradeForWeaponSpeed(const Player* player, const Item* item) const
{
    return FindUpgradeForWeapon(characterWeaponSpeedUpgradeData, player, item);
}

/*static*/ std::string ItemUpgrade::FormatFloat(float val, uint32 decimals)
{
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(decimals) << val;
    return oss.str();
}

/*static*/ std::string ItemUpgrade::FormatIncrease(float prev, float next)
{
    std::ostringstream oss;
    oss << "";
    oss << "|cffb50505" << FormatFloat(prev) << "|r ";
    oss << "-> ";
    oss << "|cff056e3a" << FormatFloat(next) << "|r";
    oss << "";
    return oss.str();
}

/*static*/ std::string ItemUpgrade::FormatDelay(uint32 val)
{
    std::ostringstream oss;
    oss << FormatFloat(val / 1000.0f) << "s";
    return oss.str();
}

void ItemUpgrade::SetReloading(bool value)
{
    reloading = value;
}

bool ItemUpgrade::GetReloading() const
{
    return reloading;
}

void ItemUpgrade::HandleDataReload(bool apply)
{
    const WorldSessionMgr::SessionMap& sessions = sWorldSessionMgr->GetAllSessions();
    WorldSessionMgr::SessionMap::const_iterator itr;
    for (itr = sessions.begin(); itr != sessions.end(); ++itr)
        if (itr->second && itr->second->GetPlayer() && itr->second->GetPlayer()->IsInWorld())
            HandleDataReload(itr->second->GetPlayer(), apply);
}

void ItemUpgrade::HandleDataReload(Player* player, bool apply)
{
    std::vector<Item*> playerItems = GetPlayerItems(player, true);
    std::vector<Item*>::iterator iter = playerItems.begin();
    for (iter; iter != playerItems.end(); ++iter)
    {
        Item* item = *iter;

        if (!item->IsEquipped())
            continue;

        player->_ApplyItemMods(item, item->GetSlot(), apply);
    }

    if (apply)
    {
        UpdateVisualCache(player);
        RefreshWeaponSpeed(player);
    }
}

std::vector<Item*> ItemUpgrade::GetPlayerItems(const Player* player, bool inBankAlso) const
{
    std::vector<Item*> items;
    for (uint8 i = INVENTORY_SLOT_ITEM_START; i < INVENTORY_SLOT_ITEM_END; i++)
        if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            items.push_back(item);

    for (uint8 i = INVENTORY_SLOT_BAG_START; i < INVENTORY_SLOT_BAG_END; i++)
        if (Bag* bag = player->GetBagByPos(i))
            for (uint32 j = 0; j < bag->GetBagSize(); j++)
                if (Item* item = player->GetItemByPos(i, j))
                    items.push_back(item);

    for (uint8 i = EQUIPMENT_SLOT_START; i < EQUIPMENT_SLOT_END; i++)
        if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            items.push_back(item);

    if (inBankAlso)
    {
        for (uint8 i = BANK_SLOT_ITEM_START; i < BANK_SLOT_ITEM_END; i++)
            if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
                items.push_back(item);

        for (uint8 i = BANK_SLOT_BAG_START; i < BANK_SLOT_BAG_END; i++)
            if (Bag* bag = player->GetBagByPos(i))
                for (uint32 j = 0; j < bag->GetBagSize(); j++)
                    if (Item* item = player->GetItemByPos(i, j))
                        items.push_back(item);
    }

    return items;
}

bool ItemUpgrade::IsAllowedItem(const Item* item) const
{
    if (allowedItems.empty())
        return true;

    return allowedItems.find(item->GetEntry()) != allowedItems.end();
}

bool ItemUpgrade::IsBlacklistedItem(const Item* item) const
{
    if (blacklistedItems.empty())
        return false;

    return blacklistedItems.find(item->GetEntry()) != blacklistedItems.end();
}

void ItemUpgrade::SendItemPacket(Player* player, Item* item) const
{
    ItemTemplate const* pProto = sObjectMgr->GetItemTemplate(item->GetEntry());
    std::string Name = pProto->Name1;
    std::string Description = pProto->Description;

    int loc_idx = player->GetSession()->GetSessionDbLocaleIndex();
    if (loc_idx >= 0)
    {
        if (ItemLocale const* il = sObjectMgr->GetItemLocale(pProto->ItemId))
        {
            ObjectMgr::GetLocaleString(il->Name, loc_idx, Name);
            ObjectMgr::GetLocaleString(il->Description, loc_idx, Description);
        }
    }
    // guess size
    WorldPacket queryData(SMSG_ITEM_QUERY_SINGLE_RESPONSE, 600);
    queryData << pProto->ItemId;
    queryData << pProto->Class;
    queryData << pProto->SubClass;
    queryData << pProto->SoundOverrideSubclass;
    queryData << Name;
    queryData << uint8(0x00);                                //pProto->Name2; // blizz not send name there, just uint8(0x00); <-- \0 = empty string = empty name...
    queryData << uint8(0x00);                                //pProto->Name3; // blizz not send name there, just uint8(0x00);
    queryData << uint8(0x00);                                //pProto->Name4; // blizz not send name there, just uint8(0x00);
    queryData << pProto->DisplayInfoID;
    queryData << pProto->Quality;
    queryData << pProto->Flags;
    queryData << pProto->Flags2;
    queryData << pProto->BuyPrice;
    queryData << pProto->SellPrice;
    queryData << pProto->InventoryType;
    queryData << pProto->AllowableClass;
    queryData << pProto->AllowableRace;
    if (GetBoolConfig(CONFIG_ITEM_UPGRADE_SEND_PACKETS) && pProto->StatsCount > 0)
        queryData << CalculateItemLevel(player, item).second;
    else
        queryData << pProto->ItemLevel;
    queryData << pProto->RequiredLevel;
    queryData << pProto->RequiredSkill;
    queryData << pProto->RequiredSkillRank;
    queryData << pProto->RequiredSpell;
    queryData << pProto->RequiredHonorRank;
    queryData << pProto->RequiredCityRank;
    queryData << pProto->RequiredReputationFaction;
    queryData << pProto->RequiredReputationRank;
    queryData << int32(pProto->MaxCount);
    queryData << int32(pProto->Stackable);
    queryData << pProto->ContainerSlots;
    queryData << pProto->StatsCount;                         // item stats count
    for (uint32 i = 0; i < pProto->StatsCount; ++i)
    {
        queryData << pProto->ItemStat[i].ItemStatType;
        if (GetBoolConfig(CONFIG_ITEM_UPGRADE_SEND_PACKETS))
            queryData << HandleStatModifier(player, item, pProto->ItemStat[i].ItemStatType, pProto->ItemStat[i].ItemStatValue, MAX_ENCHANTMENT_SLOT);
        else
            queryData << pProto->ItemStat[i].ItemStatValue;
    }
    queryData << pProto->ScalingStatDistribution;            // scaling stats distribution
    queryData << pProto->ScalingStatValue;                   // some kind of flags used to determine stat values column
    for (int i = 0; i < MAX_ITEM_PROTO_DAMAGES; ++i)
    {
        if (GetBoolConfig(CONFIG_ITEM_UPGRADE_SEND_PACKETS))
        {
            std::pair<float, float> upgradedDmgInfo = HandleWeaponModifier(player, item, pProto->Damage[i].DamageMin, pProto->Damage[i].DamageMax);
            queryData << upgradedDmgInfo.first;
            queryData << upgradedDmgInfo.second;
        }
        else
        {
            queryData << pProto->Damage[i].DamageMin;
            queryData << pProto->Damage[i].DamageMax;
        }

        queryData << pProto->Damage[i].DamageType;
    }

    // resistances (7)
    queryData << pProto->Armor;
    queryData << pProto->HolyRes;
    queryData << pProto->FireRes;
    queryData << pProto->NatureRes;
    queryData << pProto->FrostRes;
    queryData << pProto->ShadowRes;
    queryData << pProto->ArcaneRes;

    if (GetBoolConfig(CONFIG_ITEM_UPGRADE_SEND_PACKETS))
        queryData << HandleWeaponSpeedModifier(player, item);
    else
        queryData << pProto->Delay;
    queryData << pProto->AmmoType;
    queryData << pProto->RangedModRange;

    for (int s = 0; s < MAX_ITEM_PROTO_SPELLS; ++s)
    {
        // send DBC data for cooldowns in same way as it used in Spell::SendSpellCooldown
        // use `item_template` or if not set then only use spell cooldowns
        SpellInfo const* spell = sSpellMgr->GetSpellInfo(pProto->Spells[s].SpellId);
        if (spell)
        {
            bool db_data = pProto->Spells[s].SpellCooldown >= 0 || pProto->Spells[s].SpellCategoryCooldown >= 0;

            queryData << pProto->Spells[s].SpellId;
            queryData << pProto->Spells[s].SpellTrigger;
            queryData << int32(pProto->Spells[s].SpellCharges);

            if (db_data)
            {
                queryData << uint32(pProto->Spells[s].SpellCooldown);
                queryData << uint32(pProto->Spells[s].SpellCategory);
                queryData << uint32(pProto->Spells[s].SpellCategoryCooldown);
            }
            else
            {
                queryData << uint32(spell->RecoveryTime);
                queryData << uint32(spell->GetCategory());
                queryData << uint32(spell->CategoryRecoveryTime);
            }
        }
        else
        {
            queryData << uint32(0);
            queryData << uint32(0);
            queryData << uint32(0);
            queryData << uint32(-1);
            queryData << uint32(0);
            queryData << uint32(-1);
        }
    }
    queryData << pProto->Bonding;
    queryData << Description;
    queryData << pProto->PageText;
    queryData << pProto->LanguageID;
    queryData << pProto->PageMaterial;
    queryData << pProto->StartQuest;
    queryData << pProto->LockID;
    queryData << int32(pProto->Material);
    queryData << pProto->Sheath;
    queryData << pProto->RandomProperty;
    queryData << pProto->RandomSuffix;
    queryData << pProto->Block;
    queryData << pProto->ItemSet;
    queryData << pProto->MaxDurability;
    queryData << pProto->Area;
    queryData << pProto->Map;                                // Added in 1.12.x & 2.0.1 client branch
    queryData << pProto->BagFamily;
    queryData << pProto->TotemCategory;
    for (int s = 0; s < MAX_ITEM_PROTO_SOCKETS; ++s)
    {
        queryData << pProto->Socket[s].Color;
        queryData << pProto->Socket[s].Content;
    }
    queryData << pProto->socketBonus;
    queryData << pProto->GemProperties;
    queryData << pProto->RequiredDisenchantSkill;
    queryData << pProto->ArmorDamageModifier;
    queryData << pProto->Duration;                           // added in 2.4.2.8209, duration (seconds)
    queryData << pProto->ItemLimitCategory;                  // WotLK, ItemLimitCategory
    queryData << pProto->HolidayId;                          // Holiday.dbc?
    player->GetSession()->SendPacket(&queryData);
}

void ItemUpgrade::UpdateVisualCache(Player* player)
{
    std::map<uint32, std::vector<ItemUpgradeInfo>> entryUpgradeMap;
    std::vector<Item*> items = GetPlayerItems(player, true);
    std::vector<Item*>::const_iterator citer = items.begin();
    for (citer; citer != items.end(); ++citer)
    {
        const Item* item = *citer;
        ItemUpgradeInfo upgradeInfo;
        upgradeInfo.itemGuid = item->GetGUID();
        upgradeInfo.upgrades = FindUpgradesForItem(player, item);
        upgradeInfo.weaponUpgrade = FindUpgradeForWeapon(characterWeaponUpgradeData, player, item);
        upgradeInfo.weaponSpeedUpgrade = FindUpgradeForWeaponSpeed(player, item);
        entryUpgradeMap[item->GetEntry()].push_back(upgradeInfo);
    }

    auto chooseVisualItem = [&](const uint32 entry) -> const ItemUpgradeInfo* {
        auto emptyUpgrade = [](const ItemUpgradeInfo* itemUpgradeInfo)
            {
                return itemUpgradeInfo->upgrades.empty()
                    && itemUpgradeInfo->weaponUpgrade == nullptr
                    && itemUpgradeInfo->weaponSpeedUpgrade == nullptr;
            };

        const std::vector<ItemUpgradeInfo>& upgradeInfo = entryUpgradeMap.at(entry);
        const ItemUpgradeInfo* highestStatUpgrade = &upgradeInfo[0];
        const ItemUpgradeInfo* highestWeaponUpgrade = &upgradeInfo[0];
        const ItemUpgradeInfo* highestWeaponSpeedUpgrade = &upgradeInfo[0];
        for (size_t i = 1; i < upgradeInfo.size(); i++)
        {
            const ItemUpgradeInfo& itemUpgradeInfo = upgradeInfo[i];
            if (itemUpgradeInfo.upgrades.size() > highestStatUpgrade->upgrades.size())
                highestStatUpgrade = &itemUpgradeInfo;
            if (itemUpgradeInfo.weaponUpgrade != nullptr && (highestWeaponUpgrade->weaponUpgrade == nullptr || itemUpgradeInfo.weaponUpgrade->statModPct > highestWeaponUpgrade->weaponUpgrade->statModPct))
                highestWeaponUpgrade = &itemUpgradeInfo;
            if (itemUpgradeInfo.weaponSpeedUpgrade != nullptr && (highestWeaponSpeedUpgrade->weaponSpeedUpgrade == nullptr || itemUpgradeInfo.weaponSpeedUpgrade->statModPct > highestWeaponSpeedUpgrade->weaponSpeedUpgrade->statModPct))
                highestWeaponSpeedUpgrade = &itemUpgradeInfo;
        }
        if (emptyUpgrade(highestStatUpgrade) && emptyUpgrade(highestWeaponUpgrade) && emptyUpgrade(highestWeaponSpeedUpgrade))
            return &upgradeInfo[0];

        if (GetItemVisualsPriority() == PRIORITIZE_STATS)
        {
            if (!highestStatUpgrade->upgrades.empty())
                return highestStatUpgrade;
            else
            {
                if (highestWeaponUpgrade->weaponUpgrade != nullptr)
                    return highestWeaponUpgrade;
                if (highestWeaponSpeedUpgrade->weaponSpeedUpgrade != nullptr)
                    return highestWeaponSpeedUpgrade;
            }
        }
        else
        {
            if (highestWeaponUpgrade->weaponUpgrade != nullptr)
                return highestWeaponUpgrade;
            else if (highestWeaponSpeedUpgrade->weaponSpeedUpgrade != nullptr)
                return highestWeaponSpeedUpgrade;
            else
            {
                if (!highestStatUpgrade->upgrades.empty())
                    return highestStatUpgrade;
            }
        }

        return &upgradeInfo[0];
        };

    for (const auto& p : entryUpgradeMap)
    {
        const ItemUpgradeInfo* itemUpgradeInfo = chooseVisualItem(p.first);
        ASSERT(itemUpgradeInfo != nullptr);
        Item* item = player->GetItemByGuid(itemUpgradeInfo->itemGuid);
        if (item != nullptr)
            SendItemPacket(player, item);
    }
}

void ItemUpgrade::VisualFeedback(Player* player)
{
    player->CastSpell(player, VISUAL_FEEDBACK_SPELL_ID, true);
}

std::pair<uint32, uint32> ItemUpgrade::CalculateItemLevel(const Player* player, Item* item, const UpgradeStat* upgrade) const
{
    std::unordered_map<uint32, const UpgradeStat*> upgrades;
    if (upgrade != nullptr)
        upgrades[upgrade->statType] = upgrade;
    return CalculateItemLevel(player, item, upgrades);
}

std::pair<uint32, uint32> ItemUpgrade::CalculateItemLevel(const Player* player, Item* item, std::unordered_map<uint32, const UpgradeStat*> upgrades) const
{
    const ItemTemplate* proto = item->GetTemplate();
    std::vector<_ItemStat> originalStats = LoadItemStatInfo(item);
    if (originalStats.empty())
        return std::make_pair(proto->ItemLevel, proto->ItemLevel);

    uint32 originalSum = std::accumulate(originalStats.begin(), originalStats.end(), 0, [&](uint32 a, const _ItemStat& stat) { return a + stat.ItemStatValue; });
    uint32 upgradedSum = 0;

    for (const _ItemStat& stat : originalStats)
    {
        if (upgrades.find(stat.ItemStatType) != upgrades.end())
            upgradedSum += (uint32)CalculateModPct(stat.ItemStatValue, upgrades.at(stat.ItemStatType));
        else
            upgradedSum += HandleStatModifier(player, item, stat.ItemStatType, stat.ItemStatValue, MAX_ENCHANTMENT_SLOT);
    }

    if (upgradedSum <= originalSum)
        return std::make_pair(proto->ItemLevel, proto->ItemLevel);

    return std::make_pair(proto->ItemLevel, (upgradedSum * proto->ItemLevel) / originalSum);
}

bool ItemUpgrade::ChooseRandomUpgrade(Player* player, Item* item)
{
    if (!GetBoolConfig(CONFIG_ITEM_UPGRADE_ENABLED))
        return false;

    if (!GetBoolConfig(CONFIG_ITEM_UPGRADE_RANDOM_UPGRADES))
        return false;

    if (!IsAllowedItem(item) || IsBlacklistedItem(item))
        return false;

    if (!FindUpgradesForItem(player, item).empty())
        return false;

    if (!roll_chance_f(GetFloatConfig(CONFIG_ITEM_UPGRADE_RANDOM_UPGRADES_CHANCE)))
        return false;

    uint32 statCountToUpgrade = urand(1, (uint32)GetIntConfig(CONFIG_ITEM_UPGRADE_RANDOM_UPGRADES_MAX_STATS));
    std::vector<_ItemStat> statTypes = LoadItemStatInfo(item);
    std::vector<const UpgradeStat*> upgrades;
    for (const _ItemStat& stat : statTypes)
    {
        if (!IsAllowedStatType(stat.ItemStatType))
            continue;

        const UpgradeStat* foundUpgradeStat = FindNearestUpgradeStat(stat.ItemStatType, (uint16)urand(1, (uint32)GetIntConfig(CONFIG_ITEM_UPGRADE_RANDOM_UPGRADES_MAX_RANK)), item);
        if (foundUpgradeStat != nullptr)
            upgrades.push_back(foundUpgradeStat);
    }

    if (upgrades.empty())
        return false;

    Acore::Containers::RandomShuffle(upgrades);
    uint32 currentStatCount = 0;
    for (const UpgradeStat* stat : upgrades)
    {
        if (currentStatCount == statCountToUpgrade)
            break;

        AddUpgradeForNewItem(player, item, stat, GetStatByType(statTypes, stat->statType));

        currentStatCount++;
    }

    return true;
}

bool ItemUpgrade::AddUpgradeForNewItem(Player* player, Item* item, const UpgradeStat* upgrade, const _ItemStat* stat)
{
    if (stat == nullptr)
        return false;

    const UpgradeStat* foundUpgrade = FindUpgradeForItem(player, item, upgrade->statType);
    std::vector<CharacterUpgrade>& upgrades = characterUpgradeData[player->GetGUID().GetCounter()];
    if (foundUpgrade != nullptr)
        return false;
    else
        AddItemUpgradeToDB(player, item, upgrade);

    CharacterUpgrade newUpgrade;
    newUpgrade.guid = player->GetGUID().GetCounter();
    newUpgrade.itemGuid = item->GetGUID();
    newUpgrade.upgradeStat = upgrade;
    upgrades.push_back(newUpgrade);

    std::pair<uint32, uint32> itemLevel = CalculateItemLevel(player, item);
    Notify(player, IU_TEXT_LOOT, ItemLink(player, item), StatName(player->GetSession(), upgrade->statType), upgrade->statRank,
        FormatFloat(upgrade->statModPct), stat->ItemStatValue, CalculateModPct(stat->ItemStatValue, upgrade), itemLevel.second);

    SendItemPacket(player, item);

    return true;
}

void ItemUpgrade::AddItemUpgradeToDB(const Player* player, const Item* item, const UpgradeStat* upgrade) const
{
    CharacterDatabase.Execute("INSERT INTO character_item_upgrade (guid, item_guid, stat_id) VALUES ({}, {}, {})",
        player->GetGUID().GetCounter(), item->GetGUID().GetCounter(), upgrade->statId);
}

const ItemUpgrade::UpgradeStat* ItemUpgrade::FindNearestUpgradeStat(uint32 statType, uint16 rank, const Item* item) const
{
    while (rank > 0)
    {
        const UpgradeStat* foundStat = FindUpgradeStat(statType, rank);
        if (foundStat != nullptr && CanApplyUpgradeForItem(item, foundStat))
            return foundStat;

        rank--;
    }

    return nullptr;
}

bool ItemUpgrade::IsAllowedStatForItem(const Item* item, const UpgradeStat* upgrade) const
{
    if (allowedStatItems.find(upgrade->statId) == allowedStatItems.end())
        return true;

    const std::set<uint32>& allowedStatsForItems = allowedStatItems.at(upgrade->statId);
    return allowedStatsForItems.find(item->GetEntry()) != allowedStatsForItems.end();
}

bool ItemUpgrade::IsBlacklistedStatForItem(const Item* item, const UpgradeStat* upgrade) const
{
    if (blacklistedStatItems.find(upgrade->statId) == blacklistedStatItems.end())
        return false;

    const std::set<uint32>& blacklistedStatsForItems = blacklistedStatItems.at(upgrade->statId);
    return blacklistedStatsForItems.find(item->GetEntry()) != blacklistedStatsForItems.end();
}

bool ItemUpgrade::CanApplyUpgradeForItem(const Item* item, const UpgradeStat* upgrade) const
{
    return IsAllowedStatForItem(item, upgrade) && !IsBlacklistedStatForItem(item, upgrade);
}

bool ItemUpgrade::CheckDataValidity() const
{
    if (upgradeStatList.empty())
        return true;

    bool ok = true;
    for (const UpgradeStat& upgrade : upgradeStatList)
    {
        if (!IsValidStatType(upgrade.statType))
        {
            LOG_ERROR("sql.sql", "FATAL: Table `mod_item_upgrade_stats` has invalid `stat_type` {}", upgrade.statType);
            ok = false;
        }
        if (upgrade.statModPct <= 0)
        {
            LOG_ERROR("sql.sql", "FATAL: Table `mod_item_upgrade_stats` has invalid `stat_mod_pct` {}", upgrade.statModPct);
            ok = false;
        }
    }

    if (!ok)
        return false;

    std::unordered_map<uint32, std::vector<uint16>> ranksMap;
    for (const UpgradeStat& upgrade : upgradeStatList)
        ranksMap[upgrade.statType].push_back(upgrade.statRank);

    for (auto& rpair : ranksMap)
    {
        std::vector<uint16>& ranks = rpair.second;
        std::sort(ranks.begin(), ranks.end());
        if (ranks[0] != 1)
        {
            ok = false;
            LOG_ERROR("sql.sql", "FATAL: Table `mod_item_upgrade_stats` has invalid starting rank (`stat_rank`) {} for stat type (`stat_type`) {}", ranks[0], rpair.first);
        }

        bool consecutive = true;
        for (uint32 i = 1; i < ranks.size(); i++)
        {
            if (ranks[i] != ranks[i - 1] + 1)
            {
                consecutive = false;
                break;
            }
        }
        if (!consecutive)
        {
            ok = false;
            LOG_ERROR("sql.sql", "FATAL: Table `mod_item_upgrade_stats` does not have consecutive ranks (`stat_rank`) for stat type (`stat_type`) {}", rpair.first);
        }
    }

    return ok;
}

const ItemUpgrade::StatRequirementContainer* ItemUpgrade::GetStatRequirements(const UpgradeStat* upgrade, const Item* item) const
{
    if (overrideStatRequirements.find(item->GetEntry()) != overrideStatRequirements.end())
    {
        const std::unordered_map<uint32, StatRequirementContainer>& itemReqs = overrideStatRequirements.at(item->GetEntry());
        if (itemReqs.find(upgrade->statId) != itemReqs.end())
            return &itemReqs.at(upgrade->statId);
    }

    if (baseStatRequirements.find(upgrade->statId) != baseStatRequirements.end())
        return &baseStatRequirements.at(upgrade->statId);

    return nullptr;
}

bool ItemUpgrade::EmptyRequirements(const StatRequirementContainer* reqs) const
{
    if (reqs == nullptr || reqs->size() == 0)
        return true;

    if (reqs->size() == 1 && reqs->at(0).reqType == REQ_TYPE_NONE)
        return true;

    return false;
}

void ItemUpgrade::LoadWeaponUpgradePercents(UpgradeStatContainer& upgradeStats, CharacterUpgradeContainer& characterUpgradeContainer, const std::string& percents,
    const char* option, float maxPct)
{
    upgradeStats.clear();

    // A mistyped value of the configuration is reported and skipped, never used.
    std::vector<float> weaponUpgradePercents;
    for (std::string_view token : Acore::Tokenize(percents, ',', false))
    {
        std::string_view value = TrimConfigValue(token);
        if (value.empty())
            continue;

        Optional<float> pct = Acore::StringTo<float>(value);
        if (!pct || !std::isfinite(*pct) || *pct <= 0.0f || (maxPct > 0.0f && *pct >= maxPct))
        {
            if (maxPct > 0.0f)
                LOG_ERROR("server.loading", "{}: `{}` is not a percentage above 0 and below {}, skipped", option, value, maxPct);
            else
                LOG_ERROR("server.loading", "{}: `{}` is not a percentage above 0, skipped", option, value);
            continue;
        }

        weaponUpgradePercents.push_back(*pct);
    }
    std::sort(weaponUpgradePercents.begin(), weaponUpgradePercents.end());
    weaponUpgradePercents.erase(std::unique(weaponUpgradePercents.begin(), weaponUpgradePercents.end()), weaponUpgradePercents.end());

    for (size_t i = 0; i < weaponUpgradePercents.size(); i++)
    {
        UpgradeStat weaponUpgradeStat;
        weaponUpgradeStat.statId = i + 1;
        weaponUpgradeStat.statRank = i + 1;
        weaponUpgradeStat.statModPct = weaponUpgradePercents[i];
        weaponUpgradeStat.statType = 0;
        upgradeStats.push_back(weaponUpgradeStat);
    }

    for (auto itr = characterUpgradeContainer.begin(); itr != characterUpgradeContainer.end(); ++itr)
    {
        std::vector<CharacterUpgrade>& weaponUpgrades = itr->second;
        for (CharacterUpgrade& upgrade : weaponUpgrades)
        {
            upgrade.upgradeStat = FindWeaponUpgradeStat(upgradeStats, upgrade.upgradeStatModPct);
            if (upgrade.upgradeStat == nullptr)
                upgrade.upgradeStat = FindNearestWeaponUpgradeStat(upgradeStats, upgrade.upgradeStatModPct);
        }
    }
}

/*static*/ std::pair<float, float> ItemUpgrade::GetItemProtoDamage(const ItemTemplate* proto)
{
    return std::make_pair(proto->Damage[0].DamageMin, proto->Damage[0].DamageMax);
}

/*static*/ std::pair<float, float> ItemUpgrade::GetItemProtoDamage(const Item* item)
{
    return GetItemProtoDamage(item->GetTemplate());
}

/*static*/ uint32 ItemUpgrade::GetItemProtoDelay(const ItemTemplate* proto)
{
    return proto->Delay;
}

/*static*/ uint32 ItemUpgrade::GetItemProtoDelay(const Item* item)
{
    return GetItemProtoDelay(item->GetTemplate());
}

bool ItemUpgrade::MeetsWeaponUpgradeRequirement(const Player* player) const
{
    return MeetsRequirement(player, &weaponUpgradeReqs);
}

bool ItemUpgrade::MeetsWeaponSpeedUpgradeRequirement(const Player* player) const
{
    return MeetsRequirement(player, &weaponSpeedUpgradeReqs);
}

void ItemUpgrade::BuildWeaponUpgradeReqs()
{
    weaponUpgradeReqs.clear();

    const ItemTemplate* tokenProto = sObjectMgr->GetItemTemplate(GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_DAMAGE_TOKEN));
    if (tokenProto != nullptr)
    {
        UpgradeStatReq tokenReq;
        tokenReq.reqType = REQ_TYPE_ITEM;
        tokenReq.reqVal1 = (float)GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_DAMAGE_TOKEN);
        tokenReq.reqVal2 = (float)GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_DAMAGE_TOKEN_COUNT);
        weaponUpgradeReqs.push_back(tokenReq);
    }

    if (GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_DAMAGE_MONEY) > 0)
    {
        UpgradeStatReq moneyReq;
        moneyReq.reqType = REQ_TYPE_COPPER;
        moneyReq.reqVal1 = (float)GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_DAMAGE_MONEY);
        weaponUpgradeReqs.push_back(moneyReq);
    }
}

void ItemUpgrade::BuildWeaponSpeedUpgradeReqs()
{
    weaponSpeedUpgradeReqs.clear();

    const ItemTemplate* tokenProto = sObjectMgr->GetItemTemplate(GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_SPEED_TOKEN));
    if (tokenProto != nullptr)
    {
        UpgradeStatReq tokenReq;
        tokenReq.reqType = REQ_TYPE_ITEM;
        tokenReq.reqVal1 = (float)GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_SPEED_TOKEN);
        tokenReq.reqVal2 = (float)GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_SPEED_TOKEN_COUNT);
        weaponSpeedUpgradeReqs.push_back(tokenReq);
    }

    if (GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_SPEED_MONEY) > 0)
    {
        UpgradeStatReq moneyReq;
        moneyReq.reqType = REQ_TYPE_COPPER;
        moneyReq.reqVal1 = (float)GetIntConfig(CONFIG_ITEM_UPGRADE_WEAPON_SPEED_MONEY);
        weaponSpeedUpgradeReqs.push_back(moneyReq);
    }
}

ItemUpgrade::ItemVisualsPriority ItemUpgrade::GetItemVisualsPriority() const
{
    int32 priority = cfg.GetIntConfig(CONFIG_ITEM_UPGRADE_SEND_PACKETS_PRIORITY);
    switch (priority)
    {
    case 0:
        return PRIORITIZE_STATS;
    case 1:
        return PRIORITIZE_WEAPON_DAMAGE;
    default:
        return PRIORITIZE_STATS;
    }
}

bool ItemUpgrade::IsInactiveStatUpgrade(const Item* item, const UpgradeStat* upgradeStat) const
{
    if (!GetBoolConfig(CONFIG_ITEM_UPGRADE_ENABLED))
        return true;

    if (!IsAllowedItem(item)
        || IsBlacklistedItem(item)
        || !IsAllowedStatType(upgradeStat->statType)
        || !CanApplyUpgradeForItem(item, upgradeStat))
        return true;

    return false;
}

bool ItemUpgrade::IsInactiveWeaponUpgrade() const
{
    return !GetBoolConfig(CONFIG_ITEM_UPGRADE_ENABLED) || !GetBoolConfig(CONFIG_ITEM_UPGRADE_WEAPON_DAMAGE);
}

bool ItemUpgrade::IsInactiveWeaponSpeedUpgrade() const
{
    return !GetBoolConfig(CONFIG_ITEM_UPGRADE_ENABLED) || !GetBoolConfig(CONFIG_ITEM_UPGRADE_WEAPON_SPEED);
}

void ItemUpgrade::RefreshWeaponSpeed(Player* player)
{
    RefreshWeaponSpeed(player, EQUIPMENT_SLOT_MAINHAND);
    RefreshWeaponSpeed(player, EQUIPMENT_SLOT_OFFHAND);
    RefreshWeaponSpeed(player, EQUIPMENT_SLOT_RANGED);
}

void ItemUpgrade::RefreshWeaponSpeed(Player* player, EquipmentSlots slot)
{
    if (player->IsInFeralForm())
        return;

    Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
    if (!IsValidWeaponForSpeedUpgrade(item, player))
        return;

    uint32 delay = HandleWeaponSpeedModifier(player, item);
    if (slot == EQUIPMENT_SLOT_RANGED)
        player->SetAttackTime(RANGED_ATTACK, delay);
    else if (slot == EQUIPMENT_SLOT_MAINHAND)
        player->SetAttackTime(BASE_ATTACK, delay);
    else if (slot == EQUIPMENT_SLOT_OFFHAND)
        player->SetAttackTime(OFF_ATTACK, delay);

    if (player->CanModifyStats())
        player->UpdateDamagePhysical(WeaponAttackType(Player::GetAttackBySlot(slot)));
}
