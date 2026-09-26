-- ForeverUI : le navigateur de raid de WotLK dans la fenetre du chercheur
-- (GroupFinder.lua), a la DA du chercheur de groupe de camelot -- etape 2,
-- 2026-09-26 ; memoire foreverui-chercheur.
--
-- UN ONGLET LATERAL, DEUX ONGLETS EN BAS (demande de l'utilisateur,
-- 2026-09-26, apres deux essais -- deux onglets lateraux, puis deux sections
-- retractables) : l'onglet lateral "Raid Browser"
-- (Achievement_General_StayClassy), et sous la fenetre les onglets "List My
-- Group" (LIST_MY_GROUP) et "Join" (JOIN), ceux de la fenetre Social (onglets
-- du bas de camelot, PanelTabButtonTemplate). Chacun montre son panneau :
-- "List My Group" la page d'inscription de camelot (LFGListingFrame), "Join"
-- sa page de parcours (LFGBrowseFrame). L'onglet choisi est celui du client
-- (LFRParentFrame.activeTab, LFRFrame_SetActiveTab) : le raid rouvre sur le
-- dernier panneau vu.
--
-- LES CATEGORIES RETRACTABLES DE LA LISTE DES RAIDS sont celles de la feuille
-- de personnage (TokensTab.lua, TokenHeaderTemplate) : en-tete de 26,
-- common-button-list-collapseExpand en neuf tranches (coin 12), nom
-- GameFontNormalLeft a LEFT (10) sur 15 de haut, fleche
-- common-button-list-minus / -plus a RIGHT (-8, -1) ; entrees de 22 en
-- retrait de 2 ; 3 entre deux lignes. Un clic sur l'en-tete replie ou deplie
-- (LFRList_SetHeaderCollapsed du client). L'en-tete n'a plus sa case "tout
-- cocher" de WotLK : la feuille n'en a pas ; chaque raid garde la sienne.
-- Le rectangle des entrees est celui de la feuille aussi (TokenEntryTemplate,
-- decision de l'utilisateur) : charactercreate-customize-dropdown-
-- linemouseover en trois tranches (cotes de 6, le droit retourne), 0,10 au
-- survol, 0,20 sur un raid coche ; le survol se lit sur toute la ligne, sa
-- case comprise (IsMouseOver a chaque image, comme la feuille).
--
-- RELEVE -- blizzard_groupfinder_vanillastyle/mainline :
--   inscription  bandeau des roles (tank, soin, degats a x 70 / 174 / 278,
--                pas de chef : WotLK n'en a pas ici), encadre (4,-118 /
--                -4,37) ; la liste (ActivityView 7,-125 / -7,40, marge 4)
--                s'arrete a 88 au-dessus du bas de la vue ; filet
--                shop-list-rule a 80 au-dessus de ce bas ; le commentaire
--                (UIPanelInputScrollFrameTemplate 394 x 47, BOTTOM (0, 19) de
--                la vue) :
--                bord Common-Input-Border en neuf morceaux (coins 8 x 8 a
--                +/-5), texte GameFontHighlightSmall sur 394 - 18, consigne
--                GameFontNormalSmall gris 0,35 ; boutons Back 111 x 28
--                BOTTOMLEFT (4,6) -> Set Comment, Post 109 x 28 BOTTOMRIGHT
--                (-4,6) -> List Me
--   parcours     encadre (4,-80 / -4,37), fond entier ; menu
--                WowStyle1DropdownTemplate a TOPLEFT (70,-43) ; bouton de
--                rafraichissement
--                32 x 32 (UI-SquareButton, surbrillance UI-Common-MouseHilight,
--                icone UI-RefreshButton 16 x 16 a (-1, 0), (-2, -1) enfonce) a
--                sa droite (+9) ; lignes de 48 (LFGBrowseSearchEntryTemplate) :
--                fond blanc 0,04, chef UI-Group-LeaderIcon 24 x 24 a (8,-4),
--                nom GameFontNormalLarge (9,-9) seul, (32,-9) en groupe,
--                couleur de classe, niveau "LEVEL_ABBR n" GameFontDisableLeft
--                a +4, icone de classe groupfinder-icon-class-* 24 x 24 a
--                +3,-5, ligne du bas GameFontDisableLeft a (10,5) ; selection
--                groupfinder-highlightbar-yellow, survol -blue (3,-3 / -3,-1,
--                ADD) ; a droite : seul, "Roles:" GameFontHighlight a RIGHT
--                -120 et les roles groupfinder-icon-role-micro-* 20 x 20 (+4
--                puis +24) ; en groupe, groupfinder-waitdot 18 x 17 a RIGHT -16
--                et le nombre a sa gauche ; liste (7,-83 / -22,40 avec la
--                barre, -6 sans ; barre a +2,-4) ; boutons SendMessage 111 x 28
--                BOTTOMLEFT (4,6), GroupInvite 109 x 28 BOTTOMRIGHT (-4,6)
--
-- CE QUI VIENT DE WotLK (LFRFrame.lua) : les donnees et les actions. Le
-- contenu du panneau (LFRQueueFrame, LFRBrowseFrame) reste affiche mais
-- transparent sous notre fenetre ; on recopie son etat et on agit par ses
-- fonctions (LFRQueueFrameDungeonChoiceEnableButton_OnClick,
-- LFRBrowseButton_OnClick / _OnEnter avec notre ligne, Click() sur ses
-- boutons, son menu des raids ouvert sous notre bouton).
--
-- CORRESPONDANCES : menu de camelot -> le menu des raids de WotLK ; ligne
-- du bas -> le commentaire du joueur, sinon sa zone.
--
-- UN RAID A LA FOIS, COMME WotLK. Parcourir toute une categorie a ete
-- essaye le 2026-09-26 puis retire (decision de l'utilisateur) : le serveur
-- ne cherche qu'un raid par joueur (AzerothCore, LFGMgr : RBSearchersStore),
-- et SearchLFGJoin est PROTEGEE -- elle ne passe que pendant un clic ou une
-- touche ; appelee d'une horloge pour enchainer les raids, le client la
-- bloquait ("Interface action failed because of an addon"). Le menu reste le
-- notre (bati sur GetFullRaidList, sa liste a la largeur de notre bouton),
-- ses categories de simples sous-menus. Chaque reponse est relevee en entier
-- (membres du groupe, boss) : l'infobulle, reprise de LFRBrowseButton_OnEnter,
-- s'appuie sur ce releve. La selection est la notre ; Send Message et Invite
-- font ce que font ceux du client (ChatFrame_SendTell, InviteUnit,
-- LFRBrowse_UpdateButtonStates).
--
-- ECARTS SIGNALES : pas de tri par colonnes (camelot n'a pas d'en-tetes) ;
-- pas de separation "joueurs seuls / groupes" (ses chaines n'existent pas en
-- 3.3.5) ; pas de texte "aucun resultat" (idem) ; le commentaire garde la
-- limite de WotLK (64 lettres) et ne defile pas.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local F = ForeverUI.GroupFinder
local R = {}
ForeverUI.GroupFinderRaid = R

if not (F and F.cadre and LFRParentFrame and LFRQueueFrame and LFRBrowseFrame) then return end

local SEP = string.char(92)
local G = F.G
local txt, actif = F.txt, F.actif

local M = {
	-- l'inscription
	regleY = 40 + 80, listeHaut = -125 - 4, listeBas = 40 + 88 + 4, listeX = 7 + 4,
	commentaireL = 394, commentaireH = 47, commentaireY = 40 + 19, lettres = 64,
	-- les categories de la liste des raids (TokensTab.lua)
	catEntete = 26, catEntree = 22, catEcart = 3, catRetrait = 2, catMarge = 4, catCoin = 12,
	catNomX = 10, catNomH = 15, catFlecheX = -8, catFlecheY = -1, catFlechePlace = 16,
	catCote = 6, catChoisie = 0.20, catSurvol = 0.10,
	-- le parcours
	parcoursY = -80, menuX = 70, menuY = -43, menuL = 300, menuH = 25,
	rafraichir = 32, rafraichirX = 9,
	resultat = 48, resultatsY = -83, resultatsX2 = -22, resultatsSans = -6,
	-- les onglets du bas (ceux de Social : premier a (5, 2) sous la fenetre,
	-- les suivants a +3)
	ongletX = 5, ongletY = 2, ongletEcart = 3,
	bord = "Interface" .. SEP .. "Common" .. SEP .. "Common-Input-Border-",
	carre = "interface" .. SEP .. "ForeverUI" .. SEP .. "buttons" .. SEP,
	chef = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-LeaderIcon",
	gris = { 0.3, 0.3, 0.3 },
}

-- ---------------------------------------------------------------- la source
-- la liste des raids (LFRFrame.lua) : en groupe, un seul raid, par un
-- bouton rond (LFRQueueFrame.selectedLFM) ; seul, des cases
local SOURCE_LFR = {
	-- la case de camelot (GroupFinder.lua, caseCamelot)
	style = "camelot",
	liste = function() return LFRRaidList or {} end,
	habilite = function() return LFR_IsEmpowered() end,
	plus = function(b) LFRQueueFrameExpandOrCollapseButton_OnClick(b) end,
	case = function(c) LFRQueueFrameDungeonChoiceEnableButton_OnClick(c) end,
	plusieurs = function() return LFR_CanQueueForMultiple() end,
	verrou = function(id) return not LFR_CanQueueForLockedInstances() and LFGLockList[id] end,
	etat = function(id, mode)
		if mode == "queued" or mode == "listed" then return LFGQueuedForList[id] end
		if not LFR_CanQueueForMultiple() then return id == LFRQueueFrame.selectedLFM end
		return LFGEnabledList[id]
	end,
}
R.SOURCE = SOURCE_LFR

local function texteDe(nom)
	local r = _G[nom]
	return r and r.GetText and r:GetText() or ""
end

-- un bouton de la fenetre qui reprend le texte et l'etat d'un bouton du
-- client, et le fait cliquer
local function refleter(b, nomClient, garderTexte)
	local c = _G[nomClient]
	if not c then return end
	if not garderTexte then b:SetText(c:GetText() or "") end
	b:Activer(actif(c))
end

-- ---------------------------------------------------------------- l'inscription

-- les roles de LFRQueueFrame, aux places de camelot
local function rolesRaid()
	local l = {}
	local clients = { tank = "LFRQueueFrameRoleButtonTank", soin = "LFRQueueFrameRoleButtonHealer",
		degats = "LFRQueueFrameRoleButtonDPS" }
	for _, r in ipairs(F.ROLES) do
		if clients[r.cle] then
			table.insert(l, { cle = r.cle, page = "Raid", client = clients[r.cle], id = r.id, x = r.x,
				alpha = r.alpha, icone = r.icone, fond = r.fond })
		end
	end
	return l
end

-- LE COMMENTAIRE : le cadre de camelot, un champ de WotLK. Le champ du client
-- (LFRQueueFrameComment) reste celui que LFRQueueFrame_Join lit : le notre
-- lui recopie son texte ; ses regles de focus et d'envoi sont reprises de son
-- XML (OnEditFocusGained / OnEditFocusLost).
local function construireCommentaire(p, niveau)
	local c = CreateFrame("Frame", "ForeverUIGroupFinderRaidComment", p)
	c:SetWidth(M.commentaireL)
	c:SetHeight(M.commentaireH)
	c:SetFrameLevel(niveau)
	c:EnableMouse(true)
	local function morceau(suffixe)
		local t = c:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(M.bord .. suffixe)
		return t
	end
	local hg, hd, bg, bd = morceau("TL"), morceau("TR"), morceau("BL"), morceau("BR")
	for _, t in ipairs({ hg, hd, bg, bd }) do t:SetWidth(8) t:SetHeight(8) end
	hg:SetPoint("TOPLEFT", c, "TOPLEFT", -5, 5)
	hd:SetPoint("TOPRIGHT", c, "TOPRIGHT", 5, 5)
	bg:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", -5, -5)
	bd:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 5, -5)
	local haut, bas, gauche, droite = morceau("T"), morceau("B"), morceau("L"), morceau("R")
	haut:SetPoint("TOPLEFT", hg, "TOPRIGHT", 0, 0)
	haut:SetPoint("BOTTOMRIGHT", hd, "BOTTOMLEFT", 0, 0)
	bas:SetPoint("TOPLEFT", bg, "TOPRIGHT", 0, 0)
	bas:SetPoint("BOTTOMRIGHT", bd, "BOTTOMLEFT", 0, 0)
	gauche:SetPoint("TOPLEFT", hg, "BOTTOMLEFT", 0, 0)
	gauche:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT", 0, 0)
	droite:SetPoint("TOPLEFT", hd, "BOTTOMLEFT", 0, 0)
	droite:SetPoint("BOTTOMRIGHT", bd, "TOPRIGHT", 0, 0)
	local milieu = morceau("M")
	milieu:SetPoint("TOPLEFT", gauche, "TOPRIGHT", 0, 0)
	milieu:SetPoint("BOTTOMRIGHT", droite, "BOTTOMLEFT", 0, 0)

	local e = CreateFrame("EditBox", "ForeverUIGroupFinderRaidCommentEditBox", c)
	e:SetMultiLine(true)
	e:SetAutoFocus(false)
	e:SetMaxLetters(M.lettres)
	e:SetWidth(M.commentaireL - 18)
	e:SetHeight(M.commentaireH)
	e:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	e:SetFontObject(GameFontHighlightSmall)
	local consigne = e:CreateFontString(nil, "BORDER", "GameFontNormalSmall")
	consigne:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
	consigne:SetWidth(M.commentaireL)
	consigne:SetJustifyH("LEFT")
	consigne:SetJustifyV("TOP")
	consigne:SetTextColor(0.35, 0.35, 0.35)
	consigne:SetText(txt("TYPE_LFR_COMMENT_HERE"))
	e.consigne = consigne
	e:SetScript("OnEditFocusGained", function(self)
		if LFR_IsEmpowered() and LFRRaidList and LFRRaidList[1] then
			self.consigne:Hide()
		else
			self:ClearFocus()
		end
	end)
	e:SetScript("OnEditFocusLost", function(self)
		local t = self:GetText() or ""
		if strtrim(t) == "" then self.consigne:Show() end
		LFRQueueFrameComment:SetText(t)
		SetLFGComment(t)
	end)
	e:SetScript("OnTextChanged", function(self)
		LFRQueueFrameComment:SetText(self:GetText() or "")
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	c:SetScript("OnMouseDown", function() e:SetFocus() end)
	R.saisie = e
	R.commentaire = c
end

-- LA LISTE DES RAIDS, A CATEGORIES : les en-tetes de la feuille de
-- personnage, les entrees communes avec les donjons (F.creerLigne, source
-- SOURCE_LFR). Des lignes de deux hauteurs : on les empile a la main, et le
-- decalage compte des lignes, pas des pixels.
local function creerEnteteCat(zone, n)
	local b = CreateFrame("Button", "ForeverUIGroupFinderRaidHeader" .. n, zone)
	b:SetHeight(M.catEntete)
	ForeverUI.CreateNineSlice(b, "common-button-list-collapseexpand", M.catCoin, { 0, 0, 0, 0 }, "BACKGROUND")
	-- le survol : la meme plaque, en ADD a 0,3
	for _, t in ipairs(ForeverUI.CreateNineSlice(b, "common-button-list-collapseexpand", M.catCoin,
		{ 0, 0, 0, 0 }, "HIGHLIGHT") or {}) do
		t:SetBlendMode("ADD")
		t:SetAlpha(0.3)
	end
	local nom = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
	nom:SetHeight(M.catNomH)
	nom:SetJustifyH("LEFT")
	nom:SetPoint("LEFT", b, "LEFT", M.catNomX, 0)
	nom:SetPoint("RIGHT", b, "RIGHT", -M.catFlechePlace, 0)
	b.nom = nom
	local fleche = b:CreateTexture(nil, "OVERLAY")
	fleche:SetPoint("RIGHT", b, "RIGHT", M.catFlecheX, M.catFlecheY)
	b.fleche = fleche
	b:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		LFRList_SetHeaderCollapsed(self.id, not LFGCollapseList[self.id])
		F.demander()
	end)
	return b
end

local SURVOL_COTE = "charactercreate-customize-dropdown-linemouseover-side"
local SURVOL_MILIEU = "charactercreate-customize-dropdown-linemouseover-middle"

local function creerEntreeCat(zone, n)
	local l = CreateFrame("Button", "ForeverUIGroupFinderRaidRow" .. n, zone)
	l:SetHeight(M.catEntree)
	-- le rectangle de la feuille, sous la ligne
	local survol = CreateFrame("Frame", nil, l)
	survol:SetAllPoints(l)
	survol:SetAlpha(0)
	local g = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(g, SURVOL_COTE, true)
	g:SetWidth(M.catCote)
	g:SetPoint("TOPLEFT", survol, "TOPLEFT", 0, 0)
	g:SetPoint("BOTTOMLEFT", survol, "BOTTOMLEFT", 0, 0)
	local d = survol:CreateTexture(nil, "BACKGROUND")
	if ForeverUI.SetAtlas(d, SURVOL_COTE, true) then
		local e = ForeverUI.AtlasEntry(SURVOL_COTE)
		d:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	d:SetWidth(M.catCote)
	d:SetPoint("TOPRIGHT", survol, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", survol, "BOTTOMRIGHT", 0, 0)
	local m = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(m, SURVOL_MILIEU, true)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	l.survol = survol
	F.creerLigne(l)
	return l
end

-- l'opacite du rectangle : cochee 0,20 ; au survol 0,10 ; au repos 0
local function poserSurvol(l)
	local coche = l.case:IsShown() and l.case:GetChecked()
	l.survol:SetAlpha((coche and M.catChoisie) or (l:IsMouseOver() and M.catSurvol) or 0)
end

-- combien de lignes tiennent depuis la i-eme
local function tiennent(l, depuis, haut)
	local y, n = M.catMarge, 0
	for i = depuis, #l do
		local h = (l[i] < 0) and M.catEntete or M.catEntree
		if y + h > haut then break end
		y = y + h + M.catEcart
		n = n + 1
	end
	return n
end

local function poserZone(zone)
	local f = F.cadre
	zone:ClearAllPoints()
	zone:SetPoint("TOPLEFT", f, "TOPLEFT", M.listeX, M.listeHaut)
	zone:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", zone.avecBarre and (G.listeX2 + G.barreDroite - G.marge)
		or (G.listeX2 - G.marge), M.listeBas)
end

function R.majCategories()
	local zone = R.liste
	local l = LFRRaidList or {}
	local total = #l
	local haut = G.hauteur + M.listeHaut - M.listeBas
	-- le plus grand decalage : celui d'ou la fin de la liste tient
	local maxi = 0
	for d = 0, total do
		if tiennent(l, d + 1, haut) >= total - d then
			maxi = d
			break
		end
	end
	zone.maxi = maxi
	zone.decalage = math.max(0, math.min(zone.decalage or 0, maxi))
	local avecBarre = maxi > 0
	if avecBarre ~= zone.avecBarre then
		zone.avecBarre = avecBarre
		poserZone(zone)
	end
	local y = M.catMarge
	local ne, nn = 0, 0
	for i = zone.decalage + 1, total do
		local id = l[i]
		local h = (id < 0) and M.catEntete or M.catEntree
		if y + h > haut then break end
		local ligne
		if id < 0 then
			ne = ne + 1
			ligne = zone.entetes[ne] or creerEnteteCat(zone, ne)
			zone.entetes[ne] = ligne
			ligne.id = id
			local info = LFGDungeonInfo and LFGDungeonInfo[id] or {}
			ligne.nom:SetText(info[1] or "")
			ForeverUI.SetAtlas(ligne.fleche, LFGCollapseList[id] and "common-button-list-plus"
				or "common-button-list-minus", false)
			ligne:ClearAllPoints()
			ligne:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -y)
			ligne:SetPoint("TOPRIGHT", zone, "TOPRIGHT", 0, -y)
		else
			nn = nn + 1
			ligne = zone.entrees[nn] or creerEntreeCat(zone, nn)
			zone.entrees[nn] = ligne
			F.remplirLigne(ligne, i)
			poserSurvol(ligne)
			ligne:ClearAllPoints()
			ligne:SetPoint("TOPLEFT", zone, "TOPLEFT", M.catRetrait, -y)
			ligne:SetPoint("TOPRIGHT", zone, "TOPRIGHT", 0, -y)
		end
		ligne:Show()
		y = y + h + M.catEcart
	end
	for i = ne + 1, #zone.entetes do zone.entetes[i]:Hide() end
	for i = nn + 1, #zone.entrees do zone.entrees[i]:Hide() end
	zone.barre:Regler(maxi + 1, 1, zone.decalage)
end

-- LE PANNEAU "LIST MY GROUP" : la page d'inscription de camelot
local function construireInscription(p)
	local f = F.cadre
	R.bleu, R.roles = F.construireBandeau(p, rolesRaid())
	local encadre = F.construireEncadre(p, "ForeverUIGroupFinderRaidInset", G.encadreY1, true)
	R.encadre = encadre

	local zone = CreateFrame("Frame", "ForeverUIGroupFinderRaidList", p)
	zone.src = SOURCE_LFR
	zone.entetes, zone.entrees = {}, {}
	zone.decalage = 0
	zone:SetFrameLevel(encadre:GetFrameLevel() + 1)
	zone.avecBarre = false
	poserZone(zone)
	local barre = ForeverUI.CreateScrollBar("ForeverUIGroupFinderRaidListScrollBar", p, zone)
	barre:SetFrameLevel(encadre:GetFrameLevel() + 2)
	barre:ClearAllPoints()
	barre:SetPoint("TOPLEFT", zone, "TOPRIGHT", 13 + G.marge, 0)
	barre:SetPoint("BOTTOMLEFT", zone, "BOTTOMRIGHT", 13 + G.marge, -2)
	barre.surDefilement = function(nouveau)
		zone.decalage = nouveau
		R.majCategories()
	end
	zone.barre = barre
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(self, sens)
		self.decalage = math.max(0, math.min((self.decalage or 0) - sens, self.maxi or 0))
		R.majCategories()
	end)
	-- le survol suivi a chaque image, comme la feuille (suivreSurvol)
	zone:SetScript("OnUpdate", function(self)
		for _, l in ipairs(self.entrees) do
			if l:IsShown() then poserSurvol(l) end
		end
	end)
	R.liste = zone
	-- "aucun raid" : LFRQueueFrameSpecificNoRaidsAvailable
	local aucun = zone:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	aucun:SetWidth(300)
	aucun:SetPoint("TOP", zone, "TOP", 0, -40)
	aucun:SetText(txt("NO_RAIDS_AVAILABLE"))
	aucun:Hide()
	R.aucun = aucun

	-- le filet et le commentaire, au-dessus de l'encadre
	local dessus = CreateFrame("Frame", nil, p)
	dessus:SetAllPoints(f)
	dessus:SetFrameLevel(encadre:GetFrameLevel() + 1)
	local regle = dessus:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(regle, "shop-list-rule", true)
	regle:SetHeight(G.regleH)
	regle:SetPoint("LEFT", f, "BOTTOMLEFT", G.listeX1, M.regleY)
	regle:SetPoint("RIGHT", f, "BOTTOMRIGHT", G.listeX2, M.regleY)
	R.regle = regle
	construireCommentaire(p, encadre:GetFrameLevel() + 2)
	R.commentaire:SetPoint("BOTTOM", f, "BOTTOM", 0, M.commentaireY)

	-- "pas de raid pendant la file des donjons" : le voile de WotLK
	local voile = F.creerVoile("ForeverUIGroupFinderNoLFRWhileLFD", 16, p, encadre)
	voile:SetAllPoints(encadre)
	voile.quitter = ForeverUI.CreatePanelButton(voile, txt("LEAVE_QUEUE"), 153, 22, nil, "GameFontNormal")
	voile.quitter:SetPoint("TOP", voile.description, "BOTTOM", 0, -10)
	voile.quitter:SetScript("OnClick", function()
		if LFRQueueFrameNoLFRWhileLFDLeaveQueueButton then LFRQueueFrameNoLFRWhileLFDLeaveQueueButton:Click() end
	end)
	R.voile = voile

	-- les boutons : "Set Comment" et "List Me", ceux du client
	local commenter = ForeverUI.CreatePanelButton(p, txt("ACCEPT_COMMENT"), G.backL, G.boutonH,
		"ForeverUIGroupFinderRaidCommentButton", "GameFontNormal")
	commenter:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.boutonCote, G.boutonBas)
	-- l'OnClick de LFRQueueFrameAcceptCommentButton : lacher le champ envoie
	-- le commentaire ; sans focus, un son
	commenter:SetScript("OnClick", function()
		if R.saisie:HasFocus() then
			R.saisie:ClearFocus()
		else
			PlaySound("igMainMenuOptionCheckBoxOn")
		end
	end)
	R.commenter = commenter
	local inscrire = ForeverUI.CreatePanelButton(p, txt("LIST_ME"), G.postL, G.boutonH,
		"ForeverUIGroupFinderRaidListButton", "GameFontNormal")
	inscrire:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -G.boutonCote, G.boutonBas)
	inscrire:SetScript("OnClick", function()
		if R.saisie:HasFocus() then R.saisie:ClearFocus() end
		if LFRQueueFrameFindGroupButton and actif(LFRQueueFrameFindGroupButton) then
			LFRQueueFrameFindGroupButton:Click()
		end
	end)
	R.inscrire = inscrire
end

local function majInscription()
	R.majCategories()
	if LFRQueueFrameSpecificNoRaidsAvailable and LFRQueueFrameSpecificNoRaidsAvailable:IsShown() then
		R.aucun:Show()
	else
		R.aucun:Hide()
	end
	-- le commentaire du client, tant qu'on n'ecrit pas
	if not R.saisie:HasFocus() then
		R.saisie:SetText(LFRQueueFrameComment:GetText() or "")
		if LFRQueueFrameCommentExplanation and not LFRQueueFrameCommentExplanation:IsShown()
			and strtrim(R.saisie:GetText() or "") ~= "" then
			R.saisie.consigne:Hide()
		else
			R.saisie.consigne:Show()
		end
	end
	local v = LFRQueueFrameNoLFRWhileLFD
	if v and v:IsShown() then
		R.voile.description:SetText(texteDe("LFRQueueFrameNoLFRWhileLFDDescription"))
		refleter(R.voile.quitter, "LFRQueueFrameNoLFRWhileLFDLeaveQueueButton", true)
		R.voile:Show()
	else
		R.voile:Hide()
	end
	refleter(R.commenter, "LFRQueueFrameAcceptCommentButton")
	refleter(R.inscrire, "LFRQueueFrameFindGroupButton")
end

-- ---------------------------------------------------------------- le parcours

-- WowStyle1DropdownTemplate, comme les etages de la carte : fond
-- common-dropdown-textholder-c60 en trois (16 / 19), fleche a RIGHT (1,-3),
-- texte GameFontHighlight de (8,-8) a la fleche
local function construireMenu(p)
	local b = CreateFrame("Button", "ForeverUIGroupFinderRaidDropDown", p)
	b:SetWidth(M.menuL)
	b:SetHeight(M.menuH)
	b:SetPoint("TOPLEFT", p, "TOPLEFT", M.menuX, M.menuY)
	local e = ForeverUI.AtlasEntry("common-dropdown-textholder-c60")
	local fond = CreateFrame("Frame", nil, b)
	fond:SetPoint("TOPLEFT", b, "TOPLEFT", -8, 7)
	fond:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 8, -9)
	if e then
		local du = (e[3] - e[2]) / e[6]
		local u1, u2 = e[2] + 16 * du, e[3] - 19 * du
		local function morceau(a, z)
			local t = b:CreateTexture(nil, "BACKGROUND")
			t:SetTexture(e[1])
			t:SetTexCoord(a, z, e[4], e[5])
			return t
		end
		local g = morceau(e[2], u1)
		g:SetWidth(16)
		g:SetPoint("TOPLEFT", fond, "TOPLEFT", 0, 0)
		g:SetPoint("BOTTOMLEFT", fond, "BOTTOMLEFT", 0, 0)
		local d = morceau(u2, e[3])
		d:SetWidth(19)
		d:SetPoint("TOPRIGHT", fond, "TOPRIGHT", 0, 0)
		d:SetPoint("BOTTOMRIGHT", fond, "BOTTOMRIGHT", 0, 0)
		local m = morceau(u1, u2)
		m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
		m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	end
	local fleche = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(fleche, "common-dropdown-a-button")
	fleche:SetPoint("RIGHT", b, "RIGHT", 1, -3)
	local texte = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	texte:SetJustifyH("LEFT")
	texte:SetHeight(10)
	texte:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -8)
	texte:SetPoint("TOPRIGHT", fleche, "LEFT", 0, 0)
	b.texte = texte
	b.fleche = fleche
	b:SetScript("OnMouseDown", function(self) ForeverUI.SetAtlas(self.fleche, "common-dropdown-a-button-pressed", true) end)
	b:SetScript("OnMouseUp", function(self) ForeverUI.SetAtlas(self.fleche, "common-dropdown-a-button", true) end)
	-- NOTRE MENU, sous notre bouton : celui du client
	-- (LFRBrowseFrameRaidDropDown_Initialize). Un menu sans bouton du client : displayMode "MENU", la
	-- largeur de son contenu, au moins celle de notre bouton (DropDown.lua,
	-- foreverMinimum)
	local menu = CreateFrame("Frame", "ForeverUIGroupFinderRaidMenu", p)
	menu.displayMode = "MENU"
	menu.foreverMinimum = M.menuL
	menu.initialize = function(self, niveau) R.initialiserMenu(niveau) end
	R.menuListe = menu
	b:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		ToggleDropDownMenu(1, nil, menu, self, 0, 0)
	end)
	R.menu = b
end

-- ---------------------------------------------------------------- la recherche
-- R.recherche = { nom, ids = { raid } } ; R.cache[raid] = les inscrits
-- releves pour ce raid.
R.cache = {}

local function typeDe(id)
	local info = LFGGetDungeonInfoByID and LFGGetDungeonInfoByID(id)
	return info and info[2] or 0
end

local function nomDe(id)
	local info = LFGGetDungeonInfoByID and LFGGetDungeonInfoByID(id)
	if not info then return "" end
	return format(txt("LFD_LEVEL_FORMAT_SINGLE"), info[12] or 0) .. " " .. (info[1] or "")
end

-- relever la reponse du serveur pour le raid cherche : tout ce que
-- l'infobulle du client lit (SearchLFGGetResults, GetPartyResults,
-- GetEncounterResults)
function R.relever(raid)
	local l = {}
	local nombre = SearchLFGGetNumResults() or 0
	for i = 1, nombre do
		local d = { SearchLFGGetResults(i) }
		local e = { raid = raid, nom = d[1], niveau = d[2], zone = d[3], nomClasse = d[4], commentaire = d[5],
			membres = d[6] or 0, classe = d[8], bossTotal = d[9] or 0, bossTues = d[10] or 0, chef = d[11],
			tank = d[12], soin = d[13], degats = d[14], groupe = {}, boss = {} }
		for j = 1, e.membres do
			local nm, nv, lien = SearchLFGGetPartyResults(i, j)
			e.groupe[j] = { nom = nm, lien = lien }
		end
		if e.bossTues > 0 then
			for j = 1, e.bossTotal do
				local bn, _, tue = SearchLFGGetEncounterResults(i, j)
				e.boss[j] = { nom = bn, tue = tue }
			end
		end
		l[i] = e
	end
	R.cache[raid] = l
end

-- LFRBrowseFrameRaidDropDownButton_OnClick : aucun raid, ou un raid. Appele
-- du clic sur la ligne du menu -- SearchLFGJoin en a besoin.
function R.choisir(valeur)
	CloseDropDownMenus()
	R.choix = nil
	if valeur == nil then
		R.recherche = nil
		SearchLFGLeave()
	else
		R.recherche = { nom = nomDe(valeur), ids = { valeur }, depuis = GetTime() }
		SearchLFGJoin(typeDe(valeur), valeur)
	end
	F.demander()
end

-- LFRBrowseFrameRaidDropDown_Initialize ; le premier niveau sans cases
-- (demande de l'utilisateur, 2026-09-26 : ses categories ne se choisissent
-- pas)
function R.initialiserMenu(niveau)
	local ordre, liste = GetFullRaidList()
	local r = R.recherche
	local info = UIDropDownMenu_CreateInfo()
	if not niveau or niveau == 1 then
		info.text = txt("NONE")
		info.func = function() R.choisir(nil) end
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, 1)
		for _, groupe in ipairs(ordre) do
			info = UIDropDownMenu_CreateInfo()
			info.text = LFGGetDungeonInfoByID(groupe)[1]
			info.value = groupe
			info.hasArrow = true
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, 1)
		end
	elseif niveau == 2 then
		for _, id in ipairs(liste[UIDROPDOWNMENU_MENU_VALUE] or {}) do
			info = UIDropDownMenu_CreateInfo()
			info.text = nomDe(id)
			info.value = id
			info.func = function() R.choisir(id) end
			info.checked = r ~= nil and r.ids[1] == id
			UIDropDownMenu_AddButton(info, 2)
		end
	end
end

-- ce que la liste montre : les inscrits des raids cherches, dans l'ordre
function R.inscrits()
	local r = R.recherche
	local l = {}
	if not r then return l end
	for _, id in ipairs(r.ids) do
		for _, e in ipairs(R.cache[id] or {}) do table.insert(l, e) end
	end
	return l
end

local function construireRafraichir(p)
	local b = CreateFrame("Button", "ForeverUIGroupFinderRaidRefresh", p)
	b:SetWidth(M.rafraichir)
	b:SetHeight(M.rafraichir)
	b:SetPoint("LEFT", R.menu, "RIGHT", M.rafraichirX, 0)
	b:SetNormalTexture(M.carre .. "ui-squarebutton-up")
	b:SetPushedTexture(M.carre .. "ui-squarebutton-down")
	b:SetHighlightTexture(M.carre .. "ui-common-mousehilight")
	local s = b:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	local icone = b:CreateTexture(nil, "ARTWORK")
	icone:SetTexture(M.carre .. "ui-refreshbutton")
	icone:SetWidth(16)
	icone:SetHeight(16)
	icone:SetPoint("CENTER", b, "CENTER", -1, 0)
	b.icone = icone
	b:SetScript("OnMouseDown", function(self)
		self.icone:ClearAllPoints()
		self.icone:SetPoint("CENTER", self, "CENTER", -2, -1)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.icone:ClearAllPoints()
		self.icone:SetPoint("CENTER", self, "CENTER", -1, 0)
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(txt("REFRESH"))
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- le bouton du client : RefreshLFGList
	b:SetScript("OnClick", function()
		if LFRBrowseFrameRefreshButton then LFRBrowseFrameRefreshButton:Click() end
	end)
	R.rafraichir = b
end

-- LFGBrowseSearchEntryTemplate
local function creerResultat(l)
	local fond = l:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture(1, 1, 1, 0.04)
	fond:SetPoint("TOPLEFT", l, "TOPLEFT", 3, -2)
	fond:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", -3, 0)
	local chef = l:CreateTexture(nil, "ARTWORK")
	chef:SetTexture(M.chef)
	chef:SetWidth(24)
	chef:SetHeight(24)
	chef:SetPoint("TOPLEFT", l, "TOPLEFT", 8, -4)
	l.chef = chef
	local nom = l:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	nom:SetHeight(14)
	nom:SetJustifyH("LEFT")
	l.nom = nom
	local niveau = l:CreateFontString(nil, "ARTWORK", "GameFontDisableLeft")
	niveau:SetHeight(14)
	niveau:SetPoint("BOTTOMLEFT", nom, "BOTTOMRIGHT", 4, 0)
	l.niveau = niveau
	local classe = l:CreateTexture(nil, "ARTWORK")
	classe:SetWidth(24)
	classe:SetHeight(24)
	classe:SetPoint("BOTTOMLEFT", niveau, "BOTTOMRIGHT", 3, -5)
	l.classe = classe
	local bas = l:CreateFontString(nil, "ARTWORK", "GameFontDisableLeft")
	bas:SetHeight(15)
	bas:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT", 10, 5)
	bas:SetPoint("RIGHT", l, "RIGHT", -120, 0)
	bas:SetJustifyH("LEFT")
	l.bas = bas
	local function barre(atlas)
		local t = l:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetBlendMode("ADD")
		t:SetPoint("TOPLEFT", l, "TOPLEFT", 3, -3)
		t:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", -3, -1)
		t:Hide()
		return t
	end
	l.choisi = barre("groupfinder-highlightbar-yellow")
	l.survol = barre("groupfinder-highlightbar-blue")

	-- a droite : les roles d'un joueur seul, le nombre d'un groupe
	local roles = l:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	roles:SetHeight(20)
	roles:SetPoint("RIGHT", l, "RIGHT", -2 - 120, -1)
	roles:SetText(txt("LFG_TOOLTIP_ROLES"))
	l.roles = roles
	l.iconesRole = {}
	for i = 1, 3 do
		local t = l:CreateTexture(nil, "ARTWORK")
		t:SetWidth(20)
		t:SetHeight(20)
		t:SetPoint("LEFT", roles, "RIGHT", 4 + (i - 1) * 24, 0)
		l.iconesRole[i] = t
	end
	local attente = l:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(attente, "groupfinder-waitdot", true)
	attente:SetWidth(18)
	attente:SetHeight(17)
	attente:SetPoint("RIGHT", l, "RIGHT", -2 - 16, -1)
	l.attente = attente
	local nombre = l:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	nombre:SetWidth(22)
	nombre:SetHeight(18)
	nombre:SetJustifyH("RIGHT")
	nombre:SetPoint("RIGHT", attente, "LEFT", -1, 0)
	l.nombre = nombre

	-- le survol et l'infobulle (R.infobulle, reprise du client) ; le clic
	-- (LFRBrowseButton_OnClick : choisir, ou lacher ce qu'on avait choisi)
	l:SetScript("OnEnter", function(self)
		if not self.choisi:IsShown() then self.survol:Show() end
		if self.donnee then R.infobulle(self, self.donnee) end
	end)
	l:SetScript("OnLeave", function(self)
		self.survol:Hide()
		GameTooltip:Hide()
	end)
	l:SetScript("OnClick", function(self)
		local e = self.donnee
		if self.moi or not e then return end
		if R.choix and R.choix.nom == e.nom then
			PlaySound("igMainMenuOptionCheckBoxOff")
			R.choix = nil
		else
			PlaySound("igMainMenuOptionCheckBoxOn")
			R.choix = { nom = e.nom, groupe = e.membres > 0 }
		end
		F.demander()
	end)
end

-- LFRBrowseButton_OnEnter, sur les donnees relevees
function R.infobulle(l, e)
	local rouge = RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }
	local vert = GREEN_FONT_COLOR or { r = 0.1, g = 1, b = 0.1 }
	local blanc = HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
	local role = "Interface" .. SEP .. "LFGFrame" .. SEP .. "LFGRole"
	GameTooltip:SetOwner(l, "ANCHOR_RIGHT", 27, -37)
	if e.membres > 0 then
		GameTooltip:AddLine(txt("LOOKING_FOR_RAID"))
		GameTooltip:AddLine(e.nom)
		GameTooltip:AddTexture(role, 0, 0.25, 0, 1)
		GameTooltip:AddLine(format(txt("LFM_NUM_RAID_MEMBER_TEMPLATE"), e.membres))
		GameTooltip:AddTexture("")
		local titre = false
		for _, m in ipairs(e.groupe) do
			if m.lien then
				if not titre then
					titre = true
					GameTooltip:AddLine("\n" .. txt("IMPORTANT_PEOPLE_IN_GROUP"))
				end
				if m.lien == "ignored" then
					GameTooltip:AddDoubleLine(m.nom, txt("IGNORED"), rouge.r, rouge.g, rouge.b, rouge.r, rouge.g, rouge.b)
				elseif m.lien == "friend" then
					GameTooltip:AddDoubleLine(m.nom, txt("FRIEND"), vert.r, vert.g, vert.b, vert.r, vert.g, vert.b)
				end
			end
		end
	else
		GameTooltip:AddLine(e.nom)
		GameTooltip:AddLine(format(txt("FRIENDS_LEVEL_TEMPLATE"), e.niveau or 0, e.nomClasse or ""))
	end
	if e.commentaire and e.commentaire ~= "" then
		GameTooltip:AddLine("\n" .. e.commentaire, blanc.r, blanc.g, blanc.b, 1)
	end
	if e.membres == 0 then
		GameTooltip:AddLine("\n" .. txt("LFG_TOOLTIP_ROLES"))
		if e.tank then GameTooltip:AddLine(txt("TANK")) GameTooltip:AddTexture(role, 0.5, 0.75, 0, 1) end
		if e.soin then GameTooltip:AddLine(txt("HEALER")) GameTooltip:AddTexture(role, 0.75, 1, 0, 1) end
		if e.degats then GameTooltip:AddLine(txt("DAMAGER")) GameTooltip:AddTexture(role, 0.25, 0.5, 0, 1) end
	end
	if e.bossTues > 0 then
		GameTooltip:AddLine("\n" .. txt("BOSSES"))
		for _, b in ipairs(e.boss) do
			if b.tue then
				GameTooltip:AddDoubleLine(b.nom, txt("BOSS_DEAD"), rouge.r, rouge.g, rouge.b, rouge.r, rouge.g, rouge.b)
			else
				GameTooltip:AddDoubleLine(b.nom, txt("BOSS_ALIVE"), vert.r, vert.g, vert.b, vert.r, vert.g, vert.b)
			end
		end
	elseif e.membres > 0 and e.bossTotal > 0 then
		GameTooltip:AddLine("\n" .. txt("ALL_BOSSES_ALIVE"))
	end
	GameTooltip:Show()
end

local ROLES_MICRO = { "groupfinder-icon-role-micro-tank", "groupfinder-icon-role-micro-heal",
	"groupfinder-icon-role-micro-dps" }

local function couleurs(fs, c)
	fs:SetTextColor(c[1] or c.r, c[2] or c.g, c[3] or c.b)
end

local function remplirResultat(l, index)
	local e = R.liste_inscrits[index]
	l.donnee = e
	local name, level, class = e.nom, e.niveau, e.classe
	l.moi = name == UnitName("player")
	local groupe = e.membres > 0
	-- le nom, pose sur la ligne (et non sur l'icone du chef : voir
	-- foreverui-reprendre-un-ecran, point 9) ; 228 au plus (NameMaxWidth)
	l.nom:ClearAllPoints()
	if groupe then
		l.chef:Show()
		l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", 8 + 24, -4 - 5)
		l.niveau:Hide()
		l.classe:Hide()
	else
		l.chef:Hide()
		l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", 8 + 1, -4 - 5)
		l.niveau:SetText(txt("LEVEL_ABBR") .. " " .. (level or ""))
		l.niveau:Show()
		local a = class and ForeverUI.AtlasEntry("groupfinder-icon-class-" .. string.lower(class))
		if a then
			ForeverUI.SetAtlas(l.classe, "groupfinder-icon-class-" .. string.lower(class), true)
			l.classe:Show()
		else
			l.classe:Hide()
		end
	end
	l.nom:SetWidth(0)
	l.nom:SetText(name or "")
	if (l.nom:GetStringWidth() or 0) > 228 then l.nom:SetWidth(228) end
	-- la ligne du bas : le commentaire, sinon la zone
	l.bas:SetText((e.commentaire and e.commentaire ~= "") and e.commentaire or (e.zone or ""))
	-- a droite
	if groupe then
		l.roles:Hide()
		for _, t in ipairs(l.iconesRole) do t:Hide() end
		l.attente:Show()
		l.nombre:SetText(e.membres)
		l.nombre:Show()
	else
		l.attente:Hide()
		l.nombre:Hide()
		l.roles:Show()
		local n = 0
		for i, oui in ipairs({ e.tank and true or false, e.soin and true or false, e.degats and true or false }) do
			if oui then
				n = n + 1
				ForeverUI.SetAtlas(l.iconesRole[n], ROLES_MICRO[i], true)
				l.iconesRole[n]:Show()
			end
		end
		for i = n + 1, 3 do l.iconesRole[i]:Hide() end
	end
	-- les couleurs : de classe ; le joueur lui-meme, gris et inactif
	local cc = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
	if l.moi then
		couleurs(l.nom, M.gris)
		couleurs(l.niveau, M.gris)
		couleurs(l.bas, M.gris)
		l.classe:SetDesaturated(true)
	else
		couleurs(l.nom, cc)
		local g = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
		couleurs(l.niveau, g)
		couleurs(l.bas, g)
		l.classe:SetDesaturated(false)
	end
	if R.choix and R.choix.nom == name then
		l.choisi:Show()
		l.survol:Hide()
	else
		l.choisi:Hide()
	end
end

local function construireParcours(p)
	local f = F.cadre
	local encadre = F.construireEncadre(p, "ForeverUIGroupFinderBrowseInset", M.parcoursY, false)
	R.encadreParcours = encadre
	construireMenu(p)
	construireRafraichir(p)
	local S = ForeverUI.Social
	local liste = S.creerListe(p, "ForeverUIGroupFinderBrowseList", M.resultat, creerResultat, remplirResultat)
	liste:SetFrameLevel(encadre:GetFrameLevel() + 1)
	liste.barre:SetFrameLevel(encadre:GetFrameLevel() + 2)
	liste:SuivreBarre({ "TOPLEFT", f, "TOPLEFT", G.listeX1, M.resultatsY },
		{ "BOTTOMRIGHT", f, "BOTTOMRIGHT", M.resultatsX2, G.listeY2 }, M.resultatsSans)
	liste.barre:ClearAllPoints()
	liste.barre:SetPoint("TOPLEFT", liste, "TOPRIGHT", 2, -4)
	liste.barre:SetPoint("BOTTOMLEFT", liste, "BOTTOMRIGHT", 2, 2)
	R.resultats = liste

	local message = ForeverUI.CreatePanelButton(p, txt("SEND_MESSAGE"), G.backL, G.boutonH,
		"ForeverUIGroupFinderRaidMessageButton", "GameFontNormal")
	message:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.boutonCote, G.boutonBas)
	-- LFRBrowseFrameSendMessageButton : ChatFrame_SendTell
	message:SetScript("OnClick", function()
		if R.choix then ChatFrame_SendTell(R.choix.nom) end
	end)
	R.message = message
	local inviter = ForeverUI.CreatePanelButton(p, txt("INVITE"), G.postL, G.boutonH,
		"ForeverUIGroupFinderRaidInviteButton", "GameFontNormal")
	inviter:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -G.boutonCote, G.boutonBas)
	-- LFRBrowseFrameInviteButton : InviteUnit
	inviter:SetScript("OnClick", function()
		if R.choix then InviteUnit(R.choix.nom) end
	end)
	R.inviter = inviter
end

local function majParcours()
	-- une recherche faite ailleurs (avant nous, ou quittee au bout de 40 s par
	-- le client) : la notre suit celle du serveur
	local cherche = SearchLFGGetJoinedID and SearchLFGGetJoinedID()
	-- une recherche qu'on vient de lancer attend la reponse du serveur
	local recente = R.recherche and R.recherche.depuis and GetTime() - R.recherche.depuis < 5
	if not cherche and not recente then
		R.recherche = nil
	elseif cherche and not R.recherche then
		R.recherche = { nom = nomDe(cherche), ids = { cherche } }
	end
	R.menu.texte:SetText(R.recherche and R.recherche.nom or txt("NONE"))
	R.liste_inscrits = R.inscrits()
	-- un choix qui n'est plus dans la liste s'en va, comme chez le client
	if R.choix then
		local la = false
		for _, e in ipairs(R.liste_inscrits) do
			if e.nom == R.choix.nom then la = true break end
		end
		if not la then R.choix = nil end
	end
	R.resultats:Maj(#R.liste_inscrits)
	-- LFRBrowse_UpdateButtonStates
	local c = R.choix
	R.message:Activer(c ~= nil and c.nom ~= UnitName("player"))
	R.inviter:Activer(c ~= nil and c.nom ~= UnitName("player") and not c.groupe and CanGroupInvite() and true or false)
end

-- ---------------------------------------------------------------- le panneau

-- Le panneau du client se tait comme celui des donjons : son icone, ses
-- onglets, sa croix ; ses deux contenus restent affiches, transparents, sous
-- notre fenetre.
local function etoufferClient()
	local p = LFRParentFrame
	for _, r in ipairs({ p:GetRegions() }) do r:Hide() end
	for _, c in ipairs({ p:GetChildren() }) do
		if c ~= F.cadre and c ~= LFRQueueFrame and c ~= LFRBrowseFrame then c:Hide() end
	end
	p:EnableMouse(false)
	for _, c in ipairs({ LFRQueueFrame, LFRBrowseFrame }) do
		c:SetAlpha(0)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", F.cadre, "TOPLEFT", 0, 0)
		c:SetWidth(p:GetWidth())
		c:SetHeight(p:GetHeight())
	end
end

-- ---------------------------------------------------------------- la page

-- LES ONGLETS DU BAS : ceux de la fenetre Social ; chacun, un panneau et
-- l'onglet du client (1 : l'inscription, 2 : le parcours)
local ONGLETS = {
	{ texte = "LIST_MY_GROUP", client = 1 },
	{ texte = "JOIN", client = 2 },
}

-- le panneau de l'onglet du client, et les onglets du bas qui le disent
function R.afficherPanneau()
	local n = (LFRParentFrame.activeTab == 2) and 2 or 1
	R.panneau = n
	local S = ForeverUI.Social
	for i, o in ipairs(R.onglets) do
		S.choisirOnglet(o, i == n, true)
		o:SetWidth(S.largeurOnglet(o))
	end
	if n == 1 then
		R.inscription:Show()
		R.parcours:Hide()
	else
		R.parcours:Show()
		R.inscription:Hide()
	end
end

local function construirePage(f)
	local p = CreateFrame("Frame", "ForeverUIGroupFinderRaid", f)
	p:SetAllPoints(f)
	p:Hide()
	R.page = p
	R.inscription = CreateFrame("Frame", "ForeverUIGroupFinderRaidQueue", p)
	R.inscription:SetAllPoints(f)
	R.parcours = CreateFrame("Frame", "ForeverUIGroupFinderRaidBrowse", p)
	R.parcours:SetAllPoints(f)
	construireInscription(R.inscription)
	construireParcours(R.parcours)

	local S = ForeverUI.Social
	R.onglets = {}
	local precedent
	for i, def in ipairs(ONGLETS) do
		local o = S.creerOnglet(p, "ForeverUIGroupFinderRaidTab" .. i, false)
		o:SetText(txt(def.texte))
		if precedent then
			o:SetPoint("TOPLEFT", precedent, "TOPRIGHT", M.ongletEcart, 0)
		else
			o:SetPoint("TOPLEFT", f, "BOTTOMLEFT", M.ongletX, M.ongletY)
		end
		-- l'onglet du client fait le reste : LFRFrame_SetActiveTab
		o:SetScript("OnClick", function()
			PlaySound("igCharacterInfoTab")
			LFRFrame_SetActiveTab(def.client)
		end)
		R.onglets[i] = o
		precedent = o
	end
end

local function majPage()
	if R.panneau == 2 then majParcours() else majInscription() end
end

local function ouvrir()
	if LFDParentFrame and LFDParentFrame:IsShown() then HideUIPanel(LFDParentFrame) end
	F.attacher(LFRParentFrame)
	etoufferClient()
	-- les deux contenus du client a la fois : l'inscription et le parcours
	LFRQueueFrame:Show()
	LFRBrowseFrame:Show()
	F.cadre:Show()
	R.afficherPanneau()
	F.afficher("raid")
end

construirePage(F.cadre)
F.inscrirePage("raid", R.page, majPage)
LFRParentFrame:HookScript("OnShow", ouvrir)
LFRParentFrame:HookScript("OnHide", function()
	if F.cadre:GetParent() == LFRParentFrame then F.cadre:Hide() end
end)
-- le client ne montre qu'un de ses deux contenus : on remontre l'autre, et
-- notre panneau suit son onglet
if LFRFrame_SetActiveTab then
	hooksecurefunc("LFRFrame_SetActiveTab", function()
		if LFRParentFrame:IsShown() then
			LFRQueueFrame:Show()
			LFRBrowseFrame:Show()
			if F.cadre:GetParent() == LFRParentFrame then
				R.afficherPanneau()
				F.maj()
			end
		end
	end)
end
for _, nom in ipairs({ "LFRQueueFrameSpecificList_Update", "LFRQueueFrameFindGroupButton_Update",
	"LFRBrowseFrameList_Update", "LFRBrowse_UpdateButtonStates" }) do
	if _G[nom] then hooksecurefunc(nom, F.demander) end
end
-- LA REPONSE DU SERVEUR : relevee pour le raid cherche
local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("UPDATE_LFG_LIST")
veilleur:SetScript("OnEvent", function()
	local cherche = SearchLFGGetJoinedID and SearchLFGGetJoinedID()
	if cherche then R.relever(cherche) end
	F.demander()
end)
ForeverUI.Superposition.inscrire("chercheurRaid", LFRParentFrame, function()
	local z = { F.cadre }
	for _, o in ipairs(F.onglets) do z[#z + 1] = o end
	-- les onglets du bas sortent de la fenetre
	for _, o in ipairs(R.onglets) do z[#z + 1] = o end
	return z
end)
