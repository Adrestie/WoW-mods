-- ForeverUI : l'onglet des statistiques (demande du 2026-09-29 : « il y a
-- une nouvelle interface sur WoW Camelot, l'onglet "Statistics" a ete
-- rempli [...] il faut reproduire l'interface dans notre onglet »).
--
-- RELEVE -- blizzard_statistics (camelot : StatisticsFrame.xml et
-- StatisticsFrame.lua, lus en entier ; identiques dans le client 70009) :
--
-- StatisticsFrame      setAllPoints sur CharacterFrame, onglet 6
--   ScrollBox          TOPLEFT sur CharacterFrameLeftPaneHost (10, -40),
--                      BOTTOMRIGHT sur le meme (-25, 15), les deux traits
--                      UI-Character-Info-ScrollLine-Long centres sur son TOP
--                      et son BOTTOM
--   ScrollBar          MinimalScrollBar, TOPLEFT sur le TOPRIGHT du
--                      ScrollBox (5, -2), BOTTOMLEFT sur son BOTTOMRIGHT (5, 4)
--   vue                CreateScrollBoxListTreeListView(20, 10, 10, 10, 10, 3) :
--                      retrait de 20 par niveau, marges de 10, ecart de 3
--   donnees            GetStatisticsCategoryList, dans l'ordre de ses cles ;
--                      les categories de parent -1 a la racine, chacune
--                      suivie de ses enfants ; sous chaque categorie ses
--                      statistiques (GetCategoryNumAchievements, puis
--                      GetStatistic) : celles marquees « skip » sont omises
--   valeur             tonumber(quantite) : un nombre positif s'ecrit, tout
--                      le reste s'ecrit « -- »
--   mise a jour        CRITERIA_UPDATE, ecoute tant que l'onglet est montre
--
-- StatisticsHeaderTemplate, hauteur 26 (categorie de premier niveau) :
--   fond        common-button-list-collapseExpand, etire sur la ligne ; le
--               meme en ADD a 0,3 au survol
--   StateIcon   common-button-list-plus ou -minus, RIGHT (-8, -1)
--   nom         GameFontNormalLeft, hauteur 15, LEFT x = 10 ; decale de
--               (1, -1) bouton enfonce
--
-- StatisticsSubHeaderTemplate, hauteur 22 (sous-categorie) :
--   bouton      20 x 20, LEFT x = 2 : campaign_headericon_closed / _open
--               (et _closedpressed / _openpressed enfonce), a la taille de
--               l'atlas ; survol Interface\Buttons\UI-PlusButton-Hilight
--               en ADD
--   nom         a +4 du bouton, jusqu'a 24 du bord droit ; pas de valeur
--
-- StatisticsEntryTemplate, hauteur 24 (une statistique) :
--   survol      charactercreate-customize-dropdown-linemouseover : cotes
--               de 6 (le droit retourne) et milieu, blancs, alpha 0,10
--               sous la souris, 0 sinon
--   valeur      GameFontHighlight, a droite, 50 x 15, RIGHT x = -12
--   nom         GameFontHighlight, a gauche, LEFT x = 2, jusqu'a 10 de la
--               valeur ; infobulle du nom quand il est coupe
--   contenu     decale de (1, -1) bouton enfonce
--
-- CE QUE 3.3.5 DONNE. Les memes fonctions, sauf GetStatistic : ici
-- GetStatistic(id), l'identifiant venant de GetAchievementInfo(categorie,
-- rang) -- l'ecran de 3.3.5 (AchievementFrameStats_Update) fait de meme.
-- Les categories du haut ont bien le parent -1.
--
-- CE QUI DIFFERE, ET POURQUOI :
--   * La liste est faite a la main : 3.3.5 n'a ni le ScrollBox ni son arbre.
--     Les lignes sont recyclees, la barre est celle de ScrollBar.lua, et
--     sans barre la liste prend sa place (regle du 28/09).
--   * L'ETAT REPLIE SURVIT AUX MISES A JOUR. camelot refait son arbre a
--     chaque CRITERIA_UPDATE, et tout ce qui etait replie se redeplie ; ici
--     l'etat est garde par categorie.
--   * « Tronque » se mesure sur un texte a part, jamais borne : 3.3.5 n'a
--     pas IsTruncated.
--   * LES VALEURS SONT CELLES DU CLIENT (choix de l'utilisateur du
--     2026-09-29 : « tout comme le client ») : le nom d'une statistique
--     « ... most » (la potion la plus bue...), un montant d'or avec ses
--     pieces ; « -- » quand le client ne rend rien, comme l'ecran de 3.3.5
--     (AchievementFrameStats_Update). camelot n'ecrit que les nombres
--     positifs. La colonne de la valeur, 50 chez camelot, s'elargit donc a
--     ce qu'elle porte, jusqu'a la moitie de la ligne.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local RACINE = -1                       -- ROOT_CATEGORY_ID

local LISTE_X, LISTE_Y = 10, -40
local LISTE_X2, LISTE_Y2 = -25, 15

local RETRAIT = 20                      -- CreateScrollBoxListTreeListView
local MARGE = 10
local ECART = 3

local ENTETE_H = 26                     -- StatisticsHeaderTemplate
local SOUS_ENTETE_H = 22                -- StatisticsSubHeaderTemplate
local ENTREE_H = 24                     -- StatisticsEntryTemplate

local ENTETE_NOM_X = 10
local FLECHE_X, FLECHE_Y = -8, -1
local FLECHE_PLACE = 16
local NOM_H = 15
local NOM_X = 2
local NOM_ECART = -10
local VALEUR_L, VALEUR_X = 50, -12
local BOUTON_L, BOUTON_X = 20, 2
local SOUS_NOM_ECART = 4
local SOUS_NOM_X2 = -24
local COTE = 6
local PLAQUE_COIN = 12                  -- celui des competences et de la reputation
local SURVOL_ALPHA = 0.10
local ENTETE_SURVOL_ALPHA = 0.3

local ATLAS_ENTETE = "common-button-list-collapseexpand"
local ATLAS_PLUS = "common-button-list-plus"
local ATLAS_MOINS = "common-button-list-minus"
local ATLAS_TRAIT = "ui-character-info-scrollline-long"
local ATLAS_SURVOL_COTE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_SURVOL_MILIEU = "charactercreate-customize-dropdown-linemouseover-middle"
local ATLAS_FERME = "campaign_headericon_closed"
local ATLAS_FERME_BAS = "campaign_headericon_closedpressed"
local ATLAS_OUVERT = "campaign_headericon_open"
local ATLAS_OUVERT_BAS = "campaign_headericon_openpressed"
local SURVOL_BOUTON = "Interface\\Buttons\\UI-PlusButton-Hilight"

-- La taille du volet, par construction (celle des competences).
local VOLET_L, VOLET_H = 398, 464

local S = {}
ForeverUI.StatisticsTab = S

local lignes = {}
local panneau, mesure, decalage = nil, nil, 0
local visibles = 0
local replies = {}                      -- [categorie] = true
local elements = {}                     -- la liste aplatie, telle que montree

-- --------------------------------------------------------------- les donnees

-- BuildOrderedCategoryIDs : les identifiants dans l'ordre de leurs cles
local function categoriesOrdonnees(source)
	local entrees = {}
	for cle, valeur in next, source or {} do
		if valeur and type(cle) == "number" then
			entrees[#entrees + 1] = { index = cle, id = valeur }
		end
	end
	table.sort(entrees, function(a, b) return a.index < b.index end)
	local ids = {}
	for _, e in ipairs(entrees) do
		ids[#ids + 1] = e.id
	end
	return ids
end

-- la valeur d'une statistique, telle que le client la rend ; « -- » sans
-- valeur (AchievementFrameStats_Update)
local function texteValeur(quantite)
	if quantite == nil or quantite == "" then
		return "--"
	end
	return tostring(quantite)
end

-- l'arbre : { id, nom, enfants = { categories }, stats = { { nom, valeur } } }
-- (BuildCategoryEntriesFromSource, AppendStatisticRows)
local function lireArbre()
	local ordre = categoriesOrdonnees(GetStatisticsCategoryList and GetStatisticsCategoryList())
	local racines, enfantsDe = {}, {}
	for _, id in ipairs(ordre) do
		local _, parent = GetCategoryInfo(id)
		if parent == RACINE then
			racines[#racines + 1] = id
		else
			enfantsDe[parent] = enfantsDe[parent] or {}
			table.insert(enfantsDe[parent], id)
		end
	end
	local vus = {}
	local function noeud(id)
		if vus[id] then
			return nil
		end
		vus[id] = true
		local n = { id = id, nom = GetCategoryInfo(id) or UNKNOWN, stats = {}, enfants = {} }
		for rang = 1, (GetCategoryNumAchievements(id)) or 0 do
			local statID = GetAchievementInfo(id, rang)
			if statID then
				local quantite, passer = GetStatistic(statID)
				if not passer then
					local _, nom = GetAchievementInfo(statID)
					n.stats[#n.stats + 1] = { nom = nom or UNKNOWN, valeur = texteValeur(quantite) }
				end
			end
		end
		for _, enfant in ipairs(enfantsDe[id] or {}) do
			local e = noeud(enfant)
			if e then
				n.enfants[#n.enfants + 1] = e
			end
		end
		return n
	end
	local arbre = {}
	for _, id in ipairs(racines) do
		local n = noeud(id)
		if n then
			arbre[#arbre + 1] = n
		end
	end
	return arbre
end

-- La liste aplatie, dans l'ordre du TreeDataProvider : une categorie, ses
-- statistiques, puis ses sous-categories ; rien sous une categorie repliee.
local function aplatir(arbre)
	local liste = {}
	local function descendre(n, profondeur)
		liste[#liste + 1] = { genre = (profondeur == 1) and "entete" or "sous", id = n.id,
			nom = n.nom, profondeur = profondeur }
		if replies[n.id] then
			return
		end
		for _, s in ipairs(n.stats) do
			liste[#liste + 1] = { genre = "stat", nom = s.nom, valeur = s.valeur, profondeur = profondeur + 1 }
		end
		for _, e in ipairs(n.enfants) do
			descendre(e, profondeur + 1)
		end
	end
	for _, n in ipairs(arbre) do
		descendre(n, 1)
	end
	return liste
end

-- --------------------------------------------------------------- une ligne

-- le nom est-il coupe ? (IsTruncated : sa largeur entiere depasse la boite)
local function coupe(texte, police)
	local t = texte:GetText()
	if not t or t == "" then
		return false
	end
	mesure:SetFontObject(police)
	mesure:SetText(t)
	return mesure:GetStringWidth() > (texte:GetWidth() or 0) + 0.5
end

local function infobulle(ligne)
	local nom = ligne.nom
	local police = (ligne.genre == "entete") and (GameFontNormalLeft or GameFontNormal) or (GameFontHighlight or GameFontNormal)
	if coupe(nom, police) then
		GameTooltip:SetOwner(ligne, "ANCHOR_RIGHT")
		GameTooltip:SetText(nom:GetText())
		GameTooltip:Show()
	end
end

local function cacherInfobulle(ligne)
	if GameTooltip:GetOwner() == ligne then
		GameTooltip:Hide()
	end
end

local function creerLigne(index)
	local ligne = CreateFrame("Button", "ForeverUIStatisticsRow" .. index, panneau)
	ligne:SetHeight(ENTREE_H)

	-- l'en-tete : la plaque, et la meme en ADD au survol
	ligne.plaque = ForeverUI.CreateNineSlice(ligne, ATLAS_ENTETE, PLAQUE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	ligne.lueur = ForeverUI.CreateNineSlice(ligne, ATLAS_ENTETE, PLAQUE_COIN,
		{ 0, 0, 0, 0 }, "HIGHLIGHT") or {}
	for _, t in ipairs(ligne.lueur) do
		t:SetBlendMode("ADD")
		t:SetAlpha(ENTETE_SURVOL_ALPHA)
	end

	-- le contenu d'une entree ou d'un sous-en-tete : il se decale enfonce
	local contenu = CreateFrame("Frame", nil, ligne)
	contenu:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, 0)
	contenu:SetPoint("BOTTOMRIGHT", ligne, "BOTTOMRIGHT", 0, 0)
	ligne.contenu = contenu

	local survol = CreateFrame("Frame", nil, contenu)
	survol:SetAllPoints(contenu)
	survol:SetAlpha(0)
	survol:SetFrameLevel(math.max(0, ligne:GetFrameLevel() - 1))
	ligne.survol = survol
	local gauche = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(gauche, ATLAS_SURVOL_COTE, true)
	gauche:SetWidth(COTE)
	gauche:SetPoint("TOPLEFT", survol, "TOPLEFT", 0, 0)
	gauche:SetPoint("BOTTOMLEFT", survol, "BOTTOMLEFT", 0, 0)
	local droite = survol:CreateTexture(nil, "BACKGROUND")
	if ForeverUI.SetAtlas(droite, ATLAS_SURVOL_COTE, true) then
		local e = ForeverUI.AtlasEntry(ATLAS_SURVOL_COTE)
		droite:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	droite:SetWidth(COTE)
	droite:SetPoint("TOPRIGHT", survol, "TOPRIGHT", 0, 0)
	droite:SetPoint("BOTTOMRIGHT", survol, "BOTTOMRIGHT", 0, 0)
	local milieu = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(milieu, ATLAS_SURVOL_MILIEU, true)
	milieu:SetPoint("TOPLEFT", gauche, "TOPRIGHT", 0, 0)
	milieu:SetPoint("BOTTOMRIGHT", droite, "BOTTOMLEFT", 0, 0)
	for _, t in ipairs({ gauche, droite, milieu }) do
		t:SetVertexColor(1, 1, 1)
	end

	local valeur = contenu:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	valeur:SetJustifyH("RIGHT")
	valeur:SetWidth(VALEUR_L)
	valeur:SetHeight(NOM_H)
	valeur:SetPoint("RIGHT", contenu, "RIGHT", VALEUR_X, 0)
	ligne.valeur = valeur

	local nom = contenu:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nom:SetHeight(NOM_H)
	nom:SetJustifyH("LEFT")
	ligne.nom = nom

	-- la fleche d'un en-tete, a droite
	local fleche = ligne:CreateTexture(nil, "BORDER")
	fleche:SetPoint("RIGHT", ligne, "RIGHT", FLECHE_X, FLECHE_Y)
	fleche:Hide()
	ligne.fleche = fleche

	-- le bouton d'un sous-en-tete, a gauche
	local bouton = CreateFrame("Button", nil, contenu)
	bouton:SetWidth(BOUTON_L)
	bouton:SetHeight(BOUTON_L)
	bouton:SetPoint("LEFT", contenu, "LEFT", BOUTON_X, 0)
	bouton:SetNormalTexture(ForeverUI.AtlasEntry(ATLAS_FERME)[1])
	bouton:SetPushedTexture(ForeverUI.AtlasEntry(ATLAS_FERME_BAS)[1])
	bouton:SetHighlightTexture(SURVOL_BOUTON, "ADD")
	bouton:Hide()
	ligne.bouton = bouton

	ligne:RegisterForClicks("LeftButtonUp")
	ligne:SetScript("OnMouseDown", function(self)
		self.bas = true
		S.PoserDecalage(self)
	end)
	ligne:SetScript("OnMouseUp", function(self)
		self.bas = nil
		S.PoserDecalage(self)
	end)
	ligne:SetScript("OnEnter", function(self)
		S.PoserSurvol(self)
		infobulle(self)
	end)
	ligne:SetScript("OnLeave", function(self)
		S.PoserSurvol(self)
		cacherInfobulle(self)
	end)
	ligne:SetScript("OnClick", function(self)
		if self.categorie then
			S.Basculer(self.categorie)
		end
	end)
	bouton:SetScript("OnClick", function()
		if ligne.categorie then
			S.Basculer(ligne.categorie)
		end
	end)
	return ligne
end

-- l'image d'un atlas a sa taille, dans une texture de bouton
local function poserImage(texture, atlas)
	if texture then
		ForeverUI.SetAtlas(texture, atlas)
		texture:ClearAllPoints()
		texture:SetPoint("CENTER", texture:GetParent(), "CENTER", 0, 0)
	end
end

-- RefreshBackgroundHighlightOpacity : 0,10 sous la souris ; jamais pour un
-- en-tete, qui a sa lueur
function S.PoserSurvol(ligne)
	if ligne.genre == "entete" then
		ligne.survol:SetAlpha(0)
		return
	end
	ligne.survol:SetAlpha(ligne:IsMouseOver() and SURVOL_ALPHA or 0)
end

-- enfonce : le nom d'un en-tete, le contenu d'une entree se decalent de (1, -1)
function S.PoserDecalage(ligne)
	local dx, dy = ligne.bas and 1 or 0, ligne.bas and -1 or 0
	if ligne.genre == "entete" then
		ligne.contenu:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, 0)
		ligne.contenu:SetPoint("BOTTOMRIGHT", ligne, "BOTTOMRIGHT", 0, 0)
		ligne.nom:SetPoint("LEFT", ligne, "LEFT", ENTETE_NOM_X + dx, dy)
		ligne.nom:SetPoint("RIGHT", ligne, "RIGHT", FLECHE_X - FLECHE_PLACE + dx, dy)
	else
		ligne.contenu:SetPoint("TOPLEFT", ligne, "TOPLEFT", dx, dy)
		ligne.contenu:SetPoint("BOTTOMRIGHT", ligne, "BOTTOMRIGHT", dx, dy)
	end
end

-- SetFontObject efface la justification : on la repose apres (voir
-- SkillsTab.lua).
local function remplirLigne(ligne, e)
	ligne.genre = e.genre
	ligne.categorie = (e.genre ~= "stat") and e.id or nil
	ligne.bas = nil
	ligne.nom:SetText(e.nom or "")
	ligne.nom:ClearAllPoints()
	local entete = e.genre == "entete"
	for _, t in ipairs(ligne.plaque) do
		if entete then t:Show() else t:Hide() end
	end
	for _, t in ipairs(ligne.lueur) do
		if entete then t:Show() else t:Hide() end
	end
	if entete then
		ligne:SetHeight(ENTETE_H)
		ligne.nom:SetFontObject(GameFontNormalLeft or GameFontNormal)
		ligne.nom:SetJustifyH("LEFT")
		ligne.valeur:SetText("")
		ligne.bouton:Hide()
		ForeverUI.SetAtlas(ligne.fleche, replies[e.id] and ATLAS_PLUS or ATLAS_MOINS)
		ligne.fleche:Show()
	elseif e.genre == "sous" then
		ligne:SetHeight(SOUS_ENTETE_H)
		ligne.nom:SetFontObject(GameFontHighlight or GameFontNormal)
		ligne.nom:SetJustifyH("LEFT")
		-- le nom s'ancre sur le contenu, a la place du bouton (voir
		-- ReputationTab.lua : ancre sur un voisin, il derivait)
		ligne.nom:SetPoint("LEFT", ligne.contenu, "LEFT", BOUTON_X + BOUTON_L + SOUS_NOM_ECART, 0)
		ligne.nom:SetPoint("RIGHT", ligne.contenu, "RIGHT", SOUS_NOM_X2, 0)
		ligne.valeur:SetText("")
		ligne.fleche:Hide()
		local ferme = replies[e.id]
		poserImage(ligne.bouton:GetNormalTexture(), ferme and ATLAS_FERME or ATLAS_OUVERT)
		poserImage(ligne.bouton:GetPushedTexture(), ferme and ATLAS_FERME_BAS or ATLAS_OUVERT_BAS)
		ligne.bouton:Show()
	else
		ligne:SetHeight(ENTREE_H)
		ligne.nom:SetFontObject(GameFontHighlight or GameFontNormal)
		ligne.nom:SetJustifyH("LEFT")
		ligne.nom:SetPoint("LEFT", ligne.contenu, "LEFT", NOM_X, 0)
		ligne.nom:SetPoint("RIGHT", ligne.valeur, "LEFT", NOM_ECART, 0)
		ligne.valeur:SetText(e.valeur or "--")
		-- la colonne de la valeur : 50, ou ce que porte la valeur, jusqu'a la
		-- moitie de la ligne
		mesure:SetFontObject(GameFontHighlight or GameFontNormal)
		mesure:SetText(e.valeur or "--")
		local plafond = math.floor((ligne:GetWidth() or 0) / 2)
		ligne.valeur:SetWidth(math.max(VALEUR_L, math.min(math.ceil(mesure:GetStringWidth()), plafond)))
		ligne.fleche:Hide()
		ligne.bouton:Hide()
	end
	S.PoserDecalage(ligne)
	S.PoserSurvol(ligne)
	ligne:Show()
end

-- ------------------------------------------------------------- la mise en place

local function hauteurDe(e)
	return (e.genre == "entete" and ENTETE_H) or (e.genre == "sous" and SOUS_ENTETE_H) or ENTREE_H
end

local function disposer()
	local hauteurUtile = panneau:GetHeight() or 0
	if hauteurUtile < 50 then
		hauteurUtile = VOLET_H + LISTE_Y - LISTE_Y2
	end
	local largeurUtile = panneau:GetWidth() or 0
	if largeurUtile < 50 then
		largeurUtile = VOLET_L + LISTE_X2 - LISTE_X
	end
	local y = MARGE
	local posees = 0
	for rang, ligne in ipairs(lignes) do
		local e = elements[decalage + rang]
		local hauteur = e and hauteurDe(e) or 0
		if e and y + hauteur <= hauteurUtile - MARGE then
			local retrait = (e.profondeur - 1) * RETRAIT
			ligne:SetWidth(largeurUtile - 2 * MARGE - retrait)
			remplirLigne(ligne, e)
			ligne:ClearAllPoints()
			ligne:SetPoint("TOPLEFT", panneau, "TOPLEFT", MARGE + retrait, -y)
			y = y + hauteur + ECART
			posees = posees + 1
		else
			ligne:Hide()
		end
	end
	return posees
end

local function poserListe()
	if not panneau then
		return
	end
	local total = #elements
	local posees = disposer()
	if decalage > 0 and decalage + posees > total then
		decalage = math.max(0, total - posees)
		posees = disposer()
	end
	visibles = posees
	if panneau.barre then
		panneau.barre:Regler(total, posees, decalage)
	end
end

-- Update : l'arbre relu, la liste reposee a la meme place
function S.Maj()
	if not panneau then
		return
	end
	elements = aplatir(lireArbre())
	poserListe()
end

-- ToggleCollapsed d'une categorie
function S.Basculer(categorie)
	replies[categorie] = not replies[categorie] or nil
	S.Maj()
end

-- --------------------------------------------------------- la construction

local function monter(hote)
	if panneau then
		return panneau:GetParent(), {}
	end
	local racine = CreateFrame("Frame", "ForeverUIStatisticsFrame", hote)
	racine:SetAllPoints(hote)

	local hauteur = hote:GetHeight() or 0
	if hauteur < 100 then
		hauteur = VOLET_H
	end
	local largeur = hote:GetWidth() or 0
	if largeur < 100 then
		largeur = VOLET_L
	end
	largeur = largeur + LISTE_X2 - LISTE_X

	panneau = CreateFrame("Frame", "ForeverUIStatisticsList", racine)
	panneau:SetPoint("TOPLEFT", hote, "TOPLEFT", LISTE_X, LISTE_Y)
	panneau:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", LISTE_X2, LISTE_Y2)
	panneau:SetWidth(largeur)

	mesure = panneau:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	mesure:SetAlpha(0)

	local place = math.floor((hauteur + LISTE_Y - LISTE_Y2) / (SOUS_ENTETE_H + ECART))
	if place < 1 then
		place = 1
	end
	for index = 1, place do
		lignes[index] = creerLigne(index)
	end

	-- les deux traits, centres sur le haut et le bas de la liste
	local haut = panneau:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(haut, ATLAS_TRAIT)
	haut:SetPoint("CENTER", panneau, "TOP", 0, 0)
	local bas = panneau:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(bas, ATLAS_TRAIT)
	bas:SetPoint("CENTER", panneau, "BOTTOM", 0, 0)

	-- la barre de camelot ; sans barre, la liste prend sa place
	panneau.barre = ForeverUI.CreateScrollBar("ForeverUIStatisticsScrollBar", racine, panneau)
	panneau.barre.surDefilement = function(nouveau)
		decalage = nouveau
		poserListe()
	end
	panneau.barre.surVisibilite = function(avec)
		local x2 = avec and LISTE_X2 or -LISTE_X
		panneau:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", x2, LISTE_Y2)
		panneau:SetWidth(largeur + x2 - LISTE_X2)
		disposer()
	end

	panneau:EnableMouseWheel(true)
	panneau:SetScript("OnMouseWheel", function(_, sens)
		decalage = math.max(0, math.min(decalage - sens, #elements - visibles))
		poserListe()
	end)

	-- OnShow / OnHide / OnEvent : CRITERIA_UPDATE, ecoute onglet montre
	racine:SetScript("OnShow", function(self)
		self:RegisterEvent("CRITERIA_UPDATE")
		S.Maj()
	end)
	racine:SetScript("OnHide", function(self)
		self:UnregisterEvent("CRITERIA_UPDATE")
	end)
	racine:SetScript("OnEvent", function(_, ev)
		if ev == "CRITERIA_UPDATE" then
			S.Maj()
		end
	end)
	racine:RegisterEvent("CRITERIA_UPDATE")

	S.Maj()
	return racine, {}
end

S.Build = monter
S.Rows = lignes
