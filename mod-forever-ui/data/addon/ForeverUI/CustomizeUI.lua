-- ForeverUI: Customize UI, the edit mode (camelot EditModeManagerFrame, blizzard_editmode).
-- A grid over the screen, every movable element under a blue veil (the edit mode highlight),
-- and a window for the grid (spacing, origin), snapping, and the session: Cancel restores the
-- layout found on opening, Reset goes back to the defaults, Validate saves.
-- A click selects an element (edit mode selected frame): nine handles on its box, each one
-- the reference while it is dragged, and a window beside it for its size in percent.
-- Opened from the Esc menu (after AddOns, as in camelot) or with /fui.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Layout = ForeverUI.Layout
local Tpl = ForeverUI.Templates
local L = ForeverUI.L

local C = {}
ForeverUI.CustomizeUI = C

-- Numbers kept in a table: Lua 5.1 allows at most 60 upvalues per function.
local N = {
	width = 510, height = 262, top = -100,     -- EditModeManagerFrame: fixedWidth 510, TOP (0, -100)
	title = -15,
	labelX = 25,
	column = 170, columnGap = 30,              -- controls column: after the widest label
	rowY = -68,                                -- center of the grid spacing row
	slider = { right = 440, height = 17, stepperGap = 4 },
	valueGap = 25,                             -- MinimalSliderWithSteppers RightText
	originTop = -90, box = { 108, 66 }, radio = 16, radioInset = 4, originNameGap = 12,
	checkTop = -172, check = 32, checkLabel = 5, secondColumn = 255,
	button = { 150, 28 }, buttonX = 15, buttonY = 16,
	grid = { min = 20, max = 300, step = 10 },  -- Constants.EditModeConsts
	line = { 1, 1, 1, 0.247 },                 -- GlobalColor EDIT_MODE_GRID_LINE_COLOR
	originLine = { 0.784, 0.271, 0.980, 0.498 }, -- EDIT_MODE_GRID_CENTER_LINE_COLOR
	veilCorner = 8,                            -- EditModeSystemSelectionLayout: corners 8 outside
	-- Veils above every element, the client's HIGH frames included (BonusActionBarFrame and
	-- its buttons); the windows above the veils.
	veilStrata = "DIALOG", windowStrata = "FULLSCREEN",
	magnet = 8,                                -- attraction range, UIParent units
	dragStart = 1,                             -- cursor travel before a click becomes a drag
	handle = 16, handleLevel = 100,
	size = {                                   -- size window (EditModeSystemSettingsDialog look)
		width = 260, height = 96, titleInset = 30, rowY = -58,
		field = { 40, 20 }, fieldGap = 14, percentGap = 6,
		gap = 12,                              -- from the element
		min = 50, max = 200,
	},
}

-- The nine grid origins: anchor, screen fractions (x from the left, y from the bottom), name.
local ORIGINS = {
	{ "TOPLEFT", 0, 1, L.CUSTOMIZEUI_ORIGIN_TOPLEFT },
	{ "TOP", 0.5, 1, L.CUSTOMIZEUI_ORIGIN_TOP },
	{ "TOPRIGHT", 1, 1, L.CUSTOMIZEUI_ORIGIN_TOPRIGHT },
	{ "LEFT", 0, 0.5, L.CUSTOMIZEUI_ORIGIN_LEFT },
	{ "CENTER", 0.5, 0.5, L.CUSTOMIZEUI_ORIGIN_CENTER },
	{ "RIGHT", 1, 0.5, L.CUSTOMIZEUI_ORIGIN_RIGHT },
	{ "BOTTOMLEFT", 0, 0, L.CUSTOMIZEUI_ORIGIN_BOTTOMLEFT },
	{ "BOTTOM", 0.5, 0, L.CUSTOMIZEUI_ORIGIN_BOTTOM },
	{ "BOTTOMRIGHT", 1, 0, L.CUSTOMIZEUI_ORIGIN_BOTTOMRIGHT },
}
local ORIGIN_BY_KEY = {}
for _, o in ipairs(ORIGINS) do
	ORIGIN_BY_KEY[o[1]] = o
end

local DEFAULTS = { spacing = 100, origin = "CENTER", snap = true, sticky = true }

-- Saved grid settings, completed with the defaults.
local function saved()
	ForeverUIDB = ForeverUIDB or {}
	if type(ForeverUIDB.customize) ~= "table" then
		ForeverUIDB.customize = {}
	end
	local s = ForeverUIDB.customize
	for k, v in pairs(DEFAULTS) do
		if s[k] == nil then
			s[k] = v
		end
	end
	return s
end

-- The session's working copy of the grid settings (saved on Validate).
C.settings = {}

-- ------------------------------------------------------------ Grid

local grid = CreateFrame("Frame", "ForeverUICustomizeGrid", UIParent)
grid:SetAllPoints(UIParent)
grid:SetFrameStrata("BACKGROUND")
grid:Hide()
local lines = {}

-- Size of one screen pixel in UIParent units: the lines stay one pixel thick.
local function pixel()
	local height = tonumber(string.match(GetCVar("gxResolution") or "", "%d+x(%d+)"))
	if not height or height <= 0 then
		return 1
	end
	return UIParent:GetHeight() / height
end

-- Draws a line through the origin at every spacing step, the origin lines in violet.
function C.DrawGrid()
	local s = C.settings
	local width, height = grid:GetWidth(), grid:GetHeight()
	local o = ORIGIN_BY_KEY[s.origin] or ORIGIN_BY_KEY.CENTER
	local ox, oy = width * o[2], height * o[3]
	local px = pixel()
	local n = 0
	-- on whole pixels, or a line would blur over two
	local function snap(v)
		return math.floor(v / px + 0.5) * px
	end
	-- vertical: along x, else along y; position from the left or the bottom
	local function line(vertical, position, isOrigin)
		n = n + 1
		local t = lines[n]
		if not t then
			t = grid:CreateTexture(nil, "BACKGROUND")
			lines[n] = t
		end
		local c = isOrigin and N.originLine or N.line
		t:SetTexture(c[1], c[2], c[3], c[4])
		t:ClearAllPoints()
		if vertical then
			local x = snap(math.min(math.max(position - px / 2, 0), width - px))
			t:SetPoint("TOPLEFT", grid, "TOPLEFT", x, 0)
			t:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", x, 0)
			t:SetWidth(px)
		else
			local y = snap(math.min(math.max(position - px / 2, 0), height - px))
			t:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 0, y)
			t:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, y)
			t:SetHeight(px)
		end
		t:Show()
	end
	local step = s.spacing
	for k = math.ceil(-ox / step), math.floor((width - ox) / step) do
		line(true, ox + k * step, k == 0)
	end
	for k = math.ceil(-oy / step), math.floor((height - oy) / step) do
		line(false, oy + k * step, k == 0)
	end
	for i = n + 1, #lines do
		lines[i]:Hide()
	end
end

grid:RegisterEvent("DISPLAY_SIZE_CHANGED")
grid:RegisterEvent("UI_SCALE_CHANGED")
grid:SetScript("OnEvent", function(self)
	if self:IsShown() then
		C.DrawGrid()
	end
end)
C.grid = grid

-- ------------------------------------------------------------ Geometry

-- Fractions of a box for an anchor point: x from the left, y from the bottom.
local function fractions(point)
	local fx = (string.find(point, "LEFT") and 0) or (string.find(point, "RIGHT") and 1) or 0.5
	local fy = (string.find(point, "BOTTOM") and 0) or (string.find(point, "TOP") and 1) or 0.5
	return fx, fy
end

-- Box of a frame in UIParent units { left, bottom, width, height }; nil before layout.
local function box(frame)
	local l, b = frame:GetLeft(), frame:GetBottom()
	if not l or not b then
		return nil
	end
	local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return { l * k, b * k, frame:GetWidth() * k, frame:GetHeight() * k }
end

-- ------------------------------------------------------------ Veils

-- The edit mode selection (EditModeSystemSelectionLayout): one corner image mirrored four
-- times, centered on the element's corners, edges between them, and the center reaching the
-- corners' middle. Corners: point, side (x, y), flipX, flipY.
local CORNERS = {
	{ "TOPLEFT", -1, 1, false, false }, { "TOPRIGHT", 1, 1, true, false },
	{ "BOTTOMLEFT", -1, -1, false, true }, { "BOTTOMRIGHT", 1, -1, true, true },
}

-- Paints the pieces with a texture kit: "highlight" (the blue veil) or "selected".
local function paint(pieces, kit)
	local base = "editmode-actionbar-" .. kit .. "-nineslice"
	local e = ForeverUI.AtlasEntry(base .. "-corner")
	for i, c in ipairs(CORNERS) do
		local t = pieces.corners[i]
		local l, r, top, bottom = e[2], e[3], e[4], e[5]
		if c[4] then l, r = r, l end
		if c[5] then top, bottom = bottom, top end
		t:SetTexture(e[1])
		t:SetTexCoord(l, r, top, bottom)
		t:SetWidth(e[6])
		t:SetHeight(e[7])
	end
	ForeverUI.SetAtlas(pieces.top, "_" .. base .. "-edgetop", true)
	ForeverUI.SetAtlas(pieces.bottom, "_" .. base .. "-edgebottom", true)
	ForeverUI.SetAtlas(pieces.left, "!" .. base .. "-edgeleft", true)
	ForeverUI.SetAtlas(pieces.right, "!" .. base .. "-edgeright", true)
	ForeverUI.SetAtlas(pieces.center, base .. "-center", true)
end

-- Builds the pieces on host, the frame they are drawn on.
local function selection(host)
	local k = N.veilCorner
	local p = { corners = {} }
	for i, c in ipairs(CORNERS) do
		local t = host:CreateTexture(nil, "BORDER")
		t:SetPoint(c[1], host, c[1], c[2] * k, c[3] * k)
		p.corners[i] = t
	end
	local tl, tr, bl, br = p.corners[1], p.corners[2], p.corners[3], p.corners[4]
	-- from, to: the two corners the edge spans; the anchors pick the facing sides
	local function edge(from, fromPoint, to, toPoint)
		local t = host:CreateTexture(nil, "BORDER")
		t:SetPoint("TOPLEFT", from, fromPoint)
		t:SetPoint("BOTTOMRIGHT", to, toPoint)
		return t
	end
	p.top = edge(tl, "TOPRIGHT", tr, "BOTTOMLEFT")
	p.bottom = edge(bl, "TOPRIGHT", br, "BOTTOMLEFT")
	p.left = edge(tl, "BOTTOMLEFT", bl, "TOPRIGHT")
	p.right = edge(tr, "BOTTOMLEFT", br, "TOPRIGHT")
	p.center = host:CreateTexture(nil, "BACKGROUND")
	p.center:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT", -k, k)
	p.center:SetPoint("BOTTOMRIGHT", br, "TOPLEFT", k, -k)
	return p
end

local veils = {}

-- The label fits the element: large font, smaller ones when it does not fit.
local function fitLabel(veil)
	for _, font in ipairs({ GameFontHighlightLarge, GameFontHighlight, GameFontHighlightSmall }) do
		veil.label:SetFontObject(font)
		if veil.label:GetStringWidth() <= veil:GetWidth() then
			return
		end
	end
end

-- The veil keeps the screen's scale whatever the element's size: its frame, label and
-- handles do not grow with the element.
local function unscale(veil)
	veil:SetScale(UIParent:GetEffectiveScale() / veil:GetParent():GetEffectiveScale())
	fitLabel(veil)
end

-- Veil over one element: a click selects it, a drag moves it.
local function buildVeil(id, system)
	local veil = CreateFrame("Frame", nil, system.frame)
	veil:SetAllPoints(system.frame)
	veil:SetFrameStrata(N.veilStrata)
	veil:EnableMouse(true)
	veil.pieces = selection(veil)
	paint(veil.pieces, "highlight")
	veil.label = veil:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	veil.label:SetPoint("CENTER", veil, "CENTER", 0, 0)
	veil.label:SetText(system.label)
	veil:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			C.Select(id)
			C.BeginDrag(id)
		end
	end)
	veil:SetScript("OnMouseUp", function()
		C.EndDrag()
	end)
	veil:SetScript("OnSizeChanged", fitLabel)
	veils[id] = veil
	return veil
end

local function showVeil(id)
	local system = Layout.systems[id]
	if not system then
		return
	end
	local veil = veils[id] or buildVeil(id, system)
	veil:Show()
	unscale(veil)
end
C.veils = veils

-- ------------------------------------------------------------ Moving

-- Drag in progress: { id, point (held point), fx, fy, box (at the start), cursorX, cursorY,
-- moved, left, bottom (where the box is now) }
local drag = CreateFrame("Frame")
drag:Hide()
C.drag = drag

-- The smallest shift within the magnet range. best: best shift so far, or nil; shift: candidate
local function closer(best, shift)
	if math.abs(shift) <= N.magnet and (not best or math.abs(shift) < math.abs(best)) then
		return shift
	end
	return best
end

-- Shifts along one axis that stick an edge or the middle of the moved box to another box.
-- from, size: the moved box on that axis; otherFrom, otherSize: the other box
local function stickShifts(from, size, otherFrom, otherSize)
	local otherTo = otherFrom + otherSize
	return {
		otherFrom - from, otherTo - from, otherFrom - (from + size), otherTo - (from + size),
		otherFrom + otherSize / 2 - (from + size / 2),
	}
end

-- Where the box goes once attracted: Snap on Grid pulls the held point onto a grid line near
-- it, Sticky UI pulls an edge onto an edge of another element near it (facing it).
local function attract(d, left, bottom)
	local s = C.settings
	local w, h = d.box[3], d.box[4]
	local sx, sy
	if s.snap then
		local o = ORIGIN_BY_KEY[s.origin]
		local ox, oy = grid:GetWidth() * o[2], grid:GetHeight() * o[3]
		local x, y = left + d.fx * w, bottom + d.fy * h
		sx = closer(sx, ox + math.floor((x - ox) / s.spacing + 0.5) * s.spacing - x)
		sy = closer(sy, oy + math.floor((y - oy) / s.spacing + 0.5) * s.spacing - y)
	end
	if s.sticky then
		local m = N.magnet
		for id, system in pairs(Layout.systems) do
			local o = id ~= d.id and system.frame:IsVisible() and box(system.frame)
			if o then
				if bottom <= o[2] + o[4] + m and bottom + h >= o[2] - m then
					for _, shift in ipairs(stickShifts(left, w, o[1], o[3])) do
						sx = closer(sx, shift)
					end
				end
				if left <= o[1] + o[3] + m and left + w >= o[1] - m then
					for _, shift in ipairs(stickShifts(bottom, h, o[2], o[4])) do
						sy = closer(sy, shift)
					end
				end
			end
		end
	end
	return left + (sx or 0), bottom + (sy or 0)
end

-- Puts the dragged box at left, bottom (UIParent units), attracted and kept on screen; the
-- held point anchors the element meanwhile.
local function place(d, left, bottom)
	local w, h = d.box[3], d.box[4]
	left, bottom = attract(d, left, bottom)
	left = math.max(0, math.min(left, UIParent:GetWidth() - w))
	bottom = math.max(0, math.min(bottom, UIParent:GetHeight() - h))
	d.left, d.bottom = left, bottom
	local frame = Layout.systems[d.id].frame
	local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	frame:ClearAllPoints()
	frame:SetPoint(d.point, UIParent, "BOTTOMLEFT", (left + d.fx * w) / k, (bottom + d.fy * h) / k)
end

drag:SetScript("OnUpdate", function(self)
	local d = self.state
	local ui = UIParent:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	local dx, dy = cx / ui - d.cursorX, cy / ui - d.cursorY
	if not d.moved and math.abs(dx) + math.abs(dy) < N.dragStart then
		return
	end
	d.moved = true
	place(d, d.box[1] + dx, d.box[2] + dy)
end)

-- Starts moving an element. point: the held handle; nil for the body, whose reference is
-- the element's anchor.
function C.BeginDrag(id, point)
	local system = Layout.systems[id]
	local b = system and box(system.frame)
	if not b then
		return
	end
	point = point or Layout.Anchor(id).point
	local fx, fy = fractions(point)
	local ui = UIParent:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	drag.state = { id = id, point = point, fx = fx, fy = fy, box = b, cursorX = cx / ui, cursorY = cy / ui }
	drag:Show()
end

-- Ends the move: the element gets its own anchor back, at the new place. A click without
-- moving only selects.
function C.EndDrag()
	local d = drag.state
	drag:Hide()
	drag.state = nil
	if not (d and d.moved) then
		return
	end
	local anchor = Layout.Anchor(d.id)
	local ax, ay = fractions(anchor.point)
	local rx, ry = fractions(anchor.relativePoint)
	Layout.SetPosition(d.id, d.left + ax * d.box[3] - rx * UIParent:GetWidth(),
		d.bottom + ay * d.box[4] - ry * UIParent:GetHeight())
	C.PlaceSizeWindow()
end

-- ------------------------------------------------------------ Selection

-- The nine handles, on the selected element only.
local HANDLES = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local handles = {}
C.handles = handles

-- Handle image: gold edged while hovered or held.
local function paintHandle(h)
	local state = (h.hover or h.held) and "active" or "default"
	ForeverUI.SetAtlas(h.texture, "housing-advancedmode-scale-handle-" .. state, true)
end

local function buildHandles()
	for _, point in ipairs(HANDLES) do
		local h = CreateFrame("Frame", nil, UIParent)
		h:SetWidth(N.handle)
		h:SetHeight(N.handle)
		h:EnableMouse(true)
		h:Hide()
		h.texture = h:CreateTexture(nil, "OVERLAY")
		h.texture:SetAllPoints(h)
		paintHandle(h)
		h:SetScript("OnEnter", function(self)
			self.hover = true
			paintHandle(self)
		end)
		h:SetScript("OnLeave", function(self)
			self.hover = false
			paintHandle(self)
		end)
		h:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" and C.selected then
				self.held = true
				paintHandle(self)
				C.BeginDrag(C.selected, point)
			end
		end)
		h:SetScript("OnMouseUp", function(self)
			self.held = false
			paintHandle(self)
			C.EndDrag()
		end)
		handles[point] = h
	end
end

local sizeWindow

-- Size in effect of the selected element, in percent.
local function selectedPercent()
	return math.floor(Layout.Scale(C.selected) * 100 + 0.5)
end

-- Selects an element: selected frame, handles on its box, size window beside it.
function C.Select(id)
	local veil = veils[id]
	if C.selected == id or not veil then
		return
	end
	C.Deselect()
	C.selected = id
	paint(veil.pieces, "selected")
	for point, h in pairs(handles) do
		h:SetParent(veil)
		h:SetFrameStrata(N.veilStrata)
		h:SetFrameLevel(N.handleLevel)
		h:ClearAllPoints()
		h:SetPoint("CENTER", veil, point, 0, 0)
		h:Show()
	end
	sizeWindow.title:SetText(Layout.systems[id].label)
	sizeWindow.field:SetText(tostring(selectedPercent()))
	sizeWindow:Show()
	C.PlaceSizeWindow()
end

function C.Deselect()
	local veil = C.selected and veils[C.selected]
	if veil then
		paint(veil.pieces, "highlight")
	end
	for _, h in pairs(handles) do
		h:Hide()
	end
	if sizeWindow then
		sizeWindow.field:ClearFocus()
		sizeWindow:Hide()
	end
	C.selected = nil
end

-- The size window beside the selected element: on its right, or its left when the screen
-- ends, level with its top.
function C.PlaceSizeWindow()
	local id = C.selected
	if not (id and sizeWindow) then
		return
	end
	local b = box(Layout.systems[id].frame)
	sizeWindow:ClearAllPoints()
	if not b then
		sizeWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		return
	end
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	local w, h = sizeWindow:GetWidth(), sizeWindow:GetHeight()
	local x = b[1] + b[3] + N.size.gap
	if x + w > width then
		x = math.max(0, math.min(b[1] - N.size.gap - w, width - w))
	end
	local top = math.max(h, math.min(height, b[2] + b[4]))
	sizeWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
end

-- Resizes the selected element; percent: typed value, kept between 50 and 200.
-- Returns the size applied.
function C.SetSize(percent)
	local id = C.selected
	if not id then
		return nil
	end
	percent = math.max(N.size.min, math.min(N.size.max, math.floor(percent + 0.5)))
	Layout.SetScale(id, percent / 100)
	unscale(veils[id])
	C.PlaceSizeWindow()
	return percent
end

-- ------------------------------------------------------------ Window

local window
local controls = {}

-- Row label; y: center of the row. Returns its width.
local function rowLabel(f, text, y)
	local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
	label:SetPoint("LEFT", f, "TOPLEFT", N.labelX, y)
	label:SetText(text)
	return label:GetStringWidth()
end

-- Slider with steppers (MinimalSliderWithSteppersTemplate) for the grid spacing.
-- column: left edge of the slider
local function buildSpacing(f, column)
	local S = N.slider
	local slider = CreateFrame("Slider", "ForeverUICustomizeSpacing", f)
	slider:SetOrientation("HORIZONTAL")
	slider:SetWidth(S.right - column)
	slider:SetHeight(S.height)
	slider:SetPoint("LEFT", f, "TOPLEFT", column, N.rowY)
	slider:SetMinMaxValues(N.grid.min, N.grid.max)
	slider:SetValueStep(N.grid.step)
	slider:EnableMouse(true)
	ForeverUI.Settings.Cursor(slider)

	-- atlas: stepper image; point, relativePoint, x: placement beside the slider;
	-- delta: value change per click
	local function stepper(atlas, point, relativePoint, x, delta)
		local b = CreateFrame("Button", nil, f)
		local t = b:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, atlas)
		b:SetWidth(t:GetWidth())
		b:SetHeight(t:GetHeight())
		t:SetAllPoints(b)
		b:SetPoint(point, slider, relativePoint, x, 0)
		b:SetScript("OnClick", function()
			slider:SetValue(slider:GetValue() + delta)
		end)
	end
	stepper("minimal_sliderbar_button_left", "RIGHT", "LEFT", -S.stepperGap, -N.grid.step)
	stepper("minimal_sliderbar_button_right", "LEFT", "RIGHT", S.stepperGap, N.grid.step)

	local value = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	value:SetPoint("LEFT", slider, "RIGHT", N.valueGap, 0)
	slider:SetScript("OnValueChanged", function(self, v)
		local step = N.grid.step
		v = math.floor(v / step + 0.5) * step
		value:SetText(tostring(v))
		if C.settings.spacing ~= v then
			C.settings.spacing = v
			C.DrawGrid()
		end
	end)
	controls.spacing = slider
	controls.spacingValue = value
end

-- Nine radio buttons placed like the screen: the grid origin. column: left edge of the box
local function buildOrigin(f, column)
	local box = CreateFrame("Frame", nil, f)
	box:SetWidth(N.box[1])
	box:SetHeight(N.box[2])
	box:SetPoint("TOPLEFT", f, "TOPLEFT", column, N.originTop)
	Tpl.Inset(box)

	local name = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	name:SetPoint("LEFT", box, "RIGHT", N.originNameGap, 0)
	controls.originName = name

	controls.origins = {}
	for _, o in ipairs(ORIGINS) do
		local key = o[1]
		local r = CreateFrame("CheckButton", nil, box)
		r:SetWidth(N.radio)
		r:SetHeight(N.radio)
		local dx = (o[2] == 0 and N.radioInset) or (o[2] == 1 and -N.radioInset) or 0
		local dy = (o[3] == 0 and N.radioInset) or (o[3] == 1 and -N.radioInset) or 0
		r:SetPoint(key, box, key, dx, dy)
		-- set, get: the button's texture setter and getter; atlas: the image
		local function state(set, get, atlas)
			r[set](r, ForeverUI.AtlasEntry(atlas)[1])
			local t = r[get](r)
			ForeverUI.SetAtlas(t, atlas, true)
			t:ClearAllPoints()
			t:SetAllPoints(r)
		end
		state("SetNormalTexture", "GetNormalTexture", "common-radiobutton-circle")
		state("SetCheckedTexture", "GetCheckedTexture", "common-radiobutton-dot")
		r:SetScript("OnClick", function()
			C.SetOrigin(key)
		end)
		r:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(o[4])
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		controls.origins[key] = r
	end
end

-- EditModeCheckButtonTemplate: 32 x 32 UI-CheckBox, label 5 px right of it.
-- x: left position; text: label; key: setting it toggles
local function checkButton(f, x, text, key)
	local SEP = string.char(92)
	local b = CreateFrame("CheckButton", nil, f)
	b:SetWidth(N.check)
	b:SetHeight(N.check)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", x, N.checkTop)
	local path = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-"
	b:SetNormalTexture(path .. "Up")
	b:SetPushedTexture(path .. "Down")
	b:SetHighlightTexture(path .. "Highlight", "ADD")
	b:SetCheckedTexture(path .. "Check")
	b:SetDisabledCheckedTexture(path .. "Check-Disabled")
	local label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
	label:SetPoint("LEFT", b, "RIGHT", N.checkLabel, 0)
	label:SetText(text)
	b:SetScript("OnClick", function(self)
		C.settings[key] = Tpl.Truthy(self:GetChecked())
	end)
	return b
end

local function buildButtons(f)
	local B = N.button
	local cancel = ForeverUI.CreatePanelButton(f, CANCEL, B[1], B[2], "ForeverUICustomizeCancel", "GameFontNormal")
	cancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", N.buttonX, N.buttonY)
	cancel:SetScript("OnClick", function() C.Cancel() end)
	local reset = ForeverUI.CreatePanelButton(f, RESET, B[1], B[2], "ForeverUICustomizeReset", "GameFontNormal")
	reset:SetPoint("BOTTOM", f, "BOTTOM", 0, N.buttonY)
	reset:SetScript("OnClick", function() StaticPopup_Show("FOREVERUI_CUSTOMIZE_RESET") end)
	local validate = ForeverUI.CreatePanelButton(f, L.CUSTOMIZEUI_VALIDATE, B[1], B[2],
		"ForeverUICustomizeValidate", "GameFontNormal")
	validate:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -N.buttonX, N.buttonY)
	validate:SetScript("OnClick", function() C.Validate() end)
end

-- DialogBorderTranslucentTemplate: Dialog border, black 0.8 inside 7 px from the edge
local function dialogBackground(f)
	local background = f:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(0, 0, 0, 0.8)
	background:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -7)
	background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -7, 7)
	Tpl.NineSlice(f, "Dialog")
end

-- Numeric field in the InputBoxTemplate border (Common-Input-Border: 8 wide ends, stretched
-- middle, 20 high, the left end 5 out). Enter applies the typed size; leaving the field shows
-- the size in effect again.
local function sizeField(f)
	local SEP = string.char(92)
	local field = CreateFrame("EditBox", "ForeverUICustomizeSizeField", f)
	field:SetWidth(N.size.field[1])
	field:SetHeight(N.size.field[2])
	field:SetAutoFocus(false)
	field:SetNumeric(true)
	field:SetMaxLetters(3)
	field:SetFontObject(ChatFontNormal)
	field:SetJustifyH("CENTER")
	local border = "Interface" .. SEP .. "Common" .. SEP .. "Common-Input-Border"
	-- u1, u2: part of the border image; point: where it holds on the field
	local function piece(u1, u2, point, x)
		local t = field:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(border)
		t:SetTexCoord(u1, u2, 0, 0.625)
		t:SetHeight(20)
		if point then
			t:SetWidth(8)
			t:SetPoint(point, field, point, x, 0)
		end
		return t
	end
	local left = piece(0, 0.0625, "LEFT", -5)
	local right = piece(0.9375, 1, "RIGHT", 0)
	local middle = piece(0.0625, 0.9375)
	middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
	middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
	field:SetScript("OnEnterPressed", function(self)
		local percent = tonumber(self:GetText())
		if percent then
			C.SetSize(percent)
		end
		self:ClearFocus()
	end)
	field:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	field:SetScript("OnEditFocusLost", function(self)
		if C.selected then
			self:SetText(tostring(selectedPercent()))
		end
	end)
	return field
end

-- The selected element's window: its name, and its size in percent.
local function buildSizeWindow()
	local S = N.size
	local f = CreateFrame("Frame", "ForeverUICustomizeSize", UIParent)
	f:SetWidth(S.width)
	f:SetHeight(S.height)
	f:SetFrameStrata(N.windowStrata)
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:Hide()
	dialogBackground(f)
	f.title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	f.title:SetPoint("TOP", f, "TOP", 0, N.title)
	f.title:SetWidth(S.width - 2 * S.titleInset)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	Tpl.CloseButton(close, f)
	close:SetScript("OnClick", function() C.Deselect() end)
	local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
	label:SetPoint("LEFT", f, "TOPLEFT", N.labelX, S.rowY)
	label:SetText(L.CUSTOMIZEUI_SIZE)
	f.field = sizeField(f)
	f.field:SetPoint("LEFT", label, "RIGHT", S.fieldGap, 0)
	local percent = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	percent:SetPoint("LEFT", f.field, "RIGHT", S.percentGap, 0)
	percent:SetText(L.CUSTOMIZEUI_PERCENT)
	sizeWindow = f
	C.sizeWindow = f
end

local function build()
	if window then
		return window
	end
	local f = CreateFrame("Frame", "ForeverUICustomizeUI", UIParent)
	f:SetWidth(N.width)
	f:SetHeight(N.height)
	f:SetPoint("TOP", UIParent, "TOP", 0, N.top)
	f:SetFrameStrata(N.windowStrata)
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	dialogBackground(f)

	local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	title:SetPoint("TOP", f, "TOP", 0, N.title)
	title:SetText(L.CUSTOMIZEUI_TITLE)

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	Tpl.CloseButton(close, f)
	close:SetScript("OnClick", function() C.Cancel() end)

	-- the controls start after the widest label (French ones are longer)
	local widest = math.max(rowLabel(f, L.CUSTOMIZEUI_GRID_SPACING, N.rowY),
		rowLabel(f, L.CUSTOMIZEUI_GRID_ORIGIN, N.originTop - N.box[2] / 2))
	local column = math.max(N.column, N.labelX + widest + N.columnGap)
	buildSpacing(f, column)
	buildOrigin(f, column)
	controls.snap = checkButton(f, N.labelX - 5, L.CUSTOMIZEUI_SNAP, "snap")
	controls.sticky = checkButton(f, N.secondColumn, L.CUSTOMIZEUI_STICKY, "sticky")
	buildButtons(f)

	-- Esc and any other hide without Validate cancel the session.
	f:SetScript("OnHide", function()
		if C.active then
			C.Cancel()
		end
	end)
	table.insert(UISpecialFrames, "ForeverUICustomizeUI")
	buildSizeWindow()
	buildHandles()
	window = f
	C.window = f
	C.controls = controls
	return f
end

-- Shows the working settings in the window.
local function refreshControls()
	local s = C.settings
	controls.spacing:SetValue(s.spacing)
	controls.spacingValue:SetText(tostring(s.spacing))
	for key, r in pairs(controls.origins) do
		r:SetChecked(key == s.origin)
	end
	controls.originName:SetText(ORIGIN_BY_KEY[s.origin][4])
	controls.snap:SetChecked(s.snap)
	controls.sticky:SetChecked(s.sticky)
end

-- ------------------------------------------------------------ Session

function C.SetOrigin(key)
	if not ORIGIN_BY_KEY[key] then
		return
	end
	C.settings.origin = key
	refreshControls()
	C.DrawGrid()
end

function C.Open()
	if C.active then
		return
	end
	if InCombatLockdown() then
		Layout.Say(L.LAYOUT_EDIT_MODE_COMBAT)
		return
	end
	build()
	local s = saved()
	C.settings = { spacing = s.spacing, origin = s.origin, snap = s.snap, sticky = s.sticky }
	Layout.BeginEdit()
	C.active = true
	grid:Show()
	C.DrawGrid()
	for _, id in ipairs(Layout.order) do
		showVeil(id)
	end
	window:Show()
	refreshControls()
end

local function close()
	C.active = false
	drag:Hide()
	drag.state = nil
	C.Deselect()
	grid:Hide()
	for _, veil in pairs(veils) do
		veil:Hide()
	end
	if window then
		window:Hide()
	end
end

-- Saves the layout and the grid settings, then closes.
function C.Validate()
	if not C.active then
		return
	end
	local s = saved()
	for k in pairs(DEFAULTS) do
		s[k] = C.settings[k]
	end
	Layout.Commit()
	close()
end

-- Puts every element back where it was on opening, then closes.
function C.Cancel()
	if not C.active then
		return
	end
	Layout.Revert()
	close()
end

-- Every element back to its default position and size; the session stays open.
function C.Reset()
	if not C.active then
		return
	end
	Layout.Reset()
	for _, veil in pairs(veils) do
		if veil:IsShown() then
			unscale(veil)
		end
	end
	if C.selected then
		sizeWindow.field:SetText(tostring(selectedPercent()))
		C.PlaceSizeWindow()
	end
end

function C.Toggle()
	if C.active then
		C.Cancel()
	else
		C.Open()
	end
end

Layout.onRegister = showVeil

StaticPopupDialogs["FOREVERUI_CUSTOMIZE_RESET"] = {
	text = L.CUSTOMIZEUI_RESET_CONFIRM,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function() C.Reset() end,
	-- the client's popups sit below our windows: raised above them while shown
	OnShow = function(self)
		C.popupStrata = self:GetFrameStrata()
		self:SetFrameStrata("FULLSCREEN_DIALOG")
	end,
	OnHide = function(self)
		self:SetFrameStrata(C.popupStrata or "DIALOG")
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

-- Secure frames cannot move in combat: entering combat cancels the session (the event comes
-- before the lockdown, so the elements can still go back).
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:SetScript("OnEvent", function()
	if C.active then
		C.Cancel()
		Layout.Say(L.LAYOUT_EDIT_MODE_COMBAT)
	end
end)

-- Esc menu button, after AddOns (camelot GameMenuFrame: Edit Mode); GameMenu.lua places it.
if GameMenuFrame then
	local b = CreateFrame("Button", "ForeverUIGameMenuButtonCustomize", GameMenuFrame, "GameMenuButtonTemplate")
	b:SetText(L.CUSTOMIZEUI_MENU_BUTTON)
	b:SetScript("OnClick", function()
		PlaySound("igMainMenuOption")
		HideUIPanel(GameMenuFrame)
		C.Open()
	end)
	ForeverUI.GameMenu.Layout()
end
