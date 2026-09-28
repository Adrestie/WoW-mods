-- ForeverUI : la carte de zone (BattlefieldMinimap, Maj+M), a la DA de
-- camelot (demande de l'utilisateur, 2026-09-28 : « fait le reste des
-- fenetres secondaires »).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (Blizzard_BattlefieldMinimap.xml / .lua
-- de 3.3.5, charge a la demande) :
--   BattlefieldMinimap 225 x 150, strate BACKGROUND, sous son onglet
--     (BattlefieldMinimapTab, art ChatFrameTab, texte a (0, -5) de son bout
--     gauche) ; douze tuiles de 56, les calques de la zone ;
--   le cadre : BattlefieldMinimapBackground (UI-BattlefieldMinimap-Border,
--     256 x 256 a (-12, 12), OVERLAY) et BattlefieldMinimapCorner
--     (UI-DialogBox-Corner a TOPRIGHT (-2, 3)) ;
--   BattlefieldMinimapCloseButton (UIPanelCloseButton) a TOPRIGHT (2, 7) ;
--   BattlefieldMinimap_UpdateOpacity repose l'alpha du cadre, du coin, de
--     la croix (1 - opacite) a chaque ouverture et a chaque reglage.
--
-- RELEVE -- CAMELOT (blizzard_battlefieldmap/mainline, le [Family] de
-- camelot) :
--   BattlefieldMapFrame 300 x 200 ; BorderFrame en strate HIGH sur tout le
--     cadre : coins battlefieldminimap-border-topleft (-11, 13), -topright
--     (7, 13), -bottomleft (-11, -7), -bottomright (7, -7) a leur taille,
--     bords -top, -bottom, -left, -right etires entre eux ; croix
--     UIPanelCloseButton a TOPRIGHT (2, 6) du BorderFrame ;
--   RefreshAlpha : le BorderFrame a 1 - opacite ;
--   BattlefieldMapTab : le meme art que 3.3.5, texte a (-5, -5).
--
-- CE QUI DIFFERE, ET POURQUOI. La carte garde la taille de 3.3.5
-- (225 x 150) : ses tuiles de 56 sont posees par le client. Le cadre de
-- 3.3.5 perd son image et se cache -- l'alpha seul ne tiendrait pas,
-- BattlefieldMinimap_UpdateOpacity le repose. La croix du client reste la
-- sienne (elle remet showBattlefieldMinimap a 0), montee en strate HIGH
-- au-dessus du cadre de camelot.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local Z = {}
ForeverUI.CarteDeZone = Z

local N = {
	coins = {
		{ "battlefieldminimap-border-topleft", "TOPLEFT", -11, 13 },
		{ "battlefieldminimap-border-topright", "TOPRIGHT", 7, 13 },
		{ "battlefieldminimap-border-bottomleft", "BOTTOMLEFT", -11, -7 },
		{ "battlefieldminimap-border-bottomright", "BOTTOMRIGHT", 7, -7 },
	},
	croix = { 2, 6 },
	texteOnglet = { -5, -5 },
}

function Z.Opacite()
	local bord = BattlefieldMinimap and BattlefieldMinimap.foreverBord
	if not bord then return end
	local o = BattlefieldMinimapOptions and BattlefieldMinimapOptions.opacity or 0
	bord:SetAlpha(1 - o)
end

function Z.Habiller()
	local f = BattlefieldMinimap
	if not f or f.foreverBord then return end
	for _, t in ipairs({ BattlefieldMinimapBackground, BattlefieldMinimapCorner }) do
		t:SetTexture(nil)
		t:Hide()
	end
	local bord = CreateFrame("Frame", nil, f)
	bord:SetFrameStrata("HIGH")
	bord:SetAllPoints(f)
	local p = {}
	for i, c in ipairs(N.coins) do
		local t = bord:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, c[1])
		t:SetPoint(c[2], bord, c[2], c[3], c[4])
		p[i] = t
	end
	local function cote(atlas, pointA, cibleA, relatifA, pointB, cibleB, relatifB)
		local t = bord:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetPoint(pointA, cibleA, relatifA, 0, 0)
		t:SetPoint(pointB, cibleB, relatifB, 0, 0)
		return t
	end
	p[5] = cote("battlefieldminimap-border-top", "TOPLEFT", p[1], "TOPRIGHT", "BOTTOMRIGHT", p[2], "BOTTOMLEFT")
	p[6] = cote("battlefieldminimap-border-bottom", "TOPLEFT", p[3], "TOPRIGHT", "BOTTOMRIGHT", p[4], "BOTTOMLEFT")
	p[7] = cote("battlefieldminimap-border-left", "TOPLEFT", p[1], "BOTTOMLEFT", "BOTTOMRIGHT", p[3], "TOPRIGHT")
	p[8] = cote("battlefieldminimap-border-right", "TOPLEFT", p[2], "BOTTOMLEFT", "BOTTOMRIGHT", p[4], "TOPRIGHT")
	bord.pieces = p
	f.foreverBord = bord
	-- la croix de camelot, au-dessus du cadre
	local x = BattlefieldMinimapCloseButton
	Gb.Croix(x, f)
	x:ClearAllPoints()
	x:SetPoint("TOPRIGHT", f, "TOPRIGHT", N.croix[1], N.croix[2])
	x:SetFrameStrata("HIGH")
	x:SetFrameLevel(bord:GetFrameLevel() + 1)
	-- l'onglet : le texte a la place de camelot
	local texte = BattlefieldMinimapTabText
	if texte then
		texte:ClearAllPoints()
		texte:SetPoint("LEFT", BattlefieldMinimapTabLeft, "RIGHT", N.texteOnglet[1], N.texteOnglet[2])
	end
	hooksecurefunc("BattlefieldMinimap_UpdateOpacity", Z.Opacite)
	Z.Opacite()
end

Z.Habiller()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(_, _, nom)
	if nom == "Blizzard_BattlefieldMinimap" then
		Z.Habiller()
	end
end)
