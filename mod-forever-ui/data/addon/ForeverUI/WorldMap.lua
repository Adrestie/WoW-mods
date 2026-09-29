-- World map with camelot's look (Map and Quest Log), in windowed and maximized modes.
-- It is built around the WotLK map: its frames, their names, its functions and CVars stay, so
-- addons that use WorldMapFrame keep working. Only the visible parts are added.
--
-- Hooks (WotLK WorldMapFrame.lua): WorldMap_ToggleSizeDown and WorldMapFrame_SetMiniMode for
-- the small window; WorldMap_ToggleSizeUp for the full screen (WorldMapFrame unparented over
-- the whole screen by SetupFullscreenScale, UIParent hidden, black background). The maximized
-- mode keeps that full screen and shows camelot's frame, map only, on a holder sized in UI
-- units (camelot blizzard_worldmap.lua UpdateMaximizedSize).
--
-- Scale: camelot fits the 1002 x 668 WotLK map into 697 x 465 (0.6956). WotLK places the
-- player arrow, landmarks and POI bounds with its own scales (WORLDMAP_WINDOWED_SIZE 0.573,
-- WORLDMAP_QUESTLIST_SIZE 0.691, WORLDMAP_FULLMAP_SIZE 1) in WorldMapFrame units, and the
-- engine's arrow does not follow the map scale. Writing those constants from the addon would
-- taint them, so WorldMapFrame itself is scaled (our scale / its scale) and our frames, the
-- quest pane and the red buttons take the inverse scale.

ForeverUI = ForeverUI or {}

local W = {}
ForeverUI.WorldMap = W
local L = ForeverUI.L

-- Layout in one table: the client's Lua 5.1 allows at most 60 upvalues per function.
-- Values come from camelot blizzard_worldmap.xml/.lua and its templates.
local G = {
	width = 702, height = 534,
	cardX = 2, mapY = -67,          -- top-left corner of the map
	mapW = 697, cardH = 465,
	mapBottom = 2,
	backgroundX1 = 2, backgroundY1 = -21, backgroundX2 = -2, backgroundY2 = 2,
	trimY = -63, trimH = 3,
	portraitX = -5, portraitY = 7, portraitSide = 62,
	titleX1 = 58, titleX2 = -24, titleY = -1, titleH = 20, titleTextY = -5,
	closeX = -2, closeY = 1, buttonSide = 24, maximizeX = -1,
	-- the bar stops NAVBAR_X_OFFSET (-50) from the map's right edge,
	-- which stays at 699 whether the quest pane is open or not
	barX = 64 + 2, barY = -25, barRight = 2 + 697 - 50, barBottom = -67 + 9,
	-- quest pane: minimizedWidth + questLogWidth (702 + 333)
	paneWidth = 333,
	-- SidePanelToggle: 32 x 32, BOTTOMRIGHT of the map (-2, 1)
	toggleSide = 32, toggleX = -2, toggleY = 1,
	filtersX = 10, filtersY = -2, filtersSide = 32,
	floorW = 160, floorH = 25, floorX = 2, floorY = 0,
	-- common-dropdown-textholder: 54 x 41, sliced by camelot's engine
	-- (UiTextureAtlasElementSliceData.db2: 16 left, 19 right, none vertically)
	floorEdgeLeft = 16, floorEdgeRight = 19, floorTextX = 8, floorTextY = -8,
	coordX = 68, coordY = 2, coordW = 100, coordH = 15,
	-- maximized mode
	bannerH = 67, screenEdge = 30, mapRight = 3,
	barXMaximized = 8 + 2,
	usableMapW = 1002, usableMapH = 668,
}
G.scale = G.mapW / 1002

-- Metal border: camelot PortraitFrameTemplateMinimizable (mainline/nineslicelayouts.lua)
-- with the fixes of camelot/nineslicelayoutoverrides.lua.
local METAL = {
	{ key = "topLeft", name = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ key = "topRight", name = "ui-frame-metal-cornertoprightdouble", point = "TOPRIGHT", x = 2, y = 16 },
	{ key = "bottomLeft", name = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ key = "bottomRight", name = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}
-- ButtonFrameTemplateNoPortraitMinimizable, same fixes: without the portrait,
-- both left corners move to x = -12
local METAL_MAXIMIZED = {
	topLeft = { name = "ui-frame-metal-cornertopleft", x = -12, y = 16 },
	bottomLeft = { name = "ui-frame-metal-cornerbottomleft", x = -12, y = -8 },
}

-- Camelot strings (GlobalStrings.db2). 3.3.5 lacks MAP_AND_QUEST_LOG, the coordinate
-- formats and WORLD: they are in Textes_<language>.lua.
local TEXT = {
	title = L.WORLDMAP_TITLE,           -- MAP_AND_QUEST_LOG
	maximizedTitle = WORLD_MAP,           -- WORLD_MAP (3.3.5 has it)
	world = L.WORLDMAP_WORLD,           -- WORLD
	cursor = L.WORLDMAP_CURSOR_COORDS, -- WORLD_MAP_CURSOR_COORDS_INTEGER
	player = L.WORLDMAP_PLAYER_COORDS,  -- WORLD_MAP_PLAYER_COORDS_INTEGER
	showRegion = L.WORLDMAP_FILTER_SHOW,   -- WORLD_MAP_FILTER_LABEL_SHOW
}

-- Navigation bar (navigationbar.xml): two texture files, no atlas.
local NAV = {
	sheet = "interface\\ForeverUI\\helpframe\\cs_helptextures",
	tile = "interface\\ForeverUI\\helpframe\\cs_helptextures_tile",
	shadow = "interface\\ForeverUI\\common\\shadowoverlay-left",
	arrows = "interface\\ForeverUI\\buttons\\squarebuttontextures",
	squareUp = "interface\\ForeverUI\\buttons\\ui-squarebutton-up",
	squareDown = "interface\\ForeverUI\\buttons\\ui-squarebutton-down",
	squareHover = "interface\\ForeverUI\\buttons\\ui-common-mousehilight",
	background = { 0, 1, 0.1875, 0.25390625 },               -- _NavMenu-BarBG
	veil = { 0, 1, 0.2578125, 0.32421875 },           -- _NavMenu-BarOverlay
	buttonUp = { 0, 1, 0.0625, 0.12109375 },         -- _NavMenu-Button-Up
	buttonBottom = { 0, 1, 0.125, 0.18359375 },           -- _NavMenu-Button-Down
	buttonHover = { 0.00195313, 0.25195313, 0.65625, 0.92187500 },
	buttonSelected = { 0.00195313, 0.25195313, 0.375, 0.640625 },
	upArrow = { 0.88867188, 0.92968750, 0.29687500, 0.53125000 },
	downArrow = { 0.63281250, 0.67382813, 0.75781250, 0.99218750 },
	menuArrow = { 0.45312500, 0.64062500, 0.20312500, 0.01562500 },
	homeUp = { 0.00781250, 0.24218750 },
	homeDown = { 0.25781250, 0.49218750 },
	homeHover = { 0.50781250, 0.74218750 },
	homeRight = 0.703125,
	buttonHeight = 30,
}

local PREFIX = "|cff66ccffForeverUI|r "

local function say(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

-- Silences a client region: texture, alpha and visibility at once, because WotLK's
-- code shows again what is only hidden.
local function suppress(region)
	if not region then
		return
	end
	if region.SetTexture then
		region:SetTexture(nil)
	end
	region:SetAlpha(0)
	region:Hide()
end

-- Sets one button state from an atlas. SetNormalTexture only takes a path, and a 3.3.5
-- button only has the states its XML declares.
-- state: "Normal", "Pushed", "Disabled" or "Highlight"; name: atlas entry
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
		texture:ClearAllPoints()
		texture:SetAllPoints(button)
	end
	return texture
end

local function isSmallWindow()
	return WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE
end

-- ---------- Scale
-- WorldMapFrame scale in the small window: WotLK draws the map at 0.573
-- (WORLDMAP_WINDOWED_SIZE, read only); camelot needs 0.6956.
local function reducedScale()
	return G.scale / (WORLDMAP_WINDOWED_SIZE or G.scale)
end
W.inverse = 1

-- ---------- Moving
-- The small window can be dragged by its title bar (camelot cannot do this; WotLK can).
-- WotLK's advanced mode (CVar advancedWorldMap, option ADVANCED_WORLD_MAP_TEXT) makes it a
-- "center" panel that the panel manager never moves (UIParent.lua:1694), movable and
-- anchored on WorldMapScreenAnchor, whose position the client saves. WorldMapTitleButton
-- drags it unless the map is locked (the default). The full screen does not move.
-- The CVar must be set before VARIABLES_LOADED, when WotLK reads it.
if GetCVar and SetCVar and GetCVar("advancedWorldMap") ~= "1" then
	SetCVar("advancedWorldMap", "1")
end

-- The lock stays the client's (WORLDMAP_SETTINGS.locked, never written). When the map is
-- locked, WotLK refuses to drag, so these do the work of its WorldMapTitleButton_OnDragStart
-- / _OnDragStop after it (WorldMapFrame.lua:2063-2087). When unlocked, WotLK drags the map
-- itself and these do nothing.
local function dragStart()
	if not (WORLDMAP_SETTINGS.advanced and WORLDMAP_SETTINGS.locked) then return end
	if WORLDMAP_SETTINGS.selectedQuest then
		WorldMapBlobFrame:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuestId, false)
	end
	WorldMapScreenAnchor:ClearAllPoints()
	WorldMapFrame:ClearAllPoints()
	WorldMapFrame:StartMoving()
end

local function dragStop()
	if not (WORLDMAP_SETTINGS.advanced and WORLDMAP_SETTINGS.locked) then return end
	WorldMapFrame:StopMovingOrSizing()
	WorldMapBlobFrame_CalculateHitTranslations()
	if WORLDMAP_SETTINGS.selectedQuest and not WORLDMAP_SETTINGS.selectedQuest.completed then
		WorldMapBlobFrame:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuestId, true)
	end
	WorldMapScreenAnchor:StartMoving()
	WorldMapScreenAnchor:SetPoint("TOPLEFT", WorldMapFrame)
	WorldMapScreenAnchor:StopMovingOrSizing()
end

if WorldMapTitleButton and WorldMapTitleButton.HookScript then
	WorldMapTitleButton:HookScript("OnDragStart", dragStart)
	WorldMapTitleButton:HookScript("OnDragStop", dragStop)
end

-- The anchor starts at the screen's top-left corner (XML). It is moved to where camelot
-- opens its map: a "left" panel at LEFT_OFFSET 16, TOP_OFFSET -116
-- (uipanellayoutframe.lua:3-4). Like WorldMapFrame_ToggleAdvanced, it goes through
-- StartMoving so the client saves the position.
local ANCHOR = { x = 16, y = -116 }

local function placeAnchor()
	local anchor = WorldMapScreenAnchor
	if not anchor or (anchor.IsUserPlaced and anchor:IsUserPlaced()) then
		return
	end
	anchor:StartMoving()
	anchor:ClearAllPoints()
	anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ANCHOR.x, ANCHOR.y)
	anchor:StopMovingOrSizing()
end

-- ---------- Skin
-- Two layers, as in camelot: the background below the map (map strata, WorldMapFrame
-- level) and the frame above it (HIGH strata, like BorderFrame). Neither takes the mouse:
-- in the small window WotLK disables the mouse on WorldMapFrame, and the map must stay
-- clickable.

local function buildBackground(map)
	local background = CreateFrame("Frame", "ForeverUIWorldMapBackground", map)
	background:SetAllPoints(map)

	-- Bg: UI-Background-Rock is a whole file, so it can tile.
	local rock = background:CreateTexture(nil, "BACKGROUND")
	rock:SetTexture("interface\\ForeverUI\\framegeneral\\ui-background-rock", true)
	if rock.SetHorizTile then
		rock:SetHorizTile(true)
		rock:SetVertTile(true)
	end
	rock:SetPoint("TOPLEFT", background, "TOPLEFT", G.backgroundX1, G.backgroundY1)
	rock:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", G.backgroundX2, G.backgroundY2)

	-- OverscrollBG, on the map rectangle (the canvas, which follows the map in both modes).
	-- Its textures are regions of the background, not a child frame: a child frame sits one
	-- level above its parent (89), over WotLK's tiles (WorldMapDetailFrame, 88), and hides
	-- them. The tile is an atlas and 3.3.5 cannot tile an atlas rectangle, so it is stretched.
	local canvas = W.canvas
	local tile = background:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(tile, "gamepad-mapquestlog-bgtile-2k", true)
	tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
	tile:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", 0, 0)
	background.tile = tile

	local e = ForeverUI.AtlasEntry("gamepad-mapquestlog-bg-vignette")
	if e then
		-- four quarters, mirrored by texture coordinates (blizzard_worldmap.xml)
		local quarters = {
			{ "TOPLEFT", "TOPLEFT", "BOTTOMRIGHT", "CENTER", e[2], e[3], e[4], e[5] },
			{ "TOPRIGHT", "TOPRIGHT", "BOTTOMLEFT", "CENTER", e[3], e[2], e[4], e[5] },
			{ "BOTTOMLEFT", "BOTTOMLEFT", "TOPRIGHT", "CENTER", e[2], e[3], e[5], e[4] },
			{ "BOTTOMRIGHT", "BOTTOMRIGHT", "TOPLEFT", "CENTER", e[3], e[2], e[5], e[4] },
		}
		for _, q in ipairs(quarters) do
			local v = background:CreateTexture(nil, "BORDER")
			v:SetTexture(e[1])
			v:SetTexCoord(q[5], q[6], q[7], q[8])
			v:SetPoint(q[1], canvas, q[2], 0, 0)
			v:SetPoint(q[3], canvas, q[4], 0, 0)
		end
	end
	return background
end

local function buildFrame(map)
	local frame = CreateFrame("Frame", "ForeverUIWorldMapBorder", map)
	frame:SetAllPoints(map)
	frame:SetFrameStrata("HIGH")

	-- trim under the title area
	local trim = frame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(trim, "_ui-frame-innertoptile", true)
	trim:SetHeight(G.trimH)
	trim:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, G.trimY)
	trim:SetPoint("RIGHT", frame, "LEFT", G.cardX + G.mapW, 0)
	frame.trim = trim

	-- portrait, below the metal (PortraitContainer 400 < NineSlice 500)
	local portrait = CreateFrame("Frame", nil, frame)
	portrait:SetAllPoints(frame)
	portrait:SetFrameLevel(frame:GetFrameLevel() + 1)
	local image = portrait:CreateTexture(nil, "OVERLAY")
	image:SetWidth(G.portraitSide)
	image:SetHeight(G.portraitSide)
	image:SetPoint("TOPLEFT", frame, "TOPLEFT", G.portraitX, G.portraitY)
	local book = "interface\\ForeverUI\\questframe\\ui-questlog-bookicon"
	if SetPortraitToTexture then
		SetPortraitToTexture(image, book)
	else
		image:SetTexture(book)
	end
	frame.portrait = image
	frame.portraitFrame = portrait

	-- metal border
	local metal = CreateFrame("Frame", nil, frame)
	metal:SetAllPoints(frame)
	metal:SetFrameLevel(frame:GetFrameLevel() + 2)
	local p = {}
	for _, corner in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, corner.name)
		t:SetPoint(corner.point, metal, corner.point, corner.x, corner.y)
		p[corner.key] = t
	end
	frame.corners = p
	local function edge(name, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, name)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	edge("_ui-frame-metal-edgetop", "TOPLEFT", p.topLeft, "TOPRIGHT", "TOPRIGHT", p.topRight, "TOPLEFT")
	edge("_ui-frame-metal-edgebottom", "BOTTOMLEFT", p.bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bottomRight, "BOTTOMLEFT")
	edge("!ui-frame-metal-edgeleft", "TOPLEFT", p.topLeft, "BOTTOMLEFT", "BOTTOMLEFT", p.bottomLeft, "TOPLEFT")
	edge("!ui-frame-metal-edgeright", "TOPRIGHT", p.topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bottomRight, "TOPRIGHT")
	frame.metal = metal

	-- title strip, above the metal (TitleContainer 510)
	local banner = CreateFrame("Frame", nil, frame)
	banner:SetFrameLevel(frame:GetFrameLevel() + 3)
	banner:SetHeight(G.titleH)
	banner:SetPoint("TOPLEFT", frame, "TOPLEFT", G.titleX1, G.titleY)
	banner:SetPoint("TOPRIGHT", frame, "TOPRIGHT", G.titleX2, G.titleY)
	frame.banner = banner
	return frame
end

-- ---------- Navigation bar
-- camelot navigationbar.lua on WotLK data: World > continent > zone. The root button
-- shows the world view. A button's list holds its siblings: GetMapContinents for a
-- continent, GetMapZones for a zone.

local navMenu = CreateFrame("Frame", "ForeverUIWorldMapNavMenu", UIParent, "UIDropDownMenuTemplate")
navMenu:Hide()

-- Opens the shared dropdown list under anchor.
-- list: entries (text, func, checked, isTitle, ...); minimum: smallest list width, the
-- width of the dropdown that opens it (DropdownButtonMixin:RegisterMenu, SetMinimumWidth)
local function openMenu(anchor, list, minimum)
	navMenu.foreverMinimum = minimum
	UIDropDownMenu_Initialize(navMenu, function()
		for _, entry in ipairs(list) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = entry.text
			info.func = entry.func
			info.checked = entry.checked
			info.notCheckable = entry.checked == nil and 1 or nil
			info.keepShownOnClick = entry.keepShownOnClick
			info.isTitle = entry.isTitle
			info.notClickable = entry.isTitle
			info.disabled = entry.disabled
			UIDropDownMenu_AddButton(info)
		end
	end, "MENU")
	ToggleDropDownMenu(1, nil, navMenu, anchor, 0, 0)
	-- Always downward. 3.3.5's ToggleDropDownMenu flips the list above the button when it
	-- would pass the screen bottom (long zone lists in the small window). Camelot menus
	-- (Blizzard_Menu) stay below their button and are clamped to the screen, so the list is
	-- moved back below and clamped while it is open.
	local list1 = DropDownList1
	if list1 and list1:IsShown() then
		local point = list1:GetPoint(1)
		if point and string.find(point, "^BOTTOM") then
			list1:ClearAllPoints()
			list1:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
		end
		if not list1.foreverClamped then
			list1.foreverClamped = true
			list1.foreverClampedBefore = list1.IsClampedToScreen and list1:IsClampedToScreen() or false
			list1:SetClampedToScreen(true)
		end
	end
end
W.openMenu = openMenu

-- list closed: give back its clamping to the game's other menus
if DropDownList1 then
	DropDownList1:HookScript("OnHide", function(self)
		if self.foreverClamped then
			self:SetClampedToScreen(self.foreverClampedBefore and true or false)
			self.foreverClamped, self.foreverClampedBefore = nil, nil
		end
	end)
end

local function placeOnSheet(texture, coords)
	texture:SetTexture(NAV.sheet)
	texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

-- Rows of the tiled sheet have a uniform width, so they are stretched instead of tiled
-- (3.3.5 tiling would ignore the chosen row).
local function placeOnTile(texture, coords)
	texture:SetTexture(NAV.tile)
	texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

local function createNavButton(bar, index)
	local b = CreateFrame("Button", "ForeverUIWorldMapNavButton" .. index, bar)
	b:SetHeight(NAV.buttonHeight)
	b:SetNormalTexture(NAV.tile)
	placeOnTile(b:GetNormalTexture(), NAV.buttonUp)
	b:SetPushedTexture(NAV.tile)
	placeOnTile(b:GetPushedTexture(), NAV.buttonBottom)
	b:SetDisabledTexture(NAV.tile)
	placeOnTile(b:GetDisabledTexture(), NAV.buttonUp)
	b:SetHighlightTexture(NAV.sheet)
	placeOnSheet(b:GetHighlightTexture(), NAV.buttonHover)
	b:GetHighlightTexture():SetBlendMode("ADD")

	local text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetJustifyH("LEFT")
	text:SetHeight(12)
	text:SetPoint("LEFT", b, "LEFT", 20, 0)
	b:SetFontString(text)
	b.text = text

	b.arrowUp = b:CreateTexture(nil, "OVERLAY")
	b.arrowUp:SetWidth(21)
	b.arrowUp:SetHeight(30)
	b.arrowUp:SetPoint("LEFT", b, "RIGHT", 0, 0)
	placeOnSheet(b.arrowUp, NAV.upArrow)
	b.arrowDown = b:CreateTexture(nil, "OVERLAY")
	b.arrowDown:SetWidth(21)
	b.arrowDown:SetHeight(30)
	b.arrowDown:SetPoint("LEFT", b, "RIGHT", 0, 0)
	placeOnSheet(b.arrowDown, NAV.downArrow)
	b.arrowDown:Hide()
	b.selected = b:CreateTexture(nil, "OVERLAY")
	b.selected:SetAllPoints(b)
	placeOnSheet(b.selected, NAV.buttonSelected)
	b.selected:Hide()

	b:SetScript("OnMouseDown", function(self)
		if self:IsEnabled() == 1 then
			self.arrowUp:Hide()
			self.arrowDown:Show()
		end
	end)
	b:SetScript("OnMouseUp", function(self)
		self.arrowDown:Hide()
		self.arrowUp:Show()
	end)

	-- MenuArrowButton: 27 x 31, RIGHT on TOPRIGHT (-2, -15)
	local m = CreateFrame("Button", nil, b)
	m:SetWidth(27)
	m:SetHeight(31)
	m:SetPoint("RIGHT", b, "TOPRIGHT", -2, -15)
	m.Art = m:CreateTexture(nil, "OVERLAY")
	m.Art:SetWidth(12)
	m.Art:SetHeight(12)
	m.Art:SetPoint("CENTER", m, "CENTER", 0, -1)
	m.Art:SetTexture(NAV.arrows)
	m.Art:SetTexCoord(NAV.menuArrow[1], NAV.menuArrow[2], NAV.menuArrow[3], NAV.menuArrow[4])
	m:SetNormalTexture(NAV.squareUp)
	m:GetNormalTexture():SetAlpha(0)
	m:SetPushedTexture(NAV.squareDown)
	m:GetPushedTexture():SetAlpha(0)
	m:SetHighlightTexture(NAV.squareHover)
	m:GetHighlightTexture():SetBlendMode("ADD")
	for _, t in ipairs({ m:GetNormalTexture(), m:GetPushedTexture(), m:GetHighlightTexture() }) do
		t:ClearAllPoints()
		t:SetWidth(32)
		t:SetHeight(32)
		t:SetPoint("CENTER", m, "CENTER", 0, 0)
	end
	m:SetScript("OnMouseDown", function(self) self.Art:SetPoint("CENTER", self, "CENTER", -1, -2) end)
	m:SetScript("OnMouseUp", function(self) self.Art:SetPoint("CENTER", self, "CENTER", 0, -1) end)
	m:SetScript("OnEnter", function(self)
		self:GetNormalTexture():SetAlpha(1)
		self:GetPushedTexture():SetAlpha(1)
	end)
	m:SetScript("OnLeave", function(self)
		self:GetNormalTexture():SetAlpha(0)
		self:GetPushedTexture():SetAlpha(0)
	end)
	m:SetScript("OnClick", function(self)
		local parent = self:GetParent()
		if parent.listFunc then
			openMenu(self, parent.listFunc())
		end
	end)
	b.MenuArrowButton = m

	b:SetScript("OnClick", function(self)
		if self.myclick then
			self.myclick()
		end
	end)
	return b
end

local function buildBar(map)
	local bar = CreateFrame("Frame", "ForeverUIWorldMapNavBar", map)
	bar:SetPoint("TOPLEFT", map, "TOPLEFT", G.barX, G.barY)
	bar:SetPoint("BOTTOMRIGHT", map, "TOPLEFT", G.barRight, G.barBottom)

	local background = bar:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(bar)
	placeOnTile(background, NAV.background)

	-- inner border (WorldMapNavBarTemplate), BORDER layer
	local function piece(name)
		local t = bar:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, name)
		return t
	end
	local bottomLeft = piece("ui-frame-innerbotleftcorner")
	bottomLeft:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -3, -3)
	local bottomRight = piece("ui-frame-innerbotright")
	bottomRight:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -3)
	local down = piece("_ui-frame-innerbottile")
	down:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT")
	down:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")
	local left = piece("!ui-frame-innerlefttile")
	left:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 0)
	-- as written in the source: BOTTOMLEFT on the TOPLEFT of
	-- InsetBorderBottomRight (blizzard_worldmaptemplates.xml:97)
	left:SetPoint("BOTTOMLEFT", bottomRight, "TOPLEFT")
	local right = piece("!ui-frame-innerrighttile")
	right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 3, 0)
	right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")

	-- root button
	local home = CreateFrame("Button", "ForeverUIWorldMapNavBarHomeButton", bar)
	home:SetHeight(NAV.buttonHeight)
	home:SetNormalTexture(NAV.sheet)
	home:SetPushedTexture(NAV.sheet)
	home:SetHighlightTexture(NAV.sheet)
	home:GetHighlightTexture():SetBlendMode("ADD")
	local text = home:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetJustifyH("LEFT")
	text:SetHeight(12)
	text:SetPoint("LEFT", home, "LEFT", 10, 0)
	text:SetPoint("RIGHT", home, "RIGHT", -30, 0)
	home:SetFontString(text)
	home.text = text
	home:SetText(TEXT.world)
	local width = math.min(128, text:GetStringWidth() + 50)
	local du = (width / 128) * 0.25
	local d = NAV.homeRight
	home:GetNormalTexture():SetTexCoord(d - du, d, NAV.homeUp[1], NAV.homeUp[2])
	home:GetPushedTexture():SetTexCoord(d - du, d, NAV.homeDown[1], NAV.homeDown[2])
	home:GetHighlightTexture():SetTexCoord(d - du, d + 0.01, NAV.homeHover[1], NAV.homeHover[2])
	home:SetWidth(width)
	home.xoffset = -15
	local shadow = home:CreateTexture(nil, "OVERLAY")
	shadow:SetTexture(NAV.shadow)
	shadow:SetWidth(30)
	shadow:SetHeight(30)
	shadow:SetPoint("LEFT", home, "LEFT", 0, 0)
	home:SetPoint("LEFT", bar, "LEFT", 0, 0)
	-- The World button shows the map that chooses between Azeroth and Outland:
	-- WORLDMAP_COSMIC_ID, like WotLK's zoom out from Azeroth (WorldMapZoomOutButton_OnClick).
	-- The cosmic view is detected as WorldMapFrame_Update does: GetMapInfo() returns nil and
	-- the continent is WORLDMAP_COSMIC_ID. From a dungeon WotLK only leaves through ZoomOut,
	-- so SetMapZoom then ZoomOut are tried while the map keeps changing.
	home.myclick = function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		local cosmicId = WORLDMAP_COSMIC_ID or -1
		local function isCosmic()
			return GetMapInfo() == nil and GetCurrentMapContinent() == cosmicId
		end
		local function state()
			return tostring(GetMapInfo()) .. ":" .. tostring(GetCurrentMapContinent()) .. ":"
				.. tostring(GetCurrentMapZone()) .. ":" .. tostring(GetCurrentMapDungeonLevel())
		end
		for _ = 1, 6 do
			if isCosmic() then break end
			SetMapZoom(cosmicId)
			if isCosmic() then break end
			local before = state()
			ZoomOut()
			if state() == before then break end
		end
		-- the client refused: print what it reports, for diagnosis
		if not isCosmic() then
			say(string.format(L.WORLDMAP_DEBUG_WORLD_REFUSED,
				tostring(GetMapInfo()), tostring(GetCurrentMapContinent()), tostring(GetCurrentMapZone()),
				tostring(GetCurrentMapDungeonLevel()), tostring(IsZoomOutAvailable and IsZoomOutAvailable())))
		end
	end
	home:SetScript("OnClick", function(self) self.myclick() end)
	bar.home = home

	-- veil, above the buttons
	local veil = CreateFrame("Frame", nil, bar)
	veil:SetAllPoints(bar)
	local t = veil:CreateTexture(nil, "OVERLAY")
	t:SetAllPoints(veil)
	placeOnTile(t, NAV.veil)
	bar.veil = veil

	bar.buttons = {}
	return bar
end

-- Hierarchy of the displayed map as 3.3.5 knows it: continent, then zone, each with
-- its click action and the list of its siblings.
local function hierarchy()
	local list = {}
	local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
	local zone = GetCurrentMapZone and GetCurrentMapZone() or 0
	if continent and continent > 0 then
		local continents = { GetMapContinents() }
		table.insert(list, {
			name = continents[continent],
			OnClick = function() SetMapZoom(continent) end,
			listFunc = function()
				local l = {}
				for i, name in ipairs({ GetMapContinents() }) do
					table.insert(l, { text = name, func = function() SetMapZoom(i) end })
				end
				return l
			end,
		})
		if zone and zone > 0 then
			local zones = { GetMapZones(continent) }
			table.insert(list, {
				name = zones[zone],
				OnClick = function() SetMapZoom(continent, zone) end,
				listFunc = function()
					local l = {}
					for i, name in ipairs({ GetMapZones(continent) }) do
						table.insert(l, { text = name, func = function() SetMapZoom(continent, i) end })
					end
					return l
				end,
			})
		end
	end
	return list
end
W.hierarchy = hierarchy

-- NavBar_Reset + NavBar_AddButton + NavBar_CheckLength: a button is its text + 53 wide
-- with a list, + 30 without; each one anchors right of the previous one at its xoffset
-- (-15 after the root button); the last one is disabled and shows the selection image.
local function refreshBar()
	local bar = W.bar
	if not bar then
		return
	end
	for _, b in ipairs(bar.buttons) do
		b:Hide()
	end
	local list = hierarchy()
	local previous = bar.home
	local level = bar:GetFrameLevel() + 1
	bar.home:SetFrameLevel(level)
	for i, data in ipairs(list) do
		local b = bar.buttons[i]
		if not b then
			b = createNavButton(bar, i)
			bar.buttons[i] = b
		end
		b:SetText(data.name or "")
		if data.listFunc then
			b.MenuArrowButton:Show()
			b:SetWidth(b.text:GetStringWidth() + 53)
		else
			b.MenuArrowButton:Hide()
			b:SetWidth(b.text:GetStringWidth() + 30)
		end
		b.myclick = data.OnClick
		b.listFunc = data.listFunc
		b:ClearAllPoints()
		b:SetPoint("LEFT", previous, "RIGHT", previous.xoffset or 0, 0)
		level = level + 1
		b:SetFrameLevel(level)
		b:Show()
		previous = b
	end
	-- the last button is the current location
	local last = #list
	for i = 1, last do
		local b = bar.buttons[i]
		if i < last then
			b.selected:Hide()
			b:Enable()
		else
			b.selected:Show()
			b:SetButtonState("NORMAL")
			b:Disable()
		end
	end
	-- World is the current location only on the cosmic view (no map name, continent
	-- WORLDMAP_COSMIC_ID). In a dungeon 3.3.5 gives no continent or zone: the trail is
	-- empty, but World must stay clickable, as on Azeroth.
	local cosmicId = GetMapInfo() == nil and GetCurrentMapContinent() == (WORLDMAP_COSMIC_ID or -1)
	if last == 0 and cosmicId then
		bar.home:SetButtonState("NORMAL")
		bar.home:Disable()
	else
		bar.home:Enable()
	end
	bar.veil:SetFrameLevel(level + 1)
end
W.refreshBar = refreshBar

-- ---------- Filters
-- camelot/blizzard_worldmaptemplates.xml. Camelot's menu lists its map filters; 3.3.5
-- has only two: quest objectives (CVar questPOI, WotLK's checkbox) and difficulty
-- colors (mapQuestDifficulty).

local function filters()
	return {
		{ text = TEXT.showRegion, isTitle = 1 },
		{
			text = SHOW_QUEST_OBJECTIVES_ON_MAP_TEXT or QUEST_OBJECTIVES,
			checked = WorldMapQuestShowObjectives and WorldMapQuestShowObjectives:GetChecked() and true or false,
			keepShownOnClick = 1,
			func = function()
				if WorldMapQuestShowObjectives then
					WorldMapQuestShowObjectives:Click()
				end
			end,
		},
		{
			text = MAP_QUEST_DIFFICULTY_TEXT,
			checked = MAP_QUEST_DIFFICULTY == "1",
			keepShownOnClick = 1,
			func = function()
				local value = MAP_QUEST_DIFFICULTY == "1" and "0" or "1"
				SetCVar("mapQuestDifficulty", value)
				MAP_QUEST_DIFFICULTY = value
				if WorldMapFrame_ResetQuestColors then
					WorldMapFrame_ResetQuestColors()
				end
				if WorldMapFrame:IsShown() and WatchFrame and WatchFrame.showObjectives then
					WorldMapFrame_DisplayQuests()
				end
			end,
		},
	}
end

local function buildFilters(map, bar)
	local b = CreateFrame("Button", "ForeverUIWorldMapFilterButton", map)
	b:SetFrameStrata("HIGH")
	b:SetWidth(G.filtersSide)
	b:SetHeight(G.filtersSide)
	b:SetPoint("LEFT", bar, "RIGHT", G.filtersX, G.filtersY)
	local icon = b:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(icon, "common-dropdown-a-button")
	icon:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -6)
	b.Icon = icon
	b:SetHighlightTexture(ForeverUI.AtlasEntry("common-dropdown-a-button")[1])
	local hover = b:GetHighlightTexture()
	ForeverUI.SetAtlas(hover, "common-dropdown-a-button")
	hover:ClearAllPoints()
	hover:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -6)
	hover:SetBlendMode("ADD")
	hover:SetAlpha(0.4)
	b:SetScript("OnMouseDown", function(self) ForeverUI.SetAtlas(self.Icon, "common-dropdown-a-button-pressed", true) end)
	b:SetScript("OnMouseUp", function(self) ForeverUI.SetAtlas(self.Icon, "common-dropdown-a-button", true) end)
	b:SetScript("OnClick", function(self) openMenu(self, filters()) end)
	return b
end

-- ---------- Floors
-- WowStyle1DropdownTemplate: background common-dropdown-textholder from (-8, 7) to
-- (8, -9), arrow common-dropdown-a-button at RIGHT (1, -3), GameFontHighlight text from
-- (8, -8) to the arrow. Shown only when the map has floors
-- (WorldMapFloorNavigationFrameMixin:Refresh).

-- Name of floor i as WotLK builds it: DUNGEON_FLOOR_<MAP><n>, n counted from 0 when
-- the dungeon also uses the terrain map; FLOOR_NUMBER when no name exists.
local function floorName(i)
	local name = strupper(GetMapInfo() or "")
	local number = i
	if DungeonUsesTerrainMap and DungeonUsesTerrainMap() then
		number = i - 1
	end
	return _G["DUNGEON_FLOOR_" .. name .. number] or string.format(FLOOR_NUMBER, i)
end

local function buildFloors(map)
	local b = CreateFrame("Button", "ForeverUIWorldMapFloorButton", map)
	b:SetFrameStrata("HIGH")
	b:SetWidth(G.floorW)
	b:SetHeight(G.floorH)
	b:SetPoint("TOPLEFT", map, "TOPLEFT", G.cardX + G.floorX, G.mapY - G.floorY)
	-- Background in three pieces: stretched in one piece, its 16 and 19 pixels of
	-- transparent shadow grow with the width, and the visible box looks narrow and shifted
	-- right. Variant c60, the one camelot shows.
	local e = ForeverUI.AtlasEntry("common-dropdown-textholder-c60")
	local background = CreateFrame("Frame", nil, b)
	background:SetPoint("TOPLEFT", b, "TOPLEFT", -8, 7)
	background:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 8, -9)
	if e then
		local du = (e[3] - e[2]) / e[6]
		local u1, u2 = e[2] + G.floorEdgeLeft * du, e[3] - G.floorEdgeRight * du
		local function piece(a, z)
			local t = b:CreateTexture(nil, "BACKGROUND")
			t:SetTexture(e[1])
			t:SetTexCoord(a, z, e[4], e[5])
			return t
		end
		local g = piece(e[2], u1)
		g:SetWidth(G.floorEdgeLeft)
		g:SetPoint("TOPLEFT", background, "TOPLEFT", 0, 0)
		g:SetPoint("BOTTOMLEFT", background, "BOTTOMLEFT", 0, 0)
		local d = piece(u2, e[3])
		d:SetWidth(G.floorEdgeRight)
		d:SetPoint("TOPRIGHT", background, "TOPRIGHT", 0, 0)
		d:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 0, 0)
		local m = piece(u1, u2)
		m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
		m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
		b.background = { g, m, d }
	end
	local arrow = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(arrow, "common-dropdown-a-button")
	arrow:SetPoint("RIGHT", b, "RIGHT", 1, -3)
	local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetJustifyH("LEFT")
	text:SetHeight(10)
	text:SetPoint("TOPLEFT", b, "TOPLEFT", G.floorTextX, G.floorTextY)
	text:SetPoint("TOPRIGHT", arrow, "LEFT", 0, 0)
	b.Text = text
	b.Arrow = arrow
	b:SetScript("OnMouseDown", function(self) ForeverUI.SetAtlas(self.Arrow, "common-dropdown-a-button-pressed", true) end)
	b:SetScript("OnMouseUp", function(self) ForeverUI.SetAtlas(self.Arrow, "common-dropdown-a-button", true) end)
	b:SetScript("OnClick", function(self)
		local l = {}
		local current = GetCurrentMapDungeonLevel()
		for i = 1, GetNumDungeonMapLevels() do
			table.insert(l, {
				text = floorName(i),
				checked = (i == current),
				func = function() SetDungeonMapLevel(i) end,
			})
		end
		openMenu(self, l, self:GetWidth())
	end)
	b:Hide()
	return b
end

-- Room for the name: from the left edge (+8) to the arrow, which overhangs the button
-- by 1 on the right (RIGHT (1, -3)).
function W.floorTextWidth()
	local arrow = ForeverUI.AtlasEntry("common-dropdown-a-button")
	return G.floorW + 1 - (arrow and arrow[6] or 27) - G.floorTextX
end

-- wordwrap="false": a name that is too long ends with an ellipsis. Characters are
-- removed (never splitting a UTF-8 character) until the name fits.
-- fs: font string; width: room available, nil for no limit
function W.writeElided(fs, text, width)
	fs:SetText(text)
	if not width or fs:GetStringWidth() <= width then
		return
	end
	local points = "..."
	local isTruncated = text
	while #isTruncated > 0 do
		isTruncated = string.sub(isTruncated, 1, -2)
		-- a UTF-8 character cut in the middle is removed whole
		while #isTruncated > 0 and string.byte(isTruncated, -1) >= 128 and string.byte(isTruncated, -1) < 192 do
			isTruncated = string.sub(isTruncated, 1, -2)
		end
		if #isTruncated > 0 and string.byte(isTruncated, -1) >= 192 then
			isTruncated = string.sub(isTruncated, 1, -2)
		end
		fs:SetText(isTruncated .. points)
		if fs:GetStringWidth() <= width then
			return
		end
	end
	fs:SetText(points)
end

local function refreshFloors()
	local b = W.floors
	if not b then
		return
	end
	if GetNumDungeonMapLevels and GetNumDungeonMapLevels() > 0 then
		W.writeElided(b.Text, floorName(GetCurrentMapDungeonLevel()), W.floorTextWidth())
		b:Show()
	else
		b:Hide()
	end
end

-- ---------- Coordinates
-- WorldMapCoordsPanelTemplate: two 100 x 15 rows, GameFontHighlightSmall, left-aligned.
-- The cursor row shows only while the mouse is over the map, the player row only when
-- the player is on the displayed map (3.3.5 cannot read the position on another map
-- without changing the displayed one).

local function buildCoordinates(map)
	local c = CreateFrame("Frame", "ForeverUIWorldMapCoords", map)
	c:SetWidth(G.coordW)
	c:SetHeight(G.coordH * 2)
	c:SetPoint("BOTTOMLEFT", map, "TOPLEFT", G.cardX + G.coordX, G.mapY - G.cardH + G.coordY)
	local function row()
		local t = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		t:SetJustifyH("LEFT")
		t:SetWidth(G.coordW)
		t:SetHeight(G.coordH)
		return t
	end
	c.player = row()
	c.player:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	c.cursor = row()
	c.pending = 0
	c:SetScript("OnUpdate", function(self, elapsed)
		self.pending = self.pending - (elapsed or 0)
		if self.pending > 0 then
			return
		end
		self.pending = 0.05
		W.updateCoordinates()
	end)
	return c
end

function W.updateCoordinates()
	local c = W.coords
	if not c then
		return
	end
	local x, y = GetPlayerMapPosition("player")
	local player = x and y and not (x == 0 and y == 0)
	if player then
		c.player:SetText(string.format(TEXT.player, math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5)))
		c.player:Show()
	else
		c.player:Hide()
	end

	local button = WorldMapButton
	local cursor = false
	if button and button:IsVisible() and button:IsMouseOver() then
		local cx, cy = GetCursorPosition()
		local scale = button:GetEffectiveScale()
		cx, cy = cx / scale, cy / scale
		local left, top = button:GetLeft(), button:GetTop()
		local l, h = button:GetWidth(), button:GetHeight()
		if left and top and l > 0 and h > 0 then
			local nx, ny = (cx - left) / l, (top - cy) / h
			if nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
				c.cursor:SetText(string.format(TEXT.cursor, math.floor(nx * 100 + 0.5), math.floor(ny * 100 + 0.5)))
				cursor = true
			end
		end
	end
	c.cursor:ClearAllPoints()
	if player then
		c.cursor:SetPoint("BOTTOMLEFT", c.player, "TOPLEFT", 0, 0)
	else
		c.cursor:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	end
	if cursor then c.cursor:Show() else c.cursor:Hide() end
end

-- ---------- Tiles
-- WorldMapFrame.xml:541-636: twelve 256 x 256 tiles in 4 x 3 (1024 x 768) for a usable
-- map of 1002 x 668. WotLK crops nothing: its borders cover the overflow. Camelot's
-- border does not, so the last column is cropped to 1002 - 768 = 234 and the last row
-- to 668 - 512 = 156. WorldMapFrame_Update reloads the tiles on each map change, so
-- this runs again after it.
-- active: true crops, false restores the full tiles
local TILES = { side = 256, columns = 4, rowLines = 3, usableW = 1002, usableH = 668 }

local function cropTiles(active)
	local lastW = TILES.usableW - TILES.side * (TILES.columns - 1)
	local lastH = TILES.usableH - TILES.side * (TILES.rowLines - 1)
	for rowLine = 1, TILES.rowLines do
		for column = 1, TILES.columns do
			local tile = _G["WorldMapDetailTile" .. ((rowLine - 1) * TILES.columns + column)]
			if tile then
				local l, h = TILES.side, TILES.side
				if active and column == TILES.columns then l = lastW end
				if active and rowLine == TILES.rowLines then h = lastH end
				tile:SetWidth(l)
				tile:SetHeight(h)
				tile:SetTexCoord(0, l / TILES.side, 0, h / TILES.side)
			end
		end
	end
end
W.cropTiles = cropTiles

-- ---------- Red buttons

local function skinRedButtons(map, frame)
	local close = WorldMapFrameCloseButton
	if close then
		close:SetFrameStrata("HIGH")
		close:SetFrameLevel(frame:GetFrameLevel() + 4)
		close:SetWidth(G.buttonSide)
		close:SetHeight(G.buttonSide)
		close:SetHitRectInsets(0, 0, 0, 0)
		applyButtonState(close, "Normal", "redbutton-exit")
		applyButtonState(close, "Pushed", "redbutton-exit-pressed")
		applyButtonState(close, "Disabled", "redbutton-exit-disabled")
		local s = applyButtonState(close, "Highlight", "redbutton-highlight")
		if s then s:SetBlendMode("ADD") end
	end
	local grow = WorldMapFrameSizeUpButton
	if grow then
		grow:SetFrameStrata("HIGH")
		grow:SetFrameLevel(frame:GetFrameLevel() + 4)
		grow:SetWidth(G.buttonSide)
		grow:SetHeight(G.buttonSide)
		grow:SetHitRectInsets(0, 0, 0, 0)
		applyButtonState(grow, "Normal", "redbutton-expand")
		applyButtonState(grow, "Pushed", "redbutton-expand-pressed")
		applyButtonState(grow, "Disabled", "redbutton-expand-disabled")
		local s = applyButtonState(grow, "Highlight", "redbutton-highlight")
		if s then s:SetBlendMode("ADD") end
	end
end

-- ---------- Quest pane toggle
-- WorldMapSidePanelToggleTemplate: two 32 x 32 buttons at the same place, one to open
-- (QuestCollapse-Show), one to close (QuestCollapse-Hide), each on the
-- MapCornerShadow-Right shadow, hover UI-Common-MouseHilight in ADD at 48 x 48.
local function buildToggle(map)
	local frame = CreateFrame("Frame", "ForeverUIWorldMapSidePanelToggle", map)
	frame:SetWidth(G.toggleSide)
	frame:SetHeight(G.toggleSide)
	frame:SetPoint("BOTTOMRIGHT", map, "TOPLEFT",
		G.cardX + G.mapW + G.toggleX, G.mapY - G.cardH + G.toggleY)
	local function button(prefix)
		local b = CreateFrame("Button", nil, frame)
		b:SetAllPoints(frame)
		local shadow = b:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(shadow, "mapcornershadow-right")
		shadow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1)
		applyButtonState(b, "Normal", prefix .. "-up")
		applyButtonState(b, "Pushed", prefix .. "-down")
		b:SetHighlightTexture(NAV.squareHover)
		local s = b:GetHighlightTexture()
		s:ClearAllPoints()
		s:SetWidth(48)
		s:SetHeight(48)
		s:SetPoint("CENTER", b, "CENTER", 0, 0)
		s:SetBlendMode("ADD")
		b:SetScript("OnClick", function()
			PlaySound("igMainMenuOptionCheckBoxOn")
			if ForeverUI.QuestLog then
				ForeverUI.QuestLog.togglePane()
			end
		end)
		return b
	end
	frame.open = button("questcollapse-show")
	frame.close = button("questcollapse-hide")
	return frame
end

local function openedPane()
	local J = ForeverUI.QuestLog
	return J and J.settings and J.settings().pane
end

-- ---------- Assembly

local function build()
	local map = WorldMapFrame
	if not map or not WorldMapDetailFrame then
		say(L.WORLDMAP_DEBUG_NO_FRAME)
		return false
	end
	if W.built then
		return true
	end
	if not ForeverUI.SetAtlas then
		say(L.WORLDMAP_DEBUG_NO_ATLAS)
		return false
	end
	-- canvas: the map rectangle, in either mode
	W.canvas = CreateFrame("Frame", "ForeverUIWorldMapCanvas", map)
	W.canvas:SetPoint("TOPLEFT", map, "TOPLEFT", G.cardX, G.mapY)
	W.canvas:SetWidth(G.mapW)
	W.canvas:SetHeight(G.cardH)
	-- holder for the maximized mode: camelot's frame, in UI units
	W.maximized = CreateFrame("Frame", "ForeverUIWorldMapMaximized", map)
	W.background = buildBackground(map)
	W.frame = buildFrame(map)
	W.bar = buildBar(map)
	W.filters = buildFilters(map, W.bar)
	W.floors = buildFloors(map)
	W.coords = buildCoordinates(map)
	W.toggle = buildToggle(map)
	skinRedButtons(map, W.frame)
	W.ownFrames = { W.background, W.frame, W.bar, W.filters, W.coords, W.toggle }
	W.built = true
	return true
end

-- Anchoring shared by both modes: everything is placed on holder (the WotLK map in the
-- small window, the maximized holder otherwise) at scale (the inverse of WorldMapFrame's,
-- back to UI units), around a canvasW x canvasH canvas.
-- maximized: true for the maximized layout (no portrait, other corners and bar offset)
local function anchorMap(holder, scale, canvasW, canvasH, maximized)
	for _, f in ipairs(W.ownFrames) do
		f:SetScale(scale)
	end
	W.floors:SetScale(scale)
	W.canvas:SetScale(scale)
	W.canvas:ClearAllPoints()
	W.canvas:SetPoint("TOPLEFT", holder, "TOPLEFT", G.cardX, G.mapY)
	W.canvas:SetWidth(canvasW)
	W.canvas:SetHeight(canvasH)

	W.background:ClearAllPoints()
	W.background:SetAllPoints(holder)
	local frame = W.frame
	frame:ClearAllPoints()
	frame:SetAllPoints(holder)
	frame.trim:ClearAllPoints()
	frame.trim:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, G.trimY)
	frame.trim:SetPoint("RIGHT", frame, "LEFT", G.cardX + canvasW, 0)
	if maximized then frame.portraitFrame:Hide() else frame.portraitFrame:Show() end
	-- the left corners change with the portrait
	for _, corner in ipairs(METAL) do
		local t = frame.corners[corner.key]
		local a = maximized and METAL_MAXIMIZED[corner.key] or corner
		ForeverUI.SetAtlas(t, a.name)
		t:ClearAllPoints()
		t:SetPoint(corner.point, frame.metal, corner.point, a.x, a.y)
	end

	W.bar:ClearAllPoints()
	W.bar:SetPoint("TOPLEFT", holder, "TOPLEFT", maximized and G.barXMaximized or G.barX, G.barY)
	W.bar:SetPoint("BOTTOMRIGHT", holder, "TOPLEFT", G.cardX + canvasW - 50, G.barBottom)
	W.floors:ClearAllPoints()
	W.floors:SetPoint("TOPLEFT", holder, "TOPLEFT", G.cardX + G.floorX, G.mapY - G.floorY)
	W.coords:ClearAllPoints()
	W.coords:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", G.cardX + G.coordX, G.mapY - canvasH + G.coordY)
	W.toggle:ClearAllPoints()
	W.toggle:SetPoint("BOTTOMRIGHT", holder, "TOPLEFT",
		G.cardX + canvasW + G.toggleX, G.mapY - canvasH + G.toggleY)

	-- frame levels: the background at the map's level, below WorldMapDetailFrame
	W.background:SetFrameLevel(WorldMapFrame:GetFrameLevel())
	W.bar:SetFrameLevel(WorldMapPOIFrame:GetFrameLevel() + 2)
	W.coords:SetFrameLevel(WorldMapPOIFrame:GetFrameLevel() + 2)
	W.toggle:SetFrameLevel(WorldMapPOIFrame:GetFrameLevel() + 2)

	-- what WotLK shows and camelot does not have
	if WorldMapQuestShowObjectives then
		WorldMapQuestShowObjectives:Hide()
	end
	if WorldMapTrackQuest then
		WorldMapTrackQuest:SetAlpha(0)
		WorldMapTrackQuest:EnableMouse(false)
	end
	if WorldMapLevelDropDown then
		WorldMapLevelDropDown:Hide()
	end

	-- title, in the title strip
	local title = WorldMapFrameTitle
	title:SetParent(frame.banner)
	title:ClearAllPoints()
	title:SetPoint("TOP", frame.banner, "TOP", 0, G.titleTextY)
	title:SetPoint("LEFT", frame.banner, "LEFT")
	title:SetPoint("RIGHT", frame.banner, "RIGHT")
	title:SetText(maximized and TEXT.maximizedTitle or TEXT.title)

	-- red buttons: close, and to its left maximize or minimize
	local close = WorldMapFrameCloseButton
	close:SetScale(scale)
	close:ClearAllPoints()
	close:SetPoint("TOPRIGHT", holder, "TOPRIGHT", G.closeX, G.closeY)
	local toggle = maximized and WorldMapFrameSizeDownButton or WorldMapFrameSizeUpButton
	toggle:SetScale(scale)
	toggle:ClearAllPoints()
	toggle:SetPoint("RIGHT", close, "LEFT", G.maximizeX, 0)

	for _, f in ipairs(W.ownFrames) do
		f:Show()
	end
	cropTiles(true)
	refreshBar()
	refreshFloors()
end

-- Windowed mode: lays out camelot-style what WotLK just placed. Runs after
-- WorldMap_ToggleSizeDown and WorldMapFrame_SetMiniMode (which
-- WorldMapFrame_ToggleAdvanced calls on its own).
local function layoutWindowed()
	if not build() or not isSmallWindow() then
		return
	end
	local map = WorldMapFrame

	if WORLDMAP_SETTINGS.advanced then
		placeAnchor()
	end
	-- WorldMapFrame at our scale; its size and anything placed on it without its own
	-- scale are then in WorldMapFrame units
	local k = reducedScale()
	map:SetScale(k)
	W.inverse = 1 / k
	local pane = openedPane()
	map:SetWidth((G.width + (pane and G.paneWidth or 0)) / k)
	map:SetHeight(G.height / k)

	-- the map: its offsets are in its own units, already at our scale
	WorldMapDetailFrame:ClearAllPoints()
	WorldMapDetailFrame:SetPoint("TOPLEFT", map, "TOPLEFT", G.cardX / G.scale, G.mapY / G.scale)
	WorldMapBlobFrame_CalculateHitTranslations()

	-- what WotLK's small window shows and camelot does not have
	suppress(WorldMapFrameMiniBorderLeft)
	suppress(WorldMapFrameMiniBorderRight)
	anchorMap(map, W.inverse, G.mapW, G.cardH, false)

	-- WotLK's title bar (drag, opacity menu) covers the title strip
	if WorldMapTitleButton then
		WorldMapTitleButton:ClearAllPoints()
		WorldMapTitleButton:SetPoint("TOPLEFT", map, "TOPLEFT", G.titleX1 / k, G.titleY / k)
		WorldMapTitleButton:SetPoint("TOPRIGHT", map, "TOPRIGHT", (G.titleX2 - 2 * G.buttonSide) / k, G.titleY / k)
		WorldMapTitleButton:SetHeight(G.titleH / k)
	end

	if pane then
		W.toggle.close:Show()
		W.toggle.open:Hide()
	else
		W.toggle.close:Hide()
		W.toggle.open:Show()
	end
	if ForeverUI.QuestLog and ForeverUI.QuestLog.place then
		ForeverUI.QuestLog.place()
	end
end
W.layoutWindowed = layoutWindowed

-- Maximized mode. What WotLK's full screen shows and camelot does not have: its border
-- (WorldMapFrameTexture1..18, reloaded on each opening), its continent and zone menus,
-- its zoom-out button, the quest list, details and rewards on the right (the map is
-- shown alone), its floor arrows and the two checkboxes.
local SUPPRESSED_MAXIMIZED = {
	"WorldMapZoneMinimapDropDown", "WorldMapZoomOutButton", "WorldMapZoneDropDown",
	"WorldMapContinentDropDown", "WorldMapLevelUpButton", "WorldMapLevelDownButton",
	"WorldMapQuestScrollFrame", "WorldMapQuestDetailScrollFrame", "WorldMapQuestRewardScrollFrame",
}

local function suppressFullScreen()
	for i = 1, 18 do
		suppress(_G["WorldMapFrameTexture" .. i])
	end
	for _, name in ipairs(SUPPRESSED_MAXIMIZED) do
		local f = _G[name]
		if f then f:Hide() end
	end
end

-- Map centered in the canvas, at the scale of WotLK's view (QUESTLIST or FULLMAP);
-- WorldMapFrame carries the rest (applyMaximized).
local function placeMaximizedMap()
	WorldMapDetailFrame:ClearAllPoints()
	WorldMapDetailFrame:SetPoint("CENTER", W.canvas, "CENTER", 0, 0)
	WorldMapBlobFrame_CalculateHitTranslations()
	suppressFullScreen()
end
W.placeMaximizedMap = placeMaximizedMap

-- Maximized mode: sizes camelot's frame over WotLK's full screen and scales
-- WorldMapFrame so the map fits the canvas.
local function applyMaximized()
	if not build() or isSmallWindow() then
		return
	end
	local map = WorldMapFrame
	-- UpdateMaximizedSize, in UI units
	local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
	local available = screenW - G.screenEdge
	local unbounded = ((screenH - G.bannerH) * G.width) / (G.height - G.bannerH)
	local width = math.min(available, unbounded)
	local height = ((screenH - G.bannerH) * (width / unbounded)) + G.bannerH
	width, height = math.floor(width), math.floor(height)

	local canvasW = width - G.cardX - G.mapRight
	local canvasH = height + G.mapY - G.mapBottom
	-- the map fits the canvas, centered (camelot's canvas): at WotLK's view scale
	-- (WORLDMAP_SETTINGS.size), WorldMapFrame, unparented in full screen, carries the rest
	local fitScale = math.min(canvasW / G.usableMapW, canvasH / G.usableMapH)
	map:SetScale(UIParent:GetEffectiveScale() * fitScale / WORLDMAP_SETTINGS.size)
	-- one UI unit in the full screen scaled this way
	local k = UIParent:GetEffectiveScale() / map:GetEffectiveScale()
	W.inverse = k

	local holder = W.maximized
	holder:SetScale(k)
	holder:ClearAllPoints()
	holder:SetPoint("TOP", map, "TOP", 0, 0)
	holder:SetWidth(width)
	holder:SetHeight(height)
	holder:SetFrameLevel(map:GetFrameLevel())

	anchorMap(holder, k, canvasW, canvasH, true)
	placeMaximizedMap()
	W.toggle:Hide()
	applyButtonState(WorldMapFrameSizeDownButton, "Normal", "redbutton-condense")
	applyButtonState(WorldMapFrameSizeDownButton, "Pushed", "redbutton-condense-pressed")
	local s = applyButtonState(WorldMapFrameSizeDownButton, "Highlight", "redbutton-highlight")
	if s then s:SetBlendMode("ADD") end
	WorldMapFrameSizeDownButton:SetWidth(G.buttonSide)
	WorldMapFrameSizeDownButton:SetHeight(G.buttonSide)
	WorldMapFrameSizeDownButton:SetHitRectInsets(0, 0, 0, 0)
	WorldMapFrameSizeDownButton:SetFrameStrata("HIGH")
	WorldMapFrameSizeDownButton:SetFrameLevel(W.frame:GetFrameLevel() + 4)
	if ForeverUI.QuestLog and ForeverUI.QuestLog.hide then
		ForeverUI.QuestLog.hide()
	end
end
W.applyMaximized = applyMaximized

-- Gives back to the client what the skin took from it. Unused.
local function remove()
	if not W.built then
		return
	end
	for _, f in ipairs(W.ownFrames) do
		f:Hide()
	end
	W.floors:Hide()
	cropTiles(false)
	if ForeverUI.QuestLog and ForeverUI.QuestLog.hide then
		ForeverUI.QuestLog.hide()
	end
	WorldMapFrameTitle:SetParent(WorldMapFrame)
	if WorldMapQuestShowObjectives then
		WorldMapQuestShowObjectives:Show()
	end
	if WorldMapTrackQuest then
		WorldMapTrackQuest:SetAlpha(1)
		WorldMapTrackQuest:EnableMouse(true)
	end
end
W.remove = remove

-- Dungeon and raid portals: clicking one opens the instance map. The icons are not
-- client landmarks (AreaPOI.dbc has none): they come from the WDM addon ("WoW Dungeon
-- Maps - HD client", in patch-enus-n.mpq) as WorldMapFrameAtlasPOIn buttons. WDM gives
-- them WotLK's landmark click (WorldMapPOI_OnClick) with mapLinkID = 0, which is true in
-- Lua, so ClickLandmark(0) goes nowhere. Their name (LibBabble-Zone) gives the instance
-- map (WorldMapInstances.lua, generated from the client DBC) and SetMapByID opens it.
-- WotLK landmarks (WorldMapFramePOIn) without a link are handled the same way. Both are
-- created on demand in WorldMapFrame_Update, where WDM may add its own after us, so they
-- are hooked again on the next frame.
local function portalMap(name)
	local t = ForeverUI.InstanceMaps
	return name and t and t[string.lower(name)]
end
W.portalMap = portalMap

local function openPortal(self, button)
	-- a real map link: WotLK handles it
	if button ~= "LeftButton" or (self.mapLinkID and self.mapLinkID ~= 0) then return end
	local id = portalMap(self.name)
	if id and SetMapByID then SetMapByID(id) end
end

local function hookPortals()
	for _, family in ipairs({ { "WorldMapFramePOI", NUM_WORLDMAP_POIS },
		{ "WorldMapFrameAtlasPOI", NUM_WORLDMAP_ATLAS_POI } }) do
		for i = 1, (family[2] or 0) do
			local b = _G[family[1] .. i]
			if b and not b.foreverPortal then
				b.foreverPortal = true
				b:HookScript("OnClick", openPortal)
			end
		end
	end
end
W.hookPortals = hookPortals

local deferredPortals = CreateFrame("Frame")
deferredPortals:Hide()
deferredPortals:SetScript("OnUpdate", function(self)
	self:Hide()
	hookPortals()
end)
W.deferredPortals = deferredPortals

if hooksecurefunc then
	if WorldMap_ToggleSizeDown then
		hooksecurefunc("WorldMap_ToggleSizeDown", layoutWindowed)
	end
	if WorldMapFrame_SetMiniMode then
		hooksecurefunc("WorldMapFrame_SetMiniMode", layoutWindowed)
	end
		if WorldMap_ToggleSizeUp then
		hooksecurefunc("WorldMap_ToggleSizeUp", applyMaximized)
	end
	-- both full-screen views place the map and its scale again
	for _, name in ipairs({ "WorldMapFrame_SetQuestMapView", "WorldMapFrame_SetFullMapView" }) do
		if _G[name] then
			hooksecurefunc(name, function()
				if W.built and not isSmallWindow() then
					applyMaximized()
				end
			end)
		end
	end
	-- in the small window WotLK writes the zone name in the title; camelot keeps
	-- MAP_AND_QUEST_LOG
	if WorldMapFrame_SetMapName then
			hooksecurefunc("WorldMapFrame_SetMapName", function()
			if W.built then
				WorldMapFrameTitle:SetText(isSmallWindow() and TEXT.title or TEXT.maximizedTitle)
			end
		end)
	end
	-- WotLK's floor menu shows itself again on every update
	if WorldMapLevelDropDown_Update then
			hooksecurefunc("WorldMapLevelDropDown_Update", function()
			if W.built then
				WorldMapLevelDropDown:Hide()
				refreshFloors()
			end
		end)
	end
	-- on each opening in the small window: the pane may have changed state while the map
	-- was closed (quest log key, pane button)
	if WorldMapFrame and WorldMapFrame.HookScript then
		-- in full screen the scale is known only here (SetupFullscreenScale)
		-- The first opening builds the skin, also when the map first opens in full screen.
		WorldMapFrame:HookScript("OnShow", function()
			local initial = not W.built
			if isSmallWindow() then
				layoutWindowed()
			else
				applyMaximized()
			end
			-- what the hooks on WotLK functions would have done if the map had been built
			if initial and W.built then
				cropTiles(true)
				refreshBar()
				refreshFloors()
			end
		end)
	end
	-- WorldMapFrame_Update reloads the displayed map's tiles
	if WorldMapFrame_Update then
			hooksecurefunc("WorldMapFrame_Update", function()
			if W.built then
				cropTiles(true)
			end
			hookPortals()
			deferredPortals:Show()
		end)
	end
	-- each map change rebuilds the breadcrumb
	if WorldMapFrame_UpdateMap then
			hooksecurefunc("WorldMapFrame_UpdateMap", function()
			if W.built then
				refreshBar()
				refreshFloors()
			end
		end)
	end
	-- DisplayQuests shows the track checkbox again for each quest
	if WorldMapFrame_DisplayQuests then
			hooksecurefunc("WorldMapFrame_DisplayQuests", function()
			if W.built and WorldMapTrackQuest then
				WorldMapTrackQuest:SetAlpha(0)
				WorldMapTrackQuest:EnableMouse(false)
			end
		end)
	end
end

-- screen size changed: recompute the maximized mode
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
watcher:RegisterEvent("UI_SCALE_CHANGED")
watcher:SetScript("OnEvent", function()
	if W.built and WorldMapFrame:IsShown() and not isSmallWindow() then
		applyMaximized()
	end
end)

-- Prints the map's size, scale, landmarks, breadcrumb and floors to the chat,
-- for diagnosis.
ForeverUI.WorldMapDebug = function()
	local map = WorldMapFrame
	if not map then
		say(L.WORLDMAP_DEBUG_MISSING)
		return
	end
	local function row(text)
		DEFAULT_CHAT_FRAME:AddMessage("   " .. text)
	end
	-- landmarks of the displayed map, and the instance map their name gives
	for i = 1, (GetNumMapLandmarks and GetNumMapLandmarks() or 0) do
		local name, description, icon, x, y, link = GetMapLandmarkInfo(i)
		row(string.format(L.WORLDMAP_DEBUG_LANDMARK, i, tostring(name),
			tostring(description), tostring(icon), tostring(link), tostring(portalMap(name))))
	end
	say(string.format(L.WORLDMAP_DEBUG_FRAME,
		map:GetWidth(), map:GetHeight(), map:GetScale(),
		isSmallWindow() and L.WORLDMAP_DEBUG_MODE_WINDOWED or L.WORLDMAP_DEBUG_MODE_FULLSCREEN,
		WORLDMAP_SETTINGS.size, WORLDMAP_WINDOWED_SIZE))
	local scale = WorldMapDetailFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	row(string.format(L.WORLDMAP_DEBUG_DETAIL,
		WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight(), scale,
		WorldMapDetailFrame:GetWidth() * scale, WorldMapDetailFrame:GetHeight() * scale))
	local names = {}
	for _, d in ipairs(hierarchy()) do
		table.insert(names, d.name or "?")
	end
	row(L.WORLDMAP_DEBUG_BREADCRUMB .. TEXT.world .. (#names > 0 and (" > " .. table.concat(names, " > ")) or ""))
	row(string.format(L.WORLDMAP_DEBUG_FLOORS,
		GetNumDungeonMapLevels and GetNumDungeonMapLevels() or 0,
		tostring(W.built), tostring(map:GetAttribute("UIPanelLayout-area"))))
	row(string.format(L.WORLDMAP_DEBUG_MOVABLE,
		tostring(map:IsMovable()), tostring(GetCVar("advancedWorldMap")),
		tostring(WORLDMAP_SETTINGS.locked)))
end
