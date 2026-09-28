-- ForeverUI : la creation de personnage, copie de celle de camelot --
-- premiere etape (race, classe, corps).
--
-- RELEVE -- blizzard_charactercreate/camelot : blizzard_charactercreate.xml et
-- .lua, blizzard_charactercreate_templates.xml et .lua ;
-- blizzard_charactercustomize/camelot/blizzard_charactercustomize.xml
-- (CharCustomizeBodyTypeButtonTemplate) ; blizzard_customizationui
-- (CustomizationMaskedButtonTemplate) ; blizzard_sharedxml :
-- shared/frametemplate/ringedframetemplate.xml et .lua,
-- spacetofitlayoutframe.lua, portraitframe.lua, sharedconstants.lua.
-- Nombres de camelot :
--   * vignettes : haut 451 de haut sur toute la largeur, cotes 703 de large
--     (celui de droite retourne), bas 577 ; bandes de 89 aux bords quand
--     l'ecran depasse le 16:9 ; noir hors du cadre ; alpha 0,8 pour le
--     chevalier de la mort, sinon 0,6 pour la Horde, sinon 1 ; celle du bas
--     s'efface en 0,25 s a l'etape suivante ;
--   * colonnes de faction 168 x 794, Alliance a TOPLEFT (3, 0), Horde 20 a sa
--     droite : banniere et embleme a leur taille d'atlas en TOP, nom de la
--     faction en capitales (GameFontNormalLarge2) dont le haut est 10 au-dessus
--     du bas de l'embleme, races 10 sous le nom ;
--   * boutons de race 79 x 79, 18 d'ecart (moins si la colonne ne tient pas
--     a 20 au-dessus de Back) ; anneau character-create-icon-frame 86 x 86,
--     lueur de selection character-create-icon-selectedglow 116 x 116 ;
--     survol : l'anneau (non choisi) ou la lueur (choisi), en ADD a 0,5 ;
--     enfonce : icone, anneau et lueur decales de (1, -1) ; interdit : icone
--     desaturee sous un voile noir a 0,5 (0,75 pour une classe) ; icones de
--     la Horde retournees ;
--   * corps (BodyTypes) : cadre heavybronze en TOP, marges 20 / 20 / 25,
--     ecart 22, au moins 180 x 90 ; boutons 55 x 55, anneau 60, lueur 80,
--     fond noir rond de 56 ; icone charactercreate-gendericon-<sexe> (-selected
--     une fois choisi) ; infobulle BODY_1 / BODY_2 en ANCHOR_BOTTOMRIGHT ;
--   * classes : cadre heavybronze 900 x 140 en BOTTOM ; boutons 66 x 66, 30
--     d'ecart, anneau 73, lueur 103, nom GameFontNormalMed2 (grise :
--     GameFontDisableMed2) de 85 x 48 sous le bouton (2, 3) ; rangee a
--     (largeur - rangee) / 2 du bord gauche, (140 - 116) / 2 au-dessus du
--     milieu ; deux rangees de 50 d'ecart si la place manque entre la Horde
--     et Customize ; ordre de camelot (classLayoutIndices) ;
--   * encadres (faction, race, classe) : 390 x 260, en colonne a TOPRIGHT
--     (0, -40), 10 d'ecart ; cadre heavybronze-frame-basic, equerres
--     verticales TR / BR, fond heavybronze en mosaique de (10, -10) a
--     (-10, 10) ; portrait 62 x 62 a (-30, 12) du coin haut gauche, anneau
--     character-create-icon-circle-frame 64 x 64 ; texte defilant de
--     (44, -14) a (-35, 15), lignes de 310 a 10 d'ecart : espace de 14,
--     titre GameFontNormalLarge2 blanc, textes GameFontNormalLarge dores,
--     espace de 14 ; barre minimale, une fleche avance de 50 ;
--   * Back et Customize : 250 x 66, GameFontNormalOutline22, a BOTTOMLEFT
--     (46, 28) et BOTTOMRIGHT (-46, 28) ; fleche 8 x 13 a deux espaces du
--     texte (common-icon-backarrow / -forwardarrow, -disable si grise).
-- Les donnees et les decisions restent celles du client 3.3.5 : nos boutons
-- cliquent ses boutons caches (CharacterRace_OnClick, CharacterClass_OnClick,
-- SetCharacterGender), et se relisent apres CharacterChangeFixup.
-- ECARTS : le cadre des classes s'allonge pour la dixieme classe de 3.3.5
-- (996 au lieu de 900, meme marge de 33) ; les traits raciaux sont du texte seul (3.3.5 n'a pas leurs
-- icones) ; pas d'animation de classe, pas de fondu des bords du texte ; le
-- nom de la race sous son bouton n'est montre chez camelot qu'en mode
-- debutant, que 3.3.5 n'a pas ; l'anneau -disabled que camelot demande
-- n'existe pas dans le client moderne : l'anneau reste le meme.
--
-- SECONDE ETAPE (personnalisation) -- blizzard_charactercustomize/camelot
-- (CustomizeOptionsContainerFrame, CharacterCustomizeOptions),
-- blizzard_customizationui (CustomizationFrameBaseMixin, gabarits,
-- CustomizationDropdownWithSteppersAndLabelTemplate), blizzard_sharedxml
-- (DropdownWithSteppersLargeTemplate, SharedEditBoxTemplate), blizzard_menu
-- (WowStyle2DropdownTemplate, WowStyle2IconButtonTemplate) :
--   * panneau heavybronze de 360 de large a TOPRIGHT (0, -137), equerres
--     verticales TR / BR, haut de 20 de plus que son contenu ; de au hasard
--     (bouton carre 48 x 48, icone 24) a TOPLEFT (12, -12) ; pas de
--     categories (une seule) : les reglages a TOPRIGHT (-10, -80), 300 de
--     large, lignes de 265 x 38 a 48 d'ecart ;
--   * une ligne : la case (WowStyle2Dropdown 122 x 25 a l'echelle 1,55, fond
--     common-dropdown-c-button en trois tranches de (-7, 7) a (7, -7), texte
--     GameFontNormal dore entre 13 et -13) au centre ; fleches
--     (WowStyle2IconButton 26 x 25 a l'echelle 1,7, fond common-dropdown-
--     c-button[-hover-2|-pressed-2|-pressedhover-2] a sa taille, icone
--     common-dropdown-icon-back / -next decalee de (2, -1) enfoncee) a 5 a
--     gauche et 4 a droite de la case ;
--   * nom : cadre heavybronze 800 x 90 en TOP, equerres horizontales TL / TR,
--     « Name » (GameFontHighlightLarge2) a TOP (0, -16) ; de du nom au hasard
--     a LEFT (10, -10) ; champ SharedEditBox 343 x 48 a sa droite (gauche 13
--     et droite 314 a leur taille, milieu en mosaique ; NumberFont_Shadow_Large
--     centre) ; Echap recule, Entree avance ;
--   * petits boutons (SmallButtons) : cadre heavybronze a TOPLEFT (40, -30),
--     fond de (8, -8) a (-8, 8), marges 10, ecart -5 ; boutons carres 48 x 48
--     (icone 24 en OVERLAY) : reinitialiser (common-icon-undo : retour a
--     l'orientation par defaut en 0,25 s), puis 30 plus loin tourner a
--     gauche et a droite (common-icon-rotateleft / -right : 10 degres au
--     clic, 100 par seconde tenu plus de 0,25 s) ; infobulle en
--     ANCHOR_BOTTOMRIGHT (-5, -5). Pas de zoom avant ni arriere : la camera
--     de la creation est celle du modele du decor (une seule par decor) et
--     suit ses deplacements ; 3.3.5 n'offre rien d'autre au Lua.
-- MODE 1 (client non patche) : la case porte le nom du reglage, sans numero
-- ni echantillon (3.3.5 ne dit pas quel choix est applique) ; elle ne s'ouvre
-- pas. Les fleches cyclent par CharacterCustomization_Left / _Right.

local G = ForeverUIGlue
local L = G.L
local cadre = CharacterCreateFrame

-- textes absents de 3.3.5 : G.L (ForeverUIGlueTextes) ; les noms des
-- factions sont ceux du client (ALLIANCE, HORDE de GlueStrings)
local TEXTE = {
	CUSTOMIZE = L.GLUECHARACTERCREATE_CUSTOMIZE,
	FINISH = L.GLUECHARACTERCREATE_FINISH,
	RACIAL_TRAITS = L.GLUECHARACTERCREATE_RACIAL_TRAITS,
	FACTION = { Alliance = ALLIANCE, Horde = HORDE },
	LORE = {
		Alliance = L.GLUECHARACTERCREATE_LORE_ALLIANCE,
		Horde = L.GLUECHARACTERCREATE_LORE_HORDE,
	},
	BODY = { [SEX_MALE] = L.GLUECHARACTERCREATE_BODY_1, [SEX_FEMALE] = L.GLUECHARACTERCREATE_BODY_2 },
	RANDOMIZE_APPEARANCE = L.GLUECHARACTERCREATE_RANDOMIZE_APPEARANCE,
	RESET_CAMERA = L.GLUECHARACTERCREATE_RESET_CAMERA,
	ROTATE_LEFT = L.GLUECHARACTERCREATE_ROTATE_LEFT,
	ROTATE_RIGHT = L.GLUECHARACTERCREATE_ROTATE_RIGHT,
}

local ART = "Interface\\ForeverUI\\charactercreate\\"
-- le nom de fichier des icones de race (fileString de 3.3.5 en capitales)
local FICHIER_RACE = {
	HUMAN = "human", ORC = "orc", DWARF = "dwarf", NIGHTELF = "nightelf", SCOURGE = "undead",
	TAUREN = "tauren", GNOME = "gnome", TROLL = "troll", BLOODELF = "bloodelf", DRAENEI = "draenei",
}
-- classLayoutIndices de camelot
local ORDRE_CLASSE = {
	WARRIOR = 1, HUNTER = 2, MAGE = 3, ROGUE = 4, PRIEST = 5, WARLOCK = 6,
	PALADIN = 7, DRUID = 8, SHAMAN = 9, DEATHKNIGHT = 12,
}
-- UpdateBackgroundOverlays : classe, sinon faction
local ALPHA_FOND = { classe = { DEATHKNIGHT = 0.8 }, faction = { Horde = 0.6 } }

local etat = { mode = 1, races = {}, classes = {}, fondu = nil }

-- IsEnabled rend 1 ou nil en 3.3.5
local function actif(b)
	local e = b:IsEnabled()
	return e and e ~= 0
end

local function sexe()
	return (GetSelectedSex() == SEX_FEMALE) and "female" or "male"
end

-- ------------------------------------------------------------ la racine

local racine = CreateFrame("Frame", "ForeverUICharacterCreate", cadre)
racine:SetAllPoints(cadre)

-- ------------------------------------------------------------ les vignettes

local function vignette(nom, points, largeur, hauteur, retourner)
	local t = racine:CreateTexture(nil, "BACKGROUND")
	local e = G.PoserAtlas(t, nom)
	if retourner then
		t:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	for _, p in ipairs(points) do
		t:SetPoint(p, racine, p)
	end
	if largeur then t:SetWidth(largeur) end
	if hauteur then t:SetHeight(hauteur) end
	return t
end

-- BGTex : haut, gauche, droite, bas
local fonds = {
	vignette("charactercreate-vignette-top", { "TOPLEFT", "TOPRIGHT" }, nil, 451),
	vignette("charactercreate-vignette-sides", { "TOPLEFT", "BOTTOMLEFT" }, 703),
	vignette("charactercreate-vignette-sides", { "TOPRIGHT", "BOTTOMRIGHT" }, 703, nil, true),
	vignette("charactercreate-vignette-bottom", { "BOTTOMLEFT", "BOTTOMRIGHT" }, nil, 577),
}
local fondBas = fonds[4]
local larges = {
	vignette("charactercreate-vignette-sides-widescreen", { "TOPLEFT", "BOTTOMLEFT" }, 89),
	vignette("charactercreate-vignette-sides-widescreen", { "TOPRIGHT", "BOTTOMRIGHT" }, 89, nil, true),
}
-- noir hors du cadre (LeftBlackBar, RightBlackBar)
local noirs = {}
for i, cote in ipairs({ { "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT" }, { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
	local t = racine:CreateTexture(nil, "BACKGROUND")
	t:SetTexture(0, 0, 0)
	t:SetPoint(cote[1], racine, cote[2])
	t:SetPoint(cote[3], racine, cote[4])
	noirs[i] = t
end

local function poserBords()
	local bande = G.BANDE or 0
	for _, t in ipairs(noirs) do
		t:SetWidth(math.max(bande, 1))
		G.Montrer(t, bande > 0)
	end
	local large = (GetScreenWidth() / GetScreenHeight()) - 16 / 9 > 0.001
	for _, t in ipairs(larges) do
		G.Montrer(t, large)
	end
end
-- une autre resolution appliquee : les bandes noires et les vignettes
-- larges suivent la nouvelle zone utile (ForeverUIGlue.lua)
G.surEchelle[#G.surEchelle + 1] = poserBords

-- ------------------------------------------------------------ le bouton rond

-- RingedMaskedButtonTemplate : l'icone (cuite dans son masque rond par
-- tools/cuire_creation.py), le voile des boutons interdits, l'anneau, la
-- lueur de selection, et le survol en ADD a 0,5
local function boutonRond(parent, taille, anneau, lueur, voile)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(taille)
	b:SetHeight(taille)
	b.icone = b:CreateTexture(nil, "ARTWORK")
	b.icone:SetAllPoints(b)
	b.voile = b:CreateTexture(nil, "ARTWORK")
	b.voile:SetAllPoints(b.icone)
	b.voile:SetVertexColor(0, 0, 0)
	b.voile:SetAlpha(voile)
	b.anneau = b:CreateTexture(nil, "OVERLAY")
	G.PoserAtlas(b.anneau, "character-create-icon-frame")
	b.anneau:SetWidth(anneau)
	b.anneau:SetHeight(anneau)
	b.lueur = b:CreateTexture(nil, "OVERLAY")
	G.PoserAtlas(b.lueur, "character-create-icon-selectedglow")
	b.lueur:SetWidth(lueur)
	b.lueur:SetHeight(lueur)
	b.survol = b:CreateTexture(nil, "HIGHLIGHT")
	b.survol:SetBlendMode("ADD")
	b.survol:SetAlpha(0.5)
	local function placer(dx, dy)
		b.icone:ClearAllPoints()
		b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", dx, dy)
		b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", dx, dy)
		b.anneau:ClearAllPoints()
		b.anneau:SetPoint("CENTER", b, "CENTER", dx, dy)
		b.lueur:ClearAllPoints()
		b.lueur:SetPoint("CENTER", b, "CENTER", dx, dy)
	end
	placer(0, 0)
	b:SetScript("OnMouseDown", function(self)
		if actif(self) then placer(1, -1) end
	end)
	b:SetScript("OnMouseUp", function() placer(0, 0) end)
	-- SetChecked, SetEnabledState, UpdateHighlightTexture
	function b:Etat(choisi, permis)
		self.choisi = choisi
		G.Montrer(self.lueur, choisi)
		if permis then self:Enable() else self:Disable() end
		self.icone:SetDesaturated(not permis)
		G.Montrer(self.voile, not permis)
		self.survol:ClearAllPoints()
		if choisi then
			G.PoserAtlas(self.survol, "character-create-icon-selectedglow")
			self.survol:SetAllPoints(self.lueur)
		else
			G.PoserAtlas(self.survol, "character-create-icon-frame")
			self.survol:SetAllPoints(self.anneau)
		end
	end
	return b
end

-- l'icone d'un bouton rond : un fichier cuit (retourne pour la Horde)
local function iconeFichier(b, fichier, retourner)
	for _, t in ipairs({ b.icone, b.voile }) do
		t:SetTexture(fichier)
		if retourner then
			t:SetTexCoord(1, 0, 0, 1)
		else
			t:SetTexCoord(0, 1, 0, 1)
		end
	end
end

-- ------------------------------------------------------------ le cadre heavybronze

local function cadreBronze(f, equerres, marge)
	marge = marge or 10
	local fond = f:CreateTexture(nil, "BACKGROUND")
	fond:SetPoint("TOPLEFT", f, "TOPLEFT", marge, -marge)
	fond:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -marge, marge)
	local bord = G.AtlasEtire(f, "heavybronze-frame-basic", "BORDER")
	bord.rect:SetAllPoints(f)
	for _, e in ipairs(equerres) do
		local t = f:CreateTexture(nil, "BORDER")
		G.PoserAtlas(t, e[1], true)
		t:SetPoint(e[2], f, e[2])
	end
	return function(largeur, hauteur)
		f:SetWidth(largeur)
		f:SetHeight(hauteur)
		G.Mosaique(fond, "heavybronze-frame-background", largeur - 2 * marge, hauteur - 2 * marge)
	end
end

-- ------------------------------------------------------------ les boutons de navigation

local function boutonNav(nom, sens)
	local b = G.CreerBoutonTroisTranches(nom, racine, 250, 66, "128-RedButton",
		{ "GameFontNormalOutline22", "GameFontHighlightOutline22", "GameFontDisableOutline22" })
	b.fleche = b:CreateTexture(nil, "ARTWORK")
	b.fleche:SetWidth(8)
	b.fleche:SetHeight(13)
	b.sens = sens
	return b
end

-- UpdateText : « texte  fleche » ou « fleche  texte », centres ensemble
local function texteNav(b, texte)
	local avant = (b.sens == "avant")
	b:SetText(avant and (texte .. "  ") or ("  " .. texte))
	local fs = b:GetFontString()
	local grise = actif(b) and "" or "-disable"
	fs:ClearAllPoints()
	b.fleche:ClearAllPoints()
	if avant then
		G.PoserAtlas(b.fleche, "common-icon-forwardarrow" .. grise)
		fs:SetPoint("CENTER", b, "CENTER", -4, 0)
		b.fleche:SetPoint("LEFT", fs, "RIGHT")
	else
		G.PoserAtlas(b.fleche, "common-icon-backarrow" .. grise)
		fs:SetPoint("CENTER", b, "CENTER", 4, 0)
		b.fleche:SetPoint("RIGHT", fs, "LEFT")
	end
	b.fleche:SetWidth(8)
	b.fleche:SetHeight(13)
end

local retour = boutonNav("ForeverUICharacterCreateBackButton", "arriere")
retour:SetPoint("BOTTOMLEFT", racine, "BOTTOMLEFT", 46, 28)
local avancer = boutonNav("ForeverUICharacterCreateForwardButton", "avant")
avancer:SetPoint("BOTTOMRIGHT", racine, "BOTTOMRIGHT", -46, 28)

-- ------------------------------------------------------------ race et classe

local raceClasse = CreateFrame("Frame", nil, racine)
raceClasse:SetAllPoints(racine)

local function colonne(faction)
	local f = CreateFrame("Frame", nil, raceClasse)
	f:SetWidth(168)
	f:SetHeight(794)
	local cle = string.lower(faction)
	local banniere = f:CreateTexture(nil, "BACKGROUND")
	G.PoserAtlas(banniere, "charactercreate-factionflag-" .. cle, true)
	banniere:SetPoint("TOP", f, "TOP")
	local logo = f:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(logo, "charactercreate-icon-" .. cle, true)
	logo:SetPoint("TOP", f, "TOP")
	local nom = f:CreateFontString(nil, "ARTWORK")
	nom:SetFontObject(G.Police("GameFontNormalLarge2"))
	nom:SetPoint("TOP", logo, "BOTTOM", 0, 10)
	nom:SetText(string.upper(TEXTE.FACTION[faction]))
	f.races = CreateFrame("Frame", nil, f)
	f.races:SetWidth(79)
	f.races:SetHeight(1)
	f.races:SetPoint("TOP", nom, "BOTTOM", 0, -10)
	f.boutons = {}
	return f
end

local alliance = colonne("Alliance")
alliance:SetPoint("TOPLEFT", raceClasse, "TOPLEFT", 3, 0)
local horde = colonne("Horde")
horde:SetPoint("TOPLEFT", alliance, "TOPRIGHT", 20, 0)
local COLONNES = { Alliance = alliance, Horde = horde }

local function boutonRace(col, i)
	local b = col.boutons[i]
	if not b then
		b = boutonRond(col.races, 79, 86, 116, 0.5)
		b:SetScript("OnClick", function(self)
			local client = _G["CharacterCreateRaceButton" .. self.index]
			if client then client:Click() end
		end)
		col.boutons[i] = b
	end
	return b
end

-- SpaceToFitVerticalLayoutFrame : 18, ou moins si la colonne ne tient pas
-- a 20 au-dessus de Back
local function rangerRaces(col, n)
	local ecart = 18
	local haut, basRetour = col.races:GetTop(), retour:GetTop()
	if haut and basRetour and n > 0 then
		local reste = (haut - basRetour - 20) - n * 79
		if reste < ecart * n then
			ecart = math.floor(reste / n)
		end
	end
	for i = 1, n do
		local b = col.boutons[i]
		b:ClearAllPoints()
		b:SetPoint("TOP", col.races, "TOP", 0, -(i - 1) * (79 + ecart))
	end
end

-- les corps
local corps = CreateFrame("Frame", nil, raceClasse)
-- ECART voulu (27/09) : decale vers la droite (camelot : au centre), pour
-- laisser la tete des grands personnages visible
local DECALAGE_CORPS = 250
corps:SetPoint("TOP", raceClasse, "TOP", DECALAGE_CORPS, 0)
local dimensionnerCorps = cadreBronze(corps, { { "heavybronze-horz-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-horz-cornerbracket-tl", "TOPLEFT" } })
-- HorizontalLayoutFrame : 25 + 55 + 22 + 55 = 157 -> 180 ; 20 + 55 + 20 = 95
dimensionnerCorps(math.max(180, 25 + 55 + 22 + 55), math.max(90, 20 + 55 + 20))
local boutonsCorps = {}
for i, sexeId in ipairs({ SEX_MALE, SEX_FEMALE }) do
	local b = boutonRond(corps, 55, 60, 80, 0.75)
	b:SetPoint("TOPLEFT", corps, "TOPLEFT", 25 + (i - 1) * (55 + 22), -20)
	-- BlackBG : 56 x 56, noir, rond
	local noir = b:CreateTexture(nil, "BACKGROUND")
	G.PoserAtlas(noir, "character-create-icon-mask")
	noir:SetVertexColor(0, 0, 0)
	noir:SetWidth(56)
	noir:SetHeight(56)
	noir:SetPoint("CENTER", b, "CENTER")
	b.sexe = sexeId
	b:SetScript("OnClick", function(self)
		if self.sexe == SEX_MALE then
			CharacterCreateGenderButtonMale:Click()
		else
			CharacterCreateGenderButtonFemale:Click()
		end
	end)
	-- ANCHOR_BOTTOMRIGHT (10, 0) de RingedFrameWithTooltipTemplate
	b:SetScript("OnEnter", function(self)
		GlueTooltip_SetOwner(self, nil, 10, 0, "TOPLEFT", "BOTTOMRIGHT")
		GlueTooltip_SetText(TEXTE.BODY[self.sexe], nil, 1.0, 1.0, 1.0)
	end)
	b:SetScript("OnLeave", function() GlueTooltip:Hide() end)
	boutonsCorps[i] = b
end

-- les classes
local classes = CreateFrame("Frame", nil, raceClasse)
classes:SetFrameLevel(raceClasse:GetFrameLevel() + 4)
classes:SetPoint("BOTTOM", raceClasse, "BOTTOM")
local dimensionnerClasses = cadreBronze(classes, { { "heavybronze-horz-cornerbracket-br", "BOTTOMRIGHT" }, { "heavybronze-horz-cornerbracket-bl", "BOTTOMLEFT" } })
dimensionnerClasses(900, 140)
local boutonsClasse = {}

local function boutonClasse(i)
	local b = boutonsClasse[i]
	if not b then
		b = boutonRond(classes, 66, 73, 103, 0.75)
		b.nom = b:CreateFontString(nil, "OVERLAY")
		b.nom:SetWidth(85)
		b.nom:SetHeight(48)
		b.nom:SetJustifyH("CENTER")
		b.nom:SetJustifyV("MIDDLE")
		b.nom:SetPoint("TOP", b, "BOTTOM", 2, 3)
		b:SetScript("OnClick", function(self)
			local client = _G["CharacterCreateClassButton" .. self.index]
			if client then client:Click() end
		end)
		boutonsClasse[i] = b
	end
	return b
end

-- UpdateClassButtons
local function rangerClasses(n)
	local ecartX, icone, ecartNom = 30, 66, 50
	local largeurBouton, hauteurBouton = icone, icone + ecartNom
	-- AvailableSpace : de 10 a droite de la Horde (3 + 168 + 20 + 168 du bord
	-- gauche) a 10 a gauche de Customize
	local place = 900
	local bord, droite = racine:GetLeft(), avancer:GetLeft()
	if bord and droite then
		place = (droite - 10) - (bord + 3 + 168 + 20 + 168 + 10)
	end
	local rangees = math.ceil((n * largeurBouton + (n - 1) * ecartX) / place)
	local largeur, hauteur = 900, 140
	if rangees <= 1 then
		rangees = 1
		place = largeur
	else
		hauteur = 140 * 2 - 20
	end
	if place < 900 then
		ecartX = 20
		place = place - 40
		largeur = place
	end
	if rangees > 2 then
		rangees = 2
	end
	local pas = math.ceil(n / rangees)
	local rangee = (pas * largeurBouton) + ((pas - 1) * ecartX)
	-- ECART voulu (27/09) : les 900 de camelot tiennent ses 9 classes avec 33
	-- de marge de chaque cote ; la rangee de 3.3.5 (10 classes) garde cette
	-- marge, le cadre s'allonge d'autant
	local marge = (900 - (9 * largeurBouton + 8 * 30)) / 2
	if rangee + 2 * marge > largeur then
		largeur = rangee + 2 * marge
		place = largeur
	end
	dimensionnerClasses(largeur, hauteur)
	local x0 = (place - rangee) / 2
	local y0 = (hauteur - hauteurBouton) * 0.5
	for i = 1, n do
		local b = boutonsClasse[i]
		local col, lig = (i - 1) % pas, math.floor((i - 1) / pas)
		b:ClearAllPoints()
		b:SetPoint("LEFT", classes, "LEFT", x0 + col * (largeurBouton + ecartX), y0 - lig * (icone + ecartNom))
	end
end

-- ------------------------------------------------------------ les encadres

local function encadre(nom, indice)
	local f = CreateFrame("Frame", nom, racine)
	f:SetFrameLevel(racine:GetFrameLevel() + 4)
	f:EnableMouse(true)
	f:SetPoint("TOPRIGHT", racine, "TOPRIGHT", 0, -40 - (indice - 1) * (260 + 10))
	local dimensionner = cadreBronze(f, { { "heavybronze-vert-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-vert-cornerbracket-br", "BOTTOMRIGHT" } })
	dimensionner(390, 260)

	-- PortraitContainer (frameLevel 400)
	local p = CreateFrame("Frame", nil, f)
	p:SetFrameLevel(400)
	p:SetWidth(1)
	p:SetHeight(1)
	p:SetPoint("TOPLEFT", f, "TOPLEFT", -25, 5)
	f.portrait = p:CreateTexture(nil, "OVERLAY")
	f.portrait:SetWidth(62)
	f.portrait:SetHeight(62)
	f.portrait:SetPoint("TOPLEFT", p, "TOPLEFT", -5, 7)
	local anneau = p:CreateTexture(nil, "OVERLAY")
	G.PoserAtlas(anneau, "character-create-icon-circle-frame")
	anneau:SetWidth(64)
	anneau:SetHeight(64)
	anneau:SetPoint("CENTER", f.portrait, "CENTER")

	-- ScrollBox et son contenu (VerticalLayoutFrame, ecart 10)
	local zone = CreateFrame("ScrollFrame", nil, f)
	zone:SetPoint("TOPLEFT", f, "TOPLEFT", 44, -14)
	zone:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -35, 15)
	local contenu = CreateFrame("Frame", nil, zone)
	contenu:SetWidth(310)
	contenu:SetHeight(1)
	zone:SetScrollChild(contenu)
	f.zone, f.contenu, f.lignes = zone, contenu, {}

	local barre = G.BarreMinimale(f, nom .. "ScrollBar")
	barre:SetPoint("TOP", f, "TOPRIGHT", -25.5, -14 - 16)
	barre:SetPoint("BOTTOM", f, "BOTTOMRIGHT", -25.5, 15 + 16)
	barre.pas = 50
	-- la barre seulement si elle sert (regle du 28/09) ; sans elle, la zone
	-- s'etend jusqu'au bord droit qu'elle avait (-25,5 + 4 : -21,5), le texte
	-- avec (voir remplir)
	barre.cacherSiInutile = true
	barre.surVisibilite = function(avec)
		zone:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", avec and -35 or -21.5, 15)
	end
	barre.surDefilement = function(position)
		zone:SetVerticalScroll(position)
	end
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(_, sens)
		barre:Deplacer(barre.position - sens * 50 * 2)
	end)
	f.barre = barre
	return f
end

-- le texte : 310 avec la barre ; sans elle, jusqu'au bord droit qu'avait la
-- barre (44 + 324,5 = 368,5), comme la zone
local TEXTE_L, TEXTE_SANS, VUE = 310, 324.5, 260 - 14 - 15

-- lignes : { "espace" } | { "titre", texte } | { "texte", texte }
local function remplir(f, lignes)
	for _, fs in ipairs(f.lignes) do
		fs:Hide()
	end
	-- une passe a une largeur donnee : rend la hauteur du contenu
	local function disposer(largeur)
		local y, n = 0, 0
		for i, l in ipairs(lignes) do
			if i > 1 then
				y = y + 10
			end
			if l[1] == "espace" then
				y = y + 14
			else
				n = n + 1
				local fs = f.lignes[n]
				if not fs then
					fs = f.contenu:CreateFontString(nil, "ARTWORK")
					fs:SetJustifyH("LEFT")
					f.lignes[n] = fs
				end
				fs:SetWidth(largeur)
				if l[1] == "titre" then
					fs:SetFontObject(G.Police("GameFontNormalLarge2"))
					fs:SetTextColor(1, 1, 1)
				else
					fs:SetFontObject(G.Police("GameFontNormalLarge"))
					fs:SetTextColor(1, 0.82, 0)
				end
				fs:SetText(l[2] or "")
				fs:ClearAllPoints()
				fs:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
				fs:Show()
				y = y + fs:GetHeight()
			end
		end
		f.contenu:SetWidth(largeur)
		return y
	end
	-- sans barre d'abord ; si le texte deborde, avec (plus etroit, il deborde
	-- encore : la barre reste)
	local y = disposer(TEXTE_SANS)
	if y > VUE then
		y = disposer(TEXTE_L)
	end
	f.contenu:SetHeight(math.max(1, y))
	f.barre:Regler(y, VUE, 0)
	f.zone:SetVerticalScroll(0)
end

local encadreFaction = encadre("ForeverUICharacterCreateFactionDetails", 1)
local encadreRace = encadre("ForeverUICharacterCreateRaceDetails", 2)
local encadreClasse = encadre("ForeverUICharacterCreateClassDetails", 3)
local ENCADRES = { encadreFaction, encadreRace, encadreClasse }

-- ------------------------------------------------------------ la lecture du client

local function lireRaces()
	local t = { GetAvailableRaces() }
	local races = {}
	for i = 1, #t, 3 do
		local n = (i + 2) / 3
		local client = _G["CharacterCreateRaceButton" .. n]
		local _, faction = GetFactionForRace(n)
		races[n] = {
			index = n, nom = t[i], fichier = string.upper(t[i + 1] or ""), faction = faction,
			permis = client and client.enable and actif(client),
		}
	end
	return races
end

local function lireClasses()
	local t = { GetAvailableClasses() }
	local liste = {}
	for i = 1, #t, 3 do
		local n = (i + 2) / 3
		local client = _G["CharacterCreateClassButton" .. n]
		table.insert(liste, {
			index = n, nom = t[i], fichier = string.upper(t[i + 1] or ""),
			permis = client and client.enable and actif(client),
		})
	end
	table.sort(liste, function(a, b)
		return (ORDRE_CLASSE[a.fichier] or 99) < (ORDRE_CLASSE[b.fichier] or 99)
	end)
	return liste
end

local function mettreAJour()
	if not CharacterCreate:IsShown() then
		return
	end
	local choixRace = GetSelectedRace()
	local _, fichierClasse, choixClasse = GetSelectedClass()
	local choixSexe = GetSelectedSex()
	local races = lireRaces()

	-- les races, par faction, dans l'ordre du client
	local compte = { Alliance = 0, Horde = 0 }
	local raceChoisie
	for _, r in ipairs(races) do
		local col = COLONNES[r.faction]
		if col then
			compte[r.faction] = compte[r.faction] + 1
			local b = boutonRace(col, compte[r.faction])
			b.index = r.index
			iconeFichier(b, ART .. "bouton-raceicon128-" .. (FICHIER_RACE[r.fichier] or "human") .. "-" .. sexe(), r.faction == "Horde")
			b:Etat(r.index == choixRace, r.permis)
			b:Show()
		end
		if r.index == choixRace then
			raceChoisie = r
		end
	end
	for faction, col in pairs(COLONNES) do
		for i = compte[faction] + 1, #col.boutons do
			col.boutons[i]:Hide()
		end
		rangerRaces(col, compte[faction])
	end

	-- les corps
	for _, b in ipairs(boutonsCorps) do
		local nomSexe = (b.sexe == SEX_FEMALE) and "female" or "male"
		local choisi = (b.sexe == choixSexe)
		G.PoserAtlas(b.icone, "charactercreate-gendericon-" .. nomSexe .. (choisi and "-selected" or ""))
		G.PoserAtlas(b.voile, "charactercreate-gendericon-" .. nomSexe)
		b:Etat(choisi, true)
	end

	-- les classes
	local liste = lireClasses()
	for i, c in ipairs(liste) do
		local b = boutonClasse(i)
		b.index = c.index
		iconeFichier(b, ART .. "bouton-classicon-" .. string.lower(c.fichier))
		b:Etat(c.index == choixClasse, c.permis)
		b.nom:SetFontObject(G.Police(c.permis and "GameFontNormalMed2" or "GameFontDisableMed2"))
		b.nom:SetText(c.nom)
		b:Show()
	end
	for i = #liste + 1, #boutonsClasse do
		boutonsClasse[i]:Hide()
	end
	rangerClasses(#liste)

	-- les encadres
	if raceChoisie then
		local faction = raceChoisie.faction
		encadreFaction.portrait:SetTexture(ART .. "portrait-charactercreate-icon-" .. string.lower(faction or "alliance") .. "bg")
		remplir(encadreFaction, { { "espace" }, { "titre", TEXTE.FACTION[faction] }, { "texte", TEXTE.LORE[faction] }, { "espace" } })

		encadreRace.portrait:SetTexture(ART .. "portrait-raceicon128-" .. (FICHIER_RACE[raceChoisie.fichier] or "human") .. "-" .. sexe())
		local lignes = { { "espace" }, { "titre", raceChoisie.nom }, { "texte", TEXTE.RACIAL_TRAITS } }
		local i = 1
		while _G["ABILITY_INFO_" .. raceChoisie.fichier .. i] do
			table.insert(lignes, { "texte", _G["ABILITY_INFO_" .. raceChoisie.fichier .. i] })
			i = i + 1
		end
		table.insert(lignes, { "texte", GetFlavorText("RACE_INFO_" .. raceChoisie.fichier, choixSexe) })
		table.insert(lignes, { "espace" })
		remplir(encadreRace, lignes)
	end
	if fichierClasse then
		local classeNom = GetSelectedClass()
		-- SetPortraitToClassIcon : UI-Classes-Circles et CLASS_ICON_TCOORDS
		encadreClasse.portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
		local c = CLASS_ICON_TCOORDS[string.upper(fichierClasse)]
		if c then
			encadreClasse.portrait:SetTexCoord(c[1], c[2], c[3], c[4])
		end
		remplir(encadreClasse, { { "espace" }, { "titre", classeNom }, { "texte", GetFlavorText("CLASS_" .. string.upper(fichierClasse), choixSexe) }, { "espace" } })
	end

	-- UpdateBackgroundOverlays
	local a = ALPHA_FOND.classe[string.upper(fichierClasse or "")]
		or (raceChoisie and ALPHA_FOND.faction[raceChoisie.faction]) or 1
	etat.alphaFond = a
	for _, t in ipairs(fonds) do
		t:SetAlpha(a)
	end
	if etat.mode == 2 then
		fondBas:SetAlpha(0)
	end
end

-- ------------------------------------------------------------ la personnalisation

local perso = CreateFrame("Frame", nil, racine)
perso:SetAllPoints(racine)

-- CustomizeOptionsContainerFrame
local conteneur = CreateFrame("Frame", nil, perso)
conteneur:SetFrameLevel(perso:GetFrameLevel() + 4)
conteneur:EnableMouse(true)
conteneur:SetPoint("TOPRIGHT", perso, "TOPRIGHT", 0, -137)
local dimensionnerConteneur = cadreBronze(conteneur, { { "heavybronze-vert-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-vert-cornerbracket-br", "BOTTOMRIGHT" } })

-- infobulle ANCHOR_LEFT (9, -9) des petits boutons
local function infobulleGauche(b, texte)
	b:SetScript("OnEnter", function(self)
		GlueTooltip_SetOwner(self, nil, 9, -9, "BOTTOMRIGHT", "TOPLEFT")
		GlueTooltip_SetText(texte, nil, 1.0, 1.0, 1.0)
	end)
	b:SetScript("OnLeave", function() GlueTooltip:Hide() end)
end

-- RandomizeAppearanceButton
local hasardApparence = CreateFrame("Button", "ForeverUICharacterCreateRandomizeButton", conteneur)
G.BoutonCarreIcone(hasardApparence, "charactercreate-icon-dice", 24, "OVERLAY")
hasardApparence:SetPoint("TOPLEFT", conteneur, "TOPLEFT", 12, -12)
local actualiserReglages
hasardApparence:SetScript("OnClick", function()
	CharacterCreate_Randomize()
	actualiserReglages()
end)
infobulleGauche(hasardApparence, TEXTE.RANDOMIZE_APPEARANCE)

-- CharacterCustomizeOptions
-- ECART voulu (27/09) : 46 entre les lignes au lieu des 48 de camelot, le
-- panneau gardant la hauteur de camelot : le bas du cadre respire davantage
local LIGNE_L, LIGNE_H, LIGNE_ECART, ECART_CAMELOT = 265, 38, 46, 48
local reglages = CreateFrame("Frame", nil, conteneur)
reglages:SetWidth(300)
reglages:SetHeight(5 * LIGNE_H + 4 * LIGNE_ECART)
reglages:SetPoint("TOPRIGHT", conteneur, "TOPRIGHT", -10, -80)
dimensionnerConteneur(360, 80 + 5 * LIGNE_H + 4 * ECART_CAMELOT + 20)

-- WowStyle2IconButton : fond selon l'etat, icone decalee enfoncee
local function flecheReglage(parent, sens, action)
	local b = CreateFrame("Button", nil, parent)
	b:SetScale(1.7)
	b:SetWidth(26)
	b:SetHeight(25)
	b.fond = b:CreateTexture(nil, "BACKGROUND")
	b.fond:SetPoint("CENTER", b, "CENTER")
	b.icone = b:CreateTexture(nil, "OVERLAY")
	local function peindre()
		local fond = "common-dropdown-c-button"
		if b.bas and b.dessus then
			fond = "common-dropdown-c-button-pressedhover-2"
		elseif b.dessus then
			fond = "common-dropdown-c-button-hover-2"
		elseif b.bas then
			fond = "common-dropdown-c-button-pressed-2"
		end
		G.PoserAtlas(b.fond, fond, true)
		G.PoserAtlas(b.icone, "common-dropdown-icon-" .. sens, true)
		b.icone:ClearAllPoints()
		b.icone:SetPoint("CENTER", b, "CENTER", b.bas and 2 or 0, b.bas and -1 or 0)
	end
	b:SetScript("OnEnter", function() b.dessus = true; peindre() end)
	b:SetScript("OnLeave", function() b.dessus = false; peindre() end)
	b:SetScript("OnMouseDown", function() b.bas = true; peindre() end)
	b:SetScript("OnMouseUp", function() b.bas = false; peindre() end)
	b:SetScript("OnClick", action)
	peindre()
	return b
end

-- une ligne : [<] [case] [>] (DropdownWithSteppersLargeTemplate)
local lignes = {}
for i = 1, 5 do
	local ligne = CreateFrame("Frame", nil, reglages)
	ligne.i = i
	ligne:SetWidth(LIGNE_L)
	ligne:SetHeight(LIGNE_H)
	ligne:SetPoint("TOPLEFT", reglages, "TOPLEFT", 0, -(i - 1) * (LIGNE_H + LIGNE_ECART))
	local case = CreateFrame("Frame", nil, ligne)
	case:SetScale(1.55)
	case:SetWidth(122)
	case:SetHeight(25)
	case:SetPoint("CENTER", ligne, "CENTER")
	local fond = G.AtlasEtire(case, "common-dropdown-c-button", "BACKGROUND")
	fond.rect:SetPoint("TOPLEFT", case, "TOPLEFT", -7, 7)
	fond.rect:SetPoint("BOTTOMRIGHT", case, "BOTTOMRIGHT", 7, -7)
	ligne.case, ligne.fond = case, fond
	ligne.texte = case:CreateFontString(nil, "OVERLAY")
	ligne.texte:SetFontObject(G.Police("GameFontNormal"))
	ligne.texte:SetTextColor(1, 0.82, 0)
	ligne.texte:SetJustifyH("CENTER")
	ligne.texte:SetHeight(20)
	ligne.texte:SetPoint("LEFT", case, "LEFT", 13, 0)
	ligne.texte:SetPoint("RIGHT", case, "RIGHT", -13, 0)
	local moins = flecheReglage(ligne, "back", function()
		CharacterCustomization_Left(i)
		actualiserReglages(i)
	end)
	moins:SetPoint("RIGHT", case, "LEFT", -5, 0)
	local plus = flecheReglage(ligne, "next", function()
		CharacterCustomization_Right(i)
		actualiserReglages(i)
	end)
	plus:SetPoint("LEFT", case, "RIGHT", 4, 0)
	-- mode 2 : le nom au-dessus de la ligne (Label de
	-- DropdownWithSteppersAndLabelLargeTemplate), le numero dans la case
	-- (SelectionNumber, 25 x 20, au centre de SelectionDetails), la fleche de
	-- survol (12 x 5 a BOTTOM, -5) et la case qui ouvre la liste
	ligne.titre = ligne:CreateFontString(nil, "ARTWORK")
	ligne.titre:SetFontObject(G.Police("SystemFont_Shadow_Large"))
	ligne.titre:SetPoint("BOTTOMLEFT", moins, "TOPLEFT", 2, 4)
	ligne.numero = case:CreateFontString(nil, "OVERLAY")
	ligne.numero:SetFontObject(G.Police("GameFontNormal"))
	ligne.numero:SetTextColor(1, 0.82, 0)
	ligne.numero:SetJustifyH("LEFT")
	ligne.numero:SetWidth(25)
	ligne.numero:SetHeight(20)
	ligne.numero:SetPoint("CENTER", case, "CENTER")
	-- ColorSwatch1 et sa lueur (ColorSwatch1Glow, ADD) : dans la case,
	-- l'echantillon remplace le numero (hideNumber), au centre
	ligne.echantillon = case:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(ligne.echantillon, "charactercreate-customize-palette", true)
	ligne.echantillon:SetPoint("CENTER", case, "CENTER")
	ligne.echantillon:Hide()
	ligne.lueur = case:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(ligne.lueur, "charactercreate-customize-palette-glow", true)
	ligne.lueur:SetBlendMode("ADD")
	ligne.lueur:SetPoint("CENTER", ligne.echantillon, "CENTER")
	ligne.lueur:Hide()
	ligne.fleche = case:CreateTexture(nil, "OVERLAY")
	G.PoserAtlas(ligne.fleche, "common-dropdown-c-button-hover-arrow")
	ligne.fleche:SetWidth(12)
	ligne.fleche:SetHeight(5)
	ligne.fleche:SetPoint("BOTTOM", case, "BOTTOM", 0, -5)
	ligne.fleche:Hide()
	ligne.bouton = CreateFrame("Button", nil, case)
	ligne.bouton:SetAllPoints(case)
	ligne.bouton:EnableMouseWheel(true)
	ligne.bouton:Hide()
	lignes[i] = ligne
end

-- ------------------------------------------------------------ mode 2 : les choix

-- Un client patche (tools/patcheur, ForeverUIPatcher) fait rendre a
-- CycleCharCustomization(reglage, decalage) l'indice du reglage ; un
-- decalage de 0 ne change rien. Le numero est le rang du choix parmi les
-- choix valides, le plus petit indice valide etant 1. Client non patche (ou
-- objet d'apparence pas encore cree) : aucun nombre, mode 1.
-- LES CHOIX VALIDES SE CALCULENT (calculer) sur les donnees du client
-- (ForeverUIGlueChoix.lua), aux regles du moteur que reprend
-- tools/choix_personnalisation.py. Les faire recenser au moteur, cran par
-- cran, redessinait le personnage a chaque cran : les visages defilaient en
-- changeant la peau et les FPS chutaient (constate le 2026-09-27). Le moteur
-- ne recense plus qu'en secours (lister), si sa valeur manque a la liste
-- calculee.
local listes = {}

local function indice(i)
	local v = CycleCharCustomization(i, 0)
	if type(v) == "number" then
		return v
	end
end

local function rang(liste, v)
	for k, x in ipairs(liste) do
		if x == v then
			return k
		end
	end
end

-- le tour complet d'un reglage : il s'arrete au retour sur le choix de
-- depart, le reglage est alors revenu ou il etait
local function lister(i)
	local depart = indice(i)
	if not depart then
		return nil
	end
	local tour, place = { depart }, { [depart] = 1 }
	for _ = 1, 255 do
		local v = CycleCharCustomization(i, 1)
		if type(v) ~= "number" or v == depart then
			break
		end
		if place[v] then
			-- depart hors du cycle (ne devrait pas arriver) : le cycle seul
			local cycle = {}
			for k = place[v], #tour do
				cycle[#cycle + 1] = tour[k]
			end
			tour = cycle
			break
		end
		tour[#tour + 1] = v
		place[v] = #tour
	end
	-- dans l'ordre du moteur, a partir du plus petit indice
	local premier = 1
	for k = 2, #tour do
		if tour[k] < tour[premier] then
			premier = k
		end
	end
	local liste = {}
	for k = 0, #tour - 1 do
		liste[#liste + 1] = tour[(premier - 1 + k) % #tour + 1]
	end
	return liste
end

-- les choix valides d'un reglage, calcules : les cases [section][variation]
-- [couleur] de CharSections (section 0 peau, 1 visage, 2 pilosite, 3
-- cheveux, 4 sous-vetements) et les regles du moteur (Wow.exe 0x4EB150,
-- 0x4EB710, 0x4F0490, 0x4EB500, 0x4EBCA0), en ordre croissant comme le
-- moteur les parcourt
local function calculer(i)
	local race = G.choix and lireRaces()[GetSelectedRace()]
	local d = race and G.choix[race.fichier]
	d = d and d[(GetSelectedSex() == SEX_FEMALE) and 1 or 0]
	if not d then
		return nil
	end
	-- drapeaux : un poids pour les classes, un autre pour le chevalier de la mort
	local _, classe = GetSelectedClass()
	local poids = (classe == "DEATHKNIGHT") and 2 or 1
	local function nb(section, var)
		local s = var and d[section][var]
		return s and string.len(s) or 0
	end
	local function bonne(section, var, col)
		local s = var and d[section][var]
		local c = s and string.byte(s, col + 1)
		c = c and c - 48                -- "0".."3" ; "." (pas de ligne) < 0
		return c ~= nil and c >= 0 and math.floor(c / poids) % 2 == 1
	end
	local function uneCouleur(section, var, test)
		for c = 0, nb(section, var) - 1 do
			if test(c) then
				return true
			end
		end
		return false
	end
	local liste = {}
	if i == 1 then
		-- peau : avec le visage courant et les sous-vetements
		local visage = indice(2)
		for c = 0, nb(0, 0) - 1 do
			if bonne(0, 0, c) and bonne(1, visage, c) and bonne(4, 0, c) then
				liste[#liste + 1] = c
			end
		end
	elseif i == 2 then
		-- visage : une couleur de peau au moins lui convient
		for v = 0, d[1].n - 1 do
			if uneCouleur(1, v, function(c) return bonne(1, v, c) and bonne(0, 0, c) and bonne(4, 0, c) end) then
				liste[#liste + 1] = v
			end
		end
	elseif i == 3 then
		-- coiffure : une couleur au moins
		for s = 0, d[3].n - 1 do
			if uneCouleur(3, s, function(c) return bonne(3, s, c) end) then
				liste[#liste + 1] = s
			end
		end
	elseif i == 4 then
		-- couleur des cheveux : celles de la coiffure courante
		local coiffure = indice(3)
		for c = 0, nb(3, coiffure) - 1 do
			if bonne(3, coiffure, c) then
				liste[#liste + 1] = c
			end
		end
	else
		-- pilosite : si la case (pilosite, couleur des cheveux) existe, les
		-- styles qui ont une couleur au moins ; sinon tous les styles
		local poil, couleur = indice(5), indice(4)
		if poil and couleur and poil < d[2].n and couleur < nb(2, poil) then
			for v = 0, d[2].n - 1 do
				if uneCouleur(2, v, function(c) return bonne(2, v, c) end) then
					liste[#liste + 1] = v
				end
			end
		else
			for v = 0, (d.barbes or 0) - 1 do
				liste[#liste + 1] = v
			end
		end
	end
	return liste
end

-- amener un reglage sur un choix par le plus court chemin
local function allerA(i, cible)
	local liste = listes[i]
	if not liste then
		return
	end
	local n, p, q = #liste, rang(liste, indice(i)), rang(liste, cible)
	if not p or not q then
		return
	end
	local avant, arriere = (q - p) % n, (p - q) % n
	if avant <= arriere then
		for _ = 1, avant do
			CycleCharCustomization(i, 1)
		end
	else
		for _ = 1, arriere do
			CycleCharCustomization(i, -1)
		end
	end
end

-- La couleur d'un choix (ColorSwatch1 : swatchColor1 du choix chez
-- camelot) : celle que tools/couleurs_personnalisation.py a lue dans la
-- texture du choix (ForeverUIGlueCouleurs.lua). Peau (1) et couleur des
-- cheveux (4) ; les autres reglages n'en ont pas, comme chez camelot.
local ECHANTILLONS = { [1] = "peau", [4] = "cheveux" }

-- LA LUMIERE DU DECOR. Chaque decor eclaire le personnage de ses lumieres
-- (RaceLights du client, que pose SetLighting) : celui du chevalier de la
-- mort n'a qu'une ambiante bleu-cyan, ou une peau pale parait bleutee ;
-- celui de l'orc, une directionnelle orangee qui fait virer le cyan au vert.
-- Sans elle, la teinte de l'echantillon de peau ne correspondait pas au
-- personnage (constate le 2026-09-27, surtout en chevalier de la mort).
-- Teinte : ambiante entiere, directionnelle a moitie (un corps n'en recoit
-- qu'une part), ramenee a 1 sur sa plus forte composante.
local PART_DIRECTIONNELLE = 0.5
local function teinteDuDecor()
	local nom = GetCreateBackgroundModel and GetCreateBackgroundModel()
	local lumieres = nom and RaceLights and RaceLights[string.upper(nom)]
	if not lumieres then
		return nil
	end
	local r, g, b = 0, 0, 0
	for _, l in ipairs(lumieres) do
		-- { allumee, omni, direction x3, ambiante (intensite, r, g, b),
		--   directionnelle (intensite, r, g, b) }
		if l[1] == 1 then
			r = r + l[6] * l[7] + l[10] * l[11] * PART_DIRECTIONNELLE
			g = g + l[6] * l[8] + l[10] * l[12] * PART_DIRECTIONNELLE
			b = b + l[6] * l[9] + l[10] * l[13] * PART_DIRECTIONNELLE
		end
	end
	local m = math.max(r, g, b)
	if m <= 0 then
		return nil
	end
	return r / m, g / m, b / m
end

local function couleurDe(i, v)
	local genre = ECHANTILLONS[i]
	local race = genre and v and G.couleurs and lireRaces()[GetSelectedRace()]
	local t = race and G.couleurs[race.fichier]
	t = t and t[(GetSelectedSex() == SEX_FEMALE) and 1 or 0]
	t = t and t[genre]
	local c = t and t[v]
	if c and genre == "peau" then
		local r, g, b = teinteDuDecor()
		if r then
			return { c[1] * r, c[2] * g, c[3] * b }
		end
	end
	return c
end

-- ------------------------------------------------------------ mode 2 : la liste ouverte

-- MenuStyle2 : fond common-dropdown-c-bg de (-17, 12) a (17, -22), marges
-- 3 / 6 / 3 / 7, a l'echelle de la case, TOPRIGHT sur son BOTTOMRIGHT ; grille
-- verticale, 1 colonne jusqu'a 10 choix, 2 jusqu'a 24, 3 jusqu'a 36, 4
-- au-dela, et plus de colonnes si la liste descendrait a moins de 100 du bas ;
-- elements de 20 (DarkMenuElement : details a 14 du bord, 116 de large sur
-- une colonne, 42 sur plusieurs, plus 14) ; survol : common-dropdown-
-- customize-mouseover a 0,15 et apercu du choix sur le personnage ; choix en
-- cours dore, les autres gris ; un clic choisit et referme.
local menu = CreateFrame("Frame", "ForeverUICharacterCreateChoiceMenu", perso)
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:SetFrameLevel(20)
menu:SetScale(1.55)
menu:EnableMouse(true)
menu:Hide()
local fondMenu = G.AtlasEtire(menu, "common-dropdown-c-bg", "BACKGROUND")
fondMenu.rect:SetPoint("TOPLEFT", menu, "TOPLEFT", -17, 12)
fondMenu.rect:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 17, -22)
-- un clic hors de la liste la referme sans rien choisir
local capteur = CreateFrame("Button", nil, perso)
capteur:SetFrameStrata("FULLSCREEN_DIALOG")
capteur:SetFrameLevel(10)
capteur:SetAllPoints(GlueParent)
capteur:Hide()

local ouvert        -- { ligne, choisi } tant qu'une liste est ouverte
local entrees = {}
local peindreCase

-- ECART voulu (27/09) : camelot montre l'apercu des le survol d'une ligne ;
-- ici apres un arret de APERCU_DELAI sur elle. Chaque apercu fait
-- recomposer au moteur les textures du personnage, ce qui gele en haute
-- definition : balayer la liste n'en declenche ainsi qu'un.
-- LE TEMPS COMPTE. Un apercu gele le moteur, et l'image d'apres recoit le
-- gel entier comme temps ecoule : compte tel quel, il vidait d'un coup le
-- delai de la ligne suivante, et chaque gel relancait un apercu (constate le
-- 2026-09-27). L'image du survol ne compte donc pas, et une image ne compte
-- jamais plus de APERCU_PAS_MAX.
local APERCU_DELAI = 0.1
local APERCU_PAS_MAX = 0.05
local apercu        -- { k, attente, neuf } : la ligne survolee, pas encore montree
menu:SetScript("OnUpdate", function(_, ecoule)
	if not apercu then
		return
	end
	if apercu.neuf then
		apercu.neuf = false
		return
	end
	apercu.attente = apercu.attente - math.min(ecoule, APERCU_PAS_MAX)
	if apercu.attente <= 0 then
		local k = apercu.k
		apercu = nil
		if ouvert then
			allerA(ouvert.ligne.i, listes[ouvert.ligne.i][k])
		end
	end
end)

local function oublierMenu()
	ouvert = nil
	apercu = nil
	menu:Hide()
	capteur:Hide()
end

-- garder : le choix survole est retenu ; sinon retour au choix en cours
local function fermerMenu(garder)
	local o = ouvert
	if not o then
		return
	end
	oublierMenu()
	if garder then
		actualiserReglages(o.ligne.i)
	else
		allerA(o.ligne.i, o.choisi)
		peindreCase(o.ligne)
	end
end
capteur:SetScript("OnClick", function() fermerMenu(false) end)

local function entree(k)
	if entrees[k] then
		return entrees[k]
	end
	local e = CreateFrame("Button", nil, menu)
	e:SetHeight(20)
	e.survol = G.AtlasEtire(e, "common-dropdown-customize-mouseover", "BACKGROUND")
	e.survol.rect:SetAllPoints(e)
	e.survol.rect:SetAlpha(0.15)
	for _, t in ipairs(e.survol.pieces) do
		t:SetAlpha(0.15)
	end
	e.survol:Montrer(false)
	e.numero = e:CreateFontString(nil, "OVERLAY")
	e.numero:SetFontObject(G.Police("GameFontNormal"))
	e.numero:SetJustifyH("LEFT")
	e.numero:SetWidth(25)
	e.numero:SetHeight(20)
	e.numero:SetPoint("TOPLEFT", e, "TOPLEFT", 14, 0)
	-- ColorSwatch1 a droite du numero, sa lueur, et ColorSelected (le
	-- choix en cours) a 4 a gauche de l'echantillon
	e.echantillon = e:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(e.echantillon, "charactercreate-customize-palette", true)
	e.echantillon:SetPoint("LEFT", e.numero, "RIGHT", 0, 0)
	e.lueur = e:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(e.lueur, "charactercreate-customize-palette-glow", true)
	e.lueur:SetBlendMode("ADD")
	e.lueur:SetPoint("CENTER", e.echantillon, "CENTER")
	e.choisi = e:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(e.choisi, "charactercreate-customize-palette-selected", true)
	e.choisi:SetPoint("LEFT", e.echantillon, "LEFT", -4, 0)
	e:SetScript("OnEnter", function(self)
		self.survol:Montrer(true)
		if ouvert then
			apercu = { k = self.k, attente = APERCU_DELAI, neuf = true }
		end
	end)
	e:SetScript("OnLeave", function(self)
		self.survol:Montrer(false)
		if apercu and apercu.k == self.k then
			apercu = nil
		end
	end)
	e:SetScript("OnClick", function(self)
		if ouvert then
			apercu = nil
			PlaySound("gsCharacterCreationLook")
			allerA(ouvert.ligne.i, listes[ouvert.ligne.i][self.k])
			fermerMenu(true)
		end
	end)
	entrees[k] = e
	return e
end

local function ouvrirMenu(ligne)
	local liste = listes[ligne.i]
	if not liste then
		return
	end
	local n = #liste
	local choisi = rang(liste, indice(ligne.i)) or 1
	local colonnes = (n > 36 and 4) or (n > 24 and 3) or (n > 10 and 2) or 1
	local rangees = math.ceil(n / colonnes)
	-- compactionMargin : le haut de la liste est le bas de la case
	local haut = ligne.case:GetBottom()
	if haut then
		local maxi = math.max(1, math.floor((haut - 100) / 20))
		if rangees > maxi then
			colonnes = math.ceil(n / maxi)
			rangees = math.ceil(n / colonnes)
		end
	end
	-- AdjustWidth : sur plusieurs colonnes, numero (25) + ColorSwatch2 (36)
	-- + 18 quand les choix ont une couleur, 42 sinon
	local couleurs = couleurDe(ligne.i, liste[1]) and true
	local details = 116
	if colonnes > 1 then
		details = couleurs and (25 + 36 + 18) or 42
	end
	local largeur = 14 + details + 14
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", ligne.case, "BOTTOMRIGHT")
	menu:SetWidth(3 + colonnes * largeur + 3)
	menu:SetHeight(6 + rangees * 20 + 7)
	for k = 1, n do
		local e = entree(k)
		e.k = k
		e:SetWidth(largeur)
		e:ClearAllPoints()
		e:SetPoint("TOPLEFT", menu, "TOPLEFT", 3 + math.floor((k - 1) / rangees) * largeur, -(6 + ((k - 1) % rangees) * 20))
		e.numero:SetText(k)
		if k == choisi then
			e.numero:SetTextColor(1, 0.82, 0)
		else
			e.numero:SetTextColor(0.5, 0.5, 0.5)
		end
		e.survol:Montrer(false)
		local couleur = couleurDe(ligne.i, liste[k])
		if couleur then
			e.echantillon:SetVertexColor(couleur[1], couleur[2], couleur[3])
		end
		G.Montrer(e.echantillon, couleur)
		G.Montrer(e.lueur, couleur)
		G.Montrer(e.choisi, couleur and k == choisi)
		e:Show()
	end
	for k = n + 1, #entrees do
		entrees[k]:Hide()
	end
	ouvert = { ligne = ligne, choisi = liste[choisi] }
	menu:Show()
	capteur:Show()
	peindreCase(ligne)
end

-- WowStyle2Dropdown : fond selon l'etat (enfonce, survole, ouvert), fleche
-- au survol, details decales de (1, -1) enfonces
peindreCase = function(ligne)
	local b = ligne.bouton
	local nom = "common-dropdown-c-button"
	if b.bas and b.dessus then
		nom = "common-dropdown-c-button-pressedhover-1"
	elseif b.bas then
		nom = "common-dropdown-c-button-pressed-1"
	elseif b.dessus then
		nom = "common-dropdown-c-button-hover-1"
	elseif ouvert and ouvert.ligne == ligne then
		nom = "common-dropdown-c-button-open"
	end
	ligne.fond:Poser(nom)
	G.Montrer(ligne.fleche, b.dessus)
	local dx, dy = b.bas and 1 or 0, b.bas and -1 or 0
	ligne.numero:ClearAllPoints()
	ligne.numero:SetPoint("CENTER", ligne.case, "CENTER", dx, dy)
	ligne.echantillon:ClearAllPoints()
	ligne.echantillon:SetPoint("CENTER", ligne.case, "CENTER", dx, dy)
end

for _, ligne in ipairs(lignes) do
	local b, i = ligne.bouton, ligne.i
	b:SetScript("OnEnter", function(self) self.dessus = true; peindreCase(ligne) end)
	b:SetScript("OnLeave", function(self) self.dessus = nil; peindreCase(ligne) end)
	b:SetScript("OnMouseDown", function(self) self.bas = true; peindreCase(ligne) end)
	b:SetScript("OnMouseUp", function(self) self.bas = nil; peindreCase(ligne) end)
	b:SetScript("OnHide", function(self) self.dessus, self.bas = nil, nil end)
	b:SetScript("OnClick", function()
		if ouvert and ouvert.ligne == ligne then
			fermerMenu(false)
		else
			fermerMenu(false)
			ouvrirMenu(ligne)
		end
	end)
	-- la molette sur la case : vers le bas le choix suivant
	b:SetScript("OnMouseWheel", function(_, sens)
		fermerMenu(false)
		if sens < 0 then
			CharacterCustomization_Right(i)
		else
			CharacterCustomization_Left(i)
		end
		actualiserReglages(i)
	end)
end

-- les noms des reglages : ceux du client (CharacterCreate_OnLoad et
-- CharacterCreate_UpdateHairCustomization) ; en mode 2, le numero du choix.
-- Les listes se recalculent toutes a chaque fois : sans le moteur, c'est
-- immediat.
actualiserReglages = function()
	local cheveux, poils = GetHairCustomization(), GetFacialHairCustomization()
	local noms = {
		CHAR_CUSTOMIZATION1_DESC, CHAR_CUSTOMIZATION2_DESC,
		_G["HAIR_" .. cheveux .. "_STYLE"], _G["HAIR_" .. cheveux .. "_COLOR"],
		_G["FACIAL_HAIR_" .. poils],
	}
	for i, ligne in ipairs(lignes) do
		local v = indice(i)
		if not v then
			listes[i] = nil
		else
			listes[i] = calculer(i)
			-- secours : la valeur du moteur manque a la liste calculee
			if not (listes[i] and rang(listes[i], v)) then
				listes[i] = lister(i)
			end
		end
		local position = v and listes[i] and rang(listes[i], v)
		local couleur = position and couleurDe(i, v)
		if couleur then
			ligne.echantillon:SetVertexColor(couleur[1], couleur[2], couleur[3])
		end
		G.Montrer(ligne.echantillon, couleur)
		G.Montrer(ligne.lueur, couleur)
		if position then
			ligne.titre:SetText(noms[i] or "")
			ligne.numero:SetText(position)
			ligne.texte:Hide()
			ligne.titre:Show()
			G.Montrer(ligne.numero, not couleur)
			ligne.bouton:Show()
		else
			ligne.texte:SetText(noms[i] or "")
			ligne.texte:Show()
			ligne.titre:Hide()
			ligne.numero:Hide()
			ligne.bouton:Hide()
		end
		peindreCase(ligne)
	end
end

-- NameChoiceFrame
local choixNom = CreateFrame("Frame", "ForeverUICharacterCreateNameChoice", perso)
choixNom:SetFrameLevel(perso:GetFrameLevel() + 4)
-- ECART voulu (27/09) : en BAS de l'ecran (camelot : en haut) et retourne
-- en miroir -- equerres en bas, titre sous le champ, de et champ remontes
choixNom:SetPoint("BOTTOM", perso, "BOTTOM", 0, 0)
local dimensionnerNom = cadreBronze(choixNom, { { "heavybronze-horz-cornerbracket-br", "BOTTOMRIGHT" }, { "heavybronze-horz-cornerbracket-bl", "BOTTOMLEFT" } })
-- ECART voulu (27/09) : les 800 de camelot logent le nom et le nom de
-- famille ; 3.3.5 n'a que le nom : 10 + 48 (de) + 343 (champ) + 48 + 10, le
-- champ centre sous le titre
dimensionnerNom(10 + 48 + 343 + 48 + 10, 90)
local titreNom = choixNom:CreateFontString(nil, "ARTWORK")
titreNom:SetFontObject(G.Police("GameFontHighlightLarge2"))
titreNom:SetPoint("BOTTOM", choixNom, "BOTTOM", 0, 16)
titreNom:SetText(NAME)

-- RandomNameButton : le nom au hasard du client, quand il le permet
local hasardNom = CreateFrame("Button", "ForeverUICharacterCreateRandomNameButton", choixNom)
G.BoutonCarreIcone(hasardNom, "charactercreate-icon-dice", 24, "OVERLAY")
hasardNom:SetPoint("LEFT", choixNom, "LEFT", 10, 10)
hasardNom:SetScript("OnClick", function()
	CharacterCreateNameEdit:SetText(GetRandomName())
	PlaySound("gsCharacterCreationLook")
end)
infobulleGauche(hasardNom, RANDOMIZE)

-- le champ du client, habille en SharedEditBoxTemplate et pose dans le cadre
-- (ancre, sans changer de parent)
local champNom = CharacterCreateNameEdit
champNom:SetBackdrop(nil)
-- seule l'etiquette « Name » du client s'efface : GetRegions rend aussi le
-- texte meme du champ
for _, r in ipairs({ champNom:GetRegions() }) do
	if r:GetObjectType() == "FontString" and r:GetText() == NAME then
		r:SetAlpha(0)
		r:Hide()
	end
end
local bordG = champNom:CreateTexture(nil, "BACKGROUND")
G.PoserAtlas(bordG, "common-gray-button-entrybox-left", true)
bordG:SetPoint("LEFT", champNom, "LEFT")
local bordD = champNom:CreateTexture(nil, "BACKGROUND")
G.PoserAtlas(bordD, "common-gray-button-entrybox-right", true)
bordD:SetPoint("RIGHT", champNom, "RIGHT")
local bordM = champNom:CreateTexture(nil, "BACKGROUND")
G.PoserAtlas(bordM, "common-gray-button-entrybox-center")
bordM:SetPoint("TOPLEFT", bordG, "TOPRIGHT")
bordM:SetPoint("BOTTOMRIGHT", bordD, "BOTTOMLEFT")
champNom:SetWidth(343)
champNom:SetHeight(48)
champNom:SetFontObject(G.Police("NumberFont_Shadow_Large"))
champNom:SetJustifyH("CENTER")
champNom:SetTextInsets(0, 0, 0, 0)
champNom:SetFrameLevel(choixNom:GetFrameLevel() + 2)
champNom:ClearAllPoints()
champNom:SetPoint("LEFT", hasardNom, "RIGHT", 0, 0)
-- CharacterCreateEditBoxMixin : Echap recule, Entree avance
champNom:SetScript("OnEscapePressed", function() retour:Click() end)
champNom:SetScript("OnEnterPressed", function() avancer:Click() end)

-- SmallButtons, sans le zoom (3.3.5 n'en a pas a la creation : la camera du
-- decor appartient a son modele et le suit)
local FACE_DEFAUT = -15    -- CharacterCreate_OnShow du client
local petits = CreateFrame("Frame", nil, perso)
petits:SetFrameLevel(perso:GetFrameLevel() + 4)
petits:SetPoint("TOPLEFT", perso, "TOPLEFT", 40, -30)
local dimensionnerPetits = cadreBronze(petits, {}, 8)
-- HorizontalLayoutFrame : 10, 48 par bouton a -5 d'ecart, 30 de plus avant
-- la rotation, 10
local X_PETITS = { 10, 10 + 43 + 30, 10 + 86 + 30 }
dimensionnerPetits(X_PETITS[3] + 48 + 10, 10 + 48 + 10)

local function petitBouton(icone, x, texte)
	local b = CreateFrame("Button", nil, petits)
	G.BoutonCarreIcone(b, icone, 24, "OVERLAY")
	b:SetPoint("TOPLEFT", petits, "TOPLEFT", x, -10)
	b:SetScript("OnEnter", function(self)
		GlueTooltip_SetOwner(self, nil, -5, -5, "TOPLEFT", "BOTTOMRIGHT")
		GlueTooltip_SetText(texte, nil, 1.0, 1.0, 1.0)
	end)
	b:SetScript("OnLeave", function() GlueTooltip:Hide() end)
	return b
end

-- ResetSubjectRotation : vers l'orientation par defaut en 0,25 s
local reinit = petitBouton("common-icon-undo", X_PETITS[1], TEXTE.RESET_CAMERA)
reinit:SetScript("OnClick", function(self)
	PlaySound("igMainMenuOptionCheckBoxOn")
	local depart, t = GetCharacterCreateFacing(), 0
	local ecart = ((FACE_DEFAUT - depart + 180) % 360) - 180
	self:SetScript("OnUpdate", function(soi, ecoule)
		t = t + ecoule
		local p = math.min(1, t / 0.25)
		SetCharacterCreateFacing(depart + ecart * p)
		if p >= 1 then
			soi:SetScript("OnUpdate", nil)
		end
	end)
end)

-- CustomizationClickOrHoldButton : un clic tourne de pas, tenu plus de
-- 0,25 s tourne de parSeconde
local function tourner(b, pas, parSeconde)
	G.Accrocher(b, "OnMouseDown", function(self)
		self.tenu = false
		self.attente = 0.25
		self:SetScript("OnUpdate", function(soi, ecoule)
			if soi.attente then
				soi.attente = soi.attente - ecoule
				if soi.attente >= 0 then
					return
				end
				ecoule = ecoule + soi.attente
				soi.attente = nil
			end
			soi.tenu = true
			SetCharacterCreateFacing(GetCharacterCreateFacing() + parSeconde * ecoule)
		end)
	end)
	G.Accrocher(b, "OnMouseUp", function(self)
		self.attente = nil
		self:SetScript("OnUpdate", nil)
	end)
	G.Accrocher(b, "OnHide", function(self)
		self.attente = nil
		self:SetScript("OnUpdate", nil)
	end)
	b:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		if not self.tenu then
			SetCharacterCreateFacing(GetCharacterCreateFacing() + pas)
		end
	end)
end
tourner(petitBouton("common-icon-rotateleft", X_PETITS[2], TEXTE.ROTATE_LEFT), -10, -100)
tourner(petitBouton("common-icon-rotateright", X_PETITS[3], TEXTE.ROTATE_RIGHT), 10, 100)

-- ------------------------------------------------------------ les etapes

-- ce que le client montre et que camelot n'a pas ; ses boutons de race, de
-- classe et de sexe, caches avec leur panneau, restent cliquables par :Click()
local CLIENT_CACHE = {
	CharacterCreateWoWLogo, CharacterCreateCharacterRace, CharacterCreateCharacterClass,
	CharacterCreateConfigurationFrame, CharacterCreateRandomName,
	CharacterCreateRotateLeft, CharacterCreateRotateRight, CharCreateOkayButton, CharCreateBackButton,
}

-- le fondu de la vignette du bas (FadeOut / FadeIn, 0,25 s)
local function fondre(vers)
	etat.fondu = { depart = fondBas:GetAlpha(), vers = vers, t = 0 }
	racine:SetScript("OnUpdate", function(_, ecoule)
		local f = etat.fondu
		f.t = f.t + ecoule
		local p = math.min(1, f.t / 0.25)
		fondBas:SetAlpha(f.depart + (f.vers - f.depart) * p)
		if p >= 1 then
			racine:SetScript("OnUpdate", nil)
		end
	end)
end

local function montrerMode(mode)
	local avant = etat.mode
	etat.mode = mode
	local un = (mode == 1)
	oublierMenu()
	for _, f in ipairs(CLIENT_CACHE) do
		f:Hide()
	end
	G.Montrer(raceClasse, un)
	for _, f in ipairs(ENCADRES) do
		G.Montrer(f, un)
	end
	G.Montrer(perso, not un)
	G.Montrer(CharacterCreateNameEdit, not un)
	G.Montrer(hasardNom, ALLOW_RANDOM_NAME_BUTTON and true or false)
	if un then
		CharacterCreateNameEdit:ClearFocus()
	else
		actualiserReglages()
	end
	texteNav(retour, BACK)
	texteNav(avancer, un and TEXTE.CUSTOMIZE or TEXTE.FINISH)
	if avant ~= mode then
		fondre(un and (etat.alphaFond or 1) or 0)
	end
end

-- NavBack / NavForward
retour:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOn")
	if etat.mode == 1 then
		CharacterCreate_Back()
	else
		PlaySound("gsCharacterCreationCancel")
		montrerMode(1)
	end
end)
avancer:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOn")
	if etat.mode == 1 then
		PlaySound("gsCharacterSelectionCreateNew")
		montrerMode(2)
	else
		CharacterCreate_Okay()
	end
end)

-- OnKeyDown de camelot : Echap recule, Entree avance
CharacterCreate:SetScript("OnKeyDown", function(_, touche)
	if touche == "ESCAPE" and ouvert then
		fermerMenu(false)
	elseif touche == "ESCAPE" then
		retour:Click()
	elseif touche == "ENTER" then
		avancer:Click()
	elseif touche == "PRINTSCREEN" then
		Screenshot()
	end
end)

-- ------------------------------------------------------------ apres le client

G.AccrocherFonction("CharacterChangeFixup", mettreAJour)
G.Accrocher(CharacterCreate, "OnShow", function()
	poserBords()
	etat.mode = 0
	mettreAJour()
	montrerMode(1)
	fondBas:SetAlpha(etat.alphaFond or 1)
	racine:SetScript("OnUpdate", nil)
	-- les places des colonnes et des classes se lisent une fois posees
	mettreAJour()
end)
