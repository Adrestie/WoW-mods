/*
 * Credits: silviu20092
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Tokenize.h"
#include "StringConvert.h"
#include "WorldSessionMgr.h"
#include "item_upgrade.h"

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
            { "reload",  HandleReloadModItemUpgrade, SEC_ADMINISTRATOR, Console::Yes },
            { "lock",    HandleLockItemUpgrade,      SEC_ADMINISTRATOR, Console::Yes },
            { "list",    HandleListUpgrades,         SEC_PLAYER,        Console::Yes },
            // Used by the upgrade window through the addon command channel.
            { "state",   HandleStateCommand,         SEC_PLAYER,        Console::No  },
            { "upgrade", HandleUpgradeCommand,       SEC_PLAYER,        Console::No  }
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
        sItemUpgrade->SetReloading(true);
        sItemUpgrade->HandleDataReload(false);

        sItemUpgrade->LoadFromDB(true);

        sItemUpgrade->HandleDataReload(true);
        sItemUpgrade->SetReloading(false);

        // Every game master in the world is told, each in their client's language.
        for (auto const& [accountId, session] : sWorldSessionMgr->GetAllSessions())
        {
            if (session && session->GetPlayer() && session->GetPlayer()->IsInWorld()
                && session->HasPermission(rbac::RBAC_PERM_RECEIVE_GLOBAL_GM_TEXTMESSAGE))
                ChatHandler(session).SendSysMessage(ItemUpgrade::Text(session, IU_TEXT_RELOADED));
        }

        if (handler->IsConsole())
            handler->SendSysMessage(ItemUpgrade::Text(nullptr, IU_TEXT_RELOADED));

        return true;
    }

    static bool HandleLockItemUpgrade(ChatHandler* handler)
    {
        sItemUpgrade->SetReloading(true);
        handler->SendSysMessage(ItemUpgrade::Text(handler->GetSession(), IU_TEXT_LOCK_SET));
        return true;
    }

    static std::string Status(WorldSession* session, bool inactive)
    {
        return inactive ? "|cffb50505" + ItemUpgrade::Text(session, IU_TEXT_INACTIVE) + "|r"
                        : "|cff056e3a" + ItemUpgrade::Text(session, IU_TEXT_ACTIVE) + "|r";
    }

    static bool HandleListUpgrades(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        if (!target)
            target = PlayerIdentifier::FromTargetOrSelf(handler);

        if (!target)
            return false;

        Player* player = target->GetConnectedPlayer();
        if (!player)
        {
            handler->SendErrorMessage(LANG_PLAYER_NOT_FOUND);
            return false;
        }

        WorldSession* session = handler->GetSession();

        uint32 currentTime = getMSTime();
        uint32 lastTime = cmdListUpgradesTimerMap[player->GetGUID().GetCounter()];
        uint32 diff = getMSTimeDiff(lastTime, currentTime);
        if (lastTime > 0 && diff < listUpgradesDiffTimer)
        {
            handler->SendSysMessage(ItemUpgrade::Format(session, IU_TEXT_LIST_WAIT, (listUpgradesDiffTimer - diff) / 1000));
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
                    handler->PSendSysMessage("{} [{}]", ItemUpgrade::ItemLink(player, item), ItemUpgrade::SlotName(session, i));
                    if (!upgrades.empty())
                    {
                        upgradedStats += upgrades.size();
                        std::vector<_ItemStat> statInfo = ItemUpgrade::LoadItemStatInfo(item);
                        handler->SendSysMessage(ItemUpgrade::Format(session, IU_TEXT_LIST_STATS, upgrades.size()));
                        for (const auto* stat : upgrades)
                        {
                            const _ItemStat* foundStat = ItemUpgrade::GetStatByType(statInfo, stat->statType);
                            if (!foundStat)
                                continue;

                            std::ostringstream oss;
                            oss << "|cffb50505" << foundStat->ItemStatValue << "|r --> ";
                            oss << "|cff056e3a" << ItemUpgrade::CalculateModPct(foundStat->ItemStatValue, stat) << "|r";
                            handler->SendSysMessage(ItemUpgrade::Format(session, IU_TEXT_LIST_STAT, ItemUpgrade::StatName(session, stat->statType),
                                ItemUpgrade::FormatFloat(stat->statModPct), stat->statRank, oss.str(),
                                Status(session, sItemUpgrade->IsInactiveStatUpgrade(item, stat))));
                        }
                    }
                    if (weaponUpgrade != nullptr)
                    {
                        weaponUpgrades++;
                        std::pair<float, float> dmgInfo = ItemUpgrade::GetItemProtoDamage(item);
                        float upgradedMinDamage = std::floor(ItemUpgrade::CalculateModPctF(dmgInfo.first, weaponUpgrade));
                        float upgradedMaxDamage = std::ceil(ItemUpgrade::CalculateModPctF(dmgInfo.second, weaponUpgrade));

                        handler->SendSysMessage(ItemUpgrade::Format(session, IU_TEXT_LIST_DAMAGE,
                            ItemUpgrade::FormatFloat(weaponUpgrade->statModPct),
                            ItemUpgrade::FormatIncrease(dmgInfo.first, upgradedMinDamage),
                            ItemUpgrade::FormatIncrease(dmgInfo.second, upgradedMaxDamage),
                            Status(session, sItemUpgrade->IsInactiveWeaponUpgrade())));
                    }
                    if (weaponSpeedUpgrade != nullptr)
                    {
                        if (weaponUpgrade == nullptr)
                            weaponUpgrades++;

                        uint32 originalDelay = ItemUpgrade::GetItemProtoDelay(item);
                        uint32 newDelay = sItemUpgrade->HandleWeaponSpeedModifier(player, item);

                        handler->SendSysMessage(ItemUpgrade::Format(session, IU_TEXT_LIST_SPEED,
                            ItemUpgrade::FormatFloat(weaponSpeedUpgrade->statModPct),
                            ItemUpgrade::FormatDelay(originalDelay),
                            ItemUpgrade::FormatDelay(newDelay),
                            Status(session, sItemUpgrade->IsInactiveWeaponSpeedUpgrade())));
                    }
                    handler->SendSysMessage(ItemUpgrade::Text(session, IU_TEXT_LIST_SEPARATOR));
                }
            }
        }

        if (upgradedItems == 0 && weaponUpgrades == 0)
            handler->SendSysMessage(ItemUpgrade::Format(session, IU_TEXT_LIST_NONE, player->GetPlayerName()));
        else
            handler->SendSysMessage(ItemUpgrade::Format(session, IU_TEXT_LIST_TOTAL, player->GetPlayerName(), upgradedItems, upgradedStats, weaponUpgrades));

        return true;
    }

    // --- Upgrade window --------------------------------------------------------
    // The window sends these through the addon command channel; each reply line
    // reaches it as one addon message (item_upgrade_addon.cpp lists them).
    // A refusal is "#ERR <text id>" and the command reports a failure.

    static bool Refuse(ChatHandler* handler, uint32 textId)
    {
        handler->SendSysMessage(Acore::StringFormat("#ERR {}", textId));
        handler->SetSentErrorMessage(true);
        return true;
    }

    // Typed in the chat instead of sent by the window: explain, do nothing.
    // Otherwise the module must be on and not locked.
    static bool CheckWindowCall(ChatHandler* handler)
    {
        if (handler->IsHumanReadable())
        {
            handler->SendSysMessage(ItemUpgrade::Text(handler->GetSession(), IU_TEXT_WINDOW_ONLY));
            return false;
        }

        if (!sItemUpgrade->GetBoolConfig(CONFIG_ITEM_UPGRADE_ENABLED))
            return !Refuse(handler, IU_TEXT_DISABLED);

        if (sItemUpgrade->GetReloading())
            return !Refuse(handler, IU_TEXT_LOCKED);

        return true;
    }

    static void SendLines(ChatHandler* handler, const std::vector<std::string>& lines)
    {
        for (const std::string& line : lines)
            handler->SendSysMessage(line);
    }

    static bool HandleStateCommand(ChatHandler* handler, uint8 container, uint8 slot)
    {
        if (!CheckWindowCall(handler))
            return true;

        Player* player = handler->GetSession()->GetPlayer();
        Item* item = ItemUpgrade::FindItemForAddon(player, container, slot);
        if (!item)
            return Refuse(handler, IU_TEXT_ITEM_GONE);

        SendLines(handler, sItemUpgrade->DescribeItemForAddon(player, item));
        return true;
    }

    // targets: stat types and/or "dmg" / "spd", separated by commas ("7,32,dmg").
    static bool HandleUpgradeCommand(ChatHandler* handler, uint8 container, uint8 slot, uint32 itemGuid, std::string_view targets)
    {
        if (!CheckWindowCall(handler))
            return true;

        Player* player = handler->GetSession()->GetPlayer();
        Item* item = ItemUpgrade::FindItemForAddon(player, container, slot);
        // The item must still be the one the window showed.
        if (!item || item->GetGUID().GetCounter() != itemGuid)
            return Refuse(handler, IU_TEXT_ITEM_GONE);

        std::set<uint32> statTypes;
        bool damage = false;
        bool speed = false;
        for (std::string_view target : Acore::Tokenize(targets, ',', false))
        {
            if (target == "dmg")
                damage = true;
            else if (target == "spd")
                speed = true;
            else if (Optional<uint32> statType = Acore::StringTo<uint32>(target))
                statTypes.insert(*statType);
            else
                return Refuse(handler, IU_TEXT_UNAVAILABLE);
        }

        uint32 result = sItemUpgrade->UpgradeForAddon(player, item, std::vector<uint32>(statTypes.begin(), statTypes.end()), damage, speed);
        if (result != IU_TEXT_SUCCESS)
            return Refuse(handler, result);

        // Success, then the item as it is now, so the window can refresh at once.
        handler->SendSysMessage(Acore::StringFormat("#OK {}", result));
        SendLines(handler, sItemUpgrade->DescribeItemForAddon(player, item));
        return true;
    }
};

std::unordered_map<uint32, uint32> item_upgrade_commandscript::cmdListUpgradesTimerMap;

void AddSC_item_upgrade_commandscript()
{
    new item_upgrade_commandscript();
}
