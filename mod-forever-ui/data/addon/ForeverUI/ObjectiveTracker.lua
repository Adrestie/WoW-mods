-- Camelot's quest and achievement tracker on the WotLK WatchFrame (docs/SUIVI_DES_QUETES.md).
-- WatchFrame, its events and CVars, VISIBLE_WATCHES, WatchFrameItem<n> and the handler API stay;
-- only the three WotLK display handlers are replaced by camelot's two modules.
-- Missing from 3.3.5, so absent here: Focus tracking, progress bars, automatic quest popups.

ForeverUI = ForeverUI or {}

local T = {}
ForeverUI.ObjectiveTracker = T
local L = ForeverUI.L

local G = {
	width = 260, headerH = 32, headerTextX = 7, headerTextL = 208,
	buttonW = 18, buttonH = 19, buttonX = -1, filterX = -2,
	modulesTop = 38, rowsBottom = 12,
	moduleHeaderH = 26, moduleCountedHeader = 25, moduleTextL = 200, moduleButtonSide = 16, moduleButtonX = 1,
	blockX = 20, firstBlockY = -10, blockY = -10, rowGap = 4,
	itemSide = 26, itemFrame = 42, rightGap = 2,
	checkMark = 16, checkMarkX = -10, checkMarkY = 2,
	poiX = -17, poiY = -5,
	rowGlowL = 180, headerGlowL = 240,
	timerW = 192, timerH = 20, barW = 128, barH = 10, barX = -4,
	maxCriteria = 5,
	-- default place: camelot EditModePresetLayouts, ObjectiveTracker system,
	-- TOPRIGHT of UIParent at (-110, -275)
	defaultX = -110, defaultY = -275, minHeight = 140,
}

-- OBJECTIVE_TRACKER_COLOR, values from camelot's GlobalColor.db2
local COLOR = {
	normal = { 0.8, 0.8, 0.8 }, normalHover = { 1, 1, 1 },
	failed = { 0.8, 0.098, 0.098 }, failedHover = { 1, 0.125, 0.125 },
	header = { 0.749, 0.612, 0 }, headerHover = { 1, 0.824, 0 },
	finished = { 0.6, 0.6, 0.6 },
	title = { 1, 0.824, 0 },                        -- NORMAL_FONT_COLOR
	bar = { 0.26, 0.42, 1 }, barBackground = { 0.04, 0.07, 0.18 },
}
COLOR.normal.inverse = COLOR.normalHover
COLOR.normalHover.inverse = COLOR.normal
COLOR.failed.inverse = COLOR.failedHover
COLOR.failedHover.inverse = COLOR.failed

-- 3.3.5 strings when it has them, camelot's otherwise (Textes_<locale>.lua)
local TEXT = {
	all = L.OBJECTIVETRACKER_ALL_OBJECTIVES, -- TRACKER_ALL_OBJECTIVES
	quests = QUESTS_LABEL,                   -- TRACKER_HEADER_QUESTS (3.3.5: QUESTS_LABEL)
	achievements = ACHIEVEMENTS,               -- TRACKER_HEADER_ACHIEVEMENTS (3.3.5: ACHIEVEMENTS)
	ready = L.OBJECTIVETRACKER_READY,         -- QUEST_WATCH_QUEST_READY
	viewPage = OBJECTIVES_VIEW_IN_QUESTLOG,  -- OBJECTIVES_VIEW_IN_QUESTLOG (in 3.3.5)
	viewMap = L.OBJECTIVETRACKER_OPEN_MAP, -- OBJECTIVES_SHOW_QUEST_MAP
	untrack = L.OBJECTIVETRACKER_UNTRACK, -- OBJECTIVES_STOP_TRACKING
	shareInChat = L.OBJECTIVETRACKER_SHARE_IN_CHAT, -- SHARE_IN_CHAT
	abandonQuest = ABANDON_QUEST_ABBREV,       -- ABANDON_QUEST_ABBREV (in 3.3.5)
	viewAchievement = OBJECTIVES_VIEW_ACHIEVEMENT, -- OBJECTIVES_VIEW_ACHIEVEMENT (in 3.3.5)
	minutes = "%.2d:%.2d",                    -- MINUTES_SECONDS
	hours = "%.2d:%.2d:%.2d",                -- HOURS_MINUTES_SECONDS
}

local FONT = "Fonts\\FRIZQT__.TTF"

local function color(fs, c)
	fs:SetTextColor(c[1], c[2], c[3])
	fs.color = c
end

-- ObjectiveTrackerLineFont (12) and ObjectiveTrackerHeaderFont (14), black shadow (1, -1)
local function font(fs, size)
	fs:SetFont(FONT, size)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
end

local function settings()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.tracking = ForeverUIDB.tracking or {}
	ForeverUIDB.tracking.collapsedModules = ForeverUIDB.tracking.collapsedModules or {}
	return ForeverUIDB.tracking
end

-- camelot SecondsToClock
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return format(TEXT.hours, h, m, s)
	end
	return format(TEXT.minutes, m, s)
end

-- ---------- Animations
-- One OnUpdate plays every running step: a delay, a duration, and a function that receives
-- the progress from 0 to 1. 3.3.5 animation groups lack fromAlpha / toAlpha and
-- setToFinalAlpha, so camelot's animations are replayed by hand with its timings.
local A = { steps = {} }
A.frame = CreateFrame("Frame")
A.frame:Hide()
A.frame:SetScript("OnUpdate", function(self, elapsed)
	local remaining = 0
	for key, e in pairs(A.steps) do
		e.t = e.t + elapsed
		if e.t >= e.delay then
			local p = (e.duration > 0) and math.min(1, (e.t - e.delay) / e.duration) or 1
			e.fn(p)
			if p >= 1 then
				A.steps[key] = nil
				if e.finish then e.finish() end
			else
				remaining = remaining + 1
			end
		else
			remaining = remaining + 1
		end
	end
	if remaining == 0 then self:Hide() end
end)

-- key: { object, name }, a step with the same key replaces the running one;
-- fn(progress) runs each frame; finish: called once done
local function play(key, delay, duration, fn, finish)
	key = tostring(key[1]) .. key[2]
	A.steps[key] = { t = 0, delay = delay, duration = duration, fn = fn, finish = finish }
	A.frame:Show()
end
T.play = play

-- smoothing="OUT"
local function easeOut(p) return 1 - (1 - p) * (1 - p) end

-- ---------- Buttons
-- atlasButton: l, h: size; normal, pressed, hover: atlas names
local function atlasButton(parent, l, h, normal, pressed, hover)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(l)
	b:SetHeight(h)
	local e = ForeverUI.AtlasEntry(normal)
	b:SetNormalTexture(e and e[1] or "")
	ForeverUI.SetAtlas(b:GetNormalTexture(), normal, true)
	b:GetNormalTexture():SetAllPoints(b)
	b:SetPushedTexture(e and e[1] or "")
	ForeverUI.SetAtlas(b:GetPushedTexture(), pressed, true)
	b:GetPushedTexture():SetAllPoints(b)
	b:SetHighlightTexture(e and e[1] or "")
	local s = b:GetHighlightTexture()
	ForeverUI.SetAtlas(s, hover, true)
	s:SetAllPoints(b)
	s:SetBlendMode("ADD")
	return b
end

local function buttonStates(b, normal, pressed)
	ForeverUI.SetAtlas(b:GetNormalTexture(), normal, true)
	ForeverUI.SetAtlas(b:GetPushedTexture(), pressed, true)
end

-- opens a dropdown through the world map's menu helper
local function menu(anchor, list)
	if ForeverUI.WorldMap and ForeverUI.WorldMap.openMenu then
		ForeverUI.WorldMap.openMenu(anchor, list)
	end
end

-- ---------- Main header
-- ObjectiveTrackerContainerHeaderTemplate, on WatchFrame
local function createHeader()
	local h = CreateFrame("Frame", "ForeverUIObjectiveTrackerHeader", WatchFrame)
	h:SetWidth(G.width)
	h:SetHeight(G.headerH)
	h:SetPoint("TOPLEFT", WatchFrame, "TOPLEFT", 0, 0)
	local background = h:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "ui-questtracker-primary-objective-header")
	background:SetPoint("CENTER", h, "CENTER", 0, 0)
	h.background = background
	local text = h:CreateFontString(nil, "ARTWORK")
	font(text, 14)
	color(text, COLOR.title)
	text:SetWidth(G.headerTextL)
	text:SetJustifyV("MIDDLE")
	text:SetPoint("LEFT", h, "LEFT", G.headerTextX, 0)
	text:SetText(TEXT.all)
	h.text = text

	local shrink = atlasButton(h, G.buttonW, G.buttonH, "ui-questtrackerbutton-collapse-all",
		"ui-questtrackerbutton-collapse-all-pressed", "ui-questtrackerbutton-red-highlight")
	shrink:SetPoint("RIGHT", h, "RIGHT", G.buttonX, 0)
	-- WatchFrame_CollapseExpandButton_OnClick, with camelot's sound
	shrink:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		if WatchFrame.collapsed then
			WatchFrame.userCollapsed = nil
			WatchFrame_Expand(WatchFrame)
		else
			WatchFrame.userCollapsed = true
			WatchFrame_Collapse(WatchFrame)
		end
	end)
	h.shrink = shrink

	-- filter button (camelot has it but hides it): WotLK sorting and filters
	local filter = atlasButton(h, G.buttonW, G.buttonH, "ui-questtrackerbutton-filter",
		"ui-questtrackerbutton-filter-pressed", "ui-questtrackerbutton-red-highlight")
	filter:SetPoint("RIGHT", shrink, "LEFT", G.filterX, 0)
	filter:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		T.filterMenu(self)
	end)
	h.filter = filter
	h:Hide()
	return h
end

-- WatchFrameHeaderDropDown_Initialize, entry for entry
function T.filterMenu(anchor)
	local sort = WATCHFRAME_SORT_TYPE
	local filter = WATCHFRAME_FILTER_TYPE
	local function sortBy(value)
		return function() WatchFrame_SetSorting(nil, value) end
	end
	local function filterBy(value)
		return function() WatchFrame_SetFilter(nil, value) end
	end
	local function active(bit_)
		return bit.band(filter, bit_) == bit_
	end
	menu(anchor, {
		{ text = TRACKER_SORT_LABEL, isTitle = true },
		{ text = TRACKER_SORT_PROXIMITY, checked = sort == WATCHFRAME_SORT_PROXIMITY, func = sortBy(WATCHFRAME_SORT_PROXIMITY) },
		{ text = TRACKER_SORT_DIFFICULTY_HIGH, checked = sort == WATCHFRAME_SORT_DIFFICULTY_HIGH, func = sortBy(WATCHFRAME_SORT_DIFFICULTY_HIGH) },
		{ text = TRACKER_SORT_DIFFICULTY_LOW, checked = sort == WATCHFRAME_SORT_DIFFICULTY_LOW, func = sortBy(WATCHFRAME_SORT_DIFFICULTY_LOW) },
		{ text = TRACKER_SORT_MANUAL, checked = sort == WATCHFRAME_SORT_MANUAL, func = sortBy(WATCHFRAME_SORT_MANUAL) },
		{ text = TRACKER_FILTER_LABEL, isTitle = true },
		{ text = TRACKER_FILTER_ACHIEVEMENTS, checked = active(WATCHFRAME_FILTER_ACHIEVEMENTS), keepShownOnClick = 1, func = filterBy(WATCHFRAME_FILTER_ACHIEVEMENTS) },
		{ text = TRACKER_FILTER_COMPLETED_QUESTS, checked = active(WATCHFRAME_FILTER_COMPLETED_QUESTS), keepShownOnClick = 1, func = filterBy(WATCHFRAME_FILTER_COMPLETED_QUESTS) },
		{ text = TRACKER_FILTER_REMOTE_ZONES, checked = active(WATCHFRAME_FILTER_REMOTE_ZONES), keepShownOnClick = 1, func = filterBy(WATCHFRAME_FILTER_REMOTE_ZONES) },
	})
end

-- ---------- Modules
-- ObjectiveTrackerModuleTemplate: a header, then the blocks.
-- title: header text; key: saved collapse state key
local function createModule(name, title, key)
	local m = CreateFrame("Frame", name, WatchFrameLines)
	m:SetWidth(G.width)
	m:SetHeight(10)
	m.key = key
	local h = CreateFrame("Frame", nil, m)
	h:SetWidth(G.width)
	h:SetHeight(G.moduleHeaderH)
	h:SetPoint("TOPLEFT", m, "TOPLEFT", 0, 0)
	local background = h:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "ui-questtracker-secondary-objective-header")
	background:SetPoint("CENTER", h, "CENTER", 0, 0)
	local text = h:CreateFontString(nil, "ARTWORK")
	font(text, 14)
	color(text, COLOR.title)
	text:SetWidth(G.moduleTextL)
	text:SetJustifyV("MIDDLE")
	text:SetPoint("LEFT", h, "LEFT", G.headerTextX, 0)
	text:SetText(title)
	local shine = h:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(shine, "ui-questtracker-objfx-shine")
	shine:SetWidth(shine:GetWidth() * 0.95)
	shine:SetHeight(shine:GetHeight() * 0.95)
	shine:SetPoint("CENTER", h, "CENTER", -150, 1)
	shine:SetAlpha(0)
	local glow = h:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(glow, "ui-questtracker-objfx-barglow")
	glow:SetPoint("CENTER", h, "CENTER", -120, 1)
	glow:SetAlpha(0)
	local button = atlasButton(h, G.moduleButtonSide, G.moduleButtonSide, "ui-questtrackerbutton-secondary-collapse",
		"ui-questtrackerbutton-secondary-collapse-pressed", "ui-questtrackerbutton-yellow-highlight")
	button:SetPoint("RIGHT", h, "RIGHT", G.moduleButtonX, 0)
	button:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		local r = settings().collapsedModules
		r[key] = not r[key] or nil
		WatchFrame_Update()
	end)
	h.background, h.text, h.shine, h.glow, h.button = background, text, shine, glow, button
	m.header = h
	m.blocks, m.freeBlocks = {}, {}
	m:Hide()
	return m
end

-- ObjectiveTrackerModuleHeaderMixin:PlayAddAnimation
local function animateModuleHeader(m)
	local h = m.header
	local key = m
	h.background:SetAlpha(0)
	h.button:SetAlpha(0)
	play({ key, "background" }, 0, 0.5, function(p) h.background:SetAlpha(p) end)
	play({ key, "button" }, 0, 1, function(p) h.button:SetAlpha(p) end)
	play({ key, "glow" }, 0, 0.2, function(p) h.glow:SetAlpha(p) end, function()
		play({ key, "glow" }, 0, 0.6, function(p) h.glow:SetAlpha(1 - p) end)
	end)
	play({ key, "shine" }, 0.2, 1.2, function(p)
		local q = math.min(1, p * 1.2 / 0.7)
		h.shine:ClearAllPoints()
		h.shine:SetPoint("CENTER", h, "CENTER", -150 + 200 * q, 1)
		h.shine:SetAlpha(1 - p)
	end, function() h.shine:SetAlpha(0) end)
end

-- ---------- Blocks
local function createRow(block)
	local l = CreateFrame("Frame", nil, block)
	local dash = l:CreateFontString(nil, "ARTWORK")
	font(dash, 12)
	dash:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 1)
	dash:SetText(QUEST_DASH)
	local text = l:CreateFontString(nil, "ARTWORK")
	font(text, 12)
	text:SetPoint("TOP", l, "TOP", 0, 0)
	text:SetPoint("LEFT", dash, "RIGHT", 0, 0)
	local checkMark = l:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(checkMark, "ui-questtracker-tracker-check", true)
	checkMark:SetWidth(G.checkMark)
	checkMark:SetHeight(G.checkMark)
	checkMark:SetPoint("TOPLEFT", l, "TOPLEFT", G.checkMarkX, G.checkMarkY)
	checkMark:Hide()
	local flare = l:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(flare, "ui-questtracker-tracker-check-glow", true)
	flare:SetWidth(G.checkMark)
	flare:SetHeight(G.checkMark)
	flare:SetPoint("CENTER", checkMark, "CENTER", 0, 0)
	flare:SetAlpha(0)
	local glow = l:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(glow, "ui-questtracker-objfx-barglow", true)
	glow:SetWidth(G.rowGlowL)
	glow:SetPoint("LEFT", text, "LEFT", -2, 0)
	glow:SetPoint("TOP", l, "TOP", 0, 0)
	glow:SetPoint("BOTTOM", l, "BOTTOM", 0, -4)
	glow:SetAlpha(0)
	l.dash, l.text, l.checkMark, l.flare, l.glow = dash, text, checkMark, flare, glow
	return l
end

-- ObjectiveTrackerTimerBarTemplate
local function createTimer(block)
	local m = CreateFrame("Frame", nil, block)
	m:SetWidth(G.timerW)
	m:SetHeight(G.timerH)
	-- camelot GameFontHighlightMedium: FRIZQT 14, white, shadow
	local text = m:CreateFontString(nil, "ARTWORK")
	text:SetFont(FONT, 14)
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", m, "LEFT", 0, 0)
	local bar = CreateFrame("StatusBar", nil, m)
	bar:SetWidth(G.barW)
	bar:SetHeight(G.barH)
	bar:SetPoint("RIGHT", m, "RIGHT", G.barX, 0)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(COLOR.bar[1], COLOR.bar[2], COLOR.bar[3])
	local background = bar:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(COLOR.barBackground[1], COLOR.barBackground[2], COLOR.barBackground[3])
	background:SetAllPoints(bar)
	local BAR_BORDER = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
	local g = bar:CreateTexture(nil, "ARTWORK")
	g:SetTexture(BAR_BORDER)
	g:SetTexCoord(0.007843, 0.043137, 0.193548, 0.774193)
	g:SetWidth(9) g:SetHeight(14)
	g:SetPoint("LEFT", bar, "LEFT", -3, 0)
	local d = bar:CreateTexture(nil, "ARTWORK")
	d:SetTexture(BAR_BORDER)
	d:SetTexCoord(0.043137, 0.007843, 0.193548, 0.774193)
	d:SetWidth(9) d:SetHeight(14)
	d:SetPoint("RIGHT", bar, "RIGHT", 3, 0)
	local mid = bar:CreateTexture(nil, "ARTWORK")
	mid:SetTexture(BAR_BORDER)
	mid:SetTexCoord(0.113726, 0.1490196, 0.193548, 0.774193)
	mid:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	mid:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	m.text, m.bar = text, bar
	-- ObjectiveTrackerTimerBarMixin:OnUpdate and GetTextColor
	m:SetScript("OnUpdate", function(self)
		if not self.duration then return end
		local rest = self.duration - (GetTime() - self.start)
		self.bar:SetValue(math.max(0, rest))
		if rest < -1 then
			self.duration = nil
			WatchFrame_Update()
			return
		end
		rest = math.max(0, rest)
		self.text:SetText(clock(rest))
		local part = rest / self.duration
		if part > 0.66 then
			self.text:SetTextColor(1, 1, 1)
		elseif part > 0.33 then
			self.text:SetTextColor(1, 1, (part - 0.33) / 0.33)
		else
			self.text:SetTextColor(1, part / 0.33, 0)
		end
	end)
	return m
end

local function createBlock(m)
	local b = CreateFrame("Frame", nil, m)
	local title = b:CreateFontString(nil, "ARTWORK")
	font(title, 12)
	title:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.title = title
	local glow = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(glow, "ui-questtracker-objfx-barglow", true)
	glow:SetWidth(G.headerGlowL)
	glow:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 3)
	glow:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", 0, -4)
	glow:SetAlpha(0)
	b.glow = glow
	-- HeaderButton: over the title, left and right click
	local button = CreateFrame("Button", nil, b)
	button:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 0)
	button:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 0, 0)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(_, mouse) m.onClick(b, mouse) end)
	button:SetScript("OnEnter", function() T.toggleHighlight(b, true) end)
	button:SetScript("OnLeave", function() T.toggleHighlight(b, false) end)
	b.button = button
	b.rows, b.freeRows = {}, {}
	return b
end

-- ObjectiveTrackerBlockMixin:UpdateHighlight; yes: hovered
function T.toggleHighlight(b, yes)
	b.hover = yes
	color(b.title, yes and COLOR.headerHover or COLOR.header)
	local dash = yes and COLOR.normalHover or COLOR.normal
	for _, l in ipairs(b.shownRows or {}) do
		local c = l.text.color
		if c and c.inverse and ((yes and (c == COLOR.normal or c == COLOR.failed))
			or (not yes and (c == COLOR.normalHover or c == COLOR.failedHover))) then
			color(l.text, c.inverse)
		end
		l.dash:SetTextColor(dash[1], dash[2], dash[3])
	end
end

-- A block starts from scratch on every pass (Reset), and so do its rows.
local function acquireBlock(m, id)
	local b = m.blocks[id]
	if not b then
		b = table.remove(m.freeBlocks) or createBlock(m)
		m.blocks[id] = b
	end
	b.id, b.inUse = id, true
	b:SetWidth(G.width - G.blockX)
	b.contentHeight = 0
	b.last = nil
	b.right = 0
	b.shownRows = {}
	for _, l in pairs(b.rows) do l.used = nil end
	if b.timer then b.timer:Hide() b.timer.duration = nil end
	b:ClearAllPoints()
	b:SetAlpha(1)
	b.title:SetAlpha(1)
	return b
end

-- Widths are set by hand: the block is not placed yet when its texts are measured, and
-- 3.3.5 only measures a text that has a width (camelot relies on anchors).
local function setBlockTitle(b, text)
	b.title:SetWidth(G.width - G.blockX + b.right)
	b.title:SetHeight(0)
	b.title:SetText(text)
	color(b.title, b.hover and COLOR.headerHover or COLOR.header)
	b.contentHeight = b.title:GetHeight()
end

-- ObjectiveTrackerBlockMixin:AddObjective. key: row id in the block; dash: show the dash;
-- c: text color (default normal)
local function row(b, key, text, dash, c)
	local l = b.rows[key]
	if not l then
		l = table.remove(b.freeRows) or createRow(b)
		b.rows[key] = l
	end
	l.used = true
	l:ClearAllPoints()
	l:SetPoint("TOPLEFT", b.last or b.title, "BOTTOMLEFT", 0, -G.rowGap)
	local width = G.width - G.blockX + b.right
	l:SetWidth(width)
	l.dash:SetText(QUEST_DASH)
	if dash then l.dash:Show() else l.dash:Hide() end
	l.text:SetWidth(width - l.dash:GetStringWidth())
	l.text:SetHeight(0)
	l.text:SetText(text)
	c = c or COLOR.normal
	if b.hover and c.inverse then c = c.inverse end
	color(l.text, c)
	local tc = b.hover and COLOR.normalHover or COLOR.normal
	l.dash:SetTextColor(tc[1], tc[2], tc[3])
	local h = l.text:GetHeight()
	l:SetHeight(h)
	l:SetAlpha(1)
	l:Show()
	b.contentHeight = b.contentHeight + h + G.rowGap
	b.last = l
	table.insert(b.shownRows, l)
	return l
end

-- ObjectiveTrackerBlockMixin:AddTimerBar; start: GetTime() when the timer began
local function timer(b, duration, start)
	if not b.timer then b.timer = createTimer(b) end
	local m = b.timer
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", b.last or b.title, "BOTTOMLEFT", 0, -G.rowGap)
	m.bar:SetMinMaxValues(0, duration)
	m.duration, m.start = duration, start
	m:Show()
	b.contentHeight = b.contentHeight + G.timerH + G.rowGap
	b.last = m
end

-- rows and blocks not reused in this pass are released
local function releaseRows(b)
	for key, l in pairs(b.rows) do
		if not l.used then
			l:Hide()
			l.checkMark:Hide()
			l.glow:SetAlpha(0)
			l.flare:SetAlpha(0)
			b.rows[key] = nil
			table.insert(b.freeRows, l)
		end
	end
end

local function releaseBlocks(m)
	for id, b in pairs(m.blocks) do
		if not b.inUse then
			b:Hide()
			b.hover = nil
			m.blocks[id] = nil
			table.insert(m.freeBlocks, b)
		end
	end
end

-- check state of a row: Completed = check mark shown, no animation;
-- Completing (animate) = check mark + flare + glow (CheckAnim and GlowAnim)
local function checkOff(l, animate)
	l.checkMark:Show()
	if not animate then
		l.checkMark:SetAlpha(1)
		return
	end
	play({ l, "checkMark" }, 0, 0.3, function(p)
		local s = (p < 0.5) and (1 + 0.2 * easeOut(p * 2)) or (1.2 - 0.2 * easeOut((p - 0.5) * 2))
		l.checkMark:SetWidth(G.checkMark * s)
		l.checkMark:SetHeight(G.checkMark * s)
		l.checkMark:SetAlpha(math.min(1, p / 0.53))
		l.flare:SetWidth(G.checkMark * s)
		l.flare:SetHeight(G.checkMark * s)
		l.flare:SetAlpha(p < 0.5 and p * 2 or (1 - p) * 2)
	end, function()
		l.checkMark:SetWidth(G.checkMark) l.checkMark:SetHeight(G.checkMark) l.checkMark:SetAlpha(1)
		l.flare:SetAlpha(0)
	end)
	T.sweep(l.glow, G.rowGlowL, 0.1, 0.66, 0.33, 0.58)
end

-- a glow that stretches from the left (Scale x 0 -> 1, origin LEFT), then fades out
-- (Alpha 1 -> 0)
function T.sweep(t, width, delay, duration, alphaDelay, alphaDuration)
	play({ t, "width" }, delay, duration, function(p)
		t:SetWidth(math.max(1, width * easeOut(p)))
	end)
	play({ t, "alpha" }, alphaDelay, alphaDuration, function(p) t:SetAlpha(1 - p) end,
		function() t:SetAlpha(0) t:SetWidth(width) end)
end

-- ObjectiveTrackerAnimBlockMixin:PlayAddAnimation: title glow, then the title and rows fade in
local function animateAdd(b)
	b.glow:SetWidth(1)
	b.glow:SetAlpha(1)
	play({ b.glow, "width" }, 0.15, 0.31, function(p) b.glow:SetWidth(math.max(1, G.headerGlowL * p)) end)
	play({ b.glow, "alpha" }, 0.33, 0.41, function(p) b.glow:SetAlpha(1 - p) end,
		function() b.glow:SetAlpha(0) b.glow:SetWidth(G.headerGlowL) end)
	b.title:SetAlpha(0)
	play({ b.title, "alpha" }, 0, 0.03, function(p) b.title:SetAlpha(p) end)
	for _, l in ipairs(b.shownRows) do
		l:SetAlpha(0)
		play({ l, "entry" }, 0, 0.5, function(p) l:SetAlpha(p) end)
	end
end

-- ---------- Layout
-- ObjectiveTrackerModuleMixin: BeginLayout, AddBlock / CanFitBlock, EndLayout.
-- position: height available; finalize returns the module height, 0 when hidden.
local function begin(m, position)
	m.position = position
	m.contentHeight = G.moduleCountedHeader
	m.last = nil
	m.content = false
	m.skipped = false
	m.tried = false
	for _, b in pairs(m.blocks) do b.inUse = nil end
end

-- returns true when the block fits
local function place(m, b)
	m.tried = true
	releaseRows(b)
	b:SetHeight(math.max(1, b.contentHeight))
	local gap = m.last and G.blockY or G.firstBlockY
	if m.contentHeight + b.contentHeight - gap > m.position then
		m.skipped = true
		b.inUse = nil
		return false
	end
	m.content = true
	if settings().collapsedModules[m.key] then
		b.inUse = nil
		return true
	end
	b:ClearAllPoints()
	if m.last then
		b:SetPoint("TOP", m.last, "BOTTOM", 0, gap)
	else
		b:SetPoint("TOP", m.header, "BOTTOM", 0, gap)
	end
	b:SetPoint("LEFT", m, "LEFT", G.blockX, 0)
	b:SetPoint("RIGHT", m, "RIGHT", 0, 0)
	b:Show()
	m.contentHeight = m.contentHeight + b.contentHeight - gap
	m.last = b
	return true
end

local function finalize(m, lineFrame, offset)
	releaseBlocks(m)
	local collapsed = settings().collapsedModules[m.key]
	buttonStates(m.header.button,
		collapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse",
		collapsed and "ui-questtrackerbutton-secondary-expand-pressed" or "ui-questtrackerbutton-secondary-collapse-pressed")
	if m.content then
		m:ClearAllPoints()
		m:SetPoint("TOPLEFT", lineFrame, "TOPLEFT", 0, offset)
		m:SetHeight(m.contentHeight)
		local wasShown = m:IsShown() and m.displayed
		m:Show()
		m.displayed = true
		if not wasShown then animateModuleHeader(m) end
		return m.contentHeight
	end
	m:Hide()
	m.displayed = nil
	return 0
end

-- space left in WatchFrameLines below this offset
local function remainingSpace(maxHeight, offset)
	return (maxHeight or 0) - G.modulesTop - G.rowsBottom + (offset or 0)
end

-- ---------- Quests
-- durations: largest remaining time seen per quest. 3.3.5 only gives the remaining time
-- (GetQuestTimers), so that value is the timer bar's full duration.
local Q = { states = {}, seen = nil, durations = {} }

-- WatchFrame_DisplayTrackedQuests for the data, QuestObjectiveTracker for the display.
-- Zone quests: WotLK's LOCAL_MAP_QUESTS is kept in our own table. The client fills it only in
-- its quest handler, which is removed; writing it from the addon would taint it, and with it
-- the world map that reads it.
local locales = {}
T.locales = locales
T.numItems = 0

local function displayQuests(lineFrame, initialOffset, maxHeight, frameWidth)
	local m = T.quests
	begin(m, remainingSpace(maxHeight, initialOffset))
	local money = GetMoney()
	local numWatched = GetNumQuestWatches()
	local nPOI = { numbered = 0, inside = 0, outside = 0 }
	local objects = 0
	local seen = {}
	for w = 1, numWatched do
		local index = GetQuestIndexForWatch(w)
		if index then
			local title, _, _, _, _, _, _, _, questID = GetQuestLogTitle(index)
			seen[questID or title] = true
		end
	end
	local questTimers = {}
	local timers = { GetQuestTimers() }
	for i, seconds in ipairs(timers) do
		local index = GetQuestIndexForTimer(i)
		if index then questTimers[index] = seconds end
	end

	local selection
	if WorldMapFrame and WorldMapFrame:IsShown() then
		selection = WORLDMAP_SETTINGS.selectedQuestId
	else
		table.wipe(locales)
		locales["zone"] = GetCurrentMapZone()
		for id in pairs(CURRENT_MAP_QUESTS) do
			locales[id] = true
		end
	end
	table.wipe(VISIBLE_WATCHES)

	for w = 1, numWatched do
		local index = GetQuestIndexForWatch(w)
		if index then
			local title, _, _, _, _, _, isComplete, _, questID = GetQuestLogTitle(index)
			local required = GetQuestLogRequiredMoney(index)
			local numObjectives = GetNumQuestLeaderBoards(index)
			local failed = isComplete and isComplete < 0
			if failed then
				isComplete = false
			elseif isComplete and isComplete > 0 then
				isComplete = true
			elseif numObjectives == 0 and money >= required then
				isComplete = true
			else
				isComplete = false
			end
			-- WotLK filters
			local keep = true
			if isComplete and bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_COMPLETED_QUESTS) ~= WATCHFRAME_FILTER_COMPLETED_QUESTS then
				keep = false
			elseif bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_REMOTE_ZONES) ~= WATCHFRAME_FILTER_REMOTE_ZONES and not locales[questID] then
				keep = false
			end
			if keep then
				if required > 0 then WatchFrame.watchMoney = true end
				local _, object, charges = GetQuestLogSpecialItemInfo(index)
				local key = questID or title
				local before = Q.states[key]
				local state = { finished = {}, isComplete = isComplete }
				local b = acquireBlock(m, key)
				b.index, b.watch, b.questID, b.questTitle = index, w, questID, title
				-- quest item, right of the block
				local button
				if object and not isComplete then
					objects = objects + 1
					button = T.object(objects, lineFrame, index, object, charges)
					b.right = -(G.itemSide + G.rightGap)
				end
				setBlockTitle(b, title)

				local animate = {}
				if isComplete then
					-- QUEST_LOG_UPDATE: objectives already shown fade out (FadeOutAnim: 1 s then 0.1 s),
					-- then the completion text
					local fade = before and not before.isComplete and not (before.fade and before.fade <= GetTime())
					if fade then
						state.fade = before.fade or (GetTime() + 1.1)
						for j = 1, numObjectives do
							local text = GetQuestLogLeaderBoard(j, index)
							if text then
								local l = row(b, j, WatchFrame_ReverseQuestObjective(text), false, COLOR.finished)
								state.finished[j] = true
								table.insert(animate, { l, not (before.finished and before.finished[j]) })
								play({ l, "fade" }, math.max(0, state.fade - 0.1 - GetTime()), 0.1,
									function(p) l:SetAlpha(1 - p) end)
							end
						end
						state.isComplete = false
						T.restart(state.fade)
					else
						local completionText = GetQuestLogCompletionText(index)
						if completionText then
							row(b, "QuestComplete", completionText, false)
						else
							row(b, "QuestComplete", TEXT.ready, false, COLOR.finished)
						end
					end
				elseif failed then
					row(b, "Failed", FAILED, false, COLOR.failed)
				else
					for j = 1, numObjectives do
						local text, _, finished = GetQuestLogLeaderBoard(j, index)
						if text then
							text = WatchFrame_ReverseQuestObjective(text)
							if finished then
								state.finished[j] = true
								local l = row(b, j, text, false, COLOR.finished)
								table.insert(animate, { l, before and not (before.finished and before.finished[j]) })
							else
								local l = row(b, j, text, true)
								l.checkMark:Hide()
							end
						end
					end
					if required > money then
						row(b, "Money", GetMoneyString(money) .. " / " .. GetMoneyString(required), true)
					end
					local rest = questTimers[index]
					if rest then
						local duration = math.max(Q.durations[key] or 0, rest)
						Q.durations[key] = duration
						timer(b, duration, GetTime() - (duration - rest))
					end
				end

				Q.states[key] = state
				if place(m, b) then
					if not settings().collapsedModules[m.key] then
						table.insert(VISIBLE_WATCHES, index)
						for _, a in ipairs(animate) do checkOff(a[1], a[2]) end
						if button then
							button:ClearAllPoints()
							button:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
							button:Show()
						end
						-- WotLK POI button (QuestPOI_DisplayButton, 32 x 32), centered where camelot centers
						-- its 20 x 20 one
						if WatchFrame.showObjectives then
							local poi
							if CURRENT_MAP_QUESTS[questID] then
								if isComplete then
									nPOI.inside = nPOI.inside + 1
									poi = QuestPOI_DisplayButton("WatchFrameLines", QUEST_POI_COMPLETE_IN, nPOI.inside, questID)
								else
									nPOI.numbered = nPOI.numbered + 1
									poi = QuestPOI_DisplayButton("WatchFrameLines", QUEST_POI_NUMERIC, nPOI.numbered, questID)
								end
							elseif isComplete then
								nPOI.outside = nPOI.outside + 1
								poi = QuestPOI_DisplayButton("WatchFrameLines", QUEST_POI_COMPLETE_OUT, nPOI.outside, questID)
							end
							if poi then
								poi:ClearAllPoints()
								poi:SetPoint("CENTER", b.title, "TOPLEFT", G.poiX, G.poiY)
							end
						end
						-- a quest absent from the previous pass is new (3.3.5 has no QUEST_WATCH_LIST_CHANGED)
						if Q.seen and not Q.seen[key] then
							animateAdd(b)
						end
					elseif button then
						button:Hide()
					end
				else
					if button then
						button:Hide()
						objects = objects - 1
					end
					break
				end
			end
		end
	end

	for i = objects + 1, T.numItems do
		local it = _G["WatchFrameItem" .. i]
		if it then it:Hide() end
	end
	QuestPOI_HideButtons("WatchFrameLines", QUEST_POI_NUMERIC, nPOI.numbered + 1)
	QuestPOI_HideButtons("WatchFrameLines", QUEST_POI_COMPLETE_IN, nPOI.inside + 1)
	QuestPOI_HideButtons("WatchFrameLines", QUEST_POI_COMPLETE_OUT, nPOI.outside + 1)
	if selection then
		QuestPOI_SelectButtonByQuestId("WatchFrameLines", selection, true)
	end
	-- remember this pass; the first pass animates no quest (they were already there)
	for key in pairs(Q.states) do
		if not seen[key] then Q.states[key] = nil end
	end
	Q.seen = seen
	local height = finalize(m, lineFrame, initialOffset)
	return height, G.width, numWatched
end
T.displayQuests = displayQuests

-- one more pass when a fade ends
function T.restart(when)
	play({ T, "rerun" }, math.max(0, when - GetTime()), 0, function() end, function()
		WatchFrame_Update()
	end)
end

-- WatchFrameItem<n>: the WotLK buttons, reskinned once. n: button number;
-- index: quest log index; icon, charges: the quest item
function T.object(n, lineFrame, index, icon, charges)
	local b = _G["WatchFrameItem" .. n]
	if not b then
		b = CreateFrame("Button", "WatchFrameItem" .. n, lineFrame, "WatchFrameItemButtonTemplate")
	end
	-- button count: WotLK's WATCHFRAME_NUM_ITEMS is read only by its removed quest handler;
	-- kept here so the addon never writes that global
	if n > T.numItems then T.numItems = n end
	if not b.foreverSkinApplied then
		b.foreverSkinApplied = true
		b:SetWidth(G.itemSide)
		b:SetHeight(G.itemSide)
		local e = ForeverUI.AtlasEntry("ui-questtrackerbutton-questitem-frame")
		b:SetNormalTexture(e and e[1] or "")
		local t = b:GetNormalTexture()
		ForeverUI.SetAtlas(t, "ui-questtrackerbutton-questitem-frame", true)
		t:ClearAllPoints()
		t:SetWidth(G.itemFrame)
		t:SetHeight(G.itemFrame)
		t:SetPoint("CENTER", b, "CENTER", 0, 0)
		b:SetPushedTexture(e and e[1] or "")
		local p = b:GetPushedTexture()
		ForeverUI.SetAtlas(p, "ui-questtrackerbutton-questitem-frame", true)
		p:ClearAllPoints()
		p:SetWidth(G.itemFrame)
		p:SetHeight(G.itemFrame)
		p:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
	b:SetID(index)
	SetItemButtonTexture(b, icon)
	SetItemButtonCount(b, charges)
	b.charges = charges
	WatchFrameItem_UpdateCooldown(b)
	b.rangeTimer = -1
	return b
end

-- ---------- Achievements
local function showAchievements(lineFrame, initialOffset, maxHeight, frameWidth, ...)
	local m = T.achievements
	begin(m, remainingSpace(maxHeight, initialOffset))
	local count = select("#", ...)
	local arena = ArenaEnemyFrames and ArenaEnemyFrames:IsShown()
	if bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_ACHIEVEMENTS) == WATCHFRAME_FILTER_ACHIEVEMENTS then
		for i = 1, count do
			local id = select(i, ...)
			local category = GetAchievementCategory(id)
			local _, name, _, completed, _, _, _, description = GetAchievementInfo(id)
			if not completed and not arena or category == WATCHFRAME_ACHIEVEMENT_ARENA_CATEGORY then
				local b = acquireBlock(m, id)
				b.achievement = id
				setBlockTitle(b, name)
				local numCriteria = GetAchievementNumCriteria(id)
				if numCriteria > 0 then
					local shownItems = 0
					for j = 1, numCriteria do
						local text, _, filled, _, _, _, flags, _, quantity, criteriaID = GetAchievementCriteriaInfo(id, j)
						if filled or shownItems > G.maxCriteria then
							-- skip: criterion done, or past the limit
						elseif shownItems == G.maxCriteria and numCriteria > G.maxCriteria + 1 then
							row(b, "Extra", "...", false)
							shownItems = shownItems + 1
						else
							if bit.band(flags, ACHIEVEMENT_CRITERIA_PROGRESS_BAR) == ACHIEVEMENT_CRITERIA_PROGRESS_BAR then
								text = quantity
							end
							row(b, j, text, true)
							shownItems = shownItems + 1
							local stopwatch = WATCHFRAME_TIMEDCRITERIA[criteriaID]
							if stopwatch and GetTime() - stopwatch.startTime < stopwatch.duration then
								timer(b, stopwatch.duration, stopwatch.startTime)
							end
						end
					end
				else
					row(b, 1, description, true)
					for _, stopwatch in pairs(WATCHFRAME_TIMEDCRITERIA) do
						if stopwatch.achievementID == id and GetTime() - stopwatch.startTime <= stopwatch.duration then
							timer(b, stopwatch.duration, stopwatch.startTime)
							break
						end
					end
				end
				if not place(m, b) then
					break
				end
			end
		end
	end
	local height = finalize(m, lineFrame, initialOffset)
	return height, G.width, count
end

local function achievementHandler(lineFrame, initialOffset, maxHeight, frameWidth)
	return showAchievements(lineFrame, initialOffset, maxHeight, frameWidth, GetTrackedAchievements())
end
T.achievementHandler = achievementHandler

-- ---------- Clicks
-- QuestObjectiveTrackerMixin:OnBlockHeaderClick
local function questClick(b, mouse)
	if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
		local link = GetQuestLink(b.index)
		if link then ChatEdit_InsertLink(link) end
		return
	end
	if mouse ~= "RightButton" then
		CloseDropDownMenus()
		if IsModifiedClick("QUESTWATCHTOGGLE") then
			WatchFrame_StopTrackingQuest(nil, b.watch)
		else
			T.openPage(b.watch)
		end
		return
	end
	local w = b.watch
	local index = b.index
	local l = {
		{ text = b.questTitle, isTitle = true },
		{ text = TEXT.viewPage, func = function() T.openPage(w) end },
		{ text = TEXT.viewMap, func = function() WatchFrame_OpenMapToQuest(nil, w) end },
		{ text = TEXT.untrack, func = function() WatchFrame_StopTrackingQuest(nil, w) end },
	}
	if GetQuestLogPushable and (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 1) then
		local selection = GetQuestLogSelection()
		SelectQuestLogEntry(index)
		local shareable = GetQuestLogPushable()
		SelectQuestLogEntry(selection)
		if shareable then
			table.insert(l, { text = SHARE_QUEST, func = function() WatchFrame_ShareQuest(nil, w) end })
		end
	end
	table.insert(l, { text = TEXT.shareInChat, func = function()
		local link = GetQuestLink(index)
		if link and not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) then
			ChatFrame_OpenChat(link)
		end
	end })
	table.insert(l, { text = TEXT.abandonQuest, func = function() WatchFrame_AbandonQuest(nil, w) end })
	-- WotLK manual ordering
	local n = #VISIBLE_WATCHES
	local rank = WatchFrame_GetVisibleIndex(index)
	if n > 1 and rank then
		if rank > 1 then
			table.insert(l, { text = TRACKER_SORT_MANUAL_UP, func = function() WatchFrame_MoveQuest(nil, index, -1) end })
			table.insert(l, { text = TRACKER_SORT_MANUAL_TOP, func = function() WatchFrame_MoveQuest(nil, index, -100) end })
		end
		if rank < n then
			table.insert(l, { text = TRACKER_SORT_MANUAL_DOWN, func = function() WatchFrame_MoveQuest(nil, index, 1) end })
			table.insert(l, { text = TRACKER_SORT_MANUAL_BOTTOM, func = function() WatchFrame_MoveQuest(nil, index, 100) end })
		end
	end
	menu("cursor", l)
end

-- AchievementObjectiveTrackerMixin:OnBlockHeaderClick
local function achievementClick(b, mouse)
	local id = b.achievement
	if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
		local link = GetAchievementLink(id)
		if link then ChatEdit_InsertLink(link) end
		return
	end
	if mouse ~= "RightButton" then
		CloseDropDownMenus()
		if IsModifiedClick("QUESTWATCHTOGGLE") then
			WatchFrame_StopTrackingAchievement(nil, id)
		else
			WatchFrame_OpenAchievementFrame(nil, id)
		end
		return
	end
	local _, name = GetAchievementInfo(id)
	menu("cursor", {
		{ text = name, isTitle = true },
		{ text = TEXT.viewAchievement, func = function() WatchFrame_OpenAchievementFrame(nil, id) end },
		{ text = TEXT.untrack, func = function() WatchFrame_StopTrackingAchievement(nil, id) end },
	})
end

-- QuestMapFrame_OpenToQuestDetails: map, side panel, quest page. WotLK first expands the
-- quest's header (WatchFrameLinkButtonTemplate_OnLeftClick).
function T.openPage(watch)
	local index = GetQuestIndexForWatch(watch)
	if not index then return end
	ExpandQuestHeader(GetQuestSortIndex(index))
	index = GetQuestIndexForWatch(watch)
	if index and ForeverUI.QuestLog and ForeverUI.QuestLog.openPage then
		ForeverUI.QuestLog.openPage(index)
	end
end

-- ---------- Assembly
local function suppressWotLKHeader()
	for _, f in ipairs({ WatchFrameHeader, WatchFrameCollapseExpandButton }) do
		if f then
			f:SetAlpha(0)
			f:EnableMouse(false)
			f:Hide()
		end
	end
end

-- After each WatchFrame_Update our header replaces WotLK's. WotLK decides whether to show it
-- only in WatchFrame_Update, so that decision is kept: its header is already hidden when
-- WatchFrame_Collapse / _Expand call us again. fromUpdate: called from WatchFrame_Update.
local function afterUpdate(fromUpdate)
	local h = T.header
	if not h then return end
	if fromUpdate then
		T.headerWanted = WatchFrameHeader:IsShown() and true or false
	end
	local showRegion = T.headerWanted
	suppressWotLKHeader()
	if showRegion then
		h:Show()
		local active = WatchFrameCollapseExpandButton:IsEnabled() == 1
		if active then h.shrink:Enable() else h.shrink:Disable() end
	else
		h:Hide()
	end
	if WatchFrame.collapsed then
		buttonStates(h.shrink, "ui-questtrackerbutton-expand-all", "ui-questtrackerbutton-expand-all-pressed")
	else
		buttonStates(h.shrink, "ui-questtrackerbutton-collapse-all", "ui-questtrackerbutton-collapse-all-pressed")
	end
end
T.afterUpdate = afterUpdate

-- WatchFrame_SetWidth and WatchFrame_Collapse / _Expand: 260, collapsed or not.
-- WATCHFRAME_EXPANDEDWIDTH and WATCHFRAME_MAXLINEWIDTH keep the client's values: the width
-- is re-applied after it (hooks below), and our handlers ignore the width it passes.
local function width()
	WatchFrame:SetWidth(G.width)
end

-- The tracker follows a CARRIER registered in edit mode. WotLK's
-- UIParent_ManageFramePositions re-anchors WatchFrame under MinimapCluster on every pass and
-- adds a BOTTOMRIGHT point, so WatchFrame is re-placed after it. Its height runs from the
-- carrier down to WotLK's bottom (CONTAINER_OFFSET_Y, above the action bars).
function T.place()
	local carrier = T.carrier
	if not carrier then return end
	WatchFrame:ClearAllPoints()
	WatchFrame:SetPoint("TOPLEFT", carrier, "TOPLEFT", 0, 0)
	local top = carrier:GetTop()
	if top then
		WatchFrame:SetHeight(math.max(G.minHeight, top - (CONTAINER_OFFSET_Y or 0)))
	end
end

local function buildCarrier()
	local carrier = CreateFrame("Frame", "ForeverUIObjectiveTrackerHolder", UIParent)
	carrier:SetWidth(G.width)
	carrier:SetHeight(G.headerH)
	T.carrier = carrier
	local L = ForeverUI.Layout
	if L and L.Register then
		L.Register(carrier, "tracking", ForeverUI.L.OBJECTIVETRACKER_EDIT_LABEL, "TOPRIGHT", "TOPRIGHT", G.defaultX, G.defaultY)
		-- moved, reset or applied at login: the tracker follows
		local function after(id)
			if id == "tracking" then T.place() end
		end
		hooksecurefunc(L, "Save", after)
		hooksecurefunc(L, "Apply", after)
	end
	if UIParent_ManageFramePositions then
		hooksecurefunc("UIParent_ManageFramePositions", T.place)
	end
	T.place()
end

local function build()
	if T.header or not WatchFrame or not WatchFrameLines then
		return
	end
	buildCarrier()
	T.header = createHeader()
	T.quests = createModule("ForeverUIQuestObjectiveTracker", TEXT.quests, "quests")
	T.quests.onClick = questClick
	T.achievements = createModule("ForeverUIAchievementObjectiveTracker", TEXT.achievements, "achievements")
	T.achievements.onClick = achievementClick

	WatchFrameLines:ClearAllPoints()
	WatchFrameLines:SetPoint("TOPLEFT", WatchFrame, "TOPLEFT", 0, -G.modulesTop)
	WatchFrameLines:SetPoint("BOTTOMRIGHT", WatchFrame, "BOTTOMRIGHT", 0, G.rowsBottom)
	width()

	-- camelot's two modules, in camelot's order, replace the three WotLK handlers;
	-- addon handlers stay after them
	WatchFrame_RemoveObjectiveHandler(WatchFrame_HandleDisplayQuestTimers)
	WatchFrame_RemoveObjectiveHandler(WatchFrame_HandleDisplayTrackedAchievements)
	WatchFrame_RemoveObjectiveHandler(WatchFrame_DisplayTrackedQuests)
	table.insert(WATCHFRAME_OBJECTIVEHANDLERS, 1, displayQuests)
	table.insert(WATCHFRAME_OBJECTIVEHANDLERS, 2, achievementHandler)

	hooksecurefunc("WatchFrame_Update", function() afterUpdate(true) end)
	hooksecurefunc("WatchFrame_SetWidth", function()
		if not WatchFrame.collapsed then width() end
	end)
	-- Tracking a quest from the map: WotLK adds it to LOCAL_MAP_QUESTS when that table is the
	-- shown zone's, and removes it otherwise (WorldMapFrame.lua:2162-2167). The table is ours,
	-- so do the same, then redo the refresh the client already ran without it.
	if WorldMapTrackQuest_Toggle then
		hooksecurefunc("WorldMapTrackQuest_Toggle", function(checkMark)
			local id = WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.selectedQuestId
			if not id then return end
			if checkMark then
				if locales["zone"] == GetCurrentMapZone() then locales[id] = true end
			else
				locales[id] = nil
			end
			WatchFrame_Update()
		end)
	end
	hooksecurefunc("WatchFrame_Collapse", function(self)
		self:SetWidth(G.width)
		afterUpdate()
	end)
	hooksecurefunc("WatchFrame_Expand", function(self)
		self:SetWidth(G.width)
		afterUpdate()
	end)
	suppressWotLKHeader()
	-- WatchFrame_Update measures the frame, so not before it is placed (it is not at addon
	-- load; its login events refresh it)
	if WatchFrame:GetTop() and WatchFrame:GetBottom() then
		WatchFrame_Update()
	end
end
T.build = build

build()

ForeverUI.ObjectiveTrackerDebug = function()
	local prefix = "|cff66ccffForeverUI|r "
	if not T.header then
		DEFAULT_CHAT_FRAME:AddMessage(prefix .. L.OBJECTIVETRACKER_DEBUG_NOT_BUILT)
		return
	end
	local n = 0
	for _ in pairs(T.quests.blocks) do n = n + 1 end
	local a = 0
	for _ in pairs(T.achievements.blocks) do a = a + 1 end
	DEFAULT_CHAT_FRAME:AddMessage(prefix .. string.format(
		L.OBJECTIVETRACKER_DEBUG_STATE,
		WatchFrame:GetWidth(), WatchFrame:GetHeight(), tostring(WatchFrame.collapsed), tostring(T.header:IsShown()),
		n, tostring(T.quests:IsShown()), a, tostring(T.achievements:IsShown()), #WATCHFRAME_OBJECTIVEHANDLERS,
		tostring(WATCHFRAME_SORT_TYPE), tostring(WATCHFRAME_FILTER_TYPE)))
end
