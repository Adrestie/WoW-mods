-- ForeverUI : la banque de guilde (GuildBankFrame, Blizzard_GuildBankUI
-- charge a la demande), a la DA de camelot (demande de l'utilisateur,
-- 2026-09-28 : « fait le reste du commerce »).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (Blizzard_GuildBankUI.xml / .lua de
-- 3.3.5) :
--   GuildBankFrame 769 x 444 a TOPLEFT (0, -104) : art GuildBankFrameLeft /
--     -Right (UI-GuildBankFrame-Left / Right), un UIPanelCloseButton sans nom
--     TOPRIGHT (3, -8) ; titre de l'onglet GuildBankTabTitleBackground TOP
--     (6, -43), limite GuildBankTabLimitBackground TOP (6, -388) ;
--     GuildBankEmblemFrame TOP (-70, 46) ; GuildBankColumn1 (30, -70), les
--     six autres a sa droite (3, 0) ; GuildBankMoneyLimitLabel BOTTOMLEFT
--     (26, 16), GuildBankMoneyFrame BOTTOMRIGHT (-4, 16), Deposit
--     BOTTOMRIGHT (-11, 37), Withdraw a sa gauche ; GuildBankFrameTab1..4
--     (CharacterFrameTabButtonTemplate) BOTTOMLEFT (19, -24) ; GuildBankTab1
--     TOPLEFT sur TOPRIGHT (-1, -32) ; GuildBankFrameLog : GuildBankMessage-
--     Frame (33, -73) 688 x 304 et GuildBankTransactionsScrollFrame
--     (FauxScrollFrameTemplate, fond UI-Character-ScrollBar) ; GuildBankInfo
--     (32, -74) : GuildBankInfoScrollFrame (0, 0), GuildBankInfoSaveButton
--     BOTTOMLEFT (25, 37).
--
-- RELEVE -- CAMELOT (blizzard_guildbankui/mainline) :
--   GuildBankFrame : BasicFrameTemplate 750 x 428 (fond UI-Background-Rock
--     de (2, -21) a (-2, 2), TitleBg _UI-Frame-TitleTileBg (2, -1 / -25, -1),
--     stries (0, -21 / -2, -21) ; coins UI-Frame-TopLeftCorner (-6, 1),
--     -TopCornerRight (0, 1), -BotCornerLeft (-6, -5), -BotCornerRight (0,
--     -5), bords _UI-Frame-TitleTile, _UI-Frame-Bot, !UI-Frame-LeftTile,
--     !UI-Frame-RightTile (+1) ; croix UIPanelCloseButtonDefaultAnchors) ;
--   RedMarbleBG (GuildVaultBG, en mosaique) de (2, -20) a (-2, 20), BlackBG
--     noir entre les coins interieurs (4, -4 / -4, 3) ; deux cadres
--     Corners / VertTile / HorizTile : exterieur (-2, 21), (0, 21), (0,
--     -18), (-2, -18), interieur a (14, 32), (-9, 32), (-9, -35), (14, -35)
--     des coins exterieurs ; bords a -3 / +4 / +3 / -5 ;
--   titre de l'onglet TOP (0, -30), limite TOP (0, -370) ; Emblem TOP (-70,
--     59) ; Column1 (18, -59), les autres a (3, 0) ; MoneyFrameBG
--     (ThinGoldEdgeTemplate) de TOPLEFT sur BOTTOMLEFT (1, 25) a BOTTOMRIGHT
--     (-4, 2), GuildBankMoneyLimitLabel BOTTOMLEFT (8, 6), GuildBankMoney-
--     Frame BOTTOMRIGHT (-2, 6), Deposit BOTTOMRIGHT (-8, 30) ; onglets
--     PanelTabButtonTemplate, le premier BOTTOMLEFT (7, -30), les suivants a
--     +3 ; GuildBankTab1 TOPLEFT sur TOPRIGHT (-1, -17) ; Log.MessageFrame
--     (24, -64) 688 x 304, sa barre MinimalScrollBar a (6, 0 / 5, 3) ;
--     GuildBankInfoScrollFrame (-9, 12), barre (4, -2 / 3) ; SaveButton
--     BOTTOMLEFT (20, 31) ; GuildItemSearchBox 130 x 20 TOPRIGHT (-15, -36) ;
--     le contour de qualite des objets.
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : les cadres et la
-- logique du client restent. Le journal defile par la barre du client
-- (FauxScrollFrame), posee a la place de celle de camelot, sur le message.
-- La recherche suit la regle des sacs (nom, type, sous-type). Les onglets du
-- bas sont ceux de la fenetre Social et commandent ceux du client. LA
-- FENETRE D'ICONE D'UN ONGLET (GuildBankPopupFrame) N'EST PAS REPRISE : chez
-- camelot c'est IconSelectorPopupFrameTemplate, qui demande de refaire sa
-- grille comme pour les macros.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local G = {}
ForeverUI.BanqueDeGuilde = G

local SEP = string.char(92)

local N = {
	fenetre = { 750, 428 },
	fond = { 2, -21, -2, 2 }, titreFond = { 2, -1, -25, -1 }, stries = { 0, -21, -2, -21 },
	coins = { hg = { -6, 1 }, hd = { 0, 1 }, bg = { -6, -5 }, bd = { 0, -5 } },
	-- les tailles des textures virtuelles de camelot (UI-Frame-TopLeftCorner
	-- = l'atlas UI-Frame-TopLeftCornerNoPortrait, 33 x 33)
	pieces = { titreFond = 18, stries = 43, coinHaut = 33, coinBasGauche = 14, coinBasDroit = 11,
		haut = 28, bas = 9, gauche = 16, droite = 10 },
	marbre = { 2, -20, -2, 20 },
	exterieur = { bg = { -2, 21 }, bd = { 0, 21 }, hd = { 0, -18 }, hg = { -2, -18 } },
	interieur = { bg = { 14, 32 }, bd = { -9, 32 }, hd = { -9, -35 }, hg = { 14, -35 } },
	noir = { 4, -4, -4, 3 },
	titreOnglet = { 0, -30 }, limite = { 0, -370 }, embleme = { -70, 59 },
	colonne = { 18, -59 },
	argent = { bord = { 1, 25, -4, 2 }, limite = { 8, 6 }, bourse = { -2, 6 }, depot = { -8, 30 } },
	onglet = { x = 7, y = -30, ecart = 3 },
	ongletCote = { -1, -17 },
	journal = { 24, -64, barre = { 6, 0, 3 } },
	info = { defile = { -9, 12 }, barre = { 4, -2, 3 }, sauver = { 20, 31 } },
	recherche = { -15, -36, 130, 20 },
}

local ART = {
	roche = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock",
	coffre = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildbankframe" .. SEP .. "guildvaultbg",
	coinsGB = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildbankframe" .. SEP .. "corners",
	vertical = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildbankframe" .. SEP .. "verttile",
	horizontal = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildbankframe" .. SEP .. "horiztile",
	argent = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
}

-- les quatre coins de Corners (un fichier, quatre bandes)
local COINS = {
	bg = { 0.015625, 0.515625, 0.00390625, 0.12890625 },
	bd = { 0.015625, 0.515625, 0.13671875, 0.26171875 },
	hd = { 0.015625, 0.515625, 0.26953125, 0.39453125 },
	hg = { 0.015625, 0.515625, 0.40234375, 0.52734375 },
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

local function mosaique(t, fichier, h, v)
	t:SetTexture(fichier, true)
	if t.SetHorizTile then
		t:SetHorizTile(h and true or false)
		t:SetVertTile(v and true or false)
	end
end

-- BaseBasicFrameTemplate : les pieces UI-Frame, en regions de la fenetre,
-- A LA TAILLE DE LEUR TEXTURE VIRTUELLE (mainline/shareduipaneltemplates.xml)
-- -- sans taille, le client 3.3.5 dessine une texture a la taille de sa
-- feuille entiere (constate en jeu le 28/09 : cadre casse)
local function cadreSimple(f)
	local F, T, S, P = N.fond, N.titreFond, N.stries, N.pieces
	local roche = f:CreateTexture(nil, "BACKGROUND")
	mosaique(roche, ART.roche, true, true)
	roche:SetPoint("TOPLEFT", f, "TOPLEFT", F[1], F[2])
	roche:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", F[3], F[4])
	local titreFond = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(titreFond, "_ui-frame-titletilebg", true)
	titreFond:SetHeight(P.titreFond)
	titreFond:SetPoint("TOPLEFT", f, "TOPLEFT", T[1], T[2])
	titreFond:SetPoint("TOPRIGHT", f, "TOPRIGHT", T[3], T[4])
	local stries = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(stries, "_ui-frame-toptilestreaks", true)
	stries:SetHeight(P.stries)
	stries:SetPoint("TOPLEFT", f, "TOPLEFT", S[1], S[2])
	stries:SetPoint("TOPRIGHT", f, "TOPRIGHT", S[3], S[4])
	local C = N.coins
	local function coin(atlas, couche, point, o, cote)
		local t = f:CreateTexture(nil, couche)
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetWidth(cote)
		t:SetHeight(cote)
		t:SetPoint(point, f, point, o[1], o[2])
		return t
	end
	local hg = coin("ui-frame-topleftcornernoportrait", "OVERLAY", "TOPLEFT", C.hg, P.coinHaut)
	local hd = coin("ui-frame-topcornerright", "OVERLAY", "TOPRIGHT", C.hd, P.coinHaut)
	local bg = coin("ui-frame-botcornerleft", "BORDER", "BOTTOMLEFT", C.bg, P.coinBasGauche)
	local bd = coin("ui-frame-botcornerright", "BORDER", "BOTTOMRIGHT", C.bd, P.coinBasDroit)
	-- un bord : sa longueur par ses deux ancres, son epaisseur fixee
	local function bord(atlas, couche, epaisseur, horizontal, a1, c1, r1, a2, c2, r2, x)
		local t = f:CreateTexture(nil, couche)
		ForeverUI.SetAtlas(t, atlas, true)
		if horizontal then t:SetHeight(epaisseur) else t:SetWidth(epaisseur) end
		t:SetPoint(a1, c1, r1, x or 0, 0)
		t:SetPoint(a2, c2, r2)
		return t
	end
	return {
		roche = roche, titreFond = titreFond, stries = stries, coins = { hg = hg, hd = hd, bg = bg, bd = bd },
		haut = bord("_ui-frame-titletile", "OVERLAY", P.haut, true, "TOPLEFT", hg, "TOPRIGHT", "TOPRIGHT", hd, "TOPLEFT"),
		bas = bord("_ui-frame-bot", "BORDER", P.bas, true, "BOTTOMLEFT", bg, "BOTTOMRIGHT", "BOTTOMRIGHT", bd, "BOTTOMLEFT"),
		gauche = bord("!ui-frame-lefttile", "BORDER", P.gauche, false, "TOPLEFT", hg, "BOTTOMLEFT", "BOTTOMLEFT", bg, "TOPLEFT"),
		droite = bord("!ui-frame-righttile", "BORDER", P.droite, false, "TOPRIGHT", hd, "BOTTOMRIGHT", "BOTTOMRIGHT", bd, "TOPRIGHT", 1),
	}
end

-- un cadre de Corners / VertTile / HorizTile : ses quatre coins places
-- depuis `relatif` (la fenetre, ou les coins du cadre exterieur)
local function cadreCoffre(f, places, relatifs)
	local coins = {}
	for cle, point in pairs({ bg = "BOTTOMLEFT", bd = "BOTTOMRIGHT", hd = "TOPRIGHT", hg = "TOPLEFT" }) do
		local t = f:CreateTexture(nil, "BORDER")
		t:SetTexture(ART.coinsGB)
		local c = COINS[cle]
		t:SetTexCoord(c[1], c[2], c[3], c[4])
		t:SetWidth(32)
		t:SetHeight(32)
		t:SetPoint(point, relatifs and relatifs[cle] or f, point, places[cle][1], places[cle][2])
		coins[cle] = t
	end
	local function bord(fichier, h, a1, c1, r1, x1, y1, a2, c2, r2, x2, y2)
		local t = f:CreateTexture(nil, "BORDER")
		mosaique(t, fichier, h, not h)
		t:SetPoint(a1, c1, r1, x1, y1)
		t:SetPoint(a2, c2, r2, x2, y2)
		return t
	end
	return {
		coins = coins,
		gauche = bord(ART.vertical, false, "TOPLEFT", coins.hg, "BOTTOMLEFT", -3, 0, "BOTTOMLEFT", coins.bg, "TOPLEFT", -3, 0),
		droite = bord(ART.vertical, false, "TOPRIGHT", coins.hd, "BOTTOMRIGHT", 4, 0, "BOTTOMRIGHT", coins.bd, "TOPRIGHT", 4, 0),
		haut = bord(ART.horizontal, true, "TOPLEFT", coins.hg, "TOPRIGHT", 0, 3, "TOPRIGHT", coins.hd, "TOPLEFT", 0, 3),
		bas = bord(ART.horizontal, true, "BOTTOMLEFT", coins.bg, "BOTTOMRIGHT", 0, -5, "BOTTOMRIGHT", coins.bd, "BOTTOMLEFT", 0, -5),
	}
end

-- ThinGoldEdgeTemplate
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

-- la regle de la recherche des sacs (nom, type, sous-type ; sans casse)
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

-- APRES GuildBankFrame_Update : contour de qualite et voile de recherche
function G.ApresMaj()
	local onglet = GetCurrentGuildBankTab()
	local texte = G.champ and G.champ:GetText() or ""
	for c = 1, NUM_GUILDBANK_COLUMNS do
		for i = 1, NUM_SLOTS_PER_GUILDBANK_GROUP do
			local b = _G["GuildBankColumn" .. c .. "Button" .. i]
			if b then
				local lien = GetGuildBankItemLink(onglet, (c - 1) * NUM_SLOTS_PER_GUILDBANK_GROUP + i)
				Gb.Qualite(nil, b, lien)
				if not b.foreverVoile then
					local v = b:CreateTexture(nil, "OVERLAY")
					v:SetTexture(0, 0, 0, 0.8)
					v:SetAllPoints(b)
					b.foreverVoile = v
				end
				Gb.Montrer(b.foreverVoile, texte ~= "" and lien ~= nil and not correspond(lien, texte))
			end
		end
	end
end

-- les onglets du bas suivent ceux du client
function G.MajOnglets()
	local S = ForeverUI.Social
	for i, o in ipairs(G.onglets or {}) do
		S.choisirOnglet(o, GuildBankFrame.selectedTab == i, true)
		o:SetWidth(S.largeurOnglet(o))
	end
end

local function croixDuClient(f)
	for _, c in ipairs({ f:GetChildren() }) do
		if c:GetObjectType() == "Button" and not c:GetName() then
			local t = c:GetNormalTexture()
			local fichier = t and t:GetTexture()
			if type(fichier) == "string" and string.find(fichier, "MinimizeButton", 1, true) then
				return c
			end
		end
	end
end

function G.Habiller()
	local f = GuildBankFrame
	if not f or f.foreverHabit then return end
	GuildBankFrameLeft:SetAlpha(0)
	GuildBankFrameRight:SetAlpha(0)
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	local habit = cadreSimple(f)
	f.foreverHabit = habit
	-- le coffre : marbre rouge, cadres exterieur et interieur, fond noir
	local M = N.marbre
	local marbre = f:CreateTexture(nil, "BACKGROUND")
	mosaique(marbre, ART.coffre, true, true)
	marbre:SetPoint("TOPLEFT", f, "TOPLEFT", M[1], M[2])
	marbre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", M[3], M[4])
	habit.marbre = marbre
	habit.exterieur = cadreCoffre(f, N.exterieur)
	habit.interieur = cadreCoffre(f, N.interieur, habit.exterieur.coins)
	local noir = f:CreateTexture(nil, "BACKGROUND")
	noir:SetTexture(0, 0, 0, 1)
	noir:SetPoint("TOPLEFT", habit.interieur.coins.hg, "TOPLEFT", N.noir[1], N.noir[2])
	noir:SetPoint("BOTTOMRIGHT", habit.interieur.coins.bd, "BOTTOMRIGHT", N.noir[3], N.noir[4])
	habit.noir = noir
	-- la croix
	local croix = croixDuClient(f)
	if croix then
		Gb.Croix(croix, f)
		croix:SetFrameLevel(f:GetFrameLevel() + 5)
		habit.croix = croix
	end
	-- l'onglet, sa limite, le blason, les colonnes, les onglets lateraux
	poser(GuildBankTabTitleBackground, "TOP", f, "TOP", N.titreOnglet[1], N.titreOnglet[2])
	poser(GuildBankTabLimitBackground, "TOP", f, "TOP", N.limite[1], N.limite[2])
	poser(GuildBankEmblemFrame, "TOP", f, "TOP", N.embleme[1], N.embleme[2])
	poser(GuildBankColumn1, "TOPLEFT", f, "TOPLEFT", N.colonne[1], N.colonne[2])
	poser(GuildBankTab1, "TOPLEFT", f, "TOPRIGHT", N.ongletCote[1], N.ongletCote[2])
	-- l'argent
	local A = N.argent
	local bord = CreateFrame("Frame", nil, f)
	bord:EnableMouse(false)
	bord:SetPoint("TOPLEFT", f, "BOTTOMLEFT", A.bord[1], A.bord[2])
	bord:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", A.bord[3], A.bord[4])
	habit.bordArgent = bord
	habit.bordDore = bordDore(f, bord)
	poser(GuildBankMoneyLimitLabel, "BOTTOMLEFT", f, "BOTTOMLEFT", A.limite[1], A.limite[2])
	poser(GuildBankMoneyFrame, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A.bourse[1], A.bourse[2])
	poser(GuildBankFrameDepositButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A.depot[1], A.depot[2])
	-- le journal : le message et la barre du client, a la place de camelot
	local J = N.journal
	poser(GuildBankMessageFrame, "TOPLEFT", GuildBankFrameLog, "TOPLEFT", J[1], J[2])
	local fx = GuildBankTransactionsScrollFrame
	fx:ClearAllPoints()
	fx:SetPoint("TOPLEFT", GuildBankMessageFrame, "TOPLEFT", 0, 0)
	fx:SetPoint("BOTTOMRIGHT", GuildBankMessageFrame, "BOTTOMRIGHT", 0, 0)
	for _, r in ipairs({ fx:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	Gb.BarreA(GuildBankTransactionsScrollFrameScrollBar, GuildBankMessageFrame, J.barre[1], J.barre[2], J.barre[3])
	-- l'information de l'onglet
	local I = N.info
	poser(GuildBankInfoScrollFrame, "TOPLEFT", GuildBankInfo, "TOPLEFT", I.defile[1], I.defile[2])
	Gb.BarreA(GuildBankInfoScrollFrameScrollBar, GuildBankInfoScrollFrame, I.barre[1], I.barre[2], I.barre[3])
	poser(GuildBankInfoSaveButton, "BOTTOMLEFT", f, "BOTTOMLEFT", I.sauver[1], I.sauver[2])
	-- la recherche
	local R = N.recherche
	local champ = CreateFrame("EditBox", "ForeverUIGuildItemSearchBox", f, "InputBoxTemplate")
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
		Gb.Montrer(invite, (champ:GetText() or "") == "" and not champ:HasFocus())
		G.ApresMaj()
	end
	champ:SetScript("OnTextChanged", maj)
	champ:SetScript("OnEditFocusGained", maj)
	champ:SetScript("OnEditFocusLost", maj)
	champ:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	champ:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	champ:HookScript("OnHide", function(self) self:SetText("") end)
	G.champ = champ
	-- les onglets du bas : ceux de Social, qui commandent ceux du client
	local S, O = ForeverUI.Social, N.onglet
	G.onglets = {}
	for i, texte in ipairs({ GUILD_BANK, GUILD_BANK_LOG, GUILD_BANK_MONEY_LOG, GUILD_BANK_TAB_INFO }) do
		local o = S.creerOnglet(f, "ForeverUIGuildBankTab" .. i, false)
		o:SetText(texte)
		if i == 1 then
			o:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", G.onglets[i - 1], "TOPRIGHT", O.ecart, 0)
		end
		o:SetScript("OnClick", function()
			GuildBankFrameTab_OnClick(_G["GuildBankFrameTab" .. i], i)
		end)
		G.onglets[i] = o
		ForeverUI.Suppress(_G["GuildBankFrameTab" .. i])
	end
	hooksecurefunc("GuildBankFrame_Update", G.ApresMaj)
	hooksecurefunc("GuildBankFrameTab_OnClick", G.MajOnglets)
	G.MajOnglets()
end

G.Habiller()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(_, _, nom)
	if nom == "Blizzard_GuildBankUI" then
		G.Habiller()
	end
end)
