-- ForeverUI : l'echange (TradeFrame), a la DA de camelot (demande de
-- l'utilisateur, 2026-09-28 : « fait le reste du commerce »).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (TradeFrame.xml / .lua de 3.3.5,
-- FrameXML) :
--   TradeFrame 384 x 512 a TOPLEFT (0, -104), HitRectInsets 0 / 35 / 0 / 72 ;
--     art UI-TradeFrame-TopLeft / TopRight / BotLeft / BotRight (quatre
--     textures sans nom) ; TradeFramePlayerPortrait (7, -6) et
--     TradeFrameRecipientPortrait (183, -6), 60 x 60 (SetPortraitTexture a
--     chaque TradeFrame_Update) ; TradeFramePlayerNameText (75, -17) 100 x
--     12, TradeFrameRecipientNameText (245, -17) 80 x 12 ; les textes
--     d'enchantement (26, -374) et +170 ;
--   TradeHighlightPlayer (19, -100) et -Recipient (189, -100), 161 x 266 ;
--     les deux -Enchant dessous (0, -4), 161 x 61 ;
--   TradePlayerItem1 (26, -104), TradeRecipientItem1 (195, -104), 7 entre
--     deux, le septieme (l'enchantement) 28 sous le sixieme ;
--   TradeFrameTradeButton 85 x 22 BOTTOMRIGHT (-113, 55), Cancel 77 x 22 a
--     sa droite (3) ; TradeFrameCloseButton TOPRIGHT (-25, -8) ;
--   TradePlayerInputMoneyFrame (26, -73), TradeRecipientMoneyFrame TOPRIGHT
--     (-40, -78).
--
-- RELEVE -- CAMELOT (blizzard_uipanels_game/mainline/tradeframe.xml et
-- .lua) :
--   TradeFrame : ButtonFrameTemplate 344 x 446, portrait du joueur
--     (SetPortraitToUnit) ; RecipientOverlay a TOPLEFT sur TOPRIGHT (-180,
--     7) : portrait de l'autre 60 x 60 a (2, 0) et son coin de metal
--     UI-Frame-PortraitMetal-CornerTopLeft a (-8, 9) de lui, au-dessus de
--     tout (frameLevel 550) ;
--   TradeRecipientBG : blanc a 0,15 de TOPRIGHT (-172, -20) a BOTTOMRIGHT,
--     au-dessus du marbre des encarts ; TradeRecipientLeftBorder
--     (!UI-Frame-LeftTile) de TOPRIGHT (-178, -50) a TradeRecipient-
--     BotLeftCorner (UI-Frame-BotCornerLeft), BOTTOMLEFT sur BOTTOMRIGHT
--     (-178, -3), en OVERLAY ;
--   les noms, dans un cadre de strate HIGH : joueur (65, -5) 100 x 12,
--     l'autre (230, -5) 80 x 12 ;
--   six encarts InsetFrameTemplate (de TOPLEFT a TOPLEFT) : objets du joueur
--     (4, -83 / 166, -352), son enchantement (4, -354 / 166, -418), son
--     argent (4, -58 / 166, -82) ; objets de l'autre (175, -83 / 338, -352)
--     et son enchantement (175, -354 / 338, -418), marbre a 0,1 ; son argent
--     (175, -58 / 338, -81), sans marbre ; TradeRecipientMoneyBg
--     (ThinGoldEdgeTemplate) de TOPRIGHT (-168, -80) a TOPRIGHT (-7, -60), a
--     0,6 ; TradeRecipientMoneyFrame TOPRIGHT (-5, -64) ;
--     TradePlayerInputMoneyFrame (11, -61) ;
--   surbrillances 150 x 266 a (6, -85) et (176, -85), enchantements 150 x 61
--     dessous (0, -4) ; TradePlayerItem1 (14, -89), TradeRecipientItem1
--     (182, -89), le reste enchaine comme en 3.3.5 ; textes d'enchantement
--     (15, -360) et +166 ;
--   Trade 85 x 22 BOTTOMRIGHT (-85, 5), Cancel a sa droite (3) ;
--   la qualite des objets (TradeFrame_UpdatePlayerItem / -TargetItem) : nom
--     a sa couleur hors enchantement, contour de l'icone (SetItemButtonQuality).
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : les cadres et la
-- logique du client restent. Les portraits suivent la regle VALIDEE du
-- portrait d'unite (Inspect.lua) : 48 de cote, centres sur le trou de leur
-- anneau -- celui de l'autre garde le meme ecart a son coin de metal. Les
-- noms, regions de la fenetre que le metal couvrirait, sont recopies dans un
-- cadre au-dessus. La saisie de l'argent garde le mode compact de 3.3.5
-- (meme art de champ, Common-Input-Border) : le mode compact de camelot, qui
-- elargit l'or avec les chiffres, n'existe pas ici.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local T = {}
ForeverUI.Echange = T

local SEP = string.char(92)

local N = {
	fenetre = { 344, 446 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	-- l'autre : son coin de metal a TOPRIGHT (-180 + 2 - 8, 7 + 9), son
	-- portrait au meme ecart de son coin que le portrait du joueur (14, -14,5)
	autre = { coin = { -186, 16 }, portrait = { 14, -14.5 } },
	noms = { joueur = { 65, -5, 100, 12 }, autre = { 230, -5, 80, 12 } },
	fondAutre = { -172, -20, a = 0.15 },
	-- UI-Frame-BotCornerLeft 14 x 14, !UI-Frame-LeftTile 16 de large (leurs
	-- textures virtuelles) ; sans taille, le client 3.3.5 dessine une texture
	-- a la taille de sa feuille entiere (constate en jeu le 28/09)
	separation = { haut = { -178, -50 }, coin = { -178, -3 }, coinCote = 14, filetL = 16 },
	encarts = {
		{ nom = "joueurObjets", 4, -83, 166, -352 },
		{ nom = "joueurEnchant", 4, -354, 166, -418 },
		{ nom = "joueurArgent", 4, -58, 166, -82 },
		{ nom = "autreObjets", 175, -83, 338, -352, marbre = 0.1 },
		{ nom = "autreEnchant", 175, -354, 338, -418, marbre = 0.1 },
		{ nom = "autreArgent", 175, -58, 338, -81, marbre = 0 },
	},
	bordAutre = { -168, -80, -7, -60, a = 0.6 },
	argentAutre = { -5, -64 },
	saisie = { 11, -61 },
	surbrillance = { joueur = { 6, -85 }, autre = { 176, -85 }, l = 150 },
	objets = { joueur = { 14, -89 }, autre = { 182, -89 } },
	enchant = { 15, -360, 166 },
	echanger = { -85, 5 },
}

local ART = {
	marbre = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	argent = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	coinPortrait = "ui-frame-portraitmetal-cornertopleft",
	separation = "!ui-frame-lefttile",
	coinBas = "ui-frame-botcornerleft",
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- un encart (InsetFrameTemplate) : marbre et lisere, en regions de la
-- fenetre calees sur un repere
local function encart(f, e)
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", e[1], e[2])
	rect:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", e[3], e[4])
	local marbre = f:CreateTexture(nil, "BACKGROUND")
	marbre:SetTexture(ART.marbre, true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(rect)
	marbre:SetAlpha(e.marbre or 1)
	rect.marbre = marbre
	rect.lisere = Gb.NeufTranches(f, "InsetFrameTemplate", rect)
	return rect
end

-- ThinGoldEdgeTemplate
local function bordDore(f, rect, alpha)
	local function morceau(u1, u2, v1, v2)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ART.argent)
		t:SetTexCoord(u1, u2, v1, v2)
		t:SetAlpha(alpha)
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

-- APRES LE CLIENT : les portraits (TradeFrame_Update les repose)
function T.ApresMaj()
	local h = TradeFrame.foreverHabit
	if not h then return end
	SetPortraitTexture(h.portrait, "player")
	SetPortraitTexture(h.portraitAutre, "NPC")
end

-- APRES LE CLIENT : la qualite d'un objet (le septieme, l'enchantement,
-- garde la couleur que son texte porte)
function T.ApresJoueur(id)
	local lien = GetTradePlayerItemLink(id)
	local nom = (id ~= TRADE_ENCHANT_SLOT) and _G["TradePlayerItem" .. id .. "Name"] or nil
	Gb.Qualite(nom, _G["TradePlayerItem" .. id .. "ItemButton"], lien)
end

function T.ApresAutre(id)
	local _, _, _, q = GetTradeTargetItemInfo(id)
	local nom = (id ~= TRADE_ENCHANT_SLOT) and _G["TradeRecipientItem" .. id .. "Name"] or nil
	Gb.Qualite(nom, _G["TradeRecipientItem" .. id .. "ItemButton"], GetTradeTargetItemLink(id), q)
end

function T.Habiller()
	local f = TradeFrame
	if not f or f.foreverHabit then return end

	-- l'art de 3.3.5 : les quatre morceaux sans nom, les deux portraits
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then
			r:SetAlpha(0)
		end
	end
	TradeFramePlayerPortrait:SetAlpha(0)
	TradeFrameRecipientPortrait:SetAlpha(0)
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	f:SetHitRectInsets(0, 0, 0, 0)

	-- ButtonFrameTemplate, portrait du joueur, pas de titre
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y, titre = "",
	})
	f.foreverHabit = habit

	-- les encarts, puis le voile de l'autre au-dessus de leur marbre
	habit.encarts = {}
	for _, e in ipairs(N.encarts) do
		habit.encarts[e.nom] = encart(f, e)
	end
	local FA = N.fondAutre
	local voile = f:CreateTexture(nil, "BACKGROUND")
	voile:SetTexture(1, 1, 1, FA.a)
	voile:SetPoint("TOPLEFT", f, "TOPRIGHT", FA[1], FA[2])
	voile:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	habit.voileAutre = voile
	-- la separation des deux moities
	local S = N.separation
	local coinBas = f:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(coinBas, ART.coinBas, true)
	coinBas:SetWidth(S.coinCote)
	coinBas:SetHeight(S.coinCote)
	coinBas:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", S.coin[1], S.coin[2])
	local filet = f:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(filet, ART.separation, true)
	filet:SetWidth(S.filetL)
	filet:SetPoint("TOPLEFT", f, "TOPRIGHT", S.haut[1], S.haut[2])
	filet:SetPoint("BOTTOMLEFT", coinBas, "TOPLEFT", 0, 0)
	habit.separation = { filet = filet, coin = coinBas }
	-- l'argent de l'autre : bord dore a 0,6, sa bourse
	local B = N.bordAutre
	local bord = CreateFrame("Frame", nil, f)
	bord:EnableMouse(false)
	bord:SetPoint("BOTTOMLEFT", f, "TOPRIGHT", B[1], B[2])
	bord:SetPoint("TOPRIGHT", f, "TOPRIGHT", B[3], B[4])
	habit.bordAutre = bord
	habit.bordDore = bordDore(f, bord, B.a)
	poser(TradeRecipientMoneyFrame, "TOPRIGHT", f, "TOPRIGHT", N.argentAutre[1], N.argentAutre[2])
	poser(TradePlayerInputMoneyFrame, "TOPLEFT", f, "TOPLEFT", N.saisie[1], N.saisie[2])

	-- le portrait de l'autre et son coin de metal, au-dessus du metal
	local A = N.autre
	local dessus = CreateFrame("Frame", nil, f)
	dessus:SetAllPoints(f)
	dessus:SetFrameLevel(f:GetFrameLevel() + 21)
	dessus:EnableMouse(false)
	local coin = dessus:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(coin, ART.coinPortrait)
	coin:SetPoint("TOPLEFT", f, "TOPRIGHT", A.coin[1], A.coin[2])
	local portrait = dessus:CreateTexture(nil, "ARTWORK")
	portrait:SetWidth(N.portrait.cote)
	portrait:SetHeight(N.portrait.cote)
	portrait:SetPoint("TOPLEFT", coin, "TOPLEFT", A.portrait[1], A.portrait[2])
	habit.coinAutre, habit.portraitAutre = coin, portrait

	-- les noms, recopies au-dessus du metal
	habit.noms = {}
	for cle, fs in pairs({ joueur = TradeFramePlayerNameText, autre = TradeFrameRecipientNameText }) do
		local P = N.noms[cle]
		fs:SetWidth(P[3])
		fs:SetHeight(P[4])
		poser(fs, "TOPLEFT", f, "TOPLEFT", P[1], P[2])
		local copie = Gb.Recopier(fs, dessus, GameFontNormal)
		copie:SetWidth(P[3])
		copie:SetHeight(P[4])
		habit.noms[cle] = copie
	end

	-- surbrillances, objets, textes d'enchantement
	local H = N.surbrillance
	for _, v in ipairs({ { TradeHighlightPlayer, H.joueur }, { TradeHighlightRecipient, H.autre } }) do
		v[1]:SetWidth(H.l)
		poser(v[1], "TOPLEFT", f, "TOPLEFT", v[2][1], v[2][2])
	end
	TradeHighlightPlayerEnchant:SetWidth(H.l)
	TradeHighlightRecipientEnchant:SetWidth(H.l)
	poser(TradePlayerItem1, "TOPLEFT", f, "TOPLEFT", N.objets.joueur[1], N.objets.joueur[2])
	poser(TradeRecipientItem1, "TOPLEFT", f, "TOPLEFT", N.objets.autre[1], N.objets.autre[2])
	poser(TradeFramePlayerEnchantText, "TOPLEFT", f, "TOPLEFT", N.enchant[1], N.enchant[2])
	poser(TradeFrameRecipientEnchantText, "LEFT", TradeFramePlayerEnchantText, "LEFT", N.enchant[3], 0)

	-- les boutons, la croix
	poser(TradeFrameTradeButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.echanger[1], N.echanger[2])
	Gb.Croix(TradeFrameCloseButton, f)
	TradeFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)

	hooksecurefunc("TradeFrame_Update", T.ApresMaj)
	hooksecurefunc("TradeFrame_UpdatePlayerItem", T.ApresJoueur)
	hooksecurefunc("TradeFrame_UpdateTargetItem", T.ApresAutre)
end

T.Habiller()
