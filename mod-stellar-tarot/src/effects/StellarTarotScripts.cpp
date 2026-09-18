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
 * mod-stellar-tarot — the registry of scripts.
 *
 * Every family lives in StellarTarotEngine.cpp and is registered from there;
 * this file holds the registry itself and nothing else.
 */

#include "StellarTarotScript.h"
#include <map>

namespace
{
    std::map<std::string, StellarTarotScripts::Factory>& Registry()
    {
        static std::map<std::string, StellarTarotScripts::Factory> registry;
        return registry;
    }

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
    RegisterEngine();
}
