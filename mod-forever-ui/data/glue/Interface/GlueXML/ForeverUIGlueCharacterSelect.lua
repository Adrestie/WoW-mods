-- ForeverUI : la selection des personnages, copie de celle de camelot.
--
-- RELEVE -- blizzard_gluexml : mainline/characterselect.xml et .lua,
-- mainline/characterselect/characterselectlist.xml / .lua,
-- characterselectlistelements.xml / .lua, characterselecttemplates.lua,
-- camelot/characterselect/characterselectlist.lua, characterselecttemplates.lua,
-- characterselectlistbackground.xml, mainline/characterselect/charselectsearch.lua ;
-- blizzard_characterselectnavbar (characterselectnavbar.xml / .lua,
-- camelot/characterselectnavbar.lua, camelot/characterselectnavtemplates.xml).
-- Tous les nombres sont ceux de camelot, en unites de camelot (l'echelle est
-- posee une fois sur GlueParent) :
--   * logo 256 x 128 a TOPLEFT (3, -2) (LogoHoist (3, -17) + (0, 15)) ;
--   * barre du haut : 55 de haut sur toute la largeur ; boutons de 64 de
--     haut, largeur = texte + 70, enchaines au centre ; fond
--     glues-characterselect-tophud-middle-bg, -left-bg deborde de 27 a
--     gauche du premier, -right-bg de 27 a droite du dernier ; separateur
--     -bg-divider a droite de chacun sauf le dernier ; survol : -selected-
--     (middle, left, right), 44 de haut, 7 au-dessus du bas ; polices
--     GlueFontNormal / GlueFontYellow / GlueFontDisable ;
--   * liste (CharacterList) : 386 de large, TOPRIGHT a (-9, -69) (sous le
--     conteneur des jetons, 68 de haut, a (-12, -2), + (3, 1)), bas 10
--     au-dessus du bouton de repli ; fond heavybronze-frame-background en
--     mosaique, cadre heavybronze-frame-basic de (-9, 15) a (9, -15) avec
--     ses equerres vert-cornerbracket-TR / -BR ;
--   * recherche 308 x 24 a TOPLEFT (33, -25) (retiree, voir plus bas) ;
--   * cartes 347 x 95, 2 d'ecart, dans la zone de (-115, -67) a (-32, 83) de
--     la liste, a 122 de son bord gauche ; barre de defilement minimale de
--     (0, -2) a (0, 4) de la zone, a 16 du bord droit de la liste ; la
--     molette avance de 2 x 95, une fleche de 95 ;
--   * Create Character 205 x 42 a BOTTOM (-57, 23) de la liste ; corbeille
--     42 x 42 (128-RedButton-Delete) 6 a sa droite ;
--   * service payant 58 x 58 a gauche de la carte (-5, 0) ;
--   * repli de la liste : 385 x 50 a BOTTOMRIGHT (-10, 6) ;
--   * nom du personnage GameFontNormalHuge4Outline a BOTTOM (0, 114) ; Enter
--     World 250 x 66 a BOTTOM (0, 45) ; rotation 48 x 48, gauche a
--     (-21, 4) sous Enter World, droite 11 plus pres ; Back 188 x 42 a
--     BOTTOMLEFT (12, 12) ; oeil 42 x 42 a BOTTOMLEFT (205, 12).
-- Les cartes sont les notres (3.3.5 n'a pas de liste defilante) : elles
-- lisent GetCharacterInfo et declenchent les boutons du client, caches.
-- ECARTS A CAMELOT voulus par l'utilisateur (27/09), pour que 10 cartes
-- (10 x 95 + 9 x 2 = 968) tiennent sans defiler : pas de recherche, la zone
-- des cartes monte a sa place (haut -67 -> -25) ; Create Character et la
-- corbeille descendus de 11, la zone allongee d'autant (bas 83 -> 72) ; la
-- barre de defilement se cache quand tout tient ; service payant 53 x 53.

local G = ForeverUIGlue
local ui = CharacterSelectUI
local liste = CharacterSelectCharacterFrame

-- textes absents de 3.3.5 : ceux de camelot (GlobalStrings du client moderne)
local TEXTE = {
	REALMS = "REALMS",
	MENU = "MENU",
	TOGGLE = "Toggle Character List",
}

-- la faction d'une race (jeton de GetSelectBackgroundModel, ou nom anglais
-- de la race pour le chevalier de la mort, dont le decor est DeathKnight)
local FACTIONS = {
	Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance", Draenei = "Alliance",
	Orc = "Horde", Scourge = "Horde", Tauren = "Horde", Troll = "Horde", BloodElf = "Horde",
	["Night Elf"] = "Alliance", Undead = "Horde", ["Blood Elf"] = "Horde",
}

local etat = { decalage = 0, cartes = {}, visibles = {} }

-- ------------------------------------------------------------ le logo

CharacterSelectLogo:ClearAllPoints()
CharacterSelectLogo:SetPoint("TOPLEFT", ui, "TOPLEFT", 3, -2)

-- ------------------------------------------------------------ la barre du haut

local nav = CreateFrame("Frame", "ForeverUICharacterSelectNavBar", ui)
nav:SetHeight(55)
nav:SetPoint("TOPLEFT", ui, "TOPLEFT")
nav:SetPoint("TOPRIGHT", ui, "TOPRIGHT")
local plateau = CreateFrame("Frame", nil, nav)
plateau:SetPoint("TOP", nav, "TOP")
plateau:SetPoint("BOTTOM", nav, "BOTTOM")
plateau:SetWidth(1)

local function boutonNav(texte, action)
	local b = CreateFrame("Button", nil, plateau)
	b:SetHeight(64)
	b:SetNormalFontObject(G.Police("GlueFontNormal"))
	b:SetHighlightFontObject(G.Police("GlueFontYellow"))
	b:SetDisabledFontObject(G.Police("GlueFontDisable"))
	b:SetText(texte)
	b:SetWidth(b:GetTextWidth() + 70)
	b.fond = G.AtlasEtire(b, "glues-characterselect-tophud-middle-bg", "BACKGROUND")
	b.grise = G.AtlasEtire(b, "glues-characterselect-tophud-middle-dis-bg", "BACKGROUND")
	b.survol = G.AtlasEtire(b, "glues-characterselect-tophud-selected-middle", "BORDER")
	b.barre = b:CreateTexture(nil, "OVERLAY")
	G.PoserAtlas(b.barre, "glues-characterselect-tophud-bg-divider", true)
	b.barre:SetPoint("RIGHT", b, "RIGHT")
	b:SetScript("OnClick", action)
	b:SetScript("OnEnter", function(self) if self:IsEnabled() then self.survol:Montrer(true) end end)
	b:SetScript("OnLeave", function(self) self.survol:Montrer(false) end)
	return b
end

local boutonsNav = {
	boutonNav(TEXTE.REALMS, function() CharacterSelect_ChangeRealm() end),
	boutonNav(TEXTE.MENU, function() G.BasculerMenu() end),
	boutonNav(string.upper(ADDONS), function() CharacterSelectAddonsButton:Click() end),
}

-- les extremites (camelot/characterselectnavbar.lua, SetButtonVisuals)
local function peindreNav(b, rang, dernier)
	local fond, grise = "glues-characterselect-tophud-middle-bg", "glues-characterselect-tophud-middle-dis-bg"
	local survol = "glues-characterselect-tophud-selected-middle"
	local fg, fd = 0, 0            -- debord du fond a gauche et a droite
	local sg, sd = 0, -7           -- survol : ecart a gauche et a droite
	if rang == 1 then
		fond, grise = "glues-characterselect-tophud-left-bg", "glues-characterselect-tophud-left-dis-bg"
		survol = "glues-characterselect-tophud-selected-left"
		fg, sg, sd = -27, 4, -3 - 18
	end
	if dernier then
		fond, grise = "glues-characterselect-tophud-right-bg", "glues-characterselect-tophud-right-dis-bg"
		survol = "glues-characterselect-tophud-selected-right"
		fd, sg, sd = 27, 9, -10
	end
	for _, obj in ipairs({ { b.fond, fond }, { b.grise, grise } }) do
		obj[1]:Poser(obj[2])
		obj[1].rect:ClearAllPoints()
		obj[1].rect:SetPoint("TOPLEFT", b, "TOPLEFT", fg, 0)
		obj[1].rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", fd, 0)
	end
	b.survol:Poser(survol)
	b.survol.rect:ClearAllPoints()
	b.survol.rect:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", sg, 7)
	b.survol.rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", sd, 7)
	b.survol.rect:SetHeight(44)
	b.survol:Montrer(false)
	G.Montrer(b.barre, not dernier)
	local actif = b:IsEnabled() and true or false
	b.fond:Montrer(actif)
	b.grise:Montrer(not actif)
	G.PoserAtlas(b.barre, actif and "glues-characterselect-tophud-bg-divider" or "glues-characterselect-tophud-bg-divider-dis", true)
end

local function rangerNav()
	local montres = {}
	for i, b in ipairs(boutonsNav) do
		-- AddOns seulement s'il y en a (le client recompte dans UpdateAddonButton)
		local visible = (i ~= 3) or (GetNumAddOns() > 0)
		G.Montrer(b, visible)
		if visible then table.insert(montres, b) end
	end
	local x = 0
	for i, b in ipairs(montres) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", plateau, "TOPLEFT", x, 0)
		x = x + b:GetWidth()
		peindreNav(b, i, i == #montres)
	end
	plateau:SetWidth(math.max(1, x))
end
rangerNav()

-- ------------------------------------------------------------ la liste

CharSelectRealmName:Hide()
CharSelectChangeRealmButton:Hide()
liste:SetBackdrop(nil)
liste:SetWidth(386)

-- le fond en mosaique, recalcule a la taille de la liste (deux ancres : sa
-- hauteur se lit par GetTop - GetBottom)
local fondListe = liste:CreateTexture(nil, "BACKGROUND")
fondListe:SetAllPoints(liste)
local function poserFondListe()
	local l = (liste:GetRight() or 0) - (liste:GetLeft() or 0)
	local h = (liste:GetTop() or 0) - (liste:GetBottom() or 0)
	if l > 0 and h > 0 then
		G.Mosaique(fondListe, "heavybronze-frame-background", l, h)
	end
end
local cadreListe = G.AtlasEtire(liste, "heavybronze-frame-basic", "BORDER")
cadreListe.rect:SetPoint("TOPLEFT", liste, "TOPLEFT", -9, 15)
cadreListe.rect:SetPoint("BOTTOMRIGHT", liste, "BOTTOMRIGHT", 9, -15)
for _, e in ipairs({ { "heavybronze-vert-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-vert-cornerbracket-br", "BOTTOMRIGHT" } }) do
	local t = liste:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(t, e[1], true)
	t:SetPoint(e[2], cadreListe.rect, e[2])
end

-- ------------------------------------------------------------ la zone des cartes

local CARTE_L, CARTE_H, ECART, MARGE_G = 347, 95, 2, 122
local PAN = 95
-- ecarts a camelot (voir l'en-tete) : la zone monte a la place de la
-- recherche retiree, les boutons descendent de 11, service reduit
local HAUT_ZONE, DESCENTE, SERVICE = -25, 11, 53

local zone = CreateFrame("ScrollFrame", "ForeverUICharacterSelectScrollBox", liste)
zone:SetPoint("TOPLEFT", liste, "TOPLEFT", -115, HAUT_ZONE)
zone:SetPoint("BOTTOMRIGHT", liste, "BOTTOMRIGHT", -32, 83 - DESCENTE)
local contenu = CreateFrame("Frame", nil, zone)
contenu:SetWidth(386 + 115 - 32)
contenu:SetHeight(1)
zone:SetScrollChild(contenu)

local barreDefil = G.BarreMinimale(liste, "ForeverUICharacterSelectScrollBar")
barreDefil:SetPoint("TOP", zone, "TOP", 0, -2)
barreDefil:SetPoint("BOTTOM", zone, "BOTTOM", 0, 4)
barreDefil:SetPoint("RIGHT", liste, "RIGHT", -16, 0)
barreDefil.pas = PAN
barreDefil.cacherSiInutile = true
barreDefil.surDefilement = function(position)
	etat.decalage = position
	zone:SetVerticalScroll(position)
end
zone:EnableMouseWheel(true)
zone:SetScript("OnMouseWheel", function(_, sens)
	barreDefil:Deplacer(barreDefil.position - sens * PAN * 2)
end)

-- ------------------------------------------------------------ une carte

local SERVICES = {
	{ "CharSelectFactionChange", PAID_FACTION_CHANGE, "glues-characterselect-icon-factionchange", PAID_FACTION_CHANGE_TOOLTIP },
	{ "CharSelectRaceChange", PAID_RACE_CHANGE, "glues-characterselect-icon-racechange", PAID_RACE_CHANGE_TOOLTIP },
	{ "CharSelectCharacterCustomize", PAID_CHARACTER_CUSTOMIZATION, "glues-characterselect-icon-appearancechange", PAID_CHARACTER_CUSTOMIZE_TOOLTIP },
}

local function survolCarte(c, dessus)
	c.dessus = dessus
	local choisie = c.choisie
	G.Montrer(c.selectedHighlight, dessus and choisie)
	G.Montrer(c.highlight, dessus and not choisie)
	if c.faction then
		-- camelot cache l'embleme choisi au survol pour y montrer les fleches
		-- de deplacement (ShowMoveButtons) ; 3.3.5 ne reordonne pas les
		-- personnages : pas de fleches, l'embleme reste (demande du 27/09)
		G.Montrer(c.emblemeSurvol, dessus and not choisie)
		G.Montrer(c.emblemeChoisi, choisie)
		G.Montrer(c.embleme, not choisie)
	end
end

local function creerCarte(n)
	local c = CreateFrame("Button", "ForeverUICharacterCard" .. n, contenu)
	c:SetWidth(CARTE_L)
	c:SetHeight(CARTE_H)
	c:SetHitRectInsets(20, 12, 0, 0)
	c:RegisterForClicks("LeftButtonUp")
	local ic = CreateFrame("Frame", nil, c)
	ic:SetPoint("TOPLEFT", c, "TOPLEFT", 20, 0)
	ic:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -10, 0)
	local function tex(couche, atlas, point, x, y)
		local t = ic:CreateTexture(nil, couche)
		if atlas then G.PoserAtlas(t, atlas, true) end
		t:SetPoint(point, ic, point, x or 0, y or 0)
		return t
	end
	c.fond = tex("BACKGROUND", "glues-characterselect-card-singles", "CENTER")
	c.highlight = tex("BORDER", "glues-characterselect-card-singles-hover", "CENTER")
	c.selected = tex("ARTWORK", "glues-characterselect-card-selected", "TOPLEFT", -13, 14)
	c.selectedHighlight = tex("ARTWORK", "glues-characterselect-card-selected-hover", "TOPLEFT", -13, 14)
	c.embleme = tex("OVERLAY", nil, "TOPRIGHT", -20, -27)
	c.emblemeSurvol = tex("OVERLAY", nil, "TOPRIGHT", -20, -27)
	c.emblemeChoisi = tex("OVERLAY", nil, "TOPRIGHT", -17, -25)
	-- les textes (Text, setAllPoints de InnerContent)
	local function texte(police, l, h)
		local f = ic:CreateFontString(nil, "OVERLAY")
		f:SetFontObject(G.Police(police))
		f:SetJustifyH("LEFT")
		f:SetWidth(l)
		f:SetHeight(h)
		return f
	end
	c.nom = texte("GlueFontNormalHuge", 270, 22)
	c.nom:SetPoint("TOPLEFT", ic, "TOPLEFT", 14, -14)
	c.info = texte("GlueFontNormalLarge", 270, 18)
	c.info:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -4)
	c.zone = texte("GlueFontDisableLarge", 215, 18)
	c.zone:SetPoint("BOTTOMLEFT", ic, "BOTTOMLEFT", 14, 17)
	-- le service payant, a gauche de la carte
	c.service = CreateFrame("Button", nil, c)
	c.service:SetWidth(SERVICE)
	c.service:SetHeight(SERVICE)
	c.service:SetPoint("RIGHT", c, "LEFT", -5, 0)
	c.service:SetScript("OnClick", function(self, bouton, bas)
		CharacterSelect_PaidServiceOnClick(self, bouton, bas, self.type)
	end)
	c.service:SetScript("OnEnter", function(self)
		-- PaidServiceButtonMixin:OnEnter : ANCHOR_LEFT (4, -8), le coin bas
		-- droit de l'infobulle sur le coin haut gauche du bouton
		GlueTooltip_SetOwner(self, nil, 4, -8, "BOTTOMRIGHT", "TOPLEFT")
		GlueTooltip_SetText(self.infobulle, nil, 1.0, 1.0, 1.0)
	end)
	c.service:SetScript("OnLeave", function() GlueTooltip:Hide() end)

	c:SetScript("OnEnter", function(self) survolCarte(self, true) end)
	c:SetScript("OnLeave", function(self) survolCarte(self, false) end)
	c:SetScript("OnClick", function(self)
		CharacterSelectButton_OnClick(_G["CharSelectCharacterButton" .. self.index])
	end)
	c:SetScript("OnDoubleClick", function(self)
		CharacterSelectButton_OnDoubleClick(_G["CharSelectCharacterButton" .. self.index])
	end)
	c.selected:Hide()
	c.selectedHighlight:Hide()
	c.highlight:Hide()
	return c
end

for i = 1, MAX_CHARACTERS_DISPLAYED do
	etat.cartes[i] = creerCarte(i)
end

local function faction(i, race)
	local jeton = GetSelectBackgroundModel(i)
	return FACTIONS[jeton] or FACTIONS[race]
end

local function remplirCarte(c, i)
	local nom, race, classe, niveau, lieu, _, fantome, PCC, PRC, PFC = GetCharacterInfo(i)
	c.index = i
	c.nom:SetText(nom or "")
	c.nom:SetTextColor(1, 0.82, 0)
	local couleur = G.CLASSES[classe or ""]
	local classeTexte = classe or ""
	if couleur then
		classeTexte = string.format("|cff%02x%02x%02x%s|r", couleur[2] * 255, couleur[3] * 255, couleur[4] * 255, classeTexte)
	end
	c.info:SetFormattedText(fantome and CHARACTER_SELECT_INFO_GHOST or CHARACTER_SELECT_INFO, niveau or 0, classeTexte)
	c.info:SetTextColor(1, 1, 1)
	c.zone:SetText(lieu or "")
	c.zone:SetTextColor(0.5, 0.5, 0.5)

	c.faction = faction(i, race)
	for _, t in ipairs({ c.embleme, c.emblemeSurvol, c.emblemeChoisi }) do t:Hide() end
	if c.faction then
		local base = c.faction == "Alliance" and "glues-characterselect-icon-faction-alliance" or "glues-characterselect-icon-faction-horde"
		G.PoserAtlas(c.embleme, base, true)
		G.PoserAtlas(c.emblemeSurvol, base .. "-hover", true)
		G.PoserAtlas(c.emblemeChoisi, base .. "-selected", true)
	end

	-- le service payant (UpdateCharacterList : faction, sinon race, sinon
	-- apparence)
	local service
	if PFC then service = SERVICES[1] elseif PRC then service = SERVICES[2] elseif PCC then service = SERVICES[3] end
	if service then
		local s = c.service
		s:SetID(i)
		s.type = service[2]
		s.infobulle = service[4]
		-- l'image remplit le bouton (NormalTexture sans ancre chez camelot)
		s:SetNormalTexture(G.atlas[service[3]][1])
		G.PoserAtlas(s:GetNormalTexture(), service[3])
		s:GetNormalTexture():ClearAllPoints()
		s:GetNormalTexture():SetAllPoints(s)
		s:SetHighlightTexture(G.atlas[service[3] .. "-hover"][1])
		G.PoserAtlas(s:GetHighlightTexture(), service[3] .. "-hover")
		s:GetHighlightTexture():ClearAllPoints()
		s:GetHighlightTexture():SetAllPoints(s)
		s:Show()
	else
		c.service:Hide()
	end
end

-- la selection : carte choisie, embleme choisi
local function marquer()
	local choisi = CharacterSelect.selectedIndex or 0
	for _, c in ipairs(etat.cartes) do
		c.choisie = (c.index == choisi)
		G.Montrer(c.selected, c.choisie)
		survolCarte(c, c.dessus and c:IsShown())
	end
end

-- la mise en page : les cartes en colonne
local function ranger()
	local n = 0
	etat.visibles = {}
	for i = 1, MAX_CHARACTERS_DISPLAYED do
		local c = etat.cartes[i]
		local nom = i <= GetNumCharacters() and GetCharacterInfo(i)
		if nom then
			n = n + 1
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", contenu, "TOPLEFT", MARGE_G, -(n - 1) * (CARTE_H + ECART))
			c:Show()
			etat.visibles[n] = c
		else
			c:Hide()
		end
	end
	local total = n > 0 and (n * CARTE_H + (n - 1) * ECART) or 0
	contenu:SetHeight(math.max(1, total))
	-- arrondie : 10 cartes remplissent la zone exactement, une poussiere de
	-- virgule flottante ne doit pas faire paraitre la barre
	local vue = math.floor((zone:GetTop() or 0) - (zone:GetBottom() or 0) + 0.5)
	barreDefil:Regler(total, vue, etat.decalage)
	etat.decalage = barreDefil.position
	zone:SetVerticalScroll(etat.decalage)
	marquer()
end

-- garder la carte choisie en vue (fleches du clavier)
local function montrerChoisie()
	local choisi = CharacterSelect.selectedIndex or 0
	for n, c in ipairs(etat.visibles) do
		if c.index == choisi then
			local haut = (n - 1) * (CARTE_H + ECART)
			local vue = math.floor((zone:GetTop() or 0) - (zone:GetBottom() or 0) + 0.5)
			if haut < etat.decalage then
				barreDefil:Deplacer(haut)
			elseif haut + CARTE_H > etat.decalage + vue then
				barreDefil:Deplacer(haut + CARTE_H - vue)
			end
		end
	end
end

-- ------------------------------------------------------------ les boutons sous la liste

local creer = CharSelectCreateCharacterButton
G.BoutonTroisTranches(creer, "128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
creer:SetWidth(205)
creer:SetHeight(42)
creer:SetText(CREATE_CHARACTER)
creer:ClearAllPoints()
creer:SetPoint("BOTTOM", liste, "BOTTOM", -57, 23 - DESCENTE)

local corbeille = CharacterSelectDeleteButton
G.BoutonArt(corbeille, "128-RedButton-Delete")
corbeille:SetWidth(42)
corbeille:SetHeight(42)
corbeille:ClearAllPoints()
corbeille:SetPoint("LEFT", creer, "RIGHT", 6, 0)

-- ------------------------------------------------------------ le repli de la liste

local repli = CreateFrame("Button", "ForeverUICharacterSelectListToggle", ui)
repli:SetWidth(385)
repli:SetHeight(50)
repli:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -10, 6)
local fondRepli = repli:CreateTexture(nil, "BACKGROUND")
G.PoserAtlas(fondRepli, "glues-characterselect-listlauncher-bg", true)
fondRepli:SetPoint("RIGHT", repli, "RIGHT", -11, 0)
local fleche = CreateFrame("Button", nil, repli)
fleche:SetWidth(42)
fleche:SetHeight(42)
fleche:SetPoint("RIGHT", repli, "RIGHT", 0, 0)
local texteRepli = repli:CreateFontString(nil, "BORDER")
texteRepli:SetFontObject(G.Police("GlueFontHighlightLarge"))
texteRepli:SetPoint("RIGHT", fleche, "LEFT", -10, -1)
texteRepli:SetText(TEXTE.TOGGLE)

liste:ClearAllPoints()
liste:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -9, -69)
liste:SetPoint("BOTTOMRIGHT", repli, "TOPRIGHT", 0, 10)

local deplie = true
local function basculerListe(ouvert)
	deplie = ouvert
	G.Montrer(liste, ouvert)
	G.Montrer(corbeille, ouvert)
	G.BoutonArt(fleche, ouvert and "128-RedButton-ArrowDown" or "128-RedButton-ArrowUpGlow")
end
basculerListe(true)
local function surRepli()
	PlaySound("igMainMenuOptionCheckBoxOn")
	basculerListe(not deplie)
end
repli:SetScript("OnClick", surRepli)
fleche:SetScript("OnClick", surRepli)

-- ------------------------------------------------------------ le bas de l'ecran

CharSelectCharacterName:SetFontObject(G.Police("GameFontNormalHuge4Outline"))
CharSelectCharacterName:ClearAllPoints()
CharSelectCharacterName:SetPoint("BOTTOM", ui, "BOTTOM", 0, 114)

local entrer = CharSelectEnterWorldButton
G.BoutonTroisTranches(entrer, "128-RedButton", { "GameFontNormalOutline22", "GameFontHighlightOutline22", "GameFontDisableOutline22" })
entrer:SetWidth(250)
entrer:SetHeight(66)
entrer:ClearAllPoints()
entrer:SetPoint("BOTTOM", ui, "BOTTOM", 0, 45)

-- l'icone en OVERLAY (camelot) : en ARTWORK, comme le fond gris du bouton,
-- elle passait tantot dessous (fleche ternie, 28/09)
G.BoutonCarreIcone(CharacterSelectRotateLeft, "common-icon-rotateleft", 24, "OVERLAY")
CharacterSelectRotateLeft:ClearAllPoints()
CharacterSelectRotateLeft:SetPoint("TOP", entrer, "BOTTOM", -21, 4)
G.BoutonCarreIcone(CharacterSelectRotateRight, "common-icon-rotateright", 24, "OVERLAY")
CharacterSelectRotateRight:ClearAllPoints()
CharacterSelectRotateRight:SetPoint("LEFT", CharacterSelectRotateLeft, "RIGHT", -11, 0)

local retour = CharacterSelectBackButton
G.BoutonTroisTranches(retour, "128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
retour:SetWidth(188)
retour:SetHeight(42)
retour:ClearAllPoints()
retour:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 12, 12)
local flecheRetour = retour:CreateTexture(nil, "ARTWORK")
G.PoserAtlas(flecheRetour, "common-icon-backarrow")
flecheRetour:SetWidth(11)
flecheRetour:SetHeight(16)
flecheRetour:SetPoint("RIGHT", retour:GetFontString(), "LEFT")

-- l'oeil : cache toute l'interface (VisibilityFramesContainer), sauf lui
local oeil = CreateFrame("Button", "ForeverUICharacterSelectVisibilityToggle", ui)
oeil:SetWidth(42)
oeil:SetHeight(42)
oeil:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 205, 12)
G.BoutonArt(oeil, "128-RedButton-VisibilityOn")
local interfaceVisible = true
local MASQUABLES = { nav, repli, CharSelectCharacterName, entrer, CharacterSelectRotateLeft, CharacterSelectRotateRight, retour }
oeil:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOn")
	interfaceVisible = not interfaceVisible
	for _, f in ipairs(MASQUABLES) do G.Montrer(f, interfaceVisible) end
	if interfaceVisible then
		basculerListe(deplie)
	else
		liste:Hide()
		corbeille:Hide()
	end
	G.BoutonArt(oeil, interfaceVisible and "128-RedButton-VisibilityOn" or "128-RedButton-VisibilityOff")
end)

-- ------------------------------------------------------------ ce que le client ne montre plus

local function cacherClient()
	for i = 1, MAX_CHARACTERS_DISPLAYED do
		for _, nom in ipairs({ "CharSelectCharacterButton", "CharSelectCharacterCustomize", "CharSelectRaceChange", "CharSelectFactionChange" }) do
			local b = _G[nom .. i]
			if b then
				b:SetAlpha(0)
				b:EnableMouse(false)
			end
		end
	end
	CharacterSelectAddonsButton:Hide()
	CharSelectRealmName:Hide()
	CharSelectChangeRealmButton:Hide()
end
cacherClient()

-- ------------------------------------------------------------ apres le client

G.AccrocherFonction("UpdateCharacterList", function()
	cacherClient()
	for i = 1, math.min(GetNumCharacters(), MAX_CHARACTERS_DISPLAYED) do
		remplirCarte(etat.cartes[i], i)
	end
	-- Create Character reste en place ; sans place libre, il est grise
	creer:Show()
	if (CharacterSelect.createIndex or 0) > 0 and IsConnectedToServer() then
		creer:SetID(CharacterSelect.createIndex)
		creer:Enable()
	else
		creer:Disable()
	end
	ranger()
	montrerChoisie()
end)
G.AccrocherFonction("UpdateCharacterSelection", function()
	marquer()
	montrerChoisie()
end)
G.AccrocherFonction("UpdateAddonButton", function()
	CharacterSelectAddonsButton:Hide()
	rangerNav()
end)
G.Accrocher(CharacterSelect, "OnShow", function()
	poserFondListe()
	rangerNav()
	ranger()
end)
G.Accrocher(liste, "OnSizeChanged", poserFondListe)
