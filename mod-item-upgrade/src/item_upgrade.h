/*
 * Credits: silviu20092
 */

#ifndef _ITEM_UPGRADE_H_
#define _ITEM_UPGRADE_H_

#include <vector>
#include "Player.h"
#include "item_upgrade_config.h"
#include "StringFormat.h"
#include "WorldSession.h"

#define ITEM_UPGRADE_MODULE "mod-item-upgrade"

// Ids of the rows of `module_string` the C++ reads (module "mod-item-upgrade").
enum ItemUpgradeTexts
{
    IU_TEXT_DISABLED        = 1,
    IU_TEXT_LOCKED          = 2,
    IU_TEXT_WINDOW_ONLY     = 3,
    IU_TEXT_ITEM_GONE       = 4,
    IU_TEXT_NOT_UPGRADABLE  = 5,
    IU_TEXT_NOTHING_CHOSEN  = 6,
    IU_TEXT_UNAVAILABLE     = 7,
    IU_TEXT_REQUIREMENTS    = 8,
    IU_TEXT_SUCCESS         = 9,
    IU_TEXT_LOOT            = 10,
    IU_TEXT_LOGIN           = 11,
    IU_TEXT_RELOADED        = 12,
    IU_TEXT_LOCK_SET        = 13,
    IU_TEXT_LIST_WAIT       = 14,
    IU_TEXT_LIST_STATS      = 15,
    IU_TEXT_LIST_STAT       = 16,
    IU_TEXT_ACTIVE          = 17,
    IU_TEXT_INACTIVE        = 18,
    IU_TEXT_LIST_DAMAGE     = 19,
    IU_TEXT_LIST_SPEED      = 20,
    IU_TEXT_LIST_SEPARATOR  = 21,
    IU_TEXT_LIST_NONE       = 22,
    IU_TEXT_LIST_TOTAL      = 23,
    // 101-199: the upgrade window (read by the addon, not by the C++)
    IU_TEXT_STAT            = 1000, // + stat type (ItemModType)
    IU_TEXT_SLOT            = 1100  // + equipment slot (EquipmentSlots)
};

class ItemUpgrade
{
private:
    ItemUpgrade();
    ~ItemUpgrade();
public:
    enum ItemVisualsPriority
    {
        PRIORITIZE_STATS,
        PRIORITIZE_WEAPON_DAMAGE
    };

    enum UpgradeStatReqType
    {
        REQ_TYPE_COPPER = 1,
        REQ_TYPE_HONOR,
        REQ_TYPE_ARENA,
        REQ_TYPE_ITEM,
        REQ_TYPE_NONE,
        MAX_REQ_TYPE
    };

    struct UpgradeStatReq
    {
        /* Associated stat ID from UpgradeStat */
        uint32 statId;

        /*
            Possible values:
                1 = this rank requires money (copper, gold) to be bought
                2 = this rank requires honor points to be bought
                3 = this rank requires arena points to be bought
                4 = this rank requires certain item(s) to be bought
         */
        UpgradeStatReqType reqType;

        /*
         *   If reqType = 1 THEN required copper to purchase rank
         *   If reqType = 2 THEN required honor points to purchase rank
         *   If reqType = 3 THEN required arena points to purchase rank
         *   If reqType = 4 THEN item ENTRY (from item_template.entry) required to purchase rank
         */
        float reqVal1;

        /*
         *  If reqType = 4 THEN item count required to purchase rank
         *  NOT USED otherwise
         */ 
        float reqVal2;

        UpgradeStatReq()
        {
            statId = 0;
            reqType = MAX_REQ_TYPE;
            reqVal1 = 0.0f;
            reqVal2 = 0.0f;
        }

        UpgradeStatReq(uint32 statId, UpgradeStatReqType reqType, float reqVal1, float reqVal2)
            : statId(statId), reqType(reqType), reqVal1(reqVal1), reqVal2(reqVal2) {}

        UpgradeStatReq(uint32 statId, UpgradeStatReqType reqType, float reqVal1)
            : statId(statId), reqType(reqType), reqVal1(reqVal1), reqVal2(0.0f) {}

        UpgradeStatReq(uint32 statId, UpgradeStatReqType reqType)
            : statId(statId), reqType(reqType), reqVal1(0.0f), reqVal2(0.0f) {}
    };
    typedef std::vector<UpgradeStatReq> StatRequirementContainer;

    struct UpgradeStat
    {
        uint32 statId;
        uint32 statType;
        float statModPct;
        uint16 statRank;
    };
    typedef std::vector<UpgradeStat> UpgradeStatContainer;

    struct CharacterUpgrade
    {
        uint32 guid;
        ObjectGuid itemGuid;
        const UpgradeStat* upgradeStat;
        float upgradeStatModPct;
    };
    typedef std::unordered_map<uint32, std::vector<CharacterUpgrade>> CharacterUpgradeContainer;

    struct ItemUpgradeInfo
    {
        ObjectGuid itemGuid;
        std::vector<const UpgradeStat*> upgrades;
        const UpgradeStat* weaponUpgrade;
        const UpgradeStat* weaponSpeedUpgrade;
    };

    typedef std::set<uint32> ItemEntryContainer;
    typedef std::unordered_map<uint32, std::set<uint32>> StatWithItemContainer;
public:
    static ItemUpgrade* instance();

    template <class Container, typename T>
    static T* FindInContainer(const Container& c, const T& val)
    {
        typename Container::const_iterator citr = std::find_if(c.begin(), c.end(), [&](const T& value) { return value == val; });
        return citr != c.end() ? (T*)(&*citr) : nullptr;
    }

    bool GetBoolConfig(ItemUpgradeBoolConfigs index) const;
    std::string GetStringConfig(ItemUpgradeStringConfigs index) const;
    float GetFloatConfig(ItemUpgradeFloatConfigs index) const;
    int32 GetIntConfig(ItemUpgradeIntConfigs index) const;

    void LoadConfig(bool reload);
    void LoadFromDB(bool reload = false);

    bool CanApplyUpgradeForItem(const Item* item, const UpgradeStat* upgrade) const;
    const StatRequirementContainer* GetStatRequirements(const UpgradeStat* upgrade, const Item* item) const;
    bool MeetsRequirement(const Player* player, const UpgradeStat* upgradeStat, const Item* item) const;
    void TakeRequirements(Player* player, const UpgradeStat* upgradeStat, const Item* item);
    bool HandlePurchaseRank(Player* player, Item* item, const UpgradeStat* upgrade);
    void SendItemPacket(Player* player, Item* item) const;
    const UpgradeStat* FindUpgradeStat(uint32 statId) const;
    const UpgradeStat* FindUpgradeStat(uint32 statType, uint16 rank) const;
    const UpgradeStat* FindUpgradeForItem(const Player* player, const Item* item, uint32 statType) const;



    bool IsValidItemForUpgrade(const Item* item, const Player* player) const;
    bool IsValidWeaponForUpgrade(const Item* item, const Player* player) const;
    bool IsValidWeaponForSpeedUpgrade(const Item* item, const Player* player) const;

    int32 HandleStatModifier(const Player* player, uint8 slot, uint32 statType, int32 amount) const;
    int32 HandleStatModifier(const Player* player, Item* item, uint32 statType, int32 amount, EnchantmentSlot slot) const;
    std::pair<float, float> HandleWeaponModifier(const Player* player, uint8 slot, float minDamage, float maxDamage) const;
    std::pair<float, float> HandleWeaponModifier(const Player* player, const Item* item, float minDamage, float maxDamag) const;
    uint32 HandleWeaponSpeedModifier(const Player* player, const Item* item) const;
    void HandleItemRemove(Player* player, Item* item);
    void HandleCharacterRemove(uint32 guid);

    void SetReloading(bool value);
    bool GetReloading() const;

    void HandleDataReload(bool apply);

    void UpdateVisualCache(Player* player);
    void VisualFeedback(Player* player);

    bool ChooseRandomUpgrade(Player* player, Item* item);

    void BuildWeaponUpgradeReqs();
    void BuildWeaponSpeedUpgradeReqs();

    static std::vector<_ItemStat> LoadItemStatInfo(const Item* item);
    static const _ItemStat* GetStatByType(const std::vector<_ItemStat>& statInfo, uint32 statType);
    static std::pair<float, float> GetItemProtoDamage(const ItemTemplate* proto);
    static std::pair<float, float> GetItemProtoDamage(const Item* item);
    static uint32 GetItemProtoDelay(const ItemTemplate* proto);
    static uint32 GetItemProtoDelay(const Item* item);

    static std::string FormatFloat(float val, uint32 decimals = 2);
    static std::string FormatIncrease(float prev, float next);
    static std::string FormatDelay(uint32 val);

    static int32 CalculateModPct(int32 value, const UpgradeStat* upgradeStat);
    static float CalculateModPctF(float value, const UpgradeStat* upgradeStat);
    static uint32 CalculatePctDecrease(uint32 value, float pct);

    std::vector<const UpgradeStat*> FindUpgradesForItem(const Player* player, const Item* item) const;
    const UpgradeStat* FindUpgradeForWeapon(const CharacterUpgradeContainer& characterUpgradeContainer, const Player* player, const Item* item) const;
    const UpgradeStat* FindUpgradeForWeaponDamage(const Player* player, const Item* item) const;
    const UpgradeStat* FindUpgradeForWeaponSpeed(const Player* player, const Item* item) const;

    bool IsInactiveStatUpgrade(const Item* item, const UpgradeStat* upgradeStat) const;
    bool IsInactiveWeaponUpgrade() const;
    bool IsInactiveWeaponSpeedUpgrade() const;

    void RefreshWeaponSpeed(Player* player);
public:
    static std::string ItemNameWithLocale(const Player* player, const ItemTemplate* itemTemplate, int32 randomPropertyId);
    static std::string ItemLink(const Player* player, const ItemTemplate* itemTemplate, int32 randomPropertyId);
    static std::string ItemLink(const Player* player, const Item* item);
    static void SendMessage(const Player* player, const std::string& message);

    static constexpr int VISUAL_FEEDBACK_SPELL_ID = 46331;

    ItemUpgradeConfig cfg;

    bool reloading;
    std::vector<uint32> allowedStats;
    UpgradeStatContainer upgradeStatList;
    CharacterUpgradeContainer characterUpgradeData;
    ItemEntryContainer allowedItems;
    ItemEntryContainer blacklistedItems;
    StatWithItemContainer allowedStatItems;
    StatWithItemContainer blacklistedStatItems;

    std::map<float, std::vector<const ItemUpgrade::UpgradeStat*>> upgradesPctMap;

    std::unordered_map<uint32, StatRequirementContainer> baseStatRequirements;
    std::unordered_map<uint32, std::unordered_map<uint32, StatRequirementContainer>> overrideStatRequirements;

    UpgradeStatContainer weaponUpgradeStats;
    CharacterUpgradeContainer characterWeaponUpgradeData;
    StatRequirementContainer weaponUpgradeReqs;

    UpgradeStatContainer weaponSpeedUpgradeStats;
    CharacterUpgradeContainer characterWeaponSpeedUpgradeData;
    StatRequirementContainer weaponSpeedUpgradeReqs;


    void CleanupDB(bool reload);
    void LoadStatRequirements();
    void LoadStatRequirementsOverrides();
    void LoadUpgradeStats();
    void LoadCharacterUpgradeData();
    void LoadCharacterWeaponUpgradeData();
    void LoadCharacterWeaponSpeedUpgradeData();
    void LoadAllowedItems();
    void LoadAllowedStatsItems();
    void LoadBlacklistedItems();
    void LoadBlacklistedStatsItems();
    bool IsValidReqType(uint8 reqType) const;
    bool ValidateReq(uint32 id, UpgradeStatReqType reqType, float val1, float val2, const std::string& table) const;
    void MergeStatRequirements(std::unordered_map<uint32, StatRequirementContainer>& statRequirementMap, bool validate = true);

    template <typename Func>
    const UpgradeStat* _FindUpgradeStat(const UpgradeStatContainer& upgradeStatContainer, Func f) const
    {
        UpgradeStatContainer::const_iterator citer = std::find_if(upgradeStatContainer.begin(), upgradeStatContainer.end(), f);
        if (citer != upgradeStatContainer.end())
            return &*citer;
        return nullptr;
    }


    const UpgradeStat* FindWeaponUpgradeStat(const UpgradeStatContainer& upgradeStatContainer, float pct) const;
    const UpgradeStat* FindNearestWeaponUpgradeStat(const UpgradeStatContainer& upgradeStatContainer, float pct) const;
    const UpgradeStat* FindNextWeaponUpgradeStat(const UpgradeStatContainer& upgradeStatContainer, float pct) const;
    std::vector<const UpgradeStat*> _FindUpgradesForItem(const CharacterUpgradeContainer& characterUpgradeDataContainer, const Player* player, const Item* item) const;
    bool MeetsRequirement(const Player* player, const UpgradeStatReq& req) const;
    bool MeetsRequirement(const Player* player, const StatRequirementContainer* reqs) const;
    void TakeRequirements(Player* player, const StatRequirementContainer* reqs);
    void TakeWeaponUpgradeRequirements(Player* player);
    void TakeWeaponSpeedUpgradeRequirements(Player* player);
    void HandleDataReload(Player* player, bool apply);
    std::vector<Item*> GetPlayerItems(const Player* player, bool inBankAlso) const;
    bool IsAllowedItem(const Item* item) const;
    bool IsBlacklistedItem(const Item* item) const;
    std::pair<uint32, uint32> CalculateItemLevel(const Player* player, Item* item, const UpgradeStat* upgrade = nullptr) const;
    std::pair<uint32, uint32> CalculateItemLevel(const Player* player, Item* item, std::unordered_map<uint32, const UpgradeStat*>) const;
    void RemoveItemUpgradeFromContainer(CharacterUpgradeContainer& upgradesContainer, Player* player, Item* item);
    void RemoveItemUpgrade(Player* player, Item* item);
    void RemoveWeaponUpgrade(Player* player, Item* item);
    void RemoveWeaponSpeedUpgrade(Player* player, Item* item);
    bool AddUpgradeForNewItem(Player* player, Item* item, const UpgradeStat* upgrade, const _ItemStat* stat);
    void AddItemUpgradeToDB(const Player* player, const Item* item, const UpgradeStat* upgrade) const;
    const UpgradeStat* FindNearestUpgradeStat(uint32 statType, uint16 rank, const Item* item) const;
    bool IsAllowedStatForItem(const Item* item, const UpgradeStat* upgrade) const;
    bool IsBlacklistedStatForItem(const Item* item, const UpgradeStat* upgrade) const;
    void CreateUpgradesPctMap();
    // What several upgrades bought together cost: amounts added up, items
    // grouped by entry, in exact integers (a single rank's columns are floats).
    struct TotalCost
    {
        uint64 copper = 0;
        uint64 honor = 0;
        uint64 arena = 0;
        std::map<uint32, uint64> items;
        bool invalid = false;
    };
    TotalCost SumRequirements(const std::vector<const StatRequirementContainer*>& parts) const;
    bool MeetsCost(const Player* player, const TotalCost& cost) const;
    void TakeCost(Player* player, const TotalCost& cost);
    bool HandlePurchaseWeaponUpgrade(Player* player, Item* item, const UpgradeStat* upgrade, bool speedUpgrade);
    bool CheckDataValidity() const;
    bool IsValidStatType(uint32 statType) const;
    bool EmptyRequirements(const StatRequirementContainer* reqs) const;
    bool IsAllowedStatType(uint32 statType) const;
    void LoadAllowedStats(const std::string& stats);

    // maxPct: the value a percentage must stay below, 0 for no limit.
    void LoadWeaponUpgradePercents(UpgradeStatContainer& upgradeStats, CharacterUpgradeContainer& characterUpgradeContainer, const std::string& percents,
        const char* option, float maxPct);
    bool MeetsWeaponUpgradeRequirement(const Player* player) const;
    bool MeetsWeaponSpeedUpgradeRequirement(const Player* player) const;


    ItemVisualsPriority GetItemVisualsPriority() const;


    void RefreshWeaponSpeed(Player* player, EquipmentSlots slot);

    // --- Texts ---------------------------------------------------------------
    // Every text the module shows lives in `module_string` (English) and
    // `module_string_locale` (every other language), module "mod-item-upgrade":
    // data/sql/db-world/base/02_item_upgrade_strings.sql. Each player gets the
    // row of their client's language. Numbers: 1-99 messages, 101-199 the
    // interface, 1000 + stat type the statistics, 1100 + slot the equipment.
    static std::string Text(const WorldSession* session, uint32 id);
    template <typename... Args>
    static std::string Format(const WorldSession* session, uint32 id, Args&&... args)
    {
        return Acore::StringFormat(Text(session, id), std::forward<Args>(args)...);
    }
    template <typename... Args>
    static void Notify(const Player* player, uint32 id, Args&&... args)
    {
        SendMessage(player, Format(player->GetSession(), id, std::forward<Args>(args)...));
    }
    static std::string StatName(const WorldSession* session, uint32 statType);
    static std::string SlotName(const WorldSession* session, uint8 slot);

    // --- Operations of the upgrade window (item_upgrade_addon.cpp) -----------
    // The window names an item by where it sits: containers 0-4 as the client
    // counts its bags, ADDON_EQUIPMENT for the equipment (slots 1-19 as the
    // client counts them). Nothing the window sends is trusted beyond that.
    static constexpr uint8 ADDON_EQUIPMENT = 100;
    static Item* FindItemForAddon(Player* player, uint8 container, uint8 slot);
    // Lines describing the item, one per statistic and per weapon upgrade.
    std::vector<std::string> DescribeItemForAddon(Player* player, Item* item) const;
    // Buys the next rank of every target at once, for the sum of their costs:
    // all of them or none. Returns the id of the text to show the player.
    uint32 UpgradeForAddon(Player* player, Item* item, const std::vector<uint32>& statTypes, bool damage, bool speed);
    uint16 MaxRankForStat(uint32 statType) const;
};

#define sItemUpgrade ItemUpgrade::instance()

#endif
