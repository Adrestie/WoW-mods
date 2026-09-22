-- ForeverUI : le gestionnaire d'equipement, dans le volet droit.
--
-- RELEVE -- camelot/PaperDollFrame.xml, PaperDollFrame.EquipmentManagerPane :
--   ancre       TOPLEFT sur le BOTTOMLEFT de la bande de pierre du volet,
--               BOTTOMRIGHT sur le volet lui-meme.
--   bordure     common-insideframe, TOPLEFT (1, 1) et BOTTOMRIGHT (-4, 2).
--   liste       TOPLEFT (5, -8), BOTTOMRIGHT (-20, 105).
--   trait       UI-Character-Info-ScrollLine, au TOP du BOTTOM de la liste.
--   Equip       99 x 28, BOTTOM (-50, 20), intitule EQUIPSET_EQUIP.
--   Save        99 x 28, BOTTOM (50, 20), intitule SAVE.
--   New Set     180 x 34, BOTTOM (0, 50), avec UI-Character-Info-Icon-Add
--               a LEFT (13).
--
-- RELEVE -- camelot, GearSetButtonTemplate, la carte d'un ensemble :
--   cadre       169 x 44
--   fond        UI-Character-Info-OutfitCard, 152 x 49, TOPLEFT x = 42
--   survol      UI-Character-Info-OutfitCard-Hover, meme place
--   choisi      UI-Character-Info-OutfitCard-Selected, meme place
--   coche       UI-Character-Info-Icon-Tick, RIGHT (-23, 0), montree quand
--               l'ensemble est PORTE (PaperDollEquipmentManagerPane_InitButton)
--   intitule    GameFontNormalLeft, 98 x 38, LEFT (55)
--   icone       36 x 36, LEFT (4), cerclee de
--               UI-Character-Info-OutfitIcon-Frame, centree dessus
--
-- CE QUE LE CLIENT PORTE. GearManagerDialog, une fenetre de 261 x 155 sur
-- UIPanelDialogTemplate, avec GearSetButton1..MAX_EQUIPMENT_SETS_PER_PLAYER
-- poses EN GRILLE de cinq, et trois boutons : Delete, Equip, Save. Une carte
-- y est un CheckButton de 36 sur PopupButtonTemplate -- son icone est sa
-- NormalTexture, son intitule le $parentName sous elle, et un fond
-- UI-EmptySlot-Disabled derriere.
--
-- Rien n'est recree : la fenetre du client passe dans le volet, ses cartes
-- se reposent en colonne et se rhabillent, ses boutons gardent leur clic.
-- C'est lui qui tient la liste, la selection et les infobulles.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   3.3.5 n'a pas de bouton "New Set" : on y cree un ensemble par Save, qui
--   ouvre la fenetre de nom. Le notre fait la meme chose apres avoir vide la
--   selection, ce qui est exactement "enregistrer sous un nouveau nom".
--   Le bouton Delete du client n'a pas d'equivalent chez camelot, qui efface
--   un ensemble par le menu de sa carte -- menu que 3.3.5 n'a pas. Il est
--   donc GARDE, a droite de Save, plutot que de retirer la seule facon
--   d'effacer un ensemble.
--   GetEquipmentSetInfo ne dit pas si un ensemble est porte. La coche se
--   calcule donc depuis GetEquipmentSetLocations : l'ensemble est porte
--   quand chacune de ses pieces est sur le joueur et hors des sacs.
--   La barre de defilement de camelot (MinimalScrollBar) n'est pas portee :
--   la liste defile a la molette, et le trait de camelot marque son bas.

ForeverUI = ForeverUI or {}

local CARTE_L, CARTE_H = 169, 44
local CARTE_FOND_L, CARTE_FOND_H = 152, 49
local CARTE_FOND_X = 42
local CARTE_ICONE, CARTE_ICONE_X = 36, 4
local CARTE_TEXTE_X = 55
local CARTE_TEXTE_L, CARTE_TEXTE_H = 98, 38
local COCHE_X = -23

local LISTE_X, LISTE_Y = 5, -8
local LISTE_X2, LISTE_Y2 = -20, 105
local BOUTON_L, BOUTON_H = 99, 28
local BOUTON_Y, BOUTON_ECART = 20, 50
local NOUVEAU_L, NOUVEAU_H = 180, 34
local NOUVEAU_Y, NOUVEAU_ICONE_X = 50, 13
-- LA BORDURE SE DECOUPE, ELLE NE S'ETIRE PAS. common-insideframe fait
-- 107 x 107 et porte un MOTIF dans chaque angle : tendue sur les 233 x 379
-- du panneau, elle est multipliee par deux en largeur et par trois et demi
-- en hauteur, et tout se brouille.
--
-- Mesure sur l'art : le filet occupe 2..12 et 94..104 sur les deux axes, et
-- le motif d'angle s'arrete a 19 -- des x = 20 le profil n'est plus que le
-- filet. Le coin vaut donc 20, ce qui laisse une bande centrale de 67.
--
-- Les marges viennent de camelot, qui ancre sa bordure en TOPLEFT (1, 1) et
-- BOTTOMRIGHT (-4, 2) : converties dans la convention du decoupage -- de
-- combien l'image deborde du cadre -- cela donne -1, 1, -4, -2.
local BORDURE_COIN = 20
local BORDURE_MARGES = { -1, 1, -4, -2 }

local ATLAS_FOND = "ui-character-info-outfitcard"
local ATLAS_SURVOL = "ui-character-info-outfitcard-hover"
local ATLAS_CHOISI = "ui-character-info-outfitcard-selected"
local ATLAS_COCHE = "ui-character-info-icon-tick"
local ATLAS_CERCLE = "ui-character-info-outfiticon-frame"
local ATLAS_PLUS = "ui-character-info-icon-add"
local ATLAS_BORDURE = "common-insideframe"
local ATLAS_TRAIT = "ui-character-info-scrollline"

local panneau, decalage = nil, 0

-- Un ensemble est PORTE quand chacune de ses pieces est sur le joueur et
-- hors des sacs. EquipmentManager_UnpackLocation rend ces deux drapeaux.
local function ensemblePorte(nom)
	if not nom or not GetEquipmentSetLocations or not EquipmentManager_UnpackLocation then
		return false
	end

	local places = GetEquipmentSetLocations(nom)
	if not places then
		return false
	end

	local vu = false
	for _, place in pairs(places) do
		if type(place) == "number" and place > 1 then
			local joueur, _, sacs = EquipmentManager_UnpackLocation(place)
			if not joueur or sacs then
				return false
			end
			vu = true
		end
	end
	return vu
end

-- Combien de cartes tiennent dans la liste, et ou elle commence.
local function hauteurListe()
	if not panneau then
		return 0
	end
	return panneau:GetHeight() - (-LISTE_Y) - LISTE_Y2
end

local function cartesVisibles()
	local place = math.floor(hauteurListe() / CARTE_H)
	if place < 1 then
		place = 1
	end
	return place
end

-- La carte : le cadre du client, rhabille une seule fois.
local function habillerCarte(bouton)
	if bouton.foreverCarte then
		return
	end

	bouton:SetWidth(CARTE_L)
	bouton:SetHeight(CARTE_H)

	-- Le fond d'emplacement vide de 3.3.5 s'en va ; l'icone, elle, est la
	-- NormalTexture du bouton et doit rester.
	local icone = bouton:GetNormalTexture()
	local regions = { bouton:GetRegions() }
	for _, region in ipairs(regions) do
		if region ~= icone and region.GetObjectType and region:GetObjectType() == "Texture" then
			local chemin = region.GetTexture and region:GetTexture()
			if type(chemin) == "string" and string.find(string.lower(chemin), "emptyslot") then
				region:SetAlpha(0)
			end
		end
	end
	if bouton:GetHighlightTexture() then
		bouton:GetHighlightTexture():SetAlpha(0)
	end
	if bouton.GetCheckedTexture and bouton:GetCheckedTexture() then
		bouton:GetCheckedTexture():SetAlpha(0)
	end

	local function carte(atlas, couche)
		local t = bouton:CreateTexture(nil, couche)
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetWidth(CARTE_FOND_L)
		t:SetHeight(CARTE_FOND_H)
		t:SetPoint("TOPLEFT", bouton, "TOPLEFT", CARTE_FOND_X, 0)
		return t
	end

	bouton.foreverFond = carte(ATLAS_FOND, "BACKGROUND")
	bouton.foreverSurvol = carte(ATLAS_SURVOL, "BORDER")
	bouton.foreverSurvol:Hide()
	bouton.foreverChoisi = carte(ATLAS_CHOISI, "BORDER")
	bouton.foreverChoisi:Hide()

	if icone then
		icone:ClearAllPoints()
		icone:SetWidth(CARTE_ICONE)
		icone:SetHeight(CARTE_ICONE)
		icone:SetPoint("LEFT", bouton, "LEFT", CARTE_ICONE_X, 0)
		icone:SetDrawLayer("ARTWORK")
	end

	local cercle = bouton:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(cercle, ATLAS_CERCLE)
	cercle:SetPoint("CENTER", icone or bouton, "CENTER", 0, 0)

	local coche = bouton:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(coche, ATLAS_COCHE)
	coche:SetPoint("RIGHT", bouton, "RIGHT", COCHE_X, 0)
	coche:Hide()
	bouton.foreverCoche = coche

	local texte = _G[bouton:GetName() .. "Name"]
	if texte then
		texte:ClearAllPoints()
		texte:SetFontObject(GameFontNormalLeft or GameFontNormal)
		texte:SetWidth(CARTE_TEXTE_L)
		texte:SetHeight(CARTE_TEXTE_H)
		texte:SetJustifyH("LEFT")
		texte:SetPoint("LEFT", bouton, "LEFT", CARTE_TEXTE_X, 0)
	end

	bouton:HookScript("OnEnter", function(self)
		if self.name and self.name ~= "" then
			self.foreverSurvol:Show()
		end
	end)
	bouton:HookScript("OnLeave", function(self)
		self.foreverSurvol:Hide()
	end)

	bouton.foreverCarte = true
end

-- La liste : les ensembles existants, en colonne, a partir du decalage.
local function poserCartes()
	local dialogue = _G["GearManagerDialog"]
	if not dialogue or not dialogue.buttons or not panneau then
		return
	end

	local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
	local place = cartesVisibles()
	if decalage > total - place then
		decalage = math.max(0, total - place)
	end

	local precedent
	for index, bouton in ipairs(dialogue.buttons) do
		habillerCarte(bouton)
		local rang = index - decalage
		if index <= total and rang >= 1 and rang <= place then
			bouton:ClearAllPoints()
			if precedent then
				bouton:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, 0)
			else
				bouton:SetPoint("TOPLEFT", panneau, "TOPLEFT", LISTE_X, LISTE_Y)
			end
			precedent = bouton
			bouton:Show()

			if bouton.foreverChoisi then
				if bouton:GetChecked() then
					bouton.foreverChoisi:Show()
				else
					bouton.foreverChoisi:Hide()
				end
			end
			if bouton.foreverCoche then
				if ensemblePorte(bouton.name) then
					bouton.foreverCoche:Show()
				else
					bouton.foreverCoche:Hide()
				end
			end
		else
			bouton:Hide()
		end
	end
end
ForeverUI.EquipmentSetsLayout = poserCartes

local function monter(volet)
	panneau = CreateFrame("Frame", "ForeverUIEquipmentPane", volet)
	panneau:SetPoint("TOPLEFT", volet.pierre, "BOTTOMLEFT", 0, 0)
	panneau:SetPoint("BOTTOMRIGHT", volet, "BOTTOMRIGHT", 0, 0)
	panneau:SetFrameLevel(volet:GetFrameLevel() + 3)

	panneau.bordure = ForeverUI.CreateNineSlice(panneau, ATLAS_BORDURE,
		BORDURE_COIN, BORDURE_MARGES, "BORDER")

	local trait = panneau:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(trait, ATLAS_TRAIT)
	trait:SetPoint("TOP", panneau, "BOTTOM", 0, LISTE_Y2)

	-- La molette fait defiler : camelot a une barre, que nous n'avons pas.
	panneau:EnableMouseWheel(true)
	panneau:SetScript("OnMouseWheel", function(self, sens)
		local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
		decalage = math.max(0, math.min(decalage - sens, total - cartesVisibles()))
		poserCartes()
	end)

	return panneau
end

-- Les trois boutons du bas, plus celui que le client garde pour effacer.
local function poserBoutons()
	local equiper = _G["GearManagerDialogEquipSet"]
	local enregistrer = _G["GearManagerDialogSaveSet"]
	local effacer = _G["GearManagerDialogDeleteSet"]

	if equiper then
		equiper:SetWidth(BOUTON_L)
		equiper:SetHeight(BOUTON_H)
		equiper:ClearAllPoints()
		equiper:SetPoint("BOTTOM", panneau, "BOTTOM", -BOUTON_ECART, BOUTON_Y)
	end
	if enregistrer then
		enregistrer:SetWidth(BOUTON_L)
		enregistrer:SetHeight(BOUTON_H)
		enregistrer:ClearAllPoints()
		enregistrer:SetPoint("BOTTOM", panneau, "BOTTOM", BOUTON_ECART, BOUTON_Y)
	end
	if effacer then
		effacer:SetWidth(BOUTON_L)
		effacer:SetHeight(BOUTON_H)
		effacer:ClearAllPoints()
		effacer:SetPoint("BOTTOM", enregistrer or panneau, "TOP", 0, 0)
		effacer:Hide()
	end

	if not panneau.nouveau then
		local nouveau = CreateFrame("Button", "ForeverUIEquipmentNewSet", panneau,
			"UIPanelButtonTemplate")
		nouveau:SetWidth(NOUVEAU_L)
		nouveau:SetHeight(NOUVEAU_H)
		nouveau:SetPoint("BOTTOM", panneau, "BOTTOM", 0, NOUVEAU_Y)
		nouveau:SetText(NEW_COMPACT_UNIT_FRAME_PROFILE or EQUIPMENT_MANAGER or "New Set")

		local plus = nouveau:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(plus, ATLAS_PLUS)
		plus:SetPoint("LEFT", nouveau, "LEFT", NOUVEAU_ICONE_X, 0)

		nouveau:SetScript("OnClick", function()
			local dialogue = _G["GearManagerDialog"]
			if dialogue then
				dialogue.selectedSetName = nil
				dialogue.selectedSet = nil
			end
			if GearManagerDialogSaveSet_OnClick then
				GearManagerDialogSaveSet_OnClick(_G["GearManagerDialogSaveSet"])
			end
		end)
		panneau.nouveau = nouveau
	end
end

-- LA FENETRE DU CLIENT PASSE DANS LE VOLET. On la vide de son art de
-- fenetre -- UIPanelDialogTemplate porte un fond, une bordure et une barre
-- de titre -- et on l'etale sur le panneau : elle n'est plus qu'un support
-- pour ses cartes et ses boutons.
local function accueillirDialogue()
	local dialogue = _G["GearManagerDialog"]
	if not dialogue or dialogue.foreverAccueilli then
		return
	end

	dialogue:SetParent(panneau)
	dialogue:ClearAllPoints()
	dialogue:SetAllPoints(panneau)
	dialogue:SetFrameLevel(panneau:GetFrameLevel() + 1)

	local regions = { dialogue:GetRegions() }
	for _, region in ipairs(regions) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
	if dialogue.title then
		dialogue.title:Hide()
	end
	local fermer = _G["GearManagerDialogCloseButton"]
	if fermer then
		fermer:Hide()
	end

	dialogue.foreverAccueilli = true
end

local function habiller()
	local panes = ForeverUI.CharacterPanes
	local volet = panes and panes.droit
	if not volet or not volet.pierre or InCombatLockdown() then
		return
	end

	if not panneau then
		monter(volet)
	end
	accueillirDialogue()
	poserBoutons()
	poserCartes()
end

ForeverUI.EquipmentPane = { Apply = habiller, Frame = function() return panneau end }

if hooksecurefunc then
	for _, nom in ipairs({ "GearManagerDialog_Update", "GearManagerDialog_OnShow" }) do
		if type(_G[nom]) == "function" then
			hooksecurefunc(nom, function() habiller() end)
		end
	end
end
