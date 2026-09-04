#ifndef MODULE_ATTRIBOOST_H
#define MODULE_ATTRIBOOST_H

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "CommandScript.h"

#include <unordered_map>

enum AttriboostConstants
{
    ATTR_ITEM = 890010,
    TALENT_ITEM = 890011,
    ATTR_POINTS_PER_BOOK = 3,
    ATTR_SPELL = 18282,
    ATTR_QUEST = 441153,
    TALENT_QUEST = 441154,

    ATTR_SETTING_PROMPT = 1,

    ATTR_GOSSIP_ALLOCATE = 1,
    ATTR_GOSSIP_ALLOCATE_RETURN = 2,
    ATTR_GOSSIP_ALLOCATE_RESET = 3,
    ATTR_GOSSIP_SETTINGS = 4,
    ATTR_GOSSIP_SETTINGS_PROMPT = 5,
    ATTR_GOSSIP_SETTINGS_RETURN = 6,

    ATTR_NPC_TEXT_HAS_ATTRIBUTES = 441191,
    ATTR_NPC_TEXT_GENERIC = 441190,
    ATTR_NPC_TEXT_DISABLED = 441192,

    ATTR_SPELL_STAMINA = 890007,
    ATTR_SPELL_AGILITY = 890000,
    ATTR_SPELL_INTELLECT = 890001,
    ATTR_SPELL_STRENGTH = 890002,
    ATTR_SPELL_SPIRIT = 890003,
    ATTR_SPELL_SPELL_POWER = 890006,
    ATTR_SPELL_CRITICAL_STRIKE_DAMAGE = 890004,
    ATTR_SPELL_ALL_RESISTS = 890008,
    ATTR_SPELL_PENETRATION = 890009,
    ATTR_SPELL_HEALING_POWER = 890005
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

void AddAttributePoint(Player* /*player*/);
void AddTalentPoint(Player* /*player*/);
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
bool HasSetting(Player* /*player*/, uint32 /*setting*/);
void ToggleSetting(Player* /*player*/, uint32 /*setting*/);
void SendAllocateMenu(Player* /*player*/, Creature* /*creature*/);
void SendSettingsMenu(Player* /*player*/, Creature* /*creature*/);

class AttriboostPlayerScript : public PlayerScript
{
public:
    AttriboostPlayerScript() : PlayerScript("AttriboostPlayerScript") { }

    virtual void OnPlayerLogin(Player* /*player*/) override;
    virtual void OnPlayerLogout(Player* /*player*/) override;
    virtual void OnPlayerCompleteQuest(Player* /*player*/, Quest const* /*quest*/) override;
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

class AttriboostCreatureScript : public CreatureScript
{
public:
    AttriboostCreatureScript() : CreatureScript("AttriboostCreatureScript") { }

    virtual bool OnGossipHello(Player* /*player*/, Creature* /*creature*/) override;
    virtual bool OnGossipSelect(Player* /*player*/, Creature* /*creature*/, uint32 /*sender*/, uint32 /*action*/) override;

    void HandleAttributeAllocation(Player* /*player*/, uint32 /*attribute*/, bool /*reset*/);
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
