-- ForeverUI : la fenetre de chat, a la DA de camelot -- etape 1, le cadre
-- (demande de l'utilisateur, 2026-09-26) ; etape 2, les onglets et la saisie
-- (2026-09-28) ; memoire foreverui-chat.
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
--   onglets      ChatTabArtTemplate : le cote gauche a BOTTOMLEFT (-2,0) de
--                l'onglet, le droit a BOTTOMRIGHT (2,0), le milieu tendu
--                entre eux (3.3.5 : le gauche a TOPLEFT (0,0), le milieu de
--                la largeur du texte, le droit a sa suite) ; ChatTabTemplate :
--                le texte au CENTRE (0,-5) (3.3.5 : a gauche, contre le cote
--                gauche, (0,-5)) ; PanelTemplates_TabResize : largeur = texte
--                + 20 + marge, au moins les deux cotes (32) ; a taille
--                imposee, le texte prend taille - 20 - marge (3.3.5 : texte +
--                marge + les deux cotes)
--   dock         FCFDock_SetPrimary : le dock sur le HAUT DU FOND du chat
--                principal (3.3.5 : sur le haut du chat, a 6) ;
--                FCFDock_UpdateTabs : le premier onglet a BOTTOMLEFT (0,0) du
--                dock, les suivants a 1 du precedent (3.3.5 : a 0) ; ceux des
--                chuchotements depuis LEFT (0,-1) de la liste defilante, a 1
--                l'un de l'autre ; la liste a BOTTOMRIGHT (0,0) du dock
--                (3.3.5 : (0,-5)) ; le bouton de debordement a BOTTOMRIGHT
--                (0,0) du dock (3.3.5 : (0,-5)), la liste s'arretant alors 5
--                avant lui, 1 plus bas
--   saisie       TOPLEFT sur le BOTTOMLEFT du chat (-5,-2), comme 3.3.5 ; le
--                bord droit sur celui de la barre, +8 -- 16 au-dela du chat
--                (3.3.5 : 5)
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
-- FCF_SetButtonSide (la colonne), FCF_OpenTemporaryWindow (les fenetres de chuchotement),
-- PanelTemplates_TabResize (pour les seuls onglets du chat), FCFDock_UpdateTabs
-- et FCFDock_SetPrimary (le dock). Les
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
local L = ForeverUI.L

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
	ongletCote = 2, ongletMarges = 20, ongletTexteY = -5,
	ongletEcart = 1, ongletMobileY = -1, debordEcart = 5, debordY = -1,
	saisieX = -5, saisieY = -2, saisieDroite = 8,
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

-- ------------------------------------------------------------ les onglets

C.onglets = {}

-- ChatTabArtTemplate de camelot : les cotes debordent de 2 de chaque cote de
-- l'onglet, le milieu s'etire entre eux (le choisi et la surbrillance
-- suivent : ils sont poses sur eux) ; le texte au centre, sauf celui d'un
-- onglet de chuchotement, a gauche derriere son icone (FCF_OpenTemporaryWindow,
-- le meme dans les deux)
function C.habillerOnglet(onglet)
	if not onglet or C.onglets[onglet] then return end
	local nom = onglet:GetName()
	local gauche, milieu, droite = _G[nom .. "Left"], _G[nom .. "Middle"], _G[nom .. "Right"]
	if not (gauche and milieu and droite) then return end
	C.onglets[onglet] = true
	gauche:ClearAllPoints()
	gauche:SetPoint("BOTTOMLEFT", onglet, "BOTTOMLEFT", -G.ongletCote, 0)
	droite:ClearAllPoints()
	droite:SetPoint("BOTTOMRIGHT", onglet, "BOTTOMRIGHT", G.ongletCote, 0)
	milieu:ClearAllPoints()
	milieu:SetPoint("LEFT", gauche, "RIGHT", 0, 0)
	milieu:SetPoint("RIGHT", droite, "LEFT", 0, 0)
	local texte = _G[nom .. "Text"]
	if texte and not onglet.conversationIcon then
		texte:ClearAllPoints()
		texte:SetPoint("CENTER", onglet, "CENTER", 0, G.ongletTexteY)
	end
end

-- PanelTemplates_TabResize de camelot : le texte + 20 + la marge, au moins
-- les deux cotes ; a taille imposee, le texte prend le reste
function C.redimensionner(onglet, marge, taille, texteAbsolu)
	local nom = onglet:GetName()
	local texte = _G[nom .. "Text"]
	if not texte then return end
	marge = marge or 0
	texte:SetWidth(texteAbsolu or 0)
	local largeurTexte = texte:GetStringWidth()
	local largeur = largeurTexte + G.ongletMarges + marge
	local cotes = _G[nom .. "Left"]:GetWidth() + _G[nom .. "Right"]:GetWidth()
	if taille then
		largeur = math.max(taille, cotes)
		largeurTexte = largeur - G.ongletMarges - marge
	elseif largeur < cotes then
		largeur = cotes
		largeurTexte = largeur - G.ongletMarges - marge
	end
	texte:SetWidth(largeurTexte)
	onglet:SetWidth(largeur)
end

-- FCFDock_SetPrimary de camelot : le dock sur le haut du fond du chat
-- principal
function C.poserAncrageDock(dock)
	local primaire = dock and dock.primary
	local fond = primaire and _G[primaire:GetName() .. "Background"]
	if not fond then return end
	dock:ClearAllPoints()
	dock:SetPoint("BOTTOMLEFT", fond, "TOPLEFT", 0, 0)
	dock:SetPoint("BOTTOMRIGHT", fond, "TOPRIGHT", 0, 0)
end

-- FCFDock_UpdateTabs de camelot : les onglets fixes depuis le bas a gauche
-- du dock, ceux des chuchotements depuis la gauche de la liste defilante,
-- chacun a 1 du precedent ; le bouton de debordement au bas a droite du
-- dock, la liste 5 avant lui
function C.poserDock(dock)
	if not (dock and dock.DOCKED_CHAT_FRAMES and dock.scrollFrame) then return end
	local enfant = dock.scrollFrame:GetScrollChild()
	local dernierFixe, dernierMobile
	for _, fenetre in ipairs(dock.DOCKED_CHAT_FRAMES) do
		local onglet = _G[fenetre:GetName() .. "Tab"]
		if onglet then
			onglet:ClearAllPoints()
			if fenetre.isStaticDocked then
				if dernierFixe then
					onglet:SetPoint("LEFT", dernierFixe, "RIGHT", G.ongletEcart, 0)
				else
					onglet:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
				end
				dernierFixe = onglet
			else
				if dernierMobile then
					onglet:SetPoint("LEFT", dernierMobile, "RIGHT", G.ongletEcart, 0)
				elseif enfant then
					onglet:SetPoint("LEFT", enfant, "LEFT", 0, G.ongletMobileY)
				end
				dernierMobile = onglet
			end
		end
	end
	local debord = dock.overflowButton
	if debord then
		debord:ClearAllPoints()
		debord:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
	end
	if debord and debord:IsShown() then
		dock.scrollFrame:SetPoint("BOTTOMRIGHT", debord, "BOTTOMLEFT", -G.debordEcart, G.debordY)
	else
		dock.scrollFrame:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
	end
end

-- l'onglet d'une fenetre qu'on habille : l'art, puis la taille (celle que
-- le dock lui impose s'il est dans sa liste defilante)
local function habillerOngletDe(fenetre)
	local onglet = _G[fenetre:GetName() .. "Tab"]
	C.habillerOnglet(onglet)
	if not C.onglets[onglet] then return end
	local dock = GENERAL_CHAT_DOCK
	local taille
	if fenetre.isDocked and not fenetre.isStaticDocked and dock and dock.scrollFrame then
		taille = dock.scrollFrame.dynTabSize
	end
	C.redimensionner(onglet, onglet.sizePadding or 0, taille)
end

-- ------------------------------------------------------------ la selection

-- Alt maintenu, on glisse sur le chat : le texte se surligne comme dans un
-- editeur. Le seul chemin vers le presse-papiers en 3.3.5 est Ctrl+C dans
-- une saisie : une saisie invisible, en lecture seule, porte le texte ; elle
-- ne prend le clavier que PENDANT QUE Ctrl EST ENFONCE (le C qui suit copie),
-- et le rend au relachement de Ctrl. Le reste du temps, le clavier est au
-- jeu : 3.3.5 ne sait pas voir une touche sans la lui prendre (ni IsKeyDown
-- ni transmission des touches).
-- TOUT AUTRE GESTE EFFACE LA SELECTION (demande du 2026-09-28, « le jeu garde
-- le clavier ») : Ctrl relache (Ctrl+C fait ou non), un clic, se deplacer,
-- tourner, sauter (hors taxi), lancer un sort, une autre saisie qui prend le
-- clavier (celle du chat), une fenetre qui s'ouvre (ShowUIPanel), Echap
-- (ToggleGameMenu), le chat qui defile ou dont un message selectionne
-- change, le chat cache. Une touche sans effet visible de l'addon laisse la
-- selection.
-- (demande de l'utilisateur, 2026-09-28 ; ni 3.3.5 ni camelot ne le font)
--
-- RELEVE EN JEU (/fui chatlignes, 2026-09-28) : le moteur fait UN objet
-- texte par message, coupe sur plusieurs lignes a la largeur du chat (5
-- lignes de 14,33 pour le message d'essai), sans retrait (l'objet texte ne
-- l'a pas, meme si le chat l'a) ; la meme police, a la meme largeur, rend
-- la meme hauteur, et la meme largeur a 0,7 pres. On retrouve donc les
-- coupures du moteur en mesurant : la hauteur du texte jusqu'a la fin de
-- chaque mot donne la ligne ou il tombe (le moteur coupe mot a mot, et un
-- debut de texte se coupe comme le texte entier) ; un mot plus long qu'une
-- ligne se mesure lettre a lettre.

local S = { cache = {} }
C.selection = S

-- une methode que le client n'a peut-etre pas : rien plutot qu'une erreur
local function appel(objet, methode, ...)
	if not objet[methode] then return nil end
	local r = { pcall(objet[methode], objet, ...) }
	if not r[1] then return nil end
	return r[2], r[3], r[4], r[5]
end

-- la couleur du surlignage (ce n'est pas un element de camelot)
S.couleur = { 0.3, 0.5, 1, 0.4 }

-- les marques de raid, telles qu'on les tape dans le chat : l'etiquette du
-- client (ICON_TAG_RAID_TARGET_*1 ; en anglais {rt1} a {rt8})
local MARQUES = { "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL" }
local function etiquetteImage(brut)
	local n = tonumber(string.match(brut, "RaidTargetingIcon_(%d)"))
	local nom = n and MARQUES[n] and _G["ICON_TAG_RAID_TARGET_" .. MARQUES[n] .. "1"]
	return nom and ("{" .. nom .. "}") or ""
end

-- ce qui se voit d'un message, unite par unite : une lettre (UTF-8), une
-- barre (||), une image (|T...|t) ; les codes de couleur (|c, |r) et de
-- lien (|H...|h, |h) ne se voient pas -- le texte d'un lien, si
function C.unites(texte)
	local u, i, n = {}, 1, string.len(texte or "")
	while i <= n do
		local c = string.sub(texte, i, i)
		if c == "|" then
			local s = string.sub(texte, i + 1, i + 1)
			if s == "c" then
				i = i + 10
			elseif s == "r" or s == "h" then
				i = i + 2
			elseif s == "H" then
				local fin = string.find(texte, "|h", i + 2, true)
				i = fin and fin + 2 or n + 1
			elseif s == "T" then
				local fin = string.find(texte, "|t", i + 2, true) or n
				local brut = string.sub(texte, i, fin + 1)
				table.insert(u, { brut = brut, copie = etiquetteImage(brut) })
				i = fin + 2
			elseif s == "n" then
				table.insert(u, { brut = "", copie = "\n" })
				i = i + 2
			else
				table.insert(u, { brut = "||", copie = "|" })
				i = i + (s == "|" and 2 or 1)
			end
		else
			local b = string.byte(c)
			local l = (b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1
			local lettre = string.sub(texte, i, i + l - 1)
			table.insert(u, { brut = lettre, copie = lettre, espace = (lettre == " ") })
			i = i + l
		end
	end
	return u
end

local function brut(unites, a, b)
	local t = {}
	for k = a, b do t[#t + 1] = unites[k].brut end
	return table.concat(t)
end

-- deux objets texte de mesure, invisibles : l'un sur une ligne, l'autre a
-- la largeur du message ; ils prennent la police et les reglages de
-- l'objet texte mesure
local mesures
local function mesurer(r, c)
	if not mesures then
		local cadre = CreateFrame("Frame", nil, UIParent)
		cadre:SetAlpha(0)
		cadre:SetWidth(1)
		cadre:SetHeight(1)
		cadre:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
		mesures = { ligne = cadre:CreateFontString(nil, "ARTWORK"), bloc = cadre:CreateFontString(nil, "ARTWORK") }
		mesures.ligne:SetPoint("TOPLEFT", cadre, "TOPLEFT", 0, 0)
		mesures.bloc:SetPoint("TOPLEFT", cadre, "TOPLEFT", 0, 0)
	end
	local police, taille, contour = r:GetFont()
	for _, m in pairs(mesures) do
		m:SetFont(police, taille, contour)
		if m.SetSpacing then m:SetSpacing(appel(r, "GetSpacing") or 0) end
	end
	mesures.ligne:SetWidth(0)
	mesures.bloc:SetWidth(c and c.largeur or r:GetWidth())
	if mesures.bloc.SetIndentedWordWrap then mesures.bloc:SetIndentedWordWrap(appel(r, "GetIndentedWordWrap") and true or false) end
	if mesures.bloc.SetNonSpaceWrap then mesures.bloc:SetNonSpaceWrap(appel(r, "CanNonSpaceWrap") and true or false) end
	return mesures
end

-- la mise en lignes d'un objet texte du chat : ses unites, le debut de
-- chaque ligne, la hauteur d'une ligne ; gardee tant que son texte et sa
-- largeur ne changent pas
function C.disposer(r)
	local texte, largeur = r:GetText() or "", r:GetWidth()
	local c = S.cache[r]
	if c and c.texte == texte and c.largeur == largeur then return c end
	c = { texte = texte, largeur = largeur, largeurs = {} }
	local m = mesurer(r, c)
	m.ligne:SetText("A")
	c.hauteurLigne = math.max(1, m.ligne:GetStringHeight())
	local u = C.unites(texte)
	c.unites = u
	local function lignes(b)
		m.bloc:SetText(brut(u, 1, b))
		return math.floor(m.bloc:GetStringHeight() / c.hauteurLigne + 0.5)
	end
	local debuts, faites = { 1 }, 1
	local a, n = 1, #u
	while a <= n do
		while a <= n and u[a].espace do a = a + 1 end
		if a > n then break end
		local b = a
		while b < n and not u[b + 1].espace do b = b + 1 end
		local L = lignes(b)
		if L > faites then
			m.ligne:SetText(brut(u, a, b))
			if m.ligne:GetStringWidth() <= largeur then
				-- le mot passe a la ligne suivante
				for k = faites + 1, L do debuts[k] = a end
			else
				-- un mot plus long qu'une ligne : coupe a la lettre
				for v = a, b do
					local Lv = lignes(v)
					for k = faites + 1, Lv do debuts[k] = v end
					if Lv > faites then faites = Lv end
				end
			end
			faites = math.max(faites, L)
		end
		a = b + 1
	end
	c.debuts, c.nLignes = debuts, #debuts
	S.cache[r] = c
	return c
end

-- la largeur, depuis le debut de la ligne n, jusqu'a la frontiere b (avant
-- l'unite b)
local function largeurJusqua(r, c, n, b)
	local debut = c.debuts[n]
	if b <= debut then return 0 end
	local cle = n * 100000 + b
	if not c.largeurs[cle] then
		local m = mesurer(r, c)
		m.ligne:SetText(brut(c.unites, debut, b - 1))
		c.largeurs[cle] = m.ligne:GetStringWidth()
	end
	return c.largeurs[cle]
end

-- les messages affiches, de haut en bas
function C.messagesVisibles(fenetre)
	local liste = {}
	for _, r in ipairs({ fenetre:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:IsVisible() and (r:GetAlpha() or 0) > 0.01
			and (r:GetText() or "") ~= "" and r:GetTop() then
			table.insert(liste, r)
		end
	end
	table.sort(liste, function(p, q) return p:GetTop() > q:GetTop() end)
	return liste
end

-- le curseur, dans l'unite du chat
local function curseur(fenetre)
	local x, y = GetCursorPosition()
	local e = fenetre:GetEffectiveScale()
	return x / e, y / e
end

-- sous le curseur : le rang du message et la frontiere la plus proche ;
-- au-dessus du premier, son debut ; sous le dernier, sa fin
function C.pointer(liste, x, y)
	if #liste == 0 then return nil end
	if y > liste[1]:GetTop() then return 1, 1 end
	for rang, r in ipairs(liste) do
		if y >= r:GetBottom() or rang == #liste then
			local c = C.disposer(r)
			if y < r:GetBottom() then return rang, #c.unites + 1 end
			local n = math.min(c.nLignes, math.max(1, math.floor((r:GetTop() - y) / c.hauteurLigne) + 1))
			local debut = c.debuts[n]
			local fin = c.debuts[n + 1] or (#c.unites + 1)
			local xr = x - r:GetLeft()
			local bas, haut = debut, fin
			while bas < haut do
				local milieu = math.floor((bas + haut) / 2)
				if largeurJusqua(r, c, n, milieu) < xr then bas = milieu + 1 else haut = milieu end
			end
			local b = bas
			if b > debut and (xr - largeurJusqua(r, c, n, b - 1)) < (largeurJusqua(r, c, n, b) - xr) then
				b = b - 1
			end
			return rang, b
		end
	end
end

-- l'ancre et le bout, dans l'ordre de lecture
local function bornes()
	local a, b = S.ancre, S.bout
	if a[1] > b[1] or (a[1] == b[1] and a[2] > b[2]) then a, b = b, a end
	return a, b
end

-- le surlignage : un rectangle par morceau de ligne, sur le chat lui-meme
-- (calque BORDER : sous le texte)
function C.peindre()
	local d = S.fenetre and C.fenetres[S.fenetre]
	if not d then return end
	local k = 0
	if S.ancre and S.bout then
		local a, b = bornes()
		for rang = a[1], b[1] do
			local r = S.messages[rang]
			local c = C.disposer(r)
			local du = (rang == a[1]) and a[2] or 1
			local au = (rang == b[1]) and b[2] or (#c.unites + 1)
			for n = 1, c.nLignes do
				local p = math.max(c.debuts[n], du)
				local q = math.min(c.debuts[n + 1] or (#c.unites + 1), au)
				if p < q then
					local x1, x2 = largeurJusqua(r, c, n, p), largeurJusqua(r, c, n, q)
					if x2 > x1 then
						k = k + 1
						local t = d.surlignes[k]
						if not t then
							t = S.fenetre:CreateTexture(nil, "BORDER")
							t:SetTexture(S.couleur[1], S.couleur[2], S.couleur[3], S.couleur[4])
							d.surlignes[k] = t
						end
						t:ClearAllPoints()
						t:SetPoint("TOPLEFT", r, "TOPLEFT", x1, -(n - 1) * c.hauteurLigne)
						t:SetWidth(x2 - x1)
						t:SetHeight(c.hauteurLigne)
						t:Show()
					end
				end
			end
		end
	end
	for i = k + 1, #d.surlignes do d.surlignes[i]:Hide() end
end

-- le texte a copier : ce qui se voit, les liens par leur texte, les
-- marques par leur nom ; un message par ligne
function C.texteSelection()
	if not (S.ancre and S.bout) then return "" end
	local a, b = bornes()
	local parties = {}
	for rang = a[1], b[1] do
		local c = C.disposer(S.messages[rang])
		local du = (rang == a[1]) and a[2] or 1
		local au = (rang == b[1]) and b[2] or (#c.unites + 1)
		local t = {}
		for k = du, au - 1 do t[#t + 1] = c.unites[k].copie end
		parties[#parties + 1] = table.concat(t)
	end
	return table.concat(parties, "\n")
end

-- la saisie invisible qui porte la copie ; en lecture seule : ce qu'on y
-- tape est defait
local boite = CreateFrame("EditBox", nil, UIParent)
boite:SetMultiLine(true)
boite:SetAutoFocus(false)
boite:SetFontObject(ChatFontNormal)
boite:SetWidth(200)
boite:SetHeight(20)
boite:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
boite:SetAlpha(0)
boite:EnableMouse(false)
S.boite = boite

function C.effacer()
	local d = S.fenetre and C.fenetres[S.fenetre]
	S.fenetre, S.messages, S.ancre, S.bout, S.glisse, S.texte = nil, nil, nil, nil, false, nil
	S.ctrl, S.base = false, nil
	if d then
		for _, t in ipairs(d.surlignes) do t:Hide() end
	end
	if boite:HasFocus() then boite:ClearFocus() end
end

boite:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
boite:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
boite:SetScript("OnEditFocusLost", function()
	if S.texte then C.effacer() end
end)
boite:SetScript("OnTextChanged", function(self, saisi)
	if saisi and S.texte then
		self:SetText(S.texte)
		self:HighlightText()
	end
end)

function C.commencer(fenetre)
	C.effacer()
	local liste = C.messagesVisibles(fenetre)
	local rang, b = C.pointer(liste, curseur(fenetre))
	if not rang then return end
	S.fenetre, S.messages, S.glisse = fenetre, liste, true
	S.ancre, S.bout = { rang, b }, { rang, b }
	C.peindre()
end

function C.suivre()
	local rang, b = C.pointer(S.messages, curseur(S.fenetre))
	if rang and (rang ~= S.bout[1] or b ~= S.bout[2]) then
		S.bout = { rang, b }
		C.peindre()
	end
end

function C.terminer()
	if not S.glisse then return end
	C.suivre()
	S.glisse = false
	local texte = C.texteSelection()
	if texte == "" then
		C.effacer()
		return
	end
	S.texte = texte
	boite:SetText(texte)
	-- ce qu'on surveille pour effacer : le personnage, le defilement du
	-- chat, le texte des messages selectionnes
	local vitesse = GetUnitSpeed and GetUnitSpeed("player") or 0
	S.base = {
		taxi = UnitOnTaxi and UnitOnTaxi("player") and true or false,
		vitesse = vitesse,
		face = GetPlayerFacing and GetPlayerFacing() or 0,
		chute = IsFalling and IsFalling() and true or false,
		defilement = S.fenetre.GetCurrentScroll and S.fenetre:GetCurrentScroll() or 0,
		textes = {},
	}
	for rang, r in ipairs(S.messages) do S.base.textes[rang] = r:GetText() end
end

-- un geste autre que Ctrl+C, une fois la selection faite ?
function C.autreGeste()
	local b = S.base
	if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") or IsMouseButtonDown("MiddleButton") then
		return true
	end
	if not S.fenetre:IsVisible() then return true end
	local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
	if focus and focus ~= boite then return true end
	if not b.taxi then
		if (GetUnitSpeed and GetUnitSpeed("player") or 0) ~= b.vitesse then return true end
		if math.abs((GetPlayerFacing and GetPlayerFacing() or 0) - b.face) > 0.001 then return true end
		if (IsFalling and IsFalling() and true or false) ~= b.chute then return true end
	end
	if (S.fenetre.GetCurrentScroll and S.fenetre:GetCurrentScroll() or 0) ~= b.defilement then return true end
	for rang, r in ipairs(S.messages) do
		if r:GetText() ~= b.textes[rang] then return true end
	end
	return false
end

-- une fois la selection faite : Ctrl enfonce, la saisie prend le clavier ;
-- Ctrl relache, ou tout autre geste, et la selection s'efface
function C.veillerCopie()
	if IsControlKeyDown() then
		if not S.ctrl then
			S.ctrl = true
			boite:SetText(S.texte)
			boite:SetFocus()
			boite:HighlightText()
		end
	elseif S.ctrl then
		C.effacer()
		return
	end
	if C.autreGeste() then C.effacer() end
end

-- la surface qui prend la souris sur le chat, Alt maintenu seulement : sans
-- Alt, le chat laisse passer les clics (monde, liens) comme avant
function C.creerCapteur(fenetre, d)
	d.surlignes = {}
	local capteur = CreateFrame("Frame", nil, fenetre)
	capteur:SetAllPoints(fenetre)
	capteur:EnableMouse(false)
	capteur:SetScript("OnMouseDown", function(_, bouton)
		if bouton == "LeftButton" then C.commencer(fenetre) end
	end)
	capteur:SetScript("OnMouseUp", function(_, bouton)
		if bouton == "LeftButton" then C.terminer() end
	end)
	d.capteur, d.prise = capteur, false
end

local veilleSelection = CreateFrame("Frame")
veilleSelection:SetScript("OnUpdate", function()
	local alt = IsAltKeyDown() and true or false
	for fenetre, d in pairs(C.fenetres) do
		local prise = ((alt and fenetre:IsVisible()) or (S.glisse and S.fenetre == fenetre)) and true or false
		if prise ~= d.prise then
			d.prise = prise
			d.capteur:EnableMouse(prise)
		end
	end
	if S.glisse then
		C.suivre()
	elseif S.texte then
		C.veillerCopie()
	end
end)
C.veilleSelection = veilleSelection

-- un sort lance, une fenetre ouverte, Echap : la selection s'efface
local function horsCopie()
	if S.texte and not S.glisse then C.effacer() end
end
veilleSelection:RegisterEvent("UNIT_SPELLCAST_SENT")
veilleSelection:SetScript("OnEvent", function(_, _, unite)
	if unite == "player" then horsCopie() end
end)
if ShowUIPanel then hooksecurefunc("ShowUIPanel", horsCopie) end
if ToggleGameMenu then hooksecurefunc("ToggleGameMenu", horsCopie) end

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
	-- la saisie : TOPLEFT comme 3.3.5, le bord droit sur celui de la barre,
	-- + 8 (camelot : RIGHT sur la barre ; le meme point, pris ici sur le
	-- chat -- la barre part de son TOPRIGHT -- pour que la hauteur reste
	-- donnee par le seul TOPLEFT)
	local saisie = fenetre.editBox
	if saisie then
		saisie:ClearAllPoints()
		saisie:SetPoint("TOPLEFT", fenetre, "BOTTOMLEFT", G.saisieX, G.saisieY)
		saisie:SetPoint("TOPRIGHT", fenetre, "BOTTOMRIGHT", barre:GetWidth() + G.saisieDroite, G.saisieY)
	end
	habillerOngletDe(fenetre)
	-- les alphas vises : la barre et le retour s'allument avec le chat
	d.cibleBarre, d.cibleRetour = 0, 0
	d.vitesseBarre, d.vitesseRetour = 1, 1
	d.flashTemps = 0
	C.fenetres[fenetre] = d
	C.creerCapteur(fenetre, d)
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
	-- le dock, et ses onglets (ceux d'une fenetre qu'on vient d'habiller
	-- ont ete poses par le client avant elle)
	C.poserAncrageDock(GENERAL_CHAT_DOCK)
	C.poserDock(GENERAL_CHAT_DOCK)
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
-- la taille des onglets du chat (et d'eux seuls : la fonction sert a tous
-- les onglets du jeu) ; le dock, apres chaque remise en ordre du client
if PanelTemplates_TabResize then
	hooksecurefunc("PanelTemplates_TabResize", function(onglet, marge, taille, _, texteAbsolu)
		if C.onglets[onglet] then C.redimensionner(onglet, marge, taille, texteAbsolu) end
	end)
end
if FCFDock_UpdateTabs then hooksecurefunc("FCFDock_UpdateTabs", C.poserDock) end
if FCFDock_SetPrimary then hooksecurefunc("FCFDock_SetPrimary", C.poserAncrageDock) end

-- TEMOIN -- /fui chat
function ForeverUI.ChatDebug()
	local dire = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t) end
	for fenetre, d in pairs(C.fenetres) do
		if fenetre:IsShown() then
			local total, visibles, rang, maxi = etatDefilement(fenetre)
			dire(string.format(L.CHAT_DEBUG_STATE,
				fenetre:GetName(), total, visibles, rang, maxi, tostring(fenetre:AtBottom()),
				d.barre:IsShown() and L.CHAT_DEBUG_SHOWN or L.CHAT_DEBUG_HIDDEN, d.barre:GetAlpha(), d.retour:GetAlpha(),
				fenetre.SetScrollOffset and L.CHAT_DEBUG_YES or L.CHAT_DEBUG_NO))
			-- ce que FCF_OnUpdate regarde avant d'eteindre le chat, et nos pieces
			local function oui(v) return v and L.CHAT_DEBUG_YES_UPPER or L.CHAT_DEBUG_NO end
			dire(string.format(L.CHAT_DEBUG_FADE,
				oui(d.allume), oui(fenetre.hasBeenFaded), oui(d.survol), d.dehors,
				oui(fenetre:IsMouseOver(28, -2, -2, 2)), oui(fenetre.isDocked and FriendsMicroButton and FriendsMicroButton:IsMouseOver()),
				oui(fenetre.buttonFrame and fenetre.buttonFrame:IsMouseOver()),
				oui(d.barre:IsShown() and MouseIsOver(d.barre)), oui(MouseIsOver(d.retour))))
			local _, _, _, _, _, opacite = GetChatWindowInfo(fenetre:GetID())
			dire(string.format(L.CHAT_DEBUG_REST,
				d.repos, d.cibleRepos, #d.effaces, #d.saisie, _G[fenetre:GetName() .. "Background"]:GetAlpha(),
				opacite or -1, oui(ForeverUIDB and ForeverUIDB.chatFondRepos)))
		end
	end
end

-- RELEVE -- /fui chatlignes (2026-09-28, avant la selection au glisser) :
-- comment le moteur pose les lignes du chat -- un objet texte par message,
-- ou un par ligne a l'ecran -- et si une mesure avec la meme police rend la
-- meme largeur. Un long message d'essai est ajoute a la fenetre affichee ;
-- deux images plus tard, ses objets texte sont releves dans
-- ForeverUIDB.releveChat (ecrit sur le disque au /reload suivant).
-- Le texte est L.CHAT_LINES_TEST (le lien puis l'icone en %s) ; le nom de
-- la pierre de foyer vient du client (GetItemInfo), son numero s'il ne l'a
-- pas encore en cache.
local function essai()
	local lien = "|cffffffff|Hitem:6948:0:0:0:0:0:0:0:80|h[" .. (GetItemInfo(6948) or "6948") .. "]|h|r"
	return string.format(L.CHAT_LINES_TEST, lien,
		"|TInterface" .. SEP .. "TargetingFrame" .. SEP .. "UI-RaidTargetingIcon_1:0|t")
end

local support, mesure
function C.releverLignes(fenetre)
	if not support then
		support = CreateFrame("Frame", nil, UIParent)
		support:SetAlpha(0)
		support:SetWidth(1)
		support:SetHeight(1)
		support:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
		mesure = support:CreateFontString(nil, "ARTWORK")
		mesure:SetPoint("TOPLEFT", support, "TOPLEFT", 0, 0)
	end
	local rel = { fenetre = fenetre:GetName() }
	rel.gauche, rel.haut, rel.droite, rel.bas = fenetre:GetLeft(), fenetre:GetTop(), fenetre:GetRight(), fenetre:GetBottom()
	rel.largeur, rel.hauteur, rel.echelle = fenetre:GetWidth(), fenetre:GetHeight(), fenetre:GetEffectiveScale()
	rel.police, rel.taille, rel.contour = fenetre:GetFont()
	rel.espacement = appel(fenetre, "GetSpacing")
	rel.justification = appel(fenetre, "GetJustifyH")
	rel.retrait = appel(fenetre, "GetIndentedWordWrap")
	rel.insertion = appel(fenetre, "GetInsertMode")
	rel.messages = appel(fenetre, "GetNumMessages")
	rel.lignesAffichees = appel(fenetre, "GetNumLinesDisplayed")
	rel.ligneCourante = appel(fenetre, "GetCurrentLine")
	rel.defilement = appel(fenetre, "GetCurrentScroll")
	-- les derniers messages, tels que le client les garde
	rel.derniers = {}
	local n = rel.messages or 0
	for i = math.max(1, n - 5), n do
		table.insert(rel.derniers, { rang = i, texte = (appel(fenetre, "GetMessageInfo", i)) })
	end
	-- les objets texte de la fenetre
	rel.textes = {}
	local visibles = 0
	for rang, r in ipairs({ fenetre:GetRegions() }) do
		if r:GetObjectType() == "FontString" then
			local t = { rang = rang }
			t.montre, t.visible, t.alpha = r:IsShown() and true or false, r:IsVisible() and true or false, r:GetAlpha()
			t.gauche, t.haut, t.droite, t.bas = r:GetLeft(), r:GetTop(), r:GetRight(), r:GetBottom()
			t.largeur, t.hauteur = r:GetWidth(), r:GetHeight()
			t.largeurTexte, t.hauteurTexte = r:GetStringWidth(), appel(r, "GetStringHeight")
			t.texte = r:GetText()
			t.rouge, t.vert, t.bleu, t.opacite = r:GetTextColor()
			t.police, t.taille, t.contour = r:GetFont()
			t.justification = appel(r, "GetJustifyH")
			t.coupure = appel(r, "CanWordWrap")
			t.retrait = appel(r, "GetIndentedWordWrap")
			t.points = r:GetNumPoints()
			if t.points > 0 then
				local p, cible, pc, x, y = r:GetPoint(1)
				t.point = string.format("%s %s %s %.2f %.2f", tostring(p),
					cible and cible.GetName and (cible:GetName() or "?") or "nil", tostring(pc), x or 0, y or 0)
			end
			-- la mesure qu'on ferait : meme police, sur une ligne, puis a la
			-- largeur de la fenetre
			if t.texte and t.police then
				mesure:SetFont(t.police, t.taille, t.contour)
				mesure:SetWidth(0)
				mesure:SetText(t.texte)
				t.mesure = mesure:GetStringWidth()
				t.mesureHauteur = mesure:GetStringHeight()
				mesure:SetWidth(rel.largeur)
				t.mesureCoupee = mesure:GetStringHeight()
			end
			if t.visible then visibles = visibles + 1 end
			table.insert(rel.textes, t)
		end
	end
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.releveChat = rel
	DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffForeverUI|r " .. L.CHAT_LINES_RECORDED,
		rel.fenetre, #rel.textes, visibles, n))
end

local attente = CreateFrame("Frame")
attente:Hide()
attente:SetScript("OnUpdate", function(self)
	self.images = self.images + 1
	if self.images < 3 then return end
	self:Hide()
	C.releverLignes(self.fenetre)
end)
C.attenteReleve = attente

function ForeverUI.ChatReleveLignes()
	local fenetre = (GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.selected) or DEFAULT_CHAT_FRAME
	if not (fenetre and fenetre:IsShown()) then fenetre = DEFAULT_CHAT_FRAME end
	fenetre:AddMessage(essai(), 1, 1, 0)
	attente.fenetre, attente.images = fenetre, 0
	attente:Show()
end
