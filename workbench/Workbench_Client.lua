--[[
    The workbench, a component shared by the modules of this repository.

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
    The workbench, client side (shipped by AIO). The window the sphere grid's
    workbench had, now shared: three slots, an arrow, the result, a button,
    and a list under a clicked slot of what the bags hold that the bench
    would take. The line above the slots says what is about to be crafted,
    the "i" in the corner lists the recipes.

    Nothing is decided here: every gesture goes to the server, which answers
    with the state of the bench -- what is placed, which craft it is locked
    to, which recipe accepts it and what that recipe would give -- and this
    window draws that.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- server side: we stop here
end

local Handlers = AIO.AddHandlers("Workbench", {})

local max, min, floor = math.max, math.min, math.floor
local fmt = string.format
local FR = GetLocale() == "frFR"

local L = {
    title      = FR and "Établi" or "Workbench",
    craft      = FR and "Fabriquer" or "Craft",
    empty      = FR and "Vide" or "Empty",
    all        = FR and "Tout" or "All",
    choose     = FR and "Clic gauche : choisir un objet" or "Left-click: choose an item",
    remove     = FR and "Clic droit : retirer" or "Right-click: remove",
    list       = FR and "Choisir un objet" or "Choose an item",
    none_fits  = FR and "Aucun objet dans vos sacs ne convient"
                    or "No item in your bags is suitable",
    help       = FR and "Posez des objets : la recette qu'ils composent apparaîtra."
                    or "Place items: the recipe they make will appear.",
    p_title    = FR and "Résultat" or "Result",
    help_title = FR and "Les recettes de l'établi" or "Workbench recipes",
    help_lock  = FR and "Ce qui est posé fixe l'artisanat : videz l'établi pour en changer."
                    or "What is placed sets the craft: clear the bench to change it.",
}

-- EVERY DRAWING CONSTANT IN ONE TABLE. The client runs Lua 5.1, which allows
-- a function sixty upvalues, and each bare local eats one of them.
local EC = {
    W = 344, H = 196,
    SLOT = 42, RESULT = 46,
    BAGS = { 0, 1, 2, 3, 4 },
    PICK_W = 250, PICK_ROWS = 9, PICK_ROW_H = 22, PICK_ICON = 18,
    PICK_MIN = 190, PICK_MARGIN = 56, PICK_SLIDER = 16,
    TAB_W = 88, TAB_H = 22, TAB_GAP = 4,
    KNOB = "Interface\\Buttons\\UI-ScrollBar-Knob",
    ARROW = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
    UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark",
    HELP = "Interface\\Common\\help-i",
    BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",
    EMPTY_EDGE = { 0.35, 0.35, 0.35 },
    BACKGROUND = { 0.06, 0.055, 0.05 },
}

local S = { state = nil, eligible = nil, kinds = nil }
local UI = nil

-- ---------------------------------------------------------------------------
-- Items the client has never seen have neither name nor icon; they are asked
-- for, and the window redraws itself when the answers arrive.
-- ---------------------------------------------------------------------------

local WAITING = {}
local Update, FillPicker, Prime

local function ItemName(entry)
    local name = GetItemInfo(entry)
    if not name then Prime(entry) end
    return name or fmt("#%d", entry)
end

local function ItemQuality(entry)
    local _, _, q = GetItemInfo(entry or 0)
    return q
end

local function ItemIcon(entry)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(entry)
    if not texture then Prime(entry) end
    return texture or EC.UNKNOWN
end

local function TintFrame(frame, quality)
    local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c then
        frame:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    else
        frame:SetBackdropBorderColor(EC.EMPTY_EDGE[1], EC.EMPTY_EDGE[2], EC.EMPTY_EDGE[3], 1)
    end
end

function Prime(entry)
    if not UI then return end
    if not entry or GetItemInfo(entry) or WAITING[entry] then return end
    WAITING[entry] = true
    if not UI.probe then
        UI.probe = CreateFrame("GameTooltip", "WorkbenchProbe", nil, "GameTooltipTemplate")
        UI.waiter = CreateFrame("Frame")
        UI.waiter.elapsed = 0
        UI.waiter:SetScript("OnUpdate", function(self, delta)
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
            if arrived and UI.frame and UI.frame:IsShown() then
                Update()
                if UI.pick and UI.pick:IsShown() then FillPicker() end
            end
            if not left then self:Hide() end
        end)
    end
    UI.probe:SetOwner(UIParent, "ANCHOR_NONE")
    UI.probe:SetHyperlink("item:" .. entry)
    UI.probe:Hide()
    UI.waiter.elapsed = 0
    UI.waiter:Show()
end

-- ---------------------------------------------------------------------------
-- Bags
-- ---------------------------------------------------------------------------

local function WalkBags(action)
    for _, bag in ipairs(EC.BAGS) do
        for slotIndex = 1, (GetContainerNumSlots(bag) or 0) do
            local entry = GetContainerItemID and GetContainerItemID(bag, slotIndex)
            if not entry then
                local link = GetContainerItemLink(bag, slotIndex)
                entry = link and tonumber(link:match("item:(%d+)"))
            end
            if entry then
                local _, nb = GetContainerItemInfo(bag, slotIndex)
                action(entry, nb or 1)
            end
        end
    end
end

local function BagEntries()
    local seen, out = {}, {}
    WalkBags(function(e)
        if not seen[e] then
            seen[e] = true
            out[#out + 1] = e
        end
    end)
    return out
end

local function CountInBags(entry)
    local total = 0
    WalkBags(function(e, nb) if e == entry then total = total + nb end end)
    return total
end

-- What is left of an entry once the bench has its share, the slot being
-- refilled not counted.
local function Available(entry, except)
    local placed = 0
    for i, e in pairs((S.state and S.state.slots) or {}) do
        if e == entry and i ~= except then placed = placed + 1 end
    end
    return CountInBags(entry) - placed
end

-- ---------------------------------------------------------------------------
-- The gestures: all of them go to the server
-- ---------------------------------------------------------------------------

local function ClosePicker()
    if UI and UI.pick then UI.pick:Hide() end
end

local function Put(slot, entry)
    ClosePicker()
    AIO.Handle("Workbench", "Put", slot, entry)
end

local function TakeFromCursor(cell)
    if not CursorHasItem() then return end
    local kind, entry, link = GetCursorInfo()
    if kind ~= "item" then return end
    entry = tonumber(entry) or (link and tonumber(tostring(link):match("item:(%d+)")))
    if not entry then return end
    ClearCursor()
    Put(cell, entry)
end

local function Craft()
    local recipe = S.recipe
    if not recipe then return end
    ClosePicker()
    AIO.Handle("Workbench", "Run", recipe.key)
end

-- ---------------------------------------------------------------------------
-- The picker
-- ---------------------------------------------------------------------------

-- The tabs, standing on the list's left edge: "All", then one per type
-- present among the eligible items, in the providers' order.
local function LayoutTabs(frame, present)
    local tabs = { { key = nil, name = L.all } }
    for _, k in ipairs(S.kinds or {}) do
        if present[k[1]] then tabs[#tabs + 1] = { key = k[1], name = k[2] } end
    end
    local found = frame.tab == nil
    for _, t in ipairs(tabs) do
        if t.key == frame.tab then found = true end
    end
    if not found then frame.tab = nil end
    for _, b in ipairs(frame.tabs) do b:Hide() end
    if #tabs <= 1 then frame.tab = nil return false end
    for i, t in ipairs(tabs) do
        local b = frame.tabs[i]
        if not b then
            b = CreateFrame("Button", nil, frame)
            b:SetWidth(EC.TAB_W)
            b:SetHeight(EC.TAB_H)
            b:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.label:SetPoint("CENTER")
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b:SetScript("OnClick", function(self)
                frame.tab, frame.offset = self.key, 0
                FillPicker()
            end)
            frame.tabs[i] = b
        end
        b.key = t.key
        b.label:SetText(t.name)
        if t.key == frame.tab then
            b:SetBackdropColor(0.25, 0.2, 0.05, 1)
            b:SetBackdropBorderColor(1, 0.82, 0)
            b.label:SetTextColor(1, 0.82, 0)
        else
            b:SetBackdropColor(0, 0, 0, 0.8)
            b:SetBackdropBorderColor(0.5, 0.5, 0.5)
            b.label:SetTextColor(0.8, 0.8, 0.8)
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 10, -26 - (i - 1) * (EC.TAB_H + EC.TAB_GAP))
        b:Show()
    end
    return true
end

function FillPicker()
    local frame = UI.pick
    -- The order of the types, as the providers declared them.
    local rank = {}
    for i, k in ipairs(S.kinds or {}) do rank[k[1]] = i end
    local present, candidates = {}, {}
    for _, pair in ipairs(S.eligible or {}) do
        local entry, kind = pair[1], pair[2]
        if Available(entry, frame.cell) > 0 then
            present[kind] = true
            candidates[#candidates + 1] = { entry = entry, kind = kind }
        end
    end
    -- The tabs stand in a column inside the window, on its left; the rows
    -- start after them.
    local left = LayoutTabs(frame, present) and (10 + EC.TAB_W + 8) or 10
    frame.empty:SetPoint("TOPLEFT", left + 2, -26)
    local list, key = {}, {}
    for _, c in ipairs(candidates) do
        if frame.tab == nil or c.kind == frame.tab then
            list[#list + 1] = c.entry
            key[c.entry] = { rank[c.kind] or 999, ItemQuality(c.entry) or 0, ItemName(c.entry) }
        end
    end
    -- By type, then quality, then name.
    table.sort(list, function(a, b)
        local ka, kb = key[a], key[b]
        if ka[1] ~= kb[1] then return ka[1] < kb[1] end
        if ka[2] ~= kb[2] then return ka[2] < kb[2] end
        if ka[3] ~= kb[3] then return ka[3] < kb[3] end
        return a < b
    end)
    frame.list = list

    local plus = 0
    for _, entry in ipairs(list) do
        frame.meter:SetText(fmt("%s  x%d", ItemName(entry), Available(entry, frame.cell)))
        plus = max(plus, frame.meter:GetStringWidth() or 0)
    end
    frame.meter:SetText(L.none_fits)
    plus = max(plus, frame.meter:GetStringWidth() or 0)

    local maxi = max(0, #list - EC.PICK_ROWS)
    if frame.offset > maxi then frame.offset = maxi end
    local scrolls = maxi > 0
    -- As wide as the longest line needs, never less: nothing is cut.
    frame:SetWidth(max(EC.PICK_MIN, plus + EC.PICK_MARGIN) + (scrolls and EC.PICK_SLIDER or 0) + (left - 10))
    for i = 1, EC.PICK_ROWS do
        frame.lines[i]:SetPoint("TOPLEFT", left, -26 - (i - 1) * EC.PICK_ROW_H)
        frame.lines[i]:SetPoint("TOPRIGHT", scrolls and -(10 + EC.PICK_SLIDER) or -10,
                                -26 - (i - 1) * EC.PICK_ROW_H)
    end
    if scrolls then
        frame.slider.settling = true
        frame.slider:SetMinMaxValues(0, maxi)
        frame.slider:SetValue(frame.offset)
        frame.slider.settling = nil
        frame.slider:Show()
    else
        frame.slider:Hide()
    end

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

function Update()
    local state = S.state or { slots = {}, recipes = {}, maxSlots = 3 }
    local slots = state.slots or {}
    for i = 1, 3 do
        local cell, entry = UI.cells[i], slots[i]
        if i <= (state.maxSlots or 3) then cell:Show() else cell:Hide() end
        if entry then
            cell.iconFile:SetTexture(ItemIcon(entry))
            cell.iconFile:Show()
        else
            cell.iconFile:Hide()
        end
        cell.entry = entry
        TintFrame(cell, entry and ItemQuality(entry) or nil)
    end

    -- The recipe: the first one the server says accepts what is placed.
    local recipe = nil
    for _, r in ipairs(state.recipes or {}) do
        if r.ok and not recipe then recipe = r end
    end
    S.recipe = recipe
    UI.explanation:SetText(recipe and recipe.name or L.help)

    if recipe then
        local preview = recipe.preview or {}
        local known = preview.entry and GetItemInfo(preview.entry)
        if preview.entry and not known then Prime(preview.entry) end
        -- The icon: the one given, or the item's once the client knows it;
        -- nothing in between, rather than a number or a question mark.
        local icon = preview.icon or (known and ItemIcon(preview.entry)) or nil
        if icon then
            UI.result.iconFile:SetTexture(icon)
            UI.result.iconFile:Show()
        else
            UI.result.iconFile:Hide()
        end
        UI.resultName = preview.name or (known and ItemName(preview.entry)) or nil
        UI.resultText = preview.text
        if not UI.resultName and not UI.resultText then UI.resultName = recipe.name end
        UI.arrow:SetAlpha(1)
        UI.button:Enable()
        TintFrame(UI.result, preview.quality or (known and ItemQuality(preview.entry)) or nil)
    else
        UI.result.iconFile:Hide()
        UI.resultName, UI.resultText = nil, nil
        UI.arrow:SetAlpha(0.3)
        UI.button:Disable()
        TintFrame(UI.result, nil)
    end
end

local function Build()
    local f = CreateFrame("Frame", "WorkbenchFrame", UIParent)
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

    -- INSIDE the outline, not under it.
    local background = f:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", 11, -12)
    background:SetPoint("BOTTOMRIGHT", -12, 11)
    background:SetTexture(EC.BACKGROUND[1], EC.BACKGROUND[2], EC.BACKGROUND[3], 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    title:SetPoint("TOP", 0, -16)
    title:SetText(L.title)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() ClosePicker() f:Hide() end)

    -- The recipes the bench knows: those of the craft it is locked to, or of
    -- every craft while it is empty. Half faded until the pointer meets it.
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
        for _, line in ipairs((S.state and S.state.help) or {}) do
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.help_lock, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    help:SetScript("OnLeave", function(self)
        self:SetAlpha(0.5)
        GameTooltip:Hide()
    end)

    UI = { frame = f, cells = {} }

    -- Three slots, then the arrow, then the result.
    for i = 1, 3 do
        local cell = CreateFrame("Button", nil, f)
        cell:SetWidth(EC.SLOT)
        cell:SetHeight(EC.SLOT)
        cell:SetPoint("TOPLEFT", 26 + (i - 1) * (EC.SLOT + 10), -74)
        cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        cell:SetBackdrop({ edgeFile = EC.BORDER, edgeSize = 12 })
        cell:SetBackdropBorderColor(EC.EMPTY_EDGE[1], EC.EMPTY_EDGE[2], EC.EMPTY_EDGE[3], 1)

        local cellBackground = cell:CreateTexture(nil, "BACKGROUND")
        cellBackground:SetPoint("TOPLEFT", 3, -3)
        cellBackground:SetPoint("BOTTOMRIGHT", -3, 3)
        cellBackground:SetTexture(0, 0, 0, 0.5)

        cell.iconFile = cell:CreateTexture(nil, "ARTWORK")
        cell.iconFile:SetPoint("TOPLEFT", 3, -3)
        cell.iconFile:SetPoint("BOTTOMRIGHT", -3, 3)
        cell.iconFile:Hide()

        cell:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                ClosePicker()
                AIO.Handle("Workbench", "Take", i)
                return
            end
            -- A held item is an answer, not a request for the list.
            if CursorHasItem() then
                TakeFromCursor(i)
                return
            end
            -- The list: the server says which of the bags' items the bench
            -- would take; the list opens when it answers.
            UI.pick.cell, UI.pick.offset = i, 0
            UI.pick:ClearAllPoints()
            UI.pick:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
            AIO.Handle("Workbench", "Owners", BagEntries(), i)
        end)
        cell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.entry and ItemName(self.entry) or L.empty, 1, 1, 1)
            GameTooltip:AddLine(self.entry and L.remove or L.choose, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cell:SetScript("OnReceiveDrag", function() TakeFromCursor(i) end)
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
        if not S.recipe then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.p_title, 1, 0.82, 0)
        if UI.resultName then GameTooltip:AddLine(UI.resultName, 1, 1, 1, true) end
        if UI.resultText then GameTooltip:AddLine(UI.resultText, 0.8, 0.8, 0.8, true) end
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
    local frame = CreateFrame("Frame", "WorkbenchPicker", f)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetWidth(EC.PICK_W)
    frame:SetHeight(EC.PICK_ROWS * EC.PICK_ROW_H + 34)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
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
    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    frame.empty:SetPoint("TOPLEFT", 12, -26)
    frame.empty:SetTextColor(1, 0.3, 0.3)
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
            Put(frame.cell, self.entry)
        end)
        frame.lines[i] = line
    end
    frame.offset = 0
    frame.tabs, frame.tab = {}, nil

    -- The slider, on the right, only when the list is longer than its rows.
    local slider = CreateFrame("Slider", nil, frame)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(EC.PICK_SLIDER)
    slider:SetPoint("TOPRIGHT", -10, -26)
    slider:SetPoint("BOTTOMRIGHT", -10, 10)
    slider:SetThumbTexture(EC.KNOB)
    slider:GetThumbTexture():SetWidth(EC.PICK_SLIDER)
    slider:GetThumbTexture():SetHeight(24)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOPLEFT", 6, 0)
    track:SetPoint("BOTTOMRIGHT", -6, 0)
    track:SetTexture(0, 0, 0, 0.6)
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(1)
    slider:SetScript("OnValueChanged", function(self, value)
        if self.settling then return end
        local at = floor(value + 0.5)
        if at ~= frame.offset then
            frame.offset = at
            FillPicker()
        end
    end)
    slider:Hide()
    frame.slider = slider

    -- A click anywhere but on the list closes it: a frame under the list,
    -- covering the screen, catches the click.
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function() frame:Hide() end)
    catcher:Hide()
    frame:SetFrameLevel(catcher:GetFrameLevel() + 5)
    frame:SetScript("OnShow", function() catcher:Show() end)
    frame:SetScript("OnHide", function() catcher:Hide() end)

    UI.pick = frame
    tinsert(UISpecialFrames, "WorkbenchPicker")

    -- The bags move with every craft: the list rights itself.
    local idle = CreateFrame("Frame", nil, f)
    idle:RegisterEvent("BAG_UPDATE")
    idle:SetScript("OnEvent", function()
        if f:IsShown() and frame:IsShown() then FillPicker() end
    end)

    tinsert(UISpecialFrames, "WorkbenchFrame")
    return f
end

-- ---------------------------------------------------------------------------
-- What the server sends
-- ---------------------------------------------------------------------------

function Handlers.Show(_, state)
    S.state = state
    local old = _G["WorkbenchFrame"]
    if old and (not UI or UI.frame ~= old) then old:Hide() end
    local f = (UI and UI.frame) or Build()
    Update()
    f:Show()
end

function Handlers.State(_, state)
    S.state = state
    if UI and UI.frame:IsShown() then
        Update()
        if UI.pick:IsShown() then FillPicker() end
    end
end

function Handlers.Eligible(_, entries, kinds)
    if not UI or not UI.frame:IsShown() then return end
    S.eligible, S.kinds = entries or {}, kinds or {}
    UI.pick.tab = nil
    FillPicker()
    UI.pick:Show()
end

function Handlers.Close()
    if not UI then return end
    ClosePicker()
    if UI.frame then UI.frame:Hide() end
end
