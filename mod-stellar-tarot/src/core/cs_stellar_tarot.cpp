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
 * mod-stellar-tarot — chat commands.
 *
 * .tarot info                          (SEC_GAMEMASTER)     the loaded catalogue
 * .tarot reload                        (SEC_ADMINISTRATOR)  reads the mod_stellar_tarot_* tables again
 * .tarot study <entry>                 (SEC_PLAYER)         studies a card or a board from the bags
 * .tarot hud                           (SEC_PLAYER)         toggles the measurement block
 * .tarot binder [player]               (SEC_GAMEMASTER)     what a player's account has studied
 * .tarot board <board_id|0>            (SEC_PLAYER)         equips a board, or takes it off
 * .tarot place <row> <col> <card_id>   (SEC_PLAYER)         lays a card on a cell
 * .tarot remove <row> <col>            (SEC_PLAYER)         takes a card off a cell
 * .tarot clear                         (SEC_PLAYER)         takes every card off
 * .tarot preset save <name>            (SEC_PLAYER)         saves the layout under a name
 * .tarot preset load <preset_id>       (SEC_PLAYER)         equips and lays a saved layout
 * .tarot preset delete <preset_id>     (SEC_PLAYER)         forgets a saved layout
 * .tarot layout [player]               (SEC_GAMEMASTER)     a player's board and the level of every card
 * .tarot effects [player]              (SEC_GAMEMASTER)     the effects in force on a player
 * .tarot xp [player]                   (SEC_GAMEMASTER)     what the cards make of 1000 experience
 * .tarot fuse <a> <b> <c>              (SEC_PLAYER)         the workbench: three cards, or three boards, become one
 * .tarot check [start|stop]           (SEC_GAMEMASTER)     measures the event lines and gives the verdict
 * .tarot test card <player> <card> <level> [cumulative]  (SEC_GAMEMASTER)  one card level, test values armed
 * .tarot test clear <player>                      (SEC_GAMEMASTER)  back to the board, everything released
 * .tarot test force <player> <state> on|off|free  (SEC_GAMEMASTER)  a state held, failed or given back
 * .tarot test hour <0-23|-1>                      (SEC_GAMEMASTER)  the hour every card reads
 * .tarot test hp|mana <player> <pct>              (SEC_GAMEMASTER)  health or mana set to a share
 * .tarot test trace <player> on|off               (SEC_GAMEMASTER)  the probes, in the log and the chat
 * .tarot test status <player>                     (SEC_GAMEMASTER)  what the bench holds for a player
 * .tarot test fire <player> <event> [n]          (SEC_GAMEMASTER)  an event of the game handed to the cards
 * .tarot test snapshot <player>                   (SEC_GAMEMASTER)  what can be measured of the player
 * .tarot test aura <player> <spell> [target] [n]  (SEC_GAMEMASTER)  an aura laid on the player or the target
 *
 * .tarot with no argument lists the subcommands (the core behaviour for a
 * parent command, filtered by security level). Each subcommand describes
 * itself through the `command` table: .tarot <sub> help.
 *
 * The SEC_PLAYER commands are the paths the interface takes: the Lua relays
 * a gesture and runs the command AS THE PLAYER, so every rule and every
 * message lives here. Handing a card to a player is the core's own
 * `.additem`: the module adds no command the core already has.
 *
 * Every text comes from module_string (English, plus one row per locale) —
 * see StellarTarotStrings.h. No hardcoded text here.
 */

#include "Chat.h"
#include "Log.h"
#include <cmath>
#include <map>
#include <set>
#include "CellImpl.h"
#include "CommandScript.h"
#include "Creature.h"
#include "GameObject.h"
#include "GameTime.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Item.h"
#include "LootMgr.h"
#include "ObjectMgr.h"
#include "Pet.h"
#include "QuestDef.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "TemporarySummon.h"
#include "Player.h"
#include "StellarTarotBinder.h"
#include "StellarTarotEffects.h"
#include "StellarTarotLayout.h"
#include "StellarTarotScript.h"
#include "StellarTarotLoot.h"
#include "StellarTarotMgr.h"
#include "StellarTarotStrings.h"
#include "WorldSession.h"

using namespace Acore::ChatCommands;

class stellar_tarot_commandscript : public CommandScript
{
public:
    stellar_tarot_commandscript() : CommandScript("stellar_tarot_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable presetTable =
        {
            { "save",   HandlePresetSaveCommand,   SEC_PLAYER, Console::No },
            { "load",   HandlePresetLoadCommand,   SEC_PLAYER, Console::No },
            { "delete", HandlePresetDeleteCommand, SEC_PLAYER, Console::No },
        };

        // The test bench: every subcommand names its player, so that it runs
        // from the console as well.
        static ChatCommandTable testTable =
        {
            { "card",   HandleTestCardCommand,   SEC_GAMEMASTER, Console::Yes },
            { "clear",  HandleTestClearCommand,  SEC_GAMEMASTER, Console::Yes },
            { "force",  HandleTestForceCommand,  SEC_GAMEMASTER, Console::Yes },
            { "hour",   HandleTestHourCommand,   SEC_GAMEMASTER, Console::Yes },
            { "hp",     HandleTestHealthCommand, SEC_GAMEMASTER, Console::Yes },
            { "mana",   HandleTestManaCommand,   SEC_GAMEMASTER, Console::Yes },
            { "trace",  HandleTestTraceCommand,  SEC_GAMEMASTER, Console::Yes },
            { "status", HandleTestStatusCommand, SEC_GAMEMASTER, Console::Yes },
            { "fire",   HandleTestFireCommand,   SEC_GAMEMASTER, Console::Yes },
            { "snapshot", HandleTestSnapshotCommand, SEC_GAMEMASTER, Console::Yes },
            { "aura",   HandleTestAuraCommand,   SEC_GAMEMASTER, Console::Yes },
        };

        static ChatCommandTable tarotTable =
        {
            { "info",   HandleInfoCommand,   SEC_GAMEMASTER,    Console::Yes },
            { "reload", HandleReloadCommand, SEC_ADMINISTRATOR, Console::Yes },
            // SEC_PLAYER: the paths of the interface (through RunCommand) --
            // every rule is applied inside.
            { "study",  HandleStudyCommand,  SEC_PLAYER,        Console::No  },
            { "hud",    HandleHudCommand,    SEC_PLAYER,        Console::No  },
            { "binder", HandleBinderCommand, SEC_GAMEMASTER,    Console::Yes },
            { "board",  HandleBoardCommand,  SEC_PLAYER,        Console::No  },
            { "place",  HandlePlaceCommand,  SEC_PLAYER,        Console::No  },
            { "remove", HandleRemoveCommand, SEC_PLAYER,        Console::No  },
            { "move",   HandleMoveCommand,   SEC_PLAYER,        Console::No  },
            { "clear",  HandleClearCommand,  SEC_PLAYER,        Console::No  },
            { "preset", presetTable },
            { "layout", HandleLayoutCommand, SEC_GAMEMASTER,    Console::Yes },
            { "effects", HandleEffectsCommand, SEC_GAMEMASTER,  Console::Yes },
            { "xp",     HandleXpCommand,      SEC_GAMEMASTER,  Console::Yes },
            // The workbench: the shared bench relays here; the rules stay here.
            { "fuse",   HandleFuseCommand,   SEC_PLAYER,        Console::No  },
            { "sources", HandleSourcesCommand, SEC_GAMEMASTER,  Console::Yes },
            { "check",  HandleCheckCommand,  SEC_GAMEMASTER,    Console::No  },
            { "test",   testTable },
        };

        static ChatCommandTable commandTable =
        {
            { "tarot", tarotTable },
        };

        return commandTable;
    }

    template<typename... Args>
    static void Say(ChatHandler* handler, uint32 id, Args&&... args)
    {
        handler->PSendModuleSysMessage(STELLAR_TAROT_MODULE, id, std::forward<Args>(args)...);
    }

    // An error or an impossible operation: the standard red text in the middle
    // of the screen (SMSG_NOTIFICATION), like Blizzard refusals. The console has
    // no screen: fall back on the system message.
    template<typename... Args>
    static void SayError(ChatHandler* handler, uint32 id, Args&&... args)
    {
        if (handler->GetSession())
            handler->SendNotification("{}",
                handler->PGetParseModuleString(STELLAR_TAROT_MODULE, id, std::forward<Args>(args)...));
        else
            handler->PSendModuleSysMessage(STELLAR_TAROT_MODULE, id, std::forward<Args>(args)...);
    }

    // The target of a command: the named player, else the selection, else
    // oneself. Returns nullptr after printing the error.
    static Player* ConnectedTarget(ChatHandler* handler, Optional<PlayerIdentifier>& target)
    {
        if (!target)
            target = PlayerIdentifier::FromTargetOrSelf(handler);
        if (!target || !target->IsConnected())
        {
            Say(handler, STELLAR_TAROT_STR_PLAYER_NOT_FOUND);
            return nullptr;
        }
        return target->GetConnectedPlayer();
    }

    // The player behind a SEC_PLAYER command: always oneself.
    static Player* Self(ChatHandler* handler)
    {
        return handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
    }

    // The numbers of one axis, both sides: "1/7-4/4-8/2" for three rows read
    // left/right, or three columns read top/bottom.
    static std::string Numbers(std::array<uint8, STELLAR_TAROT_MAX_SIDE> const& first,
                               std::array<uint8, STELLAR_TAROT_MAX_SIDE> const& second, uint8 count)
    {
        std::string out;
        for (uint8 i = 0; i < count; ++i)
        {
            if (i)
                out += '-';
            out += std::to_string(first[i]) + "/" + std::to_string(second[i]);
        }
        return out;
    }

    static bool HandleInfoCommand(ChatHandler* handler)
    {
        if (!sStellarTarotMgr->Enabled())
        {
            Say(handler, STELLAR_TAROT_STR_DISABLED);
            return true;
        }
        Say(handler, STELLAR_TAROT_STR_INFO_HEADER,
            sStellarTarotMgr->Cards().size(), sStellarTarotMgr->Boards().size(),
            sStellarTarotMgr->Tags().size());
        for (auto const& [id, card] : sStellarTarotMgr->Cards())
        {
            StellarTarotTag const* tag = sStellarTarotMgr->Tag(card.tagId);
            std::string const tags = tag ? tag->name : std::to_string(card.tagId);
            Say(handler, STELLAR_TAROT_STR_INFO_CARD, id, sStellarTarotMgr->CardName(id),
                uint32(card.edges[STELLAR_TAROT_EDGE_TOP]), uint32(card.edges[STELLAR_TAROT_EDGE_RIGHT]),
                uint32(card.edges[STELLAR_TAROT_EDGE_BOTTOM]), uint32(card.edges[STELLAR_TAROT_EDGE_LEFT]),
                StellarTarotMgr::ItemForCard(id), tags.empty() ? std::string("-") : tags);
            Say(handler, STELLAR_TAROT_STR_INFO_CARD_LEVELS, card.cumulative ? "cumulative" : "highest level only",
                Describe(card.effects[0]), Describe(card.effects[1]), Describe(card.effects[2]), Describe(card.effects[3]));
        }
        for (auto const& [id, why] : sStellarTarotMgr->Refused())
            Say(handler, STELLAR_TAROT_STR_INFO_REFUSED, id, sStellarTarotMgr->CardName(id), why);
        for (auto const& [id, board] : sStellarTarotMgr->Boards())
            Say(handler, STELLAR_TAROT_STR_INFO_BOARD, id, sStellarTarotMgr->BoardName(id),
                uint32(board.rows), uint32(board.cols),
                Numbers(board.rowLeft, board.rowRight, board.rows), Numbers(board.colTop, board.colBottom, board.cols),
                StellarTarotMgr::ItemForBoard(id));
        std::string names;
        for (std::string const& name : StellarTarotScripts::Names())
            names += (names.empty() ? "" : ", ") + name;
        Say(handler, STELLAR_TAROT_STR_INFO_SCRIPTS, names.empty() ? std::string("-") : names);
        return true;
    }

    // One level of a card, in a word: "spell 88004", "gold_on_kill:1234", or both.
    static std::string Describe(StellarTarotEffect const& effect)
    {
        std::string out;
        if (effect.spellId)
            out = "spell " + std::to_string(effect.spellId);
        if (!effect.script.Empty())
            out += (out.empty() ? "" : " + ") + effect.script.text;
        return out.empty() ? std::string("-") : out;
    }

    // STUDYING: the item leaves the bags and the card or board joins the
    // binder of the whole account. Always on oneself, always from the bags.
    // LE BLOC DE MESURE : ce que le serveur est seul a savoir, pousse a
    // l'addon une fois par seconde. Outil de mise au point, perdu a la
    // deconnexion.
    static bool HandleHudCommand(ChatHandler* handler)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        bool const allume = StellarTarotEffects::ToggleHud(player);
        handler->PSendSysMessage(allume ? "Tarot : bloc de mesure ALLUME."
                                        : "Tarot : bloc de mesure eteint.");
        return true;
    }

    static bool HandleStudyCommand(ChatHandler* handler, uint32 entry)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        bool isBoard = false;
        uint32 id = 0;
        switch (StellarTarotBinder::Study(player, entry, isBoard, id))
        {
            case StellarTarotStudyResult::NotOurs:
                SayError(handler, STELLAR_TAROT_STR_STUDY_NOT_OURS, entry);
                break;
            case StellarTarotStudyResult::NotCarried:
                SayError(handler, STELLAR_TAROT_STR_STUDY_NOT_CARRIED,
                         isBoard ? sStellarTarotMgr->BoardName(id) : sStellarTarotMgr->CardName(id));
                break;
            case StellarTarotStudyResult::AlreadyKnown:
                SayError(handler, STELLAR_TAROT_STR_STUDY_KNOWN,
                         isBoard ? sStellarTarotMgr->BoardName(id) : sStellarTarotMgr->CardName(id));
                break;
            case StellarTarotStudyResult::Ok:
                Say(handler, STELLAR_TAROT_STR_STUDY_OK,
                    isBoard ? sStellarTarotMgr->BoardName(id) : sStellarTarotMgr->CardName(id));
                break;
        }
        return true;
    }

    static bool HandleBinderCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;
        uint32 const accountId = player->GetSession()->GetAccountId();
        std::vector<uint32> const cards = StellarTarotBinder::Cards(accountId);
        std::vector<uint32> const boards = StellarTarotBinder::Boards(accountId);
        Say(handler, STELLAR_TAROT_STR_BINDER_HEADER, player->GetName(), cards.size(), boards.size());

        std::string list;
        for (uint32 id : cards)
            list += (list.empty() ? "" : ", ") + std::to_string(id) + " " + sStellarTarotMgr->CardName(id);
        Say(handler, STELLAR_TAROT_STR_BINDER_CARDS, list.empty() ? std::string("-") : list);
        list.clear();
        for (uint32 id : boards)
            list += (list.empty() ? "" : ", ") + std::to_string(id) + " " + sStellarTarotMgr->BoardName(id);
        Say(handler, STELLAR_TAROT_STR_BINDER_BOARDS, list.empty() ? std::string("-") : list);
        return true;
    }

    // -- the layout ----------------------------------------------------------

    // The refusals of the layout, one message each. Ok says nothing: each
    // command has its own success line.
    static bool Refused(ChatHandler* handler, StellarTarotLayoutResult result,
                        uint32 boardId = 0, uint32 row = 0, uint32 col = 0, uint32 cardId = 0)
    {
        switch (result)
        {
            case StellarTarotLayoutResult::Ok:
                return false;
            case StellarTarotLayoutResult::NoSuchBoard:
                SayError(handler, STELLAR_TAROT_STR_BOARD_UNKNOWN, boardId);
                break;
            case StellarTarotLayoutResult::BoardNotKnown:
                SayError(handler, STELLAR_TAROT_STR_BOARD_NOT_KNOWN, sStellarTarotMgr->BoardName(boardId));
                break;
            case StellarTarotLayoutResult::NoBoard:
                SayError(handler, STELLAR_TAROT_STR_NO_BOARD);
                break;
            case StellarTarotLayoutResult::OutOfBounds:
                SayError(handler, STELLAR_TAROT_STR_OUT_OF_BOUNDS, row, col);
                break;
            case StellarTarotLayoutResult::CellTaken:
                SayError(handler, STELLAR_TAROT_STR_CELL_TAKEN, row, col);
                break;
            case StellarTarotLayoutResult::CellEmpty:
                SayError(handler, STELLAR_TAROT_STR_CELL_EMPTY, row, col);
                break;
            case StellarTarotLayoutResult::NoSuchCard:
                SayError(handler, STELLAR_TAROT_STR_CARD_UNKNOWN, cardId);
                break;
            case StellarTarotLayoutResult::CardNotKnown:
                SayError(handler, STELLAR_TAROT_STR_CARD_NOT_KNOWN, sStellarTarotMgr->CardName(cardId));
                break;
            case StellarTarotLayoutResult::CardAlreadyPlaced:
                SayError(handler, STELLAR_TAROT_STR_CARD_TWICE, sStellarTarotMgr->CardName(cardId));
                break;
            case StellarTarotLayoutResult::NoSuchPreset:
                SayError(handler, STELLAR_TAROT_STR_PRESET_UNKNOWN, boardId);
                break;
            case StellarTarotLayoutResult::BadPresetName:
                SayError(handler, STELLAR_TAROT_STR_PRESET_NAME);
                break;
        }
        return true;
    }

    static bool HandleBoardCommand(ChatHandler* handler, uint32 boardId)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        if (Refused(handler, StellarTarotLayouts::Equip(player, boardId), boardId))
            return true;
        StellarTarotEffects::Refresh(player);
        if (boardId)
            Say(handler, STELLAR_TAROT_STR_BOARD_EQUIPPED, sStellarTarotMgr->BoardName(boardId));
        else
            Say(handler, STELLAR_TAROT_STR_BOARD_REMOVED);
        return true;
    }

    static bool HandlePlaceCommand(ChatHandler* handler, uint32 row, uint32 col, uint32 cardId)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        if (row > STELLAR_TAROT_MAX_SIDE || col > STELLAR_TAROT_MAX_SIDE)
            return Refused(handler, StellarTarotLayoutResult::OutOfBounds, 0, row, col);
        uint32 replaced = 0;
        if (Refused(handler, StellarTarotLayouts::Place(player, uint8(row), uint8(col), cardId, replaced), 0, row, col, cardId))
            return true;
        StellarTarotEffects::Refresh(player);
        if (replaced)
            Say(handler, STELLAR_TAROT_STR_REPLACED, sStellarTarotMgr->CardName(cardId), sStellarTarotMgr->CardName(replaced), row, col);
        else
            Say(handler, STELLAR_TAROT_STR_PLACED, sStellarTarotMgr->CardName(cardId), row, col);
        return true;
    }

    static bool HandleMoveCommand(ChatHandler* handler, uint32 fromRow, uint32 fromCol, uint32 toRow, uint32 toCol)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        if (fromRow > STELLAR_TAROT_MAX_SIDE || fromCol > STELLAR_TAROT_MAX_SIDE)
            return Refused(handler, StellarTarotLayoutResult::OutOfBounds, 0, fromRow, fromCol);
        if (toRow > STELLAR_TAROT_MAX_SIDE || toCol > STELLAR_TAROT_MAX_SIDE)
            return Refused(handler, StellarTarotLayoutResult::OutOfBounds, 0, toRow, toCol);
        uint32 cardId = 0, swappedWith = 0;
        if (Refused(handler, StellarTarotLayouts::Move(player, uint8(fromRow), uint8(fromCol), uint8(toRow), uint8(toCol),
                                                       cardId, swappedWith), 0, fromRow, fromCol))
            return true;
        if (fromRow == toRow && fromCol == toCol)
            return true;
        StellarTarotEffects::Refresh(player);
        if (swappedWith)
            Say(handler, STELLAR_TAROT_STR_SWAPPED, sStellarTarotMgr->CardName(cardId), sStellarTarotMgr->CardName(swappedWith));
        else
            Say(handler, STELLAR_TAROT_STR_MOVED, sStellarTarotMgr->CardName(cardId), toRow, toCol);
        return true;
    }

    static bool HandleRemoveCommand(ChatHandler* handler, uint32 row, uint32 col)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        if (row > STELLAR_TAROT_MAX_SIDE || col > STELLAR_TAROT_MAX_SIDE)
            return Refused(handler, StellarTarotLayoutResult::OutOfBounds, 0, row, col);
        uint32 cardId = 0;
        if (Refused(handler, StellarTarotLayouts::Remove(player, uint8(row), uint8(col), cardId), 0, row, col))
            return true;
        StellarTarotEffects::Refresh(player);
        Say(handler, STELLAR_TAROT_STR_REMOVED, sStellarTarotMgr->CardName(cardId), row, col);
        return true;
    }

    static bool HandleClearCommand(ChatHandler* handler)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        StellarTarotLayouts::Clear(player);
        StellarTarotEffects::Refresh(player);
        Say(handler, STELLAR_TAROT_STR_CLEARED);
        return true;
    }

    static bool HandlePresetSaveCommand(ChatHandler* handler, Tail name)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        uint32 presetId = 0, count = 0;
        if (Refused(handler, StellarTarotLayouts::SavePreset(player, std::string(name), presetId, count)))
            return true;
        Say(handler, STELLAR_TAROT_STR_PRESET_SAVED, std::string(name), count);
        return true;
    }

    static bool HandlePresetLoadCommand(ChatHandler* handler, uint32 presetId)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        std::string name;
        uint32 laid = 0, skipped = 0;
        if (Refused(handler, StellarTarotLayouts::LoadPreset(player, presetId, name, laid, skipped), presetId))
            return true;
        StellarTarotEffects::Refresh(player);
        Say(handler, STELLAR_TAROT_STR_PRESET_LOADED, name, laid, skipped);
        return true;
    }

    static bool HandlePresetDeleteCommand(ChatHandler* handler, uint32 presetId)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        std::string name;
        if (Refused(handler, StellarTarotLayouts::DeletePreset(player, presetId, name), presetId))
            return true;
        Say(handler, STELLAR_TAROT_STR_PRESET_DELETED, name);
        return true;
    }

    static bool HandleLayoutCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;
        StellarTarotLayout const layout = StellarTarotLayouts::Load(player);
        StellarTarotBoard const* board = layout.boardId ? sStellarTarotMgr->Board(layout.boardId) : nullptr;
        Say(handler, STELLAR_TAROT_STR_LAYOUT_HEADER, player->GetName(),
            board ? sStellarTarotMgr->BoardName(layout.boardId) : std::string("-"),
            uint32(board ? board->rows : 0), uint32(board ? board->cols : 0), layout.cells.size());
        for (StellarTarotActivation const& a : StellarTarotLayouts::Activations(layout))
        {
            std::string edges;
            for (uint8 e = 0; e < STELLAR_TAROT_EDGES; ++e)
                edges += a.matched[e] ? '1' : '0';
            Say(handler, STELLAR_TAROT_STR_LAYOUT_CELL, uint32(a.placement.row), uint32(a.placement.col),
                sStellarTarotMgr->CardName(a.placement.cardId), uint32(a.level), edges);
        }
        return true;
    }

    // CE QUE LES CARTES FONT DE L'EXPERIENCE : une somme de reference passee
    // par le meme chemin que celle d'une creature tuee. Rien n'est recalcule a
    // cote : c'est le chiffre du module lui-meme.
    static bool HandleXpCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;
        uint32 const before = 1000;
        uint32 amount = before;
        // Une victime : la source la plus ordinaire, celle que la commande
        // montre. Les auras natives n'y paraissent pas -- c'est le chiffre du
        // module seul, comme le dit le commentaire ci-dessus.
        StellarTarotEffects::OnGiveXP(player, amount, 0);
        Say(handler, STELLAR_TAROT_STR_XP_BONUS, player->GetName(), amount,
            int32(amount) - int32(before));
        return true;
    }

    static bool HandleEffectsCommand(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = ConnectedTarget(handler, target);
        if (!player)
            return true;
        std::vector<StellarTarotActiveEffect> const active = StellarTarotEffects::Active(player);
        Say(handler, STELLAR_TAROT_STR_EFFECTS_HEADER, player->GetName(), active.size());
        for (StellarTarotActiveEffect const& e : active)
            Say(handler, STELLAR_TAROT_STR_EFFECTS_LINE, sStellarTarotMgr->CardName(e.cardId), uint32(e.level),
                e.spellId ? std::to_string(e.spellId) : std::string("-"),
                e.script.empty() ? std::string("-") : e.script);
        return true;
    }

    static bool HandleFuseCommand(ChatHandler* handler, uint32 a, uint32 b, uint32 c)
    {
        Player* player = Self(handler);
        if (!player)
            return true;
        uint32 crafted = 0;
        bool isBoard = false;
        switch (StellarTarotFuse::Fuse(player, a, b, c, crafted, isBoard))
        {
            case StellarTarotFuseResult::NotThreeOfAKind:
                SayError(handler, STELLAR_TAROT_STR_FUSE_NOT_THREE);
                break;
            case StellarTarotFuseResult::NotCarried:
                SayError(handler, STELLAR_TAROT_STR_FUSE_NOT_CARRIED);
                break;
            case StellarTarotFuseResult::BagFull:
                SayError(handler, STELLAR_TAROT_STR_FUSE_BAG_FULL);
                break;
            case StellarTarotFuseResult::NothingToDraw:
                SayError(handler, STELLAR_TAROT_STR_FUSE_NOTHING);
                break;
            case StellarTarotFuseResult::Ok:
                Say(handler, STELLAR_TAROT_STR_FUSE_OK,
                    isBoard ? sStellarTarotMgr->BoardName(crafted - STELLAR_TAROT_BOARD_ITEM_BASE)
                            : sStellarTarotMgr->CardName(crafted - STELLAR_TAROT_CARD_ITEM_BASE));
                break;
        }
        return true;
    }

    // Where cards and boards drop from, as loaded: every source, and the
    // three settings that govern them.
    // ===================== L'INSTRUMENT DE MESURE =====================
    //
    // Ce que le coeur cache depuis qu'il filtre lui-meme la chance et la
    // recharge : les procs REFUSES. Une aura TEMOIN par evenement, a chance 100
    // et sans recharge, les rend visibles. La commande compte alors les
    // OCCASIONS d'un cote, les DEPARTS de l'autre, et rend le verdict.
    static bool HandleCheckCommand(ChatHandler* handler, Optional<std::string> quoi)
    {
        Player* const player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return true;
        std::string const mot = quoi ? *quoi : "";
        if (mot == "stop")
        {
            StellarTarotEffects::MesureArrete(player);
            handler->PSendSysMessage("Tarot : mesure arretee, temoins retires.");
            return true;
        }
        if (mot == "start")
        {
            uint32 const lignes = StellarTarotEffects::MesureCommence(player);
            handler->PSendSysMessage("Tarot : mesure commencee sur %u ligne(s) a evenement. "
                                     "Frappez, puis `.tarot check`.", lignes);
            LOG_INFO("module", "StellarTarot CHECK: mesure commencee pour {} sur {} ligne(s).",
                     player->GetName(), lignes);
            return true;
        }
        if (!StellarTarotEffects::MesureEnCours(player))
        {
            handler->PSendSysMessage("Tarot : aucune mesure en cours. `.tarot check start` d'abord.");
            return true;
        }
        if (StellarTarotEffects::Mesure(player).empty())
        {
            handler->PSendSysMessage("Tarot : rien a mesurer -- aucune carte posee ne guette un "
                                     "evenement du systeme de procs (critique, esquive, parade, "
                                     "blocage, attaque ratee, critique de soin).");
            return true;
        }
        // LE VERDICT, ligne par ligne.
        bool tout = true;
        for (auto const& paire : StellarTarotEffects::Mesure(player))
        {
            uint32 const spellId = paire.first;
            StellarTarotEffects::Compte const& c = paire.second;
            // La ligne dit ce qu'elle promet ; le nom de la carte vient de la
            // liste des effets en force.
            std::string quoiDit = "?";
            int32 chance = 100, icd = 0;
            bool coreChance = false, coreIcd = false;
            uint32 carte = 0;
            uint8 niveau = 0;
            for (StellarTarotActiveEffect const& e : StellarTarotEffects::Active(player))
                if (e.spellId == spellId)
                {
                    carte = e.cardId;
                    niveau = e.level;
                    quoiDit = e.script;
                }
            StellarTarotEffects::PromesseDe(player, spellId, chance, icd, coreChance, coreIcd);
            // LA CHANCE : fourchette binomiale a trois ecarts-types.
            double const p = double(chance) / 100.0;
            // LA CHANCE SE JUGE SUR LES ELIGIBLES, la recharge refusant les
            // autres de son plein droit.
            double const attendu = double(c.eligibles) * p;
            double const sigma = std::sqrt(double(c.eligibles) * p * (1.0 - p));
            double const marge = std::max(3.0 * sigma, 1.0);
            // A CHANCE CERTAINE, une seule occasion suffit a juger.
            bool const assez = c.eligibles >= 30 || chance >= 100 || chance <= 0;
            bool const chanceOk = !assez ? true
                                : std::fabs(double(c.departs) - attendu) <= marge;
            // LA RECHARGE : jamais deux departs a moins de l'ICD annonce -- et
            // si rien ne l'a approchee, elle n'est pas eprouvee.
            bool const icdOk = !icd || c.departs < 2 || c.ecartMin + 50 >= uint32(icd) * 1000;
            tout = tout && chanceOk && icdOk;
            char const* const verdictChance = !c.eligibles ? "AUCUNE OCCASION"
                                            : !assez ? "ECHANTILLON INSUFFISANT"
                                            : chanceOk ? "ATTEINT" : "MANQUE";
            char const* const verdictIcd = !icd ? "sans objet"
                                         : c.departs < 2 ? "ECHANTILLON INSUFFISANT"
                                         : !icdOk ? "MANQUE"
                                         : (c.ecartMin > uint32(icd) * 2000 ? "ATTEINT (NON EPROUVE)"
                                                                            : "ATTEINT");
            handler->PSendSysMessage("carte %u N%u : %u occasions dont %u eligibles, %u departs "
                                     "(attendu %.1f, marge %.1f) -> chance %s", carte, uint32(niveau),
                                     c.occasions, c.eligibles, c.departs, attendu, marge, verdictChance);
            handler->PSendSysMessage("   ecart minimal %.1f s (ICD annonce %d s) -> %s%s",
                                     double(c.ecartMin) / 1000.0, icd, verdictIcd,
                                     coreIcd ? " [tenu par le coeur]" : " [tenu par le module]");
            if (c.revers)
                handler->PSendSysMessage("   revers tombe %u fois sur %u occasions", c.revers, c.occasions);
            LOG_INFO("module", "StellarTarot CHECK: carte {} N{} [{}] occasions={} departs={} "
                               "attendu={:.1f} marge={:.1f} chance={} ecartMin={:.1f}s icd={}s icd={} "
                               "revers={} chanceTenue={} icdTenu={}",
                     carte, uint32(niveau), quoiDit, c.occasions, c.departs, attendu, marge,
                     verdictChance, double(c.ecartMin) / 1000.0, icd, verdictIcd, c.revers,
                     coreChance ? "coeur" : "module", coreIcd ? "coeur" : "module");
        }
        handler->PSendSysMessage("Tarot : verdict d'ensemble -> %s", tout ? "ATTEINT" : "MANQUE");
        LOG_INFO("module", "StellarTarot CHECK: verdict d'ensemble pour {} -> {}",
                 player->GetName(), tout ? "ATTEINT" : "MANQUE");
        return true;
    }

    static bool HandleSourcesCommand(ChatHandler* handler)
    {
        if (!sStellarTarotMgr->Enabled())
        {
            Say(handler, STELLAR_TAROT_STR_DISABLED);
            return true;
        }
        std::vector<StellarTarotSource> const& sources = StellarTarotLoot::Sources();
        Say(handler, STELLAR_TAROT_STR_SOURCES_HEADER, sources.size(),
            StellarTarotLoot::Enabled() ? "on" : "off", StellarTarotLoot::Rate(),
            StellarTarotLoot::KnownMayDrop() ? "may drop" : "never drop");
        if (sources.empty())
        {
            Say(handler, STELLAR_TAROT_STR_SOURCES_NONE);
            return true;
        }
        for (StellarTarotSource const& source : sources)
            Say(handler, STELLAR_TAROT_STR_SOURCES_LINE, source.id, StellarTarotLoot::Describe(source));
        return true;
    }

    static bool HandleReloadCommand(ChatHandler* handler)
    {
        sStellarTarotMgr->Load();
        // A card changed under a character's feet: what everyone has is
        // computed again from the new catalogue.
        StellarTarotEffects::RefreshEveryone();
        Say(handler, STELLAR_TAROT_STR_RELOAD_OK,
            sStellarTarotMgr->Cards().size(), sStellarTarotMgr->Boards().size());
        return true;
    }

    // ===================== THE TEST BENCH =====================

    static Player* Tested(ChatHandler* handler, PlayerIdentifier& who)
    {
        if (!who.IsConnected())
        {
            Say(handler, STELLAR_TAROT_STR_PLAYER_NOT_FOUND);
            return nullptr;
        }
        return who.GetConnectedPlayer();
    }

    // One card level alone, in place of the board, test values armed.
    // cumulative: the levels below come too, when the card is cumulative.
    static bool HandleTestCardCommand(ChatHandler* handler, PlayerIdentifier who, uint32 cardId, uint32 level,
                                      Optional<std::string> mode)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        StellarTarotCard const* card = sStellarTarotMgr->Card(cardId);
        if (!card || level < 1 || level > card->effects.size())
        {
            Say(handler, STELLAR_TAROT_STR_TEST_NO_LEVEL, cardId, level);
            return true;
        }
        StellarTarotEffects::TestCard(player, cardId, uint8(level), mode && *mode == "cumulative");
        Say(handler, STELLAR_TAROT_STR_TEST_CARD, player->GetName(), cardId, sStellarTarotMgr->CardName(cardId), level);
        return true;
    }

    // Back to the board; the forced states, the hour and the probes go.
    static bool HandleTestClearCommand(ChatHandler* handler, PlayerIdentifier who)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        StellarTarotEffects::TestClear(player);
        StellarTarotEffects::ForceHour(-1);
        Say(handler, STELLAR_TAROT_STR_TEST_CLEAR, player->GetName());
        return true;
    }

    // A state word held (on), failed (off) or given back to the game (free).
    static bool HandleTestForceCommand(ChatHandler* handler, PlayerIdentifier who, std::string word, std::string mode)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        static std::set<std::string> const words = {
            "combat", "nocombat", "solo", "rested", "water", "indoors", "outdoors", "mounted", "walking",
            "running", "still", "shield", "twohand", "dualwield", "unarmed", "heirloom", "stunned",
            "controlled", "charmed", "slowed", "burning", "humanoid", "alone", "back" };
        int8 const state = mode == "on" ? 1 : mode == "off" ? 0 : mode == "free" ? -1 : -2;
        if (!words.count(word) || state == -2)
        {
            Say(handler, STELLAR_TAROT_STR_TEST_BAD_STATE, word, mode);
            return true;
        }
        StellarTarotEffects::Force(player, word, state);
        Say(handler, state == 1 ? STELLAR_TAROT_STR_TEST_HELD
                   : state == 0 ? STELLAR_TAROT_STR_TEST_FAILED : STELLAR_TAROT_STR_TEST_FREED,
            player->GetName(), word);
        return true;
    }

    // The hour every card reads, 0 to 23; -1 gives back the server's clock.
    static bool HandleTestHourCommand(ChatHandler* handler, int32 hour)
    {
        StellarTarotEffects::ForceHour(hour);
        if (StellarTarotEffects::ForcedHour() >= 0)
            Say(handler, STELLAR_TAROT_STR_TEST_HOUR, StellarTarotEffects::ForcedHour());
        else
            Say(handler, STELLAR_TAROT_STR_TEST_HOUR_OFF);
        return true;
    }

    static bool HandleTestHealthCommand(ChatHandler* handler, PlayerIdentifier who, uint32 pct)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        pct = std::min<uint32>(100, std::max<uint32>(1, pct));
        player->SetHealth(std::max<uint32>(1, player->CountPctFromMaxHealth(int32(pct))));
        Say(handler, STELLAR_TAROT_STR_TEST_HEALTH, player->GetName(), pct);
        return true;
    }

    static bool HandleTestManaCommand(ChatHandler* handler, PlayerIdentifier who, uint32 pct)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        pct = std::min<uint32>(100, pct);
        player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA) * pct / 100);
        Say(handler, STELLAR_TAROT_STR_TEST_MANA, player->GetName(), pct);
        return true;
    }

    // The probes: a log line and a chat line for every effect that fires.
    static bool HandleTestTraceCommand(ChatHandler* handler, PlayerIdentifier who, std::string mode)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        if (mode != "on" && mode != "off")
        {
            Say(handler, STELLAR_TAROT_STR_TEST_BAD_STATE, "trace", mode);
            return true;
        }
        StellarTarotEffects::Trace(player, mode == "on");
        Say(handler, mode == "on" ? STELLAR_TAROT_STR_TEST_TRACE_ON : STELLAR_TAROT_STR_TEST_TRACE_OFF,
            player->GetName());
        return true;
    }

    static bool HandleTestStatusCommand(ChatHandler* handler, PlayerIdentifier who)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        uint32 cardId = 0;
        uint8 level = 0;
        StellarTarotEffects::TestCardOf(player, cardId, level);
        std::string forced;
        for (auto const& [word, state] : StellarTarotEffects::ForcedStates(player))
            forced += (forced.empty() ? "" : ", ") + word + "=" + std::to_string(state);
        Say(handler, STELLAR_TAROT_STR_TEST_STATUS, player->GetName(), cardId, uint32(level),
            StellarTarotEffects::Tracing(player) ? 1 : 0, StellarTarotEffects::ForcedHour(),
            forced.empty() ? "-" : forced);
        return true;
    }

    // The creature the bench summons to be struck, to strike, to be healed: a
    // plain level 70 humanoid, with no script and no immunity.
    static constexpr uint32 BENCH_CREATURE = 5063;

    // The bench's own target, per player, kept while it lives.
    static std::map<ObjectGuid, ObjectGuid>& BenchTargets()
    {
        static std::map<ObjectGuid, ObjectGuid> targets;
        return targets;
    }

    // A creature summoned around the player. angle: 0 in front, pi behind.
    // hostile: faction 14, else the player's. hp: its maximum health, 0 to keep it.
    static Creature* SummonAround(Player* player, uint32 entry, float dist, float angle, uint32 ms, bool hostile,
                                  uint32 hp)
    {
        if (!sObjectMgr->GetCreatureTemplate(entry))
            return nullptr;
        Position const pos = player->GetNearPosition(dist, angle);
        Creature* creature = player->SummonCreature(entry, pos, TEMPSUMMON_TIMED_DESPAWN, ms);
        if (!creature)
            return nullptr;
        creature->SetFaction(hostile ? 14 : player->GetFaction());
        // The player's own level: a lower one misses its spells on him.
        creature->SetLevel(player->GetLevel());
        creature->SetReactState(REACT_PASSIVE);
        creature->SetRegeneratingHealth(false);
        if (hp)
        {
            creature->SetMaxHealth(hp);
            creature->SetFullHealth();
        }
        creature->SetFacingToObject(player);
        return creature;
    }

    // The target of the test blows: the bench's creature, in front of the
    // player, with health enough to take every blow of a run.
    static Unit* TestTarget(Player* player)
    {
        auto it = BenchTargets().find(player->GetGUID());
        if (it != BenchTargets().end())
            if (Creature* kept = ObjectAccessor::GetCreature(*player, it->second))
                if (kept->IsAlive() && kept->IsInWorld() && player->IsWithinDistInMap(kept, 30.0f))
                    return kept;
        Creature* target = SummonAround(player, BENCH_CREATURE, 4.0f, 0.0f, 3600000, true, 10000000);
        if (!target)
            return nullptr;
        target->SetArmor(0);
        BenchTargets()[player->GetGUID()] = target->GetGUID();
        return target;
    }

    // Turns the player to the unit, server side: the facing checks of a cast
    // read this orientation.
    static void Face(Player* player, Unit* unit)
    {
        if (unit && unit != player)
            player->SetOrientation(player->GetAngle(unit));
    }

    // A creature of that entry beside the player, hostile, killed by the player
    // through the core (kill hooks, loot, nearby death). Tells its loot.
    // The last creature the bench killed, per player: its corpse is read later.
    static std::map<ObjectGuid, ObjectGuid>& LastKills()
    {
        static std::map<ObjectGuid, ObjectGuid> kills;
        return kills;
    }

    static bool KillOne(Player* player, uint32 entry, std::string& loot)
    {
        Creature* creature = SummonAround(player, entry, 3.0f, 0.0f, 60000, true, 0);
        if (!creature)
            return false;
        LastKills()[player->GetGUID()] = creature->GetGUID();
        creature->LowerPlayerDamageReq(creature->GetMaxHealth());
        creature->SetLootRecipient(player);
        Unit::Kill(player, creature);
        loot = "gold " + std::to_string(creature->loot.gold) + ", items";
        for (LootItem const& item : creature->loot.items)
            loot += " " + std::to_string(item.itemid) + "x" + std::to_string(item.count);
        for (LootItem const& item : creature->loot.quest_items)
            loot += " " + std::to_string(item.itemid) + "x" + std::to_string(item.count);
        return true;
    }

    // An item in the bags, given when missing.
    static Item* Carried(Player* player, uint32 entry)
    {
        Item* item = player->GetItemByEntry(entry);
        if (!item && player->AddItem(entry, 1))
            item = player->GetItemByEntry(entry);
        return item;
    }

    // A cast as a player casts: not triggered, so that the cast hooks see it;
    // cooldowns and the global cooldown cleared first.
    static std::string CastAsPlayer(Player* player, Unit* target, uint32 spellId)
    {
        SpellInfo const* info = sSpellMgr->GetSpellInfo(spellId);
        if (!info)
            return "no such spell";
        player->RemoveSpellCooldown(spellId, true);
        player->GetGlobalCooldownMgr().CancelGlobalCooldown(info);
        Unit* on = info->IsPositive() || !target ? player : target;
        Face(player, on);
        return "cast result " + std::to_string(uint32(player->CastSpell(on, spellId, TRIGGERED_NONE)));
    }

    // An event of the game, handed to the player's cards. Real when the core can
    // play it (a blow, a cast, a heal, a kill, a death, an item used), through
    // the module's own relay otherwise. n: an amount, a spell, a creature or an
    // item entry, or a count, depending on the event.
    static bool HandleTestFireCommand(ChatHandler* handler, PlayerIdentifier who, std::string what, Optional<uint32> n)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        uint32 const value = n ? *n : 0;
        std::string result = "done";
        Unit* target = TestTarget(player);
        if (what == "swing")
        {
            if (!target)
                result = "no target";
            else
            {
                Face(player, target);
                player->EngageWithTarget(target);
                for (uint32 i = 0; i < std::max<uint32>(1, value); ++i)
                    player->AttackerStateUpdate(target, BASE_ATTACK, false, true);
            }
        }
        else if (what == "spell")
        {
            if (target)
            {
                Face(player, target);
                player->CastSpell(target, value ? value : 133, true);
            }
            else
                result = "no target";
        }
        // A cast as the player makes one: the cast hooks see it.
        else if (what == "cast")
            result = CastAsPlayer(player, target, value ? value : 42873);
        // A spell on a unit far in front of the player: 25 yards.
        else if (what == "far")
        {
            Creature* distant = SummonAround(player, BENCH_CREATURE, 25.0f, 0.0f, 30000, true, 1000000);
            if (!distant)
                result = "no far target";
            else
            {
                Face(player, distant);
                player->CastSpell(distant, value ? value : 133, true);
                result = "distance " + std::to_string(uint32(player->GetDistance(distant)));
            }
        }
        // Several hostile units around the player, for what strikes around.
        else if (what == "mobs")
        {
            uint32 const count = std::max<uint32>(1, value ? value : 3);
            for (uint32 i = 0; i < count; ++i)
                SummonAround(player, BENCH_CREATURE, 3.0f, float(2 * M_PI) * float(i) / float(count), 60000, true, 1000000);
            result = std::to_string(count) + " unit(s)";
        }
        // The bench's target killed by the player: what the player laid on it
        // dies with it.
        else if (what == "killtarget")
        {
            if (Creature* victim = target ? target->ToCreature() : nullptr)
            {
                victim->LowerPlayerDamageReq(victim->GetMaxHealth());
                victim->SetLootRecipient(player);
                Unit::Kill(player, victim);
                BenchTargets().erase(player->GetGUID());
            }
            else
                result = "no target";
        }
        // The bench's target at a single point of health: the next blow kills it.
        else if (what == "targetone")
        {
            if (target)
                target->SetHealth(1);
        }
        // The bench's target at n % health.
        else if (what == "targethp")
        {
            if (target)
                target->SetHealth(std::max<uint32>(1, target->CountPctFromMaxHealth(int32(value ? value : 100))));
        }
        // A fresh target: the one kept goes, the next blow summons another.
        else if (what == "newtarget")
        {
            auto it = BenchTargets().find(player->GetGUID());
            if (it != BenchTargets().end())
            {
                if (Creature* kept = ObjectAccessor::GetCreature(*player, it->second))
                    kept->DespawnOrUnsummon();
                BenchTargets().erase(it);
            }
        }
        else if (what == "selfhit")
            player->CastSpell(player, value ? value : 44998, true);
        // Blows the player takes from a creature: in front, in the back, or
        // certain to be critical (Recklessness on the striker).
        else if (what == "struck" || what == "struckback" || what == "struckcrit")
        {
            Creature* striker = SummonAround(player, BENCH_CREATURE, 2.0f, what == "struckback" ? float(M_PI) : 0.0f,
                                             20000, true, 1000000);
            if (!striker)
                result = "no striker";
            else
            {
                if (what == "struckcrit")
                    striker->AddAura(13847, striker);
                uint32 const before = player->GetHealth();
                for (uint32 i = 0; i < std::max<uint32>(1, value); ++i)
                    striker->AttackerStateUpdate(player, BASE_ATTACK, false, true);
                result = "health " + std::to_string(before) + " -> " + std::to_string(player->GetHealth());
            }
        }
        // A spell the player takes from a creature.
        else if (what == "struckspell")
        {
            Creature* caster = SummonAround(player, BENCH_CREATURE, 5.0f, 0.0f, 20000, true, 1000000);
            if (!caster)
                result = "no caster";
            else
            {
                uint32 const before = player->GetHealth();
                SpellCastResult const cast = caster->CastSpell(player, value ? value : 133, true);
                result = "cast result " + std::to_string(uint32(cast)) + ", health " + std::to_string(before) +
                         " -> " + std::to_string(player->GetHealth());
            }
        }
        else if (what == "taken" || what == "takenspell")
        {
            uint32 damage = value ? value : 500;
            if (target)
                StellarTarotEffects::OnDamage(target, player, damage, what == "takenspell",
                                              what == "takenspell" ? uint32(SPELL_SCHOOL_MASK_FIRE) : 1u, 0);
            result = "damage " + std::to_string(value ? value : 500) + " -> " + std::to_string(damage);
        }
        else if (what == "dealt")
        {
            uint32 damage = value ? value : 500;
            if (target)
                StellarTarotEffects::OnDamage(player, target, damage, false);
            result = "damage " + std::to_string(value ? value : 500) + " -> " + std::to_string(damage);
        }
        else if (what == "heal")
            player->CastSpell(player, value ? value : 2061, true);
        // A heal on a friendly creature beside the player, hurt (healother) or
        // at full health (healfull).
        else if (what == "healother" || what == "healfull")
        {
            Creature* ally = SummonAround(player, BENCH_CREATURE, 3.0f, float(M_PI) / 2.0f, 20000, false, 0);
            if (!ally)
                result = "no ally";
            else
            {
                if (what == "healother")
                    ally->SetHealth(ally->CountPctFromMaxHealth(50));
                uint32 const before = ally->GetHealth();
                SpellCastResult const cast = player->CastSpell(ally, value ? value : 2061, true);
                result = "cast result " + std::to_string(uint32(cast)) + ", ally health " + std::to_string(before) +
                         " -> " + std::to_string(ally->GetHealth()) + "/" + std::to_string(ally->GetMaxHealth());
            }
        }
        // A friendly creature heals the player.
        else if (what == "healedby")
        {
            Creature* healer = SummonAround(player, BENCH_CREATURE, 3.0f, float(M_PI) / 2.0f, 20000, false, 0);
            if (!healer)
                result = "no healer";
            else
            {
                uint32 const before = player->GetHealth();
                SpellCastResult const cast = healer->CastSpell(player, value ? value : 2061, true);
                result = "cast result " + std::to_string(uint32(cast)) + ", health " + std::to_string(before) +
                         " -> " + std::to_string(player->GetHealth());
            }
        }
        // A friendly creature beside the player at n % health, for 20 seconds.
        else if (what == "allylow")
        {
            Creature* ally = SummonAround(player, BENCH_CREATURE, 3.0f, float(M_PI) / 2.0f, 20000, false, 0);
            if (!ally)
                result = "no ally";
            else
            {
                ally->SetHealth(std::max<uint32>(1, ally->CountPctFromMaxHealth(int32(value ? value : 10))));
                result = "ally health " + std::to_string(ally->GetHealth()) + "/" + std::to_string(ally->GetMaxHealth());
            }
        }
        else if (what == "healed")
        {
            uint32 gain = value ? value : 1000;
            StellarTarotEffects::OnHeal(player, player, gain);
            result = "heal " + std::to_string(value ? value : 1000) + " -> " + std::to_string(gain);
        }
        else if (what == "trigger")
        {
            std::vector<uint32> const triggers = StellarTarotEffects::TestTriggers(player);
            for (uint32 aura : triggers)
                StellarTarotEffects::OnProc(player, aura, target, value ? value : 1000);
            result = std::to_string(triggers.size()) + " trigger(s)";
        }
        else if (what == "kill")
        {
            std::string loot;
            result = KillOne(player, value ? value : BENCH_CREATURE, loot) ? "killed, loot " + loot : "no such creature";
        }
        // The corpse of the last kill, read again: what was added after the death.
        else if (what == "corpse")
        {
            auto it = LastKills().find(player->GetGUID());
            Creature* corps = it == LastKills().end() ? nullptr : ObjectAccessor::GetCreature(*player, it->second);
            if (!corps)
                result = "no corpse";
            else
            {
                result = "gold " + std::to_string(corps->loot.gold) + ", lootable " +
                         std::to_string(corps->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE) ? 1 : 0) + ", items";
                for (LootItem const& item : corps->loot.items)
                    result += " " + std::to_string(item.itemid) + "x" + std::to_string(item.count);
            }
        }
        else if (what == "combat")
        {
            if (target)
                player->EngageWithTarget(target);
            StellarTarotEffects::OnEnterCombat(player);
        }
        // Out of combat, and standing: a seated player neither dodges nor
        // parries, and every blow on him is critical.
        else if (what == "leave")
        {
            player->CombatStop(true);
            player->RemoveAurasWithInterruptFlags(AURA_INTERRUPT_FLAG_NOT_SEATED);
            player->SetStandState(UNIT_STAND_STATE_STAND);
            StellarTarotEffects::OnLeaveCombat(player);
        }
        else if (what == "xp")
        {
            uint32 amount = value ? value : 1000;
            StellarTarotEffects::OnGiveXP(player, amount, 0);
            result = "xp " + std::to_string(value ? value : 1000) + " -> " + std::to_string(amount);
        }
        // Experience from a quest, a discovery, a battleground.
        else if (what == "xpquest" || what == "xpexplore" || what == "xpbg")
        {
            uint32 amount = value ? value : 1000;
            uint8 const source = what == "xpquest" ? 1 : what == "xpexplore" ? 3 : 4;
            StellarTarotEffects::OnGiveXP(player, amount, source);
            result = "xp " + std::to_string(value ? value : 1000) + " -> " + std::to_string(amount);
        }
        else if (what == "repquest")
        {
            float amount = float(value ? value : 100);
            StellarTarotEffects::OnGiveReputation(player, amount, uint8(REPUTATION_SOURCE_QUEST));
            result = "rep " + std::to_string(value ? value : 100) + " -> " + std::to_string(amount);
        }
        else if (what == "rep")
        {
            float amount = float(value ? value : 100);
            StellarTarotEffects::OnGiveReputation(player, amount, 0);
            result = "rep " + std::to_string(value ? value : 100) + " -> " + std::to_string(amount);
        }
        else if (what == "money")
        {
            uint32 copper = value ? value : 10000;
            StellarTarotEffects::OnLootMoney(player, copper);
            result = "copper " + std::to_string(value ? value : 10000) + " -> " + std::to_string(copper);
        }
        else if (what == "quest")
        {
            Quest const* quest = sObjectMgr->GetQuestTemplate(value);
            if (quest)
                StellarTarotEffects::OnQuestComplete(player, quest);
            else
                result = "no such quest";
        }
        else if (what == "zone")
            StellarTarotEffects::OnZone(player, player->GetZoneId(), player->GetAreaId());
        // Out of a capital, then into Thunder Bluff.
        else if (what == "capital")
        {
            StellarTarotEffects::OnZone(player, 215, 215);
            StellarTarotEffects::OnZone(player, 1638, 1638);
        }
        // Half of the durability of every piece worn, lost; or all of it mended.
        else if (what == "wear")
            player->DurabilityLossAll(0.5, false);
        else if (what == "repairall")
            player->DurabilityRepairAll(false, 0.0f, false);
        // An object of the world, opened: a chest, a herb, a vein. n: its entry.
        else if (what == "lootgo")
        {
            GameObjectTemplate const* info = sObjectMgr->GetGameObjectTemplate(value);
            GameObject* go = info ? player->SummonGameObject(value, player->GetPositionX() + 3.0f, player->GetPositionY(),
                                                             player->GetPositionZ(), 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 30)
                                  : nullptr;
            if (!go)
                result = "no such object";
            else
            {
                go->loot.clear();
                go->loot.FillLoot(info->GetLootId(), LootTemplates_Gameobject, player, true, true, LOOT_MODE_DEFAULT, go);
                result = "object loot " + std::to_string(info->GetLootId()) + ", items";
                for (LootItem const& item : go->loot.items)
                    result += " " + std::to_string(item.itemid) + "x" + std::to_string(item.count);
                go->DespawnOrUnsummon();
            }
        }
        // A loot filled from one of the core's tables, as a fishing bobber, a
        // skinned corpse or a prospected ore would fill it. n: the loot id.
        else if (what == "lootfish" || what == "lootskin" || what == "lootprospect")
        {
            LootStore const& store = what == "lootfish" ? LootTemplates_Fishing
                                   : what == "lootskin" ? LootTemplates_Skinning : LootTemplates_Prospecting;
            Loot loot;
            loot.FillLoot(value, store, player, true, true);
            result = "gold " + std::to_string(loot.gold) + ", items";
            for (LootItem const& item : loot.items)
                result += " " + std::to_string(item.itemid) + "x" + std::to_string(item.count);
            for (LootItem const& item : loot.quest_items)
                result += " " + std::to_string(item.itemid) + "x" + std::to_string(item.count);
        }
        else if (what == "repair")
        {
            float mod = 1.0f;
            StellarTarotEffects::OnRepairDiscount(player, ObjectGuid::Empty, mod);
            StellarTarotEffects::OnSpend(player);
            result = "repair price factor " + std::to_string(mod);
        }
        else if (what == "vendor")
        {
            float discount = 1.0f;
            StellarTarotEffects::OnVendorDiscount(player, discount);
            result = "vendor price factor " + std::to_string(discount);
        }
        // A purchase: the item lands in the bags, bought at its price.
        else if (what == "buy")
        {
            uint32 const entry = value ? value : 4540;
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry);
            uint32 const had = player->GetItemCount(entry);
            Item* item = proto && player->AddItem(entry, 1) ? player->GetItemByEntry(entry) : nullptr;
            if (!item)
                result = "no such item";
            else
            {
                uint64 const before = player->GetMoney();
                StellarTarotEffects::OnVendorBuy(player, item, 1, proto->BuyPrice);
                StellarTarotEffects::OnSpend(player);
                result = "paid " + std::to_string(proto->BuyPrice) + ", money back " +
                         std::to_string(int64(player->GetMoney()) - int64(before)) + ", count " +
                         std::to_string(had) + " -> " + std::to_string(player->GetItemCount(entry));
            }
        }
        // A sale: the item leaves the bags, and the vendor pays its price.
        else if (what == "sell")
        {
            uint32 const entry = value ? value : 7428;
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry);
            Item* item = proto ? Carried(player, entry) : nullptr;
            if (!item)
                result = "no such item";
            else
            {
                uint64 const before = player->GetMoney();
                StellarTarotEffects::OnSellItem(player, item);
                player->DestroyItemCount(entry, 1, true);
                player->ModifyMoney(int32(proto->SellPrice));
                result = "price " + std::to_string(proto->SellPrice) + ", received " +
                         std::to_string(int64(player->GetMoney()) - int64(before));
            }
        }
        // An item that enters the bags, as loot does.
        else if (what == "additem")
        {
            uint32 const entry = value ? value : 7428;
            uint32 const before = player->GetItemCount(entry);
            uint64 const money = player->GetMoney();
            result = player->AddItem(entry, 1) ? "count " + std::to_string(before) + " -> " +
                                                  std::to_string(player->GetItemCount(entry)) + ", money " +
                                                  std::to_string(int64(player->GetMoney()) - int64(money))
                                               : "no such item";
        }
        // An item used from the bags: a potion, a flask, food, a drink.
        else if (what == "useitem")
        {
            Item* item = Carried(player, value);
            if (!item)
                result = "no such item";
            else
            {
                SpellCastTargets targets;
                targets.SetUnitTarget(player);
                player->RemoveAllSpellCooldown();
                player->SetLastPotionId(0);
                player->CastItemUseSpell(item, targets, 1, 0);
            }
        }
        else if (what == "sold")
        {
            int32 amount = int32(value ? value : 10000);
            StellarTarotEffects::OnMoneyChanged(player, amount);
            result = "sale " + std::to_string(value ? value : 10000) + " -> " + std::to_string(amount);
        }
        else if (what == "auction")
        {
            uint32 profit = value ? value : 10000;
            StellarTarotEffects::OnAuctionSold(player, profit);
            result = "profit " + std::to_string(value ? value : 10000) + " -> " + std::to_string(profit);
        }
        else if (what == "auctionpost")
        {
            uint64 const before = player->GetMoney();
            StellarTarotEffects::OnSpend(player);
            StellarTarotEffects::OnAuctionPosted(player, value ? value : 10000);
            result = "money back " + std::to_string(int64(player->GetMoney()) - int64(before));
        }
        else if (what == "auctionwon")
        {
            uint64 const before = player->GetMoney();
            StellarTarotEffects::OnSpend(player);
            StellarTarotEffects::OnAuctionWon(player, value ? value : 10000);
            result = "money back " + std::to_string(int64(player->GetMoney()) - int64(before));
        }
        else if (what == "jump")
            StellarTarotEffects::OnJump(player);
        // n full turns on the spot, to the left (the orientation grows) or to the right.
        else if (what == "spinleft" || what == "spinright")
        {
            float const way = what == "spinleft" ? 1.0f : -1.0f;
            float o = player->GetOrientation();
            uint32 const steps = std::max<uint32>(1, value ? value : 1) * 16 + 1;
            for (uint32 i = 0; i <= steps; ++i)
            {
                StellarTarotEffects::OnFacing(player, player->GetPositionX(), player->GetPositionY(),
                                              Position::NormalizeOrientation(o), 0);
                o += way * float(2 * M_PI) / 16.0f;
            }
        }
        // Half a yard aside: the player has moved.
        else if (what == "nudge")
        {
            float const step = (value % 2) ? -0.5f : 0.5f;
            player->NearTeleportTo(player->GetPositionX() + step, player->GetPositionY(), player->GetPositionZ(),
                                   player->GetOrientation());
        }
        else if (what == "mount")
            player->CastSpell(player, value ? value : 580, true);
        else if (what == "dismount")
            player->RemoveAurasByType(SPELL_AURA_MOUNTED);
        // The player's pet: summoned (the water elemental), striking, killed.
        else if (what == "pet")
        {
            player->CastSpell(player, value ? value : 31687, true);
            result = player->GetPet() ? "pet " + std::to_string(player->GetPet()->GetEntry()) : "no pet";
        }
        else if (what == "pethit")
        {
            Pet* pet = player->GetPet();
            if (!pet || !target)
                result = "no pet";
            else
                for (uint32 i = 0; i < std::max<uint32>(1, value); ++i)
                    pet->AttackerStateUpdate(target, BASE_ATTACK, false, true);
        }
        // A heal on the player's pet: an ally a player may heal.
        else if (what == "healpet")
        {
            Pet* pet = player->GetPet();
            if (!pet)
                result = "no pet";
            else
            {
                uint32 const before = pet->GetHealth();
                SpellCastResult const cast = player->CastSpell(pet, 2061, true);
                result = "cast result " + std::to_string(uint32(cast)) + ", pet health " + std::to_string(before) +
                         " -> " + std::to_string(pet->GetHealth()) + "/" + std::to_string(pet->GetMaxHealth());
            }
        }
        else if (what == "pethp")
        {
            if (Pet* pet = player->GetPet())
                pet->SetHealth(std::max<uint32>(1, pet->CountPctFromMaxHealth(int32(value ? value : 50))));
            else
                result = "no pet";
        }
        else if (what == "petdie")
        {
            if (Pet* pet = player->GetPet())
                Unit::Kill(player, pet, false);
            else
                result = "no pet";
        }
        // A wand shot at the target, a wand worn first.
        else if (what == "shoot")
        {
            if (!player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_RANGED))
                player->EquipNewItem((INVENTORY_SLOT_BAG_0 << 8) | EQUIPMENT_SLOT_RANGED, value ? value : 28783, true);
            if (target)
            {
                Face(player, target);
                player->CastSpell(target, 5019, true);
            }
            else
                result = "no target";
        }
        else if (what == "death")
            StellarTarotEffects::OnDeath(player);
        else if (what == "resurrect")
            StellarTarotEffects::OnResurrect(player);
        // A true death and a true return.
        else if (what == "die")
        {
            if (player->IsAlive())
                Unit::Kill(player, player, false);
        }
        else if (what == "revive")
        {
            if (!player->IsAlive())
            {
                player->ResurrectPlayer(1.0f);
                player->SpawnCorpseBones();
            }
        }
        else if (what == "level")
            StellarTarotEffects::OnLevelChanged(player);
        else
            result = "unknown event";
        Say(handler, STELLAR_TAROT_STR_TEST_FIRED, player->GetName(), what, value, result);
        return true;
    }

    // An aura laid on the player (self), or on the bench's target: what a card
    // needs around it -- a critical strike, a dodge, a parry, the stacks another
    // level would have built. A negative id removes it.
    static bool HandleTestAuraCommand(ChatHandler* handler, PlayerIdentifier who, int32 spellId, Optional<std::string> on,
                                      Optional<uint32> stacks)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        Unit* unit = on && *on == "target" ? TestTarget(player) : player;
        if (!unit)
            return true;
        if (spellId < 0)
            unit->RemoveAurasDueToSpell(uint32(-spellId));
        else if (sSpellMgr->GetSpellInfo(uint32(spellId)))
        {
            // Laid by the player, as a card of his would lay it.
            Aura* aura = unit->GetAura(uint32(spellId));
            if (!aura)
                aura = player->AddAura(uint32(spellId), unit);
            if (aura && stacks && *stacks > 1)
                aura->SetStackAmount(uint8(std::min<uint32>(*stacks, 255)));
        }
        Say(handler, STELLAR_TAROT_STR_TEST_FIRED, player->GetName(), "aura", spellId,
            unit->HasAura(uint32(std::abs(spellId))) ? "present" : "absent");
        return true;
    }

    // The auras of a unit the player cast, and those of the module, as
    // id:stacks:amounts.
    static std::string AurasOf(Unit* unit, Player* player)
    {
        std::string auras;
        for (auto const& [spellId, application] : unit->GetAppliedAuras())
        {
            Aura const* aura = application->GetBase();
            bool const module = spellId >= 87000 && spellId <= 89999;
            bool const own = aura->GetCasterGUID() == player->GetGUID() && !aura->IsPassive();
            if (!module && !own)
                continue;
            std::string amounts;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (AuraEffect const* effect = aura->GetEffect(i))
                    amounts += (amounts.empty() ? "" : "/") + std::to_string(effect->GetAmount());
            auras += (auras.empty() ? "" : " ") + std::to_string(spellId) + ":" +
                     std::to_string(aura->GetStackAmount()) + ":" + (amounts.empty() ? "-" : amounts) + ":" +
                     std::to_string(aura->GetDuration() / 1000);
        }
        return auras.empty() ? "-" : auras;
    }

    // What can be measured of the player: health, mana, money, combat, and the
    // auras of the module (spell:stacks:amounts:seconds) and those the player
    // cast; then the same of the bench's target and of the pet.
    static bool HandleTestSnapshotCommand(ChatHandler* handler, PlayerIdentifier who)
    {
        Player* player = Tested(handler, who);
        if (!player)
            return true;
        std::string extra = AurasOf(player, player);
        auto it = BenchTargets().find(player->GetGUID());
        if (it != BenchTargets().end())
            if (Creature* target = ObjectAccessor::GetCreature(*player, it->second))
                extra += " | target " + std::to_string(target->GetHealth()) + "/" + std::to_string(target->GetMaxHealth()) +
                         " " + AurasOf(target, player);
        if (Pet* pet = player->GetPet())
            extra += " | pet " + std::to_string(pet->GetHealth()) + "/" + std::to_string(pet->GetMaxHealth()) +
                     " " + AurasOf(pet, player);
        std::string stats;
        for (uint8 s = STAT_STRENGTH; s < MAX_STATS; ++s)
            stats += (s ? "," : "") + std::to_string(int32(player->GetStat(Stats(s))));
        std::string ratings;
        for (uint8 cr = 0; cr < MAX_COMBAT_RATING; ++cr)
            ratings += (cr ? "," : "") + std::to_string(player->GetUInt32Value(uint16(PLAYER_FIELD_COMBAT_RATING_1) + cr));
        std::string resist;
        for (uint8 r = SPELL_SCHOOL_HOLY; r < MAX_SPELL_SCHOOL; ++r)
            resist += (r > SPELL_SCHOOL_HOLY ? "," : "") + std::to_string(player->GetResistance(SpellSchools(r)));
        std::string cooldowns;
        uint32 const now = GameTime::GetGameTimeMS().count();
        for (auto const& [spellId, cd] : player->GetSpellCooldownMap())
            if (cd.end > now)
                cooldowns += (cooldowns.empty() ? "" : ",") + std::to_string(spellId) + ":" + std::to_string(cd.end - now);
        extra += " | stats " + stats +
                 " | sp " + std::to_string(player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)) +
                 " heal " + std::to_string(player->SpellBaseHealingBonusDone(SPELL_SCHOOL_MASK_ALL)) +
                 " | ap " + std::to_string(int32(player->GetTotalAttackPowerValue(BASE_ATTACK))) +
                 " rap " + std::to_string(int32(player->GetTotalAttackPowerValue(RANGED_ATTACK))) +
                 " | armor " + std::to_string(player->GetArmor()) + " resist " + resist +
                 " | ratings " + ratings +
                 " | speed " + std::to_string(int32(player->GetSpeedRate(MOVE_RUN) * 100.0f)) +
                 " | cd " + (cooldowns.empty() ? "-" : cooldowns);
        // The durability of what the player wears, summed.
        uint32 usure = 0, usureMax = 0;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            if (Item const* piece = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
            {
                usure += piece->GetUInt32Value(ITEM_FIELD_DURABILITY);
                usureMax += piece->GetUInt32Value(ITEM_FIELD_MAXDURABILITY);
            }
        extra += " | durability " + std::to_string(usure) + "/" + std::to_string(usureMax);
        extra += " | cooldowns " + std::to_string(player->GetSpellCooldownMap().size()) +
                 " | alive " + std::to_string(player->IsAlive() ? 1 : 0) +
                 " | mounted " + std::to_string(player->IsMounted() ? 1 : 0) +
                 " | pos " + std::to_string(int32(player->GetPositionX() * 10)) + "," +
                 std::to_string(int32(player->GetPositionY() * 10));
        Say(handler, STELLAR_TAROT_STR_TEST_SNAPSHOT, player->GetName(), player->GetHealth(), player->GetMaxHealth(),
            player->GetPower(POWER_MANA), player->GetMaxPower(POWER_MANA), player->GetMoney(),
            player->IsInCombat() ? 1 : 0, extra);
        return true;
    }
};

void AddSC_stellar_tarot_commands()
{
    new stellar_tarot_commandscript();
}
