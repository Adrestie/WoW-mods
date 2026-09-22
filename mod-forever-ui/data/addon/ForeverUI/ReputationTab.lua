-- ForeverUI : l'onglet de reputation.
--
-- POURQUOI NOS PROPRES LIGNES, ET NON CELLES DU CLIENT.
--
-- Premiere tentative : reposer et rhabiller les quinze ReputationBar<i> de
-- 3.3.5. Elle a echoue trois fois de suite, toujours de la meme facon --
-- ReputationFrame_Update ne se contente pas de remplir, il REPOSE son art a
-- chaque passage : SetNormalTexture sur les boutons, les AtWarHighlight
-- additifs, les traits d'arborescence, la texture de la StatusBar. Chaque
-- correction tenait jusqu'au passage suivant, et le clic en declenchait un.
--
-- Les lignes sont donc les NOTRES, baties d'apres les gabarits de camelot et
-- remplies depuis GetFactionInfo -- la seule chose que 3.3.5 apporte ici, et
-- la seule dont on ait besoin. Le ReputationFrame du client ne sert plus que
-- de support ; ses lignes sont retirees.
--
-- RELEVE -- camelot/ReputationFrame.xml et reputationframe.lua.
--
-- La liste, dans le volet gauche :
--   TOPLEFT sur CharacterFrameLeftPaneHost (10, -40)
--   BOTTOMRIGHT sur le meme (-25, 15)
--   deux traits UI-Character-Info-ScrollLine-Long, centres sur son TOP et
--   sur son BOTTOM
--
-- ReputationHeaderTemplate, hauteur 28 :
--   fond        common-button-list-collapseExpand, sans ancrage donc etire
--               sur toute la ligne
--   StateIcon   common-button-list-plus ou -minus, RIGHT (-8, -1)
--   nom         GameFontNormalLeft -- en or -- hauteur 15, LEFT x = 10
--
-- ReputationEntryTemplate, hauteur 30 :
--   barre               ReputationBarTemplate, RIGHT x = -3
--   AccountWideIcon     23 x 22, LEFT x = 2. Elle n'existe pas en 3.3.5,
--                       mais c'est son bord droit -- x = 25 -- qui donne
--                       l'origine du nom.
--   nom                 GameFontHighlight -- en blanc -- hauteur 15, aligne
--                       a gauche, de x = 25 au LEFT de la barre moins 10
--   BackgroundHighlight trois tranches, cotes larges de 6 :
--                       charactercreate-customize-dropdown-linemouseover-side
--                       -- le droit retourne -- et -middle entre les deux.
--                       RefreshBackgroundHighlightOpacity donne les alphas :
--                       au repos 0 ; au survol 0,10 ; choisie 0,20. En
--                       guerre 0,50 / 0,65 / 0,85, et teinte par
--                       FACTION_AT_WAR_COLOR.
--
-- ReputationBarTemplate, 160 x 29, herite de ColoredProgressBarTemplate :
--   fond          common-stat-bar-bg, sans ancrage donc etire sur la barre
--   remplissage   common-stat-bar-white, hauteur 15, ancre LEFT. SetFillPercent
--                 pose largeur = fraction x largeur de barre et rogne la
--                 texture d'autant. UpdateBarColor la TEINTE avec
--                 FACTION_BAR_COLORS[attitude].
--   texte         GameFontHighlight, LEFT et RIGHT sur la barre, donc centre.
--                 L'intitule d'attitude au repos ; au survol la progression,
--                 par TryShowBarProgressText.
--
-- InitializeBarForStandardReputation : a l'attitude maximale la barre est
-- pleine et n'a pas de texte de progression ; sinon la valeur se normalise
-- entre le seuil courant et le suivant.
--
-- CE QUI DIFFERE, ET POURQUOI :
--   * 3.3.5 n'a pas de MaskTexture : les bouts du remplissage restent carres.
--   * Ni AccountWideIcon, ni Paragon, ni amitie : ces notions n'existent pas
--     dans ce client. Seul le retrait qu'imposait la premiere est garde.
--   * La barre de defilement reste a faire ; la molette suffit d'ici la.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local LISTE_X, LISTE_Y = 10, -40
local LISTE_X2, LISTE_Y2 = -25, 15

local ENTREE_H = 30                     -- ReputationEntryTemplate
local ENTETE_H = 28                     -- ReputationHeaderTemplate
local BARRE_L, BARRE_H = 160, 29
local BARRE_X = -3                      -- RIGHT de la ligne
local REMPLISSAGE_H = 15
local NOM_H = 15
local NOM_X = 25                        -- le bord droit de l'AccountWideIcon
local NOM_ECART = -10                   -- du LEFT de la barre
local ENTETE_NOM_X = 10
local FLECHE_X, FLECHE_Y = -8, -1
local FLECHE_PLACE = 16                 -- ce que le nom lui laisse
local COTE = 6                          -- les tranches du survol

-- LA PLAQUE D'EN-TETE SE DECOUPE, ELLE NE S'ETIRE PAS.
--
-- Elle mesure 64 x 29 et la ligne en fait plus de trois cents : etiree telle
-- quelle, ses coins arrondis s'etalaient en ellipses. Mesure sur l'art --
-- alpha de la colonne de gauche -- l'arrondi court sur une dizaine de
-- pixels ; un coin de 12 le couvre, et reste sous la moitie de la hauteur,
-- au-dela de quoi les tranches se chevaucheraient.
local PLAQUE_COIN = 12

-- LE FOND DE JAUGE SE DECOUPE AUSSI.
--
-- common-stat-bar-bg mesure 68 x 30 et la barre en fait 160 : etire, ses
-- bouts arrondis s'allongeaient. Mesure sur l'art -- on cherche la premiere
-- colonne dont le profil vertical rejoint celui du milieu, c'est-a-dire ou
-- le bord est fini : elle tombe a 10. La hauteur ne changeant pas, seules
-- les tranches horizontales du milieu s'etirent.
--
-- LE REMPLISSAGE, LUI, NE SE DECOUPE PAS : c'est une jauge. camelot le
-- rogne a la fraction voulue -- SetFillPercent pose largeur = fraction x
-- largeur de barre et SetTexCoord(0, fraction, ...) -- et la meme
-- compression horizontale s'y applique, sa feuille faisant 240 pour une
-- barre de 160. Le decouper en ferait un cadre, pas une jauge.
local JAUGE_COIN = 10

local ATLAS_BARRE_FOND = "common-stat-bar-bg"
-- LE REMPLISSAGE EST CUIT, PAS PRIS DANS SA FEUILLE.
--
-- camelot le decoupe par common-stat-bar-Mask, une MaskTexture que 3.3.5 n'a
-- pas : sans elle, le remplissage avait des bouts carres qui ne suivaient pas
-- le contour du fond. tools/cuire_masque.py multiplie donc l'alpha du masque
-- dans celui du remplissage, une fois pour toutes -- et il le DECOUPE comme
-- notre fond, bouts de 10 px et milieu etire, pour que les deux contours se
-- superposent exactement.
--
-- Le resultat est un fichier a lui seul, calcule pour une barre de 160 : on
-- le rogne a la fraction voulue, comme SetFillPercent.
local CHEMIN_REMPLISSAGE = "Interface\\ForeverUI\\Bars\\statbarfill"
local ATLAS_ENTETE = "common-button-list-collapseexpand"
local ATLAS_PLUS = "common-button-list-plus"
local ATLAS_MOINS = "common-button-list-minus"
local ATLAS_TRAIT = "ui-character-info-scrollline-long"
local ATLAS_SURVOL_COTE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_SURVOL_MILIEU = "charactercreate-customize-dropdown-linemouseover-middle"

-- La taille du volet, par construction : un contenu se batit a sa premiere
-- ouverture, qui peut preceder la pose de la fenetre. GetHeight rendrait
-- alors zero.
local VOLET_L, VOLET_H = 398, 464

local lignes = {}
local panneau, decalage = nil, 0
local choisie

-- --------------------------------------------------------------- une ligne

local function creerLigne(index, largeur)
	local ligne = CreateFrame("Button", "ForeverUIReputationRow" .. index, panneau)
	ligne:SetWidth(largeur)
	ligne:SetHeight(ENTREE_H)

	-- LE FOND D'EN-TETE, en neuf tranches : seules celles du milieu s'etirent.
	ligne.plaque = ForeverUI.CreateNineSlice(ligne, ATLAS_ENTETE, PLAQUE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	for _, tranche in ipairs(ligne.plaque) do
		tranche:Hide()
	end

	-- LE SURVOL D'UNE ENTREE : trois tranches, les cotes larges de 6.
	local survol = CreateFrame("Frame", nil, ligne)
	survol:SetAllPoints(ligne)
	survol:SetAlpha(0)
	ligne.survol = survol

	local gauche = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(gauche, ATLAS_SURVOL_COTE, true)
	gauche:SetWidth(COTE)
	gauche:SetPoint("TOPLEFT", survol, "TOPLEFT", 0, 0)
	gauche:SetPoint("BOTTOMLEFT", survol, "BOTTOMLEFT", 0, 0)

	local droite = survol:CreateTexture(nil, "BACKGROUND")
	if ForeverUI.SetAtlas(droite, ATLAS_SURVOL_COTE, true) then
		-- La source la retourne : TexCoords left = 1, right = 0.
		local e = ForeverUI.AtlasEntry(ATLAS_SURVOL_COTE)
		droite:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	droite:SetWidth(COTE)
	droite:SetPoint("TOPRIGHT", survol, "TOPRIGHT", 0, 0)
	droite:SetPoint("BOTTOMRIGHT", survol, "BOTTOMRIGHT", 0, 0)

	local milieu = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(milieu, ATLAS_SURVOL_MILIEU, true)
	milieu:SetPoint("TOPLEFT", gauche, "TOPRIGHT", 0, 0)
	milieu:SetPoint("BOTTOMRIGHT", droite, "BOTTOMLEFT", 0, 0)

	ligne.survolPieces = { gauche, droite, milieu }

	-- LA BARRE, et ce qu'elle porte.
	local barre = CreateFrame("Frame", nil, ligne)
	barre:SetWidth(BARRE_L)
	barre:SetHeight(BARRE_H)
	barre:SetPoint("RIGHT", ligne, "RIGHT", BARRE_X, 0)
	ligne.barre = barre

	ForeverUI.CreateNineSlice(barre, ATLAS_BARRE_FOND, JAUGE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND")

	local remplissage = barre:CreateTexture(nil, "BORDER")
	remplissage:SetPoint("LEFT", barre, "LEFT", 0, 0)
	barre.remplissage = remplissage

	local texte = barre:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	texte:SetPoint("LEFT", barre, "LEFT", 0, 0)
	texte:SetPoint("RIGHT", barre, "RIGHT", 0, 0)
	texte:SetJustifyH("CENTER")
	barre.texte = texte

	-- LE NOM. Ses deux ancrages ne sont pas les memes selon le gabarit : ils
	-- se reposent donc a chaque remplissage.
	local nom = ligne:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nom:SetHeight(NOM_H)
	nom:SetJustifyH("LEFT")
	ligne.nom = nom

	-- LA FLECHE d'un en-tete.
	local fleche = ligne:CreateTexture(nil, "OVERLAY")
	fleche:SetPoint("RIGHT", ligne, "RIGHT", FLECHE_X, FLECHE_Y)
	fleche:Hide()
	ligne.fleche = fleche

	ligne:RegisterForClicks("LeftButtonUp")
	return ligne
end

-- ----------------------------------------------------------- le remplissage

local function poserBarre(ligne, donnees)
	local barre = ligne.barre
	local fraction = 0
	if donnees.maximum and donnees.maximum > 0 then
		fraction = donnees.valeur / donnees.maximum
	end
	if fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end

	-- SetFillPercent : largeur = fraction x largeur de barre, et la texture
	-- rognee d'autant. Une largeur nulle est refusee par le client.
	if fraction * BARRE_L < 1 then
		barre.remplissage:Hide()
	else
		barre.remplissage:SetTexture(CHEMIN_REMPLISSAGE)
		barre.remplissage:SetTexCoord(0, fraction, 0, 1)
		barre.remplissage:SetWidth(BARRE_L * fraction)
		barre.remplissage:SetHeight(REMPLISSAGE_H)
		barre.remplissage:Show()
	end

	local couleur = FACTION_BAR_COLORS and FACTION_BAR_COLORS[donnees.attitude]
	if couleur then
		barre.remplissage:SetVertexColor(couleur.r, couleur.g, couleur.b)
	end

	barre.texte:SetText(donnees.intitule or "")
end

-- L'OPACITE DU SURVOL, telle que RefreshBackgroundHighlightOpacity la donne.
local function poserSurvol(ligne)
	if ligne.entete then
		ligne.survol:SetAlpha(0)
		return
	end

	local dessus = ligne:IsMouseOver()
	local alpha
	if ligne.enGuerre then
		alpha = (ligne.choisie and 0.85) or (dessus and 0.65) or 0.50
	else
		alpha = (ligne.choisie and 0.20) or (dessus and 0.10) or 0
	end
	ligne.survol:SetAlpha(alpha)

	local teinte = ligne.enGuerre and FACTION_AT_WAR_COLOR
	for _, piece in ipairs(ligne.survolPieces) do
		if teinte then
			piece:SetVertexColor(teinte.r, teinte.g, teinte.b)
		else
			piece:SetVertexColor(1, 1, 1)
		end
	end
end

local function remplirLigne(ligne, donnees)
	ligne.factionIndex = donnees.index
	ligne.entete = donnees.entete
	ligne.replie = donnees.replie
	ligne.enGuerre = donnees.enGuerre
	ligne.progression = donnees.progression
	ligne.intitule = donnees.intitule
	ligne.dessusAvant = nil

	ligne.nom:SetText(donnees.nom or "")
	ligne.nom:ClearAllPoints()

	if donnees.entete then
		ligne:SetHeight(ENTETE_H)
		for _, tranche in ipairs(ligne.plaque) do
			tranche:Show()
		end
		ligne.barre:Hide()
		ligne.nom:SetFontObject(GameFontNormalLeft or GameFontNormal)
		ligne.nom:SetPoint("LEFT", ligne, "LEFT", ENTETE_NOM_X, 0)
		ligne.nom:SetPoint("RIGHT", ligne, "RIGHT", FLECHE_X - FLECHE_PLACE, 0)

		ForeverUI.SetAtlas(ligne.fleche, donnees.replie and ATLAS_PLUS or ATLAS_MOINS)
		ligne.fleche:Show()
	else
		ligne:SetHeight(ENTREE_H)
		for _, tranche in ipairs(ligne.plaque) do
			tranche:Hide()
		end
		ligne.barre:Show()
		ligne.fleche:Hide()
		ligne.nom:SetFontObject(GameFontHighlight or GameFontNormal)
		ligne.nom:SetPoint("LEFT", ligne, "LEFT", NOM_X, 0)
		ligne.nom:SetPoint("RIGHT", ligne.barre, "LEFT", NOM_ECART, 0)
		poserBarre(ligne, donnees)
	end

	ligne.choisie = (choisie ~= nil and choisie == donnees.index)
	poserSurvol(ligne)
	ligne:Show()
end

-- ------------------------------------------------------------- les donnees

-- CE QUE 3.3.5 DONNE. GetFactionInfo rend, dans l'ordre : nom, description,
-- attitude, seuil courant, seuil suivant, valeur, en guerre, peut declarer la
-- guerre, est un en-tete, est replie, a de la reputation, est surveillee,
-- est un enfant.
local function lireFaction(rang)
	local nom, _, attitude, seuil, suivant, valeur, enGuerre, _, entete,
		replie = GetFactionInfo(rang)
	if not nom then
		return nil
	end

	local maximum, courant = 1, 1
	local plein = (attitude == (MAX_REPUTATION_REACTION or 8))
	if not plein then
		maximum = (suivant or 0) - (seuil or 0)
		courant = (valeur or 0) - (seuil or 0)
	end

	local intitule = ""
	if GetText then
		intitule = GetText("FACTION_STANDING_LABEL" .. tostring(attitude),
			UnitSex and UnitSex("player")) or ""
	end

	return {
		index = rang,
		nom = nom,
		attitude = attitude,
		valeur = courant,
		maximum = maximum,
		entete = entete,
		replie = replie,
		enGuerre = enGuerre,
		intitule = intitule,
		progression = (not plein)
			and (tostring(courant) .. " / " .. tostring(maximum)) or nil,
	}
end

local function poserListe()
	if not panneau then
		return
	end

	local total = (GetNumFactions and GetNumFactions()) or 0
	local place = #lignes
	if decalage > total - place then
		decalage = math.max(0, total - place)
	end

	local precedente
	for rang, ligne in ipairs(lignes) do
		local donnees = lireFaction(decalage + rang)
		if donnees then
			remplirLigne(ligne, donnees)
			ligne:ClearAllPoints()
			if precedente then
				ligne:SetPoint("TOPLEFT", precedente, "BOTTOMLEFT", 0, 0)
			else
				ligne:SetPoint("TOPLEFT", panneau, "TOPLEFT", 0, 0)
			end
			precedente = ligne
		else
			ligne:Hide()
		end
	end
end
ForeverUI.ReputationLayout = poserListe

-- --------------------------------------------------------- la construction

local function suivreSurvol()
	for _, ligne in ipairs(lignes) do
		if ligne:IsShown() and not ligne.entete then
			poserSurvol(ligne)

			-- Au survol, la barre montre la progression ; au repos,
			-- l'attitude. C'est TryShowBarProgressText.
			local dessus = ligne:IsMouseOver()
			if dessus ~= ligne.dessusAvant then
				ligne.dessusAvant = dessus
				if dessus and ligne.progression then
					ligne.barre.texte:SetText(ligne.progression)
				else
					ligne.barre.texte:SetText(ligne.intitule or "")
				end
			end
		end
	end
end

local function monter(hote)
	local cadre = _G["ReputationFrame"]
	if not cadre or not hote then
		return nil, {}
	end

	cadre:ClearAllPoints()
	cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
	cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)

	if panneau then
		return nil, { cadre }
	end

	-- L'ART ET LES LIGNES DE 3.3.5 S'EN VONT. On ne garde du client que ce
	-- cadre, comme support, et ses fonctions de lecture.
	for _, region in ipairs({ cadre:GetRegions() }) do
		if region.Hide then
			region:Hide()
		end
	end
	for index = 1, 15 do
		local vieille = _G["ReputationBar" .. index]
		if vieille then
			vieille:Hide()
			vieille:ClearAllPoints()
		end
	end

	local hauteur = hote:GetHeight() or 0
	if hauteur < 100 then
		hauteur = VOLET_H
	end
	local largeur = hote:GetWidth() or 0
	if largeur < 100 then
		largeur = VOLET_L
	end
	largeur = largeur + LISTE_X2 - LISTE_X

	panneau = CreateFrame("Frame", "ForeverUIReputationList", cadre)
	panneau:SetPoint("TOPLEFT", hote, "TOPLEFT", LISTE_X, LISTE_Y)
	panneau:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", LISTE_X2, LISTE_Y2)
	panneau:SetWidth(largeur)

	local place = math.floor((hauteur + LISTE_Y - LISTE_Y2) / ENTREE_H)
	if place < 1 then
		place = 1
	end
	for index = 1, place do
		local ligne = creerLigne(index, largeur)
		ligne:SetScript("OnClick", function(self)
			if not self.factionIndex then
				return
			end
			if self.entete then
				if self.replie then
					ExpandFactionHeader(self.factionIndex)
				else
					CollapseFactionHeader(self.factionIndex)
				end
			else
				choisie = self.factionIndex
				poserListe()
			end
		end)
		lignes[index] = ligne
	end

	-- LES DEUX TRAITS, en haut et en bas de la liste.
	local haut = cadre:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(haut, ATLAS_TRAIT)
	haut:SetPoint("CENTER", panneau, "TOP", 0, 0)

	local bas = cadre:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(bas, ATLAS_TRAIT)
	bas:SetPoint("CENTER", panneau, "BOTTOM", 0, 0)

	panneau:SetScript("OnUpdate", suivreSurvol)
	panneau:EnableMouseWheel(true)
	panneau:SetScript("OnMouseWheel", function(self, sens)
		local total = (GetNumFactions and GetNumFactions()) or 0
		decalage = math.max(0, math.min(decalage - sens, total - #lignes))
		poserListe()
	end)

	poserListe()
	return nil, { cadre }
end

ForeverUI.ReputationTab = { Build = monter, Rows = lignes }

-- Le client annonce ses changements par UPDATE_FACTION et les traite dans
-- ReputationFrame_Update : on se greffe dessus, ses donnees etant les notres.
if hooksecurefunc and type(_G["ReputationFrame_Update"]) == "function" then
	hooksecurefunc("ReputationFrame_Update", poserListe)
end
