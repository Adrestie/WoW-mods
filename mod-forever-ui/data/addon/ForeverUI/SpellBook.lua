-- ForeverUI: camelot's spellbook (blizzard_playerspells), drawn inside WotLK's SpellBookFrame.
-- SpellBookFrame keeps its open/close paths (ToggleSpellBook, P key, micro button) and its close
-- button, re-skinned, so closing never goes through our code. Its art and its twelve spell
-- buttons are hidden.
--
-- Casting is protected, and WotLK's buttons cast from their book's internal state, so each cell
-- is a secure button (SecureActionButtonTemplate, type "spell"). Out of combat, every category,
-- page and group is computed and published to a secure controller
-- (SecureHandlerAttributeTemplate). Tabs, arrows, wheel, groups, settings and resize only send
-- it requests; its "show" snippet places the cells, then CallMethod runs ordinary code for
-- textures and texts, which the client allows in combat. The same path runs out of combat.
-- Only the computation waits for the end of combat (a spell learned or a pet summoned in it).
--
-- Differences with camelot:
--   * 3.3.5 has no texture masks: square icons keep their corners; passive icons are rounded
--     by SetPortraitToTexture.
--   * 3.3.5 has no upcoming spells: nothing grayed or "available at level n".
--   * pet spells cast by name; right click toggles autocast (/petautocasttoggle).
--   * WotLK's panel keeps its "left" UI panel area; the book sits where camelot puts a
--     "center" panel, without pushing the others.

ForeverUI = ForeverUI or {}

local S = {}
ForeverUI.SpellBook = S

-- Layout values from blizzard_playerspells: PlayerSpellsFrame, SpellBookFrame,
-- CategoryTabSystem, PagedSpellsFrame (PagedCondensedVerticalGrid), PagingControls.
local G = {
	width = 1618, compactWidth = 809, height = 720, top = -116,
	bookW = 1612, reducedBookW = 806, bookH = 702, bookBottom = 4,
	tabsX = 70, tabsY = -26, tabW = 44, tabH = 32, tabGap = 1,
	tabIconW = 34, tabIconH = 33,
	pagesTop = -50, viewW = 680, viewH = 590, view1X = 85, viewY = -45, view2X = -50,
	columns = 3, gapX = 15, gapY = 10, headerH = 51, spellH = 60, space = 20,
	pagerX = -75, pagerY = 40, pagerGap = 8, arrowSide = 32,
	buttonSide = 40, iconSide = 36, textX = 50,
	cellsPerView = 24,
	closeX = -2, closeY = 1, redSide = 24,
	portraitX = -5, portraitY = 7, portraitSide = 62,
	titleX1 = 58, titleX2 = -24, titleY = -1, titleH = 20,
	settingsX = -30, settingsY = -27, settingsW = 15, settingsH = 16,
	-- flyout (SpellBookItemButtonMixin, FlyoutButtonTemplate, SpellFlyout): opens to the RIGHT,
	-- offset -4, 42 high; arrow 15 x 6, 4 from the edge closed, 2 open; small buttons of 30,
	-- first at 9, gap 4, 9 after the last; border tinted 0.7
	flyoutOffset = -4, flyoutH = 42, arrowW = 15, arrowH = 6,
	arrowClosed = 4, arrowOpen = 2, smallSide = 30, flyoutStart = 9,
	flyoutGap = 4, flyoutEnd = 9, flyoutTint = 0.7,
	smallFrame = 35, smallStateW = 31.6, smallStateH = 30.9,
}
G.cellW = (G.viewW - G.gapX * (G.columns - 1)) / G.columns

-- metal corners: PortraitFrameTemplate as camelot adjusts it (top-right and bottom-right
-- x - 2, bottom y = -8)
local METAL = {
	{ key = "topLeft", name = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ key = "topRight", name = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ key = "bottomLeft", name = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ key = "bottomRight", name = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

local INK = { 0.18, 0.106, 0.059 }       -- SPELLBOOK_FONT_COLOR
local FONT = "Fonts\\FRIZQT__.TTF"
local L = ForeverUI.L
local TEXT = {
	title = SPELLBOOK,
	page = L.SPELLBOOK_PAGE,                -- PAGE_NUMBER_WITH_MAX
	passive = SPELL_PASSIVE,
	pet = PET,
	-- settings: camelot's SPELLBOOK_FILTER_PASSIVES and SHOW_ALL_SPELL_RANKS
	hidePassives = L.SPELLBOOK_HIDE_PASSIVES,
	allRanks = SHOW_ALL_SPELL_RANKS,
	flyouts = L.SPELLBOOK_USE_FLYOUTS,
	passivesDisabled = L.SPELLBOOK_HIDE_PASSIVES_DISABLED,   -- SPELLBOOK_SEARCH_HIDE_PASSIVES_DISABLED
}

-- Settings menu, made of secure buttons. It copies the client list as DropDown.lua skins it
-- (3.3.5 UIDropDownMenu.lua, UIDropDownMenuTemplates.xml): DIALOG strata, TOPLEFT on the
-- arrow's BOTTOMLEFT; rows of 20 (ForeverUI's UIDROPDOWNMENU_BUTTON_HEIGHT) at
-- x = 5 + 12 - 6 (checkbox, MENU mode) and y = -15 - (n - 1) x 20; list n x 20 + 2 x 15 high
-- and longest text + 40 + 25 wide, rows 25 narrower; text 20 from the edge; checkbox
-- common-dropdown-ticksquare 12, yellow check 15 x 14 at (2, 1); background
-- common-dropdown-bg-c60 nine-slice (18; 9, 6, 9, 12) at 0.925. It closes 2 s after the
-- mouse leaves (UIDROPDOWNMENU_SHOW_TIME), or by the arrow.
local MENU = {
	rowH = 20, edge = 15, rowX = 11, textX = 20, extraWidth = 40, margin = 25,
	checkbox = 12, checkMarkW = 15, checkMarkH = 14, checkMarkX = 2, checkMarkY = 1,
	backgroundCorner = 18, backgroundMargins = { 9, 6, 9, 12 }, backgroundAlpha = 0.925, pending = 2,
}
-- settings and their bit in the settings combination (reg); flyouts is checked when its bit
-- is ABSENT (the bit means "no groups")
local SETTINGS = {
	{ bit = 1, text = TEXT.hidePassives },
	{ bit = 2, text = TEXT.flyouts, inverse = true },
	{ bit = 4, text = TEXT.allRanks },
}
local SEP = string.char(92)
local ROCK = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock"
local ARROWS = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-SpellbookIcon-"
local SQUARE_HOVER = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Common-MouseHilight"
local CLASS_ICON = "Interface" .. SEP .. "ForeverUI" .. SEP .. "icons" .. SEP .. "classicon_"
-- portrait: the icon of camelot's General line (inv_misc_book_09), with its round mask baked
-- in (tools/bake_masks.py)
local PORTRAIT = "Interface" .. SEP .. "ForeverUI" .. SEP .. "spellbook" .. SEP .. "portrait"

local function settings()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.spellbook = ForeverUIDB.spellbook or {}
	return ForeverUIDB.spellbook
end

local function font(fs, size, c)
	fs:SetFont(FONT, size)
	c = c or INK
	fs:SetTextColor(c[1], c[2], c[3])
end

-- Hide a WotLK region or frame for good: texture, alpha, visibility and mouse. WotLK's code
-- shows again what is only hidden.
local function suppress(f)
	if not f then return end
	if f.SetTexture then f:SetTexture(nil) end
	f:SetAlpha(0)
	if f.EnableMouse then f:EnableMouse(false) end
	f:Hide()
end

-- ---------------------------------------------------------------- Data
-- camelot's categories: one per spell tab (General, then one per talent tree), plus the pet.
-- General shows the class icon.
local function categories()
	local list = {}
	for i = 1, GetNumSpellTabs() do
		local name, icon, offset, count = GetSpellTabInfo(i)
		if name then
			if i == 1 then
				local _, className = UnitClass("player")
				icon = CLASS_ICON .. string.lower(className or "warrior")
			end
			table.insert(list, { name = name, icon = icon, offset = offset, count = count, book = BOOKTYPE_SPELL })
		end
	end
	local numPetSpells = HasPetSpells()
	if numPetSpells and numPetSpells > 0 then
		table.insert(list, {
			name = TEXT.pet, icon = GetPetIcon and GetPetIcon() or nil,
			offset = 0, count = numPetSpells, book = BOOKTYPE_PET, pet = true,
		})
	end
	return list
end
S.categories = categories
S.G = G
S.font = font

-- Spell options: passives = hide passives, flyouts = no flyout groups, ranks = all ranks.
-- Defaults: the saved settings and the ShowAllSpellRanks CVar.
local function currentOptions()
	return { passives = settings().hidePassives and true or false,
		flyouts = settings().noFlyouts and true or false,
		ranks = GetCVar("ShowAllSpellRanks") == "1" }
end

-- Spells of a category. Without all ranks, a spell keeps only its highest rank (the last of
-- the line). Hide passives (camelot's spellBookHidePassives, missing in 3.3.5, is kept in
-- ForeverUIDB) removes passives. opts: optional, defaults to currentOptions()
local function spellsOf(cat, opts)
	opts = opts or currentOptions()
	local spells, last = {}, {}
	local allRanks = opts.ranks
	local noPassives = opts.passives
	for slot = cat.offset + 1, cat.offset + cat.count do
		local name, rank = GetSpellName(slot, cat.book)
		local passive = name and IsPassiveSpell(slot, cat.book) and true or false
		if name and not (noPassives and passive) then
			local spell = { slot = slot, book = cat.book, name = name, rank = rank or "", passive = passive,
				icon = GetSpellTexture(slot, cat.book), pet = cat.pet }
			if not allRanks and last[name] then
				spells[last[name]] = spell
			else
				table.insert(spells, spell)
				last[name] = #spells
			end
		end
	end
	return spells
end
S.spellsOf = spellsOf

-- ------------------------------------------------------------ Flyouts
-- "Group Similar Spells on Flyouts" (SPELLBOOK_USE_FLYOUTS). camelot's server puts a flyout
-- entry in the book and removes its spells (IsSpellBookItemLooseFlyoutMember). 3.3.5 has
-- neither, so the groups are camelot's, from SpellFlyout.db2 and SpellFlyoutItem.db2 (name,
-- description, icon, spells in slot order), minus the two empty ones (263, 265) and the two
-- with only camelot spells (252 Spell Resistances, 257 Weapon Proficiencies). Each camelot
-- list is followed by the class spells TBC and WotLK add to that family (Spell.dbc,
-- SkillLineAbility.dbc).
-- A spell joins a group BY NAME (GetSpellInfo(id)), so the ranks 3.3.5 adds follow the
-- original one. camelot-only ids (above one million) do not exist here and are ignored.
local FLYOUTS = {
	-- Portals and teleports: one group per faction (SpellFlyout race mask). After camelot's
	-- list, the TBC and WotLK cities: Exodar / Silvermoon, Shattrath (one spell per faction),
	-- Theramore / Stonard, Dalaran (the same spell for both).
	{ id = 248, name = L.SPELLBOOK_FLYOUT_PORTAL, icon = "spell_arcane_portalstormwind", faction = "Alliance",
		text = L.SPELLBOOK_FLYOUT_PORTAL_DESC,
		spells = { 11419, 11416, 10059, 32266, 33691, 49360, 53142 } },
	{ id = 249, name = L.SPELLBOOK_FLYOUT_PORTAL, icon = "spell_arcane_portalorgrimmar", faction = "Horde",
		text = L.SPELLBOOK_FLYOUT_PORTAL_DESC,
		spells = { 11417, 11420, 11418, 32267, 35717, 49361, 53142 } },
	{ id = 250, name = L.SPELLBOOK_FLYOUT_TELEPORT, icon = "spell_arcane_teleportstormwind", faction = "Alliance",
		text = L.SPELLBOOK_FLYOUT_TELEPORT_DESC,
		spells = { 3565, 3562, 3561, 1297659, 32271, 33690, 49359, 53140 } },
	{ id = 251, name = L.SPELLBOOK_FLYOUT_TELEPORT, icon = "spell_arcane_teleportorgrimmar", faction = "Horde",
		text = L.SPELLBOOK_FLYOUT_TELEPORT_DESC,
		spells = { 3567, 3566, 3563, 1297659, 32272, 35715, 49358, 53140 } },
	{ id = 253, name = L.SPELLBOOK_FLYOUT_ASPECT, icon = "ability_hunter_aspectmastery",
		text = L.SPELLBOOK_FLYOUT_ASPECT_DESC,
		spells = { 13163, 13165, 14318, 14319, 14320, 14321, 14322, 25296, 5118, 13161,
			1299445, 1299446, 1299447, 13159, 20043, 20190,
			34074, 61846 } },                        -- + Viper, Dragonhawk
	{ id = 259, name = L.SPELLBOOK_FLYOUT_SUMMON_DEMON, icon = "spell_shadow_summonimp",
		text = L.SPELLBOOK_FLYOUT_SUMMON_DEMON_DESC,
		spells = { 688, 697, 712, 713, 691,
			30146 } },                               -- + Felguard
	{ id = 261, name = L.SPELLBOOK_FLYOUT_IMP_SPELLS, icon = "spell_fire_firebolt",
		text = L.SPELLBOOK_FLYOUT_IMP_SPELLS_DESC,
		spells = { 20801, 6307, 2949, 4511 } },
	{ id = 262, name = L.SPELLBOOK_FLYOUT_SHAPESHIFT, icon = "ability_racial_bearform",
		text = L.SPELLBOOK_FLYOUT_SHAPESHIFT_DESC,
		spells = { 5487, 9634, 1066, 768, 783, 24858,
			33943, 40120, 33891 } },                 -- + Flight, Swift Flight, Tree of Life
	{ id = 264, name = L.SPELLBOOK_FLYOUT_BLESSINGS, icon = "spell_magic_magearmor",
		text = L.SPELLBOOK_FLYOUT_BLESSINGS_DESC,
		-- 1038 (camelot's Blessing of Salvation) is Hand of Salvation here: it goes with the other
		-- Hands, in Utility Blessings
		spells = { 20217, 25291, 19838, 19837, 19836, 19835, 19834, 19740, 25290,
			19854, 19853, 19852, 19850, 19742, 19979, 19978, 19977,
			20911 } },                               -- + Sanctuary
	{ id = 267, name = L.SPELLBOOK_FLYOUT_PET_UTILITIES, icon = "ability_hunter_beasttaming",
		text = L.SPELLBOOK_FLYOUT_PET_UTILITIES_DESC,
		spells = { 883, 982, 6991, 2641, 1515, 1462, 5149 } },
	{ id = 268, name = L.SPELLBOOK_FLYOUT_TRACKING, icon = "ability_tracking",
		text = L.SPELLBOOK_FLYOUT_TRACKING_DESC,
		spells = { 1494, 19878, 19879, 19880, 19882, 19885, 19883, 19884 } },
	{ id = 269, name = L.SPELLBOOK_FLYOUT_STANCES, icon = "ability_warrior_offensivestance",
		text = L.SPELLBOOK_FLYOUT_STANCES_DESC,
		spells = { 2457, 71, 2458 } },
	{ id = 270, name = AURAS, icon = "spell_holy_devotionaura",
		text = L.SPELLBOOK_FLYOUT_AURAS_DESC,
		spells = { 10301, 10300, 10299, 10298, 7294, 10293, 10292, 1032, 10291, 643,
			10290, 465, 19746, 20218, 19900, 19899, 19891, 19898, 19897, 19888,
			19896, 19895, 19876,
			32223 } },                               -- + Crusader Aura
	{ id = 272, name = L.SPELLBOOK_FLYOUT_GREATER_BLESSINGS, icon = "spell_holy_greaterblessingofkings",
		text = L.SPELLBOOK_FLYOUT_GREATER_BLESSINGS_DESC,
		spells = { 25895, 25898, 25916, 25782, 25918, 25894, 25890,
			25899 } },                               -- + Greater Sanctuary
	{ id = 273, name = L.SPELLBOOK_FLYOUT_UTILITY_BLESSINGS, icon = "spell_holy_sealofvalor",
		text = L.SPELLBOOK_FLYOUT_UTILITY_BLESSINGS_DESC,
		spells = { 10278, 5599, 1022, 1044, 20729, 6940,
			1038 } },                                -- + Hand of Salvation
	-- Two groups camelot does not have: paladin seals and judgements. No id, description or
	-- icon: the group uses its first spell's icon. Spell ids from Spell.dbc and
	-- SkillLineAbility.dbc.
	{ name = L.SPELLBOOK_FLYOUT_SEALS,
		spells = { 21084, 20164, 20165, 20166, 20375, 31801, 53736 } },
	{ name = L.SPELLBOOK_FLYOUT_JUDGEMENTS,
		spells = { 20271, 53408, 53407 } },
}
S.FLYOUTS = FLYOUTS

-- Group of a spell name: { flyout, order of the name in the group }. byName is built once;
-- a name can be in two groups (Dalaran, in both factions'), the player's faction wins.
local byName
local function flyoutOf(name)
	if not byName then
		byName = {}
		for _, v in ipairs(FLYOUTS) do
			local order, seen = 0, {}
			for _, id in ipairs(v.spells) do
				local n = GetSpellInfo(id)
				if n and not seen[n] then
					seen[n] = true
					order = order + 1
					byName[n] = byName[n] or {}
					table.insert(byName[n], { flyout = v, order = order })
				end
			end
		end
	end
	local faction = UnitFactionGroup("player")
	for _, m in ipairs(byName[name] or {}) do
		if not m.flyout.faction or m.flyout.faction == faction then
			return m
		end
	end
end

-- Groups of ONE category: a group only joins spells of the same tab (warrior stances, each
-- in its own tree, stay alone; mage portals and teleports, all in one tab, are grouped).
-- It needs at least two DIFFERENT spells: two ranks of one spell are not a group. Its spells
-- follow the group order.
local function groupsOf(spells)
	local groups = {}
	for _, spell in ipairs(spells) do
		local m = flyoutOf(spell.name)
		if m then
			local g = groups[m.flyout]
			if not g then
				g = { members = {}, names = {}, distinctCount = 0 }
				groups[m.flyout] = g
			end
			spell.order = m.order
			table.insert(g.members, spell)
			if not g.names[spell.name] then
				g.names[spell.name] = true
				g.distinctCount = g.distinctCount + 1
			end
		end
	end
	for v, g in pairs(groups) do
		if g.distinctCount < 2 then
			groups[v] = nil
		else
			table.sort(g.members, function(a, b)
				if a.order ~= b.order then return a.order < b.order end
				return a.slot < b.slot
			end)
		end
	end
	return groups
end

-- What a category shows: its spells and, when grouping, each group in place of its first
-- spell, its members removed. Pet spells are never grouped.
-- cats: categories(); index: category index; opts: see currentOptions
local function displayedList(cats, index, opts)
	opts = opts or currentOptions()
	local cat = cats[index]
	if not cat then return {} end
	local spells = spellsOf(cat, opts)
	if cat.pet or opts.flyouts then
		return spells
	end
	local groups = groupsOf(spells)
	local list, placed = {}, {}
	for _, spell in ipairs(spells) do
		local m = flyoutOf(spell.name)
		local g = m and groups[m.flyout]
		if not g then
			table.insert(list, spell)
		elseif not placed[m.flyout] then
			placed[m.flyout] = true
			local v = m.flyout
			local icon = v.icon and ("Interface" .. SEP .. "Icons" .. SEP .. v.icon) or g.members[1].icon
			table.insert(list, { flyout = v, name = v.name, rank = "", passive = false,
				icon = icon, members = g.members })
		end
	end
	return list
end
S.displayedList = displayedList
S.currentOptions = currentOptions

-- ------------------------------------------------------------ Layout
-- PagedCondensedVerticalGrid: the header takes a row (again at the top of each following
-- view), then spells fill the columns one by one over ceil(remaining / 3) rows in the space
-- left; a full view opens another, and the row count restarts from the remaining spells.
-- Several sections (search results): each keeps its own rows; a section starting on a used
-- view gets camelot's spacer (spacerSize 20 + yPadding 10), and moves to the next view if its
-- header and one row do not fit.
-- groups: list of { title, spells }. Returns the views, each a list of
-- { header or sort, column, y }.
local function paginateGroups(groups)
	local views = {}
	local view, busy
	local step = G.spellH + G.gapY
	local function newView(title)
		view = {}
		table.insert(views, view)
		busy = 0
		if title then
			table.insert(view, { header = title, column = 1, y = 0 })
			busy = G.headerH + G.gapY
		end
	end
	for _, g in ipairs(groups) do
		local title, spells = g.title, g.spells
		if not view then
			newView(title)
		elseif busy + G.space + G.gapY + G.headerH + G.gapY + step > G.viewH then
			newView(title)
		else
			busy = busy + G.space + G.gapY
			if title then
				table.insert(view, { header = title, column = 1, y = busy })
				busy = busy + G.headerH + G.gapY
			end
		end
		local i = 1
		while i <= #spells do
			local available = math.floor((G.viewH - busy) / step)
			if available < 1 then
				newView(title)
				available = math.floor((G.viewH - busy) / step)
			end
			local remaining = #spells - i + 1
			local rowLines = math.min(math.ceil(remaining / G.columns), available)
			for column = 1, G.columns do
				for r = 1, rowLines do
					if i <= #spells then
						table.insert(view, { spell = spells[i], column = column, y = busy + (r - 1) * step })
						i = i + 1
					end
				end
			end
			busy = busy + rowLines * step
			if i <= #spells then
				newView(title)
			end
		end
	end
	if not view then newView(nil) end
	return views
end
S.paginateGroups = paginateGroups

local function paginate(title, spells)
	return paginateGroups({ { title = title, spells = spells } })
end
S.paginate = paginate

-- --------------------------------------------------------------- Cells
local function atlas(t, name, keep)
	return ForeverUI.SetAtlas(t, name, keep)
end

-- Create spell cell n: a holder frame (background, texts) with the secure icon button
-- inside.
local function createCheckbox(view, n)
	local c = CreateFrame("Frame", nil, view)
	c:SetWidth(G.cellW)
	c:SetHeight(G.spellH)
	local background = c:CreateTexture(nil, "BACKGROUND")
	atlas(background, "spellbook-item-backplate")
	background:SetPoint("CENTER", c, "CENTER", 5, -5)
	background:SetAlpha(0.25)
	c.background = background

	local b = CreateFrame("Button", "ForeverUISpellBookButton" .. n, c, "SecureActionButtonTemplate")
	b:SetWidth(G.buttonSide)
	b:SetHeight(G.buttonSide)
	b:SetPoint("LEFT", c, "LEFT", 0, 0)
	b:RegisterForClicks("AnyUp")
	b:RegisterForDrag("LeftButton")
	-- cell index: the group snippet passes it to ForeverUIFlyout
	b:SetID(n)
	-- a modified click links the spell in chat instead of casting it
	b:SetAttribute("shift-type1", "link")
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(G.iconSide)
	icon:SetHeight(G.iconSide)
	icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	local shadow = b:CreateTexture(nil, "ARTWORK")
	atlas(shadow, "spellbook-item-iconframe-shadow", true)
	shadow:SetPoint("TOPLEFT", b, "TOPLEFT", -12, 3)
	shadow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -8)
	local frame = b:CreateTexture(nil, "OVERLAY")
	local hover = b:CreateTexture(nil, "OVERLAY")
	hover:SetAllPoints(b)
	hover:SetBlendMode("ADD")
	hover:SetAlpha(0.35)
	hover:Hide()
	local auto = b:CreateTexture(nil, "OVERLAY")
	atlas(auto, "spellbook-item-petautocast-corners", true)
	auto:SetAllPoints(icon)
	auto:Hide()
	local cooldown = CreateFrame("Cooldown", "ForeverUISpellBookButton" .. n .. "Cooldown", b, "CooldownFrameTemplate")
	cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
	cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
	-- flyout arrow (FlyoutButtonTemplate, Arrow)
	local arrow = b:CreateTexture(nil, "OVERLAY")
	arrow:Hide()
	b.icon, b.shadow, b.frame, b.hover, b.auto, b.cooldown = icon, shadow, frame, hover, auto, cooldown
	b.arrow = arrow

	local name = c:CreateFontString(nil, "ARTWORK")
	font(name, 16)
	name:SetJustifyH("LEFT")
	name:SetWidth(G.cellW - G.textX)
	local sub = c:CreateFontString(nil, "ARTWORK")
	font(sub, 12)
	sub:SetJustifyH("LEFT")
	sub:SetWidth(G.cellW - G.textX)
	c.name, c.sub = name, sub

	b:SetScript("OnEnter", function(self)
		c.background:SetAlpha(1)
		self.hover:Show()
		self.isHovered = true
		local spell = c.spell
		if spell and spell.flyout then
			-- group: its name and description (SpellFlyout.db2)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(spell.name, 1, 1, 1)
			if spell.flyout.text then GameTooltip:AddLine(spell.flyout.text, nil, nil, nil, 1) end
			GameTooltip:Show()
			S.placeArrow(self)
		elseif spell then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetSpell(spell.slot, spell.book)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.isHovered, self.pressed = nil, nil
		c.background:SetAlpha(0.25)
		self.hover:Hide()
		GameTooltip:Hide()
		if c.spell and c.spell.flyout then S.placeArrow(self) end
	end)
	b:SetScript("OnMouseDown", function(self)
		self.pressed = true
		self.hover:SetAlpha(0.65)
		if c.spell and c.spell.flyout then S.placeArrow(self) end
	end)
	b:SetScript("OnMouseUp", function(self)
		self.pressed = nil
		self.hover:SetAlpha(0.35)
		if c.spell and c.spell.flyout then S.placeArrow(self) end
	end)
	b:SetScript("OnDragStart", function(self)
		local spell = c.spell
		-- a group cannot go on an action bar: 3.3.5 has no flyouts there
		if spell and not spell.flyout then PickupSpell(spell.slot, spell.book) end
		self.pressed = nil
	end)
	-- SpellButton_OnModifiedClick: the spell link. A group opens through the secure snippet
	-- wrapped around OnClick (OPEN).
	b:SetScript("PostClick", function(self, mouse)
		local spell = c.spell
		if spell and not spell.flyout and IsModifiedClick("CHATLINK") then
			local link = GetSpellLink(spell.slot, spell.book)
			if link then ChatEdit_InsertLink(link) end
		end
	end)
	c.button = b
	c:Hide()
	return c
end

-- UpdateVisuals: square or round frame, texts, cooldown, autocast. Nothing protected:
-- called in combat by ForeverUIVisuals.
local function fillCell(c, spell)
	c.spell = spell
	local b = c.button
	if spell.passive then
		SetPortraitToTexture(b.icon, spell.icon)
		b.icon:SetTexCoord(0, 1, 0, 1)
		atlas(b.frame, "talents-node-circle-gray", true)
		b.frame:ClearAllPoints()
		b.frame:SetAllPoints(b)
		atlas(b.hover, "spellbook-item-iconframe-passive-hover", true)
		-- a passive has only its round icon, without an active spell's square shadow
		b.shadow:Hide()
	else
		b.shadow:Show()
		b.icon:SetTexture(spell.icon)
		b.icon:SetTexCoord(0, 1, 0, 1)
		atlas(b.frame, "spellbook-item-iconframe-c60", true)
		b.frame:ClearAllPoints()
		b.frame:SetPoint("TOPLEFT", b, "TOPLEFT", -11, 1)
		b.frame:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -7)
		atlas(b.hover, "spellbook-item-iconframe-hover", true)
	end
	c.name:SetText(spell.name)
	local subtitle = spell.rank
	if subtitle == "" and spell.passive then subtitle = TEXT.passive end
	c.sub:SetText(subtitle)
	-- text block centered on the cell at (50, -1)
	local nameH = c.name:GetHeight() or 0
	local subH = (subtitle ~= "" and (c.sub:GetHeight() or 0)) or 0
	local total = nameH + (subH > 0 and (2 + subH) or 0)
	c.name:ClearAllPoints()
	c.name:SetPoint("TOPLEFT", c, "LEFT", G.textX, total / 2 - 1)
	c.sub:ClearAllPoints()
	c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
	if subtitle == "" then c.sub:Hide() else c.sub:Show() end

	if spell.flyout then
		b.arrow:Show()
		S.placeArrow(b)
	else
		b.arrow:Hide()
	end
	S.updateState(c)
end

-- "Name(Rank N)": what SecureActionButton passes to CastSpellByName
function S.spellText(spell)
	local text = spell.name
	if spell.rank ~= "" and not spell.pet then text = text .. "(" .. spell.rank .. ")" end
	return text
end

-- cooldown and autocast, without touching the attributes
function S.updateState(c)
	local spell = c.spell
	if not spell then return end
	local b = c.button
	if spell.flyout then
		if CooldownFrame_SetTimer then CooldownFrame_SetTimer(b.cooldown, 0, 0, 0) end
		b.auto:Hide()
		return
	end
	local start, duration, active = GetSpellCooldown(spell.slot, spell.book)
	if CooldownFrame_SetTimer and start then
		CooldownFrame_SetTimer(b.cooldown, start, duration, active)
	end
	if spell.pet then
		local allowed, isLit = GetSpellAutocast(spell.slot, spell.book)
		if allowed and isLit then b.auto:Show() else b.auto:Hide() end
	else
		b.auto:Hide()
	end
end

-- ------------------------------------------------------------ Flyout menu
-- SetClampedTextureRotation at 90 or 270 on an atlas entry: the eight-argument SetTexCoord
-- (SetRotation would lose the atlas rectangle), width and height swapped.
local function rotateAtlas(t, name, degrees, width, height)
	local e = ForeverUI.AtlasEntry(name)
	if not e then return end
	t:SetTexture(e[1])
	local u1, u2, v1, v2 = e[2], e[3], e[4], e[5]
	if degrees == 90 then
		t:SetTexCoord(u1, v2, u2, v2, u1, v1, u2, v1)
	else
		t:SetTexCoord(u2, v1, u1, v1, u2, v2, u1, v2)
	end
	t:SetWidth(height)
	t:SetHeight(width)
end

-- FlyoutButtonMixin: normal, hover or pressed arrow; pointing right (90) when closed,
-- flipped (270) when open, 4 or 2 from the right edge
function S.placeArrow(b)
	local isOpen = S.openFlyout == b
	local name = "ui-hud-actionbar-flyout"
	if b.pressed then
		name = name .. "-down"
	elseif b.isHovered then
		name = name .. "-mouseover"
	end
	rotateAtlas(b.arrow, name, isOpen and 270 or 90, G.arrowW, G.arrowH)
	b.arrow:ClearAllPoints()
	b.arrow:SetPoint("RIGHT", b, "RIGHT", isOpen and G.arrowOpen or G.arrowClosed, 0)
end

-- SpellFlyoutPopupButtonTemplate: the small action button (30; frame and pushed 35,
-- centered; hover 31.6 x 30.9), secure to cast. n: button index
local function createSmallButton(flyout, n)
	local b = CreateFrame("Button", "ForeverUISpellFlyoutButton" .. n, flyout, "SecureActionButtonTemplate")
	b:SetWidth(G.smallSide)
	b:SetHeight(G.smallSide)
	b:RegisterForClicks("AnyUp")
	b:RegisterForDrag("LeftButton")
	b:SetAttribute("type1", "spell")
	b:SetAttribute("shift-type1", "link")
	-- its position never changes: the secure snippet only shows it
	b:SetPoint("LEFT", flyout, "LEFT", G.flyoutStart + (n - 1) * (G.smallSide + G.flyoutGap), 0)
	b:Hide()
	local icon = b:CreateTexture(nil, "BORDER")
	icon:SetAllPoints(b)
	b.icon = icon
	local function state(t, name, l, h, add)
		ForeverUI.SetAtlas(t, name, true)
		t:SetWidth(l)
		t:SetHeight(h)
		t:ClearAllPoints()
		t:SetPoint("CENTER", b, "CENTER", 0, 0)
		if add then t:SetBlendMode("ADD") end
	end
	local e = ForeverUI.AtlasEntry("ui-hud-actionbar-iconframe")
	b:SetNormalTexture(e and e[1] or "")
	state(b:GetNormalTexture(), "ui-hud-actionbar-iconframe", G.smallFrame, G.smallFrame)
	b:SetPushedTexture(e and e[1] or "")
	state(b:GetPushedTexture(), "ui-hud-actionbar-iconframe-down", G.smallFrame, G.smallFrame)
	b:SetHighlightTexture(e and e[1] or "")
	state(b:GetHighlightTexture(), "ui-hud-actionbar-iconframe-mouseover", G.smallStateW, G.smallStateH)
	-- CHECKED state: the hover art in ADD, shown while the spell is current
	local checkMark = b:CreateTexture(nil, "OVERLAY")
	state(checkMark, "ui-hud-actionbar-iconframe-mouseover", G.smallStateW, G.smallStateH, true)
	checkMark:Hide()
	b.checkMark = checkMark
	b.cooldown = CreateFrame("Cooldown", "ForeverUISpellFlyoutButton" .. n .. "Cooldown", b, "CooldownFrameTemplate")
	b.cooldown:SetAllPoints(icon)

	b:SetScript("OnEnter", function(self)
		if not self.spell then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 4)
		GameTooltip:SetSpell(self.spell.slot, self.spell.book)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnDragStart", function(self)
		if self.spell then PickupSpell(self.spell.slot, self.spell.book) end
	end)
	-- SpellFlyoutPopupButtonMixin:OnClick: the link here; the cast and closing the menu go
	-- through the secure snippet (SMALL_PRE, SMALL_POST)
	b:SetScript("PostClick", function(self)
		if self.spell and IsModifiedClick("CHATLINK") then
			local link = GetSpellLink(self.spell.slot, self.spell.book)
			if link then ChatEdit_InsertLink(link) end
		end
	end)
	return b
end

local function updateSmallButton(b)
	local spell = b.spell
	if not spell then return end
	local start, duration, active = GetSpellCooldown(spell.slot, spell.book)
	if CooldownFrame_SetTimer and start then
		CooldownFrame_SetTimer(b.cooldown, start, duration, active)
	end
	if IsCurrentSpell and IsCurrentSpell(spell.slot, spell.book) then b.checkMark:Show() else b.checkMark:Hide() end
end

-- FlyoutPopupTemplate, opened to the right: start cap (FlyoutBottom) on the left, middle
-- (FlyoutMidLeft), end cap (FlyoutButton) on the right; both caps rotated by 90
local function buildFlyout(book)
	local flyout = CreateFrame("Frame", "ForeverUISpellFlyout", book)
	flyout:SetFrameStrata("DIALOG")
	flyout:EnableMouse(true)
	flyout:SetHeight(G.flyoutH)
	flyout:Hide()
	local start = flyout:CreateTexture(nil, "BACKGROUND")
	rotateAtlas(start, "ui-hud-actionbar-iconframe-flyoutbottom", 90, 47, 5)
	start:SetHeight(G.flyoutH)
	start:SetPoint("LEFT", flyout, "LEFT", 0, 0)
	local finish = flyout:CreateTexture(nil, "BACKGROUND")
	rotateAtlas(finish, "ui-hud-actionbar-iconframe-flyoutbutton", 90, 47, 29)
	finish:SetHeight(G.flyoutH)
	finish:SetPoint("RIGHT", flyout, "RIGHT", 0, 0)
	local middle = flyout:CreateTexture(nil, "BACKGROUND")
	atlas(middle, "_ui-hud-actionbar-iconframe-flyoutmidleft", true)
	middle:SetHeight(G.flyoutH)
	middle:SetPoint("LEFT", start, "RIGHT", 0, 0)
	middle:SetPoint("RIGHT", finish, "LEFT", 0, 0)
	for _, t in ipairs({ start, middle, finish }) do
		t:SetVertexColor(G.flyoutTint, G.flyoutTint, G.flyoutTint)
	end
	flyout.buttons = {}
	-- hidden by anything (page, book, category): the arrow follows
	flyout:SetScript("OnHide", function()
		local b = S.openFlyout
		S.openFlyout = nil
		if b then S.placeArrow(b) end
	end)
	S.flyout = flyout
	return flyout
end

-- ForeverUIFlyout, called by a group's secure snippet (CallMethod): textures of the small
-- buttons and the arrow. Nothing protected. k: cell index; fk: group index in S.flyoutData
function S.flyoutOpenedBy(k, fk)
	local old = S.openFlyout
	local c = S.cells and S.cells[k]
	local members = S.flyoutData and S.flyoutData[fk]
	if not c or not members then return end
	S.openFlyout = c.button
	if old and old ~= c.button then S.placeArrow(old) end
	for i, p in ipairs(S.flyout.buttons) do
		p.spell = members[i]
		if p.spell then
			p.icon:SetTexture(p.spell.icon)
			updateSmallButton(p)
		end
	end
	S.placeArrow(c.button)
end

-- category header (SpellBookHeaderTemplate)
local function createHeader(view)
	local h = CreateFrame("Frame", nil, view)
	h:SetWidth(G.viewW)
	h:SetHeight(G.headerH)
	local background = h:CreateTexture(nil, "BACKGROUND")
	atlas(background, "spellbook-list-backplate", true)
	background:SetWidth(416)
	background:SetHeight(106)
	background:SetPoint("LEFT", h, "LEFT", -85, 10)
	background:SetAlpha(0.65)
	local text = h:CreateFontString(nil, "ARTWORK")
	font(text, 24)
	text:SetJustifyH("LEFT")
	text:SetPoint("TOPLEFT", h, "TOPLEFT", -8, 0)
	text:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -60, 0)
	local line = h:CreateTexture(nil, "ARTWORK")
	atlas(line, "spellbook-divider", true)
	line:SetHeight(11)
	line:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", -32, 0)
	line:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -60, 0)
	h.text = text
	h:Hide()
	return h
end

-- ------------------------------------------------------------ Frame
-- The close button is not a child of the book, so its level is set again on each show,
-- above the metal (+20) and the title (+21).
function S.raiseCloseButton()
	local close, book = SpellBookCloseButton, S.book
	if not close or not book then return end
	close:SetFrameStrata(book:GetFrameStrata())
	close:SetFrameLevel(book:GetFrameLevel() + 22)
end

-- Red title bar button. normal, pressed: atlas names; template: frame template
local function redButton(parent, normal, pressed, template)
	local b = CreateFrame("Button", nil, parent, template)
	b:SetWidth(G.redSide)
	b:SetHeight(G.redSide)
	local e = ForeverUI.AtlasEntry(normal)
	b:SetNormalTexture(e and e[1] or "")
	atlas(b:GetNormalTexture(), normal, true)
	b:SetPushedTexture(e and e[1] or "")
	atlas(b:GetPushedTexture(), pressed, true)
	b:SetHighlightTexture(e and e[1] or "")
	atlas(b:GetHighlightTexture(), "redbutton-highlight", true)
	b:GetHighlightTexture():SetBlendMode("ADD")
	return b
end

-- Window chrome of the book: rock, metal, portrait, title, close and resize buttons.
local function buildFrame(book)
	-- rock background and metal (PortraitFrameTemplate)
	local rock = book:CreateTexture(nil, "BACKGROUND")
	rock:SetTexture(ROCK, true)
	if rock.SetHorizTile then rock:SetHorizTile(true) rock:SetVertTile(true) end
	rock:SetPoint("TOPLEFT", book, "TOPLEFT", 2, -21)
	rock:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -2, 2)

	local metal = CreateFrame("Frame", nil, book)
	metal:SetAllPoints(book)
	metal:SetFrameLevel(book:GetFrameLevel() + 20)
	local p = {}
	for _, corner in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		atlas(t, corner.name)
		t:SetPoint(corner.point, metal, corner.point, corner.x, corner.y)
		p[corner.key] = t
	end
	local function edge(name, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		atlas(t, name)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	edge("_ui-frame-metal-edgetop", "TOPLEFT", p.topLeft, "TOPRIGHT", "TOPRIGHT", p.topRight, "TOPLEFT")
	edge("_ui-frame-metal-edgebottom", "BOTTOMLEFT", p.bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bottomRight, "BOTTOMLEFT")
	edge("!ui-frame-metal-edgeleft", "TOPLEFT", p.topLeft, "BOTTOMLEFT", "BOTTOMLEFT", p.bottomLeft, "TOPLEFT")
	edge("!ui-frame-metal-edgeright", "TOPRIGHT", p.topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bottomRight, "TOPRIGHT")

	-- round portrait (PortraitContainer, below the metal)
	local portraitFrame = CreateFrame("Frame", nil, book)
	portraitFrame:SetAllPoints(book)
	portraitFrame:SetFrameLevel(book:GetFrameLevel() + 19)
	local portrait = portraitFrame:CreateTexture(nil, "OVERLAY")
	portrait:SetWidth(G.portraitSide)
	portrait:SetHeight(G.portraitSide)
	portrait:SetPoint("TOPLEFT", book, "TOPLEFT", G.portraitX, G.portraitY)
	portrait:SetTexture(PORTRAIT)
	book.portrait = portrait

	-- title (TitleContainer, above the metal)
	local banner = CreateFrame("Frame", nil, book)
	banner:SetFrameLevel(book:GetFrameLevel() + 21)
	banner:SetHeight(G.titleH)
	banner:SetPoint("TOPLEFT", book, "TOPLEFT", G.titleX1, G.titleY)
	banner:SetPoint("TOPRIGHT", book, "TOPRIGHT", G.titleX2, G.titleY)
	local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", banner, "TOP", 0, -5)
	title:SetText(TEXT.title)
	book.title = title
	book.banner = banner

	-- close button: WotLK's, re-skinned. It stays a child of SpellBookFrame: its OnClick hides
	-- ITS PARENT (HideUIPanel), so closing never goes through our code.
	local close = SpellBookCloseButton
	if close then
		S.raiseCloseButton()
		close:SetWidth(G.redSide)
		close:SetHeight(G.redSide)
		close:SetHitRectInsets(0, 0, 0, 0)
		for _, state in ipairs({ { "Normal", "redbutton-exit" }, { "Pushed", "redbutton-exit-pressed" },
			{ "Highlight", "redbutton-highlight" } }) do
			local e = ForeverUI.AtlasEntry(state[2])
			local t = close["Get" .. state[1] .. "Texture"](close)
			if not t and e then
				close["Set" .. state[1] .. "Texture"](close, e[1])
				t = close["Get" .. state[1] .. "Texture"](close)
			end
			if t then
				atlas(t, state[2], true)
				t:ClearAllPoints()
				t:SetAllPoints(close)
			end
		end
		close:ClearAllPoints()
		close:SetPoint("TOPRIGHT", book, "TOPRIGHT", G.closeX, G.closeY)
	end

	-- maximize / minimize (MaximizeMinimizeButtonFrameTemplate), on the left. It tells the
	-- controller to switch mode (SecureHandlerClickTemplate), in combat too.
	local size = redButton(book, "redbutton-condense", "redbutton-condense-pressed", "SecureHandlerClickTemplate")
	size:SetFrameLevel(book:GetFrameLevel() + 22)
	if close then
		size:SetPoint("RIGHT", close, "LEFT", 0, 0)
	else
		size:SetPoint("TOPRIGHT", book, "TOPRIGHT", G.closeX - G.redSide, G.closeY)
	end
	size:SetAttribute("_onclick", [==[ self:GetFrameRef("ctrl"):SetAttribute("size", 1) ]==])
	size:HookScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn") end)
	book.size = size
end

local function build()
	if S.book or not SpellBookFrame then
		return S.book
	end
	-- WotLK's panel no longer catches the mouse: it is empty
	SpellBookFrame:EnableMouse(false)

	local book = CreateFrame("Frame", "ForeverUISpellBookFrame", SpellBookFrame)
	book:SetPoint("TOP", UIParent, "TOP", 0, G.top)
	book:SetHeight(G.height)
	book:SetWidth(G.width)
	book:EnableMouse(true)
	-- NO SetToplevel here: a book raising itself would cover the close button, its sibling.
	-- SpellBookFrame is toplevel and raises both.
	S.book = book
	buildFrame(book)

	-- open book: two pages, or one when reduced
	local pages = CreateFrame("Frame", "ForeverUISpellBookPages", book)
	pages:SetPoint("BOTTOMLEFT", book, "BOTTOMLEFT", 0, G.bookBottom)
	pages:SetHeight(G.bookH)
	pages:SetWidth(G.bookW)
	local left = pages:CreateTexture(nil, "BACKGROUND")
	atlas(left, "spellbook-page-left-c60-2x", true)
	left:SetPoint("TOPLEFT", pages, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", pages, "BOTTOM", 0, 0)
	local right = pages:CreateTexture(nil, "BACKGROUND")
	atlas(right, "spellbook-page-right-c60-2x", true)
	right:SetPoint("TOPLEFT", pages, "TOP", 0, 0)
	right:SetPoint("BOTTOMRIGHT", pages, "BOTTOMRIGHT", 0, 0)
	local singlePage = pages:CreateTexture(nil, "BACKGROUND")
	atlas(singlePage, "spellbook-page-right-c60-2x", true)
	singlePage:SetAllPoints(pages)
	singlePage:Hide()
	pages.left, pages.right, pages.singlePage = left, right, singlePage
	S.pages = pages

	-- category tabs
	local tabs = CreateFrame("Frame", nil, pages)
	tabs:SetPoint("TOPLEFT", pages, "TOPLEFT", G.tabsX, G.tabsY)
	tabs:SetWidth(1)
	tabs:SetHeight(G.tabH)
	tabs.buttons = {}
	S.tabs = tabs

	-- the two views; the content turns pages with the mouse wheel through a secure snippet
	-- (SecureHandlerMouseWheelTemplate)
	local content = CreateFrame("Frame", "ForeverUISpellBookContent", pages, "SecureHandlerMouseWheelTemplate")
	content:SetPoint("TOPLEFT", pages, "TOPLEFT", 0, G.pagesTop)
	content:SetPoint("BOTTOMRIGHT", pages, "BOTTOMRIGHT", 0, 0)
	S.content = content
	S.views = {}
	S.cells = {}
	for v = 1, 2 do
		local view = CreateFrame("Frame", "ForeverUISpellBookView" .. v, content)
		view:SetWidth(G.viewW)
		view:SetHeight(G.viewH)
		if v == 1 then
			view:SetPoint("TOPLEFT", content, "TOPLEFT", G.view1X, G.viewY)
		else
			view:SetPoint("TOPRIGHT", content, "TOPRIGHT", G.view2X, G.viewY)
		end
		view.cells = {}
		for n = 1, G.cellsPerView do
			local k = (v - 1) * G.cellsPerView + n
			view.cells[n] = createCheckbox(view, k)
			S.cells[k] = view.cells[n]
		end
		view.headers = { createHeader(view) }
		view.header = view.headers[1]
		S.views[v] = view
	end

	-- paging: "Page n/m", previous, next (right to left); a click tells the controller to
	-- turn (SecureHandlerClickTemplate)
	local nextPage = CreateFrame("Button", "ForeverUISpellBookNextPage", content, "SecureHandlerClickTemplate")
	local prev = CreateFrame("Button", "ForeverUISpellBookPrevPage", content, "SecureHandlerClickTemplate")
	for _, f in ipairs({ { nextPage, "NextPage", 1 }, { prev, "PrevPage", -1 } }) do
		local b = f[1]
		b:SetWidth(G.arrowSide)
		b:SetHeight(G.arrowSide)
		b:SetNormalTexture(ARROWS .. f[2] .. "-Up")
		b:SetPushedTexture(ARROWS .. f[2] .. "-Down")
		b:SetDisabledTexture(ARROWS .. f[2] .. "-Disabled")
		b:SetHighlightTexture(SQUARE_HOVER)
		b:GetHighlightTexture():SetBlendMode("ADD")
		b:SetAttribute("_onclick", ([[ self:GetFrameRef("ctrl"):SetAttribute("rotate", %d) ]]):format(f[3]))
		b:HookScript("OnClick", function() PlaySound("igAbiliityPageTurn") end)
	end
	nextPage:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", G.pagerX, G.pagerY)
	prev:SetPoint("RIGHT", nextPage, "LEFT", -G.pagerGap, 0)
	local text = content:CreateFontString(nil, "ARTWORK")
	font(text, 14)
	text:SetPoint("RIGHT", prev, "LEFT", -G.pagerGap, 0)
	S.pager = { nextPage = nextPage, prev = prev, text = text }
	content:EnableMouseWheel(true)
	content:SetAttribute("_onmousewheel", [[ self:GetFrameRef("ctrl"):SetAttribute("rotate", -delta) ]])

	-- settings (SpellBookSettingsDropdown): TOPRIGHT (-30, -27) of the book
	S.createSettings(pages)
	buildFlyout(book)
	S.createController(book)

	S.suppressWotLK()
	S.applySize()
	return book
end
S.build = build

-- ------------------------------------------------------------ Settings
-- UIPanelArrowDropdownButtonTemplate: 15 x 16, arrow common-dropdown-a-button at atlas
-- size, centered; on hover the same in ADD at 0.4; pressed, the icon moves by (1, -1). The
-- menu opens TOPLEFT on BOTTOMLEFT (DropdownButton). Entries (camelot's
-- SetupSettingsDropdown): hide passives; group on flyouts (kept in ForeverUIDB, 3.3.5 has no
-- spellBookHideFlyouts; on by default); all ranks, for every class (camelot hides it for
-- rogues and warriors). A click toggles and keeps the menu open.
function S.createSettings(pages)
	local b = CreateFrame("Button", "ForeverUISpellBookSettingsButton", pages, "SecureHandlerClickTemplate")
	b:SetWidth(G.settingsW)
	b:SetHeight(G.settingsH)
	b:SetPoint("TOPRIGHT", pages, "TOPRIGHT", G.settingsX, G.settingsY)
	local icon = b:CreateTexture(nil, "ARTWORK")
	atlas(icon, "common-dropdown-a-button")
	icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	local hover = b:CreateTexture(nil, "HIGHLIGHT")
	atlas(hover, "common-dropdown-a-button")
	hover:SetPoint("CENTER", icon, "CENTER", 0, 0)
	hover:SetBlendMode("ADD")
	hover:SetAlpha(0.4)
	b.icon = icon
	b:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", b, "CENTER", 1, -1) end)
	b:SetScript("OnMouseUp", function() icon:SetPoint("CENTER", b, "CENTER", 0, 0) end)

	-- dropdown list
	local list = CreateFrame("Frame", "ForeverUISpellBookSettingsList", pages)
	list:SetFrameStrata("DIALOG")
	list:EnableMouse(true)
	list:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, 0)
	list:Hide()
	local slices = ForeverUI.CreateNineSlice(list, "common-dropdown-bg-c60", MENU.backgroundCorner, MENU.backgroundMargins, "BACKGROUND")
	for _, t in ipairs(slices or {}) do t:SetAlpha(MENU.backgroundAlpha) end
	list.rows = {}
	local longest = 0
	for i, r in ipairs(SETTINGS) do
		local l = CreateFrame("Button", "ForeverUISpellBookSettingsEntry" .. i, list, "SecureHandlerClickTemplate")
		l:SetID(r.bit)
		l:SetHeight(MENU.rowH)
		l:SetPoint("TOPLEFT", list, "TOPLEFT", MENU.rowX, -MENU.edge - (i - 1) * MENU.rowH)
		l:SetHighlightTexture("Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight")
		l:GetHighlightTexture():SetBlendMode("ADD")
		local text = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
		text:SetPoint("LEFT", l, "LEFT", MENU.textX, 0)
		text:SetText(r.text)
		longest = math.max(longest, text:GetStringWidth() or 0)
		local checkbox = l:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(checkbox, "common-dropdown-ticksquare", true)
		checkbox:SetWidth(MENU.checkbox)
		checkbox:SetHeight(MENU.checkbox)
		checkbox:SetPoint("LEFT", l, "LEFT", 0, 0)
		local checkMark = l:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(checkMark, "common-dropdown-icon-checkmark-yellow", true)
		checkMark:SetWidth(MENU.checkMarkW)
		checkMark:SetHeight(MENU.checkMarkH)
		checkMark:SetPoint("CENTER", checkbox, "CENTER", MENU.checkMarkX, MENU.checkMarkY)
		checkMark:Hide()
		l.text, l.checkMark, l.setting = text, checkMark, r
		-- UIDropDownMenuButton_OnClick, keepShownOnClick: the list stays open; the setting goes
		-- through the controller, in combat too
		l:SetAttribute("_onclick", [==[ self:GetFrameRef("ctrl"):SetAttribute("setting", self:GetID()) ]==])
		l:HookScript("OnClick", function() PlaySound("UChatScrollButton") end)
		-- SetupHidePassivesCheckbox: disabled during a search, with a tooltip (the other two have
		-- none)
		if r.bit == 1 then
			l:SetScript("OnEnter", function(self)
				if not S.settingsGrayed then return end
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(TEXT.passivesDisabled, 1, 1, 1, 1, 1)
				GameTooltip:Show()
			end)
			l:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end
		list.rows[i] = l
	end
	local width = longest + MENU.extraWidth + MENU.margin
	list:SetWidth(width)
	list:SetHeight(#SETTINGS * MENU.rowH + 2 * MENU.edge)
	for _, l in ipairs(list.rows) do l:SetWidth(width - MENU.margin) end

	-- the arrow opens or closes the list, in combat too; the list hides itself 2 s after the
	-- mouse leaves it
	b:SetFrameRef("list", list)
	b:SetAttribute("_onclick", ([==[
		local l = self:GetFrameRef("list")
		if l:IsShown() then
			l:Hide()
		else
			l:Show()
			l:RegisterAutoHide(%d)
			l:AddToAutoHide(self)
		end
	]==]):format(MENU.pending))
	S.settings, S.settingsList = b, list
	return b
end

-- In combat too: grayed during a search (the secure snippet disables the rows; this sets
-- the text color). grayed: true during a search
function S.graySettings(grayed)
	if not S.settingsList then return end
	S.settingsGrayed = grayed
	for _, l in ipairs(S.settingsList.rows) do
		-- "Show all spell ranks" stays enabled during a search (camelot disables it)
		if grayed and l.setting.bit ~= 4 then
			l.text:SetTextColor(0.5, 0.5, 0.5)
		else
			l.text:SetTextColor(1, 1, 1)
		end
	end
end

-- In combat too: check marks follow the settings combination (textures only). reg: settings
-- bits
function S.checkSettings(reg)
	if not S.settingsList then return end
	for _, l in ipairs(S.settingsList.rows) do
		local active = math.floor(reg / l.setting.bit) % 2 == 1
		if l.setting.inverse then active = not active end
		if active then l.checkMark:Show() else l.checkMark:Hide() end
	end
end

-- Hide WotLK's regions and frames in SpellBookFrame, except the book and the close button.
function S.suppressWotLK()
	for _, region in ipairs({ SpellBookFrame:GetRegions() }) do
		suppress(region)
	end
	for _, child in ipairs({ SpellBookFrame:GetChildren() }) do
		if child ~= S.book and child ~= SpellBookCloseButton then
			suppress(child)
		end
	end
end

-- Two pages or one: page and button textures. Widths and the right view are set by the
-- secure "place" snippet; this follows, in combat too. reduced: one page; nil reads the
-- saved setting
function S.applySize(reduced)
	local book, pages = S.book, S.pages
	if not book then return end
	if reduced == nil then reduced = settings().reduced end
	if S.onResize then S.onResize(reduced) end
	if reduced then
		pages.left:Hide() pages.right:Hide() pages.singlePage:Show()
		atlas(book.size:GetNormalTexture(), "redbutton-expand", true)
		atlas(book.size:GetPushedTexture(), "redbutton-expand-pressed", true)
	else
		pages.left:Show() pages.right:Show() pages.singlePage:Hide()
		atlas(book.size:GetNormalTexture(), "redbutton-condense", true)
		atlas(book.size:GetPushedTexture(), "redbutton-condense-pressed", true)
	end
end

-- ------------------------------------------------------------ Tabs
-- A tab tells the controller "category n" (SecureHandlerClickTemplate); tabs are created
-- out of combat only.
local function createTab(parent, n)
	local b = CreateFrame("Button", "ForeverUISpellBookTab" .. n, parent, "SecureHandlerClickTemplate")
	b:SetID(n)
	b:SetFrameRef("ctrl", S.ctrl)
	b:SetAttribute("_onclick", [[ self:GetFrameRef("ctrl"):SetAttribute("category", self:GetID()) ]])
	S.ctrl:SetFrameRef("o" .. n, b)
	S.ctrl:Execute(("TABS[%d] = self:GetFrameRef(\"o%d\")"):format(n, n))
	b:SetWidth(G.tabW)
	b:SetHeight(G.tabH)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(G.tabIconW)
	icon:SetHeight(G.tabIconH)
	icon:SetPoint("CENTER", b, "CENTER", -1, -1)
	-- frame ABOVE the icon (camelot: ARTWORK sublevel 1): a child frame
	local hovered = CreateFrame("Frame", nil, b)
	hovered:SetAllPoints(b)
	hovered:SetFrameLevel(b:GetFrameLevel() + 1)
	local frame = hovered:CreateTexture(nil, "ARTWORK")
	atlas(frame, "spellbook-tab-frame-c60")
	frame:SetPoint("BOTTOM", b, "BOTTOM", 0, 1)
	local active = hovered:CreateTexture(nil, "ARTWORK")
	atlas(active, "spellbook-tab-frame-glow-c60")
	active:SetPoint("BOTTOM", b, "BOTTOM", 0, 1)
	local glow = hovered:CreateTexture(nil, "OVERLAY")
	atlas(glow, "spellbook-tab-frame-glow-gradient-c60")
	glow:SetPoint("BOTTOM", b, "BOTTOM", 0, 0)
	b.icon, b.frame, b.active, b.glow = icon, frame, active, glow
	b:HookScript("OnClick", function() PlaySound("igSpellBookOpen") end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -12, -6)
		GameTooltip:SetText(self.name)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

-- out of combat: one tab per category, in place
local function layoutTabs(cats)
	local tabs = S.tabs
	for i, cat in ipairs(cats) do
		local b = tabs.buttons[i]
		if not b then
			b = createTab(tabs, i)
			tabs.buttons[i] = b
		end
		b.index, b.name = i, cat.name
		b.icon:SetTexture(cat.icon)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", tabs, "TOPLEFT", (i - 1) * (G.tabW + G.tabGap), 0)
		b:Show()
	end
	for i = #cats + 1, #tabs.buttons do
		tabs.buttons[i]:Hide()
	end
end

-- in combat too: the selected tab lights up (textures only; enabling is done by the secure
-- snippet)
local function highlightTabs(selectedItem)
	for i, b in ipairs(S.tabs.buttons) do
		-- 3.3.5 has no SetShown
		if i == selectedItem then
			b.frame:Hide() b.active:Show() b.glow:Show()
		else
			b.frame:Show() b.active:Hide() b.glow:Hide()
		end
	end
end

-- ------------------------------------------------------------ Filling
S.state = { category = 1, page = 1 }

-- Requests to the controller, out of combat only (tabs, arrows and wheel are secure and work
-- in combat).
function S.choose(index)
	if InCombatLockdown() or not S.ctrl then return end
	S.ctrl:SetAttribute("category", index)
end

function S.rotate(direction)
	if InCombatLockdown() or not S.ctrl then return end
	S.ctrl:SetAttribute("rotate", direction)
end

-- The controller. Its restricted environment holds the published data (D: cells of each
-- page, NUM_PAGES: pages of each category, V: spells of each group), the state (SETTINGS,
-- MODE, CAT, PAGE, OPEN_OWNER) and frame handles. Restricted code (RestrictedExecution.lua,
-- RestrictedFrames.lua) allows no braces and no "function" keyword, hence newtable;
-- SetPoint only targets an explicitly protected frame or "$parent".
local DISPLAY = [==[
	local list = D[SETTINGS .. ":" .. MODE .. ":" .. CAT .. ":" .. PAGE]
	FLYOUT:Hide()
	OPEN_OWNER = nil
	for k = 1, NUM_CELLS do
		CELLS[k]:Hide()
		BUTTONS[k]:SetAttribute("flyout", nil)
	end
	if list then
		for i = 1, #list do
			local e = list[i]
			local c = CELLS[e[1]]
			local b = BUTTONS[e[1]]
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", "$parent", "TOPLEFT", e[2], e[3])
			if e[4] == "" then b:SetAttribute("type1", nil) else b:SetAttribute("type1", e[4]) end
			if e[5] == "" then b:SetAttribute("spell", nil) else b:SetAttribute("spell", e[5]) end
			if e[6] == "" then
				b:SetAttribute("type2", nil)
				b:SetAttribute("macrotext2", nil)
			else
				b:SetAttribute("type2", e[6])
				b:SetAttribute("macrotext2", e[7])
			end
			if e[8] > 0 then b:SetAttribute("flyout", e[8]) end
			c:Show()
		end
	end
	for i = 1, NUM_TABS do
		if i == CAT then TABS[i]:Disable() else TABS[i]:Enable() end
	end
	for i = 1, NUM_ENTRIES do
		if CAT == 0 and ENTRIES[i]:GetID() ~= 4 then ENTRIES[i]:Disable() else ENTRIES[i]:Enable() end
	end
	if PAGE > 1 then PREV:Enable() else PREV:Disable() end
	if PAGE < NUM_PAGES[SETTINGS .. ":" .. MODE .. ":" .. CAT] then NEXT:Enable() else NEXT:Disable() end
	control:CallMethod("ForeverUIVisuals", CAT, PAGE, MODE, SETTINGS)
]==]

local ON_ATTRIBUTE_CHANGED = [==[
	if name == "category" and value then
		self:SetAttribute("category", nil)
		if (value >= 1 and value <= NUM_TABS) or (value == 0 and NUM_PAGES[SETTINGS .. ":" .. MODE .. ":0"]) then
			CAT = value
			PAGE = 1
			control:RunAttribute("show")
		end
	elseif name == "rotate" and value then
		self:SetAttribute("rotate", nil)
		local p = PAGE + value
		if p >= 1 and p <= NUM_PAGES[SETTINGS .. ":" .. MODE .. ":" .. CAT] then
			PAGE = p
			control:RunAttribute("show")
		end
	elseif name == "size" and value then
		self:SetAttribute("size", nil)
		if MODE == 2 then
			MODE = 1
			PAGE = PAGE * 2 - 1
		else
			MODE = 2
			PAGE = ceil(PAGE / 2)
		end
		if PAGE > NUM_PAGES[SETTINGS .. ":" .. MODE .. ":" .. CAT] then PAGE = NUM_PAGES[SETTINGS .. ":" .. MODE .. ":" .. CAT] end
		control:RunAttribute("place")
		control:RunAttribute("show")
	elseif name == "clear" and value then
		self:SetAttribute("clear", nil)
		if CAT == 0 then
			CAT = 1
			PAGE = 1
			control:RunAttribute("show")
		end
	elseif name == "setting" and value then
		self:SetAttribute("setting", nil)
		if floor(SETTINGS / value) % 2 == 1 then SETTINGS = SETTINGS - value else SETTINGS = SETTINGS + value end
		if PAGE > NUM_PAGES[SETTINGS .. ":" .. MODE .. ":" .. CAT] then PAGE = NUM_PAGES[SETTINGS .. ":" .. MODE .. ":" .. CAT] end
		control:RunAttribute("show")
	end
]==]

-- MaximizeMinimizeButtonFrameTemplate: 1618 / 809 wide, two pages or one (right view
-- hidden). %d: widths from G.
local LAYOUT = [==[
	if MODE == 1 then
		SPELL_BOOK:SetWidth(%d)
		PAGES:SetWidth(%d)
		VIEW2:Hide()
	else
		SPELL_BOOK:SetWidth(%d)
		PAGES:SetWidth(%d)
		VIEW2:Show()
	end
]==]

-- SpellFlyoutMixin:Toggle, wrapped around each cell's OnClick: the same group closes the
-- menu, another moves it. A modifier does not open it (link). %d: base width, width per
-- button and x offset, from G.
local OPEN = [==[
	local v = self:GetAttribute("flyout")
	if v and not IsModifierKeyDown() then
		if OPEN_OWNER == self and FLYOUT:IsShown() then
			FLYOUT:Hide()
			OPEN_OWNER = nil
		else
			local list = V[v]
			local n = #list
			for i = 1, NUM_SMALL do
				if i <= n then
					SMALL[i]:SetAttribute("spell", list[i])
					SMALL[i]:Show()
				else
					SMALL[i]:Hide()
				end
			end
			FLYOUT:SetWidth(%d + n * %d)
			FLYOUT:ClearAllPoints()
			FLYOUT:SetPoint("LEFT", self, "RIGHT", %d, 0)
			FLYOUT:Show()
			OPEN_OWNER = self
			control:CallMethod("ForeverUIFlyout", self:GetID(), v)
		end
	end
]==]

-- a small button: the spell is cast, then the menu closes (except for a link)
local SMALL_PRE = [==[ if not IsModifiedClick("CHATLINK") then return nil, "close" end ]==]
local SMALL_POST = [==[ FLYOUT:Hide() OPEN_OWNER = nil ]==]
-- the book hides: the menu too (FlyoutButtonMixin:OnHide)
local ON_HIDE = [==[ FLYOUT:Hide() OPEN_OWNER = nil ]==]

-- Create the secure controller and give it the handles of the cells, buttons, flyout, pages,
-- page arrows and settings rows.
function S.createController(book)
	local ctrl = CreateFrame("Frame", "ForeverUISpellBookControl", book, "SecureHandlerAttributeTemplate")
	S.ctrl = ctrl
	for k, c in ipairs(S.cells) do
		ctrl:SetFrameRef("c" .. k, c)
		ctrl:SetFrameRef("b" .. k, c.button)
		ctrl:WrapScript(c.button, "OnClick", OPEN:format(G.flyoutStart + G.flyoutEnd - G.flyoutGap,
			G.smallSide + G.flyoutGap, G.flyoutOffset))
	end
	ctrl:SetFrameRef("flyout", S.flyout)
	ctrl:SetFrameRef("book", book)
	ctrl:SetFrameRef("pages", S.pages)
	ctrl:SetFrameRef("view2", S.views[2])
	book.size:SetFrameRef("ctrl", ctrl)
	for i, l in ipairs(S.settingsList.rows) do
		l:SetFrameRef("ctrl", ctrl)
		ctrl:SetFrameRef("e" .. i, l)
	end
	ctrl:SetFrameRef("prevPage", S.pager.prev)
	ctrl:SetFrameRef("nextPage", S.pager.nextPage)
	for _, b in ipairs({ S.pager.prev, S.pager.nextPage, S.content }) do
		b:SetFrameRef("ctrl", ctrl)
	end
	ctrl:Execute(([==[
		NUM_CELLS = %d
		CELLS = newtable()
		BUTTONS = newtable()
		for k = 1, NUM_CELLS do
			CELLS[k] = self:GetFrameRef("c" .. k)
			BUTTONS[k] = self:GetFrameRef("b" .. k)
		end
		FLYOUT = self:GetFrameRef("flyout")
		SPELL_BOOK = self:GetFrameRef("book")
		PAGES = self:GetFrameRef("pages")
		VIEW2 = self:GetFrameRef("view2")
		MODE = 2
		SETTINGS = 0
		PREV = self:GetFrameRef("prevPage")
		NEXT = self:GetFrameRef("nextPage")
		TABS = newtable()
		SMALL = newtable()
		ENTRIES = newtable()
		NUM_ENTRIES = %d
		for i = 1, NUM_ENTRIES do ENTRIES[i] = self:GetFrameRef("e" .. i) end
		NUM_SMALL = 0
		D = newtable()
		NUM_PAGES = newtable()
		V = newtable()
		NUM_TABS = 0
		CAT = 1
		PAGE = 1
	]==]):format(#S.cells, #S.settingsList.rows))
	ctrl:SetAttribute("show", DISPLAY)
	ctrl:SetAttribute("place", LAYOUT:format(G.compactWidth, G.reducedBookW, G.width, G.bookW))
	ctrl:SetAttribute("_onattributechanged", ON_ATTRIBUTE_CHANGED)
	ctrl:WrapScript(S.content, "OnHide", ON_HIDE)
	-- called by CallMethod: ordinary code, allowed in combat
	ctrl.ForeverUIVisuals = function(_, cat, page, mode, reg) S.updateVisuals(cat, page, mode, reg) end
	ctrl.ForeverUIFlyout = function(_, k, fk) S.flyoutOpenedBy(k, fk) end
	return ctrl
end

-- Small flyout buttons: as many as the largest group, created out of combat, each known to
-- the controller. n: number needed
local function ensureSmallButtons(n)
	local flyout, ctrl = S.flyout, S.ctrl
	for i = #flyout.buttons + 1, n do
		local p = createSmallButton(flyout, i)
		flyout.buttons[i] = p
		ctrl:SetFrameRef("p" .. i, p)
		ctrl:WrapScript(p, "OnClick", SMALL_PRE, SMALL_POST)
		ctrl:Execute(("SMALL[%d] = self:GetFrameRef(\"p%d\") NUM_SMALL = %d"):format(i, i, i))
	end
end

-- quoted string for a secure snippet
local function q(text)
	return string.format("%q", text or "")
end

-- Out of combat: lay out each category, publish it to the controller, then show the current
-- state.
function S.update()
	local book = S.book
	if not book then return end
	if InCombatLockdown() then
		S.queued = true
		return
	end
	S.queued, S.dirty = nil, nil
	local cats = categories()
	local e = S.state
	if e.category > #cats then e.category = 1 end
	-- Search (SpellBookSearch.lua): its results form one more category, 0, without a tab. With
	-- no result the search ends (DisplayFullSearchResults -> ClearActiveSearchState).
	local search = ForeverUI.SpellBookSearch
	if search then search.invalidate() end
	local searchGroups = {}
	if search and search.active() then
		-- one variant per settings set: search follows Hide Passives and Show all spell ranks, and
		-- never groups (camelot shows passives and all ranks there, and groups)
		local empty = true
		for r = 0, 7 do
			local g = search.groups(cats, { passives = r % 2 == 1, flyouts = true,
				ranks = math.floor(r / 4) % 2 == 1 })
			searchGroups[r] = g
			if #g > 0 then empty = false end
		end
		if empty then
			search.quit()
			searchGroups = {}
		end
	end
	if e.category == 0 and not searchGroups[0] then e.category = 1 end
	layoutTabs(cats)
	local mode = settings().reduced and 1 or 2
	local current = currentOptions()
	local reg = (current.passives and 1 or 0) + (current.flyouts and 2 or 0) + (current.ranks and 4 or 0)

	-- Everything is published: the eight settings sets (reg, three bits), each in one page (1)
	-- or two (2), so settings and resize work in combat. In a set, the views are the same for
	-- both modes; only their grouping into pages changes.
	S.pageData, S.np, S.flyoutData = {}, {}, {}
	local code = { "wipe(D) wipe(NUM_PAGES) wipe(V)" }
	local largest = 0
	for r = 0, 7 do
		local opts = { passives = r % 2 == 1, flyouts = math.floor(r / 2) % 2 == 1, ranks = math.floor(r / 4) % 2 == 1 }
		S.pageData[r], S.np[r] = { {}, {} }, { {}, {} }
		-- category 0: search results for this settings set
		local g = searchGroups[r]
	for ci = (g and 0 or 1), #cats do
		local cat = cats[ci]
		local views
		if ci == 0 then
			views = paginateGroups(g)
		else
			views = paginate(cat.name, displayedList(cats, ci, opts))
		end
		for perPage = 1, 2 do
			local nPages = math.max(1, math.ceil(#views / perPage))
			S.np[r][perPage][ci] = nPages
			S.pageData[r][perPage][ci] = {}
			table.insert(code, ('NUM_PAGES["%d:%d:%d"] = %d'):format(r, perPage, ci, nPages))
			for page = 1, nPages do
				local data = { headers = {}, cells = {} }
				S.pageData[r][perPage][ci][page] = data
				local entries = {}
				for slot = 1, perPage do
					local n = 0
					for _, el in ipairs(views[(page - 1) * perPage + slot] or {}) do
						if el.header then
							data.headers[slot] = data.headers[slot] or {}
							table.insert(data.headers[slot], el)
						else
							n = n + 1
							local k = (slot - 1) * G.cellsPerView + n
							local spell = el.spell
							data.cells[k] = spell
							-- a group is published once, for both modes
							if spell.flyout and not spell.fk then
								table.insert(S.flyoutData, spell.members)
								spell.fk = #S.flyoutData
								local texts = {}
								for _, m in ipairs(spell.members) do table.insert(texts, q(S.spellText(m))) end
								table.insert(code, ("V[%d] = newtable(%s)"):format(spell.fk, table.concat(texts, ", ")))
								largest = math.max(largest, #spell.members)
							end
							local castable = not (spell.passive or spell.flyout)
							table.insert(entries, ("newtable(%d, %.14g, %d, %s, %s, %s, %s, %d)"):format(k,
								(el.column - 1) * (G.cellW + G.gapX), -el.y,
								q(castable and "spell" or ""), q(castable and S.spellText(spell) or ""),
								q(spell.pet and "macro" or ""), q(spell.pet and ("/petautocasttoggle " .. spell.name) or ""),
								spell.fk or 0))
						end
					end
				end
				table.insert(code, ('D["%d:%d:%d:%d"] = newtable(%s)'):format(r, perPage, ci, page, table.concat(entries, ", ")))
			end
		end
	end
	end
	ensureSmallButtons(largest)
	if e.page > S.np[reg][mode][e.category] then e.page = S.np[reg][mode][e.category] end
	-- Run "place" on EACH computation: the layout follows the setting even when it arrives
	-- later (saved variables load after the file, so after the book is built).
	table.insert(code, ("NUM_TABS = %d CAT = %d PAGE = %d MODE = %d SETTINGS = %d control:RunAttribute(\"place\") control:RunAttribute(\"show\")")
		:format(#cats, e.category, e.page, mode, reg))
	S.ctrl:Execute(table.concat(code, "\n"))
end

-- ForeverUIVisuals: textures and texts for what the secure snippet just placed. Nothing
-- protected: this keeps the book readable in combat.
-- cat: category (0 = search); mode: 1 or 2 pages; reg: settings bits
function S.updateVisuals(cat, page, mode, reg)
	local e = S.state
	e.category, e.page = cat, page
	mode, reg = mode or 2, reg or 0
	-- the chosen mode and settings are saved, even when changed in combat (SetCVar is not
	-- protected)
	settings().reduced = (mode == 1) or nil
	settings().hidePassives = (reg % 2 == 1) or nil
	settings().noFlyouts = (math.floor(reg / 2) % 2 == 1) or nil
	local ranks = math.floor(reg / 4) % 2 == 1
	if ranks ~= (GetCVar("ShowAllSpellRanks") == "1") then
		SetCVar("ShowAllSpellRanks", ranks and "1" or "0")
	end
	S.reg = reg
	S.checkSettings(reg)
	S.applySize(mode == 1)
	e.pages = S.np and S.np[reg][mode][cat] or 1
	highlightTabs(cat)
	local data = S.pageData and S.pageData[reg][mode][cat] and S.pageData[reg][mode][cat][page]
	-- headers: one per section of the view (plain frames, created as needed, allowed in
	-- combat)
	for slot, view in ipairs(S.views) do
		local list = data and data.headers[slot] or {}
		for i, el in ipairs(list) do
			local h = view.headers[i]
			if not h then
				h = createHeader(view)
				view.headers[i] = h
			end
			h.text:SetText(el.header)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -el.y)
			h:Show()
		end
		for i = #list + 1, #view.headers do view.headers[i]:Hide() end
	end
	-- settings are grayed during a search (camelot disables them)
	S.graySettings(cat == 0)
	if S.onVisuals then S.onVisuals(cat) end
	for k, c in ipairs(S.cells) do
		local spell = data and data.cells[k]
		c.spell = spell
		if spell then fillCell(c, spell) end
	end
	S.pager.text:SetText(string.format(TEXT.page, e.page, e.pages))
end

-- state of the shown cells: cooldowns, autocast
function S.updateStates()
	if not S.views then return end
	if S.flyout and S.flyout:IsShown() then
		for _, p in ipairs(S.flyout.buttons) do
			if p:IsShown() then updateSmallButton(p) end
		end
	end
	for _, view in ipairs(S.views) do
		for _, c in ipairs(view.cells) do
			if c:IsShown() and c.spell then S.updateState(c) end
		end
	end
end

-- ------------------------------------------------------------ Assembly
build()

if S.book then
	-- movable by its title; in front when shown or clicked
	ForeverUI.WindowStack.makeMovable(S.book, S.book.banner, "spellbook")
	ForeverUI.WindowStack.register("spellbook", SpellBookFrame, function()
		return { S.book, _G.ForeverUISpellFlyout, _G.ForeverUISpellBookSettingsList,
			_G.ForeverUISpellBookSearchPreview }
	end)
	-- on each show: the requested book (spells or pet) and its content
	SpellBookFrame:HookScript("OnShow", function()
		S.suppressWotLK()
		S.raiseCloseButton()
		-- in combat the book opens as last published
		if InCombatLockdown() then return end
		if SpellBookFrame.bookType == BOOKTYPE_PET then
			local cats = categories()
			for i, cat in ipairs(cats) do
				if cat.pet then S.state.category = i S.state.page = 1 end
			end
		elseif S.state.category and categories()[S.state.category] and categories()[S.state.category].pet then
			S.state.category = 1
			S.state.page = 1
		end
		S.update()
	end)
	if hooksecurefunc and SpellBookFrame_Update then
		hooksecurefunc("SpellBookFrame_Update", S.suppressWotLK)
	end
	-- The book must be published BEFORE combat, shown or not, since it can open in combat. A
	-- change marks it and the next frame recomputes it (SPELLS_CHANGED comes in bursts);
	-- PLAYER_REGEN_DISABLED, the last moment before lockdown, catches what missed its frame.
	local watcher = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PET_BAR_UPDATE",
		"UNIT_PET", "SPELL_UPDATE_COOLDOWN", "CURRENT_SPELL_CAST_CHANGED", "PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED", "CVAR_UPDATE" }) do
		watcher:RegisterEvent(ev)
	end
	local function onNextFrame()
		watcher:SetScript("OnUpdate", nil)
		if S.dirty and not InCombatLockdown() then S.update() end
	end
	function S.mark()
		S.dirty = true
		watcher:SetScript("OnUpdate", onNextFrame)
	end
	watcher:SetScript("OnEvent", function(_, ev)
		if ev == "SPELL_UPDATE_COOLDOWN" or ev == "CURRENT_SPELL_CAST_CHANGED" then
			S.updateStates()
			return
		end
		if ev == "PET_BAR_UPDATE" then S.updateStates() end
		if ev == "PLAYER_REGEN_DISABLED" then
			if S.dirty then S.update() end
			return
		end
		if ev == "PLAYER_REGEN_ENABLED" then
			if S.dirty or S.queued then S.update() end
			return
		end
		S.mark()
	end)
end

-- Print the book's size, mode and state to the chat.
ForeverUI.SpellBookDebug = function()
	local prefix = "|cff66ccffForeverUI|r "
	if not S.book then
		DEFAULT_CHAT_FRAME:AddMessage(prefix .. L.SPELLBOOK_DEBUG_NOT_BUILT)
		return
	end
	local cats = categories()
	local e = S.state
	local names = {}
	for _, c in ipairs(cats) do table.insert(names, c.name .. " (" .. c.count .. ")") end
	DEFAULT_CHAT_FRAME:AddMessage(prefix .. string.format(
		L.SPELLBOOK_DEBUG_STATE,
		S.book:GetWidth(), S.book:GetHeight(), settings().reduced and L.SPELLBOOK_DEBUG_ONE_PAGE or L.SPELLBOOK_DEBUG_TWO_PAGES,
		e.category, #cats, e.page, e.pages or 1, table.concat(names, ", ")))
end
