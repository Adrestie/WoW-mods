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
--                (10, -3), alpha 0,925.
--   GetInset()   gauche 8, haut 8, droite 8, bas 15.
--   ligne        DarkMenuElementTemplate, 20 de haut.
--   police       le compositeur pose GameFontHighlight, blanc, justifie a
--                gauche et centre verticalement.
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

local FOND_ATLAS = "common-dropdown-bg-c60"
local FOND_X, FOND_Y = 10, 3
local FOND_ALPHA = 0.925
local LIGNE_HAUTEUR = 20
local CASE_ATLAS = "common-dropdown-ticksquare"
local CASE = 12
local COCHE_ATLAS = "common-dropdown-icon-checkmark-yellow"
local COCHE_L, COCHE_H = 15, 14
local COCHE_X, COCHE_Y = 2, 1
local FONDS = { "Backdrop", "MenuBackdrop" }

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

	local fond = liste:CreateTexture(nil, "BACKGROUND")
	if not ForeverUI.SetAtlas(fond, FOND_ATLAS, true) then
		fond:Hide()
	end
	fond:SetPoint("TOPLEFT", liste, "TOPLEFT", -FOND_X, FOND_Y)
	fond:SetPoint("BOTTOMRIGHT", liste, "BOTTOMRIGHT", FOND_X, -FOND_Y)
	fond:SetAlpha(FOND_ALPHA)
	liste.foreverFond = fond
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

-- Le pas des lignes suit leur hauteur : le client le lit a chaque ligne
-- posee et a chaque calcul de hauteur de liste.
UIDROPDOWNMENU_BUTTON_HEIGHT = LIGNE_HAUTEUR

if hooksecurefunc and type(UIDropDownMenu_AddButton) == "function" then
	hooksecurefunc("UIDropDownMenu_AddButton", function(info, level)
		level = level or 1
		local liste = _G["DropDownList" .. level]
		if not liste then
			return
		end

		habillerListe(liste)

		local bouton = _G[liste:GetName() .. "Button" .. (liste.numButtons or 1)]
		if bouton then
			habillerBouton(bouton)
			reglerBouton(bouton)
		end
	end)
end

ForeverUI.DropDown = {
	Skin = habillerListe,
	SkinButton = habillerBouton,
	Refresh = reglerBouton,
}
