-- ForeverUI: buff and debuff bars in camelot style (blizzard_buffframe, AuraContainerMixin).
-- Data and options come from 3.3.5; the client's BuffFrame, enchants and consolidation are hidden.
-- CancelUnitBuff and CancelItemTempEnchantment are not protected in 3.3.5.
-- Not in 3.3.5, so not here: external defensives, deadly debuffs, private auras, Bleed type.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local B = {}
ForeverUI.Buffs = B

local SEP = string.char(92)
local L = ForeverUI.L

local G = {
	width = 30, height = 40, icon = 30,
	border = 40, enchantBorder = 32,
	space = 5,
	collapseW = 15, collapseH = 30, arrowW = 10, arrowH = 16, highlight = 0.4,
	alert = 31, alertDuration = 90,
	period = 1.5, alphaMin = 0.3, alphaMax = 1,
	check = 0.2, tooltip = 0.2,
	tooltipPerRow = 5, tooltipScale = 0.8, tooltipMargin = 16, tooltipRight = 9, tooltipBottom = 2,
	tooltipExitMargin = 10,
}

local BARS = {
	buffs = { name = "ForeverUIBuffFrame", filter = "HELPFUL", max = 32, perRow = 11,
		x = -255, y = -10, caption = L.BUFFS_EDIT_LABEL_BUFFS },
	debuffs = { name = "ForeverUIDebuffFrame", filter = "HARMFUL", max = 16, perRow = 8,
		x = -270, y = -155, caption = L.BUFFS_EDIT_LABEL_DEBUFFS, showType = true },
}

-- Dishonored debuff: the client only shows an aura its own Spell.dbc knows, and no stock spell
-- fits. ForeverUI draws it from the state mod-pvp-titles-ext sends over the addon channel
-- (PvPTab.lua, ForeverUI.Dishonor): first among debuffs, no type.
local DISHONOR_ICON = "Interface" .. SEP .. "Icons" .. SEP .. "Ability_Hunter_MarkedForDeath"

-- Border per type (camelot DEBUFF_DISPLAY_INFO): no icon, with icon, colorblind symbol.
local TYPES = {
	Magic = { "ui-debuff-border-magic-noicon", "ui-debuff-border-magic-icon", "DEBUFF_SYMBOL_MAGIC" },
	Curse = { "ui-debuff-border-curse-noicon", "ui-debuff-border-curse-icon", "DEBUFF_SYMBOL_CURSE" },
	Disease = { "ui-debuff-border-disease-noicon", "ui-debuff-border-disease-icon", "DEBUFF_SYMBOL_DISEASE" },
	Poison = { "ui-debuff-border-poison-noicon", "ui-debuff-border-poison-icon", "DEBUFF_SYMBOL_POISON" },
	None = { "ui-debuff-border-default-noicon" },
}

local ENCHANT_BORDER = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-TempEnchant-Border"
local CONSOLIDATION = "Interface" .. SEP .. "Buttons" .. SEP .. "BuffConsolidation"

-- ---------- Options

local function durations() return SHOW_BUFF_DURATIONS == "1" end
local function consolidateEnabled() return CONSOLIDATE_BUFFS == "1" end
local function colorblindMode() return ENABLE_COLORBLIND_MODE == "1" end
-- camelot: collapse and consolidation exclude each other; 3.3.5 has no collapse option.
local function collapseEnabled() return not consolidateEnabled() end

-- Shown unit: the vehicle while in one. PlayerFrame is suppressed, so PlayerFrame.unit
-- does not follow the vehicle and the unit is computed here.
function B.unit()
	if UnitHasVehicleUI and UnitHasVehicleUI("player") and UnitExists("vehicle") then
		return "vehicle"
	end
	return "player"
end

-- ---------- Warning blink

-- AuraContainerWarningFader: under 31 s, alpha goes 0.3 -> 1 -> 0.3 over 1.5 s, the same
-- for all icons. rest: seconds left.
function B.warningAlpha(rest)
	if rest and rest < G.alert then
		local half = G.period / 2
		local t = (GetTime() or 0) % G.period
		local p = (t < half) and (t / half) or ((G.period - t) / half)
		return G.alphaMin + (G.alphaMax - G.alphaMin) * p
	end
	return G.alphaMax
end

-- ---------- One button

local function filterOf(b)
	if b.auraType == "Buff" or b.auraType == "TempEnchant" then return "HELPFUL" end
	if b.auraType == "Debuff" then return "HARMFUL" end
end

local function tooltip(b)
	if b.auraType == "TempEnchant" then
		GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetInventoryItem("player", b.info.ID)
		return
	end
	GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetFrameLevel(b:GetFrameLevel() + 2)
	if b.info.dishonor then
		local c = NORMAL_FONT_COLOR
		GameTooltip:SetText(ForeverUI.Dishonor.name(), 1, 1, 1)
		GameTooltip:AddLine(L.BUFFS_DISHONORED_DESC, c.r, c.g, c.b, true)
		GameTooltip:Show()
		return
	end
	GameTooltip:SetUnitAura(b.unit, b.info.index, filterOf(b))
end

local function updateDuration(b, rest)
	local showRegion = rest and durations()
	if showRegion then
		b.Duration:SetFormattedText(SecondsToTimeAbbrev(rest))
		local c = (rest < G.alertDuration) and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR
		b.Duration:SetVertexColor(c.r, c.g, c.b)
		b.Duration:Show()
	else
		b.Duration:Hide()
	end
end

local function onUpdate(b, elapsed)
	if not b.info then return end
	if b.auraType == "TempEnchant" and B.unit() ~= "player" then
		b:Hide()
		return
	end
	b:SetAlpha(B.warningAlpha(b.rest))
	b.rest = math.max((b.info.expirationTime or 0) - GetTime(), 0)
	updateDuration(b, b.rest)
	b.tooltipTimer = (b.tooltipTimer or 0) - (elapsed or 0)
	if b.tooltipTimer <= 0 then
		b.tooltipTimer = G.tooltip
		if GameTooltip:IsOwned(b) then tooltip(b) end
	end
end

local function applyType(b, auraType)
	b.auraType = auraType
	b.Symbol:Hide()
	if auraType == "Buff" then
		b.DebuffBorder:Hide()
		b.TempEnchantBorder:Hide()
	elseif auraType == "Debuff" then
		ForeverUI.SetAtlas(b.DebuffBorder, TYPES.None[1])
		b.DebuffBorder:Show()
		b.TempEnchantBorder:Hide()
	elseif auraType == "TempEnchant" then
		b.DebuffBorder:Hide()
		b.TempEnchantBorder:Show()
	end
end

local function applyExpiration(b, info)
	if info.expirationTime and info.expirationTime > 0 then
		if durations() then b.Duration:Show() else b.Duration:Hide() end
		b.rest = info.expirationTime - GetTime()
		b:SetScript("OnUpdate", onUpdate)
	else
		b.Duration:Hide()
		b:SetScript("OnUpdate", nil)
		b.rest = nil
		b:SetAlpha(1)
	end
end

-- AuraButtonMixin:Update. info: aura data; showType: debuff border with its type icon.
function B.populate(b, info, showType)
	applyType(b, info.auraType)
	b.info = info
	b.unit = B.unit()
	if info.auraType == "Debuff" then
		local t = TYPES[info.debuffType or ""] or TYPES.None
		ForeverUI.SetAtlas(b.DebuffBorder, (showType and t[2]) or t[1])
		if colorblindMode() and t[3] then
			b.Symbol:SetText(_G[t[3]] or "")
			b.Symbol:Show()
		end
	end
	applyExpiration(b, info)
	b.Icon:SetTexture(info.texture)
	if (info.count or 0) > 1 then
		b.Count:SetText(info.count)
		b.Count:Show()
	else
		b.Count:Hide()
	end
	if GameTooltip:IsOwned(b) then tooltip(b) end
end

-- AuraButtonArtTemplate: 30 x 40, icon 30 on top, duration below; right-click cancels.
function B.createButton(parent, name)
	local b = CreateFrame("Button", name, parent)
	b:SetWidth(G.width)
	b:SetHeight(G.height)
	b.Icon = b:CreateTexture(nil, "BACKGROUND")
	b.Icon:SetWidth(G.icon)
	b.Icon:SetHeight(G.icon)
	b.Icon:SetPoint("TOP", b, "TOP", 0, 0)
	b.Duration = b:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
	b.Duration:SetPoint("TOP", b.Icon, "BOTTOM", 0, 0)
	b.Duration:Hide()
	b.DebuffBorder = b:CreateTexture(nil, "OVERLAY")
	b.DebuffBorder:SetWidth(G.border)
	b.DebuffBorder:SetHeight(G.border)
	b.DebuffBorder:SetPoint("CENTER", b.Icon, "CENTER", 0, 0)
	b.TempEnchantBorder = b:CreateTexture(nil, "OVERLAY")
	b.TempEnchantBorder:SetTexture(ENCHANT_BORDER)
	b.TempEnchantBorder:SetWidth(G.enchantBorder)
	b.TempEnchantBorder:SetHeight(G.enchantBorder)
	b.TempEnchantBorder:SetPoint("CENTER", b.Icon, "CENTER", 0, 0)
	b.Symbol = b:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	b.Symbol:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.Count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.Count:SetPoint("BOTTOMRIGHT", b.Icon, "BOTTOMRIGHT", -2, 2)
	applyType(b, nil)
	b:RegisterForClicks("RightButtonUp")
	b:SetScript("OnClick", function(self, button)
		if button ~= "RightButton" or not self.info then return end
		if self.auraType == "Buff" then
			CancelUnitBuff(self.unit, self.info.index, "HELPFUL")
		elseif self.auraType == "TempEnchant" then
			CancelItemTempEnchantment(self.info.ID == 16 and 1 or 2)
		end
	end)
	b:SetScript("OnEnter", function(self) if self.info then tooltip(self) end end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:Hide()
	return b
end

-- ---------- Grid

-- Right to left, then down (AuraContainerMixin). buttons: the buttons to place.
local function arrange(container, buttons, perRow)
	for i, b in ipairs(buttons) do
		local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
		b:ClearAllPoints()
		b:SetPoint("TOPRIGHT", container, "TOPRIGHT",
			-col * (G.width + G.space), -row * (G.height + G.space))
	end
end

-- ---------- One bar

local function createBar(key)
	local c = BARS[key]
	local f = CreateFrame("Frame", c.name, UIParent)
	f:SetFrameStrata("LOW")
	f.key, f.c = key, c
	f.container = CreateFrame("Frame", nil, f)
	f.container:SetWidth(1)
	f.container:SetHeight(1)
	f.buttons = {}
	for i = 1, c.max do
		f.buttons[i] = B.createButton(f.container, c.name .. "Button" .. i)
	end
	local rows = math.ceil(c.max / c.perRow)
	local width = (G.width + G.space) * c.perRow
	if key == "buffs" then width = width + G.collapseW end
	f:SetWidth(width)
	f:SetHeight((G.height + G.space) * rows)
	f.auras = {}
	return f
end

-- Collapse button: bag-arrow, flipped when the bar is expanded. t: arrow texture.
local function orientArrow(t, flipped)
	local e = ForeverUI.AtlasEntry("bag-arrow")
	if not e then return end
	t:SetTexture(e[1])
	local u1, u2, v1, v2 = e[2], e[3], e[4], e[5]
	if flipped then
		t:SetTexCoord(u2, v2, u2, v1, u1, v2, u1, v1)
	else
		t:SetTexCoord(u1, v1, u1, v2, u2, v1, u2, v2)
	end
end

function B.orientCollapse()
	local r = B.buffs.collapse
	-- Icons grow to the left: expanded, the arrow is rotated by pi.
	local expanded = r:GetChecked() and true or false
	for _, t in ipairs({ r:GetNormalTexture(), r:GetPushedTexture(), r:GetHighlightTexture() }) do
		orientArrow(t, expanded)
	end
end

local function createCollapse(f)
	local r = CreateFrame("CheckButton", f.c.name .. "CollapseAndExpandButton", f)
	r:SetWidth(G.collapseW)
	r:SetHeight(G.collapseH)
	r:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	local e = ForeverUI.AtlasEntry("bag-arrow")
	r:SetNormalTexture(e and e[1] or "")
	r:SetPushedTexture(e and e[1] or "")
	r:SetHighlightTexture(e and e[1] or "", "ADD")
	for _, t in ipairs({ r:GetNormalTexture(), r:GetPushedTexture(), r:GetHighlightTexture() }) do
		t:ClearAllPoints()
		t:SetWidth(G.arrowW)
		t:SetHeight(G.arrowH)
		t:SetPoint("CENTER", r, "CENTER", 0, 0)
	end
	r:GetHighlightTexture():SetAlpha(G.highlight)
	r:SetChecked(true)
	r:SetScript("OnClick", function(self)
		B.expanded = self:GetChecked() and true or false
		B.orientCollapse()
		B.update()
	end)
	f.collapse = r
	f.container:SetPoint("TOPRIGHT", r, "TOPLEFT", 0, 0)
	return r
end

-- Consolidation icon (BuffConsolidation) and its popup.
local function createConsolidation(f)
	local b = B.createButton(f.container, f.c.name .. "ConsolidatedBuffs")
	applyType(b, "Buff")
	b.Icon:SetTexture(CONSOLIDATION)
	b.Icon:SetTexCoord(0.109375, 0.390625, 0.21875, 0.78125)
	b:SetScript("OnClick", nil)
	b:SetScript("OnLeave", nil)
	b.count = 0

	local tooltipFrame = CreateFrame("Frame", f.c.name .. "ConsolidatedBuffsTooltip", b)
	tooltipFrame:SetFrameStrata("TOOLTIP")
	tooltipFrame:SetClampedToScreen(true)
	tooltipFrame:SetPoint("TOPLEFT", b.Icon, "BOTTOMLEFT", 0, 0)
	tooltipFrame:SetBackdrop({
		bgFile = "Interface" .. SEP .. "Tooltips" .. SEP .. "UI-Tooltip-Background",
		edgeFile = "Interface" .. SEP .. "Tooltips" .. SEP .. "UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	tooltipFrame:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
	tooltipFrame:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
	tooltipFrame:Hide()
	local auras = CreateFrame("Frame", nil, tooltipFrame)
	auras:SetScale(G.tooltipScale)
	auras:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", G.tooltipMargin, -G.tooltipMargin)
	auras:SetWidth(1)
	auras:SetHeight(1)
	tooltipFrame.auras = auras
	tooltipFrame.buttons = {}
	for i = 1, BARS.buffs.max do
		tooltipFrame.buttons[i] = B.createButton(auras, f.c.name .. "ConsolidatedBuffsTooltipButton" .. i)
	end
	tooltipFrame:SetScript("OnUpdate", function(self)
		local m = G.tooltipExitMargin
		if not self:IsMouseOver(m, -m, -m, m) and not b:IsMouseOver(m, -m, -m, m) then
			self:Hide()
		end
	end)
	b:SetScript("OnEnter", function() B.fillTooltip(); tooltipFrame:Show() end)
	b:SetScript("OnHide", function() tooltipFrame:Hide() end)
	b.tooltipFrame = tooltipFrame
	f.consolidated = b
	return b
end

-- Popup: the hidden buffs, 5 per row, left to right.
function B.fillTooltip()
	local b = B.buffs.consolidated
	local tooltipFrame = b.tooltipFrame
	local n = 0
	for _, info in ipairs(B.buffs.auras) do
		if info.hideable then
			n = n + 1
			local button = tooltipFrame.buttons[n]
			if not button then break end
			B.populate(button, info)
			button:Show()
			local col, row = (n - 1) % G.tooltipPerRow, math.floor((n - 1) / G.tooltipPerRow)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", tooltipFrame.auras, "TOPLEFT",
				col * (G.width + G.space), -row * (G.height + G.space))
		end
	end
	for i = n + 1, #tooltipFrame.buttons do
		tooltipFrame.buttons[i].info = nil
		tooltipFrame.buttons[i]:Hide()
	end
	local l = (G.width + G.space) * math.min(G.tooltipPerRow, n)
	local h = (G.height + G.space) * math.ceil(n / G.tooltipPerRow)
	tooltipFrame:SetWidth((G.tooltipMargin + l) * G.tooltipScale + G.tooltipRight)
	tooltipFrame:SetHeight((G.tooltipMargin + h) * G.tooltipScale + G.tooltipBottom)
end

-- ---------- Data

-- Weapon enchants: main hand, then off hand, listed before the buffs.
local function enchantments(list)
	local now = GetTime()
	local hasMain, expMain, chMain, hasOff, expOff, chOff = GetWeaponEnchantInfo()
	for _, e in ipairs({ { hasMain, expMain, chMain, 16 }, { hasOff, expOff, chOff, 17 } }) do
		if e[1] then
			local rest = (e[2] or 0) / 1000
			local info = {
				auraType = "TempEnchant",
				texture = GetInventoryItemTexture("player", e[4]),
				count = e[3] or 0,
				expirationTime = now + rest,
				ID = e[4],
			}
			info.hideable = rest > G.alertDuration
			table.insert(list, info)
		end
	end
end

-- Appends up to max auras of unit to list. hideable: no duration or more than 90 s left.
local function auras(unit, filter, max, list)
	local now = GetTime()
	for i = 1, max do
		local name, _, icon, stacks, dispelType, duration, expiration = UnitAura(unit, i, filter)
		if not name then break end
		local info = {
			auraType = (filter == "HELPFUL") and "Buff" or "Debuff",
			index = i,
			texture = icon,
			count = stacks or 0,
			debuffType = dispelType,
			duration = duration or 0,
			expirationTime = expiration or 0,
		}
		if filter == "HELPFUL" then
			info.hideable = (info.duration == 0) or (info.expirationTime == 0)
				or ((info.expirationTime - now) > G.alertDuration)
		end
		table.insert(list, info)
	end
end

-- The Dishonored debuff, first, while the state lasts (player only, not in a vehicle).
local function dishonor(list)
	local state = ForeverUI.Dishonor
	if not state or not state.finish or B.unit() ~= "player" or state.finish <= GetTime() then return end
	table.insert(list, 1, {
		auraType = "Debuff",
		texture = DISHONOR_ICON,
		count = 0,
		duration = 0,
		expirationTime = state.finish,
		dishonor = true,
	})
end

-- ---------- Update

B.expanded = true

local function expanded()
	if collapseEnabled() then return B.expanded end
	return false
end

function B.updateBuffs()
	local f = B.buffs
	local list = {}
	if B.unit() == "player" then enchantments(list) end
	auras(B.unit(), "HELPFUL", f.c.max, list)
	f.auras = list
	local hideableCount = 0
	for _, info in ipairs(list) do
		if info.hideable then hideableCount = hideableCount + 1 end
	end
	f.hideableCount = hideableCount
	-- Consolidation
	local r = f.consolidated
	r.count = hideableCount
	r.Count:SetText(hideableCount)
	local withConsolidation = consolidateEnabled() and hideableCount > 0
	if withConsolidation then r:Show() else r:Hide() end
	-- Buttons
	local isOpen = expanded()
	local following = 1
	for _, b in ipairs(f.buttons) do
		local info
		while following <= #list do
			local candidate = list[following]
			following = following + 1
			if isOpen or not candidate.hideable then
				info = candidate
				break
			end
		end
		if info then
			B.populate(b, info)
			b:Show()
		else
			b.info = nil
			b:SetScript("OnUpdate", nil)
			b:Hide()
		end
	end
	local toPlace = {}
	if withConsolidation then table.insert(toPlace, r) end
	for _, b in ipairs(f.buttons) do table.insert(toPlace, b) end
	arrange(f.container, toPlace, f.c.perRow)
	-- Collapse button only if something can be hidden
	if collapseEnabled() and hideableCount > 0 then f.collapse:Show() else f.collapse:Hide() end
	f.collapse:SetChecked(B.expanded)
	B.orientCollapse()
	if r.tooltipFrame:IsShown() then B.fillTooltip() end
	-- Watch for hidden buffs that drop under 90 s and return to the bar
	f.pending = (not isOpen and hideableCount > 0) and G.check or nil
end

function B.updateDebuffs()
	local f = B.debuffs
	local list = {}
	auras(B.unit(), "HARMFUL", f.c.max, list)
	dishonor(list)
	f.auras = list
	local toPlace = {}
	for i, b in ipairs(f.buttons) do
		local info = list[i]
		if info then
			B.populate(b, info, f.c.showType)
			b:Show()
			table.insert(toPlace, b)
		else
			b.info = nil
			b:SetScript("OnUpdate", nil)
			b:Hide()
		end
	end
	arrange(f.container, toPlace, f.c.perRow)
end

function B.update()
	B.updateBuffs()
	B.updateDebuffs()
end

-- ---------- Build

B.buffs = createBar("buffs")
B.debuffs = createBar("debuffs")
createCollapse(B.buffs)
createConsolidation(B.buffs)
B.orientCollapse()
B.debuffs.container:SetPoint("TOPRIGHT", B.debuffs, "TOPRIGHT", 0, 0)

for _, key in ipairs({ "buffs", "debuffs" }) do
	local c = BARS[key]
	ForeverUI.Layout.Register(B[key], key, c.caption, "TOPRIGHT", "TOPRIGHT", c.x, c.y)
end

-- The client's BuffFrame, weapon enchants and consolidation
for _, name in ipairs({ "BuffFrame", "TemporaryEnchantFrame", "ConsolidatedBuffs", "ConsolidatedBuffsTooltip" }) do
	ForeverUI.Suppress(_G[name])
end

-- Interface options (durations, consolidation) go through these two
if BuffFrame_UpdatePositions then hooksecurefunc("BuffFrame_UpdatePositions", function() B.update() end) end
if BuffFrame_Update then hooksecurefunc("BuffFrame_Update", function() B.update() end) end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("UNIT_AURA")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("UNIT_ENTERED_VEHICLE")
watcher:RegisterEvent("UNIT_EXITED_VEHICLE")
watcher:SetScript("OnEvent", function(self, event, unit)
	if event == "UNIT_AURA" then
		if unit == B.unit() then B.update() end
	elseif event == "PLAYER_ENTERING_WORLD" or unit == "player" then
		B.update()
	end
end)

-- Every 0.2 s: weapon enchants (3.3.5 has no event; its TemporaryEnchantFrame polls every
-- frame) and hidden buffs that return to the collapsed bar.
local function enchantsSignature()
	if B.unit() ~= "player" then return "" end
	local a, _, ca, g, _, cg = GetWeaponEnchantInfo()
	return tostring(a) .. ":" .. tostring(ca) .. ":" .. tostring(GetInventoryItemTexture("player", 16))
		.. "|" .. tostring(g) .. ":" .. tostring(cg) .. ":" .. tostring(GetInventoryItemTexture("player", 17))
end

watcher.clock = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
	self.clock = self.clock - (elapsed or 0)
	if self.clock > 0 then return end
	self.clock = G.check
	local s = enchantsSignature()
	if s ~= self.enchants then
		self.enchants = s
		B.update()
		return
	end
	local f = B.buffs
	if f.pending then
		local now = GetTime()
		for _, info in ipairs(f.auras) do
			if info.hideable and info.expirationTime and info.expirationTime > 0
				and (info.expirationTime - now) <= G.alertDuration then
				B.update()
				return
			end
		end
	end
end)
B.watcher = watcher

B.update()

-- /fui buffs: prints the state of both bars.
function ForeverUI.BuffsDebug()
	local say = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t) end
	local f = B.buffs
	local shownItems = 0
	for _, b in ipairs(f.buttons) do if b:IsShown() then shownItems = shownItems + 1 end end
	say(string.format(L.BUFFS_DEBUG_BUFFS,
		B.unit(), #f.auras, f.hideableCount or 0, shownItems, f.collapse:IsShown() and L.BUFFS_DEBUG_VISIBLE or L.BUFFS_DEBUG_HIDDEN, tostring(B.expanded),
		f.consolidated:IsShown() and L.BUFFS_DEBUG_VISIBLE or L.BUFFS_DEBUG_HIDDEN, f.consolidated.count or 0, tostring(durations())))
	local d = B.debuffs
	local types = {}
	for _, info in ipairs(d.auras) do table.insert(types, tostring(info.debuffType or NONE)) end
	say(string.format(L.BUFFS_DEBUG_DEBUFFS, #d.auras, table.concat(types, ", ")))
end
