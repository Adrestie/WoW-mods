/*
 * This file is part of mod-spheregrid.
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
 * mod-spheregrid — world scripts.
 *
 * The definition is loaded before the world opens, like any other custom data.
 * Reloading it at runtime goes through .spheregrid reload.
 */

#include "EventProcessor.h"
#include "Item.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "SphereGridStrings.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "SphereGridLoot.h"
#include "SphereGridMgr.h"
#include "SphereGridPlayerMgr.h"

class SphereGridWorldScript : public WorldScript
{
public:
    SphereGridWorldScript() : WorldScript("SphereGridWorldScript",
        {
            WORLDHOOK_ON_BEFORE_WORLD_INITIALIZED
        }) { }

    void OnBeforeWorldInitialized() override
    {
        sSphereGridMgr->Load();
    }
};

class SphereGridPlayerScript : public PlayerScript
{
public:
    SphereGridPlayerScript() : PlayerScript("SphereGridPlayerScript",
        {
            PLAYERHOOK_ON_LOGIN,
            PLAYERHOOK_ON_LOGOUT,
            PLAYERHOOK_ON_CREATURE_KILL,
            PLAYERHOOK_ON_CREATURE_KILLED_BY_PET,
            // The ranks granted by runes follow the talents live.
            PLAYERHOOK_ON_TALENTS_RESET,
            PLAYERHOOK_ON_AFTER_SPEC_SLOT_CHANGED,
            PLAYERHOOK_ON_LEARN_SPELL,
            // A level gained awards Spherite.
            PLAYERHOOK_ON_LEVEL_CHANGED,
            // A quest completed as well. THIS LIST GATES THE CALL:
            // ScriptDefines/PlayerScript.cpp goes through CALL_ENABLED_HOOKS, so
            // an overridden method missing from here compiles and never fires.
            PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST,
            // An achievement as well.
            PLAYERHOOK_ON_ACHI_COMPLETE
        }) { }

    void OnPlayerLogin(Player* player) override
    {
        sSphereGridPlayerMgr->Load(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        sSphereGridPlayerMgr->Unload(player);
        // Bad-luck protection does not outlive the session.
        SphereGridForgetPity(player);
    }

    void OnPlayerCreatureKill(Player* killer, Creature* killed) override
    {
        sSphereGridPlayerMgr->CreditBoss(killer, killed);
    }

    // A pet or a totem landing the killing blow does not fire the previous
    // hook.
    void OnPlayerCreatureKilledByPet(Player* petOwner, Creature* killed) override
    {
        sSphereGridPlayerMgr->CreditBoss(petOwner, killed);
    }

    // A COMPLETED QUEST AWARDS SPHERITE. The amount is read from the data like
    // every other award: the ("quest", quest id) row when it exists, otherwise
    // ("quest", 0), which is its default. No figure here.
    //
    // ONLY THE PLAYER HANDING THE QUEST IN IS CREDITED, unlike a boss: a quest
    // is turned in individually, even when completed as a group.
    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
    {
        if (!player || !quest)
            return;
        sSphereGridPlayerMgr->CreditSource(player, "quest", quest->GetQuestId(),
                                           SPHEREGRID_STR_GAIN_QUEST,
                                           SphereGridQuestName(player, quest));
    }

    // AN ACHIEVEMENT AWARDS SPHERITE: "its own score x the multiplier", the
    // latter being the (achievement, 0) row.
    //
    // BEWARE: this hook ALSO fires when a module granting account-wide
    // achievements hands a fresh character the whole account history at its
    // first login. CreditAchievement guards against that by checking that no
    // other character of the account already owns the achievement.
    void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) override
    {
        sSphereGridPlayerMgr->CreditAchievement(player, achievement);
    }

    // A LEVEL GAINED AWARDS SPHERITE: "the award x the new level", the award
    // being the ("level", 0) row. The core passes the OLD level; the new one is
    // read from the player.
    void OnPlayerLevelChanged(Player* player, uint8 oldLevel) override
    {
        sSphereGridPlayerMgr->CreditLevel(player, oldLevel);
    }

    // --- following the talents ---------------------------------------------
    // A talent spell lost must disable its runes ON THE SPOT, without the player
    // having to open any interface.
    //
    // Two precautions, both checked against the core:
    //
    //  - OnPlayerTalentsReset fires BEFORE the reset. Recomputing here would
    //    still see the old state, so the work is deferred by one loop tick.
    //  - OnPlayerLearnSpell fires once PER SPELL, that is a whole burst during a
    //    respec. The same deferral doubles as deduplication: several requests in
    //    the same tick amount to one.
    void OnPlayerTalentsReset(Player* player, bool /*noCost*/) override
    {
        DeferRuneSync(player);
    }

    void OnPlayerAfterSpecSlotChanged(Player* player, uint8 /*newSlot*/) override
    {
        DeferRuneSync(player);
    }

    void OnPlayerLearnSpell(Player* player, uint32 /*spellId*/) override
    {
        DeferRuneSync(player);
    }

private:
    // One synchronisation per loop tick and per player, no more.
    class SyncRunesEvent : public BasicEvent
    {
    public:
        explicit SyncRunesEvent(Player* player) : _guid(player->GetGUID()) { }

        bool Execute(uint64 /*time*/, uint32 /*diff*/) override
        {
            if (Player* player = ObjectAccessor::FindPlayer(_guid))
                sSphereGridPlayerMgr->SyncRunes(player);
            return true;
        }

    private:
        ObjectGuid _guid;
    };

    void DeferRuneSync(Player* player)
    {
        if (!player || !sSphereGridPlayerMgr->State(player))
            return;
        player->m_Events.AddEventAtOffset(new SyncRunesEvent(player), 1ms);
    }
};

// A Nexus consumed: the right click casts the item spell, exactly as for any
// consumable, and the item goes with its charge. The spell does nothing by
// itself — this script is what credits the points, and the NUMBER of points is
// carried by the spell (EffectBasePoints), read here through GetEffectValue().
// A single value: the client shows it as $s1 in the tooltip, the server applies
// it. Bound through spell_script_names.
class spell_spheregrid_sphere : public SpellScript
{
    PrepareSpellScript(spell_spheregrid_sphere);

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        if (!player)
            return;

        int32 const points = GetEffectValue();
        if (points <= 0)
            return;

        // The Nexus consumed names itself in the message: it is the item that
        // cast this spell. With no source item — a theoretical case — the name
        // stays empty.
        Item const* nexus = GetCastItem();
        sSphereGridPlayerMgr->Earn(player, uint32(points), SPHEREGRID_STR_GAIN_NEXUS,
            nexus ? SphereGridItemName(player, nexus->GetEntry()) : "");
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_spheregrid_sphere::HandleDummy,
                                 EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// The PRISMATIC NEXUS: one more prism on the account, and every Spherite gain
// goes up — with no cap.
class spell_spheregrid_prism : public SpellScript
{
    PrepareSpellScript(spell_spheregrid_prism);

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        if (player)
            sSphereGridPlayerMgr->AbsorbPrism(player);
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_spheregrid_prism::HandleDummy,
                                 EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// Injecting the sphere grid items into loot. The hook fires on EVERY loot the
// server fills: the sorting happens in SphereGridFillLoot, from the loot store
// onwards, before anything is read.
class SphereGridLootScript : public MiscScript
{
public:
    SphereGridLootScript() : MiscScript("SphereGridLootScript",
        {
            MISCHOOK_ON_AFTER_LOOT_TEMPLATE_PROCESS
        }) { }

    void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* /*tab*/,
        LootStore const& store, Player* lootOwner, bool /*personal*/,
        bool /*noEmptyError*/, uint16 /*lootMode*/) override
    {
        SphereGridFillLoot(loot, store, lootOwner);
    }
};

void AddSC_spheregrid_scripts()
{
    new SphereGridWorldScript();
    new SphereGridPlayerScript();
    new SphereGridLootScript();
    RegisterSpellScript(spell_spheregrid_sphere);
    RegisterSpellScript(spell_spheregrid_prism);
}
