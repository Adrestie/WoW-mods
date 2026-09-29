-- ForeverUI : la fenetre des metiers (TradeSkillFrame, Blizzard_TradeSkillUI
-- charge a la demande), a la disposition de camelot (chantier des PNJ, etape
-- 4, choix de l'utilisateur : « disposition Camelot » ; demande du
-- 2026-09-28). Cette partie : la page de fabrication. La page d'ensemble et
-- les onglets lateraux des metiers sont dans ProfessionsBook.lua.
--
-- RELEVE -- CAMELOT (blizzard_professions : camelot/blizzard_professionsframe
-- .xml / .lua, blizzard_professionscrafting.xml / .lua et camelot/ ;
-- blizzard_professionstemplates : recipelist, recipeschematicform (+
-- camelot/), rankbar, recipereagentslot(base), templates, professions.lua (+
-- camelot/) ; blizzard_colors ; tables DB2 GlobalStrings, GlobalColor,
-- UiTextureAtlasMember / ElementSliceData) :
--   fenetre        ProfessionsFrame 673 x 594, PortraitFrameTemplate ; fond
--                  Profession-Background-Overview (Bg), stries cachees ;
--                  titre TRADE_SKILL_TITLE (nom du metier ; lie : « nom
--                  [joueur] ») ; portrait = l'icone du metier ; croix (-2, 1)
--   la page        Profession-Background-Template2 a sa taille (665 x 570) a
--                  (3, -21)
--   la liste       304 de large, de (5, -72) a 5 du bas ; fond Professions-
--                  background-summarylist sur toute la liste (le liseré
--                  InsetFrameTemplate cache) ; filtre WowStyle1Filter-
--                  DropdownTemplate (18 de haut) a TOPRIGHT (-8, -9) ; recherche
--                  SearchBoxTemplate de (13, -8) au filtre (-4), 20 de haut ;
--                  zone de (8, -35) a (-20, 5), barre MinimalScrollBar contre
--                  elle ; arbre : retrait 10, marges 5 (haut, bas, droite), 0
--                  a gauche, 1 entre deux elements ; sous chaque categorie
--                  depliee, 1 au-dessus des recettes et 10 en dessous ; aucun
--                  resultat : PROFESSIONS_NO_JOURNAL_ENTRIES, TOP (0, -60),
--                  GameFontNormal 200
--   la categorie   ListHeaderVisualTemplate, 25 : common-button-list-
--                  collapseExpand (et en ADD a 0,4 au survol), nom
--                  Game15Font_Shadow LEFT (8, 0), NORMAL, blanc au survol ;
--                  bouton 20 x 20 a RIGHT (-6) : common-button-list-plus
--                  (repliee) / -minus ; enfonce : texte et icone de (1, -1)
--   la recette     20 de haut : icone de progression Professions-Icon-Skill-
--                  High / -Medium / -Low (optimale, moyenne, facile ; rien
--                  si triviale) dans un cadre 26 x 15 a LEFT (-9, 0) (+1 en y
--                  si optimale), l'icone a RIGHT (0, -1) ; nom GameFont-
--                  Highlight_NoShadow a (4) de ce cadre, PROFESSION_RECIPE_-
--                  COLOR, blanc au survol ; « [n] » fabricables a sa droite ;
--                  choisie Professions_Recipe_Active, survol Professions_-
--                  Recipe_Hover a 0,5, centres (0, -1) ; nom tronque a la
--                  place restante (10 de marge), infobulle s'il l'est
--   le rang        ProfessionsRankBarTemplate 453 x 18 a (110, -40) : fond
--                  Professions-skillbar-bg, remplissage Skillbar_Fill_-
--                  Flipbook_<metier> (441 x 18 a (5, -3)) montre sur 453 x
--                  rang / max par le masque (a 1 du remplissage), eclat
--                  Skillbar_Flare_<metier> 53 x 16 au bout (cache si plein),
--                  cadre Professions-skillbar-frame ; texte TRADESKILL_NAME_-
--                  RANK Number12FontOutline au centre (-3)
--   le lien        23 x 23 a LEFT sur RIGHT du rang (-2, -4) : common-button-
--                  tertiary-square-* (34 x 34), icone common-icon-chatlink
--                  25 x 25 ; infobulle LINK_TRADESKILL_TOOLTIP ; clic : le
--                  lien dans la saisie active
--   la fiche       360 x 484 a TOPRIGHT de la liste (2, 0) : carte du metier
--                  Profession-background-card-<metier> (sinon Professions-
--                  Recipe-Background) sur toute la fiche ; cadre common-
--                  insideframe (decoupe 53) ; resultat 47 x 47 a (28, -28),
--                  icone ronde 53 x 53, contour auctionhouse-itemicon-border-
--                  <qualite> 68 x 68 (et en ADD a 0,2 au survol, 66 x 66),
--                  nombre NumberFontNormalLarge BOTTOM sur BOTTOMRIGHT (-4, 1)
--                  sur BattleBar-SwapPetShadow a 0,8 ; nom GameFontHighlight-
--                  Med2 (couleur de qualite) a RIGHT de l'icone (14, 17) ;
--                  outils GameFontHighlightSmall2 sous le nom (0, -4),
--                  PROFESSIONS_REQUIRED_TOOLS ; puis, depuis (-1, -12) sous
--                  l'icone, a 4 d'ecart : recharge GameFontRedSmall 400,
--                  description GameFontHighlightSmall2 305 (+5) ; reactifs a
--                  (0, -20) sous la description : « Reagents: »
--                  GameFontNormalSmall 180 x 20, emplacements 180 x 50 a
--                  (1, -20), par colonnes de 4, 5 d'ecart ; bouton 39 x 39
--                  (Professions-Slot-bg, icone, contour Professions-Slot-
--                  Frame-<qualite> de (-5, 4) a (4, -5)), nom GameFont-
--                  Highlight_NoShadow 108 x 36 a LEFT (46) : « possede/requis
--                  nom », blanc s'il y en a assez, DISABLED_REAGENT_COLOR sinon
--   les boutons    SharedButtonSmallTemplate (128-RedButton, 28 de haut, 80
--                  au moins, texte + 30) : Creer a BOTTOMRIGHT (-9, 7) ;
--                  Tout creer « %s [%d] » a BOTTOMLEFT sur BOTTOMRIGHT (-362,
--                  7) ; compteur NumericInputSpinnerTemplate 31 x 20 a
--                  (-185, 11), fleches 23 x 22 (UI-SpellbookIcon-Prev/Next-
--                  Page), molette +-1 (+-10 avec Maj)
--
-- RELEVE -- 3.3.5 (Blizzard_TradeSkillUI.xml / .lua) : 384 x 512, liste plate
-- (GetTradeSkillInfo : nom, type header / optimal / medium / easy / trivial,
-- fabricables, deplie, verbe), 8 lignes, details dessous, deux menus
-- (sous-classe, emplacement), case « Have Materials », recherche des 75 de
-- competence, rang TradeSkillRankFrame, Creer / Tout creer / compteur /
-- Quitter ; TradeSkillFrame_Update, TradeSkillFrame_SetSelection.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * L'hote reste le TradeSkillFrame du client (panneau, evenements, choix
--     de la recette) : ses lignes, listes, details et menus deviennent
--     invisibles et sans souris. La liste, la fiche, le rang et les boutons
--     sont a nous, sur ses donnees ; un clic fait ce que faisait sa ligne.
--   * Le metier est reconnu a l'icone de son sort (GetSpellTexture du nom,
--     Spell.dbc : Trade_Tailoring...), la meme dans toutes les langues : elle
--     choisit la carte de fond et la barre de rang. Joaillerie et
--     calligraphie n'ont pas de carte chez camelot : Professions-Recipe-
--     Background, comme son code le prevoit.
--   * La barre de rang de camelot est animee (60 images) : 3.3.5 n'affiche
--     pas ses feuilles (1712 de large) ; la premiere image, fixe.
--   * Le filtre « Has skill up » est fait par la liste (3.3.5 n'a pas ce
--     filtre) : les recettes triviales sont ecartees, et les categories
--     videes avec elles. « Have Materials » et les emplacements passent par
--     le client (TradeSkillOnlyShowMakeable, SetTradeSkillInvSlotFilter).
--   * La recherche : le nom seul, comme camelot. Sous 75 de competence (hors
--     metier lie), TradeSkillFrame_Update du client remet le filtre de nom a
--     vide a chaque mise a jour : le champ y est cache, comme en 3.3.5 (le
--     forcer relancerait la mise a jour sans fin).
--   * Pas de favoris, de suivi de recette, de qualites, d'equipement de
--     metier, de concentration, de commandes, de menu de canaux pour le
--     lien : 3.3.5 ne les a pas. Le nombre de points gagnes n'est pas connu
--     de 3.3.5 : 1 dans l'infobulle de progression.
--   * La liste du filtre suit la regle de camelot (le bouton comme plancher,
--     la liste s'elargit a ses entrees) ; les autres menus de l'atelier
--     gardent la largeur exacte de leur bouton (ecart valide).
--   * « Creer » est active quand les reactifs sont la (la regle de 3.3.5) ;
--     « Tout creer » et le compteur n'existent pas pour un sort a verbe
--     (enchantement...), comme en 3.3.5.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits
local L = ForeverUI.L

local M = {}
ForeverUI.Metiers = M

local SEP = string.char(92)
local POLICE = "Fonts" .. SEP .. "FRIZQT__.TTF"
local POLICE_CHIFFRES = "Fonts" .. SEP .. "ARIALN.TTF"
local BOUTONS = "Interface" .. SEP .. "Buttons" .. SEP

local N = {
	fenetre = { 673, 594 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	fond = { 2, -21, -2, 2 },                -- Bg de PortraitFrameTemplate
	page = { 3, -21 },                       -- Profession-Background-Template2
	liste = { 5, -72, 304, bas = 5 },
	filtre = { -8, -9, 18 },
	recherche = { 13, -8, 20, ecart = -4 },
	zone = { 8, -35, -20, 5 },
	arbre = { retrait = 10, haut = 5, bas = 5, droite = 5, espace = 1, dessus = 1, dessous = 10 },
	categorie = { h = 25, texte = 8, bouton = 20, boutonX = -6 },
	recette = { h = 20, progres = { 26, 15, -9 }, nomX = 4, marge = 10 },
	aucun = { 0, -60, 200 },
	pas = 21,                                -- un cran de molette : une recette
	rang = { 110, -40, 453, 18, fond = { 451, 29 }, rempli = { 441, 18, 5, -3 }, masque = 1,
		eclat = { 53, 16 }, texte = -3 },
	lien = { -2, -4, 23, fond = 34, icone = 25 },
	fiche = { 2, 0, 360, 484 },
	resultat = { 28, -28, 47, icone = 53, contour = 68, lueur = 66, nombre = { -4, 1 } },
	nom = { 14, 17 },
	outils = { 0, -4 },
	organisateur = { -1, -12, 4 },
	recharge = 400, description = 305,
	reactifs = { 0, -20, etiquette = { 180, 20 }, emplacement = { 180, 50 }, debut = { 1, -20 },
		ecart = { 5, 5 }, colonne = 4, bouton = 39, nomX = 46, nomTaille = { 108, 36 } },
	creer = { -9, 7, 80, 28, marge = 30 },
	toutCreer = { -362, 7 },
	compteur = { -185, 11, 31, 20, fleche = { 23, 22 }, ecartMoins = -6 },
	niveaux = { page = 1, liste = 2, lignes = 3, fiche = 2, rang = 5, croix = 22 },
}

-- GlobalColor de camelot
local COULEURS = {
	recette = { 0.8863, 0.8627, 0.8392 },    -- PROFESSION_RECIPE_COLOR
	reactifManquant = { 0.6275, 0.6275, 0.6275 }, -- DISABLED_REAGENT_COLOR
}

local PROGRES = {
	optimal = { "professions-icon-skill-high", 1, L.TRADESKILL_SKILL_UP_OPTIMAL },
	medium = { "professions-icon-skill-medium", 0, L.TRADESKILL_SKILL_UP_MEDIUM },
	easy = { "professions-icon-skill-low", 0, L.TRADESKILL_SKILL_UP_EASY },
}

-- le metier, par l'icone de son sort (Spell.dbc de 3.3.5) : carte de fond,
-- bande et eclat du rang (variante c60 quand camelot l'a)
local METIERS = {
	["trade_alchemy"] = { carte = "profession-background-card-alchemy", rang = "alchemy_c60" },
	["trade_blacksmithing"] = { carte = "profession-background-card-blacksmithing", rang = "blacksmithing" },
	["trade_engraving"] = { carte = "profession-background-card-enchanting", rang = "enchanting_c60" },
	["trade_engineering"] = { carte = "profession-background-card-engineering", rang = "engineering" },
	["inv_inscription_tradeskill01"] = { rang = "inscription" },
	["inv_misc_gem_01"] = { rang = "jewelcrafting" },
	["inv_misc_gem_02"] = { rang = "jewelcrafting" },
	["inv_misc_armorkit_17"] = { carte = "profession-background-card-leatherworking", rang = "leatherworking" },
	["trade_tailoring"] = { carte = "profession-background-card-tailoring", rang = "tailoring" },
	["inv_misc_food_15"] = { carte = "profession-background-card-cooking", rang = "cooking" },
	["spell_holy_sealofsacrifice"] = { carte = "profession-background-card-firstaid", rang = "firstaid_c60" },
	["trade_mining"] = { carte = "profession-background-card-mining", rang = "mining" },
}

-- AUCTION_HOUSE_ITEM_QUALITY_ICON_BORDER_ATLASES / PROFESSIONS_ITEM_QUALITY_-
-- ICON_BORDER_ATLASES (blizzard_colors)
local CONTOUR_RESULTAT = { [0] = "gray", [1] = "white", [2] = "green", [3] = "blue", [4] = "purple",
	[5] = "orange", [6] = "artifact", [7] = "account" }
local CONTOUR_REACTIF = { [1] = "professions-slot-frame", [2] = "professions-slot-frame-green",
	[3] = "professions-slot-frame-blue", [4] = "professions-slot-frame-epic", [5] = "professions-slot-frame-legendary" }

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

local function atlas(t, nom, taille)
	return ForeverUI.SetAtlas(t, nom, not taille)
end

-- les polices de camelot absentes de 3.3.5
local function police(nom, chemin, taille, contour, ombre, r, g, b)
	local p = _G[nom] or CreateFont(nom)
	p:SetFont(chemin, taille, contour or "")
	if ombre then
		p:SetShadowOffset(1, -1)
		p:SetShadowColor(0, 0, 0, 1)
	else
		p:SetShadowOffset(0, 0)
		p:SetShadowColor(0, 0, 0, 0)
	end
	p:SetTextColor(r or 1, g or 1, b or 1)
	return p
end
local POLICES = {
	ligne = police("ForeverUIFontHighlightNoShadow12", POLICE, 12),          -- GameFontHighlight_NoShadow
	categorie = police("ForeverUIFontGame15Shadow", POLICE, 15, nil, true), -- Game15Font_Shadow
	med2 = police("ForeverUIFontHighlightMed2", POLICE, 14, nil, true),     -- GameFontHighlightMed2
	small2 = police("ForeverUIFontHighlightSmall2", POLICE, 11),            -- GameFontHighlightSmall2
	rang = police("ForeverUIFontNumber12Outline", POLICE_CHIFFRES, 12, "OUTLINE"), -- Number12FontOutline
}

local function vrai(v)
	return v and v ~= 0 and true or false
end

-- ------------------------------------------------------------ le metier

local function metier()
	local nom = GetTradeSkillLine()
	local icone = nom and GetSpellTexture(nom)
	local cle = icone and string.lower(string.match(icone, "([^" .. SEP .. SEP .. "/]+)$") or "")
	return cle and METIERS[cle], icone
end

-- ------------------------------------------------------------ la liste

-- le fond d'un en-tete : common-button-list-collapseExpand, bouts de 18 et
-- centre (28 texels sur 64) pose tuile a tuile (voir QuestLog.lua)
local DECOUPE_ENTETE = { cote = 18, image = 64 }
local function fondEntete(b, couche, mode, alpha)
	local e = ForeverUI.AtlasEntry("common-button-list-collapseexpand")
	if not e then return {} end
	local du = (e[3] - e[2]) / DECOUPE_ENTETE.image
	local cote = DECOUPE_ENTETE.cote
	local milieu = DECOUPE_ENTETE.image - 2 * cote
	local pieces = {}
	local function piece(u1, u2)
		local t = b:CreateTexture(nil, couche)
		t:SetTexture(e[1])
		t:SetTexCoord(u1, u2, e[4], e[5])
		if mode then t:SetBlendMode(mode) end
		if alpha then t:SetAlpha(alpha) end
		pieces[#pieces + 1] = t
		return t
	end
	local gauche = piece(e[2], e[2] + cote * du)
	gauche:SetWidth(cote)
	gauche:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	gauche:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	local droite = piece(e[3] - cote * du, e[3])
	droite:SetWidth(cote)
	droite:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	droite:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	b.foreverTuiles = b.foreverTuiles or {}
	b.foreverTuiles[couche] = { gauche = gauche, du = du, e = e, milieu = milieu, cote = cote, pieces = {}, mode = mode, alpha = alpha }
	return pieces
end

-- les tuiles du centre, a la largeur de la ligne
local function tuilerEntete(b, largeur)
	for couche, T in pairs(b.foreverTuiles or {}) do
		for _, t in ipairs(T.pieces) do t:Hide() end
		local reste, x, n = largeur - 2 * T.cote, 0, 0
		while reste > 0 do
			n = n + 1
			local t = T.pieces[n]
			if not t then
				t = b:CreateTexture(nil, couche)
				t:SetTexture(T.e[1])
				if T.mode then t:SetBlendMode(T.mode) end
				if T.alpha then t:SetAlpha(T.alpha) end
				T.pieces[n] = t
			end
			local l = math.min(T.milieu, reste)
			local u1 = T.e[2] + T.cote * T.du
			t:SetTexCoord(u1, u1 + l * T.du, T.e[4], T.e[5])
			t:SetWidth(l)
			poser(t, "TOPLEFT", T.gauche, "TOPRIGHT", x, 0)
			t:SetPoint("BOTTOMLEFT", T.gauche, "BOTTOMRIGHT", x, 0)
			t:Show()
			x = x + l
			reste = reste - l
		end
	end
end

-- pour les autres addons qui reprennent cette page : les en-tetes de la
-- liste et les polices
M.FondEntete, M.TuilerEntete, M.Polices = fondEntete, tuilerEntete, POLICES

local function creerCategorie(n)
	local h = M.habit
	local C = N.categorie
	local b = CreateFrame("Button", "ForeverUITradeSkillCategory" .. n, h.enfant)
	b:SetHeight(C.h)
	b:RegisterForClicks("LeftButtonUp")
	fondEntete(b, "BACKGROUND")
	fondEntete(b, "HIGHLIGHT", "ADD", 0.4)
	local plus = CreateFrame("Frame", nil, b)
	plus:SetWidth(C.bouton)
	plus:SetHeight(C.bouton)
	plus:SetPoint("RIGHT", b, "RIGHT", C.boutonX, 0)
	plus.Icon = plus:CreateTexture(nil, "ARTWORK")
	plus.Icon:SetPoint("CENTER", plus, "CENTER", 0, 0)
	b.plus = plus
	local texte = b:CreateFontString(nil, "OVERLAY")
	texte:SetFontObject(POLICES.categorie)
	texte:SetJustifyH("LEFT")
	texte:SetPoint("LEFT", b, "LEFT", C.texte, 0)
	texte:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	b.texte = texte
	local n_ = NORMAL_FONT_COLOR
	texte:SetTextColor(n_.r, n_.g, n_.b)
	b:SetScript("OnEnter", function(self) self.texte:SetTextColor(1, 1, 1) end)
	b:SetScript("OnLeave", function(self) self.texte:SetTextColor(n_.r, n_.g, n_.b) end)
	b:SetScript("OnMouseDown", function(self)
		poser(self.texte, "LEFT", self, "LEFT", C.texte + 1, -1)
		self.texte:SetPoint("RIGHT", self.plus, "LEFT", -4, 0)
		poser(self.plus.Icon, "CENTER", self.plus, "CENTER", 1, -1)
	end)
	b:SetScript("OnMouseUp", function(self)
		poser(self.texte, "LEFT", self, "LEFT", C.texte, 0)
		self.texte:SetPoint("RIGHT", self.plus, "LEFT", -4, 0)
		poser(self.plus.Icon, "CENTER", self.plus, "CENTER", 0, 0)
	end)
	b:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		if self.deplie then
			CollapseTradeSkillSubClass(self:GetID())
		else
			ExpandTradeSkillSubClass(self:GetID())
		end
	end)
	return b
end

local function creerRecette(n)
	local h = M.habit
	local R = N.recette
	local b = CreateFrame("Button", "ForeverUITradeSkillRecipe" .. n, h.enfant)
	b:SetHeight(R.h)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local progres = CreateFrame("Frame", nil, b)
	progres:SetWidth(R.progres[1])
	progres:SetHeight(R.progres[2])
	progres:SetPoint("LEFT", b, "LEFT", R.progres[3], 0)
	progres:EnableMouse(true)
	progres.Icon = progres:CreateTexture(nil, "OVERLAY")
	progres.Icon:SetPoint("RIGHT", progres, "RIGHT", 0, -1)
	b.progres = progres
	local nom = b:CreateFontString(nil, "OVERLAY")
	nom:SetFontObject(POLICES.ligne)
	nom:SetJustifyH("LEFT")
	nom:SetHeight(12)
	nom:SetPoint("LEFT", progres, "RIGHT", R.nomX, 0)
	b.nom = nom
	local nombre = b:CreateFontString(nil, "OVERLAY")
	nombre:SetFontObject(POLICES.ligne)
	nombre:SetJustifyH("LEFT")
	nombre:SetHeight(12)
	nombre:SetPoint("LEFT", nom, "RIGHT", 0, 0)
	b.nombre = nombre
	-- choisie (au-dessus du nom) et survol (calque HIGHLIGHT)
	local choix = CreateFrame("Frame", nil, b)
	choix:SetAllPoints(b)
	choix:SetFrameLevel(b:GetFrameLevel() + 1)
	choix:EnableMouse(false)
	local choisie = choix:CreateTexture(nil, "OVERLAY")
	atlas(choisie, "professions_recipe_active", true)
	choisie:SetPoint("CENTER", b, "CENTER", 0, -1)
	choisie:Hide()
	b.choisie = choisie
	local survol = b:CreateTexture(nil, "HIGHLIGHT")
	atlas(survol, "professions_recipe_hover", true)
	survol:SetPoint("CENTER", b, "CENTER", 0, -1)
	survol:SetAlpha(0.5)
	b.survol = survol
	local function couleurs(self, blanc)
		local c = blanc and { 1, 1, 1 } or COULEURS.recette
		self.nom:SetTextColor(c[1], c[2], c[3])
		self.nombre:SetTextColor(c[1], c[2], c[3])
	end
	b.couleurs = couleurs
	local function entrer(self)
		couleurs(b, true)
		if b.tronque then
			GameTooltip:SetOwner(b.nom, "ANCHOR_RIGHT")
			GameTooltip:AddLine(b.nomComplet, 1, 1, 1, false)
			GameTooltip:Show()
		end
	end
	local function sortir()
		couleurs(b, false)
		GameTooltip:Hide()
	end
	b:SetScript("OnEnter", entrer)
	b:SetScript("OnLeave", sortir)
	progres:SetScript("OnLeave", sortir)
	progres:SetScript("OnMouseUp", function(_, bouton) b:Click(bouton) end)
	b:SetScript("OnClick", function(self, bouton)
		if bouton ~= "LeftButton" then return end
		if IsModifiedClick() then
			HandleModifiedItemClick(GetTradeSkillRecipeLink(self:GetID()))
			return
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
		TradeSkillFrame_SetSelection(self:GetID())
		TradeSkillFrame_Update()
	end)
	return b
end

-- les elements de la liste, dans l'ordre : les donnees de 3.3.5 mises en
-- arbre (un en-tete, ses recettes) ; le filtre « Has skill up »
function M.Elements()
	local elements = {}
	local categorie
	local enAttente = {}
	local function fermer()
		if categorie then
			local recettes = categorie.recettes
			if categorie.deplie and #recettes > 0 then
				elements[#elements + 1] = { espace = N.arbre.dessus }
				for _, r in ipairs(recettes) do elements[#elements + 1] = r end
				elements[#elements + 1] = { espace = N.arbre.dessous }
			end
		end
	end
	for i = 1, GetNumTradeSkills() or 0 do
		local nom, genre, fabricables, deplie = GetTradeSkillInfo(i)
		if nom then
			if genre == "header" then
				fermer()
				categorie = { index = i, nom = nom, deplie = deplie and true or false, recettes = {}, categorie = true }
				enAttente[#enAttente + 1] = categorie
				elements[#elements + 1] = categorie
			elseif not (M.seulementProgression and genre == "trivial") then
				local r = { index = i, nom = nom, genre = genre, fabricables = fabricables or 0, retrait = categorie and true or false }
				if categorie then
					table.insert(categorie.recettes, r)
				else
					elements[#elements + 1] = r
				end
			end
		end
	end
	fermer()
	-- une categorie que le filtre a videe disparait (camelot filtre avant de
	-- construire l'arbre) ; une categorie repliee garde son en-tete
	if M.seulementProgression then
		local garde = {}
		for _, e in ipairs(elements) do
			if not (e.categorie and e.deplie and #e.recettes == 0) then garde[#garde + 1] = e end
		end
		elements = garde
	end
	return elements
end

local function poserBarre(avec)
	local h = M.habit
	local Z = N.zone
	h.zone:ClearAllPoints()
	h.zone:SetPoint("TOPLEFT", h.liste, "TOPLEFT", Z[1], Z[2])
	-- sans barre : la meme marge a droite qu'a gauche (regle de l'atelier)
	h.zone:SetPoint("BOTTOMRIGHT", h.liste, "BOTTOMRIGHT", avec and Z[3] or -Z[1], Z[4])
end

function M.MajListe()
	local h = M.habit
	if not h then return end
	local A = N.arbre
	local elements = M.Elements()
	-- la place : avec ou sans barre selon la hauteur
	local hauteur = A.haut + A.bas
	for i, e in ipairs(elements) do
		hauteur = hauteur + (e.categorie and N.categorie.h or e.espace or N.recette.h) + (i > 1 and A.espace or 0)
	end
	local vue = h.zone:GetHeight()
	if not vue or vue <= 0 then vue = N.fenetre[2] + N.liste[2] - N.liste.bas + N.zone[2] - N.zone[4] end
	local avec = hauteur > vue
	if avec ~= h.avecBarre then
		h.avecBarre = avec
		poserBarre(avec)
	end
	local largeur = N.liste[3] - N.zone[1] + (avec and N.zone[3] or -N.zone[1])
	h.enfant:SetWidth(largeur)
	h.enfant:SetHeight(math.max(hauteur, 1))
	local choisi = GetTradeSkillSelectionIndex()
	local y, nc, nr = A.haut, 0, 0
	local argent = nil
	for i, e in ipairs(elements) do
		if i > 1 then y = y + A.espace end
		if e.categorie then
			nc = nc + 1
			local b = h.categories[nc] or creerCategorie(nc)
			h.categories[nc] = b
			b:SetID(e.index)
			b.deplie = e.deplie
			b.texte:SetText(e.nom)
			local ic = e.deplie and "common-button-list-minus" or "common-button-list-plus"
			atlas(b.plus.Icon, ic, true)
			local l = largeur - A.droite
			b:SetWidth(l)
			tuilerEntete(b, l)
			poser(b, "TOPLEFT", h.enfant, "TOPLEFT", 0, -y)
			b:Show()
			y = y + N.categorie.h
		elseif e.espace then
			y = y + e.espace
		else
			nr = nr + 1
			local b = h.recettes[nr] or creerRecette(nr)
			h.recettes[nr] = b
			b:SetID(e.index)
			local retrait = e.retrait and A.retrait or 0
			local l = largeur - A.droite - retrait
			b:SetWidth(l)
			poser(b, "TOPLEFT", h.enfant, "TOPLEFT", retrait, -y)
			M.RemplirRecette(b, e, l, choisi == e.index)
			b:Show()
			y = y + N.recette.h
		end
	end
	for i = nc + 1, #h.categories do h.categories[i]:Hide() end
	for i = nr + 1, #h.recettes do h.recettes[i]:Hide() end
	Gb.Montrer(h.aucun, #elements == 0)
	-- la barre
	local total = math.ceil(hauteur / N.pas)
	local visibles = math.floor(vue / N.pas)
	h.decalage = math.max(0, math.min(h.decalage or 0, total - visibles))
	h.barre:Regler(total, visibles, h.decalage)
	h.zone:SetVerticalScroll(math.min(h.decalage * N.pas, math.max(0, hauteur - vue)))
end

-- LA MESURE D'UN NOM. Une ligne sert tour a tour a plusieurs recettes : son
-- nom garde la largeur donnee a la precedente, et le client mesure le texte
-- DANS cette largeur (GetStringWidth rend la largeur affichee). Un nom plus
-- long que le precedent y etait coupe sans raison (signale le 2026-09-28 :
-- « Rough Blast... »). On mesure donc sur un texte a part, jamais borne,
-- present mais invisible.
local function largeurNom(texte)
	local m = M.mesure
	if not m then
		m = M.habit.enfant:CreateFontString(nil, "OVERLAY")
		m:SetFontObject(POLICES.ligne)
		m:SetPoint("TOPLEFT", M.habit.enfant, "TOPLEFT", 0, 0)
		m:SetAlpha(0)
		M.mesure = m
	end
	m:SetText(texte)
	return m:GetStringWidth()
end

function M.RemplirRecette(b, e, largeur, choisie)
	local R = N.recette
	b.nomComplet = e.nom
	b.nom:SetText(e.nom)
	b.couleurs(b, false)
	local P = PROGRES[e.genre]
	if P then
		atlas(b.progres.Icon, P[1], true)
		poser(b.progres, "LEFT", b, "LEFT", R.progres[3], P[2])
		b.progres:Show()
		b.progres:SetScript("OnEnter", function()
			b.couleurs(b, true)
			GameTooltip:SetOwner(b.progres, "ANCHOR_RIGHT")
			local t = P[3]
			local n_ = NORMAL_FONT_COLOR
			GameTooltip:AddLine(string.format(t, 1), n_.r, n_.g, n_.b, true)
			GameTooltip:Show()
		end)
	else
		b.progres:Hide()
	end
	local avecNombre = (e.fabricables or 0) > 0
	if avecNombre then
		b.nombre:SetFormattedText(" [%d] ", e.fabricables)
		b.nombre:Show()
	else
		b.nombre:SetText("")
		b.nombre:Hide()
	end
	-- la place du nom : la ligne moins le nombre, la marge et le cadre de
	-- progression
	local place = largeur - ((avecNombre and b.nombre:GetStringWidth() or 0) + R.marge + R.progres[1])
	local plein = largeurNom(e.nom)
	b.nom:SetWidth(math.max(1, math.min(place, plein)))
	b.tronque = plein > place
	Gb.Montrer(b.choisie, choisie)
	Gb.Montrer(b.survol, not choisie)
end

-- ------------------------------------------------------------ le rang

function M.MajRang()
	local h = M.habit
	local r = h.rang
	local nom, rang, maxi, bonus = GetTradeSkillLine()
	if not nom or not maxi or maxi <= 0 then
		r:Hide()
		return
	end
	r:Show()
	if bonus and bonus > 0 then
		r.texte:SetFormattedText(L.TRADESKILL_NAME_RANK_MODIFIER, nom, rang, bonus, maxi)
	else
		r.texte:SetFormattedText(L.TRADESKILL_NAME_RANK, nom, rang, maxi)
	end
	local M_ = metier()
	local bande = M_ and ("skillbar_fill_flipbook_" .. M_.rang) or "skillbar_fill_flipbook_defaultblue"
	local e = ForeverUI.AtlasEntry(bande) or ForeverUI.AtlasEntry("skillbar_fill_flipbook_defaultblue")
	local eclat = M_ and ForeverUI.AtlasEntry("skillbar_flare_" .. M_.rang)
	local R = N.rang
	local part = math.min(rang / maxi, 1)
	-- le masque : de 1 apres le debut du remplissage, sur 453 x la part ; le
	-- remplissage (441) n'est visible que dessous
	local vu = math.min(R.rempli[1] - R.masque, R[3] * part)
	if e and vu >= 1 then
		r.rempli:SetTexture(e[1])
		local du = (e[3] - e[2]) / R.rempli[1]
		r.rempli:SetTexCoord(e[2] + du * R.masque, e[2] + du * (R.masque + vu), e[4], e[5])
		r.rempli:SetWidth(vu)
		r.rempli:Show()
	else
		r.rempli:Hide()
	end
	-- L'ECLAT EST MASQUE LUI AUSSI chez camelot (MaskedTexture Flare) : il
	-- ne se voit que sur la largeur du masque, depuis le debut du
	-- remplissage. 3.3.5 n'a pas de masque : on en garde la partie droite,
	-- a la largeur visible. Sans cela, a faible rang, il debordait a gauche
	-- de la barre (signale le 2026-09-28).
	local masque = R[3] * part
	if eclat and masque >= 1 then
		local l = math.min(R.eclat[1], masque)
		local du = (eclat[3] - eclat[2]) / R.eclat[1]
		r.eclat:SetTexture(eclat[1])
		r.eclat:SetTexCoord(eclat[3] - du * l, eclat[3], eclat[4], eclat[5])
		r.eclat:SetWidth(l)
		poser(r.eclat, "RIGHT", r, "TOPLEFT", R.rempli[3] + R.masque + masque, R.rempli[4] - R.rempli[2] / 2)
		r.eclat:SetAlpha(rang >= maxi and 0 or 1)
		r.eclat:Show()
	else
		r.eclat:Hide()
	end
end

-- ------------------------------------------------------------ la fiche

local function textePlein(fs, texte, maxi)
	fs:SetHeight(200)
	fs:SetText(texte)
	fs:SetWidth(maxi)
	fs:SetWidth(fs:GetStringWidth())
	fs:SetHeight(fs:GetStringHeight())
end

local function qualite(lien)
	if lien and string.find(lien, "|Hitem:", 1, true) then
		local nom, _, q = GetItemInfo(lien)
		return q or 0, nom
	end
	return 0, nil
end

local function creerReactif(n)
	local h = M.habit
	local Rc = N.reactifs
	local s = CreateFrame("Frame", nil, h.reactifs)
	s:SetWidth(Rc.emplacement[1])
	s:SetHeight(Rc.emplacement[2])
	local b = CreateFrame("Button", "ForeverUITradeSkillReagent" .. n, s)
	b:SetWidth(Rc.bouton)
	b:SetHeight(Rc.bouton)
	b:SetPoint("LEFT", s, "LEFT", 0, 0)
	local fond = b:CreateTexture(nil, "BACKGROUND")
	atlas(fond, "professions-slot-bg", true)
	fond:SetAllPoints(b)
	local icone = b:CreateTexture(nil, "ARTWORK")
	icone:SetAllPoints(b)
	local contour = b:CreateTexture(nil, "OVERLAY")
	contour:SetPoint("TOPLEFT", icone, "TOPLEFT", -5, 4)
	contour:SetPoint("BOTTOMRIGHT", icone, "BOTTOMRIGHT", 4, -5)
	-- UI-Quickslot2 (SetModifyingRequired(false)), en BORDER, sur le bouton
	b:SetNormalTexture(BOUTONS .. "UI-Quickslot2")
	local cadre = b:GetNormalTexture()
	cadre:SetDrawLayer("BORDER")
	cadre:ClearAllPoints()
	cadre:SetAllPoints(b)
	b.icone, b.contour = icone, contour
	local nom = s:CreateFontString(nil, "BORDER")
	nom:SetFontObject(POLICES.ligne)
	nom:SetJustifyH("LEFT")
	nom:SetWidth(Rc.nomTaille[1])
	nom:SetHeight(Rc.nomTaille[2])
	nom:SetPoint("LEFT", s, "LEFT", Rc.nomX, 0)
	s.bouton, s.nom = b, nom
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetTradeSkillItem(M.choisi, self:GetID())
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		if IsModifiedClick() then
			HandleModifiedItemClick(GetTradeSkillReagentItemLink(M.choisi, self:GetID()))
		end
	end)
	return s
end

-- APRES TradeSkillFrame_SetSelection : la fiche de la recette choisie
function M.MajFiche()
	local h = M.habit
	if not h then return end
	local id = GetTradeSkillSelectionIndex()
	local nom, genre, fabricables, _, verbe = GetTradeSkillInfo(id)
	local F = h.fiche
	-- la carte du metier
	local M_ = metier()
	local carte = (M_ and M_.carte and ForeverUI.AtlasEntry(M_.carte)) and M_.carte or "professions-recipe-background"
	atlas(F.carte, carte, true)
	if not nom or genre == "header" then
		M.choisi = nil
		F.contenu:Hide()
		M.MajBoutons(nil)
		return
	end
	M.choisi = id
	F.contenu:Show()
	-- le resultat
	local lien = GetTradeSkillItemLink(id)
	local q, nomObjet = qualite(lien)
	SetPortraitToTexture(F.icone, GetTradeSkillIcon(id))
	local contour = CONTOUR_RESULTAT[q]
	if contour then
		atlas(F.contour, "auctionhouse-itemicon-border-" .. contour)
		F.contour:Show()
	else
		F.contour:Hide()
	end
	local mini, maxi = GetTradeSkillNumMade(id)
	if maxi and maxi > 1 then
		if mini == maxi then F.nombre:SetText(mini) else F.nombre:SetFormattedText("%d-%d", mini, maxi) end
		if F.nombre:GetWidth() > 39 then F.nombre:SetFormattedText("~%d", math.floor((mini + maxi) / 2)) end
		F.ombre:Show()
	else
		F.nombre:SetText("")
		F.ombre:Hide()
	end
	local texteNom
	if nomObjet then
		local c = ITEM_QUALITY_COLORS[q]
		local hex = c and (c.hex or string.format("|cff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5)))
		texteNom = hex and (hex .. nomObjet .. "|r") or nomObjet
	else
		texteNom = NORMAL_FONT_COLOR_CODE .. nom .. "|r"
	end
	textePlein(F.nom, texteNom, 800)
	-- les outils
	local outils = BuildColoredListString(GetTradeSkillTools(id))
	if outils then
		textePlein(F.outils, NORMAL_FONT_COLOR_CODE .. REQUIRES_LABEL .. "|r " .. outils, 800)
		F.outils:Show()
	else
		F.outils:SetText("")
		F.outils:Hide()
	end
	-- la recharge, puis la description (l'organisateur vertical)
	local O = N.organisateur
	local recharge = GetTradeSkillCooldown(id)
	local precedent
	if recharge then
		F.recharge:SetText(COOLDOWN_REMAINING .. " " .. SecondsToTime(recharge))
		poser(F.recharge, "TOPLEFT", F.resultat, "BOTTOMLEFT", O[1], O[2])
		F.recharge:Show()
		precedent = F.recharge
	else
		F.recharge:Hide()
	end
	local description = GetTradeSkillDescription(id)
	F.description:SetWidth(N.description)
	F.description:SetHeight(600)
	F.description:SetText(description or "")
	F.description:SetHeight((description and description ~= "") and (F.description:GetStringHeight() + 1) or 1)
	if precedent then
		poser(F.description, "TOPLEFT", precedent, "BOTTOMLEFT", 0, -(O[3] + 5))
	else
		poser(F.description, "TOPLEFT", F.resultat, "BOTTOMLEFT", O[1], O[2])
	end
	-- les reactifs
	local Rc = N.reactifs
	local n = GetTradeSkillNumReagents(id) or 0
	Gb.Montrer(h.reactifs, n > 0)
	poser(h.reactifs, "TOPLEFT", F.description, "BOTTOMLEFT", Rc[1], Rc[2])
	local montres = 0
	for i = 1, n do
		local rNom, rIcone, requis, possede = GetTradeSkillReagentInfo(id, i)
		if rNom and rIcone then
			montres = montres + 1
			local s = h.emplacements[montres] or creerReactif(montres)
			h.emplacements[montres] = s
			s.bouton:SetID(i)
			s.bouton.icone:SetTexture(rIcone)
			local rq = qualite(GetTradeSkillReagentItemLink(id, i))
			local ct = CONTOUR_REACTIF[rq]
			if ct then
				atlas(s.bouton.contour, ct, true)
				s.bouton.contour:Show()
			else
				s.bouton.contour:Hide()
			end
			local assez = (possede or 0) >= (requis or 0)
			local c = assez and { 1, 1, 1 } or COULEURS.reactifManquant
			s.nom:SetFormattedText(L.TRADESKILL_REAGENT_COUNT .. " %s", tostring(possede or 0), requis or 0, rNom)
			s.nom:SetTextColor(c[1], c[2], c[3])
			local colonne = math.floor((montres - 1) / Rc.colonne)
			local rangee = (montres - 1) % Rc.colonne
			poser(s, "TOPLEFT", h.reactifs, "TOPLEFT", Rc.debut[1] + colonne * (Rc.emplacement[1] + Rc.ecart[1]),
				Rc.debut[2] - rangee * (Rc.emplacement[2] + Rc.ecart[2]))
			s:Show()
		end
	end
	for i = montres + 1, #h.emplacements do h.emplacements[i]:Hide() end
	M.MajBoutons(id, nom, verbe, fabricables)
end

-- ------------------------------------------------------------ les boutons

local function texteAjuste(b, texte)
	b:SetText(texte)
	local fs = b:GetFontString()
	local largeur = (fs and fs:GetStringWidth() or 0) + N.creer.marge
	b:SetWidth(math.max(b:GetWidth(), largeur))
end

function M.MajBoutons(id, nom, verbe, fabricables)
	local h = M.habit
	local B = h.boutons
	if not id or vrai(IsTradeSkillLinked()) then
		B.creer:Hide()
		B.tout:Hide()
		B.compteur:Hide()
		return
	end
	-- les reactifs : la regle de 3.3.5 pour « Creer »
	local possible = true
	for i = 1, GetTradeSkillNumReagents(id) or 0 do
		local _, _, requis, possede = GetTradeSkillReagentInfo(id, i)
		if (possede or 0) < (requis or 0) then possible = false end
	end
	local maxi = math.abs(fabricables or 0)
	B.creer:Show()
	texteAjuste(B.creer, verbe or CREATE)
	if possible then B.creer:Enable() else B.creer:Disable() end
	local plusieurs = not verbe
	Gb.Montrer(B.tout, plusieurs)
	Gb.Montrer(B.compteur, plusieurs)
	if plusieurs then
		texteAjuste(B.tout, string.format(L.TRADESKILL_CREATE_ALL_FORMAT, CREATE_ALL, maxi))
		if possible and maxi > 0 then B.tout:Enable() else B.tout:Disable() end
		B.compteur.maxi = maxi
		if maxi > 0 then
			B.compteur:SetNumber(math.max(1, math.min(GetTradeskillRepeatCount() or 1, maxi)))
			B.compteur:EnableMouse(true)
			B.compteur.actif = true
		else
			B.compteur:SetNumber(0)
			B.compteur:EnableMouse(false)
			B.compteur.actif = false
		end
		M.MajFleches()
	end
end

function M.MajFleches()
	local c = M.habit.boutons.compteur
	local v = c:GetNumber()
	local function etat(b, oui) if oui then b:Enable() else b:Disable() end end
	etat(c.plus, c.actif and v < (c.maxi or 0))
	etat(c.moins, c.actif and v > 1)
end

local function changerCompteur(pas)
	local c = M.habit.boutons.compteur
	if not c.actif then return end
	c:SetNumber(math.max(1, math.min((c:GetNumber() or 1) + pas, c.maxi or 1)))
	M.MajFleches()
end

local function creerBoutons(page)
	local h = M.habit
	local C, T, K = N.creer, N.toutCreer, N.compteur
	local polices = { GameFontNormal, GameFontHighlight, GameFontDisable }
	local function bouton(nom)
		local b = CreateFrame("Button", nom, page)
		b:SetWidth(C[3])
		b:SetHeight(C[4])
		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		b:SetFontString(fs)
		Gb.BoutonTroisTranches(b, "128-redbutton", polices)
		return b
	end
	local creer = bouton("ForeverUITradeSkillCreateButton")
	creer:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", C[1], C[2])
	creer:SetScript("OnClick", function()
		if M.choisi then DoTradeSkill(M.choisi, h.boutons.compteur:GetNumber()) end
	end)
	local tout = bouton("ForeverUITradeSkillCreateAllButton")
	tout:SetPoint("BOTTOMLEFT", page, "BOTTOMRIGHT", T[1], T[2])
	tout:SetScript("OnClick", function()
		local c = h.boutons.compteur
		if M.choisi and (c.maxi or 0) > 0 then
			c:SetNumber(c.maxi)
			DoTradeSkill(M.choisi, c.maxi)
		end
	end)
	-- le compteur (NumericInputSpinnerTemplate < InputBoxTemplate)
	local c = CreateFrame("EditBox", "ForeverUITradeSkillInputBox", page)
	c:SetWidth(K[3])
	c:SetHeight(K[4])
	c:SetPoint("BOTTOMLEFT", page, "BOTTOMRIGHT", K[1], K[2])
	c:SetAutoFocus(false)
	c:SetNumeric(true)
	c:SetMaxLetters(3)
	c:SetFontObject(ChatFontNormal)
	c:SetJustifyH("CENTER")
	local bord = "Interface" .. SEP .. "Common" .. SEP .. "Common-Input-Border"
	local g = c:CreateTexture(nil, "BACKGROUND")
	g:SetTexture(bord) g:SetTexCoord(0, 0.0625, 0, 0.625)
	g:SetWidth(8) g:SetHeight(20)
	g:SetPoint("LEFT", c, "LEFT", -5, 0)
	local d = c:CreateTexture(nil, "BACKGROUND")
	d:SetTexture(bord) d:SetTexCoord(0.9375, 1, 0, 0.625)
	d:SetWidth(8) d:SetHeight(20)
	d:SetPoint("RIGHT", c, "RIGHT", 0, 0)
	local m = c:CreateTexture(nil, "BACKGROUND")
	m:SetTexture(bord) m:SetTexCoord(0.0625, 0.9375, 0, 0.625)
	m:SetHeight(20)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	m:SetPoint("RIGHT", d, "LEFT", 0, 0)
	c:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	c:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	c:SetScript("OnEditFocusLost", function() changerCompteur(0) end)
	c:SetScript("OnTextChanged", function() M.MajFleches() end)
	local function fleche(nom, fichier)
		local f = CreateFrame("Button", nom, c)
		f:SetWidth(K.fleche[1])
		f:SetHeight(K.fleche[2])
		f:SetNormalTexture(BOUTONS .. fichier .. "-Up")
		f:SetPushedTexture(BOUTONS .. fichier .. "-Down")
		f:SetDisabledTexture(BOUTONS .. fichier .. "-Disabled")
		f:SetHighlightTexture(BOUTONS .. "UI-Common-MouseHilight")
		f:GetHighlightTexture():SetBlendMode("ADD")
		return f
	end
	local plus = fleche("ForeverUITradeSkillIncrementButton", "UI-SpellbookIcon-NextPage")
	plus:SetPoint("LEFT", c, "RIGHT", 0, 0)
	plus:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		changerCompteur(1)
	end)
	local moins = fleche("ForeverUITradeSkillDecrementButton", "UI-SpellbookIcon-PrevPage")
	moins:SetPoint("RIGHT", c, "LEFT", K.ecartMoins, 0)
	moins:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		changerCompteur(-1)
	end)
	c.plus, c.moins = plus, moins
	local molette = CreateFrame("Frame", nil, c)
	molette:SetPoint("TOPLEFT", moins, "TOPLEFT")
	molette:SetPoint("BOTTOMRIGHT", plus, "BOTTOMRIGHT")
	molette:EnableMouseWheel(true)
	molette:SetScript("OnMouseWheel", function(_, sens)
		changerCompteur((IsShiftKeyDown() and 10 or 1) * (sens > 0 and 1 or -1))
		c:ClearFocus()
	end)
	h.boutons = { creer = creer, tout = tout, compteur = c }
end

-- ------------------------------------------------------------ le filtre

-- 3.3.5 appelle la fonction avec (cadre, niveau) (UIDropDownMenu.lua) ;
-- ToggleDropDownMenu pose aussi UIDROPDOWNMENU_MENU_LEVEL
local function initialiserFiltre(_, niveau)
	niveau = niveau or UIDROPDOWNMENU_MENU_LEVEL or 1
	if niveau == 1 then
		local info = UIDropDownMenu_CreateInfo()
		info.text = L.TRADESKILL_FILTER_SKILL_UP
		info.checked = M.seulementProgression
		info.keepShownOnClick = 1
		info.func = function()
			M.seulementProgression = not M.seulementProgression
			M.MajListe()
		end
		UIDropDownMenu_AddButton(info, niveau)
		info = UIDropDownMenu_CreateInfo()
		info.text = CRAFT_IS_MAKEABLE
		info.checked = vrai(TradeSkillFrameAvailableFilterCheckButton:GetChecked())
		info.keepShownOnClick = 1
		info.func = function()
			local oui = not vrai(TradeSkillFrameAvailableFilterCheckButton:GetChecked())
			TradeSkillFrameAvailableFilterCheckButton:SetChecked(oui)
			TradeSkillOnlyShowMakeable(oui)
		end
		UIDropDownMenu_AddButton(info, niveau)
		info = UIDropDownMenu_CreateInfo()
		info.text = L.TRADESKILL_FILTER_SLOTS
		info.hasArrow = 1
		info.notCheckable = 1
		info.value = "emplacements"
		UIDropDownMenu_AddButton(info, niveau)
	elseif UIDROPDOWNMENU_MENU_VALUE == "emplacements" then
		local info = UIDropDownMenu_CreateInfo()
		info.text = L.TRADESKILL_CHECK_ALL
		info.notCheckable = 1
		info.func = function()
			SetTradeSkillInvSlotFilter(0, 1, 1)
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(info, niveau)
		info = UIDropDownMenu_CreateInfo()
		info.text = L.TRADESKILL_UNCHECK_ALL
		info.notCheckable = 1
		info.func = function()
			for i = 1, select("#", GetTradeSkillInvSlots()) do SetTradeSkillInvSlotFilter(i, 0, 0) end
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(info, niveau)
		local tous = vrai(GetTradeSkillInvSlotFilter(0))
		for i = 1, select("#", GetTradeSkillInvSlots()) do
			info = UIDropDownMenu_CreateInfo()
			info.text = select(i, GetTradeSkillInvSlots())
			info.checked = tous or vrai(GetTradeSkillInvSlotFilter(i))
			info.keepShownOnClick = 1
			local index = i
			info.func = function(self)
				local coche = vrai(GetTradeSkillInvSlotFilter(0)) or vrai(GetTradeSkillInvSlotFilter(index))
				SetTradeSkillInvSlotFilter(index, coche and 0 or 1, 0)
			end
			UIDropDownMenu_AddButton(info, niveau)
		end
	end
end

-- ------------------------------------------------------------ la fenetre

-- l'ecran du client : invisible et sans souris ; il reste l'hote
local function etouffer(f)
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	TradeSkillFrameTitleText:SetAlpha(0)
	TradeSkillFrameDummyString:SetAlpha(0)
	for i = 1, TRADE_SKILLS_DISPLAYED or 8 do
		local b = _G["TradeSkillSkill" .. i]
		if b then b:SetAlpha(0) b:EnableMouse(false) end
	end
	for _, nom in ipairs({ "TradeSkillListScrollFrame", "TradeSkillDetailScrollFrame", "TradeSkillHighlightFrame" }) do
		local fx = _G[nom]
		if fx then
			fx:SetAlpha(0)
			fx:EnableMouse(false)
			if fx.EnableMouseWheel then fx:EnableMouseWheel(false) end
			for _, s in ipairs({ "ScrollBar", "ScrollBarScrollUpButton", "ScrollBarScrollDownButton" }) do
				local c = _G[nom .. s]
				if c then c:EnableMouse(false) end
			end
		end
	end
	for i = 1, MAX_TRADE_SKILL_REAGENTS or 8 do
		local r = _G["TradeSkillReagent" .. i]
		if r then r:EnableMouse(false) end
	end
	if TradeSkillSkillIcon then TradeSkillSkillIcon:EnableMouse(false) end
	for _, c in ipairs({ TradeSkillLinkButton, TradeSkillFrameAvailableFilterCheckButton, TradeSkillRankFrame,
		TradeSkillFrameEditBox, TradeSkillExpandButtonFrame, TradeSkillInvSlotDropDown, TradeSkillSubClassDropDown,
		TradeSkillCreateButton, TradeSkillCreateAllButton, TradeSkillDecrementButton, TradeSkillInputBox,
		TradeSkillIncrementButton, TradeSkillCancelButton }) do
		if c then ForeverUI.Suppress(c) end
	end
end

-- APRES TradeSkillFrame_Update : titre, portrait, rang, liste
function M.Maj()
	local f = TradeSkillFrame
	local h = f and f.foreverHabit
	if not h then return end
	local nom = GetTradeSkillLine()
	local lie, joueur = IsTradeSkillLinked()
	if vrai(lie) and joueur then
		h.titre:SetText(string.format("%s %s[%s]|r", string.format(TRADE_SKILL_TITLE, nom or ""), HIGHLIGHT_FONT_COLOR_CODE, joueur))
	else
		h.titre:SetText(string.format(TRADE_SKILL_TITLE, nom or ""))
	end
	local _, icone = metier()
	if icone then
		SetPortraitToTexture(h.portrait, icone)
	else
		SetPortraitTexture(h.portrait, "player")
	end
	M.MajRang()
	Gb.Montrer(h.lien, not vrai(lie) and GetTradeSkillListLink() ~= nil)
	local _, rang = GetTradeSkillLine()
	local recherche = vrai(lie) or (rang or 0) >= 75
	Gb.Montrer(h.recherche, recherche)
	if not recherche and h.recherche:GetText() ~= "" then h.recherche:SetText("") end
	M.MajListe()
	M.MajFiche()
end

function M.Habiller()
	local f = TradeSkillFrame
	if not f or f.foreverHabit then return end
	etouffer(f)
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
	})
	f.foreverHabit = habit
	M.habit = habit
	-- OverrideArt : Profession-Background-Overview a la place de la roche,
	-- sans stries
	if habit.roche.SetHorizTile then
		habit.roche:SetHorizTile(false)
		habit.roche:SetVertTile(false)
	end
	atlas(habit.roche, "profession-background-overview", true)
	habit.stries:Hide()
	local base = f:GetFrameLevel()
	local NV = N.niveaux
	-- la page de fabrication
	local page = CreateFrame("Frame", "ForeverUITradeSkillPage", f)
	page:SetAllPoints(f)
	page:SetFrameLevel(base + NV.page)
	habit.page = page
	local fondPage = page:CreateTexture(nil, "BACKGROUND")
	atlas(fondPage, "profession-background-template2", true)
	fondPage:SetPoint("TOPLEFT", f, "TOPLEFT", N.page[1], N.page[2])
	habit.fondPage = fondPage
	-- la liste
	local Li = N.liste
	local liste = CreateFrame("Frame", "ForeverUITradeSkillRecipeList", page)
	liste:SetWidth(Li[3])
	liste:SetPoint("TOPLEFT", page, "TOPLEFT", Li[1], Li[2])
	liste:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", Li[1], Li.bas)
	liste:SetFrameLevel(base + NV.liste)
	habit.liste = liste
	local fondListe = liste:CreateTexture(nil, "BACKGROUND")
	atlas(fondListe, "professions-background-summarylist", true)
	fondListe:SetAllPoints(liste)
	local aucun = liste:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	aucun:SetWidth(N.aucun[3])
	aucun:SetPoint("TOP", liste, "TOP", N.aucun[1], N.aucun[2])
	aucun:SetText(L.TRADESKILL_NO_RESULTS)
	aucun:Hide()
	habit.aucun = aucun
	-- le filtre
	local Fi = N.filtre
	local dd = CreateFrame("Frame", "ForeverUITradeSkillFilter", liste, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(dd, initialiserFiltre)
	UIDropDownMenu_SetText(dd, FILTER)
	Gb.MenuFiltre(dd, Fi[3])
	-- la liste : au moins la largeur du bouton, et plus si ses entrees
	-- l'exigent (SetMinimumWidth de camelot ; demande du 28/09)
	dd.foreverPlancher = true
	poser(dd, "TOPRIGHT", liste, "TOPRIGHT", Fi[1], Fi[2])
	habit.filtre = dd
	-- la recherche (SearchBoxTemplate, comme le journal de quetes)
	local Re = N.recherche
	local r = CreateFrame("EditBox", "ForeverUITradeSkillSearchBox", liste)
	r:SetHeight(Re[3])
	r:SetPoint("TOPLEFT", liste, "TOPLEFT", Re[1], Re[2])
	r:SetPoint("RIGHT", dd, "LEFT", Re.ecart, 0)
	r:SetAutoFocus(false)
	r:SetMaxLetters(60)
	r:SetFontObject("GameFontHighlightSmall")
	r:SetTextInsets(16, 20, 0, 0)
	local function bord(prefixe)
		local g = r:CreateTexture(nil, "BACKGROUND")
		atlas(g, prefixe .. "-left", true)
		g:SetWidth(8) g:SetHeight(20)
		g:SetPoint("LEFT", r, "LEFT", -5, 0)
		local d = r:CreateTexture(nil, "BACKGROUND")
		atlas(d, prefixe .. "-right", true)
		d:SetWidth(8) d:SetHeight(20)
		d:SetPoint("RIGHT", r, "RIGHT", 0, 0)
		local m = r:CreateTexture(nil, "BACKGROUND")
		atlas(m, prefixe .. "-middle", true)
		m:SetPoint("TOPLEFT", g, "TOPRIGHT")
		m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	end
	bord("common-search-border")
	local loupe = r:CreateTexture(nil, "OVERLAY")
	atlas(loupe, "common-search-magnifyingglass", true)
	loupe:SetWidth(10) loupe:SetHeight(10)
	loupe:SetPoint("LEFT", r, "LEFT", 1, -1)
	local consigne = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	consigne:SetPoint("TOPLEFT", r, "TOPLEFT", 16, 0)
	consigne:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -20, 0)
	consigne:SetJustifyH("LEFT")
	consigne:SetTextColor(0.35, 0.35, 0.35)
	consigne:SetText(SEARCH)
	local effacer = CreateFrame("Button", nil, r)
	effacer:SetWidth(17) effacer:SetHeight(17)
	effacer:SetPoint("RIGHT", r, "RIGHT", -3, 0)
	local croix = effacer:CreateTexture(nil, "ARTWORK")
	atlas(croix, "common-search-clearbutton", true)
	croix:SetWidth(10) croix:SetHeight(10)
	croix:SetPoint("CENTER", effacer, "CENTER", 0, 0)
	croix:SetAlpha(0.5)
	effacer:SetScript("OnEnter", function() croix:SetAlpha(1) end)
	effacer:SetScript("OnLeave", function() croix:SetAlpha(0.5) end)
	effacer:SetScript("OnClick", function()
		r:SetText("")
		r:ClearFocus()
	end)
	effacer:Hide()
	r:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	r:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	r:SetScript("OnEditFocusGained", function() consigne:Hide() end)
	r:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then consigne:Show() end
	end)
	r:SetScript("OnTextChanged", function(self)
		local t = self:GetText()
		if t == "" then effacer:Hide() else effacer:Show() consigne:Hide() end
		SetTradeSkillItemNameFilter(t)
	end)
	habit.recherche = r
	-- la zone de la liste, a defilement
	local zone = CreateFrame("ScrollFrame", "ForeverUITradeSkillListScroll", liste)
	habit.zone = zone
	poserBarre(false)
	habit.avecBarre = false
	local enfant = CreateFrame("Frame", nil, zone)
	enfant:SetWidth(1)
	enfant:SetHeight(1)
	zone:SetScrollChild(enfant)
	enfant:SetFrameLevel(base + NV.lignes)
	habit.enfant = enfant
	habit.categories, habit.recettes, habit.decalage = {}, {}, 0
	local barre = ForeverUI.CreateScrollBar("ForeverUITradeSkillScrollBar", liste, zone)
	barre:ClearAllPoints()
	barre:SetPoint("TOPLEFT", zone, "TOPRIGHT", 0, 0)
	barre:SetPoint("BOTTOMLEFT", zone, "BOTTOMRIGHT", 0, 0)
	barre.surDefilement = function(pas)
		habit.decalage = pas
		M.MajListe()
	end
	habit.barre = barre
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(_, sens)
		if barre:IsShown() then barre:Deplacer(barre.decalage - sens * 3) end
	end)
	-- le rang
	local R = N.rang
	local rang = CreateFrame("Frame", "ForeverUITradeSkillRankBar", page)
	rang:SetWidth(R[3])
	rang:SetHeight(R[4])
	rang:SetPoint("TOPLEFT", page, "TOPLEFT", R[1], R[2])
	rang:SetFrameLevel(base + NV.rang)
	local fondRang = rang:CreateTexture(nil, "BACKGROUND")
	atlas(fondRang, "professions-skillbar-bg", true)
	fondRang:SetWidth(R.fond[1]) fondRang:SetHeight(R.fond[2])
	fondRang:SetPoint("TOPLEFT", rang, "TOPLEFT", 0, 0)
	local rempli = rang:CreateTexture(nil, "BORDER")
	rempli:SetHeight(R.rempli[2])
	rempli:SetPoint("TOPLEFT", rang, "TOPLEFT", R.rempli[3] + R.masque, R.rempli[4])
	local eclat = rang:CreateTexture(nil, "ARTWORK")
	eclat:SetWidth(R.eclat[1]) eclat:SetHeight(R.eclat[2])
	eclat:SetBlendMode("ADD")
	local cadreRang = rang:CreateTexture(nil, "OVERLAY")
	atlas(cadreRang, "professions-skillbar-frame", true)
	cadreRang:SetWidth(R.fond[1]) cadreRang:SetHeight(R.fond[2])
	cadreRang:SetPoint("TOPLEFT", rang, "TOPLEFT", 0, 0)
	local texteRang = CreateFrame("Frame", nil, rang)
	texteRang:SetHeight(R[4])
	texteRang:SetPoint("LEFT", rang, "LEFT", 0, R.texte)
	texteRang:SetPoint("RIGHT", rang, "RIGHT", 0, R.texte)
	texteRang:SetFrameLevel(rang:GetFrameLevel() + 1)
	local t = texteRang:CreateFontString(nil, "ARTWORK")
	t:SetFontObject(POLICES.rang)
	t:SetPoint("CENTER", texteRang, "CENTER", 0, 0)
	rang.rempli, rang.eclat, rang.texte = rempli, eclat, t
	habit.rang = rang
	-- le lien
	local Ln = N.lien
	local lien = CreateFrame("Button", "ForeverUITradeSkillLinkButton", page)
	lien:SetWidth(Ln[3]) lien:SetHeight(Ln[3])
	lien:SetPoint("LEFT", rang, "RIGHT", Ln[1], Ln[2])
	lien:SetFrameLevel(base + NV.rang)
	local fondLien = lien:CreateTexture(nil, "BACKGROUND")
	fondLien:SetWidth(Ln.fond) fondLien:SetHeight(Ln.fond)
	fondLien:SetPoint("CENTER", lien, "CENTER", 0, 0)
	local iconeLien = lien:CreateTexture(nil, "ARTWORK")
	atlas(iconeLien, "common-icon-chatlink", true)
	iconeLien:SetWidth(Ln.icone) iconeLien:SetHeight(Ln.icone)
	iconeLien:SetPoint("CENTER", lien, "CENTER", 0, 0)
	local function etatLien(etat) atlas(fondLien, "common-button-tertiary-square-" .. etat, true) end
	etatLien("normal")
	lien:SetScript("OnEnter", function(self)
		etatLien("hover")
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(LINK_TRADESKILL_TOOLTIP, nil, nil, nil, nil, 1)
		GameTooltip:Show()
	end)
	lien:SetScript("OnLeave", function()
		etatLien("normal")
		GameTooltip:Hide()
	end)
	lien:SetScript("OnMouseDown", function() etatLien("pressed") end)
	lien:SetScript("OnMouseUp", function(self) etatLien(self:IsMouseOver() and "hover" or "normal") end)
	lien:SetScript("OnClick", function()
		local l = GetTradeSkillListLink()
		if l and not ChatEdit_InsertLink(l) then
			ChatEdit_GetLastActiveWindow():Show()
			ChatEdit_InsertLink(l)
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	habit.lien = lien
	-- la fiche
	local Fc = N.fiche
	local fiche = CreateFrame("Frame", "ForeverUITradeSkillSchematic", page)
	fiche:SetWidth(Fc[3])
	fiche:SetHeight(Fc[4])
	fiche:SetPoint("TOPLEFT", liste, "TOPRIGHT", Fc[1], Fc[2])
	fiche:SetFrameLevel(base + NV.fiche)
	local F = { cadre = fiche }
	F.carte = fiche:CreateTexture(nil, "BACKGROUND")
	F.carte:SetAllPoints(fiche)
	local bordFiche = Gb.AtlasEtire(fiche, "common-insideframe", "BORDER")
	bordFiche.rect:SetAllPoints(fiche)
	-- le contenu de la recette (cache sans recette)
	local contenu = CreateFrame("Frame", nil, fiche)
	contenu:SetAllPoints(fiche)
	F.contenu = contenu
	local Rs = N.resultat
	local resultat = CreateFrame("Button", "ForeverUITradeSkillOutputIcon", contenu)
	resultat:SetWidth(Rs[3]) resultat:SetHeight(Rs[3])
	resultat:SetPoint("TOPLEFT", fiche, "TOPLEFT", Rs[1], Rs[2])
	resultat:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	F.resultat = resultat
	F.icone = resultat:CreateTexture(nil, "BORDER")
	F.icone:SetWidth(Rs.icone) F.icone:SetHeight(Rs.icone)
	F.icone:SetPoint("CENTER", resultat, "CENTER", 0, 0)
	F.contour = resultat:CreateTexture(nil, "OVERLAY")
	F.contour:SetWidth(Rs.contour) F.contour:SetHeight(Rs.contour)
	F.contour:SetPoint("CENTER", resultat, "CENTER", 0, 0)
	local lueur = resultat:CreateTexture(nil, "HIGHLIGHT")
	atlas(lueur, "auctionhouse-itemicon-border-white", true)
	lueur:SetWidth(Rs.lueur) lueur:SetHeight(Rs.lueur)
	lueur:SetPoint("CENTER", resultat, "CENTER", 0, 0)
	lueur:SetBlendMode("ADD")
	lueur:SetAlpha(0.2)
	local dessusResultat = CreateFrame("Frame", nil, resultat)
	dessusResultat:SetAllPoints(resultat)
	dessusResultat:SetFrameLevel(resultat:GetFrameLevel() + 1)
	F.nombre = dessusResultat:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	F.nombre:SetJustifyH("RIGHT")
	F.nombre:SetPoint("BOTTOM", resultat, "BOTTOMRIGHT", Rs.nombre[1], Rs.nombre[2])
	F.ombre = dessusResultat:CreateTexture(nil, "ARTWORK")
	atlas(F.ombre, "battlebar-swappetshadow", true)
	F.ombre:SetAlpha(0.8)
	F.ombre:SetPoint("TOPLEFT", F.nombre, "TOPLEFT", -10, 10)
	F.ombre:SetPoint("BOTTOMRIGHT", F.nombre, "BOTTOMRIGHT", 10, -10)
	F.ombre:Hide()
	resultat:SetScript("OnEnter", function(self)
		if not M.choisi then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetTradeSkillItem(M.choisi)
		GameTooltip:Show()
	end)
	resultat:SetScript("OnLeave", function() GameTooltip:Hide() end)
	resultat:SetScript("OnClick", function()
		if M.choisi then HandleModifiedItemClick(GetTradeSkillItemLink(M.choisi)) end
	end)
	F.nom = contenu:CreateFontString(nil, "ARTWORK")
	F.nom:SetFontObject(POLICES.med2)
	F.nom:SetJustifyH("LEFT")
	F.nom:SetJustifyV("TOP")
	F.nom:SetPoint("LEFT", resultat, "RIGHT", N.nom[1], N.nom[2])
	F.outils = contenu:CreateFontString(nil, "ARTWORK")
	F.outils:SetFontObject(POLICES.small2)
	F.outils:SetJustifyH("LEFT")
	F.outils:SetJustifyV("TOP")
	F.outils:SetPoint("TOPLEFT", F.nom, "BOTTOMLEFT", N.outils[1], N.outils[2])
	F.recharge = contenu:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
	F.recharge:SetJustifyH("LEFT")
	F.recharge:SetWidth(N.recharge)
	F.description = contenu:CreateFontString(nil, "ARTWORK")
	F.description:SetFontObject(POLICES.small2)
	F.description:SetJustifyH("LEFT")
	F.description:SetJustifyV("TOP")
	habit.fiche = F
	-- les reactifs
	local Rc = N.reactifs
	local reactifs = CreateFrame("Frame", "ForeverUITradeSkillReagents", contenu)
	reactifs:SetWidth(Rc.etiquette[1])
	reactifs:SetHeight(Rc.etiquette[2])
	local etiquette = reactifs:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
	etiquette:SetJustifyH("LEFT")
	etiquette:SetWidth(Rc.etiquette[1])
	etiquette:SetHeight(Rc.etiquette[2])
	etiquette:SetPoint("TOPLEFT", reactifs, "TOPLEFT", 0, 0)
	etiquette:SetText(L.TRADESKILL_REAGENTS)
	habit.reactifs, habit.emplacements = reactifs, {}
	-- les boutons
	creerBoutons(page)
	Gb.Croix(TradeSkillFrameCloseButton, f)
	TradeSkillFrameCloseButton:SetFrameLevel(base + NV.croix)
	hooksecurefunc("TradeSkillFrame_Update", M.Maj)
	hooksecurefunc("TradeSkillFrame_SetSelection", M.MajFiche)
end

M.Habiller()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:RegisterEvent("UPDATE_TRADESKILL_RECAST")
veille:SetScript("OnEvent", function(_, evenement, nom)
	if evenement == "ADDON_LOADED" then
		if nom == "Blizzard_TradeSkillUI" then M.Habiller() end
	elseif M.habit and TradeSkillFrame:IsShown() and M.habit.boutons.compteur.actif then
		M.habit.boutons.compteur:SetNumber(GetTradeskillRepeatCount())
		M.MajFleches()
	end
end)
