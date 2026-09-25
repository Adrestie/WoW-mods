-- ForeverUI : le suivi de quetes et de hauts faits de camelot, pose sur le
-- WatchFrame de WotLK (docs/SUIVI_DES_QUETES.md).
--
-- L'OSSATURE RESTE CELLE DE WOTLK. WatchFrame, WatchFrameLines, leurs
-- evenements, leurs CVar (trackerSorting, trackerFilter), VISIBLE_WATCHES,
-- WatchFrameItem<n> et l'API des gestionnaires d'objectifs restent en place :
-- WatchFrame_Update appelle toujours, dans l'ordre, les fonctions de
-- WATCHFRAME_OBJECTIVEHANDLERS, et un addon peut toujours y ajouter la sienne.
-- On retire seulement les trois gestionnaires d'affichage de WotLK (minuteurs,
-- hauts faits, quetes) pour poser les deux modules de camelot a leur place.
--
-- RELEVE -- blizzard_objectivetracker (le .toc charge les fichiers de la
-- racine ; camelot/ ne surcharge que CanShowTimerBar) :
--   ObjectiveTrackerFrame   260 de large ; en-tete 260 x 32 en TOPLEFT, fond
--                           ui-questtracker-primary-objective-header a sa
--                           taille, centre ; texte "All Objectives" en
--                           ObjectiveTrackerHeaderFont (14, doree, ombre
--                           1/-1) a LEFT (7, 0), 208 de large ; bouton
--                           reduire-tout 18 x 19 a RIGHT (-1, 0), surbrillance
--                           rouge ; bouton filtre a sa gauche (-2), cache par
--                           defaut
--   modules                 le premier a 38 sous le haut (BASE_TOP_PADDING),
--                           les suivants a 10 du precedent (moduleSpacing)
--   en-tete de module       260 x 26, fond ui-questtracker-secondary-objective-
--                           header centre ; texte a LEFT (7, 0), 200 de large ;
--                           bouton 16 x 16 a RIGHT (1, 0), surbrillance jaune ;
--                           le module compte 25 pour son en-tete (headerHeight)
--   blocs                   a 20 du bord gauche (blockOffsetX), a 10 sous
--                           l'en-tete puis 10 sous le bloc precedent ; titre
--                           en ObjectiveTrackerLineFont (12, ombre) couleur
--                           OBJECTIVE_TRACKER_BLOCK_HEADER_COLOR ; lignes a 4
--                           l'une de l'autre (lineSpacing)
--   lignes                  tiret QUEST_DASH en TOPLEFT (0, 1), texte a sa
--                           droite ; objectif rempli : tiret cache (sa place
--                           reste), gris 0,6, coche 16 x 16 a (-10, 2)
--   objet de quete          26 x 26 en TOPRIGHT du bloc, cadre
--                           ui-questtrackerbutton-questitem-frame 42 x 42 ; le
--                           titre et les lignes s'arretent 2 avant lui
--   repere                  POIButton en TOPRIGHT (-7, 5) du titre
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * le repere est celui de WotLK (decision 3) : QuestPOI_DisplayButton, 32 x
--     32, centre la ou camelot centre son bouton de 20.
--   * le tri, les filtres (decision 2) passent dans le bouton filtre de
--     l'en-tete, que camelot prevoit et cache ; le deplacement manuel dans le
--     menu de la quete.
--   * le minuteur d'une quete : 3.3.5 ne donne que le temps RESTANT
--     (GetQuestTimers). La duree totale de la barre est la plus grande valeur
--     vue depuis le chargement de l'interface.
--   * 3.3.5 n'a ni QUEST_WATCH_LIST_CHANGED ni QUEST_TURNED_IN : une quete
--     nouvellement suivie se reconnait a ce qu'elle n'etait pas dans l'affichage
--     precedent ; l'animation de rendu n'existe pas.
--   * les animations sont jouees a la main (un OnUpdate), aux durees et
--     delais des groupes d'animation de camelot : ceux de 3.3.5 n'ont ni
--     fromAlpha / toAlpha ni setToFinalAlpha.
--   * absents de 3.3.5, donc absents d'ici : le suivi prioritaire (Focus), la
--     progression du groupe au survol, les barres de progression, les
--     fenetres surgissantes de quete automatique.

ForeverUI = ForeverUI or {}

local T = {}
ForeverUI.ObjectiveTracker = T

local G = {
	largeur = 260, enteteH = 32, enteteTexteX = 7, enteteTexteL = 208,
	boutonL = 18, boutonH = 19, boutonX = -1, filtreX = -2,
	hautModules = 38, basLignes = 12,
	moduleEnteteH = 26, moduleCompteEntete = 25, moduleTexteL = 200, moduleBoutonCote = 16, moduleBoutonX = 1,
	blocX = 20, premierBlocY = -10, blocY = -10, ligneEcart = 4,
	objetCote = 26, objetCadre = 42, droiteEcart = 2,
	coche = 16, cocheX = -10, cocheY = 2,
	repereX = -17, repereY = -5,
	lueurLigneL = 180, lueurEnteteL = 240,
	minuteurL = 192, minuteurH = 20, barreL = 128, barreH = 10, barreX = -4,
	criteresMax = 5,
	-- la place par defaut : EditModePresetLayouts de camelot, systeme
	-- ObjectiveTracker, TOPRIGHT de UIParent a (-110, -275)
	defautX = -110, defautY = -275, hauteurMin = 140,
}

-- OBJECTIVE_TRACKER_COLOR, valeurs de GlobalColor.db2 du client camelot
local COULEUR = {
	normal = { 0.8, 0.8, 0.8 }, normalSurvol = { 1, 1, 1 },
	echec = { 0.8, 0.098, 0.098 }, echecSurvol = { 1, 0.125, 0.125 },
	entete = { 0.749, 0.612, 0 }, enteteSurvol = { 1, 0.824, 0 },
	fini = { 0.6, 0.6, 0.6 },
	titre = { 1, 0.824, 0 },                        -- NORMAL_FONT_COLOR
	barre = { 0.26, 0.42, 1 }, fondBarre = { 0.04, 0.07, 0.18 },
}
COULEUR.normal.inverse = COULEUR.normalSurvol
COULEUR.normalSurvol.inverse = COULEUR.normal
COULEUR.echec.inverse = COULEUR.echecSurvol
COULEUR.echecSurvol.inverse = COULEUR.echec

-- Les textes de 3.3.5 quand il les a, ceux de camelot sinon.
local TEXTE = {
	tout = "All Objectives",                  -- TRACKER_ALL_OBJECTIVES
	quetes = "Quests",                        -- TRACKER_HEADER_QUESTS
	hautsFaits = "Achievements",              -- TRACKER_HEADER_ACHIEVEMENTS
	pret = "Ready for turn-in",               -- QUEST_WATCH_QUEST_READY
	voirPage = "Open Quest Details",          -- OBJECTIVES_VIEW_IN_QUESTLOG
	voirCarte = "Open Quest Map",             -- OBJECTIVES_SHOW_QUEST_MAP
	nePlusSuivre = "Untrack",                 -- OBJECTIVES_STOP_TRACKING
	partagerChat = "Share in Chat",           -- SHARE_IN_CHAT
	abandonner = "Abandon",                   -- ABANDON_QUEST_ABBREV
	voirHautFait = "Open Achievement",        -- OBJECTIVES_VIEW_ACHIEVEMENT
	minutes = "%.2d:%.2d",                    -- MINUTES_SECONDS
	heures = "%.2d:%.2d:%.2d",                -- HOURS_MINUTES_SECONDS
}

local POLICE = "Fonts\\FRIZQT__.TTF"

local function couleur(fs, c)
	fs:SetTextColor(c[1], c[2], c[3])
	fs.couleur = c
end

-- ObjectiveTrackerLineFont (12) et ObjectiveTrackerHeaderFont (14), ombre
-- noire (1, -1)
local function police(fs, taille)
	fs:SetFont(POLICE, taille)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
end

local function reglages()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.suivi = ForeverUIDB.suivi or {}
	ForeverUIDB.suivi.replis = ForeverUIDB.suivi.replis or {}
	return ForeverUIDB.suivi
end

-- SecondsToClock de camelot
local function horloge(secondes)
	secondes = math.max(0, math.floor(secondes))
	local h = math.floor(secondes / 3600)
	local m = math.floor((secondes % 3600) / 60)
	local s = secondes % 60
	if h > 0 then
		return format(TEXTE.heures, h, m, s)
	end
	return format(TEXTE.minutes, m, s)
end

-- --------------------------------------------------------- les animations
-- Un seul OnUpdate joue toutes les etapes en cours. Une etape : un delai, une
-- duree, et une fonction qui recoit l'avancement de 0 a 1.
local A = { etapes = {} }
A.cadre = CreateFrame("Frame")
A.cadre:Hide()
A.cadre:SetScript("OnUpdate", function(self, ecoule)
	local restantes = 0
	for cle, e in pairs(A.etapes) do
		e.t = e.t + ecoule
		if e.t >= e.delai then
			local p = (e.duree > 0) and math.min(1, (e.t - e.delai) / e.duree) or 1
			e.fn(p)
			if p >= 1 then
				A.etapes[cle] = nil
				if e.fin then e.fin() end
			else
				restantes = restantes + 1
			end
		else
			restantes = restantes + 1
		end
	end
	if restantes == 0 then self:Hide() end
end)

-- cle : { objet, nom } ; une etape de meme cle remplace la precedente
local function jouer(cle, delai, duree, fn, fin)
	cle = tostring(cle[1]) .. cle[2]
	A.etapes[cle] = { t = 0, delai = delai, duree = duree, fn = fn, fin = fin }
	A.cadre:Show()
end
T.jouer = jouer

-- smoothing="OUT"
local function sortie(p) return 1 - (1 - p) * (1 - p) end

-- --------------------------------------------------------- les boutons
local function boutonAtlas(parent, l, h, normal, presse, survol)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(l)
	b:SetHeight(h)
	local e = ForeverUI.AtlasEntry(normal)
	b:SetNormalTexture(e and e[1] or "")
	ForeverUI.SetAtlas(b:GetNormalTexture(), normal, true)
	b:GetNormalTexture():SetAllPoints(b)
	b:SetPushedTexture(e and e[1] or "")
	ForeverUI.SetAtlas(b:GetPushedTexture(), presse, true)
	b:GetPushedTexture():SetAllPoints(b)
	b:SetHighlightTexture(e and e[1] or "")
	local s = b:GetHighlightTexture()
	ForeverUI.SetAtlas(s, survol, true)
	s:SetAllPoints(b)
	s:SetBlendMode("ADD")
	return b
end

local function etatsBouton(b, normal, presse)
	ForeverUI.SetAtlas(b:GetNormalTexture(), normal, true)
	ForeverUI.SetAtlas(b:GetPushedTexture(), presse, true)
end

local function menu(ancre, liste)
	if ForeverUI.WorldMap and ForeverUI.WorldMap.ouvrirMenu then
		ForeverUI.WorldMap.ouvrirMenu(ancre, liste)
	end
end

-- --------------------------------------------------------- l'en-tete general
-- ObjectiveTrackerContainerHeaderTemplate, pose sur WatchFrame
local function creerEntete()
	local h = CreateFrame("Frame", "ForeverUIObjectiveTrackerHeader", WatchFrame)
	h:SetWidth(G.largeur)
	h:SetHeight(G.enteteH)
	h:SetPoint("TOPLEFT", WatchFrame, "TOPLEFT", 0, 0)
	local fond = h:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "ui-questtracker-primary-objective-header")
	fond:SetPoint("CENTER", h, "CENTER", 0, 0)
	h.fond = fond
	local texte = h:CreateFontString(nil, "ARTWORK")
	police(texte, 14)
	couleur(texte, COULEUR.titre)
	texte:SetWidth(G.enteteTexteL)
	texte:SetJustifyV("MIDDLE")
	texte:SetPoint("LEFT", h, "LEFT", G.enteteTexteX, 0)
	texte:SetText(TEXTE.tout)
	h.texte = texte

	local reduire = boutonAtlas(h, G.boutonL, G.boutonH, "ui-questtrackerbutton-collapse-all",
		"ui-questtrackerbutton-collapse-all-pressed", "ui-questtrackerbutton-red-highlight")
	reduire:SetPoint("RIGHT", h, "RIGHT", G.boutonX, 0)
	-- WatchFrame_CollapseExpandButton_OnClick, au son de camelot
	reduire:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		if WatchFrame.collapsed then
			WatchFrame.userCollapsed = nil
			WatchFrame_Expand(WatchFrame)
		else
			WatchFrame.userCollapsed = true
			WatchFrame_Collapse(WatchFrame)
		end
	end)
	h.reduire = reduire

	-- le bouton filtre : le tri et les filtres de WotLK (decision 2)
	local filtre = boutonAtlas(h, G.boutonL, G.boutonH, "ui-questtrackerbutton-filter",
		"ui-questtrackerbutton-filter-pressed", "ui-questtrackerbutton-red-highlight")
	filtre:SetPoint("RIGHT", reduire, "LEFT", G.filtreX, 0)
	filtre:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		T.menuFiltres(self)
	end)
	h.filtre = filtre
	h:Hide()
	return h
end

-- WatchFrameHeaderDropDown_Initialize, entree pour entree
function T.menuFiltres(ancre)
	local tri = WATCHFRAME_SORT_TYPE
	local filtre = WATCHFRAME_FILTER_TYPE
	local function trier(valeur)
		return function() WatchFrame_SetSorting(nil, valeur) end
	end
	local function filtrer(valeur)
		return function() WatchFrame_SetFilter(nil, valeur) end
	end
	local function actif(bit_)
		return bit.band(filtre, bit_) == bit_
	end
	menu(ancre, {
		{ text = TRACKER_SORT_LABEL, isTitle = true },
		{ text = TRACKER_SORT_PROXIMITY, checked = tri == WATCHFRAME_SORT_PROXIMITY, func = trier(WATCHFRAME_SORT_PROXIMITY) },
		{ text = TRACKER_SORT_DIFFICULTY_HIGH, checked = tri == WATCHFRAME_SORT_DIFFICULTY_HIGH, func = trier(WATCHFRAME_SORT_DIFFICULTY_HIGH) },
		{ text = TRACKER_SORT_DIFFICULTY_LOW, checked = tri == WATCHFRAME_SORT_DIFFICULTY_LOW, func = trier(WATCHFRAME_SORT_DIFFICULTY_LOW) },
		{ text = TRACKER_SORT_MANUAL, checked = tri == WATCHFRAME_SORT_MANUAL, func = trier(WATCHFRAME_SORT_MANUAL) },
		{ text = TRACKER_FILTER_LABEL, isTitle = true },
		{ text = TRACKER_FILTER_ACHIEVEMENTS, checked = actif(WATCHFRAME_FILTER_ACHIEVEMENTS), keepShownOnClick = 1, func = filtrer(WATCHFRAME_FILTER_ACHIEVEMENTS) },
		{ text = TRACKER_FILTER_COMPLETED_QUESTS, checked = actif(WATCHFRAME_FILTER_COMPLETED_QUESTS), keepShownOnClick = 1, func = filtrer(WATCHFRAME_FILTER_COMPLETED_QUESTS) },
		{ text = TRACKER_FILTER_REMOTE_ZONES, checked = actif(WATCHFRAME_FILTER_REMOTE_ZONES), keepShownOnClick = 1, func = filtrer(WATCHFRAME_FILTER_REMOTE_ZONES) },
	})
end

-- --------------------------------------------------------- les modules
-- ObjectiveTrackerModuleTemplate : un en-tete, puis les blocs.
local function creerModule(nom, titre, cle)
	local m = CreateFrame("Frame", nom, WatchFrameLines)
	m:SetWidth(G.largeur)
	m:SetHeight(10)
	m.cle = cle
	local h = CreateFrame("Frame", nil, m)
	h:SetWidth(G.largeur)
	h:SetHeight(G.moduleEnteteH)
	h:SetPoint("TOPLEFT", m, "TOPLEFT", 0, 0)
	local fond = h:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "ui-questtracker-secondary-objective-header")
	fond:SetPoint("CENTER", h, "CENTER", 0, 0)
	local texte = h:CreateFontString(nil, "ARTWORK")
	police(texte, 14)
	couleur(texte, COULEUR.titre)
	texte:SetWidth(G.moduleTexteL)
	texte:SetJustifyV("MIDDLE")
	texte:SetPoint("LEFT", h, "LEFT", G.enteteTexteX, 0)
	texte:SetText(titre)
	local brillant = h:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(brillant, "ui-questtracker-objfx-shine")
	brillant:SetWidth(brillant:GetWidth() * 0.95)
	brillant:SetHeight(brillant:GetHeight() * 0.95)
	brillant:SetPoint("CENTER", h, "CENTER", -150, 1)
	brillant:SetAlpha(0)
	local lueur = h:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(lueur, "ui-questtracker-objfx-barglow")
	lueur:SetPoint("CENTER", h, "CENTER", -120, 1)
	lueur:SetAlpha(0)
	local bouton = boutonAtlas(h, G.moduleBoutonCote, G.moduleBoutonCote, "ui-questtrackerbutton-secondary-collapse",
		"ui-questtrackerbutton-secondary-collapse-pressed", "ui-questtrackerbutton-yellow-highlight")
	bouton:SetPoint("RIGHT", h, "RIGHT", G.moduleBoutonX, 0)
	bouton:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		local r = reglages().replis
		r[cle] = not r[cle] or nil
		WatchFrame_Update()
	end)
	h.fond, h.texte, h.brillant, h.lueur, h.bouton = fond, texte, brillant, lueur, bouton
	m.entete = h
	m.blocs, m.libres = {}, {}
	m:Hide()
	return m
end

-- ObjectiveTrackerModuleHeaderMixin:PlayAddAnimation
local function animerEnteteModule(m)
	local h = m.entete
	local cle = m
	h.fond:SetAlpha(0)
	h.bouton:SetAlpha(0)
	jouer({ cle, "fond" }, 0, 0.5, function(p) h.fond:SetAlpha(p) end)
	jouer({ cle, "bouton" }, 0, 1, function(p) h.bouton:SetAlpha(p) end)
	jouer({ cle, "lueur" }, 0, 0.2, function(p) h.lueur:SetAlpha(p) end, function()
		jouer({ cle, "lueur" }, 0, 0.6, function(p) h.lueur:SetAlpha(1 - p) end)
	end)
	jouer({ cle, "brillant" }, 0.2, 1.2, function(p)
		local q = math.min(1, p * 1.2 / 0.7)
		h.brillant:ClearAllPoints()
		h.brillant:SetPoint("CENTER", h, "CENTER", -150 + 200 * q, 1)
		h.brillant:SetAlpha(1 - p)
	end, function() h.brillant:SetAlpha(0) end)
end

-- --------------------------------------------------------- les blocs
local function creerLigne(bloc)
	local l = CreateFrame("Frame", nil, bloc)
	local tiret = l:CreateFontString(nil, "ARTWORK")
	police(tiret, 12)
	tiret:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 1)
	tiret:SetText(QUEST_DASH)
	local texte = l:CreateFontString(nil, "ARTWORK")
	police(texte, 12)
	texte:SetPoint("TOP", l, "TOP", 0, 0)
	texte:SetPoint("LEFT", tiret, "RIGHT", 0, 0)
	local coche = l:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(coche, "ui-questtracker-tracker-check", true)
	coche:SetWidth(G.coche)
	coche:SetHeight(G.coche)
	coche:SetPoint("TOPLEFT", l, "TOPLEFT", G.cocheX, G.cocheY)
	coche:Hide()
	local eclat = l:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(eclat, "ui-questtracker-tracker-check-glow", true)
	eclat:SetWidth(G.coche)
	eclat:SetHeight(G.coche)
	eclat:SetPoint("CENTER", coche, "CENTER", 0, 0)
	eclat:SetAlpha(0)
	local lueur = l:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(lueur, "ui-questtracker-objfx-barglow", true)
	lueur:SetWidth(G.lueurLigneL)
	lueur:SetPoint("LEFT", texte, "LEFT", -2, 0)
	lueur:SetPoint("TOP", l, "TOP", 0, 0)
	lueur:SetPoint("BOTTOM", l, "BOTTOM", 0, -4)
	lueur:SetAlpha(0)
	l.tiret, l.texte, l.coche, l.eclat, l.lueur = tiret, texte, coche, eclat, lueur
	return l
end

-- ObjectiveTrackerTimerBarTemplate
local function creerMinuteur(bloc)
	local m = CreateFrame("Frame", nil, bloc)
	m:SetWidth(G.minuteurL)
	m:SetHeight(G.minuteurH)
	-- GameFontHighlightMedium de camelot : FRIZQT 14, blanc, ombre
	local texte = m:CreateFontString(nil, "ARTWORK")
	texte:SetFont(POLICE, 14)
	texte:SetShadowOffset(1, -1)
	texte:SetShadowColor(0, 0, 0, 1)
	texte:SetJustifyH("LEFT")
	texte:SetPoint("LEFT", m, "LEFT", 0, 0)
	local barre = CreateFrame("StatusBar", nil, m)
	barre:SetWidth(G.barreL)
	barre:SetHeight(G.barreH)
	barre:SetPoint("RIGHT", m, "RIGHT", G.barreX, 0)
	barre:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	barre:SetStatusBarColor(COULEUR.barre[1], COULEUR.barre[2], COULEUR.barre[3])
	local fond = barre:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture(COULEUR.fondBarre[1], COULEUR.fondBarre[2], COULEUR.fondBarre[3])
	fond:SetAllPoints(barre)
	local BORD = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
	local g = barre:CreateTexture(nil, "ARTWORK")
	g:SetTexture(BORD)
	g:SetTexCoord(0.007843, 0.043137, 0.193548, 0.774193)
	g:SetWidth(9) g:SetHeight(14)
	g:SetPoint("LEFT", barre, "LEFT", -3, 0)
	local d = barre:CreateTexture(nil, "ARTWORK")
	d:SetTexture(BORD)
	d:SetTexCoord(0.043137, 0.007843, 0.193548, 0.774193)
	d:SetWidth(9) d:SetHeight(14)
	d:SetPoint("RIGHT", barre, "RIGHT", 3, 0)
	local mi = barre:CreateTexture(nil, "ARTWORK")
	mi:SetTexture(BORD)
	mi:SetTexCoord(0.113726, 0.1490196, 0.193548, 0.774193)
	mi:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	mi:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	m.texte, m.barre = texte, barre
	-- ObjectiveTrackerTimerBarMixin:OnUpdate et GetTextColor
	m:SetScript("OnUpdate", function(self)
		if not self.duree then return end
		local reste = self.duree - (GetTime() - self.debut)
		self.barre:SetValue(math.max(0, reste))
		if reste < -1 then
			self.duree = nil
			WatchFrame_Update()
			return
		end
		reste = math.max(0, reste)
		self.texte:SetText(horloge(reste))
		local part = reste / self.duree
		if part > 0.66 then
			self.texte:SetTextColor(1, 1, 1)
		elseif part > 0.33 then
			self.texte:SetTextColor(1, 1, (part - 0.33) / 0.33)
		else
			self.texte:SetTextColor(1, part / 0.33, 0)
		end
	end)
	return m
end

local function creerBloc(m)
	local b = CreateFrame("Frame", nil, m)
	local titre = b:CreateFontString(nil, "ARTWORK")
	police(titre, 12)
	titre:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.titre = titre
	local lueur = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(lueur, "ui-questtracker-objfx-barglow", true)
	lueur:SetWidth(G.lueurEnteteL)
	lueur:SetPoint("TOPLEFT", titre, "TOPLEFT", 0, 3)
	lueur:SetPoint("BOTTOMLEFT", titre, "BOTTOMLEFT", 0, -4)
	lueur:SetAlpha(0)
	b.lueur = lueur
	-- HeaderButton : sur le titre, clic gauche et droit
	local bouton = CreateFrame("Button", nil, b)
	bouton:SetPoint("TOPLEFT", titre, "TOPLEFT", 0, 0)
	bouton:SetPoint("BOTTOMRIGHT", titre, "BOTTOMRIGHT", 0, 0)
	bouton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	bouton:SetScript("OnClick", function(_, souris) m.clic(b, souris) end)
	bouton:SetScript("OnEnter", function() T.surligner(b, true) end)
	bouton:SetScript("OnLeave", function() T.surligner(b, false) end)
	b.bouton = bouton
	b.lignes, b.lignesLibres = {}, {}
	return b
end

-- ObjectiveTrackerBlockMixin:UpdateHighlight
function T.surligner(b, oui)
	b.survol = oui
	couleur(b.titre, oui and COULEUR.enteteSurvol or COULEUR.entete)
	local tiret = oui and COULEUR.normalSurvol or COULEUR.normal
	for _, l in ipairs(b.lignesMontrees or {}) do
		local c = l.texte.couleur
		if c and c.inverse and ((oui and (c == COULEUR.normal or c == COULEUR.echec))
			or (not oui and (c == COULEUR.normalSurvol or c == COULEUR.echecSurvol))) then
			couleur(l.texte, c.inverse)
		end
		l.tiret:SetTextColor(tiret[1], tiret[2], tiret[3])
	end
end

-- Un bloc repart de zero a chaque passage (Reset), ses lignes aussi.
local function prendreBloc(m, id)
	local b = m.blocs[id]
	if not b then
		b = table.remove(m.libres) or creerBloc(m)
		m.blocs[id] = b
	end
	b.id, b.utilise = id, true
	b:SetWidth(G.largeur - G.blocX)
	b.hauteur = 0
	b.dernier = nil
	b.droite = 0
	b.lignesMontrees = {}
	for _, l in pairs(b.lignes) do l.utilisee = nil end
	if b.minuteur then b.minuteur:Hide() b.minuteur.duree = nil end
	b:ClearAllPoints()
	b:SetAlpha(1)
	b.titre:SetAlpha(1)
	return b
end

-- Les largeurs sont posees a la main : le bloc n'est pas encore place quand
-- on mesure ses textes, et 3.3.5 ne sait mesurer qu'un texte qui a une
-- largeur (camelot, lui, s'en remet aux ancres).
local function titreBloc(b, texte)
	b.titre:SetWidth(G.largeur - G.blocX + b.droite)
	b.titre:SetHeight(0)
	b.titre:SetText(texte)
	couleur(b.titre, b.survol and COULEUR.enteteSurvol or COULEUR.entete)
	b.hauteur = b.titre:GetHeight()
end

-- ObjectiveTrackerBlockMixin:AddObjective
local function ligne(b, cle, texte, tiret, c)
	local l = b.lignes[cle]
	if not l then
		l = table.remove(b.lignesLibres) or creerLigne(b)
		b.lignes[cle] = l
	end
	l.utilisee = true
	l:ClearAllPoints()
	l:SetPoint("TOPLEFT", b.dernier or b.titre, "BOTTOMLEFT", 0, -G.ligneEcart)
	local largeur = G.largeur - G.blocX + b.droite
	l:SetWidth(largeur)
	l.tiret:SetText(QUEST_DASH)
	if tiret then l.tiret:Show() else l.tiret:Hide() end
	l.texte:SetWidth(largeur - l.tiret:GetStringWidth())
	l.texte:SetHeight(0)
	l.texte:SetText(texte)
	c = c or COULEUR.normal
	if b.survol and c.inverse then c = c.inverse end
	couleur(l.texte, c)
	local tc = b.survol and COULEUR.normalSurvol or COULEUR.normal
	l.tiret:SetTextColor(tc[1], tc[2], tc[3])
	local h = l.texte:GetHeight()
	l:SetHeight(h)
	l:SetAlpha(1)
	l:Show()
	b.hauteur = b.hauteur + h + G.ligneEcart
	b.dernier = l
	table.insert(b.lignesMontrees, l)
	return l
end

-- ObjectiveTrackerBlockMixin:AddTimerBar
local function minuteur(b, duree, debut)
	if not b.minuteur then b.minuteur = creerMinuteur(b) end
	local m = b.minuteur
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", b.dernier or b.titre, "BOTTOMLEFT", 0, -G.ligneEcart)
	m.barre:SetMinMaxValues(0, duree)
	m.duree, m.debut = duree, debut
	m:Show()
	b.hauteur = b.hauteur + G.minuteurH + G.ligneEcart
	b.dernier = m
end

-- les lignes non reprises et les blocs non repris sont rendus
local function libererLignes(b)
	for cle, l in pairs(b.lignes) do
		if not l.utilisee then
			l:Hide()
			l.coche:Hide()
			l.lueur:SetAlpha(0)
			l.eclat:SetAlpha(0)
			b.lignes[cle] = nil
			table.insert(b.lignesLibres, l)
		end
	end
end

local function libererBlocs(m)
	for id, b in pairs(m.blocs) do
		if not b.utilise then
			b:Hide()
			b.survol = nil
			m.blocs[id] = nil
			table.insert(m.libres, b)
		end
	end
end

-- l'etat de coche d'une ligne : Completed = coche montree, sans animation ;
-- Completing = coche + eclat + lueur (CheckAnim et GlowAnim)
local function cocher(l, animer)
	l.coche:Show()
	if not animer then
		l.coche:SetAlpha(1)
		return
	end
	jouer({ l, "coche" }, 0, 0.3, function(p)
		local s = (p < 0.5) and (1 + 0.2 * sortie(p * 2)) or (1.2 - 0.2 * sortie((p - 0.5) * 2))
		l.coche:SetWidth(G.coche * s)
		l.coche:SetHeight(G.coche * s)
		l.coche:SetAlpha(math.min(1, p / 0.53))
		l.eclat:SetWidth(G.coche * s)
		l.eclat:SetHeight(G.coche * s)
		l.eclat:SetAlpha(p < 0.5 and p * 2 or (1 - p) * 2)
	end, function()
		l.coche:SetWidth(G.coche) l.coche:SetHeight(G.coche) l.coche:SetAlpha(1)
		l.eclat:SetAlpha(0)
	end)
	T.balayer(l.lueur, G.lueurLigneL, 0.1, 0.66, 0.33, 0.58)
end

-- une lueur qui s'etire depuis la gauche (Scale x 0 -> 1, origine LEFT) et
-- s'efface ensuite (Alpha 1 -> 0)
function T.balayer(t, largeur, delai, duree, delaiAlpha, dureeAlpha)
	jouer({ t, "largeur" }, delai, duree, function(p)
		t:SetWidth(math.max(1, largeur * sortie(p)))
	end)
	jouer({ t, "alpha" }, delaiAlpha, dureeAlpha, function(p) t:SetAlpha(1 - p) end,
		function() t:SetAlpha(0) t:SetWidth(largeur) end)
end

-- ObjectiveTrackerAnimBlockMixin:PlayAddAnimation : la lueur du titre, le
-- titre et les lignes qui apparaissent
local function animerAjout(b)
	b.lueur:SetWidth(1)
	b.lueur:SetAlpha(1)
	jouer({ b.lueur, "largeur" }, 0.15, 0.31, function(p) b.lueur:SetWidth(math.max(1, G.lueurEnteteL * p)) end)
	jouer({ b.lueur, "alpha" }, 0.33, 0.41, function(p) b.lueur:SetAlpha(1 - p) end,
		function() b.lueur:SetAlpha(0) b.lueur:SetWidth(G.lueurEnteteL) end)
	b.titre:SetAlpha(0)
	jouer({ b.titre, "alpha" }, 0, 0.03, function(p) b.titre:SetAlpha(p) end)
	for _, l in ipairs(b.lignesMontrees) do
		l:SetAlpha(0)
		jouer({ l, "entree" }, 0, 0.5, function(p) l:SetAlpha(p) end)
	end
end

-- --------------------------------------------------------- la mise en page
-- ObjectiveTrackerModuleMixin : BeginLayout, AddBlock / CanFitBlock,
-- EndLayout. Rend la hauteur prise par le module, 0 s'il ne se montre pas.
local function debuter(m, place)
	m.place = place
	m.hauteur = G.moduleCompteEntete
	m.dernier = nil
	m.contenu = false
	m.saute = false
	m.essaye = false
	for _, b in pairs(m.blocs) do b.utilise = nil end
end

-- rend vrai si le bloc a trouve sa place
local function placer(m, b)
	m.essaye = true
	libererLignes(b)
	b:SetHeight(math.max(1, b.hauteur))
	local ecart = m.dernier and G.blocY or G.premierBlocY
	if m.hauteur + b.hauteur - ecart > m.place then
		m.saute = true
		b.utilise = nil
		return false
	end
	m.contenu = true
	if reglages().replis[m.cle] then
		b.utilise = nil
		return true
	end
	b:ClearAllPoints()
	if m.dernier then
		b:SetPoint("TOP", m.dernier, "BOTTOM", 0, ecart)
	else
		b:SetPoint("TOP", m.entete, "BOTTOM", 0, ecart)
	end
	b:SetPoint("LEFT", m, "LEFT", G.blocX, 0)
	b:SetPoint("RIGHT", m, "RIGHT", 0, 0)
	b:Show()
	m.hauteur = m.hauteur + b.hauteur - ecart
	m.dernier = b
	return true
end

local function terminer(m, lineFrame, decalage)
	libererBlocs(m)
	local replie = reglages().replis[m.cle]
	etatsBouton(m.entete.bouton,
		replie and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse",
		replie and "ui-questtrackerbutton-secondary-expand-pressed" or "ui-questtrackerbutton-secondary-collapse-pressed")
	if m.contenu then
		m:ClearAllPoints()
		m:SetPoint("TOPLEFT", lineFrame, "TOPLEFT", 0, decalage)
		m:SetHeight(m.hauteur)
		local etaitLa = m:IsShown() and m.montre
		m:Show()
		m.montre = true
		if not etaitLa then animerEnteteModule(m) end
		return m.hauteur
	end
	m:Hide()
	m.montre = nil
	return 0
end

-- la place qu'il reste dans WatchFrameLines, sous ce decalage
local function placeRestante(maxHeight, decalage)
	return (maxHeight or 0) - G.hautModules - G.basLignes + (decalage or 0)
end

-- --------------------------------------------------------- les quetes
local Q = { etats = {}, vus = nil, durees = {} }

-- WatchFrame_DisplayTrackedQuests pour les donnees, QuestObjectiveTracker
-- pour l'affichage
local function afficherQuetes(lineFrame, initialOffset, maxHeight, frameWidth)
	local m = T.quetes
	debuter(m, placeRestante(maxHeight, initialOffset))
	local argent = GetMoney()
	local nbSuivies = GetNumQuestWatches()
	local nPOI = { numerique = 0, dedans = 0, dehors = 0 }
	local objets = 0
	local vus = {}
	for w = 1, nbSuivies do
		local index = GetQuestIndexForWatch(w)
		if index then
			local titre, _, _, _, _, _, _, _, questID = GetQuestLogTitle(index)
			vus[questID or titre] = true
		end
	end
	local minuteurs = {}
	local timers = { GetQuestTimers() }
	for i, secondes in ipairs(timers) do
		local index = GetQuestIndexForTimer(i)
		if index then minuteurs[index] = secondes end
	end

	local selection
	if WorldMapFrame and WorldMapFrame:IsShown() then
		selection = WORLDMAP_SETTINGS.selectedQuestId
	else
		table.wipe(LOCAL_MAP_QUESTS)
		LOCAL_MAP_QUESTS["zone"] = GetCurrentMapZone()
		for id in pairs(CURRENT_MAP_QUESTS) do
			LOCAL_MAP_QUESTS[id] = true
		end
	end
	table.wipe(VISIBLE_WATCHES)

	for w = 1, nbSuivies do
		local index = GetQuestIndexForWatch(w)
		if index then
			local titre, _, _, _, _, _, complet, _, questID = GetQuestLogTitle(index)
			local requis = GetQuestLogRequiredMoney(index)
			local nbObjectifs = GetNumQuestLeaderBoards(index)
			local echec = complet and complet < 0
			if echec then
				complet = false
			elseif complet and complet > 0 then
				complet = true
			elseif nbObjectifs == 0 and argent >= requis then
				complet = true
			else
				complet = false
			end
			-- les filtres de WotLK
			local garder = true
			if complet and bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_COMPLETED_QUESTS) ~= WATCHFRAME_FILTER_COMPLETED_QUESTS then
				garder = false
			elseif bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_REMOTE_ZONES) ~= WATCHFRAME_FILTER_REMOTE_ZONES and not LOCAL_MAP_QUESTS[questID] then
				garder = false
			end
			if garder then
				if requis > 0 then WatchFrame.watchMoney = true end
				local _, objet, charges = GetQuestLogSpecialItemInfo(index)
				local cle = questID or titre
				local avant = Q.etats[cle]
				local etat = { fini = {}, complet = complet }
				local b = prendreBloc(m, cle)
				b.index, b.watch, b.questID, b.titreQuete = index, w, questID, titre
				-- l'objet de quete, a droite du bloc
				local bouton
				if objet and not complet then
					objets = objets + 1
					bouton = T.objet(objets, lineFrame, index, objet, charges)
					b.droite = -(G.objetCote + G.droiteEcart)
				end
				titreBloc(b, titre)

				local animer = {}
				if complet then
					-- QUEST_LOG_UPDATE : les objectifs deja montres s'effacent
					-- (FadeOutAnim : 1 s puis 0,1 s), puis le texte de rendu
					local fondu = avant and not avant.complet and not (avant.fondu and avant.fondu <= GetTime())
					if fondu then
						etat.fondu = avant.fondu or (GetTime() + 1.1)
						for j = 1, nbObjectifs do
							local texte = GetQuestLogLeaderBoard(j, index)
							if texte then
								local l = ligne(b, j, WatchFrame_ReverseQuestObjective(texte), false, COULEUR.fini)
								etat.fini[j] = true
								table.insert(animer, { l, not (avant.fini and avant.fini[j]) })
								jouer({ l, "fondu" }, math.max(0, etat.fondu - 0.1 - GetTime()), 0.1,
									function(p) l:SetAlpha(1 - p) end)
							end
						end
						etat.complet = false
						T.relancer(etat.fondu)
					else
						local rendu = GetQuestLogCompletionText(index)
						if rendu then
							ligne(b, "QuestComplete", rendu, false)
						else
							ligne(b, "QuestComplete", TEXTE.pret, false, COULEUR.fini)
						end
					end
				elseif echec then
					ligne(b, "Failed", FAILED, false, COULEUR.echec)
				else
					for j = 1, nbObjectifs do
						local texte, _, fini = GetQuestLogLeaderBoard(j, index)
						if texte then
							texte = WatchFrame_ReverseQuestObjective(texte)
							if fini then
								etat.fini[j] = true
								local l = ligne(b, j, texte, false, COULEUR.fini)
								table.insert(animer, { l, avant and not (avant.fini and avant.fini[j]) })
							else
								local l = ligne(b, j, texte, true)
								l.coche:Hide()
							end
						end
					end
					if requis > argent then
						ligne(b, "Money", GetMoneyString(argent) .. " / " .. GetMoneyString(requis), true)
					end
					local reste = minuteurs[index]
					if reste then
						local duree = math.max(Q.durees[cle] or 0, reste)
						Q.durees[cle] = duree
						minuteur(b, duree, GetTime() - (duree - reste))
					end
				end

				Q.etats[cle] = etat
				if placer(m, b) then
					if not reglages().replis[m.cle] then
						table.insert(VISIBLE_WATCHES, index)
						for _, a in ipairs(animer) do cocher(a[1], a[2]) end
						if bouton then
							bouton:ClearAllPoints()
							bouton:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
							bouton:Show()
						end
						-- le repere de WotLK, centre ou camelot centre le sien
						if WatchFrame.showObjectives then
							local poi
							if CURRENT_MAP_QUESTS[questID] then
								if complet then
									nPOI.dedans = nPOI.dedans + 1
									poi = QuestPOI_DisplayButton("WatchFrameLines", QUEST_POI_COMPLETE_IN, nPOI.dedans, questID)
								else
									nPOI.numerique = nPOI.numerique + 1
									poi = QuestPOI_DisplayButton("WatchFrameLines", QUEST_POI_NUMERIC, nPOI.numerique, questID)
								end
							elseif complet then
								nPOI.dehors = nPOI.dehors + 1
								poi = QuestPOI_DisplayButton("WatchFrameLines", QUEST_POI_COMPLETE_OUT, nPOI.dehors, questID)
							end
							if poi then
								poi:ClearAllPoints()
								poi:SetPoint("CENTER", b.titre, "TOPLEFT", G.repereX, G.repereY)
							end
						end
						-- une quete qui n'etait pas la au passage precedent
						if Q.vus and not Q.vus[cle] then
							animerAjout(b)
						end
					elseif bouton then
						bouton:Hide()
					end
				else
					if bouton then
						bouton:Hide()
						objets = objets - 1
					end
					break
				end
			end
		end
	end

	for i = objets + 1, WATCHFRAME_NUM_ITEMS do
		local it = _G["WatchFrameItem" .. i]
		if it then it:Hide() end
	end
	QuestPOI_HideButtons("WatchFrameLines", QUEST_POI_NUMERIC, nPOI.numerique + 1)
	QuestPOI_HideButtons("WatchFrameLines", QUEST_POI_COMPLETE_IN, nPOI.dedans + 1)
	QuestPOI_HideButtons("WatchFrameLines", QUEST_POI_COMPLETE_OUT, nPOI.dehors + 1)
	if selection then
		QuestPOI_SelectButtonByQuestId("WatchFrameLines", selection, true)
	end
	-- le premier passage ne fete aucune quete : elles etaient deja la
	for cle in pairs(Q.etats) do
		if not vus[cle] then Q.etats[cle] = nil end
	end
	Q.vus = vus
	local hauteur = terminer(m, lineFrame, initialOffset)
	return hauteur, G.largeur, nbSuivies
end
T.afficherQuetes = afficherQuetes

-- un passage de plus quand un fondu se termine
function T.relancer(quand)
	jouer({ T, "relance" }, math.max(0, quand - GetTime()), 0, function() end, function()
		WatchFrame_Update()
	end)
end

-- WatchFrameItem<n> : les boutons de WotLK, rhabilles une fois
function T.objet(n, lineFrame, index, icone, charges)
	local b = _G["WatchFrameItem" .. n]
	if not b then
		WATCHFRAME_NUM_ITEMS = n
		b = CreateFrame("Button", "WatchFrameItem" .. n, lineFrame, "WatchFrameItemButtonTemplate")
	end
	if not b.foreverHabille then
		b.foreverHabille = true
		b:SetWidth(G.objetCote)
		b:SetHeight(G.objetCote)
		local e = ForeverUI.AtlasEntry("ui-questtrackerbutton-questitem-frame")
		b:SetNormalTexture(e and e[1] or "")
		local t = b:GetNormalTexture()
		ForeverUI.SetAtlas(t, "ui-questtrackerbutton-questitem-frame", true)
		t:ClearAllPoints()
		t:SetWidth(G.objetCadre)
		t:SetHeight(G.objetCadre)
		t:SetPoint("CENTER", b, "CENTER", 0, 0)
		b:SetPushedTexture(e and e[1] or "")
		local p = b:GetPushedTexture()
		ForeverUI.SetAtlas(p, "ui-questtrackerbutton-questitem-frame", true)
		p:ClearAllPoints()
		p:SetWidth(G.objetCadre)
		p:SetHeight(G.objetCadre)
		p:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
	b:SetID(index)
	SetItemButtonTexture(b, icone)
	SetItemButtonCount(b, charges)
	b.charges = charges
	WatchFrameItem_UpdateCooldown(b)
	b.rangeTimer = -1
	return b
end

-- --------------------------------------------------------- les hauts faits
local function afficherHautsFaits(lineFrame, initialOffset, maxHeight, frameWidth, ...)
	local m = T.hautsFaits
	debuter(m, placeRestante(maxHeight, initialOffset))
	local nb = select("#", ...)
	local arene = ArenaEnemyFrames and ArenaEnemyFrames:IsShown()
	if bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_ACHIEVEMENTS) == WATCHFRAME_FILTER_ACHIEVEMENTS then
		for i = 1, nb do
			local id = select(i, ...)
			local categorie = GetAchievementCategory(id)
			local _, nom, _, fait, _, _, _, description = GetAchievementInfo(id)
			if not fait and not arene or categorie == WATCHFRAME_ACHIEVEMENT_ARENA_CATEGORY then
				local b = prendreBloc(m, id)
				b.hautFait = id
				titreBloc(b, nom)
				local nbCriteres = GetAchievementNumCriteria(id)
				if nbCriteres > 0 then
					local montres = 0
					for j = 1, nbCriteres do
						local texte, _, rempli, _, _, _, drapeaux, _, quantite, critere = GetAchievementCriteriaInfo(id, j)
						if rempli or montres > G.criteresMax then
							-- rien
						elseif montres == G.criteresMax and nbCriteres > G.criteresMax + 1 then
							ligne(b, "Extra", "...", false)
							montres = montres + 1
						else
							if bit.band(drapeaux, ACHIEVEMENT_CRITERIA_PROGRESS_BAR) == ACHIEVEMENT_CRITERIA_PROGRESS_BAR then
								texte = quantite
							end
							ligne(b, j, texte, true)
							montres = montres + 1
							local chrono = WATCHFRAME_TIMEDCRITERIA[critere]
							if chrono and GetTime() - chrono.startTime < chrono.duration then
								minuteur(b, chrono.duration, chrono.startTime)
							end
						end
					end
				else
					ligne(b, 1, description, true)
					for _, chrono in pairs(WATCHFRAME_TIMEDCRITERIA) do
						if chrono.achievementID == id and GetTime() - chrono.startTime <= chrono.duration then
							minuteur(b, chrono.duration, chrono.startTime)
							break
						end
					end
				end
				if not placer(m, b) then
					break
				end
			end
		end
	end
	local hauteur = terminer(m, lineFrame, initialOffset)
	return hauteur, G.largeur, nb
end

local function gestionnaireHautsFaits(lineFrame, initialOffset, maxHeight, frameWidth)
	return afficherHautsFaits(lineFrame, initialOffset, maxHeight, frameWidth, GetTrackedAchievements())
end
T.gestionnaireHautsFaits = gestionnaireHautsFaits

-- --------------------------------------------------------- les clics
-- QuestObjectiveTrackerMixin:OnBlockHeaderClick
local function clicQuete(b, souris)
	if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
		local lien = GetQuestLink(b.index)
		if lien then ChatEdit_InsertLink(lien) end
		return
	end
	if souris ~= "RightButton" then
		CloseDropDownMenus()
		if IsModifiedClick("QUESTWATCHTOGGLE") then
			WatchFrame_StopTrackingQuest(nil, b.watch)
		else
			T.ouvrirPage(b.watch)
		end
		return
	end
	local w = b.watch
	local index = b.index
	local l = {
		{ text = b.titreQuete, isTitle = true },
		{ text = TEXTE.voirPage, func = function() T.ouvrirPage(w) end },
		{ text = TEXTE.voirCarte, func = function() WatchFrame_OpenMapToQuest(nil, w) end },
		{ text = TEXTE.nePlusSuivre, func = function() WatchFrame_StopTrackingQuest(nil, w) end },
	}
	if GetQuestLogPushable and (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 1) then
		local selection = GetQuestLogSelection()
		SelectQuestLogEntry(index)
		local partageable = GetQuestLogPushable()
		SelectQuestLogEntry(selection)
		if partageable then
			table.insert(l, { text = SHARE_QUEST, func = function() WatchFrame_ShareQuest(nil, w) end })
		end
	end
	table.insert(l, { text = TEXTE.partagerChat, func = function()
		local lien = GetQuestLink(index)
		if lien and not (ChatEdit_InsertLink and ChatEdit_InsertLink(lien)) then
			ChatFrame_OpenChat(lien)
		end
	end })
	table.insert(l, { text = TEXTE.abandonner, func = function() WatchFrame_AbandonQuest(nil, w) end })
	-- le deplacement manuel de WotLK (decision 2)
	local n = #VISIBLE_WATCHES
	local rang = WatchFrame_GetVisibleIndex(index)
	if n > 1 and rang then
		if rang > 1 then
			table.insert(l, { text = TRACKER_SORT_MANUAL_UP, func = function() WatchFrame_MoveQuest(nil, index, -1) end })
			table.insert(l, { text = TRACKER_SORT_MANUAL_TOP, func = function() WatchFrame_MoveQuest(nil, index, -100) end })
		end
		if rang < n then
			table.insert(l, { text = TRACKER_SORT_MANUAL_DOWN, func = function() WatchFrame_MoveQuest(nil, index, 1) end })
			table.insert(l, { text = TRACKER_SORT_MANUAL_BOTTOM, func = function() WatchFrame_MoveQuest(nil, index, 100) end })
		end
	end
	menu("cursor", l)
end

-- AchievementObjectiveTrackerMixin:OnBlockHeaderClick
local function clicHautFait(b, souris)
	local id = b.hautFait
	if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
		local lien = GetAchievementLink(id)
		if lien then ChatEdit_InsertLink(lien) end
		return
	end
	if souris ~= "RightButton" then
		CloseDropDownMenus()
		if IsModifiedClick("QUESTWATCHTOGGLE") then
			WatchFrame_StopTrackingAchievement(nil, id)
		else
			WatchFrame_OpenAchievementFrame(nil, id)
		end
		return
	end
	local _, nom = GetAchievementInfo(id)
	menu("cursor", {
		{ text = nom, isTitle = true },
		{ text = TEXTE.voirHautFait, func = function() WatchFrame_OpenAchievementFrame(nil, id) end },
		{ text = TEXTE.nePlusSuivre, func = function() WatchFrame_StopTrackingAchievement(nil, id) end },
	})
end

-- QuestMapFrame_OpenToQuestDetails : la carte, le volet, la page. WotLK
-- deplie d'abord l'en-tete de la quete (WatchFrameLinkButtonTemplate_OnLeftClick).
function T.ouvrirPage(watch)
	local index = GetQuestIndexForWatch(watch)
	if not index then return end
	ExpandQuestHeader(GetQuestSortIndex(index))
	index = GetQuestIndexForWatch(watch)
	if index and ForeverUI.QuestLog and ForeverUI.QuestLog.ouvrirPage then
		ForeverUI.QuestLog.ouvrirPage(index)
	end
end

-- --------------------------------------------------------- l'assemblage
local function etoufferEnteteWotLK()
	for _, f in ipairs({ WatchFrameHeader, WatchFrameCollapseExpandButton }) do
		if f then
			f:SetAlpha(0)
			f:EnableMouse(false)
			f:Hide()
		end
	end
end

-- apres chaque WatchFrame_Update : notre en-tete prend la place du sien.
-- WotLK decide de le montrer ou non dans WatchFrame_Update seulement : on
-- retient sa decision, car l'en-tete de WotLK est deja etouffe quand le
-- repli (WatchFrame_Collapse / _Expand) nous rappelle.
local function apresMiseAJour(depuisMaj)
	local h = T.entete
	if not h then return end
	if depuisMaj then
		T.enteteVoulu = WatchFrameHeader:IsShown() and true or false
	end
	local montrer = T.enteteVoulu
	etoufferEnteteWotLK()
	if montrer then
		h:Show()
		local actif = WatchFrameCollapseExpandButton:IsEnabled() == 1
		if actif then h.reduire:Enable() else h.reduire:Disable() end
	else
		h:Hide()
	end
	if WatchFrame.collapsed then
		etatsBouton(h.reduire, "ui-questtrackerbutton-expand-all", "ui-questtrackerbutton-expand-all-pressed")
	else
		etatsBouton(h.reduire, "ui-questtrackerbutton-collapse-all", "ui-questtrackerbutton-collapse-all-pressed")
	end
end
T.apresMiseAJour = apresMiseAJour

-- WatchFrame_SetWidth et WatchFrame_Collapse / _Expand : 260, replie ou non
local function largeur()
	WATCHFRAME_EXPANDEDWIDTH = G.largeur
	WATCHFRAME_MAXLINEWIDTH = G.largeur - G.blocX
	WatchFrame:SetWidth(G.largeur)
end

-- LA PLACE DU SUIVI (demande du 2026-09-25 : il passait derriere la
-- minimap, et doit se deplacer par /fui). UIParent_ManageFramePositions de
-- WotLK recolle WatchFrame sous MinimapCluster a chaque passage, et lui
-- ajoute un point BOTTOMRIGHT sur le bas de l'ecran. Le suivi suit donc un
-- PORTEUR, enregistre dans le mode edition comme tout le reste, et on le
-- repose apres chaque passage de WotLK. Sa hauteur va du porteur au bas que
-- WotLK lui donnait (CONTAINER_OFFSET_Y, au-dessus des barres d'action).
function T.placer()
	local porteur = T.porteur
	if not porteur then return end
	WatchFrame:ClearAllPoints()
	WatchFrame:SetPoint("TOPLEFT", porteur, "TOPLEFT", 0, 0)
	local haut = porteur:GetTop()
	if haut then
		WatchFrame:SetHeight(math.max(G.hauteurMin, haut - (CONTAINER_OFFSET_Y or 0)))
	end
end

local function construirePorteur()
	local porteur = CreateFrame("Frame", "ForeverUIObjectiveTrackerHolder", UIParent)
	porteur:SetWidth(G.largeur)
	porteur:SetHeight(G.enteteH)
	T.porteur = porteur
	local L = ForeverUI.Layout
	if L and L.Register then
		L.Register(porteur, "suivi", "Suivi de quetes", "TOPRIGHT", "TOPRIGHT", G.defautX, G.defautY)
		-- deplace, remis a zero ou repose a l'entree en jeu : le suivi suit
		local function apres(id)
			if id == "suivi" then T.placer() end
		end
		hooksecurefunc(L, "Save", apres)
		hooksecurefunc(L, "Apply", apres)
	end
	if UIParent_ManageFramePositions then
		hooksecurefunc("UIParent_ManageFramePositions", T.placer)
	end
	T.placer()
end

local function construire()
	if T.entete or not WatchFrame or not WatchFrameLines then
		return
	end
	construirePorteur()
	T.entete = creerEntete()
	T.quetes = creerModule("ForeverUIQuestObjectiveTracker", TEXTE.quetes, "quetes")
	T.quetes.clic = clicQuete
	T.hautsFaits = creerModule("ForeverUIAchievementObjectiveTracker", TEXTE.hautsFaits, "hautsFaits")
	T.hautsFaits.clic = clicHautFait

	WatchFrameLines:ClearAllPoints()
	WatchFrameLines:SetPoint("TOPLEFT", WatchFrame, "TOPLEFT", 0, -G.hautModules)
	WatchFrameLines:SetPoint("BOTTOMRIGHT", WatchFrame, "BOTTOMRIGHT", 0, G.basLignes)
	largeur()

	-- les deux modules de camelot, dans l'ordre de camelot, a la place des
	-- trois gestionnaires de WotLK ; ceux des addons restent apres eux
	WatchFrame_RemoveObjectiveHandler(WatchFrame_HandleDisplayQuestTimers)
	WatchFrame_RemoveObjectiveHandler(WatchFrame_HandleDisplayTrackedAchievements)
	WatchFrame_RemoveObjectiveHandler(WatchFrame_DisplayTrackedQuests)
	table.insert(WATCHFRAME_OBJECTIVEHANDLERS, 1, afficherQuetes)
	table.insert(WATCHFRAME_OBJECTIVEHANDLERS, 2, gestionnaireHautsFaits)

	hooksecurefunc("WatchFrame_Update", function() apresMiseAJour(true) end)
	hooksecurefunc("WatchFrame_SetWidth", function()
		if not WatchFrame.collapsed then largeur() end
		WATCHFRAME_EXPANDEDWIDTH = G.largeur
		WATCHFRAME_MAXLINEWIDTH = G.largeur - G.blocX
	end)
	hooksecurefunc("WatchFrame_Collapse", function(self)
		self:SetWidth(G.largeur)
		apresMiseAJour()
	end)
	hooksecurefunc("WatchFrame_Expand", function(self)
		self:SetWidth(G.largeur)
		apresMiseAJour()
	end)
	etoufferEnteteWotLK()
	-- WatchFrame_Update mesure le cadre : pas avant qu'il soit place (au
	-- chargement de l'addon, il ne l'est pas encore ; ses evenements
	-- d'entree en jeu le rafraichiront)
	if WatchFrame:GetTop() and WatchFrame:GetBottom() then
		WatchFrame_Update()
	end
end
T.construire = construire

construire()

ForeverUI.ObjectiveTrackerDebug = function()
	local prefixe = "|cff66ccffForeverUI|r "
	if not T.entete then
		DEFAULT_CHAT_FRAME:AddMessage(prefixe .. "suivi : pas construit.")
		return
	end
	local n = 0
	for _ in pairs(T.quetes.blocs) do n = n + 1 end
	local a = 0
	for _ in pairs(T.hautsFaits.blocs) do a = a + 1 end
	DEFAULT_CHAT_FRAME:AddMessage(prefixe .. string.format(
		"suivi : %.0f x %.0f, replie=%s | en-tete %s | quetes %d bloc(s) (%s) | hauts faits %d bloc(s) (%s) | gestionnaires %d | tri %s, filtre %s",
		WatchFrame:GetWidth(), WatchFrame:GetHeight(), tostring(WatchFrame.collapsed), tostring(T.entete:IsShown()),
		n, tostring(T.quetes:IsShown()), a, tostring(T.hautsFaits:IsShown()), #WATCHFRAME_OBJECTIVEHANDLERS,
		tostring(WATCHFRAME_SORT_TYPE), tostring(WATCHFRAME_FILTER_TYPE)))
end
