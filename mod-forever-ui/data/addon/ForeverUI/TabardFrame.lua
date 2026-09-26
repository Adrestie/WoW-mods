-- ForeverUI : la fenetre de creation du tabard de guilde, facon camelot
-- (demande de l'utilisateur, 2026-09-26).
--
-- RELEVE -- camelot charge blizzard_uipanels_game/mainline/tabardframe.xml et
-- .lua ([Family], pas de variante camelot). La fenetre garde les images de
-- WotLK (le cadre du tabard TabardFrameOuterFrame, le panneau de
-- personnalisation, les etiquettes CharacterCreate-LabelFrame, les fleches,
-- la rotation) ; ce qui change :
--   enveloppe    ButtonFrameTemplate, 338 x 424 (PortraitFrameBaseTemplate) :
--                fond UI-Background-Rock (2, -21 / -2, 2), stries (6, -21 /
--                -2, -21), metal a portrait, croix rouge 24 x 24 a TOPRIGHT
--                (-2, 1), encadre InsetFrameTemplate (4, -60 / -6, 26) ;
--                plus de grand fond TabardFrameBackground ni de cadre de
--                WotLK (UI-Character-General-*, UI-ClassTrainer-Bot*)
--   places       (valeurs de camelot, celles de WotLK entre parentheses)
--                cadre du tabard TOPLEFT (8, -63)          ((19, -73))
--                nom du marchand CENTER (6, 202)           ((6, 232))
--                accueil TOP (15, -28)                     ((10, -39))
--                modele BOTTOM (0, 38)                     ((-14, 114))
--                rotation BOTTOMLEFT (14, 33)              ((26, 110))
--                personnalisation BOTTOMRIGHT (26, -28)    ((-9, 50))
--                argent BOTTOMRIGHT sur BOTTOMLEFT (175, 8) ((183, 86))
--                Accept / Cancel CENTER sur TOPLEFT (213 / 294, -409)
--                                                          ((224 / 305, -420))
--   argent       un encadre InsetFrameTemplate de BOTTOMLEFT (4, 4) a
--                TOPRIGHT sur BOTTOMLEFT (170, 25), et le bord dore
--                ThinGoldEdgeTemplate (Interface\Common\Moneyframe, trois
--                morceaux) de BOTTOMLEFT (7, 6) a TOPRIGHT sur BOTTOMLEFT
--                (166, 24)
-- Le reste -- l'embleme en filigrane, le cout, les cinq reglages -- garde les
-- memes ancres dans les deux clients : il suit le cadre.
--
-- ECART : camelot pose le portrait du marchand a (7, -6) en BACKGROUND
-- (TabardFramePortrait), sous l'anneau de metal ; le cadre a portrait, lui, a
-- son anneau a (-5, 7). Le portrait est pose ici DANS L'ANNEAU (60 x 60 a
-- (-5, 7)), comme la fenetre Social.
--
-- La fenetre reste celle du client (TabardFrame, TabardModel et leurs
-- fonctions) : on la retaille, on replace ses pieces, on l'habille ; aucun de
-- ses cadres ne change de parent.
--
-- LES COUCHES. Camelot pose ses encadres en cadres fils au niveau de la
-- fenetre (useParentLevel) ; en 3.3.5, deux cadres de meme niveau se dessinent
-- dans un ordre indetermine, et l'encadre pourrait couvrir le cadre du tabard
-- et l'embleme en filigrane, qui sont des regions de la fenetre. L'encadre et
-- le bord dore sont donc des REGIONS de la fenetre elle-meme : roche en
-- BACKGROUND, marbre en BORDER, liseres et bord dore en ARTWORK, sous le cadre
-- du tabard et l'embleme (OVERLAY). Des cadres vides servent de reperes.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local SEP = string.char(92)

local P = {
	largeur = 338, hauteur = 424,
	roche = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock",
	argent = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	portraitCote = 60, portraitX = -5, portraitY = 7,
	croix = 24, croixX = -2, croixY = 1,
}

local METAL = {
	{ cle = "hg", nom = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ cle = "hd", nom = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ cle = "bg", nom = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ cle = "bd", nom = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

-- les places de camelot : { region, point, relatif, point relatif, x, y }
local PLACES = {
	{ "TabardFrameOuterFrameTopLeft", "TOPLEFT", "TabardFrame", "TOPLEFT", 8, -63 },
	{ "TabardFrameGreetingText", "TOP", "TabardFrame", "TOP", 15, -28 },
	{ "TabardModel", "BOTTOM", "TabardFrame", "BOTTOM", 0, 38 },
	{ "TabardCharacterModelRotateLeftButton", "BOTTOMLEFT", "TabardFrame", "BOTTOMLEFT", 14, 33 },
	{ "TabardFrameCustomizationBorder", "BOTTOMRIGHT", "TabardFrame", "BOTTOMRIGHT", 26, -28 },
	{ "TabardFrameMoneyFrame", "BOTTOMRIGHT", "TabardFrame", "BOTTOMLEFT", 175, 8 },
	{ "TabardFrameAcceptButton", "CENTER", "TabardFrame", "TOPLEFT", 213, -409 },
	{ "TabardFrameCancelButton", "CENTER", "TabardFrame", "TOPLEFT", 294, -409 },
}

local T = {}
ForeverUI.TabardFrame = T

-- l'enveloppe de ButtonFrameTemplate (les memes valeurs que la fenetre Social)
local function envelopper(f)
	local roche = f:CreateTexture(nil, "BACKGROUND")
	roche:SetTexture(P.roche, true)
	if roche.SetHorizTile then roche:SetHorizTile(true) roche:SetVertTile(true) end
	roche:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -21)
	roche:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	T.roche = roche

	local stries = f:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(stries, "_ui-frame-toptilestreaks", true)
	stries:SetHeight(43)
	stries:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -21)
	stries:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)

	local metal = CreateFrame("Frame", nil, f)
	metal:SetAllPoints(f)
	metal:SetFrameLevel(f:GetFrameLevel() + 20)
	local c = {}
	for _, coin in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, coin.nom)
		t:SetPoint(coin.point, metal, coin.point, coin.x, coin.y)
		c[coin.cle] = t
	end
	local function bord(nom, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, nom)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	bord("_ui-frame-metal-edgetop", "TOPLEFT", c.hg, "TOPRIGHT", "TOPRIGHT", c.hd, "TOPLEFT")
	bord("_ui-frame-metal-edgebottom", "BOTTOMLEFT", c.bg, "BOTTOMRIGHT", "BOTTOMRIGHT", c.bd, "BOTTOMLEFT")
	bord("!ui-frame-metal-edgeleft", "TOPLEFT", c.hg, "BOTTOMLEFT", "BOTTOMLEFT", c.bg, "TOPLEFT")
	bord("!ui-frame-metal-edgeright", "TOPRIGHT", c.hd, "BOTTOMRIGHT", "BOTTOMRIGHT", c.bd, "TOPRIGHT")
	T.metal = metal

	-- le portrait du marchand, dans l'anneau
	local cadrePortrait = CreateFrame("Frame", nil, f)
	cadrePortrait:SetAllPoints(f)
	cadrePortrait:SetFrameLevel(f:GetFrameLevel() + 19)
	T.portrait = cadrePortrait:CreateTexture(nil, "OVERLAY")
	T.portrait:SetWidth(P.portraitCote)
	T.portrait:SetHeight(P.portraitCote)
	T.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", P.portraitX, P.portraitY)

	-- le nom du marchand, au-dessus du metal (le texte du client lui sert de
	-- source : TabardFrame_OnEvent le remplit a l'ouverture)
	local bandeau = CreateFrame("Frame", nil, f)
	bandeau:SetAllPoints(f)
	bandeau:SetFrameLevel(f:GetFrameLevel() + 21)
	T.nom = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	T.nom:SetWidth(109)
	T.nom:SetHeight(16)
	T.nom:SetPoint("CENTER", f, "CENTER", 6, 202)
end

-- la croix du client, habillee en croix rouge de camelot
local function habillerCroix(croix, f)
	croix:ClearAllPoints()
	croix:SetPoint("TOPRIGHT", f, "TOPRIGHT", P.croixX, P.croixY)
	croix:SetWidth(P.croix)
	croix:SetHeight(P.croix)
	croix:SetFrameLevel(f:GetFrameLevel() + 22)
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
end

-- l'argent : l'encadre et le bord dore (ThinGoldEdgeTemplate)
-- un repere : un cadre vide, pour la geometrie seulement
local function repere(f, nom)
	local r = CreateFrame("Frame", nom, f)
	r:EnableMouse(false)
	return r
end

-- InsetFrameTemplate (le meme habillage que ForeverUI.DecorateInset), en
-- regions de la fenetre posees sur le repere
local MARBRE = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble"
local function encadrer(f, r)
	local fond = f:CreateTexture(nil, "BORDER")
	fond:SetTexture(MARBRE, true)
	if fond.SetHorizTile then fond:SetHorizTile(true) fond:SetVertTile(true) end
	fond:SetAllPoints(r)
	r.fond = fond
	local function coin(atlas, point, y)
		local t = f:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, atlas)
		t:SetPoint(point, r, point, 0, y or 0)
		return t
	end
	local hg = coin("ui-frame-innertopleft", "TOPLEFT")
	local hd = coin("ui-frame-innertopright", "TOPRIGHT")
	local bg = coin("ui-frame-innerbotleftcorner", "BOTTOMLEFT", -1)
	local bd = coin("ui-frame-innerbotright", "BOTTOMRIGHT", -1)
	local function bord(atlas, a1, c1, r1, a2, c2, r2)
		local t = f:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
		return t
	end
	bord("_ui-frame-innertoptile", "TOPLEFT", hg, "TOPRIGHT", "TOPRIGHT", hd, "TOPLEFT"):SetHeight(3)
	bord("_ui-frame-innerbottile", "BOTTOMLEFT", bg, "BOTTOMRIGHT", "BOTTOMRIGHT", bd, "BOTTOMLEFT"):SetHeight(3)
	bord("!ui-frame-innerlefttile", "TOPLEFT", hg, "BOTTOMLEFT", "BOTTOMLEFT", bg, "TOPLEFT"):SetWidth(3)
	bord("!ui-frame-innerrighttile", "TOPRIGHT", hd, "BOTTOMRIGHT", "BOTTOMRIGHT", bd, "TOPRIGHT"):SetWidth(3)
end

local function habillerArgent(f)
	local encadre = repere(f, "ForeverUITabardMoneyInset")
	encadre:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
	encadre:SetPoint("TOPRIGHT", f, "BOTTOMLEFT", 170, 25)
	encadrer(f, encadre)
	T.encadreArgent = encadre

	local bord = repere(f, "ForeverUITabardMoneyBg")
	bord:SetPoint("TOPRIGHT", f, "BOTTOMLEFT", 166, 24)
	bord:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 7, 6)
	bord.morceaux = {}
	local function morceau(u1, u2, v1, v2)
		local t = f:CreateTexture(nil, "ARTWORK")
		table.insert(bord.morceaux, t)
		t:SetTexture(P.argent)
		t:SetTexCoord(u1, u2, v1, v2)
		return t
	end
	local g = morceau(0.953125, 0.9921875, 0, 0.296875)
	g:SetWidth(7)
	g:SetPoint("TOPLEFT", bord, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", bord, "BOTTOMLEFT")
	local d = morceau(0, 0.0546875, 0, 0.296875)
	d:SetWidth(7)
	d:SetPoint("TOPRIGHT", bord, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", bord, "BOTTOMRIGHT")
	local m = morceau(0, 0.9921875, 0.3125, 0.609375)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	T.bordArgent = bord
end

function T.habiller()
	local f = TabardFrame
	if not f or f.foreverHabille then return end
	f.foreverHabille = true
	f:SetWidth(P.largeur)
	f:SetHeight(P.hauteur)
	f:SetHitRectInsets(0, 0, 0, 0)

	-- ce que camelot n'a plus : le cadre de WotLK et son grand fond
	for _, r in ipairs({ f:GetRegions() }) do
		if r.GetTexture and r:GetObjectType() == "Texture" then
			local chemin = string.lower(tostring(r:GetTexture() or ""))
			if string.find(chemin, "ui-character-general", 1, true) or string.find(chemin, "ui-classtrainer-bot", 1, true) then
				r:Hide()
			end
		end
	end
	if TabardFrameBackground then TabardFrameBackground:Hide() end
	if TabardFramePortrait then TabardFramePortrait:Hide() end
	if TabardFrameNameText then TabardFrameNameText:Hide() end

	envelopper(f)
	local encadre = repere(f, "ForeverUITabardInset")
	encadre:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -60)
	encadre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 26)
	encadrer(f, encadre)
	T.encadre = encadre
	habillerArgent(f)
	if TabardFrameCloseButton then habillerCroix(TabardFrameCloseButton, f) end

	for _, p in ipairs(PLACES) do
		local r = _G[p[1]]
		if r then
			r:ClearAllPoints()
			r:SetPoint(p[2], _G[p[3]], p[4], p[5], p[6])
		end
	end
end

-- LE CADRAGE DU MODELE. Le rappel de SetUnit n'y change rien (verifie a
-- l'ecran le 2026-09-26) : le personnage reste en bas a gauche. Ce client
-- n'a que deux leviers sur un modele, SetPosition(profondeur, lateral,
-- hauteur) et SetModelScale, plus SetCamera (releve dans Wow.exe pour la
-- feuille de personnage). Les valeurs se jugent a l'ecran : /fui tabard les
-- pose et les rend. Le moteur les reprend apres SetUnit : on les repose a
-- chaque image pendant une seconde et demie apres l'ouverture, comme pour la
-- feuille de personnage. Valeurs relevees a l'ecran le 2026-09-26 (personnage
-- centre, en pied, dans l'encadre) ; la camera 1 ne cadre pas mieux que celle
-- par defaut. SetUnit ne remet pas la position a zero.
local REGLAGE = { camera = nil, position = { 0.55, 0.11, 0.72 }, echelle = nil }
T.reglage = { camera = REGLAGE.camera, position = REGLAGE.position, echelle = REGLAGE.echelle }
local RATTRAPAGE = 1.5

local function appliquerReglage()
	local m = TabardModel
	if not m then return end
	local r = T.reglage
	if r.camera and m.SetCamera then m:SetCamera(r.camera) end
	if r.echelle and m.SetModelScale then m:SetModelScale(r.echelle) end
	if r.position and m.SetPosition then m:SetPosition(r.position[1], r.position[2], r.position[3]) end
end
T.appliquerReglage = appliquerReglage

local rattrapage = CreateFrame("Frame")
rattrapage:Hide()
rattrapage.reste = 0
rattrapage:SetScript("OnUpdate", function(self, ecoule)
	appliquerReglage()
	self.reste = self.reste - (ecoule or 0)
	if self.reste <= 0 then self:Hide() end
end)
T.rattrapage = rattrapage

local function rattraper()
	rattrapage.reste = RATTRAPAGE
	rattrapage:Show()
end

--   /fui tabard                      ce que porte le modele
--   /fui tabard camera <n>           SetCamera
--   /fui tabard echelle <s>          SetModelScale
--   /fui tabard position <x> <y> <z> SetPosition(profondeur, lateral, hauteur)
--   /fui tabard defaut               reprend le reglage retenu
--   /fui tabard client               rend le modele au client (sans reglage)
function ForeverUI.TabardModelTune(argument)
	local dire = function(texte) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte) end
	local m = TabardModel
	if not m then return end
	local cle, reste = string.match(argument or "", "^(%S*)%s*(.*)$")
	cle = string.lower(cle or "")
	local r = T.reglage
	if cle == "camera" then
		r.camera = tonumber(reste)
	elseif cle == "echelle" then
		r.echelle = tonumber(reste)
	elseif cle == "position" then
		local x, y, z = string.match(reste, "^(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)$")
		if not x then
			dire("tabard : /fui tabard position <profondeur> <lateral> <hauteur>")
			return
		end
		r.position = { tonumber(x), tonumber(y), tonumber(z) }
	elseif cle == "defaut" then
		T.reglage = { camera = REGLAGE.camera, position = REGLAGE.position, echelle = REGLAGE.echelle }
		m:SetUnit("player")
		if m.InitializeTabardColors then m:InitializeTabardColors() end
	elseif cle == "client" then
		T.reglage = { camera = nil, position = { 0, 0, 0 }, echelle = 1 }
		m:SetUnit("player")
		if m.InitializeTabardColors then m:InitializeTabardColors() end
	elseif cle ~= "" then
		dire("tabard : camera <n> | echelle <s> | position <x> <y> <z> | defaut | client")
		return
	end
	appliquerReglage()
	rattraper()
	local x, y, z
	if m.GetPosition then x, y, z = m:GetPosition() end
	dire(string.format("tabard : camera=%s echelle=%s position=(%s, %s, %s)", tostring(T.reglage.camera),
		tostring(m.GetModelScale and m:GetModelScale()), tostring(x), tostring(y), tostring(z)))
end

-- LE MODELE DECALE EN BAS A GAUCHE (constate le 2026-09-26, deja present
-- avec la fenetre de WotLK). A OPEN_TABARD_FRAME, le client 3.3.5 appelle
-- TabardModel:SetUnit("player") AVANT ShowUIPanel : le modele se cadre sur
-- une fenetre encore cachee. Camelot rappelle SetUnit quand la taille ou
-- l'affichage changent (TabardFrame_OnEvent : "This will happen even on
-- initial open"). On le rappelle donc une fois la fenetre affichee, a l'image
-- suivante, et on remet le tabard en cours comme le client le fait apres son
-- SetUnit (InitializeTabardColors, TabardFrame_UpdateTextures).
local recadrage = CreateFrame("Frame")
recadrage:Hide()
recadrage:SetScript("OnUpdate", function(self)
	self:Hide()
	if not (TabardFrame and TabardFrame:IsShown() and TabardModel) then return end
	TabardModel:SetUnit("player")
	if TabardModel.InitializeTabardColors then TabardModel:InitializeTabardColors() end
	if TabardFrame_UpdateTextures then TabardFrame_UpdateTextures() end
	if TabardFrame_UpdateButtons then TabardFrame_UpdateButtons() end
	rattraper()
end)
T.recadrage = recadrage

-- a l'ouverture : le portrait et le nom du marchand (TabardFrame_OnEvent les
-- vient de poser sur les regions du client), et le modele recadre
function T.ouvrir()
	SetPortraitTexture(T.portrait, "npc")
	T.nom:SetText(TabardFrameNameText and TabardFrameNameText:GetText() or UnitName("npc"))
	recadrage:Show()
end

if TabardFrame then
	T.habiller()
	TabardFrame:HookScript("OnShow", T.ouvrir)
end
