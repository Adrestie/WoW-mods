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
 * mod-stellar-tarot — applying the effects of a layout.
 */

#include "StellarTarotEffects.h"
#include "Log.h"
#include "Player.h"
#include "StellarTarotLayout.h"
#include "StellarTarotMgr.h"
#include "StellarTarotScript.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include <map>
#include <memory>

namespace
{
    // An effect in force, with the script instance when there is one.
    struct Running
    {
        StellarTarotActiveEffect effect;
        std::unique_ptr<StellarTarotScript> script;
    };

    // Character guid -> its running effects.
    std::map<uint32, std::vector<Running>>& Everyone()
    {
        static std::map<uint32, std::vector<Running>> everyone;
        return everyone;
    }

    uint32 Guid(Player* player) { return player->GetGUID().GetCounter(); }

    // A card at a level is one key; two cards can name the same spell, and an
    // aura is only removed when no other effect in force still names it.
    bool SameEffect(StellarTarotActiveEffect const& a, StellarTarotActiveEffect const& b)
    {
        return a.cardId == b.cardId && a.level == b.level && a.spellId == b.spellId && a.script == b.script;
    }

    // What the layout grants: for every laid card, its reached level -- and
    // the levels below when it is cumulative.
    std::vector<StellarTarotActiveEffect> Wanted(Player* player)
    {
        std::vector<StellarTarotActiveEffect> out;
        StellarTarotLayout const layout = StellarTarotLayouts::Load(player);
        for (StellarTarotActivation const& a : StellarTarotLayouts::Activations(layout))
        {
            StellarTarotCard const* card = sStellarTarotMgr->Card(a.placement.cardId);
            if (!card || a.level == 0)
                continue;
            uint8 const first = card->cumulative ? 1 : a.level;
            for (uint8 level = first; level <= a.level; ++level)
            {
                StellarTarotEffect const& effect = card->effects[level - 1];
                StellarTarotActiveEffect active;
                active.cardId = card->id;
                active.level = level;
                active.spellId = effect.spellId;
                active.script = effect.script.text;
                out.push_back(active);
            }
        }
        return out;
    }

    void Start(Player* player, StellarTarotActiveEffect const& effect, std::vector<Running>& running)
    {
        Running r;
        r.effect = effect;
        if (effect.spellId && !player->HasAura(effect.spellId))
            player->AddAura(effect.spellId, player);
        if (!effect.script.empty())
        {
            StellarTarotCard const* card = sStellarTarotMgr->Card(effect.cardId);
            std::string error;
            if (card)
                r.script = StellarTarotScripts::Create(card->effects[effect.level - 1].script, error);
            if (r.script)
                r.script->Apply(player);
            else
                LOG_ERROR("module", "StellarTarot: card {} level {}: script not started ({}).",
                          effect.cardId, effect.level, error);
        }
        running.push_back(std::move(r));
    }

    void Stop(Player* player, Running& r, std::vector<Running> const& others)
    {
        if (r.script)
        {
            r.script->Remove(player);
            r.script.reset();
        }
        if (r.effect.spellId)
        {
            bool stillNamed = false;
            for (Running const& o : others)
                if (&o != &r && o.effect.spellId == r.effect.spellId)
                    stillNamed = true;
            if (!stillNamed)
                player->RemoveAurasDueToSpell(r.effect.spellId);
        }
    }
}

void StellarTarotEffects::Refresh(Player* player)
{
    if (!player || !sStellarTarotMgr->Enabled())
        return;
    std::vector<Running>& running = Everyone()[Guid(player)];
    std::vector<StellarTarotActiveEffect> const wanted = Wanted(player);

    // What is no longer wanted stops first, so that an aura two effects share
    // is judged against what stays.
    for (size_t i = 0; i < running.size();)
    {
        bool keep = false;
        for (StellarTarotActiveEffect const& w : wanted)
            if (SameEffect(w, running[i].effect))
                keep = true;
        if (keep)
        {
            ++i;
            continue;
        }
        Running gone = std::move(running[i]);
        running.erase(running.begin() + i);
        Stop(player, gone, running);
    }
    // Then what is wanted and not yet in force starts. An aura the core
    // restored at login is not applied twice: Start checks HasAura.
    for (StellarTarotActiveEffect const& w : wanted)
    {
        bool have = false;
        for (Running const& r : running)
            if (SameEffect(w, r.effect))
                have = true;
        if (!have)
            Start(player, w, running);
    }
    // THE BANNER, the one aura the player sees: there while anything is in
    // force, gone when nothing is.
    if (!running.empty())
    {
        if (!player->HasAura(STELLAR_TAROT_BANNER_SPELL))
            player->AddAura(STELLAR_TAROT_BANNER_SPELL, player);
    }
    else
        player->RemoveAurasDueToSpell(STELLAR_TAROT_BANNER_SPELL);
}

void StellarTarotEffects::OnLogin(Player* player)
{
    if (!player || !sStellarTarotMgr->Enabled())
        return;
    Everyone()[Guid(player)].clear();
    // EVERY AURA OF THE MODULE GOES FIRST: the core saved them with the
    // character, and the card, the level or the catalogue may have changed
    // since. What the layout grants today is applied afresh.
    for (uint32 spellId : sStellarTarotMgr->EffectSpells())
        player->RemoveAurasDueToSpell(spellId);
    player->RemoveAurasDueToSpell(STELLAR_TAROT_BANNER_SPELL);
    Refresh(player);
}

void StellarTarotEffects::OnLogout(Player* player)
{
    if (!player)
        return;
    auto it = Everyone().find(Guid(player));
    if (it == Everyone().end())
        return;
    for (Running& r : it->second)
        if (r.script)
            r.script->Remove(player);
    Everyone().erase(it);
}

void StellarTarotEffects::RefreshEveryone()
{
    for (auto const& [id, session] : sWorldSessionMgr->GetAllSessions())
        if (session && session->GetPlayer() && session->GetPlayer()->IsInWorld())
            OnLogin(session->GetPlayer());
}

void StellarTarotEffects::OnCreatureKill(Player* player, Creature* killed)
{
    if (!player)
        return;
    auto it = Everyone().find(Guid(player));
    if (it == Everyone().end())
        return;
    for (Running& r : it->second)
        if (r.script)
            r.script->OnCreatureKill(player, killed);
}

std::vector<StellarTarotActiveEffect> StellarTarotEffects::Active(Player* player)
{
    std::vector<StellarTarotActiveEffect> out;
    if (!player)
        return out;
    auto it = Everyone().find(Guid(player));
    if (it == Everyone().end())
        return out;
    for (Running const& r : it->second)
        out.push_back(r.effect);
    return out;
}
