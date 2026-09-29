-- Icon picker of equipment sets (GearManagerDialogPopup) in the layout of camelot
-- IconSelectorPopupFrameTemplate (SharedUIPanelTemplates.xml) and ScrollBoxSelectorMixin.
-- The client fills a grid of 5 per row through the NUM_GEARSET_ICON* globals. Writing them
-- from the addon would taint every client function that reads them, so the client fills its
-- grid and we redo it after it in rows of 10 (populate, realign).

ForeverUI = ForeverUI or {}
local L = ForeverUI.L

-- Positions from camelot IconSelectorPopupFrameTemplate. The window takes the character
-- sheet's height instead of camelot's 495; from the grid (-97) to the button base, seven
-- rows fit.
local POPUP_W, POPUP_H = 525, 484
local HEADER_X, HEADER_Y = 24, -21
local FIELD_X, FIELD_Y = 29, -35
local CHOOSE_X, CHOOSE_Y = 24, -79

local ZONE_W, ZONE_H = 275, 45
local ZONE_X, ZONE_Y = -13, -13
local CHOICE_ICON = 36
local CHOICE_X, CHOICE_Y = -4.5, -3.5

-- camelot ScrollBoxSelectorMixin: stride 10, button 36, padding 5, spacing 10
local GRID_X, GRID_Y = 21, -97
local ICON = 36
local PER_ROW = 10
local ROWS = 7
local GAP = 10
local MARGIN = 5
local STEP = ICON + GAP

-- camelot SelectionFrameTemplate buttons: Cancel 78 x 22 at BOTTOMRIGHT (-11, 13), Okay at
-- its left (x = -2). They fall exactly in the two slots of the bottom right corner art.
local BOTTOM_BUTTON_W, BOTTOM_BUTTON_H = 78, 22
local BOTTOM_BUTTON_X, BOTTOM_BUTTON_Y = -11, 13
local BOTTOM_BUTTON_GAP = -2
local RIGHT_EDGE = 17                   -- width of !macropopup-right

-- Skin sizes (background, frame, bar). Declared here because placeWindow uses them to
-- center the bar in the remaining space.
local BACKGROUND_ALPHA = 0.8
local BACKGROUND_MARGIN = 7
local BAR_W = 8
local ARROW_W, ARROW_H = 17, 11
local CURSOR_H = 36                    -- minimal-scrollbar-thumb-bottom

local built = false

local SHOWN_COUNT = PER_ROW * ROWS

-- Creates the missing buttons on the client's template (the client makes only fifteen, at
-- load), then lays out the whole grid in rows of ten.
local function layoutGrid(popup)
	for index = #popup.buttons + 1, SHOWN_COUNT do
		local button = CreateFrame("CheckButton",
			"GearManagerDialogPopupButton" .. index, popup,
			"GearSetPopupButtonTemplate")
		button:SetID(index)
		table.insert(popup.buttons, button)
	end

	for index, button in ipairs(popup.buttons) do
		button:SetWidth(ICON)
		button:SetHeight(ICON)
		button:ClearAllPoints()
		if index == 1 then
			button:SetPoint("TOPLEFT", popup, "TOPLEFT",
				GRID_X + MARGIN, GRID_Y - MARGIN)
		elseif math.fmod(index - 1, PER_ROW) == 0 then
			button:SetPoint("TOPLEFT", popup.buttons[index - PER_ROW],
				"BOTTOMLEFT", 0, -GAP)
		else
			button:SetPoint("TOPLEFT", popup.buttons[index - 1], "TOPRIGHT",
				GAP, 0)
		end
	end
end

-- Current choice zone. camelot shows the selected icon and a click scrolls the list to it;
-- 3.3.5 does this jump with RecalculateGearManagerDialogPopup.
local function placeCurrentChoice(popup)
	if popup.foreverChoice then
		return
	end

	local zone = CreateFrame("Frame", "ForeverUIIconChoice", popup)
	zone:SetWidth(ZONE_W)
	zone:SetHeight(ZONE_H)
	zone:SetPoint("TOPRIGHT", popup, "TOPRIGHT", ZONE_X, ZONE_Y)

	local button = CreateFrame("Button", "ForeverUIIconChoiceButton", zone)
	button:SetWidth(CHOICE_ICON)
	button:SetHeight(CHOICE_ICON)
	button:SetPoint("TOPRIGHT", zone, "TOPRIGHT", CHOICE_X, CHOICE_Y)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	button.icon = icon

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(button)

	-- From the text table: ICON_SELECTION_TITLE_CURRENT and its description are missing from
	-- this client.
	local title = zone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPRIGHT", button, "TOPLEFT", -6, -2)
	title:SetText(L.ICONPICKER_CURRENTLY_SELECTED)

	local help = zone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	help:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -2)
	help:SetText(L.ICONPICKER_CLICK_TO_VIEW)

	button:SetScript("OnClick", function()
		if RecalculateGearManagerDialogPopup then
			RecalculateGearManagerDialogPopup()
		end
	end)

	popup.foreverChoice = button
	popup.foreverZone = zone
end

-- The icon shown in the zone follows the client's selection.
local function updateCurrentChoice()
	local popup = _G["GearManagerDialogPopup"]
	if not popup or not popup.foreverChoice then
		return
	end

	local texture = popup.selectedTexture
	if not texture and popup.selectedIcon and GetEquipmentSetIconInfo then
		texture = GetEquipmentSetIconInfo(popup.selectedIcon)
	end
	popup.foreverChoice.icon:SetTexture(texture or "")
end

-- Sizes the window and places the client's name field, labels, scroll frame and buttons
local function placeWindow(popup)
	local sheet = _G["CharacterFrame"]
	popup:SetWidth(POPUP_W)
	popup:SetHeight((sheet and sheet:GetHeight()) or POPUP_H)

	local field = _G["GearManagerDialogPopupEditBox"]
	if field then
		field:ClearAllPoints()
		field:SetPoint("TOPLEFT", popup, "TOPLEFT", FIELD_X, FIELD_Y)
	end

	-- The two client labels are unnamed regions, found by their text (GEARSETS_POPUP_TEXT and
	-- MACRO_POPUP_CHOOSE_ICON).
	local regions = { popup:GetRegions() }
	for _, region in ipairs(regions) do
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			local text = region:GetText()
			region:ClearAllPoints()
			if text == MACRO_POPUP_CHOOSE_ICON then
				region:SetPoint("TOPLEFT", popup, "TOPLEFT", CHOOSE_X, CHOOSE_Y)
			else
				region:SetPoint("TOPLEFT", popup, "TOPLEFT", HEADER_X, HEADER_Y)
			end
		end
	end

	local scrolling = _G["GearManagerDialogPopupScrollFrame"]
	if scrolling then
		scrolling:SetWidth(PER_ROW * STEP - GAP + 2 * MARGIN)
		scrolling:SetHeight(ROWS * STEP - GAP + 2 * MARGIN)
		scrolling:ClearAllPoints()
		scrolling:SetPoint("TOPLEFT", popup, "TOPLEFT", GRID_X, GRID_Y)
	end

	-- Same space on both sides of the bar: between the last icon column and the bar, and
	-- between the bar and the window edge. It is computed, so it follows the grid and window.
	local bar = _G["GearManagerDialogPopupScrollFrameScrollBar"]
	if bar then
		local iconsRight = GRID_X + MARGIN + PER_ROW * STEP - GAP
		local free = (POPUP_W - RIGHT_EDGE) - iconsRight
		local gap = (free - BAR_W) / 2
		bar:ClearAllPoints()
		bar:SetPoint("TOPRIGHT", popup, "TOPRIGHT",
			-(RIGHT_EDGE + gap), GRID_Y - MARGIN)
		bar:SetPoint("BOTTOMRIGHT", popup, "TOPRIGHT",
			-(RIGHT_EDGE + gap), GRID_Y - MARGIN - (ROWS * STEP - GAP))
	end

	local okay = _G["GearManagerDialogPopupOkay"]
	local cancel = _G["GearManagerDialogPopupCancel"]
	if cancel then
		cancel:SetWidth(BOTTOM_BUTTON_W)
		cancel:SetHeight(BOTTOM_BUTTON_H)
		cancel:ClearAllPoints()
		cancel:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT",
			BOTTOM_BUTTON_X, BOTTOM_BUTTON_Y)
	end
	if okay and cancel then
		okay:SetWidth(BOTTOM_BUTTON_W)
		okay:SetHeight(BOTTOM_BUTTON_H)
		okay:ClearAllPoints()
		okay:SetPoint("RIGHT", cancel, "LEFT", BOTTOM_BUTTON_GAP, 0)
	end
end

-- ------------------------------------------------------------ filling

-- Equipped items with an icon, like RefreshEquipmentSetIconInfo
local function countEquippedItems()
	local n = 0
	for i = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		if GetInventoryItemTexture("player", i) then n = n + 1 end
	end
	return n
end

-- The client's count (_TotalItems): items, macro icons, and the special icon when
-- RecalculateGearManagerDialogPopup has set one
local function tally()
	local base = countEquippedItems() + GetNumMacroIcons()
	if GetEquipmentSetIconInfo(base + 1) then
		base = base + 1
	end
	return base
end

local inProgress = false

-- After GearManagerDialogPopup_Update: refill as a grid of ten. Each button's ID is set so
-- that GearSetPopupButton_OnClick (offset x 5 + ID) lands on the icon it shows. Scrolling
-- counts rows of ten with the client's GEARSET_ICON_ROW_HEIGHT (read only).
local function populate()
	local popup = _G["GearManagerDialogPopup"]
	local scrolling = _G["GearManagerDialogPopupScrollFrame"]
	if inProgress or not (built and popup and scrolling and popup.buttons) then
		return
	end
	inProgress = true
	local offset = FauxScrollFrame_GetOffset(scrolling) or 0
	local total = tally()
	local clientPerRow = NUM_GEARSET_ICONS_PER_ROW or 5
	for i, button in ipairs(popup.buttons) do
		local index = offset * PER_ROW + i
		button:SetID(offset * (PER_ROW - clientPerRow) + i)
		if i <= SHOWN_COUNT and index <= total then
			local texture = GetEquipmentSetIconInfo(index)
			button.icon:SetTexture(texture)
			button:Show()
			if index == popup.selectedIcon then
				button:SetChecked(1)
			elseif texture and texture == popup.selectedTexture then
				button:SetChecked(1)
				popup:SetSelection(false, index)
			else
				button:SetChecked(nil)
			end
		else
			button.icon:SetTexture("")
			button:Hide()
		end
	end
	FauxScrollFrame_Update(scrolling, math.ceil(total / PER_ROW), ROWS, GEARSET_ICON_ROW_HEIGHT)
	inProgress = false
end

-- After RecalculateGearManagerDialogPopup: scroll the selected icon into view with the
-- client's rule (at least ROWS rows shown, no move if it is on the first page)
local function realign()
	local popup = _G["GearManagerDialogPopup"]
	local scrolling = _G["GearManagerDialogPopupScrollFrame"]
	if not (built and popup and scrolling) then
		return
	end
	local total = tally()
	local match = popup.selectedIcon
	if not match and popup.selectedTexture then
		for index = 1, total do
			if GetEquipmentSetIconInfo(index) == popup.selectedTexture then
				match = index
				break
			end
		end
	end
	if match then
		local last = math.floor((total - 1) / PER_ROW)
		local rowLine = math.floor((match - 1) / PER_ROW)
		rowLine = rowLine + math.min(ROWS - 1, last - rowLine) - (ROWS - 1)
		if match <= SHOWN_COUNT then
			rowLine = 0
		end
		FauxScrollFrame_OnVerticalScroll(scrolling, rowLine * GEARSET_ICON_ROW_HEIGHT, GEARSET_ICON_ROW_HEIGHT, nil)
	end
	populate()
end

-- Builds the grid and choice zone once, then applies the skin; skipped in combat
local function applySkin()
	local popup = _G["GearManagerDialogPopup"]
	if not popup or not popup.buttons or InCombatLockdown() then
		return
	end

	if not built then
		layoutGrid(popup)
		placeCurrentChoice(popup)
		placeWindow(popup)
		built = true
	end

	if ForeverUI.IconPickerSkin then
		ForeverUI.IconPickerSkin()
	end
	updateCurrentChoice()
end

ForeverUI.IconPicker = { Apply = applySkin }

-- ============================================================ skin
--
-- camelot: black background at 80 %, inset 7; SelectionFrameTemplate frame, a nine-slice
-- of macropopup-* atlases (the bottom right corner is 174 wide: it holds the button base);
-- MinimalScrollBar, 8 wide, three-piece track and thumb, 17 x 11 arrows.

-- Replaces the 3.3.5 window art with the camelot background and frame
local function skinFrame(popup)
	if popup.foreverFrame then
		return
	end

	-- Hide the 3.3.5 window art.
	local regions = { popup:GetRegions() }
	for _, region in ipairs(regions) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end

	local background = popup:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(0, 0, 0, BACKGROUND_ALPHA)
	background:SetPoint("TOPLEFT", popup, "TOPLEFT", BACKGROUND_MARGIN, -BACKGROUND_MARGIN)
	background:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -BACKGROUND_MARGIN, BACKGROUND_MARGIN)

	local function piece(atlas, point)
		local t = popup:CreateTexture(nil, "BORDER")
		if not ForeverUI.SetAtlas(t, atlas) then
			t:Hide()
		end
		if point then
			t:SetPoint(point, popup, point, 0, 0)
		end
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
	-- Side strips keep their atlas width: anchoring them by opposite corners would stretch them
	-- to the next corner, and the bottom right corner is 174 wide. Two points on the same side
	-- are enough.
	local left = piece("!macropopup-left-c60")
	left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
	left:SetPoint("BOTTOMLEFT", bottomLeft, "TOPLEFT")
	local right = piece("!macropopup-right-c60")
	right:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT")
	right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")

	popup.foreverFrame = { topLeft, topRight, bottomLeft, bottomRight, top, down, left, right }
	popup.foreverBackground = background
end

-- Scroll bar: the FauxScrollFrame bar keeps its behavior; only its textures change.
local function skinBar()
	local bar = _G["GearManagerDialogPopupScrollFrameScrollBar"]
	if not bar or bar.foreverBar then
		return
	end

	-- The bar's old trim is not on the bar: the client's scroll frame holds two 30-wide
	-- textures (the track outline), so hide them too.
	local frame = _G["GearManagerDialogPopupScrollFrame"]
	if frame then
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetObjectType and region:GetObjectType() == "Texture" then
				region:SetAlpha(0)
			end
		end
	end

	bar:SetWidth(BAR_W)

	-- The thumb is a region of the bar: keep it out of this loop, or it stays invisible after
	-- being retextured.
	local cursor = _G["GearManagerDialogPopupScrollFrameScrollBarThumbTexture"]
	for _, region in ipairs({ bar:GetRegions() }) do
		if region ~= cursor and region.GetObjectType
			and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end

	local function slice(atlas, layer)
		local t = bar:CreateTexture(nil, layer or "BACKGROUND")
		if not ForeverUI.SetAtlas(t, atlas) then
			t:Hide()
		end
		t:SetWidth(BAR_W)
		return t
	end

	local trackTop = slice("minimal-scrollbar-track-top-c60")
	trackTop:SetPoint("TOP", bar, "TOP", 0, 0)
	local bottomLeft = slice("minimal-scrollbar-track-bottom-c60")
	bottomLeft:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
	local trackMiddle = slice("!minimal-scrollbar-track-middle-c60")
	trackMiddle:SetPoint("TOPLEFT", trackTop, "BOTTOMLEFT")
	trackMiddle:SetPoint("BOTTOMRIGHT", bottomLeft, "TOPRIGHT")

	-- The client has one thumb texture where camelot has three: use the stretchable middle
	-- piece at the size of camelot's shortest thumb (8 x 36).
	if cursor then
		ForeverUI.SetAtlas(cursor, "minimal-scrollbar-thumb-middle-c60", true)
		cursor:SetWidth(BAR_W)
		cursor:SetHeight(CURSOR_H)
		cursor:SetAlpha(1)
	end

	for name, atlas in pairs({
		["GearManagerDialogPopupScrollFrameScrollBarScrollUpButton"] =
			"minimal-scrollbar-arrow-top-c60",
		["GearManagerDialogPopupScrollFrameScrollBarScrollDownButton"] =
			"minimal-scrollbar-arrow-bottom-c60",
	}) do
		local button = _G[name]
		if button then
			button:SetWidth(ARROW_W)
			button:SetHeight(ARROW_H)
			for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture",
				"GetDisabledTexture", "GetHighlightTexture" }) do
				local texture = button[method] and button[method](button)
				if texture then
					texture:SetAlpha(0)
				end
			end
			local arrow = button:CreateTexture(nil, "ARTWORK")
			ForeverUI.SetAtlas(arrow, atlas)
			arrow:SetPoint("CENTER", button, "CENTER", 0, 0)
		end
	end

	bar.foreverBar = true
end

-- Right of the character sheet: camelot anchors its TOPLEFT to the TOPRIGHT of the frame it
-- accompanies. The 3.3.5 anchor, the gear manager, is no longer a window here.
local function placeBeside(popup)
	local sheet = _G["CharacterFrame"]
	if not sheet then
		return
	end
	popup:ClearAllPoints()
	popup:SetPoint("TOPLEFT", sheet, "TOPRIGHT", 0, 0)
end

ForeverUI.IconPickerSkin = function()
	local popup = _G["GearManagerDialogPopup"]
	if not popup then
		return
	end
	skinFrame(popup)
	skinBar()
	placeBeside(popup)
end

-- Run at load, and last: the client fills its grid on first open and needs its eighty
-- buttons then; IconPickerSkin must already be defined when this runs.
applySkin()

if hooksecurefunc then
	for _, name in ipairs({ "GearManagerDialogPopup_OnShow", "GearManagerDialogPopup_Update" }) do
		if type(_G[name]) == "function" then
			hooksecurefunc(name, function() applySkin() end)
		end
	end
	if type(GearManagerDialogPopup_Update) == "function" then
		hooksecurefunc("GearManagerDialogPopup_Update", populate)
	end
	if type(RecalculateGearManagerDialogPopup) == "function" then
		hooksecurefunc("RecalculateGearManagerDialogPopup", realign)
	end
end
