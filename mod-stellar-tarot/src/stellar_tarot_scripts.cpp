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
 * mod-stellar-tarot — world and player scripts.
 *
 * The catalogue is loaded before the world opens, like any other custom
 * data. Reloading it at runtime goes through .tarot reload. The effects of a
 * layout are applied at login and handed the game's events while the
 * character is in the world.
 */

#include "Creature.h"
#include "LootMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
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
            PLAYERHOOK_ON_CREATURE_KILL,
            PLAYERHOOK_ON_CREATURE_KILLED_BY_PET
        }) { }

    void OnPlayerLogin(Player* player) override
    {
        StellarTarotEffects::OnLogin(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        StellarTarotEffects::OnLogout(player);
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
    new StellarTarotLootScript();
}
