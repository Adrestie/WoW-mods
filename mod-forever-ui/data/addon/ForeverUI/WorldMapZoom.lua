-- World map zoom: the mouse wheel scales the map toward the cursor (x 1.25 per step, 1 to 4)
-- and a left-button drag pans the zoomed map; a click without drag keeps its meaning.
-- Camelot zooms through map art layers (mapcanvas_scrollcontainermixin.lua), which 3.3.5
-- lacks. The zoom returns to 1 when the map changes, changes mode or closes.

local W = ForeverUI.WorldMap
local Z = { z = 1, cx = 0.5, cy = 0.5, active = false, STEP = 1.25, MAX = 4, THRESHOLD = 4 }
W.zoom = Z

local CARD_W, CARD_H = 1002, 668
local TILE, COLUMNS, ROWS = 256, 4, 3

local function tile(k)
	return _G["WorldMapDetailTile" .. k]
end

local function ready()
	return W.built and W.canvas and WorldMapDetailFrame and WorldMapButton and WORLDMAP_SETTINGS
end

-- The view: the canvas rectangle in WorldMapDetailFrame units (WorldMapButton has the same
-- scale and corner), origin at the map's top left
local function viewSize()
	local c, d = W.canvas, WorldMapDetailFrame
	local k = c:GetEffectiveScale() / d:GetEffectiveScale()
	return c:GetWidth() * k, c:GetHeight() * k
end

local function view()
	local vw, vh = viewSize()
	local x, y = Z.cx * CARD_W, Z.cy * CARD_H
	return x - vw / 2, y - vh / 2, x + vw / 2, y + vh / 2
end
Z.view = view

-- Keep the center where the view stays inside the map
local function clampView()
	local vw, vh = viewSize()
	local halfX, halfY = vw / 2 / CARD_W, vh / 2 / CARD_H
	if halfX >= 0.5 then Z.cx = 0.5 else Z.cx = math.max(halfX, math.min(1 - halfX, Z.cx)) end
	if halfY >= 0.5 then Z.cy = 0.5 else Z.cy = math.max(halfY, math.min(1 - halfY, Z.cy)) end
end

-- ---------------------------------------------------------------- Tiles

-- 3.3.5 clips nothing outside a ScrollFrame and client frames are never reparented, so each
-- tile is cropped to the view: its visible part, at its place, with matching tex coords
local function cropTexture()
	local d = WorldMapDetailFrame
	local x0, y0, x1, y1 = view()
	for rowLine = 1, ROWS do
		for column = 1, COLUMNS do
			local t = tile((rowLine - 1) * COLUMNS + column)
			if t then
				local tx, ty = (column - 1) * TILE, (rowLine - 1) * TILE
				local ix0, iy0 = math.max(tx, x0), math.max(ty, y0)
				local ix1 = math.min(tx + TILE, CARD_W, x1)
				local iy1 = math.min(ty + TILE, CARD_H, y1)
				t:ClearAllPoints()
				if ix1 - ix0 < 0.01 or iy1 - iy0 < 0.01 then
					t:SetPoint("TOPLEFT", d, "TOPLEFT", tx, -ty)
					t:SetWidth(1)
					t:SetHeight(1)
					t:SetAlpha(0)
				else
					t:SetPoint("TOPLEFT", d, "TOPLEFT", ix0, -iy0)
					t:SetWidth(ix1 - ix0)
					t:SetHeight(iy1 - iy0)
					t:SetTexCoord((ix0 - tx) / TILE, (ix1 - tx) / TILE, (iy0 - ty) / TILE, (iy1 - ty) / TILE)
					t:SetAlpha(1)
				end
			end
		end
	end
end

-- Tile anchors from WorldMapFrame.xml (541-636): the first at the corner, each right of the
-- previous one, each row under the first tile of the row above; then the small-window crop
-- (WorldMap.lua)
local function rechainTiles()
	for k = 1, COLUMNS * ROWS do
		local t = tile(k)
		if t then
			t:ClearAllPoints()
			t:SetAlpha(1)
			if k == 1 then
				t:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT", 0, 0)
			elseif (k - 1) % COLUMNS == 0 then
				t:SetPoint("TOPLEFT", tile(k - COLUMNS), "BOTTOMLEFT", 0, 0)
			else
				t:SetPoint("TOPLEFT", tile(k - 1), "TOPRIGHT", 0, 0)
			end
		end
	end
	if W.cropTiles then W.cropTiles(true) end
end

-- --------------------------------------------------------------- Markers

-- A marker out of the view fades out and releases the mouse (invisible, it would still
-- steal hover and clicks from the quest log or the frame); back in view, it gets its alpha
-- and mouse back
local function turnOff(f)
	f.foreverZoomAlpha = f:GetAlpha()
	f.foreverZoomMouse = f.IsMouseEnabled and f:IsMouseEnabled() and true or false
	f:SetAlpha(0)
	if f.foreverZoomMouse then f:EnableMouse(false) end
end

local function restore(f)
	f:SetAlpha(f.foreverZoomAlpha)
	if f.foreverZoomMouse then f:EnableMouse(true) end
	f.foreverZoomAlpha, f.foreverZoomMouse = nil, nil
end

-- Fade out the markers outside the view, restore those back inside
local function sortBy()
	local c = W.canvas
	local e = c:GetEffectiveScale()
	local left, down, right, top = c:GetLeft(), c:GetBottom(), c:GetRight(), c:GetTop()
	if not (left and down and right and top) then return end
	left, down, right, top = left * e, down * e, right * e, top * e
	for _, parent in ipairs({ WorldMapButton, WorldMapPOIFrame }) do
		if parent then
			for _, f in ipairs({ parent:GetChildren() }) do
				if f ~= WorldMapFrameAreaFrame and f:IsShown() then
					local x, y = f:GetCenter()
					local fe = f:GetEffectiveScale()
					local inside = not x or (x * fe >= left and x * fe <= right and y * fe >= down and y * fe <= top)
					if inside then
						if f.foreverZoomAlpha then restore(f) end
					elseif not f.foreverZoomAlpha then
						turnOff(f)
					end
				end
			end
		end
	end
end

local function restoreChildren()
	for _, parent in ipairs({ WorldMapButton, WorldMapPOIFrame }) do
		if parent then
			for _, f in ipairs({ parent:GetChildren() }) do
				if f.foreverZoomAlpha then restore(f) end
			end
		end
	end
end

-- ------------------------------------------------------------- Apply

-- Current map key: a map change resets the zoom to 1
function Z.mapKey()
	return tostring(GetCurrentMapAreaID and GetCurrentMapAreaID()) .. ":" ..
		tostring(GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel())
end

-- Scales of the zoomed frames: { frame, zoomed scale, normal scale }. Markers, party and
-- quest numbers are placed in WorldMapButton / WorldMapPOIFrame units, so they follow.
local function frameScales()
	local base = WORLDMAP_SETTINGS.size
	return {
		{ WorldMapDetailFrame, base * Z.z, base },
		{ WorldMapButton, base * Z.z, base },
		{ WorldMapBlobFrame, base * Z.z, base },
		{ WorldMapPOIFrame, Z.z, 1 },
		{ WorldMapFrameAreaFrame, (Z.areaScale or 1) / Z.z, Z.areaScale or 1 },
	}
end

-- The quest blob (WorldMapBlobFrame) is drawn by the engine in one piece and would overflow,
-- so it hides while zoomed; WorldMapButton's hit rect is limited to the view.
function Z.apply()
	local d = WorldMapDetailFrame
	if not Z.active then
		Z.active = true
		Z.points = {}
		for i = 1, d:GetNumPoints() do
			Z.points[i] = { d:GetPoint(i) }
		end
		Z.areaScale = WorldMapFrameAreaFrame and WorldMapFrameAreaFrame:GetScale() or 1
		Z.key = Z.mapKey()
	end
	for _, e in ipairs(frameScales()) do
		if e[1] then e[1]:SetScale(e[2]) end
	end
	clampView()
	d:ClearAllPoints()
	d:SetPoint("CENTER", W.canvas, "CENTER", (0.5 - Z.cx) * CARD_W, (Z.cy - 0.5) * CARD_H)
	if WorldMapBlobFrame then
		WorldMapBlobFrame:SetAlpha(0)
		if WorldMapBlobFrame_CalculateHitTranslations then WorldMapBlobFrame_CalculateHitTranslations() end
	end
	local a = WorldMapFrameAreaFrame
	if a then
		a:ClearAllPoints()
		a:SetPoint("TOP", W.canvas, "TOP", 0, -10)
	end
	local x0, y0, x1, y1 = view()
	WorldMapButton:SetHitRectInsets(math.max(0, x0), math.max(0, CARD_W - x1),
		math.max(0, y0), math.max(0, CARD_H - y1))
	cropTexture()
	sortBy()
end

-- Back to the whole map. After a mode change, the client and WorldMap.lua have just set
-- their own scales and anchors: only frames still carrying our scale are restored.
function Z.reset(isModeChange)
	if not Z.active then
		Z.z = 1
		return
	end
	local zoomed = frameScales()
	Z.z = 1
	local restore = frameScales()
	for i, e in ipairs(zoomed) do
		if e[1] and math.abs(e[1]:GetScale() - e[2]) < 1e-6 then
			e[1]:SetScale(restore[i][3])
		end
	end
	Z.active = false
	local d = WorldMapDetailFrame
	if not isModeChange and Z.points then
		d:ClearAllPoints()
		for _, p in ipairs(Z.points) do
			d:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
	end
	if WorldMapBlobFrame then
		WorldMapBlobFrame:SetAlpha(1)
		if WorldMapBlobFrame_CalculateHitTranslations then WorldMapBlobFrame_CalculateHitTranslations() end
	end
	local a = WorldMapFrameAreaFrame
	if a then
		a:ClearAllPoints()
		a:SetPoint("TOP", WorldMapButton, "TOP", 0, -10)
	end
	WorldMapButton:SetHitRectInsets(0, 0, 0, 0)
	WorldMapButton:EnableMouse(true)
	Z.pressPoint, Z.dragging = nil, false
	rechainTiles()
	restoreChildren()
	Z.cx, Z.cy = 0.5, 0.5
end

-- ------------------------------------------------------------- Mouse wheel

-- Map point under the cursor, and the cursor offset from the canvas center in screen pixels
local function pointUnderCursor()
	local x, y = GetCursorPosition()
	local c = W.canvas
	local cx, cy = c:GetCenter()
	if not cx then return nil end
	local ce = c:GetEffectiveScale()
	local dx, dy = x - cx * ce, y - cy * ce
	local de = WorldMapDetailFrame:GetEffectiveScale()
	return Z.cx + dx / (CARD_W * de), Z.cy - dy / (CARD_H * de), dx, dy, de
end

function Z.wheel(direction)
	if not ready() then return end
	local old = Z.z
	local new = direction > 0 and old * Z.STEP or old / Z.STEP
	if new > Z.MAX then new = Z.MAX end
	if new < 1.0001 then new = 1 end
	if new == old then return end
	if new == 1 then
		Z.reset(false)
		return
	end
	if not Z.active then Z.cx, Z.cy = 0.5, 0.5 end
	-- Keep the point under the cursor in place (camelot: SetPanTarget)
	local fx, fy, dx, dy, de = pointUnderCursor()
	Z.z = new
	if fx then
		local de2 = de * new / old
		Z.cx = fx - dx / (CARD_W * de2)
		Z.cy = fy + dy / (CARD_H * de2)
	end
	Z.apply()
end

-- --------------------------------------------------------------- Watcher

local mapKey = Z.mapKey

-- Child of the map frame, so it only runs while the map is open
local watcher = CreateFrame("Frame", nil, WorldMapFrame)
watcher:SetScript("OnUpdate", function()
	if not (Z.active and ready()) then
		Z.key = ready() and mapKey() or nil
		return
	end
	if mapKey() ~= Z.key then
		Z.reset(false)
		Z.key = mapKey()
		return
	end
	-- Drag: past THRESHOLD pixels the map follows the cursor. WorldMapButton_OnClick navigates
	-- on mouse up, so WorldMapButton releases the mouse until the button is up. The client code
	-- is not wrapped: it closes dropdowns and would taint their state if called from the addon.
	local pressPoint = Z.pressPoint
	if pressPoint then
		local x, y = GetCursorPosition()
		if not IsMouseButtonDown("LeftButton") then
			Z.pressPoint = nil
			if Z.dragging then
				Z.dragging = false
				WorldMapButton:EnableMouse(true)
			end
		else
			if not Z.dragging and math.abs(x - pressPoint.x) + math.abs(y - pressPoint.y) > Z.THRESHOLD then
				Z.dragging = true
				WorldMapButton:EnableMouse(false)
			end
			if Z.dragging then
				local de = WorldMapDetailFrame:GetEffectiveScale()
				Z.cx = pressPoint.cx - (x - pressPoint.x) / (CARD_W * de)
				Z.cy = pressPoint.cy + (y - pressPoint.y) / (CARD_H * de)
				Z.apply()
				return
			end
		end
	end
	sortBy()
end)
Z.watcher = watcher

-- ------------------------------------------------------------ Hooks

if WorldMapButton then
	WorldMapButton:EnableMouseWheel(true)
	WorldMapButton:SetScript("OnMouseWheel", function(_, direction)
		Z.wheel(direction)
	end)
	WorldMapButton:HookScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and Z.active then
			local x, y = GetCursorPosition()
			Z.pressPoint = { x = x, y = y, cx = Z.cx, cy = Z.cy }
			Z.dragging = false
		end
	end)
	-- Player arrow: WorldMapButton_OnUpdate places it at the WotLK scale (position x
	-- WORLDMAP_SETTINGS.size); place it again x zoom, or hide it out of the view
	WorldMapButton:HookScript("OnUpdate", function()
		if not Z.active then return end
		local x, y = GetPlayerMapPosition("player")
		if not x or (x == 0 and y == 0) then return end
		local px, py = x * CARD_W, y * CARD_H
		local x0, y0, x1, y1 = view()
		if px < x0 or px > x1 or py < y0 or py > y1 then
			if ShowWorldMapArrowFrame then ShowWorldMapArrowFrame(nil) end
		elseif PositionWorldMapArrowFrame then
			local s = WORLDMAP_SETTINGS.size * Z.z
			PositionWorldMapArrowFrame("CENTER", "WorldMapDetailFrame", "TOPLEFT", px * s, -py * s)
		end
	end)
end

if WorldMapFrame then
	WorldMapFrame:HookScript("OnHide", function() Z.reset(false) end)
end

-- WorldMapFrame_Update reloads the tiles (WORLD_MAP_UPDATE): crop them again while zoomed
if WorldMapFrame_Update then
	hooksecurefunc("WorldMapFrame_Update", function()
		if Z.active then cropTexture() end
	end)
end

-- Mode or view change: back to 1, without undoing what the client has just set
for _, name in ipairs({ "WorldMap_ToggleSizeDown", "WorldMap_ToggleSizeUp", "WorldMapFrame_SetMiniMode",
	"WorldMapFrame_SetQuestMapView", "WorldMapFrame_SetFullMapView" }) do
	if _G[name] then
		hooksecurefunc(name, function() Z.reset(true) end)
	end
end
