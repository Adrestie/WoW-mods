-- ForeverUI: arena teams in the left pane of the PvP tab, and a team detail window beside it.
-- camelot has no arena teams, so the screen follows the 3.3.5 PVPFrame (PVPTeam_Update,
-- PVPTeamDetails) in camelot art. As in 3.3.5, cards show this week only (PVPTeam_Update
-- always hides the toggle); the detail window has its own week / season toggle.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local L = ForeverUI.L

local A = {}
ForeverUI.PvPArena = A

local SEP = string.char(92)
local PVP = "Interface" .. SEP .. "PVPFrame" .. SEP
local ELEMENTS = PVP .. "UI-Character-PVP-Elements"
local POINTS_ICON = PVP .. "PVP-ArenaPoints-Icon"
local COLUMN_TABS = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "WhoFrame-ColumnTabs"
local COLUMN_HIGHLIGHT = "Interface" .. SEP .. "PaperDollInfoFrame" .. SEP .. "UI-Character-Tab-Highlight"
local ARROW = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-SpellbookIcon-NextPage-"
local SQUARE_HOVER = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Common-MouseHilight"

local SIZES = { 2, 3, 5 }
local MAX_TEAMS = 3
local MAX_MEMBERS = 10

-- Pane order, top to bottom: rank title, gauge, win counter, separator, arena points, teams.
-- Each piece hangs on the previous one (the counter on the dial, PvPTab.lua); the cards sit
-- against the pane bottom, 52 high to fit below the arena points.
local PANE_W = 398
local CARDS_X = 16
local CARD_W = PANE_W - 2 * CARDS_X
local CARD_H, CARD_GAP = 52, 0     -- no gap between cards
local ATLAS_SEPARATOR = "ui-character-info-scrollline-long"
local SEPARATOR_BELOW_COUNTER = -4
-- Teams sit against the pane bottom, the last one CARDS_BOTTOM above it; the free space
-- stays between the arena points and the first card.
local CARDS_BOTTOM = 4
local OFF_SEASON_BELOW_POINTS = -10
local CARD_LEVEL = 6                        -- above the dial (its glow overflows)

-- Banner: PVPTeamStandardTemplate scaled from 90 to 48 high to fit a card.
local SCALE = 48 / 90
local POLE_X, POLE_Y = 8, -2
local POLE_W, POLE_H = 50 * SCALE, 13 * SCALE
local BANNER_W, BANNER_H = 45 * SCALE, 90 * SCALE
local BANNER_X, BANNER_Y = 5 * SCALE, -2 * SCALE
local EMBLEM_SIZE = 24 * SCALE
local EMBLEM_X, EMBLEM_Y = -5 * SCALE, 17 * SCALE

-- Card text
local TEXT_X = 50
local NAME_Y, NAME_W = -7, 190
local RATING_X, RATING_Y = -14, -8
local TYPE_Y = -30
local TAGS_Y = -24
local VALUE_GAP = -2
local CARD_COLUMNS = { games = 170, winLoss = 245, played = 320 }
local POINTS_GAP, ICON_GAP = 15, 5
local ICON_W, ICON_H = 17, 15

-- camelot plate and hover, as on the reputation rows.
local ATLAS_PLATE = "common-button-list-collapseexpand"
local PLATE_CORNER = 12
local ATLAS_HOVER_SIDE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_HOVER_MIDDLE = "charactercreate-customize-dropdown-linemouseover-middle"
local HOVER_SIDE = 6
local HOVER_ALPHA, SELECTED_ALPHA = 0.10, 0.20

-- Detail window, beside the character sheet: past its side tabs (55 wide, at +1 from its
-- edge) and the overhang of its metal.
local WINDOW_W, WINDOW_H = 400, 372
local WINDOW_X, WINDOW_Y = 76, 0
local WINDOW_LEVEL = 10
local TOP_LEFT_CORNER = "ui-frame-metal-cornertopleft"
local CLOSE_SIZE = 24
local CLOSE_X, CLOSE_Y = 1, 0
local TITLE_Y, TITLE_W = -6, 300
local STATS_X, STATS_Y = 20, -40
local STATS_COLUMNS = { 170, 222, 274, 326 }
local STATS_VALUE_GAP = -6
local SEPARATOR_Y = -76
local HEADERS_X, HEADERS_Y = 15, -86
local HEADER_H = 24
local HEADERS = {
	{ text = "NAME", width = 110, sort = "name" },
	{ text = "CLASS", width = 80, sort = "class" },
	{ text = "PLAYED", width = 55, sort = "played", seasonSort = "seasonplayed" },
	{ text = "WIN_LOSS", width = 75, sort = "won", seasonSort = "seasonwon" },
	{ text = "RATING", width = 59, sort = "rating" },
}
local ROWS_X, ROWS_Y = 15, -115
local ROW_W, ROW_H, ROW_GAP = 380, 16, 3
local ADD_W, ADD_H = 100, 22
local ADD_X, ADD_Y = 20, 16
local TOGGLE_SIZE = 32
local TOGGLE_X, TOGGLE_Y = -17, 17

local maps, points, offSeason, window
local host

-- --------------------------------------------------------------- data

-- Client global string named key, or default.
local function txt(key, default)
	return _G[key] or default
end

-- Slot of each team size (2, 3, 5): its GetArenaTeam index, or nil.
local function indicesBySize()
	local indices = {}
	for i = 1, MAX_TEAMS do
		local name, size = GetArenaTeam(i)
		if name then
			for rank, t in ipairs(SIZES) do
				if t == size then
					indices[rank] = i
				end
			end
		end
	end
	return indices
end

-- All GetArenaTeam fields of team id, by name.
local function readTeam(id)
	local e = {}
	local background, emblem, edge = {}, {}, {}
	e.name, e.size, e.side, e.played, e.wins, e.seasonPlayed,
		e.seasonWins, e.playerPlayed, e.seasonPlayerPlayed, e.rank, e.playerRating,
		background.r, background.g, background.b, e.emblem, emblem.r, emblem.g, emblem.b,
		e.edge, edge.r, edge.g, edge.b = GetArenaTeam(id)
	e.backgroundColor, e.emblemColor, e.borderColor = background, emblem, edge
	return e
end

local function percentage(part, total)
	if total and total ~= 0 then
		return math.floor((part / total) * 100)
	end
	return math.floor((part or 0) * 100)
end

-- ----------------------------------------------------------- small pieces

-- Row hover highlight (camelot dropdown line mouseover), shown by alpha.
local function createHover(parent)
	local hover = CreateFrame("Frame", nil, parent)
	hover:SetAllPoints(parent)
	hover:SetAlpha(0)

	local left = hover:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(left, ATLAS_HOVER_SIDE, true)
	left:SetWidth(HOVER_SIDE)
	left:SetPoint("TOPLEFT", hover, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", hover, "BOTTOMLEFT", 0, 0)

	local right = hover:CreateTexture(nil, "BACKGROUND")
	if ForeverUI.SetAtlas(right, ATLAS_HOVER_SIDE, true) then
		local e = ForeverUI.AtlasEntry(ATLAS_HOVER_SIDE)
		right:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	right:SetWidth(HOVER_SIDE)
	right:SetPoint("TOPRIGHT", hover, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", hover, "BOTTOMRIGHT", 0, 0)

	local middle = hover:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(middle, ATLAS_HOVER_MIDDLE, true)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
	return hover
end

local function text(parent, template, justify)
	local fs = parent:CreateFontString(nil, "ARTWORK", template)
	if justify then
		fs:SetJustifyH(justify)
	end
	return fs
end

-- Label with its value below, centred on column x.
-- tag: label text; valueTemplate: value font; gap: space between label and value
local function column(parent, x, y, tag, valueTemplate, gap)
	local e = text(parent, "GameFontDisableSmall", "CENTER")
	e:SetPoint("TOP", parent, "TOPLEFT", x, y)
	e:SetText(tag)
	local v = text(parent, valueTemplate or "GameFontHighlightSmall", "CENTER")
	v:SetPoint("TOP", e, "BOTTOM", 0, gap or VALUE_GAP)
	return e, v
end

-- camelot UIPanelButtonTemplate: ForeverUI.CreatePanelButton (AtlasUtil).
local function panelButton(parent, buttonText, width, height)
	return ForeverUI.CreatePanelButton(parent, buttonText, width, height)
end

-- Shared with the right pane (PvPBattlegrounds.lua): same hover and same camelot button.
A.createHover = createHover
A.panelButton = panelButton

-- ------------------------------------------------------------------ cards

-- Team card; rank: 1, 2, 3 for the 2v2, 3v3, 5v5 slot.
local function createCard(block, rank)
	local c = CreateFrame("Button", "ForeverUIArenaTeam" .. rank, block)
	c:SetWidth(CARD_W)
	c:SetHeight(CARD_H)
	c:SetFrameLevel(block:GetFrameLevel() + CARD_LEVEL)
	c:RegisterForClicks("LeftButtonUp")
	c.size = SIZES[rank]

	c.plate = ForeverUI.CreateNineSlice(c, ATLAS_PLATE, PLATE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	c.hover = createHover(c)

	-- Banner: pole, tinted banner, its border and the emblem.
	local bannerFrame = CreateFrame("Frame", nil, c)
	bannerFrame:SetAllPoints(c)
	c.bannerFrame = bannerFrame
	local pole = bannerFrame:CreateTexture(nil, "BACKGROUND")
	pole:SetTexture(ELEMENTS)
	pole:SetTexCoord(0, 0.099609375, 0.91015625, 0.935546875)
	pole:SetWidth(POLE_W)
	pole:SetHeight(POLE_H)
	pole:SetPoint("TOPLEFT", c, "TOPLEFT", POLE_X, POLE_Y)
	local bannerTexture = bannerFrame:CreateTexture(nil, "BORDER")
	bannerTexture:SetWidth(BANNER_W)
	bannerTexture:SetHeight(BANNER_H)
	bannerTexture:SetPoint("TOP", pole, "TOP", BANNER_X, BANNER_Y)
	local edge = bannerFrame:CreateTexture(nil, "ARTWORK")
	edge:SetWidth(BANNER_W)
	edge:SetHeight(BANNER_H)
	edge:SetPoint("CENTER", bannerTexture, "CENTER", 0, 0)
	local emblem = bannerFrame:CreateTexture(nil, "OVERLAY")
	emblem:SetWidth(EMBLEM_SIZE)
	emblem:SetHeight(EMBLEM_SIZE)
	emblem:SetPoint("CENTER", edge, "CENTER", EMBLEM_X, EMBLEM_Y)
	c.bannerTexture, c.edge, c.emblem = bannerTexture, edge, emblem

	-- Team data in its own frame, so an empty slot hides it at once, like PVPTeam<n>Data.
	local d = CreateFrame("Frame", nil, c)
	d:SetAllPoints(c)
	c.data = d
	d.name = text(d, "GameFontNormal", "LEFT")
	d.name:SetWidth(NAME_W)
	d.name:SetPoint("TOPLEFT", c, "TOPLEFT", TEXT_X, NAME_Y)
	d.side = text(d, "GameFontNormalSmall", "RIGHT")
	d.side:SetPoint("TOPRIGHT", c, "TOPRIGHT", RATING_X, RATING_Y)
	d.ratingLabel = text(d, "GameFontDisableSmall", "RIGHT")
	d.ratingLabel:SetPoint("RIGHT", d.side, "LEFT", -4, 0)
	d.ratingLabel:SetText(ARENA_TEAM_RATING)
	d.type = text(d, "GameFontHighlightSmall", "LEFT")
	d.type:SetPoint("TOPLEFT", c, "TOPLEFT", TEXT_X, TYPE_Y)
	d.gamesTag, d.games = column(d, CARD_COLUMNS.games, TAGS_Y, GAMES)
	d.recordTag, d.winLoss = column(d, CARD_COLUMNS.winLoss, TAGS_Y, WIN_LOSS)
	d.playedTag, d.played = column(d, CARD_COLUMNS.played, TAGS_Y, PLAYED)

	-- Empty slot: "(2v2)" in GameFontDisableLarge.
	c.empty = c:CreateFontString(nil, "ARTWORK", "GameFontDisableLarge")
	c.empty:SetPoint("CENTER", c, "CENTER", 0, 0)
	c.empty:Hide()

	c:SetScript("OnEnter", function(self)
		if not self.selectedItem then
			self.hover:SetAlpha(self.team and HOVER_ALPHA or 0)
		end
		if GameTooltip_AddNewbieTip then
			GameTooltip_AddNewbieTip(self, ARENA_TEAM, 1.0, 1.0, 1.0,
				self.team and CLICK_FOR_DETAILS or ARENA_TEAM_LEAD_IN, 1)
		end
	end)
	c:SetScript("OnLeave", function(self)
		if not self.selectedItem then
			self.hover:SetAlpha(0)
		end
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	c:SetScript("OnClick", function(self)
		A.toggleDetail(self.team)
	end)
	return c
end

-- Fills a card from team id, or shows the greyed empty slot when id is nil.
local function populateCard(c, id)
	c.team = id
	local d = c.data
	if not id then
		c:SetID(0)
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

	local e = readTeam(id)
	c:SetID(id)
	c:SetAlpha(1)
	c.bannerFrame:SetAlpha(1)

	-- PVPTeam_Update: this week only (see the file header).
	local played, wins, playerPlayed = e.played or 0, e.wins or 0, e.playerPlayed or 0
	local pct = percentage(playerPlayed, played)
	d.name:SetText(e.name)
	d.side:SetText(e.side)
	d.type:SetText(ARENA_THIS_WEEK)
	d.games:SetText(played)
	d.winLoss:SetText(tostring(wins) .. " - " .. tostring(played - wins))
	d.played:SetText(tostring(playerPlayed) .. " (" .. string.format("%d", pct) .. "%)")
	if pct < 10 then
		d.played:SetVertexColor(1.0, 0, 0)
	else
		d.played:SetVertexColor(1.0, 1.0, 1.0)
	end

	c.bannerTexture:SetTexture(PVP .. "PVP-Banner-" .. tostring(e.size))
	c.bannerTexture:SetVertexColor(e.backgroundColor.r or 1, e.backgroundColor.g or 1, e.backgroundColor.b or 1)
	c.edge:SetVertexColor(e.borderColor.r or 1, e.borderColor.g or 1, e.borderColor.b or 1)
	c.emblem:SetVertexColor(e.emblemColor.r or 1, e.emblemColor.g or 1, e.emblemColor.b or 1)
	if e.edge and e.edge ~= -1 then
		c.edge:SetTexture(PVP .. "PVP-Banner-" .. tostring(e.size) .. "-Border-" .. tostring(e.edge))
	end
	if e.emblem and e.emblem ~= -1 then
		c.emblem:SetTexture(PVP .. "Icons" .. SEP .. "PVP-Banner-Emblem-" .. tostring(e.emblem))
	end
	c.edge:Show()
	c.emblem:Show()
	d:Show()
	c.empty:Hide()
end

-- Highlights the card whose team is open in the detail window.
local function markCards()
	if not maps then
		return
	end
	local openTeam = window and window:IsShown() and window.team
	for _, c in ipairs(maps) do
		local before = c.selectedItem
		c.selectedItem = (c.team ~= nil and c.team == openTeam) or nil
		if c.selectedItem then
			c.hover:SetAlpha(SELECTED_ALPHA)
		elseif before then
			c.hover:SetAlpha(0)
		end
	end
end

local function updatePoints()
	if not points then
		return
	end
	points.value:SetText(GetArenaCurrency and GetArenaCurrency() or 0)
	-- The row is centred on the pane, so its width is the width of its contents.
	local width = points.tag:GetStringWidth() + POINTS_GAP
		+ points.value:GetStringWidth() + ICON_GAP + ICON_W
	points:SetWidth(math.max(1, width))
end

function A.update()
	if not maps then
		return
	end
	local season = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0
	if season == 0 then
		for _, c in ipairs(maps) do
			c:Hide()
		end
		local prev = GetPreviousArenaSeason and GetPreviousArenaSeason() or 0
		offSeason:SetText(string.format(ARENA_OFF_SEASON_TEXT,
			prev, prev + 1))
		offSeason:Show()
	else
		offSeason:Hide()
		local indices = indicesBySize()
		for rank, c in ipairs(maps) do
			populateCard(c, indices[rank])
			c:Show()
		end
	end
	updatePoints()
	markCards()
end

-- -------------------------------------------------------- detail window

-- UnitPopup "TEAM" and ADD_TEAMMEMBER read PVPTeamDetails.team, and the menu offers
-- promote / kick / leave only if PVPTeamDetails:IsShown(). So the client frame gets our team
-- and its shown flag; it stays invisible under the hidden PVPFrame.
local function syncClientFrame(id)
	local client = _G["PVPTeamDetails"]
	if not client then
		return
	end
	client.team = id
	if id then
		client:Show()
	else
		client:Hide()
	end
end

local function redCloseButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(CLOSE_SIZE)
	b:SetHeight(CLOSE_SIZE)
	for _, state in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(state[3])
		b[state[1]](b, e and e[1] or "")
		local t = b[state[2]](b)
		if t then
			ForeverUI.SetAtlas(t, state[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
			if state[3] == "redbutton-highlight" then
				t:SetBlendMode("ADD")
			end
		end
	end
	b:SetScript("OnClick", function() parent:Hide() end)
	return b
end

-- Roster column header n (HEADERS); previous: header on its left. A click sorts the roster.
local function createHeader(f, n, previous)
	local def = HEADERS[n]
	local b = CreateFrame("Button", "ForeverUIArenaTeamDetailsHeader" .. n, f)
	b:SetHeight(HEADER_H)
	b:SetWidth(def.width)
	if previous then
		b:SetPoint("LEFT", previous, "RIGHT", -2, 0)
	else
		b:SetPoint("TOPLEFT", f, "TOPLEFT", HEADERS_X, HEADERS_Y)
	end
	-- WhoFrameColumn_SetWidth: the middle takes the width minus both ends.
	local g = b:CreateTexture(nil, "BACKGROUND")
	g:SetTexture(COLUMN_TABS)
	g:SetTexCoord(0, 0.078125, 0, 0.75)
	g:SetWidth(5)
	g:SetHeight(HEADER_H)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local m = b:CreateTexture(nil, "BACKGROUND")
	m:SetTexture(COLUMN_TABS)
	m:SetTexCoord(0.078125, 0.90625, 0, 0.75)
	m:SetWidth(def.width - 9)
	m:SetHeight(HEADER_H)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	local d = b:CreateTexture(nil, "BACKGROUND")
	d:SetTexture(COLUMN_TABS)
	d:SetTexCoord(0.90625, 0.96875, 0, 0.75)
	d:SetWidth(4)
	d:SetHeight(HEADER_H)
	d:SetPoint("LEFT", m, "RIGHT", 0, 0)
	local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	fs:SetPoint("CENTER", m, "CENTER", 0, 0)
	b:SetFontString(fs)
	b:SetText(txt(def.text))
	b:SetHighlightTexture(COLUMN_HIGHLIGHT)
	local s = b:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", g, "TOPLEFT", -2, 5)
		s:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 2, -7)
	end
	b.def = def
	b:SetScript("OnClick", function(self)
		local sort = (window.season and self.def.seasonSort) or self.def.sort
		if sort and SortArenaTeamRoster then
			SortArenaTeamRoster(sort)
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	return b
end

-- Roster row n. Cells are FontStrings; "played" is a frame so it can carry its tooltip.
local function createRow(f, n)
	local l = CreateFrame("Button", "ForeverUIArenaTeamDetailsRow" .. n, f)
	l:SetWidth(ROW_W)
	l:SetHeight(ROW_H)
	l:SetPoint("TOPLEFT", f, "TOPLEFT", ROWS_X, ROWS_Y - (n - 1) * (ROW_H + ROW_GAP))
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	l.hover = createHover(l)

	local function cell(x, width, template, justify)
		local fs = text(l, template, justify)
		fs:SetWidth(width)
		fs:SetHeight(14)
		fs:SetPoint("TOPLEFT", l, "TOPLEFT", x, -1)
		return fs
	end
	-- name 104 at 10; class 73 at +4; played 45 at +4; wins-losses 72 at +0;
	-- rating 54 at +4 (PVPTeamMemberButtonTemplate)
	l.name = cell(10, 104, "GameFontNormalSmall", "LEFT")
	l.className = cell(118, 70, "GameFontNormalSmall", "LEFT")
	local played = CreateFrame("Frame", nil, l)
	played:SetWidth(45)
	played:SetHeight(14)
	played:SetPoint("TOPLEFT", l, "TOPLEFT", 195, -1)
	played:EnableMouse(true)
	l.played = text(played, "GameFontNormalSmall", "CENTER")
	l.played:SetAllPoints(played)
	l.wins = cell(240, 30, "GameFontHighlightSmall", "RIGHT")
	l.dash = cell(269, 12, "GameFontHighlightSmall", "LEFT")
	l.dash:SetText(" - ")
	l.losses = cell(281, 30, "GameFontHighlightSmall", "LEFT")
	l.side = cell(316, 54, "GameFontNormalSmall", "CENTER")

	local function lightUp(self)
		if not l.selectedItem then
			l.hover:SetAlpha(HOVER_ALPHA)
		end
	end
	local function turnOff(self)
		if not l.selectedItem then
			l.hover:SetAlpha(0)
		end
	end
	l:SetScript("OnEnter", lightUp)
	l:SetScript("OnLeave", turnOff)
	played:SetScript("OnEnter", function(self)
		lightUp()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if l.pct then
			GameTooltip:SetText(l.pct)
		end
	end)
	played:SetScript("OnLeave", function()
		turnOff()
		GameTooltip:Hide()
	end)

	-- PVPTeamDetailsButton_OnClick
	l:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			local name, _, _, _, online = GetArenaTeamRosterInfo(window.team, self.member)
			if PVPFrame_ShowDropdown then
				PVPFrame_ShowDropdown(name, online)
			end
		else
			SetArenaTeamRosterSelection(window.team, self.member)
			A.updateDetail()
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	return l
end

local function createWindow(block)
	local f = CreateFrame("Frame", "ForeverUIArenaTeamDetails", block)
	f:SetWidth(WINDOW_W)
	f:SetHeight(WINDOW_H)
	f:SetPoint("TOPLEFT", _G["CharacterFrame"] or host, "TOPRIGHT", WINDOW_X, WINDOW_Y)
	f:SetFrameLevel(block:GetFrameLevel() + WINDOW_LEVEL)
	f:EnableMouse(true)
	f:Hide()
	ForeverUI.SetPanelArt(f, { topLeftCorner = TOP_LEFT_CORNER, level = 5 })
	local metal = f.foreverSkinLayer or f

	-- title in the metal bar: name, then size
	local banner = CreateFrame("Frame", nil, f)
	banner:SetAllPoints(f)
	banner:SetFrameLevel(metal:GetFrameLevel() + 1)
	f.title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOP", f, "TOP", 0, TITLE_Y)
	f.title:SetWidth(TITLE_W)

	f.close = redCloseButton(f)
	f.close:SetFrameLevel(metal:GetFrameLevel() + 2)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", CLOSE_X, CLOSE_Y)

	-- stats header
	f.type = text(f, "GameFontHighlightSmall", "LEFT")
	f.type:SetPoint("TOPLEFT", f, "TOPLEFT", STATS_X, STATS_Y - 8)
	local _
	_, f.games = column(f, STATS_COLUMNS[1], STATS_Y, GAMES, nil, STATS_VALUE_GAP)
	_, f.winLoss = column(f, STATS_COLUMNS[2], STATS_Y, WIN_LOSS, nil, STATS_VALUE_GAP)
	_, f.rank = column(f, STATS_COLUMNS[3], STATS_Y, RANK, nil, STATS_VALUE_GAP)
	_, f.side = column(f, STATS_COLUMNS[4], STATS_Y, ARENA_TEAM_RATING,
		"GameFontNormalSmall", STATS_VALUE_GAP)

	local line = f:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(line, "ui-character-info-scrollline-long")
	line:SetHeight(3)
	line:SetPoint("TOPLEFT", f, "TOPLEFT", HEADERS_X, SEPARATOR_Y)
	line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -HEADERS_X, SEPARATOR_Y)

	f.headers = {}
	local previous
	for n = 1, #HEADERS do
		previous = createHeader(f, n, previous)
		f.headers[n] = previous
	end
	f.rows = {}
	for n = 1, MAX_MEMBERS do
		f.rows[n] = createRow(f, n)
	end

	f.add = panelButton(f, ADDMEMBER_TEAM, ADD_W, ADD_H)
	f.add:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ADD_X, ADD_Y)
	f.add:SetScript("OnClick", function()
		StaticPopup_Show("ADD_TEAMMEMBER")
	end)
	f.add:SetScript("OnEnter", function(self)
		if GameTooltip_AddNewbieTip then
			GameTooltip_AddNewbieTip(self, ADDMEMBER, 1.0, 1.0, 1.0,
				NEWBIE_TOOLTIP_ADDTEAMMEMBER, 1)
		end
	end)
	f.add:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- week / season toggle: the spellbook arrow, its text on the left
	local toggle = CreateFrame("Button", "ForeverUIArenaTeamDetailsToggle", f)
	toggle:SetWidth(TOGGLE_SIZE)
	toggle:SetHeight(TOGGLE_SIZE)
	toggle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", TOGGLE_X, TOGGLE_Y)
	toggle:SetNormalTexture(ARROW .. "Up")
	toggle:SetPushedTexture(ARROW .. "Down")
	toggle:SetHighlightTexture(SQUARE_HOVER)
	local s = toggle:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
	end
	toggle.text = text(toggle, "GameFontNormalSmall", "RIGHT")
	toggle.text:SetWidth(180)
	toggle.text:SetPoint("RIGHT", toggle, "LEFT", 0, 0)
	toggle:SetScript("OnClick", function()
		f.season = not f.season or nil
		A.updateDetail()
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	f.toggle = toggle

	f:SetScript("OnShow", function()
		PlaySound("igSpellBookOpen")
	end)
	-- PVPTeamDetails_OnHide and PVPFrame_OnHide: leaving the tab closes the detail, which does
	-- not come back on return.
	f:SetScript("OnHide", function(self)
		if self.team then
			self.team = nil
			CloseArenaTeamRoster()
			syncClientFrame(nil)
			PlaySound("igSpellBookClose")
		end
		if self:IsShown() then
			self:Hide()
		end
		markCards()
	end)
	return f
end

-- PVPTeamDetails_Update
function A.updateDetail()
	local f = window
	if not f or not f.team then
		return
	end
	local id = f.team
	local e = readTeam(id)
	if not e.name then
		f:Hide()
		return
	end

	f.title:SetText(tostring(e.name) .. " |cffffffff"
		.. string.format(PVP_TEAMSIZE, e.size, e.size) .. "|r")
	f.rank:SetText(e.rank)
	f.side:SetText(e.side)

	local teamPlayed, wins
	if f.season then
		teamPlayed, wins = e.seasonPlayed or 0, e.seasonWins or 0
		f.type:SetText(string.upper(ARENA_THIS_SEASON))
		f.toggle.text:SetText(ARENA_THIS_WEEK_TOGGLE)
	else
		teamPlayed, wins = e.played or 0, e.wins or 0
		f.type:SetText(string.upper(ARENA_THIS_WEEK))
		f.toggle.text:SetText(ARENA_THIS_SEASON_TOGGLE)
	end
	f.games:SetText(teamPlayed)
	f.winLoss:SetText(tostring(wins) .. " - " .. tostring(teamPlayed - wins))

	local count = GetNumArenaTeamMembers(id, 1) or 0
	local selected = GetArenaTeamRosterSelection and GetArenaTeamRosterSelection(id)
	for n, l in ipairs(f.rows) do
		if n > count then
			l:Hide()
		else
			local name, rank, level, className, online, played, won, seasonPlayed,
				seasonWon, side = GetArenaTeamRosterInfo(id, n)
			local playedValue, wonValue = played or 0, won or 0
			if f.season then
				playedValue, wonValue = seasonPlayed or 0, seasonWon or 0
			end
			local pct = percentage(playedValue, teamPlayed)
			l.member = n
			l.pct = string.format("%d", pct) .. "%"
			l.name:SetText(name)
			l.className:SetText(className)
			l.played:SetText(playedValue)
			l.wins:SetText(wonValue)
			l.losses:SetText(playedValue - wonValue)
			l.side:SetText(side)

			-- white online, gold for the captain, gray offline
			local r, v, b = 0.5, 0.5, 0.5
			if online then
				if rank and rank > 0 then
					r, v, b = 1.0, 1.0, 1.0
				else
					r, v, b = 1.0, 0.82, 0.0
				end
			end
			for _, fs in ipairs({ l.name, l.className, l.played, l.wins, l.dash, l.losses, l.side }) do
				fs:SetTextColor(r, v, b)
			end
			-- PVPTeamDetails_Update tints the red over the text color
			if pct < 10 then
				l.played:SetVertexColor(1.0, 0, 0)
			else
				l.played:SetVertexColor(1.0, 1.0, 1.0)
			end

			l.selectedItem = (selected == n) or nil
			l.hover:SetAlpha(l.selectedItem and SELECTED_ALPHA or 0)
			l:Show()
		end
	end
end

-- PVPTeam_OnClick: opens a team's detail, or closes it if it is already open.
function A.toggleDetail(id)
	if not id or not window or not GetArenaTeam(id) then
		return
	end
	if window:IsShown() and window.team == id then
		window:Hide()
		return
	end
	if window.team and window.team ~= id then
		CloseArenaTeamRoster()
	end
	window.team = id
	syncClientFrame(id)
	ArenaTeamRoster(id)
	window:Show()
	A.updateDetail()
	markCards()
end

-- ------------------------------------------------------------ build

-- block: rank block of PvPTab.lua (win counter in block.progress); pane: the left pane
function A.build(block, pane)
	if maps or not block or not pane then
		return
	end
	host = pane

	-- Separator below the win counter, at its element size (384 x 8). With keepSize it had no
	-- size and took the whole atlas sheet.
	local separator = block:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(separator, ATLAS_SEPARATOR)
	separator:SetPoint("TOP", block.progress, "BOTTOM", 0, SEPARATOR_BELOW_COUNTER)
	A.separator = separator

	-- Arena points, centred below the separator.
	points = CreateFrame("Frame", "ForeverUIArenaPoints", block)
	points:SetHeight(ICON_H)
	points:SetFrameLevel(block:GetFrameLevel() + CARD_LEVEL)
	points:EnableMouse(true)
	points.tag = text(points, "GameFontHighlightSmall", "LEFT")
	points.tag:SetPoint("LEFT", points, "LEFT", 0, 0)
	points.tag:SetText(PVP_LABEL_ARENA)
	points.value = text(points, "GameFontNormal", "RIGHT")
	points.value:SetPoint("LEFT", points.tag, "RIGHT", POINTS_GAP, 0)
	points.icon = points:CreateTexture(nil, "ARTWORK")
	points.icon:SetTexture(POINTS_ICON)
	points.icon:SetWidth(ICON_W)
	points.icon:SetHeight(ICON_H)
	points.icon:SetPoint("LEFT", points.value, "RIGHT", ICON_GAP, 0)
	points:SetScript("OnEnter", function(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetText(ARENA_POINTS, 1.0, 1.0, 1.0)
		GameTooltip:AddLine(TOOLTIP_ARENA_POINTS, nil, nil, nil, 1)
		GameTooltip:Show()
	end)
	points:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Team cards, below the points.
	maps = {}
	for rank = 1, MAX_TEAMS do
		maps[rank] = createCard(block, rank)
	end
	-- stacked up from the pane bottom, centred
	for rank = MAX_TEAMS, 1, -1 do
		if rank == MAX_TEAMS then
			maps[rank]:SetPoint("BOTTOM", host, "BOTTOM", 0, CARDS_BOTTOM)
		else
			maps[rank]:SetPoint("BOTTOM", maps[rank + 1], "TOP", 0, CARD_GAP)
		end
	end

	-- Arena points centred between the separator and the first card: a mouse-less zone spans
	-- the gap and the row centres on it, keeping its own small area for the tooltip.
	local zone = CreateFrame("Frame", "ForeverUIArenaPointsZone", block)
	zone:SetPoint("TOP", separator, "BOTTOM", 0, 0)
	zone:SetPoint("BOTTOM", maps[1], "TOP", 0, 0)
	zone:SetWidth(CARD_W)
	points:SetPoint("CENTER", zone, "CENTER", 0, 0)

	offSeason = block:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	offSeason:SetJustifyH("LEFT")
	offSeason:SetWidth(CARD_W - 16)
	offSeason:SetPoint("TOP", points, "BOTTOM", 0, OFF_SEASON_BELOW_POINTS)
	offSeason:Hide()

	window = createWindow(block)
	A.update()
end

-- PVPFrame_OnEvent: ARENA_TEAM_UPDATE refreshes cards and detail (or closes it if the team
-- is gone); ARENA_TEAM_ROSTER_UPDATE with an argument asks for the roster again, without one
-- the roster is ready. PVPFrame already asks for PVPTeamDetails; we ask only if it is missing.
local listener = CreateFrame("Frame")
listener:RegisterEvent("ARENA_TEAM_UPDATE")
listener:RegisterEvent("ARENA_TEAM_ROSTER_UPDATE")
listener:RegisterEvent("HONOR_CURRENCY_UPDATE")
listener:SetScript("OnEvent", function(self, event, arg1)
	if not maps then
		return
	end
	if event == "ARENA_TEAM_ROSTER_UPDATE" then
		if arg1 then
			if window:IsShown() and window.team and not _G["PVPTeamDetails"] then
				ArenaTeamRoster(window.team)
			end
		else
			A.updateDetail()
			A.update()
		end
		return
	end
	A.update()
	if event == "ARENA_TEAM_UPDATE" and window:IsShown() then
		if window.team and not GetArenaTeam(window.team) then
			window:Hide()
		else
			A.updateDetail()
		end
	end
end)

-- /fui arena: what the client returns for the three team slots.
function ForeverUI.PvPArenaDebug()
	local say = function(t)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t)
	end
	say(string.format(L.PVPARENA_DEBUG_SEASON,
		tostring(GetCurrentArenaSeason and GetCurrentArenaSeason()),
		tostring(GetPreviousArenaSeason and GetPreviousArenaSeason()),
		tostring(GetArenaCurrency and GetArenaCurrency())))
	for i = 1, MAX_TEAMS do
		local e = readTeam(i)
		if e.name then
			say(string.format(L.PVPARENA_DEBUG_TEAM,
				i, e.name, e.size or 0, e.size or 0, tostring(e.side),
				tostring(e.wins), tostring(e.played), tostring(e.playerPlayed),
				tostring(e.seasonWins), tostring(e.seasonPlayed),
				tostring(e.edge), tostring(e.emblem)))
		else
			say(string.format(L.PVPARENA_DEBUG_NO_TEAM, i))
		end
	end
	if window then
		say(string.format(L.PVPARENA_DEBUG_DETAIL,
			tostring(window:IsShown()), tostring(window.team), tostring(window.season)))
	end
end
