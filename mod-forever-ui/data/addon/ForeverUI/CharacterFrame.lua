-- ForeverUI : la feuille du personnage.
--
-- Reprise a zero le 2026-09-22, avec la capture de reference sous les yeux :
-- docs/reference/camelot_feuille_personnage.png (923 x 663, echelle 4/3 --
-- le cadre y mesure 837 x 647 pour 631 x 484 logiques).
--
-- CE JALON pose le cadre, ses deux volets, les emplacements d'equipement et
-- les onglets lateraux. Le contenu du volet droit -- les statistiques et
-- leurs categories -- vient ensuite.
--
-- RELEVE DES SOURCES. Seuls camelot/ et shared/ font foi ; les trois
-- fichiers de la feuille existent en camelot/, il n'y a rien a trancher.
--
-- camelot/CharacterFrameConstants.lua
--   CHARACTER_FRAME_WIDTH 631, CHARACTER_FRAME_HEIGHT 484, replie 398.
--
-- camelot/CharacterFrame.xml
--   CharacterFrame herite de PortraitFrameBaseTemplate, dont le layoutType
--   est "PortraitFrameTemplate" : la meme mise en page que les sacs, au
--   coin haut gauche pres -- UI-Frame-PortraitMetal-CornerTopLeft, un
--   anneau plus large pour un portrait de 62. Son NineSlice et son
--   PortraitContainer (frameLevel 400) sont des CADRES FILS.
--   LeftPaneHost   398 de large, TOPLEFT (0, -20) et BOTTOMLEFT du cadre ;
--                  fond UI-Character-Info-General-BG (398 x 464).
--   RightPaneHost  233, accroche au TOPRIGHT du volet gauche ; fond
--                  UI-Character-Info-Stat-BG SANS ancrage -- donc il
--                  remplit -- et UI-Character-Info-Stat-StoneBG (233 x 85)
--                  en ARTWORK au TOPLEFT ; un common-framedivider de 11
--                  pose a -6, tendu sur la hauteur.
--   ModeTabs       64 x 384, TOPLEFT sur le TOPRIGHT du cadre, y = -30.
--
-- camelot/CharacterFrame.lua
--   CHARACTER_FRAME_TAB : Character 1, Reputation 2, Skills 3, PVP 4,
--   Currency 5, Statistics 6. L'onglet du personnage porte le PORTRAIT du
--   joueur, rogne a 0,03125 (UpdateCharacterModeTabPortrait).
--
-- SidePanelTabButtonMixin (blizzard_sharedxml)
--   la taille d'un onglet vient de son art : common-sidetab, 55 x 60 dans
--   la variante camelot, moins 5 de hauteur transparente -> 55 x 55.
--   L'icone est centree a (-3, 0).
--
-- camelot/PaperDollFrame.xml et .lua
--   emplacement 40 x 40, cadre UI-Character-Info-GearSlot a sa taille ;
--   colonne gauche TOPLEFT (24, -60), colonne droite TOPRIGHT (-20, -60),
--   ecart 6 ; l'arme principale au BOTTOM (-60, 30) du volet gauche quand
--   l'emplacement de distance est montre, puis secondaire et distance a
--   +6 ; distance et munitions en 27 avec -GearSlotSmall, munitions a +19
--   de la distance ; la scene du modele occupe tout le volet gauche.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   3.3.5 montre toujours un emplacement de distance -- arc, arme de jet ou
--   relique selon la classe : seule la variante a -60 sert.
--   Les icones d'onglet INV_SideTab_*_c60 que la source demande N'EXISTENT
--   PAS dans l'export du client : seul l'art commun des onglets y est. Les
--   onglets gardent donc le texte du client, sauf celui du personnage qui
--   porte son portrait comme dans la source.
--   Les emplacements, les onglets et le modele sont des cadres du client :
--   ils sont redimensionnes et reposes, jamais recrees, et jamais en
--   combat.

local LARGEUR, HAUTEUR = 631, 484
local VOLET_GAUCHE, VOLET_DROIT = 398, 233
local COMBLE = 20                       -- les volets commencent sous le titre
local NIVEAU_ART = 5                    -- l'art passe au-dessus des volets

local EMPLACEMENT = 40
local ECART = 6
local GAUCHE_X, GAUCHE_Y = 24, -60
local DROITE_X, DROITE_Y = -20, -60
local ARME_X, ARME_Y = -60, 30
local PETIT = 27
local MUNITIONS_ECART = 19

local SEPARATEUR = 11
local SEPARATEUR_EMBOUT = 4             -- mesure sur l'art : 11 x 50, deux embouts

local ONGLETS_L, ONGLETS_H = 64, 384    -- CharacterFrameModeTabs
local ONGLETS_Y = -30
local ONGLET_L, ONGLET_H = 55, 55       -- 55 x 60 moins 5 de transparent
local ONGLET_ICONE = 32
local ONGLET_ICONE_X = -3               -- GetIconAnchorOffsetsForTabArt
local PORTRAIT_ONGLET = 0.03125         -- UpdateCharacterModeTabPortrait

local PORTRAIT = 44                     -- voir le calcul plus bas
local PORTRAIT_X, PORTRAIT_Y = 25, -22.5

-- LE TITRE. TitledPanelMixin:SetTitleOffsets pose le conteneur du titre en
-- TOPLEFT (gauche, -1) et TOPRIGHT (droite, -1), avec son texte a TOP
-- (0, -5). ContainerFrame l'appelle avec 35 ; CharacterFrame ne l'appelle
-- PAS et garde donc les valeurs par defaut, 58 et -24. Le titre n'est donc
-- pas centre sur la fenetre mais entre le portrait et le bouton de
-- fermeture -- son milieu tombe a 332,5 sur 631, ce que la capture
-- confirme. CharacterFrameMixin:OnLoad ajoute SetTitleMaxLinesAndHeight(1,
-- 13) : une seule ligne.
local TITRE_GAUCHE, TITRE_DROITE = 58, -24
local TITRE_CONTENEUR, TITRE_TEXTE = -1, -5
local TITRE_BANDE = 20

-- ECART ASSUME, sur demande. characterFrameDisplayInfo fait suivre le
-- titre au sous-cadre affiche : le nom du joueur par defaut, puis
-- REPUTATION, CURRENCY, PVP, SKILLS ou STATISTICS selon le panneau, en
-- jaune. Ici la barre du haut porte TOUJOURS le nom du personnage et son
-- titre, quel que soit le panneau.

-- LE NIVEAU, LA RACE ET LA CLASSE, dans le volet DROIT.
--
-- RELEVE -- PaperDollLevelInfo : une bande de 220 x 20 posee au TOP
-- (0, -50) de PaperDollSidebarTabs, qui est elle-meme au TOP (0, -4) du
-- volet droit. La ligne tombe donc a -54 sous le haut du volet, centree.
-- C'est le "Druidesse de niveau 3" de la capture. 3.3.5 n'a qu'une ligne
-- pour les trois ; elle prend cette place.
local NIVEAU_Y = -54
local NIVEAU_LARGEUR, NIVEAU_HAUTEUR = 220, 20

-- LES FLECHES DU MODELE, centrees dans le volet gauche : leur milieu tombe
-- sur celui du volet, mesure a 276 sur la capture contre 275 pour le volet.
-- Leur hauteur est un REGLAGE, pas un releve -- la capture montre trois
-- boutons la ou 3.3.5 en a deux, et ils n'ont pas la meme taille.
local ROTATION_Y = -12
local ROTATION_ECART = 4

-- LE MODELE remonte d'autant dans son volet. Reglage lui aussi : la source
-- fait remplir tout le volet a sa scene, mais sa camera n'est pas celle de
-- 3.3.5, qui cadre le personnage plus bas.
local MODELE_Y = 24

-- LE PANNEAU DES RESISTANCES se decale vers la droite. On garde son
-- ancrage d'origine et on n'y ajoute que ce decalage, sinon chaque passage
-- le pousserait un peu plus loin.
local RESISTANCES_X = 30

local FERMETURE = 24
local FERMETURE_X, FERMETURE_Y = 1, 0
local FERMETURE_ATLAS = {
	{ atlas = "redbutton-exit", methode = "GetNormalTexture" },
	{ atlas = "redbutton-exit-pressed", methode = "GetPushedTexture" },
	{ atlas = "redbutton-exit-disabled", methode = "GetDisabledTexture" },
	{ atlas = "redbutton-highlight", methode = "GetHighlightTexture" },
}

local COIN_PORTRAIT = "ui-frame-portraitmetal-cornertopleft"

local ATLAS = {
	fondGauche = "ui-character-info-general-bg",
	fondDroit = "ui-character-info-stat-bg",
	pierre = "ui-character-info-stat-stonebg",
	separateur = "common-framedivider",
	emplacement = "ui-character-info-gearslot",
	petitEmplacement = "ui-character-info-gearslotsmall",
	onglet = "common-sidetab",
	ongletSurvol = "common-sidetab-hover",
	ongletChoisi = "common-sidetab-selected",
}

local COLONNE_GAUCHE = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
}
local COLONNE_DROITE = {
	"Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
}
local RANGEE_ARMES = { "MainHand", "SecondaryHand", "Ranged" }

-- L'art d'epoque ne tient pas qu'au cadre : 3.3.5 le repartit sur ses
-- sous-cadres, qui sont des cadres fils et echappent a un balayage du seul
-- CharacterFrame.
local ANCIENS_CADRES = {
	"CharacterFrame", "PaperDollFrame", "PetPaperDollFrame", "SkillFrame",
	"ReputationFrame", "HonorFrame", "TokenFrame", "PaperDollItemsFrame",
	"CharacterAttributesFrame", "CharacterResistanceFrame",
}

-- LA FENETRE SE DEPLACE PAR SA BARRE DU HAUT. Le cadre du client est
-- range par le systeme de panneaux : il le repose a chaque ouverture. On
-- retient donc la place choisie et on la repose apres lui, a chaque
-- passage de l'habillage -- qui tourne justement a l'ouverture.
local function placeRetenue()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

local voletGauche, voletDroit, barreOnglets
local onglets = {}

local function balayerTextures(cadre)
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

local function effacerArtDepoque()
	for _, nom in ipairs(ANCIENS_CADRES) do
		balayerTextures(_G[nom])
	end
end

local function monterVolets(cadre)
	if voletGauche then
		return
	end

	voletGauche = CreateFrame("Frame", "ForeverUICharacterLeftPane", cadre)
	voletGauche:SetWidth(VOLET_GAUCHE)
	voletGauche:SetPoint("TOPLEFT", cadre, "TOPLEFT", 0, -COMBLE)
	voletGauche:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", 0, 0)

	local fondGauche = voletGauche:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fondGauche, ATLAS.fondGauche)
	fondGauche:SetPoint("TOPLEFT", voletGauche, "TOPLEFT", 0, 0)

	voletDroit = CreateFrame("Frame", "ForeverUICharacterRightPane", cadre)
	voletDroit:SetWidth(VOLET_DROIT)
	voletDroit:SetPoint("TOPLEFT", voletGauche, "TOPRIGHT", 0, 0)
	voletDroit:SetPoint("BOTTOMLEFT", voletGauche, "BOTTOMRIGHT", 0, 0)

	-- La source declare ce fond sans ancrage : il remplit son volet. A sa
	-- taille d'atlas (233 x 383) il laisserait 81 px nus en bas.
	local fondDroit = voletDroit:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fondDroit, ATLAS.fondDroit, true)
	fondDroit:SetAllPoints(voletDroit)

	local pierre = voletDroit:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(pierre, ATLAS.pierre)
	pierre:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", 0, 0)
	voletDroit.pierre = pierre

	-- Le separateur porte un embout a chaque bout : tendu tel quel sur la
	-- hauteur du volet, ils s'etalent. Trois tranches.
	local separateur = ForeverUI.CreateVerticalDivider(voletDroit, ATLAS.separateur,
		SEPARATEUR_EMBOUT, voletDroit:GetFrameLevel() + 1)
	separateur:SetWidth(SEPARATEUR)
	separateur:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", -6, -1)
	separateur:SetPoint("BOTTOMLEFT", voletDroit, "BOTTOMLEFT", -6, 0)
	voletDroit.separateur = separateur

	ForeverUI.CharacterPanes = { gauche = voletGauche, droit = voletDroit }
end

-- LE PORTRAIT. La source le pose en 62 dans PortraitContainer et l'arrondit
-- par un masque ; ici c'est le trou de l'anneau qui decoupe, comme sur les
-- sacs. Cet anneau, mesure au pixel a la taille ou il est dessine, est
-- transparent jusqu'a 13 du centre, en degrade jusqu'a 23, opaque de 24 a
-- 31. Aucune taille ne couvre le degrade (il faudrait 46) tout en cachant
-- ses coins (43,8) : 44, dont les coins tombent a 31,1, juste sous le
-- metal. Le trou mesure a son centre en (25 ; -22,5), la ou la source met
-- le sien a (26 ; -24).
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

-- LE TITRE, dans un cadre fils. La source range le sien dans
-- TitleContainer, a frameLevel 510 : au-dessus du NineSlice, qui est a 400.
-- Il le faut, le metal etant en OVERLAY sur son propre cadre.
local function poserTitre(cadre)
	if not cadre.foreverBandeTitre then
		local ancien = _G["CharacterNameText"]
		if ancien then
			ancien:Hide()
		end

		local bande = CreateFrame("Frame", "ForeverUICharacterTitle", cadre)
		bande:SetFrameLevel(cadre:GetFrameLevel() + NIVEAU_ART + 2)
		bande:SetHeight(TITRE_BANDE)
		bande:SetPoint("TOPLEFT", cadre, "TOPLEFT", TITRE_GAUCHE, TITRE_CONTENEUR)
		bande:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", TITRE_DROITE, TITRE_CONTENEUR)

		local texte = bande:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		texte:SetPoint("TOP", bande, "TOP", 0, TITRE_TEXTE)
		texte:SetPoint("LEFT", bande, "LEFT")
		texte:SetPoint("RIGHT", bande, "RIGHT")
		texte:SetJustifyH("CENTER")
		cadre.foreverBandeTitre = bande
		cadre.foreverTitre = texte

		-- La barre du haut sert de poignee : clic maintenu, la fenetre suit.
		cadre:SetMovable(true)
		cadre:SetClampedToScreen(true)
		bande:EnableMouse(true)
		bande:RegisterForDrag("LeftButton")
		bande:SetScript("OnDragStart", function()
			if not InCombatLockdown() then
				cadre:StartMoving()
			end
		end)
		bande:SetScript("OnDragStop", function()
			cadre:StopMovingOrSizing()
			local point, _, pointRelatif, x, y = cadre:GetPoint(1)
			if point then
				placeRetenue()["feuille"] = {
					point = point, relativePoint = pointRelatif, x = x, y = y,
				}
			end
		end)
	end

	-- UnitPVPName rend le nom ACCOMPAGNE de son titre quand le joueur en
	-- porte un ; sans titre, c'est le nom seul.
	local texte = cadre.foreverTitre
	local nom = (UnitPVPName and UnitPVPName("player")) or UnitName("player")
	-- (le deplacement est monte plus bas, une seule fois)
	texte:SetText(nom or "")
	if HIGHLIGHT_FONT_COLOR then
		texte:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g,
			HIGHLIGHT_FONT_COLOR.b)
	end
end

-- Le bouton de fermeture : celui du client, rhabille du X rouge des
-- panneaux modernes et remis au coin haut droit.
local function poserFermeture(cadre)
	local fermer = _G["CharacterFrameCloseButton"]
	if not fermer then
		return
	end

	fermer:SetWidth(FERMETURE)
	fermer:SetHeight(FERMETURE)
	fermer:ClearAllPoints()
	fermer:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", FERMETURE_X, FERMETURE_Y)
	fermer:SetFrameLevel(cadre:GetFrameLevel() + NIVEAU_ART + 2)

	if cadre.foreverFermetureHabillee then
		return
	end

	for _, entree in ipairs(FERMETURE_ATLAS) do
		local texture = fermer[entree.methode] and fermer[entree.methode](fermer)
		if texture then
			ForeverUI.SetAtlas(texture, entree.atlas, true)
			texture:ClearAllPoints()
			texture:SetAllPoints(fermer)
			if entree.atlas == "redbutton-highlight" then
				texture:SetBlendMode("ADD")
			end
		end
	end
	cadre.foreverFermetureHabillee = true
end

local function habillerEmplacement(nom, cote, atlasCadre)
	local bouton = _G["Character" .. nom .. "Slot"]
	if not bouton then
		return nil
	end

	bouton:SetWidth(cote)
	bouton:SetHeight(cote)

	if not bouton.foreverCadre then
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

	precedent = nil
	for index, nom in ipairs(RANGEE_ARMES) do
		local cote = (nom == "Ranged") and PETIT or EMPLACEMENT
		local art = (nom == "Ranged") and ATLAS.petitEmplacement or ATLAS.emplacement
		local bouton = habillerEmplacement(nom, cote, art)
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

local function poserModele()
	local modele = CharacterModelFrame
	if not modele then
		return
	end

	modele:ClearAllPoints()
	modele:SetPoint("TOPLEFT", voletGauche, "TOPLEFT", 0, MODELE_Y)
	modele:SetPoint("BOTTOMRIGHT", voletGauche, "BOTTOMRIGHT", 0, MODELE_Y)

	-- Les fleches de rotation : centrees sur le volet, cote a cote.
	local gauche = _G["CharacterModelFrameRotateLeftButton"]
	local droite = _G["CharacterModelFrameRotateRightButton"]
	if gauche and droite then
		local demi = gauche:GetWidth() / 2 + ROTATION_ECART / 2

		gauche:ClearAllPoints()
		gauche:SetPoint("TOP", voletGauche, "TOP", -demi, ROTATION_Y)
		gauche:SetFrameLevel(modele:GetFrameLevel() + 2)

		droite:ClearAllPoints()
		droite:SetPoint("TOP", voletGauche, "TOP", demi, ROTATION_Y)
		droite:SetFrameLevel(modele:GetFrameLevel() + 2)
	end
end

-- Le panneau des resistances, decale vers la droite. Son ancrage d'origine
-- est garde a part : on repart toujours de lui, jamais de la position
-- courante, qui derive a chaque passage.
local function poserResistances()
	local cadre = _G["CharacterResistanceFrame"]
	if not cadre or not cadre.GetPoint or cadre:GetNumPoints() == 0 then
		return
	end

	if not cadre.foreverAncrage then
		local point, cible, pointCible, x, y = cadre:GetPoint(1)
		cadre.foreverAncrage = { point, cible, pointCible, x or 0, y or 0 }
	end

	local a = cadre.foreverAncrage
	cadre:ClearAllPoints()
	cadre:SetPoint(a[1], a[2], a[3], a[4] + RESISTANCES_X, a[5])
end

-- La ligne du niveau, de la race et de la classe.
--
-- PIEGE 3.3.5. Une region ne se REPARENTE pas : SetParent n'est pas dans la
-- table des methodes de FontString de ce client. Ancrer celle du client au
-- volet ne suffirait pas non plus -- elle appartient au cadre, donc elle se
-- dessinerait SOUS les volets, qui sont des cadres fils. On efface donc la
-- sienne et on pose la notre dans le volet, en recopiant son texte : c'est
-- le client qui le compose, nous ne faisons que l'afficher.
local function poserNiveau()
	local source = _G["CharacterLevelText"]

	if not voletDroit.ligneNiveau then
		local ligne = voletDroit:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		ligne:SetPoint("TOP", voletDroit, "TOP", 0, NIVEAU_Y)
		ligne:SetWidth(NIVEAU_LARGEUR)
		ligne:SetHeight(NIVEAU_HAUTEUR)
		ligne:SetJustifyH("CENTER")
		ligne:SetJustifyV("MIDDLE")
		voletDroit.ligneNiveau = ligne
	end

	if source then
		source:Hide()
		voletDroit.ligneNiveau:SetText(source:GetText() or "")
	end
end

-- LES ONGLETS LATERAUX. camelot les met en colonne A DROITE, dehors : une
-- barre de 64 x 384 ancree au TOPRIGHT du cadre, 30 px sous son haut. Les
-- onglets du bas de 3.3.5 sont donc reposes la, empiles.
local function poserOnglets(cadre)
	if not barreOnglets then
		barreOnglets = CreateFrame("Frame", "ForeverUICharacterModeTabs", cadre)
		barreOnglets:SetWidth(ONGLETS_L)
		barreOnglets:SetHeight(ONGLETS_H)
		barreOnglets:SetPoint("TOPLEFT", cadre, "TOPRIGHT", 0, ONGLETS_Y)
	end

	local precedent
	local index = 1
	while true do
		local onglet = _G["CharacterFrameTab" .. index]
		if not onglet then
			break
		end

		if not onglet.foreverSkinned then
			balayerTextures(onglet)
			for _, methode in ipairs({ "GetNormalTexture", "GetPushedTexture",
				"GetDisabledTexture", "GetHighlightTexture" }) do
				local texture = onglet[methode] and onglet[methode](onglet)
				if texture then
					texture:SetAlpha(0)
				end
			end

			local fond = onglet:CreateTexture(nil, "BACKGROUND")
			ForeverUI.SetAtlas(fond, ATLAS.onglet, true)
			fond:SetAllPoints(onglet)
			onglet.foreverFond = fond

			local survol = onglet:CreateTexture(nil, "HIGHLIGHT")
			ForeverUI.SetAtlas(survol, ATLAS.ongletSurvol, true)
			survol:SetAllPoints(onglet)

			local icone = onglet:CreateTexture(nil, "ARTWORK")
			icone:SetWidth(ONGLET_ICONE)
			icone:SetHeight(ONGLET_ICONE)
			icone:SetPoint("CENTER", onglet, "CENTER", ONGLET_ICONE_X, 0)
			icone:Hide()
			onglet.foreverIcone = icone

			-- Le texte du client reste : les icones que la source demande
			-- pour les autres onglets n'existent pas dans l'export.
			local texte = _G["CharacterFrameTab" .. index .. "Text"]
			if texte then
				texte:ClearAllPoints()
				texte:SetPoint("CENTER", onglet, "CENTER", ONGLET_ICONE_X, 0)
				texte:SetWidth(ONGLET_L - 10)
			end

			onglet.foreverSkinned = true
			onglets[index] = onglet
		end

		onglet:SetWidth(ONGLET_L)
		onglet:SetHeight(ONGLET_H)
		onglet:ClearAllPoints()
		if precedent then
			onglet:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, 0)
		else
			onglet:SetPoint("TOPLEFT", barreOnglets, "TOPLEFT", 0, 0)
		end
		precedent = onglet
		index = index + 1
	end

	-- L'onglet du personnage porte le portrait du joueur, rogne comme le
	-- fait UpdateCharacterModeTabPortrait.
	local premier = onglets[1]
	if premier and premier.foreverIcone and SetPortraitTexture then
		SetPortraitTexture(premier.foreverIcone, "player")
		premier.foreverIcone:SetTexCoord(PORTRAIT_ONGLET, 1 - PORTRAIT_ONGLET,
			PORTRAIT_ONGLET, 1 - PORTRAIT_ONGLET)
		premier.foreverIcone:Show()
		local texte = _G["CharacterFrameTab1Text"]
		if texte then
			texte:Hide()
		end
	end
end

-- Le systeme de panneaux du client repose la fenetre a chaque ouverture :
-- on remet la place retenue apres lui.
local function reposerLaPlace(cadre)
	local place = placeRetenue()["feuille"]
	if not place or InCombatLockdown() then
		return
	end

	cadre:ClearAllPoints()
	cadre:SetPoint(place.point, UIParent, place.relativePoint or place.point,
		place.x or 0, place.y or 0)
end

local function habiller()
	local cadre = CharacterFrame
	if not cadre or InCombatLockdown() then
		return
	end

	cadre:SetWidth(LARGEUR)
	cadre:SetHeight(HAUTEUR)

	if not cadre.foreverSkinned then
		-- L'ORDRE COMPTE. Les volets sont des cadres fils : ils recouvrent
		-- toute region de leur parent. L'art du panneau doit donc vivre
		-- dans un cadre fils de niveau superieur, comme le NineSlice de la
		-- source, sinon les fonds le recouvrent.
		effacerArtDepoque()
		monterVolets(cadre)
		ForeverUI.SetPanelArt(cadre, {
			coinHautGauche = COIN_PORTRAIT,
			niveau = NIVEAU_ART,
		})
		cadre.foreverSkinned = true
	end

	effacerArtDepoque()
	if ForeverUI.UpdatePanelCorners then
		ForeverUI.UpdatePanelCorners(cadre)
	end
	poserPortrait(cadre)
	poserTitre(cadre)
	reposerLaPlace(cadre)
	poserFermeture(cadre)
	poserModele()
	poserResistances()
	poserNiveau()
	poserEmplacements()
	poserOnglets(cadre)
end

ForeverUI.CharacterSheet = { Apply = habiller, Tabs = onglets }

if hooksecurefunc then
	for _, nomFonction in ipairs({ "CharacterFrame_ShowSubFrame", "PaperDollFrame_OnShow",
		"PaperDollFrame_SetLevel", "CharacterFrame_Collapse", "CharacterFrame_Expand" }) do
		if type(_G[nomFonction]) == "function" then
			hooksecurefunc(nomFonction, habiller)
		end
	end
end

local veilleur = CreateFrame("Frame", "ForeverUICharacterWatcher")
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:RegisterEvent("PLAYER_REGEN_ENABLED")
veilleur:RegisterEvent("UNIT_INVENTORY_CHANGED")
veilleur:RegisterEvent("UNIT_PORTRAIT_UPDATE")
veilleur:SetScript("OnEvent", habiller)

if CharacterFrame then
	CharacterFrame:HookScript("OnShow", habiller)
end

habiller()
