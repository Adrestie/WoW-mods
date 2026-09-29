-- ForeverUI: camelot's talent search (search box, options, preview, node markers).
--
-- From blizzard_playerspells (camelot/classtalents), blizzard_sharedtalentui (classtalentsearch,
-- talentbuttonart, sharedtalentbuttontemplates, sharedtalentutil) and blizzard_spellsearch:
--   box       SpellSearchBoxTemplate 184 x 30, 40 letters; same look as SpellBookSearch.lua
--   options   SearchOptionsDropdown (25 x 25 arrow, common-dropdown-a-button); two unsaved
--             options, Hide Passives and Show Ranks, that only change the preview
--             (TransformPreviewResults)
--   preview   SpellSearchPreviewContainerTemplate, 176 wide; name filter (exact, contains);
--             below 3 letters, the "Missing from action bar" suggestion
--   search    text filter (GetMatchTypeForText): exact, name, description, then related
--             (the talent's name is in the description of the exact match); or the action
--             bar filter: a learned active talent that is on no active bar
--   markers   no result list: each matching node gets a SearchIcon (talents-search-*,
--             63 x 63) centered on its icon's TOPRIGHT, with an ADD glow pulsing
--             0 -> 0.5 -> 0 over 2 s; hovering its 18 x 18 center shows its tooltip
--   update    results are recomputed on every screen update (UpdateFullSearchResults)
--
-- Differences: the box sits left of the "Unspent Talents" counter and shrinks in the small
-- window; the preview shows 5 results (camelot: 3), like the spellbook; 3.3.5 has no talent
-- description API, so it is read from a hidden tooltip (SetTalent) without its rank,
-- prerequisite and "Click to learn" lines; no box on the glyph page.

ForeverUI = ForeverUI or {}

local K = {}
ForeverUI.TalentsSearch = K

local SEP = string.char(92)
local L = ForeverUI.L
local TEXT = {
	instruction = SEARCH,
	notOnBar = L.TALENTSSEARCH_NOT_ON_ACTIONBAR,   -- TALENT_FRAME_SEARCH_NOT_ON_ACTIONBAR
	hidePassives = L.TALENTSSEARCH_HIDE_PASSIVES,   -- CLASS_TALENT_SEARCH_OPTION_HIDE_PASSIVES
	ranks = L.TALENTSSEARCH_SHOW_RANKS,               -- CLASS_TALENT_SEARCH_OPTION_SHOW_RANKS
	overflow = L.TALENTSSEARCH_PREVIEW_OVERFLOW,   -- TALENT_FRAME_SEARCH_PREVIEW_OVERFLOW_FORMAT
}
local MIN_LETTERS = 3                                 -- MIN_CHARACTER_SEARCH

-- SpellSearchUtil.MatchType: higher is better
local TYPE = { description = 1, name = 2, related = 3, exact = 4, absent = 5, inactiveStance = 6, disabledBar = 7 }
-- SearchMatchStyles (blizzard_sharedtalentutil.lua)
local STYLES = {
	[TYPE.related] = { icon = "talents-search-relatedmatch", info = L.TALENTSSEARCH_TOOLTIP_RELATED_MATCH },
	[TYPE.name] = { icon = "talents-search-match", info = L.TALENTSSEARCH_TOOLTIP_MATCH },
	[TYPE.description] = { icon = "talents-search-match", info = L.TALENTSSEARCH_TOOLTIP_MATCH },
	[TYPE.exact] = { icon = "talents-search-exactmatch", info = L.TALENTSSEARCH_TOOLTIP_EXACT_MATCH },
	[TYPE.absent] = { icon = "talents-search-notonactionbar", info = L.TALENTSSEARCH_TOOLTIP_NOT_ON_ACTIONBAR },
	[TYPE.inactiveStance] = { icon = "talents-search-notonactionbarhidden",
		info = L.TALENTSSEARCH_TOOLTIP_ON_INACTIVE_BONUSBAR },
	[TYPE.disabledBar] = { icon = "talents-search-notonactionbarhidden", info = L.TALENTSSEARCH_TOOLTIP_ON_DISABLED_ACTIONBAR },
}

local M = {
	boxW = 184, boxH = 30, maxLetters = 40, counterGap = 10, leftMargin = 10,
	arrow = 25, arrowX = 3, arrowY = -2,
	edgeW = 8, edgeH = 20, edgeX = -5, magnifier = 10, magnifierX = 1, magnifierY = -1, gray = 0.6,
	clear = 17, clearX = -3, clearIcon = 10, clearIconX = 3, clearIconY = -3,
	insetLeft = 16, insetRight = 20, instructionGray = 0.35,
	previewW = 176, previewX = -4, previewY = 2, rowH = 27, rows = 5, topMargin = 1, bottomMargin = 3,
	gap = 1, overflowH = 16, overflowY = 5, overflowX = 9,
	iconFrame = 18, iconFrameX = 5, iconFrameY = 1, nameX = 5, nameY = 1, nameRight = -5,
	suggMagnifier = 14, suggMagnifierX = 10, suggMagnifierY = 1, suggTextX = 10,
	-- node marker and its pulse
	marker = 63, markerHover = 18, pulse = 1, pulseAlpha = 0.5,
	-- options list (same as the spellbook settings list)
	menuRowH = 20, menuEdge = 15, menuRowX = 11, menuTextX = 20, extraWidth = 40, menuMargin = 25,
	checkbox = 12, checkMarkW = 15, checkMarkH = 14, checkMarkX = 2, checkMarkY = 1,
	backgroundCorner = 18, backgroundMargins = { 9, 6, 9, 12 }, backgroundAlpha = 0.925, pending = 2,
}

-- ------------------------------------------------------------ Strings
local function equals(a, b)
	return a and b and string.lower(a) == string.lower(b)
end
local function contains(parent, sub)
	return parent and sub and string.find(string.lower(parent), string.lower(sub), 1, true) ~= nil
end

-- ------------------------------------------------------------ Description
-- A talent tooltip without its name, rank and prerequisite lines or the learn prompt:
-- what remains is the description (and the next rank's).
local scanner = CreateFrame("GameTooltip", "ForeverUITalentsScanTooltip", nil, "GameTooltipTemplate")
-- Turns a client format string into a Lua pattern; its arguments may be numbered
-- ("Requires %1$d points in %2$s Talents": TOOLTIP_TALENT_TIER_POINTS).
local function motif(format)
	if not format then return nil end
	local m = string.gsub(format, "%%%d%$", "%%")
	m = string.gsub(m, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	m = string.gsub(m, "%%d", "%%d+")
	m = string.gsub(m, "%%s", ".+")
	return "^" .. m .. "$"
end
local EXCLUDED_LINES = {}
for _, f in ipairs({ TOOLTIP_TALENT_RANK, TOOLTIP_TALENT_NEXT_RANK, TOOLTIP_TALENT_LEARN,
	TOOLTIP_TALENT_TIER_POINTS, TOOLTIP_TALENT_PREREQ, TOOLTIP_TALENT_UNLEARN }) do
	local m = motif(f)
	if m then table.insert(EXCLUDED_LINES, m) end
end
local descriptions = {}
-- Cached description of talent t; T: the talents module (pet, group).
local function description(T, t)
	local key = (T.pet and "p" or "j") .. T.group .. ":" .. t.tab .. ":" .. t.index .. ":" .. t.rank
	local d = descriptions[key]
	if d == nil then
		local parts = {}
		scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
		scanner:ClearLines()
		scanner:SetTalent(t.tab, t.index, false, T.pet, T.group, true)
		for i = 2, scanner:NumLines() do
			local row = _G["ForeverUITalentsScanTooltipTextLeft" .. i]
			local text = row and row:GetText()
			if text and text ~= "" then
				local excluded = false
				for _, m in ipairs(EXCLUDED_LINES) do
					local ok, match = pcall(string.find, text, m)
					if ok and match then excluded = true break end
				end
				if not excluded then table.insert(parts, text) end
			end
		end
		scanner:Hide()
		d = table.concat(parts, "\n")
		descriptions[key] = d
	end
	return d
end
K.description = description

-- ------------------------------------------------------------ State
K.state = nil                      -- { filter = "text", text } | { filter = "bars" }
K.options = { passives = false, ranks = false }
local T                           -- ForeverUI.Talents, set by K.build

-- talents on screen, in order (tree, tier, column)
local function talents()
	local list = {}
	for _, o in ipairs(T.tabs or {}) do
		for _, t in ipairs(o.talents) do table.insert(list, t) end
	end
	table.sort(list, function(a, b)
		if a.tab ~= b.tab then return a.tab < b.tab end
		if a.tier ~= b.tier then return a.tier < b.tier end
		return a.column < b.column
	end)
	return list
end

-- GetActionbarStatusForSpell: a learned active talent that is on no active bar.
-- bars: action bar spell sets from SpellBookSearch.bars()
local function barType(t, bars)
	if not t.square or (t.learned or 0) == 0 then return end
	if T.pet then
		if bars.pet[t.name] then return end
		return TYPE.absent
	end
	if bars.activeSet[t.name] then return end
	if bars.disabled[t.name] then return TYPE.disabledBar end
	if bars.inactive[t.name] then return TYPE.inactiveStance end
	return TYPE.absent
end

-- match types of the current search, per talent ("tab:index")
function K.compute()
	local state = K.state
	local types = {}
	if not state then return types end
	local all = talents()
	if state.filter == "bars" then
		local R = ForeverUI.SpellBookSearch
		local bars = R and R.bars and R.bars()
		if bars then
			for _, t in ipairs(all) do
				types[t.tab .. ":" .. t.index] = barType(t, bars)
			end
		end
		return types
	end
	local text = state.text
	local exactDesc
	for _, t in ipairs(all) do
		if equals(t.name, text) then
			exactDesc = description(T, t)
			break
		end
	end
	for _, t in ipairs(all) do
		local ty
		if equals(t.name, text) then
			ty = TYPE.exact
		elseif contains(t.name, text) then
			ty = TYPE.name
		elseif contains(description(T, t), text) then
			ty = TYPE.description
		elseif exactDesc and contains(exactDesc, t.name) then
			ty = TYPE.related
		end
		types[t.tab .. ":" .. t.index] = ty
	end
	return types
end

-- preview: the name filter, then the options (TransformPreviewResults)
function K.preview(text)
	local matches = {}
	for _, t in ipairs(talents()) do
		local ty
		if equals(t.name, text) then ty = TYPE.exact elseif contains(t.name, text) then ty = TYPE.name end
		if ty and not (K.options.passives and not t.square) then
			local name = t.name
			if K.options.ranks then name = name .. " (" .. t.rank .. "/" .. t.max .. ")" end
			table.insert(matches, { talent = t, type = ty, name = name, searching = t.name, icon = t.icon })
		end
	end
	-- PreviewSearchResultSort: by type, then screen order
	local order = {}
	for i, r in ipairs(matches) do order[r] = i end
	table.sort(matches, function(a, b)
		if a.type ~= b.type then return a.type > b.type end
		return order[a] < order[b]
	end)
	return matches
end

-- ------------------------------------------------------------ Markers
local function createMarker(b)
	local m = CreateFrame("Frame", nil, b)
	m:SetWidth(M.marker)
	m:SetHeight(M.marker)
	m:SetPoint("CENTER", b.icon, "TOPRIGHT", 0, 0)
	m:SetFrameLevel(b:GetFrameLevel() + 50)
	local icon = m:CreateTexture(nil, "OVERLAY")
	icon:SetAllPoints(m)
	local beatGlow = m:CreateTexture(nil, "OVERLAY")
	beatGlow:SetAllPoints(m)
	beatGlow:SetBlendMode("ADD")
	beatGlow:SetAlpha(0)
	m.icon, m.beatGlow = icon, beatGlow
	-- hover: its center only
	local hover = CreateFrame("Frame", nil, m)
	hover:SetWidth(M.markerHover)
	hover:SetHeight(M.markerHover)
	hover:SetPoint("CENTER", m, "CENTER", 0, 0)
	hover:EnableMouse(true)
	hover:SetScript("OnEnter", function(self)
		if not m.info then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(m.info, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		GameTooltip:Show()
	end)
	hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
	m.hover = hover
	-- GlowAnim: 0 -> 0.5 in 1 s, then 0.5 -> 0 in 1 s, looping
	m:SetScript("OnUpdate", function(self, elapsed)
		self.clock = ((self.clock or 0) + elapsed) % (2 * M.pulse)
		local t = self.clock
		local a = t < M.pulse and t / M.pulse or 2 - t / M.pulse
		self.beatGlow:SetAlpha(a * M.pulseAlpha)
	end)
	m:Hide()
	b.marker = m
	-- a marker sits very high (node + 50): raise the close button above it again
	if T.raiseCloseButton then T.raiseCloseButton() end
	return m
end

-- SetSearchMatchType on each shown node
local function mark(types)
	for _, b in pairs(T.tree and T.tree.nodes or {}) do
		local t = b:IsShown() and b.talent
		local ty = t and types[t.tab .. ":" .. t.index]
		if ty then
			local m = b.marker or createMarker(b)
			local style = STYLES[ty]
			ForeverUI.SetAtlas(m.icon, style.icon, true)
			ForeverUI.SetAtlas(m.beatGlow, style.icon, true)
			m.info = style.info
			m.type = ty
			m:Show()
		elseif b.marker then
			b.marker.type = nil
			b.marker:Hide()
		end
	end
end

-- ------------------------------------------------------------ Search box
local box, clear, preview, arrow, list

-- box text if it has at least MIN_LETTERS letters, else nil
local function evaluate()
	local t = box:GetText() or ""
	if string.len(t) >= MIN_LETTERS then return t end
end

local function hidePreview()
	preview:Hide()
	preview.highlighted = 0
end

local function updateMagnifier()
	local active = box:HasFocus() or (box:GetText() or "") ~= ""
	local g = active and 1 or M.gray
	box.magnifier:SetVertexColor(g, g, g)
	if (box:GetText() or "") == "" then box.instruction:Show() else box.instruction:Hide() end
	if active then clear:Show() else clear:Hide() end
end

-- SetFullResultSearch
function K.find(text)
	if not text then
		K.quit()
		return
	end
	if equals(text, TEXT.notOnBar) then
		K.state = { filter = "bars" }
	else
		K.state = { filter = "text", text = text }
	end
	K.update()
end

-- ClearActiveSearchState
function K.quit()
	K.state = nil
	if box then
		box:ClearFocus()
		box:SetText("")
		hidePreview()
		updateMagnifier()
	end
	K.update()
end

-- ------------------------------------------------------------ Preview
local function resultRow(parent, i)
	local l = CreateFrame("Button", "ForeverUITalentsSearchResult" .. i, parent)
	l:SetHeight(M.rowH)
	local e = ForeverUI.AtlasEntry("_search-rowbg")
	l:SetNormalTexture(e and e[1] or "")
	ForeverUI.SetAtlas(l:GetNormalTexture(), "_search-rowbg", true)
	l:SetPushedTexture(e and e[1] or "")
	ForeverUI.SetAtlas(l:GetPushedTexture(), "_search-rowbg", true)
	local hovered = CreateFrame("Frame", nil, l)
	hovered:SetAllPoints(l)
	hovered:SetFrameLevel(l:GetFrameLevel() + 1)
	l.hovered = hovered
	local highlighted = hovered:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(highlighted, "search-highlight", true)
	highlighted:SetAllPoints(l)
	highlighted:SetBlendMode("ADD")
	highlighted:Hide()
	l.highlighted = highlighted
	return l
end

local function buildPreview(parent)
	local a = CreateFrame("Frame", "ForeverUITalentsSearchPreview", parent)
	a:SetFrameStrata("HIGH")
	a:SetWidth(M.previewW)
	a:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", M.previewX, M.previewY)
	a:SetHeight(M.rowH)
	a:EnableMouse(true)
	a:Hide()
	local background = a:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "_search-rowbg", true)
	background:SetAllPoints(a)
	local leftCorner = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(leftCorner, "ui-frame-botcornerleft")
	leftCorner:SetPoint("LEFT", a, "LEFT", -7, 0)
	leftCorner:SetPoint("BOTTOM", a, "BOTTOM", 0, -7)
	local rightCorner = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(rightCorner, "ui-frame-botcornerright")
	rightCorner:SetPoint("BOTTOM", leftCorner, "BOTTOM", 0, 0)
	rightCorner:SetPoint("RIGHT", a, "RIGHT", 4, 0)
	local down = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(down, "_ui-frame-bot", true)
	down:SetHeight(9)
	down:SetPoint("BOTTOMLEFT", leftCorner, "BOTTOMRIGHT", 0, 0)
	down:SetPoint("BOTTOMRIGHT", rightCorner, "BOTTOMLEFT", 0, 0)
	local left = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(left, "!ui-frame-lefttile", true)
	left:SetWidth(16)
	left:SetPoint("BOTTOMLEFT", leftCorner, "TOPLEFT", 0, 0)
	left:SetPoint("TOPLEFT", a, "TOPLEFT", -7, 2)
	local right = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(right, "!ui-frame-righttile", true)
	right:SetWidth(10)
	right:SetPoint("BOTTOMRIGHT", rightCorner, "TOPRIGHT", 1, 0)
	right:SetPoint("TOPRIGHT", a, "TOPRIGHT", 5, 2)

	a.rows = {}
	for i = 1, M.rows do
		local l = resultRow(a, i)
		l:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -M.topMargin - (i - 1) * (M.rowH + M.gap))
		l:SetPoint("TOPRIGHT", a, "TOPRIGHT", 0, -M.topMargin - (i - 1) * (M.rowH + M.gap))
		local frame = l.hovered:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(frame, "talents-search-suggestion-itemborder")
		frame:SetWidth(M.iconFrame)
		frame:SetHeight(M.iconFrame)
		frame:SetPoint("LEFT", l, "LEFT", M.iconFrameX, M.iconFrameY)
		local icon = l:CreateTexture(nil, "OVERLAY")
		icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
		local name = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		name:SetJustifyH("LEFT")
		name:SetPoint("LEFT", icon, "RIGHT", M.nameX, M.nameY)
		name:SetPoint("RIGHT", l, "RIGHT", M.nameRight, 0)
		l.icon, l.name = icon, name
		l:SetScript("OnEnter", function() K.toggleHighlight(i) end)
		l:SetScript("OnClick", function() K.choose(i) end)
		l:Hide()
		a.rows[i] = l
	end
	local sugg = resultRow(a, "Suggestion")
	sugg:SetPoint("TOPLEFT", a, "TOPLEFT", 0, 0)
	sugg:SetPoint("TOPRIGHT", a, "TOPRIGHT", 0, 0)
	local magnifier = sugg:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(magnifier, "talents-search-suggestion-magnifyingglass", true)
	magnifier:SetWidth(M.suggMagnifier)
	magnifier:SetHeight(M.suggMagnifier)
	magnifier:SetPoint("LEFT", sugg, "LEFT", M.suggMagnifierX, M.suggMagnifierY)
	local text = sugg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", magnifier, "RIGHT", M.suggTextX, 0)
	text:SetPoint("RIGHT", sugg, "RIGHT", -5, 0)
	text:SetText(TEXT.notOnBar)
	sugg.text = text
	sugg:SetScript("OnEnter", function() K.toggleHighlight(1) end)
	sugg:SetScript("OnClick", function() K.choose(1) end)
	sugg:Hide()
	a.suggestion = sugg
	local plus = CreateFrame("Frame", nil, a)
	plus:SetHeight(M.overflowH)
	plus:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 0, M.overflowY)
	plus:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, M.overflowY)
	local moreText = plus:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	moreText:SetJustifyH("LEFT")
	moreText:SetPoint("TOPLEFT", plus, "TOPLEFT", M.overflowX, 0)
	moreText:SetPoint("BOTTOMRIGHT", plus, "BOTTOMRIGHT", 0, 0)
	plus.text = moreText
	plus:Hide()
	a.overflow = plus
	a.highlighted = 0
	a:SetScript("OnUpdate", function(self)
		if not box:HasFocus() and not MouseIsOver(self) then hidePreview() end
	end)
	return a
end

function K.updatePreview(text)
	local a = preview
	a.highlighted = 0
	a.results = nil
	for _, l in ipairs(a.rows) do l:Hide() l.highlighted:Hide() end
	a.suggestion:Hide()
	a.suggestion.highlighted:Hide()
	a.overflow:Hide()
	if not text then
		a.suggestion:Show()
		a.count = 1
		a:SetHeight(M.rowH + M.bottomMargin)
		a:Show()
		return
	end
	local matches = K.preview(text)
	if #matches == 0 then
		hidePreview()
		return
	end
	a.results = matches
	local n = math.min(#matches, M.rows)
	for i = 1, n do
		local l = a.rows[i]
		l.name:SetText(matches[i].name)
		l.icon:SetTexture(matches[i].icon)
		l:Show()
	end
	a.count = n
	local h = M.topMargin + n * M.rowH + (n - 1) * M.gap + M.bottomMargin
	if #matches > M.rows then
		a.overflow.text:SetText(string.format(TEXT.overflow, #matches - M.rows))
		a.overflow:Show()
		h = h + M.overflowH
	end
	a:SetHeight(h)
	a:Show()
end

function K.toggleHighlight(i)
	local a = preview
	a.highlighted = i
	if a.results then
		for j, l in ipairs(a.rows) do
			if j == i then l.highlighted:Show() else l.highlighted:Hide() end
		end
	else
		if i == 1 then a.suggestion.highlighted:Show() else a.suggestion.highlighted:Hide() end
	end
end

-- moves the preview highlight; direction: -1 up, 1 down (wraps around)
local function browse(direction)
	local a = preview
	if not a:IsShown() or not a.count or a.count == 0 then return end
	local n, i = a.count, a.highlighted or 0
	if direction < 0 then i = (i - 2) % n + 1 else i = i % n + 1 end
	K.toggleHighlight(i)
end

-- OnPreviewSearchResultClicked: searches the original name (without "(rank/max)")
function K.choose(i)
	local a = preview
	PlaySound("igMainMenuOptionCheckBoxOn")
	local text
	if a.results then
		local r = a.results[i]
		if not r then return end
		text = r.searching
	else
		text = TEXT.notOnBar
	end
	box:ClearFocus()
	box:SetText(text)
	hidePreview()
	K.find(text)
end

-- ------------------------------------------------------------ Options
local function updateArrow()
	local state = "common-dropdown-a-button"
	if arrow.pressed and arrow.hover then
		state = "common-dropdown-a-button-pressedhover"
	elseif arrow.hover then
		state = "common-dropdown-a-button-hover"
	elseif arrow.pressed then
		state = "common-dropdown-a-button-pressed"
	elseif list and list:IsShown() then
		state = "common-dropdown-a-button-open"
	end
	ForeverUI.SetAtlas(arrow.icon, state)
end

local function updateCheckMarks()
	for _, l in ipairs(list.rows) do
		if K.options[l.key] then l.checkMark:Show() else l.checkMark:Hide() end
	end
end

local function buildOptions(parent)
	local b = CreateFrame("Button", "ForeverUITalentsSearchOptions", parent)
	arrow = b
	b:SetWidth(M.arrow)
	b:SetHeight(M.arrow)
	b:SetPoint("LEFT", box, "RIGHT", M.arrowX, M.arrowY)
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetPoint("CENTER", b, "CENTER", 0, -2)
	b:SetScript("OnEnter", function(self) self.hover = true updateArrow() end)
	b:SetScript("OnLeave", function(self) self.hover = false updateArrow() end)
	b:SetScript("OnMouseDown", function(self) self.pressed = true updateArrow() end)
	b:SetScript("OnMouseUp", function(self) self.pressed = false updateArrow() end)
	b:SetScript("OnClick", function()
		if list:IsShown() then list:Hide() else list.pending = 0 list:Show() end
		updateArrow()
	end)

	local l0 = CreateFrame("Frame", "ForeverUITalentsSearchOptionsList", parent)
	list = l0
	l0:SetFrameStrata("DIALOG")
	l0:EnableMouse(true)
	l0:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, 0)
	l0:Hide()
	local slices = ForeverUI.CreateNineSlice(l0, "common-dropdown-bg-c60", M.backgroundCorner, M.backgroundMargins, "BACKGROUND")
	for _, t in ipairs(slices or {}) do t:SetAlpha(M.backgroundAlpha) end
	l0.rows = {}
	local longest = 0
	for i, def in ipairs({ { key = "passives", text = TEXT.hidePassives }, { key = "ranks", text = TEXT.ranks } }) do
		local l = CreateFrame("Button", "ForeverUITalentsSearchOption" .. i, l0)
		l:SetHeight(M.menuRowH)
		l:SetPoint("TOPLEFT", l0, "TOPLEFT", M.menuRowX, -M.menuEdge - (i - 1) * M.menuRowH)
		l:SetHighlightTexture("Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight")
		l:GetHighlightTexture():SetBlendMode("ADD")
		local text = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
		text:SetPoint("LEFT", l, "LEFT", M.menuTextX, 0)
		text:SetText(def.text)
		longest = math.max(longest, text:GetStringWidth() or 0)
		local checkbox = l:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(checkbox, "common-dropdown-ticksquare", true)
		checkbox:SetWidth(M.checkbox)
		checkbox:SetHeight(M.checkbox)
		checkbox:SetPoint("LEFT", l, "LEFT", 0, 0)
		local checkMark = l:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(checkMark, "common-dropdown-icon-checkmark-yellow", true)
		checkMark:SetWidth(M.checkMarkW)
		checkMark:SetHeight(M.checkMarkH)
		checkMark:SetPoint("CENTER", checkbox, "CENTER", M.checkMarkX, M.checkMarkY)
		checkMark:Hide()
		l.key, l.text, l.checkMark = def.key, text, checkMark
		-- CreateCheckbox: the option toggles and the list stays open; an open preview
		-- is rebuilt
		l:SetScript("OnClick", function(self)
			PlaySound("UChatScrollButton")
			K.options[self.key] = not K.options[self.key]
			updateCheckMarks()
			if box:HasFocus() then K.updatePreview(evaluate()) end
		end)
		l0.rows[i] = l
	end
	local width = longest + M.extraWidth + M.menuMargin
	l0:SetWidth(width)
	l0:SetHeight(#l0.rows * M.menuRowH + 2 * M.menuEdge)
	for _, l in ipairs(l0.rows) do l:SetWidth(width - M.menuMargin) end
	-- it closes 2 s after the mouse leaves it (and the arrow)
	l0:SetScript("OnUpdate", function(self, elapsed)
		if MouseIsOver(self) or MouseIsOver(arrow) then
			self.pending = 0
		else
			self.pending = (self.pending or 0) + elapsed
			if self.pending >= M.pending then self:Hide() end
		end
	end)
	l0:SetScript("OnShow", updateCheckMarks)
	l0:SetScript("OnHide", updateArrow)
	updateArrow()
end

-- ------------------------------------------------------------ Build
function K.build(talentsModule)
	if box then return end
	T = talentsModule
	local parent = T.frame
	local b = CreateFrame("EditBox", "ForeverUITalentsSearchBox", parent)
	box = b
	b:SetAutoFocus(false)
	b:SetMaxLetters(M.maxLetters)
	b:SetHeight(M.boxH)
	b:SetWidth(M.boxW)
	b:SetFrameLevel(parent:GetFrameLevel() + 6)
	b:SetFontObject(GameFontHighlightSmall)
	b:SetTextInsets(M.insetLeft, M.insetRight, 0, 0)
	local g = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(g, "common-search-border-left", true)
	g:SetWidth(M.edgeW) g:SetHeight(M.edgeH)
	g:SetPoint("LEFT", b, "LEFT", M.edgeX, 0)
	local d = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(d, "common-search-border-right", true)
	d:SetWidth(M.edgeW) d:SetHeight(M.edgeH)
	d:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	local m = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(m, "common-search-border-middle", true)
	m:SetHeight(M.edgeH)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	m:SetPoint("RIGHT", d, "LEFT", 0, 0)
	local magnifier = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(magnifier, "common-search-magnifyingglass", true)
	magnifier:SetWidth(M.magnifier) magnifier:SetHeight(M.magnifier)
	magnifier:SetPoint("LEFT", b, "LEFT", M.magnifierX, M.magnifierY)
	b.magnifier = magnifier
	local instruction = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	instruction:SetJustifyH("LEFT")
	instruction:SetJustifyV("MIDDLE")
	instruction:SetPoint("TOPLEFT", b, "TOPLEFT", M.insetLeft, 0)
	instruction:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -M.insetRight, 0)
	instruction:SetTextColor(M.instructionGray, M.instructionGray, M.instructionGray)
	instruction:SetText(TEXT.instruction)
	b.instruction = instruction

	local e = CreateFrame("Button", "ForeverUITalentsSearchClear", b)
	clear = e
	e:SetWidth(M.clear) e:SetHeight(M.clear)
	e:SetPoint("RIGHT", b, "RIGHT", M.clearX, 0)
	e:SetFrameLevel(b:GetFrameLevel() + 2)
	local icon = e:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(icon, "common-search-clearbutton", true)
	icon:SetWidth(M.clearIcon) icon:SetHeight(M.clearIcon)
	icon:SetPoint("TOPLEFT", e, "TOPLEFT", M.clearIconX, M.clearIconY)
	icon:SetAlpha(0.5)
	e.icon = icon
	e:SetScript("OnEnter", function() icon:SetAlpha(1) end)
	e:SetScript("OnLeave", function() icon:SetAlpha(0.5) end)
	e:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", e, "TOPLEFT", M.clearIconX + 1, M.clearIconY - 1) end)
	e:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", e, "TOPLEFT", M.clearIconX, M.clearIconY) end)
	e:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		K.quit()
	end)
	e:Hide()

	buildOptions(parent)
	arrow:SetFrameLevel(b:GetFrameLevel())
	-- placement: the arrow against the counter label, the box against the arrow
	-- (camelot: arrow at RIGHT of the box, (3, -2))
	arrow:ClearAllPoints()
	arrow:SetPoint("RIGHT", T.points.caption, "LEFT", -M.counterGap, M.arrowY - 1)
	b:SetPoint("RIGHT", arrow, "LEFT", -M.arrowX, -M.arrowY)

	preview = buildPreview(parent)

	b:SetScript("OnEditFocusGained", function()
		updateMagnifier()
		K.updatePreview(evaluate())
	end)
	b:SetScript("OnEditFocusLost", function()
		updateMagnifier()
		if not MouseIsOver(preview) then hidePreview() end
	end)
	b:SetScript("OnTextChanged", function(self)
		updateMagnifier()
		if self:HasFocus() then K.updatePreview(evaluate()) end
	end)
	b:SetScript("OnEnterPressed", function(self)
		local a = preview
		if a:IsShown() and (a.highlighted or 0) > 0 then
			K.choose(a.highlighted)
			return
		end
		hidePreview()
		K.find(evaluate())
		self:ClearFocus()
	end)
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	b:SetScript("OnKeyDown", function(_, pressedKey)
		if pressedKey == "UP" then browse(-1) elseif pressedKey == "DOWN" then browse(1) end
	end)
	updateMagnifier()
	K.box, K.clear, K.previewFrame, K.arrow, K.list = box, clear, preview, arrow, list
end

-- width: 184, or what is left of the counter (small window)
function K.place(pageWidth)
	if not box then return end
	local caption = T.points.caption
	local captionRight = T.points.captionRight or 0
	local w = caption:GetStringWidth() or 0
	-- from the frame's left edge (page + 2 on each side) to the box's left
	local rest = pageWidth + 4 + captionRight - w - M.counterGap - M.arrow - M.arrowX - M.leftMargin
	box:SetWidth(math.max(60, math.min(M.boxW, rest)))
end

-- after each screen update: the markers (UpdateFullSearchResults); nothing on the glyph
-- page or on an inspected player's talents, the player's search resumes afterwards
function K.update()
	if not box or not T then return end
	if T.glyphs or T.inspection then
		box:Hide()
		arrow:Hide()
		list:Hide()
		hidePreview()
		mark({})
		return
	end
	box:Show()
	arrow:Show()
	mark(K.compute())
end

-- When action bars change (spell placed or removed, page or stance), the
-- "Missing from action bar" search is redone, so a talent just placed loses its marker.
local watcher = CreateFrame("Frame")
for _, ev in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
	"ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "PET_BAR_UPDATE", "UPDATE_MULTI_ACTIONBAR" }) do
	watcher:RegisterEvent(ev)
end
watcher:SetScript("OnEvent", function()
	if K.state and K.state.filter == "bars" and T and T.book and T.book:IsVisible() then
		K.update()
	end
end)
K.barWatcher = watcher

-- talents already built (Blizzard_TalentUI loads before this file)
if ForeverUI.Talents and ForeverUI.Talents.book then
	K.build(ForeverUI.Talents)
	ForeverUI.Talents.update()
end
