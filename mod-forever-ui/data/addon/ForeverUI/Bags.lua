-- ForeverUI : l'interface des sacs.
--
-- RELEVE DES SOURCES -- tout vient du code extrait de camelot, qui pour les
-- sacs se sert du fichier commun (camelot/ContainerFrame.lua ne fait qu'une
-- chose : recadrer le masque rond du portrait).
--
-- mainline/ContainerFrame.lua -- LA GEOMETRIE, chiffre par chiffre
--   CONTAINER_WIDTH = 178, ITEM_SPACING_X = ITEM_SPACING_Y = 5, quatre
--   colonnes, boutons de 37.
--   ContainerFrameMixin:GetFirstButtonOffsetY = 9
--   ContainerFrameMixin:GetPaddingHeight = 9 + 48, et +30 pour le sac a dos
--   (la bande du champ de recherche)
--   ContainerFrameMixin:CalculateHeight = hauteur des rangees + ce
--   remplissage + CalculateExtraHeight, qui vaut la hauteur de la bourse pour
--   le sac a dos.
--   sac ordinaire : premier bouton BOTTOMRIGHT (-7, 9) du cadre.
--   sac a dos     : bourse BOTTOMLEFT (8, 8) et BOTTOMRIGHT (-8, 8), haute de
--                   13 ; premier bouton BOTTOMRIGHT sur le TOPRIGHT de la
--                   bourse, decale de (0, 4).
--   bourse        : ContainerFrameCurrencyBorderTemplate, haut de 17, bouts
--                   de 8 x 17 (common-coinbox-left et -right) et milieu tendu.
--
-- mainline/ContainerFrame.xml
--   cadre           ContainerFrameTemplate herite de PortraitFrameFlatTemplate :
--                   fond plat + encadrement de metal en neuf tranches, jeu
--                   HeldBagLayout. Monte par ForeverUI.SetPanelArt.
--   emplacement     ContainerFrameItemButtonTemplate, 37 x 37, fond d'un
--                   emplacement vide = bags-item-slot64.
--
-- shared/ItemButtonTemplate.lua : SetItemButtonQuality_Base
--   Le contour d'un objet, c'est IconBorder : Interface\Common\WhiteIconFrame
--   teinte par la couleur de qualite de l'objet. Une case vide n'en a pas ;
--   c'est son fond qui se voit.
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

-- =====================================================================
-- REGLAGES DE L'INTERFACE DES SACS
--
-- RELEVE -- blizzard_uipanels_game/mainline/containerframe.lua, ContainerFrameMixin.
-- Tout ce bloc est recopie de la source ; rien n'y est mesure ni estime.
--
--   CalculateWidth()        = CONTAINER_WIDTH, une CONSTANTE (178) -- la
--                             largeur ne se deduit PAS de la grille
--   CalculateHeight()       = rangees x 37 + (rangees - 1) x 5
--                             + GetPaddingHeight() + CalculateExtraHeight()
--   GetPaddingHeight()      = GetFirstButtonOffsetY() (9) + 48
--                             + 30 sur le sac a dos (ContainerFrameBackpackMixin,
--                             "Account for the search box in the backpack")
--   CalculateExtraHeight()  = 0 ; + la hauteur de la bourse sur le sac a dos
--   GetInitialItemAnchor()  = sac porte : BOTTOMRIGHT du cadre, (-7, 9)
--                             sac a dos : BOTTOMRIGHT de la BOURSE, TOPRIGHT (0, 4)
--   UpdateCurrencyFrames()  = bourse BOTTOMLEFT (8, 8) / BOTTOMRIGHT (-8, 8)
--   SetSearchBoxPoint()     = champ TOPLEFT (42, -37), 96 de large
--   UpdateSearchBox()       = tri TOPRIGHT (-9, -34)
--   ContainerFrameItemButtonTemplate (containerframe.xml, ligne 82) : 37 x 37
--   ITEM_SPACING_X = ITEM_SPACING_Y = 5 ; colonnes = 4
--
-- CE QUI FAIT QUE LA FENETRE SUIT SON CONTENU : la hauteur est un CALCUL a
-- partir du nombre de rangees, pas une somme d'ancrages. Le comble (titre,
-- champ de recherche) est une hauteur fixe ancree en HAUT, exactement comme
-- dans la source -- c'est la formule qui s'adapte, pas les ancrages.
--   sac a dos, 16 cases : 163 + (9 + 48 + 30) + 13 = 263
--   sac porte, 16 cases : 163 + (9 + 48)           = 220
--
-- En jeu, pour essayer sans rien reinstaller :
--     /fui sacs                    la hauteur calculee, celle du cadre, le detail
--     /fui sacs emplacement 44     change une valeur et refait la fenetre
-- Quand le reglage convient, il se fige dans ce bloc.
local R = {
	-- LA GRILLE
	emplacement = 37,       -- ContainerFrameItemButtonTemplate
	ecartCases = 5,         -- ITEM_SPACING_X et ITEM_SPACING_Y
	colonnes = 4,           -- GetColumns()
	largeur = 178,          -- CONTAINER_WIDTH

	-- LE CALCUL DE LA HAUTEUR
	premierBoutonY = 9,     -- GetFirstButtonOffsetY()
	premierBoutonX = -7,    -- GetInitialItemAnchor()
	entete = 48,            -- GetPaddingHeight() : "titlebar and attic"
	bandeRecherche = 30,    -- le meme, + 30 sur le sac a dos

	-- LA BOURSE, et la grille qui s'y accroche sur le sac a dos
	bourseHauteur = 13,     -- UpdateMoneyFrame()
	bourseCote = 8,         -- UpdateCurrencyFrames()
	bourseBas = 8,          -- UpdateCurrencyFrames()
	ecartBourseGrille = 4,  -- ContainerFrameBackpackMixin:GetInitialItemAnchor()
	bourseCadre = 17,       -- l'encadre de camelot deborde de la bourse

	-- LE COMBLE
	champLargeur = 96,      -- SetSearchBoxPoint()
	champHauteur = 18,
	champX = 42,
	champY = -37,
	triLargeur = 28,
	triHauteur = 26,
	triX = -9,              -- UpdateSearchBox()
	triY = -34,

	-- LES DECORS DU CADRE
	fermeture = 24,
	fermetureX = 1,
	fermetureY = 0,
	portrait = 34,
	portraitX = 13.5,
	portraitY = -14,

	-- L'ENSEMBLE
	echelle = 1,            -- 1 = taille de camelot ; 1.25 = un quart de plus
}
ForeverUI = ForeverUI or {}
ForeverUI.BagsSettings = R
-- =====================================================================

local NB_CADRES = NUM_CONTAINER_FRAMES or 13
local SACS = { 0, 1, 2, 3, 4 }          -- sac a dos et les quatre sacs portes

-- Lua 5.1 lit les antislashs comme des echappements : on pose le separateur
-- en clair.
local SEP = string.char(92)
local SURVOL_CARRE = "Interface" .. SEP .. "Buttons" .. SEP .. "ButtonHilight-Square"
local CADRE_QUALITE = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "whiteiconframe"

-- MESURE SUR LA CAPTURE. camelot pose un cadre sur CHAQUE case, pleine ou
-- vide : gris sombre, bords entre 25 et 49, coins vers 100. L'image porte ces
-- memes valeurs a 255 et 140 : la teinte vaut donc 0,39. La couleur de
-- qualite ne prend le relais qu'a partir de peu commun.
local CADRE_GRIS = 0.39
local QUALITE_TEINTEE = 2

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

	-- Le contour d'un objet : WhiteIconFrame teinte par sa qualite, comme
	-- SetItemButtonQuality_Base le fait. Une case vide n'en a pas.
	local contour = bouton:CreateTexture(nil, "OVERLAY")
	contour:SetTexture(CADRE_QUALITE)
	contour:SetAllPoints(bouton)
	contour:SetVertexColor(CADRE_GRIS, CADRE_GRIS, CADRE_GRIS)
	bouton.foreverContour = contour

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
		portrait:SetWidth(R.portrait)
		portrait:SetHeight(R.portrait)
		portrait:SetPoint("CENTER", cadre, "TOPLEFT", R.portraitX, R.portraitY)
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

	-- Le bouton de fermeture : 24 x 24, TOPRIGHT (1, 0), le X rouge des
	-- panneaux modernes (UIPanelCloseButtonNoScripts, atlas RedButton-Exit).
	local fermer = _G[nom .. "CloseButton"]
	if fermer then
		fermer:SetWidth(R.fermeture)
		fermer:SetHeight(R.fermeture)
		fermer:ClearAllPoints()
		fermer:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", R.fermetureX, R.fermetureY)
		for atlas, methode in pairs({ ["redbutton-exit"] = "GetNormalTexture",
			["redbutton-exit-pressed"] = "GetPushedTexture",
			["redbutton-exit-disabled"] = "GetDisabledTexture",
			["redbutton-highlight"] = "GetHighlightTexture" }) do
			local texture = fermer[methode] and fermer[methode](fermer)
			if texture then
				ForeverUI.SetAtlas(texture, atlas, true)
				texture:ClearAllPoints()
				texture:SetAllPoints(fermer)
				if atlas == "redbutton-highlight" then
					texture:SetBlendMode("ADD")
				end
			end
		end
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

-- Le voile de recherche ET le contour de qualite se decident au meme moment :
-- les deux dependent de ce que la case contient.
function Recherche.Appliquer(cadre)
	local nom = cadre:GetName()
	local sac = cadre:GetID()
	for index = 1, cadre.size or 0 do
		local bouton = _G[nom .. "Item" .. index]
		if bouton and bouton.foreverVoile then
			local emplacement = bouton:GetID()
			local lien = GetContainerItemLink(sac, emplacement)

			if lien and not Recherche.Correspond(lien) then
				bouton.foreverVoile:Show()
			else
				bouton.foreverVoile:Hide()
			end

			-- Le cadre est toujours la ; seule sa teinte change, et seulement
			-- a partir de peu commun.
			local contour = bouton.foreverContour
			if contour then
				local qualite = select(4, GetContainerItemInfo(sac, emplacement))
				local couleur = lien and qualite and qualite >= QUALITE_TEINTEE
					and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualite]
				if couleur then
					contour:SetVertexColor(couleur.r, couleur.g, couleur.b)
				else
					contour:SetVertexColor(CADRE_GRIS, CADRE_GRIS, CADRE_GRIS)
				end
				contour:Show()
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
champ:SetWidth(R.champLargeur)
champ:SetHeight(R.champHauteur)
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
boutonTri:SetWidth(R.triLargeur)
boutonTri:SetHeight(R.triHauteur)
boutonTri:Hide()

-- PIEGE 3.3.5. SetNormalTexture et ses soeurs ne prennent qu'un CHEMIN de
-- fichier ; leur passer un objet texture, comme le fait le client moderne,
-- leve une erreur -- et une erreur au premier niveau d'un fichier abandonne
-- TOUT ce qui suit. On pose donc le chemin de la feuille, puis on regle
-- l'atlas sur la texture que le bouton vient de creer.
local function poserEtat(bouton, poser, obtenir, atlas, largeur, hauteur, add)
	local e = ForeverUI.AtlasEntry(atlas)
	if not e then
		return nil
	end

	bouton[poser](bouton, e[1])
	local texture = bouton[obtenir](bouton)
	if not texture then
		return nil
	end

	ForeverUI.SetAtlas(texture, atlas, true)
	texture:ClearAllPoints()
	if largeur then
		texture:SetWidth(largeur)
		texture:SetHeight(hauteur)
		texture:SetPoint("CENTER")
	else
		texture:SetAllPoints(bouton)
	end
	if add then
		texture:SetBlendMode("ADD")
	end
	return texture
end

poserEtat(boutonTri, "SetNormalTexture", "GetNormalTexture", "bags-button-autosort-up")
poserEtat(boutonTri, "SetPushedTexture", "GetPushedTexture", "bags-button-autosort-down")

-- Le survol est un fichier du client, pas un element d'atlas : 24 x 23 centre.
boutonTri:SetHighlightTexture(SURVOL_CARRE)
local triSurvol = boutonTri:GetHighlightTexture()
if triSurvol then
	triSurvol:SetBlendMode("ADD")
	triSurvol:ClearAllPoints()
	triSurvol:SetWidth(24)
	triSurvol:SetHeight(23)
	triSurvol:SetPoint("CENTER")
end

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

-- ------------------------------------------------------------ les mesures
-- RELEVE -- ContainerFrameMixin:GetRows, CalculateWidth, CalculateHeight,
-- GetPaddingHeight, CalculateExtraHeight, et leurs surcharges du sac a dos.
-- C'est LE calcul qui fait suivre la fenetre a son contenu : la hauteur se
-- deduit du nombre de rangees, jamais d'une somme d'ancrages.
local function mesures(cadre)
	local taille = cadre.size or 0
	local m = { sacADos = cadre:GetID() == 0 }

	m.rangees = math.ceil(taille / R.colonnes)                      -- GetRows()
	m.grille = m.rangees * R.emplacement + (m.rangees - 1) * R.ecartCases

	-- GetPaddingHeight() : le bas du premier bouton, plus le titre et le
	-- comble ; le sac a dos ajoute la bande du champ de recherche.
	m.comble = R.premierBoutonY + R.entete
	if m.sacADos then
		m.comble = m.comble + R.bandeRecherche
	end

	-- CalculateExtraHeight() : la bourse, sur le sac a dos seulement.
	m.extra = m.sacADos and R.bourseHauteur or 0

	m.hauteur = m.grille + m.comble + m.extra                       -- CalculateHeight()
	m.largeur = R.largeur                                           -- CalculateWidth()
	return m
end

-- RELEVE -- ContainerFrameMixin:UpdateSearchBox : les deux ne se montrent que-- RELEVE -- ContainerFrameMixin:UpdateSearchBox : les deux ne se montrent que
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

	-- Les deux sont ancres en HAUT, comme dans la source : ils occupent le
	-- comble, dont la hauteur est fixe. C'est la formule de CalculateHeight
	-- qui adapte la fenetre, pas ces deux ancrages.
	champ:SetParent(hote)
	champ:ClearAllPoints()
	champ:SetWidth(R.champLargeur)
	champ:SetHeight(R.champHauteur)
	champ:SetPoint("TOPLEFT", hote, "TOPLEFT", R.champX, R.champY)
	champ:Show()

	boutonTri:SetParent(hote)
	boutonTri:ClearAllPoints()
	boutonTri:SetWidth(R.triLargeur)
	boutonTri:SetHeight(R.triHauteur)
	boutonTri:SetPoint("TOPRIGHT", hote, "TOPRIGHT", R.triX, R.triY)
	boutonTri:Show()
end

-- L'encadre de la bourse : deux bouts et un milieu tendu, 17 de haut.
local function habillerBourse(bourse)
	if not bourse or bourse.foreverBorde then
		return
	end

	bourse:SetHeight(R.bourseHauteur)

	local gauche = bourse:CreateTexture(nil, "BACKGROUND")
	if not ForeverUI.SetAtlas(gauche, "common-coinbox-left", true) then
		gauche:Hide()
		return
	end
	gauche:SetWidth(R.bourseCadre / 2)
	gauche:SetHeight(R.bourseCadre)
	gauche:SetPoint("LEFT", bourse, "LEFT", 0, 0)

	local droite = bourse:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(droite, "common-coinbox-right", true)
	droite:SetWidth(R.bourseCadre / 2)
	droite:SetHeight(R.bourseCadre)
	droite:SetPoint("RIGHT", bourse, "RIGHT", 0, 0)

	local milieu = bourse:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(milieu, "_common-coinbox-center", true)
	milieu:SetPoint("TOPLEFT", gauche, "TOPRIGHT")
	milieu:SetPoint("BOTTOMRIGHT", droite, "BOTTOMLEFT")

	bourse.foreverBorde = true
end

-- RELEVE -- 3.3.5 ContainerFrame_GenerateFrame : le premier bouton porte le
-- coin BAS DROIT de la grille, les suivants s'enchainent vers la gauche puis
-- vers le haut, avec 4 px entre deux rangees. camelot en met 5 : on repose
-- donc aussi le premier bouton de chaque rangee.
-- RELEVE -- ContainerFrameMixin:UpdateFrameSize, GetInitialItemAnchor,
-- GetAnchorLayout (grille BottomRightToTopLeft) et, pour le sac a dos,
-- ContainerFrameBackpackMixin:GetInitialItemAnchor + UpdateCurrencyFrames.
local function poserGrille(cadre)
	local taille = cadre.size or 0
	if taille <= 1 then
		return                      -- le cadeau a un seul emplacement garde sa forme
	end

	local nom = cadre:GetName()
	local m = mesures(cadre)
	local bourse = _G[nom .. "MoneyFrame"]

	-- UpdateFrameSize() : la fenetre prend la mesure calculee.
	cadre:SetScale(R.echelle)
	cadre:SetWidth(m.largeur)
	cadre:SetHeight(m.hauteur)

	-- UpdateCurrencyFrames() : la bourse se pose avant la grille, qui
	-- s'accroche a elle.
	if m.sacADos and bourse then
		habillerBourse(bourse)
		bourse:ClearAllPoints()
		bourse:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", R.bourseCote, R.bourseBas)
		bourse:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", -R.bourseCote, R.bourseBas)
		bourse:Show()
	end

	-- GetAnchorLayout() : BottomRightToTopLeft, 4 colonnes, 5 d'ecart. Toute
	-- la grille est reposee, 3.3.5 employant ses propres ecarts.
	for index = 1, taille do
		local bouton = _G[nom .. "Item" .. index]
		if bouton then
			bouton:SetWidth(R.emplacement)
			bouton:SetHeight(R.emplacement)
			bouton:ClearAllPoints()
			if index == 1 then
				if m.sacADos and bourse then
					-- ContainerFrameBackpackMixin:GetInitialItemAnchor()
					bouton:SetPoint("BOTTOMRIGHT", bourse, "TOPRIGHT",
						0, R.ecartBourseGrille)
				else
					-- ContainerFrameMixin:GetInitialItemAnchor()
					bouton:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT",
						R.premierBoutonX, R.premierBoutonY)
				end
			elseif math.fmod(index - 1, R.colonnes) == 0 then
				bouton:SetPoint("BOTTOMRIGHT", _G[nom .. "Item" .. (index - R.colonnes)],
					"TOPRIGHT", 0, R.ecartCases)
			else
				bouton:SetPoint("BOTTOMRIGHT", _G[nom .. "Item" .. (index - 1)],
					"BOTTOMLEFT", -R.ecartCases, 0)
			end
		end
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

	-- ContainerFrame_Update est rappele a chaque mise a jour de sac. Le
	-- client y repose ses propres morceaux : la grille est reposee ensuite,
	-- sinon la taille d'origine revient des le premier objet ramasse.
	hooksecurefunc("ContainerFrame_Update", function(cadre)
		poserGrille(cadre)
		Recherche.Appliquer(cadre)
	end)

	hooksecurefunc("ContainerFrame_OnHide", function()
		poserOutils()
	end)

	-- Le client remet son echelle et repose les cadres a chaque
	-- reagencement : on repasse derriere lui, taille comprise.
	hooksecurefunc("updateContainerFrameAnchors", function()
		for _, cadre in ipairs(cadres) do
			if cadre:GetScale() ~= R.echelle then
				cadre:SetScale(R.echelle)
			end
			if cadre:IsShown() then
				poserGrille(cadre)
			end
		end
	end)
end

local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:RegisterEvent("BAG_UPDATE")
veilleur:SetScript("OnEvent", function()
	habillerTout()
	for _, cadre in ipairs(cadres) do
		if cadre:IsShown() then
			poserGrille(cadre)
		end
	end
	poserOutils()
	Recherche.Tout()
end)

-- Refaire toute la mise en page apres un changement de reglage.
function ForeverUI.BagsApply()
	for _, cadre in ipairs(cadres) do
		poserGrille(cadre)
	end
	poserOutils()
	Recherche.Tout()
end

-- Le diagnostic ne dit que ce que le JEU montre : pour CHAQUE sac ouvert, la
-- hauteur que la formule donne et celle que le cadre porte vraiment. Si les
-- deux different, quelque chose repose la taille apres nous, et la ligne le
-- dit au lieu de le laisser deviner.
ForeverUI.BagsDebug = function()
	local ouverts = 0
	for _, cadre in ipairs(cadres) do
		if cadre:IsShown() and (cadre.size or 0) > 0 then
			ouverts = ouverts + 1
			local nom = cadre:GetName()
			local m = mesures(cadre)
			local reelleL, reelleH = cadre:GetWidth(), cadre:GetHeight()
			local accord = (math.abs(reelleH - m.hauteur) < 0.5)
				and (math.abs(reelleL - m.largeur) < 0.5)

			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"|cff66ccffForeverUI|r %s (sac %d) : %d cases, %d rangees",
				nom, cadre:GetID(), cadre.size or 0, m.rangees))
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"   calcule %d x %d = grille %d + comble %d + extra %d | le cadre porte %.0f x %.0f  %s",
				m.largeur, m.hauteur, m.grille, m.comble, m.extra, reelleL, reelleH,
				accord and "|cff44ff44ACCORD|r" or "|cffff4444DESACCORD : le client repose la taille|r"))
		end
	end

	if ouverts == 0 then
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cff66ccffForeverUI|r aucun sac ouvert : ouvrez-en un puis refaites /fui sacs")
	end

	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"   cadres habilles %d | case %.0f | champ visible=%s",
		#cadres, R.emplacement, tostring(champ:IsShown())))

	-- Tous les reglages, par ordre alphabetique : la liste ne peut pas se
	-- demoder quand un reglage apparait ou disparait.
	local cles = {}
	for cle in pairs(R) do
		table.insert(cles, cle)
	end
	table.sort(cles)
	local ligne = ""
	for _, cle in ipairs(cles) do
		ligne = ligne .. string.format("%s=%s  ", cle, tostring(R[cle]))
		if string.len(ligne) > 80 then
			DEFAULT_CHAT_FRAME:AddMessage("   " .. ligne)
			ligne = ""
		end
	end
	if ligne ~= "" then
		DEFAULT_CHAT_FRAME:AddMessage("   " .. ligne)
	end
end

-- Changer un reglage en jeu, pour essayer avant de le figer dans le fichier.
function ForeverUI.BagsSet(cle, valeur)
	if R[cle] == nil then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r reglage inconnu : " .. tostring(cle))
		return false
	end
	local nombre = tonumber(valeur)
	if not nombre then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r valeur attendue : un nombre")
		return false
	end
	R[cle] = nombre
	ForeverUI.BagsApply()
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r sacs : %s = %s", cle, tostring(nombre)))
	return true
end
