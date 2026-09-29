-- Currencies tab of the character sheet, after camelot's Blizzard_TokenUI: a list on the
-- left pane and a detail on the right pane (name, icon, count, the client's two checkboxes).
-- 3.3.5 has no sub-headers, description, cap or weekly quota: GetCurrencyListInfo returns only
-- name, isHeader, expanded, unused, isTracked, count, specialType, icon and itemID.
-- No scroll bar (the mouse wheel scrolls), so the list's right edge is at -10, not -25.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local L = ForeverUI.L

local LIST_X, LIST_Y = 10, -40
local LIST_X2, LIST_Y2 = -LIST_X, 15

local ENTRY_H = 22                     -- TokenEntryTemplate
local HEADER_H = 26                     -- TokenHeaderTemplate
local MARGIN = 10
local GAP = 3
local HEADER_INDENT = 0
local OTHER_INDENT = 2

local NAME_H = 11
local HEADER_NAME_H = 15
local HEADER_NAME_X = 10
local NAME_X = 2
local NAME_GAP = -10                   -- from the count's LEFT
local ICON = 20
local ICON_X = -20
local COUNT_X = -5
local CHECKMARK_W = 16
local CHECKMARK_X = -3
local ARROW_X, ARROW_Y = -8, -1
local ARROW_SPACE = 16
local SIDE = 6                          -- hover side slice width
local PLATE_CORNER = 12                  -- same as the reputation tab

local SELECTED_ALPHA = 0.20
local HOVER_ALPHA = 0.10

local ATLAS_HEADER = "common-button-list-collapseexpand"
local ATLAS_PLUS = "common-button-list-plus"
local ATLAS_MINUS = "common-button-list-minus"
local ATLAS_LINE = "ui-character-info-scrollline-long"
local ATLAS_HOVER_SIDE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_HOVER_MIDDLE = "charactercreate-customize-dropdown-linemouseover-middle"

local CHECKMARK_PATH = "Interface\\Buttons\\UI-CheckBox-Check"
local ARENA_PATH = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
local HONOR_PATH = "Interface\\TargetingFrame\\UI-PVP-%s"
local HONOR_CORNER = 0.03125
local HONOR_SIDE = 0.59375

-- Pane size by construction: content is built on first open, which can come before the
-- window is laid out, when GetHeight still returns 0. Same guard as the reputation tab.
local PANE_W, PANE_H = 398, 464

local rows = {}
local panel, offset = nil, 0
local visibleCount = 0
local selectedItem

-- Forward declarations: layoutList, written above clampToPane, calls it on every pass;
-- without them these names would resolve to globals, i.e. nil.
local leftHost
local clampToPane

-- ---------------------------------------------------------------- Data

-- Currency list row rank as a table, or nil
local function readCurrency(rank)
	if not GetCurrencyListInfo then
		return nil
	end
	local name, isHeader, expanded, unused, isTracked, count, special, icon,
		object = GetCurrencyListInfo(rank)
	if not name or name == "" then
		return nil
	end
	return {
		index = rank,
		name = name,
		header = isHeader and true or false,
		expanded = expanded and true or false,
		unused = unused and true or false,
		isTracked = isTracked and true or false,
		count = count or 0,
		special = special,
		icon = icon,
		object = object,
	}
end

-- Currency icon. Arena and honor points have their own, hardcoded in the client.
local function placeIcon(texture, data)
	if data.special == 1 then
		texture:SetTexture(ARENA_PATH)
		texture:SetTexCoord(0, 1, 0, 1)
	elseif data.special == 2 then
		local faction = UnitFactionGroup and UnitFactionGroup("player")
		if faction then
			texture:SetTexture(string.format(HONOR_PATH, faction))
			texture:SetTexCoord(HONOR_CORNER, HONOR_SIDE, HONOR_CORNER, HONOR_SIDE)
		else
			texture:SetTexture("")
			texture:SetTexCoord(0, 1, 0, 1)
		end
	else
		texture:SetTexture(data.icon or "")
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

local function heightOf(data)
	return data.header and HEADER_H or ENTRY_H
end

local function indentOf(data)
	return data.header and HEADER_INDENT or OTHER_INDENT
end

-- ----------------------------------------------------------------- Row

local function createRow(index, width)
	local row = CreateFrame("Button", "ForeverUITokenRow" .. index, panel)
	row:SetWidth(width)
	row:SetHeight(ENTRY_H)

	-- Header background in nine slices: only the middle ones stretch.
	row.plate = ForeverUI.CreateNineSlice(row, ATLAS_HEADER, PLATE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	for _, slice in ipairs(row.plate) do
		slice:Hide()
	end

	-- Entry hover: three slices, sides 6 wide.
	local hover = CreateFrame("Frame", nil, row)
	hover:SetAllPoints(row)
	hover:SetAlpha(0)
	row.hover = hover

	local left = hover:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(left, ATLAS_HOVER_SIDE, true)
	left:SetWidth(SIDE)
	left:SetPoint("TOPLEFT", hover, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", hover, "BOTTOMLEFT", 0, 0)

	local right = hover:CreateTexture(nil, "BACKGROUND")
	if ForeverUI.SetAtlas(right, ATLAS_HOVER_SIDE, true) then
		-- Flipped as in the source: TexCoords left = 1, right = 0.
		local e = ForeverUI.AtlasEntry(ATLAS_HOVER_SIDE)
		right:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	right:SetWidth(SIDE)
	right:SetPoint("TOPRIGHT", hover, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", hover, "BOTTOMRIGHT", 0, 0)

	local middle = hover:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(middle, ATLAS_HOVER_MIDDLE, true)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

	row.hoverPieces = { left, right, middle }

	-- Check mark of a tracked currency, far right.
	local checkMark = row:CreateTexture(nil, "OVERLAY")
	checkMark:SetTexture(CHECKMARK_PATH)
	checkMark:SetWidth(CHECKMARK_W)
	checkMark:SetHeight(CHECKMARK_W)
	checkMark:SetPoint("RIGHT", row, "RIGHT", CHECKMARK_X, 0)
	checkMark:Hide()
	row.checkMark = checkMark

	local icon = row:CreateTexture(nil, "BORDER")
	icon:SetWidth(ICON)
	icon:SetHeight(ICON)
	icon:SetPoint("RIGHT", row, "RIGHT", ICON_X, 0)
	row.icon = icon

	local count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightRight")
	count:SetJustifyH("RIGHT")
	count:SetPoint("RIGHT", icon, "LEFT", COUNT_X, 0)
	row.count = count

	-- Name: its two anchors depend on the template, so they are set on each fill.
	local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
	name:SetJustifyH("LEFT")
	row.name = name

	-- Header arrow on the right: StateIcon.
	local arrow = row:CreateTexture(nil, "OVERLAY")
	arrow:SetPoint("RIGHT", row, "RIGHT", ARROW_X, ARROW_Y)
	arrow:Hide()
	row.arrow = arrow

	row:RegisterForClicks("LeftButtonUp")
	return row
end

-- -------------------------------------------------------------- Display

-- Hover opacity from the template KeyValues: selected 0.20, hovered 0.10, idle 0.
local function placeHover(row)
	if row.header then
		row.hover:SetAlpha(0)
		return
	end
	local hovered = row:IsMouseOver()
	row.hover:SetAlpha((row.selectedItem and SELECTED_ALPHA)
		or (hovered and HOVER_ALPHA) or 0)
end

-- SetFontObject resets the justification, so set it again afterwards. GameFontHighlight has
-- no justifyH, i.e. CENTER (client FontStyles.xml), so the name would be centered and shift
-- as rows are reused. camelot also sets justifyH="LEFT" on top of the font object.
local function populateRow(row, data)
	row.currencyIndex = data.index
	row.currencyName = data.name
	row.header = data.header
	row.expanded = data.expanded
	row.isTracked = data.isTracked
	row.selectedItem = (not data.header) and (selectedItem == data.name) or false

	row:SetHeight(heightOf(data))

	row.name:ClearAllPoints()
	if data.header then
		for _, slice in ipairs(row.plate) do
			slice:Show()
		end
		row.icon:Hide()
		row.count:SetText("")
		row.checkMark:Hide()

		row.name:SetHeight(HEADER_NAME_H)
		row.name:SetFontObject(GameFontNormalLeft or "GameFontNormal")
		row.name:SetJustifyH("LEFT")
		row.name:SetPoint("LEFT", row, "LEFT", HEADER_NAME_X, 0)
		row.name:SetPoint("RIGHT", row, "RIGHT", -ARROW_SPACE, 0)
		row.name:SetText(data.name)

		ForeverUI.SetAtlas(row.arrow,
			data.expanded and ATLAS_MINUS or ATLAS_PLUS, false)
		row.arrow:Show()
	else
		for _, slice in ipairs(row.plate) do
			slice:Hide()
		end
		row.arrow:Hide()

		placeIcon(row.icon, data)
		row.icon:Show()
		row.count:SetText(data.count)

		-- A zero count is gray, as in the client.
		local font = (data.count == 0) and (GameFontDisable or "GameFontDisable")
			or (GameFontHighlight or "GameFontHighlight")
		row.count:SetFontObject(font)
		row.count:SetJustifyH("RIGHT")
		row.name:SetFontObject(font)
		row.name:SetJustifyH("LEFT")

		if data.isTracked then
			row.checkMark:Show()
		else
			row.checkMark:Hide()
		end

		row.name:SetHeight(NAME_H)
		row.name:SetPoint("LEFT", row, "LEFT", NAME_X, 0)
		row.name:SetPoint("RIGHT", row.count, "LEFT", NAME_GAP, 0)
		row.name:SetText(data.name)
	end

	placeHover(row)
	row:Show()
end

-- Hides the 3.3.5 art and rows on EVERY pass: TokenFrame_Update restores them whenever
-- a currency changes. Both regions and children go, except our panel.
local function suppressClientScreen()
	local frame = _G["TokenFrame"]
	if not frame then
		return
	end

	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.Hide then
			region:Hide()
		end
	end
	if frame.GetChildren then
		for _, childFrame in ipairs({ frame:GetChildren() }) do
			if childFrame ~= panel and childFrame.Hide then
				childFrame:Hide()
			end
		end
	end
end

-- One pass: stack rows from the offset down to the bottom margin, stopping at
-- GetCurrencyListSize like the client. Returns the number of rows placed.
local function layout()
	local total = (GetCurrencyListSize and GetCurrencyListSize()) or 0
	local usableHeight = (panel:GetHeight() or 0)
	if usableHeight < 50 then
		usableHeight = PANE_H + LIST_Y - LIST_Y2
	end
	local usableWidth = (panel:GetWidth() or 0)
	if usableWidth < 50 then
		usableWidth = PANE_W + LIST_X2 - LIST_X
	end

	local y = MARGIN
	local placedCount = 0
	for rank, row in ipairs(rows) do
		local index = offset + rank
		local data = (index <= total) and readCurrency(index) or nil
		local height = data and heightOf(data) or 0
		if data and y + height <= usableHeight - MARGIN then
			local indent = indentOf(data)
			row:SetWidth(usableWidth - 2 * MARGIN - indent)
			populateRow(row, data)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", MARGIN + indent, -y)
			y = y + height + GAP
			placedCount = placedCount + 1
		else
			row:Hide()
		end
	end
	return placedCount
end

local function layoutList()
	if not panel then
		return
	end

	clampToPane()
	suppressClientScreen()

	local total = (GetCurrencyListSize and GetCurrencyListSize()) or 0
	local placedCount = layout()

	-- Collapsing a category shortens the list: clamp the offset and lay out again if it moved.
	-- Same trap as the reputation tab.
	if offset > 0 and offset + placedCount > total then
		offset = math.max(0, total - placedCount)
		placedCount = layout()
	end

	visibleCount = placedCount

	if ForeverUI.TokensDetail then
		ForeverUI.TokensDetail()
	end
end
ForeverUI.TokensLayout = layoutList

-- ---------------------------------------------------------- Build

local function trackHover()
	for _, row in ipairs(rows) do
		if row:IsShown() and not row.header then
			placeHover(row)
		end
	end
end

-- Pins TokenFrame to the left pane. Blizzard_TokenUI registers it in UIPanelWindows, and
-- while registered, UpdateUIPanelPositions re-anchors it on UIParent, where the invisible
-- frame still catches the mouse and blocks the side tabs (as with the PvP frame). build
-- removes it from UIPanelWindows.
clampToPane = function()
	local frame = _G["TokenFrame"]
	if not frame or not leftHost then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", leftHost, "TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", leftHost, "BOTTOMRIGHT", 0, 0)
end

-- Builds the currency list in host, the character sheet's left pane
local function build(host)
	local frame = _G["TokenFrame"]
	if not frame or not host then
		return nil, {}
	end

	leftHost = host
	if UIPanelWindows then
		UIPanelWindows["TokenFrame"] = nil
	end
	clampToPane()

	if panel then
		return nil, { frame }
	end

	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end

	local height = host:GetHeight() or 0
	if height < 100 then
		height = PANE_H
	end
	local width = host:GetWidth() or 0
	if width < 100 then
		width = PANE_W
	end
	width = width + LIST_X2 - LIST_X

	panel = CreateFrame("Frame", "ForeverUITokenList", frame)
	panel:SetPoint("TOPLEFT", host, "TOPLEFT", LIST_X, LIST_Y)
	panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", LIST_X2, LIST_Y2)
	panel:SetWidth(width)

	-- Enough rows for the densest case (only entries, the shortest rows), since layoutList
	-- stops at the bottom margin.
	local position = math.floor((height + LIST_Y - LIST_Y2) / (ENTRY_H + GAP))
	if position < 1 then
		position = 1
	end
	for index = 1, position do
		local row = createRow(index, width)
		row:SetScript("OnClick", function(self)
			if not self.currencyIndex then
				return
			end
			if self.header then
				if ExpandCurrencyList then
					ExpandCurrencyList(self.currencyIndex, self.expanded and 0 or 1)
				end
				layoutList()
			else
				ForeverUI.TokensSelect(self.currencyName)
			end
		end)
		rows[index] = row
	end

	-- Both lines live on our panel: the client frame's regions are hidden on every pass
	-- and ours would go with them.
	local top = panel:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(top, ATLAS_LINE)
	top:SetPoint("CENTER", panel, "TOP", 0, 0)

	local down = panel:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(down, ATLAS_LINE)
	down:SetPoint("CENTER", panel, "BOTTOM", 0, 0)

	panel:SetScript("OnUpdate", trackHover)
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_self, direction)
		local total = (GetCurrencyListSize and GetCurrencyListSize()) or 0
		offset = math.max(0, math.min(offset - direction, total - visibleCount))
		layoutList()
	end)

	layoutList()
	return nil, { frame }
end

-- ------------------------------------------------------------ Right pane

local RIGHT_PANE_X, RIGHT_PANE_Y = 16, -14
local RIGHT_PANE_X2, RIGHT_PANE_Y2 = -12, 14
local TITLE_W = 195
local SUBTITLE_Y = -3
local SEPARATOR_Y = -4
local DETAIL_ICON = 16
local DETAIL_ICON_X = -4
local CHECKBOX = 26
local CHECKBOX_X, CHECKBOX_GAP = -4, -2
local CHECKBOX_LABEL_L = 158
local CHECKBOX_LABEL_X = 2

local ATLAS_CHECKBOX = "checkbox-minimal"
local ATLAS_CHECKMARK = "checkmark-minimal"
local ATLAS_SEPARATOR = "ui-character-info-scrollline"

local detail

-- The client's two checkboxes, moved and reskinned. Their logic stays theirs: they call
-- SetCurrencyUnused and SetCurrencyBackpack on TokenFrame.selectedID, which we keep current.
local CHECKBOXES = {
	{ name = "TokenFramePopupInactiveCheckBox" },
	{ name = "TokenFramePopupBackpackCheckBox" },
}

local function skinCell(checkbox)
	if not checkbox or checkbox.foreverSkinDone then
		return
	end

	checkbox:SetWidth(CHECKBOX)
	checkbox:SetHeight(CHECKBOX)

	for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture",
		"GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
		local texture = checkbox[method] and checkbox[method](checkbox)
		if texture then
			texture:SetAlpha(0)
		end
	end

	local background = checkbox:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, ATLAS_CHECKBOX)
	background:SetPoint("CENTER", checkbox, "CENTER", 0, 0)

	local checkMark = checkbox:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(checkMark, ATLAS_CHECKMARK)
	checkMark:SetPoint("CENTER", checkbox, "CENTER", 0, 0)
	checkbox.foreverCheck = checkMark

	local label = _G[checkbox:GetName() .. "Text"]
	if label then
		label:ClearAllPoints()
		label:SetPoint("LEFT", checkbox, "RIGHT", CHECKBOX_LABEL_X, 0)
		label:SetWidth(CHECKBOX_LABEL_L)
		label:SetJustifyH("LEFT")
		if GameFontNormal then
			label:SetFontObject(GameFontNormal)
		end
	end

	checkbox.foreverSkinDone = true
end

-- Shows our check mark when the client checkbox is checked
local function syncCheckboxes()
	for _, desc in ipairs(CHECKBOXES) do
		local checkbox = _G[desc.name]
		if checkbox and checkbox.foreverCheck then
			if checkbox:GetChecked() then
				checkbox.foreverCheck:Show()
			else
				checkbox.foreverCheck:Hide()
			end
		end
	end
end

local function showCells(state)
	for _, desc in ipairs(CHECKBOXES) do
		local checkbox = _G[desc.name]
		if checkbox then
			if state then checkbox:Show() else checkbox:Hide() end
		end
	end
end

-- The detail follows the name, not the index: moving a currency to unused or collapsing its
-- category renumbers the list. The client does the same (TokenFrame.selectedToken is a name).
local function indexOf(name)
	if not name then
		return nil
	end
	for rank = 1, (GetCurrencyListSize and GetCurrencyListSize()) or 0 do
		local currency = readCurrency(rank)
		if currency and currency.name == name and not currency.header then
			return rank
		end
	end
	return nil
end

local function clearDetail()
	detail.title:SetText("")
	detail.subtitle:SetText("")
	detail.icon:Hide()
	detail.separator:Hide()
	showCells(false)
end

local function updateDetail()
	if not detail then
		return
	end

	if not selectedItem then
		clearDetail()
		return
	end

	local index = indexOf(selectedItem)
	if not index then
		-- The currency left the list (category collapsed, or moved to unused): show nothing, as
		-- TokenFramePopup_CloseIfHidden does.
		selectedItem = nil
		clearDetail()
		return
	end

	local data = readCurrency(index)
	if not data then
		clearDetail()
		return
	end

	-- The client acts on its own index: keep it current, or its checkboxes would target
	-- another currency.
	local token = _G["TokenFrame"]
	if token then
		token.selectedToken = data.name
		token.selectedID = index
	end

	detail.title:SetText(data.name)
	detail.subtitle:SetText(tostring(data.count))
	placeIcon(detail.icon, data)
	detail.icon:Show()
	detail.separator:Show()

	showCells(true)
	for _, desc in ipairs(CHECKBOXES) do
		local checkbox = _G[desc.name]
		if checkbox and checkbox.SetChecked then
			if desc.name == "TokenFramePopupInactiveCheckBox" then
				checkbox:SetChecked(data.unused)
			else
				checkbox:SetChecked(data.isTracked)
			end
		end
	end
	syncCheckboxes()
end
ForeverUI.TokensDetail = updateDetail

local function choose(name)
	selectedItem = name
	layoutList()
end
ForeverUI.TokensSelect = choose

-- Moves TokenFramePopup into host, the character sheet's right pane, and restyles it
local function buildDetail(host)
	if detail then
		return detail, {}
	end

	local frame = _G["TokenFramePopup"]
	if not frame or not host then
		return nil, {}
	end

	frame:SetParent(host)
	if frame.SetToplevel then
		frame:SetToplevel(false)
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", host, "TOPLEFT", RIGHT_PANE_X, RIGHT_PANE_Y)
	frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", RIGHT_PANE_X2, RIGHT_PANE_Y2)
	-- The backdrop is not a region: only SetBackdrop(nil) removes it (same as
	-- ReputationDetailFrame).
	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end

	-- Hide the client's texts too: TokenFramePopup has a title FontString (TOKEN_OPTIONS) at
	-- TOPLEFT (25, -17) that would otherwise stay on screen. Our regions are created after this.
	for _, region in ipairs({ frame:GetRegions() }) do
		local objectType = region.GetObjectType and region:GetObjectType()
		if objectType == "Texture" then
			region:SetAlpha(0)
		elseif objectType == "FontString" and region.Hide then
			region:Hide()
		end
	end
	local close = _G["TokenFramePopupCloseButton"]
	if close then
		close:Hide()
	end

	detail = frame

	-- camelot uses GameFontNormalMed3, which 3.3.5 lacks; GameFontNormalLarge is the closest.
	detail.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	detail.title:SetWidth(TITLE_W)
	detail.title:SetJustifyH("CENTER")
	detail.title:SetPoint("TOP", frame, "TOP", 0, 0)

	detail.subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	detail.subtitle:SetJustifyH("LEFT")
	detail.subtitle:SetPoint("TOP", detail.title, "BOTTOM", 0, SUBTITLE_Y)

	-- Currency icon left of its count: camelot puts it in the subtitle as a texture tag.
	detail.icon = frame:CreateTexture(nil, "ARTWORK")
	detail.icon:SetWidth(DETAIL_ICON)
	detail.icon:SetHeight(DETAIL_ICON)
	detail.icon:SetPoint("RIGHT", detail.subtitle, "LEFT", DETAIL_ICON_X, 0)
	detail.icon:Hide()

	detail.separator = frame:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(detail.separator, ATLAS_SEPARATOR)
	detail.separator:SetPoint("TOP", detail.subtitle, "BOTTOM", 0, SEPARATOR_Y)

	-- Footer: the two checkboxes, stacked from the bottom of the pane.
	local prev
	for _, desc in ipairs(CHECKBOXES) do
		local checkbox = _G[desc.name]
		if checkbox then
			skinCell(checkbox)
			checkbox:SetParent(frame)
			checkbox:ClearAllPoints()
			if prev then
				checkbox:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, CHECKBOX_GAP)
			else
				local footer = 2 * CHECKBOX + (-CHECKBOX_GAP)
				checkbox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", CHECKBOX_X, footer)
			end
			prev = checkbox
		end
	end

	updateDetail()
	return frame, {}
end

ForeverUI.TokensTab = { Build = build, BuildRight = buildDetail }

-- The client redraws its screen in TokenFrame_Update: run after it.
if hooksecurefunc and type(_G["TokenFrame_Update"]) == "function" then
	hooksecurefunc("TokenFrame_Update", function()
		layoutList()
	end)
end

-- /fui currency: prints what the client returns for each visible row and our state.
function ForeverUI.TokensDebug()
	local say = function(text)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
	end

	local total = (GetCurrencyListSize and GetCurrencyListSize()) or 0
	say(string.format(L.TOKENSTAB_DEBUG_SUMMARY, total, offset, visibleCount,
		tostring(selectedItem)))

	for rank = 1, math.min(total, 12) do
		local currency = readCurrency(rank)
		if currency then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				L.TOKENSTAB_DEBUG_ROW,
				rank, currency.name,
				currency.header and (currency.expanded and "[-]" or "[+]") or "   ",
				tostring(currency.count), tostring(currency.special),
				tostring(currency.isTracked), tostring(currency.unused)))
		end
	end

	local token = _G["TokenFrame"]
	say(string.format(L.TOKENSTAB_DEBUG_CLIENT,
		tostring(token and token.selectedToken),
		tostring(token and token.selectedID),
		tostring(token and token:IsShown())))
end
