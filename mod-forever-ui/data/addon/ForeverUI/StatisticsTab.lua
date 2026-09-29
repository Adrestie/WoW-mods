-- ForeverUI: the character Statistics tab, after Camelot's blizzard_statistics (StatisticsFrame).
-- 3.3.5 has no ScrollBox or tree view, so the list is built by hand with recycled rows and the
-- ScrollBar.lua bar. The collapsed state survives CRITERIA_UPDATE (Camelot rebuilds its tree and
-- expands everything). Values are shown as the client returns them, as AchievementFrameStats_Update
-- does (Camelot shows only positive numbers), so the value column widens up to half the row.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local ROOT = -1                       -- ROOT_CATEGORY_ID

local LIST_X, LIST_Y = 10, -40
local LIST_X2, LIST_Y2 = -25, 15

local INDENT = 20                      -- CreateScrollBoxListTreeListView
local MARGIN = 10
local GAP = 3

local HEADER_H = 26                     -- StatisticsHeaderTemplate
local SUBHEADER_H = 22                -- StatisticsSubHeaderTemplate
local ENTRY_H = 24                     -- StatisticsEntryTemplate

local HEADER_NAME_X = 10
local ARROW_X, ARROW_Y = -8, -1
local ARROW_SPACE = 16
local NAME_H = 15
local NAME_X = 2
local NAME_GAP = -10
local VALUE_W, VALUE_X = 50, -12
local BUTTON_W, BUTTON_X = 20, 2
local SUBNAME_GAP = 4
local SUB_NAME_X2 = -24
local SIDE = 6
local PLATE_CORNER = 12                  -- as in the Skills and Reputation tabs
local HOVER_ALPHA = 0.10
local HEADER_HOVER_ALPHA = 0.3

local ATLAS_HEADER = "common-button-list-collapseexpand"
local ATLAS_PLUS = "common-button-list-plus"
local ATLAS_MINUS = "common-button-list-minus"
local ATLAS_LINE = "ui-character-info-scrollline-long"
local ATLAS_HOVER_SIDE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_HOVER_MIDDLE = "charactercreate-customize-dropdown-linemouseover-middle"
local ATLAS_CLOSED = "campaign_headericon_closed"
local ATLAS_CLOSED_PRESSED = "campaign_headericon_closedpressed"
local ATLAS_OPEN = "campaign_headericon_open"
local ATLAS_OPEN_PRESSED = "campaign_headericon_openpressed"
local BUTTON_HOVER = "Interface\\Buttons\\UI-PlusButton-Hilight"

-- Pane size, fixed by construction (as the Skills tab).
local PANE_W, PANE_H = 398, 464

local S = {}
ForeverUI.StatisticsTab = S

local rows = {}
local panel, measure, offset = nil, nil, 0
local visibleCount = 0
local collapsedSet = {}                      -- [category] = true
local elements = {}                     -- flattened list, as shown

-- --------------------------------------------------------------- Data

-- BuildOrderedCategoryIDs: ids in the order of their keys
local function orderedCategories(source)
	local entries = {}
	for key, value in next, source or {} do
		if value and type(key) == "number" then
			entries[#entries + 1] = { index = key, id = value }
		end
	end
	table.sort(entries, function(a, b) return a.index < b.index end)
	local ids = {}
	for _, e in ipairs(entries) do
		ids[#ids + 1] = e.id
	end
	return ids
end

-- statistic value as the client returns it; -- when empty (AchievementFrameStats_Update)
local function valueText(quantity)
	if quantity == nil or quantity == "" then
		return "--"
	end
	return tostring(quantity)
end

-- tree: { id, name, children = { categories }, stats = { { name, value } } }
-- (BuildCategoryEntriesFromSource, AppendStatisticRows). In 3.3.5 GetStatistic takes the id
-- from GetAchievementInfo(category, rank), as AchievementFrameStats_Update does.
local function readTree()
	local order = orderedCategories(GetStatisticsCategoryList and GetStatisticsCategoryList())
	local roots, childrenOf = {}, {}
	for _, id in ipairs(order) do
		local _, parent = GetCategoryInfo(id)
		if parent == ROOT then
			roots[#roots + 1] = id
		else
			childrenOf[parent] = childrenOf[parent] or {}
			table.insert(childrenOf[parent], id)
		end
	end
	local seen = {}
	local function node(id)
		if seen[id] then
			return nil
		end
		seen[id] = true
		local n = { id = id, name = GetCategoryInfo(id) or UNKNOWN, stats = {}, children = {} }
		for rank = 1, (GetCategoryNumAchievements(id)) or 0 do
			local statID = GetAchievementInfo(id, rank)
			if statID then
				local quantity, skip = GetStatistic(statID)
				if not skip then
					local _, name = GetAchievementInfo(statID)
					n.stats[#n.stats + 1] = { name = name or UNKNOWN, value = valueText(quantity) }
				end
			end
		end
		for _, child in ipairs(childrenOf[id] or {}) do
			local e = node(child)
			if e then
				n.children[#n.children + 1] = e
			end
		end
		return n
	end
	local tree = {}
	for _, id in ipairs(roots) do
		local n = node(id)
		if n then
			tree[#tree + 1] = n
		end
	end
	return tree
end

-- Flattened list in TreeDataProvider order: a category, its statistics, then its
-- subcategories; nothing under a collapsed category.
local function flatten(tree)
	local list = {}
	local function descend(n, depth)
		list[#list + 1] = { kind = (depth == 1) and "header" or "sub", id = n.id,
			name = n.name, depth = depth }
		if collapsedSet[n.id] then
			return
		end
		for _, s in ipairs(n.stats) do
			list[#list + 1] = { kind = "stat", name = s.name, value = s.value, depth = depth + 1 }
		end
		for _, e in ipairs(n.children) do
			descend(e, depth + 1)
		end
	end
	for _, n in ipairs(tree) do
		descend(n, 1)
	end
	return list
end

-- --------------------------------------------------------------- Row

-- is the name cut? 3.3.5 has no IsTruncated: compares the full width, measured on a separate
-- unbounded text, with the box
local function isTruncated(text, font)
	local t = text:GetText()
	if not t or t == "" then
		return false
	end
	measure:SetFontObject(font)
	measure:SetText(t)
	return measure:GetStringWidth() > (text:GetWidth() or 0) + 0.5
end

local function tooltip(row)
	local name = row.name
	local font = (row.kind == "header") and (GameFontNormalLeft or GameFontNormal) or (GameFontHighlight or GameFontNormal)
	if isTruncated(name, font) then
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		GameTooltip:SetText(name:GetText())
		GameTooltip:Show()
	end
end

local function hideTooltip(row)
	if GameTooltip:GetOwner() == row then
		GameTooltip:Hide()
	end
end

local function createRow(index)
	local row = CreateFrame("Button", "ForeverUIStatisticsRow" .. index, panel)
	row:SetHeight(ENTRY_H)

	-- header: the plate, and the same in ADD on hover
	row.plate = ForeverUI.CreateNineSlice(row, ATLAS_HEADER, PLATE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	row.glow = ForeverUI.CreateNineSlice(row, ATLAS_HEADER, PLATE_CORNER,
		{ 0, 0, 0, 0 }, "HIGHLIGHT") or {}
	for _, t in ipairs(row.glow) do
		t:SetBlendMode("ADD")
		t:SetAlpha(HEADER_HOVER_ALPHA)
	end

	-- content of an entry or subheader: shifts when pressed
	local content = CreateFrame("Frame", nil, row)
	content:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	content:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.content = content

	local hover = CreateFrame("Frame", nil, content)
	hover:SetAllPoints(content)
	hover:SetAlpha(0)
	hover:SetFrameLevel(math.max(0, row:GetFrameLevel() - 1))
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
	for _, t in ipairs({ left, right, middle }) do
		t:SetVertexColor(1, 1, 1)
	end

	local value = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	value:SetJustifyH("RIGHT")
	value:SetWidth(VALUE_W)
	value:SetHeight(NAME_H)
	value:SetPoint("RIGHT", content, "RIGHT", VALUE_X, 0)
	row.value = value

	local name = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	name:SetHeight(NAME_H)
	name:SetJustifyH("LEFT")
	row.name = name

	-- header arrow, on the right
	local arrow = row:CreateTexture(nil, "BORDER")
	arrow:SetPoint("RIGHT", row, "RIGHT", ARROW_X, ARROW_Y)
	arrow:Hide()
	row.arrow = arrow

	-- subheader button, on the left
	local button = CreateFrame("Button", nil, content)
	button:SetWidth(BUTTON_W)
	button:SetHeight(BUTTON_W)
	button:SetPoint("LEFT", content, "LEFT", BUTTON_X, 0)
	button:SetNormalTexture(ForeverUI.AtlasEntry(ATLAS_CLOSED)[1])
	button:SetPushedTexture(ForeverUI.AtlasEntry(ATLAS_CLOSED_PRESSED)[1])
	button:SetHighlightTexture(BUTTON_HOVER, "ADD")
	button:Hide()
	row.button = button

	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnMouseDown", function(self)
		self.down = true
		S.ApplyOffset(self)
	end)
	row:SetScript("OnMouseUp", function(self)
		self.down = nil
		S.ApplyOffset(self)
	end)
	row:SetScript("OnEnter", function(self)
		S.ApplyHover(self)
		tooltip(self)
	end)
	row:SetScript("OnLeave", function(self)
		S.ApplyHover(self)
		hideTooltip(self)
	end)
	row:SetScript("OnClick", function(self)
		if self.category then
			S.Toggle(self.category)
		end
	end)
	button:SetScript("OnClick", function()
		if row.category then
			S.Toggle(row.category)
		end
	end)
	return row
end

-- atlas image at its size, centered in a button texture
local function placeImage(texture, atlas)
	if texture then
		ForeverUI.SetAtlas(texture, atlas)
		texture:ClearAllPoints()
		texture:SetPoint("CENTER", texture:GetParent(), "CENTER", 0, 0)
	end
end

-- RefreshBackgroundHighlightOpacity: 0.10 under the mouse; never for a header, which has its glow
function S.ApplyHover(row)
	if row.kind == "header" then
		row.hover:SetAlpha(0)
		return
	end
	row.hover:SetAlpha(row:IsMouseOver() and HOVER_ALPHA or 0)
end

-- pressed: a header's name or an entry's content shifts by (1, -1)
function S.ApplyOffset(row)
	local dx, dy = row.down and 1 or 0, row.down and -1 or 0
	if row.kind == "header" then
		row.content:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.content:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		row.name:SetPoint("LEFT", row, "LEFT", HEADER_NAME_X + dx, dy)
		row.name:SetPoint("RIGHT", row, "RIGHT", ARROW_X - ARROW_SPACE + dx, dy)
	else
		row.content:SetPoint("TOPLEFT", row, "TOPLEFT", dx, dy)
		row.content:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", dx, dy)
	end
end

-- Fills row with list element e. SetFontObject clears the justification, so it is set again
-- after it (see SkillsTab.lua).
local function populateRow(row, e)
	row.kind = e.kind
	row.category = (e.kind ~= "stat") and e.id or nil
	row.down = nil
	row.name:SetText(e.name or "")
	row.name:ClearAllPoints()
	local header = e.kind == "header"
	for _, t in ipairs(row.plate) do
		if header then t:Show() else t:Hide() end
	end
	for _, t in ipairs(row.glow) do
		if header then t:Show() else t:Hide() end
	end
	if header then
		row:SetHeight(HEADER_H)
		row.name:SetFontObject(GameFontNormalLeft or GameFontNormal)
		row.name:SetJustifyH("LEFT")
		row.value:SetText("")
		row.button:Hide()
		ForeverUI.SetAtlas(row.arrow, collapsedSet[e.id] and ATLAS_PLUS or ATLAS_MINUS)
		row.arrow:Show()
	elseif e.kind == "sub" then
		row:SetHeight(SUBHEADER_H)
		row.name:SetFontObject(GameFontHighlight or GameFontNormal)
		row.name:SetJustifyH("LEFT")
		-- the name anchors to the content in place of the button (anchored to a sibling it drifts,
		-- see ReputationTab.lua)
		row.name:SetPoint("LEFT", row.content, "LEFT", BUTTON_X + BUTTON_W + SUBNAME_GAP, 0)
		row.name:SetPoint("RIGHT", row.content, "RIGHT", SUB_NAME_X2, 0)
		row.value:SetText("")
		row.arrow:Hide()
		local closed = collapsedSet[e.id]
		placeImage(row.button:GetNormalTexture(), closed and ATLAS_CLOSED or ATLAS_OPEN)
		placeImage(row.button:GetPushedTexture(), closed and ATLAS_CLOSED_PRESSED or ATLAS_OPEN_PRESSED)
		row.button:Show()
	else
		row:SetHeight(ENTRY_H)
		row.name:SetFontObject(GameFontHighlight or GameFontNormal)
		row.name:SetJustifyH("LEFT")
		row.name:SetPoint("LEFT", row.content, "LEFT", NAME_X, 0)
		row.name:SetPoint("RIGHT", row.value, "LEFT", NAME_GAP, 0)
		row.value:SetText(e.value or "--")
		-- value column: 50, or the value's width, up to half the row
		measure:SetFontObject(GameFontHighlight or GameFontNormal)
		measure:SetText(e.value or "--")
		local cap = math.floor((row:GetWidth() or 0) / 2)
		row.value:SetWidth(math.max(VALUE_W, math.min(math.ceil(measure:GetStringWidth()), cap)))
		row.arrow:Hide()
		row.button:Hide()
	end
	S.ApplyOffset(row)
	S.ApplyHover(row)
	row:Show()
end

-- ------------------------------------------------------------- Layout

local function heightOf(e)
	return (e.kind == "header" and HEADER_H) or (e.kind == "sub" and SUBHEADER_H) or ENTRY_H
end

-- places the rows from offset; returns how many fit
local function layout()
	local usableHeight = panel:GetHeight() or 0
	if usableHeight < 50 then
		usableHeight = PANE_H + LIST_Y - LIST_Y2
	end
	local usableWidth = panel:GetWidth() or 0
	if usableWidth < 50 then
		usableWidth = PANE_W + LIST_X2 - LIST_X
	end
	local y = MARGIN
	local placedCount = 0
	for rank, row in ipairs(rows) do
		local e = elements[offset + rank]
		local height = e and heightOf(e) or 0
		if e and y + height <= usableHeight - MARGIN then
			local indent = (e.depth - 1) * INDENT
			row:SetWidth(usableWidth - 2 * MARGIN - indent)
			populateRow(row, e)
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

-- lays out the list, clamps the offset and updates the bar
local function layoutList()
	if not panel then
		return
	end
	local total = #elements
	local placedCount = layout()
	if offset > 0 and offset + placedCount > total then
		offset = math.max(0, total - placedCount)
		placedCount = layout()
	end
	visibleCount = placedCount
	if panel.bar then
		panel.bar:Configure(total, placedCount, offset)
	end
end

-- Update: re-reads the tree and lays out the list at the same offset
function S.Update()
	if not panel then
		return
	end
	elements = flatten(readTree())
	layoutList()
end

-- ToggleCollapsed of a category
function S.Toggle(category)
	collapsedSet[category] = not collapsedSet[category] or nil
	S.Update()
end

-- --------------------------------------------------------- Build

-- builds the tab once in pane host
local function build(host)
	if panel then
		return panel:GetParent(), {}
	end
	local root = CreateFrame("Frame", "ForeverUIStatisticsFrame", host)
	root:SetAllPoints(host)

	local height = host:GetHeight() or 0
	if height < 100 then
		height = PANE_H
	end
	local width = host:GetWidth() or 0
	if width < 100 then
		width = PANE_W
	end
	width = width + LIST_X2 - LIST_X

	panel = CreateFrame("Frame", "ForeverUIStatisticsList", root)
	panel:SetPoint("TOPLEFT", host, "TOPLEFT", LIST_X, LIST_Y)
	panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", LIST_X2, LIST_Y2)
	panel:SetWidth(width)

	measure = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	measure:SetAlpha(0)

	local position = math.floor((height + LIST_Y - LIST_Y2) / (SUBHEADER_H + GAP))
	if position < 1 then
		position = 1
	end
	for index = 1, position do
		rows[index] = createRow(index)
	end

	-- the two lines, centered on the list's top and bottom
	local top = panel:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(top, ATLAS_LINE)
	top:SetPoint("CENTER", panel, "TOP", 0, 0)
	local down = panel:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(down, ATLAS_LINE)
	down:SetPoint("CENTER", panel, "BOTTOM", 0, 0)

	-- Camelot scroll bar; without it, the list takes its room
	panel.bar = ForeverUI.CreateScrollBar("ForeverUIStatisticsScrollBar", root, panel)
	panel.bar.onScroll = function(new)
		offset = new
		layoutList()
	end
	panel.bar.onVisibility = function(hasBar)
		local x2 = hasBar and LIST_X2 or -LIST_X
		panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", x2, LIST_Y2)
		panel:SetWidth(width + x2 - LIST_X2)
		layout()
	end

	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_, direction)
		offset = math.max(0, math.min(offset - direction, #elements - visibleCount))
		layoutList()
	end)

	-- listens to CRITERIA_UPDATE while the tab is shown
	root:SetScript("OnShow", function(self)
		self:RegisterEvent("CRITERIA_UPDATE")
		S.Update()
	end)
	root:SetScript("OnHide", function(self)
		self:UnregisterEvent("CRITERIA_UPDATE")
	end)
	root:SetScript("OnEvent", function(_, ev)
		if ev == "CRITERIA_UPDATE" then
			S.Update()
		end
	end)
	root:RegisterEvent("CRITERIA_UPDATE")

	S.Update()
	return root, {}
end

S.Build = build
S.Rows = rows
