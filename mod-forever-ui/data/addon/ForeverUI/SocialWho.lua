-- ForeverUI : la page "Who" de la fenetre Social (onglet 2 du client).
--
-- La page reprend WotLK (FriendsFrame.lua et .xml du client, WhoList_Update
-- et WhoFrame) -- saisie, totaux, boutons -- habille comme le reste de la
-- fenetre. LA LISTE DES JOUEURS est celle de camelot (2026-09-26, demande de
-- l'utilisateur) : camelot range son "Qui" dans le chercheur de groupe
-- (blizzard_groupfinder_vanillastyle, charge par [Family]\WhoList.xml),
-- LFGWhoListFrame.
--
-- RELEVE camelot (wholist.xml et .lua) :
--   carte     LFGWhoListButtonTemplate, 69 de haut, large comme la liste ;
--             fond common-button-list-large, choisie
--             common-button-list-large-selected, survol
--             common-button-list-large-hover en ADD ; pas d'ecart entre les
--             cartes ; pas d'en-tetes de colonnes, pas de tri. Les trois
--             images en NEUF TRANCHES, coins de 9 (mesures sur l'art 169 x 69) :
--             etirees d'un bloc, leurs angles se deformaient (2026-09-26)
--   textes    GameFontNormalMed1 (SystemFont_Med2, ombre 1,-1, or) :
--             ligne 1 le nom (10, -6) jusqu'au bord droit ; ligne 2, 6 plus
--             bas, LFG_WHO_LEVEL, la race (+10), la classe (+10, teinte
--             RAID_CLASS_COLORS) en blanc ; ligne 3, 6 plus bas, la colonne
--             variable -- whoSortValue = 1 : la zone -- puis la guilde (+10)
--             en FRIENDS_GRAY_COLOR
--   clics     gauche : la selection, un second clic la retire ; droit :
--             FriendsFrame_ShowDropdown(nom, 1)
--   infobulle si le nom, le niveau ou la colonne variable sont coupes : le
--             nom, WHO_LIST_LEVEL_TOOLTIP, la colonne variable
--
-- ECARTS : 3.3.5 n'a ni GameFontNormalMed1 (on en tire une de SystemFont_Med2,
-- qu'il a), ni LFG_WHO_LEVEL / WHO_LIST_LEVEL_TOOLTIP (UNIT_LEVEL_TEMPLATE,
-- "Level %d", dans la langue du client), ni IsTruncated (la largeur du texte
-- comparee a celle du champ). Les lignes 1 a 3 sont posees a hauteur fixe,
-- la classe et la guilde bornees au bord droit a la hauteur de leur ligne.
--
-- RELEVE WotLK (ce qui entoure la liste) :
--   donnees   numWhos, totalCount = GetNumWhoResults() ;
--             name, guild, level, race, class, zone, classFileName =
--             GetWhoInfo(i) ; SendWho(texte)
--   totaux    format(WHO_FRAME_TOTAL_TEMPLATE, total), suivi de
--             format(WHO_FRAME_SHOWN_TEMPLATE, 50) au-dela de
--             MAX_WHOS_FROM_SERVER
--   saisie    Entree : SendWho(texte), puis la saisie perd le focus
--   boutons   REFRESH (85) : SendWho(texte), plus de selection ; ADD_FRIEND
--             (120) : AddFriend(nom) ; GROUP_INVITE (120) : InviteUnit(nom) ;
--             les deux derniers eteints sans selection
--   ecran     SetWhoToUI(1) a l'affichage de WhoFrame, 0 au masquage : les
--             resultats d'un /who viennent dans la fenetre, pas dans le chat

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local S = ForeverUI.Social
if not S or not S.inscrirePage then
	return
end

local W = {}
S.Who = W

local P = {
	encadreX1 = 4, encadreY1 = -60, encadreX2 = -6, encadreY2 = 74,
	listeX = 4, listeY = -4, listeX2 = -22, listeX2Seule = -4, listeBas = 4,
	carteH = 69, coin = 9, texteH = 13, texteX = 10, texteY = -6, ecartLigne = 6, ecartMot = 10,
	fond = "common-button-list-large",
	choisie = "common-button-list-large-selected",
	survol = "common-button-list-large-hover",
	totauxY = 58, saisieY = 30, saisieH = 20, saisieX = 12,
	boutonBas = 4, boutonDroite = -6, refreshL = 85, boutonL = 120,
}

local txt = S.txt

local function actif(b, oui)
	if b.Activer then b:Activer(oui) elseif oui then b:Enable() else b:Disable() end
end

-- GameFontNormalMed1 de camelot, tiree de SystemFont_Med2
local function police()
	if W.police then return W.police end
	local f = CreateFont("ForeverUIFontNormalMed1")
	f:SetFontObject(SystemFont_Med2)
	f:SetShadowOffset(1, -1)
	f:SetShadowColor(0, 0, 0)
	f:SetTextColor(1, 0.82, 0)
	W.police = f
	return f
end

-- IsTruncated, que 3.3.5 n'a pas : un champ de largeur fixee trop etroit
local function tronque(fs)
	local l = fs:GetWidth()
	return l and l > 0 and fs:GetStringWidth() > l + 0.5
end

local function niveauTexte(niveau)
	return string.format(txt("UNIT_LEVEL_TEMPLATE"), niveau or 0)
end

function W.maj()
	if not W.liste then return end
	local nombre, total = GetNumWhoResults()
	nombre, total = nombre or 0, total or 0
	local shown = ""
	if total > (MAX_WHOS_FROM_SERVER or 50) then
		shown = string.format(txt("WHO_FRAME_SHOWN_TEMPLATE"), MAX_WHOS_FROM_SERVER or 50)
	end
	W.totaux:SetText(string.format(txt("WHO_FRAME_TOTAL_TEMPLATE"), total) .. "  " .. shown)
	if W.choisi and W.choisi > nombre then W.choisi = nil end
	W.nomChoisi = W.choisi and GetWhoInfo(W.choisi) or nil
	actif(W.ajouter, W.choisi ~= nil)
	actif(W.inviter, W.choisi ~= nil)
	W.liste:Maj(nombre)
end

-- -------------------------------------------------------------- les cartes

local function montrer(tranches, oui)
	for _, t in ipairs(tranches) do
		if oui then t:Show() else t:Hide() end
	end
end

local function creerCarte(l)
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local bords = { 0, 0, 0, 0 }
	l.fond = ForeverUI.CreateNineSlice(l, P.fond, P.coin, bords, "BACKGROUND") or {}
	l.choisie = ForeverUI.CreateNineSlice(l, P.choisie, P.coin, bords, "BORDER") or {}
	montrer(l.choisie, false)
	-- le survol : la couche HIGHLIGHT, que le bouton montre sous la souris
	l.survol = ForeverUI.CreateNineSlice(l, P.survol, P.coin, bords, "HIGHLIGHT") or {}
	for _, t in ipairs(l.survol) do t:SetBlendMode("ADD") end

	local blanc = HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
	local gris = FRIENDS_GRAY_COLOR or { r = 0.486, g = 0.518, b = 0.541 }
	local function texte(couleur)
		local fs = l:CreateFontString(nil, "ARTWORK")
		fs:SetFontObject(police())
		fs:SetJustifyH("LEFT")
		fs:SetHeight(P.texteH)
		if couleur then fs:SetTextColor(couleur.r, couleur.g, couleur.b) end
		return fs
	end
	-- les centres des lignes 2 et 3, pour borner la classe et la guilde
	local y2 = P.texteY - P.texteH - P.ecartLigne
	local y3 = y2 - P.texteH - P.ecartLigne
	l.nom = texte()
	l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", P.texteX, P.texteY)
	l.nom:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, P.texteY)
	l.niveau = texte(blanc)
	l.niveau:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -P.ecartLigne)
	l.race = texte(blanc)
	l.race:SetPoint("LEFT", l.niveau, "RIGHT", P.ecartMot, 0)
	l.classe = texte(blanc)
	l.classe:SetPoint("LEFT", l.race, "RIGHT", P.ecartMot, 0)
	l.classe:SetPoint("RIGHT", l, "TOPRIGHT", 0, y2 - P.texteH / 2)
	l.variable = texte(gris)
	l.variable:SetPoint("TOPLEFT", l.niveau, "BOTTOMLEFT", 0, -P.ecartLigne)
	l.guilde = texte(gris)
	l.guilde:SetPoint("LEFT", l.variable, "RIGHT", P.ecartMot, 0)
	l.guilde:SetPoint("RIGHT", l, "TOPRIGHT", 0, y3 - P.texteH / 2)

	l:SetScript("OnClick", function(self, bouton)
		if bouton == "LeftButton" then
			if W.choisi == self.index then W.choisi = nil else W.choisi = self.index end
			W.maj()
		else
			FriendsFrame_ShowDropdown(GetWhoInfo(self.index), 1)
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	l:SetScript("OnEnter", function(self)
		if self.bulle then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(self.bulle[1])
			GameTooltip:AddLine(self.bulle[2], 1, 1, 1)
			GameTooltip:AddLine(self.bulle[3], 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	l:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- LFGWhoListButtonMixin:InitButton
local function remplirCarte(l, index)
	local nom, guilde, niveau, race, classe, zone, fichier = GetWhoInfo(index)
	local c = fichier and RAID_CLASS_COLORS and RAID_CLASS_COLORS[fichier] or HIGHLIGHT_FONT_COLOR
	l.nom:SetText(nom)
	l.niveau:SetText(niveauTexte(niveau))
	l.race:SetText(race)
	l.classe:SetText(classe)
	l.classe:SetTextColor(c.r, c.g, c.b)
	l.variable:SetText(zone)
	l.guilde:SetText(guilde)
	montrer(l.choisie, W.choisi == index)
	if tronque(l.variable) or tronque(l.niveau) or tronque(l.nom) then
		l.bulle = { nom, niveauTexte(niveau), zone }
	else
		l.bulle = nil
	end
end

local function construire(cadre)
	local encadre = ForeverUI.CreateInset(cadre, "ForeverUIWhoInset")
	encadre:SetPoint("TOPLEFT", S.cadre, "TOPLEFT", P.encadreX1, P.encadreY1)
	encadre:SetPoint("BOTTOMRIGHT", S.cadre, "BOTTOMRIGHT", P.encadreX2, P.encadreY2)

	W.liste = S.creerListe(encadre, "ForeverUIWhoList", P.carteH, creerCarte, remplirCarte)
	W.liste:SuivreBarre({ "TOPLEFT", encadre, "TOPLEFT", P.listeX, P.listeY },
		{ "BOTTOMRIGHT", encadre, "BOTTOMRIGHT", P.listeX2, P.listeBas }, P.listeX2Seule)

	W.totaux = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	W.totaux:SetPoint("BOTTOM", S.cadre, "BOTTOM", 0, P.totauxY)

	-- LA SAISIE : le champ de camelot (InputBoxVisualTemplate), comme la
	-- recherche du grimoire
	local b = CreateFrame("EditBox", "ForeverUIWhoEditBox", cadre)
	b:SetAutoFocus(false)
	b:SetHeight(P.saisieH)
	b:SetPoint("BOTTOMLEFT", S.cadre, "BOTTOMLEFT", P.saisieX, P.saisieY)
	b:SetPoint("BOTTOMRIGHT", S.cadre, "BOTTOMRIGHT", -P.saisieX, P.saisieY)
	b:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
	b:SetTextInsets(6, 6, 0, 0)
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
	b:SetScript("OnEnterPressed", function(self)
		SendWho(self:GetText())
		self:ClearFocus()
	end)
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	W.saisie = b

	W.inviter = S.bouton(cadre, txt("GROUP_INVITE"), P.boutonL)
	W.inviter:SetPoint("BOTTOMRIGHT", S.cadre, "BOTTOMRIGHT", P.boutonDroite, P.boutonBas)
	W.inviter:SetScript("OnClick", function()
		if W.nomChoisi then InviteUnit(W.nomChoisi) end
	end)
	W.ajouter = S.bouton(cadre, txt("ADD_FRIEND"), P.boutonL)
	W.ajouter:SetPoint("RIGHT", W.inviter, "LEFT", 0, 0)
	W.ajouter:SetScript("OnClick", function()
		if W.nomChoisi then AddFriend(W.nomChoisi) end
	end)
	W.rafraichir = S.bouton(cadre, txt("REFRESH"), P.refreshL)
	W.rafraichir:SetPoint("RIGHT", W.ajouter, "LEFT", 0, 0)
	W.rafraichir:SetScript("OnClick", function()
		SendWho(W.saisie:GetText())
		W.choisi = nil
	end)
end

S.inscrirePage(2, {
	construire = construire,
	titre = function() return txt("WHO_LIST") end,
	maj = W.maj,
	-- WhoFrame OnShow / OnHide
	montrer = function() SetWhoToUI(1) end,
	cacher = function() SetWhoToUI(0) end,
})

local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("WHO_LIST_UPDATE")
veilleur:SetScript("OnEvent", function()
	if W.liste and W.liste:IsVisible() then W.maj() end
end)
