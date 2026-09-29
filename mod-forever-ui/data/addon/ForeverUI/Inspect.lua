-- ForeverUI: the inspect window (InspectFrame, load-on-demand Blizzard_InspectUI) in camelot's
-- style. The client frames, slots, model and logic stay; they are moved and re-skinned.
-- Side tabs: character and PvP (camelot has no PvP page; this one uses the sheet's PvP art).
-- No guild tab: 3.3.5 has no inspect guild data. camelot's Talents button opens the talent
-- window on the inspected unit (Talents.inspect).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local I = {}
ForeverUI.Inspection = I

local SEP = string.char(92)
local TABS = "Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP
local PARTS = "Interface" .. SEP .. "ForeverUI" .. SEP .. "characterframe" .. SEP .. "char-paperdoll-"
local PVP = "Interface" .. SEP .. "PVPFrame" .. SEP

local N = {
	window = { 338, 424 },
	-- 48, centered on the ring hole: (-13 + 38 - 24, 16 - 38.5 + 24); larger, the disc goes past
	-- the opaque metal
	portrait = { side = 48, x = 1, y = 1.5 },
	inset = { 4, -60, -6, 4 },
	tabs = { x = 1, y = -30, l = 64, h = 384, side = 55, gap = -2, icon = 50, iconX = -3, crop = 0.03125 },
	level = { y = -27, l = 220 },
	talents = { l = 102, h = 20, y = -39, minLevel = 10 },
	model = { x = 52, y = -66, l = 231, h = 320, arrowsY = -2, arrowsGap = 4 },
	background = { l = 212, h = 245, right = 19, down = 128, veil = 52,
		uLeft = { 0.171875, 1 }, uRight = { 0, 0.296875 }, vTop = 0.0392156862745098 },
	edges = { corner = 7, rule = 5, x = 46, xRight = -47, y = -4, yBottom = 31 },
	slot = 37, gap = 4, left = { 4, -2 }, right = { -4, -2 },
	weapons = { 116, 16 }, weaponsGap = 5,
}

-- Char-Paperdoll-* (camelot/characterframe.xml): file, u1, u2, v1, v2
local PIECES = {
	cornerTL = { "parts", 0.40625, 0.43359375, 0.8046875, 0.859375 },
	topRightCorner = { "parts", 0.40625, 0.43359375, 0.734375, 0.7890625 },
	bottomLeftCorner = { "parts", 0.40625, 0.43359375, 0.6640625, 0.71875 },
	cornerBR = { "parts", 0.40625, 0.43359375, 0.59375, 0.6484375 },
	left = { "vertical", 0.0625, 0.375, 0, 1 },
	right = { "vertical", 0.5, 0.8125, 0, 1 },
	top = { "horizontal", 0, 1, 0.5, 0.8125 },
	down = { "horizontal", 0, 1, 0.0625, 0.375 },
}

local LEFT_COLUMN = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT_COLUMN = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local WEAPONS = { "MainHand", "SecondaryHand", "Ranged" }

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- ------------------------------------------------------------ Side tabs
-- LargeSideTabButtonTemplate, as on the character sheet: common-sidetab background, cropped
-- icon 50 at (-3, 0), common-sidetab-selected when open, common-sidetab-hover on mouse over.
-- bar: parent bar; id: tab index for InspectSwitchTabs; tooltip: tooltip text
local function createTab(bar, id, tooltip)
	local O = N.tabs
	local b = CreateFrame("Button", "ForeverUIInspectTab" .. id, bar)
	b:SetWidth(O.side)
	b:SetHeight(O.side)
	b:SetID(id)
	local background = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "common-sidetab", true)
	background:SetAllPoints(b)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(O.icon)
	icon:SetHeight(O.icon)
	icon:SetPoint("CENTER", b, "CENTER", O.iconX, 0)
	icon:SetTexCoord(O.crop, 1 - O.crop, O.crop, 1 - O.crop)
	local selected = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(selected, "common-sidetab-selected", true)
	selected:SetAllPoints(b)
	selected:Hide()
	local hover = b:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(hover, "common-sidetab-hover", true)
	hover:SetAllPoints(b)
	b.icon, b.selected = icon, selected
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(tooltip, 1.0, 1.0, 1.0)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		PlaySound("igCharacterInfoTab")
		InspectSwitchTabs(self:GetID())
	end)
	return b
end

function I.UpdateTabs()
	local selected = PanelTemplates_GetSelectedTab(InspectFrame)
	for id, b in ipairs(I.tabs or {}) do
		Tpl.SetShown(b.selected, id == selected)
	end
end

-- ------------------------------------------------------------ Character page
-- 3.3.5 DressUpTexturePath for another unit: same fallback for the missing backgrounds
-- (gnome, troll)
local function backgroundPath(unit)
	local _, file = UnitRace(unit)
	local top = string.upper(file or "")
	if top == "GNOME" then
		file = "Dwarf"
	elseif top == "TROLL" then
		file = "Orc"
	end
	return "Interface" .. SEP .. "DressUpFrame" .. SEP .. "DressUpBackground-" .. (file or "Orc")
end

local function createPiece(parent, overlay, key)
	local d = PIECES[key]
	local t = parent:CreateTexture(nil, overlay)
	t:SetTexture(PARTS .. d[1])
	t:SetTexCoord(d[2], d[3], d[4], d[5])
	return t
end

-- Resize an inspect slot to 37 and put the gear slot art behind it.
local function skinSlot(name)
	local b = _G["Inspect" .. name .. "Slot"]
	if not b or b.foreverFrame then return b end
	b:SetWidth(N.slot)
	b:SetHeight(N.slot)
	local frame = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(frame, "ui-character-info-gearslot")
	frame:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.foreverFrame = frame
	return b
end

-- Character page: level, talents button, model, race background, frame and slots.
local function skinCharacter(inset)
	local p = InspectPaperDollFrame
	for _, r in ipairs({ p:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then r:SetAlpha(0) end
	end
	place(InspectLevelText, "TOP", p, "TOP", 0, N.level.y)
	InspectLevelText:SetWidth(N.level.l)
	-- talents button, enabled from level 10 (InspectFrame_UpdateTalentTab)
	local TB = N.talents
	local b = ForeverUI.CreatePanelButton(p, TALENTS, TB.l, TB.h, "ForeverUIInspectTalentsButton", "GameFontNormal")
	b:SetPoint("TOP", p, "TOP", 0, TB.y)
	b:SetMotionScriptsWhileDisabled(true)
	b:SetScript("OnClick", function()
		PlaySound("igCharacterInfoTab")
		if ForeverUI.Talents and InspectFrame.unit then ForeverUI.Talents.inspect(InspectFrame.unit) end
	end)
	b:SetScript("OnEnter", function(self)
		if Tpl.Truthy(self:IsEnabled()) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(UNAVAILABLE, 1.0, 0.125, 0.125)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	I.talents = b
	-- model: 3.3.5 has no model controls, so the two rotate arrows sit at TOP (0, -2), 4 apart
	local M = N.model
	local model = InspectModelFrame
	place(model, "TOPLEFT", p, "TOPLEFT", M.x, M.y)
	model:SetWidth(M.l)
	model:SetHeight(M.h)
	local left, right = InspectModelRotateLeftButton, InspectModelRotateRightButton
	local half = left:GetWidth() / 2 + M.arrowsGap / 2
	place(left, "TOP", model, "TOP", -half, M.arrowsY)
	place(right, "TOP", model, "TOP", half, M.arrowsY)
	ForeverUI.RotateWithMouse(model)
	-- race background under the model (page regions), then the black veil
	local F = N.background
	local background = {}
	local function piece(u, v1, v2, l, h)
		local t = p:CreateTexture(nil, "BACKGROUND")
		t:SetTexCoord(u[1], u[2], v1, v2)
		t:SetWidth(l)
		t:SetHeight(h)
		t:SetDesaturated(true)
		background[#background + 1] = t
		return t
	end
	-- bottom pieces are cut at the inset bottom (109 of 128); whole, they leave the window
	local visibleBottom = (N.window[2] - N.inset[4]) - (-M.y + F.h)
	local topLeft = piece(F.uLeft, F.vTop, 1, F.l, F.h)
	topLeft:SetPoint("TOPLEFT", model, "TOPLEFT", 0, 0)
	local topRight = piece(F.uRight, F.vTop, 1, F.right, F.h)
	topRight:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 0, 0)
	local bottomLeft = piece(F.uLeft, 0, visibleBottom / F.down, F.l, visibleBottom)
	bottomLeft:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, 0)
	local bottomRight = piece(F.uRight, 0, visibleBottom / F.down, F.right, visibleBottom)
	bottomRight:SetPoint("TOPLEFT", topLeft, "BOTTOMRIGHT", 0, 0)
	local veil = p:CreateTexture(nil, "BORDER")
	veil:SetTexture(0, 0, 0, 1)
	veil:SetPoint("TOPLEFT", topLeft, "TOPLEFT", 0, 0)
	veil:SetPoint("BOTTOMRIGHT", topRight, "BOTTOMRIGHT", 0, -(F.down - F.veil))
	I.background, I.veil = background, veil
	-- Char-Paperdoll frame above the model. camelot's second bottom rule (BorderBottom2) is not
	-- drawn: it doubles the frame's bottom rule 3 px higher.
	local B = N.edges
	local frame = CreateFrame("Frame", nil, p)
	frame:SetAllPoints(inset)
	frame:SetFrameLevel(model:GetFrameLevel() + 1)
	local c = {}
	for _, d in ipairs({ { "cornerTL", "TOPLEFT", B.x, B.y }, { "topRightCorner", "TOPRIGHT", B.xRight, B.y },
		{ "bottomLeftCorner", "BOTTOMLEFT", B.x, B.yBottom }, { "cornerBR", "BOTTOMRIGHT", B.xRight, B.yBottom } }) do
		local t = createPiece(frame, "OVERLAY", d[1])
		t:SetWidth(B.corner)
		t:SetHeight(B.corner)
		t:SetPoint(d[2], inset, d[2], d[3], d[4])
		c[d[1]] = t
	end
	local function rule(key, a1, r1, p1, x1, y1, a2, r2, p2, x2, y2)
		local t = createPiece(frame, "OVERLAY", key)
		t:SetPoint(a1, r1, p1, x1, y1)
		t:SetPoint(a2, r2, p2, x2, y2)
		return t
	end
	local g = rule("left", "TOPLEFT", c.cornerTL, "BOTTOMLEFT", -1, 0, "BOTTOMLEFT", c.bottomLeftCorner, "TOPLEFT", -1, 0)
	local d = rule("right", "TOPRIGHT", c.topRightCorner, "BOTTOMRIGHT", 1, 0, "BOTTOMRIGHT", c.cornerBR, "TOPRIGHT", 1, 0)
	local h = rule("top", "TOPLEFT", c.cornerTL, "TOPRIGHT", 0, 1, "TOPRIGHT", c.topRightCorner, "TOPLEFT", 0, 1)
	local down = rule("down", "BOTTOMLEFT", c.bottomLeftCorner, "BOTTOMRIGHT", 0, -1, "BOTTOMRIGHT", c.cornerBR, "BOTTOMLEFT", 0, -1)
	g:SetWidth(B.rule)
	d:SetWidth(B.rule)
	h:SetHeight(B.rule)
	down:SetHeight(B.rule)
	c.left, c.right, c.top, c.down = g, d, h, down
	I.frame = c
	-- slots above the frame (camelot: frameLevel 100), so the bottom rule does not cross
	-- the weapons
	local function skinRaised(name)
		local s = skinSlot(name)
		s:SetFrameLevel(frame:GetFrameLevel() + 1)
		return s
	end
	local previous
	for i, name in ipairs(LEFT_COLUMN) do
		local s = skinRaised(name)
		if i == 1 then
			place(s, "TOPLEFT", inset, "TOPLEFT", N.left[1], N.left[2])
		else
			place(s, "TOPLEFT", previous, "BOTTOMLEFT", 0, -N.gap)
		end
		previous = s
	end
	for i, name in ipairs(RIGHT_COLUMN) do
		local s = skinRaised(name)
		if i == 1 then
			place(s, "TOPRIGHT", inset, "TOPRIGHT", N.right[1], N.right[2])
		else
			place(s, "TOPLEFT", previous, "BOTTOMLEFT", 0, -N.gap)
		end
		previous = s
	end
	for i, name in ipairs(WEAPONS) do
		local s = skinRaised(name)
		if i == 1 then
			place(s, "BOTTOMLEFT", p, "BOTTOMLEFT", N.weapons[1], N.weapons[2])
		else
			place(s, "TOPLEFT", previous, "TOPRIGHT", N.weaponsGap, 0)
		end
		previous = s
	end
end

-- ------------------------------------------------------------ PvP page
-- Head: the rank name and the sheet's ui-character-info-honor-levelbg line (PvPTab.lua),
-- then the inspected player's faction emblem, at 50 % under the rank badge if any, full
-- otherwise ("Civilian"); badges 36 x 42. Below: honor table (today / yesterday / lifetime,
-- as InspectPVPHonor), the sheet's separator, and the three teams as cards (PvPArena.lua).
-- Heights below count from the bottom of the head.
local J = {
	head = { h = 90, nameY = -12, rowY = -10, emblemGap = -4, badgeW = 36, badgeH = 42, underRankAlpha = 0.5 },
	top = -12, tagX = 14, columns = { 150, 215, 280 }, rowLines = { -30, -48 },
	separator = -64, cardsY = -74, cardX = 8, cardH = 52,
	textX = 50, nameY = -7, nameW = 160, ratingX = -14, ratingY = -8, typeY = -30,
	tagsY = -24, valueGap = -2, cardColumns = { 145, 209, 273 },
	-- banner scaled from 90 to 48 high (PvPArena.lua)
	scale = 48 / 90,
}
local SIZES = { 2, 3, 5 }

local function text(parent, template, justify)
	local fs = parent:CreateFontString(nil, "ARTWORK", template)
	if justify then fs:SetJustifyH(justify) end
	return fs
end

-- Column label with its value below; returns the value font string.
local function column(parent, x, y, tag)
	local e = text(parent, "GameFontDisableSmall", "CENTER")
	e:SetPoint("TOP", parent, "TOPLEFT", x, y)
	e:SetText(tag)
	local v = text(parent, "GameFontHighlightSmall", "CENTER")
	v:SetPoint("TOP", e, "BOTTOM", 0, J.valueGap)
	return v
end

-- Arena team card: banner, name, rating and season columns. rank: 1..3 for sizes
-- 2, 3, 5
local function createCard(page, rank, width)
	local c = CreateFrame("Frame", "ForeverUIInspectArenaTeam" .. rank, page)
	c:SetWidth(width)
	c:SetHeight(J.cardH)
	c.size = SIZES[rank]
	c.plate = ForeverUI.CreateNineSlice(c, "common-button-list-collapseexpand", 12, { 0, 0, 0, 0 }, "BACKGROUND") or {}
	local E = J.scale
	local bannerFrame = CreateFrame("Frame", nil, c)
	bannerFrame:SetAllPoints(c)
	c.bannerFrame = bannerFrame
	local pole = bannerFrame:CreateTexture(nil, "BACKGROUND")
	pole:SetTexture(PVP .. "UI-Character-PVP-Elements")
	pole:SetTexCoord(0, 0.099609375, 0.91015625, 0.935546875)
	pole:SetWidth(50 * E)
	pole:SetHeight(13 * E)
	pole:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -2)
	local bannerTexture = bannerFrame:CreateTexture(nil, "BORDER")
	bannerTexture:SetWidth(45 * E)
	bannerTexture:SetHeight(90 * E)
	bannerTexture:SetPoint("TOP", pole, "TOP", 5 * E, -2 * E)
	local edge = bannerFrame:CreateTexture(nil, "ARTWORK")
	edge:SetWidth(45 * E)
	edge:SetHeight(90 * E)
	edge:SetPoint("CENTER", bannerTexture, "CENTER", 0, 0)
	local emblem = bannerFrame:CreateTexture(nil, "OVERLAY")
	emblem:SetWidth(24 * E)
	emblem:SetHeight(24 * E)
	emblem:SetPoint("CENTER", edge, "CENTER", -5 * E, 17 * E)
	c.bannerTexture, c.edge, c.emblem = bannerTexture, edge, emblem
	local d = CreateFrame("Frame", nil, c)
	d:SetAllPoints(c)
	c.data = d
	d.name = text(d, "GameFontNormal", "LEFT")
	d.name:SetWidth(J.nameW)
	d.name:SetPoint("TOPLEFT", c, "TOPLEFT", J.textX, J.nameY)
	d.side = text(d, "GameFontNormalSmall", "RIGHT")
	d.side:SetPoint("TOPRIGHT", c, "TOPRIGHT", J.ratingX, J.ratingY)
	d.ratingLabel = text(d, "GameFontDisableSmall", "RIGHT")
	d.ratingLabel:SetPoint("RIGHT", d.side, "LEFT", -4, 0)
	d.ratingLabel:SetText(ARENA_TEAM_RATING)
	d.type = text(d, "GameFontHighlightSmall", "LEFT")
	d.type:SetPoint("TOPLEFT", c, "TOPLEFT", J.textX, J.typeY)
	d.type:SetText(ARENA_THIS_SEASON)
	local K = J.cardColumns
	d.games = column(d, K[1], J.tagsY, GAMES)
	d.winLoss = column(d, K[2], J.tagsY, WIN_LOSS)
	d.character = column(d, K[3], J.tagsY, RATING)
	c.empty = c:CreateFontString(nil, "ARTWORK", "GameFontDisableLarge")
	c.empty:SetPoint("CENTER", c, "CENTER", 0, 0)
	c.empty:Hide()
	return c
end

-- One card: the team of that size, or the empty slot, as InspectPVPTeam_Update (season values
-- and the inspected player's rating). id: GetInspectArenaTeamData index, or nil
local function populateCard(c, id)
	local d = c.data
	if not id then
		c:SetAlpha(0.4)
		c.bannerTexture:SetTexture(PVP .. "PVP-Banner-" .. c.size)
		c.bannerTexture:SetVertexColor(1, 1, 1)
		c.bannerFrame:SetAlpha(0.1)
		c.edge:Hide()
		c.emblem:Hide()
		d:Hide()
		c.empty:SetText(string.format(PVP_TEAMSIZE, c.size, c.size))
		c.empty:Show()
		return
	end
	local name, size, side, played, wins, _, character, fr, fg, fb, emblem, er, eg, eb, edge, br, bgc, bb =
		GetInspectArenaTeamData(id)
	c:SetAlpha(1)
	c.bannerFrame:SetAlpha(1)
	d.name:SetText(name)
	d.side:SetText(side)
	d.games:SetText(played)
	d.winLoss:SetText(tostring(wins or 0) .. " - " .. tostring((played or 0) - (wins or 0)))
	d.character:SetText(character)
	c.bannerTexture:SetTexture(PVP .. "PVP-Banner-" .. tostring(size))
	c.bannerTexture:SetVertexColor(fr or 1, fg or 1, fb or 1)
	c.edge:SetVertexColor(br or 1, bgc or 1, bb or 1)
	c.emblem:SetVertexColor(er or 1, eg or 1, eb or 1)
	if edge and edge ~= -1 then
		c.edge:SetTexture(PVP .. "PVP-Banner-" .. tostring(size) .. "-Border-" .. tostring(edge))
	end
	if emblem and emblem ~= -1 then
		c.emblem:SetTexture(PVP .. "Icons" .. SEP .. "PVP-Banner-Emblem-" .. tostring(emblem))
	end
	c.edge:Show()
	c.emblem:Show()
	d:Show()
	c.empty:Hide()
end

-- Rank of the inspected player from lifetime honorable kills at the sheet's thresholds
-- (IsTitleKnown only knows the player's titles). The server sends no honor data for a player
-- out of inspect range or attackable (other faction, duel; MiscHandler.cpp,
-- HandleInspectHonorStatsOpcode): GetInspectHonorData then returns zeros, so "Civilian" and
-- the faction emblem.
local function updateRank(page, wins)
	local R = ForeverUI.PvPRanks
	local unit = InspectFrame and InspectFrame.unit
	local faction = unit and UnitFactionGroup(unit)
	if not R or not faction then
		page.badge:Hide()
		page.insignia:Hide()
		page.rank:SetText("")
		return
	end
	-- unknown thresholds (not sent by the server): no rank, the emblem stays alone
	local number = R.byWins(wins)
	page.rank:SetText(number and R.name(number, faction) or "")
	number = number or 0
	ForeverUI.SetAtlas(page.badge, string.format(R.badgeFaction, string.lower(faction)), true)
	page.badge:Show()
	-- a rank: its badge over the emblem, half faded
	if number > 0 and ForeverUI.SetAtlas(page.insignia, string.format(R.badgeRank, number), true) then
		page.badge:SetAlpha(J.head.underRankAlpha)
		page.insignia:Show()
	else
		page.badge:SetAlpha(1)
		page.insignia:Hide()
	end
end

function I.UpdatePvP()
	local page = I.pvpPage
	if not page then return end
	local todayHK, todayHonor, yesterdayHK, yesterdayHonor, lifetimeHK = GetInspectHonorData()
	updateRank(page, lifetimeHK)
	local v = page.values
	v[1]:SetText(todayHK)
	v[2]:SetText(yesterdayHK)
	v[3]:SetText(lifetimeHK)
	v[4]:SetText(todayHonor)
	v[5]:SetText(yesterdayHonor)
	v[6]:SetText("-")
	local indices = {}
	for i = 1, (MAX_ARENA_TEAMS or 3) do
		local _, size = GetInspectArenaTeamData(i)
		for rank, t in ipairs(SIZES) do
			if size == t then indices[rank] = i end
		end
	end
	for rank, c in ipairs(page.maps) do
		populateCard(c, indices[rank])
	end
end

-- PvP page rebuilt over the client's InspectPVPFrame.
local function buildPvP(f, inset)
	-- the client frame stays shown (it requests the data and gets the events), but invisible
	InspectPVPFrame:SetAlpha(0)
	InspectPVPFrame:EnableMouse(false)
	for i = 1, 3 do
		local b = _G["InspectPVPTeam" .. i]
		if b then b:EnableMouse(false) end
	end
	local page = CreateFrame("Frame", "ForeverUIInspectPvP", f)
	page:SetAllPoints(inset)
	page:SetFrameLevel(InspectPVPFrame:GetFrameLevel() + 10)
	page:Hide()
	local width = N.window[1] + N.inset[3] - N.inset[1] - 2 * J.cardX
	-- head: rank name and line, then emblem and badge
	local R = J.head
	local head = CreateFrame("Frame", nil, page)
	head:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	head:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	head:SetHeight(R.h)
	local rankName = text(head, "GameFontHighlightLarge", "CENTER")
	rankName:SetPoint("TOP", head, "TOP", 0, R.nameY)
	local row = head:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(row, "ui-character-info-honor-levelbg")
	row:SetWidth(width)
	row:SetPoint("BOTTOM", rankName, "BOTTOM", 0, R.rowY)
	local badge = head:CreateTexture(nil, "ARTWORK")
	badge:SetWidth(R.badgeW)
	badge:SetHeight(R.badgeH)
	badge:SetPoint("TOP", row, "BOTTOM", 0, R.emblemGap)
	badge:Hide()
	local insignia = head:CreateTexture(nil, "OVERLAY")
	insignia:SetWidth(R.badgeW)
	insignia:SetHeight(R.badgeH)
	insignia:SetPoint("CENTER", badge, "CENTER", 0, 0)
	insignia:Hide()
	page.head, page.badge, page.insignia, page.rank, page.row = head, badge, insignia, rankName, row
	-- honor, under the head
	for i, t in ipairs({ HONOR_TODAY, HONOR_YESTERDAY, HONOR_LIFETIME }) do
		local e = text(page, "GameFontDisableSmall", "CENTER")
		e:SetPoint("TOP", head, "BOTTOMLEFT", J.columns[i], J.top)
		e:SetText(t)
	end
	page.values = {}
	for r, t in ipairs({ KILLS, HONOR }) do
		local e = text(page, "GameFontDisableSmall", "LEFT")
		e:SetPoint("TOPLEFT", head, "BOTTOMLEFT", J.tagX, J.rowLines[r])
		e:SetText(t)
		for i = 1, 3 do
			local v = text(page, "GameFontHighlightSmall", "CENTER")
			v:SetPoint("TOP", head, "BOTTOMLEFT", J.columns[i], J.rowLines[r])
			page.values[#page.values + 1] = v
		end
	end
	local separator = page:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(separator, "ui-character-info-scrollline-long")
	separator:SetWidth(width)
	separator:SetPoint("TOP", head, "BOTTOM", 0, J.separator)
	page.separator = separator
	page.maps = {}
	for rank = 1, #SIZES do
		local c = createCard(page, rank, width)
		if rank == 1 then
			c:SetPoint("TOPLEFT", head, "BOTTOMLEFT", J.cardX, J.cardsY)
		else
			c:SetPoint("TOPLEFT", page.maps[rank - 1], "BOTTOMLEFT", 0, 0)
		end
		page.maps[rank] = c
	end
	I.pvpPage = page
	InspectPVPFrame:HookScript("OnShow", function()
		page:Show()
		I.UpdatePvP()
	end)
	InspectPVPFrame:HookScript("OnHide", function() page:Hide() end)
end

-- ------------------------------------------------------------ Moving
-- The title bar is the drag handle, as in Achievements.lua. The position is saved in
-- ForeverUIDB.positions (key "inspection", top-center, as WindowStack.lua) and re-applied on
-- show and after UpdateUIPanelPositions, which re-places this "left" panel whenever a panel
-- opens or closes. Nothing here is secure, so moving works in combat. The inspected talent
-- window does not follow.
local KEY = "inspection"

local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

function I.Reposition()
	local f = InspectFrame
	local p = positions()[KEY]
	if not f or not p then return end
	f:ClearAllPoints()
	f:SetPoint("TOP", UIParent, "TOP", p.x, p.y)
end

-- Top-center of a frame relative to UIParent's (nil while the frame is not placed)
local function topCenter(frame)
	local cx, ux = frame:GetCenter(), UIParent:GetCenter()
	local top, uiTop = frame:GetTop(), UIParent:GetTop()
	if not cx or not ux or not top or not uiTop then return end
	return cx - ux, top - uiTop
end

local function makeMovable(f, handle)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	handle:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local x, y = topCenter(f)
		if not x then return end
		f:ClearAllPoints()
		f:SetPoint("TOP", UIParent, "TOP", x, y)
		-- we keep the position: stop the client from saving it too
		if f.SetUserPlaced then f:SetUserPlaced(false) end
		positions()[KEY] = { x = x, y = y }
	end)
	f:HookScript("OnShow", I.Reposition)
	hooksecurefunc("UpdateUIPanelPositions", function()
		if f:IsShown() then I.Reposition() end
	end)
end

-- ------------------------------------------------------------ Opening
-- Refresh portraits, PvP tab icon, race background and talents button for the unit.
function I.Update()
	local f = InspectFrame
	local skin = f and f.foreverSkin
	local unit = f and f.unit
	if not skin or not unit then return end
	SetPortraitTexture(skin.portrait, unit)
	local o = I.tabs
	-- UpdateCharacterModeTabPortrait: the portrait, cropped again
	local R = N.tabs.crop
	SetPortraitTexture(o[1].icon, unit)
	o[1].icon:SetTexCoord(R, 1 - R, R, 1 - R)
	local faction = UnitFactionGroup(unit) or UnitFactionGroup("player") or "Alliance"
	o[2].icon:SetTexture(TABS .. "Inv_SideTab_Honor_" .. faction .. "_c60")
	local file = backgroundPath(unit)
	for i, t in ipairs(I.background) do t:SetTexture(file .. i) end
	local level = UnitLevel(unit) or 0
	I.talents:Activate(not (level > 0 and level < N.talents.minLevel))
	I.UpdateTabs()
end

function I.Skin()
	local f = InspectFrame
	if not f or f.foreverSkin then return end
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	InspectFramePortrait:SetAlpha(0)
	InspectNameFrame:SetAlpha(0)
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = InspectNameText:GetText(),
	})
	f.foreverSkin = skin
	makeMovable(f, skin.banner)
	skin.title:SetFontObject(GameFontHighlight)
	hooksecurefunc(InspectNameText, "SetText", function()
		skin.title:SetText(InspectNameText:GetText() or "")
	end)
	-- inset, without button bar
	local E = N.inset
	local inset = CreateFrame("Frame", "ForeverUIInspectInset", f)
	inset:SetPoint("TOPLEFT", f, "TOPLEFT", E[1], E[2])
	inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", E[3], E[4])
	local marble = f:CreateTexture(nil, "BACKGROUND")
	marble:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble", true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(inset)
	skin.frameBox = Tpl.NineSlice(f, "InsetFrameTemplate", inset)
	skin.marble, skin.inset = marble, inset
	Tpl.CloseButton(InspectFrameCloseButton, f)
	InspectFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	-- the bottom tabs go away; the side tabs replace them
	for i = 1, 3 do
		local t = _G["InspectFrameTab" .. i]
		t:SetAlpha(0)
		t:EnableMouse(false)
		t:Hide()
	end
	local O = N.tabs
	local bar = CreateFrame("Frame", nil, f)
	bar:SetWidth(O.l)
	bar:SetHeight(O.h)
	bar:SetPoint("TOPLEFT", f, "TOPRIGHT", O.x, O.y)
	bar:SetFrameLevel(f:GetFrameLevel() + 1)
	I.tabs = { createTab(bar, 1, CHARACTER_INFO), createTab(bar, 2, PLAYER_V_PLAYER) }
	I.tabs[1]:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	I.tabs[2]:SetPoint("TOPLEFT", I.tabs[1], "BOTTOMLEFT", 0, O.gap)
	skinCharacter(inset)
	buildPvP(f, inset)
	f:HookScript("OnShow", I.Update)
	-- the talent window follows the inspection: it closes with it
	f:HookScript("OnHide", function()
		if ForeverUI.Talents and ForeverUI.Talents.inspection and PlayerTalentFrame then
			HideUIPanel(PlayerTalentFrame)
		end
	end)
	hooksecurefunc("InspectSwitchTabs", I.UpdateTabs)
	hooksecurefunc("InspectFrame_UnitChanged", I.Update)
	I.Update()
	I.Reposition()
end

I.Skin()

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("UNIT_PORTRAIT_UPDATE")
watcher:RegisterEvent("INSPECT_HONOR_UPDATE")
watcher:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "Blizzard_InspectUI" then I.Skin() end
	elseif event == "UNIT_PORTRAIT_UPDATE" then
		if InspectFrame and InspectFrame:IsShown() and arg1 == InspectFrame.unit then I.Update() end
	elseif I.pvpPage and I.pvpPage:IsShown() then
		I.UpdatePvP()
	end
end)
