-- Shared base for the login screens rebuilt from camelot, which use camelot's numbers as is:
-- scale, usable area and fonts are set here once, along with camelot's templates (atlas,
-- nine-slice layouts, three-slice red button, dialog border and header, window).

ForeverUIGlue = ForeverUIGlue or {}
local G = ForeverUIGlue

-- ---------- 1. Scale

-- not every 3.3.5 CVar is registered on the glue screens, and GetCVar then raises an error,
-- so the read is protected
local function cvar(name)
	if not GetCVar then
		return nil
	end
	local ok, value = pcall(GetCVar, name)
	if ok then
		return value
	end
	return nil
end

local function screenHeight()
	local resolution = cvar("gxResolution")
	local height = resolution and tonumber(string.match(resolution, "%d+x(%d+)"))
	return height or 1080
end

-- camelot glue screen height in units: the screen height, capped at 1200 (measured 1200 on
-- a 1600 px screen, the only height measured). 3.3.5 glue screens are 768 units tall, so
-- GlueParent is scaled 768 / height: everything in it counts in camelot units.
G.CAMELOT_HEIGHT = math.min(math.max(screenHeight(), 768), 1200)
G.SCALE = 768 / G.CAMELOT_HEIGHT
G.MAX_RATIO = 2

GlueParent:SetScale(G.SCALE)

-- ---------- 2. Usable area
-- GlueParent_OnLoad (3.3.5) bounds it to 16:9; camelot's is 2:1 (version text 10 units
-- from the left edge, Quit 24 from the right).

function G.FitScreen()
	local width = GetScreenWidth() / G.SCALE
	local height = GetScreenHeight() / G.SCALE
	local strip = 0
	if width / height > G.MAX_RATIO then
		strip = (width - height * G.MAX_RATIO) / 2
	end
	-- width of each strip outside the area, in camelot units
	G.STRIP = strip
	GlueParent:ClearAllPoints()
	GlueParent:SetPoint("TOPLEFT", strip, 0)
	GlueParent:SetPoint("BOTTOMRIGHT", -strip, 0)
end
G.FitScreen()

-- Resolution change: scale and area depend on gxResolution and the screen size, and applying
-- another resolution (RestartGx) does not notify the glue screens. The three values are read
-- five times per second; on a change both are recomputed and every G.onScale callback runs.
G.onScale = {}

function G.Rescale()
	G.CAMELOT_HEIGHT = math.min(math.max(screenHeight(), 768), 1200)
	G.SCALE = 768 / G.CAMELOT_HEIGHT
	GlueParent:SetScale(G.SCALE)
	G.FitScreen()
	for _, f in ipairs(G.onScale) do
		f()
	end
end

local function fingerprint()
	return (cvar("gxResolution") or "") .. " " .. GetScreenWidth() .. " " .. GetScreenHeight()
end

local screenWatcher = CreateFrame("Frame")
screenWatcher.fingerprint = fingerprint()
screenWatcher.t = 0
screenWatcher:SetScript("OnUpdate", function(self, elapsed)
	self.t = self.t + (elapsed or 0)
	if self.t < 0.2 then
		return
	end
	self.t = 0
	local e = fingerprint()
	if e ~= self.fingerprint then
		self.fingerprint = e
		G.Rescale()
	end
end)

-- ---------- 3. Fonts
-- 3.3.5 ignores FontHeight on an inherited font, so ForeverUIGlueFonts.xml
-- (tools/glue_fonts.py) holds camelot's fonts flattened; G.Font returns one by camelot name.

function G.Font(name)
	local font = _G["ForeverUIGlue_" .. name]
	if not font then
		error(G.L.GLUE_ERROR_MISSING_FONT .. tostring(name))
	end
	return font
end

-- ---------- Hooks

-- adds a handler to a script without replacing the client's
function G.Hook(frame, script, func)
	if frame.HookScript then
		frame:HookScript(script, func)
		return
	end
	local before = frame:GetScript(script)
	frame:SetScript(script, function(...)
		if before then
			before(...)
		end
		func(...)
	end)
end

function G.SetShown(region, yes)
	if yes then region:Show() else region:Hide() end
end

-- ---------- Atlas

-- places an atlas element (tools/glue_atlas.py); atlasSize: apply its official size
-- (camelot SetAtlas(name, true)). Returns the entry.
function G.PlaceAtlas(texture, name, atlasSize)
	local e = G.atlas[string.lower(name)]
	if not e then
		error(G.L.GLUE_ERROR_MISSING_ATLAS .. tostring(name))
	end
	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[3], e[4], e[5])
	if atlasSize then
		texture:SetWidth(e[6])
		texture:SetHeight(e[7])
	end
	return e
end

-- 3.3.5 can only tile a whole image: an element that fills its sheet tiles, others stretch
local function tile(texture, e)
	local isWhole = e[2] == 0 and e[3] == 1 and e[4] == 0 and e[5] == 1
	if isWhole and (e[8] or e[9]) and texture.SetHorizTile then
		texture:SetTexture(e[1], true)
		texture:SetHorizTile(e[8] and true or false)
		texture:SetVertTile(e[9] and true or false)
	end
end

-- ---------- Nine-slice

-- blizzard_sharedxml/mainline/nineslicelayouts.lua (layouts copied as is) and nineslice.lua
-- (ApplyLayout).
G.LAYOUTS = {
	TooltipMixedLayout = {
		TopRightCorner = { atlas = "Tooltip-Glues-NineSlice-CornerTopRight" },
		TopLeftCorner = { atlas = "Tooltip-Glues-NineSlice-CornerTopLeft" },
		BottomLeftCorner = { atlas = "Tooltip-Glues-NineSlice-CornerBottomLeft" },
		BottomRightCorner = { atlas = "Tooltip-Glues-NineSlice-CornerBottomRight" },
		TopEdge = { atlas = "_Tooltip-Glues-NineSlice-EdgeTop" },
		BottomEdge = { atlas = "_Tooltip-Glues-NineSlice-EdgeBottom" },
		LeftEdge = { atlas = "!Tooltip-Glues-NineSlice-EdgeLeft" },
		RightEdge = { atlas = "!Tooltip-Glues-NineSlice-EdgeRight" },
		Center = { layer = "BACKGROUND", atlas = "Tooltip-NineSlice-Center", x = -8, y = 10, x1 = 8, y1 = -7 },
	},
	TooltipDefaultLayout = {
		TopRightCorner = { atlas = "Tooltip-NineSlice-CornerTopRight" },
		TopLeftCorner = { atlas = "Tooltip-NineSlice-CornerTopLeft" },
		BottomLeftCorner = { atlas = "Tooltip-NineSlice-CornerBottomLeft" },
		BottomRightCorner = { atlas = "Tooltip-NineSlice-CornerBottomRight" },
		TopEdge = { atlas = "_Tooltip-NineSlice-EdgeTop" },
		BottomEdge = { atlas = "_Tooltip-NineSlice-EdgeBottom" },
		LeftEdge = { atlas = "!Tooltip-NineSlice-EdgeLeft" },
		RightEdge = { atlas = "!Tooltip-NineSlice-EdgeRight" },
		Center = { layer = "BACKGROUND", atlas = "Tooltip-NineSlice-Center", x = -4, y = 4, x1 = 4, y1 = -4 },
	},
	Dialog = {
		TopLeftCorner = { atlas = "UI-Frame-DiamondMetal-CornerTopLeft" },
		TopRightCorner = { atlas = "UI-Frame-DiamondMetal-CornerTopRight" },
		BottomLeftCorner = { atlas = "UI-Frame-DiamondMetal-CornerBottomLeft" },
		BottomRightCorner = { atlas = "UI-Frame-DiamondMetal-CornerBottomRight" },
		TopEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeTop" },
		BottomEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom" },
		LeftEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft" },
		RightEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeRight" },
	},
	-- ButtonFrameTemplateNoPortrait with camelot/NineSliceLayoutOverrides.lua
	-- (top right corner x - 2; bottom corners y = -8, bottom right x - 2)
	ButtonFrameTemplateNoPortrait = {
		TopLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopLeft", x = -8, y = 16 },
		TopRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 2, y = 16 },
		BottomLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -8, y = -8 },
		BottomRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 2, y = -8 },
		TopEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop" },
		BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom" },
		LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft" },
		RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight" },
	},
	InsetFrameTemplate = {
		TopLeftCorner = { atlas = "UI-Frame-InnerTopLeft" },
		TopRightCorner = { atlas = "UI-Frame-InnerTopRight" },
		BottomLeftCorner = { atlas = "UI-Frame-InnerBotLeftCorner", x = 0, y = -1 },
		BottomRightCorner = { atlas = "UI-Frame-InnerBotRight", x = 0, y = -1 },
		TopEdge = { atlas = "_UI-Frame-InnerTopTile" },
		BottomEdge = { atlas = "_UI-Frame-InnerBotTile" },
		LeftEdge = { atlas = "!UI-Frame-InnerLeftTile" },
		RightEdge = { atlas = "!UI-Frame-InnerRightTile" },
	},
}

-- order and anchors of nineSliceSetup (nineslice.lua)
local PIECES = {
	{ "TopLeftCorner", "TOPLEFT" },
	{ "TopRightCorner", "TOPRIGHT" },
	{ "BottomLeftCorner", "BOTTOMLEFT" },
	{ "BottomRightCorner", "BOTTOMRIGHT" },
	{ "TopEdge", "TOPLEFT", "TOPRIGHT", "TopLeftCorner", "TopRightCorner" },
	{ "BottomEdge", "BOTTOMLEFT", "BOTTOMRIGHT", "BottomLeftCorner", "BottomRightCorner" },
	{ "LeftEdge", "TOPLEFT", "BOTTOMLEFT", "TopLeftCorner", "BottomLeftCorner" },
	{ "RightEdge", "TOPRIGHT", "BOTTOMRIGHT", "TopRightCorner", "BottomRightCorner" },
	{ "Center" },
}

-- Applies a layout to a frame as regions of that frame (in 3.3.5 a child frame would cover
-- the frame's texts). Returns the pieces by name. target: rectangle the corners align on,
-- the host by default (e.g. an inset drawn as regions of its window).
function G.NineSlice(host, layoutName, target)
	local layout = G.LAYOUTS[layoutName]
	local p = {}
	for _, m in ipairs(PIECES) do
		local name = m[1]
		local l = layout[name]
		if l then
			local t = host:CreateTexture(nil, l.layer or "BORDER")
			p[name] = t
			if name == "Center" then
				local e = G.PlaceAtlas(t, l.atlas, true)
				t:SetPoint("TOPLEFT", p.TopLeftCorner, "BOTTOMRIGHT", l.x or 0, l.y or 0)
				t:SetPoint("BOTTOMRIGHT", p.BottomRightCorner, "TOPLEFT", l.x1 or 0, l.y1 or 0)
				tile(t, e)
			elseif m[3] then
				local e = G.PlaceAtlas(t, l.atlas, true)
				t:SetPoint(m[2], p[m[4]], m[3], l.x or 0, l.y or 0)
				t:SetPoint(m[3], p[m[5]], m[2], l.x1 or 0, l.y1 or 0)
				tile(t, e)
			else
				G.PlaceAtlas(t, l.atlas, true)
				t:SetPoint(l.point or m[2], target or host, l.relativePoint or l.point or m[2], l.x or 0, l.y or 0)
			end
		end
	end
	return p
end

-- NineSlicePanel SetCenterColor / SetBorderColor
function G.NineSliceColors(p, center, edge)
	for name, t in pairs(p) do
		local c = (name == "Center") and center or edge
		if c then
			t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		end
	end
end

-- TooltipBackdropTemplate: layout, then background color (backdropColor, else
-- TOOLTIP_DEFAULT_BACKGROUND_COLOR) and border color
G.GLUE_BACKDROP_COLOR = { 0.09, 0.09, 0.09 }
G.GLUE_BACKDROP_BORDER_COLOR = { 0.8, 0.8, 0.8 }

function G.TooltipBackground(host, layoutName, background, edge)
	local p = G.NineSlice(host, layoutName)
	G.NineSliceColors(p, background, edge)
	return p
end

-- ---------- Red button

-- blizzard_sharedxml/shared/button/threeslicebuttontemplate.xml / .lua: Left and Right at
-- their atlas size scaled to the button height, Center stretched between them, Left and
-- Right cropped when they do not fit (UpdateScale); -Pressed and -Disabled states,
-- atlasName-Highlight glow, text pushed by (-2, -1) (BigRedThreeSliceButtonTemplate).

local function cropTexture(t, e, leftToRight, part)
	-- keep a part of the element's width; leftToRight: keep its left side
	local u1, u2 = e[2], e[3]
	if leftToRight then
		t:SetTexCoord(u1, u1 + (u2 - u1) * part, e[4], e[5])
	else
		t:SetTexCoord(u2 - (u2 - u1) * part, u2, e[4], e[5])
	end
end

local function paintThreeSlices(b, state)
	local r = b.foreverThreeSlice
	if not b:IsEnabled() then
		state = "DISABLED"
	end
	local suffix = ""
	if state == "DISABLED" then
		suffix = "-Disabled"
	elseif state == "PUSHED" then
		suffix = "-Pressed"
	end
	local eg = G.PlaceAtlas(r.left, r.atlas .. "-Left" .. suffix)
	G.PlaceAtlas(r.center, "_" .. r.atlas .. "-Center" .. suffix)
	local ed = G.PlaceAtlas(r.right, r.atlas .. "-Right" .. suffix)

	-- UpdateScale
	local height, width = b:GetHeight(), b:GetWidth()
	local scale = height / eg[7]
	local lg, ld = eg[6] * scale, ed[6] * scale
	if lg + ld > width then
		local excess = lg + ld - width
		local ng, nd = lg, ld
		if (lg - excess) > ld then
			ng = lg - excess
		elseif (ld - excess) > lg then
			nd = ld - excess
		else
			if lg ~= ld then
				excess = excess - math.abs(lg - ld)
				ng = math.min(lg, ld)
				nd = ng
			end
			ng = ng - excess / 2
			nd = nd - excess / 2
		end
		cropTexture(r.left, eg, true, ng / lg)
		cropTexture(r.right, ed, false, nd / ld)
		lg, ld = ng, nd
	end
	r.left:SetWidth(lg)
	r.left:SetHeight(height)
	r.right:SetWidth(ld)
	r.right:SetHeight(height)
	r.active = b:IsEnabled() and true or false
end

-- clears the art the 3.3.5 client puts on its own buttons
function G.ClearClientArt(b)
	for _, read in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = b[read] and b[read](b)
		if t then
			t:SetTexture(nil)
		end
	end
end

-- fonts: { normal, highlight, disabled }, camelot font names
function G.ThreeSliceButton(b, atlas, fonts)
	G.ClearClientArt(b)
	local r = { atlas = atlas }
	r.left = b:CreateTexture(nil, "BACKGROUND")
	r.left:SetPoint("TOPLEFT", b, "TOPLEFT")
	r.right = b:CreateTexture(nil, "BACKGROUND")
	r.right:SetPoint("TOPRIGHT", b, "TOPRIGHT")
	r.center = b:CreateTexture(nil, "BACKGROUND")
	r.center:SetPoint("TOPLEFT", r.left, "TOPRIGHT")
	r.center:SetPoint("BOTTOMRIGHT", r.right, "BOTTOMLEFT")
	b.foreverThreeSlice = r

	-- glow: SetHighlightAtlas over the whole button, ADD blend
	local function glow()
		b:SetHighlightTexture(G.atlas[string.lower(atlas .. "-Highlight")][1])
		local h = b:GetHighlightTexture()
		G.PlaceAtlas(h, atlas .. "-Highlight")
		h:ClearAllPoints()
		h:SetAllPoints(b)
		h:SetBlendMode("ADD")
	end
	glow()
	r.glow = glow

	if fonts then
		b:SetNormalFontObject(G.Font(fonts[1]))
		b:SetHighlightFontObject(G.Font(fonts[2] or fonts[1]))
		b:SetDisabledFontObject(G.Font(fonts[3] or fonts[1]))
	end
	local text = b:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
	b:SetPushedTextOffset(-2, -1)

	G.Hook(b, "OnMouseDown", function(self)
		if self:IsEnabled() then
			paintThreeSlices(self, "PUSHED")
		end
	end)
	G.Hook(b, "OnMouseUp", function(self) paintThreeSlices(self, "NORMAL") end)
	G.Hook(b, "OnShow", function(self) paintThreeSlices(self, "NORMAL") end)
	G.Hook(b, "OnSizeChanged", function(self) paintThreeSlices(self, "NORMAL") end)
	-- 3.3.5 has no Enable / Disable event, so the state is polled; and
	-- CharacterSelect_DeathKnightSwap restores the client art (background AND glow) on some
	-- buttons, so it is cleared and the glow re-applied
	G.Hook(b, "OnUpdate", function(self)
		local n = self:GetNormalTexture()
		if n and n:GetTexture() then
			G.ClearClientArt(self)
			self.foreverThreeSlice.glow()
		end
		if (self:IsEnabled() and true or false) ~= self.foreverThreeSlice.active then
			paintThreeSlices(self, "NORMAL")
		end
	end)
	paintThreeSlices(b, "NORMAL")
	return b
end

function G.CreateThreeSliceButton(name, parent, width, height, atlas, fonts, text)
	local b = CreateFrame("Button", name, parent)
	b:SetWidth(width)
	b:SetHeight(height)
	b:SetText(text or "")
	G.ThreeSliceButton(b, atlas, fonts)
	return b
end

-- ---------- Dialog

-- DialogBorderTemplate: UI-DialogBox-Background tiled 7 in from the edge, Dialog layout
-- (DialogBorderNoCenterTemplate)
function G.DialogFrame(host)
	local background = host:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background", true)
	if background.SetHorizTile then
		background:SetHorizTile(true)
		background:SetVertTile(true)
	end
	background:SetPoint("TOPLEFT", host, "TOPLEFT", 7, -7)
	background:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -7, 7)
	return G.NineSlice(host, "Dialog"), background
end

-- DialogHeaderTemplate: 200 x 39 at TOP (0, 11); 32 x 39 corners, tile between them;
-- text at TOP (0, -13); width = text + headerTextPadding (64)
function G.DialogHeader(parent, text, font)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(200)
	f:SetHeight(39)
	f:SetPoint("TOP", parent, "TOP", 0, 11)
	local g = f:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(g, "UI-Frame-DiamondMetal-Header-CornerLeft")
	g:SetWidth(32)
	g:SetHeight(39)
	g:SetPoint("LEFT", f, "LEFT")
	local d = f:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(d, "UI-Frame-DiamondMetal-Header-CornerRight")
	d:SetWidth(32)
	d:SetHeight(39)
	d:SetPoint("RIGHT", f, "RIGHT")
	local c = f:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(c, "_UI-Frame-DiamondMetal-Header-Tile")
	c:SetPoint("TOPLEFT", g, "TOPRIGHT")
	c:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	local t = f:CreateFontString(nil, "ARTWORK")
	t:SetFontObject(G.Font(font or "GameFontNormal"))
	t:SetPoint("TOP", f, "TOP", 0, -13)
	t:SetText(text)
	f.Text = t
	f:SetWidth(t:GetStringWidth() + 64)
	return f
end

-- ---------- Window

local ROCK_BACKGROUND = "Interface\\ForeverUI\\framegeneral\\ui-background-rock"
local MARBLE_BACKGROUND = "Interface\\ForeverUI\\framegeneral\\ui-background-marble"

local function tileBackground(t, file)
	t:SetTexture(file, true)
	if t.SetHorizTile then
		t:SetHorizTile(true)
		t:SetVertTile(true)
	end
end

-- ButtonFrameTemplate without portrait (shareduipaneltemplates.xml / .lua): rock background
-- tiled from (7, -21) to (-2, 2), _UI-Frame-TopTileStreaks from (6, -21) to (-2, -21), metal
-- frame, GameFontNormal title 5 below the top (TitleContainer, 20 tall at (0, -1)). All are
-- host regions; the title sits in a child frame above the metal.
-- Returns { title, frame, background, stripes }. translucent: black at 0.8 instead of the
-- rock (DialogBorderTranslucentTemplate).
function G.Window(host, title, translucent)
	local background = host:CreateTexture(nil, "BACKGROUND")
	if translucent then
		background:SetTexture(0, 0, 0, 0.8)
	else
		tileBackground(background, ROCK_BACKGROUND)
	end
	background:SetPoint("TOPLEFT", host, "TOPLEFT", 7, -21)
	background:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 2)
	local stripes = host:CreateTexture(nil, "BORDER")
	G.PlaceAtlas(stripes, "_UI-Frame-TopTileStreaks", true)
	stripes:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -21)
	stripes:SetPoint("TOPRIGHT", host, "TOPRIGHT", -2, -21)
	local frame = G.NineSlice(host, "ButtonFrameTemplateNoPortrait")
	local container = CreateFrame("Frame", nil, host)
	container:SetFrameLevel(host:GetFrameLevel() + 10)
	container:SetHeight(20)
	container:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -1)
	container:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -1)
	local t = container:CreateFontString(nil, "OVERLAY")
	t:SetFontObject(G.Font("GameFontNormal"))
	t:SetPoint("TOP", container, "TOP", 0, -5)
	t:SetPoint("LEFT", container, "LEFT")
	t:SetPoint("RIGHT", container, "RIGHT")
	t:SetText(title or "")
	return { title = t, frame = frame, background = background, stripes = stripes }
end

-- InsetFrameTemplate: tiled UI-Background-Marble and the InsetFrameTemplate border, as host
-- regions (BORDER layer: above the window background, under its metal) on the target
-- rectangle; a child frame would cover the window content. translucent: no marble, the
-- window background shows through (see G.Window).
function G.Inset(host, target, translucent)
	local background
	if not translucent then
		background = host:CreateTexture(nil, "BORDER")
		tileBackground(background, MARBLE_BACKGROUND)
		background:SetAllPoints(target)
	end
	return G.NineSlice(host, "InsetFrameTemplate", target), background
end

-- UIPanelCloseButton: 24 x 24, RedButton-Exit / -exit-pressed / -Exit-Disabled,
-- RedButton-Highlight glow in ADD; camelot places it at TOPRIGHT (-2, 1) of its window
-- (UIPanelCloseButtonDefaultAnchorsMixin)
function G.WindowCloseButton(b, window)
	b:SetWidth(24)
	b:SetHeight(24)
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, 1)
	local function place()
		for _, v in ipairs({
			{ "SetNormalTexture", "GetNormalTexture", "RedButton-Exit" },
			{ "SetPushedTexture", "GetPushedTexture", "RedButton-exit-pressed" },
			{ "SetDisabledTexture", "GetDisabledTexture", "RedButton-Exit-Disabled" },
			{ "SetHighlightTexture", "GetHighlightTexture", "RedButton-Highlight" },
		}) do
			b[v[1]](b, G.atlas[string.lower(v[3])][1])
			local t = b[v[2]](b)
			G.PlaceAtlas(t, v[3])
			t:ClearAllPoints()
			t:SetAllPoints(b)
			if v[1] == "SetHighlightTexture" then
				t:SetBlendMode("ADD")
			end
		end
	end
	place()
	return b
end
