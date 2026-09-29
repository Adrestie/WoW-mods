-- ForeverUI : le coiffeur (BarberShopFrame, Blizzard_BarbershopUI charge a la
-- demande), a la disposition de camelot (chantier des PNJ, etape 5, choix de
-- l'utilisateur : « disposition Camelot » ; demande du 2026-09-29 : « fait
-- l'etape 5 »).
--
-- RELEVE -- CAMELOT (blizzard_barbershopui/mainline : BarberShopFrame ;
-- blizzard_charactercustomize/camelot : CharCustomizeFrame, qu'il accroche ;
-- blizzard_sharedxml : SharedButtonLargeTemplate ; les nombres du panneau
-- sont ceux de la creation de personnage de l'atelier, VALIDEE --
-- ForeverUIGlueCharacterCreate.lua, meme CharCustomizeFrame) :
--   ecran          plein ecran (TopLevelParentScaleFrameTemplate, panneau
--                  "full" : l'interface du jeu se cache) ; Echap annule ;
--                  musique, son et capture d'ecran restent au clavier
--   vignettes      charactercreate-vignette-top 451 de haut sur toute la
--                  largeur ; charactercreate-vignette-sides 703 de large a
--                  gauche, et retournee a droite (OVERLAY)
--   reglages       CustomizeOptionsContainerFrame a TOPRIGHT (0, -137), 360
--                  de large : cadre heavybronze-frame-basic (decoupe 32),
--                  equerres verticales TR / BR, fond heavybronze en mosaique
--                  de (10, -10) a (-10, 10) ; les reglages a TOPRIGHT (-10,
--                  -80), 300 de large ; haut : 80 + les lignes (48 d'ecart)
--                  + 20
--   ligne          265 x 38 (46 d'ecart, comme la creation validee) : case
--                  122 x 25 a l'echelle 1,55 au centre (common-dropdown-c-
--                  button en trois tranches de (-7, 7) a (7, -7), texte
--                  GameFontNormal dore entre 13 et -13) ; fleches 26 x 25 a
--                  l'echelle 1,7 (fond common-dropdown-c-button, -hover-2,
--                  -pressed-2, -pressedhover-2 ; icone common-dropdown-icon-
--                  back / -next, decalee de (2, -1) enfoncee) a 5 a gauche
--                  et 4 a droite ; nom du reglage au-dessus
--                  (SystemFont_Shadow_Large a (2, 4) de la fleche gauche)
--   boutons        SharedButtonLargeTemplate 150 x 40 (128-RedButton,
--                  GameFontNormalMed3 / HighlightMedium / DisableMed3) :
--                  Annuler a BOTTOMLEFT (30, 15), Reinitialiser 15 au-dessus,
--                  Accepter a BOTTOMRIGHT (-30, 15) ; Accepter et
--                  Reinitialiser grises sans changement
--   erreurs        UIErrorsFrame sous les corps, en haut de l'ecran
--   apres          l'apparence appliquee : le coiffeur se ferme
--
-- RELEVE -- 3.3.5 (Blizzard_BarbershopUI.xml / .lua) : trois reglages --
-- coiffure, couleur, pilosite (leurs noms selon la race : HAIR_<x>_STYLE,
-- HAIR_<x>_COLOR, FACIAL_HAIR_<y>) --, un quatrieme (SKIN_COLOR) si
-- CanAlterSkin ; GetBarberShopStyleInfo (nom du choix, ..., choix actuel),
-- SetNextBarberShopStyle (precedent si 1), GetBarberShopTotalCost,
-- ApplyBarberShopStyle, BarberShopReset, CancelBarberShop.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * Les reglages sont ceux de 3.3.5, a sa facon : les fleches font avancer
--     le choix (SetNextBarberShopStyle) ; la case porte le nom du choix
--     quand le client en donne un (coiffures, pilosites).
--   * DEUX MODES, comme la creation de personnage validee. Le Lua de 3.3.5 ne
--     dit pas quel choix est en cours : le client patche (tools/patcheur)
--     fait rendre a GetBarberShopStyleInfo, en cinquieme valeur, l'indice du
--     choix, et pour la peau, en sixieme, celui du visage.
--       mode 1 (client d'origine) : les couleurs portent le nom du reglage
--       dans la case, sans titre ; la case ne s'ouvre pas ;
--       mode 2 (client patche) : la case s'ouvre sur la liste des choix
--       (celle de la creation : MenuStyle2, apercu au survol) ; les couleurs
--       ont leur echantillon (celui de la creation, SANS la lumiere du decor
--       de creation : le coiffeur est dans le monde). Les choix valides se
--       calculent sur les donnees du client (BarberShopData.lua) : le
--       coiffeur fait avancer ses reglages par les routines de la creation
--       (Wow.exe 0x4F0490, 0x4EB500, 0x4EBCA0, 0x4EB150). Les noms de la
--       liste viennent du client, dans sa langue : le patch lui fait rendre
--       par GetBarberShopStyleInfo(reglage, n) le nom du choix n ; un client
--       patche avant cette piece ne le sait pas, et sa liste n'a que les
--       numeros.
--   * Pas de corps a choisir (le sexe ne change pas chez le coiffeur de
--     3.3.5), pas de de au hasard, pas de boutons de camera (3.3.5 ne donne
--     ni l'un ni l'autre au Lua).
--   * LE PRIX RESTE AFFICHE, au-dessus d'Accepter : camelot ne le montre
--     nulle part, le coiffeur de 3.3.5 si.
--   * L'interface est cachee par UIParent:Hide(), et rendue a la fermeture ;
--     les erreurs (UIErrorsFrame, qui part avec elle) ont leur ligne a nous.
--     A l'entree en combat (PLAYER_REGEN_DISABLED, avant le verrou),
--     l'interface revient et l'ecran de 3.3.5 reprend la main.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local C = {}
ForeverUI.Coiffeur = C

local SEP = string.char(92)
local FOND_BRONZE = "Interface" .. SEP .. "ForeverUI" .. SEP .. "glues" .. SEP .. "characterselect" .. SEP
	.. "heavybronzeframebackgroundc60"
local COTE_FOND = 1024

local N = {
	vignettes = { haut = 451, cotes = 703 },
	panneau = { 360, y = -137, marge = 10 },
	reglages = { 300, x = -10, y = -80, bas = 20 },
	ligne = { 265, 38, ecart = 46, ecartCamelot = 48 },
	caseReglage = { 122, 25, echelle = 1.55, fond = 7, texte = 13, h = 20 },
	fleche = { 26, 25, echelle = 1.7, gauche = -5, droite = 4 },
	titre = { 2, 4 },
	bouton = { 150, 40 },
	annuler = { 30, 15 }, ecartBoutons = 15, accepter = { -30, 15 },
	prix = { 0, 8 },
	erreur = { -122, duree = 5, fondu = 1 },
}

-- les touches que camelot laisse passer (BarberShopMixin:OnKeyDown)
local TOUCHES = { TOGGLEMUSIC = true, TOGGLESOUND = true, SCREENSHOT = true }

local function atlas(t, nom, taille)
	return ForeverUI.SetAtlas(t, nom, not taille)
end

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

local vrai = Gb.Vrai

-- GameFontDisableMed3, absente de 3.3.5 : la police de GameFontNormalMed3,
-- en gris
local function policeGrisee()
	local p = _G["ForeverUIFontDisableMed3"] or CreateFont("ForeverUIFontDisableMed3")
	p:SetFontObject(GameFontNormalMed3)
	p:SetTextColor(0.5, 0.5, 0.5)
	return p
end

-- ------------------------------------------------------------ la lecture

-- les reglages de 3.3.5 : leur nom (selon la race) ; le quatrieme si la peau
-- change
function C.Reglages()
	local cheveux = GetHairCustomization()
	local liste = {
		_G["HAIR_" .. cheveux .. "_STYLE"],
		_G["HAIR_" .. cheveux .. "_COLOR"],
		_G["FACIAL_HAIR_" .. GetFacialHairCustomization()],
	}
	if vrai(CanAlterSkin()) then liste[4] = SKIN_COLOR end
	return liste
end

-- ------------------------------------------------------------ l'ecran

local function vignette(racine, nom, points, largeur, hauteur, retourner)
	local t = racine:CreateTexture(nil, "OVERLAY")
	atlas(t, nom)
	if retourner then
		local e = ForeverUI.AtlasEntry(nom)
		t:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	for _, p in ipairs(points) do t:SetPoint(p, racine, p) end
	if largeur then t:SetWidth(largeur) end
	if hauteur then t:SetHeight(hauteur) end
	return t
end

-- le cadre heavybronze : fond en mosaique, bord decoupe, equerres
local function cadreBronze(f)
	local P = N.panneau
	local fond = f:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture(FOND_BRONZE, true)
	fond:SetPoint("TOPLEFT", f, "TOPLEFT", P.marge, -P.marge)
	fond:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -P.marge, P.marge)
	local bord = Gb.AtlasEtire(f, "heavybronze-frame-basic", "BORDER")
	bord.rect:SetAllPoints(f)
	for _, e in ipairs({ { "heavybronze-vert-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-vert-cornerbracket-br", "BOTTOMRIGHT" } }) do
		local t = f:CreateTexture(nil, "BORDER")
		atlas(t, e[1], true)
		t:SetPoint(e[2], f, e[2])
	end
	f.fond = fond
	return function(largeur, hauteur)
		f:SetWidth(largeur)
		f:SetHeight(hauteur)
		fond:SetTexCoord(0, (largeur - 2 * P.marge) / COTE_FOND, 0, (hauteur - 2 * P.marge) / COTE_FOND)
	end
end

-- WowStyle2IconButton : fond selon l'etat, icone decalee enfoncee
local function fleche(parent, sens, action)
	local F = N.fleche
	local b = CreateFrame("Button", nil, parent)
	b:SetScale(F.echelle)
	b:SetWidth(F[1])
	b:SetHeight(F[2])
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
		atlas(b.fond, fond, true)
		atlas(b.icone, "common-dropdown-icon-" .. sens, true)
		poser(b.icone, "CENTER", b, "CENTER", b.bas and 2 or 0, b.bas and -1 or 0)
	end
	b:SetScript("OnEnter", function() b.dessus = true peindre() end)
	b:SetScript("OnLeave", function() b.dessus = false peindre() end)
	b:SetScript("OnMouseDown", function() b.bas = true peindre() end)
	b:SetScript("OnMouseUp", function() b.bas = false peindre() end)
	b:SetScript("OnClick", action)
	peindre()
	b.peindre = peindre
	return b
end

-- une ligne : [<] [case] [>], le nom du reglage au-dessus
local function creerLigne(reglages, i)
	local L_, K = N.ligne, N.caseReglage
	local ligne = CreateFrame("Frame", nil, reglages)
	ligne:SetWidth(L_[1])
	ligne:SetHeight(L_[2])
	ligne:SetPoint("TOPLEFT", reglages, "TOPLEFT", 0, -(i - 1) * (L_[2] + L_.ecart))
	local case = CreateFrame("Frame", nil, ligne)
	case:SetScale(K.echelle)
	case:SetWidth(K[1])
	case:SetHeight(K[2])
	case:SetPoint("CENTER", ligne, "CENTER")
	local fond = Gb.AtlasEtire(case, "common-dropdown-c-button", "BACKGROUND")
	fond.rect:SetPoint("TOPLEFT", case, "TOPLEFT", -K.fond, K.fond)
	fond.rect:SetPoint("BOTTOMRIGHT", case, "BOTTOMRIGHT", K.fond, -K.fond)
	local texte = case:CreateFontString(nil, "OVERLAY")
	texte:SetFontObject(GameFontNormal)
	texte:SetTextColor(1, 0.82, 0)
	texte:SetJustifyH("CENTER")
	texte:SetHeight(K.h)
	texte:SetPoint("LEFT", case, "LEFT", K.texte, 0)
	texte:SetPoint("RIGHT", case, "RIGHT", -K.texte, 0)
	local F = N.fleche
	local moins = fleche(ligne, "back", function()
		SetNextBarberShopStyle(i, 1)
		PlaySound("UChatScrollButton")
		C.Maj()
	end)
	moins:SetPoint("RIGHT", case, "LEFT", F.gauche, 0)
	local plus = fleche(ligne, "next", function()
		SetNextBarberShopStyle(i)
		PlaySound("UChatScrollButton")
		C.Maj()
	end)
	plus:SetPoint("LEFT", case, "RIGHT", F.droite, 0)
	local titre = ligne:CreateFontString(nil, "ARTWORK")
	titre:SetFontObject(SystemFont_Shadow_Large)
	titre:SetPoint("BOTTOMLEFT", moins, "TOPLEFT", N.titre[1], N.titre[2])
	ligne.i, ligne.case, ligne.fond, ligne.texte, ligne.moins, ligne.plus, ligne.titre = i, case, fond, texte, moins, plus, titre
	-- mode 2 : le numero (SelectionNumber, 25 x 20), l'echantillon et sa
	-- lueur (ColorSwatch1, ColorSwatch1Glow en ADD) au centre de la case, la
	-- fleche de survol (12 x 5 a BOTTOM, -5) et la case qui ouvre la liste
	local numero = case:CreateFontString(nil, "OVERLAY")
	numero:SetFontObject(GameFontNormal)
	numero:SetTextColor(1, 0.82, 0)
	numero:SetJustifyH("LEFT")
	numero:SetWidth(25)
	numero:SetHeight(20)
	numero:Hide()
	local echantillon = case:CreateTexture(nil, "ARTWORK")
	Gb.Poser(echantillon, "charactercreate-customize-palette", true)
	echantillon:Hide()
	local lueur = case:CreateTexture(nil, "ARTWORK")
	Gb.Poser(lueur, "charactercreate-customize-palette-glow", true)
	lueur:SetBlendMode("ADD")
	lueur:SetPoint("CENTER", echantillon, "CENTER")
	lueur:Hide()
	local survol = case:CreateTexture(nil, "OVERLAY")
	Gb.Poser(survol, "common-dropdown-c-button-hover-arrow", true)
	survol:SetPoint("BOTTOM", case, "BOTTOM", 0, -5)
	survol:Hide()
	local b = CreateFrame("Button", nil, case)
	b:SetAllPoints(case)
	b:EnableMouseWheel(true)
	b:Hide()
	ligne.numero, ligne.echantillon, ligne.lueur, ligne.survol, ligne.bouton = numero, echantillon, lueur, survol, b
	C.ArmerCase(ligne)
	return ligne
end

-- SharedButtonLargeTemplate
local function bouton(racine, nom, texte, action)
	local B = N.bouton
	local b = CreateFrame("Button", nom, racine)
	b:SetWidth(B[1])
	b:SetHeight(B[2])
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
	b:SetFontString(fs)
	Gb.BoutonTroisTranches(b, "128-redbutton", { GameFontNormalMed3, GameFontHighlightMedium, policeGrisee() })
	b:SetText(texte)
	b:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		action()
	end)
	return b
end

-- la ligne des erreurs : UIErrorsFrame part avec l'interface
local function creerErreur(racine)
	local E = N.erreur
	local t = racine:CreateFontString(nil, "OVERLAY", "ErrorFont")
	t:SetPoint("TOP", racine, "TOP", 0, E[1])
	t:Hide()
	local minuteur = CreateFrame("Frame", nil, racine)
	minuteur:Hide()
	minuteur:SetScript("OnUpdate", function(self, ecoule)
		self.reste = self.reste - ecoule
		if self.reste <= 0 then
			t:Hide()
			self:Hide()
		elseif self.reste < E.fondu then
			t:SetAlpha(self.reste / E.fondu)
		end
	end)
	function C.Erreur(message, r, g, b)
		t:SetText(message)
		t:SetTextColor(r, g, b)
		t:SetAlpha(1)
		t:Show()
		minuteur.reste = E.duree
		minuteur:Show()
	end
	return t
end

function C.Construire()
	if C.racine then return C.racine end
	-- plein ecran, a l'echelle de l'interface, hors d'UIParent (qui se cache)
	local r = CreateFrame("Frame", "ForeverUIBarberShop", nil)
	r:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	r:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
	r:SetFrameStrata("MEDIUM")
	r:EnableKeyboard(true)
	r:Hide()
	local V = N.vignettes
	r.vignettes = {
		vignette(r, "charactercreate-vignette-top", { "TOPLEFT", "TOPRIGHT" }, nil, V.haut),
		vignette(r, "charactercreate-vignette-sides", { "TOPLEFT", "BOTTOMLEFT" }, V.cotes),
		vignette(r, "charactercreate-vignette-sides", { "TOPRIGHT", "BOTTOMRIGHT" }, V.cotes, nil, true),
	}
	-- les reglages
	local P, R = N.panneau, N.reglages
	local panneau = CreateFrame("Frame", "ForeverUIBarberShopOptions", r)
	panneau:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, P.y)
	panneau:EnableMouse(true)
	r.dimensionner = cadreBronze(panneau)
	local reglages = CreateFrame("Frame", nil, panneau)
	reglages:SetWidth(R[1])
	reglages:SetPoint("TOPRIGHT", panneau, "TOPRIGHT", R.x, R.y)
	r.panneau, r.reglages, r.lignes = panneau, reglages, {}
	-- les boutons
	local annuler = bouton(r, "ForeverUIBarberShopCancelButton", CANCEL, function() CancelBarberShop() end)
	annuler:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", N.annuler[1], N.annuler[2])
	local reinitialiser = bouton(r, "ForeverUIBarberShopResetButton", RESET, function()
		BarberShopReset()
		C.Maj()
	end)
	reinitialiser:SetPoint("BOTTOMLEFT", annuler, "TOPLEFT", 0, N.ecartBoutons)
	local accepter = bouton(r, "ForeverUIBarberShopAcceptButton", ACCEPT, function() ApplyBarberShopStyle() end)
	accepter:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", N.accepter[1], N.accepter[2])
	-- le prix (ecart : camelot ne le montre pas)
	local prix = CreateFrame("Frame", "ForeverUIBarberShopMoneyFrame", r, "SmallMoneyFrameTemplate")
	prix:SetPoint("BOTTOMRIGHT", accepter, "TOPRIGHT", N.prix[1], N.prix[2])
	-- un montant fixe, pas l'or du joueur (le coiffeur de 3.3.5 : GUILD_REPAIR)
	if MoneyFrame_SetType then MoneyFrame_SetType(prix, "STATIC") end
	r.annuler, r.reinitialiser, r.accepter, r.prix = annuler, reinitialiser, accepter, prix
	r.erreur = creerErreur(r)
	-- BarberShopMixin:OnKeyDown
	r:SetScript("OnKeyDown", function(_, touche)
		if touche == "ESCAPE" then
			-- une liste ouverte se referme d'abord, sur le choix en cours
			if C.ListeOuverte() then
				C.FermerListe(false)
			else
				CancelBarberShop()
			end
			return
		end
		local action = GetBindingAction(touche)
		if action and TOUCHES[action] then RunBinding(action) end
	end)
	r:SetScript("OnHide", function()
		C.OublierListe()
		C.RendreInterface()
	end)
	C.CreerListe(r)
	C.racine = r
	return r
end

-- ------------------------------------------------------------ mode 2 : les choix

-- Reglages du coiffeur : 1 coiffure, 2 couleur des cheveux, 3 pilosite, 4
-- peau. Le numero d'un choix est son rang parmi les choix valides, le plus
-- petit indice valide etant 1 (la creation validee).
C.listes = {}

-- l'indice du choix en cours, et pour la peau celui du visage (client
-- patche) ; client d'origine : rien, mode 1
local function indice(i)
	local v, visage = select(5, GetBarberShopStyleInfo(i))
	if type(v) == "number" then
		return v, visage
	end
end

local function rang(liste, v)
	for k, x in ipairs(liste) do
		if x == v then
			return k
		end
	end
end

-- la race (fichier de ChrRaces, en majuscules) et le sexe (0 / 1) du joueur
local function joueur()
	local _, fichier = UnitRace("player")
	return fichier and string.upper(fichier), (UnitSex("player") == 3) and 1 or 0
end

-- les choix valides d'un reglage, calcules : les cases [section][variation]
-- [couleur] de CharSections (section 0 peau, 1 visage, 2 pilosite, 3
-- cheveux, 4 sous-vetements) et les regles du moteur, en ordre croissant
-- comme le moteur les parcourt (tools/choix_personnalisation.py)
local function calculer(i)
	local fichier, sexe = joueur()
	local d = ForeverUI.ChoixApparence and fichier and ForeverUI.ChoixApparence[fichier]
	d = d and d[sexe]
	if not d then
		return nil
	end
	-- drapeaux : un poids pour les classes, un autre pour le chevalier de la mort
	local _, classe = UnitClass("player")
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
	local function uneCouleur(section, var)
		for c = 0, nb(section, var) - 1 do
			if bonne(section, var, c) then
				return true
			end
		end
		return false
	end
	local liste = {}
	if i == 1 then
		-- coiffure (0x4F0490) : une couleur au moins
		for s = 0, d[3].n - 1 do
			if uneCouleur(3, s) then
				liste[#liste + 1] = s
			end
		end
	elseif i == 2 then
		-- couleur des cheveux (0x4EB500) : celles de la coiffure courante
		local coiffure = indice(1)
		for c = 0, nb(3, coiffure) - 1 do
			if bonne(3, coiffure, c) then
				liste[#liste + 1] = c
			end
		end
	elseif i == 3 then
		-- pilosite (0x4EBCA0) : si la case (pilosite, couleur des cheveux)
		-- existe, les styles qui ont une couleur au moins ; sinon tous les
		-- styles
		local poil, couleur = indice(3), indice(2)
		if poil and couleur and poil < d[2].n and couleur < nb(2, poil) then
			for v = 0, d[2].n - 1 do
				if uneCouleur(2, v) then
					liste[#liste + 1] = v
				end
			end
		else
			for v = 0, (d.barbes or 0) - 1 do
				liste[#liste + 1] = v
			end
		end
	else
		-- peau (0x4EB150) : avec le visage courant et les sous-vetements
		local _, visage = indice(4)
		for c = 0, nb(0, 0) - 1 do
			if bonne(0, 0, c) and bonne(1, visage, c) and bonne(4, 0, c) then
				liste[#liste + 1] = c
			end
		end
	end
	return liste
end

-- secours, si la valeur du moteur manque a la liste calculee : le tour
-- complet du reglage par le moteur, arrete au retour sur le choix de depart
-- (chaque cran redessine le personnage)
local function lister(i)
	local depart = indice(i)
	if not depart then
		return nil
	end
	local tour = { depart }
	for _ = 1, 255 do
		SetNextBarberShopStyle(i)
		local v = indice(i)
		if not v or v == depart then
			break
		end
		tour[#tour + 1] = v
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

-- amener un reglage sur un choix par le plus court chemin
local function allerA(i, cible)
	local liste = C.listes[i]
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
			SetNextBarberShopStyle(i)
		end
	else
		for _ = 1, arriere do
			SetNextBarberShopStyle(i, 1)
		end
	end
end

-- La couleur d'un choix (ColorSwatch1) : celle que
-- tools/couleurs_personnalisation.py a lue dans sa texture
-- (BarberShopColors.lua). Couleur des cheveux (2) et peau (4).
local ECHANTILLONS = { [2] = "cheveux", [4] = "peau" }
local function couleurDe(i, v)
	local genre = ECHANTILLONS[i]
	if not (genre and v and ForeverUI.CouleursApparence) then
		return nil
	end
	local fichier, sexe = joueur()
	local t = fichier and ForeverUI.CouleursApparence[fichier]
	t = t and t[sexe]
	t = t and t[genre]
	return t and t[v]
end

-- Le nom d'un choix dans la liste, que donne le client patche :
-- GetBarberShopStyleInfo(reglage, n) rend le SEUL nom du choix n
-- (BarberShopStyle.dbc, dans la langue du client), ou nil. Un client qui ne
-- connait pas ce second argument l'ignore et rend les valeurs du choix en
-- cours : on ne se fie donc qu'a une reponse d'une seule valeur. La couleur
-- des cheveux n'a pas de noms.
local NOMMES = { [1] = true, [3] = true, [4] = true }
local function seul(...)
	if select("#", ...) == 1 then
		return (...)
	end
end
local function nomDe(i, v)
	if not NOMMES[i] then
		return nil
	end
	local nom = seul(GetBarberShopStyleInfo(i, v))
	if type(nom) == "string" and nom ~= "" then
		return nom
	end
end

-- ------------------------------------------------------------ mode 2 : la liste ouverte

-- MenuStyle2 (celle de la creation validee) : fond common-dropdown-c-bg de
-- (-17, 12) a (17, -22), marges 3 / 6 / 3 / 7, a l'echelle de la case,
-- TOPRIGHT sur son BOTTOMRIGHT ; grille verticale, 1 colonne jusqu'a 10
-- choix, 2 jusqu'a 24, 3 jusqu'a 36, 4 au-dela, et plus de colonnes si la
-- liste descendrait a moins de 100 du bas ; elements de 20 (details a 14 du
-- bord ; AdjustWidth : 116 sur une colonne, sur plusieurs 25 + 36 + 18 avec
-- des couleurs, 108 avec des noms, 42 sinon) ; SelectionName a droite du
-- numero, borne a la largeur de l'element moins 2 et le numero ; survol :
-- common-dropdown-customize-mouseover a 0,15 et apercu du choix sur le
-- personnage ; choix en cours dore, les autres gris ; un clic choisit et
-- referme ; un clic a cote ou Echap revient au choix en cours.
-- L'APERCU attend APERCU_DELAI sur une ligne (chaque apercu recompose les
-- textures du personnage) ; l'image qui suit le survol ne compte pas, et
-- une image ne compte jamais plus de APERCU_PAS_MAX (la creation validee).
local APERCU_DELAI = 0.1
local APERCU_PAS_MAX = 0.05
local L = { entrees = {} }          -- ouvert = { ligne, choisi }, apercu = { k, attente, neuf }
C.entrees = L.entrees

function C.ListeOuverte()
	return L.ouvert ~= nil
end

-- sans rien changer : la liste s'efface (le coiffeur se ferme)
function C.OublierListe()
	L.ouvert, L.apercu = nil, nil
	local r = C.racine
	if r then
		r.menu:Hide()
		r.capteur:Hide()
	end
end

-- garder : le choix survole est retenu ; sinon retour au choix en cours
function C.FermerListe(garder)
	local o = L.ouvert
	if not o then
		return
	end
	C.OublierListe()
	if not garder then
		allerA(o.ligne.i, o.choisi)
	end
	C.Maj()
end

function C.CreerListe(r)
	local menu = CreateFrame("Frame", "ForeverUIBarberShopChoiceMenu", r)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetFrameLevel(20)
	menu:SetScale(N.caseReglage.echelle)
	menu:EnableMouse(true)
	menu:Hide()
	local fond = Gb.AtlasEtire(menu, "common-dropdown-c-bg", "BACKGROUND")
	fond.rect:SetPoint("TOPLEFT", menu, "TOPLEFT", -17, 12)
	fond.rect:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 17, -22)
	-- un clic hors de la liste la referme sans rien choisir
	local capteur = CreateFrame("Button", nil, r)
	capteur:SetFrameStrata("FULLSCREEN_DIALOG")
	capteur:SetFrameLevel(10)
	capteur:SetAllPoints(r)
	capteur:Hide()
	capteur:SetScript("OnClick", function() C.FermerListe(false) end)
	-- la largeur d'un nom, mesuree sur un texte jamais borne (une ligne
	-- reutilisee mesurerait dans la largeur posee pour la precedente)
	local mesure = menu:CreateFontString(nil, "OVERLAY")
	mesure:SetFontObject(GameFontNormal)
	mesure:SetAlpha(0)
	menu:SetScript("OnUpdate", function(_, ecoule)
		local a = L.apercu
		if not a then
			return
		end
		if a.neuf then
			a.neuf = false
			return
		end
		a.attente = a.attente - math.min(ecoule, APERCU_PAS_MAX)
		if a.attente <= 0 then
			L.apercu = nil
			if L.ouvert then
				allerA(L.ouvert.ligne.i, C.listes[L.ouvert.ligne.i][a.k])
				C.MajPrix()
			end
		end
	end)
	r.menu, r.capteur, r.mesure = menu, capteur, mesure
end

local function entree(k)
	if L.entrees[k] then
		return L.entrees[k]
	end
	local e = CreateFrame("Button", nil, C.racine.menu)
	e:SetHeight(20)
	e.survol = Gb.AtlasEtire(e, "common-dropdown-customize-mouseover", "BACKGROUND")
	e.survol.rect:SetAllPoints(e)
	e.survol:Alpha(0.15)
	e.survol:Montrer(false)
	e.numero = e:CreateFontString(nil, "OVERLAY")
	e.numero:SetFontObject(GameFontNormal)
	e.numero:SetJustifyH("LEFT")
	e.numero:SetWidth(25)
	e.numero:SetHeight(20)
	e.numero:SetPoint("TOPLEFT", e, "TOPLEFT", 14, 0)
	e.nom = e:CreateFontString(nil, "OVERLAY")
	e.nom:SetFontObject(GameFontNormal)
	e.nom:SetJustifyH("LEFT")
	e.nom:SetHeight(20)
	e.nom:SetPoint("LEFT", e.numero, "RIGHT", 0, 0)
	-- ColorSwatch1 a droite du numero, sa lueur, et ColorSelected (le
	-- choix en cours) a 4 a gauche de l'echantillon
	e.echantillon = e:CreateTexture(nil, "ARTWORK")
	Gb.Poser(e.echantillon, "charactercreate-customize-palette", true)
	e.echantillon:SetPoint("LEFT", e.numero, "RIGHT", 0, 0)
	e.lueur = e:CreateTexture(nil, "ARTWORK")
	Gb.Poser(e.lueur, "charactercreate-customize-palette-glow", true)
	e.lueur:SetBlendMode("ADD")
	e.lueur:SetPoint("CENTER", e.echantillon, "CENTER")
	e.choisi = e:CreateTexture(nil, "ARTWORK")
	Gb.Poser(e.choisi, "charactercreate-customize-palette-selected", true)
	e.choisi:SetPoint("LEFT", e.echantillon, "LEFT", -4, 0)
	e:SetScript("OnEnter", function(self)
		self.survol:Montrer(true)
		if L.ouvert then
			L.apercu = { k = self.k, attente = APERCU_DELAI, neuf = true }
		end
	end)
	e:SetScript("OnLeave", function(self)
		self.survol:Montrer(false)
		if L.apercu and L.apercu.k == self.k then
			L.apercu = nil
		end
	end)
	e:SetScript("OnClick", function(self)
		if L.ouvert then
			L.apercu = nil
			PlaySound("gsCharacterCreationLook")
			allerA(L.ouvert.ligne.i, C.listes[L.ouvert.ligne.i][self.k])
			C.FermerListe(true)
		end
	end)
	L.entrees[k] = e
	return e
end

local function ouvrirListe(ligne)
	local r, i = C.racine, ligne.i
	local liste = C.listes[i]
	if not liste or #liste == 0 then
		return
	end
	local n = #liste
	local choisi = rang(liste, indice(i)) or 1
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
	local couleurs = couleurDe(i, liste[1]) and true
	local noms = false
	for _, v in ipairs(liste) do
		if not couleurs and nomDe(i, v) then
			noms = true
		end
	end
	local details = 116
	if colonnes > 1 then
		details = (couleurs and (25 + 36 + 18)) or (noms and 108) or 42
	end
	local largeur = 14 + details + 14
	local menu = r.menu
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
		local nom = not couleurs and nomDe(i, liste[k])
		if nom then
			r.mesure:SetText(nom)
			e.nom:SetWidth(math.min(r.mesure:GetStringWidth(), largeur - 2 - 25))
			e.nom:SetText(nom)
		end
		Gb.Montrer(e.nom, nom)
		if k == choisi then
			e.numero:SetTextColor(1, 0.82, 0)
			e.nom:SetTextColor(1, 0.82, 0)
		else
			e.numero:SetTextColor(0.5, 0.5, 0.5)
			e.nom:SetTextColor(0.5, 0.5, 0.5)
		end
		e.survol:Montrer(false)
		local couleur = couleurDe(i, liste[k])
		if couleur then
			e.echantillon:SetVertexColor(couleur[1], couleur[2], couleur[3])
		end
		Gb.Montrer(e.echantillon, couleur)
		Gb.Montrer(e.lueur, couleur)
		Gb.Montrer(e.choisi, couleur and k == choisi)
		e:Show()
	end
	for k = n + 1, #L.entrees do
		L.entrees[k]:Hide()
	end
	L.ouvert = { ligne = ligne, choisi = liste[choisi] }
	menu:Show()
	r.capteur:Show()
	C.PeindreCase(ligne)
end

-- WowStyle2Dropdown : fond selon l'etat (enfonce, survole, ouvert), fleche
-- au survol, details decales de (1, -1) enfonces
function C.PeindreCase(ligne)
	local b, K = ligne.bouton, N.caseReglage
	local nom = "common-dropdown-c-button"
	if b.bas and b.dessus then
		nom = "common-dropdown-c-button-pressedhover-1"
	elseif b.bas then
		nom = "common-dropdown-c-button-pressed-1"
	elseif b.dessus then
		nom = "common-dropdown-c-button-hover-1"
	elseif L.ouvert and L.ouvert.ligne == ligne then
		nom = "common-dropdown-c-button-open"
	end
	ligne.fond:Poser(nom)
	Gb.Montrer(ligne.survol, b:IsShown() and b.dessus)
	local dx, dy = b.bas and 1 or 0, b.bas and -1 or 0
	poser(ligne.numero, "CENTER", ligne.case, "CENTER", dx, dy)
	poser(ligne.echantillon, "CENTER", ligne.case, "CENTER", dx, dy)
	poser(ligne.texte, "LEFT", ligne.case, "LEFT", K.texte + dx, dy)
	ligne.texte:SetPoint("RIGHT", ligne.case, "RIGHT", -K.texte + dx, dy)
end

-- la case d'une ligne : elle ouvre la liste ; la molette fait avancer le
-- choix (vers le bas, le suivant)
function C.ArmerCase(ligne)
	local b = ligne.bouton
	b:SetScript("OnEnter", function(self) self.dessus = true C.PeindreCase(ligne) end)
	b:SetScript("OnLeave", function(self) self.dessus = nil C.PeindreCase(ligne) end)
	b:SetScript("OnMouseDown", function(self) self.bas = true C.PeindreCase(ligne) end)
	b:SetScript("OnMouseUp", function(self) self.bas = nil C.PeindreCase(ligne) end)
	b:SetScript("OnHide", function(self) self.dessus, self.bas = nil, nil end)
	b:SetScript("OnClick", function()
		local deja = L.ouvert and L.ouvert.ligne == ligne
		C.FermerListe(false)
		if not deja then
			ouvrirListe(ligne)
		end
	end)
	b:SetScript("OnMouseWheel", function(_, sens)
		C.FermerListe(false)
		if sens < 0 then
			SetNextBarberShopStyle(ligne.i)
		else
			SetNextBarberShopStyle(ligne.i, 1)
		end
		PlaySound("UChatScrollButton")
		C.Maj()
	end)
end

-- ------------------------------------------------------------ la mise a jour

-- le prix et les boutons (BarberShop_UpdateCost) : Accepter et
-- Reinitialiser grises sans changement
function C.MajPrix()
	local r = C.racine
	if not r then return end
	local toutActuel = true
	for i = 1, #C.Reglages() do
		local _, _, _, actuel = GetBarberShopStyleInfo(i)
		if not vrai(actuel) then toutActuel = false end
	end
	MoneyFrame_Update(r.prix:GetName(), GetBarberShopTotalCost())
	if toutActuel then
		r.accepter:Disable()
		r.reinitialiser:Disable()
	else
		r.accepter:Enable()
		r.reinitialiser:Enable()
	end
end

-- les lignes (BarberShop_Update), puis le prix et les boutons. Mode 2 : les
-- listes se recalculent toutes (sans le moteur, c'est immediat), sauf celle
-- qui est ouverte.
function C.Maj()
	local r = C.racine
	if not r or not r:IsShown() then return end
	local noms = C.Reglages()
	local L_, P, R = N.ligne, N.panneau, N.reglages
	for i, nomReglage in ipairs(noms) do
		local ligne = r.lignes[i] or creerLigne(r.reglages, i)
		r.lignes[i] = ligne
		local nom = GetBarberShopStyleInfo(i)
		local aNom = nom and nom ~= ""
		local v = indice(i)
		local position
		if not v then
			C.listes[i] = nil
		else
			if not (L.ouvert and L.ouvert.ligne.i == i) then
				local liste = calculer(i)
				if not (liste and rang(liste, v)) then
					liste = lister(i)
				end
				C.listes[i] = liste
			end
			position = C.listes[i] and rang(C.listes[i], v)
		end
		local couleur = position and couleurDe(i, v)
		if couleur then
			ligne.echantillon:SetVertexColor(couleur[1], couleur[2], couleur[3])
		end
		Gb.Montrer(ligne.echantillon, couleur)
		Gb.Montrer(ligne.lueur, couleur)
		if position then
			-- mode 2 : le reglage au-dessus ; dans la case le nom du choix,
			-- son echantillon, ou a defaut son numero
			ligne.titre:SetText(nomReglage)
			ligne.titre:Show()
			ligne.texte:SetText(aNom and nom or "")
			Gb.Montrer(ligne.texte, aNom and not couleur)
			ligne.numero:SetText(position)
			Gb.Montrer(ligne.numero, not aNom and not couleur)
			ligne.bouton:Show()
		else
			-- mode 1 : le nom du choix sous celui du reglage ; sinon le
			-- reglage dans la case, sans titre
			if aNom then
				ligne.texte:SetText(nom)
				ligne.titre:SetText(nomReglage)
				ligne.titre:Show()
			else
				ligne.texte:SetText(nomReglage)
				ligne.titre:Hide()
			end
			ligne.texte:Show()
			ligne.numero:Hide()
			ligne.bouton:Hide()
		end
		C.PeindreCase(ligne)
		ligne:Show()
	end
	for i = #noms + 1, #r.lignes do r.lignes[i]:Hide() end
	local n = #noms
	r.reglages:SetHeight(n * L_[2] + (n - 1) * L_.ecart)
	r.dimensionner(P[1], -R.y + n * L_[2] + (n - 1) * L_.ecartCamelot + R.bas)
	C.MajPrix()
end

-- ------------------------------------------------------------ l'ouverture

-- L'ECRAN DE 3.3.5 RESTE L'HOTE (evenements, sons) : enfant d'UIParent, il
-- disparait avec l'interface, sans rien toucher de lui -- et revient intact
-- si le combat rend l'interface.
function C.Ouvrir()
	if InCombatLockdown() then return end
	local r = C.Construire()
	r:SetScale(UIParent:GetScale())
	if UIParent:IsShown() then
		C.cache = true
		UIParent:Hide()
	end
	r:Show()
	C.Maj()
end

function C.Fermer()
	-- l'ecran de 3.3.5 d'abord : invisible sous l'interface cachee,
	-- BARBER_SHOP_CLOSE ne l'a pas ferme (il ne ferme qu'un ecran visible) ;
	-- ferme APRES le retour de l'interface, il reparaissait un instant et
	-- rejouait son son d'installation
	if BarberShopFrame and BarberShopFrame:IsShown() then BarberShopFrame:Hide() end
	if C.racine and C.racine:IsShown() then C.racine:Hide() end
	C.RendreInterface()
end

function C.RendreInterface()
	if C.cache then
		C.cache = nil
		UIParent:Show()
	end
end

local veille = CreateFrame("Frame")
C.veille = veille
for _, ev in ipairs({ "BARBER_SHOP_OPEN", "BARBER_SHOP_CLOSE", "BARBER_SHOP_SUCCESS",
	"BARBER_SHOP_APPEARANCE_APPLIED", "PLAYER_REGEN_DISABLED", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE" }) do
	veille:RegisterEvent(ev)
end
veille:SetScript("OnEvent", function(_, ev, message)
	local ouvert = C.racine and C.racine:IsShown()
	if ev == "BARBER_SHOP_OPEN" then
		C.Ouvrir()
	elseif ev == "BARBER_SHOP_CLOSE" then
		C.Fermer()
	elseif ev == "PLAYER_REGEN_DISABLED" then
		-- avant le verrou du combat : l'interface revient, l'ecran de 3.3.5
		-- reprend la main
		if ouvert then C.racine:Hide() end
	elseif not ouvert then
		return
	elseif ev == "BARBER_SHOP_APPEARANCE_APPLIED" then
		-- camelot : l'apparence appliquee, le coiffeur se ferme
		CancelBarberShop()
	elseif ev == "UI_ERROR_MESSAGE" then
		C.Erreur(message, 1.0, 0.1, 0.1)
	elseif ev == "UI_INFO_MESSAGE" then
		C.Erreur(message, 1.0, 1.0, 0.0)
	else
		C.Maj()
	end
end)
