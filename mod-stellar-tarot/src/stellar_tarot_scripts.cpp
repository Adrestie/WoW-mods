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

#include "AuctionHouseMgr.h"
#include "Creature.h"
#include "Item.h"
#include "LootMgr.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "StellarTarotEffects.h"
#include "StellarTarotLoot.h"
#include "StellarTarotMgr.h"

#include <algorithm>

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
            PLAYERHOOK_ON_MAP_CHANGED,
            PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST,
            PLAYERHOOK_ON_SPELL_CAST,
            PLAYERHOOK_ON_BEFORE_LOOT_MONEY,
            PLAYERHOOK_ON_GIVE_EXP,
            PLAYERHOOK_ON_GIVE_REPUTATION,
            PLAYERHOOK_ON_BEFORE_DURABILITY_REPAIR,
            PLAYERHOOK_ON_AFTER_STORE_OR_EQUIP_NEW_ITEM,
            PLAYERHOOK_ANTICHEAT_HANDLE_DOUBLE_JUMP,
            PLAYERHOOK_ANTICHEAT_CHECK_MOVEMENT_INFO,
            PLAYERHOOK_ON_GET_REPUTATION_PRICE_DISCOUNT,
            PLAYERHOOK_ON_MONEY_CHANGED,
            PLAYERHOOK_CAN_PLACE_AUCTION_BID,
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
    void OnPlayerMapChanged(Player* player) override { StellarTarotEffects::OnMapChanged(player); }
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
    void OnPlayerBeforeDurabilityRepair(Player* player, ObjectGuid /*npc*/, ObjectGuid item, float& discountMod, uint8 /*guildBank*/) override
    {
        StellarTarotEffects::OnRepairDiscount(player, item, discountMod);
        StellarTarotEffects::OnSpend(player);
    }
    void OnPlayerGetReputationPriceDiscount(Player const* player, Creature const* /*creature*/, float& discount) override
    {
        StellarTarotEffects::OnVendorDiscount(player, discount);
    }
    // A purchase, once the goods are in the bags -- and only a purchase: the
    // core calls this for what a VENDOR hands over, nothing else.
    //
    // CAREFUL: `count` is what the player ASKED FOR, counted in the vendor's
    // own lots, not in items. A lot is `BuyCount` items -- one click on a
    // stack of arrows buys two hundred of them -- so what actually landed in
    // the bags is the product of the two. Scripts are told the real figure.
    void OnPlayerAfterStoreOrEquipNewItem(Player* player, uint32 /*vendorslot*/, Item* item, uint8 count,
                                          uint8 /*bag*/, uint8 /*slot*/, ItemTemplate const* proto,
                                          Creature* vendor, VendorItem const* /*crItem*/, bool /*store*/) override
    {
        if (!vendor || !proto)
            return;
        uint32 const lot = proto->BuyCount ? proto->BuyCount : 1;
        // LE PRIX REELLEMENT PAYE, calcule comme Player::BuyItemFromVendorSlot
        // le calcule : le prix du lot, multiplie par le nombre de lots, puis
        // la remise du moment -- celle de la reputation ET celle que les autres
        // cartes accordent, puisque toutes passent par le meme crochet.
        uint64 price = uint64(proto->BuyPrice) * uint64(count);
        price = uint64(double(price) * double(player->GetReputationPriceDiscount(vendor)));
        StellarTarotEffects::OnVendorBuy(player, item, uint32(count) * lot,
                                         uint32(std::min<uint64>(price, 2000000000ULL)));
        if (price)
            StellarTarotEffects::OnSpend(player);
    }
    void OnPlayerMoneyChanged(Player* player, int32& amount) override { StellarTarotEffects::OnMoneyChanged(player, amount); }
    // LE SAUT. Le coeur n'a pas d'evenement de saut : il n'y a que ce crochet
    // d'anti-triche, appele sur l'opcode MSG_MOVE_JUMP et sur lui seul. On
    // regarde passer, on laisse toujours faire.
    bool AnticheatHandleDoubleJump(Player* player, Unit* /*mover*/) override
    {
        StellarTarotEffects::OnJump(player);
        return true;
    }
    // LA ROTATION. Le coeur n'a pas d'evenement pour « le joueur se tourne » :
    // il n'y a que ce crochet d'anti-triche, appele a CHAQUE paquet de
    // mouvement -- et le paquet porte l'orientation. On regarde passer, on
    // laisse toujours faire.
    bool AnticheatCheckMovementInfo(Player* player, MovementInfo const& movementInfo,
                                    Unit* /*mover*/, bool /*jump*/) override
    {
        StellarTarotEffects::OnFacing(player, movementInfo.pos.GetPositionX(),
                                     movementInfo.pos.GetPositionY(), movementInfo.pos.GetOrientation(),
                                     movementInfo.GetMovementFlags());
        return true;
    }
    // L'HOTEL DES VENTES : une enchere ou un achat immediat. Le coeur appelle
    // ce crochet au tout debut de la demande -- avant meme de savoir si elle
    // aboutira -- et n'en offre pas d'autre : le geste vaut la depense.
    bool OnPlayerCanPlaceAuctionBid(Player* player, AuctionEntry* /*auction*/) override
    {
        StellarTarotEffects::OnSpend(player);
        return true;
    }
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
            UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK,
            UNITHOOK_MODIFY_HEAL_RECEIVED,
            UNITHOOK_ON_AURA_APPLY,
            UNITHOOK_ON_HEAL,
            UNITHOOK_ON_BEFORE_ROLL_MELEE_OUTCOME_AGAINST,
            UNITHOOK_ON_UNIT_DEATH
        }) { }

    // Le coeur ne signale une mort qu'au tueur : c'est ici que le module
    // apprend qu'une creature est tombee, pour prevenir les temoins.
    void OnUnitDeath(Unit* unit, Unit* killer) override
    {
        StellarTarotEffects::OnUnitDied(unit, killer);
    }

    void OnBeforeRollMeleeOutcomeAgainst(Unit const* attacker, Unit const* victim, WeaponAttackType /*attType*/,
        int32& /*attackerMaxSkill*/, int32& /*victimMaxSkill*/, int32& /*attackerWeaponSkill*/, int32& /*victimDefenseSkill*/,
        int32& crit, int32& miss, int32& dodge, int32& parry, int32& block) override
    {
        StellarTarotEffects::OnMeleeRoll(const_cast<Unit*>(attacker), const_cast<Unit*>(victim), crit, miss, dodge, parry, block);
    }

    void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage) override
    {
        StellarTarotEffects::OnDamage(attacker, target, damage, false);
    }
    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
    {
        if (damage <= 0)
            return;
        uint32 d = uint32(damage);
        // The school of the blow travels with it: a card may name one.
        StellarTarotEffects::OnDamage(attacker, target, d, true,
                                      spellInfo ? uint32(spellInfo->GetSchoolMask()) : 0,
                                      spellInfo ? spellInfo->Id : 0);
        damage = int32(d);
    }
    // An aura laid on someone: the caster's cards may stretch it.
    void OnAuraApply(Unit* unit, Aura* aura) override
    {
        StellarTarotEffects::OnAuraApply(unit, aura);
    }

    // A tick of a periodic damage effect: the caster's cards may add to it.
    void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo) override
    {
        StellarTarotEffects::OnPeriodicTick(attacker, target, damage, false, spellInfo ? spellInfo->Id : 0);
    }

    // Every heal passes here, periodic ticks included. CAREFUL: the core calls
    // this with the CASTER first and the healed unit second, whatever the names
    // of the parameters say (Unit::HealBySpell). Only a spell that heals over
    // time is a tick.
    void ModifyHealReceived(Unit* caster, Unit* healed, uint32& heal, SpellInfo const* spellInfo) override
    {
        if (!spellInfo || !heal)
            return;
        // LE MONTANT DU SOIN, et non ce qu'il a rendu : une carte qui promet
        // « une part du montant » doit compter le sort tel qu'il est lancé. Le
        // crochet d'apres (OnHeal) ne connait que le gain -- nul des qu'une
        // cible manque peu de vie, ce qui faisait taire la ligne.
        StellarTarotEffects::OnHeal(caster, healed, heal);
        if (!spellInfo->HasAura(SPELL_AURA_PERIODIC_HEAL) && !spellInfo->HasAura(SPELL_AURA_OBS_MOD_HEALTH))
            return;
        StellarTarotEffects::OnPeriodicTick(caster, healed, heal, true, spellInfo->Id);
    }
    // Le soin une fois rendu : plus rien ne s'y accroche, les lignes comptant
    // desormais le MONTANT du sort, au crochet precedent.
    void OnHeal(Unit* /*healer*/, Unit* /*receiver*/, uint32& /*gain*/) override { }
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

    void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* tab,
        LootStore const& store, Player* lootOwner, bool /*personal*/,
        bool /*noEmptyError*/, uint16 /*lootMode*/) override
    {
        StellarTarotLoot::Fill(loot, store, lootOwner);
        if (!lootOwner)
            return;
        // What the CARDS add to a corpse: the same moment, the creature's own
        // loot store and no other.
        if (&store == &LootTemplates_Creature)
            StellarTarotEffects::OnCreatureLoot(lootOwner, loot);
        // Un coffre : la carte peut puiser de nouveau dans SA table.
        else if (&store == &LootTemplates_Gameobject)
            StellarTarotEffects::OnObjectLoot(lootOwner, loot, tab, &store);
        // Un minerai prospecte : la table du minerai, la meme, une fois de plus.
        else if (&store == &LootTemplates_Prospecting)
            StellarTarotEffects::OnProspect(lootOwner, loot, tab, &store);
        // La peche : ce que le bouchon vient de remonter.
        else if (&store == &LootTemplates_Fishing)
            StellarTarotEffects::OnFishing(lootOwner, loot, tab, &store);
        // The crate of goods being opened: the module fills it itself.
        else if (&store == &LootTemplates_Item)
            if (Item const* opened = lootOwner->GetItemByGuid(loot->containerGUID))
                if (opened->GetEntry() == STELLAR_TAROT_ITEM_CRATE)
                    StellarTarotLoot::FillCrate(lootOwner, loot);
    }
};

// L'HOTEL DES VENTES, du cote du vendeur : une vente mise en ligne, son depot
// deja preleve. Le coeur appelle aussi ce crochet en relisant les ventes de la
// base au demarrage -- personne n'est alors en jeu, et rien ne se passe.
class StellarTarotAuctionScript : public AuctionHouseScript
{
public:
    StellarTarotAuctionScript() : AuctionHouseScript("StellarTarotAuctionScript",
        {
            AUCTIONHOUSEHOOK_ON_AUCTION_ADD
        }) { }

    void OnAuctionAdd(AuctionHouseObject* /*ah*/, AuctionEntry* entry) override
    {
        if (!entry)
            return;
        if (Player* seller = ObjectAccessor::FindConnectedPlayer(entry->owner))
            StellarTarotEffects::OnSpend(seller);
    }
};

void AddSC_stellar_tarot_scripts()
{
    new StellarTarotWorldScript();
    new StellarTarotPlayerScript();
    new StellarTarotUnitScript();
    new StellarTarotLootScript();
    new StellarTarotAuctionScript();
}
