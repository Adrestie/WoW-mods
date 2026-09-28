-- ForeverUI : l'hotel des ventes (AuctionFrame, Blizzard_AuctionUI charge a
-- la demande), a la DA de camelot (demande de l'utilisateur, 2026-09-28 :
-- « fait le reste du commerce » ; choix : l'hotel de WotLK habille camelot).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (Blizzard_AuctionUI.xml, -Templates.xml
-- et .lua de 3.3.5) :
--   AuctionFrame 832 x 447 a TOPLEFT (0, -104) ; UIPanelWindows :
--     doublewide, 840 ; son art AuctionFrameTopLeft / Top / TopRight /
--     BotLeft / Bot / BotRight (UI-AuctionFrame-<onglet>-*, change par
--     AuctionFrameTab_OnClick) ; visible de (12, -13) a (830, -439) ;
--     AuctionPortraitTexture 58 x 58 a (8, -7) ; AuctionFrameTab1..3
--     (BROWSE, BIDS, AUCTIONS) sous le bas ; AuctionFrameMoneyFrame
--     BOTTOMRIGHT sur BOTTOMLEFT (181, 20) ; AuctionFrameCloseButton TOPRIGHT
--     (3, -8) ;
--   AuctionFrameBrowse / Bid / Auctions 758 x 447 a TOPLEFT, titres
--     BrowseTitle / BidTitle / AuctionsTitle TOP (0, -18) ;
--   Parcourir : BrowseName, BrowseMinLevel / MaxLevel (InputBoxTemplate),
--     BrowseDropDown (UIDropDownMenuTemplate, libelle BrowseDropDownName) a
--     BrowseLevelText BOTTOMRIGHT (-5, -1), IsUsableCheckButton a
--     BrowseDropDownButton RIGHT (10, 13), ShowOnPlayerCheckButton dessous ;
--     AuctionFilterButton1..15 (AuctionClassButtonTemplate 136 x 20, fond
--     UI-AuctionFrame-FilterBg, surbrillance verrouillee a la selection,
--     FilterButton_SetType : alpha 1 / 0,4 / 0, texte a 4 / 12 / 20, traits
--     FilterLines) a (23, -105) ; BrowseFilterScrollFrame TOPRIGHT sur
--     TOPLEFT (158, -105) ; en-tetes BrowseQualitySort (186, -82)... ;
--     BrowseButton1..8 (BrowseButtonTemplate 37 de haut, cadre de nom
--     UI-AuctionItemNameFrame, icone UI-Quickslot2, surbrillance
--     HelpFrameButton-Highlight) a (195, -110) ; BrowseScrollFrame TOPRIGHT
--     (39, -105) ;
--   Offres : BidQualitySort (65, -52)..., BidButton1..9 a (27, -76),
--     BidScrollFrame TOPRIGHT (40, -74) ;
--   Encheres : AuctionsTabText (CREATE_AUCTION) TOP sur TOPLEFT (121, -55),
--     AuctionsItemButton 37 x 37 a (30, -94) sur UI-AuctionFrame-ItemSlot,
--     AuctionsStackSizeEntry / NumStacksEntry (Common-Input-Border),
--     PriceDropDown TOPRIGHT sur TOPLEFT (217, -215), DurationDropDown
--     BOTTOMRIGHT sur BOTTOMLEFT (217, 89), libelles sans nom a leur RIGHT
--     (-192, 3) ; AuctionsQualitySort (219, -51)..., AuctionsButton1..9 a
--     (219, -76), AuctionsScrollFrame TOPRIGHT (40, -72) ;
--   largeur des lignes : sans barre 625 / 793 / 599, avec 600 / 769 / 576, la
--     derniere colonne suivant (207 / 184, 169 / 145, 213 / 193), reposees a
--     chaque mise a jour ; fleches de tri UI-SortArrow (SortButton_UpdateArrow).
--
-- RELEVE -- CAMELOT (blizzard_auctionhouseui, [Family] mainline et shared) :
--   AuctionHouseFrame : PortraitFrameTemplate, portrait de l'unite ;
--     MoneyFrameInset (InsetFrameTemplate) de TOPLEFT sur BOTTOMLEFT (2, 27)
--     a BOTTOMRIGHT sur BOTTOMLEFT (167, 3), MoneyFrameBorder
--     (ThinGoldEdgeTemplate) 158 x 19 a BOTTOMLEFT (5, 6) ; onglets
--     PanelTabButtonTemplate, le premier BOTTOMLEFT (20, -28), les suivants a
--     +3 (PanelTemplates_SetNumTabs -> PanelTemplates_AnchorTabs) ;
--   les listes : InsetFrameTemplate et un fond a (3, -3) --
--     auctionhouse-background-categories (categories), -index (resultats,
--     offres, encheres), -sell-left (mise en vente) ; en-tetes a (4, -1) de
--     l'encadre, lignes 6 dessous, barre MinimalScrollBar hors de l'encadre
--     (bord a -22 de la liste, barre a +9 de la zone, 4 au-dessus du bas) ;
--   les categories (AuctionHouseFilterButton_SetUp) : categorie
--     auctionhouse-nav-button 136 x 32 a (-2, 0), choix -select et survol
--     -highlight 132 x 21 a LEFT, texte a 8 ; sous-categorie
--     -nav-button-secondary 133 x 32 a (1, 0), choix / survol -secondary-*
--     122 x 21 a (10, 0), texte a 18 ; troisieme niveau sans fond, choix
--     auctionhouse-ui-row-select / survol -row-highlight (ADD) 116 x 18 a
--     TOPRIGHT (0, -2), trait -tertiary-filterline a LEFT (18, 3), texte a 26 ;
--   les lignes (AuctionHouseItemListLineTemplate) : fond alterne
--     auctionhouse-rowstripe-1 / -2 (pas sur les resultats : hideStripes),
--     choix auctionhouse-ui-row-select et survol -row-highlight en ADD sur
--     toute la ligne ; icone cerclee de auctionhouse-itemicon-small-border
--     (16 pour 14) ;
--   en-tetes : l'art de WotLK (ColumnDisplayButtonShortTemplate), fleche
--     auctionhouse-ui-sortarrow 9 x 9 a LEFT du texte (3, 0), retournee a
--     l'envers ;
--   mise en vente : l'onglet auctionhouse-selltab-left / -middle / -right (23
--     de haut) BOTTOMLEFT sur TOPLEFT (42, -3) du panneau, CREATE_AUCTION
--     (GameFontNormalSmall) a 12 ; l'objet sur auctionhouse-itemheaderframe
--     (342 x 72, le bouton de 54 a 12 du bord), la case vide
--     auctionhouse-itemicon-empty ; menus WowStyle1DropdownTemplate, champs
--     et cases de camelot.
--
-- CE QUI DIFFERE, ET POURQUOI. La structure de WotLK reste (choix de
-- l'utilisateur) : ses trois onglets, ses cadres, sa logique et ses places ;
-- la fenetre de camelot se pose sur le rectangle visible de l'art de 3.3.5,
-- les encadres autour des listes. Les lignes gardent toujours la largeur « avec
-- barre » : chez camelot la barre vit hors de l'encadre, la liste ne
-- s'elargit pas sans elle. Le choix d'une ligne se lit par
-- GetSelectedAuctionItem (le client verrouille aussi la surbrillance au survol
-- de l'icone). NE SONT PAS REPRIS : la cabine de l'hotel
-- (AuctionDressUpFrame), la barre de mise en vente multiple
-- (AuctionProgressFrame) et les fenetres de confirmation (StaticPopup).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local H = {}
ForeverUI.HotelDesVentes = H

local SEP = string.char(92)

-- les nombres dans le repere de AuctionFrame (ses onglets s'y calent aussi)
local N = {
	habit = { 12, -13, -2, 8 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	argent = { encart = { 2, 27, 167, 3 }, bord = { 5, 6, 158, 19 }, bourse = { 166, 8 } },
	onglet = { x = 20, y = -28, ecart = 3 },
	fond = 3,
	-- les encadres : haut-gauche et bas-droit
	categories = { 20, -99, 182, -409 },
	resultats = { 182, -81, 804, -409 },
	offres = { 23, -51, 804, -411 },
	vente = { 15, -68, 214, -411 },
	encheres = { 215, -50, 804, -411 },
	-- les barres (Gb.BarreA : x, haut, bas depuis la fenetre a defilement)
	barres = {
		BrowseFilterScrollFrame = { 5, 0, 7 },
		BrowseScrollFrame = { 12, -2, 9 },
		BidScrollFrame = { 11, -3, 5 },
		AuctionsScrollFrame = { 11, -4, 7 },
	},
	-- les lignes : largeur avec barre, surbrillance, derniere colonne
	lignes = {
		Browse = { nombre = 8, largeur = 600, lueur = 562, colonne = "BrowseCurrentBidSort", colonneL = 184,
			type = "list", defile = "BrowseScrollFrame", rayures = false },
		Bid = { nombre = 9, largeur = 769, lueur = 735, colonne = "BidBidSort", colonneL = 145,
			type = "bidder", defile = "BidScrollFrame", rayures = true },
		Auctions = { nombre = 9, largeur = 576, lueur = 543, colonne = "AuctionsBidSort", colonneL = 193,
			type = "owner", defile = "AuctionsScrollFrame", rayures = true },
	},
	decalageLigne = 2.5,
	icone = { cote = 37 },
	-- les categories : par type, fond / choix / survol (atlas, l, h, point, x, y)
	categorie = {
		class = {
			fond = { "auctionhouse-nav-button", 136, 32, "TOPLEFT", -2, 0 },
			choix = { "auctionhouse-nav-button-select", 132, 21, "LEFT", 0, 0 },
			survol = { "auctionhouse-nav-button-highlight", 132, 21, "LEFT", 0, 0, "BLEND" },
			texte = 8,
		},
		subclass = {
			fond = { "auctionhouse-nav-button-secondary", 133, 32, "TOPLEFT", 1, 0 },
			choix = { "auctionhouse-nav-button-secondary-select", 122, 21, "TOPLEFT", 10, 0 },
			survol = { "auctionhouse-nav-button-secondary-highlight", 122, 21, "TOPLEFT", 10, 0, "BLEND" },
			texte = 18,
		},
		invtype = {
			choix = { "auctionhouse-ui-row-select", 116, 18, "TOPRIGHT", 0, -2 },
			survol = { "auctionhouse-ui-row-highlight", 116, 18, "TOPRIGHT", 0, -2, "ADD" },
			texte = 26,
		},
		largeur = 132, trait = { 18, 3 },
	},
	fleche = { cote = 9, x = 3, y = 0 },
	-- les menus : « sur une ligne », a la hauteur des champs voisins (leur
	-- bord common-search-border : 20), en mode compact -- le fond rogne a sa
	-- boite, sans ombre qui deborde (28/09 : « cadres trop epais », deux
	-- fois) ; places de WotLK (Left / Middle / Right de
	-- UIDropDownMenuTemplate : 17 a 149 du bord), le menu Rarity centre sur la
	-- rangee des niveaux ; libelles et cases a leur ecart de 3.3.5
	menus = {
		hauteur = 20, compact = true,
		-- Rarity a 20 des champs de niveau (demande du 28/09 : « un espace
		-- entre Rarity et Level Range »), centre sur leur rangee ; son libelle
		-- sur la ligne de Level Range
		-- les deux cases rapprochees (demande du 28/09) : 19 de l'une a
		-- l'autre (22 en 3.3.5), la paire centree sur le menu
		parcourir = { largeur = 132, ecart = 20, libelle = { 3, 4 }, case = { 10, 9.5 }, pasCases = 19 },
		prix = { largeur = 97, droite = { 201, -219 }, libelle = { 25, -228 } },
		duree = { largeur = 97, droite = { 201, -330 }, libelle = { 25, -339 } },
	},
	-- les cases a cocher : l'art de camelot a la taille de la case visible
	-- de WotLK (UI-CheckBox, 23 x 21 de 32, sur 24 : 17), au centre
	caseCote = 17,
	ongletVente = { x = 42, y = -3, texte = 12 },
	objet = { gauche = -8, haut = 6, droite = 174, bas = -6, bout = 20 },
}

local ART = {
	marbre = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	argent = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	categories = "auctionhouse-background-categories",
	index = "auctionhouse-background-index",
	vente = "auctionhouse-background-sell-left",
	rayures = { "auctionhouse-rowstripe-1", "auctionhouse-rowstripe-2" },
	choix = "auctionhouse-ui-row-select",
	survol = "auctionhouse-ui-row-highlight",
	bordIcone = "auctionhouse-itemicon-small-border",
	fleche = "auctionhouse-ui-sortarrow",
	trait = "auctionhouse-nav-button-tertiary-filterline",
	caseVide = "auctionhouse-itemicon-empty",
	entete = "auctionhouse-itemheaderframe",
}

local TRIS = {
	"BrowseQualitySort", "BrowseLevelSort", "BrowseDurationSort", "BrowseHighBidderSort", "BrowseCurrentBidSort",
	"BidQualitySort", "BidLevelSort", "BidDurationSort", "BidBuyoutSort", "BidStatusSort", "BidBidSort",
	"AuctionsQualitySort", "AuctionsDurationSort", "AuctionsHighBidderSort", "AuctionsBidSort",
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- un element d'atlas a une taille donnee (les feuilles de l'hotel sont en
-- double densite : la taille de l'atlas n'est pas celle de camelot)
local function atlas(t, nom, l, h)
	ForeverUI.SetAtlas(t, nom, true)
	if l then t:SetWidth(l) end
	if h then t:SetHeight(h) end
end

-- ------------------------------------------------------------ les encadres

-- InsetFrameTemplate et son fond, en regions de l'onglet (sous ses cadres) :
-- r = { x1, y1, x2, y2 } depuis le TOPLEFT de l'onglet
local function encadre(hote, r, fond)
	local rect = CreateFrame("Frame", nil, hote)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", hote, "TOPLEFT", r[1], r[2])
	rect:SetPoint("BOTTOMRIGHT", hote, "TOPLEFT", r[3], r[4])
	local t = hote:CreateTexture(nil, "BACKGROUND")
	atlas(t, fond)
	t:SetPoint("TOPLEFT", rect, "TOPLEFT", N.fond, -N.fond)
	t:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", -N.fond, N.fond)
	return { rect = rect, fond = t, bord = Gb.NeufTranches(hote, "InsetFrameTemplate", rect) }
end

-- ThinGoldEdgeTemplate : Interface\Common\Moneyframe en trois morceaux
local function bordDore(f, rect)
	local function morceau(u1, u2, v1, v2)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ART.argent)
		t:SetTexCoord(u1, u2, v1, v2)
		return t
	end
	local g = morceau(0.953125, 0.9921875, 0, 0.296875)
	g:SetWidth(7)
	g:SetPoint("TOPLEFT", rect, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", rect, "BOTTOMLEFT")
	local d = morceau(0, 0.0546875, 0, 0.296875)
	d:SetWidth(7)
	d:SetPoint("TOPRIGHT", rect, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT")
	local m = morceau(0, 0.9921875, 0.3125, 0.609375)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	return { g, m, d }
end

-- l'argent : InsetFrameTemplate (marbre et lisere), bord dore, bourse
local function argent(habit)
	local A = N.argent
	local rect = CreateFrame("Frame", nil, habit)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", habit, "BOTTOMLEFT", A.encart[1], A.encart[2])
	rect:SetPoint("BOTTOMRIGHT", habit, "BOTTOMLEFT", A.encart[3], A.encart[4])
	local marbre = habit:CreateTexture(nil, "BACKGROUND")
	marbre:SetTexture(ART.marbre, true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(rect)
	local bord = CreateFrame("Frame", nil, habit)
	bord:EnableMouse(false)
	bord:SetWidth(A.bord[3])
	bord:SetHeight(A.bord[4])
	bord:SetPoint("BOTTOMLEFT", habit, "BOTTOMLEFT", A.bord[1], A.bord[2])
	poser(AuctionFrameMoneyFrame, "BOTTOMRIGHT", habit, "BOTTOMLEFT", A.bourse[1], A.bourse[2])
	return { encart = rect, marbre = marbre, encadre = Gb.NeufTranches(habit, "InsetFrameTemplate", rect),
		bord = bord, dore = bordDore(habit, bord) }
end

-- ------------------------------------------------------------ les categories

-- APRES FilterButton_SetType : l'art du niveau de la categorie
function H.PeindreCategorie(b, genre)
	local c = b.foreverCategorie
	local C = N.categorie[genre]
	if not c or not C then return end
	local plus = (b:GetWidth() or C.largeur) - N.categorie.largeur
	local fond = b:GetNormalTexture()
	if fond then
		fond:ClearAllPoints()
		if C.fond then
			atlas(fond, C.fond[1], C.fond[2] + plus, C.fond[3])
			fond:SetPoint(C.fond[4], b, C.fond[4], C.fond[5], C.fond[6])
			fond:SetAlpha(1)
		else
			fond:SetPoint("TOPLEFT", b, "TOPLEFT", 10, 0)
			fond:SetAlpha(0)
		end
	end
	for _, cle in ipairs({ "choix", "survol" }) do
		local e, t = C[cle], c[cle]
		atlas(t, e[1], e[2] + plus, e[3])
		poser(t, e[4], b, e[4], e[5], e[6])
		if e[7] then t:SetBlendMode(e[7]) end
	end
	local texte = _G[b:GetName() .. "NormalText"]
	if texte then poser(texte, "LEFT", b, "LEFT", C.texte, 0) end
	local trait = _G[b:GetName() .. "Lines"]
	if trait then
		atlas(trait, ART.trait, 5, 11)
		poser(trait, "LEFT", b, "LEFT", N.categorie.trait[1], N.categorie.trait[2])
	end
end

local function habillerCategorie(b)
	local c = {}
	c.survol = b:CreateTexture(nil, "BORDER")
	c.survol:Hide()
	c.choix = b:CreateTexture(nil, "ARTWORK")
	c.choix:SetBlendMode("ADD")
	c.choix:Hide()
	b.foreverCategorie = c
	-- la surbrillance du client, verrouillee a la selection : eteinte ; le
	-- choix et le survol de camelot la remplacent
	local h = b:GetHighlightTexture()
	if h then h:SetAlpha(0) end
	hooksecurefunc(b, "LockHighlight", function() c.choix:Show() end)
	hooksecurefunc(b, "UnlockHighlight", function() c.choix:Hide() end)
	b:HookScript("OnEnter", function() c.survol:Show() end)
	b:HookScript("OnLeave", function() c.survol:Hide() end)
	H.PeindreCategorie(b, b.type or "class")
end

-- ------------------------------------------------------------ les lignes

local function habillerLigne(b)
	local nom = b:GetName()
	for _, s in ipairs({ "Left", "Right", "Highlight" }) do
		local t = _G[nom .. s]
		if t then t:SetAlpha(0) end
	end
	-- le milieu sans nom du cadre de nom
	for _, r in ipairs({ b:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then
			local f = r:GetTexture()
			if type(f) == "string" and string.find(string.lower(f), "auctionitemnameframe", 1, true) then
				r:SetAlpha(0)
			end
		end
	end
	local l = {}
	local d = N.decalageLigne
	local function surLigne(t)
		t:SetPoint("TOPLEFT", b, "TOPLEFT", 0, d)
		t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, d)
		return t
	end
	l.rayure = surLigne(b:CreateTexture(nil, "BACKGROUND"))
	atlas(l.rayure, ART.rayures[1])
	l.rayure:Hide()
	l.choix = surLigne(b:CreateTexture(nil, "OVERLAY"))
	atlas(l.choix, ART.choix)
	l.choix:SetBlendMode("ADD")
	l.choix:Hide()
	l.survol = surLigne(b:CreateTexture(nil, "OVERLAY"))
	atlas(l.survol, ART.survol)
	l.survol:SetBlendMode("ADD")
	l.survol:Hide()
	-- l'icone : sans la case de WotLK, cerclee comme chez camelot
	local objet = _G[nom .. "Item"]
	if objet then
		for _, lire in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
			local t = objet[lire](objet)
			if t then t:SetAlpha(0) end
		end
		l.bord = objet:CreateTexture(nil, "OVERLAY")
		atlas(l.bord, ART.bordIcone, N.icone.cote, N.icone.cote)
		l.bord:SetPoint("CENTER", objet, "CENTER", 0, 0)
		objet:HookScript("OnEnter", function() l.survol:Show() end)
		objet:HookScript("OnLeave", function() l.survol:Hide() end)
	end
	b:HookScript("OnEnter", function() l.survol:Show() end)
	b:HookScript("OnLeave", function() l.survol:Hide() end)
	b.foreverLigne = l
end

-- APRES AuctionFrameBrowse_Update / Bid / Auctions : largeur « avec barre »,
-- choix, rayures
function H.MajLignes(cle)
	local L = N.lignes[cle]
	local decalage = FauxScrollFrame_GetOffset(_G[L.defile]) or 0
	local choisi = GetSelectedAuctionItem(L.type)
	for i = 1, L.nombre do
		local b = _G[cle .. "Button" .. i]
		local l = b and b.foreverLigne
		if l then
			b:SetWidth(L.largeur)
			local lueur = _G[cle .. "Button" .. i .. "Highlight"]
			if lueur then lueur:SetWidth(L.lueur) end
			Gb.Montrer(l.choix, choisi ~= nil and choisi == decalage + i)
			if L.rayures then
				atlas(l.rayure, ART.rayures[(decalage + i) % 2 == 1 and 1 or 2])
				l.rayure:Show()
			end
		end
	end
	local colonne = _G[L.colonne]
	if colonne then colonne:SetWidth(L.colonneL) end
end

-- ------------------------------------------------------------ les en-tetes

local function habillerTri(nom)
	local fleche = _G[nom .. "Arrow"]
	if not fleche then return end
	local F = N.fleche
	atlas(fleche, ART.fleche, F.cote, F.cote)
	local texte = _G[nom .. "Text"]
	if texte then poser(fleche, "LEFT", texte, "RIGHT", F.x, F.y) end
end

-- APRES SortButton_UpdateArrow : la fleche de camelot, retournee a l'envers
function H.PeindreFleche(bouton, genre)
	local fleche = bouton and _G[bouton:GetName() .. "Arrow"]
	if not fleche then return end
	local e = ForeverUI.AtlasEntry(ART.fleche)
	if not e then return end
	local _, inverse = GetAuctionSort(genre, 1)
	fleche:SetTexture(e[1])
	if inverse then
		fleche:SetTexCoord(e[2], e[3], e[5], e[4])
	else
		fleche:SetTexCoord(e[2], e[3], e[4], e[5])
	end
end

-- ------------------------------------------------------------ les menus

local function libelleDe(dd, texte)
	for _, r in ipairs({ dd:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == texte then
			return r
		end
	end
end

local function menus()
	local M = N.menus
	-- Parcourir : le menu a droite des niveaux, son libelle dessus, les cases
	local P = M.parcourir
	Gb.MenuStyle1(BrowseDropDown, P.largeur, M.hauteur, M.compact)
	poser(BrowseDropDown, "LEFT", BrowseMaxLevel, "RIGHT", P.ecart, 0)
	poser(BrowseDropDownName, "BOTTOMLEFT", BrowseDropDown, "TOPLEFT", P.libelle[1], P.libelle[2])
	poser(IsUsableCheckButton, "LEFT", BrowseDropDown, "RIGHT", P.case[1], P.case[2])
	poser(ShowOnPlayerCheckButton, "TOPLEFT", IsUsableCheckButton, "TOPLEFT", 0, -P.pasCases)
	-- Encheres : prix et duree, libelle a gauche, menu a droite
	for _, v in ipairs({ { PriceDropDown, AUCTION_PRICE, M.prix }, { DurationDropDown, AUCTION_DURATION, M.duree } }) do
		local dd, texte, R = v[1], v[2], v[3]
		local libelle = libelleDe(dd, texte)
		Gb.MenuStyle1(dd, R.largeur, M.hauteur, M.compact)
		poser(dd, "TOPRIGHT", AuctionFrameAuctions, "TOPLEFT", R.droite[1], R.droite[2])
		if libelle then poser(libelle, "LEFT", AuctionFrameAuctions, "TOPLEFT", R.libelle[1], R.libelle[2]) end
	end
end

-- ------------------------------------------------------------ la mise en vente

-- auctionhouse-itemheaderframe en trois morceaux : ses bouts arrondis
-- gardent leur rapport, le milieu s'etire
local function enteteObjet(hote, rect)
	local e = ForeverUI.AtlasEntry(ART.entete)
	if not e then return end
	local O = N.objet
	local hauteur = O.haut - O.bas + N.icone.cote
	local bout = O.bout * hauteur / 72
	local du = (e[3] - e[2]) * O.bout / 342
	local function morceau(u1, u2)
		local t = hote:CreateTexture(nil, "ARTWORK")
		t:SetTexture(e[1])
		t:SetTexCoord(u1, u2, e[4], e[5])
		return t
	end
	local g = morceau(e[2], e[2] + du)
	g:SetWidth(bout)
	g:SetPoint("TOPLEFT", rect, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", rect, "BOTTOMLEFT")
	local d = morceau(e[3] - du, e[3])
	d:SetWidth(bout)
	d:SetPoint("TOPRIGHT", rect, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT")
	local m = morceau(e[2] + du, e[3] - du)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	return { g, m, d }
end

local function miseEnVente(f)
	local habit = AuctionFrame.foreverHabit
	-- l'onglet « Creer une enchere » au-dessus du panneau
	local V = N.ongletVente
	local cadre = habit.vente.rect
	local g = f:CreateTexture(nil, "ARTWORK")
	atlas(g, "auctionhouse-selltab-left", 9, 23)
	g:SetPoint("BOTTOMLEFT", cadre, "TOPLEFT", V.x, V.y)
	AuctionsTabText:SetFontObject(GameFontNormalSmall)
	poser(AuctionsTabText, "LEFT", g, "RIGHT", V.texte, 0)
	local m = f:CreateTexture(nil, "BORDER")
	atlas(m, "auctionhouse-selltab-middle", nil, 23)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("RIGHT", AuctionsTabText, "RIGHT", V.texte, 0)
	local d = f:CreateTexture(nil, "BORDER")
	atlas(d, "auctionhouse-selltab-right", 9, 23)
	d:SetPoint("TOPLEFT", m, "TOPRIGHT", 0, 0)
	habit.ongletVente = { g, m, d }
	-- l'objet : sans la case de WotLK, sur le cadre d'objet de camelot
	local b = AuctionsItemButton
	for _, r in ipairs({ b:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local fichier = r:GetTexture()
			if type(fichier) == "string" and string.find(string.lower(fichier), "itemslot", 1, true) then
				r:SetAlpha(0)
			end
		end
	end
	local O = N.objet
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", b, "TOPLEFT", O.gauche, O.haut)
	rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", O.droite, O.bas)
	habit.objet = { rect = rect, entete = enteteObjet(f, rect) }
	local vide = b:CreateTexture(nil, "BACKGROUND")
	atlas(vide, ART.caseVide)
	vide:SetAllPoints(b)
	habit.objet.vide = vide
end

-- ------------------------------------------------------------ les onglets

function H.MajOnglets()
	local S = ForeverUI.Social
	for i, o in ipairs(H.onglets or {}) do
		S.choisirOnglet(o, AuctionFrame.selectedTab == i, true)
		o:SetWidth(S.largeurOnglet(o))
	end
	-- le titre : celui de l'onglet du client montre
	local habit = AuctionFrame.foreverHabit
	if habit then
		for _, v in ipairs({ { AuctionFrameBrowse, BrowseTitle }, { AuctionFrameBid, BidTitle },
			{ AuctionFrameAuctions, AuctionsTitle } }) do
			if v[1]:IsShown() then habit.titre:SetText(v[2]:GetText() or "") end
		end
	end
end

local function onglets(habit)
	local S, O = ForeverUI.Social, N.onglet
	H.onglets = {}
	for i, texte in ipairs({ BROWSE, BIDS, AUCTIONS }) do
		local o = S.creerOnglet(habit, "ForeverUIAuctionTab" .. i, false)
		o:SetText(texte)
		if i == 1 then
			o:SetPoint("BOTTOMLEFT", habit, "BOTTOMLEFT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", H.onglets[i - 1], "TOPRIGHT", O.ecart, 0)
		end
		o:SetScript("OnClick", function()
			AuctionFrameTab_OnClick(_G["AuctionFrameTab" .. i])
		end)
		H.onglets[i] = o
		ForeverUI.Suppress(_G["AuctionFrameTab" .. i])
	end
end

-- ------------------------------------------------------------ la fenetre

function H.Habiller()
	local f = AuctionFrame
	if not f or f.foreverHabit then return end

	-- l'art de 3.3.5, les titres des onglets (repris dans la barre de titre)
	for _, r in ipairs({ AuctionPortraitTexture, AuctionFrameTopLeft, AuctionFrameTop, AuctionFrameTopRight,
		AuctionFrameBotLeft, AuctionFrameBot, AuctionFrameBotRight, BrowseTitle, BidTitle, AuctionsTitle }) do
		r:SetAlpha(0)
	end

	-- la fenetre de camelot, sur le rectangle visible de l'art de 3.3.5
	local Hb = N.habit
	local cadre = CreateFrame("Frame", nil, f)
	cadre:SetFrameLevel(f:GetFrameLevel())
	cadre:EnableMouse(false)
	cadre:SetPoint("TOPLEFT", f, "TOPLEFT", Hb[1], Hb[2])
	cadre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", Hb[3], Hb[4])
	local habit = Gb.FenetrePortrait(cadre, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = BrowseTitle:GetText(),
	})
	habit.cadre = cadre
	f.foreverHabit = habit
	f:HookScript("OnShow", function() SetPortraitTexture(habit.portrait, "npc") end)
	Gb.Croix(AuctionFrameCloseButton, cadre)
	AuctionFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	habit.argent = argent(cadre)

	-- les encadres, en regions de chaque onglet
	habit.categories = encadre(AuctionFrameBrowse, N.categories, ART.categories)
	habit.resultats = encadre(AuctionFrameBrowse, N.resultats, ART.index)
	habit.offres = encadre(AuctionFrameBid, N.offres, ART.index)
	habit.vente = encadre(AuctionFrameAuctions, N.vente, ART.vente)
	habit.encheres = encadre(AuctionFrameAuctions, N.encheres, ART.index)

	-- les barres : celles du client, a la place et a l'art de camelot
	for nom, B in pairs(N.barres) do
		local fx = _G[nom]
		for _, r in ipairs({ fx:GetRegions() }) do
			if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
		end
		Gb.BarreA(_G[nom .. "ScrollBar"], fx, B[1], B[2], B[3])
	end

	-- les categories, les lignes, les en-tetes
	-- chaque categorie au-dessus de la precedente : l'ombre de son art (11
	-- sous le bouton) tombe sur la suivante, et deux cadres au meme niveau
	-- se dessinent dans un ordre qui change quand la liste se refait -- des
	-- boutons paraissaient enfonces selon la selection (28/09)
	local niveau = AuctionFilterButton1:GetFrameLevel()
	for i = 1, NUM_FILTERS_TO_DISPLAY do
		local b = _G["AuctionFilterButton" .. i]
		b:SetFrameLevel(niveau + i - 1)
		habillerCategorie(b)
	end
	hooksecurefunc("FilterButton_SetType", H.PeindreCategorie)
	for cle, L in pairs(N.lignes) do
		for i = 1, L.nombre do
			habillerLigne(_G[cle .. "Button" .. i])
		end
	end
	hooksecurefunc("AuctionFrameBrowse_Update", function() H.MajLignes("Browse") end)
	hooksecurefunc("AuctionFrameBid_Update", function() H.MajLignes("Bid") end)
	hooksecurefunc("AuctionFrameAuctions_Update", function() H.MajLignes("Auctions") end)
	for cle in pairs(N.lignes) do H.MajLignes(cle) end
	for _, nom in ipairs(TRIS) do habillerTri(nom) end
	hooksecurefunc("SortButton_UpdateArrow", H.PeindreFleche)

	-- champs, cases, menus
	local S = ForeverUI.Social
	for _, champ in ipairs({ BrowseName, BrowseMinLevel, BrowseMaxLevel, AuctionsStackSizeEntry, AuctionsNumStacksEntry }) do
		S.habillerSaisie(champ)
	end
	for _, c in ipairs({ IsUsableCheckButton, ShowOnPlayerCheckButton }) do
		S.habillerCase(c)
		for _, lire in ipairs({ "GetNormalTexture", "GetCheckedTexture", "GetDisabledCheckedTexture", "GetPushedTexture" }) do
			local t = c[lire] and c[lire](c)
			if t then
				t:ClearAllPoints()
				t:SetWidth(N.caseCote)
				t:SetHeight(N.caseCote)
				t:SetPoint("CENTER", c, "CENTER", 0, 0)
			end
		end
	end
	menus()
	miseEnVente(AuctionFrameAuctions)

	-- les onglets du bas, et le titre qui suit l'onglet
	onglets(cadre)
	hooksecurefunc("AuctionFrameTab_OnClick", H.MajOnglets)
	H.MajOnglets()
end

H.Habiller()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(_, _, nom)
	if nom == "Blizzard_AuctionUI" then
		H.Habiller()
	end
end)
