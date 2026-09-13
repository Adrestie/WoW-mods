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
 *       the state, up to k (still:5:stacks:5).
 *
 *   proc:<event>:<chance>:<icd>:<action>[:<params>]
 *       On the event, with that chance (percent) and no more often than the
 *       internal cooldown (seconds), the action. Events: kill, kill_boss,
 *       kill_elite, kill_humanoid, hit, hit_melee, hit_spell, dmg_taken,
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
 *       miss come that way, as MARKER spells the core casts).
 *
 *   dmgmod:<target condition>[:n]:<pct>
 *       The damage the player deals is changed by pct when the target meets
 *       the condition: stunned, alone, hp_above:<pct>, hp_below:<pct>, full_hp,
 *       humanoid, range_over:<yards>, slowed, burning.
 *
 *   takenmod:<condition>:<pct>
 *       The damage the player takes is changed by pct: alone (one attacker),
 *       controlled (stunned, rooted, feared, confused).
 *
 *   sp_pct:<pct>
 *       The level's spell carries a flat spell power (damage and healing)
 *       recomputed every second as pct of the player's current spell power.
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
            for (char const* s : noArg)
                if (_state == s)
                    return r.End() || (error = "no parameter after " + _state, false);
            bool ok = false;
            if (_state == "still" || _state == "mounted")
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
            // (still:5:stacks:5 = a stack every 5 s of standing still, up to 5).
            if (!r.End())
            {
                if (r.Word() != "stacks" || !r.Int(2, 100, _stacks) || !r.End())
                {
                    error = "after the state, only stacks:<k> may follow";
                    return false;
                }
            }
            return true;
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _stillSince = 0; Check(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); }
        void OnTick(Player* player) override { Check(player); }
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
            if (_state == "night") { int h = LocalHour(); return h < 6 || h >= 21; }
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
        std::string _state;
        int32 _n = 0, _m = 0, _stacks = 1;
        uint32 _stillSince = 0;
        float _x = 0, _y = 0;
    };

    // =========================================================================
    // proc:<event>:<chance>:<icd>:<action>[:<params>]
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
                                                 "heal", "heal_ally", "enter_combat", "leave_combat", "levelup", "resurrect",
                                                 "zone", "quest", "hourly",
                                                 "crit", "spell_crit", "heal_crit", "dodge", "parry", "block", "crit_taken", "miss" };
            bool known = false;
            for (char const* e : plain)
                if (_event == e) known = true;
            if (_event == "tick" || _event == "every" || _event == "hp_below" || _event == "mana_below")
            {
                known = true;
                if (!r.Int(1, 86400, _eventN)) { error = _event + " expects a number"; return false; }
            }
            if (!known) { error = "unknown event \"" + _event + "\""; return false; }
            if (!r.Int(0, 100, _chance) || !r.Int(0, 86400, _icd)) { error = "expects the chance then the cooldown"; return false; }
            _action = r.Word();
            if (_action == "aura")
                return (r.Int(0, 86400, _a) && r.Int(1, 100, _b) || (error = "aura expects seconds and stacks", false)) && Trailer(r, error);
            if (_action == "heal" || _action == "mana" || _action == "heal_both" || _action == "leech")
                return (r.Int(1, 1000, _a) || (error = _action + " expects a percentage", false)) && Trailer(r, error);
            if (_action == "restore")
                return Trailer(r, error);
            if (_action == "gold_level" || _action == "silver_level")
                return (r.Int(1, 100000000, _a) || (error = _action + " expects an amount", false)) && Trailer(r, error);
            if (_action == "damage_sp" || _action == "damage_ap" || _action == "extra")
                return (r.Int(1, 10000, _a) && r.Int(1, 127, _b) || (error = _action + " expects a percentage and a school", false)) && Trailer(r, error);
            bool ok = false;
            if (_action == "root" || _action == "stun")
                ok = r.Int(1, 600, _a) || (error = _action + " expects the seconds", false);
            else if (_action == "bleed")
                ok = r.Int(1, 600, _a) && r.Int(1, 1000, _b) || (error = "bleed expects the seconds and the percent of attack power per tick", false);
            else
            {
                error = "unknown action \"" + _action + "\"";
                return false;
            }
            if (!ok)
                return false;
            return Trailer(r, error);
        }
        // After the action: an optional "trigger:<spell>", the passive aura
        // through which the core's proc system signals the event.
        bool Trailer(Reader& r, std::string& error)
        {
            if (r.End())
                return true;
            if (r.Word() != "trigger" || !r.Int(int32(STELLAR_TAROT_TRIGGER_FIRST), int32(STELLAR_TAROT_TRIGGER_LAST), _trigger) || !r.End())
            {
                error = "after the action, only trigger:<spell> may follow";
                return false;
            }
            return true;
        }
        bool OwnsAura() const override { return _action == "aura"; }
        void Apply(Player* player) override
        {
            _last = 0; _wasBelow = false; _elapsed = 0;
            if (_trigger)
                ApplyOwned(player, uint32(_trigger));
        }
        void Remove(Player* player) override
        {
            if (_action == "aura") RemoveOwned(player, _spellId);
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
                    Fire(player, nullptr, 0);
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
                Fire(player, killed, 0);
        }
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool spell) override
        {
            if (_event == "hit" || (_event == "hit_melee" && !spell) || (_event == "hit_spell" && spell))
                Fire(player, victim, damage);
        }
        void OnDamageTaken(Player* player, Unit* attacker, uint32& damage, bool spell) override
        {
            if (_event == "dmg_taken" || (_event == "dmg_taken_phys" && !spell) || (_event == "dmg_taken_magic" && spell))
                Fire(player, attacker, damage);
        }
        void OnHealDone(Player* player, Unit* target, uint32& gain) override
        {
            if (_event == "heal" || (_event == "heal_ally" && target != player))
                Fire(player, target, gain);
        }
        // A spell the player casts himself -- or a MARKER the core's proc
        // system casts for him: the event it stands for.
        void OnSpellCast(Player* player, Spell* spell) override
        {
            uint32 const id = spell->GetSpellInfo()->Id;
            if (id >= STELLAR_TAROT_MARKER_FIRST && id <= STELLAR_TAROT_MARKER_LAST)
            {
                static char const* const markers[] = { "crit", "spell_crit", "heal_crit", "dodge", "parry", "block", "crit_taken", "miss" };
                if (_event == markers[id - STELLAR_TAROT_MARKER_FIRST])
                    Fire(player, spell->m_targets.GetUnitTarget(), 0);
                return;
            }
            if (_event == "spell_cast" && !spell->IsTriggered())
                Fire(player, nullptr, 0);
        }
        void OnEnterCombat(Player* player) override { if (_event == "enter_combat") Fire(player, nullptr, 0); }
        void OnLeaveCombat(Player* player) override { if (_event == "leave_combat") Fire(player, nullptr, 0); }
        void OnLevelUp(Player* player) override { if (_event == "levelup") Fire(player, nullptr, 0); }
        void OnResurrect(Player* player) override { if (_event == "resurrect") Fire(player, nullptr, 0); }
        void OnZone(Player* player, uint32 /*zone*/, uint32 /*area*/) override { if (_event == "zone") Fire(player, nullptr, 0); }
        void OnQuestComplete(Player* player, Quest const* /*quest*/) override { if (_event == "quest") Fire(player, nullptr, 0); }

    private:
        void Fire(Player* player, Unit* other, uint32 amount)
        {
            if (!player->IsAlive() && _action != "restore")
                return;
            uint32 const now = uint32(GameTime::GetGameTime().count());
            if (_icd && _last && now - _last < uint32(_icd))
                return;
            if (_chance < 100 && int32(urand(1, 100)) > _chance)
                return;
            _last = now;
            Do(player, other, amount);
        }
        void Do(Player* player, Unit* other, uint32 amount)
        {
            if (_action == "aura")
            {
                Aura* aura = player->GetAura(_spellId);
                if (!aura)
                    aura = player->AddAura(_spellId, player);
                else if (_b > 1 && aura->GetStackAmount() < uint8(_b))
                    aura->ModStackAmount(1);
                if (aura && _a)
                {
                    aura->SetMaxDuration(_a * 1000);
                    aura->SetDuration(_a * 1000);
                }
            }
            else if (_action == "heal")
                player->ModifyHealth(int32(PctOf(player->GetMaxHealth(), _a)));
            else if (_action == "mana")
                player->ModifyPower(POWER_MANA, int32(PctOf(player->GetMaxPower(POWER_MANA), _a)));
            else if (_action == "heal_both")
            {
                player->ModifyHealth(int32(PctOf(player->GetMaxHealth(), _a)));
                player->ModifyPower(POWER_MANA, int32(PctOf(player->GetMaxPower(POWER_MANA), _a)));
            }
            else if (_action == "restore")
            {
                player->SetHealth(player->GetMaxHealth());
                player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));
            }
            else if (_action == "leech")
                player->ModifyHealth(int32(PctOf(amount, _a)));
            else if (_action == "gold_level")
                player->ModifyMoney(int32(uint64(_a) * player->GetLevel()));
            else if (_action == "silver_level")
                player->ModifyMoney(int32(uint64(_a) * 100 * player->GetLevel()));
            else if ((_action == "root" || _action == "stun") && other && other->IsAlive())
            {
                // The module's own controls: nothing breaks them but time.
                uint32 const spell = _action == "root" ? STELLAR_TAROT_SPELL_ROOT : STELLAR_TAROT_SPELL_STUN;
                if (Aura* aura = player->AddAura(spell, other))
                {
                    aura->SetMaxDuration(_a * 1000);
                    aura->SetDuration(_a * 1000);
                }
            }
            else if (_action == "bleed" && other && other->IsAlive())
            {
                // Periodic physical damage, a tick every 2 s: pct of attack power per tick.
                int32 const perTick = int32(PctOf(uint32(player->GetTotalAttackPowerValue(BASE_ATTACK)), _b));
                if (perTick > 0)
                {
                    player->CastCustomSpell(other, STELLAR_TAROT_SPELL_BLEED, &perTick, nullptr, nullptr, true);
                    if (Aura* aura = other->GetAura(STELLAR_TAROT_SPELL_BLEED, player->GetGUID()))
                    {
                        aura->SetMaxDuration(_a * 1000);
                        aura->SetDuration(_a * 1000);
                    }
                }
            }
            else if ((_action == "damage_sp" || _action == "damage_ap" || _action == "extra") && other && other->IsAlive()
                     && !gInsideDamage)
            {
                uint32 base = 0;
                if (_action == "damage_sp")
                    base = uint32(std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)));
                else if (_action == "damage_ap")
                    base = uint32(player->GetTotalAttackPowerValue(BASE_ATTACK));
                else
                    base = amount;
                uint32 const dmg = PctOf(base, _a);
                if (!dmg)
                    return;
                gInsideDamage = true;
                Unit::DealDamage(player, other, dmg, nullptr, SPELL_DIRECT_DAMAGE, SpellSchoolMask(_b), nullptr, false);
                gInsideDamage = false;
            }
        }
        std::string _event, _action;
        int32 _eventN = 0, _chance = 100, _icd = 0, _a = 0, _b = 1, _trigger = 0;
        uint32 _last = 0, _elapsed = 0;
        bool _wasBelow = false;
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
            return r.Int(-100, 1000, _pct) && r.End() || (error = "expects the percentage", false);
        }
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool /*spell*/) override
        {
            if (victim && Meets(player, victim))
                damage = uint32(std::llround(double(damage) * (100 + _pct) / 100.0));
        }
    private:
        bool Meets(Player* player, Unit* v)
        {
            if (_cond == "stunned") return v->HasUnitState(UNIT_STATE_STUNNED);
            if (_cond == "alone") return v->getAttackers().size() <= 1;
            if (_cond == "full_hp") return v->GetHealth() >= v->GetMaxHealth();
            if (_cond == "hp_above") return v->GetHealthPct() > float(_n);
            if (_cond == "hp_below") return v->GetHealthPct() < float(_n);
            if (_cond == "humanoid") return v->GetCreatureType() == CREATURE_TYPE_HUMANOID;
            if (_cond == "range_over") return player->GetDistance(v) > float(_n);
            if (_cond == "slowed") return v->HasAuraType(SPELL_AURA_MOD_DECREASE_SPEED) || v->HasUnitState(UNIT_STATE_ROOT);
            if (_cond == "burning")
            {
                for (AuraEffect const* eff : v->GetAuraEffectsByType(SPELL_AURA_PERIODIC_DAMAGE))
                    if (eff->GetSpellInfo()->GetSchoolMask() & SPELL_SCHOOL_MASK_FIRE)
                        return true;
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
            return r.Int(-100, 1000, _pct) && r.End() || (error = "expects the percentage", false);
        }
        void OnDamageTaken(Player* player, Unit* /*attacker*/, uint32& damage, bool /*spell*/) override
        {
            bool meets = false;
            if (_cond == "alone") meets = player->getAttackers().size() <= 1;
            if (_cond == "controlled") meets = player->HasUnitState(UNIT_STATE_STUNNED | UNIT_STATE_ROOT | UNIT_STATE_FLEEING | UNIT_STATE_CONFUSED);
            if (meets)
                damage = uint32(std::llround(double(damage) * (100 + _pct) / 100.0));
        }
    private:
        std::string _cond;
        int32 _pct = 0;
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
            return r.Int(1, 1000, _pct) && r.End() || (error = "expects the percentage", false);
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _applied = 0; Recompute(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); _applied = 0; }
        void OnTick(Player* player) override { Recompute(player); }
    private:
        void Recompute(Player* player)
        {
            int32 const current = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)) - _applied;
            int32 const bonus = int32(std::llround(double(current) * _pct / 100.0));
            if (bonus == _applied && player->HasAura(_spellId))
                return;
            RemoveOwned(player, _spellId);
            _applied = bonus;
            if (bonus > 0)
                player->CastCustomSpell(player, _spellId, &bonus, &bonus, nullptr, true);
        }
        int32 _pct = 0, _applied = 0;
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
    Register("econ", [] { return std::make_unique<Econ>(); });
}
