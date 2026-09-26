-- ForeverUI : la page "Chat" de la fenetre Social (onglet 4 du client) --
-- les canaux de discussion.
--
-- camelot met ses canaux dans une fenetre a part (blizzard_channels) ; la
-- decision de l'utilisateur (2026-09-26) les garde en onglet, comme WotLK.
-- La page reprend donc ChannelFrame (ChannelFrame.lua et .xml du client),
-- habillee comme le reste de la fenetre.
--
-- RELEVE WotLK :
--   liste     GetNumDisplayChannels ; name, header, collapsed, channelNumber,
--             count, active, category = GetChannelDisplayInfo(i). En-tete : nom dore, "+" replie / "-"
--             deplie, cliquable seulement s'il a un compte. Canal actif :
--             "N. nom" en blanc, "(count)" en plus pour la categorie GROUP ;
--             inactif : en gris, et desactive. 20 lignes de 20.
--   clics     en-tete : ExpandChannelHeader / CollapseChannelHeader ; canal
--             actif : SetSelectedDisplayChannel et la liste des membres ;
--             droit : le menu ChannelListDropDown (mot de passe, inviter,
--             rejoindre, quitter)
--   membres   name, owner, moderator = GetChannelRosterInfo(canal, i) ; icone de chef
--             (UI-Group-LeaderIcon) pour le proprietaire, d'assistant
--             (UI-Group-AssistantIcon) pour un moderateur ; lignes de 15 ;
--             le titre : le nom du canal, et "(count)" pour GROUP ; clic
--             droit : ChannelRosterFrame_ShowDropdown (UnitPopup CHAT_ROSTER)
--   nouveau   ADD (80) : nom (31 lettres) et mot de passe facultatif ;
--             JoinPermanentChannel(nom, mdp, DEFAULT_CHAT_FRAME:GetID(), 1),
--             CHAT_INVALID_NAME_NOTICE sinon, puis le canal inscrit dans la
--             liste du cadre de discussion (ChannelFrameDaughterFrame_Okay)
--
-- RETIRE (2026-09-26, demande de l'utilisateur) : tout ce qui touche au chat
-- vocal -- les cases d'adhesion automatique, les haut-parleurs des canaux et
-- des membres, le glisser vers la fenetre detachee du roster vocal. Le menu du
-- client ne recoit plus les champs de voix : il n'en propose plus les lignes.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local S = ForeverUI.Social
if not S or not S.inscrirePage then
	return
end

local C = {}
S.Chat = C

local SEP = string.char(92)
local P = {
	listeL = 172, encadreY1 = -60, encadreBas = 32, ecart = 4,
	ligneH = 20, membreH = 15, titreRosterH = 18,
	ajouterL = 80, boutonBas = 4, boutonDroite = -6,
	chef = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-LeaderIcon",
	assistant = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-AssistantIcon",
	surbrillance = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight",
	plus = "common-button-list-plus", moins = "common-button-list-minus",
	plaque = "common-button-list-collapseexpand",
}

local txt = S.txt

local function choisi()
	return GetSelectedDisplayChannel() or 0
end

-- ---------------------------------------------------------------- la liste

local function creerLigne(l)
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	l.plaque = ForeverUI.CreateNineSlice(l, P.plaque, 12, { 0, 0, 0, 0 }, "BACKGROUND") or {}
	l.texte = l:CreateFontString(nil, "ARTWORK", "GameFontNormalSmallLeft")
	l.texte:SetPoint("LEFT", l, "LEFT", 5, 0)
	l.texte:SetPoint("RIGHT", l, "RIGHT", -20, 0)
	l.texte:SetHeight(12)
	l.signe = l:CreateTexture(nil, "ARTWORK")
	l.signe:SetPoint("RIGHT", l, "RIGHT", -6, 0)
	l:SetHighlightTexture(P.surbrillance)
	local s = l:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	l:SetScript("OnClick", function(self, bouton) C.cliquer(self, bouton) end)
end

local function remplirLigne(l, i)
	local nom, entete, replie, numero, compte, actif, categorie = GetChannelDisplayInfo(i)
	l.canal, l.entete, l.actif, l.categorie = nil, entete, actif, categorie
	l:UnlockHighlight()
	if entete then
		for _, t in ipairs(l.plaque) do t:Show() end
		l.texte:ClearAllPoints()
		l.texte:SetPoint("LEFT", l, "LEFT", 5, 0)
		l.texte:SetPoint("RIGHT", l, "RIGHT", -20, 0)
		l.texte:SetText((NORMAL_FONT_COLOR_CODE or "|cffffd200") .. (nom or "") .. "|r")
		if compte then
			ForeverUI.SetAtlas(l.signe, replie and P.plus or P.moins, false)
			l.signe:Show()
			l:Enable()
		else
			l.signe:Hide()
			l:Disable()
		end
	else
		for _, t in ipairs(l.plaque) do t:Hide() end
		l.signe:Hide()
		l.texte:ClearAllPoints()
		l.texte:SetPoint("LEFT", l, "LEFT", 10, 0)
		l.texte:SetPoint("RIGHT", l, "RIGHT", -4, 0)
		local num = numero and (numero .. ". ") or ""
		if actif then
			local suite = ""
			if categorie == "CHANNEL_CATEGORY_GROUP" and compte then
				suite = " (" .. compte .. ")"
			end
			l.texte:SetText((HIGHLIGHT_FONT_COLOR_CODE or "|cffffffff") .. num .. (nom or "") .. suite .. "|r")
			l:Enable()
		else
			l.texte:SetText((GRAY_FONT_COLOR_CODE or "|cff808080") .. num .. (nom or "") .. "|r")
			l:Disable()
		end
		l.canal = nom
		if i == choisi() then l:LockHighlight() end
	end
end

-- LE MENU D'UN CANAL : ChannelList_ShowDropdown, dont on pose nous-memes les
-- champs -- le client les lit sur ses propres lignes ChannelButtonN.
local function menuCanal(id)
	local nom, _, _, _, _, actif, categorie = GetChannelDisplayInfo(id)
	HideDropDownMenu(1)
	local d = ChannelListDropDown
	if not d then return end
	d.global = (categorie == "CHANNEL_CATEGORY_WORLD") and 1 or nil
	d.group = (categorie == "CHANNEL_CATEGORY_GROUP") and 1 or nil
	d.custom = (categorie == "CHANNEL_CATEGORY_CUSTOM") and 1 or nil
	d.initialize = ChannelListDropDown_Initialize
	d.displayMode = "MENU"
	d.id = id
	d.voice = nil
	d.voiceActive = nil
	d.active = actif
	d.channelName = nom
	ToggleDropDownMenu(1, nil, d, "cursor")
end

-- ChannelList_OnClick
function C.cliquer(l, bouton)
	PlaySound("igMainMenuOptionCheckBoxOn")
	if ChannelListDropDown then ChannelListDropDown.clicked = nil end
	local id = l.index
	if bouton == "LeftButton" then
		HideDropDownMenu(1)
		if l.entete then
			local _, _, replie = GetChannelDisplayInfo(id)
			if replie then ExpandChannelHeader(id) else CollapseChannelHeader(id) end
		elseif l.actif then
			SetSelectedDisplayChannel(id)
			C.maj()
		end
	elseif l.canal then
		if l.categorie == "CHANNEL_CATEGORY_WORLD" then
			menuCanal(id)
		end
		if l.actif then
			GetNumChannelMembers(id)
			if ChannelListDropDown then ChannelListDropDown.clicked = id end
			if l.categorie ~= "CHANNEL_CATEGORY_WORLD" then menuCanal(id) end
		end
	end
end

-- -------------------------------------------------------------- les membres

local function creerMembre(l)
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	l.rang = l:CreateTexture(nil, "ARTWORK")
	l.rang:SetWidth(12)
	l.rang:SetHeight(12)
	l.rang:SetPoint("LEFT", l, "LEFT", 2, 1)
	l.nom = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	l.nom:SetJustifyH("LEFT")
	l.nom:SetPoint("LEFT", l, "LEFT", 16, 0)
	l.nom:SetPoint("RIGHT", l, "RIGHT", -4, 0)
	l:SetHighlightTexture(P.surbrillance)
	local s = l:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	l:SetScript("OnClick", function(self, bouton)
		-- ChannelRoster_OnClick : le clic droit seulement
		if bouton == "RightButton" and ChannelRosterFrame_ShowDropdown then
			ForeverUI.MenuUnite.ouvrir(ChannelRosterFrame_ShowDropdown, self.index)
		end
	end)
end

local function remplirMembre(l, i)
	local nom, proprietaire, moderateur = GetChannelRosterInfo(choisi(), i)
	l.nom:SetText(nom)
	if proprietaire then
		l.rang:SetTexture(P.chef)
		l.rang:Show()
	elseif moderateur then
		l.rang:SetTexture(P.assistant)
		l.rang:Show()
	else
		l.rang:Hide()
	end
end

-- ------------------------------------------------------------ la mise a jour

function C.maj()
	if not C.liste then return end
	C.liste:Maj(GetNumDisplayChannels() or 0)
	-- ChannelRoster_Update
	local id = choisi()
	local nom, _, _, _, compte, _, categorie = GetChannelDisplayInfo(id)
	if not compte then
		C.titre:SetText("")
		C.membres:Maj(0)
	else
		local suite = (categorie == "CHANNEL_CATEGORY_GROUP") and (" (" .. compte .. ")") or ""
		C.titre:SetText((nom or "") .. suite)
		C.membres:Maj(compte)
	end
end

-- LA FENETRE "NOUVEAU CANAL" : notre annexe, et DEDANS les champs et les
-- boutons de la boite du client (ChannelFrameDaughterFrame). Rejoindre un
-- canal l'inscrit dans la liste du cadre de discussion
-- (DEFAULT_CHAT_FRAME.channelList) : ecrite par l'addon, cette liste
-- passerait a l'addon, et avec elle chaque message de canal que le client
-- traite (2026-09-26, le code doit etre propre). Le clic sur OK et la touche
-- Entree sont donc ceux du client -- ChannelFrameDaughterFrame_Okay, son code
-- a lui. Ses champs et ses boutons restent les enfants de sa boite ; ils
-- sont seulement poses dans notre annexe et habilles comme les notres. Sa
-- boite ne montre plus rien d'elle-meme : ni son fond, ni son titre, ni sa
-- croix, ni sa case de chat vocal.
local function creerNouveau()
	local a = S.creerAnnexe("ForeverUIChannelNewFrame", 230, 170)
	a.titre:SetText(txt("CHANNEL_NEW_CHANNEL"))
	local l1 = a:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	l1:SetPoint("TOPLEFT", a, "TOPLEFT", 22, -36)
	l1:SetText(txt("CHANNEL_CHANNEL_NAME"))

	local fille = ChannelFrameDaughterFrame
	local nom = ChannelFrameDaughterFrameChannelName
	local mdp = ChannelFrameDaughterFrameChannelPassword
	local ok = ChannelFrameDaughterFrameOkayButton
	local annuler = ChannelFrameDaughterFrameCancelButton
	if not (fille and nom and mdp and ok and annuler) then
		return a
	end

	-- la boite du client : sous UIParent (ChannelFrame, l'onglet du client,
	-- n'est pas montre), sur notre annexe, au-dessus d'elle, sans son art
	fille:SetParent(UIParent)
	fille:ClearAllPoints()
	fille:SetAllPoints(a)
	fille:SetFrameStrata(a:GetFrameStrata())
	fille:SetFrameLevel(a:GetFrameLevel() + 10)
	fille:EnableMouse(false)
	if fille.SetBackdrop then fille:SetBackdrop(nil) end
	for _, r in ipairs({ fille:GetRegions() }) do
		r:SetAlpha(0)
	end
	for _, suffixe in ipairs({ "VoiceChat", "DetailCloseButton" }) do
		ForeverUI.Suppress(_G["ChannelFrameDaughterFrame" .. suffixe])
	end

	-- ses deux champs, a la place et a la taille des notres
	local function champ(b)
		b:SetWidth(180)
		b:SetHeight(20)
		b:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
		b:SetTextInsets(6, 6, 0, 0)
		S.habillerSaisie(b)
		local etiquette = _G[b:GetName() .. "Label"]
		if etiquette then etiquette:SetAlpha(0) end
		local facultatif = _G[b:GetName() .. "Optional"]
		if facultatif then facultatif:SetAlpha(0) end
	end
	champ(nom)
	nom:ClearAllPoints()
	nom:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 2, -4)
	local l2 = a:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	l2:SetPoint("TOPLEFT", nom, "BOTTOMLEFT", -2, -10)
	l2:SetText(txt("PASSWORD") .. " |cffffffff" .. txt("OPTIONAL_PARENS") .. "|r")
	champ(mdp)
	mdp:ClearAllPoints()
	mdp:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 2, -4)

	-- ses deux boutons, a la place et a la taille des notres
	for _, b in ipairs({ ok, annuler }) do
		b:SetWidth(96)
		b:SetHeight(S.G.boutonH)
		b:SetNormalFontObject(GameFontNormal)
		b:SetHighlightFontObject(GameFontHighlight)
		if b.SetDisabledFontObject then b:SetDisabledFontObject(GameFontDisable) end
		b:ClearAllPoints()
	end
	ok:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 12, 12)
	annuler:SetPoint("LEFT", ok, "RIGHT", 4, 0)

	-- l'annexe et la boite s'ouvrent et se ferment ensemble : OK, Entree,
	-- Echap et Annuler ferment la boite du client, notre croix l'annexe
	a:HookScript("OnShow", function()
		fille:Show()
		nom:SetText("")
		mdp:SetText("")
		nom:SetFocus()
	end)
	a:HookScript("OnHide", function() fille:Hide() end)
	fille:HookScript("OnHide", function() a:Hide() end)
	a.nom, a.mdp, a.ok, a.annuler = nom, mdp, ok, annuler
	return a
end

local function construire(cadre)
	local gauche = ForeverUI.CreateInset(cadre, "ForeverUIChannelListInset")
	gauche:SetPoint("TOPLEFT", S.cadre, "TOPLEFT", 4, P.encadreY1)
	gauche:SetPoint("BOTTOMLEFT", S.cadre, "BOTTOMLEFT", 4, P.encadreBas)
	gauche:SetWidth(P.listeL)
	local droite = ForeverUI.CreateInset(cadre, "ForeverUIChannelRosterInset")
	droite:SetPoint("TOPLEFT", gauche, "TOPRIGHT", P.ecart, 0)
	droite:SetPoint("BOTTOMRIGHT", S.cadre, "BOTTOMRIGHT", -6, P.encadreBas)

	C.liste = S.creerListe(gauche, "ForeverUIChannelList", P.ligneH, creerLigne, remplirLigne)
	C.liste:SetPoint("TOPLEFT", gauche, "TOPLEFT", 4, -4)
	C.liste:SetPoint("BOTTOMRIGHT", gauche, "BOTTOMRIGHT", -16, 4)

	C.titre = droite:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	C.titre:SetPoint("TOPLEFT", droite, "TOPLEFT", 8, -6)
	C.titre:SetPoint("TOPRIGHT", droite, "TOPRIGHT", -8, -6)
	C.titre:SetJustifyH("LEFT")
	C.titre:SetHeight(13)
	C.membres = S.creerListe(droite, "ForeverUIChannelRoster", P.membreH, creerMembre, remplirMembre)
	C.membres:SetPoint("TOPLEFT", droite, "TOPLEFT", 4, -4 - P.titreRosterH)
	C.membres:SetPoint("BOTTOMRIGHT", droite, "BOTTOMRIGHT", -16, 4)

	C.nouveau = creerNouveau()
	C.ajouter = S.bouton(cadre, txt("ADD"), P.ajouterL)
	C.ajouter:SetPoint("BOTTOMRIGHT", S.cadre, "BOTTOMRIGHT", P.boutonDroite, P.boutonBas)
	C.ajouter:SetScript("OnClick", function()
		if C.nouveau:IsShown() then C.nouveau:Hide() else C.nouveau:Show() end
	end)
end

S.inscrirePage(4, {
	construire = construire,
	titre = function() return txt("CHAT_CHANNELS") end,
	maj = C.maj,
	cacher = function() if C.nouveau then C.nouveau:Hide() end end,
})

local veilleur = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "CHANNEL_UI_UPDATE", "PARTY_MEMBERS_CHANGED",
	"PARTY_LEADER_CHANGED", "RAID_ROSTER_UPDATE", "CHANNEL_COUNT_UPDATE", "CHANNEL_ROSTER_UPDATE",
	"IGNORELIST_UPDATE", "CHANNEL_FLAGS_UPDATED" }) do
	veilleur:RegisterEvent(ev)
end
veilleur:SetScript("OnEvent", function()
	if C.liste and C.liste:IsVisible() then C.maj() end
end)
