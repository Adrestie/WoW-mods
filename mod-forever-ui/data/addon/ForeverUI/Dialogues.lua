-- ForeverUI : les boites de confirmation du jeu (StaticPopup1 a 4), aux
-- contours de camelot (demande de l'utilisateur du 2026-09-28, a la
-- confirmation d'un remplacement de sertissage ; regle de l'atelier : tous
-- les dialogues a la DA de camelot).
--
-- RELEVE -- CAMELOT (blizzard_staticpopup_game/gamedialog.xml, gamedialog.lua
-- et mainline/gamedialog.lua) :
--   StaticPopupBaseTemplate   cadre BG sur toute la boite : BG.Top =
--                             GameDialogBackgroundTop (UI-DiamondDialogBox-
--                             Border, variante c60, decoupe en neuf 32 / 32 /
--                             32 / 32) sur toute la boite ; BG.Bottom = UI-
--                             DialogBox-Background-Dark (mosaique) de (7, -7)
--                             a (-7, 7), sous la bordure
--   la croix                  UIPanelCloseButton a TOPRIGHT (-3, -3) :
--                             RedButton-Exit / -exit-pressed, ou RedButton-
--                             MiniCondense / -pressed pour une boite qui se
--                             cache (SetCloseButtonToMinimize)
--   les boutons               StaticPopupButtonTemplate, UI-DialogBox-Button-*
--                             : les memes images qu'en 3.3.5
--
-- RELEVE -- 3.3.5 (FrameXML/StaticPopup.xml et .lua) : StaticPopupTemplate
-- 320 x 72, Backdrop UI-DialogBox-Background / UI-DialogBox-Border (marges
-- 11, 12, 12, 11) ; croix UIPanelCloseButton a (-3, -3), dont StaticPopup_Show
-- repose les images a chaque ouverture (UI-Panel-HideButton si
-- closeButtonIsHide, UI-Panel-MinimizeButton sinon).
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * Seuls les contours changent : le Backdrop est retire, le fond sombre et
--     la bordure de camelot prennent sa place. La taille, la mise en page,
--     les textes et les boutons restent ceux du client, qui decide de tout.
--   * La croix est rhabillee APRES StaticPopup_Show, qui repose les siennes.
--   * Les quatre boites servent a toutes les confirmations du jeu : toutes
--     prennent ces contours.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local D = {}
ForeverUI.Dialogues = D

local N = { fond = 7, croix = { -3, -3 }, boites = 4 }

-- l'image d'un etat de la croix, a la taille du bouton
local function etatCroix(b, poser, lire, atlas)
	local e = ForeverUI.AtlasEntry(atlas)
	if not e then return end
	b[poser](b, e[1])
	local t = b[lire](b)
	t:SetTexCoord(e[2], e[3], e[4], e[5])
	t:ClearAllPoints()
	t:SetAllPoints(b)
end

-- la croix de camelot, selon la boite (apres StaticPopup_Show)
function D.Croix(f)
	local b = _G[f:GetName() .. "CloseButton"]
	if not b or not b:IsShown() then return end
	local info = f.which and StaticPopupDialogs[f.which]
	if info and info.closeButtonIsHide then
		etatCroix(b, "SetNormalTexture", "GetNormalTexture", "redbutton-minicondense")
		etatCroix(b, "SetPushedTexture", "GetPushedTexture", "redbutton-minicondense-pressed")
	else
		etatCroix(b, "SetNormalTexture", "GetNormalTexture", "redbutton-exit")
		etatCroix(b, "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed")
	end
end

function D.Habiller(f)
	if not f or f.foreverHabit then return end
	f:SetBackdrop(nil)
	-- BG.Bottom : le fond sombre, en mosaique, a 7 du bord
	local fond = f:CreateTexture(nil, "BACKGROUND")
	local e = ForeverUI.AtlasEntry("ui-dialogbox-background-dark")
	fond:SetTexture(e[1], true)
	if fond.SetHorizTile then
		fond:SetHorizTile(true)
		fond:SetVertTile(true)
	end
	fond:SetPoint("TOPLEFT", f, "TOPLEFT", N.fond, -N.fond)
	fond:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -N.fond, N.fond)
	-- BG.Top : la bordure, decoupee en neuf, sur toute la boite
	local bord = Gb.AtlasEtire(f, "ui-diamonddialogbox-border", "BORDER")
	bord.rect:SetAllPoints(f)
	-- la croix : celle de camelot, a sa place
	local croix = _G[f:GetName() .. "CloseButton"]
	if croix then
		Gb.Croix(croix, f)
		croix:ClearAllPoints()
		croix:SetPoint("TOPRIGHT", f, "TOPRIGHT", N.croix[1], N.croix[2])
	end
	f.foreverHabit = { fond = fond, bord = bord, croix = croix }
end

for i = 1, N.boites do
	D.Habiller(_G["StaticPopup" .. i])
end

hooksecurefunc("StaticPopup_Show", function()
	for i = 1, N.boites do
		local f = _G["StaticPopup" .. i]
		if f and f:IsShown() then D.Croix(f) end
	end
end)
