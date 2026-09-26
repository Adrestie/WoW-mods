-- ForeverUI : les listes des menus deroulants.
--
-- CE QUE C'EST. Quand on clique sur un menu deroulant, 3.3.5 ouvre un cadre
-- global unique -- DropDownList1, et DropDownList2 pour un sous-menu. Tous
-- les menus du jeu passent par lui : celui des categories de statistiques
-- comme celui d'un clic droit sur un joueur. Le rhabiller les rhabille tous.
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (patch-enUS-2 pour le .xml, patch-enUS-3
-- pour le .lua, le FrameXML d'origine).
--   UIDropDownListTemplate : un Button en strate DIALOG qui tient DEUX fonds
--   en cadres fils, montres l'un ou l'autre selon displayMode --
--   $parentBackdrop (UI-DialogBox-Background-Dark et UI-DialogBox-Border) et
--   $parentMenuBackdrop (UI-Tooltip-Background et UI-Tooltip-Border).
--   UIDropDownMenuButtonTemplate : 100 x 16, avec $parentHighlight
--   (UI-QuestTitleHighlight en ADD), $parentCheck (UI-CheckBox-Check, 18 x 18
--   a LEFT), $parentExpandArrow (ChatFrameExpandArrow) et $parentNormalText.
--   UIDROPDOWNMENU_BUTTON_HEIGHT 16, UIDROPDOWNMENU_BORDER_HEIGHT 15 :
--   une ligne se pose a -((rang - 1) x 16) - 15 et la liste fait
--   rangs x 16 + 15 x 2.
--
-- RELEVE -- CE QUE FAIT CAMELOT. Blizzard_Menu, MenuStyle1Mixin, que
-- MenuVariants.GetDefaultMenuMixin et GetDefaultContextMenuMixin rendent
-- tous deux -- donc le meme habillage pour un menu deroulant et pour un menu
-- contextuel.
--
--   Generate()   fond common-dropdown-bg, TOPLEFT (-10, 3) et BOTTOMRIGHT
--                (10, -3), alpha 0,925 -- UNE texture etiree.
--   GetInset()   gauche 8, haut 8, droite 8, bas 15.
--   ligne        DarkMenuElementTemplate, 20 de haut.
--   police       le compositeur pose GameFontHighlight, blanc, justifie a
--                gauche et centre verticalement.
--   largeur      DropdownButtonMixin:RegisterMenu -- si la description du
--                menu n'impose rien, SetMinimumWidth(self:GetWidth()) : la
--                liste fait AU MOINS la largeur du bouton qui l'ouvre.
--   coche        MenuVariants.CreateCheckbox : la CASE common-dropdown-
--                ticksquare a LEFT, toujours la, et la COCHE JAUNE
--                common-dropdown-icon-checkmark-yellow par-dessus, centree
--                a (2, 1), seulement quand la ligne est choisie.
--   surbrillance MenuVariants.CreateHighlight : UI-QuestTitleHighlight en
--                ADD sur toute la ligne -- DEJA CE QUE FAIT 3.3.5.
--   sous-menu    MenuVariants.CreateSubmenuArrow : ChatFrameExpandArrow --
--                DEJA CE QUE FAIT 3.3.5.
--
-- QUELLE SAVEUR. Blizzard_Menu.toc charge Camelot\Menu.xml pour camelot,
-- mais ses gabarits viennent de [Family]\MenuTemplates : il n'y a pas de
-- camelot/, et entre les deux familles presentes la reponse se lit dans
-- l'art -- les atlas common-dropdown-classic-* n'existent NULLE PART dans ce
-- client, tandis que common-dropdown-* ont tous leur variante c60. C'est
-- donc la famille mainline, avec l'art c60.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   Les marges de camelot sont dissymetriques (8 en haut, 15 en bas) ; 3.3.5
--   n'a qu'une constante pour les deux, UIDROPDOWNMENU_BORDER_HEIGHT, et la
--   sert deux fois. Elle reste a 15 : la tordre deplacerait toutes les
--   lignes de tous les menus du jeu pour trois pixels.
--   La case a cocher et la coche jaune n'ont PAS de variante c60 : leur art
--   de base est celui que camelot montre.
--   3.3.5 ne distingue pas une case a cocher d'un bouton radio -- un menu
--   n'a que info.checked. La paire case + coche jaune sert donc partout, la
--   ou camelot choisirait le rond pour un choix unique.

ForeverUI = ForeverUI or {}

-- LE FOND, EN NEUF TRANCHES. Camelot etire une seule texture d'un bord a
-- l'autre. Mesure sur l'image -- common-dropdown-bg-c60, 68 x 68 -- le
-- panneau n'occupe que x 9..58 et y 6..55 : le reste est une OMBRE de 9 a
-- gauche et a droite, 6 en haut et 12 en bas, et les angles sont coupes sur
-- 6 pixels. L'etirer sur une liste de 200 x 130 multiplie cette ombre par
-- 3,3 en largeur et par 2 en hauteur : le filet dore rentre d'une vingtaine
-- de pixels de chaque cote, les angles s'ecrasent, et le bas du panneau
-- remonte au-dessus de la derniere ligne.
--
-- Les coins gardent donc leur taille et seuls les bords s'etirent. Le coin
-- vaut 18 : l'ombre la plus epaisse (12) plus le pan coupe (6), ce qui
-- laisse une bande centrale de 32 sur les 68.
--
-- Et les marges ne sont plus celles de camelot mais CELLES DE L'IMAGE :
-- donner l'epaisseur de l'ombre fait tomber le filet exactement sur le bord
-- du cadre, donc sur la largeur du menu deroulant.
local FOND_ATLAS = "common-dropdown-bg-c60"
local FOND_COIN = 18
local FOND_MARGES = { 9, 6, 9, 12 }     -- gauche, haut, droite, bas
local FOND_ALPHA = 0.925
local LIGNE_HAUTEUR = 20
local CASE_ATLAS = "common-dropdown-ticksquare"
local CASE = 12
local COCHE_ATLAS = "common-dropdown-icon-checkmark-yellow"
local COCHE_L, COCHE_H = 15, 14
local COCHE_X, COCHE_Y = 2, 1
local FONDS = { "Backdrop", "MenuBackdrop" }

-- L'ecart que le client garde entre la liste et ses lignes : il pose la
-- liste a maxWidth + 25 et les lignes a maxWidth. On le garde tel quel pour
-- que la marge de droite ne bouge pas quand la liste s'elargit.
local LISTE_MARGE = 25

-- LA LARGEUR. Le client taille la liste sur son texte le plus long
-- (maxWidth + 25) ; camelot lui impose un PLANCHER, la largeur du bouton
-- qui l'ouvre (DropdownButtonMixin:RegisterMenu, SetMinimumWidth).
--
-- ECART ASSUME, sur demande : ici c'est une EGALITE, pas un plancher. La
-- liste prend exactement la largeur de son bouton, meme quand une entree
-- est plus longue -- auquel cas son texte se trouve serre.
--
-- Cela se joue a l'affichage de la liste : ToggleDropDownMenu retient le
-- menu ouvert (UIDROPDOWNMENU_OPEN_MENU) AVANT de la montrer, et ne verifie
-- qu'elle tient dans l'ecran qu'APRES -- la largeur doit donc etre acquise
-- a ce moment-la, sinon le recadrage se ferait sur l'ancienne.
--
-- Seul le premier niveau d'un MENU DEROULANT est concerne. Un menu
-- contextuel (displayMode "MENU" : clic droit, menus de la carte, du journal,
-- du suivi) n'a pas de bouton a epouser -- son ouvreur est un cadre
-- invisible de 40 de large -- et un sous-menu n'est ouvert par aucun bouton :
-- ceux-la prennent la largeur de leur CONTENU (corrige le 2026-09-25 : ils
-- etaient ecrases a 40).
--
-- LE CONTENU SE MESURE DANS LA POLICE AFFICHEE. Le client mesure chaque
-- ligne en GameFontHighlightSmallLeft, avant que nous passions a
-- GameFontHighlightLeft, plus grande : sa largeur (maxWidth) serait trop
-- courte. La mesure est refaite a chaque ligne posee (mesurerBouton) avec la
-- formule de UIDropDownMenu_AddButton.
local function fixerLargeur(liste, voulue)
	if math.abs(liste:GetWidth() - voulue) < 0.5 then
		return
	end
	liste:SetWidth(voulue)
	for index = 1, (liste.numButtons or 0) do
		local bouton = _G[liste:GetName() .. "Button" .. index]
		if bouton then
			bouton:SetWidth(voulue - LISTE_MARGE)
		end
	end
end

local function ajusterLargeur(liste)
	local ouvreur = UIDROPDOWNMENU_OPEN_MENU
	local niveau = liste.foreverNiveau or liste:GetID()
	if niveau ~= 1 or not ouvreur or not ouvreur.GetWidth or ouvreur.displayMode == "MENU" then
		local contenu = liste.foreverContenu
		if contenu and contenu > 0 then
			-- un menu de ForeverUI peut demander un plancher : la largeur du
			-- bouton qui l'ouvre, comme camelot (SetMinimumWidth)
			local minimum = niveau == 1 and ouvreur and ouvreur.foreverMinimum or 0
			fixerLargeur(liste, math.max(contenu + LISTE_MARGE, minimum))
		end
		return
	end

	local voulue = ouvreur:GetWidth()
	if not voulue or voulue <= 0 then
		return
	end
	fixerLargeur(liste, voulue)
end

-- La largeur d'une ligne, par la formule de UIDropDownMenu_AddButton : texte
-- + 40, + 10 pour une fleche ou un nuancier, - 30 sans case, + 10 pour une
-- icone, + le rembourrage demande.
local function mesurerBouton(liste, bouton, info)
	if liste.numButtons == 1 then
		liste.foreverContenu = 0
	end
	local texte = _G[bouton:GetName() .. "NormalText"]
	if not (texte and info and info.text) then
		return
	end
	local largeur = texte:GetStringWidth() + 40
	if info.hasArrow or info.hasColorSwatch then largeur = largeur + 10 end
	if info.notCheckable then largeur = largeur - 30 end
	if info.icon then largeur = largeur + 10 end
	if info.padding then largeur = largeur + info.padding end
	if largeur > (liste.foreverContenu or 0) then
		liste.foreverContenu = largeur
	end
end

-- La liste perd ses deux fonds d'epoque et prend celui de camelot.
--
-- On RETIRE le fond au lieu de masquer le cadre : ToggleDropDownMenu montre
-- l'un ou l'autre a chaque ouverture, selon displayMode, et remettrait
-- debout ce qu'on aurait couche. Un cadre sans fond ne dessine rien.
local function habillerListe(liste)
	if liste.foreverFond then
		return
	end

	local nom = liste:GetName()
	for _, suffixe in ipairs(FONDS) do
		local cadre = nom and _G[nom .. suffixe]
		if cadre and cadre.SetBackdrop then
			cadre:SetBackdrop(nil)
		end
	end

	local tranches = ForeverUI.CreateNineSlice(liste, FOND_ATLAS, FOND_COIN,
		FOND_MARGES, "BACKGROUND")
	if not tranches then
		return
	end
	for _, tranche in ipairs(tranches) do
		tranche:SetAlpha(FOND_ALPHA)
	end
	liste.foreverFond = tranches[1]
	liste.foreverTranches = tranches

	liste:HookScript("OnShow", ajusterLargeur)
end

-- La case et la coche. La case va en BORDER et la coche reste en ARTWORK :
-- 3.3.5 n'a pas de sous-niveau de calque, l'ordre vient donc du calque, et
-- la coche doit passer par-dessus sa case.
local function habillerBouton(bouton)
	if bouton.foreverCase then
		return
	end

	local case = bouton:CreateTexture(nil, "BORDER")
	if not ForeverUI.SetAtlas(case, CASE_ATLAS, true) then
		case:Hide()
	end
	case:SetWidth(CASE)
	case:SetHeight(CASE)
	case:SetPoint("LEFT", bouton, "LEFT", 0, 0)
	case:Hide()
	bouton.foreverCase = case

	local coche = _G[bouton:GetName() .. "Check"]
	if coche then
		ForeverUI.SetAtlas(coche, COCHE_ATLAS, true)
		coche:SetWidth(COCHE_L)
		coche:SetHeight(COCHE_H)
		coche:ClearAllPoints()
		coche:SetPoint("CENTER", case, "CENTER", COCHE_X, COCHE_Y)
	end
end

-- Ce qui se refait a chaque ligne posee : UIDropDownMenu_AddButton remet la
-- police a GameFontHighlightSmallLeft a chaque passage, et c'est elle qui
-- sait si la ligne porte une case (info.notCheckable).
local function reglerBouton(bouton)
	bouton:SetHeight(LIGNE_HAUTEUR)
	if GameFontHighlightLeft then
		bouton:SetNormalFontObject(GameFontHighlightLeft)
		bouton:SetHighlightFontObject(GameFontHighlightLeft)
	end

	if bouton.foreverCase then
		if bouton.notCheckable then
			bouton.foreverCase:Hide()
		else
			bouton.foreverCase:Show()
		end
	end
end

-- Le pas des lignes suit leur hauteur. Le client le lit dans
-- UIDROPDOWNMENU_BUTTON_HEIGHT -- a chaque ligne posee, a chaque calcul de
-- hauteur de liste, et pour la hauteur du menu deroulant lui-meme
-- (UIDropDownMenu_InitializeHelper) -- mais on N'ECRIT PAS cette globale :
-- ecrite par l'addon, elle souillerait chaque menu du client, jusqu'au menu
-- d'un clic droit sur un joueur et ses actions protegees (taint.log du
-- 2026-09-26, meme cas que StaticPopupDialogs). Le client pose donc ses
-- lignes a 16, et on les repose a 20 juste apres lui, aux memes endroits.
local BORDURE = UIDROPDOWNMENU_BORDER_HEIGHT or 15

local function reposerLigne(liste, bouton)
	local point, relatif, pointRelatif, x = bouton:GetPoint(1)
	if point then
		bouton:ClearAllPoints()
		bouton:SetPoint(point, relatif, pointRelatif, x,
			-((bouton:GetID() - 1) * LIGNE_HAUTEUR) - BORDURE)
	end
	liste:SetHeight(((liste.numButtons or 1) * LIGNE_HAUTEUR) + (BORDURE * 2))
end

if hooksecurefunc and type(UIDropDownMenu_InitializeHelper) == "function" then
	hooksecurefunc("UIDropDownMenu_InitializeHelper", function(cadre)
		if cadre and cadre.SetHeight then
			cadre:SetHeight(LIGNE_HAUTEUR * 2)
		end
	end)
end

if hooksecurefunc and type(UIDropDownMenu_AddButton) == "function" then
	hooksecurefunc("UIDropDownMenu_AddButton", function(info, level)
		level = level or 1
		local liste = _G["DropDownList" .. level]
		if not liste then
			return
		end

		liste.foreverNiveau = level
		habillerListe(liste)

		local bouton = _G[liste:GetName() .. "Button" .. (liste.numButtons or 1)]
		if bouton then
			reposerLigne(liste, bouton)
			habillerBouton(bouton)
			reglerBouton(bouton)
			mesurerBouton(liste, bouton, info)
		end
	end)
end

-- UIDropDownMenu_Refresh retaille la liste sur son texte (maxWidth + 25) et
-- effacerait la largeur voulue : on la repose derriere elle.
if hooksecurefunc and type(UIDropDownMenu_Refresh) == "function" then
	hooksecurefunc("UIDropDownMenu_Refresh", function(cadre, valeur, niveau)
		local liste = _G["DropDownList" .. (niveau or UIDROPDOWNMENU_MENU_LEVEL or 1)]
		if liste and liste:IsShown() then
			ajusterLargeur(liste)
		end
	end)
end

ForeverUI.DropDown = {
	Skin = habillerListe,
	SkinButton = habillerBouton,
	Refresh = reglerBouton,
	Fit = ajusterLargeur,
}

-- ------------------------------------------------------------ LES MENUS D'UNITE
--
-- LE PROBLEME (taint.log du 2026-09-26). Nos cadres d'unite ouvrent le menu
-- du clic droit par une fonction a nous (le « menu » de leur action
-- securisee) : le client construit alors tout le menu comme venant de
-- l'addon, et les lignes qui appellent une fonction protegee sont bloquees
-- -- SET_FOCUS (FocusUnit), CLEAR_FOCUS (ClearFocus), TARGET
-- (TargetUnit) et PET_DISMISS (PetDismiss), UnitPopup.lua:1201-1384. Les
-- autres lignes marchent.
--
-- LA REPONSE (decision de l'utilisateur, 2026-09-26). Hors combat, un bouton
-- securise de ForeverUI se pose sur chacune de ces lignes : c'est vous qui
-- cliquez, et il fait l'action comme une macro -- focus sur l'unite,
-- /clearfocus, /targetexact <nom>, /script PetDismiss(). En combat, le
-- client interdit a tout addon de poser, montrer ou regler un bouton
-- securise : ces lignes sont grisees (et le restent, UnitPopup_OnUpdate les
-- reactivant a chaque image). A l'entree en combat, les boutons poses s'en
-- vont avant le verrou et leurs lignes se grisent.
--
-- Seuls les menus ouverts PAR NOS CADRES sont touches (MenuUnite.ouvrir) :
-- ceux que le client ouvre lui-meme marchent deja.

local M = {}
ForeverUI.MenuUnite = M
M.surcouches = {}
M.grises = {}

local SURBRILLANCE = "Interface" .. string.char(92) .. "QuestFrame" .. string.char(92) .. "UI-QuestTitleHighlight"

-- le nom complet, comme UnitPopup_OnClick (UnitPopup.lua:1169-1174)
local function nomComplet(menu)
	local nom, serveur = menu.name, menu.server
	if nom and serveur and (not menu.unit or not UnitIsSameServer("player", menu.unit)) then
		return nom .. "-" .. serveur
	end
	return nom
end

-- ce que fait chaque ligne protegee, en action securisee
local PROTEGEES = {
	SET_FOCUS = function(o, menu)
		if not menu.unit then return false end
		o:SetAttribute("type", "focus")
		o:SetAttribute("unit", menu.unit)
	end,
	CLEAR_FOCUS = function(o)
		o:SetAttribute("type", "macro")
		o:SetAttribute("macrotext", "/clearfocus")
	end,
	TARGET = function(o, menu)
		local nom = nomComplet(menu)
		if not nom then return false end
		o:SetAttribute("type", "macro")
		o:SetAttribute("macrotext", "/targetexact " .. nom)
	end,
	PET_DISMISS = function(o)
		o:SetAttribute("type", "macro")
		o:SetAttribute("macrotext", "/script PetDismiss()")
	end,
}
M.PROTEGEES = PROTEGEES

local function surcouche(k)
	local o = M.surcouches[k]
	if o then return o end
	o = CreateFrame("Button", "ForeverUIUnitMenuSecure" .. k, UIParent, "SecureActionButtonTemplate")
	o:RegisterForClicks("LeftButtonUp")
	o:SetHighlightTexture(SURBRILLANCE)
	local h = o:GetHighlightTexture()
	if h then h:SetBlendMode("ADD") end
	-- la liste se ferme d'elle-meme quand la souris quitte ses lignes : sur
	-- la surcouche, on la retient comme sur une ligne
	o:SetScript("OnEnter", function() UIDropDownMenu_StopCounting(DropDownList1) end)
	o:SetScript("OnLeave", function() UIDropDownMenu_StartCounting(DropDownList1) end)
	o:SetScript("PostClick", function() CloseDropDownMenus() end)
	o:Hide()
	M.surcouches[k] = o
	return o
end

-- hors combat seulement : un bouton securise ne se touche pas sous le verrou
function M.cacher()
	if InCombatLockdown() then return end
	for _, o in ipairs(M.surcouches) do
		o:Hide()
		o:ClearAllPoints()
	end
end

local function griser(ligne)
	ligne:Disable()
	table.insert(M.grises, ligne)
end

-- apres UnitPopup_ShowMenu, sur la premiere liste : les lignes protegees
function M.poser(menu)
	M.cacher()
	table.wipe(M.grises)
	local liste = DropDownList1
	local combat = InCombatLockdown()
	local k = 0
	for i = 1, (liste.numButtons or 0) do
		local ligne = _G["DropDownList1Button" .. i]
		local regler = ligne and PROTEGEES[ligne.value]
		if regler then
			if combat then
				griser(ligne)
			else
				local o = surcouche(k + 1)
				if regler(o, menu) ~= false then
					k = k + 1
					o:ClearAllPoints()
					o:SetAllPoints(ligne)
					-- DropDownList1, toplevel, remonte au premier plan de sa
					-- strate en s'affichant : la strate des infobulles est
					-- au-dessus (meme reponse que SocialRaid.lua)
					o:SetFrameStrata("TOOLTIP")
					o:Show()
				end
			end
		end
	end
end

-- ouvrir un menu depuis un de nos cadres
function M.ouvrir(fn, ...)
	M.nous = true
	local ok, err = pcall(fn, ...)
	M.nous = false
	if not ok then error(err, 0) end
end

if hooksecurefunc and type(UnitPopup_ShowMenu) == "function" then
	hooksecurefunc("UnitPopup_ShowMenu", function(menu)
		if not M.nous or not menu or (UIDROPDOWNMENU_MENU_LEVEL or 1) ~= 1 then return end
		M.poser(menu)
	end)
end
if hooksecurefunc and type(UnitPopup_OnUpdate) == "function" then
	hooksecurefunc("UnitPopup_OnUpdate", function()
		if #M.grises == 0 or not DropDownList1:IsShown() then return end
		for _, ligne in ipairs(M.grises) do
			if ligne:IsEnabled() == 1 then ligne:Disable() end
		end
	end)
end
if DropDownList1 then
	DropDownList1:HookScript("OnHide", function()
		M.cacher()
		table.wipe(M.grises)
	end)
end

-- a l'entree en combat, avant le verrou : les boutons s'en vont, leurs
-- lignes se grisent
local veille = CreateFrame("Frame")
veille:RegisterEvent("PLAYER_REGEN_DISABLED")
veille:SetScript("OnEvent", function()
	local posees = false
	for _, o in ipairs(M.surcouches) do
		if o:IsShown() then posees = true end
		o:Hide()
		o:ClearAllPoints()
	end
	if posees and DropDownList1:IsShown() then
		for i = 1, (DropDownList1.numButtons or 0) do
			local ligne = _G["DropDownList1Button" .. i]
			if ligne and PROTEGEES[ligne.value] then griser(ligne) end
		end
	end
end)
M.veille = veille
