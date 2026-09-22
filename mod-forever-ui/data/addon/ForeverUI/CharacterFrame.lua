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
local SEPARATEUR_EMBOUT = 4             -- ses deux embouts, mesures sur l'art
local NIVEAU_HABILLAGE = 5              -- l'art passe au-dessus des volets
local PORTRAIT = 44                     -- voir le calcul plus bas
local PORTRAIT_X, PORTRAIT_Y = 25, -22.5

-- RELEVE -- PortraitFrameBaseTemplate : layoutType = "PortraitFrameTemplate".
-- Cette mise en page ne differe de celle des sacs QUE par son coin haut
-- gauche : un anneau plus large, pour un portrait de 62.
local COIN_PORTRAIT = "ui-frame-portraitmetal-cornertopleft"

-- Les cadres du client dont l'art d'epoque doit disparaitre : le cadre
-- lui-meme n'en porte qu'une partie.
local ANCIENS_CADRES = {
	"CharacterFrame", "PaperDollFrame", "PetPaperDollFrame", "SkillFrame",
	"ReputationFrame", "HonorFrame", "TokenFrame", "PaperDollItemsFrame",
	"CharacterAttributesFrame", "CharacterResistanceFrame",
}

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

-- L'art d'epoque ne tient pas qu'au cadre : la feuille de 3.3.5 le repartit
-- sur ses sous-cadres, qui sont des cadres fils et echappent donc a un
-- balayage du seul CharacterFrame. On balaie la liste.
--
-- Le portrait du client y passe aussi -- c'est une region du cadre. On en
-- pose un a nous, plus bas, sinon l'anneau reste vide.
local function effacerArtDepoque()
	for _, nom in ipairs(ANCIENS_CADRES) do
		local cadre = _G[nom]
		if cadre and cadre.GetRegions then
			local regions = { cadre:GetRegions() }
			for _, region in ipairs(regions) do
				if region and region.GetObjectType
					and region:GetObjectType() == "Texture" then
					region:SetAlpha(0)
				end
			end
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

	-- La source declare ce fond SANS ancrage : il remplit son volet. Pose a
	-- sa taille d'atlas (233 x 383) il laisserait 81 px nus en bas, le volet
	-- en faisant 464.
	local fondDroit = voletDroit:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fondDroit, ATLAS.fondDroit, true)
	fondDroit:SetAllPoints(voletDroit)

	local pierre = voletDroit:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(pierre, ATLAS.pierreDroite)
	pierre:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", 0, 0)
	voletDroit.pierre = pierre

	-- Le separateur des deux volets. Son element porte un embout a chaque
	-- bout : tendu tel quel sur 464 px, ils s'etalent. Trois tranches.
	local separateur = ForeverUI.CreateVerticalDivider(voletDroit, ATLAS.separateur,
		SEPARATEUR_EMBOUT, voletDroit:GetFrameLevel() + 1)
	separateur:SetWidth(SEPARATEUR)
	separateur:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", -6, -1)
	separateur:SetPoint("BOTTOMLEFT", voletDroit, "BOTTOMLEFT", -6, 0)
	voletDroit.separateur = separateur

	ForeverUI.CharacterPanes = { gauche = voletGauche, droit = voletDroit }
end

-- LE PORTRAIT. La source le pose en 62 x 62 dans PortraitContainer, un
-- cadre fils de niveau 400, et l'arrondit par un masque. Ici c'est le trou
-- de l'anneau qui decoupe, comme sur les sacs.
--
-- L'anneau de ce coin, MESURE au pixel a la taille ou il est dessine :
-- transparent jusqu'a 13 du centre, degrade jusqu'a 23, metal opaque de 24
-- a 31. Aucune taille ne couvre le degrade (il faudrait 46) tout en cachant
-- ses coins (il faudrait 43,8) : on prend 44, dont les coins tombent a 31,1
-- -- juste sous le metal -- et dont les bords s'arretent dans le degrade,
-- ou l'anneau est de toute facon a demi transparent. Le trou mesure place
-- son centre a (25 ; -22,5) du coin du cadre, la ou la source met le sien
-- a (26 ; -24).
local function poserPortrait(cadre)
	local hote = cadre.foreverHabillage or cadre
	if not cadre.foreverPortrait then
		local portrait = hote:CreateTexture(nil, "BACKGROUND")
		portrait:SetWidth(PORTRAIT)
		portrait:SetHeight(PORTRAIT)
		portrait:SetPoint("CENTER", hote, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
		cadre.foreverPortrait = portrait
	end

	if SetPortraitTexture then
		SetPortraitTexture(cadre.foreverPortrait, "player")
	end
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
		-- L'ORDRE COMPTE. Les volets sont des cadres fils : ils se dessinent
		-- au-dessus de toute region de leur parent. L'art du panneau doit
		-- donc vivre dans un cadre fils de niveau superieur, comme le
		-- NineSlice de la source -- sinon les fonds des volets recouvrent le
		-- metal, debordent sur le bord droit et mangent l'anneau du portrait.
		effacerArtDepoque()
		monterVolets(cadre)
		ForeverUI.SetPanelArt(cadre, {
			coinHautGauche = COIN_PORTRAIT,
			niveau = NIVEAU_HABILLAGE,
		})
		cadre.foreverSkinned = true
	end

	effacerArtDepoque()
	poserPortrait(cadre)

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
