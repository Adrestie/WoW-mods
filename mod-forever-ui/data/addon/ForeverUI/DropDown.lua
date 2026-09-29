-- Dropdown lists with camelot's art. 3.3.5 opens every menu (dropdowns and right-click menus)
-- in the global DropDownList1 (DropDownList2 for a submenu), so skinning it skins them all.
-- Style 1 follows camelot's MenuStyle1Mixin (Blizzard_Menu, mainline family, c60 art):
-- common-dropdown-bg background, 20-high rows, GameFontHighlight, and the
-- common-dropdown-ticksquare box with the yellow checkmark over it. 3.3.5 has no radio
-- buttons (only info.checked), so the box and checkmark serve everywhere.
-- UIDROPDOWNMENU_BORDER_HEIGHT stays 15 for both top and bottom (camelot uses 8 and 15):
-- changing it would move every row of every menu.

ForeverUI = ForeverUI or {}

-- Background in nine slices. Camelot stretches one texture, but common-dropdown-bg-c60
-- (68 x 68) has a shadow around the panel (9 left and right, 6 top, 12 bottom) and 6 px cut
-- corners: stretched, the shadow grows and the gold edge moves inward. Corners keep their
-- size (18 = thickest shadow 12 + cut 6). The margins are the image's shadow, so the gold
-- edge falls exactly on the frame edge.
local BACKGROUND_ATLAS = "common-dropdown-bg-c60"
local BACKGROUND_CORNER = 18
local BACKGROUND_MARGINS = { 9, 6, 9, 12 }     -- left, top, right, bottom
local BACKGROUND_ALPHA = 0.925
local ROW_HEIGHT = 20
local CHECKBOX_ATLAS = "common-dropdown-ticksquare"
local CHECKBOX = 12
local CHECKMARK_ATLAS = "common-dropdown-icon-checkmark-yellow"
local CHECKMARK_W, CHECKMARK_H = 15, 14
local CHECKMARK_X, CHECKMARK_Y = 2, 1
local BACKDROPS = { "Backdrop", "MenuBackdrop" }

-- Style 2, for settings: a dropdown of the options windows has foreverStyle = 2
-- (Settings.lua), and its list matches the login screen options (ForeverUIGlueDropDown.lua).
-- Camelot's MenuStyle2Mixin (mainline/menutemplates.lua): nine-slice common-dropdown-c-bg
-- from (-17, 12) to (17, -22), margins 3 / 6 / 3 / 7, 20-high rows, radial tick for a
-- single choice, width = content but at least the button, list below the button. Rows use
-- size 10 (GameFont*SmallLeft) instead of 12. Other menus keep style 1.
local STYLE2 = {
	background = "common-dropdown-c-bg",
	backgroundA = { -17, 12 },
	backgroundB = { 17, -22 },
	margins = { 3, 6, 3, 7 },            -- left, top, right, bottom
	circle = "common-dropdown-tickradial",
	point = "common-dropdown-icon-radialtick-yellow",
	span = 16 + 20,                  -- circle (-3 .. 15) + 1, plus the padding
	noRadio = 20,
}

local function style2(frame)
	return frame ~= nil and type(frame) == "table" and frame.foreverStyle == 2
end

-- The menu the list serves now: the one being filled, else the open one
local function currentMenu()
	return UIDROPDOWNMENU_INIT_MENU or UIDROPDOWNMENU_OPEN_MENU
end

-- Gap the client keeps between the list and its rows: list at maxWidth + 25, rows at
-- maxWidth. Kept so the right margin does not move when the list widens.
local LIST_MARGIN = 25

-- Width. The client sizes the list on its longest text (maxWidth + 25); camelot uses the
-- opening button as a floor (DropdownButtonMixin:RegisterMenu, SetMinimumWidth). Here the
-- list gets exactly the button width, even when an entry is longer (its text is squeezed).
-- It is set on show: ToggleDropDownMenu sets UIDROPDOWNMENU_OPEN_MENU before showing the
-- list and clamps it to the screen after, so the width must be final by then.
-- Only the first level of a dropdown does this. Context menus (displayMode "MENU", whose
-- opener is an invisible 40-wide frame) and submenus take the width of their content,
-- measured again per row (measureButton) in the displayed font: the client measures in
-- the smaller GameFontHighlightSmallLeft.
local function applyWidth(list, wantedValue)
	if math.abs(list:GetWidth() - wantedValue) < 0.5 then
		return
	end
	list:SetWidth(wantedValue)
	for index = 1, (list.numButtons or 0) do
		local button = _G[list:GetName() .. "Button" .. index]
		if button then
			button:SetWidth(wantedValue - LIST_MARGIN)
		end
	end
end

-- Style 2: content inside its margins, at least the button on the first level
local function style2Width(list, opener, level)
	local m = STYLE2.margins
	local wantedValue = (list.foreverContent2 or 0) + m[1] + m[3]
	if level == 1 and opener.foreverButton and opener.displayMode ~= "MENU" then
		wantedValue = math.max(wantedValue, opener.foreverButton:GetWidth() or 0)
	end
	if not wantedValue or wantedValue <= 0 then
		return
	end
	list:SetWidth(wantedValue)
	for index = 1, (list.numButtons or 0) do
		local button = _G[list:GetName() .. "Button" .. index]
		if button then
			button:SetWidth(wantedValue - m[1] - m[3])
		end
	end
end

local function fitWidth(list)
	local opener = UIDROPDOWNMENU_OPEN_MENU
	local level = list.foreverLevel or list:GetID()
	if list.foreverStyle2 and style2(opener) then
		style2Width(list, opener, level)
		return
	end
	if level ~= 1 or not opener or not opener.GetWidth or opener.displayMode == "MENU" then
		local content = list.foreverContent
		if content and content > 0 then
			-- A ForeverUI menu can ask for a floor: the width of the button that opens it, as
			-- camelot's SetMinimumWidth
			local minimum = level == 1 and opener and opener.foreverMinimum or 0
			applyWidth(list, math.max(content + LIST_MARGIN, minimum))
		end
		return
	end

	local wantedValue = opener:GetWidth()
	if not wantedValue or wantedValue <= 0 then
		return
	end
	-- A ForeverUI menu can ask for camelot's rule as is: the button as a floor, the list
	-- growing with its content (SetMinimumWidth)
	if opener.foreverFloor and list.foreverContent then
		wantedValue = math.max(wantedValue, list.foreverContent + LIST_MARGIN)
	end
	applyWidth(list, wantedValue)
end

-- Row width by the UIDropDownMenu_AddButton formula: text + 40, + 10 for an arrow or a
-- color swatch, - 30 without a checkbox, + 10 for an icon, + the requested padding.
local function measureButton(list, button, info)
	if list.numButtons == 1 then
		list.foreverContent = 0
	end
	local text = _G[button:GetName() .. "NormalText"]
	if not (text and info and info.text) then
		return
	end
	local width = text:GetStringWidth() + 40
	if info.hasArrow or info.hasColorSwatch then width = width + 10 end
	if info.notCheckable then width = width - 30 end
	if info.icon then width = width + 10 end
	if info.padding then width = width + info.padding end
	if width > (list.foreverContent or 0) then
		list.foreverContent = width
	end
end

-- The list drops its two old backdrops for camelot's background. The backdrop is removed
-- instead of hiding the frame: ToggleDropDownMenu shows one frame or the other on each
-- opening, by displayMode. A frame without backdrop draws nothing.
local function skinList(list)
	if list.foreverBackground then
		return
	end

	local name = list:GetName()
	for _, suffix in ipairs(BACKDROPS) do
		local frame = name and _G[name .. suffix]
		if frame and frame.SetBackdrop then
			frame:SetBackdrop(nil)
		end
	end

	local slices = ForeverUI.CreateNineSlice(list, BACKGROUND_ATLAS, BACKGROUND_CORNER,
		BACKGROUND_MARGINS, "BACKGROUND")
	if not slices then
		return
	end
	for _, slice in ipairs(slices) do
		slice:SetAlpha(BACKGROUND_ALPHA)
	end
	list.foreverBackground = slices[1]
	list.foreverSlices = slices

	list:HookScript("OnShow", fitWidth)
end

-- Checkbox in BORDER, checkmark in ARTWORK: 3.3.5 has no draw sublevels, so only the
-- layer puts the checkmark over its box.
local function skinButton(button)
	if button.foreverCell then
		return
	end

	local checkbox = button:CreateTexture(nil, "BORDER")
	if not ForeverUI.SetAtlas(checkbox, CHECKBOX_ATLAS, true) then
		checkbox:Hide()
	end
	checkbox:SetWidth(CHECKBOX)
	checkbox:SetHeight(CHECKBOX)
	checkbox:SetPoint("LEFT", button, "LEFT", 0, 0)
	checkbox:Hide()
	button.foreverCell = checkbox

	local checkMark = _G[button:GetName() .. "Check"]
	if checkMark then
		ForeverUI.SetAtlas(checkMark, CHECKMARK_ATLAS, true)
		checkMark:SetWidth(CHECKMARK_W)
		checkMark:SetHeight(CHECKMARK_H)
		checkMark:ClearAllPoints()
		checkMark:SetPoint("CENTER", checkbox, "CENTER", CHECKMARK_X, CHECKMARK_Y)
	end
end

-- Restores the style 1 checkmark after a style 2 list changed it
local function checkMarkStyle1(button)
	if not button.foreverStyle2 then
		return
	end
	button.foreverStyle2 = nil
	if button.foreverCircle then
		button.foreverCircle:Hide()
	end
	local checkMark = _G[button:GetName() .. "Check"]
	if checkMark and button.foreverCell then
		ForeverUI.SetAtlas(checkMark, CHECKMARK_ATLAS, true)
		checkMark:SetWidth(CHECKMARK_W)
		checkMark:SetHeight(CHECKMARK_H)
		checkMark:ClearAllPoints()
		checkMark:SetPoint("CENTER", button.foreverCell, "CENTER", CHECKMARK_X, CHECKMARK_Y)
	end
end

-- A style 2 row: the circle under the client's checkmark (which becomes the yellow dot),
-- text on its right, the style 1 box hidden
local function style2Row(list, button, info)
	local Tpl = ForeverUI.Templates
	local m = STYLE2.margins
	local i = button:GetID()
	if not button.foreverCircle then
		button.foreverCircle = button:CreateTexture(nil, "BORDER")
		Tpl.Place(button.foreverCircle, STYLE2.circle, true)
		button.foreverCircle:SetPoint("LEFT", button, "LEFT", -3, 0)
	end
	button.foreverStyle2 = true
	if button.foreverCell then
		button.foreverCell:Hide()
	end
	local checkMark = _G[button:GetName() .. "Check"]
	if checkMark then
		Tpl.Place(checkMark, STYLE2.point, true)
		checkMark:ClearAllPoints()
		checkMark:SetPoint("TOPLEFT", button.foreverCircle, "TOPLEFT")
	end
	button:SetHeight(ROW_HEIGHT)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", list, "TOPLEFT", m[1], -(m[2] + (i - 1) * ROW_HEIGHT))
	button:SetNormalFontObject(GameFontHighlightSmallLeft)
	button:SetHighlightFontObject(GameFontHighlightSmallLeft)
	if button.SetDisabledFontObject then
		if info and info.isTitle then
			button:SetDisabledFontObject(GameFontNormalSmallLeft)
		elseif info and info.notClickable then
			button:SetDisabledFontObject(GameFontHighlightSmallLeft)
		else
			button:SetDisabledFontObject(GameFontDisableSmallLeft)
		end
	end
	local raw = button:GetText()
	local clean = Tpl.Utf8Text(raw)
	if clean ~= raw then
		button:SetText(clean)
	end
	local text = _G[button:GetName() .. "NormalText"]
	local checkable = not (info and info.notCheckable)
	if checkable then
		button.foreverCircle:Show()
	else
		button.foreverCircle:Hide()
	end
	if text then
		text:ClearAllPoints()
		if checkable then
			text:SetPoint("LEFT", button.foreverCircle, "RIGHT", 1, 0)
		elseif info and info.justifyH == "CENTER" then
			text:SetPoint("CENTER", button, "CENTER", 0, 0)
		else
			text:SetPoint("LEFT", button, "LEFT", 0, 0)
		end
		-- Row extent (MeasureFrameExtents + padding of 20)
		local e = (checkable and STYLE2.span or STYLE2.noRadio) + (text:GetStringWidth() or 0)
		if i == 1 or e > (list.foreverContent2 or 0) then
			list.foreverContent2 = e
		end
	end
	list:SetHeight(m[2] + (list.numButtons or i) * ROW_HEIGHT + m[4])
end

-- The two backgrounds of a list: style 1 (slices) or style 2, by the menu it serves
local function applyListBackgrounds(list, isStyle2)
	list.foreverStyle2 = isStyle2 and true or nil
	if isStyle2 and not list.foreverBackground2 then
		local Tpl = ForeverUI.Templates
		local f = Tpl.StretchedAtlas(list, STYLE2.background, "BACKGROUND")
		f.rect:SetPoint("TOPLEFT", list, "TOPLEFT", STYLE2.backgroundA[1], STYLE2.backgroundA[2])
		f.rect:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", STYLE2.backgroundB[1], STYLE2.backgroundB[2])
		list.foreverBackground2 = f
	end
	if list.foreverBackground2 then
		list.foreverBackground2:SetShown(isStyle2)
	end
	for _, slice in ipairs(list.foreverSlices or {}) do
		if isStyle2 then slice:Hide() else slice:Show() end
	end
end

-- Redone for every row added: UIDropDownMenu_AddButton resets the font to
-- GameFontHighlightSmallLeft each time, and sets whether the row has a checkbox
-- (info.notCheckable).
local function adjustButton(button)
	checkMarkStyle1(button)
	button:SetHeight(ROW_HEIGHT)
	if GameFontHighlightLeft then
		button:SetNormalFontObject(GameFontHighlightLeft)
		button:SetHighlightFontObject(GameFontHighlightLeft)
	end

	if button.foreverCell then
		if button.notCheckable then
			button.foreverCell:Hide()
		else
			button.foreverCell:Show()
		end
	end
end

-- Row spacing follows row height. The client reads UIDROPDOWNMENU_BUTTON_HEIGHT for each
-- row, the list height and the dropdown height (UIDropDownMenu_InitializeHelper), but
-- writing that global from the addon would taint every client menu, including the
-- protected actions of a player's right-click menu. So the client lays rows at 16 and
-- we move them to 20 right after it.
local BORDER = UIDROPDOWNMENU_BORDER_HEIGHT or 15

local function relayoutRow(list, button)
	local point, relativeTo, relativePoint, x = button:GetPoint(1)
	if point then
		button:ClearAllPoints()
		button:SetPoint(point, relativeTo, relativePoint, x,
			-((button:GetID() - 1) * ROW_HEIGHT) - BORDER)
	end
	list:SetHeight(((list.numButtons or 1) * ROW_HEIGHT) + (BORDER * 2))
end

if hooksecurefunc and type(UIDropDownMenu_InitializeHelper) == "function" then
	hooksecurefunc("UIDropDownMenu_InitializeHelper", function(frame)
		if frame and frame.SetHeight then
			frame:SetHeight(ROW_HEIGHT * 2)
		end
	end)
end

if hooksecurefunc and type(UIDropDownMenu_AddButton) == "function" then
	hooksecurefunc("UIDropDownMenu_AddButton", function(info, level)
		level = level or 1
		local list = _G["DropDownList" .. level]
		if not list then
			return
		end

		list.foreverLevel = level
		skinList(list)

		local isStyle2 = style2(currentMenu())
		applyListBackgrounds(list, isStyle2)
		local button = _G[list:GetName() .. "Button" .. (list.numButtons or 1)]
		if button then
			skinButton(button)
			if isStyle2 then
				style2Row(list, button, info)
			else
				relayoutRow(list, button)
				adjustButton(button)
				measureButton(list, button, info)
			end
		end
	end)
end

-- Style 2: after ToggleDropDownMenu, put the list under camelot's button (even when the
-- client anchors it elsewhere) at its width, and repaint the button (arrow, open state)
-- with foreverPaint, set by Settings.lua
if hooksecurefunc and type(ToggleDropDownMenu) == "function" then
	hooksecurefunc("ToggleDropDownMenu", function(level)
		level = level or 1
		local list = _G["DropDownList" .. level]
		local opener = UIDROPDOWNMENU_OPEN_MENU
		if not (list and style2(opener)) then
			return
		end
		if list:IsShown() then
			fitWidth(list)
			if level == 1 and opener.foreverButton and opener.displayMode ~= "MENU" then
				list:ClearAllPoints()
				list:SetPoint("TOPLEFT", opener.foreverButton, "BOTTOMLEFT", 0, 0)
			end
		end
		if opener.foreverPaint then
			opener.foreverPaint()
		end
	end)
end

-- The button arrow goes back to rest when the list closes
for level = 1, (UIDROPDOWNMENU_MAXLEVELS or 2) do
	local list = _G["DropDownList" .. level]
	if list and list.HookScript then
		list:HookScript("OnHide", function()
			local opener = UIDROPDOWNMENU_OPEN_MENU
			if style2(opener) and opener.foreverPaint then
				opener.foreverPaint()
			end
		end)
	end
end

-- UIDropDownMenu_Refresh resizes the list on its text (maxWidth + 25), erasing the wanted
-- width: set it again after it.
if hooksecurefunc and type(UIDropDownMenu_Refresh) == "function" then
	hooksecurefunc("UIDropDownMenu_Refresh", function(frame, value, level)
		local list = _G["DropDownList" .. (level or UIDROPDOWNMENU_MENU_LEVEL or 1)]
		if list and list:IsShown() then
			fitWidth(list)
		end
	end)
end

ForeverUI.DropDown = {
	Skin = skinList,
	SkinButton = skinButton,
	Refresh = adjustButton,
	Fit = fitWidth,
}

-- ------------------------------------------------------------ Unit menus
--
-- Our unit frames open the right-click menu through our own function (the "menu" of
-- their secure action), so the client builds the whole menu as addon code and blocks the
-- rows that call a protected function: SET_FOCUS, CLEAR_FOCUS, TARGET and PET_DISMISS
-- (UnitPopup.lua:1201-1384). Out of combat, a secure ForeverUI button covers each of these
-- rows and runs the action as a macro on the player's click. In combat no addon may place
-- or show a secure button, so these rows are grayed (UnitPopup_OnUpdate enables them
-- every frame, so they are disabled again). Only menus opened by our frames (M.open) are
-- touched: the client's own menus already work.

local M = {}
ForeverUI.UnitMenu = M
M.overlays = {}
M.grayedRows = {}

local HIGHLIGHT = "Interface" .. string.char(92) .. "QuestFrame" .. string.char(92) .. "UI-QuestTitleHighlight"

-- Full name, as UnitPopup_OnClick builds it (UnitPopup.lua:1169-1174)
local function fullName(menu)
	local name, server = menu.name, menu.server
	if name and server and (not menu.unit or not UnitIsSameServer("player", menu.unit)) then
		return name .. "-" .. server
	end
	return name
end

-- Secure action of each protected row
local PROTECTED = {
	SET_FOCUS = function(o, menu)
		if not menu.unit then return false end
		o:SetAttribute("type", "focus")
		o:SetAttribute("unit", menu.unit)
	end,
	CLEAR_FOCUS = function(o)
		o:SetAttribute("type", "macro")
		o:SetAttribute("macrotext", "/clearfocus")
	end,
	TARGET = function(o, menu)
		local name = fullName(menu)
		if not name then return false end
		o:SetAttribute("type", "macro")
		o:SetAttribute("macrotext", "/targetexact " .. name)
	end,
	PET_DISMISS = function(o)
		o:SetAttribute("type", "macro")
		o:SetAttribute("macrotext", "/script PetDismiss()")
	end,
}
M.PROTECTED = PROTECTED

-- Secure overlay button k, created on first use
local function overlay(k)
	local o = M.overlays[k]
	if o then return o end
	o = CreateFrame("Button", "ForeverUIUnitMenuSecure" .. k, UIParent, "SecureActionButtonTemplate")
	o:RegisterForClicks("LeftButtonUp")
	o:SetHighlightTexture(HIGHLIGHT)
	local h = o:GetHighlightTexture()
	if h then h:SetBlendMode("ADD") end
	-- The list closes by itself when the mouse leaves its rows: keep it open over the
	-- overlay as over a row
	o:SetScript("OnEnter", function() UIDropDownMenu_StopCounting(DropDownList1) end)
	o:SetScript("OnLeave", function() UIDropDownMenu_StartCounting(DropDownList1) end)
	o:SetScript("PostClick", function() CloseDropDownMenus() end)
	o:Hide()
	M.overlays[k] = o
	return o
end

-- Out of combat only: a secure button cannot be touched under lockdown
function M.hide()
	if InCombatLockdown() then return end
	for _, o in ipairs(M.overlays) do
		o:Hide()
		o:ClearAllPoints()
	end
end

local function grayOut(row)
	row:Disable()
	table.insert(M.grayedRows, row)
end

-- After UnitPopup_ShowMenu, on the first list: cover or gray the protected rows.
-- menu: the unit menu frame given to UnitPopup_ShowMenu
function M.place(menu)
	M.hide()
	table.wipe(M.grayedRows)
	local list = DropDownList1
	local combat = InCombatLockdown()
	local k = 0
	for i = 1, (list.numButtons or 0) do
		local row = _G["DropDownList1Button" .. i]
		local configure = row and PROTECTED[row.value]
		if configure then
			if combat then
				grayOut(row)
			else
				local o = overlay(k + 1)
				if configure(o, menu) ~= false then
					k = k + 1
					o:ClearAllPoints()
					o:SetAllPoints(row)
					-- DropDownList1 is toplevel and rises to the top of its strata when shown:
					-- the TOOLTIP strata stays above it (as in SocialRaid.lua)
					o:SetFrameStrata("TOOLTIP")
					o:Show()
				end
			end
		end
	end
end

-- Opens a menu from one of our frames. fn: the client function that opens it;
-- ...: its arguments
function M.open(fn, ...)
	M.ownCall = true
	local ok, err = pcall(fn, ...)
	M.ownCall = false
	if not ok then error(err, 0) end
end

if hooksecurefunc and type(UnitPopup_ShowMenu) == "function" then
	hooksecurefunc("UnitPopup_ShowMenu", function(menu)
		if not M.ownCall or not menu or (UIDROPDOWNMENU_MENU_LEVEL or 1) ~= 1 then return end
		M.place(menu)
	end)
end
if hooksecurefunc and type(UnitPopup_OnUpdate) == "function" then
	hooksecurefunc("UnitPopup_OnUpdate", function()
		if #M.grayedRows == 0 or not DropDownList1:IsShown() then return end
		for _, row in ipairs(M.grayedRows) do
			if row:IsEnabled() == 1 then row:Disable() end
		end
	end)
end
if DropDownList1 then
	DropDownList1:HookScript("OnHide", function()
		M.hide()
		table.wipe(M.grayedRows)
	end)
end

-- On entering combat, before the lockdown: overlays go away and their rows are grayed
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:SetScript("OnEvent", function()
	local placedCount = false
	for _, o in ipairs(M.overlays) do
		if o:IsShown() then placedCount = true end
		o:Hide()
		o:ClearAllPoints()
	end
	if placedCount and DropDownList1:IsShown() then
		for i = 1, (DropDownList1.numButtons or 0) do
			local row = _G["DropDownList1Button" .. i]
			if row and PROTECTED[row.value] then grayOut(row) end
		end
	end
end)
M.watcher = watcher
