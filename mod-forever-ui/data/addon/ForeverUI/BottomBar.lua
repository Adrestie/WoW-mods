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
--   latence       MainMenuBarPerformanceBar, 19 x 39, BOTTOM (0, -2)
--
-- camelot/MicroMenuContainerOverrides.lua donne l'ordre. Trois des dix boutons
-- de 3.3.5 n'existent plus chez camelot, et l'atlas ne leur offre pas de jeu
-- d'images c60 :
--   Succes -> jeu "Achievements", present dans l'atlas mais sans variante c60
--             (camelot a retire ce bouton) : on prend la variante de base.
--   JcJ    -> aucun equivalent : le fond de camelot, et l'embleme de faction
--             de 3.3.5 (PVPMicroButtonTexture) pour image.
--   Aide   -> camelot lui donne le meme jeu qu'au menu du jeu, mais cache le
--             bouton ; ici il reste visible, donc deux points d'interrogation
--             voisins. On lui donne "AdventureGuide", le seul jeu c60
--             inutilise qui evoque un manuel. CHOIX A CONFIRMER.
--
-- camelot/MainMenuBarBagButtons.xml + shared/BagsBar.lua
--   sac              45 x 45, bagPadding = 2, ranges vers la GAUCHE depuis le
--                    sac a dos
--   ordre            sac a dos, sacs 1 a 4, trousseau (le sac a composants
--                    de camelot n'existe pas sur 3.3.5 et sa place n'est plus
--                    tenue : les 47 px rendus vont au bandeau du micro-menu,
--                    la rangee garde donc sa longueur)
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

-- Place rendue par le sac a composants absent, reversee au micro-menu pour
-- que la rangee garde sa longueur.
local MICRO_RALLONGE = 45 + 2

local MICRO_X, MICRO_Y = 116.5, 6
local BAR_OFFSET_X, BAR_OFFSET_Y = -4.5, -4
local BAGS_OFFSET_X, BAGS_OFFSET_Y = 7, -4

-- Lua 5.1 lit les antislashs d'une chaine comme des echappements : on pose le
-- separateur de chemin en clair plutot que de le doubler.
local SEP = string.char(92)
local ICONE_SAC = "Interface" .. SEP .. "ForeverUI" .. SEP .. "icons" .. SEP .. "ui-hud-actionbar-bag"

-- L'ordre de camelot, reduit aux boutons que ce client possede.
local MICRO = {
	{ nom = "CharacterMicroButton", portrait = true },
	{ nom = "SpellbookMicroButton", jeu = "spellbookabilities" },
	{ nom = "TalentMicroButton", jeu = "spectalents" },
	{ nom = "AchievementMicroButton", jeu = "achievements" },
	{ nom = "QuestLogMicroButton", jeu = "questlog" },
	{ nom = "SocialsMicroButton", jeu = "guildcommunities" },
	{ nom = "PVPMicroButton", embleme = true },
	{ nom = "LFDMicroButton", jeu = "groupfinder" },
	{ nom = "HelpMicroButton", jeu = "adventureguide" },
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

-- PVPFrame.lua repose l'embleme avec SetPoint("TOP", ...) sans effacer les
-- ancrages : il faut donc le recentrer apres chaque appel du client, pas une
-- seule fois au chargement. Le client le decale de (-1, -1) et le passe a 50 %
-- quand le bouton est enfonce : on garde ce comportement.
local function ancrerEmbleme(entree, enfonce)
	local embleme = entree.embleme
	if not embleme then
		return
	end

	embleme:ClearAllPoints()
	embleme:SetPoint("CENTER", entree.bouton, "CENTER", enfonce and -1 or 0, enfonce and -1 or 0)
	embleme:SetAlpha(enfonce and 0.5 or 1)
end

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

	ancrerEmbleme(entree, enfonce)

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

local function habillerMicro(definition, index)
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

	local entree = { bouton = bouton, jeu = definition.jeu, portrait = definition.portrait }

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

	if definition.embleme then
		-- L'embleme de faction de 3.3.5, pose au centre du fond de camelot.
		local embleme = _G[definition.nom .. "Texture"]
		if embleme then
			embleme:SetDrawLayer("ARTWORK")
			embleme:SetWidth(24)
			embleme:SetHeight(24)
			entree.embleme = embleme
			ancrerEmbleme(entree, false)

			-- L'appui ne passe pas par UpdateMicroButtons : on s'accroche aussi
			-- aux deux scripts du bouton.
			bouton:HookScript("OnMouseDown", function()
				ancrerEmbleme(entree, true)
			end)
			bouton:HookScript("OnMouseUp", function()
				ancrerEmbleme(entree, false)
			end)
		end
	end

	if definition.nom == "MainMenuMicroButton" and MainMenuBarPerformanceBar then
		MainMenuBarPerformanceBar:SetWidth(19)
		MainMenuBarPerformanceBar:SetHeight(39)
		MainMenuBarPerformanceBar:ClearAllPoints()
		MainMenuBarPerformanceBar:SetPoint("BOTTOM", bouton, "BOTTOM", 0, -2)
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
micro:SetWidth(LARGEUR_BOUTONS + MICRO_RALLONGE)

-- Les boutons restent serres contre le bord GAUCHE du bandeau : la rallonge
-- reste libre a droite, du cote ou le micro-menu s'allonge
-- (layoutFramesGoingRight chez camelot).
--
-- ET ON LES REPOSE, PARCE QUE LE CLIENT LES REPREND.
--
-- VehicleMenuBar_MoveMicroButtons les reancre : CharacterMicroButton a
-- BOTTOMLEFT (552, 2) et SocialsMicroButton sur le BOTTOMRIGHT de
-- QuestLogMicroButton. Elle est appelee par MainMenuBar_ToPlayerArt et
-- MainMenuBar_ToVehicleArt -- donc a chaque entree ou sortie de vehicule,
-- et le micro-menu se disloquait. Releve par /fui micro, qui a montre ces
-- deux boutons-la ancres ailleurs que sur notre bandeau.
local function poserMicro()
	for index, entree in ipairs(boutonsMicro) do
		entree.bouton:ClearAllPoints()
		entree.bouton:SetPoint("LEFT", micro, "LEFT", (index - 1) * MICRO_PITCH, 0)
	end
end
ForeverUI.MicroLayout = poserMicro

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
	ForeverUI.SetAtlas(iconeTrousseau, "ui-hud-actionbar-keyring-small")

	-- camelot garde toujours ce bouton dans la barre ; 3.3.5 le laisse cache
	-- tant que le joueur n'a pas ramasse de cle.
	bouton:Show()
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

ForeverUI.Layout.Register(micro, "micromenu", "Micro-menu", "BOTTOM", "BOTTOM", MICRO_X, MICRO_Y)
ForeverUI.Layout.Register(sacs, "sacs", "Barre des sacs", "BOTTOMLEFT", "BOTTOM",
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

	dire(string.format("micro-menu : %d boutons, bandeau %.0f x %.0f, pas %d",
		#boutonsMicro, micro:GetWidth() or 0, micro:GetHeight() or 0, MICRO_PITCH))

	for index, entree in ipairs(boutonsMicro) do
		local bouton = entree.bouton
		local point, cible, pointCible, x, y = bouton:GetPoint(1)
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"   %2d %-24s %s sur %s (%s, %s) | %.0f x %.0f | attendu x=%d | "
			.. "visible=%s actif=%s niveau=%d ancres=%d",
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
		local nom = sous and sous.GetName and sous:GetName() or "(rien)"
		if nom ~= dernier then
			dernier = nom
            DEFAULT_CHAT_FRAME:AddMessage("   sous le curseur : " .. nom)
		end
		if reste <= 0 then
			self:SetScript("OnUpdate", nil)
		end
	end)
	dire("promenez le curseur sur le bouton du personnage : cinq secondes.")
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
		"|cff66ccffForeverUI|r bas : micro %.0f x %.0f (%d boutons) | sacs %.0f x %.0f | ancre %s sur %s (%.1f, %.1f) | trousseau visible=%s",
		micro:GetWidth(), micro:GetHeight(), #boutonsMicro,
		sacs:GetWidth(), sacs:GetHeight(),
		tostring(point), tostring(relativePoint), x or 0, y or 0,
		tostring(KeyRingButton and KeyRingButton:IsShown())))
end
