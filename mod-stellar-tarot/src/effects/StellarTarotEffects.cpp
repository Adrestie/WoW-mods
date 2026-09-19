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
#include "GameTime.h"
#include "Log.h"
#include "Player.h"
#include "StellarTarotLayout.h"
#include "StellarTarotMgr.h"
#include "StellarTarotScript.h"
#include "Spell.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include "CellImpl.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include <list>
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

    // Secondes ecoulees depuis le dernier verdict porte au journal, par
    // personnage : l'instrument ne parle que toutes les trente secondes.
    std::map<uint32, uint32>& Verdicts()
    {
        static std::map<uint32, uint32> verdicts;
        return verdicts;
    }

    // Milliseconds since the last tick, per character.
    std::map<uint32, uint32>& Clocks()
    {
        static std::map<uint32, uint32> clocks;
        return clocks;
    }

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
        // The script first: one that OWNS the level's spell applies it itself.
        if (!effect.script.empty())
        {
            StellarTarotCard const* card = sStellarTarotMgr->Card(effect.cardId);
            std::string error;
            if (card)
                r.script = StellarTarotScripts::Create(card->effects[effect.level - 1].script, error);
            if (!r.script)
                LOG_ERROR("module", "StellarTarot: card {} level {}: script not started ({}).",
                          effect.cardId, effect.level, error);
        }
        bool const owned = r.script && r.script->OwnsAura();
        if (effect.spellId && !owned && !player->HasAura(effect.spellId))
            player->AddAura(effect.spellId, player);
        if (r.script)
        {
            r.script->SetSpell(effect.spellId);
            r.script->Apply(player);
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
    // L'INSTRUMENT DE MESURE suit le plateau : ce qui est pose est ce qui est
    // mesure. Les temoins se posent, les compteurs repartent de zero.
    if (sStellarTarotMgr->Checking())
        MesureCommence(player);
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
    for (uint32 spellId = STELLAR_TAROT_TRIGGER_FIRST; spellId <= STELLAR_TAROT_TRIGGER_LAST; ++spellId)
        player->RemoveAurasDueToSpell(spellId);
    player->RemoveAurasDueToSpell(STELLAR_TAROT_BANNER_SPELL);
    Refresh(player);
}

void StellarTarotEffects::OnLogout(Player* player)
{
    if (!player)
        return;
    // UN DERNIER VERDICT avant de tout oublier.
    if (sStellarTarotMgr->Checking())
        MesureAuJournal(player, true);
    Verdicts().erase(Guid(player));
    Clocks().erase(Guid(player));
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

// ---------------------------------------------------------------------------
// The events, to the scripts of the character concerned.
// ---------------------------------------------------------------------------

namespace
{
    template <typename F>
    void Each(Player* player, F fn)
    {
        if (!player)
            return;
        auto it = Everyone().find(Guid(player));
        if (it == Everyone().end())
            return;
        for (Running& r : it->second)
            if (r.script)
                fn(*r.script);
    }

}

void StellarTarotEffects::OnUpdate(Player* player, uint32 diff)
{
    if (!player || !player->IsInWorld())
        return;
    uint32& clock = Clocks()[Guid(player)];
    clock += diff;
    if (clock < 1000)
        return;
    clock = 0;
    Each(player, [&](StellarTarotScript& s) { s.OnTick(player); });
    // LE VERDICT AU JOURNAL, toutes les trente secondes et seulement s'il s'est
    // passe quelque chose depuis la derniere fois.
    if (sStellarTarotMgr->Checking())
    {
        uint32& depuis = Verdicts()[Guid(player)];
        if (++depuis >= 30)
        {
            depuis = 0;
            MesureAuJournal(player, false);
        }
    }
}

namespace
{
    // Une PROFONDEUR par joueur, et non un booleen global : deux cartes qui se
    // repondent ne doivent pas se masquer l'une l'autre, et deux joueurs qui
    // frappent en meme temps ne partagent pas un verrou.
    std::map<ObjectGuid, uint32>& Locks()
    {
        static std::map<ObjectGuid, uint32> locks;
        return locks;
    }

    // UN SORT DU MODULE NE DECLENCHE PAS LE MODULE.
    bool OursSpell(uint32 spellId)
    {
        return spellId >= STELLAR_TAROT_CARD_ITEM_BASE && spellId <= STELLAR_TAROT_TRIGGER_LAST;
    }

    // Le verrou vaut pour l'unite qui agit comme pour celle qui subit : le
    // coup qu'une carte porte ne doit reveiller aucune ligne, des deux cotes.
    bool Held(Unit* one, Unit* two)
    {
        return (one && StellarTarotEffects::HeldFor(one->GetGUID()))
            || (two && StellarTarotEffects::HeldFor(two->GetGUID()));
    }
}

void StellarTarotEffects::HoldFor(ObjectGuid who)
{
    ++Locks()[who];
}

void StellarTarotEffects::ReleaseFor(ObjectGuid who)
{
    auto it = Locks().find(who);
    if (it == Locks().end())
        return;
    if (--it->second == 0)
        Locks().erase(it);
}

bool StellarTarotEffects::HeldFor(ObjectGuid who)
{
    return Locks().count(who) != 0;
}

void StellarTarotEffects::OnDamage(Unit* attacker, Unit* victim, uint32& damage, bool spell, uint32 school, uint32 spellId)
{
    if (OursSpell(spellId) || Held(attacker, victim))
        return;
    if (attacker && attacker->IsPlayer())
        Each(attacker->ToPlayer(), [&](StellarTarotScript& s) { s.OnDamageDealt(attacker->ToPlayer(), victim, damage, spell, school, spellId); });
    if (victim && victim->IsPlayer())
        Each(victim->ToPlayer(), [&](StellarTarotScript& s) { s.OnDamageTaken(victim->ToPlayer(), attacker, damage, spell, school, spellId); });
    // LE COUP DU FAMILIER : le coeur ne parle que de la bete ; le module remonte
    // jusqu'au maitre, dont les cartes peuvent y repondre.
    if (attacker && !attacker->IsPlayer())
        if (Unit* owner = attacker->GetOwner())
            if (Player* master = owner->ToPlayer())
                Each(master, [&](StellarTarotScript& s) { s.OnPetDamage(master, victim, damage); });
}

void StellarTarotEffects::OnHeal(Unit* healer, Unit* receiver, uint32& gain)
{
    if (Held(healer, receiver))
        return;
    if (healer && healer->IsPlayer())
        Each(healer->ToPlayer(), [&](StellarTarotScript& s) { s.OnHealDone(healer->ToPlayer(), receiver, gain); });
}

// ===================== L'INSTRUMENT DE MESURE =====================
//
// Un releve par joueur mesure, range par sort de niveau. Les occasions viennent
// des auras TEMOIN -- a chance 100, sans recharge -- et les departs de la ligne
// elle-meme : le rapport des deux est la chance reellement vecue, et le plus
// court intervalle entre deux departs la recharge reellement tenue.
namespace
{
    std::map<uint32, std::map<uint32, StellarTarotEffects::Compte>>& Releves()
    {
        static std::map<uint32, std::map<uint32, StellarTarotEffects::Compte>> releves;
        return releves;
    }

    // L'evenement d'une ligne -> le marqueur qui l'annonce, dans l'ordre des
    // marqueurs (903810 et suivants).
    int32 MarqueurDe(std::string const& event)
    {
        static char const* const events[] = { "crit", "spell_crit", "heal_crit", "dodge", "parry",
                                              "block", "crit_taken", "miss", "spell_crit_fire" };
        for (int32 i = 0; i < int32(sizeof(events) / sizeof(events[0])); ++i)
            if (event == events[i])
                return i;
        return -1;
    }
}

uint32 StellarTarotEffects::MesureCommence(Player* player)
{
    if (!player)
        return 0;
    auto& releve = Releves()[Guid(player)];
    releve.clear();
    uint32 posees = 0;
    Each(player, [&](StellarTarotScript& s)
    {
        std::string event;
        int32 chance = 0, icd = 0;
        bool coreChance = false, coreIcd = false;
        if (!s.Promise(event, chance, icd, coreChance, coreIcd))
            return;
        int32 const index = MarqueurDe(event);
        if (index < 0)
            return;                       // l'evenement ne vient pas du systeme de procs
        releve[s.SpellId()] = Compte();
        LOG_INFO("module", "StellarTarot CHECK: sous l'oeil -- sort {} sur « {} », chance {}% {}, "
                           "ICD {}s {}",
                 s.SpellId(), event, chance,
                 chance >= 100 ? "sans tirage" : (coreChance ? "coeur" : "module"),
                 icd, coreIcd ? "coeur" : "module");
        // LE TEMOIN DE CET EVENEMENT : il part a chaque occasion.
        uint32 const temoin = STELLAR_TAROT_WITNESS_FIRST + uint32(index);
        if (!player->HasAura(temoin))
        {
            player->AddAura(temoin, player);
            ++posees;
        }
    });
    if (releve.empty())
        LOG_INFO("module", "StellarTarot CHECK: rien a mesurer -- aucune ligne du plateau ne guette "
                           "un evenement du systeme de procs (critique, esquive, parade, blocage, "
                           "attaque ratee, critique de soin). Les autres lignes passent par les "
                           "crochets du module et n'ont pas de chance a verifier ici.");
    return uint32(releve.size());
}

void StellarTarotEffects::MesureArrete(Player* player)
{
    if (!player)
        return;
    for (uint32 id = STELLAR_TAROT_WITNESS_FIRST; id <= STELLAR_TAROT_WITNESS_LAST; ++id)
        player->RemoveAurasDueToSpell(id);
    Releves().erase(Guid(player));
}

bool StellarTarotEffects::MesureEnCours(Player* player)
{
    return player && Releves().count(Guid(player)) != 0;
}

std::map<uint32, StellarTarotEffects::Compte> const& StellarTarotEffects::Mesure(Player* player)
{
    static std::map<uint32, Compte> vide;
    if (!player)
        return vide;
    auto it = Releves().find(Guid(player));
    return it == Releves().end() ? vide : it->second;
}

// LE VERDICT AU JOURNAL. Les criteres sont ceux de la ligne elle-meme : les
// departs doivent tenir dans la fourchette binomiale a trois ecarts-types autour
// de `occasions x chance`, et le plus court intervalle entre deux departs ne
// jamais descendre sous l'ICD annonce.
bool StellarTarotEffects::MesureAuJournal(Player* player, bool force)
{
    if (!MesureEnCours(player))
        return false;
    auto& releve = Releves()[Guid(player)];
    bool du_neuf = false;
    for (auto& paire : releve)
        if (paire.second.occasions != paire.second.dites)
            du_neuf = true;
    if (!du_neuf && !force)
        return false;
    for (auto& paire : releve)
    {
        Compte& c = paire.second;
        c.dites = c.occasions;
        int32 chance = 100, icd = 0;
        bool coreChance = false, coreIcd = false;
        if (!PromesseDe(player, paire.first, chance, icd, coreChance, coreIcd))
            continue;
        uint32 carte = 0;
        uint32 niveau = 0;
        for (StellarTarotActiveEffect const& e : Active(player))
            if (e.spellId == paire.first)
            {
                carte = e.cardId;
                niveau = e.level;
            }
        double const p = double(chance) / 100.0;
        // LA CHANCE SE JUGE SUR LES ELIGIBLES : une ligne a recharge refuse
        // volontairement les occasions qui tombent dans sa fenetre.
        double const attendu = double(c.eligibles) * p;
        double const sigma = std::sqrt(double(c.eligibles) * p * (1.0 - p));
        double const marge = std::max(3.0 * sigma, 1.0);
        // A CHANCE CERTAINE la loi n'a aucune variance : une seule occasion
        // suffit a juger. Le seuil de trente ne vaut que pour l'incertain.
        bool const assez = c.eligibles >= 30 || chance >= 100 || chance <= 0;
        char const* const verdictChance =
            !c.eligibles ? "AUCUNE OCCASION"
                         : !assez ? "ECHANTILLON INSUFFISANT"
                         : (std::fabs(double(c.departs) - attendu) <= marge ? "ATTEINT" : "MANQUE");
        // UNE RECHARGE QUE RIEN N'A APPROCHEE n'est pas eprouvee : le dire, au
        // lieu de la declarer tenue.
        bool const tenue = c.ecartMin + 50 >= uint32(icd) * 1000;
        char const* const verdictIcd =
            !icd ? "sans objet"
                 : c.departs < 2 ? "ECHANTILLON INSUFFISANT"
                 : !tenue ? "MANQUE"
                 : (c.ecartMin > uint32(icd) * 2000 ? "ATTEINT (NON EPROUVE)" : "ATTEINT");
        double const taux = c.eligibles ? 100.0 * double(c.departs) / double(c.eligibles) : 0.0;
        LOG_INFO("module",
                 "StellarTarot CHECK: carte {} N{} | occasions {} dont {} eligibles | departs {} "
                 "= {:.1f}% (annonce {}% {}, attendu {:.1f} +/- {:.1f}) -> {} | ecart min {:.1f}s / "
                 "ICD {}s {} -> {} | revers {} | sur {}",
                 carte, niveau, c.occasions, c.eligibles, c.departs, taux,
                 chance, chance >= 100 ? "sans tirage" : (coreChance ? "coeur" : "module"),
                 attendu, marge, verdictChance,
                 double(c.ecartMin) / 1000.0, icd, coreIcd ? "coeur" : "module", verdictIcd,
                 c.revers, c.cible.empty() ? "-" : c.cible);
    }
    return true;
}

void StellarTarotEffects::OnProc(Player* player, uint32 auraId, Unit* other, uint32 amount)
{
    if (!player)
        return;
    // UNE AURA DE TEMOIN ne reveille aucune ligne : elle part a chaque
    // occasion, et c'est tout ce qu'on lui demande.
    if (auraId >= STELLAR_TAROT_WITNESS_FIRST && auraId <= STELLAR_TAROT_WITNESS_LAST)
    {
        CompteOccasion(player, auraId - STELLAR_TAROT_WITNESS_FIRST);
        return;
    }
    // L'AURA NOMME LA LIGNE : c'est le `trigger:` qu'elle declare.
    Each(player, [&](StellarTarotScript& s)
    {
        if (s.Trigger() == auraId)
            s.OnTriggerProc(player, other, amount);
    });
}

void StellarTarotEffects::CompteOccasion(Player* player, uint32 quel)
{
    if (!MesureEnCours(player))
        return;
    int32 const index = int32(quel);
    auto& releve = Releves()[Guid(player)];
    uint32 const now = uint32(GameTime::GetGameTimeMS().count());
    // L'OCCASION VAUT POUR TOUTES LES LIGNES QUI GUETTENT CET EVENEMENT. Elle
    // est ELIGIBLE quand la recharge de la ligne etait ecoulee : c'est sur
    // celles-la, et sur elles seules, que la chance se juge.
    Each(player, [&](StellarTarotScript& s)
    {
        std::string event;
        int32 chance = 0, icd = 0;
        bool coreChance = false, coreIcd = false;
        if (!s.Promise(event, chance, icd, coreChance, coreIcd) || MarqueurDe(event) != index)
            return;
        auto it = releve.find(s.SpellId());
        if (it == releve.end())
            return;
        ++it->second.occasions;
        if (!icd || !it->second.dernier || now - it->second.dernier >= uint32(icd) * 1000)
            ++it->second.eligibles;
    });
}

void StellarTarotEffects::CompteDepart(Player* player, uint32 spellId, Unit* sur)
{
    if (!MesureEnCours(player))
        return;
    auto& releve = Releves()[Guid(player)];
    auto it = releve.find(spellId);
    if (it == releve.end())
        return;
    uint32 const now = uint32(GameTime::GetGameTimeMS().count());
    if (it->second.dernier)
    {
        uint32 const ecart = now - it->second.dernier;
        if (!it->second.ecartMin || ecart < it->second.ecartMin)
            it->second.ecartMin = ecart;
    }
    it->second.dernier = now;
    ++it->second.departs;
    it->second.cible = sur ? sur->GetName() : "-";
}

bool StellarTarotEffects::PromesseDe(Player* player, uint32 spellId, int32& chance, int32& icd,
                                     bool& coreChance, bool& coreIcd)
{
    bool trouve = false;
    Each(player, [&](StellarTarotScript& s)
    {
        std::string event;
        if (s.SpellId() == spellId && s.Promise(event, chance, icd, coreChance, coreIcd))
            trouve = true;
    });
    return trouve;
}

void StellarTarotEffects::CompteRevers(Player* player, uint32 spellId)
{
    if (!MesureEnCours(player))
        return;
    auto& releve = Releves()[Guid(player)];
    auto it = releve.find(spellId);
    if (it != releve.end())
        ++it->second.revers;
}

void StellarTarotEffects::OnSpellCast(Player* player, Spell* spell)
{
    // LE MARQUEUR D'UN TEMOIN ne reveille aucune ligne : il ne sert qu'a
    // compter l'occasion, puisque son aura part a chaque fois.
    if (spell && player)
    {
        uint32 const id = spell->GetSpellInfo()->Id;
        if (id >= STELLAR_TAROT_MARKER_FIRST && id <= STELLAR_TAROT_MARKER_LAST)
            if (SpellInfo const* const par = spell->GetTriggeredByAuraSpellInfo())
                if (par->Id >= STELLAR_TAROT_WITNESS_FIRST && par->Id <= STELLAR_TAROT_WITNESS_LAST)
                {
                    CompteOccasion(player, id);
                    return;
                }
    }
    Each(player, [&](StellarTarotScript& s) { s.OnSpellCast(player, spell); });
}
void StellarTarotEffects::OnEnterCombat(Player* player)
{
    Each(player, [&](StellarTarotScript& s) { s.OnEnterCombat(player); });
}
void StellarTarotEffects::OnLeaveCombat(Player* player)
{
    Each(player, [&](StellarTarotScript& s) { s.OnLeaveCombat(player); });
}
void StellarTarotEffects::OnDeath(Player* player)
{
    Each(player, [&](StellarTarotScript& s) { s.OnDeath(player); });
}
void StellarTarotEffects::OnResurrect(Player* player)
{
    Each(player, [&](StellarTarotScript& s) { s.OnResurrect(player); });
}
void StellarTarotEffects::OnZone(Player* player, uint32 zone, uint32 area)
{
    Each(player, [&](StellarTarotScript& s) { s.OnZone(player, zone, area); });
}
void StellarTarotEffects::OnQuestComplete(Player* player, Quest const* quest)
{
    Each(player, [&](StellarTarotScript& s) { s.OnQuestComplete(player, quest); });
}
void StellarTarotEffects::OnLevelChanged(Player* player)
{
    // Les auras « par niveau du joueur » se reposent au nouveau chiffre...
    OnLogin(player);
    // ... et les scripts apprennent le niveau gagne : sans cela, une ligne
    // accrochee au niveau ne se declenchait jamais.
    Each(player, [&](StellarTarotScript& s) { s.OnLevelUp(player); });
}

void StellarTarotEffects::OnLootMoney(Player* player, uint32& copper)
{
    Each(player, [&](StellarTarotScript& s) { s.OnLootMoney(player, copper); });
}
void StellarTarotEffects::OnGiveXP(Player* player, uint32& amount, uint8 source)
{
    Each(player, [&](StellarTarotScript& s) { s.OnGiveXP(player, amount, source); });
}
void StellarTarotEffects::OnGiveReputation(Player* player, float& amount)
{
    Each(player, [&](StellarTarotScript& s) { s.OnGiveReputation(player, amount); });
}
void StellarTarotEffects::OnRepairDiscount(Player* player, ObjectGuid itemGuid, float& discountMod)
{
    Each(player, [&](StellarTarotScript& s) { s.OnRepairDiscount(player, itemGuid, discountMod); });
}
void StellarTarotEffects::OnVendorDiscount(Player const* player, float& discount)
{
    Each(const_cast<Player*>(player), [&](StellarTarotScript& s) { s.OnVendorDiscount(player, discount); });
}
void StellarTarotEffects::OnMoneyChanged(Player* player, int32& amount)
{
    Each(player, [&](StellarTarotScript& s) { s.OnMoneyChanged(player, amount); });
}
void StellarTarotEffects::OnVendorBuy(Player* player, Item* item, uint32 count, uint32 paid)
{
    Each(player, [&](StellarTarotScript& s) { s.OnVendorBuy(player, item, count, paid); });
}

void StellarTarotEffects::OnCreatureLoot(Player* player, Loot* loot)
{
    Each(player, [&](StellarTarotScript& s) { s.OnCreatureLoot(player, loot); });
}

// PERSONNE NE PREVIENT LES TEMOINS. Le coeur ne signale une mort qu'a celui
// qui l'a donnee ; une carte qui veut voir mourir autour d'elle doit chercher
// elle-meme. On ne parcourt que les joueurs qui portent des cartes, et la
// distance exacte reste au script : chacun a la sienne.
void StellarTarotEffects::OnUnitDied(Unit* died, Unit* /*killer*/)
{
    if (!died || !died->IsCreature())
        return;
    // On cherche autour du mort plutot que de parcourir tous les porteurs de
    // cartes du royaume : cent metres de garde-fou, la portee exacte restant
    // au script.
    std::list<Player*> around;
    Acore::AnyPlayerInObjectRangeCheck check(died, 100.0f);
    Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(died, around, check);
    Cell::VisitObjects(died, searcher, 100.0f);
    for (Player* player : around)
        if (player && player->IsInWorld())
            Each(player, [&](StellarTarotScript& s) { s.OnNearbyDeath(player, died); });
}

void StellarTarotEffects::OnProspect(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store)
{
    Each(player, [&](StellarTarotScript& s) { s.OnProspect(player, loot, tab, store); });
}

void StellarTarotEffects::OnFishing(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store)
{
    Each(player, [&](StellarTarotScript& s) { s.OnFishing(player, loot, tab, store); });
}

void StellarTarotEffects::OnSpend(Player* player)
{
    Each(player, [&](StellarTarotScript& s) { s.OnSpend(player); });
}

void StellarTarotEffects::OnFacing(Player* player, float x, float y, float orientation, uint32 moveFlags)
{
    Each(player, [&](StellarTarotScript& s) { s.OnFacing(player, x, y, orientation, moveFlags); });
}

void StellarTarotEffects::OnObjectLoot(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store)
{
    Each(player, [&](StellarTarotScript& s) { s.OnObjectLoot(player, loot, tab, store); });
}

void StellarTarotEffects::OnMapChanged(Player* player)
{
    Each(player, [&](StellarTarotScript& s) { s.OnMapChanged(player); });
}

void StellarTarotEffects::OnJump(Player* player)
{
    Each(player, [&](StellarTarotScript& s) { s.OnJump(player); });
}

void StellarTarotEffects::OnSellItem(Player* player, Item* item)
{
    Each(player, [&](StellarTarotScript& s) { s.OnSellItem(player, item); });
}
void StellarTarotEffects::OnAuraApply(Unit* target, Aura* aura)
{
    if (!aura || !target)
        return;
    Unit* const caster = aura->GetCaster();
    if (caster && caster->IsPlayer())
        Each(caster->ToPlayer(), [&](StellarTarotScript& s) { s.OnAuraApplied(caster->ToPlayer(), target, aura); });
}

void StellarTarotEffects::OnPeriodicTick(Unit* caster, Unit* other, uint32& amount, bool heal, uint32 spellId)
{
    // ICI, PAS DE GARDE SUR LE BLOC DU MODULE : une carte ECOUTE ses propres
    // battements -- la fievre reconnait ses tics a leur sort, et `tickmod`
    // amplifie ceux qu'une carte a poses. Seul le verrou de re-entrance vaut,
    // celui que les aides levent le temps de leur ouvrage.
    if (Held(caster, other))
        return;
    if (caster && caster->IsPlayer())
        Each(caster->ToPlayer(), [&](StellarTarotScript& s) { s.OnPeriodicTick(caster->ToPlayer(), other, amount, heal, spellId); });
}
void StellarTarotEffects::OnMeleeRoll(Unit* attacker, Unit* victim, int32& crit, int32& miss, int32& dodge, int32& parry, int32& block)
{
    if (attacker && attacker->IsPlayer())
        Each(attacker->ToPlayer(), [&](StellarTarotScript& s) { s.OnMeleeRoll(attacker->ToPlayer(), victim, crit, miss, dodge, parry, block); });
}

