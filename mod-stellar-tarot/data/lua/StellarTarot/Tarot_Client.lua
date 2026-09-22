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
    Stellar tarot — the window, client side (shipped by AIO).

    Three columns. THE DECK on the left: one tab per tag, standing on the left
    edge, and the grid of every card of the tab -- known and free, known and
    laid on the board (dimmed), or not yet known (a question mark). THE BOARD
    in the middle: the slot that equips one, the grid with the board's numbers
    around it, every card laid with its four edge numbers -- lit where they
    match -- and its level; the "remove all" button; the presets. THE CARD IN
    HAND on the right: what is hovered, large, with its edges and its four
    levels; under it, the effects active on the board.

    A card is laid by dragging it from the deck onto an empty cell, and taken
    off by a right-click. Nothing is decided here: every gesture is sent to
    the server, which runs the module's command as the player and sends the
    layout back. The levels are computed here as well, from the same rule the
    module applies, so that the drawing follows the gesture at once.

    A card the account already knows says so in its bag tooltip, in red, as a
    recipe already learnt does.

    The way in: /tarot. Texts bilingual according to the client's language.
    Everything the client draws is the game's own art: no texture is shipped.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- server side: we stop here
end

local Handlers = AIO.AddHandlers("StellarTarot", {})

local fmt, floor = string.format, math.floor

-- ---------------------------------------------------------------------------
-- Texts, in the client's language
-- ---------------------------------------------------------------------------

local FR = GetLocale() == "frFR"
local L = {
    title         = FR and "Tarot stellaire" or "Stellar Tarot",
    deck          = FR and "Deck" or "Deck",
    search        = FR and "Rechercher..." or "Search...",
    all           = FR and "Toutes" or "All",
    unknown       = FR and "Carte inconnue" or "Unknown card",
    cumulative    = FR and "Cumulatif" or "Cumulative",
    spell_unknown = FR and "sort n°%d" or "spell #%d",
    edges         = FR and "Bords : haut %d, droite %d, bas %d, gauche %d"
                       or "Edges: top %d, right %d, bottom %d, left %d",
    level         = FR and "(%d) %s" or "(%d) %s",
    combo         = FR and "%d : %s" or "%d: %s",             -- a line of the card's box
    combos        = FR and "Paires :" or "Pairs:",
    size          = FR and "%d ligne(s) x %d colonne(s)" or "%d row(s) x %d column(s)",
    row_numbers   = FR and "Chiffres des lignes : %s" or "Row numbers: %s",
    col_numbers   = FR and "Chiffres des colonnes : %s" or "Column numbers: %s",
    already_known = FR and "Déjà connu" or "Already known",
    on_board      = FR and "Posée sur le plateau" or "Laid on the board",
    board         = FR and "Plateau" or "Board",
    board_none    = FR and "Aucun plateau équipé" or "No board equipped",
    board_pick    = FR and "Cliquez pour choisir un plateau" or "Click to choose a board",
    board_take_off = FR and "Retirer le plateau" or "Take the board off",
    board_change  = FR and "Changer de plateau retire toutes les cartes."
                       or "Changing the board takes every card off.",
    remove_all    = FR and "Tout retirer" or "Remove all",
    remove_all_ask = FR and "Retirer toutes les cartes du plateau ?" or "Take every card off the board?",
    yes           = FR and "Retirer" or "Remove",
    cancel        = FR and "Annuler" or "Cancel",
    cell_empty    = FR and "Case vide" or "Empty cell",
    cell_hint     = FR and "Clic droit : retirer la carte" or "Right-click: take the card off",
    activation    = FR and "Activation : %d / 4" or "Activation: %d / 4",
    inert         = FR and "Inerte : aucun bord ne se raccorde." or "Inert: no edge matches.",
    highest_only  = FR and "Seul le niveau atteint s'applique." or "Only the level reached applies.",
    cumulative_long = FR and "Cumulatif : un niveau atteint conserve les précédents."
                       or "Cumulative: a level reached keeps the ones below.",
    presets       = FR and "Presets" or "Presets",
    preset_save   = FR and "Enregistrer" or "Save",
    preset_load   = FR and "Cliquez pour charger ce preset" or "Click to load this preset",
    preset_delete = FR and "Supprimer ce preset" or "Delete this preset",
    preset_none   = FR and "Aucun preset enregistré." or "No preset saved.",
    hand          = FR and "Aperçu" or "Preview",
    hand_empty    = FR and "Survolez une carte" or "Hover a card",
    effects       = FR and "Effets actifs" or "Active effects",
    effects_none  = FR and "Aucun effet actif." or "No active effect.",
    effects_wheel = FR and "Molette de la souris : faire défiler la liste."
                       or "Mouse wheel: scroll the list.",
    effect_line   = FR and "%s — niveau %d : %s" or "%s — level %d: %s",
}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local S = {
    cat = nil,          -- the catalogue, as the server sent it
    known = {},         -- card id -> true
    knownBoards = {},   -- board id -> true
    tab = 0,            -- the deck tab shown: a tag id, 0 for "All"
    layout = nil,       -- { board, cells = { {row, col, card} }, presets = { {id, name, board} } }
    placed = {},        -- card id -> true, the cards on the board
    acts = {},          -- row*10+col -> { card, matched, level, row, col }
    hover = nil,        -- { card, act } shown in the hand
    pinned = nil,       -- the card a click in the deck PINNED the hand on; nil: the hand follows the mouse
    drag = nil,         -- the card being dragged
    dragFrom = nil,     -- { row, col } when it comes from the board, nil from the deck
    projection = nil,   -- what the drag would do: { kind, card, row, col, from } -- see Project
    ui = nil,
}

-- WHAT THE TOOLTIPS READ. The hook below is installed once per session and
-- must see the CURRENT binder after every reload of this file, so the set of
-- known item entries lives in a global rather than in an upvalue.
STELLAR_TAROT_KNOWN = STELLAR_TAROT_KNOWN or {}

local function SetBinder(binder)
    S.known, S.knownBoards = {}, {}
    local entries = {}
    for _, id in ipairs(binder.cards or {}) do
        S.known[id] = true
        entries[902000 + id] = true
    end
    for _, id in ipairs(binder.boards or {}) do
        S.knownBoards[id] = true
        entries[902500 + id] = true
    end
    STELLAR_TAROT_KNOWN = entries
end

local function CardById(id)
    if not S.cat then return nil end
    for _, card in ipairs(S.cat.cards) do
        if card.id == id then return card end
    end
    return nil
end

local function BoardById(id)
    if not S.cat or not id or id == 0 then return nil end
    for _, board in ipairs(S.cat.boards) do
        if board.id == id then return board end
    end
    return nil
end

-- THE RULE OF A CELL, the same the module applies: a card faces four numbers
-- -- its neighbours' opposite edges, or the board's own on the rim -- and
-- every equality is a match. Edges are 1 top, 2 right, 3 bottom, 4 left.
local OPPOSITE = { 3, 4, 1, 2 }
local DROW = { -1, 0, 1, 0 }
local DCOL = { 0, 1, 0, -1 }

local function Activations(cells)
    local acts, placed = {}, {}
    local board = S.layout and BoardById(S.layout.board)
    if not board then return acts, placed end
    cells = cells or S.layout.cells
    local grid = {}
    for _, cell in ipairs(cells) do
        grid[cell.row * 10 + cell.col] = CardById(cell.card)
    end
    for _, cell in ipairs(cells) do
        local card = grid[cell.row * 10 + cell.col]
        if card then
            placed[card.id] = true
            local matched, level = {}, 0
            for e = 1, 4 do
                local nr, nc = cell.row + DROW[e], cell.col + DCOL[e]
                local facing
                if nr < 1 then
                    facing = board.colTop[cell.col]
                elseif nr > board.rows then
                    facing = board.colBottom[cell.col]
                elseif nc < 1 then
                    facing = board.rowLeft[cell.row]
                elseif nc > board.cols then
                    facing = board.rowRight[cell.row]
                else
                    local other = grid[nr * 10 + nc]
                    facing = other and other.edges[OPPOSITE[e]] or 0
                end
                matched[e] = card.edges[e] == facing
                if matched[e] then level = level + 1 end
            end
            acts[cell.row * 10 + cell.col] = { card = card, matched = matched, level = level,
                                               row = cell.row, col = cell.col }
        end
    end
    return acts, placed
end

-- ---------------------------------------------------------------------------
-- Items the client has never seen have neither name nor icon: GetItemInfo
-- asks the server on the spot and the answer lands a moment later. The
-- unknown ones are asked for, and the window redraws itself when the answers
-- arrive.
-- ---------------------------------------------------------------------------

local WAITING = {}
local Refresh
local RefreshDeck

local function Prime(entry)
    if not S.ui or GetItemInfo(entry) or WAITING[entry] then return end
    WAITING[entry] = true
    local ui = S.ui
    if not ui.probe then
        ui.probe = CreateFrame("GameTooltip", "StellarTarotProbe", nil, "GameTooltipTemplate")
        ui.waiter = CreateFrame("Frame")
        ui.waiter.elapsed = 0
        ui.waiter:SetScript("OnUpdate", function(self, delta)
            self.elapsed = self.elapsed + (delta or 0)
            if self.elapsed < 0.2 then return end
            self.elapsed = 0
            local left, arrived = false, false
            for e in pairs(WAITING) do
                if GetItemInfo(e) then
                    WAITING[e] = nil
                    arrived = true
                else
                    left = true
                end
            end
            if arrived and ui.frame:IsShown() then Refresh() end
            if not left then self:Hide() end
        end)
    end
    ui.probe:SetOwner(UIParent, "ANCHOR_NONE")
    ui.probe:SetHyperlink("item:" .. entry)
    ui.probe:Hide()
    ui.waiter.elapsed = 0
    ui.waiter:Show()
end

local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local ItemIcon

-- A card's icon: cut from its own illustration when it has one (`art`,
-- the texture path without extension: the icon is `<art>_icon`), else the
-- icon of its item.
local function CardIcon(card)
    if card.art and card.art ~= "" then return card.art .. "_icon" end
    return ItemIcon(card.entry)
end

function ItemIcon(entry)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(entry)
    if not texture then Prime(entry) end
    return texture or UNKNOWN_ICON
end

local function QualityColor(quality)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- The numbers of one axis, both sides: "1/7, 4/4, 8/2" for three rows read
-- left/right, or three columns read top/bottom.
local function Join(first, second)
    local out = {}
    for i, v in ipairs(first) do out[i] = tostring(v) .. "/" .. tostring(second[i] or "?") end
    return table.concat(out, ", ")
end

-- ---------------------------------------------------------------------------
-- What a level says: the spell's own tooltip text, read from the client's
-- Spell.dbc through a hidden tooltip, and/or the script's description sent
-- by the server. A spell the client has no row for is named by its number.
-- ---------------------------------------------------------------------------

local SPELL_TEXT = {}

-- Defined with the aura's tooltip, below; the hand uses them too.
-- LES MOTS QUE L'ADDON LIT DANS LES PHRASES DES CARTES. Le texte arrive dans
-- la LANGUE DU CLIENT : ces mots-la doivent donc exister dans les deux, sans
-- quoi rien ne se reconnait -- ni la mesure par niveau, ni les termes a
-- separer, ni la clause de nuit.
local MOTS = FR and {
    par_niveau = "niveau du joueur",
    et         = "et",
    mais       = "mais",
    seuil      = " sous ",                       -- « -10% sous 60% PV »
    nuit_seule = { ",%s*[Ll]a nuit uniquement",
                   "^[Dd]e nuit uniquement%s*[,:]%s*",
                   "^[Ll]a nuit uniquement%s*[,:]%s*",
                   "^[Nn]uit uniquement%s*[,:]%s*" },
    nuit_chiffre = { "%(([%-%+]?%d+)%%%s+de nuit%)",
                     ",%s*([%-%+]?%d+)%%%s+la nuit" },
    nuit_retrait = { "%s*%([%-%+]?%d+%%%s+de nuit%)",
                     ",%s*[%-%+]?%d+%%%s+la nuit" },
} or {
    par_niveau = "per player level",
    et         = "and",
    mais       = "but",
    seuil      = " under ",
    nuit_seule = { ",%s*[Aa]t night only",
                   "^[Aa]t night only%s*[,:]%s*",
                   "^[Nn]ight only%s*[,:]%s*",
                   -- « At night, ... » : la meme clause, dite plus court
                   "^[Aa]t night%s*[,:]%s*" },
    nuit_chiffre = { "%(([%-%+]?%d+)%%%s+at night%)",
                     ",%s*([%-%+]?%d+)%%%s+at night" },
    nuit_retrait = { "%s*%([%-%+]?%d+%%%s+at night%)",
                     ",%s*[%-%+]?%d+%%%s+at night" },
}

local SplitCondition, Lower, ScaledBonus
local PROC_SPELLS                -- buff name -> spell id of a proc, built from the catalogue

-- HOW AN EFFECT READS. The designer's text names the chances and the internal
-- cooldowns; the player is not shown them. And a plain change of a value is
-- written as a signed number: "augmente la force de 1%" reads "+1% force".
local ARTICLES = { "les scores de ", "le score de ", "les scores d'", "le score d'",
                   "les ", "le ", "la ", "l'", "vos ", "votre " }
local function StripArticle(what)
    for _, a in ipairs(ARTICLES) do
        if what:sub(1, #a) == a then what = what:sub(#a + 1) break end
    end
    -- "force, l'agilité et l'endurance" -> "force, agilité et endurance"
    what = what:gsub(", l[ae]s? ", ", "):gsub(", l'", ", "):gsub(" et l[ae]s? ", " et "):gsub(" et l'", " et ")
    what = what:gsub(" et de ", " et "):gsub(" et d'", " et ")
    return what
end
local SHORT = {
    { " par niveau du joueur", "/niv." },
    { "supplémentaires", "suppl." },
    { "supplémentaire", "suppl." },
    { "cumulable", "cumul." },
    { "Cumulable", "cumul." },
    { "temps de recharge", "recharge" },
    { "les membres du groupe à moins de", "le groupe à" },
    { "les membres du groupe à", "le groupe à" },
    { "les membres de votre groupe à", "le groupe à" },
    { "de vos PV max", "PV max" },
    { "des PV max", "PV max" },
    { "%% de PV", "%% PV" },
    { "secondes", "s" },
    { "seconde", "s" },
    { "minutes", "min" },
    { "minute", "min" },
    { "pendant", "pdt" },
}
local function Pretty(text)
    if not text then return text end
    -- "(10% de chance, 8 sec d'ICD)", "(100% de chance)", "(3 sec d'ICD)": gone.
    text = text:gsub("%s*%b()", function(p)
        if p:find("chance") or p:find("ICD") then return "" end
    end)
    -- ... and one never closed, to the end of the text.
    text = text:gsub("%s*%([^()]*$", function(p)
        if p:find("chance") or p:find("ICD") then return "" end
    end)
    -- "5% de chance de" -> "une chance de"
    text = text:gsub("%d+[%.,]?%d*%s*%% de chances? (d[e'])", "une chance %1")
    text = text:gsub("%d+[%.,]?%d*%s*%% de chances? (qu')", "une chance %1")
    -- "augmente la force de 1%" -> "+1% force" ; "réduit les dégâts subis de 3%" -> "-3% dégâts subis"
    text = text:gsub("[Aa]ugmente (.-) de (%d+[%.,]?%d*%%?)", function(what, n)
        return "+" .. n .. " " .. StripArticle(what)
    end)
    text = text:gsub("[Rr]éduit (.-) de (%d+[%.,]?%d*%%?)", function(what, n)
        return "-" .. n .. " " .. StripArticle(what)
    end)
    -- Then the SHORT FORMS: the box on the card is small.
    text = text:gsub("ont une chance de ", "peuvent "):gsub("ont une chance d'", "peuvent ")
    text = text:gsub("a une chance de ", "peut "):gsub("a une chance d'", "peut ")
    text = text:gsub("à une chance de ", "peut "):gsub("à une chance d'", "peut ")
    -- "chance d'appliquer ..." at the start, "chance quand ..."
    text = text:gsub("^[Cc]hance de ", "peut "):gsub("^[Cc]hance d'", "peut "):gsub("^[Cc]hance quand ", "quand ")
    text = text:gsub("quand vos PV passent sous (%d+)%%", "sous %1%% PV")
    for _, pair in ipairs(SHORT) do
        text = text:gsub(pair[1], pair[2])
    end
    text = text:gsub(" sec([%s%),])", " s%1"):gsub(" sec$", " s"):gsub("(%d) sec%.", "%1 s.")
    text = text:gsub("(le groupe à %d+ m) gagnent", "%1 gagne")
    text = text:gsub(" pdt (%d+ s)", ", %1"):gsub(" pdt (%d+ min)", ", %1"):gsub(" pdt (%d+)%.", ", %1 s.")
    text = text:gsub("subits", "subis"):gsub(" %.", "."):gsub("%.%.", ".")
    text = text:gsub("[Cc]umul%. (%d+) fois", "%1 cumul.")
    text = text:gsub("  +", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function SpellText(spellId)
    if SPELL_TEXT[spellId] then return SPELL_TEXT[spellId] end
    local text
    if GetSpellInfo(spellId) then
        local probe = _G["StellarTarotSpellProbe"]
            or CreateFrame("GameTooltip", "StellarTarotSpellProbe", nil, "GameTooltipTemplate")
        probe:SetOwner(UIParent, "ANCHOR_NONE")
        probe:SetHyperlink("spell:" .. spellId)
        -- Line 1 is the name; the cast time ("Instant", "2 sec cast") and
        -- the range are not the description either.
        local skip = { [SPELL_CAST_TIME_INSTANT or "Instant"] = true,
                       [SPELL_CAST_TIME_INSTANT_NO_MANA or "Instant"] = true }
        local lines = {}
        for i = 2, probe:NumLines() do
            local line = _G["StellarTarotSpellProbeTextLeft" .. i]
            local s = line and line:GetText()
            if s and s ~= "" and not skip[s] and not (i == 2 and s:find("%d")) then
                lines[#lines + 1] = s
            end
        end
        probe:Hide()
        text = #lines > 0 and table.concat(lines, " ") or GetSpellInfo(spellId)
    else
        text = fmt(L.spell_unknown, spellId)
    end
    text = Pretty(text)
    SPELL_TEXT[spellId] = text
    return text
end

local function LevelText(card, level)
    local parts = {}
    local spell = card.spells and card.spells[level] or 0
    if spell and spell ~= 0 then parts[#parts + 1] = SpellText(spell) end
    local script = card.scripts and card.scripts[level]
    if script and script.desc ~= "" then parts[#parts + 1] = script.desc end
    return #parts > 0 and table.concat(parts, " ") or "-"
end

-- ---------------------------------------------------------------------------
-- Tooltips
-- ---------------------------------------------------------------------------

-- WHAT A CARD IS CALLED. Every card carries a number for the players, "1."
-- onwards in the order of the catalogue -- a name to point at a card by,
-- known or not. It is not the card's identifier: the module never reads it.
local function Label(card)
    if S.known[card.id] then
        return fmt("%d. %s", card.no or 0, card.name)
    end
    return fmt("%d. %s", card.no or 0, L.unknown)
end

-- A known card: its name, "Cumulative" when it is, and what each of its four
-- levels does -- nothing else. A card not yet known: its number, and the
-- hint to find it -- nothing of what it does.
local function CardTooltip(button)
    local card = button.card
    if not card then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if not S.known[card.id] then
        GameTooltip:SetText(Label(card), 0.8, 0.2, 0.2)
        GameTooltip:AddLine(card.hint and card.hint ~= "" and card.hint or "-", 1, 1, 1, true)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetText(Label(card), QualityColor(card.quality))
    GameTooltip:AddLine(" ")
    if card.cumulative then
        GameTooltip:AddLine(L.cumulative, 1, 0.82, 0)
    end
    -- One line per level, never wrapped: the tooltip widens to fit.
    for level = 1, 4 do
        GameTooltip:AddLine(fmt(L.level, level, LevelText(card, level)), 1, 1, 1, false)
    end
    GameTooltip:Show()
end

local function BoardTooltip(button)
    local board = button.board
    if not board then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(board.name, QualityColor(board.quality))
    GameTooltip:AddLine(fmt(L.size, board.rows, board.cols), 1, 1, 1, true)
    GameTooltip:AddLine(fmt(L.row_numbers, Join(board.rowLeft, board.rowRight)), 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(fmt(L.col_numbers, Join(board.colTop, board.colBottom)), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- A board previewed: the grid, small, with its numbers around it -- what a
-- tooltip cannot draw, so a frame of its own, shown beside what is hovered.
-- ---------------------------------------------------------------------------

local PREVIEW_CELL, PREVIEW_GAP, PREVIEW_RIM = 22, 2, 14

local function PreviewFrame()
    local ui = S.ui
    if ui.preview then return ui.preview end
    local frame = CreateFrame("Frame", "StellarTarotBoardPreview", UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.name:SetPoint("TOPLEFT", 10, -8)
    frame.size = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.size:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -2)
    frame.grid = CreateFrame("Frame", nil, frame)
    frame.grid:SetPoint("TOP", frame.size, "BOTTOM", 0, -6)
    frame.cells, frame.rims = {}, { left = {}, right = {}, top = {}, bottom = {} }
    for i = 1, 16 do
        local cell = frame.grid:CreateTexture(nil, "ARTWORK")
        cell:SetSize(PREVIEW_CELL, PREVIEW_CELL)
        cell:SetTexture(0.2, 0.2, 0.25, 1)
        frame.cells[i] = cell
    end
    for _, side in pairs(frame.rims) do
        for i = 1, 4 do
            local text = frame.grid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetTextColor(1, 0.82, 0)
            side[i] = text
        end
    end
    frame:Hide()
    ui.preview = frame
    return frame
end

local function ShowPreview(board, anchor)
    local frame = PreviewFrame()
    frame.name:SetText(board.name)
    frame.name:SetTextColor(QualityColor(board.quality))
    frame.size:SetText(fmt(L.size, board.rows, board.cols))
    local step = PREVIEW_CELL + PREVIEW_GAP
    local width, height = board.cols * step - PREVIEW_GAP, board.rows * step - PREVIEW_GAP
    frame.grid:SetSize(width + 2 * PREVIEW_RIM, height + 2 * PREVIEW_RIM)
    for i, cell in ipairs(frame.cells) do
        local r, c = floor((i - 1) / 4) + 1, (i - 1) % 4 + 1
        if r <= board.rows and c <= board.cols then
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", frame.grid, "TOPLEFT",
                          PREVIEW_RIM + (c - 1) * step, -PREVIEW_RIM - (r - 1) * step)
            cell:Show()
        else
            cell:Hide()
        end
    end
    for _, side in pairs(frame.rims) do for _, t in ipairs(side) do t:Hide() end end
    for r = 1, board.rows do
        local y = -PREVIEW_RIM - (r - 1) * step - PREVIEW_CELL / 2
        frame.rims.left[r]:ClearAllPoints()
        frame.rims.left[r]:SetPoint("CENTER", frame.grid, "TOPLEFT", PREVIEW_RIM / 2, y)
        frame.rims.left[r]:SetText(board.rowLeft[r])
        frame.rims.left[r]:Show()
        frame.rims.right[r]:ClearAllPoints()
        frame.rims.right[r]:SetPoint("CENTER", frame.grid, "TOPLEFT", PREVIEW_RIM + width + PREVIEW_RIM / 2, y)
        frame.rims.right[r]:SetText(board.rowRight[r])
        frame.rims.right[r]:Show()
    end
    for c = 1, board.cols do
        local x = PREVIEW_RIM + (c - 1) * step + PREVIEW_CELL / 2
        frame.rims.top[c]:ClearAllPoints()
        frame.rims.top[c]:SetPoint("CENTER", frame.grid, "TOPLEFT", x, -PREVIEW_RIM / 2)
        frame.rims.top[c]:SetText(board.colTop[c])
        frame.rims.top[c]:Show()
        frame.rims.bottom[c]:ClearAllPoints()
        frame.rims.bottom[c]:SetPoint("CENTER", frame.grid, "TOPLEFT", x, -PREVIEW_RIM - height - PREVIEW_RIM / 2)
        frame.rims.bottom[c]:SetText(board.colBottom[c])
        frame.rims.bottom[c]:Show()
    end
    local textWidth = math.max(frame.name:GetStringWidth(), frame.size:GetStringWidth())
    frame:SetSize(math.max(width + 2 * PREVIEW_RIM, textWidth) + 20,
                  8 + frame.name:GetStringHeight() + 2 + frame.size:GetStringHeight() + 6
                  + height + 2 * PREVIEW_RIM + 10)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    frame:Show()
end

local function HidePreview()
    if S.ui and S.ui.preview then S.ui.preview:Hide() end
end

-- ---------------------------------------------------------------------------
-- The card in hand: the right column
-- ---------------------------------------------------------------------------

local GREEN, CYAN, RED = { 0.2, 1, 0.2 }, { 0, 1, 1 }, { 1, 0.25, 0.25 }
-- The inks on the card frame's parchment.
local PARCHMENT_INK = { 0.18, 0.11, 0.04 }
local PARCHMENT_GREEN_HEX, PARCHMENT_TEAL_HEX, PARCHMENT_FADED_HEX = "0d660d", "005973", "615242"
local PARCHMENT_INK_HEX = "2e1c0a"

-- The block of levels: its lines left-aligned, the block itself as wide
-- as its widest line and centred, both ways, in the room the box leaves
-- it -- never closer to the box's edge than the margin.
local LEVELS_LIFT = 6                       -- pixels the block sits above the exact centre

-- LES LIGNES DE LA CARTE, une par FontString. C'est le seul moyen d'avoir une
-- condition en gras, un effet indente dont le repli respecte son indentation,
-- et un bloc serre a gauche et en haut : un texte d'un seul tenant n'a qu'une
-- police, une marge et un centrage.
local LIGNE_RETRAIT, LIGNE_AIR = 14, 4

local function PoserLignes(entrees)
    local ui = S.ui
    local box, child = ui.handLevelsBox, ui.handScrollChild
    if not box then return end
    ui.handLines = ui.handLines or {}
    ui.handBold = ui.handBold or {}
    local haut = LIGNE_AIR              -- un peu d'air sous le mot « Paires »
    for i, e in ipairs(entrees) do
        local fs = ui.handLines[i]
        if not fs then
            fs = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            fs:SetShadowOffset(0, 0)
            ui.handLines[i] = fs
        end
        local police, taille = fs:GetFont()
        fs:SetFont(police, taille, "")
        local retrait = e.indent and LIGNE_RETRAIT or 0
        fs:SetWidth(box.width - retrait)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", child, "TOPLEFT", retrait, -haut)
        fs:SetText(e.text or "")
        fs:Show()
        -- LE GRAS, SANS TOUCHER A LA COULEUR : la meme ligne ecrite une
        -- seconde fois a un pixel d'ecart. Le contour du client est NOIR et
        -- salirait l'encre du parchemin.
        local gras = ui.handBold[i]
        if e.bold then
            if not gras then
                gras = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                gras:SetJustifyH("LEFT")
                gras:SetJustifyV("TOP")
                gras:SetShadowOffset(0, 0)
                ui.handBold[i] = gras
            end
            gras:SetFont(police, taille, "")
            gras:SetWidth(box.width - retrait)
            gras:ClearAllPoints()
            gras:SetPoint("TOPLEFT", child, "TOPLEFT", retrait + 1, -haut)
            gras:SetText(e.text or "")
            gras:Show()
        elseif gras then
            gras:Hide()
        end
        haut = haut + (fs:GetStringHeight() or 0)
    end
    -- LE MENAGE SE FAIT SUR LA TABLE ENTIERE : celle des secondes frappes est
    -- CREUSE -- seules les lignes en gras en ont une -- et « # » ne dit rien
    -- d'une table a trous.
    for i, fs in pairs(ui.handLines) do
        if i > #entrees then
            fs:SetText("")
            fs:Hide()
        end
    end
    for i, gras in pairs(ui.handBold) do
        if i > #entrees or not entrees[i].bold then
            gras:SetText("")
            gras:Hide()
        end
    end
    child:SetHeight(math.max(box.room, haut + 2))
    ui.handScroll:SetVerticalScroll(0)
    ui.handScroll:UpdateScrollChildRect()
end

-- The activation of a card on the board, if it is laid.
local function ActOf(card)
    if not card then return nil end
    for _, a in pairs(S.acts) do
        if a.card.id == card.id then return a end
    end
    return nil
end

local function ShowHand(card, act, tint)
    local ui = S.ui
    tint = tint or GREEN
    S.hover = card and { card = card, act = act } or nil
    if not card then
        ui.handIcon:Hide()
        ui.handName:SetText(L.hand_empty)
        ui.handName:SetTextColor(0.45, 0.4, 0.35)
        for e = 1, 4 do ui.handEdges[e]:SetText("") end
        ui.handMode:SetText("")
        if ui.handModeBold then ui.handModeBold:SetText("") end
        ui.handPairs:SetText("")
        PoserLignes({})
        return
    end
    ui.handIcon:SetTexture((card.art and card.art ~= "") and card.art or CardIcon(card))
    ui.handIcon:Show()
    ui.handName:SetText(Label(card))
    ui.handName:SetTextColor(PARCHMENT_INK[1], PARCHMENT_INK[2], PARCHMENT_INK[3])
    for e = 1, 4 do
        ui.handEdges[e]:SetText(card.edges[e])
        if act and act.matched[e] then
            ui.handEdges[e]:SetTextColor(tint[1], tint[2], tint[3])
        else
            ui.handEdges[e]:SetTextColor(1, 1, 1)
        end
    end
    -- The four levels, one block centred in the box. On the parchment the
    -- inks are dark: green for a level in force -- the one reached, and the
    -- ones below when the card is cumulative -- teal for one projected,
    -- faded brown for the rest.
    local ink = tint == CYAN and PARCHMENT_TEAL_HEX or PARCHMENT_GREEN_HEX
    ui.handPairs:SetText(L.combos)
    -- The levels, GROUPED under their condition when they share one (the
    -- same reading as the aura's tooltip): the condition on its line, in the
    -- parchment's ink, the levels under it. A level without one keeps its
    -- own line.
    -- Only CONSECUTIVE levels share a heading: the levels always read 1 to 4.
    local order = {}
    for i = 1, 4 do
        local cond, rest = SplitCondition(LevelText(card, i))
        local key = cond and Lower(cond) or nil
        local last = order[#order]
        if last and key and last.key == key then
            last.items[#last.items + 1] = { level = i, text = rest }
        else
            order[#order + 1] = { key = key, cond = cond, items = { { level = i, text = rest } } }
        end
    end
    local entrees = {}
    for _, g in ipairs(order) do
        -- LA CONDITION EN GRAS, sur sa ligne ; ce qu'elle commande, indente.
        if g.cond then
            entrees[#entrees + 1] = { text = "|cff" .. PARCHMENT_INK_HEX .. g.cond .. " :|r",
                                      bold = true }
        end
        -- LA PREVIEW DIT CE QUE LA CARTE PORTE, non ce que le joueur en tire :
        -- « +1 strength par niveau » se lit « +1 strength ». Le total est
        -- l'affaire de la banniere, qui dit ce qui est en force.
        for _, it in ipairs(g.items) do
            local i = it.level
            local colour = (act and (act.level == i or (card.cumulative and i < act.level))) and ink or PARCHMENT_FADED_HEX
            entrees[#entrees + 1] = { text = "|cff" .. colour .. fmt(L.combo, i, it.text) .. "|r",
                                      indent = g.cond ~= nil }
        end
    end
    PoserLignes(entrees)
    -- Under them, at the bottom of the box: the one word, when it applies.
    ui.handMode:SetText(card.cumulative and L.cumulative or "")
    if ui.handModeBold then
        ui.handModeBold:SetTextColor(ui.handMode:GetTextColor())
        ui.handModeBold:SetText(ui.handMode:GetText() or "")
    end
end

-- What the mouse passes over goes to the hand -- unless a click in the deck
-- PINNED the hand on a card: then the hand stays on it. A drag still shows
-- its projection, and the pinned card comes back after it.
local function HoverHand(card, act, tint)
    if S.pinned then return end
    ShowHand(card, act, tint)
end

-- The levels a card has in force at an activation: the one reached, and
-- the ones below when the card is cumulative.
local function LevelsInForce(act)
    local out = {}
    if act and act.level > 0 then
        for level = act.card.cumulative and 1 or act.level, act.level do out[level] = true end
    end
    return out
end

-- The effects in force, as an equipment set reads: the card, then one line
-- per active level under it, "(level) effect". Only what is in force -- or,
-- given what the board WOULD hold (`after`), what is and what would be: a
-- level kept in green, one gained in cyan, one lost in red.
local function RefreshEffects(after)
    local ui = S.ui
    local now = S.acts
    after = after or now
    local lines = {}
    local keys, seen = {}, {}
    for key in pairs(after) do keys[#keys + 1] = key seen[key] = true end
    for key in pairs(now) do if not seen[key] then keys[#keys + 1] = key end end
    -- In the order of the cards' numbers, not of their cells.
    local function CardOf(key) return (after[key] or now[key]).card.id end
    table.sort(keys, function(a, b)
        local ca, cb = CardOf(a), CardOf(b)
        if ca ~= cb then return ca < cb end
        return a < b
    end)
    for _, key in ipairs(keys) do
        local act = after[key] or now[key]
        local before, later = LevelsInForce(now[key]), LevelsInForce(after[key])
        local card = act.card
        local block = {}
        for level = 1, 4 do
            local colour = before[level] and later[level] and "33ff33"
                        or later[level] and "00ffff"
                        or before[level] and "ff4040"
            if colour then
                block[#block + 1] = fmt("   |cff%s(%d) %s|r", colour, level, LevelText(card, level))
            end
        end
        if #block > 0 then
            lines[#lines + 1] = "|cffffd100" .. Label(card) .. " :|r"
            for _, line in ipairs(block) do lines[#lines + 1] = line end
        end
    end
    ui.effects:SetText(#lines > 0 and table.concat(lines, "\n") or L.effects_none)
    ui.effectsContent:SetHeight(math.max(ui.effects:GetStringHeight() + 8, 20))
end

-- ---------------------------------------------------------------------------
-- The projection: while the dragged card hovers a free cell, the hand and
-- the effects show the board as it would be, and go back to what it is as
-- soon as the card leaves the cell, is laid, or is let go.
-- ---------------------------------------------------------------------------

local RefreshBoard

-- The mouse wheel while a projection is shown: the effects list scrolls,
-- through its own bar so that the bar follows.
local function WheelEffects(delta)
    if not S.projection then return end
    local bar = _G["StellarTarotEffectsScrollScrollBar"]
    if not bar then return end
    local lo, hi = bar:GetMinMaxValues()
    bar:SetValue(math.max(lo, math.min(hi, bar:GetValue() - delta * 24)))
end

local function ShowWheelHint(shown)
    local ui = S.ui
    if not ui or not ui.effectsHint then return end
    if shown then
        ui.effectsHint:Show()
        ui.effectsScroll:SetPoint("BOTTOMRIGHT", -30, 28)
    else
        ui.effectsHint:Hide()
        ui.effectsScroll:SetPoint("BOTTOMRIGHT", -30, 10)
    end
end

-- The cells as the board WOULD hold them, by the kind of the projection:
--   place    a deck card onto a free cell
--   replace  a deck card onto a taken cell: that card comes off
--   move     a board card onto a free cell
--   swap     a board card onto a taken cell: the two exchange
--   remove   a board card held outside the board
local function ProjectedCells(p)
    local cells = {}
    for _, cell in ipairs(S.layout.cells) do
        local keep = true
        if p.from and cell.row == p.from.row and cell.col == p.from.col then keep = false end
        if p.kind ~= "remove" and cell.row == p.row and cell.col == p.col then keep = false end
        if keep then cells[#cells + 1] = cell end
    end
    if p.kind ~= "remove" then
        cells[#cells + 1] = { row = p.row, col = p.col, card = p.card.id }
    end
    if p.kind == "swap" then
        cells[#cells + 1] = { row = p.from.row, col = p.from.col, card = p.other.id }
    end
    return cells
end

local function RefreshProjection()
    local p = S.projection
    if not p or not S.layout then return end
    local after = Activations(ProjectedCells(p))
    RefreshBoard(after)
    RefreshEffects(after)
    if p.kind == "remove" then
        ShowHand(p.card, nil, CYAN)
    else
        ShowHand(p.card, after[p.row * 10 + p.col], CYAN)
    end
    ShowWheelHint(true)
end

local function ClearProjection()
    if not S.projection then return end
    S.projection = nil
    ShowWheelHint(false)
    RefreshBoard()
    RefreshEffects()
    if S.pinned then
        ShowHand(S.pinned, ActOf(S.pinned))
    elseif S.hover then
        ShowHand(S.hover.card, S.hover.act)
    end
end

-- The cell under the cursor, found geometrically: IsMouseOver is reliable
-- during a drag where GetMouseFocus is not.
local function CellUnderCursor()
    for _, cell in ipairs(S.ui.cells) do
        if cell:IsShown() and cell:IsMouseOver() then return cell end
    end
    return nil
end

-- What the drag would do if let go here, or nil for nothing.
local function Project(card, over)
    local from = S.dragFrom
    if not from then
        if not over then return nil end
        return { kind = over.act and "replace" or "place", card = card, row = over.row, col = over.col,
                 other = over.act and over.act.card or nil }
    end
    if not over then
        return { kind = "remove", card = card, from = from }
    end
    if over.row == from.row and over.col == from.col then return nil end
    return { kind = over.act and "swap" or "move", card = card, row = over.row, col = over.col, from = from,
             other = over.act and over.act.card or nil }
end

local function SameProjection(a, b)
    if not a or not b then return a == b end
    return a.kind == b.kind and a.card == b.card and a.row == b.row and a.col == b.col
end

-- Called as the ghost moves.
local function TrackProjection()
    local card = S.drag
    if not card then return end
    local wanted = Project(card, CellUnderCursor())
    if SameProjection(S.projection, wanted) then return end
    if not wanted then
        ClearProjection()
        return
    end
    S.projection = wanted
    RefreshProjection()
end

-- ---------------------------------------------------------------------------
-- Dragging a card from the deck onto a cell
-- ---------------------------------------------------------------------------

local function Ghost()
    local ui = S.ui
    if ui.ghost then return ui.ghost end
    local ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetSize(40, 40)
    ghost:SetFrameStrata("TOOLTIP")
    ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
    ghost.icon:SetAllPoints()
    ghost:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        TrackProjection()
    end)
    ghost:Hide()
    ui.ghost = ghost
    return ghost
end

local function BeginDrag(card, from)
    S.drag, S.dragFrom = card, from
    local ghost = Ghost()
    ghost.icon:SetTexture(CardIcon(card))
    ghost:Show()
    GameTooltip:Hide()
    if from then RefreshBoard() end            -- the cell picked up is dimmed
end

local function DragStart(button)
    local card = button.card
    if not card or not S.known[card.id] or S.placed[card.id] or not S.layout or S.layout.board == 0 then return end
    BeginDrag(card, nil)
end

local function DragStartCell(cell)
    if not cell.act then return end
    BeginDrag(cell.act.card, { row = cell.row, col = cell.col })
end

-- The cell under the cursor, found geometrically: IsMouseOver is reliable
-- during a drag where GetMouseFocus is not.
-- Let go: the projected action, for real. The server answers with the
-- layout, and the window redraws itself from it.
local function DragStop()
    local card, from = S.drag, S.dragFrom
    local p = card and Project(card, CellUnderCursor()) or nil
    S.drag, S.dragFrom = nil, nil
    if S.ui.ghost then S.ui.ghost:Hide() end
    ClearProjection()
    RefreshBoard()
    if not p then return end
    if p.kind == "place" or p.kind == "replace" then
        AIO.Handle("StellarTarot", "Place", p.row, p.col, card.id)
    elseif p.kind == "remove" then
        AIO.Handle("StellarTarot", "Remove", from.row, from.col)
    else
        AIO.Handle("StellarTarot", "Move", from.row, from.col, p.row, p.col)
    end
end

-- ---------------------------------------------------------------------------
-- Building the window
-- ---------------------------------------------------------------------------

-- THE COLUMNS. The deck is as wide as its tabs, its grid of five cards and
-- the scroll bar need; the board takes the same width; the hand is the
-- card's frame with a third of the room it used to have on either side, and
-- the effects sit under it at the same width. The window follows.
local TAB_WIDTH, TAB_HEIGHT = 64, 26           -- the deck's tabs
local CELL, GAP, COLUMNS = 44, 4, 5            -- the deck grid
local DECK_WIDTH = 10 + TAB_WIDTH + 8 + COLUMNS * (CELL + GAP) + 30 + 4
local BOARD_WIDTH = DECK_WIDTH
local HAND_WIDTH = 400 + 2 * 11                -- the card frame (400) and its margins
local EFFECTS_WIDTH = 280                      -- the fourth column: the effects in force
local COL1 = 20
local COL2 = COL1 + DECK_WIDTH + 4             -- the four columns' left edges, 4 px apart
local COL3 = COL2 + BOARD_WIDTH + 4
local COL4 = COL3 + HAND_WIDTH + 4
local WIDTH, HEIGHT = COL4 + EFFECTS_WIDTH + 20, 700
local SLOT = 60                                -- a board cell
-- The frame of an edge number on a laid card: the module's own texture, a
-- flat trapezoid whose long base sits on the cell's edge. 32 px wide and
-- 12 px deep in the file, drawn at 30 x 11 so the digit fits inside; a
-- second texture, dark green, when the edge matches.
local EDGE_BOX_TEXTURE = "Interface\\mod-Tarot\\UI\\trapezoid_off"
local EDGE_BOX_MATCH = "Interface\\mod-Tarot\\UI\\trapezoid_on"          -- dark green: matches
local EDGE_BOX_PREVIEW = "Interface\\mod-Tarot\\UI\\trapezoid_preview"   -- teal: would match
local EDGE_BOX_DEPTH = 51 / 64                 -- the trapezoid fills the texture's width and its top 51 rows of 64
local EDGE_BOX_LONG, EDGE_BOX_SHORT = 30, 12
local DECK_BOX_LONG, DECK_BOX_SHORT = 20, 9    -- the same trapezoid on a deck icon
-- The four ways of drawing the trapezoid, its long base against the edge
-- it sits on: top as drawn, right, bottom flipped, left.
local TRAPEZOID_COORDS = {
    { 0, 0,  0, EDGE_BOX_DEPTH,  1, 0,  1, EDGE_BOX_DEPTH },
    { 0, EDGE_BOX_DEPTH,  1, EDGE_BOX_DEPTH,  0, 0,  1, 0 },
    { 0, EDGE_BOX_DEPTH,  0, 0,  1, EDGE_BOX_DEPTH,  1, 0 },
    { 0, 0,  1, 0,  0, EDGE_BOX_DEPTH,  1, EDGE_BOX_DEPTH },
}

-- THE BOARDS' FRAMES, one texture per size, assembled by the workshop tool
-- from the module's sprites (make_boards.py), which also measures where the
-- cells and the trapezoids sit, in fractions of the drawn content.
BOARD_FRAMES = {
    ["2x2"] = {
        texture = "Interface\\mod-Tarot\\Boards\\board_2x2", texcoord = { 1.0000, 1.0000 }, aspect = 1.0000,
        cells = {
            { 1, 1, { 0.1805, 0.1805, 0.4872, 0.4872 } },
            { 1, 2, { 0.5128, 0.1805, 0.8195, 0.4872 } },
            { 2, 1, { 0.1805, 0.5128, 0.4872, 0.8195 } },
            { 2, 2, { 0.5128, 0.5128, 0.8195, 0.8195 } },
        },
        top = { { 0.2133, 0.0224, 0.4545, 0.1182 }, { 0.5455, 0.0224, 0.7867, 0.1182 } },
        bottom = { { 0.2133, 0.8818, 0.4545, 0.9776 }, { 0.5455, 0.8818, 0.7867, 0.9776 } },
        left = { { 0.0224, 0.2133, 0.1182, 0.4545 }, { 0.0224, 0.5455, 0.1182, 0.7867 } },
        right = { { 0.8818, 0.2133, 0.9776, 0.4545 }, { 0.8818, 0.5455, 0.9776, 0.7867 } },
    },
    ["3x3"] = {
        texture = "Interface\\mod-Tarot\\Boards\\board_3x3", texcoord = { 1.0000, 1.0000 }, aspect = 1.0000,
        cells = {
            { 1, 1, { 0.1355, 0.1355, 0.3657, 0.3657 } },
            { 1, 2, { 0.3849, 0.1355, 0.6151, 0.3657 } },
            { 1, 3, { 0.6343, 0.1355, 0.8645, 0.3657 } },
            { 2, 1, { 0.1355, 0.3849, 0.3657, 0.6151 } },
            { 2, 2, { 0.3849, 0.3849, 0.6151, 0.6151 } },
            { 2, 3, { 0.6343, 0.3849, 0.8645, 0.6151 } },
            { 3, 1, { 0.1355, 0.6343, 0.3657, 0.8645 } },
            { 3, 2, { 0.3849, 0.6343, 0.6151, 0.8645 } },
            { 3, 3, { 0.6343, 0.6343, 0.8645, 0.8645 } },
        },
        top = { { 0.1601, 0.0168, 0.3411, 0.0887 }, { 0.4095, 0.0168, 0.5905, 0.0887 }, { 0.6589, 0.0168, 0.8399, 0.0887 } },
        bottom = { { 0.1601, 0.9113, 0.3411, 0.9832 }, { 0.4095, 0.9113, 0.5905, 0.9832 }, { 0.6589, 0.9113, 0.8399, 0.9832 } },
        left = { { 0.0168, 0.1601, 0.0887, 0.3411 }, { 0.0168, 0.4095, 0.0887, 0.5905 }, { 0.0168, 0.6589, 0.0887, 0.8399 } },
        right = { { 0.9113, 0.1601, 0.9832, 0.3411 }, { 0.9113, 0.4095, 0.9832, 0.5905 }, { 0.9113, 0.6589, 0.9832, 0.8399 } },
    },
    ["4x4"] = {
        texture = "Interface\\mod-Tarot\\Boards\\board_4x4", texcoord = { 1.0000, 1.0000 }, aspect = 1.0000,
        cells = {
            { 1, 1, { 0.1084, 0.1084, 0.2927, 0.2927 } },
            { 1, 2, { 0.3081, 0.1084, 0.4923, 0.2927 } },
            { 1, 3, { 0.5077, 0.1084, 0.6919, 0.2927 } },
            { 1, 4, { 0.7073, 0.1084, 0.8916, 0.2927 } },
            { 2, 1, { 0.1084, 0.3081, 0.2927, 0.4923 } },
            { 2, 2, { 0.3081, 0.3081, 0.4923, 0.4923 } },
            { 2, 3, { 0.5077, 0.3081, 0.6919, 0.4923 } },
            { 2, 4, { 0.7073, 0.3081, 0.8916, 0.4923 } },
            { 3, 1, { 0.1084, 0.5077, 0.2927, 0.6919 } },
            { 3, 2, { 0.3081, 0.5077, 0.4923, 0.6919 } },
            { 3, 3, { 0.5077, 0.5077, 0.6919, 0.6919 } },
            { 3, 4, { 0.7073, 0.5077, 0.8916, 0.6919 } },
            { 4, 1, { 0.1084, 0.7073, 0.2927, 0.8916 } },
            { 4, 2, { 0.3081, 0.7073, 0.4923, 0.8916 } },
            { 4, 3, { 0.5077, 0.7073, 0.6919, 0.8916 } },
            { 4, 4, { 0.7073, 0.7073, 0.8916, 0.8916 } },
        },
        top = { { 0.1281, 0.0134, 0.2730, 0.0710 }, { 0.3277, 0.0134, 0.4726, 0.0710 }, { 0.5274, 0.0134, 0.6723, 0.0710 }, { 0.7270, 0.0134, 0.8719, 0.0710 } },
        bottom = { { 0.1281, 0.9290, 0.2730, 0.9866 }, { 0.3277, 0.9290, 0.4726, 0.9866 }, { 0.5274, 0.9290, 0.6723, 0.9866 }, { 0.7270, 0.9290, 0.8719, 0.9866 } },
        left = { { 0.0134, 0.1281, 0.0710, 0.2730 }, { 0.0134, 0.3277, 0.0710, 0.4726 }, { 0.0134, 0.5274, 0.0710, 0.6723 }, { 0.0134, 0.7270, 0.0710, 0.8719 } },
        right = { { 0.9290, 0.1281, 0.9866, 0.2730 }, { 0.9290, 0.3277, 0.9866, 0.4726 }, { 0.9290, 0.5274, 0.9866, 0.6723 }, { 0.9290, 0.7270, 0.9866, 0.8719 } },
    },
    ["2x3"] = {
        texture = "Interface\\mod-Tarot\\Boards\\board_2x3", texcoord = { 0.6660, 1.0000 }, aspect = 1.3323,
        cells = {
            { 1, 1, { 0.1355, 0.1805, 0.3657, 0.4872 } },
            { 1, 2, { 0.3849, 0.1805, 0.6151, 0.4872 } },
            { 1, 3, { 0.6343, 0.1805, 0.8645, 0.4872 } },
            { 2, 1, { 0.1355, 0.5128, 0.3657, 0.8195 } },
            { 2, 2, { 0.3849, 0.5128, 0.6151, 0.8195 } },
            { 2, 3, { 0.6343, 0.5128, 0.8645, 0.8195 } },
        },
        top = { { 0.1601, 0.0224, 0.3411, 0.1182 }, { 0.4095, 0.0224, 0.5905, 0.1182 }, { 0.6589, 0.0224, 0.8399, 0.1182 } },
        bottom = { { 0.1601, 0.8818, 0.3411, 0.9776 }, { 0.4095, 0.8818, 0.5905, 0.9776 }, { 0.6589, 0.8818, 0.8399, 0.9776 } },
        left = { { 0.0168, 0.2133, 0.0887, 0.4545 }, { 0.0168, 0.5455, 0.0887, 0.7867 } },
        right = { { 0.9113, 0.2133, 0.9832, 0.4545 }, { 0.9113, 0.5455, 0.9832, 0.7867 } },
    },
    ["3x2"] = {
        texture = "Interface\\mod-Tarot\\Boards\\board_3x2", texcoord = { 1.0000, 0.6660 }, aspect = 0.7506,
        cells = {
            { 1, 1, { 0.1805, 0.1355, 0.4872, 0.3657 } },
            { 1, 2, { 0.5128, 0.1355, 0.8195, 0.3657 } },
            { 2, 1, { 0.1805, 0.3849, 0.4872, 0.6151 } },
            { 2, 2, { 0.5128, 0.3849, 0.8195, 0.6151 } },
            { 3, 1, { 0.1805, 0.6343, 0.4872, 0.8645 } },
            { 3, 2, { 0.5128, 0.6343, 0.8195, 0.8645 } },
        },
        top = { { 0.2133, 0.0168, 0.4545, 0.0887 }, { 0.5455, 0.0168, 0.7867, 0.0887 } },
        bottom = { { 0.2133, 0.9113, 0.4545, 0.9832 }, { 0.5455, 0.9113, 0.7867, 0.9832 } },
        left = { { 0.0224, 0.1601, 0.1182, 0.3411 }, { 0.0224, 0.4095, 0.1182, 0.5905 }, { 0.0224, 0.6589, 0.1182, 0.8399 } },
        right = { { 0.8818, 0.1601, 0.9776, 0.3411 }, { 0.8818, 0.4095, 0.9776, 0.5905 }, { 0.8818, 0.6589, 0.9776, 0.8399 } },
    },
    ["2x4"] = {
        texture = "Interface\\mod-Tarot\\Boards\\board_2x4", texcoord = { 0.8320, 1.0000 }, aspect = 1.6645,
        cells = {
            { 1, 1, { 0.1084, 0.1805, 0.2927, 0.4872 } },
            { 1, 2, { 0.3081, 0.1805, 0.4923, 0.4872 } },
            { 1, 3, { 0.5077, 0.1805, 0.6919, 0.4872 } },
            { 1, 4, { 0.7073, 0.1805, 0.8916, 0.4872 } },
            { 2, 1, { 0.1084, 0.5128, 0.2927, 0.8195 } },
            { 2, 2, { 0.3081, 0.5128, 0.4923, 0.8195 } },
            { 2, 3, { 0.5077, 0.5128, 0.6919, 0.8195 } },
            { 2, 4, { 0.7073, 0.5128, 0.8916, 0.8195 } },
        },
        top = { { 0.1281, 0.0224, 0.2730, 0.1182 }, { 0.3277, 0.0224, 0.4726, 0.1182 }, { 0.5274, 0.0224, 0.6723, 0.1182 }, { 0.7270, 0.0224, 0.8719, 0.1182 } },
        bottom = { { 0.1281, 0.8818, 0.2730, 0.9776 }, { 0.3277, 0.8818, 0.4726, 0.9776 }, { 0.5274, 0.8818, 0.6723, 0.9776 }, { 0.7270, 0.8818, 0.8719, 0.9776 } },
        left = { { 0.0134, 0.2133, 0.0710, 0.4545 }, { 0.0134, 0.5455, 0.0710, 0.7867 } },
        right = { { 0.9290, 0.2133, 0.9866, 0.4545 }, { 0.9290, 0.5455, 0.9866, 0.7867 } },
    },
    ["4x2"] = {
        texture = "Interface\\mod-Tarot\\Boards\\board_4x2", texcoord = { 1.0000, 0.8320 }, aspect = 0.6008,
        cells = {
            { 1, 1, { 0.1805, 0.1084, 0.4872, 0.2927 } },
            { 1, 2, { 0.5128, 0.1084, 0.8195, 0.2927 } },
            { 2, 1, { 0.1805, 0.3081, 0.4872, 0.4923 } },
            { 2, 2, { 0.5128, 0.3081, 0.8195, 0.4923 } },
            { 3, 1, { 0.1805, 0.5077, 0.4872, 0.6919 } },
            { 3, 2, { 0.5128, 0.5077, 0.8195, 0.6919 } },
            { 4, 1, { 0.1805, 0.7073, 0.4872, 0.8916 } },
            { 4, 2, { 0.5128, 0.7073, 0.8195, 0.8916 } },
        },
        top = { { 0.2133, 0.0134, 0.4545, 0.0710 }, { 0.5455, 0.0134, 0.7867, 0.0710 } },
        bottom = { { 0.2133, 0.9290, 0.4545, 0.9866 }, { 0.5455, 0.9290, 0.7867, 0.9866 } },
        left = { { 0.0224, 0.1281, 0.1182, 0.2730 }, { 0.0224, 0.3277, 0.1182, 0.4726 }, { 0.0224, 0.5274, 0.1182, 0.6723 }, { 0.0224, 0.7270, 0.1182, 0.8719 } },
        right = { { 0.8818, 0.1281, 0.9776, 0.2730 }, { 0.8818, 0.3277, 0.9776, 0.4726 }, { 0.8818, 0.5274, 0.9776, 0.6723 }, { 0.8818, 0.7270, 0.9776, 0.8719 } },
    },
    ["3x4"] = {
        texture = "Interface\\mod-Tarot\\Boards\\board_3x4", texcoord = { 0.6250, 1.0000 }, aspect = 1.2494,
        cells = {
            { 1, 1, { 0.1084, 0.1355, 0.2927, 0.3657 } },
            { 1, 2, { 0.3081, 0.1355, 0.4923, 0.3657 } },
            { 1, 3, { 0.5077, 0.1355, 0.6919, 0.3657 } },
            { 1, 4, { 0.7073, 0.1355, 0.8916, 0.3657 } },
            { 2, 1, { 0.1084, 0.3849, 0.2927, 0.6151 } },
            { 2, 2, { 0.3081, 0.3849, 0.4923, 0.6151 } },
            { 2, 3, { 0.5077, 0.3849, 0.6919, 0.6151 } },
            { 2, 4, { 0.7073, 0.3849, 0.8916, 0.6151 } },
            { 3, 1, { 0.1084, 0.6343, 0.2927, 0.8645 } },
            { 3, 2, { 0.3081, 0.6343, 0.4923, 0.8645 } },
            { 3, 3, { 0.5077, 0.6343, 0.6919, 0.8645 } },
            { 3, 4, { 0.7073, 0.6343, 0.8916, 0.8645 } },
        },
        top = { { 0.1281, 0.0168, 0.2730, 0.0887 }, { 0.3277, 0.0168, 0.4726, 0.0887 }, { 0.5274, 0.0168, 0.6723, 0.0887 }, { 0.7270, 0.0168, 0.8719, 0.0887 } },
        bottom = { { 0.1281, 0.9113, 0.2730, 0.9832 }, { 0.3277, 0.9113, 0.4726, 0.9832 }, { 0.5274, 0.9113, 0.6723, 0.9832 }, { 0.7270, 0.9113, 0.8719, 0.9832 } },
        left = { { 0.0134, 0.1601, 0.0710, 0.3411 }, { 0.0134, 0.4095, 0.0710, 0.5905 }, { 0.0134, 0.6589, 0.0710, 0.8399 } },
        right = { { 0.9290, 0.1601, 0.9866, 0.3411 }, { 0.9290, 0.4095, 0.9866, 0.5905 }, { 0.9290, 0.6589, 0.9866, 0.8399 } },
    },
    ["4x3"] = {
        texture = "Interface\\mod-Tarot\\Boards\\board_4x3", texcoord = { 1.0000, 0.6250 }, aspect = 0.8004,
        cells = {
            { 1, 1, { 0.1355, 0.1084, 0.3657, 0.2927 } },
            { 1, 2, { 0.3849, 0.1084, 0.6151, 0.2927 } },
            { 1, 3, { 0.6343, 0.1084, 0.8645, 0.2927 } },
            { 2, 1, { 0.1355, 0.3081, 0.3657, 0.4923 } },
            { 2, 2, { 0.3849, 0.3081, 0.6151, 0.4923 } },
            { 2, 3, { 0.6343, 0.3081, 0.8645, 0.4923 } },
            { 3, 1, { 0.1355, 0.5077, 0.3657, 0.6919 } },
            { 3, 2, { 0.3849, 0.5077, 0.6151, 0.6919 } },
            { 3, 3, { 0.6343, 0.5077, 0.8645, 0.6919 } },
            { 4, 1, { 0.1355, 0.7073, 0.3657, 0.8916 } },
            { 4, 2, { 0.3849, 0.7073, 0.6151, 0.8916 } },
            { 4, 3, { 0.6343, 0.7073, 0.8645, 0.8916 } },
        },
        top = { { 0.1601, 0.0134, 0.3411, 0.0710 }, { 0.4095, 0.0134, 0.5905, 0.0710 }, { 0.6589, 0.0134, 0.8399, 0.0710 } },
        bottom = { { 0.1601, 0.9290, 0.3411, 0.9866 }, { 0.4095, 0.9290, 0.5905, 0.9866 }, { 0.6589, 0.9290, 0.8399, 0.9866 } },
        left = { { 0.0168, 0.1281, 0.0887, 0.2730 }, { 0.0168, 0.3277, 0.0887, 0.4726 }, { 0.0168, 0.5274, 0.0887, 0.6723 }, { 0.0168, 0.7270, 0.0887, 0.8719 } },
        right = { { 0.9113, 0.1281, 0.9832, 0.2730 }, { 0.9113, 0.3277, 0.9832, 0.4726 }, { 0.9113, 0.5274, 0.9832, 0.6723 }, { 0.9113, 0.7270, 0.9832, 0.8719 } },
    },
}
local GRID_AREA = 340                          -- the square the grid is centred in, room for 4 x 4 and the numbers
local SLOT_GAP = 4

local function Panel(parent, x, width, caption, y, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", x, y or -44)
    panel:SetSize(width, height or HEIGHT - 64)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.1, 1)
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("TOPLEFT", 12, -10)
    text:SetText(caption)
    return panel
end

local function BuildFrame()
    -- A frame from an earlier load of this file is set aside, hidden: the
    -- client never destroys a frame, and reusing its children would tie them
    -- to code that no longer exists.
    local old = _G["StellarTarotFrame"]
    if old then old:Hide() end

    local frame = CreateFrame("Frame", "StellarTarotFrame", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) WheelEffects(delta) end)
    -- The dialog background is translucent: an opaque ground goes under it.
    local ground = frame:CreateTexture(nil, "BACKGROUND")
    ground:SetPoint("TOPLEFT", 10, -10)
    ground:SetPoint("BOTTOMRIGHT", -10, 10)
    ground:SetTexture(0, 0, 0, 1)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:Hide()
    tinsert(UISpecialFrames, "StellarTarotFrame")

    local header = frame:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(300, 64)
    header:SetPoint("TOP", 0, 12)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText(L.title)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    return frame
end

-- THE DECK: the tabs on the left edge, one per tag; the grid of the tab's
-- cards to their right.
local function BuildDeck(ui)
    local panel = Panel(ui.frame, COL1, DECK_WIDTH, L.deck)

    local tabs = CreateFrame("Frame", nil, panel)
    tabs:SetPoint("TOPLEFT", 10, -40)
    tabs:SetSize(TAB_WIDTH, HEIGHT - 120)

    -- The search: an edit box above the grid; the grid only shows the cards
    -- whose name contains what is typed (accents and case ignored).
    local search = CreateFrame("EditBox", "StellarTarotDeckSearch", panel, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", tabs, "TOPRIGHT", 14, 0)
    search:SetSize(COLUMNS * (CELL + GAP) - 10, 20)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    search.hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    search.hint:SetPoint("LEFT", 2, 0)
    search.hint:SetText(L.search)
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then self.hint:Show() else self.hint:Hide() end
        if S.search ~= text then
            S.search = text
            if RefreshDeck then RefreshDeck() end
        end
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    ui.search = search

    local scroll = CreateFrame("ScrollFrame", "StellarTarotDeckScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", tabs, "TOPRIGHT", 8, -26)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(COLUMNS * (CELL + GAP), 10)
    scroll:SetScrollChild(content)

    ui.deck = panel
    ui.tabs, ui.content = tabs, content
    ui.tabButtons, ui.cardButtons = {}, {}
end

local function BuildBoard(ui)
    local panel = Panel(ui.frame, COL2, BOARD_WIDTH, L.board)

    -- The slot: the board equipped, and the list to choose one.
    local slot = CreateFrame("Button", nil, panel)
    slot:SetSize(44, 44)
    slot:SetPoint("TOPLEFT", 12, -32)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", 2, -2)
    slot.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    slot:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                       bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                       insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    slot:SetBackdropColor(0, 0, 0, 0.8)
    slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    slot.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    slot.label:SetPoint("LEFT", slot, "RIGHT", 8, 6)
    slot.label:SetWidth(BOARD_WIDTH - 80)
    slot.label:SetJustifyH("LEFT")
    slot.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slot.hint:SetPoint("LEFT", slot, "RIGHT", 8, -10)
    slot.hint:SetWidth(BOARD_WIDTH - 80)
    slot.hint:SetJustifyH("LEFT")
    slot.hint:SetText(L.board_pick)

    -- The list of boards, shown by the slot.
    local picker = CreateFrame("Frame", nil, panel)
    picker:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -2)
    picker:SetWidth(BOARD_WIDTH - 24)
    picker:SetFrameStrata("DIALOG")
    picker:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    picker:SetBackdropColor(0, 0, 0, 1)
    picker:Hide()
    picker.rows = {}
    -- A CLICK ANYWHERE ELSE CLOSES THE LIST. While it is open, an invisible
    -- frame covers the whole screen under it and swallows the first click,
    -- which does nothing but close the list.
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(picker:GetFrameLevel() - 1)
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function() picker:Hide() end)
    catcher:Hide()
    picker:SetFrameLevel(catcher:GetFrameLevel() + 5)
    slot:SetScript("OnClick", function()
        if picker:IsShown() then picker:Hide() else picker:Show() end
    end)
    picker:SetScript("OnShow", function() catcher:Show() end)
    picker:SetScript("OnHide", function() catcher:Hide() HidePreview() end)
    -- The board equipped: its name and size only -- its numbers stand around
    -- the grid already.
    slot:SetScript("OnEnter", function(self)
        if self.board then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.board.name, QualityColor(self.board.quality))
            GameTooltip:AddLine(fmt(L.size, self.board.rows, self.board.cols), 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.board_change, 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- The grid: the cells, and the board's numbers around them.
    -- A square area with room for a 4 x 4 board and its numbers; whatever
    -- the board's size, its cells are centred in it, vertically as well.
    local grid = CreateFrame("Frame", nil, panel)
    grid:SetPoint("TOP", panel, "TOP", 0, -84)
    grid:SetSize(GRID_AREA, GRID_AREA)
    grid:EnableMouseWheel(true)
    grid:SetScript("OnMouseWheel", function(_, delta) WheelEffects(delta) end)
    -- The board's frame, drawn under the cells at the size that makes its
    -- cells SLOT wide, centred in the grid area.
    ui.boardArt = grid:CreateTexture(nil, "BACKGROUND")
    ui.boardArt:SetPoint("CENTER")
    ui.boardArt:Hide()
    ui.cells, ui.rims = {}, {}
    for r = 1, 4 do
        for c = 1, 4 do
            local cell = CreateFrame("Button", nil, grid)
            cell:SetSize(SLOT, SLOT)
            cell.row, cell.col = r, c
            cell:EnableMouseWheel(true)
            cell:SetScript("OnMouseWheel", function(_, delta) WheelEffects(delta) end)
            -- No border of its own: the board's frame draws a ring around it.
            cell:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
            cell:SetBackdropColor(0, 0, 0, 0.7)
            -- A laid card fills the cell; its four numbers sit in small
            -- trapezoids glued to the middle of each edge, over the picture:
            -- the module's own texture, drawn with its long base on top and
            -- turned for the other three edges through the texture coordinates.
            cell.icon = cell:CreateTexture(nil, "ARTWORK")
            cell.icon:SetPoint("TOPLEFT", 0, 0)
            cell.icon:SetPoint("BOTTOMRIGHT", 0, 0)
            cell.edges, cell.boxes = {}, {}
            local anchors = { "TOP", "RIGHT", "BOTTOM", "LEFT" }
            local offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }   -- the long base on the cell's edge
            local coords = TRAPEZOID_COORDS
            for e = 1, 4 do
                local box = CreateFrame("Frame", nil, cell)
                if e == 1 or e == 3 then box:SetSize(EDGE_BOX_LONG, EDGE_BOX_SHORT)
                else box:SetSize(EDGE_BOX_SHORT, EDGE_BOX_LONG) end
                box:SetFrameLevel(cell:GetFrameLevel() + 1)
                box:SetPoint(anchors[e], cell, anchors[e], offsets[e][1], offsets[e][2])
                box.bg = box:CreateTexture(nil, "BACKGROUND")
                box.bg:SetAllPoints()
                box.bg:SetTexture(EDGE_BOX_TEXTURE)
                box.coords = coords[e]
                box.bg:SetTexCoord(unpack(coords[e]))
                -- The digit sits in the middle of the trapezoid, a touch
                -- towards the long base, where the shape is widest.
                local text = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                local nudge = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }
                text:SetPoint("CENTER", nudge[e][1], nudge[e][2])
                box:Hide()
                cell.boxes[e] = box
                cell.edges[e] = text
            end
            cell.badge = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cell.badge:SetPoint("TOPLEFT", 4, -3)
            cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            cell:RegisterForClicks("RightButtonUp")
            cell:SetScript("OnClick", function(self)
                if self.act then AIO.Handle("StellarTarot", "Remove", self.row, self.col) end
            end)
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnDragStart", DragStartCell)
            cell:SetScript("OnDragStop", DragStop)
            cell:SetScript("OnEnter", function(self)
                if self.act then
                    HoverHand(self.act.card, self.act)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(Label(self.act.card), QualityColor(self.act.card.quality))
                    GameTooltip:AddLine(self.act.level > 0 and fmt(L.activation, self.act.level) or L.inert, 1, 1, 1)
                    GameTooltip:AddLine(L.cell_hint, 0.6, 0.6, 0.6)
                    GameTooltip:Show()
                else
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L.cell_empty, 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
            cell:Hide()
            ui.cells[#ui.cells + 1] = cell
        end
    end
    -- The rim numbers: one text per side and per index, placed when the board
    -- is known.
    -- Each rim number on its own trapezoid, a frame over the board's art
    -- and under the cells.
    -- Drawn with the long base towards the cells: the top band uses the
    -- bottom edge's drawing, and so on.
    local RIM_EDGE = { top = 3, right = 4, bottom = 1, left = 2 }
    for _, side in ipairs({ "left", "right", "top", "bottom" }) do
        ui.rims[side] = {}
        for i = 1, 4 do
            local box = CreateFrame("Frame", nil, grid)
            box:SetFrameLevel(grid:GetFrameLevel() + 1)
            box.bg = box:CreateTexture(nil, "BACKGROUND")
            box.bg:SetAllPoints()
            box.bg:SetTexture(EDGE_BOX_TEXTURE)
            box.coords = TRAPEZOID_COORDS[RIM_EDGE[side]]
            box.bg:SetTexCoord(unpack(box.coords))
            local text = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            -- Nudged two pixels towards the cells, where the trapezoid is widest.
            local RIM_NUDGE = { top = { 0, -2 }, right = { -2, 0 }, bottom = { 0, 2 }, left = { 2, 0 } }
            text:SetPoint("CENTER", RIM_NUDGE[side][1], RIM_NUDGE[side][2])
            text:SetTextColor(1, 1, 1)
            box.text = text
            box:Hide()
            ui.rims[side][i] = box
        end
    end
    ui.boardNote = grid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ui.boardNote:SetPoint("CENTER")
    ui.boardNote:SetWidth(BOARD_WIDTH - 40)
    ui.boardNote:SetText(L.board_none)

    local clear = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clear:SetSize(120, 22)
    clear:SetPoint("TOP", grid, "BOTTOM", 0, -6)
    clear:SetText(L.remove_all)
    -- Asked first: the game's own confirmation box, and nothing happens
    -- until it is answered.
    StaticPopupDialogs["STELLAR_TAROT_REMOVE_ALL"] = {
        text = L.remove_all_ask,
        button1 = L.yes,
        button2 = L.cancel,
        OnAccept = function() AIO.Handle("StellarTarot", "Clear") end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    clear:SetScript("OnClick", function()
        if S.layout and S.layout.cells and #S.layout.cells > 0 then
            StaticPopup_Show("STELLAR_TAROT_REMOVE_ALL")
        end
    end)

    -- The presets.
    local presetsCaption = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    presetsCaption:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -466)
    presetsCaption:SetText(L.presets)
    local nameBox = CreateFrame("EditBox", "StellarTarotPresetName", panel, "InputBoxTemplate")
    nameBox:SetSize(230, 20)
    nameBox:SetPoint("TOPLEFT", presetsCaption, "BOTTOMLEFT", 6, -4)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(32)
    local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    save:SetSize(100, 22)
    save:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
    save:SetText(L.preset_save)
    local function Save()
        local name = nameBox:GetText()
        if name and name:match("%S") then
            AIO.Handle("StellarTarot", "PresetSave", name)
            nameBox:SetText("")
            nameBox:ClearFocus()
        end
    end
    save:SetScript("OnClick", Save)
    nameBox:SetScript("OnEnterPressed", Save)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local list = CreateFrame("ScrollFrame", "StellarTarotPresetScroll", panel, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", -6, -6)
    list:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)
    local rows = CreateFrame("Frame", nil, list)
    rows:SetSize(BOARD_WIDTH - 50, 10)
    list:SetScrollChild(rows)
    ui.presetNote = rows:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ui.presetNote:SetPoint("TOPLEFT", 4, -4)

    ui.board = panel
    ui.slot, ui.picker, ui.grid, ui.presetRows, ui.presetButtons = slot, picker, grid, rows, {}
end

-- The right column: the preview on top, the active effects under it.
local PREVIEW_HEIGHT = HEIGHT - 64             -- the whole column

-- THE CARD, COMPOSED IN THE INTERFACE: the module's frame (a 2:3 template,
-- drawn from the upper three quarters of a 512 x 1024 texture), the
-- illustration behind the frame's window, the name in the banner, the four
-- levels in the box. The zones are fractions of the template, measured by
-- the workshop tool that makes the frame texture (make_card_frame.py).
local FRAME_TEXTURE = "Interface\\mod-Tarot\\UI\\card_frame"
local FRAME_TEXCOORD_BOTTOM = 0.75
local FRAME_W, FRAME_H = 400, 600
local FRAME_X, FRAME_Y = (HAND_WIDTH - FRAME_W) / 2, -(PREVIEW_HEIGHT - FRAME_H) / 2   -- centred in the panel
local FRAME_ZONES = {
    window      = { 0.1631, 0.1055, 0.8350, 0.4570 },
    banner      = { 0.1523, 0.4759, 0.8467, 0.5267 },
    box         = { 0.1504, 0.5872, 0.8486, 0.8626 },
    -- The four trapezoids on the card's edges, where the edge numbers sit:
    -- top, right, bottom, left, in the order of the edges.
    edge_top    = { 0.4209, 0.0404, 0.5781, 0.0898 },
    edge_right  = { 0.9121, 0.4570, 0.9668, 0.5391 },
    edge_bottom = { 0.4189, 0.8822, 0.5791, 0.9362 },
    edge_left   = { 0.0342, 0.4570, 0.0879, 0.5391 },
}
local EDGE_ZONES = { "edge_top", "edge_right", "edge_bottom", "edge_left" }
local ART_LIFT = 1                             -- pixels the illustration sits above the measured window (negative: below)
local ART_SCALE = 1.05                         -- the illustration, relative to the window

-- A region of the frame, in pixels of the panel: left, top (negative), width, height.
local function FrameZone(name)
    local z = FRAME_ZONES[name]
    return FRAME_X + z[1] * FRAME_W, FRAME_Y - z[2] * FRAME_H, (z[3] - z[1]) * FRAME_W, (z[4] - z[2]) * FRAME_H
end

local function BuildHand(ui)
    -- No caption: the card is its own title.
    local panel = Panel(ui.frame, COL3, HAND_WIDTH, "", -44, PREVIEW_HEIGHT)

    -- The illustration, under the frame: as wide as the window, and cut top
    -- and bottom to the window's proportions (the illustrations are square).
    local wx, wy, ww, wh = FrameZone("window")
    local icon = panel:CreateTexture(nil, "BORDER")
    -- Drawn a little larger than the window, about its centre: the frame
    -- overlaps its edges, so the picture never falls short of them.
    icon:SetSize(ww * ART_SCALE, wh * ART_SCALE)
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT",
                  wx - ww * (ART_SCALE - 1) / 2, wy + ART_LIFT + wh * (ART_SCALE - 1) / 2)
    local cut = (1 - wh / ww) / 2
    icon:SetTexCoord(0, 1, cut, 1 - cut)
    icon:Hide()

    local frame = panel:CreateTexture(nil, "ARTWORK")
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("TOPLEFT", panel, "TOPLEFT", FRAME_X, FRAME_Y)
    frame:SetTexture(FRAME_TEXTURE)
    frame:SetTexCoord(0, 1, 0, FRAME_TEXCOORD_BOTTOM)

    -- The four edge numbers, each centred in its trapezoid on the card's
    -- edge.
    local edges = {}
    for e = 1, 4 do
        local zx, zy, zw, zh = FrameZone(EDGE_ZONES[e])
        local text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        text:SetPoint("TOPLEFT", panel, "TOPLEFT", zx, zy)
        text:SetSize(zw, zh)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetShadowOffset(0, 0)
        edges[e] = text
    end

    -- The name, in the banner.
    local bx, by, bw, bh = FrameZone("banner")
    local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    name:SetPoint("TOPLEFT", panel, "TOPLEFT", bx, by)
    name:SetSize(bw, bh)
    name:SetJustifyH("CENTER")
    name:SetJustifyV("MIDDLE")
    name:SetShadowOffset(0, 0)

    -- The four levels, one block centred in the box, above the kind of
    -- card, which sits at the bottom of the box.
    local lx, ly, lw, lh = FrameZone("box")
    local KIND_H = 20
    -- Les lignes se posent une a une (PoserLignes), du haut et de la gauche.
    local BOX_MARGIN = 14
    -- At the top of the box, centred: the heading of the lines.
    local pairs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pairs:SetPoint("TOPLEFT", panel, "TOPLEFT", lx, ly - 4)
    pairs:SetSize(lw, KIND_H)
    pairs:SetJustifyH("CENTER")
    pairs:SetShadowOffset(0, 0)
    pairs:SetTextColor(PARCHMENT_INK[1], PARCHMENT_INK[2], PARCHMENT_INK[3])
    ui.handPairs = pairs
    -- The lines, a block centred in what is left between the heading and
    -- the kind of card -- in a TRANSPARENT SCROLLING BOX: when the four
    -- levels are too long for the parchment, the box scrolls (wheel, or the
    -- bar on its right, shown only then).
    local SCROLLBAR_W = 22                     -- the template's bar sits 4 px right of the frame, 16 px wide
    local roomW, roomH = lw - 2 * BOX_MARGIN - SCROLLBAR_W, lh - 8 - 2 * KIND_H
    local scroll = CreateFrame("ScrollFrame", "StellarTarotHandScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", lx + BOX_MARGIN, ly - 4 - KIND_H)
    scroll:SetSize(roomW, roomH)
    scroll.scrollBarHideable = 1
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(roomW, roomH)
    scroll:SetScrollChild(child)
    -- LES LIGNES SE POSENT UNE A UNE (PoserLignes) : plus de bloc d'un seul
    -- tenant, donc plus de mesure de la ligne la plus large.
    ui.handScroll, ui.handScrollChild = scroll, child
    ui.handLevelsBox = { width = roomW, room = roomH }
    local mode = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")

    mode:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", lx, ly - lh + 4)
    mode:SetSize(lw, KIND_H)
    mode:SetJustifyH("CENTER")
    mode:SetShadowOffset(0, 0)
    mode:SetTextColor(PARCHMENT_INK[1], PARCHMENT_INK[2], PARCHMENT_INK[3])
    local state = nil

    -- The fourth column, the whole height.
    local effectsPanel = Panel(ui.frame, COL4, EFFECTS_WIDTH, L.effects, -44, HEIGHT - 64)
    local scroll = CreateFrame("ScrollFrame", "StellarTarotEffectsScroll", effectsPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -36)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(EFFECTS_WIDTH - 44, 20)
    scroll:SetScrollChild(content)
    local effects = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    effects:SetPoint("TOPLEFT", 4, -4)
    effects:SetWidth(EFFECTS_WIDTH - 56)
    effects:SetJustifyH("LEFT")
    -- Said at the bottom while a projection is shown: the wheel scrolls.
    local hint = effectsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 12, 10)
    hint:SetPoint("RIGHT", effectsPanel, "RIGHT", -12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.7, 0.7, 0.7)
    hint:SetText(L.effects_wheel)
    hint:Hide()
    ui.effectsScroll, ui.effectsHint = scroll, hint

    ui.hand, ui.effectsPanel = panel, effectsPanel
    ui.handIcon, ui.handEdges, ui.handName, ui.handState = icon, edges, name, state
    -- EN GRAS, SANS TOUCHER A LA COULEUR : le mot est ecrit deux fois, a un
    -- pixel d'ecart. Sa seconde frappe suit son texte (ShowHand).
    local modeBold = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    modeBold:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", lx + 1, ly - lh + 4)
    modeBold:SetSize(lw, KIND_H)
    modeBold:SetJustifyH(mode:GetJustifyH())
    modeBold:SetShadowOffset(0, 0)
    modeBold:SetTextColor(mode:GetTextColor())
    ui.handModeBold = modeBold
    ui.handMode = mode
    ui.effects, ui.effectsContent = effects, content
end

local function Build()
    if S.ui then return S.ui end
    local ui = {}
    ui.frame = BuildFrame()
    BuildDeck(ui)
    BuildBoard(ui)
    BuildHand(ui)
    S.ui = ui
    ShowHand(nil)
    return ui
end

-- ---------------------------------------------------------------------------
-- Drawing the deck
-- ---------------------------------------------------------------------------

-- The tabs, stacked on the left edge: "All" first, then one per tag. The one
-- shown is lit. Tag 0 stands for "All".
local ALL = 0

-- What is typed in the search box, and whether a card answers it. DIGITS ASK
-- FOR A NUMBER: the one the player reads on the card, "82.", not the
-- catalogue's identifier. The first digits are enough -- "8" keeps 8 and the
-- eighties -- and a card still unknown answers too, its number being all it
-- shows. Anything else is read as a name, as before.
local function Matches(card)
    local wanted = S.search or ""
    if wanted == "" then return true end
    if wanted:match("^%d+$") then
        return tostring(card.no or 0):find(wanted, 1, true) == 1
    end
    return Lower(card.name or ""):find(Lower(wanted), 1, true) ~= nil
end

local function LayoutTabs()
    local ui = S.ui
    for _, b in ipairs(ui.tabButtons) do b:Hide() end
    local tabs = { { id = ALL, name = L.all } }
    for _, tag in ipairs(S.cat.tags) do tabs[#tabs + 1] = tag end
    local found = false
    for _, tag in ipairs(tabs) do
        if tag.id == S.tab then found = true end
    end
    if not found then S.tab = ALL end
    for i, tag in ipairs(tabs) do
        local b = ui.tabButtons[i]
        if not b then
            b = CreateFrame("Button", nil, ui.tabs)
            b:SetSize(TAB_WIDTH, TAB_HEIGHT)
            b:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.label:SetPoint("CENTER")
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b:SetScript("OnClick", function(self)
                S.tab = self.tagId
                Refresh()
            end)
            ui.tabButtons[i] = b
        end
        b.tagId = tag.id
        b.label:SetText(tag.name)
        if tag.id == S.tab then
            b:SetBackdropColor(0.25, 0.2, 0.05, 1)
            b:SetBackdropBorderColor(1, 0.82, 0)
            b.label:SetTextColor(1, 0.82, 0)
        else
            b:SetBackdropColor(0, 0, 0, 0.8)
            b:SetBackdropBorderColor(0.5, 0.5, 0.5)
            b.label:SetTextColor(0.8, 0.8, 0.8)
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, -(i - 1) * (TAB_HEIGHT + 4))
        b:Show()
    end
end

local TogglePin                                -- defined after RefreshDeck, which it calls

local function CardButton(i)
    local ui = S.ui
    local b = ui.cardButtons[i]
    if b then return b end
    b = CreateFrame("Button", nil, ui.content)
    b:SetSize(CELL, CELL)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- The four edge numbers, each on a small trapezoid glued to the middle
    -- of its edge, as on a laid card, drawn smaller.
    b.edges, b.boxes = {}, {}
    local anchors = { "TOP", "RIGHT", "BOTTOM", "LEFT" }
    for e = 1, 4 do
        local box = CreateFrame("Frame", nil, b)
        if e == 1 or e == 3 then box:SetSize(DECK_BOX_LONG, DECK_BOX_SHORT)
        else box:SetSize(DECK_BOX_SHORT, DECK_BOX_LONG) end
        box:SetFrameLevel(b:GetFrameLevel() + 1)
        box:SetPoint(anchors[e], b, anchors[e], 0, 0)
        box.bg = box:CreateTexture(nil, "BACKGROUND")
        box.bg:SetAllPoints()
        box.bg:SetTexture(EDGE_BOX_TEXTURE)
        box.bg:SetTexCoord(unpack(TRAPEZOID_COORDS[e]))
        local text = box:CreateFontString(nil, "OVERLAY")
        text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        text:SetTextColor(0.95, 0.95, 0.95)
        local nudge = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }
        text:SetPoint("CENTER", nudge[e][1], nudge[e][2])
        box:Hide()
        b.boxes[e] = box
        b.edges[e] = text
    end
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", DragStart)
    b:SetScript("OnDragStop", DragStop)
    -- A CLICK (a press released without dragging) pins the hand on the card;
    -- a click on the pinned card lets the hand follow the mouse again.
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(self)
        if self.card and S.known[self.card.id] then TogglePin(self.card) end
    end)
    b:SetScript("OnEnter", function(self)
        if self.card and S.known[self.card.id] then
            HoverHand(self.card, ActOf(self.card))
        end
        CardTooltip(self)
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.cardButtons[i] = b
    return b
end

-- Every card of the tab shown -- every card at all under "All": known and
-- free, known and laid (dimmed), or not yet known (a question mark).
RefreshDeck = function()
    local ui = S.ui
    LayoutTabs()
    for _, b in ipairs(ui.cardButtons) do b:Hide() end
    local shown = 0
    for _, card in ipairs(S.cat.cards) do
        if (S.tab == ALL or card.tag == S.tab) and Matches(card) then
            shown = shown + 1
            local b = CardButton(shown)
            b.card = card
            if S.known[card.id] then
                b.icon:SetTexture(CardIcon(card))
                for e = 1, 4 do
                    b.edges[e]:SetText(card.edges[e])
                    b.boxes[e]:Show()
                end
                if S.pinned and S.pinned.id == card.id then
                    b:SetBackdropBorderColor(1, 0.82, 0)           -- gold: the hand is pinned here
                else
                    b:SetBackdropBorderColor(QualityColor(card.quality))
                end
                if S.placed[card.id] then
                    b.icon:SetDesaturated(true)
                    b:SetAlpha(0.4)
                else
                    b.icon:SetDesaturated(false)
                    b:SetAlpha(1)
                end
            else
                -- Not known yet: the red question mark, as the game draws it.
                b.icon:SetTexture(UNKNOWN_ICON)
                b.icon:SetDesaturated(false)
                b:SetBackdropBorderColor(0.6, 0.15, 0.15)
                b:SetAlpha(1)
                for e = 1, 4 do b.boxes[e]:Hide() end
            end
            local col, row = (shown - 1) % COLUMNS, floor((shown - 1) / COLUMNS)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", col * (CELL + GAP), -row * (CELL + GAP))
            b:Show()
        end
    end
    local rows = shown > 0 and (floor((shown - 1) / COLUMNS) + 1) or 0
    ui.content:SetHeight(math.max(rows * (CELL + GAP), 10))
end

TogglePin = function(card)
    if S.pinned and S.pinned.id == card.id then
        S.pinned = nil
    else
        S.pinned = card
    end
    ShowHand(card, ActOf(card))
    RefreshDeck()
end

-- ---------------------------------------------------------------------------
-- Drawing the board
-- ---------------------------------------------------------------------------

local function RefreshPicker()
    local ui = S.ui
    local picker = ui.picker
    for _, row in ipairs(picker.rows) do row:Hide() end
    local y, n = -6, 0
    local function Row(text, r, g, b, boardId, board)
        n = n + 1
        local row = picker.rows[n]
        if not row then
            row = CreateFrame("Button", nil, picker)
            row:SetSize(BOARD_WIDTH - 36, 20)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", 6, 0)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row:SetScript("OnClick", function(self)
                picker:Hide()
                AIO.Handle("StellarTarot", "Equip", self.boardId)
            end)
            row:SetScript("OnEnter", function(self) if self.board then ShowPreview(self.board, self) end end)
            row:SetScript("OnLeave", HidePreview)
            picker.rows[n] = row
        end
        row.boardId, row.board = boardId, board
        row.label:SetText(text)
        row.label:SetTextColor(r, g, b)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 6, y)
        row:Show()
        y = y - 20
    end
    Row(L.board_take_off, 0.7, 0.7, 0.7, 0, nil)
    for _, board in ipairs(S.cat.boards) do
        if S.knownBoards[board.id] then
            local r, g, b = QualityColor(board.quality)
            Row(fmt("%s (%dx%d)", board.name, board.rows, board.cols), r, g, b, board.id, board)
        end
    end
    picker:SetHeight(-y + 6)
end

function RefreshBoard(after)
    local ui = S.ui
    local board = S.layout and BoardById(S.layout.board)
    ui.slot.board = board
    if board then
        ui.slot.icon:SetTexture(ItemIcon(board.entry))
        ui.slot.label:SetText(board.name)
        ui.slot.label:SetTextColor(QualityColor(board.quality))
        ui.slot.hint:SetText(fmt(L.size, board.rows, board.cols))
        ui.boardNote:Hide()
    else
        ui.slot.icon:SetTexture(nil)
        ui.slot.label:SetText(L.board_none)
        ui.slot.label:SetTextColor(0.6, 0.6, 0.6)
        ui.slot.hint:SetText(L.board_pick)
        ui.boardNote:Show()
    end
    RefreshPicker()

    for _, cell in ipairs(ui.cells) do cell.act = nil end
    for _, side in pairs(ui.rims) do for _, t in ipairs(side) do t:Hide() end end
    if not board then
        for _, cell in ipairs(ui.cells) do cell:Hide() end
        ui.boardArt:Hide()
        return
    end

    -- The grid is centred in its frame; the rim numbers sit outside it.
    -- The frame for this size: drawn so that a cell is SLOT wide, centred
    -- in the grid area; every cell and every trapezoid at its measured place.
    local art = BOARD_FRAMES[board.rows .. "x" .. board.cols]
    local cellFrac = art.cells[1][3][3] - art.cells[1][3][1]
    local artW = SLOT / cellFrac
    local artH = artW / art.aspect
    ui.boardArt:SetTexture(art.texture)
    ui.boardArt:SetTexCoord(0, art.texcoord[1], 0, art.texcoord[2])
    ui.boardArt:SetSize(artW, artH)
    ui.boardArt:Show()
    local left, top = -artW / 2, artH / 2
    local function Zone(rect)
        return left + rect[1] * artW, top - rect[2] * artH, (rect[3] - rect[1]) * artW, (rect[4] - rect[2]) * artH
    end
    local cellZone = {}
    for _, z in ipairs(art.cells) do cellZone[z[1] * 10 + z[2]] = z[3] end
    for _, cell in ipairs(ui.cells) do
        if cell.row <= board.rows and cell.col <= board.cols then
            local zx, zy, zw, zh = Zone(cellZone[cell.row * 10 + cell.col])
            cell:ClearAllPoints()
            cell:SetSize(zw, zh)
            cell:SetPoint("TOPLEFT", ui.grid, "CENTER", zx, zy)
            local act = S.acts[cell.row * 10 + cell.col]
            local will = after and after[cell.row * 10 + cell.col]
            cell.act = act
            local lifted = S.dragFrom and S.dragFrom.row == cell.row and S.dragFrom.col == cell.col
            cell:SetAlpha(lifted and 0.35 or 1)
            if act then
                cell.icon:SetTexture(CardIcon(act.card))
                cell:SetBackdropBorderColor(QualityColor(act.card.quality))
                for e = 1, 4 do
                    cell.edges[e]:SetText(act.card.edges[e])
                    -- The same card still there, and matched: green. Matched
                    -- now but not after -- another card, or nothing, would face
                    -- it: red on the plain box.
                    local same = will and will.card.id == act.card.id
                    if act.matched[e] and (not after or (same and will.matched[e])) then
                        cell.edges[e]:SetTextColor(0.75, 1, 0.75)
                        cell.boxes[e].bg:SetTexture(EDGE_BOX_MATCH)
                    elseif act.matched[e] and after then
                        cell.edges[e]:SetTextColor(1, 0.35, 0.35)
                        cell.boxes[e].bg:SetTexture(EDGE_BOX_TEXTURE)
                    elseif same and will.matched[e] then
                        -- Would match once the dragged card is laid: cyan.
                        cell.edges[e]:SetTextColor(0.6, 1, 1)
                        cell.boxes[e].bg:SetTexture(EDGE_BOX_PREVIEW)
                    else
                        cell.edges[e]:SetTextColor(0.95, 0.95, 0.95)
                        cell.boxes[e].bg:SetTexture(EDGE_BOX_TEXTURE)
                    end
                    cell.boxes[e].bg:SetTexCoord(unpack(cell.boxes[e].coords))
                    cell.boxes[e]:Show()
                end
                cell.badge:SetText("")                  -- the lit edges say the level
            else
                cell.icon:SetTexture(nil)
                cell:SetBackdropBorderColor(0.4, 0.4, 0.4)
                for e = 1, 4 do cell.boxes[e]:Hide() end
                cell.badge:SetText("")
            end
            -- NEVER hidden and shown again while it stays on the board: a
            -- drag that started on it would be cancelled, without any event.
            if not cell:IsShown() then cell:Show() end
        else
            cell:Hide()
        end
    end
    -- A rim number lights up green when the card facing it matches it:
    -- the left edge (4) of the row's first card, the right edge (2) of its
    -- last, the top edge (1) of the column's first card, the bottom edge (3)
    -- of its last.
    -- A rim number on its trapezoid: green on a green trapezoid when the
    -- card facing it matches, cyan on a teal one when it would, red on a
    -- plain one when it would stop, white on a plain one otherwise.
    local function Rim(box, rect, value, key, edge)
        local act, will = S.acts[key], after and after[key]
        local zx, zy, zw, zh = Zone(rect)
        box:ClearAllPoints()
        box:SetSize(zw, zh)
        box:SetPoint("TOPLEFT", ui.grid, "CENTER", zx, zy)
        box.text:SetText(value)
        local now = act and act.matched[edge] or false
        local later = after and (will and will.matched[edge] or false) or now
        if now and later then
            box.text:SetTextColor(0.2, 1, 0.2)
            box.bg:SetTexture(EDGE_BOX_MATCH)
        elseif later then
            box.text:SetTextColor(0, 1, 1)
            box.bg:SetTexture(EDGE_BOX_PREVIEW)
        elseif now then
            box.text:SetTextColor(1, 0.35, 0.35)
            box.bg:SetTexture(EDGE_BOX_TEXTURE)
        else
            box.text:SetTextColor(1, 1, 1)
            box.bg:SetTexture(EDGE_BOX_TEXTURE)
        end
        box.bg:SetTexCoord(unpack(box.coords))
        box:Show()
    end
    for r = 1, board.rows do
        Rim(ui.rims.left[r], art.left[r], board.rowLeft[r], r * 10 + 1, 4)
        Rim(ui.rims.right[r], art.right[r], board.rowRight[r], r * 10 + board.cols, 2)
    end
    for c = 1, board.cols do
        Rim(ui.rims.top[c], art.top[c], board.colTop[c], 1 * 10 + c, 1)
        Rim(ui.rims.bottom[c], art.bottom[c], board.colBottom[c], board.rows * 10 + c, 3)
    end
end

local function RefreshPresets()
    local ui = S.ui
    for _, row in ipairs(ui.presetButtons) do row:Hide() end
    local presets = S.layout and S.layout.presets or {}
    local y = -4
    for i, preset in ipairs(presets) do
        local row = ui.presetButtons[i]
        if not row then
            row = CreateFrame("Button", nil, ui.presetRows)
            row:SetSize(BOARD_WIDTH - 90, 20)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", 4, 0)
            row.label:SetWidth(BOARD_WIDTH - 100)
            row.label:SetJustifyH("LEFT")
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row:SetScript("OnClick", function(self) AIO.Handle("StellarTarot", "PresetLoad", self.presetId) end)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.presetName, 1, 1, 1)
                local board = BoardById(self.boardId)
                if board then GameTooltip:AddLine(board.name, QualityColor(board.quality)) end
                GameTooltip:AddLine(L.preset_load, 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.delete = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            row.delete:SetSize(22, 22)
            row.delete:SetPoint("LEFT", row, "RIGHT", 0, 0)
            row.delete:SetScript("OnClick", function(self) AIO.Handle("StellarTarot", "PresetDelete", self:GetParent().presetId) end)
            row.delete:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.preset_delete, 1, 0.3, 0.3)
                GameTooltip:Show()
            end)
            row.delete:SetScript("OnLeave", function() GameTooltip:Hide() end)
            ui.presetButtons[i] = row
        end
        row.presetId, row.presetName, row.boardId = preset.id, preset.name, preset.board
        row.label:SetText(preset.name)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 4, y)
        row:Show()
        y = y - 22
    end
    if #presets == 0 then
        ui.presetNote:SetText(L.preset_none)
        ui.presetNote:Show()
        y = y - 20
    else
        ui.presetNote:Hide()
    end
    ui.presetRows:SetHeight(-y + 4)
end

function Refresh()
    if not S.ui or not S.cat then return end
    S.acts, S.placed = Activations()
    RefreshDeck()
    RefreshBoard()
    RefreshPresets()
    RefreshEffects()
    -- The card in hand follows the board: its level may have changed.
    if S.pinned then
        ShowHand(S.pinned, ActOf(S.pinned))
    elseif S.hover then
        ShowHand(S.hover.card, ActOf(S.hover.card))
    end
    if S.projection then RefreshProjection() end
end

-- ---------------------------------------------------------------------------
-- What the server sends
-- ---------------------------------------------------------------------------

local function Take(catalogue, binder, layout)
    S.cat = catalogue
    PROC_SPELLS = nil
    SCALED_NAMES = nil
    -- The players' numbers: 1 onwards, in the order the server lists the
    -- cards (by catalogue number).
    for i, card in ipairs(S.cat.cards) do card.no = i end
    SetBinder(binder)
    S.layout = layout
    S.acts, S.placed = Activations()
end

-- At login: everything, and no window. The aura's tooltip reads it.
function Handlers.Prime(_, catalogue, binder, layout)
    Take(catalogue, binder, layout)
end

function Handlers.Show(_, catalogue, binder, layout)
    Take(catalogue, binder, layout)
    Build()
    Refresh()
    S.ui.frame:Show()
end

function Handlers.Binder(_, binder)
    SetBinder(binder)
    if S.ui and S.ui.frame:IsShown() then Refresh() end
end

function Handlers.Layout(_, layout)
    S.layout = layout
    S.acts, S.placed = Activations()
    if S.ui and S.ui.frame:IsShown() then Refresh() end
end

-- ---------------------------------------------------------------------------
-- THE AURA'S TOOLTIP LISTS THE EFFECTS IN FORCE. The aura's own text is the
-- client's spell file, fixed; the lines under it are added here, from the
-- layout the server sent, whenever the buff "Stellar Tarot" is hovered.
-- Installed once per session, and reading the CURRENT state through a global.
-- ---------------------------------------------------------------------------

local BANNER_SPELL = 903002

-- The effects in force, without their source, MERGED and GROUPED. Two
-- effects that read the same but for their figure become one line with the
-- figures added -- "+50 Stamina" and "+150 Stamina" read "+200 Stamina"; an
-- effect with no figure is listed once. And the effects that share a
-- CONDITION -- the part before the colon, "Si 2 armes équipées :" -- stand
-- under it, indented, when there are two or more; a lone one stays on its
-- line. Every line is { text, indent }.
-- THE EVENTS AND CONDITIONS, NORMALISED. An effect begins with a trigger
-- ("subir des dégâts", "vos attaques", "tuer un ennemi"...) or reads
-- "condition : effect"; every wording is brought to ONE canonical form, the
-- key the effects are grouped under and the heading they are listed under.
-- The prefixes are in the short form Pretty gives the text; longest first.
local TRIGGERS = {
    -- damage taken
    { "subir un coup critique", "Subir un crit." }, { "subir un crit.", "Subir un crit." },
    { "subir des dégâts", "Subir des dégâts" }, { "recevoir des dégâts", "Subir des dégâts" },
    { "être touché en mêlée", "Subir des dégâts" }, { "être touché", "Subir des dégâts" },
    { "subir un sort de dégâts", "Subir un sort" }, { "subir un sort de contrôle", "Subir un contrôle" },
    { "subir un sort", "Subir un sort" }, { "subir un contrôle", "Subir un contrôle" },
    { "être étourdi ou enraciné", "Subir un contrôle" }, { "après une peur ou un charme subi", "Subir un contrôle" },
    { "subir 5 coups d'affilée sans en rendre", "Subir des dégâts" },
    { "quand des dégâts sont subis", "Subir des dégâts" }, { "quand vous subissez des dégâts", "Subir des dégâts" },
    { "quand inflige des dégâts", "Infliger des dégâts" }, { "quand vous infligez des dégâts", "Infliger des dégâts" },
    { "quand vous touchez", "Infliger des dégâts" },
    -- damage dealt
    { "infliger un coup critique", "Infliger un crit." }, { "infliger un crit.", "Infliger un crit." },
    { "effectuer un coup critique", "Infliger un crit." }, { "effectuer un crit.", "Infliger un crit." },
    { "vos coups critiques de sort", "Infliger un crit. de sort" }, { "vos crit. de sort", "Infliger un crit. de sort" },
    { "vos coups critiques de feu", "Infliger un crit. de feu" }, { "vos crit. de feu", "Infliger un crit. de feu" },
    { "vos coups critiques", "Infliger un crit." }, { "vos crit.", "Infliger un crit." },
    { "infliger des dégâts", "Infliger des dégâts" }, { "vos attaques et sorts", "Infliger des dégâts" },
    { "vos attaques à distance", "Infliger des dégâts à distance" }, { "vos attaques", "Infliger des dégâts" },
    { "chaque coup porté", "Infliger des dégâts" },
    { "attaquer une cible que personne d'autre n'attaque", "Cible que personne d'autre n'attaque" },
    { "face à un seul ennemi", "Face à un seul ennemi" },
    { "rater une attaque", "Rater une attaque" },
    -- spells
    { "vos sorts de dégâts", "Lancer un sort" }, { "vos sorts de feu", "Lancer un sort de feu" },
    { "vos sorts de givre", "Lancer un sort de givre" }, { "vos sorts de nature", "Lancer un sort de nature" },
    { "vos sorts d'ombre", "Lancer un sort d'ombre" }, { "vos sorts périodiques", "Lancer un sort périodique" },
    { "vos effets périodiques", "Effets périodiques" }, { "vos sorts à incantation", "Lancer un sort" },
    { "vos sorts de zone", "Lancer un sort de zone" }, { "vos sorts", "Lancer un sort" },
    { "lancer un sort périodique", "Lancer un sort périodique" }, { "lancer un sort de feu", "Lancer un sort de feu" },
    { "lancer plusieurs fois de suite le même sort", "Lancer un sort" }, { "lancer 5 sorts d'affilée", "Lancer un sort" },
    { "lancer un sort", "Lancer un sort" }, { "changer d'école de sort", "Changer d'école de sort" },
    { "les tirs de baguette", "Tir de baguette" }, { "chaque tir de baguette", "Tir de baguette" },
    -- healing
    { "vos soins critiques", "Soin critique" }, { "soigner un allié", "Soigner" }, { "vos soins", "Soigner" },
    -- kills, combat, movement
    { "tuer un ennemi avec un sort", "Tuer un ennemi" }, { "tuer un ennemi", "Tuer un ennemi" },
    { "quand votre familier tue un ennemi", "Tuer un ennemi" }, { "tuer un boss", "Tuer un boss" },
    { "entrer en combat", "Entrer en combat" }, { "sortir du combat", "Sortir du combat" },
    { "être le premier du groupe à engager un ennemi", "Entrer en combat" },
    { "esquiver", "Esquiver" }, { "bloquer ou parer", "Parer ou bloquer" }, { "parer", "Parer ou bloquer" },
    { "mourir", "Mourir" }, { "revenir à la vie", "Revenir à la vie" }, { "rester immobile", "Rester immobile" },
    { "sauter", "Sauter" }, { "courir", "Courir" }, { "marcher", "Marcher" },
    -- states
    { "à chaque connexion", "À chaque connexion" }, { "la nuit", "La nuit" }, { "de nuit", "La nuit" },
    { "de jour", "De jour" }, { "seul", "Seul" }, { "en combat", "En combat" }, { "hors combat", "Hors combat" },
    { "être reposé", "Reposé" }, { "être monté", "Monté" }, { "être dans l'eau", "Dans l'eau" },
    { "marée haute", "Marée haute" }, { "marée basse", "Marée basse" },
    { "chaque changement de marée", "Changement de marée" },
    -- world
    { "terminer une quête", "Terminer une quête" }, { "les quêtes journalières", "Quête journalière" },
    { "découvrir une nouvelle zone", "Découvrir une zone" }, { "boire une potion", "Boire une potion" },
    { "boire", "Boire" }, { "manger ou boire", "Manger ou boire" }, { "manger", "Manger" },
    { "fabriquer un objet", "Fabriquer un objet" }, { "fabriquer une potion", "Fabriquer un objet" },
    { "extraire un filon", "Extraire un filon" }, { "fondre un minerai", "Fondre un minerai" },
    { "cueillir une plante", "Cueillir une plante" }, { "dépecer un cadavre", "Dépecer" }, { "pêcher", "Pêcher" },
    { "ouvrir un butin", "Ouvrir un butin" }, { "ouvrir un coffre", "Ouvrir un coffre" },
    { "ouvrir un conteneur", "Ouvrir un conteneur" }, { "acheter un objet chez un marchand", "Acheter chez un marchand" },
    { "acheter chez un marchand", "Acheter chez un marchand" }, { "vendre un objet", "Vendre un objet" },
    { "réparer", "Réparer" }, { "arriver d'un vol", "Arriver d'un vol" }, { "prendre un vol", "Prendre un vol" },
    { "atteindre un nouveau niveau", "Monter de niveau" }, { "monter de niveau", "Monter de niveau" },
    { "utiliser la pierre de foyer", "Pierre de foyer" }, { "entrer dans une instance", "Entrer dans une instance" },
    { "entrer dans une capitale", "Entrer dans une capitale" },
    -- others
    { "la mort de votre familier", "Mort du familier" }, { "votre familier", "Familier" }, { "le familier", "Familier" },
    { "le groupe à 20 m", "Le groupe à 20 m" }, { "le groupe à 30 m", "Le groupe à 30 m" },
    { "quand un allié à 30 m", "Un allié à 30 m" }, { "quand un allié à 20 m", "Un allié à 20 m" },
    { "quand un allié à moins de 10 m", "Un allié à 10 m" }, { "quand un membre du groupe à 30 m", "Un allié à 30 m" },
    { "posséder plus de", "Posséder plus de" },
}
-- A qualifier that follows a trigger stays with it, in one spelling.
local QUALIFIERS = { { "physiques", "physiques" }, { "physique", "physiques" }, { "magiques", "magiques" },
                     { "mortels", "mortels" } }
-- Conditions that carry a figure: "sous 30% PV", "sous 20% de mana".
local THRESHOLDS = { { "^sous (%d+)%% pv", "Sous %s%% PV" }, { "^sous (%d+)%% de mana", "Sous %s%% de mana" },
                     { "^sous (%d+)%% de pv", "Sous %s%% PV" } }

-- Case, ASCII only: string.lower/upper follow the locale and may mangle
-- the bytes of an accented letter.
Lower = function(text)
    return (text:gsub("[A-Z]", function(c) return string.char(c:byte() + 32) end))
end
local function Capitalise(text)
    return (text:gsub("^[a-z]", function(c) return string.char(c:byte() - 32) end))
end

-- The canonical form of a condition, and what is left of the effect.
local function Canonical(text)
    local lower = Lower(text)
    for _, t in ipairs(THRESHOLDS) do
        local a, b, n = lower:find(t[1])
        if a then
            local rest = text:sub(b + 1):gsub("^%s*[,:]?%s*", "")
            return string.format(t[2], n), rest
        end
    end
    for _, pair in ipairs(TRIGGERS) do
        local t = Lower(pair[1])
        if lower:sub(1, #t) == t then
            local after = text:sub(#t + 1)
            local sep = after:match("^%s*[,:]%s*") or after:match("^%s+") or ""
            if sep ~= "" or after == "" then
                local cond, rest = pair[2], after:sub(#sep + 1)
                for _, q in ipairs(QUALIFIERS) do
                    if Lower(rest):sub(1, #q[1] + 1) == q[1] .. " " then
                        cond, rest = cond .. " " .. q[2], rest:sub(#q[1] + 2)
                        break
                    end
                end
                return cond, rest
            end
        end
    end
    return nil, text
end

-- THE CONDITIONS OF EQUIPMENT AND SITUATION, matched whole -- before the
-- colon ("Si 2 armes équipées : ...") or at the END of the effect ("... si un
-- bouclier est équipé") -- and brought to one form.
local CONDITIONS = {
    { "si une seule arme à 2 mains est équipée", "Arme à 2 mains" },
    { "si une arme à 2 mains est équipée", "Arme à 2 mains" }, { "si une arme à deux mains est équipée", "Arme à 2 mains" },
    { "si un bouclier est équipé", "Bouclier équipé" }, { "si un bouclier équipé", "Bouclier équipé" },
    { "si 2 armes équipées", "2 armes équipées" }, { "si deux armes équipées", "2 armes équipées" },
    { "si 2 armes sont équipées", "2 armes équipées" }, { "si aucune arme", "Aucune arme" },
    { "si aucune arme équipée", "Aucune arme" }, { "sans arme", "Aucune arme" },
    { "quand vous n'êtes pas en groupe", "Seul" }, { "si vous n'êtes pas en groupe", "Seul" }, { "seul", "Seul" },
    { "en groupe", "En groupe" }, { "en combat", "En combat" }, { "hors combat", "Hors combat" },
    { "la nuit", "La nuit" }, { "de jour", "De jour" }, { "face à un seul ennemi", "Face à un seul ennemi" },
    { "contre les cibles à plus de 90% de pv", "Cible à plus de 90% PV" },
    { "quand vous touchez", "Infliger des dégâts" }, { "quand des dégâts sont subis", "Subir des dégâts" },
    { "contre une cible à plus de 50% de pv", "Cible à plus de 50% PV" },
}

-- A condition read whole: one of the known ones, else a trigger read whole,
-- else as written with a capital.
local function CanonicalCondition(cond)
    local lower = Lower(cond):gsub("^%s+", ""):gsub("%s*:?%s*$", "")
    for _, p in ipairs(CONDITIONS) do
        if lower == p[1] then return p[2] end
    end
    local canon, left = Canonical(cond)
    if canon and left == "" then return canon end
    return Capitalise(cond)
end

-- A known condition at the END of the effect: its canonical form and the
-- effect before it, or nil.
local function TrailingCondition(text)
    local lower = Lower(text)
    for _, p in ipairs(CONDITIONS) do
        local tail = " " .. p[1]
        if #lower > #tail and lower:sub(-#tail) == tail then
            return p[2], (text:sub(1, #text - #tail):gsub("[%s,]+$", ""))
        end
        -- The condition in the middle of the effect, before a punctuation:
        -- "peut appliquer un saignement quand vous touchez. dure 16 s".
        local a, b = lower:find(tail, 1, true)
        if a and a > 1 and lower:sub(b + 1, b + 1):match("[%.,;]") then
            local before = text:sub(1, a - 1):gsub("[%s,]+$", "")
            local after = text:sub(b + 1)
            return p[2], (before .. after)
        end
    end
    return nil
end

-- Splits an effect into its canonical condition and the rest: "cond : rest"
-- (the condition normalised when it is a known one, capitalised otherwise),
-- or a trigger at the start of the effect.
SplitCondition = function(text)
    -- A known trigger or threshold at the start wins, whatever follows.
    local canon, left = Canonical(text)
    if canon and left ~= "" then
        -- "vos attaques peuvent ..." under "Infliger des dégâts" reads "peut ..."
        left = left:gsub("^peuvent ", "peut ")
        return canon, left
    end
    -- Else "condition : effect", the condition normalised.
    local cond, rest = text:match("^(.-)%s*:%s*(.+)$")
    if cond and cond ~= "" then return CanonicalCondition(cond), rest end
    -- Else "effect ... if <condition>", a known condition at the end.
    local tail, before = TrailingCondition(text)
    if tail then return tail, before end
    return nil, text
end

function STELLAR_TAROT_ACTIVE_LINES()
    local lines = {}
    if not S.cat then return lines end
    local keys = {}
    for key in pairs(S.acts) do keys[#keys + 1] = key end
    table.sort(keys)
    local order, totals = {}, {}
    local groups, groupOrder = {}, {}
    -- "+20 endurance et +20 force", "+8% dégâts mais -8% PV": several TERMS,
    -- each summed on its own with the same term of other cards. A line is
    -- split only when every piece is a signed figure and a statistic.
    local function SplitTerms(rest)
        local pieces = {}
        for piece in (rest .. " " .. MOTS.et .. " "):gmatch("(.-)%s+" .. MOTS.et .. "%s+") do
            for sub in (piece .. " " .. MOTS.mais .. " "):gmatch("(.-)%s+" .. MOTS.mais .. "%s+") do
                for part in (sub .. ", "):gmatch("(.-),%s+") do
                    if part ~= "" then pieces[#pieces + 1] = part end
                end
            end
        end
        if #pieces < 2 then return nil end
        for _, p in ipairs(pieces) do
            if not p:match("^[+-]%d+[,.]?%d*%%?%s+%S") then return nil end
            -- « -10% sous 60% PV » commence bien par un chiffre signe, mais ce
            -- n'est pas une statistique : c'est une condition, et la ligne doit
            -- rester entiere plutot que de se couper en deux.
            if p:find(MOTS.seuil, 1, true) then return nil end
        end
        return pieces
    end
    -- THE BANNER SAYS WHAT IS IN FORCE NOW. Night, by the clock of the machine
    -- as the server reads it: from 21:00 to 06:00. A figure the night changes
    -- shows its night value, an effect the night alone grants is not listed by
    -- day, and the markers themselves never show.
    local hour = tonumber(date("%H")) or 12
    local night = hour < 6 or hour >= 21
    local function Tonight(text)
        local only = false
        local t = text
        local mark = function() only = true; return "" end
        for _, motif in ipairs(MOTS.nuit_seule) do
            t = t:gsub(motif, mark)
        end
        if only and not night then return nil end
        local figure
        for _, motif in ipairs(MOTS.nuit_chiffre) do
            figure = figure or t:match(motif)
        end
        if figure then
            for _, motif in ipairs(MOTS.nuit_retrait) do
                t = t:gsub(motif, "")
            end
            if night then
                -- the figure of the effect, not one the condition names; a
                -- signed night figure replaces the day's sign as well
                local pattern = figure:match("^[%-%+]") and "[%-%+]?%d+" or "%d+"
                local head, rest = t:match("^(.- : )(.+)$")
                if head then t = head .. (rest:gsub(pattern, figure, 1))
                else t = (t:gsub(pattern, figure, 1)) end
            end
        end
        return t
    end
    local AddOne
    local function Add(text)
        if not text or text == "" or text == "-" then return end
        text = Tonight(text)
        if not text then return end
        local cond, rest = SplitCondition(text)
        local terms = SplitTerms(rest)
        if terms then
            for _, term in ipairs(terms) do AddOne(cond, term) end
        else
            AddOne(cond, rest)
        end
    end
    AddOne = function(cond, rest)
        local condKey = cond and cond:lower() or ""
        -- The first number of the effect is the figure; the rest is the key.
        local figure = rest:match("%d+")
        local restKey = figure and rest:gsub("%d+", "#", 1) or rest
        local key = condKey .. "|" .. restKey
        if not totals[key] then
            totals[key] = { cond = cond, condKey = condKey, text = rest, key = restKey, sum = 0,
                            figure = figure ~= nil }
            order[#order + 1] = key
            if cond then
                if not groups[condKey] then
                    groups[condKey] = { cond = cond, keys = {} }
                    groupOrder[#groupOrder + 1] = condKey
                end
                local g = groups[condKey]
                g.keys[#g.keys + 1] = key
            end
        end
        if figure then totals[key].sum = totals[key].sum + tonumber(figure) end
    end
    for _, key in ipairs(keys) do
        local act = S.acts[key]
        if act.level > 0 then
            local first = act.card.cumulative and 1 or act.level
            for level = first, act.level do
                local spell = act.card.spells and act.card.spells[level] or 0
                if spell and spell ~= 0 then Add(SpellText(spell)) end
                local script = act.card.scripts and act.card.scripts[level]
                if script and script.desc ~= "" then Add(script.desc) end
            end
        end
    end
    local function Text(entry)
        local text = entry.text
        if entry.figure then text = (entry.key:gsub("#", tostring(entry.sum), 1)) end
        if entry.condKey == MOTS.par_niveau then text = ScaledBonus(text, UnitLevel("player")) end
        return text
    end
    -- LES GAINS ENSEMBLE, LES PERTES ENSEMBLE. Le joueur lit ce qu'il gagne,
    -- puis ce que cela lui coute ; ce qui ne porte pas de signe -- une phrase,
    -- un effet qui se declenche -- tient le milieu. A rang egal, l'ordre
    -- d'arrivee departage.
    local function Rang(texte)
        if texte:match("^%s*%+") then return 1 end
        if texte:match("^%s*%-") then return 3 end
        return 2
    end
    local function Ranger(liste)
        local ordre = {}
        for i, e in ipairs(liste) do ordre[i] = { i = i, e = e } end
        table.sort(ordre, function(a, b)
            local ra, rb = Rang(a.e.text), Rang(b.e.text)
            if ra ~= rb then return ra < rb end
            return a.i < b.i
        end)
        local out = {}
        for i, o in ipairs(ordre) do out[i] = o.e end
        return out
    end
    local done, plats, blocs = {}, {}, {}
    for _, key in ipairs(order) do
        local entry = totals[key]
        if not entry.cond then
            plats[#plats + 1] = { text = Text(entry), indent = false }
        elseif not done[entry.condKey] then
            done[entry.condKey] = true
            local g = groups[entry.condKey]
            if entry.condKey == MOTS.par_niveau then
                -- CE N'EST PAS UNE CONDITION, c'est une mesure : la banniere
                -- donne le total, sans dire d'ou il vient.
                for _, k in ipairs(g.keys) do
                    plats[#plats + 1] = { text = Text(totals[k]), indent = false }
                end
            else
                local sous = {}
                for _, k in ipairs(g.keys) do
                    sous[#sous + 1] = { text = Text(totals[k]), indent = true }
                end
                blocs[#blocs + 1] = { cond = g.cond, items = Ranger(sous) }
            end
        end
    end
    -- Ce qui vaut toujours d'abord, ce qui demande une condition ensuite.
    for _, e in ipairs(Ranger(plats)) do lines[#lines + 1] = e end
    for _, b in ipairs(blocs) do
        lines[#lines + 1] = { text = b.cond .. " :", indent = false }
        for _, e in ipairs(b.items) do lines[#lines + 1] = e end
    end
    return lines
end

-- The hook itself is installed once per session; what it does is a global
-- function, redefined by every reload of this file, so that a reload changes
-- the behaviour without a restart.
-- THE BUFFS OF THE PROCS. A level whose script grants its aura for a while
-- shows in the buff bar; its tooltip is the bonus alone, and the bonus is
-- shown MULTIPLIED BY THE STACKS -- the client is not told an aura's real
-- amount, only its stack count, so the figure is computed here.
-- UN NIVEAU DE CARTE, reconnu a son IDENTIFIANT. Le nom ne sert plus que de
-- repli, pour un client qui ne donnerait pas l'identifiant dans UnitAura.
local function SortDeNiveau(id, name)
    if not S.cat then return nil end
    if not PROC_SPELLS then
        PROC_SPELLS = {}
        for _, card in ipairs(S.cat.cards) do
            for level = 1, 4 do
                local sid = card.spells and card.spells[level]
                if sid and sid ~= 0 then
                    PROC_SPELLS[sid] = sid
                    local spellName = GetSpellInfo(sid)
                    if spellName then PROC_SPELLS[spellName] = sid end
                end
            end
        end
    end
    return (id and PROC_SPELLS[id]) or (name and PROC_SPELLS[name])
end

ScaledBonus = function(text, count)
    if not count or count <= 1 then return text end
    return (text:gsub("([+-])(%d+[,.]?%d*)", function(sign, n)
        local v = tonumber((n:gsub(",", "."))) * count
        local s = (v == math.floor(v)) and tostring(math.floor(v)) or string.format("%.1f", v):gsub("%.", ",")
        return sign .. s
    end))
end

-- LE SAIGNEMENT : un tic toutes les 2 secondes valant une PART de la puissance
-- d'attaque du lanceur. Le client n'est pas averti du montant du tic ; il le
-- calcule ici, le joueur etant le lanceur. Le feu du module, lui, ne dit rien
-- de son chiffre, comme les effets periodiques de Blizzard.
--
-- LA PART NE SE RECOPIE PLUS : elle est dans la ligne de la carte,
-- `bleed:<sec>:<part>`, que le catalogue porte deja jusqu'ici. Si le classeur
-- change la part, l'infobulle suit.
--
-- `bleed_hit:<sec>:<part>:<sort>` est un AUTRE saignement : sa part se prend
-- sur LE COUP qui vient de porter, non sur la puissance d'attaque, et le
-- client ne connait pas ce coup. Son infobulle dit « 2 % du coup », ce qui est
-- deja vrai : elle n'est pas reecrite.
local BLEED_SPELL = 903802      -- l'etabli : une part de la puissance d'attaque
local PARTS_DE_SAIGNEMENT
local function PartDeSaignement(id, name)
    if not (S.cat and S.cat.cards) then return nil end
    if not PARTS_DE_SAIGNEMENT then
        PARTS_DE_SAIGNEMENT = {}
        local function poser(sort, part)
            sort, part = tonumber(sort), tonumber(part)
            if not (sort and part) then return end
            PARTS_DE_SAIGNEMENT[sort] = part
            local n = GetSpellInfo(sort)
            if n then PARTS_DE_SAIGNEMENT[n] = part end
        end
        for _, card in ipairs(S.cat.cards) do
            for level = 1, 4 do
                local spec = card.scripts and card.scripts[level]
                              and card.scripts[level].text or ""
                -- « bleed: » seul : « bleed_hit: » ne repond pas au motif, le
                -- deux-points ne suivant pas immediatement le mot.
                poser(BLEED_SPELL, spec:match("bleed:%d+:(%d+)"))
            end
        end
    end
    return (id and PARTS_DE_SAIGNEMENT[id]) or (name and PARTS_DE_SAIGNEMENT[name])
end

local function BleedText(part)
    local base, pos, neg = UnitAttackPower("player")
    local ap = (base or 0) + (pos or 0) + (neg or 0)
    return fmt(FR and "Saigne : %d dégâts toutes les 2 sec" or "Bleeds: %d damage every 2 sec",
               math.floor(ap * part / 100))
end

-- ---------------------------------------------------------------------------
-- CE QU'UNE CARTE AJOUTE A UNE POTION. Le client ecrit l'infobulle d'un buff
-- depuis son propre Spell.dbc : elle ne dit que les chiffres de la potion, le
-- serveur ne lui envoyant d'une aura ni montant ni texte. Le module chuchote
-- donc les montants qu'il applique vraiment -- un message d'addon, comme AIO
-- en envoie -- et l'infobulle est corrigee ici, chiffre par chiffre.
--
-- La table est rangee PAR NOM DE SORT : c'est ce que l'infobulle donne.
-- ---------------------------------------------------------------------------

STELLAR_TAROT_POTION_BOOST = STELLAR_TAROT_POTION_BOOST or {}

if not STELLAR_TAROT_POTION_HOOKED then
    STELLAR_TAROT_POTION_HOOKED = true
    local receiver = CreateFrame("Frame")
    receiver:RegisterEvent("CHAT_MSG_ADDON")
    receiver:SetScript("OnEvent", function(_, _, prefix, message)
        if prefix ~= "StellarTarotPotion" or not message then return end
        local id, rest = message:match("^(%d+)(.*)$")
        local spellName = id and GetSpellInfo(tonumber(id))
        if not spellName then return end
        local map, any = {}, false
        for propre, releve in rest:gmatch("|(%-?%d+)&(%-?%d+)") do
            map[propre], any = releve, true
        end
        -- PAR IDENTIFIANT D'ABORD : deux sorts peuvent porter le meme nom. Le
        -- nom reste en repli, pour un client qui ne donnerait pas
        -- l'identifiant dans UnitAura.
        STELLAR_TAROT_POTION_BOOST[tonumber(id)] = any and map or nil
        STELLAR_TAROT_POTION_BOOST[spellName] = any and map or nil
    end)
end

-- ---------------------------------------------------------------------------
-- LE BÉNÉFICE D'UNE VENTE, ANNONCÉ QUAND LE MARCHAND SE FERME.
--
-- Le serveur ne sait pas quand la fenêtre du marchand se ferme : le client
-- n'envoie rien en la fermant. Il envoie donc ce que CHAQUE vente a rapporté
-- en plus, et c'est ici qu'on additionne, pour le dire d'un trait au moment où
-- le joueur repart -- une ligne par carte qui y a contribué.
--
-- Le nom de la carte vient du DBC du client (`GetSpellInfo`), donc dans sa
-- langue ; la parenthèse du niveau est retirée, c'est la CARTE qui parle.
-- ---------------------------------------------------------------------------

if not STELLAR_TAROT_PROFIT_HOOKED then
    STELLAR_TAROT_PROFIT_HOOKED = true
    local gains = {}                       -- nom de carte -> cuivre

    local PIECES = FR and { { 10000, "pièce d'or", "pièces d'or" },
                            { 100, "pièce d'argent", "pièces d'argent" },
                            { 1, "pièce de cuivre", "pièces de cuivre" } }
                     or { { 10000, "gold coin", "gold coins" },
                          { 100, "silver coin", "silver coins" },
                          { 1, "copper coin", "copper coins" } }

    -- « 15 pièces d'argent », « 2 pièces d'or et 15 pièces d'argent » : les
    -- rangs nuls se taisent, et le dernier se joint par « et ».
    local function Somme(cuivre)
        local bouts, reste = {}, cuivre
        for _, rang in ipairs(PIECES) do
            local combien = math.floor(reste / rang[1])
            reste = reste - combien * rang[1]
            if combien > 0 then
                bouts[#bouts + 1] = combien .. " " .. (combien > 1 and rang[3] or rang[2])
            end
        end
        if #bouts == 0 then return nil end
        if #bouts == 1 then return bouts[1] end
        local dernier = table.remove(bouts)
        return table.concat(bouts, ", ") .. (FR and " et " or " and ") .. dernier
    end

    local function Nom(spellId)
        local nom = GetSpellInfo(spellId)
        if not nom then return nil end
        return (nom:gsub("%s*%b()%s*$", ""))
    end


-- ---------------------------------------------------------------------------
-- LE BLOC DE MESURE
--
-- Un bloc de texte, deplacable, qui dit en continu ce que porte le personnage :
-- ce que le client sait lire lui-meme -- statistiques, scores et le pourcentage
-- auquel chacun se convertit, vitesse -- et ce que le SERVEUR est seul a
-- savoir : les multiplicateurs de degats et de soins, qu'aucune fonction du
-- client n'expose, et l'etat des lignes de cartes qui majorent un chiffre au
-- moment du coup, lesquelles ne posent aucune aura.
--
-- `.tarot hud` l'allume et l'eteint. Le serveur pousse son bloc une fois par
-- seconde ; le cote client se relit cinq fois par seconde.
-- ---------------------------------------------------------------------------
local HUD = { serveur = {}, lignes = {} }

local CR = {   -- les indices de l'API du client, 1-based
    { "Toucher mêlée", 6 }, { "Toucher distance", 7 }, { "Toucher sorts", 8 },
    { "Critique mêlée", 9 }, { "Critique distance", 10 }, { "Critique sorts", 11 },
    { "Hâte mêlée", 18 }, { "Hâte distance", 19 }, { "Hâte sorts", 20 },
    { "Esquive", 3 }, { "Parade", 4 }, { "Blocage", 5 }, { "Défense", 2 },
}

local function Ligne(nom, valeur, extra)
    if extra then
        return fmt("|cffa0a0a0%s|r  |cffffffff%s|r  |cff808080(%s)|r", nom, valeur, extra)
    end
    return fmt("|cffa0a0a0%s|r  |cffffffff%s|r", nom, valeur)
end

local function BlocClient()
    local t = {}
    t[#t + 1] = "|cffffd100Statistiques|r"
    local STATS = { "Force", "Agilité", "Endurance", "Intelligence", "Esprit" }
    for i = 1, 5 do
        -- LE PREMIER RETOUR DE `UnitStat` EST LE TOTAL, non la base : Blizzard
        -- lui-même calcule la base par `stat - posBuff - negBuff`
        -- (PaperDollFrame.lua). Et le client ne sait pas séparer un bonus fixe
        -- d'un bonus en pourcentage : quand le serveur l'a dit, on le croit.
        local total, effectif, pos, neg = UnitStat("player", i)
        local part = HUD.serveur["stat" .. (i - 1)]
        if part then
            local base, fixe, pct, somme, dixiemes = part[1], part[2], part[3], part[4], part[5]
            local detail = fmt("base %d", base)
            if fixe ~= 0 then detail = detail .. fmt(" %+d", fixe) end
            if pct ~= 0 then detail = detail .. fmt(" %+d à %+.1f%%", pct, dixiemes / 10) end
            t[#t + 1] = Ligne(STATS[i], somme, detail)
        else
            t[#t + 1] = Ligne(STATS[i], effectif, fmt("base %d, %+d / %d", total - pos - neg, pos, neg))
        end
    end
    t[#t + 1] = Ligne("PV max", UnitHealthMax("player"))
    t[#t + 1] = Ligne("Ressource max", UnitPowerMax("player"))
    t[#t + 1] = Ligne("Armure", (select(2, UnitArmor("player"))))

    t[#t + 1] = " "
    t[#t + 1] = "|cffffd100Scores de combat|r  |cff808080(valeur → %)|r"
    for _, c in ipairs(CR) do
        local score = GetCombatRating(c[2]) or 0
        local pct = GetCombatRatingBonus(c[2]) or 0
        if score ~= 0 or pct ~= 0 then
            t[#t + 1] = Ligne(c[1], score, fmt("%.2f%%", pct))
        end
    end
    -- PÉNÉTRATION D'ARMURE ET EXPERTISE : dites par le SERVEUR, et montrées
    -- même à zéro. Ce sont elles que lisent les lignes de cartes à part de
    -- score, et savoir qu'on n'en porte aucune vaut autant que le chiffre.
    for _, c in ipairs({ { "Pénétration d'armure", "armorpen" }, { "Expertise", "expertise" } }) do
        local p = HUD.serveur[c[2]]
        if p then
            t[#t + 1] = Ligne(c[1], p[1], fmt("%.1f%%", p[2] / 10))
        end
    end

    t[#t + 1] = " "
    t[#t + 1] = "|cffffd100Chances effectives|r"
    t[#t + 1] = Ligne("Critique mêlée", fmt("%.2f%%", GetCritChance() or 0))
    t[#t + 1] = Ligne("Critique distance", fmt("%.2f%%", GetRangedCritChance() or 0))
    t[#t + 1] = Ligne("Critique sorts", fmt("%.2f%%", GetSpellCritChance(2) or 0))
    t[#t + 1] = Ligne("Esquive", fmt("%.2f%%", GetDodgeChance() or 0))
    t[#t + 1] = Ligne("Parade", fmt("%.2f%%", GetParryChance() or 0))
    t[#t + 1] = Ligne("Blocage", fmt("%.2f%%", GetBlockChance() or 0))

    t[#t + 1] = " "
    t[#t + 1] = "|cffffd100Puissance|r"
    local ap, apPos, apNeg = UnitAttackPower("player")
    t[#t + 1] = Ligne("Puissance d'attaque", (ap or 0) + (apPos or 0) + (apNeg or 0))
    local rap, rPos, rNeg = UnitRangedAttackPower("player")
    t[#t + 1] = Ligne("Puissance à distance", (rap or 0) + (rPos or 0) + (rNeg or 0))
    t[#t + 1] = Ligne("Puissance des sorts", GetSpellBonusDamage(2) or 0)
    t[#t + 1] = Ligne("Puissance de soin", GetSpellBonusHealing and GetSpellBonusHealing() or 0)

    t[#t + 1] = " "
    t[#t + 1] = "|cffffd100Déplacement|r"
    local vitesse = GetUnitSpeed("player") or 0
    t[#t + 1] = Ligne("Vitesse", fmt("%.2f yd/s", vitesse), fmt("%.0f%%", vitesse / 7 * 100))
    return t
end

local NOMS = {
    dmgdone = "Dégâts infligés", dmgtaken = "Dégâts subis",
    meleetaken = "Dégâts de mêlée subis", healdone = "Soins prodigués",
    healtaken = "Soins reçus", speed = "Vitesse (serveur)",
}
local ORDRE = { "dmgdone", "dmgtaken", "meleetaken", "healdone", "healtaken", "speed" }

local function BlocServeur()
    local t = { " ", "|cffffd100Multiplicateurs du cœur|r  |cff808080(100% = rien)|r" }
    for _, clef in ipairs(ORDRE) do
        local v = HUD.serveur[clef]
        if v then
            local couleur = (v == 100) and "|cffffffff" or (v > 100 and "|cff60ff60" or "|cffff8060")
            t[#t + 1] = Ligne(NOMS[clef], couleur .. v .. "%|r")
        end
    end
    if #HUD.lignes > 0 then
        t[#t + 1] = " "
        t[#t + 1] = "|cffffd100Lignes de cartes au coup|r  |cff808080(aucune aura : invisibles ailleurs)|r"
        for _, l in ipairs(HUD.lignes) do
            local texte, etat = l:match("^(.-) |(%u?%a+)$")
            texte, etat = texte or l, etat or ""
            local couleur = (etat == "ACTIF") and "|cff60ff60" or "|cff808080"
            t[#t + 1] = fmt("%s%s|r", couleur, texte)
        end
    end
    if not HUD.serveur.dmgdone then
        t[#t + 1] = "|cff808080en attente du serveur…|r"
    end
    return t
end

function HUD.Cadre()
    if HUD.frame then return HUD.frame end
    local f = CreateFrame("Frame", "StellarTarotHud", UIParent)
    f:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
    f:SetWidth(320)
    f:SetHeight(200)
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropColor(0, 0, 0, 0.75)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("TOPLEFT", 10, -10)
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    f.text:SetWidth(300)
    f.depuis = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.depuis = self.depuis + elapsed
        if self.depuis < 0.2 then return end
        self.depuis = 0
        local t = BlocClient()
        for _, l in ipairs(BlocServeur()) do t[#t + 1] = l end
        self.text:SetText(table.concat(t, "\n"))
        self:SetHeight(self.text:GetStringHeight() + 20)
    end)
    HUD.frame = f
    return f
end

function HUD.Montre(visible)
    local f = HUD.Cadre()
    if visible then f:Show() else f:Hide() end
end

function HUD.Recoit(message)
    if message == "on" then
        HUD.serveur, HUD.lignes = {}, {}
        HUD.Montre(true)
        return
    end
    if message == "off" then
        HUD.Montre(false)
        return
    end
    local serveur, lignes = {}, {}
    for champ in message:gmatch("[^\t]+") do
        local clef, valeur = champ:match("^(%w+)=(.+)$")
        if clef == "ligne" then
            lignes[#lignes + 1] = valeur
        elseif clef and valeur:find(":", 1, true) then
            -- Un champ composé : les cinq termes d'une statistique.
            local parts = {}
            for n in valeur:gmatch("[^:]+") do parts[#parts + 1] = tonumber(n) or 0 end
            serveur[clef] = parts
        elseif clef then
            serveur[clef] = tonumber(valeur) or valeur
        end
    end
    HUD.serveur, HUD.lignes = serveur, lignes
end

    local receiver = CreateFrame("Frame")
    receiver:RegisterEvent("CHAT_MSG_ADDON")
    receiver:RegisterEvent("MERCHANT_SHOW")
    receiver:RegisterEvent("MERCHANT_CLOSED")
    receiver:SetScript("OnEvent", function(_, event, prefix, message)
        if event == "MERCHANT_SHOW" then
            gains = {}
            return
        end
        if event == "CHAT_MSG_ADDON" then
            -- LA REPARATION OFFERTE : elle se dit sur-le-champ, sans rien
            -- attendre -- le forgeron a fini, il n'y a pas de fenêtre à fermer.
            -- LA BONNE AFFAIRE : le marchand a paye le double, et l'objet se
            -- nomme comme les autres, par son lien.
            -- LE BLOC DE MESURE : le serveur y pousse ce qu'il est seul a savoir.
            if prefix == "StellarTarotHud" and message then
                HUD.Recoit(message)
                return
            end
            if prefix == "StellarTarotKeenBuyer" and message then
                local id, objet = message:match("^(%d+):(%d+)$")
                local nom = id and Nom(tonumber(id))
                local _, lien = GetItemInfo(tonumber(objet or 0))
                if nom and lien then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        FR and ("[" .. nom .. "] Le marchand était très intéressé par " .. lien .. " !")
                            or ("[" .. nom .. "] The merchant was very interested in " .. lien .. "!"),
                        1.0, 0.82, 0.0)
                end
                return
            end
            -- L'EXEMPLAIRE OFFERT : l'objet se nomme par son LIEN, que le
            -- client colore et rend cliquable. Il vient d'entrer dans les sacs,
            -- donc le client le connaît déjà.
            if prefix == "StellarTarotExtraCopy" and message then
                local id, objet = message:match("^(%d+):(%d+)$")
                local nom = id and Nom(tonumber(id))
                local _, lien = GetItemInfo(tonumber(objet or 0))
                if nom and lien then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        FR and ("[" .. nom .. "] Vous venez de recevoir " .. lien .. " en plus, gratuitement !")
                            or ("[" .. nom .. "] You just got a little extra of " .. lien .. " for free!"),
                        1.0, 0.82, 0.0)
                end
                return
            end
            if prefix == "StellarTarotFreeRepair" and message then
                local nom = Nom(tonumber(message))
                if nom then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        FR and ("[" .. nom .. "] Le forgeron vous a offert vos réparations !")
                            or ("[" .. nom .. "] The blacksmith repaired your gear for free!"),
                        1.0, 0.82, 0.0)
                end
                return
            end
            if prefix ~= "StellarTarotProfit" or not message then return end
            local id, cuivre = message:match("^(%d+):(%d+)$")
            local nom = id and Nom(tonumber(id))
            if not nom then return end
            gains[nom] = (gains[nom] or 0) + tonumber(cuivre)
            return
        end
        -- MERCHANT_CLOSED : le moment que le joueur reconnaît.
        for nom, cuivre in pairs(gains) do
            local somme = Somme(cuivre)
            if somme then
                DEFAULT_CHAT_FRAME:AddMessage(
                    FR and ("[" .. nom .. "] Vous avez gagné " .. somme .. " de bénéfice.")
                        or ("[" .. nom .. "] You have gained " .. somme .. " in profit."),
                    1.0, 0.82, 0.0)
            end
        end
        gains = {}
    end)
end

-- Les nombres de l'infobulle que le module a releves, remplaces par les siens.
local function RaisePotionLines(tip, map)
    local n, changed = 2, false
    while true do
        local line = _G[tip:GetName() .. "TextLeft" .. n]
        local text = line and line:GetText()
        if not text then break end
        local raised = text:gsub("%d+", function(num) return map[num] end)
        if raised ~= text then
            line:SetText(raised)
            changed = true
        end
        n = n + 1
    end
    return changed
end

function STELLAR_TAROT_ON_BUFF_TOOLTIP(tip, unit, index, filter)
    -- L'IDENTIFIANT DU SORT est la onzieme valeur de `UnitAura` en 3.3.5 :
    -- tout se range par lui, et deux sorts homonymes cessent de se prendre
    -- l'un pour l'autre. Le nom demeure en repli.
    local name, _, _, count, _, _, _, _, _, _, spellId = UnitAura(unit, index, filter)
    if not name then return end
    local boost = (spellId and STELLAR_TAROT_POTION_BOOST[spellId])
                  or STELLAR_TAROT_POTION_BOOST[name]
    if boost then
        if RaisePotionLines(tip, boost) then tip:Show() end
        return
    end
    local part = PartDeSaignement(spellId, name)
    if part then
        local line = _G[tip:GetName() .. "TextLeft2"]
        if line then
            line:SetText(BleedText(part))
            line:SetTextColor(1, 1, 1)
            tip:Show()
        end
        return
    end
    -- Le client multiplie deja par les cumuls le chiffre d'un texte en $s :
    -- l'addon n'y touche pas, sous peine de compter deux fois.
    if S.cat and S.cat.scaled then
        if not SCALED_NAMES then
            SCALED_NAMES = {}
            for _, id in ipairs(S.cat.scaled) do
                SCALED_NAMES[id] = true
                local n = GetSpellInfo(id)
                if n then SCALED_NAMES[n] = true end
            end
        end
        if (spellId and SCALED_NAMES[spellId]) or SCALED_NAMES[name] then return end
    end
    if spellId ~= BANNER_SPELL and name ~= GetSpellInfo(BANNER_SPELL) then
        -- Les auras du module qui ne sont pas un niveau de carte -- le revers
        -- qu'une ligne pose a part, par exemple -- portent son nom : leur
        -- infobulle se multiplie par les cumuls comme celle d'un niveau.
        local id = SortDeNiveau(spellId, name)
            or ((name:match("^Tarot stellaire") or name:match("^Stellar Tarot")) and -1 or nil)
        if not id then return end
        local line = _G[tip:GetName() .. "TextLeft2"]
        if line and line:GetText() then
            line:SetText(ScaledBonus(line:GetText(), count))
            tip:Show()
        end
        return
    end
    local lines = STELLAR_TAROT_ACTIVE_LINES()
    if #lines == 0 then return end
    -- Wider than the buff's own text: the lines wrap less.
    tip:SetMinimumWidth(420)
    tip:AddLine(" ")
    for _, line in ipairs(lines) do
        tip:AddLine((line.indent and "    " or "") .. line.text, 0.2, 1, 0.2, true)
    end
    tip:Show()
end

if not STELLAR_TAROT_AURA_HOOKED_V2 then
    STELLAR_TAROT_AURA_HOOKED_V2 = true
    hooksecurefunc(GameTooltip, "SetUnitBuff", function(tip, unit, index, filter)
        STELLAR_TAROT_ON_BUFF_TOOLTIP(tip, unit, index, filter)
    end)
    hooksecurefunc(GameTooltip, "SetUnitAura", function(tip, unit, index, filter)
        STELLAR_TAROT_ON_BUFF_TOOLTIP(tip, unit, index, filter)
    end)
    hooksecurefunc(GameTooltip, "SetUnitDebuff", function(tip, unit, index, filter)
        STELLAR_TAROT_ON_BUFF_TOOLTIP(tip, unit, index, filter or "HARMFUL")
    end)
end

-- ---------------------------------------------------------------------------
-- "Already known" in the bag tooltip of a card or board the account has
-- studied -- red, as a recipe already learnt. Installed once per session: a
-- reload of this file must not stack a second line.
-- ---------------------------------------------------------------------------

if not STELLAR_TAROT_TOOLTIP_HOOKED then
    STELLAR_TAROT_TOOLTIP_HOOKED = true
    GameTooltip:HookScript("OnTooltipSetItem", function(tip)
        local _, link = tip:GetItem()
        local entry = link and tonumber(link:match("item:(%d+)"))
        if entry and STELLAR_TAROT_KNOWN[entry] then
            tip:AddLine(STELLAR_TAROT_ALREADY_KNOWN or "Already known", 1, 0.13, 0.13)
            tip:Show()
        end
    end)
end
STELLAR_TAROT_ALREADY_KNOWN = L.already_known

-- ---------------------------------------------------------------------------
-- The way in
-- ---------------------------------------------------------------------------

SLASH_STELLARTAROT1 = "/tarot"
SlashCmdList["STELLARTAROT"] = function()
    if S.ui and S.ui.frame:IsShown() then
        S.ui.frame:Hide()
    else
        AIO.Handle("StellarTarot", "Open")
    end
end

-- The binder is asked for as soon as this file runs, so that the tooltips
-- know what is already studied before the window is ever opened.
AIO.Handle("StellarTarot", "Hello")
