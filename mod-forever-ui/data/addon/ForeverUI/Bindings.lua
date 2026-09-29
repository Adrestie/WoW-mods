-- ForeverUI: the key bindings window (KeyBindingFrame, load-on-demand Blizzard_BindingUI) in
-- Camelot's style, like the settings: the client's rows, buttons and logic stay, and Camelot's
-- window covers the visible part of the 3.3.5 art. Binding buttons are silver buttons
-- (KeyBindingFrameBindingButtonTemplate); the selection mark keeps the 3.3.5 button width (180).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local K = {}

local N = {
	grow = 30, shift = 24,
	window = { g = 4, h = -4, d = -44, b = 12 },   -- visible part of the 3.3.5 art
	command = { 26, -35 }, list = { 27, -53 }, scroll = { 2, -53 },
	checkboxXY = { -245, -12 },
	inner = { g = 15, h = -49, d = -50, b = 3 },  -- b: below the last row
	rows = 17, rowH = 25, rowStep = 23,
	button = { 130, 22 }, edge = 16, gap = 2,
	selectionH = 20, selectionY = -3,
}

local SEP = string.char(92)
local SELECTION = "Interface" .. SEP .. "ForeverUI" .. SEP .. "buttons" .. SEP .. "ui-silver-button-select"

-- selection mark of the chosen button, from KeyBindingFrame.selected and keyID
function K.Paint()
	local f = KeyBindingFrame
	if not f then return end
	for i = 1, N.rows do
		for k = 1, 2 do
			local b = _G["KeyBindingFrameBinding" .. i .. "Key" .. k .. "Button"]
			if b and b.foreverChoice then
				local selected = f.selected ~= nil and b.commandName == f.selected and f.keyID == b:GetID()
				Tpl.SetShown(b.foreverChoice, selected)
			end
		end
	end
end

-- silver button b plus its hidden selection mark
local function skinButton(b)
	Tpl.SilverButton(b)
	local t = b:CreateTexture(nil, "OVERLAY")
	t:SetTexture(SELECTION)
	t:SetBlendMode("ADD")
	t:SetWidth(b:GetWidth())
	t:SetHeight(N.selectionH)
	t:SetPoint("CENTER", b, "CENTER", 0, N.selectionY)
	t:Hide()
	b.foreverChoice = t
end

function K.Skin()
	local f = KeyBindingFrame
	if not f or f.foreverSkin then return end
	-- visible part, plus room for the per-character checkbox under the title bar
	-- (3.3.5 has it in the title bar)
	f:SetHeight(f:GetHeight() + N.grow)
	local win = CreateFrame("Frame", nil, f)
	win:SetFrameLevel(f:GetFrameLevel())
	win:SetPoint("TOPLEFT", f, "TOPLEFT", N.window.g, N.window.h)
	win:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", N.window.d, N.window.b)
	-- 3.3.5 art (six pieces and header) goes to alpha 0
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			r:SetAlpha(0)
		end
	end
	local skin = Tpl.Window(win, KeyBindingFrameHeaderText:GetText())
	skin.stripes:Hide()
	f.foreverSkin = skin
	KeyBindingFrameHeaderText:SetAlpha(0)
	local function title()
		skin.title:SetText(KeyBindingFrameHeaderText:GetText() or "")
	end
	hooksecurefunc(KeyBindingFrameHeaderText, "SetText", title)
	hooksecurefunc(KeyBindingFrameHeaderText, "SetFormattedText", title)
	-- close button acts as Cancel, like Esc: nothing Cancel rewrites (LoadBindings,
	-- KeyBindingFrame.selected) is read by protected client code
	local closeButton = CreateFrame("Button", "KeyBindingFrameForeverUICloseButton", f)
	closeButton:SetFrameLevel(f:GetFrameLevel() + 20)
	Tpl.CloseButton(closeButton, win)
	closeButton:SetScript("OnClick", function()
		KeyBindingFrameCancelButton:Click()
	end)
	f.foreverCloseButton = closeButton

	-- content moves down
	local d = N.shift
	KeyBindingFrameCommandLabel:ClearAllPoints()
	KeyBindingFrameCommandLabel:SetPoint("TOPLEFT", f, "TOPLEFT", N.command[1], N.command[2] - d)
	KeyBindingFrameBinding1:ClearAllPoints()
	KeyBindingFrameBinding1:SetPoint("TOPLEFT", f, "TOPLEFT", N.list[1], N.list[2] - d)
	KeyBindingFrameScrollFrame:ClearAllPoints()
	KeyBindingFrameScrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", N.scroll[1], N.scroll[2] - d)
	KeyBindingFrameCharacterButton:ClearAllPoints()
	KeyBindingFrameCharacterButton:SetPoint("TOPLEFT", f, "TOPRIGHT", N.checkboxXY[1], N.checkboxXY[2] - d)

	-- inner frame around the rows and the bar
	local I = N.inner
	local listBottom = N.list[2] - d - (N.rows - 1) * N.rowStep - N.rowH
	local rect = CreateFrame("Frame", nil, win)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", I.g, I.h - d)
	rect:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", I.d, listBottom - I.b)
	win.foreverRect = rect
	skin.inner = Tpl.InnerFrame(win, rect)

	-- client texts (window regions our background would cover), mirrored above it
	skin.texts = {}
	for _, fs in ipairs({ KeyBindingFrameCommandLabel, KeyBindingFrameKey1Label,
			KeyBindingFrameKey2Label, KeyBindingFrameOutputText }) do
		skin.texts[#skin.texts + 1] = Tpl.Mirror(fs, skin.container, GameFontNormal)
	end

	-- silver buttons and their selection mark
	for i = 1, N.rows do
		for k = 1, 2 do
			local b = _G["KeyBindingFrameBinding" .. i .. "Key" .. k .. "Button"]
			if b then skinButton(b) end
		end
	end

	-- scroll bar, checkbox
	Tpl.Bar(KeyBindingFrameScrollFrameScrollBar)
	ForeverUI.Settings.Checkbox(KeyBindingFrameCharacterButton)

	-- bottom buttons: UIPanelButtonTemplate
	local previous
	for _, b in ipairs({ KeyBindingFrameCancelButton, KeyBindingFrameOkayButton, KeyBindingFrameUnbindButton }) do
		b:SetWidth(N.button[1])
		b:SetHeight(N.button[2])
		Tpl.PanelButton(b)
		b:ClearAllPoints()
		if previous then
			b:SetPoint("RIGHT", previous, "LEFT", -N.gap, 0)
		else
			b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -N.edge, N.edge)
		end
		previous = b
	end
	local default = KeyBindingFrameDefaultButton
	default:SetWidth(N.button[1])
	default:SetHeight(N.button[2])
	Tpl.PanelButton(default)
	default:ClearAllPoints()
	default:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", N.edge, N.edge)

	hooksecurefunc("KeyBindingFrame_Update", K.Paint)
	hooksecurefunc("KeyBindingFrame_SetSelected", K.Paint)
	K.Paint()
end

-- load-on-demand: skin when it loads, or now if already loaded
if KeyBindingFrame then
	K.Skin()
end
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(self, _, name)
	if name == "Blizzard_BindingUI" then
		K.Skin()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
K.watcher = watcher
