-- ForeverUI : la carte du monde, mode reduit (etape 1 du chantier
-- docs/CARTE_ET_JOURNAL.md).
--
-- LA REGLE DU CHANTIER. On construit autour de la carte de WotLK : ses
-- cadres, leurs noms, ses fonctions et ses CVar restent. Les addons qui
-- parlent a WorldMapFrame continuent de parler a la carte normale. On
-- n'ajoute que ce qui se voit.
--
-- RELEVE DES SOURCES -- camelot, fichiers charges pour camelot d'apres les .toc.
--
-- blizzard_worldmap.xml + blizzard_worldmap.lua (Minimize, lignes 52-70) :
--   WorldMapFrame        702 x 534 en mode reduit (1035 avec le volet de
--                        quetes, etape 2)
--   TitleCanvasSpacer    TOPLEFT (2, 0), 67 de haut ; son bord droit a W - 3
--   ScrollContainer      la carte : sous le bandeau, bas a +2 -> 697 x 465
--   OverscrollBG         derriere la carte : gamepad-mapquestlog-bgtile-2k,
--                        quatre vignettes, une par quart, en miroir
--   BorderFrame          strate HIGH ; PortraitFrameTemplateMinimizable
--     Bg                 UI-Background-Rock pave, TOPLEFT (2,-21) BOTTOMRIGHT
--                        (-2, 2) -- remis sur WorldMapFrame par le Lua
--     InsetBorderTop     _UI-Frame-InnerTopTile, 3 de haut, TOPLEFT (2, -63),
--                        jusqu'au bord droit de la carte
--     portrait           62 x 62, TOPLEFT (-5, 7), UI-QuestLog-BookIcon, rond
--     NineSlice          coins et bords de metal, niveau 500 ; corrections
--                        camelot (NineSliceLayoutOverrides) : haut-droit x -2,
--                        bas y = -8
--     TitleText          GameFontNormal, TOP (0,-5) d'un bandeau de 20 pose
--                        de (58, -1) a (-24, -1) ; texte MAP_AND_QUEST_LOG
--     CloseButton        24 x 24, TOPRIGHT (-2, 1) (camelot)
--     MaximizeMinimize   24 x 24, RIGHT sur la gauche du CloseButton (-1)
--   NavBar               de (64, -25) du bandeau a (NAVBAR_X_OFFSET -50, 9)
--                        de son coin bas-droit ; navigationbar.xml/.lua
--   Filtres              32 x 32, LEFT sur la droite de la NavBar (10, -2)
--   Etages               WowStyle1Dropdown 160 x 25, TOPLEFT de la carte (2,0)
--   Coordonnees          BOTTOMLEFT de la carte (68, 2) ; curseur au-dessus,
--                        joueur en dessous, 100 x 15 chacune
--
-- CE QUE WOTLK FAIT, ET OU L'ON S'ACCROCHE (WorldMapFrame.lua, patch-enUS-3) :
--   WorldMap_ToggleSizeDown   passe en petite fenetre : echelle
--                             WORLDMAP_WINDOWED_SIZE, bordure MiniBorder,
--                             boutons replaces, puis WorldMapFrame_SetMiniMode
--   WorldMapFrame_SetMiniMode taille 623 x 437 (593 si deplacable), carte a
--                             (37, -66) ou (19, -42)
--   WorldMap_ToggleSizeUp     plein ecran : WorldMapFrame sans parent, sur
--                             tout l'ecran (SetupFullscreenScale), UIParent
--                             masque, BlackoutWorld noir ; vue QUESTLIST ou
--                             FULLMAP selon les quetes -- l'etape 4, plus bas
--   WorldMapButton_OnUpdate   place la fleche du joueur a
--                             position x WORLDMAP_SETTINGS.size : la fleche
--                             du moteur n'est PAS mise a l'echelle avec la
--                             carte. D'ou le choix ci-dessous.
--
-- LE MODE AGRANDI (etape 4, docs/CARTE_ET_JOURNAL.md, decision 1 : la carte
-- seule, comme camelot). RELEVE -- blizzard_worldmap.lua :
--   Maximize             bordure ButtonFrameTemplateNoPortraitMinimizable (sans
--                        portrait) ; NavBar a (8, -25) du bandeau au lieu de 64 ;
--                        pas de bouton d'aide ; titre WORLD_MAP
--   UpdateMaximizedSize  hauteur de l'ecran, largeur au prorata de la petite
--                        fenetre : ((H - 67) x 702) / (534 - 67), bornee a la
--                        largeur de l'ecran - 30 ; posee en TOP de l'ecran
--                        (maximizePoint "TOP") ; BlackoutFrame noir derriere
--   NineSliceLayouts     ButtonFrameTemplateNoPortraitMinimizable : haut-gauche
--                        UI-Frame-Metal-CornerTopLeft (-12, 16), haut-droit
--                        double (4, 16), bas (-12, -3) et (4, -3) ; corriges
--                        par camelot : haut-droit et bas-droit x - 2, bas y = -8
--
-- CE QUE L'ON GARDE DE WOTLK : sa bascule (CVar miniWorldMap, meme bouton), son
-- plein ecran detache de l'interface, son fond noir. Le cadre de camelot se
-- pose sur un SUPPORT aux dimensions de camelot, dans l'unite de l'interface
-- (le plein ecran de WotLK a sa propre echelle : le support la compense). La
-- carte de WotLK prend l'echelle qui la fait tenir dans le canevas, par les
-- CONSTANTES que WotLK lit pour placer fleche et reperes (QUESTLIST et
-- FULLMAP), comme la petite fenetre le fait deja avec WINDOWED.

-- L'ECHELLE. camelot pose sa carte dans 697 x 465, soit 697 / 1002 = 0,6956
-- pour une carte de WotLK de 1002 x 668. On change la CONSTANTE de la petite
-- fenetre avant que VARIABLES_LOADED n'appelle WorldMap_ToggleSizeDown :
-- tout le code de WotLK -- echelle, fleche, reperes, bornes des POI -- suit
-- alors de lui-meme.

ForeverUI = ForeverUI or {}

local W = {}
ForeverUI.WorldMap = W

-- LA GEOMETRIE, en une table (le Lua 5.1 du client refuse plus de 60
-- upvalues par fonction).
local G = {
	largeur = 702, hauteur = 534,
	carteX = 2, carteY = -67,          -- coin haut-gauche de la carte
	carteL = 697, carteH = 465,
	carteBas = 2,
	fondX1 = 2, fondY1 = -21, fondX2 = -2, fondY2 = 2,
	lisereY = -63, lisereH = 3,
	portraitX = -5, portraitY = 7, portraitCote = 62,
	titreX1 = 58, titreX2 = -24, titreY = -1, titreH = 20, titreTexteY = -5,
	fermerX = -2, fermerY = 1, boutonCote = 24, agrandirX = -1,
	-- la barre s'arrete a NAVBAR_X_OFFSET (-50) du bord droit de la carte,
	-- qui reste a 699 que le volet soit ouvert ou non
	barreX = 64 + 2, barreY = -25, barreDroite = 2 + 697 - 50, barreBas = -67 + 9,
	-- le volet de quetes : minimizedWidth + questLogWidth (702 + 333)
	largeurVolet = 333,
	-- SidePanelToggle : 32 x 32, BOTTOMRIGHT de la carte (-2, 1)
	basculeCote = 32, basculeX = -2, basculeY = 1,
	filtresX = 10, filtresY = -2, filtresCote = 32,
	etageL = 160, etageH = 25, etageX = 2, etageY = 0,
	-- common-dropdown-textholder : 54 x 41, decoupe par le moteur de camelot
	-- (UiTextureAtlasElementSliceData.db2 : 16 a gauche, 19 a droite, rien
	-- en hauteur -- l'image a deja la hauteur du fond)
	etageBordG = 16, etageBordD = 19, etageTexteX = 8, etageTexteY = -8,
	coordX = 68, coordY = 2, coordL = 100, coordH = 15,
	-- le mode agrandi
	bandeauH = 67, bordEcran = 30, carteDroite = 3,
	barreXAgrandi = 8 + 2,
	carteUtileL = 1002, carteUtileH = 668,
}
G.echelle = G.carteL / 1002

-- LE METAL (sx/mainline/nineslicelayouts.lua PortraitFrameTemplateMinimizable,
-- corrige par sx/camelot/nineslicelayoutoverrides.lua).
local METAL = {
	{ cle = "hg", nom = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ cle = "hd", nom = "ui-frame-metal-cornertoprightdouble", point = "TOPRIGHT", x = 2, y = 16 },
	{ cle = "bg", nom = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ cle = "bd", nom = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}
-- ButtonFrameTemplateNoPortraitMinimizable, corrige de meme : sans portrait,
-- le coin haut-gauche et les deux coins de gauche passent a -12
local METAL_AGRANDI = {
	hg = { nom = "ui-frame-metal-cornertopleft", x = -12, y = 16 },
	bg = { nom = "ui-frame-metal-cornerbottomleft", x = -12, y = -8 },
}

-- LES CHAINES DE CAMELOT (GlobalStrings.db2 du client camelot). 3.3.5 n'a
-- ni MAP_AND_QUEST_LOG, ni les formats de coordonnees, ni WORLD.
local TEXTE = {
	titre = "Map & Quest Log",          -- MAP_AND_QUEST_LOG
	titreAgrandi = WORLD_MAP or "Map",  -- WORLD_MAP (3.3.5 l'a)
	monde = "World",                    -- WORLD
	curseur = "Cursor: %d, %d",         -- WORLD_MAP_CURSOR_COORDS_INTEGER
	joueur = "Player: %d, %d",          -- WORLD_MAP_PLAYER_COORDS_INTEGER
	montrer = "Show:",                  -- WORLD_MAP_FILTER_LABEL_SHOW
}

-- LA BARRE DE NAVIGATION (navigationbar.xml). Deux fichiers, pas d'atlas.
local NAV = {
	feuille = "interface\\ForeverUI\\helpframe\\cs_helptextures",
	tuile = "interface\\ForeverUI\\helpframe\\cs_helptextures_tile",
	ombre = "interface\\ForeverUI\\common\\shadowoverlay-left",
	fleches = "interface\\ForeverUI\\buttons\\squarebuttontextures",
	carreHaut = "interface\\ForeverUI\\buttons\\ui-squarebutton-up",
	carreBas = "interface\\ForeverUI\\buttons\\ui-squarebutton-down",
	survolCarre = "interface\\ForeverUI\\buttons\\ui-common-mousehilight",
	fond = { 0, 1, 0.1875, 0.25390625 },               -- _NavMenu-BarBG
	voile = { 0, 1, 0.2578125, 0.32421875 },           -- _NavMenu-BarOverlay
	boutonHaut = { 0, 1, 0.0625, 0.12109375 },         -- _NavMenu-Button-Up
	boutonBas = { 0, 1, 0.125, 0.18359375 },           -- _NavMenu-Button-Down
	boutonSurvol = { 0.00195313, 0.25195313, 0.65625, 0.92187500 },
	boutonChoisi = { 0.00195313, 0.25195313, 0.375, 0.640625 },
	flecheHaut = { 0.88867188, 0.92968750, 0.29687500, 0.53125000 },
	flecheBas = { 0.63281250, 0.67382813, 0.75781250, 0.99218750 },
	flecheMenu = { 0.45312500, 0.64062500, 0.20312500, 0.01562500 },
	accueilHaut = { 0.00781250, 0.24218750 },
	accueilBas = { 0.25781250, 0.49218750 },
	accueilSurvol = { 0.50781250, 0.74218750 },
	accueilDroite = 0.703125,
	hauteurBouton = 30,
}

local PREFIX = "|cff66ccffForeverUI|r "

local function dire(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

-- ETOUFFER une region du client : image, opacite et visibilite a la fois --
-- le code de WotLK remontre ce qu'on se contente de cacher.
local function etouffer(region)
	if not region then
		return
	end
	if region.SetTexture then
		region:SetTexture(nil)
	end
	region:SetAlpha(0)
	region:Hide()
end

-- UN ETAT DE BOUTON SUR UN ATLAS. SetNormalTexture n'accepte qu'un chemin, et
-- un bouton de 3.3.5 n'a que les etats que son XML declare.
local function etatBouton(bouton, etat, nom)
	local e = ForeverUI.AtlasEntry(nom)
	if not e then
		return nil
	end
	local texture = bouton["Get" .. etat .. "Texture"](bouton)
	if not texture then
		bouton["Set" .. etat .. "Texture"](bouton, e[1])
		texture = bouton["Get" .. etat .. "Texture"](bouton)
	end
	if texture then
		ForeverUI.SetAtlas(texture, nom, true)
		texture:ClearAllPoints()
		texture:SetAllPoints(bouton)
	end
	return texture
end

local function enPetiteFenetre()
	return WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE
end

-- ---------------------------------------------------------------- l'echelle
-- Avant VARIABLES_LOADED : c'est lui qui appelle WorldMap_ToggleSizeDown.
if WORLDMAP_WINDOWED_SIZE then
	WORLDMAP_WINDOWED_SIZE = G.echelle
end

-- -------------------------------------------------------------- le deplacement
-- Demande de l'utilisateur (2026-09-25) : la carte reduite se deplace en la
-- tirant par sa barre du haut. camelot ne le permet pas ; WotLK, si. Son mode
-- avance (CVar advancedWorldMap, la case ADVANCED_WORLD_MAP_TEXT des options)
-- fait de la petite fenetre un panneau de zone "center" -- que le
-- gestionnaire ne replace jamais (UIParent.lua:1694) --, deplacable, ancre sur
-- WorldMapScreenAnchor, dont le client retient la position. La barre de titre
-- de WotLK (WorldMapTitleButton) la fait glisser, sauf si elle est
-- verrouillee -- ce qu'elle est par defaut. Le plein ecran, lui, ne bouge pas.
-- La CVar doit etre posee AVANT VARIABLES_LOADED : c'est la que WotLK la lit.
if GetCVar and SetCVar and GetCVar("advancedWorldMap") ~= "1" then
	SetCVar("advancedWorldMap", "1")
end
if WORLDMAP_SETTINGS then
	WORLDMAP_SETTINGS.locked = false
end

-- La premiere fois, l'ancre est au coin haut-gauche de l'ecran (XML). On la
-- pose ou camelot ouvre sa carte : un panneau "left" a LEFT_OFFSET 16,
-- TOP_OFFSET -116 (uipanellayoutframe.lua:3-4). Comme WorldMapFrame_ToggleAdvanced,
-- par StartMoving : le client retient alors la position.
local ANCRE = { x = 16, y = -116 }

local function placerAncre()
	local ancre = WorldMapScreenAnchor
	if not ancre or (ancre.IsUserPlaced and ancre:IsUserPlaced()) then
		return
	end
	ancre:StartMoving()
	ancre:ClearAllPoints()
	ancre:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ANCRE.x, ANCRE.y)
	ancre:StopMovingOrSizing()
end

-- ------------------------------------------------------------ l'habillage
-- Deux calques, comme chez camelot : le FOND sous la carte (strate de la
-- carte, niveau de WorldMapFrame), le CADRE au-dessus (strate HIGH, comme
-- BorderFrame). Ni l'un ni l'autre n'attrape la souris : en petite fenetre
-- WotLK coupe la souris de WorldMapFrame, et la carte doit rester cliquable.

local function construireFond(carte)
	local fond = CreateFrame("Frame", "ForeverUIWorldMapBackground", carte)
	fond:SetAllPoints(carte)

	-- Bg : UI-Background-Rock, un FICHIER entier, donc pavable.
	local roche = fond:CreateTexture(nil, "BACKGROUND")
	roche:SetTexture("interface\\ForeverUI\\framegeneral\\ui-background-rock", true)
	if roche.SetHorizTile then
		roche:SetHorizTile(true)
		roche:SetVertTile(true)
	end
	roche:SetPoint("TOPLEFT", fond, "TOPLEFT", G.fondX1, G.fondY1)
	roche:SetPoint("BOTTOMRIGHT", fond, "BOTTOMRIGHT", G.fondX2, G.fondY2)

	-- OverscrollBG, sur le rectangle de la carte -- le CANEVAS, qui suit la
	-- carte dans les deux modes. Ses textures restent des REGIONS du fond, et
	-- non un cadre fils : un cadre fils prend un niveau au-dessus de son
	-- parent -- 89 --, soit AU-DESSUS des tuiles de WotLK (WorldMapDetailFrame,
	-- 88), qu'il masquait en partie. La tuile est un atlas : 3.3.5 ne pave pas
	-- un rectangle d'atlas, on l'etire.
	local canevas = W.canevas
	local tuile = fond:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(tuile, "gamepad-mapquestlog-bgtile-2k", true)
	tuile:SetPoint("TOPLEFT", canevas, "TOPLEFT", 0, 0)
	tuile:SetPoint("BOTTOMRIGHT", canevas, "BOTTOMRIGHT", 0, 0)
	fond.tuile = tuile

	local e = ForeverUI.AtlasEntry("gamepad-mapquestlog-bg-vignette")
	if e then
		-- quatre quarts, en miroir par les coordonnees (blizzard_worldmap.xml)
		local quarts = {
			{ "TOPLEFT", "TOPLEFT", "BOTTOMRIGHT", "CENTER", e[2], e[3], e[4], e[5] },
			{ "TOPRIGHT", "TOPRIGHT", "BOTTOMLEFT", "CENTER", e[3], e[2], e[4], e[5] },
			{ "BOTTOMLEFT", "BOTTOMLEFT", "TOPRIGHT", "CENTER", e[2], e[3], e[5], e[4] },
			{ "BOTTOMRIGHT", "BOTTOMRIGHT", "TOPLEFT", "CENTER", e[3], e[2], e[5], e[4] },
		}
		for _, q in ipairs(quarts) do
			local v = fond:CreateTexture(nil, "BORDER")
			v:SetTexture(e[1])
			v:SetTexCoord(q[5], q[6], q[7], q[8])
			v:SetPoint(q[1], canevas, q[2], 0, 0)
			v:SetPoint(q[3], canevas, q[4], 0, 0)
		end
	end
	return fond
end

local function construireCadre(carte)
	local cadre = CreateFrame("Frame", "ForeverUIWorldMapBorder", carte)
	cadre:SetAllPoints(carte)
	cadre:SetFrameStrata("HIGH")

	-- le liseré sous le bandeau
	local lisere = cadre:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(lisere, "_ui-frame-innertoptile", true)
	lisere:SetHeight(G.lisereH)
	lisere:SetPoint("TOPLEFT", cadre, "TOPLEFT", 2, G.lisereY)
	lisere:SetPoint("RIGHT", cadre, "LEFT", G.carteX + G.carteL, 0)
	cadre.lisere = lisere

	-- le portrait, sous le metal (PortraitContainer 400 < NineSlice 500)
	local portrait = CreateFrame("Frame", nil, cadre)
	portrait:SetAllPoints(cadre)
	portrait:SetFrameLevel(cadre:GetFrameLevel() + 1)
	local image = portrait:CreateTexture(nil, "OVERLAY")
	image:SetWidth(G.portraitCote)
	image:SetHeight(G.portraitCote)
	image:SetPoint("TOPLEFT", cadre, "TOPLEFT", G.portraitX, G.portraitY)
	local livre = "interface\\ForeverUI\\questframe\\ui-questlog-bookicon"
	if SetPortraitToTexture then
		SetPortraitToTexture(image, livre)
	else
		image:SetTexture(livre)
	end
	cadre.portrait = image
	cadre.portraitCadre = portrait

	-- le metal
	local metal = CreateFrame("Frame", nil, cadre)
	metal:SetAllPoints(cadre)
	metal:SetFrameLevel(cadre:GetFrameLevel() + 2)
	local p = {}
	for _, coin in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, coin.nom)
		t:SetPoint(coin.point, metal, coin.point, coin.x, coin.y)
		p[coin.cle] = t
	end
	cadre.coins = p
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
	cadre.metal = metal

	-- le bandeau du titre, au-dessus du metal (TitleContainer 510)
	local bandeau = CreateFrame("Frame", nil, cadre)
	bandeau:SetFrameLevel(cadre:GetFrameLevel() + 3)
	bandeau:SetHeight(G.titreH)
	bandeau:SetPoint("TOPLEFT", cadre, "TOPLEFT", G.titreX1, G.titreY)
	bandeau:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", G.titreX2, G.titreY)
	cadre.bandeau = bandeau
	return cadre
end

-- ------------------------------------------------------ la barre de navigation
-- navigationbar.lua, recopie pour les donnees de WotLK : Monde > continent >
-- zone. camelot prend la carte la plus haute de type World ; en 3.3.5 c'est
-- SetMapZoom(WORLDMAP_WORLD_ID). Les listes d'un bouton sont ses soeurs :
-- GetMapContinents pour le continent, GetMapZones pour la zone.

local menuNav = CreateFrame("Frame", "ForeverUIWorldMapNavMenu", UIParent, "UIDropDownMenuTemplate")
menuNav:Hide()

-- minimum : la largeur que la liste ne peut pas descendre -- celle du menu
-- deroulant qui l'ouvre (DropdownButtonMixin:RegisterMenu, SetMinimumWidth)
local function ouvrirMenu(ancre, liste, minimum)
	menuNav.foreverMinimum = minimum
	UIDropDownMenu_Initialize(menuNav, function()
		for _, entree in ipairs(liste) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = entree.text
			info.func = entree.func
			info.checked = entree.checked
			info.notCheckable = entree.checked == nil and 1 or nil
			info.keepShownOnClick = entree.keepShownOnClick
			info.isTitle = entree.isTitle
			info.notClickable = entree.isTitle
			info.disabled = entree.disabled
			UIDropDownMenu_AddButton(info)
		end
	end, "MENU")
	ToggleDropDownMenu(1, nil, menuNav, ancre, 0, 0)
	-- VERS LE BAS, TOUJOURS (2026-09-25). ToggleDropDownMenu de 3.3.5 RETOURNE
	-- la liste au-dessus du bouton des qu'elle deborderait sous l'ecran --
	-- le cas des longues listes de zones en petite fenetre. Les menus de
	-- camelot (Blizzard_Menu) restent sous leur bouton et se calent dans
	-- l'ecran : la liste repart vers le bas, calee le temps qu'elle est
	-- ouverte.
	local liste1 = DropDownList1
	if liste1 and liste1:IsShown() then
		local point = liste1:GetPoint(1)
		if point and string.find(point, "^BOTTOM") then
			liste1:ClearAllPoints()
			liste1:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", 0, 0)
		end
		if not liste1.foreverCalee then
			liste1.foreverCalee = true
			liste1.foreverCaleeAvant = liste1.IsClampedToScreen and liste1:IsClampedToScreen() or false
			liste1:SetClampedToScreen(true)
		end
	end
end
W.ouvrirMenu = ouvrirMenu

-- la liste refermee : elle rend son calage aux autres menus du jeu
if DropDownList1 then
	DropDownList1:HookScript("OnHide", function(self)
		if self.foreverCalee then
			self:SetClampedToScreen(self.foreverCaleeAvant and true or false)
			self.foreverCalee, self.foreverCaleeAvant = nil, nil
		end
	end)
end

local function poserSurFeuille(texture, coords)
	texture:SetTexture(NAV.feuille)
	texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

-- Les rangees de la feuille pavee sont uniformes en largeur : on les etire
-- au lieu de les paver (le pavage de 3.3.5 ignorerait la rangee choisie).
local function poserSurTuile(texture, coords)
	texture:SetTexture(NAV.tuile)
	texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

local function creerBoutonNav(barre, index)
	local b = CreateFrame("Button", "ForeverUIWorldMapNavButton" .. index, barre)
	b:SetHeight(NAV.hauteurBouton)
	b:SetNormalTexture(NAV.tuile)
	poserSurTuile(b:GetNormalTexture(), NAV.boutonHaut)
	b:SetPushedTexture(NAV.tuile)
	poserSurTuile(b:GetPushedTexture(), NAV.boutonBas)
	b:SetDisabledTexture(NAV.tuile)
	poserSurTuile(b:GetDisabledTexture(), NAV.boutonHaut)
	b:SetHighlightTexture(NAV.feuille)
	poserSurFeuille(b:GetHighlightTexture(), NAV.boutonSurvol)
	b:GetHighlightTexture():SetBlendMode("ADD")

	local texte = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	texte:SetJustifyH("LEFT")
	texte:SetHeight(12)
	texte:SetPoint("LEFT", b, "LEFT", 20, 0)
	b:SetFontString(texte)
	b.text = texte

	b.arrowUp = b:CreateTexture(nil, "OVERLAY")
	b.arrowUp:SetWidth(21)
	b.arrowUp:SetHeight(30)
	b.arrowUp:SetPoint("LEFT", b, "RIGHT", 0, 0)
	poserSurFeuille(b.arrowUp, NAV.flecheHaut)
	b.arrowDown = b:CreateTexture(nil, "OVERLAY")
	b.arrowDown:SetWidth(21)
	b.arrowDown:SetHeight(30)
	b.arrowDown:SetPoint("LEFT", b, "RIGHT", 0, 0)
	poserSurFeuille(b.arrowDown, NAV.flecheBas)
	b.arrowDown:Hide()
	b.selected = b:CreateTexture(nil, "OVERLAY")
	b.selected:SetAllPoints(b)
	poserSurFeuille(b.selected, NAV.boutonChoisi)
	b.selected:Hide()

	b:SetScript("OnMouseDown", function(self)
		if self:IsEnabled() == 1 then
			self.arrowUp:Hide()
			self.arrowDown:Show()
		end
	end)
	b:SetScript("OnMouseUp", function(self)
		self.arrowDown:Hide()
		self.arrowUp:Show()
	end)

	-- MenuArrowButton : 27 x 31, RIGHT sur TOPRIGHT (-2, -15)
	local m = CreateFrame("Button", nil, b)
	m:SetWidth(27)
	m:SetHeight(31)
	m:SetPoint("RIGHT", b, "TOPRIGHT", -2, -15)
	m.Art = m:CreateTexture(nil, "OVERLAY")
	m.Art:SetWidth(12)
	m.Art:SetHeight(12)
	m.Art:SetPoint("CENTER", m, "CENTER", 0, -1)
	m.Art:SetTexture(NAV.fleches)
	m.Art:SetTexCoord(NAV.flecheMenu[1], NAV.flecheMenu[2], NAV.flecheMenu[3], NAV.flecheMenu[4])
	m:SetNormalTexture(NAV.carreHaut)
	m:GetNormalTexture():SetAlpha(0)
	m:SetPushedTexture(NAV.carreBas)
	m:GetPushedTexture():SetAlpha(0)
	m:SetHighlightTexture(NAV.survolCarre)
	m:GetHighlightTexture():SetBlendMode("ADD")
	for _, t in ipairs({ m:GetNormalTexture(), m:GetPushedTexture(), m:GetHighlightTexture() }) do
		t:ClearAllPoints()
		t:SetWidth(32)
		t:SetHeight(32)
		t:SetPoint("CENTER", m, "CENTER", 0, 0)
	end
	m:SetScript("OnMouseDown", function(self) self.Art:SetPoint("CENTER", self, "CENTER", -1, -2) end)
	m:SetScript("OnMouseUp", function(self) self.Art:SetPoint("CENTER", self, "CENTER", 0, -1) end)
	m:SetScript("OnEnter", function(self)
		self:GetNormalTexture():SetAlpha(1)
		self:GetPushedTexture():SetAlpha(1)
	end)
	m:SetScript("OnLeave", function(self)
		self:GetNormalTexture():SetAlpha(0)
		self:GetPushedTexture():SetAlpha(0)
	end)
	m:SetScript("OnClick", function(self)
		local parent = self:GetParent()
		if parent.listFunc then
			ouvrirMenu(self, parent.listFunc())
		end
	end)
	b.MenuArrowButton = m

	b:SetScript("OnClick", function(self)
		if self.myclick then
			self.myclick()
		end
	end)
	return b
end

local function construireBarre(carte)
	local barre = CreateFrame("Frame", "ForeverUIWorldMapNavBar", carte)
	barre:SetPoint("TOPLEFT", carte, "TOPLEFT", G.barreX, G.barreY)
	barre:SetPoint("BOTTOMRIGHT", carte, "TOPLEFT", G.barreDroite, G.barreBas)

	local fond = barre:CreateTexture(nil, "BACKGROUND")
	fond:SetAllPoints(barre)
	poserSurTuile(fond, NAV.fond)

	-- liseré interieur (WorldMapNavBarTemplate), couche BORDER
	local function piece(nom)
		local t = barre:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, nom)
		return t
	end
	local bg = piece("ui-frame-innerbotleftcorner")
	bg:SetPoint("BOTTOMLEFT", barre, "BOTTOMLEFT", -3, -3)
	local bd = piece("ui-frame-innerbotright")
	bd:SetPoint("BOTTOMRIGHT", barre, "BOTTOMRIGHT", 3, -3)
	local bas = piece("_ui-frame-innerbottile")
	bas:SetPoint("BOTTOMLEFT", bg, "BOTTOMRIGHT")
	bas:SetPoint("BOTTOMRIGHT", bd, "BOTTOMLEFT")
	local gauche = piece("!ui-frame-innerlefttile")
	gauche:SetPoint("TOPLEFT", barre, "TOPLEFT", -3, 0)
	-- tel qu'ecrit dans la source : BOTTOMLEFT sur le TOPLEFT de
	-- InsetBorderBottomRight (blizzard_worldmaptemplates.xml:97)
	gauche:SetPoint("BOTTOMLEFT", bd, "TOPLEFT")
	local droite = piece("!ui-frame-innerrighttile")
	droite:SetPoint("TOPRIGHT", barre, "TOPRIGHT", 3, 0)
	droite:SetPoint("BOTTOMRIGHT", bd, "TOPRIGHT")

	-- le bouton racine
	local accueil = CreateFrame("Button", "ForeverUIWorldMapNavBarHomeButton", barre)
	accueil:SetHeight(NAV.hauteurBouton)
	accueil:SetNormalTexture(NAV.feuille)
	accueil:SetPushedTexture(NAV.feuille)
	accueil:SetHighlightTexture(NAV.feuille)
	accueil:GetHighlightTexture():SetBlendMode("ADD")
	local texte = accueil:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	texte:SetJustifyH("LEFT")
	texte:SetHeight(12)
	texte:SetPoint("LEFT", accueil, "LEFT", 10, 0)
	texte:SetPoint("RIGHT", accueil, "RIGHT", -30, 0)
	accueil:SetFontString(texte)
	accueil.text = texte
	accueil:SetText(TEXTE.monde)
	local largeur = math.min(128, texte:GetStringWidth() + 50)
	local du = (largeur / 128) * 0.25
	local d = NAV.accueilDroite
	accueil:GetNormalTexture():SetTexCoord(d - du, d, NAV.accueilHaut[1], NAV.accueilHaut[2])
	accueil:GetPushedTexture():SetTexCoord(d - du, d, NAV.accueilBas[1], NAV.accueilBas[2])
	accueil:GetHighlightTexture():SetTexCoord(d - du, d + 0.01, NAV.accueilSurvol[1], NAV.accueilSurvol[2])
	accueil:SetWidth(largeur)
	accueil.xoffset = -15
	local ombre = accueil:CreateTexture(nil, "OVERLAY")
	ombre:SetTexture(NAV.ombre)
	ombre:SetWidth(30)
	ombre:SetHeight(30)
	ombre:SetPoint("LEFT", accueil, "LEFT", 0, 0)
	accueil:SetPoint("LEFT", barre, "LEFT", 0, 0)
	-- LE BOUTON "WORLD" montre la carte ou l'on choisit entre Azeroth et
	-- l'Outreterre : WORLDMAP_COSMIC_ID, comme le zoom arriere de WotLK depuis
	-- Azeroth (WorldMapZoomOutButton_OnClick). La vue cosmique se reconnait
	-- comme WorldMapFrame_Update la reconnait : GetMapInfo() ne rend rien et
	-- le continent vaut WORLDMAP_COSMIC_ID (la premiere version attendait
	-- "Cosmic" de GetMapInfo, qui rend nil : elle repartait aussitot par
	-- ZoomOut vers la carte d'ou l'on venait -- en donjon, "World" ne faisait
	-- rien). Depuis un donjon, WotLK ne sort que par ZoomOut : on essaie
	-- SetMapZoom, puis ZoomOut, tant que la carte change.
	accueil.myclick = function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		local cosmique = WORLDMAP_COSMIC_ID or -1
		local function estCosmique()
			return GetMapInfo() == nil and GetCurrentMapContinent() == cosmique
		end
		local function etat()
			return tostring(GetMapInfo()) .. ":" .. tostring(GetCurrentMapContinent()) .. ":"
				.. tostring(GetCurrentMapZone()) .. ":" .. tostring(GetCurrentMapDungeonLevel())
		end
		for _ = 1, 6 do
			if estCosmique() then break end
			SetMapZoom(cosmique)
			if estCosmique() then break end
			local avant = etat()
			ZoomOut()
			if etat() == avant then break end
		end
		-- le client a refuse : ce qu'il repond, pour comprendre
		if not estCosmique() then
			dire(string.format("carte du monde : \"World\" refuse par le client (carte %s, continent %s, zone %s, etage %s, zoom arriere %s)",
				tostring(GetMapInfo()), tostring(GetCurrentMapContinent()), tostring(GetCurrentMapZone()),
				tostring(GetCurrentMapDungeonLevel()), tostring(IsZoomOutAvailable and IsZoomOutAvailable())))
		end
	end
	accueil:SetScript("OnClick", function(self) self.myclick() end)
	barre.home = accueil

	-- le voile, par-dessus les boutons
	local voile = CreateFrame("Frame", nil, barre)
	voile:SetAllPoints(barre)
	local t = voile:CreateTexture(nil, "OVERLAY")
	t:SetAllPoints(voile)
	poserSurTuile(t, NAV.voile)
	barre.voile = voile

	barre.boutons = {}
	return barre
end

-- La hierarchie de la carte affichee, telle que 3.3.5 la connait.
local function hierarchie()
	local liste = {}
	local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
	local zone = GetCurrentMapZone and GetCurrentMapZone() or 0
	if continent and continent > 0 then
		local continents = { GetMapContinents() }
		table.insert(liste, {
			name = continents[continent],
			OnClick = function() SetMapZoom(continent) end,
			listFunc = function()
				local l = {}
				for i, nom in ipairs({ GetMapContinents() }) do
					table.insert(l, { text = nom, func = function() SetMapZoom(i) end })
				end
				return l
			end,
		})
		if zone and zone > 0 then
			local zones = { GetMapZones(continent) }
			table.insert(liste, {
				name = zones[zone],
				OnClick = function() SetMapZoom(continent, zone) end,
				listFunc = function()
					local l = {}
					for i, nom in ipairs({ GetMapZones(continent) }) do
						table.insert(l, { text = nom, func = function() SetMapZoom(continent, i) end })
					end
					return l
				end,
			})
		end
	end
	return liste
end
W.hierarchie = hierarchie

-- NavBar_Reset + NavBar_AddButton + NavBar_CheckLength : la largeur d'un
-- bouton vaut son texte + 53 s'il a une liste, + 30 sinon ; chacun s'ancre a
-- droite du precedent, de xoffset (-15 apres le bouton racine) ; le dernier
-- est desactive et porte l'image de selection.
local function rafraichirBarre()
	local barre = W.barre
	if not barre then
		return
	end
	for _, b in ipairs(barre.boutons) do
		b:Hide()
	end
	local liste = hierarchie()
	local precedent = barre.home
	local niveau = barre:GetFrameLevel() + 1
	barre.home:SetFrameLevel(niveau)
	for i, donnees in ipairs(liste) do
		local b = barre.boutons[i]
		if not b then
			b = creerBoutonNav(barre, i)
			barre.boutons[i] = b
		end
		b:SetText(donnees.name or "")
		if donnees.listFunc then
			b.MenuArrowButton:Show()
			b:SetWidth(b.text:GetStringWidth() + 53)
		else
			b.MenuArrowButton:Hide()
			b:SetWidth(b.text:GetStringWidth() + 30)
		end
		b.myclick = donnees.OnClick
		b.listFunc = donnees.listFunc
		b:ClearAllPoints()
		b:SetPoint("LEFT", precedent, "RIGHT", precedent.xoffset or 0, 0)
		niveau = niveau + 1
		b:SetFrameLevel(niveau)
		b:Show()
		precedent = b
	end
	-- le dernier bouton est l'endroit ou l'on est
	local dernier = #liste
	for i = 1, dernier do
		local b = barre.boutons[i]
		if i < dernier then
			b.selected:Hide()
			b:Enable()
		else
			b.selected:Show()
			b:SetButtonState("NORMAL")
			b:Disable()
		end
	end
	-- "World" n'est l'endroit ou l'on est que sur la vue cosmique (pas de nom
	-- de carte, continent WORLDMAP_COSMIC_ID). En donjon, 3.3.5 ne donne ni
	-- continent ni zone : le fil est vide, mais "World" doit rester cliquable
	-- (il etait desactive, 2026-09-25) ; sur Azeroth aussi.
	local cosmique = GetMapInfo() == nil and GetCurrentMapContinent() == (WORLDMAP_COSMIC_ID or -1)
	if dernier == 0 and cosmique then
		barre.home:SetButtonState("NORMAL")
		barre.home:Disable()
	else
		barre.home:Enable()
	end
	barre.voile:SetFrameLevel(niveau + 1)
end
W.rafraichirBarre = rafraichirBarre

-- ------------------------------------------------------------- les filtres
-- camelot/blizzard_worldmaptemplates.xml. Le menu de camelot liste ses
-- filtres de carte ; 3.3.5 n'en a que deux : les objectifs de quete (CVar
-- questPOI, la case de WotLK) et la couleur de difficulte (mapQuestDifficulty).

local function filtres()
	return {
		{ text = TEXTE.montrer, isTitle = 1 },
		{
			text = SHOW_QUEST_OBJECTIVES_ON_MAP_TEXT or QUEST_OBJECTIVES,
			checked = WorldMapQuestShowObjectives and WorldMapQuestShowObjectives:GetChecked() and true or false,
			keepShownOnClick = 1,
			func = function()
				if WorldMapQuestShowObjectives then
					WorldMapQuestShowObjectives:Click()
				end
			end,
		},
		{
			text = MAP_QUEST_DIFFICULTY_TEXT,
			checked = MAP_QUEST_DIFFICULTY == "1",
			keepShownOnClick = 1,
			func = function()
				local valeur = MAP_QUEST_DIFFICULTY == "1" and "0" or "1"
				SetCVar("mapQuestDifficulty", valeur)
				MAP_QUEST_DIFFICULTY = valeur
				if WorldMapFrame_ResetQuestColors then
					WorldMapFrame_ResetQuestColors()
				end
				if WorldMapFrame:IsShown() and WatchFrame and WatchFrame.showObjectives then
					WorldMapFrame_DisplayQuests()
				end
			end,
		},
	}
end

local function construireFiltres(carte, barre)
	local b = CreateFrame("Button", "ForeverUIWorldMapFilterButton", carte)
	b:SetFrameStrata("HIGH")
	b:SetWidth(G.filtresCote)
	b:SetHeight(G.filtresCote)
	b:SetPoint("LEFT", barre, "RIGHT", G.filtresX, G.filtresY)
	local icone = b:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(icone, "common-dropdown-a-button")
	icone:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -6)
	b.Icon = icone
	b:SetHighlightTexture(ForeverUI.AtlasEntry("common-dropdown-a-button")[1])
	local survol = b:GetHighlightTexture()
	ForeverUI.SetAtlas(survol, "common-dropdown-a-button")
	survol:ClearAllPoints()
	survol:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -6)
	survol:SetBlendMode("ADD")
	survol:SetAlpha(0.4)
	b:SetScript("OnMouseDown", function(self) ForeverUI.SetAtlas(self.Icon, "common-dropdown-a-button-pressed", true) end)
	b:SetScript("OnMouseUp", function(self) ForeverUI.SetAtlas(self.Icon, "common-dropdown-a-button", true) end)
	b:SetScript("OnClick", function(self) ouvrirMenu(self, filtres()) end)
	return b
end

-- ---------------------------------------------------------------- les etages
-- WowStyle1DropdownTemplate : fond common-dropdown-textholder de (-8, 7) a
-- (8, -9), fleche common-dropdown-a-button a RIGHT (1, -3), texte
-- GameFontHighlight de (8, -8) a la fleche. Visible seulement si la carte a
-- des etages (WorldMapFloorNavigationFrameMixin:Refresh).

local function nomEtage(i)
	local nom = strupper(GetMapInfo() or "")
	local numero = i
	if DungeonUsesTerrainMap and DungeonUsesTerrainMap() then
		numero = i - 1
	end
	return _G["DUNGEON_FLOOR_" .. nom .. numero] or string.format(FLOOR_NUMBER, i)
end

local function construireEtages(carte)
	local b = CreateFrame("Button", "ForeverUIWorldMapFloorButton", carte)
	b:SetFrameStrata("HIGH")
	b:SetWidth(G.etageL)
	b:SetHeight(G.etageH)
	b:SetPoint("TOPLEFT", carte, "TOPLEFT", G.carteX + G.etageX, G.carteY - G.etageY)
	-- LE FOND, EN TROIS : etire d'une piece, ses 16 et 19 pixels d'ombre
	-- transparente triplaient avec la largeur -- la boite visible se
	-- retrouvait etroite et decalee a droite, le nom debordant a sa gauche
	-- (constate en jeu le 2026-09-25). Variante c60, celle que camelot montre.
	local e = ForeverUI.AtlasEntry("common-dropdown-textholder-c60")
	local fond = CreateFrame("Frame", nil, b)
	fond:SetPoint("TOPLEFT", b, "TOPLEFT", -8, 7)
	fond:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 8, -9)
	if e then
		local du = (e[3] - e[2]) / e[6]
		local u1, u2 = e[2] + G.etageBordG * du, e[3] - G.etageBordD * du
		local function morceau(a, z)
			local t = b:CreateTexture(nil, "BACKGROUND")
			t:SetTexture(e[1])
			t:SetTexCoord(a, z, e[4], e[5])
			return t
		end
		local g = morceau(e[2], u1)
		g:SetWidth(G.etageBordG)
		g:SetPoint("TOPLEFT", fond, "TOPLEFT", 0, 0)
		g:SetPoint("BOTTOMLEFT", fond, "BOTTOMLEFT", 0, 0)
		local d = morceau(u2, e[3])
		d:SetWidth(G.etageBordD)
		d:SetPoint("TOPRIGHT", fond, "TOPRIGHT", 0, 0)
		d:SetPoint("BOTTOMRIGHT", fond, "BOTTOMRIGHT", 0, 0)
		local m = morceau(u1, u2)
		m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
		m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
		b.fond = { g, m, d }
	end
	local fleche = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(fleche, "common-dropdown-a-button")
	fleche:SetPoint("RIGHT", b, "RIGHT", 1, -3)
	local texte = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	texte:SetJustifyH("LEFT")
	texte:SetHeight(10)
	texte:SetPoint("TOPLEFT", b, "TOPLEFT", G.etageTexteX, G.etageTexteY)
	texte:SetPoint("TOPRIGHT", fleche, "LEFT", 0, 0)
	b.Text = texte
	b.Arrow = fleche
	b:SetScript("OnMouseDown", function(self) ForeverUI.SetAtlas(self.Arrow, "common-dropdown-a-button-pressed", true) end)
	b:SetScript("OnMouseUp", function(self) ForeverUI.SetAtlas(self.Arrow, "common-dropdown-a-button", true) end)
	b:SetScript("OnClick", function(self)
		local l = {}
		local courant = GetCurrentMapDungeonLevel()
		for i = 1, GetNumDungeonMapLevels() do
			table.insert(l, {
				text = nomEtage(i),
				checked = (i == courant),
				func = function() SetDungeonMapLevel(i) end,
			})
		end
		ouvrirMenu(self, l, self:GetWidth())
	end)
	b:Hide()
	return b
end

-- La place du nom : du bord gauche (+8) jusqu'a la fleche, qui deborde le
-- bouton de 1 a droite (RIGHT (1, -3)).
function W.largeurTexteEtage()
	local fleche = ForeverUI.AtlasEntry("common-dropdown-a-button")
	return G.etageL + 1 - (fleche and fleche[6] or 27) - G.etageTexteX
end

-- wordwrap="false" : un nom trop long se termine par des points de
-- suspension. On retire des caracteres (sans couper un caractere UTF-8)
-- jusqu'a ce que le nom tienne.
function W.ecrireElide(fs, texte, largeur)
	fs:SetText(texte)
	if not largeur or fs:GetStringWidth() <= largeur then
		return
	end
	local points = "..."
	local coupe = texte
	while #coupe > 0 do
		coupe = string.sub(coupe, 1, -2)
		-- un caractere UTF-8 coupe en son milieu part en entier
		while #coupe > 0 and string.byte(coupe, -1) >= 128 and string.byte(coupe, -1) < 192 do
			coupe = string.sub(coupe, 1, -2)
		end
		if #coupe > 0 and string.byte(coupe, -1) >= 192 then
			coupe = string.sub(coupe, 1, -2)
		end
		fs:SetText(coupe .. points)
		if fs:GetStringWidth() <= largeur then
			return
		end
	end
	fs:SetText(points)
end

local function rafraichirEtages()
	local b = W.etages
	if not b then
		return
	end
	if GetNumDungeonMapLevels and GetNumDungeonMapLevels() > 0 then
		W.ecrireElide(b.Text, nomEtage(GetCurrentMapDungeonLevel()), W.largeurTexteEtage())
		b:Show()
	else
		b:Hide()
	end
end

-- ------------------------------------------------------------ les coordonnees
-- WorldMapCoordsPanelTemplate : deux lignes de 100 x 15, GameFontHighlightSmall
-- a gauche ; le curseur seulement quand la souris est sur la carte, le joueur
-- seulement quand il est sur la carte affichee (3.3.5 ne sait pas lire sa
-- position sur une autre carte sans changer celle qu'on regarde).

local function construireCoordonnees(carte)
	local c = CreateFrame("Frame", "ForeverUIWorldMapCoords", carte)
	c:SetWidth(G.coordL)
	c:SetHeight(G.coordH * 2)
	c:SetPoint("BOTTOMLEFT", carte, "TOPLEFT", G.carteX + G.coordX, G.carteY - G.carteH + G.coordY)
	local function ligne()
		local t = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		t:SetJustifyH("LEFT")
		t:SetWidth(G.coordL)
		t:SetHeight(G.coordH)
		return t
	end
	c.joueur = ligne()
	c.joueur:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	c.curseur = ligne()
	c.attente = 0
	c:SetScript("OnUpdate", function(self, ecoule)
		self.attente = self.attente - (ecoule or 0)
		if self.attente > 0 then
			return
		end
		self.attente = 0.05
		W.majCoordonnees()
	end)
	return c
end

function W.majCoordonnees()
	local c = W.coords
	if not c then
		return
	end
	local x, y = GetPlayerMapPosition("player")
	local joueur = x and y and not (x == 0 and y == 0)
	if joueur then
		c.joueur:SetText(string.format(TEXTE.joueur, math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5)))
		c.joueur:Show()
	else
		c.joueur:Hide()
	end

	local bouton = WorldMapButton
	local curseur = false
	if bouton and bouton:IsVisible() and bouton:IsMouseOver() then
		local cx, cy = GetCursorPosition()
		local echelle = bouton:GetEffectiveScale()
		cx, cy = cx / echelle, cy / echelle
		local gauche, haut = bouton:GetLeft(), bouton:GetTop()
		local l, h = bouton:GetWidth(), bouton:GetHeight()
		if gauche and haut and l > 0 and h > 0 then
			local nx, ny = (cx - gauche) / l, (haut - cy) / h
			if nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
				c.curseur:SetText(string.format(TEXTE.curseur, math.floor(nx * 100 + 0.5), math.floor(ny * 100 + 0.5)))
				curseur = true
			end
		end
	end
	c.curseur:ClearAllPoints()
	if joueur then
		c.curseur:SetPoint("BOTTOMLEFT", c.joueur, "TOPLEFT", 0, 0)
	else
		c.curseur:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	end
	if curseur then c.curseur:Show() else c.curseur:Hide() end
end

-- ------------------------------------------------------------------ les tuiles
-- WorldMapFrame.xml:541-636 : douze tuiles de 256 x 256 en 4 x 3, soit
-- 1024 x 768, pour une carte utile de 1002 x 668. WotLK ne rogne rien : sa
-- bordure (UI-WorldMapSmall-Left/Right, et l'habillage du plein ecran)
-- recouvre le debord. La bordure de camelot ne le recouvre pas : en petite
-- fenetre, on rogne donc la derniere colonne a 1002 - 768 = 234 et la
-- derniere rangee a 668 - 512 = 156. WorldMapFrame_Update recharge les
-- tuiles a chaque changement de carte : on repasse derriere lui.
local TUILES = { cote = 256, colonnes = 4, rangees = 3, utileL = 1002, utileH = 668 }

local function rognerTuiles(actif)
	local derniereL = TUILES.utileL - TUILES.cote * (TUILES.colonnes - 1)
	local derniereH = TUILES.utileH - TUILES.cote * (TUILES.rangees - 1)
	for rangee = 1, TUILES.rangees do
		for colonne = 1, TUILES.colonnes do
			local tuile = _G["WorldMapDetailTile" .. ((rangee - 1) * TUILES.colonnes + colonne)]
			if tuile then
				local l, h = TUILES.cote, TUILES.cote
				if actif and colonne == TUILES.colonnes then l = derniereL end
				if actif and rangee == TUILES.rangees then h = derniereH end
				tuile:SetWidth(l)
				tuile:SetHeight(h)
				tuile:SetTexCoord(0, l / TUILES.cote, 0, h / TUILES.cote)
			end
		end
	end
end
W.rognerTuiles = rognerTuiles

-- ----------------------------------------------------------- les boutons rouges

local function habillerBoutonsRouges(carte, cadre)
	local fermer = WorldMapFrameCloseButton
	if fermer then
		fermer:SetFrameStrata("HIGH")
		fermer:SetFrameLevel(cadre:GetFrameLevel() + 4)
		fermer:SetWidth(G.boutonCote)
		fermer:SetHeight(G.boutonCote)
		fermer:SetHitRectInsets(0, 0, 0, 0)
		etatBouton(fermer, "Normal", "redbutton-exit")
		etatBouton(fermer, "Pushed", "redbutton-exit-pressed")
		etatBouton(fermer, "Disabled", "redbutton-exit-disabled")
		local s = etatBouton(fermer, "Highlight", "redbutton-highlight")
		if s then s:SetBlendMode("ADD") end
	end
	local agrandir = WorldMapFrameSizeUpButton
	if agrandir then
		agrandir:SetFrameStrata("HIGH")
		agrandir:SetFrameLevel(cadre:GetFrameLevel() + 4)
		agrandir:SetWidth(G.boutonCote)
		agrandir:SetHeight(G.boutonCote)
		agrandir:SetHitRectInsets(0, 0, 0, 0)
		etatBouton(agrandir, "Normal", "redbutton-expand")
		etatBouton(agrandir, "Pushed", "redbutton-expand-pressed")
		etatBouton(agrandir, "Disabled", "redbutton-expand-disabled")
		local s = etatBouton(agrandir, "Highlight", "redbutton-highlight")
		if s then s:SetBlendMode("ADD") end
	end
end

-- ------------------------------------------------------- la bascule du volet
-- WorldMapSidePanelToggleTemplate : deux boutons de 32 x 32 au meme endroit,
-- l'un pour ouvrir (QuestCollapse-Show), l'autre pour fermer (QuestCollapse-
-- Hide), chacun sur l'ombre MapCornerShadow-Right, survol
-- UI-Common-MouseHilight en ADD 48 x 48.
local function construireBascule(carte)
	local cadre = CreateFrame("Frame", "ForeverUIWorldMapSidePanelToggle", carte)
	cadre:SetWidth(G.basculeCote)
	cadre:SetHeight(G.basculeCote)
	cadre:SetPoint("BOTTOMRIGHT", carte, "TOPLEFT",
		G.carteX + G.carteL + G.basculeX, G.carteY - G.carteH + G.basculeY)
	local function bouton(prefixe)
		local b = CreateFrame("Button", nil, cadre)
		b:SetAllPoints(cadre)
		local ombre = b:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(ombre, "mapcornershadow-right")
		ombre:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1)
		etatBouton(b, "Normal", prefixe .. "-up")
		etatBouton(b, "Pushed", prefixe .. "-down")
		b:SetHighlightTexture(NAV.survolCarre)
		local s = b:GetHighlightTexture()
		s:ClearAllPoints()
		s:SetWidth(48)
		s:SetHeight(48)
		s:SetPoint("CENTER", b, "CENTER", 0, 0)
		s:SetBlendMode("ADD")
		b:SetScript("OnClick", function()
			PlaySound("igMainMenuOptionCheckBoxOn")
			if ForeverUI.QuestLog then
				ForeverUI.QuestLog.basculerVolet()
			end
		end)
		return b
	end
	cadre.ouvrir = bouton("questcollapse-show")
	cadre.fermer = bouton("questcollapse-hide")
	return cadre
end

local function voletOuvert()
	local J = ForeverUI.QuestLog
	return J and J.reglages and J.reglages().volet
end

-- -------------------------------------------------------------- l'assemblage

local function construire()
	local carte = WorldMapFrame
	if not carte or not WorldMapDetailFrame then
		dire("carte du monde : le client n'a pas WorldMapFrame.")
		return false
	end
	if W.construit then
		return true
	end
	if not ForeverUI.SetAtlas then
		dire("carte du monde : AtlasUtil.lua manque, rien n'est habille.")
		return false
	end
	-- le canevas : le rectangle de la carte, dans l'un ou l'autre mode
	W.canevas = CreateFrame("Frame", "ForeverUIWorldMapCanvas", carte)
	W.canevas:SetPoint("TOPLEFT", carte, "TOPLEFT", G.carteX, G.carteY)
	W.canevas:SetWidth(G.carteL)
	W.canevas:SetHeight(G.carteH)
	-- le support du mode agrandi : le cadre de camelot, en unites de
	-- l'interface
	W.agrandi = CreateFrame("Frame", "ForeverUIWorldMapMaximized", carte)
	W.fond = construireFond(carte)
	W.cadre = construireCadre(carte)
	W.barre = construireBarre(carte)
	W.filtres = construireFiltres(carte, W.barre)
	W.etages = construireEtages(carte)
	W.coords = construireCoordonnees(carte)
	W.bascule = construireBascule(carte)
	habillerBoutonsRouges(carte, W.cadre)
	W.nos = { W.fond, W.cadre, W.barre, W.filtres, W.coords, W.bascule }
	W.construit = true
	return true
end

-- L'ANCRAGE COMMUN AUX DEUX MODES : tout se pose sur un SUPPORT -- la carte
-- de WotLK en petite fenetre, le support agrandi sinon --, a l'echelle
-- `ech` (1 en petite fenetre ; en agrandi, ce qui ramene le plein ecran de
-- WotLK a l'unite de l'interface), autour d'un canevas de canL x canH.
local function ancrer(support, ech, canL, canH, agrandi)
	for _, f in ipairs(W.nos) do
		f:SetScale(ech)
	end
	W.etages:SetScale(ech)
	W.canevas:SetScale(ech)
	W.canevas:ClearAllPoints()
	W.canevas:SetPoint("TOPLEFT", support, "TOPLEFT", G.carteX, G.carteY)
	W.canevas:SetWidth(canL)
	W.canevas:SetHeight(canH)

	W.fond:ClearAllPoints()
	W.fond:SetAllPoints(support)
	local cadre = W.cadre
	cadre:ClearAllPoints()
	cadre:SetAllPoints(support)
	cadre.lisere:ClearAllPoints()
	cadre.lisere:SetPoint("TOPLEFT", cadre, "TOPLEFT", 2, G.lisereY)
	cadre.lisere:SetPoint("RIGHT", cadre, "LEFT", G.carteX + canL, 0)
	if agrandi then cadre.portraitCadre:Hide() else cadre.portraitCadre:Show() end
	-- les coins de gauche changent avec le portrait
	for _, coin in ipairs(METAL) do
		local t = cadre.coins[coin.cle]
		local a = agrandi and METAL_AGRANDI[coin.cle] or coin
		ForeverUI.SetAtlas(t, a.nom)
		t:ClearAllPoints()
		t:SetPoint(coin.point, cadre.metal, coin.point, a.x, a.y)
	end

	W.barre:ClearAllPoints()
	W.barre:SetPoint("TOPLEFT", support, "TOPLEFT", agrandi and G.barreXAgrandi or G.barreX, G.barreY)
	W.barre:SetPoint("BOTTOMRIGHT", support, "TOPLEFT", G.carteX + canL - 50, G.barreBas)
	W.etages:ClearAllPoints()
	W.etages:SetPoint("TOPLEFT", support, "TOPLEFT", G.carteX + G.etageX, G.carteY - G.etageY)
	W.coords:ClearAllPoints()
	W.coords:SetPoint("BOTTOMLEFT", support, "TOPLEFT", G.carteX + G.coordX, G.carteY - canH + G.coordY)
	W.bascule:ClearAllPoints()
	W.bascule:SetPoint("BOTTOMRIGHT", support, "TOPLEFT",
		G.carteX + canL + G.basculeX, G.carteY - canH + G.basculeY)

	-- les niveaux : le fond au niveau de la carte, sous WorldMapDetailFrame
	W.fond:SetFrameLevel(WorldMapFrame:GetFrameLevel())
	W.barre:SetFrameLevel(WorldMapPOIFrame:GetFrameLevel() + 2)
	W.coords:SetFrameLevel(WorldMapPOIFrame:GetFrameLevel() + 2)
	W.bascule:SetFrameLevel(WorldMapPOIFrame:GetFrameLevel() + 2)

	-- ce que WotLK montre, et que camelot n'a pas
	if WorldMapQuestShowObjectives then
		WorldMapQuestShowObjectives:Hide()
	end
	if WorldMapTrackQuest then
		WorldMapTrackQuest:SetAlpha(0)
		WorldMapTrackQuest:EnableMouse(false)
	end
	if WorldMapLevelDropDown then
		WorldMapLevelDropDown:Hide()
	end

	-- le titre, dans le bandeau
	local titre = WorldMapFrameTitle
	titre:SetParent(cadre.bandeau)
	titre:ClearAllPoints()
	titre:SetPoint("TOP", cadre.bandeau, "TOP", 0, G.titreTexteY)
	titre:SetPoint("LEFT", cadre.bandeau, "LEFT")
	titre:SetPoint("RIGHT", cadre.bandeau, "RIGHT")
	titre:SetText(agrandi and TEXTE.titreAgrandi or TEXTE.titre)

	-- les boutons rouges : fermer, et a sa gauche agrandir ou reduire
	local fermer = WorldMapFrameCloseButton
	fermer:SetScale(ech)
	fermer:ClearAllPoints()
	fermer:SetPoint("TOPRIGHT", support, "TOPRIGHT", G.fermerX, G.fermerY)
	local bascule = agrandi and WorldMapFrameSizeDownButton or WorldMapFrameSizeUpButton
	bascule:SetScale(ech)
	bascule:ClearAllPoints()
	bascule:SetPoint("RIGHT", fermer, "LEFT", G.agrandirX, 0)

	for _, f in ipairs(W.nos) do
		f:Show()
	end
	rognerTuiles(true)
	rafraichirBarre()
	rafraichirEtages()
end

-- LE MODE REDUIT : ce que WotLK vient de poser, on le repose a la maniere
-- de camelot. Appele apres WorldMap_ToggleSizeDown et apres
-- WorldMapFrame_SetMiniMode (que WorldMapFrame_ToggleAdvanced rappelle seul).
local function poserReduit()
	if not construire() or not enPetiteFenetre() then
		return
	end
	local carte = WorldMapFrame

	if WORLDMAP_SETTINGS.advanced then
		placerAncre()
	end
	local volet = voletOuvert()
	carte:SetWidth(G.largeur + (volet and G.largeurVolet or 0))
	carte:SetHeight(G.hauteur)

	WorldMapDetailFrame:ClearAllPoints()
	WorldMapDetailFrame:SetPoint("TOPLEFT", carte, "TOPLEFT", G.carteX / G.echelle, G.carteY / G.echelle)

	-- ce que la petite fenetre de WotLK montre, et que camelot n'a pas
	etouffer(WorldMapFrameMiniBorderLeft)
	etouffer(WorldMapFrameMiniBorderRight)
	ancrer(carte, 1, G.carteL, G.carteH, false)

	-- la barre de titre de WotLK (glisser, menu d'opacite) couvre le bandeau
	if WorldMapTitleButton then
		WorldMapTitleButton:ClearAllPoints()
		WorldMapTitleButton:SetPoint("TOPLEFT", carte, "TOPLEFT", G.titreX1, G.titreY)
		WorldMapTitleButton:SetPoint("TOPRIGHT", carte, "TOPRIGHT", G.titreX2 - 2 * G.boutonCote, G.titreY)
		WorldMapTitleButton:SetHeight(G.titreH)
	end

	if volet then
		W.bascule.fermer:Show()
		W.bascule.ouvrir:Hide()
	else
		W.bascule.fermer:Hide()
		W.bascule.ouvrir:Show()
	end
	if ForeverUI.QuestLog and ForeverUI.QuestLog.poser then
		ForeverUI.QuestLog.poser()
	end
end
W.poserReduit = poserReduit

-- LE MODE AGRANDI. Ce que le plein ecran de WotLK montre et que camelot n'a
-- pas : sa bordure (WorldMapFrameTexture1..18, chargees a chaque ouverture),
-- ses menus de continent et de zone, son bouton de zoom arriere, la liste,
-- le detail et les recompenses des quetes a droite (decision 1 : la carte
-- seule), ses fleches d'etage, et les deux cases.
local ETOUFFES_AGRANDI = {
	"WorldMapZoneMinimapDropDown", "WorldMapZoomOutButton", "WorldMapZoneDropDown",
	"WorldMapContinentDropDown", "WorldMapLevelUpButton", "WorldMapLevelDownButton",
	"WorldMapQuestScrollFrame", "WorldMapQuestDetailScrollFrame", "WorldMapQuestRewardScrollFrame",
}

local function etoufferPleinEcran()
	for i = 1, 18 do
		etouffer(_G["WorldMapFrameTexture" .. i])
	end
	for _, nom in ipairs(ETOUFFES_AGRANDI) do
		local f = _G[nom]
		if f then f:Hide() end
	end
end

-- La carte dans le canevas. Les deux vues de WotLK la reposent (et rechargent
-- leur echelle) a chaque passage : on repasse derriere elles.
local function poserCarteAgrandie()
	local s = W.echelleAgrandie
	if not s then return end
	WORLDMAP_QUESTLIST_SIZE = s
	WORLDMAP_FULLMAP_SIZE = s
	if WORLDMAP_SETTINGS.size ~= WORLDMAP_WINDOWED_SIZE then
		WORLDMAP_SETTINGS.size = s
	end
	WorldMapDetailFrame:SetScale(s)
	WorldMapButton:SetScale(s)
	WorldMapFrameAreaFrame:SetScale(s)
	WorldMapBlobFrame:SetScale(s)
	WorldMapBlobFrame.xRatio = nil
	WorldMapDetailFrame:ClearAllPoints()
	WorldMapDetailFrame:SetPoint("CENTER", W.canevas, "CENTER", 0, 0)
	if WorldMapFrame_SetPOIMaxBounds then
		WorldMapFrame_SetPOIMaxBounds()
	end
	etoufferPleinEcran()
end
W.poserCarteAgrandie = poserCarteAgrandie

local function poserAgrandi()
	if not construire() or enPetiteFenetre() then
		return
	end
	local carte = WorldMapFrame
	-- l'unite de l'interface dans le plein ecran de WotLK
	local k = UIParent:GetEffectiveScale() / carte:GetEffectiveScale()
	-- UpdateMaximizedSize, en unites de l'interface
	local ecranL, ecranH = UIParent:GetWidth(), UIParent:GetHeight()
	local dispo = ecranL - G.bordEcran
	local sansBorne = ((ecranH - G.bandeauH) * G.largeur) / (G.hauteur - G.bandeauH)
	local largeur = math.min(dispo, sansBorne)
	local hauteur = ((ecranH - G.bandeauH) * (largeur / sansBorne)) + G.bandeauH
	largeur, hauteur = math.floor(largeur), math.floor(hauteur)

	local support = W.agrandi
	support:SetScale(k)
	support:ClearAllPoints()
	support:SetPoint("TOP", carte, "TOP", 0, 0)
	support:SetWidth(largeur)
	support:SetHeight(hauteur)
	support:SetFrameLevel(carte:GetFrameLevel())

	local canL = largeur - G.carteX - G.carteDroite
	local canH = hauteur + G.carteY - G.carteBas
	W.dimensionsAgrandies = { largeur, hauteur, canL, canH, k }
	-- la carte tient dans le canevas, au centre (le canevas de camelot)
	local tenir = math.min(canL / G.carteUtileL, canH / G.carteUtileH)
	W.echelleAgrandie = tenir * k

	ancrer(support, k, canL, canH, true)
	poserCarteAgrandie()
	W.bascule:Hide()
	etatBouton(WorldMapFrameSizeDownButton, "Normal", "redbutton-condense")
	etatBouton(WorldMapFrameSizeDownButton, "Pushed", "redbutton-condense-pressed")
	local s = etatBouton(WorldMapFrameSizeDownButton, "Highlight", "redbutton-highlight")
	if s then s:SetBlendMode("ADD") end
	WorldMapFrameSizeDownButton:SetWidth(G.boutonCote)
	WorldMapFrameSizeDownButton:SetHeight(G.boutonCote)
	WorldMapFrameSizeDownButton:SetHitRectInsets(0, 0, 0, 0)
	WorldMapFrameSizeDownButton:SetFrameStrata("HIGH")
	WorldMapFrameSizeDownButton:SetFrameLevel(W.cadre:GetFrameLevel() + 4)
	if ForeverUI.QuestLog and ForeverUI.QuestLog.cacher then
		ForeverUI.QuestLog.cacher()
	end
end
W.poserAgrandi = poserAgrandi

-- (plus appele : le plein ecran est habille depuis l'etape 4) rendre au
-- client ce qu'on lui avait pris.
local function retirer()
	if not W.construit then
		return
	end
	for _, f in ipairs(W.nos) do
		f:Hide()
	end
	W.etages:Hide()
	rognerTuiles(false)
	if ForeverUI.QuestLog and ForeverUI.QuestLog.cacher then
		ForeverUI.QuestLog.cacher()
	end
	WorldMapFrameTitle:SetParent(WorldMapFrame)
	if WorldMapQuestShowObjectives then
		WorldMapQuestShowObjectives:Show()
	end
	if WorldMapTrackQuest then
		WorldMapTrackQuest:SetAlpha(1)
		WorldMapTrackQuest:EnableMouse(true)
	end
end
W.retirer = retirer

-- LES PORTAILS DES DONJONS ET DES RAIDS (demande du 2026-09-25) : cliquer
-- le portail d'une instance ouvre sa carte. Ces icones ne sont PAS des
-- reperes du client (AreaPOI.dbc n'en a aucun) : elles viennent de WDM ("WoW
-- Dungeon Maps - HD client", addon livre dans patch-enus-n.mpq), boutons
-- WorldMapFrameAtlasPOIn (releve en jeu par /fui souris). WDM leur donne le
-- clic des reperes de WotLK (WorldMapPOI_OnClick) avec mapLinkID = 0 : 0 est
-- vrai en Lua, et ClickLandmark(0) ne mene nulle part. Leur nom (celui de
-- LibBabble-Zone) donne la carte de l'instance (WorldMapInstances.lua, genere
-- des DBC du client) et SetMapByID l'ouvre. Les reperes de WotLK
-- (WorldMapFramePOIn) sans lien sont traites de meme. Les uns et les autres
-- naissent a la demande, pendant WorldMapFrame_Update -- WDM y greffe les
-- siens, peut-etre apres nous : on les branche a nouveau a l'image suivante.
local function carteDePortail(nom)
	local t = ForeverUI.CartesInstances
	return nom and t and t[string.lower(nom)]
end
W.carteDePortail = carteDePortail

local function ouvrirPortail(self, bouton)
	-- un vrai lien de carte : WotLK s'en charge
	if bouton ~= "LeftButton" or (self.mapLinkID and self.mapLinkID ~= 0) then return end
	local id = carteDePortail(self.name)
	if id and SetMapByID then SetMapByID(id) end
end

local function brancherPortails()
	for _, famille in ipairs({ { "WorldMapFramePOI", NUM_WORLDMAP_POIS },
		{ "WorldMapFrameAtlasPOI", NUM_WORLDMAP_ATLAS_POI } }) do
		for i = 1, (famille[2] or 0) do
			local b = _G[famille[1] .. i]
			if b and not b.foreverPortail then
				b.foreverPortail = true
				b:HookScript("OnClick", ouvrirPortail)
			end
		end
	end
end
W.brancherPortails = brancherPortails

local portailsSuivants = CreateFrame("Frame")
portailsSuivants:Hide()
portailsSuivants:SetScript("OnUpdate", function(self)
	self:Hide()
	brancherPortails()
end)
W.portailsSuivants = portailsSuivants

if hooksecurefunc then
	if WorldMap_ToggleSizeDown then
		hooksecurefunc("WorldMap_ToggleSizeDown", poserReduit)
	end
	if WorldMapFrame_SetMiniMode then
		hooksecurefunc("WorldMapFrame_SetMiniMode", poserReduit)
	end
		if WorldMap_ToggleSizeUp then
		hooksecurefunc("WorldMap_ToggleSizeUp", poserAgrandi)
	end
	-- les deux vues du plein ecran reposent la carte et son echelle
	for _, nom in ipairs({ "WorldMapFrame_SetQuestMapView", "WorldMapFrame_SetFullMapView" }) do
		if _G[nom] then
			hooksecurefunc(nom, function()
				if W.construit and not enPetiteFenetre() then
					poserCarteAgrandie()
				end
			end)
		end
	end
	-- en petite fenetre, WotLK ecrit le nom de la zone dans le titre ; camelot
	-- garde MAP_AND_QUEST_LOG
	if WorldMapFrame_SetMapName then
			hooksecurefunc("WorldMapFrame_SetMapName", function()
			if W.construit then
				WorldMapFrameTitle:SetText(enPetiteFenetre() and TEXTE.titre or TEXTE.titreAgrandi)
			end
		end)
	end
	-- le menu des etages de WotLK se remontre a chaque mise a jour
	if WorldMapLevelDropDown_Update then
			hooksecurefunc("WorldMapLevelDropDown_Update", function()
			if W.construit then
				WorldMapLevelDropDown:Hide()
				rafraichirEtages()
			end
		end)
	end
	-- a chaque ouverture en petite fenetre : le volet a pu changer d'etat
	-- pendant que la carte etait fermee (L, bouton du volet)
	if WorldMapFrame and WorldMapFrame.HookScript then
		-- en plein ecran, l'echelle n'est connue qu'ici (SetupFullscreenScale)
		-- LA PREMIERE OUVERTURE construit l'habillage : ouverte d'emblee en
		-- plein ecran, la carte gardait celui de WotLK jusqu'a un aller-retour
		-- par la petite fenetre (2026-09-25) -- seules les bascules et
		-- WorldMapFrame_SetMiniMode le construisaient
		WorldMapFrame:HookScript("OnShow", function()
			local premiere = not W.construit
			if enPetiteFenetre() then
				poserReduit()
			else
				poserAgrandi()
			end
			-- ce que les greffes de WotLK auraient pose sur une carte deja
			-- construite
			if premiere and W.construit then
				rognerTuiles(true)
				rafraichirBarre()
				rafraichirEtages()
			end
		end)
	end
	-- WorldMapFrame_Update recharge les tuiles de la carte affichee
	if WorldMapFrame_Update then
			hooksecurefunc("WorldMapFrame_Update", function()
			if W.construit then
				rognerTuiles(true)
			end
			brancherPortails()
			portailsSuivants:Show()
		end)
	end
	-- chaque changement de carte refait le fil d'Ariane
	if WorldMapFrame_UpdateMap then
			hooksecurefunc("WorldMapFrame_UpdateMap", function()
			if W.construit then
				rafraichirBarre()
				rafraichirEtages()
			end
		end)
	end
	-- DisplayQuests remontre la case de suivi a chaque quete
	if WorldMapFrame_DisplayQuests then
			hooksecurefunc("WorldMapFrame_DisplayQuests", function()
			if W.construit and WorldMapTrackQuest then
				WorldMapTrackQuest:SetAlpha(0)
				WorldMapTrackQuest:EnableMouse(false)
			end
		end)
	end
end

-- l'ecran change de taille : le mode agrandi se recalcule
local veille = CreateFrame("Frame")
veille:RegisterEvent("DISPLAY_SIZE_CHANGED")
veille:RegisterEvent("UI_SCALE_CHANGED")
veille:SetScript("OnEvent", function()
	if W.construit and WorldMapFrame:IsShown() and not enPetiteFenetre() then
		poserAgrandi()
	end
end)

ForeverUI.WorldMapDebug = function()
	local carte = WorldMapFrame
	if not carte then
		dire("carte du monde : absente.")
		return
	end
	local function ligne(texte)
		DEFAULT_CHAT_FRAME:AddMessage("   " .. texte)
	end
	-- les reperes de la carte affichee, et la carte d'instance que leur nom
	-- donne
	for i = 1, (GetNumMapLandmarks and GetNumMapLandmarks() or 0) do
		local nom, description, icone, x, y, lien = GetMapLandmarkInfo(i)
		ligne(string.format("repere %d : %s (%s) icone %s, lien %s, carte d'instance %s", i, tostring(nom),
			tostring(description), tostring(icone), tostring(lien), tostring(carteDePortail(nom))))
	end
	dire(string.format("carte du monde : %.0f x %.0f, mode %s (taille %.4f, petite fenetre %.4f)",
		carte:GetWidth(), carte:GetHeight(),
		enPetiteFenetre() and "reduit" or "plein ecran",
		WORLDMAP_SETTINGS.size, WORLDMAP_WINDOWED_SIZE))
	ligne(string.format("carte %.0f x %.0f a l'echelle %.4f -> %.1f x %.1f a l'ecran",
		WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight(),
		WorldMapDetailFrame:GetScale(),
		WorldMapDetailFrame:GetWidth() * WorldMapDetailFrame:GetScale(),
		WorldMapDetailFrame:GetHeight() * WorldMapDetailFrame:GetScale()))
	local noms = {}
	for _, d in ipairs(hierarchie()) do
		table.insert(noms, d.name or "?")
	end
	ligne("fil d'Ariane : " .. TEXTE.monde .. (#noms > 0 and (" > " .. table.concat(noms, " > ")) or ""))
	ligne(string.format("etages : %d | construit : %s | panneau : %s",
		GetNumDungeonMapLevels and GetNumDungeonMapLevels() or 0,
		tostring(W.construit), tostring(carte:GetAttribute("UIPanelLayout-area"))))
	ligne(string.format("deplacable : %s (advancedWorldMap %s, verrou %s)",
		tostring(carte:IsMovable()), tostring(GetCVar("advancedWorldMap")),
		tostring(WORLDMAP_SETTINGS.locked)))
end
