-- ForeverUI : l'onglet de reputation.
--
-- RELEVE -- camelot/ReputationFrame.xml :
--
--   ReputationFrame     setAllPoints, parent CharacterFrame, useParentLevel
--   la liste            TOPLEFT sur CharacterFrameLeftPaneHost (10, -40)
--                       BOTTOMRIGHT sur le meme (-25, 15)
--   deux traits         UI-Character-Info-ScrollLine-Long, centres sur le
--                       TOP et sur le BOTTOM de la liste
--   ReputationEntryTemplate      hauteur 30
--   ReputationHeaderTemplate     hauteur 28, bouton common-button-list-collapseExpand
--   ReputationSubHeaderTemplate  hauteur 22
--   ReputationBarTemplate        160 x 29, herite de ColoredProgressBarTemplate
--   son icone                    16 x 16, CENTER sur le LEFT de la barre (4, 0)
--   le nom                       du LEFT jusqu'au LEFT de la barre, x = -10
--
-- RELEVE -- camelot/SharedXML/progressbars/ColoredProgressBar.xml :
--   fond         common-stat-bar-bg
--   remplissage  common-stat-bar-white, hauteur 15, ancre LEFT, TEINTE
--   masque       common-stat-bar-Mask, qui arrondit les bouts du remplissage
--
-- CE QUE 3.3.5 DONNE EN FACE. ReputationFrame existe, avec quinze lignes
-- ReputationBar1..15 de 295 x 20 : un bouton deplier/replier de 13 a gauche,
-- une StatusBar de 101 x 13 a droite, le nom et l'intitule d'attitude. Les
-- lignes sont ancrees UNE FOIS dans le XML et ReputationFrame_Update ne fait
-- que les remplir : on peut donc les reposer une fois pour toutes.
--
-- CE QUI DIFFERE, ET POURQUOI :
--   * 3.3.5 n'a pas de MaskTexture. Les bouts du remplissage restent donc
--     carres la ou camelot les arrondit. Le fond, lui, porte ses arrondis
--     dans son art : le defaut ne se voit qu'a barre pleine.
--   * Les trois hauteurs de camelot -- 30, 28, 22 -- supposent une liste qui
--     mesure chaque ligne. 3.3.5 a un PAS UNIQUE, que sa pagination utilise
--     pour savoir combien de lignes tiennent : on garde donc un seul pas,
--     celui des entrees.
--   * Le nombre de lignes affichees est une constante du client, calee sur
--     l'ancienne fenetre. Avec le pas de camelot, moins de lignes tiennent
--     dans le volet : on la recalcule au lieu de laisser deborder.
--   * Les lignes d'arborescence -- LeftLine, BottomLine, les deux
--     TopTreeTexture -- n'existent pas chez camelot, qui marque la hierarchie
--     par le retrait du nom. Elles s'effacent.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

-- La liste, dans le volet gauche.
local LISTE_X, LISTE_Y = 10, -40
local LISTE_X2, LISTE_Y2 = -25, 15

local LIGNE_HAUTEUR = 30                -- ReputationEntryTemplate
local BARRE_L, BARRE_H = 160, 29        -- ReputationBarTemplate
local REMPLISSAGE_H = 15                -- ColoredProgressBarTemplate
local BOUTON = 20                       -- common-button-list-collapseExpand
local BOUTON_X = 3
local NOM_X = 26                        -- apres le bouton
local NOM_ECART = -10                   -- du LEFT de la barre

local ATLAS_FOND = "common-stat-bar-bg"
local ATLAS_REMPLISSAGE = "common-stat-bar-white"
local ATLAS_BOUTON = "common-button-list-collapseexpand"
local ATLAS_TRAIT = "ui-character-info-scrollline-long"

-- LA TAILLE DU VOLET NE SE MESURE PAS ICI.
--
-- Un contenu se batit a sa premiere ouverture, qui peut arriver AVANT que le
-- client ait pose la fenetre : GetHeight rend alors zero, et le calcul du
-- nombre de lignes donnerait n'importe quoi. Ces deux nombres sont ceux de
-- notre propre feuille -- 484 de haut moins les 20 du bandeau de titre, 398
-- de large -- donc des constantes, pas des mesures. La mesure sert quand
-- meme, quand elle est credible : elle suivra un jour un volet redimensionne.
local VOLET_L, VOLET_H = 398, 464

-- L'art d'epoque de cet ecran : quatre morceaux de parchemin et deux
-- intitules de colonne, que camelot n'a pas.
local ANCIENS = { "ReputationFrameFactionLabel", "ReputationFrameStandingLabel",
                  "ReputationFrameTopTreeTexture", "ReputationFrameTopTreeTexture2" }

local monte = false

local function balayerFond(cadre)
	if not cadre or not cadre.GetRegions then
		return
	end
	for _, region in ipairs({ cadre:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
end

-- LE BOUTON DEPLIER / REPLIER. camelot lui donne un seul art, retourne selon
-- l'etat ; 3.3.5 en pose deux, UI-PlusButton-Up et UI-MinusButton-Up, et
-- ReputationFrame_Update les repose a chaque passage. On greffe donc APRES
-- lui, sinon il reprendrait la main.
local function habillerBouton(bouton, replie)
	if not bouton then
		return
	end

	if not bouton.foreverFond then
		bouton:SetWidth(BOUTON)
		bouton:SetHeight(BOUTON)
		local fond = bouton:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(fond, ATLAS_BOUTON, true)
		fond:SetPoint("CENTER", bouton, "CENTER", 0, 0)
		bouton.foreverFond = fond

		for _, methode in ipairs({ "GetNormalTexture", "GetPushedTexture",
			"GetHighlightTexture" }) do
			local texture = bouton[methode] and bouton[methode](bouton)
			if texture then
				texture:SetAlpha(0)
			end
		end
	end

	-- Deplie, la fleche pointe vers le bas : une rotation d'un quart de tour
	-- par les coordonnees, faute de SetRotation sur ce client.
	local e = ForeverUI.AtlasEntry and ForeverUI.AtlasEntry(ATLAS_BOUTON)
	if e then
		if replie then
			bouton.foreverFond:SetTexCoord(e[2], e[3], e[4], e[5])
		else
			bouton.foreverFond:SetTexCoord(e[3], e[2], e[4], e[5])
		end
	end
end

-- UNE LIGNE. Le contenu reste au client ; on ne fait que la reposer et
-- l'habiller.
local function habillerLigne(index, largeur)
	local ligne = _G["ReputationBar" .. index]
	if not ligne then
		return nil
	end

	ligne:SetWidth(largeur)
	ligne:SetHeight(LIGNE_HAUTEUR)

	-- Les lignes d'arborescence de 3.3.5 : camelot n'en a pas.
	for _, suffixe in ipairs({ "LeftLine", "BottomLine", "Background" }) do
		local piece = _G["ReputationBar" .. index .. suffixe]
		if piece then
			piece:SetAlpha(0)
		end
	end

	local barre = _G["ReputationBar" .. index .. "ReputationBar"]
	if barre and not barre.foreverFond then
		barre:SetWidth(BARRE_L)
		barre:SetHeight(BARRE_H)

		-- La StatusBar du client garde sa valeur -- c'est elle qu'on lit --
		-- mais plus son art. On EFFACE sa texture plutot que de la remplacer :
		-- SetStatusBarTexture attend un chemin, et lui en donner un vide ou
		-- nul se comporte mal selon les clients.
		local sienne = barre.GetStatusBarTexture and barre:GetStatusBarTexture()
		if sienne then
			sienne:SetAlpha(0)
		end
		balayerFond(barre)

		local fond = barre:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(fond, ATLAS_FOND)
		fond:SetAllPoints(barre)
		barre.foreverFond = fond

		local remplissage = barre:CreateTexture(nil, "BORDER")
		remplissage:SetPoint("LEFT", barre, "LEFT", 0, 0)
		remplissage:SetHeight(REMPLISSAGE_H)
		barre.foreverRemplissage = remplissage
	end

	local nom = _G["ReputationBar" .. index .. "FactionName"]
	if nom and barre then
		nom:ClearAllPoints()
		nom:SetPoint("LEFT", ligne, "LEFT", NOM_X, 0)
		nom:SetPoint("RIGHT", barre, "LEFT", NOM_ECART, 0)
		nom:SetJustifyH("LEFT")
	end

	local attitude = _G["ReputationBar" .. index .. "ReputationBarFactionStanding"]
	if attitude and barre then
		attitude:ClearAllPoints()
		attitude:SetPoint("CENTER", barre, "CENTER", 0, 0)
	end

	local bouton = _G["ReputationBar" .. index .. "ExpandOrCollapseButton"]
	if bouton then
		bouton:ClearAllPoints()
		bouton:SetPoint("LEFT", ligne, "LEFT", BOUTON_X, 0)
	end

	return ligne
end

-- LE REMPLISSAGE SUIT LA VALEUR, ET SA COULEUR L'ATTITUDE.
--
-- FACTION_BAR_COLORS est la table du client : huit attitudes, de hai a
-- exalte. camelot teinte le meme remplissage blanc ; on fait de meme, plutot
-- que de chercher un art par attitude qui n'existe pas.
local function majRemplissages()
	for index = 1, (NUM_FACTIONS_DISPLAYED or 0) do
		local barre = _G["ReputationBar" .. index .. "ReputationBar"]
		if barre and barre.foreverRemplissage then
			local _, maximum = barre:GetMinMaxValues()
			local valeur = barre:GetValue() or 0
			local fraction = 0
			if maximum and maximum > 0 then
				fraction = valeur / maximum
			end
			ForeverUI.SetAtlasFill(barre.foreverRemplissage, ATLAS_REMPLISSAGE,
				fraction, BARRE_L)
			barre.foreverRemplissage:SetHeight(REMPLISSAGE_H)

			local ligne = _G["ReputationBar" .. index]
			local couleur = ligne and ligne.standingID and FACTION_BAR_COLORS
				and FACTION_BAR_COLORS[ligne.standingID]
			if couleur then
				barre.foreverRemplissage:SetVertexColor(couleur.r, couleur.g, couleur.b)
			end
		end

		local bouton = _G["ReputationBar" .. index .. "ExpandOrCollapseButton"]
		local ligne = _G["ReputationBar" .. index]
		if bouton and ligne then
			habillerBouton(bouton, ligne.isCollapsed)
		end
	end
end
ForeverUI.ReputationFills = majRemplissages

-- L'ATTITUDE N'EST PAS RETENUE PAR LE CLIENT. ReputationFrame_Update la lit
-- pour ecrire l'intitule, puis l'oublie ; il nous la faut pour teinter. On la
-- reprend a la source -- GetFactionInfo -- au meme indice que lui.
local function retenirAttitudes()
    local total = (GetNumFactions and GetNumFactions()) or 0
    local decalage = (FauxScrollFrame_GetOffset
        and _G["ReputationListScrollFrame"]
        and FauxScrollFrame_GetOffset(_G["ReputationListScrollFrame"])) or 0
    for index = 1, (NUM_FACTIONS_DISPLAYED or 0) do
        local ligne = _G["ReputationBar" .. index]
        if ligne then
            local rang = decalage + index
            if rang <= total then
                local _, _, standingID = GetFactionInfo(rang)
                ligne.standingID = standingID
            else
                ligne.standingID = nil
            end
        end
    end
end

local function monter(hote)
	local cadre = _G["ReputationFrame"]
	if not cadre or not hote then
		return nil, {}
	end

	-- L'ecran occupe le volet gauche, comme les autres.
	cadre:ClearAllPoints()
	cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
	cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)

	if not monte then
		monte = true
		balayerFond(cadre)
		for _, nom in ipairs(ANCIENS) do
			local piece = _G[nom]
			if piece then
				piece:SetAlpha(0)
			end
		end

		-- COMBIEN DE LIGNES TIENNENT. Le client en annonce quinze, calees
		-- sur sa fenetre ; au pas de camelot, le volet en porte moins. On
		-- recalcule plutot que de laisser deborder, et on le dit au client :
		-- sa pagination se sert des deux memes nombres.
		local hauteur = hote:GetHeight() or 0
		if hauteur < 100 then
			hauteur = VOLET_H
		end

		local place = math.floor((hauteur + LISTE_Y - LISTE_Y2) / LIGNE_HAUTEUR)
		if place < 1 then
			place = 1
		end
		if place > 15 then
			place = 15
		end
		NUM_FACTIONS_DISPLAYED = place
		REPUTATIONFRAME_FACTIONHEIGHT = LIGNE_HAUTEUR

		local largeur = hote:GetWidth() or 0
		if largeur < 100 then
			largeur = VOLET_L
		end
		largeur = largeur + LISTE_X2 - LISTE_X

		local precedente
		for index = 1, 15 do
			local ligne = habillerLigne(index, largeur)
			if ligne then
				ligne:ClearAllPoints()
				if index > place then
					ligne:Hide()
				elseif precedente then
					ligne:SetPoint("TOPLEFT", precedente, "BOTTOMLEFT", 0, 0)
				else
					ligne:SetPoint("TOPLEFT", hote, "TOPLEFT", LISTE_X, LISTE_Y)
				end
				if index <= place then
					precedente = ligne
				end
			end
		end

		-- LES DEUX TRAITS, en haut et en bas de la liste.
		local premiere = _G["ReputationBar1"]
		if premiere then
			local haut = cadre:CreateTexture(nil, "ARTWORK")
			ForeverUI.SetAtlas(haut, ATLAS_TRAIT, true)
			haut:SetPoint("CENTER", premiere, "TOP", 0, 0)

			local bas = cadre:CreateTexture(nil, "ARTWORK")
			ForeverUI.SetAtlas(bas, ATLAS_TRAIT, true)
			bas:SetPoint("CENTER", hote, "BOTTOMLEFT",
				LISTE_X + largeur / 2, LISTE_Y2)
		end
	end

	return nil, { cadre }
end

ForeverUI.ReputationTab = { Build = monter }

-- LE CLIENT REMPLIT, NOUS TEIGNONS. ReputationFrame_Update pose les valeurs
-- et les intitules ; notre passage vient apres, sur le meme evenement.
if hooksecurefunc and type(_G["ReputationFrame_Update"]) == "function" then
	hooksecurefunc("ReputationFrame_Update", function()
		retenirAttitudes()
		majRemplissages()
	end)
end
