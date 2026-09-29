#ifndef MODULE_ATTRIBOOST_H
#define MODULE_ATTRIBOOST_H

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "CommandScript.h"

#include <unordered_map>

enum AttriboostConstants
{
    ATTR_ITEM = 82010,
    TALENT_ITEM = 82011,
    ATTR_POINTS_PER_BOOK = 3,
    ATTR_SPELL = 18282,

    // Default of the `settings` column, inherited from the original module.
    // Nothing reads it any more; it is kept so the table keeps its layout.
    ATTR_SETTING_PROMPT = 1,

    ATTR_SPELL_STAMINA = 82007,
    ATTR_SPELL_AGILITY = 82000,
    ATTR_SPELL_INTELLECT = 82001,
    ATTR_SPELL_STRENGTH = 82002,
    ATTR_SPELL_SPIRIT = 82003,
    ATTR_SPELL_SPELL_POWER = 82006,
    ATTR_SPELL_CRITICAL_STRIKE_DAMAGE = 82004,
    ATTR_SPELL_ALL_RESISTS = 82008,
    ATTR_SPELL_PENETRATION = 82009,
    ATTR_SPELL_HEALING_POWER = 82005,

    // The ten auras above are hidden from the player (no aura icon, no combat
    // log). The one aura the player sees, "Attributes", does nothing: it is there
    // while any point is spent, and the interface lists the bonuses in its
    // tooltip.
    ATTR_SPELL_SUMMARY = 82012
};

// Texts shown to the player, one row each in `module_string` (English) and
// `module_string_locale` (every other language), keyed by this module name:
// data/sql/db-world/base/03_attriboost_strings.sql, the single source of every
// text of the module. The core picks the row matching the client's language and
// falls back on English. Ids 15-99 belong to the server-side Lua script, 101 and
// up to the interface. An id is never reused once retired.
#define ATTRIBOOST_MODULE "mod-attriboost"

enum AttriboostStrings
{
    ATTR_STR_DISABLED           = 1,
    ATTR_STR_BAD_BOOK_COUNT     = 2,
    ATTR_STR_NOT_ENOUGH_TOMES   = 3,
    ATTR_STR_ATTRIBUTE_POINTS   = 4,
    ATTR_STR_NOT_ENOUGH_TALENT_BOOKS = 5,
    ATTR_STR_TALENT_POINTS      = 6,
    ATTR_STR_UNKNOWN_STAT       = 7,
    ATTR_STR_BAD_POINT_COUNT    = 8,
    ATTR_STR_NOT_ENOUGH_POINTS  = 9,
    ATTR_STR_ALREADY_MAXED      = 10,
    ATTR_STR_PARTLY_ALLOCATED   = 11,
    ATTR_STR_NOTHING_TO_RESET   = 12,
    ATTR_STR_NOT_ENOUGH_MONEY   = 13,
    ATTR_STR_RESET_DONE         = 14
};

struct Attriboosts
{
    uint32 Unallocated;

    uint32 Stamina;
    uint32 Strength;
    uint32 Agility;
    uint32 Intellect;
    uint32 Spirit;
    uint32 SpellPower;
    uint32 CriticalStrikeDamage;
    uint32 AllResists;
    uint32 SpellPenetration;
    uint32 HealingPower;

    uint32 Settings;
};

std::unordered_map<uint64, Attriboosts> attriboostsMap;

Attriboosts* GetAttriboosts(Player* /*player*/);
void ClearAttriboosts();
void LoadAttriboosts();
Attriboosts* LoadAttriboostsForPlayer(Player* /*player*/);
void SaveAttriboosts();
void SaveAttriboostsForPlayer(Player* /*player*/);
void SaveAttriboostsForPlayerDirect(Player* /*player*/);
void ApplyAttributes(Player* /*player*/, Attriboosts* /*attributes*/);
void DisableAttributes(Player* /*player*/);
bool TryAddAttribute(Attriboosts* /*attributes*/, uint32 /*attribute*/);
void ResetAttributes(Attriboosts* /*attributes*/);
bool HasAttributesToSpend(Player* /*player*/);
bool HasAttributes(Player* /*player*/);
bool IsAttributeAtMax(uint32 /*attribute*/, uint32 /*value*/);
uint32 GetAttributesToSpend(Player* /*player*/);
uint32 GetTotalAttributes(Player* /*player*/);
uint32 GetTotalAttributes(Attriboosts* /*attributes*/);
uint32 GetResetCost();

class AttriboostPlayerScript : public PlayerScript
{
public:
    AttriboostPlayerScript() : PlayerScript("AttriboostPlayerScript") { }

    virtual void OnPlayerLogin(Player* /*player*/) override;
    virtual void OnPlayerLogout(Player* /*player*/) override;
    virtual void OnPlayerLeaveCombat(Player* /*player*/) override;

    uint32 GetRandomAttributeForClass(Player* /*player*/);
    std::string GetAttributeName(uint32 /*attribute*/);
};

class AttriboostUnitScript : public UnitScript
{
public:
    AttriboostUnitScript() : UnitScript("AttriboostUnitScript") { }

    void OnDamage(Unit* /*attacker*/, Unit* /*victim*/, uint32& /*damage*/);
};

class AttriboostWorldScript : public WorldScript
{
public:
    AttriboostWorldScript() : WorldScript("AttriboostWorldScript") { }

    virtual void OnAfterConfigLoad(bool /*reload*/) override;
    virtual void OnShutdownInitiate(ShutdownExitCode /*code*/, ShutdownMask /*mask*/) override;
};

// Commandes joueur (.attriboost ...) : voie d'acces de l'interface Lua/AIO,
// qui valide puis pilote le module par RunCommand. Ecritures SYNCHRONES pour
// que le Lua puisse relire la base juste apres.
class AttriboostCommandScript : public CommandScript
{
public:
    AttriboostCommandScript() : CommandScript("AttriboostCommandScript") { }

    Acore::ChatCommands::ChatCommandTable GetCommands() const override;

    static bool HandleExchangeCommand(ChatHandler* /*handler*/, uint32 /*count*/);
    static bool HandleTalentsCommand(ChatHandler* /*handler*/, uint32 /*count*/);
    static bool HandleAllocateCommand(ChatHandler* /*handler*/, std::string /*stat*/, uint32 /*count*/);
    static bool HandleResetCommand(ChatHandler* /*handler*/);
};

#endif // MODULE_ATTRIBOOST_H
