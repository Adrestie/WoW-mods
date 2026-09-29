-- Title list, a page of the character sheet's right pane.
-- Row layout from camelot PlayerTitleButtonTemplate (paperdollframe.xml): check 16 x 16 at
-- LEFT (8, 0), text 3 px right of it to RIGHT (-3, 0), SelectedBar alpha 0.4 ADD, blue
-- highlight ADD.
-- Data API, as used by the client's PlayerTitleFrame_UpdateTitles:
--   IsTitleKnown returns 0 or 1, and 0 is true in Lua: test `~= 0`, as the client does.
--   GetTitleName pads the name with spaces ("Private "): strtrim it, as the client does.
--   GetCurrentTitle returns 0 when nothing is chosen, -1 for None, else the id;
--   SetCurrentTitle(-1) sets None.
-- Differences from camelot:
--   * The tab is not in camelot's PAPERDOLL_SIDEBARS; it comes from
--     mainline/PaperDollFrameConstants.lua PAPERDOLL_SIDEBARTAB_TITLES.
--   * camelot's TitleManagerPane keeps a dead TOPLEFT (4, -4) anchor, under the stone band
--     and tabs. We use EquipmentManagerPane's: stone bottom to pane bottom.
--   * No scroll bar: mouse wheel only, like reputation and skills.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local L = ForeverUI.L

-- Rows span the pane width minus the stat rows' margin (camelot: 169 wide in a 233 pane),
-- so both pages of the pane share the same edge.
local ROW_H = 22
local MARGIN = 20                         -- STAT_MARGIN of CharacterFrame.lua, on each side
local LIST_Y = -4                       -- SetPadding(4, 0, 2, 0, 0)
local CHECKMARK = 16
local CHECKMARK_X = 8
local TEXT_X, TEXT_X2 = 3, -3
local SELECTED_ALPHA = 0.4

-- Alternating background, the same as the stat rows: the two bands of paperdollinfopart1c60
-- whose alpha fades at both ends.
--   UI-Character-Info-ItemLevel-Bounce  204 x 21, dark  (27, 21, 16) at 255
--   UI-Character-Info-Line-Bounce       213 x 18, light (87, 67, 46) at 102
-- Dark first. Alternation follows the list index (scroll included), not the screen slot,
-- as camelot's PaperDollTitlesPane_InitButton does with `index % 2`.
local ATLAS_DARK_BACKGROUND = "ui-character-info-itemlevel-bounce"
local ATLAS_LIGHT_BACKGROUND = "ui-character-info-line-bounce"
local CHECKMARK_PATH = "Interface\\Buttons\\UI-CheckBox-Check"
local SELECTED_PATH = "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar"
local HOVER_PATH =
	"Interface\\ForeverUI\\FriendsFrame\\UI-FriendsFrame-HighlightBar-Blue"

-- Pane size, used when content is built on first open before the window is laid out
-- (GetHeight returns 0 then). Same guard as reputation and skills.
-- Right pane 233 x 464; the stone band takes the top 85.
local PANE_W, PANE_H, STONE_H = 233, 464, 85

local panel, offset, rows, titles, selected = nil, 0, {}, {}, -1

-- ---------- Data

local function noneName()
	return NONE
end

-- Titles the character owns, sorted by name, with None first (as in camelot's list).
local function readTitles()
	local list = {}
	local count = GetNumTitles and GetNumTitles() or 0
	for identifier = 1, count do
		if IsTitleKnown and IsTitleKnown(identifier) ~= 0 then
			local name = GetTitleName and GetTitleName(identifier)
			if name then
				name = strtrim(name)
				if name ~= "" then
					list[#list + 1] = { id = identifier, name = name }
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	table.insert(list, 1, { id = -1, name = noneName() })
	return list
end

-- Worn title as camelot keeps it: the current id if it is a known title, else None (-1).
-- GetCurrentTitle returns 0 while nothing is chosen.
local function wornTitle()
	local current = GetCurrentTitle and GetCurrentTitle() or 0
	local count = GetNumTitles and GetNumTitles() or 0
	if current and current > 0 and current <= count
		and IsTitleKnown and IsTitleKnown(current) ~= 0 then
		return current
	end
	return -1
end

-- ---------- Display

local function applyChoice(row, marker)
	if marker then
		row.checkMark:Show()
		row.selected:Show()
	else
		row.checkMark:Hide()
		row.selected:Hide()
	end
end

-- Row width: pane width minus margins. Falls back to PANE_W when content is built before
-- the window is laid out (GetWidth returns 0 then).
local function rowWidth()
	local width = (panel and panel:GetWidth()) or 0
	if width < 50 then
		width = PANE_W
	end
	return width - 2 * MARGIN
end

local function createRow(rank)
	local row = CreateFrame("Button", "ForeverUITitleRow" .. rank, panel)
	row:SetWidth(rowWidth())
	row:SetHeight(ROW_H)

	-- Background: one texture whose atlas changes on each pass. SetAtlas keeps the size
	-- (third argument): it comes from the two anchors.
	local background = row:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	background:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.background = background

	local selectedBar = row:CreateTexture(nil, "OVERLAY")
	selectedBar:SetTexture(SELECTED_PATH)
	selectedBar:SetBlendMode("ADD")
	selectedBar:SetAlpha(SELECTED_ALPHA)
	selectedBar:SetAllPoints(row)
	selectedBar:Hide()
	row.selected = selectedBar

	local checkMark = row:CreateTexture(nil, "BORDER")
	checkMark:SetTexture(CHECKMARK_PATH)
	checkMark:SetWidth(CHECKMARK)
	checkMark:SetHeight(CHECKMARK)
	checkMark:SetPoint("LEFT", row, "LEFT", CHECKMARK_X, 0)
	checkMark:Hide()
	row.checkMark = checkMark

	local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", checkMark, "RIGHT", TEXT_X, 0)
	text:SetPoint("RIGHT", row, "RIGHT", TEXT_X2, 0)
	row.text = text
	row:SetFontString(text)

	-- 3.3.5: SetHighlightTexture takes a path and a blend mode, never a texture object, so the
	-- highlight cannot be built separately as camelot's XML does.
	row:SetHighlightTexture(HOVER_PATH, "ADD")
	local hover = row.GetHighlightTexture and row:GetHighlightTexture()
	if hover then
		hover:SetAllPoints(row)
	end

	row:SetScript("OnClick", function(self)
		if not self.titleId then
			return
		end
		if PlaySound then
			PlaySound("igMainMenuOptionCheckBoxOff")
		end
		if SetCurrentTitle then
			SetCurrentTitle(self.titleId)
		end
		selected = self.titleId
		if ForeverUI.TitlesUpdate then
			ForeverUI.TitlesUpdate()
		end
	end)

	if rank == 1 then
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", MARGIN, LIST_Y)
	else
		row:SetPoint("TOPLEFT", rows[rank - 1], "BOTTOMLEFT", 0, 0)
	end

	rows[rank] = row
	return row
end

-- How many rows fit in the panel, top margin deducted.
local function fitCount()
	local height = (panel and panel:GetHeight()) or 0
	if height < 50 then
		height = PANE_H - STONE_H
	end
	local count = math.floor((height + LIST_Y) / ROW_H)
	if count < 1 then
		count = 1
	end
	return count
end

-- Stacks rows from the scroll offset down to the panel bottom; returns the count shown.
local function place()
	if not panel then
		return 0
	end

	local slots = fitCount()
	local total = #titles
	if offset > 0 and offset + slots > total then
		offset = math.max(0, total - slots)
	end

	local width = rowWidth()
	local placedCount = 0
	for rank = 1, slots do
		local index = offset + rank
		local title = titles[index]
		local row = rows[rank] or createRow(rank)
		row:SetWidth(width)
		if title then
			row.titleId = title.id
			row.text:SetText(title.name)
			applyChoice(row, title.id == selected)
			ForeverUI.SetAtlas(row.background,
				(index % 2 == 1) and ATLAS_DARK_BACKGROUND or ATLAS_LIGHT_BACKGROUND,
				true)
			row:Show()
			placedCount = placedCount + 1
		else
			row.titleId = nil
			row:Hide()
		end
	end
	for rank = slots + 1, #rows do
		rows[rank]:Hide()
	end
	return placedCount
end

-- The client's title drop-down is hidden on every pass: PlayerTitleFrame_UpdateTitles shows
-- it again (PlayerTitleFrame:Show()) whenever a title changes.
local CLIENT_MENU = { "PlayerTitleFrame", "PlayerTitlePickerFrame" }

local function suppressClientMenu()
	for _, name in ipairs(CLIENT_MENU) do
		local frame = _G[name]
		if frame then
			frame:Hide()
			if frame.EnableMouse then
				frame:EnableMouse(false)
			end
		end
	end
end

local function update()
	suppressClientMenu()
	if not panel then
		return
	end
	titles = readTitles()
	selected = wornTitle()
	place()
end
ForeverUI.TitlesUpdate = update

-- ---------- Construction

-- Builds the pane once. host: the character sheet's right pane (host.stone: its stone band).
local function build(host)
	if panel then
		return panel, {}
	end

	-- EquipmentManagerPane's anchor: stone bottom to pane bottom (see the file header).
	panel = CreateFrame("Frame", "ForeverUITitlesPane", host)
	if host.stone then
		panel:SetPoint("TOPLEFT", host.stone, "BOTTOMLEFT", 0, 0)
	else
		panel:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
	end
	panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)

	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_self, direction)
		offset = math.max(0, math.min(offset - direction, #titles - fitCount()))
		place()
	end)

	update()
	return panel, {}
end

ForeverUI.TitlesPane = { Build = build, Update = update }

-- The client rebuilds its list in PlayerTitleFrame_UpdateTitles: run after it to refresh
-- ours and hide its own.
if hooksecurefunc and type(_G["PlayerTitleFrame_UpdateTitles"]) == "function" then
	hooksecurefunc("PlayerTitleFrame_UpdateTitles", function()
		update()
	end)
end

-- KNOWN_TITLES_UPDATE: a title is earned; UNIT_NAME_UPDATE on the player: the worn title
-- changes. camelot listens to these same two events.
local listener = CreateFrame("Frame")
listener:RegisterEvent("KNOWN_TITLES_UPDATE")
listener:RegisterEvent("UNIT_NAME_UPDATE")
listener:SetScript("OnEvent", function(_self, event, unit)
	if event == "UNIT_NAME_UPDATE" and unit ~= "player" then
		return
	end
	update()
end)

-- Debug report: /fui titles.
function ForeverUI.TitlesDebug()
	local say = function(t)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t)
	end
	local list = readTitles()
	say(string.format(L.TITLES_DEBUG_SUMMARY, #list - 1, tostring(wornTitle()),
		offset, panel and fitCount() or 0))
	local names = {}
	for index = 1, math.min(#list, 8) do
		names[#names + 1] = string.format("%s(%d)", list[index].name,
			list[index].id)
	end
	say("   " .. table.concat(names, ", "))
	for _, name in ipairs(CLIENT_MENU) do
		local frame = _G[name]
		say(string.format("   %s : %s", name,
			frame and (frame:IsShown() and L.TITLES_DEBUG_VISIBLE or L.TITLES_DEBUG_HIDDEN)
			or L.TITLES_DEBUG_ABSENT))
	end
end
