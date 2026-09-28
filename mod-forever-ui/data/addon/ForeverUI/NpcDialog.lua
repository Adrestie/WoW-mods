-- ForeverUI : le dialogue des PNJ (GossipFrame) et la fenetre de quete
-- (QuestFrame), a la DA de camelot (demande de l'utilisateur, 2026-09-28 :
-- « fait les PNJ », etape 1).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (GossipFrame.xml / .lua, QuestFrame.xml
-- / .lua, QuestFrameTemplates.xml, QuestInfo.lua de 3.3.5, FrameXML) :
--   GossipFrame et QuestFrame 384 x 512 a TOPLEFT (0, -104), HitRectInsets
--     (0, 30, 0, 70) ; UIPanelWindows : area "left" ; portrait 60 x 60 a
--     (7, -6) (SetPortraitTexture "npc" / "questnpc", sinon
--     UI-QuestLog-BookIcon), nom du PNJ dans GossipFrameNpcNameText /
--     QuestFrameNpcNameText (GossipFrameUpdate, QuestFrame_SetPortrait) ;
--     croix CENTER sur TOPRIGHT (-42, -31) ;
--   les panneaux (GossipFramePanelTemplate, QuestFramePanelTemplate, 384 x
--     512) : l'art UI-QuestGreeting-TopLeft / TopRight / BotLeft / BotRight
--     (sans nom, sauf <panneau>BotRight), la matiere <panneau>MaterialTopLeft
--     239 x 241 a (21, -75) et ses trois voisines (QuestFrame_SetMaterial),
--     UI-Quest-BotLeftPatch sous l'accueil ;
--   les fenetres a defilement (UIPanelScrollFrameTemplate) 300 x 334 a (23,
--     -81) : GossipGreetingScrollFrame, QuestDetail-, QuestProgress-,
--     QuestReward-, QuestGreetingScrollFrame ; enfants 300 x 334 ;
--   les boutons a BOTTOMLEFT (22 / 23, 72) et BOTTOMRIGHT (-39, 72 / 73) ;
--   QuestProgressTitleText a (5, -10) ;
--   les objets : QuestInfoItem1..10 (QuestInfo_ShowRewards, GetQuestItemInfo
--     hors journal), QuestProgressItem1..6 (QuestFrameProgressItems_Update,
--     GetQuestItemInfo "required").
--
-- RELEVE -- CAMELOT (blizzard_uipanels_game : [Family] mainline
-- gossipframe.xml, questframe.xml, questframetemplates.xml / .lua ; shared
-- gossipframeshared.lua ; blizzard_accessibilitytemplates questtextcontrast) :
--   GossipFrame et QuestFrame : ButtonFrameTemplate 338 x 496, portrait de
--     l'unite (SetPortraitToUnit, sinon le livre), titre = nom du PNJ
--     (SetTitle) ;
--   le fond : l'atlas QuestBG-Parchment (useAtlasSize) a (7, -62) ;
--   le dialogue : ScrollBox 300 x 403 a (8, -65), MinimalScrollBar a (6, -3)
--     / (6, 3) ; Au revoir BOTTOMRIGHT (-6, 4) ;
--   la quete : QuestScrollFrameTemplate 300 x 403 a (5, -65), barre
--     scrollBarX 9, scrollBarTopY -2, bas par defaut 5 (ScrollDefine) ;
--     enfants 300 x 403 (recompense : 300 x 334) ; matiere a (7, -62), 239 x
--     300 / 64 x 300 / 239 x 138 / 64 x 138 ; boutons BOTTOMLEFT (6, 4) et
--     BOTTOMRIGHT (-6, 4) ; QuestProgressTitleText a (10, -10) ;
--   les objets : LargeItemButtonTemplate (le meme qu'en 3.3.5) et le contour
--     de qualite de l'icone (SetItemButtonQuality).
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : les cadres et la
-- logique du client restent, poses aux places de camelot. Le portrait suit
-- la regle VALIDEE (48, centre sur le trou de l'anneau, Inspect.lua). Le
-- dialogue garde le ScrollFrame de 3.3.5 (pas de ScrollBox), a la place de
-- celle de camelot. Le bouton Annuler de la recompense reste (camelot ne
-- montre que Terminer la quete) : il passe a droite comme les autres.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local D = {}
ForeverUI.DialoguePNJ = D

local SEP = string.char(92)

local N = {
	fenetre = { 338, 496 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	parchemin = { 7, -62, droite = -9 },
	gauche = { 6, 4 }, droite = { -6, 4 },
	-- le dialogue
	dialogue = { defile = { 8, -65, 300, 403 }, barre = { 6, -3, 3 } },
	-- la quete
	quete = { defile = { 5, -65, 300, 403 }, barre = { 9, -2, 5 }, enfant = 403, enfantRecompense = 334,
		matiere = { 7, -62, haut = 300, bas = 138, gauche = 239, droite = 64 },
		titreProgres = { 10, -10 } },
}

local ART = {
	parchemin = "questbg-parchment",
	livre = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestLog-BookIcon",
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- l'art de 3.3.5 d'un panneau : ses quatre morceaux UI-QuestGreeting et la
-- piece du bas de l'accueil
local function eteindrePanneau(p)
	for _, r in ipairs({ p:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local f = r:GetTexture()
			if type(f) == "string" then
				f = string.lower(f)
				if string.find(f, "questgreeting", 1, true) or string.find(f, "botleftpatch", 1, true) then
					r:SetAlpha(0)
				end
			end
		end
	end
end

-- ButtonFrameTemplate a portrait, le parchemin, la croix ; le nom du PNJ
-- passe dans la barre de titre. o (facultatif) : { hauteur, page = hauteur
-- du parchemin } -- 424 et 357 / 334 pour les pages de l'etape 2, sinon 496
-- et la hauteur de l'atlas.
local function habiller(f, nom, portraitClient, croix, o)
	o = o or {}
	portraitClient:SetAlpha(0)
	nom:SetAlpha(0)
	f:SetWidth(N.fenetre[1])
	f:SetHeight(o.hauteur or N.fenetre[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = nom:GetText(),
	})
	local function suivre() habit.titre:SetText(nom:GetText() or "") end
	hooksecurefunc(nom, "SetText", suivre)
	hooksecurefunc(nom, "SetFormattedText", suivre)
	-- le parchemin en BORDER : camelot le pose au-dessus de la pierre et des
	-- stries du cadre par un sous-calque ; 3.3.5 n'en a pas, et dans le meme
	-- calque la pierre passait devant (dialogue, 28/09 : « le fond n'est pas
	-- correct »). Les panneaux et leur matiere, cadres fils, restent dessus.
	local fond = f:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(fond, ART.parchemin)
	if o.page then fond:SetHeight(o.page) end
	fond:SetPoint("TOPLEFT", f, "TOPLEFT", N.parchemin[1], N.parchemin[2])
	habit.parchemin = fond
	Gb.Croix(croix, f)
	croix:SetFrameLevel(f:GetFrameLevel() + 22)
	f.foreverHabit = habit
	return habit
end

-- le portrait de l'unite, sinon le livre (GossipFrameUpdate,
-- QuestFrame_SetPortrait)
local function portrait(habit, unite)
	if UnitExists(unite) then
		SetPortraitTexture(habit.portrait, unite)
	else
		habit.portrait:SetTexture(ART.livre)
	end
end

-- le contour de qualite, sur l'icone de 39 d'un LargeItemButtonTemplate
local function contour(b, q)
	local icone = _G[b:GetName() .. "IconTexture"]
	local t = Gb.Contour(b)
	if icone and not b.foreverContourPose then
		t:ClearAllPoints()
		t:SetAllPoints(icone)
		b.foreverContourPose = true
	end
	Gb.ContourQualite(b, q)
end

-- LA BARRE SEULEMENT SI ELLE SERT (demande du 28/09 ; camelot :
-- scrollBarHideIfUnscrollable). Le client 3.3.5 sait le faire :
-- ScrollFrame_OnScrollRangeChanged cache la barre quand rien ne defile si la
-- fenetre porte scrollBarHideable. On lit aussi la plage a l'ouverture, le
-- client ne la relisant qu'a un changement.
-- SANS BARRE, LA PAGE PREND TOUT L'ESPACE (demande du 28/09) : le parchemin
-- s'etend sur le couloir de la barre, jusqu'au bord interieur droit, a la
-- meme marge qu'a gauche au regard de l'encart de camelot (4 / -6 : 7 /
-- -9) ; avec la barre, il reprend sa largeur d'atlas.
local function pagePleine(f, pleine)
	local h = f.foreverHabit
	local t = h and h.parchemin
	if not t then return end
	local P = N.parchemin
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", f, "TOPLEFT", P[1], P[2])
	if pleine then
		t:SetPoint("TOPRIGHT", f, "TOPRIGHT", P.droite, P[2])
	else
		local e = ForeverUI.AtlasEntry(ART.parchemin)
		t:SetWidth(e[6])
	end
end
D.PagePleine = pagePleine

-- LE CONTENU S'ADAPTE A LA BARRE (regle du 28/09, Gb.BarreSelonContenu) :
-- avec elle, la fenetre a defilement, son enfant et les textes du client
-- gardent leurs largeurs du XML ; sans elle, chacun s'etend jusqu'a laisser
-- A DROITE DE LA PAGE LA MEME MARGE QU'A GAUCHE (demande du 28/09 : « le
-- meme espace a gauche et a droite »). `largeurs` : { { objet, avec la
-- barre, sans la barre } }.
local function elargir(largeurs, avec)
	for _, v in ipairs(largeurs) do
		if v[1] then v[1]:SetWidth(avec and v[2] or v[3]) end
	end
end

-- la largeur qui laisse a droite de la page (sans barre : de N.parchemin[1]
-- a la largeur de la fenetre + N.parchemin.droite) la marge qu'un objet a a
-- gauche ; `gauche` : son bord gauche dans la fenetre
local function jusquAMarge(gauche)
	local P = N.parchemin
	return (N.fenetre[1] + P.droite) - (gauche - P[1]) - gauche
end

-- adapter : ce que la fenetre fait en plus de la page (la quete a quatre
-- zones : seule la visible decide, Gb.BarreSelonContenu ne l'appelle que
-- visible)
local function barreSiBesoin(fx, f, adapter)
	return Gb.BarreSelonContenu(fx, function(avec)
		pagePleine(f, not avec)
		if adapter then adapter(avec) end
	end)
end
D.BarreSiBesoin = barreSiBesoin

-- ------------------------------------------------------------ le dialogue

function D.ApresDialogue()
	local h = GossipFrame.foreverHabit
	if h then portrait(h, "npc") end
end

function D.HabillerDialogue()
	local f = GossipFrame
	if not f or f.foreverHabit then return end
	habiller(f, GossipFrameNpcNameText, GossipFramePortrait, GossipFrameCloseButton)
	eteindrePanneau(GossipFrameGreetingPanel)
	local S = N.dialogue
	local fx = GossipGreetingScrollFrame
	fx:SetWidth(S.defile[3])
	fx:SetHeight(S.defile[4])
	poser(fx, "TOPLEFT", f, "TOPLEFT", S.defile[1], S.defile[2])
	Gb.BarreA(GossipGreetingScrollFrameScrollBar, fx, S.barre[1], S.barre[2], S.barre[3])
	-- le contenu : la fenetre, son enfant, le texte d'accueil (270, a (10,
	-- -10) de l'enfant), les choix (300, a -10 du texte ; leur texte 275 :
	-- GossipTitleButtonTemplate, qui suit son bouton)
	local x, texteX = S.defile[1], S.defile[1] + 10
	local fxSans = jusquAMarge(x)
	local largeurs = { { fx, S.defile[3], fxSans }, { GossipGreetingScrollChildFrame, S.defile[3], fxSans },
		{ GossipGreetingText, 270, jusquAMarge(texteX) } }
	for i = 1, NUMGOSSIPBUTTONS do
		local b = _G["GossipTitleButton" .. i]
		if b then
			largeurs[#largeurs + 1] = { b, 300, jusquAMarge(x) }
			largeurs[#largeurs + 1] = { b:GetFontString(), 275, 275 + jusquAMarge(x) - 300 }
		end
	end
	barreSiBesoin(fx, f, function(avec) elargir(largeurs, avec) end)
	poser(GossipFrameGreetingGoodbyeButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.droite[1], N.droite[2])
	hooksecurefunc("GossipFrameUpdate", D.ApresDialogue)
end

-- ------------------------------------------------------------ la quete

function D.ApresPortraitQuete()
	local h = QuestFrame.foreverHabit
	if h then portrait(h, "questnpc") end
end

-- APRES QuestInfo_ShowRewards : le contour de qualite des objets, hors
-- journal (le journal a les siens, QuestLog.lua)
function D.ApresRecompenses()
	if QuestInfoFrame and QuestInfoFrame.questLog then return end
	for i = 1, MAX_NUM_ITEMS do
		local b = _G["QuestInfoItem" .. i]
		if b and b:IsShown() and b.type then
			local _, _, _, q = GetQuestItemInfo(b.type, b:GetID())
			contour(b, q)
		elseif b and b.foreverContour then
			b.foreverContour:Hide()
		end
	end
end

-- APRES QuestFrameProgressItems_Update : les objets demandes
function D.ApresProgres()
	for i = 1, MAX_REQUIRED_ITEMS do
		local b = _G["QuestProgressItem" .. i]
		if b and b:IsShown() and b.type == "required" then
			local _, _, _, q = GetQuestItemInfo("required", b:GetID())
			contour(b, q)
		elseif b and b.foreverContour then
			b.foreverContour:Hide()
		end
	end
end

function D.HabillerQuete()
	local f = QuestFrame
	if not f or f.foreverHabit then return end
	habiller(f, QuestFrameNpcNameText, QuestFramePortrait, QuestFrameCloseButton)
	local Q = N.quete
	local M = Q.matiere
	for _, nom in ipairs({ "QuestFrameGreetingPanel", "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel" }) do
		local p = _G[nom]
		eteindrePanneau(p)
		-- la matiere (QuestFrame_SetMaterial la montre et la cache)
		local hg = _G[nom .. "MaterialTopLeft"]
		hg:SetWidth(M.gauche)
		hg:SetHeight(M.haut)
		poser(hg, "TOPLEFT", f, "TOPLEFT", M[1], M[2])
		_G[nom .. "MaterialTopRight"]:SetWidth(M.droite)
		_G[nom .. "MaterialTopRight"]:SetHeight(M.haut)
		_G[nom .. "MaterialBotLeft"]:SetWidth(M.gauche)
		_G[nom .. "MaterialBotLeft"]:SetHeight(M.bas)
		_G[nom .. "MaterialBotRight"]:SetWidth(M.droite)
		_G[nom .. "MaterialBotRight"]:SetHeight(M.bas)
	end
	-- le contenu commun des pages de quete (QuestInfo.xml : 285 ;
	-- QuestInfoFrame 300 ; tout a 5 de l'enfant, QUEST_TEMPLATE_* : le titre a
	-- (5, -10), le reste dessous), de la progression (285 / 275 / 295, a 10
	-- de l'enfant) et de l'accueil (270 / 300 a 10, les titres 300 a 0 et leur
	-- texte 275) ; sans barre, chacun jusqu'a la marge qu'il a a gauche
	local x = Q.defile[1]
	local fxSans = jusquAMarge(x)
	local communs = { { QuestInfoFrame, 300, jusquAMarge(x) } }
	for _, n in ipairs({ "QuestInfoTitleHeader", "QuestInfoObjectivesText", "QuestInfoRewardText",
		"QuestInfoDescriptionHeader", "QuestInfoObjectivesHeader", "QuestInfoDescriptionText", "QuestInfoTimerText",
		"QuestInfoRewardsHeader", "QuestInfoItemChooseText", "QuestInfoReputationText", "QuestInfoObjectivesFrame",
		"QuestInfoRewardsFrame", "QuestInfoReputationsFrame", "QuestInfoRequiredMoneyFrame" }) do
		communs[#communs + 1] = { _G[n], 285, jusquAMarge(x + 5) }
	end
	for i = 1, 10 do communs[#communs + 1] = { _G["QuestInfoObjective" .. i], 285, jusquAMarge(x + 5) } end
	local progres, accueil = jusquAMarge(x + Q.titreProgres[1]), jusquAMarge(x + 10)
	local parPage = {
		QuestProgressScrollFrame = { { QuestProgressTitleText, 285, progres }, { QuestProgressText, 275, progres },
			{ QuestProgressRequiredItemsText, 295, progres } },
		QuestGreetingScrollFrame = { { GreetingText, 270, accueil }, { CurrentQuestsText, 300, accueil },
			{ AvailableQuestsText, 300, accueil } },
	}
	for i = 1, 32 do
		local b = _G["QuestTitleButton" .. i]
		if b then
			table.insert(parPage.QuestGreetingScrollFrame, { b, 300, jusquAMarge(x) })
			table.insert(parPage.QuestGreetingScrollFrame, { b:GetFontString(), 275, 275 + jusquAMarge(x) - 300 })
		end
	end
	-- la matiere de chaque panneau (239 + 64) : sans barre, jusqu'au bord de
	-- la page, comme le parchemin
	local matiere = jusquAMarge(M[1]) - M.droite
	for fx, p in pairs({ QuestGreetingScrollFrame = "QuestFrameGreetingPanel", QuestDetailScrollFrame = "QuestFrameDetailPanel",
		QuestProgressScrollFrame = "QuestFrameProgressPanel", QuestRewardScrollFrame = "QuestFrameRewardPanel" }) do
		parPage[fx] = parPage[fx] or {}
		table.insert(parPage[fx], { _G[p .. "MaterialTopLeft"], M.gauche, matiere })
		table.insert(parPage[fx], { _G[p .. "MaterialBotLeft"], M.gauche, matiere })
	end
	-- les fenetres a defilement et leurs enfants
	for _, v in ipairs({ { "QuestGreetingScrollFrame", "QuestGreetingScrollChildFrame", Q.enfant },
		{ "QuestDetailScrollFrame", "QuestDetailScrollChildFrame", Q.enfant },
		{ "QuestProgressScrollFrame", "QuestProgressScrollChildFrame", Q.enfant },
		{ "QuestRewardScrollFrame", "QuestRewardScrollChildFrame", Q.enfantRecompense } }) do
		local fx = _G[v[1]]
		fx:SetWidth(Q.defile[3])
		fx:SetHeight(Q.defile[4])
		poser(fx, "TOPLEFT", f, "TOPLEFT", Q.defile[1], Q.defile[2])
		_G[v[2]]:SetHeight(v[3])
		Gb.BarreA(_G[v[1] .. "ScrollBar"], fx, Q.barre[1], Q.barre[2], Q.barre[3])
		local largeurs = { { fx, Q.defile[3], fxSans }, { _G[v[2]], Q.defile[3], fxSans } }
		for _, c in ipairs(communs) do largeurs[#largeurs + 1] = c end
		for _, c in ipairs(parPage[v[1]] or {}) do largeurs[#largeurs + 1] = c end
		barreSiBesoin(fx, f, function(avec) elargir(largeurs, avec) end)
	end
	poser(QuestProgressTitleText, "TOPLEFT", QuestProgressScrollChildFrame, "TOPLEFT", Q.titreProgres[1], Q.titreProgres[2])
	-- les boutons : a gauche l'action, a droite le refus
	for _, b in ipairs({ QuestFrameAcceptButton, QuestFrameCompleteButton, QuestFrameCompleteQuestButton }) do
		poser(b, "BOTTOMLEFT", f, "BOTTOMLEFT", N.gauche[1], N.gauche[2])
	end
	for _, b in ipairs({ QuestFrameDeclineButton, QuestFrameGoodbyeButton, QuestFrameCancelButton, QuestFrameGreetingGoodbyeButton }) do
		poser(b, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.droite[1], N.droite[2])
	end
	hooksecurefunc("QuestFrame_SetPortrait", D.ApresPortraitQuete)
	hooksecurefunc("QuestInfo_ShowRewards", D.ApresRecompenses)
	hooksecurefunc("QuestFrameProgressItems_Update", D.ApresProgres)
end

-- ------------------------------------------------------------ etape 2

-- RELEVE -- CE QUE LE CLIENT CHARGE (ItemTextFrame.xml / .lua,
-- PetitionFrame.xml / .lua, GuildRegistrarFrame.xml / .lua de 3.3.5) :
--   les trois fenetres 384 x 512 a TOPLEFT (0, -104) ;
--   ItemTextFrame : art sans nom (Spellbook-Icon 58 x 58 a (10, -8),
--     UI-ItemText-TopLeft / BotLeft, UI-SpellbookPanel-TopRight / BotRight),
--     ItemTextMaterialTopLeft (21, -76) et ses voisines, ItemTextTitleText
--     CENTER (6, 230) (ItemTextGetItem), ItemTextCurrentPage TOP (10, -50),
--     ItemTextScrollFrame 280 x 355 TOPRIGHT (-66, -76) et ses fonds
--     ItemTextScrollFrameTop / Bottom / Middle, scrollBarHideable pose par le
--     client ; ItemTextPageText (0, -15) 270 x 304 ; Prev / Next CENTER sur
--     TOPLEFT (90, -56) et TOPRIGHT (-55, -56) ; ItemTextCloseButton ;
--   PetitionFrame : PetitionFramePortrait (GuildCharter-Icon) 58 x 58 a (10,
--     -8), art UI-QuestGreeting sans nom, PetitionFrameCharterTitle (30,
--     -95) et les lignes enchainees, nom dans PetitionFrameNpcNameText
--     (PetitionFrame_Update, SetFormattedText), boutons BOTTOMRIGHT (-40,
--     72) et BOTTOMLEFT (22, 72) ;
--   GuildRegistrarFrame : GuildRegistrarFramePortrait 60 x 60 a (7, -6) et
--     GuildRegistrarFrameNpcNameText (GuildRegistrar_OnShow), art
--     UI-QuestGreeting, UI-Quest-BotLeftPatch sous l'accueil,
--     AvailableServicesText (35, -100), GuildRegistrarPurchaseText (35, -95),
--     boutons BOTTOMRIGHT (-40, 72) et BOTTOMLEFT (22, 72).
--
-- RELEVE -- CAMELOT ([Family] mainline itemtextframe, petitionframe,
-- guildregistrarframe) :
--   ButtonFrameTemplate 338 x 424 (DEFAULT_ITEM_TEXT_FRAME_WIDTH / HEIGHT) ;
--   ItemTextFrame : ItemTextFramePageBg (QuestBG-Parchment) 299 x 357 a (7,
--     -62), matiere a (7, -62), ItemTextCurrentPage TOP (20, -35), Prev /
--     Next CENTER (75, -41) / (-23, -41), ItemTextScrollFrame de TOPRIGHT
--     (-31, -63) a BOTTOMLEFT (6, 6), barre scrollBarX 7, TopY -5, BottomY 5,
--     texte a (18, -15) 270 x 304, titre = ItemTextGetItem (SetTitle) ;
--   PetitionFrame : Bg (QuestBG-Parchment) 299 x 334 a (7, -62),
--     PetitionFrameCharterTitle (12, -80), boutons BOTTOMRIGHT (-6, 4) et
--     BOTTOMLEFT (4, 4) ;
--   GuildRegistrarFrame : Bg 299 x 334 a (7, -62), AvailableServicesText et
--     GuildRegistrarPurchaseText (20, -70), boutons (-6, 4) et (6, 4).
--
-- CE QUI DIFFERE, ET POURQUOI. Le portrait suit la regle VALIDEE (48 a (1,
-- 1,5)) : le livre, la charte ou le PNJ. Les regles VALIDEES sur le
-- dialogue valent pour le livre : la barre seulement si elle sert, la page
-- sur tout l'espace sans elle. Le mode livre agrandi (ParchmentLarge) et la
-- page pleine (ItemTextIsFullPage) n'existent pas en 3.3.5.
local P2 = {
	hauteur = 424,
	livre = { page = 357, defileHD = { -31, -63 }, defileBG = { 6, 6 }, barre = { 7, -5, 5 }, texte = { 18, -15 }, largeurTexte = 270,
		pageCourante = { 20, -35 }, precedent = { 75, -41 }, suivant = { -23, -41 } },
	petition = { page = 334, charte = { 12, -80 }, gauche = { 4, 4 } },
	registre = { page = 334, services = { 20, -70 }, achat = { 20, -70 } },
}

local ART2 = {
	livre = "Interface" .. SEP .. "Spellbook" .. SEP .. "Spellbook-Icon",
}

-- l'art sans nom d'une fenetre (avant de l'habiller : nos textures sont
-- sans nom aussi)
local function eteindreSansNom(f)
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then r:SetAlpha(0) end
	end
end

function D.HabillerLivre()
	local f = ItemTextFrame
	if not f or f.foreverHabit then return end
	local L = P2.livre
	eteindreSansNom(f)
	local habit = habiller(f, ItemTextTitleText, ItemTextTitleText, ItemTextCloseButton,
		{ hauteur = P2.hauteur, page = L.page })
	habit.portrait:SetTexture(ART2.livre)
	poser(ItemTextMaterialTopLeft, "TOPLEFT", f, "TOPLEFT", N.parchemin[1], N.parchemin[2])
	poser(ItemTextCurrentPage, "TOP", f, "TOP", L.pageCourante[1], L.pageCourante[2])
	poser(ItemTextPrevPageButton, "CENTER", f, "TOPLEFT", L.precedent[1], L.precedent[2])
	poser(ItemTextNextPageButton, "CENTER", f, "TOPRIGHT", L.suivant[1], L.suivant[2])
	local fx = ItemTextScrollFrame
	fx:ClearAllPoints()
	fx:SetPoint("TOPRIGHT", f, "TOPRIGHT", L.defileHD[1], L.defileHD[2])
	fx:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", L.defileBG[1], L.defileBG[2])
	for _, s in ipairs({ "Top", "Bottom", "Middle" }) do
		local t = _G["ItemTextScrollFrame" .. s]
		if t then t:SetAlpha(0) end
	end
	poser(ItemTextPageText, "TOPLEFT", ItemTextPageScrollChild, "TOPLEFT", L.texte[1], L.texte[2])
	Gb.BarreA(ItemTextScrollFrameScrollBar, fx, L.barre[1], L.barre[2], L.barre[3])
	-- le contenu : sans barre, la fenetre s'etend sur le couloir, le texte
	-- (270, a 18 de la fenetre a defilement) jusqu'a la marge qu'il a a
	-- gauche, la matiere (256 + 64) jusqu'au bord de la page
	local texteSans = jusquAMarge(L.defileBG[1] + L.texte[1])
	local matiere = jusquAMarge(N.parchemin[1]) - 64
	barreSiBesoin(fx, f, function(avec)
		fx:SetPoint("TOPRIGHT", f, "TOPRIGHT", L.defileHD[1] + (avec and 0 or Gb.COULOIR), L.defileHD[2])
		ItemTextPageText:SetWidth(avec and L.largeurTexte or texteSans)
		ItemTextMaterialTopLeft:SetWidth(avec and 256 or matiere)
		ItemTextMaterialBotLeft:SetWidth(avec and 256 or matiere)
	end)
end

function D.HabillerPetition()
	local f = PetitionFrame
	if not f or f.foreverHabit then return end
	local T = P2.petition
	local charte = PetitionFramePortrait:GetTexture()
	eteindrePanneau(f)
	local habit = habiller(f, PetitionFrameNpcNameText, PetitionFramePortrait, PetitionFrameCloseButton,
		{ hauteur = P2.hauteur, page = T.page })
	habit.portrait:SetTexture(charte)
	poser(PetitionFrameCharterTitle, "TOPLEFT", f, "TOPLEFT", T.charte[1], T.charte[2])
	poser(PetitionFrameCancelButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.droite[1], N.droite[2])
	for _, b in ipairs({ PetitionFrameSignButton, PetitionFrameRequestButton }) do
		poser(b, "BOTTOMLEFT", f, "BOTTOMLEFT", T.gauche[1], T.gauche[2])
	end
end

function D.ApresRegistre()
	local h = GuildRegistrarFrame.foreverHabit
	if h then portrait(h, "npc") end
end

function D.HabillerRegistre()
	local f = GuildRegistrarFrame
	if not f or f.foreverHabit then return end
	local R = P2.registre
	eteindrePanneau(f)
	eteindrePanneau(GuildRegistrarGreetingFrame)
	habiller(f, GuildRegistrarFrameNpcNameText, GuildRegistrarFramePortrait, GuildRegistrarFrameCloseButton,
		{ hauteur = P2.hauteur, page = R.page })
	poser(AvailableServicesText, "TOPLEFT", f, "TOPLEFT", R.services[1], R.services[2])
	poser(GuildRegistrarPurchaseText, "TOPLEFT", f, "TOPLEFT", R.achat[1], R.achat[2])
	for _, b in ipairs({ GuildRegistrarFrameGoodbyeButton, GuildRegistrarFrameCancelButton }) do
		poser(b, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.droite[1], N.droite[2])
	end
	poser(GuildRegistrarFramePurchaseButton, "BOTTOMLEFT", f, "BOTTOMLEFT", N.gauche[1], N.gauche[2])
	hooksecurefunc("GuildRegistrar_OnShow", D.ApresRegistre)
end

D.HabillerDialogue()
D.HabillerQuete()
D.HabillerLivre()
D.HabillerPetition()
D.HabillerRegistre()
