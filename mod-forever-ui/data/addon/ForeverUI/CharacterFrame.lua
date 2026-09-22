-- ForeverUI : la feuille du personnage.
--
-- JALON 1 : le cadre, ses deux volets et les emplacements d'equipement.
-- Le volet droit (statistiques, onglets lateraux) et les autres onglets
-- -- reputation, competences, PvP, devises -- viendront ensuite.
--
-- RELEVE DES SOURCES -- camelot/, le seul dossier qui fasse foi ici avec
-- shared/ ; tout ce qui suit en vient.
--
-- camelot/CharacterFrameConstants.lua
--   CHARACTER_FRAME_WIDTH = 631, CHARACTER_FRAME_HEIGHT = 484
--   CHARACTER_FRAME_COLLAPSED_WIDTH = 398 (le volet droit se replie)
--
-- camelot/CharacterFrame.xml
--   CharacterFrame herite de PortraitFrameBaseTemplate : le meme panneau
--   que les sacs, avec portrait, titre et bouton de fermeture.
--   LeftPaneHost   398 de large, TOPLEFT (0, -20) et BOTTOMLEFT du cadre,
--                  fond UI-Character-Info-General-BG a sa taille d'atlas
--   RightPaneHost  233 de large, accroche au TOPRIGHT du volet gauche,
--                  fonds UI-Character-Info-Stat-BG puis -Stat-StoneBG en
--                  ARTWORK, et un common-framedivider de 11 pose a -6
--
-- camelot/PaperDollFrame.xml
--   emplacement    PaperDollItemSlotButtonTemplate, 40 x 40, son cadre est
--                  l'atlas UI-Character-Info-GearSlot a sa taille (55)
--   colonne gauche TOPLEFT (24, -60) du volet gauche, puis chaque suivant
--                  6 px sous le precedent : tete, cou, epaules, dos, torse,
--                  chemise, tabard, poignets
--   colonne droite TOPRIGHT (-20, -60), meme pas : mains, taille, jambes,
--                  pieds, deux anneaux, deux bijoux
--   munitions      27 x 27, LEFT (+19) de l'emplacement de distance, son
--                  cadre est UI-Character-Info-GearSlotSmall
--   modele         la scene occupe tout le volet gauche
--
-- camelot/PaperDollFrame.lua, PaperDollItemSlotButton_OnLoad
--   l'arme principale se pose au BOTTOM du volet gauche : (-60, 30) quand
--   l'emplacement de distance est montre, (-40, 30) sinon -- et dans ce
--   dernier cas l'emplacement de distance est masque. Les deux autres
--   suivent, 6 px a droite chacun.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   3.3.5 montre toujours un emplacement de distance (arc, arme de jet ou
--   relique selon la classe) : on prend donc la variante a -60.
--   Le cadre du client fait 384 x 512 et ses emplacements 37 : tout est
--   redimensionne et repose, jamais recree -- ce sont des cadres du client
--   qui portent le glisser-deposer de l'equipement.
--   Les onglets du bas de 3.3.5 restent en place pour l'instant ; camelot
--   les met sur le cote (CharacterFrameModeTabs, 64 x 384), ce sera pour
--   le jalon qui traitera le volet droit.

local LARGEUR, HAUTEUR = 631, 484
local VOLET_GAUCHE, VOLET_DROIT = 398, 233
local COMBLE = 20                       -- les volets commencent la, sous le titre
local EMPLACEMENT = 40
local ECART = 6
local GAUCHE_X, GAUCHE_Y = 24, -60
local DROITE_X, DROITE_Y = -20, -60
local ARME_X, ARME_Y = -60, 30          -- BOTTOM du volet gauche
local PETIT = 27                        -- distance et munitions
local MUNITIONS_ECART = 19
local SEPARATEUR = 11                   -- common-framedivider

local ATLAS = {
	fondGauche = "ui-character-info-general-bg",
	fondDroit = "ui-character-info-stat-bg",
	pierreDroite = "ui-character-info-stat-stonebg",
	separateur = "common-framedivider",
	emplacement = "ui-character-info-gearslot",
	petitEmplacement = "ui-character-info-gearslotsmall",
}

local COLONNE_GAUCHE = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
}
local COLONNE_DROITE = {
	"Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
}
local RANGEE_ARMES = { "MainHand", "SecondaryHand", "Ranged" }

local voletGauche, voletDroit

-- Toutes les regions du cadre lui-meme s'effacent : l'art d'epoque de la
-- feuille est fait de quatre quartiers, et on ne se fie pas a leurs noms.
-- Les sous-cadres sont des cadres fils, ils ne sont pas touches.
local function effacerArtDepoque(cadre)
	if not cadre or not cadre.GetRegions then
		return
	end

	local regions = { cadre:GetRegions() }
	for _, region in ipairs(regions) do
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
end

local function monterVolets(cadre)
	if voletGauche then
		return
	end

	-- LeftPaneHost : 398 de large, du haut moins le comble jusqu'au bas.
	voletGauche = CreateFrame("Frame", "ForeverUICharacterLeftPane", cadre)
	voletGauche:SetWidth(VOLET_GAUCHE)
	voletGauche:SetPoint("TOPLEFT", cadre, "TOPLEFT", 0, -COMBLE)
	voletGauche:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", 0, 0)

	local fondGauche = voletGauche:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fondGauche, ATLAS.fondGauche)
	fondGauche:SetPoint("TOPLEFT", voletGauche, "TOPLEFT", 0, 0)

	-- RightPaneHost : 233, accroche a la droite du volet gauche.
	voletDroit = CreateFrame("Frame", "ForeverUICharacterRightPane", cadre)
	voletDroit:SetWidth(VOLET_DROIT)
	voletDroit:SetPoint("TOPLEFT", voletGauche, "TOPRIGHT", 0, 0)
	voletDroit:SetPoint("BOTTOMLEFT", voletGauche, "BOTTOMRIGHT", 0, 0)

	local fondDroit = voletDroit:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fondDroit, ATLAS.fondDroit)
	fondDroit:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", 0, 0)

	local pierre = voletDroit:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(pierre, ATLAS.pierreDroite)
	pierre:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", 0, 0)
	voletDroit.pierre = pierre

	-- Le separateur des deux volets, tendu sur toute la hauteur.
	local separateur = voletDroit:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(separateur, ATLAS.separateur, true)
	separateur:SetWidth(SEPARATEUR)
	separateur:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", -6, -1)
	separateur:SetPoint("BOTTOMLEFT", voletDroit, "BOTTOMLEFT", -6, 0)

	ForeverUI.CharacterPanes = { gauche = voletGauche, droit = voletDroit }
end

-- RELEVE -- PaperDollItemSlotButtonTemplate : 40 x 40, et son cadre est
-- l'atlas UI-Character-Info-GearSlot pose a sa taille, centre.
local function habillerEmplacement(nom, cote, atlasCadre)
	local bouton = _G["Character" .. nom .. "Slot"]
	if not bouton then
		return nil
	end

	bouton:SetWidth(cote)
	bouton:SetHeight(cote)

	if not bouton.foreverCadre then
		-- L'art d'epoque du bouton s'efface ; le notre se pose dessous,
		-- comme la source qui met le sien en BACKGROUND d'un cadre fils.
		local normale = bouton:GetNormalTexture()
		if normale then
			normale:SetAlpha(0)
		end

		local cadre = bouton:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(cadre, atlasCadre)
		cadre:SetPoint("CENTER", bouton, "CENTER", 0, 0)
		bouton.foreverCadre = cadre
	end

	local icone = _G["Character" .. nom .. "SlotIconTexture"]
	if icone then
		icone:ClearAllPoints()
		icone:SetAllPoints(bouton)
		icone:SetTexCoord(0, 1, 0, 1)
	end

	return bouton
end

local function poserEmplacements()
	if InCombatLockdown() then
		return
	end

	local precedent
	for index, nom in ipairs(COLONNE_GAUCHE) do
		local bouton = habillerEmplacement(nom, EMPLACEMENT, ATLAS.emplacement)
		if bouton then
			bouton:ClearAllPoints()
			if index == 1 then
				bouton:SetPoint("TOPLEFT", voletGauche, "TOPLEFT", GAUCHE_X, GAUCHE_Y)
			else
				bouton:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, -ECART)
			end
			precedent = bouton
		end
	end

	precedent = nil
	for index, nom in ipairs(COLONNE_DROITE) do
		local bouton = habillerEmplacement(nom, EMPLACEMENT, ATLAS.emplacement)
		if bouton then
			bouton:ClearAllPoints()
			if index == 1 then
				bouton:SetPoint("TOPRIGHT", voletGauche, "TOPRIGHT", DROITE_X, DROITE_Y)
			else
				bouton:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, -ECART)
			end
			precedent = bouton
		end
	end

	-- La rangee des armes, posee sur le bas du volet gauche. 3.3.5 montre
	-- toujours un emplacement de distance : on prend la variante a -60.
	precedent = nil
	for index, nom in ipairs(RANGEE_ARMES) do
		local cote = (nom == "Ranged") and PETIT or EMPLACEMENT
		local atlasCadre = (nom == "Ranged") and ATLAS.petitEmplacement or ATLAS.emplacement
		local bouton = habillerEmplacement(nom, cote, atlasCadre)
		if bouton then
			bouton:ClearAllPoints()
			if index == 1 then
				bouton:SetPoint("BOTTOM", voletGauche, "BOTTOM", ARME_X, ARME_Y)
			else
				bouton:SetPoint("TOPLEFT", precedent, "TOPRIGHT", ECART, 0)
			end
			precedent = bouton
		end
	end

	local munitions = habillerEmplacement("Ammo", PETIT, ATLAS.petitEmplacement)
	if munitions and precedent then
		munitions:ClearAllPoints()
		munitions:SetPoint("LEFT", precedent, "RIGHT", MUNITIONS_ECART, 0)
	end
end

-- La scene de camelot occupe tout le volet gauche ; le modele de 3.3.5
-- prend la meme place.
local function poserModele()
	local modele = CharacterModelFrame
	if not modele or InCombatLockdown() then
		return
	end

	modele:ClearAllPoints()
	modele:SetPoint("TOPLEFT", voletGauche, "TOPLEFT", 0, 0)
	modele:SetPoint("BOTTOMRIGHT", voletGauche, "BOTTOMRIGHT", 0, 0)
end

local function habiller()
	local cadre = CharacterFrame
	if not cadre or InCombatLockdown() then
		return
	end

	cadre:SetWidth(LARGEUR)
	cadre:SetHeight(HAUTEUR)

	if not cadre.foreverSkinned then
		effacerArtDepoque(cadre)
		monterVolets(cadre)
		ForeverUI.SetPanelArt(cadre)
		cadre.foreverSkinned = true
	end

	if ForeverUI.UpdatePanelCorners then
		ForeverUI.UpdatePanelCorners(cadre)
	end

	poserModele()
	poserEmplacements()
end

ForeverUI.CharacterSheet = { Apply = habiller }

if hooksecurefunc then
	for _, nomFonction in ipairs({ "CharacterFrame_ShowSubFrame", "PaperDollFrame_OnShow",
		"PaperDollFrame_SetLevel" }) do
		if type(_G[nomFonction]) == "function" then
			hooksecurefunc(nomFonction, habiller)
		end
	end
end

local veilleur = CreateFrame("Frame", "ForeverUICharacterWatcher")
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:RegisterEvent("PLAYER_REGEN_ENABLED")
veilleur:RegisterEvent("UNIT_INVENTORY_CHANGED")
veilleur:SetScript("OnEvent", habiller)

if CharacterFrame then
	CharacterFrame:HookScript("OnShow", habiller)
end

habiller()
