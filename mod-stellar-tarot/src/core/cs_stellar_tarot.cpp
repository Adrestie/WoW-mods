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
#include "CommandScript.h"
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

        static ChatCommandTable tarotTable =
        {
            { "info",   HandleInfoCommand,   SEC_GAMEMASTER,    Console::Yes },
            { "reload", HandleReloadCommand, SEC_ADMINISTRATOR, Console::Yes },
            // SEC_PLAYER: the paths of the interface (through RunCommand) --
            // every rule is applied inside.
            { "study",  HandleStudyCommand,  SEC_PLAYER,        Console::No  },
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

    // One level of a card, in a word: "spell 903004", "gold_on_kill:1234", or both.
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
};

void AddSC_stellar_tarot_commands()
{
    new stellar_tarot_commandscript();
}
