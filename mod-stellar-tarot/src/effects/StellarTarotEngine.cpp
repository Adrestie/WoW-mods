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
 * mod-stellar-tarot — the engine: the families of scripts the design
 * workbook's conditions map onto.
 *
 *   cond:<state>[:n]
 *       The level's spell is applied while the state holds and removed when
 *       it stops; checked every second and on combat changes. States:
 *       shield, twohand, dualwield, unarmed, solo, night, day, dawn_dusk,
 *       combat, nocombat, rested, water, still:<sec>, mounted:<sec>,
 *       hp_below:<pct>, hp_above:<pct>, mana_below:<pct>, gold_above:<copper>,
 *       hour:<from>:<to>. Then, optionally, stacks:<k>: a stack per period of
 *       the state, up to k (still:5:stacks:5); tick:<sec>:<action>:<n>: that
 *       small action while the state holds; sp:<pct>: the aura carries a spell
 *       power read as a percentage of the player's current one.
 *
 *   proc:<event>:<chance>:<icd>:<action>[:<params>]
 *       On the event, with that chance (percent) and no more often than the
 *       internal cooldown (seconds), the action. Events: kill, kill_boss,
 *       kill_elite, kill_humanoid, hit, hit_melee, hit_spell, dmg_taken,
 *       spell_cast_school:<school mask> (a spell of that school),
 *       dmg_taken_phys, dmg_taken_magic, spell_cast, heal, heal_ally,
 *       enter_combat, leave_combat, levelup, resurrect, zone, quest, hourly,
 *       tick:<sec> (in combat), every:<sec>, hp_below:<pct> (when crossed),
 *       mana_below:<pct>.
 *       Actions: aura:<sec>:<stacks> (the level's spell, for that long, stacking
 *       up to that many), heal:<pct of max>, mana:<pct of max>, heal_both:<pct>,
 *       restore, leech:<pct of the damage> (hit events), gold_level:<copper x
 *       level>, silver_level:<silver x level>, damage_sp:<pct>:<school>,
 *       damage_ap:<pct>:<school>, extra:<pct>:<school> (of the damage dealt),
 *       root:<sec>, stun:<sec>, bleed:<sec>:<pct of attack power per tick> (the
 *       other unit of a hit or kill event). Then, optionally, trigger:<spell>:
 *       the passive aura the core's proc system fires the event through (the
 *       events crit, spell_crit, heal_crit, dodge, parry, block, crit_taken,
 *       miss come that way, as MARKER spells the core casts). Then also
 *       cost:<kind>:<n> (health, mana or a control on the player),
 *       night:<n> (the action's figure between 21:00 and 06:00) and onlynight
 *       (nothing happens by day).
 *
 *   dmgmod:<target condition>[:n]:<pct>[:<school>]
 *       A school mask at the end limits it to that school (absent: all).
 *       The damage the player deals is changed by pct when the target meets
 *       the condition: stunned, alone, hp_above:<pct>, hp_below:<pct>, full_hp,
 *       humanoid, range_over:<yards>, slowed, burning.
 *
 *   takenmod:<condition>:<pct>[:<school>]
 *       The damage the player takes is changed by pct: alone (one attacker),
 *       controlled (stunned, rooted, feared, confused).
 *
 *   sp_pct:<pct>[:night:<pct>]
 *       The level's spell carries a flat spell power (damage and healing)
 *       recomputed every second as pct of the player's current spell power.
 *       A night percentage takes over between 21:00 and 06:00.
 *
 *   stat:<day>:<night>
 *       The level's aura, with the figure it takes by day and the one it takes
 *       by night; every effect of the spell gets that figure.
 *
 *   costmod:heal_low:<hp pct>:<discount pct>
 *       A heal on a target under that share of health costs that much less
 *       mana. The core takes the cost AFTER this hook, so the share comes back
 *       on the next update; the figure the client shows does not move.
 *
 *   tickmod:<chance>:<pct>[:onlynight]
 *       With that chance, one tick of one of the player's periodic effects --
 *       damage or healing -- counts for pct percent more (100: one tick more).
 *       onlynight: nothing by day.
 *
 *   econ:<kind>:<pct>
 *       gold_loot, xp, rep, quest_gold, repair (cost), vendor_buy (price),
 *       vendor_sell (price).
 *
 * Schools: 1 physical, 2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane.
 */

#include "StellarTarotScript.h"
#include "Creature.h"
#include "GameTime.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Player.h"
#include "QuestDef.h"
#include "SharedDefines.h"
#include "Spell.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "Unit.h"
#include "CellImpl.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Group.h"
#include "Pet.h"
#include "SpellMgr.h"
#include "ObjectAccessor.h"
#include "Log.h"
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <ctime>

namespace
{
    // -- parameters ----------------------------------------------------------

    bool Number(std::string const& s, int32 low, int32 high, int32& out)
    {
        if (s.empty())
            return false;
        size_t i = (s[0] == '-' || s[0] == '+') ? 1 : 0;
        if (i >= s.size() || s.find_first_not_of("0123456789", i) != std::string::npos)
            return false;
        long const v = std::strtol(s.c_str(), nullptr, 10);
        if (v < low || v > high)
            return false;
        out = int32(v);
        return true;
    }

    // "hp_below:30" split on the first colon is already done by the spec:
    // the state and its number come as two parameters. This joins a name and
    // reads the optional number that follows it in the parameter list.
    struct Reader
    {
        std::vector<std::string> const& p;
        size_t at = 0;
        explicit Reader(std::vector<std::string> const& params) : p(params) { }
        bool End() const { return at >= p.size(); }
        std::string Word() { return at < p.size() ? p[at++] : std::string(); }
        bool Int(int32 low, int32 high, int32& out)
        {
            if (at >= p.size() || !Number(p[at], low, high, out))
                return false;
            ++at;
            return true;
        }
        // An optional number: consumed only if the next word is one.
        bool OptInt(int32 low, int32 high, int32& out)
        {
            if (at < p.size() && Number(p[at], low, high, out)) { ++at; return true; }
            return false;
        }
    };

    // -- the game, read --------------------------------------------------------

    int LocalHour()
    {
        time_t t = time_t(GameTime::GetGameTime().count());
        tm lt{};
#ifdef _WIN32
        localtime_s(&lt, &t);
#else
        localtime_r(&t, &lt);
#endif
        return lt.tm_hour;
    }

    // Night: between 21:00 and 06:00, by the clock of the machine.
    bool IsNight() { int const h = LocalHour(); return h < 6 || h >= 21; }

    Item* Equipped(Player* player, uint8 slot)
    {
        return player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
    }

    bool HasShield(Player* player)
    {
        Item* off = Equipped(player, EQUIPMENT_SLOT_OFFHAND);
        return off && off->GetTemplate()->InventoryType == INVTYPE_SHIELD;
    }
    bool HasTwoHand(Player* player)
    {
        Item* main = Equipped(player, EQUIPMENT_SLOT_MAINHAND);
        return main && main->GetTemplate()->InventoryType == INVTYPE_2HWEAPON;
    }
    bool DualWields(Player* player)
    {
        Item* main = Equipped(player, EQUIPMENT_SLOT_MAINHAND);
        Item* off = Equipped(player, EQUIPMENT_SLOT_OFFHAND);
        return main && off && main->GetTemplate()->Class == ITEM_CLASS_WEAPON
            && off->GetTemplate()->Class == ITEM_CLASS_WEAPON;
    }
    bool Unarmed(Player* player)
    {
        Item* main = Equipped(player, EQUIPMENT_SLOT_MAINHAND);
        return !main || main->GetTemplate()->Class != ITEM_CLASS_WEAPON;
    }

    bool IsBoss(Creature* c)
    {
        return c && (c->isWorldBoss() || c->IsDungeonBoss());
    }
    bool IsElite(Creature* c)
    {
        return c && c->GetCreatureTemplate()->rank != CREATURE_ELITE_NORMAL;
    }

    uint32 PctOf(uint32 value, int32 pct)
    {
        return uint32(std::llround(double(value) * pct / 100.0));
    }

    // Re-entrancy guard: damage dealt from inside a damage hook must not fire
    // the hook again.
    bool gInsideDamage = false;

    // The hostile units within `range` of `center`, `except` left out.
    std::list<Unit*> HostilesAround(Player* player, WorldObject* center, float range, Unit* except)
    {
        std::list<Unit*> out;
        Acore::AnyUnfriendlyUnitInObjectRangeCheck check(center, player, range);
        Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck> searcher(center, out, check);
        Cell::VisitObjects(center, searcher, range);
        out.remove(except);
        return out;
    }

    bool gInsideHeal = false;

    SpellInfo const* Info(uint32 spellId) { return spellId ? sSpellMgr->GetSpellInfo(spellId) : nullptr; }

    // Damage dealt by the module, logged under the level's spell so the
    // client shows the figure.
    void Hurt(Player* player, Unit* victim, uint32 damage, uint32 school, uint32 spellId = 0)
    {
        if (!victim || !victim->IsAlive() || !damage || gInsideDamage)
            return;
        gInsideDamage = true;
        SpellInfo const* info = Info(spellId);
        uint32 const dealt = Unit::DealDamage(player, victim, damage, nullptr, SPELL_DIRECT_DAMAGE, SpellSchoolMask(school), info, false);
        if (info)
            player->SendSpellNonMeleeDamageLog(victim, info, dealt, SpellSchoolMask(school), 0, 0, school == 1, 0);
        gInsideDamage = false;
    }

    // A heal by the module: through the spell log, so the client shows it.
    void Heal(Player* player, Unit* target, uint32 amount, uint32 spellId)
    {
        if (!target || !target->IsAlive() || !amount)
            return;
        SpellInfo const* info = Info(spellId);
        if (!info)
        {
            target->ModifyHealth(int32(amount));
            return;
        }
        bool const was = gInsideHeal;
        gInsideHeal = true;
        HealInfo healInfo(player, target, amount, info, SPELL_SCHOOL_MASK_HOLY);
        player->HealBySpell(healInfo);
        gInsideHeal = was;
    }
    void Energize(Player* player, Unit* target, uint32 amount, uint32 spellId)
    {
        if (!target || !amount)
            return;
        if (spellId)
            player->EnergizeBySpell(target, spellId, amount, POWER_MANA);
        else
            target->ModifyPower(POWER_MANA, int32(amount));
    }
    // Health the player gives up: never below 1, logged as damage.
    void Bleed(Player* player, uint32 amount, uint32 spellId)
    {
        int32 const dmg = std::min<int32>(int32(amount), int32(player->GetHealth()) - 1);
        if (dmg <= 0)
            return;
        SpellInfo const* info = Info(spellId);
        gInsideDamage = true;
        Unit::DealDamage(player, player, uint32(dmg), nullptr, SELF_DAMAGE, SPELL_SCHOOL_MASK_SHADOW, info, false);
        gInsideDamage = false;
        if (info)
            player->SendSpellNonMeleeDamageLog(player, info, uint32(dmg), SPELL_SCHOOL_MASK_SHADOW, 0, 0, false, 0);
    }

    // A control or a shield of the module on `target`, for `sec` seconds,
    // with `bp` as the amount when the spell takes one.
    void Put(Player* player, Unit* target, uint32 spellId, int32 sec, int32 const* bp = nullptr)
    {
        if (!target || !target->IsAlive())
            return;
        if (bp)
        {
            // Le montant d'une aura déjà là ne se recalcule pas : on l'enlève
            // pour que la nouvelle pose remplace vraiment l'ancienne.
            target->RemoveAurasDueToSpell(spellId, player->GetGUID());
            player->CastCustomSpell(target, spellId, bp, nullptr, nullptr, true);
        }
        else
            player->AddAura(spellId, target);
        if (Aura* aura = target->GetAura(spellId, player->GetGUID()))
        {
            aura->SetMaxDuration(sec * 1000);
            aura->SetDuration(sec * 1000);
        }
    }

    // The group members (the player included) within `range`.
    std::vector<Player*> GroupAround(Player* player, float range)
    {
        std::vector<Player*> out;
        if (Group* group = player->GetGroup())
        {
            for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
                if (Player* member = ref->GetSource())
                    if (member->IsAlive() && member->IsInMap(player) && player->GetDistance(member) <= range)
                        out.push_back(member);
        }
        else
            out.push_back(player);
        return out;
    }

    // Every equipped item gains `points` of durability.
    void Mend(Player* player, uint32 points)
    {
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            uint32 const max = item->GetUInt32Value(ITEM_FIELD_MAXDURABILITY);
            uint32 const cur = item->GetUInt32Value(ITEM_FIELD_DURABILITY);
            if (!max || cur >= max)
                continue;
            item->SetUInt32Value(ITEM_FIELD_DURABILITY, std::min(max, cur + points));
            item->SetState(ITEM_CHANGED, player);
            if (!cur)
                player->_ApplyItemMods(item, slot, true);
        }
    }

    // The player pays: health (never below 1), mana, or a control on himself.
    void Cost(Player* player, std::string const& kind, int32 n, uint32 spellId = 0)
    {
        if (kind == "hp")
            Bleed(player, PctOf(player->GetMaxHealth(), n), spellId);
        else if (kind == "mana")
            player->ModifyPower(POWER_MANA, -int32(PctOf(player->GetMaxPower(POWER_MANA), n)));
        else if (kind == "disorient") Put(player, player, STELLAR_TAROT_SPELL_DISORIENT, n);
        else if (kind == "stun") Put(player, player, STELLAR_TAROT_SPELL_STUN, n);
        else if (kind == "silence") Put(player, player, STELLAR_TAROT_SPELL_SILENCE, n);
        else if (kind == "sleep") Put(player, player, STELLAR_TAROT_SPELL_SLEEP, n);
    }
    bool CostKind(std::string const& k)
    {
        return k == "hp" || k == "mana" || k == "disorient" || k == "stun" || k == "silence" || k == "sleep";
    }

    // A periodic action under a state (Cond) or on a timer: what and how much.
    void SmallAction(Player* player, std::string const& action, int32 n, uint32 spellId = 0)
    {
        if (action == "heal") Heal(player, player, PctOf(player->GetMaxHealth(), n), spellId);
        else if (action == "mana") Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), n), spellId);
        else if (action == "heal_both")
        {
            Heal(player, player, PctOf(player->GetMaxHealth(), n), spellId);
            Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), n), spellId);
        }
        else if (action == "repair") Mend(player, uint32(n));
    }
    bool SmallKind(std::string const& a) { return a == "heal" || a == "mana" || a == "heal_both" || a == "repair"; }

    // -- aura helpers ----------------------------------------------------------

    void ApplyOwned(Player* player, uint32 spellId)
    {
        if (spellId && !player->HasAura(spellId))
            player->AddAura(spellId, player);
    }
    void RemoveOwned(Player* player, uint32 spellId)
    {
        if (spellId)
            player->RemoveAurasDueToSpell(spellId);
    }

    // =========================================================================
    // cond:<state>[:n]
    // =========================================================================
    class Cond : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _state = r.Word();
            static char const* const noArg[] = { "shield", "twohand", "dualwield", "unarmed", "solo", "night", "day",
                                                 "dawn_dusk", "combat", "nocombat", "rested", "water" };
            bool ok = false;
            for (char const* s : noArg)
                if (_state == s)
                    ok = true;
            if (ok)
                ; // nothing expected before the optional trailers below
            else if (_state == "still" || _state == "mounted")
                ok = r.Int(1, 3600, _n) || (error = _state + " expects the seconds", false);
            else if (_state == "hp_below" || _state == "hp_above" || _state == "mana_below")
                ok = r.Int(1, 100, _n) || (error = _state + " expects a percentage", false);
            else if (_state == "gold_above")
                ok = r.Int(1, 2000000000, _n) || (error = "gold_above expects an amount of copper", false);
            else if (_state == "hour")
                ok = r.Int(0, 23, _n) && r.Int(0, 24, _m) || (error = "hour expects from and to", false);
            else
            {
                error = "unknown state \"" + _state + "\"";
                return false;
            }
            if (!ok)
                return false;
            // Optional: "stacks:<k>" -- one stack per period of the state
            // (still:5:stacks:5 = a stack every 5 s of standing still, up to 5);
            // or "tick:<sec>:<action>:<n>" -- while the state holds, every sec
            // seconds, the action (heal, mana, heal_both, repair) with n.
            while (!r.End())
            {
                std::string const word = r.Word();
                if (word == "stacks" && r.Int(2, 100, _stacks))
                    continue;
                if (word == "tick" && r.Int(1, 3600, _tickEvery))
                {
                    _tickAction = r.Word();
                    if (SmallKind(_tickAction) && r.Int(1, 100000, _tickN))
                        continue;
                }
                // sp:<pct> -- the aura's figure is a percentage of the spell
                // power the player has, recomputed while the state holds.
                if (word == "sp" && r.Int(1, 1000, _spPct))
                    continue;
                error = "after the state, only stacks:<k>, tick:<sec>:<action>:<n> or sp:<pct> may follow";
                return false;
            }
            return true;
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _stillSince = 0; Check(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); }
        void OnTick(Player* player) override
        {
            Check(player);
            if (_tickEvery && player->HasAura(_spellId) && ++_ticked >= uint32(_tickEvery))
            {
                _ticked = 0;
                SmallAction(player, _tickAction, _tickN, _spellId);
            }
        }
        void OnEnterCombat(Player* player) override { Check(player); }
        void OnLeaveCombat(Player* player) override { Check(player); }

    private:
        bool Holds(Player* player)
        {
            if (_state == "shield") return HasShield(player);
            if (_state == "twohand") return HasTwoHand(player);
            if (_state == "dualwield") return DualWields(player);
            if (_state == "unarmed") return Unarmed(player);
            if (_state == "solo") return !player->GetGroup();
            if (_state == "night") return IsNight();
            if (_state == "day") { int h = LocalHour(); return h >= 6 && h < 21; }
            if (_state == "dawn_dusk") { int h = LocalHour(); return (h >= 5 && h < 7) || (h >= 19 && h < 21); }
            if (_state == "combat") return player->IsInCombat();
            if (_state == "nocombat") return !player->IsInCombat();
            if (_state == "rested") return player->HasPlayerFlag(PLAYER_FLAGS_RESTING);
            if (_state == "water") return player->IsInWater();
            if (_state == "hp_below") return player->GetHealthPct() < float(_n);
            if (_state == "hp_above") return player->GetHealthPct() > float(_n);
            if (_state == "mana_below") return player->GetPowerPct(POWER_MANA) < float(_n);
            if (_state == "gold_above") return player->GetMoney() > uint32(_n);
            if (_state == "hour") { int h = LocalHour(); return h >= _n && h < _m; }
            if (_state == "mounted")
            {
                uint32 const now = uint32(GameTime::GetGameTime().count());
                if (!player->IsMounted()) { _stillSince = 0; return false; }
                if (!_stillSince) _stillSince = now;
                return now - _stillSince >= uint32(_n);
            }
            if (_state == "still")
            {
                uint32 const now = uint32(GameTime::GetGameTime().count());
                float const x = player->GetPositionX(), y = player->GetPositionY();
                if (!_stillSince || std::fabs(x - _x) > 0.1f || std::fabs(y - _y) > 0.1f)
                {
                    _stillSince = now; _x = x; _y = y;
                }
                return now - _stillSince >= uint32(_n);
            }
            return false;
        }
        void Check(Player* player)
        {
            if (!Holds(player))
            {
                RemoveOwned(player, _spellId);
                _applied = 0;
                return;
            }
            if (_spPct)
            {
                // A figure read from the player's own spell power: the aura is
                // cast again whenever that figure moves.
                int32 const current = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)) - _applied;
                int32 const bonus = int32(std::llround(double(current) * _spPct / 100.0));
                if (bonus != _applied || !player->HasAura(_spellId))
                {
                    RemoveOwned(player, _spellId);
                    _applied = bonus;
                    // The aura is there while the state holds, even at nothing:
                    // a character with no spell power still sees the condition
                    // met. The figure passed is one short, the spell's die side
                    // adding the last point (as the generator writes them).
                    int32 const bp = bonus - 1;
                    player->CastCustomSpell(player, _spellId, &bp, &bp, nullptr, true);
                }
                return;
            }
            ApplyOwned(player, _spellId);
            if (_stacks > 1 && _n > 0)
            {
                // One stack per period held, from the first at the threshold.
                uint32 const now = uint32(GameTime::GetGameTime().count());
                uint32 const held = _stillSince ? now - _stillSince : 0;
                int32 const want = std::min<int32>(_stacks, std::max<int32>(1, int32(held / uint32(_n))));
                if (Aura* aura = player->GetAura(_spellId))
                    if (int32(aura->GetStackAmount()) != want)
                        aura->SetStackAmount(uint8(want));
            }
        }
        std::string _state, _tickAction;
        int32 _n = 0, _m = 0, _stacks = 1, _tickEvery = 0, _tickN = 0, _spPct = 0, _applied = 0;
        uint32 _ticked = 0;
        uint32 _stillSince = 0;
        float _x = 0, _y = 0;
    };

    // =========================================================================
    // proc:<event>:<chance>:<icd>:<action>[:<params>][:trigger:<spell>][:cost:<kind>:<n>]
    // =========================================================================
    class Proc : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _event = r.Word();
            static char const* const plain[] = { "kill", "kill_boss", "kill_elite", "kill_humanoid", "hit", "hit_melee",
                                                 "hit_spell", "dmg_taken", "dmg_taken_phys", "dmg_taken_magic", "spell_cast",
                                                 "spell_cast_dmg", "spell_cast_heal",
                                                 "spell_crit_fire",
                                                 "heal", "heal_ally", "enter_combat", "leave_combat", "levelup", "resurrect",
                                                 "zone", "quest", "hourly", "loot_gold",
                                                 "crit", "spell_crit", "heal_crit", "dodge", "parry", "block", "crit_taken", "miss" };
            bool known = false;
            for (char const* e : plain)
                if (_event == e) known = true;
            if (_event == "tick" || _event == "every" || _event == "hp_below" || _event == "mana_below"
                || _event == "spell_cast_school")
            {
                known = true;
                if (!r.Int(1, 86400, _eventN)) { error = _event + " expects a number"; return false; }
            }
            if (!known) { error = "unknown event \"" + _event + "\""; return false; }
            if (!r.Int(0, 100, _chance) || !r.Int(0, 86400, _icd)) { error = "expects the chance then the cooldown"; return false; }
            _action = r.Word();
            bool ok = true;
            std::string const& A = _action;
            if (A == "cost_next")
            {
                if (!r.Int(1, 100, _a)) { error = "cost_next expects the percentage"; return false; }
            }
            else if (A == "burn")
            {
                if (!r.Int(1, 3600, _a) || !r.Int(1, 1000, _b)) { error = "burn expects the seconds then the share"; return false; }
            }
            else if (A == "none" || A == "restore" || A == "recast" || A == "repair_all" || A == "next_crit" || A == "next_sure")
                ok = true;
            else if (A == "aura" || A == "aura_target")
                ok = r.Int(0, 86400, _a) && r.Int(1, 100, _b);
            else if (A == "aura_group")
                ok = r.Int(1, 86400, _a) && r.Int(1, 100, _b);
            else if (A == "heal" || A == "mana" || A == "heal_both" || A == "leech" || A == "reflect" || A == "copper_per_damage"
                     || A == "free_next" || A == "cooldowns" || A == "reset_cooldowns" || A == "repair" || A == "gold_mult"
                     || A == "immune_snare" || A == "root" || A == "stun" || A == "disorient" || A == "fear" || A == "sleep"
                     || A == "silence" || A == "knockback")
                ok = r.Int(1, 100000, _a);
            else if (A == "gold_level" || A == "silver_level")
                ok = r.Int(1, 100000000, _a);
            else if (A == "shield_self" || A == "shield_target" || A == "splash" || A == "cleave" || A == "explode"
                     || A == "heal_group" || A == "heal_ally_amount" || A == "heal_pet" || A == "bleed" || A == "blink")
                ok = r.Int(1, 10000, _a) && r.Int(0, 10000, _b);
            else if (A == "shield_ally" || A == "shield_group" || A == "damage_sp" || A == "damage_ap" || A == "extra"
                     || A == "explode_sp")
                ok = r.Int(1, 10000, _a) && r.Int(0, 10000, _b) && (r.OptInt(0, 10000, _c) || true);
            else
            {
                error = "unknown action \"" + A + "\"";
                return false;
            }
            if (!ok) { error = A + ": bad parameters"; return false; }
            // Trailers, in any order: trigger:<spell>, cost:<kind>:<n>.
            while (!r.End())
            {
                std::string const word = r.Word();
                if (word == "trigger" && r.Int(int32(STELLAR_TAROT_TRIGGER_FIRST), int32(STELLAR_TAROT_TRIGGER_LAST), _trigger))
                    continue;
                if (word == "cost")
                {
                    _costKind = r.Word();
                    if (CostKind(_costKind) && r.Int(1, 100000, _costN))
                        continue;
                }
                if (word == "night" && r.Int(1, 100000, _nightA))
                    continue;
                if (word == "onlynight")
                {
                    _onlyNight = true;
                    continue;
                }
                error = "after the action, only trigger:<spell>, cost:<kind>:<n>, night:<n> or onlynight may follow";
                return false;
            }
            return true;
        }
        // A state the level's spell shows while it lasts: the module does not
        // apply that spell itself.
        bool State() const
        {
            return _action == "next_crit" || _action == "next_sure" || _action == "free_next" || _action == "cost_next";
        }
        bool OwnsAura() const override { return _action == "aura" || _action == "aura_target" || _action == "aura_group" || State(); }
        void Apply(Player* player) override
        {
            _last = 0; _wasBelow = false; _elapsed = 0; _freeLeft = 0; _nextCrit = false; _nextSure = false;
            _armedAt = 0;
            if (_trigger)
                ApplyOwned(player, uint32(_trigger));
        }
        void Remove(Player* player) override
        {
            if (_action == "aura" || State()) RemoveOwned(player, _spellId);
            if (_trigger) RemoveOwned(player, uint32(_trigger));
        }

        void OnTick(Player* player) override
        {
            if (_event == "tick")
            {
                if (!player->IsInCombat()) { _elapsed = 0; return; }
                if (++_elapsed >= uint32(_eventN)) { _elapsed = 0; Fire(player, nullptr, 0); }
            }
            else if (_event == "every")
            {
                if (++_elapsed >= uint32(_eventN)) { _elapsed = 0; Fire(player, nullptr, 0); }
            }
            else if (_event == "hp_below" || _event == "mana_below")
            {
                float const pct = _event == "hp_below" ? player->GetHealthPct() : player->GetPowerPct(POWER_MANA);
                bool const below = pct < float(_eventN);
                if (below && !_wasBelow)
                    Fire(player, player->GetVictim(), 0);
                _wasBelow = below;
            }
            else if (_event == "hourly")
            {
                if (++_elapsed >= 3600) { _elapsed = 0; Fire(player, nullptr, 0); }
            }
        }
        void OnCreatureKill(Player* player, Creature* killed) override
        {
            if (_event == "kill" || (_event == "kill_boss" && IsBoss(killed)) || (_event == "kill_elite" && IsElite(killed))
                || (_event == "kill_humanoid" && killed && killed->GetCreatureType() == CREATURE_TYPE_HUMANOID))
                Fire(player, killed, killed ? killed->GetMaxHealth() : 0);
        }
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool spell, uint32 /*school*/,
                           uint32 /*spellId*/) override
        {
            // Kept for the markers, which the core fires just after the blow.
            if (victim && damage)
            {
                _lastVictim = victim->GetGUID();
                _lastAmount = damage;
            }
            if (_event == "hit" || (_event == "hit_melee" && !spell) || (_event == "hit_spell" && spell))
                Fire(player, victim, damage);
        }
        void OnDamageTaken(Player* player, Unit* attacker, uint32& damage, bool spell, uint32 /*school*/,
                           uint32 /*spellId*/) override
        {
            if (_event == "dmg_taken" || (_event == "dmg_taken_phys" && !spell) || (_event == "dmg_taken_magic" && spell))
                Fire(player, attacker, damage);
        }
        void OnHealDone(Player* player, Unit* target, uint32& gain) override
        {
            if (gInsideHeal)
                return;
            if (_event == "heal" || (_event == "heal_ally" && target != player))
                Fire(player, target, gain);
        }
        // A spell the player casts himself -- or a MARKER the core's proc
        // system casts for him: the event it stands for. A free cast granted
        // earlier is refunded here.
        void OnSpellCast(Player* player, Spell* spell) override
        {
            uint32 const id = spell->GetSpellInfo()->Id;
            if (id >= STELLAR_TAROT_MARKER_FIRST && id <= STELLAR_TAROT_MARKER_LAST)
            {
                static char const* const markers[] = { "crit", "spell_crit", "heal_crit", "dodge", "parry", "block",
                                                      "crit_taken", "miss", "spell_crit_fire", "" };
                if (_event == markers[id - STELLAR_TAROT_MARKER_FIRST])
                {
                    // The marker comes right after the blow that fired it: the
                    // unit struck and the figure struck for are the ones the
                    // damage hook has just seen.
                    Unit* struck = _lastVictim ? ObjectAccessor::GetUnit(*player, _lastVictim) : nullptr;
                    Fire(player, struck ? struck : spell->m_targets.GetUnitTarget(), _lastAmount);
                }
                return;
            }
            if (spell->IsTriggered())
                return;
            SpellInfo const* const info = spell->GetSpellInfo();
            // The free cast: the state's own aura takes the cost away (-100%),
            // so the spell is already free; the state goes when it is used.
            if (_action == "free_next" && _freeLeft > 0)
            {
                if (!player->HasAura(_spellId))
                    _freeLeft = 0;                               // the state ran out
                else if (info->ManaCost > 0 || info->ManaCostPercentage > 0)
                {
                    if (--_freeLeft <= 0)
                    {
                        _freeLeft = 0;
                        RemoveOwned(player, _spellId);
                    }
                }
            }
            // The next spell at a lower cost: the state goes when it is used.
            if (_action == "cost_next" && player->HasAura(_spellId)
                && (info->ManaCost > 0 || info->ManaCostPercentage > 0))
                RemoveOwned(player, _spellId);
            bool fires = _event == "spell_cast";
            if (_event == "spell_cast_school")
                fires = (info->GetSchoolMask() & uint32(_eventN)) != 0;
            else if (_event == "spell_cast_dmg")
                fires = !info->IsPositive();
            else if (_event == "spell_cast_heal")
                fires = info->HasEffect(SPELL_EFFECT_HEAL) || info->HasEffect(SPELL_EFFECT_HEAL_PCT)
                        || info->HasEffect(SPELL_EFFECT_HEAL_MAX_HEALTH);
            if (fires)
            {
                _lastCast = spell;
                Fire(player, spell->m_targets.GetUnitTarget(), 0);
                _lastCast = nullptr;
            }
        }
        void OnEnterCombat(Player* player) override { if (_event == "enter_combat") Fire(player, player->GetVictim(), 0); }
        void OnLeaveCombat(Player* player) override { if (_event == "leave_combat") Fire(player, nullptr, 0); }
        void OnLevelUp(Player* player) override { if (_event == "levelup") Fire(player, nullptr, 0); }
        void OnResurrect(Player* player) override { if (_event == "resurrect") Fire(player, nullptr, 0); }
        void OnZone(Player* player, uint32 /*zone*/, uint32 /*area*/) override { if (_event == "zone") Fire(player, nullptr, 0); }
        void OnQuestComplete(Player* player, Quest const* /*quest*/) override { if (_event == "quest") Fire(player, nullptr, 0); }
        // The gold of a loot, before it is taken: gold_mult multiplies it.
        void OnLootMoney(Player* player, uint32& copper) override
        {
            if (_event != "loot_gold" || _action != "gold_mult" || !Ready(player))
                return;
            copper = uint32(std::min<uint64>(uint64(copper) * uint64(_a), 2000000000ULL));
            Pay(player);
        }
        void OnMeleeRoll(Player* player, Unit* /*victim*/, int32& crit, int32& miss, int32& dodge, int32& parry, int32& block) override
        {
            if (!_nextCrit && !_nextSure)
                return;
            // Unit::CalculateMeleeDamage hands the damage to the scripts BEFORE
            // it rolls the swing's outcome: a state a hit has just armed would
            // be spent by that very swing, the aura gone before it is seen. It
            // waits for the next swing -- a later world tick.
            if (_armedAt == uint32(GameTime::GetGameTimeMS().count()))
                return;
            bool const held = player->HasAura(_spellId);         // the state ran out with its aura
            // The chances are in hundredths of a percent (RollMeleeOutcomeAgainst).
            if (_nextCrit && held) { crit = 10000; miss = 0; }
            if (_nextSure && held) { dodge = 0; parry = 0; block = 0; miss = 0; }
            _nextCrit = false; _nextSure = false;
            RemoveOwned(player, _spellId);
        }

    private:
        // The chance and the cooldown, without firing.
        bool Ready(Player* player)
        {
            if (!player->IsAlive() && _action != "restore")
                return false;
            if (_onlyNight && !IsNight())
                return false;
            uint32 const now = uint32(GameTime::GetGameTime().count());
            if (_icd && _last && now - _last < uint32(_icd))
                return false;
            if (_chance < 100 && int32(urand(1, 100)) > _chance)
                return false;
            _last = now;
            return true;
        }
        void Pay(Player* player)
        {
            if (!_costKind.empty())
                Cost(player, _costKind, _costN, _spellId);
        }
        void Fire(Player* player, Unit* other, uint32 amount)
        {
            if (!Ready(player))
                return;
            // The night figure stands in for the action's own while it lasts.
            int32 const day = _a;
            if (_nightA && IsNight())
                _a = _nightA;
            Do(player, other, amount);
            _a = day;
            Pay(player);
        }
        void Do(Player* player, Unit* other, uint32 amount)
        {
            std::string const& A = _action;
            if (A == "none")
                return;
            if (A == "aura" || A == "aura_target")
            {
                Unit* who = A == "aura" ? player : other;
                if (!who || !who->IsAlive())
                    return;
                Aura* aura = who->GetAura(_spellId, player->GetGUID());
                if (!aura)
                    aura = player->AddAura(_spellId, who);
                else if (_b > 1 && aura->GetStackAmount() < uint8(_b))
                    aura->ModStackAmount(1);
                if (aura && _a)
                {
                    aura->SetMaxDuration(_a * 1000);
                    aura->SetDuration(_a * 1000);
                }
            }
            else if (A == "aura_group")
            {
                for (Player* member : GroupAround(player, float(_b)))
                    if (Aura* aura = player->AddAura(_spellId, member))
                    {
                        aura->SetMaxDuration(_a * 1000);
                        aura->SetDuration(_a * 1000);
                    }
            }
            else if (A == "heal") Heal(player, player, PctOf(player->GetMaxHealth(), _a), _spellId);
            else if (A == "mana") Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), _a), _spellId);
            else if (A == "heal_both")
            {
                Heal(player, player, PctOf(player->GetMaxHealth(), _a), _spellId);
                Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), _a), _spellId);
            }
            else if (A == "restore")
            {
                player->SetHealth(player->GetMaxHealth());
                player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));
            }
            else if (A == "leech") Heal(player, player, PctOf(amount, _a), _spellId);
            else if (A == "heal_group")
            {
                for (Player* member : GroupAround(player, float(_b)))
                    Heal(player, member, PctOf(member->GetMaxHealth(), _a), _spellId);
            }
            else if (A == "heal_ally_amount")
            {
                // The most injured group member in range, the healed one left out.
                Player* pick = nullptr;
                for (Player* member : GroupAround(player, float(_b)))
                    if (member != other && (!pick || member->GetHealthPct() < pick->GetHealthPct()))
                        pick = member;
                if (pick)
                    Heal(player, pick, PctOf(amount, _a), _spellId);
            }
            else if (A == "heal_pet")
            {
                if (Pet* pet = player->GetPet())
                    Heal(player, pet, PctOf(pet->GetMaxHealth(), _a), _spellId);
                Heal(player, player, PctOf(player->GetMaxHealth(), _b), _spellId);
            }
            else if (A == "gold_level") player->ModifyMoney(int32(uint64(_a) * player->GetLevel()));
            else if (A == "silver_level") player->ModifyMoney(int32(uint64(_a) * 100 * player->GetLevel()));
            else if (A == "copper_per_damage") player->ModifyMoney(int32(std::min<uint64>(uint64(amount) * uint64(_a), 100000000ULL)));
            else if (A == "shield_self" || A == "shield_target")
            {
                int32 const bp = int32(A == "shield_self" ? PctOf(player->GetMaxHealth(), _a) : PctOf(amount, _a));
                Unit* who = A == "shield_self" ? player : other;
                if (bp > 0)
                    Put(player, who, STELLAR_TAROT_SPELL_SHIELD, _b ? _b : 15, &bp);
            }
            else if (A == "shield_ally" || A == "shield_group")
            {
                int32 const sec = _c ? _c : 15;
                if (A == "shield_group")
                {
                    for (Player* member : GroupAround(player, float(_b)))
                    {
                        int32 const bp = int32(PctOf(member->GetMaxHealth(), _a));
                        Put(player, member, STELLAR_TAROT_SPELL_SHIELD, sec, &bp);
                    }
                }
                else
                {
                    Player* pick = nullptr;
                    for (Player* member : GroupAround(player, float(_b)))
                        if (member != player && (!pick || member->GetHealthPct() < pick->GetHealthPct()))
                            pick = member;
                    if (pick)
                    {
                        int32 const bp = int32(PctOf(pick->GetMaxHealth(), _a));
                        Put(player, pick, STELLAR_TAROT_SPELL_SHIELD, sec, &bp);
                    }
                }
            }
            else if (A == "reflect") Hurt(player, other, PctOf(amount, _a), 1, _spellId);
            else if (A == "extra") Hurt(player, other, PctOf(amount, _a), uint32(_b), _spellId);
            else if (A == "damage_sp" || A == "damage_ap")
            {
                uint32 const base = A == "damage_sp" ? uint32(std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)))
                                                     : uint32(player->GetTotalAttackPowerValue(BASE_ATTACK));
                Hurt(player, other, PctOf(base, _a), uint32(_b), _spellId);
            }
            else if (A == "splash" || A == "explode" || A == "explode_sp")
            {
                if (!other)
                    return;
                uint32 dmg = 0;
                if (A == "splash") dmg = PctOf(amount, _a);
                else if (A == "explode") dmg = PctOf(amount, _a);           // amount = the victim's max health on a kill
                else dmg = PctOf(uint32(std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC))), _a);
                uint32 const school = A == "explode_sp" ? uint32(_c ? _c : 64) : 1;
                if (A == "explode" && other->IsCreature() && IsBoss(other->ToCreature()))
                    return;
                player->CastSpell(player, school == 1 ? STELLAR_TAROT_SPELL_VISUAL_PHYS : STELLAR_TAROT_SPELL_VISUAL_MAGIC, true);
                for (Unit* unit : HostilesAround(player, other, float(_b), other))
                    Hurt(player, unit, dmg, school, _spellId);
            }
            else if (A == "cleave")
            {
                for (Unit* unit : HostilesAround(player, player, float(_b), other))
                    if (player->HasInArc(float(M_PI), unit))
                        Hurt(player, unit, PctOf(amount, _a), 1, _spellId);
            }
            else if (A == "root") Put(player, other, STELLAR_TAROT_SPELL_ROOT, _a);
            else if (A == "stun") Put(player, other, STELLAR_TAROT_SPELL_STUN, _a);
            else if (A == "disorient") Put(player, other, STELLAR_TAROT_SPELL_DISORIENT, _a);
            else if (A == "fear") Put(player, other, STELLAR_TAROT_SPELL_FEAR, _a);
            else if (A == "sleep") Put(player, other, STELLAR_TAROT_SPELL_SLEEP, _a);
            else if (A == "silence") Put(player, other, STELLAR_TAROT_SPELL_SILENCE, _a);
            else if (A == "immune_snare") Put(player, player, STELLAR_TAROT_SPELL_IMMUNE_SNARE, _a);
            else if (A == "bleed")
            {
                int32 const perTick = int32(PctOf(uint32(player->GetTotalAttackPowerValue(BASE_ATTACK)), _b));
                if (perTick > 0)
                    Put(player, other, STELLAR_TAROT_SPELL_BLEED, _a, &perTick);
            }
            else if (A == "burn")
            {
                // A share of the blow, spread over the ticks of two seconds.
                // La part vaut pour CHAQUE tic, et jamais moins d'un point.
                int32 const perTick = std::max(1, int32(PctOf(amount, _b)));
                Put(player, other, STELLAR_TAROT_SPELL_BURN, _a, &perTick);
            }
            else if (A == "knockback")
            {
                if (other && other->IsAlive())
                    other->KnockbackFrom(player->GetPositionX(), player->GetPositionY(), float(_a) * 2.0f, 5.0f);
            }
            else if (A == "blink")
            {
                // _b: 0 backwards, 1 a random direction
                float const angle = _b ? frand(0.0f, float(2 * M_PI)) : float(M_PI);
                Position pos = player->GetNearPosition(float(_a), angle);
                player->NearTeleportTo(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(), player->GetOrientation());
            }
            else if (A == "free_next") { _freeLeft = _a; Put(player, player, _spellId, 20); }
            else if (A == "cost_next") Put(player, player, _spellId, 20);
            else if (A == "next_crit" || A == "next_sure")
            {
                if (A == "next_crit") _nextCrit = true; else _nextSure = true;
                _armedAt = uint32(GameTime::GetGameTimeMS().count());
                Put(player, player, _spellId, 20);
            }
            else if (A == "recast")
            {
                if (_lastCast && _lastCast->GetSpellInfo())
                    player->CastSpell(other ? other : player, _lastCast->GetSpellInfo()->Id, true);
            }
            else if (A == "cooldowns")
            {
                std::vector<uint32> ids;
                for (auto const& [spellId, cd] : player->GetSpellCooldownMap())
                    ids.push_back(spellId);
                for (uint32 spellId : ids)
                    player->ModifySpellCooldown(spellId, -_a * 1000);
            }
            else if (A == "reset_cooldowns")
            {
                uint32 const now = GameTime::GetGameTimeMS().count();
                std::vector<uint32> ids;
                for (auto const& [spellId, cd] : player->GetSpellCooldownMap())
                    if (cd.end > now && cd.end - now <= uint32(_a) * 1000)
                        ids.push_back(spellId);
                for (uint32 spellId : ids)
                    player->RemoveSpellCooldown(spellId, true);
            }
            else if (A == "repair") Mend(player, uint32(_a));
            else if (A == "repair_all") player->DurabilityRepairAll(false, 0.0f, false);
        }
        std::string _event, _action, _costKind;
        int32 _eventN = 0, _chance = 100, _icd = 0, _a = 0, _b = 0, _c = 0, _trigger = 0, _costN = 0, _freeLeft = 0;
        int32 _nightA = 0;
        bool _onlyNight = false;
        ObjectGuid _lastVictim;
        uint32 _lastAmount = 0;
        uint32 _last = 0, _elapsed = 0, _armedAt = 0;
        bool _wasBelow = false, _nextCrit = false, _nextSure = false;
        Spell* _lastCast = nullptr;
    };

    // =========================================================================
    // dmgmod:<target condition>[:n]:<pct>
    // =========================================================================
    class DmgMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _cond = r.Word();
            static char const* const plain[] = { "stunned", "alone", "full_hp", "humanoid", "slowed", "burning" };
            bool known = false;
            for (char const* c : plain)
                if (_cond == c) known = true;
            if (_cond == "hp_above" || _cond == "hp_below" || _cond == "range_over")
            {
                known = true;
                if (!r.Int(1, 100, _n)) { error = _cond + " expects a number"; return false; }
            }
            if (!known) { error = "unknown target condition \"" + _cond + "\""; return false; }
            if (!r.Int(-100, 100000, _pct))
                return (error = "expects the percentage", false);
            // l'école, facultative : 0 ou absente, toutes les écoles
            r.OptInt(0, 127, _school);
            return r.End() || (error = "after the percentage, only the school may follow", false);
        }
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool /*spell*/, uint32 school,
                           uint32 spellId) override
        {
            if (_school && !(school & uint32(_school)))
                return;
            if (victim && Meets(player, victim, spellId))
                damage = uint32(std::llround(double(damage) * (100 + _pct) / 100.0));
        }
    private:
        int32 _school = 0;

        // An aura born within the second of the blow being counted: the blow
        // laid it itself. The hour of an aura is fixed at its creation and a
        // renewal does not move it.
        static bool JustLaid(AuraEffect const* eff)
        {
            Aura const* aura = eff->GetBase();
            return aura && aura->GetApplyTime() >= GameTime::GetGameTime().count();
        }

        bool Meets(Player* player, Unit* v, uint32 /*spellId*/ = 0)
        {
            // « Cible étourdie » : toute immobilisation -- étourdissement,
            // renversement (un étourdissement lui aussi) et enracinement --
            // mais jamais un simple ralentissement.
            if (_cond == "stunned")
                return v->HasUnitState(UNIT_STATE_STUNNED) || v->HasUnitState(UNIT_STATE_ROOT)
                    || v->HasAuraType(SPELL_AURA_MOD_STUN) || v->HasAuraType(SPELL_AURA_MOD_ROOT);
            if (_cond == "alone") return v->getAttackers().size() <= 1;
            if (_cond == "full_hp") return v->GetHealth() >= v->GetMaxHealth();
            if (_cond == "hp_above") return v->GetHealthPct() > float(_n);
            if (_cond == "hp_below") return v->GetHealthPct() < float(_n);
            if (_cond == "humanoid") return v->GetCreatureType() == CREATURE_TYPE_HUMANOID;
            if (_cond == "range_over") return player->GetDistance(v) > float(_n);
            if (_cond == "slowed")
            {
                for (AuraEffect const* eff : v->GetAuraEffectsByType(SPELL_AURA_MOD_DECREASE_SPEED))
                    if (!JustLaid(eff))
                        return true;
                return v->HasUnitState(UNIT_STATE_ROOT);
            }
            if (_cond == "burning")
            {
                for (AuraEffect const* eff : v->GetAuraEffectsByType(SPELL_AURA_PERIODIC_DAMAGE))
                {
                    if (!(eff->GetSpellInfo()->GetSchoolMask() & SPELL_SCHOOL_MASK_FIRE))
                        continue;
                    // A spell lays its aura before its damage is counted, so a
                    // burn born of this very blow does not pay for itself. One
                    // laid earlier does, even when this blow renews it.
                    if (JustLaid(eff))
                        continue;
                    return true;
                }
                return false;
            }
            return false;
        }
        std::string _cond;
        int32 _n = 0, _pct = 0;
    };

    // =========================================================================
    // takenmod:<condition>:<pct>
    // =========================================================================
    class TakenMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _cond = r.Word();
            if (_cond != "alone" && _cond != "controlled") { error = "unknown condition \"" + _cond + "\""; return false; }
            if (!r.Int(-100, 1000, _pct))
                return (error = "expects the percentage", false);
            r.OptInt(0, 127, _school);
            return r.End() || (error = "after the percentage, only the school may follow", false);
        }
        void OnDamageTaken(Player* player, Unit* /*attacker*/, uint32& damage, bool /*spell*/, uint32 school,
                           uint32 /*spellId*/) override
        {
            if (_school && !(school & uint32(_school)))
                return;
            bool meets = false;
            if (_cond == "alone") meets = player->getAttackers().size() <= 1;
            if (_cond == "controlled") meets = player->HasUnitState(UNIT_STATE_STUNNED | UNIT_STATE_ROOT | UNIT_STATE_FLEEING | UNIT_STATE_CONFUSED);
            if (meets)
                damage = uint32(std::llround(double(damage) * (100 + _pct) / 100.0));
        }
    private:
        std::string _cond;
        int32 _pct = 0, _school = 0;
    };

    // =========================================================================
    // sp_pct:<pct>  -- the level's spell: MOD_DAMAGE_DONE (magic) + MOD_HEALING_DONE
    // =========================================================================
    class SpellPowerPct : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 1000, _pct))
                return (error = "expects the percentage", false);
            // night:<pct> -- the percentage the night takes over with
            if (!r.End())
            {
                if (r.Word() != "night" || !r.Int(1, 1000, _night) || !r.End())
                    return (error = "after the percentage, only night:<pct> may follow", false);
            }
            return true;
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _applied = 0; Recompute(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); _applied = 0; }
        void OnTick(Player* player) override { Recompute(player); }
    private:
        void Recompute(Player* player)
        {
            int32 const pct = (_night && IsNight()) ? _night : _pct;
            int32 const current = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)) - _applied;
            int32 const bonus = int32(std::llround(double(current) * pct / 100.0));
            if (bonus == _applied && player->HasAura(_spellId))
                return;
            RemoveOwned(player, _spellId);
            _applied = bonus;
            int32 const bp = bonus - 1;         // the spell's die side adds the last point
            player->CastCustomSpell(player, _spellId, &bp, &bp, nullptr, true);
        }
        int32 _pct = 0, _night = 0, _applied = 0;
    };

    // =========================================================================
    // stat:<day>:<night>
    //     The level's aura, at the figure the hour calls for: every effect of
    //     the spell is given that figure, recast when the hour changes it.
    // =========================================================================
    class NightStat : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(-1000, 1000, _day) && r.Int(-1000, 1000, _night) && r.End())
                || (error = "expects the figure by day then by night", false);
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _has = false; Check(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); _has = false; }
        void OnTick(Player* player) override { Check(player); }

    private:
        void Check(Player* player)
        {
            int32 const want = IsNight() ? _night : _day;
            if (_has && want == _applied && player->HasAura(_spellId))
                return;
            RemoveOwned(player, _spellId);
            _applied = want;
            _has = true;
            // One short: the spell's die side adds the last point, the way the
            // generator writes every figure.
            int32 const bp = want - 1;
            player->CastCustomSpell(player, _spellId, &bp, &bp, &bp, true);
        }
        int32 _day = 0, _night = 0, _applied = 0;
        bool _has = false;
    };

    // =========================================================================
    // costmod:heal_low:<hp percent>:<discount percent>
    // =========================================================================
    class CostMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _kind = r.Word();
            if (_kind != "heal_low")
            {
                error = "unknown kind \"" + _kind + "\"";
                return false;
            }
            return (r.Int(1, 100, _hp) && r.Int(1, 100, _pct) && r.End())
                || (error = "expects the share of health then the discount", false);
        }
        void OnSpellCast(Player* player, Spell* spell) override
        {
            SpellInfo const* const info = spell->GetSpellInfo();
            if (spell->IsTriggered() || info->PowerType != POWER_MANA)
                return;
            if (!(info->HasEffect(SPELL_EFFECT_HEAL) || info->HasEffect(SPELL_EFFECT_HEAL_PCT)
                  || info->HasEffect(SPELL_EFFECT_HEAL_MAX_HEALTH)))
                return;
            Unit* const target = spell->m_targets.GetUnitTarget();
            if (!target || target->GetHealthPct() > float(_hp))
                return;
            int32 const back = int32(PctOf(uint32(std::max(0, spell->GetPowerCost())), _pct));
            if (back <= 0)
                return;
            ObjectGuid const guid = player->GetGUID();
            player->m_Events.AddEventAtOffset([guid, back]()
            {
                if (Player* p = ObjectAccessor::FindPlayer(guid))
                    p->ModifyPower(POWER_MANA, back);
            }, Milliseconds(1));
        }

    private:
        std::string _kind;
        int32 _hp = 0, _pct = 0;
    };

    // =========================================================================
    // dotlong:<school>:<ticks>
    //     A periodic effect of that school, laid by the player, lasts that many
    //     TICKS longer -- its own period, so the extra time always pays: two
    //     seconds added to a three-second period would buy nothing. Caught as
    //     the aura is applied.
    // =========================================================================
    class DotLong : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 127, _school) && r.Int(1, 20, _ticks) && r.End())
                || (error = "expects the school then the number of ticks", false);
        }
        // A spell with a travel time lays its aura long after the cast is
        // announced: the moment the aura appears is the one to catch.
        void OnAuraApplied(Player* /*player*/, Unit* /*target*/, Aura* aura) override
        {
            SpellInfo const* const info = aura->GetSpellInfo();
            if (!info || !(info->GetSchoolMask() & uint32(_school)))
                return;
            if (!info->HasAura(SPELL_AURA_PERIODIC_DAMAGE) || aura->GetMaxDuration() <= 0)
                return;
            // The period of the effect itself: a tick more means that much more.
            int32 period = 0;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (AuraEffect const* eff = aura->GetEffect(i))
                    if (eff->GetAuraType() == SPELL_AURA_PERIODIC_DAMAGE && eff->GetAmplitude() > 0)
                    {
                        period = eff->GetAmplitude();
                        break;
                    }
            if (period <= 0)
                return;
            int32 const more = period * _ticks;
            aura->SetMaxDuration(aura->GetMaxDuration() + more);
            aura->SetDuration(aura->GetDuration() + more);
        }

    private:
        int32 _school = 0, _ticks = 0;
    };

    // =========================================================================
    // tickmod:<chance>:<pct>
    // =========================================================================
    class TickMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _chance) || !r.Int(1, 1000, _pct))
                return (error = "expects the chance then the percentage", false);
            if (!r.End())
            {
                if (r.Word() != "onlynight" || !r.End())
                    return (error = "after the percentage, only onlynight may follow", false);
                _onlyNight = true;
            }
            return true;
        }
        void OnPeriodicTick(Player* /*player*/, Unit* /*other*/, uint32& amount, bool /*heal*/) override
        {
            if (!amount || (_onlyNight && !IsNight()) || int32(urand(1, 100)) > _chance)
                return;
            amount += PctOf(amount, _pct);
        }

    private:
        int32 _chance = 0, _pct = 0;
        bool _onlyNight = false;
    };

    // =========================================================================
    // econ:<kind>:<pct>
    // =========================================================================
    class Econ : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _kind = r.Word();
            static char const* const kinds[] = { "gold_loot", "xp", "rep", "quest_gold", "repair", "vendor_buy", "vendor_sell" };
            bool known = false;
            for (char const* k : kinds)
                if (_kind == k) known = true;
            if (!known) { error = "unknown kind \"" + _kind + "\""; return false; }
            return r.Int(-100, 10000, _pct) && r.End() || (error = "expects the percentage", false);
        }
        void OnLootMoney(Player* /*player*/, uint32& copper) override
        {
            if (_kind == "gold_loot") copper = uint32(std::llround(double(copper) * (100 + _pct) / 100.0));
        }
        void OnGiveXP(Player* /*player*/, uint32& amount) override
        {
            if (_kind == "xp") amount = uint32(std::llround(double(amount) * (100 + _pct) / 100.0));
        }
        void OnGiveReputation(Player* /*player*/, float& amount) override
        {
            if (_kind == "rep") amount = amount * float(100 + _pct) / 100.0f;
        }
        void OnQuestComplete(Player* player, Quest const* quest) override
        {
            if (_kind == "quest_gold" && quest)
            {
                int32 const money = quest->GetRewOrReqMoney();
                if (money > 0)
                    player->ModifyMoney(int32(std::llround(double(money) * _pct / 100.0)));
            }
        }
        void OnRepairDiscount(Player* /*player*/, float& discountMod) override
        {
            if (_kind == "repair") discountMod *= float(100 + _pct) / 100.0f;      // pct is negative for a rebate
        }
        void OnVendorDiscount(Player const* /*player*/, float& discount) override
        {
            if (_kind == "vendor_buy") discount *= float(100 + _pct) / 100.0f;
        }
        void OnSellItem(Player* /*player*/, Item* /*item*/) override
        {
            if (_kind == "vendor_sell") _selling = true;
        }
        void OnMoneyChanged(Player* /*player*/, int32& amount) override
        {
            if (_kind == "vendor_sell" && _selling && amount > 0)
            {
                amount = int32(std::llround(double(amount) * (100 + _pct) / 100.0));
                _selling = false;
            }
        }
    private:
        std::string _kind;
        int32 _pct = 0;
        bool _selling = false;
    };
}

void StellarTarotScripts::RegisterEngine()
{
    Register("cond", [] { return std::make_unique<Cond>(); });
    Register("proc", [] { return std::make_unique<Proc>(); });
    Register("dmgmod", [] { return std::make_unique<DmgMod>(); });
    Register("takenmod", [] { return std::make_unique<TakenMod>(); });
    Register("sp_pct", [] { return std::make_unique<SpellPowerPct>(); });
    Register("stat", [] { return std::make_unique<NightStat>(); });
    Register("costmod", [] { return std::make_unique<CostMod>(); });
    Register("tickmod", [] { return std::make_unique<TickMod>(); });
    Register("dotlong", [] { return std::make_unique<DotLong>(); });
    Register("econ", [] { return std::make_unique<Econ>(); });
}
