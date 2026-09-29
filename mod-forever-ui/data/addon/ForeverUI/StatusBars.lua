-- Bottom status bars: experience and reputation.
-- mainline/StatusTrackingBarTemplate.xml: both bars are the same object (background, fill,
-- frame over it, centered text), so both are built the same way.
-- camelot/StatusTrackingBarConstants.lua: the containers are one bar height apart, so the
-- bars touch; camelot's image is 13 high. The game shows reputation above experience,
-- although the priorities (Experience 0, Reputation 2) sorted descending suggest the reverse.
-- Reputation fill color by standing (shared/ReputationBar.lua), same ranges as 3.3.5
-- FACTION_BAR_COLORS.
-- The experience bar hides at max level and reputation moves down to its place (camelot
-- StatusTrackingBarManager fills containers from the bottom). Reputation hides when no
-- faction is watched.
-- Both bars span the bottom row (action bar, micro menu, bags) and sit on its top, measured
-- by BottomBar (ForeverUI.BottomRow). Each stays movable.

local HEIGHT = 13   -- camelot image height (1020 x 13)
local L = ForeverUI.L

local ATLAS_REPUTATION = {
	"ui-hud-experiencebar-fill-reputation-faction-red-camelot",     -- hated
	"ui-hud-experiencebar-fill-reputation-faction-red-camelot",     -- hostile
	"ui-hud-experiencebar-fill-reputation-faction-orange-camelot",  -- unfriendly
	"ui-hud-experiencebar-fill-reputation-faction-yellow-camelot",  -- neutral
	"ui-hud-experiencebar-fill-reputation-faction-green-camelot",   -- friendly
	"ui-hud-experiencebar-fill-reputation-faction-green-camelot",   -- honored
	"ui-hud-experiencebar-fill-reputation-faction-green-camelot",   -- revered
	"ui-hud-experiencebar-fill-reputation-faction-green-camelot",   -- exalted
}

-- Crops a fill to the fraction. The image has rounded ends: cutting it on the right gives
-- the straight edge of a partial fill. width: bar width at 100 %.
local function populate(texture, atlas, fraction, width)
	local e = atlas and ForeverUI.AtlasEntry(atlas)
	if not e or not fraction or fraction ~= fraction or fraction <= 0 then
		texture:Hide()
		return
	end

	if fraction > 1 then
		fraction = 1
	end

	local w = width * fraction
	if w < 1 then
		texture:Hide()
		return
	end

	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[2] + (e[3] - e[2]) * fraction, e[4], e[5])
	texture:SetWidth(w)
	texture:Show()
end

local function createBar(name)
	local bar = CreateFrame("Frame", name, UIParent)
	bar:SetHeight(HEIGHT)
	bar:EnableMouse(true)

	local background = bar:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "ui-hud-experiencebar-background-camelot", true)
	background:SetAllPoints(bar)

	-- Rested part shows behind the earned part: lower layer, same left edge.
	local rested = bar:CreateTexture(nil, "BORDER")
	rested:SetPoint("LEFT", bar, "LEFT", 0, 0)
	rested:SetHeight(HEIGHT)
	rested:Hide()

	local fill = bar:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
	fill:SetHeight(HEIGHT)
	fill:Hide()

	local frame = bar:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(frame, "ui-hud-experiencebar-frame-camelot", true)
	frame:SetAllPoints(bar)

	local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER")
	text:Hide()

	bar.background, bar.rested, bar.fill, bar.frame, bar.text =
		background, rested, fill, frame, text

	bar:SetScript("OnEnter", function(self)
		self.text:Show()
	end)
	bar:SetScript("OnLeave", function(self)
		self.text:Hide()
	end)

	return bar
end

local experience = createBar("ForeverUIExperienceBar")
local reputation = createBar("ForeverUIReputationBar")

-- Reputation: just above experience, or in its place when experience is hidden (max level)
local function placeReputation()
	local rowLine = ForeverUI.BottomRow
	if not rowLine then
		return
	end
	local center = (rowLine.left + rowLine.right) / 2
	local y = experience:IsShown() and rowLine.top + HEIGHT or rowLine.top
	ForeverUI.Layout.SetDefaults("reputationbar", "BOTTOM", "BOTTOM", center, y)
end

-- ---------- Experience
local function updateExperience()
	local maximum = UnitXPMax("player")
	local level = UnitLevel("player")
	local maxLevel = MAX_PLAYER_LEVEL or 80

	if not maximum or maximum <= 0 or (level and level >= maxLevel) then
		experience:Hide()
		placeReputation()
		return
	end

	experience:Show()
	placeReputation()

	local width = experience:GetWidth()
	local earned = UnitXP("player")
	local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
	local fraction = earned / maximum

	populate(experience.rested, "ui-hud-experiencebar-fill-rested-camelot",
		(earned + rested) / maximum, width)
	populate(experience.fill, "ui-hud-experiencebar-fill-experience-camelot",
		fraction, width)

	experience.text:SetText(string.format("%d / %d  (%d%%)", earned, maximum,
		math.floor(fraction * 100)))
end

-- ---------- Reputation
local function updateReputation()
	local name, standingId, minimum, maximum, value = GetWatchedFactionInfo()
	if not name or not maximum or maximum <= minimum then
		reputation:Hide()
		return
	end

	reputation:Show()

	local span = maximum - minimum
	local earned = value - minimum
	local fraction = earned / span

	populate(reputation.fill, ATLAS_REPUTATION[standingId] or ATLAS_REPUTATION[4],
		fraction, reputation:GetWidth())

	reputation.text:SetText(string.format("%s  %d / %d", name, earned, span))
end

-- ---------- Placement
-- Both bars span the row (action bar, micro menu, bags) and touch: experience on the row,
-- reputation just above (or on the row without experience).
local function place()
	local rowLine = ForeverUI.BottomRow
	if not rowLine then
		return
	end

	local width = rowLine.right - rowLine.left
	local center = (rowLine.left + rowLine.right) / 2

	experience:SetWidth(width)
	reputation:SetWidth(width)

	ForeverUI.Layout.SetDefaults("experiencebar", "BOTTOM", "BOTTOM", center, rowLine.top)
	placeReputation()
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("PLAYER_XP_UPDATE")
listener:RegisterEvent("PLAYER_LEVEL_UP")
listener:RegisterEvent("UPDATE_EXHAUSTION")
listener:RegisterEvent("UPDATE_FACTION")
listener:SetScript("OnEvent", function(_self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		-- The client's bars: experience, rested tick, and reputation, which re-places itself on
		-- every update.
		ForeverUI.Suppress(MainMenuExpBar)
		ForeverUI.Suppress(ExhaustionTick)
		ForeverUI.Suppress(ReputationWatchBar)
		place()
	end
	updateExperience()
	updateReputation()
end)

ForeverUI.Layout.Register(experience, "experiencebar", L.STATUSBARS_EDIT_LABEL_EXPERIENCE, "BOTTOM", "BOTTOM", 0, 54)
ForeverUI.Layout.Register(reputation, "reputationbar", L.STATUSBARS_EDIT_LABEL_REPUTATION, "BOTTOM", "BOTTOM", 0, 67)
place()
updateExperience()
updateReputation()

ForeverUI.ReputationBar = reputation
ForeverUI.StatusBarsUpdate = function()
	updateExperience()
	updateReputation()
end
-- the row changed width (BottomBar.lua: a micro button was added)
ForeverUI.StatusBarsLayout = function()
	place()
	updateExperience()
	updateReputation()
end

ForeverUI.StatusBarsDebug = function()
	local rowLine = ForeverUI.BottomRow or {}
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r " .. L.STATUSBARS_DEBUG,
		rowLine.left or 0, rowLine.right or 0, tostring(rowLine.top),
		experience:GetWidth(),
		tostring(experience:IsShown()), tostring(select(5, experience:GetPoint(1))),
		tostring(reputation:IsShown()), tostring(select(5, reputation:GetPoint(1)))))
	-- what decides the reputation's place: level, the client's max level, XP to earn, default
	-- place, saved place
	local system = ForeverUI.Layout.systems["reputationbar"]
	local saved = ForeverUIDB and ForeverUIDB.positions and ForeverUIDB.positions["reputationbar"]
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r " .. L.STATUSBARS_DEBUG_STATE,
		tostring(UnitLevel("player")), tostring(MAX_PLAYER_LEVEL), tostring(UnitXPMax("player")),
		tostring(system and system.defaults and system.defaults.y), tostring(saved and saved.y),
		tostring(reputation.IsUserPlaced and reputation:IsUserPlaced())))
end
