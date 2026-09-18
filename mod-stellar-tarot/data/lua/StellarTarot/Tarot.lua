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
    The stellar tarot, server side.

    THIS FILE DECIDES NOTHING. It serves the catalogue -- the module's tables
    in the world database, in the player's language -- the binder of the
    player's account and the layout of the character, and relays every
    gesture of the window to the module's `.tarot` commands, RUN AS THE
    PLAYER: every rule and every message lives there. The module's writes are
    synchronous, so the state read back here right after a command is what the
    command wrote.

    A card or a board is USED from the bags: the item carries a spell the
    client knows, the use reaches the server, and it is intercepted here before
    any cast -- the item never casts anything, the module studies it and
    destroys it.
------------------------------------------------------------------------------]]

local AIO = require("AIO")

local Handlers = AIO.AddHandlers("StellarTarot", {})

local fmt = string.format

-- The identifiers the module allocates (StellarTarotMgr.h): card N is item
-- CARD_BASE + N, board B is item BOARD_BASE + B.
local CARD_BASE = 902000
local BOARD_BASE = 902500

local LOCALE_FRFR = 2
local ITEM_EVENT_ON_USE = 2

-- The catalogue is served in the player's language: the item names come from
-- item_template_locale, the tag names and the effect texts from the module's
-- own locale tables. Anything without a row in that language is English.
local function Locale(player)
    return player:GetDbLocaleIndex() == LOCALE_FRFR and "frFR" or "enUS"
end

local function Text(q, index)
    if q:IsNull(index) then return nil end
    local s = q:GetString(index)
    return s ~= "" and s or nil
end

-- ---------------------------------------------------------------------------
-- The catalogue, read from the world database on every opening: the tables
-- are small and openings are rare, and a `.tarot reload` is then seen at once.
-- ---------------------------------------------------------------------------

local function Catalogue(locale)
    local cat = { cards = {}, boards = {}, tags = {} }
    local cards, boards = {}, {}

    local q = WorldDBQuery(fmt(
        "SELECT t.tag_id, t.name, l.name FROM mod_stellar_tarot_tag t "
        .. "LEFT JOIN mod_stellar_tarot_tag_locale l ON l.tag_id = t.tag_id AND l.locale = '%s' "
        .. "ORDER BY t.tag_id", locale))
    if q then
        repeat
            cat.tags[#cat.tags + 1] = { id = q:GetUInt32(0), name = Text(q, 2) or q:GetString(1) }
        until not q:NextRow()
    end

    -- WHAT A SCRIPT SAYS OF ITSELF: its row of module_string, in the player's
    -- language when there is one, with {} for each parameter of the column.
    local scriptTexts = {}
    q = WorldDBQuery(fmt(
        "SELECT s.name, m.string, l.string FROM mod_stellar_tarot_script s "
        .. "LEFT JOIN module_string m ON m.module = 'mod-stellar-tarot' AND m.id = s.string_id "
        .. "LEFT JOIN module_string_locale l ON l.module = 'mod-stellar-tarot' AND l.id = s.string_id AND l.locale = '%s'",
        locale))
    if q then
        repeat
            scriptTexts[q:GetString(0)] = Text(q, 2) or Text(q, 1)
        until not q:NextRow()
    end
    local function DescribeScript(column)
        if column == "" then return nil end
        local pieces = {}
        for piece in (column .. ":"):gmatch("([^:]*):") do pieces[#pieces + 1] = piece end
        local name = pieces[1] or column
        local text = scriptTexts[name]
        -- No row: the level's spell description says it all (the engine's
        -- families have none by design); the column stays for the tools.
        if not text then return { text = column, desc = "" } end
        local at = 1
        text = text:gsub("{}", function()
            at = at + 1
            return pieces[at] or "?"
        end)
        return { text = column, desc = text }
    end

    q = WorldDBQuery(fmt(
        "SELECT c.card_id, c.edge_top, c.edge_right, c.edge_bottom, c.edge_left, c.art, "
        .. "i.name, i.Quality, l.Name, c.cumulative, c.tag_id, "
        .. "c.card_spell_1, c.card_spell_2, c.card_spell_3, c.card_spell_4, "
        .. "c.card_script_1, c.card_script_2, c.card_script_3, c.card_script_4, "
        .. "c.hint, h.hint "
        .. "FROM mod_stellar_tarot_card c "
        .. "JOIN item_template i ON i.entry = %d + c.card_id "
        .. "LEFT JOIN item_template_locale l ON l.ID = i.entry AND l.locale = '%s' "
        .. "LEFT JOIN mod_stellar_tarot_card_locale h ON h.card_id = c.card_id AND h.locale = '%s' "
        .. "ORDER BY c.card_id", CARD_BASE, locale, locale))
    if q then
        repeat
            local id = q:GetUInt32(0)
            local card = {
                id = id, entry = CARD_BASE + id,
                edges = { q:GetUInt32(1), q:GetUInt32(2), q:GetUInt32(3), q:GetUInt32(4) },
                art = q:GetString(5),
                name = Text(q, 8) or q:GetString(6),
                quality = q:GetUInt32(7),
                cumulative = q:GetUInt32(9) ~= 0,
                tag = q:GetUInt32(10),
                hint = Text(q, 20) or q:GetString(19),
                spells = {}, scripts = {},
            }
            for level = 1, 4 do
                card.spells[level] = q:GetUInt32(10 + level)
                card.scripts[level] = DescribeScript(q:GetString(14 + level))
            end
            cards[id] = card
            cat.cards[#cat.cards + 1] = card
        until not q:NextRow()
    end

    q = WorldDBQuery(fmt(
        "SELECT b.board_id, b.row_count, b.col_count, b.art, i.name, i.Quality, l.Name "
        .. "FROM mod_stellar_tarot_board b "
        .. "JOIN item_template i ON i.entry = %d + b.board_id "
        .. "LEFT JOIN item_template_locale l ON l.ID = i.entry AND l.locale = '%s' "
        .. "ORDER BY b.board_id", BOARD_BASE, locale))
    if q then
        repeat
            local id = q:GetUInt32(0)
            local board = {
                id = id, entry = BOARD_BASE + id,
                rows = q:GetUInt32(1), cols = q:GetUInt32(2),
                art = q:GetString(3),
                name = Text(q, 6) or q:GetString(4),
                quality = q:GetUInt32(5),
                rowLeft = {}, rowRight = {}, colTop = {}, colBottom = {},
            }
            boards[id] = board
            cat.boards[#cat.boards + 1] = board
        until not q:NextRow()
    end

    -- axis 0 = a row (side 0 left, 1 right), axis 1 = a column (side 0 top,
    -- 1 bottom).
    q = WorldDBQuery("SELECT board_id, axis, idx, side, number FROM mod_stellar_tarot_board_line")
    if q then
        repeat
            local board = boards[q:GetUInt32(0)]
            if board then
                local axis, side = q:GetUInt32(1), q:GetUInt32(3)
                local list
                if axis == 0 then
                    list = side == 0 and board.rowLeft or board.rowRight
                else
                    list = side == 0 and board.colTop or board.colBottom
                end
                list[q:GetUInt32(2)] = q:GetUInt32(4)
            end
        until not q:NextRow()
    end

    -- LES SORTS DONT LE CLIENT CALCULE LES CHIFFRES LUI-MEME : leur texte porte
    -- un $s, et le client multiplie deja ce chiffre par les cumuls. L'addon ne
    -- doit donc pas le multiplier une seconde fois.
    cat.scaled = {}
    q = WorldDBQuery("SELECT Id FROM spell_dbc WHERE Id BETWEEN 902000 AND 903999 "
                     .. "AND (AuraDescription_Lang_enUS LIKE '%$s%' OR AuraDescription_Lang_koKR LIKE '%$s%')")
    if q then
        repeat
            cat.scaled[#cat.scaled + 1] = q:GetUInt32(0)
        until not q:NextRow()
    end
    return cat
end

-- ---------------------------------------------------------------------------
-- The binder of the player's account, and the layout of the character:
-- always read from the base, never cached.
-- ---------------------------------------------------------------------------

local function Binder(player)
    local account = player:GetAccountId()
    local binder = { cards = {}, boards = {} }
    local q = CharDBQuery(fmt(
        "SELECT card_id FROM mod_stellar_tarot_account_card WHERE account_id = %d ORDER BY card_id", account))
    if q then
        repeat binder.cards[#binder.cards + 1] = q:GetUInt32(0) until not q:NextRow()
    end
    q = CharDBQuery(fmt(
        "SELECT board_id FROM mod_stellar_tarot_account_board WHERE account_id = %d ORDER BY board_id", account))
    if q then
        repeat binder.boards[#binder.boards + 1] = q:GetUInt32(0) until not q:NextRow()
    end
    return binder
end

local function Layout(player)
    local guid = player:GetGUIDLow()
    local layout = { board = 0, cells = {}, presets = {} }
    local q = CharDBQuery(fmt(
        "SELECT board_id FROM mod_stellar_tarot_character_board WHERE guid = %d", guid))
    if q then layout.board = q:GetUInt32(0) end
    q = CharDBQuery(fmt(
        "SELECT row_idx, col_idx, card_id FROM mod_stellar_tarot_character_cell WHERE guid = %d", guid))
    if q then
        repeat
            layout.cells[#layout.cells + 1] = { row = q:GetUInt32(0), col = q:GetUInt32(1), card = q:GetUInt32(2) }
        until not q:NextRow()
    end
    q = CharDBQuery(fmt(
        "SELECT preset_id, name, board_id FROM mod_stellar_tarot_preset WHERE account_id = %d ORDER BY preset_id",
        player:GetAccountId()))
    if q then
        repeat
            layout.presets[#layout.presets + 1] = { id = q:GetUInt32(0), name = q:GetString(1), board = q:GetUInt32(2) }
        until not q:NextRow()
    end
    return layout
end

-- The client says hello once its side is loaded: it gets the catalogue, its
-- binder and its layout without the window opening -- what its tooltips need
-- from the first moment: what is already known, and what the board's aura
-- grants.
function Handlers.Hello(player)
    AIO.Handle(player, "StellarTarot", "Prime", Catalogue(Locale(player)), Binder(player), Layout(player))
end

function Handlers.Open(player)
    AIO.Handle(player, "StellarTarot", "Show", Catalogue(Locale(player)), Binder(player), Layout(player))
end

-- CE QUE LE SORT COUTE VRAIMENT. Le client sait calculer un coût, mais il
-- n'applique pas tout ce que le serveur lui envoie : un modificateur de coût
-- posé par une carte ne se voit dans ses infobulles que pour une poignée de
-- sorts. Il demande donc ici le chiffre, et le cœur le lui donne -- le sien,
-- celui qu'il prélèvera. Rien n'est recalculé de part et d'autre.
function Handlers.SpellCost(player, spellId)
    spellId = tonumber(spellId)
    if not spellId then return end
    local cost, power = player:GetSpellPowerCost(spellId)
    AIO.Handle(player, "StellarTarot", "SpellCost", spellId, cost, power)
end

-- ---------------------------------------------------------------------------
-- The gestures of the window. Each one is a command run as the player; the
-- layout is sent back afterwards, whatever the command said.
-- ---------------------------------------------------------------------------

local function Whole(v)
    return type(v) == "number" and math.floor(v) or -1
end

local function Relay(player, command)
    player:RunCommand(command)
    AIO.Handle(player, "StellarTarot", "Layout", Layout(player))
end

function Handlers.Equip(player, boardId)
    boardId = Whole(boardId)
    if boardId < 0 then return end
    Relay(player, fmt("tarot board %d", boardId))
end

function Handlers.Place(player, row, col, cardId)
    row, col, cardId = Whole(row), Whole(col), Whole(cardId)
    if row < 1 or col < 1 or cardId < 1 then return end
    Relay(player, fmt("tarot place %d %d %d", row, col, cardId))
end

function Handlers.Remove(player, row, col)
    row, col = Whole(row), Whole(col)
    if row < 1 or col < 1 then return end
    Relay(player, fmt("tarot remove %d %d", row, col))
end

-- A card of the board to another cell: a move, or a swap when that cell
-- is taken; the command decides, in one action.
function Handlers.Move(player, fromRow, fromCol, toRow, toCol)
    fromRow, fromCol, toRow, toCol = Whole(fromRow), Whole(fromCol), Whole(toRow), Whole(toCol)
    if fromRow < 1 or fromCol < 1 or toRow < 1 or toCol < 1 then return end
    Relay(player, fmt("tarot move %d %d %d %d", fromRow, fromCol, toRow, toCol))
end

function Handlers.Clear(player)
    Relay(player, "tarot clear")
end

-- A name travels as the tail of the command line: what could break it there
-- -- quotes, pipes, control characters -- is taken out before it goes.
function Handlers.PresetSave(player, name)
    if type(name) ~= "string" then return end
    name = name:gsub("[%c\"\\|]", ""):sub(1, 32)
    if name == "" then return end
    Relay(player, "tarot preset save " .. name)
end

function Handlers.PresetLoad(player, presetId)
    presetId = Whole(presetId)
    if presetId < 1 then return end
    Relay(player, fmt("tarot preset load %d", presetId))
end

function Handlers.PresetDelete(player, presetId)
    presetId = Whole(presetId)
    if presetId < 1 then return end
    Relay(player, fmt("tarot preset delete %d", presetId))
end

-- ---------------------------------------------------------------------------
-- A card or a board USED from the bags
-- ---------------------------------------------------------------------------

-- The module does the work and speaks to the player; the binder is then sent
-- back so that an open window, and the tooltips, follow. Returning false
-- stops the cast: the item's spell is a key the client needs, not an effect.
local function OnUse(_, player, item)
    if not player or not item then return false end
    player:RunCommand(fmt("tarot study %d", item:GetEntry()))
    AIO.Handle(player, "StellarTarot", "Binder", Binder(player))
    return false
end

-- Every card and every board of the catalogue is listened to. A card added
-- to the catalogue after this file was loaded needs a `.reload ale` to be
-- listened to as well.
local function Listen()
    local count = 0
    local q = WorldDBQuery("SELECT card_id FROM mod_stellar_tarot_card")
    if q then
        repeat
            RegisterItemEvent(CARD_BASE + q:GetUInt32(0), ITEM_EVENT_ON_USE, OnUse)
            count = count + 1
        until not q:NextRow()
    end
    q = WorldDBQuery("SELECT board_id FROM mod_stellar_tarot_board")
    if q then
        repeat
            RegisterItemEvent(BOARD_BASE + q:GetUInt32(0), ITEM_EVENT_ON_USE, OnUse)
            count = count + 1
        until not q:NextRow()
    end
    return count
end

print(fmt("StellarTarot: interface loaded, %d item(s) listened to.", Listen()))
