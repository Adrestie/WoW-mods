-- ForeverUI: PvP tab of the character sheet (camelot PVPRankFrame.xml, pvprankframe.lua).
-- Left pane: rank title, honor stats, rank gauge and arena teams. Right pane: battlegrounds.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local L = ForeverUI.L

local SEASON_X, SEASON_Y = -46, -18
-- Left pane layout: rank title at the top, honor on two columns under the title line, then a
-- separator, the dial and the win counter.
-- Measured on image alpha (threshold 128, shadow ignored):
--   title line   ui-character-info-honor-levelbg, 350 x 62, solid on rows 53-58: it ends
--                4 px above its image bottom
--   ring         solid from row 31 of 201 (drawn at 209): it shows 6 px below the dial top
local BLOCK_Y = 0
local RANK_TOP = -12
local HONOR_BELOW_LINE = -2           -- 6 px below the solid line
local HONOR_W = 366
local HONOR_COLUMN = 173             -- (366 - 20) / 2
local HONOR_ROW_H, HONOR_GAP = 14, 3
local HONOR_SEPARATOR_Y = -4
local DIAL_BELOW_SEPARATOR = 0        -- the ring shows 6 px lower
local BLOCK_Y2 = -195
local SEASON_TITLE_Y = -20
-- Win counter, 5 px below the visible bottom of the gauge. The ring (230 x 201, drawn at
-- 235 x 209) is solid down to row 169, the rest is a fading shadow: its solid bottom is 5 px
-- above the dial bottom; the reward ring (54, solid down to row 49, at -1) is 4 px above.
-- Fixed height: it is empty without a rank, and what follows must not move up.
local PROGRESS_BELOW_DIAL = -1
local PROGRESS_H = 12
local LINE_Y = -10

local DIAL_SIZE = 154
local GLOW_W, GLOW_H = 275, 295
local BACKGROUND_W, BACKGROUND_H = 115, 115
local RING_W, RING_H = 235, 209
local RING_Y = -1
local BADGE_W, BADGE_H = 72, 84
local REWARD_Y = -1

local LINE_ATLAS = "ui-character-info-honor-levelbg"
local GLOW_ATLAS = "ui-character-info-honor-bar-bg-glow"
local RING_ATLAS = "ui-character-info-honor-bar-bg"
local ATLAS_BACKGROUND = "ui-character-info-honor-bar-bg-%s"
local FACTION_BADGE_ATLAS = "ui-character-info-honor-icon-%s"
local RANK_BADGE_ATLAS = "ui-character-info-honor-icon-%d"
-- Dishonored: the broken faction crest (tools/bake_dishonor.py) replaces the faction badge.
local BROKEN_CREST = "Interface\\ForeverUI\\pvpframe\\honor-dishonored-%s"
local REWARD_RING_ATLAS = "ui-character-info-honor-rewardring"
local LONG_SEPARATOR_ATLAS = "ui-character-info-scrollline-long"

-- Gauge. camelot uses a Cooldown with a custom swipe texture; 3.3.5 has no SetSwipeTexture and
-- the Cooldown swipe is shared by the whole game. Each dial quarter shows either the full ring
-- or a rotated half ring cut by the quarter rectangle (both baked by tools/bake_masks.py).
local GAUGE_FULL = "Interface\\ForeverUI\\PvP\\honorfill"
local GAUGE_HALF = "Interface\\ForeverUI\\PvP\\honorfillhalf"
local GAUGE_ORIGIN = 180        -- <Cooldown rotation="180">: starts at six o'clock
local GAUGE_DIRECTION = 1            -- 1: clockwise; -1: counterclockwise


local PANE_W = 398

local block, detail

-- Forward declarations: updateBlock, defined above, calls clampToPane; without them the names
-- would resolve to globals (nil).
local leftHost
local clampToPane

-- --------------------------------------------------------------- Data

local function faction()
	return (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
end

-- Rank names come from the client strings PVP_RANK_<index>_<faction01> (camelot
-- GetPVPRankText). Indices 1-4 are the negative ranks (Pariah, Outlaw, Exiled, Dishonored);
-- rank N is index N + 4. GetPVPRankInfo returns nothing on this server.
-- A player without rank is a civilian, not dishonored. "Civilian" is not a client string, so
-- it comes from the text table.
local UNRANKED_NAME = L.PVPTAB_CIVILIAN

local function rankName(index)
	if not index or index <= 0 then
		return nil
	end
	local faction01 = (faction() == "Alliance") and 1 or 0
	return _G["PVP_RANK_" .. tostring(index) .. "_" .. tostring(faction01)]
end

-- The rank comes from titles: mod-pvp-titles (AwardEarnedTitles) sets a CharTitles title for
-- each lifetime kill threshold and never sets the old rank counter, so UnitPVPRank stays 0.
-- Title ids (CharTitles.dbc), in rank order: 1-14 Alliance, 15-28 Horde. For these ids the bit
-- index equals the id, so IsTitleKnown takes them as is.
local FIRST_TITLE = { Alliance = 1, Horde = 15 }
local RANK_COUNT = 14

-- IsTitleKnown returns a number, and 0 is true in Lua: compare with 0, as
-- PaperDollFrame.lua does (IsTitleKnown(i) ~= 0).
local function isTitleKnown(identifier)
	if not IsTitleKnown then
		return false
	end
	local known = IsTitleKnown(identifier)
	return known ~= nil and known ~= false and known ~= 0
end

local function rankByTitles()
	local first = FIRST_TITLE[faction()] or FIRST_TITLE.Alliance
	for number = RANK_COUNT, 1, -1 do
		if isTitleKnown(first + number - 1) then
			return number
		end
	end
	return 0
end

-- Lifetime kills needed for each rank are server settings (mod_pvptitles.conf,
-- PvPTitles.Rank_1 to Rank_14) that no client API returns. mod-pvp-titles-ext whispers them on
-- the PVPTITLES addon prefix ("RANKS:k1,...,k14") at login and on "REQ".
-- Without a reply they stay nil: the tab shows the rank and kill count only, with no
-- threshold or gauge; inspection shows the faction badge without rank name.
local THRESHOLDS = nil

-- Dishonored state (mod-pvp-titles-ext "DISHONOR:..."): finish is its end in GetTime time,
-- nil outside the state. Shown as the negative rank Dishonored (PVP_RANK_4), with the time
-- left instead of the progress.
local DISHONOR = { finish = nil }
-- Shared with Buffs.lua, which shows it as a debuff; name() is the client's negative rank
-- string, in the client language.
DISHONOR.name = function() return rankName(4) or "" end
ForeverUI.Dishonor = DISHONOR

local function updateDebuffs()
	if ForeverUI.Buffs and ForeverUI.Buffs.update then
		ForeverUI.Buffs.update()
	end
end

-- Gauge fraction: lifetime wins between the threshold of rank number and the next one.
local function progressByWins(number, wins)
	if not THRESHOLDS then
		return 0          -- unknown thresholds: no gauge
	end
	local following = THRESHOLDS[number + 1]
	if not following then
		return 1          -- max rank: full gauge
	end
	local earned = (number > 0) and THRESHOLDS[number] or 0
	if following <= earned then
		return 0
	end
	local part = ((wins or 0) - earned) / (following - earned)
	if part < 0 then
		return 0
	elseif part > 1 then
		return 1
	end
	return part
end

-- Rank of another player, for Inspect.lua. Titles cannot be read for other units, but lifetime
-- kills can (GetInspectHonorData): the rank is the number of thresholds reached, as the server
-- module awards them. Unknown thresholds: nil. fac: "Alliance" or "Horde".
ForeverUI.PvPRanks = {
	byWins = function(wins)
		if not THRESHOLDS then
			return nil
		end
		local number = 0
		for i, threshold in ipairs(THRESHOLDS) do
			if (wins or 0) >= threshold then number = i end
		end
		return number
	end,
	name = function(number, fac)
		if not number or number <= 0 then return UNRANKED_NAME end
		local faction01 = (fac == "Alliance") and 1 or 0
		return _G["PVP_RANK_" .. tostring(number + 4) .. "_" .. tostring(faction01)]
	end,
	badgeRank = RANK_BADGE_ATLAS,
	badgeFaction = FACTION_BADGE_ATLAS,
}

-- Player rank: counter index, name, number, gauge progress, lifetime wins and next threshold.
local function readRank()
	local index = UnitPVPRank and UnitPVPRank("player") or 0
	local name, number
	if index and index > 0 and GetPVPRankInfo then
		name, number = GetPVPRankInfo(index, "player")
	end

	if not number or number <= 0 then
		number = (index > 4) and (index - 4) or 0
	end

	-- The server never sets the rank counter: use the titles.
	if number <= 0 then
		number = rankByTitles()
	end

	-- Name, three cases:
	--   number > 0       real rank: index = number + 4
	--   index 1 to 4     negative rank (Pariah, Outlaw, Exiled, Dishonored), named by its index
	--   otherwise        no rank: civilian
	if not name then
		if number > 0 then
			name = rankName(number + 4)
		elseif index and index >= 1 and index <= 4 then
			name = rankName(index)
		else
			name = UNRANKED_NAME
		end
	end

	local wins = 0
	if GetPVPLifetimeStats then
		wins = GetPVPLifetimeStats() or 0
	end

	local progress = 0
	if GetPVPRankProgress then
		progress = GetPVPRankProgress() or 0
	end
	if not progress or progress <= 0 then
		progress = progressByWins(number, wins)
	end

	-- Dishonored: negative rank, no gauge, time left.
	local rest = DISHONOR.finish and (DISHONOR.finish - GetTime())
	if rest and rest > 0 then
		return {
			index = 4,
			name = rankName(4),
			number = 0,
			progress = 0,
			wins = wins,
			dishonored = rest,
		}
	end

	return {
		index = index,
		name = name,
		number = number,
		progress = progress,
		wins = wins,
		threshold = THRESHOLDS and THRESHOLDS[number + 1],
	}
end

-- Honor stats, still provided by 3.3.5.
local function readHonor()
	local lifetime, dishonor, highestRank = 0, 0, 0
	if GetPVPLifetimeStats then
		lifetime, dishonor, highestRank = GetPVPLifetimeStats()
	end
	local day, todayPoints = 0, 0
	if GetPVPSessionStats then
		day, todayPoints = GetPVPSessionStats()
	end
	local yesterday, yesterdayPoints = 0, 0
	if GetPVPYesterdayStats then
		yesterday, yesterdayPoints = GetPVPYesterdayStats()
	end
	local current = GetHonorCurrency and GetHonorCurrency() or 0

	return {
		lifetime = lifetime or 0,
		dishonor = dishonor or 0,
		highestRank = highestRank or 0,
		day = day or 0,
		todayPoints = todayPoints or 0,
		yesterday = yesterday or 0,
		yesterdayPoints = yesterdayPoints or 0,
		current = current or 0,
	}
end

-- ----------------------------------------------------------------- Gauge

-- Dial quarters {u1, u2, v1, v2}, clockwise from twelve o'clock, as fractions of the dial:
-- u to the right, v down (texture coordinates).
local QUADRANTS = {
	{ 0.5, 1.0, 0.0, 0.5 },   -- top right: 0 to 90 degrees
	{ 0.5, 1.0, 0.5, 1.0 },   -- bottom right: 90 to 180
	{ 0.0, 0.5, 0.5, 1.0 },   -- bottom left: 180 to 270
	{ 0.0, 0.5, 0.0, 0.5 },   -- top left: 270 to 360
}

-- Where to read dial point (u, v) in a texture rotated clockwise by the angle (cosine, sine).
-- 8-argument SetTexCoord does not move the corners on screen, it picks the image point each
-- one shows: rotating the image means rotating the lookup the other way around the center.
-- Points outside [0, 1] repeat the empty edge texel, so the corners stay transparent.
local function rotate(u, v, cosine, sine)
	local du, dv = u - 0.5, v - 0.5
	return 0.5 + du * cosine + dv * sine, 0.5 - du * sine + dv * cosine
end

-- Anchors a quarter texture on the dial; mirrored when the gauge runs counterclockwise.
local function placeQuarter(tex, dial, u1, u2, v1, v2)
	if GAUGE_DIRECTION < 0 then
		u1, u2 = 1 - u2, 1 - u1
	end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", dial, "TOPLEFT", u1 * DIAL_SIZE, -v1 * DIAL_SIZE)
	tex:SetPoint("BOTTOMRIGHT", dial, "TOPLEFT", u2 * DIAL_SIZE, -v2 * DIAL_SIZE)
end

-- Creates the four quarters of a dial, each with a full-ring texture and a half-ring arc.
local function buildGauge(dial)
	local quarters = {}
	for i = 1, 4 do
		local quarter = QUADRANTS[i]
		local u1, u2, v1, v2 = quarter[1], quarter[2], quarter[3], quarter[4]
		local q = { u1 = u1, u2 = u2, v1 = v1, v2 = v2 }

		-- Angle where this quarter starts, measured from the gauge origin.
		q.origin = (90 * (i - 1) - GAUGE_ORIGIN) % 360

		-- Passed quarter: the full ring, read on this quarter.
		q.full = dial:CreateTexture(nil, "ARTWORK")
		q.full:SetTexture(GAUGE_FULL)
		q.full:SetTexCoord(u1, u2, v1, v2)
		placeQuarter(q.full, dial, u1, u2, v1, v2)
		q.full:Hide()

		-- Quarter where the gauge stops: the rotated half ring.
		q.arc = dial:CreateTexture(nil, "ARTWORK")
		q.arc:SetTexture(GAUGE_HALF)
		placeQuarter(q.arc, dial, u1, u2, v1, v2)
		q.arc:Hide()

		quarters[i] = q
	end
	return quarters
end

-- Shows the quarters of a gauge (buildGauge) for a fraction from 0 to 1.
local function updateQuarters(quarters, fraction)
	fraction = fraction or 0
	if fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end
	local traveled = fraction * 360

	for i = 1, 4 do
		local q = quarters[i]
		if traveled >= q.origin + 90 then
			q.arc:Hide()
			q.full:Show()
		elseif traveled <= q.origin then
			q.arc:Hide()
			q.full:Hide()
		else
			q.full:Hide()

			-- The half ring covers the 180 degrees that end at its rotation angle. Rotate it so they end
			-- at the gauge head (GAUGE_ORIGIN + traveled), minus the half turn it already has.
			local phi = math.rad(GAUGE_ORIGIN + traveled - 360)
			local cosine, sine = math.cos(phi), math.sin(phi)
			local tlu, tlv = rotate(q.u1, q.v1, cosine, sine)
			local blu, blv = rotate(q.u1, q.v2, cosine, sine)
			local tru, trv = rotate(q.u2, q.v1, cosine, sine)
			local bru, brv = rotate(q.u2, q.v2, cosine, sine)
			q.arc:SetTexCoord(tlu, tlv, blu, blv, tru, trv, bru, brv)
			q.arc:Show()
		end
	end
end

local function updateGauge(fraction)
	if not block or not block.gauge then
		return
	end
	updateQuarters(block.gauge, fraction)
end
ForeverUI.PvPGauge = updateGauge

-- --------------------------------------------------------------- Display

local function placeBadge(rank)
	if not block then
		return
	end

	-- Dishonored: the broken faction crest, drawn on the badge silhouette so it blends into the
	-- dial like the badge.
	if rank.dishonored then
		block.badge:SetTexture(string.format(BROKEN_CREST, string.lower(faction())))
		block.badge:SetTexCoord(0, 1, 0, 1)
		block.badge:SetWidth(BADGE_W)
		block.badge:SetHeight(BADGE_H)
		return
	end

	-- camelot UpdateFactionBadge: faction badge without rank, rank badge otherwise.
	local installed = false
	if rank.number and rank.number > 0 then
		installed = ForeverUI.SetAtlas(block.badge,
			string.format(RANK_BADGE_ATLAS, rank.number), true)
	end
	if not installed then
		ForeverUI.SetAtlas(block.badge,
			string.format(FACTION_BADGE_ATLAS, string.lower(faction())), true)
	end
	block.badge:SetWidth(BADGE_W)
	block.badge:SetHeight(BADGE_H)
end

local function updateBlock()
	if not block then
		return
	end

	clampToPane()

	local rank = readRank()

	-- No season line: the arena teams use its space.
	block.season:SetText("")
	block.season:Hide()

	-- Rank title at the top; the rank number only in the reward ring (camelot also writes
	-- PVP_RANK_NUMBER_AND_TITLE at the top).
	block.rank:SetText(rank.name or "")

	-- Honor labels from the client GlobalStrings, as WotLK PVPHonor: HONOR_POINTS,
	-- HONORABLE_KILLS, HONOR_TODAY, HONOR_YESTERDAY. LIFETIME_HONORABLE_KILLS, TODAY and
	-- YESTERDAY do not exist in 3.3.5.
	local honor = readHonor()
	local cells = {
		{ HONOR_POINTS, honor.current },
		{ HONORABLE_KILLS, honor.lifetime },
		{ HONOR_TODAY,
		  tostring(honor.day) .. " (" .. tostring(honor.todayPoints) .. ")" },
		{ HONOR_YESTERDAY,
		  tostring(honor.yesterday) .. " (" .. tostring(honor.yesterdayPoints) .. ")" },
	}
	for n, c in ipairs(cells) do
		block.honor.cells[n].label:SetText(c[1])
		block.honor.cells[n].value:SetText(tostring(c[2]))
	end

	placeBadge(rank)

	updateGauge(rank.progress)

	-- Progress as numbers, like camelot CurrentRankProgressField (PVP_RANK_CURRENT_PROGRESS does
	-- not exist in 3.3.5): lifetime kills / next threshold, the values mod-pvp-titles compares.
	-- At max rank or with unknown thresholds, the kill count alone; dishonored, the time left.
	if rank.dishonored then
		block.progress:SetText(string.format(L.PVPTAB_DISHONORED_LEFT,
			SecondsToTime(rank.dishonored)))
	elseif rank.threshold then
		block.progress:SetText(string.format("%d / %d", rank.wins or 0,
			rank.threshold))
	else
		block.progress:SetText(tostring(rank.wins or 0))
	end

	-- No rank, no reward ring: an empty gold ring looks like a bug. The dial keeps its glow,
	-- faction background and badge.
	if rank.number and rank.number > 0 then
		block.number:SetText(tostring(rank.number))
		block.reward:Show()
		block.number:Show()
	else
		block.number:SetText("")
		block.reward:Hide()
		block.number:Hide()
	end

	-- Arena teams below the rank (PvPArena.lua).
	if ForeverUI.PvPArena then
		ForeverUI.PvPArena.update()
	end
end
ForeverUI.PvPUpdate = updateBlock

-- ---------------------------------------------------------- Build

-- Hides the whole client PvP screen on every pass: PVPParentFrame regions and child frames
-- (tabs, arena team frames, off-season banner and their art).
local function suppressClientScreen()
	local frame = _G["PVPParentFrame"]
	if not frame then
		return
	end

	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.Hide then
			region:Hide()
		end
	end
	if frame.GetChildren then
		for _, childFrame in ipairs({ frame:GetChildren() }) do
			if childFrame ~= block and childFrame.Hide then
				childFrame:Hide()
			end
		end
	end
end

-- PVPParentFrame is registered in UIPanelWindows (UIParent.lua). The panel system then
-- re-anchors it to UIParent (UpdateUIPanelPositions) as an invisible 384 x 512 frame that
-- takes the mouse clicks of everything below it, such as the side tabs. Removing it from the
-- table makes it plain pane content.
local function detachFromPanelSystem(frame)
	if UIPanelWindows then
		UIPanelWindows["PVPParentFrame"] = nil
	end
	-- If the panel system already manages it, it keeps its slot until HideUIPanel.
	if HideUIPanel and frame.IsShown and frame:IsShown() then
		HideUIPanel(frame)
	end
end

-- Pins the frame to the pane on every pass, in case another system re-anchors it.
clampToPane = function()
	local frame = _G["PVPParentFrame"]
	local host = leftHost
	if not frame or not host then
		return
	end
	if frame:GetParent() ~= host then
		frame:SetParent(host)
	end
	if frame.SetToplevel then
		frame:SetToplevel(false)
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
end

local function build(host)
	local frame = _G["PVPParentFrame"]
	if not frame or not host then
		return nil, {}
	end

	leftHost = host
	detachFromPanelSystem(frame)
	clampToPane()

	if block then
		suppressClientScreen()
		updateBlock()
		return nil, { frame }
	end

	local width = host:GetWidth() or 0
	if width < 100 then
		width = PANE_W
	end

	-- Main block: from the pane top (BLOCK_Y) down to BLOCK_Y2.
	block = CreateFrame("Frame", "ForeverUIPvPMain", frame)
	block:SetPoint("TOPLEFT", host, "TOPLEFT", 0, BLOCK_Y)
	block:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, BLOCK_Y2)

	-- Season end countdown: the line exists but stays empty (no C_SeasonInfo in 3.3.5).
	block.timer = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	block.timer:SetJustifyH("RIGHT")
	block.timer:SetPoint("TOPRIGHT", host, "TOPRIGHT", SEASON_X, SEASON_Y)

	-- GameFontNormalMed2 does not exist in 3.3.5.
	block.season = block:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	block.season:SetJustifyH("CENTER")
	block.season:SetPoint("TOP", block, "TOP", 0, SEASON_TITLE_Y)

	block.rank = block:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	block.rank:SetJustifyH("CENTER")
	block.rank:SetPoint("TOP", block, "TOP", 0, RANK_TOP)

	block.row = block:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(block.row, LINE_ATLAS)
	block.row:SetPoint("BOTTOM", block.rank, "BOTTOM", 0, LINE_Y)

	block.progress = block:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	block.progress:SetJustifyH("CENTER")
	block.progress:SetHeight(PROGRESS_H)

	-- Dial: glow, faction background, ring, gauge and badge, in this draw order.
	local dial = CreateFrame("Frame", "ForeverUIPvPDial", block)
	dial:SetWidth(DIAL_SIZE)
	dial:SetHeight(DIAL_SIZE)
	dial:SetFrameLevel(block:GetFrameLevel() + 1)
	block.dial = dial

	-- Honor on two columns, in a frame above the dial: the dial glow spreads upward and would
	-- veil the text.
	local honor = CreateFrame("Frame", "ForeverUIPvPHonor", block)
	honor:SetWidth(HONOR_W)
	honor:SetHeight(2 * HONOR_ROW_H + HONOR_GAP)
	honor:SetPoint("TOP", block.row, "BOTTOM", 0, HONOR_BELOW_LINE)
	honor:SetFrameLevel(block:GetFrameLevel() + 2)
	block.honor = honor
	honor.cells = {}
	for n = 1, 4 do
		local column, rowLine = (n - 1) % 2, math.floor((n - 1) / 2)
		local x = column * (HONOR_W - HONOR_COLUMN)
		local y = -rowLine * (HONOR_ROW_H + HONOR_GAP)
		local label = honor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		label:SetJustifyH("LEFT")
		label:SetPoint("TOPLEFT", honor, "TOPLEFT", x, y)
		local value = honor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		value:SetJustifyH("RIGHT")
		value:SetPoint("TOPRIGHT", honor, "TOPLEFT", x + HONOR_COLUMN, y)
		honor.cells[n] = { label = label, value = value }
	end

	local separator = honor:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(separator, LONG_SEPARATOR_ATLAS)
	separator:SetPoint("TOP", honor, "BOTTOM", 0, HONOR_SEPARATOR_Y)
	block.honorSeparator = separator

	dial:SetPoint("TOP", separator, "BOTTOM", 0, DIAL_BELOW_SEPARATOR)
	block.progress:SetPoint("TOP", dial, "BOTTOM", 0, PROGRESS_BELOW_DIAL)

	local glow = dial:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(glow, GLOW_ATLAS, true)
	glow:SetWidth(GLOW_W)
	glow:SetHeight(GLOW_H)
	glow:SetPoint("CENTER", dial, "CENTER", 0, 0)

	local background = dial:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, string.format(ATLAS_BACKGROUND, string.lower(faction())), true)
	background:SetWidth(BACKGROUND_W)
	background:SetHeight(BACKGROUND_H)
	background:SetPoint("CENTER", dial, "CENTER", 0, 0)
	block.background = background

	local ring = dial:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(ring, RING_ATLAS, true)
	ring:SetWidth(RING_W)
	ring:SetHeight(RING_H)
	ring:SetPoint("CENTER", dial, "CENTER", 0, RING_Y)

	-- Gauge quarters, created here to draw above the ring and below the badge.
	block.gauge = buildGauge(dial)

	block.badge = dial:CreateTexture(nil, "ARTWORK")
	block.badge:SetPoint("CENTER", dial, "CENTER", 0, 0)

	-- Reward ring at the dial bottom, holding the rank number.
	local reward = dial:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(reward, REWARD_RING_ATLAS)
	reward:SetPoint("BOTTOM", dial, "BOTTOM", 0, REWARD_Y)
	block.reward = reward

	block.number = dial:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	block.number:SetPoint("CENTER", reward, "CENTER", 0, 0)
	block.number:SetJustifyH("CENTER")

	-- Arena teams and arena points at the bottom of the pane (PvPArena.lua).
	if ForeverUI.PvPArena then
		ForeverUI.PvPArena.build(block, host)
	end

	suppressClientScreen()
	updateBlock()
	return nil, { frame }
end

-- Right pane: battlegrounds (PvPBattlegrounds.lua).
local function buildDetail(host)
	if detail then
		return detail, {}
	end
	detail = CreateFrame("Frame", "ForeverUIPvPDetail", host)
	detail:SetAllPoints(host)
	if ForeverUI.PvPBattlegrounds then
		ForeverUI.PvPBattlegrounds.build(detail)
	end
	return detail, {}
end

ForeverUI.PvPTab = { Build = build, BuildRight = buildDetail }

-- /fui pvp: prints what the rank functions, titles and honor APIs return on this server.
-- test: optional gauge fraction to display.
function ForeverUI.PvPDebug(test)
	local say = function(text)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
	end

	-- Test value: /fui pvp 0.35 shows the gauge at 35 % until the next rank event.
	if test then
		updateGauge(test)
		say(string.format(L.PVPTAB_DEBUG_TEST_VALUE,
			test * 100))
	else
		-- Without a value, reset the gauge to the real progress.
		updateGauge(readRank().progress)
	end

	local index = UnitPVPRank and UnitPVPRank("player")
	local name, number
	if index and GetPVPRankInfo then
		name, number = GetPVPRankInfo(index, "player")
	end
	say(string.format(L.PVPTAB_DEBUG_RANK_COUNTER,
		tostring(index), tostring(name), tostring(number),
		tostring(GetPVPRankProgress and GetPVPRankProgress())))

	-- Titles, where the server stores the rank.
	local first = FIRST_TITLE[faction()] or FIRST_TITLE.Alliance
	local knownItems = {}
	for number2 = 1, RANK_COUNT do
		if isTitleKnown(first + number2 - 1) then
			knownItems[#knownItems + 1] = tostring(number2)
		end
	end
	say(string.format(L.PVPTAB_DEBUG_RANK_TITLES,
		faction(), first, first + RANK_COUNT - 1,
		(#knownItems > 0) and table.concat(knownItems, " ") or L.PVPTAB_DEBUG_NONE))

	local r = readRank()
	say(string.format(L.PVPTAB_DEBUG_KEPT,
		tostring(r.number), tostring(r.name), r.wins or 0,
		tostring(r.threshold), r.progress or 0))

	local h = readHonor()
	say(string.format(L.PVPTAB_DEBUG_HONOR,
		h.current, h.lifetime, h.highestRank, h.day, h.todayPoints, h.yesterday, h.yesterdayPoints))
	say(string.format(L.PVPTAB_DEBUG_SEASON,
		tostring(GetCurrentArenaSeason and GetCurrentArenaSeason()), faction()))

	-- Gauge state per quarter: full, arc or empty.
	if block and block.gauge then
		local states = {}
		for i = 1, 4 do
			local q = block.gauge[i]
			local state = L.PVPTAB_DEBUG_QUARTER_EMPTY
			if q.full:IsShown() then
				state = L.PVPTAB_DEBUG_QUARTER_FULL
			elseif q.arc:IsShown() then
				state = L.PVPTAB_DEBUG_QUARTER_ARC
			end
			states[i] = string.format("%d(%d)=%s", i, q.origin, state)
		end
		say(string.format(L.PVPTAB_DEBUG_GAUGE, tostring(GAUGE_ORIGIN),
			tostring(GAUGE_DIRECTION), table.concat(states, " ")))
	else
		say(L.PVPTAB_DEBUG_GAUGE_NOT_BUILT)
	end
end

-- The client redraws its screen in PVPFrame_Update: run after it.
if hooksecurefunc and type(_G["PVPFrame_Update"]) == "function" then
	hooksecurefunc("PVPFrame_Update", function()
		suppressClientScreen()
		updateBlock()
	end)
end

-- Rank updates: KNOWN_TITLES_UPDATE announces a new rank title, PLAYER_PVP_KILLS_CHANGED moves
-- the gauge on each kill.
local listener = CreateFrame("Frame")
listener:RegisterEvent("KNOWN_TITLES_UPDATE")
listener:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
listener:RegisterEvent("PLAYER_PVP_RANK_CHANGED")
listener:RegisterEvent("HONOR_CURRENCY_UPDATE")
listener:SetScript("OnEvent", function()
	if block then
		updateBlock()
	end
end)

-- Server channel (mod-pvp-titles-ext): addon whispers to the player.
--   RANKS:k1,...,k14                       lifetime kills for each rank
--   DISHONOR:left,victims,required,window  seconds left (0: not dishonored)
-- Requested again on each world entry: the login message can arrive before the UI, and
-- /reload loses it. Only whispers from the player himself are accepted.
local SERVER_PREFIX = "PVPTITLES"

-- Civilian mark in unit tooltips. CREATURE_FLAG_EXTRA_CIVILIAN is server data, missing from
-- the 3.3.5 creature query reply (CreatureTemplate::InitializeQueryData). The module answers:
--   CIV:<entry>          whispered to self
--   CIV:<entry>:<0|1>    the reply
-- The flag belongs to the creature template, so each entry is asked once per session.
-- Nothing is asked when the server sent no thresholds (module missing).
local CIVILIANS = {} -- entry -> true, false or "pending"

-- Creature entry from the GUID: 0xF130 (creature) or 0xF150 (vehicle), six hex digits of
-- entry, then the counter (ObjectGuid: counter | entry << 24 | high << 48). Players and pets
-- have none.
local function creatureEntry(unit)
	local x = unit and string.match(UnitGUID(unit) or "", "^0x[Ff]1[35]0(%x%x%x%x%x%x)")
	return x and tonumber(x, 16)
end

local function markCivilian(tooltipFrame)
	tooltipFrame:AddLine(L.PVPTAB_TOOLTIP_CIVILIAN, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	tooltipFrame:Show()
end

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
	local _, unit = self:GetUnit()
	local entry = creatureEntry(unit)
	if not entry then
		return
	end
	if CIVILIANS[entry] == true then
		markCivilian(self)
	elseif CIVILIANS[entry] == nil and THRESHOLDS then
		CIVILIANS[entry] = "pending"
		SendAddonMessage(SERVER_PREFIX, "CIV:" .. entry, "WHISPER", UnitName("player"))
	end
end)

-- The reply arrives after the tooltip is built: add the line if it still shows this creature.
local function onCivilianReply(entry, civilian)
	CIVILIANS[entry] = civilian
	if civilian and GameTooltip:IsShown() then
		local _, unit = GameTooltip:GetUnit()
		if creatureEntry(unit) == entry then
			markCivilian(GameTooltip)
		end
	end
end

local channel = CreateFrame("Frame")
channel:RegisterEvent("PLAYER_ENTERING_WORLD")
channel:RegisterEvent("CHAT_MSG_ADDON")
channel:SetScript("OnEvent", function(_, event, prefix, message, distribution, sender)
	if event == "PLAYER_ENTERING_WORLD" then
		SendAddonMessage(SERVER_PREFIX, "REQ", "WHISPER", UnitName("player"))
		return
	end
	if prefix ~= SERVER_PREFIX or distribution ~= "WHISPER" or sender ~= UnitName("player") then
		return
	end
	local entry, civilian = string.match(message or "", "^CIV:(%d+):([01])$")
	if entry then
		onCivilianReply(tonumber(entry), civilian == "1")
		return
	end
	local ranks = string.match(message or "", "^RANKS:(.+)$")
	if ranks then
		local parsed = {}
		for n in string.gmatch(ranks, "%d+") do
			parsed[#parsed + 1] = tonumber(n)
		end
		if #parsed == 14 then
			THRESHOLDS = parsed
		end
	end
	local rest = tonumber(string.match(message or "", "^DISHONOR:(%d+)") or "")
	if rest then
		DISHONOR.finish = (rest > 0) and (GetTime() + rest) or nil
		updateDebuffs()
	end
	if block then
		updateBlock()
	end
	if ForeverUI.Inspection and ForeverUI.Inspection.UpdatePvP then
		ForeverUI.Inspection.UpdatePvP()
	end
end)

-- Dishonored countdown, updated every second while the sheet is open; the rank returns at the
-- end.
local elapsed = 0
channel:SetScript("OnUpdate", function(_, e)
	if not DISHONOR.finish then
		return
	end
	elapsed = elapsed + e
	if elapsed < 1 then
		return
	end
	elapsed = 0
	local rest = DISHONOR.finish - GetTime()
	if rest <= 0 then
		DISHONOR.finish = nil
		updateDebuffs()
		if block then
			updateBlock()
		end
	elseif block and block:IsVisible() then
		block.progress:SetText(string.format(L.PVPTAB_DISHONORED_LEFT, SecondsToTime(rest)))
	end
end)
