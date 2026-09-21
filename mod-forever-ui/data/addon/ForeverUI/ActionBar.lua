-- ForeverUI : la barre d'action principale.
--
-- RELEVE DES SOURCES -- tout vient du code extrait de camelot.
--
-- mainline/ActionButtonTemplate.xml (la famille que charge camelot)
--   bouton            45 x 45          <Size x="45" y="45"/>
--   icone             sans ancrage ni taille : elle remplit le bouton, donc
--                     45 x 45. Le moderne l'arrondit avec un masque
--                     (UI-HUD-ActionBar-IconFrame-Mask) ; 3.3.5 n'a pas de
--                     MaskTexture, et ce sont les coins pleins du cadre qui
--                     recouvrent les angles de l'icone.
--   fond d'emplacement UI-HUD-ActionBar-IconFrame-Background, setAllPoints
--   art d'emplacement ui-hud-actionbar-iconframe-slot, setAllPoints
--   cadre normal      UI-HUD-ActionBar-IconFrame, 46 x 45, ancre TOPLEFT
--   enfonce           UI-HUD-ActionBar-IconFrame-Down, 46 x 45, TOPLEFT
--   survol            UI-HUD-ActionBar-IconFrame-Mouseover, 46 x 45, TOPLEFT
--   coche             le meme survol, mais en melange ADD
--   bordure           UI-HUD-ActionBar-IconFrame-Border, taille d'atlas,
--                     TOPLEFT, masquee par defaut
--   raccourci         32 x 10, TOPRIGHT (-5, -5), NumberFontNormalSmallGray,
--                     aligne a droite
--   quantite          NumberFontNormal, BOTTOMRIGHT (-5, 5), aligne a droite
--   nom de macro      36 x 10, BOTTOM (0, 2), GameFontHighlightSmallOutline
--   recharge          ancree sur l'icone avec 3 px de retrait de chaque cote
--
-- shared/ActionBar.lua
--   minButtonPadding = 2 : les boutons sont espaces de 2 px, soit un pas de
--   47 px pour des boutons de 45.
--
-- mainline/MainActionBar.xml
--   douze boutons sur une rangee ; bordure de barre UI-HUD-ActionBar-Frame
--   ancree TOPLEFT (-6, 6) et BOTTOMRIGHT (4, -5) sur la barre. C'est UNE
--   image de 55 x 55, decoupee en neuf par ForeverUI.SetBarFrameArt.
--   Les separateurs se posent entre deux boutons : RIGHT sur le LEFT du
--   bouton decale de 5, sur toute la hauteur -- trois tranches verticales de
--   12 de large (ForeverUI.CreateDivider).
--
-- camelot/MainMenuBarEndCaps.xml
--   embouts : deux cadres de 154 x 95, textures ui-hud-actionbar-gryphon-left
--   et -right qui les remplissent (pas de taille d'atlas).
--
-- CE QUE CE FICHIER NE FAIT PAS. Les boutons d'action du client sont des
-- cadres securises : on les garde et on les rhabille. Les recreer signifierait
-- reecrire sorts, macros et glisser-deposer, et risquer la contamination du
-- code protege. Rien n'est redimensionne ni deplace en combat, ou le client
-- l'interdit.

local BUTTON_SIZE = 45
local BUTTON_PADDING = 2
local BUTTON_PITCH = BUTTON_SIZE + BUTTON_PADDING
local FRAME_WIDTH, FRAME_HEIGHT = 46, 45      -- taille des quatre etats
local BUTTON_COUNT = 12
local END_CAP_WIDTH, END_CAP_HEIGHT = 154, 95
local DESCENTE_EMBOUT = -2      -- releve a l'ecran : le bas de l'image tombe
                                -- 2 px sous le bas de la barre

local ATLAS = {
	normal = "ui-hud-actionbar-iconframe",
	pushed = "ui-hud-actionbar-iconframe-down",
	highlight = "ui-hud-actionbar-iconframe-mouseover",
	border = "ui-hud-actionbar-iconframe-border",
	slot = "ui-hud-actionbar-iconframe-slot",
	background = "ui-hud-actionbar-iconframe-background",
	flash = "ui-hud-actionbar-iconframe-flash",
}

local BARS = {
	"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
	"MultiBarRightButton", "MultiBarLeftButton", "BonusActionButton",
}

-- POURQUOI LE CADRE N'EST PAS LA NormalTexture DU BOUTON. ActionButton_Update
-- appelle SetNormalTexture("Interface\Buttons\UI-Quickslot2") a chaque
-- rafraichissement, et ActionButton_ShowGrid lui remet une couleur : tout
-- habillage pose dessus est efface dans la seconde. On neutralise donc celle
-- du client et on dessine notre propre cadre, que rien ne vient reecrire.
local function setStateTexture(texture, atlas, add)
	if not texture then
		return
	end

	ForeverUI.SetAtlas(texture, atlas, true)
	texture:SetWidth(FRAME_WIDTH)
	texture:SetHeight(FRAME_HEIGHT)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", 0, 0)
	texture:SetBlendMode(add and "ADD" or "BLEND")
end

-- Remet a zero ce que le client vient de reecrire.
local function silenceNormalTexture(button)
	local normal = button:GetNormalTexture()
	if normal then
		normal:SetAlpha(0)
		normal:SetVertexColor(1, 1, 1, 0)
	end
end

-- PIEGE 3.3.5. Ce n'est pas le fond de l'emplacement que le client masque,
-- c'est LE BOUTON ENTIER : ActionButton_HideGrid le cache des que le
-- compteur showgrid retombe a zero, et ce compteur ne monte que le temps
-- d'un glisser-deposer (evenements ACTIONBAR_SHOWGRID / _HIDEGRID). Un
-- emplacement vide disparait donc, et notre art avec lui.
--
-- On maintient le compteur a 1 : le client garde alors ses boutons vides
-- affiches de lui-meme. Le Show de secours ne sert que si le bouton etait
-- deja masque, et jamais en combat -- afficher un cadre securise y est
-- interdit. Ce qui aurait ete masque pendant un combat revient a la sortie,
-- PLAYER_REGEN_ENABLED etant deja surveille.
local function garderGrille(button)
	if not button or button:GetAttribute("statehidden") then
		return
	end

	button.showgrid = math.max(button.showgrid or 0, 1)
	if not button:IsShown() and not InCombatLockdown() then
		button:Show()
	end
end

local function skinButton(button)
	if not button or button.foreverSkinned then
		return
	end

	local name = button:GetName()
	if not name then
		return
	end

	local icon = _G[name .. "Icon"]
	local border = _G[name .. "Border"]
	local hotkey = _G[name .. "HotKey"]
	local count = _G[name .. "Count"]
	local macro = _G[name .. "Name"]
	local cooldown = _G[name .. "Cooldown"]
	local flash = _G[name .. "Flash"]
	local floatingBG = _G[name .. "FloatingBG"]

	button:SetWidth(BUTTON_SIZE)
	button:SetHeight(BUTTON_SIZE)

	-- L'emplacement vide, sous l'icone.
	local background = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, ATLAS.background, true)
	background:SetAllPoints(button)

	local slot = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(slot, ATLAS.slot, true)
	slot:SetAllPoints(button)

	button.foreverBackground = background
	button.foreverSlot = slot

	if icon then
		-- L'icone occupe tout le bouton, comme dans la source ; les angles
		-- sont couverts par les coins pleins du cadre.
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetDrawLayer("BORDER")
	end

	-- Notre cadre, pose au-dessus de l'icone et hors d'atteinte du client.
	local cadre = button:CreateTexture(nil, "ARTWORK")
	setStateTexture(cadre, ATLAS.normal)
	button.foreverFrame = cadre

	silenceNormalTexture(button)
	setStateTexture(button:GetPushedTexture(), ATLAS.pushed)
	setStateTexture(button:GetHighlightTexture(), ATLAS.highlight)
	setStateTexture(button:GetCheckedTexture(), ATLAS.highlight, true)

	if flash then
		ForeverUI.SetAtlas(flash, ATLAS.flash)
		flash:ClearAllPoints()
		flash:SetPoint("TOPLEFT", 0, 0)
	end

	if border then
		-- La bordure d'equipement du client est verte et carree ; la source
		-- utilise sa propre bordure, masquee par defaut.
		ForeverUI.SetAtlas(border, ATLAS.border)
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", 0, 0)
	end

	if floatingBG then
		floatingBG:SetAlpha(0)
	end

	if hotkey then
		hotkey:SetWidth(32)
		hotkey:SetHeight(10)
		hotkey:SetJustifyH("RIGHT")
		hotkey:ClearAllPoints()
		hotkey:SetPoint("TOPRIGHT", -5, -5)
		hotkey:SetFontObject(NumberFontNormalSmallGray)
	end

	if count then
		count:SetJustifyH("RIGHT")
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", -5, 5)
		count:SetFontObject(NumberFontNormal)
	end

	if macro then
		macro:SetWidth(36)
		macro:SetHeight(10)
		macro:ClearAllPoints()
		macro:SetPoint("BOTTOM", 0, 2)
		macro:SetFontObject(GameFontHighlightSmallOutline)
	end

	if cooldown and icon then
		cooldown:ClearAllPoints()
		cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", 3, -3)
		cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -3, 3)
	end

	garderGrille(button)
	button.foreverSkinned = true
end

-- ------------------------------------------------------------ la barre
local holder = CreateFrame("Frame", "ForeverUIActionBarHolder", UIParent)
holder:SetWidth(BUTTON_COUNT * BUTTON_SIZE + (BUTTON_COUNT - 1) * BUTTON_PADDING)
holder:SetHeight(BUTTON_SIZE)

-- Bordure de barre : la source pose UI-HUD-ActionBar-Frame, une seule image
-- octogonale, entre TOPLEFT (-6, 6) et BOTTOMRIGHT (4, -5). On la decoupe en
-- neuf pour que les biseaux des coins gardent leur taille.
local border = CreateFrame("Frame", nil, holder)
border:SetPoint("TOPLEFT", -6, 6)
border:SetPoint("BOTTOMRIGHT", 4, -5)
border:SetFrameLevel(holder:GetFrameLevel())
ForeverUI.SetBarFrameArt(border)

-- Le bloc de pagination.
-- RELEVE -- mainline/MainActionBar.xml : ActionBarPageNumber se pose
-- BOTTOMRIGHT sur le BOTTOMLEFT de la barre, decale de (-4, 9). Il contient le
-- numero (17 x 10, centre a -1) et deux fleches de 17 x 14, centrees a +10 et
-- -10. Sa taille suit ses enfants : 17 de large, 34 de haut.
local page = CreateFrame("Frame", "ForeverUIActionBarPage", holder)
page:SetWidth(17)
page:SetHeight(34)
page:SetPoint("BOTTOMRIGHT", holder, "BOTTOMLEFT", -4, 9)
page:SetFrameLevel(holder:GetFrameLevel() + 11)

-- Separateurs entre boutons : RIGHT sur le LEFT du bouton, decale de 5.
local dividers = {}

-- Embouts : deux cadres de 154 x 95 que la texture remplit.
local function createEndCap(nom, atlas, point, relPoint, decalageX)
	local cap = CreateFrame("Frame", nom, holder)
	cap:SetWidth(END_CAP_WIDTH)
	cap:SetHeight(END_CAP_HEIGHT)
	cap:SetPoint(point, holder, relPoint, decalageX, DESCENTE_EMBOUT)
	-- RELEVE -- camelot/MainMenuBarEndCaps.xml : frameLevel 100. L'embout passe
	-- DEVANT les boutons, dont le niveau est celui du cadre du client.
	cap:SetFrameLevel(holder:GetFrameLevel() + 10)

	local texture = cap:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints(cap)
	if not ForeverUI.SetAtlas(texture, atlas, true) then
		cap:Hide()
	end
	cap.texture = texture
	return cap
end

-- RELEVE -- mainline/EditModePresetLayouts.lua : l'embout gauche se pose sur
-- le bord GAUCHE de la barre, l'embout droit sur le bord DROIT de la BARRE DES
-- SACS, chacun rentrant de 30 px. BottomBar.lua reancre le droit sur les sacs
-- des que ceux-ci existent.
--
-- ECART ASSUME SUR LA VERTICALE. La source cale l'embout 20 px SOUS le bas de
-- la barre (mainline : BOTTOMRIGHT (9, -22) pour 98 de haut ; camelot : centre
-- a +5 du milieu d'une barre de 45 pour 95 de haut -- meme resultat). La barre
-- etant a 2 px du bas de l'ecran, ces 20 px tombent hors de l'ecran : les
-- pattes du griffon disparaissent et la barre vient mordre sa tete. On cale
-- donc le BAS de l'image sur le BAS de la barre, comme le jeu le montre --
-- puis 2 px plus bas, valeur relevee a l'ecran.
local leftCap = createEndCap("ForeverUIActionBarLeftCap", "ui-hud-actionbar-gryphon-left", "BOTTOMRIGHT", "BOTTOMLEFT", 30)
local rightCap = createEndCap("ForeverUIActionBarRightCap", "ui-hud-actionbar-gryphon-right", "BOTTOMLEFT", "BOTTOMRIGHT", -30)

local function layoutButtons()
	if InCombatLockdown() then
		return
	end

	for index = 1, BUTTON_COUNT do
		local button = _G["ActionButton" .. index]
		if button then
			-- On ne reparente pas : le bouton reste enfant de la barre du
			-- client, donc il suit sa visibilite (vehicule, possession). Seul
			-- son ancrage change.
			button:ClearAllPoints()
			button:SetPoint("LEFT", holder, "LEFT", (index - 1) * BUTTON_PITCH, 0)

			if index > 1 and not dividers[index] then
				local divider = ForeverUI.CreateDivider(holder, holder:GetFrameLevel() + 1)
				divider:SetPoint("TOP", button, "TOP", 0, 0)
				divider:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
				divider:SetPoint("RIGHT", button, "LEFT", 5, 0)
				dividers[index] = divider
			end
		end
	end
end

-- Le fond de barre du client n'a plus rien a faire la. RELEVE dans
-- 3.3.5 MainMenuBar.xml : l'habillage d'epoque n'est pas une image mais
-- QUATRE series de morceaux, et en oublier une laisse la vieille barre naine
-- derriere la notre --
--   MainMenuBarTexture0..3    le corps de la barre (MainMenuBarArtFrame)
--   MainMenuXPBarTexture0..3  l'encadrement de la barre d'experience
--   MainMenuMaxLevelBar0..3   sa version niveau maximum, affichee a 80
--   MainMenuBarLeftEndCap / RightEndCap  les embouts nains
-- plus le texte d'experience de MainMenuBarOverlayFrame.
local OLD_ART = {
	"MainMenuBarTexture%d", "MainMenuXPBarTexture%d", "MainMenuMaxLevelBar%d",
}

local function hideOldBarArt()
	for _, modele in ipairs(OLD_ART) do
		for index = 0, 3 do
			local texture = _G[string.format(modele, index)]
			if texture then
				texture:SetAlpha(0)
			end
		end
	end

	for _, nom in ipairs({ "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "MainMenuBarExpText" }) do
		local region = _G[nom]
		if region then
			region:SetAlpha(0)
		end
	end

	if MainMenuBarPageNumber then
		MainMenuBarPageNumber:SetAlpha(1)
		MainMenuBarPageNumber:SetWidth(17)
		MainMenuBarPageNumber:SetHeight(10)
		MainMenuBarPageNumber:SetJustifyH("CENTER")
		MainMenuBarPageNumber:ClearAllPoints()
		MainMenuBarPageNumber:SetPoint("CENTER", page, "CENTER", -1, 0)
	end

	-- Les fleches de page : le client les habille avec ses propres images,
	-- camelot a les siennes dans le meme atlas que la barre.
	local fleches = {
		{ bouton = ActionBarUpButton, prefixe = "ui-hud-actionbar-pageuparrow", y = 10 },
		{ bouton = ActionBarDownButton, prefixe = "ui-hud-actionbar-pagedownarrow", y = -10 },
	}
	for _, entree in ipairs(fleches) do
		local bouton = entree.bouton
		if bouton and not bouton.foreverSkinned then
			ForeverUI.SetAtlas(bouton:GetNormalTexture(), entree.prefixe .. "-up")
			ForeverUI.SetAtlas(bouton:GetPushedTexture(), entree.prefixe .. "-down")
			ForeverUI.SetAtlas(bouton:GetHighlightTexture(), entree.prefixe .. "-mouseover")
			if bouton.GetDisabledTexture and bouton:GetDisabledTexture() then
				ForeverUI.SetAtlas(bouton:GetDisabledTexture(), entree.prefixe .. "-disabled")
			end
			bouton:SetWidth(17)
			bouton:SetHeight(14)
			bouton:ClearAllPoints()
			bouton:SetPoint("CENTER", page, "CENTER", 0, entree.y)
			bouton.foreverSkinned = true
		end
	end
end

local function skinAll()
	for _, prefix in ipairs(BARS) do
		for index = 1, BUTTON_COUNT do
			local button = _G[prefix .. index]
			skinButton(button)
			garderGrille(button)
		end
	end
	hideOldBarArt()
end

-- Le client reecrit la texture normale a chaque mise a jour de bouton : on
-- repasse derriere lui plutot que de lutter.
if hooksecurefunc then
	hooksecurefunc("ActionButton_Update", function(self)
		if self and self.foreverSkinned then
			silenceNormalTexture(self)
			garderGrille(self)
		end
	end)

	hooksecurefunc("ActionButton_ShowGrid", function(self)
		if self and self.foreverSkinned then
			silenceNormalTexture(self)
		end
	end)

	-- C'est ici que le bouton vide disparaissait.
	hooksecurefunc("ActionButton_HideGrid", function(self)
		if self and self.foreverSkinned then
			silenceNormalTexture(self)
			garderGrille(self)
		end
	end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
watcher:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
watcher:SetScript("OnEvent", function()
	skinAll()
	layoutButtons()
end)

skinAll()
layoutButtons()

ForeverUI.ActionBarDebug = function()
	local button = _G["ActionButton1"]
	if not button then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r : ActionButton1 introuvable")
		return
	end

	local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
	local normal = button:GetNormalTexture()
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r barre : bouton %.0fx%.0f | parent %s | ancre %s sur %s (%.0f, %.0f) | visible=%s | cadre=%s | normale alpha=%.2f",
		button:GetWidth(), button:GetHeight(),
		tostring(button:GetParent() and button:GetParent():GetName() or "?"),
		tostring(point), tostring(relativeTo and relativeTo:GetName() or "?"), x or 0, y or 0,
		tostring(button:IsShown()),
		tostring(button.foreverFrame and button.foreverFrame:GetTexture() or "aucun"),
		normal and normal:GetAlpha() or -1))
end

ForeverUI.ActionBarHolder = holder
ForeverUI.ActionBarBorder = border
ForeverUI.ActionBarPage = page
ForeverUI.ActionBarEndCaps = { left = leftCap, right = rightCap }
ForeverUI.ActionBarSkin = { skinButton = skinButton, skinAll = skinAll, layoutButtons = layoutButtons }
-- RELEVE -- camelot/EditModePresetLayoutConstants.lua : la barre se pose
-- BOTTOMRIGHT sur le BOTTOMLEFT du micro-menu, decalee de (-4.5, -4). Le
-- micro-menu etant lui-meme a BOTTOM (116.5, 6) et large de 275, cela met le
-- bord droit de la barre a -25.5 du centre de l'ecran, a 2 du bas.
-- BottomBar.lua refait ce calcul avec la largeur reelle du micro-menu.
ForeverUI.Layout.Register(holder, "actionbar", "Barre d'action", "BOTTOMRIGHT", "BOTTOM", -25.5, 2)
