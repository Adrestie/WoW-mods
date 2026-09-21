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
-- POUR AGRANDIR LA FENETRE DES SACS : CE NOMBRE, ET LUI SEUL.
-- 1 = la taille de camelot. 1.25 = un quart plus grand, et tout suit :
-- emplacements, icones, textes, encadrement, champ de recherche.
-- C'est ainsi que le client moderne s'y prend lui-meme
-- (ContainerFrameMixin, CONTAINER_SCALE) : il met la fenetre a l'echelle
-- plutot que de changer ses mesures.
local ECHELLE = 1
-- =====================================================================

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
local COLONNES = 4
local ECART = 5                 -- ITEM_SPACING_X et _Y
local LARGEUR_CADRE = 178       -- CONTAINER_WIDTH de camelot (192 en 3.3.5)
local REMPLISSAGE = 9 + 48      -- GetPaddingHeight
local REMPLISSAGE_RECHERCHE = 30
local MARGE_BAS = 9             -- GetFirstButtonOffsetY
local BOURSE_H = 13
local BOURSE_BAS, BOURSE_COTE = 8, 8

-- MESURE SUR LA CAPTURE DU VRAI CLIENT (docs/reference). A l'echelle 4/3 de
-- cette capture, la grille fait 217 px pour les 163 unites de camelot, un
-- emplacement 49 px pour 37, le pas 56 px pour 42, et la fenetre 411 px pour
-- les 305 unites que donne la formule sur cinq rangees. Les chiffres du code
-- de camelot sont donc les bons : rien a ajouter.

-- L'encadre de la bourse depasse d'elle de deux pixels en haut comme en bas
-- (17 de haut pour une bourse de 13). La derniere rangee se pose 1 px
-- au-dessus de cet encadre.
local BORDURE_BOURSE_H, BORDURE_BOURSE_BOUT = 17, 8
local BORDURE_DEPASSE = (BORDURE_BOURSE_H - BOURSE_H) / 2
local AIR_GRILLE_BOURSE = 1

local CADRE_QUALITE = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "whiteiconframe"

-- MESURE SUR LA CAPTURE. camelot pose un cadre sur CHAQUE case, pleine ou
-- vide : gris sombre, bords entre 25 et 49, coins vers 100. L'image porte ces
-- memes valeurs a 255 et 140 : la teinte vaut donc 0,39. La couleur de
-- qualite ne prend le relais qu'a partir de peu commun -- les objets communs
-- de la capture gardent le cadre gris.
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

	-- Le bouton de fermeture : 24 x 24, TOPRIGHT (1, 0), le X rouge des
	-- panneaux modernes (UIPanelCloseButtonNoScripts, atlas RedButton-Exit).
	local fermer = _G[nom .. "CloseButton"]
	if fermer then
		fermer:SetWidth(24)
		fermer:SetHeight(24)
		fermer:ClearAllPoints()
		fermer:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", 1, 0)
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

-- L'encadre de la bourse : deux bouts et un milieu tendu, 17 de haut.
local function habillerBourse(bourse)
	if not bourse or bourse.foreverBorde then
		return
	end

	bourse:SetHeight(BOURSE_H)

	local gauche = bourse:CreateTexture(nil, "BACKGROUND")
	if not ForeverUI.SetAtlas(gauche, "common-coinbox-left", true) then
		gauche:Hide()
		return
	end
	gauche:SetWidth(BORDURE_BOURSE_BOUT)
	gauche:SetHeight(BORDURE_BOURSE_H)
	gauche:SetPoint("LEFT", bourse, "LEFT", 0, 0)

	local droite = bourse:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(droite, "common-coinbox-right", true)
	droite:SetWidth(BORDURE_BOURSE_BOUT)
	droite:SetHeight(BORDURE_BOURSE_H)
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
local function poserGrille(cadre)
	local taille = cadre.size or 0
	if taille <= 1 then
		return                      -- le cadeau a un seul emplacement garde sa forme
	end

	local nom = cadre:GetName()
	local rangees = math.ceil(taille / COLONNES)
	local hauteurGrille = rangees * EMPLACEMENT + (rangees - 1) * ECART
	local sacADos = cadre:GetID() == 0

	cadre:SetWidth(LARGEUR_CADRE)
	-- Le client pose sa propre echelle dans updateContainerFrameAnchors (il
	-- retrecit les sacs quand l'ecran est court) ; on repasse derriere lui.
	cadre:SetScale(ECHELLE)

	local bourse = _G[nom .. "MoneyFrame"]
	local hauteur = hauteurGrille + REMPLISSAGE
	if sacADos then
		hauteur = hauteur + REMPLISSAGE_RECHERCHE + BOURSE_H
	end
	cadre:SetHeight(hauteur)

	if sacADos and bourse then
		habillerBourse(bourse)
		bourse:ClearAllPoints()
		bourse:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", BOURSE_COTE, BOURSE_BAS)
		bourse:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", -BOURSE_COTE, BOURSE_BAS)
		bourse:Show()
	end

	local premier = _G[nom .. "Item1"]
	if premier then
		premier:ClearAllPoints()
		if sacADos and bourse then
			premier:SetPoint("BOTTOMRIGHT", bourse, "TOPRIGHT", 0,
				BORDURE_DEPASSE + AIR_GRILLE_BOURSE)
		else
			premier:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", -7, MARGE_BAS)
		end
	end

	-- 3.3.5 empile les rangees avec 4 px ; camelot en met 5.
	for index = COLONNES + 1, taille, COLONNES do
		local bouton = _G[nom .. "Item" .. index]
		local dessous = _G[nom .. "Item" .. (index - COLONNES)]
		if bouton and dessous then
			bouton:ClearAllPoints()
			bouton:SetPoint("BOTTOMRIGHT", dessous, "TOPRIGHT", 0, ECART)
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

	hooksecurefunc("ContainerFrame_Update", function(cadre)
		Recherche.Appliquer(cadre)
	end)

	hooksecurefunc("ContainerFrame_OnHide", function()
		poserOutils()
	end)

	-- Le client remet son echelle a chaque reagencement des sacs.
	hooksecurefunc("updateContainerFrameAnchors", function()
		for _, cadre in ipairs(cadres) do
			if cadre:GetScale() ~= ECHELLE then
				cadre:SetScale(ECHELLE)
			end
		end
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
	local cadre = ContainerFrame1
	local nom = cadre:GetName()
	local premier = _G[nom .. "Item1"]
	local dernier = _G[nom .. "Item" .. math.max(1, (cadre.size or 1))]
	local bourse = _G[nom .. "MoneyFrame"]

	local haut = cadre:GetTop() or 0
	local bas = cadre:GetBottom() or 0
	local hautGrille = (dernier and dernier:GetTop()) or 0
	local basGrille = (premier and premier:GetBottom()) or 0

	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r sac : %d cases, %d rangees | cadre %.0f x %.0f (echelle %.2f)",
		cadre.size or 0, math.ceil((cadre.size or 0) / COLONNES),
		cadre:GetWidth(), cadre:GetHeight(), cadre:GetScale()))
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"   entete %.0f | grille %.0f | sous la grille %.0f | bourse %.0f de haut, %.0f du bas",
		haut - hautGrille, hautGrille - basGrille, basGrille - bas,
		bourse and bourse:GetHeight() or 0,
		bourse and ((bourse:GetBottom() or 0) - bas) or 0))
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"   cases habillees %d | case %.0f x %.0f | recherche visible=%s",
		#cadres, premier and premier:GetWidth() or 0, premier and premier:GetHeight() or 0,
		tostring(champ:IsShown())))
end
