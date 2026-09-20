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
 * mod-stellar-tarot — the scripts a card can name.
 *
 * A spell applied as an aura covers a plain statistic; everything else -- a
 * thing that happens on a kill, on a hit, under a condition -- is a SCRIPT:
 * a small C++ class registered under a name, that a card names in one of its
 * `card_script_N` columns as `name` or `name:param:param`.
 *
 * ONE INSTANCE PER PLAYER AND PER ACTIVE LEVEL. The module creates it when the
 * level is reached, tells it the level's spell, calls Apply, feeds it the
 * game's events while it lives, calls Remove and destroys it when the level
 * is lost or the player logs out. A script keeps whatever state it needs in
 * its own members.
 *
 * THE LEVEL'S SPELL. Every level names a spell. Normally the module applies
 * it as a permanent aura; a script that answers true to OwnsAura takes it
 * over instead -- applies it under a condition, or for a while after an
 * event, or with figures it computes -- and the module leaves it alone.
 *
 * THE FAMILIES (StellarTarotEngine.cpp), named after the conditions of the
 * design workbook:
 *
 *   cond:<state>[:n]                      the level's aura, while a state holds
 *   proc:<event>:<chance>:<icd>:<action>  something happens on an event
 *   dmgmod:<target condition>[:n]:<pct>   damage dealt, under a condition on the target
 *   takenmod:<condition>:<pct>            damage taken, under a condition
 *   sp_pct:<pct>                          spell power, in percent of the current one
 *   econ:<kind>:<pct>                     gold, experience, reputation, prices
 *
 * WHAT A SCRIPT SAYS OF ITSELF is not in the code: the interface reads the
 * level's spell description, which the workbook wrote.
 */

#ifndef MOD_STELLAR_TAROT_SCRIPT_H_
#define MOD_STELLAR_TAROT_SCRIPT_H_

#include "Define.h"
#include "ObjectGuid.h"
#include "StellarTarotMgr.h"
#include <functional>
#include <memory>
#include <string>
#include <vector>

class Creature;
class Item;
class Player;
class Quest;
class Aura;
class Loot;
class LootTemplate;
class LootStore;
class Spell;
class Unit;

class StellarTarotScript
{
public:
    virtual ~StellarTarotScript() = default;

    // Reads the parameters; false, with `error` filled, when they cannot be
    // read. Called at load time to refuse a badly written card, and again on
    // every instance before Apply.
    virtual bool Parse(std::vector<std::string> const& params, std::string& error) = 0;

    // CE QUE LA LIGNE PROMET, pour l'instrument de mesure : son evenement, sa
    // chance, son temps de recharge, et ce que le coeur en tient desormais.
    // Faux pour les familles qui ne sont pas des procs.
    virtual bool Promise(std::string& /*event*/, int32& /*chance*/, int32& /*icd*/,
                         bool& /*coreChance*/, bool& /*coreIcd*/) const { return false; }

    // The level's spell, told before Apply.
    void SetSpell(uint32 spellId) { _spellId = spellId; }
    [[nodiscard]] uint32 SpellId() const { return _spellId; }
    // True: the module does not apply the level's spell itself.
    [[nodiscard]] virtual bool OwnsAura() const { return false; }

    virtual void Apply(Player* /*player*/) { }
    virtual void Remove(Player* /*player*/) { }

    // The game's events, while the level is active.
    virtual void OnTick(Player* /*player*/) { }                                  // about once a second
    virtual void OnCreatureKill(Player* /*player*/, Creature* /*killed*/) { }
    // Damage the player is about to deal / take. `damage` may be changed.
    // `school` is the school mask of the blow: 1 physical, 4 fire, and so on.
    // `spellId` is the spell that strikes, 0 for a weapon swing: a condition on
    // the target must be able to tell an aura this very spell keeps up.
    virtual void OnDamageDealt(Player* /*player*/, Unit* /*victim*/, uint32& /*damage*/, bool /*spell*/,
                               uint32 /*school*/ = 1, uint32 /*spellId*/ = 0) { }
    virtual void OnDamageTaken(Player* /*player*/, Unit* /*attacker*/, uint32& /*damage*/, bool /*spell*/,
                               uint32 /*school*/ = 1, uint32 /*spellId*/ = 0) { }
    virtual void OnHealDone(Player* /*player*/, Unit* /*target*/, uint32& /*gain*/) { }
    virtual void OnSpellCast(Player* /*player*/, Spell* /*spell*/) { }
    // NOTE D'UNITE : la chance qu'une ligne annonce (`Promise`) est EN POUR
    // MILLE -- 25 vaut 2,5 %. La ligne l'ecrit en pour-cent, le moteur la garde
    // au dixieme.
    // LE COEUR A FAIT PARTIR L'AURA DE CETTE LIGNE : l'evenement a eu lieu, la
    // chance et la recharge de `spell_proc` l'ont laisse passer, et le coeur
    // donne l'unite et le montant. Rien a reconstituer.
    virtual void OnTriggerProc(Player* /*player*/, Unit* /*other*/, uint32 /*amount*/) { }
    // LE COEUR CALCULE LA DUREE D'UNE AURA que le joueur pose, avant que
    // cette aura n'existe (Aura::CalcMaxDuration -> OnCalcMaxDuration).
    virtual void OnCalcAuraDuration(Player* /*player*/, Aura const* /*aura*/,
                                    int32& /*duration*/) { }
    // LE COEUR A CONSOMME LA PROMESSE : le coup promis a porte, l'aura est
    // retiree, et le prix est du. Le module ne suppose plus rien.
    virtual void OnPromiseSpent(Player* /*player*/) { }
    // L'AURA QUI NOMME CETTE LIGNE, quand elle en a une (le `trigger:`).
    [[nodiscard]] virtual uint32 Trigger() const { return 0; }
    virtual void OnEnterCombat(Player* /*player*/) { }
    virtual void OnLeaveCombat(Player* /*player*/) { }
    virtual void OnLevelUp(Player* /*player*/) { }
    virtual void OnDeath(Player* /*player*/) { }
    // Une creature vient de mourir pres du joueur, tuee par n'importe qui --
    // lui compris. La distance est a la charge du script.
    virtual void OnNearbyDeath(Player* /*player*/, Unit* /*died*/) { }
    // LES CROCHETS QUE LE COEUR APPELLE BEAUCOUP : une ligne qui les veut le
    // DIT. Sans cette declaration, le module partirait en recherche spatiale a
    // chaque mort de creature du royaume, et suivrait chaque pas et chaque
    // saut de chaque joueur, pour n'y trouver personne.
    enum Guet : uint32
    {
        GUET_MORT_ALENTOUR = 0x1,   // une creature meurt pres du joueur
        GUET_ROTATION      = 0x2,   // le joueur tourne sur place
        GUET_SAUT          = 0x4,   // le joueur saute
    };
    [[nodiscard]] virtual uint32 Watches() const { return 0; }
    // Le joueur saute : le seul signal que le coeur donne d'un saut.
    virtual void OnJump(Player* /*player*/) { }
    virtual void OnResurrect(Player* /*player*/) { }
    virtual void OnZone(Player* /*player*/, uint32 /*zone*/, uint32 /*area*/) { }
    // Le joueur vient de changer de carte : franchir le seuil d'une instance
    // se lit ici, le coeur n'ayant pas d'evenement plus precis.
    virtual void OnMapChanged(Player* /*player*/) { }
    virtual void OnQuestComplete(Player* /*player*/, Quest const* /*quest*/) { }
    virtual void OnLootMoney(Player* /*player*/, uint32& /*copper*/) { }
    // `source` : d'ou vient l'experience (Player.h, enum PlayerXPSource) --
    // 0 une victime, 1 et 2 une quete, 3 une decouverte, 4 un champ de
    // bataille. Les auras natives ne couvrent que les trois premieres.
    virtual void OnGiveXP(Player* /*player*/, uint32& /*amount*/, uint8 /*source*/) { }
    virtual void OnGiveReputation(Player* /*player*/, float& /*amount*/) { }
    // Une réparation sur le point d'être payée : l'objet visé, ou un GUID
    // vide quand le joueur répare tout.
    virtual void OnRepairDiscount(Player* /*player*/, ObjectGuid /*itemGuid*/, float& /*discountMod*/) { }
    virtual void OnVendorDiscount(Player const* /*player*/, float& /*discount*/) { }
    virtual void OnMoneyChanged(Player* /*player*/, int32& /*amount*/) { }
    virtual void OnSellItem(Player* /*player*/, Item* /*item*/) { }
    // The loot of a creature, while it is being filled: a card may add to it.
    virtual void OnCreatureLoot(Player* /*player*/, Loot* /*loot*/) { }
    // Le butin d'un OBJET du decor -- un coffre -- pendant qu'il se remplit,
    // avec la table dont il sort : une carte peut y puiser de nouveau.
    // Un MINERAI PROSPECTE : sa table vient d'etre tiree, et une carte peut
    // la faire tirer une fois de plus.
    virtual void OnProspect(Player* /*player*/, Loot* /*loot*/, LootTemplate const* /*tab*/,
                            LootStore const* /*store*/) { }
    // UNE DEPENSE : de l'or vient de passer a un MARCHAND (un achat, une
    // reparation) ou a l'HOTEL DES VENTES (un depot, une enchere, un achat
    // immediat). Le courrier, le vol et l'entraineur n'en sont pas.
    virtual void OnSpend(Player* /*player*/) { }
    // LE JOUEUR BOUGE : la place et l'orientation qu'un paquet de mouvement
    // vient d'annoncer. Tout ce que le serveur sait de la rotation passe par la.
    virtual void OnFacing(Player* /*player*/, float /*x*/, float /*y*/, float /*orientation*/,
                          uint32 /*moveFlags*/) { }
    // UN COUP DU FAMILIER : le maitre est prevenu de ce que sa bete porte.
    virtual void OnPetDamage(Player* /*player*/, Unit* /*victim*/, uint32& /*damage*/) { }
    // LA PECHE : le butin du bouchon vient d'etre tire, et une carte peut y
    // ajouter -- ou doubler ce qui en sort.
    virtual void OnFishing(Player* /*player*/, Loot* /*loot*/, LootTemplate const* /*tab*/,
                           LootStore const* /*store*/) { }
    virtual void OnObjectLoot(Player* /*player*/, Loot* /*loot*/, LootTemplate const* /*tab*/,
                              LootStore const* /*store*/) { }
    // An item BOUGHT from a vendor, once it is in the bags: how many pieces
    // landed, and what the player ACTUALLY paid -- reputation and the other
    // cards' rebates included.
    virtual void OnVendorBuy(Player* /*player*/, Item* /*item*/, uint32 /*count*/, uint32 /*paid*/) { }
    // An aura the player has just laid on someone.
    virtual void OnAuraApplied(Player* /*player*/, Unit* /*target*/, Aura* /*aura*/) { }
    // A tick of one of the player's periodic effects, before it lands: damage
    // on a victim, or healing on whoever carries the effect.
    virtual void OnPeriodicTick(Player* /*player*/, Unit* /*other*/, uint32& /*amount*/, bool /*heal*/,
                                uint32 /*spellId*/) { }

protected:
    uint32 _spellId = 0;
};

namespace StellarTarotScripts
{
    using Factory = std::function<std::unique_ptr<StellarTarotScript>()>;

    void Register(std::string const& name, Factory factory);

    // A fresh instance with its parameters read, or nullptr with `error`.
    std::unique_ptr<StellarTarotScript> Create(StellarTarotScriptSpec const& spec, std::string& error);
    // Only says whether the spec is sound: known name, readable parameters.
    bool Check(StellarTarotScriptSpec const& spec, std::string& error);
    // The registered names, for the checks and the listings.
    std::vector<std::string> Names();

    // Makes sure every script of the module is registered.
    void RegisterAll();
    // The families of the engine (StellarTarotEngine.cpp).
    void RegisterEngine();
}

#endif
