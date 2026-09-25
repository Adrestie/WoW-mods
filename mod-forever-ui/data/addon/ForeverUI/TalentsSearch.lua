-- ForeverUI : la recherche des talents de camelot (docs/TALENTS.md, etape 4).
--
-- RELEVE -- blizzard_playerspells (camelot/classtalents), blizzard_sharedtalentui
-- (classtalentsearch, talentbuttonart, sharedtalentbuttontemplates,
-- sharedtalentutil) et blizzard_spellsearch (filtres, gabarits) :
--   champ        SpellSearchBoxTemplate 184 x 30, 40 lettres ; consigne SEARCH
--                (SearchBoxTemplate) ; loupe, bord et effacement comme le
--                grimoire (ForeverUI SpellBookSearch.lua)
--   options      SearchOptionsDropdown (WowStyle1ArrowDropdownTemplate 25 x 25,
--                fleche common-dropdown-a-button et ses etats) a RIGHT du champ
--                (3, -2) ; deux cases : CLASS_TALENT_SEARCH_OPTION_HIDE_PASSIVES
--                "Hide Passives" et _SHOW_RANKS "Show Ranks", non retenues ;
--                elles ne touchent QUE l'apercu (TransformPreviewResults) :
--                passifs retires, "Nom (rang/max)"
--   apercu       SpellSearchPreviewContainerTemplate 176 de large, TOPRIGHT
--                sur le BOTTOMRIGHT du champ (-4, 2) ; filtre de NOM (exact,
--                contenu) ; la suggestion TALENT_FRAME_SEARCH_NOT_ON_ACTIONBAR
--                "Missing from action bar" sous 3 lettres
--   recherche    filtre de TEXTE (GetMatchTypeForText) : exact, nom,
--                description, puis "apparente" (le nom du talent figure dans
--                la description du talent qui porte exactement le texte) ;
--                ou le filtre des BARRES : un talent appris, sort actif,
--                absent d'une barre active
--   marques      pas de liste : chaque noeud trouve porte SearchIcon, 63 x 63
--                (talents-search-*, taille d'atlas), CENTER sur le TOPRIGHT de
--                son icone, au-dessus du noeud ; OverlayIcon, la meme en ADD,
--                bat de 0 a 0,5 en 1 s puis retombe en 1 s ; au survol de son
--                centre (18 x 18), TALENT_FRAME_SEARCH_TOOLTIP_* :
--                  exact            talents-search-exactmatch  "Exact search match"
--                  nom, description talents-search-match       "Search match"
--                  apparente        talents-search-relatedmatch
--                                   "Related to the talent you searched for"
--                  absent           talents-search-notonactionbar "Not on action bar"
--                  posture inactive talents-search-notonactionbarhidden
--                                   "On an action bar belonging to a different stance"
--                  barre desactivee talents-search-notonactionbarhidden
--                                   "On a disabled action bar"
--   mise a jour  la recherche se recalcule a chaque changement de l'ecran
--                (UpdateFullSearchResults)
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * le champ est a GAUCHE du compteur "Unspent Talents" (camelot : a droite,
--     la ou le compteur a ete remonte a la demande) ; en fenetre reduite il se
--     retrecit pour tenir (decision du 2026-09-25).
--   * l'apercu montre 5 resultats (camelot : 3), comme le grimoire
--     (decision du 2026-09-25).
--   * 3.3.5 ne donne pas la description d'un talent : elle se lit dans une
--     infobulle cachee (SetTalent), sans ses lignes de rang, de prerequis ni
--     "Click to learn".
--   * pas de champ sur la page des glyphes.

ForeverUI = ForeverUI or {}

local K = {}
ForeverUI.TalentsSearch = K

local SEP = string.char(92)
local TEXTE = {
	consigne = SEARCH or "Search",
	pasSurBarre = "Missing from action bar",          -- TALENT_FRAME_SEARCH_NOT_ON_ACTIONBAR
	masquerPassifs = "Hide Passives",                 -- CLASS_TALENT_SEARCH_OPTION_HIDE_PASSIVES
	rangs = "Show Ranks",                             -- CLASS_TALENT_SEARCH_OPTION_SHOW_RANKS
	depassement = "And %s more",                      -- TALENT_FRAME_SEARCH_PREVIEW_OVERFLOW_FORMAT
}
local MIN_LETTRES = 3                                 -- MIN_CHARACTER_SEARCH

-- SpellSearchUtil.MatchType : le plus grand est le meilleur
local TYPE = { description = 1, nom = 2, apparente = 3, exact = 4, absent = 5, postureInactive = 6, barreDesactivee = 7 }
-- SearchMatchStyles (blizzard_sharedtalentutil.lua)
local STYLES = {
	[TYPE.apparente] = { icone = "talents-search-relatedmatch", info = "Related to the talent you searched for" },
	[TYPE.nom] = { icone = "talents-search-match", info = "Search match" },
	[TYPE.description] = { icone = "talents-search-match", info = "Search match" },
	[TYPE.exact] = { icone = "talents-search-exactmatch", info = "Exact search match" },
	[TYPE.absent] = { icone = "talents-search-notonactionbar", info = "Not on action bar" },
	[TYPE.postureInactive] = { icone = "talents-search-notonactionbarhidden",
		info = "On an action bar belonging to a different stance" },
	[TYPE.barreDesactivee] = { icone = "talents-search-notonactionbarhidden", info = "On a disabled action bar" },
}

local M = {
	boiteL = 184, boiteH = 30, lettres = 40, ecartCompteur = 10, margeGauche = 10,
	fleche = 25, flecheX = 3, flecheY = -2,
	bordL = 8, bordH = 20, bordX = -5, loupe = 10, loupeX = 1, loupeY = -1, gris = 0.6,
	effacer = 17, effacerX = -3, effacerIcone = 10, effacerIconeX = 3, effacerIconeY = -3,
	margeG = 16, margeD = 20, consigneGris = 0.35,
	apercuL = 176, apercuX = -4, apercuY = 2, ligneH = 27, lignes = 5, hautMarge = 1, basMarge = 3,
	ecart = 1, depassementH = 16, depassementY = 5, depassementX = 9,
	cadreIcone = 18, cadreIconeX = 5, cadreIconeY = 1, nomX = 5, nomY = 1, nomD = -5,
	loupeSugg = 14, loupeSuggX = 10, loupeSuggY = 1, texteSuggX = 10,
	-- la marque d'un noeud et son battement
	marque = 63, marqueSurvol = 18, battement = 1, battementAlpha = 0.5,
	-- la liste des options (celle des reglages du grimoire)
	ligneMenuH = 20, bordMenu = 15, ligneMenuX = 11, texteMenuX = 20, largeurPlus = 40, margeMenu = 25,
	case = 12, cocheL = 15, cocheH = 14, cocheX = 2, cocheY = 1,
	fondCoin = 18, fondMarges = { 9, 6, 9, 12 }, fondAlpha = 0.925, attente = 2,
}

-- ------------------------------------------------------------ les chaines
local function egal(a, b)
	return a and b and string.lower(a) == string.lower(b)
end
local function contient(parent, sous)
	return parent and sous and string.find(string.lower(parent), string.lower(sous), 1, true) ~= nil
end

-- ------------------------------------------------------------ la description
-- l'infobulle d'un talent, sans son nom, ses lignes de rang, de prerequis ni
-- l'invite d'apprentissage : ce qui reste est la description (et celle du
-- rang suivant)
local lecteur = CreateFrame("GameTooltip", "ForeverUITalentsScanTooltip", nil, "GameTooltipTemplate")
-- un format du client en motif Lua ; ses arguments peuvent etre numerotes
-- ("Requires %1$d points in %2$s Talents" : TOOLTIP_TALENT_TIER_POINTS)
local function motif(format)
	if not format then return nil end
	local m = string.gsub(format, "%%%d%$", "%%")
	m = string.gsub(m, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	m = string.gsub(m, "%%d", "%%d+")
	m = string.gsub(m, "%%s", ".+")
	return "^" .. m .. "$"
end
local LIGNES_ECARTEES = {}
for _, f in ipairs({ TOOLTIP_TALENT_RANK, TOOLTIP_TALENT_NEXT_RANK, TOOLTIP_TALENT_LEARN,
	TOOLTIP_TALENT_TIER_POINTS, TOOLTIP_TALENT_PREREQ, TOOLTIP_TALENT_UNLEARN }) do
	local m = motif(f)
	if m then table.insert(LIGNES_ECARTEES, m) end
end
local descriptions = {}
local function description(T, t)
	local cle = (T.pet and "p" or "j") .. T.groupe .. ":" .. t.onglet .. ":" .. t.index .. ":" .. t.rang
	local d = descriptions[cle]
	if d == nil then
		local parties = {}
		lecteur:SetOwner(WorldFrame, "ANCHOR_NONE")
		lecteur:ClearLines()
		lecteur:SetTalent(t.onglet, t.index, false, T.pet, T.groupe, true)
		for i = 2, lecteur:NumLines() do
			local ligne = _G["ForeverUITalentsScanTooltipTextLeft" .. i]
			local texte = ligne and ligne:GetText()
			if texte and texte ~= "" then
				local ecartee = false
				for _, m in ipairs(LIGNES_ECARTEES) do
					local ok, trouve = pcall(string.find, texte, m)
					if ok and trouve then ecartee = true break end
				end
				if not ecartee then table.insert(parties, texte) end
			end
		end
		lecteur:Hide()
		d = table.concat(parties, "\n")
		descriptions[cle] = d
	end
	return d
end
K.description = description

-- ------------------------------------------------------------ l'etat
K.etat = nil                      -- { filtre = "texte", texte } | { filtre = "barres" }
K.options = { passifs = false, rangs = false }
local T                           -- ForeverUI.Talents, a la construction

-- les talents de l'ecran, dans l'ordre (arbre, palier, colonne)
local function talents()
	local liste = {}
	for _, o in ipairs(T.onglets or {}) do
		for _, t in ipairs(o.talents) do table.insert(liste, t) end
	end
	table.sort(liste, function(a, b)
		if a.onglet ~= b.onglet then return a.onglet < b.onglet end
		if a.palier ~= b.palier then return a.palier < b.palier end
		return a.colonne < b.colonne
	end)
	return liste
end

-- GetActionbarStatusForSpell : un talent appris (valide), sort actif, qui
-- n'est sur aucune barre active
local function typeBarre(t, barres)
	if not t.carre or (t.appris or 0) == 0 then return end
	if T.pet then
		if barres.familier[t.nom] then return end
		return TYPE.absent
	end
	if barres.actives[t.nom] then return end
	if barres.desactivees[t.nom] then return TYPE.barreDesactivee end
	if barres.inactives[t.nom] then return TYPE.postureInactive end
	return TYPE.absent
end

-- les types de la recherche en cours, par talent (onglet:index)
function K.calculer()
	local etat = K.etat
	local types = {}
	if not etat then return types end
	local tous = talents()
	if etat.filtre == "barres" then
		local R = ForeverUI.SpellBookSearch
		local barres = R and R.barres and R.barres()
		if barres then
			for _, t in ipairs(tous) do
				types[t.onglet .. ":" .. t.index] = typeBarre(t, barres)
			end
		end
		return types
	end
	local texte = etat.texte
	local descExacte
	for _, t in ipairs(tous) do
		if egal(t.nom, texte) then
			descExacte = description(T, t)
			break
		end
	end
	for _, t in ipairs(tous) do
		local ty
		if egal(t.nom, texte) then
			ty = TYPE.exact
		elseif contient(t.nom, texte) then
			ty = TYPE.nom
		elseif contient(description(T, t), texte) then
			ty = TYPE.description
		elseif descExacte and contient(descExacte, t.nom) then
			ty = TYPE.apparente
		end
		types[t.onglet .. ":" .. t.index] = ty
	end
	return types
end

-- l'apercu : le filtre de nom ; puis les options (TransformPreviewResults)
function K.apercu(texte)
	local trouves = {}
	for _, t in ipairs(talents()) do
		local ty
		if egal(t.nom, texte) then ty = TYPE.exact elseif contient(t.nom, texte) then ty = TYPE.nom end
		if ty and not (K.options.passifs and not t.carre) then
			local nom = t.nom
			if K.options.rangs then nom = nom .. " (" .. t.rang .. "/" .. t.max .. ")" end
			table.insert(trouves, { talent = t, type = ty, nom = nom, cherche = t.nom, icone = t.icone })
		end
	end
	-- PreviewSearchResultSort : le type, puis l'ordre de l'ecran
	local ordre = {}
	for i, r in ipairs(trouves) do ordre[r] = i end
	table.sort(trouves, function(a, b)
		if a.type ~= b.type then return a.type > b.type end
		return ordre[a] < ordre[b]
	end)
	return trouves
end

-- ------------------------------------------------------------ les marques
local function creerMarque(b)
	local m = CreateFrame("Frame", nil, b)
	m:SetWidth(M.marque)
	m:SetHeight(M.marque)
	m:SetPoint("CENTER", b.icone, "TOPRIGHT", 0, 0)
	m:SetFrameLevel(b:GetFrameLevel() + 50)
	local icone = m:CreateTexture(nil, "OVERLAY")
	icone:SetAllPoints(m)
	local battant = m:CreateTexture(nil, "OVERLAY")
	battant:SetAllPoints(m)
	battant:SetBlendMode("ADD")
	battant:SetAlpha(0)
	m.icone, m.battant = icone, battant
	-- le survol : son centre seulement
	local survol = CreateFrame("Frame", nil, m)
	survol:SetWidth(M.marqueSurvol)
	survol:SetHeight(M.marqueSurvol)
	survol:SetPoint("CENTER", m, "CENTER", 0, 0)
	survol:EnableMouse(true)
	survol:SetScript("OnEnter", function(self)
		if not m.info then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(m.info, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		GameTooltip:Show()
	end)
	survol:SetScript("OnLeave", function() GameTooltip:Hide() end)
	m.survol = survol
	-- GlowAnim : 0 -> 0,5 en 1 s, puis 0,5 -> 0 en 1 s, en boucle
	m:SetScript("OnUpdate", function(self, ecoule)
		self.temps = ((self.temps or 0) + ecoule) % (2 * M.battement)
		local t = self.temps
		local a = t < M.battement and t / M.battement or 2 - t / M.battement
		self.battant:SetAlpha(a * M.battementAlpha)
	end)
	m:Hide()
	b.marque = m
	-- une marque monte tres haut (noeud + 50) : la croix repasse au-dessus
	if T.leverCroix then T.leverCroix() end
	return m
end

-- SetSearchMatchType sur chaque noeud montre
local function marquer(types)
	for _, b in pairs(T.arbre and T.arbre.noeuds or {}) do
		local t = b:IsShown() and b.talent
		local ty = t and types[t.onglet .. ":" .. t.index]
		if ty then
			local m = b.marque or creerMarque(b)
			local style = STYLES[ty]
			ForeverUI.SetAtlas(m.icone, style.icone, true)
			ForeverUI.SetAtlas(m.battant, style.icone, true)
			m.info = style.info
			m.type = ty
			m:Show()
		elseif b.marque then
			b.marque.type = nil
			b.marque:Hide()
		end
	end
end

-- ------------------------------------------------------------ le champ
local boite, effacer, apercu, fleche, liste

local function evaluer()
	local t = boite:GetText() or ""
	if string.len(t) >= MIN_LETTRES then return t end
end

local function cacherApercu()
	apercu:Hide()
	apercu.surligne = 0
end

local function majLoupe()
	local actif = boite:HasFocus() or (boite:GetText() or "") ~= ""
	local g = actif and 1 or M.gris
	boite.loupe:SetVertexColor(g, g, g)
	if (boite:GetText() or "") == "" then boite.consigne:Show() else boite.consigne:Hide() end
	if actif then effacer:Show() else effacer:Hide() end
end

-- SetFullResultSearch
function K.chercher(texte)
	if not texte then
		K.quitter()
		return
	end
	if egal(texte, TEXTE.pasSurBarre) then
		K.etat = { filtre = "barres" }
	else
		K.etat = { filtre = "texte", texte = texte }
	end
	K.maj()
end

-- ClearActiveSearchState
function K.quitter()
	K.etat = nil
	if boite then
		boite:ClearFocus()
		boite:SetText("")
		cacherApercu()
		majLoupe()
	end
	K.maj()
end

-- ------------------------------------------------------------ l'apercu
local function ligneResultat(parent, i)
	local l = CreateFrame("Button", "ForeverUITalentsSearchResult" .. i, parent)
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

local function construireApercu(parent)
	local a = CreateFrame("Frame", "ForeverUITalentsSearchPreview", parent)
	a:SetFrameStrata("HIGH")
	a:SetWidth(M.apercuL)
	a:SetPoint("TOPRIGHT", boite, "BOTTOMRIGHT", M.apercuX, M.apercuY)
	a:SetHeight(M.ligneH)
	a:EnableMouse(true)
	a:Hide()
	local fond = a:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "_search-rowbg", true)
	fond:SetAllPoints(a)
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
		l:SetScript("OnEnter", function() K.surligner(i) end)
		l:SetScript("OnClick", function() K.choisir(i) end)
		l:Hide()
		a.lignes[i] = l
	end
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
	sugg:SetScript("OnEnter", function() K.surligner(1) end)
	sugg:SetScript("OnClick", function() K.choisir(1) end)
	sugg:Hide()
	a.suggestion = sugg
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
	a:SetScript("OnUpdate", function(self)
		if not boite:HasFocus() and not MouseIsOver(self) then cacherApercu() end
	end)
	return a
end

function K.majApercu(texte)
	local a = apercu
	a.surligne = 0
	a.resultats = nil
	for _, l in ipairs(a.lignes) do l:Hide() l.surligne:Hide() end
	a.suggestion:Hide()
	a.suggestion.surligne:Hide()
	a.depassement:Hide()
	if not texte then
		a.suggestion:Show()
		a.nombre = 1
		a:SetHeight(M.ligneH + M.basMarge)
		a:Show()
		return
	end
	local trouves = K.apercu(texte)
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

function K.surligner(i)
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

local function parcourir(sens)
	local a = apercu
	if not a:IsShown() or not a.nombre or a.nombre == 0 then return end
	local n, i = a.nombre, a.surligne or 0
	if sens < 0 then i = (i - 2) % n + 1 else i = i % n + 1 end
	K.surligner(i)
end

-- OnPreviewSearchResultClicked : le nom d'origine (sans "(rang/max)")
function K.choisir(i)
	local a = apercu
	PlaySound("igMainMenuOptionCheckBoxOn")
	local texte
	if a.resultats then
		local r = a.resultats[i]
		if not r then return end
		texte = r.cherche
	else
		texte = TEXTE.pasSurBarre
	end
	boite:ClearFocus()
	boite:SetText(texte)
	cacherApercu()
	K.chercher(texte)
end

-- ------------------------------------------------------------ les options
local function majFleche()
	local etat = "common-dropdown-a-button"
	if fleche.enfonce and fleche.survol then
		etat = "common-dropdown-a-button-pressedhover"
	elseif fleche.survol then
		etat = "common-dropdown-a-button-hover"
	elseif fleche.enfonce then
		etat = "common-dropdown-a-button-pressed"
	elseif liste and liste:IsShown() then
		etat = "common-dropdown-a-button-open"
	end
	ForeverUI.SetAtlas(fleche.icone, etat)
end

local function majCoches()
	for _, l in ipairs(liste.lignes) do
		if K.options[l.cle] then l.coche:Show() else l.coche:Hide() end
	end
end

local function construireOptions(parent)
	local b = CreateFrame("Button", "ForeverUITalentsSearchOptions", parent)
	fleche = b
	b:SetWidth(M.fleche)
	b:SetHeight(M.fleche)
	b:SetPoint("LEFT", boite, "RIGHT", M.flecheX, M.flecheY)
	b.icone = b:CreateTexture(nil, "OVERLAY")
	b.icone:SetPoint("CENTER", b, "CENTER", 0, -2)
	b:SetScript("OnEnter", function(self) self.survol = true majFleche() end)
	b:SetScript("OnLeave", function(self) self.survol = false majFleche() end)
	b:SetScript("OnMouseDown", function(self) self.enfonce = true majFleche() end)
	b:SetScript("OnMouseUp", function(self) self.enfonce = false majFleche() end)
	b:SetScript("OnClick", function()
		if liste:IsShown() then liste:Hide() else liste.attente = 0 liste:Show() end
		majFleche()
	end)

	local l0 = CreateFrame("Frame", "ForeverUITalentsSearchOptionsList", parent)
	liste = l0
	l0:SetFrameStrata("DIALOG")
	l0:EnableMouse(true)
	l0:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, 0)
	l0:Hide()
	local tranches = ForeverUI.CreateNineSlice(l0, "common-dropdown-bg-c60", M.fondCoin, M.fondMarges, "BACKGROUND")
	for _, t in ipairs(tranches or {}) do t:SetAlpha(M.fondAlpha) end
	l0.lignes = {}
	local plusLong = 0
	for i, def in ipairs({ { cle = "passifs", texte = TEXTE.masquerPassifs }, { cle = "rangs", texte = TEXTE.rangs } }) do
		local l = CreateFrame("Button", "ForeverUITalentsSearchOption" .. i, l0)
		l:SetHeight(M.ligneMenuH)
		l:SetPoint("TOPLEFT", l0, "TOPLEFT", M.ligneMenuX, -M.bordMenu - (i - 1) * M.ligneMenuH)
		l:SetHighlightTexture("Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight")
		l:GetHighlightTexture():SetBlendMode("ADD")
		local texte = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
		texte:SetPoint("LEFT", l, "LEFT", M.texteMenuX, 0)
		texte:SetText(def.texte)
		plusLong = math.max(plusLong, texte:GetStringWidth() or 0)
		local case = l:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(case, "common-dropdown-ticksquare", true)
		case:SetWidth(M.case)
		case:SetHeight(M.case)
		case:SetPoint("LEFT", l, "LEFT", 0, 0)
		local coche = l:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(coche, "common-dropdown-icon-checkmark-yellow", true)
		coche:SetWidth(M.cocheL)
		coche:SetHeight(M.cocheH)
		coche:SetPoint("CENTER", case, "CENTER", M.cocheX, M.cocheY)
		coche:Hide()
		l.cle, l.texte, l.coche = def.cle, texte, coche
		-- CreateCheckbox : la case bascule, la liste reste ouverte ; l'apercu
		-- ouvert se refait
		l:SetScript("OnClick", function(self)
			PlaySound("UChatScrollButton")
			K.options[self.cle] = not K.options[self.cle]
			majCoches()
			if boite:HasFocus() then K.majApercu(evaluer()) end
		end)
		l0.lignes[i] = l
	end
	local largeur = plusLong + M.largeurPlus + M.margeMenu
	l0:SetWidth(largeur)
	l0:SetHeight(#l0.lignes * M.ligneMenuH + 2 * M.bordMenu)
	for _, l in ipairs(l0.lignes) do l:SetWidth(largeur - M.margeMenu) end
	-- elle se ferme 2 s apres que la souris l'a quittee (et la fleche)
	l0:SetScript("OnUpdate", function(self, ecoule)
		if MouseIsOver(self) or MouseIsOver(fleche) then
			self.attente = 0
		else
			self.attente = (self.attente or 0) + ecoule
			if self.attente >= M.attente then self:Hide() end
		end
	end)
	l0:SetScript("OnShow", majCoches)
	l0:SetScript("OnHide", majFleche)
	majFleche()
end

-- ------------------------------------------------------------ construction
function K.construire(talentsModule)
	if boite then return end
	T = talentsModule
	local parent = T.cadre
	local b = CreateFrame("EditBox", "ForeverUITalentsSearchBox", parent)
	boite = b
	b:SetAutoFocus(false)
	b:SetMaxLetters(M.lettres)
	b:SetHeight(M.boiteH)
	b:SetWidth(M.boiteL)
	b:SetFrameLevel(parent:GetFrameLevel() + 6)
	b:SetFontObject(GameFontHighlightSmall)
	b:SetTextInsets(M.margeG, M.margeD, 0, 0)
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
	local loupe = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(loupe, "common-search-magnifyingglass", true)
	loupe:SetWidth(M.loupe) loupe:SetHeight(M.loupe)
	loupe:SetPoint("LEFT", b, "LEFT", M.loupeX, M.loupeY)
	b.loupe = loupe
	local consigne = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	consigne:SetJustifyH("LEFT")
	consigne:SetJustifyV("MIDDLE")
	consigne:SetPoint("TOPLEFT", b, "TOPLEFT", M.margeG, 0)
	consigne:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -M.margeD, 0)
	consigne:SetTextColor(M.consigneGris, M.consigneGris, M.consigneGris)
	consigne:SetText(TEXTE.consigne)
	b.consigne = consigne

	local e = CreateFrame("Button", "ForeverUITalentsSearchClear", b)
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
	e:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		K.quitter()
	end)
	e:Hide()

	construireOptions(parent)
	fleche:SetFrameLevel(b:GetFrameLevel())
	-- la place : la fleche contre le libelle du compteur, le champ contre la
	-- fleche (camelot : la fleche a RIGHT du champ en (3, -2))
	fleche:ClearAllPoints()
	fleche:SetPoint("RIGHT", T.points.libelle, "LEFT", -M.ecartCompteur, M.flecheY - 1)
	b:SetPoint("RIGHT", fleche, "LEFT", -M.flecheX, -M.flecheY)

	apercu = construireApercu(parent)

	b:SetScript("OnEditFocusGained", function()
		majLoupe()
		K.majApercu(evaluer())
	end)
	b:SetScript("OnEditFocusLost", function()
		majLoupe()
		if not MouseIsOver(apercu) then cacherApercu() end
	end)
	b:SetScript("OnTextChanged", function(self)
		majLoupe()
		if self:HasFocus() then K.majApercu(evaluer()) end
	end)
	b:SetScript("OnEnterPressed", function(self)
		local a = apercu
		if a:IsShown() and (a.surligne or 0) > 0 then
			K.choisir(a.surligne)
			return
		end
		cacherApercu()
		K.chercher(evaluer())
		self:ClearFocus()
	end)
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	b:SetScript("OnKeyDown", function(_, touche)
		if touche == "UP" then parcourir(-1) elseif touche == "DOWN" then parcourir(1) end
	end)
	majLoupe()
	K.boite, K.effacer, K.apercuCadre, K.fleche, K.liste = boite, effacer, apercu, fleche, liste
end

-- la largeur : 184, ou ce qui reste a gauche du compteur (fenetre reduite)
function K.poser(largeurPage)
	if not boite then return end
	local libelle = T.points.libelle
	local droiteLibelle = T.points.droiteLibelle or 0
	local w = libelle:GetStringWidth() or 0
	-- du bord gauche du cadre (page + 2 de chaque cote) a la gauche du champ
	local reste = largeurPage + 4 + droiteLibelle - w - M.ecartCompteur - M.fleche - M.flecheX - M.margeGauche
	boite:SetWidth(math.max(60, math.min(M.boiteL, reste)))
end

-- apres chaque mise a jour de l'ecran : les marques (UpdateFullSearchResults) ;
-- rien sur la page des glyphes
function K.maj()
	if not boite or not T then return end
	if T.glyphes then
		boite:Hide()
		fleche:Hide()
		liste:Hide()
		cacherApercu()
		marquer({})
		return
	end
	boite:Show()
	fleche:Show()
	marquer(K.calculer())
end

-- LES BARRES CHANGENT (un sort pose, retire, une page ou une posture) : la
-- recherche "Missing from action bar" se refait, et le talent qu'on vient de
-- poser perd sa marque (demande du 2026-09-25)
local veille = CreateFrame("Frame")
for _, ev in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
	"ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "PET_BAR_UPDATE", "UPDATE_MULTI_ACTIONBAR" }) do
	veille:RegisterEvent(ev)
end
veille:SetScript("OnEvent", function()
	if K.etat and K.etat.filtre == "barres" and T and T.livre and T.livre:IsVisible() then
		K.maj()
	end
end)
K.veilleBarres = veille

-- les talents deja construits (Blizzard_TalentUI charge avant ce fichier)
if ForeverUI.Talents and ForeverUI.Talents.livre then
	K.construire(ForeverUI.Talents)
	ForeverUI.Talents.maj()
end
