-- ForeverUI: the barber shop (BarberShopFrame, load-on-demand Blizzard_BarbershopUI) in
-- Camelot's full-screen layout (BarberShopFrame over CharCustomizeFrame, numbers as in
-- character creation). Settings and actions stay those of 3.3.5. The price stays shown above
-- Accept (Camelot hides it). No body, random or camera buttons: 3.3.5 gives none to Lua.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local C = {}
ForeverUI.Barber = C

local SEP = string.char(92)
local BRONZE_BACKGROUND = "Interface" .. SEP .. "ForeverUI" .. SEP .. "glues" .. SEP .. "characterselect" .. SEP
	.. "heavybronzeframebackgroundc60"
local BACKGROUND_SIDE = 1024

local N = {
	vignettes = { top = 451, sides = 703 },
	panel = { 360, y = -137, margin = 10 },
	settings = { 300, x = -10, y = -80, down = 20 },
	row = { 265, 38, gap = 46, camelotGap = 48 },
	settingCell = { 122, 25, scale = 1.55, background = 7, text = 13, h = 20 },
	arrow = { 26, 25, scale = 1.7, left = -5, right = 4 },
	title = { 2, 4 },
	button = { 150, 40 },
	cancel = { 30, 15 }, buttonGap = 15, accept = { -30, 15 },
	price = { 0, 8 },
	errorMsg = { -122, duration = 5, fade = 1 },
}

-- keys Camelot lets through (BarberShopMixin:OnKeyDown)
local BINDINGS = { TOGGLEMUSIC = true, TOGGLESOUND = true, SCREENSHOT = true }

local function atlas(t, name, size)
	return ForeverUI.SetAtlas(t, name, not size)
end

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

local truthy = Tpl.Truthy

-- GameFontDisableMed3 does not exist in 3.3.5: GameFontNormalMed3 in gray
local function grayedFont()
	local p = _G["ForeverUIFontDisableMed3"] or CreateFont("ForeverUIFontDisableMed3")
	p:SetFontObject(GameFontNormalMed3)
	p:SetTextColor(0.5, 0.5, 0.5)
	return p
end

-- ------------------------------------------------------------ Reading

-- the 3.3.5 settings: their names (race dependent), plus a fourth when the skin can change
function C.Settings()
	local hair = GetHairCustomization()
	local list = {
		_G["HAIR_" .. hair .. "_STYLE"],
		_G["HAIR_" .. hair .. "_COLOR"],
		_G["FACIAL_HAIR_" .. GetFacialHairCustomization()],
	}
	if truthy(CanAlterSkin()) then list[4] = SKIN_COLOR end
	return list
end

-- ------------------------------------------------------------ Screen

-- vignette texture of root anchored at points; flip: mirrored horizontally
local function vignette(root, name, points, width, height, flip)
	local t = root:CreateTexture(nil, "OVERLAY")
	atlas(t, name)
	if flip then
		local e = ForeverUI.AtlasEntry(name)
		t:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	for _, p in ipairs(points) do t:SetPoint(p, root, p) end
	if width then t:SetWidth(width) end
	if height then t:SetHeight(height) end
	return t
end

-- heavybronze frame: tiled background, sliced edge, corner brackets. Returns resize(w, h).
local function bronzeFrame(f)
	local P = N.panel
	local background = f:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(BRONZE_BACKGROUND, true)
	background:SetPoint("TOPLEFT", f, "TOPLEFT", P.margin, -P.margin)
	background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -P.margin, P.margin)
	local edge = Tpl.StretchedAtlas(f, "heavybronze-frame-basic", "BORDER")
	edge.rect:SetAllPoints(f)
	for _, e in ipairs({ { "heavybronze-vert-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-vert-cornerbracket-br", "BOTTOMRIGHT" } }) do
		local t = f:CreateTexture(nil, "BORDER")
		atlas(t, e[1], true)
		t:SetPoint(e[2], f, e[2])
	end
	f.background = background
	return function(width, height)
		f:SetWidth(width)
		f:SetHeight(height)
		background:SetTexCoord(0, (width - 2 * P.margin) / BACKGROUND_SIDE, 0, (height - 2 * P.margin) / BACKGROUND_SIDE)
	end
end

-- WowStyle2IconButton: background by state, icon offset when pressed; direction: back or next
local function arrow(parent, direction, action)
	local F = N.arrow
	local b = CreateFrame("Button", nil, parent)
	b:SetScale(F.scale)
	b:SetWidth(F[1])
	b:SetHeight(F[2])
	b.background = b:CreateTexture(nil, "BACKGROUND")
	b.background:SetPoint("CENTER", b, "CENTER")
	b.icon = b:CreateTexture(nil, "OVERLAY")
	local function paint()
		local background = "common-dropdown-c-button"
		if b.down and b.hovered then
			background = "common-dropdown-c-button-pressedhover-2"
		elseif b.hovered then
			background = "common-dropdown-c-button-hover-2"
		elseif b.down then
			background = "common-dropdown-c-button-pressed-2"
		end
		atlas(b.background, background, true)
		atlas(b.icon, "common-dropdown-icon-" .. direction, true)
		place(b.icon, "CENTER", b, "CENTER", b.down and 2 or 0, b.down and -1 or 0)
	end
	b:SetScript("OnEnter", function() b.hovered = true paint() end)
	b:SetScript("OnLeave", function() b.hovered = false paint() end)
	b:SetScript("OnMouseDown", function() b.down = true paint() end)
	b:SetScript("OnMouseUp", function() b.down = false paint() end)
	b:SetScript("OnClick", action)
	paint()
	b.paint = paint
	return b
end

-- a row: [<] [cell] [>], setting name above
local function createRow(settings, i)
	local L_, K = N.row, N.settingCell
	local row = CreateFrame("Frame", nil, settings)
	row:SetWidth(L_[1])
	row:SetHeight(L_[2])
	row:SetPoint("TOPLEFT", settings, "TOPLEFT", 0, -(i - 1) * (L_[2] + L_.gap))
	local cell = CreateFrame("Frame", nil, row)
	cell:SetScale(K.scale)
	cell:SetWidth(K[1])
	cell:SetHeight(K[2])
	cell:SetPoint("CENTER", row, "CENTER")
	local background = Tpl.StretchedAtlas(cell, "common-dropdown-c-button", "BACKGROUND")
	background.rect:SetPoint("TOPLEFT", cell, "TOPLEFT", -K.background, K.background)
	background.rect:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", K.background, -K.background)
	local text = cell:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(GameFontNormal)
	text:SetTextColor(1, 0.82, 0)
	text:SetJustifyH("CENTER")
	text:SetHeight(K.h)
	text:SetPoint("LEFT", cell, "LEFT", K.text, 0)
	text:SetPoint("RIGHT", cell, "RIGHT", -K.text, 0)
	local F = N.arrow
	local minus = arrow(row, "back", function()
		SetNextBarberShopStyle(i, 1)
		PlaySound("UChatScrollButton")
		C.Update()
	end)
	minus:SetPoint("RIGHT", cell, "LEFT", F.left, 0)
	local plus = arrow(row, "next", function()
		SetNextBarberShopStyle(i)
		PlaySound("UChatScrollButton")
		C.Update()
	end)
	plus:SetPoint("LEFT", cell, "RIGHT", F.right, 0)
	local title = row:CreateFontString(nil, "ARTWORK")
	title:SetFontObject(SystemFont_Shadow_Large)
	title:SetPoint("BOTTOMLEFT", minus, "TOPLEFT", N.title[1], N.title[2])
	row.i, row.cell, row.background, row.text, row.minus, row.plus, row.title = i, cell, background, text, minus, plus, title
	-- mode 2: number (SelectionNumber, 25 x 20), swatch and its ADD glow (ColorSwatch1,
	-- ColorSwatch1Glow) centered in the cell, hover arrow (12 x 5 at BOTTOM, -5) and the button
	-- that opens the list
	local number = cell:CreateFontString(nil, "OVERLAY")
	number:SetFontObject(GameFontNormal)
	number:SetTextColor(1, 0.82, 0)
	number:SetJustifyH("LEFT")
	number:SetWidth(25)
	number:SetHeight(20)
	number:Hide()
	local swatch = cell:CreateTexture(nil, "ARTWORK")
	Tpl.Place(swatch, "charactercreate-customize-palette", true)
	swatch:Hide()
	local glow = cell:CreateTexture(nil, "ARTWORK")
	Tpl.Place(glow, "charactercreate-customize-palette-glow", true)
	glow:SetBlendMode("ADD")
	glow:SetPoint("CENTER", swatch, "CENTER")
	glow:Hide()
	local hover = cell:CreateTexture(nil, "OVERLAY")
	Tpl.Place(hover, "common-dropdown-c-button-hover-arrow", true)
	hover:SetPoint("BOTTOM", cell, "BOTTOM", 0, -5)
	hover:Hide()
	local b = CreateFrame("Button", nil, cell)
	b:SetAllPoints(cell)
	b:EnableMouseWheel(true)
	b:Hide()
	row.number, row.swatch, row.glow, row.hover, row.button = number, swatch, glow, hover, b
	C.WireCell(row)
	return row
end

-- SharedButtonLargeTemplate
local function button(root, name, text, action)
	local B = N.button
	local b = CreateFrame("Button", name, root)
	b:SetWidth(B[1])
	b:SetHeight(B[2])
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
	b:SetFontString(fs)
	Tpl.ThreeSliceButton(b, "128-redbutton", { GameFontNormalMed3, GameFontHighlightMedium, grayedFont() })
	b:SetText(text)
	b:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		action()
	end)
	return b
end

-- own error line: UIErrorsFrame hides with the game UI
local function createError(root)
	local E = N.errorMsg
	local t = root:CreateFontString(nil, "OVERLAY", "ErrorFont")
	t:SetPoint("TOP", root, "TOP", 0, E[1])
	t:Hide()
	local timer = CreateFrame("Frame", nil, root)
	timer:Hide()
	timer:SetScript("OnUpdate", function(self, elapsed)
		self.rest = self.rest - elapsed
		if self.rest <= 0 then
			t:Hide()
			self:Hide()
		elseif self.rest < E.fade then
			t:SetAlpha(self.rest / E.fade)
		end
	end)
	function C.ShowError(message, r, g, b)
		t:SetText(message)
		t:SetTextColor(r, g, b)
		t:SetAlpha(1)
		t:Show()
		timer.rest = E.duration
		timer:Show()
	end
	return t
end

function C.Build()
	if C.root then return C.root end
	-- full screen, at UI scale, outside UIParent (which gets hidden)
	local r = CreateFrame("Frame", "ForeverUIBarberShop", nil)
	r:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	r:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
	r:SetFrameStrata("MEDIUM")
	r:EnableKeyboard(true)
	r:Hide()
	local V = N.vignettes
	r.vignettes = {
		vignette(r, "charactercreate-vignette-top", { "TOPLEFT", "TOPRIGHT" }, nil, V.top),
		vignette(r, "charactercreate-vignette-sides", { "TOPLEFT", "BOTTOMLEFT" }, V.sides),
		vignette(r, "charactercreate-vignette-sides", { "TOPRIGHT", "BOTTOMRIGHT" }, V.sides, nil, true),
	}
	-- settings panel
	local P, R = N.panel, N.settings
	local panel = CreateFrame("Frame", "ForeverUIBarberShopOptions", r)
	panel:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, P.y)
	panel:EnableMouse(true)
	r.resize = bronzeFrame(panel)
	local settings = CreateFrame("Frame", nil, panel)
	settings:SetWidth(R[1])
	settings:SetPoint("TOPRIGHT", panel, "TOPRIGHT", R.x, R.y)
	r.panel, r.settings, r.rows = panel, settings, {}
	-- buttons
	local cancel = button(r, "ForeverUIBarberShopCancelButton", CANCEL, function() CancelBarberShop() end)
	cancel:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", N.cancel[1], N.cancel[2])
	local reset = button(r, "ForeverUIBarberShopResetButton", RESET, function()
		BarberShopReset()
		C.Update()
	end)
	reset:SetPoint("BOTTOMLEFT", cancel, "TOPLEFT", 0, N.buttonGap)
	local accept = button(r, "ForeverUIBarberShopAcceptButton", ACCEPT, function() ApplyBarberShopStyle() end)
	accept:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", N.accept[1], N.accept[2])
	-- price (Camelot does not show it)
	local price = CreateFrame("Frame", "ForeverUIBarberShopMoneyFrame", r, "SmallMoneyFrameTemplate")
	price:SetPoint("BOTTOMRIGHT", accept, "TOPRIGHT", N.price[1], N.price[2])
	-- a fixed amount, not the player's gold (as the 3.3.5 barber shop: GUILD_REPAIR)
	if MoneyFrame_SetType then MoneyFrame_SetType(price, "STATIC") end
	r.cancel, r.reset, r.accept, r.price = cancel, reset, accept, price
	r.errorMsg = createError(r)
	-- BarberShopMixin:OnKeyDown
	r:SetScript("OnKeyDown", function(_, pressedKey)
		if pressedKey == "ESCAPE" then
			-- an open list closes first, back on the current choice
			if C.IsListOpen() then
				C.CloseList(false)
			else
				CancelBarberShop()
			end
			return
		end
		local action = GetBindingAction(pressedKey)
		if action and BINDINGS[action] then RunBinding(action) end
	end)
	r:SetScript("OnHide", function()
		C.ForgetList()
		C.RestoreInterface()
	end)
	C.CreateList(r)
	C.root = r
	return r
end

-- ------------------------------------------------------------ Mode 2: choices

-- Mode 2 needs a patched client (tools/patcher). C.lists[i]: valid choices of setting i
-- (1 hair style, 2 hair color, 3 facial hair, 4 skin); a choice's number is its rank there.
C.lists = {}

-- index of the current choice, and for skin the face index: 5th and 6th values of
-- GetBarberShopStyleInfo on a patched client; nil on the stock client (mode 1)
local function index(i)
	local v, face = select(5, GetBarberShopStyleInfo(i))
	if type(v) == "number" then
		return v, face
	end
end

-- position of v in list, or nil
local function rank(list, v)
	for k, x in ipairs(list) do
		if x == v then
			return k
		end
	end
end

-- player race (ChrRaces file name, uppercase) and sex (0 / 1)
local function player()
	local _, file = UnitRace("player")
	return file and string.upper(file), (UnitSex("player") == 3) and 1 or 0
end

-- valid choices of setting i, computed from CharSections [section][variation][color]
-- (section 0 skin, 1 face, 2 facial hair, 3 hair, 4 underwear) and the engine rules,
-- in ascending order as the engine walks them (tools/customization_choices.py)
local function compute(i)
	local file, sex = player()
	local d = ForeverUI.AppearanceChoices and file and ForeverUI.AppearanceChoices[file]
	d = d and d[sex]
	if not d then
		return nil
	end
	-- flags: bit 1 for other classes, bit 2 for death knights
	local _, className = UnitClass("player")
	local weight = (className == "DEATHKNIGHT") and 2 or 1
	local function count(section, var)
		local s = var and d[section][var]
		return s and string.len(s) or 0
	end
	local function isAvailable(section, var, col)
		local s = var and d[section][var]
		local c = s and string.byte(s, col + 1)
		c = c and c - 48                -- "0".."3"; "." (no row) is below 0
		return c ~= nil and c >= 0 and math.floor(c / weight) % 2 == 1
	end
	local function hasColor(section, var)
		for c = 0, count(section, var) - 1 do
			if isAvailable(section, var, c) then
				return true
			end
		end
		return false
	end
	local list = {}
	if i == 1 then
		-- hair style (0x4F0490): at least one color
		for s = 0, d[3].n - 1 do
			if hasColor(3, s) then
				list[#list + 1] = s
			end
		end
	elseif i == 2 then
		-- hair color (0x4EB500): those of the current hair style
		local hairStyle = index(1)
		for c = 0, count(3, hairStyle) - 1 do
			if isAvailable(3, hairStyle, c) then
				list[#list + 1] = c
			end
		end
	elseif i == 3 then
		-- facial hair (0x4EBCA0): if the (facial hair, hair color) cell exists, styles with
		-- at least one color; otherwise all styles
		local facialHair, color = index(3), index(2)
		if facialHair and color and facialHair < d[2].n and color < count(2, facialHair) then
			for v = 0, d[2].n - 1 do
				if hasColor(2, v) then
					list[#list + 1] = v
				end
			end
		else
			for v = 0, (d.facialHairs or 0) - 1 do
				list[#list + 1] = v
			end
		end
	else
		-- skin (0x4EB150): valid with the current face and the underwear
		local _, face = index(4)
		for c = 0, count(0, 0) - 1 do
			if isAvailable(0, 0, c) and isAvailable(1, face, c) and isAvailable(4, 0, c) then
				list[#list + 1] = c
			end
		end
	end
	return list
end

-- Fallback when the engine value is missing from the computed list: step the setting through a
-- full loop with the engine, stopping back at the start (each step redraws the character)
local function enumerate(i)
	local origin = index(i)
	if not origin then
		return nil
	end
	local loop = { origin }
	for _ = 1, 255 do
		SetNextBarberShopStyle(i)
		local v = index(i)
		if not v or v == origin then
			break
		end
		loop[#loop + 1] = v
	end
	-- in engine order, starting from the smallest index
	local first = 1
	for k = 2, #loop do
		if loop[k] < loop[first] then
			first = k
		end
	end
	local list = {}
	for k = 0, #loop - 1 do
		list[#list + 1] = loop[(first - 1 + k) % #loop + 1]
	end
	return list
end

-- moves setting i to choice target by the shortest path
local function goTo(i, target)
	local list = C.lists[i]
	if not list then
		return
	end
	local n, p, q = #list, rank(list, index(i)), rank(list, target)
	if not p or not q then
		return
	end
	local forward, backward = (q - p) % n, (p - q) % n
	if forward <= backward then
		for _ = 1, forward do
			SetNextBarberShopStyle(i)
		end
	else
		for _ = 1, backward do
			SetNextBarberShopStyle(i, 1)
		end
	end
end

-- Swatch color of a choice (ColorSwatch1), read from its texture by
-- tools/customization_colors.py (BarberShopColors.lua). Hair color (2) and skin (4) only.
local SWATCHES = { [2] = "hair", [4] = "skinColor" }
local function colorOf(i, v)
	local kind = SWATCHES[i]
	if not (kind and v and ForeverUI.AppearanceColors) then
		return nil
	end
	local file, sex = player()
	local t = file and ForeverUI.AppearanceColors[file]
	t = t and t[sex]
	t = t and t[kind]
	return t and t[v]
end

-- Choice name from the patched client: GetBarberShopStyleInfo(i, n) returns only the name of
-- choice n (BarberShopStyle.dbc, client language) or nil. A stock client ignores n and returns
-- the current choice's values, so only a single-value answer is trusted. Hair colors have no
-- names.
local NAMED = { [1] = true, [3] = true, [4] = true }
local function single(...)
	if select("#", ...) == 1 then
		return (...)
	end
end
local function nameOf(i, v)
	if not NAMED[i] then
		return nil
	end
	local name = single(GetBarberShopStyleInfo(i, v))
	if type(name) == "string" and name ~= "" then
		return name
	end
end

-- ------------------------------------------------------------ Mode 2: open list

-- MenuStyle2, as in character creation: common-dropdown-c-bg background, TOPRIGHT on the
-- cell's BOTTOMRIGHT; vertical grid of 1 to 4 columns (up to 10, 24, 36 choices), more if the
-- list would end within 100 of the bottom; 20 high items. Hover previews the choice; a click
-- picks and closes; a click outside or Esc goes back to the current choice.
-- A preview waits PREVIEW_DELAY on one item (each preview rebuilds the character textures);
-- the frame after the hover does not count, and a frame never counts more than PREVIEW_MAX_STEP.
local PREVIEW_DELAY = 0.1
local PREVIEW_MAX_STEP = 0.05
local L = { entries = {} }          -- isOpen = { row, selected }, preview = { k, pending, fresh }
C.entries = L.entries

function C.IsListOpen()
	return L.isOpen ~= nil
end

-- closes the list without changing anything (used when the barber shop closes)
function C.ForgetList()
	L.isOpen, L.preview = nil, nil
	local r = C.root
	if r then
		r.menu:Hide()
		r.catcher:Hide()
	end
end

-- keep: keep the hovered choice; otherwise go back to the current choice
function C.CloseList(keep)
	local o = L.isOpen
	if not o then
		return
	end
	C.ForgetList()
	if not keep then
		goTo(o.row.i, o.selected)
	end
	C.Update()
end

function C.CreateList(r)
	local menu = CreateFrame("Frame", "ForeverUIBarberShopChoiceMenu", r)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetFrameLevel(20)
	menu:SetScale(N.settingCell.scale)
	menu:EnableMouse(true)
	menu:Hide()
	local background = Tpl.StretchedAtlas(menu, "common-dropdown-c-bg", "BACKGROUND")
	background.rect:SetPoint("TOPLEFT", menu, "TOPLEFT", -17, 12)
	background.rect:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 17, -22)
	-- a click outside the list closes it without picking
	local catcher = CreateFrame("Button", nil, r)
	catcher:SetFrameStrata("FULLSCREEN_DIALOG")
	catcher:SetFrameLevel(10)
	catcher:SetAllPoints(r)
	catcher:Hide()
	catcher:SetScript("OnClick", function() C.CloseList(false) end)
	-- name width, measured on a never-bounded text (a reused item would measure within the width
	-- set for the previous one)
	local measure = menu:CreateFontString(nil, "OVERLAY")
	measure:SetFontObject(GameFontNormal)
	measure:SetAlpha(0)
	menu:SetScript("OnUpdate", function(_, elapsed)
		local a = L.preview
		if not a then
			return
		end
		if a.fresh then
			a.fresh = false
			return
		end
		a.pending = a.pending - math.min(elapsed, PREVIEW_MAX_STEP)
		if a.pending <= 0 then
			L.preview = nil
			if L.isOpen then
				goTo(L.isOpen.row.i, C.lists[L.isOpen.row.i][a.k])
				C.UpdatePrice()
			end
		end
	end)
	r.menu, r.catcher, r.measure = menu, catcher, measure
end

-- list item k, created on first use
local function entry(k)
	if L.entries[k] then
		return L.entries[k]
	end
	local e = CreateFrame("Button", nil, C.root.menu)
	e:SetHeight(20)
	e.hover = Tpl.StretchedAtlas(e, "common-dropdown-customize-mouseover", "BACKGROUND")
	e.hover.rect:SetAllPoints(e)
	e.hover:Alpha(0.15)
	e.hover:SetShown(false)
	e.number = e:CreateFontString(nil, "OVERLAY")
	e.number:SetFontObject(GameFontNormal)
	e.number:SetJustifyH("LEFT")
	e.number:SetWidth(25)
	e.number:SetHeight(20)
	e.number:SetPoint("TOPLEFT", e, "TOPLEFT", 14, 0)
	e.name = e:CreateFontString(nil, "OVERLAY")
	e.name:SetFontObject(GameFontNormal)
	e.name:SetJustifyH("LEFT")
	e.name:SetHeight(20)
	e.name:SetPoint("LEFT", e.number, "RIGHT", 0, 0)
	-- ColorSwatch1 right of the number, its glow, and ColorSelected (current choice) 4 left of it
	e.swatch = e:CreateTexture(nil, "ARTWORK")
	Tpl.Place(e.swatch, "charactercreate-customize-palette", true)
	e.swatch:SetPoint("LEFT", e.number, "RIGHT", 0, 0)
	e.glow = e:CreateTexture(nil, "ARTWORK")
	Tpl.Place(e.glow, "charactercreate-customize-palette-glow", true)
	e.glow:SetBlendMode("ADD")
	e.glow:SetPoint("CENTER", e.swatch, "CENTER")
	e.selected = e:CreateTexture(nil, "ARTWORK")
	Tpl.Place(e.selected, "charactercreate-customize-palette-selected", true)
	e.selected:SetPoint("LEFT", e.swatch, "LEFT", -4, 0)
	e:SetScript("OnEnter", function(self)
		self.hover:SetShown(true)
		if L.isOpen then
			L.preview = { k = self.k, pending = PREVIEW_DELAY, fresh = true }
		end
	end)
	e:SetScript("OnLeave", function(self)
		self.hover:SetShown(false)
		if L.preview and L.preview.k == self.k then
			L.preview = nil
		end
	end)
	e:SetScript("OnClick", function(self)
		if L.isOpen then
			L.preview = nil
			PlaySound("gsCharacterCreationLook")
			goTo(L.isOpen.row.i, C.lists[L.isOpen.row.i][self.k])
			C.CloseList(true)
		end
	end)
	L.entries[k] = e
	return e
end

local function openList(row)
	local r, i = C.root, row.i
	local list = C.lists[i]
	if not list or #list == 0 then
		return
	end
	local n = #list
	local selected = rank(list, index(i)) or 1
	local columns = (n > 36 and 4) or (n > 24 and 3) or (n > 10 and 2) or 1
	local rowLines = math.ceil(n / columns)
	-- compactionMargin: the list starts at the bottom of the cell
	local top = row.cell:GetBottom()
	if top then
		local maxValue = math.max(1, math.floor((top - 100) / 20))
		if rowLines > maxValue then
			columns = math.ceil(n / maxValue)
			rowLines = math.ceil(n / columns)
		end
	end
	local colors = colorOf(i, list[1]) and true
	local names = false
	for _, v in ipairs(list) do
		if not colors and nameOf(i, v) then
			names = true
		end
	end
	local details = 116
	if columns > 1 then
		details = (colors and (25 + 36 + 18)) or (names and 108) or 42
	end
	local width = 14 + details + 14
	local menu = r.menu
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", row.cell, "BOTTOMRIGHT")
	menu:SetWidth(3 + columns * width + 3)
	menu:SetHeight(6 + rowLines * 20 + 7)
	for k = 1, n do
		local e = entry(k)
		e.k = k
		e:SetWidth(width)
		e:ClearAllPoints()
		e:SetPoint("TOPLEFT", menu, "TOPLEFT", 3 + math.floor((k - 1) / rowLines) * width, -(6 + ((k - 1) % rowLines) * 20))
		e.number:SetText(k)
		local name = not colors and nameOf(i, list[k])
		if name then
			r.measure:SetText(name)
			e.name:SetWidth(math.min(r.measure:GetStringWidth(), width - 2 - 25))
			e.name:SetText(name)
		end
		Tpl.SetShown(e.name, name)
		if k == selected then
			e.number:SetTextColor(1, 0.82, 0)
			e.name:SetTextColor(1, 0.82, 0)
		else
			e.number:SetTextColor(0.5, 0.5, 0.5)
			e.name:SetTextColor(0.5, 0.5, 0.5)
		end
		e.hover:SetShown(false)
		local color = colorOf(i, list[k])
		if color then
			e.swatch:SetVertexColor(color[1], color[2], color[3])
		end
		Tpl.SetShown(e.swatch, color)
		Tpl.SetShown(e.glow, color)
		Tpl.SetShown(e.selected, color and k == selected)
		e:Show()
	end
	for k = n + 1, #L.entries do
		L.entries[k]:Hide()
	end
	L.isOpen = { row = row, selected = list[selected] }
	menu:Show()
	r.catcher:Show()
	C.PaintCell(row)
end

-- WowStyle2Dropdown: background by state (pressed, hovered, open), hover arrow, details
-- offset by (1, -1) when pressed
function C.PaintCell(row)
	local b, K = row.button, N.settingCell
	local name = "common-dropdown-c-button"
	if b.down and b.hovered then
		name = "common-dropdown-c-button-pressedhover-1"
	elseif b.down then
		name = "common-dropdown-c-button-pressed-1"
	elseif b.hovered then
		name = "common-dropdown-c-button-hover-1"
	elseif L.isOpen and L.isOpen.row == row then
		name = "common-dropdown-c-button-open"
	end
	row.background:Place(name)
	Tpl.SetShown(row.hover, b:IsShown() and b.hovered)
	local dx, dy = b.down and 1 or 0, b.down and -1 or 0
	place(row.number, "CENTER", row.cell, "CENTER", dx, dy)
	place(row.swatch, "CENTER", row.cell, "CENTER", dx, dy)
	place(row.text, "LEFT", row.cell, "LEFT", K.text + dx, dy)
	row.text:SetPoint("RIGHT", row.cell, "RIGHT", -K.text + dx, dy)
end

-- the row's cell opens the list; the wheel steps the choice (down: next)
function C.WireCell(row)
	local b = row.button
	b:SetScript("OnEnter", function(self) self.hovered = true C.PaintCell(row) end)
	b:SetScript("OnLeave", function(self) self.hovered = nil C.PaintCell(row) end)
	b:SetScript("OnMouseDown", function(self) self.down = true C.PaintCell(row) end)
	b:SetScript("OnMouseUp", function(self) self.down = nil C.PaintCell(row) end)
	b:SetScript("OnHide", function(self) self.hovered, self.down = nil, nil end)
	b:SetScript("OnClick", function()
		local already = L.isOpen and L.isOpen.row == row
		C.CloseList(false)
		if not already then
			openList(row)
		end
	end)
	b:SetScript("OnMouseWheel", function(_, direction)
		C.CloseList(false)
		if direction < 0 then
			SetNextBarberShopStyle(row.i)
		else
			SetNextBarberShopStyle(row.i, 1)
		end
		PlaySound("UChatScrollButton")
		C.Update()
	end)
end

-- ------------------------------------------------------------ Update

-- price and buttons (BarberShop_UpdateCost): Accept and Reset disabled when nothing changed
function C.UpdatePrice()
	local r = C.root
	if not r then return end
	local allCurrent = true
	for i = 1, #C.Settings() do
		local _, _, _, current = GetBarberShopStyleInfo(i)
		if not truthy(current) then allCurrent = false end
	end
	MoneyFrame_Update(r.price:GetName(), GetBarberShopTotalCost())
	if allCurrent then
		r.accept:Disable()
		r.reset:Disable()
	else
		r.accept:Enable()
		r.reset:Enable()
	end
end

-- rows (BarberShop_Update), then price and buttons. Mode 2: every list is recomputed
-- (instant without the engine), except the open one.
function C.Update()
	local r = C.root
	if not r or not r:IsShown() then return end
	local names = C.Settings()
	local L_, P, R = N.row, N.panel, N.settings
	for i, settingName in ipairs(names) do
		local row = r.rows[i] or createRow(r.settings, i)
		r.rows[i] = row
		local name = GetBarberShopStyleInfo(i)
		local hasName = name and name ~= ""
		local v = index(i)
		local position
		if not v then
			C.lists[i] = nil
		else
			if not (L.isOpen and L.isOpen.row.i == i) then
				local list = compute(i)
				if not (list and rank(list, v)) then
					list = enumerate(i)
				end
				C.lists[i] = list
			end
			position = C.lists[i] and rank(C.lists[i], v)
		end
		local color = position and colorOf(i, v)
		if color then
			row.swatch:SetVertexColor(color[1], color[2], color[3])
		end
		Tpl.SetShown(row.swatch, color)
		Tpl.SetShown(row.glow, color)
		if position then
			-- mode 2: setting name above; in the cell the choice name, its swatch,
			-- or else its number
			row.title:SetText(settingName)
			row.title:Show()
			row.text:SetText(hasName and name or "")
			Tpl.SetShown(row.text, hasName and not color)
			row.number:SetText(position)
			Tpl.SetShown(row.number, not hasName and not color)
			row.button:Show()
		else
			-- mode 1: choice name under the setting name; otherwise the setting name
			-- in the cell, no title
			if hasName then
				row.text:SetText(name)
				row.title:SetText(settingName)
				row.title:Show()
			else
				row.text:SetText(settingName)
				row.title:Hide()
			end
			row.text:Show()
			row.number:Hide()
			row.button:Hide()
		end
		C.PaintCell(row)
		row:Show()
	end
	for i = #names + 1, #r.rows do r.rows[i]:Hide() end
	local n = #names
	r.settings:SetHeight(n * L_[2] + (n - 1) * L_.gap)
	r.resize(P[1], -R.y + n * L_[2] + (n - 1) * L_.camelotGap + R.down)
	C.UpdatePrice()
end

-- ------------------------------------------------------------ Opening

-- The game UI is hidden with UIParent:Hide() and shown again on close. The 3.3.5 frame stays
-- the host (events, sounds): as a child of UIParent it hides with the UI untouched, and comes
-- back intact if combat restores the UI.
function C.Open()
	if InCombatLockdown() then return end
	local r = C.Build()
	r:SetScale(UIParent:GetScale())
	if UIParent:IsShown() then
		C.hidden = true
		UIParent:Hide()
	end
	r:Show()
	C.Update()
end

function C.Close()
	-- close the 3.3.5 frame first: hidden with the UI, it was not closed by BARBER_SHOP_CLOSE
	-- (which only closes a visible frame); closed after the UI returns, it would flash and replay
	-- its sound
	if BarberShopFrame and BarberShopFrame:IsShown() then BarberShopFrame:Hide() end
	if C.root and C.root:IsShown() then C.root:Hide() end
	C.RestoreInterface()
end

function C.RestoreInterface()
	if C.hidden then
		C.hidden = nil
		UIParent:Show()
	end
end

local watcher = CreateFrame("Frame")
C.watcher = watcher
for _, ev in ipairs({ "BARBER_SHOP_OPEN", "BARBER_SHOP_CLOSE", "BARBER_SHOP_SUCCESS",
	"BARBER_SHOP_APPEARANCE_APPLIED", "PLAYER_REGEN_DISABLED", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE" }) do
	watcher:RegisterEvent(ev)
end
watcher:SetScript("OnEvent", function(_, ev, message)
	local isOpen = C.root and C.root:IsShown()
	if ev == "BARBER_SHOP_OPEN" then
		C.Open()
	elseif ev == "BARBER_SHOP_CLOSE" then
		C.Close()
	elseif ev == "PLAYER_REGEN_DISABLED" then
		-- before the combat lockdown: the UI comes back and the 3.3.5 frame takes over
		if isOpen then C.root:Hide() end
	elseif not isOpen then
		return
	elseif ev == "BARBER_SHOP_APPEARANCE_APPLIED" then
		-- as in Camelot: once the appearance is applied, the barber shop closes
		CancelBarberShop()
	elseif ev == "UI_ERROR_MESSAGE" then
		C.ShowError(message, 1.0, 0.1, 0.1)
	elseif ev == "UI_INFO_MESSAGE" then
		C.ShowError(message, 1.0, 1.0, 0.0)
	else
		C.Update()
	end
end)
