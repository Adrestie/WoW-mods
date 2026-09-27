-- ForeverUI -- la liste des royaumes, a la DA de camelot.
--
-- CHOIX (27/09) : camelot n'a pas de liste des royaumes (son .toc ne charge
-- RealmList que pour le jeu mainline ; camelot choisit une region par
-- cartes, SuperDistrict). On garde la liste du client 3.3.5 -- ses places,
-- ses tailles, sa logique -- et on lui donne l'art de la liste moderne
-- (blizzard_gluexml/mainline/realmlist.xml, meme ecran) :
--   * le cadre (Interface\HelpFrame\HelpFrame-*), les en-tetes de colonnes
--     (WhoFrame-ColumnTabs), la fleche de tri (UI-SortArrow) et la barre de
--     la ligne choisie (UI-QuestLogTitleHighlight) restent : la liste
--     moderne emploie les memes fichiers, identiques dans le client de
--     camelot (ecart moyen de 0,1 a 1,7 sur 255, bruit de compression) ;
--   * en-tete : DialogHeaderTemplate a TOP (-12, 11), texte SERVER_SELECTION ;
--   * onglets (RealmListTabButtonTemplate) : uiframe-tab-left / -right /
--     _center a leur taille, LEFT a -3 et RIGHT a +7 ; l'onglet choisi
--     uiframe-activetab-*, LEFT a -1 et RIGHT a +8 ; survol : l'art de
--     l'onglet en ADD a 0,4 ;
--   * croix : BigRedExitButtonTemplate (artKit 128-redbutton-exit), 32 x 32 ;
--   * Annuler / OK : GlueButtonTemplate (SharedButtonTemplate, 128-RedButton,
--     GlueFontNormal / Highlight / Disable) ;
--   * barre de defilement : MinimalScrollBar, a 5 a droite de la liste, de
--     -2 en haut a +4 en bas ;
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

-- ------------------------------------------------------------ l'en-tete

RealmListHeader:SetAlpha(0)
RealmListHeader:Hide()
for _, r in ipairs({ fond:GetRegions() }) do
	if r:GetObjectType() == "FontString" and r:GetText() == SERVER_SELECTION then
		r:SetAlpha(0)
		r:Hide()
	end
end
local entete = G.EnTeteDialogue(fond, SERVER_SELECTION, "GameFontNormal")
entete:ClearAllPoints()
entete:SetPoint("TOP", fond, "TOP", -12, 11)

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

RealmListCloseButton:SetWidth(32)
RealmListCloseButton:SetHeight(32)
G.BoutonArt(RealmListCloseButton, "128-RedButton-Exit")

-- ------------------------------------------------------------ Annuler / OK

for _, b in ipairs({ RealmListCancelButton, RealmListOkButton }) do
	G.BoutonTroisTranches(b, "128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
end

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

local barre = G.BarreMinimale(fond, "ForeverUIRealmListScrollBar")
barre:SetPoint("TOPLEFT", RealmListScrollFrame, "TOPRIGHT", 5, -2)
barre:SetPoint("BOTTOMLEFT", RealmListScrollFrame, "BOTTOMRIGHT", 5, 4)
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
