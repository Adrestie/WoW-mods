-- ForeverUI : le courrier (MailFrame : boite de reception et envoi ;
-- OpenMailFrame : la lettre ouverte), a la DA de camelot (demande de
-- l'utilisateur, 2026-09-28 : « fait le reste du commerce »).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (MailFrame.xml / .lua de 3.3.5,
-- FrameXML) :
--   MailFrame 384 x 512 a TOPLEFT (0, -104) : Mail-Icon (sans nom, 58 x 58 a
--     (10, -8)), MailFrameTopLeft / TopRight / BotLeft / BotRight (art
--     change par MailFrameTab_OnClick) ; InboxCloseButton ; MailFrameTab1 /
--     Tab2 (FriendsFrameTabTemplate) BOTTOMLEFT (24, 44) ;
--   InboxFrame : InboxTitleText, MailItem1 (28, -80) et six dessous (305 x
--     45), InboxCurrentPage BOTTOM (-14, 96), Prev / Next CENTER sur
--     BOTTOMLEFT (50 / 314, 104), InboxTooMuchMail TOP (0, -38) ;
--   SendMailFrame : SendMailTitleText, les barres UI-ClassTrainer-
--     HorizontalBar (15, -350) et -Left2 (reposee), SendMailScrollFrame
--     (UIPanelScrollFrameTemplate 296 x 257 a (21, -97), fond de barre
--     UI-Character-ScrollBar), SendMailNameEditBox (105, -46) 109 x 20, le
--     sujet dessous (0, -3), SendMailCostMoneyFrame TOPRIGHT (-36, -48),
--     SendMailMoneyButton BOTTOMLEFT (30, 110), le choix envoi / contre
--     remboursement a (0, 12) de l'argent, SendMailMoneyFrame BOTTOMRIGHT sur
--     BOTTOMLEFT (183, 84), Cancel BOTTOMRIGHT (-39, 80) et Send a sa gauche ;
--     les pieces jointes placees par SendMailFrame_Update (marges 31 / 46,
--     hauteur 156) ;
--   OpenMailFrame 384 x 512 sur InboxFrame (-10, 0) : son art, son titre
--     OPENMAIL, expediteur (114, -45) et sujet (114, -65), Report Spam
--     TOPRIGHT (-45, -45), OpenMailScrollFrame (21, -97), les pieces jointes,
--     la barre et le texte des pieces placees par OpenMail_Update (marges
--     27 / 47, hauteur 103 ; barre a (15, 114 + hauteur)), Close / Delete /
--     Reply BOTTOMRIGHT (-39, 80).
--
-- RELEVE -- CAMELOT (blizzard_mailframe/mailframe.xml / .lua, mainline) :
--   MailFrame : ButtonFrameTemplate (338 x 424), portrait Mail-Icon
--     (SetPortraitToAsset), titre INBOX / SENDMAIL selon l'onglet ; l'encart
--     de (4, -58) sans barre de boutons a la reception, de (4, -80) avec a
--     l'envoi (MailFrameTab_OnClick) ; onglets PanelTabButtonTemplate, le
--     premier BOTTOMLEFT (14, -30), le suivant a +3 ;
--   InboxFrame : InboxFrameBg (UI-MailFrameBG 512 x 512 a (7, -62)),
--     MailItem1 (13, -70), InboxCurrentPage BOTTOM (0, 8) 192 de large, Prev
--     BOTTOMLEFT (14, 10), Next BOTTOMRIGHT (-14, 10), InboxTooMuchMail TOP
--     (0, -25), OpenAllMail (UIPanelButtonTemplate 120 x 24 CENTER sur
--     BOTTOM (0, 26)) ; le contour de qualite de la premiere piece jointe,
--     grise a 0,5 une fois la lettre lue (InboxFrame_Update) ;
--   SendMailFrame : barres (2, -337) et -Left2 (2, 96 + hauteur),
--     SendMailScrollFrame (8, -83) et sa barre MinimalScrollBar (10, -4 /
--     3), le nom (90, -30) 109 x 25 (bord gauche a -2), le sujet dessous
--     (0, 0), le cout TOPRIGHT (-4, -34), SendMailMoneyButton BOTTOMLEFT
--     (15, 37), le choix a (20, 12) de l'argent, l'argent dans son encart
--     (4, 4 / 170, 27) et son bord dore (7, 6 / 166, 25), la bourse
--     BOTTOMRIGHT sur BOTTOMLEFT (175, 8), Cancel BOTTOMRIGHT (-7, 4) ;
--     pieces jointes : fond UI-Slot-Background a (-1, 1), contour de qualite,
--     placees par SendMailFrame_Update (marges 14 / 0, hauteur 82, pas en x
--     moins 2) ;
--   OpenMailFrame : ButtonFrameTemplate a TOPLEFT sur MailFrame TOPRIGHT
--     (46, 0), titre OPENMAIL, portrait = la papeterie de la lettre ;
--     encart (4, -80) ; expediteur (105, -33) jusqu'a Report Spam (-5) ou
--     jusqu'au bord (-12) sans lui ; sujet (105, -55) ; Report Spam TOPRIGHT
--     (-12, -32) ; OpenMailScrollFrame (8, -84), barre (10, -3 / 5) ;
--     placement par OpenMail_Update (marges 14 / 47, hauteur 28, pas en x
--     plus 6 ; barre a (2, 39 + hauteur)) ; Close BOTTOMRIGHT (-6, 4).
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : les cadres et la
-- logique du client restent ; les placements que le client refait a chaque
-- mise a jour (pieces jointes, barres, hauteur du texte) sont refaits
-- apres lui avec les nombres de camelot. Le portrait suit la regle VALIDEE
-- (48, centre sur le trou de l'anneau). « Tout ouvrir » est porte avec les
-- fonctions de 3.3.5 (TakeInboxMoney, TakeInboxItem, delai de 0,15 s) :
-- 3.3.5 ne dit pas quel objet a echoue (MAIL_FAILED sans argument) ni si
-- une commande est en cours, le suivi des echecs de camelot manque donc. La
-- facture d'une vente garde la disposition de 3.3.5. Le choix de papeterie
-- de 3.3.5 (StationeryPopupFrame) n'est pas repris.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits
local L = ForeverUI.L

local C = {}
ForeverUI.Courrier = C

local SEP = string.char(92)

local N = {
	fenetre = { 338, 424 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	encart = { reception = { 4, -58, -6, 4 }, envoi = { 4, -80, -6, 26 } },
	onglet = { x = 14, y = -30, ecart = 3 },
	reception = { fond = { 512, 7, -62 }, premier = { 13, -70 }, page = { 0, 8, 192 },
		precedent = { 14, 10 }, suivant = { -14, 10 }, tropDeCourrier = { 0, -25 },
		toutOuvrir = { 120, 24, 0, 26 }, luGris = 0.5 },
	envoi = { barre1 = { 2, -337 }, defile = { 8, -83 }, barre = { 10, -4, 3 },
		nom = { 90, -30, 109, 25, bord = -2 }, cout = { -4, -34 }, argentBouton = { 15, 37 },
		choix = { 20, 12 }, encartArgent = { 4, 4, 170, 27 }, bordArgent = { 7, 6, 166, 25 },
		bourse = { 175, 8 }, annuler = { -7, 4 }, fondPiece = { -1, 1 } },
	pieces = { envoi = { gauche = 14, droite = 0, haut = 82, pasX = -2, barreX = 2, barreY = 96 },
		lecture = { gauche = 14, droite = 47, haut = 28, pasX = 6, barreX = 2, barreY = 39 } },
	lecture = { place = { 46, 0 }, encart = { 4, -80, -6, 26 }, expediteur = { 105, -33 },
		sujet = { 105, -55 }, spam = { -12, -32 }, finExpediteur = { -5, -12 },
		defile = { 8, -84 }, barre = { 10, -3, 5 }, fermer = { -6, 4 } },
	delaiOuverture = 0.15,
	-- la page de la lettre : Stationery*1 pose a 252 de large, le bord dechire
	-- de Stationery*2 opaque jusqu'a sa colonne 49 -- la page finit a 302 de
	-- la fenetre a defilement, 310 de la fenetre. Sans barre, elle va a 4 du
	-- bord droit de l'encart (332), comme elle est a 4 de son bord gauche :
	-- 18 de plus, pris sur la partie gauche, etiree. Sans barre, la fenetre a
	-- defilement et son enfant vont au bout de la page (320), et le texte
	-- jusqu'a y laisser a droite la marge qu'il a a gauche : l'envoi (a 20 de
	-- la page) 280, la lettre (a 10) 300
	papeterie = { gauche = 252, sansBarre = 18, defile = 320, envoi = 280, lecture = 300 },
}

local ART = {
	icone = "Interface" .. SEP .. "MailFrame" .. SEP .. "Mail-Icon",
	fondReception = "Interface" .. SEP .. "ForeverUI" .. SEP .. "mailframe" .. SEP .. "ui-mailframebg",
	marbre = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	argent = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	papeterie = "Interface" .. SEP .. "Stationery" .. SEP .. "StationeryTest",
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- InsetFrameTemplate : marbre et lisere, en regions de la fenetre, cales
-- sur un repere qu'on reancre
local function encart(f)
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	local marbre = f:CreateTexture(nil, "BACKGROUND")
	marbre:SetTexture(ART.marbre, true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(rect)
	rect.marbre = marbre
	rect.lisere = Gb.NeufTranches(f, "InsetFrameTemplate", rect)
	return rect
end

local function placerEncart(rect, f, e)
	rect:ClearAllPoints()
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", e[1], e[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", e[3], e[4])
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

-- le fond de barre UI-Character-ScrollBar d'une fenetre a defilement (ses
-- deux textures, l'une nommee, l'autre non) s'eteint
local function eteindreFondBarre(sf)
	for _, r in ipairs({ sf:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" and string.find(string.lower(t), "ui-character-scrollbar", 1, true) then
				r:SetAlpha(0)
			end
		end
	end
end

-- ------------------------------------------------------------ l'onglet

-- APRES MailFrameTab_OnClick : titre, encart, onglets
function C.ApresOnglet()
	local f = MailFrame
	local h = f.foreverHabit
	if not h then return end
	local envoi = f.selectedTab == 2
	h.titre:SetText(envoi and SENDMAIL or INBOX)
	placerEncart(h.encart, f, envoi and N.encart.envoi or N.encart.reception)
	local S = ForeverUI.Social
	for i, o in ipairs(C.onglets or {}) do
		S.choisirOnglet(o, f.selectedTab == i, true)
		o:SetWidth(S.largeurOnglet(o))
	end
end

-- ------------------------------------------------------------ la reception

-- APRES InboxFrame_Update : le contour de la premiere piece jointe
function C.ApresReception()
	local page = InboxFrame.pageNum or 1
	for i = 1, INBOXITEMS_TO_DISPLAY do
		local index = (page - 1) * INBOXITEMS_TO_DISPLAY + i
		local b = _G["MailItem" .. i .. "Button"]
		local lu, piece
		if index <= GetInboxNumItems() then
			local _, _, _, _, _, _, _, avecObjet, dejaLu = GetInboxHeaderInfo(index)
			lu = dejaLu
			if avecObjet then
				for p = 1, ATTACHMENTS_MAX_RECEIVE do
					local nom, _, _, q = GetInboxItem(index, p)
					if nom then piece = q break end
				end
			end
		end
		Gb.ContourQualite(b, piece)
		if lu and piece then
			local g = N.reception.luGris
			b.foreverContour:SetVertexColor(g, g, g)
		end
	end
end

-- « TOUT OUVRIR » (OpenAllMailMixin de camelot, sur les fonctions de 3.3.5)
local ouvrir = { courrier = 1, piece = ATTACHMENTS_MAX, attente = nil }

local function placesLibres()
	local n = 0
	for sac = 0, NUM_BAG_SLOTS do
		n = n + (GetContainerNumFreeSlots(sac) or 0)
	end
	return n
end

local function arreter()
	local b = C.toutOuvrir
	ouvrir.courrier, ouvrir.piece, ouvrir.attente = 1, ATTACHMENTS_MAX, nil
	b:Enable()
	b:SetText(L.MAIL_OPEN_ALL)
	b:UnregisterEvent("MAIL_INBOX_UPDATE")
end

-- les lettres d'un MJ et les contre remboursements s'ouvrent a la main
local function sauterLettre(i)
	local _, _, _, _, _, contre, _, _, _, _, _, _, mj = GetInboxHeaderInfo(i)
	return mj or (contre and contre > 0)
end

local function sauterPiece(i, p)
	local _, _, _, _, argent = GetInboxHeaderInfo(i)
	if argent and argent > 0 then return false end
	return GetInboxItem(i, p) == nil
end

local function lettreSuivante()
	ouvrir.courrier = ouvrir.courrier + 1
	ouvrir.piece = ATTACHMENTS_MAX
	return ouvrir.courrier <= GetInboxNumItems()
end

local function pieceSuivante()
	while true do
		if ouvrir.courrier > GetInboxNumItems() then return false end
		if sauterLettre(ouvrir.courrier) then
			if not lettreSuivante() then return false end
		else
			while ouvrir.piece > 0 and sauterPiece(ouvrir.courrier, ouvrir.piece) do
				ouvrir.piece = ouvrir.piece - 1
			end
			if ouvrir.piece > 0 then return true end
			if not lettreSuivante() then return false end
		end
	end
end

local function traiter()
	if placesLibres() == 0 or not pieceSuivante() then
		arreter()
		return
	end
	local _, _, _, _, argent, _, _, nombre = GetInboxHeaderInfo(ouvrir.courrier)
	if argent and argent > 0 then
		TakeInboxMoney(ouvrir.courrier)
		ouvrir.attente = N.delaiOuverture
	elseif nombre and nombre > 0 then
		TakeInboxItem(ouvrir.courrier, ouvrir.piece)
		ouvrir.attente = N.delaiOuverture
	else
		traiter()
	end
end

function C.ToutOuvrir()
	local b = C.toutOuvrir
	ouvrir.courrier, ouvrir.piece, ouvrir.attente = 1, ATTACHMENTS_MAX, nil
	ouvrir.nombre = GetInboxNumItems()
	b:Disable()
	b:SetText(L.MAIL_OPEN_ALL_OPENING)
	b:RegisterEvent("MAIL_INBOX_UPDATE")
	traiter()
end

local function boutonToutOuvrir()
	local T = N.reception.toutOuvrir
	local b = CreateFrame("Button", "ForeverUIOpenAllMail", InboxFrame, "UIPanelButtonTemplate")
	b:SetWidth(T[1])
	b:SetHeight(T[2])
	b:SetPoint("CENTER", InboxFrame, "BOTTOM", T[3], T[4])
	b:SetText(L.MAIL_OPEN_ALL)
	Gb.BoutonPanneau(b)
	b:SetScript("OnClick", C.ToutOuvrir)
	b:SetScript("OnHide", arreter)
	b:SetScript("OnEvent", function()
		-- une lettre est partie : on reprend au debut
		if ouvrir.nombre ~= GetInboxNumItems() then
			ouvrir.courrier, ouvrir.piece = 1, ATTACHMENTS_MAX
			ouvrir.nombre = GetInboxNumItems()
		end
	end)
	b:SetScript("OnUpdate", function(_, e)
		if ouvrir.attente then
			ouvrir.attente = ouvrir.attente - e
			if ouvrir.attente <= 0 then
				ouvrir.attente = nil
				traiter()
			end
		end
	end)
	C.toutOuvrir = b
end

local function reception()
	local R = N.reception
	local fond = InboxFrame:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture(ART.fondReception)
	fond:SetWidth(R.fond[1])
	fond:SetHeight(R.fond[1])
	fond:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", R.fond[2], R.fond[3])
	C.fondReception = fond
	InboxTitleText:SetAlpha(0)
	poser(MailItem1, "TOPLEFT", InboxFrame, "TOPLEFT", R.premier[1], R.premier[2])
	InboxCurrentPage:SetWidth(R.page[3])
	poser(InboxCurrentPage, "BOTTOM", InboxFrame, "BOTTOM", R.page[1], R.page[2])
	poser(InboxPrevPageButton, "BOTTOMLEFT", InboxFrame, "BOTTOMLEFT", R.precedent[1], R.precedent[2])
	poser(InboxNextPageButton, "BOTTOMRIGHT", InboxFrame, "BOTTOMRIGHT", R.suivant[1], R.suivant[2])
	poser(InboxTooMuchMail, "TOP", InboxFrame, "TOP", R.tropDeCourrier[1], R.tropDeCourrier[2])
	boutonToutOuvrir()
	hooksecurefunc("InboxFrame_Update", C.ApresReception)
end

-- ------------------------------------------------------------ l'envoi

-- APRES SendMailFrame_Update : pieces jointes, barre, hauteur du texte,
-- avec les nombres de camelot ; le contour de qualite des pieces
function C.ApresEnvoi()
	local P = N.pieces.envoi
	local rangs = SendMailFrame.maxRowsShown or 1
	local premier = SendMailAttachment1
	local largeur = SendMailFrame:GetWidth() - P.gauche - P.droite
	local iconeX, iconeY = premier:GetWidth() + 2, premier:GetHeight() + 2
	local ecartX1 = math.floor((largeur - iconeX * ATTACHMENTS_PER_ROW_SEND) / (ATTACHMENTS_PER_ROW_SEND - 1))
	local ecartX2 = math.floor((largeur - iconeX * ATTACHMENTS_PER_ROW_SEND - ecartX1 * (ATTACHMENTS_PER_ROW_SEND - 1)) / 2)
	local ecartY1, ecartY2 = 5, 6
	local hauteur = ecartY2 * 2 + ecartY1 * (rangs - 1) + iconeY * rangs
	local retraitX = P.gauche + ecartX2
	local retraitY = P.haut + ecartY2 + iconeY
	local pasX = iconeX + ecartX1 + P.pasX
	local pasY = iconeY + ecartY1
	local defile = 249 - hauteur
	SendMailScrollFrame:SetHeight(defile)
	SendMailScrollChildFrame:SetHeight(defile)
	poser(SendMailHorizontalBarLeft2, "TOPLEFT", SendMailFrame, "BOTTOMLEFT", P.barreX, P.barreY + hauteur)
	-- la papeterie de camelot, toujours la meme
	SendStationeryBackgroundLeft:SetTexture(ART.papeterie .. "1")
	SendStationeryBackgroundRight:SetTexture(ART.papeterie .. "2")
	local cx, cy = 0, rangs - 1
	for i = 1, ATTACHMENTS_MAX_SEND do
		local b = _G["SendMailAttachment" .. i]
		if cy >= 0 then
			poser(b, "TOPLEFT", SendMailFrame, "BOTTOMLEFT", retraitX + pasX * cx, retraitY + pasY * cy)
			cx = cx + 1
			if cx >= ATTACHMENTS_PER_ROW_SEND then
				cy, cx = cy - 1, 0
			end
		end
		local nom, _, _, q = GetSendMailItem(i)
		Gb.ContourQualite(b, nom and q or nil)
	end
end

local function envoi(f)
	local E = N.envoi
	local s = SendMailFrame
	SendMailTitleText:SetAlpha(0)
	poser(SendMailHorizontalBarLeft, "TOPLEFT", s, "TOPLEFT", E.barre1[1], E.barre1[2])
	poser(SendMailScrollFrame, "TOPLEFT", s, "TOPLEFT", E.defile[1], E.defile[2])
	eteindreFondBarre(SendMailScrollFrame)
	Gb.BarreA(SendMailScrollFrameScrollBar, SendMailScrollFrame, E.barre[1], E.barre[2], E.barre[3])
	-- la barre seulement si elle sert, le texte ET LA PAGE prennent sa place
	-- (regle du 28/09, Gb.BarreSelonContenu) : 296 / 300 / 270 du modele 3.3.5
	local Pp = N.papeterie
	Gb.BarreSelonContenu(SendMailScrollFrame, function(avec)
		SendMailScrollFrame:SetWidth(avec and 296 or Pp.defile)
		SendMailScrollChildFrame:SetWidth(avec and 300 or Pp.defile)
		SendMailBodyEditBox:SetWidth(avec and 270 or Pp.envoi)
		SendStationeryBackgroundLeft:SetWidth(Pp.gauche + (avec and 0 or Pp.sansBarre))
	end)
	local nom = SendMailNameEditBox
	nom:SetWidth(E.nom[3])
	nom:SetHeight(E.nom[4])
	poser(nom, "TOPLEFT", s, "TOPLEFT", E.nom[1], E.nom[2])
	poser(SendMailNameEditBoxLeft, "TOPLEFT", nom, "TOPLEFT", -8, E.nom.bord)
	poser(SendMailSubjectEditBox, "TOPLEFT", nom, "BOTTOMLEFT", 0, 0)
	poser(SendMailCostMoneyFrame, "TOPRIGHT", s, "TOPRIGHT", E.cout[1], E.cout[2])
	poser(SendMailMoneyButton, "BOTTOMLEFT", s, "BOTTOMLEFT", E.argentBouton[1], E.argentBouton[2])
	poser(SendMailSendMoneyButton, "TOPLEFT", SendMailMoney, "TOPRIGHT", E.choix[1], E.choix[2])
	-- l'argent : encart et bord dore, en regions de la fenetre d'envoi
	local ea = encart(s)
	ea:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", E.encartArgent[1], E.encartArgent[2])
	ea:SetPoint("TOPRIGHT", s, "BOTTOMLEFT", E.encartArgent[3], E.encartArgent[4])
	C.encartArgent = ea
	local bord = CreateFrame("Frame", nil, s)
	bord:EnableMouse(false)
	bord:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", E.bordArgent[1], E.bordArgent[2])
	bord:SetPoint("TOPRIGHT", s, "BOTTOMLEFT", E.bordArgent[3], E.bordArgent[4])
	C.bordArgent = bord
	C.bordDore = bordDore(s, bord)
	poser(SendMailMoneyFrame, "BOTTOMRIGHT", s, "BOTTOMLEFT", E.bourse[1], E.bourse[2])
	poser(SendMailCancelButton, "BOTTOMRIGHT", s, "BOTTOMRIGHT", E.annuler[1], E.annuler[2])
	-- le fond de chaque piece jointe : UI-Slot-Background a (-1, 1)
	for i = 1, ATTACHMENTS_MAX do
		local b = _G["SendMailAttachment" .. i]
		for _, r in ipairs({ b:GetRegions() }) do
			if r:GetObjectType() == "Texture" and r:GetDrawLayer() == "BACKGROUND" then
				poser(r, "TOPLEFT", b, "TOPLEFT", E.fondPiece[1], E.fondPiece[2])
			end
		end
	end
	hooksecurefunc("SendMailFrame_Update", C.ApresEnvoi)
end

-- ------------------------------------------------------------ la lettre ouverte

-- APRES OpenMail_Update : portrait, expediteur, pieces jointes et barre avec
-- les nombres de camelot, contour de qualite
function C.ApresLecture()
	local o = OpenMailFrame
	local h = o.foreverHabit
	local id = InboxFrame.openMailID
	if not h or not id or id == 0 then return end
	local _, papeterie = GetInboxHeaderInfo(id)
	h.portrait:SetTexture(papeterie or ART.icone)
	local Lc = N.lecture
	local fs = OpenMailSender
	fs:ClearAllPoints()
	fs:SetPoint("LEFT", OpenMailSenderLabel, "RIGHT", 5, 0)
	if OpenMailReportSpamButton:IsShown() then
		fs:SetPoint("RIGHT", OpenMailReportSpamButton, "LEFT", Lc.finExpediteur[1], 0)
	else
		fs:SetPoint("RIGHT", o, "RIGHT", Lc.finExpediteur[2], 0)
	end

	local P = N.pieces.lecture
	local rangs = o.activeAttachmentRowPositions and #o.activeAttachmentRowPositions or 0
	local premier = OpenMailAttachmentButton1
	local largeur = o:GetWidth() - P.gauche - P.droite
	local iconeX, iconeY = premier:GetWidth() + 2, premier:GetHeight() + 2
	local ecartX1 = math.floor((largeur - iconeX * ATTACHMENTS_PER_ROW_RECEIVE) / (ATTACHMENTS_PER_ROW_RECEIVE - 1))
	local ecartX2 = math.floor((largeur - iconeX * ATTACHMENTS_PER_ROW_RECEIVE - ecartX1 * (ATTACHMENTS_PER_ROW_RECEIVE - 1)) / 2)
	local ecartY1, ecartY2 = 3, 3
	local texte = OpenMailAttachmentText
	local hauteur = ecartY2 + texte:GetHeight() + ecartY2 + iconeY * rangs + ecartY1 * (rangs - 1) + ecartY2
	local retraitX = P.gauche + ecartX2
	local retraitY = P.haut + ecartY2
	local pasX = iconeX + ecartX1 + P.pasX
	local pasY = iconeY + ecartY1
	local defile = 305 - hauteur
	if defile > 256 then
		defile = 256
		hauteur = 305 - defile
	end
	OpenMailScrollFrame:SetHeight(defile)
	OpenMailScrollChildFrame:SetHeight(defile)
	poser(OpenMailHorizontalBarLeft, "TOPLEFT", o, "BOTTOMLEFT", P.barreX, P.barreY + hauteur)
	if (o.itemButtonCount or 0) > 0 then
		poser(texte, "TOPLEFT", o, "BOTTOMLEFT", retraitX,
			retraitY + iconeY * rangs + ecartY1 * (rangs - 1) + ecartY2 + texte:GetHeight())
	else
		poser(texte, "TOPLEFT", o, "BOTTOMLEFT", P.gauche + (largeur - texte:GetWidth()) / 2,
			retraitY + (hauteur - texte:GetHeight()) / 2 + texte:GetHeight())
	end
	if rangs > 0 and o.activeAttachmentButtons then
		local rang = 1
		local cx = o.activeAttachmentRowPositions[1].cursorxstart
		local cxFin = o.activeAttachmentRowPositions[1].cursorxend
		local cy = rangs - 1
		for _, b in pairs(o.activeAttachmentButtons) do
			poser(b, "TOPLEFT", o, "BOTTOMLEFT", retraitX + pasX * cx, retraitY + iconeY + pasY * cy)
			if b ~= OpenMailLetterButton and b ~= OpenMailMoneyButton then
				local _, _, _, q = GetInboxItem(id, b:GetID())
				Gb.ContourQualite(b, q)
			else
				Gb.ContourQualite(b, nil)
			end
			cx = cx + 1
			if cx > cxFin then
				rang = rang + 1
				cy = cy - 1
				if rang <= rangs then
					cx = o.activeAttachmentRowPositions[rang].cursorxstart
					cxFin = o.activeAttachmentRowPositions[rang].cursorxend
				end
			end
		end
	end
end

local function lecture()
	local o = OpenMailFrame
	local Lc = N.lecture
	for _, r in ipairs({ OpenMailFrameIcon, OpenMailFrameTopLeft, OpenMailFrameTopRight, OpenMailFrameBotLeft,
		OpenMailFrameBotRight, OpenMailTitleText }) do
		r:SetAlpha(0)
	end
	o:SetWidth(N.fenetre[1])
	o:SetHeight(N.fenetre[2])
	o:SetHitRectInsets(0, 0, 0, 0)
	poser(o, "TOPLEFT", MailFrame, "TOPRIGHT", Lc.place[1], Lc.place[2])
	local habit = Gb.FenetrePortrait(o, {
		portrait = ART.icone, portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = OPENMAIL,
	})
	o.foreverHabit = habit
	habit.encart = encart(o)
	placerEncart(habit.encart, o, Lc.encart)
	poser(OpenMailSenderLabel, "TOPRIGHT", o, "TOPLEFT", Lc.expediteur[1], Lc.expediteur[2])
	poser(OpenMailSubjectLabel, "TOPRIGHT", o, "TOPLEFT", Lc.sujet[1], Lc.sujet[2])
	OpenMailSender:SetJustifyH("LEFT")
	poser(OpenMailReportSpamButton, "TOPRIGHT", o, "TOPRIGHT", Lc.spam[1], Lc.spam[2])
	poser(OpenMailScrollFrame, "TOPLEFT", o, "TOPLEFT", Lc.defile[1], Lc.defile[2])
	eteindreFondBarre(OpenMailScrollFrame)
	Gb.BarreA(OpenMailScrollFrameScrollBar, OpenMailScrollFrame, Lc.barre[1], Lc.barre[2], Lc.barre[3])
	-- la barre seulement si elle sert, le texte ET LA PAGE prennent sa place
	-- (296 / 276)
	local Pp = N.papeterie
	Gb.BarreSelonContenu(OpenMailScrollFrame, function(avec)
		OpenMailScrollFrame:SetWidth(avec and 296 or Pp.defile)
		OpenMailScrollChildFrame:SetWidth(avec and 296 or Pp.defile)
		OpenMailBodyText:SetWidth(avec and 276 or Pp.lecture)
		OpenStationeryBackgroundLeft:SetWidth(Pp.gauche + (avec and 0 or Pp.sansBarre))
	end)
	poser(OpenMailCancelButton, "BOTTOMRIGHT", o, "BOTTOMRIGHT", Lc.fermer[1], Lc.fermer[2])
	Gb.Croix(OpenMailCloseButton, o)
	OpenMailCloseButton:SetFrameLevel(o:GetFrameLevel() + 22)
	hooksecurefunc("OpenMail_Update", C.ApresLecture)
end

-- ------------------------------------------------------------ la fenetre

local function onglets(f)
	local S = ForeverUI.Social
	local O = N.onglet
	C.onglets = {}
	for i, texte in ipairs({ INBOX, SENDMAIL }) do
		local o = S.creerOnglet(f, "ForeverUIMailTab" .. i, false)
		o:SetText(texte)
		if i == 1 then
			o:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", C.onglets[i - 1], "TOPRIGHT", O.ecart, 0)
		end
		-- ce que fait l'onglet du client
		o:SetScript("OnClick", function()
			MailFrameTab_OnClick(_G["MailFrameTab" .. i], i)
		end)
		C.onglets[i] = o
		ForeverUI.Suppress(_G["MailFrameTab" .. i])
	end
end

function C.Habiller()
	local f = MailFrame
	if not f or f.foreverHabit then return end
	-- l'art de 3.3.5 : l'icone sans nom et les quatre morceaux
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			r:SetAlpha(0)
		end
	end
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	local habit = Gb.FenetrePortrait(f, {
		portrait = ART.icone, portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = INBOX,
	})
	f.foreverHabit = habit
	habit.encart = encart(f)
	-- la reception et l'envoi remplissent la fenetre (TOPLEFT / BOTTOMRIGHT)
	for _, c in ipairs({ InboxFrame, SendMailFrame }) do
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
		-- (la taille suit les ancres ; posee aussi, pour qui la lit tout de suite)
		c:SetWidth(N.fenetre[1])
		c:SetHeight(N.fenetre[2])
	end
	Gb.Croix(InboxCloseButton, f)
	InboxCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	reception()
	envoi(f)
	lecture()
	onglets(f)
	hooksecurefunc("MailFrameTab_OnClick", C.ApresOnglet)
	C.ApresOnglet()
end

C.Habiller()
