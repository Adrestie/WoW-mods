-- ForeverUI -- les options des ecrans d'accueil : le menu Options
-- (OptionsSelectFrame), les fenetres Video (VideoOptionsFrame) et Son
-- (AudioOptionsFrame), a la DA de camelot.
--
-- CHOIX DE L'UTILISATEUR (28/09) : « 3.3.5 rhabillee ». Camelot n'a ni ce
-- menu ni ces deux fenetres (ses ecrans d'accueil ouvrent SettingsPanel) ;
-- on garde les ecrans du client -- places, tailles, logique, reglages -- et
-- on pose l'art de camelot :
--   * menu Options : DialogBorderTemplate et DialogHeaderTemplate (OPTIONS),
--     comme le menu du jeu ; boutons rouges (128-RedButton) poses sur la
--     partie visible des boutons de 3.3.5 (Glue-Panel-Button-*, releve de
--     l'image : opaque de 8 a 140 sur 148, de 6 a 40 sur 48) : Video et Son
--     196 x 32, 3 entre eux ; Reset 196 x 27 et Close 112 x 27, 12 au-dessus
--     du bas, 20 et 15 des bords ; polices du client (GlueFont*) ;
--   * fenetres Video et Son : SettingsFrameTemplate de camelot (la fenetre
--     de ses reglages) -- cadre de metal ButtonFrameTemplateNoPortrait, titre
--     GameFontNormal a -5, croix UIPanelCloseButton a (-2, 1) (elle fait ce
--     que fait Cancel), sans les stries de ButtonFrameTemplate ; ECART (comme
--     les listes des royaumes et des AddOns, a la demande) : fond noir
--     translucide ; le cadre des panneaux devient un encart
--     (InsetFrameTemplate) ; boutons UIPanelButtonTemplate 96 x 22 (Close et
--     Apply de SettingsPanel) : Okay / Cancel / Apply colles a BOTTOMRIGHT
--     (-16, 16), 2 entre eux (ApplyButton), dans l'ordre du client ; Defaults
--     a la place miroir, BOTTOMLEFT (16, 16) ;
--   * liste des categories : SettingsCategoryListButtonTemplate -- choisie :
--     Options_List_Active a sa taille, centree, et GameFontHighlight ;
--     survolee : Options_List_Hover ; sinon GameFontNormal (sous-categorie :
--     GameFontHighlight) ; pas de cadre (la liste de camelot n'en a pas ;
--     Options_InnerFrame, 886 x 618, ne tient pas dans ces fenetres) ;
--   * cases : SettingsCheckboxTemplate (checkbox-minimal, checkmark-minimal,
--     -disabled ; pas de lueur au survol), a la taille du client (26) ;
--   * curseurs : MinimalSliderTemplate (Minimal_SliderBar_Left / Right a leur
--     taille, _Minimal_SliderBar_Middle entre eux, bouton
--     Minimal_SliderBar_Button), a la taille du client (17 de haut, celle de
--     la glissiere) ; bouton a 0,7 quand le curseur est desactive ; sans les
--     fleches de MinimalSliderWithSteppers (le client n'en a pas) ; ECART
--     (28/09, a la demande : « poignees trop grosses ») : bouton de 16 x 15
--     au lieu de 20 x 19, art affine x4 (minimalsliderbarc60-hd,
--     tools/affiner_champs.py) ;
--   * menus deroulants : WowStyle2 (celui de SettingsDropdownControl), voir
--     ForeverUIGlueMenuDeroulant.lua ; sans les fleches de
--     DropdownWithSteppers ;
--   * cadres de groupe (OptionsBoxTemplate, que camelot n'a pas) : le bord
--     des infobulles de camelot au gris du client ; infobulle a l'art des
--     infobulles ; polices de camelot a la place de celles du client (memes
--     noms).
-- Le client garde la main sur tout : ses panneaux, ses CVars, ses boutons ;
-- on ne fait que reposer l'art et les polices apres lui.

local G = ForeverUIGlue

-- 3.3.5 rend 1 / nil, parfois 0 / 1 : zero est vrai en Lua
local function vrai(v)
	return v and v ~= 0 and true or false
end

-- une police de camelot pour une police du client, si camelot la connait
local function policeCamelot(objet)
	local nom = objet and objet.GetName and objet:GetName()
	if not nom or string.find(nom, "^ForeverUIGlue_") then
		return nil
	end
	return _G["ForeverUIGlue_" .. nom]
end

local function reposerPolice(fs)
	local p = policeCamelot(fs:GetFontObject())
	if p then
		fs:SetFontObject(p)
	end
end

-- toutes les polices d'un cadre : ses FontString, et les polices de bouton
local function reposerPolices(cadre)
	for _, r in ipairs({ cadre:GetRegions() }) do
		if r:GetObjectType() == "FontString" then
			reposerPolice(r)
		end
	end
	if cadre.GetNormalFontObject then
		for _, v in ipairs({ { "GetNormalFontObject", "SetNormalFontObject" },
				{ "GetHighlightFontObject", "SetHighlightFontObject" },
				{ "GetDisabledFontObject", "SetDisabledFontObject" } }) do
			local p = policeCamelot(cadre[v[1]](cadre))
			if p then
				cadre[v[2]](cadre, p)
			end
		end
	end
end

-- ------------------------------------------------------------ l'infobulle

-- OptionsTooltip : celle des ecrans d'accueil (GlueTooltip, disposition
-- TooltipDefaultLayout, fond 0,09) ; lignes GlueFontNormal puis
-- GlueFontNormalSmall
OptionsTooltip:SetBackdrop(nil)
G.FondInfobulle(OptionsTooltip, "TooltipDefaultLayout", G.GLUE_BACKDROP_COLOR)
OptionsTooltipText1:SetFontObject(G.Police("GlueFontNormal"))
OptionsTooltipText2:SetFontObject(G.Police("GlueFontNormalSmall"))

-- ------------------------------------------------------------ les commandes

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

-- SettingsCheckboxTemplate, a la taille de la case du client (26) : pas de
-- lueur au survol
local function habillerCase(c)
	poserEtat(c, "SetNormalTexture", "GetNormalTexture", "checkbox-minimal")
	poserEtat(c, "SetPushedTexture", "GetPushedTexture", "checkbox-minimal")
	local lueur = c:GetHighlightTexture()
	if lueur then
		lueur:SetTexture(nil)
		lueur:SetAlpha(0)
	end
	poserEtat(c, "SetCheckedTexture", "GetCheckedTexture", "checkmark-minimal")
	poserEtat(c, "SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "checkmark-minimal-disabled")
	reposerPolices(c)
end

-- OptionsBoxTemplate : le bord des infobulles de camelot au gris du client
-- (0,4), sans fond (le client n'en pose pas)
local function habillerBoite(f)
	f:SetBackdrop(nil)
	local p = G.NeufTranches(f, "TooltipDefaultLayout")
	G.CouleursNeufTranches(p, nil, { 0.4, 0.4, 0.4 })
	p.Center:Hide()
	reposerPolices(f)
end

-- MinimalSliderTemplate sur le curseur du client
local curseurs = {}
local function habillerCurseur(s)
	s:SetBackdrop(nil)
	local g = s:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(g, "minimal_sliderbar_left", true)
	g:SetPoint("LEFT", s, "LEFT")
	local d = s:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(d, "minimal_sliderbar_right", true)
	d:SetPoint("RIGHT", s, "RIGHT")
	local m = s:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(m, "_minimal_sliderbar_middle", true)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("TOPRIGHT", d, "TOPLEFT")
	s:SetThumbTexture(G.atlas["minimal_sliderbar_button"][1])
	local bouton = s:GetThumbTexture()
	G.PoserAtlas(bouton, "minimal_sliderbar_button")
	bouton:SetWidth(16)
	bouton:SetHeight(15)
	reposerPolices(s)
	curseurs[#curseurs + 1] = s
end

-- le bouton a 0,7 quand le curseur est desactive (MinimalSliderWithSteppers :
-- ConfigureSlider) ; le client desactive ses curseurs par une fonction qu'il
-- garde sur chacun : on le lit pendant que les fenetres sont ouvertes
local veille = CreateFrame("Frame")
veille.t = 0
veille:SetScript("OnUpdate", function(self, ecoule)
	self.t = self.t + (ecoule or 0)
	if self.t < 0.1 then
		return
	end
	self.t = 0
	if not (VideoOptionsFrame:IsShown() or AudioOptionsFrame:IsShown()) then
		return
	end
	for _, s in ipairs(curseurs) do
		local actif = not s.IsEnabled or vrai(s:IsEnabled())
		s:GetThumbTexture():SetAlpha(actif and 1 or 0.7)
	end
end)

-- tout un panneau : ses textes, puis chaque commande selon son gabarit
local function habillerPanneau(panneau)
	reposerPolices(panneau)
	for _, c in ipairs({ panneau:GetChildren() }) do
		local nom = c:GetName()
		local genre = c:GetObjectType()
		if genre == "CheckButton" then
			habillerCase(c)
		elseif genre == "Slider" then
			habillerCurseur(c)
		elseif nom and _G[nom .. "Button"] and _G[nom .. "Middle"] then
			G.HabillerMenuDeroulant(c, 2)
			reposerPolices(c)
		elseif (nom and _G[nom .. "Title"]) or (c.GetBackdrop and c:GetBackdrop()) then
			habillerBoite(c)
		else
			reposerPolices(c)
		end
	end
end

-- ------------------------------------------------------------ le menu Options

local POLICES = { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" }

local fond = OptionsSelectFrameBackground
fond:SetBackdrop(nil)
G.CadreDialogue(fond)
OptionsSelectFrameBackgroundHeader:SetAlpha(0)
OptionsSelectFrameBackgroundHeaderText:SetAlpha(0)
G.EnTeteDialogue(fond, OPTIONS, "GlueFontNormal")
local video = OptionsSelectFrameBackgroundContainerVideoOptionsButton
local son = OptionsSelectFrameBackgroundContainerAudioOptionsButton
local reset = OptionsSelectResetSettingsButton
local fermer = OptionsSelectFrameBackgroundOkayButton
for _, b in ipairs({ video, son }) do
	b:SetWidth(196)
	b:SetHeight(32)
	G.BoutonTroisTranches(b, "128-RedButton", POLICES)
end
for _, b in ipairs({ reset, fermer }) do
	b:SetHeight(27)
	G.BoutonTroisTranches(b, "128-RedButton", { "GlueFontNormalSmall", "GlueFontHighlightSmall", "GlueFontDisableSmall" })
end
reset:SetWidth(196)
fermer:SetWidth(112)
video:ClearAllPoints()
video:SetPoint("TOP", OptionsSelectFrameBackgroundContainer, "TOP", 0, -16)
son:ClearAllPoints()
son:SetPoint("TOP", video, "BOTTOM", 0, -3)
reset:ClearAllPoints()
reset:SetPoint("BOTTOMLEFT", fond, "BOTTOMLEFT", 20, 12)
fermer:ClearAllPoints()
fermer:SetPoint("BOTTOMRIGHT", fond, "BOTTOMRIGHT", -15, 12)

-- ------------------------------------------------------------ les categories

-- SettingsCategoryListButtonMixin:OnButtonStateChanged, apres le client
-- (OptionsCategoryFrame_Update et OptionsListButton_OnClick reposent ses
-- polices et sa selection)
local function peindreCategories(liste)
	for _, b in ipairs(liste.buttons) do
		local el = b.element
		local choisi = el ~= nil and liste.selection == el
		G.Montrer(b.foreverActif, choisi)
		G.Montrer(b.foreverSurvol, not choisi and b.foreverDessus)
		local police
		if choisi or (el and el.parent) then
			police = G.Police("GameFontHighlight")
		else
			police = G.Police("GameFontNormal")
		end
		b:SetNormalFontObject(police)
		b:SetHighlightFontObject(police)
	end
end

local function habillerCategories(liste)
	liste.foreverCategories = true
	local nom = liste:GetName()
	for _, suffixe in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right", "Top", "Bottom" }) do
		local t = _G[nom .. suffixe]
		if t then
			t:SetAlpha(0)
		end
	end
	for _, b in ipairs(liste.buttons) do
		local lueur = b:GetHighlightTexture()
		if lueur then
			lueur:SetTexture(nil)
			lueur:SetAlpha(0)
		end
		b.foreverActif = b:CreateTexture(nil, "BACKGROUND")
		G.PoserAtlas(b.foreverActif, "options_list_active", true)
		b.foreverActif:SetPoint("CENTER", b, "CENTER")
		b.foreverActif:Hide()
		b.foreverSurvol = b:CreateTexture(nil, "BACKGROUND")
		G.PoserAtlas(b.foreverSurvol, "options_list_hover", true)
		b.foreverSurvol:SetPoint("CENTER", b, "CENTER")
		b.foreverSurvol:Hide()
		G.Accrocher(b, "OnEnter", function(self)
			self.foreverDessus = true
			peindreCategories(liste)
		end)
		G.Accrocher(b, "OnLeave", function(self)
			self.foreverDessus = false
			peindreCategories(liste)
		end)
	end
	peindreCategories(liste)
end

G.AccrocherFonction("OptionsCategoryFrame_Update", function(liste)
	if liste and liste.foreverCategories then
		peindreCategories(liste)
	end
end)
G.AccrocherFonction("OptionsListButton_OnClick", function(b)
	local liste = b and b:GetParent()
	if liste and liste.foreverCategories then
		peindreCategories(liste)
	end
end)

-- ------------------------------------------------------------ les fenetres

local function habillerFenetre(f, boutonsDroite, defaut)
	local nom = f:GetName()
	f:SetBackdrop(nil)
	_G[nom .. "Header"]:SetAlpha(0)
	local titre = _G[nom .. "HeaderText"]
	titre:SetAlpha(0)
	-- la fenetre de camelot, au niveau de la fenetre du client : ses cadres
	-- fils (liste, panneaux, boutons) passent devant
	local fen = CreateFrame("Frame", nil, f)
	fen:SetFrameLevel(f:GetFrameLevel())
	fen:SetAllPoints(f)
	local habit = G.Fenetre(fen, titre:GetText(), true)
	habit.stries:Hide()
	-- la croix : ce que fait Cancel
	local croix = CreateFrame("Button", nom .. "ForeverUICloseButton", f)
	croix:SetFrameLevel(f:GetFrameLevel() + 20)
	G.CroixFenetre(croix, f)
	croix:SetScript("OnClick", function()
		boutonsDroite[#boutonsDroite == 3 and 2 or 1]:Click()
	end)
	-- le cadre des panneaux : un encart ; la liste des categories
	local conteneur = _G[nom .. "PanelContainer"]
	conteneur:SetBackdrop(nil)
	G.Encart(fen, conteneur, true)
	local categories = _G[nom .. "CategoryFrame"]
	habillerCategories(categories)
	-- OptionsFrame_OnShow redessine la liste par categoryFrame:update(), une
	-- reference prise au chargement : l'accroche sur la fonction ne la voit
	-- pas ; on repasse apres l'ouverture de la fenetre
	G.Accrocher(f, "OnShow", function()
		peindreCategories(categories)
	end)
	-- les boutons : UIPanelButtonTemplate 96 x 22
	local precedent
	for _, b in ipairs(boutonsDroite) do
		b:SetWidth(96)
		b:SetHeight(22)
		G.BoutonPanneau(b)
		b:ClearAllPoints()
		if precedent then
			b:SetPoint("RIGHT", precedent, "LEFT", -2, 0)
		else
			b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
		end
		precedent = b
	end
	defaut:SetWidth(96)
	defaut:SetHeight(22)
	G.BoutonPanneau(defaut)
	defaut:ClearAllPoints()
	defaut:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
	return habit
end

habillerFenetre(VideoOptionsFrame, { VideoOptionsFrameApply, VideoOptionsFrameCancel, VideoOptionsFrameOkay },
	VideoOptionsFrameDefault)
habillerFenetre(AudioOptionsFrame, { AudioOptionsFrameCancel, AudioOptionsFrameOkay }, AudioOptionsFrameDefault)

for _, p in ipairs({ VideoOptionsResolutionPanel, VideoOptionsEffectsPanel, VideoOptionsStereoPanel,
		AudioOptionsSoundPanel }) do
	habillerPanneau(p)
end
