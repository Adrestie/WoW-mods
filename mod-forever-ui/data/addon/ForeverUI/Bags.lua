-- ForeverUI : l'interface des sacs.
--
-- RELEVE DES SOURCES -- tout vient du code extrait de camelot, qui pour les
-- sacs se sert du fichier commun (camelot/ContainerFrame.lua ne fait qu'une
-- chose : recadrer le masque rond du portrait).
--
-- mainline/ContainerFrame.xml
--   cadre           ContainerFrameTemplate herite de PortraitFrameFlatTemplate :
--                   fond plat + encadrement de metal en neuf tranches, jeu
--                   HeldBagLayout. Monte par ForeverUI.SetPanelArt.
--   emplacement     ContainerFrameItemButtonTemplate, 37 x 37, fond d'un
--                   emplacement vide = bags-item-slot64.
--   champ           BagItemSearchBox, 96 x 18, 15 lettres, TOPLEFT (42, -37)
--                   du sac principal (ContainerFrameMixin:SetSearchBoxPoint).
--   bouton de tri   BagItemAutoSortButton, 28 x 26, TOPRIGHT (-9, -34),
--                   images bags-button-autosort-up et -down, survol
--                   Interface\Buttons\ButtonHilight-Square en ADD, 24 x 23
--                   centre. Au clic : un son, puis C_Container.SortBags().
--   les deux ne se montrent QUE sur le sac principal
--                   (ContainerFrameMixin:UpdateSearchBox).
--
-- mainline/SharedUIPanelTemplates.xml
--   titre           TitleContainer de TOPLEFT (58, -1) a TOPRIGHT (-24, -1),
--                   haut de 20 ; le texte centre dedans, 5 px sous son haut.
--   portrait        62 x 62, dans l'anneau du coin haut gauche.
--
-- shared/UIPanelTemplatesShared.lua
--   BagSearch_OnTextChanged pousse le texte dans toutes les barres de
--   recherche puis appelle C_Container.SetItemSearch ; BagSearch_OnChar rend
--   la main des que les quatre derniers caracteres sont identiques ;
--   BagSearch_OnHide efface la recherche quand plus aucune barre n'est
--   visible. Ces trois comportements sont repris tels quels.
--
-- CE QUE 3.3.5 N'A PAS, ET COMMENT C'EST FAIT ICI.
--   C_Container.SetItemSearch n'existe pas : le client moderne marque
--   lui-meme chaque objet et le code ne fait que lire `isFiltered`. Ici le
--   tri des correspondances est fait en Lua, sur le nom, le type et le
--   sous-type de l'objet, et l'objet qui ne correspond pas recoit le meme
--   voile que la source (ItemButton : searchOverlay, noir a 80 %).
--   C_Container.SortBags n'existe pas non plus, et son ordre est decide dans
--   le client : il n'est pas lisible. Le rangement est donc refait ici, en
--   deplacant les objets un par un ; l'ordre suit celui que le jeu lui-meme
--   emploie pour ses categories (GetAuctionItemClasses), puis la qualite, le
--   nom et la taille de la pile. CHOIX ASSUME, faute de source.

local NB_CADRES = NUM_CONTAINER_FRAMES or 13
local SACS = { 0, 1, 2, 3, 4 }          -- sac a dos et les quatre sacs portes

local EMPLACEMENT = 37                  -- taille d'un bouton d'objet
local RECHERCHE_W, RECHERCHE_H = 96, 18
local TRI_W, TRI_H = 28, 26

-- Lua 5.1 lit les antislashs comme des echappements : on pose le separateur
-- en clair.
local SEP = string.char(92)
local SURVOL_CARRE = "Interface" .. SEP .. "Buttons" .. SEP .. "ButtonHilight-Square"

-- LA MISE EN PAGE EST REFAITE ICI.
--
-- 3.3.5 taille sa fenetre sur ses propres images de fond et colle la grille a
-- droite (premier bouton a -12 du bord). Ces images ont disparu avec
-- l'habillage : la fenetre est donc mesuree a partir de ce qu'elle contient,
-- et la grille centree.
--   entete    la bande de titre, plus la bande du champ de recherche pour le
--             sac a dos (le champ est pose de -37 a -55)
--   grille    quatre colonnes, pas de 42 x 41 pour des boutons de 37
--   bourse    sous la grille, dans la fenetre
local COLONNES = NUM_CONTAINER_COLUMNS or 4
local PAS_X, PAS_Y = 42, 41
local ENTETE_SAC_A_DOS = 60
local ENTETE_SAC = 32
local MARGE_BAS = 9

local RANGER = BAG_CLEANUP_BAGS or "Ranger les sacs"
local RANGER_AIDE = BAG_CLEANUP_BAGS_DESCRIPTION
	or "Reunit les piles et remet les objets en ordre."

ForeverUI = ForeverUI or {}

-- ------------------------------------------------------------ les cadres
local cadres = {}

local function habillerBouton(bouton)
	if not bouton or bouton.foreverSkinned then
		return
	end

	local nom = bouton:GetName()

	-- Le cadre dore de 3.3.5 laisse la place a l'emplacement moderne, qui est
	-- le fond d'une case vide chez camelot (emptyBackgroundAtlas).
	local normale = bouton:GetNormalTexture()
	if normale then
		ForeverUI.SetAtlas(normale, "bags-item-slot64", true)
		normale:ClearAllPoints()
		normale:SetAllPoints(bouton)
	end

	local survol = bouton:GetHighlightTexture()
	if survol then
		survol:SetTexture(SURVOL_CARRE)
		survol:SetBlendMode("ADD")
		survol:ClearAllPoints()
		survol:SetAllPoints(bouton)
	end

	local icone = _G[nom .. "IconTexture"]
	if icone then
		icone:ClearAllPoints()
		icone:SetAllPoints(bouton)
		icone:SetTexCoord(0, 1, 0, 1)
		icone:SetDrawLayer("BORDER")
	end

	-- Le contour. La source ne pose que le fond d'une case vide
	-- (bags-item-slot64), qui disparait des qu'un objet occupe la case : les
	-- emplacements n'ont alors plus de bord. On ajoute donc le cadre des sacs,
	-- celui-la meme que porte la barre des sacs.
	local contour = bouton:CreateTexture(nil, "ARTWORK")
	if ForeverUI.SetAtlas(contour, "ui-hud-actionbar-iconframe-bags", true) then
		contour:SetAllPoints(bouton)
		bouton.foreverContour = contour
	else
		contour:Hide()
	end

	-- Le voile de recherche : la source le declare sur le bouton d'objet
	-- lui-meme, noir a 80 %, sur toute la surface.
	local voile = bouton:CreateTexture(nil, "OVERLAY")
	voile:SetTexture(0, 0, 0, 0.8)
	voile:SetAllPoints(bouton)
	voile:Hide()
	bouton.foreverVoile = voile

	bouton.foreverSkinned = true
end

local function habillerCadre(cadre)
	if not cadre or cadre.foreverSkinned then
		return
	end

	local nom = cadre:GetName()

	-- L'habillage d'epoque : quatre morceaux empiles, plus la version a un
	-- seul emplacement. ContainerFrame_GenerateFrame les reaffiche et leur
	-- change de texture a chaque ouverture, mais ne touche pas leur alpha.
	for _, suffixe in ipairs({ "BackgroundTop", "BackgroundMiddle1", "BackgroundMiddle2",
		"BackgroundBottom", "Background1Slot" }) do
		local texture = _G[nom .. suffixe]
		if texture then
			texture:SetAlpha(0)
		end
	end

	ForeverUI.SetPanelArt(cadre)

	-- Le portrait se pose dans l'anneau du coin haut gauche. L'anneau est
	-- centre a 13,5 px du bord gauche et 14 px sous le haut (mesure sur
	-- l'image du coin), son trou fait 36 de diametre. 3.3.5 n'a pas de
	-- masque : l'icone est rognee pour tenir dans le rond.
	local portrait = _G[nom .. "Portrait"]
	if portrait then
		portrait:ClearAllPoints()
		portrait:SetWidth(34)
		portrait:SetHeight(34)
		portrait:SetPoint("CENTER", cadre, "TOPLEFT", 13.5, -14)
		portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		portrait:SetDrawLayer("OVERLAY")
	end

	-- Le titre : centre dans la bande du haut, entre 58 et la largeur moins 24.
	local titre = _G[nom .. "Name"]
	if titre then
		titre:ClearAllPoints()
		titre:SetPoint("TOPLEFT", cadre, "TOPLEFT", 58, -6)
		titre:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", -24, -6)
		titre:SetJustifyH("CENTER")
	end

	for index = 1, MAX_CONTAINER_ITEMS do
		habillerBouton(_G[nom .. "Item" .. index])
	end

	cadre.foreverSkinned = true
	table.insert(cadres, cadre)
end

-- ---------------------------------------------------------- la recherche
local Recherche = { texte = "" }
ForeverUI.BagSearch = Recherche

-- Le nom d'un objet, meme quand le client ne l'a pas encore en cache : le
-- lien porte toujours le nom entre crochets.
local function nomDeLObjet(lien)
	if not lien then
		return nil
	end
	local nom, _, _, _, _, type_, sousType = GetItemInfo(lien)
	if nom then
		return nom, type_, sousType
	end
	return string.match(lien, "%[(.+)%]")
end

function Recherche.Correspond(lien)
	if Recherche.texte == "" then
		return true
	end
	if not lien then
		return false
	end

	local nom, type_, sousType = nomDeLObjet(lien)
	for _, champ in ipairs({ nom, type_, sousType }) do
		if champ and string.find(string.lower(champ), Recherche.texte, 1, true) then
			return true
		end
	end
	return false
end

function Recherche.Appliquer(cadre)
	local nom = cadre:GetName()
	local sac = cadre:GetID()
	for index = 1, cadre.size or 0 do
		local bouton = _G[nom .. "Item" .. index]
		if bouton and bouton.foreverVoile then
			local lien = GetContainerItemLink(sac, bouton:GetID())
			if lien and not Recherche.Correspond(lien) then
				bouton.foreverVoile:Show()
			else
				bouton.foreverVoile:Hide()
			end
		end
	end
end

function Recherche.Tout()
	for _, cadre in ipairs(cadres) do
		if cadre:IsShown() then
			Recherche.Appliquer(cadre)
		end
	end
end

function Recherche.Set(texte)
	Recherche.texte = string.lower(texte or "")
	Recherche.Tout()
end

-- -------------------------------------------------------------- le tri
--
-- L'ordre des categories est celui du jeu lui-meme : GetAuctionItemClasses
-- rend les classes d'objets dans l'ordre ou le client les presente.
local Tri = { file = {}, actif = false }
ForeverUI.BagSort = Tri

local rangClasse

local function construireRangs()
	if rangClasse then
		return
	end
	rangClasse = {}
	if GetAuctionItemClasses then
		local classes = { GetAuctionItemClasses() }
		for index, nom in ipairs(classes) do
			rangClasse[nom] = index
		end
	end
end

local function lireCase(sac, emplacement)
	local lien = GetContainerItemLink(sac, emplacement)
	if not lien then
		return nil
	end
	local _, nombre, verrouille = GetContainerItemInfo(sac, emplacement)
	local nom, _, qualite, _, _, type_, sousType, pileMax = GetItemInfo(lien)
	return {
		lien = lien,
		nombre = nombre or 1,
		verrouille = verrouille,
		nom = nom or string.match(lien, "%[(.+)%]") or lien,
		qualite = qualite or 0,
		classe = rangClasse[type_ or ""] or 99,
		sousType = sousType or "",
		pileMax = pileMax or 1,
	}
end

local function avant(a, b)
	if a.classe ~= b.classe then
		return a.classe < b.classe
	end
	if a.sousType ~= b.sousType then
		return a.sousType < b.sousType
	end
	if a.qualite ~= b.qualite then
		return a.qualite > b.qualite
	end
	if a.nom ~= b.nom then
		return a.nom < b.nom
	end
	return a.nombre > b.nombre
end

-- L'etat courant des sacs : une case par emplacement, dans l'ordre.
local function relever()
	local cases = {}
	for _, sac in ipairs(SACS) do
		for emplacement = 1, (GetContainerNumSlots(sac) or 0) do
			table.insert(cases, {
				sac = sac,
				emplacement = emplacement,
				objet = lireCase(sac, emplacement),
			})
		end
	end
	return cases
end

local function verrouille(case)
	local _, _, estVerrouille = GetContainerItemInfo(case.sac, case.emplacement)
	return estVerrouille
end

-- Une seule action par passage : le serveur doit confirmer chaque
-- deplacement avant le suivant, sinon la case est encore verrouillee.
local function uneEtape()
	local cases = relever()

	-- 1. reunir les piles entamees du meme objet
	for i = 1, #cases do
		local a = cases[i].objet
		if a and a.nombre < a.pileMax then
			for j = i + 1, #cases do
				local b = cases[j].objet
				if b and b.lien == a.lien and b.nombre < b.pileMax then
					if verrouille(cases[i]) or verrouille(cases[j]) then
						return true
					end
					PickupContainerItem(cases[j].sac, cases[j].emplacement)
					PickupContainerItem(cases[i].sac, cases[i].emplacement)
					return true
				end
			end
		end
	end

    -- 2. mettre en ordre : la case i doit porter le i-eme objet trie
	local objets = {}
	for _, case in ipairs(cases) do
		if case.objet then
			table.insert(objets, case.objet)
		end
	end
	table.sort(objets, avant)

	for i = 1, #cases do
		local voulu = objets[i]
		local present = cases[i].objet
		local memeObjet = (voulu == nil and present == nil)
			or (voulu and present and voulu.lien == present.lien and voulu.nombre == present.nombre)
		if not memeObjet then
			if voulu == nil then
				return false        -- plus rien a placer
			end
			-- trouver la case qui porte l'objet voulu
			for j = i + 1, #cases do
				local candidat = cases[j].objet
				if candidat and candidat.lien == voulu.lien and candidat.nombre == voulu.nombre then
					if verrouille(cases[i]) or verrouille(cases[j]) then
						return true
					end
					PickupContainerItem(cases[j].sac, cases[j].emplacement)
					PickupContainerItem(cases[i].sac, cases[i].emplacement)
					return true
				end
			end
			return false            -- introuvable : on s'arrete plutot que tourner
		end
	end

	return false                    -- tout est en place
end

local MAX_ETAPES = 400
local tempsDepuisEtape = 0

local horloge = CreateFrame("Frame")
horloge:Hide()
horloge:SetScript("OnUpdate", function(self, elapsed)
	tempsDepuisEtape = tempsDepuisEtape + elapsed
	if tempsDepuisEtape < 0.1 then
		return
	end
	tempsDepuisEtape = 0

	Tri.etapes = (Tri.etapes or 0) + 1
	if Tri.etapes > MAX_ETAPES or not uneEtape() then
		Tri.actif = false
		self:Hide()
		Recherche.Tout()
	end
end)

function Tri.Lancer()
	if Tri.actif then
		return
	end
	if CursorHasItem() then
		ClearCursor()
	end
	construireRangs()
	Tri.actif = true
	Tri.etapes = 0
	tempsDepuisEtape = 0
	horloge:Show()
end

-- ------------------------------------------- le champ et le bouton de tri
local champ = CreateFrame("EditBox", "ForeverUIBagSearchBox", UIParent, "InputBoxTemplate")
champ:SetWidth(RECHERCHE_W)
champ:SetHeight(RECHERCHE_H)
champ:SetAutoFocus(false)
champ:SetMaxLetters(15)
champ:SetTextInsets(16, 20, 0, 0)
champ:Hide()

local loupe = champ:CreateTexture(nil, "OVERLAY")
ForeverUI.SetAtlas(loupe, "common-search-magnifyingglass", true)
loupe:SetWidth(10)
loupe:SetHeight(10)
loupe:SetPoint("LEFT", champ, "LEFT", 1, -1)

local invite = champ:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
invite:SetPoint("LEFT", champ, "LEFT", 16, 0)
invite:SetText(SEARCH or "Rechercher")

local effacer = CreateFrame("Button", nil, champ)
effacer:SetWidth(17)
effacer:SetHeight(17)
effacer:SetPoint("RIGHT", champ, "RIGHT", -3, 0)
effacer:Hide()
local croix = effacer:CreateTexture(nil, "ARTWORK")
ForeverUI.SetAtlas(croix, "common-search-clearbutton", true)
croix:SetWidth(10)
croix:SetHeight(10)
croix:SetPoint("TOPLEFT", effacer, "TOPLEFT", 3, -3)
croix:SetAlpha(0.5)
effacer:SetScript("OnEnter", function() croix:SetAlpha(1) end)
effacer:SetScript("OnLeave", function() croix:SetAlpha(0.5) end)
effacer:SetScript("OnClick", function()
	champ:SetText("")
	champ:ClearFocus()
end)

local function majChamp()
	local texte = champ:GetText() or ""
	if texte == "" and not champ:HasFocus() then
		invite:Show()
	else
		invite:Hide()
	end
	if texte == "" then
		effacer:Hide()
	else
		effacer:Show()
	end
end

champ:SetScript("OnTextChanged", function(self)
	majChamp()
	Recherche.Set(self:GetText())
end)
champ:SetScript("OnEditFocusGained", majChamp)
champ:SetScript("OnEditFocusLost", majChamp)
champ:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
champ:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

-- RELEVE -- BagSearch_OnChar : quatre caracteres identiques a la suite et le
-- champ rend la main, pour ne pas bloquer un joueur qui martele une touche.
champ:SetScript("OnChar", function(self)
	local texte = self:GetText() or ""
	if string.len(texte) >= 4 then
		local repete = true
		for i = 1, 3 do
			if string.sub(texte, -i, -i) ~= string.sub(texte, -1 - i, -1 - i) then
				repete = false
				break
			end
		end
		if repete then
			self:ClearFocus()
		end
	end
end)

local boutonTri = CreateFrame("Button", "ForeverUIBagSortButton", UIParent)
boutonTri:SetWidth(TRI_W)
boutonTri:SetHeight(TRI_H)
boutonTri:Hide()

local triNormale = boutonTri:CreateTexture(nil, "ARTWORK")
ForeverUI.SetAtlas(triNormale, "bags-button-autosort-up", true)
triNormale:SetAllPoints(boutonTri)
boutonTri:SetNormalTexture(triNormale)

local triEnfoncee = boutonTri:CreateTexture(nil, "ARTWORK")
ForeverUI.SetAtlas(triEnfoncee, "bags-button-autosort-down", true)
triEnfoncee:SetAllPoints(boutonTri)
boutonTri:SetPushedTexture(triEnfoncee)

local triSurvol = boutonTri:CreateTexture(nil, "HIGHLIGHT")
triSurvol:SetTexture(SURVOL_CARRE)
triSurvol:SetBlendMode("ADD")
triSurvol:SetWidth(24)
triSurvol:SetHeight(23)
triSurvol:SetPoint("CENTER")
boutonTri:SetHighlightTexture(triSurvol)

boutonTri:SetScript("OnClick", function()
	Tri.Lancer()
end)
boutonTri:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText(RANGER, 1, 1, 1)
	GameTooltip:AddLine(RANGER_AIDE, nil, nil, nil, true)
	GameTooltip:Show()
end)
boutonTri:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- RELEVE -- ContainerFrameMixin:UpdateSearchBox : les deux ne se montrent que
-- sur le sac principal, le champ en TOPLEFT (42, -37) et le bouton en
-- TOPRIGHT (-9, -34).
local function poserOutils()
	local hote
	for _, cadre in ipairs(cadres) do
		if cadre:IsShown() and cadre:GetID() == 0 then
			hote = cadre
			break
		end
	end

	if not hote then
		champ:Hide()
		boutonTri:Hide()
		-- BagSearch_OnHide : plus de barre visible, la recherche s'efface.
		if champ:GetText() ~= "" then
			champ:SetText("")
		end
		return
	end

	champ:SetParent(hote)
	champ:ClearAllPoints()
	champ:SetPoint("TOPLEFT", hote, "TOPLEFT", 42, -37)
	champ:SetWidth(RECHERCHE_W)
	champ:Show()

	boutonTri:SetParent(hote)
	boutonTri:ClearAllPoints()
	boutonTri:SetPoint("TOPRIGHT", hote, "TOPRIGHT", -9, -34)
	boutonTri:Show()
end

-- RELEVE -- 3.3.5 ContainerFrame_GenerateFrame : le premier bouton porte le
-- coin BAS DROIT de la grille, les suivants s'enchainent vers la gauche puis
-- vers le haut. Deplacer ce seul bouton deplace donc toute la grille.
local function poserGrille(cadre)
	local taille = cadre.size or 0
	if taille <= 1 then
		return                      -- le cadeau a un seul emplacement garde sa forme
	end

	local nom = cadre:GetName()
	local rangees = math.ceil(taille / COLONNES)
	local hauteurGrille = rangees * PAS_Y - (PAS_Y - EMPLACEMENT)
	local largeurGrille = COLONNES * EMPLACEMENT + (COLONNES - 1) * (PAS_X - EMPLACEMENT)
	local marge = ((CONTAINER_WIDTH or 192) - largeurGrille) / 2

	local sacADos = cadre:GetID() == 0
	local entete = sacADos and ENTETE_SAC_A_DOS or ENTETE_SAC

	-- La bourse ne s'affiche que sur le sac a dos, et doit tenir DANS la
	-- fenetre : on lui reserve sa hauteur sous la grille.
	local bourse = _G[nom .. "MoneyFrame"]
	local placeBourse = 0
	if sacADos and bourse then
		local hauteur = bourse:GetHeight()
		if not hauteur or hauteur < 1 then
			hauteur = 24
		end
		placeBourse = hauteur + 8
	end

	cadre:SetHeight(entete + hauteurGrille + placeBourse + MARGE_BAS)

	local premier = _G[nom .. "Item1"]
	if premier then
		premier:ClearAllPoints()
		premier:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", -marge, placeBourse + MARGE_BAS)
	end

	if sacADos and bourse then
		bourse:ClearAllPoints()
		bourse:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", -12, 8)
	end
end

ForeverUI.BagsLayout = poserOutils

-- ------------------------------------------------------------- accroches
local function habillerTout()
	for index = 1, NB_CADRES do
		habillerCadre(_G["ContainerFrame" .. index])
	end
end

habillerTout()
majChamp()

if hooksecurefunc then
	-- Le client repose ses propres morceaux a chaque ouverture de sac.
	hooksecurefunc("ContainerFrame_GenerateFrame", function(cadre)
		habillerCadre(cadre)
		poserGrille(cadre)
		poserOutils()
		Recherche.Tout()
	end)

	hooksecurefunc("ContainerFrame_Update", function(cadre)
		Recherche.Appliquer(cadre)
	end)

	hooksecurefunc("ContainerFrame_OnHide", function()
		poserOutils()
	end)
end

local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:RegisterEvent("BAG_UPDATE")
veilleur:SetScript("OnEvent", function()
	habillerTout()
	poserOutils()
	Recherche.Tout()
end)

ForeverUI.BagsDebug = function()
	local ouverts = 0
	for _, cadre in ipairs(cadres) do
		if cadre:IsShown() then
			ouverts = ouverts + 1
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r sacs : %d cadres habilles, %d ouverts | recherche \"%s\" | champ visible=%s | tri actif=%s",
		#cadres, ouverts, Recherche.texte, tostring(champ:IsShown()), tostring(Tri.actif)))
end
