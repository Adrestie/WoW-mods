-- ForeverUI : la recherche du grimoire de camelot (docs/GRIMOIRE.md,
-- etape 3).
--
-- RELEVE -- blizzard_spellsearch (util, filtres, controleur, gabarits) et
-- blizzard_playerspells/spellbook/blizzard_spellbooksearch.lua :
--   champ        SpellSearchBoxTemplate < SearchBoxTemplate, 300 x 30, 40
--                lettres ; RIGHT sur le LEFT des reglages (-5, 4) ; largeur
--                min(droite du champ - droite des onglets - 10, 300) ; bord
--                common-search-border-left / -middle / -right (8 x 20, a -5) ;
--                loupe common-search-magnifyingglass 10 a LEFT (1, -1), grise
--                (0,6) sans focus ni texte ; bouton d'effacement 17 a RIGHT
--                (-3), icone common-search-clearbutton 10 a (3, -3), alpha
--                0,5 (1 au survol, (4, -4) enfonce) ; consigne
--                SPELLBOOK_SEARCH_INSTRUCTIONS en GameFontDisableSmall
--                (0,35) de 16 a -20 ; texte GameFontHighlightSmall, marges
--                16 / 20
--   apercu       SpellSearchPreviewContainerTemplate : sous le champ, de
--                (20, 4) a (-3, 4) ; 3 lignes au plus de 27 (marges 1 / 3,
--                ICI 5, a la demande -- 2026-09-25 --
--                ecart 1), fond _search-rowbg, surbrillance search-highlight
--                en ADD, cadre d'icone talents-search-suggestion-itemborder
--                18 a (5, 1), nom GameFontHighlightSmall ; "And %s more"
--                (TALENT_FRAME_SEARCH_PREVIEW_OVERFLOW_FORMAT) en
--                GameFontDisableSmall, 16 de haut ; bordure UI-Frame-BotCorner*
--                / _UI-Frame-Bot / !UI-Frame-*Tile ; sous 3 lettres, la
--                suggestion "Missing from action bar" (loupe 14 a (10, 1))
--   clavier      haut / bas parcourent l'apercu, Entree choisit (ou lance la
--                recherche entiere), Echap rend le focus
--   correspond.  sans casse, sous-chaine litterale ; 3 lettres au moins
--                (MIN_CHARACTER_SEARCH). Apercu : exact ou nom. Recherche
--                entiere : exact, nom (ou sous-titre : rang, "Passive"),
--                description, puis "apparente" (le nom apparait dans la
--                description du sort qui porte exactement le texte). Un
--                groupe prend le meilleur de ses sorts.
--   resultats    une categorie sans onglet, en sections (Exact / Related /
--                Name / Description Matches ; "Matches" pour les barres) ;
--                tri : type, actifs avant passifs, livre, emplacement ;
--                aucun resultat : on
--                sort de la recherche. On en sort aussi par l'effacement,
--                Entree sous 3 lettres, ou un onglet. Les reglages y sont
--                desactives, sauf "Show all spell ranks" (voir plus bas).
--   barres       "Missing from action bar" : ni passifs ni attaques
--                automatiques ; absent de toute barre, sur une barre
--                desactivee, sur une barre de posture inactive.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * l'apercu montre 5 resultats (camelot : 3), a la demande.
--   * une ligne de resultat : 3.3.5 n'a pas de sous-niveau de calque, et la
--     texture normale d'un bouton (le fond _search-rowbg) se dessine en
--     ARTWORK. L'icone y passait tantot dessous, tantot dessus : elle va en
--     OVERLAY, et son cadre et la surbrillance -- qui la recouvrent chez
--     camelot (OVERLAY 2 et 3) -- dans un cadre fils, au-dessus.
--   * 3.3.5 ne donne pas la description d'un sort : elle se lit dans une
--     infobulle cachee (sa derniere ligne).
--   * les resultats suivent "Hide Passives" et "Show all spell ranks", et
--     ce dernier reste actif pendant une recherche ; la recherche ne groupe
--     jamais les sorts en menus volants (demandes du 2026-09-25) : camelot y
--     montre passifs et tous les rangs, groupe selon son reglage, et
--     desactive ses reglages.
--   * pas de combat assiste (SPELLBOOK_SEARCH_ASSISTED_COMBAT) : 3.3.5 ne l'a
--     pas, sa suggestion n'est pas montree.
--   * EN COMBAT, le champ ne prend pas le focus : une recherche publie des
--     pages, ce qui ne se fait qu'hors combat. Des resultats deja affiches
--     se feuillettent en combat, et l'effacement ou un onglet en sortent
--     (par le controleur securise).
--   * le bouton d'effacement est securise (il sort de la recherche en combat)
--     : en combat, il ne peut plus se cacher, il devient transparent.

ForeverUI = ForeverUI or {}

local S = ForeverUI.SpellBook
if not (S and S.livre and S.pages) then return end

local R = {}
ForeverUI.SpellBookSearch = R

local SEP = string.char(92)
local TEXTE = {
	consigne = "Search abilities, keywords",         -- SPELLBOOK_SEARCH_INSTRUCTIONS
	pasSurBarre = "Missing from action bar",         -- SPELLBOOK_SEARCH_NOT_ON_ACTIONBAR
	exact = "Exact Matches",                         -- SPELLBOOK_SEARCH_HEADER_EXACT
	apparente = "Related Matches",                   -- SPELLBOOK_SEARCH_HEADER_RELATED
	nom = "Name Matches",                            -- SPELLBOOK_SEARCH_HEADER_NAME
	description = "Description Matches",             -- SPELLBOOK_SEARCH_HEADER_DESCRIPTION
	generique = "Matches",                           -- SPELLBOOK_SEARCH_HEADER_GENERIC
	depassement = "And %s more",                     -- TALENT_FRAME_SEARCH_PREVIEW_OVERFLOW_FORMAT
	passif = SPELL_PASSIVE or "Passive",
}
local MIN_LETTRES = 3                                -- MIN_CHARACTER_SEARCH

local M = {
	boiteL = 300, boiteH = 30, boiteX = -5, boiteY = 4, ecartOnglets = 10, lettres = 40,
	bordL = 8, bordH = 20, bordX = -5, loupe = 10, loupeX = 1, loupeY = -1, gris = 0.6,
	effacer = 17, effacerX = -3, effacerIcone = 10, effacerIconeX = 3, effacerIconeY = -3,
	margeG = 16, margeD = 20, consigneGris = 0.35,
	apercuX1 = 20, apercuX2 = -3, apercuY = 4, ligneH = 27, lignes = 5, hautMarge = 1, basMarge = 3,
	ecart = 1, depassementH = 16, depassementY = 5, depassementX = 9,
	cadreIcone = 18, cadreIconeX = 5, cadreIconeY = 1, nomX = 5, nomY = 1, nomD = -5,
	loupeSugg = 14, loupeSuggX = 10, loupeSuggY = 1, texteSuggX = 10,
}

-- SpellSearchUtil.MatchType : le plus grand est le meilleur
local T = { description = 1, nom = 2, apparente = 3, exact = 4, absent = 5, postureInactive = 6, barreDesactivee = 7 }
local SECTIONS = {
	{ titre = TEXTE.exact, types = { [T.exact] = true } },
	{ titre = TEXTE.apparente, types = { [T.apparente] = true } },
	{ titre = TEXTE.nom, types = { [T.nom] = true } },
	{ titre = TEXTE.description, types = { [T.description] = true } },
	{ titre = TEXTE.generique, types = { [T.absent] = true, [T.postureInactive] = true, [T.barreDesactivee] = true } },
}

-- ------------------------------------------------------------ les chaines
-- DoStringsMatch / DoesStringContain : sans casse, litteral
local function egal(a, b)
	return a and b and string.lower(a) == string.lower(b)
end
local function contient(parent, sous)
	return parent and sous and string.find(string.lower(parent), string.lower(sous), 1, true) ~= nil
end

-- ------------------------------------------------------------ la description
-- 3.3.5 n'a pas GetSpellBookItemDescription : une infobulle cachee, dont la
-- derniere ligne est la description.
local lecteur = CreateFrame("GameTooltip", "ForeverUISpellBookScanTooltip", nil, "GameTooltipTemplate")
local descriptions = {}
local function description(sort)
	local cle = sort.livre .. ":" .. sort.nom .. ":" .. (sort.rang or "")
	local d = descriptions[cle]
	if d == nil then
		d = ""
		lecteur:SetOwner(WorldFrame, "ANCHOR_NONE")
		lecteur:ClearLines()
		lecteur:SetSpell(sort.slot, sort.livre)
		for i = lecteur:NumLines(), 2, -1 do
			local ligne = _G["ForeverUISpellBookScanTooltipTextLeft" .. i]
			local t = ligne and ligne:GetText()
			if t and t ~= "" then
				d = t
				break
			end
		end
		lecteur:Hide()
		descriptions[cle] = d
	end
	return d
end
R.description = description

-- ------------------------------------------------------------ l'etat
R.etat = nil            -- { filtre = "texte" | "barres", texte = ... }
local cache = {}

function R.active() return R.etat ~= nil end
function R.nouveauCalcul() cache = {} end

-- les elements cherchables : ceux des categories, dans leur ordre
local function elements(cats, opts)
	local liste = {}
	for ci = 1, #cats do
		for _, el in ipairs(S.listeAffichee(cats, ci, opts)) do
			table.insert(liste, el)
		end
	end
	return liste
end

-- le livre (sorts avant familier) et l'emplacement d'un element
local function rangLivre(el)
	local sort = el.volant and el.membres[1] or el
	return (sort.livre == BOOKTYPE_PET) and 1 or 0, sort.slot or 0
end

-- le sous-titre d'un sort, qui compte comme son nom (extraSpellName)
local function sousTitre(sort)
	if sort.rang and sort.rang ~= "" then return sort.rang end
	if sort.passif then return TEXTE.passif end
end

-- GetMatchTypeForText, pour un sort
local function typeTexte(sort, texte, descExacte)
	if egal(sort.nom, texte) then return T.exact end
	if contient(sort.nom, texte) or contient(sousTitre(sort), texte) then return T.nom end
	if contient(description(sort), texte) then return T.description end
	if descExacte and contient(descExacte, sort.nom) then return T.apparente end
end

-- un groupe : le meilleur de ses sorts, et ce sort-la
local function meilleur(el, fn)
	if not el.volant then return fn(el), el end
	local best, lequel
	for _, m in ipairs(el.membres) do
		local t = fn(m)
		if t and (not best or t > best) then best, lequel = t, m end
	end
	return best, lequel
end

-- ------------------------------------------------------------ les barres
-- GetActionBarStatusForSpell, en 3.3.5 : 1-24 la barre principale (pages 1
-- et 2) ; 25-36 droite, 37-48 gauche, 49-60 bas droite, 61-72 bas gauche
-- (GetActionBarToggles : bas gauche, bas droite, droite, gauche) ; 73-120
-- les barres de posture, une active (GetBonusBarOffset).
local function nomsDeLAction(slot, noms)
	local t, id, sous, global = GetActionInfo(slot)
	if t ~= "spell" then return end
	if global then noms[#noms + 1] = GetSpellInfo(global) end
	if id then
		if sous == BOOKTYPE_SPELL or sous == BOOKTYPE_PET then
			noms[#noms + 1] = GetSpellName(id, sous)
		else
			noms[#noms + 1] = GetSpellInfo(id)
		end
	end
end

local function etatDesBarres()
	if cache.barres then return cache.barres end
	local actives, desactivees, inactives = {}, {}, {}
	local basG, basD, droite, gauche = GetActionBarToggles()
	local multi = { [3] = droite, [4] = gauche, [5] = basD, [6] = basG }
	local posture = GetBonusBarOffset and GetBonusBarOffset() or 0
	for slot = 1, 120 do
		local noms = {}
		nomsDeLAction(slot, noms)
		for _, n in ipairs(noms) do
			if slot <= 24 then
				actives[n] = true
			elseif slot <= 72 then
				local barre = math.floor((slot - 1) / 12) + 1
				if multi[barre] then actives[n] = true else desactivees[n] = true end
			else
				local barre = math.floor((slot - 73) / 12) + 1
				if barre == posture then actives[n] = true else inactives[n] = true end
			end
		end
	end
	local familier = {}
	for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
		local n = GetPetActionInfo(i)
		if n then familier[n] = true end
	end
	cache.barres = { actives = actives, desactivees = desactivees, inactives = inactives, familier = familier }
	return cache.barres
end

-- pour la recherche des talents (TalentsSearch.lua) : les barres, relues
function R.barres()
	cache.barres = nil
	return etatDesBarres()
end

-- l'etat d'un sort : nil s'il est sur une barre active (ou exclu)
local function typeBarre(sort)
	if sort.passif then return end
	if IsAttackSpell and IsAttackSpell(sort.nom) then return end
	if IsAutoRepeatSpell and IsAutoRepeatSpell(sort.nom) then return end
	local b = etatDesBarres()
	if sort.livre == BOOKTYPE_PET then
		if b.familier[sort.nom] then return end
		return T.absent
	end
	if b.actives[sort.nom] then return end
	if b.desactivees[sort.nom] then return T.barreDesactivee end
	if b.inactives[sort.nom] then return T.postureInactive end
	return T.absent
end

-- un groupe n'est absent que si aucun de ses sorts n'est sur une barre active
local function typeBarreElement(el)
	if not el.volant then return typeBarre(el) end
	local best
	for _, m in ipairs(el.membres) do
		local t = typeBarre(m)
		if not t then return end
		if not best or t < best then best = t end
	end
	return best
end

-- ------------------------------------------------------------ les resultats
-- FullSearchResultSort : type (a rebours pour les barres), actifs avant
-- passifs, livre, emplacement
local function trier(liste, aRebours)
	table.sort(liste, function(a, b)
		if a.type ~= b.type then
			if aRebours then return a.type < b.type end
			return a.type > b.type
		end
		local pa, pb = a.el.passif and 1 or 0, b.el.passif and 1 or 0
		if pa ~= pb then return pa < pb end
		local la, sa = rangLivre(a.el)
		local lb, sb = rangLivre(b.el)
		if la ~= lb then return la < lb end
		return sa < sb
	end)
end

-- les sections de la recherche en cours : { { titre, sorts }, ... }
function R.groupes(cats, opts)
	local cle = (opts.passifs and "p" or "a") .. (opts.volants and "v" or "s") .. (opts.rangs and "r" or "h")
	if cache[cle] then return cache[cle] end
	local etat = R.etat
	local trouves = {}
	if etat then
		local tous = elements(cats, opts)
		if etat.filtre == "barres" then
			for _, el in ipairs(tous) do
				local t = typeBarreElement(el)
				if t then table.insert(trouves, { el = el, type = t }) end
			end
		else
			-- la description du sort qui porte exactement le texte
			local descExacte
			for _, el in ipairs(tous) do
				local t, m = meilleur(el, function(s) return egal(s.nom, etat.texte) and T.exact or nil end)
				if t then
					descExacte = description(m)
					break
				end
			end
			for _, el in ipairs(tous) do
				local t = meilleur(el, function(s) return typeTexte(s, etat.texte, descExacte) end)
				if t then table.insert(trouves, { el = el, type = t }) end
			end
		end
		trier(trouves, etat.filtre == "barres")
	end
	local groupes = {}
	for _, section in ipairs(SECTIONS) do
		local sorts = {}
		for _, r in ipairs(trouves) do
			if section.types[r.type] then table.insert(sorts, r.el) end
		end
		if #sorts > 0 then table.insert(groupes, { titre = section.titre, sorts = sorts }) end
	end
	cache[cle] = groupes
	return groupes
end

-- l'apercu : le filtre de nom, exact ou contenu ; un groupe montre son
-- meilleur sort (nom et icone) ; PreviewSearchResultSort
function R.apercu(texte)
	local cats = S.categories()
	local opts = S.optionsCourantes()
	opts.volants = true                  -- jamais de groupes dans la recherche
	local trouves = {}
	for _, el in ipairs(elements(cats, opts)) do
		local t, m = meilleur(el, function(s)
			if egal(s.nom, texte) then return T.exact end
			if contient(s.nom, texte) then return T.nom end
		end)
		if t then
			local montre = el
			if el.volant and m then montre = m end
			table.insert(trouves, { el = el, type = t, nom = montre.nom, icone = montre.icone })
		end
	end
	table.sort(trouves, function(a, b)
		if a.type ~= b.type then return a.type > b.type end
		local la, sa = rangLivre(a.el)
		local lb, sb = rangLivre(b.el)
		if la ~= lb then return la < lb end
		return sa < sb
	end)
	return trouves
end

-- ------------------------------------------------------------ le champ
local boite, effacer, apercu

-- EvaluateSearchText : le texte, s'il a 3 lettres au moins
local function evaluer()
	local t = boite:GetText() or ""
	if string.len(t) >= MIN_LETTRES then return t end
end

local function cacherApercu()
	apercu:Hide()
	apercu.surligne = 0
end

-- le bouton d'effacement : cache hors combat, transparent en combat (il est
-- securise)
local function majEffacer()
	local visible = boite:HasFocus() or (boite:GetText() or "") ~= ""
	if InCombatLockdown() then
		effacer:SetAlpha(visible and 1 or 0)
		return
	end
	effacer:SetAlpha(1)
	if visible then effacer:Show() else effacer:Hide() end
end

-- SearchBoxTemplate : loupe et consigne
local function majLoupe()
	local actif = boite:HasFocus() or (boite:GetText() or "") ~= ""
	local g = actif and 1 or M.gris
	boite.loupe:SetVertexColor(g, g, g)
	if (boite:GetText() or "") == "" then boite.consigne:Show() else boite.consigne:Hide() end
	majEffacer()
end

-- SetFullResultSearch
function R.chercher(texte)
	if InCombatLockdown() then return end
	if not texte then
		R.quitter(true)
		return
	end
	if egal(texte, TEXTE.pasSurBarre) then
		R.etat = { filtre = "barres" }
	else
		R.etat = { filtre = "texte", texte = texte }
	end
	-- la categorie 0 AVANT le calcul : il affiche aussitot l'etat voulu (un
	-- affichage sur un onglet passerait pour un clic d'onglet, qui sort de
	-- la recherche)
	S.etat.categorie, S.etat.page = 0, 1
	S.maj()
end

-- ClearActiveSearchState : le texte, le focus, l'apercu ; revenir au premier
-- onglet si l'on etait en recherche (sauf quand c'est un onglet qui en sort)
function R.quitter(versPremierOnglet)
	local etait = R.etat ~= nil
	R.etat = nil
	if boite then
		boite:ClearFocus()
		boite:SetText("")
		cacherApercu()
		majLoupe()
	end
	if etait and versPremierOnglet and not InCombatLockdown() then
		S.choisir(1)
	end
end

-- ------------------------------------------------------------ l'apercu
local function ligneResultat(parent, i)
	local l = CreateFrame("Button", "ForeverUISpellBookSearchResult" .. i, parent)
	l:SetHeight(M.ligneH)
	local e = ForeverUI.AtlasEntry("_search-rowbg")
	l:SetNormalTexture(e and e[1] or "")
	ForeverUI.SetAtlas(l:GetNormalTexture(), "_search-rowbg", true)
	l:SetPushedTexture(e and e[1] or "")
	ForeverUI.SetAtlas(l:GetPushedTexture(), "_search-rowbg", true)
	local dessus = CreateFrame("Frame", nil, l)
	dessus:SetAllPoints(l)
	dessus:SetFrameLevel(l:GetFrameLevel() + 1)
	l.dessus = dessus
	local surligne = dessus:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(surligne, "search-highlight", true)
	surligne:SetAllPoints(l)
	surligne:SetBlendMode("ADD")
	surligne:Hide()
	l.surligne = surligne
	return l
end

local function construireApercu()
	local a = CreateFrame("Frame", "ForeverUISpellBookSearchPreview", S.pages)
	a:SetFrameStrata("HIGH")
	a:SetPoint("TOPLEFT", boite, "BOTTOMLEFT", M.apercuX1, M.apercuY)
	a:SetPoint("TOPRIGHT", boite, "BOTTOMRIGHT", M.apercuX2, M.apercuY)
	a:SetHeight(M.ligneH)
	a:EnableMouse(true)
	a:Hide()
	local fond = a:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "_search-rowbg", true)
	fond:SetAllPoints(a)
	-- la bordure (UI-Frame-BotCorner*, _UI-Frame-Bot, !UI-Frame-*Tile)
	local coinG = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(coinG, "ui-frame-botcornerleft")
	coinG:SetPoint("LEFT", a, "LEFT", -7, 0)
	coinG:SetPoint("BOTTOM", a, "BOTTOM", 0, -7)
	local coinD = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(coinD, "ui-frame-botcornerright")
	coinD:SetPoint("BOTTOM", coinG, "BOTTOM", 0, 0)
	coinD:SetPoint("RIGHT", a, "RIGHT", 4, 0)
	local bas = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(bas, "_ui-frame-bot", true)
	bas:SetHeight(9)
	bas:SetPoint("BOTTOMLEFT", coinG, "BOTTOMRIGHT", 0, 0)
	bas:SetPoint("BOTTOMRIGHT", coinD, "BOTTOMLEFT", 0, 0)
	local gauche = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(gauche, "!ui-frame-lefttile", true)
	gauche:SetWidth(16)
	gauche:SetPoint("BOTTOMLEFT", coinG, "TOPLEFT", 0, 0)
	gauche:SetPoint("TOPLEFT", a, "TOPLEFT", -7, 2)
	local droite = a:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(droite, "!ui-frame-righttile", true)
	droite:SetWidth(10)
	droite:SetPoint("BOTTOMRIGHT", coinD, "TOPRIGHT", 1, 0)
	droite:SetPoint("TOPRIGHT", a, "TOPRIGHT", 5, 2)

	-- les lignes de resultat (SpellSearchPreviewResultTemplate)
	a.lignes = {}
	for i = 1, M.lignes do
		local l = ligneResultat(a, i)
		l:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -M.hautMarge - (i - 1) * (M.ligneH + M.ecart))
		l:SetPoint("TOPRIGHT", a, "TOPRIGHT", 0, -M.hautMarge - (i - 1) * (M.ligneH + M.ecart))
		local cadre = l.dessus:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(cadre, "talents-search-suggestion-itemborder")
		cadre:SetWidth(M.cadreIcone)
		cadre:SetHeight(M.cadreIcone)
		cadre:SetPoint("LEFT", l, "LEFT", M.cadreIconeX, M.cadreIconeY)
		local icone = l:CreateTexture(nil, "OVERLAY")
		icone:SetPoint("TOPLEFT", cadre, "TOPLEFT", 1, -1)
		icone:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", -1, 1)
		local nom = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		nom:SetJustifyH("LEFT")
		nom:SetPoint("LEFT", icone, "RIGHT", M.nomX, M.nomY)
		nom:SetPoint("RIGHT", l, "RIGHT", M.nomD, 0)
		l.icone, l.nom = icone, nom
		l:SetScript("OnEnter", function() R.surligner(i) end)
		l:SetScript("OnClick", function() R.choisir(i) end)
		l:Hide()
		a.lignes[i] = l
	end
	-- la suggestion (SpellSearchSuggestedResultButtonTemplate)
	local sugg = ligneResultat(a, "Suggestion")
	sugg:SetPoint("TOPLEFT", a, "TOPLEFT", 0, 0)
	sugg:SetPoint("TOPRIGHT", a, "TOPRIGHT", 0, 0)
	local loupe = sugg:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(loupe, "talents-search-suggestion-magnifyingglass", true)
	loupe:SetWidth(M.loupeSugg)
	loupe:SetHeight(M.loupeSugg)
	loupe:SetPoint("LEFT", sugg, "LEFT", M.loupeSuggX, M.loupeSuggY)
	local texte = sugg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	texte:SetJustifyH("LEFT")
	texte:SetPoint("LEFT", loupe, "RIGHT", M.texteSuggX, 0)
	texte:SetPoint("RIGHT", sugg, "RIGHT", -5, 0)
	texte:SetText(TEXTE.pasSurBarre)
	sugg.texte = texte
	sugg:SetScript("OnEnter", function() R.surligner(1) end)
	sugg:SetScript("OnClick", function() R.choisir(1) end)
	sugg:Hide()
	a.suggestion = sugg
	-- le depassement
	local plus = CreateFrame("Frame", nil, a)
	plus:SetHeight(M.depassementH)
	plus:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 0, M.depassementY)
	plus:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, M.depassementY)
	local plusTexte = plus:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	plusTexte:SetJustifyH("LEFT")
	plusTexte:SetPoint("TOPLEFT", plus, "TOPLEFT", M.depassementX, 0)
	plusTexte:SetPoint("BOTTOMRIGHT", plus, "BOTTOMRIGHT", 0, 0)
	plus.texte = plusTexte
	plus:Hide()
	a.depassement = plus
	a.surligne = 0
	-- le champ a perdu le focus pendant qu'on cliquait ici : l'apercu reste
	-- le temps du clic, puis part des que la souris le quitte
	a:SetScript("OnUpdate", function(self)
		if not boite:HasFocus() and not MouseIsOver(self) then cacherApercu() end
	end)
	return a
end

-- SetPreviewResults / UpdateResultsDisplay
function R.majApercu(texte)
	if InCombatLockdown() then return end
	local a = apercu
	a.surligne = 0
	a.resultats = nil
	for _, l in ipairs(a.lignes) do l:Hide() l.surligne:Hide() end
	a.suggestion:Hide()
	a.suggestion.surligne:Hide()
	a.depassement:Hide()
	if not texte then
		-- sous 3 lettres : la suggestion (le combat assiste n'existe pas ici)
		a.suggestion:Show()
		a.nombre = 1
		a:SetHeight(M.ligneH * 1 + M.basMarge)
		a:Show()
		return
	end
	local trouves = R.apercu(texte)
	if #trouves == 0 then
		cacherApercu()
		return
	end
	a.resultats = trouves
	local n = math.min(#trouves, M.lignes)
	for i = 1, n do
		local l = a.lignes[i]
		l.nom:SetText(trouves[i].nom)
		l.icone:SetTexture(trouves[i].icone)
		l:Show()
	end
	a.nombre = n
	local h = M.hautMarge + n * M.ligneH + (n - 1) * M.ecart + M.basMarge
	if #trouves > M.lignes then
		a.depassement.texte:SetText(string.format(TEXTE.depassement, #trouves - M.lignes))
		a.depassement:Show()
		h = h + M.depassementH
	end
	a:SetHeight(h)
	a:Show()
end

-- HighlightPreviewResult
function R.surligner(i)
	local a = apercu
	a.surligne = i
	if a.resultats then
		for j, l in ipairs(a.lignes) do
			if j == i then l.surligne:Show() else l.surligne:Hide() end
		end
	else
		if i == 1 then a.suggestion.surligne:Show() else a.suggestion.surligne:Hide() end
	end
end

-- CycleHighlightedResultUp / Down (la formule de camelot, telle quelle)
local function parcourir(sens)
	local a = apercu
	if not a:IsShown() or not a.nombre or a.nombre == 0 then return end
	local n, i = a.nombre, a.surligne or 0
	if sens < 0 then
		i = (i - 2) % n + 1
	else
		i = i % n + 1
	end
	R.surligner(i)
end

-- SelectPreviewResult / le clic d'une suggestion
function R.choisir(i)
	local a = apercu
	PlaySound("igMainMenuOptionCheckBoxOn")
	if a.resultats then
		local r = a.resultats[i]
		if not r then return end
		boite:ClearFocus()
		boite:SetText(r.nom)
		cacherApercu()
		R.chercher(r.nom)
	else
		boite:ClearFocus()
		boite:SetText(TEXTE.pasSurBarre)
		cacherApercu()
		R.chercher(TEXTE.pasSurBarre)
	end
end

-- ------------------------------------------------------------ construction
local function construire()
	local b = CreateFrame("EditBox", "ForeverUISpellBookSearchBox", S.pages)
	boite = b
	b:SetAutoFocus(false)
	b:SetMaxLetters(M.lettres)
	b:SetHeight(M.boiteH)
	b:SetWidth(M.boiteL)
	b:SetPoint("RIGHT", S.reglages, "LEFT", M.boiteX, M.boiteY)
	b:SetFontObject(GameFontHighlightSmall)
	b:SetTextInsets(M.margeG, M.margeD, 0, 0)
	-- le bord (InputBoxVisualTemplate)
	local g = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(g, "common-search-border-left", true)
	g:SetWidth(M.bordL) g:SetHeight(M.bordH)
	g:SetPoint("LEFT", b, "LEFT", M.bordX, 0)
	local d = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(d, "common-search-border-right", true)
	d:SetWidth(M.bordL) d:SetHeight(M.bordH)
	d:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	local m = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(m, "common-search-border-middle", true)
	m:SetHeight(M.bordH)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	m:SetPoint("RIGHT", d, "LEFT", 0, 0)
	-- la loupe
	local loupe = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(loupe, "common-search-magnifyingglass", true)
	loupe:SetWidth(M.loupe) loupe:SetHeight(M.loupe)
	loupe:SetPoint("LEFT", b, "LEFT", M.loupeX, M.loupeY)
	b.loupe = loupe
	-- la consigne
	local consigne = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	consigne:SetJustifyH("LEFT")
	consigne:SetJustifyV("MIDDLE")
	consigne:SetPoint("TOPLEFT", b, "TOPLEFT", M.margeG, 0)
	consigne:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -M.margeD, 0)
	consigne:SetTextColor(M.consigneGris, M.consigneGris, M.consigneGris)
	consigne:SetText(TEXTE.consigne)
	b.consigne = consigne

	-- l'effacement : securise, il sort de la recherche en combat aussi
	local e = CreateFrame("Button", "ForeverUISpellBookSearchClear", S.pages, "SecureHandlerClickTemplate")
	effacer = e
	e:SetWidth(M.effacer) e:SetHeight(M.effacer)
	e:SetPoint("RIGHT", b, "RIGHT", M.effacerX, 0)
	e:SetFrameLevel(b:GetFrameLevel() + 2)
	local icone = e:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(icone, "common-search-clearbutton", true)
	icone:SetWidth(M.effacerIcone) icone:SetHeight(M.effacerIcone)
	icone:SetPoint("TOPLEFT", e, "TOPLEFT", M.effacerIconeX, M.effacerIconeY)
	icone:SetAlpha(0.5)
	e.icone = icone
	e:SetScript("OnEnter", function() icone:SetAlpha(1) end)
	e:SetScript("OnLeave", function() icone:SetAlpha(0.5) end)
	e:SetScript("OnMouseDown", function() icone:SetPoint("TOPLEFT", e, "TOPLEFT", M.effacerIconeX + 1, M.effacerIconeY - 1) end)
	e:SetScript("OnMouseUp", function() icone:SetPoint("TOPLEFT", e, "TOPLEFT", M.effacerIconeX, M.effacerIconeY) end)
	e:SetFrameRef("ctrl", S.ctrl)
	e:SetAttribute("_onclick", [==[ self:GetFrameRef("ctrl"):SetAttribute("effacer", 1) ]==])
	-- SearchBoxTemplateClearButton_OnClick : le son, le texte, le focus
	e:HookScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		R.quitter(false)
	end)
	e:Hide()

	apercu = construireApercu()

	-- SpellSearchBoxMixin
	b:SetScript("OnEditFocusGained", function(self)
		-- en combat, rien a publier : le champ rend le focus
		if InCombatLockdown() then
			self:ClearFocus()
			return
		end
		majLoupe()
		R.majApercu(evaluer())
	end)
	b:SetScript("OnEditFocusLost", function(self)
		majLoupe()
		if not MouseIsOver(apercu) then cacherApercu() end
	end)
	b:SetScript("OnTextChanged", function(self)
		majLoupe()
		if self:HasFocus() then R.majApercu(evaluer()) end
	end)
	b:SetScript("OnEnterPressed", function(self)
		local a = apercu
		if a:IsShown() and (a.surligne or 0) > 0 then
			R.choisir(a.surligne)
			return
		end
		cacherApercu()
		R.chercher(evaluer())
		self:ClearFocus()
	end)
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	b:SetScript("OnKeyDown", function(self, touche)
		if touche == "UP" then parcourir(-1) elseif touche == "DOWN" then parcourir(1) end
	end)
	majLoupe()
end

construire()
R.boite, R.effacer, R.apercuCadre = boite, effacer, apercu

-- un onglet sort de la recherche (ClearActiveSearchState, sans revenir au
-- premier onglet) : en combat aussi, rien de protege ici
S.surVisuels = function(cat)
	if cat ~= 0 and R.etat then
		R.quitter(false)
	end
end

-- ResizeSearchBox : entre la droite des onglets (+ 10) et les reglages, 300
-- au plus. Hors combat seulement : le champ porte un bouton securise ancre
-- a lui.
S.surTaille = function(reduit)
	if InCombatLockdown() or not boite then return end
	local G = S.G
	local pagesL = reduit and G.livreLReduit or G.livreL
	local nOnglets = 0
	for _, o in ipairs(S.onglets.boutons) do
		if o:IsShown() then nOnglets = nOnglets + 1 end
	end
	local droiteOnglets = G.ongletsX + nOnglets * (G.ongletL + G.ongletEcart) - G.ongletEcart
	local droiteBoite = pagesL + G.reglagesX - G.reglagesL + M.boiteX
	boite:SetWidth(math.min(droiteBoite - droiteOnglets - M.ecartOnglets, M.boiteL))
end

-- le combat commence : le champ rend le focus, l'apercu part ; il finit :
-- l'effacement reprend sa visibilite
local veille = CreateFrame("Frame")
veille:RegisterEvent("PLAYER_REGEN_DISABLED")
veille:RegisterEvent("PLAYER_REGEN_ENABLED")
veille:SetScript("OnEvent", function(_, ev)
	if ev == "PLAYER_REGEN_DISABLED" then
		boite:ClearFocus()
		cacherApercu()
	else
		majEffacer()
	end
end)

-- LES BARRES CHANGENT (un sort pose, retire, une page ou une posture) : une
-- recherche "Missing from action bar" se refait (demande du 2026-09-25) --
-- une fois par image, un glisser en declenchant plusieurs ; en combat, S.maj
-- attend la fin du combat, comme pour tout le reste
local barres = CreateFrame("Frame")
barres:Hide()
for _, ev in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
	"PET_BAR_UPDATE", "UPDATE_MULTI_ACTIONBAR" }) do
	barres:RegisterEvent(ev)
end
barres:SetScript("OnEvent", function(self)
	if R.etat and R.etat.filtre == "barres" then self:Show() end
end)
barres:SetScript("OnUpdate", function(self)
	self:Hide()
	if R.etat and R.etat.filtre == "barres" and S.livre:IsVisible() then S.maj() end
end)
R.veilleBarres = barres
