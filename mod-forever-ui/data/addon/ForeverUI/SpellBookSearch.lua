-- ForeverUI: spell book search, after camelot's blizzard_spellsearch and
-- blizzard_spellbooksearch.lua. Search box, preview (5 rows; camelot: 3), full results as a
-- tab-less category (0) in sections, and the "Missing from action bar" filter.
-- Unlike camelot, results follow "Hide Passives" and "Show all spell ranks" (which stays
-- enabled while searching) and never group spells into flyouts.
-- No assisted combat: 3.3.5 lacks it.

ForeverUI = ForeverUI or {}

local S = ForeverUI.SpellBook
if not (S and S.book and S.pages) then return end

local R = {}
ForeverUI.SpellBookSearch = R

local L = ForeverUI.L
local TEXT = {
	instruction = L.SPELLBOOKSEARCH_INSTRUCTIONS,       -- SPELLBOOK_SEARCH_INSTRUCTIONS
	notOnBar = L.SPELLBOOKSEARCH_NOT_ON_ACTIONBAR, -- SPELLBOOK_SEARCH_NOT_ON_ACTIONBAR
	exact = L.SPELLBOOKSEARCH_HEADER_EXACT,          -- SPELLBOOK_SEARCH_HEADER_EXACT
	related = L.SPELLBOOKSEARCH_HEADER_RELATED,    -- SPELLBOOK_SEARCH_HEADER_RELATED
	name = L.SPELLBOOKSEARCH_HEADER_NAME,             -- SPELLBOOK_SEARCH_HEADER_NAME
	description = L.SPELLBOOKSEARCH_HEADER_DESCRIPTION, -- SPELLBOOK_SEARCH_HEADER_DESCRIPTION
	generic = L.SPELLBOOKSEARCH_HEADER_GENERIC,    -- SPELLBOOK_SEARCH_HEADER_GENERIC
	overflow = L.SPELLBOOKSEARCH_PREVIEW_OVERFLOW, -- TALENT_FRAME_SEARCH_PREVIEW_OVERFLOW_FORMAT
	passive = SPELL_PASSIVE,
}
local MIN_LETTERS = 3                                -- MIN_CHARACTER_SEARCH

local M = {
	boxW = 300, boxH = 30, boxX = -5, boxY = 4, tabsGap = 10, maxLetters = 40,
	edgeW = 8, edgeH = 20, edgeX = -5, magnifier = 10, magnifierX = 1, magnifierY = -1, gray = 0.6,
	clear = 17, clearX = -3, clearIcon = 10, clearIconX = 3, clearIconY = -3,
	insetLeft = 16, insetRight = 20, instructionGray = 0.35,
	previewX1 = 20, previewX2 = -3, previewY = 4, rowH = 27, rows = 5, topMargin = 1, bottomMargin = 3,
	gap = 1, overflowH = 16, overflowY = 5, overflowX = 9,
	iconFrame = 18, iconFrameX = 5, iconFrameY = 1, nameX = 5, nameY = 1, nameRight = -5,
	suggMagnifier = 14, suggMagnifierX = 10, suggMagnifierY = 1, suggTextX = 10,
}

-- SpellSearchUtil.MatchType: higher is better
local T = { description = 1, name = 2, related = 3, exact = 4, absent = 5, inactiveStance = 6, disabledBar = 7 }
local SECTIONS = {
	{ title = TEXT.exact, types = { [T.exact] = true } },
	{ title = TEXT.related, types = { [T.related] = true } },
	{ title = TEXT.name, types = { [T.name] = true } },
	{ title = TEXT.description, types = { [T.description] = true } },
	{ title = TEXT.generic, types = { [T.absent] = true, [T.inactiveStance] = true, [T.disabledBar] = true } },
}

-- ------------------------------------------------------------ Strings
-- DoStringsMatch / DoesStringContain: case-insensitive, literal
local function equals(a, b)
	return a and b and string.lower(a) == string.lower(b)
end
local function contains(parent, sub)
	return parent and sub and string.find(string.lower(parent), string.lower(sub), 1, true) ~= nil
end

-- ------------------------------------------------------------ Description
-- 3.3.5 has no GetSpellBookItemDescription: a hidden tooltip is read instead, and its last
-- non-empty line is the description.
local scanner = CreateFrame("GameTooltip", "ForeverUISpellBookScanTooltip", nil, "GameTooltipTemplate")
local descriptions = {}
local function description(spell)
	local key = spell.book .. ":" .. spell.name .. ":" .. (spell.rank or "")
	local d = descriptions[key]
	if d == nil then
		d = ""
		scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
		scanner:ClearLines()
		scanner:SetSpell(spell.slot, spell.book)
		for i = scanner:NumLines(), 2, -1 do
			local row = _G["ForeverUISpellBookScanTooltipTextLeft" .. i]
			local t = row and row:GetText()
			if t and t ~= "" then
				d = t
				break
			end
		end
		scanner:Hide()
		descriptions[key] = d
	end
	return d
end
R.description = description

-- ------------------------------------------------------------ State
R.state = nil            -- { filter = "text" | "bars", text = ... }
-- Cache of the bar state and of the result sections per option set; R.invalidate clears it
local hidden = {}

function R.active() return R.state ~= nil end
function R.invalidate() hidden = {} end

-- Searchable elements: those of every category, in order
local function elements(cats, opts)
	local list = {}
	for ci = 1, #cats do
		for _, el in ipairs(S.displayedList(cats, ci, opts)) do
			table.insert(list, el)
		end
	end
	return list
end

-- Sort keys of an element: book (spells before pet) and slot
local function bookRank(el)
	local spell = el.flyout and el.members[1] or el
	return (spell.book == BOOKTYPE_PET) and 1 or 0, spell.slot or 0
end

-- Spell subtitle (rank or "Passive"), matched like its name (extraSpellName)
local function subtitle(spell)
	if spell.rank and spell.rank ~= "" then return spell.rank end
	if spell.passive then return TEXT.passive end
end

-- GetMatchTypeForText for one spell. exactDesc: description of the spell named exactly
-- as the text (for related matches)
local function textMatchType(spell, text, exactDesc)
	if equals(spell.name, text) then return T.exact end
	if contains(spell.name, text) or contains(subtitle(spell), text) then return T.name end
	if contains(description(spell), text) then return T.description end
	if exactDesc and contains(exactDesc, spell.name) then return T.related end
end

-- A flyout group takes its best member: returns that type and member; fn: spell -> type
local function bestOf(el, fn)
	if not el.flyout then return fn(el), el end
	local best, bestMember
	for _, m in ipairs(el.members) do
		local t = fn(m)
		if t and (not best or t > best) then best, bestMember = t, m end
	end
	return best, bestMember
end

-- ------------------------------------------------------------ Action bars
-- Appends the spell names of action slot `slot` to `names`
local function actionNames(slot, names)
	local t, id, sub, global = GetActionInfo(slot)
	if t ~= "spell" then return end
	if global then names[#names + 1] = GetSpellInfo(global) end
	if id then
		if sub == BOOKTYPE_SPELL or sub == BOOKTYPE_PET then
			names[#names + 1] = GetSpellName(id, sub)
		else
			names[#names + 1] = GetSpellInfo(id)
		end
	end
end

-- Spell names on active bars, disabled bars, inactive stance bars and the pet bar (cached).
-- 3.3.5 slots: 1-24 main bar (pages 1-2); 25-36 right, 37-48 left, 49-60 bottom right,
-- 61-72 bottom left (GetActionBarToggles order: bottom left, bottom right, right, left);
-- 73-120 stance bars, one active (GetBonusBarOffset).
local function barsState()
	if hidden.bars then return hidden.bars end
	local activeSet, disabled, inactive = {}, {}, {}
	local bottomLeft, bottomRight, right, left = GetActionBarToggles()
	local multi = { [3] = right, [4] = left, [5] = bottomRight, [6] = bottomLeft }
	local stance = GetBonusBarOffset and GetBonusBarOffset() or 0
	for slot = 1, 120 do
		local names = {}
		actionNames(slot, names)
		for _, n in ipairs(names) do
			if slot <= 24 then
				activeSet[n] = true
			elseif slot <= 72 then
				local bar = math.floor((slot - 1) / 12) + 1
				if multi[bar] then activeSet[n] = true else disabled[n] = true end
			else
				local bar = math.floor((slot - 73) / 12) + 1
				if bar == stance then activeSet[n] = true else inactive[n] = true end
			end
		end
	end
	local pet = {}
	for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
		local n = GetPetActionInfo(i)
		if n then pet[n] = true end
	end
	hidden.bars = { activeSet = activeSet, disabled = disabled, inactive = inactive, pet = pet }
	return hidden.bars
end

-- For the talent search (TalentsSearch.lua): bar state, read afresh
function R.bars()
	hidden.bars = nil
	return barsState()
end

-- Bar match type of a spell: nil if it is on an active bar, passive or an auto attack
local function barType(spell)
	if spell.passive then return end
	if IsAttackSpell and IsAttackSpell(spell.name) then return end
	if IsAutoRepeatSpell and IsAutoRepeatSpell(spell.name) then return end
	local b = barsState()
	if spell.book == BOOKTYPE_PET then
		if b.pet[spell.name] then return end
		return T.absent
	end
	if b.activeSet[spell.name] then return end
	if b.disabled[spell.name] then return T.disabledBar end
	if b.inactive[spell.name] then return T.inactiveStance end
	return T.absent
end

-- A group is missing only if none of its spells is on an active bar
local function elementBarType(el)
	if not el.flyout then return barType(el) end
	local best
	for _, m in ipairs(el.members) do
		local t = barType(m)
		if not t then return end
		if not best or t < best then best = t end
	end
	return best
end

-- ------------------------------------------------------------ Results
-- FullSearchResultSort: type (reversed for bars), active before passive, book, slot
local function sortBy(list, reversed)
	table.sort(list, function(a, b)
		if a.type ~= b.type then
			if reversed then return a.type < b.type end
			return a.type > b.type
		end
		local pa, pb = a.el.passive and 1 or 0, b.el.passive and 1 or 0
		if pa ~= pb then return pa < pb end
		local la, sa = bookRank(a.el)
		local lb, sb = bookRank(b.el)
		if la ~= lb then return la < lb end
		return sa < sb
	end)
end

-- Sections of the current search: { { title, spells }, ... }, cached per option set
function R.groups(cats, opts)
	local key = (opts.passives and "p" or "a") .. (opts.flyouts and "v" or "s") .. (opts.ranks and "r" or "h")
	if hidden[key] then return hidden[key] end
	local state = R.state
	local matches = {}
	if state then
		local all = elements(cats, opts)
		if state.filter == "bars" then
			for _, el in ipairs(all) do
				local t = elementBarType(el)
				if t then table.insert(matches, { el = el, type = t }) end
			end
		else
			-- Description of the spell named exactly as the text (for related matches)
			local exactDesc
			for _, el in ipairs(all) do
				local t, m = bestOf(el, function(s) return equals(s.name, state.text) and T.exact or nil end)
				if t then
					exactDesc = description(m)
					break
				end
			end
			for _, el in ipairs(all) do
				local t = bestOf(el, function(s) return textMatchType(s, state.text, exactDesc) end)
				if t then table.insert(matches, { el = el, type = t }) end
			end
		end
		sortBy(matches, state.filter == "bars")
	end
	local groups = {}
	for _, section in ipairs(SECTIONS) do
		local spells = {}
		for _, r in ipairs(matches) do
			if section.types[r.type] then table.insert(spells, r.el) end
		end
		if #spells > 0 then table.insert(groups, { title = section.title, spells = spells }) end
	end
	hidden[key] = groups
	return groups
end

-- Preview: name filter, exact or contained; a group shows its best spell (name and icon);
-- PreviewSearchResultSort
function R.preview(text)
	local cats = S.categories()
	local opts = S.currentOptions()
	opts.flyouts = true                  -- the search never groups spells
	local matches = {}
	for _, el in ipairs(elements(cats, opts)) do
		local t, m = bestOf(el, function(s)
			if equals(s.name, text) then return T.exact end
			if contains(s.name, text) then return T.name end
		end)
		if t then
			local displayed = el
			if el.flyout and m then displayed = m end
			table.insert(matches, { el = el, type = t, name = displayed.name, icon = displayed.icon })
		end
	end
	table.sort(matches, function(a, b)
		if a.type ~= b.type then return a.type > b.type end
		local la, sa = bookRank(a.el)
		local lb, sb = bookRank(b.el)
		if la ~= lb then return la < lb end
		return sa < sb
	end)
	return matches
end

-- ------------------------------------------------------------ Search box
local box, clear, preview

-- EvaluateSearchText: the text, if it has at least 3 letters
local function evaluate()
	local t = box:GetText() or ""
	if string.len(t) >= MIN_LETTERS then return t end
end

local function hidePreview()
	preview:Hide()
	preview.highlighted = 0
end

-- Clear button: hidden out of combat. It is secure, so in combat it cannot hide and turns
-- transparent instead.
local function updateClearButton()
	local visible = box:HasFocus() or (box:GetText() or "") ~= ""
	if InCombatLockdown() then
		clear:SetAlpha(visible and 1 or 0)
		return
	end
	clear:SetAlpha(1)
	if visible then clear:Show() else clear:Hide() end
end

-- SearchBoxTemplate: magnifier and instruction
local function updateMagnifier()
	local active = box:HasFocus() or (box:GetText() or "") ~= ""
	local g = active and 1 or M.gray
	box.magnifier:SetVertexColor(g, g, g)
	if (box:GetText() or "") == "" then box.instruction:Show() else box.instruction:Hide() end
	updateClearButton()
end

-- SetFullResultSearch; a nil text leaves the search and goes back to the first tab
function R.find(text)
	if InCombatLockdown() then return end
	if not text then
		R.quit(true)
		return
	end
	if equals(text, TEXT.notOnBar) then
		R.state = { filter = "bars" }
	else
		R.state = { filter = "text", text = text }
	end
	-- Set category 0 BEFORE updating, so the search shows at once (an update on a tab would
	-- count as a tab click, which leaves the search)
	S.state.category, S.state.page = 0, 1
	S.update()
end

-- ClearActiveSearchState: text, focus, preview. toFirstTab: go back to the first tab if a
-- search was shown (false when a tab click leaves the search)
function R.quit(toFirstTab)
	local wasShown = R.state ~= nil
	R.state = nil
	if box then
		box:ClearFocus()
		box:SetText("")
		hidePreview()
		updateMagnifier()
	end
	if wasShown and toFirstTab and not InCombatLockdown() then
		S.choose(1)
	end
end

-- ------------------------------------------------------------ Preview
-- Preview row button. 3.3.5 has no draw sublevels and draws a button's normal texture
-- (_search-rowbg) in ARTWORK, so the icon goes in OVERLAY and its border and highlight
-- (camelot: OVERLAY 2 and 3) go in a child frame above it.
local function resultRow(parent, i)
	local l = CreateFrame("Button", "ForeverUISpellBookSearchResult" .. i, parent)
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

-- Preview list under the box (SpellSearchPreviewContainerTemplate)
local function buildPreview()
	local a = CreateFrame("Frame", "ForeverUISpellBookSearchPreview", S.pages)
	a:SetFrameStrata("HIGH")
	a:SetPoint("TOPLEFT", box, "BOTTOMLEFT", M.previewX1, M.previewY)
	a:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", M.previewX2, M.previewY)
	a:SetHeight(M.rowH)
	a:EnableMouse(true)
	a:Hide()
	local background = a:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "_search-rowbg", true)
	background:SetAllPoints(a)
	-- Border (UI-Frame-BotCorner*, _UI-Frame-Bot, !UI-Frame-*Tile)
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

	-- Result rows (SpellSearchPreviewResultTemplate)
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
		l:SetScript("OnEnter", function() R.toggleHighlight(i) end)
		l:SetScript("OnClick", function() R.choose(i) end)
		l:Hide()
		a.rows[i] = l
	end
	-- Suggestion (SpellSearchSuggestedResultButtonTemplate)
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
	sugg:SetScript("OnEnter", function() R.toggleHighlight(1) end)
	sugg:SetScript("OnClick", function() R.choose(1) end)
	sugg:Hide()
	a.suggestion = sugg
	-- Overflow line ("And %s more")
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
	-- If the box loses focus during a click here, the preview stays for the click and hides
	-- once the mouse leaves it
	a:SetScript("OnUpdate", function(self)
		if not box:HasFocus() and not MouseIsOver(self) then hidePreview() end
	end)
	return a
end

-- SetPreviewResults / UpdateResultsDisplay; text: nil below 3 letters
function R.updatePreview(text)
	if InCombatLockdown() then return end
	local a = preview
	a.highlighted = 0
	a.results = nil
	for _, l in ipairs(a.rows) do l:Hide() l.highlighted:Hide() end
	a.suggestion:Hide()
	a.suggestion.highlighted:Hide()
	a.overflow:Hide()
	if not text then
		-- Below 3 letters: the suggestion only (3.3.5 has no assisted combat)
		a.suggestion:Show()
		a.count = 1
		a:SetHeight(M.rowH * 1 + M.bottomMargin)
		a:Show()
		return
	end
	local matches = R.preview(text)
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

-- HighlightPreviewResult
function R.toggleHighlight(i)
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

-- CycleHighlightedResultUp / Down (camelot's formula as is)
local function browse(direction)
	local a = preview
	if not a:IsShown() or not a.count or a.count == 0 then return end
	local n, i = a.count, a.highlighted or 0
	if direction < 0 then
		i = (i - 2) % n + 1
	else
		i = i % n + 1
	end
	R.toggleHighlight(i)
end

-- SelectPreviewResult / suggestion click
function R.choose(i)
	local a = preview
	PlaySound("igMainMenuOptionCheckBoxOn")
	if a.results then
		local r = a.results[i]
		if not r then return end
		box:ClearFocus()
		box:SetText(r.name)
		hidePreview()
		R.find(r.name)
	else
		box:ClearFocus()
		box:SetText(TEXT.notOnBar)
		hidePreview()
		R.find(TEXT.notOnBar)
	end
end

-- ------------------------------------------------------------ Build
local function build()
	local b = CreateFrame("EditBox", "ForeverUISpellBookSearchBox", S.pages)
	box = b
	b:SetAutoFocus(false)
	b:SetMaxLetters(M.maxLetters)
	b:SetHeight(M.boxH)
	b:SetWidth(M.boxW)
	b:SetPoint("RIGHT", S.settings, "LEFT", M.boxX, M.boxY)
	b:SetFontObject(GameFontHighlightSmall)
	b:SetTextInsets(M.insetLeft, M.insetRight, 0, 0)
	-- Border (InputBoxVisualTemplate)
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
	-- Magnifier
	local magnifier = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(magnifier, "common-search-magnifyingglass", true)
	magnifier:SetWidth(M.magnifier) magnifier:SetHeight(M.magnifier)
	magnifier:SetPoint("LEFT", b, "LEFT", M.magnifierX, M.magnifierY)
	b.magnifier = magnifier
	-- Instruction text
	local instruction = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	instruction:SetJustifyH("LEFT")
	instruction:SetJustifyV("MIDDLE")
	instruction:SetPoint("TOPLEFT", b, "TOPLEFT", M.insetLeft, 0)
	instruction:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -M.insetRight, 0)
	instruction:SetTextColor(M.instructionGray, M.instructionGray, M.instructionGray)
	instruction:SetText(TEXT.instruction)
	b.instruction = instruction

	-- Clear button: secure, so it leaves the search in combat too
	local e = CreateFrame("Button", "ForeverUISpellBookSearchClear", S.pages, "SecureHandlerClickTemplate")
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
	e:SetFrameRef("ctrl", S.ctrl)
	e:SetAttribute("_onclick", [==[ self:GetFrameRef("ctrl"):SetAttribute("clear", 1) ]==])
	-- SearchBoxTemplateClearButton_OnClick: sound, text, focus
	e:HookScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		R.quit(false)
	end)
	e:Hide()

	preview = buildPreview()

	-- SpellSearchBoxMixin
	b:SetScript("OnEditFocusGained", function(self)
		-- A search publishes pages, which only works out of combat: in combat the box drops focus
		if InCombatLockdown() then
			self:ClearFocus()
			return
		end
		updateMagnifier()
		R.updatePreview(evaluate())
	end)
	b:SetScript("OnEditFocusLost", function(self)
		updateMagnifier()
		if not MouseIsOver(preview) then hidePreview() end
	end)
	b:SetScript("OnTextChanged", function(self)
		updateMagnifier()
		if self:HasFocus() then R.updatePreview(evaluate()) end
	end)
	b:SetScript("OnEnterPressed", function(self)
		local a = preview
		if a:IsShown() and (a.highlighted or 0) > 0 then
			R.choose(a.highlighted)
			return
		end
		hidePreview()
		R.find(evaluate())
		self:ClearFocus()
	end)
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	b:SetScript("OnKeyDown", function(self, pressedKey)
		if pressedKey == "UP" then browse(-1) elseif pressedKey == "DOWN" then browse(1) end
	end)
	updateMagnifier()
end

build()
R.box, R.clear, R.previewFrame = box, clear, preview

-- A tab click leaves the search (ClearActiveSearchState, without going to the first tab);
-- nothing protected here, so it works in combat too
S.onVisuals = function(cat)
	if cat ~= 0 and R.state then
		R.quit(false)
	end
end

-- ResizeSearchBox: between the tabs' right edge (+ 10) and the settings, 300 at most.
-- Out of combat only: a secure button is anchored to the box. reduced: book at reduced width
S.onResize = function(reduced)
	if InCombatLockdown() or not box then return end
	local G = S.G
	local pagesW = reduced and G.reducedBookW or G.bookW
	local nTabs = 0
	for _, o in ipairs(S.tabs.buttons) do
		if o:IsShown() then nTabs = nTabs + 1 end
	end
	local tabsRight = G.tabsX + nTabs * (G.tabW + G.tabGap) - G.tabGap
	local boxRight = pagesW + G.settingsX - G.settingsW + M.boxX
	box:SetWidth(math.min(boxRight - tabsRight - M.tabsGap, M.boxW))
end

-- Combat start: the box drops focus and the preview hides. Combat end: the clear button
-- gets its visibility back
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function(_, ev)
	if ev == "PLAYER_REGEN_DISABLED" then
		box:ClearFocus()
		hidePreview()
	else
		updateClearButton()
	end
end)

-- When the bars change (spell placed or removed, page, stance), a "Missing from action bar"
-- search is redone once per frame (a drag fires several events). In combat, S.update waits
-- for combat to end.
local bars = CreateFrame("Frame")
bars:Hide()
for _, ev in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
	"PET_BAR_UPDATE", "UPDATE_MULTI_ACTIONBAR" }) do
	bars:RegisterEvent(ev)
end
bars:SetScript("OnEvent", function(self)
	if R.state and R.state.filter == "bars" then self:Show() end
end)
bars:SetScript("OnUpdate", function(self)
	self:Hide()
	if R.state and R.state.filter == "bars" and S.book:IsVisible() then S.update() end
end)
R.barWatcher = bars
