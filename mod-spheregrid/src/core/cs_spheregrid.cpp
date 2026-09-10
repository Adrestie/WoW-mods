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
 * mod-spheregrid — chat commands.
 *
 * .spheregrid info                  (SEC_GAMEMASTER)     state of the loaded definition
 * .spheregrid reload                (SEC_ADMINISTRATOR)  reloads the spheregrid_* tables
 * .spheregrid status [player]       (SEC_GAMEMASTER)     points and activations of a player
 * .spheregrid points add N [player] (SEC_ADMINISTRATOR)  credits N points
 * .spheregrid points remove N [...] (SEC_ADMINISTRATOR)  debits N points (capped)
 * .spheregrid points set N [player] (SEC_ADMINISTRATOR)  sets the AVAILABLE points to N
 * .spheregrid activate <node_id>    (SEC_PLAYER)         buys the cell, game rules applied
 * .spheregrid reset [player]        (SEC_ADMINISTRATOR)  full wipe of one character
 * .spheregrid respec                (SEC_PLAYER)         the player gives his grid back
 * .spheregrid show                  (SEC_PLAYER)         the player interface
 * .spheregrid editor                (SEC_ADMINISTRATOR)  the layout editor
 *
 * .spheregrid with no argument lists the subcommands (the core behaviour for a
 * parent command, filtered by security level). Each subcommand describes itself
 * through the `command` table: .spheregrid <sub> help.
 *
 * show and editor are INTERCEPTED by the Lua interface before they reach here:
 * their C++ handlers are only fallbacks for a server without the Lua engine,
 * and their presence in the table feeds the listing and documents the level
 * each one requires.
 *
 * Every text comes from module_string (English, plus one row per locale) — see
 * SphereGridStrings.h. No hardcoded text here.
 */

#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "SphereGridMgr.h"
#include "SphereGridPlayerMgr.h"
#include "SphereGridBench.h"
#include "SphereGridStrings.h"

#include <array>
#include <map>

using namespace Acore::ChatCommands;

class spheregrid_commandscript : public CommandScript
{
public:
    spheregrid_commandscript() : CommandScript("spheregrid_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable pointsTable =
        {
            { "add",    HandlePointsAddCommand,    SEC_ADMINISTRATOR, Console::Yes },
            { "remove", HandlePointsRemoveCommand, SEC_ADMINISTRATOR, Console::Yes },
            { "set",    HandlePointsSetCommand,    SEC_ADMINISTRATOR, Console::Yes },
            // Internal entry point for the Lua interface (RunCommand): credits
            // the award of a content source. Console only, invisible in game.
            { "source", HandlePointsSourceCommand, SEC_CONSOLE,       Console::Yes },
        };

        static ChatCommandTable spheregridTable =
        {
            { "info",     HandleInfoCommand,     SEC_GAMEMASTER,    Console::Yes },
            { "reload",   HandleReloadCommand,   SEC_ADMINISTRATOR, Console::Yes },
            { "status",   HandleStatusCommand,   SEC_GAMEMASTER,    Console::Yes },
            { "points",   pointsTable },
            // SEC_PLAYER: this is how the player interface buys a cell (through
            // RunCommand) — every game rule is applied inside.
            { "activate", HandleActivateCommand, SEC_PLAYER,        Console::No  },
            { "reset",    HandleResetCommand,    SEC_ADMINISTRATOR, Console::Yes },
            { "wipeall",  HandleWipeAllCommand,  SEC_ADMINISTRATOR, Console::Yes },
            // PLAYER-TRIGGERED RESET: the path of the interface button, hence
            // player level — and ALWAYS on oneself, no target possible. Nothing
            // to do with `reset`, which is the game master tool.
            { "respec",   HandleRespecCommand,   SEC_PLAYER,        Console::No  },
            { "show",     HandleShowCommand,     SEC_PLAYER,        Console::No  },
            { "editor",   HandleEditorCommand,   SEC_ADMINISTRATOR, Console::No  },
            // Socketing: an interface path too, hence player level.
            { "socket",   HandleSocketCommand,   SEC_PLAYER,        Console::No  },
            { "unsocket", HandleUnsocketCommand, SEC_PLAYER,        Console::No  },
            // The workbench: borrowed by the interface, like socketing — the
            // rules stay here.
            { "fuse",   HandleFuseCommand,   SEC_PLAYER,        Console::No  },
            { "reroll",  HandleRerollCommand,  SEC_PLAYER,        Console::No  },
            { "reforge",  HandleReforgeCommand,  SEC_PLAYER,        Console::No  },
            { "grind",  HandleGrindCommand,  SEC_PLAYER,        Console::No  },
            { "stats",    HandleStatsCommand,    SEC_GAMEMASTER,    Console::Yes },
        };

        static ChatCommandTable commandTable =
        {
            { "spheregrid", spheregridTable },
        };

        return commandTable;
    }

    template<typename... Args>
    static void Say(ChatHandler* handler, uint32 id, Args&&... args)
    {
        handler->PSendModuleSysMessage(SPHEREGRID_MODULE, id, std::forward<Args>(args)...);
    }

    // An error or an impossible operation: the standard red text in the middle
    // of the screen (SMSG_NOTIFICATION), like Blizzard refusals. The console has
    // no screen: fall back on the system message.
    template<typename... Args>
    static void SayError(ChatHandler* handler, uint32 id, Args&&... args)
    {
        if (handler->GetSession())
            handler->SendNotification("{}",
                handler->PGetParseModuleString(SPHEREGRID_MODULE, id, std::forward<Args>(args)...));
        else
            handler->PSendModuleSysMessage(SPHEREGRID_MODULE, id, std::forward<Args>(args)...);
    }

    static bool HandleInfoCommand(ChatHandler* handler)
    {
        auto const& cells = sSphereGridMgr->Cells();

        // [0] = nodes, [1] = sockets, [2] = spell cells
        std::map<uint8, std::array<uint32, 3>> perClass;
        for (auto const& [id, e] : cells)
            ++perClass[e.classId][e.kind <= SPHEREGRID_SPELL ? e.kind : SPHEREGRID_NODE];

        Say(handler, SPHEREGRID_STR_INFO_HEADER,
            cells.size(), sSphereGridMgr->EdgeCount(), perClass.size());

        for (auto const& [classId, count] : perClass)
            Say(handler, SPHEREGRID_STR_INFO_CLASS,
                classId, count[0], count[1], count[2], sSphereGridMgr->Start(classId));

        Say(handler, SPHEREGRID_STR_INFO_SOURCE_COUNT, sSphereGridMgr->PointSources().size());
        for (auto const& [key, points] : sSphereGridMgr->PointSources())
            Say(handler, SPHEREGRID_STR_INFO_SOURCE_LINE, key.first, key.second, points);

        return true;
    }

    static bool HandleReloadCommand(ChatHandler* handler)
    {
        sSphereGridMgr->Load();
        Say(handler, SPHEREGRID_STR_RELOAD_OK,
            sSphereGridMgr->Cells().size(), sSphereGridMgr->EdgeCount());
        return true;
    }

    // The target of a command: the named player, else the selection, else
    // oneself. Returns nullptr after printing the error.
    static Player* ConnectedTarget(ChatHandler* handler, Optional<PlayerIdentifier>& target)
    {
        if (!target)
            target = PlayerIdentifier::FromTargetOrSelf(handler);
        if (!target || !target->IsConnected())
        {
            Say(handler, SPHEREGRID_STR_PLAYER_NOT_FOUND);
            return nullptr;
        }
        return target->GetConnectedPlayer();
    }

    static bool HandleStatusCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;

        SphereGridPlayerState* state = sSphereGridPlayerMgr->State(player);
        if (!state)
        {
            Say(handler, SPHEREGRID_STR_NO_STATE_FOR, player->GetName());
            return true;
        }

        uint32 total = 0;
        for (auto const& [id, e] : sSphereGridMgr->Cells())
            if (e.classId == player->getClass())
                ++total;

        // COST BY DISTANCE: there is no single "next cost" any more, the price
        // depends on the cell aimed at. So we show the cheapest of those
        // reachable right now.
        uint8 const playerClass = player->getClass();
        uint32 cheapest = sSphereGridMgr->ActivationCost(playerClass, sSphereGridMgr->Start(playerClass));
        if (!state->actives.empty())
        {
            bool found = false;
            for (auto const& [activeId, content] : state->actives)
            {
                SphereGridCell const* e = sSphereGridMgr->Cell(activeId);
                if (!e)
                    continue;
                for (uint32 neighbour : e->neighbours)
                {
                    if (state->actives.count(neighbour))
                        continue;
                    uint32 const c = sSphereGridMgr->ActivationCost(playerClass, neighbour);
                    if (!found || c < cheapest)
                    {
                        cheapest = c;
                        found = true;
                    }
                }
            }
            if (!found)
                cheapest = 0;   // the whole grid is bought
        }

        Say(handler, SPHEREGRID_STR_STATUS_POINTS,
            player->GetName(), state->Available(), state->earned, state->spent);
        Say(handler, SPHEREGRID_STR_STATUS_ACTIVE,
            state->actives.size(), total, player->getClass(), cheapest);
        Say(handler, SPHEREGRID_STR_STATUS_PRISMS, state->prisms, 25 * state->prisms);
        return true;
    }

    // With no amount, each points subcommand prints its own help.
    static void PointsHelp(ChatHandler* handler, char const* name, uint32 effectString)
    {
        Say(handler, SPHEREGRID_STR_POINTS_USAGE, name);
        Say(handler, effectString);
        Say(handler, SPHEREGRID_STR_POINTS_TARGET);
    }

    static bool HandlePointsAddCommand(ChatHandler* handler, Optional<uint32> amount, Optional<PlayerIdentifier> target)
    {
        if (!amount || !*amount)
        {
            PointsHelp(handler, "add", SPHEREGRID_STR_POINTS_HELP_ADD);
            return true;
        }

        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;

        if (!sSphereGridPlayerMgr->AddPoints(player, *amount))
        {
            Say(handler, SPHEREGRID_STR_NO_STATE_FOR, player->GetName());
            return true;
        }

        SphereGridPlayerState* state = sSphereGridPlayerMgr->State(player);
        Say(handler, SPHEREGRID_STR_POINTS_ADDED,
            player->GetName(), *amount, state ? state->Available() : 0);
        return true;
    }

    static bool HandlePointsRemoveCommand(ChatHandler* handler, Optional<uint32> amount, Optional<PlayerIdentifier> target)
    {
        if (!amount || !*amount)
        {
            PointsHelp(handler, "remove", SPHEREGRID_STR_POINTS_HELP_REMOVE);
            return true;
        }

        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;

        uint32 removed = 0;
        if (!sSphereGridPlayerMgr->RemovePoints(player, *amount, removed))
        {
            Say(handler, SPHEREGRID_STR_NO_STATE_FOR, player->GetName());
            return true;
        }

        SphereGridPlayerState* state = sSphereGridPlayerMgr->State(player);
        Say(handler, SPHEREGRID_STR_POINTS_REMOVED,
            player->GetName(), removed, *amount, state ? state->Available() : 0);
        return true;
    }

    static bool HandlePointsSetCommand(ChatHandler* handler, Optional<uint32> amount, Optional<PlayerIdentifier> target)
    {
        if (!amount)
        {
            PointsHelp(handler, "set", SPHEREGRID_STR_POINTS_HELP_SET);
            return true;
        }

        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;

        if (!sSphereGridPlayerMgr->SetPoints(player, *amount))
        {
            Say(handler, SPHEREGRID_STR_NO_STATE_FOR, player->GetName());
            return true;
        }

        Say(handler, SPHEREGRID_STR_POINTS_SET, player->GetName(), *amount);
        return true;
    }

    static bool HandlePointsSourceCommand(ChatHandler* handler, std::string type, uint32 value, Optional<PlayerIdentifier> target)
    {
        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;

        uint32 const points = sSphereGridMgr->PointsForSource(type, value);
        if (!points)
        {
            Say(handler, SPHEREGRID_STR_SOURCE_UNKNOWN, type, value);
            return true;
        }

        // A content SOURCE: boosted by the account prisms like any gain — only
        // points add / set stay raw.
        SphereGridPlayerState* state = sSphereGridPlayerMgr->State(player);
        uint32 const credited = sSphereGridPlayerMgr->Boosted(player, points);

        // The origin announced to the player: some sources name their tier, the
        // others fall back on the generic message for lack of anything better.
        uint32 const text = (type == "mythic_plus")
            ? SPHEREGRID_STR_GAIN_MYTHIC : SPHEREGRID_STR_GAIN_GENERIC;
        if (!sSphereGridPlayerMgr->Earn(player, points, text, std::to_string(value)))
        {
            Say(handler, SPHEREGRID_STR_NO_STATE_FOR, player->GetName());
            return true;
        }

        Say(handler, SPHEREGRID_STR_POINTS_ADDED,
            player->GetName(), credited, state ? state->Available() : 0);
        return true;
    }

    static bool HandleActivateCommand(ChatHandler* handler, uint32 nodeId)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return true;

        switch (sSphereGridPlayerMgr->Activate(player, nodeId))
        {
            // SILENT ON SUCCESS: this command is the channel the INTERFACE buys
            // through, so a click on the grid used to produce a chat line per
            // cell. The window refreshes on its own and already shows points and
            // count. Failures stay announced: it is the only way the player
            // learns why his purchase was refused.
            case SphereGridActivation::Ok:
                break;
            case SphereGridActivation::NoState:
                SayError(handler, SPHEREGRID_STR_NO_STATE_SELF);
                break;
            case SphereGridActivation::UnknownCell:
                SayError(handler, SPHEREGRID_STR_ACT_UNKNOWN, nodeId);
                break;
            case SphereGridActivation::WrongClass:
                SayError(handler, SPHEREGRID_STR_ACT_WRONG_CLASS, nodeId);
                break;
            case SphereGridActivation::AlreadyActive:
                SayError(handler, SPHEREGRID_STR_ACT_ALREADY, nodeId);
                break;
            case SphereGridActivation::NotAdjacent:
                SayError(handler, SPHEREGRID_STR_ACT_NOT_ADJACENT, nodeId);
                break;
            case SphereGridActivation::NotEnoughPoints:
                // Neither the cost nor what the player owns: the refusal only
                // says that he cannot afford it.
                SayError(handler, SPHEREGRID_STR_ACT_NOT_ENOUGH);
                break;
        }
        return true;
    }

    static bool HandleResetCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;

        sSphereGridPlayerMgr->Reset(player);
        Say(handler, SPHEREGRID_STR_RESET_OK, player->GetName());
        return true;
    }

    // THE PLAYER GIVES HIS GRID BACK. Always on oneself: the command takes no
    // target, the interface borrows it for the connected character. The rules
    // live in the module (spells forgotten, stones and runes left in place, the
    // character's Spherite returned).
    static bool HandleRespecCommand(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
        {
            Say(handler, SPHEREGRID_STR_PLAYER_NOT_FOUND);
            return true;
        }

        uint32 const refunded = sSphereGridPlayerMgr->ResetProgression(player);
        Say(handler, SPHEREGRID_STR_RESPEC_OK, refunded);
        return true;
    }

    // THE WHOLE ACCOUNT of the target: earned Spherite erased and the grids of
    // every one of its characters reset, online or not. With no argument, the
    // caller's own account.
    //
    // IRREVERSIBLE, and far wider than `reset`, which takes a single character
    // and leaves the account Spherite untouched.
    static bool HandleWipeAllCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;

        uint32 const count = sSphereGridPlayerMgr->WipeAccount(player);
        Say(handler, SPHEREGRID_STR_WIPEALL_OK, player->GetName(), count);
        return true;
    }

    // Reports a socketing or a use of the pin. Refusals go through the red
    // text, like every refusal of the module.
    static void ReportSocketing(ChatHandler* handler, SphereGridSocketing r,
        uint32 nodeId, uint32 okString, uint32 arg1, uint32 arg2)
    {
        switch (r)
        {
            // SOCKETING SAYS NOTHING. The stone or the rune is in the cell,
            // the window shows it and a sound answers the gesture; a line
            // naming an entry and a cell number was one more thing to read.
            // Emptying still speaks: what came out went back to the bags.
            case SphereGridSocketing::Ok:
                if (okString != SPHEREGRID_STR_SOCKETED)
                    Say(handler, okString, arg1, arg2);
                break;
            case SphereGridSocketing::NoState:
                SayError(handler, SPHEREGRID_STR_NO_STATE_SELF);
                break;
            case SphereGridSocketing::UnknownCell:
                SayError(handler, SPHEREGRID_STR_ACT_UNKNOWN, nodeId);
                break;
            case SphereGridSocketing::NotActive:
                SayError(handler, SPHEREGRID_STR_SOCKET_NOT_ACTIVE, nodeId);
                break;
            case SphereGridSocketing::AlreadyFilled:
                SayError(handler, okString == SPHEREGRID_STR_SOCKETED
                    ? SPHEREGRID_STR_SOCKET_FILLED : SPHEREGRID_STR_SOCKET_EMPTY, nodeId);
                break;
            case SphereGridSocketing::WrongKind:
                SayError(handler, SPHEREGRID_STR_SOCKET_WRONG_KIND, nodeId);
                break;
            case SphereGridSocketing::ItemMissing:
                SayError(handler, SPHEREGRID_STR_SOCKET_ITEM_MISSING);
                break;
            case SphereGridSocketing::WrongClass:
                SayError(handler, SPHEREGRID_STR_SOCKET_WRONG_CLASS);
                break;
            case SphereGridSocketing::TooManyRunes:
                SayError(handler, SPHEREGRID_STR_SOCKET_TOO_MANY_RUNES);
                break;
        }
    }

    // A single place to report what the workbench answered, the recipes sharing
    // the same set of refusals.
    static void ReportBench(ChatHandler* handler, SphereGridBenchResult r)
    {
        switch (r)
        {
            // A SUCCESS SAYS NOTHING. What was crafted lands in the bag,
            // where the player sees it and where the window redraws itself on
            // the bag's own event. The line that named the entry crafted was a
            // developer's receipt, and the player read it after every recipe.
            case SphereGridBenchResult::Ok:
                break;
            case SphereGridBenchResult::NotAStone:
                SayError(handler, SPHEREGRID_STR_BENCH_NOT_STONE);
                break;
            case SphereGridBenchResult::NotARune:
                SayError(handler, SPHEREGRID_STR_BENCH_NOT_RUNE);
                break;
            case SphereGridBenchResult::DifferentEffects:
                SayError(handler, SPHEREGRID_STR_BENCH_EFFECTS);
                break;
            case SphereGridBenchResult::DifferentQualities:
                SayError(handler, SPHEREGRID_STR_BENCH_QUALITIES);
                break;
            case SphereGridBenchResult::MaxQuality:
                SayError(handler, SPHEREGRID_STR_BENCH_MAX_QUALITY);
                break;
            case SphereGridBenchResult::NothingToDraw:
                SayError(handler, SPHEREGRID_STR_BENCH_NOTHING);
                break;
            case SphereGridBenchResult::ItemMissing:
                SayError(handler, SPHEREGRID_STR_BENCH_ITEM_MISSING);
                break;
            case SphereGridBenchResult::BagFull:
                SayError(handler, SPHEREGRID_STR_BENCH_BAG_FULL);
                break;
            case SphereGridBenchResult::NotGrindable:
                SayError(handler, SPHEREGRID_STR_BENCH_NOT_GRINDABLE);
                break;
        }
    }

    // GRINDING: the only recipe that returns no item, and it says nothing of
    // its own either. Earn has already announced the gain, in the words of the
    // source it came from; a second line carrying the same amount said the
    // same thing twice.
    static bool HandleGrindCommand(ChatHandler* handler, uint32 entry)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return true;

        uint32 earned = 0;
        ReportBench(handler, SphereGridBench::Grind(player, entry, earned));
        return true;
    }

    // Fusing takes three times the SAME stone, hence a single argument.
    static bool HandleFuseCommand(ChatHandler* handler, uint32 entry)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return true;

        uint32 crafted = 0;
        ReportBench(handler, SphereGridBench::Fuse(player, entry, crafted));
        return true;
    }

    static bool HandleRerollCommand(ChatHandler* handler, uint32 a, uint32 b)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return true;

        uint32 crafted = 0;
        ReportBench(handler, SphereGridBench::RerollStone(player, a, b, crafted));
        return true;
    }

    static bool HandleReforgeCommand(ChatHandler* handler, uint32 a, uint32 b, uint32 c)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return true;

        uint32 crafted = 0;
        ReportBench(handler, SphereGridBench::ReforgeRunes(player, a, b, c, crafted));
        return true;
    }

    static bool HandleSocketCommand(ChatHandler* handler, uint32 nodeId, uint32 itemEntry)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return true;

        ReportSocketing(handler,
            sSphereGridPlayerMgr->Socket(player, nodeId, itemEntry),
            nodeId, SPHEREGRID_STR_SOCKETED, itemEntry, nodeId);
        return true;
    }

    static bool HandleUnsocketCommand(ChatHandler* handler, uint32 nodeId)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return true;

        ReportSocketing(handler,
            sSphereGridPlayerMgr->Unsocket(player, nodeId),
            nodeId, SPHEREGRID_STR_UNSOCKETED, nodeId, 0);
        return true;
    }

    static bool HandleStatsCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;

        SphereGridStatBlock const* block = sSphereGridPlayerMgr->StatBlock(player);
        bool anything = false;
        if (block)
            for (uint8 s = 1; s <= SPHEREGRID_STAT_COUNT; ++s)
                if ((*block)[s])
                {
                    if (!anything)
                    {
                        Say(handler, SPHEREGRID_STR_STATS_HEADER, player->GetName());
                        anything = true;
                    }
                    Say(handler, SPHEREGRID_STR_STATS_LINE, s, (*block)[s]);
                }

        if (!anything)
            Say(handler, SPHEREGRID_STR_STATS_EMPTY);
        return true;
    }

    // Fallbacks: normally the Lua interface intercepts show and editor first.
    static bool HandleShowCommand(ChatHandler* handler)
    {
        Say(handler, SPHEREGRID_STR_SHOW_FALLBACK);
        return true;
    }

    static bool HandleEditorCommand(ChatHandler* handler)
    {
        Say(handler, SPHEREGRID_STR_EDITOR_FALLBACK);
        return true;
    }
};

void AddSC_spheregrid_commands()
{
    new spheregrid_commandscript();
}
