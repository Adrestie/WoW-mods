-- Flight master map (TaxiFrame) with camelot's art (blizzard_uipanels_game/shared/taxiframe).
-- Camelot uses TaxiFrame for its flight maps 1463 (Eastern Kingdoms) and 1464 (Kalimdor). The
-- client's TaxiRouteMap is suppressed and its TaxiMap hidden (its texture name gives the map);
-- buttons, lines and map image are ours. Outland and Northrend keep the 3.3.5 image, and so
-- does a map whose current or reachable node lies in a Burning Crusade zone camelot lacks.
-- The frame is camelot's bronze metal without portrait (ButtonFrameTemplateNoPortrait) on the
-- rock and stripes of PortraitFrameTemplate, instead of its grey BasicFrameTemplateWithInset.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates
local L = ForeverUI.L

local V = {}
ForeverUI.FlightMaster = V

local SEP = string.char(92)
local FOLDER = "Interface" .. SEP .. "ForeverUI" .. SEP .. "taxiframe" .. SEP

local N = {
	window = { 590, 608 },
	map = { 4, -24, -6, 4 },     -- InsetBg: 580 x 580
	side = 580,                    -- camelot TAXI_MAP_WIDTH / HEIGHT
	button = 16, glow = 32,
	minGap = 18,                 -- TAXI_BUTTON_MIN_DIST
	line = 32,
	background = { 2, -21, -2, 2 },       -- Bg of PortraitFrameTemplate
	stripes = { 6, -21, -2, -21, 43 },
	titleFrame = { 0, -1, 20, -5 },  -- TitleContainer without portrait, text at -5
	levels = { routes = 1, metal = 20, title = 21, closeButton = 22 },
}

-- camelot TaxiButtonTypes, keyed by the 3.3.5 node types
local TYPES = {
	CURRENT = { file = FOLDER .. "ui-taxi-icon-green", glow = 0 },
	REACHABLE = { file = FOLDER .. "ui-taxi-icon-white", glow = 1 },
	DISTANT = { file = FOLDER .. "ui-taxi-icon-nub", glow = 0 },
}

-- Flight maps camelot knows: image, 3.3.5 world square (WorldMapContinent.dbc: minX, minY,
-- maxX, maxY), camelot world square (UiMapAssignment), Burning Crusade zone area
-- (WorldMapTransforms.dbc: region + offset)
local CAMELOT = {
	[0] = {
		image = FOLDER .. "taximap-1463",
		taxi = { -16530, -16530, 12270, 12270 },
		camelot = { -15980, -11880, 5817, 9917 },
		bc = { 2400, -7733.3330078125, 13600, -266.666748046875 },
	},
	[1] = {
		image = FOLDER .. "taximap1-classic",
		taxi = { -11870, -13370, 12470, 10970 },
		camelot = { -11870, -13370, 12470, 10970 },
		bc = { 3199.99951171875, 1600, 10666.666320800781, 9600 },
	},
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- ------------------------------------------------------------ Positions

-- A 3.3.5 flight map position (u from the left, v from the bottom) on camelot's image
-- (fractions, y from the BOTTOM), and whether it falls in a Burning Crusade zone
local function toCamelot(C, u, v)
	local T, K, B = C.taxi, C.camelot, C.bc
	local worldY = T[4] - u * (T[4] - T[2])
	local worldX = T[1] + v * (T[3] - T[1])
	local cu = (K[4] - worldY) / (K[4] - K[2])
	local cv = (worldX - K[1]) / (K[3] - K[1])
	local bc = worldX >= B[1] and worldX <= B[3] and worldY >= B[2] and worldY <= B[4]
	return cu, cv, bc
end

local function inside(cu, cv)
	return cu >= 0 and cu <= 1 and cv >= 0 and cv <= 1
end

-- ------------------------------------------------------------ Route lines
-- The client's DrawRouteLine is camelot's DrawLine (same math, same 32 / 30 factor).

-- Route line texture i, created on first use
local function line(i)
	local h = V.skin
	local t = h.lines[i]
	if not t then
		t = h.routes:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(FOLDER .. "ui-taxi-line")
		h.lines[i] = t
	end
	return t
end

-- The button at this 3.3.5 position: 3.3.5 has no TaxiGetNodeSlot, so route legs are only
-- given by their positions
local function buttonAt(x, y)
	local best, gap
	for _, b in pairs(V.skin.buttons) do
		if b.active then
			local d = math.abs(b.u - x) + math.abs(b.v - y)
			if not gap or d < gap then best, gap = b, d end
		end
	end
	if gap and gap < 0.001 then return best end
end

-- Origin and destination buttons of leg r of the route to node i
local function leg(i, r)
	return buttonAt(TaxiGetSrcX(i, r), TaxiGetSrcY(i, r)), buttonAt(TaxiGetDestX(i, r), TaxiGetDestY(i, r))
end

local function connect(t, origin, destination)
	DrawRouteLine(t, V.skin.routes, origin.x, origin.y, destination.x, destination.y, N.line)
	t:Show()
end

-- DrawOneHopLines: direct flights from the current node, i.e. one-leg routes (3.3.5 has no
-- TaxiIsDirectFlight). ERR_TAXINOPATHS stays with the client's own DrawOneHopLines.
function V.DirectFlights()
	local h = V.skin
	local n = 0
	for i = 1, NumTaxiNodes() do
		local b = h.buttons[i]
		if b and b.active then
			if b.kind == "REACHABLE" and GetNumRoutes(i) == 1 then
				local origin, destination = leg(i, 1)
				if origin and destination then
					n = n + 1
					connect(line(n), origin, destination)
				end
			elseif b.kind == "DISTANT" then
				b:Hide()
			end
		end
	end
	for i = n + 1, #h.lines do h.lines[i]:Hide() end
end

-- ------------------------------------------------------------ Buttons

-- Tooltip and route of a node. A reachable node also calls TaxiNodeSetCurrent, as the
-- 3.3.5 TaxiNodeOnButtonEnter does.
local function onEnter(b)
	local h = V.skin
	local i = b:GetID()
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	GameTooltip:AddLine(TaxiNodeName(i), nil, nil, nil, true)
	if b.kind ~= "DISTANT" then
		-- Hide distant nodes first
		for _, a in pairs(h.buttons) do
			if a.active and a.kind == "DISTANT" then a:Hide() end
		end
	end
	if b.kind == "REACHABLE" then
		SetTooltipMoney(GameTooltip, TaxiNodeCost(i))
		TaxiNodeSetCurrent(i)
		local n = GetNumRoutes(i)
		for r = 1, math.max(n, #h.lines) do
			if r <= n then
				local origin, destination = leg(i, r)
				if origin and destination then
					connect(line(r), origin, destination)
					if destination.kind == "DISTANT" then destination:Show() end
				elseif h.lines[r] then
					h.lines[r]:Hide()
				end
			else
				h.lines[r]:Hide()
			end
		end
	elseif b.kind == "CURRENT" then
		GameTooltip:AddLine(TAXINODEYOUAREHERE, 1, 1, 1, true)
		V.DirectFlights()
	end
	GameTooltip:Show()
end

local function onLeave()
	GameTooltip:Hide()
end

local function createButton(i)
	local h = V.skin
	local b = CreateFrame("Button", "ForeverUITaxiButton" .. i, h.routes)
	b:SetWidth(N.button)
	b:SetHeight(N.button)
	b:SetNormalTexture(TYPES.REACHABLE.file)
	b:SetHighlightTexture(FOLDER .. "ui-taxi-icon-highlight")
	local l = b:GetHighlightTexture()
	l:ClearAllPoints()
	l:SetWidth(N.glow)
	l:SetHeight(N.glow)
	l:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetScript("OnEnter", onEnter)
	b:SetScript("OnLeave", onLeave)
	b:SetScript("OnClick", function(self) TakeTaxiNode(self:GetID()) end)
	h.buttons[i] = b
	return b
end

-- ------------------------------------------------------------ Opening

-- Runs AFTER the client's OnEvent (TAXIMAP_OPENED): image, buttons, direct flights
function V.Open()
	local h = V.skin
	if not h then return end
	local path = TaxiMap:GetTexture()
	local map = type(path) == "string" and tonumber(string.match(string.lower(path), "taximap(%d+)"))
	local C = map and CAMELOT[map]
	-- Nodes, and the image they allow
	local points = {}
	for i = 1, NumTaxiNodes() do
		local kind = TaxiNodeGetType(i)
		if TYPES[kind] then
			local u, v = TaxiNodePosition(i)
			local p = { kind = kind, u = u, v = v }
			if C then
				p.cu, p.cv, p.bc = toCamelot(C, u, v)
				if kind ~= "DISTANT" and (p.bc or not inside(p.cu, p.cv)) then C = nil end
			end
			points[i] = p
		end
	end
	V.camelotImage = C and true or false
	h.map:SetTexCoord(0, 1, 0, 1)
	h.map:SetTexture(C and C.image or path)
	for _, b in pairs(h.buttons) do
		b.active = false
		b:Hide()
	end
	-- Buttons, pushed TAXI_BUTTON_MIN_DIST (18) away from a previous one; a distant node
	-- never pushes a non-distant one
	local slots = {}
	for i = 1, NumTaxiNodes() do
		local p = points[i]
		local showable = p and (not C or (not p.bc and inside(p.cu, p.cv)))
		if showable then
			local x, y
			if C then
				x, y = p.cu * N.side, p.cv * N.side
			else
				x, y = p.u * N.side, p.v * N.side
			end
			for j = 1, i - 1 do
				local q = slots[j]
				if q and (p.kind == "DISTANT" or q.kind ~= "DISTANT") then
					local dx, dy = x - q.x, y - q.y
					local d2 = dx * dx + dy * dy
					if d2 < N.minGap * N.minGap then
						local k = N.minGap
						if d2 > 0 then k = N.minGap / math.sqrt(d2) end
						x, y = q.x + dx * k, q.y + dy * k
					end
				end
			end
			slots[i] = { x = x, y = y, kind = p.kind }
			local b = h.buttons[i] or createButton(i)
			b:SetID(i)
			b.active, b.kind, b.u, b.v, b.x, b.y = true, p.kind, p.u, p.v, x, y
			place(b, "CENTER", h.map, "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5))
			local T = TYPES[p.kind]
			b:SetNormalTexture(T.file)
			b:GetHighlightTexture():SetAlpha(T.glow)
			if p.kind == "DISTANT" then b:Hide() else b:Show() end
		end
	end
	V.DirectFlights()
end

function V.AfterEvent(self, event)
	if event == "TAXIMAP_OPENED" then V.Open() end
end

-- ------------------------------------------------------------ Window

function V.Skin()
	local f = TaxiFrame
	if not f or f.foreverSkin then return end
	-- 3.3.5 art (the four unnamed UI-TaxiFrame-* textures), portrait and merchant name:
	-- camelot has none of them. The client's map is hidden and its TaxiRouteMap suppressed.
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" and string.find(string.lower(t), "ui-taxiframe", 1, true) then
				r:SetAlpha(0)
			end
		end
	end
	TaxiPortrait:SetAlpha(0)
	TaxiMerchant:SetAlpha(0)
	TaxiMap:SetAlpha(0)
	ForeverUI.Suppress(TaxiRouteMap)
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	local skin = {}
	f.foreverSkin = skin
	V.skin = skin
	-- Rock background and stripes (PortraitFrameTemplate)
	local F, S = N.background, N.stripes
	local rock = f:CreateTexture(nil, "BACKGROUND")
	rock:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock", true)
	if rock.SetHorizTile then rock:SetHorizTile(true) rock:SetVertTile(true) end
	rock:SetPoint("TOPLEFT", f, "TOPLEFT", F[1], F[2])
	rock:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", F[3], F[4])
	local stripes = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(stripes, "_ui-frame-toptilestreaks", true)
	stripes:SetHeight(S[5])
	stripes:SetPoint("TOPLEFT", f, "TOPLEFT", S[1], S[2])
	stripes:SetPoint("TOPRIGHT", f, "TOPRIGHT", S[3], S[4])
	skin.rock, skin.stripes = rock, stripes
	-- Bronze metal without portrait, above everything else
	local metal = CreateFrame("Frame", nil, f)
	metal:SetAllPoints(f)
	metal:SetFrameLevel(f:GetFrameLevel() + N.levels.metal)
	skin.metal = Tpl.NineSlice(metal, "ButtonFrameTemplateNoPortrait", f)
	-- Map in BORDER: under the trim (ARTWORK) and the edges (OVERLAY)
	local C = N.map
	local map = f:CreateTexture(nil, "BORDER")
	map:SetPoint("TOPLEFT", f, "TOPLEFT", C[1], C[2])
	map:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", C[3], C[4])
	skin.map = map
	skin.trim = Tpl.NineSlice(f, "InsetFrameTemplate", map, "ARTWORK")
	-- Camelot's TaxiRouteMap: lines and buttons over the map
	local routes = CreateFrame("Frame", "ForeverUITaxiRouteMap", f)
	routes:SetAllPoints(map)
	routes:SetFrameLevel(f:GetFrameLevel() + N.levels.routes)
	skin.routes, skin.lines, skin.buttons = routes, {}, {}
	-- Title (TitleContainer without portrait), above the metal
	local T = N.titleFrame
	local container = CreateFrame("Frame", nil, f)
	container:SetHeight(T[3])
	container:SetPoint("TOPLEFT", f, "TOPLEFT", T[1], T[2])
	container:SetPoint("TOPRIGHT", f, "TOPRIGHT", -T[1], T[2])
	container:SetFrameLevel(f:GetFrameLevel() + N.levels.title)
	local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", container, "TOP", 0, T[4])
	title:SetPoint("LEFT", container, "LEFT")
	title:SetPoint("RIGHT", container, "RIGHT")
	title:SetText(L.TAXI_TITLE)
	skin.title = title
	Tpl.CloseButton(TaxiCloseButton, f)
	TaxiCloseButton:SetFrameLevel(f:GetFrameLevel() + N.levels.closeButton)
	-- The XML binds OnEvent to TaxiFrame_OnEvent itself (function=), so a hook on the global
	-- would never run; hook the script instead
	f:HookScript("OnEvent", V.AfterEvent)
end

V.Skin()
