-- ForeverUI : le chercheur de donjon de WotLK, a la DA du chercheur de groupe
-- de camelot, dans une fenetre deplacable (demande de l'utilisateur,
-- 2026-09-26 ; memoire foreverui-chercheur).
--
-- CAMELOT N'A PAS DE CHERCHEUR DE DONJON : blizzard_groupfinder.toc porte
-- ExcludeLoadGameType camelot. Il charge a la place
-- Blizzard_GroupFinder_VanillaStyle (LFGParentFrame), qui liste des groupes.
-- DECISION DE L'UTILISATEUR : la file de WotLK et ses donnees, presentees
-- comme le LFGParentFrame de camelot ; le navigateur de raid en onglet
-- lateral de la meme fenetre (etape 2).
--
-- RELEVE -- blizzard_groupfinder_vanillastyle/mainline (charge par [Family]) :
-- blizzard_lfgvanilla_parentframe.xml, blizzard_lfgvanilla_listing.xml/.lua,
-- lfgvanilla_constants.lua ; blizzard_sharedxml (PortraitFrameTemplate,
-- InsetFrameTemplate, LargeSideTabButtonTemplate, camelot/nineslicelayout
-- overrides) ; sharedutils.lua (GetTexCoordsForRole,
-- GetBackgroundTexCoordsForRole) :
--   fenetre      458 x 535 ; roche (2,-21 / -2,2), stries (6,-21 / -2,-21),
--                metal du cadre a portrait (coins -13,16 / 2,16 / -13,-8 /
--                2,-8) ; portrait groupfinder-eye-frame 62 x 62 a (-5, 7) ;
--                titre LFG_TITLE, bande (58,-1 / -24,-1), texte TOP (0,-5) ;
--                croix TOPRIGHT (0, 0)
--   roles        bandeau UI-LFG-BlueBG de (2,-25) au TOPRIGHT (248,-169),
--                etire, sans TexCoords ; boutons 64 x 64 a y -41 : tank
--                x 70, soigneur x 174, degats x 278, le quatrieme (celui du
--                nouveau venu, ici le CHEF de WotLK) TOPRIGHT (-20,-41) ; fond
--                UI-LFG-ICONS-ROLEBACKGROUNDS 80 x 80 centre (alpha 0,6 / 0,4
--                / 0,6), icone UI-LFG-ICON-ROLES, voile (0,5) quand le role
--                est refuse ; case UI-CheckBox 24 x 24 a BOTTOMLEFT (-5,-5)
--   encadre      (4,-118 / -4,37), sans marbre ; groupfinder-background de
--                (3,-3) a (-3,3), TexCoords top 0,093
--   categories   (8,-124 / -8,40) ; boutons 380 x 60, le premier a TOP
--                (0,-20), pas de 68 [RESSERRES, voir plus bas] ; image
--                groupfinder-button-* (5,-8 /
--                -5,5), couvercle groupfinder-button-cover, selection et
--                surbrillance PvPMegaQueue 366 x 48 en ADD, texte
--                GameFontNormalLarge a LEFT (20, 0)
--   liste        (7,-125 / -7,40), marge 4, lignes de 22 ; barre a droite
--                (liste a -28 avec, 0 sans) ; ligne : +/- 16 x 16 a LEFT,
--                case 30 x 30 a sa droite (+4), nom, niveau 60 x 22 a RIGHT ;
--                en-tete gris 0,7, entree or, trop facile gris 0,5, trop dur
--                orange (1, 0,5, 0,25)
--   boutons      Back 111 x 28 BOTTOMLEFT (4,6), Post 109 x 28 BOTTOMRIGHT
--                (-4,6)
--   onglets      LargeSideTabButtonTemplate 55 x 55 a TOPLEFT sur TOPRIGHT
--                (0,-60), les suivants 2 plus bas ; icone INV_Helmet_08 pour
--                le premier
--
-- CE QUI VIENT DE WotLK (LFDFrame.lua, LFGFrame.lua) : TOUT ce qui est donnee
-- ou action. Le panneau LFDParentFrame reste celui du client -- le
-- micro-bouton, /lfd, la touche, l'oeil de la minimap, Echap et la
-- conversation d'un PNJ l'ouvrent et le ferment comme avant. Son contenu
-- (LFDQueueFrame) reste affiche mais transparent, SOUS notre fenetre : toute
-- sa logique tourne donc comme prevu (demandes de verrous a l'ouverture,
-- listes filtrees, bouton de recherche, attente, reprise de groupe). Notre
-- fenetre en lit l'etat apres chacune de ses mises a jour, et agit par ses
-- fonctions : LFDQueueFrame_SetType, les cases et les +/- de la liste, les
-- cases de role, le bouton de recherche.
--
-- CORRESPONDANCES (camelot -> WotLK) :
--   categories   le menu "Type" de WotLK : un bouton par donjon aleatoire
--                affichable, puis "Specific Dungeons" (meme ordre, memes
--                refus et meme infobulle) ; le bouton du type choisi porte
--                la selection
--   liste        la liste des donjons specifiques (en-tetes, +/-, cases a
--                trois etats, verrous)
--   details      le texte et les recompenses du donjon aleatoire choisi
--                (texte, recompenses, argent, experience) -- camelot n'en a
--                pas : sous les categories, aux polices de camelot
--   Back         retour aux categories, visible dans la liste seulement ; Post -> le bouton
--                de recherche du client (Find Group / Join as Party / Leave
--                Queue)
--   voiles       l'attente et la desertion, la reprise d'un groupe, "pas de
--                donjon pendant le raid" : ceux de WotLK, sur ce qui suit le
--                choix du type, comme chez WotLK ou le menu "Type" restait
--                accessible -- les details, ou toute la liste
--
-- DEMANDE DE L'UTILISATEUR (2026-09-26, apres la premiere livraison) : les
-- boutons resserres vers le haut (premier a 6 sous le haut de la zone, pas
-- de 62 au lieu de 68), un separateur dessous (le filet de camelot,
-- shop-list-rule), et sous le separateur le texte et les recompenses du
-- bouton choisi. Choisir un donjon aleatoire reste sur la page ; seul
-- "Specific Dungeons" ouvre la liste.
-- PUIS (meme jour) : boutons encore resserres et amincis -- 380 x 40 au
-- lieu de 60, colles (pas de 40), le premier a 4 sous le haut de la zone ;
-- l'image, la selection et la surbrillance suivent la meme proportion
-- (40 / 60) ; filet et details rapproches, ecarts du texte reduits : le
-- but est de loger le texte et les recompenses sans barre. La barre reste,
-- pour le cas qui depasse encore.
-- PUIS : le filet DESCEND sur le contenu. Les details sont poses en bas de
-- l'encadre, a leur hauteur, et le filet juste au-dessus ; il ne monte
-- jamais plus haut que sous le dernier bouton (6 dessous), ou la barre
-- prend le relais.
-- PUIS ("un peu trop descendu, le scroller est reapparu") : trois causes
-- corrigees -- la barre comptait en crans arrondis (contenu vers le haut,
-- zone vers le bas) et apparaissait des qu'une hauteur n'etait pas un
-- multiple de 20 ; la zone visible etait lue par GetHeight juste apres le
-- reancrage, ou le client peut encore rendre l'ancienne ; la hauteur d'un
-- texte replie peut etre sous-estimee a la premiere mesure. Desormais : la
-- zone visible se calcule d'apres nos propres ecarts, 6 d'air au-dessus du
-- contenu, une tolerance de 2, et une seconde mesure a l'image suivante (du
-- haut du contenu au bas de sa derniere piece) qui replace le filet si la
-- premiere etait courte.
-- PUIS : les boutons s'epaississent LEGEREMENT, de 40 a 46 -- la hauteur
-- propre de groupfinder-button-cover, sans etirement vertical -- toujours
-- colles (pas de 46) ; image, selection et surbrillance au prorata (46 /
-- 60). Le filet et les details ne bougent pas : poses sur le contenu.
-- PUIS : les details prennent le decalage des boutons -- 380 de large,
-- centres dans la zone de 442 qui part a 8 : leur bord gauche tombe a
-- 8 + (442 - 380) / 2 = 39, le droit a 39 du bord droit. La barre, si elle
-- vient, se pose 5 a droite.
-- PUIS ("un peu plus") : le bord gauche avance de 6, a 45 ; le droit reste.
-- PUIS : l'argent devient une case comme les objets -- l'icone de pieces
-- de WotLK (inv_misc_coin_02, celle de sa fenetre "donjon pret") et le
-- montant dans le cadre de nom, a la place suivante de la grille.
-- PUIS : filet et details remontes de 5 -- le bas des details passe de 45
-- a 50 au-dessus du bas de la fenetre.
-- PUIS : boutons epaissis de 2, a 48 (pas de 48, selection 38 = 48 x 48 / 60).
-- PUIS ("encore") : 2 de plus, a 50 (pas de 50, selection 40).
--
-- ECARTS SIGNALES : pas de bouton d'options (camelot en a un, rien a y
-- mettre) ; pas de commentaire ni de filet shop-list-rule sous la liste des
-- donjons (WotLK n'a pas de commentaire pour les donjons : la liste descend
-- jusqu'en bas) ; le verrou de WotLK (UI-LFG-ICON-LOCK) prend la place de la
-- case d'un donjon interdit ; pas d'icone heroique sur les en-tetes (leur
-- nom le dit).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local F = {}
ForeverUI.GroupFinder = F

local SEP = string.char(92)
local LFG = "Interface" .. SEP .. "LFGFrame" .. SEP
local BOUTONS = "Interface" .. SEP .. "Buttons" .. SEP

-- une table : Lua 5.1 limite a 60 les valeurs capturees par une fonction
local G = {
	largeur = 458, hauteur = 535,
	roche = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock",
	portraitCote = 62, portraitX = -5, portraitY = 7,
	titreX1 = 58, titreX2 = -24, titreY = -1, titreH = 20, titreTexteY = -5,
	croix = 24, croixX = 0, croixY = 0,
	bleu = "interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP .. "ui-lfg-bluebg",
	bleuX1 = 2, bleuY1 = -25, bleuX2 = 248, bleuY2 = -169,
	role = 64, roleY = -41, roleFond = 80, caseRole = 24, caseRoleX = -5, caseRoleY = -5,
	roleIcones = LFG .. "UI-LFG-ICON-ROLES",
	roleFonds = LFG .. "UI-LFG-ICONS-ROLEBACKGROUNDS",
	encadreX1 = 4, encadreY1 = -118, encadreX2 = -4, encadreY2 = 37,
	fondHaut = 0.093,
	catX1 = 8, catY1 = -124, catX2 = -8, catY2 = 40, catPremier = -4, catPas = 50,
	-- le filet sous les boutons, puis les details
	regleEcart = 6, regleH = 16, detailsEcart = 6, detailsAir = 6, tolerance = 2, detailsX1 = 45, detailsX2 = -39, detailsBas = 50,
	cran = 20,
	catL = 380, catH = 50, catSelL = 366, catSelH = 40,
	-- l'image dans le bouton : (5,-8 / -5,5) de camelot, ramenes a 50 de haut
	catImageHaut = -6, catImageBas = 4,
	mega = "interface" .. SEP .. "ForeverUI" .. SEP .. "pvpframe" .. SEP .. "pvpmegaqueue",
	pieces = "Interface" .. SEP .. "Icons" .. SEP .. "inv_misc_coin_02",
	listeX1 = 7, listeY1 = -125, listeX2 = -7, listeY2 = 40, marge = 4, barreDroite = -28,
	ligne = 22, plus = 16, case = 30, niveauL = 60,
	backL = 111, postL = 109, boutonH = 28, boutonBas = 6, boutonCote = 4,
	onglet = 55, ongletY = -60, ongletEcart = -2, ongletIcone = 50, ongletIconeX = -3, rognage = 0.03125,
	voileL = 330, voileH = 257,
}

-- les coordonnees de sharedutils.lua (GetTexCoordsForRole : 256 x 256,
-- cases de 67 ; GetBackgroundTexCoordsForRole : 256 x 128, cases de 75)
local ROLES = {
	{ cle = "tank", client = "LFDQueueFrameRoleButtonTank", id = 2, x = 70, alpha = 0.6,
		icone = { 0, 0.26171875, 0.26171875, 0.5234375 }, fond = { 0.29296875, 0.5859375, 0, 0.5859375 } },
	{ cle = "soin", client = "LFDQueueFrameRoleButtonHealer", id = 3, x = 174, alpha = 0.4,
		icone = { 0.26171875, 0.5234375, 0, 0.26171875 }, fond = { 0, 0.29296875, 0, 0.5859375 } },
	{ cle = "degats", client = "LFDQueueFrameRoleButtonDPS", id = 1, x = 278, alpha = 0.6,
		icone = { 0.26171875, 0.5234375, 0.26171875, 0.5234375 }, fond = { 0.5859375, 0.87890625, 0, 0.5859375 } },
	-- le quatrieme emplacement de camelot (TOPRIGHT -20,-41), sans fond
	{ cle = "chef", client = "LFDQueueFrameRoleButtonLeader", id = 4, droite = -20,
		icone = { 0, 0.26171875, 0, 0.26171875 } },
}
local VOILE_ROLE = { 0, 0.2617, 0.5234, 0.7851 }

-- les polices de fontstyles.xml (LFGActivityHeader, LFGActivityEntry...)
local COULEURS = {
	entete = { 0.7, 0.7, 0.7 },
	entree = { 1.0, 0.82, 0 },
	facile = { 0.5, 0.5, 0.5 },
	dur = { 1.0, 0.5, 0.25 },
}

-- l'image d'un bouton de categorie
local ART = {
	aleatoire = "groupfinder-button-dungeons",
	fete = "groupfinder-button-questing",
	specifique = "groupfinder-button-custom-pve",
}

local function txt(cle)
	return _G[cle] or cle
end

-- 3.3.5 rend 1 ou nil (et le banc 0 ou 1) : on compare
local function actif(b)
	return b ~= nil and b.IsEnabled ~= nil and b:IsEnabled() == 1
end

-- visible pour de bon : le cadre et ses parents jusqu'au panneau
local function affiche(c)
	while c do
		if not c:IsShown() then return false end
		if c == LFDParentFrame then return true end
		c = c:GetParent()
	end
	return false
end

-- ------------------------------------------------------------------ le cadre

local METAL = {
	{ cle = "hg", nom = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ cle = "hd", nom = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ cle = "bg", nom = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ cle = "bd", nom = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

local function croixRouge(b)
	for _, etat in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(etat[3])
		b[etat[1]](b, e and e[1] or "")
		local t = b[etat[2]](b)
		if t then
			ForeverUI.SetAtlas(t, etat[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
			if etat[3] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
end

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

	-- le portrait : l'oeil de camelot (SetPortraitAtlasRaw, 62 x 62)
	local cadrePortrait = CreateFrame("Frame", nil, f)
	cadrePortrait:SetAllPoints(f)
	cadrePortrait:SetFrameLevel(f:GetFrameLevel() + 19)
	local portrait = cadrePortrait:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(portrait, "groupfinder-eye-frame", true)
	portrait:SetWidth(G.portraitCote)
	portrait:SetHeight(G.portraitCote)
	portrait:SetPoint("TOPLEFT", f, "TOPLEFT", G.portraitX, G.portraitY)
	f.portrait = portrait

	local bandeau = CreateFrame("Frame", nil, f)
	bandeau:SetFrameLevel(f:GetFrameLevel() + 21)
	bandeau:SetHeight(G.titreH)
	bandeau:SetPoint("TOPLEFT", f, "TOPLEFT", G.titreX1, G.titreY)
	bandeau:SetPoint("TOPRIGHT", f, "TOPRIGHT", G.titreX2, G.titreY)
	f.titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.titre:SetPoint("TOP", bandeau, "TOP", 0, G.titreTexteY)
	f.titre:SetText(txt("LFG_TITLE"))
	f.bandeau = bandeau

	-- LA CROIX : elle ferme le panneau du client, comme la sienne
	local croix = CreateFrame("Button", "ForeverUIGroupFinderCloseButton", f)
	croix:SetWidth(G.croix)
	croix:SetHeight(G.croix)
	croix:SetFrameLevel(f:GetFrameLevel() + 22)
	croix:SetPoint("TOPRIGHT", f, "TOPRIGHT", G.croixX, G.croixY)
	croixRouge(croix)
	croix:SetScript("OnClick", function() HideUIPanel(LFDParentFrame) end)
	f.croix = croix
end

-- ------------------------------------------------------------ les onglets
-- LargeSideTabButtonTemplate, comme ceux de la feuille (CharacterFrame.lua) :
-- fond common-sidetab, icone cuite par tools/cuire_masque.py a 50 x 50 en
-- (-3, 0) rognee de 0,03125, marqueur common-sidetab-selected, survol
-- common-sidetab-hover.
local ONGLETS = {
	{ cle = "donjons", texte = "LOOKING_FOR_DUNGEON",
		icone = "Interface" .. SEP .. "ForeverUI" .. SEP .. "tabicons" .. SEP .. "inv_helmet_08" },
}

local function creerOnglet(f, def, n)
	local o = CreateFrame("Button", "ForeverUIGroupFinderTab" .. n, f)
	o:SetWidth(G.onglet)
	o:SetHeight(G.onglet)
	local fond = o:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "common-sidetab", true)
	fond:SetAllPoints(o)
	local icone = o:CreateTexture(nil, "ARTWORK")
	icone:SetWidth(G.ongletIcone)
	icone:SetHeight(G.ongletIcone)
	icone:SetPoint("CENTER", o, "CENTER", G.ongletIconeX, 0)
	icone:SetTexCoord(G.rognage, 1 - G.rognage, G.rognage, 1 - G.rognage)
	icone:SetTexture(def.icone)
	o.icone = icone
	local choisi = o:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(choisi, "common-sidetab-selected", true)
	choisi:SetAllPoints(o)
	choisi:Hide()
	o.choisi = choisi
	local survol = o:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(survol, "common-sidetab-hover", true)
	survol:SetAllPoints(o)
	o:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
		GameTooltip:SetText(txt(def.texte))
		GameTooltip:Show()
	end)
	o:SetScript("OnLeave", function() GameTooltip:Hide() end)
	o:SetScript("OnClick", function()
		PlaySound("igCharacterInfoTab")
		F.choisirOnglet(def.cle)
	end)
	o.cle = def.cle
	return o
end

function F.choisirOnglet(cle)
	F.onglet = cle
	for _, o in ipairs(F.onglets or {}) do
		if o.cle == cle then o.choisi:Show() else o.choisi:Hide() end
	end
end

-- ------------------------------------------------------------ les roles

local function creerRole(parent, r)
	local b = CreateFrame("Button", "ForeverUIGroupFinderRole" .. r.cle, parent)
	b:SetWidth(G.role)
	b:SetHeight(G.role)
	if r.droite then
		b:SetPoint("TOPRIGHT", F.cadre, "TOPRIGHT", r.droite, G.roleY)
	else
		b:SetPoint("TOPLEFT", F.cadre, "TOPLEFT", r.x, G.roleY)
	end
	if r.fond then
		local fond = b:CreateTexture(nil, "BACKGROUND")
		fond:SetTexture(G.roleFonds)
		fond:SetTexCoord(r.fond[1], r.fond[2], r.fond[3], r.fond[4])
		fond:SetWidth(G.roleFond)
		fond:SetHeight(G.roleFond)
		fond:SetPoint("CENTER", b, "CENTER", 0, 0)
		fond:SetAlpha(r.alpha)
		b.fond = fond
	end
	local icone = b:CreateTexture(nil, "ARTWORK")
	icone:SetTexture(G.roleIcones)
	icone:SetTexCoord(r.icone[1], r.icone[2], r.icone[3], r.icone[4])
	icone:SetAllPoints(b)
	b.icone = icone
	local voile = b:CreateTexture(nil, "OVERLAY")
	voile:SetTexture(G.roleIcones)
	voile:SetTexCoord(VOILE_ROLE[1], VOILE_ROLE[2], VOILE_ROLE[3], VOILE_ROLE[4])
	voile:SetAllPoints(b)
	voile:SetAlpha(0.5)
	voile:Hide()
	b.voile = voile

	local c = CreateFrame("CheckButton", "ForeverUIGroupFinderRole" .. r.cle .. "Check", b)
	c:SetWidth(G.caseRole)
	c:SetHeight(G.caseRole)
	c:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", G.caseRoleX, G.caseRoleY)
	c:SetNormalTexture(BOUTONS .. "UI-CheckBox-Up")
	c:SetPushedTexture(BOUTONS .. "UI-CheckBox-Down")
	c:SetHighlightTexture(BOUTONS .. "UI-CheckBox-Highlight")
	local s = c:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	c:SetCheckedTexture(BOUTONS .. "UI-CheckBox-Check")
	c:SetDisabledCheckedTexture(BOUTONS .. "UI-CheckBox-Check-Disabled")
	b.case = c

	-- LA CASE DU CLIENT FAIT LE TRAVAIL : son Click la bascule et joue son
	-- OnClick (son, LFDQueueFrame_SetRoles). La notre suit ensuite.
	c:SetScript("OnClick", function(self)
		local client = _G[r.client]
		self:SetChecked(not self:GetChecked())
		if client and client.checkButton and actif(client.checkButton) then
			client.checkButton:Click()
		end
		F.majRoles()
	end)
	b:SetScript("OnClick", function()
		if actif(c) then c:Click() end
	end)
	b:SetScript("OnEnter", function(self)
		local client = _G[r.client]
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if r.cle == "chef" then
			GameTooltip:SetText(txt("GUIDE_TOOLTIP"), nil, nil, nil, nil, 1)
		else
			GameTooltip:SetText(txt("ROLE_DESCRIPTION" .. r.id), nil, nil, nil, nil, 1)
			if client and client.permDisabled then
				local rouge = RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }
				GameTooltip:AddLine(txt("YOUR_CLASS_MAY_NOT_PERFORM_ROLE"), rouge.r, rouge.g, rouge.b, 1)
			end
		end
		GameTooltip:Show()
		if actif(c) then c:LockHighlight() end
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
		c:UnlockHighlight()
	end)
	b.def = r
	return b
end

-- l'etat de chaque bouton de role du client, recopie
function F.majRoles()
	for _, b in ipairs(F.roles or {}) do
		local client = _G[b.def.client]
		if client and client.checkButton then
			b.case:SetChecked(client.checkButton:GetChecked())
			if client.checkButton:IsShown() then b.case:Show() else b.case:Hide() end
			if actif(client.checkButton) then b.case:Enable() else b.case:Disable() end
			if client.cover and client.cover:IsShown() then
				b.voile:SetAlpha(client.cover:GetAlpha())
				b.voile:Show()
			else
				b.voile:Hide()
			end
			if b.fond then
				if client.background and client.background:IsShown() then b.fond:Show() else b.fond:Hide() end
			end
			b.icone:SetDesaturated(client.permDisabled and true or false)
		end
	end
end

-- ------------------------------------------------------------ les categories

-- isRandomDungeonDisplayable de LFDFrame.lua (locale au client)
local function aleatoireAffichable(id)
	local _, _, minimum, maximum, _, _, _, extension = GetLFGDungeonInfo(id)
	local niveau = UnitLevel("player")
	local ext = (GetExpansionLevel and GetExpansionLevel()) or 2
	return minimum and niveau >= minimum and niveau <= maximum and ext >= (extension or 0)
end

-- LFDQueueFrameTypeDropDown_Initialize : "specific" d'abord, puis chaque
-- aleatoire affichable, rejoignable ou non
function F.categories()
	local l = { { valeur = "specific", texte = txt("SPECIFIC_DUNGEONS"), art = ART.specifique, dispo = true } }
	for i = 1, (GetNumRandomDungeons and GetNumRandomDungeons() or 0) do
		local id, nom = GetLFGRandomDungeonInfo(i)
		if id and aleatoireAffichable(id) then
			local fete = select(14, GetLFGDungeonInfo(id))
			table.insert(l, { valeur = id, texte = nom, art = fete and ART.fete or ART.aleatoire,
				dispo = IsLFGDungeonJoinable(id) and true or false })
		end
	end
	return l
end

local function creerCategorie(ligne)
	local b = CreateFrame("Button", nil, ligne)
	b:SetWidth(G.catL)
	b:SetHeight(G.catH)
	b:SetPoint("TOP", ligne, "TOP", 0, 0)
	local image = b:CreateTexture(nil, "BACKGROUND")
	image:SetPoint("TOPLEFT", b, "TOPLEFT", 5, G.catImageHaut)
	image:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, G.catImageBas)
	b.image = image
	local couvercle = b:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(couvercle, "groupfinder-button-cover", true)
	couvercle:SetAllPoints(b)
	local choix = b:CreateTexture(nil, "OVERLAY")
	choix:SetTexture(G.mega)
	choix:SetTexCoord(0.00195313, 0.63867188, 0.76953125, 0.83007813)
	choix:SetBlendMode("ADD")
	choix:SetWidth(G.catSelL)
	choix:SetHeight(G.catSelH)
	choix:SetPoint("CENTER", b, "CENTER", 0, 0)
	choix:Hide()
	b.choix = choix
	b:SetHighlightTexture(G.mega)
	local s = b:GetHighlightTexture()
	if s then
		s:SetTexCoord(0.00195313, 0.63867188, 0.70703125, 0.76757813)
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetWidth(G.catSelL)
		s:SetHeight(G.catSelH)
		s:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
	local texte = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	texte:SetPoint("LEFT", b, "LEFT", 20, 0)
	texte:SetJustifyH("LEFT")
	b.texte = texte
	b:SetScript("OnClick", function(self)
		local c = self.categorie
		if not c or not c.dispo then return end
		PlaySound("igMainMenuOptionCheckBoxOn")
		LFDQueueFrame_SetType(c.valeur)
		F.vue = (c.valeur == "specific") and "liste" or "categories"
		F.maj()
	end)
	b:SetScript("OnEnter", function(self)
		local c = self.categorie
		if c and not c.dispo then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(txt("YOU_MAY_NOT_QUEUE_FOR_THIS"), 1, 1, 1)
			local raison = LFDConstructDeclinedMessage and LFDConstructDeclinedMessage(c.valeur)
			if raison then GameTooltip:AddLine(raison, nil, nil, nil, 1) end
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	ligne.bouton = b
end

local function remplirCategorie(ligne, index)
	local c = F.liste_categories[index]
	local b = ligne.bouton
	b.categorie = c
	ForeverUI.SetAtlas(b.image, c.art, true)
	b.image:SetDesaturated(not c.dispo)
	b.texte:SetText(c.texte)
	if c.dispo then
		b.texte:SetTextColor(1, 0.82, 0)
	else
		b.texte:SetTextColor(0.5, 0.5, 0.5)
	end
	if LFDQueueFrame.type == c.valeur then b.choix:Show() else b.choix:Hide() end
end

-- ------------------------------------------------------------ la liste

local function creerLigne(ligne)
	local plus = CreateFrame("Button", nil, ligne)
	plus:SetWidth(G.plus)
	plus:SetHeight(G.plus)
	plus:SetPoint("LEFT", ligne, "LEFT", 0, 0)
	plus:SetHitRectInsets(1, -4, -2, -2)
	plus:SetNormalTexture(BOUTONS .. "UI-MinusButton-UP")
	local n = plus:GetNormalTexture()
	if n then
		n:ClearAllPoints()
		n:SetWidth(20)
		n:SetHeight(20)
		n:SetPoint("LEFT", plus, "LEFT", 3, 0)
	end
	plus:SetHighlightTexture(BOUTONS .. "UI-PlusButton-Hilight")
	local s = plus:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetWidth(20)
		s:SetHeight(20)
		s:SetPoint("LEFT", plus, "LEFT", 3, 0)
	end
	-- le +/- du client : LFDQueueFrameExpandOrCollapseButton_OnClick lit
	-- self:GetParent().id et .isCollapsed
	plus:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		LFDQueueFrameExpandOrCollapseButton_OnClick(self)
	end)
	ligne.plus = plus

	local c = CreateFrame("CheckButton", nil, ligne)
	c:SetWidth(G.case)
	c:SetHeight(G.case)
	c:SetPoint("LEFT", plus, "RIGHT", 4, 0)
	c:SetNormalTexture(BOUTONS .. "UI-CheckBox-Up")
	c:SetPushedTexture(BOUTONS .. "UI-CheckBox-Down")
	c:SetHighlightTexture(BOUTONS .. "UI-CheckBox-Highlight")
	local h = c:GetHighlightTexture()
	if h then h:SetBlendMode("ADD") end
	c:SetCheckedTexture(BOUTONS .. "UI-CheckBox-Check")
	c:SetDisabledCheckedTexture(BOUTONS .. "UI-CheckBox-Check-Disabled")
	-- la case du client : LFDQueueFrameDungeonChoiceEnableButton_OnClick lit
	-- self:GetParent().id et self:GetChecked()
	c:SetScript("OnClick", function(self)
		LFDQueueFrameDungeonChoiceEnableButton_OnClick(self)
	end)
	ligne.case = c

	-- le verrou de WotLK, a la place de la case
	local verrou = ligne:CreateTexture(nil, "ARTWORK")
	verrou:SetTexture(LFG .. "UI-LFG-ICON-LOCK")
	verrou:SetTexCoord(0, 0.71875, 0, 0.875)
	verrou:SetWidth(12)
	verrou:SetHeight(14)
	verrou:SetPoint("CENTER", c, "CENTER", 0, 0)
	verrou:Hide()
	ligne.lockedIndicator = verrou

	local niveau = ligne:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	niveau:SetWidth(G.niveauL)
	niveau:SetHeight(G.ligne)
	niveau:SetPoint("RIGHT", ligne, "RIGHT", 0, 0)
	niveau:SetJustifyH("LEFT")
	ligne.niveau = niveau

	local nom = ligne:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	nom:SetHeight(G.ligne)
	nom:SetPoint("LEFT", c, "RIGHT", 0, 0)
	nom:SetPoint("RIGHT", niveau, "LEFT", -4, 0)
	nom:SetJustifyH("LEFT")
	ligne.nom = nom

	-- le nom clique la case, et la survole (NameButton de camelot) ;
	-- l'infobulle des verrous est celle du client
	ligne:EnableMouse(true)
	ligne:SetScript("OnEnter", function(self)
		if actif(self.case) and self.case:IsShown() then self.case:LockHighlight() end
		LFDQueueFrameDungeonListButton_OnEnter(self)
	end)
	ligne:SetScript("OnLeave", function(self)
		self.case:UnlockHighlight()
		GameTooltip:Hide()
	end)
	ligne:SetScript("OnClick", function(self)
		if self.case:IsShown() and actif(self.case) then self.case:Click() end
	end)
end

local function couleur(fs, c)
	fs:SetTextColor(c[1], c[2], c[3])
end

-- LFDQueueFrameSpecificListButton_SetDungeon, a la maniere de camelot
local function remplirLigne(ligne, index)
	local id = LFDDungeonList[index]
	local info = LFGDungeonInfo and LFGDungeonInfo[id] or {}
	local mode = GetLFGMode()
	local fige = mode == "rolecheck" or mode == "queued" or mode == "listed" or not LFD_IsEmpowered()
	ligne.id = id
	ligne.nom:SetText(info[1] or "")
	if id < 0 then
		ligne.plus:Show()
		ligne.isCollapsed = LFGCollapseList[id]
		ligne.plus:SetNormalTexture(BOUTONS .. (ligne.isCollapsed and "UI-PlusButton-UP" or "UI-MinusButton-UP"))
		local n = ligne.plus:GetNormalTexture()
		if n then
			n:ClearAllPoints()
			n:SetWidth(20)
			n:SetHeight(20)
			n:SetPoint("LEFT", ligne.plus, "LEFT", 3, 0)
		end
		ligne.niveau:Hide()
		couleur(ligne.nom, COULEURS.entete)
	else
		ligne.plus:Hide()
		ligne.isCollapsed = false
		local minimum, maximum = info[3] or 0, info[4] or 0
		if minimum == maximum then
			ligne.niveau:SetText(format(txt("LFD_LEVEL_FORMAT_SINGLE"), minimum))
		else
			ligne.niveau:SetText(format(txt("LFD_LEVEL_FORMAT_RANGE"), minimum, maximum))
		end
		ligne.niveau:Show()
		local joueur = UnitLevel("player")
		local c = COULEURS.entree
		if maximum ~= 0 and maximum < joueur then
			c = COULEURS.facile
		elseif minimum ~= 0 and minimum > joueur then
			c = COULEURS.dur
		end
		couleur(ligne.niveau, c)
		couleur(ligne.nom, fige and COULEURS.entete or c)
	end

	if LFGLockList[id] then
		ligne.case:Hide()
		ligne.lockedIndicator:Show()
	else
		ligne.case:Show()
		ligne.lockedIndicator:Hide()
	end
	local etat
	if mode == "queued" or mode == "listed" then
		etat = LFGQueuedForList[id]
	else
		etat = LFGEnabledList[id]
	end
	if etat == 1 then
		ligne.case:SetCheckedTexture(BOUTONS .. "UI-MultiCheck-Up")
		ligne.case:SetDisabledCheckedTexture(BOUTONS .. "UI-MultiCheck-Disabled")
	else
		ligne.case:SetCheckedTexture(BOUTONS .. "UI-CheckBox-Check")
		ligne.case:SetDisabledCheckedTexture(BOUTONS .. "UI-CheckBox-Check-Disabled")
	end
	ligne.case:SetChecked(etat and etat ~= 0)
	if fige then ligne.case:Disable() else ligne.case:Enable() end
end

-- ------------------------------------------------------------ les recompenses

local OBJETS = "LFDQueueFrameRandomScrollFrameChildFrameItem"

local function creerObjet(parent, i)
	local b = CreateFrame("Button", "ForeverUIGroupFinderReward" .. i, parent)
	b:SetWidth(147)
	b:SetHeight(41)
	local icone = b:CreateTexture(nil, "BORDER")
	icone:SetWidth(39)
	icone:SetHeight(39)
	icone:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.icone = icone
	local cadreNom = b:CreateTexture(nil, "BACKGROUND")
	cadreNom:SetTexture("Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestItemNameFrame")
	cadreNom:SetWidth(128)
	cadreNom:SetHeight(64)
	cadreNom:SetPoint("LEFT", icone, "RIGHT", -10, 0)
	local nom = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	nom:SetWidth(90)
	nom:SetHeight(36)
	nom:SetPoint("LEFT", icone, "RIGHT", 8, 0)
	nom:SetJustifyH("LEFT")
	b.nom = nom
	local nombre = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	nombre:SetPoint("BOTTOMRIGHT", icone, "BOTTOMRIGHT", -5, 2)
	b.nombre = nombre
	b:SetID(i)
	-- LFDRandomDungeonLootTemplate
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetLFGDungeonReward(LFDQueueFrame.type, self:GetID())
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		HandleModifiedItemClick(GetLFGDungeonRewardLink(LFDQueueFrame.type, self:GetID()))
	end)
	return b
end

-- LES DETAILS : une zone qui defile sous le filet. Chaque piece est posee
-- a sa hauteur depuis le haut du contenu (et non d'une piece a l'autre) :
-- la hauteur totale en sort, et la barre la suit.
local function construireRecompenses(p)
	local vue = CreateFrame("ScrollFrame", "ForeverUIGroupFinderDetails", p)
	vue.decalage = 0
	local r = CreateFrame("Frame", "ForeverUIGroupFinderRewards", vue)
	r:SetWidth(G.largeur + G.detailsX2 - G.detailsX1)
	r:SetHeight(1)
	vue:SetScrollChild(r)
	local largeur = G.largeur + G.detailsX2 - G.detailsX1
	local function texte(police)
		local fs = r:CreateFontString(nil, "ARTWORK", police)
		fs:SetWidth(largeur)
		fs:SetJustifyH("LEFT")
		return fs
	end
	r.description = texte("GameFontHighlight")
	r.etiquette = texte("GameFontNormalLarge")
	r.etiquette:SetText(txt("LFD_REWARDS"))
	r.explication = texte("GameFontHighlight")
	r.pug = texte("GameFontHighlight")
	-- l'argent : une case d'objet, sans infobulle ni lien
	local argent = creerObjet(r, 0)
	argent:SetScript("OnEnter", nil)
	argent:SetScript("OnLeave", nil)
	argent:SetScript("OnClick", nil)
	argent.icone:SetTexture(G.pieces)
	argent.nombre:Hide()
	r.argent = argent
	r.xp = texte("GameFontNormal")
	r.objets = {}
	F.recompenses = r

	local barre = ForeverUI.CreateScrollBar("ForeverUIGroupFinderDetailsScrollBar", p, vue)
	barre.surDefilement = function(nouveau)
		vue.decalage = nouveau
		vue:SetVerticalScroll(math.min(nouveau * G.cran, math.max(0, (vue.contenu or 0) - (vue.visible or 0))))
	end
	vue:EnableMouseWheel(true)
	vue:SetScript("OnMouseWheel", function(self, sens)
		barre:Deplacer(self.decalage - sens)
	end)
	vue.barre = barre
	F.details = vue

	-- LA SECONDE MESURE, a l'image suivante : du haut du contenu au bas de
	-- sa derniere piece. Plus haute que la premiere, elle replace tout.
	local remesure = CreateFrame("Frame")
	remesure:Hide()
	remesure:SetScript("OnUpdate", function(self)
		self:Hide()
		local piece = F.dernierePiece
		if not (vue:IsShown() and piece and piece:IsShown()) then return end
		local haut, bas = r:GetTop(), piece:GetBottom()
		if not (haut and bas) then return end
		local reel = haut - bas
		if reel > (vue.contenu or 0) + 0.5 then F.poserContenu(reel) end
	end)
	F.remesure = remesure
end

-- LE FILET ET LES DETAILS. Les details finissent en bas de l'encadre ; le
-- filet se pose au-dessus de leur contenu, sans monter plus haut que
-- F.filetMax (6 sous le dernier bouton). Sans contenu, il reste la-haut.
local function placerFilet(contenu)
	local y = F.filetMax or 0
	if contenu and contenu > 0 then
		local voulu = -(G.hauteur - G.detailsBas) + contenu + G.detailsAir + G.detailsEcart + G.regleH / 2
		if voulu < y then y = voulu end
	end
	-- la hauteur visible des details, d'apres nos ecarts et non GetHeight
	F.details.visible = (y - G.regleH / 2 - G.detailsEcart) + (G.hauteur - G.detailsBas)
	F.regle:ClearAllPoints()
	F.regle:SetPoint("LEFT", F.cadre, "TOPLEFT", G.listeX1, y)
	F.regle:SetPoint("RIGHT", F.cadre, "TOPRIGHT", G.listeX2, y)
	F.details:ClearAllPoints()
	F.details:SetPoint("TOPLEFT", F.cadre, "TOPLEFT", G.detailsX1, y - G.regleH / 2 - G.detailsEcart)
	F.details:SetPoint("BOTTOMRIGHT", F.cadre, "BOTTOMRIGHT", G.detailsX2, G.detailsBas)
	-- les voiles des details partent du filet
	F.hautDetails = y - G.regleH / 2 - G.encadreY1
end

-- la hauteur d'un texte replie sur sa largeur : GetHeight, comme
-- QuestInfo.lua du client
local function hauteur(fs)
	local h = fs:GetHeight() or 0
	if h <= 0 and fs.GetStringHeight then h = fs:GetStringHeight() or 0 end
	return h
end

-- LFDQueueFrameRandom_UpdateFrame a pose les textes sur les regions du
-- client : on les reprend. Le titre n'est pas repris : le bouton choisi le
-- porte deja.
local function majRecompenses()
	local r = F.recompenses
	local vue = F.details
	local client = LFDQueueFrameRandomScrollFrameChildFrame
	local id = LFDQueueFrame.type
	if not client or type(id) ~= "number" then
		placerFilet(nil)
		vue:Hide()
		vue.barre:Hide()
		return
	end
	vue:Show()
	local y = 0
	local dernier
	local function poser(piece, x, ecart)
		piece:ClearAllPoints()
		piece:SetPoint("TOPLEFT", r, "TOPLEFT", x or 0, -(y + (ecart or 0)))
		piece:Show()
		y = y + (ecart or 0) + hauteur(piece)
		dernier = piece
	end
	r.description:SetText(client.description:GetText() or "")
	poser(r.description)
	if client.rewardsLabel:IsShown() then
		r.explication:SetText(client.rewardsDescription:GetText() or "")
		poser(r.etiquette, 0, 10)
		poser(r.explication, 0, 6)
	else
		r.etiquette:Hide()
		r.explication:Hide()
	end
	local _, argentBase, argentVar, xpBase, xpVar, nombre = GetLFGDungeonRewards(id)
	nombre = nombre or 0
	-- l'argent et l'experience : le calcul de LFDQueueFrameRandom_UpdateFrame
	local aleas = 4 - GetNumPartyMembers()
	local argent = (argentBase or 0) + (argentVar or 0) * aleas
	local xp = (xpBase or 0) + (xpVar or 0) * aleas
	local haut = y + 8
	local function case(b, i)
		local rang, colonne = math.floor((i - 1) / 2), (i - 1) % 2
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", r, "TOPLEFT", colonne * 157, -(haut + rang * 44))
		b:Show()
		y = haut + rang * 44 + 41
		dernier = b
	end
	for i = 1, nombre do
		local b = r.objets[i] or creerObjet(r, i)
		r.objets[i] = b
		local nom, image, quantite = GetLFGDungeonRewardInfo(id, i)
		b.nom:SetText(nom or "")
		b.icone:SetTexture(image)
		if quantite and quantite > 1 then b.nombre:SetText(quantite) b.nombre:Show() else b.nombre:Hide() end
		case(b, i)
	end
	for i = nombre + 1, #r.objets do r.objets[i]:Hide() end
	if argent > 0 then
		r.argent.nom:SetText(GetCoinTextureString(argent))
		case(r.argent, nombre + 1)
	else
		r.argent:Hide()
	end
	if client.pugDescription:IsShown() then
		r.pug:SetText(client.pugDescription:GetText() or "")
		poser(r.pug, 0, 5)
	else
		r.pug:Hide()
	end
	if xp > 0 then
		r.xp:SetText(txt("EXPERIENCE_COLON") .. " |cffffffff" .. xp .. "|r")
		poser(r.xp, 0, 8)
	else
		r.xp:Hide()
	end
	-- le filet descend sur le contenu ; puis la barre
	F.dernierePiece = dernier
	F.poserContenu(y)
	-- la seconde mesure, une fois les textes poses par le client
	F.remesure:Show()
end

function F.poserContenu(y)
	local vue = F.details
	F.recompenses:SetHeight(math.max(1, y))
	vue.contenu = y
	placerFilet(y)
	local visible = vue.visible or 0
	if visible <= 0 or y <= visible + G.tolerance then
		vue.decalage = 0
		vue:SetVerticalScroll(0)
		vue.barre:Regler(0, 0, 0)
	else
		-- en crans de 20 : le dernier cran montre la fin du contenu
		local total, visibles = math.ceil((y - visible) / G.cran) + 1, 1
		vue.decalage = math.min(vue.decalage, total - visibles)
		vue.barre:Regler(total, visibles, vue.decalage)
		vue.barre.surDefilement(vue.decalage)
	end
end

-- ------------------------------------------------------------ les voiles
-- Ceux de WotLK (330 x 257, noir a 0,93), poses sur l'encadre et dans le
-- meme ordre : l'attente (11), la reprise d'un groupe (14), "pas de donjon
-- pendant le raid" (16).

local function creerVoile(nom, niveau)
	local v = CreateFrame("Frame", nom, F.pageDonjons)
	v:SetFrameLevel(F.encadre:GetFrameLevel() + niveau)
	v:EnableMouse(true)
	local noir = v:CreateTexture(nil, "BACKGROUND")
	noir:SetTexture(0, 0, 0, 0.93)
	noir:SetAllPoints(v)
	v.description = v:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	v.description:SetWidth(300)
	v.description:SetPoint("TOP", v, "TOP", 0, -70)
	v:Hide()
	return v
end

local function construireVoiles()
	local attente = creerVoile("ForeverUIGroupFinderCooldown", 11)
	attente.temps = attente:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	attente.temps:SetPoint("TOP", attente.description, "BOTTOM", 0, -10)
	attente.noms, attente.etats = {}, {}
	for i = 1, 4 do
		local n = attente:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		n:SetWidth(120)
		n:SetJustifyH("LEFT")
		if i == 1 then
			n:SetPoint("TOPLEFT", attente.description, "BOTTOMLEFT", 25, -60)
		else
			n:SetPoint("TOP", attente.noms[i - 1], "BOTTOM", 0, -5)
		end
		local e = attente:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		e:SetWidth(110)
		e:SetJustifyH("RIGHT")
		e:SetPoint("TOPLEFT", n, "TOPRIGHT", 0, 0)
		attente.noms[i], attente.etats[i] = n, e
	end
	-- le temps restant change a chaque image chez le client
	attente:SetScript("OnUpdate", function(self)
		local c = LFDQueueFrameCooldownFrame
		if c and c.time then
			self.temps:SetText(c.time:GetText() or "")
		end
	end)
	F.attente = attente

	local reprise = creerVoile("ForeverUIGroupFinderBackfill", 14)
	reprise.oui = ForeverUI.CreatePanelButton(reprise, txt("YES"), 153, 22, nil, "GameFontNormal")
	reprise.oui:SetPoint("TOPRIGHT", reprise.description, "BOTTOM", -5, -10)
	reprise.oui:SetScript("OnClick", function()
		if LFDQueueFramePartyBackfillBackfillButton then LFDQueueFramePartyBackfillBackfillButton:Click() end
	end)
	reprise.non = ForeverUI.CreatePanelButton(reprise, txt("HIDE"), 153, 22, nil, "GameFontNormal")
	reprise.non:SetPoint("TOPLEFT", reprise.description, "BOTTOM", 5, -10)
	reprise.non:SetScript("OnClick", function()
		if LFDQueueFramePartyBackfillNoBackfillButton then LFDQueueFramePartyBackfillNoBackfillButton:Click() end
	end)
	F.reprise = reprise

	local raid = creerVoile("ForeverUIGroupFinderNoLFDWhileLFR", 16)
	raid.quitter = ForeverUI.CreatePanelButton(raid, "", 153, 22, nil, "GameFontNormal")
	raid.quitter:SetPoint("TOP", raid.description, "BOTTOM", 0, -10)
	raid.quitter:SetScript("OnClick", function()
		if LFDQueueFrameNoLFDWhileLFRLeaveQueueButton then LFDQueueFrameNoLFDWhileLFRLeaveQueueButton:Click() end
	end)
	F.raid = raid
end

local function texteDe(nom)
	local r = _G[nom]
	return r and r.GetText and r:GetText() or ""
end

-- ce qu'ils couvrent : les details sous le filet, ou toute la liste
local function placerVoiles()
	for _, v in ipairs({ F.attente, F.reprise, F.raid }) do
		v:ClearAllPoints()
		if F.vue == "liste" then
			v:SetAllPoints(F.encadre)
		else
			v:SetPoint("TOPLEFT", F.encadre, "TOPLEFT", 0, F.hautDetails)
			v:SetPoint("BOTTOMRIGHT", F.encadre, "BOTTOMRIGHT", 0, 0)
		end
	end
end

local function majVoiles()
	placerVoiles()
	-- l'attente : visible chez le client (son parent change selon la
	-- desertion), textes recopies
	local c = LFDQueueFrameCooldownFrame
	if c and affiche(c) then
		F.attente.description:SetText(c.description and c.description:GetText() or "")
		F.attente.description:ClearAllPoints()
		F.attente.description:SetPoint("TOP", F.attente, "TOP", 0, GetNumPartyMembers() == 0 and -85 or -30)
		F.attente.temps:SetText(c.time and c.time:GetText() or "")
		if c.time and c.time:IsShown() then F.attente.temps:Show() else F.attente.temps:Hide() end
		for i = 1, 4 do
			local n, e = _G["LFDQueueFrameCooldownFrameName" .. i], _G["LFDQueueFrameCooldownFrameStatus" .. i]
			if n and n:IsShown() then
				F.attente.noms[i]:SetText(n:GetText() or "")
				F.attente.etats[i]:SetText(e and e:GetText() or "")
				F.attente.noms[i]:Show()
				F.attente.etats[i]:Show()
			else
				F.attente.noms[i]:Hide()
				F.attente.etats[i]:Hide()
			end
		end
		F.attente:Show()
	else
		F.attente:Hide()
	end

	local b = LFDQueueFramePartyBackfill
	if b and affiche(b) then
		F.reprise.description:SetText(texteDe("LFDQueueFramePartyBackfillDescription"))
		F.reprise.oui:Activer(actif(LFDQueueFramePartyBackfillBackfillButton))
		F.reprise:Show()
	else
		F.reprise:Hide()
	end

	local l = LFDQueueFrameNoLFDWhileLFR
	if l and affiche(l) then
		F.raid.description:SetText(texteDe("LFDQueueFrameNoLFDWhileLFRDescription"))
		F.raid.quitter:SetText(texteDe("LFDQueueFrameNoLFDWhileLFRLeaveQueueButton"))
		F.raid.quitter:Activer(actif(LFDQueueFrameNoLFDWhileLFRLeaveQueueButton))
		F.raid:Show()
	else
		F.raid:Hide()
	end
end

-- ------------------------------------------------------------ la page

local function construirePage(f)
	local p = CreateFrame("Frame", "ForeverUIGroupFinderDungeons", f)
	p:SetAllPoints(f)
	F.pageDonjons = p

	-- le bandeau des roles : un cadre fils, au-dessus des stries (camelot le
	-- pose en cadre fils, RolesSection)
	local roles = CreateFrame("Frame", nil, p)
	roles:SetAllPoints(f)
	roles:SetFrameLevel(f:GetFrameLevel() + 1)
	local bleu = roles:CreateTexture(nil, "BACKGROUND")
	bleu:SetTexture(G.bleu)
	bleu:SetPoint("TOPLEFT", f, "TOPLEFT", G.bleuX1, G.bleuY1)
	bleu:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", G.bleuX2, G.bleuY2)
	F.bleu = bleu
	F.roles = {}
	for _, r in ipairs(ROLES) do
		table.insert(F.roles, creerRole(roles, r))
	end

	-- l'encadre, au-dessus du bandeau : son fond de camelot couvre le bas du
	-- bleu comme dans la source
	local encadre = ForeverUI.CreateInset(p, "ForeverUIGroupFinderInset")
	encadre:SetFrameLevel(f:GetFrameLevel() + 2)
	encadre:SetPoint("TOPLEFT", f, "TOPLEFT", G.encadreX1, G.encadreY1)
	encadre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.encadreX2, G.encadreY2)
	encadre.fond:Hide()
	local fond = encadre:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "groupfinder-background", true)
	local e = ForeverUI.AtlasEntry("groupfinder-background")
	if e then
		fond:SetTexCoord(e[2], e[3], e[4] + (e[5] - e[4]) * G.fondHaut, e[5])
	end
	fond:SetPoint("TOPLEFT", encadre, "TOPLEFT", 3, -3)
	fond:SetPoint("BOTTOMRIGHT", encadre, "BOTTOMRIGHT", -3, 3)
	F.encadre = encadre

	local S = ForeverUI.Social
	-- les categories : empilees depuis le haut, sans defilement ; le filet
	-- et les details suivent le dernier bouton
	local cats = CreateFrame("Frame", "ForeverUIGroupFinderCategories", p)
	cats:SetFrameLevel(encadre:GetFrameLevel() + 1)
	cats:SetPoint("TOPLEFT", f, "TOPLEFT", G.catX1, G.catY1)
	cats:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.catX2, G.catY2)
	cats.lignes = {}
	F.categoriesVue = cats
	local regle = cats:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(regle, "shop-list-rule", true)
	regle:SetHeight(G.regleH)
	F.regle = regle

	-- la liste des donjons specifiques
	local liste = S.creerListe(p, "ForeverUIGroupFinderList", G.ligne, creerLigne, remplirLigne)
	liste:SetFrameLevel(encadre:GetFrameLevel() + 1)
	liste.barre:SetFrameLevel(encadre:GetFrameLevel() + 2)
	liste:SuivreBarre({ "TOPLEFT", f, "TOPLEFT", G.listeX1 + G.marge, G.listeY1 - G.marge },
		{ "BOTTOMRIGHT", f, "BOTTOMRIGHT", G.listeX2 + G.barreDroite - G.marge, G.listeY2 + G.marge },
		G.listeX2 - G.marge)
	-- la barre : TOPLEFT sur le TOPRIGHT de la liste (+13, -4) avec la marge
	liste.barre:ClearAllPoints()
	liste.barre:SetPoint("TOPLEFT", liste, "TOPRIGHT", 13 + G.marge, 0)
	liste.barre:SetPoint("BOTTOMLEFT", liste, "BOTTOMRIGHT", 13 + G.marge, -2)
	F.listeVue = liste

	construireRecompenses(p)
	F.details:SetFrameLevel(encadre:GetFrameLevel() + 1)
	F.details.barre:SetFrameLevel(encadre:GetFrameLevel() + 2)
	construireVoiles()

	-- les boutons du bas
	local retour = ForeverUI.CreatePanelButton(p, txt("BACK"), G.backL, G.boutonH, "ForeverUIGroupFinderBackButton", "GameFontNormal")
	retour:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.boutonCote, G.boutonBas)
	retour:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		F.vue = "categories"
		F.maj()
	end)
	F.retour = retour
	local chercher = ForeverUI.CreatePanelButton(p, txt("FIND_A_GROUP"), G.postL, G.boutonH, "ForeverUIGroupFinderFindButton", "GameFontNormal")
	chercher:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -G.boutonCote, G.boutonBas)
	-- le bouton du client : son OnClick choisit entre LeaveLFG et
	-- LFDQueueFrame_Join
	chercher:SetScript("OnClick", function()
		if LFDQueueFrameFindGroupButton and actif(LFDQueueFrameFindGroupButton) then
			LFDQueueFrameFindGroupButton:Click()
		end
	end)
	F.chercher = chercher
end

-- ------------------------------------------------------------ la mise a jour

local function modeEnFile()
	local mode = GetLFGMode()
	return mode == "queued" or mode == "rolecheck" or mode == "proposal"
end

-- les boutons de categorie, le filet sous le dernier, les details dessous
local function poserCategories()
	local cats = F.categoriesVue
	local n = #F.liste_categories
	for i = 1, n do
		local l = cats.lignes[i]
		if not l then
			l = CreateFrame("Frame", nil, cats)
			l:SetHeight(G.catH)
			creerCategorie(l)
			cats.lignes[i] = l
		end
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", cats, "TOPLEFT", 0, G.catPremier - (i - 1) * G.catPas)
		l:SetPoint("TOPRIGHT", cats, "TOPRIGHT", 0, G.catPremier - (i - 1) * G.catPas)
		remplirCategorie(l, i)
		l:Show()
	end
	for i = n + 1, #cats.lignes do cats.lignes[i]:Hide() end
	-- le bas du dernier bouton, depuis le haut de la fenetre
	local bas = G.catY1 + G.catPremier - (n - 1) * G.catPas - G.catH
	F.filetMax = bas - G.regleEcart
	placerFilet(nil)
end

function F.maj()
	if not F.cadre then return end
	F.majRoles()
	local vue = F.vue or "categories"
	if vue == "liste" and LFDQueueFrame.type ~= "specific" then vue = "categories" end
	F.vue = vue

	F.liste_categories = F.categories()
	poserCategories()
	if vue == "categories" then
		F.categoriesVue:Show()
		majRecompenses()
	else
		F.categoriesVue:Hide()
		F.details:Hide()
		F.details.barre:Hide()
	end
	if vue == "liste" then
		F.listeVue:Show()
		F.listeVue:Maj(LFDDungeonList and #LFDDungeonList or 0)
	else
		F.listeVue:Hide()
		F.listeVue.barre:Hide()
	end
	majVoiles()

	-- Back n'existe que dans la liste de "Specific Dungeons" (demande du
	-- 2026-09-26)
	if vue == "liste" then F.retour:Show() else F.retour:Hide() end
	local client = LFDQueueFrameFindGroupButton
	if client then
		F.chercher:SetText(client:GetText() or txt("FIND_A_GROUP"))
		F.chercher:Activer(actif(client))
	end
end

-- plusieurs mises a jour du client dans la meme image n'en font qu'une chez
-- nous
local attendre = CreateFrame("Frame")
attendre:Hide()
attendre:SetScript("OnUpdate", function(self)
	self:Hide()
	F.maj()
end)
F.attendre = attendre

function F.demander()
	if F.cadre and F.cadre:IsShown() then attendre:Show() end
end

-- ------------------------------------------------------------ le panneau

-- Le panneau du client se tait : ses regions, ses cadres fils sauf son
-- contenu et notre fenetre ; il n'attrape plus la souris. Son contenu reste
-- affiche -- sa logique en depend -- mais transparent, et pose SOUS notre
-- fenetre : ses boutons invisibles ne peuvent rien attraper.
local function etoufferClient()
	local p = LFDParentFrame
	for _, r in ipairs({ p:GetRegions() }) do r:Hide() end
	for _, c in ipairs({ p:GetChildren() }) do
		if c ~= F.cadre and c ~= LFDQueueFrame then c:Hide() end
	end
	p:EnableMouse(false)
	LFDQueueFrame:SetAlpha(0)
	LFDQueueFrame:ClearAllPoints()
	LFDQueueFrame:SetPoint("TOPLEFT", F.cadre, "TOPLEFT", 0, 0)
	LFDQueueFrame:SetWidth(p:GetWidth())
	LFDQueueFrame:SetHeight(p:GetHeight())
end

local function ouvrir()
	etoufferClient()
	-- a l'ouverture, les categories ; en file pour des donjons choisis, leur
	-- liste
	if modeEnFile() and LFDQueueFrame.type == "specific" then
		F.vue = "liste"
	else
		F.vue = "categories"
	end
	F.choisirOnglet("donjons")
	F.cadre:Show()
	F.maj()
end

local function construire()
	if F.cadre or not LFDParentFrame or not LFDQueueFrame then return end
	local f = CreateFrame("Frame", "ForeverUIGroupFinderFrame", LFDParentFrame)
	f:SetWidth(G.largeur)
	f:SetHeight(G.hauteur)
	f:SetPoint("TOPLEFT", LFDParentFrame, "TOPLEFT", 0, 0)
	-- au-dessus de tout le contenu du client (ses voiles montent a 16)
	f:SetFrameLevel(LFDParentFrame:GetFrameLevel() + 30)
	f:EnableMouse(true)
	F.cadre = f
	construireCadre(f)
	construirePage(f)

	F.onglets = {}
	local precedent
	for n, def in ipairs(ONGLETS) do
		local o = creerOnglet(f, def, n)
		if precedent then
			o:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, G.ongletEcart)
		else
			o:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, G.ongletY)
		end
		F.onglets[n] = o
		precedent = o
	end
	f:Hide()
end

construire()

if F.cadre then
	LFDParentFrame:HookScript("OnShow", ouvrir)
	LFDParentFrame:HookScript("OnHide", function() F.cadre:Hide() end)
	-- chaque mise a jour du client, et le changement de type (le PNJ d'une
	-- conversation l'appelle aussi) : la vue suit le type choisi
	for _, nom in ipairs({ "LFDQueueFrameSpecificList_Update", "LFDQueueFrameRandom_UpdateFrame",
		"LFDQueueFrameFindGroupButton_Update", "LFG_UpdateRolesChangeable", "LFG_UpdateRoleCheckboxes",
		"LFG_UpdateLockedOutPanels", "LFDFrame_UpdateBackfill", "LFDQueueFrameRandomCooldownFrame_Update" }) do
		if _G[nom] then hooksecurefunc(nom, F.demander) end
	end
	if LFDQueueFrame_SetType then
		hooksecurefunc("LFDQueueFrame_SetType", function(valeur)
			F.vue = (valeur == "specific") and "liste" or "categories"
			F.demander()
		end)
	end
	local veilleur = CreateFrame("Frame")
	for _, ev in ipairs({ "LFG_UPDATE", "LFG_ROLE_UPDATE", "LFG_LOCK_INFO_RECEIVED",
		"LFG_UPDATE_RANDOM_INFO", "PARTY_MEMBERS_CHANGED" }) do
		veilleur:RegisterEvent(ev)
	end
	veilleur:SetScript("OnEvent", F.demander)
	-- deplacable par son titre ; devant quand on l'ouvre ou qu'on la clique
	ForeverUI.Superposition.deplacable(F.cadre, F.cadre.bandeau, "chercheur")
	ForeverUI.Superposition.inscrire("chercheur", LFDParentFrame, function()
		local z = { F.cadre }
		for _, o in ipairs(F.onglets) do z[#z + 1] = o end
		return z
	end)
end

-- TEMOIN -- /fui chercheur
function ForeverUI.GroupFinderDebug()
	local dire = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t) end
	if not F.cadre then
		dire("chercheur : non construit (LFDParentFrame absent ?)")
		return
	end
	dire(string.format("chercheur : vue %s | type %s | mode %s | %d donjons | notre fenetre %s, niveau %d | contenu du client alpha %s, niveau %d",
		tostring(F.vue), tostring(LFDQueueFrame.type), tostring(GetLFGMode()),
		LFDDungeonList and #LFDDungeonList or 0, F.cadre:IsShown() and "affichee" or "cachee",
		F.cadre:GetFrameLevel(), tostring(LFDQueueFrame:GetAlpha()), LFDQueueFrame:GetFrameLevel()))
end
