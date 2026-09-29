-- ForeverUI: the profession crafting page (TradeSkillFrame, from Blizzard_TradeSkillUI) with
-- Camelot's ProfessionsFrame layout; the overview page and side tabs are in ProfessionsBook.lua.
-- The client's TradeSkillFrame stays the host (panel, events, selection): its widgets are hidden
-- and mouse-less, and our list, schematic, rank bar and buttons run on its data. Favorites,
-- tracking, qualities, concentration and orders do not exist in 3.3.5 and are left out.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates
local L = ForeverUI.L

local M = {}
ForeverUI.Professions = M

local SEP = string.char(92)
local FONT = "Fonts" .. SEP .. "FRIZQT__.TTF"
local NUMBER_FONT = "Fonts" .. SEP .. "ARIALN.TTF"
local BUTTONS = "Interface" .. SEP .. "Buttons" .. SEP

local N = {
	window = { 673, 594 },
	portrait = { side = 48, x = 1, y = 1.5 },
	background = { 2, -21, -2, 2 },                -- Bg of PortraitFrameTemplate
	page = { 3, -21 },                       -- Profession-Background-Template2
	list = { 5, -72, 304, down = 5 },
	filter = { -8, -9, 18 },
	search = { 13, -8, 20, gap = -4 },
	zone = { 8, -35, -20, 5 },
	tree = { indent = 10, top = 5, down = 5, right = 5, space = 1, hovered = 1, below = 10 },
	category = { h = 25, text = 8, button = 20, buttonX = -6 },
	recipe = { h = 20, progress = { 26, 15, -9 }, nameX = 4, margin = 10 },
	none = { 0, -60, 200 },
	step = 21,                                -- one wheel step: one recipe
	rank = { 110, -40, 453, 18, background = { 451, 29 }, filled = { 441, 18, 5, -3 }, mask = 1,
		flare = { 53, 16 }, text = -3 },
	link = { -2, -4, 23, background = 34, icon = 25 },
	card = { 2, 0, 360, 484 },
	result = { 28, -28, 47, icon = 53, outline = 68, glow = 66, count = { -4, 1 } },
	name = { 14, 17 },
	tools = { 0, -4 },
	organizer = { -1, -12, 4 },
	cooldown = 400, description = 305,
	reagents = { 0, -20, tag = { 180, 20 }, slot = { 180, 50 }, start = { 1, -20 },
		gap = { 5, 5 }, column = 4, button = 39, nameX = 46, nameSize = { 108, 36 } },
	create = { -9, 7, 80, 28, margin = 30 },
	createAll = { -362, 7 },
	counter = { -185, 11, 31, 20, arrow = { 23, 22 }, minusGap = -6 },
	levels = { page = 1, list = 2, rows = 3, card = 2, rank = 5, closeButton = 22 },
}

-- Camelot's GlobalColor
local COLORS = {
	recipe = { 0.8863, 0.8627, 0.8392 },    -- PROFESSION_RECIPE_COLOR
	missingReagent = { 0.6275, 0.6275, 0.6275 }, -- DISABLED_REAGENT_COLOR
}

local PROGRESS = {
	optimal = { "professions-icon-skill-high", 1, L.TRADESKILL_SKILL_UP_OPTIMAL },
	medium = { "professions-icon-skill-medium", 0, L.TRADESKILL_SKILL_UP_MEDIUM },
	easy = { "professions-icon-skill-low", 0, L.TRADESKILL_SKILL_UP_EASY },
}

-- Profession, found by its spell icon (3.3.5 Spell.dbc), the same in every language: background
-- card, rank fill and flare (c60 variant when Camelot has one). Jewelcrafting and inscription have
-- no card in Camelot: Professions-Recipe-Background is used.
local PROFESSIONS = {
	["trade_alchemy"] = { map = "profession-background-card-alchemy", rank = "alchemy_c60" },
	["trade_blacksmithing"] = { map = "profession-background-card-blacksmithing", rank = "blacksmithing" },
	["trade_engraving"] = { map = "profession-background-card-enchanting", rank = "enchanting_c60" },
	["trade_engineering"] = { map = "profession-background-card-engineering", rank = "engineering" },
	["inv_inscription_tradeskill01"] = { rank = "inscription" },
	["inv_misc_gem_01"] = { rank = "jewelcrafting" },
	["inv_misc_gem_02"] = { rank = "jewelcrafting" },
	["inv_misc_armorkit_17"] = { map = "profession-background-card-leatherworking", rank = "leatherworking" },
	["trade_tailoring"] = { map = "profession-background-card-tailoring", rank = "tailoring" },
	["inv_misc_food_15"] = { map = "profession-background-card-cooking", rank = "cooking" },
	["spell_holy_sealofsacrifice"] = { map = "profession-background-card-firstaid", rank = "firstaid_c60" },
	["trade_mining"] = { map = "profession-background-card-mining", rank = "mining" },
}

-- AUCTION_HOUSE_ITEM_QUALITY_ICON_BORDER_ATLASES / PROFESSIONS_ITEM_QUALITY_-
-- ICON_BORDER_ATLASES (blizzard_colors)
local RESULT_OUTLINE = { [0] = "gray", [1] = "white", [2] = "green", [3] = "blue", [4] = "purple",
	[5] = "orange", [6] = "artifact", [7] = "account" }
local REAGENT_OUTLINE = { [1] = "professions-slot-frame", [2] = "professions-slot-frame-green",
	[3] = "professions-slot-frame-blue", [4] = "professions-slot-frame-epic", [5] = "professions-slot-frame-legendary" }

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

local function atlas(t, name, size)
	return ForeverUI.SetAtlas(t, name, not size)
end

-- Camelot fonts missing in 3.3.5
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
	row = font("ForeverUIFontHighlightNoShadow12", FONT, 12),          -- GameFontHighlight_NoShadow
	category = font("ForeverUIFontGame15Shadow", FONT, 15, nil, true), -- Game15Font_Shadow
	med2 = font("ForeverUIFontHighlightMed2", FONT, 14, nil, true),     -- GameFontHighlightMed2
	small2 = font("ForeverUIFontHighlightSmall2", FONT, 11),            -- GameFontHighlightSmall2
	rank = font("ForeverUIFontNumber12Outline", NUMBER_FONT, 12, "OUTLINE"), -- Number12FontOutline
}

local function truthy(v)
	return v and v ~= 0 and true or false
end

-- ------------------------------------------------------------ profession

-- Current profession's PROFESSIONS entry, and its spell icon
local function profession()
	local name = GetTradeSkillLine()
	local icon = name and GetSpellTexture(name)
	local key = icon and string.lower(string.match(icon, "([^" .. SEP .. SEP .. "/]+)$") or "")
	return key and PROFESSIONS[key], icon
end

-- ------------------------------------------------------------ recipe list

-- Header background: common-button-list-collapseExpand, 18-wide ends and a middle
-- (28 texels of 64) laid tile by tile (see QuestLog.lua)
local HEADER_SLICE = { side = 18, image = 64 }
local function headerBackground(b, layer, mode, alpha)
	local e = ForeverUI.AtlasEntry("common-button-list-collapseexpand")
	if not e then return {} end
	local du = (e[3] - e[2]) / HEADER_SLICE.image
	local side = HEADER_SLICE.side
	local middle = HEADER_SLICE.image - 2 * side
	local pieces = {}
	local function piece(u1, u2)
		local t = b:CreateTexture(nil, layer)
		t:SetTexture(e[1])
		t:SetTexCoord(u1, u2, e[4], e[5])
		if mode then t:SetBlendMode(mode) end
		if alpha then t:SetAlpha(alpha) end
		pieces[#pieces + 1] = t
		return t
	end
	local left = piece(e[2], e[2] + side * du)
	left:SetWidth(side)
	left:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	local right = piece(e[3] - side * du, e[3])
	right:SetWidth(side)
	right:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	b.foreverTiles = b.foreverTiles or {}
	b.foreverTiles[layer] = { left = left, du = du, e = e, middle = middle, side = side, pieces = {}, mode = mode, alpha = alpha }
	return pieces
end

-- Middle tiles, to the row width
local function tileHeader(b, width)
	for layer, T in pairs(b.foreverTiles or {}) do
		for _, t in ipairs(T.pieces) do t:Hide() end
		local rest, x, n = width - 2 * T.side, 0, 0
		while rest > 0 do
			n = n + 1
			local t = T.pieces[n]
			if not t then
				t = b:CreateTexture(nil, layer)
				t:SetTexture(T.e[1])
				if T.mode then t:SetBlendMode(T.mode) end
				if T.alpha then t:SetAlpha(T.alpha) end
				T.pieces[n] = t
			end
			local l = math.min(T.middle, rest)
			local u1 = T.e[2] + T.side * T.du
			t:SetTexCoord(u1, u1 + l * T.du, T.e[4], T.e[5])
			t:SetWidth(l)
			place(t, "TOPLEFT", T.left, "TOPRIGHT", x, 0)
			t:SetPoint("BOTTOMLEFT", T.left, "BOTTOMRIGHT", x, 0)
			t:Show()
			x = x + l
			rest = rest - l
		end
	end
end


local function createCategory(n)
	local h = M.skin
	local C = N.category
	local b = CreateFrame("Button", "ForeverUITradeSkillCategory" .. n, h.child)
	b:SetHeight(C.h)
	b:RegisterForClicks("LeftButtonUp")
	headerBackground(b, "BACKGROUND")
	headerBackground(b, "HIGHLIGHT", "ADD", 0.4)
	local plus = CreateFrame("Frame", nil, b)
	plus:SetWidth(C.button)
	plus:SetHeight(C.button)
	plus:SetPoint("RIGHT", b, "RIGHT", C.buttonX, 0)
	plus.Icon = plus:CreateTexture(nil, "ARTWORK")
	plus.Icon:SetPoint("CENTER", plus, "CENTER", 0, 0)
	b.plus = plus
	local text = b:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(FONTS.category)
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", b, "LEFT", C.text, 0)
	text:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	b.text = text
	local n_ = NORMAL_FONT_COLOR
	text:SetTextColor(n_.r, n_.g, n_.b)
	b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
	b:SetScript("OnLeave", function(self) self.text:SetTextColor(n_.r, n_.g, n_.b) end)
	b:SetScript("OnMouseDown", function(self)
		place(self.text, "LEFT", self, "LEFT", C.text + 1, -1)
		self.text:SetPoint("RIGHT", self.plus, "LEFT", -4, 0)
		place(self.plus.Icon, "CENTER", self.plus, "CENTER", 1, -1)
	end)
	b:SetScript("OnMouseUp", function(self)
		place(self.text, "LEFT", self, "LEFT", C.text, 0)
		self.text:SetPoint("RIGHT", self.plus, "LEFT", -4, 0)
		place(self.plus.Icon, "CENTER", self.plus, "CENTER", 0, 0)
	end)
	b:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		if self.expanded then
			CollapseTradeSkillSubClass(self:GetID())
		else
			ExpandTradeSkillSubClass(self:GetID())
		end
	end)
	return b
end

local function createRecipe(n)
	local h = M.skin
	local R = N.recipe
	local b = CreateFrame("Button", "ForeverUITradeSkillRecipe" .. n, h.child)
	b:SetHeight(R.h)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local progress = CreateFrame("Frame", nil, b)
	progress:SetWidth(R.progress[1])
	progress:SetHeight(R.progress[2])
	progress:SetPoint("LEFT", b, "LEFT", R.progress[3], 0)
	progress:EnableMouse(true)
	progress.Icon = progress:CreateTexture(nil, "OVERLAY")
	progress.Icon:SetPoint("RIGHT", progress, "RIGHT", 0, -1)
	b.progress = progress
	local name = b:CreateFontString(nil, "OVERLAY")
	name:SetFontObject(FONTS.row)
	name:SetJustifyH("LEFT")
	name:SetHeight(12)
	name:SetPoint("LEFT", progress, "RIGHT", R.nameX, 0)
	b.name = name
	local count = b:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(FONTS.row)
	count:SetJustifyH("LEFT")
	count:SetHeight(12)
	count:SetPoint("LEFT", name, "RIGHT", 0, 0)
	b.count = count
	-- Selected (above the name) and hover (HIGHLIGHT layer)
	local choice = CreateFrame("Frame", nil, b)
	choice:SetAllPoints(b)
	choice:SetFrameLevel(b:GetFrameLevel() + 1)
	choice:EnableMouse(false)
	local selectedItem = choice:CreateTexture(nil, "OVERLAY")
	atlas(selectedItem, "professions_recipe_active", true)
	selectedItem:SetPoint("CENTER", b, "CENTER", 0, -1)
	selectedItem:Hide()
	b.selectedItem = selectedItem
	local hover = b:CreateTexture(nil, "HIGHLIGHT")
	atlas(hover, "professions_recipe_hover", true)
	hover:SetPoint("CENTER", b, "CENTER", 0, -1)
	hover:SetAlpha(0.5)
	b.hover = hover
	local function colors(self, white)
		local c = white and { 1, 1, 1 } or COLORS.recipe
		self.name:SetTextColor(c[1], c[2], c[3])
		self.count:SetTextColor(c[1], c[2], c[3])
	end
	b.colors = colors
	local function onEnter(self)
		colors(b, true)
		if b.isTruncated then
			GameTooltip:SetOwner(b.name, "ANCHOR_RIGHT")
			GameTooltip:AddLine(b.fullName, 1, 1, 1, false)
			GameTooltip:Show()
		end
	end
	local function exit()
		colors(b, false)
		GameTooltip:Hide()
	end
	b:SetScript("OnEnter", onEnter)
	b:SetScript("OnLeave", exit)
	progress:SetScript("OnLeave", exit)
	progress:SetScript("OnMouseUp", function(_, button) b:Click(button) end)
	b:SetScript("OnClick", function(self, button)
		if button ~= "LeftButton" then return end
		if IsModifiedClick() then
			HandleModifiedItemClick(GetTradeSkillRecipeLink(self:GetID()))
			return
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
		TradeSkillFrame_SetSelection(self:GetID())
		TradeSkillFrame_Update()
	end)
	return b
end

-- List elements in order: the 3.3.5 flat list made into a tree (a header, its recipes);
-- the "Has skill up" filter, missing in 3.3.5, drops trivial recipes
function M.Elements()
	local elements = {}
	local category
	local queued = {}
	local function close()
		if category then
			local recipes = category.recipes
			if category.expanded and #recipes > 0 then
				elements[#elements + 1] = { space = N.tree.hovered }
				for _, r in ipairs(recipes) do elements[#elements + 1] = r end
				elements[#elements + 1] = { space = N.tree.below }
			end
		end
	end
	for i = 1, GetNumTradeSkills() or 0 do
		local name, kind, numCraftable, expanded = GetTradeSkillInfo(i)
		if name then
			if kind == "header" then
				close()
				category = { index = i, name = name, expanded = expanded and true or false, recipes = {}, category = true }
				queued[#queued + 1] = category
				elements[#elements + 1] = category
			elseif not (M.skillUpsOnly and kind == "trivial") then
				local r = { index = i, name = name, kind = kind, numCraftable = numCraftable or 0, indent = category and true or false }
				if category then
					table.insert(category.recipes, r)
				else
					elements[#elements + 1] = r
				end
			end
		end
	end
	close()
	-- A category emptied by the filter disappears (camelot filters before building the tree);
	-- a collapsed category keeps its header
	if M.skillUpsOnly then
		local keep = {}
		for _, e in ipairs(elements) do
			if not (e.category and e.expanded and #e.recipes == 0) then keep[#keep + 1] = e end
		end
		elements = keep
	end
	return elements
end

local function placeBar(hasBar)
	local h = M.skin
	local Z = N.zone
	h.zone:ClearAllPoints()
	h.zone:SetPoint("TOPLEFT", h.list, "TOPLEFT", Z[1], Z[2])
	-- Without a bar: the same margin on the right as on the left
	h.zone:SetPoint("BOTTOMRIGHT", h.list, "BOTTOMRIGHT", hasBar and Z[3] or -Z[1], Z[4])
end

function M.UpdateList()
	local h = M.skin
	if not h then return end
	local A = N.tree
	local elements = M.Elements()
	-- Content height decides whether the bar is needed
	local height = A.top + A.down
	for i, e in ipairs(elements) do
		height = height + (e.category and N.category.h or e.space or N.recipe.h) + (i > 1 and A.space or 0)
	end
	local view = h.zone:GetHeight()
	if not view or view <= 0 then view = N.window[2] + N.list[2] - N.list.down + N.zone[2] - N.zone[4] end
	local hasBar = height > view
	if hasBar ~= h.hasBar then
		h.hasBar = hasBar
		placeBar(hasBar)
	end
	local width = N.list[3] - N.zone[1] + (hasBar and N.zone[3] or -N.zone[1])
	h.child:SetWidth(width)
	h.child:SetHeight(math.max(height, 1))
	local selected = GetTradeSkillSelectionIndex()
	local y, nc, nr = A.top, 0, 0
	for i, e in ipairs(elements) do
		if i > 1 then y = y + A.space end
		if e.category then
			nc = nc + 1
			local b = h.categories[nc] or createCategory(nc)
			h.categories[nc] = b
			b:SetID(e.index)
			b.expanded = e.expanded
			b.text:SetText(e.name)
			local ic = e.expanded and "common-button-list-minus" or "common-button-list-plus"
			atlas(b.plus.Icon, ic, true)
			local l = width - A.right
			b:SetWidth(l)
			tileHeader(b, l)
			place(b, "TOPLEFT", h.child, "TOPLEFT", 0, -y)
			b:Show()
			y = y + N.category.h
		elseif e.space then
			y = y + e.space
		else
			nr = nr + 1
			local b = h.recipes[nr] or createRecipe(nr)
			h.recipes[nr] = b
			b:SetID(e.index)
			local indent = e.indent and A.indent or 0
			local l = width - A.right - indent
			b:SetWidth(l)
			place(b, "TOPLEFT", h.child, "TOPLEFT", indent, -y)
			M.FillRecipe(b, e, l, selected == e.index)
			b:Show()
			y = y + N.recipe.h
		end
	end
	for i = nc + 1, #h.categories do h.categories[i]:Hide() end
	for i = nr + 1, #h.recipes do h.recipes[i]:Hide() end
	Tpl.SetShown(h.none, #elements == 0)
	-- Scroll bar
	local total = math.ceil(height / N.step)
	local visibleCount = math.floor(view / N.step)
	h.offset = math.max(0, math.min(h.offset or 0, total - visibleCount))
	h.bar:Configure(total, visibleCount, h.offset)
	h.zone:SetVerticalScroll(math.min(h.offset * N.step, math.max(0, height - view)))
end

-- Name width. A row is reused for several recipes: its name keeps the previous width, and the
-- client measures the text within that width (GetStringWidth returns the shown width), so a
-- longer name would be cut. We measure on a separate, unbounded, invisible font string.
local function nameWidth(text)
	local m = M.measure
	if not m then
		m = M.skin.child:CreateFontString(nil, "OVERLAY")
		m:SetFontObject(FONTS.row)
		m:SetPoint("TOPLEFT", M.skin.child, "TOPLEFT", 0, 0)
		m:SetAlpha(0)
		M.measure = m
	end
	m:SetText(text)
	return m:GetStringWidth()
end

function M.FillRecipe(b, e, width, selectedItem)
	local R = N.recipe
	b.fullName = e.name
	b.name:SetText(e.name)
	b.colors(b, false)
	local P = PROGRESS[e.kind]
	if P then
		atlas(b.progress.Icon, P[1], true)
		place(b.progress, "LEFT", b, "LEFT", R.progress[3], P[2])
		b.progress:Show()
		b.progress:SetScript("OnEnter", function()
			b.colors(b, true)
			GameTooltip:SetOwner(b.progress, "ANCHOR_RIGHT")
			local t = P[3]
			local n_ = NORMAL_FONT_COLOR
			-- 3.3.5 does not give the skill points gained: 1 is shown
			GameTooltip:AddLine(string.format(t, 1), n_.r, n_.g, n_.b, true)
			GameTooltip:Show()
		end)
	else
		b.progress:Hide()
	end
	local hasCount = (e.numCraftable or 0) > 0
	if hasCount then
		b.count:SetFormattedText(" [%d] ", e.numCraftable)
		b.count:Show()
	else
		b.count:SetText("")
		b.count:Hide()
	end
	-- Room for the name: the row minus the count, the margin and the progress frame
	local position = width - ((hasCount and b.count:GetStringWidth() or 0) + R.margin + R.progress[1])
	local full = nameWidth(e.name)
	b.name:SetWidth(math.max(1, math.min(position, full)))
	b.isTruncated = full > position
	Tpl.SetShown(b.selectedItem, selectedItem)
	Tpl.SetShown(b.hover, not selectedItem)
end

-- ------------------------------------------------------------ rank bar

function M.UpdateRank()
	local h = M.skin
	local r = h.rank
	local name, rank, maxValue, bonus = GetTradeSkillLine()
	if not name or not maxValue or maxValue <= 0 then
		r:Hide()
		return
	end
	r:Show()
	if bonus and bonus > 0 then
		r.text:SetFormattedText(L.TRADESKILL_NAME_RANK_MODIFIER, name, rank, bonus, maxValue)
	else
		r.text:SetFormattedText(L.TRADESKILL_NAME_RANK, name, rank, maxValue)
	end
	local M_ = profession()
	local strip = M_ and ("skillbar_fill_flipbook_" .. M_.rank) or "skillbar_fill_flipbook_defaultblue"
	local e = ForeverUI.AtlasEntry(strip) or ForeverUI.AtlasEntry("skillbar_fill_flipbook_defaultblue")
	local flare = M_ and ForeverUI.AtlasEntry("skillbar_flare_" .. M_.rank)
	local R = N.rank
	local part = math.min(rank / maxValue, 1)
	-- Mask: from 1 after the fill start, over 453 x the ratio; the fill (441) shows only below it.
	-- Camelot's fill is a 60-frame flipbook 1712 wide that 3.3.5 cannot show: the first frame is used.
	local found = math.min(R.filled[1] - R.mask, R[3] * part)
	if e and found >= 1 then
		r.filled:SetTexture(e[1])
		local du = (e[3] - e[2]) / R.filled[1]
		r.filled:SetTexCoord(e[2] + du * R.mask, e[2] + du * (R.mask + found), e[4], e[5])
		r.filled:SetWidth(found)
		r.filled:Show()
	else
		r.filled:Hide()
	end
	-- Camelot masks the flare too (MaskedTexture Flare): it shows only over the mask width, from the
	-- fill start. 3.3.5 has no mask, so we keep the flare's right part, cut to the visible width;
	-- otherwise it overhangs the bar on the left at low rank.
	local mask = R[3] * part
	if flare and mask >= 1 then
		local l = math.min(R.flare[1], mask)
		local du = (flare[3] - flare[2]) / R.flare[1]
		r.flare:SetTexture(flare[1])
		r.flare:SetTexCoord(flare[3] - du * l, flare[3], flare[4], flare[5])
		r.flare:SetWidth(l)
		place(r.flare, "RIGHT", r, "TOPLEFT", R.filled[3] + R.mask + mask, R.filled[4] - R.filled[2] / 2)
		r.flare:SetAlpha(rank >= maxValue and 0 or 1)
		r.flare:Show()
	else
		r.flare:Hide()
	end
end

-- ------------------------------------------------------------ schematic

-- Sizes fs to its text, wrapped at maxValue wide
local function fitText(fs, text, maxValue)
	fs:SetHeight(200)
	fs:SetText(text)
	fs:SetWidth(maxValue)
	fs:SetWidth(fs:GetStringWidth())
	fs:SetHeight(fs:GetStringHeight())
end

-- Quality and name of an item link; 0 and nil for anything else
local function quality(link)
	if link and string.find(link, "|Hitem:", 1, true) then
		local name, _, q = GetItemInfo(link)
		return q or 0, name
	end
	return 0, nil
end

local function createReagent(n)
	local h = M.skin
	local Rg = N.reagents
	local s = CreateFrame("Frame", nil, h.reagents)
	s:SetWidth(Rg.slot[1])
	s:SetHeight(Rg.slot[2])
	local b = CreateFrame("Button", "ForeverUITradeSkillReagent" .. n, s)
	b:SetWidth(Rg.button)
	b:SetHeight(Rg.button)
	b:SetPoint("LEFT", s, "LEFT", 0, 0)
	local background = b:CreateTexture(nil, "BACKGROUND")
	atlas(background, "professions-slot-bg", true)
	background:SetAllPoints(b)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(b)
	local outline = b:CreateTexture(nil, "OVERLAY")
	outline:SetPoint("TOPLEFT", icon, "TOPLEFT", -5, 4)
	outline:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 4, -5)
	-- UI-Quickslot2 (SetModifyingRequired(false)), BORDER layer, on the button
	b:SetNormalTexture(BUTTONS .. "UI-Quickslot2")
	local frame = b:GetNormalTexture()
	frame:SetDrawLayer("BORDER")
	frame:ClearAllPoints()
	frame:SetAllPoints(b)
	b.icon, b.outline = icon, outline
	local name = s:CreateFontString(nil, "BORDER")
	name:SetFontObject(FONTS.row)
	name:SetJustifyH("LEFT")
	name:SetWidth(Rg.nameSize[1])
	name:SetHeight(Rg.nameSize[2])
	name:SetPoint("LEFT", s, "LEFT", Rg.nameX, 0)
	s.button, s.name = b, name
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetTradeSkillItem(M.selected, self:GetID())
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		if IsModifiedClick() then
			HandleModifiedItemClick(GetTradeSkillReagentItemLink(M.selected, self:GetID()))
		end
	end)
	return s
end

-- After TradeSkillFrame_SetSelection: the selected recipe's schematic
function M.UpdateCard()
	local h = M.skin
	if not h then return end
	local id = GetTradeSkillSelectionIndex()
	local name, kind, numCraftable, _, verb = GetTradeSkillInfo(id)
	local F = h.card
	-- Profession card
	local M_ = profession()
	local map = (M_ and M_.map and ForeverUI.AtlasEntry(M_.map)) and M_.map or "professions-recipe-background"
	atlas(F.map, map, true)
	if not name or kind == "header" then
		M.selected = nil
		F.content:Hide()
		M.UpdateButtons(nil)
		return
	end
	M.selected = id
	F.content:Show()
	-- Result
	local link = GetTradeSkillItemLink(id)
	local q, itemName = quality(link)
	SetPortraitToTexture(F.icon, GetTradeSkillIcon(id))
	local outline = RESULT_OUTLINE[q]
	if outline then
		atlas(F.outline, "auctionhouse-itemicon-border-" .. outline)
		F.outline:Show()
	else
		F.outline:Hide()
	end
	local minValue, maxValue = GetTradeSkillNumMade(id)
	if maxValue and maxValue > 1 then
		if minValue == maxValue then F.count:SetText(minValue) else F.count:SetFormattedText("%d-%d", minValue, maxValue) end
		if F.count:GetWidth() > 39 then F.count:SetFormattedText("~%d", math.floor((minValue + maxValue) / 2)) end
		F.shadow:Show()
	else
		F.count:SetText("")
		F.shadow:Hide()
	end
	local nameText
	if itemName then
		local c = ITEM_QUALITY_COLORS[q]
		local hex = c and (c.hex or string.format("|cff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5)))
		nameText = hex and (hex .. itemName .. "|r") or itemName
	else
		nameText = NORMAL_FONT_COLOR_CODE .. name .. "|r"
	end
	fitText(F.name, nameText, 800)
	-- Tools
	local tools = BuildColoredListString(GetTradeSkillTools(id))
	if tools then
		fitText(F.tools, NORMAL_FONT_COLOR_CODE .. REQUIRES_LABEL .. "|r " .. tools, 800)
		F.tools:Show()
	else
		F.tools:SetText("")
		F.tools:Hide()
	end
	-- Cooldown, then description (vertical layout)
	local O = N.organizer
	local cooldown = GetTradeSkillCooldown(id)
	local previous
	if cooldown then
		F.cooldown:SetText(COOLDOWN_REMAINING .. " " .. SecondsToTime(cooldown))
		place(F.cooldown, "TOPLEFT", F.result, "BOTTOMLEFT", O[1], O[2])
		F.cooldown:Show()
		previous = F.cooldown
	else
		F.cooldown:Hide()
	end
	local description = GetTradeSkillDescription(id)
	F.description:SetWidth(N.description)
	F.description:SetHeight(600)
	F.description:SetText(description or "")
	F.description:SetHeight((description and description ~= "") and (F.description:GetStringHeight() + 1) or 1)
	if previous then
		place(F.description, "TOPLEFT", previous, "BOTTOMLEFT", 0, -(O[3] + 5))
	else
		place(F.description, "TOPLEFT", F.result, "BOTTOMLEFT", O[1], O[2])
	end
	-- Reagents
	local Rg = N.reagents
	local n = GetTradeSkillNumReagents(id) or 0
	Tpl.SetShown(h.reagents, n > 0)
	place(h.reagents, "TOPLEFT", F.description, "BOTTOMLEFT", Rg[1], Rg[2])
	local shownItems = 0
	for i = 1, n do
		local rName, rIcon, required, owned = GetTradeSkillReagentInfo(id, i)
		if rName and rIcon then
			shownItems = shownItems + 1
			local s = h.slots[shownItems] or createReagent(shownItems)
			h.slots[shownItems] = s
			s.button:SetID(i)
			s.button.icon:SetTexture(rIcon)
			local rq = quality(GetTradeSkillReagentItemLink(id, i))
			local ct = REAGENT_OUTLINE[rq]
			if ct then
				atlas(s.button.outline, ct, true)
				s.button.outline:Show()
			else
				s.button.outline:Hide()
			end
			local enough = (owned or 0) >= (required or 0)
			local c = enough and { 1, 1, 1 } or COLORS.missingReagent
			s.name:SetFormattedText(L.TRADESKILL_REAGENT_COUNT .. " %s", tostring(owned or 0), required or 0, rName)
			s.name:SetTextColor(c[1], c[2], c[3])
			local column = math.floor((shownItems - 1) / Rg.column)
			local rowLine = (shownItems - 1) % Rg.column
			place(s, "TOPLEFT", h.reagents, "TOPLEFT", Rg.start[1] + column * (Rg.slot[1] + Rg.gap[1]),
				Rg.start[2] - rowLine * (Rg.slot[2] + Rg.gap[2]))
			s:Show()
		end
	end
	for i = shownItems + 1, #h.slots do h.slots[i]:Hide() end
	M.UpdateButtons(id, name, verb, numCraftable)
end

-- ------------------------------------------------------------ buttons

-- Sets the button text and widens it to fit (never narrower)
local function fitButtonText(b, text)
	b:SetText(text)
	local fs = b:GetFontString()
	local width = (fs and fs:GetStringWidth() or 0) + N.create.margin
	b:SetWidth(math.max(b:GetWidth(), width))
end

function M.UpdateButtons(id, name, verb, numCraftable)
	local h = M.skin
	local B = h.buttons
	if not id or truthy(IsTradeSkillLinked()) then
		B.create:Hide()
		B.all:Hide()
		B.counter:Hide()
		return
	end
	-- Create is enabled when the reagents are there (the 3.3.5 rule); Create All and the counter
	-- do not exist for a spell with a verb (enchanting), as in 3.3.5
	local possible = true
	for i = 1, GetTradeSkillNumReagents(id) or 0 do
		local _, _, required, owned = GetTradeSkillReagentInfo(id, i)
		if (owned or 0) < (required or 0) then possible = false end
	end
	local maxValue = math.abs(numCraftable or 0)
	B.create:Show()
	fitButtonText(B.create, verb or CREATE)
	if possible then B.create:Enable() else B.create:Disable() end
	local multiple = not verb
	Tpl.SetShown(B.all, multiple)
	Tpl.SetShown(B.counter, multiple)
	if multiple then
		fitButtonText(B.all, string.format(L.TRADESKILL_CREATE_ALL_FORMAT, CREATE_ALL, maxValue))
		if possible and maxValue > 0 then B.all:Enable() else B.all:Disable() end
		B.counter.maxValue = maxValue
		if maxValue > 0 then
			B.counter:SetNumber(math.max(1, math.min(GetTradeskillRepeatCount() or 1, maxValue)))
			B.counter:EnableMouse(true)
			B.counter.active = true
		else
			B.counter:SetNumber(0)
			B.counter:EnableMouse(false)
			B.counter.active = false
		end
		M.UpdateArrows()
	end
end

function M.UpdateArrows()
	local c = M.skin.buttons.counter
	local v = c:GetNumber()
	local function state(b, yes) if yes then b:Enable() else b:Disable() end end
	state(c.plus, c.active and v < (c.maxValue or 0))
	state(c.minus, c.active and v > 1)
end

local function changeCounter(step)
	local c = M.skin.buttons.counter
	if not c.active then return end
	c:SetNumber(math.max(1, math.min((c:GetNumber() or 1) + step, c.maxValue or 1)))
	M.UpdateArrows()
end

local function createButtons(page)
	local h = M.skin
	local C, T, K = N.create, N.createAll, N.counter
	local fonts = { GameFontNormal, GameFontHighlight, GameFontDisable }
	local function button(name)
		local b = CreateFrame("Button", name, page)
		b:SetWidth(C[3])
		b:SetHeight(C[4])
		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		b:SetFontString(fs)
		Tpl.ThreeSliceButton(b, "128-redbutton", fonts)
		return b
	end
	local create = button("ForeverUITradeSkillCreateButton")
	create:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", C[1], C[2])
	create:SetScript("OnClick", function()
		if M.selected then DoTradeSkill(M.selected, h.buttons.counter:GetNumber()) end
	end)
	local all = button("ForeverUITradeSkillCreateAllButton")
	all:SetPoint("BOTTOMLEFT", page, "BOTTOMRIGHT", T[1], T[2])
	all:SetScript("OnClick", function()
		local c = h.buttons.counter
		if M.selected and (c.maxValue or 0) > 0 then
			c:SetNumber(c.maxValue)
			DoTradeSkill(M.selected, c.maxValue)
		end
	end)
	-- Counter (NumericInputSpinnerTemplate < InputBoxTemplate)
	local c = CreateFrame("EditBox", "ForeverUITradeSkillInputBox", page)
	c:SetWidth(K[3])
	c:SetHeight(K[4])
	c:SetPoint("BOTTOMLEFT", page, "BOTTOMRIGHT", K[1], K[2])
	c:SetAutoFocus(false)
	c:SetNumeric(true)
	c:SetMaxLetters(3)
	c:SetFontObject(ChatFontNormal)
	c:SetJustifyH("CENTER")
	local edge = "Interface" .. SEP .. "Common" .. SEP .. "Common-Input-Border"
	local g = c:CreateTexture(nil, "BACKGROUND")
	g:SetTexture(edge) g:SetTexCoord(0, 0.0625, 0, 0.625)
	g:SetWidth(8) g:SetHeight(20)
	g:SetPoint("LEFT", c, "LEFT", -5, 0)
	local d = c:CreateTexture(nil, "BACKGROUND")
	d:SetTexture(edge) d:SetTexCoord(0.9375, 1, 0, 0.625)
	d:SetWidth(8) d:SetHeight(20)
	d:SetPoint("RIGHT", c, "RIGHT", 0, 0)
	local m = c:CreateTexture(nil, "BACKGROUND")
	m:SetTexture(edge) m:SetTexCoord(0.0625, 0.9375, 0, 0.625)
	m:SetHeight(20)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	m:SetPoint("RIGHT", d, "LEFT", 0, 0)
	c:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	c:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	c:SetScript("OnEditFocusLost", function() changeCounter(0) end)
	c:SetScript("OnTextChanged", function() M.UpdateArrows() end)
	local function arrow(name, file)
		local f = CreateFrame("Button", name, c)
		f:SetWidth(K.arrow[1])
		f:SetHeight(K.arrow[2])
		f:SetNormalTexture(BUTTONS .. file .. "-Up")
		f:SetPushedTexture(BUTTONS .. file .. "-Down")
		f:SetDisabledTexture(BUTTONS .. file .. "-Disabled")
		f:SetHighlightTexture(BUTTONS .. "UI-Common-MouseHilight")
		f:GetHighlightTexture():SetBlendMode("ADD")
		return f
	end
	local plus = arrow("ForeverUITradeSkillIncrementButton", "UI-SpellbookIcon-NextPage")
	plus:SetPoint("LEFT", c, "RIGHT", 0, 0)
	plus:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		changeCounter(1)
	end)
	local minus = arrow("ForeverUITradeSkillDecrementButton", "UI-SpellbookIcon-PrevPage")
	minus:SetPoint("RIGHT", c, "LEFT", K.minusGap, 0)
	minus:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		changeCounter(-1)
	end)
	c.plus, c.minus = plus, minus
	local wheel = CreateFrame("Frame", nil, c)
	wheel:SetPoint("TOPLEFT", minus, "TOPLEFT")
	wheel:SetPoint("BOTTOMRIGHT", plus, "BOTTOMRIGHT")
	wheel:EnableMouseWheel(true)
	wheel:SetScript("OnMouseWheel", function(_, direction)
		changeCounter((IsShiftKeyDown() and 10 or 1) * (direction > 0 and 1 or -1))
		c:ClearFocus()
	end)
	h.buttons = { create = create, all = all, counter = c }
end

-- ------------------------------------------------------------ filter

-- 3.3.5 calls it with (frame, level) (UIDropDownMenu.lua);
-- ToggleDropDownMenu also sets UIDROPDOWNMENU_MENU_LEVEL
local function initFilter(_, level)
	level = level or UIDROPDOWNMENU_MENU_LEVEL or 1
	if level == 1 then
		local info = UIDropDownMenu_CreateInfo()
		info.text = L.TRADESKILL_FILTER_SKILL_UP
		info.checked = M.skillUpsOnly
		info.keepShownOnClick = 1
		info.func = function()
			M.skillUpsOnly = not M.skillUpsOnly
			M.UpdateList()
		end
		UIDropDownMenu_AddButton(info, level)
		info = UIDropDownMenu_CreateInfo()
		info.text = CRAFT_IS_MAKEABLE
		info.checked = truthy(TradeSkillFrameAvailableFilterCheckButton:GetChecked())
		info.keepShownOnClick = 1
		info.func = function()
			local yes = not truthy(TradeSkillFrameAvailableFilterCheckButton:GetChecked())
			TradeSkillFrameAvailableFilterCheckButton:SetChecked(yes)
			TradeSkillOnlyShowMakeable(yes)
		end
		UIDropDownMenu_AddButton(info, level)
		info = UIDropDownMenu_CreateInfo()
		info.text = L.TRADESKILL_FILTER_SLOTS
		info.hasArrow = 1
		info.notCheckable = 1
		info.value = "slots"
		UIDropDownMenu_AddButton(info, level)
	elseif UIDROPDOWNMENU_MENU_VALUE == "slots" then
		local info = UIDropDownMenu_CreateInfo()
		info.text = L.TRADESKILL_CHECK_ALL
		info.notCheckable = 1
		info.func = function()
			SetTradeSkillInvSlotFilter(0, 1, 1)
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(info, level)
		info = UIDropDownMenu_CreateInfo()
		info.text = L.TRADESKILL_UNCHECK_ALL
		info.notCheckable = 1
		info.func = function()
			for i = 1, select("#", GetTradeSkillInvSlots()) do SetTradeSkillInvSlotFilter(i, 0, 0) end
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(info, level)
		local all = truthy(GetTradeSkillInvSlotFilter(0))
		for i = 1, select("#", GetTradeSkillInvSlots()) do
			info = UIDropDownMenu_CreateInfo()
			info.text = select(i, GetTradeSkillInvSlots())
			info.checked = all or truthy(GetTradeSkillInvSlotFilter(i))
			info.keepShownOnClick = 1
			local index = i
			info.func = function(self)
				local checkMark = truthy(GetTradeSkillInvSlotFilter(0)) or truthy(GetTradeSkillInvSlotFilter(index))
				SetTradeSkillInvSlotFilter(index, checkMark and 0 or 1, 0)
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end
end

-- ------------------------------------------------------------ window

-- The client's frame: invisible and mouse-less; it stays the host
local function suppress(f)
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	TradeSkillFrameTitleText:SetAlpha(0)
	TradeSkillFrameDummyString:SetAlpha(0)
	for i = 1, TRADE_SKILLS_DISPLAYED or 8 do
		local b = _G["TradeSkillSkill" .. i]
		if b then b:SetAlpha(0) b:EnableMouse(false) end
	end
	for _, name in ipairs({ "TradeSkillListScrollFrame", "TradeSkillDetailScrollFrame", "TradeSkillHighlightFrame" }) do
		local fx = _G[name]
		if fx then
			fx:SetAlpha(0)
			fx:EnableMouse(false)
			if fx.EnableMouseWheel then fx:EnableMouseWheel(false) end
			for _, s in ipairs({ "ScrollBar", "ScrollBarScrollUpButton", "ScrollBarScrollDownButton" }) do
				local c = _G[name .. s]
				if c then c:EnableMouse(false) end
			end
		end
	end
	for i = 1, MAX_TRADE_SKILL_REAGENTS or 8 do
		local r = _G["TradeSkillReagent" .. i]
		if r then r:EnableMouse(false) end
	end
	if TradeSkillSkillIcon then TradeSkillSkillIcon:EnableMouse(false) end
	for _, c in ipairs({ TradeSkillLinkButton, TradeSkillFrameAvailableFilterCheckButton, TradeSkillRankFrame,
		TradeSkillFrameEditBox, TradeSkillExpandButtonFrame, TradeSkillInvSlotDropDown, TradeSkillSubClassDropDown,
		TradeSkillCreateButton, TradeSkillCreateAllButton, TradeSkillDecrementButton, TradeSkillInputBox,
		TradeSkillIncrementButton, TradeSkillCancelButton }) do
		if c then ForeverUI.Suppress(c) end
	end
end

-- After TradeSkillFrame_Update: title, portrait, rank, list. Below 75 skill (unless linked),
-- TradeSkillFrame_Update clears the name filter on each update, so the search box is hidden
-- as in 3.3.5 (forcing it would update forever).
function M.Update()
	local f = TradeSkillFrame
	local h = f and f.foreverSkin
	if not h then return end
	local name = GetTradeSkillLine()
	local linked, player = IsTradeSkillLinked()
	if truthy(linked) and player then
		h.title:SetText(string.format("%s %s[%s]|r", string.format(TRADE_SKILL_TITLE, name or ""), HIGHLIGHT_FONT_COLOR_CODE, player))
	else
		h.title:SetText(string.format(TRADE_SKILL_TITLE, name or ""))
	end
	local _, icon = profession()
	if icon then
		SetPortraitToTexture(h.portrait, icon)
	else
		SetPortraitTexture(h.portrait, "player")
	end
	M.UpdateRank()
	Tpl.SetShown(h.link, not truthy(linked) and GetTradeSkillListLink() ~= nil)
	local _, rank = GetTradeSkillLine()
	local search = truthy(linked) or (rank or 0) >= 75
	Tpl.SetShown(h.search, search)
	if not search and h.search:GetText() ~= "" then h.search:SetText("") end
	M.UpdateList()
	M.UpdateCard()
end

function M.Skin()
	local f = TradeSkillFrame
	if not f or f.foreverSkin then return end
	suppress(f)
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
	})
	f.foreverSkin = skin
	M.skin = skin
	-- OverrideArt: Profession-Background-Overview instead of the rock, no stripes
	if skin.rock.SetHorizTile then
		skin.rock:SetHorizTile(false)
		skin.rock:SetVertTile(false)
	end
	atlas(skin.rock, "profession-background-overview", true)
	skin.stripes:Hide()
	local base = f:GetFrameLevel()
	local NV = N.levels
	-- Crafting page
	local page = CreateFrame("Frame", "ForeverUITradeSkillPage", f)
	page:SetAllPoints(f)
	page:SetFrameLevel(base + NV.page)
	skin.page = page
	local pageBackground = page:CreateTexture(nil, "BACKGROUND")
	atlas(pageBackground, "profession-background-template2", true)
	pageBackground:SetPoint("TOPLEFT", f, "TOPLEFT", N.page[1], N.page[2])
	skin.pageBackground = pageBackground
	-- Recipe list
	local Li = N.list
	local list = CreateFrame("Frame", "ForeverUITradeSkillRecipeList", page)
	list:SetWidth(Li[3])
	list:SetPoint("TOPLEFT", page, "TOPLEFT", Li[1], Li[2])
	list:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", Li[1], Li.down)
	list:SetFrameLevel(base + NV.list)
	skin.list = list
	local listBackground = list:CreateTexture(nil, "BACKGROUND")
	atlas(listBackground, "professions-background-summarylist", true)
	listBackground:SetAllPoints(list)
	local none = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	none:SetWidth(N.none[3])
	none:SetPoint("TOP", list, "TOP", N.none[1], N.none[2])
	none:SetText(L.TRADESKILL_NO_RESULTS)
	none:Hide()
	skin.none = none
	-- Filter
	local Fi = N.filter
	local dd = CreateFrame("Frame", "ForeverUITradeSkillFilter", list, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(dd, initFilter)
	UIDropDownMenu_SetText(dd, FILTER)
	Tpl.FilterMenu(dd, Fi[3])
	-- The menu list is at least the button width, wider if its entries need it
	-- (camelot SetMinimumWidth)
	dd.foreverFloor = true
	place(dd, "TOPRIGHT", list, "TOPRIGHT", Fi[1], Fi[2])
	skin.filter = dd
	-- Search (SearchBoxTemplate, as in the quest log)
	local Sr = N.search
	local r = CreateFrame("EditBox", "ForeverUITradeSkillSearchBox", list)
	r:SetHeight(Sr[3])
	r:SetPoint("TOPLEFT", list, "TOPLEFT", Sr[1], Sr[2])
	r:SetPoint("RIGHT", dd, "LEFT", Sr.gap, 0)
	r:SetAutoFocus(false)
	r:SetMaxLetters(60)
	r:SetFontObject("GameFontHighlightSmall")
	r:SetTextInsets(16, 20, 0, 0)
	local function edge(prefix)
		local g = r:CreateTexture(nil, "BACKGROUND")
		atlas(g, prefix .. "-left", true)
		g:SetWidth(8) g:SetHeight(20)
		g:SetPoint("LEFT", r, "LEFT", -5, 0)
		local d = r:CreateTexture(nil, "BACKGROUND")
		atlas(d, prefix .. "-right", true)
		d:SetWidth(8) d:SetHeight(20)
		d:SetPoint("RIGHT", r, "RIGHT", 0, 0)
		local m = r:CreateTexture(nil, "BACKGROUND")
		atlas(m, prefix .. "-middle", true)
		m:SetPoint("TOPLEFT", g, "TOPRIGHT")
		m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	end
	edge("common-search-border")
	local magnifier = r:CreateTexture(nil, "OVERLAY")
	atlas(magnifier, "common-search-magnifyingglass", true)
	magnifier:SetWidth(10) magnifier:SetHeight(10)
	magnifier:SetPoint("LEFT", r, "LEFT", 1, -1)
	local instruction = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	instruction:SetPoint("TOPLEFT", r, "TOPLEFT", 16, 0)
	instruction:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -20, 0)
	instruction:SetJustifyH("LEFT")
	instruction:SetTextColor(0.35, 0.35, 0.35)
	instruction:SetText(SEARCH)
	local clear = CreateFrame("Button", nil, r)
	clear:SetWidth(17) clear:SetHeight(17)
	clear:SetPoint("RIGHT", r, "RIGHT", -3, 0)
	local closeButton = clear:CreateTexture(nil, "ARTWORK")
	atlas(closeButton, "common-search-clearbutton", true)
	closeButton:SetWidth(10) closeButton:SetHeight(10)
	closeButton:SetPoint("CENTER", clear, "CENTER", 0, 0)
	closeButton:SetAlpha(0.5)
	clear:SetScript("OnEnter", function() closeButton:SetAlpha(1) end)
	clear:SetScript("OnLeave", function() closeButton:SetAlpha(0.5) end)
	clear:SetScript("OnClick", function()
		r:SetText("")
		r:ClearFocus()
	end)
	clear:Hide()
	r:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	r:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	r:SetScript("OnEditFocusGained", function() instruction:Hide() end)
	r:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then instruction:Show() end
	end)
	r:SetScript("OnTextChanged", function(self)
		local t = self:GetText()
		if t == "" then clear:Hide() else clear:Show() instruction:Hide() end
		SetTradeSkillItemNameFilter(t)
	end)
	skin.search = r
	-- Scrolling list area
	local zone = CreateFrame("ScrollFrame", "ForeverUITradeSkillListScroll", list)
	skin.zone = zone
	placeBar(false)
	skin.hasBar = false
	local child = CreateFrame("Frame", nil, zone)
	child:SetWidth(1)
	child:SetHeight(1)
	zone:SetScrollChild(child)
	child:SetFrameLevel(base + NV.rows)
	skin.child = child
	skin.categories, skin.recipes, skin.offset = {}, {}, 0
	local bar = ForeverUI.CreateScrollBar("ForeverUITradeSkillScrollBar", list, zone)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", zone, "TOPRIGHT", 0, 0)
	bar:SetPoint("BOTTOMLEFT", zone, "BOTTOMRIGHT", 0, 0)
	bar.onScroll = function(step)
		skin.offset = step
		M.UpdateList()
	end
	skin.bar = bar
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(_, direction)
		if bar:IsShown() then bar:MoveTo(bar.offset - direction * 3) end
	end)
	-- Rank bar
	local R = N.rank
	local rank = CreateFrame("Frame", "ForeverUITradeSkillRankBar", page)
	rank:SetWidth(R[3])
	rank:SetHeight(R[4])
	rank:SetPoint("TOPLEFT", page, "TOPLEFT", R[1], R[2])
	rank:SetFrameLevel(base + NV.rank)
	local rankBackground = rank:CreateTexture(nil, "BACKGROUND")
	atlas(rankBackground, "professions-skillbar-bg", true)
	rankBackground:SetWidth(R.background[1]) rankBackground:SetHeight(R.background[2])
	rankBackground:SetPoint("TOPLEFT", rank, "TOPLEFT", 0, 0)
	local filled = rank:CreateTexture(nil, "BORDER")
	filled:SetHeight(R.filled[2])
	filled:SetPoint("TOPLEFT", rank, "TOPLEFT", R.filled[3] + R.mask, R.filled[4])
	local flare = rank:CreateTexture(nil, "ARTWORK")
	flare:SetWidth(R.flare[1]) flare:SetHeight(R.flare[2])
	flare:SetBlendMode("ADD")
	local rankFrame = rank:CreateTexture(nil, "OVERLAY")
	atlas(rankFrame, "professions-skillbar-frame", true)
	rankFrame:SetWidth(R.background[1]) rankFrame:SetHeight(R.background[2])
	rankFrame:SetPoint("TOPLEFT", rank, "TOPLEFT", 0, 0)
	local rankText = CreateFrame("Frame", nil, rank)
	rankText:SetHeight(R[4])
	rankText:SetPoint("LEFT", rank, "LEFT", 0, R.text)
	rankText:SetPoint("RIGHT", rank, "RIGHT", 0, R.text)
	rankText:SetFrameLevel(rank:GetFrameLevel() + 1)
	local t = rankText:CreateFontString(nil, "ARTWORK")
	t:SetFontObject(FONTS.rank)
	t:SetPoint("CENTER", rankText, "CENTER", 0, 0)
	rank.filled, rank.flare, rank.text = filled, flare, t
	skin.rank = rank
	-- Link button
	local Ln = N.link
	local link = CreateFrame("Button", "ForeverUITradeSkillLinkButton", page)
	link:SetWidth(Ln[3]) link:SetHeight(Ln[3])
	link:SetPoint("LEFT", rank, "RIGHT", Ln[1], Ln[2])
	link:SetFrameLevel(base + NV.rank)
	local linkBackground = link:CreateTexture(nil, "BACKGROUND")
	linkBackground:SetWidth(Ln.background) linkBackground:SetHeight(Ln.background)
	linkBackground:SetPoint("CENTER", link, "CENTER", 0, 0)
	local linkIcon = link:CreateTexture(nil, "ARTWORK")
	atlas(linkIcon, "common-icon-chatlink", true)
	linkIcon:SetWidth(Ln.icon) linkIcon:SetHeight(Ln.icon)
	linkIcon:SetPoint("CENTER", link, "CENTER", 0, 0)
	local function applyLinkState(state) atlas(linkBackground, "common-button-tertiary-square-" .. state, true) end
	applyLinkState("normal")
	link:SetScript("OnEnter", function(self)
		applyLinkState("hover")
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(LINK_TRADESKILL_TOOLTIP, nil, nil, nil, nil, 1)
		GameTooltip:Show()
	end)
	link:SetScript("OnLeave", function()
		applyLinkState("normal")
		GameTooltip:Hide()
	end)
	link:SetScript("OnMouseDown", function() applyLinkState("pressed") end)
	link:SetScript("OnMouseUp", function(self) applyLinkState(self:IsMouseOver() and "hover" or "normal") end)
	link:SetScript("OnClick", function()
		local l = GetTradeSkillListLink()
		if l and not ChatEdit_InsertLink(l) then
			ChatEdit_GetLastActiveWindow():Show()
			ChatEdit_InsertLink(l)
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	skin.link = link
	-- Schematic
	local Cd = N.card
	local card = CreateFrame("Frame", "ForeverUITradeSkillSchematic", page)
	card:SetWidth(Cd[3])
	card:SetHeight(Cd[4])
	card:SetPoint("TOPLEFT", list, "TOPRIGHT", Cd[1], Cd[2])
	card:SetFrameLevel(base + NV.card)
	local F = { frame = card }
	F.map = card:CreateTexture(nil, "BACKGROUND")
	F.map:SetAllPoints(card)
	local cardEdge = Tpl.StretchedAtlas(card, "common-insideframe", "BORDER")
	cardEdge.rect:SetAllPoints(card)
	-- Recipe content (hidden without a recipe)
	local content = CreateFrame("Frame", nil, card)
	content:SetAllPoints(card)
	F.content = content
	local Rs = N.result
	local result = CreateFrame("Button", "ForeverUITradeSkillOutputIcon", content)
	result:SetWidth(Rs[3]) result:SetHeight(Rs[3])
	result:SetPoint("TOPLEFT", card, "TOPLEFT", Rs[1], Rs[2])
	result:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	F.result = result
	F.icon = result:CreateTexture(nil, "BORDER")
	F.icon:SetWidth(Rs.icon) F.icon:SetHeight(Rs.icon)
	F.icon:SetPoint("CENTER", result, "CENTER", 0, 0)
	F.outline = result:CreateTexture(nil, "OVERLAY")
	F.outline:SetWidth(Rs.outline) F.outline:SetHeight(Rs.outline)
	F.outline:SetPoint("CENTER", result, "CENTER", 0, 0)
	local glow = result:CreateTexture(nil, "HIGHLIGHT")
	atlas(glow, "auctionhouse-itemicon-border-white", true)
	glow:SetWidth(Rs.glow) glow:SetHeight(Rs.glow)
	glow:SetPoint("CENTER", result, "CENTER", 0, 0)
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.2)
	local resultOverlay = CreateFrame("Frame", nil, result)
	resultOverlay:SetAllPoints(result)
	resultOverlay:SetFrameLevel(result:GetFrameLevel() + 1)
	F.count = resultOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	F.count:SetJustifyH("RIGHT")
	F.count:SetPoint("BOTTOM", result, "BOTTOMRIGHT", Rs.count[1], Rs.count[2])
	F.shadow = resultOverlay:CreateTexture(nil, "ARTWORK")
	atlas(F.shadow, "battlebar-swappetshadow", true)
	F.shadow:SetAlpha(0.8)
	F.shadow:SetPoint("TOPLEFT", F.count, "TOPLEFT", -10, 10)
	F.shadow:SetPoint("BOTTOMRIGHT", F.count, "BOTTOMRIGHT", 10, -10)
	F.shadow:Hide()
	result:SetScript("OnEnter", function(self)
		if not M.selected then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetTradeSkillItem(M.selected)
		GameTooltip:Show()
	end)
	result:SetScript("OnLeave", function() GameTooltip:Hide() end)
	result:SetScript("OnClick", function()
		if M.selected then HandleModifiedItemClick(GetTradeSkillItemLink(M.selected)) end
	end)
	F.name = content:CreateFontString(nil, "ARTWORK")
	F.name:SetFontObject(FONTS.med2)
	F.name:SetJustifyH("LEFT")
	F.name:SetJustifyV("TOP")
	F.name:SetPoint("LEFT", result, "RIGHT", N.name[1], N.name[2])
	F.tools = content:CreateFontString(nil, "ARTWORK")
	F.tools:SetFontObject(FONTS.small2)
	F.tools:SetJustifyH("LEFT")
	F.tools:SetJustifyV("TOP")
	F.tools:SetPoint("TOPLEFT", F.name, "BOTTOMLEFT", N.tools[1], N.tools[2])
	F.cooldown = content:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
	F.cooldown:SetJustifyH("LEFT")
	F.cooldown:SetWidth(N.cooldown)
	F.description = content:CreateFontString(nil, "ARTWORK")
	F.description:SetFontObject(FONTS.small2)
	F.description:SetJustifyH("LEFT")
	F.description:SetJustifyV("TOP")
	skin.card = F
	-- Reagents
	local Rg = N.reagents
	local reagents = CreateFrame("Frame", "ForeverUITradeSkillReagents", content)
	reagents:SetWidth(Rg.tag[1])
	reagents:SetHeight(Rg.tag[2])
	local tag = reagents:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
	tag:SetJustifyH("LEFT")
	tag:SetWidth(Rg.tag[1])
	tag:SetHeight(Rg.tag[2])
	tag:SetPoint("TOPLEFT", reagents, "TOPLEFT", 0, 0)
	tag:SetText(L.TRADESKILL_REAGENTS)
	skin.reagents, skin.slots = reagents, {}
	-- Buttons
	createButtons(page)
	Tpl.CloseButton(TradeSkillFrameCloseButton, f)
	TradeSkillFrameCloseButton:SetFrameLevel(base + NV.closeButton)
	hooksecurefunc("TradeSkillFrame_Update", M.Update)
	hooksecurefunc("TradeSkillFrame_SetSelection", M.UpdateCard)
end

M.Skin()

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("UPDATE_TRADESKILL_RECAST")
watcher:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name == "Blizzard_TradeSkillUI" then M.Skin() end
	elseif M.skin and TradeSkillFrame:IsShown() and M.skin.buttons.counter.active then
		M.skin.buttons.counter:SetNumber(GetTradeskillRepeatCount())
		M.UpdateArrows()
	end
end)
