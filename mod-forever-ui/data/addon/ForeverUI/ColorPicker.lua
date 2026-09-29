-- Color picker (ColorPickerFrame) and small opacity window (OpacityFrame) in camelot style
-- (blizzard_colorpickerframe/mainline): DialogBorderTemplate, DialogHeaderTemplate; N holds
-- camelot's sizes and offsets (388 x 210, 331 wide without opacity).
-- The client's opacity slider stays (value and OnValueChanged) and takes the place and look
-- of camelot's opacity column: checkerboard, gradient of the chosen color from opaque (top,
-- the client's "+" side) to transparent, arrow thumb; its "-", "+" and "Opacity" texts
-- are hidden.
-- camelot's ColorSwatchOriginal and hex field have no 3.3.5 counterpart: not added.
-- OpacityFrame gets only the dialog border; its slider keeps 3.3.5's BACKDROP_SLIDER_8_8 art.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local CP = {}
ForeverUI.Colors = CP

local SEP = string.char(92)

local N = {
	width = 388, widthNoOpacity = 331, height = 210,
	wheel = { 23, -37 },
	colorSwatch = { l = 47, h = 25, x = -100, y = -37 },
	opacity = { x = -157, y = -37, l = 32, h = 128 },
	cursor = { l = 48, h = 14, uv = { 0.25, 1, 0, 0.875 } },
	button = { 154, 22 }, footerY = 12,
}

-- Opacity column: gradient of the chosen color over the checkerboard
function CP.Gradient()
	local s = OpacitySliderFrame
	local d = s and s.foreverGradient
	if not d then return end
	local r, g, b = ColorPickerFrame:GetColorRGB()
	d:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 1)
end

function CP.Skin()
	local f = ColorPickerFrame
	if not f or f.foreverSkin then return end
	f:SetBackdrop(nil)
	f:SetHeight(N.height)
	local frame, background = Tpl.DialogFrame(f)
	-- client's header (named texture and unnamed text)
	ColorPickerFrameHeader:SetAlpha(0)
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == COLOR_PICKER then
			r:SetAlpha(0)
		end
	end
	local header = Tpl.Header(f, COLOR_PICKER, GameFontNormal)
	f.foreverSkin = { frame = frame, background = background, header = header }

	-- wheel (camelot: ColorPicker (23, -30) + wheel (0, -7); the value bar follows, 24 right),
	-- current swatch
	ColorPickerWheel:ClearAllPoints()
	ColorPickerWheel:SetPoint("TOPLEFT", f, "TOPLEFT", N.wheel[1], N.wheel[2])
	ColorSwatch:SetWidth(N.colorSwatch.l)
	ColorSwatch:SetHeight(N.colorSwatch.h)
	ColorSwatch:ClearAllPoints()
	ColorSwatch:SetPoint("TOPLEFT", f, "TOPRIGHT", N.colorSwatch.x, N.colorSwatch.y)

	-- camelot's opacity column on the client's slider: checkerboard, gradient, and the
	-- UI-ColorPicker-Buttons thumb (48 x 14, like camelot's value bar)
	local s = OpacitySliderFrame
	local O = N.opacity
	s:SetBackdrop(nil)
	s:SetWidth(O.l)
	s:SetHeight(O.h)
	s:ClearAllPoints()
	s:SetPoint("TOPLEFT", f, "TOPRIGHT", O.x, O.y)
	for _, r in ipairs({ s:GetRegions() }) do
		if r:GetObjectType() == "FontString" then r:SetAlpha(0) end
	end
	local checkerboard = s:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(checkerboard, "colorpicker-checkerboard")
	checkerboard:SetAllPoints(s)
	local gradient = s:CreateTexture(nil, "BORDER")
	gradient:SetTexture(1, 1, 1, 1)
	gradient:SetAllPoints(s)
	s.foreverGradient = gradient
	local K = N.cursor
	s:SetThumbTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-ColorPicker-Buttons")
	local thumb = s:GetThumbTexture()
	thumb:SetTexCoord(K.uv[1], K.uv[2], K.uv[3], K.uv[4])
	thumb:SetWidth(K.l)
	thumb:SetHeight(K.h)
	f.foreverSkin.checkerboard = checkerboard

	-- buttons: UIPanelButtonTemplate 154 x 22, the pair centered
	for _, b in ipairs({ ColorPickerOkayButton, ColorPickerCancelButton }) do
		b:SetWidth(N.button[1])
		b:SetHeight(N.button[2])
		Tpl.PanelButton(b)
		b:ClearAllPoints()
	end
	ColorPickerOkayButton:SetPoint("BOTTOMRIGHT", f, "BOTTOM", 0, N.footerY)
	ColorPickerCancelButton:SetPoint("BOTTOMLEFT", f, "BOTTOM", 0, N.footerY)

	-- after the client's OnShow (365 / 305): camelot's widths
	f:HookScript("OnShow", function(self)
		self:SetWidth(self.hasOpacity and N.width or N.widthNoOpacity)
		CP.Gradient()
	end)
	f:HookScript("OnColorSelect", CP.Gradient)

	-- small opacity window: its border only
	if OpacityFrame then
		OpacityFrame:SetBackdrop(nil)
		OpacityFrame.foreverSkin = { Tpl.DialogFrame(OpacityFrame) }
	end
end

CP.Skin()
