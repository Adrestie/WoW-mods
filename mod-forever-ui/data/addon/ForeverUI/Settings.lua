-- ForeverUI : les reglages du jeu -- les fenetres Video (VideoOptionsFrame),
-- Son et voix (AudioOptionsFrame) et Interface (InterfaceOptionsFrame), a la
-- DA de camelot (demande de l'utilisateur, 2026-09-28 : « fait le menu et
-- reglages », etape 1).
--
-- CHOIX : « 3.3.5 rhabillee », celui que l'utilisateur a pris le 28/09 pour
-- les options des ecrans d'accueil, VALIDEES (ForeverUIGlueOptions.lua).
-- Camelot n'a pas ces trois fenetres (il ouvre SettingsPanel, reglages
-- regroupes) : on garde les ecrans du client -- places, tailles, logique,
-- reglages, CVars, boutons -- et on pose l'art de camelot apres lui, avec
-- les memes elements et les memes nombres qu'a l'accueil.
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (FrameXML de 3.3.5, par la chaine
-- d'archives) :
--   OptionsFrameTemplate (OptionsFrameTemplates.xml) 648 x 520 : <Backdrop>
--     UI-DialogBox, en-tete UI-DialogBox-Header et $parentHeaderText ;
--     $parentCategoryFrame (OptionsFrameListTemplate, 175 x 429 a (22, -40))
--     et $parentPanelContainer (bord d'infobulle gris 0,6) ; Video : Apply,
--     Cancel, Okay a BOTTOMRIGHT (-16, 16), Defaults (gris) a BOTTOMLEFT ;
--     Son : Cancel, Okay, Defaults.
--   InterfaceOptionsFrame (InterfaceOptionsFrame.xml) : la meme fenetre, deux
--     listes ($parentCategories, $parentAddOns) et deux onglets
--     (OptionsFrameTabButtonTemplate, GAME et ADDONS) au-dessus des listes ;
--     Cancel, Okay, Defaults.
--   OptionsFrameListTemplate : bord en huit textures (UI-Tooltip-Border),
--     deux entretoises UI-OptionsFrame-Spacer, un defilement a fausse barre
--     ($parentList, UIPanelScrollBarTemplate) montre quand la liste deborde,
--     les lignes OptionsListButtonTemplate (175 x 18, surbrillance
--     UI-QuestLogTitleHighlight, bouton de depliage $parentToggle 14 x 14 a
--     TOPRIGHT (-6, -1), UI-PlusButton / UI-MinusButton).
--     OptionsList_DisplayButton pose les polices a chaque passage :
--     GameFontNormal / Highlight, GameFontHighlightSmall en sous-categorie.
--   OptionsPanelTemplates.xml : cases OptionsBaseCheckButtonTemplate (26 x
--     26, UI-CheckBox-*), curseurs OptionsSliderTemplate (144 x 17, <Backdrop>
--     UI-SliderBar), cadres de groupe OptionsBoxTemplate (bord d'infobulle
--     gris 0,4) ; menus deroulants UIDropDownMenuTemplate (cadre
--     CharacterCreate-LabelFrame, comme a l'accueil).
--   Echap : ToggleGameMenu clique Cancel ; UIPanelWindows les tient au
--     centre.
--
-- RELEVE -- CAMELOT : les nombres sont ceux de l'accueil (relevee des
-- gabarits de reglages du 28/09) :
--   SettingsFrameTemplate : cadre de metal ButtonFrameTemplateNoPortrait,
--     titre GameFontNormal a -5 ; croix UIPanelCloseButton a (-2, 1) ;
--     boutons UIPanelButtonTemplate 96 x 22 a BOTTOMRIGHT (-16, 16), 2 entre
--     eux (ApplyButton).
--   SettingsCategoryListButtonTemplate : choisie Options_List_Active a sa
--     taille, centree, GameFontHighlight ; survolee Options_List_Hover ;
--     sinon GameFontNormal (sous-categorie GameFontHighlight) ; depliage
--     common-button-dropdown-open / -closed (+ -pressed), lueur
--     UI-PlusButton-Hilight ; liste sans cadre, barre MinimalScrollBar.
--   MinimalTabTemplate (onglets Game / AddOns) : Options_Tab_Left / Middle /
--     Right, choisi Options_Tab_Active_* ; largeur = texte + 40 ; texte
--     BOTTOM (0, 4), choisi (0, 6), GameFontNormalSmall, GameFontHighlight-
--     Small au survol et choisi ; 5 entre deux onglets.
--   SettingsCheckboxTemplate (checkbox-minimal, checkmark-minimal), curseur
--     MinimalSliderTemplate, menu WowStyle2DropdownTemplate : voir plus bas.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   Comme a l'accueil (ecarts deja valides) : fond noir translucide ; le
--   cadre des panneaux prend le cadre interieur de camelot (Options_
--   InnerFrame, voir plus bas : l'Interface le 28/09, puis Video et Son a
--   la demande, au lieu de l'encart de l'accueil) ; pas de stries ; cases et
--   curseurs a la taille du client ; poignee du curseur 16 x 15, art affine ;
--   menus sans fleches de pas ; cadres de groupe au bord d'infobulle gris ;
--   textes des menus en taille 10.
--   ECART propre au jeu : la croix FERME la fenetre (HideUIPanel), la ou
--   celle de l'accueil cliquait Cancel. Cliquer Cancel depuis le code d'un
--   addon ferait jouer les annulations du client (BlizzardOptionsPanel_
--   Cancel, qui reecrivent CVars et variables d'interface) hors du chemin
--   securise, et souillerait ces variables pour tout le client (meme cas que
--   StaticPopupDialogs, 26/09). Une valeur changee et ni validee ni annulee
--   n'est pas appliquee ; le client la relit a la prochaine ouverture.
--   Le bouton de depliage garde la place et la taille du client (14 x 14 a
--   TOPRIGHT), avec l'art de camelot.
--   Les panneaux des autres addons (onglet AddOns) gardent leurs commandes :
--   seuls ceux du client sont rhabilles ; la fenetre, la liste et les
--   onglets le sont pour tous.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits
local vrai = Gb.Vrai

local R = {}
ForeverUI.Reglages = R

-- les nombres, en tables : Lua 5.1 refuse plus de 60 valeurs exterieures
-- dans une fonction
local N = {
	boite = { 0.4, 0.4, 0.4 },          -- OptionsBoxTemplate : son bord
	poignee = { 16, 15 },               -- ECART : 20 x 19 chez camelot
	poigneeGrisee = 0.7,                -- MinimalSliderWithSteppers
	bouton = { 96, 22 },
	boutonBord = 16,
	boutonEcart = 2,
	menu = { gauche = 16, haut = -19, droite = -17, hauteur = 25, fond = 7, texte = 13, flecheY = -5 },
	onglet = { hauteur = 37, marge = 40, texte = 4, texteChoisi = 6, ecart = 5 },
	veille = 0.1,
}

-- ------------------------------------------------------------ les commandes

local function poserEtat(b, set, get, nom, mode)
	b[set](b, Gb.Art(nom)[1])
	local t = b[get](b)
	Gb.Poser(t, nom)
	t:ClearAllPoints()
	t:SetAllPoints(b)
	if mode then
		t:SetBlendMode(mode)
	end
	return t
end

-- SettingsCheckboxTemplate, a la taille de la case du client (26) : pas de
-- lueur au survol
function R.Case(c)
	if c.foreverCase then return end
	c.foreverCase = true
	poserEtat(c, "SetNormalTexture", "GetNormalTexture", "checkbox-minimal")
	poserEtat(c, "SetPushedTexture", "GetPushedTexture", "checkbox-minimal")
	local lueur = c:GetHighlightTexture()
	if lueur then
		lueur:SetTexture(nil)
		lueur:SetAlpha(0)
	end
	poserEtat(c, "SetCheckedTexture", "GetCheckedTexture", "checkmark-minimal")
	poserEtat(c, "SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "checkmark-minimal-disabled")
end

-- OptionsBoxTemplate : le bord des infobulles de camelot au gris du client
-- (0,4), sans fond (le client n'en pose pas)
function R.Boite(f)
	if f.foreverNeuf then return end
	local p = ForeverUI.Tooltips.Habiller(f)
	for nom, t in pairs(p) do
		if nom == "Center" then
			t:SetAlpha(0)
		else
			t:SetVertexColor(N.boite[1], N.boite[2], N.boite[3], 1)
		end
	end
end

-- MinimalSliderTemplate sur le curseur du client, a sa taille (17 de haut,
-- celle de la glissiere) : Left / Right a leur taille, Middle entre eux,
-- bouton Minimal_SliderBar_Button (ECART : 16 x 15)
R.curseurs = {}
function R.Curseur(s)
	if s.foreverCurseur then return end
	s.foreverCurseur = true
	s:SetBackdrop(nil)
	local g = s:CreateTexture(nil, "ARTWORK")
	Gb.Poser(g, "minimal_sliderbar_left", true)
	g:SetPoint("LEFT", s, "LEFT")
	local d = s:CreateTexture(nil, "ARTWORK")
	Gb.Poser(d, "minimal_sliderbar_right", true)
	d:SetPoint("RIGHT", s, "RIGHT")
	local m = s:CreateTexture(nil, "ARTWORK")
	Gb.Poser(m, "_minimal_sliderbar_middle", true)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("TOPRIGHT", d, "TOPLEFT")
	s:SetThumbTexture(Gb.Art("minimal_sliderbar_button")[1])
	local bouton = s:GetThumbTexture()
	Gb.Poser(bouton, "minimal_sliderbar_button")
	bouton:SetWidth(N.poignee[1])
	bouton:SetHeight(N.poignee[2])
	R.curseurs[#R.curseurs + 1] = s
end

-- ------------------------------------------------------------ le menu deroulant

-- WowStyle2DropdownTemplate (celui de SettingsDropdownControl), dans la
-- partie visible du cadre de 3.3.5 (CharacterCreate-LabelFrame : opaque de
-- 16 a 111 sur 128 en largeur, de 19 a 45 sur 64 en hauteur) : fond
-- common-dropdown-c-button de (-7, 7) a (7, -7), etats hover-1 / pressed-1 /
-- pressedhover-1 / open / disabled ; fleche common-dropdown-c-button-hover-
-- arrow a BOTTOM (0, -5) au survol seulement, desaturee si desactive ; texte
-- centre de 13 a -13, 20 de haut, decale de (2, -1) enfonce ; ECART : texte
-- GameFontNormalSmall (taille 10) au lieu de GameFontNormal. La liste :
-- DropDown.lua, style 2.
local function ouvert(dd)
	return DropDownList1 and DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == dd
end

local function peindreMenu(dd)
	local b = dd.foreverBouton
	local actif = vrai(b:IsEnabled())
	local n = "common-dropdown-c-button"
	if not actif then
		n = n .. "-disabled"
	elseif b.foreverBas and b.foreverDessus then
		n = n .. "-pressedhover-1"
	elseif b.foreverDessus then
		n = n .. "-hover-1"
	elseif b.foreverBas then
		n = n .. "-pressed-1"
	elseif ouvert(dd) then
		n = n .. "-open"
	end
	dd.foreverFond:Poser(n)
	Gb.Montrer(dd.foreverFleche, b.foreverDessus)
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
	if b.foreverBas and actif then
		dx, dy = 2, -1
	end
	texte:ClearAllPoints()
	texte:SetPoint("LEFT", b, "LEFT", N.menu.texte + dx, dy)
	texte:SetPoint("RIGHT", b, "RIGHT", -N.menu.texte + dx, dy)
end

function R.Menu(dd)
	if dd.foreverBouton then return end
	dd.foreverStyle = 2
	local nom = dd:GetName()
	local gauche, droite = _G[nom .. "Left"], _G[nom .. "Right"]
	for _, suffixe in ipairs({ "Left", "Middle", "Right" }) do
		_G[nom .. suffixe]:SetAlpha(0)
	end
	local b = _G[nom .. "Button"]
	dd.foreverBouton = b
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", gauche, "TOPLEFT", N.menu.gauche, N.menu.haut)
	b:SetPoint("RIGHT", droite, "RIGHT", N.menu.droite, 0)
	b:SetHeight(N.menu.hauteur)
	Gb.EffacerArt(b)
	-- le fond en region du menu, sous son texte ; la case (cadre fils) ne
	-- porte que la fleche
	local texte = _G[nom .. "Text"]
	texte:SetHeight(20)
	texte:SetFontObject(GameFontNormalSmall)
	texte:SetJustifyH("CENTER")
	dd.foreverFond = Gb.AtlasEtire(dd, "common-dropdown-c-button", "BACKGROUND")
	dd.foreverFond.rect:SetPoint("TOPLEFT", b, "TOPLEFT", -N.menu.fond, N.menu.fond)
	dd.foreverFond.rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", N.menu.fond, -N.menu.fond)
	dd.foreverFleche = b:CreateTexture(nil, "OVERLAY")
	Gb.Poser(dd.foreverFleche, "common-dropdown-c-button-hover-arrow", true)
	dd.foreverFleche:SetPoint("BOTTOM", b, "BOTTOM", 0, N.menu.flecheY)
	dd.foreverPeindre = function() peindreMenu(dd) end
	b:HookScript("OnEnter", function(self)
		self.foreverDessus = true
		peindreMenu(dd)
		-- le survol du menu (son infobulle) reste celui du client : la case
		-- le relaie
		local surEntree = dd:GetScript("OnEnter")
		if surEntree then surEntree(dd) end
	end)
	b:HookScript("OnLeave", function(self)
		self.foreverDessus = false
		peindreMenu(dd)
		local surSortie = dd:GetScript("OnLeave")
		if surSortie then surSortie(dd) end
	end)
	b:HookScript("OnMouseDown", function(self) self.foreverBas = true; peindreMenu(dd) end)
	b:HookScript("OnMouseUp", function(self) self.foreverBas = false; peindreMenu(dd) end)
	b:HookScript("OnDisable", function() peindreMenu(dd) end)
	b:HookScript("OnEnable", function() peindreMenu(dd) end)
	dd:HookScript("OnShow", function() peindreMenu(dd) end)
	peindreMenu(dd)
end

-- le texte du menu est repose par le client (UIDropDownMenu_SetText,
-- _EnableDropDown, _DisableDropDown) : on repasse derriere lui
for _, nom in ipairs({ "UIDropDownMenu_EnableDropDown", "UIDropDownMenu_DisableDropDown" }) do
	if type(_G[nom]) == "function" then
		hooksecurefunc(nom, function(dd)
			if dd and dd.foreverPeindre then dd.foreverPeindre() end
		end)
	end
end

-- le texte du bouton, converti comme les lignes (Gb.TexteUtf8)
hooksecurefunc("UIDropDownMenu_SetText", function(dd, texte)
	local fs = dd and dd.foreverBouton and _G[dd:GetName() .. "Text"]
	local propre = Gb.TexteUtf8(texte)
	if fs and propre ~= texte then
		fs:SetText(propre)
	end
end)

-- ------------------------------------------------------------ les panneaux

-- tout un panneau : chaque commande selon son gabarit, et les cadres qui en
-- portent d'autres (cadres de groupe, sous-cadres)
function R.Panneau(cadre)
	for _, c in ipairs({ cadre:GetChildren() }) do
		local nom = c:GetName()
		local genre = c:GetObjectType()
		if genre == "CheckButton" then
			R.Case(c)
		elseif genre == "Slider" then
			R.Curseur(c)
		elseif nom and _G[nom .. "Button"] and _G[nom .. "Middle"] and _G[nom .. "Left"] then
			R.Menu(c)
		else
			local fond = c.GetBackdrop and c:GetBackdrop()
			if fond and type(fond.edgeFile) == "string"
				and string.find(string.lower(fond.edgeFile), "ui%-tooltip%-border") then
				R.Boite(c)
			end
			if genre == "Frame" then
				R.Panneau(c)
			end
		end
	end
end

-- le bouton a 0,7 quand le curseur est desactive (MinimalSliderWithSteppers :
-- ConfigureSlider) ; le client desactive ses curseurs par une fonction qu'il
-- garde sur chacun : on le lit pendant que les fenetres sont ouvertes
local veille = CreateFrame("Frame")
veille.t = 0
veille:SetScript("OnUpdate", function(self, ecoule)
	self.t = self.t + (ecoule or 0)
	if self.t < N.veille then
		return
	end
	self.t = 0
	local f1, f2, f3 = VideoOptionsFrame, AudioOptionsFrame, InterfaceOptionsFrame
	if not ((f1 and f1:IsShown()) or (f2 and f2:IsShown()) or (f3 and f3:IsShown())) then
		return
	end
	for _, s in ipairs(R.curseurs) do
		local actif = not s.IsEnabled or vrai(s:IsEnabled())
		s:GetThumbTexture():SetAlpha(actif and 1 or N.poigneeGrisee)
	end
end)
R.veille = veille

-- ------------------------------------------------------------ les categories

-- SettingsCategoryListButtonMixin:UpdateStateInternal, apres le client
-- (OptionsList_DisplayButton reposent polices et depliage ; OptionsList_
-- SelectButton / ClearSelection la selection)
local function peindreLigne(liste, b)
	local el = b.element
	local choisi = el ~= nil and liste.selection == el
	Gb.Montrer(b.foreverActif, choisi)
	Gb.Montrer(b.foreverSurvol, not choisi and b.foreverDessus)
	local police
	if choisi or (el and el.parent) then
		police = GameFontHighlight
	else
		police = GameFontNormal
	end
	b:SetNormalFontObject(police)
	b:SetHighlightFontObject(police)
	-- le depliage : common-button-dropdown-open / -closed
	local t = b.toggle
	if t and el and el.hasChildren then
		local etat = el.collapsed and "closed" or "open"
		t:SetNormalTexture(ForeverUI.AtlasEntry("common-button-dropdown-" .. etat)[1])
		ForeverUI.SetAtlas(t:GetNormalTexture(), "common-button-dropdown-" .. etat, true)
		t:SetPushedTexture(ForeverUI.AtlasEntry("common-button-dropdown-" .. etat .. "pressed")[1])
		ForeverUI.SetAtlas(t:GetPushedTexture(), "common-button-dropdown-" .. etat .. "pressed", true)
	end
end

function R.PeindreListe(liste)
	for _, b in ipairs(liste.buttons or {}) do
		peindreLigne(liste, b)
	end
end

-- LA BARRE DE LA LISTE : l'art de MinimalScrollBar (les morceaux de
-- ScrollBar.lua : fleches minimal-scrollbar-arrow-top / -bottom 17 x 11 et
-- leur survol, glissiere track-top / middle / bottom et curseur thumb-top,
-- middle, thumb-top retourne, 8 de large) POSE SUR la fausse barre du
-- client. Celle-ci reste a sa place, invisible (alpha 0) mais a la souris :
-- c'est elle qu'on clique, qu'on glisse et qui tourne a la molette, par le
-- chemin securise du client -- faire defiler la liste depuis le code d'un
-- addon rejouerait OptionsCategoryFrame_Update hors de ce chemin et
-- souillerait les lignes (button.element) que lit ensuite le clic. L'art
-- suit : fleches sur les siennes, glissiere sur la sienne, curseur ancre
-- sur le sien. ECART : le curseur a la taille de celui du client (fixe), et
-- non a la part visible de la liste.
local BARRE = {
	largeur = 8, bout = 8,
	flecheHaut = "minimal-scrollbar-arrow-top-c60", flecheHautSurvol = "minimal-scrollbar-arrow-top-over-c60",
	flecheBas = "minimal-scrollbar-arrow-bottom-c60", flecheBasSurvol = "minimal-scrollbar-arrow-bottom-over-c60",
	pisteHaut = "minimal-scrollbar-track-top-c60", pisteMilieu = "!minimal-scrollbar-track-middle-c60",
	pisteBas = "minimal-scrollbar-track-bottom-c60",
	curseurBout = "minimal-scrollbar-thumb-top-c60", curseurMilieu = "minimal-scrollbar-thumb-middle-c60",
}

local function fleche(v, bouton, atlas, survol)
	-- a la taille de l'element (17 x 11) : une texture sans taille prendrait
	-- celle de sa feuille
	local t = v:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(t, atlas)
	t:SetPoint("CENTER", bouton, "CENTER", 0, 0)
	bouton:HookScript("OnEnter", function() ForeverUI.SetAtlas(t, survol, true) end)
	bouton:HookScript("OnLeave", function() ForeverUI.SetAtlas(t, atlas, true) end)
	return t
end

function R.Barre(liste)
	local defile = liste.scrollFrame
	local sb = defile and _G[defile:GetName() .. "ScrollBar"]
	if not sb then return end
	defile:SetBackdrop(nil)
	sb:SetAlpha(0)
	local v = CreateFrame("Frame", nil, defile)
	v:SetFrameLevel(sb:GetFrameLevel() + 5)
	v:SetAllPoints(defile)
	local b = BARRE
	v.haut = fleche(v, _G[sb:GetName() .. "ScrollUpButton"], b.flecheHaut, b.flecheHautSurvol)
	v.bas = fleche(v, _G[sb:GetName() .. "ScrollDownButton"], b.flecheBas, b.flecheBasSurvol)
	local function tranche(atlas, couche)
		local t = v:CreateTexture(nil, couche)
		ForeverUI.SetAtlas(t, atlas)
		t:SetWidth(b.largeur)
		return t
	end
	local ph = tranche(b.pisteHaut, "BACKGROUND")
	ph:SetPoint("TOP", sb, "TOP", 0, 0)
	local pb = tranche(b.pisteBas, "BACKGROUND")
	pb:SetPoint("BOTTOM", sb, "BOTTOM", 0, 0)
	local pm = tranche(b.pisteMilieu, "BACKGROUND")
	pm:SetPoint("TOP", ph, "BOTTOM", 0, 0)
	pm:SetPoint("BOTTOM", pb, "TOP", 0, 0)
	local pouce = sb:GetThumbTexture()
	local ch = tranche(b.curseurBout, "ARTWORK")
	ch:SetHeight(b.bout)
	ch:SetPoint("TOP", pouce, "TOP", 0, 0)
	-- le meme morceau, retourne, pour le bas
	local cb = tranche(b.curseurBout, "ARTWORK")
	local e = ForeverUI.AtlasEntry(b.curseurBout)
	cb:SetTexCoord(e[2], e[3], e[5], e[4])
	cb:SetHeight(b.bout)
	cb:SetPoint("BOTTOM", pouce, "BOTTOM", 0, 0)
	local cm = tranche(b.curseurMilieu, "ARTWORK")
	cm:SetPoint("TOP", ch, "BOTTOM", 0, 0)
	cm:SetPoint("BOTTOM", cb, "TOP", 0, 0)
	v.curseur = { ch, cm, cb }
	liste.foreverBarre = v
end

function R.Liste(liste)
	if liste.foreverCategories then return end
	liste.foreverCategories = true
	local nom = liste:GetName()
	-- sans cadre : les huit textures du bord et les deux entretoises
	for _, suffixe in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right", "Top", "Bottom" }) do
		local t = _G[nom .. suffixe]
		if t then
			t:SetAlpha(0)
		end
	end
	for _, b in ipairs(liste.buttons or {}) do
		local lueur = b:GetHighlightTexture()
		if lueur then
			lueur:SetTexture(nil)
			lueur:SetAlpha(0)
		end
		b.foreverActif = b:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(b.foreverActif, "options_list_active")
		b.foreverActif:SetPoint("CENTER", b, "CENTER")
		b.foreverActif:Hide()
		b.foreverSurvol = b:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(b.foreverSurvol, "options_list_hover")
		b.foreverSurvol:SetPoint("CENTER", b, "CENTER")
		b.foreverSurvol:Hide()
		b:HookScript("OnEnter", function(self)
			self.foreverDessus = true
			peindreLigne(liste, self)
		end)
		b:HookScript("OnLeave", function(self)
			self.foreverDessus = false
			peindreLigne(liste, self)
		end)
	end
	R.Barre(liste)
	R.PeindreListe(liste)
end

local function apresListe(liste)
	if liste and liste.foreverCategories then
		R.PeindreListe(liste)
	end
end

hooksecurefunc("OptionsList_DisplayButton", function(b)
	local liste = b and b:GetParent()
	if liste and liste.foreverCategories then
		peindreLigne(liste, b)
	end
end)
hooksecurefunc("OptionsList_SelectButton", apresListe)
hooksecurefunc("OptionsList_ClearSelection", apresListe)
hooksecurefunc("OptionsCategoryFrame_Update", apresListe)
for _, nom in ipairs({ "InterfaceCategoryList_Update", "InterfaceAddOnsList_Update" }) do
	if type(_G[nom]) == "function" then
		hooksecurefunc(nom, function()
			apresListe(InterfaceOptionsFrameCategories)
			apresListe(InterfaceOptionsFrameAddOns)
		end)
	end
end

-- ------------------------------------------------------------ les onglets

-- MinimalTabTemplate sur un onglet du client (PanelTemplates : l'onglet
-- choisi est DESACTIVE)
local function peindreOnglet(o)
	local choisi = not vrai(o:IsEnabled())
	local suffixe = choisi and "active_" or ""
	for _, cote in ipairs({ "left", "middle", "right" }) do
		-- a la taille de l'element (useAtlasSize) : sans taille, une texture
		-- prend celle de sa feuille (1024 x 1024) -- vu en jeu le 28/09
		ForeverUI.SetAtlas(o.foreverArt[cote], "options_tab_" .. suffixe .. cote)
	end
	local texte = o:GetFontString()
	if texte then
		texte:ClearAllPoints()
		texte:SetPoint("BOTTOM", o, "BOTTOM", 0, choisi and N.onglet.texteChoisi or N.onglet.texte)
	end
	o:SetNormalFontObject((choisi or o.foreverDessus) and GameFontHighlightSmall or GameFontNormalSmall)
	o:SetWidth((texte and texte:GetStringWidth() or 0) + N.onglet.marge)
end

function R.Onglet(o)
	if o.foreverArt then return end
	local nom = o:GetName()
	for _, suffixe in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
		local t = _G[nom .. suffixe]
		if t then t:SetAlpha(0) end
	end
	local lueur = o:GetHighlightTexture()
	if lueur then
		lueur:SetTexture(nil)
		lueur:SetAlpha(0)
	end
	o:SetHeight(N.onglet.hauteur)
	local a = {}
	a.left = o:CreateTexture(nil, "BACKGROUND")
	a.left:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT")
	a.right = o:CreateTexture(nil, "BACKGROUND")
	a.right:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT")
	a.middle = o:CreateTexture(nil, "BACKGROUND")
	a.middle:SetPoint("TOPLEFT", a.left, "TOPRIGHT")
	a.middle:SetPoint("TOPRIGHT", a.right, "TOPLEFT")
	o.foreverArt = a
	o:SetDisabledFontObject(GameFontHighlightSmall)
	o:HookScript("OnEnter", function(self) self.foreverDessus = true; peindreOnglet(self) end)
	o:HookScript("OnLeave", function(self) self.foreverDessus = false; peindreOnglet(self) end)
	o:HookScript("OnShow", peindreOnglet)
	o:HookScript("OnEnable", peindreOnglet)
	o:HookScript("OnDisable", peindreOnglet)
	peindreOnglet(o)
end

-- ------------------------------------------------------------ le cadre interieur

-- Options_InnerFrame (camelot : SettingsPanel, couche OVERLAY, TOPLEFT
-- (17, -64), 886 x 618 sur la feuille optionsc60) : le cadre qui entoure la
-- liste des categories et les reglages -- un fond sombre presque
-- transparent, un filet brun, un degrade vers l'interieur (29 sur les
-- cotes, 82 en haut, 167 en bas) et le SEPARATEUR de la liste (colonnes 199
-- et 200). Chez camelot : liste a 18 (1 a l'interieur), separateur a
-- 17 + 199 (bord droit de la liste - 1), haut 12 au-dessus de la liste
-- (-64 / -76), bord droit a 17 de la fenetre, onglets POSES sur son haut.
-- Decoupe ici en 5 x 3 : bords et degrades a leur taille, separateur a sa
-- place, le reste etire.
local INTERIEUR = {
	cols = { 0, 29, 199, 201, 857, 886 },
	rangs = { 0, 82, 451, 618 },
	gauche = -1, haut = 12, bas = -4, droite = -17,
}

-- f : la fenetre ; liste : la liste des categories, sur laquelle le cadre
-- se cale. Rend le rectangle (un cadre sans image, pour les ancres).
function R.Interieur(hote, f, liste)
	local I = INTERIEUR
	local e = ForeverUI.AtlasEntry("options_innerframe")
	local rect = CreateFrame("Frame", nil, hote)
	rect:SetPoint("TOPLEFT", liste, "TOPLEFT", I.gauche, I.haut)
	rect:SetPoint("BOTTOMLEFT", liste, "BOTTOMLEFT", I.gauche, I.bas)
	rect:SetPoint("RIGHT", f, "RIGHT", I.droite, 0)
	local W, H = e[6], e[7]
	local du, dv = (e[3] - e[2]) / W, (e[5] - e[4]) / H
	-- le separateur a la place de camelot : largeur de la liste depuis le
	-- bord gauche du cadre
	local sep = liste:GetWidth() - I.gauche - 1
	local xs = { 0, I.cols[2], sep, sep + 2 }
	local pieces = {}
	for c = 1, 5 do
		for r = 1, 3 do
			local t = hote:CreateTexture(nil, "ARTWORK")
			t:SetTexture(e[1])
			t:SetTexCoord(e[2] + I.cols[c] * du, e[2] + I.cols[c + 1] * du,
				e[4] + I.rangs[r] * dv, e[4] + I.rangs[r + 1] * dv)
			if c == 5 then
				t:SetPoint("RIGHT", rect, "RIGHT", 0, 0)
				t:SetWidth(I.cols[6] - I.cols[5])
			elseif c == 4 then
				t:SetPoint("LEFT", rect, "LEFT", xs[4], 0)
				t:SetPoint("RIGHT", rect, "RIGHT", -(I.cols[6] - I.cols[5]), 0)
			else
				t:SetPoint("LEFT", rect, "LEFT", xs[c], 0)
				t:SetWidth(xs[c + 1] - xs[c])
			end
			if r == 1 then
				t:SetPoint("TOP", rect, "TOP", 0, 0)
				t:SetHeight(I.rangs[2])
			elseif r == 3 then
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, 0)
				t:SetHeight(I.rangs[4] - I.rangs[3])
			else
				t:SetPoint("TOP", rect, "TOP", 0, -I.rangs[2])
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, I.rangs[4] - I.rangs[3])
			end
			pieces[#pieces + 1] = t
		end
	end
	rect.pieces = pieces
	return rect
end

-- ------------------------------------------------------------ les fenetres

-- f : la fenetre du client ; boutonsDroite : de droite a gauche, dans
-- l'ordre du client ; defaut : le bouton Defaults ; listes : ses listes
function R.Fenetre(f, boutonsDroite, defaut, listes, interieur)
	local nom = f:GetName()
	f:SetBackdrop(nil)
	_G[nom .. "Header"]:SetAlpha(0)
	local titre = _G[nom .. "HeaderText"]
	titre:SetAlpha(0)
	-- la fenetre de camelot, au niveau de la fenetre du client : ses cadres
	-- fils (listes, panneaux, boutons) passent devant
	local fen = CreateFrame("Frame", nil, f)
	fen:SetFrameLevel(f:GetFrameLevel())
	fen:SetAllPoints(f)
	local habit = Gb.Fenetre(fen, titre:GetText())
	habit.stries:Hide()
	f.foreverHabit = habit
	-- la croix : elle ferme (voir l'ECART plus haut)
	local croix = CreateFrame("Button", nom .. "ForeverUICloseButton", f)
	croix:SetFrameLevel(f:GetFrameLevel() + 20)
	Gb.Croix(croix, f)
	croix:SetScript("OnClick", function()
		HideUIPanel(f)
	end)
	f.foreverCroix = croix
	-- le cadre des panneaux : un encart, ou le cadre interieur de camelot
	local conteneur = _G[nom .. "PanelContainer"]
	conteneur:SetBackdrop(nil)
	if interieur then
		f.foreverInterieur = R.Interieur(fen, f, listes[1])
	else
		Gb.Encart(fen, conteneur)
	end
	for _, liste in ipairs(listes) do
		R.Liste(liste)
	end
	-- OptionsFrame_OnShow redessine la liste par categoryFrame:update(), une
	-- reference prise au chargement : l'accroche sur la fonction ne la voit
	-- pas ; on repasse apres l'ouverture de la fenetre
	f:HookScript("OnShow", function()
		for _, liste in ipairs(listes) do
			R.PeindreListe(liste)
		end
	end)
	-- les boutons : UIPanelButtonTemplate 96 x 22
	local precedent
	for _, b in ipairs(boutonsDroite) do
		b:SetWidth(N.bouton[1])
		b:SetHeight(N.bouton[2])
		Gb.BoutonPanneau(b)
		b:ClearAllPoints()
		if precedent then
			b:SetPoint("RIGHT", precedent, "LEFT", -N.boutonEcart, 0)
		else
			b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -N.boutonBord, N.boutonBord)
		end
		precedent = b
	end
	defaut:SetWidth(N.bouton[1])
	defaut:SetHeight(N.bouton[2])
	Gb.BoutonPanneau(defaut)
	defaut:ClearAllPoints()
	defaut:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", N.boutonBord, N.boutonBord)
	return habit
end

-- ------------------------------------------------------------ la mise en place

local PANNEAUX = {
	"VideoOptionsResolutionPanel", "VideoOptionsEffectsPanel", "VideoOptionsStereoPanel",
	"AudioOptionsSoundPanel", "AudioOptionsVoicePanel",
	"InterfaceOptionsControlsPanel", "InterfaceOptionsCombatPanel", "InterfaceOptionsDisplayPanel",
	"InterfaceOptionsObjectivesPanel", "InterfaceOptionsSocialPanel", "InterfaceOptionsActionBarsPanel",
	"InterfaceOptionsNamesPanel", "InterfaceOptionsCombatTextPanel", "InterfaceOptionsStatusTextPanel",
	"InterfaceOptionsUnitFramePanel", "InterfaceOptionsBuffsPanel", "InterfaceOptionsBattlenetPanel",
	"InterfaceOptionsCameraPanel", "InterfaceOptionsMousePanel", "InterfaceOptionsFeaturesPanel",
	"InterfaceOptionsHelpPanel", "InterfaceOptionsLanguagesPanel",
}

if VideoOptionsFrame then
	R.Fenetre(VideoOptionsFrame, { VideoOptionsFrameApply, VideoOptionsFrameCancel, VideoOptionsFrameOkay },
		VideoOptionsFrameDefaults, { VideoOptionsFrameCategoryFrame }, true)
end
if AudioOptionsFrame then
	R.Fenetre(AudioOptionsFrame, { AudioOptionsFrameCancel, AudioOptionsFrameOkay },
		AudioOptionsFrameDefaults, { AudioOptionsFrameCategoryFrame }, true)
end
-- L'INTERFACE A LA DISPOSITION DE CAMELOT (retour du 28/09 : « les onglets
-- debordent dans le header de la fenetre », « l'encadre argente des options
-- n'est pas beau ») : en 3.3.5 les listes commencent a -40 et il n'y a que
-- 19 entre la barre de titre et elles, pour des onglets de 26. ECART
-- (geometrie de 3.3.5) : comme chez camelot, les listes a -76 et les
-- onglets (37) poses sur le haut du cadre interieur (-64), a 15 de son bord
-- gauche ; la fenetre grandit d'autant (36) pour garder la hauteur des
-- listes et l'ecart aux boutons du bas. Le cadre des reglages est le cadre
-- interieur de camelot (Options_InnerFrame) au lieu de l'encart.
local INTERFACE = { listesY = -76, grandit = 36, ongletX = 15 }

if InterfaceOptionsFrame then
	local f = InterfaceOptionsFrame
	f:SetHeight(f:GetHeight() + INTERFACE.grandit)
	for _, l in ipairs({ InterfaceOptionsFrameCategories, InterfaceOptionsFrameAddOns }) do
		local _, _, _, x = l:GetPoint(1)
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", f, "TOPLEFT", x or 22, INTERFACE.listesY)
	end
	R.Fenetre(f, { InterfaceOptionsFrameCancel, InterfaceOptionsFrameOkay },
		InterfaceOptionsFrameDefaults, { InterfaceOptionsFrameCategories, InterfaceOptionsFrameAddOns }, true)
	for _, s in ipairs({ "Tab1TabSpacer", "Tab2TabSpacer1", "Tab2TabSpacer2" }) do
		local t = _G["InterfaceOptionsFrame" .. s]
		if t then t:SetAlpha(0) end
	end
	R.Onglet(InterfaceOptionsFrameTab1)
	R.Onglet(InterfaceOptionsFrameTab2)
	InterfaceOptionsFrameTab1:ClearAllPoints()
	InterfaceOptionsFrameTab1:SetPoint("BOTTOMLEFT", f.foreverInterieur, "TOPLEFT", INTERFACE.ongletX, 0)
	InterfaceOptionsFrameTab2:ClearAllPoints()
	InterfaceOptionsFrameTab2:SetPoint("TOPLEFT", InterfaceOptionsFrameTab1, "TOPRIGHT", N.onglet.ecart, 0)
end
for _, nom in ipairs(PANNEAUX) do
	local p = _G[nom]
	if p then
		R.Panneau(p)
	end
end
