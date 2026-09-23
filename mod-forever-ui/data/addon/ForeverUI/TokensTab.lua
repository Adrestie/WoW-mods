-- ForeverUI : l'onglet des monnaies.
--
-- RELEVE -- camelot/blizzard_tokenui.xml et .lua, lus en entier, plus le
-- Blizzard_TokenUI du client 3.3.5, lu dans l'archive.
--
-- TokenFrame
--   ScrollBox     TOPLEFT sur CharacterFrameLeftPaneHost (10, -40),
--                 BOTTOMRIGHT (-25, 15) -- les memes bornes que la
--                 reputation et les competences, au pixel pres
--   deux traits   UI-Character-Info-ScrollLine-Long, centres sur le TOP et
--                 le BOTTOM du ScrollBox
--   ScrollBar     MinimalScrollBar, a droite
--
-- TokenHeaderTemplate, 26 de haut
--   fond          common-button-list-collapseExpand, a sa taille d'atlas
--   survol        le meme, ADD, alpha 0,3
--   StateIcon     RIGHT (-8, -1)
--   Name          GameFontNormalLeft, LEFT (10), hauteur 15
--
-- TokenEntryTemplate, 22 de haut
--   BackgroundHighlight  trois tranches, cotes larges de 6 :
--                 charactercreate-customize-dropdown-linemouseover-side --
--                 le droit retourne -- et -middle entre les deux. Choisie
--                 0,20 ; au survol 0,10 ; au repos 0.
--   CurrencyIcon  20 x 20, RIGHT (-20, 0)
--   Count         GameFontHighlightRight, LEFT de l'icone (-5, 0)
--   Name          GameFontHighlightLeft, hauteur 11, du LEFT au Count (-10)
--   WatchedCurrencyCheck  Interface/Buttons/UI-CheckBox-Check, 16 x 16,
--                 RIGHT (-3, 0)
--
-- TokenDetailFrame, CharacterFrameSidePaneTemplate
--   titre         le nom de la monnaie
--   sous-titre    son icone et sa quantite
--   description   GetCurrencyDescriptionText
--   deux cases    InactiveCheckbox (UNUSED) et BackpackCheckbox
--                 (SHOW_ON_BACKPACK), 26 x 26, checkbox-minimal et
--                 checkmark-minimal
--
-- CE QUE 3.3.5 DONNE, ET CE QU'IL NE DONNE PAS.
--
-- GetCurrencyListSize et GetCurrencyListInfo sont dans le binaire, verifie,
-- et le client s'en sert lui-meme. GetCurrencyListInfo rend NEUF valeurs :
--   nom, enTete, deplie, inutilisee, suivie, compte, typeSpecial, icone,
--   identifiantObjet
--
-- CE QUI DIFFERE, ET POURQUOI.
--
--   * PAS DE SOUS-EN-TETE. camelot a un TokenSubHeaderTemplate ; la liste de
--     3.3.5 n'a que deux niveaux -- GetCurrencyListInfo ne rend qu'un
--     enTete, sans notion d'enfant. Il n'y a donc rien a poser.
--   * PAS DE DESCRIPTION. camelot la tire de GetCurrencyDescriptionText, qui
--     n'existe pas ici, et GetCurrencyListInfo n'en porte aucune. Le volet
--     droit montre le nom, l'icone et la quantite ; la place de la
--     description reste vide. C'est un manque, signale.
--   * PAS DE PLAFOND NI DE QUOTA HEBDOMADAIRE, pour la meme raison.
--   * DEUX MONNAIES ONT UNE ICONE A PART, et le client le dit lui-meme :
--     typeSpecial 1, les points d'arene -- Interface/PVPFrame/
--     PVP-ArenaPoints-Icon ; typeSpecial 2, les points d'honneur --
--     Interface/TargetingFrame/UI-PVP-<faction>, rogne a 0,03125 ..
--     0,59375. Releve dans TokenFrame_Update.
--   * UNE MONNAIE A ZERO S'ECRIT EN GRIS. GameFontDisable, comme le client.
--   * PAS DE BARRE DE DEFILEMENT, comme la reputation et les competences :
--     la molette suffit d'ici la.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local LISTE_X, LISTE_Y = 10, -40
local LISTE_X2, LISTE_Y2 = -25, 15

local ENTREE_H = 22                     -- TokenEntryTemplate
local ENTETE_H = 26                     -- TokenHeaderTemplate
local MARGE = 10
local ECART = 3
local RETRAIT_ENTETE = 0
local RETRAIT_AUTRE = 2

local NOM_H = 11
local ENTETE_NOM_H = 15
local ENTETE_NOM_X = 10
local NOM_X = 2
local NOM_ECART = -10                   -- du LEFT du compte
local ICONE = 20
local ICONE_X = -20
local COMPTE_X = -5
local COCHE_L = 16
local COCHE_X = -3
local FLECHE_X, FLECHE_Y = -8, -1
local FLECHE_PLACE = 16
local COTE = 6                          -- les tranches du survol
local PLAQUE_COIN = 12                  -- le meme que la reputation

local CHOISIE_ALPHA = 0.20
local SURVOL_ALPHA = 0.10

local ATLAS_ENTETE = "common-button-list-collapseexpand"
local ATLAS_PLUS = "common-button-list-plus"
local ATLAS_MOINS = "common-button-list-minus"
local ATLAS_TRAIT = "ui-character-info-scrollline-long"
local ATLAS_SURVOL_COTE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_SURVOL_MILIEU = "charactercreate-customize-dropdown-linemouseover-middle"

local CHEMIN_COCHE = "Interface\\Buttons\\UI-CheckBox-Check"
local CHEMIN_ARENE = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
local CHEMIN_HONNEUR = "Interface\\TargetingFrame\\UI-PVP-%s"
local HONNEUR_COIN = 0.03125
local HONNEUR_COTE = 0.59375

-- La taille du volet, par construction : un contenu se batit a sa premiere
-- ouverture, qui peut preceder la pose de la fenetre. GetHeight rendrait
-- alors zero. Le meme garde-fou que la reputation.
local VOLET_L, VOLET_H = 398, 464

local lignes = {}
local panneau, decalage = nil, 0
local visibles = 0
local choisie

-- DECLAREES AVANT D'ETRE ECRITES. poserListe borne l'ecran a chaque passage
-- et il est ecrit plus haut qu'elles : sans ces deux lignes leurs noms s'y
-- resoudraient en GLOBALES, donc nil.
local hoteGauche
local bornerAuVolet

-- ---------------------------------------------------------------- les donnees

local function lireDevise(rang)
	if not GetCurrencyListInfo then
		return nil
	end
	local nom, enTete, deplie, inutilisee, suivie, compte, special, icone,
		objet = GetCurrencyListInfo(rang)
	if not nom or nom == "" then
		return nil
	end
	return {
		index = rang,
		nom = nom,
		entete = enTete and true or false,
		deplie = deplie and true or false,
		inutilisee = inutilisee and true or false,
		suivie = suivie and true or false,
		compte = compte or 0,
		special = special,
		icone = icone,
		objet = objet,
	}
end

-- L'ICONE D'UNE MONNAIE. Deux types ont la leur, en dur dans le client.
local function poserIcone(texture, donnees)
	if donnees.special == 1 then
		texture:SetTexture(CHEMIN_ARENE)
		texture:SetTexCoord(0, 1, 0, 1)
	elseif donnees.special == 2 then
		local faction = UnitFactionGroup and UnitFactionGroup("player")
		if faction then
			texture:SetTexture(string.format(CHEMIN_HONNEUR, faction))
			texture:SetTexCoord(HONNEUR_COIN, HONNEUR_COTE, HONNEUR_COIN, HONNEUR_COTE)
		else
			texture:SetTexture("")
			texture:SetTexCoord(0, 1, 0, 1)
		end
	else
		texture:SetTexture(donnees.icone or "")
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

local function hauteurDe(donnees)
	return donnees.entete and ENTETE_H or ENTREE_H
end

local function retraitDe(donnees)
	return donnees.entete and RETRAIT_ENTETE or RETRAIT_AUTRE
end

-- ----------------------------------------------------------------- une ligne

local function creerLigne(index, largeur)
	local ligne = CreateFrame("Button", "ForeverUITokenRow" .. index, panneau)
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

	-- LA COCHE d'une monnaie suivie, tout a droite.
	local coche = ligne:CreateTexture(nil, "OVERLAY")
	coche:SetTexture(CHEMIN_COCHE)
	coche:SetWidth(COCHE_L)
	coche:SetHeight(COCHE_L)
	coche:SetPoint("RIGHT", ligne, "RIGHT", COCHE_X, 0)
	coche:Hide()
	ligne.coche = coche

	local icone = ligne:CreateTexture(nil, "BORDER")
	icone:SetWidth(ICONE)
	icone:SetHeight(ICONE)
	icone:SetPoint("RIGHT", ligne, "RIGHT", ICONE_X, 0)
	ligne.icone = icone

	local compte = ligne:CreateFontString(nil, "ARTWORK", "GameFontHighlightRight")
	compte:SetJustifyH("RIGHT")
	compte:SetPoint("RIGHT", icone, "LEFT", COMPTE_X, 0)
	ligne.compte = compte

	-- LE NOM. Ses deux ancrages changent selon le gabarit : ils se reposent
	-- a chaque remplissage.
	local nom = ligne:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
	nom:SetJustifyH("LEFT")
	ligne.nom = nom

	-- LA FLECHE d'un en-tete, a droite : StateIcon.
	local fleche = ligne:CreateTexture(nil, "OVERLAY")
	fleche:SetPoint("RIGHT", ligne, "RIGHT", FLECHE_X, FLECHE_Y)
	fleche:Hide()
	ligne.fleche = fleche

	ligne:RegisterForClicks("LeftButtonUp")
	return ligne
end

-- -------------------------------------------------------------- l'affichage

-- L'OPACITE DU SURVOL, telle que les KeyValues du gabarit la donnent :
-- choisie 0,20 ; au survol 0,10 ; au repos 0.
local function poserSurvol(ligne)
	if ligne.entete then
		ligne.survol:SetAlpha(0)
		return
	end
	local dessus = ligne:IsMouseOver()
	ligne.survol:SetAlpha((ligne.choisie and CHOISIE_ALPHA)
		or (dessus and SURVOL_ALPHA) or 0)
end

local function remplirLigne(ligne, donnees)
	ligne.deviseIndex = donnees.index
	ligne.deviseNom = donnees.nom
	ligne.entete = donnees.entete
	ligne.deplie = donnees.deplie
	ligne.suivie = donnees.suivie
	ligne.choisie = (not donnees.entete) and (choisie == donnees.nom) or false

	ligne:SetHeight(hauteurDe(donnees))

	ligne.nom:ClearAllPoints()
	if donnees.entete then
		for _, tranche in ipairs(ligne.plaque) do
			tranche:Show()
		end
		ligne.icone:Hide()
		ligne.compte:SetText("")
		ligne.coche:Hide()

		ligne.nom:SetHeight(ENTETE_NOM_H)
		ligne.nom:SetFontObject(GameFontNormalLeft or "GameFontNormal")
		ligne.nom:SetPoint("LEFT", ligne, "LEFT", ENTETE_NOM_X, 0)
		ligne.nom:SetPoint("RIGHT", ligne, "RIGHT", -FLECHE_PLACE, 0)
		ligne.nom:SetText(donnees.nom)

		ForeverUI.SetAtlas(ligne.fleche,
			donnees.deplie and ATLAS_MOINS or ATLAS_PLUS, false)
		ligne.fleche:Show()
	else
		for _, tranche in ipairs(ligne.plaque) do
			tranche:Hide()
		end
		ligne.fleche:Hide()

		poserIcone(ligne.icone, donnees)
		ligne.icone:Show()
		ligne.compte:SetText(donnees.compte)

		-- UNE MONNAIE A ZERO S'ECRIT EN GRIS : c'est ce que fait le client.
		local police = (donnees.compte == 0) and (GameFontDisable or "GameFontDisable")
			or (GameFontHighlight or "GameFontHighlight")
		ligne.compte:SetFontObject(police)
		ligne.nom:SetFontObject(police)

		if donnees.suivie then
			ligne.coche:Show()
		else
			ligne.coche:Hide()
		end

		ligne.nom:SetHeight(NOM_H)
		ligne.nom:SetPoint("LEFT", ligne, "LEFT", NOM_X, 0)
		ligne.nom:SetPoint("RIGHT", ligne.compte, "LEFT", NOM_ECART, 0)
		ligne.nom:SetText(donnees.nom)
	end

	poserSurvol(ligne)
	ligne:Show()
end

-- LE BALAYAGE. L'art et les lignes de 3.3.5 s'en vont, a CHAQUE passage :
-- TokenFrame_Update les repose des qu'une monnaie bouge. On balaie les
-- regions ET les enfants, sauf notre panneau.
local function etoufferEcranDuClient()
	local cadre = _G["TokenFrame"]
	if not cadre then
		return
	end

	if cadre.SetBackdrop then
		cadre:SetBackdrop(nil)
	end
	for _, region in ipairs({ cadre:GetRegions() }) do
		if region.Hide then
			region:Hide()
		end
	end
	if cadre.GetChildren then
		for _, fils in ipairs({ cadre:GetChildren() }) do
			if fils ~= panneau and fils.Hide then
				fils:Hide()
			end
		end
	end
end

-- UN PASSAGE : empiler les lignes depuis le decalage, jusqu'a la marge du
-- bas. ON S'ARRETE A GetCurrencyListSize, comme le client.
local function disposer()
	local total = (GetCurrencyListSize and GetCurrencyListSize()) or 0
	local hauteurUtile = (panneau:GetHeight() or 0)
	if hauteurUtile < 50 then
		hauteurUtile = VOLET_H + LISTE_Y - LISTE_Y2
	end
	local largeurUtile = (panneau:GetWidth() or 0)
	if largeurUtile < 50 then
		largeurUtile = VOLET_L + LISTE_X2 - LISTE_X
	end

	local y = MARGE
	local posees = 0
	for rang, ligne in ipairs(lignes) do
		local index = decalage + rang
		local donnees = (index <= total) and lireDevise(index) or nil
		local hauteur = donnees and hauteurDe(donnees) or 0
		if donnees and y + hauteur <= hauteurUtile - MARGE then
			local retrait = retraitDe(donnees)
			ligne:SetWidth(largeurUtile - 2 * MARGE - retrait)
			remplirLigne(ligne, donnees)
			ligne:ClearAllPoints()
			ligne:SetPoint("TOPLEFT", panneau, "TOPLEFT", MARGE + retrait, -y)
			y = y + hauteur + ECART
			posees = posees + 1
		else
			ligne:Hide()
		end
	end
	return posees
end

local function poserListe()
	if not panneau then
		return
	end

	bornerAuVolet()
	etoufferEcranDuClient()

	local total = (GetCurrencyListSize and GetCurrencyListSize()) or 0
	local posees = disposer()

	-- Replier une categorie raccourcit la liste : on borne le decalage et on
	-- repose si cela a bouge. Le meme piege que la reputation.
	if decalage > 0 and decalage + posees > total then
		decalage = math.max(0, total - posees)
		posees = disposer()
	end

	visibles = posees

	if ForeverUI.TokensDetail then
		ForeverUI.TokensDetail()
	end
end
ForeverUI.TokensLayout = poserListe

-- ---------------------------------------------------------- la construction

local function suivreSurvol()
	for _, ligne in ipairs(lignes) do
		if ligne:IsShown() and not ligne.entete then
			poserSurvol(ligne)
		end
	end
end

-- L'ECRAN DES MONNAIES CESSE D'ETRE UN PANNEAU.
--
-- Releve a la PREMIERE ligne du Blizzard_TokenUI du client :
--   UIPanelWindows["TokenFrame"] = { area = "left", pushable = 1,
--                                    whileDead = 1 }
--
-- Il est donc inscrit au systeme de panneaux, comme la fenetre PvP. Tant
-- qu'il y est, UpdateUIPanelPositions lui rend ses ancres a l'ecran des
-- qu'il repasse, et il redevient une dalle posee sur UIParent : son art
-- etant eteint, elle ne se voit pas, mais elle prend la souris. C'est ce
-- qui rendait les onglets lateraux incliquables depuis le PvP ; le meme
-- geste vaut ici, avant que le defaut ne se montre.
bornerAuVolet = function()
	local cadre = _G["TokenFrame"]
	if not cadre or not hoteGauche then
		return
	end
	cadre:ClearAllPoints()
	cadre:SetPoint("TOPLEFT", hoteGauche, "TOPLEFT", 0, 0)
	cadre:SetPoint("BOTTOMRIGHT", hoteGauche, "BOTTOMRIGHT", 0, 0)
end

local function monter(hote)
	local cadre = _G["TokenFrame"]
	if not cadre or not hote then
		return nil, {}
	end

	hoteGauche = hote
	if UIPanelWindows then
		UIPanelWindows["TokenFrame"] = nil
	end
	bornerAuVolet()

	if panneau then
		return nil, { cadre }
	end

	if cadre.SetBackdrop then
		cadre:SetBackdrop(nil)
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

	panneau = CreateFrame("Frame", "ForeverUITokenList", cadre)
	panneau:SetPoint("TOPLEFT", hote, "TOPLEFT", LISTE_X, LISTE_Y)
	panneau:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", LISTE_X2, LISTE_Y2)
	panneau:SetWidth(largeur)

	-- Assez de lignes pour le cas le plus dense -- que des entrees, les plus
	-- courtes -- puisque poserListe s'arrete a la marge du bas.
	local place = math.floor((hauteur + LISTE_Y - LISTE_Y2) / (ENTREE_H + ECART))
	if place < 1 then
		place = 1
	end
	for index = 1, place do
		local ligne = creerLigne(index, largeur)
		ligne:SetScript("OnClick", function(self)
			if not self.deviseIndex then
				return
			end
			if self.entete then
				if ExpandCurrencyList then
					ExpandCurrencyList(self.deviseIndex, self.deplie and 0 or 1)
				end
				poserListe()
			else
				ForeverUI.TokensSelect(self.deviseNom)
			end
		end)
		lignes[index] = ligne
	end

	-- LES DEUX TRAITS VIVENT SUR NOTRE PANNEAU : le cadre du client voit
	-- toutes ses regions masquees a chaque passage, et les notres y
	-- disparaitraient avec.
	local haut = panneau:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(haut, ATLAS_TRAIT)
	haut:SetPoint("CENTER", panneau, "TOP", 0, 0)

	local bas = panneau:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(bas, ATLAS_TRAIT)
	bas:SetPoint("CENTER", panneau, "BOTTOM", 0, 0)

	panneau:SetScript("OnUpdate", suivreSurvol)
	panneau:EnableMouseWheel(true)
	panneau:SetScript("OnMouseWheel", function(_self, sens)
		local total = (GetCurrencyListSize and GetCurrencyListSize()) or 0
		decalage = math.max(0, math.min(decalage - sens, total - visibles))
		poserListe()
	end)

	poserListe()
	return nil, { cadre }
end

-- ------------------------------------------------------------ le volet droit

local VOLET_DROIT_X, VOLET_DROIT_Y = 16, -14
local VOLET_DROIT_X2, VOLET_DROIT_Y2 = -12, 14
local TITRE_L = 195
local SOUS_TITRE_Y = -3
local SEPARATEUR_Y = -4
local DETAIL_ICONE = 16
local DETAIL_ICONE_X = -4
local CASE = 26
local CASE_X, CASE_ECART = -4, -2
local CASE_INTITULE_L = 158
local CASE_INTITULE_X = 2

local ATLAS_CASE = "checkbox-minimal"
local ATLAS_COCHE = "checkmark-minimal"
local ATLAS_SEPARATEUR = "ui-character-info-scrollline"

local detail

-- LES DEUX CASES DU CLIENT, reposees et rhabillees. Leur logique reste la
-- leur : elles appellent SetCurrencyUnused et SetCurrencyBackpack sur
-- TokenFrame.selectedID, qu'on tient a jour.
local CASES = {
	{ nom = "TokenFramePopupInactiveCheckBox" },
	{ nom = "TokenFramePopupBackpackCheckBox" },
}

local function habillerCase(case)
	if not case or case.foreverHabillee then
		return
	end

	case:SetWidth(CASE)
	case:SetHeight(CASE)

	for _, methode in ipairs({ "GetNormalTexture", "GetPushedTexture",
		"GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
		local texture = case[methode] and case[methode](case)
		if texture then
			texture:SetAlpha(0)
		end
	end

	local fond = case:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, ATLAS_CASE)
	fond:SetPoint("CENTER", case, "CENTER", 0, 0)

	local coche = case:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(coche, ATLAS_COCHE)
	coche:SetPoint("CENTER", case, "CENTER", 0, 0)
	case.foreverCoche = coche

	local intitule = _G[case:GetName() .. "Text"]
	if intitule then
		intitule:ClearAllPoints()
		intitule:SetPoint("LEFT", case, "RIGHT", CASE_INTITULE_X, 0)
		intitule:SetWidth(CASE_INTITULE_L)
		intitule:SetJustifyH("LEFT")
		if GameFontNormal then
			intitule:SetFontObject(GameFontNormal)
		end
	end

	case.foreverHabillee = true
end

local function suivreCases()
	for _, decrit in ipairs(CASES) do
		local case = _G[decrit.nom]
		if case and case.foreverCoche then
			if case:GetChecked() then
				case.foreverCoche:Show()
			else
				case.foreverCoche:Hide()
			end
		end
	end
end

local function montrerCases(etat)
	for _, decrit in ipairs(CASES) do
		local case = _G[decrit.nom]
		if case then
			if etat then case:Show() else case:Hide() end
		end
	end
end

-- LE DETAIL SUIT LE NOM, PAS L'INDICE.
--
-- Ranger une monnaie parmi les inutilisees, ou replier sa categorie, change
-- toute la numerotation : l'indice retenu designerait une autre ligne. Le
-- nom, lui, ne bouge pas. C'est la meme lecon que la reputation, et le
-- client la suit deja -- TokenFrame.selectedToken porte un NOM.
local function indiceDe(nom)
	if not nom then
		return nil
	end
	for rang = 1, (GetCurrencyListSize and GetCurrencyListSize()) or 0 do
		local devise = lireDevise(rang)
		if devise and devise.nom == nom and not devise.entete then
			return rang
		end
	end
	return nil
end

local function viderDetail()
	detail.titre:SetText("")
	detail.sousTitre:SetText("")
	detail.icone:Hide()
	detail.separateur:Hide()
	montrerCases(false)
end

local function majDetail()
	if not detail then
		return
	end

	if not choisie then
		viderDetail()
		return
	end

	local index = indiceDe(choisie)
	if not index then
		-- La monnaie a quitte la liste : sa categorie s'est repliee, ou elle
		-- est passee parmi les inutilisees. C'est ce que fait
		-- TokenFramePopup_CloseIfHidden : on ne montre plus rien.
		choisie = nil
		viderDetail()
		return
	end

	local donnees = lireDevise(index)
	if not donnees then
		viderDetail()
		return
	end

	-- Le client agit sur SON indice : on le tient a jour, sinon ses deux
	-- cases porteraient sur une autre monnaie.
	local jeton = _G["TokenFrame"]
	if jeton then
		jeton.selectedToken = donnees.nom
		jeton.selectedID = index
	end

	detail.titre:SetText(donnees.nom)
	detail.sousTitre:SetText(tostring(donnees.compte))
	poserIcone(detail.icone, donnees)
	detail.icone:Show()
	detail.separateur:Show()

	montrerCases(true)
	for _, decrit in ipairs(CASES) do
		local case = _G[decrit.nom]
		if case and case.SetChecked then
			if decrit.nom == "TokenFramePopupInactiveCheckBox" then
				case:SetChecked(donnees.inutilisee)
			else
				case:SetChecked(donnees.suivie)
			end
		end
	end
	suivreCases()
end
ForeverUI.TokensDetail = majDetail

local function choisir(nom)
	choisie = nom
	poserListe()
end
ForeverUI.TokensSelect = choisir

local function monterDetail(hote)
	if detail then
		return detail, {}
	end

	local cadre = _G["TokenFramePopup"]
	if not cadre or not hote then
		return nil, {}
	end

	cadre:SetParent(hote)
	if cadre.SetToplevel then
		cadre:SetToplevel(false)
	end
	cadre:ClearAllPoints()
	cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", VOLET_DROIT_X, VOLET_DROIT_Y)
	cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", VOLET_DROIT_X2, VOLET_DROIT_Y2)
	-- Le fond de fenetre n'est pas une region : SetBackdrop(nil) seul
	-- l'enleve. Le meme piege que ReputationDetailFrame.
	if cadre.SetBackdrop then
		cadre:SetBackdrop(nil)
	end

	-- L'INTITULE DU CLIENT S'EN VA AUSSI, ET CE N'EST PAS UNE TEXTURE.
	--
	-- TokenFramePopup porte un FontString, $parentTitle -- TOKEN_OPTIONS,
	-- "Currency Options" -- ancre au TOPLEFT du popup (25, -17). Le
	-- balayage ne prenait que les TEXTURES : cet intitule restait donc a
	-- l'ecran, a une place qui n'a plus de sens une fois le cadre etale sur
	-- le volet. Notre titre porte le nom de la monnaie, il n'a pas de
	-- second intitule a cote.
	--
	-- On balaie les deux natures de region. Les notres sont creees APRES :
	-- elles ne sont pas concernees.
	for _, region in ipairs({ cadre:GetRegions() }) do
		local nature = region.GetObjectType and region:GetObjectType()
		if nature == "Texture" then
			region:SetAlpha(0)
		elseif nature == "FontString" and region.Hide then
			region:Hide()
		end
	end
	local fermer = _G["TokenFramePopupCloseButton"]
	if fermer then
		fermer:Hide()
	end

	detail = cadre

	-- ECART ASSUME : camelot ecrit le titre en GameFontNormalMed3, que 3.3.5
	-- n'a pas. GameFontNormalLarge est le plus proche qu'il porte.
	detail.titre = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	detail.titre:SetWidth(TITRE_L)
	detail.titre:SetJustifyH("CENTER")
	detail.titre:SetPoint("TOP", cadre, "TOP", 0, 0)

	detail.sousTitre = cadre:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	detail.sousTitre:SetJustifyH("LEFT")
	detail.sousTitre:SetPoint("TOP", detail.titre, "BOTTOM", 0, SOUS_TITRE_Y)

	-- L'ICONE de la monnaie, a gauche de sa quantite : c'est ce que camelot
	-- met dans son sous-titre, par un marqueur de texture.
	detail.icone = cadre:CreateTexture(nil, "ARTWORK")
	detail.icone:SetWidth(DETAIL_ICONE)
	detail.icone:SetHeight(DETAIL_ICONE)
	detail.icone:SetPoint("RIGHT", detail.sousTitre, "LEFT", DETAIL_ICONE_X, 0)
	detail.icone:Hide()

	detail.separateur = cadre:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(detail.separateur, ATLAS_SEPARATEUR)
	detail.separateur:SetPoint("TOP", detail.sousTitre, "BOTTOM", 0, SEPARATEUR_Y)

	-- LE PIED : les deux cases, empilees depuis le bas du volet.
	local precedente
	for _, decrit in ipairs(CASES) do
		local case = _G[decrit.nom]
		if case then
			habillerCase(case)
			case:SetParent(cadre)
			case:ClearAllPoints()
			if precedente then
				case:SetPoint("TOPLEFT", precedente, "BOTTOMLEFT", 0, CASE_ECART)
			else
				local pied = 2 * CASE + (-CASE_ECART)
				case:SetPoint("TOPLEFT", cadre, "BOTTOMLEFT", CASE_X, pied)
			end
			precedente = case
		end
	end

	majDetail()
	return cadre, {}
end

ForeverUI.TokensTab = { Build = monter, BuildRight = monterDetail }

-- Le client refait son ecran dans TokenFrame_Update : on passe apres.
if hooksecurefunc and type(_G["TokenFrame_Update"]) == "function" then
	hooksecurefunc("TokenFrame_Update", function()
		poserListe()
	end)
end

-- TEMOIN -- /fui monnaie. Ce que le client rend pour chaque ligne visible,
-- et ce qu'on en fait.
function ForeverUI.TokensDebug()
	local dire = function(texte)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
	end

	local total = (GetCurrencyListSize and GetCurrencyListSize()) or 0
	dire(string.format("monnaies : %d dans la liste, decalage %d, %d posee(s),"
		.. " choisie=%s", total, decalage, visibles, tostring(choisie)))

	for rang = 1, math.min(total, 12) do
		local devise = lireDevise(rang)
		if devise then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"   %2d %-28s %s compte=%-8s special=%-4s suivie=%-5s inutilisee=%s",
				rang, devise.nom,
				devise.entete and (devise.deplie and "[-]" or "[+]") or "   ",
				tostring(devise.compte), tostring(devise.special),
				tostring(devise.suivie), tostring(devise.inutilisee)))
		end
	end

	local jeton = _G["TokenFrame"]
	dire(string.format("client : selectedToken=%s selectedID=%s | ecran=%s",
		tostring(jeton and jeton.selectedToken),
		tostring(jeton and jeton.selectedID),
		tostring(jeton and jeton:IsShown())))
end
