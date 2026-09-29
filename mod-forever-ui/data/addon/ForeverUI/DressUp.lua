-- ForeverUI: the dressing room (DressUpFrame) in the camelot style (mainline/dressupframes.xml).
-- The client's model, rotation arrows, buttons and race background are kept and moved; the
-- 3.3.5 art, portrait and instructions are hidden (camelot shows no instructions). Minimizing
-- and transmog sets have no 3.3.5 equivalent and are not reproduced.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local D = {}

local SEP = string.char(92)

-- camelot sizes and offsets (dressupframes.xml). portrait: 48 px centred on the ring hole,
-- as the unit portrait of Inspect.lua
local N = {
	window = { 450, 545 },
	portrait = { side = 48, x = 1, y = 1.5 },
	inset = { 4, -60, -6, 26 },
	scene = { 7, -63, -9, 28 },
	background = { right = 85, top = 348, down = 175 },
	arrows = { y = -10, gap = 4 },
	button = { 80, 22 }, cancel = { -7, 4 },
}

-- Re-anchors region r to a single point (SetPoint arguments).
local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

function D.Portrait()
	local skin = DressUpFrame and DressUpFrame.foreverSkin
	if skin then SetPortraitTexture(skin.portrait, "player") end
end

-- Reskins the client DressUpFrame once (foreverSkin marks it done).
function D.Skin()
	local f = DressUpFrame
	if not f or f.foreverSkin then return end
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	-- hide the 3.3.5 art: the four unnamed textures, the portrait, the texts
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then
			r:SetAlpha(0)
		end
	end
	for _, r in ipairs({ DressUpFramePortrait, DressUpFrameTitleText, DressUpFrameDescriptionText }) do
		r:SetAlpha(0)
	end
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = DRESSUP_FRAME,
	})
	f.foreverSkin = skin
	-- ButtonFrameTemplate inset: marble and trim, as regions
	local E = N.inset
	local rect = CreateFrame("Frame", nil, f)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", E[1], E[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", E[3], E[4])
	local marble = f:CreateTexture(nil, "BACKGROUND")
	marble:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble", true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(rect)
	skin.frameBox = Tpl.NineSlice(f, "InsetFrameTemplate", rect)
	skin.marble = marble
	-- scene: the model over the race background. The two bottom pieces are cropped to the scene:
	-- at camelot's 175 they would overflow the window. 3.3.5 has no scene control (zoom, rotate,
	-- reset), so the two rotation arrows take its place at the top of the scene.
	local S = N.scene
	local scene = CreateFrame("Frame", nil, f)
	scene:SetPoint("TOPLEFT", f, "TOPLEFT", S[1], S[2])
	scene:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", S[3], S[4])
	skin.scene = scene
	local F = N.background
	local visible = (N.window[2] + S[2] - S[4]) - F.top
	place(DressUpBackgroundTopLeft, "TOPLEFT", scene, "TOPLEFT", 0, 0)
	DressUpBackgroundTopLeft:SetPoint("TOPRIGHT", scene, "TOPRIGHT", -F.right, 0)
	DressUpBackgroundTopLeft:SetHeight(F.top)
	place(DressUpBackgroundTopRight, "TOPRIGHT", scene, "TOPRIGHT", 0, 0)
	DressUpBackgroundTopRight:SetWidth(F.right)
	DressUpBackgroundTopRight:SetHeight(F.top)
	place(DressUpBackgroundBotLeft, "TOPLEFT", DressUpBackgroundTopLeft, "BOTTOMLEFT", 0, 0)
	DressUpBackgroundBotLeft:SetPoint("TOPRIGHT", DressUpBackgroundTopLeft, "BOTTOMRIGHT", 0, 0)
	place(DressUpBackgroundBotRight, "TOPRIGHT", DressUpBackgroundTopRight, "BOTTOMRIGHT", 0, 0)
	DressUpBackgroundBotRight:SetWidth(F.right)
	for _, t in ipairs({ DressUpBackgroundBotLeft, DressUpBackgroundBotRight }) do
		t:SetHeight(visible)
		t:SetTexCoord(0, 1, 0, visible / F.down)
	end
	place(DressUpModel, "TOPLEFT", scene, "TOPLEFT", 0, 0)
	DressUpModel:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", 0, 0)
	local left, right = DressUpModelRotateLeftButton, DressUpModelRotateRightButton
	local half = left:GetWidth() / 2 + N.arrows.gap / 2
	place(left, "TOP", scene, "TOP", -half, N.arrows.y)
	place(right, "TOP", scene, "TOP", half, N.arrows.y)
	ForeverUI.RotateWithMouse(DressUpModel)
	-- close button above the metal; camelot's two buttons (Cancel, Reset)
	Tpl.CloseButton(DressUpFrameCloseButton, f)
	DressUpFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	for _, b in ipairs({ DressUpFrameCancelButton, DressUpFrameResetButton }) do
		b:SetWidth(N.button[1])
		b:SetHeight(N.button[2])
		Tpl.PanelButton(b)
	end
	place(DressUpFrameCancelButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.cancel[1], N.cancel[2])
	place(DressUpFrameResetButton, "RIGHT", DressUpFrameCancelButton, "LEFT", 0, 0)
	f:HookScript("OnShow", D.Portrait)
	D.Portrait()
end

D.Skin()
