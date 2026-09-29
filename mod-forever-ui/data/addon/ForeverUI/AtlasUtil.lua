-- ForeverUI: drawing parts of atlas sheets.
-- A sheet stays one texture: only the rectangle read from it moves. A partial fill
-- (health bar at 40 %) crops that rectangle instead of stretching the image, which would
-- distort the art.

ForeverUI = ForeverUI or {}

-- Atlas entry { file, left, right, top, bottom, width, height }, or nil if unknown.
local function entry(name)
	if not UIAtlas or not UIAtlas.data then
		return nil
	end
	return UIAtlas.data[name]
end

ForeverUI.AtlasEntry = entry

-- Sets a texture to an atlas element. keepSize keeps the current size (when the frame
-- sets its own dimensions).
function ForeverUI.SetAtlas(texture, name, keepSize)
	local e = entry(name)
	if not e then
		return false
	end

	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[3], e[4], e[5])

	if not keepSize then
		texture:SetWidth(e[6])
		texture:SetHeight(e[7])
	end

	return true
end

-- Left-to-right fill: the rectangle is cropped to the fraction. fullWidth: width at 100 %.
-- The client rejects a zero width, so the texture is hidden instead.
function ForeverUI.SetAtlasFill(texture, name, fraction, fullWidth)
	local e = entry(name)
	if not e then
		texture:Hide()
		return false
	end

	if not fraction or fraction ~= fraction or fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end

	local width = (fullWidth or e[6]) * fraction
	if width < 1 then
		texture:Hide()
		return true
	end

	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[2] + (e[3] - e[2]) * fraction, e[4], e[5])
	texture:SetWidth(width)
	texture:SetHeight(e[7])
	texture:Show()
	return true
end

-- Nine-slice cut of one atlas element.
-- mainline/MainActionBar.xml, camelot/MainMenuBarBagButtons.xml and MainMenuBarMicroMenu.xml
-- all frame their group with UI-HUD-ActionBar-Frame (TOPLEFT -6, 6; BOTTOMRIGHT 4, -5):
-- a 55 x 55 octagon (110 x 110 on a 2x sheet) with a bronze edge. The modern client
-- nine-slices it; stretched in one piece over 560 px, its bevels would become ramps.
-- options.name: atlas element; options.layer: draw layer (BACKGROUND by default);
-- options.imageMargin: corner size in the image, px; options.imageSize: image side, px;
-- options.margin: corner size on screen, px.
function ForeverUI.SetAtlasNineSlice(parent, options)
	local e = entry(options.name)
	if not e then
		return nil
	end

	local layer = options.layer or "BACKGROUND"
	local margin = options.margin
	local fraction = options.imageMargin / options.imageSize
	local du = (e[3] - e[2]) * fraction
	local dv = (e[5] - e[4]) * fraction
	local u = { e[2], e[2] + du, e[3] - du, e[3] }
	local v = { e[4], e[4] + dv, e[5] - dv, e[5] }

	local function piece(cu1, cu2, cv1, cv2)
		local t = parent:CreateTexture(nil, layer)
		t:SetTexture(e[1])
		t:SetTexCoord(u[cu1], u[cu2], v[cv1], v[cv2])
		return t
	end

	local p = {}

	p.topLeftCorner = piece(1, 2, 1, 2)
	p.topLeftCorner:SetWidth(margin)
	p.topLeftCorner:SetHeight(margin)
	p.topLeftCorner:SetPoint("TOPLEFT", parent, "TOPLEFT")

	p.topRightCorner = piece(3, 4, 1, 2)
	p.topRightCorner:SetWidth(margin)
	p.topRightCorner:SetHeight(margin)
	p.topRightCorner:SetPoint("TOPRIGHT", parent, "TOPRIGHT")

	p.bottomLeftCorner = piece(1, 2, 3, 4)
	p.bottomLeftCorner:SetWidth(margin)
	p.bottomLeftCorner:SetHeight(margin)
	p.bottomLeftCorner:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT")

	p.bottomRightCorner = piece(3, 4, 3, 4)
	p.bottomRightCorner:SetWidth(margin)
	p.bottomRightCorner:SetHeight(margin)
	p.bottomRightCorner:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")

	-- Edges and center are set by two opposite corners: no size to compute.
	p.topEdge = piece(2, 3, 1, 2)
	p.topEdge:SetPoint("TOPLEFT", p.topLeftCorner, "TOPRIGHT")
	p.topEdge:SetPoint("BOTTOMRIGHT", p.topRightCorner, "BOTTOMLEFT")

	p.bottomEdge = piece(2, 3, 3, 4)
	p.bottomEdge:SetPoint("TOPLEFT", p.bottomLeftCorner, "TOPRIGHT")
	p.bottomEdge:SetPoint("BOTTOMRIGHT", p.bottomRightCorner, "BOTTOMLEFT")

	p.leftEdge = piece(1, 2, 2, 3)
	p.leftEdge:SetPoint("TOPLEFT", p.topLeftCorner, "BOTTOMLEFT")
	p.leftEdge:SetPoint("BOTTOMRIGHT", p.bottomLeftCorner, "TOPRIGHT")

	p.rightEdge = piece(3, 4, 2, 3)
	p.rightEdge:SetPoint("TOPLEFT", p.topRightCorner, "BOTTOMLEFT")
	p.rightEdge:SetPoint("BOTTOMRIGHT", p.bottomRightCorner, "TOPRIGHT")

	p.center = piece(2, 3, 2, 3)
	p.center:SetPoint("TOPLEFT", p.topLeftCorner, "BOTTOMRIGHT")
	p.center:SetPoint("BOTTOMRIGHT", p.bottomRightCorner, "TOPLEFT")

	return p
end

-- Frame art shared by the three groups at the bottom of the screen.
-- The corner must hold the whole bevel: the image's top and left profiles only become
-- constant from pixel 19 of 110. A smaller cut stretches part of the diagonal along the
-- bar. So 20 (one pixel of margin), which is 10 px on screen on this 2x sheet.
function ForeverUI.SetBarFrameArt(frame, layer)
	return ForeverUI.SetAtlasNineSlice(frame, {
		name = "ui-hud-actionbar-frame",
		layer = layer or "BACKGROUND",
		imageMargin = 20,
		imageSize = 110,
		margin = 10,
	})
end

-- Divider between two slots. mainline/MainActionBar.xml HorizontalDividerTemplate: 12 wide,
-- three vertical slices of ui-hud-actionbar-frame-divider. Heights 14 top, 16 center,
-- 15 bottom fit a 45 button.
function ForeverUI.CreateDivider(parent, level)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetWidth(12)
	frame:SetFrameLevel(level or parent:GetFrameLevel())

	local top = frame:CreateTexture(nil, "ARTWORK")
	if not ForeverUI.SetAtlas(top, "ui-hud-actionbar-frame-divider-threeslice-edgetop", true) then
		frame:Hide()
		return frame
	end
	top:SetHeight(14)
	top:SetPoint("TOPLEFT", frame, "TOPLEFT")
	top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

	local down = frame:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(down, "ui-hud-actionbar-frame-divider-threeslice-edgebottom", true)
	down:SetHeight(15)
	down:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	down:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

	local center = frame:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(center, "!ui-hud-actionbar-frame-divider-threeslice-center", true)
	center:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
	center:SetPoint("BOTTOMRIGHT", down, "TOPRIGHT")

	frame.top, frame.center, frame.down = top, center, down
	return frame
end

-- Panel art: mainline/SharedUIPanelTemplates.xml PortraitFrameFlatTemplate, two layers.
-- 1. Flat background (FlatPanelBackgroundTemplate), TOPLEFT (2, -20) to BOTTOMRIGHT (-2, 3):
--    two 16 x 16 rounded bottom corners, an edge between them, the rest flat, all tinted
--    by PANEL_BACKGROUND_COLOR.
-- 2. Metal nine-slice frame: HeldBagLayout (mainline/NineSliceLayouts.lua) with the fixes
--    of camelot/NineSliceLayoutOverrides.lua (top right corner x -2, bottom corners y -8).
-- PANEL_BACKGROUND_COLOR is not in the extracted code; measured on a real client capture
-- (docs/reference): (16, 14, 12), opaque. A translucent one turns bag slot gaps blue.
-- Edges are stretched, not tiled: a tiled atlas texture spreads the whole sheet.
local PANEL_BACKGROUND = { 16 / 255, 14 / 255, 12 / 255, 1 }

-- HeldBagLayout (blizzard_sharedxml/mainline/nineslicelayouts.lua): the eight pieces are
-- OVERLAY and each corner has its offset, copied as is. In OVERLAY the metal covers every
-- region of the frame itself. The source puts title and portrait in child frames
-- (TitleContainer at frameLevel 510, PortraitContainer), which draw above their parent's
-- regions; callers must do the same for anything that must stay visible.
local PANEL_LAYER = "OVERLAY"

local PANEL_CORNERS = {
	{ key = "topLeftCorner", name = "ui-frame-portraitmetal-cornertopleftsmall",
	  point = "TOPLEFT", x = -13, y = 16 },
	{ key = "topRightCorner", name = "ui-frame-metal-cornertopright",
	  point = "TOPRIGHT", x = 4, y = 16 },
	{ key = "bottomLeftCorner", name = "ui-frame-metal-cornerbottomleft",
	  point = "BOTTOMLEFT", x = -13, y = -3 },
	{ key = "bottomRightCorner", name = "ui-frame-metal-cornerbottomright",
	  point = "BOTTOMRIGHT", x = 4, y = -3 },
}

-- options.topLeftCorner: top left corner atlas. HeldBagLayout uses ...CornerTopLeftSmall,
--   PortraitFrameTemplate ...CornerTopLeft (a wider ring for a 62 portrait).
-- options.corners: { key = { x =, y = } } overrides a corner offset, as
--   camelot/NineSliceLayoutOverrides.lua does on every layout (its art has other sizes).
-- options.level: puts the metal in a child frame this many levels above the frame. Needed
--   when the frame has other child frames, which would draw over the metal. The background
--   stays on the frame itself, behind all its child frames.
function ForeverUI.SetPanelArt(frame, options)
	if frame.foreverPanel then
		return frame.foreverPanel
	end

	options = options or {}
	-- host: where the metal goes. The background stays on the frame, at the back.
	local host = frame
	if options.level then
		host = CreateFrame("Frame", nil, frame)
		host:SetAllPoints(frame)
		host:SetFrameLevel(frame:GetFrameLevel() + options.level)
		frame.foreverSkinLayer = host
	end

	local p = {}

	-- 1. Flat background
	local r, v, b, a = PANEL_BACKGROUND[1], PANEL_BACKGROUND[2], PANEL_BACKGROUND[3], PANEL_BACKGROUND[4]

	local bottomLeft = frame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(bottomLeft, "uiframebackground-nineslice-cornerbottomleft")
	bottomLeft:SetVertexColor(r, v, b, a)
	bottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 3)

	local bottomRight = frame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(bottomRight, "uiframebackground-nineslice-cornerbottomright")
	bottomRight:SetVertexColor(r, v, b, a)
	bottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 3)

	local bottomEdge = frame:CreateTexture(nil, "BACKGROUND")
	bottomEdge:SetTexture(r, v, b, a)
	bottomEdge:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT")
	bottomEdge:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")

	local body = frame:CreateTexture(nil, "BACKGROUND")
	body:SetTexture(r, v, b, a)
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -20)
	body:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")

	p.background = { bottomLeft, bottomRight, bottomEdge, body }

	-- 2. Metal frame
	for _, corner in ipairs(PANEL_CORNERS) do
		local texture = host:CreateTexture(nil, PANEL_LAYER)
		local atlasName = corner.name
		if corner.key == "topLeftCorner" and options.topLeftCorner then
			atlasName = options.topLeftCorner
		end
		if ForeverUI.SetAtlas(texture, atlasName) then
			local x, y = corner.x, corner.y
			local setting = options.corners and options.corners[corner.key]
			if setting then
				x = setting.x or x
				y = setting.y or y
			end
			texture:SetPoint(corner.point, host, corner.point, x, y)
			p[corner.key] = texture
			p[corner.key .. "Atlas"] = atlasName
		else
			texture:Hide()
		end
	end

	local function edge(name, point1, target1, relative1, point2, target2, relative2)
		local texture = host:CreateTexture(nil, PANEL_LAYER)
		if not ForeverUI.SetAtlas(texture, name) then
			texture:Hide()
			return nil
		end
		texture:SetPoint(point1, target1, relative1)
		texture:SetPoint(point2, target2, relative2)
		return texture
	end

	if p.topLeftCorner and p.topRightCorner then
		p.topEdge = edge("_ui-frame-metal-edgetop",
			"TOPLEFT", p.topLeftCorner, "TOPRIGHT",
			"TOPRIGHT", p.topRightCorner, "TOPLEFT")
		p.leftEdge = edge("!ui-frame-metal-edgeleft",
			"TOPLEFT", p.topLeftCorner, "BOTTOMLEFT",
			"BOTTOMLEFT", p.bottomLeftCorner, "TOPLEFT")
		p.rightEdge = edge("!ui-frame-metal-edgeright",
			"TOPRIGHT", p.topRightCorner, "BOTTOMRIGHT",
			"BOTTOMRIGHT", p.bottomRightCorner, "TOPRIGHT")
		p.bottomEdge = edge("_ui-frame-metal-edgebottom",
			"BOTTOMLEFT", p.bottomLeftCorner, "BOTTOMRIGHT",
			"BOTTOMRIGHT", p.bottomRightCorner, "BOTTOMLEFT")
	end

	frame.foreverPanel = p
	ForeverUI.UpdatePanelCorners(frame)
	return p
end

-- NineSliceUtil.UpdateCornerCropping and ClipNineSliceBottomCorner
-- (blizzard_sharedxml/nineslice.lua):
--   overhang = topCornerHeight + bottomCornerHeight - frameHeight
--              - topOffset - (-bottomOffset)
-- When a frame is shorter than its two corners stacked, the bottom corners are cropped from
-- the top by that overhang (texture coordinates and height). Otherwise the corners overlap
-- and the left edge between them is drawn upside down across the frame.
function ForeverUI.UpdatePanelCorners(frame)
	local p = frame.foreverPanel
	if not p then
		return
	end

	local topLeft, bottomLeft
	for _, corner in ipairs(PANEL_CORNERS) do
		if corner.key == "topLeftCorner" then topLeft = corner end
		if corner.key == "bottomLeftCorner" then bottomLeft = corner end
	end

	local topEntry = ForeverUI.AtlasEntry(p.topLeftCornerAtlas or topLeft.name)
	local bottomEntry = ForeverUI.AtlasEntry(bottomLeft.name)
	if not (topEntry and bottomEntry) then
		return
	end

	local overhang = topEntry[7] + bottomEntry[7] - frame:GetHeight() - topLeft.y - (-bottomLeft.y)

	for _, corner in ipairs(PANEL_CORNERS) do
		if corner.point == "BOTTOMLEFT" or corner.point == "BOTTOMRIGHT" then
			local texture = p[corner.key]
			local e = ForeverUI.AtlasEntry(corner.name)
			if texture and e then
				local trim = math.max(0, math.min(overhang, e[7]))
				local uvHeight = e[5] - e[4]
				texture:SetTexCoord(e[2], e[3], e[4] + (trim / e[7]) * uvHeight, e[5])
				texture:SetWidth(e[6])
				texture:SetHeight(e[7] - trim)
			end
		end
	end
end


-- Vertical divider in three slices. common-framedivider (11 x 50) has a cap at each end;
-- stretched over a panel's height, the caps smear over dozens of pixels. So it is cut by
-- texture coordinates into top cap, stretched middle and bottom cap.
-- atlas: element; endCap: cap height in px (4 by default); level: frame level.
function ForeverUI.CreateVerticalDivider(parent, atlas, endCap, level)
	local e = ForeverUI.AtlasEntry(atlas)
	local frame = CreateFrame("Frame", nil, parent)
	if not e then
		frame:Hide()
		return frame
	end

	endCap = endCap or 4
	frame:SetWidth(e[6])
	frame:SetFrameLevel(level or parent:GetFrameLevel())

	local u1, u2, v1, v2, height = e[2], e[3], e[4], e[5], e[7]
	local partV = (v2 - v1) * (endCap / height)

	local top = frame:CreateTexture(nil, "OVERLAY")
	top:SetTexture(e[1])
	top:SetTexCoord(u1, u2, v1, v1 + partV)
	top:SetHeight(endCap)
	top:SetPoint("TOPLEFT", frame, "TOPLEFT")
	top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

	local down = frame:CreateTexture(nil, "OVERLAY")
	down:SetTexture(e[1])
	down:SetTexCoord(u1, u2, v2 - partV, v2)
	down:SetHeight(endCap)
	down:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	down:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

	local middle = frame:CreateTexture(nil, "OVERLAY")
	middle:SetTexture(e[1])
	middle:SetTexCoord(u1, u2, v1 + partV, v2 - partV)
	middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
	middle:SetPoint("BOTTOMRIGHT", down, "TOPRIGHT")

	frame.top, frame.middle, frame.down = top, middle, down
	return frame
end

-- Nine slices cut from one image. A panel image has a shadow and fixed-size rounded
-- corners; stretched whole, the shadow scales with it and the corners distort. Corners keep
-- their size, edges stretch one way, the center both.
-- corner: corner size in px; margins = { left, top, right, bottom }: how far the image
-- overhangs the frame (the shadow thickness measured on the image), so the image's rim
-- falls on the frame edge; level: draw layer (BACKGROUND by default).
function ForeverUI.CreateNineSlice(parent, atlas, corner, margins, level)
	local e = ForeverUI.AtlasEntry(atlas)
	if not e then
		return nil
	end

	local path, u1, u2, v1, v2, width, height = e[1], e[2], e[3], e[4], e[5], e[6], e[7]
	local du = (u2 - u1) * corner / width
	local dv = (v2 - v1) * corner / height
	local us = { u1, u1 + du, u2 - du, u2 }
	local vs = { v1, v1 + dv, v2 - dv, v2 }

	local slices = {}
	local function slice(column, row)
		local t = parent:CreateTexture(nil, level or "BACKGROUND")
		t:SetTexture(path)
		t:SetTexCoord(us[column], us[column + 1], vs[row], vs[row + 1])
		slices[#slices + 1] = t
		return t
	end

	local topLeft, topRight = slice(1, 1), slice(3, 1)
	local bottomLeft, bottomRight = slice(1, 3), slice(3, 3)
	local top, down = slice(2, 1), slice(2, 3)
	local left, right = slice(1, 2), slice(3, 2)
	local center = slice(2, 2)

	for _, c in ipairs({ topLeft, topRight, bottomLeft, bottomRight }) do
		c:SetWidth(corner)
		c:SetHeight(corner)
	end
	top:SetHeight(corner)
	down:SetHeight(corner)
	left:SetWidth(corner)
	right:SetWidth(corner)

	local G, H, D, B = margins[1], margins[2], margins[3], margins[4]
	topLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", -G, H)
	topRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", D, H)
	bottomLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -G, -B)
	bottomRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", D, -B)

	top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
	top:SetPoint("TOPRIGHT", topRight, "TOPLEFT")
	down:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT")
	down:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")
	left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
	left:SetPoint("BOTTOMRIGHT", bottomLeft, "TOPRIGHT")
	right:SetPoint("TOPLEFT", topRight, "BOTTOMLEFT")
	right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")
	center:SetPoint("TOPLEFT", topLeft, "BOTTOMRIGHT")
	center:SetPoint("BOTTOMRIGHT", bottomRight, "TOPLEFT")

	return slices
end

-- Tertiary button, two states: common-button-tertiary-normal / -pressed, 46 x 34 each, sheet
-- commonbuttontertiaryc60. The rounded end is 11 px (column profile constant from x = 11),
-- so the corner is 11 on both axes. Stretched instead of sliced, it squashes past 46 wide.
-- The button keeps its own textures at alpha 0: they still hold its state for the client,
-- and some functions read them.
-- auto: the pressed state follows the mouse button. Otherwise the caller drives it with
-- button.foreverPress(true or false), e.g. statistic selectors, pressed while their list
-- is open.
local TERTIARY_NORMAL = "common-button-tertiary-normal"
local TERTIARY_PRESSED = "common-button-tertiary-pressed"
local TERTIARY_CORNER = 11
local TERTIARY_MARGINS = { 0, 0, 0, 0 }

function ForeverUI.SkinTertiaryButton(button, auto)
	if button.foreverPress then
		return button
	end

	for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture",
		"GetHighlightTexture", "GetDisabledTexture" }) do
		local texture = button[method] and button[method](button)
		if texture then
			texture:SetAlpha(0)
		end
	end

	button.foreverNormal = ForeverUI.CreateNineSlice(button, TERTIARY_NORMAL,
		TERTIARY_CORNER, TERTIARY_MARGINS, "BACKGROUND")
	button.foreverPressed = ForeverUI.CreateNineSlice(button, TERTIARY_PRESSED,
		TERTIARY_CORNER, TERTIARY_MARGINS, "BACKGROUND")

	button.foreverPress = function(state)
		for _, slice in ipairs(button.foreverPressed or {}) do
			if state then slice:Show() else slice:Hide() end
		end
		for _, slice in ipairs(button.foreverNormal or {}) do
			if state then slice:Hide() else slice:Show() end
		end
	end
	button.foreverPress(false)

	if auto then
		button:HookScript("OnMouseDown", function() button.foreverPress(true) end)
		button:HookScript("OnMouseUp", function() button.foreverPress(false) end)
	end

	return button
end

-- Camelot inset: InsetFrameTemplate (shareduipaneltemplates.xml, nineslicelayouts.lua).
-- Tiled UI-Background-Marble background; UI-Frame-InnerTopLeft / TopRight / BotLeftCorner /
-- BotRight corners (6 x 6, bottom ones at y = -1) joined by _UI-Frame-InnerTopTile / BotTile
-- and !UI-Frame-InnerLeftTile / RightTile (3 thick).
local MARBLE = "interface" .. string.char(92) .. "ForeverUI" .. string.char(92)
	.. "framegeneral" .. string.char(92) .. "ui-background-marble"

function ForeverUI.CreateInset(parent, name)
	return ForeverUI.DecorateInset(CreateFrame("Frame", name, parent))
end

-- Same art on an existing frame (e.g. the bank rights frame of the guild control window):
-- regions of its own, below its child frames.
function ForeverUI.DecorateInset(e)
	local background = e:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(MARBLE, true)
	if background.SetHorizTile then
		background:SetHorizTile(true)
		background:SetVertTile(true)
	end
	background:SetAllPoints(e)
	e.background = background

	local function corner(atlas, point, y)
		local t = e:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, atlas)
		t:SetPoint(point, e, point, 0, y or 0)
		return t
	end
	local topLeft = corner("ui-frame-innertopleft", "TOPLEFT")
	local topRight = corner("ui-frame-innertopright", "TOPRIGHT")
	local bottomLeft = corner("ui-frame-innerbotleftcorner", "BOTTOMLEFT", -1)
	local bottomRight = corner("ui-frame-innerbotright", "BOTTOMRIGHT", -1)
	-- thickness from the element (3), length from the corners
	local function edge(atlas, a1, c1, r1, a2, c2, r2)
		local t = e:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
		return t
	end
	local top = edge("_ui-frame-innertoptile", "TOPLEFT", topLeft, "TOPRIGHT", "TOPRIGHT", topRight, "TOPLEFT")
	top:SetHeight(3)
	local down = edge("_ui-frame-innerbottile", "BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")
	down:SetHeight(3)
	local left = edge("!ui-frame-innerlefttile", "TOPLEFT", topLeft, "BOTTOMLEFT", "BOTTOMLEFT", bottomLeft, "TOPLEFT")
	left:SetWidth(3)
	local right = edge("!ui-frame-innerrighttile", "TOPRIGHT", topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "TOPRIGHT")
	right:SetWidth(3)
	e.trim = { topLeft, topRight, bottomLeft, bottomRight, top, down, left, right }
	return e
end

-- Camelot panel button, UIPanelButtonTemplate: three pieces of UI-Panel-Button-Up / -Down /
-- -Disabled (left 12, stretched middle, right 12; 0.6875 high), -Highlight in ADD.
-- b:Activate(yes): UIPanelButton_OnEnable / _OnDisable, -Disabled image and grey font.
-- font: font object name (GameFontNormalSmall by default); template: optional frame template.
local PANEL_BUTTON = "Interface" .. string.char(92) .. "Buttons" .. string.char(92) .. "UI-Panel-Button-"

function ForeverUI.CreatePanelButton(parent, buttonText, width, height, name, font, template)
	local b = CreateFrame("Button", name, parent, template)
	b:SetWidth(width)
	b:SetHeight(height)
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
	local pieces = { g, m, d }
	local function state(suffix)
		for _, t in ipairs(pieces) do
			t:SetTexture(PANEL_BUTTON .. suffix)
		end
	end
	state("Up")
	local normalFont = font and _G[font .. ""] or GameFontNormalSmall
	local hover = font and _G[(font == "GameFontNormal") and "GameFontHighlight" or "GameFontHighlightSmall"]
		or GameFontHighlightSmall
	local fs = b:CreateFontString(nil, "ARTWORK")
	fs:SetFontObject(normalFont)
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetFontString(fs)
	b:SetNormalFontObject(normalFont)
	b:SetHighlightFontObject(hover)
	if b.SetDisabledFontObject then
		b:SetDisabledFontObject((font == "GameFontNormal") and GameFontDisable or GameFontDisableSmall)
	end
	b:SetText(buttonText)
	b:SetHighlightTexture(PANEL_BUTTON .. "Highlight")
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
