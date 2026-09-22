-- ForeverUI : le choix d'icone d'un ensemble d'equipement.
--
-- RELEVE -- camelot, IconSelectorPopupFrameTemplate
-- (blizzard_sharedxml/mainline/SharedUIPanelTemplates.xml) :
--   fenetre            525 x 495
--   intitule du champ  TOPLEFT (24, -21)
--   champ de nom       182 x 20, TOPLEFT (29, -35), 16 lettres
--   "Choose an Icon:"  TOPLEFT (24, -79)
--   zone du choix      275 x 45, TOPRIGHT (-13, -13) ; son bouton d'icone
--                      fait 36, TOPRIGHT (-4,5 ; -3,5), avec deux lignes a
--                      sa gauche : ICON_SELECTION_TITLE_CURRENT et sa
--                      description
--   grille             494 x 361, TOPLEFT (21, -97)
--
-- RELEVE -- ScrollBoxSelectorMixin (blizzard_sharedxml/shared/selector) :
--   GetStride          10   -- dix icones par rangee
--   GetButtonHeight    36   -- et la largeur suit
--   GetPadding         haut 5, bas 5, gauche 5, droite 5, ecarts 10 et 10
--
-- CE QUE LE CLIENT PORTE. GearManagerDialogPopup, 297 x 254, avec
-- GearManagerDialogPopupButton1..NUM_GEARSET_ICONS_SHOWN poses en grille de
-- NUM_GEARSET_ICONS_PER_ROW, un FauxScrollFrame, un champ de nom de 182 x 20
-- deja limite a 16 lettres, et les boutons Okay et Cancel.
--
-- TOUT SON REMPLISSAGE PASSE PAR QUATRE GLOBALES --
-- NUM_GEARSET_ICONS_PER_ROW, NUM_GEARSET_ICON_ROWS, NUM_GEARSET_ICONS_SHOWN
-- et GEARSET_ICON_ROW_HEIGHT : GearManagerDialogPopup_Update et
-- RecalculateGearManagerDialogPopup ne lisent qu'elles. Les porter aux
-- valeurs de camelot suffit donc a obtenir sa grille, sans rien recrire du
-- parcours des icones ni du defilement.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   Le client ne cree que quinze boutons, au chargement. Il en faut quatre-
--   vingts : les soixante-cinq manquants sont crees ici, sur SON gabarit
--   (GearSetPopupButtonTemplate), et tous sont reposes en grille de dix.
--   La barre de defilement reste celle de 3.3.5 : MinimalScrollBar n'est pas
--   portee.
--   ICON_SELECTION_TITLE_CURRENT et sa description n'existent pas dans ce
--   client. Les deux lignes sont ecrites en dur, comme "New Set".

ForeverUI = ForeverUI or {}

local POPUP_L, POPUP_H = 525, 495
local ENTETE_X, ENTETE_Y = 24, -21
local CHAMP_X, CHAMP_Y = 29, -35
local CHOISIR_X, CHOISIR_Y = 24, -79

local ZONE_L, ZONE_H = 275, 45
local ZONE_X, ZONE_Y = -13, -13
local CHOIX_ICONE = 36
local CHOIX_X, CHOIX_Y = -4.5, -3.5

local GRILLE_X, GRILLE_Y = 21, -97
local ICONE = 36
local PAR_RANGEE = 10
local RANGEES = 8
local ECART = 10
local MARGE = 5
local PAS = ICONE + ECART

local BAS_ECART = 16                    -- Okay et Cancel, au bas de la fenetre

local monte = false

-- Les quatre globales que tout le remplissage du client lit.
local function poserLesGlobales()
	NUM_GEARSET_ICONS_PER_ROW = PAR_RANGEE
	NUM_GEARSET_ICON_ROWS = RANGEES
	NUM_GEARSET_ICONS_SHOWN = PAR_RANGEE * RANGEES
	GEARSET_ICON_ROW_HEIGHT = PAS
end

-- Les boutons manquants, sur le gabarit du client, puis toute la grille
-- reposee en rangees de dix.
local function poserGrille(popup)
	for index = #popup.buttons + 1, NUM_GEARSET_ICONS_SHOWN do
		local bouton = CreateFrame("CheckButton",
			"GearManagerDialogPopupButton" .. index, popup,
			"GearSetPopupButtonTemplate")
		bouton:SetID(index)
		table.insert(popup.buttons, bouton)
	end

	for index, bouton in ipairs(popup.buttons) do
		bouton:SetWidth(ICONE)
		bouton:SetHeight(ICONE)
		bouton:ClearAllPoints()
		if index == 1 then
			bouton:SetPoint("TOPLEFT", popup, "TOPLEFT",
				GRILLE_X + MARGE, GRILLE_Y - MARGE)
		elseif math.fmod(index - 1, PAR_RANGEE) == 0 then
			bouton:SetPoint("TOPLEFT", popup.buttons[index - PAR_RANGEE],
				"BOTTOMLEFT", 0, -ECART)
		else
			bouton:SetPoint("TOPLEFT", popup.buttons[index - 1], "TOPRIGHT",
				ECART, 0)
		end
	end
end

-- LA ZONE DU CHOIX COURANT. camelot y montre l'icone retenue et invite a
-- cliquer pour la retrouver dans la liste ; 3.3.5 sait deja faire ce saut,
-- c'est RecalculateGearManagerDialogPopup qui deplace le defilement jusqu'a
-- elle.
local function poserChoixCourant(popup)
	if popup.foreverChoix then
		return
	end

	local zone = CreateFrame("Frame", "ForeverUIIconChoice", popup)
	zone:SetWidth(ZONE_L)
	zone:SetHeight(ZONE_H)
	zone:SetPoint("TOPRIGHT", popup, "TOPRIGHT", ZONE_X, ZONE_Y)

	local bouton = CreateFrame("Button", "ForeverUIIconChoiceButton", zone)
	bouton:SetWidth(CHOIX_ICONE)
	bouton:SetHeight(CHOIX_ICONE)
	bouton:SetPoint("TOPRIGHT", zone, "TOPRIGHT", CHOIX_X, CHOIX_Y)

	local icone = bouton:CreateTexture(nil, "ARTWORK")
	icone:SetAllPoints(bouton)
	bouton.icone = icone

	local surlignage = bouton:CreateTexture(nil, "HIGHLIGHT")
	surlignage:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	surlignage:SetBlendMode("ADD")
	surlignage:SetAllPoints(bouton)

	-- Ecrites en dur : ICON_SELECTION_TITLE_CURRENT et sa description
	-- n'existent pas dans ce client.
	local titre = zone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	titre:SetPoint("TOPRIGHT", bouton, "TOPLEFT", -6, -2)
	titre:SetText("Currently Selected")

	local aide = zone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	aide:SetPoint("TOPRIGHT", titre, "BOTTOMRIGHT", 0, -2)
	aide:SetText("Click to view in the list")

	bouton:SetScript("OnClick", function()
		if RecalculateGearManagerDialogPopup then
			RecalculateGearManagerDialogPopup()
		end
	end)

	popup.foreverChoix = bouton
	popup.foreverZone = zone
end

-- L'icone montree dans la zone suit ce que le client a retenu.
local function majChoixCourant()
	local popup = _G["GearManagerDialogPopup"]
	if not popup or not popup.foreverChoix then
		return
	end

	local texture = popup.selectedTexture
	if not texture and popup.selectedIcon and GetEquipmentSetIconInfo then
		texture = GetEquipmentSetIconInfo(popup.selectedIcon)
	end
	popup.foreverChoix.icone:SetTexture(texture or "")
end
ForeverUI.IconPickerRefresh = majChoixCourant

local function poserFenetre(popup)
	popup:SetWidth(POPUP_L)
	popup:SetHeight(POPUP_H)

	local champ = _G["GearManagerDialogPopupEditBox"]
	if champ then
		champ:ClearAllPoints()
		champ:SetPoint("TOPLEFT", popup, "TOPLEFT", CHAMP_X, CHAMP_Y)
	end

	-- Les deux intitules du client sont des regions sans nom : on les
	-- retrouve par leur texte, qui vient de GEARSETS_POPUP_TEXT et de
	-- MACRO_POPUP_CHOOSE_ICON.
	local regions = { popup:GetRegions() }
	for _, region in ipairs(regions) do
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			local texte = region:GetText()
			region:ClearAllPoints()
			if texte == MACRO_POPUP_CHOOSE_ICON then
				region:SetPoint("TOPLEFT", popup, "TOPLEFT", CHOISIR_X, CHOISIR_Y)
			else
				region:SetPoint("TOPLEFT", popup, "TOPLEFT", ENTETE_X, ENTETE_Y)
			end
		end
	end

	local defilement = _G["GearManagerDialogPopupScrollFrame"]
	if defilement then
		defilement:SetWidth(PAR_RANGEE * PAS - ECART + 2 * MARGE)
		defilement:SetHeight(RANGEES * PAS - ECART + 2 * MARGE)
		defilement:ClearAllPoints()
		defilement:SetPoint("TOPLEFT", popup, "TOPLEFT", GRILLE_X, GRILLE_Y)
	end

	local okay = _G["GearManagerDialogPopupOkay"]
	local annuler = _G["GearManagerDialogPopupCancel"]
	if annuler then
		annuler:ClearAllPoints()
		annuler:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -BAS_ECART, BAS_ECART)
	end
	if okay and annuler then
		okay:ClearAllPoints()
		okay:SetPoint("RIGHT", annuler, "LEFT", -BAS_ECART, 0)
	end
end

local function habiller()
	local popup = _G["GearManagerDialogPopup"]
	if not popup or not popup.buttons or InCombatLockdown() then
		return
	end

	if not monte then
		poserLesGlobales()
		poserGrille(popup)
		poserChoixCourant(popup)
		poserFenetre(popup)
		monte = true
	end

	majChoixCourant()
end

ForeverUI.IconPicker = { Apply = habiller }

-- Monte des le chargement : le client remplit sa grille des la premiere
-- ouverture, et il lui faut ses quatre-vingts boutons a ce moment-la.
habiller()

if hooksecurefunc then
	for _, nom in ipairs({ "GearManagerDialogPopup_OnShow", "GearManagerDialogPopup_Update" }) do
		if type(_G[nom]) == "function" then
			hooksecurefunc(nom, function() habiller() end)
		end
	end
end
