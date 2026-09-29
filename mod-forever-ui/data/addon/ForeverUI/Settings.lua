-- ForeverUI: camelot art on the client Video, Sound and Interface options windows.
-- camelot has no such windows (it uses SettingsPanel): the client screens, logic and CVars stay,
-- with the same art pieces and numbers as the glue options (ForeverUIGlueOptions.lua).
-- Panels of other addons (AddOns tab) keep their controls; only the window, list and tabs change.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates
local truthy = Tpl.Truthy

local R = {}
ForeverUI.Settings = R

-- Numbers kept in tables: Lua 5.1 allows at most 60 upvalues per function.
local N = {
	box = { 0.4, 0.4, 0.4 },          -- OptionsBoxTemplate border
	handle = { 16, 15 },               -- camelot: 20 x 19
	disabledHandle = 0.7,                -- MinimalSliderWithSteppers
	button = { 96, 22 },
	buttonEdge = 16,
	buttonGap = 2,
	menu = { left = 16, top = -19, right = -17, height = 25, background = 7, text = 13, arrowY = -5 },
	tab = { height = 37, margin = 40, text = 4, selectedText = 6, gap = 5 },
	watcher = 0.1,
}

-- ------------------------------------------------------------ Controls

-- Sets one state texture of a button to a camelot atlas, stretched over the button.
-- set, get: texture setter and getter names; name: atlas; mode: optional blend mode.
local function applyState(b, set, get, name, mode)
	b[set](b, Tpl.Art(name)[1])
	local t = b[get](b)
	Tpl.Place(t, name)
	t:ClearAllPoints()
	t:SetAllPoints(b)
	if mode then
		t:SetBlendMode(mode)
	end
	return t
end

-- SettingsCheckboxTemplate at the client checkbox size (26), no hover glow.
function R.Checkbox(c)
	if c.foreverCell then return end
	c.foreverCell = true
	applyState(c, "SetNormalTexture", "GetNormalTexture", "checkbox-minimal")
	applyState(c, "SetPushedTexture", "GetPushedTexture", "checkbox-minimal")
	local glow = c:GetHighlightTexture()
	if glow then
		glow:SetTexture(nil)
		glow:SetAlpha(0)
	end
	applyState(c, "SetCheckedTexture", "GetCheckedTexture", "checkmark-minimal")
	applyState(c, "SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "checkmark-minimal-disabled")
end

-- OptionsBoxTemplate: camelot tooltip border in the client grey (0.4), no background (the
-- client has none).
function R.Box(f)
	if f.foreverNineSlice then return end
	local p = ForeverUI.Tooltips.Skin(f)
	for name, t in pairs(p) do
		if name == "Center" then
			t:SetAlpha(0)
		else
			t:SetVertexColor(N.box[1], N.box[2], N.box[3], 1)
		end
	end
end

-- MinimalSliderTemplate on the client slider, at its size (17 high, the track height):
-- Left / Right at atlas size, Middle between them, thumb Minimal_SliderBar_Button (16 x 15).
R.sliders = {}
function R.Cursor(s)
	if s.foreverCursor then return end
	s.foreverCursor = true
	s:SetBackdrop(nil)
	local g = s:CreateTexture(nil, "ARTWORK")
	Tpl.Place(g, "minimal_sliderbar_left", true)
	g:SetPoint("LEFT", s, "LEFT")
	local d = s:CreateTexture(nil, "ARTWORK")
	Tpl.Place(d, "minimal_sliderbar_right", true)
	d:SetPoint("RIGHT", s, "RIGHT")
	local m = s:CreateTexture(nil, "ARTWORK")
	Tpl.Place(m, "_minimal_sliderbar_middle", true)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("TOPRIGHT", d, "TOPLEFT")
	s:SetThumbTexture(Tpl.Art("minimal_sliderbar_button")[1])
	local button = s:GetThumbTexture()
	Tpl.Place(button, "minimal_sliderbar_button")
	button:SetWidth(N.handle[1])
	button:SetHeight(N.handle[2])
	R.sliders[#R.sliders + 1] = s
end

-- ------------------------------------------------------------ Dropdown menu

-- WowStyle2DropdownTemplate (SettingsDropdownControl), inside the visible part of the 3.3.5
-- frame (CharacterCreate-LabelFrame: opaque from 16 to 111 of 128 wide, 19 to 45 of 64 high):
-- background common-dropdown-c-button from (-7, 7) to (7, -7) with its hover, pressed, open
-- and disabled states; hover arrow at BOTTOM (0, -5), desaturated when disabled; text centered
-- from 13 to -13, shifted (2, -1) when pressed, in GameFontNormalSmall (size 10) instead of
-- GameFontNormal. The list: DropDown.lua, style 2.
local function isOpen(dd)
	return DropDownList1 and DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == dd
end

-- Draws the dropdown state: background atlas, hover arrow, text color and pressed offset.
local function paintMenu(dd)
	local b = dd.foreverButton
	local active = truthy(b:IsEnabled())
	local n = "common-dropdown-c-button"
	if not active then
		n = n .. "-disabled"
	elseif b.foreverMouseDown and b.foreverHovered then
		n = n .. "-pressedhover-1"
	elseif b.foreverHovered then
		n = n .. "-hover-1"
	elseif b.foreverMouseDown then
		n = n .. "-pressed-1"
	elseif isOpen(dd) then
		n = n .. "-open"
	end
	dd.foreverBackground:Place(n)
	Tpl.SetShown(dd.foreverArrow, b.foreverHovered)
	dd.foreverArrow:SetDesaturated(not active)
	local text = _G[dd:GetName() .. "Text"]
	-- The client greys the text with SetVertexColor: reset it and use our own color.
	text:SetVertexColor(1, 1, 1)
	if active then
		text:SetTextColor(1, 0.82, 0)
	else
		text:SetTextColor(0.5, 0.5, 0.5)
	end
	-- camelot: SetDisplacedRegions(2, -1, Text)
	local dx, dy = 0, 0
	if b.foreverMouseDown and active then
		dx, dy = 2, -1
	end
	text:ClearAllPoints()
	text:SetPoint("LEFT", b, "LEFT", N.menu.text + dx, dy)
	text:SetPoint("RIGHT", b, "RIGHT", -N.menu.text + dx, dy)
end

-- Skins a client UIDropDownMenu as a camelot dropdown.
function R.Menu(dd)
	if dd.foreverButton then return end
	dd.foreverStyle = 2
	local name = dd:GetName()
	local left, right = _G[name .. "Left"], _G[name .. "Right"]
	for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
		_G[name .. suffix]:SetAlpha(0)
	end
	local b = _G[name .. "Button"]
	dd.foreverButton = b
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", left, "TOPLEFT", N.menu.left, N.menu.top)
	b:SetPoint("RIGHT", right, "RIGHT", N.menu.right, 0)
	b:SetHeight(N.menu.height)
	Tpl.ClearArt(b)
	-- Background as a region of the dropdown, below its text; the button (child frame) holds only
	-- the arrow.
	local text = _G[name .. "Text"]
	text:SetHeight(20)
	text:SetFontObject(GameFontNormalSmall)
	text:SetJustifyH("CENTER")
	dd.foreverBackground = Tpl.StretchedAtlas(dd, "common-dropdown-c-button", "BACKGROUND")
	dd.foreverBackground.rect:SetPoint("TOPLEFT", b, "TOPLEFT", -N.menu.background, N.menu.background)
	dd.foreverBackground.rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", N.menu.background, -N.menu.background)
	dd.foreverArrow = b:CreateTexture(nil, "OVERLAY")
	Tpl.Place(dd.foreverArrow, "common-dropdown-c-button-hover-arrow", true)
	dd.foreverArrow:SetPoint("BOTTOM", b, "BOTTOM", 0, N.menu.arrowY)
	dd.foreverPaint = function() paintMenu(dd) end
	b:HookScript("OnEnter", function(self)
		self.foreverHovered = true
		paintMenu(dd)
		-- The dropdown's own hover script (its tooltip) stays the client's: the button forwards it.
		local onEnter = dd:GetScript("OnEnter")
		if onEnter then onEnter(dd) end
	end)
	b:HookScript("OnLeave", function(self)
		self.foreverHovered = false
		paintMenu(dd)
		local onLeave = dd:GetScript("OnLeave")
		if onLeave then onLeave(dd) end
	end)
	b:HookScript("OnMouseDown", function(self) self.foreverMouseDown = true; paintMenu(dd) end)
	b:HookScript("OnMouseUp", function(self) self.foreverMouseDown = false; paintMenu(dd) end)
	b:HookScript("OnDisable", function() paintMenu(dd) end)
	b:HookScript("OnEnable", function() paintMenu(dd) end)
	dd:HookScript("OnShow", function() paintMenu(dd) end)
	paintMenu(dd)
end

-- The client resets the dropdown in UIDropDownMenu_EnableDropDown / _DisableDropDown:
-- repaint after it.
for _, name in ipairs({ "UIDropDownMenu_EnableDropDown", "UIDropDownMenu_DisableDropDown" }) do
	if type(_G[name]) == "function" then
		hooksecurefunc(name, function(dd)
			if dd and dd.foreverPaint then dd.foreverPaint() end
		end)
	end
end

-- Button text, converted like the list lines (Tpl.Utf8Text).
hooksecurefunc("UIDropDownMenu_SetText", function(dd, text)
	local fs = dd and dd.foreverButton and _G[dd:GetName() .. "Text"]
	local clean = Tpl.Utf8Text(text)
	if fs and clean ~= text then
		fs:SetText(clean)
	end
end)

-- ------------------------------------------------------------ Panels

-- Skins a whole panel: each control by its template, recursing into frames that hold others
-- (group boxes, sub-frames).
function R.Panel(frame)
	for _, c in ipairs({ frame:GetChildren() }) do
		local name = c:GetName()
		local kind = c:GetObjectType()
		if kind == "CheckButton" then
			R.Checkbox(c)
		elseif kind == "Slider" then
			R.Cursor(c)
		elseif name and _G[name .. "Button"] and _G[name .. "Middle"] and _G[name .. "Left"] then
			R.Menu(c)
		else
			local background = c.GetBackdrop and c:GetBackdrop()
			if background and type(background.edgeFile) == "string"
				and string.find(string.lower(background.edgeFile), "ui%-tooltip%-border") then
				R.Box(c)
			end
			if kind == "Frame" then
				R.Panel(c)
			end
		end
	end
end

-- Slider thumb at 0.7 alpha when disabled (MinimalSliderWithSteppers: ConfigureSlider). The
-- client disables sliders through a function stored on each one, so poll them while the
-- windows are open.
local watcher = CreateFrame("Frame")
watcher.t = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
	self.t = self.t + (elapsed or 0)
	if self.t < N.watcher then
		return
	end
	self.t = 0
	local f1, f2, f3 = VideoOptionsFrame, AudioOptionsFrame, InterfaceOptionsFrame
	if not ((f1 and f1:IsShown()) or (f2 and f2:IsShown()) or (f3 and f3:IsShown())) then
		return
	end
	for _, s in ipairs(R.sliders) do
		local active = not s.IsEnabled or truthy(s:IsEnabled())
		s:GetThumbTexture():SetAlpha(active and 1 or N.disabledHandle)
	end
end)
R.watcher = watcher

-- ------------------------------------------------------------ Categories

-- camelot SettingsCategoryListButtonMixin:UpdateStateInternal, run after the client
-- (OptionsList_DisplayButton resets fonts and toggle; OptionsList_SelectButton /
-- ClearSelection set the selection).
local function paintRow(list, b)
	local el = b.element
	local selected = el ~= nil and list.selection == el
	Tpl.SetShown(b.foreverActive, selected)
	Tpl.SetShown(b.foreverHover, not selected and b.foreverHovered)
	local font
	if selected or (el and el.parent) then
		font = GameFontHighlight
	else
		font = GameFontNormal
	end
	b:SetNormalFontObject(font)
	b:SetHighlightFontObject(font)
	-- Toggle: common-button-dropdown-open / -closed
	local t = b.toggle
	if t and el and el.hasChildren then
		local state = el.collapsed and "closed" or "open"
		t:SetNormalTexture(ForeverUI.AtlasEntry("common-button-dropdown-" .. state)[1])
		ForeverUI.SetAtlas(t:GetNormalTexture(), "common-button-dropdown-" .. state, true)
		t:SetPushedTexture(ForeverUI.AtlasEntry("common-button-dropdown-" .. state .. "pressed")[1])
		ForeverUI.SetAtlas(t:GetPushedTexture(), "common-button-dropdown-" .. state .. "pressed", true)
	end
end

function R.PaintList(list)
	for _, b in ipairs(list.buttons or {}) do
		paintRow(list, b)
	end
end

-- List scroll bar: MinimalScrollBar art (ScrollBar.lua pieces: arrows 17 x 11 with hover,
-- track top / middle / bottom, thumb top / middle / flipped top, 8 wide) laid over the client
-- bar. The client bar stays in place at alpha 0 and takes clicks, drags and the wheel through
-- its secure path: scrolling from addon code would run OptionsCategoryFrame_Update outside it
-- and taint the rows (button.element) the click reads. The thumb keeps the client's fixed size.
local BAR = {
	width = 8, tip = 8,
	upArrow = "minimal-scrollbar-arrow-top-c60", upArrowHover = "minimal-scrollbar-arrow-top-over-c60",
	downArrow = "minimal-scrollbar-arrow-bottom-c60", downArrowHover = "minimal-scrollbar-arrow-bottom-over-c60",
	trackTop = "minimal-scrollbar-track-top-c60", trackMiddle = "!minimal-scrollbar-track-middle-c60",
	trackBottom = "minimal-scrollbar-track-bottom-c60",
	cursorTip = "minimal-scrollbar-thumb-top-c60", cursorMiddle = "minimal-scrollbar-thumb-middle-c60",
}

-- Arrow art over a client scroll button. v: overlay frame; atlas, hover: normal and hover art.
local function arrow(v, button, atlas, hover)
	-- At atlas size (17 x 11): a texture without a size takes the size of its sheet.
	local t = v:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(t, atlas)
	t:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:HookScript("OnEnter", function() ForeverUI.SetAtlas(t, hover, true) end)
	button:HookScript("OnLeave", function() ForeverUI.SetAtlas(t, atlas, true) end)
	return t
end

function R.Bar(list)
	local scroll = list.scrollFrame
	local sb = scroll and _G[scroll:GetName() .. "ScrollBar"]
	if not sb then return end
	scroll:SetBackdrop(nil)
	sb:SetAlpha(0)
	local v = CreateFrame("Frame", nil, scroll)
	v:SetFrameLevel(sb:GetFrameLevel() + 5)
	v:SetAllPoints(scroll)
	local b = BAR
	v.top = arrow(v, _G[sb:GetName() .. "ScrollUpButton"], b.upArrow, b.upArrowHover)
	v.down = arrow(v, _G[sb:GetName() .. "ScrollDownButton"], b.downArrow, b.downArrowHover)
	local function slice(atlas, layer)
		local t = v:CreateTexture(nil, layer)
		ForeverUI.SetAtlas(t, atlas)
		t:SetWidth(b.width)
		return t
	end
	local ph = slice(b.trackTop, "BACKGROUND")
	ph:SetPoint("TOP", sb, "TOP", 0, 0)
	local pb = slice(b.trackBottom, "BACKGROUND")
	pb:SetPoint("BOTTOM", sb, "BOTTOM", 0, 0)
	local pm = slice(b.trackMiddle, "BACKGROUND")
	pm:SetPoint("TOP", ph, "BOTTOM", 0, 0)
	pm:SetPoint("BOTTOM", pb, "TOP", 0, 0)
	local thumb = sb:GetThumbTexture()
	local ch = slice(b.cursorTip, "ARTWORK")
	ch:SetHeight(b.tip)
	ch:SetPoint("TOP", thumb, "TOP", 0, 0)
	-- Same piece, flipped, for the bottom.
	local cb = slice(b.cursorTip, "ARTWORK")
	local e = ForeverUI.AtlasEntry(b.cursorTip)
	cb:SetTexCoord(e[2], e[3], e[5], e[4])
	cb:SetHeight(b.tip)
	cb:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
	local cm = slice(b.cursorMiddle, "ARTWORK")
	cm:SetPoint("TOP", ch, "BOTTOM", 0, 0)
	cm:SetPoint("BOTTOM", cb, "TOP", 0, 0)
	v.cursor = { ch, cm, cb }
	list.foreverBar = v
end

-- Skins a client options category list: no border, camelot selection and hover, scroll bar.
function R.List(list)
	if list.foreverCategories then return end
	list.foreverCategories = true
	local name = list:GetName()
	-- No border: hide the eight border textures.
	for _, suffix in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right", "Top", "Bottom" }) do
		local t = _G[name .. suffix]
		if t then
			t:SetAlpha(0)
		end
	end
	for _, b in ipairs(list.buttons or {}) do
		local glow = b:GetHighlightTexture()
		if glow then
			glow:SetTexture(nil)
			glow:SetAlpha(0)
		end
		-- Selection and hover extend 6 px past each side of the row (187 for 175) and follow its
		-- width: the client narrows the row when the scroll bar shows (OptionsList_DisplayScrollBar).
		b.foreverActive = b:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(b.foreverActive, "options_list_active")
		b.foreverActive:SetPoint("LEFT", b, "LEFT", -6, 0)
		b.foreverActive:SetPoint("RIGHT", b, "RIGHT", 6, 0)
		b.foreverActive:Hide()
		b.foreverHover = b:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(b.foreverHover, "options_list_hover")
		b.foreverHover:SetPoint("LEFT", b, "LEFT", -6, 0)
		b.foreverHover:SetPoint("RIGHT", b, "RIGHT", 6, 0)
		b.foreverHover:Hide()
		b:HookScript("OnEnter", function(self)
			self.foreverHovered = true
			paintRow(list, self)
		end)
		b:HookScript("OnLeave", function(self)
			self.foreverHovered = false
			paintRow(list, self)
		end)
	end
	R.Bar(list)
	R.PaintList(list)
end

local function afterListSelect(list)
	if list and list.foreverCategories then
		R.PaintList(list)
	end
end

hooksecurefunc("OptionsList_DisplayButton", function(b)
	local list = b and b:GetParent()
	if list and list.foreverCategories then
		paintRow(list, b)
	end
end)
hooksecurefunc("OptionsList_SelectButton", afterListSelect)
hooksecurefunc("OptionsList_ClearSelection", afterListSelect)
hooksecurefunc("OptionsCategoryFrame_Update", afterListSelect)
for _, name in ipairs({ "InterfaceCategoryList_Update", "InterfaceAddOnsList_Update" }) do
	if type(_G[name]) == "function" then
		hooksecurefunc(name, function()
			afterListSelect(InterfaceOptionsFrameCategories)
			afterListSelect(InterfaceOptionsFrameAddOns)
		end)
	end
end

-- ------------------------------------------------------------ Tabs

-- camelot MinimalTabTemplate on a client tab (PanelTemplates: the selected tab is disabled).
local function paintTab(o)
	local selected = not truthy(o:IsEnabled())
	local suffix = selected and "active_" or ""
	for _, side in ipairs({ "left", "middle", "right" }) do
		-- At atlas size (useAtlasSize): without a size, a texture takes the size of its sheet
		-- (1024 x 1024).
		ForeverUI.SetAtlas(o.foreverArt[side], "options_tab_" .. suffix .. side)
	end
	local text = o:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("BOTTOM", o, "BOTTOM", 0, selected and N.tab.selectedText or N.tab.text)
	end
	o:SetNormalFontObject((selected or o.foreverHovered) and GameFontHighlightSmall or GameFontNormalSmall)
	o:SetWidth((text and text:GetStringWidth() or 0) + N.tab.margin)
end

function R.Tab(o)
	if o.foreverArt then return end
	local name = o:GetName()
	for _, suffix in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
		local t = _G[name .. suffix]
		if t then t:SetAlpha(0) end
	end
	local glow = o:GetHighlightTexture()
	if glow then
		glow:SetTexture(nil)
		glow:SetAlpha(0)
	end
	o:SetHeight(N.tab.height)
	local a = {}
	a.left = o:CreateTexture(nil, "BACKGROUND")
	a.left:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT")
	a.right = o:CreateTexture(nil, "BACKGROUND")
	a.right:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT")
	a.middle = o:CreateTexture(nil, "BACKGROUND")
	a.middle:SetPoint("TOPLEFT", a.left, "TOPRIGHT")
	a.middle:SetPoint("TOPRIGHT", a.right, "TOPLEFT")
	o.foreverArt = a
	o:SetDisabledFontObject(GameFontHighlightSmall)
	o:HookScript("OnEnter", function(self) self.foreverHovered = true; paintTab(self) end)
	o:HookScript("OnLeave", function(self) self.foreverHovered = false; paintTab(self) end)
	o:HookScript("OnShow", paintTab)
	o:HookScript("OnEnable", paintTab)
	o:HookScript("OnDisable", paintTab)
	paintTab(o)
end

-- ------------------------------------------------------------ Inner frame

-- camelot Options_InnerFrame (SettingsPanel, OVERLAY, TOPLEFT (17, -64), 886 x 618 on the
-- optionsc60 sheet): frame around the category list and the settings, with a dark translucent
-- fill, a brown edge, an inward gradient (29 on the sides, 82 at the top, 167 at the bottom)
-- and the list separator (columns 199-200). camelot: top 12 above the list, right edge 17 from
-- the window, tabs on its top. Cut here into 5 x 3 pieces: edges and gradients at their size,
-- separator in place, the rest stretched.
local INNER = {
	cols = { 0, 29, 199, 201, 857, 886 },
	ranks = { 0, 82, 451, 618 },
	left = -1, top = 12, down = -4, right = -17,
}

-- host: parent of the textures; f: the window; list: the category list the frame fits on.
-- Returns the rectangle (an empty frame, for anchors).
function R.Interior(host, f, list)
	local I = INNER
	local e = ForeverUI.AtlasEntry("options_innerframe")
	local rect = CreateFrame("Frame", nil, host)
	rect:SetPoint("TOPLEFT", list, "TOPLEFT", I.left, I.top)
	rect:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", I.left, I.down)
	rect:SetPoint("RIGHT", f, "RIGHT", I.right, 0)
	local W, H = e[6], e[7]
	local du, dv = (e[3] - e[2]) / W, (e[5] - e[4]) / H
	-- Separator where camelot has it: list width from the frame's left edge.
	local sep = list:GetWidth() - I.left - 1
	local xs = { 0, I.cols[2], sep, sep + 2 }
	local pieces = {}
	for c = 1, 5 do
		for r = 1, 3 do
			local t = host:CreateTexture(nil, "ARTWORK")
			t:SetTexture(e[1])
			t:SetTexCoord(e[2] + I.cols[c] * du, e[2] + I.cols[c + 1] * du,
				e[4] + I.ranks[r] * dv, e[4] + I.ranks[r + 1] * dv)
			if c == 5 then
				t:SetPoint("RIGHT", rect, "RIGHT", 0, 0)
				t:SetWidth(I.cols[6] - I.cols[5])
			elseif c == 4 then
				t:SetPoint("LEFT", rect, "LEFT", xs[4], 0)
				t:SetPoint("RIGHT", rect, "RIGHT", -(I.cols[6] - I.cols[5]), 0)
			else
				t:SetPoint("LEFT", rect, "LEFT", xs[c], 0)
				t:SetWidth(xs[c + 1] - xs[c])
			end
			if r == 1 then
				t:SetPoint("TOP", rect, "TOP", 0, 0)
				t:SetHeight(I.ranks[2])
			elseif r == 3 then
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, 0)
				t:SetHeight(I.ranks[4] - I.ranks[3])
			else
				t:SetPoint("TOP", rect, "TOP", 0, -I.ranks[2])
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, I.ranks[4] - I.ranks[3])
			end
			pieces[#pieces + 1] = t
		end
	end
	rect.pieces = pieces
	return rect
end

-- ------------------------------------------------------------ Windows

-- f: client window; rightButtons: right to left, in client order; default: the Defaults
-- button; lists: its category lists; inner: camelot inner frame instead of an inset.
function R.Window(f, rightButtons, default, lists, inner)
	local name = f:GetName()
	f:SetBackdrop(nil)
	_G[name .. "Header"]:SetAlpha(0)
	local title = _G[name .. "HeaderText"]
	title:SetAlpha(0)
	-- camelot window at the client window's level: its child frames (lists, panels, buttons)
	-- draw in front.
	local win = CreateFrame("Frame", nil, f)
	win:SetFrameLevel(f:GetFrameLevel())
	win:SetAllPoints(f)
	local skin = Tpl.Window(win, title:GetText())
	skin.stripes:Hide()
	f.foreverSkin = skin
	-- The close button hides the window (HideUIPanel) instead of clicking Cancel: running the
	-- client's cancel code (BlizzardOptionsPanel_Cancel) from an addon would taint the CVars and
	-- UI variables it rewrites. An unconfirmed change is not applied; the client reads it again
	-- on the next open.
	local closeButton = CreateFrame("Button", name .. "ForeverUICloseButton", f)
	closeButton:SetFrameLevel(f:GetFrameLevel() + 20)
	Tpl.CloseButton(closeButton, f)
	closeButton:SetScript("OnClick", function()
		HideUIPanel(f)
	end)
	f.foreverCloseButton = closeButton
	-- Panel frame: an inset, or the camelot inner frame.
	local container = _G[name .. "PanelContainer"]
	container:SetBackdrop(nil)
	if inner then
		f.foreverInner = R.Interior(win, f, lists[1])
	else
		Tpl.Inset(win, container)
	end
	for _, list in ipairs(lists) do
		R.List(list)
	end
	-- OptionsFrame_OnShow redraws the list through categoryFrame:update(), a reference taken at
	-- load time that a function hook does not see: repaint after the window opens.
	f:HookScript("OnShow", function()
		for _, list in ipairs(lists) do
			R.PaintList(list)
		end
	end)
	-- Buttons: UIPanelButtonTemplate 96 x 22.
	local previous
	for _, b in ipairs(rightButtons) do
		b:SetWidth(N.button[1])
		b:SetHeight(N.button[2])
		Tpl.PanelButton(b)
		b:ClearAllPoints()
		if previous then
			b:SetPoint("RIGHT", previous, "LEFT", -N.buttonGap, 0)
		else
			b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -N.buttonEdge, N.buttonEdge)
		end
		previous = b
	end
	default:SetWidth(N.button[1])
	default:SetHeight(N.button[2])
	Tpl.PanelButton(default)
	default:ClearAllPoints()
	default:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", N.buttonEdge, N.buttonEdge)
	return skin
end

-- ------------------------------------------------------------ Setup

local PANELS = {
	"VideoOptionsResolutionPanel", "VideoOptionsEffectsPanel", "VideoOptionsStereoPanel",
	"AudioOptionsSoundPanel", "AudioOptionsVoicePanel",
	"InterfaceOptionsControlsPanel", "InterfaceOptionsCombatPanel", "InterfaceOptionsDisplayPanel",
	"InterfaceOptionsObjectivesPanel", "InterfaceOptionsSocialPanel", "InterfaceOptionsActionBarsPanel",
	"InterfaceOptionsNamesPanel", "InterfaceOptionsCombatTextPanel", "InterfaceOptionsStatusTextPanel",
	"InterfaceOptionsUnitFramePanel", "InterfaceOptionsBuffsPanel", "InterfaceOptionsBattlenetPanel",
	"InterfaceOptionsCameraPanel", "InterfaceOptionsMousePanel", "InterfaceOptionsFeaturesPanel",
	"InterfaceOptionsHelpPanel", "InterfaceOptionsLanguagesPanel",
}

if VideoOptionsFrame then
	R.Window(VideoOptionsFrame, { VideoOptionsFrameApply, VideoOptionsFrameCancel, VideoOptionsFrameOkay },
		VideoOptionsFrameDefaults, { VideoOptionsFrameCategoryFrame }, true)
end
if AudioOptionsFrame then
	R.Window(AudioOptionsFrame, { AudioOptionsFrameCancel, AudioOptionsFrameOkay },
		AudioOptionsFrameDefaults, { AudioOptionsFrameCategoryFrame }, true)
end
-- Interface window in the camelot layout. In 3.3.5 the lists start at -40, leaving 19 px under
-- the title bar for 26 px tabs. As in camelot: lists at -76, tabs (37 high) on top of the
-- inner frame (-64), 15 from its left edge; the window grows by 36 to keep the list height and
-- the gap to the bottom buttons.
local INTERFACE = { listsY = -76, extraHeight = 36, tabX = 15 }

if InterfaceOptionsFrame then
	local f = InterfaceOptionsFrame
	f:SetHeight(f:GetHeight() + INTERFACE.extraHeight)
	for _, l in ipairs({ InterfaceOptionsFrameCategories, InterfaceOptionsFrameAddOns }) do
		local _, _, _, x = l:GetPoint(1)
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", f, "TOPLEFT", x or 22, INTERFACE.listsY)
	end
	R.Window(f, { InterfaceOptionsFrameCancel, InterfaceOptionsFrameOkay },
		InterfaceOptionsFrameDefaults, { InterfaceOptionsFrameCategories, InterfaceOptionsFrameAddOns }, true)
	for _, s in ipairs({ "Tab1TabSpacer", "Tab2TabSpacer1", "Tab2TabSpacer2" }) do
		local t = _G["InterfaceOptionsFrame" .. s]
		if t then t:SetAlpha(0) end
	end
	R.Tab(InterfaceOptionsFrameTab1)
	R.Tab(InterfaceOptionsFrameTab2)
	InterfaceOptionsFrameTab1:ClearAllPoints()
	InterfaceOptionsFrameTab1:SetPoint("BOTTOMLEFT", f.foreverInner, "TOPLEFT", INTERFACE.tabX, 0)
	InterfaceOptionsFrameTab2:ClearAllPoints()
	InterfaceOptionsFrameTab2:SetPoint("TOPLEFT", InterfaceOptionsFrameTab1, "TOPRIGHT", N.tab.gap, 0)
end
for _, name in ipairs(PANELS) do
	local p = _G[name]
	if p then
		R.Panel(p)
	end
end
