-- ForeverUI -- les credits des ecrans d'accueil : le CreditsFrame de
-- camelot, sur les textes et la musique du client 3.3.5.
--
-- RELEVE -- blizzard_gluexml/mainline/creditsframe.xml et .lua ;
-- blizzard_gluexmlbase/mainline/constants.lua (CREDITS_SCROLL_RATE_*) et
-- gluebuttons.xml (GlueButtonSmallTemplate) ; blizzard_sharedxml :
-- shared/button/iconbuttontemplate.xml, shared/dialog/dialogtemplates.xml
-- (DialogBorderTranslucentTemplate, DialogHeaderTemplate).
--   * fond      CreditsScreen-Background-<extension> en mosaique sur tout
--               l'ecran (bandes comprises) ; illustration CreditsScreen-
--               KeyArt-<extension> (1425 x 966, en deux tuiles : 3.3.5
--               n'affiche pas plus de 1024) a TOP ((-(droite - gauche du
--               texte + 100) / 2), -50), a l'echelle (hauteur - 120) / 966 ;
--               degrades _CreditsScreen-Gradient-Tile de 64 en haut et en
--               bas (retourne), sur toute la largeur ; logo de l'extension
--               340 x 170 a TOPLEFT (35, -25) ;
--   * texte     colonne de 250 a RIGHT (-50) -- sur toute la hauteur de
--               l'ecran, comme les lignes de camelot -- GlueFontHighlightSmall
--               (espacement 2), titres GlueFontNormalLarge et GlueFontHighlight
--               (4) ; le premier titre part du haut ;
--   * vitesse   CreditsSpeedButtonTemplate 43 x 43 (common-button-square-
--               gray-up / -down a leur taille, icone CreditsScreen-Assets-
--               Buttons-* 22 x 22 en OVERLAY, sa copie en lueur ADD) : Rewind a
--               BOTTOM (-50, 20), Pause, Play, FastForward a 5 l'un de
--               l'autre ; -160, 0, 40, 160 par seconde ; le bouton actif garde
--               sa lueur, a 0,5 (les autres a 1 au survol) ; en arriere, le
--               debut arrete le defilement ; a la fin, retour a l'ecran de
--               connexion ;
--   * boutons   Back et Expansion, GlueButtonSmallTemplate (128-RedButton,
--               GlueFontNormalSmall / HighlightSmall / DisableSmall) 150 x 28 :
--               Back a BOTTOMLEFT (50, 50) de GlueParent, Expansion 10 au-dessus ;
--   * extensions  CreditsExpansionListTemplate : DialogBorderTranslucent
--               (noir 0,8 a 7 du bord, bord Dialog), en-tete EXPANSION ; une
--               ligne par extension, 28 de haut, 5 d'ecart, la premiere a TOP
--               (0, -35), largeur du plus long texte (200 au moins),
--               GlueFontHighlightSmall ; choisie : CreditsScreen-Selected a
--               0,8 ; survol : CreditsScreen-Highlight ; OK / Cancel de
--               max(80, texte) + 20, OK a BOTTOMRIGHT sur BOTTOM (-2, 20),
--               Cancel 4 a sa droite ; largeur max(lignes, 2 x bouton) + 60,
--               hauteur n x 33 + 100 ;
--   * Echap     ferme la liste si elle est ouverte, sinon l'ecran.
-- CHOIX DE L'UTILISATEUR (28/09) : la structure de camelot ; l'illustration
-- fixe de l'extension remplace le diaporama de 3.3.5. Les textes
-- (GetCreditsText), la musique (SetGlueScreen) et le passage d'une extension
-- a l'autre (CreditsFrame_Switch) restent ceux du client.

local G = ForeverUIGlue
local F = CreditsFrame

-- textes absents de 3.3.5 : ceux de camelot (GlobalStrings du client moderne)
local TEXTE = { EXTENSION = "Expansion" }

-- creditsType du client (1, 2, 3) -> extension de camelot (0, 1, 2)
local EXTENSIONS = {
	{ nom = WORLD_OF_WARCRAFT, logo = "Interface\\Glues\\Common\\Glues-WoW-Logo" },
	{ nom = BURNING_CRUSADE, logo = "Interface\\Glues\\Common\\Glues-WoW-BCLogo" },
	{ nom = WRATH_OF_THE_LICH_KING, logo = "Interface\\Glues\\Common\\Glues-WoW-WotLKLogo" },
}
local VITESSES = { recul = -160, pause = 0, lecture = 40, avance = 160 }

local etat = { position = 0, vitesse = VITESSES.lecture }

-- ------------------------------------------------------------ l'ecran du client

-- tout l'art du client (parchemin, diaporama, bandes, logo) : eteint
local function eteindreClient()
	for _, r in ipairs({ F:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r.forever then
			r:SetAlpha(0)
			r:Hide()
		end
	end
	-- les fondus du haut et du bas de la colonne (un cadre fils) ; pas le
	-- texte, qui est aussi un fils (ScrollChild)
	for _, c in ipairs({ CreditsScrollFrame:GetChildren() }) do
		if c ~= CreditsText then
			for _, r in ipairs({ c:GetRegions() }) do
				r:SetAlpha(0)
				r:Hide()
			end
		end
	end
	CreditsFrameSwitchButton1:Hide()
	CreditsFrameSwitchButton2:Hide()
end

-- ------------------------------------------------------------ le fond

local function texture(couche)
	local t = F:CreateTexture(nil, couche)
	t.forever = true
	return t
end

local fond = texture("BACKGROUND")
local tuiles = { texture("BORDER"), texture("BORDER") }
local degradeHaut = texture("ARTWORK")
local degradeBas = texture("ARTWORK")
local logo = texture("OVERLAY")
logo:SetWidth(340)
logo:SetHeight(170)
logo:SetPoint("TOPLEFT", F, "TOPLEFT", 35, -25)

-- CreditsFrameMixin:UpdateArt ; le fond et les degrades couvrent tout
-- l'ecran, bandes comprises
local function poserArt()
	local genre = F.creditsType or 3
	local extension = genre - 1
	local bande = G.BANDE or 0
	local largeur, hauteur = F:GetWidth() or 0, F:GetHeight() or 0

	fond:ClearAllPoints()
	fond:SetPoint("TOPLEFT", F, "TOPLEFT", -bande, 0)
	fond:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", bande, 0)
	G.Mosaique(fond, "CreditsScreen-Background-" .. extension, largeur + 2 * bande, hauteur)

	local ill = G.illustrations[extension]
	if ill and hauteur > 0 then
		local k = (hauteur - 120) / ill.hauteur
		local x = -((F:GetRight() or 0) - (CreditsScrollFrame:GetLeft() or 0) + 100) / 2
		local gauche = x - ill.largeur * k / 2
		for i, t in ipairs(tuiles) do
			local tu = ill.tuiles[i]
			if tu then
				t:SetTexture(tu[1])
				t:SetTexCoord(0, tu[2], 0, tu[3])
				t:SetWidth(tu[4] * k)
				t:SetHeight(ill.hauteur * k)
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", F, "TOP", gauche, -50)
				gauche = gauche + tu[4] * k
				t:Show()
			else
				t:Hide()
			end
		end
	end

	for _, t in ipairs({ degradeHaut, degradeBas }) do
		G.PoserAtlas(t, "_CreditsScreen-Gradient-Tile")
		t:SetHeight(64)
		t:ClearAllPoints()
		t:SetPoint("LEFT", F, "LEFT", -bande, 0)
		t:SetPoint("RIGHT", F, "RIGHT", bande, 0)
	end
	degradeHaut:SetPoint("TOP", F, "TOP")
	degradeBas:SetPoint("BOTTOM", F, "BOTTOM")
	-- le degrade du bas est retourne (TexCoords top 1, bottom 0)
	local e = G.atlas["_creditsscreen-gradient-tile"]
	degradeBas:SetTexCoord(e[2], e[3], e[5], e[4])

	logo:SetTexture(EXTENSIONS[genre] and EXTENSIONS[genre].logo or EXTENSIONS[3].logo)
end
G.surEchelle[#G.surEchelle + 1] = function()
	if F:IsShown() then
		poserArt()
	end
end

-- ------------------------------------------------------------ le texte

-- la colonne sur toute la hauteur de l'ecran, a 50 du bord droit
CreditsScrollFrame:ClearAllPoints()
CreditsScrollFrame:SetWidth(250)
CreditsScrollFrame:SetPoint("TOPRIGHT", F, "TOPRIGHT", -50, 0)
CreditsScrollFrame:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -50, 0)
for _, v in ipairs({ { "P", "GlueFontHighlightSmall", 2 }, { "H1", "GlueFontNormalLarge", 4 },
		{ "H2", "GlueFontHighlight", 4 } }) do
	pcall(CreditsText.SetFontObject, CreditsText, v[1], G.Police(v[2]))
	pcall(CreditsText.SetSpacing, CreditsText, v[1], v[3])
end

-- ------------------------------------------------------------ la vitesse

local vitesses = {}

-- CreditsFrameMixin:UpdateSpeedButtons
local function peindreVitesses()
	for _, b in ipairs(vitesses) do
		local actif = b.vitesse == etat.vitesse
		if actif then
			b:LockHighlight()
			b:GetHighlightTexture():SetAlpha(0.5)
		else
			b:UnlockHighlight()
			b:GetHighlightTexture():SetAlpha(1)
		end
	end
end

local function reglerVitesse(v)
	PlaySound("igMainMenuOptionCheckBoxOff")
	etat.vitesse = v
	peindreVitesses()
end

local function boutonVitesse(icone, vitesse)
	local b = CreateFrame("Button", nil, F)
	b:SetWidth(43)
	b:SetHeight(43)
	b.vitesse = vitesse
	b:SetNormalTexture(G.atlas["common-button-square-gray-up"][1])
	local n = b:GetNormalTexture()
	G.PoserAtlas(n, "common-button-square-gray-up", true)
	n:ClearAllPoints()
	n:SetPoint("CENTER", b, "CENTER")
	b:SetPushedTexture(G.atlas["common-button-square-gray-down"][1])
	local p = b:GetPushedTexture()
	G.PoserAtlas(p, "common-button-square-gray-down", true)
	p:ClearAllPoints()
	p:SetPoint("CENTER", b, "CENTER")
	b.icone = b:CreateTexture(nil, "OVERLAY")
	G.PoserAtlas(b.icone, icone, true)
	b.icone:SetPoint("CENTER", b, "CENTER")
	b:SetHighlightTexture(G.atlas[string.lower(icone)][1])
	local h = b:GetHighlightTexture()
	G.PoserAtlas(h, icone, true)
	h:ClearAllPoints()
	h:SetPoint("CENTER", b.icone, "CENTER")
	h:SetBlendMode("ADD")
	h:SetAlpha(0.4)
	b:SetScript("OnClick", function(self)
		reglerVitesse(self.vitesse)
	end)
	vitesses[#vitesses + 1] = b
	return b
end

local recul = boutonVitesse("CreditsScreen-Assets-Buttons-Rewind", VITESSES.recul)
recul:SetPoint("BOTTOM", F, "BOTTOM", -50, 20)
local precedent = recul
for _, v in ipairs({ { "CreditsScreen-Assets-Buttons-Pause", VITESSES.pause },
		{ "CreditsScreen-Assets-Buttons-Play", VITESSES.lecture },
		{ "CreditsScreen-Assets-Buttons-FastForward", VITESSES.avance } }) do
	local b = boutonVitesse(v[1], v[2])
	b:SetPoint("LEFT", precedent, "RIGHT", 5, 0)
	precedent = b
end

-- ------------------------------------------------------------ le defilement

-- a la place de CreditsFrame_OnUpdate du client (vitesse fixe, diaporama) :
-- la vitesse choisie ; au debut en arriere, pause ; a la fin, l'ecran de
-- connexion, comme le client
F:SetScript("OnUpdate", function(_, ecoule)
	if not CreditsScrollFrame:IsShown() then
		return
	end
	etat.position = etat.position + etat.vitesse * (ecoule or 0)
	if etat.position <= 0 then
		etat.position = 0
		if etat.vitesse < 0 then
			etat.vitesse = VITESSES.pause
			peindreVitesses()
		end
	end
	local fin = CreditsScrollFrame:GetVerticalScrollRange() + (CreditsScrollFrame:GetHeight() or 0)
	if etat.position >= fin then
		SetGlueScreen("login")
		return
	end
	CreditsScrollFrame:SetVerticalScroll(etat.position)
end)

-- ------------------------------------------------------------ la liste des extensions

local POLICES_PETITES = { "GlueFontNormalSmall", "GlueFontHighlightSmall", "GlueFontDisableSmall" }

local liste = CreateFrame("Frame", "ForeverUICreditsExpansionList", F)
liste:SetFrameStrata("DIALOG")
liste:EnableMouse(true)
liste:SetPoint("CENTER", F, "CENTER")
liste:Hide()
do
	local noir = liste:CreateTexture(nil, "BACKGROUND")
	noir:SetTexture(0, 0, 0, 0.8)
	noir:SetPoint("TOPLEFT", liste, "TOPLEFT", 7, -7)
	noir:SetPoint("BOTTOMRIGHT", liste, "BOTTOMRIGHT", -7, 7)
	G.NeufTranches(liste, "Dialog")
end
G.EnTeteDialogue(liste, TEXTE.EXTENSION, "GameFontNormal")

local lignes = {}
local choix

local function marquer()
	for _, b in ipairs(lignes) do
		G.Montrer(b.choisie, b:GetID() == choix)
	end
end

for i, ext in ipairs(EXTENSIONS) do
	local b = CreateFrame("Button", nil, liste)
	b:SetID(i)
	b:SetHeight(28)
	b:SetNormalFontObject(G.Police("GlueFontHighlightSmall"))
	b:SetHighlightFontObject(G.Police("GlueFontHighlightSmall"))
	b:SetDisabledFontObject(G.Police("GlueFontDisableSmall"))
	b:SetText(ext.nom)
	b.choisie = b:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(b.choisie, "CreditsScreen-Selected")
	b.choisie:SetAllPoints(b)
	b.choisie:SetVertexColor(1, 1, 1, 0.8)
	b.choisie:Hide()
	b.survol = b:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(b.survol, "CreditsScreen-Highlight")
	b.survol:SetAllPoints(b)
	b.survol:Hide()
	b:SetScript("OnEnter", function(self)
		if not self.choisie:IsShown() then
			self.survol:Show()
		end
	end)
	b:SetScript("OnLeave", function(self) self.survol:Hide() end)
	b:SetScript("OnClick", function(self)
		choix = self:GetID()
		marquer()
		self.survol:Hide()
	end)
	if i == 1 then
		b:SetPoint("TOP", liste, "TOP", 0, -35)
	else
		b:SetPoint("TOP", lignes[i - 1], "BOTTOM", 0, -5)
	end
	lignes[i] = b
end

local ok = G.CreerBoutonTroisTranches("ForeverUICreditsExpansionOkay", liste, 100, 28, "128-RedButton", POLICES_PETITES, OKAY)
ok:SetPoint("BOTTOMRIGHT", liste, "BOTTOM", -2, 20)
local annuler = G.CreerBoutonTroisTranches("ForeverUICreditsExpansionCancel", liste, 100, 28, "128-RedButton", POLICES_PETITES, CANCEL)
annuler:SetPoint("LEFT", ok, "RIGHT", 4, 0)
ok:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOff")
	liste:Hide()
	if choix and choix ~= F.creditsType then
		CreditsFrame_Switch(F, choix)
	end
end)
annuler:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOff")
	liste:Hide()
end)

-- CreditsExpansionListMixin:OpenExpansionList
local function ouvrirListe()
	choix = F.creditsType or 3
	local plusLarge = 200
	for _, b in ipairs(lignes) do
		plusLarge = math.max(plusLarge, b:GetTextWidth() or 0)
	end
	for _, b in ipairs(lignes) do
		b:SetWidth(plusLarge)
	end
	local texteBoutons = math.max(ok:GetTextWidth() or 0, annuler:GetTextWidth() or 0)
	local lb = math.max(80, texteBoutons) + 10 * 2
	ok:SetWidth(lb)
	annuler:SetWidth(lb)
	liste:SetWidth(math.max(plusLarge, 2 * lb) + 60)
	liste:SetHeight(#lignes * (28 + 5) + 100)
	marquer()
	liste:Show()
end

-- ------------------------------------------------------------ Back et Expansion

local retour = G.CreerBoutonTroisTranches("ForeverUICreditsBackButton", F, 150, 28, "128-RedButton", POLICES_PETITES, BACK)
retour:SetPoint("BOTTOMLEFT", GlueParent, "BOTTOMLEFT", 50, 50)
retour:SetScript("OnClick", function()
	SetGlueScreen("login")
end)
local extension = G.CreerBoutonTroisTranches("ForeverUICreditsExpansionButton", F, 150, 28, "128-RedButton", POLICES_PETITES, TEXTE.EXTENSION)
extension:SetPoint("BOTTOM", retour, "TOP", 0, 10)
extension:SetScript("OnClick", function()
	if liste:IsShown() then
		liste:Hide()
	else
		ouvrirListe()
	end
end)

F:SetScript("OnKeyDown", function(_, touche)
	if touche == "ESCAPE" then
		if liste:IsShown() then
			liste:Hide()
		else
			SetGlueScreen("login")
		end
	elseif touche == "PRINTSCREEN" then
		Screenshot()
	end
end)

-- ------------------------------------------------------------ a chaque ouverture

-- apres CreditsFrame_OnShow du client (texte, defilement a 0)
G.Accrocher(F, "OnShow", function()
	eteindreClient()
	liste:Hide()
	etat.position = 0
	etat.vitesse = VITESSES.lecture
	peindreVitesses()
	poserArt()
end)
eteindreClient()
