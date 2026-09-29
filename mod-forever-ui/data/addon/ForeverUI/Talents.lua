-- ForeverUI: camelot's talent screen (blizzard_playerspells, blizzard_sharedtalentui): three
-- trees, nodes, arrows, gates, unspent points, spec and pet side tabs, glyphs and inspection.
-- PlayerTalentFrame (Blizzard_TalentUI, loaded on demand) stays the panel that N, the micro
-- button and ToggleTalentFrame open and close; its art is hidden and this screen sits inside it.
-- Pending changes use the WotLK talent preview in place of C_Traits; there is no Reset, since
-- WotLK only unlearns at a trainer. The tooltip is WotLK's (SetTalent).

ForeverUI = ForeverUI or {}

local T = {}
ForeverUI.Talents = T

local G = {
	width = 1218, height = 708, top = -116,
	pageW = 1212, pageH = 681, pageBottom = 4,
	backgroundW = 605, backgroundH = 701, backgroundTop = -70, backgroundBottom = 36,
	frameLeft = -2, frameTop = 4, frameCorner = 24,
	-- Horizontal bar 46 higher than camelot's -4 (its line lands on the top of the art). Vertical
	-- separators 60 below the bars' center (camelot) but exactly on the art transitions, at thirds
	-- (x 404 and 808; camelot: +-95 from the bars' centers). Headers 5 px under the bar line
	-- (camelot: -100), their small separator 5 px under the ring (camelot: BOTTOM (60, -20)).
	-- Unspent points 26 higher (camelot: -6), box scaled 0.8, digits 24 instead of 32.
	separatorTop = 42, verticalY = -60, transitionsX = { 404, 808 },
	headerX = 140, headerGap = 400, headerY = -38.5, headerSide = 48, smallSeparatorY = -8.5,
	pointsX = -20, pointsY = 20, pointsScale = 0.8, pointsSize = 24,
	-- Nodes fill the page height (page coordinates): first row 10 px under the small separator
	-- line, last row 40 from the bottom (camelot's bottomPadding); each tree centered in its
	-- column, between the vertical separators; steps keep camelot's ratios (columns 1.5 nodes,
	-- rows 1.4 nodes).
	firstTop = -123, lastBottom = -641, tiers = 11,
	columnsX = { 202, 606, 1010 },
	columnRatio = 1.5, rowRatio = 1.4,
	node = 40, icon = 36, squareShadow = 39, roundShadow = 38,
	rankX = 11, rankY = 4, rankSize = 16,
	line = 6, arrowHeadW = 14, arrowHeadH = 12,
	gateW = 124, gateH = 40, gateIconW = 84, gateIconH = 14, gateX = -12,
	closeX = -2, closeY = 1, redSide = 24,
	portraitX = -5, portraitY = 7, portraitSide = 62,
	titleX1 = 58, titleX2 = -24, titleY = -1, titleH = 20,
	pointsPerTier = 5,
	petPointsPerTier = 3,
	-- Window reduced to one tree (pet, glyphs): the first column
	narrowPage = 404,
	-- Glyphs: center of the socket star in GlyphFrame (Blizzard_GlyphUI.xml: sockets 121 from
	-- (178, -238.5)), placed at the center of the art frame; center of the drawn circle in its
	-- piece. The parchment covers the whole art frame; the gold corners sit inside the inner
	-- frame's line (talents-inner-frame-c60: the line ends 7 px in at the sides, 5 at top/bottom).
	glyphCenterX = 178, glyphCenterY = -238.5,
	circleCenterX = 179.65, circleCenterY = 202.41,
	cornerIndentX = 7, cornerIndentY = 5,
	-- Glow pulse (GlyphFramePulse: 0.1 s rise, 1.5 s fall); the sparkle is enlarged, since the
	-- star has rays
	glowRise = 0.1, glowFall = 1.5, sparkScale = 2.5,
	-- Concentric circles: faint, slowly counter-rotating, lit by filled sockets; max alpha, and
	-- fade speed per second
	circlesAlpha = 0.35, circlesFade = 0.5,
	-- Side tabs (same build as CharacterFrame.lua)
	tabsX = 1, tabsY = -30, tabSide = 55, tabGap = -2, tabIcon = 50,
	tabIconX = -3, tabCrop = 0.03125, checkMarkW = 20, checkMarkH = 15, lockW = 10, lockH = 14,
	applyW = 164, applyH = 22, applyY = 8, cancelSide = 25, cancelX = 14,
	cancelIconW = 21, cancelIconH = 20, glowW = 25, glowH = 49, glowX = 12,
	-- Inspection is more compact: 260-wide columns instead of 404 (nodes fit within +-95 of the
	-- center). The small separator is cut 5 from its column's edge; each tree keeps its own third
	-- of the art, cropped by the same amount on each side; no bottom strip (Apply / Undo), no
	-- gates.
	inspectionColumn = 260, smallSeparatorMargin = 5,
}
-- Scale that fits the tiers: 10 steps + one node = the available height
G.scale = (G.firstTop - G.lastBottom) / (40 * ((G.tiers - 1) * G.rowRatio + 1))
G.rowStep = G.rowRatio * 40 * G.scale
G.columnStep = G.columnRatio * 40 * G.scale
-- Vertical separators: 60 below the bars' center (camelot)
G.verticalTop = G.separatorTop - 28 + G.verticalY
-- Inspection: centers of the three columns, and their transitions
G.inspectionColumns = { G.inspectionColumn / 2, 1.5 * G.inspectionColumn, 2.5 * G.inspectionColumn }
G.inspectionTransitions = { G.inspectionColumn, 2 * G.inspectionColumn }

local METAL = {
	{ key = "topLeft", name = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ key = "topRight", name = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ key = "bottomLeft", name = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ key = "bottomRight", name = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

local SEP = string.char(92)
local FONT = "Fonts" .. SEP .. "FRIZQT__.TTF"
local ROCK = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock"
local PORTRAIT = "Interface" .. SEP .. "ForeverUI" .. SEP .. "talents" .. SEP .. "portrait_"
local L = ForeverUI.L
local TEXT = {
	title = TALENTS,
	unspent = L.TALENTS_UNSPENT_POINTS,                        -- UNSPENT_POINTS
	gate = L.TALENTS_GATE_TOOLTIP,                                -- TALENT_FRAME_GATE_TOOLTIP_FORMAT
	apply = L.TALENTS_APPLY_CHANGES,                           -- TALENT_FRAME_APPLY_BUTTON_TEXT
	cancel = L.TALENTS_UNDO_PENDING_CHANGES,                      -- TALENT_FRAME_DISCARD_CHANGES_BUTTON_TOOLTIP
	activate = ACTIVATE,                                            -- TALENT_SPEC_ACTIVATE
	confirmClose = L.TALENTS_CONFIRM_CLOSE,                  -- TALENT_FRAME_CONFIRM_CLOSE
	active = L.TALENTS_SPEC_ACTIVE,                                 -- TALENT_SPEC_ACTIVE
	locked = LOCKED,                                           -- TALENT_SPEC_LOCKED
	primary = L.TALENTS_SPEC_PRIMARY,                             -- DUAL_SPEC_PRIMARY
	secondary = L.TALENTS_SPEC_SECONDARY,                         -- DUAL_SPEC_SECONDARY
	pet = PET,
	glyphs = GLYPHS,                                              -- GLYPHS
	primaryGlyphs = TALENT_SPEC_PRIMARY_GLYPH,
	secondaryGlyphs = TALENT_SPEC_SECONDARY_GLYPH,
	inspection = L.TALENTS_INSPECT_TITLE,                          -- TALENTS_INSPECT_FORMAT
}
-- Spec icon (TalentFrame_UpdateSpecInfoCache): the main tree's, the hybrid one, or the
-- default one; baked (tools/bake_masks.py)
local TAB_ICONS = "Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP
local HYBRID_ICON = "ability_dualwieldspecialization"
local DEFAULT_ICON = "ability_marksmanship"
local GLYPHS_ICON = "inv_inscription_tradeskill01"
-- Glyphs: the two baked sheets (tools/bake_glyphs.py) and their pieces: sheet, x, y, width,
-- height in pixels; displayed width and height
local GLYPHS_FOLDER = "Interface" .. SEP .. "ForeverUI" .. SEP .. "glyphes" .. SEP
local GLYPHS_RECTS = {
	["parchment"] = { "glyphes-fond", 0, 0, 539, 793, 404.00, 595.00 },
	["circle"] = { "glyphes-fond", 543, 0, 481, 550, 360.84, 412.52 },
	["coin-hg"] = { "glyphes-fond", 0, 801, 89, 94, 66.62, 70.25 },
	["coin-hd"] = { "glyphes-fond", 93, 801, 89, 94, 66.62, 70.25 },
	["coin-bg"] = { "glyphes-fond", 186, 801, 88, 90, 65.75, 67.62 },
	["coin-bd"] = { "glyphes-fond", 278, 801, 87, 90, 65.50, 67.62 },
	["anneau-runique"] = { "glyphes-lueurs", 94, 94, 444, 444, 332.72, 332.72 },
	["anneau-epines"] = { "glyphes-lueurs", 692, 56, 256, 256, 191.95, 191.95 },
	["anneau-double"] = { "glyphes-lueurs", 669, 405, 145, 145, 108.57, 108.57 },
	["anneau-orange"] = { "glyphes-lueurs", 851, 372, 145, 145, 108.87, 108.87 },
	["star"] = { "glyphes-lueurs", 851, 521, 64, 64, 48.00, 48.00 },
	["rayon-0"] = { "glyphes-lueurs", 0, 636, 92, 376, 68.80, 282.00 },
	["rayon-1"] = { "glyphes-lueurs", 100, 636, 372, 268, 279.00, 201.00 },
	["rayon-2"] = { "glyphes-lueurs", 480, 636, 372, 268, 279.00, 201.00 },
}
local GLYPHS_SHEET = 1024

-- Shows a piece of the glyph sheets on texture t; size: also apply its displayed size
local function applyGlyph(t, key, size)
	local r = GLYPHS_RECTS[key]
	t:SetTexture(GLYPHS_FOLDER .. r[1])
	t:SetTexCoord(r[2] / GLYPHS_SHEET, (r[2] + r[4]) / GLYPHS_SHEET,
		r[3] / GLYPHS_SHEET, (r[3] + r[5]) / GLYPHS_SHEET)
	if size then
		t:SetWidth(r[6])
		t:SetHeight(r[7])
	end
end

-- Concentric circles: one ring per socket pair, from center to edge, in the order WotLK opens
-- them (levels 15/15, 30/50, 70/80); each filled glyph of the pair lights half the ring.
-- loop: seconds per turn, the sign gives the direction.
local CIRCLES = {
	{ key = "anneau-double", sockets = { 1, 2 }, loop = 90 },
	{ key = "anneau-epines", sockets = { 3, 4 }, loop = -120 },
	{ key = "anneau-runique", sockets = { 5, 6 }, loop = 180 },
}

-- Rotates a ring texture: its coords turn around the center of its piece (the sheet leaves
-- room around each ring for the corners of the rotated square: tools/bake_glyphs.py)
local function rotateRing(t, key, angle)
	local r = GLYPHS_RECTS[key]
	local cx, cy = (r[2] + r[4] / 2) / GLYPHS_SHEET, (r[3] + r[5] / 2) / GLYPHS_SHEET
	local h = r[4] / 2 / GLYPHS_SHEET
	local c, s = math.cos(angle), math.sin(angle)
	local function p(ox, oy) return cx + ox * c - oy * s, cy + ox * s + oy * c end
	local ulx, uly = p(-h, -h)
	local llx, lly = p(-h, h)
	local urx, ury = p(h, -h)
	local lrx, lry = p(h, h)
	t:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

-- Activation spells (TALENT_ACTIVATION_SPELLS, Constants.lua)
local ACTIVATION_SPELLS = { 63645, 63644 }
local COLOR = {
	gray = { 0.5, 0.5, 0.5 },       -- DISABLED_FONT_COLOR
	green = { 0.1, 1, 0.1 },         -- GREEN_FONT_COLOR
	yellow = { 1, 0.82, 0 },         -- NORMAL_FONT_COLOR
	gate = { 1, 0.64, 0.56 },
}

-- Backgrounds: one per class; death knights get one per tree
local BACKGROUND_DK = { "talents-background-deathknight-blood", "talents-background-deathknight-frost",
	"talents-background-deathknight-unholy" }

local function atlas(t, name, keep)
	return ForeverUI.SetAtlas(t, name, keep)
end

-- Sets an atlas at a given size (the LOGICAL sizes of UiTextureAtlasMember, which the atlas
-- table lacks for talents.blp); l: width; h: height (default l)
local function sizedAtlas(t, name, l, h)
	ForeverUI.SetAtlas(t, name, true)
	t:SetWidth(l)
	t:SetHeight(h or l)
end

local function color(fs, c)
	fs:SetTextColor(c[1], c[2], c[3])
end

-- Silences a WotLK region or frame: texture, alpha, visibility, mouse. The WotLK code shows
-- again what is only hidden.
local function suppress(f)
	if not f then return end
	if f.SetTexture then f:SetTexture(nil) end
	f:SetAlpha(0)
	if f.EnableMouse then f:EnableMouse(false) end
	f:Hide()
end

-- ------------------------------------------------------------ Frame
-- Camelot's red close button on WotLK's PlayerTalentFrameCloseButton
local function skinCloseButton(book)
	local close = PlayerTalentFrameCloseButton
	if not close then return end
	close:SetWidth(G.redSide)
	close:SetHeight(G.redSide)
	close:SetHitRectInsets(0, 0, 0, 0)
	for _, state in ipairs({ { "Normal", "redbutton-exit" }, { "Pushed", "redbutton-exit-pressed" },
		{ "Highlight", "redbutton-highlight" } }) do
		local e = ForeverUI.AtlasEntry(state[2])
		local t = close["Get" .. state[1] .. "Texture"](close)
		if not t and e then
			close["Set" .. state[1] .. "Texture"](close, e[1])
			t = close["Get" .. state[1] .. "Texture"](close)
		end
		if t then
			atlas(t, state[2], true)
			t:ClearAllPoints()
			t:SetAllPoints(close)
		end
	end
	close:ClearAllPoints()
	close:SetPoint("TOPRIGHT", book, "TOPRIGHT", G.closeX, G.closeY)
end

-- Highest frame level of a frame and all its descendants
local function highestLevel(frame)
	local n = frame:GetFrameLevel()
	for _, child in ipairs({ frame:GetChildren() }) do
		local m = highestLevel(child)
		if m > n then n = m end
	end
	return n
end

-- The close button is a sibling of the book, not a child, so its level is reset on every open.
-- Blizzard_GlyphUI puts it just above GlyphFrame on load (GlyphFrame_OnEvent, ADDON_LOADED),
-- which is under the book: it is raised above both.
function T.raiseCloseButton()
	local close, book = PlayerTalentFrameCloseButton, T.book
	if not close or not book then return end
	close:SetFrameStrata(book:GetFrameStrata())
	local top = highestLevel(book)
	if GlyphFrame then top = math.max(top, highestLevel(GlyphFrame)) end
	close:SetFrameLevel(top + 1)
end

-- Window frame: rock background, metal border, class portrait, title banner, close button
local function buildFrame(book)
	local rock = book:CreateTexture(nil, "BACKGROUND")
	rock:SetTexture(ROCK, true)
	if rock.SetHorizTile then rock:SetHorizTile(true) rock:SetVertTile(true) end
	rock:SetPoint("TOPLEFT", book, "TOPLEFT", 2, -21)
	rock:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -2, 2)

	local metal = CreateFrame("Frame", nil, book)
	metal:SetAllPoints(book)
	metal:SetFrameLevel(book:GetFrameLevel() + 20)
	local p = {}
	for _, corner in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		atlas(t, corner.name)
		t:SetPoint(corner.point, metal, corner.point, corner.x, corner.y)
		p[corner.key] = t
	end
	local function edge(name, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		atlas(t, name)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	edge("_ui-frame-metal-edgetop", "TOPLEFT", p.topLeft, "TOPRIGHT", "TOPRIGHT", p.topRight, "TOPLEFT")
	edge("_ui-frame-metal-edgebottom", "BOTTOMLEFT", p.bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bottomRight, "BOTTOMLEFT")
	edge("!ui-frame-metal-edgeleft", "TOPLEFT", p.topLeft, "BOTTOMLEFT", "BOTTOMLEFT", p.bottomLeft, "TOPLEFT")
	edge("!ui-frame-metal-edgeright", "TOPRIGHT", p.topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bottomRight, "TOPRIGHT")

	-- Portrait: the class icon, baked round (tools/bake_masks.py)
	local portraitFrame = CreateFrame("Frame", nil, book)
	portraitFrame:SetAllPoints(book)
	portraitFrame:SetFrameLevel(book:GetFrameLevel() + 19)
	local portrait = portraitFrame:CreateTexture(nil, "OVERLAY")
	portrait:SetWidth(G.portraitSide)
	portrait:SetHeight(G.portraitSide)
	portrait:SetPoint("TOPLEFT", book, "TOPLEFT", G.portraitX, G.portraitY)
	local _, className = UnitClass("player")
	portrait:SetTexture(PORTRAIT .. string.lower(className or "warrior"))
	book.portrait = portrait

	local banner = CreateFrame("Frame", nil, book)
	banner:SetFrameLevel(book:GetFrameLevel() + 21)
	banner:SetHeight(G.titleH)
	banner:SetPoint("TOPLEFT", book, "TOPLEFT", G.titleX1, G.titleY)
	banner:SetPoint("TOPRIGHT", book, "TOPRIGHT", G.titleX2, G.titleY)
	local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", banner, "TOP", 0, -5)
	title:SetText(TEXT.title)
	book.title = title
	book.banner = banner

	skinCloseButton(book)
end

-- Camelot's UIPanelButtonTemplate: three pieces of UI-Panel-Button-* (as in QuestLog.lua)
local PANEL = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Panel-Button-"
function T.panelButton(parent, name, text, width)
	local b = CreateFrame("Button", name, parent)
	b:SetWidth(width)
	b:SetHeight(G.applyH)
	local function piece(u1, u2)
		local t = b:CreateTexture(nil, "BACKGROUND")
		t:SetTexCoord(u1, u2, 0, 0.6875)
		return t
	end
	local g = piece(0, 0.09375)
	g:SetWidth(12)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	g:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	local d = piece(0.53125, 0.625)
	d:SetWidth(12)
	d:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	local m = piece(0.09375, 0.53125)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	b.pieces = { g, m, d }
	local function state(suffix)
		for _, t in ipairs(b.pieces) do t:SetTexture(PANEL .. suffix) end
	end
	state("Up")
	local fs = b:CreateFontString(nil, "ARTWORK")
	fs:SetFontObject(GameFontNormal)
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetFontString(fs)
	b:SetNormalFontObject(GameFontNormal)
	b:SetHighlightFontObject(GameFontHighlight)
	b:SetDisabledFontObject(GameFontDisable)
	b:SetText(text)
	b:SetHighlightTexture(PANEL .. "Highlight")
	local s = b:GetHighlightTexture()
	if s then
		s:SetTexCoord(0, 0.625, 0, 0.6875)
		s:SetBlendMode("ADD")
	end
	b.active = true
	b:SetScript("OnMouseDown", function(self) if self.active then state("Down") end end)
	b:SetScript("OnMouseUp", function(self) if self.active then state("Up") end end)
	function b:Activate(yes)
		self.active = yes and true or false
		if yes then
			self:Enable()
			state("Up")
		else
			self:Disable()
			state("Disabled")
		end
	end
	return b
end

-- Talents-Background-c60 tiled across the page width; when shorter (inspection, no bottom
-- strip) it is cropped at the bottom, not squashed
local function placeStone(width, height)
	local background = T.background
	local e = ForeverUI.AtlasEntry("talents-background-c60")
	local down = e and (e[4] + (e[5] - e[4]) * (height or G.backgroundH) / G.backgroundH)
	local x, n = 0, 0
	while x < width do
		n = n + 1
		local t = background.stones[n] or background:CreateTexture(nil, "BACKGROUND")
		background.stones[n] = t
		local l = math.min(G.backgroundW, width - x)
		if e then
			t:SetTexture(e[1])
			t:SetTexCoord(e[2], e[2] + (e[3] - e[2]) * l / G.backgroundW, e[4], down)
		end
		t:SetWidth(l)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", background, "TOPLEFT", x, 0)
		t:SetPoint("BOTTOMLEFT", background, "BOTTOMLEFT", x, 0)
		t:Show()
		x = x + l
	end
	for i = n + 1, #background.stones do background.stones[i]:Hide() end
end

-- ------------------------------------------------------------ Page
local function buildPage(book)
	local page = CreateFrame("Frame", "ForeverUITalentsPage", book)
	page:SetWidth(G.pageW)
	page:SetHeight(G.pageH)
	page:SetPoint("BOTTOM", book, "BOTTOM", 0, G.pageBottom)
	T.page = page

	-- Talents-Background-c60 repeats horizontally (horizTile): 3.3.5 cannot tile an atlas
	-- region, so copies are placed side by side
	local background = CreateFrame("Frame", nil, page)
	background:SetHeight(G.backgroundH)
	background:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
	background:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	background.stones = {}
	T.background = background

	-- Class background ONE LEVEL ABOVE the stone: two sibling frames at the same level have no
	-- guaranteed draw order, and the opaque stone could cover the art
	background:SetFrameLevel(page:GetFrameLevel() + 1)
	local className = CreateFrame("Frame", nil, page)
	className:SetFrameLevel(background:GetFrameLevel() + 1)
	className:SetPoint("TOPLEFT", background, "TOPLEFT", 0, G.backgroundTop)
	className:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 0, G.backgroundBottom)
	className.textures = {}
	T.className = className

	-- Inner frame, nine-slice (its corners are ornate)
	local frame = CreateFrame("Frame", nil, page)
	frame:SetPoint("TOPLEFT", className, "TOPLEFT", G.frameLeft, G.frameTop)
	frame:SetPoint("BOTTOMRIGHT", className, "BOTTOMRIGHT", -G.frameLeft, -G.frameTop)
	frame:SetFrameLevel(page:GetFrameLevel() + 2)
	ForeverUI.CreateNineSlice(frame, "talents-inner-frame-c60", G.frameCorner, { 0, 0, 0, 0 }, "OVERLAY")
	T.frame = frame

	-- Separators
	local left = frame:CreateTexture(nil, "OVERLAY")
	atlas(left, "talents-divider-left-c60")
	T.barLeft = left
	left:SetPoint("RIGHT", frame, "CENTER", 0, 0)
	left:SetPoint("TOP", frame, "TOP", 0, G.separatorTop)
	local right = frame:CreateTexture(nil, "OVERLAY")
	atlas(right, "talents-divider-right-c60")
	T.barRight = right
	right:SetPoint("LEFT", frame, "CENTER", 0, 0)
	right:SetPoint("TOP", frame, "TOP", 0, G.separatorTop)
	-- Vertical separators: 60 below the bars' center (camelot), on the art transitions (the frame
	-- starts at -2 from the page)
	local verticals = {}
	for i, x in ipairs(G.transitionsX) do
		local v = frame:CreateTexture(nil, "OVERLAY")
		atlas(v, "talents-divider-vertical-c60")
		v:SetPoint("TOP", frame, "TOPLEFT", x - G.frameLeft, G.verticalTop)
		verticals[i] = v
	end
	T.verticals = verticals

	-- Unspent points
	local points = CreateFrame("Frame", nil, frame)
	points:SetWidth(1)
	points:SetHeight(1)
	points:SetPoint("TOPRIGHT", frame, "TOPRIGHT", G.pointsX, G.pointsY)
	local box = points:CreateTexture(nil, "ARTWORK")
	atlas(box, "talents-square-box-c60")
	local k = G.pointsScale
	box:SetWidth(box:GetWidth() * k)
	box:SetHeight(box:GetHeight() * k)
	box:SetPoint("RIGHT", points, "RIGHT", 0, 0)
	local caption = points:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Med1")
	caption:SetJustifyH("RIGHT")
	caption:SetPoint("RIGHT", box, "LEFT", 60 * k, 0)
	caption:SetText(TEXT.unspent)
	-- The search aligns on this label: its right edge, from the frame's right edge
	points.caption = caption
	points.captionRight = G.pointsX - box:GetWidth() + 60 * k
	local count = points:CreateFontString(nil, "ARTWORK")
	count:SetFont(FONT, G.pointsSize)
	count:SetShadowOffset(2, -2)
	count:SetShadowColor(0, 0, 0, 1)
	count:SetPoint("CENTER", box, "RIGHT", (-4 - 24) * k, 0)
	points.count = count
	T.points = points

	-- The three headers
	T.headers = {}
	for i = 1, 3 do
		local h = CreateFrame("Frame", "ForeverUITalentsHeader" .. i, frame)
		h:SetWidth(G.headerSide)
		h:SetHeight(G.headerSide)
		h:SetPoint("CENTER", frame, "TOPLEFT", G.headerX + (i - 1) * G.headerGap, G.headerY)
		h:SetFrameLevel(frame:GetFrameLevel() + 5)
		local icon = h:CreateTexture(nil, "BORDER")
		icon:SetWidth(36)
		icon:SetHeight(36)
		icon:SetPoint("CENTER", h, "CENTER", -3, 3)
		local ring = h:CreateTexture(nil, "OVERLAY")
		atlas(ring, "talents-main-ring-c60")
		ring:SetPoint("CENTER", icon, "CENTER", 0, 0)
		local name = h:CreateFontString(nil, "OVERLAY")
		name:SetFont(FONT, 16, "OUTLINE")
		name:SetTextColor(1, 1, 1)
		name:SetPoint("LEFT", h, "LEFT", 54, 2)
		local textBox = h:CreateTexture(nil, "OVERLAY")
		atlas(textBox, "talents-main-ring-box-c60")
		textBox:SetPoint("CENTER", h, "CENTER", 14, -12)
		local spent = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		spent:SetPoint("CENTER", textBox, "CENTER", 0, 0)
		local line = h:CreateTexture(nil, "OVERLAY")
		atlas(line, "talents-small-divider-c60")
		line:SetPoint("BOTTOM", h, "BOTTOM", 60, G.smallSeparatorY)
		h.icon, h.name, h.spent, h.line = icon, name, spent, line
		T.headers[i] = h
	end

	-- Apply and Undo, at the bottom of the background
	local apply = T.panelButton(page, "ForeverUITalentsApplyButton", TEXT.apply, G.applyW)
	apply:SetPoint("BOTTOM", background, "BOTTOM", 0, G.applyY)
	apply:SetFrameLevel(frame:GetFrameLevel() + 6)
	apply:SetScript("OnClick", function() T.apply() end)
	local glow = CreateFrame("Frame", nil, apply)
	glow:SetHeight(1)
	glow:SetPoint("LEFT", apply, "LEFT", -G.glowX, 0)
	glow:SetPoint("RIGHT", apply, "RIGHT", G.glowX, 0)
	local lg = glow:CreateTexture(nil, "ARTWORK")
	sizedAtlas(lg, "newplayertutorial-yellowglow-redbutton-left", G.glowW, G.glowH)
	lg:SetBlendMode("ADD")
	lg:SetPoint("LEFT", glow, "LEFT", 0, 0)
	local ld = glow:CreateTexture(nil, "ARTWORK")
	sizedAtlas(ld, "newplayertutorial-yellowglow-redbutton-right", G.glowW, G.glowH)
	ld:SetBlendMode("ADD")
	ld:SetPoint("RIGHT", glow, "RIGHT", 0, 0)
	local lm = glow:CreateTexture(nil, "ARTWORK")
	atlas(lm, "newplayertutorial-yellowglow-redbutton-middle", true)
	lm:SetBlendMode("ADD")
	lm:SetPoint("TOPLEFT", lg, "TOPRIGHT", 0, 0)
	lm:SetPoint("BOTTOMRIGHT", ld, "BOTTOMLEFT", 0, 0)
	glow:Hide()
	apply.glow = glow
	T.applyButton = apply

	local cancel = CreateFrame("Button", "ForeverUITalentsUndoButton", page)
	cancel:SetWidth(G.cancelSide)
	cancel:SetHeight(G.cancelSide)
	cancel:SetPoint("CENTER", apply, "RIGHT", G.cancelX + G.cancelSide / 2, 0)
	cancel:SetFrameLevel(frame:GetFrameLevel() + 6)
	local icon = cancel:CreateTexture(nil, "ARTWORK")
	sizedAtlas(icon, "talents-button-undo", G.cancelIconW, G.cancelIconH)
	icon:SetPoint("CENTER", cancel, "CENTER", 0, 0)
	-- useIconAsHighlight: the same icon, in ADD, on hover
	local hover = cancel:CreateTexture(nil, "HIGHLIGHT")
	sizedAtlas(hover, "talents-button-undo", G.cancelIconW, G.cancelIconH)
	hover:SetPoint("CENTER", cancel, "CENTER", 0, 0)
	hover:SetBlendMode("ADD")
	cancel:SetScript("OnClick", function() T.cancel() end)
	cancel:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(TEXT.cancel, 1, 1, 1)
		GameTooltip:Show()
	end)
	cancel:SetScript("OnLeave", function() GameTooltip:Hide() end)
	cancel:Hide()
	T.cancelButton = cancel

	-- Activate, in place of Apply on an inactive spec
	local activate = T.panelButton(page, "ForeverUITalentsActivateButton", TEXT.activate, G.applyW)
	activate:SetPoint("BOTTOM", background, "BOTTOM", 0, G.applyY)
	activate:SetFrameLevel(frame:GetFrameLevel() + 6)
	activate:SetScript("OnClick", function() T.activate() end)
	activate:Hide()
	T.activateButton = activate

	-- The tree: nodes, arrows and gates, scaled
	local tree = CreateFrame("Frame", "ForeverUITalentsTree", page)
	tree:SetScale(G.scale)
	tree:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	tree:SetWidth(G.pageW / G.scale)
	tree:SetHeight(G.pageH / G.scale)
	tree:SetFrameLevel(frame:GetFrameLevel() + 3)
	tree.nodes, tree.lines, tree.arrowHeads, tree.gates = {}, {}, {}, {}
	T.tree = tree
end

-- ------------------------------------------------------------ Nodes
-- Column centers and transitions: the narrower inspection ones, or the page ones
local function columnsX()
	if T.inspection then return G.inspectionColumns, G.inspectionTransitions end
	return G.columnsX, G.transitionsX
end

-- Center of a node in tree coordinates (divided by the scale)
local function center(tab, tier, column)
	local x = columnsX()[tab] + (column - 2.5) * G.columnStep
	-- The pet tree (reduced window) is tab 1, so it lands in the only column shown
	local y = G.firstTop - 20 * G.scale - (tier - 1) * G.rowStep
	return x / G.scale, y / G.scale
end
T.center = center

local function createNode(n)
	local tree = T.tree
	local b = CreateFrame("Button", "ForeverUITalentsNode" .. n, tree)
	b:SetWidth(G.node)
	b:SetHeight(G.node)
	b:SetFrameLevel(tree:GetFrameLevel() + 2)
	local shadow = b:CreateTexture(nil, "BACKGROUND")
	shadow:SetPoint("CENTER", b, "CENTER", 0, 0)
	local icon = b:CreateTexture(nil, "BORDER")
	icon:SetWidth(G.icon)
	icon:SetHeight(G.icon)
	icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	local border = b:CreateTexture(nil, "ARTWORK")
	border:SetPoint("CENTER", b, "CENTER", 0, 0)
	-- Rank: SystemFont16_Shadow_ThickOutline and its four shadows
	local rank = b:CreateFontString(nil, "OVERLAY")
	rank:SetFont(FONT, G.rankSize, "THICKOUTLINE")
	rank:SetPoint("BOTTOM", b, "BOTTOM", G.rankX, G.rankY)
	local shadows = {}
	for i, d in ipairs({ { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }) do
		local o = b:CreateFontString(nil, "ARTWORK")
		o:SetFont(FONT, G.rankSize, "THICKOUTLINE")
		o:SetTextColor(0, 0, 0)
		o:SetPoint("CENTER", rank, "CENTER", d[1], d[2])
		shadows[i] = o
	end
	b.shadow, b.icon, b.border, b.rank, b.rankShadows = shadow, icon, border, rank, shadows
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnEnter", function(self)
		if not self.talent then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		-- Pending points count (WotLK preview)
		GameTooltip:SetTalent(self.talent.tab, self.talent.index, T.inspection ~= nil, T.pet, T.group, T.inspection == nil)
		GameTooltip:Show()
	end)
	b:SetScript("OnClick", function(self, button) T.click(self, button) end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- Drag a learned active spell to a bar (camelot's TalentButtonSpendMixin:OnDragStart; WotLK
	-- has none)
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", function(self) T.pickupSpell(self) end)
	return b
end

local function writeRank(b, text, c)
	b.rank:SetText(text)
	color(b.rank, c)
	for _, o in ipairs(b.rankShadows) do o:SetText(text) end
end

-- Talent state (camelot override, blizzard_sharedtalentoverrides): "maxed" yellow,
-- "selectable" green (can be bought, or partly ranked), "locked" behind a gate, "disabled"
-- gray otherwise. isOpen: its tier is reached; points: unspent points.
local function stateOf(t, isOpen, points)
	if t.rank > 0 and t.rank >= t.max then return "maxed" end
	if not isOpen then return "locked" end
	if t.rank > 0 then return "selectable" end
	if t.prereq and points > 0 then return "selectable" end
	return "disabled"
end
T.stateOf = stateOf

local BORDER = { maxed = "yellow", selectable = "green", locked = "locked", disabled = "gray" }
local RANK_TEXT = { maxed = COLOR.yellow, selectable = COLOR.green, locked = COLOR.gray, disabled = COLOR.gray }

local function fillNode(b, t, state)
	b.talent = t
	local shape = t.square and "square" or "circle"
	sizedAtlas(b.shadow, "talents-node-" .. shape .. "-shadow", t.square and G.squareShadow or G.roundShadow)
	sizedAtlas(b.border, "talents-node-" .. shape .. "-" .. BORDER[state], G.node)
	if t.square then
		b.icon:SetTexture(t.icon)
		b.icon:SetTexCoord(0, 1, 0, 1)
	else
		SetPortraitToTexture(b.icon, t.icon)
		b.icon:SetTexCoord(0, 1, 0, 1)
	end
	-- DisabledOverlay: black at 0.7 behind a gate, 0.25 when gray; 3.3.5 has no mask for the
	-- round shape, so the icon is darkened instead
	local v = (state == "locked") and 0.3 or ((state == "disabled") and 0.75 or 1)
	b.icon:SetVertexColor(v, v, v)
	-- Current rank only; nothing at zero unless it can be bought
	if t.rank == 0 and state ~= "selectable" then
		writeRank(b, "", RANK_TEXT[state])
	else
		writeRank(b, tostring(t.rank), RANK_TEXT[state])
	end
	local x, y = center(t.tab, t.tier, t.column)
	b:ClearAllPoints()
	b:SetPoint("CENTER", T.tree, "TOPLEFT", x, y)
	b:Show()
end

-- ------------------------------------------------------------ Arrows
-- SetClampedTextureRotation at 90 / 270, as the eight-argument SetTexCoord
local function rotate(t, name, degrees)
	local e = ForeverUI.AtlasEntry(name)
	if not e then return end
	t:SetTexture(e[1])
	local u1, u2, v1, v2 = e[2], e[3], e[4], e[5]
	if degrees == 90 then
		t:SetTexCoord(u1, v2, u2, v2, u1, v1, u2, v1)
	elseif degrees == 270 then
		t:SetTexCoord(u2, v1, u1, v1, u2, v2, u1, v2)
	else
		t:SetTexCoord(u1, u2, v1, v2)
	end
end

-- Reuses or creates texture n of a pool; overlay: its draw layer
local function acquire(list, n, overlay)
	local t = list[n]
	if not t then
		t = T.tree:CreateTexture(nil, overlay)
		list[n] = t
	end
	t:Show()
	return t
end

-- Straight line, horizontal or vertical, from (x1, y1) to (x2, y2); n: pool index
local function line(n, x1, y1, x2, y2, state)
	local t = acquire(T.tree.lines, n, "BACKGROUND")
	local name = "talents-arrow-line-" .. state
	t:ClearAllPoints()
	if x1 == x2 then
		-- The strip is horizontal in the image: rotated for a vertical line
		rotate(t, name, 90)
		t:SetWidth(G.line)
		t:SetHeight(math.abs(y2 - y1))
		t:SetPoint("TOP", T.tree, "TOPLEFT", x1, math.max(y1, y2))
	else
		rotate(t, name, 0)
		t:SetHeight(G.line)
		t:SetWidth(math.abs(x2 - x1))
		t:SetPoint("LEFT", T.tree, "TOPLEFT", math.min(x1, x2), y1)
	end
end

-- Arrow head against the target node; it points down in the image
local function arrowHead(n, x, y, direction, state)
	local t = acquire(T.tree.arrowHeads, n, "BORDER")
	local name = "talents-arrow-head-" .. state
	t:ClearAllPoints()
	if direction == "down" then
		rotate(t, name, 0)
		t:SetWidth(G.arrowHeadW) t:SetHeight(G.arrowHeadH)
	elseif direction == "right" then
		rotate(t, name, 270)
		t:SetWidth(G.arrowHeadH) t:SetHeight(G.arrowHeadW)
	else
		rotate(t, name, 90)
		t:SetWidth(G.arrowHeadH) t:SetHeight(G.arrowHeadW)
	end
	t:SetPoint("CENTER", T.tree, "TOPLEFT", x, y)
end

-- Prerequisite arrow: straight within a column or tier, otherwise down then sideways (as in
-- WotLK: 3.3.5 cannot rotate a texture freely). Returns the next line and head indexes.
local function arrow(nLine, nArrowHead, source, target, state)
	local x1, y1 = center(source.tab, source.tier, source.column)
	local x2, y2 = center(target.tab, target.tier, target.column)
	local r = G.node / 2
	if x1 == x2 then
		local tip = y2 + r + G.arrowHeadH / 2
		line(nLine, x1, y1, x1, tip, state)
		arrowHead(nArrowHead, x2, tip, "down", state)
		return nLine + 1, nArrowHead + 1
	end
	local direction = (x2 > x1) and "right" or "left"
	local tip = (x2 > x1) and (x2 - r - G.arrowHeadH / 2) or (x2 + r + G.arrowHeadH / 2)
	if y1 == y2 then
		line(nLine, x1, y1, tip, y1, state)
		arrowHead(nArrowHead, tip, y2, direction, state)
		return nLine + 1, nArrowHead + 1
	end
	line(nLine, x1, y1, x1, y2, state)
	line(nLine + 1, x1, y2, tip, y2, state)
	arrowHead(nArrowHead, tip, y2, direction, state)
	return nLine + 2, nArrowHead + 1
end

-- ------------------------------------------------------------ Gates
local function createGate(n)
	local p = CreateFrame("Frame", "ForeverUITalentsGate" .. n, T.tree)
	p:SetWidth(G.gateW)
	p:SetHeight(G.gateH)
	p:SetFrameLevel(T.tree:GetFrameLevel() + 3)
	local icon = p:CreateTexture(nil, "ARTWORK")
	sizedAtlas(icon, "talents-gate", G.gateIconW, G.gateIconH)
	icon:SetPoint("RIGHT", p, "RIGHT", 25, 2)
	local text = p:CreateFontString(nil, "OVERLAY")
	text:SetFont(FONT, 24)
	color(text, COLOR.gate)
	text:SetPoint("RIGHT", icon, "LEFT", -10, -1)
	p.text = text
	p:EnableMouse(true)
	p:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT", 4, -4)
		GameTooltip:SetText(string.format(TEXT.gate, self.rest or 0), 1, 0.125, 0.125)
		GameTooltip:Show()
	end)
	p:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return p
end

-- ------------------------------------------------------------ Filling
-- View: the spec shown (group nil = the active one) or the pet
T.view = { group = nil, pet = false }

-- Inspection: camelot opens its talent window on the inspected player
-- (PlayerSpellsFrameMixin:SetInspecting): TALENTS_INSPECT_FORMAT title, their class, no spec
-- tabs, Apply / Undo hidden, nothing to buy. T.inspection holds the unit (nil otherwise); the
-- 3.3.5 talent functions read it through their inspect argument, active spec only. The window
-- is more compact: no gates, narrower columns, no bottom strip, no search, no unspent points.
T.inspection = nil

-- Reads the talents of the viewed spec or pet, by tab; returns tabs and the points left
function T.read()
	-- Glyphs: the state is WotLK's (GlyphFrame shown, and the spec PlayerSpecTab_OnClick chose)
	local inspecting = T.inspection ~= nil
	T.glyphs = (not inspecting and GlyphFrame and GlyphFrame:IsShown()) and true or false
	if inspecting then T.view.pet = false end
	if T.glyphs then
		T.view.pet = false
		T.view.group = PlayerTalentFrame.talentGroup or T.view.group
	end
	-- Pet gone (or without talents): the view goes back to the player
	if T.view.pet and (GetNumTalentTabs(false, true) or 0) == 0 then T.view.pet = false end
	local pet = T.view.pet and true or false
	local active = GetActiveTalentGroup and GetActiveTalentGroup(inspecting, pet) or 1
	local group = (not pet and not inspecting and T.view.group) or active
	T.group, T.pet, T.active = group, pet, (group == active)
	local tabs = {}
	for o = 1, math.min(GetNumTalentTabs(inspecting, pet) or 0, 3) do
		local name, icon, spent, background, pending = GetTalentTabInfo(o, inspecting, pet, group)
		local tab = { name = name, icon = icon, spent = (spent or 0) + (pending or 0), background = background, talents = {} }
		local squares = ForeverUI.TalentsSquares and ForeverUI.TalentsSquares[background or ""] or {}
		for i = 1, (GetNumTalents(o, inspecting, pet) or 0) do
			local n, ic, tier, column, rank, max, _, prereq, previewRank, previewPrereq =
				GetTalentInfo(o, i, inspecting, pet, group)
			if n then
				-- The rank SHOWN is the preview rank: learned + pending
				table.insert(tab.talents, { tab = o, index = i, name = n, icon = ic, tier = tier,
					column = column, rank = previewRank or rank or 0, learned = rank or 0, max = max or 1,
					prereq = (previewPrereq ~= nil and previewPrereq or prereq) and true or false,
					square = squares[tier .. ":" .. column] and true or false })
			end
		end
		tabs[o] = tab
	end
	-- Points left: minus the pending ones
	local pending = (not inspecting and GetGroupPreviewTalentPointsSpent) and GetGroupPreviewTalentPointsSpent(pet, group) or 0
	T.pending = pending
	return tabs, (GetUnspentTalentPoints(inspecting, pet, group) or 0) - pending
end

-- ------------------------------------------------------------ Drag
-- Book slot of talent t's spell (player or pet book), at its highest known rank. Talent spells
-- come from the DBC (TalentsData.lua, ForeverUI.TalentsSpells); the name is the fallback.
-- Only a learned (not just pending) square talent of the active spec can be dragged.
function T.talentSpell(t)
	local book = T.pet and BOOKTYPE_PET or BOOKTYPE_SPELL
	local total = 0
	if T.pet then
		total = (HasPetSpells and HasPetSpells()) or 0
	else
		for i = 1, (GetNumSpellTabs() or 0) do
			local _, _, start, count = GetSpellTabInfo(i)
			total = math.max(total, (start or 0) + (count or 0))
		end
	end
	local o = T.tabs and T.tabs[t.tab]
	local spells = o and ForeverUI.TalentsSpells and ForeverUI.TalentsSpells[o.background or ""]
	spells = spells and spells[t.tier .. ":" .. t.column]
	local wantedIds = {}
	for _, id in ipairs(spells or {}) do wantedIds[id] = true end
	local match, byName
	for slot = 1, total do
		local link = GetSpellLink(slot, book)
		local id = link and tonumber(string.match(link, "spell:(%d+)"))
		if id and wantedIds[id] then match = slot end
		if GetSpellName(slot, book) == t.name then byName = slot end
	end
	return match or byName, book
end

function T.pickupSpell(b)
	local t = b.talent
	if T.inspection or not t or not t.square or (t.learned or 0) == 0 or not T.active then return end
	local slot, book = T.talentSpell(t)
	if slot then PickupSpell(slot, book) end
end

-- ------------------------------------------------------------ Pending changes
-- Left click adds a point, right click removes a pending point, modified click links;
-- the client refuses what is not allowed
function T.click(b, button)
	local t = b.talent
	if not t then return end
	if IsModifiedClick("CHATLINK") then
		local link = GetTalentLink(t.tab, t.index, T.inspection ~= nil, T.pet, T.group)
		if link then ChatEdit_InsertLink(link) end
		return
	end
	-- An inactive spec, or an inspected one, is read-only (IsLocked)
	if not T.active or T.inspection then return end
	if button == "RightButton" then
		if t.rank > t.learned then
			AddPreviewTalentPoints(t.tab, t.index, -1, T.pet, T.group)
		end
	elseif t.state == "selectable" and t.rank < t.max then
		AddPreviewTalentPoints(t.tab, t.index, 1, T.pet, T.group)
	end
	T.update()
	if GameTooltip.IsOwned and GameTooltip:IsOwned(b) then b:GetScript("OnEnter")(b) end
end

function T.apply()
	if (T.pending or 0) <= 0 then return end
	LearnPreviewTalents(T.pet)
	T.update()
end

function T.cancel()
	ResetGroupPreviewTalentPoints(T.pet, T.group)
	T.update()
end

-- ActivateSpec: SetActiveTalentGroup casts a spell (63645 / 63644)
function T.activate()
	if T.pet or T.active then return end
	SetActiveTalentGroup(T.group)
	T.update()
end

-- ------------------------------------------------------------ Tabs
-- Tab icon of spec group: its main tree's if it clearly leads, else the hybrid icon;
-- the default one with no points
local function specializationIcon(group)
	local points = {}
	for o = 1, math.min(GetNumTalentTabs(false, false) or 0, 3) do
		local _, icon, spent = GetTalentTabInfo(o, false, false, group)
		table.insert(points, { n = spent or 0, icon = icon })
	end
	table.sort(points, function(a, b) return a.n > b.n end)
	local top, middle, down = points[1], points[2], points[3]
	if not top or top.n == 0 then return TAB_ICONS .. DEFAULT_ICON end
	local m, b = middle and middle.n or 0, down and down.n or 0
	if 3 * (m - b) < 2 * (top.n - b) then
		local name = string.match(top.icon or "", "([^" .. SEP .. "/]+)$") or DEFAULT_ICON
		return TAB_ICONS .. string.lower(name)
	end
	return TAB_ICONS .. HYBRID_ICON
end
T.specializationIcon = specializationIcon

-- Side tab button n; key: spec1, spec2, glyphs or pet
local function createTab(key, n)
	local bar = T.tabBar
	local b = CreateFrame("Button", "ForeverUITalentsTab" .. n, bar)
	b:SetFrameLevel(bar:GetFrameLevel() + 1)
	b:SetWidth(G.tabSide)
	b:SetHeight(G.tabSide)
	local tabBackground = b:CreateTexture(nil, "BACKGROUND")
	atlas(tabBackground, "common-sidetab", true)
	tabBackground:SetAllPoints(b)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(G.tabIcon)
	icon:SetHeight(G.tabIcon)
	icon:SetPoint("CENTER", b, "CENTER", G.tabIconX, 0)
	icon:SetTexCoord(G.tabCrop, 1 - G.tabCrop, G.tabCrop, 1 - G.tabCrop)
	local selected = b:CreateTexture(nil, "OVERLAY")
	atlas(selected, "common-sidetab-selected", true)
	selected:SetAllPoints(b)
	selected:Hide()
	local hover = b:CreateTexture(nil, "HIGHLIGHT")
	atlas(hover, "common-sidetab-hover", true)
	hover:SetAllPoints(b)
	-- Check mark on the active spec, lock on the locked one
	local checkMark = b:CreateTexture(nil, "OVERLAY")
	sizedAtlas(checkMark, "talents-checkmark-c60", G.checkMarkW, G.checkMarkH)
	checkMark:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
	checkMark:Hide()
	local lock = b:CreateTexture(nil, "OVERLAY")
	sizedAtlas(lock, "talents-lock-c60", G.lockW, G.lockH)
	lock:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -4, 4)
	lock:Hide()
	b.icon, b.selected, b.checkMark, b.lock, b.key = icon, selected, checkMark, lock, key
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.title or "")
		if self.locked then
			GameTooltip:AddLine(TEXT.locked, 1, 0.125, 0.125)
		elseif self.isActive then
			GameTooltip:AddLine(TEXT.active, COLOR.green[1], COLOR.green[2], COLOR.green[3])
		end
		if self.distribution then GameTooltip:AddLine(self.distribution, 1, 1, 1) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		if self.locked then return end
		PlaySound("igCharacterInfoTab")
		if self.key == "glyphs" then
			T.openGlyphs(not T.view.pet and T.view.group or nil)
		elseif self.key == "pet" then
			T.closeGlyphs()
			T.view.pet = true
		else
			T.closeGlyphs()
			T.view.pet = false
			T.view.group = self.group
		end
		T.update()
	end)
	return b
end

-- Tab stack: first spec, second spec, glyphs (from the inscription level), pet (if it has
-- talents)
function T.layoutTabs()
	local bar = T.tabBar
	if not bar then return end
	bar.tabs = bar.tabs or {}
	-- Inspection has no tabs (camelot's IsTabAvailable)
	if T.inspection then
		for _, b in ipairs(bar.tabs) do b:Hide() end
		return
	end
	local active = GetActiveTalentGroup and GetActiveTalentGroup(false, false) or 1
	local numGroups = GetNumTalentGroups and GetNumTalentGroups(false, false) or 1
	local defs = {
		{ key = "spec1", group = 1, title = TEXT.primary },
		{ key = "spec2", group = 2, title = TEXT.secondary },
	}
	-- PlayerTalentFrame_UpdateTabs: the tab exists from SHOW_INSCRIPTION_LEVEL; its title is
	-- GlyphFrameTitleText's
	if (UnitLevel("player") or 0) >= (SHOW_INSCRIPTION_LEVEL or 15) then
		local found = (not T.view.pet and T.view.group) or active
		local title = TEXT.glyphs
		if numGroups > 1 then
			title = found == 2 and TEXT.secondaryGlyphs or TEXT.primaryGlyphs
		end
		table.insert(defs, { key = "glyphs", title = title })
	end
	if (GetNumTalentTabs(false, true) or 0) > 0 then
		table.insert(defs, { key = "pet", title = TEXT.pet })
	end
	local previous
	for i, d in ipairs(defs) do
		local b = bar.tabs[i] or createTab(d.key, i)
		bar.tabs[i] = b
		b.key, b.group, b.title = d.key, d.group, d.title
		b.locked = (d.group == 2 and numGroups < 2) or nil
		b.isActive = (d.group ~= nil and d.group == active) or nil
		if d.key == "pet" then
			SetPortraitTexture(b.icon, "pet")
			b.distribution = nil
		elseif d.key == "glyphs" then
			b.icon:SetTexture(TAB_ICONS .. GLYPHS_ICON)
			b.distribution = nil
		else
			b.icon:SetTexture(specializationIcon(d.group))
			local r = {}
			for o = 1, math.min(GetNumTalentTabs(false, false) or 0, 3) do
				local _, _, spent = GetTalentTabInfo(o, false, false, d.group)
				table.insert(r, tostring(spent or 0))
			end
			b.distribution = table.concat(r, " / ")
		end
		b.icon:SetDesaturated(b.locked and true or false)
		if b.isActive then b.checkMark:Show() else b.checkMark:Hide() end
		if b.locked then b.lock:Show() else b.lock:Hide() end
		local selected
		if d.key == "glyphs" then
			selected = T.glyphs
		elseif T.glyphs then
			selected = false
		elseif d.key == "pet" then
			selected = T.view.pet
		else
			selected = not T.view.pet and d.group == (T.view.group or active)
		end
		if selected then b.selected:Show() else b.selected:Hide() end
		b:ClearAllPoints()
		if previous then
			b:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, G.tabGap)
		else
			b:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		end
		b:Show()
		previous = b
	end
	for i = #defs + 1, #bar.tabs do bar.tabs[i]:Hide() end
end

-- ------------------------------------------------------------ Glyphs
-- WotLK keeps control: its own hidden tabs are clicked
local function specializationTab(key)
	for i = 1, 4 do
		local b = _G["PlayerSpecTab" .. i]
		if b and b.specIndex == key then return b end
	end
end

function T.openGlyphs(group)
	group = group or (GetActiveTalentGroup and GetActiveTalentGroup(false, false)) or 1
	T.view.pet, T.view.group = false, group
	local spec = specializationTab("spec" .. group)
	if spec and PlayerSpecTab_OnClick then PlayerSpecTab_OnClick(spec) end
	local tab = _G["PlayerTalentFrameTab" .. (GLYPH_TALENT_TAB or 4)]
	if tab and PlayerTalentTab_OnClick then PlayerTalentTab_OnClick(tab) end
end

function T.closeGlyphs()
	if not (GlyphFrame and GlyphFrame:IsShown()) then return end
	local tab = _G["PlayerTalentFrameTab1"]
	if tab and PlayerTalentTab_OnClick then
		PlayerTalentTab_OnClick(tab)
	else
		GlyphFrame:Hide()
	end
end

-- Places GlyphFrame on the reduced page: parchment centered, at its size. GlyphFrame keeps
-- its WotLK parent (PlayerTalentFrame): reparenting it to our frames crashes the client at
-- logout (ERROR #132, frame destruction hits a freed child). It is only anchored to the page
-- and raised above it.
function T.placeGlyphs()
	local g = GlyphFrame
	if not g or not T.page then return end
	T.buildGlyphScenery()
	g:ClearAllPoints()
	g:SetPoint("TOPLEFT", T.className, "CENTER", -G.glyphCenterX, -G.glyphCenterY)
	-- Scenery (on the inner frame), its glows (frame + 2), then the sockets
	g:SetFrameLevel(T.frame:GetFrameLevel() + 3)
	-- Hide WotLK's scenery: parchment, glow and title
	if _G.GlyphFrameBackground then _G.GlyphFrameBackground:Hide() end
	if g.glow then g.glow:Hide() end
	if _G.GlyphFrameTitleText then _G.GlyphFrameTitleText:Hide() end
	T.raiseCloseButton()
end

-- Scenery: ours (never GlyphFrame itself, see above). Its textures sit ON THE INNER FRAME, in
-- its background layers, so the frame's border (OVERLAY) draws over them. One frame orders
-- its layers; two frames at the same level have no guaranteed order.
function T.buildGlyphScenery()
	if T.scenery then return T.scenery end
	local className, frame = T.className, T.frame
	local scenery = { textures = {} }
	local parchment = frame:CreateTexture("ForeverUIGlyphParchment", "BACKGROUND")
	applyGlyph(parchment, "parchment")
	parchment:SetAllPoints(className)
	local circle = frame:CreateTexture("ForeverUIGlyphCircle", "BORDER")
	applyGlyph(circle, "circle", true)
	circle:SetPoint("TOPLEFT", className, "CENTER", -G.circleCenterX, G.circleCenterY)
	scenery.textures = { parchment, circle }
	for _, c in ipairs({ { "coin-hg", "TOPLEFT", 1, -1 }, { "coin-hd", "TOPRIGHT", -1, -1 },
		{ "coin-bg", "BOTTOMLEFT", 1, 1 }, { "coin-bd", "BOTTOMRIGHT", -1, 1 } }) do
		local t = frame:CreateTexture("ForeverUIGlyphCorner" .. c[1]:sub(-2), "ARTWORK")
		applyGlyph(t, c[1], true)
		t:SetPoint(c[2], className, c[2], c[3] * G.cornerIndentX, c[4] * G.cornerIndentY)
		table.insert(scenery.textures, t)
	end
	function scenery:Show()
		for _, t in ipairs(self.textures) do t:Show() end
		if self.circles then self.circles:Show() end
	end
	function scenery:Hide()
		for _, t in ipairs(self.textures) do t:Hide() end
		if self.circles then self.circles:Hide() end
	end

	-- Concentric circles: over the parchment, under the glows and sockets, in ADD; they only
	-- rotate while the page is shown
	local circles = CreateFrame("Frame", "ForeverUIGlyphRings", T.page)
	circles:SetAllPoints(className)
	circles:SetFrameLevel(frame:GetFrameLevel() + 1)
	circles.rings = {}
	for i, def in ipairs(CIRCLES) do
		local t = circles:CreateTexture(nil, "ARTWORK")
		applyGlyph(t, def.key, true)
		t:SetBlendMode("ADD")
		t:SetPoint("CENTER", className, "CENTER", 0, 0)
		t:SetAlpha(0)
		circles.rings[i] = { texture = t, def = def, angle = 0, alpha = 0, target = 0 }
	end
	circles:SetScript("OnUpdate", function(self, elapsed)
		for _, a in ipairs(self.rings) do
			a.angle = (a.angle + 2 * math.pi * elapsed / a.def.loop) % (2 * math.pi)
			rotateRing(a.texture, a.def.key, a.angle)
			if a.alpha ~= a.target then
				local step = G.circlesFade * elapsed
				if a.alpha < a.target then
					a.alpha = math.min(a.target, a.alpha + step)
				else
					a.alpha = math.max(a.target, a.alpha - step)
				end
				a.texture:SetAlpha(a.alpha)
			end
		end
	end)
	circles:Hide()
	scenery.circles = circles

	-- Glows: above the frame, under the sockets, in ADD
	local glows = CreateFrame("Frame", "ForeverUIGlyphGlow", T.page)
	glows:SetAllPoints(className)
	glows:SetFrameLevel(frame:GetFrameLevel() + 2)
	glows.textures = {}
	for _, key in ipairs({ "anneau-runique", "anneau-epines", "anneau-double", "rayon-0", "rayon-1", "rayon-2" }) do
		local t = glows:CreateTexture(nil, "OVERLAY")
		applyGlyph(t, key, true)
		t:SetBlendMode("ADD")
		t:SetPoint("CENTER", className, "CENTER", 0, 0)
		glows.textures[key] = t
	end
	glows:SetAlpha(0)
	glows:Hide()
	glows:SetScript("OnUpdate", function(self, elapsed)
		self.clock = (self.clock or 0) + elapsed
		local t = self.clock
		if t < G.glowRise then
			self:SetAlpha(t / G.glowRise)
		elseif t < G.glowRise + G.glowFall then
			self:SetAlpha(1 - (t - G.glowRise) / G.glowFall)
		else
			self:SetAlpha(0)
			self:Hide()
		end
	end)
	scenery.glows = glows
	scenery:Hide()
	T.scenery = scenery
	return scenery
end

-- GlyphFrame_PulseGlow: our glows replace UI-GlyphFrame-Glow
function T.pulseGlyphs()
	local glows = T.scenery and T.scenery.glows
	if not glows then return end
	glows.clock = 0
	glows:SetAlpha(0)
	glows:Show()
	if GlyphFrame and GlyphFrame.glow then GlyphFrame.glow:Hide() end
end

-- Socket highlight: the orange ring, at the size WotLK gives it (the mount's, 108 or 86);
-- GlyphFrameGlyph_SetGlyphType resets its coords to UI-GlyphFrame on every update
local function highlight(button)
	if button and button.highlight then applyGlyph(button.highlight, "anneau-orange") end
end

-- Filled sockets of the spec shown set each circle's target alpha (GetGlyphSocketInfo returns
-- the spell of the inscribed glyph)
function T.countGlyphs()
	local circles = T.scenery and T.scenery.circles
	if not circles then return end
	local group = PlayerTalentFrame and PlayerTalentFrame.talentGroup
	for _, a in ipairs(circles.rings) do
		local n = 0
		for _, id in ipairs(a.def.sockets) do
			local _, _, spell = GetGlyphSocketInfo(id, group)
			if spell then n = n + 1 end
		end
		a.target = G.circlesAlpha * n / #a.def.sockets
	end
end

-- Inactive spec: the scenery is grayed, as WotLK grays its background
function T.grayOutGlyphs()
	if not T.scenery then return end
	local active = PlayerTalentFrame and not PlayerTalentFrame.pet
		and PlayerTalentFrame.talentGroup == GetActiveTalentGroup(false, false)
	for _, t in ipairs(T.scenery.textures) do t:SetDesaturated(not active) end
end

-- Before the client destroys the UI, GlyphFrame gets back the anchor WotLK gives it
-- (ADDON_LOADED: SetAllPoints on PlayerTalentFrame); it returns to the page on its next open
function T.restoreGlyphs()
	local g = GlyphFrame
	if not g or not PlayerTalentFrame then return end
	g:ClearAllPoints()
	g:SetAllPoints(PlayerTalentFrame)
end

-- Once, when Blizzard_GlyphUI is loaded
function T.hookGlyphs()
	local g = GlyphFrame
	if not g or g.foreverHooked then return end
	g.foreverHooked = true
	g:HookScript("OnShow", function()
		T.placeGlyphs()
		if T.book and T.book:IsVisible() then T.update() end
	end)
	-- At logout the client destroys the UI and hides GlyphFrame if shown; resizing and
	-- re-anchoring the window during that destruction crashes the client (ERROR #132).
	-- Nothing moves after PLAYER_LOGOUT / PLAYER_LEAVING_WORLD (T.finished).
	g:HookScript("OnHide", function()
		if not T.finished and T.book and T.book:IsVisible() then T.update() end
	end)
	-- Hooks on WotLK's code: glow, highlight, sparkles, gray-out
	if type(GlyphFrame_PulseGlow) == "function" then
		hooksecurefunc("GlyphFrame_PulseGlow", T.pulseGlyphs)
	end
	if type(GlyphFrameGlyph_SetGlyphType) == "function" then
		hooksecurefunc("GlyphFrameGlyph_SetGlyphType", highlight)
	end
	for i = 1, 6 do highlight(_G["GlyphFrameGlyph" .. i]) end
	if type(GlyphFrame_StartSlotAnimation) == "function" then
		hooksecurefunc("GlyphFrame_StartSlotAnimation", function(id)
			local e = _G["GlyphFrameSparkle" .. id]
			if not e then return end
			local l, h = e:GetWidth(), e:GetHeight()
			applyGlyph(e, "star")
			e:SetWidth(l * G.sparkScale)
			e:SetHeight(h * G.sparkScale)
		end)
	end
	if type(GlyphFrame_Update) == "function" then
		hooksecurefunc("GlyphFrame_Update", function()
			T.grayOutGlyphs()
			T.countGlyphs()
		end)
	end
	-- A glyph inscribed or removed (GLYPH_ADDED / _REMOVED / _UPDATED) calls
	-- GlyphFrameGlyph_UpdateSlot, not GlyphFrame_Update
	if type(GlyphFrameGlyph_UpdateSlot) == "function" then
		hooksecurefunc("GlyphFrameGlyph_UpdateSlot", T.countGlyphs)
	end
	T.placeGlyphs()
end

-- Width: three trees, one (narrow: pet, glyphs) or three narrower columns (inspection);
-- height: no bottom strip during inspection
function T.applyWidth(narrow)
	local pageW = narrow and G.narrowPage or (T.inspection and 3 * G.inspectionColumn) or G.pageW
	local indent = T.inspection and G.backgroundBottom or 0
	T.book:SetHeight(G.height - indent)
	T.page:SetHeight(G.pageH - indent)
	T.background:SetHeight(G.backgroundH - indent)
	T.className:ClearAllPoints()
	T.className:SetPoint("TOPLEFT", T.background, "TOPLEFT", 0, G.backgroundTop)
	T.className:SetPoint("BOTTOMRIGHT", T.background, "BOTTOMRIGHT", 0, G.backgroundBottom - indent)
	-- Headers keep the same offset from their column's center; during inspection, the small
	-- separator is cropped to its column
	local centers, transitions = columnsX()
	local e = ForeverUI.AtlasEntry("talents-small-divider-c60")
	for i, h in ipairs(T.headers) do
		local gap = G.headerX + (i - 1) * G.headerGap - (G.columnsX[i] - G.frameLeft)
		h:ClearAllPoints()
		h:SetPoint("CENTER", T.frame, "TOPLEFT", centers[i] - G.frameLeft + gap, G.headerY)
		local t = h.line
		atlas(t, "talents-small-divider-c60")
		local g, d = 0, e and e[6] or t:GetWidth()
		if T.inspection and e then
			-- Separator center from the column center; the kept window, in separator coordinates
			local lineCenter = gap + 60
			local a = G.inspectionColumn / 2 - G.smallSeparatorMargin
			g = math.max(0, -a - lineCenter + e[6] / 2)
			d = math.min(e[6], a - lineCenter + e[6] / 2)
			local du = (e[3] - e[2]) / e[6]
			t:SetTexCoord(e[2] + g * du, e[2] + d * du, e[4], e[5])
			t:SetWidth(d - g)
		end
		t:ClearAllPoints()
		t:SetPoint("BOTTOM", h, "BOTTOM", 60 + (g + d) / 2 - (e and e[6] or d) / 2, G.smallSeparatorY)
	end
	T.book:SetWidth(G.width - G.pageW + pageW)
	T.page:SetWidth(pageW)
	placeStone(pageW, G.backgroundH - indent)
	-- Horizontal bars cropped to half the width: the end ornament stays, the line reaches the
	-- center
	local half = (pageW - 2 * G.frameLeft) / 2
	for _, d in ipairs({ { T.barLeft, "talents-divider-left-c60", false },
		{ T.barRight, "talents-divider-right-c60", true } }) do
		local t, e = d[1], ForeverUI.AtlasEntry(d[2])
		if e then
			local l = math.min(e[6], half)
			local du = (e[3] - e[2]) * l / e[6]
			if d[3] then
				t:SetTexCoord(e[3] - du, e[3], e[4], e[5])
			else
				t:SetTexCoord(e[2], e[2] + du, e[4], e[5])
			end
			t:SetWidth(l)
		end
	end
	for i, v in ipairs(T.verticals) do
		v:ClearAllPoints()
		v:SetPoint("TOP", T.frame, "TOPLEFT", transitions[i] - G.frameLeft, G.verticalTop)
		if narrow then v:Hide() else v:Show() end
	end
	T.narrow = narrow
end

-- Class art behind the trees, and the portrait
local function placeBackground(tabs)
	local className = T.className
	for _, t in ipairs(className.textures) do t:Hide() end
	local _, token = UnitClass(T.inspection or "player")
	-- Portrait: the class shown (the inspected unit's during inspection)
	T.book.portrait:SetTexture(PORTRAIT .. string.lower(token or "warrior"))
	-- One background per tree: death knights (the middle third of each modern image), and
	-- inspection (the tree's own third of the class art, cropped on each side like its column)
	local dk = token == "DEATHKNIGHT"
	if (dk or T.inspection) and not T.narrow then
		local l = T.inspection and G.inspectionColumn or G.pageW / 3
		local keep = l / (G.pageW / 3)
		for i = 1, 3 do
			local t = className.textures[i] or className:CreateTexture(nil, "BACKGROUND")
			className.textures[i] = t
			local e = ForeverUI.AtlasEntry(dk and BACKGROUND_DK[i] or ("talent-background-" .. string.lower(token or "warrior")))
			if e then
				t:SetTexture(e[1])
				local du = (e[3] - e[2]) / 3
				local start = e[2] + du * (dk and 1 or (i - 1))
				local margin = du * (1 - keep) / 2
				t:SetTexCoord(start + margin, start + du - margin, e[4], e[5])
			end
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", className, "TOPLEFT", (i - 1) * l, 0)
			t:SetPoint("BOTTOMLEFT", className, "BOTTOMLEFT", (i - 1) * l, 0)
			t:SetWidth(l)
			t:Show()
		end
		return
	end
	local t = className.textures[1] or className:CreateTexture(nil, "BACKGROUND")
	className.textures[1] = t
	local name = "talent-background-" .. string.lower(token or "warrior")
	atlas(t, name, true)
	-- The reduced window shows the first third of the art: the one of the column it keeps
	if T.narrow then
		local e = ForeverUI.AtlasEntry(name)
		if e then t:SetTexCoord(e[2], e[2] + (e[3] - e[2]) / 3, e[4], e[5]) end
	end
	t:ClearAllPoints()
	t:SetAllPoints(className)
	t:Show()
end

function T.update()
	if not T.book or T.finished then return end
	local tabs, points = T.read()
	T.tabs = tabs
	T.applyWidth(T.pet or T.glyphs)
	placeBackground(tabs)
	T.layoutTabs()
	-- Glyphs: the page keeps only the stone and its frame
	local glyphs = T.glyphs
	for _, f in ipairs({ T.className, T.tree, T.points, T.barLeft, T.barRight }) do
		if glyphs then f:Hide() else f:Show() end
	end
	-- No unspent points during inspection, nor search (TalentsSearch.lua)
	if T.inspection then T.points:Hide() end
	local title = TEXT.title
	if T.inspection then title = string.format(TEXT.inspection, UnitName(T.inspection) or "") end
	T.book.title:SetText(glyphs and _G.GlyphFrameTitleText and _G.GlyphFrameTitleText:GetText() or title)
	if T.scenery then
		if glyphs then T.scenery:Show() else T.scenery:Hide() end
	end
	local search = ForeverUI.TalentsSearch
	if glyphs then
		if search then search.update() end
		for _, h in ipairs(T.headers) do h:Hide() end
		T.placeGlyphs()
		T.scenery:Show()
		T.grayOutGlyphs()
		T.countGlyphs()
		T.applyButton:Hide()
		T.cancelButton:Hide()
		if T.active then
			T.activateButton:Hide()
		else
			T.activateButton:Show()
			local spell = ACTIVATION_SPELLS[T.group]
			T.activateButton:Activate(not (spell and IsCurrentSpell and IsCurrentSpell(spell)))
		end
		return
	end
	local perTier = T.pet and G.petPointsPerTier or G.pointsPerTier

	-- Headers
	for i, h in ipairs(T.headers) do
		local o = tabs[i]
		if o then
			SetPortraitToTexture(h.icon, o.icon)
			h.name:SetText(o.name)
			h.spent:SetText(tostring(o.spent))
			h:Show()
		else
			h:Hide()
		end
	end
	-- Apply and Undo only with pending changes; on an inactive spec, Activate instead
	local pending = (T.pending or 0) > 0
	if T.inspection then
		T.applyButton:Hide()
		T.cancelButton:Hide()
		T.activateButton:Hide()
	elseif T.active then
		T.activateButton:Hide()
		T.applyButton:Show()
		T.applyButton:Activate(pending)
		if pending then T.applyButton.glow:Show() T.cancelButton:Show()
		else T.applyButton.glow:Hide() T.cancelButton:Hide() end
	else
		T.applyButton:Hide()
		T.cancelButton:Hide()
		T.activateButton:Show()
		-- While the activation spell casts, the button is disabled
		-- (PlayerTalentFrameActivateButton)
		local spell = ACTIVATION_SPELLS[T.group]
		T.activateButton:Activate(not (spell and IsCurrentSpell and IsCurrentSpell(spell)))
	end

	-- Unspent points: green if any are left
	T.points.count:SetText(tostring(points))
	color(T.points.count, points > 0 and COLOR.green or COLOR.gray)

	-- Nodes
	local tree = T.tree
	local n = 0
	local bySlot = {}
	for _, o in ipairs(tabs) do
		for _, t in ipairs(o.talents) do
			n = n + 1
			local b = tree.nodes[n] or createNode(n)
			tree.nodes[n] = b
			local isOpen = (t.tier - 1) * perTier <= o.spent
			t.state = stateOf(t, isOpen, T.inspection and 0 or points)
			fillNode(b, t, t.state)
			bySlot[t.tab .. ":" .. t.tier .. ":" .. t.column] = t
		end
	end
	for i = n + 1, #tree.nodes do
		tree.nodes[i].talent = nil
		tree.nodes[i]:Hide()
	end

	-- Arrows: prerequisites of each talent (tier, column, met)
	local nW, nH = 1, 1
	for _, o in ipairs(tabs) do
		for _, t in ipairs(o.talents) do
			local p = { GetTalentPrereqs(t.tab, t.index, T.inspection ~= nil, T.pet, T.group) }
			for k = 1, #p, 4 do
				local source = bySlot[t.tab .. ":" .. p[k] .. ":" .. p[k + 1]]
				if source then
					local filled = p[k + 3]
					if filled == nil then filled = p[k + 2] end
					local state = (t.state == "locked") and "locked" or (filled and "yellow" or "gray")
					nW, nH = arrow(nW, nH, source, t, state)
				end
			end
		end
	end
	for i = nW, #tree.lines do tree.lines[i]:Hide() end
	for i = nH, #tree.arrowHeads do tree.arrowHeads[i]:Hide() end

	-- Gates: one per tree, at the first locked tier holding a talent, left of its first node;
	-- none during inspection
	local nGate = 0
	for ti, o in ipairs(tabs) do
		local first
		for _, t in ipairs(o.talents) do
			if t.state == "locked" and (not first or t.tier < first.tier
				or (t.tier == first.tier and t.column < first.column)) then
				first = t
			end
		end
		if first and not T.inspection then
			nGate = nGate + 1
			local p = tree.gates[nGate] or createGate(nGate)
			tree.gates[nGate] = p
			p.rest = (first.tier - 1) * perTier - o.spent
			p.text:SetText(tostring(p.rest))
			local x, y = center(first.tab, first.tier, first.column)
			p:ClearAllPoints()
			p:SetPoint("RIGHT", tree, "TOPLEFT", x - G.node / 2 + G.gateX, y)
			p:Show()
		end
	end
	for i = nGate + 1, #tree.gates do tree.gates[i]:Hide() end

	-- Search: its width, and the node marks
	if search then
		search.place(T.page:GetWidth())
		search.update()
	end
end

-- ------------------------------------------------------------ Inspection
-- Talents button of the inspect frame (Inspect.lua): opens the window on the inspected unit,
-- or switches to it if already open. Closing brings back the player's screen (OnHide below).
function T.inspect(unit)
	if not unit then return end
	if not PlayerTalentFrame and TalentFrame_LoadUI then TalentFrame_LoadUI() end
	if not PlayerTalentFrame then return end
	T.build()
	T.closeGlyphs()
	T.inspection = unit
	if PlayerTalentFrame:IsShown() then
		T.view.group, T.view.pet = nil, false
		T.update()
	else
		ShowUIPanel(PlayerTalentFrame)
	end
end

-- ------------------------------------------------------------ Assembly
-- Silences PlayerTalentFrame's own art and children, except our book, the close button and
-- GlyphFrame
function T.suppressWotLK()
	local f = PlayerTalentFrame
	if not f then return end
	for _, region in ipairs({ f:GetRegions() }) do suppress(region) end
	for _, child in ipairs({ f:GetChildren() }) do
		if child ~= T.book and child ~= PlayerTalentFrameCloseButton and child ~= GlyphFrame then
			suppress(child)
		end
	end
end

-- ------------------------------------------------------------ Close confirmation
-- Pending changes: the player's (active spec, the only one that takes points) or the pet's
local function hasPet()
	return (GetNumTalentTabs(false, true) or 0) > 0
end
function T.queued()
	local n = GetGroupPreviewTalentPointsSpent(false, GetActiveTalentGroup(false, false)) or 0
	if hasPet() then
		n = n + (GetGroupPreviewTalentPointsSpent(true, GetActiveTalentGroup(false, true)) or 0)
	end
	return n > 0
end

-- CONTINUE: drop the pending changes and really close
function T.closeNow()
	ResetGroupPreviewTalentPoints(false, GetActiveTalentGroup(false, false))
	if hasPet() then ResetGroupPreviewTalentPoints(true, GetActiveTalentGroup(false, true)) end
	T.confirmed = true
	HideUIPanel(PlayerTalentFrame)
	T.confirmed = nil
end

-- StaticPopupDialogs always exists (StaticPopup.lua): NEVER reassign it. The whole global
-- would become addon-owned and taint every client popup (BindEnchant blocked). Only our key
-- is written.
StaticPopupDialogs["FOREVERUI_TALENTS_CONFIRM_CLOSE"] = {
	text = TEXT.confirmClose,
	button1 = CONTINUE,
	button2 = CANCEL,
	OnAccept = function() T.closeNow() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

-- Closed with pending changes: 3.3.5 cannot cancel a close without tainting HideUIPanel, so
-- the window reopens on the next frame, as it was, and asks
local reopener = CreateFrame("Frame")
reopener:Hide()
reopener:SetScript("OnUpdate", function(self)
	self:Hide()
	if T.finished or not T.queued() then return end
	T.keepView = true
	ShowUIPanel(PlayerTalentFrame)
	T.keepView = nil
	StaticPopup_Show("FOREVERUI_TALENTS_CONFIRM_CLOSE")
end)
T.reopener = reopener

function T.build()
	if T.book or not PlayerTalentFrame then return T.book end
	PlayerTalentFrame:EnableMouse(false)
	local book = CreateFrame("Frame", "ForeverUITalentsFrame", PlayerTalentFrame)
	book:SetPoint("TOP", UIParent, "TOP", 0, G.top)
	book:SetWidth(G.width)
	book:SetHeight(G.height)
	book:EnableMouse(true)
	T.book = book
	buildFrame(book)
	buildPage(book)
	-- Side tab bar, outside on the right (CharacterFrameModeTabs)
	local bar = CreateFrame("Frame", "ForeverUITalentsTabs", book)
	bar:SetWidth(64)
	bar:SetHeight(384)
	bar:SetPoint("TOPLEFT", book, "TOPRIGHT", G.tabsX, G.tabsY)
	bar:SetFrameLevel(book:GetFrameLevel() + 1)
	T.tabBar = bar
	T.suppressWotLK()
	T.hookGlyphs()
	-- Search (TalentsSearch.lua loads after this file; if not loaded yet, it builds itself)
	if ForeverUI.TalentsSearch then ForeverUI.TalentsSearch.build(T) end
	-- Movable by its title; brought to front when opened or clicked
	ForeverUI.WindowStack.makeMovable(book, book.banner, "talents")
	ForeverUI.WindowStack.register("talents", PlayerTalentFrame, function()
		return { T.book, T.tabBar, _G.ForeverUITalentsSearchPreview, _G.ForeverUITalentsSearchOptionsList }
	end)

	PlayerTalentFrame:HookScript("OnShow", function()
		T.suppressWotLK()
		T.raiseCloseButton()
		-- On every open, the active spec (SetTab(GetActiveTab())); not when it reopens to confirm
		if not T.keepView then T.view.group, T.view.pet = nil, false end
		T.update()
	end)
	PlayerTalentFrame:HookScript("OnHide", function()
		T.inspection = nil
		if T.finished or T.confirmed or not T.queued() then return end
		reopener:Show()
	end)
	for _, name in ipairs({ "PlayerTalentFrame_Refresh", "PlayerTalentFrame_Update" }) do
		if type(_G[name]) == "function" then
			hooksecurefunc(name, function()
				T.suppressWotLK()
				if T.book:IsVisible() then T.update() end
			end)
		end
	end
	return book
end

-- Blizzard_TalentUI loads on demand: the screen is built when it arrives (or now if already
-- loaded)
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_TALENT_UPDATE")
watcher:RegisterEvent("CHARACTER_POINTS_CHANGED")
watcher:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
watcher:RegisterEvent("PREVIEW_TALENT_POINTS_CHANGED")
watcher:RegisterEvent("PREVIEW_PET_TALENT_POINTS_CHANGED")
watcher:RegisterEvent("PET_TALENT_UPDATE")
watcher:RegisterEvent("UNIT_PET")
watcher:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
watcher:RegisterEvent("PLAYER_LEVEL_UP")
watcher:RegisterEvent("PLAYER_LOGOUT")
watcher:RegisterEvent("PLAYER_LEAVING_WORLD")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("INSPECT_TALENT_READY")
watcher:SetScript("OnEvent", function(_, ev, arg1)
	if ev == "ADDON_LOADED" then
		if arg1 == "Blizzard_TalentUI" then T.build() end
		if arg1 == "Blizzard_GlyphUI" and T.book then T.hookGlyphs() end
		return
	end
	if ev == "PLAYER_LOGOUT" or ev == "PLAYER_LEAVING_WORLD" then
		T.finished = true
		T.restoreGlyphs()
		return
	end
	if ev == "PLAYER_ENTERING_WORLD" then T.finished = false return end
	if ev == "UNIT_PET" and arg1 ~= "player" then return end
	if T.book and T.book:IsVisible() then T.update() end
end)
if PlayerTalentFrame then T.build() end
