-- ForeverUI: camelot borders on the game's confirmation boxes (StaticPopup1 to 4).
-- camelot (gamedialog.xml): UI-DiamondDialogBox-Border nine-sliced over the box,
-- UI-DialogBox-Background-Dark tiled 7 inside it, RedButton-Exit close button at (-3, -3).
-- Only the borders change: size, layout, texts and buttons stay the client's.
-- StaticPopup_Show re-sets the close button textures on each show, so we re-skin it after.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local D = {}

local N = { background = 7, closeButton = { -3, -3 }, boxes = 4 }

-- Apply an atlas to one close button state, stretched over the button.
-- place, read: setter and getter names of that state (e.g. SetNormalTexture)
local function applyCloseState(b, place, read, atlas)
	local e = ForeverUI.AtlasEntry(atlas)
	if not e then return end
	b[place](b, e[1])
	local t = b[read](b)
	t:SetTexCoord(e[2], e[3], e[4], e[5])
	t:ClearAllPoints()
	t:SetAllPoints(b)
end

-- camelot close button: minimize style for closeButtonIsHide boxes, exit otherwise
function D.CloseButton(f)
	local b = _G[f:GetName() .. "CloseButton"]
	if not b or not b:IsShown() then return end
	local info = f.which and StaticPopupDialogs[f.which]
	if info and info.closeButtonIsHide then
		applyCloseState(b, "SetNormalTexture", "GetNormalTexture", "redbutton-minicondense")
		applyCloseState(b, "SetPushedTexture", "GetPushedTexture", "redbutton-minicondense-pressed")
	else
		applyCloseState(b, "SetNormalTexture", "GetNormalTexture", "redbutton-exit")
		applyCloseState(b, "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed")
	end
end

function D.Skin(f)
	if not f or f.foreverSkin then return end
	f:SetBackdrop(nil)
	-- BG.Bottom: dark tiled background, 7 inside the edge
	local background = f:CreateTexture(nil, "BACKGROUND")
	local e = ForeverUI.AtlasEntry("ui-dialogbox-background-dark")
	background:SetTexture(e[1], true)
	if background.SetHorizTile then
		background:SetHorizTile(true)
		background:SetVertTile(true)
	end
	background:SetPoint("TOPLEFT", f, "TOPLEFT", N.background, -N.background)
	background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -N.background, N.background)
	-- BG.Top: nine-sliced border over the whole box
	local edge = Tpl.StretchedAtlas(f, "ui-diamonddialogbox-border", "BORDER")
	edge.rect:SetAllPoints(f)
	-- camelot close button, at camelot's place
	local closeButton = _G[f:GetName() .. "CloseButton"]
	if closeButton then
		Tpl.CloseButton(closeButton, f)
		closeButton:ClearAllPoints()
		closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", N.closeButton[1], N.closeButton[2])
	end
	f.foreverSkin = { background = background, edge = edge, closeButton = closeButton }
end

for i = 1, N.boxes do
	D.Skin(_G["StaticPopup" .. i])
end

hooksecurefunc("StaticPopup_Show", function()
	for i = 1, N.boxes do
		local f = _G["StaticPopup" .. i]
		if f and f:IsShown() then D.CloseButton(f) end
	end
end)
