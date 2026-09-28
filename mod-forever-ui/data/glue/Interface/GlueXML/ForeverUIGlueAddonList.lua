-- ForeverUI -- la liste des AddOns de camelot, sur les donnees du client
-- 3.3.5.
--
-- RELEVE -- blizzard_addonlist/addonlist.xml et addonlist.lua (le fichier
-- commun : l'addon n'a ni camelot/ ni mainline/) ; blizzard_sharedxml :
-- mainline/shareduipaneltemplates.xml / .lua (ButtonFrameTemplate,
-- ButtonFrameTemplate_HidePortrait), shared/button/checkbuttontemplates.xml
-- (MinimalCheckbox*), shared/inputbox/inputboxtemplates.xml / .lua
-- (SearchBoxTemplate), shared/button/threeslicebuttontemplate.xml
-- (SharedButtonSmallTemplate), secureuipaneltemplates.xml / .lua
-- (UIPanelButtonTemplate), shared/scroll/* (ScrollBox, MinimalScrollBar) ;
-- blizzard_menu : mainline/menutemplates.xml / .lua (WowStyle1Dropdown,
-- MenuStyle1), menuvariants.lua et mainline/menuvariants.lua (radio,
-- surbrillance, sons) ; blizzard_gluexml/mainline/gluetooltip.xml.
--   * fenetre   ButtonFrameTemplate sans portrait, 600 x 550 a CENTER (0, 24),
--               titre ADDON_LIST ; encart (9, -60) / (-6, 26) ; croix
--               UIPanelCloseButton ;
--   * menu      WowStyle1DropdownTemplate 140 x 25 a TOPLEFT (12, -30) : fond
--               common-dropdown-textholder de (-8, 7) a (8, -9), fleche
--               common-dropdown-a-button (etats hover / pressed /
--               pressedhover / open / disabled) a RIGHT (1, -3), texte
--               GameFontHighlight de (8, -8) a la fleche ; sa liste
--               MenuStyle1 sous le bouton (TOPLEFT sur BOTTOMLEFT) : fond
--               common-dropdown-bg de (-10, 3) a (10, -3) a 0,925, marges
--               8 / 8 / 8 / 15, lignes de 20, au moins la largeur du bouton,
--               sinon texte + 16 + 20 ; radio common-dropdown-tickradial a
--               LEFT (-3, 0), choisi : common-dropdown-icon-radialtick-yellow
--               par-dessus ; texte GameFontHighlight a 1 a sa droite ;
--               surbrillance UI-QuestTitleHighlight en ADD ; ALL puis les
--               personnages ; sons de case a cocher a l'ouverture, au choix
--               et a la fermeture ;
--   * case      ForceLoad, MinimalCheckboxTemplate 30 x 29 a TOP (-80, -27),
--               ADDON_FORCE_LOAD en GameFontNormalSmall a LEFT (36, 0) ;
--   * recherche SearchBoxTemplate 160 x 22 a TOPRIGHT (-10, -31) : bord
--               common-search-border-* 8 x 20 (le gauche a -5), loupe 10 a
--               LEFT (1, -1) grise a 0,6 au repos, consigne SEARCH en
--               GameFontDisableSmall (0,35) de 16 a -20, texte
--               GameFontHighlightSmall, marges 16 / 20, effacement 17 a
--               RIGHT (-3, 0) (icone 10 a (3, -3), alpha 0,5, 1 au survol,
--               (4, -4) enfoncee) ; le titre ou le nom contient le texte,
--               sans casse ;
--   * liste     ScrollBox de LEFT 7 / TOP -65 (Performance repliee : elle ne
--               se montre jamais aux ecrans d'accueil) a BOTTOMRIGHT (-34,
--               28) ; marges 5, lignes de 16 espacees de 8 ; molette : 2 x
--               (16 + 8) ; MinimalScrollBar a (4, -3) / (4, 2) de la liste,
--               une fleche avance de 16 + 8 ;
--   * ligne     AddonListEntryTemplate : case MinimalCheckboxArtTemplate
--               24 x 24 a LEFT (5, 0) (bas du clic rentre de 8), coche grise
--               (desaturee) quand l'AddOn n'est actif que pour certains
--               personnages ; titre GameFontNormal 300 x 12 a LEFT (32, 0) ;
--               couleur dore / rouge / gris comme le client ; statut
--               GameFontNormalSmall a RIGHT (0, 0),
--               ADDON_<raison> quand l'AddOn ne se charge pas ; survol
--               UI-QuestTitleHighlight en ADD de LEFT 40 a RIGHT, 22 de haut ;
--               un clic gauche sur la ligne coche ou decoche ;
--   * infobulle celle des ecrans d'accueil (GlueTooltip, disposition
--               TooltipDefaultLayout) a ANCHOR_RIGHT (-270, 0) de la ligne :
--               titre et version (GlueFontNormal), notes en blanc et
--               dependances en dore (GlueFontNormalSmall) ; ADDON_BANNED_TOOLTIP
--               pour un AddOn banni ; sur la case, ENABLED_FOR_SOME ;
--   * boutons   SharedButtonSmallTemplate (128-RedButton, GameFontNormal /
--               Highlight / Disable) : Annuler 80 x 22 a BOTTOMRIGHT (-4, 4),
--               OK a sa gauche ; Tout activer / Tout desactiver 120 x 22 a
--               BOTTOMLEFT (4, 4) ;
--   * dialogue  AddonDialog (AddOns perimes) : DialogBorderTemplate, texte
--               GameFontNormalLarge, boutons UIPanelButtonTemplate 120 x 22
--               (UI-Panel-Button-*, fichiers identiques chez camelot, ecart
--               moyen 0,4 a 0,7 sur 255).
-- ECART (28/09, a la demande, comme la liste des royaumes) : fond noir
-- translucide a la place de la pierre et du marbre.
-- RETIRE a la demande (28/09) : l'icone de securite de 3.3.5 (jamais
-- montree par le client), et l'icone de camelot devant le titre
-- (INV_Misc_QuestionMark faute d'IconTexture, un « ? » rouge sur chaque
-- ligne). GARDE a la demande (28/09) : le bouton d'adresse de 3.3.5 et son
-- double de mise a jour, que camelot n'a pas -- 16 x 16 a droite de la
-- colonne du titre ; note UI-GuildButton-PublicNote-Up, ou etoile
-- Glues-AddOn-Icons (quatrieme quart) quand une version plus recente est
-- annoncee ; lueur du meme art en ADD ; infobulle GlueTooltip ; un clic
-- demande confirmation (CONFIRM_LAUNCH_ADDON_URL) comme le client.
-- ABSENT faute de donnees en 3.3.5 : categories et groupes (champs Category
-- et Group du .toc moderne), mesures de performance, menu du clic droit
-- (dependances, valeur par defaut : IsAddOnDefaultEnabled n'existe pas).
-- La fenetre du client (AddonListBackground) est eteinte ; sa logique reste
-- la sienne : OK et Annuler appellent AddonList_OnOk / AddonList_OnCancel,
-- le clavier reste le sien (Echap, Entree), et ses donnees passent par les
-- fonctions de 3.3.5 (GetAddOnInfo, GetAddOnEnableState, EnableAddOn...).

local G = ForeverUIGlue
local L = G.L

-- textes absents de 3.3.5 : G.L (ForeverUIGlueTextes)
local TEXTE = { SEARCH = L.GLUEADDONLIST_SEARCH }

local NOTE = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
local ETOILE = "Interface\\Glues\\CharacterSelect\\Glues-AddOn-Icons"
local SURVOL = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local SON = { oui = "igMainMenuOptionCheckBoxOn", non = "igMainMenuOptionCheckBoxOff" }

local M = {
	largeur = 600, hauteur = 550, y = 24,
	listeG = 7, listeH = 65, listeD = 34, listeB = 28,
	marge = 5, ligneH = 16, ecart = 8, molette = 2,
	menuL = 140, menuH = 25, ligneMenu = 20, menuMarges = { 8, 8, 8, 15 },
	infobulleL = 200,
}
M.pas = M.ligneH + M.ecart
M.listeL = M.largeur - M.listeG - M.listeD
M.listeVue = M.hauteur - M.listeH - M.listeB

-- 3.3.5 rend 1 / nil, parfois 0 / 1 : zero est vrai en Lua
local function vrai(v)
	return v and v ~= 0 and true or false
end

-- un etat de bouton ou de case sur un element d'atlas, sur tout le bouton
local function poserEtat(b, set, get, nom, mode)
	b[set](b, G.atlas[string.lower(nom)][1])
	local t = b[get](b)
	G.PoserAtlas(t, nom)
	t:ClearAllPoints()
	t:SetAllPoints(b)
	if mode then
		t:SetBlendMode(mode)
	end
	return t
end

-- MinimalCheckboxArtTemplate
local function caseMinimale(c)
	poserEtat(c, "SetNormalTexture", "GetNormalTexture", "checkbox-minimal")
	poserEtat(c, "SetPushedTexture", "GetPushedTexture", "checkbox-minimal")
	poserEtat(c, "SetHighlightTexture", "GetHighlightTexture", "checkbox-minimal", "ADD")
	poserEtat(c, "SetCheckedTexture", "GetCheckedTexture", "checkmark-minimal")
	poserEtat(c, "SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "checkmark-minimal-disabled")
end

-- ------------------------------------------------------------ la fenetre du client

-- eteinte en entier : image, cadres fils, souris ; l'alpha est le seul
-- reglage qu'aucun code du client ne reprend
AddonListBackground:SetAlpha(0)
AddonListBackground:Hide()
G.Accrocher(AddonListBackground, "OnShow", function(self)
	self:Hide()
end)

-- ------------------------------------------------------------ la fenetre

local F = CreateFrame("Frame", "ForeverUIAddonList", AddonList)
F:SetWidth(M.largeur)
F:SetHeight(M.hauteur)
F:SetPoint("CENTER", AddonList, "CENTER", 0, M.y)
F:EnableMouse(true)
G.Fenetre(F, ADDON_LIST, true)
local encart = CreateFrame("Frame", nil, F)
encart:SetPoint("TOPLEFT", F, "TOPLEFT", 9, -60)
encart:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -6, 26)
G.Encart(F, encart, true)

-- les commandes passent devant la liste : une ligne a moitie defilee
-- deborde du cadre de la liste
local DEVANT = F:GetFrameLevel() + 10

local croix = CreateFrame("Button", "ForeverUIAddonListCloseButton", F)
croix:SetFrameLevel(DEVANT + 1)
G.CroixFenetre(croix, F)
croix:SetScript("OnClick", function()
	AddonList_OnCancel()
end)

local etat = { personnage = nil, lignes = {}, position = 0, ouvert = false }
local maj

-- ------------------------------------------------------------ l'infobulle

local bulle = CreateFrame("Frame", "ForeverUIAddonListTooltip", AddonList)
bulle:SetFrameStrata("TOOLTIP")
bulle:SetClampedToScreen(true)
bulle:Hide()
G.FondInfobulle(bulle, "TooltipDefaultLayout", G.GLUE_BACKDROP_COLOR)
bulle.titre = bulle:CreateFontString(nil, "ARTWORK")
bulle.titre:SetFontObject(G.Police("GlueFontNormal"))
bulle.titre:SetJustifyH("LEFT")
bulle.titre:SetPoint("TOPLEFT", bulle, "TOPLEFT", 10, -10)
bulle.version = bulle:CreateFontString(nil, "ARTWORK")
bulle.version:SetFontObject(G.Police("GlueFontNormal"))
bulle.version:SetJustifyH("RIGHT")
bulle.version:SetPoint("TOPRIGHT", bulle, "TOPRIGHT", -10, -10)
bulle.notes = bulle:CreateFontString(nil, "ARTWORK")
bulle.notes:SetFontObject(G.Police("GlueFontNormalSmall"))
bulle.notes:SetJustifyH("LEFT")
bulle.notes:SetTextColor(1, 1, 1)
bulle.notes:SetPoint("TOPLEFT", bulle.titre, "BOTTOMLEFT", 0, -2)
bulle.deps = bulle:CreateFontString(nil, "ARTWORK")
bulle.deps:SetFontObject(G.Police("GlueFontNormalSmall"))
bulle.deps:SetJustifyH("LEFT")
bulle.deps:SetTextColor(1, 0.82, 0)

-- lignes : { titre, version, notes, deps } ; le texte plie a la largeur
-- du titre, 200 au moins (celle de l'infobulle d'AddOn de 3.3.5 : le
-- GameTooltip de camelot plie dans le moteur, sans nombre dans le code)
local function montrerBulle(proprio, titre, version, notes, deps)
	bulle.titre:SetText(titre or "")
	bulle.version:SetText(version or "")
	local l = bulle.titre:GetStringWidth()
	if version and version ~= "" then
		l = l + 20 + bulle.version:GetStringWidth()
	end
	local plie = math.max(M.infobulleL, l)
	local h = bulle.titre:GetHeight()
	local dessous = bulle.titre
	for _, v in ipairs({ { bulle.notes, notes }, { bulle.deps, deps } }) do
		local fs, texte = v[1], v[2]
		if texte and texte ~= "" then
			fs:SetWidth(plie)
			fs:SetText(texte)
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", dessous, "BOTTOMLEFT", 0, -2)
			fs:Show()
			h = h + 2 + fs:GetHeight()
			dessous = fs
		else
			fs:SetText("")
			fs:Hide()
		end
	end
	if (notes and notes ~= "") or (deps and deps ~= "") then
		l = plie
	end
	bulle:SetWidth(l + 20)
	bulle:SetHeight(h + 20)
	bulle:ClearAllPoints()
	bulle:SetPoint("BOTTOMLEFT", proprio, "TOPRIGHT", -270, 0)
	bulle:Show()
end

local function metadonnee(index, champ)
	if not GetAddOnMetadata then
		return nil
	end
	local ok, v = pcall(GetAddOnMetadata, index, champ)
	if ok then
		return v
	end
end

-- AddonTooltip_Update de camelot
local function bulleAddOn(ligne)
	local index = ligne.index
	local nom, titre, notes, _, _, _, securite = GetAddOnInfo(index)
	if securite == "BANNED" then
		montrerBulle(ligne, ADDON_BANNED_TOOLTIP)
	else
		montrerBulle(ligne, titre or nom, metadonnee(index, "Version"), notes,
			AddonTooltip_BuildDeps(GetAddOnDependencies(index)))
	end
end

-- ------------------------------------------------------------ le menu des personnages

local menu = CreateFrame("Button", "ForeverUIAddonListDropdown", F)
menu:SetFrameLevel(DEVANT)
menu:SetWidth(M.menuL)
menu:SetHeight(M.menuH)
menu:SetPoint("TOPLEFT", F, "TOPLEFT", 12, -30)
menu:RegisterForClicks("LeftButtonDown")
local fondMenu = G.AtlasEtire(menu, "common-dropdown-textholder", "BACKGROUND")
fondMenu.rect:SetPoint("TOPLEFT", menu, "TOPLEFT", -8, 7)
fondMenu.rect:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 8, -9)
menu.fleche = menu:CreateTexture(nil, "OVERLAY")
G.PoserAtlas(menu.fleche, "common-dropdown-a-button", true)
menu.fleche:SetPoint("RIGHT", menu, "RIGHT", 1, -3)
menu.texte = menu:CreateFontString(nil, "OVERLAY")
menu.texte:SetFontObject(G.Police("GameFontHighlight"))
menu.texte:SetJustifyH("LEFT")
menu.texte:SetHeight(10)
menu.texte:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -8)
menu.texte:SetPoint("TOPRIGHT", menu.fleche, "LEFT", 0, 0)

-- GetWowStyle1ArrowButtonState
local function peindreMenu()
	local n = "common-dropdown-a-button"
	if not vrai(menu:IsEnabled()) then
		n = n .. "-disabled"
	elseif menu.bas and menu.dessus then
		n = n .. "-pressedhover"
	elseif menu.dessus then
		n = n .. "-hover"
	elseif menu.bas then
		n = n .. "-pressed"
	elseif etat.ouvert then
		n = n .. "-open"
	end
	G.PoserAtlas(menu.fleche, n, true)
end
menu:SetScript("OnEnter", function(self) self.dessus = true; peindreMenu() end)
menu:SetScript("OnLeave", function(self) self.dessus = false; peindreMenu() end)
menu:SetScript("OnMouseDown", function(self) self.bas = true; peindreMenu() end)
menu:SetScript("OnMouseUp", function(self) self.bas = false; peindreMenu() end)

-- la liste ouverte (MenuStyle1)
local liste = CreateFrame("Frame", "ForeverUIAddonListDropdownMenu", F)
liste:SetFrameStrata("FULLSCREEN_DIALOG")
liste:SetFrameLevel(20)
liste:EnableMouse(true)
liste:Hide()
local fondListe = G.AtlasEtire(liste, "common-dropdown-bg", "BACKGROUND")
fondListe.rect:SetPoint("TOPLEFT", liste, "TOPLEFT", -10, 3)
fondListe.rect:SetPoint("BOTTOMRIGHT", liste, "BOTTOMRIGHT", 10, -3)
fondListe.rect:SetAlpha(0.925)
for _, t in ipairs(fondListe.pieces) do
	t:SetAlpha(0.925)
end
-- un clic hors de la liste la referme
local capteur = CreateFrame("Button", nil, F)
capteur:SetFrameStrata("FULLSCREEN_DIALOG")
capteur:SetFrameLevel(10)
capteur:SetAllPoints(GlueParent)
capteur:Hide()

local choix = {}

local function fermerListe(silence)
	if not etat.ouvert then
		return
	end
	etat.ouvert = false
	liste:Hide()
	capteur:Hide()
	if not silence then
		PlaySound(SON.non)
	end
	peindreMenu()
end
capteur:SetScript("OnClick", function() fermerListe() end)

-- ALL, puis chaque personnage (AddonListCharacterDropDown_Initialize)
local function options()
	local o = { { texte = ALL, valeur = nil } }
	for i = 1, GetNumCharacters() do
		local nom = GetCharacterInfo(i)
		o[#o + 1] = { texte = nom, valeur = nom }
	end
	return o
end

local function texteChoisi()
	menu.texte:SetText(etat.personnage or ALL)
end

local function elementListe(k)
	if choix[k] then
		return choix[k]
	end
	local e = CreateFrame("Button", nil, liste)
	e:SetHeight(M.ligneMenu)
	e.survol = e:CreateTexture(nil, "BACKGROUND")
	e.survol:SetTexture(SURVOL)
	e.survol:SetBlendMode("ADD")
	e.survol:SetAllPoints(e)
	e.survol:Hide()
	e.rond = e:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(e.rond, "common-dropdown-tickradial", true)
	e.rond:SetPoint("LEFT", e, "LEFT", -3, 0)
	e.point = e:CreateTexture(nil, "OVERLAY")
	G.PoserAtlas(e.point, "common-dropdown-icon-radialtick-yellow", true)
	e.point:SetPoint("TOPLEFT", e.rond, "TOPLEFT")
	e.texte = e:CreateFontString(nil, "ARTWORK")
	e.texte:SetFontObject(G.Police("GameFontHighlight"))
	e.texte:SetJustifyH("LEFT")
	e.texte:SetHeight(M.ligneMenu)
	e.texte:SetPoint("LEFT", e.rond, "RIGHT", 1, 0)
	e:SetScript("OnEnter", function(self) self.survol:Show() end)
	e:SetScript("OnLeave", function(self) self.survol:Hide() end)
	e:SetScript("OnClick", function(self)
		PlaySound(SON.oui)
		etat.personnage = self.valeur
		texteChoisi()
		fermerListe()
		maj()
	end)
	choix[k] = e
	return e
end

local function ouvrirListe()
	local o = options()
	local g, h, d, b = M.menuMarges[1], M.menuMarges[2], M.menuMarges[3], M.menuMarges[4]
	-- l'etendue d'une ligne : radio (-3 .. 15), 1, texte ; plus 20
	local large = 0
	for k, v in ipairs(o) do
		local e = elementListe(k)
		e.texte:SetText(v.texte)
		large = math.max(large, 16 + e.texte:GetStringWidth() + 20)
	end
	large = math.max(large, M.menuL - g - d)
	for k, v in ipairs(o) do
		local e = choix[k]
		e.valeur = v.valeur
		e:SetWidth(large)
		e:ClearAllPoints()
		e:SetPoint("TOPLEFT", liste, "TOPLEFT", g, -(h + (k - 1) * M.ligneMenu))
		G.Montrer(e.point, v.valeur == etat.personnage)
		e.survol:Hide()
		e:Show()
	end
	for k = #o + 1, #choix do
		choix[k]:Hide()
	end
	liste:SetWidth(g + large + d)
	liste:SetHeight(h + #o * M.ligneMenu + b)
	liste:ClearAllPoints()
	liste:SetPoint("TOPLEFT", menu, "BOTTOMLEFT", 0, 0)
	etat.ouvert = true
	liste:Show()
	capteur:Show()
	PlaySound(SON.oui)
	peindreMenu()
end
menu:SetScript("OnClick", function()
	if etat.ouvert then
		fermerListe()
	else
		ouvrirListe()
	end
end)

-- ------------------------------------------------------------ AddOns perimes

local force = CreateFrame("CheckButton", "ForeverUIAddonListForceLoad", F)
force:SetFrameLevel(DEVANT)
force:SetWidth(30)
force:SetHeight(29)
force:SetPoint("TOP", F, "TOP", -80, -27)
caseMinimale(force)
force.texte = force:CreateFontString(nil, "ARTWORK")
force.texte:SetFontObject(G.Police("GameFontNormalSmall"))
force.texte:SetPoint("LEFT", force, "LEFT", 36, 0)
force.texte:SetText(ADDON_FORCE_LOAD)
force:SetScript("OnClick", function(self)
	if vrai(self:GetChecked()) then
		PlaySound(SON.oui)
		SetAddonVersionCheck(0)
	else
		PlaySound(SON.non)
		SetAddonVersionCheck(1)
	end
	maj()
end)

-- ------------------------------------------------------------ la recherche

local cherche = CreateFrame("EditBox", "ForeverUIAddonListSearchBox", F)
cherche:SetFrameLevel(DEVANT)
cherche:SetWidth(160)
cherche:SetHeight(22)
cherche:SetPoint("TOPRIGHT", F, "TOPRIGHT", -10, -31)
cherche:SetAutoFocus(false)
cherche:EnableMouse(true)
cherche:SetFontObject(G.Police("GameFontHighlightSmall"))
cherche:SetTextInsets(16, 20, 0, 0)
do
	local g = cherche:CreateTexture(nil, "BACKGROUND")
	G.PoserAtlas(g, "common-search-border-left")
	g:SetWidth(8)
	g:SetHeight(20)
	g:SetPoint("LEFT", cherche, "LEFT", -5, 0)
	local d = cherche:CreateTexture(nil, "BACKGROUND")
	G.PoserAtlas(d, "common-search-border-right")
	d:SetWidth(8)
	d:SetHeight(20)
	d:SetPoint("RIGHT", cherche, "RIGHT", 0, 0)
	local m = cherche:CreateTexture(nil, "BACKGROUND")
	G.PoserAtlas(m, "common-search-border-middle")
	m:SetHeight(20)
	m:SetPoint("LEFT", g, "RIGHT")
	m:SetPoint("RIGHT", d, "LEFT")
end
cherche.loupe = cherche:CreateTexture(nil, "OVERLAY")
G.PoserAtlas(cherche.loupe, "common-search-magnifyingglass")
cherche.loupe:SetWidth(10)
cherche.loupe:SetHeight(10)
cherche.loupe:SetPoint("LEFT", cherche, "LEFT", 1, -1)
cherche.consigne = cherche:CreateFontString(nil, "ARTWORK")
cherche.consigne:SetFontObject(G.Police("GameFontDisableSmall"))
cherche.consigne:SetJustifyH("LEFT")
cherche.consigne:SetJustifyV("MIDDLE")
cherche.consigne:SetPoint("TOPLEFT", cherche, "TOPLEFT", 16, 0)
cherche.consigne:SetPoint("BOTTOMRIGHT", cherche, "BOTTOMRIGHT", -20, 0)
cherche.consigne:SetTextColor(0.35, 0.35, 0.35)
cherche.consigne:SetText(TEXTE.SEARCH)

local effacer = CreateFrame("Button", nil, cherche)
effacer:SetWidth(17)
effacer:SetHeight(17)
effacer:SetPoint("RIGHT", cherche, "RIGHT", -3, 0)
effacer.icone = effacer:CreateTexture(nil, "ARTWORK")
G.PoserAtlas(effacer.icone, "common-search-clearbutton")
effacer.icone:SetWidth(10)
effacer.icone:SetHeight(10)
effacer.icone:SetPoint("TOPLEFT", effacer, "TOPLEFT", 3, -3)
effacer.icone:SetAlpha(0.5)
effacer:SetScript("OnEnter", function(self) self.icone:SetAlpha(1) end)
effacer:SetScript("OnLeave", function(self) self.icone:SetAlpha(0.5) end)
effacer:SetScript("OnMouseDown", function(self) self.icone:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -4) end)
effacer:SetScript("OnMouseUp", function(self) self.icone:SetPoint("TOPLEFT", self, "TOPLEFT", 3, -3) end)
effacer:SetScript("OnClick", function()
	PlaySound(SON.oui)
	cherche:SetText("")
	cherche:ClearFocus()
end)
effacer:Hide()

-- SearchBoxTemplate_On* : loupe grise et effacement cache au repos
local function peindreRecherche()
	local vide = (cherche:GetText() or "") == ""
	local actif = cherche.focus or not vide
	local g = actif and 1 or 0.6
	cherche.loupe:SetVertexColor(g, g, g)
	G.Montrer(effacer, actif)
	G.Montrer(cherche.consigne, vide)
end
cherche:SetScript("OnEditFocusGained", function(self) self.focus = true; peindreRecherche() end)
cherche:SetScript("OnEditFocusLost", function(self) self.focus = false; peindreRecherche() end)
cherche:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
cherche:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
cherche:SetScript("OnTextChanged", function()
	peindreRecherche()
	maj()
end)
peindreRecherche()

-- ------------------------------------------------------------ la liste

local vue = CreateFrame("ScrollFrame", "ForeverUIAddonListScrollBox", F)
vue:SetPoint("TOPLEFT", F, "TOPLEFT", M.listeG, -M.listeH)
vue:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -M.listeD, M.listeB)
local contenu = CreateFrame("Frame", nil, vue)
contenu:SetWidth(M.listeL)
contenu:SetHeight(1)
vue:SetScrollChild(contenu)

local barre = G.BarreMinimale(F, "ForeverUIAddonListScrollBar")
barre:SetPoint("TOPLEFT", vue, "TOPRIGHT", 4, -3)
barre:SetPoint("BOTTOMLEFT", vue, "BOTTOMRIGHT", 4, 2)
barre.pas = M.pas

-- une ligne entierement hors de la vue se cache
local function defiler(position)
	etat.position = position
	vue:SetVerticalScroll(position)
	for k, l in ipairs(etat.lignes) do
		if l.rang then
			local haut = M.marge + (l.rang - 1) * M.pas
			G.Montrer(l, haut + M.ligneH > position and haut < position + M.listeVue)
		end
	end
end
barre.surDefilement = defiler

vue:EnableMouseWheel(true)
vue:SetScript("OnMouseWheel", function(_, sens)
	barre:Deplacer(barre.position - sens * M.molette * M.pas)
end)

local function ligne(k)
	if etat.lignes[k] then
		return etat.lignes[k]
	end
	local l = CreateFrame("Button", nil, contenu)
	l:SetHeight(M.ligneH)
	l:SetWidth(M.listeL - 2 * M.marge)
	l:SetPoint("TOPLEFT", contenu, "TOPLEFT", M.marge, -(M.marge + (k - 1) * M.pas))
	l:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	local s = l:CreateTexture(nil, "HIGHLIGHT")
	s:SetTexture(SURVOL)
	s:SetBlendMode("ADD")
	s:SetHeight(22)
	s:SetPoint("LEFT", l, "LEFT", 40, 0)
	s:SetPoint("RIGHT", l, "RIGHT")
	l.titre = l:CreateFontString(nil, "BACKGROUND")
	l.titre:SetFontObject(G.Police("GameFontNormal"))
	l.titre:SetJustifyH("LEFT")
	l.titre:SetWidth(300)
	l.titre:SetHeight(12)
	l.titre:SetPoint("LEFT", l, "LEFT", 32, 0)
	-- le bouton d'adresse et celui de mise a jour, a la meme place
	l.adresse = CreateFrame("Button", nil, l)
	l.adresse:SetNormalTexture(NOTE)
	l.adresse:SetHighlightTexture(NOTE)
	l.adresse:GetHighlightTexture():SetBlendMode("ADD")
	l.maj = CreateFrame("Button", nil, l)
	l.maj:SetNormalTexture(ETOILE)
	l.maj:GetNormalTexture():SetTexCoord(0.75, 1, 0, 1)
	l.maj:SetHighlightTexture(ETOILE)
	l.maj:GetHighlightTexture():SetTexCoord(0.75, 1, 0, 1)
	l.maj:GetHighlightTexture():SetBlendMode("ADD")
	for _, b in ipairs({ l.adresse, l.maj }) do
		b:SetWidth(16)
		b:SetHeight(16)
		b:SetPoint("LEFT", l.titre, "RIGHT", 0, 0)
		b:Hide()
		b:SetScript("OnEnter", function(self)
			GlueTooltip_SetOwner(self)
			GlueTooltip_SetText(self.infobulle)
		end)
		b:SetScript("OnLeave", function() GlueTooltip:Hide() end)
		-- le clic du client : AddonList.selectedID, puis la confirmation
		b:SetScript("OnClick", function(self)
			AddonList.selectedID = self:GetParent().index
			AddonDialog_Show("CONFIRM_LAUNCH_ADDON_URL", self.url)
		end)
	end
	l.statut = l:CreateFontString(nil, "BACKGROUND")
	l.statut:SetFontObject(G.Police("GameFontNormalSmall"))
	l.statut:SetJustifyH("LEFT")
	l.statut:SetPoint("RIGHT", l, "RIGHT", 0, 0)
	local c = CreateFrame("CheckButton", nil, l)
	c:SetWidth(24)
	c:SetHeight(24)
	c:SetPoint("LEFT", l, "LEFT", 5, 0)
	c:SetHitRectInsets(0, 0, 0, 8)
	caseMinimale(c)
	l.case = c
	-- AddonList_Enable
	c:SetScript("OnClick", function(self)
		local index = self:GetParent().index
		if vrai(self:GetChecked()) then
			PlaySound(SON.oui)
			EnableAddOn(etat.personnage, index)
		else
			PlaySound(SON.non)
			DisableAddOn(etat.personnage, index)
		end
		maj()
	end)
	c:SetScript("OnEnter", function(self)
		if self.infobulle then
			montrerBulle(self, self.infobulle)
		end
	end)
	c:SetScript("OnLeave", function() bulle:Hide() end)
	l:SetScript("OnClick", function(self, bouton)
		if bouton == "LeftButton" then
			self.case:Click()
		end
	end)
	l:SetScript("OnEnter", function(self) bulleAddOn(self) end)
	l:SetScript("OnLeave", function() bulle:Hide() end)
	etat.lignes[k] = l
	return l
end

-- AddonList_InitAddon de camelot, sur GetAddOnInfo et GetAddOnEnableState
local function remplir(l, index)
	local nom, titre, _, adresse, chargeable, raison, _, nouvelle = GetAddOnInfo(index)
	local niveau = GetAddOnEnableState(etat.personnage, index) or 0
	local actif = niveau > 0
	l.index = index
	local c = l.case
	c:SetChecked(actif)
	c:GetCheckedTexture():SetDesaturated(niveau == 1)
	c.infobulle = (niveau == 1) and ENABLED_FOR_SOME or nil
	if chargeable or (actif and (raison == "DEP_DEMAND_LOADED" or raison == "DEMAND_LOADED")) then
		l.titre:SetTextColor(1.0, 0.78, 0.0)
	elseif actif and raison ~= "DEP_DISABLED" then
		l.titre:SetTextColor(1.0, 0.1, 0.1)
	else
		l.titre:SetTextColor(0.5, 0.5, 0.5)
	end
	l.titre:SetText(titre or nom or "")
	-- AddonList_Update de 3.3.5 : l'etoile si une version plus recente est
	-- annoncee, sinon la note, quand il y a une adresse
	l.adresse:Hide()
	l.maj:Hide()
	if adresse then
		local b = nouvelle and l.maj or l.adresse
		b.url = adresse
		b.infobulle = (nouvelle and ADDON_UPDATE_AVAILABLE or "") .. CLICK_TO_LAUNCH_ADDON_URL .. adresse
		b:Show()
	end
	if not chargeable and raison then
		l.statut:SetText(_G["ADDON_" .. raison] or raison)
	else
		l.statut:SetText("")
	end
end

-- AddonList_Update de camelot : le filtre, les lignes, l'etendue ; la
-- position est gardee (RetainScrollPosition)
maj = function()
	local filtre = string.lower(cherche:GetText() or "")
	local n = 0
	for index = 1, GetNumAddOns() do
		local nom, titre = GetAddOnInfo(index)
		if filtre == "" or string.find(string.lower(titre or ""), filtre, 1, true)
			or string.find(string.lower(nom or ""), filtre, 1, true) then
			n = n + 1
			local l = ligne(n)
			l.rang = n
			remplir(l, index)
		end
	end
	for k = n + 1, #etat.lignes do
		etat.lignes[k].rang = nil
		etat.lignes[k]:Hide()
	end
	local total = 0
	if n > 0 then
		total = 2 * M.marge + n * M.ligneH + (n - 1) * M.ecart
	end
	contenu:SetHeight(math.max(total, 1))
	vue:UpdateScrollChildRect()
	barre:Regler(total, M.listeVue, etat.position)
	defiler(barre.position)
	force:SetChecked(not vrai(IsAddonVersionCheckEnabled()))
	texteChoisi()
end

-- ------------------------------------------------------------ les boutons

local POLICES = { "GameFontNormal", "GameFontHighlight", "GameFontDisable" }
local annuler = G.CreerBoutonTroisTranches("ForeverUIAddonListCancelButton", F, 80, 22, "128-RedButton", POLICES, CANCEL)
annuler:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -4, 4)
annuler:SetScript("OnClick", function() AddonList_OnCancel() end)
local ok = G.CreerBoutonTroisTranches("ForeverUIAddonListOkayButton", F, 80, 22, "128-RedButton", POLICES, OKAY)
ok:SetPoint("TOPRIGHT", annuler, "TOPLEFT", 0, 0)
ok:SetScript("OnClick", function() AddonList_OnOk() end)
local tout = G.CreerBoutonTroisTranches("ForeverUIAddonListEnableAllButton", F, 120, 22, "128-RedButton", POLICES, ENABLE_ALL_ADDONS)
tout:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", 4, 4)
tout:SetScript("OnClick", function()
	EnableAllAddOns(etat.personnage)
	maj()
end)
local aucun = G.CreerBoutonTroisTranches("ForeverUIAddonListDisableAllButton", F, 120, 22, "128-RedButton", POLICES, DISABLE_ALL_ADDONS)
aucun:SetPoint("TOPLEFT", tout, "TOPRIGHT", 0, 0)
aucun:SetScript("OnClick", function()
	DisableAllAddOns(etat.personnage)
	maj()
end)
for _, b in ipairs({ annuler, ok, tout, aucun }) do
	b:SetFrameLevel(DEVANT)
end

-- ------------------------------------------------------------ apres le client

G.AccrocherFonction("AddonList_Update", function()
	maj()
end)
G.Accrocher(AddonList, "OnHide", function()
	fermerListe(true)
	bulle:Hide()
end)

-- ------------------------------------------------------------ le dialogue des AddOns perimes

local boutonPanneau = G.BoutonPanneau

-- DialogBorderTemplate de 512 ; AddonDialog_Show du client pose les boutons
-- et la hauteur comme camelot (16 + texte + 8 + bouton + 16)
AddonDialogBackground:SetBackdrop(nil)
G.CadreDialogue(AddonDialogBackground)
AddonDialogText:SetFontObject(G.Police("GameFontNormalLarge"))
for i = 1, 2 do
	local b = _G["AddonDialogButton" .. i]
	b:SetWidth(120)
	b:SetHeight(22)
	boutonPanneau(b)
end
