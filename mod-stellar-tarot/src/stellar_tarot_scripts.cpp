/*
 * This file is part of mod-stellar-tarot.
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
 * mod-stellar-tarot — the hooks into the core.
 *
 * The catalogue is loaded before the world opens, like any other custom
 * data. Reloading it at runtime goes through .tarot reload. The effects of a
 * layout are applied at login and handed the game's events while the
 * character is in the world: every hook here ends in StellarTarotEffects,
 * which passes the event to the scripts of the character concerned.
 */

#include "Creature.h"
#include "Item.h"
#include "LootMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "StellarTarotEffects.h"
#include "StellarTarotLoot.h"
#include "StellarTarotMgr.h"

class StellarTarotWorldScript : public WorldScript
{
public:
    StellarTarotWorldScript() : WorldScript("StellarTarotWorldScript",
        {
            WORLDHOOK_ON_BEFORE_WORLD_INITIALIZED
        }) { }

    void OnBeforeWorldInitialized() override
    {
        sStellarTarotMgr->Load();
    }
};

class StellarTarotPlayerScript : public PlayerScript
{
public:
    // THIS LIST GATES THE CALLS: ScriptDefines/PlayerScript.cpp goes through
    // CALL_ENABLED_HOOKS, so an overridden method missing from here compiles
    // and never fires.
    StellarTarotPlayerScript() : PlayerScript("StellarTarotPlayerScript",
        {
            PLAYERHOOK_ON_LOGIN,
            PLAYERHOOK_ON_LOGOUT,
            PLAYERHOOK_ON_LEVEL_CHANGED,
            PLAYERHOOK_ON_CREATURE_KILL,
            PLAYERHOOK_ON_CREATURE_KILLED_BY_PET,
            PLAYERHOOK_ON_UPDATE,
            PLAYERHOOK_ON_PLAYER_ENTER_COMBAT,
            PLAYERHOOK_ON_PLAYER_LEAVE_COMBAT,
            PLAYERHOOK_ON_PLAYER_JUST_DIED,
            PLAYERHOOK_ON_PLAYER_RESURRECT,
            PLAYERHOOK_ON_UPDATE_ZONE,
            PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST,
            PLAYERHOOK_ON_SPELL_CAST,
            PLAYERHOOK_ON_BEFORE_LOOT_MONEY,
            PLAYERHOOK_ON_GIVE_EXP,
            PLAYERHOOK_ON_GIVE_REPUTATION,
            PLAYERHOOK_ON_BEFORE_DURABILITY_REPAIR,
            PLAYERHOOK_ON_GET_REPUTATION_PRICE_DISCOUNT,
            PLAYERHOOK_ON_MONEY_CHANGED,
            PLAYERHOOK_CAN_SELL_ITEM
        }) { }

    void OnPlayerLogin(Player* player) override { StellarTarotEffects::OnLogin(player); }
    void OnPlayerLogout(Player* player) override { StellarTarotEffects::OnLogout(player); }

    // The statistics "per level of the player" are auras scaled by the level
    // at the time they are applied: a new level applies them again.
    void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        StellarTarotEffects::OnLevelChanged(player);
    }

    void OnPlayerCreatureKill(Player* killer, Creature* killed) override
    {
        StellarTarotEffects::OnCreatureKill(killer, killed);
    }
    // A pet or a totem landing the killing blow does not fire the previous
    // hook.
    void OnPlayerCreatureKilledByPet(Player* petOwner, Creature* killed) override
    {
        StellarTarotEffects::OnCreatureKill(petOwner, killed);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override { StellarTarotEffects::OnUpdate(player, diff); }
    void OnPlayerEnterCombat(Player* player, Unit* /*enemy*/) override { StellarTarotEffects::OnEnterCombat(player); }
    void OnPlayerLeaveCombat(Player* player) override { StellarTarotEffects::OnLeaveCombat(player); }
    void OnPlayerJustDied(Player* player) override { StellarTarotEffects::OnDeath(player); }
    void OnPlayerResurrect(Player* player, float /*restore*/, bool& /*sickness*/) override { StellarTarotEffects::OnResurrect(player); }
    void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 newArea) override { StellarTarotEffects::OnZone(player, newZone, newArea); }
    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override { StellarTarotEffects::OnQuestComplete(player, quest); }
    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override { StellarTarotEffects::OnSpellCast(player, spell); }
    void OnPlayerBeforeLootMoney(Player* player, Loot* loot) override
    {
        if (loot)
            StellarTarotEffects::OnLootMoney(player, loot->gold);
    }
    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 /*source*/) override { StellarTarotEffects::OnGiveXP(player, amount); }
    void OnPlayerGiveReputation(Player* player, int32 /*faction*/, float& amount, ReputationSource /*source*/) override
    {
        StellarTarotEffects::OnGiveReputation(player, amount);
    }
    void OnPlayerBeforeDurabilityRepair(Player* player, ObjectGuid /*npc*/, ObjectGuid /*item*/, float& discountMod, uint8 /*guildBank*/) override
    {
        StellarTarotEffects::OnRepairDiscount(player, discountMod);
    }
    void OnPlayerGetReputationPriceDiscount(Player const* player, Creature const* /*creature*/, float& discount) override
    {
        StellarTarotEffects::OnVendorDiscount(player, discount);
    }
    void OnPlayerMoneyChanged(Player* player, int32& amount) override { StellarTarotEffects::OnMoneyChanged(player, amount); }
    bool OnPlayerCanSellItem(Player* player, Item* item, Creature* /*vendor*/) override
    {
        StellarTarotEffects::OnSellItem(player, item);
        return true;
    }
};

// Damage and healing, both ways: the hooks fire for every unit, the module
// keeps what concerns a character with effects in force.
class StellarTarotUnitScript : public UnitScript
{
public:
    StellarTarotUnitScript() : UnitScript("StellarTarotUnitScript", true,
        {
            UNITHOOK_MODIFY_MELEE_DAMAGE,
            UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN,
            UNITHOOK_ON_HEAL
        }) { }

    void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage) override
    {
        StellarTarotEffects::OnDamage(attacker, target, damage, false);
    }
    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* /*spellInfo*/) override
    {
        if (damage <= 0)
            return;
        uint32 d = uint32(damage);
        StellarTarotEffects::OnDamage(attacker, target, d, true);
        damage = int32(d);
    }
    void OnHeal(Unit* healer, Unit* receiver, uint32& gain) override
    {
        StellarTarotEffects::OnHeal(healer, receiver, gain);
    }
};

// Cards and boards into the loot. The hook fires on EVERY loot the server
// fills: the sorting happens in StellarTarotLoot::Fill, from the loot store
// onwards, before anything is read.
class StellarTarotLootScript : public MiscScript
{
public:
    StellarTarotLootScript() : MiscScript("StellarTarotLootScript",
        {
            MISCHOOK_ON_AFTER_LOOT_TEMPLATE_PROCESS
        }) { }

    void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* /*tab*/,
        LootStore const& store, Player* lootOwner, bool /*personal*/,
        bool /*noEmptyError*/, uint16 /*lootMode*/) override
    {
        StellarTarotLoot::Fill(loot, store, lootOwner);
    }
};

void AddSC_stellar_tarot_scripts()
{
    new StellarTarotWorldScript();
    new StellarTarotPlayerScript();
    new StellarTarotUnitScript();
    new StellarTarotLootScript();
}
