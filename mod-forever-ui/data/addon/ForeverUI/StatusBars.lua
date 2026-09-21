-- ForeverUI : les deux barres d'etat du bas -- experience et reputation.
--
-- RELEVE DES SOURCES -- tout vient du code extrait de camelot.
--
-- mainline/StatusTrackingBar.xml, mainline/StatusTrackingBarTemplate.xml
--   Les deux barres sont le MEME objet, monte deux fois dans deux conteneurs :
--   fond UI-HUD-ExperienceBar-Background, remplissage
--   UI-HUD-ExperienceBar-Fill-<quoi>, encadrement UI-HUD-ExperienceBar-Frame
--   par-dessus, et un texte centre. C'est pourquoi ce fichier les construit
--   toutes les deux de la meme facon.
--
-- camelot/StatusTrackingBarConstants.lua
--   Les deux conteneurs sont distants de STATUS_BAR_2_ANCHOR_OFFSET_Y = 17,
--   soit exactement une hauteur de conteneur : les deux barres se touchent.
--   Ici l'image camelot fait 13 de haut, l'ecart est donc de 13.
--
--   ORDRE : OBSERVE EN JEU, et non deduit du code. Les priorites du fichier
--   (Experience 0, Reputation 2) triees par ordre decroissant mettraient la
--   reputation dans le conteneur du bas et l'experience au-dessus ; le jeu
--   montre l'inverse -- la reputation en haut, l'experience en dessous.
--   Comme pour la lueur de menace du cadre joueur, ce que le client affiche
--   prime sur la lecture de la fonction.
--
-- shared/ReputationBar.lua
--   le remplissage depend de l'attitude : rouge pour hai et hostile, orange
--   pour inamical, jaune pour neutre, vert a partir d'amical. Ce sont les
--   memes tranches que FACTION_BAR_COLORS de 3.3.5.
--
-- DONNEES 3.3.5
--   experience : UnitXP, UnitXPMax, GetXPExhaustion ; la barre disparait au
--                niveau maximum, comme celle du client.
--   reputation : GetWatchedFactionInfo() rend nom, attitude, min, max, valeur ;
--                la barre disparait quand aucune faction n'est suivie.
--
-- PLACEMENT. Les deux barres ont la longueur de la rangee du bas -- barre
-- d'action, micro-menu et sacs alignes -- et se posent sur son point le plus
-- haut, mesure par BottomBar (ForeverUI.BottomRow). Elles restent deplacables
-- separement, comme tout le reste.

local HAUTEUR = 13   -- hauteur de l'image camelot (1020 x 13)

local ATLAS_REPUTATION = {
	"ui-hud-experiencebar-fill-reputation-faction-red-camelot",     -- hai
	"ui-hud-experiencebar-fill-reputation-faction-red-camelot",     -- hostile
	"ui-hud-experiencebar-fill-reputation-faction-orange-camelot",  -- inamical
	"ui-hud-experiencebar-fill-reputation-faction-yellow-camelot",  -- neutre
	"ui-hud-experiencebar-fill-reputation-faction-green-camelot",   -- amical
	"ui-hud-experiencebar-fill-reputation-faction-green-camelot",   -- honore
	"ui-hud-experiencebar-fill-reputation-faction-green-camelot",   -- revere
	"ui-hud-experiencebar-fill-reputation-faction-green-camelot",   -- exalte
}

-- Rogner un remplissage a la fraction voulue. L'image a des bouts arrondis :
-- on la coupe a droite, ce qui donne le bord franc d'un remplissage partiel.
local function remplir(texture, atlas, fraction, largeur)
	local e = atlas and ForeverUI.AtlasEntry(atlas)
	if not e or not fraction or fraction ~= fraction or fraction <= 0 then
		texture:Hide()
		return
	end

	if fraction > 1 then
		fraction = 1
	end

	local w = largeur * fraction
	if w < 1 then
		texture:Hide()
		return
	end

	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[2] + (e[3] - e[2]) * fraction, e[4], e[5])
	texture:SetWidth(w)
	texture:Show()
end

local function creerBarre(nom)
	local barre = CreateFrame("Frame", nom, UIParent)
	barre:SetHeight(HAUTEUR)
	barre:EnableMouse(true)

	local fond = barre:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "ui-hud-experiencebar-background-camelot", true)
	fond:SetAllPoints(barre)

	-- La part reposee se voit DERRIERE l'acquis : elle est dans une couche
	-- inferieure et part du meme bord.
	local repos = barre:CreateTexture(nil, "BORDER")
	repos:SetPoint("LEFT", barre, "LEFT", 0, 0)
	repos:SetHeight(HAUTEUR)
	repos:Hide()

	local remplissage = barre:CreateTexture(nil, "ARTWORK")
	remplissage:SetPoint("LEFT", barre, "LEFT", 0, 0)
	remplissage:SetHeight(HAUTEUR)
	remplissage:Hide()

	local cadre = barre:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(cadre, "ui-hud-experiencebar-frame-camelot", true)
	cadre:SetAllPoints(barre)

	local texte = barre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	texte:SetPoint("CENTER")
	texte:Hide()

	barre.fond, barre.repos, barre.remplissage, barre.cadre, barre.texte =
		fond, repos, remplissage, cadre, texte

	barre:SetScript("OnEnter", function(self)
		self.texte:Show()
	end)
	barre:SetScript("OnLeave", function(self)
		self.texte:Hide()
	end)

	return barre
end

local experience = creerBarre("ForeverUIExperienceBar")
local reputation = creerBarre("ForeverUIReputationBar")

-- ------------------------------------------------------------ experience
local function majExperience()
	local maximum = UnitXPMax("player")
	local niveau = UnitLevel("player")
	local maxNiveau = MAX_PLAYER_LEVEL or 80

	if not maximum or maximum <= 0 or (niveau and niveau >= maxNiveau) then
		experience:Hide()
		return
	end

	experience:Show()

	local largeur = experience:GetWidth()
	local acquis = UnitXP("player")
	local repose = (GetXPExhaustion and GetXPExhaustion()) or 0
	local fraction = acquis / maximum

	remplir(experience.repos, "ui-hud-experiencebar-fill-rested-camelot",
		(acquis + repose) / maximum, largeur)
	remplir(experience.remplissage, "ui-hud-experiencebar-fill-experience-camelot",
		fraction, largeur)

	experience.texte:SetText(string.format("%d / %d  (%d%%)", acquis, maximum,
		math.floor(fraction * 100)))
end

-- ------------------------------------------------------------ reputation
local function majReputation()
	local nom, attitude, minimum, maximum, valeur = GetWatchedFactionInfo()
	if not nom or not maximum or maximum <= minimum then
		reputation:Hide()
		return
	end

	reputation:Show()

	local etendue = maximum - minimum
	local acquis = valeur - minimum
	local fraction = acquis / etendue

	remplir(reputation.remplissage, ATLAS_REPUTATION[attitude] or ATLAS_REPUTATION[4],
		fraction, reputation:GetWidth())

	reputation.texte:SetText(string.format("%s  %d / %d", nom, acquis, etendue))
end

-- ------------------------------------------------------------- placement
-- Les deux barres font la longueur de la rangee -- barre d'action, micro-menu
-- et sacs alignes -- et se touchent : l'experience pose sur la rangee, la
-- reputation juste au-dessus.
local function poser()
	local rangee = ForeverUI.BottomRow
	if not rangee then
		return
	end

	local largeur = rangee.droite - rangee.gauche
	local centre = (rangee.gauche + rangee.droite) / 2

	experience:SetWidth(largeur)
	reputation:SetWidth(largeur)

	ForeverUI.Layout.SetDefaults("experiencebar", "BOTTOM", "BOTTOM", centre, rangee.haut)
	ForeverUI.Layout.SetDefaults("reputationbar", "BOTTOM", "BOTTOM", centre, rangee.haut + HAUTEUR)
end

local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:RegisterEvent("PLAYER_XP_UPDATE")
veilleur:RegisterEvent("PLAYER_LEVEL_UP")
veilleur:RegisterEvent("UPDATE_EXHAUSTION")
veilleur:RegisterEvent("UPDATE_FACTION")
veilleur:SetScript("OnEvent", function(_self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		-- Les barres d'origine : celle d'experience, la marque de repos, et
		-- celle de reputation, qui se replace toute seule a chaque mise a jour.
		ForeverUI.Suppress(MainMenuExpBar)
		ForeverUI.Suppress(ExhaustionTick)
		ForeverUI.Suppress(ReputationWatchBar)
		poser()
	end
	majExperience()
	majReputation()
end)

ForeverUI.Layout.Register(experience, "experiencebar", "Barre d'experience", "BOTTOM", "BOTTOM", 0, 54)
ForeverUI.Layout.Register(reputation, "reputationbar", "Barre de reputation", "BOTTOM", "BOTTOM", 0, 67)
poser()
majExperience()
majReputation()

ForeverUI.ExperienceBar = experience
ForeverUI.ReputationBar = reputation
ForeverUI.StatusBarsUpdate = function()
	majExperience()
	majReputation()
end

ForeverUI.StatusBarsDebug = function()
	local rangee = ForeverUI.BottomRow or {}
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r barres d'etat : rangee %.1f -> %.1f, haut %s | largeur %.0f | xp visible=%s a y=%s | reputation visible=%s a y=%s",
		rangee.gauche or 0, rangee.droite or 0, tostring(rangee.haut),
		experience:GetWidth(),
		tostring(experience:IsShown()), tostring(select(5, experience:GetPoint(1))),
		tostring(reputation:IsShown()), tostring(select(5, reputation:GetPoint(1)))))
end
