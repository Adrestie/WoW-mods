-- ForeverUI : la carte du maitre de vol (TaxiFrame), a la DA de camelot
-- (chantier des PNJ, etape 3, demande de l'utilisateur du 2026-09-28 ;
-- reprise le meme jour : trajets faux, points mal places).
--
-- QUELLE FENETRE. camelot (blizzard_game/mainline, HandleTaxiMapOpened)
-- ouvre le TaxiFrame quand la carte de vol est du systeme « Taxi », la
-- grande FlightMapFrame sinon. Ses cartes de vol sont les UiMap 1463
-- (Royaumes de l'Est) et 1464 (Kalimdor), System = 1 (Taxi) : une image de
-- 512 x 512, sans zoom (UiMapArtStyleLayer 4). C'est donc le TaxiFrame.
--
-- RELEVE -- CAMELOT (blizzard_uipanels_game/shared/taxiframe.xml et .lua,
-- charges pour mainline ; DrawLine de blizzard_sharedxml/mixinutil.lua) :
--   TaxiFrame      BasicFrameTemplateWithInset 590 x 608 : roche, bande de
--                  titre, stries, coins et bords UI-Frame (gris),
--                  coin UI-Frame-TopLeftCornerNoPortrait ; titre FLIGHT_MAP,
--                  GameFontNormal TOP (-6, -4) ; croix (-2, 1)
--   la carte       InsetBg de (4, -24) a (-6, 4), 580 x 580, sans mosaique,
--                  SetTaxiMap(InsetBg) : l'image de la carte de vol entiere ;
--                  liseré UI-Frame-Inner* autour ; TaxiRouteMap sur la carte
--   les boutons    TaxiButtonTemplate 16 x 16, surbrillance UI-Taxi-Icon-
--                  Highlight 32 x 32 au centre ; images TaxiButtonTypes :
--                  courant UI-Taxi-Icon-Green (surbrillance 0), joignable
--                  -White (1), lointain -Nub (0, cache hors d'un trajet) ;
--                  poses au CENTER sur le BOTTOMLEFT de la carte, a x * 580,
--                  (1 - y) * 580, arrondis ; repousses a TAXI_BUTTON_MIN_DIST
--                  = 18 d'un precedent (un lointain ne pousse pas un point
--                  qui ne l'est pas) ; clic : TakeTaxiNode
--   les trajets    UI-Taxi-Line dans TaxiRouteMap (BACKGROUND), DrawLine(...,
--                  32, TAXIROUTE_LINEFACTOR = 32 / 30), entre les positions
--                  POUSSEES ; a l'ouverture, DrawOneHopLines : les vols
--                  directs ; au survol d'un joignable, les etapes de son
--                  trajet reprennent les memes traits (les autres se
--                  cachent), les lointains traverses se montrent ; au survol
--                  du courant, DrawOneHopLines de nouveau
--   l'infobulle    ANCHOR_RIGHT : nom ; prix (joignable) ; TAXINODEYOUAREHERE
--                  en blanc (courant)
--
-- RELEVE -- 3.3.5 (FrameXML/TaxiFrame.xml et .lua) : 384 x 512, portrait
-- TaxiPortrait, quatre UI-TaxiFrame-* sans nom, TaxiMerchant, TaxiMap 316 x
-- 352 (OVERLAY), TaxiRouteMap et ses TaxiButton<i>, croix (-29, -8).
-- TaxiFrame_OnEvent (TAXIMAP_OPENED) pose l'image (SetTaxiMap : Interface\
-- TaxiFrame\TAXIMAP<carte>), les boutons a x * 316, y * 352 depuis le BAS,
-- puis ShowUIPanel ; son OnShow trace les vols directs (DrawOneHopLines).
-- Positions en fractions de SA carte de vol : un carre du monde (TaxiMin /
-- TaxiMax de WorldMapContinent.dbc). Types CURRENT, REACHABLE, DISTANT, NONE.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * Les boutons, les traits et la carte sont a nous ; la TaxiRouteMap du
--     client (ses boutons, ses traits) est eteinte, sa TaxiMap invisible (le
--     client y pose l'image : son nom dit le continent).
--   * L'image : celle de camelot pour les Royaumes de l'Est (1463, fichier
--     8033753) et Kalimdor (1464, taximap1-classic). Kalimdor couvre le meme
--     carre du monde qu'en 3.3.5 ; les Royaumes de l'Est un carre plus serre
--     (UiMapAssignment 1463 : X -15980 a 5817, Y -11880 a 9917) : les
--     positions y sont reportees. L'Outreterre et le Norfendre n'existent pas
--     dans camelot : l'image de 3.3.5.
--   * Les zones de Burning Crusade (Quel'Thalas, iles draeneies) n'existent
--     pas dans camelot : son image ne les dessine pas. Leur place sur les
--     continents vient de WorldMapTransforms.dbc. Quand le point courant ou
--     une destination joignable y est (ou hors de l'image), la fenetre garde
--     l'image de 3.3.5 ; un point lointain qui y est n'est pas montre.
--   * 3.3.5 n'a ni TaxiGetNodeSlot ni TaxiIsDirectFlight : les etapes sont
--     rendues a leurs points par leurs positions (TaxiGetSrcX...), un vol
--     direct est un trajet d'une etape (GetNumRoutes, comme 3.3.5).
--   * Le trait : DrawRouteLine du client, qui est le DrawLine de camelot
--     (meme calcul, meme facteur 32 / 30).
--   * « Aucun vol connu » (ERR_TAXINOPATHS) reste au client : son propre
--     DrawOneHopLines le dit et ferme la fenetre.
--   * Au survol d'un point joignable, TaxiNodeSetCurrent(point) est appele,
--     comme le fait le TaxiNodeOnButtonEnter de 3.3.5.
--   * Le titre FLIGHT_MAP n'existe pas en 3.3.5 : texte de l'addon.
--   * LE CADRE (choix de l'utilisateur, 28/09) : le metal bronze des autres
--     fenetres de camelot, sans portrait (disposition ButtonFrameTemplate-
--     NoPortrait, variantes c60), sur le fond de roche et les stries de
--     PortraitFrameTemplate, titre a la place du TitleContainer sans
--     portrait. Les pieces UI-Frame de BasicFrameTemplate sont grises dans
--     le client camelot (uiframe, sans variante c60) : l'utilisateur les veut
--     aux couleurs des autres fenetres.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits
local L = ForeverUI.L

local V = {}
ForeverUI.MaitreDeVol = V

local SEP = string.char(92)
local DOSSIER = "Interface" .. SEP .. "ForeverUI" .. SEP .. "taxiframe" .. SEP

local N = {
	fenetre = { 590, 608 },
	carte = { 4, -24, -6, 4 },     -- InsetBg : 580 x 580
	cote = 580,                    -- TAXI_MAP_WIDTH / HEIGHT de camelot
	bouton = 16, lueur = 32,
	ecartMin = 18,                 -- TAXI_BUTTON_MIN_DIST
	trait = 32,
	fond = { 2, -21, -2, 2 },       -- Bg de PortraitFrameTemplate
	stries = { 6, -21, -2, -21, 43 },
	titreCadre = { 0, -1, 20, -5 },  -- TitleContainer sans portrait, texte a -5
	niveaux = { routes = 1, metal = 20, titre = 21, croix = 22 },
}

-- TaxiButtonTypes de camelot, depuis les types de 3.3.5
local TYPES = {
	CURRENT = { fichier = DOSSIER .. "ui-taxi-icon-green", lueur = 0 },
	REACHABLE = { fichier = DOSSIER .. "ui-taxi-icon-white", lueur = 1 },
	DISTANT = { fichier = DOSSIER .. "ui-taxi-icon-nub", lueur = 0 },
}

-- les cartes de vol que camelot connait : image, carre du monde de 3.3.5
-- (WorldMapContinent.dbc : minX, minY, maxX, maxY), carre de camelot
-- (UiMapAssignment), place des zones de Burning Crusade (WorldMapTransforms
-- .dbc : region + decalage)
local CAMELOT = {
	[0] = {
		image = DOSSIER .. "taximap-1463",
		taxi = { -16530, -16530, 12270, 12270 },
		camelot = { -15980, -11880, 5817, 9917 },
		bc = { 2400, -7733.3330078125, 13600, -266.666748046875 },
	},
	[1] = {
		image = DOSSIER .. "taximap1-classic",
		taxi = { -11870, -13370, 12470, 10970 },
		camelot = { -11870, -13370, 12470, 10970 },
		bc = { 3199.99951171875, 1600, 10666.666320800781, 9600 },
	},
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- ------------------------------------------------------------ les positions

-- une position de la carte de vol de 3.3.5 (u depuis la gauche, v depuis le
-- bas) : sur l'image de camelot (fractions, y depuis le BAS), et si elle
-- tombe dans une zone de Burning Crusade
local function versCamelot(C, u, v)
	local T, K, B = C.taxi, C.camelot, C.bc
	local mondeY = T[4] - u * (T[4] - T[2])
	local mondeX = T[1] + v * (T[3] - T[1])
	local cu = (K[4] - mondeY) / (K[4] - K[2])
	local cv = (mondeX - K[1]) / (K[3] - K[1])
	local bc = mondeX >= B[1] and mondeX <= B[3] and mondeY >= B[2] and mondeY <= B[4]
	return cu, cv, bc
end
V.VersCamelot = versCamelot

local function dedans(cu, cv)
	return cu >= 0 and cu <= 1 and cv >= 0 and cv <= 1
end

-- ------------------------------------------------------------ les traits

local function trait(i)
	local h = V.habit
	local t = h.traits[i]
	if not t then
		t = h.routes:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(DOSSIER .. "ui-taxi-line")
		h.traits[i] = t
	end
	return t
end

-- le bouton de 3.3.5 a cette position (les etapes d'un trajet sont donnees
-- par leurs positions)
local function boutonA(x, y)
	local meilleur, ecart
	for _, b in pairs(V.habit.boutons) do
		if b.actif then
			local d = math.abs(b.u - x) + math.abs(b.v - y)
			if not ecart or d < ecart then meilleur, ecart = b, d end
		end
	end
	if ecart and ecart < 0.001 then return meilleur end
end

local function etape(i, r)
	return boutonA(TaxiGetSrcX(i, r), TaxiGetSrcY(i, r)), boutonA(TaxiGetDestX(i, r), TaxiGetDestY(i, r))
end

local function relier(t, depart, arrivee)
	DrawRouteLine(t, V.habit.routes, depart.x, depart.y, arrivee.x, arrivee.y, N.trait)
	t:Show()
end

-- DrawOneHopLines : les vols directs depuis le point courant
function V.VolsDirects()
	local h = V.habit
	local n = 0
	for i = 1, NumTaxiNodes() do
		local b = h.boutons[i]
		if b and b.actif then
			if b.genre == "REACHABLE" and GetNumRoutes(i) == 1 then
				local depart, arrivee = etape(i, 1)
				if depart and arrivee then
					n = n + 1
					relier(trait(n), depart, arrivee)
				end
			elseif b.genre == "DISTANT" then
				b:Hide()
			end
		end
	end
	for i = n + 1, #h.traits do h.traits[i]:Hide() end
end

-- ------------------------------------------------------------ les boutons

local function surEntree(b)
	local h = V.habit
	local i = b:GetID()
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	GameTooltip:AddLine(TaxiNodeName(i), nil, nil, nil, true)
	if b.genre ~= "DISTANT" then
		-- les lointains caches d'abord
		for _, a in pairs(h.boutons) do
			if a.actif and a.genre == "DISTANT" then a:Hide() end
		end
	end
	if b.genre == "REACHABLE" then
		SetTooltipMoney(GameTooltip, TaxiNodeCost(i))
		TaxiNodeSetCurrent(i)
		local n = GetNumRoutes(i)
		for r = 1, math.max(n, #h.traits) do
			if r <= n then
				local depart, arrivee = etape(i, r)
				if depart and arrivee then
					relier(trait(r), depart, arrivee)
					if arrivee.genre == "DISTANT" then arrivee:Show() end
				elseif h.traits[r] then
					h.traits[r]:Hide()
				end
			else
				h.traits[r]:Hide()
			end
		end
	elseif b.genre == "CURRENT" then
		GameTooltip:AddLine(TAXINODEYOUAREHERE, 1, 1, 1, true)
		V.VolsDirects()
	end
	GameTooltip:Show()
end

local function surSortie()
	GameTooltip:Hide()
end

local function creerBouton(i)
	local h = V.habit
	local b = CreateFrame("Button", "ForeverUITaxiButton" .. i, h.routes)
	b:SetWidth(N.bouton)
	b:SetHeight(N.bouton)
	b:SetNormalTexture(TYPES.REACHABLE.fichier)
	b:SetHighlightTexture(DOSSIER .. "ui-taxi-icon-highlight")
	local l = b:GetHighlightTexture()
	l:ClearAllPoints()
	l:SetWidth(N.lueur)
	l:SetHeight(N.lueur)
	l:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetScript("OnEnter", surEntree)
	b:SetScript("OnLeave", surSortie)
	b:SetScript("OnClick", function(self) TakeTaxiNode(self:GetID()) end)
	h.boutons[i] = b
	return b
end

-- ------------------------------------------------------------ l'ouverture

-- APRES le OnEvent du client (TAXIMAP_OPENED) : l'image, les boutons, les
-- vols directs
function V.Ouvrir()
	local h = V.habit
	if not h then return end
	local chemin = TaxiMap:GetTexture()
	local carte = type(chemin) == "string" and tonumber(string.match(string.lower(chemin), "taximap(%d+)"))
	local C = carte and CAMELOT[carte]
	-- les points, et l'image qu'ils permettent
	local points = {}
	for i = 1, NumTaxiNodes() do
		local genre = TaxiNodeGetType(i)
		if TYPES[genre] then
			local u, v = TaxiNodePosition(i)
			local p = { genre = genre, u = u, v = v }
			if C then
				p.cu, p.cv, p.bc = versCamelot(C, u, v)
				if genre ~= "DISTANT" and (p.bc or not dedans(p.cu, p.cv)) then C = nil end
			end
			points[i] = p
		end
	end
	V.imageCamelot = C and true or false
	h.carte:SetTexCoord(0, 1, 0, 1)
	h.carte:SetTexture(C and C.image or chemin)
	for _, b in pairs(h.boutons) do
		b.actif = false
		b:Hide()
	end
	-- les boutons, repousses a 18 d'un precedent
	local places = {}
	for i = 1, NumTaxiNodes() do
		local p = points[i]
		local montrable = p and (not C or (not p.bc and dedans(p.cu, p.cv)))
		if montrable then
			local x, y
			if C then
				x, y = p.cu * N.cote, p.cv * N.cote
			else
				x, y = p.u * N.cote, p.v * N.cote
			end
			for j = 1, i - 1 do
				local q = places[j]
				if q and (p.genre == "DISTANT" or q.genre ~= "DISTANT") then
					local dx, dy = x - q.x, y - q.y
					local d2 = dx * dx + dy * dy
					if d2 < N.ecartMin * N.ecartMin then
						local k = N.ecartMin
						if d2 > 0 then k = N.ecartMin / math.sqrt(d2) end
						x, y = q.x + dx * k, q.y + dy * k
					end
				end
			end
			places[i] = { x = x, y = y, genre = p.genre }
			local b = h.boutons[i] or creerBouton(i)
			b:SetID(i)
			b.actif, b.genre, b.u, b.v, b.x, b.y = true, p.genre, p.u, p.v, x, y
			poser(b, "CENTER", h.carte, "BOTTOMLEFT", math.floor(x + 0.5), math.floor(y + 0.5))
			local T = TYPES[p.genre]
			b:SetNormalTexture(T.fichier)
			b:GetHighlightTexture():SetAlpha(T.lueur)
			if p.genre == "DISTANT" then b:Hide() else b:Show() end
		end
	end
	V.VolsDirects()
end

function V.ApresEvenement(self, evenement)
	if evenement == "TAXIMAP_OPENED" then V.Ouvrir() end
end

-- ------------------------------------------------------------ la fenetre

function V.Habiller()
	local f = TaxiFrame
	if not f or f.foreverHabit then return end
	-- l'art de 3.3.5 (les quatre UI-TaxiFrame-* sans nom), le portrait et le
	-- nom du marchand : camelot n'a ni l'un ni l'autre ; la carte du client
	-- invisible, sa TaxiRouteMap (boutons, traits) eteinte
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" and string.find(string.lower(t), "ui-taxiframe", 1, true) then
				r:SetAlpha(0)
			end
		end
	end
	TaxiPortrait:SetAlpha(0)
	TaxiMerchant:SetAlpha(0)
	TaxiMap:SetAlpha(0)
	ForeverUI.Suppress(TaxiRouteMap)
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	local habit = {}
	f.foreverHabit = habit
	V.habit = habit
	-- le fond de roche et les stries (PortraitFrameTemplate)
	local F, S = N.fond, N.stries
	local roche = f:CreateTexture(nil, "BACKGROUND")
	roche:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock", true)
	if roche.SetHorizTile then roche:SetHorizTile(true) roche:SetVertTile(true) end
	roche:SetPoint("TOPLEFT", f, "TOPLEFT", F[1], F[2])
	roche:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", F[3], F[4])
	local stries = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(stries, "_ui-frame-toptilestreaks", true)
	stries:SetHeight(S[5])
	stries:SetPoint("TOPLEFT", f, "TOPLEFT", S[1], S[2])
	stries:SetPoint("TOPRIGHT", f, "TOPRIGHT", S[3], S[4])
	habit.roche, habit.stries = roche, stries
	-- le metal bronze, sans portrait, au-dessus de tout le reste
	local metal = CreateFrame("Frame", nil, f)
	metal:SetAllPoints(f)
	metal:SetFrameLevel(f:GetFrameLevel() + N.niveaux.metal)
	habit.metal = Gb.NeufTranches(metal, "ButtonFrameTemplateNoPortrait", f)
	-- la carte, en BORDER : sous le liseré (ARTWORK) et les bords (OVERLAY)
	local C = N.carte
	local carte = f:CreateTexture(nil, "BORDER")
	carte:SetPoint("TOPLEFT", f, "TOPLEFT", C[1], C[2])
	carte:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", C[3], C[4])
	habit.carte = carte
	habit.lisere = Gb.NeufTranches(f, "InsetFrameTemplate", carte, "ARTWORK")
	-- la TaxiRouteMap de camelot : sur la carte, les traits et les boutons
	local routes = CreateFrame("Frame", "ForeverUITaxiRouteMap", f)
	routes:SetAllPoints(carte)
	routes:SetFrameLevel(f:GetFrameLevel() + N.niveaux.routes)
	habit.routes, habit.traits, habit.boutons = routes, {}, {}
	-- le titre (TitleContainer sans portrait), au-dessus du metal
	local T = N.titreCadre
	local conteneur = CreateFrame("Frame", nil, f)
	conteneur:SetHeight(T[3])
	conteneur:SetPoint("TOPLEFT", f, "TOPLEFT", T[1], T[2])
	conteneur:SetPoint("TOPRIGHT", f, "TOPRIGHT", -T[1], T[2])
	conteneur:SetFrameLevel(f:GetFrameLevel() + N.niveaux.titre)
	local titre = conteneur:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titre:SetPoint("TOP", conteneur, "TOP", 0, T[4])
	titre:SetPoint("LEFT", conteneur, "LEFT")
	titre:SetPoint("RIGHT", conteneur, "RIGHT")
	titre:SetText(L.TAXI_TITLE)
	habit.titre = titre
	Gb.Croix(TaxiCloseButton, f)
	TaxiCloseButton:SetFrameLevel(f:GetFrameLevel() + N.niveaux.croix)
	-- le XML lie OnEvent a TaxiFrame_OnEvent lui-meme (function=) : une
	-- accroche sur la globale ne serait jamais appelee ; on suit le script
	f:HookScript("OnEvent", V.ApresEvenement)
end

V.Habiller()
