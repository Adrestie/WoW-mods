/*
 * .aw bonus [player]: the damage and healing bonuses the core multiplies into every hit of a player,
 * by school (auras SPELL_AURA_MOD_DAMAGE_PERCENT_DONE and SPELL_AURA_MOD_HEALING_DONE_PERCENT), with
 * the spell power (damage) and the healing power the core adds before them. The core computes these
 * for each hit but has no command that shows them: .list auras lists the auras one by one.
 */

#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"

using namespace Acore::ChatCommands;

namespace
{
    constexpr char const* MODULE = "mod-artifact-weapons";

    // module_string ids of the module.
    enum ArtifactWeaponsStrings
    {
        AW_STR_BONUS_TITLE         = 1,
        AW_STR_BONUS_WEAPON        = 2,
        AW_STR_BONUS_SPELLS        = 3,
        AW_STR_BONUS_HEALING       = 4,
        AW_STR_BONUS_SPELL_POWER   = 5,
        AW_STR_BONUS_HEALING_POWER = 6,
        AW_STR_BONUS_NOTE          = 7,
    };

    // Percent the damage done auras add for this school, filtered as the core filters them
    // (Unit::MeleeDamageBonusDone, Unit::SpellPctDamageModsDone): an aura bound to an equipped weapon
    // counts when that weapon is worn, and spells never get the physical ones bound to a weapon.
    float DamageDonePct(Player* player, SpellSchoolMask school, bool weaponAttack)
    {
        float multiplier = player->GetTotalAuraMultiplier(SPELL_AURA_MOD_DAMAGE_PERCENT_DONE,
            [player, school, weaponAttack](AuraEffect const* aurEff)
        {
            if (!(aurEff->GetMiscValue() & school))
                return false;
            SpellInfo const* info = aurEff->GetSpellInfo();
            if (info->EquippedItemClass == -1)
                return true;
            bool anyItem = info->HasAttribute(SPELL_ATTR5_AURA_AFFECTS_NOT_JUST_REQ_EQUIPPED_ITEM);
            if (!weaponAttack && !anyItem && aurEff->GetMiscValue() == SPELL_SCHOOL_MASK_NORMAL)
                return false;
            if (!anyItem && info->EquippedItemSubClassMask == 0)
                return true;
            return player->HasItemFitToSpellRequirements(info);
        });
        return (multiplier - 1.0f) * 100.0f;
    }

    template<typename... Args>
    void Say(ChatHandler* handler, uint32 id, Args&&... args)
    {
        handler->SendSysMessage(handler->PGetParseModuleString(MODULE, id, std::forward<Args>(args)...));
    }
}

class artifact_weapons_commandscript : public CommandScript
{
public:
    artifact_weapons_commandscript() : CommandScript("artifact_weapons_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable awTable =
        {
            { "bonus", HandleBonusCommand, SEC_GAMEMASTER, Console::Yes }
        };

        static ChatCommandTable commandTable =
        {
            { "aw", awTable }
        };

        return commandTable;
    }

    // The named player, else the selected one, else oneself.
    static bool HandleBonusCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        if (!target)
            target = PlayerIdentifier::FromTargetOrSelf(handler);
        if (!target || !target->IsConnected())
        {
            handler->SendErrorMessage(LANG_PLAYER_NOT_FOUND);
            return false;
        }

        Player* player = target->GetConnectedPlayer();
        Say(handler, AW_STR_BONUS_TITLE, player->GetName());
        Say(handler, AW_STR_BONUS_WEAPON, DamageDonePct(player, SPELL_SCHOOL_MASK_NORMAL, true));
        Say(handler, AW_STR_BONUS_SPELLS,
            DamageDonePct(player, SPELL_SCHOOL_MASK_NORMAL, false), DamageDonePct(player, SPELL_SCHOOL_MASK_HOLY, false),
            DamageDonePct(player, SPELL_SCHOOL_MASK_FIRE, false), DamageDonePct(player, SPELL_SCHOOL_MASK_NATURE, false),
            DamageDonePct(player, SPELL_SCHOOL_MASK_FROST, false), DamageDonePct(player, SPELL_SCHOOL_MASK_SHADOW, false),
            DamageDonePct(player, SPELL_SCHOOL_MASK_ARCANE, false));
        Say(handler, AW_STR_BONUS_HEALING,
            (player->GetTotalAuraMultiplier(SPELL_AURA_MOD_HEALING_DONE_PERCENT) - 1.0f) * 100.0f);
        Say(handler, AW_STR_BONUS_SPELL_POWER,
            player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_HOLY), player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_FIRE),
            player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_NATURE), player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_FROST),
            player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_SHADOW), player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_ARCANE));
        Say(handler, AW_STR_BONUS_HEALING_POWER, player->SpellBaseHealingBonusDone(SPELL_SCHOOL_MASK_ALL));
        Say(handler, AW_STR_BONUS_NOTE);
        return true;
    }
};

void AddSC_artifact_weapons_commandscript()
{
    new artifact_weapons_commandscript();
}
