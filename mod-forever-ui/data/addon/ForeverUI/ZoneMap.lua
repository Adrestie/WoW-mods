-- ForeverUI: the zone map (BattlefieldMinimap, Shift+M) with camelot's border
-- (blizzard_battlefieldmap). The map keeps its 3.3.5 size (225 x 150): the client places its
-- 56 px tiles. The client border is emptied and hidden, since BattlefieldMinimap_UpdateOpacity
-- resets its alpha. The client close button stays (it resets showBattlefieldMinimap).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local Z = {}
ForeverUI.ZoneMap = Z

local N = {
	corners = {
		{ "battlefieldminimap-border-topleft", "TOPLEFT", -11, 13 },
		{ "battlefieldminimap-border-topright", "TOPRIGHT", 7, 13 },
		{ "battlefieldminimap-border-bottomleft", "BOTTOMLEFT", -11, -7 },
		{ "battlefieldminimap-border-bottomright", "BOTTOMRIGHT", 7, -7 },
	},
	closeButton = { 2, 6 },
	tabText = { -5, -5 },
}

-- As camelot's RefreshAlpha: the border at 1 - opacity.
function Z.Opacity()
	local edge = BattlefieldMinimap and BattlefieldMinimap.foreverEdge
	if not edge then return end
	local o = BattlefieldMinimapOptions and BattlefieldMinimapOptions.opacity or 0
	edge:SetAlpha(1 - o)
end

function Z.Skin()
	local f = BattlefieldMinimap
	if not f or f.foreverEdge then return end
	for _, t in ipairs({ BattlefieldMinimapBackground, BattlefieldMinimapCorner }) do
		t:SetTexture(nil)
		t:Hide()
	end
	local edge = CreateFrame("Frame", nil, f)
	edge:SetFrameStrata("HIGH")
	edge:SetAllPoints(f)
	local p = {}
	for i, c in ipairs(N.corners) do
		local t = edge:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, c[1])
		t:SetPoint(c[2], edge, c[2], c[3], c[4])
		p[i] = t
	end
	local function side(atlas, pointA, targetA, relativeA, pointB, targetB, relativeB)
		local t = edge:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetPoint(pointA, targetA, relativeA, 0, 0)
		t:SetPoint(pointB, targetB, relativeB, 0, 0)
		return t
	end
	p[5] = side("battlefieldminimap-border-top", "TOPLEFT", p[1], "TOPRIGHT", "BOTTOMRIGHT", p[2], "BOTTOMLEFT")
	p[6] = side("battlefieldminimap-border-bottom", "TOPLEFT", p[3], "TOPRIGHT", "BOTTOMRIGHT", p[4], "BOTTOMLEFT")
	p[7] = side("battlefieldminimap-border-left", "TOPLEFT", p[1], "BOTTOMLEFT", "BOTTOMRIGHT", p[3], "TOPRIGHT")
	p[8] = side("battlefieldminimap-border-right", "TOPLEFT", p[2], "BOTTOMLEFT", "BOTTOMRIGHT", p[4], "TOPRIGHT")
	edge.pieces = p
	f.foreverEdge = edge
	-- Close button in camelot style, raised above the border
	local x = BattlefieldMinimapCloseButton
	Tpl.CloseButton(x, f)
	x:ClearAllPoints()
	x:SetPoint("TOPRIGHT", f, "TOPRIGHT", N.closeButton[1], N.closeButton[2])
	x:SetFrameStrata("HIGH")
	x:SetFrameLevel(edge:GetFrameLevel() + 1)
	-- Tab: text at camelot's place
	local text = BattlefieldMinimapTabText
	if text then
		text:ClearAllPoints()
		text:SetPoint("LEFT", BattlefieldMinimapTabLeft, "RIGHT", N.tabText[1], N.tabText[2])
	end
	hooksecurefunc("BattlefieldMinimap_UpdateOpacity", Z.Opacity)
	Z.Opacity()
end

Z.Skin()

-- Blizzard_BattlefieldMinimap is load-on-demand: skin it when it loads.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_BattlefieldMinimap" then
		Z.Skin()
	end
end)
