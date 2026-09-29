-- Minimap in camelot style: mainline Minimap.xml as reskinned by camelot Skin.lua and Diel.lua.
-- The client's Minimap frame is kept (only the client draws terrain, blips and the player
-- arrow): it is resized, masked and scaled, and everything around it is replaced.
-- Sizes and anchors: mainline Minimap.xml, GameTime.xml and Blizzard_TimeManager.xml.

ForeverUI = ForeverUI or {}

-- Cluster and container. Frame 253 x 253 is the c60 atlas size (camelot Skin.lua); the map
-- keeps 198. 3.3.5 SetMaskTexture takes a file path, not an atlas name.
local CLUSTER_W, CLUSTER_H = 256, 256
local MOUSE_MARGINS = { 30, 10, 0, 30 }   -- left, right, top, bottom

local ATLAS_FRAME = "ui-hud-minimap-frame-c60"
local FRAME_W, FRAME_H = 253, 253
local MASK_PATH = "interface\\ForeverUI\\hud\\uiminimapmaskgeneralc60"

local CONTAINER_X, CONTAINER_Y = 10, -30
local MAP_SIDE = 198

-- 3.3.5 draws out-of-range arrows (corpse, quest, POI) at a fixed radius in map units, sized
-- for its 140 px map, and no method changes it. So the map keeps size 140 and gets scale
-- 198 / 140: it still shows 198 wide on screen, and the arrows reach its edge.
local CLIENT_MAP = 140
local MAP_SCALE = MAP_SIDE / CLIENT_MAP

-- Arrow images shrunk by 140 / 198 (tools/shrink_arrows.py) to undo the scale. The party arrow
-- has no setter: its shrunk file replaces the original in patch-Z.
local ARROWS = {
	path = "interface\\ForeverUI\\minimap\\",
	{ method = "SetStaticPOIArrowTexture", file = "rotating-minimaparrow" },
	{ method = "SetPOIArrowTexture", file = "rotating-minimapguidearrow" },
	{ method = "SetCorpsePOIArrowTexture", file = "rotating-minimapcorpsearrow" },
}

-- Zone name bar
local BAR_KIT = "ui-hud-minimap-button"
local BAR_W, BAR_H = 175, 16
local BAR_X, BAR_Y = 15, -4
local ZONE_W, ZONE_H = 135, 12
local ZONE_X = 4
local TEXT_W, TEXT_H = 130, 12
local TEXT_Y = 1

-- Tracking and mail
local TRACKING_SIDE = 17
local TRACKING_X = -2
local TRACKING_BUTTON_W, TRACKING_BUTTON_H = 13, 14
local MAIL_W, MAIL_H = 20, 15

-- Zoom (buttons hidden unless hovered)
local ZOOM_ZONE = 40
local ZOOM_ZONE_X, ZOOM_ZONE_Y = 77, -77
local ZOOM_PLUS_W, ZOOM_PLUS_H = 17, 17
local ZOOM_PLUS_X, ZOOM_PLUS_Y = 88, -68
local ZOOM_MINUS_W, ZOOM_MINUS_H = 17, 9
local ZOOM_MINUS_X, ZOOM_MINUS_Y = 72, -84

-- Day/night ring (camelot Diel.lua). 3.3.5 has no DIEL_CYCLE_CHANGED or IsDayTime, only the
-- server hour: day is 6 h to 18 h.
local ATLAS_CYCLE = "ui-hud-minimap-frame-cycle-c60"
local ATLAS_DAY = "ui-hud-minimap-daycycle-c60"
local ATLAS_NIGHT = "ui-hud-minimap-nightcycle-c60"
local CYCLE_SIDE = 42
local ORB_SIDE = 33
local CYCLE_X, CYCLE_Y = 63, 72
local CYCLE_LEVEL = 5
local DAWN, DUSK = 6, 18
local CYCLE_PERIOD = 60          -- re-read the server hour once a minute

local DIFFICULTY_Y = -15

-- One table per element rather than one local per value: Lua 5.1 allows at most 60 upvalues
-- per function, and build() exceeded it.

-- Calendar, right of the bar
local CALENDAR = { L = 19, H = 18, X = 1, ATLAS = "ui-hud-calendar-%d-%s" }

-- Clock, in the bar
local CLOCK = {
	L = 40, H = 16, X = -4,
	MARGINS = { 8, 5, 3, 3 },
	TEXT_X = 3, TEXT_Y = 1,
-- WhiteNormalNumberFont (GameFontStyles.xml): FRIZQT__ 10, white, black shadow (1, -1).
-- 3.3.5 lacks this font object, so its settings are applied one by one.
	FONT = "Fonts\\FRIZQT__.TTF", SIZE = 10,
}

-- Player coordinates under the map (camelot MinimapPlayerCoordsMixin), every 0.1 s.
-- Formats from camelot GlobalStrings: 3.3.5 does not have them.
local COORD = {
	L = 90, H = 10, Y = -18,
	INTERVAL = 0.1,
	INTEGER = "%d, %d",          -- MINIMAP_PLAYER_COORDS_INTEGER
	TENTHS = "%.1f, %.1f",    -- MINIMAP_PLAYER_COORDS
}

-- 3.3.5 buttons camelot places elsewhere, set on the ring at our own angles: their 3.3.5
-- offsets fit a 140 map in a 192 cluster. Radius 100 is the middle of the ring's metal
-- (hole 185, metal 15 on each side).
local RING_RADIUS = 100
local RING_ITEMS = {
	{ name = "MiniMapWorldMapButton", angle = 180 },
	{ name = "MiniMapLFGFrame", angle = 215 },
	{ name = "MiniMapBattlefieldFrame", angle = 250 },
	{ name = "MiniMapRecordingButton", angle = 285 },
}

local PREFIX = "|cff66ccffForeverUI|r "
local L = ForeverUI.L

local function say(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

-- Hides a client region for good. Its own code shows it again or restores its file
-- (Minimap_UpdateRotationSetting, MiniMapTracking_Update), so texture, alpha and visibility
-- are all cleared.
local function suppress(region)
	if not region then
		return
	end
	if region.SetTexture then
		region:SetTexture(nil)
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
	if region.Hide then
		region:Hide()
	end
end

-- Puts an atlas on a button state. A 3.3.5 button has only the states its XML declares
-- (MiniMapTrackingButton has only a highlight), and Set<State>Texture takes only a file path,
-- so the sheet is set first, then the atlas rectangle on the texture it creates.
-- state: "Normal", "Pushed", "Highlight" or "Disabled"; name: atlas name
local function applyButtonState(button, state, name)
	local e = ForeverUI.AtlasEntry(name)
	if not e then
		return nil
	end
	local texture = button["Get" .. state .. "Texture"](button)
	if not texture then
		button["Set" .. state .. "Texture"](button, e[1])
		texture = button["Get" .. state .. "Texture"](button)
	end
	if texture then
		ForeverUI.SetAtlas(texture, name, true)
	end
	return texture
end

-- Nine-slice with one atlas per piece (camelot UniqueCornersLayout), unlike
-- ForeverUI.SetAtlasNineSlice which cuts one image. The `_` and `!` prefixes are part of the
-- names (tile flags); 3.3.5 cannot tile an atlas rectangle, so pieces stretch (the edges are
-- gradients). kit: atlas name prefix; layer: draw layer
local function sliceNine(frame, kit, layer)
	local p = {}

	local function piece(name, keepSize)
		local t = frame:CreateTexture(nil, layer or "BACKGROUND")
		if not ForeverUI.SetAtlas(t, name, keepSize) then
			t:Hide()
		end
		return t
	end

	p.topLeftCorner = piece(kit .. "-nineslice-cornertopleft")
	p.topLeftCorner:SetPoint("TOPLEFT", frame, "TOPLEFT")

	p.topRightCorner = piece(kit .. "-nineslice-cornertopright")
	p.topRightCorner:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

	p.bottomLeftCorner = piece(kit .. "-nineslice-cornerbottomleft")
	p.bottomLeftCorner:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")

	p.bottomRightCorner = piece(kit .. "-nineslice-cornerbottomright")
	p.bottomRightCorner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

	-- Edges and center are anchored between opposite corners: no size to compute.
	p.topEdge = piece("_" .. kit .. "-nineslice-edgetop", true)
	p.topEdge:SetPoint("TOPLEFT", p.topLeftCorner, "TOPRIGHT")
	p.topEdge:SetPoint("BOTTOMRIGHT", p.topRightCorner, "BOTTOMLEFT")

	p.bottomEdge = piece("_" .. kit .. "-nineslice-edgebottom", true)
	p.bottomEdge:SetPoint("TOPLEFT", p.bottomLeftCorner, "TOPRIGHT")
	p.bottomEdge:SetPoint("BOTTOMRIGHT", p.bottomRightCorner, "BOTTOMLEFT")

	p.leftEdge = piece("!" .. kit .. "-nineslice-edgeleft", true)
	p.leftEdge:SetPoint("TOPLEFT", p.topLeftCorner, "BOTTOMLEFT")
	p.leftEdge:SetPoint("BOTTOMRIGHT", p.bottomLeftCorner, "TOPRIGHT")

	p.rightEdge = piece("!" .. kit .. "-nineslice-edgeright", true)
	p.rightEdge:SetPoint("TOPLEFT", p.topRightCorner, "BOTTOMLEFT")
	p.rightEdge:SetPoint("BOTTOMRIGHT", p.bottomRightCorner, "TOPRIGHT")

	p.center = piece(kit .. "-nineslice-center", true)
	p.center:SetPoint("TOPLEFT", p.topLeftCorner, "BOTTOMRIGHT")
	p.center:SetPoint("BOTTOMRIGHT", p.bottomRightCorner, "TOPLEFT")

	return p
end

-- Places a frame on the ring at angle degrees: 0 is east, counterclockwise.
local function placeOnRing(frame, map, angle)
	local radians = angle * math.pi / 180
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", map, "CENTER",
		RING_RADIUS * math.cos(radians), RING_RADIUS * math.sin(radians))
end

local M = {}
ForeverUI.Minimap = M

-- Day of the month shown by the calendar image, as in camelot. The 3.3.5 GameTimeFrame_SetDate
-- writes it as text; it still runs (it tracks day changes) and its text is hidden.
function M.updateCalendar()
	local button = _G["GameTimeFrame"]
	if not button then
		return
	end
	local day = 1
	if CalendarGetDate then
		local _, _, j = CalendarGetDate()
		day = j or day
	end
	applyButtonState(button, "Normal", string.format(CALENDAR.ATLAS, day, "up"))
	applyButtonState(button, "Pushed", string.format(CALENDAR.ATLAS, day, "down"))
	local hover = applyButtonState(button, "Highlight", string.format(CALENDAR.ATLAS, day, "mouseover"))
	if hover then
		hover:SetBlendMode("BLEND")
	end
	local text = button.GetFontString and button:GetFontString()
	if text then
		text:SetAlpha(0)
	end
end

-- Clock: its 3.3.5 background is an unnamed texture (ClockBackground), found among the
-- regions; the text and the alarm glow are kept.
function M.skinClock()
	local clock = _G["TimeManagerClockButton"]
	local bar = M.bar
	if not clock or not bar then
		return
	end
	local text = _G["TimeManagerClockTicker"]
	local alarm = _G["TimeManagerAlarmFiredTexture"]
	for _, region in ipairs({ clock:GetRegions() }) do
		if region ~= text and region ~= alarm then
			suppress(region)
		end
	end
	clock:SetParent(M.cluster)
	clock:SetWidth(CLOCK.L)
	clock:SetHeight(CLOCK.H)
	clock:ClearAllPoints()
	clock:SetPoint("TOPRIGHT", bar, "TOPRIGHT", CLOCK.X, 0)
	clock:SetFrameLevel(bar:GetFrameLevel() + 1)
	clock:SetHitRectInsets(CLOCK.MARGINS[1], CLOCK.MARGINS[2],
		CLOCK.MARGINS[3], CLOCK.MARGINS[4])
	if text then
		text:SetFont(CLOCK.FONT, CLOCK.SIZE)
		text:SetShadowOffset(1, -1)
		text:SetShadowColor(0, 0, 0, 1)
		text:SetTextColor(1, 1, 1)
		text:ClearAllPoints()
		text:SetPoint("CENTER", clock, "CENTER", CLOCK.TEXT_X, CLOCK.TEXT_Y)
	end
	M.clockSkinned = true
end

-- 3.3.5 GetPlayerMapPosition answers for the map shown by the world map, so it is set back to
-- the player's zone on zone change and when the world map closes, never while it is open.
-- In instances 3.3.5 returns (0, 0) and nothing is shown.
function M.recenterWorldMap()
	if SetMapToCurrentZone and not (WorldMapFrame and WorldMapFrame:IsShown()) then
		SetMapToCurrentZone()
	end
end

function M.updateCoordinates()
	local coords = M.coords
	if not coords then
		return
	end
	local x, y = 0, 0
	if GetPlayerMapPosition then
		x, y = GetPlayerMapPosition("player")
	end
	if not x or not y or (x == 0 and y == 0) then
		coords.text:SetText("")
		return
	end
	if GetCVar and GetCVar("coordsByTenths") == "1" then
		coords.text:SetText(string.format(COORD.TENTHS, x * 100, y * 100))
	else
		coords.text:SetText(string.format(COORD.INTEGER,
			math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5)))
	end
end

-- Applies scale k to the map: its size becomes 198 / k, so it stays 198 on screen. Children the
-- addon places (MinimapBackdrop, zoom hit area) get 1 / k to keep their size. MinimapPing
-- follows the map: Minimap_SetPing works in map units.
local function applyScale(k)
	local map = M.map
	if not map then
		return
	end
	M.scale = k
	map:SetScale(k)
	map:SetWidth(MAP_SIDE / k)
	map:SetHeight(MAP_SIDE / k)
	for _, childFrame in ipairs({ _G["MinimapBackdrop"], M.zoomZone }) do
		if childFrame then
			childFrame:SetScale(1 / k)
		end
	end
end

M.applyScale = applyScale

-- Reskins the cluster; returns false when client frames or AtlasUtil are missing.
local function build()
	local cluster = _G["MinimapCluster"]
	local map = _G["Minimap"]
	local background = _G["MinimapBackdrop"]

	if not cluster or not map or not background then
		say(L.MINIMAP_DEBUG_NO_CLIENT_FRAMES)
		return false
	end

	if not ForeverUI.SetAtlas then
		say(L.MINIMAP_DEBUG_NO_ATLASUTIL)
		return false
	end

	M.cluster = cluster
	M.map = map

	-- 1. Cluster: same mouse margins as 3.3.5, new size.
	cluster:SetWidth(CLUSTER_W)
	cluster:SetHeight(CLUSTER_H)
	cluster:SetFrameStrata("LOW")
	cluster:SetHitRectInsets(MOUSE_MARGINS[1], MOUSE_MARGINS[2],
		MOUSE_MARGINS[3], MOUSE_MARGINS[4])

	suppress(_G["MinimapBorderTop"])

	-- 2. Container and map.
	local container = M.container
	if not container then
		container = CreateFrame("Frame", "ForeverUIMinimapContainer", cluster)
		M.container = container
	end
	container:SetWidth(FRAME_W)
	container:SetHeight(FRAME_H)
	container:ClearAllPoints()
	container:SetPoint("TOP", cluster, "TOP", CONTAINER_X, CONTAINER_Y)

	map:SetParent(container)
	map:ClearAllPoints()
	map:SetPoint("CENTER", container, "CENTER", 0, 0)
	map:SetMaskTexture(MASK_PATH)
	for _, arrow in ipairs(ARROWS) do
		if map[arrow.method] then
			map[arrow.method](map, ARROWS.path .. arrow.file)
		end
	end

	-- 3. Frame ring on MinimapBackdrop, as in camelot: a child of the map, it draws above the
	-- terrain, and its own children (the buttons) draw above it.
	-- MinimapCompassTexture is the 3.3.5 compass here, not camelot's frame of the same name.
	background:SetWidth(FRAME_W)
	background:SetHeight(FRAME_H)
	background:ClearAllPoints()
	background:SetPoint("CENTER", map, "CENTER", 0, 0)

	suppress(_G["MinimapBorder"])
	suppress(_G["MinimapNorthTag"])
	suppress(_G["MinimapCompassTexture"])

	local ring = M.ring
	if not ring then
		ring = background:CreateTexture(nil, "ARTWORK")
		M.ring = ring
	end
	ForeverUI.SetAtlas(ring, ATLAS_FRAME, true)
	ring:SetWidth(FRAME_W)
	ring:SetHeight(FRAME_H)
	ring:ClearAllPoints()
	ring:SetPoint("CENTER", background, "CENTER", 0, 0)

	-- 4. Zone name bar.
	local bar = M.bar
	if not bar then
		bar = CreateFrame("Frame", "ForeverUIMinimapBorderTop", cluster)
		M.bar = bar
		sliceNine(bar, BAR_KIT, "BACKGROUND")
	end
	bar:SetWidth(BAR_W)
	bar:SetHeight(BAR_H)
	bar:ClearAllPoints()
	bar:SetPoint("TOP", cluster, "TOP", BAR_X, BAR_Y)

	local zoneButton = _G["MinimapZoneTextButton"]
	if zoneButton then
		zoneButton:SetParent(cluster)
		zoneButton:SetWidth(ZONE_W)
		zoneButton:SetHeight(ZONE_H)
		zoneButton:ClearAllPoints()
		zoneButton:SetPoint("LEFT", bar, "LEFT", ZONE_X, 0)
		zoneButton:SetFrameLevel(bar:GetFrameLevel() + 1)
	end

	local zoneText = _G["MinimapZoneText"]
	if zoneText then
		zoneText:SetWidth(TEXT_W)
		zoneText:SetHeight(TEXT_H)
		zoneText:ClearAllPoints()
		zoneText:SetPoint("CENTER", zoneButton or bar, "CENTER", 0, TEXT_Y)
		zoneText:SetDrawLayer("OVERLAY")
		-- Left justification comes from the camelot template attribute; GameFontNormal has none.
		zoneText:SetJustifyH("LEFT")
		zoneText:SetJustifyV("MIDDLE")
	end

	-- 5. Tracking: the client frame stays (it opens the tracking menu), only reskinned.
	local tracking = _G["MiniMapTracking"]
	if tracking then
		tracking:SetParent(cluster)
		tracking:SetWidth(TRACKING_SIDE)
		tracking:SetHeight(TRACKING_SIDE)
		tracking:ClearAllPoints()
		tracking:SetPoint("RIGHT", bar, "LEFT", TRACKING_X, 0)
		tracking:SetFrameLevel(bar:GetFrameLevel() + 1)

		suppress(_G["MiniMapTrackingBackground"])
		suppress(_G["MiniMapTrackingIcon"])
		suppress(_G["MiniMapTrackingIconOverlay"])

		if not M.trackingBackground then
			M.trackingBackground = tracking:CreateTexture(nil, "BACKGROUND")
		end
		ForeverUI.SetAtlas(M.trackingBackground, BAR_KIT, true)
		M.trackingBackground:SetAllPoints(tracking)

		local button = _G["MiniMapTrackingButton"]
		if button then
			button:SetWidth(TRACKING_BUTTON_W)
			button:SetHeight(TRACKING_BUTTON_H)
			button:ClearAllPoints()
			button:SetPoint("CENTER", tracking, "CENTER", 0, 0)
			button:SetHitRectInsets(0, 0, 0, 0)

			suppress(_G["MiniMapTrackingButtonBorder"])
			suppress(_G["MiniMapTrackingButtonShine"])

			applyButtonState(button, "Normal", "ui-hud-minimap-tracking-up")
			applyButtonState(button, "Pushed", "ui-hud-minimap-tracking-down")
			local hover = applyButtonState(button, "Highlight", "ui-hud-minimap-tracking-mouseover")
			if hover then
				hover:SetBlendMode("BLEND")
			end
		end
	end

	-- 6. Mail, under tracking.
	local rowLine = M.rowLine
	if not rowLine then
		rowLine = CreateFrame("Frame", "ForeverUIMinimapIndicators", cluster)
		M.rowLine = rowLine
	end
	rowLine:SetWidth(MAIL_W)
	rowLine:SetHeight(MAIL_H)
	rowLine:ClearAllPoints()
	rowLine:SetPoint("TOPRIGHT", tracking or bar, "BOTTOMRIGHT", 0, 0)

	local mail = _G["MiniMapMailFrame"]
	if mail then
		mail:SetParent(rowLine)
		mail:SetWidth(MAIL_W)
		mail:SetHeight(MAIL_H)
		mail:ClearAllPoints()
		mail:SetPoint("TOPLEFT", rowLine, "TOPLEFT", 0, 0)

		suppress(_G["MiniMapMailIcon"])
		suppress(_G["MiniMapMailBorder"])

		if not M.mailIcon then
			M.mailIcon = mail:CreateTexture(nil, "ARTWORK")
		end
		ForeverUI.SetAtlas(M.mailIcon, "ui-hud-minimap-mail-up")
		M.mailIcon:ClearAllPoints()
		M.mailIcon:SetPoint("TOPLEFT", mail, "TOPLEFT", 0, 0)
	end

	-- 7. Zoom. The hit area uses the BACKGROUND strata, as in camelot, so it takes the mouse only
	-- where nothing else does and does not steal map clicks.
	local zoomZone = M.zoomZone
	if not zoomZone then
		zoomZone = CreateFrame("Frame", "ForeverUIMinimapZoomHitArea", map)
		zoomZone:EnableMouse(true)
		zoomZone:SetFrameStrata("BACKGROUND")
		M.zoomZone = zoomZone
	end
	zoomZone:SetWidth(ZOOM_ZONE)
	zoomZone:SetHeight(ZOOM_ZONE)
	zoomZone:ClearAllPoints()
	zoomZone:SetPoint("CENTER", map, "CENTER", ZOOM_ZONE_X, ZOOM_ZONE_Y)

	local plus = _G["MinimapZoomIn"]
	local minus = _G["MinimapZoomOut"]

	local function skinZoom(button, width, height, x, y, name)
		if not button then
			return
		end
		button:SetWidth(width)
		button:SetHeight(height)
		button:ClearAllPoints()
		button:SetPoint("CENTER", map, "CENTER", x, y)
		-- Client hit insets cut 4 px on each side of a 32 px button; a 17 px one needs none.
		button:SetHitRectInsets(0, 0, 0, 0)
		applyButtonState(button, "Normal", name)
		applyButtonState(button, "Pushed", name .. "-down")

		-- camelot desaturates the disabled state. 3.3.5 SetDesaturated returns false when the GPU
		-- cannot do it: then darken by hand.
		local disabled = applyButtonState(button, "Disabled", name)
		if disabled and not (disabled.SetDesaturated and disabled:SetDesaturated(true)) then
			disabled:SetVertexColor(0.45, 0.45, 0.45)
		end

		-- The client highlight is additive; camelot's is a full, lighter image, drawn with BLEND.
		local hover = applyButtonState(button, "Highlight", name .. "-mouseover")
		if hover then
			hover:SetBlendMode("BLEND")
		end
		button:Hide()
	end

	skinZoom(plus, ZOOM_PLUS_W, ZOOM_PLUS_H, ZOOM_PLUS_X, ZOOM_PLUS_Y,
		"ui-hud-minimap-zoom-in")
	skinZoom(minus, ZOOM_MINUS_W, ZOOM_MINUS_H, ZOOM_MINUS_X, ZOOM_MINUS_Y,
		"ui-hud-minimap-zoom-out")

	-- As MinimapMixin:OnLeave: hide the zoom buttons only when the mouse is on none of the four.
	local function showRegion()
		if plus then plus:Show() end
		if minus then minus:Show() end
	end

	local function hideIfPossible()
		if plus and plus:IsMouseOver() then return end
		if minus and minus:IsMouseOver() then return end
		if zoomZone:IsMouseOver() then return end
		if map:IsMouseOver() then return end
		if plus then plus:Hide() end
		if minus then minus:Hide() end
	end


	if not M.zoomHooked then
		map:HookScript("OnEnter", showRegion)
		map:HookScript("OnLeave", hideIfPossible)
		zoomZone:SetScript("OnEnter", showRegion)
		zoomZone:SetScript("OnLeave", hideIfPossible)
		if plus then
			plus:HookScript("OnEnter", showRegion)
			plus:HookScript("OnLeave", hideIfPossible)
		end
		if minus then
			minus:HookScript("OnEnter", showRegion)
			minus:HookScript("OnLeave", hideIfPossible)
		end
		-- Mouse wheel as camelot MinimapMixin:OnMouseWheel: clicks + or - (same effect and sound,
		-- nothing when disabled). 3.3.5 does not give the wheel to the map.
		-- IsEnabled returns 0 or 1, and 0 is true in Lua.
		local function click(button)
			local state = button and button:IsEnabled()
			if state and state ~= 0 then button:Click() end
		end
		map:EnableMouseWheel(true)
		map:SetScript("OnMouseWheel", function(_, direction)
			if direction > 0 then
				click(plus)
			elseif direction < 0 then
				click(minus)
			end
		end)
		M.zoomHooked = true
	end

	-- 8. Day/night ring.
	local cycle = M.cycle
	if not cycle then
		cycle = CreateFrame("Frame", "ForeverUIMinimapDiel", cluster)
		cycle:SetFrameLevel(CYCLE_LEVEL)
		M.cycle = cycle
		M.orb = cycle:CreateTexture(nil, "BACKGROUND")
		M.orb:SetPoint("CENTER", cycle, "CENTER", 0, 0)
		M.cycleEdge = cycle:CreateTexture(nil, "OVERLAY")
		M.cycleEdge:SetAllPoints(cycle)
	end
	cycle:SetWidth(CYCLE_SIDE)
	cycle:SetHeight(CYCLE_SIDE)
	cycle:ClearAllPoints()
	cycle:SetPoint("CENTER", cluster, "CENTER", CYCLE_X, CYCLE_Y)
	ForeverUI.SetAtlas(M.cycleEdge, ATLAS_CYCLE, true)
	M.orb:SetWidth(ORB_SIDE)
	M.orb:SetHeight(ORB_SIDE)

	-- 9. Instance difficulty, at the bar's corner.
	local difficulty = _G["MiniMapInstanceDifficulty"]
	if difficulty then
		difficulty:SetParent(cluster)
		difficulty:ClearAllPoints()
		difficulty:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, DIFFICULTY_Y)
	end

	-- 10. Calendar, right of the bar.
	local calendar = _G["GameTimeFrame"]
	if calendar then
		calendar:SetParent(cluster)
		calendar:SetWidth(CALENDAR.L)
		calendar:SetHeight(CALENDAR.H)
		calendar:ClearAllPoints()
		calendar:SetPoint("TOPLEFT", bar, "TOPRIGHT", CALENDAR.X, 0)
		calendar:SetFrameLevel(bar:GetFrameLevel() + 1)
		-- 3.3.5 gives it hit insets of 6/0/5/10 for a 40 px button; camelot declares none.
		calendar:SetHitRectInsets(0, 0, 0, 0)
		M.updateCalendar()
	end

	-- 11. Clock, in the bar. Blizzard_TimeManager loads on demand: ADDON_LOADED skins it later.
	M.skinClock()

	-- 12. Player coordinates under the map, a sibling of the map in the container
	-- (camelot PlayerCoords).
	local coords = M.coords
	if not coords then
		coords = CreateFrame("Frame", "ForeverUIMinimapPlayerCoords", container)
		coords.text = coords:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		coords.text:SetAllPoints(coords)
		coords.text:SetJustifyH("CENTER")
		coords.pending = 0
		coords:SetScript("OnUpdate", function(self, elapsed)
			self.pending = self.pending - (elapsed or 0)
			if self.pending > 0 then
				return
			end
			self.pending = COORD.INTERVAL
			M.updateCoordinates()
		end)
		M.coords = coords
	end
	coords:SetWidth(COORD.L)
	coords:SetHeight(COORD.H)
	coords:ClearAllPoints()
	coords:SetPoint("BOTTOM", map, "BOTTOM", 0, COORD.Y)

	-- 13. Scale last: the zoom hit area must exist.
	applyScale(M.scale or MAP_SCALE)

	-- 14. The buttons camelot does not have, on the ring.
	for _, item in ipairs(RING_ITEMS) do
		local button = _G[item.name]
		if button then
			button:SetParent(background)
			placeOnRing(button, map, item.angle)
		end
	end

	return true
end

-- The server hour picks sun or moon; 3.3.5 has no cycle event, so it is read once a minute.
local function updateCycle()
	if not M.orb then
		return
	end
	local hour = GetGameTime and GetGameTime() or 12
	local day = hour >= DAWN and hour < DUSK
	M.day = day
	ForeverUI.SetAtlas(M.orb, day and ATLAS_DAY or ATLAS_NIGHT, true)
end

M.Refresh = function()
	if M.cluster then
		updateCycle()
	end
end

local listener = CreateFrame("Frame")
listener.elapsed = 0
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("MINIMAP_UPDATE_ZOOM")
listener:RegisterEvent("ADDON_LOADED")
listener:RegisterEvent("ZONE_CHANGED_NEW_AREA")
listener:SetScript("OnEvent", function(_self, event, arg1)
	if event == "PLAYER_ENTERING_WORLD" then
		build()
		updateCycle()
		M.recenterWorldMap()
	elseif event == "ADDON_LOADED" then
		if arg1 == "Blizzard_TimeManager" then
			M.skinClock()
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		M.recenterWorldMap()
	elseif event == "MINIMAP_UPDATE_ZOOM" then
		-- As MinimapMixin:OnEvent: disable a zoom button at the end of its range.
		local plus, minus = _G["MinimapZoomIn"], _G["MinimapZoomOut"]
		local map = M.map
		if plus and minus and map and map.GetZoom and map.GetZoomLevels then
			local level = map:GetZoom()
			if level == map:GetZoomLevels() - 1 then plus:Disable() else plus:Enable() end
			if level == 0 then minus:Disable() else minus:Enable() end
		end
	end
end)

listener:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = self.elapsed + (elapsed or 0)
	if self.elapsed < CYCLE_PERIOD then
		return
	end
	self.elapsed = 0
	updateCycle()
end)

-- The client calls GameTimeFrame_SetDate on each day change: reapply the calendar image.
if hooksecurefunc and GameTimeFrame_SetDate then
	hooksecurefunc("GameTimeFrame_SetDate", function() M.updateCalendar() end)
end
if WorldMapFrame and WorldMapFrame.HookScript then
	WorldMapFrame:HookScript("OnHide", function() M.recenterWorldMap() end)
end

if build() then
	updateCycle()
	-- Registered with the layout like every frame, so the player can move it.
	if ForeverUI.Layout and ForeverUI.Layout.Register then
		ForeverUI.Layout.Register(_G["MinimapCluster"], "minimap", MINIMAP_LABEL,
			"TOPRIGHT", "TOPRIGHT", 0, 0)
	end
end


-- /fui minimap: prints each element's size and state; "scale <k>" sets the map scale.
ForeverUI.MinimapDebug = function(argument)
	local cluster, map = M.cluster, M.map
	if not cluster or not map then
		say(L.MINIMAP_DEBUG_NOTHING_BUILT)
		return
	end

	-- /fui minimap scale <k>: set the map scale until the next /reload; without k, the default.
	if argument and string.match(argument, "^scale%s*$") then
		argument = "scale " .. MAP_SCALE
	end
	local k = argument and tonumber(string.match(argument, "^scale%s+([%d%.]+)$"))
	if k and k > 0 then
		applyScale(k)
		say(string.format(L.MINIMAP_DEBUG_SCALE,
			k, map:GetWidth(), map:GetWidth() * k))
		return
	end

	local function row(text)
		DEFAULT_CHAT_FRAME:AddMessage("   " .. text)
	end

	say(string.format(L.MINIMAP_DEBUG_SIZES,
		cluster:GetWidth(), cluster:GetHeight(),
		M.container:GetWidth(), M.container:GetHeight(), map:GetWidth()))
	row(string.format(L.MINIMAP_DEBUG_FRAME,
		ATLAS_FRAME, MASK_PATH, M.scale or 1, MAP_SCALE))
	row(string.format(L.MINIMAP_DEBUG_ZONE,
		tostring(_G["MinimapZoneText"] and _G["MinimapZoneText"]:GetText()),
		tostring(_G["MinimapZoneText"] and _G["MinimapZoneText"]:GetJustifyH()),
		_G["MinimapZoneText"] and _G["MinimapZoneText"]:GetWidth() or 0))
	row(string.format(L.MINIMAP_DEBUG_ZOOM,
		tostring(map:GetZoom()), tostring(map:GetZoomLevels()),
		tostring(_G["MinimapZoomIn"] and _G["MinimapZoomIn"]:IsShown()),
		tostring(_G["MinimapZoomOut"] and _G["MinimapZoomOut"]:IsShown())))
	row(string.format(L.MINIMAP_DEBUG_CYCLE, tostring(GetGameTime and GetGameTime()),
		M.day and L.MINIMAP_DEBUG_DAY or L.MINIMAP_DEBUG_NIGHT))

	row(string.format(L.MINIMAP_DEBUG_CLOCK,
		_G["TimeManagerClockButton"] and (M.clockSkinned and L.MINIMAP_DEBUG_SKINNED or L.MINIMAP_DEBUG_NOT_SKINNED) or L.MINIMAP_DEBUG_NOT_LOADED,
		_G["GameTimeFrame"] and (_G["GameTimeFrame"]:IsShown() and L.MINIMAP_DEBUG_VISIBLE or L.MINIMAP_DEBUG_HIDDEN) or L.MINIMAP_DEBUG_ABSENT,
		tostring(M.coords and M.coords.text:GetText())))

	for _, item in ipairs(RING_ITEMS) do
		local button = _G[item.name]
		row(string.format(L.MINIMAP_DEBUG_BUTTON, item.name,
			button and (button:IsShown() and L.MINIMAP_DEBUG_VISIBLE or L.MINIMAP_DEBUG_HIDDEN) or L.MINIMAP_DEBUG_ABSENT,
			item.angle))
	end
end
