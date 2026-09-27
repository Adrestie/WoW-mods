-- ForeverUI -- les menus deroulants des ecrans d'accueil (GlueDropDownMenu),
-- a la DA de camelot.
--
-- RELEVE -- blizzard_menu : mainline/menutemplates.xml / .lua
-- (WowStyle1DropdownTemplate, WowStyle2DropdownTemplate,
-- GetWowStyle1ArrowButtonState, MenuStyle1Mixin, MenuStyle2Mixin),
-- menuvariants.lua et mainline/menuvariants.lua (radio, surbrillance, sons) ;
-- dropdownbutton.lua / .xml (ancre de la liste, largeur minimale).
-- Deux styles, comme chez camelot :
--   1 (par defaut) WowStyle1DropdownTemplate -- fond common-dropdown-
--     textholder de (-8, 7) a (8, -9), fleche common-dropdown-a-button a
--     RIGHT (1, -3) (etats hover / pressed / pressedhover / open / disabled),
--     texte GameFontHighlight de (8, -8) a la fleche ; liste MenuStyle1 :
--     fond common-dropdown-bg de (-10, 3) a (10, -3) a 0,925, marges
--     8 / 8 / 8 / 15 ;
--   2 (reglages : SettingsDropdownControl) WowStyle2DropdownTemplate -- fond
--     common-dropdown-c-button de (-7, 7) a (7, -7) (etats hover-1 /
--     pressed-1 / pressedhover-1 / open / disabled), fleche
--     common-dropdown-c-button-hover-arrow a BOTTOM (0, -5) au survol
--     seulement (desaturee si desactive), texte GameFontNormal centre de 13
--     a -13, 20 de haut, decale de (2, -1) enfonce ; liste MenuStyle2 : fond
--     common-dropdown-c-bg de (-17, 12) a (17, -22), marges 3 / 6 / 3 / 7.
-- Dans les deux listes : lignes de 20 ; choix unique : radio common-dropdown-
-- tickradial a LEFT (-3, 0), le choisi common-dropdown-icon-radialtick-yellow
-- par-dessus, texte GameFontHighlight a 1 a sa droite ; surbrillance
-- UI-QuestTitleHighlight en ADD (celle du client, deja la meme) ; la liste
-- sous le bouton, TOPLEFT sur BOTTOMLEFT.
-- 3.3.5 RHABILLE : le menu du client garde sa place et sa logique
-- (ToggleDropDownMenu, GlueDropDownMenu_AddButton...) ; on repose l'art et
-- les lignes apres lui. Le bouton de camelot tient dans la partie visible du
-- cadre de 3.3.5 (CharacterCreate-LabelFrame, releve de l'image : opaque de
-- 16 a 111 sur 128 en largeur, de 19 a 45 sur 64 en hauteur), soit de 16
-- apres le bord gauche de Left a 17 avant le bord droit de Right, 19 sous le
-- haut de Left, 25 de haut ; toute cette case ouvre la liste.
-- ECART (28/09, a la demande : « les textes des menus deroulants sont trop
-- gros et ne suivent pas la taille des autres textes ») : le texte du bouton
-- de style 2 et celui des lignes passent a la taille 10 des autres textes
-- des options (OptionsFontSmall) -- GameFontNormalSmall pour le bouton,
-- GameFontHighlightSmallLeft / NormalSmallLeft / DisableSmallLeft pour les
-- lignes -- au lieu de la taille 12 de camelot (GameFontNormal,
-- GameFontHighlight).
-- L'ECHELLE DES LISTES. DropDownList1 a 3 n'ont pas de parent (le client
-- les declare hors de GlueParent) et ToggleDropDownMenu leur remet l'echelle
-- 1 a chaque ouverture : elles echappaient a l'echelle de GlueParent (768 /
-- 1200) et tout y paraissait 1,56 fois plus grand (constate le 28/09 : « les
-- elements des listes sont trop grands »). Apres lui, la liste prend
-- l'echelle de GlueParent.
-- La largeur de la liste : celle de son contenu, au moins celle du bouton
-- au premier niveau d'un menu deroulant (SetMinimumWidth de camelot ; a la
-- demande, 28/09 : « les listes n'adaptent pas leur taille a leur
-- contenu »).
-- TEXTES VENUS DE WINDOWS : les noms des sorties audio
-- (Sound_GameSystem_GetOutputDriverNameByIndex) arrivent dans la page de
-- code du systeme (Windows-1252), que le client affiche comme de l'UTF-8 :
-- les lettres accentuees sautent ou se deforment. Une chaine qui n'est pas
-- de l'UTF-8 valide est convertie (G.TexteUtf8) a l'affichage, dans la
-- liste et dans le bouton ; la valeur choisie reste celle du client.

local G = ForeverUIGlue

local SURVOL = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local LIGNE = 20
local ETENDUE = 16 + 20                 -- radio (-3 .. 15) + 1, et le rembourrage
local NIVEAUX = GLUEDROPDOWNMENU_MAXLEVELS or 3

local STYLES = {
	[1] = { fond = "common-dropdown-bg", fondA = { -10, 3 }, fondB = { 10, -3 }, alpha = 0.925,
		marges = { 8, 8, 8, 15 } },
	[2] = { fond = "common-dropdown-c-bg", fondA = { -17, 12 }, fondB = { 17, -22 }, alpha = 1,
		marges = { 3, 6, 3, 7 } },
}

-- 3.3.5 rend 1 / nil, parfois 0 / 1 : zero est vrai en Lua
local function vrai(v)
	return v and v ~= 0 and true or false
end

-- ------------------------------------------------------------ Windows-1252

-- 0x80 a 0x9F de Windows-1252 ; 0xA0 a 0xFF valent leur point de code
local CP1252 = {
	[0x80] = 0x20AC, [0x82] = 0x201A, [0x83] = 0x0192, [0x84] = 0x201E, [0x85] = 0x2026,
	[0x86] = 0x2020, [0x87] = 0x2021, [0x88] = 0x02C6, [0x89] = 0x2030, [0x8A] = 0x0160,
	[0x8B] = 0x2039, [0x8C] = 0x0152, [0x8E] = 0x017D, [0x91] = 0x2018, [0x92] = 0x2019,
	[0x93] = 0x201C, [0x94] = 0x201D, [0x95] = 0x2022, [0x96] = 0x2013, [0x97] = 0x2014,
	[0x98] = 0x02DC, [0x99] = 0x2122, [0x9A] = 0x0161, [0x9B] = 0x203A, [0x9C] = 0x0153,
	[0x9E] = 0x017E, [0x9F] = 0x0178,
}

local function enUtf8(cp)
	if cp < 0x80 then
		return string.char(cp)
	elseif cp < 0x800 then
		return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
	end
	return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

local function utf8Valide(s)
	local i, n = 1, string.len(s)
	while i <= n do
		local c = string.byte(s, i)
		local suite
		if c < 0x80 then
			suite = 0
		elseif c >= 0xC2 and c <= 0xDF then
			suite = 1
		elseif c >= 0xE0 and c <= 0xEF then
			suite = 2
		elseif c >= 0xF0 and c <= 0xF4 then
			suite = 3
		else
			return false
		end
		for j = 1, suite do
			local d = string.byte(s, i + j)
			if not d or d < 0x80 or d > 0xBF then
				return false
			end
		end
		i = i + suite + 1
	end
	return true
end

-- une chaine de Windows-1252 en UTF-8 ; une chaine deja valide ne change pas
function G.TexteUtf8(s)
	if type(s) ~= "string" or utf8Valide(s) then
		return s
	end
	return (string.gsub(s, "[\128-\255]", function(ch)
		local b = string.byte(ch)
		return enUtf8(CP1252[b] or b)
	end))
end

-- le menu qui ouvre (ou remplit) la liste
local function ouvreur()
	local nom = GLUEDROPDOWNMENU_OPEN_MENU or GLUEDROPDOWNMENU_INIT_MENU
	return nom and _G[nom]
end

local function styleDe(dd)
	return STYLES[dd and dd.foreverStyle or 1]
end

-- ------------------------------------------------------------ le bouton

local function ouvert(dd)
	return DropDownList1:IsShown() and GLUEDROPDOWNMENU_OPEN_MENU == dd:GetName()
end

-- GetWowStyle1ArrowButtonState
local function peindreStyle1(dd, b)
	local n = "common-dropdown-a-button"
	if not vrai(b:IsEnabled()) then
		n = n .. "-disabled"
	elseif b.bas and b.dessus then
		n = n .. "-pressedhover"
	elseif b.dessus then
		n = n .. "-hover"
	elseif b.bas then
		n = n .. "-pressed"
	elseif ouvert(dd) then
		n = n .. "-open"
	end
	G.PoserAtlas(dd.foreverFleche, n, true)
end

-- WowStyle2DropdownMixin:GetBackgroundAtlas et OnButtonStateChanged
local function peindreStyle2(dd, b)
	local actif = vrai(b:IsEnabled())
	local n = "common-dropdown-c-button"
	if not actif then
		n = n .. "-disabled"
	elseif b.bas and b.dessus then
		n = n .. "-pressedhover-1"
	elseif b.dessus then
		n = n .. "-hover-1"
	elseif b.bas then
		n = n .. "-pressed-1"
	elseif ouvert(dd) then
		n = n .. "-open"
	end
	dd.foreverFond:Poser(n)
	G.Montrer(dd.foreverFleche, b.dessus)
	dd.foreverFleche:SetDesaturated(not actif)
	local texte = _G[dd:GetName() .. "Text"]
	-- le client grise le texte par SetVertexColor : la couleur est la notre
	texte:SetVertexColor(1, 1, 1)
	if actif then
		texte:SetTextColor(1, 0.82, 0)
	else
		texte:SetTextColor(0.5, 0.5, 0.5)
	end
	-- SetDisplacedRegions(2, -1, Text)
	local dx, dy = 0, 0
	if b.bas and actif then
		dx, dy = 2, -1
	end
	texte:ClearAllPoints()
	texte:SetPoint("LEFT", b, "LEFT", 13 + dx, dy)
	texte:SetPoint("RIGHT", b, "RIGHT", -13 + dx, dy)
end

local function peindreBouton(dd)
	local b = dd.foreverBouton
	if dd.foreverStyle == 2 then
		peindreStyle2(dd, b)
	else
		peindreStyle1(dd, b)
	end
end

-- style : 1 (WowStyle1, par defaut) ou 2 (WowStyle2, les reglages)
function G.HabillerMenuDeroulant(dd, style)
	if dd.foreverBouton then
		return
	end
	dd.foreverStyle = style or 1
	local nom = dd:GetName()
	local gauche, droite = _G[nom .. "Left"], _G[nom .. "Right"]
	for _, suffixe in ipairs({ "Left", "Middle", "Right" }) do
		_G[nom .. suffixe]:SetAlpha(0)
	end
	-- la case de camelot, dans la partie visible du cadre de 3.3.5
	local b = _G[nom .. "Button"]
	dd.foreverBouton = b
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", gauche, "TOPLEFT", 16, -19)
	b:SetPoint("RIGHT", droite, "RIGHT", -17, 0)
	b:SetHeight(25)
	G.EffacerArtClient(b)
	-- le fond en region du menu, sous son texte ; la case (cadre fils) ne
	-- porte que la fleche
	local texte = _G[nom .. "Text"]
	texte:SetHeight(dd.foreverStyle == 2 and 20 or 10)
	texte:ClearAllPoints()
	dd.foreverFleche = b:CreateTexture(nil, "OVERLAY")
	if dd.foreverStyle == 2 then
		dd.foreverFond = G.AtlasEtire(dd, "common-dropdown-c-button", "BACKGROUND")
		dd.foreverFond.rect:SetPoint("TOPLEFT", b, "TOPLEFT", -7, 7)
		dd.foreverFond.rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 7, -7)
		G.PoserAtlas(dd.foreverFleche, "common-dropdown-c-button-hover-arrow", true)
		dd.foreverFleche:SetPoint("BOTTOM", b, "BOTTOM", 0, -5)
		texte:SetFontObject(G.Police("GameFontNormalSmall"))
		texte:SetJustifyH("CENTER")
	else
		local fond = G.AtlasEtire(dd, "common-dropdown-textholder", "BACKGROUND")
		fond.rect:SetPoint("TOPLEFT", b, "TOPLEFT", -8, 7)
		fond.rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 8, -9)
		G.PoserAtlas(dd.foreverFleche, "common-dropdown-a-button", true)
		dd.foreverFleche:SetPoint("RIGHT", b, "RIGHT", 1, -3)
		texte:SetFontObject(G.Police("GameFontHighlight"))
		texte:SetJustifyH("LEFT")
		texte:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -8)
		texte:SetPoint("TOPRIGHT", dd.foreverFleche, "LEFT", 0, 0)
	end
	G.Accrocher(b, "OnEnter", function(self) self.dessus = true; peindreBouton(dd) end)
	G.Accrocher(b, "OnLeave", function(self) self.dessus = false; peindreBouton(dd) end)
	G.Accrocher(b, "OnMouseDown", function(self) self.bas = true; peindreBouton(dd) end)
	G.Accrocher(b, "OnMouseUp", function(self) self.bas = false; peindreBouton(dd) end)
	G.Accrocher(b, "OnDisable", function() peindreBouton(dd) end)
	G.Accrocher(b, "OnEnable", function() peindreBouton(dd) end)
	-- le survol du menu (son infobulle) reste celui du client : la case le
	-- relaie
	G.Accrocher(b, "OnEnter", function()
		local surEntree = dd:GetScript("OnEnter")
		if surEntree then surEntree(dd) end
	end)
	G.Accrocher(b, "OnLeave", function()
		local surSortie = dd:GetScript("OnLeave")
		if surSortie then surSortie(dd) end
	end)
	peindreBouton(dd)
end

-- ------------------------------------------------------------ la liste

-- les deux fonds, montres selon le style du menu qui ouvre
local function habillerListe(l)
	if l.foreverFonds then
		return
	end
	local nom = l:GetName()
	for _, suffixe in ipairs({ "Backdrop", "MenuBackdrop" }) do
		local c = _G[nom .. suffixe]
		if c and c.SetBackdrop then
			c:SetBackdrop(nil)
		end
	end
	l.foreverFonds = {}
	for i, s in ipairs(STYLES) do
		local fond = G.AtlasEtire(l, s.fond, "BACKGROUND")
		fond.rect:SetPoint("TOPLEFT", l, "TOPLEFT", s.fondA[1], s.fondA[2])
		fond.rect:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", s.fondB[1], s.fondB[2])
		fond.rect:SetAlpha(s.alpha)
		for _, t in ipairs(fond.pieces) do
			t:SetAlpha(s.alpha)
		end
		l.foreverFonds[i] = fond
	end
end

local function montrerFond(l, dd)
	local style = dd and dd.foreverStyle or 1
	for i, fond in ipairs(l.foreverFonds) do
		fond:Montrer(i == style)
	end
end

-- une ligne : radio de camelot sous la coche du client (qui devient le point
-- jaune), texte a sa droite
local function habillerLigne(b)
	if b.foreverRond then
		return
	end
	local rond = b:CreateTexture(nil, "BORDER")
	G.PoserAtlas(rond, "common-dropdown-tickradial", true)
	rond:SetPoint("LEFT", b, "LEFT", -3, 0)
	b.foreverRond = rond
	local point = _G[b:GetName() .. "Check"]
	G.PoserAtlas(point, "common-dropdown-icon-radialtick-yellow", true)
	point:ClearAllPoints()
	point:SetPoint("TOPLEFT", rond, "TOPLEFT")
	local survol = _G[b:GetName() .. "Highlight"]
	survol:SetTexture(SURVOL)
	survol:SetBlendMode("ADD")
	survol:ClearAllPoints()
	survol:SetAllPoints(b)
end

-- la largeur : celle du contenu, au moins celle du bouton au premier niveau
-- d'un menu deroulant ; les lignes au-dedans des marges
local function largeur(l, niveau)
	local dd = ouvreur()
	local m = styleDe(dd).marges
	local voulue = (l.foreverContenu or 0) + m[1] + m[3]
	if niveau == 1 and dd and dd.foreverBouton and dd.displayMode ~= "MENU" then
		voulue = math.max(voulue, dd.foreverBouton:GetWidth() or 0)
	end
	if not voulue or voulue <= 0 then
		return
	end
	l:SetWidth(voulue)
	for i = 1, (l.numButtons or 0) do
		_G[l:GetName() .. "Button" .. i]:SetWidth(voulue - m[1] - m[3])
	end
end

-- apres GlueDropDownMenu_AddButton : la ligne a sa place de camelot, sa
-- police, son radio ; la hauteur de la liste
G.AccrocherFonction("GlueDropDownMenu_AddButton", function(info, niveau)
	niveau = niveau or 1
	local l = _G["DropDownList" .. niveau]
	if not l then
		return
	end
	habillerListe(l)
	local dd = ouvreur()
	montrerFond(l, dd)
	local m = styleDe(dd).marges
	local i = l.numButtons or 1
	local b = _G[l:GetName() .. "Button" .. i]
	if not b then
		return
	end
	habillerLigne(b)
	local brut = b:GetText()
	local propre = G.TexteUtf8(brut)
	if propre ~= brut then
		b:SetText(propre)
	end
	b:SetHeight(LIGNE)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", l, "TOPLEFT", m[1], -(m[2] + (i - 1) * LIGNE))
	b:SetNormalFontObject(G.Police("GameFontHighlightSmallLeft"))
	b:SetHighlightFontObject(G.Police("GameFontHighlightSmallLeft"))
	if info and info.isTitle then
		b:SetDisabledFontObject(G.Police("GameFontNormalSmallLeft"))
	elseif info and info.notClickable then
		b:SetDisabledFontObject(G.Police("GameFontHighlightSmallLeft"))
	else
		b:SetDisabledFontObject(G.Police("GameFontDisableSmallLeft"))
	end
	local texte = _G[b:GetName() .. "NormalText"]
	local coche = not (info and info.notCheckable)
	G.Montrer(b.foreverRond, coche)
	texte:ClearAllPoints()
	if coche then
		texte:SetPoint("LEFT", b.foreverRond, "RIGHT", 1, 0)
	elseif info and info.justifyH == "CENTER" then
		texte:SetPoint("CENTER", b, "CENTER", 0, 0)
	else
		texte:SetPoint("LEFT", b, "LEFT", 0, 0)
	end
	-- l'etendue de la ligne (MeasureFrameExtents + rembourrage de 20)
	local e = (coche and ETENDUE or 20) + (texte:GetStringWidth() or 0)
	if i == 1 or e > (l.foreverContenu or 0) then
		l.foreverContenu = e
	end
	l:SetHeight(m[2] + i * LIGNE + m[4])
end)

-- apres ToggleDropDownMenu : sous le bouton de camelot (meme pour un menu
-- que le client ancre ailleurs, GlueDropDownMenu_SetAnchor), a sa largeur ;
-- la fleche passe a l'etat ouvert
G.AccrocherFonction("ToggleDropDownMenu", function(_, niveau)
	niveau = niveau or 1
	local l = _G["DropDownList" .. niveau]
	if not (l and l:IsShown()) then
		return
	end
	l:SetScale(GlueParent:GetScale())
	largeur(l, niveau)
	local dd = ouvreur()
	if niveau == 1 and dd and dd.foreverBouton and dd.displayMode ~= "MENU" then
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", dd.foreverBouton, "BOTTOMLEFT", 0, 0)
	end
	if dd and dd.foreverBouton then
		peindreBouton(dd)
	end
end)

-- le texte du bouton, converti comme les lignes
G.AccrocherFonction("GlueDropDownMenu_SetText", function(texte, dd)
	local fs = dd and _G[dd:GetName() .. "Text"]
	local propre = G.TexteUtf8(texte)
	if fs and propre ~= texte then
		fs:SetText(propre)
	end
end)

-- la fleche revient au repos quand la liste se ferme
for i = 1, NIVEAUX do
	local l = _G["DropDownList" .. i]
	if l then
		G.Accrocher(l, "OnShow", function(self)
			-- OnShow du client retaille la liste sur son texte
			largeur(self, i)
		end)
		G.Accrocher(l, "OnHide", function()
			local dd = ouvreur()
			if dd and dd.foreverBouton then
				peindreBouton(dd)
			end
		end)
	end
end
