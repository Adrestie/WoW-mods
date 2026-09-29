/*
 * Operations of the upgrade window (data/lua/ItemUpgrade_Client.lua).
 *
 * The window reaches them through the core's addon command channel
 * (".item_upgrade state" and ".item_upgrade upgrade", see
 * item_upgrade_commandscript.cpp); every rule stays here, the window only
 * shows what these lines say and sends back what the player picked.
 *
 * Lines sent to the window, one per addon message, fields separated by spaces:
 *   #ITEM <item guid> <entry> <stats 0/1> <damage 0/1> <speed 0/1>
 *   #STAT <type> <base> <rank> <max rank> <current> <next|-1> <next %|-1> <refused 0/1> <inactive 0/1> <cost>
 *   #DMG  <rank> <max rank> <current %> <next %|-1> <base min> <base max> <min> <max> <next min|-1> <next max|-1> <cost>
 *   #SPD  <rank> <max rank> <current %> <next %|-1> <base delay> <delay> <next delay|-1> <cost>
 *   #END
 * <cost> is the cost of the next rank: "-" when free or at the last rank,
 * otherwise "type:value[:count]" joined by ",", type as in
 * mod_item_upgrade_stats_req (1 copper, 2 honor, 3 arena points, 4 item).
 */

#include <cmath>
#include "Player.h"
#include "Bag.h"
#include "item_upgrade.h"

namespace
{
    bool CanUpgradeStats(const ItemUpgrade* iu, const Player* player, const Item* item)
    {
        return iu->IsValidItemForUpgrade(item, player) && iu->IsAllowedItem(item) && !iu->IsBlacklistedItem(item);
    }

    bool CanUpgradeDamage(const ItemUpgrade* iu, const Player* player, const Item* item)
    {
        return iu->GetBoolConfig(CONFIG_ITEM_UPGRADE_WEAPON_DAMAGE) && !iu->weaponUpgradeStats.empty()
            && iu->IsValidWeaponForUpgrade(item, player);
    }

    // Speed: only a weapon worn in a hand or in the ranged slot.
    bool CanUpgradeSpeed(const ItemUpgrade* iu, const Player* player, const Item* item)
    {
        return iu->GetBoolConfig(CONFIG_ITEM_UPGRADE_WEAPON_SPEED) && !iu->weaponSpeedUpgradeStats.empty()
            && iu->IsValidWeaponForSpeedUpgrade(item, player);
    }

    // Weapon ranks follow each other: the first one, then the one after the current.
    const ItemUpgrade::UpgradeStat* NextWeaponRank(const ItemUpgrade* iu, const ItemUpgrade::UpgradeStatContainer& ranks, const ItemUpgrade::UpgradeStat* current)
    {
        if (!current)
            return ranks.empty() ? nullptr : &ranks[0];

        return iu->FindNextWeaponUpgradeStat(ranks, current->statModPct);
    }

    std::string EncodeCost(const ItemUpgrade* iu, const ItemUpgrade::StatRequirementContainer* reqs)
    {
        if (iu->EmptyRequirements(reqs))
            return "-";

        std::string encoded;
        for (const ItemUpgrade::UpgradeStatReq& req : *reqs)
        {
            if (req.reqType == ItemUpgrade::REQ_TYPE_NONE)
                continue;

            if (!encoded.empty())
                encoded += ',';

            encoded += Acore::StringFormat("{}:{}", uint32(req.reqType), uint32(req.reqVal1));
            if (req.reqType == ItemUpgrade::REQ_TYPE_ITEM)
                encoded += Acore::StringFormat(":{}", uint32(req.reqVal2));
        }

        return encoded.empty() ? "-" : encoded;
    }

    std::string Pct(float pct)
    {
        return ItemUpgrade::FormatFloat(pct);
    }
}

/*static*/ Item* ItemUpgrade::FindItemForAddon(Player* player, uint8 container, uint8 slot)
{
    // Equipment: the client counts its slots from 1 (head) to 19 (tabard).
    if (container == ADDON_EQUIPMENT)
    {
        if (slot < 1 || slot > EQUIPMENT_SLOT_END)
            return nullptr;

        return player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot - 1);
    }

    if (slot < 1)
        return nullptr;

    // Backpack: slots 1-16 of container 0.
    if (container == 0)
    {
        if (slot > INVENTORY_SLOT_ITEM_END - INVENTORY_SLOT_ITEM_START)
            return nullptr;

        return player->GetItemByPos(INVENTORY_SLOT_BAG_0, INVENTORY_SLOT_ITEM_START + slot - 1);
    }

    // Bags: containers 1-4, slots from 1.
    if (container > INVENTORY_SLOT_BAG_END - INVENTORY_SLOT_BAG_START)
        return nullptr;

    Bag* bag = player->GetBagByPos(INVENTORY_SLOT_BAG_START + container - 1);
    if (!bag || slot > bag->GetBagSize())
        return nullptr;

    return bag->GetItemByPos(slot - 1);
}

std::vector<std::string> ItemUpgrade::DescribeItemForAddon(Player* player, Item* item) const
{
    std::vector<std::string> lines;
    bool stats = CanUpgradeStats(this, player, item);
    bool damage = CanUpgradeDamage(this, player, item);
    bool speed = CanUpgradeSpeed(this, player, item);

    lines.push_back(Acore::StringFormat("#ITEM {} {} {} {} {}", item->GetGUID().GetCounter(), item->GetEntry(),
        stats ? 1 : 0, damage ? 1 : 0, speed ? 1 : 0));

    if (stats)
    {
        // In the order of the ranks table (mod_item_upgrade_stats).
        std::vector<_ItemStat> statInfoList = LoadItemStatInfo(item);
        std::set<uint32> processed;
        for (const UpgradeStat& stat : upgradeStatList)
        {
            if (processed.count(stat.statType) || !IsAllowedStatType(stat.statType))
                continue;

            const _ItemStat* statInfo = GetStatByType(statInfoList, stat.statType);
            if (!statInfo)
                continue;

            processed.insert(stat.statType);

            int32 base = statInfo->ItemStatValue;
            const UpgradeStat* current = FindUpgradeForItem(player, item, stat.statType);
            const UpgradeStat* next = FindUpgradeStat(stat.statType, current ? current->statRank + 1 : 1);
            if (!current && !next)
                continue;

            lines.push_back(Acore::StringFormat("#STAT {} {} {} {} {} {} {} {} {} {}",
                stat.statType, base,
                current ? current->statRank : 0, MaxRankForStat(stat.statType),
                current ? CalculateModPct(base, current) : base,
                next ? CalculateModPct(base, next) : -1,
                next ? Pct(next->statModPct) : "-1",
                next && !CanApplyUpgradeForItem(item, next) ? 1 : 0,
                current && !CanApplyUpgradeForItem(item, current) ? 1 : 0,
                next ? EncodeCost(this, GetStatRequirements(next, item)) : "-"));
        }
    }

    if (damage)
    {
        std::pair<float, float> dmg = GetItemProtoDamage(item);
        const UpgradeStat* current = FindUpgradeForWeaponDamage(player, item);
        const UpgradeStat* next = NextWeaponRank(this, weaponUpgradeStats, current);
        auto upgraded = [&](const UpgradeStat* rank)
        {
            if (!rank)
                return std::make_pair(dmg.first, dmg.second);
            return std::make_pair(std::floor(CalculateModPctF(dmg.first, rank)), std::ceil(CalculateModPctF(dmg.second, rank)));
        };
        std::pair<float, float> cur = upgraded(current);
        std::pair<float, float> nxt = upgraded(next);

        lines.push_back(Acore::StringFormat("#DMG {} {} {} {} {} {} {} {} {} {} {}",
            current ? current->statRank : 0, uint32(weaponUpgradeStats.size()),
            current ? Pct(current->statModPct) : "0", next ? Pct(next->statModPct) : "-1",
            FormatFloat(dmg.first, 0), FormatFloat(dmg.second, 0),
            FormatFloat(cur.first, 0), FormatFloat(cur.second, 0),
            next ? FormatFloat(nxt.first, 0) : "-1", next ? FormatFloat(nxt.second, 0) : "-1",
            next ? EncodeCost(this, &weaponUpgradeReqs) : "-"));
    }

    if (speed)
    {
        uint32 baseDelay = GetItemProtoDelay(item);
        const UpgradeStat* current = FindUpgradeForWeaponSpeed(player, item);
        const UpgradeStat* next = NextWeaponRank(this, weaponSpeedUpgradeStats, current);

        lines.push_back(Acore::StringFormat("#SPD {} {} {} {} {} {} {} {}",
            current ? current->statRank : 0, uint32(weaponSpeedUpgradeStats.size()),
            current ? Pct(current->statModPct) : "0", next ? Pct(next->statModPct) : "-1",
            baseDelay, current ? CalculatePctDecrease(baseDelay, current->statModPct) : baseDelay,
            next ? int64(CalculatePctDecrease(baseDelay, next->statModPct)) : int64(-1),
            next ? EncodeCost(this, &weaponSpeedUpgradeReqs) : "-"));
    }

    lines.push_back("#END");
    return lines;
}

uint32 ItemUpgrade::UpgradeForAddon(Player* player, Item* item, const std::vector<uint32>& statTypes, bool damage, bool speed)
{
    if (statTypes.empty() && !damage && !speed)
        return IU_TEXT_NOTHING_CHOSEN;

    // Every target is checked before anything is taken or written.
    std::vector<const UpgradeStat*> statUpgrades;
    std::vector<const StatRequirementContainer*> costs;
    if (!statTypes.empty())
    {
        if (!CanUpgradeStats(this, player, item))
            return IU_TEXT_NOT_UPGRADABLE;

        std::vector<_ItemStat> statInfoList = LoadItemStatInfo(item);
        for (uint32 statType : statTypes)
        {
            if (!IsAllowedStatType(statType) || !GetStatByType(statInfoList, statType))
                return IU_TEXT_UNAVAILABLE;

            const UpgradeStat* current = FindUpgradeForItem(player, item, statType);
            const UpgradeStat* next = FindUpgradeStat(statType, current ? current->statRank + 1 : 1);
            if (!next || !CanApplyUpgradeForItem(item, next))
                return IU_TEXT_UNAVAILABLE;

            statUpgrades.push_back(next);
            costs.push_back(GetStatRequirements(next, item));
        }
    }

    const UpgradeStat* damageUpgrade = nullptr;
    if (damage)
    {
        if (!CanUpgradeDamage(this, player, item))
            return IU_TEXT_NOT_UPGRADABLE;

        damageUpgrade = NextWeaponRank(this, weaponUpgradeStats, FindUpgradeForWeaponDamage(player, item));
        if (!damageUpgrade)
            return IU_TEXT_UNAVAILABLE;

        costs.push_back(&weaponUpgradeReqs);
    }

    const UpgradeStat* speedUpgrade = nullptr;
    if (speed)
    {
        if (!CanUpgradeSpeed(this, player, item))
            return IU_TEXT_NOT_UPGRADABLE;

        speedUpgrade = NextWeaponRank(this, weaponSpeedUpgradeStats, FindUpgradeForWeaponSpeed(player, item));
        if (!speedUpgrade)
            return IU_TEXT_UNAVAILABLE;

        costs.push_back(&weaponSpeedUpgradeReqs);
    }

    TotalCost total = SumRequirements(costs);
    if (!MeetsCost(player, total))
        return IU_TEXT_REQUIREMENTS;

    // The item's bonuses come off while its ranks change, then go back on
    // with the new values (stats and weapon damage go through those bonuses).
    bool equipped = item->IsEquipped();
    if (equipped)
        player->_ApplyItemMods(item, item->GetSlot(), false);

    for (const UpgradeStat* upgrade : statUpgrades)
        HandlePurchaseRank(player, item, upgrade);

    if (damageUpgrade)
        HandlePurchaseWeaponUpgrade(player, item, damageUpgrade, false);

    if (equipped)
        player->_ApplyItemMods(item, item->GetSlot(), true);

    // Speed is the attack time, set again by RefreshWeaponSpeed below.
    if (speedUpgrade)
        HandlePurchaseWeaponUpgrade(player, item, speedUpgrade, true);

    TakeCost(player, total);

    VisualFeedback(player);
    SendItemPacket(player, item);
    RefreshWeaponSpeed(player);

    return IU_TEXT_SUCCESS;
}
