-- ForeverUI: the Reputation tab, after camelot ReputationFrame.xml and ReputationFrame.lua.
-- Rows are our own, filled from GetFactionInfo: ReputationFrame_Update re-applies its art to
-- the client rows on every pass, so they cannot be reskinned. The client frame is only a parent.
-- 3.3.5 has no AccountWideIcon, Paragon or friendship; the scroll bar comes from ScrollBar.lua.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local L = ForeverUI.L

-- List inset in CharacterFrameLeftPaneHost (camelot ReputationFrame.xml).
local LIST_X, LIST_Y = 10, -40
local LIST_X2, LIST_Y2 = -25, 15

-- Three templates, three indents (camelot ReputationFrame.lua).
-- SetElementFactory: entry 30 high, header 28, sub-header (header and child) 22.
-- SetElementIndentCalculator: top-level header 0, child that is not a header 46, others 2.
-- SetPadding: 10 on each edge, 3 between rows.
local ENTRY_H = 30                     -- ReputationEntryTemplate
local SUBHEADER_H = 22                -- ReputationSubHeaderTemplate
local HEADER_H = 28                     -- ReputationHeaderTemplate
local MARGIN = 10                        -- SetPadding
local GAP = 3                         -- elementSpacing
local HEADER_INDENT = 0
local CHILD_INDENT = 46
local OTHER_INDENT = 2
local BAR_W, BAR_H = 160, 29
local BAR_X = -3                      -- from the row's RIGHT
local FILL_H = 15
local NAME_H = 15
-- Entry name x: AccountWideIcon right edge (25), minus the 10 that ReputationEntryMixin:Initialize
-- removes when the icon is hidden. It is always hidden: 3.3.5 has no account reputation.
local NAME_X = 15
-- Sub-header button: at the icon's right edge + 3, so x = 28; its name follows 4 px after it.
local CHEVRON_X = 28
-- Collapse button width, the same in both states (plus is 13 x 13, minus 13 x 4).
local CHEVRON_W = 13
local SUBNAME_GAP = 4
local NAME_GAP = -10                   -- from the bar's LEFT
local HEADER_NAME_X = 10
local ARROW_X, ARROW_Y = -8, -1
local ARROW_SPACE = 16                 -- room the name leaves for the arrow
local SIDE = 6                          -- width of the hover side slices

-- The header plate (64 x 29) is nine-sliced: stretched over a 300+ px row, its rounded corners
-- become ellipses. The rounding spans about 10 px; 12 covers it and stays under half the height.
local PLATE_CORNER = 12

-- The gauge background (68 x 30) is nine-sliced too: its rounded ends span 10 px of the art.
-- The fill is not sliced: it is a gauge, cropped to the fraction like camelot's SetFillPercent.
local GAUGE_CORNER = 10

local ATLAS_BAR_BACKGROUND = "common-stat-bar-bg"
-- Tint of an at-war row (camelot RefreshBackgroundHighlightColor). FACTION_AT_WAR_COLOR does not
-- exist in 3.3.5; this is its value in the modern client's GlobalColor.db2: 0xFF690300.
local AT_WAR_COLOR = { r = 105 / 255, g = 3 / 255, b = 0 / 255 }

-- camelot shapes the fill with common-stat-bar-Mask, a MaskTexture 3.3.5 lacks.
-- tools/bake_masks.py bakes the mask into this file, sliced like the background, for a 160 bar.
local FILL_PATH = "Interface\\ForeverUI\\Bars\\statbarfill"
local ATLAS_HEADER = "common-button-list-collapseexpand"
local ATLAS_PLUS = "common-button-list-plus"
local ATLAS_MINUS = "common-button-list-minus"
local ATLAS_LINE = "ui-character-info-scrollline-long"
local ATLAS_HOVER_SIDE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_HOVER_MIDDLE = "charactercreate-customize-dropdown-linemouseover-middle"

-- Fixed pane size: a tab can be built before the window is laid out, when GetHeight is 0.
local PANE_W, PANE_H = 398, 464

local rows = {}
local panel, offset = nil, 0
local visibleCount = 0                      -- rows that actually fit
local selectedItem

-- ---------- Rows

local function createRow(index, width)
	local row = CreateFrame("Button", "ForeverUIReputationRow" .. index, panel)
	row:SetWidth(width)
	row:SetHeight(ENTRY_H)

	-- Header plate, nine-sliced: only the middle slices stretch.
	row.plate = ForeverUI.CreateNineSlice(row, ATLAS_HEADER, PLATE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	for _, slice in ipairs(row.plate) do
		slice:Hide()
	end

	-- Entry hover highlight: three slices, sides 6 wide.
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
		-- The source mirrors it: TexCoords left = 1, right = 0.
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

	-- Reputation bar: background, fill and text.
	local bar = CreateFrame("Frame", nil, row)
	bar:SetWidth(BAR_W)
	bar:SetHeight(BAR_H)
	bar:SetPoint("RIGHT", row, "RIGHT", BAR_X, 0)
	row.bar = bar

	ForeverUI.CreateNineSlice(bar, ATLAS_BAR_BACKGROUND, GAUGE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND")

	local fill = bar:CreateTexture(nil, "BORDER")
	fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
	bar.fill = fill

	local text = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("LEFT", bar, "LEFT", 0, 0)
	text:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
	text:SetJustifyH("CENTER")
	bar.text = text

	-- Name anchors depend on the template, so they are set on each fill.
	local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	name:SetHeight(NAME_H)
	name:SetJustifyH("LEFT")
	row.name = name

	-- Collapse arrow of a top-level header, on the right.
	local arrow = row:CreateTexture(nil, "OVERLAY")
	arrow:SetPoint("RIGHT", row, "RIGHT", ARROW_X, ARROW_Y)
	arrow:Hide()
	row.arrow = arrow

	-- Collapse button of a sub-header, on the left. camelot uses campaign_headericon_closed and
	-- _open from questmaplogatlas.blp; the header's plus and minus are used instead.
	local chevron = row:CreateTexture(nil, "OVERLAY")
	chevron:SetPoint("LEFT", row, "LEFT", CHEVRON_X, 0)
	chevron:Hide()
	row.chevron = chevron

	row:RegisterForClicks("LeftButtonUp")
	return row
end

-- ---------- Bar fill

-- Fills a reputation bar. data: readFaction result; width: bar width.
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

	-- As SetFillPercent: width = fraction x bar width, texture cropped to match.
	-- The client rejects a zero width.
	if fraction * width < 1 then
		bar.fill:Hide()
	else
		bar.fill:SetTexture(FILL_PATH)
		bar.fill:SetTexCoord(0, fraction, 0, 1)
		bar.fill:SetWidth(width * fraction)
		bar.fill:SetHeight(FILL_H)
		bar.fill:Show()
	end

	local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[data.standingId]
	if color then
		bar.fill:SetVertexColor(color.r, color.g, color.b)
	end

	bar.text:SetText(data.label or "")
end

-- List row: its bar is 160 wide.
local function placeBar(row, data)
	placeBarIn(row.bar, data, BAR_W)
end

-- Hover opacity, as in RefreshBackgroundHighlightOpacity.
local function placeHover(row)
	if row.header then
		row.hover:SetAlpha(0)
		return
	end

	local hovered = row:IsMouseOver()
	local alpha
	if row.atWar then
		alpha = (row.selectedItem and 0.85) or (hovered and 0.65) or 0.50
	else
		alpha = (row.selectedItem and 0.20) or (hovered and 0.10) or 0
	end
	row.hover:SetAlpha(alpha)

	local tint = row.atWar
		and (FACTION_AT_WAR_COLOR or AT_WAR_COLOR)
	for _, piece in ipairs(row.hoverPieces) do
		if tint then
			piece:SetVertexColor(tint.r, tint.g, tint.b)
		else
			piece:SetVertexColor(1, 1, 1)
		end
	end
end

-- Fills a row from readFaction data and applies its template.
-- SetFontObject resets the justification to the font object's own (GameFontHighlight centers),
-- so SetJustifyH is applied after it, as camelot does with justifyH="LEFT".
local function populateRow(row, data)
	row.factionIndex = data.index
	row.factionName = data.name
	row.header = data.header
	row.child = data.child
	row.collapsed = data.collapsed
	row.atWar = data.atWar
	row.progression = data.progression
	row.label = data.label
	row.lastHovered = nil

	row.name:SetText(data.name or "")
	row.name:ClearAllPoints()

	local plate = data.header and not data.child
	local subHeader = data.header and data.child

	for _, slice in ipairs(row.plate) do
		if plate then slice:Show() else slice:Hide() end
	end

	if plate then
		-- Top-level header: plate, gold name, arrow on the right.
		row:SetHeight(HEADER_H)
		row.bar:Hide()
		row.chevron:Hide()
		row.name:SetFontObject(GameFontNormalLeft or GameFontNormal)
		row.name:SetJustifyH("LEFT")
		row.name:SetPoint("LEFT", row, "LEFT", HEADER_NAME_X, 0)
		row.name:SetPoint("RIGHT", row, "RIGHT", ARROW_X - ARROW_SPACE, 0)

		ForeverUI.SetAtlas(row.arrow, data.collapsed and ATLAS_PLUS or ATLAS_MINUS)
		row.arrow:Show()
	elseif subHeader then
		-- Sub-header: button on the left, name after it, bar only if it has reputation.
		row:SetHeight(SUBHEADER_H)
		row.arrow:Hide()
		ForeverUI.SetAtlas(row.chevron, data.collapsed and ATLAS_PLUS or ATLAS_MINUS)
		row.chevron:Show()

		row.name:SetFontObject(GameFontHighlight or GameFontNormal)
		row.name:SetJustifyH("LEFT")
		-- The name anchors to the row, not to the chevron: a region anchored to another region of
		-- the same frame does not always follow when that frame is re-anchored in the same pass.
		-- The chevron is 13 wide in both states, so the offset stays the same.
		local chevronWidth = row.chevron:GetWidth() or 0
		if chevronWidth <= 0 then
			chevronWidth = CHEVRON_W
		end
		row.name:SetPoint("LEFT", row, "LEFT",
			CHEVRON_X + chevronWidth + SUBNAME_GAP, 0)
		row.name:SetPoint("RIGHT", row.bar, "LEFT", NAME_GAP, 0)

		if data.hasRep then
			row.bar:Show()
			placeBar(row, data)
		else
			row.bar:Hide()
		end
	else
		-- Entry.
		row:SetHeight(ENTRY_H)
		row.bar:Show()
		row.arrow:Hide()
		row.chevron:Hide()
		row.name:SetFontObject(GameFontHighlight or GameFontNormal)
		row.name:SetJustifyH("LEFT")
		row.name:SetPoint("LEFT", row, "LEFT", NAME_X, 0)
		row.name:SetPoint("RIGHT", row.bar, "LEFT", NAME_GAP, 0)
		placeBar(row, data)
	end

	-- Selection is kept by name: collapsing renumbers factions, so an index would move.
	row.selectedItem = (selectedItem ~= nil and selectedItem == data.name)
	placeHover(row)
	row:Show()
end

-- ---------- Data

-- Reads one faction. GetFactionInfo returns: name, description, standing, bottom and top
-- thresholds, value, atWar, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild.
local function readFaction(rank)
	local name, _, standingId, threshold, following, value, atWar, _, header,
		collapsed, hasRep, _, child = GetFactionInfo(rank)
	if not name then
		return nil
	end

	local maximum, current = 1, 1
	local full = (standingId == (MAX_REPUTATION_REACTION or 8))
	if not full then
		maximum = (following or 0) - (threshold or 0)
		current = (value or 0) - (threshold or 0)
	end

	local label = ""
	if GetText then
		label = GetText("FACTION_STANDING_LABEL" .. tostring(standingId),
			UnitSex and UnitSex("player")) or ""
	end

	return {
		index = rank,
		name = name,
		standingId = standingId,
		value = current,
		maximum = maximum,
		header = header,
		child = child,
		hasRep = hasRep,
		collapsed = collapsed,
		atWar = atWar,
		label = label,
		progression = (not full)
			and (tostring(current) .. " / " .. tostring(maximum)) or nil,
	}
end

-- Indent, as in SetElementIndentCalculator.
local function indentOf(data)
	if data.header and not data.child then
		return HEADER_INDENT
	end
	if not data.header and data.child then
		return CHILD_INDENT
	end
	return OTHER_INDENT
end

local function heightOf(data)
	if data.header then
		return data.child and SUBHEADER_H or HEADER_H
	end
	return ENTRY_H
end

-- Hides every region and child frame of the client ReputationFrame, on each pass:
-- ReputationFrame_Update shows its rows and art again every time. GetRegions only returns
-- regions and GetChildren only frames, so both are needed. The detail frame lives elsewhere.
local function suppressClientScreen()
	local frame = _G["ReputationFrame"]
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

-- One pass: stacks rows from the offset down to the bottom margin; returns how many were placed.
-- Stops at GetNumFactions: GetFactionInfo still answers past it (the Inactive header).
local function layout()
	local total = (GetNumFactions and GetNumFactions()) or 0
	local usableHeight = (panel:GetHeight() or 0)
	if usableHeight < 50 then
		usableHeight = PANE_H + LIST_Y - LIST_Y2
	end
	local usableWidth = (panel:GetWidth() or 0)
	if usableWidth < 50 then
		usableWidth = PANE_W + LIST_X2 - LIST_X
	end

	-- Row heights vary by template, so rows are stacked, not divided.
	local y = MARGIN
	local placedCount = 0
	for rank, row in ipairs(rows) do
		local index = offset + rank
		local data = (index <= total) and readFaction(index) or nil
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

-- Collapsing removes children from the client's numbering, so the list shrinks.
-- If the offset is then too large, it is clamped and the list laid out again.
local function layoutList()
	if not panel then
		return
	end

	suppressClientScreen()

	local total = (GetNumFactions and GetNumFactions()) or 0
	local placedCount = layout()

	if offset > 0 and offset + placedCount > total then
		offset = math.max(0, total - placedCount)
		placedCount = layout()
	end

	visibleCount = placedCount

	if panel.bar then
		panel.bar:Configure(total, placedCount, offset)
	end

	-- The detail pane follows the selection. It is defined below, so it is reached through
	-- ForeverUI; a plain name would resolve to a global.
	if ForeverUI.ReputationDetail then
		ForeverUI.ReputationDetail()
	end
end
ForeverUI.ReputationLayout = layoutList

-- ---------- Build

-- Every frame: hover highlight and bar text of each shown row.
local function trackHover()
	for _, row in ipairs(rows) do
		if row:IsShown() and not row.header then
			placeHover(row)

			-- On hover the bar shows progress, otherwise the standing (TryShowBarProgressText).
			local hovered = row:IsMouseOver()
			if hovered ~= row.lastHovered then
				row.lastHovered = hovered
				if hovered and row.progression then
					row.bar.text:SetText(row.progression)
				else
					row.bar.text:SetText(row.label or "")
				end
			end
		end
	end
end

-- Builds the list over the client ReputationFrame. host: left pane frame.
local function build(host)
	local frame = _G["ReputationFrame"]
	if not frame or not host then
		return nil, {}
	end

	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)

	if panel then
		return nil, { frame }
	end

	-- The client's art and rows are hidden by suppressClientScreen on every pass, the first
	-- included. Only the frame itself (as parent) and its read functions are used.
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

	panel = CreateFrame("Frame", "ForeverUIReputationList", frame)
	panel:SetPoint("TOPLEFT", host, "TOPLEFT", LIST_X, LIST_Y)
	panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", LIST_X2, LIST_Y2)
	panel:SetWidth(width)

	-- Enough rows for the densest case (only sub-headers, the shortest); layout stops at the
	-- bottom margin.
	local position = math.floor((height + LIST_Y - LIST_Y2) / (SUBHEADER_H + GAP))
	if position < 1 then
		position = 1
	end
	for index = 1, position do
		local row = createRow(index, width)
		row:SetScript("OnClick", function(self)
			if not self.factionIndex then
				return
			end
			-- Headers and sub-headers both collapse.
			if self.header then
				if self.collapsed then
					ExpandFactionHeader(self.factionIndex)
				else
					CollapseFactionHeader(self.factionIndex)
				end
			else
				-- Selection goes through the client: ReputationFrame_Update fills the description and the
				-- three checkboxes, only while its detail frame is shown.
				local frame = _G["ReputationDetailFrame"]
				if frame then
					frame:Show()
				end
				ForeverUI.ReputationSelect(self.factionName)
			end
		end)
		rows[index] = row
	end

	-- Both lines live on our panel: every region of the client frame is hidden on each pass.
	local top = panel:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(top, ATLAS_LINE)
	top:SetPoint("CENTER", panel, "TOP", 0, 0)

	local down = panel:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(down, ATLAS_LINE)
	down:SetPoint("CENTER", panel, "BOTTOM", 0, 0)

	-- camelot scroll bar, right of the list. It only takes three numbers and returns the new
	-- offset.
	panel.bar = ForeverUI.CreateScrollBar("ForeverUIReputationScrollBar",
		frame, panel)
	panel.bar.onScroll = function(new)
		offset = new
		layoutList()
	end
	-- Without a scroll bar the list takes its space: right edge from -25 to -10 (left margin).
	panel.bar.onVisibility = function(hasBar)
		local x2 = hasBar and LIST_X2 or -LIST_X
		panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", x2, LIST_Y2)
		panel:SetWidth(width + x2 - LIST_X2)
		layout()
	end

	panel:SetScript("OnUpdate", trackHover)
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(self, direction)
		local total = (GetNumFactions and GetNumFactions()) or 0
		offset = math.max(0, math.min(offset - direction, total - visibleCount))
		layoutList()
	end)

	layoutList()
	return nil, { frame }
end

-- /fui reput: prints what the client returns for each visible row and how it is laid out,
-- to tell wrong data from wrong display. filter: keep only rows whose name contains it.
function ForeverUI.ReputationDebug(filter)
	local say = function(text)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
	end

	local down = filter and string.lower(filter)
	local function keep(name)
		if not down then
			return true
		end
		return name and string.find(string.lower(name), down, 1, true) ~= nil
	end

	local total = (GetNumFactions and GetNumFactions()) or 0
	say(string.format(L.REPUTATIONTAB_DEBUG_SUMMARY,
		total, offset, #rows, visibleCount))

	-- What the client exposes, row by row with flags: it decides the hierarchy.
	say(L.REPUTATIONTAB_DEBUG_CLIENT)
	for rank = 1, total do
		local name, _, standingId, threshold, following, value, _, _, header, collapsed,
			hasRep, _, child = GetFactionInfo(rank)
		if keep(name) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			L.REPUTATIONTAB_DEBUG_CLIENT_ROW,
			rank, tostring(name), tostring(header), tostring(child),
			tostring(collapsed), tostring(hasRep), tostring(standingId),
			tostring(threshold), tostring(following), tostring(value)))
		end
	end

	-- Geometry of each placed row: position, name anchors and their count
	-- (an extra anchor reveals a missing ClearAllPoints).
	say(L.REPUTATIONTAB_DEBUG_GEOMETRY)
	for rank, row in ipairs(rows) do
		if row:IsShown() and keep(row.factionName) then
			local p, _, _, x, y = row:GetPoint(1)
			-- Anchor targets: most row pieces have no name, so they are identified by reference.
			local knownItems = {
				[row] = "row", [row.chevron] = "chevron",
				[row.bar] = "bar", [row.arrow] = "arrow",
				[row.hover] = "hover", [row.name] = "name",
				[panel] = "panel",
			}
			for index2, other in ipairs(rows) do
				knownItems[other] = knownItems[other] or ("row" .. index2)
				knownItems[other.chevron] = knownItems[other.chevron]
					or ("chevron" .. index2)
				knownItems[other.bar] = knownItems[other.bar] or ("bar" .. index2)
			end

			local anchors = {}
			for number = 1, (row.name:GetNumPoints() or 0) do
				local np, target, nrp, nx, ny = row.name:GetPoint(number)
				local targetName = knownItems[target]
					or (target and target.GetName and target:GetName())
					or L.REPUTATIONTAB_DEBUG_UNKNOWN
				local edge = "?"
				if target and target.GetLeft and target:GetLeft() then
					edge = string.format(L.REPUTATIONTAB_DEBUG_EDGES,
						target:GetLeft() - (panel:GetLeft() or 0),
						(target:GetRight() or 0) - (panel:GetLeft() or 0))
				end
				anchors[#anchors + 1] = string.format("%s>%s.%s(%s,%s)[%s]",
					tostring(np), targetName, tostring(nrp), tostring(nx),
					tostring(ny), edge)
			end
			-- Resolved position, relative to the panel so scrolling does not skew the comparison.
			local ox = panel:GetLeft() or 0
			local oy = panel:GetTop() or 0
			local function position(object)
				local g = object.GetLeft and object:GetLeft()
				local h = object.GetTop and object:GetTop()
				if not g or not h then
					return "?"
				end
				return string.format("%.1f,%.1f", g - ox, h - oy)
			end

			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				L.REPUTATIONTAB_DEBUG_ROW_GEOMETRY,
				rank, tostring(row.factionName), tostring(p), tostring(x),
				tostring(y), tostring(row:GetWidth()), tostring(row:GetHeight()),
				tostring(row.chevron:GetWidth()),
				tostring(row.chevron:GetHeight()),
				tostring(row.chevron:IsShown()),
				tostring(row.name:GetNumPoints()),
				table.concat(anchors, " ")))
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				L.REPUTATIONTAB_DEBUG_ROW_RESOLVED,
				position(row), position(row.chevron), position(row.name),
				row.name:GetWidth() or -1,
				tostring(row.name.GetJustifyH and row.name:GetJustifyH()),
				tostring(row.name.GetFontObject and row.name:GetFontObject()
					and row.name:GetFontObject():GetName())))
		end
	end

	say(L.REPUTATIONTAB_DEBUG_PLACED)

	for rank, row in ipairs(rows) do
		local name, _, standingId, threshold, following, value, atWar, _, header,
			collapsed = GetFactionInfo(offset + rank)
		if row:IsShown() and keep(name) then
			local r, v, b = row.bar.fill:GetVertexColor()
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				L.REPUTATIONTAB_DEBUG_PLACED_ROW,
				rank, tostring(name), tostring(header), tostring(standingId),
				tostring(threshold), tostring(following), tostring(value),
				tostring(row.bar:IsShown()),
				tostring(row.bar.fill:GetWidth()),
				tostring(row.bar.fill:IsShown()),
				r or -1, v or -1, b or -1))
		end
	end
end

-- ---------- Right pane: detail of the selected faction
-- Layout after camelot CharacterFrameSidePaneTemplate and ReputationDetailFrame.
-- The client's ReputationDetailFrame is kept and moved here: ReputationFrame_Update fills its
-- name, description and three checkboxes for the selected faction, only while it is shown.
-- camelot's description scrolls (ScrollingFontTemplate, missing in 3.3.5); ours is bounded.

local RIGHT_PANE_X, RIGHT_PANE_Y = 16, -14
local RIGHT_PANE_X2, RIGHT_PANE_Y2 = -12, 14
local TITLE_W = 195
local SUBTITLE_Y = -3
local SEPARATOR_Y = -4
local DETAIL_GAUGE_W, DETAIL_GAUGE_H = 180, 29
local DETAIL_GAUGE_Y = -6
local DESCRIPTION_Y = -6
local DESCRIPTION_X2 = -14
local DESCRIPTION_Y2 = 6                -- gap above the checkboxes
local CHECKBOX = 26
local CHECKBOX_X, CHECKBOX_GAP = -4, -2
local CHECKBOX_LABEL_L = 158
local CHECKBOX_LABEL_X = 2

local ATLAS_CHECKBOX = "checkbox-minimal"
local ATLAS_CHECKMARK = "checkmark-minimal"
local ATLAS_SEPARATOR = "ui-character-info-scrollline"
local CHECKMARK = "Interface\\Buttons\\UI-CheckBox-SwordCheck"
local CHECK_SIDE = 32
local CHECKMARK_X, CHECKMARK_Y = 3, -5

local detail

-- The client's three checkboxes, moved and reskinned; their logic stays the client's.
-- All use checkbox-minimal; At War checks with crossed swords (UI-CheckBox-SwordCheck),
-- the others with checkmark-minimal (camelot ReputationFrame.xml).
local CHECKBOXES = {
	{ name = "ReputationDetailAtWarCheckBox", red = true, swords = true },
	{ name = "ReputationDetailInactiveCheckBox" },
	{ name = "ReputationDetailMainScreenCheckBox" },
}

-- Reskins a client checkbox once. red: red label; swords: sword check mark.
local function skinCell(checkbox, red, swords)
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

	-- Check mark: At War uses the client file UI-CheckBox-SwordCheck, 32 at (3, -5);
	-- the others the checkmark-minimal atlas, centered.
	local checkMark = checkbox:CreateTexture(nil, "OVERLAY")
	if swords then
		checkMark:SetTexture(CHECKMARK)
		checkMark:SetWidth(CHECK_SIDE)
		checkMark:SetHeight(CHECK_SIDE)
		checkMark:SetPoint("TOPLEFT", checkbox, "TOPLEFT", CHECKMARK_X, CHECKMARK_Y)
	else
		ForeverUI.SetAtlas(checkMark, ATLAS_CHECKMARK)
		checkMark:SetPoint("CENTER", checkbox, "CENTER", 0, 0)
	end
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
		if red and RED_FONT_COLOR then
			label:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
		end
	end

	checkbox.foreverSkinDone = true
end

-- Check marks follow the state the client just set.
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

-- Shows or hides the three checkboxes.
local function showCells(state)
	for _, desc in ipairs(CHECKBOXES) do
		local checkbox = _G[desc.name]
		if checkbox then
			if state then checkbox:Show() else checkbox:Hide() end
		end
	end
end

-- Current index of a faction, by name. Move to Inactive renumbers the list, so the detail
-- keeps the name, looks up the index on each pass and gives it back to the client.
local function indexOf(name)
	if not name then
		return nil
	end
	for rank = 1, (GetNumFactions and GetNumFactions()) or 0 do
		if GetFactionInfo(rank) == name then
			return rank
		end
	end
	return nil
end

local function clearDetail()
	detail.title:SetText("")
	detail.subtitle:SetText("")
	detail.description:SetText("")
	detail.separator:Hide()
	detail.gauge:Hide()
	showCells(false)
end

local lastData

local function updateDetail()
	if not detail then
		return
	end

	-- Nothing selected: empty pane.
	if not selectedItem then
		lastData = nil
		clearDetail()
		return
	end

	local index = indexOf(selectedItem)
	local data
	if index then
		if SetSelectedFaction and GetSelectedFaction
			and GetSelectedFaction() ~= index then
			SetSelectedFaction(index)
		end
		data = readFaction(index)
		lastData = data
	else
		-- The faction left the list (made inactive or its group collapsed): keep the last data.
		data = lastData
	end

	if not data or data.header then
		clearDetail()
		return
	end

	detail.title:SetText(data.name or "")
	detail.subtitle:SetText(data.label or "")
	detail.separator:Show()

	detail.gauge:Show()
	placeBarIn(detail.gauge, data, DETAIL_GAUGE_W)
	detail.gauge.text:SetText(data.progression or data.label or "")

	-- The description comes from the client: ReputationFrame_Update sets it for the selection.
	local source = _G["ReputationDetailFactionDescription"]
	detail.description:SetText((source and source:GetText()) or "")

	showCells(true)
	syncCheckboxes()
end
ForeverUI.ReputationDetail = updateDetail

-- Selects a faction by name; nil empties the right pane.
local function choose(name)
	selectedItem = name
	local index = indexOf(name)
	if index and SetSelectedFaction then
		SetSelectedFaction(index)
	end
	if ReputationFrame_Update then
		ReputationFrame_Update()
	else
		layoutList()
	end
end
ForeverUI.ReputationSelect = choose

-- Moves the client's ReputationDetailFrame into the right pane. host: right pane frame.
local function buildDetail(host)
	if detail then
		return detail, {}
	end

	local frame = _G["ReputationDetailFrame"]
	if not frame or not host then
		return nil, {}
	end

	-- The client frame becomes our pane: no window art, spread over camelot's pane area.
	frame:SetParent(host)
	if frame.SetToplevel then
		frame:SetToplevel(false)
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", host, "TOPLEFT", RIGHT_PANE_X, RIGHT_PANE_Y)
	frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", RIGHT_PANE_X2, RIGHT_PANE_Y2)
	-- Its <Backdrop> is not a region, so GetRegions misses it: SetBackdrop(nil) removes it.
	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end

	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
	local close = _G["ReputationDetailCloseButton"]
	if close then
		close:Hide()
	end

	detail = frame

	-- camelot uses GameFontNormalMed3, missing in 3.3.5; GameFontNormalLarge is the closest.
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

	-- Pane gauge: same template as the list bars, 180 wide.
	local gauge = CreateFrame("Frame", "ForeverUIReputationStanding", frame)
	gauge:SetWidth(DETAIL_GAUGE_W)
	gauge:SetHeight(DETAIL_GAUGE_H)
	gauge:SetPoint("TOP", detail.separator, "BOTTOM", 0, DETAIL_GAUGE_Y)
	ForeverUI.CreateNineSlice(gauge, ATLAS_BAR_BACKGROUND, GAUGE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND")
	gauge.fill = gauge:CreateTexture(nil, "BORDER")
	gauge.fill:SetPoint("LEFT", gauge, "LEFT", 0, 0)
	gauge.text = gauge:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	gauge.text:SetPoint("LEFT", gauge, "LEFT", 0, 0)
	gauge.text:SetPoint("RIGHT", gauge, "RIGHT", 0, 0)
	gauge.text:SetJustifyH("CENTER")
	detail.gauge = gauge

	-- Footer height: three checkboxes and two gaps. The description ends just above.
	local footer = 3 * CHECKBOX + 2 * (-CHECKBOX_GAP)

	-- The client description is only a source: hidden, and copied into ours.
	for _, name in ipairs({ "ReputationDetailFactionDescription",
		"ReputationDetailFactionName" }) do
		local piece = _G[name]
		if piece then
			piece:Hide()
		end
	end

	-- GameFontHighlight: camelot's GameFontNormal is gold in 3.3.5, the reference text is white.
	-- Anchored on all four sides so long text wraps inside the box.
	detail.description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	detail.description:SetPoint("TOPLEFT", gauge, "BOTTOMLEFT", 0, DESCRIPTION_Y)
	detail.description:SetPoint("TOPRIGHT", gauge, "BOTTOMRIGHT", 0, DESCRIPTION_Y)
	detail.description:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, footer + DESCRIPTION_Y2)
	detail.description:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
		DESCRIPTION_X2, footer + DESCRIPTION_Y2)
	detail.description:SetJustifyH("LEFT")
	detail.description:SetJustifyV("TOP")
	if detail.description.SetWordWrap then
		detail.description:SetWordWrap(true)
	end

	-- Footer: the three checkboxes, stacked from the bottom of the pane.
	local prev
	for _, desc in ipairs(CHECKBOXES) do
		local checkbox = _G[desc.name]
		if checkbox then
			skinCell(checkbox, desc.red, desc.swords)
			checkbox:SetParent(frame)
			checkbox:ClearAllPoints()
			if prev then
				checkbox:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, CHECKBOX_GAP)
			else
				checkbox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", CHECKBOX_X, footer)
			end
			prev = checkbox
		end
	end

	frame:Show()
	updateDetail()
	return frame, {}
end

ForeverUI.ReputationTab = { Build = build, BuildRight = buildDetail, Rows = rows }

-- The client handles UPDATE_FACTION in ReputationFrame_Update; hook it to redraw the list.
if hooksecurefunc and type(_G["ReputationFrame_Update"]) == "function" then
	hooksecurefunc("ReputationFrame_Update", layoutList)
end
