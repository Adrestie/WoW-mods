-- Camelot's professions book (ProfessionsFrame.BookPage): the overview page opened by the
-- professions micro-button (BottomBar.lua), and the side tabs of the professions window.
-- 3.3.5 has no GetProfessions: professions come from the skill lines, their spells from the
-- spellbook. Casting is protected, so spell buttons are secure and the book closes in combat.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates
local L = ForeverUI.L

local PB = {}
ForeverUI.ProfessionsBook = PB

local SEP = string.char(92)
local FONT = "Fonts" .. SEP .. "FRIZQT__.TTF"
local NUMBER_FONT = "Fonts" .. SEP .. "ARIALN.TTF"
local BUTTONS = "Interface" .. SEP .. "Buttons" .. SEP
local BOOK_ICON = "Interface" .. SEP .. "ForeverUI" .. SEP .. "icons" .. SEP .. "inv_sidetab_professions_c60-rond"

local N = {
	window = { 673, 594 },
	portrait = { side = 48, x = 1, y = 1.5 },
	main = { 664, 142, x = 5, y = -41, gap = 5 },
	secondary = { 225, 275, gap = 4, step = -6 },
	-- rowLines: most primary rows visible; gutter: room for the scroll bar (8 wide, 17 arrows);
	-- trim: art edge kept when a card shrinks; online: gap between spells laid in a line
	rowLines = 3,
	gutter = 18,
	trim = 20,
	online = 5,
	name = { 20, -24 },
	absent = 485,
	primarySpells = { x = 15, single = 46, top = 60, down = 10 },
	secondarySpells = { x = 20, y = 25 },
	spell = { side = 40, mask = 3, text = { 100, 5, 7 }, sub = { 95, 28, -1 } },
	primaryRank = { 441, x = -40, offset = -7 },
	secondaryRank = { 190, y = -47, offset = -5 },
	rank = { h = 18, background = 23, slice = 30, filled = { 441, 18, 2, -3 }, mask = 1, flare = { 53, 16 }, text = -3 },
	unlearnButton = { 20, 1, -4 },
	secondaryName = -25,
	secondaryText = { 175, 5, -13 },
	levels = { content = 1, zone = 1, rowLines = 2, columns = 10, closeButton = 22 },
}

-- NORMAL_FONT_COLOR; PASSIVE_SPELL_FONT_COLOR (camelot GlobalColor 0xffc4a300)
local COLORS = {
	normal = { 1, 0.82, 0 },
	passive = { 0.7686, 0.6392, 0 },
}

-- UIPanelWindows["TradeSkillFrame"] (3.3.5 Blizzard_TradeSkillUI.lua) plus whileDead;
-- width: camelot's professionsFrameWidthOverride (tabs included), also given to TradeSkillFrame
local PANEL_WIDTH = 750
local PANEL = { area = "left", pushable = 3, whileDead = 1, width = PANEL_WIDTH }

-- name: a spell named like the profession (Spell.dbc, SkillLine.dbc), read in the client
-- language; strip: Skillbar_Fill_Flipbook_<strip>; secondary: slot among the three bottom
-- cards; tab: side tab icon (tabicons/), only for professions with a crafting page
local PROFESSIONS = {
	alchemy = { name = 2259, strip = "alchemy_c60", tab = "trade_alchemy" },
	blacksmithing = { name = 2018, strip = "blacksmithing", tab = "trade_blacksmithing" },
	enchanting = { name = 7411, strip = "enchanting_c60", tab = "trade_engraving" },
	engineering = { name = 4036, strip = "engineering", tab = "trade_engineering" },
	herbalism = { name = 9134, strip = "herbalism" },
	inscription = { name = 45357, strip = "inscription", tab = "inv_inscription_tradeskill01" },
	jewelcrafting = { name = 25229, strip = "jewelcrafting", tab = "inv_misc_gem_01" },
	leatherworking = { name = 2108, strip = "leatherworking", tab = "trade_leatherworking" },
	mining = { name = 2575, strip = "mining", tab = "trade_mining" },
	skinning = { name = 8613, strip = "skinning_c60" },
	tailoring = { name = 3908, strip = "tailoring", tab = "trade_tailoring" },
	cooking = { name = 2550, strip = "cooking", secondary = 1, absent = L.PROFESSIONSBOOK_COOKING_MISSING,
		tab = "inv_misc_food_15" },
	fishing = { name = 7620, strip = "fishing", secondary = 2, absent = L.PROFESSIONSBOOK_FISHING_MISSING },
	firstaid = { name = 3273, strip = "firstaid_c60", secondary = 3, absent = L.PROFESSIONSBOOK_FIRST_AID_MISSING,
		tab = "spell_holy_sealofsacrifice" },
}
local SECONDARY_PROFESSIONS = { "cooking", "fishing", "firstaid" }

-- Profession spells by group, each group the ranks of one spell (SkillLineAbility.dbc, no
-- recipes or hidden spells), in card order; the first group opens the crafting page.
local SPELLS = {
	alchemy = { { 2259, 3101, 3464, 11611, 28596, 51304 } },
	blacksmithing = { { 2018, 3100, 3538, 9785, 29844, 51300 } },
	enchanting = { { 7411, 7412, 7413, 13920, 28029, 51313 }, { 13262 } },
	engineering = { { 4036, 4037, 4038, 12656, 30350, 51306 } },
	herbalism = { { 2383, 8387 }, { 55428, 55480, 55500, 55501, 55502, 55503 } },
	inscription = { { 45357, 45358, 45359, 45360, 45361, 45363 }, { 51005 } },
	jewelcrafting = { { 25229, 25230, 28894, 28895, 28897, 51311 }, { 31252 } },
	leatherworking = { { 2108, 3104, 3811, 10662, 32549, 51302 } },
	mining = { { 2656 }, { 2580, 8388 } },
	skinning = { { 8613, 8617, 8618, 10768, 32678, 50305 } },
	tailoring = { { 3908, 3909, 3910, 12180, 26790, 51309 } },
	cooking = { { 2550, 3102, 3413, 18260, 33359, 51296 }, { 818 } },
	fishing = { { 62734, 7620, 7731, 7732, 18248, 33095, 51294 }, { 43308 } },
	firstaid = { { 3273, 3274, 7924, 10846, 27028, 45542 } },
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- size: true to also apply the atlas size
local function atlas(t, name, size)
	return ForeverUI.SetAtlas(t, name, not size)
end

local truthy = Tpl.Truthy

-- camelot fonts missing from 3.3.5 (same objects as TradeSkill.lua)
local function font(name, path, size, outline, shadow, r, g, b)
	local p = _G[name] or CreateFont(name)
	p:SetFont(path, size, outline or "")
	if shadow then
		p:SetShadowOffset(1, -1)
		p:SetShadowColor(0, 0, 0, 1)
	else
		p:SetShadowOffset(0, 0)
		p:SetShadowColor(0, 0, 0, 0)
	end
	p:SetTextColor(r or 1, g or 1, b or 1)
	return p
end
local FONTS = {
	small2 = font("ForeverUIFontHighlightSmall2", FONT, 11),                           -- GameFontHighlightSmall2
	sub = font("ForeverUIFontNewSubSpell", FONT, 10, nil, true, 0.82, 0.7, 0.54),     -- NewSubSpellFont
	rank = font("ForeverUIFontNumber12Outline", NUMBER_FONT, 12, "OUTLINE"),         -- Number12FontOutline
}

-- ---------- Reading

-- Reading expands collapsed skill headers, then collapses them again. Both fire
-- SKILL_LINES_CHANGED, so the book ignores that event for a moment after its own read.
local silence = 0

-- expands every collapsed skill header; returns the set of their names
local function expandHeaders()
	local collapsedSet = {}
	local i = 1
	while i <= (GetNumSkillLines() or 0) do
		local name, header, expanded = GetSkillLineInfo(i)
		if truthy(header) and not truthy(expanded) then
			collapsedSet[name] = true
			ExpandSkillHeader(i)
		end
		i = i + 1
	end
	return collapsedSet
end

-- profession name in the client language -> profession key
local function professionNames()
	local byName = {}
	for key, m in pairs(PROFESSIONS) do
		local name = GetSpellInfo(m.name)
		if name then byName[name] = key end
	end
	return byName
end

-- the player's professions: primaries as a list (two in camelot, more on a private server),
-- secondaries by key
function PB.Read()
	local byName = professionNames()
	local collapsedSet = expandHeaders()
	local primaries, secondaries = {}, {}
	for i = 1, GetNumSkillLines() or 0 do
		local name, header, _, rank, _, bonus, maxValue, abandon = GetSkillLineInfo(i)
		local key = not truthy(header) and byName[name]
		if key then
			local m = { key = key, name = name, rank = rank or 0, maxValue = maxValue or 0, bonus = bonus or 0, abandon = truthy(abandon) }
			if PROFESSIONS[key].secondary then
				secondaries[key] = m
			else
				primaries[#primaries + 1] = m
			end
		end
	end
	if next(collapsedSet) then
		for i = GetNumSkillLines() or 0, 1, -1 do
			local name, header, expanded = GetSkillLineInfo(i)
			if truthy(header) and truthy(expanded) and collapsedSet[name] then
				CollapseSkillHeader(i)
			end
		end
		silence = GetTime() + 0.5
	end
	return primaries, secondaries
end

-- spellbook: spell id -> slot
local function readSpellbook()
	local cells = {}
	for tab = 1, GetNumSpellTabs() or 0 do
		local _, _, offset, count = GetSpellTabInfo(tab)
		offset = offset or 0
		for slot = offset + 1, offset + (count or 0) do
			local link = GetSpellLink(slot, BOOKTYPE_SPELL)
			local id = link and tonumber(string.match(link, "spell:(%d+)"))
			if id and not cells[id] then cells[id] = slot end
		end
	end
	return cells
end

-- slots of a profession's spells: one per group, the highest known rank;
-- maxValue: most slots returned
local function spellsOf(key, cells, maxValue)
	local list = {}
	for _, group in ipairs(SPELLS[key]) do
		for k = #group, 1, -1 do
			local slot = cells[group[k]]
			if slot then
				list[#list + 1] = slot
				break
			end
		end
		if #list >= maxValue then break end
	end
	return list
end

-- skill line index for AbandonSkill; expands the headers if needed (they stay expanded
-- while the confirmation box is open)
local function indexOf(name)
	for attempt = 1, 2 do
		for i = 1, GetNumSkillLines() or 0 do
			local n, header = GetSkillLineInfo(i)
			if n == name and not truthy(header) then return i end
		end
		if attempt == 1 then expandHeaders() end
	end
end

-- ---------- Rank bar

-- three-slice atlas element: both ends at their size, the middle stretched;
-- tip: end width; layer: draw layer
local function threeSlice(host, name, width, height, tip, layer)
	local e = ForeverUI.AtlasEntry(name)
	if not e then return end
	local du = (e[3] - e[2]) * tip / e[6]
	local pieces = {
		{ e[2], e[2] + du, 0, tip },
		{ e[2] + du, e[3] - du, tip, width - 2 * tip },
		{ e[3] - du, e[3], width - tip, tip },
	}
	for _, m in ipairs(pieces) do
		local t = host:CreateTexture(nil, layer)
		t:SetTexture(e[1])
		t:SetTexCoord(m[1], m[2], e[4], e[5])
		t:SetWidth(m[4])
		t:SetHeight(height)
		t:SetPoint("TOPLEFT", host, "TOPLEFT", m[3], 0)
	end
end

-- ProfessionsRankBarTemplate. offset: added to the fill width (-7 primary, -5 secondary)
local function createRank(map, width, offset)
	local R = N.rank
	local r = CreateFrame("Frame", nil, map)
	r:SetWidth(width)
	r:SetHeight(R.h)
	r.fillWidth, r.offset = width, offset
	local background = r:CreateTexture(nil, "BACKGROUND")
	atlas(background, "profession-progressbar-bg")
	background:SetWidth(width)
	background:SetHeight(R.background)
	background:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
	local filled = r:CreateTexture(nil, "BORDER")
	filled:SetHeight(R.filled[2])
	filled:SetPoint("TOPLEFT", r, "TOPLEFT", R.filled[3] + R.mask, R.filled[4])
	local flare = r:CreateTexture(nil, "ARTWORK")
	flare:SetWidth(R.flare[1])
	flare:SetHeight(R.flare[2])
	flare:SetBlendMode("ADD")
	threeSlice(r, "profession-progressbar-frame", width, R.background, R.slice, "OVERLAY")
	local textFrame = CreateFrame("Frame", nil, r)
	textFrame:SetHeight(R.h)
	textFrame:SetPoint("LEFT", r, "LEFT", 0, R.text)
	textFrame:SetPoint("RIGHT", r, "RIGHT", 0, R.text)
	textFrame:SetFrameLevel(r:GetFrameLevel() + 1)
	local text = textFrame:CreateFontString(nil, "ARTWORK")
	text:SetFontObject(FONTS.rank)
	text:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
	r.background, r.filled, r.flare, r.text = background, filled, flare, text
	return r
end

-- ProfessionsRankBarMixin:Update without animation: text, profession strip (else
-- DefaultBlue) shown over width x ratio + offset, flare at the end
local function updateRank(r, m)
	local R = N.rank
	if m.bonus > 0 then
		r.text:SetFormattedText(L.TRADESKILL_NAME_RANK_MODIFIER, m.name, m.rank, m.bonus, m.maxValue)
	else
		r.text:SetFormattedText(L.TRADESKILL_NAME_RANK, m.name, m.rank, m.maxValue)
	end
	local strip = PROFESSIONS[m.key].strip
	local e = ForeverUI.AtlasEntry("skillbar_fill_flipbook_" .. strip) or ForeverUI.AtlasEntry("skillbar_fill_flipbook_defaultblue")
	local flare = ForeverUI.AtlasEntry("skillbar_flare_" .. strip)
	local part = m.maxValue > 0 and math.min(m.rank / m.maxValue, 1) or 0
	local found = math.min(R.filled[1] - R.mask, r.fillWidth * part + r.offset)
	if e and found >= 1 then
		r.filled:SetTexture(e[1])
		local du = (e[3] - e[2]) / R.filled[1]
		r.filled:SetTexCoord(e[2] + du * R.mask, e[2] + du * (R.mask + found), e[4], e[5])
		r.filled:SetWidth(found)
		r.filled:Show()
	else
		r.filled:Hide()
	end
	-- flare masked as in camelot: its right part, at the visible width (see TradeSkill.lua)
	if flare and found >= 1 then
		local l = math.min(R.flare[1], found)
		local du = (flare[3] - flare[2]) / R.flare[1]
		r.flare:SetTexture(flare[1])
		r.flare:SetTexCoord(flare[3] - du * l, flare[3], flare[4], flare[5])
		r.flare:SetWidth(l)
		place(r.flare, "RIGHT", r, "TOPLEFT", R.filled[3] + R.mask + found, R.filled[4] - R.filled[2] / 2)
		r.flare:SetAlpha(m.maxValue > 0 and m.rank >= m.maxValue and 0 or 1)
		r.flare:Show()
	else
		r.flare:Hide()
	end
end

-- ---------- Spells

local spellCount = 0

-- ProfessionButtonTemplate as a SECURE button (type "spell"): casting is protected
local function createSpell(map)
	spellCount = spellCount + 1
	local S = N.spell
	local name = "ForeverUIProfessionsBookSpell" .. spellCount
	local b = CreateFrame("Button", name, map, "SecureActionButtonTemplate")
	b:SetWidth(S.side)
	b:SetHeight(S.side)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetAttribute("type", "spell")
	-- a modified click links the spell into chat instead of casting it
	b:SetAttribute("shift-type1", "link")
	b:SetAttribute("shift-type2", "link")
	local icon = b:CreateTexture(nil, "BORDER")
	icon:SetPoint("TOPLEFT", b, "TOPLEFT", S.mask, -S.mask)
	icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -S.mask, S.mask)
	local edge = S.mask / S.side
	icon:SetTexCoord(edge, 1 - edge, edge, 1 - edge)
	local frame = b:CreateTexture(nil, "OVERLAY")
	atlas(frame, "profession-square-frame", true)
	frame:SetPoint("CENTER", icon, "CENTER", 0, 0)
	b:SetPushedTexture(BUTTONS .. "UI-Quickslot-Depress")
	b:SetHighlightTexture(BUTTONS .. "ButtonHilight-Square")
	b:GetHighlightTexture():SetBlendMode("ADD")
	local cooldown = CreateFrame("Cooldown", name .. "Cooldown", b, "CooldownFrameTemplate")
	cooldown:SetAllPoints(b)
	local text = b:CreateFontString(nil, "BORDER", "GameFontNormal")
	text:SetWidth(S.text[1])
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", b, "RIGHT", S.text[2], S.text[3])
	local sub = b:CreateFontString(nil, "BORDER")
	sub:SetFontObject(FONTS.sub)
	sub:SetWidth(S.sub[1])
	sub:SetHeight(S.sub[2])
	sub:SetJustifyH("LEFT")
	sub:SetJustifyV("TOP")
	sub:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, S.sub[3])
	b.icon, b.frame, b.cooldown, b.text, b.sub = icon, frame, cooldown, text, sub
	b:SetScript("OnEnter", function(self)
		if not self.slot then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpell(self.slot, BOOKTYPE_SPELL)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	b:SetScript("OnDragStart", function(self)
		if self.slot then PickupSpell(self.slot, BOOKTYPE_SPELL) end
	end)
	-- link: the trade skill link if any, else the spell link
	b:SetScript("PostClick", function(self)
		if self.slot and IsModifiedClick("CHATLINK") then
			local link, tradeSkillLink = GetSpellLink(self.slot, BOOKTYPE_SPELL)
			if tradeSkillLink or link then ChatEdit_InsertLink(tradeSkillLink or link) end
		end
	end)
	b:Hide()
	return b
end

local function updateCooldown(b)
	local start, duration, active = GetSpellCooldown(b.slot, BOOKTYPE_SPELL)
	CooldownFrame_SetTimer(b.cooldown, start or 0, duration or 0, active or 0)
	if truthy(active) then
		b.icon:SetVertexColor(1, 1, 1)
	else
		b.icon:SetVertexColor(0.4, 0.4, 0.4)
	end
end

-- UpdateButton: icon, name, rank, cooldown; the spell to cast is "Name(Rank)",
-- which SecureActionButton passes to CastSpellByName
local function fillSpell(b, slot)
	b.slot = slot
	local name, rank = GetSpellName(slot, BOOKTYPE_SPELL)
	local passive = IsPassiveSpell(slot, BOOKTYPE_SPELL)
	b:GetHighlightTexture():SetTexture(BUTTONS .. (passive and "UI-PassiveHighlight" or "ButtonHilight-Square"))
	local c = passive and COLORS.passive or COLORS.normal
	b.text:SetTextColor(c[1], c[2], c[3])
	b.text:SetText(name)
	b.sub:SetText(rank or "")
	b.icon:SetTexture(GetSpellTexture(slot, BOOKTYPE_SPELL))
	updateCooldown(b)
	if rank and rank ~= "" then
		b:SetAttribute("spell", name .. "(" .. rank .. ")")
	else
		b:SetAttribute("spell", name)
	end
end

-- ---------- Unlearn

function PB.Unlearn(name)
	local i = indexOf(name)
	if not i then return end
	local box = StaticPopup_Show("UNLEARN_SKILL", name)
	if box then box.data = i end
end

local function createUnlearn(map, rank)
	local O = N.unlearnButton
	local b = CreateFrame("Button", nil, map)
	b:SetWidth(O[1])
	b:SetHeight(O[1])
	b:SetPoint("LEFT", rank, "RIGHT", O[2], O[3])
	local icon = b:CreateTexture(nil, "ARTWORK")
	atlas(icon, "profession-button-red-crossmark", true)
	icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	local pressed = b:CreateTexture(nil, "OVERLAY")
	atlas(pressed, "profession-button-red-crossmark-pressed", true)
	pressed:SetPoint("CENTER", b, "CENTER", 0, 0)
	pressed:Hide()
	b.icon, b.pressed = icon, pressed
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(UNLEARN_SKILL_TOOLTIP)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	b:SetScript("OnMouseDown", function(self) self.pressed:Show() end)
	b:SetScript("OnMouseUp", function(self) self.pressed:Hide() end)
	b:SetScript("OnClick", function()
		if map.profession then PB.Unlearn(map.profession.name) end
	end)
	return b
end

-- ---------- Cards

-- Card background. At its art size: one piece. Narrower (row beside the scroll bar) or
-- shorter (column under three rows): the art is not squashed. Its left edge (row) or top
-- edge (column) is kept over N.trim, the rest aligns on the opposite edge, and the strip
-- between them is cropped.
local function placeBackground(c, name)
	local e = ForeverUI.AtlasEntry(name)
	if not e then return false end
	c.backgroundAtlas = name
	local W, H, B = e[6], e[7], N.trim
	local l, h = c:GetWidth(), c:GetHeight()
	local du, dv = (e[3] - e[2]) / W, (e[5] - e[4]) / H
	local background, edge = c.background, c.backgroundEdge
	background:SetTexture(e[1])
	edge:SetTexture(e[1])
	background:ClearAllPoints()
	if l < W then
		edge:ClearAllPoints()
		edge:SetTexCoord(e[2], e[2] + du * B, e[4], e[5])
		edge:SetWidth(B)
		edge:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		edge:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
		background:SetTexCoord(e[3] - du * (l - B), e[3], e[4], e[5])
		background:SetPoint("TOPLEFT", c, "TOPLEFT", B, 0)
		background:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
		edge:Show()
	elseif h < H then
		edge:ClearAllPoints()
		edge:SetTexCoord(e[2], e[3], e[4], e[4] + dv * B)
		edge:SetHeight(B)
		edge:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		edge:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
		background:SetTexCoord(e[2], e[3], e[5] - dv * (h - B), e[5])
		background:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -B)
		background:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
		edge:Show()
	else
		-- the hidden edge keeps its last anchors
		background:SetTexCoord(e[2], e[3], e[4], e[5])
		background:SetAllPoints(c)
		edge:Hide()
	end
	return true
end

local function createBackground(c)
	c.background = c:CreateTexture(nil, "BACKGROUND")
	c.backgroundEdge = c:CreateTexture(nil, "BACKGROUND")
	c.backgroundEdge:Hide()
end

local function createPrimary(parent, n)
	local P = N.main
	local c = CreateFrame("Frame", nil, parent)
	c:SetWidth(P[1])
	c:SetHeight(P[2])
	c.main = true
	createBackground(c)
	c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	c.name:SetJustifyH("LEFT")
	c.name:SetPoint("TOPLEFT", c, "TOPLEFT", N.name[1], N.name[2])
	c.absentTitle = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	c.absentTitle:SetJustifyH("LEFT")
	c.absentTitle:SetPoint("TOPLEFT", c, "TOPLEFT", N.name[1], N.name[2])
	if n == 1 then
		c.absentTitle:SetText(L.PROFESSIONSBOOK_FIRST_PROFESSION)
	else
		c.absentTitle:SetText(L.PROFESSIONSBOOK_SECOND_PROFESSION)
	end
	c.absentText = c:CreateFontString(nil, "OVERLAY")
	c.absentText:SetFontObject(FONTS.small2)
	c.absentText:SetWidth(N.absent)
	c.absentText:SetJustifyH("LEFT")
	c.absentText:SetPoint("CENTER", c, "CENTER", 0, 0)
	c.absentText:SetText(L.PROFESSIONSBOOK_MISSING_PROFESSION)
	local PR = N.primaryRank
	c.rank = createRank(c, PR[1], PR.offset)
	c.rank:SetPoint("RIGHT", c, "RIGHT", PR.x, 0)
	c.unlearnButton = createUnlearn(c, c.rank)
	c.spells = { createSpell(c), createSpell(c) }
	return c
end

-- columns are drawn IN FRONT of the rows zone: their level is set before their children
-- are created
local function createSecondary(content, key)
	local S = N.secondary
	local c = CreateFrame("Frame", nil, content)
	c:SetFrameLevel(content:GetFrameLevel() + N.levels.columns)
	c:SetWidth(S[1])
	c:SetHeight(S[2])
	c.key = key
	createBackground(c)
	placeBackground(c, "profession-overview-card-generic-" .. key)
	c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	c.name:SetJustifyH("LEFT")
	c.name:SetPoint("TOP", c, "TOP", 0, N.secondaryName)
	c.absentTitle = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	c.absentTitle:SetJustifyH("LEFT")
	c.absentTitle:SetPoint("TOP", c, "TOP", 0, N.secondaryName)
	c.absentTitle:SetText(GetSpellInfo(PROFESSIONS[key].name) or "")
	local T = N.secondaryText
	c.absentText = c:CreateFontString(nil, "OVERLAY")
	c.absentText:SetFontObject(FONTS.small2)
	c.absentText:SetWidth(T[1])
	c.absentText:SetJustifyH("LEFT")
	c.absentText:SetJustifyV("TOP")
	c.absentText:SetPoint("TOP", c.absentTitle, "BOTTOM", T[2], T[3])
	c.absentText:SetText(PROFESSIONS[key].absent)
	local RS = N.secondaryRank
	c.rank = createRank(c, RS[1], RS.offset)
	c.rank:SetPoint("TOP", c, "TOP", 0, RS.y)
	c.spells = {}
	for k = 1, 4 do
		c.spells[k] = createSpell(c)
	end
	return c
end

-- column spells: stacked from the bottom (camelot); in a line, icons only, when the column
-- has lost a row's height
local function placeSpellColumn(c)
	local SS = N.secondarySpells
	for k, b in ipairs(c.spells) do
		if k == 1 then
			place(b, "BOTTOMLEFT", c, "BOTTOMLEFT", SS.x, SS.y)
		elseif c.compact then
			place(b, "LEFT", c.spells[k - 1], "RIGHT", N.online, 0)
		else
			place(b, "BOTTOM", c.spells[k - 1], "TOP", 0, 0)
		end
		Tpl.SetShown(b.text, not c.compact)
		Tpl.SetShown(b.sub, not c.compact)
	end
end

-- FormatProfession. c: card; m: profession or nil; cells: spellbook slots by spell id
local function formatProfession(c, m, cells)
	if c.main then
		placeBackground(c, "profession-overview-card")
	end
	c.profession = m
	if not m then
		c.absentTitle:Show()
		c.absentText:Show()
		for _, b in ipairs(c.spells) do
			b.slot = nil
			b:Hide()
		end
		c.rank:Hide()
		c.name:SetText("")
		if c.unlearnButton then c.unlearnButton:Hide() end
		return
	end
	c.absentTitle:Hide()
	c.absentText:Hide()
	c.name:SetText(m.name)
	if c.main then
		placeBackground(c, "profession-overview-card-" .. m.key)
		Tpl.SetShown(c.unlearnButton, m.abandon)
	end
	updateRank(c.rank, m)
	c.rank:Show()
	local slots = spellsOf(m.key, cells, #c.spells)
	for k, b in ipairs(c.spells) do
		if slots[k] then
			fillSpell(b, slots[k])
			b:Show()
		else
			b.slot = nil
			b:Hide()
		end
	end
	if c.main then
		local PS = N.primarySpells
		if #slots == 1 then
			place(c.spells[1], "BOTTOMLEFT", c, "BOTTOMLEFT", PS.x, PS.single)
		else
			place(c.spells[1], "BOTTOMLEFT", c, "BOTTOMLEFT", PS.x, PS.top)
			place(c.spells[2], "BOTTOMLEFT", c, "BOTTOMLEFT", PS.x, PS.down)
		end
	end
end

-- Rows outside the zone are HIDDEN, not just scrolled away: their spells are secure buttons
-- that no click may reach under the columns or above the window. Scrolling moves one whole
-- row at a time.
local function showRowLines(f)
	local visibleCount = math.min(f.count, N.rowLines)
	local d = PB.offset or 0
	for k, c in ipairs(f.primaries) do
		Tpl.SetShown(c, k <= f.count and k > d and k <= d + visibleCount)
	end
end

-- Layout by row count: at least two (camelot); at most three visible, the columns then
-- losing a row's height; beyond that, the scroll bar and its gutter.
local function layout(f, count)
	local P, S = N.main, N.secondary
	local step = P[2] - P.gap
	local visibleCount = math.min(count, N.rowLines)
	local hasBar = count > N.rowLines
	local width = P[1] - (hasBar and N.gutter or 0)
	for k = #f.primaries + 1, count do
		local c = createPrimary(f.child, k)
		c:SetPoint("TOPLEFT", f.primaries[k - 1], "BOTTOMLEFT", 0, P.gap)
		f.primaries[k] = c
	end
	for _, c in ipairs(f.primaries) do
		c:SetWidth(width)
	end
	f.count = count
	f.zone:SetWidth(width)
	f.zone:SetHeight(visibleCount * step + P.gap)
	f.child:SetWidth(width)
	f.child:SetHeight(count * step + P.gap)
	local compact = visibleCount > 2
	for _, c in ipairs(f.secondaries) do
		c.compact = compact
		c:SetHeight(S[2] - (compact and step or 0))
		placeBackground(c, c.backgroundAtlas)
		placeSpellColumn(c)
	end
	PB.offset = math.max(0, math.min(PB.offset or 0, count - visibleCount))
	f.bar:Configure(count, visibleCount, PB.offset)
	f.zone:SetVerticalScroll(PB.offset * step)
	showRowLines(f)
end

-- ProfessionsBookFrameMixin:Update. Out of combat only: the spell buttons are protected
-- (and the book is closed in combat).
function PB.Update()
	local f = PB.book
	if not f or not f:IsShown() or InCombatLockdown() then return end
	local primaries, secondaries = PB.Read()
	local cells = readSpellbook()
	layout(f, math.max(2, #primaries))
	for i, c in ipairs(f.primaries) do
		if i <= f.count then formatProfession(c, primaries[i], cells) end
	end
	for _, c in ipairs(f.secondaries) do
		formatProfession(c, secondaries[c.key], cells)
	end
end

local function updateCooldowns()
	local f = PB.book
	for _, list in ipairs({ f.primaries, f.secondaries }) do
		for _, c in ipairs(list) do
			for _, b in ipairs(c.spells) do
				if b.slot then updateCooldown(b) end
			end
		end
	end
end

-- ---------- Moving

-- The window moves by its title banner. The book and the crafting page share one saved
-- position (top-center relative to UIParent's). The panel system re-anchors them on every
-- show, so the position is re-applied after it (OnShow, UpdateUIPanelPositions). The tabs
-- follow during the drag. The protected book only moves out of combat.
local POSITION_KEY = "professions"

local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

-- top-center of a frame relative to UIParent's (nil until the frame is placed)
local function topCenter(frame)
	local cx, ux = frame:GetCenter(), UIParent:GetCenter()
	local top, uiTop = frame:GetTop(), UIParent:GetTop()
	if not cx or not ux or not top or not uiTop then return end
	return cx - ux, top - uiTop
end

local function isLocked(f)
	return f == PB.book and InCombatLockdown()
end

function PB.Reposition(f)
	local p = positions()[POSITION_KEY]
	if not p or not f or not f:IsShown() or isLocked(f) then return end
	f:ClearAllPoints()
	f:SetPoint("TOP", UIParent, "TOP", p.x, p.y)
end

local function makeMovable(f, handle)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		if isLocked(f) then return end
		f:StartMoving()
		handle:SetScript("OnUpdate", function() PB.PlaceTabs() end)
	end)
	handle:SetScript("OnDragStop", function()
		handle:SetScript("OnUpdate", nil)
		if isLocked(f) then return end
		f:StopMovingOrSizing()
		local x, y = topCenter(f)
		if x then
			f:ClearAllPoints()
			f:SetPoint("TOP", UIParent, "TOP", x, y)
			-- we save the position ourselves: the client must not save it too
			if f.SetUserPlaced then f:SetUserPlaced(false) end
			positions()[POSITION_KEY] = { x = x, y = y }
		end
		PB.PlaceTabs()
	end)
end

-- ---------- Window

function PB.IsOpen()
	return (PB.book and PB.book:IsShown()) or (TradeSkillFrame and TradeSkillFrame:IsShown()) or false
end

local function updateMicroButton()
	if ForeverUI.UpdateProfessionsMicro then
		ForeverUI.UpdateProfessionsMicro(PB.IsOpen())
	end
end

-- a page opened or closed: update the micro-button and the tabs
local function refresh()
	updateMicroButton()
	if PB.UpdateTabs then PB.UpdateTabs() end
end

local OPEN_EVENTS = { "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN" }

function PB.Build()
	if PB.book then return PB.book end
	local f = CreateFrame("Frame", "ForeverUIProfessionsBook", UIParent)
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:Hide()
	-- panel declared by attributes (GetUIPanelWindowInfo reads them before UIPanelWindows),
	-- set before the secure buttons are created
	for k, v in pairs(PANEL) do
		f:SetAttribute("UIPanelLayout-" .. k, v)
	end
	f:SetAttribute("UIPanelLayout-defined", true)
	f:SetAttribute("UIPanelLayout-enabled", true)
	local skin = Tpl.PortraitWindow(f, {
		portrait = BOOK_ICON, portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = string.format(TRADE_SKILL_TITLE, TRADE_SKILLS),
	})
	-- the portrait is baked round (tools/bake_portrait.py; SetPortraitToTexture leaves it
	-- square): use it whole
	skin.portrait:SetTexCoord(0, 1, 0, 1)
	-- OverrideArt: Profession-Background-Overview instead of the rock, no stripes
	if skin.rock.SetHorizTile then
		skin.rock:SetHorizTile(false)
		skin.rock:SetVertTile(false)
	end
	atlas(skin.rock, "profession-background-overview", true)
	skin.stripes:Hide()
	f.skin = skin
	makeMovable(f, skin.banner)
	local content = CreateFrame("Frame", "ForeverUIProfessionsBookContent", f)
	content:SetAllPoints(f)
	content:SetFrameLevel(f:GetFrameLevel() + N.levels.content)
	f.content = content
	-- rows zone: anything past its three rows is clipped
	local P, S, NV = N.main, N.secondary, N.levels
	local zone = CreateFrame("ScrollFrame", "ForeverUIProfessionsBookScroll", content)
	zone:SetFrameLevel(content:GetFrameLevel() + NV.zone)
	zone:SetPoint("TOPLEFT", content, "TOPLEFT", P.x, P.y)
	local child = CreateFrame("Frame", "ForeverUIProfessionsBookRows", zone)
	child:SetFrameLevel(content:GetFrameLevel() + NV.rowLines)
	child:SetWidth(P[1])
	child:SetHeight(1)
	zone:SetScrollChild(child)
	f.zone, f.child = zone, child
	-- MinimalScrollBar against the zone; one wheel step scrolls one row
	local bar = ForeverUI.CreateScrollBar("ForeverUIProfessionsBookScrollBar", content, zone)
	bar:SetFrameLevel(content:GetFrameLevel() + NV.zone)
	bar.onScroll = function(step)
		PB.offset = step
		zone:SetVerticalScroll(step * (P[2] - P.gap))
		showRowLines(f)
	end
	bar:Hide()
	f.bar = bar
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(_, direction)
		if bar:IsShown() then bar:MoveTo(bar.offset - direction) end
	end)
	-- cards
	f.primaries = { createPrimary(child, 1), createPrimary(child, 2) }
	f.primaries[1]:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
	f.primaries[2]:SetPoint("TOPLEFT", f.primaries[1], "BOTTOMLEFT", 0, P.gap)
	f.secondaries = {}
	for k, key in ipairs(SECONDARY_PROFESSIONS) do
		local c = createSecondary(content, key)
		if k == 1 then
			c:SetPoint("TOPLEFT", zone, "BOTTOMLEFT", 0, S.gap)
		else
			c:SetPoint("TOPLEFT", f.secondaries[k - 1], "TOPRIGHT", S.step, 0)
		end
		f.secondaries[k] = c
	end
	layout(f, 2)
	-- close button (UIPanelCloseButton: HideParentPanel)
	local closeButton = CreateFrame("Button", "ForeverUIProfessionsBookCloseButton", f, "UIPanelCloseButton")
	Tpl.CloseButton(closeButton, f)
	closeButton:SetFrameLevel(f:GetFrameLevel() + N.levels.closeButton)
	f.closeButton = closeButton
	f:SetScript("OnShow", function(self)
		PB.Reposition(self)
		for _, ev in ipairs(OPEN_EVENTS) do self:RegisterEvent(ev) end
		PB.Update()
		PlaySound("igSpellBookOpen")
		refresh()
	end)
	f:SetScript("OnHide", function(self)
		for _, ev in ipairs(OPEN_EVENTS) do self:UnregisterEvent(ev) end
		StaticPopup_Hide("UNLEARN_SKILL")
		PlaySound("igAbilityClose")
		refresh()
	end)
	f:SetScript("OnEvent", function(_, ev)
		if ev == "SPELL_UPDATE_COOLDOWN" then
			updateCooldowns()
		elseif ev ~= "SKILL_LINES_CHANGED" or GetTime() >= silence then
			PB.Update()
		end
	end)
	PB.book = f
	return f
end

-- ---------- Side tabs

-- Side tabs (camelot ProfessionsLargeRightTabMixin, LargeSideTabButtonTemplate) right of the
-- shown page, book or crafting: overview, then primaries, first aid, fishing, cooking (only
-- those with a crafting page). A profession tab casts a spell: it is secure and its parent
-- becomes protected, so the tabs live in their own UIParent child, never a child of or
-- anchored to TradeSkillFrame; they follow it on UpdateUIPanelPositions and hide in combat.
-- Icon at (-3, 0) like the other side tabs (camelot: -4). Too many tabs for the window
-- height shrink together so the last one ends at the window bottom.
local TAB = { side = 55, y = -60, gap = -2, icon = 50, iconX = -3, crop = 0.03125 }
local TAB_ICONS = "Interface" .. SEP .. "ForeverUI" .. SEP .. "tabicons" .. SEP
local SECONDARY_TABS = { "firstaid", "fishing", "cooking" }

-- LargeSideTabButtonTemplate; secure: casts a spell (SecureActionButtonTemplate)
local function createTab(parent, name, secure)
	local O = TAB
	local b = CreateFrame("Button", name, parent, secure and "SecureActionButtonTemplate" or nil)
	b:SetWidth(O.side)
	b:SetHeight(O.side)
	b:RegisterForClicks("LeftButtonUp")
	local background = b:CreateTexture(nil, "BACKGROUND")
	atlas(background, "common-sidetab")
	background:SetAllPoints(b)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(O.icon)
	icon:SetHeight(O.icon)
	icon:SetPoint("CENTER", b, "CENTER", O.iconX, 0)
	icon:SetTexCoord(O.crop, 1 - O.crop, O.crop, 1 - O.crop)
	b.iconX = O.iconX
	local selected = b:CreateTexture(nil, "OVERLAY")
	atlas(selected, "common-sidetab-selected")
	selected:SetAllPoints(b)
	selected:Hide()
	local hover = b:CreateTexture(nil, "HIGHLIGHT")
	atlas(hover, "common-sidetab-hover")
	hover:SetAllPoints(b)
	b.icon, b.selected = icon, selected
	b:SetScript("OnEnter", function(self)
		if not self.tooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
		GameTooltip:SetText(self.tooltip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then place(self.icon, "CENTER", self, "CENTER", self.iconX + 1, -1) end
	end)
	b:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			place(self.icon, "CENTER", self, "CENTER", self.iconX, 0)
			PlaySound("igCharacterInfoTab")
		end
	end)
	return b
end

-- SelectBookPage: close the crafting page (the 3.3.5 trade skill session ends with it),
-- then open the book
function PB.OpenOverview()
	if InCombatLockdown() or (PB.book and PB.book:IsShown()) then return end
	if TradeSkillFrame and TradeSkillFrame:IsShown() then HideUIPanel(TradeSkillFrame) end
	ShowUIPanel(PB.Build())
end

local function createTabs()
	local c = CreateFrame("Frame", "ForeverUIProfessionsTabs", UIParent)
	c:SetWidth(TAB.side)
	c:SetHeight(1)
	c:Hide()
	local overview = createTab(c, "ForeverUIProfessionsTab0")
	overview.icon:SetTexture(TAB_ICONS .. "inv_sidetab_professions_c60")
	overview.tooltip = TRADE_SKILLS
	overview:SetPoint("TOPLEFT", c, "TOPLEFT", 0, TAB.y)
	overview:SetScript("OnClick", PB.OpenOverview)
	c.overview, c.professions, c.count = overview, {}, 0
	PB.tabs = c
	return c
end

local function professionTab(c, k)
	if not c.professions[k] then
		local b = createTab(c, "ForeverUIProfessionsTab" .. k, true)
		b:SetPoint("TOPLEFT", k == 1 and c.overview or c.professions[k - 1], "BOTTOMLEFT", 0, TAB.gap)
		c.professions[k] = b
	end
	return c.professions[k]
end

-- spellbook slot of the spell that opens a profession's crafting page (first group)
local function opener(key, cells)
	local group = SPELLS[key][1]
	for k = #group, 1, -1 do
		if cells[group[k]] then return cells[group[k]] end
	end
end

local function shownWindow()
	if PB.book and PB.book:IsShown() then return PB.book end
	if TradeSkillFrame and TradeSkillFrame:IsShown() then return TradeSkillFrame end
end

-- tab scale from their count and the window height; recomputed only when either changes
-- (PlaceTabs runs every frame during a drag)
local function resize(c, height)
	local O = TAB
	local n = c.count + 1
	local full = n * O.side - (n - 1) * O.gap
	local position = height + O.y
	local e = (position > 0 and full > position) and position / full or 1
	if e == c.scale and #c.professions == c.sizedCount then return e end
	c.scale, c.sizedCount = e, #c.professions
	local list = { c.overview }
	for k = 1, #c.professions do list[k + 1] = c.professions[k] end
	for k, b in ipairs(list) do
		b:SetWidth(O.side * e)
		b:SetHeight(O.side * e)
		b.iconX = O.iconX * e
		b.icon:SetWidth(O.icon * e)
		b.icon:SetHeight(O.icon * e)
		place(b.icon, "CENTER", b, "CENTER", b.iconX, 0)
		if k > 1 then place(b, "TOPLEFT", list[k - 1], "BOTTOMLEFT", 0, O.gap * e) end
	end
	return e
end

-- right of the shown window, in its strata, under its metal border
function PB.PlaceTabs()
	local c = PB.tabs
	if not c or InCombatLockdown() then return end
	local f = shownWindow()
	local right, top = f and f:GetRight(), f and f:GetTop()
	if not right or not top then
		c:Hide()
		return
	end
	local e = resize(c, f:GetHeight() or 0)
	c:ClearAllPoints()
	c:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right, top)
	c:SetHeight(-TAB.y + (c.count + 1) * (TAB.side - TAB.gap) * e)
	c:SetFrameStrata(f:GetFrameStrata())
	c:SetFrameLevel(f:GetFrameLevel() + 1)
	c:Show()
end

-- RefreshRightTabs and RightTabSelected. Out of combat only (secure buttons).
function PB.UpdateTabs()
	if InCombatLockdown() then return end
	local f = shownWindow()
	if not f then
		if PB.tabs then PB.tabs:Hide() end
		return
	end
	local c = PB.tabs or createTabs()
	local primaries, secondaries = PB.Read()
	local cells = readSpellbook()
	local list = {}
	local function add(m)
		local slot = m and PROFESSIONS[m.key].tab and opener(m.key, cells)
		if slot then list[#list + 1] = { m = m, slot = slot } end
	end
	for _, m in ipairs(primaries) do add(m) end
	for _, key in ipairs(SECONDARY_TABS) do add(secondaries[key]) end
	-- the open profession: the crafting page's, unless it is a linked one
	local isOpen
	if f == TradeSkillFrame and not truthy(IsTradeSkillLinked()) then
		isOpen = professionNames()[GetTradeSkillLine() or ""]
	end
	Tpl.SetShown(c.overview.selected, f == PB.book)
	for k, e in ipairs(list) do
		local b = professionTab(c, k)
		local name, rank = GetSpellName(e.slot, BOOKTYPE_SPELL)
		local selected = e.m.key == isOpen
		b.key = e.m.key
		b.icon:SetTexture(TAB_ICONS .. PROFESSIONS[e.m.key].tab)
		b.tooltip = e.m.name
		Tpl.SetShown(b.selected, selected)
		if selected then
			b:SetAttribute("type", nil)
		else
			b:SetAttribute("type", "spell")
		end
		if rank and rank ~= "" then
			b:SetAttribute("spell", name .. "(" .. rank .. ")")
		else
			b:SetAttribute("spell", name)
		end
		b:Show()
	end
	for k = #list + 1, #c.professions do c.professions[k]:Hide() end
	c.count = #list
	PB.PlaceTabs()
end

-- ToggleProfessionsBook: close the book or the open crafting page, else open the book
-- (out of combat only)
function PB.Toggle()
	if PB.book and PB.book:IsShown() then
		HideUIPanel(PB.book)
	elseif TradeSkillFrame and TradeSkillFrame:IsShown() then
		HideUIPanel(TradeSkillFrame)
	elseif InCombatLockdown() then
		UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.1, 0.1, 1.0)
	else
		ShowUIPanel(PB.Build())
	end
end

-- The crafting page replaces the book and moves like it. Entering combat closes the book
-- and hides the tabs (PLAYER_REGEN_DISABLED fires BEFORE the combat lockdown); leaving
-- combat shows them again. The micro-button and tabs follow the crafting page, the tabs
-- also follow panel placement; the crafting page keeps room for the tabs (camelot width).
local watcher = CreateFrame("Frame")
PB.watcher = watcher
local function hookTradeSkill()
	if TradeSkillFrame and not watcher.hooked then
		watcher.hooked = true
		TradeSkillFrame:SetAttribute("UIPanelLayout-width", PANEL_WIDTH)
		if TradeSkillFrame.foreverSkin then
			makeMovable(TradeSkillFrame, TradeSkillFrame.foreverSkin.banner)
		end
		TradeSkillFrame:HookScript("OnShow", function()
			PB.Reposition(TradeSkillFrame)
			refresh()
		end)
		TradeSkillFrame:HookScript("OnHide", refresh)
	end
end
for _, ev in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"SKILL_LINES_CHANGED", "SPELLS_CHANGED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
	watcher:RegisterEvent(ev)
end
watcher:SetScript("OnEvent", function(_, ev, name)
	if ev == "ADDON_LOADED" then
		if name == "Blizzard_TradeSkillUI" then hookTradeSkill() end
	elseif ev == "PLAYER_REGEN_DISABLED" then
		if PB.book and PB.book:IsShown() then HideUIPanel(PB.book) end
		if PB.tabs then PB.tabs:Hide() end
	elseif ev == "TRADE_SKILL_SHOW" then
		if PB.book and PB.book:IsShown() then HideUIPanel(PB.book) end
		PB.UpdateTabs()
	elseif ev ~= "SKILL_LINES_CHANGED" or GetTime() >= silence then
		PB.UpdateTabs()
	end
end)
hookTradeSkill()
-- after the panel system: re-apply the saved position, then place the tabs
if hooksecurefunc then
	hooksecurefunc("UpdateUIPanelPositions", function()
		PB.Reposition(PB.book)
		if TradeSkillFrame then PB.Reposition(TradeSkillFrame) end
		PB.PlaceTabs()
	end)
end
