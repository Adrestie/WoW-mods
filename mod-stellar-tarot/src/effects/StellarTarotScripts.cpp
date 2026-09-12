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
 * mod-stellar-tarot — the registry of scripts, and the module's own.
 *
 * Two scripts ship as examples of the mechanism:
 *
 *   gold_on_kill:<copper>    every creature killed yields that much money
 *   heal_on_kill:<percent>   every creature killed heals that share of health
 */

#include "StellarTarotScript.h"
#include "Creature.h"
#include "Player.h"
#include <cstdlib>
#include <map>

namespace
{
    std::map<std::string, StellarTarotScripts::Factory>& Registry()
    {
        static std::map<std::string, StellarTarotScripts::Factory> registry;
        return registry;
    }

    // One whole number, and nothing else.
    bool OneNumber(std::vector<std::string> const& params, char const* what, uint32 low, uint32 high,
                   uint32& out, std::string& error)
    {
        if (params.size() != 1 || params[0].empty() || params[0].find_first_not_of("0123456789") != std::string::npos)
        {
            error = std::string("expects one whole number, the ") + what;
            return false;
        }
        unsigned long const value = std::strtoul(params[0].c_str(), nullptr, 10);
        if (value < low || value > high)
        {
            error = std::string("the ") + what + " must be between " + std::to_string(low) + " and " + std::to_string(high);
            return false;
        }
        out = uint32(value);
        return true;
    }

    // -- gold_on_kill:<copper> ------------------------------------------------
    class GoldOnKill : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            return OneNumber(params, "amount of copper", 1, 1000000000, _copper, error);
        }
        void OnCreatureKill(Player* player, Creature* /*killed*/) override
        {
            player->ModifyMoney(int32(_copper));
        }
    private:
        uint32 _copper = 0;
    };

    // -- heal_on_kill:<percent> -----------------------------------------------
    class HealOnKill : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            return OneNumber(params, "percentage of health", 1, 100, _percent, error);
        }
        void OnCreatureKill(Player* player, Creature* /*killed*/) override
        {
            if (!player->IsAlive())
                return;
            player->ModifyHealth(int32(uint64(player->GetMaxHealth()) * _percent / 100));
        }
    private:
        uint32 _percent = 0;
    };
}

void StellarTarotScripts::Register(std::string const& name, Factory factory)
{
    Registry()[name] = std::move(factory);
}

std::unique_ptr<StellarTarotScript> StellarTarotScripts::Create(StellarTarotScriptSpec const& spec, std::string& error)
{
    RegisterAll();
    auto it = Registry().find(spec.name);
    if (it == Registry().end())
    {
        error = "unknown script \"" + spec.name + "\"";
        return nullptr;
    }
    std::unique_ptr<StellarTarotScript> script = it->second();
    if (!script->Parse(spec.params, error))
    {
        error = "script \"" + spec.name + "\" " + error;
        return nullptr;
    }
    return script;
}

bool StellarTarotScripts::Check(StellarTarotScriptSpec const& spec, std::string& error)
{
    return Create(spec, error) != nullptr;
}

std::vector<std::string> StellarTarotScripts::Names()
{
    RegisterAll();
    std::vector<std::string> out;
    for (auto const& [name, factory] : Registry())
        out.push_back(name);
    return out;
}

void StellarTarotScripts::RegisterAll()
{
    static bool done = false;
    if (done)
        return;
    done = true;
    Register("gold_on_kill", [] { return std::make_unique<GoldOnKill>(); });
    Register("heal_on_kill", [] { return std::make_unique<HealOnKill>(); });
}
