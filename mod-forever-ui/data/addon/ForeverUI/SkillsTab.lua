-- Skills tab of the character frame (camelot SkillsFrame.xml / skillsframe.lua), the same
-- screen as the reputation tab. Headers are 26 high (not 28), entries 30. The entry bar
-- (SkillsBarTemplate 160 x 29) is blue through its sprite, not a tint, and always shows
-- the progress. Right pane: SkillDetailFrameMixin with a 180 x 29 RankBar.
-- 3.3.5 differences: GetSkillLineInfo has one level, so there are no sub-headers; weapon
-- lines get no hit / crit detail (no WEAPON_SKILL_DETAIL_* strings); the description does
-- not scroll (no ScrollingFontTemplate); the scroll bar is MinimalScrollBar from ScrollBar.lua.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local L = ForeverUI.L

local LIST_X, LIST_Y = 10, -40
local LIST_X2, LIST_Y2 = -25, 15

local ENTRY_H = 30                     -- SkillsEntryTemplate
local HEADER_H = 26                     -- SkillsHeaderTemplate
local MARGIN = 10                        -- SetPadding
local GAP = 3                         -- elementSpacing
local HEADER_INDENT = 0
local OTHER_INDENT = 2

local BAR_W, BAR_H = 160, 29
local BAR_X = -3
local FILL_H = 15
local NAME_H = 15
local NAME_X = 2                         -- SkillsEntryTemplate
local NAME_GAP = -10
local HEADER_NAME_X = 10
local ARROW_X, ARROW_Y = -8, -1
local ARROW_SPACE = 16
local SIDE = 6

local PLATE_CORNER = 12                  -- same as the reputation tab
local GAUGE_CORNER = 10

local ATLAS_BAR_BACKGROUND = "common-stat-bar-bg"
local ATLAS_HEADER = "common-button-list-collapseexpand"
local ATLAS_PLUS = "common-button-list-plus"
local ATLAS_MINUS = "common-button-list-minus"
local ATLAS_LINE = "ui-character-info-scrollline-long"
local ATLAS_HOVER_SIDE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_HOVER_MIDDLE = "charactercreate-customize-dropdown-linemouseover-middle"
local ATLAS_SEPARATOR = "ui-character-info-scrollline"

-- Blue fill, baked with the mask like the reputation's white one: same slicing as the
-- background, so the outlines overlap.
local FILL_PATH = "Interface\\ForeverUI\\Bars\\statbarfillblue"

-- Right pane: CharacterFrameSidePaneTemplate.
local RIGHT_PANE_X, RIGHT_PANE_Y = 16, -14
local RIGHT_PANE_X2, RIGHT_PANE_Y2 = -12, 14
local TITLE_W = 195
local SUBTITLE_Y = -3
local SEPARATOR_Y = -4
local RANK_W, RANK_H = 180, 29
local RANK_Y = -6
local DESCRIPTION_Y = -8                -- not -6: SkillDetailFrameMixin
local DESCRIPTION_X2 = -14
local DESCRIPTION_Y2 = 6

-- Pane size, used while the host has no size yet.
local PANE_W, PANE_H = 398, 464

local rows = {}
local panel, offset = nil, 0
local visibleCount = 0
local selectedItem                            -- the NAME, the only stable key
local detail, lastData

-- --------------------------------------------------------------- Data

-- GetSkillLineInfo returns, in order: name, header, expanded, rank, temporary points, bonus,
-- max rank, abandonable, step cost, rank cost, min level, cost type, description.
local function readSkill(rank)
	local name, header, expanded, value, temporary, bonus, maximum, _, _, _,
		_, _, description = GetSkillLineInfo(rank)
	if not name or name == "" then
		return nil
	end

	value = (value or 0) + (temporary or 0)
	bonus = bonus or 0
	maximum = maximum or 0

	-- InitializeBarForStandardSkill: "rank / max", or "rank (+bonus) / max" with the bonus
	-- in green.
	local text
	if bonus == 0 then
		text = tostring(value) .. " / " .. tostring(maximum)
	else
		text = tostring(value) .. " |cff00ff00(+" .. tostring(bonus)
			.. ")|r / " .. tostring(maximum)
	end

	return {
		index = rank,
		name = name,
		header = header,
		collapsed = (header and not expanded) or false,
		value = value,
		maximum = maximum,
		text = text,
		description = description or "",
	}
end

-- Skill line index of a skill name, or nil
local function indexOf(name)
	if not name then
		return nil
	end
	for rank = 1, (GetNumSkillLines and GetNumSkillLines()) or 0 do
		if GetSkillLineInfo(rank) == name then
			return rank
		end
	end
	return nil
end

-- --------------------------------------------------------------- Row

local function createRow(index, width)
	local row = CreateFrame("Button", "ForeverUISkillRow" .. index, panel)
	row:SetWidth(width)
	row:SetHeight(ENTRY_H)

	row.plate = ForeverUI.CreateNineSlice(row, ATLAS_HEADER, PLATE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	for _, slice in ipairs(row.plate) do
		slice:Hide()
	end

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

	local bar = CreateFrame("Frame", nil, row)
	bar:SetWidth(BAR_W)
	bar:SetHeight(BAR_H)
	bar:SetPoint("RIGHT", row, "RIGHT", BAR_X, 0)
	row.bar = bar

	ForeverUI.CreateNineSlice(bar, ATLAS_BAR_BACKGROUND, GAUGE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND")

	bar.fill = bar:CreateTexture(nil, "BORDER")
	bar.fill:SetPoint("LEFT", bar, "LEFT", 0, 0)

	bar.text = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	bar.text:SetPoint("LEFT", bar, "LEFT", 0, 0)
	bar.text:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
	bar.text:SetJustifyH("CENTER")

	local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	name:SetHeight(NAME_H)
	name:SetJustifyH("LEFT")
	row.name = name

	local arrow = row:CreateTexture(nil, "OVERLAY")
	arrow:SetPoint("RIGHT", row, "RIGHT", ARROW_X, ARROW_Y)
	arrow:Hide()
	row.arrow = arrow

	row:RegisterForClicks("LeftButtonUp")
	return row
end

-- ----------------------------------------------------------- Fill

-- SetFillPercent: width = fraction x bar width, texture cropped the same.
local function placeBarIn(bar, data, width)
	local fraction = 0
	if data.maximum and data.maximum > 0 then
		fraction = data.value / data.maximum
	end
	if fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end

	if fraction * width < 1 then
		bar.fill:Hide()
	else
		bar.fill:SetTexture(FILL_PATH)
		bar.fill:SetTexCoord(0, fraction, 0, 1)
		bar.fill:SetWidth(width * fraction)
		bar.fill:SetHeight(FILL_H)
		bar.fill:Show()
	end

	bar.text:SetText(data.text or "")
end

-- RefreshBackgroundHighlightOpacity, without the "at war" case; the tint is always white.
local function placeHover(row)
	if row.header then
		row.hover:SetAlpha(0)
		return
	end

	local hovered = row:IsMouseOver()
	row.hover:SetAlpha((row.selectedItem and 0.20) or (hovered and 0.10) or 0)
end

-- SetFontObject resets the justification to the font's own (GameFontHighlight is centered
-- in the client's FontStyles.xml), so SetJustifyH must come after it, as camelot sets
-- justifyH="LEFT" on top of the font object.
local function populateRow(row, data)
	row.skillIndex = data.index
	row.skillName = data.name
	row.header = data.header
	row.collapsed = data.collapsed

	row.name:SetText(data.name or "")
	row.name:ClearAllPoints()

	for _, slice in ipairs(row.plate) do
		if data.header then slice:Show() else slice:Hide() end
	end

	if data.header then
		row:SetHeight(HEADER_H)
		row.bar:Hide()
		row.name:SetFontObject(GameFontNormalLeft or GameFontNormal)
		row.name:SetJustifyH("LEFT")
		row.name:SetPoint("LEFT", row, "LEFT", HEADER_NAME_X, 0)
		row.name:SetPoint("RIGHT", row, "RIGHT", ARROW_X - ARROW_SPACE, 0)

		ForeverUI.SetAtlas(row.arrow, data.collapsed and ATLAS_PLUS or ATLAS_MINUS)
		row.arrow:Show()
	else
		row:SetHeight(ENTRY_H)
		row.bar:Show()
		row.arrow:Hide()
		row.name:SetFontObject(GameFontHighlight or GameFontNormal)
		row.name:SetJustifyH("LEFT")
		row.name:SetPoint("LEFT", row, "LEFT", NAME_X, 0)
		row.name:SetPoint("RIGHT", row.bar, "LEFT", NAME_GAP, 0)
		placeBarIn(row.bar, data, BAR_W)
	end

	row.selectedItem = (selectedItem ~= nil and selectedItem == data.name)
	placeHover(row)
	row:Show()
end

-- ------------------------------------------------------------- Layout

local function indentOf(data)
	return data.header and HEADER_INDENT or OTHER_INDENT
end

local function heightOf(data)
	return data.header and HEADER_H or ENTRY_H
end

-- Hides everything the client's SkillFrame holds except our panel: its regions
-- (GetRegions) and child frames (GetChildren). Runs on every pass, since
-- SkillFrame_UpdateSkills shows them again.
local function suppressClientScreen()
	local frame = _G["SkillFrame"]
	if not frame then
		return
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

local function layout()
	local total = (GetNumSkillLines and GetNumSkillLines()) or 0

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
		local data = (index <= total) and readSkill(index) or nil
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

	suppressClientScreen()

	local total = (GetNumSkillLines and GetNumSkillLines()) or 0
	local placedCount = layout()

	if offset > 0 and offset + placedCount > total then
		offset = math.max(0, total - placedCount)
		placedCount = layout()
	end

	visibleCount = placedCount

	if panel.bar then
		panel.bar:Configure(total, placedCount, offset)
	end

	if ForeverUI.SkillsDetail then
		ForeverUI.SkillsDetail()
	end
end
ForeverUI.SkillsLayout = layoutList

-- --------------------------------------------------------------- Detail

local function clearDetail()
	detail.title:SetText("")
	detail.subtitle:SetText("")
	-- SKILL_DETAIL_SELECT_PROMPT does not exist in 3.3.5: left empty.
	detail.description:SetText("")
	detail.separator:Hide()
	detail.gauge:Hide()
end

local function updateDetail()
	if not detail then
		return
	end

	if not selectedItem then
		lastData = nil
		clearDetail()
		return
	end

	local index = indexOf(selectedItem)
	local data
	if index then
		if SetSelectedSkill and GetSelectedSkill and GetSelectedSkill() ~= index then
			SetSelectedSkill(index)
		end
		data = readSkill(index)
		lastData = data
	else
		data = lastData
	end

	if not data or data.header then
		clearDetail()
		return
	end

	detail.title:SetText(data.name or "")
	detail.subtitle:SetText("")
	detail.separator:Show()
	detail.gauge:Show()
	placeBarIn(detail.gauge, data, RANK_W)
	detail.description:SetText(data.description or "")
end
ForeverUI.SkillsDetail = updateDetail

local function choose(name)
	selectedItem = name
	local index = indexOf(name)
	if index and SetSelectedSkill then
		SetSelectedSkill(index)
	end
	layoutList()
end
ForeverUI.SkillsSelect = choose

-- SelectFirstSkillIfNoneSelected: on opening, select the first non-header skill so the
-- right pane is not empty.
local function selectFirst()
	if selectedItem then
		return
	end
	for rank = 1, (GetNumSkillLines and GetNumSkillLines()) or 0 do
		local data = readSkill(rank)
		if data and not data.header then
			choose(data.name)
			return
		end
	end
end

-- Builds the right pane (skill detail) in host
local function buildDetail(host)
	if detail then
		return detail, {}
	end

	local frame = CreateFrame("Frame", "ForeverUISkillDetail", host)
	frame:SetPoint("TOPLEFT", host, "TOPLEFT", RIGHT_PANE_X, RIGHT_PANE_Y)
	frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", RIGHT_PANE_X2, RIGHT_PANE_Y2)
	detail = frame

	detail.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	detail.title:SetWidth(TITLE_W)
	detail.title:SetJustifyH("CENTER")
	detail.title:SetPoint("TOP", frame, "TOP", 0, 0)

	detail.subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	detail.subtitle:SetWidth(TITLE_W)
	detail.subtitle:SetJustifyH("CENTER")
	detail.subtitle:SetPoint("TOP", detail.title, "BOTTOM", 0, SUBTITLE_Y)

	detail.separator = frame:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(detail.separator, ATLAS_SEPARATOR)
	detail.separator:SetPoint("TOP", detail.subtitle, "BOTTOM", 0, SEPARATOR_Y)

	local gauge = CreateFrame("Frame", "ForeverUISkillRank", frame)
	gauge:SetWidth(RANK_W)
	gauge:SetHeight(RANK_H)
	gauge:SetPoint("TOP", detail.separator, "BOTTOM", 0, RANK_Y)
	ForeverUI.CreateNineSlice(gauge, ATLAS_BAR_BACKGROUND, GAUGE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND")
	gauge.fill = gauge:CreateTexture(nil, "BORDER")
	gauge.fill:SetPoint("LEFT", gauge, "LEFT", 0, 0)
	gauge.text = gauge:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	gauge.text:SetPoint("LEFT", gauge, "LEFT", 0, 0)
	gauge.text:SetPoint("RIGHT", gauge, "RIGHT", 0, 0)
	gauge.text:SetJustifyH("CENTER")
	detail.gauge = gauge

	-- Description in a box: without a bottom anchor, a long text disappears.
	detail.description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	detail.description:SetPoint("TOPLEFT", gauge, "BOTTOMLEFT", 0, DESCRIPTION_Y)
	detail.description:SetPoint("TOPRIGHT", gauge, "BOTTOMRIGHT", 0, DESCRIPTION_Y)
	detail.description:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, DESCRIPTION_Y2)
	detail.description:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
		DESCRIPTION_X2, DESCRIPTION_Y2)
	detail.description:SetJustifyH("LEFT")
	detail.description:SetJustifyV("TOP")
	if detail.description.SetWordWrap then
		detail.description:SetWordWrap(true)
	end

	updateDetail()
	return frame, {}
end

-- --------------------------------------------------------- Build

local function trackHover()
	for _, row in ipairs(rows) do
		if row:IsShown() and not row.header then
			placeHover(row)
		end
	end
end

-- Builds the skill list in host over the client's SkillFrame
local function build(host)
	local frame = _G["SkillFrame"]
	if not frame or not host then
		return nil, {}
	end

	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)

	if panel then
		selectFirst()
		return nil, { frame }
	end

	-- The 3.3.5 art and rows go away; only the frame is kept.
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

	panel = CreateFrame("Frame", "ForeverUISkillList", frame)
	panel:SetPoint("TOPLEFT", host, "TOPLEFT", LIST_X, LIST_Y)
	panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", LIST_X2, LIST_Y2)
	panel:SetWidth(width)

	local position = math.floor((height + LIST_Y - LIST_Y2) / (HEADER_H + GAP))
	if position < 1 then
		position = 1
	end
	for index = 1, position do
		local row = createRow(index, width)
		row:SetScript("OnClick", function(self)
			if not self.skillIndex then
				return
			end
			if self.header then
				if self.collapsed then
					ExpandSkillHeader(self.skillIndex)
				else
					CollapseSkillHeader(self.skillIndex)
				end
				layoutList()
			else
				ForeverUI.SkillsSelect(self.skillName)
			end
		end)
		rows[index] = row
	end

	-- Both lines live on our panel, not on the client's frame: its regions are all hidden
	-- on every pass.
	local top = panel:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(top, ATLAS_LINE)
	top:SetPoint("CENTER", panel, "TOP", 0, 0)

	local down = panel:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(down, ATLAS_LINE)
	down:SetPoint("CENTER", panel, "BOTTOM", 0, 0)

	-- Camelot's scroll bar, right of the list, as in the reputation tab. It does not know the
	-- list: it gets three numbers and returns the new offset.
	panel.bar = ForeverUI.CreateScrollBar("ForeverUISkillsScrollBar",
		frame, panel)
	panel.bar.onScroll = function(new)
		offset = new
		layoutList()
	end
	-- Without a bar the list takes its place, as in the reputation tab: right edge from -25
	-- to -10, rows laid out again.
	panel.bar.onVisibility = function(hasBar)
		local x2 = hasBar and LIST_X2 or -LIST_X
		panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", x2, LIST_Y2)
		panel:SetWidth(width + x2 - LIST_X2)
		layout()
	end

	panel:SetScript("OnUpdate", trackHover)
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(self, direction)
		local total = (GetNumSkillLines and GetNumSkillLines()) or 0
		offset = math.max(0, math.min(offset - direction, total - visibleCount))
		layoutList()
	end)

	layoutList()
	selectFirst()
	return nil, { frame }
end

ForeverUI.SkillsTab = { Build = build, BuildRight = buildDetail, Rows = rows }

-- Debug output: /fui skills.
function ForeverUI.SkillsDebug()
	local say = function(text)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
	end

	local total = (GetNumSkillLines and GetNumSkillLines()) or 0
	say(string.format(L.SKILLSTAB_DEBUG_SUMMARY,
		total, offset, visibleCount, tostring(selectedItem)))
	for rank = 1, total do
		local d = readSkill(rank)
		if d then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				L.SKILLSTAB_DEBUG_ROW,
				rank, d.name, tostring(d.header), tostring(d.collapsed), d.text))
		end
	end
end

-- The client rebuilds its list in SkillFrame_UpdateSkills: run after it.
if hooksecurefunc and type(_G["SkillFrame_UpdateSkills"]) == "function" then
	hooksecurefunc("SkillFrame_UpdateSkills", layoutList)
end
