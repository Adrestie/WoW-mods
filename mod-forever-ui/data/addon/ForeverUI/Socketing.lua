-- ForeverUI: the gem socketing window (ItemSocketingFrame, Blizzard_ItemSocketingUI) in the
-- camelot style. 3.3.5 has no sublayers: window regions hold rock, marble, trim and panel; a
-- child frame above holds shadow, rivets, parchment, gold and plates. camelot "tile" pieces
-- stretch, since 3.3.5 cannot repeat part of an image (SetTexCoord).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local SO = {}
ForeverUI.Socketing = SO

local SEP = string.char(92)
local FOLDER = "Interface" .. SEP .. "ForeverUI" .. SEP .. "itemsocketingframe" .. SEP
local COMMON = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP

local ART = {
	sheet = FOLDER .. "ui-itemsocketingframe",
	tile = FOLDER .. "ui-itemsocketingframe-_tile",
	parchment = FOLDER .. "ui-itemsocketparchementframe-left",
	gold = COMMON .. "ui-goldborder",
	goldV = COMMON .. "ui-goldborder-!tile",
	goldH = COMMON .. "ui-goldborder-_tile",
	marble = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
}

local N = {
	window = { 338, 424 },
	portrait = { side = 48, x = 1, y = 1.5 },
	title = { 15, -5 },
	inset = { 4, -60, -6, 4 },
	panel = { 20, -74, -20, 80 },
	color = { 0.078125, 0.12109375, 0.21484375, 0.4 },
	scroll = { 22, -74, 293, 258 },
	child = 259, minimum = 240,
	-- without the bar: the panel spans 20 to 318 and the scroll frame starts at 22, so it ends
	-- at 316, the same 2 px margin as on the left
	childNoBar = 294,
	bar = { -14, -5, 1 },
	socket = { y = 33, x = { [1] = 0, [2] = -35, [3] = -75 } },
	flare = { 1, 0 },
	apply = { 162, 22, -5, 4 },
	skinLevel = 1, contentLevel = 2, closeButtonLevel = 22,
}

local KITS = { Yellow = "yellow", Red = "red", Blue = "blue", Meta = "meta", Socket = "prismatic" }

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- File texture cropped to u1..u2, v1..v2; l, h: optional width and height.
local function piece(host, layer, file, u1, u2, v1, v2, l, h)
	local t = host:CreateTexture(nil, layer)
	t:SetTexture(file)
	t:SetTexCoord(u1, u2, v1, v2)
	if l then t:SetWidth(l) end
	if h then t:SetHeight(h) end
	return t
end

-- ------------------------------------------------------------ skin

-- Child frame above the window regions: shadow, rivets, parchment, plates, gold border.
local function skinLayer(f)
	local d = CreateFrame("Frame", nil, f)
	d:SetAllPoints(f)
	d:SetFrameLevel(f:GetFrameLevel() + N.skinLevel)
	d:EnableMouse(false)
	local p = {}
	-- panel shadow (BACKGROUND of the child frame: below everything else)
	local c = {
		topLeft = piece(d, "BACKGROUND", ART.gold, 0.12890625, 0.25390625, 0.0078125, 0.2578125, 32, 32),
		topRight = piece(d, "BACKGROUND", ART.gold, 0.25390625, 0.12890625, 0.0078125, 0.2578125, 32, 32),
		bottomLeft = piece(d, "BACKGROUND", ART.gold, 0.12890625, 0.25390625, 0.2578125, 0.0078125, 32, 32),
		bottomRight = piece(d, "BACKGROUND", ART.gold, 0.25390625, 0.12890625, 0.2578125, 0.0078125, 32, 32),
	}
	c.topLeft:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -74)
	c.topRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -74)
	c.bottomLeft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 88)
	c.bottomRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 88)
	local function between(t, a1, c1, r1, a2, c2, r2)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
		return t
	end
	p.shadow = c
	between(piece(d, "BACKGROUND", ART.goldH, 0, 1, 0.1875, 0.6875, nil, 32), "TOPLEFT", c.topLeft, "TOPRIGHT", "TOPRIGHT", c.topRight, "TOPLEFT")
	between(piece(d, "BACKGROUND", ART.goldH, 0, 1, 0.6875, 0.1875, nil, 32), "BOTTOMLEFT", c.bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", c.bottomRight, "BOTTOMLEFT")
	between(piece(d, "BACKGROUND", ART.goldV, 0.34375, 0.59375, 0, 1, 32, nil), "TOPLEFT", c.topLeft, "BOTTOMLEFT", "BOTTOMLEFT", c.bottomLeft, "TOPLEFT")
	between(piece(d, "BACKGROUND", ART.goldV, 0.59375, 0.34375, 0, 1, 32, nil), "TOPRIGHT", c.topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", c.bottomRight, "TOPRIGHT")
	-- rivets (NubTemplate)
	p.rivets = {}
	for _, v in ipairs({ { "BOTTOMLEFT", 6, 20 }, { "BOTTOMRIGHT", -5, 20 }, { "BOTTOMLEFT", 6, 72 },
		{ "BOTTOMRIGHT", -5, 72 }, { "TOPLEFT", 6, -57 }, { "TOPRIGHT", -5, -57 } }) do
		local t = piece(d, "BORDER", ART.sheet, 0.62890625, 0.671875, 0.00390625, 0.05078125, 11, 12)
		t:SetPoint(v[1], f, v[1], v[2], v[3])
		p.rivets[#p.rivets + 1] = t
	end
	-- parchment
	local top = piece(d, "ARTWORK", ART.tile, 0, 1, 0.375, 0.703125, nil, 42)
	top:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -21)
	top:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -21)
	local down = piece(d, "ARTWORK", ART.tile, 0, 1, 0.1875, 0.359375, nil, 22)
	down:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 3)
	down:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 3)
	local left = piece(d, "ARTWORK", ART.parchment, 0, 0.75, 0, 1, 9, nil)
	left:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -62)
	left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 25)
	local right = piece(d, "ARTWORK", ART.parchment, 0, 0.75, 0, 1, 5, nil)
	right:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -62)
	right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 25)
	p.parchment = { top = top, down = down, left = left, right = right }
	-- socket plates and the button frame
	local pg = piece(d, "ARTWORK", ART.sheet, 0.00390625, 0.62109375, 0.00390625, 0.203125, 158, 51)
	pg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 11, 26)
	local pd = piece(d, "ARTWORK", ART.sheet, 0.00390625, 0.62109375, 0.2109375, 0.41015625, 158, 51)
	pd:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 26)
	local bottomLeft = piece(d, "ARTWORK", ART.sheet, 0.62890625, 0.64453125, 0.05859375, 0.140625, 4, 21)
	bottomLeft:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -167, 4)
	local bottomRight = piece(d, "ARTWORK", ART.sheet, 0.65234375, 0.66796875, 0.05859375, 0.140625, 4, 21)
	bottomRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
	local bm = piece(d, "ARTWORK", ART.tile, 0, 1, 0.0078125, 0.171875, nil, 21)
	bm:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT")
	bm:SetPoint("TOPRIGHT", bottomRight, "TOPLEFT")
	p.plates = { pg, pd }
	p.buttonFrame = { bottomLeft, bm, bottomRight }
	-- gold border
	local o = {
		bottomRight = piece(d, "ARTWORK", ART.gold, 0.26171875, 0.51953125, 0.0078125, 0.4375, 66, 55),
		bottomLeft = piece(d, "ARTWORK", ART.gold, 0.26171875, 0.51953125, 0.453125, 0.8828125, 66, 55),
		topRight = piece(d, "ARTWORK", ART.gold, 0.52734375, 0.78515625, 0.0078125, 0.4375, 66, 55),
		topLeft = piece(d, "ARTWORK", ART.gold, 0.52734375, 0.78515625, 0.453125, 0.8828125, 66, 55),
	}
	o.bottomRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 79)
	o.bottomLeft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 11, 79)
	o.topRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -64)
	o.topLeft:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -64)
	p.gold = o
	between(piece(d, "ARTWORK", ART.goldV, 0.0078125, 0.078125, 0, 1, 9, nil), "TOPLEFT", o.topLeft, "BOTTOMLEFT", "BOTTOMLEFT", o.bottomLeft, "TOPLEFT")
	between(piece(d, "ARTWORK", ART.goldV, 0.0078125, 0.078125, 0, 1, 9, nil), "TOPRIGHT", o.topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", o.bottomRight, "TOPRIGHT")
	between(piece(d, "ARTWORK", ART.goldH, 0, 1, 0.015625, 0.15625, nil, 9), "TOPLEFT", o.topLeft, "TOPRIGHT", "TOPRIGHT", o.topRight, "TOPLEFT")
	between(piece(d, "ARTWORK", ART.goldH, 0, 1, 0.015625, 0.15625, nil, 9), "BOTTOMLEFT", o.bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", o.bottomRight, "BOTTOMLEFT")
	p.frame = d
	return p
end

-- ------------------------------------------------------------ after the client

-- Description width by scroll bar, with the client's test (GetVerticalScrollRange) run
-- after it: without a bar, the scroll frame and its child take the bar's room.
function SO.UpdateWidths()
	local fx = ItemSocketingScrollFrame
	if not fx then return end
	local hasBar = (fx:GetVerticalScrollRange() or 0) ~= 0
	fx:SetWidth(hasBar and N.scroll[3] or N.childNoBar)
	ItemSocketingScrollChild:SetWidth(hasBar and N.child or N.childNoBar)
end

-- The client asks 240 + 28 without a bar, then fills the description. Setting it again
-- after the fill would change the range and make the client set it back, so this post-hook
-- on SetMinimumWidth swaps in our value (240 + 35) before the fill.
-- width, force: the SetMinimumWidth arguments
local function minimumNoBar(self, width, force)
	if SO.inMinimumWidth then return end
	if width == (ITEM_SOCKETING_DESCRIPTION_MIN_WIDTH or N.minimum) + 28 then
		SO.inMinimumWidth = true
		self:SetMinimumWidth(N.minimum + N.childNoBar - N.child, force)
		SO.inMinimumWidth = false
	end
end

-- After ItemSocketingFrame_Update: portrait, sockets at their camelot place, camelot
-- backgrounds and brackets
function SO.After()
	local h = ItemSocketingFrame and ItemSocketingFrame.foreverSkin
	if not h then return end
	local _, icon = GetSocketItemInfo()
	if icon then SetPortraitToTexture(h.portrait, icon) end
	local n = GetNumSockets() or 0
	local C = N.socket
	place(ItemSocketingSocket1, "BOTTOM", ItemSocketingFrame, "BOTTOM", C.x[n] or C.x[1], C.y)
	for i = 1, math.min(n, MAX_NUM_SOCKETS or 3) do
		local name = "ItemSocketingSocket" .. i
		local kit = KITS[GetSocketTypes(i) or ""]
		if kit then
			ForeverUI.SetAtlas(_G[name .. "Background"], "socket-" .. kit .. "-background")
			ForeverUI.SetAtlas(_G[name .. "BracketFrameClosedBracket"], "socket-" .. kit .. "-closed")
			ForeverUI.SetAtlas(_G[name .. "BracketFrameOpenBracket"], "socket-" .. kit .. "-open")
		end
	end
	SO.UpdateWidths()
end

function SO.Skin()
	local f = ItemSocketingFrame
	if not f or f.foreverSkin then return end
	-- hide the 3.3.5 512 px image, its unnamed title and the client portrait
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" and string.find(string.lower(t), "ui-itemsocketingframe", 1, true) then r:SetAlpha(0) end
		elseif r:GetObjectType() == "FontString" and r:GetText() == ITEM_SOCKETING then
			r:SetAlpha(0)
		end
	end
	ItemSocketingFramePortrait:SetAlpha(0)
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = ITEM_SOCKETING,
	})
	f.foreverSkin = skin
	skin.title:ClearAllPoints()
	skin.title:SetPoint("TOP", f, "TOP", N.title[1], N.title[2])
	-- inset: marble (BORDER, above the rock), trim in ARTWORK
	local E = N.inset
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", E[1], E[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", E[3], E[4])
	local marble = f:CreateTexture(nil, "BORDER")
	marble:SetTexture(ART.marble, true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(rect)
	skin.inset = { rect = rect, marble = marble, trim = Tpl.NineSlice(f, "InsetFrameTemplate", rect, "ARTWORK") }
	-- description panel: its color (ARTWORK), its image (OVERLAY)
	local P = N.panel
	local color = f:CreateTexture(nil, "ARTWORK")
	color:SetTexture(N.color[1], N.color[2], N.color[3], N.color[4])
	color:SetPoint("TOPLEFT", f, "TOPLEFT", P[1], P[2])
	color:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", P[3], P[4])
	local light = piece(f, "OVERLAY", ART.sheet, 0.00390625, 0.50390625, 0.41796875, 0.91796875)
	light:SetPoint("TOPLEFT", f, "TOPLEFT", P[1], P[2])
	light:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", P[3], P[4])
	skin.panel = { color = color, light = light }
	skin.scenery = skinLayer(f)
	-- content above the scenery
	local level = f:GetFrameLevel() + N.contentLevel
	local D = N.scroll
	local fx = ItemSocketingScrollFrame
	fx:SetFrameLevel(level)
	place(fx, "TOPLEFT", f, "TOPLEFT", D[1], D[2])
	fx:SetWidth(D[3])
	fx:SetHeight(D[4])
	for _, s in ipairs({ "Top", "Bottom" }) do
		local t = _G["ItemSocketingScrollFrame" .. s]
		if t then t:SetAlpha(0) end
	end
	Tpl.BarAt(ItemSocketingScrollFrameScrollBar, fx, N.bar[1], N.bar[2], N.bar[3])
	-- sockets: camelot right filigree, centred open bracket, shine
	for i = 1, MAX_NUM_SOCKETS or 3 do
		local name = "ItemSocketingSocket" .. i
		local s = _G[name]
		if s then
			s:SetFrameLevel(level)
			local right = _G[name .. "Right"]
			right:SetWidth(70)
			right:SetHeight(55)
			right:SetTexCoord(0.28515625, 0.565, 0, 0.21484375)
			place(_G[name .. "BracketFrameOpenBracket"], "CENTER", _G[name .. "BracketFrame"], "CENTER", 0, 0)
			place(_G[name .. "Shine"], "CENTER", s, "CENTER", N.flare[1], N.flare[2])
		end
	end
	local A = N.apply
	local b = ItemSocketingSocketButton
	b:SetFrameLevel(level)
	b:SetWidth(A[1])
	b:SetHeight(A[2])
	place(b, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A[3], A[4])
	b:SetText(APPLY)
	Tpl.CloseButton(ItemSocketingCloseButton, f)
	ItemSocketingCloseButton:SetFrameLevel(f:GetFrameLevel() + N.closeButtonLevel)
	hooksecurefunc(ItemSocketingDescription, "SetMinimumWidth", minimumNoBar)
	hooksecurefunc("ItemSocketingFrame_Update", SO.After)
	hooksecurefunc("ItemSocketingSocketButton_OnScrollRangeChanged", SO.UpdateWidths)
end

SO.Skin()

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_ItemSocketingUI" then
		SO.Skin()
	end
end)
