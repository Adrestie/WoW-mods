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
 * mod-stellar-tarot — the effects a layout grants a character.
 *
 * From the board and the cards laid on it follows, for every card, an
 * activation level; from the level and the card follow the EFFECTS: the spell
 * and the script of that level -- and of every level below it when the card
 * is cumulative. A spell is applied as an aura; a script is instantiated and
 * fed the game's events.
 *
 * WHAT IS ACTIVE IS RECOMPUTED FROM SCRATCH at every change of the layout and
 * at login, and the difference with what was active is applied: auras added
 * and removed, scripts created and destroyed. At login every aura the module
 * could have left -- the core saves them with the character -- is removed
 * first, so that a card changed while the character was away is not carried
 * over. At logout the scripts die with the session; the auras are the core's
 * to save, and the next login sorts them out.
 */

#ifndef MOD_STELLAR_TAROT_EFFECTS_H_
#define MOD_STELLAR_TAROT_EFFECTS_H_

#include "Define.h"
#include "ObjectGuid.h"
#include <map>
#include <string>
#include <vector>

class Aura;
class Creature;
class Item;
class Loot;
class LootTemplate;
class LootStore;
class Player;
class Quest;
class Spell;
class Unit;

// One effect in force on a character: which card, which level, what it is.
struct StellarTarotActiveEffect
{
    uint32 cardId = 0;
    uint8 level = 0;
    uint32 spellId = 0;
    std::string script;         // the column as written, empty for none
};

namespace StellarTarotEffects
{
    // Applies the layout: what the character should have, minus what it has.
    void Refresh(Player* player);
    // Login: purge every aura of the module, then Refresh.
    void OnLogin(Player* player);
    // Logout: forget the character.
    void OnLogout(Player* player);
    // A new level: the auras scaled by the character's level (Spell.dbc
    // RealPointsPerLevel) were computed at the old one. Everything of the
    // module is purged and applied afresh, as at login.
    void OnLevelChanged(Player* player);
    // Every online character, after a .tarot reload.
    void RefreshEveryone();

    // The game's events, handed to every active script of the character.
    // LE VERROU DE RE-ENTRANCE, par joueur. Le module ne se declenche pas sur ce
    // qu'il vient lui-meme d'infliger ou de soigner : ses aides le levent le
    // temps de leur ouvrage, et les relais s'en remettent a lui.
    void HoldFor(ObjectGuid who);
    void ReleaseFor(ObjectGuid who);
    bool HeldFor(ObjectGuid who);

    void OnCreatureKill(Player* player, Creature* killed);
    void OnUpdate(Player* player, uint32 diff);               // ticks the scripts about once a second
    // Damage about to be dealt by `attacker` to `victim`: the attacker's
    // scripts see it as dealt, the victim's as taken. Either may be a creature.
    void OnDamage(Unit* attacker, Unit* victim, uint32& damage, bool spell, uint32 school = 1, uint32 spellId = 0);
    void OnHeal(Unit* healer, Unit* receiver, uint32& gain);
    void OnSpellCast(Player* player, Spell* spell);
    void OnEnterCombat(Player* player);
    void OnLeaveCombat(Player* player);
    void OnDeath(Player* player);
    void OnResurrect(Player* player);
    void OnZone(Player* player, uint32 zone, uint32 area);
    void OnMapChanged(Player* player);
    void OnQuestComplete(Player* player, Quest const* quest);
    void OnLootMoney(Player* player, uint32& copper);
    void OnGiveXP(Player* player, uint32& amount, uint8 source);
    void OnGiveReputation(Player* player, float& amount);
    void OnRepairDiscount(Player* player, ObjectGuid itemGuid, float& discountMod);
    void OnVendorDiscount(Player const* player, float& discount);
    void OnMoneyChanged(Player* player, int32& amount);
    void OnSellItem(Player* player, Item* item);
    void OnVendorBuy(Player* player, Item* item, uint32 count, uint32 paid);
    void OnCreatureLoot(Player* player, Loot* loot);
    void OnObjectLoot(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store);
    void OnProspect(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store);
    void OnFishing(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store);
    void OnSpend(Player* player);
    void OnFacing(Player* player, float x, float y, float orientation, uint32 moveFlags);
    void OnJump(Player* player);
    // Une creature morte : le module cherche lui-meme les porteurs de cartes
    // alentour, le coeur ne prevenant que le tueur.
    void OnUnitDied(Unit* died, Unit* killer);
    void OnPeriodicTick(Unit* caster, Unit* other, uint32& amount, bool heal, uint32 spellId);
    void OnAuraApply(Unit* target, Aura* aura);

    [[nodiscard]] std::vector<StellarTarotActiveEffect> Active(Player* player);

    // ===================== L'INSTRUMENT DE MESURE =====================
    //
    // Ce que le coeur cache depuis qu'il filtre : les procs REFUSES. Une aura
    // TEMOIN par evenement, a chance 100 et sans recharge, les rend visibles --
    // le module compte alors les OCCASIONS d'un cote, les DEPARTS de l'autre, et
    // le verdict se lit tout seul.
    struct Compte
    {
        uint32 occasions = 0;
        // LES OCCASIONS ELIGIBLES : celles ou la recharge ne bloquait pas. Une
        // ligne a recharge refuse deliberement les autres -- juger sa chance sur
        // le total reviendrait a lui reprocher de faire son office.
        uint32 eligibles = 0;
        uint32 departs = 0;
        uint32 dernier = 0;          // le dernier depart, en millisecondes
        uint32 ecartMin = 0;         // le plus court intervalle entre deux departs
        uint32 revers = 0;           // les contreparties tombees
        uint32 dites = 0;            // les occasions deja portees au journal
        // SUR QUI la ligne a agi la derniere fois. Une ligne qui part n'est pas
        // une ligne qui agit sur la bonne unite : le journal doit le dire.
        std::string cible;
    };

    // Commence ou arrete la mesure pour ce joueur ; rend le nombre de lignes
    // mesurees (les lignes a evenement de proc qu'il porte).
    uint32 MesureCommence(Player* player);
    // Le verdict au JOURNAL, ligne par ligne. Rend false s'il n'y a rien de
    // neuf a dire depuis la derniere fois.
    bool MesureAuJournal(Player* player, bool force);
    void MesureArrete(Player* player);
    bool MesureEnCours(Player* player);
    // Le releve, par sort de niveau.
    std::map<uint32, Compte> const& Mesure(Player* player);
    // Les trois compteurs, appeles par le moteur.
    void CompteOccasion(Player* player, uint32 index);
    // LE COEUR A FAIT PARTIR UNE AURA DU MODULE. Celle d'une ligne reveille la
    // ligne ; celle d'un TEMOIN ne fait que compter l'occasion.
    void OnProc(Player* player, uint32 auraId, Unit* other, uint32 amount);
    // L'aura d'un NIVEAU qui part est une promesse consommee : le coeur l'a
    // retiree au premier coup qui repondait, et le prix est du.
    void OnPromiseSpent(Player* player, uint32 spellId);
    void CompteDepart(Player* player, uint32 spellId, Unit* sur);
    void CompteRevers(Player* player, uint32 spellId);
    // Ce que la ligne d'un sort de niveau promet : sa chance, son temps de
    // recharge, et ce que le coeur en tient. Faux si le sort n'est pas une
    // ligne a evenement.
    bool PromesseDe(Player* player, uint32 spellId, int32& chance, int32& icd,
                    bool& coreChance, bool& coreIcd);
}

#endif
