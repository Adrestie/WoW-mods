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
#include <string>
#include <vector>

class Creature;
class Item;
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
    void OnCreatureKill(Player* player, Creature* killed);
    void OnUpdate(Player* player, uint32 diff);               // ticks the scripts about once a second
    // Damage about to be dealt by `attacker` to `victim`: the attacker's
    // scripts see it as dealt, the victim's as taken. Either may be a creature.
    void OnDamage(Unit* attacker, Unit* victim, uint32& damage, bool spell);
    void OnHeal(Unit* healer, Unit* receiver, uint32& gain);
    void OnSpellCast(Player* player, Spell* spell);
    void OnEnterCombat(Player* player);
    void OnLeaveCombat(Player* player);
    void OnDeath(Player* player);
    void OnResurrect(Player* player);
    void OnZone(Player* player, uint32 zone, uint32 area);
    void OnQuestComplete(Player* player, Quest const* quest);
    void OnLootMoney(Player* player, uint32& copper);
    void OnGiveXP(Player* player, uint32& amount);
    void OnGiveReputation(Player* player, float& amount);
    void OnRepairDiscount(Player* player, float& discountMod);
    void OnVendorDiscount(Player const* player, float& discount);
    void OnMoneyChanged(Player* player, int32& amount);
    void OnSellItem(Player* player, Item* item);

    [[nodiscard]] std::vector<StellarTarotActiveEffect> Active(Player* player);
}

#endif
