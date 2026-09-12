--[[
    This file is part of mod-stellar-tarot.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
    Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
]]

--[[----------------------------------------------------------------------------
    The tarot at the workbench: what the shared bench (lua_scripts/Workbench)
    can do with cards and boards.

      fuse_cards    3 cards, any of them   -> 1 card drawn from the whole catalogue
      fuse_boards   3 boards, any of them  -> 1 board drawn from the whole catalogue

    THIS FILE DECIDES NOTHING: it says which items are the tarot's and which
    combinations the bench may offer; the module's `.tarot fuse` command, run
    as the player, checks everything again, does the exchange and speaks.
------------------------------------------------------------------------------]]

local fmt = string.format

if not Workbench then
    print("StellarTarot: the shared workbench (lua_scripts/Workbench/Workbench.ext) is not loaded; no recipe registered.")
    return
end

-- The identifiers the module allocates (StellarTarotMgr.h): card N is item
-- CARD_BASE + N, board B is item BOARD_BASE + B.
local CARD_BASE = 902000
local BOARD_BASE = 902500

-- Which entries exist, read once from the catalogue: a card added later
-- needs a `.reload ale` to be known here.
local cards, boards = {}, {}
local q = WorldDBQuery("SELECT card_id FROM mod_stellar_tarot_card")
if q then
    repeat cards[CARD_BASE + q:GetUInt32(0)] = true until not q:NextRow()
end
q = WorldDBQuery("SELECT board_id FROM mod_stellar_tarot_board")
if q then
    repeat boards[BOARD_BASE + q:GetUInt32(0)] = true until not q:NextRow()
end

local function OnlyCards(entries)
    for _, e in ipairs(entries) do
        if not cards[e] then return false end
    end
    return true
end

local function OnlyBoards(entries)
    for _, e in ipairs(entries) do
        if not boards[e] then return false end
    end
    return true
end

local function AllCards(entries)
    return OnlyCards(entries) and #entries == 3
end

local function AllBoards(entries)
    return OnlyBoards(entries) and #entries == 3
end

-- What the bench shows as the result: a draw, so no particular card would
-- be honest -- the type's icon under the game's red question mark (the
-- module's own textures, data/art/Interface/mod-Tarot/Icons), and a word.
local LOCALE_FRFR = 2
local function Draw(icon, kind_en, kind_fr)
    return function(player)
        local fr = player:GetDbLocaleIndex() == LOCALE_FRFR
        return { icon = "Interface\\mod-Tarot\\Icons\\" .. icon,
                 text = fr and kind_fr or kind_en }
    end
end

Workbench.Register({
    module = "mod-stellar-tarot",
    Owns = function(entry)
        return cards[entry] or boards[entry] or false
    end,
    kinds = {
        { key = "card", name = { enUS = "Cards", frFR = "Cartes" },
          Of = function(entry) return cards[entry] == true end },
        { key = "board", name = { enUS = "Boards", frFR = "Plateaux" },
          Of = function(entry) return boards[entry] == true end },
    },
    recipes = {
        {
            key = "fuse_cards", slots = 3,
            name = { enUS = "Fusion: three cards, any of them, become one drawn at random.",
                     frFR = "Fusion : trois cartes, quelles qu'elles soient, deviennent une carte tirée au hasard." },
            Fits = function(_, placed, entry) return cards[entry] == true and OnlyCards(placed) end,
            Accepts = function(_, entries) return AllCards(entries) end,
            Preview = Draw("random_card", "A card drawn at random from the whole catalogue.",
                           "Une carte tirée au hasard dans tout le catalogue."),
            Run = function(player, entries)
                player:RunCommand(fmt("tarot fuse %d %d %d", entries[1], entries[2], entries[3]))
            end,
        },
        {
            key = "fuse_boards", slots = 3,
            name = { enUS = "Fusion: three boards, any of them, become one drawn at random.",
                     frFR = "Fusion : trois plateaux, quels qu'ils soient, deviennent un plateau tiré au hasard." },
            Fits = function(_, placed, entry) return boards[entry] == true and OnlyBoards(placed) end,
            Accepts = function(_, entries) return AllBoards(entries) end,
            Preview = Draw("random_board", "A board drawn at random from the whole catalogue.",
                           "Un plateau tiré au hasard dans tout le catalogue."),
            Run = function(player, entries)
                player:RunCommand(fmt("tarot fuse %d %d %d", entries[1], entries[2], entries[3]))
            end,
        },
    },
})
