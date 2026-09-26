-- ForeverUI : la fenetre de chat, a la DA de camelot -- etape 1, le cadre
-- (demande de l'utilisateur, 2026-09-26 ; memoire foreverui-chat).
--
-- CE QUI NE CHANGE PAS : L'ART. Le fond, les bords, les onglets, la saisie,
-- le bouton de menu, la poignee et le dock de camelot sont les MEMES fichiers
-- que ceux de 3.3.5, pixel pour pixel (compare le 2026-09-26 :
-- ChatFrameBackground, UI-ChatFrame-Border*, ChatFrameTab-*,
-- UI-ChatInputBorder*, UI-ChatIcon-Chat-*, UI-ChatIM-SizeGrabber-*,
-- chat-tab-arrow...). Ce qui fait camelot, ce sont les places, et quelques
-- pieces nouvelles.
--
-- RELEVE -- blizzard_chatframebase/mainline (floatingchatframe.xml et .lua,
-- chatframe.xml) et shared (floatingchatframe.lua), charges par [Family] :
--   fond         FloatingChatFrame_UpdateBackgroundAnchors : le fond deborde
--                a droite de 7 + la largeur de la barre (8), soit 15, pour
--                loger la barre ; a gauche -2, en haut 3, en bas -6
--   colonne      FCF_SetButtonSide : TOPRIGHT sur le TOPLEFT du fond (-3,-3)
--                et BOTTOMRIGHT sur son BOTTOMLEFT (-3,6) a gauche ; a droite
--                TOPLEFT sur TOPRIGHT (3,-3) et BOTTOMLEFT sur BOTTOMRIGHT
--                (3,6) ; plus de boutons haut / bas / fin : la barre les
--                remplace ; le bouton de menu a BOTTOM (0,0) de la colonne de
--                ChatFrame1, le bouton de reduction a TOP (0,4)
--   barre        MinimalScrollBar, 8 de large, TOPLEFT sur le TOPRIGHT du chat
--                (0,0), BOTTOMLEFT sur le TOPLEFT du bouton de retour (0,2) ;
--                cachee au repos, 0,6 quand le chat s'allume (0,15 s), 0
--                quand il s'eteint (2 s)
--   retour       ScrollToBottomButton, 17 x 15, BOTTOMRIGHT sur le TOPRIGHT de
--                la poignee (-2,-2) : minimal-scrollbar-arrow-returntobottom
--                (-down enfonce, -over au survol) ; 0,65 quand le chat
--                s'allume (0,1 s), 0 quand il s'eteint ; tant que le chat
--                n'est pas en bas il clignote -- le meme art en ADD, 0,1 s
--                pour venir, 0,5 s tenu, 0,1 s pour partir, 0,5 s eteint
--                (ChatFrameConstants.ScrollToBottomFlashInterval) -- et la
--                barre s'allume
--   amis         QuickJoinToastButton, 32 x 32, dans ChatAlertFrame :
--                BOTTOMLEFT sur le TOPLEFT de la colonne du chat par defaut
--                (0,27), a droite quand la colonne est a droite ;
--                quickjoin-button-friendslist-up / -down, surbrillance
--                UI-Common-MouseHilight, nombre d'amis GameFontHighlightSmall
--                a BOTTOM (0,4)
--
-- DECISIONS DE L'UTILISATEUR (2026-09-26) : pas de bouton des canaux (son
-- icone est un haut-parleur, chatframe-button-icon-voicechat, et les canaux
-- sont dans Social) ; le bouton d'amis de camelot a la place du bouton
-- Battle.net de WotLK (FriendsMicroButton : il garde son role, son nombre
-- d'amis et son ouverture de Social).
--
-- CE QUI VIENT DE WotLK : tout le chat -- ses fenetres, le dock, le fondu
-- (FCF_OnUpdate), les onglets, la saisie. On ne remplace aucune fonction ;
-- on accroche (hooksecurefunc) celles qui reposent ce qu'on change :
-- FCF_SetButtonSide (la colonne), FCF_OpenTemporaryWindow (les fenetres de chuchotement). Les
-- boutons haut / bas / fin de la colonne sont remontres par l'OnShow de
-- chaque fenetre : on les recache apres lui.
--
-- AU REPOS (demande de l'utilisateur, 2026-09-26) : souris hors du chat, il
-- ne reste que les messages. WotLK et camelot laissent au repos le fond a
-- l'opacite retenue, les onglets a 0,4 / 0,2, la colonne du chat par defaut
-- a 1 et la saisie a 0,35 ; ici :
--   le fond       l'opacite retenue de chaque fenetre passe a 0, UNE fois
--                 (SetChatWindowAlpha a ADDON_LOADED, ForeverUIDB.chatFondRepos)
--                 : le client la relit a UPDATE_CHAT_WINDOWS et la garde ;
--                 au survol il monte a max(opacite, 0,25) comme toujours ; ce
--                 que l'utilisateur regle ensuite dans le menu de l'onglet
--                 est respecte
--   le reste      onglets, boutons de la colonne (menu, amis, reduction), la
--                 saisie : un coefficient par fenetre, 1 allumee, 0 eteinte
--                 (0,15 s pour venir, 2 s pour partir, comme le client),
--                 pose A CHAQUE IMAGE sur les REGIONS des onglets et de la
--                 saisie -- leur alpha a eux appartient au client, qui remet
--                 aussi celui du texte des onglets -- et sur les boutons ; la
--                 saisie active reste a 1. Les lueurs d'alerte des onglets
--                 (glow, TabFlash) sont animees par UIFrameFlash : on n'y
--                 touche pas
--
-- LE SURVOL (demande de l'utilisateur, 2026-09-26) : le chat s'allume au
-- survol. FCF_OnUpdate ne l'allume que si le curseur reste IMMOBILE 0,2 s
-- sur lui ; on ne remplace pas FCF_OnUpdate et on n'appelle pas
-- FCF_FadeInChatFrame (il ecrirait hasBeenFaded depuis l'addon, et
-- FCF_OnUpdate tourne dans l'OnUpdate de UIParent, avant UnitPopup_OnUpdate :
-- la souillure gagnerait les menus d'unite). Notre moteur regarde les memes
-- zones que FCF_OnUpdate (plus la barre et le retour), sans exiger
-- l'immobilite : survolee 0,2 s, la fenetre s'allume ; dehors 1 s, elle
-- s'eteint (CHAT_TAB_SHOW_DELAY, CHAT_TAB_HIDE_DELAY). Allumee par nous ou
-- par le client (hasBeenFaded), c'est pareil ; une fenetre du dock allume
-- tout le dock. Le fond, lui, est peint par le client : une DOUBLURE de
-- chacune de ses textures (CHAT_FRAME_TEXTURES), posee dessus, complete ce
-- qui manque pour atteindre max(opacite, 0,25) -- 1 - (1 - voulu) / (1 -
-- client) -- et ne fait rien quand le client l'y a deja mis
--
-- LE DEFILEMENT. 3.3.5 compte le defilement en messages depuis le bas
-- (GetCurrentScroll) ; la barre en deduit sa place, et la deplacer fait
-- defiler de la difference (ScrollUp / ScrollDown), SetScrollOffset quand le
-- client l'a.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local C = {}
ForeverUI.Chat = C

local SEP = string.char(92)

local G = {
	fondGauche = -2, fondHaut = 3, fondDroite = 7 + 8, fondBas = -6,
	colonneX = 3, colonneHaut = -3, colonneBas = 6,
	minimiserY = 4,
	amis = 32, amisY = 27,
	retourL = 17, retourH = 15, retourX = -2, retourY = -2, barreBas = 2,
	barreAlpha = 0.6, retourAlpha = 0.65,
	venue = 0.15, venueRetour = 0.1, depart = 2.0,
	fondRepos = 0,
	flashVenue = 0.1, flashTenu = 0.5,
	hautParLigne = 2,
}

local ATLAS = {
	retour = "minimal-scrollbar-arrow-returntobottom-c60",
	retourBas = "minimal-scrollbar-arrow-returntobottom-down-c60",
	retourSurvol = "minimal-scrollbar-arrow-returntobottom-over-c60",
	amis = "quickjoin-button-friendslist-up",
	amisBas = "quickjoin-button-friendslist-down",
}

C.fenetres = {}

-- ------------------------------------------------------------ la colonne

-- FCF_SetButtonSide de camelot : la colonne sur le fond
local function poserColonne(fenetre)
	local bf = fenetre.buttonFrame
	local fond = _G[fenetre:GetName() .. "Background"]
	if not (bf and fond) then return end
	bf:ClearAllPoints()
	if fenetre.buttonSide == "right" then
		bf:SetPoint("TOPLEFT", fond, "TOPRIGHT", G.colonneX, G.colonneHaut)
		bf:SetPoint("BOTTOMLEFT", fond, "BOTTOMRIGHT", G.colonneX, G.colonneBas)
	else
		bf:SetPoint("TOPRIGHT", fond, "TOPLEFT", -G.colonneX, G.colonneHaut)
		bf:SetPoint("BOTTOMRIGHT", fond, "BOTTOMLEFT", -G.colonneX, G.colonneBas)
	end
end

-- les boutons haut / bas / fin : l'OnShow de la fenetre les remontre
local function cacherFleches(fenetre)
	local nom = fenetre:GetName()
	for _, suffixe in ipairs({ "ButtonFrameUpButton", "ButtonFrameDownButton", "ButtonFrameBottomButton" }) do
		local b = _G[nom .. suffixe]
		if b then
			b:SetAlpha(0)
			b:EnableMouse(false)
			b:Hide()
		end
	end
end

-- le bouton d'amis : a gauche ou a droite de la colonne du chat par defaut
local function poserAmis()
	local b = FriendsMicroButton
	local bf = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.buttonFrame
	if not (b and bf) then return end
	b:ClearAllPoints()
	if DEFAULT_CHAT_FRAME.buttonSide == "right" then
		b:SetPoint("BOTTOMRIGHT", bf, "TOPRIGHT", 0, G.amisY)
	else
		b:SetPoint("BOTTOMLEFT", bf, "TOPLEFT", 0, G.amisY)
	end
end

local function habillerAmis()
	local b = FriendsMicroButton
	if not b or b.foreverChat then return end
	b.foreverChat = true
	b:SetWidth(G.amis)
	b:SetHeight(G.amis)
	for _, etat in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", ATLAS.amis },
		{ "SetPushedTexture", "GetPushedTexture", ATLAS.amisBas },
	}) do
		local e = ForeverUI.AtlasEntry(etat[3])
		b[etat[1]](b, e and e[1] or "")
		local t = b[etat[2]](b)
		if t then
			ForeverUI.SetAtlas(t, etat[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
		end
	end
	poserAmis()
end

-- ------------------------------------------------------------ la barre

local function taillePolice(fenetre)
	local _, taille = fenetre:GetFont()
	return taille or 14
end

-- ce que la barre montre : le nombre de messages, ceux qui tiennent, et
-- ou l'on est (en messages depuis le haut)
local function etatDefilement(fenetre)
	local total = fenetre:GetNumMessages() or 0
	local visibles = math.max(1, math.floor((fenetre:GetHeight() or 0) / (taillePolice(fenetre) + G.hautParLigne)))
	local maxi = math.max(0, total - visibles)
	local depuisBas = fenetre.GetCurrentScroll and fenetre:GetCurrentScroll() or 0
	return total, visibles, math.max(0, math.min(maxi, maxi - depuisBas)), maxi
end

-- deplacer la barre : le chat defile de la difference
function C.defiler(fenetre, rang)
	local _, _, courant, maxi = etatDefilement(fenetre)
	local voulu = math.max(0, math.min(maxi, rang))
	if fenetre.SetScrollOffset then
		fenetre:SetScrollOffset(maxi - voulu)
	else
		for _ = 1, courant - voulu do fenetre:ScrollUp() end
		for _ = 1, voulu - courant do fenetre:ScrollDown() end
	end
	C.majBarre(fenetre)
end

function C.majBarre(fenetre)
	local d = C.fenetres[fenetre]
	if not d then return end
	local total, visibles, rang = etatDefilement(fenetre)
	d.barre:Regler(total, visibles, rang)
end

-- ------------------------------------------------------------ le retour

local function creerRetour(fenetre)
	local nom = fenetre:GetName()
	local b = CreateFrame("Button", nom .. "ForeverScrollToBottom", fenetre)
	b:SetWidth(G.retourL)
	b:SetHeight(G.retourH)
	b:SetPoint("BOTTOMRIGHT", fenetre.resizeButton, "TOPRIGHT", G.retourX, G.retourY)
	for _, etat in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", ATLAS.retour },
		{ "SetPushedTexture", "GetPushedTexture", ATLAS.retourBas },
		{ "SetHighlightTexture", "GetHighlightTexture", ATLAS.retourSurvol },
	}) do
		local e = ForeverUI.AtlasEntry(etat[3])
		b[etat[1]](b, e and e[1] or "")
		local t = b[etat[2]](b)
		if t then
			ForeverUI.SetAtlas(t, etat[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
		end
	end
	local flash = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(flash, ATLAS.retour, true)
	flash:SetBlendMode("ADD")
	flash:SetAllPoints(b)
	flash:SetAlpha(0)
	b.flash = flash
	b:SetAlpha(0)
	b:SetScript("OnClick", function()
		PlaySound("igChatBottom")
		fenetre:ScrollToBottom()
		C.majBarre(fenetre)
	end)
	return b
end

-- ------------------------------------------------------------ le repos

-- les regions d'un cadre, sauf celles que le client anime lui-meme
local function regions(cadre, sauf, dans)
	for _, r in ipairs({ cadre:GetRegions() }) do
		if not sauf[r] then table.insert(dans, r) end
	end
end

-- ce qui s'efface au repos : les regions de l'onglet (sans sa lueur
-- d'alerte ; l'eclat TabFlash est un cadre fils, pas une region), les boutons de la colonne (sans les fleches, cachees), et pour
-- le chat par defaut le bouton de menu, le bouton d'amis et le bouton de
-- debordement du dock (sans sa surbrillance, qui clignote aux alertes) ;
-- a part, les regions de la saisie
function C.releverRepos(fenetre)
	local d = C.fenetres[fenetre]
	local nom = fenetre:GetName()
	d.effaces, d.saisie = {}, {}
	local onglet = _G[nom .. "Tab"]
	if onglet then
		regions(onglet, { [onglet.glow or false] = true }, d.effaces)
	end
	local fleches = {}
	for _, suffixe in ipairs({ "ButtonFrameUpButton", "ButtonFrameDownButton", "ButtonFrameBottomButton" }) do
		if _G[nom .. suffixe] then fleches[_G[nom .. suffixe]] = true end
	end
	for _, b in ipairs({ fenetre.buttonFrame:GetChildren() }) do
		if not fleches[b] then table.insert(d.effaces, b) end
	end
	if fenetre == DEFAULT_CHAT_FRAME then
		if ChatFrameMenuButton then table.insert(d.effaces, ChatFrameMenuButton) end
		if FriendsMicroButton then table.insert(d.effaces, FriendsMicroButton) end
		local debord = GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.overflowButton
		if debord then regions(debord, { [debord:GetHighlightTexture() or false] = true }, d.effaces) end
	end
	if fenetre.editBox then regions(fenetre.editBox, {}, d.saisie) end
end

-- le coefficient sur les pieces, a chaque image (le client remet l'alpha
-- du texte des onglets) ; la saisie active reste entiere
function C.poserRepos(fenetre)
	local d = C.fenetres[fenetre]
	local saisie = fenetre.editBox
	local active = saisie and (ACTIVE_CHAT_EDIT_BOX == saisie or saisie:HasFocus()) and true or false
	for _, objet in ipairs(d.effaces) do objet:SetAlpha(d.repos) end
	for _, r in ipairs(d.saisie) do r:SetAlpha(active and 1 or d.repos) end
end

-- la doublure : une copie de chaque texture du fond et de ses bords, sur
-- le meme cadre, au meme calque, aux memes coins
function C.doubler(fenetre)
	local d = C.fenetres[fenetre]
	local nom = fenetre:GetName()
	d.doublures = {}
	for _, suffixe in ipairs(CHAT_FRAME_TEXTURES or {}) do
		local o = _G[nom .. suffixe]
		if o then
			local t = o:GetParent():CreateTexture(nil, (o:GetDrawLayer()))
			t:SetTexture(o:GetTexture())
			t:SetTexCoord(o:GetTexCoord())
			t:SetAllPoints(o)
			t:SetAlpha(0)
			t:Hide()
			table.insert(d.doublures, { o, t })
		end
	end
end

-- ce qui manque au fond du client pour atteindre l'opacite allumee
function C.poserDoublure(fenetre)
	local d = C.fenetres[fenetre]
	local voulu = math.max(fenetre.oldAlpha or 0, DEFAULT_CHATFRAME_ALPHA or 0.25) * d.repos
	for _, paire in ipairs(d.doublures) do
		local o, t = paire[1], paire[2]
		local client = o:GetAlpha()
		if o:IsShown() and voulu > client + 0.001 then
			t:SetVertexColor(o:GetVertexColor())
			t:SetAlpha(1 - (1 - voulu) / (1 - client))
			t:Show()
		elseif t:IsShown() then
			t:SetAlpha(0)
			t:Hide()
		end
	end
end

-- ------------------------------------------------------------ une fenetre

function C.habiller(fenetre)
	if not fenetre or C.fenetres[fenetre] or not fenetre.buttonFrame then return end
	local nom = fenetre:GetName()
	-- le fond deborde a droite pour loger la barre
	local fond = _G[nom .. "Background"]
	if fond then
		fond:ClearAllPoints()
		fond:SetPoint("TOPLEFT", fenetre, "TOPLEFT", G.fondGauche, G.fondHaut)
		fond:SetPoint("TOPRIGHT", fenetre, "TOPRIGHT", G.fondDroite, G.fondHaut)
		fond:SetPoint("BOTTOMLEFT", fenetre, "BOTTOMLEFT", G.fondGauche, G.fondBas)
		fond:SetPoint("BOTTOMRIGHT", fenetre, "BOTTOMRIGHT", G.fondDroite, G.fondBas)
	end
	cacherFleches(fenetre)
	fenetre:HookScript("OnShow", cacherFleches)
	local bf = fenetre.buttonFrame
	if bf.minimizeButton then
		bf.minimizeButton:ClearAllPoints()
		bf.minimizeButton:SetPoint("TOP", bf, "TOP", 0, G.minimiserY)
	end
	poserColonne(fenetre)

	local d = { fenetre = fenetre }
	d.retour = creerRetour(fenetre)
	local barre = ForeverUI.CreateScrollBar(nom .. "ForeverScrollBar", fenetre, fenetre)
	barre:ClearAllPoints()
	barre:SetPoint("TOPLEFT", fenetre, "TOPRIGHT", 0, 0)
	barre:SetPoint("BOTTOMLEFT", d.retour, "TOPLEFT", 0, G.barreBas)
	barre:SetAlpha(0)
	barre.surDefilement = function(rang) C.defiler(fenetre, rang) end
	d.barre = barre
	-- les alphas vises : la barre et le retour s'allument avec le chat
	d.cibleBarre, d.cibleRetour = 0, 0
	d.vitesseBarre, d.vitesseRetour = 1, 1
	d.flashTemps = 0
	C.fenetres[fenetre] = d
	C.releverRepos(fenetre)
	C.doubler(fenetre)
	d.allume = fenetre.hasBeenFaded and true or false
	d.survol, d.dedans, d.dehors = false, 0, 0
	d.repos = d.allume and 1 or 0
	d.cibleRepos = d.repos
	d.vitesseRepos = 1
	C.poserRepos(fenetre)
	C.majBarre(fenetre)
end

-- ------------------------------------------------------------ le fondu

local function viser(d, barre, retour, dureeBarre, dureeRetour)
	d.cibleBarre = barre
	d.cibleRetour = retour
	d.vitesseBarre = G.barreAlpha / math.max(0.01, dureeBarre)
	d.vitesseRetour = G.retourAlpha / math.max(0.01, dureeRetour)
end

local function allumer(d)
	viser(d, G.barreAlpha, G.retourAlpha, G.venue, G.venueRetour)
	d.cibleRepos, d.vitesseRepos = 1, 1 / G.venue
end

local function eteindre(d)
	viser(d, 0, 0, G.depart, G.depart)
	d.cibleRepos, d.vitesseRepos = 0, 1 / G.depart
end

-- les zones de FCF_OnUpdate, plus la barre et le retour (hors du chat)
local function survolee(fenetre, d)
	if not fenetre:IsShown() then return false end
	local haut = 28
	if IsCombatLog and CombatLogQuickButtonFrame_Custom and IsCombatLog(fenetre) then
		haut = haut + CombatLogQuickButtonFrame_Custom:GetHeight()
	end
	return (fenetre:IsMouseOver(haut, -2, -2, 2)
		or (fenetre.isDocked and FriendsMicroButton and FriendsMicroButton:IsMouseOver())
		or (fenetre.buttonFrame and fenetre.buttonFrame:IsMouseOver())
		or (d.barre:IsShown() and MouseIsOver(d.barre)) or MouseIsOver(d.retour)) and true or false
end
C.survolee = survolee

local function approcher(objet, cible, vitesse, ecoule)
	local a = objet:GetAlpha()
	if a < cible then
		a = math.min(cible, a + vitesse * ecoule)
	elseif a > cible then
		a = math.max(cible, a - vitesse * ecoule)
	end
	objet:SetAlpha(a)
end

-- chaque image : la barre suit le chat, le fondu avance, le retour clignote
-- tant qu'on n'est pas en bas
local moteur = CreateFrame("Frame")
moteur:SetScript("OnUpdate", function(self, ecoule)
	ecoule = ecoule or 0
	-- le survol : 0,2 s dedans pour s'allumer, 1 s dehors pour s'eteindre
	local montrer, cacher = CHAT_TAB_SHOW_DELAY or 0.2, CHAT_TAB_HIDE_DELAY or 1
	local dock = false
	for fenetre, d in pairs(C.fenetres) do
		if survolee(fenetre, d) then
			d.dedans, d.dehors = d.dedans + ecoule, 0
			if d.dedans >= montrer then d.survol = true end
		else
			d.dedans, d.dehors = 0, d.dehors + ecoule
			if d.dehors >= cacher then d.survol = false end
		end
		if d.survol and fenetre.isDocked then dock = true end
	end
	for fenetre, d in pairs(C.fenetres) do
		local allume = (d.survol or fenetre.hasBeenFaded or (dock and fenetre.isDocked)) and true or false
		if allume ~= d.allume then
			d.allume = allume
			if allume then allumer(d) else eteindre(d) end
		end
		if d.repos < d.cibleRepos then
			d.repos = math.min(d.cibleRepos, d.repos + d.vitesseRepos * ecoule)
		elseif d.repos > d.cibleRepos then
			d.repos = math.max(d.cibleRepos, d.repos - d.vitesseRepos * ecoule)
		end
		C.poserRepos(fenetre)
		C.poserDoublure(fenetre)
		if fenetre:IsShown() then
			C.majBarre(fenetre)
			local enBas = fenetre:AtBottom()
			if enBas then
				d.flashTemps = 0
				d.retour.flash:SetAlpha(0)
			else
				-- 0,1 s pour venir, 0,5 s tenu, 0,1 s pour partir, 0,5 s eteint
				local cycle = 2 * (G.flashVenue + G.flashTenu)
				d.flashTemps = (d.flashTemps + ecoule) % cycle
				local t = d.flashTemps
				local a
				if t < G.flashVenue then a = t / G.flashVenue
				elseif t < G.flashVenue + G.flashTenu then a = 1
				elseif t < 2 * G.flashVenue + G.flashTenu then a = 1 - (t - G.flashVenue - G.flashTenu) / G.flashVenue
				else a = 0 end
				d.retour.flash:SetAlpha(a)
			end
			-- pas en bas : la barre s'allume, et le retour reste visible
			local cibleBarre = enBas and d.cibleBarre or G.barreAlpha
			local cibleRetour = enBas and d.cibleRetour or 1
			-- pas en bas, la barre vient comme au fondu (FCF_FadeInScrollbar)
			approcher(d.barre, cibleBarre, enBas and d.vitesseBarre or G.barreAlpha / G.venue, ecoule)
			approcher(d.retour, cibleRetour, math.max(d.vitesseRetour, G.retourAlpha / G.venueRetour), ecoule)
		end
	end
end)
C.moteur = moteur

-- ------------------------------------------------------------ le branchement

function C.habillerTout()
	for _, nom in ipairs(CHAT_FRAMES or {}) do
		C.habiller(_G[nom])
	end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		C.habiller(_G["ChatFrame" .. i])
	end
	habillerAmis()
	-- le bouton de menu, en bas de la colonne du chat par defaut
	if ChatFrameMenuButton and ChatFrame1ButtonFrame then
		ChatFrameMenuButton:ClearAllPoints()
		ChatFrameMenuButton:SetPoint("BOTTOM", ChatFrame1ButtonFrame, "BOTTOM", 0, 0)
	end
end

C.habillerTout()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(self, _, addon)
	if addon ~= "ForeverUI" then return end
	self:UnregisterEvent("ADDON_LOADED")
	ForeverUIDB = ForeverUIDB or {}
	if ForeverUIDB.chatFondRepos then return end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		SetChatWindowAlpha(i, G.fondRepos)
	end
	ForeverUIDB.chatFondRepos = true
end)
C.veille = veille

if FCF_SetButtonSide then
	hooksecurefunc("FCF_SetButtonSide", function(fenetre)
		if C.fenetres[fenetre] then poserColonne(fenetre) end
		if fenetre == DEFAULT_CHAT_FRAME then poserAmis() end
	end)
end
if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", C.habillerTout) end

-- TEMOIN -- /fui chat
function ForeverUI.ChatDebug()
	local dire = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t) end
	for fenetre, d in pairs(C.fenetres) do
		if fenetre:IsShown() then
			local total, visibles, rang, maxi = etatDefilement(fenetre)
			dire(string.format("chat %s : %d messages, %d visibles, rang %d/%d, en bas %s | barre %s alpha %.2f | retour alpha %.2f | SetScrollOffset %s",
				fenetre:GetName(), total, visibles, rang, maxi, tostring(fenetre:AtBottom()),
				d.barre:IsShown() and "affichee" or "cachee", d.barre:GetAlpha(), d.retour:GetAlpha(),
				fenetre.SetScrollOffset and "oui" or "non"))
			-- ce que FCF_OnUpdate regarde avant d'eteindre le chat, et nos pieces
			local function oui(v) return v and "OUI" or "non" end
			dire(string.format("   allume %s (client %s, survol %s), dehors depuis %.1f s | souris sur : chat %s, amis %s, colonne %s, barre %s, retour %s",
				oui(d.allume), oui(fenetre.hasBeenFaded), oui(d.survol), d.dehors,
				oui(fenetre:IsMouseOver(28, -2, -2, 2)), oui(fenetre.isDocked and FriendsMicroButton and FriendsMicroButton:IsMouseOver()),
				oui(fenetre.buttonFrame and fenetre.buttonFrame:IsMouseOver()),
				oui(d.barre:IsShown() and MouseIsOver(d.barre)), oui(MouseIsOver(d.retour))))
			local _, _, _, _, _, opacite = GetChatWindowInfo(fenetre:GetID())
			dire(string.format("   repos : coefficient %.2f (vise %d) sur %d pieces + %d de saisie | fond %.2f (retenue %.2f, faite %s)",
				d.repos, d.cibleRepos, #d.effaces, #d.saisie, _G[fenetre:GetName() .. "Background"]:GetAlpha(),
				opacite or -1, oui(ForeverUIDB and ForeverUIDB.chatFondRepos)))
		end
	end
end
