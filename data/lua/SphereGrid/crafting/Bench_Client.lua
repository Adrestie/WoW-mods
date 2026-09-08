--[[
    This file is part of mod-spheregrid.

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
    The workbench, client side (sent over by AIO).

    ONE window, THREE slots. Put in them whatever you like: it is the workbench
    that recognises the recipe, shows the result to expect, and lights the
    button.

      3 identical stones            -> the same stone, one quality above
      2 stones of the same quality  -> another stone, same quality
      3 runes, whichever they are   -> one rune at random

    THE RESULT OF A FUSE IS KNOWN IN ADVANCE, so its icon is the real one. The
    other two draw lots, and the icon stays honest all the same: every stone of
    a given quality shares one appearance, so showing "a stone of this quality"
    promises nothing false. Only the statistic is unknown, and the tooltip says
    so.

    It opens from the world object the module ships.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- server side: we stop here
end

local WorkbenchHandlers = AIO.AddHandlers("SphereGridWorkbench", {})

local max, min = math.max, math.min
local fmt = string.format
local FR = GetLocale() == "frFR"

local L = {
    title     = FR and "Établi du sphèrier" or "Sphere Grid Workbench",
    craft     = FR and "Fabriquer" or "Craft",
    empty      = FR and "Vide" or "Empty",
    choose   = FR and "Clic gauche : choisir un objet" or "Left-click: choose an item",
    remove   = FR and "Clic droit : retirer" or "Right-click: remove",
    list     = FR and "Choisir un objet" or "Choose an item",
    none_fits = FR and "Aucun objet dans vos sacs ne convient"
                    or "No item in your bags is suitable",
    help      = FR and "Trois pierres identiques, deux de même qualité, trois runes, ou un seul objet à broyer."
                    or "Three identical stones, two of the same quality, three runes, or a single item to grind.",
    r_fuse  = FR and "Fusion : la même pierre, une qualité au-dessus."
                    or "Merging: the same stone, one quality above.",
    r_reroll = FR and "Relance : une autre pierre, de même qualité."
                    or "Reroll: another stone, of the same quality.",
    r_reforge = FR and "Refonte : une rune tirée au hasard dans tout le catalogue."
                    or "Recasting: one rune drawn at random from the whole catalogue.",
    r_grind = FR and "Broyage : l'objet est détruit et rendu en Spherite."
                    or "Grinding: the item is destroyed and turned into Spherite.",
    p_grind = FR and "+%d Spherite" or "+%d Spherite",
    p_title   = FR and "Résultat" or "Result",
    p_chance  = FR and "Statistique tirée au hasard." or "Statistic drawn at random.",
    p_rune    = FR and "Rune tirée au hasard." or "Rune drawn at random.",
    stone    = FR and "Pierre" or "Stone",
    help_title = FR and "Les recettes de l'établi" or "Workbench recipes",
    help_1    = FR and "3 pierres identiques → la même pierre, une qualité au-dessus."
                    or "3 identical stones → the same stone, one quality above.",
    help_2    = FR and "2 pierres de même qualité → une autre pierre, même qualité."
                    or "2 stones of the same quality → another stone, same quality.",
    help_3    = FR and "3 runes, quelles qu'elles soient → une rune au hasard."
                    or "3 runes, any of them → one rune at random.",
    help_4    = FR and "1 seul objet → il est broyé et rendu en Spherite."
                    or "1 single item → it is ground down into Spherite.",
    help_note = FR and "Une pierre légendaire ne fusionne pas : il n'y a rien au-dessus."
                    or "A legendary stone cannot be merged: there is nothing above.",
    rune      = FR and "Rune" or "Rune",
}

local STAT_LABELS = {
    stamina = FR and "Endurance" or "Stamina",
    intellect = FR and "Intelligence" or "Intellect",
    spirit = FR and "Esprit" or "Spirit",
    agility = FR and "Dextérité" or "Agility",
    strength = FR and "Force" or "Strength",
    parry = FR and "Parade" or "Parry",
    block = FR and "Blocage" or "Block",
    dodge = FR and "Esquive" or "Dodge",
    haste = FR and "Hâte" or "Haste",
    crit = FR and "Critique" or "Critical strike",
    hit = FR and "Touché" or "Hit",
    spell_power = FR and "Puissance des sorts" or "Spell power",
    attack_power = FR and "Puissance d'attaque" or "Attack power",
    armor_penetration = FR and "Pénétration d'armure" or "Armor penetration",
    expertise = FR and "Expertise" or "Expertise",
    bonus_healing = FR and "Bonus des soins" or "Healing bonus",
}

-- EVERY DRAWING CONSTANT IN ONE TABLE. The client runs Lua 5.1, which allows
-- a function sixty upvalues, and each bare local eats one of them.
local EC = {
    W = 344, H = 196,
    SLOT = 42, RESULT = 46,
    BAGS = { 0, 1, 2, 3, 4 },
    PICK_W = 250, PICK_ROWS = 9, PICK_ROW_H = 22, PICK_ICON = 18,
    PICK_MIN = 190, PICK_MAX = 460, PICK_MARGIN = 46,
    ARROW = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
    UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark",
    -- A texture the client already owns: nothing to package.
    HELP = "Interface\\Common\\help-i",
    BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",
    EMPTY_EDGE = { 0.35, 0.35, 0.35 },
    -- Opaque across the whole window: nothing may be read through it.
    BACKGROUND = { 0.06, 0.055, 0.05 },
    -- A rune, and no more than that: reforging can return either kind, so no
    -- particular icon would be honest.
    ANY_RUNE = "Interface\\Icons\\INV_Misc_Rune_06",
}

local CAT = { stones = {}, runes = {}, statRunes = {} }
local UI = nil

-- ---------------------------------------------------------------------------
-- Bags and catalogue
-- ---------------------------------------------------------------------------

local function WalkBags(filter, action)
    for _, bag in ipairs(EC.BAGS) do
        for slotIndex = 1, (GetContainerNumSlots(bag) or 0) do
            local entry = GetContainerItemID and GetContainerItemID(bag, slotIndex)
            if not entry then
                local link = GetContainerItemLink(bag, slotIndex)
                entry = link and tonumber(link:match("item:(%d+)"))
            end
            if entry and filter(entry) then
                local _, nb = GetContainerItemInfo(bag, slotIndex)
                action(entry, nb or 1)
            end
        end
    end
end

local function CountInBags(entry)
    local total = 0
    WalkBags(function(e) return e == entry end,
                  function(_, nb) total = total + nb end)
    return total
end

local function IsStone(entry) return entry and CAT.stones[entry] end
local function IsRune(entry)
    return entry and (CAT.runes[entry] or CAT.statRunes[entry])
end
local function OfSphereGrid(entry) return IsStone(entry) or IsRune(entry) end

-- What grinding this item would pay. A rune has a single price; a stone is
-- priced by the quality item_template gives it. Zero if the item cannot be
-- ground, or if the recipe is switched off.
local function GrindAmount(entry)
    local scale = CAT and CAT.grind
    if not scale or not entry then return 0 end
    if IsRune(entry) then
        return scale.rune or 0
    end
    local stone = CAT.stones[entry]
    if stone and scale.stone then
        return scale.stone[stone.quality] or 0
    end
    return 0
end

-- WHAT A SLOT CAN STILL TAKE. The moment one component is placed it narrows
-- the rest: a rare stone only calls for rare stones -- fusing wants three of
-- the same, rerolling two of the same quality, so both demand one quality --
-- and a rune only calls for runes.
--
-- The slot being filled does not constrain ITSELF: reopening its list must
-- allow a change of mind, and a fresh start if it is the only one placed.
local function Compatible(entry, except)
    local amount, rune = nil, false
    for i = 1, 3 do
        local place = (i ~= except) and UI.picker[i] or nil
        if place then
            local p = IsStone(place)
            if p then amount = p.amount else rune = true end
        end
    end
    if amount then
        local p = IsStone(entry)
        return p ~= nil and p.amount == amount
    end
    if rune then
        return IsRune(entry) ~= nil
    end
    return OfSphereGrid(entry) ~= nil
end

-- How many of this entry are left once the slots have taken their share --
-- without which the last one in the bag would be offered twice.
local function Available(entry, except)
    local left = CountInBags(entry)
    for i = 1, 3 do
        if i ~= except and UI.picker[i] == entry then left = left - 1 end
    end
    return left
end


local function ItemName(entry)
    local name = GetItemInfo(entry)
    if name then return name end
    local p = CAT.stones[entry]
    if p then return fmt("%s (%s +%d)", L.stone, STAT_LABELS[p.stat] or "?", p.amount or 0) end
    local r = CAT.statRunes[entry]
    if r then return fmt("%s (%s +%d%%)", L.rune, STAT_LABELS[r.stat] or "?", r.pct or 0) end
    r = CAT.runes[entry]
    if r then return fmt("%s (%s)", L.rune, GetSpellInfo(r.spell or 0) or "?") end
    return tostring(entry)
end

-- The quality comes from the catalogue, which the server reads from
-- item_template. `GetItemInfo` is only a fallback: an item the client has never
-- seen is not known to it yet -- which is exactly the case for the result of a
-- fuse.
local function ItemQuality(entry)
    local d = entry and (CAT.stones[entry] or CAT.runes[entry] or CAT.statRunes[entry])
    if d and d.quality then return d.quality end
    local _, _, q = GetItemInfo(entry or 0)
    return q
end

-- A quality's colour is read from the client's own table. Copying it out by
-- hand would make it lie the day the game changes one.
local function TintFrame(frame, quality)
    local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c then
        frame:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    else
        frame:SetBackdropBorderColor(EC.EMPTY_EDGE[1], EC.EMPTY_EDGE[2], EC.EMPTY_EDGE[3], 1)
    end
end

-- Every rune shares one quality today, and while that holds, reforging can
-- announce the colour of what it will return. Should they ever differ, nothing
-- is promised any more.
local function RuneQuality()
    local view = nil
    for _, r in pairs(CAT.runes) do
        if view and r.quality ~= view then return nil end
        view = r.quality
    end
    for _, r in pairs(CAT.statRunes) do
        if view and r.quality ~= view then return nil end
        view = r.quality
    end
    return view
end

local function ItemIcon(entry)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(entry)
    return texture or EC.UNKNOWN
end

-- ---------------------------------------------------------------------------
-- The recipe follows from what has been placed
-- ---------------------------------------------------------------------------

-- The stone of the same statistic whose amount is the smallest one above.
-- THAT IS HOW THE MODULE READS "the quality above", without ever touching an
-- identifier. Every stone of a given quality carries the same amount, so the
-- comparison of qualities works the same way.
local function StoneAbove(p)
    local best, amount = nil, nil
    for entry, other in pairs(CAT.stones) do
        if other.stat == p.stat and other.amount > p.amount
           and (not amount or other.amount < amount) then
            best, amount = entry, other.amount
        end
    end
    return best
end

local function StoneOfQuality(amount)
    for entry, other in pairs(CAT.stones) do
        if other.amount == amount then return entry end
    end
end

-- Returns: the recipe key, the entries to send, the result's icon, its label,
-- and the line of explanation. NONE OF IT BINDS THE MODULE, which checks
-- everything again -- this only spares the player a gesture bound to be
-- refused.
local function Detect()
    local placed = {}
    for i = 1, 3 do
        if UI.picker[i] then placed[#placed + 1] = UI.picker[i] end
    end

    if #placed == 3 and IsStone(placed[1])
       and placed[1] == placed[2] and placed[2] == placed[3] then
        local result = StoneAbove(CAT.stones[placed[1]])
        if result then
            return "fuse", placed, ItemIcon(result), ItemName(result),
                   L.r_fuse, ItemQuality(result)
        end
        return nil, placed, nil, nil, L.help
    end

    if #placed == 2 then
        local a, b = IsStone(placed[1]), IsStone(placed[2])
        if a and b and a.amount == b.amount then
            local witness = StoneOfQuality(a.amount)
            return "reroll", placed, witness and ItemIcon(witness) or EC.UNKNOWN,
                   L.p_chance, L.r_reroll, ItemQuality(witness)
        end
    end

    if #placed == 3 and IsRune(placed[1]) and IsRune(placed[2]) and IsRune(placed[3]) then
        return "reforge", placed, EC.ANY_RUNE, L.p_rune, L.r_reforge,
               RuneQuality()
    end

    -- GRINDING takes ONE item, stone or rune, destroys it and returns Spherite.
    -- The amount comes with the catalogue; the module reads it again on its own
    -- side, and this is only a display.
    if #placed == 1 then
        local amount = GrindAmount(placed[1])
        if amount > 0 then
            return "grind", placed, ItemIcon(placed[1]), fmt(L.p_grind, amount),
                   L.r_grind, ItemQuality(placed[1])
        end
    end

    return nil, placed, nil, nil, L.help
end

-- ---------------------------------------------------------------------------
-- The picker
-- ---------------------------------------------------------------------------

local function ClosePicker()
    if UI and UI.pick then UI.pick:Hide() end
end

local function FillPicker()
    local frame = UI.pick
    local seen, list = {}, {}
    WalkBags(function(e) return Compatible(e, frame.cell) end, function(e)
        if not seen[e] and Available(e, frame.cell) > 0 then
            seen[e] = true
            list[#list + 1] = e
        end
    end)
    table.sort(list)
    frame.list = list

    -- The width follows the longest text, measured over EVERY entry and not only
    -- the visible ones: an entry further down the scroll would otherwise be cut
    -- off.
    local plus = 0
    for _, entry in ipairs(list) do
        frame.meter:SetText(fmt("%s  x%d", ItemName(entry), Available(entry, frame.cell)))
        plus = max(plus, frame.meter:GetStringWidth() or 0)
    end
    frame.meter:SetText(L.none_fits)
    plus = max(plus, frame.meter:GetStringWidth() or 0)
    frame:SetWidth(min(EC.PICK_MAX, max(EC.PICK_MIN, plus + EC.PICK_MARGIN)))

    local maxi = max(0, #list - EC.PICK_ROWS)
    if frame.offset > maxi then frame.offset = maxi end

    for i = 1, EC.PICK_ROWS do
        local line = frame.lines[i]
        local entry = list[i + frame.offset]
        if entry then
            line.iconFile:SetTexture(ItemIcon(entry))
            line.name:SetText(fmt("%s  x%d", ItemName(entry), Available(entry, frame.cell)))
            line.entry = entry
            line:Show()
        else
            line:Hide()
        end
    end
    frame.empty:SetText(#list == 0 and L.none_fits or "")
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local function Update()
    for i = 1, 3 do
        local cell, entry = UI.cells[i], UI.picker[i]
        if entry then
            cell.iconFile:SetTexture(ItemIcon(entry))
            cell.iconFile:Show()
        else
            cell.iconFile:Hide()
        end
        TintFrame(cell, entry and ItemQuality(entry) or nil)
    end

    local recipe, _, iconFile, label, line, quality = Detect()
    UI.recipe = recipe
    UI.resultName = label
    UI.explanation:SetText(line)

    if recipe then
        UI.result.iconFile:SetTexture(iconFile)
        UI.result.iconFile:Show()
        UI.result:Show()
        UI.arrow:SetAlpha(1)
        UI.button:Enable()
        TintFrame(UI.result, quality)
    else
        UI.result.iconFile:Hide()
        UI.arrow:SetAlpha(0.3)
        UI.button:Disable()
        TintFrame(UI.result, nil)
    end
end

local function Craft()
    local recipe, placed = Detect()
    if not recipe then return end
    if recipe == "fuse" then
        AIO.Handle("SphereGridWorkbench", "Fuse", placed[1])
    elseif recipe == "reroll" then
        AIO.Handle("SphereGridWorkbench", "Reroll", placed[1], placed[2])
    elseif recipe == "grind" then
        AIO.Handle("SphereGridWorkbench", "Grind", placed[1])
    else
        AIO.Handle("SphereGridWorkbench", "Reforge", placed[1], placed[2], placed[3])
    end
    -- The bags have changed: start from empty slots and let the module answer.
    -- The refresh follows the bag's own event.
    for i = 1, 3 do UI.picker[i] = nil end
    ClosePicker()
    Update()
end

local function Build()
    local f = CreateFrame("Frame", "SphereGridWorkbenchFrame", UIParent)
    f:SetWidth(EC.W)
    f:SetHeight(EC.H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- The whole window, edge to edge: the dialog outline draws over it, its
    -- border living in a layer above.
    local background = f:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture(EC.BACKGROUND[1], EC.BACKGROUND[2], EC.BACKGROUND[3], 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    title:SetPoint("TOP", 0, -16)
    title:SetText(L.title)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() ClosePicker() f:Hide() end)

    -- Half faded until the pointer meets it.
    -- au repos, franc au hover.
    local help = CreateFrame("Button", nil, f)
    help:SetWidth(24)
    help:SetHeight(24)
    help:SetPoint("TOPLEFT", 12, -12)
    help:SetAlpha(0.5)
    help:SetNormalTexture(EC.HELP)
    help:SetHighlightTexture(EC.HELP, "ADD")
    help:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.help_title, 1, 0.82, 0)
        GameTooltip:AddLine(L.help_1, 1, 1, 1, true)
        GameTooltip:AddLine(L.help_2, 1, 1, 1, true)
        GameTooltip:AddLine(L.help_3, 1, 1, 1, true)
        GameTooltip:AddLine(L.help_4, 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.help_note, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    help:SetScript("OnLeave", function(self)
        self:SetAlpha(0.5)
        GameTooltip:Hide()
    end)

    UI = { frame = f, cells = {}, picker = {} }

    -- Three slots, then the arrow, then the result.
    for i = 1, 3 do
        local cell = CreateFrame("Button", nil, f)
        cell:SetWidth(EC.SLOT)
        cell:SetHeight(EC.SLOT)
        cell:SetPoint("TOPLEFT", 26 + (i - 1) * (EC.SLOT + 10), -74)
        cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- The frame carries the quality colour, so the icon is inset by three
        -- points: otherwise it would cover it.
        cell:SetBackdrop({ edgeFile = EC.BORDER, edgeSize = 12 })
        cell:SetBackdropBorderColor(EC.EMPTY_EDGE[1], EC.EMPTY_EDGE[2], EC.EMPTY_EDGE[3], 1)

        local background = cell:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("TOPLEFT", 3, -3)
        background:SetPoint("BOTTOMRIGHT", -3, 3)
        background:SetTexture(0, 0, 0, 0.5)

        cell.iconFile = cell:CreateTexture(nil, "ARTWORK")
        cell.iconFile:SetPoint("TOPLEFT", 3, -3)
        cell.iconFile:SetPoint("BOTTOMRIGHT", -3, 3)
        cell.iconFile:Hide()

        cell:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                UI.picker[i] = nil
                ClosePicker()
                Update()
                return
            end
            local frame = UI.pick
            frame.cell, frame.offset = i, 0
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
            FillPicker()
            frame:Show()
        end)
        cell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(UI.picker[i] and ItemName(UI.picker[i]) or L.empty, 1, 1, 1)
            GameTooltip:AddLine(UI.picker[i] and L.remove or L.choose, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        UI.cells[i] = cell
    end

    local arrow = f:CreateTexture(nil, "ARTWORK")
    arrow:SetWidth(28)
    arrow:SetHeight(28)
    arrow:SetPoint("TOPLEFT", 26 + 3 * (EC.SLOT + 10) + 4, -81)
    arrow:SetTexture(EC.ARROW)
    arrow:SetAlpha(0.3)
    UI.arrow = arrow

    local result = CreateFrame("Button", nil, f)
    result:SetWidth(EC.RESULT)
    result:SetHeight(EC.RESULT)
    result:SetPoint("TOPLEFT", 26 + 3 * (EC.SLOT + 10) + 40, -72)
    result:SetBackdrop({ edgeFile = EC.BORDER, edgeSize = 12 })
    result:SetBackdropBorderColor(EC.EMPTY_EDGE[1], EC.EMPTY_EDGE[2], EC.EMPTY_EDGE[3], 1)
    local rBackground = result:CreateTexture(nil, "BACKGROUND")
    rBackground:SetPoint("TOPLEFT", 3, -3)
    rBackground:SetPoint("BOTTOMRIGHT", -3, 3)
    rBackground:SetTexture(0, 0, 0, 0.5)
    result.iconFile = result:CreateTexture(nil, "ARTWORK")
    result.iconFile:SetPoint("TOPLEFT", 3, -3)
    result.iconFile:SetPoint("BOTTOMRIGHT", -3, 3)
    result.iconFile:Hide()
    result:SetScript("OnEnter", function(self)
        if not UI.recipe then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.p_title, 1, 0.82, 0)
        GameTooltip:AddLine(UI.resultName or "", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    result:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI.result = result

    -- ABOVE the slots: you read what you are about to craft before you place it.
    UI.explanation = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.explanation:SetPoint("TOPLEFT", 22, -38)
    UI.explanation:SetWidth(EC.W - 44)
    UI.explanation:SetJustifyH("LEFT")
    UI.explanation:SetText(L.help)


    local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    button:SetWidth(130)
    button:SetHeight(26)
    button:SetPoint("BOTTOM", 0, 22)
    button:SetText(L.craft)
    button:SetScript("OnClick", Craft)
    button:Disable()
    UI.button = button

    -- The picker, shared by all three slots.
    local frame = CreateFrame("Frame", "SphereGridWorkbenchPicker", f)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetWidth(EC.PICK_W)
    frame:SetHeight(EC.PICK_ROWS * EC.PICK_ROW_H + 34)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    -- Opaque: without a full background, the grid and the scenery read through
    -- the list and made it unreadable.
    frame:SetBackdropColor(0.06, 0.05, 0.04, 1)
    local full = frame:CreateTexture(nil, "BACKGROUND")
    full:SetPoint("TOPLEFT", 6, -6)
    full:SetPoint("BOTTOMRIGHT", -6, 6)
    full:SetTexture(0.05, 0.04, 0.035, 1)

    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        local maxi = max(0, #(self.list or {}) - EC.PICK_ROWS)
        self.offset = min(maxi, max(0, (self.offset or 0) - delta))
        FillPicker()
    end)
    frame:Hide()

    local ct = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    ct:SetPoint("TOPLEFT", 12, -10)
    ct:SetText(L.list)

    -- In red: this is a refusal, not a hint.
    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    frame.empty:SetPoint("TOPLEFT", 12, -26)
    frame.empty:SetTextColor(1, 0.3, 0.3)

    -- The measure: a string in the same font, never shown, against which every
    -- entry is measured before the width is decided.
    frame.meter = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    frame.meter:Hide()

    frame.lines = {}
    for i = 1, EC.PICK_ROWS do
        local line = CreateFrame("Button", nil, frame)
        line:SetHeight(EC.PICK_ROW_H)
        line:SetPoint("TOPLEFT", 10, -26 - (i - 1) * EC.PICK_ROW_H)
        line:SetPoint("TOPRIGHT", -10, -26 - (i - 1) * EC.PICK_ROW_H)
        line:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

        line.iconFile = line:CreateTexture(nil, "ARTWORK")
        line.iconFile:SetWidth(EC.PICK_ICON)
        line.iconFile:SetHeight(EC.PICK_ICON)
        line.iconFile:SetPoint("LEFT")

        line.name = line:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        line.name:SetPoint("LEFT", EC.PICK_ICON + 6, 0)
        line.name:SetJustifyH("LEFT")

        line:SetScript("OnClick", function(self)
            if not self.entry then return end
            UI.picker[frame.cell] = self.entry
            ClosePicker()
            Update()
        end)
        frame.lines[i] = line
    end
    frame.offset = 0
    UI.pick = frame
    -- Escape closes the list first and the window second: the client hides one
    -- per press, and the most recently registered goes first.
    tinsert(UISpecialFrames, "SphereGridWorkbenchPicker")

    -- The bags move with every craft, so the window rights itself rather than
    -- waiting for a click.
    local idle = CreateFrame("Frame", nil, f)
    idle:RegisterEvent("BAG_UPDATE")
    idle:SetScript("OnEvent", function()
        if f:IsShown() then
            Update()
            if frame:IsShown() then FillPicker() end
        end
    end)

    tinsert(UISpecialFrames, "SphereGridWorkbenchFrame")
    return f
end

-- ---------------------------------------------------------------------------
-- Handlers
-- ---------------------------------------------------------------------------

function WorkbenchHandlers.Catalogue(_, cat)
    CAT.stones   = (cat and cat.stones) or {}
    CAT.runes     = (cat and cat.runes) or {}
    CAT.statRunes = (cat and cat.statRunes) or {}
end

function WorkbenchHandlers.Show(_, cat)
    WorkbenchHandlers.Catalogue(nil, cat)
    local f = (UI and UI.frame) or Build()
    for i = 1, 3 do UI.picker[i] = nil end
    Update()
    f:Show()
end
