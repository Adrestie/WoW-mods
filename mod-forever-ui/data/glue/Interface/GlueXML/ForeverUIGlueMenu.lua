-- ForeverUI : le menu des ecrans d'accueil (GlueMenuFrame de camelot).
--
-- RELEVE -- blizzard_gluemenuframe/mainline/gluemenuframe.xml et .lua,
-- blizzard_sharedxml/mainline/frame/mainmenuframetemplates.xml,
-- shared/frame/mainmenuframetemplates.lua, layoutframe.lua (VerticalLayout) :
--   * MainMenuFrameTemplate : colonne verticale, marges 48 (haut), 34 (bas),
--     28 (gauche et droite), ecart 0 ; DialogBorderTemplate ; en-tete
--     DialogHeaderTemplate MAINMENU_BUTTON a TOP (0, 11), police GlueFontNormal
--     (dialogHeaderFont) ; strate DIALOG, au CENTRE de GlueParent ;
--   * boutons GlueMenuFrameButtonTemplate : 200 x 36, rouges (128-RedButton),
--     GlueFontNormal / Highlight / Disable ; une section ajoute 20 au-dessus
--     du bouton suivant ; Close precede d'une section ;
--   * a la connexion : Options | Credits, Cinematics, Manage Account,
--     Community Site, Exit Game | Close ;
--   * GlueParent_AddModalFrame : voile noir a 0,5 (BlockingFrame, strate
--     HIGH), Echap ferme la fenetre du dessus.
-- Chaque bouton declenche le bouton du client 3.3.5 qui fait la meme chose.

local G = ForeverUIGlue

-- MAINMENU_BUTTON n'existe pas dans 3.3.5 : le texte de camelot
local TITRE = "Game Menu"

local voile = CreateFrame("Frame", "ForeverUIGlueMenuVoile", GlueParent)
voile:SetAllPoints(GlueParent)
voile:SetFrameStrata("HIGH")
voile:EnableMouse(true)
voile:EnableKeyboard(true)
voile:Hide()
local noir = voile:CreateTexture(nil, "BACKGROUND")
noir:SetAllPoints(voile)
noir:SetTexture(0, 0, 0, 0.5)

local menu = CreateFrame("Frame", "ForeverUIGlueMenuFrame", GlueParent)
menu:SetFrameStrata("DIALOG")
menu:SetToplevel(true)
menu:EnableMouse(true)
menu:SetPoint("CENTER", GlueParent, "CENTER")
menu:SetWidth(260)
menu:SetHeight(1)
menu:Hide()
G.CadreDialogue(menu)
G.EnTeteDialogue(menu, TITRE, "GlueFontNormal")

local MARGE_HAUT, MARGE_BAS, MARGE_COTE = 48, 34, 28
local BOUTON_L, BOUTON_H, SECTION = 200, 36, 20

local boutons = {}
local entrees = {}

local function fermer()
	PlaySound("igMainMenuContinue")
	menu:Hide()
end

local function mettreEnPage()
	local y = MARGE_HAUT
	for i, entree in ipairs(entrees) do
		local b = boutons[i]
		if not b then
			b = G.CreerBoutonTroisTranches("ForeverUIGlueMenuButton" .. i, menu, BOUTON_L, BOUTON_H,
				"128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
			boutons[i] = b
		end
		y = y + (entree.section and SECTION or 0)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", menu, "TOPLEFT", MARGE_COTE, -y)
		b:SetText(entree.texte)
		b:SetScript("OnClick", entree.action)
		b:Show()
		y = y + BOUTON_H
	end
	for i = #entrees + 1, #boutons do
		boutons[i]:Hide()
	end
	menu:SetWidth(MARGE_COTE + BOUTON_L + MARGE_COTE)
	menu:SetHeight(y + MARGE_BAS)
end

-- une action du menu : fermer, puis faire ce que fait le bouton du client
local function par(bouton)
	return function()
		menu:Hide()
		bouton:Click()
	end
end

local function boutonsConnexion()
	entrees = {
		{ texte = OPTIONS, action = par(OptionsButton) },
		{ texte = CREDITS, action = par(AccountLoginCreditsButton), section = true },
		{ texte = CINEMATICS, action = par(AccountLoginCinematicsButton) },
		{ texte = MANAGE_ACCOUNT, action = par(AccountLoginManageAccountButton) },
		{ texte = COMMUNITY_SITE, action = par(AccountLoginCommunityButton) },
		{ texte = EXIT_GAME, action = function() AccountLoginExitButton:Click() end },
		{ texte = CLOSE, action = fermer, section = true },
	}
end

-- a la selection des personnages (InitCharacterSelectButtons de camelot) :
-- Options | AddOns (s'il y en a), Exit Game | Close. La boutique n'existe pas
-- dans 3.3.5 ; Credits et Cinematics ramenent a l'ecran de connexion dans
-- 3.3.5 : retires (decision de l'utilisateur, 2026-09-27).
local function boutonsSelection()
	entrees = { { texte = OPTIONS, action = par(OptionsButton) } }
	local premier = true
	if GetNumAddOns() > 0 then
		table.insert(entrees, { texte = ADDONS, action = par(CharacterSelectAddonsButton), section = premier })
		premier = false
	end
	table.insert(entrees, { texte = EXIT_GAME, action = function() QuitGame() end, section = premier })
	table.insert(entrees, { texte = CLOSE, action = fermer, section = true })
end

G.Accrocher(menu, "OnShow", function()
	if GetCurrentGlueScreenName() == "charselect" then
		boutonsSelection()
	else
		boutonsConnexion()
	end
	mettreEnPage()
	voile:Show()
end)
G.Accrocher(menu, "OnHide", function()
	voile:Hide()
end)

voile:SetScript("OnKeyDown", function(_, touche)
	if touche == "ESCAPE" then
		fermer()
	elseif touche == "PRINTSCREEN" then
		Screenshot()
	end
end)

function G.MontrerMenu()
	menu:Show()
end

function G.BasculerMenu()
	if menu:IsShown() then
		fermer()
	else
		menu:Show()
	end
end

G.Menu = menu
