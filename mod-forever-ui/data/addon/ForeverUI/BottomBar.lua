-- ForeverUI : le bas de l'ecran -- micro-menu et barre des sacs.
--
-- RELEVE DES SOURCES -- tout vient du code extrait de camelot.
--
-- mainline/MainMenuBarMicroMenuTemplate.xml + camelot/MainMenuBarMicroMenu.xml
--   bouton        32 x 40
--   ecart         childXPadding = -5 : un pas de 27, les boutons se
--                 chevauchent de 5 px
--   fond          UI-HUD-MicroMenu-ButtonBG-Up a sa taille d'atlas, centre ;
--                 UI-HUD-MicroMenu-ButtonBG-Down prend sa place quand le
--                 bouton est enfonce (MainMenuBarMicroButtonMixin:SetPushed)
--   icones        UI-HUD-MicroMenu-<jeu>-Up / -Down / -Disabled / -Mouseover
--                 (LoadMicroButtonTextures)
--   survol        -Mouseover en BLEND quand le bouton est normal,
--                 -Down en ADD a 50 % quand il est enfonce
--   encadrement   UI-HUD-ActionBar-Frame, TOPLEFT (-8, 8), BOTTOMRIGHT (8, -8)
--   fond du bloc  UI-HUD-ActionBar-IconFrame-Background, pose sur
--                 l'encadrement : TOPLEFT (-13, 0), BOTTOMRIGHT (14, 4)
--   portrait      CharacterMicroButton n'a pas d'icone : une ombre
--                 (Portrait-Shadow), le portrait du joueur rogne a
--                 (0.2, 0.8, 0.0666, 0.9) et rentre de 7 px, et une seconde
--                 ombre (Portrait-Down) quand le bouton est enfonce
--   latence       MainMenuBarPerformanceBar, 19 x 39, BOTTOM (0, -2) -- (0, 0) ici, voir
--                 plus bas --, sur l'image
--                 de camelot (UI-MainMenuBar-PerformanceBar, 32 x 64)
--
-- camelot/MicroMenuContainerOverrides.lua donne l'ordre. Trois des dix boutons
-- de 3.3.5 n'existent plus chez camelot, et l'atlas ne leur offre pas de jeu
-- d'images c60 :
--   Succes -> jeu "Achievements", present dans l'atlas mais sans variante c60
--             (camelot a retire ce bouton) : on prend la variante de base.
--   JcJ    -> RETIRE le 2026-09-26, a la demande : le PvP s'ouvre par
--             l'onglet de la feuille de personnage. Le bouton du client est
--             neutralise (ForeverUI.Suppress).
--   Aide   -> RETIRE le 2026-09-26, a la demande -- camelot cache ce bouton
--             lui aussi. La demande d'aide passe au menu Echap, la ou camelot
--             met GAMEMENU_SUPPORT (voir plus bas) ; le bouton du client est
--             neutralise, comme celui du JcJ.
-- LE BANDEAU A LA LARGEUR DE SES BOUTONS (demande du 2026-09-26) : plus de
-- rallonge -- ni la place des boutons retires, ni celle du sac a composants --
-- et la barre d'action et les sacs, poses de part et d'autre, s'en
-- rapprochent.
--
-- camelot/MainMenuBarBagButtons.xml + shared/BagsBar.lua
--   sac              45 x 45, bagPadding = 2, ranges vers la GAUCHE depuis le
--                    sac a dos
--   ordre            sac a dos, sacs 1 a 4, trousseau (le sac a composants
--                    de camelot n'existe pas sur 3.3.5 et sa place n'est plus
--                    tenue)
--   trousseau        33 x 45
--   cadre d'un sac   ui-hud-actionbar-iconframe-bags, 46 x 46, ancre TOPLEFT
--                    (BaseBagSlotButtonMixin:UpdateTextures)
--   survol           le meme dessin, en ADD a 40 %, sur tout le bouton
--   cadre trousseau  ui-hud-actionbar-iconframe-small, 33 x 46 ; son image est
--                    UI-HUD-ActionBar-Keyring-Small quand showKeyring est
--                    actif, UI-HUD-ActionBar-IconFrame-Slot-Small sinon
--   encadrement      UI-HUD-ActionBar-Frame, TOPLEFT (-6, 6), BOTTOMRIGHT (5, -5)
--   separateurs      useDividers : LEFT sur le RIGHT du sac decale de -5,
--                    sur toute sa hauteur
--
-- camelot/EditModePresetLayoutConstants.lua, mainline/EditModePresetLayouts.lua
--   micro-menu       BOTTOM de l'ecran, (116.5, 6)
--   barre d'action   BOTTOMRIGHT sur le BOTTOMLEFT du micro-menu, (-4.5, -4)
--   sacs             BOTTOMLEFT sur le BOTTOMRIGHT du micro-menu, (7, -4)
--   embout gauche    bord gauche de la barre d'action, rentre de 30
--   embout droit     bord droit de la barre des sacs, rentre de 30
--                    (cales par le BAS : voir ActionBar.lua)

local MICRO_W, MICRO_H = 32, 40
local MICRO_PADDING = -5
local MICRO_PITCH = MICRO_W + MICRO_PADDING

-- Hauteur affichee d'un bouton. Le bandeau fait 40, son encadrement deborde de
-- 8 de chaque cote (56 au total) et le liseré de bronze prend 5 px : il reste
-- 46 d'ouverture. Les images de camelot font 41 et laissaient donc du vide en
-- haut et en bas ; on les etire a la hauteur de l'ouverture.
local MICRO_ART_H = 46

local BAG_SIZE = 45
local BAG_PADDING = 2
local BAG_FRAME_W, BAG_FRAME_H = 46, 46
local KEYRING_W = 33


local MICRO_X, MICRO_Y = 116.5, 6
local BAR_OFFSET_X, BAR_OFFSET_Y = -4.5, -4
local BAGS_OFFSET_X, BAGS_OFFSET_Y = 7, -4

-- Lua 5.1 lit les antislashs d'une chaine comme des echappements : on pose le
-- separateur de chemin en clair plutot que de le doubler.
local SEP = string.char(92)
local ICONE_SAC = "Interface" .. SEP .. "ForeverUI" .. SEP .. "icons" .. SEP .. "ui-hud-actionbar-bag"
local PERFORMANCE_IMAGE = "Interface" .. SEP .. "ForeverUI" .. SEP .. "mainmenubar" .. SEP .. "ui-mainmenubar-performancebar"
local L = ForeverUI.L

-- L'ordre de camelot, reduit aux boutons que ce client possede.
--
-- LE BOUTON DES METIERS (demande du 2026-09-28) : ProfessionMicroButton de
-- camelot, juste apres la feuille de personnage. 3.3.5 n'en a pas : le
-- bouton est cree ici (creer), a l'image de ceux du client ; il ouvre le
-- livre des metiers (ProfessionsBook.lua).
local MICRO = {
	{ nom = "CharacterMicroButton", portrait = true },
	{ nom = "ForeverUIProfessionMicroButton", jeu = "professions", creer = true },
	{ nom = "SpellbookMicroButton", jeu = "spellbookabilities" },
	{ nom = "TalentMicroButton", jeu = "spectalents" },
	{ nom = "AchievementMicroButton", jeu = "achievements" },
	{ nom = "QuestLogMicroButton", jeu = "questlog" },
	{ nom = "SocialsMicroButton", jeu = "guildcommunities" },
	{ nom = "LFDMicroButton", jeu = "groupfinder" },
	{ nom = "MainMenuMicroButton", jeu = "gamemenu" },
}

local ETATS_MICRO = {
	up = "GetNormalTexture",
	down = "GetPushedTexture",
	disabled = "GetDisabledTexture",
	mouseover = "GetHighlightTexture",
}

-- camelot affiche le jeu c60. La table d'atlas donne ces images sous leur nom
-- complet ; le nom logique, lui, tombe sur la variante de base, la feuille c60
-- etant versee apres dans l'ordre alphabetique. On demande donc la c60 par son
-- nom, et on se rabat sur la base quand elle n'existe pas.
-- L'etat desactive s'ecrit "-disable" sur la feuille c60 et "-disabled" sur la
-- feuille de base : les deux sont essayes.
local function microAtlas(jeu, etat)
	local candidats = {
		"ui-hud-micromenu-" .. jeu .. "-" .. etat .. "-c60-2x",
		"ui-hud-micromenu-" .. jeu .. "-" .. etat .. "-2x",
	}
	if etat == "disabled" then
		table.insert(candidats, 1, "ui-hud-micromenu-" .. jeu .. "-disable-c60-2x")
	end
	for _, nom in ipairs(candidats) do
		if ForeverUI.AtlasEntry(nom) then
			return nom
		end
	end
	return nil
end

-- --------------------------------------------------------- le micro-menu
local micro = CreateFrame("Frame", "ForeverUIMicroMenu", UIParent)
micro:SetHeight(MICRO_H)

local fondBloc = micro:CreateTexture(nil, "BACKGROUND")
ForeverUI.SetAtlas(fondBloc, "ui-hud-actionbar-iconframe-background", true)

local cadreBloc = CreateFrame("Frame", nil, micro)
cadreBloc:SetPoint("TOPLEFT", -8, 8)
cadreBloc:SetPoint("BOTTOMRIGHT", 8, -8)
cadreBloc:SetFrameLevel(micro:GetFrameLevel())
ForeverUI.SetBarFrameArt(cadreBloc, "BORDER")

-- Le fond deborde de l'encadrement. La source le declare apres lui, mais dans
-- un sous-niveau inferieur : a l'ecran il passe DESSOUS, et 3.3.5 n'ayant pas
-- de sous-niveaux, on le range dans une couche plus basse.
fondBloc:SetPoint("TOPLEFT", cadreBloc, "TOPLEFT", -13, 0)
fondBloc:SetPoint("BOTTOMRIGHT", cadreBloc, "BOTTOMRIGHT", 14, 4)

local boutonsMicro = {}

local function etatMicro(entree)
	local bouton = entree.bouton
	local enfonce = bouton:GetButtonState() == "PUSHED"

	if enfonce then
		entree.fond:Hide()
		entree.fondEnfonce:Show()
	else
		entree.fond:Show()
		entree.fondEnfonce:Hide()
	end

	if entree.ombreEnfoncee then
		if enfonce then
			entree.ombreEnfoncee:Show()
		else
			entree.ombreEnfoncee:Hide()
		end
	end


	-- l'embleme du tabard : CENTER (0, 2), enfonce (1, 1)
	if entree.embleme then
		for _, t in ipairs({ entree.embleme, entree.emblemeSurvol }) do
			t:ClearAllPoints()
			t:SetPoint("CENTER", bouton, "CENTER", enfonce and 1 or 0, enfonce and 1 or 2)
		end
	end

	-- CharacterMicroButton_SetPushed change le rognage du portrait ; camelot
	-- garde le meme dans les deux etats.
	if entree.portrait and MicroButtonPortrait then
		MicroButtonPortrait:SetTexCoord(0.2, 0.8, 0.0666, 0.9)
	end

	local surbrillance = bouton:GetHighlightTexture()
	if surbrillance and entree.jeu then
		if enfonce then
			if ForeverUI.SetAtlas(surbrillance, microAtlas(entree.jeu, "down"), true) then
				surbrillance:SetBlendMode("ADD")
				surbrillance:SetAlpha(0.5)
			end
		else
			if ForeverUI.SetAtlas(surbrillance, microAtlas(entree.jeu, "mouseover"), true) then
				surbrillance:SetBlendMode("BLEND")
				surbrillance:SetAlpha(1)
			end
		end
	end
end

-- la barre de latence du bouton du menu : camelot l'ancre a (0, -2) ; son
-- trait (le bas de l'image) deborde alors d'un pixel sous le bouton, ou il
-- n'y a rien. Ici le bord interieur de l'encadrement du bandeau tombe au bas
-- du bouton et le couvrait : ancre a (0, 0), le trait passe juste au-dessus.
--
-- LE TRAIT A 3 PIXELS (demande du 2026-09-28 : « pas assez epais, vise les
-- 3 pixels »). Sur l'image (32 x 64), le trait tient sur les lignes 58 et
-- 59 -- la 57 est son liseré sombre. A 39 de haut, une ligne de l'image
-- faisait moins d'un pixel d'ecran, et le trait, un seul. L'image prend
-- donc la hauteur qui donne 1,5 pixel par ligne : ses deux lignes colorees
-- font 3 pixels. La largeur reste celle de camelot (19). Le pixel se
-- compte sur la hauteur de l'ecran (gxResolution) et l'echelle du bouton.
local LATENCE = { lignes = 64, pixelsParLigne = 1.5, largeur = 19 }
local function pixelsParUnite(cadre)
	local h = tonumber(string.match(GetCVar("gxResolution") or "", "%d+x(%d+)")) or 768
	return h / 768 * cadre:GetEffectiveScale()
end
ForeverUI.PixelsParUnite = pixelsParUnite

local function poserLatence(bouton)
	MainMenuBarPerformanceBar:SetWidth(LATENCE.largeur)
	MainMenuBarPerformanceBar:SetHeight(LATENCE.lignes * LATENCE.pixelsParLigne / pixelsParUnite(bouton))
	MainMenuBarPerformanceBar:ClearAllPoints()
	MainMenuBarPerformanceBar:SetPoint("BOTTOM", bouton, "BOTTOM", 0, 0)
end

-- ProfessionMicroButtonMixin (mainline/mainmenubarmicrobuttons.lua) :
-- LoadMicroButtonTextures(self, "Professions") ; infobulle
-- MicroButtonTooltipText(PROFESSIONS_BUTTON, "TOGGLEPROFESSIONBOOK") --
-- PROFESSIONS_BUTTON est TRADE_SKILLS dans 3.3.5, qui n'a pas ce raccourci ;
-- le clic ouvre ou ferme les metiers (ToggleProfessionsBook). L'infobulle
-- et les images sont posees comme celles des boutons du client (OnEnter de
-- MainMenuBarMicroButton, GameTooltip_AddNewbieTip) ; habillerMicro les
-- reprend ensuite.
local function creerMicro(definition)
	local parent = (CharacterMicroButton and CharacterMicroButton:GetParent()) or micro
	local bouton = CreateFrame("Button", definition.nom, parent)
	for etat, methode in pairs(ETATS_MICRO) do
		local e = ForeverUI.AtlasEntry(microAtlas(definition.jeu, etat))
		if e then
			bouton[string.gsub(methode, "^Get", "Set")](bouton, e[1])
		end
	end
	bouton:RegisterForClicks("AnyUp")
	bouton.tooltipText = MicroButtonTooltipText(TRADE_SKILLS, "TOGGLEPROFESSIONBOOK")
	bouton:SetScript("OnEnter", function(self)
		GameTooltip_AddNewbieTip(self, self.tooltipText, 1.0, 1.0, 1.0, self.newbieText)
	end)
	bouton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	bouton:SetScript("OnClick", function()
		if ForeverUI.LivreMetiers then
			ForeverUI.LivreMetiers.Basculer()
		end
	end)
	return bouton
end

local function habillerMicro(definition, index)
	if definition.creer and not _G[definition.nom] then
		creerMicro(definition)
	end
	local bouton = _G[definition.nom]
	if not bouton then
		return nil
	end

	bouton:SetWidth(MICRO_W)
	bouton:SetHeight(MICRO_ART_H)
	-- 3.3.5 rend les 18 px du haut insensibles a la souris : c'etait la partie
	-- decorative de l'ancien bouton, qui n'existe plus.
	bouton:SetHitRectInsets(0, 0, 0, 0)
	-- Les boutons se chevauchent de 5 px : celui de droite passe devant.
	if MainMenuBarArtFrame then
		bouton:SetFrameLevel(MainMenuBarArtFrame:GetFrameLevel() + index)
	end

	local entree = { bouton = bouton, jeu = definition.jeu, portrait = definition.portrait, cree = definition.creer }

	entree.fond = bouton:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(entree.fond, "ui-hud-micromenu-buttonbg-up-c60-2x", true)
	entree.fond:SetAllPoints(bouton)

	entree.fondEnfonce = bouton:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(entree.fondEnfonce, "ui-hud-micromenu-buttonbg-down-c60-2x", true)
	entree.fondEnfonce:SetAllPoints(bouton)
	entree.fondEnfonce:Hide()

	if definition.jeu then
		for etat, methode in pairs(ETATS_MICRO) do
			local texture = bouton[methode] and bouton[methode](bouton)
			if texture then
				ForeverUI.SetAtlas(texture, microAtlas(definition.jeu, etat), true)
				texture:ClearAllPoints()
				texture:SetAllPoints(bouton)
			end
		end
	else
		-- Portrait et JcJ n'ont pas de jeu d'icones : on efface celui du client
		-- et le fond de camelot fait tout le dessin.
		for _, methode in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
			local texture = bouton[methode] and bouton[methode](bouton)
			if texture then
				texture:SetAlpha(0)
			end
		end
		local surbrillance = bouton:GetHighlightTexture()
		if surbrillance then
			ForeverUI.SetAtlas(surbrillance, "ui-hud-micromenu-buttonbg-down-c60-2x", true)
			surbrillance:ClearAllPoints()
			surbrillance:SetAllPoints(bouton)
			surbrillance:SetBlendMode("ADD")
			surbrillance:SetAlpha(0.4)
		end
	end

	if definition.portrait then
		local ombre = bouton:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(ombre, "ui-hud-micromenu-portrait-shadow-2x", true)
		ombre:SetAllPoints(bouton)
		entree.ombre = ombre

		if MicroButtonPortrait then
			-- La source rentre le portrait de 7 px sur un bouton de 32 x 40,
			-- soit 18 x 26. On garde cette taille : suivre la hauteur du
			-- bouton etirerait le visage.
			MicroButtonPortrait:SetDrawLayer("ARTWORK")
			MicroButtonPortrait:ClearAllPoints()
			MicroButtonPortrait:SetWidth(MICRO_W - 14)
			MicroButtonPortrait:SetHeight(MICRO_H - 14)
			MicroButtonPortrait:SetPoint("CENTER", bouton, "CENTER", 0, 0)
			MicroButtonPortrait:SetTexCoord(0.2, 0.8, 0.0666, 0.9)
		end

		local ombreEnfoncee = bouton:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(ombreEnfoncee, "ui-hud-micromenu-portrait-down-2x", true)
		ombreEnfoncee:SetWidth(MICRO_W)
		ombreEnfoncee:SetHeight(MICRO_ART_H)
		ombreEnfoncee:SetPoint("CENTER", bouton, "CENTER", 1, -4)
		ombreEnfoncee:Hide()
		entree.ombreEnfoncee = ombreEnfoncee
	end

	if definition.nom == "MainMenuMicroButton" and MainMenuBarPerformanceBar then
		-- l'image de camelot (32 x 64, un trait en bas) : celle de 3.3.5 est
		-- un pave de 16 x 8, qui s'etirait en gros carre vert
		MainMenuBarPerformanceBar:SetTexture(PERFORMANCE_IMAGE)
		poserLatence(bouton)
		-- l'ecran ou l'echelle changent : le pixel aussi
		local veilleLatence = CreateFrame("Frame")
		veilleLatence:RegisterEvent("DISPLAY_SIZE_CHANGED")
		veilleLatence:RegisterEvent("UI_SCALE_CHANGED")
		veilleLatence:RegisterEvent("PLAYER_ENTERING_WORLD")
		veilleLatence:SetScript("OnEvent", function() poserLatence(bouton) end)
		-- 3.3.5 REANCRE la barre a chaque appui et a chaque relachement
		-- (MainMenuMicroButton_SetPushed / _SetNormal : SetPoint TOPLEFT
		-- (9, -36) / (10, -34), sans ClearAllPoints). Cette ancre s'ajoutait a
		-- la notre : l'image, tiree entre les deux, tombait a 12 x 12 et son
		-- trait disparaissait (AMELIORATIONS, 2026-09-28). On repose la notre
		-- derriere elles ; camelot ne deplace pas la barre quand le bouton
		-- s'enfonce.
		for _, nom in ipairs({ "MainMenuMicroButton_SetPushed", "MainMenuMicroButton_SetNormal" }) do
			if _G[nom] then
				hooksecurefunc(nom, function() poserLatence(bouton) end)
			end
		end
	end

	bouton:ClearAllPoints()
	bouton:SetPoint("LEFT", micro, "LEFT", (index - 1) * MICRO_PITCH, 0)

	return entree
end

local nombreMicro = 0
for index, definition in ipairs(MICRO) do
	local entree = habillerMicro(definition, index)
	if entree then
		table.insert(boutonsMicro, entree)
		nombreMicro = index
	end
end
local LARGEUR_BOUTONS = nombreMicro * MICRO_W + (nombreMicro - 1) * MICRO_PADDING

-- LE TABARD DE GUILDE SUR LE BOUTON SOCIAL (2026-09-26, demande de
-- l'utilisateur ; camelot : GuildMicroButtonMixin:UpdateTabard). Avec une
-- guilde qui a un tabard, le bouton prend le jeu GuildCommunities-GuildColor
-- teint de la couleur de fond du tabard (LoadMicroButtonTextures : les quatre
-- etats), et son embleme de 12 x 14 au centre (0, 2), (1, 1) enfonce -- en
-- OVERLAY, et en HIGHLIGHT pour le survol --, pris sur la planche
-- GuildEmblems_01 (SetSmallGuildTabardTextures : cases de 18/256, 14 par
-- ligne, rentrees de 1/256) et teint de la couleur de l'embleme. Sans tabard :
-- le jeu GuildCommunities, sans embleme.
-- 3.3.5 n'a pas C_GuildInfo.GetGuildTabardInfo : GetGuildTabardFileNames ne
-- rend que les noms des textures (Background_<fond>_TU_U,
-- Emblem_<motif>_<couleur>_TU_U). Le motif est le numero de case de la
-- planche (verifie sur les motifs 0 a 150) ; les couleurs, lues dans ces
-- textures, sont dans TabardColors.lua (tools/couleurs_tabard.py).
local PLANCHE_EMBLEMES = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildframe" .. SEP .. "guildemblems_01"
local CASE_EMBLEME, COLONNES_EMBLEMES, BORD_EMBLEME = 18 / 256, 14, 1 / 256

local function tabardDeGuilde()
	if not (GetGuildTabardFileNames and IsInGuild and IsInGuild()) then return nil end
	local fond, _, embleme = GetGuildTabardFileNames()
	if not fond or not embleme then return nil end
	local f = tonumber(string.match(string.lower(fond), "background_(%d+)"))
	local motif, couleur = string.match(string.lower(embleme), "emblem_(%d+)_(%d+)")
	local couleurs = ForeverUI.TabardCouleurs
	if not (f and motif and couleurs) then return nil end
	local cf, ce = couleurs.fond[f], couleurs.embleme[tonumber(couleur)]
	if not (cf and ce) then return nil end
	return cf, tonumber(motif), ce
end

local social
for _, entree in ipairs(boutonsMicro) do
	if entree.bouton:GetName() == "SocialsMicroButton" then social = entree end
end

if social then
	social.jeuBase = social.jeu
	social.embleme = social.bouton:CreateTexture(nil, "OVERLAY")
	social.emblemeSurvol = social.bouton:CreateTexture(nil, "HIGHLIGHT")
	for _, t in ipairs({ social.embleme, social.emblemeSurvol }) do
		t:SetTexture(PLANCHE_EMBLEMES)
		t:SetWidth(12)
		t:SetHeight(14)
		t:SetPoint("CENTER", social.bouton, "CENTER", 0, 2)
		t:Hide()
	end
end

-- APRES UN CHANGEMENT D'EMBLEME (constate le 28/09) : a GUILDTABARD_UPDATE,
-- GetGuildTabardFileNames ne rend rien tant que les nouvelles donnees de la
-- guilde ne sont pas arrivees, et aucun evenement ne suit leur arrivee -- le
-- bouton retombait sur son jeu de base et y restait. Dans une guilde, un
-- tabard illisible laisse donc le visuel en place, et le tabard est relu
-- toutes les RELECTURE s, RELECTURES fois apres chaque evenement ; la
-- derniere lecture tranche (une guilde sans tabard : le jeu de base).
local RELECTURE, RELECTURES = 0.5, 20
local relecture = CreateFrame("Frame")
relecture:Hide()
ForeverUI.RelectureTabard = relecture

local function appliquerTabard(fond, motif, couleur)
	social.jeu = fond and (social.jeuBase .. "-guildcolor") or social.jeuBase
	for etat, methode in pairs(ETATS_MICRO) do
		local texture = social.bouton[methode] and social.bouton[methode](social.bouton)
		if texture and ForeverUI.SetAtlas(texture, microAtlas(social.jeu, etat), true) then
			if fond then
				texture:SetVertexColor(fond[1], fond[2], fond[3])
			else
				texture:SetVertexColor(1, 1, 1)
			end
		end
	end
	if fond then
		local x = (motif % COLONNES_EMBLEMES) * CASE_EMBLEME
		local y = math.floor(motif / COLONNES_EMBLEMES) * CASE_EMBLEME
		for _, t in ipairs({ social.embleme, social.emblemeSurvol }) do
			t:SetTexCoord(x + BORD_EMBLEME, x + CASE_EMBLEME - BORD_EMBLEME, y + BORD_EMBLEME, y + CASE_EMBLEME - BORD_EMBLEME)
			t:SetVertexColor(couleur[1], couleur[2], couleur[3])
			t:Show()
		end
	else
		social.embleme:Hide()
		social.emblemeSurvol:Hide()
	end
	etatMicro(social)
end

-- GuildMicroButtonMixin:UpdateTabard ; definitif : la derniere relecture
function ForeverUI.MajTabardSocial(definitif)
	if not social then return end
	local fond, motif, couleur = tabardDeGuilde()
	local enGuilde = IsInGuild and IsInGuild()
	if fond or definitif or not enGuilde then
		appliquerTabard(fond, motif, couleur)
	end
end

relecture:SetScript("OnUpdate", function(self, ecoule)
	self.attente = (self.attente or 0) + ecoule
	if self.attente < RELECTURE then return end
	self.attente = 0
	self.restantes = (self.restantes or 0) - 1
	local fin = self.restantes <= 0
	ForeverUI.MajTabardSocial(fin)
	if fin then self:Hide() end
end)

local veilleTabard = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_GUILD_UPDATE", "GUILDTABARD_UPDATE" }) do
	veilleTabard:RegisterEvent(ev)
end
veilleTabard:SetScript("OnEvent", function()
	ForeverUI.MajTabardSocial()
	relecture.restantes, relecture.attente = RELECTURES, 0
	relecture:Show()
end)
micro:SetWidth(LARGEUR_BOUTONS)

-- LE BOUTON JcJ DU CLIENT S'EN VA (2026-09-26). Masquer ne suffit pas :
-- UpdateMicroButtons et VehicleMenuBar_MoveMicroButtons le reprennent.
ForeverUI.Suppress(_G["PVPMicroButton"])

-- LE BOUTON D'AIDE DU CLIENT S'EN VA AUSSI (2026-09-26, demande de
-- l'utilisateur) et la demande d'aide passe au menu Echap, entre AddOns et
-- Log Out, un espace de chaque cote (demande du 2026-09-26). AddOns n'est pas
-- du client : c'est ACP (patch-5.mpq), sous Macros, qui a chaque ouverture
-- remet Log Out sous lui (et ajoute 25 a la hauteur, qu'il retire a la
-- fermeture) -- on repasse donc derriere son OnShow. Sans ACP, la demande
-- d'aide vient sous Macros. L'espace est celui que le menu du client laisse
-- deja avant Return to Game (16, GameMenuFrame.xml ; camelot en met 20 entre
-- deux sections). Le texte est celui du bouton du client (HELP_BUTTON),
-- l'action aussi (ToggleHelpFrame), apres la fermeture du menu comme ses
-- voisins. Un bouton simple : un bouton securise rendrait tout le menu Echap
-- protege, et Show/HideUIPanel passent deja par le delegue du client.
local ECART_MENU = 16
ForeverUI.Suppress(_G["HelpMicroButton"])
if GameMenuFrame and GameMenuButtonMacros and GameMenuButtonLogout then
	local aide = CreateFrame("Button", "ForeverUIGameMenuButtonHelp", GameMenuFrame, "GameMenuButtonTemplate")
	aide:SetText(HELP_BUTTON)
	aide:SetScript("OnClick", function()
		PlaySound("igMainMenuOption")
		HideUIPanel(GameMenuFrame)
		ToggleHelpFrame()
	end)
	local function poser()
		aide:ClearAllPoints()
		aide:SetPoint("TOP", _G["GameMenuButtonAddOns"] or GameMenuButtonMacros, "BOTTOM", 0, -ECART_MENU)
		GameMenuButtonLogout:SetPoint("TOP", aide, "BOTTOM", 0, -ECART_MENU)
	end
	-- ACP charge avant nous (ordre alphabetique) ; s'il venait apres, on
	-- s'accroche des qu'il arrive, avant la premiere ouverture du menu
	local branche = false
	local function brancherACP()
		local acp = _G["GameMenuButtonAddOns"]
		if acp and not branche and acp.HookScript then
			branche = true
			acp:HookScript("OnShow", poser)
		end
		poser()
	end
	brancherACP()
	local veilleACP = CreateFrame("Frame")
	veilleACP:RegisterEvent("ADDON_LOADED")
	veilleACP:SetScript("OnEvent", function(self)
		brancherACP()
		if branche then self:UnregisterEvent("ADDON_LOADED") end
	end)
	-- Log Out etait a 1 sous son voisin ; il y a maintenant l'aide et deux espaces
	GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + aide:GetHeight() + 2 * ECART_MENU - 1)
end

-- Les boutons partent du bord GAUCHE du bandeau (layoutFramesGoingRight chez
-- camelot) ; le bandeau a leur largeur.
--
-- ET ON LES REPOSE, PARCE QUE LE CLIENT LES REPREND.
--
-- VehicleMenuBar_MoveMicroButtons les reancre : CharacterMicroButton a
-- BOTTOMLEFT (552, 2) et SocialsMicroButton sur le BOTTOMRIGHT de
-- QuestLogMicroButton. Elle est appelee par MainMenuBar_ToPlayerArt et
-- MainMenuBar_ToVehicleArt -- donc a chaque entree ou sortie de vehicule,
-- et le micro-menu se disloquait. Releve par /fui micro, qui a montre ces
-- deux boutons-la ancres ailleurs que sur notre bandeau.
--
-- Le bouton des metiers suit ses voisins : en vehicule, le client les passe
-- sur VehicleMenuBarArtFrame (MainMenuBar cache) ; il change de parent avec
-- eux, un cran au-dessus de la feuille de personnage.
local function poserMicro()
	for index, entree in ipairs(boutonsMicro) do
		if entree.cree and CharacterMicroButton then
			local parent = CharacterMicroButton:GetParent()
			if entree.bouton:GetParent() ~= parent then
				entree.bouton:SetParent(parent)
			end
			entree.bouton:SetFrameLevel(CharacterMicroButton:GetFrameLevel() + index - 1)
		end
		entree.bouton:ClearAllPoints()
		entree.bouton:SetPoint("LEFT", micro, "LEFT", (index - 1) * MICRO_PITCH, 0)
	end
end
ForeverUI.MicroLayout = poserMicro

-- l'etat du bouton des metiers : enfonce tant que les metiers sont ouverts
-- (le livre ou la page de fabrication) -- voir ProfessionsBook.lua
function ForeverUI.MajMicroMetiers(ouvert)
	for _, entree in ipairs(boutonsMicro) do
		if entree.cree then
			if ouvert then
				entree.bouton:SetButtonState("PUSHED", 1)
			else
				entree.bouton:SetButtonState("NORMAL")
			end
			etatMicro(entree)
		end
	end
end

poserMicro()

if hooksecurefunc and type(_G["VehicleMenuBar_MoveMicroButtons"]) == "function" then
	hooksecurefunc("VehicleMenuBar_MoveMicroButtons", poserMicro)
end

-- ------------------------------------------------------ la barre des sacs
local sacs = CreateFrame("Frame", "ForeverUIBagsBar", UIParent)
sacs:SetHeight(BAG_SIZE)
sacs:SetWidth(5 * BAG_SIZE + KEYRING_W + 5 * BAG_PADDING)

local cadreSacs = CreateFrame("Frame", nil, sacs)
cadreSacs:SetPoint("TOPLEFT", -6, 6)
cadreSacs:SetPoint("BOTTOMRIGHT", 5, -5)
cadreSacs:SetFrameLevel(sacs:GetFrameLevel())
ForeverUI.SetBarFrameArt(cadreSacs)

local function habillerSac(bouton, atlasCadre, largeurCadre)
	if not bouton then
		return false
	end

	bouton:SetWidth(largeurCadre == KEYRING_W and KEYRING_W or BAG_SIZE)
	bouton:SetHeight(BAG_SIZE)

	local normale = bouton:GetNormalTexture()
	if normale then
		ForeverUI.SetAtlas(normale, atlasCadre, true)
		normale:SetWidth(largeurCadre)
		normale:SetHeight(BAG_FRAME_H)
		normale:ClearAllPoints()
		normale:SetPoint("TOPLEFT", bouton, "TOPLEFT")
	end

	local enfoncee = bouton:GetPushedTexture()
	if enfoncee then
		ForeverUI.SetAtlas(enfoncee, atlasCadre, true)
		enfoncee:SetWidth(largeurCadre)
		enfoncee:SetHeight(BAG_FRAME_H)
		enfoncee:ClearAllPoints()
		enfoncee:SetPoint("TOPLEFT", bouton, "TOPLEFT")
	end

	local surbrillance = bouton:GetHighlightTexture()
	if surbrillance then
		ForeverUI.SetAtlas(surbrillance, atlasCadre, true)
		surbrillance:ClearAllPoints()
		surbrillance:SetAllPoints(bouton)
		surbrillance:SetBlendMode("ADD")
		surbrillance:SetAlpha(0.4)
	end

	-- La coche verte de 3.3.5 n'a rien a faire sur ce cadre : on reprend le
	-- meme dessin en ADD, comme pour les boutons d'action.
	local cochee = bouton.GetCheckedTexture and bouton:GetCheckedTexture()
	if cochee then
		ForeverUI.SetAtlas(cochee, atlasCadre, true)
		cochee:SetWidth(largeurCadre)
		cochee:SetHeight(BAG_FRAME_H)
		cochee:ClearAllPoints()
		cochee:SetPoint("TOPLEFT", bouton, "TOPLEFT")
		cochee:SetBlendMode("ADD")
	end

	local icone = _G[bouton:GetName() .. "IconTexture"]
	if icone then
		icone:ClearAllPoints()
		icone:SetAllPoints(bouton)
		icone:SetTexCoord(0, 1, 0, 1)
	end

	return true
end

-- Le trousseau : un bouton plus etroit, son propre cadre, sa propre image.
local iconeTrousseau
local function habillerTrousseau()
	local bouton = KeyRingButton
	if not bouton then
		return
	end

	habillerSac(bouton, "ui-hud-actionbar-iconframe-small", KEYRING_W)

	if not iconeTrousseau then
		iconeTrousseau = bouton:CreateTexture(nil, "BORDER")
		iconeTrousseau:SetPoint("CENTER")
	end

	-- ECART ASSUME. KeyRingMixin:OnBagUpdate ne montre l'image du trousseau
	-- que si la CVar showKeyring est allumee, et prend sinon l'emplacement
	-- vide. Cette condition vient d'un client ou le trousseau est un reste
	-- du passe, masque par defaut : sa CVar ne s'allume qu'au tutoriel, la
	-- premiere fois qu'on ramasse une cle. En 3.3.5 le trousseau est un
	-- element permanent de la barre, et notre barre montre toujours sa
	-- cellule : un emplacement vide y serait faux. L'image du trousseau est
	-- donc TOUJOURS posee.
	-- LA VARIANTE DOUBLE DENSITE (demande du 2026-09-28 : « l'icone semble
	-- pixelisee ou zoomee ») : la simple fait 27 x 40 texels pour 27 x 40
	-- unites, et une unite vaut plus d'un pixel a l'ecran -- elle
	-- s'agrandissait. La -2x (uiactionbar2xc60, 54 x 80) se pose a la meme
	-- taille, nette.
	ForeverUI.SetAtlas(iconeTrousseau, "ui-hud-actionbar-keyring-small-c60-2x")

	-- camelot garde toujours ce bouton dans la barre ; 3.3.5 le laisse cache
	-- tant que le joueur n'a pas ramasse de cle.
	bouton:Show()
end

-- L'ANIMATION D'ENTREE DU TROUSSEAU (demande du 2026-09-28). RELEVE --
-- BaseBagSlotButtonTemplate (mainline/mainmenubarbagbuttontemplates.xml) :
-- AnimIcon, calque OVERLAY, sur tout le bouton ; FlyIn : en 1 s, echelle de
-- 0,125 a 1, alpha de 0 a 1, chemin doux (SMOOTH) par (-15, 30) et
-- (-75, 60). KeyRingMixin le joue A L'ENVERS (FlyIn:Play(true)) : l'icone
-- de la cle part de (-75, 60), entiere et opaque, et rentre dans le bouton,
-- reduite au huitieme et effacee. 3.3.5 n'a ni lecture a l'envers ni echelle
-- de depart : on la joue image par image. Elle remplace l'animation 3D de
-- 3.3.5 (KeyRingButtonItemAnim, ForcedBackpackItem.mdx).
local VOL = { duree = 1, echelle = 0.125, points = { { 0, 0 }, { -15, 30 }, { -75, 60 } } }

-- la courbe douce : Catmull-Rom par les points, extremites doublees
local function courbe(q)
	local p = VOL.points
	local n = #p - 1
	local s = math.min(n - 1e-9, math.max(0, q * n))
	local i = math.floor(s) + 1
	local u = s - (i - 1)
	local a, b, c, d = p[math.max(1, i - 1)], p[i], p[i + 1], p[math.min(#p, i + 2)]
	local function axe(k)
		return 0.5 * (2 * b[k] + (c[k] - a[k]) * u + (2 * a[k] - 5 * b[k] + 4 * c[k] - d[k]) * u * u
			+ (3 * b[k] - a[k] - 3 * c[k] + d[k]) * u * u * u)
	end
	return axe(1), axe(2)
end
ForeverUI.KeyRingFlyCurve = courbe

local vol = CreateFrame("Frame")
vol:Hide()
vol:SetScript("OnUpdate", function(self, ecoule)
	self.t = self.t + (ecoule or 0)
	local icone = self.icone
	if self.t >= VOL.duree then
		icone:Hide()
		self:Hide()
		return
	end
	-- a l'envers : la progression va de 1 a 0
	local q = 1 - self.t / VOL.duree
	local x, y = courbe(q)
	local k = VOL.echelle + (1 - VOL.echelle) * q
	local b = KeyRingButton
	icone:ClearAllPoints()
	icone:SetPoint("CENTER", b, "CENTER", x, y)
	icone:SetWidth(b:GetWidth() * k)
	icone:SetHeight(b:GetHeight() * k)
	icone:SetAlpha(q)
	icone:Show()
end)
vol:RegisterEvent("ITEM_PUSH")
vol:SetScript("OnEvent", function(self, _, sac, texture)
	local b = KeyRingButton
	if not b or sac ~= b:GetID() then
		return
	end
	if not self.icone then
		self.icone = b:CreateTexture(nil, "OVERLAY")
		self.icone:Hide()
	end
	self.icone:SetTexture(texture)
	self.t = 0
	self:Show()
end)
ForeverUI.KeyRingFly = vol
if KeyRingButtonItemAnim then
	KeyRingButtonItemAnim:UnregisterEvent("ITEM_PUSH")
	KeyRingButtonItemAnim:Hide()
end

local ORDRE_SACS = {
	"MainMenuBarBackpackButton",
	"CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
}

local cellules = {}
local separateurs = {}

local function poserSacs()
	local precedent = nil
	cellules = {}

	for _, nom in ipairs(ORDRE_SACS) do
		local bouton = _G[nom]
		if bouton then
			habillerSac(bouton, "ui-hud-actionbar-iconframe-bags", BAG_FRAME_W)
			bouton:ClearAllPoints()
			if precedent then
				bouton:SetPoint("RIGHT", precedent, "LEFT", -BAG_PADDING, 0)
			else
				bouton:SetPoint("RIGHT", sacs, "RIGHT", 0, 0)
			end
			precedent = bouton
			table.insert(cellules, bouton)
		end
	end

	habillerTrousseau()
	if KeyRingButton and precedent then
		KeyRingButton:ClearAllPoints()
		KeyRingButton:SetPoint("RIGHT", precedent, "LEFT", -BAG_PADDING, 0)
		table.insert(cellules, KeyRingButton)
	end

	-- Un separateur entre deux cellules voisines : LEFT sur le RIGHT de la
	-- cellule de gauche, decale de -5, donc centre sur l'ecart de 2 px.
	for index = 2, #cellules do
		if not separateurs[index] then
			local divider = ForeverUI.CreateDivider(sacs, sacs:GetFrameLevel() + 2)
			divider:SetPoint("TOP", cellules[index], "TOP", 0, 0)
			divider:SetPoint("BOTTOM", cellules[index], "BOTTOM", 0, 0)
			divider:SetPoint("LEFT", cellules[index], "RIGHT", -5, 0)
			separateurs[index] = divider
		end
	end
end

-- Le sac a dos porte l'icone de camelot, un fichier a part et non un element
-- d'atlas (camelot/MainMenuBarBagButtons.xml : bagIcon).
local function iconeSacADos()
	local icone = MainMenuBarBackpackButtonIconTexture
	if icone then
		icone:SetTexture(ICONE_SAC)
		icone:SetTexCoord(0, 1, 0, 1)
	end
end

-- ------------------------------------------------------------ assemblage
-- La rangee est une chaine : la barre d'action et les sacs se posent de part
-- et d'autre du micro-menu. On convertit cette chaine en positions par rapport
-- a l'ecran, pour que chaque element reste deplacable separement.
local function positionsParDefaut()
	local demi = micro:GetWidth() / 2
	ForeverUI.Layout.SetDefaults("actionbar", "BOTTOMRIGHT", "BOTTOM",
		MICRO_X - demi + BAR_OFFSET_X, MICRO_Y + BAR_OFFSET_Y)
	ForeverUI.Layout.SetDefaults("sacs", "BOTTOMLEFT", "BOTTOM",
		MICRO_X + demi + BAGS_OFFSET_X, MICRO_Y + BAGS_OFFSET_Y)
end

-- La rangee mesuree, pour ce qui vient se poser dessus (les barres d'etat).
-- Tout est exprime comme les positions par defaut : x compte depuis le centre
-- de l'ecran, y depuis le bas.
local function mesurerRangee()
	local demi = micro:GetWidth() / 2
	local barre = ForeverUI.ActionBarHolder
	local barreDroite = MICRO_X - demi + BAR_OFFSET_X
	local barreGauche = barreDroite - (barre and barre:GetWidth() or 0)
	local sacsGauche = MICRO_X + demi + BAGS_OFFSET_X

	-- Le haut de la rangee, c'est le plus haut des trois encadrements : celui
	-- de la barre d'action et celui des sacs debordent de 6, celui du
	-- micro-menu de 8.
	local hautBarre = MICRO_Y + BAR_OFFSET_Y + BAG_SIZE + 6
	local hautMicro = MICRO_Y + MICRO_H + 8
	local hautSacs = MICRO_Y + BAGS_OFFSET_Y + BAG_SIZE + 6

	ForeverUI.BottomRow = {
		-- D'un bout a l'autre des trois blocs : du bord gauche de la barre
		-- d'action au bord droit de la barre des sacs. Les embouts debordent
		-- de 30 px de chaque cote, mais ce qui se pose au-dessus s'aligne sur
		-- les blocs, pas sur les griffons.
		gauche = barreGauche,
		droite = sacsGauche + sacs:GetWidth(),
		haut = math.max(hautBarre, hautMicro, hautSacs),
	}
end

-- Les embouts encadrent TOUTE la rangee : le gauche tient a la barre d'action,
-- le droit a la barre des sacs.
local function poserEmbouts()
	local embouts = ForeverUI.ActionBarEndCaps
	if not embouts or not embouts.right then
		return
	end

	embouts.right:ClearAllPoints()
	-- Meme descente de 2 px que l'embout gauche (voir ActionBar.lua).
	embouts.right:SetPoint("BOTTOMLEFT", sacs, "BOTTOMRIGHT", -30, -2)
end

local function toutPoser()
	poserSacs()
	iconeSacADos()
	poserMicro()
	for _, entree in ipairs(boutonsMicro) do
		etatMicro(entree)
	end
end

ForeverUI.Layout.Register(micro, "micromenu", L.BOTTOMBAR_EDIT_LABEL_MICROMENU, "BOTTOM", "BOTTOM", MICRO_X, MICRO_Y)
ForeverUI.Layout.Register(sacs, "sacs", L.BOTTOMBAR_EDIT_LABEL_BAGS, "BOTTOMLEFT", "BOTTOM",
	MICRO_X + micro:GetWidth() / 2 + BAGS_OFFSET_X, MICRO_Y + BAGS_OFFSET_Y)
positionsParDefaut()
mesurerRangee()
poserEmbouts()
toutPoser()

if hooksecurefunc then
	hooksecurefunc("UpdateMicroButtons", function()
		for _, entree in ipairs(boutonsMicro) do
			etatMicro(entree)
		end
	end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("BAG_UPDATE")
watcher:RegisterEvent("CVAR_UPDATE")
watcher:SetScript("OnEvent", function()
	toutPoser()
end)

-- TEMOIN -- /fui micro. Deux questions a la fois : ou est chaque bouton, et
-- qui prend la souris a sa place.
--
-- L'ANCRAGE dit s'il a bouge : nous les posons une fois, a gauche du
-- bandeau, d'un pas fixe. Un ancrage sur autre chose que ForeverUIMicroMenu,
-- ou un decalage qui n'est pas un multiple du pas, veut dire que le client
-- les a repris -- VehicleMenuBar_MoveMicroButtons est le seul a le faire en
-- 3.3.5, mais un autre addon le peut aussi.
--
-- GetMouseFocus dit qui recoit reellement le clic : un bouton peut etre au
-- bon endroit et recouvert.
function ForeverUI.MicroDebug()
	local dire = function(texte)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
	end

	dire(string.format(L.BOTTOMBAR_MICRO_DEBUG,
		#boutonsMicro, micro:GetWidth() or 0, micro:GetHeight() or 0, MICRO_PITCH))

	for index, entree in ipairs(boutonsMicro) do
		local bouton = entree.bouton
		local point, cible, pointCible, x, y = bouton:GetPoint(1)
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"   " .. L.BOTTOMBAR_MICRO_BUTTON,
			index, bouton:GetName() or "?", tostring(point),
			tostring(cible and cible.GetName and cible:GetName()),
			tostring(x), tostring(y), bouton:GetWidth() or 0, bouton:GetHeight() or 0,
			(index - 1) * MICRO_PITCH,
			tostring(bouton:IsShown()), tostring(bouton:IsEnabled()),
			bouton:GetFrameLevel() or 0, bouton:GetNumPoints() or 0))
	end

	-- Pendant cinq secondes, ce que le curseur touche reellement.
	local veille = CreateFrame("Frame")
	local reste, dernier = 5, nil
	veille:SetScript("OnUpdate", function(self, ecoule)
		reste = reste - (ecoule or 0)
		local sous = GetMouseFocus and GetMouseFocus()
		local nom = sous and sous.GetName and sous:GetName() or L.BOTTOMBAR_NOTHING
		if nom ~= dernier then
			dernier = nom
            DEFAULT_CHAT_FRAME:AddMessage("   " .. L.BOTTOMBAR_UNDER_CURSOR .. nom)
		end
		if reste <= 0 then
			self:SetScript("OnUpdate", nil)
		end
	end)
	dire(L.BOTTOMBAR_HOVER_PROMPT)
end

-- LES CONTENANTS VIDES NE PRENNENT PLUS LA SOURIS.
--
-- MainMenuBar est declaree enableMouse="true" et couvre tout le bas de
-- l'ecran. Son art est remplace par le notre, mais elle restait une dalle
-- qui avalait les clics -- GetMouseFocus la rendait a la place du bouton
-- survole. Comme BonusActionBarFrame, et pour la meme raison : un cadre qui
-- ne sert que de contenant n'a pas a recevoir de clic. Ses enfants -- les
-- boutons d'action, les micro-boutons -- gardent le leur.
for _, nom in ipairs({ "MainMenuBar", "MainMenuBarArtFrame" }) do
	local cadre = _G[nom]
	if cadre and cadre.EnableMouse then
		cadre:EnableMouse(false)
	end
end

ForeverUI.MicroMenu = micro
ForeverUI.MicroButtons = boutonsMicro
ForeverUI.BagsBar = sacs
ForeverUI.BagsCells = cellules
ForeverUI.BagsDividers = separateurs

ForeverUI.BottomBarDebug = function()
	local point, _relativeTo, relativePoint, x, y = sacs:GetPoint(1)
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r " .. L.BOTTOMBAR_DEBUG,
		micro:GetWidth(), micro:GetHeight(), #boutonsMicro,
		sacs:GetWidth(), sacs:GetHeight(),
		tostring(point), tostring(relativePoint), x or 0, y or 0,
		tostring(KeyRingButton and KeyRingButton:IsShown())))
end
