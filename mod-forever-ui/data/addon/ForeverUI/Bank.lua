-- ForeverUI : la banque (BankFrame), a la DA de camelot (demande de
-- l'utilisateur, 2026-09-28 : « fait le reste du commerce »).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (BankFrame.xml / .lua de 3.3.5,
-- FrameXML) :
--   BankFrame 425 x 512 a TOPLEFT (0, -104) : BankPortraitTexture (7, -6),
--     l'art UI-BankFrame (sans nom), BankFrameTitleText (le nom du
--     banquier), les textes ITEMSLOTTEXT et BAGSLOTTEXT (sans nom),
--     BankCloseButton ; BankFrameItem1..28 (BankItemButtonGenericTemplate)
--     en 7 x 4 depuis (40, -73) ; BankFrameBag1..7 (BankItemButtonBag-
--     Template) : un clic ouvre le sac dans sa propre fenetre ;
--     BankFramePurchaseInfo (texte BANKSLOTPURCHASE_LABEL, BankFrameSlotCost,
--     BankFrameDetailMoneyFrame, BankFramePurchaseButton), cache quand tout
--     est achete (UpdateBagSlotStatus) ; BankFrameMoneyFrame (-30, 103).
--
-- RELEVE -- CAMELOT (blizzard_uipanels_game/camelot/bankframe.xml / .lua,
-- mainline/bankframetemplates.xml / .lua) :
--   BankFrame (BankFrameTemplate : PortraitFrameTemplate) : portrait du
--     banquier, titre BANK ; fond bank-frame-background de (0, -20) a
--     (0, 30) ; le panneau BankPanel 480 de large, son lisere
--     InsetFrameTemplate et ses ombres bank-frame-shadow-* (coins 46 a (2,
--     -22), (2, 2), (-3, -22), (-3, 2)) sur la meme etendue ; la fenetre
--     prend la taille du panneau : 460 de haut, plus 47 par rangee au-dela de
--     six (GenerateItemSlotsForSelectedTab) ;
--   LES CASES : la banque et ses sacs dans UNE grille (ShouldUsePlayerBags-
--     InBank), 8 colonnes, la premiere case a (47, -63), 13 entre deux, 10
--     entre deux rangees, 88 cases par page ; case CamelotBankItemButton-
--     Template : fond bags-item-bankslot64, cadre bank-frame-item-slotframe
--     (vide) ou bank-frame-bag-slotframe (plein), contour de qualite ;
--   les pages : BankPageTabTemplate (LargeSideTabButtonTemplate) a TOPLEFT
--     sur TOPRIGHT (3, -60), les suivantes dessous (0, -2), icones
--     INV_SideTab_Bank_c60, ACHIEVEMENT_GUILDPERK_MOBILEBANKING,
--     TRADE_ARCHAEOLOGY_CHESTOFTINYGLASSANIMALS, Ability_Racial_PackHobgoblin,
--     infobulle PAGE_NUMBER ;
--   les sacs : BagText (BAGSLOTTEXT_COLON) BOTTOMLEFT (43, 80) ; les
--     boutons a l'echelle 0,75 (bank-frame-bag-slotframe, fond
--     bank-frame-bag-slot-bg, cadenas bankslot-icon-lock tant qu'il n'est
--     pas achete), le premier a (20, 5) du haut droit du texte, les suivants
--     a +50 ; un clic prend ou pose le sac, sans ouvrir de fenetre ;
--   BagCost (COSTS_LABEL) BOTTOMLEFT (101, 45), son prix (8, 0) a sa droite,
--     le bouton d'achat 124 x 21 (8, 4) a droite du prix ; le filet
--     bank-divider a l'echelle 0,48, BOTTOM (0, 220) ;
--   BankItemSearchBox 110 x 20 TOPRIGHT (-56, -33), le tri 28 x 26 a sa
--     droite (8, -1) ; l'argent (BankPanelMoneyFrameTemplate, 180 x 25 sans
--     les virements) BOTTOMRIGHT (-3, 3) : bord dore 178 x 19 a gauche, la
--     bourse a sa droite.
--
-- CE QUI DIFFERE, ET POURQUOI. Les 28 cases du client restent les
-- siennes ; les cases des sacs de banque sont des ContainerFrameItemButton-
-- Template (clics, infobulles, partage de pile : ceux du client) dans un
-- porteur par sac. Le portrait suit la regle VALIDEE (48, centre sur le trou
-- de l'anneau). La recherche suit la regle des sacs, VALIDEE (nom, type,
-- sous-type), avec son propre champ ; le tri est celui des sacs
-- (ForeverUI.BagSort), sur la banque et ses sacs. Pas d'onglet de banque de bataillon : 3.3.5 n'en a pas.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits
local L = ForeverUI.L

local B = { page = 1, porteurs = {} }
ForeverUI.Banque = B

local SEP = string.char(92)

local N = {
	largeur = 480, hauteurBase = 460, rangee = 47, rangsBase = 6,
	colonnes = 8, premier = { 47, -63 }, ecartX = 13, ecartY = 10, case = 37, parPage = 88,
	fond = { 0, -20, 0, 30 },
	ombres = { hg = { 2, -22 }, bg = { 2, 2 }, hd = { -3, -22 }, bd = { -3, 2 }, epaisseur = 17,
		tranches = { cote = { 0.015625, 0.28125 }, bas = { 0.015625, 0.28125 }, haut = { 0.3125, 0.578125 } } },
	onglet = { x = 3, y = -60, ecart = -2, cote = 55, icone = 50, iconeX = -3, rognage = 0.03125 },
	recherche = { -56, -33, 110, 20 }, tri = { 8, -1, 28, 26 },
	argent = { boite = { -3, 3, 180, 25 }, bord = { 178, 19 } },
	sacs = { texte = { 43, 80 }, premier = { 20, 5 }, pas = 50, echelle = 0.75 },
	cout = { 101, 45, 8, 0 }, achat = { 8, 4, 124, 21 },
	filet = { echelle = 0.48, y = 220 },
	portrait = { cote = 48, x = 1, y = 1.5 },
}

local ART = {
	fond = "bank-frame-background",
	caseVide = "bank-frame-item-slotframe", casePleine = "bank-frame-bag-slotframe",
	fondCase = "bags-item-bankslot64",
	fondSac = "bank-frame-bag-slot-bg", cadenas = "bankslot-icon-lock",
	filet = "bank-divider",
	argent = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	onglet = "common-sidetab", ongletActif = "common-sidetab-selected", ongletSurvol = "common-sidetab-hover",
	pages = {
		"Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP .. "Inv_SideTab_Bank_c60",
		"Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP .. "Achievement_GuildPerk_MobileBanking",
		"Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP .. "Trade_Archaeology_ChestOfTinyGlassAnimals",
		"Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP .. "Ability_Racial_PackHobgoblin",
	},
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- les sacs de la banque : la banque elle-meme, puis ses sept sacs
local function sacsDeBanque()
	local sacs = { BANK_CONTAINER }
	for sac = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
		sacs[#sacs + 1] = sac
	end
	return sacs
end

-- ------------------------------------------------------------ une case

-- CamelotBankItemButtonTemplate : fond bags-item-bankslot64, cadre posee a
-- la taille du bouton, l'art de 3.3.5 retire
local function habillerCase(b)
	if b.foreverCase then return end
	local fond = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, ART.fondCase)
	fond:SetAllPoints(b)
	local e = ForeverUI.AtlasEntry(ART.caseVide)
	b:SetNormalTexture(e[1])
	local cadre = b:GetNormalTexture()
	cadre:ClearAllPoints()
	cadre:SetAllPoints(b)
	b.foreverCase = { fond = fond, cadre = cadre }
end

-- CamelotBankPanelItemButtonMixin:Refresh : le cadre plein ou vide
local function cadreCase(b, plein)
	local c = b.foreverCase and b:GetNormalTexture()
	if c then ForeverUI.SetAtlas(c, plein and ART.casePleine or ART.caseVide) end
end

-- une case d'un sac de banque : une ContainerFrameItemButtonTemplate dans le
-- porteur du sac (son ID est celui du sac : les scripts du client le lisent)
local function caseDeSac(sac, i)
	local p = B.porteurs[sac]
	if not p then
		p = CreateFrame("Frame", "ForeverUIBankBag" .. sac, BankFrame)
		p:SetID(sac)
		p:SetAllPoints(BankFrame)
		p.cases = {}
		B.porteurs[sac] = p
	end
	local b = p.cases[i]
	if not b then
		b = CreateFrame("Button", "ForeverUIBankBag" .. sac .. "Item" .. i, p, "ContainerFrameItemButtonTemplate")
		b:SetID(i)
		habillerCase(b)
		p.cases[i] = b
	end
	return b
end

local function caseDe(sac, i)
	if sac == BANK_CONTAINER then
		return _G["BankFrameItem" .. i]
	end
	return caseDeSac(sac, i)
end

-- une case de sac : image, nombre, verrou, qualite, recharge
local function majCase(b, sac, i)
	local texture, nombre, verrou, qualite = GetContainerItemInfo(sac, i)
	SetItemButtonTexture(b, texture)
	SetItemButtonCount(b, nombre)
	SetItemButtonDesaturated(b, verrou, 0.5, 0.5, 0.5)
	b.hasItem = texture and 1 or nil
	Gb.ContourQualite(b, texture and qualite or nil)
	cadreCase(b, texture ~= nil)
	if ContainerFrame_UpdateCooldown then ContainerFrame_UpdateCooldown(sac, b) end
	B.marquer(b, GetContainerItemLink(sac, i))
end

-- la regle de la recherche des sacs (Recherche.Correspond, Bags.lua) : le
-- nom, le type ou le sous-type contient le texte, sans casse ; le nom se lit
-- dans le lien quand le client ne l'a pas en cache
local function correspond(lien, texte)
	if texte == "" then return true end
	if not lien then return false end
	local nom, _, _, _, _, type_, sousType = GetItemInfo(lien)
	nom = nom or string.match(lien, "%[(.+)%]")
	texte = string.lower(texte)
	for _, c in ipairs({ nom, type_, sousType }) do
		if c and string.find(string.lower(c), texte, 1, true) then return true end
	end
	return false
end

-- le voile noir a 80 % sur ce qui ne correspond pas
function B.marquer(b, lien)
	local voile = b.foreverVoile
	if not voile then
		voile = b:CreateTexture(nil, "OVERLAY")
		voile:SetTexture(0, 0, 0, 0.8)
		voile:SetAllPoints(b)
		voile:Hide()
		b.foreverVoile = voile
	end
	local texte = B.champ and B.champ:GetText() or ""
	Gb.Montrer(voile, texte ~= "" and lien ~= nil and not correspond(lien, texte))
end

-- ------------------------------------------------------------ la grille

-- toutes les cases, dans l'ordre de la grille : la banque, puis ses sacs
local function toutesLesCases()
	local cases = {}
	for _, sac in ipairs(sacsDeBanque()) do
		local n = (sac == BANK_CONTAINER) and NUM_BANKGENERIC_SLOTS or (GetContainerNumSlots(sac) or 0)
		for i = 1, n do
			cases[#cases + 1] = { sac = sac, i = i }
		end
	end
	return cases
end

-- GenerateItemSlotsForSelectedTab : la page, la hauteur, les places
function B.Disposer()
	local f = BankFrame
	if not f or not f.foreverHabit then return end
	local cases = toutesLesCases()
	local pages = math.max(1, math.ceil(#cases / N.parPage))
	B.pages = pages
	if B.page > pages then B.page = pages end
	if B.page < 1 then B.page = 1 end
	local debut = (B.page - 1) * N.parPage
	local affichees = math.min(N.parPage, #cases - debut)
	local rangs = math.ceil(affichees / N.colonnes)
	f:SetHeight(N.hauteurBase + math.max(0, rangs - N.rangsBase) * N.rangee)
	-- tout se cache, puis la page se pose
	for i = 1, NUM_BANKGENERIC_SLOTS do _G["BankFrameItem" .. i]:Hide() end
	for _, p in pairs(B.porteurs) do
		for _, b in pairs(p.cases) do b:Hide() end
	end
	local pasX, pasY = N.case + N.ecartX, N.case + N.ecartY
	for k = debut + 1, debut + affichees do
		local c = cases[k]
		local b = caseDe(c.sac, c.i)
		local n = k - debut - 1
		poser(b, "TOPLEFT", f, "TOPLEFT", N.premier[1] + (n % N.colonnes) * pasX,
			N.premier[2] - math.floor(n / N.colonnes) * pasY)
		b:Show()
		if c.sac ~= BANK_CONTAINER then
			majCase(b, c.sac, c.i)
		else
			B.ApresCaseBanque(b)
		end
	end
	B.MajOnglets()
end

-- APRES BankFrameItemButton_Update : la qualite et le cadre d'une case de
-- la banque (les sacs ont les leurs, plus bas)
function B.ApresCaseBanque(b)
	if not b or b.isBag or not b.foreverCase then return end
	local _, _, _, qualite = GetContainerItemInfo(BANK_CONTAINER, b:GetID())
	local lien = GetContainerItemLink(BANK_CONTAINER, b:GetID())
	Gb.ContourQualite(b, lien and qualite or nil)
	cadreCase(b, lien ~= nil)
	B.marquer(b, lien)
end

-- ------------------------------------------------------------ les pages

function B.MajOnglets()
	for i, o in ipairs(B.onglets or {}) do
		Gb.Montrer(o, (B.pages or 1) >= i)
		Gb.Montrer(o.actif, B.page == i)
	end
end

local function onglets(f)
	local O = N.onglet
	B.onglets = {}
	for i, icone in ipairs(ART.pages) do
		local o = CreateFrame("Button", "ForeverUIBankPageTab" .. i, f)
		o:SetWidth(O.cote)
		o:SetHeight(O.cote)
		if i == 1 then
			o:SetPoint("TOPLEFT", f, "TOPRIGHT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", B.onglets[i - 1], "BOTTOMLEFT", 0, O.ecart)
		end
		local fond = o:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(fond, ART.onglet, true)
		fond:SetAllPoints(o)
		local image = o:CreateTexture(nil, "ARTWORK")
		image:SetWidth(O.icone)
		image:SetHeight(O.icone)
		image:SetPoint("CENTER", o, "CENTER", O.iconeX, 0)
		image:SetTexCoord(O.rognage, 1 - O.rognage, O.rognage, 1 - O.rognage)
		image:SetTexture(icone)
		local actif = o:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(actif, ART.ongletActif, true)
		actif:SetAllPoints(o)
		actif:Hide()
		local survol = o:CreateTexture(nil, "HIGHLIGHT")
		ForeverUI.SetAtlas(survol, ART.ongletSurvol, true)
		survol:SetAllPoints(o)
		o.icone, o.actif = image, actif
		o:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(string.format(PAGE_NUMBER, i))
			GameTooltip:Show()
		end)
		o:SetScript("OnLeave", function() GameTooltip:Hide() end)
		o:SetScript("OnClick", function()
			PlaySound("igCharacterInfoTab")
			B.page = i
			B.Disposer()
		end)
		o:Hide()
		B.onglets[i] = o
	end
end

-- ------------------------------------------------------------ les sacs

-- APRES UpdateBagSlotStatus : le cadenas des sacs non achetes, pas de
-- teinte rouge (camelot montre le cadenas)
function B.ApresSacs()
	local achetes = GetNumBankSlots()
	for i = 1, NUM_BANKBAGSLOTS do
		local b = _G["BankFrameBag" .. i]
		if b and b.foreverCadenas then
			SetItemButtonTextureVertexColor(b, 1, 1, 1)
			Gb.Montrer(b.foreverCadenas, i > achetes)
		end
	end
end

-- BankItemButtonBagMixin:OnClick : prendre ou poser le sac, sans fenetre.
-- Camelot fait C_Container.PickupContainerItem, qui pose ce que tient le
-- curseur ; en 3.3.5, poser se fait par PutItemInBag (ce que fait
-- BankFrameItemButtonBag_OnClick), prendre par PickupBagFromSlot -- le
-- clic ne faisait que prendre : un sac tenu ne se posait pas (constate en
-- jeu le 28/09).
local function clicSac(self)
	if self:GetID() - NUM_BAG_SLOTS > GetNumBankSlots() then return end
	local emplacement = self:GetInventorySlot()
	if CursorHasItem() then
		PutItemInBag(emplacement)
	else
		PickupBagFromSlot(emplacement)
	end
end

local function sacs(f)
	local S = N.sacs
	local texte = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	texte:SetText(string.format(L.BANK_COLON, BAGSLOTTEXT))
	texte:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", S.texte[1], S.texte[2])
	B.texteSacs = texte
	for i = 1, NUM_BANKBAGSLOTS do
		local b = _G["BankFrameBag" .. i]
		b:SetScale(S.echelle)
		if i == 1 then
			poser(b, "TOPLEFT", texte, "TOPRIGHT", S.premier[1], S.premier[2])
		else
			poser(b, "TOPLEFT", _G["BankFrameBag" .. (i - 1)], "TOPLEFT", S.pas, 0)
		end
		local fond = b:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(fond, ART.fondSac)
		fond:SetAllPoints(b)
		local e = ForeverUI.AtlasEntry(ART.casePleine)
		b:SetNormalTexture(e[1])
		local cadre = b:GetNormalTexture()
		ForeverUI.SetAtlas(cadre, ART.casePleine)
		cadre:ClearAllPoints()
		cadre:SetAllPoints(b)
		local cadenas = b:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(cadenas, ART.cadenas)
		cadenas:SetAllPoints(b)
		cadenas:Hide()
		b.foreverCadenas = cadenas
		b:SetScript("OnClick", clicSac)
		-- lacher un sac dessus : le meme geste (le client ouvrirait le sac
		-- quand le curseur est vide)
		b:SetScript("OnReceiveDrag", clicSac)
	end
	hooksecurefunc("UpdateBagSlotStatus", B.ApresSacs)
end

-- APRES BankFrameItemButton_Update : un sac vide n'a pas d'icone (le fond de
-- case parle pour lui)
local function apresBouton(b)
	if not b then return end
	if b.isBag then
		if not b.hasItem then _G[b:GetName() .. "IconTexture"]:Hide() end
	else
		B.ApresCaseBanque(b)
	end
end

-- ------------------------------------------------------------ l'achat, l'argent, les outils

-- le prix d'un sac, le bouton d'achat : les pieces du client, a leur place
local function achat(f)
	local C, A = N.cout, N.achat
	for _, r in ipairs({ BankFramePurchaseInfo:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == BANKSLOTPURCHASE_LABEL then
			r:SetAlpha(0)
		end
	end
	poser(BankFrameSlotCost, "BOTTOMLEFT", f, "BOTTOMLEFT", C[1], C[2])
	poser(BankFrameDetailMoneyFrame, "TOPLEFT", BankFrameSlotCost, "TOPRIGHT", C[3], C[4])
	BankFramePurchaseButton:SetWidth(A[3])
	BankFramePurchaseButton:SetHeight(A[4])
	poser(BankFramePurchaseButton, "TOPLEFT", BankFrameDetailMoneyFrame, "TOPRIGHT", A[1], A[2])
	-- le filet, a l'echelle de camelot : sa place aussi
	local filet = f:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(filet, ART.filet, true)
	local e = ForeverUI.AtlasEntry(ART.filet)
	filet:SetWidth(e[6] * N.filet.echelle)
	filet:SetHeight(e[7] * N.filet.echelle)
	filet:SetPoint("BOTTOM", f, "BOTTOM", 0, N.filet.y * N.filet.echelle)
	B.filet = filet
end

local function argent(f)
	local A = N.argent
	local boite = CreateFrame("Frame", nil, f)
	boite:EnableMouse(false)
	boite:SetWidth(A.boite[3])
	boite:SetHeight(A.boite[4])
	boite:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", A.boite[1], A.boite[2])
	local bord = CreateFrame("Frame", nil, boite)
	bord:SetWidth(A.bord[1])
	bord:SetHeight(A.bord[2])
	bord:SetPoint("LEFT", boite, "LEFT", 0, 0)
	local function morceau(u1, u2, v1, v2)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ART.argent)
		t:SetTexCoord(u1, u2, v1, v2)
		return t
	end
	local g = morceau(0.953125, 0.9921875, 0, 0.296875)
	g:SetWidth(7)
	g:SetPoint("TOPLEFT", bord, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", bord, "BOTTOMLEFT")
	local d = morceau(0, 0.0546875, 0, 0.296875)
	d:SetWidth(7)
	d:SetPoint("TOPRIGHT", bord, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", bord, "BOTTOMRIGHT")
	local m = morceau(0, 0.9921875, 0.3125, 0.609375)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	poser(BankFrameMoneyFrame, "RIGHT", bord, "RIGHT", 0, 0)
	B.boiteArgent, B.bordArgent = boite, bord
end

-- BankItemSearchBox (BagSearchBoxTemplate) : le champ des sacs, VALIDE, refait
-- ici ; et le tri a sa droite
local function outils(f)
	local R = N.recherche
	local champ = CreateFrame("EditBox", "ForeverUIBankSearchBox", f, "InputBoxTemplate")
	champ:SetWidth(R[3])
	champ:SetHeight(R[4])
	champ:SetAutoFocus(false)
	champ:SetMaxLetters(15)
	champ:SetTextInsets(16, 20, 0, 0)
	champ:SetPoint("TOPRIGHT", f, "TOPRIGHT", R[1], R[2])
	local loupe = champ:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(loupe, "common-search-magnifyingglass", true)
	loupe:SetWidth(10)
	loupe:SetHeight(10)
	loupe:SetPoint("LEFT", champ, "LEFT", 1, -1)
	local invite = champ:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	invite:SetPoint("LEFT", champ, "LEFT", 16, 0)
	invite:SetText(SEARCH)
	local function maj()
		local texte = champ:GetText() or ""
		Gb.Montrer(invite, texte == "" and not champ:HasFocus())
		for _, p in pairs(B.porteurs) do
			for i, b in pairs(p.cases) do
				if b:IsShown() then B.marquer(b, GetContainerItemLink(p:GetID(), i)) end
			end
		end
		for i = 1, NUM_BANKGENERIC_SLOTS do
			B.marquer(_G["BankFrameItem" .. i], GetContainerItemLink(BANK_CONTAINER, i))
		end
	end
	champ:SetScript("OnTextChanged", maj)
	champ:SetScript("OnEditFocusGained", maj)
	champ:SetScript("OnEditFocusLost", maj)
	champ:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	champ:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	champ:HookScript("OnHide", function(self) self:SetText("") end)
	B.champ = champ

	local T = N.tri
	local tri = CreateFrame("Button", "ForeverUIBankSortButton", f)
	tri:SetWidth(T[3])
	tri:SetHeight(T[4])
	tri:SetPoint("LEFT", champ, "RIGHT", T[1], T[2])
	for _, v in ipairs({ { "SetNormalTexture", "GetNormalTexture", "bags-button-autosort-up" },
		{ "SetPushedTexture", "GetPushedTexture", "bags-button-autosort-down" } }) do
		local e = ForeverUI.AtlasEntry(v[3])
		if e then
			tri[v[1]](tri, e[1])
			local t = tri[v[2]](tri)
			ForeverUI.SetAtlas(t, v[3])
			t:ClearAllPoints()
			t:SetAllPoints(tri)
		end
	end
	tri:SetHighlightTexture("Interface" .. SEP .. "Buttons" .. SEP .. "ButtonHilight-Square")
	tri:GetHighlightTexture():SetBlendMode("ADD")
	tri:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.BAGS_CLEANUP, 1, 1, 1)
		GameTooltip:Show()
	end)
	tri:SetScript("OnLeave", function() GameTooltip:Hide() end)
	tri:SetScript("OnClick", function()
		ForeverUI.BagSort.Lancer(sacsDeBanque())
	end)
	B.tri = tri
end

-- ------------------------------------------------------------ la fenetre

-- les evenements des sacs de banque, la fenetre ouverte
local veille = CreateFrame("Frame")
veille:SetScript("OnEvent", function(_, evenement, sac, emplacement)
	if not BankFrame or not BankFrame:IsShown() then return end
	if evenement == "BAG_UPDATE" and sac and sac > NUM_BAG_SLOTS then
		local p = B.porteurs[sac]
		local n = GetContainerNumSlots(sac) or 0
		if not p or n ~= (p.nombre or 0) then
			if p then p.nombre = n end
			B.Disposer()
		else
			for i, b in pairs(p.cases) do
				if b:IsShown() then majCase(b, sac, i) end
			end
		end
	elseif evenement == "ITEM_LOCK_CHANGED" and sac and sac > NUM_BAG_SLOTS then
		local p = B.porteurs[sac]
		local b = p and p.cases[emplacement]
		if b and b:IsShown() then majCase(b, sac, emplacement) end
	elseif evenement == "PLAYERBANKBAGSLOTS_CHANGED" or evenement == "BAG_UPDATE_COOLDOWN" then
		B.Disposer()
	end
end)
for _, e in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "BAG_UPDATE_COOLDOWN" }) do
	veille:RegisterEvent(e)
end

function B.Habiller()
	local f = BankFrame
	if not f or f.foreverHabit then return end
	-- l'art de 3.3.5 : l'art et les textes sans nom, le portrait, le titre
	for _, r in ipairs({ f:GetRegions() }) do
		if not r:GetName() then r:SetAlpha(0) end
	end
	BankPortraitTexture:SetAlpha(0)
	BankFrameTitleText:SetAlpha(0)
	f:SetWidth(N.largeur)
	f:SetHeight(N.hauteurBase)
	f:SetHitRectInsets(0, 0, 0, 0)
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y, titre = L.BANK_TITLE,
	})
	f.foreverHabit = habit
	-- le fond, le lisere du panneau et ses ombres, sur la meme etendue
	local F = N.fond
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", F[1], F[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", F[3], F[4])
	local fond = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, ART.fond)
	fond:SetAllPoints(rect)
	habit.fondBanque, habit.panneau = fond, rect
	habit.lisere = Gb.NeufTranches(f, "InsetFrameTemplate", rect)
	-- les ombres : coins a la taille de l'atlas (useAtlasSize), bords de 17
	-- dans une tranche de leur atlas (TexCoords de camelot, relatifs a
	-- l'atlas) -- sans taille, le client 3.3.5 dessine une texture a la
	-- taille de sa feuille entiere (constate le 28/09 sur l'echange)
	local O = N.ombres
	local coins = {}
	for cle, v in pairs({ hg = { "TOPLEFT", "cornertopleft" }, bg = { "BOTTOMLEFT", "cornerbottomleft" },
		hd = { "TOPRIGHT", "cornertopright" }, bd = { "BOTTOMRIGHT", "cornerbottomright" } }) do
		local t = f:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, "bank-frame-shadow-" .. v[2])
		t:SetPoint(v[1], f, v[1], O[cle][1], O[cle][2])
		coins[cle] = t
	end
	local function bord(atlas, tranche, vertical, a1, c1, r1, a2, c2, r2)
		local t = f:CreateTexture(nil, "BORDER")
		local e = ForeverUI.AtlasEntry(atlas)
		t:SetTexture(e[1])
		local du, dv = e[3] - e[2], e[5] - e[4]
		if vertical then
			t:SetTexCoord(e[2] + du * tranche[1], e[2] + du * tranche[2], e[4], e[5])
			t:SetWidth(O.epaisseur)
		else
			t:SetTexCoord(e[2], e[3], e[4] + dv * tranche[1], e[4] + dv * tranche[2])
			t:SetHeight(O.epaisseur)
		end
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
		return t
	end
	local T = O.tranches
	habit.ombres = {
		coins = coins,
		droite = bord("!bank-frame-vert-shadow", T.cote, true, "TOPRIGHT", coins.hd, "BOTTOMRIGHT", "BOTTOMRIGHT", coins.bd, "TOPRIGHT"),
		gauche = bord("!bank-frame-vert-shadow", T.cote, true, "TOPLEFT", coins.hg, "BOTTOMLEFT", "BOTTOMLEFT", coins.bg, "TOPLEFT"),
		bas = bord("_bank-frame-horiz-shadow", T.bas, false, "BOTTOMLEFT", coins.bg, "BOTTOMRIGHT", "BOTTOMRIGHT", coins.bd, "BOTTOMLEFT"),
		haut = bord("_bank-frame-horiz-shadow", T.haut, false, "TOPLEFT", coins.hg, "TOPRIGHT", "TOPRIGHT", coins.hd, "TOPLEFT"),
	}
	Gb.Croix(BankCloseButton, f)
	BankCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	-- les 28 cases du client, habillees
	for i = 1, NUM_BANKGENERIC_SLOTS do
		habillerCase(_G["BankFrameItem" .. i])
	end
	sacs(f)
	achat(f)
	argent(f)
	outils(f)
	onglets(f)
	hooksecurefunc("BankFrameItemButton_Update", apresBouton)
	f:HookScript("OnShow", function()
		SetPortraitTexture(habit.portrait, "npc")
		B.page = 1
		B.Disposer()
	end)
end

B.Habiller()
