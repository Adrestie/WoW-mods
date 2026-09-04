/*
 * Credits: silviu20092
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "item_upgrade.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include <iostream>

using namespace Acore::ChatCommands;

class item_upgrade_commandscript : public CommandScript
{
private:
    static std::unordered_map<uint32, uint32> cmdListUpgradesTimerMap;
    static constexpr uint32 listUpgradesDiffTimer = 10000;
public:
    item_upgrade_commandscript() : CommandScript("item_upgrade_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable itemUpgradeSubcommandTable =
        {
            { "reload", HandleReloadModItemUpgrade, SEC_ADMINISTRATOR, Console::Yes },
            { "lock",   HandleLockItemUpgrade,      SEC_ADMINISTRATOR, Console::Yes },
            { "list",   HandleListUpgrades,         SEC_PLAYER,        Console::Yes  },
            { "getstats",    HandleGetStatsCommand,    SEC_PLAYER, Console::Yes },
            { "getcost",     HandleGetCostCommand,     SEC_PLAYER, Console::Yes },
            { "doupgrade",   HandleDoUpgradeCommand,   SEC_PLAYER, Console::Yes },
            { "validate",    HandleValidateCommand,    SEC_PLAYER, Console::Yes }
        };

        static ChatCommandTable itemUpgradeCommandTable =
        {
            { "item_upgrade", itemUpgradeSubcommandTable }
        };

        return itemUpgradeCommandTable;
    }
private:
    static bool HandleReloadModItemUpgrade(ChatHandler* handler)
    {
        ItemUpgrade::PagedDataMap& pagedData = sItemUpgrade->GetPagedDataMap();
        for (auto& itr : pagedData)
            itr.second.reloaded = true;

        sItemUpgrade->SetReloading(true);
        sItemUpgrade->HandleDataReload(false);

        sItemUpgrade->LoadFromDB(true);

        sItemUpgrade->HandleDataReload(true);
        sItemUpgrade->SetReloading(false);

        handler->SendGlobalGMSysMessage("Item Upgrade module data successfully reloaded.");
        return true;
    }

    static bool HandleLockItemUpgrade(ChatHandler* handler)
    {
        sItemUpgrade->SetReloading(true);
        handler->SendSysMessage("Item Upgrade NPC is now locked, it is now safe to edit database tables. Release the lock by using .item_upgrade reload command");
        return true;
    }

    static bool HandleListUpgrades(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        if (!target)
            target = PlayerIdentifier::FromTargetOrSelf(handler);

        if (!target)
            return false;

        Player* player = target->GetConnectedPlayer();

        uint32 currentTime = getMSTime();
        uint32 lastTime = cmdListUpgradesTimerMap[player->GetGUID().GetCounter()];
        uint32 diff = getMSTimeDiff(lastTime, currentTime);
        if (lastTime > 0 && diff < listUpgradesDiffTimer)
        {
            handler->PSendSysMessage("Please try again in {} seconds.", (listUpgradesDiffTimer - diff) / 1000);
            return true;
        }
        cmdListUpgradesTimerMap[player->GetGUID().GetCounter()] = currentTime;

        uint32 upgradedItems = 0;
        uint32 upgradedStats = 0;
        uint32 weaponUpgrades = 0;
        for (uint8 i = EQUIPMENT_SLOT_START; i < EQUIPMENT_SLOT_END; i++)
        {
            if (const Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            {
                std::vector<const ItemUpgrade::UpgradeStat*> upgrades = sItemUpgrade->FindUpgradesForItem(player, item);
                const ItemUpgrade::UpgradeStat* weaponUpgrade = sItemUpgrade->FindUpgradeForWeaponDamage(player, item);
                const ItemUpgrade::UpgradeStat* weaponSpeedUpgrade = sItemUpgrade->FindUpgradeForWeaponSpeed(player, item);

                if (!upgrades.empty() || weaponUpgrade != nullptr || weaponSpeedUpgrade != nullptr)
                {
                    upgradedItems++;
                    std::string slot = ItemUpgrade::EquipmentSlotToString((EquipmentSlots)i);
                    handler->PSendSysMessage("{} [{}]", ItemUpgrade::ItemLink(player, item), slot);
                    if (!upgrades.empty())
                    {
                        upgradedStats += upgrades.size();
                        std::vector<_ItemStat> statInfo = ItemUpgrade::LoadItemStatInfo(item);
                        handler->PSendSysMessage("Found {} stat upgrades:", upgrades.size());
                        for (const auto* stat : upgrades)
                        {
                            const _ItemStat* foundStat = ItemUpgrade::GetStatByType(statInfo, stat->statType);
                            ASSERT(foundStat != nullptr);
                            std::ostringstream oss;
                            oss << "|cffb50505" << foundStat->ItemStatValue << "|r --> ";
                            oss << "|cff056e3a" << ItemUpgrade::CalculateModPct(foundStat->ItemStatValue, stat) << "|r";
                            std::ostringstream statusOss;
                            if (sItemUpgrade->IsInactiveStatUpgrade(item, stat))
                                statusOss << "|cffb50505INACTIVE|r";
                            else
                                statusOss << "|cff056e3aACTIVE|r";
                            handler->PSendSysMessage("{} increased by {}% [RANK {}] [{}] [{}]", ItemUpgrade::StatTypeToString(stat->statType), stat->statModPct, stat->statRank, oss.str(), statusOss.str());
                        }
                    }
                    if (weaponUpgrade != nullptr)
                    {
                        weaponUpgrades++;
                        std::pair<float, float> dmgInfo = ItemUpgrade::GetItemProtoDamage(item);
                        float upgradedMinDamage = std::floor(ItemUpgrade::CalculateModPctF(dmgInfo.first, weaponUpgrade));
                        float upgradedMaxDamage = std::ceil(ItemUpgrade::CalculateModPctF(dmgInfo.second, weaponUpgrade));

                        std::ostringstream statusOss;
                        if (sItemUpgrade->IsInactiveWeaponUpgrade())
                            statusOss << "|cffb50505INACTIVE|r";
                        else
                            statusOss << "|cff056e3aACTIVE|r";

                        handler->PSendSysMessage("This weapon is upgraded by {}%, [MIN DAMAGE {}], [MAX DAMAGE {}] [{}]",
                            ItemUpgrade::FormatFloat(weaponUpgrade->statModPct),
                            ItemUpgrade::FormatIncrease(dmgInfo.first, upgradedMinDamage),
                            ItemUpgrade::FormatIncrease(dmgInfo.second, upgradedMaxDamage),
                            statusOss.str());
                    }
                    if (weaponSpeedUpgrade != nullptr)
                    {
                        if (weaponUpgrade == nullptr)
                            weaponUpgrades++;

                        uint32 originalDelay = ItemUpgrade::GetItemProtoDelay(item);
                        uint32 newDelay = sItemUpgrade->HandleWeaponSpeedModifier(player, item);

                        std::ostringstream statusOss;
                        if (sItemUpgrade->IsInactiveWeaponSpeedUpgrade())
                            statusOss << "|cffb50505INACTIVE|r";
                        else
                            statusOss << "|cff056e3aACTIVE|r";

                        handler->PSendSysMessage("This weapon's speed is upgraded by {}%, [ORIGINAL SPEED {}] [NEW SPEED {}] [{}]",
                            ItemUpgrade::FormatFloat(weaponSpeedUpgrade->statModPct),
                            ItemUpgrade::FormatDelay(originalDelay),
                            ItemUpgrade::FormatDelay(newDelay),
                            statusOss.str());
                    }
                    handler->SendSysMessage("--------------- NEXT ITEM OR END ---------------");
                }
            }
        }

        if (upgradedItems == 0 && weaponUpgrades == 0)
            handler->PSendSysMessage("{} does not have any upgrades.", player->GetPlayerName());
        else
            handler->PSendSysMessage("{} has a total of: {} upgraded item(s), {} upgraded stat(s), {} upgraded weapon(s).", player->GetPlayerName(), upgradedItems, upgradedStats, weaponUpgrades);

        return true;
    }

    static bool HandleValidateCommand(ChatHandler* handler, char const* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        uint32 itemId = static_cast<uint32_t>(std::stoul(args));

        Item* item = FindItemInInventory(player, itemId);
        if (!item)
        {
            SendToAddon(player, "VALIDATE FALSE", handler);
            return true;
        }

        bool canUpgrade = sItemUpgrade->IsValidItemForUpgrade(item, player);

        std::string returnMsg = "VALIDATE ";
        returnMsg.append(canUpgrade ? "true " : "false ");
        returnMsg.append(std::to_string(itemId));

        SendToAddon(player, returnMsg, handler);
        return true;
    }

    static bool HandleGetStatsCommand(ChatHandler* handler, char const* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Parser l'ID de l'objet depuis les arguments
        uint32 itemId = static_cast<uint32_t>(std::stoul(args));

        // Trouver l'objet dans l'inventaire
        Item* item = nullptr;

        // Chercher dans l'équipement
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* pItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (pItem && pItem->GetEntry() == itemId)
            {
                item = pItem;
                break;
            }
        }

        // Chercher dans les sacs si pas trouvé
        if (!item)
        {
            for (uint8 i = INVENTORY_SLOT_ITEM_START; i < INVENTORY_SLOT_ITEM_END; ++i)
            {
                Item* pItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i);
                if (pItem && pItem->GetEntry() == itemId)
                {
                    item = pItem;
                    break;
                }
            }
        }

        // Chercher dans les sacs
        if (!item)
        {
            for (uint8 i = INVENTORY_SLOT_BAG_START; i < INVENTORY_SLOT_BAG_END; ++i)
            {
                if (Bag* bag = player->GetBagByPos(i))
                {
                    for (uint32 j = 0; j < bag->GetBagSize(); ++j)
                    {
                        Item* pItem = player->GetItemByPos(i, j);
                        if (pItem && pItem->GetEntry() == itemId)
                        {
                            item = pItem;
                            break;
                        }
                    }
                }
                if (item)
                    break;
            }
        }

        // Récupérer les stats
        std::vector<_ItemStat> stats = ItemUpgrade::LoadItemStatInfo(item);
        std::stringstream response;
        response << "STATS ";

        bool first = true;
        for (const auto& stat : stats)
        {
            if (!sItemUpgrade->IsAllowedStatType(stat.ItemStatType))
                continue;

            const ItemUpgrade::UpgradeStat* currentUpgrade =
                sItemUpgrade->FindUpgradeForItem(player, item, stat.ItemStatType);

            uint16 currentRank = currentUpgrade ? currentUpgrade->statRank : 0;
            uint16 nextRank = currentRank + 1;

            const ItemUpgrade::UpgradeStat* nextUpgrade =
                sItemUpgrade->FindUpgradeStat(stat.ItemStatType, nextRank);

            if (!nextUpgrade)
                continue;

            int32 upgradedValue = ItemUpgrade::CalculateModPct(
                stat.ItemStatValue, nextUpgrade);

            if (!first)
                response << ",";

            // Format: type,current,upgraded,currentRank,nextRank
            response << stat.ItemStatType << ","
                << stat.ItemStatValue << ","
                << upgradedValue << ","
                << currentRank << ","
                << nextRank;

            first = false;
        }

        SendToAddon(player, response.str().c_str(), handler);
        return true;
    }

    static bool HandleGetCostCommand(ChatHandler* handler, char const* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        std::string argsStr(args);
        std::istringstream iss(argsStr);

        // Extraire l'ID de l'objet
        uint32 itemId;

        if (!(iss >> itemId))
        {
            return true;
        }

        // Extraire la chaîne des stats (le reste après l'espace)
        std::string statsString;
        std::getline(iss, statsString);

        // Enlever l'espace initial s'il existe
        if (!statsString.empty() && statsString[0] == ' ')
            statsString = statsString.substr(1);

        // Trouver l'objet dans l'inventaire
        Item* item = nullptr;

        // Parcourir l'équipement
        for (uint8 i = EQUIPMENT_SLOT_START; i < EQUIPMENT_SLOT_END; ++i)
        {
            Item* pItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i);
            if (pItem && pItem->GetEntry() == itemId)
            {
                item = pItem;
                break;
            }
        }

        // Parcourir les sacs si pas trouvé
        if (!item)
        {
            for (uint8 i = INVENTORY_SLOT_BAG_START; i < INVENTORY_SLOT_BAG_END; ++i)
            {
                Bag* pBag = player->GetBagByPos(i);
                if (pBag)
                {
                    for (uint32 j = 0; j < pBag->GetBagSize(); ++j)
                    {
                        Item* pItem = pBag->GetItemByPos(j);
                        if (pItem && pItem->GetEntry() == itemId)
                        {
                            item = pItem;
                            break;
                        }
                    }
                }
                if (item) break;
            }
        }

        // Parcourir l'inventaire principal
        if (!item)
        {
            for (uint8 i = INVENTORY_SLOT_ITEM_START; i < INVENTORY_SLOT_ITEM_END; ++i)
            {
                Item* pItem = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i);
                if (pItem && pItem->GetEntry() == itemId)
                {
                    item = pItem;
                    break;
                }
            }
        }

        if (!item)
        {
            return true;
        }

        // Parser les types de stats
        std::vector<uint32> statTypes;
        if (!statsString.empty())
        {
            std::stringstream ss(statsString);
            std::string statStr;

            while (std::getline(ss, statStr, ','))
            {
                // Enlever les espaces
                statStr.erase(std::remove_if(statStr.begin(), statStr.end(), ::isspace), statStr.end());

                uint32 statType = atoi(statStr.c_str());
                if (statType > 0)
                {
                    statTypes.push_back(statType);
                }
            }
        }

        // Si aucune stat n'est sélectionnée, retourner coût 0
        if (statTypes.empty())
        {
            return true;
        }

        // Calculer le coût total
        int32 totalCopper = 0;
        int32 totalHonor = 0;
        int32 totalArena = 0;
        std::map<uint32, uint32> itemsNeeded;

        // Pour chaque stat sélectionnée
        for (uint32 statType : statTypes)
        {
            // Trouver l'amélioration actuelle pour cette stat
            const ItemUpgrade::UpgradeStat* currentUpgrade =
                sItemUpgrade->FindUpgradeForItem(player, item, statType);

            // Déterminer le rang suivant
            uint16 nextRank = currentUpgrade ? currentUpgrade->statRank + 1 : 1;

            // Trouver l'amélioration suivante
            const ItemUpgrade::UpgradeStat* nextUpgrade =
                sItemUpgrade->FindUpgradeStat(statType, nextRank);

            if (nextUpgrade)
            {
                // Obtenir les prérequis pour cette amélioration
                const ItemUpgrade::StatRequirementContainer* reqs =
                    sItemUpgrade->GetStatRequirements(nextUpgrade, item);

                if (reqs)
                {
                    for (const auto& req : *reqs)
                    {
                        switch (req.reqType)
                        {
                        case ItemUpgrade::REQ_TYPE_COPPER:
                            totalCopper += static_cast<int32>(req.reqVal1);
                            break;
                        case ItemUpgrade::REQ_TYPE_HONOR:
                            totalHonor += static_cast<int32>(req.reqVal1);
                            break;
                        case ItemUpgrade::REQ_TYPE_ARENA:
                            totalArena += static_cast<int32>(req.reqVal1);
                            break;
                        case ItemUpgrade::REQ_TYPE_ITEM:
                        {
                            uint32 reqItemId = static_cast<uint32>(req.reqVal1);
                            uint32 reqCount = static_cast<uint32>(req.reqVal2);
                            itemsNeeded[reqItemId] += reqCount;
                        }
                        break;
                        }
                    }
                }
            }
        }

        // Construire la réponse
        // Format: APICOST:copper,honor,arena;itemId1,count1;itemId2,count2...
        std::stringstream response;
        response << "COST " << totalCopper << "," << totalHonor << "," << totalArena;

        // Ajouter les objets requis
        for (const auto& itemPair : itemsNeeded)
        {
            response << ";" << itemPair.first << "," << itemPair.second;
        }

        SendToAddon(player, response.str().c_str(), handler);
        return true;
    }

    static bool HandleDoUpgradeCommand(ChatHandler* handler, char const* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        std::stringstream ss(args);
        std::string command;
        uint32 itemId, statId;
        ss >> itemId >> statId;

        Item* item = FindItemInInventory(player, itemId);
        if (!item)
        {
            return true;
        }

        if (!sItemUpgrade->IsValidItemForUpgrade(item, player))
        {
            return true;
        }

        bool wasEquipped = item->IsEquipped();
        uint8 slot = item->GetSlot();

        if (wasEquipped)
            player->_ApplyItemMods(item, slot, false);

        bool success = true;
        std::string error;


        const ItemUpgrade::UpgradeStat* currentUpgrade =
            sItemUpgrade->FindUpgradeForItem(player, item, statId);

        uint16 nextRank = currentUpgrade ? currentUpgrade->statRank + 1 : 1;
        const ItemUpgrade::UpgradeStat* nextUpgrade =
            sItemUpgrade->FindUpgradeStat(statId, nextRank);

        if (!nextUpgrade)
        {
            success = false;
            error = "No upgrade available";
            return true;
        }

        if (!sItemUpgrade->MeetsRequirement(player, nextUpgrade, item))
        {
            success = false;
            error = "Requirements not met";
            return true;
        }

        sItemUpgrade->HandlePurchaseRank(player, item, nextUpgrade);
        sItemUpgrade->TakeRequirements(player, nextUpgrade, item);
        

        if (wasEquipped)
            player->_ApplyItemMods(item, slot, true);

        if (success)
        {
            sItemUpgrade->SendItemPacket(player, item);
            sItemUpgrade->VisualFeedback(player);

            std::stringstream response;
            response << "UPGRADE SUCCESS";
            SendToAddon(player, response.str().c_str(), handler);

        }

        return true;
    }

    static Item* FindItemInInventory(Player* player, uint32 itemId)
    {
        // Équipement
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (item && item->GetEntry() == itemId)
                return item;
        }

        // Inventaire principal
        for (uint8 i = INVENTORY_SLOT_ITEM_START; i < INVENTORY_SLOT_ITEM_END; ++i)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i);
            if (item && item->GetEntry() == itemId)
                return item;
        }

        // Sacs
        for (uint8 i = INVENTORY_SLOT_BAG_START; i < INVENTORY_SLOT_BAG_END; ++i)
        {
            if (Bag* bag = player->GetBagByPos(i))
            {
                for (uint32 j = 0; j < bag->GetBagSize(); ++j)
                {
                    Item* item = player->GetItemByPos(i, j);
                    if (item && item->GetEntry() == itemId)
                        return item;
                }
            }
        }

        return nullptr;
    }

    static void SendToAddon(Player* player, const std::string& message, ChatHandler* handler)
    {
        if (!player || !player->GetSession())
        {
            return;
        }

        std::string prefix = "ITEMUPGRADE_RESP";

        std::string fullmsg = prefix + "\t" + message;

        WorldPacket packet(SMSG_MESSAGECHAT, 100);
        packet << uint8(CHAT_MSG_WHISPER);        // ChatType
        packet << int32(LANG_ADDON);             // Language
        packet << player->GetGUID();             // Sender GUID
        packet << uint32(0);                     // Constant time
        packet << player->GetGUID();           // Receiver GUID
        packet << uint32(fullmsg.length() + 1);  // Text length including null
        packet << fullmsg;                        // Text bytes
        packet << uint8(0);                       // Chat Tag

        player->GetSession()->SendPacket(&packet);
        return;
    }
};

std::unordered_map<uint32, uint32> item_upgrade_commandscript::cmdListUpgradesTimerMap;

void AddSC_item_upgrade_commandscript()
{
    new item_upgrade_commandscript();
}
