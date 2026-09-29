-- ForeverUI: the macro window (MacroFrame) and its icon picker (MacroPopupFrame) from the
-- load-on-demand Blizzard_MacroUI, moved to camelot's places (ButtonFrameTemplate 338 x 424).
-- camelot's Save / Cancel do not exist in 3.3.5 (a macro saves on switch or close): not added.
-- The icon picker matches IconPicker.lua (IconSelectorPopupFrameTemplate) with the client's
-- scrolling. Never write NUM_ICONS_PER_ROW, NUM_ICON_ROWS, NUM_MACRO_ICONS_SHOWN or
-- MACRO_ICON_ROW_HEIGHT: the client fills the picker with them.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates
local L = ForeverUI.L

local M = {}
ForeverUI.Macros = M

local SEP = string.char(92)

local N = {
	window = { 338, 424 },
	portrait = { side = 58, x = -5, y = 5 },
	frameBox = { 4, -60, -6, 26 },
	grid = { x = 12, y = -66, l = 319, h = 146, margin = 5, gap = 13, perRow = 6 },
	gridBar = { x = -14, top = -7, down = 3 },
	bar = { 16, 11 },                 -- client Slider width, arrow height
	textBar = { x = 6, top = -4, down = 5 },
	textWidth = 286,                 -- 3.3.5 MacroFrameScrollFrame / Text / TextButton
	textBackgroundL = 322,                   -- MacroFrameTextBackground (3.3.5 and camelot)
	macroButton = 36,                   -- PopupButtonTemplate
	line = { 2, -210 },
	selected = { 5, -218 },
	edit = { 55, -30 },
	enterText = { 8, 3 },
	text = { 11, -13 },
	textBackground = { 6, -289 },
	limit = { -15, 30 },
	tab = { x = 51, y = -28, h = 32, sides = 72, max = 140, margin = 20, text = -8, selectedText = -4, reduced = 0.75 },
	button = { 80, 22 },
	delete = { 4, 4 }, new = { -82, 4 }, exit = { -5, 4 },
}

-- ------------------------------------------------------------ Tabs

local TAB = {
	activeLeft = "uiframe-activetab-left", activeMiddle = "_uiframe-activetab-center", activeRight = "uiframe-activetab-right",
	g = "uiframe-tab-left-c60", m = "_uiframe-tab-center-c60", d = "uiframe-tab-right-c60",
}

-- One tab piece flipped vertically and cut to 75 % (PanelTopTabButtonMixin:
-- SetTexCoord(0, 1, 1, 0.25) on the atlas, height x 0.75)
local function piece(b, layer, atlas)
	local t = b:CreateTexture(nil, layer)
	local e = ForeverUI.AtlasEntry(atlas)
	ForeverUI.SetAtlas(t, atlas)
	if e then
		local top = e[4] + (e[5] - e[4]) * (1 - N.tab.reduced)
		t:SetTexCoord(e[2], e[3], e[5], top)
		t:SetHeight(e[7] * N.tab.reduced)
	end
	return t
end

-- Show the active or inactive art and pick the font for the tab state.
local function paintTab(o)
	local a = o.foreverArt
	local selected = MacroFrame and MacroFrame.selectedTab == o:GetID()
	local active = Tpl.Truthy(o:IsEnabled())
	for _, t in ipairs({ a.activeLeft, a.activeMiddle, a.activeRight }) do Tpl.SetShown(t, selected) end
	for _, t in ipairs({ a.g, a.m, a.d }) do Tpl.SetShown(t, not selected) end
	local font
	if selected or (active and o.foreverHovered) then
		font = GameFontHighlightSmall
	elseif active then
		font = GameFontNormalSmall
	else
		font = GameFontDisableSmall
	end
	o:SetNormalFontObject(font)
	o:SetDisabledFontObject(font)
	local text = o:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("CENTER", o, "CENTER", 0, selected and N.tab.selectedText or N.tab.text)
		o:SetWidth(math.max(N.tab.sides, math.min(N.tab.max, (text:GetStringWidth() or 0) + N.tab.margin)))
	end
end

local function skinTab(o)
	local name = o:GetName()
	for _, s in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
		local t = _G[name .. s]
		if t then t:SetAlpha(0) end
	end
	local glow = o:GetHighlightTexture()
	if glow then
		glow:SetTexture(nil)
		glow:SetAlpha(0)
	end
	o:SetHeight(N.tab.h)
	local a = {}
	a.activeLeft = piece(o, "BACKGROUND", TAB.activeLeft)
	a.activeLeft:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", -1, 0)
	a.activeRight = piece(o, "BACKGROUND", TAB.activeRight)
	a.activeRight:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 8, 0)
	a.activeMiddle = piece(o, "BACKGROUND", TAB.activeMiddle)
	a.activeMiddle:SetPoint("TOPLEFT", a.activeLeft, "TOPRIGHT", 0, 0)
	a.activeMiddle:SetPoint("TOPRIGHT", a.activeRight, "TOPLEFT", 0, 0)
	a.g = piece(o, "BACKGROUND", TAB.g)
	a.g:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", -3, 0)
	a.d = piece(o, "BACKGROUND", TAB.d)
	a.d:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 7, 0)
	a.m = piece(o, "BACKGROUND", TAB.m)
	a.m:SetPoint("TOPLEFT", a.g, "TOPRIGHT", 0, 0)
	a.m:SetPoint("TOPRIGHT", a.d, "TOPLEFT", 0, 0)
	-- highlight: the inactive art in ADD at 0.4
	for _, key in ipairs({ "g", "m", "d" }) do
		local s = piece(o, "HIGHLIGHT", TAB[key])
		s:SetBlendMode("ADD")
		s:SetAlpha(0.4)
		s:SetAllPoints(a[key])
	end
	o.foreverArt = a
	o:HookScript("OnEnter", function(self) self.foreverHovered = true; paintTab(self) end)
	o:HookScript("OnLeave", function(self) self.foreverHovered = false; paintTab(self) end)
	o:HookScript("OnShow", paintTab)
	o:HookScript("OnEnable", paintTab)
	o:HookScript("OnDisable", paintTab)
	o:HookScript("OnClick", function()
		paintTab(MacroFrameTab1)
		paintTab(MacroFrameTab2)
	end)
	paintTab(o)
end

-- ------------------------------------------------------------ Window

local function place(r, point, target, relativeTo, x, y)
	r:ClearAllPoints()
	r:SetPoint(point, target, relativeTo, x, y)
end

-- Put a client scroll bar at camelot's place: the 16-wide Slider centered on the 8-wide bar,
-- its arrows (outside it) at the bar ends.
-- target: scroll frame; x: offset from its right edge; top, down: vertical insets
local function attachBar(sb, target, x, top, down)
	local half = (N.bar[1] - 8) / 2
	sb:ClearAllPoints()
	sb:SetPoint("TOPLEFT", target, "TOPRIGHT", x - half, top - N.bar[2])
	sb:SetPoint("BOTTOMLEFT", target, "BOTTOMRIGHT", x - half, down + N.bar[2])
	Tpl.Bar(sb)
end

function M.Skin()
	local f = MacroFrame
	if not f or f.foreverSkin then return end
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	-- 3.3.5 art: the four background pieces, the portrait and the unnamed title are hidden; the
	-- bar and the selected-macro background stay (camelot keeps them)
	local kept = { [MacroHorizontalBarLeft] = true, [MacroFrameSelectedMacroBackground] = true }
	for _, r in ipairs({ f:GetRegions() }) do
		local kind = r:GetObjectType()
		if kind == "Texture" and not kept[r] then
			local _, relativeTo = r:GetPoint(1)
			-- the second bar piece anchors on the first: keep it
			if relativeTo ~= MacroHorizontalBarLeft then
				r:SetAlpha(0)
			end
		elseif kind == "FontString" and r:GetText() == CREATE_MACROS then
			r:SetAlpha(0)
		end
	end
	local skin = Tpl.PortraitWindow(f, {
		portrait = "Interface" .. SEP .. "MacroFrame" .. SEP .. "MacroFrame-Icon",
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = CREATE_MACROS,
	})
	f.foreverSkin = skin
	-- ButtonFrameTemplate inset: marble and edge, as regions of the window (under its texts
	-- and buttons)
	local rect = CreateFrame("Frame", nil, f)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", N.frameBox[1], N.frameBox[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", N.frameBox[3], N.frameBox[4])
	local marble = f:CreateTexture(nil, "BACKGROUND")
	marble:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble", true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(rect)
	skin.frameBox = Tpl.NineSlice(f, "InsetFrameTemplate", rect)
	skin.marble = marble
	-- close button above the metal (child frame at +20), as in the Social window
	Tpl.CloseButton(MacroFrameCloseButton, f)
	MacroFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)

	-- tabs
	place(MacroFrameTab1, "TOPLEFT", f, "TOPLEFT", N.tab.x, N.tab.y)
	skinTab(MacroFrameTab1)
	skinTab(MacroFrameTab2)

	-- grid: 6 per row, margins 5, 13 between icons
	local G = N.grid
	local grid = MacroButtonScrollFrame
	place(grid, "TOPLEFT", f, "TOPLEFT", G.x, G.y)
	local barX = G.l + N.gridBar.x
	grid:SetWidth(barX - (N.bar[1] - 8) / 2)
	grid:SetHeight(G.h)
	for _, r in ipairs({ grid:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	for i = 1, math.max(MAX_ACCOUNT_MACROS or 36, MAX_CHARACTER_MACROS or 18) do
		local b = _G["MacroButton" .. i]
		if b then
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint("TOPLEFT", MacroButtonContainer, "TOPLEFT", G.margin, -G.margin)
			elseif math.fmod(i - 1, G.perRow) == 0 then
				b:SetPoint("TOP", _G["MacroButton" .. (i - G.perRow)], "BOTTOM", 0, -G.gap)
			else
				b:SetPoint("LEFT", _G["MacroButton" .. (i - 1)], "RIGHT", G.gap, 0)
			end
		end
	end
	-- grid scroll bar: -14 from the selector's right edge, -7 / 3
	local sb = MacroButtonScrollFrameScrollBar
	local half = (N.bar[1] - 8) / 2
	sb:ClearAllPoints()
	sb:SetPoint("TOPLEFT", f, "TOPLEFT", G.x + barX - half, G.y + N.gridBar.top - N.bar[2])
	sb:SetPoint("BOTTOMLEFT", f, "TOPLEFT", G.x + barX - half, G.y - G.h + N.gridBar.down + N.bar[2])
	Tpl.Bar(sb)
	-- scroll bar only when needed. The icons have a fixed size: without the bar the grid is
	-- centered in the inset; with it, camelot's place
	local gridWidth = G.perRow * N.macroButton + (G.perRow - 1) * G.gap
	local frameBoxLeft, frameBoxRight = N.frameBox[1], N.window[1] + N.frameBox[3]
	local centerOffset = ((frameBoxLeft + frameBoxRight) - (2 * (G.x + G.margin) + gridWidth)) / 2
	Tpl.BarByContent(grid, function(hasBar)
		place(MacroButton1, "TOPLEFT", MacroButtonContainer, "TOPLEFT", G.margin + (hasBar and 0 or centerOffset), -G.margin)
	end)

	-- selected macro
	place(MacroHorizontalBarLeft, "TOPLEFT", f, "TOPLEFT", N.line[1], N.line[2])
	place(MacroFrameSelectedMacroBackground, "TOPLEFT", f, "TOPLEFT", N.selected[1], N.selected[2])
	place(MacroEditButton, "TOPLEFT", MacroFrameSelectedMacroBackground, "TOPLEFT", N.edit[1], N.edit[2])
	place(MacroFrameEnterMacroText, "TOPLEFT", MacroFrameSelectedMacroBackground, "BOTTOMLEFT", N.enterText[1], N.enterText[2])
	place(MacroFrameScrollFrame, "TOPLEFT", MacroFrameSelectedMacroBackground, "BOTTOMLEFT", N.text[1], N.text[2])
	attachBar(MacroFrameScrollFrameScrollBar, MacroFrameScrollFrame, N.textBar.x, N.textBar.top, N.textBar.down)
	-- text: scroll bar only when needed; without it the text (and its click area) widens to leave
	-- on the right of its background the margin it has on the left (background 6..328, text at
	-- 16: 302)
	local textLeft = N.selected[1] + N.text[1]
	local textNoBar = (N.textBackground[1] + N.textBackgroundL) - (textLeft - N.textBackground[1]) - textLeft
	Tpl.BarByContent(MacroFrameScrollFrame, function(hasBar)
		local l = hasBar and N.textWidth or textNoBar
		MacroFrameScrollFrame:SetWidth(l)
		MacroFrameText:SetWidth(l)
		MacroFrameTextButton:SetWidth(l)
	end)
	place(MacroFrameTextBackground, "TOPLEFT", f, "TOPLEFT", N.textBackground[1], N.textBackground[2])
	ForeverUI.Tooltips.Skin(MacroFrameTextBackground)
	place(MacroFrameCharLimitText, "BOTTOM", f, "BOTTOM", N.limit[1], N.limit[2])

	-- buttons
	for _, b in ipairs({ MacroDeleteButton, MacroNewButton, MacroExitButton }) do
		b:SetWidth(N.button[1])
		b:SetHeight(N.button[2])
	end
	for _, b in ipairs({ MacroDeleteButton, MacroNewButton, MacroExitButton, MacroEditButton }) do
		Tpl.PanelButton(b)
	end
	place(MacroDeleteButton, "BOTTOMLEFT", f, "BOTTOMLEFT", N.delete[1], N.delete[2])
	place(MacroNewButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.new[1], N.new[2])
	place(MacroExitButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.exit[1], N.exit[2])

	M.SkinChoice()
end

-- ============================================================ Icon picker
--
-- IconSelectorPopupFrameTemplate, as in IconPicker.lua (equipment sets): 525 x 495, grid of
-- 10 per row, icons of 36 with 10 between them, margins 5; current choice area 275 x 45 at
-- TOPRIGHT (-13, -13); Okay / Cancel 78 x 22 at BOTTOMRIGHT (-11, 13); SelectionFrameTemplate
-- border (macropopup-*) over a black background at 0.8.
local P = {
	window = { 525, 495 }, position = { 0, 5 },
	header = { 24, -21 }, field = { 29, -35 }, choose = { 24, -79 },
	zone = { l = 275, h = 45, x = -13, y = -13 }, choice = { side = 36, x = -4.5, y = -3.5 },
	grid = { x = 21, y = -97 }, icon = 36, perRow = 10, rowLines = 7, gap = 10, margin = 5,
	buttonBottom = { l = 78, h = 22, x = -11, y = 13, gap = -2 },
	background = { alpha = 0.8, margin = 7 },
	rightEdge = 17,
}

local function shownCount()
	return P.perRow * P.rowLines
end

-- Get or create the 70 picker buttons (the client has only 20).
local function choiceButtons()
	local list = {}
	for i = 1, shownCount() do
		local b = _G["MacroPopupButton" .. i]
		if not b then
			b = CreateFrame("CheckButton", "MacroPopupButton" .. i, MacroPopupFrame, "MacroPopupButtonTemplate")
		end
		b:SetID(i)
		list[i] = b
	end
	return list
end

-- Grid of ten per row
local function layoutGrid(popup)
	local step = P.icon + P.gap
	for i, b in ipairs(popup.foreverButtons) do
		b:SetWidth(P.icon)
		b:SetHeight(P.icon)
		b:ClearAllPoints()
		if i == 1 then
			b:SetPoint("TOPLEFT", popup, "TOPLEFT", P.grid.x + P.margin, P.grid.y - P.margin)
		elseif math.fmod(i - 1, P.perRow) == 0 then
			b:SetPoint("TOPLEFT", popup.foreverButtons[i - P.perRow], "BOTTOMLEFT", 0, -P.gap)
		else
			b:SetPoint("TOPLEFT", popup.foreverButtons[i - 1], "TOPRIGHT", P.gap, 0)
		end
	end
	local scroll = MacroPopupScrollFrame
	scroll:SetWidth(P.perRow * step - P.gap + 2 * P.margin)
	scroll:SetHeight(P.rowLines * step - P.gap + 2 * P.margin)
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", P.grid.x, P.grid.y)
	for _, r in ipairs({ scroll:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	-- same space on each side of the scroll bar (IconPicker)
	local iconsRight = P.grid.x + P.margin + P.perRow * step - P.gap
	local free = (P.window[1] - P.rightEdge) - iconsRight
	local x = P.window[1] - P.rightEdge - (free - 8) / 2 - 8 - (N.bar[1] - 8) / 2
	local sb = MacroPopupScrollFrameScrollBar
	sb:ClearAllPoints()
	sb:SetPoint("TOPLEFT", popup, "TOPLEFT", x, P.grid.y - P.margin - N.bar[2])
	sb:SetPoint("BOTTOMLEFT", popup, "TOPLEFT", x, P.grid.y - P.margin - (P.rowLines * step - P.gap) + N.bar[2])
	Tpl.Bar(sb)
end

-- Texture of the selected icon, shown in the current choice area
local function pickedIcon(popup)
	if popup.selectedIcon then
		return (GetMacroIconInfo(popup.selectedIcon))
	end
	return popup.selectedIconTexture
end

function M.UpdateChoice()
	local popup = MacroPopupFrame
	if popup and popup.foreverChoice then
		popup.foreverChoice.icon:SetTexture(pickedIcon(popup) or "")
	end
end

local inProgress = false

-- After MacroPopupFrame_Update: fill the grid of ten with the client's numbering. Each button
-- gets the id that the client formula (offset x 5 + GetID()) maps to the icon it shows.
function M.Fill()
	local popup = MacroPopupFrame
	local scroll = MacroPopupScrollFrame
	if inProgress or not (popup and popup.foreverButtons) then return end
	inProgress = true
	local offset = FauxScrollFrame_GetOffset(scroll) or 0
	local total = GetNumMacroIcons()
	local clientPerRow = NUM_ICONS_PER_ROW or 5
	for i, b in ipairs(popup.foreverButtons) do
		local index = offset * P.perRow + i
		b:SetID(offset * (P.perRow - clientPerRow) + i)
		local icon = _G[b:GetName() .. "Icon"]
		if index <= total then
			local texture = GetMacroIconInfo(index)
			icon:SetTexture(texture)
			b:Show()
			if (popup.selectedIcon and index == popup.selectedIcon)
				or (not popup.selectedIcon and texture and texture == popup.selectedIconTexture) then
				b:SetChecked(1)
			else
				b:SetChecked(nil)
			end
		else
			icon:SetTexture("")
			b:Hide()
		end
	end
	FauxScrollFrame_Update(scroll, math.ceil(total / P.perRow), P.rowLines, MACRO_ICON_ROW_HEIGHT)
	inProgress = false
	M.UpdateChoice()
end

-- Click on the current choice area: scroll the selected icon's row into view
function M.Realign()
	local popup = MacroPopupFrame
	local scroll = MacroPopupScrollFrame
	local total = GetNumMacroIcons()
	local match = popup.selectedIcon
	if not match and popup.selectedIconTexture then
		for index = 1, total do
			if GetMacroIconInfo(index) == popup.selectedIconTexture then
				match = index
				break
			end
		end
	end
	if match then
		local last = math.floor((total - 1) / P.perRow)
		local rowLine = math.floor((match - 1) / P.perRow)
		rowLine = math.max(0, math.min(rowLine, last - (P.rowLines - 1)))
		FauxScrollFrame_OnVerticalScroll(scroll, rowLine * MACRO_ICON_ROW_HEIGHT, MACRO_ICON_ROW_HEIGHT, nil)
	end
	M.Fill()
end

-- Current choice area: the selected icon, its title and click-to-view help
local function placeZone(popup)
	local Z = P.zone
	local zone = CreateFrame("Frame", nil, popup)
	zone:SetWidth(Z.l)
	zone:SetHeight(Z.h)
	zone:SetPoint("TOPRIGHT", popup, "TOPRIGHT", Z.x, Z.y)
	local button = CreateFrame("Button", "ForeverUIMacroIconChoiceButton", zone)
	button:SetWidth(P.choice.side)
	button:SetHeight(P.choice.side)
	button:SetPoint("TOPRIGHT", zone, "TOPRIGHT", P.choice.x, P.choice.y)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	button.icon = icon
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(button)
	local title = zone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPRIGHT", button, "TOPLEFT", -6, -2)
	title:SetText(L.ICONPICKER_CURRENTLY_SELECTED)
	local help = zone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	help:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -2)
	help:SetText(L.ICONPICKER_CLICK_TO_VIEW)
	button:SetScript("OnClick", M.Realign)
	popup.foreverChoice = button
	popup.foreverZone = zone
end

-- SelectionFrameTemplate: eight macropopup-* pieces over a black background
local function skinFrame(popup)
	for _, r in ipairs({ popup:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	local background = popup:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(0, 0, 0, P.background.alpha)
	background:SetPoint("TOPLEFT", popup, "TOPLEFT", P.background.margin, -P.background.margin)
	background:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -P.background.margin, P.background.margin)
	local function piece(atlas, point)
		local t = popup:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, atlas)
		if point then t:SetPoint(point, popup, point, 0, 0) end
		return t
	end
	local topLeft = piece("macropopup-topleft-c60", "TOPLEFT")
	local topRight = piece("macropopup-topright-c60", "TOPRIGHT")
	local bottomLeft = piece("macropopup-bottomleft-c60", "BOTTOMLEFT")
	local bottomRight = piece("macropopup-bottomright-c60", "BOTTOMRIGHT")
	local top = piece("_macropopup-top-c60")
	top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
	top:SetPoint("TOPRIGHT", topRight, "TOPLEFT")
	local down = piece("_macropopup-bottom-c60")
	down:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT")
	down:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")
	-- side strips keep their atlas width (IconPicker): two points on the same side
	local left = piece("!macropopup-left-c60")
	left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
	left:SetPoint("BOTTOMLEFT", bottomLeft, "TOPLEFT")
	local right = piece("!macropopup-right-c60")
	right:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT")
	right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")
	popup.foreverFrame = { topLeft, topRight, bottomLeft, bottomRight, top, down, left, right }
	popup.foreverBackground = background
end

function M.SkinChoice()
	local popup = MacroPopupFrame
	if not popup or popup.foreverButtons then return end
	popup:SetWidth(P.window[1])
	popup:SetHeight(P.window[2])
	popup:ClearAllPoints()
	popup:SetPoint("TOPLEFT", MacroFrame, "TOPRIGHT", P.position[1], P.position[2])
	popup.foreverButtons = choiceButtons()
	skinFrame(popup)
	-- the two unnamed labels, found by their text
	for _, r in ipairs({ popup:GetRegions() }) do
		if r:GetObjectType() == "FontString" then
			local t = r:GetText()
			if t == MACRO_POPUP_CHOOSE_ICON then
				place(r, "TOPLEFT", popup, "TOPLEFT", P.choose[1], P.choose[2])
			elseif t == MACRO_POPUP_TEXT then
				place(r, "TOPLEFT", popup, "TOPLEFT", P.header[1], P.header[2])
			end
		end
	end
	place(MacroPopupEditBox, "TOPLEFT", popup, "TOPLEFT", P.field[1], P.field[2])
	layoutGrid(popup)
	placeZone(popup)
	local B = P.buttonBottom
	for _, b in ipairs({ MacroPopupCancelButton, MacroPopupOkayButton }) do
		b:SetWidth(B.l)
		b:SetHeight(B.h)
		Tpl.PanelButton(b)
	end
	place(MacroPopupCancelButton, "BOTTOMRIGHT", popup, "BOTTOMRIGHT", B.x, B.y)
	place(MacroPopupOkayButton, "RIGHT", MacroPopupCancelButton, "LEFT", B.gap, 0)
	hooksecurefunc("MacroPopupFrame_Update", M.Fill)
	hooksecurefunc("MacroPopupButton_SelectTexture", M.UpdateChoice)
	popup:HookScript("OnShow", M.Fill)
end

-- Load-on-demand addon: skin it when it loads, or now if already loaded
if MacroFrame then
	M.Skin()
end
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(self, _, name)
	if name == "Blizzard_MacroUI" then
		M.Skin()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
M.watcher = watcher
