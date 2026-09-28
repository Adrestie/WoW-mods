-- ForeverUI : le marchand (MerchantFrame), a la DA de camelot (demande de
-- l'utilisateur, 2026-09-28 : « fait le commerce », etape 1).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (MerchantFrame.xml / .lua de 3.3.5,
-- FrameXML) :
--   MerchantFrame 384 x 512 a TOPLEFT (0, -104), HitRectInsets 0 / 35 / 0 /
--     61 ; UIPanelWindows : area "left" ; art UI-Merchant-TopLeft / TopRight
--     / BotLeft / BotRight (quatre textures sans nom) ; MerchantFramePortrait
--     60 x 60 a (7, -6) (SetPortraitTexture "NPC", UI-BuyBack-Icon au
--     rachat) ; MerchantNameText TOP (0, -17) (le nom du marchand,
--     MERCHANT_BUYBACK au rachat) ; MerchantPageText BOTTOM (-14, 150) ;
--     MerchantRepairText (REPAIR_ITEMS) ; BuybackFrameTopLeft / TopRight /
--     BotLeft / BotRight (le fond du rachat) ; MerchantFrameBottomLeftBorder
--     et -RightBorder (UI-Merchant-BottomBorder) ;
--   MerchantItem1..12 (MerchantItemTemplate 153 x 44 : UI-EmptySlot, UI-
--     Merchant-LabelSlots, nom, ItemButtonTemplate, argent) : le premier a
--     (24, -80), 12 entre deux colonnes, 8 entre deux rangees (15 au rachat,
--     repose par MerchantFrame_UpdateMerchantInfo / _UpdateBuybackInfo) ;
--   MerchantRepairAllButton, -ItemButton, MerchantGuildBankRepairButton
--     (UI-Merchant-RepairIcons), reposes et retailles (32 / 36) par
--     MerchantFrame_UpdateRepairButtons a chaque mise a jour ;
--   MerchantBuyBackItem 153 x 37 sous MerchantItem10 (0, -53) ;
--   MerchantMoneyFrame BOTTOMRIGHT (-40, 67) ; MerchantPrev/NextPageButton
--     CENTER sur BOTTOMLEFT (37 / 324, 156) ; MerchantFrameCloseButton
--     TOPRIGHT (-30, -8) ; MerchantFrameTab1 / Tab2
--     (CharacterFrameTabButtonTemplate) CENTER sur BOTTOMLEFT (60, 46).
--
-- RELEVE -- CAMELOT (blizzard_uipanels_game/mainline/merchantframe.xml et
-- .lua, le [Family] de camelot) :
--   MerchantFrame : ButtonFrameTemplate 336 x 444 (encart de (4, -60) a
--     (-6, 26)) ; titre UnitName("npc") (SetTitle), portrait de l'unite
--     (SetPortraitToUnit), au rachat MERCHANT_BUYBACK et UI-BuyBack-Icon ;
--   BuybackBG : blanc a 0,2 de (7, -60) a (-7, 26), montre au rachat ;
--   MerchantPageText BOTTOM (0, 86), 104 de large ;
--   MerchantFrameBottomLeftBorder : l'atlas UI-Merchant-BotFrame, 334 x 61,
--     BOTTOMLEFT (1, 26), en OVERLAY ;
--   MerchantItem1 TOPLEFT (11, -69), le reste enchaine comme en 3.3.5 ; le
--     nom a la couleur de qualite de l'objet et l'icone son contour
--     (MerchantFrameItem_UpdateQuality : ITEM_QUALITY_COLORS,
--     SetItemButtonQuality -- WhiteIconFrame, commun en COMMON_GRAY_COLOR,
--     mediocre sans contour) ;
--   reparation : 36 x 36 sur un fond UI-EmptySlot 64 x 64 a (-13, 14),
--     icones SpellIcon-256x256-RepairAll / -Repair / -RepairAllGuild ;
--     RepairAll BOTTOMRIGHT sur BOTTOMLEFT (118, 33), RepairItem a sa gauche
--     (-8) ; avec la reparation de guilde (96, 33), (-9), et la guilde a
--     droite (8) (MerchantFrame_UpdateRepairButtons) ; pas de texte ;
--   MerchantBuyBackItem 115 x 37 sous MerchantItem10 (30, -53), sans cadre
--     de nom, nom 70 x 35 a (-5, 2) du fond de case ; le compte a 0,65
--     (SetItemButtonScale) ; la fleche common-icon-undo 20 x 20 au centre
--     (0, -1), grisee sans objet a racheter ;
--   l'argent : MerchantMoneyInset (InsetFrameTemplate) de TOPLEFT sur
--     BOTTOMRIGHT (-171, 27) a BOTTOMRIGHT (-5, 4), MerchantMoneyBg
--     (ThinGoldEdgeTemplate) de BOTTOMLEFT sur BOTTOMRIGHT (-166, 6) a
--     TOPRIGHT (-7, 25), MerchantMoneyFrame BOTTOMRIGHT (-4, 8)
--     (MerchantFrame_UpdateCurrencies, sans monnaie de marchand) ;
--   Prev / Next CENTER sur BOTTOMLEFT (25 / 310, 96) ;
--   onglets PanelTabButtonTemplate : le premier CENTER sur BOTTOMLEFT
--     (50, -15), le suivant a +3 (PanelTemplates_AnchorTabs).
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : les cadres et la
-- logique du client restent, poses aux places de camelot et habilles de son
-- art ; ce que le client repose a chaque mise a jour (reparation, portrait,
-- titre, fond du rachat) est repris apres lui. Les onglets sont ceux de la
-- fenetre Social (PanelTabButtonTemplate) et commandent ceux du client, qui
-- s'effacent. Le portrait est celui de la feuille, VALIDE (Inspect.lua) :
-- 48 de cote, centre sur le trou de l'anneau -- un portrait d'unite en 60
-- depasse du cercle. N'EXISTENT PAS EN 3.3.5, donc absents : le filtre par
-- specialisation (SetMerchantFilter) et « tout vendre » les objets
-- mediocres (C_MerchantFrame.SellAllJunkItems).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local M = {}
ForeverUI.Marchand = M

local SEP = string.char(92)

local N = {
	fenetre = { 336, 444 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	encart = { 4, -60, -6, 26 },
	rachatFond = { 7, -60, -7, 26, a = 0.2 },
	basCadre = { l = 334, h = 61, x = 1, y = 26 },
	premier = { 11, -69 },
	page = { x = 0, y = 86, l = 104 },
	precedent = { 25, 96 }, suivant = { 310, 96 },
	reparer = { cote = 36, fond = { 64, -13, 14 }, seul = { x = 118, y = 33, ecart = -8 },
		guilde = { x = 96, y = 33, ecart = -9, droite = 8 } },
	rachat = { l = 115, h = 37, x = 30, y = -53, cadreNom = { 90, 64 }, nom = { 70, 35, -5, 2 },
		fleche = { cote = 20, x = 0, y = -1 }, compte = 0.65 },
	argent = { encart = { -171, 27, -5, 4 }, bord = { -166, 6, -7, 25 }, bourse = { -4, 8 } },
	onglet = { x = 50, y = -15, ecart = 3 },
}

local ART = {
	fondBas = "ui-merchant-botframe",
	toutReparer = "spellicon-256x256-repairall",
	reparer = "spellicon-256x256-repair",
	guilde = "spellicon-256x256-repairallguild",
	annuler = "common-icon-undo",
	case = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-EmptySlot",
	argent = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	marbre = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	rachat = "Interface" .. SEP .. "MerchantFrame" .. SEP .. "UI-BuyBack-Icon",
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- InsetFrameTemplate : marbre et lisere, en regions de la fenetre calees sur
-- un repere (les encadres de camelot sont au niveau de la fenetre)
local function encart(f, x1, y1, p1, x2, y2, p2)
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, p1, x1, y1)
	rect:SetPoint("BOTTOMRIGHT", f, p2, x2, y2)
	local marbre = f:CreateTexture(nil, "BACKGROUND")
	marbre:SetTexture(ART.marbre, true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(rect)
	return rect, marbre, Gb.NeufTranches(f, "InsetFrameTemplate", rect)
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

-- la qualite : nom et contour (Gb.Qualite)
local function qualite(nom, bouton, lien)
	Gb.Qualite(nom, bouton, lien)
end

local contour = Gb.Contour

-- LES REPARATIONS, apres MerchantFrame_UpdateRepairButtons (qui les repose
-- aux places de 3.3.5 et les retaille a 32 avec la guilde)
function M.PlacerReparation()
	local R = N.reparer
	local f = MerchantFrame
	for _, b in ipairs({ MerchantRepairAllButton, MerchantRepairItemButton, MerchantGuildBankRepairButton }) do
		b:SetWidth(R.cote)
		b:SetHeight(R.cote)
	end
	local guilde = MerchantGuildBankRepairButton:IsShown()
	local P = guilde and R.guilde or R.seul
	poser(MerchantRepairAllButton, "BOTTOMRIGHT", f, "BOTTOMLEFT", P.x, P.y)
	poser(MerchantRepairItemButton, "RIGHT", MerchantRepairAllButton, "LEFT", P.ecart, 0)
	poser(MerchantGuildBankRepairButton, "LEFT", MerchantRepairAllButton, "RIGHT", R.guilde.droite, 0)
end

-- la fleche du rachat : grisee sans objet a racheter
local function majFleche()
	local t = M.fleche
	if t then t:SetDesaturated(GetNumBuybackItems() == 0) end
end

-- APRES LE CLIENT : l'onglet du marchand
function M.ApresMarchand()
	local h = MerchantFrame.foreverHabit
	if not h then return end
	SetPortraitTexture(h.portrait, "npc")
	M.fondRachat:Hide()
	local numero = MerchantFrame.page or 1
	for i = 1, MERCHANT_ITEMS_PER_PAGE do
		local index = (numero - 1) * MERCHANT_ITEMS_PER_PAGE + i
		local b = _G["MerchantItem" .. i .. "ItemButton"]
		if index <= GetMerchantNumItems() then
			qualite(_G["MerchantItem" .. i .. "Name"], b, GetMerchantItemLink(index))
		else
			contour(b):Hide()
		end
	end
	local n = GetNumBuybackItems()
	qualite(MerchantBuyBackItemName, MerchantBuyBackItemItemButton, n > 0 and GetBuybackItemLink(n) or nil)
	majFleche()
end

-- APRES LE CLIENT : l'onglet du rachat
function M.ApresRachat()
	local h = MerchantFrame.foreverHabit
	if not h then return end
	h.portrait:SetTexture(ART.rachat)
	M.fondRachat:Show()
	local n = GetNumBuybackItems()
	for i = 1, BUYBACK_ITEMS_PER_PAGE do
		local b = _G["MerchantItem" .. i .. "ItemButton"]
		if i <= n then
			qualite(_G["MerchantItem" .. i .. "Name"], b, GetBuybackItemLink(i))
		else
			contour(b):Hide()
		end
	end
end

-- les onglets du bas suivent celui du client
function M.MajOnglets()
	local S = ForeverUI.Social
	for i, o in ipairs(M.onglets or {}) do
		S.choisirOnglet(o, MerchantFrame.selectedTab == i, true)
		o:SetWidth(S.largeurOnglet(o))
	end
end

local function onglets(f)
	local S = ForeverUI.Social
	local O = N.onglet
	M.onglets = {}
	for i, texte in ipairs({ MERCHANT, BUYBACK }) do
		local o = S.creerOnglet(f, "ForeverUIMerchantTab" .. i, false)
		o:SetText(texte)
		if i == 1 then
			o:SetPoint("CENTER", f, "BOTTOMLEFT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", M.onglets[i - 1], "TOPRIGHT", O.ecart, 0)
		end
		-- ce que fait l'onglet du client (MerchantFrameTab<i>, OnClick)
		o:SetScript("OnClick", function()
			PlaySound("igCharacterInfoTab")
			PanelTemplates_SetTab(MerchantFrame, i)
			MerchantFrame_Update()
		end)
		M.onglets[i] = o
		ForeverUI.Suppress(_G["MerchantFrameTab" .. i])
	end
	M.MajOnglets()
end

-- une icone de reparation de camelot, sur son fond de case
local function reparation(b, icone, atlas)
	local F = N.reparer.fond
	local fond = b:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture(ART.case)
	fond:SetWidth(F[1])
	fond:SetHeight(F[1])
	fond:SetPoint("TOPLEFT", b, "TOPLEFT", F[2], F[3])
	ForeverUI.SetAtlas(icone, atlas)
	icone:ClearAllPoints()
	icone:SetAllPoints(b)
	b.foreverFond = fond
end

-- l'icone sans nom de MerchantRepairItemButton
local function iconeSansNom(b)
	for _, r in ipairs({ b:GetRegions() }) do
		if r:GetObjectType() == "Texture" and r ~= b:GetNormalTexture() and r ~= b:GetPushedTexture()
			and r ~= b:GetHighlightTexture() and r:GetDrawLayer() == "BORDER" then
			return r
		end
	end
end

local function rachat()
	local R = N.rachat
	local it = MerchantBuyBackItem
	it:SetWidth(R.l)
	it:SetHeight(R.h)
	poser(it, "TOPLEFT", MerchantItem10, "BOTTOMLEFT", R.x, R.y)
	MerchantBuyBackItemNameFrame:SetWidth(R.cadreNom[1])
	MerchantBuyBackItemNameFrame:SetHeight(R.cadreNom[2])
	MerchantBuyBackItemNameFrame:Hide()
	MerchantBuyBackItemName:SetWidth(R.nom[1])
	MerchantBuyBackItemName:SetHeight(R.nom[2])
	poser(MerchantBuyBackItemName, "LEFT", MerchantBuyBackItemSlotTexture, "RIGHT", R.nom[3], R.nom[4])
	-- SetItemButtonScale(0.65) : le compte seul (3.3.5 ne met pas un texte a
	-- l'echelle : sa police, a 0,65 de sa taille)
	local compte = MerchantBuyBackItemItemButtonCount
	local chemin, taille, drapeaux = compte:GetFont()
	if chemin and taille then compte:SetFont(chemin, taille * R.compte, drapeaux) end
	-- la fleche, au-dessus de l'icone
	local voile = CreateFrame("Frame", nil, MerchantBuyBackItemItemButton)
	voile:SetAllPoints(MerchantBuyBackItemItemButton)
	voile:EnableMouse(false)
	local t = voile:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(t, ART.annuler)
	t:SetWidth(R.fleche.cote)
	t:SetHeight(R.fleche.cote)
	t:SetPoint("CENTER", voile, "CENTER", R.fleche.x, R.fleche.y)
	M.fleche = t
	MerchantBuyBackItemItemButton:HookScript("OnShow", majFleche)
end

function M.Habiller()
	local f = MerchantFrame
	if not f or f.foreverHabit then return end

	-- l'art de 3.3.5 : les quatre morceaux sans nom, le portrait, le nom, le
	-- texte de reparation, le fond du rachat, la bordure du bas de droite
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then
			r:SetAlpha(0)
		end
	end
	for _, r in ipairs({ MerchantFramePortrait, MerchantNameText, MerchantRepairText, BuybackFrameTopLeft,
		BuybackFrameTopRight, BuybackFrameBotLeft, BuybackFrameBotRight, MerchantFrameBottomRightBorder }) do
		r:SetAlpha(0)
	end
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	f:SetHitRectInsets(0, 0, 0, 0)

	-- ButtonFrameTemplate : pierre, stries, metal, portrait, titre
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = MerchantNameText:GetText(),
	})
	f.foreverHabit = habit
	hooksecurefunc(MerchantNameText, "SetText", function(_, texte)
		habit.titre:SetText(texte or "")
	end)
	-- l'encart, puis le fond du rachat (blanc a 0,2) dessus
	local E = N.encart
	habit.encart, habit.marbre, habit.encadre = encart(f, E[1], E[2], "TOPLEFT", E[3], E[4], "BOTTOMRIGHT")
	local RF = N.rachatFond
	local fond = f:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture(1, 1, 1, RF.a)
	fond:SetPoint("TOPLEFT", f, "TOPLEFT", RF[1], RF[2])
	fond:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", RF[3], RF[4])
	fond:Hide()
	M.fondRachat = fond
	-- le fond du bas : la texture du client, qui la montre et la cache
	local B = N.basCadre
	local bas = MerchantFrameBottomLeftBorder
	ForeverUI.SetAtlas(bas, ART.fondBas)
	bas:SetWidth(B.l)
	bas:SetHeight(B.h)
	poser(bas, "BOTTOMLEFT", f, "BOTTOMLEFT", B.x, B.y)
	-- l'argent : son encart, son bord dore, la bourse
	local A = N.argent
	habit.encartArgent = encart(f, A.encart[1], A.encart[2], "BOTTOMRIGHT", A.encart[3], A.encart[4], "BOTTOMRIGHT")
	local bord = CreateFrame("Frame", nil, f)
	bord:EnableMouse(false)
	bord:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", A.bord[1], A.bord[2])
	bord:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", A.bord[3], A.bord[4])
	habit.bordArgent = bord
	habit.bordDore = bordDore(f, bord)
	poser(MerchantMoneyFrame, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A.bourse[1], A.bourse[2])
	-- la croix, au-dessus du metal
	Gb.Croix(MerchantFrameCloseButton, f)
	MerchantFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)

	-- les objets, les pages
	poser(MerchantItem1, "TOPLEFT", f, "TOPLEFT", N.premier[1], N.premier[2])
	MerchantPageText:SetWidth(N.page.l)
	poser(MerchantPageText, "BOTTOM", f, "BOTTOM", N.page.x, N.page.y)
	poser(MerchantPrevPageButton, "CENTER", f, "BOTTOMLEFT", N.precedent[1], N.precedent[2])
	poser(MerchantNextPageButton, "CENTER", f, "BOTTOMLEFT", N.suivant[1], N.suivant[2])

	-- les reparations
	reparation(MerchantRepairAllButton, MerchantRepairAllIcon, ART.toutReparer)
	reparation(MerchantRepairItemButton, iconeSansNom(MerchantRepairItemButton), ART.reparer)
	reparation(MerchantGuildBankRepairButton, MerchantGuildBankRepairButtonIcon, ART.guilde)
	hooksecurefunc("MerchantFrame_UpdateRepairButtons", M.PlacerReparation)
	M.PlacerReparation()

	rachat()
	onglets(f)
	hooksecurefunc("MerchantFrame_UpdateMerchantInfo", M.ApresMarchand)
	hooksecurefunc("MerchantFrame_UpdateBuybackInfo", M.ApresRachat)
	hooksecurefunc("MerchantFrame_Update", M.MajOnglets)
end

M.Habiller()
