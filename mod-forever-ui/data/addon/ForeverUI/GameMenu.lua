-- ForeverUI : le menu Echap (GameMenuFrame), a la DA de camelot (demande de
-- l'utilisateur, 2026-09-28 : « fait le menu et reglages », etape 1).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (GameMenuFrame.xml de 3.3.5) : 195 x 240
-- au CENTRE, strate DIALOG ; <Backdrop> UI-DialogBox, en-tete
-- UI-DialogBox-Header et un texte SANS NOM (GameFontNormal, MAIN_MENU) ;
-- boutons GameMenuButtonTemplate a 1 l'un sous l'autre : Video, Sound &
-- Voice, Interface, (Mac, cache hors Mac), Key Bindings, Macros, (Ratings,
-- cache), Logout, Exit Game, puis Return to Game a 16. Logout et Exit Game se
-- grisent a leur OnShow quand une deconnexion est en cours.
-- Deja ajoutes au menu : l'AddOns d'ACP (patch-5.mpq) sous Macros, qui a
-- son OnShow repose Log Out sous lui et grandit le menu de 25 ; la demande
-- d'aide de ForeverUI (BottomBar.lua, 26/09), entre deux espaces.
--
-- RELEVE -- CAMELOT : blizzard_gamemenu/shared/gamemenuframe.xml / .lua et
-- blizzard_sharedxml/mainline/frame/mainmenuframetemplates.xml / shared/
-- frame/mainmenuframetemplates.lua -- MainMenuFrameTemplate :
--   colonne verticale : marges 48 (haut), 34 (bas), 28 (gauche et droite),
--   ecart 0 ; une section ajoute 20 au-dessus du bouton qui la commence ;
--   Close (Return to Game) precede d'une section ;
--   DialogBorderTemplate ; en-tete DialogHeaderTemplate a TOP (0, 11), texte
--   MAINMENU_BUTTON, police GameFontNormalMed1 (dialogHeaderFont du
--   GameMenuFrame) ;
--   boutons MainMenuFrameButtonTemplate : BigRedThreeSliceButtonTemplate
--   (128-RedButton) 200 x 36, GameFontHighlightLarge / DisableLarge.
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : les boutons restent
-- ceux du client, dans son ordre -- leur clic est securise (Logout, Quit),
-- un bouton a nous ne le serait pas. Les sections sont celles du menu
-- valide le 26/09 (reglages, Macros et AddOns | aide | Log Out et Exit Game |
-- Return to Game), avec l'ecart de camelot : 20 (il etait de 16, celui que
-- le client laissait avant Return to Game).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local M = {}
ForeverUI.GameMenu = M

local N = {
	haut = 48, bas = 34, cote = 28,
	bouton = { 200, 36 },
	section = 20,
}

-- GameFontNormalMed1 de camelot : SystemFont_Med2 (FRIZQT 13), ombre (1, -1),
-- jaune
local function policeEnTete()
	local f = CreateFont("ForeverUIGameMenuHeaderFont")
	f:SetFontObject(SystemFont_Med2 or GameFontNormal)
	f:SetShadowOffset(1, -1)
	f:SetShadowColor(0, 0, 0)
	f:SetTextColor(1, 0.82, 0)
	return f
end

-- les boutons, de haut en bas ; section : un ecart au-dessus
local function entrees()
	return {
		{ GameMenuButtonOptions },
		{ GameMenuButtonSoundOptions },
		{ GameMenuButtonMacOptions },
		{ GameMenuButtonUIOptions },
		{ GameMenuButtonKeybindings },
		{ GameMenuButtonMacros },
		{ GameMenuButtonRatings },
		{ _G["GameMenuButtonAddOns"] },
		{ _G["ForeverUIGameMenuButtonHelp"], section = true },
		{ GameMenuButtonLogout, section = true },
		{ GameMenuButtonQuit },
		{ GameMenuButtonContinue, section = true },
	}
end

local POLICES = { GameFontHighlightLarge, GameFontHighlightLarge, GameFontDisableLarge }

local function habillerBouton(b)
	if b.foreverTrois then return end
	b:SetWidth(N.bouton[1])
	b:SetHeight(N.bouton[2])
	Gb.BoutonTroisTranches(b, "128-redbutton", POLICES)
	b:HookScript("OnShow", M.Disposer)
end

-- la colonne : chaque bouton montre a sa place, puis la taille du menu.
-- Rejouee a chaque OnShow d'un bouton : l'AddOns d'ACP et Log Out (quand
-- Ratings est montre) reposent Log Out au leur, apres le menu.
function M.Disposer()
	local f = GameMenuFrame
	local y = N.haut
	local enAttente = false
	for _, e in ipairs(entrees()) do
		local b = e[1]
		if e.section then
			enAttente = true
		end
		if b and b:IsShown() then
			habillerBouton(b)
			if enAttente then
				y = y + N.section
				enAttente = false
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f, "TOPLEFT", N.cote, -y)
			y = y + N.bouton[2]
		end
	end
	f:SetWidth(N.cote + N.bouton[1] + N.cote)
	f:SetHeight(y + N.bas)
end

if GameMenuFrame then
	local f = GameMenuFrame
	f:SetBackdrop(nil)
	if GameMenuFrameHeader then
		GameMenuFrameHeader:SetAlpha(0)
	end
	-- le titre du client n'a pas de nom : c'est le texte MAIN_MENU du cadre
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == MAIN_MENU then
			r:SetAlpha(0)
		end
	end
	Gb.CadreDialogue(f)
	M.entete = Gb.EnTete(f, MAINMENU_BUTTON, policeEnTete())
	for _, e in ipairs(entrees()) do
		if e[1] then
			habillerBouton(e[1])
		end
	end
	-- un bouton arrive apres nous (l'AddOns d'ACP) est habille par la
	-- colonne, a la premiere ouverture
	f:HookScript("OnShow", M.Disposer)
	M.Disposer()
end
