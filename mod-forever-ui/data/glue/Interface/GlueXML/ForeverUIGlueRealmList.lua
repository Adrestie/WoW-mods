-- ForeverUI -- la liste des royaumes, a la DA de camelot.
--
-- CHOIX (27/09) : camelot n'a pas de liste des royaumes (son .toc ne charge
-- RealmList que pour le jeu mainline ; camelot choisit une region par
-- cartes, SuperDistrict). On garde la liste du client 3.3.5 -- ses places,
-- ses tailles, sa logique -- dans une fenetre de camelot :
--   * ECART (27/09, a la demande : « il faut mieux habiller la fenetre ») :
--     la fenetre de camelot, ButtonFrameTemplate sans portrait -- celle de
--     sa liste des AddOns (G.Fenetre) : stries, cadre de metal, titre
--     SERVER_SELECTION dans la barre ; la liste dans un encart
--     (InsetFrameTemplate, G.Encart) sous les en-tetes de colonnes ;
--   * ECART (28/09, a la demande : « le fond doit etre fonce transparent ») :
--     ni pierre ni marbre, le noir a 0,8 de DialogBorderTranslucentTemplate
--     sur toute la fenetre, encart compris ;
--     Annuler / OK dans la barre du bas (SharedButtonSmallTemplate, 22 de
--     haut, a (-4, 4)) ; la petite croix de fenetre (UIPanelCloseButton,
--     24 x 24 a (-2, 1)). Ces trois-la quittent donc leurs places de 3.3.5 ;
--   * les en-tetes de colonnes (WhoFrame-ColumnTabs), la fleche de tri
--     (UI-SortArrow) et la barre de la ligne choisie
--     (UI-QuestLogTitleHighlight) restent : la liste moderne emploie les
--     memes fichiers, identiques dans le client de camelot (ecart moyen de
--     0,1 a 1,7 sur 255, bruit de compression) ;
--   * onglets (RealmListTabButtonTemplate) : uiframe-tab-left / -right /
--     _center a leur taille, LEFT a -3 et RIGHT a +7 ; l'onglet choisi
--     uiframe-activetab-*, LEFT a -1 et RIGHT a +8 ; survol : l'art de
--     l'onglet en ADD a 0,4 ;
--   * barre de defilement : MinimalScrollBar, a la place de celle de la
--     liste des AddOns de camelot (addonlist.xml : a 4 a droite d'une liste
--     qui finit a 34 du bord, soit son bord droit a 22 du bord de la
--     fenetre, 16 dans l'encart) ; en haut a 3 sous l'encart, en bas a 4
--     au-dessus du bas de la liste du client ;
--   * polices de camelot (GlueFont*, Realm*) a la place de celles du client.
-- Le client garde la main sur tout : ses boutons, son decalage, son tri ; on
-- ne fait que reposer l'art et les polices apres lui (RealmListUpdate,
-- RealmList_UpdateTabs).

local G = ForeverUIGlue

local fond = RealmListBackground
local LIGNES = 18                -- MAX_REALMS_DISPLAYED du client
local HAUTEUR_LIGNE = 16         -- REALM_BUTTON_HEIGHT du client

-- une police de camelot pour une police du client, si camelot la connait
local function policeCamelot(objet)
	local nom = objet and objet.GetName and objet:GetName()
	if not nom or string.find(nom, "^ForeverUIGlue_") then
		return nil
	end
	return _G["ForeverUIGlue_" .. nom]
end

-- ------------------------------------------------------------ la fenetre

-- l'art du client : le cadre HelpFrame-*, l'en-tete et son titre
for _, r in ipairs({ fond:GetRegions() }) do
	local texture = r:GetObjectType() == "Texture" and string.lower(r:GetTexture() or "")
	if (texture and string.find(texture, "helpframe", 1, true))
		or (r:GetObjectType() == "FontString" and r:GetText() == SERVER_SELECTION) then
		r:SetAlpha(0)
		r:Hide()
	end
end
RealmListHeader:SetAlpha(0)
RealmListHeader:Hide()

-- La fenetre couvre la liste du client : sa largeur tient la barre de la
-- ligne choisie (jusqu'a 22 + 587 du bord, GlueScrollFrame_Update) dans
-- l'encart (6 du bord droit). Elle est au niveau du fond du client : ses
-- boutons, sa liste, ses onglets passent devant.
local fenetre = CreateFrame("Frame", "ForeverUIRealmListWindow", RealmList)
fenetre:SetFrameLevel(fond:GetFrameLevel())
fenetre:SetPoint("TOPLEFT", fond, "TOPLEFT", 0, 0)
fenetre:SetPoint("BOTTOMRIGHT", fond, "BOTTOMRIGHT", -22, 0)
G.Fenetre(fenetre, SERVER_SELECTION, true)

-- l'encart : a 9 du bord gauche (sans portrait), 6 du droit, 26 du bas ; en
-- haut, sous les en-tetes de colonnes (leur bas est a 50 du haut)
local encart = CreateFrame("Frame", nil, fenetre)
encart:SetPoint("TOPLEFT", fenetre, "TOPLEFT", 9, -52)
encart:SetPoint("BOTTOMRIGHT", fenetre, "BOTTOMRIGHT", -6, 26)
G.Encart(fenetre, encart, true)

-- ------------------------------------------------------------ les colonnes

for _, nom in ipairs({ "RealmNameSort", "RealmTypeSort", "RealmCharactersSort", "RealmLoadSort" }) do
	_G[nom]:SetNormalFontObject(G.Police("GlueFontHighlightSmall"))
end

-- ------------------------------------------------------------ les onglets

local function poser(t, atlas, point, x)
	G.PoserAtlas(t, atlas, true)
	t:ClearAllPoints()
	t:SetPoint(point, t:GetParent(), point, x, 0)
end

local function habillerOnglet(onglet)
	local nom = onglet:GetName()
	if not onglet.foreverOnglet then
		onglet.foreverOnglet = true
		-- repos : uiframe-tab-*
		local g, d, m = _G[nom .. "Left"], _G[nom .. "Right"], _G[nom .. "Middle"]
		poser(g, "uiframe-tab-left", "TOPLEFT", -3)
		poser(d, "uiframe-tab-right", "TOPRIGHT", 7)
		G.PoserAtlas(m, "_uiframe-tab-center", true)
		m:ClearAllPoints()
		m:SetPoint("LEFT", g, "RIGHT")
		m:SetPoint("RIGHT", d, "LEFT")
		-- choisi : uiframe-activetab-*
		local ga, da, ma = _G[nom .. "LeftDisabled"], _G[nom .. "RightDisabled"], _G[nom .. "MiddleDisabled"]
		poser(ga, "uiframe-activetab-left", "TOPLEFT", -1)
		poser(da, "uiframe-activetab-right", "TOPRIGHT", 8)
		G.PoserAtlas(ma, "_uiframe-activetab-center", true)
		ma:ClearAllPoints()
		ma:SetPoint("LEFT", ga, "RIGHT")
		ma:SetPoint("RIGHT", da, "LEFT")
		-- survol : l'art de l'onglet en ADD a 0,4 (couche HIGHLIGHT)
		local h = onglet:GetHighlightTexture()
		if h then
			h:SetTexture(nil)
			h:SetAlpha(0)
		end
		local hg = onglet:CreateTexture(nil, "HIGHLIGHT")
		G.PoserAtlas(hg, "uiframe-tab-left", true)
		hg:SetPoint("TOPLEFT", g, "TOPLEFT")
		local hd = onglet:CreateTexture(nil, "HIGHLIGHT")
		G.PoserAtlas(hd, "uiframe-tab-right", true)
		hd:SetPoint("TOPRIGHT", d, "TOPRIGHT")
		local hm = onglet:CreateTexture(nil, "HIGHLIGHT")
		G.PoserAtlas(hm, "_uiframe-tab-center", true)
		hm:SetPoint("LEFT", m, "LEFT")
		hm:SetPoint("RIGHT", m, "RIGHT")
		for _, t in ipairs({ hg, hd, hm }) do
			t:SetBlendMode("ADD")
			t:SetAlpha(0.4)
		end
		onglet:SetNormalFontObject(G.Police("GlueFontNormalSmall"))
		onglet:SetHighlightFontObject(G.Police("GlueFontHighlightSmall"))
	end
	-- RealmList_UpdateTabs repose la police de l'onglet grise a chaque passage
	onglet:SetDisabledFontObject(G.Police(onglet.disabled and "GlueFontDisableSmall" or "GlueFontHighlightSmall"))
end

G.AccrocherFonction("RealmList_UpdateTabs", function()
	for i = 1, MAX_REALM_CATEGORY_TABS or 8 do
		local onglet = _G["RealmListTab" .. i]
		if onglet then
			habillerOnglet(onglet)
		end
	end
end)
habillerOnglet(RealmListTab1)

-- ------------------------------------------------------------ la croix

G.CroixFenetre(RealmListCloseButton, fenetre)

-- ------------------------------------------------------------ Annuler / OK

-- SharedButtonSmallTemplate dans la barre du bas : la largeur du client
-- (125), la hauteur de camelot (22) ; Annuler a (-4, 4), OK colle a sa gauche
for _, b in ipairs({ RealmListCancelButton, RealmListOkButton }) do
	b:SetWidth(125)
	b:SetHeight(22)
	G.BoutonTroisTranches(b, "128-RedButton", { "GameFontNormal", "GameFontHighlight", "GameFontDisable" })
end
RealmListCancelButton:ClearAllPoints()
RealmListCancelButton:SetPoint("BOTTOMRIGHT", fenetre, "BOTTOMRIGHT", -4, 4)
RealmListOkButton:ClearAllPoints()
RealmListOkButton:SetPoint("TOPRIGHT", RealmListCancelButton, "TOPLEFT", 0, 0)

-- ------------------------------------------------------------ les lignes

for i = 1, LIGNES do
	local b = _G["RealmListRealmButton" .. i]
	b:SetDisabledFontObject(G.Police("GlueFontDisableLeft"))
	_G[b:GetName() .. "PVP"]:SetFontObject(G.Police("GlueFontRedSmall"))
	_G[b:GetName() .. "Players"]:SetFontObject(G.Police("GlueFontHighlightSmall"))
	_G[b:GetName() .. "Load"]:SetFontObject(G.Police("GlueFontHighlightSmall"))
end

-- ------------------------------------------------------------ la barre de defilement

-- la barre du client (GlueScrollFrameTemplate) reste celle qui fait defiler
-- -- la molette et le decalage passent par elle -- mais on ne la voit plus
local barreClient = RealmListScrollFrameScrollBar
barreClient:SetAlpha(0)
barreClient:EnableMouse(false)
for _, enfant in ipairs({ barreClient:GetChildren() }) do
	enfant:EnableMouse(false)
end
for _, nom in ipairs({ "ScrollBarTop", "ScrollBarMiddle", "ScrollBarBottom" }) do
	local t = _G["RealmListScrollFrame" .. nom]
	if t then
		t:SetAlpha(0)
	end
end

-- bord droit a 16 dans l'encart ; haut a 3 sous l'encart (2 sous la liste
-- du client, qui est a 1 sous l'encart) ; bas a 4 au-dessus du bas de la
-- liste (53 au-dessus du bas de la fenetre, donc 27 au-dessus de l'encart)
local barre = G.BarreMinimale(fond, "ForeverUIRealmListScrollBar")
barre:SetPoint("TOPRIGHT", encart, "TOPRIGHT", -16, -3)
barre:SetPoint("BOTTOMRIGHT", encart, "BOTTOMRIGHT", -16, 27)
barre.pas = HAUTEUR_LIGNE
barre.surDefilement = function(position)
	barreClient:SetValue(position)
end

-- ------------------------------------------------------------ apres le client

G.AccrocherFonction("RealmListUpdate", function()
	for i = 1, LIGNES do
		local b = _G["RealmListRealmButton" .. i]
		local n = policeCamelot(b:GetNormalFontObject())
		if n then
			b:SetNormalFontObject(n)
		end
		local h = policeCamelot(b:GetHighlightFontObject())
		if h then
			b:SetHighlightFontObject(h)
		end
	end
	local total = GetNumRealms(RealmList.selectedCategory or 1) or 0
	barre:Regler(total * HAUTEUR_LIGNE, LIGNES * HAUTEUR_LIGNE, (RealmList.offset or 0) * HAUTEUR_LIGNE)
end)
