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
 * mod-stellar-tarot — the scripts a card can name.
 *
 * A spell applied as an aura covers most powers; what an aura cannot do -- a
 * thing that happens on a kill, on a loot, on a hit -- is a SCRIPT: a small
 * C++ class registered under a name, that a card names in one of its
 * `card_script_N` columns as `name` or `name:param:param`.
 *
 * ONE INSTANCE PER PLAYER AND PER ACTIVE LEVEL. The module creates it when the
 * level is reached, calls Apply, feeds it the game's events while it lives,
 * calls Remove and destroys it when the level is lost or the player logs out.
 * A script keeps whatever state it needs in its own members.
 *
 * WHAT A SCRIPT SAYS OF ITSELF is not in the code: the table
 * mod_stellar_tarot_script names, for each script, a row of module_string
 * (English) and module_string_locale, which the interface formats with the
 * script's parameters -- a description changes in the database, without a
 * rebuild. A script without a row shows its column as written.
 *
 * TO ADD A SCRIPT: derive from StellarTarotScript, register it in
 * StellarTarotScripts.cpp, add its description rows to the SQL.
 */

#ifndef MOD_STELLAR_TAROT_SCRIPT_H_
#define MOD_STELLAR_TAROT_SCRIPT_H_

#include "Define.h"
#include "StellarTarotMgr.h"
#include <functional>
#include <memory>
#include <string>
#include <vector>

class Creature;
class Player;

class StellarTarotScript
{
public:
    virtual ~StellarTarotScript() = default;

    // Reads the parameters; false, with `error` filled, when they cannot be
    // read. Called at load time to refuse a badly written card, and again on
    // every instance before Apply.
    virtual bool Parse(std::vector<std::string> const& params, std::string& error) = 0;

    virtual void Apply(Player* /*player*/) { }
    virtual void Remove(Player* /*player*/) { }

    // The game's events, while the level is active.
    virtual void OnCreatureKill(Player* /*player*/, Creature* /*killed*/) { }
};

namespace StellarTarotScripts
{
    using Factory = std::function<std::unique_ptr<StellarTarotScript>()>;

    void Register(std::string const& name, Factory factory);

    // A fresh instance with its parameters read, or nullptr with `error`.
    std::unique_ptr<StellarTarotScript> Create(StellarTarotScriptSpec const& spec, std::string& error);
    // Only says whether the spec is sound: known name, readable parameters.
    bool Check(StellarTarotScriptSpec const& spec, std::string& error);
    // The registered names, for the checks and the listings.
    std::vector<std::string> Names();

    // Makes sure every script of the module is registered.
    void RegisterAll();
}

#endif
