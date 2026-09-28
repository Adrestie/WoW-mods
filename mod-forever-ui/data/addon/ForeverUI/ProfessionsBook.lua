-- ForeverUI : le livre des metiers de camelot -- la page d'ensemble de sa
-- fenetre des metiers (ProfessionsFrame.BookPage), que le micro-bouton des
-- metiers ouvre (BottomBar.lua). Chantier des PNJ, etape 4 (demande du
-- 2026-09-28 : « ajouter le micro bouton "Professions" a cote de la feuille
-- de personnage et faire le menu »), puis ses onglets lateraux (« fais la
-- suite de l'etape 4 », voir la section des onglets).
--
-- RELEVE -- CAMELOT (blizzard_professionsbook : camelot/blizzard_professions-
-- book.lua, camelot/blizzard_professionsbooktemplates.xml, blizzard_-
-- professionsbook.lua / templates.xml / _bootstrap.lua ; blizzard_-
-- professions : camelot/blizzard_professionsframe.xml / .lua ; blizzard_-
-- professionstemplates : rankbar ; blizzard_micromenu : mainline/mainmenubar-
-- microbuttons.lua ; tables DB2 GlobalStrings, GlobalColor, UiTextureAtlas-
-- Member / ElementSliceData) :
--   fenetre        ProfessionsFrame 673 x 594, celle de la page de fabrication
--                  (TradeSkill.lua) ; SelectBookPage : portrait INV_SideTab_-
--                  Professions_c60, titre TRADE_SKILL_TITLE de TRADE_SKILLS ;
--                  fond Profession-Background-Overview sans stries ; la page
--                  couvre toute la fenetre
--   metiers        GetProfessions : deux principaux, puis cuisine, peche,
--                  secourisme
--   principal      664 x 142 : le premier a (5, -41), le second sous lui a
--                  (0, 5) ; carte Profession-overview-Card-<metier> (sinon
--                  Profession-overview-Card) sur toute la carte ; nom
--                  GameFontNormal a (20, -24) ; rang 441, RIGHT (-40, 0) ;
--                  oubli 20 x 20 a droite du rang (1, -4) : Profession-button-
--                  red-crossmark a sa taille (-pressed enfonce), infobulle
--                  UNLEARN_SKILL_TOOLTIP, clic : boite UNLEARN_SKILL ; sorts a
--                  BOTTOMLEFT (15, 46) s'il n'y en a qu'un, sinon (15, 60) et
--                  (15, 10) ; absent : PROFESSIONS_FIRST_ / _SECOND_PROFESSION
--                  a (20, -24), PROFESSIONS_MISSING_PROFESSION GameFontHighlight-
--                  Small2 485 au centre
--   secondaire     225 x 275, le premier sous le second principal (0, 4), les
--                  autres a sa droite (-6, 0) : cuisine, peche, secourisme ;
--                  carte Profession-overview-card-generic-<metier> ; nom TOP
--                  (0, -25) ; rang 190, TOP (0, -47) ; jusqu'a quatre sorts
--                  empiles depuis BOTTOMLEFT (20, 25) ; absent : le nom du
--                  metier et PROFESSIONS_<METIER>_MISSING (175, TOP sous le
--                  nom (5, -13))
--   rang           ProfessionsRankBarTemplate, 18 de haut : fond Profession-
--                  ProgressBar-BG et cadre Profession-ProgressBar-frame
--                  (decoupe 30 / 0 / 30 / 0) a la largeur de la barre et a la
--                  hauteur de l'atlas ; remplissage 441 x 18 a (2, -3), vu de
--                  1 apres son debut sur largeur x part + decalage (-7 pour
--                  un principal, -5 pour un secondaire) ; eclat au bout,
--                  eteint si plein ; texte TRADESKILL_NAME_RANK Number12Font-
--                  Outline au centre (-3)
--   sort           40 x 40 : icone sous un masque carre rentre de 3, cadre
--                  Profession-square-frame (48) au centre ; nom GameFontNormal
--                  100 a RIGHT (5, 7), dore (PASSIVE_SPELL_FONT_COLOR pour un
--                  passif), rang NewSubSpellFont 95 x 28 dessous (0, -1) ;
--                  icone a 0,4 si le sort n'est pas utilisable ; survol
--                  ButtonHilight-Square (UI-PassiveHighlight pour un passif),
--                  enfonce UI-Quickslot-Depress ; jamais coche
--   ouverture      ToggleProfessionsBook : la fenetre s'ouvre ou se ferme ;
--                  sons IG_SPELLBOOK_OPEN / IG_ABILITY_CLOSE ; UNLEARN_SKILL
--                  se ferme avec elle
--
-- RELEVE -- 3.3.5 : ni GetProfessions ni GetProfessionInfo. Les metiers se
-- lisent dans les competences (GetSkillLineInfo : nom, rang, bonus, maximum,
-- abandonnable ; l'oubli par la boite UNLEARN_SKILL et AbandonSkill, comme
-- SkillFrame), leurs sorts dans le grimoire (GetSpellLink de chaque case
-- donne l'identifiant du sort).
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * La fenetre du livre est a nous : le TradeSkillFrame de 3.3.5 n'existe
--     que pendant une session de metier. Meme taille, meme place (panneau
--     "left", pushable 3, comme lui) ; elle se declare par ses attributs
--     UIPanelLayout-*, sans toucher a la table UIPanelWindows du client.
--     Ouvrir un metier (clic sur son sort) ferme le livre : la page de
--     fabrication prend sa place, comme chez camelot.
--   * Le metier est reconnu a son nom, compare a celui d'un sort qui porte
--     le meme (GetSpellInfo : la langue du client) : il choisit la carte et
--     la bande du rang.
--   * Les sorts d'une carte : ceux du grimoire que SkillLineAbility.dbc range
--     sous le metier (table SORTS), actifs seulement, dans un ordre fixe --
--     celui qui ouvre la fabrication d'abord. Minage : Fondre et Decouverte
--     de gisements ; herboristerie : Decouverte d'herbes et Sang-de-vie ;
--     depecage : son sort de rang. Camelot les tient de GetProfessionInfo.
--   * LANCER UN SORT EST PROTEGE : les boutons de sort sont securises, et la
--     fenetre qui les porte devient protegee. Elle se ferme donc a l'entree
--     en combat et ne s'ouvre pas pendant (ERR_NOT_IN_COMBAT) ; camelot
--     l'ouvre en combat.
--   * Une categorie de competences repliee est depliee le temps de la
--     lecture, puis repliee a nouveau.
--   * Les barres de rang restent dans la strate de la fenetre (camelot les
--     met en HIGH) ; leur bande est fixe (la premiere image, voir
--     TradeSkill.lua) ; pas de menu d'extension.
--   * Pas d'emplacements de barre montres a l'ouverture (MultiActionBar_-
--     ShowAllGrids toucherait aux boutons d'action proteges), pas de
--     clignotement de rappel de specialisation, pas d'aide.
--   * Joaillerie et calligraphie n'ont pas de carte chez camelot : la carte
--     generique, comme son code le prevoit.
--   * Le micro-bouton reste enfonce tant que les metiers sont ouverts (livre
--     ou fabrication), comme ses voisins ; chez camelot il ne l'est jamais
--     (il regarde ProfessionsBookFrame, que camelot ne charge pas).
--   * Le portrait est CUIT rond (tools/cuire_portrait.py) : SetPortraitTo-
--     Texture le laissait carre, hors de l'anneau (demande du 2026-09-28).
--
-- PLUS DE DEUX METIERS PRINCIPAUX (demande du 2026-09-28 : un serveur prive
-- peut en donner davantage ; camelot n'en connait que deux). Les rangees
-- sont dans une zone a defilement, au pas de camelot (142 de haut, 5 de
-- recouvrement : 137) :
--   * trois metiers : une troisieme rangee ; les colonnes cuisine, peche,
--     secourisme perdent sa hauteur (275 -> 138). Leurs sorts ne tiennent
--     plus empiles : ils passent en ligne, icones seules (le nom et le rang
--     restent dans l'infobulle) ;
--   * au-dela : la zone garde trois rangees, une barre de defilement parait
--     a droite, les rangees perdent sa place en largeur (664 -> 646), et les
--     suivantes, dessous, passent derriere les colonnes, invisibles ;
--   * une carte plus petite que son art n'est pas ecrasee : ses bords sont
--     gardes et une bande est rognee (le bord gauche d'une rangee, le bord
--     haut d'une colonne, 20).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits
local L = ForeverUI.L

local LM = {}
ForeverUI.LivreMetiers = LM

local SEP = string.char(92)
local POLICE = "Fonts" .. SEP .. "FRIZQT__.TTF"
local POLICE_CHIFFRES = "Fonts" .. SEP .. "ARIALN.TTF"
local BOUTONS = "Interface" .. SEP .. "Buttons" .. SEP
local ICONE_LIVRE = "Interface" .. SEP .. "ForeverUI" .. SEP .. "icons" .. SEP .. "inv_sidetab_professions_c60-rond"

local N = {
	fenetre = { 673, 594 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	principal = { 664, 142, x = 5, y = -41, ecart = 5 },
	secondaire = { 225, 275, ecart = 4, pas = -6 },
	-- plus de deux principaux : trois rangees visibles au plus, la barre
	-- (8, fleches de 17) dans une gouttiere de 18 a droite des rangees
	rangees = 3,
	gouttiere = 18,
	rogne = 20,
	enLigne = 5,
	nom = { 20, -24 },
	absent = 485,
	sortsPrincipal = { x = 15, seul = 46, haut = 60, bas = 10 },
	sortsSecondaire = { x = 20, y = 25 },
	sort = { cote = 40, masque = 3, texte = { 100, 5, 7 }, sous = { 95, 28, -1 } },
	rangPrincipal = { 441, x = -40, decalage = -7 },
	rangSecondaire = { 190, y = -47, decalage = -5 },
	rang = { h = 18, fond = 23, tranche = 30, rempli = { 441, 18, 2, -3 }, masque = 1, eclat = { 53, 16 }, texte = -3 },
	oubli = { 20, 1, -4 },
	secondaireNom = -25,
	secondaireTexte = { 175, 5, -13 },
	niveaux = { contenu = 1, zone = 1, rangees = 2, colonnes = 10, croix = 22 },
}

-- NORMAL_FONT_COLOR ; PASSIVE_SPELL_FONT_COLOR (GlobalColor de camelot,
-- 0xffc4a300)
local COULEURS = {
	normal = { 1, 0.82, 0 },
	passif = { 0.7686, 0.6392, 0 },
}

-- UIPanelWindows["TradeSkillFrame"] (Blizzard_TradeSkillUI.lua de 3.3.5),
-- plus whileDead, comme un grimoire ; la largeur de camelot, onglets
-- compris (professionsFrameWidthOverride), donnee aussi au TradeSkillFrame
local LARGEUR_PANNEAU = 750
local PANNEAU = { area = "left", pushable = 3, whileDead = 1, width = LARGEUR_PANNEAU }

-- LES METIERS. nom : un sort qui porte le nom du metier (Spell.dbc,
-- SkillLine.dbc) ; bande : Skillbar_Fill_Flipbook_<bande> ; secondaire :
-- sa place parmi les trois cartes du bas ; onglet : l'icone de son onglet
-- lateral (tabicons/), pour ceux qui ont une page de fabrication. SORTS : par groupe, les rangs d'un
-- meme sort (SkillLineAbility.dbc, sorts ni recettes ni caches), dans
-- l'ordre des cartes.
local METIERS = {
	alchemy = { nom = 2259, bande = "alchemy_c60", onglet = "trade_alchemy" },
	blacksmithing = { nom = 2018, bande = "blacksmithing", onglet = "trade_blacksmithing" },
	enchanting = { nom = 7411, bande = "enchanting_c60", onglet = "trade_engraving" },
	engineering = { nom = 4036, bande = "engineering", onglet = "trade_engineering" },
	herbalism = { nom = 9134, bande = "herbalism" },
	inscription = { nom = 45357, bande = "inscription", onglet = "inv_inscription_tradeskill01" },
	jewelcrafting = { nom = 25229, bande = "jewelcrafting", onglet = "inv_misc_gem_01" },
	leatherworking = { nom = 2108, bande = "leatherworking", onglet = "trade_leatherworking" },
	mining = { nom = 2575, bande = "mining", onglet = "trade_mining" },
	skinning = { nom = 8613, bande = "skinning_c60" },
	tailoring = { nom = 3908, bande = "tailoring", onglet = "trade_tailoring" },
	cooking = { nom = 2550, bande = "cooking", secondaire = 1, absent = L.PROFESSIONSBOOK_COOKING_MISSING,
		onglet = "inv_misc_food_15" },
	fishing = { nom = 7620, bande = "fishing", secondaire = 2, absent = L.PROFESSIONSBOOK_FISHING_MISSING },
	firstaid = { nom = 3273, bande = "firstaid_c60", secondaire = 3, absent = L.PROFESSIONSBOOK_FIRST_AID_MISSING,
		onglet = "spell_holy_sealofsacrifice" },
}
local SECONDAIRES = { "cooking", "fishing", "firstaid" }

local SORTS = {
	alchemy = { { 2259, 3101, 3464, 11611, 28596, 51304 } },
	blacksmithing = { { 2018, 3100, 3538, 9785, 29844, 51300 } },
	enchanting = { { 7411, 7412, 7413, 13920, 28029, 51313 }, { 13262 } },
	engineering = { { 4036, 4037, 4038, 12656, 30350, 51306 } },
	herbalism = { { 2383, 8387 }, { 55428, 55480, 55500, 55501, 55502, 55503 } },
	inscription = { { 45357, 45358, 45359, 45360, 45361, 45363 }, { 51005 } },
	jewelcrafting = { { 25229, 25230, 28894, 28895, 28897, 51311 }, { 31252 } },
	leatherworking = { { 2108, 3104, 3811, 10662, 32549, 51302 } },
	mining = { { 2656 }, { 2580, 8388 } },
	skinning = { { 8613, 8617, 8618, 10768, 32678, 50305 } },
	tailoring = { { 3908, 3909, 3910, 12180, 26790, 51309 } },
	cooking = { { 2550, 3102, 3413, 18260, 33359, 51296 }, { 818 } },
	fishing = { { 62734, 7620, 7731, 7732, 18248, 33095, 51294 }, { 43308 } },
	firstaid = { { 3273, 3274, 7924, 10846, 27028, 45542 } },
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

local function atlas(t, nom, taille)
	return ForeverUI.SetAtlas(t, nom, not taille)
end

local vrai = Gb.Vrai

-- les polices de camelot absentes de 3.3.5 (les memes objets que
-- TradeSkill.lua)
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
	small2 = police("ForeverUIFontHighlightSmall2", POLICE, 11),                           -- GameFontHighlightSmall2
	sous = police("ForeverUIFontNewSubSpell", POLICE, 10, nil, true, 0.82, 0.7, 0.54),     -- NewSubSpellFont
	rang = police("ForeverUIFontNumber12Outline", POLICE_CHIFFRES, 12, "OUTLINE"),         -- Number12FontOutline
}

-- ------------------------------------------------------------ la lecture

-- DEPLIER, LIRE, REPLIER. Replier et deplier annoncent SKILL_LINES_CHANGED :
-- le livre ne relit pas les annonces qui suivent sa propre lecture.
local silence = 0

local function deplier()
	local replies = {}
	local i = 1
	while i <= (GetNumSkillLines() or 0) do
		local nom, entete, deplie = GetSkillLineInfo(i)
		if vrai(entete) and not vrai(deplie) then
			replies[nom] = true
			ExpandSkillHeader(i)
		end
		i = i + 1
	end
	return replies
end

-- le nom de chaque metier dans la langue du client -> sa cle
local function nomsDesMetiers()
	local parNom = {}
	for cle, m in pairs(METIERS) do
		local nom = GetSpellInfo(m.nom)
		if nom then parNom[nom] = cle end
	end
	return parNom
end

-- les metiers du joueur : les principaux (deux chez camelot, davantage sur
-- un serveur prive), et les secondaires par cle
function LM.Lire()
	local parNom = nomsDesMetiers()
	local replies = deplier()
	local principaux, secondaires = {}, {}
	for i = 1, GetNumSkillLines() or 0 do
		local nom, entete, _, rang, _, bonus, maxi, abandon = GetSkillLineInfo(i)
		local cle = not vrai(entete) and parNom[nom]
		if cle then
			local m = { cle = cle, nom = nom, rang = rang or 0, maxi = maxi or 0, bonus = bonus or 0, abandon = vrai(abandon) }
			if METIERS[cle].secondaire then
				secondaires[cle] = m
			else
				principaux[#principaux + 1] = m
			end
		end
	end
	if next(replies) then
		for i = GetNumSkillLines() or 0, 1, -1 do
			local nom, entete, deplie = GetSkillLineInfo(i)
			if vrai(entete) and vrai(deplie) and replies[nom] then
				CollapseSkillHeader(i)
			end
		end
		silence = GetTime() + 0.5
	end
	return principaux, secondaires
end

-- le grimoire : identifiant du sort -> case
local function lireGrimoire()
	local cases = {}
	for onglet = 1, GetNumSpellTabs() or 0 do
		local _, _, decalage, nombre = GetSpellTabInfo(onglet)
		decalage = decalage or 0
		for slot = decalage + 1, decalage + (nombre or 0) do
			local lien = GetSpellLink(slot, BOOKTYPE_SPELL)
			local id = lien and tonumber(string.match(lien, "spell:(%d+)"))
			if id and not cases[id] then cases[id] = slot end
		end
	end
	return cases
end

-- les cases des sorts d'un metier : un par groupe, le plus haut rang present
local function sortsDu(cle, cases, maxi)
	local liste = {}
	for _, groupe in ipairs(SORTS[cle]) do
		for k = #groupe, 1, -1 do
			local slot = cases[groupe[k]]
			if slot then
				liste[#liste + 1] = slot
				break
			end
		end
		if #liste >= maxi then break end
	end
	return liste
end

-- l'indice d'une competence, pour AbandonSkill : sa categorie est depliee
-- s'il le faut (et le reste, la boite ouverte)
local function indiceDe(nom)
	for passe = 1, 2 do
		for i = 1, GetNumSkillLines() or 0 do
			local n, entete = GetSkillLineInfo(i)
			if n == nom and not vrai(entete) then return i end
		end
		if passe == 1 then deplier() end
	end
end

-- ------------------------------------------------------------ le rang

-- un element a decoupe 30 / 30 : ses bouts a leur taille, le milieu etire
local function troisTranches(hote, nom, largeur, hauteur, bout, couche)
	local e = ForeverUI.AtlasEntry(nom)
	if not e then return end
	local du = (e[3] - e[2]) * bout / e[6]
	local morceaux = {
		{ e[2], e[2] + du, 0, bout },
		{ e[2] + du, e[3] - du, bout, largeur - 2 * bout },
		{ e[3] - du, e[3], largeur - bout, bout },
	}
	for _, m in ipairs(morceaux) do
		local t = hote:CreateTexture(nil, couche)
		t:SetTexture(e[1])
		t:SetTexCoord(m[1], m[2], e[4], e[5])
		t:SetWidth(m[4])
		t:SetHeight(hauteur)
		t:SetPoint("TOPLEFT", hote, "TOPLEFT", m[3], 0)
	end
end

local function creerRang(carte, largeur, decalage)
	local R = N.rang
	local r = CreateFrame("Frame", nil, carte)
	r:SetWidth(largeur)
	r:SetHeight(R.h)
	r.largeur, r.decalage = largeur, decalage
	local fond = r:CreateTexture(nil, "BACKGROUND")
	atlas(fond, "profession-progressbar-bg")
	fond:SetWidth(largeur)
	fond:SetHeight(R.fond)
	fond:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
	local rempli = r:CreateTexture(nil, "BORDER")
	rempli:SetHeight(R.rempli[2])
	rempli:SetPoint("TOPLEFT", r, "TOPLEFT", R.rempli[3] + R.masque, R.rempli[4])
	local eclat = r:CreateTexture(nil, "ARTWORK")
	eclat:SetWidth(R.eclat[1])
	eclat:SetHeight(R.eclat[2])
	eclat:SetBlendMode("ADD")
	troisTranches(r, "profession-progressbar-frame", largeur, R.fond, R.tranche, "OVERLAY")
	local cadreTexte = CreateFrame("Frame", nil, r)
	cadreTexte:SetHeight(R.h)
	cadreTexte:SetPoint("LEFT", r, "LEFT", 0, R.texte)
	cadreTexte:SetPoint("RIGHT", r, "RIGHT", 0, R.texte)
	cadreTexte:SetFrameLevel(r:GetFrameLevel() + 1)
	local texte = cadreTexte:CreateFontString(nil, "ARTWORK")
	texte:SetFontObject(POLICES.rang)
	texte:SetPoint("CENTER", cadreTexte, "CENTER", 0, 0)
	r.fond, r.rempli, r.eclat, r.texte = fond, rempli, eclat, texte
	return r
end

-- ProfessionsRankBarMixin:Update, sans animation : texte, bande du metier
-- (sinon DefaultBlue) vue sur largeur x part + decalage, eclat au bout
local function majRang(r, m)
	local R = N.rang
	if m.bonus > 0 then
		r.texte:SetFormattedText(L.TRADESKILL_NAME_RANK_MODIFIER, m.nom, m.rang, m.bonus, m.maxi)
	else
		r.texte:SetFormattedText(L.TRADESKILL_NAME_RANK, m.nom, m.rang, m.maxi)
	end
	local bande = METIERS[m.cle].bande
	local e = ForeverUI.AtlasEntry("skillbar_fill_flipbook_" .. bande) or ForeverUI.AtlasEntry("skillbar_fill_flipbook_defaultblue")
	local eclat = ForeverUI.AtlasEntry("skillbar_flare_" .. bande)
	local part = m.maxi > 0 and math.min(m.rang / m.maxi, 1) or 0
	local vu = math.min(R.rempli[1] - R.masque, r.largeur * part + r.decalage)
	if e and vu >= 1 then
		r.rempli:SetTexture(e[1])
		local du = (e[3] - e[2]) / R.rempli[1]
		r.rempli:SetTexCoord(e[2] + du * R.masque, e[2] + du * (R.masque + vu), e[4], e[5])
		r.rempli:SetWidth(vu)
		r.rempli:Show()
	else
		r.rempli:Hide()
	end
	-- l'eclat, masque comme chez camelot : sa partie droite, a la largeur
	-- visible (voir TradeSkill.lua)
	if eclat and vu >= 1 then
		local l = math.min(R.eclat[1], vu)
		local du = (eclat[3] - eclat[2]) / R.eclat[1]
		r.eclat:SetTexture(eclat[1])
		r.eclat:SetTexCoord(eclat[3] - du * l, eclat[3], eclat[4], eclat[5])
		r.eclat:SetWidth(l)
		poser(r.eclat, "RIGHT", r, "TOPLEFT", R.rempli[3] + R.masque + vu, R.rempli[4] - R.rempli[2] / 2)
		r.eclat:SetAlpha(m.maxi > 0 and m.rang >= m.maxi and 0 or 1)
		r.eclat:Show()
	else
		r.eclat:Hide()
	end
end

-- ------------------------------------------------------------ les sorts

local nombreSorts = 0

-- ProfessionButtonTemplate, en bouton SECURISE (type "spell") : lancer un
-- sort est protege
local function creerSort(carte)
	nombreSorts = nombreSorts + 1
	local S = N.sort
	local nom = "ForeverUIProfessionsBookSpell" .. nombreSorts
	local b = CreateFrame("Button", nom, carte, "SecureActionButtonTemplate")
	b:SetWidth(S.cote)
	b:SetHeight(S.cote)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetAttribute("type", "spell")
	-- le clic modifie donne le lien dans la discussion, pas le sort
	b:SetAttribute("shift-type1", "lien")
	b:SetAttribute("shift-type2", "lien")
	local icone = b:CreateTexture(nil, "BORDER")
	icone:SetPoint("TOPLEFT", b, "TOPLEFT", S.masque, -S.masque)
	icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -S.masque, S.masque)
	local bord = S.masque / S.cote
	icone:SetTexCoord(bord, 1 - bord, bord, 1 - bord)
	local cadre = b:CreateTexture(nil, "OVERLAY")
	atlas(cadre, "profession-square-frame", true)
	cadre:SetPoint("CENTER", icone, "CENTER", 0, 0)
	b:SetPushedTexture(BOUTONS .. "UI-Quickslot-Depress")
	b:SetHighlightTexture(BOUTONS .. "ButtonHilight-Square")
	b:GetHighlightTexture():SetBlendMode("ADD")
	local recharge = CreateFrame("Cooldown", nom .. "Cooldown", b, "CooldownFrameTemplate")
	recharge:SetAllPoints(b)
	local texte = b:CreateFontString(nil, "BORDER", "GameFontNormal")
	texte:SetWidth(S.texte[1])
	texte:SetJustifyH("LEFT")
	texte:SetPoint("LEFT", b, "RIGHT", S.texte[2], S.texte[3])
	local sous = b:CreateFontString(nil, "BORDER")
	sous:SetFontObject(POLICES.sous)
	sous:SetWidth(S.sous[1])
	sous:SetHeight(S.sous[2])
	sous:SetJustifyH("LEFT")
	sous:SetJustifyV("TOP")
	sous:SetPoint("TOPLEFT", texte, "BOTTOMLEFT", 0, S.sous[3])
	b.icone, b.cadre, b.recharge, b.texte, b.sous = icone, cadre, recharge, texte, sous
	b:SetScript("OnEnter", function(self)
		if not self.slot then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpell(self.slot, BOOKTYPE_SPELL)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	b:SetScript("OnDragStart", function(self)
		if self.slot then PickupSpell(self.slot, BOOKTYPE_SPELL) end
	end)
	-- le lien : celui du metier s'il y en a un, sinon celui du sort
	b:SetScript("PostClick", function(self)
		if self.slot and IsModifiedClick("CHATLINK") then
			local lien, lienMetier = GetSpellLink(self.slot, BOOKTYPE_SPELL)
			if lienMetier or lien then ChatEdit_InsertLink(lienMetier or lien) end
		end
	end)
	b:Hide()
	return b
end

local function majRecharge(b)
	local debut, duree, actif = GetSpellCooldown(b.slot, BOOKTYPE_SPELL)
	CooldownFrame_SetTimer(b.recharge, debut or 0, duree or 0, actif or 0)
	if vrai(actif) then
		b.icone:SetVertexColor(1, 1, 1)
	else
		b.icone:SetVertexColor(0.4, 0.4, 0.4)
	end
end

-- UpdateButton : icone, nom, rang, recharge ; le sort que le bouton lance
-- ("Nom(Rang)", ce que SecureActionButton passe a CastSpellByName)
local function remplirSort(b, slot)
	b.slot = slot
	local nom, rang = GetSpellName(slot, BOOKTYPE_SPELL)
	local passif = IsPassiveSpell(slot, BOOKTYPE_SPELL)
	b:GetHighlightTexture():SetTexture(BOUTONS .. (passif and "UI-PassiveHighlight" or "ButtonHilight-Square"))
	local c = passif and COULEURS.passif or COULEURS.normal
	b.texte:SetTextColor(c[1], c[2], c[3])
	b.texte:SetText(nom)
	b.sous:SetText(rang or "")
	b.icone:SetTexture(GetSpellTexture(slot, BOOKTYPE_SPELL))
	majRecharge(b)
	if rang and rang ~= "" then
		b:SetAttribute("spell", nom .. "(" .. rang .. ")")
	else
		b:SetAttribute("spell", nom)
	end
end

-- ------------------------------------------------------------ l'oubli

function LM.Oublier(nom)
	local i = indiceDe(nom)
	if not i then return end
	local boite = StaticPopup_Show("UNLEARN_SKILL", nom)
	if boite then boite.data = i end
end

local function creerOubli(carte, rang)
	local O = N.oubli
	local b = CreateFrame("Button", nil, carte)
	b:SetWidth(O[1])
	b:SetHeight(O[1])
	b:SetPoint("LEFT", rang, "RIGHT", O[2], O[3])
	local icone = b:CreateTexture(nil, "ARTWORK")
	atlas(icone, "profession-button-red-crossmark", true)
	icone:SetPoint("CENTER", b, "CENTER", 0, 0)
	local enfonce = b:CreateTexture(nil, "OVERLAY")
	atlas(enfonce, "profession-button-red-crossmark-pressed", true)
	enfonce:SetPoint("CENTER", b, "CENTER", 0, 0)
	enfonce:Hide()
	b.icone, b.enfonce = icone, enfonce
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(UNLEARN_SKILL_TOOLTIP)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	b:SetScript("OnMouseDown", function(self) self.enfonce:Show() end)
	b:SetScript("OnMouseUp", function(self) self.enfonce:Hide() end)
	b:SetScript("OnClick", function()
		if carte.metier then LM.Oublier(carte.metier.nom) end
	end)
	return b
end

-- ------------------------------------------------------------ les cartes

-- LE FOND D'UNE CARTE. A la taille de son art : une piece. Plus etroite
-- (rangee a cote de la barre) ou plus basse (colonne sous trois rangees) :
-- l'art n'est pas ecrase, ses bords sont gardes -- le gauche d'une rangee,
-- le haut d'une colonne, sur N.rogne -- et le reste s'aligne sur le bord
-- oppose ; la bande entre les deux est rognee.
local function poserFond(c, nom)
	local e = ForeverUI.AtlasEntry(nom)
	if not e then return false end
	c.atlasFond = nom
	local W, H, B = e[6], e[7], N.rogne
	local l, h = c:GetWidth(), c:GetHeight()
	local du, dv = (e[3] - e[2]) / W, (e[5] - e[4]) / H
	local fond, bord = c.fond, c.fondBord
	fond:SetTexture(e[1])
	bord:SetTexture(e[1])
	fond:ClearAllPoints()
	if l < W then
		bord:ClearAllPoints()
		bord:SetTexCoord(e[2], e[2] + du * B, e[4], e[5])
		bord:SetWidth(B)
		bord:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		bord:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
		fond:SetTexCoord(e[3] - du * (l - B), e[3], e[4], e[5])
		fond:SetPoint("TOPLEFT", c, "TOPLEFT", B, 0)
		fond:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
		bord:Show()
	elseif h < H then
		bord:ClearAllPoints()
		bord:SetTexCoord(e[2], e[3], e[4], e[4] + dv * B)
		bord:SetHeight(B)
		bord:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		bord:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
		fond:SetTexCoord(e[2], e[3], e[5] - dv * (h - B), e[5])
		fond:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -B)
		fond:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
		bord:Show()
	else
		-- la bande cachee garde sa derniere place
		fond:SetTexCoord(e[2], e[3], e[4], e[5])
		fond:SetAllPoints(c)
		bord:Hide()
	end
	return true
end

local function creerFond(c)
	c.fond = c:CreateTexture(nil, "BACKGROUND")
	c.fondBord = c:CreateTexture(nil, "BACKGROUND")
	c.fondBord:Hide()
end

local function creerPrincipal(parent, n)
	local P = N.principal
	local c = CreateFrame("Frame", nil, parent)
	c:SetWidth(P[1])
	c:SetHeight(P[2])
	c.principal = true
	creerFond(c)
	c.nom = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	c.nom:SetJustifyH("LEFT")
	c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", N.nom[1], N.nom[2])
	c.absentTitre = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	c.absentTitre:SetJustifyH("LEFT")
	c.absentTitre:SetPoint("TOPLEFT", c, "TOPLEFT", N.nom[1], N.nom[2])
	if n == 1 then
		c.absentTitre:SetText(L.PROFESSIONSBOOK_FIRST_PROFESSION)
	else
		c.absentTitre:SetText(L.PROFESSIONSBOOK_SECOND_PROFESSION)
	end
	c.absentTexte = c:CreateFontString(nil, "OVERLAY")
	c.absentTexte:SetFontObject(POLICES.small2)
	c.absentTexte:SetWidth(N.absent)
	c.absentTexte:SetJustifyH("LEFT")
	c.absentTexte:SetPoint("CENTER", c, "CENTER", 0, 0)
	c.absentTexte:SetText(L.PROFESSIONSBOOK_MISSING_PROFESSION)
	local RP = N.rangPrincipal
	c.rang = creerRang(c, RP[1], RP.decalage)
	c.rang:SetPoint("RIGHT", c, "RIGHT", RP.x, 0)
	c.oubli = creerOubli(c, c.rang)
	c.sorts = { creerSort(c), creerSort(c) }
	return c
end

-- les colonnes passent DEVANT la zone des rangees : leur niveau est pose
-- avant que leurs enfants ne naissent
local function creerSecondaire(contenu, cle)
	local S = N.secondaire
	local c = CreateFrame("Frame", nil, contenu)
	c:SetFrameLevel(contenu:GetFrameLevel() + N.niveaux.colonnes)
	c:SetWidth(S[1])
	c:SetHeight(S[2])
	c.cle = cle
	creerFond(c)
	poserFond(c, "profession-overview-card-generic-" .. cle)
	c.nom = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	c.nom:SetJustifyH("LEFT")
	c.nom:SetPoint("TOP", c, "TOP", 0, N.secondaireNom)
	c.absentTitre = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	c.absentTitre:SetJustifyH("LEFT")
	c.absentTitre:SetPoint("TOP", c, "TOP", 0, N.secondaireNom)
	c.absentTitre:SetText(GetSpellInfo(METIERS[cle].nom) or "")
	local T = N.secondaireTexte
	c.absentTexte = c:CreateFontString(nil, "OVERLAY")
	c.absentTexte:SetFontObject(POLICES.small2)
	c.absentTexte:SetWidth(T[1])
	c.absentTexte:SetJustifyH("LEFT")
	c.absentTexte:SetJustifyV("TOP")
	c.absentTexte:SetPoint("TOP", c.absentTitre, "BOTTOM", T[2], T[3])
	c.absentTexte:SetText(METIERS[cle].absent)
	local RS = N.rangSecondaire
	c.rang = creerRang(c, RS[1], RS.decalage)
	c.rang:SetPoint("TOP", c, "TOP", 0, RS.y)
	c.sorts = {}
	for k = 1, 4 do
		c.sorts[k] = creerSort(c)
	end
	return c
end

-- les sorts d'une colonne : empiles depuis le bas (camelot) ; en ligne,
-- icones seules, quand la colonne a perdu la hauteur d'une rangee
local function poserSortsColonne(c)
	local SS = N.sortsSecondaire
	for k, b in ipairs(c.sorts) do
		if k == 1 then
			poser(b, "BOTTOMLEFT", c, "BOTTOMLEFT", SS.x, SS.y)
		elseif c.reduite then
			poser(b, "LEFT", c.sorts[k - 1], "RIGHT", N.enLigne, 0)
		else
			poser(b, "BOTTOM", c.sorts[k - 1], "TOP", 0, 0)
		end
		Gb.Montrer(b.texte, not c.reduite)
		Gb.Montrer(b.sous, not c.reduite)
	end
end

-- FormatProfession
local function formater(c, m, cases)
	if c.principal then
		poserFond(c, "profession-overview-card")
	end
	c.metier = m
	if not m then
		c.absentTitre:Show()
		c.absentTexte:Show()
		for _, b in ipairs(c.sorts) do
			b.slot = nil
			b:Hide()
		end
		c.rang:Hide()
		c.nom:SetText("")
		if c.oubli then c.oubli:Hide() end
		return
	end
	c.absentTitre:Hide()
	c.absentTexte:Hide()
	c.nom:SetText(m.nom)
	if c.principal then
		poserFond(c, "profession-overview-card-" .. m.cle)
		Gb.Montrer(c.oubli, m.abandon)
	end
	majRang(c.rang, m)
	c.rang:Show()
	local slots = sortsDu(m.cle, cases, #c.sorts)
	for k, b in ipairs(c.sorts) do
		if slots[k] then
			remplirSort(b, slots[k])
			b:Show()
		else
			b.slot = nil
			b:Hide()
		end
	end
	if c.principal then
		local SP = N.sortsPrincipal
		if #slots == 1 then
			poser(c.sorts[1], "BOTTOMLEFT", c, "BOTTOMLEFT", SP.x, SP.seul)
		else
			poser(c.sorts[1], "BOTTOMLEFT", c, "BOTTOMLEFT", SP.x, SP.haut)
			poser(c.sorts[2], "BOTTOMLEFT", c, "BOTTOMLEFT", SP.x, SP.bas)
		end
	end
end

-- les rangees hors de la zone sont CACHEES, pas seulement hors champ : leurs
-- sorts sont des boutons securises, qu'aucun clic ne doit trouver sous les
-- colonnes ou au-dessus de la fenetre. Le defilement va de rangee en
-- rangee : les rangees visibles sont entieres.
local function montrerRangees(f)
	local visibles = math.min(f.nombre, N.rangees)
	local d = LM.decalage or 0
	for k, c in ipairs(f.principaux) do
		Gb.Montrer(c, k <= f.nombre and k > d and k <= d + visibles)
	end
end

-- LA DISPOSITION, selon le nombre de rangees : deux au moins (camelot) ;
-- trois visibles au plus, les colonnes perdant alors la hauteur d'une
-- rangee ; au-dela, la barre et sa gouttiere.
local function disposer(f, nombre)
	local P, S = N.principal, N.secondaire
	local pas = P[2] - P.ecart
	local visibles = math.min(nombre, N.rangees)
	local avec = nombre > N.rangees
	local largeur = P[1] - (avec and N.gouttiere or 0)
	for k = #f.principaux + 1, nombre do
		local c = creerPrincipal(f.enfant, k)
		c:SetPoint("TOPLEFT", f.principaux[k - 1], "BOTTOMLEFT", 0, P.ecart)
		f.principaux[k] = c
	end
	for _, c in ipairs(f.principaux) do
		c:SetWidth(largeur)
	end
	f.nombre = nombre
	f.zone:SetWidth(largeur)
	f.zone:SetHeight(visibles * pas + P.ecart)
	f.enfant:SetWidth(largeur)
	f.enfant:SetHeight(nombre * pas + P.ecart)
	local reduite = visibles > 2
	for _, c in ipairs(f.secondaires) do
		c.reduite = reduite
		c:SetHeight(S[2] - (reduite and pas or 0))
		poserFond(c, c.atlasFond)
		poserSortsColonne(c)
	end
	LM.decalage = math.max(0, math.min(LM.decalage or 0, nombre - visibles))
	f.barre:Regler(nombre, visibles, LM.decalage)
	f.zone:SetVerticalScroll(LM.decalage * pas)
	montrerRangees(f)
end

-- ProfessionsBookFrameMixin:Update. Hors combat seulement : les boutons de
-- sort sont proteges (et le livre est ferme en combat).
function LM.Maj()
	local f = LM.livre
	if not f or not f:IsShown() or InCombatLockdown() then return end
	local principaux, secondaires = LM.Lire()
	local cases = lireGrimoire()
	disposer(f, math.max(2, #principaux))
	for i, c in ipairs(f.principaux) do
		if i <= f.nombre then formater(c, principaux[i], cases) end
	end
	for _, c in ipairs(f.secondaires) do
		formater(c, secondaires[c.cle], cases)
	end
end

local function majRecharges()
	local f = LM.livre
	for _, liste in ipairs({ f.principaux, f.secondaires }) do
		for _, c in ipairs(liste) do
			for _, b in ipairs(c.sorts) do
				if b.slot then majRecharge(b) end
			end
		end
	end
end

-- ------------------------------------------------------------ le deplacement

-- LA FENETRE SE DEPLACE PAR SA BANDE DE TITRE (demande du 2026-09-28 : « la
-- fenetre de profession doit etre deplacable » ; camelot ne le permet pas).
-- Le livre et la page de fabrication sont une seule fenetre chez camelot :
-- une seule place retenue pour les deux (ForeverUIDB.positions.metiers, le
-- haut-centre depuis celui d'UIParent, comme l'inspection). Le systeme de
-- panneaux les repose a chaque ouverture : la place revient apres lui
-- (OnShow, UpdateUIPanelPositions). Les onglets suivent pendant le glisser.
-- Le livre, protege, ne bouge que hors combat -- il est ferme pendant.
local CLE_PLACE = "metiers"

local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

-- le haut-centre d'un cadre, depuis celui d'UIParent (nil tant que le
-- cadre n'est pas place)
local function hautCentre(cadre)
	local cx, ux = cadre:GetCenter(), UIParent:GetCenter()
	local haut, uHaut = cadre:GetTop(), UIParent:GetTop()
	if not cx or not ux or not haut or not uHaut then return end
	return cx - ux, haut - uHaut
end

local function bloque(f)
	return f == LM.livre and InCombatLockdown()
end

function LM.Reposer(f)
	local p = positions()[CLE_PLACE]
	if not p or not f or not f:IsShown() or bloque(f) then return end
	f:ClearAllPoints()
	f:SetPoint("TOP", UIParent, "TOP", p.x, p.y)
end

local function rendreDeplacable(f, poignee)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	poignee:EnableMouse(true)
	poignee:RegisterForDrag("LeftButton")
	poignee:SetScript("OnDragStart", function()
		if bloque(f) then return end
		f:StartMoving()
		poignee:SetScript("OnUpdate", function() LM.PoserOnglets() end)
	end)
	poignee:SetScript("OnDragStop", function()
		poignee:SetScript("OnUpdate", nil)
		if bloque(f) then return end
		f:StopMovingOrSizing()
		local x, y = hautCentre(f)
		if x then
			f:ClearAllPoints()
			f:SetPoint("TOP", UIParent, "TOP", x, y)
			-- la place est a nous : le client ne la retient pas en plus
			if f.SetUserPlaced then f:SetUserPlaced(false) end
			positions()[CLE_PLACE] = { x = x, y = y }
		end
		LM.PoserOnglets()
	end)
end

-- ------------------------------------------------------------ la fenetre

function LM.Ouvert()
	return (LM.livre and LM.livre:IsShown()) or (TradeSkillFrame and TradeSkillFrame:IsShown()) or false
end

local function majMicro()
	if ForeverUI.MajMicroMetiers then
		ForeverUI.MajMicroMetiers(LM.Ouvert())
	end
end

-- une page s'ouvre ou se ferme : le micro-bouton et les onglets suivent
local function actualiser()
	majMicro()
	if LM.MajOnglets then LM.MajOnglets() end
end

local EVENEMENTS_OUVERT = { "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN" }

function LM.Construire()
	if LM.livre then return LM.livre end
	local f = CreateFrame("Frame", "ForeverUIProfessionsBook", UIParent)
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:Hide()
	-- le panneau, declare par ses attributs (GetUIPanelWindowInfo les lit
	-- avant la table UIPanelWindows) ; poses avant les boutons securises
	for k, v in pairs(PANNEAU) do
		f:SetAttribute("UIPanelLayout-" .. k, v)
	end
	f:SetAttribute("UIPanelLayout-defined", true)
	f:SetAttribute("UIPanelLayout-enabled", true)
	local habit = Gb.FenetrePortrait(f, {
		portrait = ICONE_LIVRE, portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = string.format(TRADE_SKILL_TITLE, TRADE_SKILLS),
	})
	-- le portrait cuit rond : pose tel quel
	habit.portrait:SetTexCoord(0, 1, 0, 1)
	-- OverrideArt : Profession-Background-Overview a la place de la roche,
	-- sans stries
	if habit.roche.SetHorizTile then
		habit.roche:SetHorizTile(false)
		habit.roche:SetVertTile(false)
	end
	atlas(habit.roche, "profession-background-overview", true)
	habit.stries:Hide()
	f.habit = habit
	rendreDeplacable(f, habit.bandeau)
	local contenu = CreateFrame("Frame", "ForeverUIProfessionsBookContent", f)
	contenu:SetAllPoints(f)
	contenu:SetFrameLevel(f:GetFrameLevel() + N.niveaux.contenu)
	f.contenu = contenu
	-- la zone des rangees : ce qui depasse ses trois rangees ne se voit pas
	local P, S, NV = N.principal, N.secondaire, N.niveaux
	local zone = CreateFrame("ScrollFrame", "ForeverUIProfessionsBookScroll", contenu)
	zone:SetFrameLevel(contenu:GetFrameLevel() + NV.zone)
	zone:SetPoint("TOPLEFT", contenu, "TOPLEFT", P.x, P.y)
	local enfant = CreateFrame("Frame", "ForeverUIProfessionsBookRows", zone)
	enfant:SetFrameLevel(contenu:GetFrameLevel() + NV.rangees)
	enfant:SetWidth(P[1])
	enfant:SetHeight(1)
	zone:SetScrollChild(enfant)
	f.zone, f.enfant = zone, enfant
	-- MinimalScrollBar, contre la zone ; un cran de molette : une rangee
	local barre = ForeverUI.CreateScrollBar("ForeverUIProfessionsBookScrollBar", contenu, zone)
	barre:SetFrameLevel(contenu:GetFrameLevel() + NV.zone)
	barre.surDefilement = function(pas)
		LM.decalage = pas
		zone:SetVerticalScroll(pas * (P[2] - P.ecart))
		montrerRangees(f)
	end
	barre:Hide()
	f.barre = barre
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(_, sens)
		if barre:IsShown() then barre:Deplacer(barre.decalage - sens) end
	end)
	-- les cartes
	f.principaux = { creerPrincipal(enfant, 1), creerPrincipal(enfant, 2) }
	f.principaux[1]:SetPoint("TOPLEFT", enfant, "TOPLEFT", 0, 0)
	f.principaux[2]:SetPoint("TOPLEFT", f.principaux[1], "BOTTOMLEFT", 0, P.ecart)
	f.secondaires = {}
	for k, cle in ipairs(SECONDAIRES) do
		local c = creerSecondaire(contenu, cle)
		if k == 1 then
			c:SetPoint("TOPLEFT", zone, "BOTTOMLEFT", 0, S.ecart)
		else
			c:SetPoint("TOPLEFT", f.secondaires[k - 1], "TOPRIGHT", S.pas, 0)
		end
		f.secondaires[k] = c
	end
	disposer(f, 2)
	-- la croix (UIPanelCloseButton : HideParentPanel)
	local croix = CreateFrame("Button", "ForeverUIProfessionsBookCloseButton", f, "UIPanelCloseButton")
	Gb.Croix(croix, f)
	croix:SetFrameLevel(f:GetFrameLevel() + N.niveaux.croix)
	f.croix = croix
	f:SetScript("OnShow", function(self)
		LM.Reposer(self)
		for _, ev in ipairs(EVENEMENTS_OUVERT) do self:RegisterEvent(ev) end
		LM.Maj()
		PlaySound("igSpellBookOpen")
		actualiser()
	end)
	f:SetScript("OnHide", function(self)
		for _, ev in ipairs(EVENEMENTS_OUVERT) do self:UnregisterEvent(ev) end
		StaticPopup_Hide("UNLEARN_SKILL")
		PlaySound("igAbilityClose")
		actualiser()
	end)
	f:SetScript("OnEvent", function(_, ev)
		if ev == "SPELL_UPDATE_COOLDOWN" then
			majRecharges()
		elseif ev ~= "SKILL_LINES_CHANGED" or GetTime() >= silence then
			LM.Maj()
		end
	end)
	LM.livre = f
	return f
end

-- ------------------------------------------------------------ les onglets

-- LES ONGLETS LATERAUX (camelot/blizzard_professionsframe.xml / .lua,
-- blizzard_professionstemplates : ProfessionsLargeRightTabMixin ; blizzard_-
-- sharedxml : LargeSideTabButtonTemplate). Ceux de la fenetre des metiers :
-- ils se tiennent a droite de la page montree, livre ou fabrication.
--   ensemble   ProfessionsOverviewTab, TOPLEFT sur le TOPRIGHT de la
--              fenetre (0, -60) : icone INV_SideTab_Professions_c60,
--              infobulle TRADE_SKILLS ; clic : la page d'ensemble
--   metiers    Professions1..7Tab, chacun sous le precedent (0, -2) :
--              RefreshRightTabs -- les principaux, puis secourisme, peche,
--              cuisine (l'ordre de GetProfessions), seulement ceux qui ont
--              une fabrication (CanTradeSkillShowCraftingUI) ; icone de la
--              competence, infobulle son nom ; clic : son sort
--              (CastProfessionSpell, sauf s'il est deja ouvert), la page de
--              fabrication
--   onglet     55 x 55 (common-sidetab sans ses 5 du bas) ; icone 50 x 50
--              (fillToInterior) rognee de 0,03125 ; enfonce : l'icone de
--              (1, -1), son IG_CHARACTER_INFO_TAB au relachement ; choisi :
--              common-sidetab-selected ; survol common-sidetab-hover ;
--              infobulle ANCHOR_RIGHT (-4, -4)
--   panneau    largeur 750 (professionsFrameWidthOverride) : la place des
--              onglets est retenue a droite de la fenetre
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * Un onglet de metier LANCE UN SORT : c'est un bouton securise, et le
--     cadre qui les porte devient protege. Il est donc a part, enfant de
--     UIParent, pose a droite de la fenetre montree -- ni enfant ni ancre
--     de TradeSkillFrame, que cela rendrait protege a son tour. Il suit la
--     fenetre a chaque placement des panneaux (UpdateUIPanelPositions), et
--     disparait en combat, comme le livre.
--   * L'icone est a (-3, 0), comme tous les onglets lateraux deja valides
--     de l'atelier, et cuite au masque (tools/cuire_masque.py). Camelot la
--     pose a (-4, 0) (camelot/shareduipaneltemplates.lua).
--   * L'onglet d'ensemble ferme la page de fabrication (la session de
--     metier de 3.3.5 prend fin avec sa fenetre) et ouvre le livre.
--   * Joaillerie et calligraphie, absentes de camelot, ont l'icone de leur
--     competence en 3.3.5.
--   * TROP D'ONGLETS POUR LA HAUTEUR DE LA FENETRE (serveur prive ; demande
--     du 2026-09-28, par anticipation) : ils retrecissent ensemble -- onglet,
--     icone, ecart, decalage de l'icone -- pour que le dernier finisse au
--     plus au bas de la fenetre. Le premier garde sa place (-60), et tous
--     restent colles au bord droit de la fenetre.
local ONGLET = { cote = 55, y = -60, ecart = -2, icone = 50, iconeX = -3, rognage = 0.03125 }
local ICONES_ONGLETS = "Interface" .. SEP .. "ForeverUI" .. SEP .. "tabicons" .. SEP
local ONGLETS_SECONDAIRES = { "firstaid", "fishing", "cooking" }

local function creerOnglet(parent, nom, securise)
	local O = ONGLET
	local b = CreateFrame("Button", nom, parent, securise and "SecureActionButtonTemplate" or nil)
	b:SetWidth(O.cote)
	b:SetHeight(O.cote)
	b:RegisterForClicks("LeftButtonUp")
	local fond = b:CreateTexture(nil, "BACKGROUND")
	atlas(fond, "common-sidetab")
	fond:SetAllPoints(b)
	local icone = b:CreateTexture(nil, "ARTWORK")
	icone:SetWidth(O.icone)
	icone:SetHeight(O.icone)
	icone:SetPoint("CENTER", b, "CENTER", O.iconeX, 0)
	icone:SetTexCoord(O.rognage, 1 - O.rognage, O.rognage, 1 - O.rognage)
	b.iconeX = O.iconeX
	local choisi = b:CreateTexture(nil, "OVERLAY")
	atlas(choisi, "common-sidetab-selected")
	choisi:SetAllPoints(b)
	choisi:Hide()
	local survol = b:CreateTexture(nil, "HIGHLIGHT")
	atlas(survol, "common-sidetab-hover")
	survol:SetAllPoints(b)
	b.icone, b.choisi = icone, choisi
	b:SetScript("OnEnter", function(self)
		if not self.infobulle then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
		GameTooltip:SetText(self.infobulle)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnMouseDown", function(self, bouton)
		if bouton == "LeftButton" then poser(self.icone, "CENTER", self, "CENTER", self.iconeX + 1, -1) end
	end)
	b:SetScript("OnMouseUp", function(self, bouton)
		if bouton == "LeftButton" then
			poser(self.icone, "CENTER", self, "CENTER", self.iconeX, 0)
			PlaySound("igCharacterInfoTab")
		end
	end)
	return b
end

-- SelectBookPage : la page de fabrication se ferme, le livre s'ouvre
function LM.PageEnsemble()
	if InCombatLockdown() or (LM.livre and LM.livre:IsShown()) then return end
	if TradeSkillFrame and TradeSkillFrame:IsShown() then HideUIPanel(TradeSkillFrame) end
	ShowUIPanel(LM.Construire())
end

local function creerOnglets()
	local c = CreateFrame("Frame", "ForeverUIProfessionsTabs", UIParent)
	c:SetWidth(ONGLET.cote)
	c:SetHeight(1)
	c:Hide()
	local ensemble = creerOnglet(c, "ForeverUIProfessionsTab0")
	ensemble.icone:SetTexture(ICONES_ONGLETS .. "inv_sidetab_professions_c60")
	ensemble.infobulle = TRADE_SKILLS
	ensemble:SetPoint("TOPLEFT", c, "TOPLEFT", 0, ONGLET.y)
	ensemble:SetScript("OnClick", LM.PageEnsemble)
	c.ensemble, c.metiers, c.nombre = ensemble, {}, 0
	LM.onglets = c
	return c
end

local function ongletMetier(c, k)
	if not c.metiers[k] then
		local b = creerOnglet(c, "ForeverUIProfessionsTab" .. k, true)
		b:SetPoint("TOPLEFT", k == 1 and c.ensemble or c.metiers[k - 1], "BOTTOMLEFT", 0, ONGLET.ecart)
		c.metiers[k] = b
	end
	return c.metiers[k]
end

-- le sort qui ouvre la fabrication d'un metier : le premier groupe
local function ouvreur(cle, cases)
	local groupe = SORTS[cle][1]
	for k = #groupe, 1, -1 do
		if cases[groupe[k]] then return cases[groupe[k]] end
	end
end

local function fenetreMontree()
	if LM.livre and LM.livre:IsShown() then return LM.livre end
	if TradeSkillFrame and TradeSkillFrame:IsShown() then return TradeSkillFrame end
end

-- la taille des onglets selon leur nombre et la hauteur de la fenetre ;
-- refaite seulement quand l'un ou l'autre change (PoserOnglets tourne a
-- chaque image pendant un glisser)
local function dimensionner(c, hauteur)
	local O = ONGLET
	local n = c.nombre + 1
	local plein = n * O.cote - (n - 1) * O.ecart
	local place = hauteur + O.y
	local e = (place > 0 and plein > place) and place / plein or 1
	if e == c.echelle and #c.metiers == c.dimensionnes then return e end
	c.echelle, c.dimensionnes = e, #c.metiers
	local liste = { c.ensemble }
	for k = 1, #c.metiers do liste[k + 1] = c.metiers[k] end
	for k, b in ipairs(liste) do
		b:SetWidth(O.cote * e)
		b:SetHeight(O.cote * e)
		b.iconeX = O.iconeX * e
		b.icone:SetWidth(O.icone * e)
		b.icone:SetHeight(O.icone * e)
		poser(b.icone, "CENTER", b, "CENTER", b.iconeX, 0)
		if k > 1 then poser(b, "TOPLEFT", liste[k - 1], "BOTTOMLEFT", 0, O.ecart * e) end
	end
	return e
end

-- a droite de la fenetre montree, dans sa strate, sous son metal
function LM.PoserOnglets()
	local c = LM.onglets
	if not c or InCombatLockdown() then return end
	local f = fenetreMontree()
	local droite, haut = f and f:GetRight(), f and f:GetTop()
	if not droite or not haut then
		c:Hide()
		return
	end
	local e = dimensionner(c, f:GetHeight() or 0)
	c:ClearAllPoints()
	c:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", droite, haut)
	c:SetHeight(-ONGLET.y + (c.nombre + 1) * (ONGLET.cote - ONGLET.ecart) * e)
	c:SetFrameStrata(f:GetFrameStrata())
	c:SetFrameLevel(f:GetFrameLevel() + 1)
	c:Show()
end

-- RefreshRightTabs et RightTabSelected. Hors combat seulement (boutons
-- securises).
function LM.MajOnglets()
	if InCombatLockdown() then return end
	local f = fenetreMontree()
	if not f then
		if LM.onglets then LM.onglets:Hide() end
		return
	end
	local c = LM.onglets or creerOnglets()
	local principaux, secondaires = LM.Lire()
	local cases = lireGrimoire()
	local liste = {}
	local function ajouter(m)
		local slot = m and METIERS[m.cle].onglet and ouvreur(m.cle, cases)
		if slot then liste[#liste + 1] = { m = m, slot = slot } end
	end
	for _, m in ipairs(principaux) do ajouter(m) end
	for _, cle in ipairs(ONGLETS_SECONDAIRES) do ajouter(secondaires[cle]) end
	-- le metier ouvert : celui de la page de fabrication, s'il est le notre
	local ouvert
	if f == TradeSkillFrame and not vrai(IsTradeSkillLinked()) then
		ouvert = nomsDesMetiers()[GetTradeSkillLine() or ""]
	end
	Gb.Montrer(c.ensemble.choisi, f == LM.livre)
	for k, e in ipairs(liste) do
		local b = ongletMetier(c, k)
		local nom, rang = GetSpellName(e.slot, BOOKTYPE_SPELL)
		local choisi = e.m.cle == ouvert
		b.cle = e.m.cle
		b.icone:SetTexture(ICONES_ONGLETS .. METIERS[e.m.cle].onglet)
		b.infobulle = e.m.nom
		Gb.Montrer(b.choisi, choisi)
		if choisi then
			b:SetAttribute("type", nil)
		else
			b:SetAttribute("type", "spell")
		end
		if rang and rang ~= "" then
			b:SetAttribute("spell", nom .. "(" .. rang .. ")")
		else
			b:SetAttribute("spell", nom)
		end
		b:Show()
	end
	for k = #liste + 1, #c.metiers do c.metiers[k]:Hide() end
	c.nombre = #liste
	LM.PoserOnglets()
end

-- ToggleProfessionsBook : le livre, ou la page de fabrication ouverte, se
-- ferme ; sinon le livre s'ouvre -- hors combat (voir plus haut)
function LM.Basculer()
	if LM.livre and LM.livre:IsShown() then
		HideUIPanel(LM.livre)
	elseif TradeSkillFrame and TradeSkillFrame:IsShown() then
		HideUIPanel(TradeSkillFrame)
	elseif InCombatLockdown() then
		UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.1, 0.1, 1.0)
	else
		ShowUIPanel(LM.Construire())
	end
end

-- la page de fabrication remplace le livre, et se deplace comme lui ;
-- l'entree en combat ferme le
-- livre et cache les onglets (PLAYER_REGEN_DISABLED passe AVANT le verrou du
-- combat), la sortie les rend ; le micro-bouton et les onglets suivent la
-- page de fabrication, les onglets le placement des panneaux ; la page de
-- fabrication garde a sa droite la place des onglets (largeur de camelot)
local veille = CreateFrame("Frame")
LM.veille = veille
local function brancherFabrication()
	if TradeSkillFrame and not veille.branche then
		veille.branche = true
		TradeSkillFrame:SetAttribute("UIPanelLayout-width", LARGEUR_PANNEAU)
		if TradeSkillFrame.foreverHabit then
			rendreDeplacable(TradeSkillFrame, TradeSkillFrame.foreverHabit.bandeau)
		end
		TradeSkillFrame:HookScript("OnShow", function()
			LM.Reposer(TradeSkillFrame)
			actualiser()
		end)
		TradeSkillFrame:HookScript("OnHide", actualiser)
	end
end
for _, ev in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"SKILL_LINES_CHANGED", "SPELLS_CHANGED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
	veille:RegisterEvent(ev)
end
veille:SetScript("OnEvent", function(_, ev, nom)
	if ev == "ADDON_LOADED" then
		if nom == "Blizzard_TradeSkillUI" then brancherFabrication() end
	elseif ev == "PLAYER_REGEN_DISABLED" then
		if LM.livre and LM.livre:IsShown() then HideUIPanel(LM.livre) end
		if LM.onglets then LM.onglets:Hide() end
	elseif ev == "TRADE_SKILL_SHOW" then
		if LM.livre and LM.livre:IsShown() then HideUIPanel(LM.livre) end
		LM.MajOnglets()
	elseif ev ~= "SKILL_LINES_CHANGED" or GetTime() >= silence then
		LM.MajOnglets()
	end
end)
brancherFabrication()
-- apres le systeme de panneaux : la place retenue, puis les onglets
if hooksecurefunc then
	hooksecurefunc("UpdateUIPanelPositions", function()
		LM.Reposer(LM.livre)
		if TradeSkillFrame then LM.Reposer(TradeSkillFrame) end
		LM.PoserOnglets()
	end)
end
