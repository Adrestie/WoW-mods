-- ForeverUI : la fenetre Social, habillee comme camelot (docs : memoire
-- foreverui-social). Ce fichier porte la fenetre, ses onglets et la page
-- Contacts (amis et ignores) ; les pages Qui, Guilde, Canaux et Raid sont
-- dans SocialWho.lua, SocialGuild.lua, SocialChat.lua et SocialRaid.lua, qui
-- s'inscrivent par S.inscrirePage.
--
-- DECISIONS DE L'UTILISATEUR (2026-09-26) : la structure de camelot plus les
-- onglets de WotLK qui lui manquent ; la guilde en onglet ; les ignores en
-- SOUS-ONGLET "Ignore" a cote de "Friends" ; rien de Battle.net (le serveur
-- ne l'a pas).
--
-- RELEVE -- camelot/friendsframe.xml et .lua, shareduipaneltemplates
-- (camelot et mainline), nineslicelayouts (+ les corrections camelot),
-- tabsystemtemplates :
--   fenetre      ButtonFrameTemplate 385 x 424 ; fond UI-Background-Rock en
--                mosaique (2,-21 / -2,2) ; _UI-Frame-TopTileStreaks 43 de haut
--                (6,-21 / -2,-21) ; metal PortraitFrameTemplate : coin
--                portrait (-13, 16), haut droit (2, 16), bas gauche (-13, -8),
--                bas droit (2, -8) ; portrait Battlenet-Portrait 60 x 60 a
--                (-5, 7) ; titre GameFontNormal TOP (0, -5) dans une bande de
--                20 (58,-1 / -24,-1) ; croix 24 x 24 a TOPRIGHT (-2, 1)
--   encadre      InsetFrameTemplate, 4,-83 / -6,26 (ButtonFrameTemplate_
--                ShowButtonBar)
--   onglets bas  PanelTabButtonTemplate, 32 de haut, texte + 20 (au moins
--                gauche + droite), le premier TOPLEFT sur le BOTTOMLEFT (5, 2),
--                les suivants a +3 ; actif uiframe-activetab-* (42), inactif
--                uiframe-tab-*-c60 (36) ; texte CENTER (0, 2), (0, -3) choisi ;
--                GameFontNormalSmall, GameFontHighlightSmall choisi
--   sous-onglets FriendsTabHeader : TabSystem a (18, -60), onglets de 24 de
--                haut, largeur bornee a 100..150, espacement 1, meme art
--                RETOURNE (isTabOnTop), texte (0, 0) choisi, (0, -3) sinon
--   liste        de (8, -87) au BOTTOMRIGHT de l'encadre (-22, 2) ; barre
--                MinimalScrollBar a droite ; ligne d'ami 34 : fond de couleur
--                (0,-1 / 0,1), etat 16 x 16 a (4, -3), nom FriendsFont_Normal
--                a (20, -4), info FriendsFont_Small dessous (0, -3) ;
--                surbrillance UI-QuestLogTitleHighlight en ADD ; la selection
--                verrouille la surbrillance ; separateur
--                UI-FriendsFrame-OnlineDivider de 16
--   boutons      UIPanelButtonTemplate 134 x 21, BOTTOMLEFT (4, 4) et
--                BOTTOMRIGHT (-6, 4)
--
-- CE QUI VIENT DE WotLK (FriendsFrame.lua du client) : les donnees
-- (GetFriendInfo, GetIgnoreName...), l'ordre des lignes -- en ligne, un
-- separateur, hors ligne --, le texte "Nom, Level 80 Warrior", les couleurs
-- FRIENDS_*, le menu du clic droit (FriendsFrame_ShowDropdown), l'infobulle
-- (FriendsFrameTooltip_Show), et ce que font les boutons
-- (FriendsFrameAddFriendButton_OnClick, FriendsFrameSendMessageButton_OnClick,
-- FriendsFrameUnsquelchButton_OnClick). La liste des ignores reprend son
-- en-tete IGNORED.
--
-- RETIRES (2026-09-26, demande de l'utilisateur) : tout ce qui touche au
-- parrainage (le bouton d'invocation) et au chat vocal (les muets, leur
-- en-tete MUTED et le bouton Mute Player).
--
-- ECARTS : camelot titre "Contacts" (CONTACTS_TAB_TITLE, CONTACTS_LIST_TITLE)
-- et 3.3.5 n'a pas ces chaines ; l'onglet et le titre prennent FRIENDS et
-- FRIENDS_LIST / IGNORE_LIST, dans la langue du client.
--
-- COMMENT ELLE VIT. FriendsFrame reste le panneau du client -- ToggleFriends
-- Frame, le micro-bouton, Echap, la place a gauche, et l'onglet choisi
-- (FriendsFrame.selectedTab). Notre fenetre est sa fille. L'ecran de WotLK se
-- tait en entier, le panneau cesse d'attraper la souris, et notre fenetre
-- montre la page de l'onglet choisi. Ce que les sous-cadres du client font en
-- s'affichant (SetWhoToUI, GuildRoster...), la page le refait.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local S = {}
ForeverUI.Social = S

local SEP = string.char(92)

-- une table : Lua 5.1 limite a 60 les valeurs capturees par une fonction
local G = {
	largeur = 385, hauteur = 424,
	roche = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock",
	-- battlenet-portrait affine (tools/affiner_portrait.py) : 128, mipmaps,
	-- non compresse ; l'original 64 en DXT5 paraissait pixelise
	portrait = "Interface" .. SEP .. "ForeverUI" .. SEP .. "friendsframe" .. SEP .. "battlenet-portrait-hd",
	portraitCote = 60, portraitX = -5, portraitY = 7,
	titreX1 = 58, titreX2 = -24, titreY = -1, titreH = 20, titreTexteY = -5,
	croix = 24, croixX = -2, croixY = 1,
	encadreX1 = 4, encadreY1 = -83, encadreX2 = -6, encadreY2 = 26,
	listeX = 8, listeY = -87, listeX2 = -22, listeY2 = 2,
	boutonL = 134, boutonH = 21, boutonBas = 4, boutonGauche = 4, boutonDroite = -6,
	ongletH = 32, ongletPremierX = 5, ongletPremierY = 2, ongletEcart = 3, ongletMarge = 20,
	sousX = 18, sousY = -60, sousH = 24, sousMin = 100, sousMax = 150, sousEcart = 1,
	ligneAmi = 34, ligneCourte = 16,
	etatCote = 16, etatX = 4, etatY = -3, nomX = 20, nomY = -4, infoY = -3,
	surbrillance = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestLogTitleHighlight",
	surbrillanceIgnore = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight",
	teinteSurbrillance = { 0.243, 0.570, 1 },
	separateur = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "UI-FriendsFrame-OnlineDivider",
	etat = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "StatusIcon-",
}

-- LE METAL de PortraitFrameTemplate, avec les corrections de camelot
-- (nineslicelayoutoverrides.lua) : les coins de droite a x = 2, ceux du bas a
-- y = -8.
local METAL = {
	{ cle = "hg", nom = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ cle = "hd", nom = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ cle = "bg", nom = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ cle = "bd", nom = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

-- LES ONGLETS. Actifs dans la feuille de base (camelot n'en a pas de c60),
-- inactifs dans la c60.
local ONGLET_ART = {
	actifG = "uiframe-activetab-left", actifM = "_uiframe-activetab-center", actifD = "uiframe-activetab-right",
	inactifG = "uiframe-tab-left-c60", inactifM = "_uiframe-tab-center-c60", inactifD = "uiframe-tab-right-c60",
}

-- LES ONGLETS DU BAS : celui des contacts, puis ceux de WotLK. L'identifiant
-- est celui de l'onglet du client, FriendsFrameTab<id>.
local ONGLETS = {
	{ id = 1, texte = "FRIENDS" },
	{ id = 2, texte = "WHO" },
	{ id = 3, texte = "GUILD" },
	{ id = 4, texte = "CHAT" },
	{ id = 5, texte = "RAID" },
}
local SOUS_ONGLETS = {
	{ id = 1, texte = "FRIENDS", titre = "FRIENDS_LIST" },
	{ id = 2, texte = "IGNORE", titre = "IGNORE_LIST" },
}

local function txt(cle)
	return _G[cle] or cle
end

local function couleur(nom, defaut)
	local c = _G[nom]
	if type(c) == "table" and c.r then
		return c.r, c.g, c.b, c.a
	end
	return defaut[1], defaut[2], defaut[3], defaut[4]
end

-- ------------------------------------------------------------------ le cadre

local function construireCadre(f)
	local roche = f:CreateTexture(nil, "BACKGROUND")
	roche:SetTexture(G.roche, true)
	if roche.SetHorizTile then roche:SetHorizTile(true) roche:SetVertTile(true) end
	roche:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -21)
	roche:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)

	local stries = f:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(stries, "_ui-frame-toptilestreaks", true)
	stries:SetHeight(43)
	stries:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -21)
	stries:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)

	local metal = CreateFrame("Frame", nil, f)
	metal:SetAllPoints(f)
	metal:SetFrameLevel(f:GetFrameLevel() + 20)
	local p = {}
	for _, coin in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, coin.nom)
		t:SetPoint(coin.point, metal, coin.point, coin.x, coin.y)
		p[coin.cle] = t
	end
	local function bord(nom, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, nom)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	bord("_ui-frame-metal-edgetop", "TOPLEFT", p.hg, "TOPRIGHT", "TOPRIGHT", p.hd, "TOPLEFT")
	bord("_ui-frame-metal-edgebottom", "BOTTOMLEFT", p.bg, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bd, "BOTTOMLEFT")
	bord("!ui-frame-metal-edgeleft", "TOPLEFT", p.hg, "BOTTOMLEFT", "BOTTOMLEFT", p.bg, "TOPLEFT")
	bord("!ui-frame-metal-edgeright", "TOPRIGHT", p.hd, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bd, "TOPRIGHT")

	local cadrePortrait = CreateFrame("Frame", nil, f)
	cadrePortrait:SetAllPoints(f)
	cadrePortrait:SetFrameLevel(f:GetFrameLevel() + 19)
	local portrait = cadrePortrait:CreateTexture(nil, "OVERLAY")
	portrait:SetWidth(G.portraitCote)
	portrait:SetHeight(G.portraitCote)
	portrait:SetPoint("TOPLEFT", f, "TOPLEFT", G.portraitX, G.portraitY)
	portrait:SetTexture(G.portrait)
	f.portrait = portrait

	local bandeau = CreateFrame("Frame", nil, f)
	bandeau:SetFrameLevel(f:GetFrameLevel() + 21)
	bandeau:SetHeight(G.titreH)
	bandeau:SetPoint("TOPLEFT", f, "TOPLEFT", G.titreX1, G.titreY)
	bandeau:SetPoint("TOPRIGHT", f, "TOPRIGHT", G.titreX2, G.titreY)
	f.titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.titre:SetPoint("TOP", bandeau, "TOP", 0, G.titreTexteY)
	f.bandeau = bandeau

	-- LA CROIX : elle ferme le panneau du client, comme la sienne.
	local croix = CreateFrame("Button", "ForeverUISocialCloseButton", f)
	croix:SetWidth(G.croix)
	croix:SetHeight(G.croix)
	croix:SetFrameLevel(f:GetFrameLevel() + 22)
	croix:SetPoint("TOPRIGHT", f, "TOPRIGHT", G.croixX, G.croixY)
	for _, etat in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(etat[3])
		croix[etat[1]](croix, e and e[1] or "")
		local t = croix[etat[2]](croix)
		if t then
			ForeverUI.SetAtlas(t, etat[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(croix)
			if etat[3] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
	croix:SetScript("OnClick", function() HideUIPanel(FriendsFrame) end)
	f.croix = croix
end

-- --------------------------------------------------------------- les onglets

-- Une texture d'onglet : son element, et pour les onglets du haut le meme
-- RETOURNE -- une rotation d'un demi-tour, c'est echanger les deux bords en
-- largeur et en hauteur (SetRotation effacerait le rectangle d'atlas).
local function morceauOnglet(b, couche, atlas, retourne)
	local t = b:CreateTexture(nil, couche)
	ForeverUI.SetAtlas(t, atlas)
	if retourne then
		local e = ForeverUI.AtlasEntry(atlas)
		if e then t:SetTexCoord(e[3], e[2], e[5], e[4]) end
	end
	return t
end

-- PanelTabButtonTemplate (bas) ou TabSystemButtonArtTemplate + isTabOnTop
-- (haut). Les deux jeux de trois morceaux : actifs et inactifs, et la
-- surbrillance, l'inactif en ADD a 0,4.
local function creerOnglet(parent, nom, enHaut)
	local b = CreateFrame("Button", nom, parent)
	b:SetHeight(enHaut and G.sousH or G.ongletH)
	local a = {}
	a.actifG = morceauOnglet(b, "BACKGROUND", ONGLET_ART.actifG, enHaut)
	a.actifD = morceauOnglet(b, "BACKGROUND", ONGLET_ART.actifD, enHaut)
	a.actifM = morceauOnglet(b, "BACKGROUND", ONGLET_ART.actifM, enHaut)
	a.g = morceauOnglet(b, "BACKGROUND", ONGLET_ART.inactifG, enHaut)
	a.d = morceauOnglet(b, "BACKGROUND", ONGLET_ART.inactifD, enHaut)
	a.m = morceauOnglet(b, "BACKGROUND", ONGLET_ART.inactifM, enHaut)
	a.sg = morceauOnglet(b, "HIGHLIGHT", ONGLET_ART.inactifG, enHaut)
	a.sd = morceauOnglet(b, "HIGHLIGHT", ONGLET_ART.inactifD, enHaut)
	a.sm = morceauOnglet(b, "HIGHLIGHT", ONGLET_ART.inactifM, enHaut)
	for _, t in ipairs({ a.sg, a.sd, a.sm }) do
		t:SetBlendMode("ADD")
		t:SetAlpha(0.4)
	end
	if enHaut then
		-- HandleRotation : le morceau "droit" retourne passe a gauche ;
		-- SetTabHeight(24) pose toutes les hauteurs
		for _, t in pairs(a) do t:SetHeight(G.sousH) end
		a.actifD:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -7, 0)
		a.actifG:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
		a.d:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -6, 0)
		a.g:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
		a.actifM:SetPoint("TOPLEFT", a.actifD, "TOPRIGHT", 0, 0)
		a.actifM:SetPoint("BOTTOMRIGHT", a.actifG, "BOTTOMLEFT", 0, 0)
		a.m:SetPoint("TOPLEFT", a.d, "TOPRIGHT", 0, 0)
		a.m:SetPoint("BOTTOMRIGHT", a.g, "BOTTOMLEFT", 0, 0)
		a.sg:SetPoint("TOPRIGHT", a.g, "TOPRIGHT", 0, 0)
		a.sd:SetPoint("TOPLEFT", a.d, "TOPLEFT", 0, 0)
		a.sm:SetPoint("TOPLEFT", a.m, "TOPLEFT", 0, 0)
		a.sm:SetPoint("BOTTOMRIGHT", a.m, "BOTTOMRIGHT", 0, 0)
	else
		a.actifG:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 0)
		a.actifD:SetPoint("TOPRIGHT", b, "TOPRIGHT", 8, 0)
		a.g:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 0)
		a.d:SetPoint("TOPRIGHT", b, "TOPRIGHT", 7, 0)
		a.actifM:SetPoint("TOPLEFT", a.actifG, "TOPRIGHT", 0, 0)
		a.actifM:SetPoint("BOTTOMRIGHT", a.actifD, "BOTTOMLEFT", 0, 0)
		a.m:SetPoint("TOPLEFT", a.g, "TOPRIGHT", 0, 0)
		a.m:SetPoint("BOTTOMRIGHT", a.d, "BOTTOMLEFT", 0, 0)
		a.sg:SetPoint("TOPLEFT", a.g, "TOPLEFT", 0, 0)
		a.sd:SetPoint("TOPRIGHT", a.d, "TOPRIGHT", 0, 0)
		a.sm:SetPoint("TOPLEFT", a.m, "TOPLEFT", 0, 0)
		a.sm:SetPoint("BOTTOMRIGHT", a.m, "BOTTOMRIGHT", 0, 0)
	end
	b.art = a
	b.enHaut = enHaut
	local fs = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fs:SetHeight(10)
	b:SetFontString(fs)
	b.texte = fs
	return b
end

-- SetTabSelected / PanelTemplates_SelectTab : l'art actif, la police claire,
-- le texte qui descend (bas) ou remonte (haut), l'onglet choisi desactive.
local function choisirOnglet(b, choisi, actif)
	local a = b.art
	for _, t in ipairs({ a.actifG, a.actifM, a.actifD }) do
		if choisi then t:Show() else t:Hide() end
	end
	for _, t in ipairs({ a.g, a.m, a.d }) do
		if choisi then t:Hide() else t:Show() end
	end
	local police = choisi and GameFontHighlightSmall or (actif and GameFontNormalSmall or GameFontDisableSmall)
	b.texte:SetFontObject(police)
	b:SetNormalFontObject(police)
	local y
	if b.enHaut then
		y = choisi and 0 or -3
	else
		y = choisi and -3 or 2
	end
	b.texte:ClearAllPoints()
	b.texte:SetPoint("CENTER", b, "CENTER", 0, y)
	if choisi or not actif then b:Disable() else b:Enable() end
end

-- PanelTemplates_TabResize / TabSystemButtonMixin:UpdateTabWidth
local function largeurOnglet(b)
	local texte = b.texte:GetStringWidth() or 0
	local g = ForeverUI.AtlasEntry(ONGLET_ART.inactifG)
	local d = ForeverUI.AtlasEntry(ONGLET_ART.inactifD)
	local cotes = (g and g[6] or 35) + (d and d[6] or 37)
	if b.enHaut then
		local l = cotes + 20
		if l < texte then l = texte + 10 end
		return math.max(G.sousMin, math.min(G.sousMax, l))
	end
	return math.max(cotes, texte + G.ongletMarge)
end

-- les onglets du bas, pour les autres fenetres (le navigateur de raid)
S.creerOnglet, S.choisirOnglet, S.largeurOnglet = creerOnglet, choisirOnglet, largeurOnglet

-- ------------------------------------------------------------------ la liste

local LIGNE = {}                        -- les lignes creees, reutilisees

local function creerLigne(n)
	local l = CreateFrame("Button", "ForeverUISocialRow" .. n, S.liste)
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	l.fond = l:CreateTexture(nil, "BACKGROUND")
	l.fond:SetPoint("TOPLEFT", l, "TOPLEFT", 0, -1)
	l.fond:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", 0, 1)
	l.etat = l:CreateTexture(nil, "ARTWORK")
	l.etat:SetWidth(G.etatCote)
	l.etat:SetHeight(G.etatCote)
	l.etat:SetPoint("TOPLEFT", l, "TOPLEFT", G.etatX, G.etatY)
	l.nom = l:CreateFontString(nil, "ARTWORK", "FriendsFont_Normal")
	l.nom:SetJustifyH("LEFT")
	l.nom:SetHeight(12)
	l.info = l:CreateFontString(nil, "ARTWORK", "FriendsFont_Small")
	l.info:SetJustifyH("LEFT")
	l.info:SetHeight(10)
	l.info:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, G.infoY)
	l.info:SetPoint("TOPRIGHT", l.nom, "BOTTOMRIGHT", 0, G.infoY)
	l.trait = l:CreateTexture(nil, "ARTWORK")
	l.trait:SetTexture(G.separateur)
	l.trait:SetAllPoints(l)
	l.titre = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
	l.titre:SetPoint("LEFT", l, "LEFT", 5, 1)
	l:SetHighlightTexture(G.surbrillance)
	local s = l:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", l, "TOPLEFT", 0, -1)
		s:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", 0, 1)
	end
	l:SetScript("OnClick", function(self, bouton) S.cliquer(self, bouton) end)
	l:SetScript("OnEnter", function(self)
		if self.sorte == "ami" and FriendsFrameTooltip_Show then
			FriendsFrameTooltip_Show(self)
		end
	end)
	l:SetScript("OnLeave", function()
		if FriendsTooltip then
			FriendsTooltip.button = nil
			FriendsTooltip:Hide()
		end
	end)
	return l
end

-- Poser une ligne selon ce qu'elle porte : "ami", "trait", "entete",
-- "ignore". Les elements des autres sortes s'effacent.
local function poserLigne(l, e)
	l.sorte = e.sorte
	local ami, trait, entete = e.sorte == "ami", e.sorte == "trait", e.sorte == "entete"
	local ignore = e.sorte == "ignore"
	l:SetHeight(ami and G.ligneAmi or G.ligneCourte)
	if ami then l.fond:Show() else l.fond:Hide() end
	if ami then l.etat:Show() else l.etat:Hide() end
	if ami or ignore then l.nom:Show() else l.nom:Hide() end
	if ami then l.info:Show() else l.info:Hide() end
	if trait then l.trait:Show() else l.trait:Hide() end
	if entete then l.titre:Show() else l.titre:Hide() end
	l:EnableMouse(ami or ignore)
	l:UnlockHighlight()

	local s = l:GetHighlightTexture()
	l.nom:ClearAllPoints()
	if ami then
		l.nom:SetFontObject(FriendsFont_Normal)
		l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", G.nomX, G.nomY)
		l.nom:SetPoint("TOPRIGHT", l, "TOPRIGHT", -4, G.nomY)
		if s then
			s:SetTexture(G.surbrillance)
			s:SetVertexColor(G.teinteSurbrillance[1], G.teinteSurbrillance[2], G.teinteSurbrillance[3])
		end
	elseif ignore then
		-- FriendsFrameIgnoreButtonTemplate : GameFontNormal a (10, 1)
		l.nom:SetFontObject(GameFontNormal)
		l.nom:SetPoint("LEFT", l, "LEFT", 10, 1)
		l.nom:SetPoint("RIGHT", l, "RIGHT", -4, 1)
		if s then
			s:SetTexture(G.surbrillanceIgnore)
			s:SetVertexColor(1, 1, 1)
		end
	end

	l.id = e.index
	l.squelch = e.squelch
	l.buttonType = ami and FRIENDS_BUTTON_TYPE_WOW or nil
	if ami then
		-- FriendsFrame_SetButton, pour un ami du jeu
		local nom, niveau, classe, zone, connecte, statut = GetFriendInfo(e.index)
		l.nomAmi, l.connecte = nom, connecte
		if connecte then
			l.fond:SetTexture(couleur("FRIENDS_WOW_BACKGROUND_COLOR", { 1.0, 0.824, 0.0, 0.05 }))
			if statut == CHAT_FLAG_AFK then
				l.etat:SetTexture(G.etat .. "Away")
			elseif statut == CHAT_FLAG_DND then
				l.etat:SetTexture(G.etat .. "DnD")
			else
				l.etat:SetTexture(G.etat .. "Online")
			end
			l.nom:SetText((nom or "") .. ", " .. string.format(txt("FRIENDS_LEVEL_TEMPLATE"), niveau or 0, classe or ""))
			l.nom:SetTextColor(couleur("FRIENDS_WOW_NAME_COLOR", { 0.996, 0.882, 0.361 }))
		else
			l.fond:SetTexture(couleur("FRIENDS_OFFLINE_BACKGROUND_COLOR", { 0.588, 0.588, 0.588, 0.05 }))
			l.etat:SetTexture(G.etat .. "Offline")
			l.nom:SetText(nom or "")
			l.nom:SetTextColor(couleur("FRIENDS_GRAY_COLOR", { 0.486, 0.518, 0.541 }))
		end
		l.info:SetText(zone or "")
		l.info:SetTextColor(couleur("FRIENDS_GRAY_COLOR", { 0.486, 0.518, 0.541 }))
		if GetSelectedFriend() == e.index then l:LockHighlight() end
	elseif ignore then
		local nom = GetIgnoreName(e.index)
		if FriendsFrame.selectedSquelchType == SQUELCH_TYPE_IGNORE and GetSelectedIgnore() == e.index then
			l:LockHighlight()
		end
		l.nom:SetText(nom or txt("UNKNOWN"))
		l.nom:SetTextColor(couleur("NORMAL_FONT_COLOR", { 1, 0.82, 0 }))
	elseif entete then
		l.titre:SetText(e.texte)
	end
end

-- CE QUE LA LISTE MONTRE, dans l'ordre de WotLK.
local function entrees()
	local liste = {}
	if S.sousOnglet() == 2 then
		-- IgnoreList_Update : les ignores
		local ignores = GetNumIgnores() or 0
		if ignores > 0 then
			liste[#liste + 1] = { sorte = "entete", texte = txt("IGNORED") }
			for i = 1, ignores do
				liste[#liste + 1] = { sorte = "ignore", index = i, squelch = SQUELCH_TYPE_IGNORE }
			end
		end
	else
		-- FriendsList_Update : en ligne, un separateur, hors ligne
		local total, enLigne = GetNumFriends()
		total, enLigne = total or 0, enLigne or 0
		for i = 1, enLigne do
			liste[#liste + 1] = { sorte = "ami", index = i }
		end
		if enLigne > 0 and total > enLigne then
			liste[#liste + 1] = { sorte = "trait" }
		end
		for i = enLigne + 1, total do
			liste[#liste + 1] = { sorte = "ami", index = i }
		end
	end
	return liste
end

local function hauteurDe(e)
	return e.sorte == "ami" and G.ligneAmi or G.ligneCourte
end

function S.poserListe()
	local liste = S.contenu or {}
	local place = S.liste:GetHeight() or 0
	if place <= 0 then
		place = G.hauteur + G.listeY - (G.encadreY2 + G.listeY2)
	end
	local total = #liste
	S.decalage = math.max(0, math.min(S.decalage or 0, total - 1))
	local y, rang, n = 0, 0, S.decalage + 1
	while n <= total do
		local h = hauteurDe(liste[n])
		if y + h > place then break end
		rang = rang + 1
		local l = LIGNE[rang]
		if not l then
			l = creerLigne(rang)
			LIGNE[rang] = l
		end
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", S.liste, "TOPLEFT", 0, -y)
		l:SetPoint("TOPRIGHT", S.liste, "TOPRIGHT", 0, -y)
		poserLigne(l, liste[n])
		l:Show()
		y = y + h
		n = n + 1
	end
	for i = rang + 1, #LIGNE do
		LIGNE[i]:Hide()
	end
	S.visibles = rang
	S.barre:Regler(total, rang, S.decalage)
end

-- ---------------------------------------------------------------- les boutons

-- 3.3.5 n'a pas SetShown
local function montrer(x, oui)
	if oui then x:Show() else x:Hide() end
end

local function actif(b, oui)
	if b.Activer then b:Activer(oui) elseif oui then b:Enable() else b:Disable() end
end

local function majBoutons()
	local b = S.boutons
	local ignore = S.sousOnglet() == 2
	montrer(b.ajouter, not ignore)
	montrer(b.message, not ignore)
	montrer(b.ignorer, ignore)
	montrer(b.retirer, ignore)
	if not ignore then
		-- FriendsList_Update : Send Message, seulement vers un ami en ligne
		local choisi = GetSelectedFriend() or 0
		local connecte = false
		if choisi > 0 then
			connecte = select(5, GetFriendInfo(choisi)) and true or false
		end
		actif(b.message, connecte)
	else
		local index = 0
		if FriendsFrame.selectedSquelchType == SQUELCH_TYPE_IGNORE then
			index = GetSelectedIgnore() or 0
		end
		actif(b.retirer, index > 0)
	end
end

-- ------------------------------------------------------------ la mise a jour

function S.sousOnglet()
	local n = FriendsTabHeader and FriendsTabHeader.selectedTab or 1
	if n ~= 2 then n = 1 end
	return n
end

-- Premiere selection, comme le client : le premier ami, le premier ignore.
local function selectionParDefaut()
	if S.sousOnglet() == 2 then
		local ok = FriendsFrame.selectedSquelchType == SQUELCH_TYPE_IGNORE and (GetSelectedIgnore() or 0) > 0
		if not ok and (GetNumIgnores() or 0) > 0 then
			FriendsFrame_SelectSquelched(SQUELCH_TYPE_IGNORE, 1)
		end
	else
		local total = GetNumFriends() or 0
		if total > 0 and (GetSelectedFriend() or 0) == 0 then
			FriendsFrame_SelectFriend(FRIENDS_BUTTON_TYPE_WOW, 1)
		end
		FriendsFrame.selectedFriend = GetSelectedFriend()
		FriendsFrame.selectedFriendType = FRIENDS_BUTTON_TYPE_WOW
	end
end

-- LES ONGLETS DU BAS : celui du client qui est choisi, la guilde eteinte
-- hors guilde comme le sien (InGuildCheck).
function S.majOnglets()
	local choisi = FriendsFrame.selectedTab or 1
	for _, o in ipairs(S.onglets) do
		local client = _G["FriendsFrameTab" .. o.id]
		local ouvert = true
		if client and client.IsEnabled and o.id ~= choisi then
			local e = client:IsEnabled()
			ouvert = (e ~= nil and e ~= false and e ~= 0)
		end
		o.bouton:SetText(txt(o.texte))
		choisirOnglet(o.bouton, o.id == choisi, ouvert)
		o.bouton:SetWidth(largeurOnglet(o.bouton))
	end
end

function S.majContacts()
	local f = S.cadre
	if not f then return end
	local sous = S.sousOnglet()
	f.titre:SetText(txt(SOUS_ONGLETS[sous].titre))

	-- les sous-onglets
	for _, o in ipairs(S.sousOnglets) do
		o.bouton:SetText(txt(o.texte))
		choisirOnglet(o.bouton, o.id == sous, true)
		o.bouton:SetWidth(largeurOnglet(o.bouton))
	end

	selectionParDefaut()
	S.contenu = entrees()
	S.poserListe()
	majBoutons()
end

-- ------------------------------------------------------------ les clics

function S.cliquer(l, bouton)
	if l.sorte == "ami" then
		if bouton == "RightButton" then
			local nom, _, _, _, connecte = GetFriendInfo(l.id)
			ForeverUI.MenuUnite.ouvrir(FriendsFrame_ShowDropdown, nom, connecte, nil, nil, nil, 1)
		else
			PlaySound("igMainMenuOptionCheckBoxOn")
			FriendsFrame_SelectFriend(FRIENDS_BUTTON_TYPE_WOW, l.id)
			FriendsFrame.selectedFriend = l.id
		end
	elseif l.sorte == "ignore" then
		PlaySound("igMainMenuOptionCheckBoxOn")
		FriendsFrame_SelectSquelched(l.squelch, l.id)
	end
	S.maj()
end

-- ------------------------------------------------------ WotLK ou camelot

-- Ce que notre fenetre laisse au client : le menu du clic droit et
-- l'infobulle, qu'elle emprunte.
local GARDES = { "FriendsDropDown", "FriendsTooltip" }

-- Une page peut garder un cadre du client (le raid de Blizzard_RaidUI...).
function S.garder(nom)
	GARDES[#GARDES + 1] = nom
end

local function etoufferWotLK()
	local ff = FriendsFrame
	S.regionsTues = S.regionsTues or {}
	for _, r in ipairs({ ff:GetRegions() }) do
		if r:IsShown() then
			S.regionsTues[r] = true
			r:Hide()
		end
	end
	local garde = { [S.cadre] = true }
	for _, n in ipairs(GARDES) do
		local c = type(n) == "string" and _G[n] or n
		if c then garde[c] = true end
	end
	-- UN CADRE PROTEGE NE SE CACHE PAS EN COMBAT : en raid, RaidFrame porte
	-- les boutons securises de Blizzard_RaidUI. On l'efface alors par
	-- l'alpha, que le combat n'interdit pas, et on le cache au passage
	-- suivant hors combat.
	local combat = InCombatLockdown and InCombatLockdown()
	for _, c in ipairs({ ff:GetChildren() }) do
		if not garde[c] and c:IsShown() then
			if combat and c.IsProtected and c:IsProtected() then
				c:SetAlpha(0)
			else
				c:Hide()
			end
		end
	end
	if not (combat and ff.IsProtected and ff:IsProtected()) then
		ff:EnableMouse(false)
	end
end

-- LES PAGES. Une par onglet du client ; chacune s'inscrit avec ce qu'elle
-- sait faire : construire(cadre), maj(), montrer(), cacher(), titre().
S.pages = {}
local inscrites = {}

function S.inscrirePage(id, def)
	inscrites[id] = def
end

local function page(id)
	local pg = S.pages[id]
	if pg then return pg end
	local def = inscrites[id]
	if not def then return nil end
	local cadre = CreateFrame("Frame", "ForeverUISocialPage" .. id, S.cadre)
	cadre:SetAllPoints(S.cadre)
	cadre:Hide()
	pg = { id = id, cadre = cadre, def = def }
	S.pages[id] = pg
	def.construire(cadre)
	return pg
end

-- Batir une page d'avance (le raid, hors combat).
function S.preparer(id)
	if S.cadre then page(id) end
end

-- Tout ce qui change dans la page choisie, et les onglets.
function S.maj()
	S.majOnglets()
	local pg = S.pages[FriendsFrame.selectedTab or 1]
	if pg and pg.cadre:IsShown() then
		if pg.def.titre then S.cadre.titre:SetText(pg.def.titre() or "") end
		if pg.def.maj then pg.def.maj() end
	end
end

-- Le passage : apres FriendsFrame_Update, qui a deja pose l'ecran du client.
function S.appliquer()
	if not S.cadre or not FriendsFrame:IsShown() then return end
	local choisi = FriendsFrame.selectedTab or 1
	-- la page d'abord : en se batissant, elle peut garder un cadre du client
	page(choisi)
	etoufferWotLK()
	S.cadre:Show()
	for id, pg in pairs(S.pages) do
		if id ~= choisi and pg.cadre:IsShown() then
			pg.cadre:Hide()
			if pg.def.cacher then pg.def.cacher() end
		end
	end
	local pg = page(choisi)
	if pg then
		local etait = pg.cadre:IsShown()
		pg.cadre:Show()
		if pg.def.montrer then pg.def.montrer(not etait) end
	end
	S.maj()
end

-- LA FERMETURE : la page ouverte fait ce que le sous-cadre du client ferait
-- en se cachant (SetWhoToUI(0)...).
local function fermer()
	for _, pg in pairs(S.pages) do
		if pg.cadre:IsShown() then
			pg.cadre:Hide()
			if pg.def.cacher then pg.def.cacher() end
		end
	end
	if S.annexe then S.annexe:Hide() end
end

-- ------------------------------------------------------ les pieces communes

S.txt = txt
S.couleur = couleur
S.G = G

-- Un bouton de panneau, la police des boutons de la fenetre (GameFontNormal).
function S.bouton(parent, texte, largeur, nom)
	return ForeverUI.CreatePanelButton(parent, texte, largeur, G.boutonH, nom, "GameFontNormal")
end

-- Une ligne d'en-tete de colonne : WhoFrameColumnHeaderTemplate, dont camelot
-- (mainline, qu'il charge) garde l'art de WotLK -- WhoFrame-ColumnTabs en
-- trois morceaux, la surbrillance UI-Character-Tab-Highlight en ADD.
local ONGLETS_COLONNE = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "WhoFrame-ColumnTabs"
local SURBRILLANCE_COLONNE = "Interface" .. SEP .. "PaperDollInfoFrame" .. SEP .. "UI-Character-Tab-Highlight"
S.COLONNE_H = 24

function S.creerEntete(parent, nom, largeur, texte, clic)
	local b = CreateFrame("Button", nom, parent)
	b:SetHeight(S.COLONNE_H)
	local g = b:CreateTexture(nil, "BACKGROUND")
	g:SetTexture(ONGLETS_COLONNE)
	g:SetTexCoord(0, 0.078125, 0, 0.75)
	g:SetWidth(5)
	g:SetHeight(S.COLONNE_H)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local d = b:CreateTexture(nil, "BACKGROUND")
	d:SetTexture(ONGLETS_COLONNE)
	d:SetTexCoord(0.90625, 0.96875, 0, 0.75)
	d:SetWidth(4)
	d:SetHeight(S.COLONNE_H)
	d:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	local m = b:CreateTexture(nil, "BACKGROUND")
	m:SetTexture(ONGLETS_COLONNE)
	m:SetTexCoord(0.078125, 0.90625, 0, 0.75)
	m:SetHeight(S.COLONNE_H)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	m:SetPoint("RIGHT", d, "LEFT", 0, 0)
	local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", b, "LEFT", 8, 0)
	fs:SetPoint("RIGHT", b, "RIGHT", -8, 0)
	fs:SetJustifyH("LEFT")
	b:SetFontString(fs)
	b.texte = fs
	b:SetText(texte or "")
	b:SetHighlightTexture(SURBRILLANCE_COLONNE)
	local s = b:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", g, "TOPLEFT", -2, 5)
		s:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 2, -7)
	end
	b:SetWidth(largeur)
	if clic then
		b:SetScript("OnClick", function(self)
			clic(self)
			PlaySound("igMainMenuOptionCheckBoxOn")
		end)
	end
	return b
end

-- UNE LISTE A LIGNES FIXES, qui defile : la zone, ses lignes, la barre de
-- camelot et la molette. L'appelant donne creer(ligne, n) et remplir(ligne,
-- index) ; liste:Maj(total) repose tout.
function S.creerListe(parent, nom, hauteurLigne, creer, remplir)
	local zone = CreateFrame("Frame", nom, parent)
	zone.lignes = {}
	zone.decalage = 0
	zone.total = 0
	zone.hauteurLigne = hauteurLigne
	zone.barre = ForeverUI.CreateScrollBar(nom .. "ScrollBar", parent, zone)
	function zone:Visibles()
		local h = self:GetHeight() or 0
		if h <= 0 then h = self.hauteurDefaut or (hauteurLigne * 10) end
		return math.max(1, math.floor(h / hauteurLigne))
	end
	function zone:Maj(total)
		self.total = total or self.total
		local visibles = self:Visibles()
		self.decalage = math.max(0, math.min(self.decalage, self.total - visibles))
		for n = 1, visibles do
			local l = self.lignes[n]
			if not l then
				l = CreateFrame("Button", nom .. "Row" .. n, self)
				l:SetHeight(hauteurLigne)
				l:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(n - 1) * hauteurLigne)
				l:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(n - 1) * hauteurLigne)
				creer(l, n)
				self.lignes[n] = l
			end
			local index = self.decalage + n
			if index <= self.total then
				l.index = index
				remplir(l, index)
				l:Show()
			else
				l.index = nil
				l:Hide()
			end
		end
		for n = visibles + 1, #self.lignes do
			self.lignes[n]:Hide()
		end
		self.barre:Regler(self.total, visibles, self.decalage)
		-- la barre vient ou s'en va : le bord droit suit
		local avec = self.total > visibles
		if avec ~= self.avecBarre then
			self.avecBarre = avec
			self:PoserAncres()
		end
	end
	-- LE BORD DROIT SELON LA BARRE (2026-09-26). Avec la barre, la liste lui
	-- laisse sa place ; sans elle, la liste -- et ce qui s'y ancre, lignes et
	-- en-tetes -- va jusqu'au bord, sans trou. hautGauche et basDroite sont
	-- { point, relatif, point relatif, x, y } ; sansBarre remplace le x du
	-- bas-droit quand la barre est cachee.
	function zone:SuivreBarre(hautGauche, basDroite, sansBarre)
		self.ancres = { hautGauche = hautGauche, basDroite = basDroite, sansBarre = sansBarre }
		self:PoserAncres()
	end
	function zone:PoserAncres()
		local a = self.ancres
		if not a then return end
		local h, b = a.hautGauche, a.basDroite
		self:ClearAllPoints()
		self:SetPoint(h[1], h[2], h[3], h[4], h[5])
		self:SetPoint(b[1], b[2], b[3], self.avecBarre and b[4] or a.sansBarre, b[5])
	end
	zone.barre.surDefilement = function(nouveau)
		zone.decalage = nouveau
		zone:Maj()
	end
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(self, sens)
		self.decalage = math.max(0, math.min(self.decalage - sens, self.total - self:Visibles()))
		self:Maj()
	end)
	return zone
end

-- UN CHAMP DE SAISIE : le champ de camelot (InputBoxVisualTemplate, bords
-- common-search-border-*), comme la recherche du grimoire.
function S.creerSaisie(parent, nom, lettres)
	local b = CreateFrame("EditBox", nom, parent)
	b:SetAutoFocus(false)
	b:SetHeight(20)
	if lettres then b:SetMaxLetters(lettres) end
	b:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
	b:SetTextInsets(6, 6, 0, 0)
	S.habillerSaisie(b)
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return b
end

-- Le bord de camelot sur un champ, le notre ou celui du client
-- (InputBoxTemplate : ses trois morceaux <nom>Left / Middle / Right se
-- taisent).
function S.habillerSaisie(b)
	local nom = b.GetName and b:GetName()
	if nom then
		for _, cote in ipairs({ "Left", "Middle", "Right" }) do
			local t = _G[nom .. cote]
			if t then t:SetAlpha(0) t:Hide() end
		end
	end
	local g = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(g, "common-search-border-left", true)
	g:SetWidth(8) g:SetHeight(20)
	g:SetPoint("LEFT", b, "LEFT", -5, 0)
	local d = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(d, "common-search-border-right", true)
	d:SetWidth(8) d:SetHeight(20)
	d:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	local m = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(m, "common-search-border-middle", true)
	m:SetHeight(20)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	m:SetPoint("RIGHT", d, "LEFT", 0, 0)
	b.bordCamelot = { g, m, d }
end

-- UNE CASE A COCHER : checkbox-minimal et checkmark-minimal, 26 x 26, comme
-- les cases de l'onglet Monnaies.
function S.creerCase(parent, nom, texte)
	local c = CreateFrame("CheckButton", nom, parent)
	c:SetWidth(26)
	c:SetHeight(26)
	S.habillerCase(c)
	c.texte = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	c.texte:SetPoint("LEFT", c, "RIGHT", 2, 1)
	c.texte:SetText(texte or "")
	return c
end

-- L'art de camelot sur une case, la notre ou celle du client : la case vide,
-- la coche, et plus d'etat enfonce ni de surbrillance de WotLK.
function S.habillerCase(c)
	local function poser(methodeSet, methodeGet, atlas)
		local e = ForeverUI.AtlasEntry(atlas)
		if c[methodeSet] then c[methodeSet](c, e and e[1] or "") end
		local t = c[methodeGet] and c[methodeGet](c)
		if t then
			ForeverUI.SetAtlas(t, atlas, true)
			t:ClearAllPoints()
			t:SetAllPoints(c)
		end
		return t
	end
	poser("SetNormalTexture", "GetNormalTexture", "checkbox-minimal")
	poser("SetCheckedTexture", "GetCheckedTexture", "checkmark-minimal")
	local d = poser("SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "checkmark-minimal")
	if d then d:SetDesaturated(true) end
	-- ENFONCEE, la case montre son image enfoncee A LA PLACE de la normale :
	-- vide, le contour disparaissait le temps du clic (2026-09-26). Elle
	-- porte donc le meme contour ; seule la coche va et vient.
	poser("SetPushedTexture", "GetPushedTexture", "checkbox-minimal")
	if c.SetHighlightTexture then c:SetHighlightTexture("") end
end

-- LA FENETRE ANNEXE : le detail d'un membre, l'information de guilde, le
-- journal, les instances sauvegardees. Une seule a la fois, a droite de la
-- fenetre, comme GuildFramePopup_Show. Le meme cadre sans portrait que le
-- detail d'une equipe d'arene.
function S.creerAnnexe(nom, largeur, hauteur)
	local a = CreateFrame("Frame", nom, S.cadre)
	a:SetWidth(largeur)
	a:SetHeight(hauteur)
	a:SetPoint("TOPLEFT", S.cadre, "TOPRIGHT", 12, 0)
	a:SetFrameLevel(S.cadre:GetFrameLevel() + 30)
	a:EnableMouse(true)
	a:Hide()
	ForeverUI.SetPanelArt(a, { coinHautGauche = "ui-frame-metal-cornertopleft", niveau = 5 })
	local metal = a.foreverHabillage or a
	local bandeau = CreateFrame("Frame", nil, a)
	bandeau:SetAllPoints(a)
	bandeau:SetFrameLevel(metal:GetFrameLevel() + 1)
	a.titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	a.titre:SetPoint("TOP", a, "TOP", 0, -6)
	a.titre:SetWidth(largeur - 60)
	local croix = CreateFrame("Button", nil, a)
	croix:SetWidth(G.croix)
	croix:SetHeight(G.croix)
	croix:SetFrameLevel(metal:GetFrameLevel() + 2)
	croix:SetPoint("TOPRIGHT", a, "TOPRIGHT", 1, 0)
	for _, etat in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(etat[3])
		croix[etat[1]](croix, e and e[1] or "")
		local t = croix[etat[2]](croix)
		if t then
			ForeverUI.SetAtlas(t, etat[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(croix)
			if etat[3] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
	croix:SetScript("OnClick", function() a:Hide() end)
	a.croix = croix
	a:HookScript("OnShow", function(self)
		if S.annexe and S.annexe ~= self then S.annexe:Hide() end
		S.annexe = self
		PlaySound("igSpellBookOpen")
	end)
	a:HookScript("OnHide", function(self)
		if S.annexe == self then S.annexe = nil end
		PlaySound("igSpellBookClose")
	end)
	S.annexes = S.annexes or {}
	table.insert(S.annexes, a)
	return a
end

-- ------------------------------------------------------------ l'assemblage

local function construire()
	if S.cadre or not FriendsFrame then return end
	local f = CreateFrame("Frame", "ForeverUISocialFrame", FriendsFrame)
	f:SetWidth(G.largeur)
	f:SetHeight(G.hauteur)
	f:SetPoint("TOPLEFT", FriendsFrame, "TOPLEFT", 0, 0)
	f:SetFrameLevel(FriendsFrame:GetFrameLevel() + 1)
	f:EnableMouse(true)
	S.cadre = f
	construireCadre(f)

	-- LA PAGE CONTACTS : ses sous-onglets, son encadre, sa liste, ses
	-- boutons.
	S.inscrirePage(1, {
		construire = function() end,
		titre = function() return txt(SOUS_ONGLETS[S.sousOnglet()].titre) end,
		maj = function() S.majContacts() end,
	})
	local p1 = page(1)
	local contacts = p1.cadre

	local encadre = ForeverUI.CreateInset(contacts, "ForeverUISocialInset")
	encadre:SetPoint("TOPLEFT", f, "TOPLEFT", G.encadreX1, G.encadreY1)
	encadre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.encadreX2, G.encadreY2)
	S.encadre = encadre
	local liste = CreateFrame("Frame", "ForeverUISocialList", contacts)
	liste:SetPoint("TOPLEFT", f, "TOPLEFT", G.listeX, G.listeY)
	liste:SetPoint("BOTTOMRIGHT", encadre, "BOTTOMRIGHT", G.listeX2, G.listeY2)
	liste:EnableMouseWheel(true)
	liste:SetScript("OnMouseWheel", function(_, sens)
		S.decalage = math.max(0, math.min((S.decalage or 0) - sens, #(S.contenu or {}) - (S.visibles or 0)))
		S.poserListe()
	end)
	S.liste = liste
	S.barre = ForeverUI.CreateScrollBar("ForeverUISocialScrollBar", contacts, liste)
	S.barre.surDefilement = function(nouveau)
		S.decalage = nouveau
		S.poserListe()
	end

	-- les onglets du bas, sur la fenetre
	S.onglets = {}
	local precedent
	for i, def in ipairs(ONGLETS) do
		local b = creerOnglet(f, "ForeverUISocialTab" .. i, false)
		if precedent then
			b:SetPoint("TOPLEFT", precedent, "TOPRIGHT", G.ongletEcart, 0)
		else
			b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", G.ongletPremierX, G.ongletPremierY)
		end
		b:SetScript("OnClick", function()
			-- l'onglet du client fait le reste : PanelTemplates_Tab_OnClick,
			-- FriendsFrame_OnShow, et la guilde qu'il referme
			local client = _G["FriendsFrameTab" .. def.id]
			if client and client:GetScript("OnClick") then
				client:GetScript("OnClick")(client, "LeftButton")
			else
				PanelTemplates_SetTab(FriendsFrame, def.id)
				FriendsFrame_OnShow()
			end
			PlaySound("igCharacterInfoTab")
		end)
		S.onglets[i] = { id = def.id, texte = def.texte, bouton = b }
		precedent = b
	end

	-- les sous-onglets : Friends et Ignore, l'etat du client
	S.sousOnglets = {}
	precedent = nil
	for i, def in ipairs(SOUS_ONGLETS) do
		local b = creerOnglet(contacts, "ForeverUISocialSubTab" .. i, true)
		b:SetFrameLevel(f:GetFrameLevel() + 2)
		if precedent then
			b:SetPoint("TOPLEFT", precedent, "TOPRIGHT", G.sousEcart, 0)
		else
			b:SetPoint("TOPLEFT", f, "TOPLEFT", G.sousX, G.sousY)
		end
		b:SetScript("OnClick", function()
			PanelTemplates_SetTab(FriendsTabHeader, def.id)
			PlaySound("igMainMenuOptionCheckBoxOn")
			S.decalage = 0
			FriendsFrame_Update()
		end)
		S.sousOnglets[i] = { id = def.id, texte = def.texte, bouton = b }
		precedent = b
	end

	-- les boutons, ceux du client pour ce qu'ils font
	local b = {}
	local function bouton(texte, largeur)
		return ForeverUI.CreatePanelButton(contacts, texte, largeur, G.boutonH, nil, "GameFontNormal")
	end
	b.ajouter = bouton(txt("ADD_FRIEND"), G.boutonL)
	b.ajouter:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.boutonGauche, G.boutonBas)
	b.ajouter:SetScript("OnClick", function(self) FriendsFrameAddFriendButton_OnClick(self) end)
	b.message = bouton(txt("SEND_MESSAGE"), G.boutonL)
	b.message:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.boutonDroite, G.boutonBas)
	b.message:SetScript("OnClick", function(self) FriendsFrameSendMessageButton_OnClick(self) end)
	b.ignorer = bouton(txt("IGNORE_PLAYER"), G.boutonL)
	b.ignorer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.boutonGauche, G.boutonBas)
	b.ignorer:SetScript("OnClick", function()
		-- l'OnClick de FriendsFrameIgnorePlayerButton, dans le XML du client
		if UnitCanCooperate("player", "target") then
			AddIgnore(UnitName("target"))
		else
			StaticPopup_Show("ADD_IGNORE")
		end
	end)
	b.retirer = bouton(txt("REMOVE_PLAYER"), G.boutonL)
	b.retirer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.boutonDroite, G.boutonBas)
	b.retirer:SetScript("OnClick", function(self) FriendsFrameUnsquelchButton_OnClick(self) end)
	S.boutons = b

	f:Hide()
end

construire()

if S.cadre then
	hooksecurefunc("FriendsFrame_Update", S.appliquer)
	FriendsFrame:HookScript("OnShow", S.appliquer)
	FriendsFrame:HookScript("OnHide", fermer)
	-- deplacable par son titre ; devant quand on l'ouvre ou qu'on la clique
	ForeverUI.Superposition.deplacable(S.cadre, S.cadre.bandeau, "social")
	ForeverUI.Superposition.inscrire("social", FriendsFrame, function()
		local z = { S.cadre }
		for _, a in ipairs(S.annexes or {}) do z[#z + 1] = a end
		return z
	end)
	local veilleur = CreateFrame("Frame")
	for _, ev in ipairs({ "FRIENDLIST_UPDATE", "IGNORELIST_UPDATE",
		"PARTY_MEMBERS_CHANGED", "PLAYER_GUILD_UPDATE" }) do
		veilleur:RegisterEvent(ev)
	end
	veilleur:SetScript("OnEvent", function()
		if S.cadre:IsVisible() and (FriendsFrame.selectedTab or 1) == 1 then S.maj() end
	end)
end

-- TEMOIN -- /fui social
function ForeverUI.SocialDebug()
	local dire = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t) end
	if not S.cadre then
		dire("fenetre Social : non construite (FriendsFrame absent ?)")
		return
	end
	local total, enLigne = GetNumFriends()
	dire(string.format("social : onglet %s, sous-onglet %s | notre fenetre %s | panneau souris %s",
		tostring(FriendsFrame.selectedTab), tostring(FriendsTabHeader and FriendsTabHeader.selectedTab),
		tostring(S.cadre:IsShown()), tostring(FriendsFrame:IsMouseEnabled())))
	dire(string.format("amis %s (%s en ligne), choisi %s | ignores %s, choisi %s",
		tostring(total), tostring(enLigne), tostring(GetSelectedFriend()), tostring(GetNumIgnores()),
		tostring(GetSelectedIgnore())))
	dire(string.format("liste : %d entree(s), %d visible(s), decalage %d",
		#(S.contenu or {}), S.visibles or 0, S.decalage or 0))
end
