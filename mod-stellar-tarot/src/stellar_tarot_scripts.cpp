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
            PLAYERHOOK_ON_STORE_NEW_ITEM,
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
    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 source) override { StellarTarotEffects::OnGiveXP(player, amount, source); }
    // UN OBJET QUI ENTRE DANS LES SACS : butin, achat, fabrication, courrier.
    void OnPlayerStoreNewItem(Player* player, Item* item, uint32 count) override
    {
        StellarTarotEffects::OnItemGained(player, item, count);
    }
    void OnPlayerGiveReputation(Player* player, int32 /*faction*/, float& amount, ReputationSource source) override
    {
        StellarTarotEffects::OnGiveReputation(player, amount, uint8(source));
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

namespace
{
    // LE DERNIER TIC DE SOIN VU. Le coeur annonce le tic d'un soin par deux
    // crochets consecutifs -- les tics, puis le soin -- avec les memes unites
    // et le meme sort. Le premier pose ce jeton, le second le consomme : c'est
    // a cela, et a cela seul, que le chemin periodique se reconnait de face du
    // chemin direct, ou les deux unites sont nommees dans l'autre ordre.
    struct TickMark
    {
        ObjectGuid healed, healer;
        uint32 spell = 0;
    };
    TickMark gTickMark;
}

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
            UNITHOOK_ON_AURA_REMOVE,
            UNITHOOK_ON_HEAL,
            UNITHOOK_ON_BEFORE_ROLL_MELEE_OUTCOME_AGAINST,
            UNITHOOK_ON_UNIT_DEATH
        }) { }

    // LE DE DU COUP BLANC, avant qu'il ne tombe. Le coeur passe les cinq
    // chances par reference : c'est le seul endroit ou une carte peut dire
    // « vos attaques ne peuvent plus etre bloquees ».
    void OnBeforeRollMeleeOutcomeAgainst(Unit const* attacker, Unit const* victim,
        WeaponAttackType /*attType*/, int32& /*attackerMaxSkillValueForLevel*/,
        int32& /*victimMaxSkillValueForLevel*/, int32& /*attackerWeaponSkill*/,
        int32& /*victimDefenseSkill*/, int32& crit_chance, int32& miss_chance,
        int32& dodge_chance, int32& parry_chance, int32& block_chance) override
    {
        StellarTarotEffects::OnMeleeRoll(const_cast<Unit*>(attacker), const_cast<Unit*>(victim),
                                         crit_chance, miss_chance, dodge_chance,
                                         parry_chance, block_chance);
    }

    // Le coeur ne signale une mort qu'au tueur : c'est ici que le module
    // apprend qu'une creature est tombee, pour prevenir les temoins.
    void OnUnitDeath(Unit* unit, Unit* killer) override
    {
        StellarTarotEffects::OnUnitDied(unit, killer);
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

    // Une aura qui s'en va : les revers qui ralentissent se recomptent.
    void OnAuraRemove(Unit* unit, AuraApplication* aurApp, AuraRemoveMode /*mode*/) override
    {
        StellarTarotEffects::OnAuraRemove(unit, aurApp ? aurApp->GetBase() : nullptr);
    }

    // UN TIC D'EFFET PERIODIQUE : les cartes du LANCEUR peuvent y ajouter. Le
    // coeur nomme ici la cible la premiere et le lanceur ensuite -- le module
    // les remet dans son ordre a lui. Il appelle AUSSI ce crochet sur le tic
    // d'un SOIN (HandlePeriodicHealAurasTick) : le sort dit lequel c'est.
    void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo) override
    {
        bool const soin = spellInfo && (spellInfo->HasAura(SPELL_AURA_PERIODIC_HEAL)
                                        || spellInfo->HasAura(SPELL_AURA_OBS_MOD_HEALTH));
        // Le jeton, pour le crochet du soin qui suit immediatement.
        if (soin && target && attacker)
            gTickMark = { target->GetGUID(), attacker->GetGUID(), spellInfo->Id };
        StellarTarotEffects::OnPeriodicTick(attacker, target, damage, soin, spellInfo ? spellInfo->Id : 0);
    }

    // TOUT SOIN passe ici, tics compris -- mais pas dans le meme ordre :
    //   soin direct    Unit::HealBySpell               (soigneur, soigne)
    //   tic d'un soin  HandlePeriodicHealAurasTick     (soigne, soigneur)
    // Le jeton pose juste avant par le crochet des tics tranche ; le tic
    // lui-meme y a deja ete annonce, il ne l'est donc plus ici.
    void ModifyHealReceived(Unit* premier, Unit* second, uint32& heal, SpellInfo const* spellInfo) override
    {
        bool const tic = spellInfo && premier && second
                      && spellInfo->Id == gTickMark.spell
                      && premier->GetGUID() == gTickMark.healed
                      && second->GetGUID() == gTickMark.healer;
        gTickMark = {};                          // le jeton ne sert qu'une fois
        if (!spellInfo || !heal)
            return;
        // LE MONTANT DU SOIN, et non ce qu'il a rendu : une carte qui promet
        // « une part du montant » doit compter le sort tel qu'il est lancé. Le
        // crochet d'apres (OnHeal) ne connait que le gain -- nul des qu'une
        // cible manque peu de vie, ce qui faisait taire la ligne.
        StellarTarotEffects::OnHeal(tic ? second : premier, tic ? premier : second, heal);
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
        // Le depeçage : ce que le couteau vient de tirer du cadavre.
        else if (&store == &LootTemplates_Skinning)
            StellarTarotEffects::OnSkinning(lootOwner, loot, tab, &store);
        // The crate of goods being opened: the module fills it itself.
        else if (&store == &LootTemplates_Item)
            if (Item const* opened = lootOwner->GetItemByGuid(loot->containerGUID))
                if (opened->GetEntry() == STELLAR_TAROT_ITEM_CRATE)
                    StellarTarotLoot::FillCrate(lootOwner, loot);
    }
};

// LE DE DE CHAQUE LIGNE DE TABLE DE BUTIN. Le crochet est global : il ne
// depend d'aucune entree de base, et le coeur l'appelle pour chaque ligne de
// chaque table qu'il compose. Rendre vrai laisse le de suivre son cours ; la
// carte ne fait que deplacer la chance.
class StellarTarotGlobalScript : public GlobalScript
{
public:
    StellarTarotGlobalScript() : GlobalScript("StellarTarotGlobalScript",
        {
            GLOBALHOOK_ON_ITEM_ROLL
        }) { }

    bool OnItemRoll(Player const* player, LootStoreItem const* item, float& chance,
        Loot& /*loot*/, LootStore const& /*store*/) override
    {
        if (player && item)
            StellarTarotEffects::OnItemRoll(player, item->itemid, chance);
        return true;
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
            AUCTIONHOUSEHOOK_ON_AUCTION_ADD,
            AUCTIONHOUSEHOOK_ON_BEFORE_AUCTIONHOUSEMGR_SEND_AUCTION_SUCCESSFUL_MAIL,
            AUCTIONHOUSEHOOK_ON_BEFORE_AUCTIONHOUSEMGR_SEND_AUCTION_WON_MAIL
        }) { }

    void OnAuctionAdd(AuctionHouseObject* /*ah*/, AuctionEntry* entry) override
    {
        if (!entry)
            return;
        if (Player* seller = ObjectAccessor::FindConnectedPlayer(entry->owner))
        {
            StellarTarotEffects::OnSpend(seller);
            StellarTarotEffects::OnAuctionPosted(seller, entry->deposit);
        }
    }

    // LA VENTE FAITE : le gain du vendeur, avant qu'il ne parte au courrier.
    void OnBeforeAuctionHouseMgrSendAuctionSuccessfulMail(AuctionHouseMgr* /*mgr*/, AuctionEntry* /*auction*/,
        Player* owner, uint32& /*owner_accId*/, uint32& profit, bool& /*sendNotification*/,
        bool& /*updateAchievementCriteria*/, bool& /*sendMail*/) override
    {
        if (owner)
            StellarTarotEffects::OnAuctionSold(owner, profit);
    }

    // L'ENCHERE REMPORTEE : ce que l'acheteur vient de payer.
    void OnBeforeAuctionHouseMgrSendAuctionWonMail(AuctionHouseMgr* /*mgr*/, AuctionEntry* auction,
        Player* bidder, uint32& /*bidder_accId*/, bool& /*sendNotification*/,
        bool& /*updateAchievementCriteria*/, bool& /*sendMail*/) override
    {
        if (bidder && auction)
            StellarTarotEffects::OnAuctionWon(bidder, auction->bid);
    }
};

// LE COEUR CALCULE LA DUREE D'UNE AURA. Un seul crochet est demande : le
// module n'est pas appele pour les treize autres.
class StellarTarotSpellScript : public AllSpellScript
{
public:
    StellarTarotSpellScript() : AllSpellScript("StellarTarotSpellScript",
        {
            ALLSPELLHOOK_ON_CALC_MAX_DURATION
        }) { }

    void OnCalcMaxDuration(Aura const* aura, int32& maxDuration) override
    {
        StellarTarotEffects::OnCalcDuration(aura, maxDuration);
    }
};

void AddSC_stellar_tarot_scripts()
{
    new StellarTarotWorldScript();
    new StellarTarotPlayerScript();
    new StellarTarotUnitScript();
    new StellarTarotLootScript();
    new StellarTarotGlobalScript();
    new StellarTarotAuctionScript();
    new StellarTarotSpellScript();
}
