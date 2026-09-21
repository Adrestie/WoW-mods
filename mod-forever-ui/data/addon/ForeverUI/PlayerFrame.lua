-- ForeverUI : le cadre joueur.
--
-- GEOMETRIE. Reprise telle quelle de Blizzard_UnitFrame/mainline/PlayerFrame.xml
-- (la saveur [Family] que charge camelot) :
--     cadre        232 x 100
--     portrait      60 x 60  ancre TOPLEFT (24, -19)
--     art du cadre 198 x 71  centre
--     barre de vie 124 x 20  ancre TOPLEFT (85, -40)
--     barre de ress.124 x 10 ancre TOPLEFT (85, -61)
--     nom           96 x 12  ancre TOPLEFT (88, -27)
--     cercle niveau 39 x 39  ancre BOTTOMLEFT (13, 7)
--
-- L'art est pose au-dessus du portrait, comme dans l'original : le trou du
-- cadre est rond, le portrait est carre, et c'est l'anneau qui recouvre les
-- coins -- un client 3.3.5 n'a pas de MaskTexture pour faire autrement.
--
-- POSITION. Le cadre ne se pose pas lui-meme : il s'enregistre aupres de
-- ForeverUI.Layout, qui decide et retient. Voir Layout.lua.

local FRAME_WIDTH, FRAME_HEIGHT = 232, 100

local ART_NORMAL = "ui-hud-unitframe-player-portraiton"
-- "-incombat" n'est PAS un art de cadre de rechange : dans les deux clients,
-- cette image est passee a UnitFrame_Initialize en position threatIndicator
-- (FrameFlash cote moderne, PlayerFrameFlash en 3.3.5). C'est la lueur de
-- menace, montree seulement quand le joueur tient l'aggro, et teintee selon le
-- niveau de menace. L'art du cadre, lui, ne change jamais.
local THREAT_GLOW = "ui-hud-unitframe-player-portraiton-incombat"
local HEALTH_FILL = "ui-hud-unitframe-player-portraiton-bar-health"

-- L'atlas porte un remplissage distinct par type de ressource : c'est lui qui
-- donne la couleur, on ne teinte rien a la main.
local POWER_FILL = {
	MANA = "ui-hud-unitframe-player-portraiton-bar-mana",
	RAGE = "ui-hud-unitframe-player-portraiton-bar-rage",
	FOCUS = "ui-hud-unitframe-player-portraiton-bar-focus",
	ENERGY = "ui-hud-unitframe-player-portraiton-bar-energy",
	RUNIC_POWER = "ui-hud-unitframe-player-portraiton-bar-runicpower",
}

local frame = CreateFrame("Button", "ForeverUIPlayerFrame", UIParent, "SecureUnitButtonTemplate")
frame:SetWidth(FRAME_WIDTH)
frame:SetHeight(FRAME_HEIGHT)
frame:SetFrameStrata("LOW")
-- La zone cliquable suit l'art, pas le cadre : (232-198)/2 de chaque cote.
frame:SetHitRectInsets(17, 17, 14, 15)

frame.unit = "player"
frame:SetAttribute("unit", "player")
frame:SetAttribute("*type1", "target")
-- En 3.3.5 l'attribut vaut "menu", pas "togglemenu" comme sur les clients
-- recents : SecureActionButton_OnClick appelle alors self.menu.
frame:SetAttribute("*type2", "menu")
frame:RegisterForClicks("AnyUp")
frame.menu = function(self)
	ToggleDropDownMenu(1, nil, PlayerFrameDropDown, self, 106, 27)
end

local portrait = frame:CreateTexture(nil, "BACKGROUND")
portrait:SetWidth(60)
portrait:SetHeight(60)
portrait:SetPoint("TOPLEFT", 24, -19)

local healthFill = frame:CreateTexture(nil, "BORDER")
healthFill:SetPoint("TOPLEFT", 85, -40)

local powerFill = frame:CreateTexture(nil, "BORDER")
powerFill:SetPoint("TOPLEFT", 85, -61)

local art = frame:CreateTexture(nil, "ARTWORK")
art:SetPoint("CENTER", 0, 0)
ForeverUI.SetAtlas(art, ART_NORMAL)

local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetWidth(96)
nameText:SetHeight(12)
nameText:SetJustifyH("LEFT")
nameText:SetPoint("TOPLEFT", 88, -27)

-- Le niveau vit dans un cadre fils d'un niveau au-dessus, pas dans un calque
-- du cadre principal. Deux textures d'un meme calque ne sont ordonnees que par
-- leur ordre de creation, et l'art du cadre est re-affecte en cours de partie
-- (bascule combat) : il repassait alors devant le cercle, et seul un
-- rechargement remettait les choses dans l'ordre. Un cadre fils ne depend pas
-- de cet ordre.
local overlayHolder = CreateFrame("Frame", nil, frame)
overlayHolder:SetAllPoints(frame)
overlayHolder:SetFrameLevel(frame:GetFrameLevel() + 1)

local levelCircle = overlayHolder:CreateTexture(nil, "ARTWORK")
levelCircle:SetPoint("BOTTOMLEFT", 13, 7)
ForeverUI.SetAtlas(levelCircle, "ui-hud-unitframe-smallcircle")

local levelText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelText:SetPoint("CENTER", levelCircle, "CENTER", 0, 0)

-- ------------------------------------------------------------- etats du joueur
-- Tout ce qui suit vit dans overlayHolder, donc au-dessus de l'art, et chaque
-- element est range par calque : le voile d'etat en fond, les icones au-dessus,
-- les textes en dernier. Aucune de ces textures n'est reaffectee en jeu (on ne
-- change que couleur et transparence), donc l'ordre ne peut plus glisser.

local STATUS_ATLAS = "ui-hud-unitframe-player-portraiton-status"
local COMBAT_ICON = "ui-hud-unitframe-player-combaticon"
local CORNER_ATLAS = "ui-hud-unitframe-player-portraiton-cornerembellishment"
local LEADER_ICON = "ui-hud-unitframe-player-group-leadericon"
local REST_ATLAS = "ui-hud-unitframe-player-rest-flipbook"

-- Le repos est une planche d'images : 7 rangees de 6 vignettes, 42 en tout,
-- parcourues en 1,5 s. Le client 3.3.5 n'a pas d'animation FlipBook, donc on
-- deplace le rectangle a la main dans un OnUpdate.
local REST_COLUMNS, REST_ROWS, REST_FRAMES, REST_DURATION = 6, 7, 42, 1.5

-- Le voile est une image claire : melangee normalement, teintee en rouge et
-- posee a demi-transparence, elle delave tout le cadre en rose. Le client
-- 3.3.5 declare son propre voile en alphaMode="ADD" (PlayerStatusTexture), et
-- c'est bien ainsi qu'il faut le poser : la lumiere s'ajoute au lieu de laver.
local statusTexture = overlayHolder:CreateTexture(nil, "BACKGROUND")
statusTexture:SetPoint("TOPLEFT", 17, -14)
ForeverUI.SetAtlas(statusTexture, STATUS_ATLAS)
statusTexture:SetBlendMode("ADD")
statusTexture:Hide()

local threatGlow = overlayHolder:CreateTexture(nil, "BORDER")
threatGlow:SetPoint("CENTER", frame, "CENTER", -1.5, 1)
ForeverUI.SetAtlas(threatGlow, THREAT_GLOW)
threatGlow:Hide()

local cornerIcon = overlayHolder:CreateTexture(nil, "ARTWORK")
cornerIcon:SetPoint("TOPLEFT", 58, -53)
ForeverUI.SetAtlas(cornerIcon, CORNER_ATLAS)

local combatIcon = overlayHolder:CreateTexture(nil, "OVERLAY")
combatIcon:SetPoint("TOPLEFT", 64, -62)
ForeverUI.SetAtlas(combatIcon, COMBAT_ICON)
combatIcon:Hide()

local leaderIcon = overlayHolder:CreateTexture(nil, "OVERLAY")
leaderIcon:SetPoint("TOPLEFT", 86, -10)
ForeverUI.SetAtlas(leaderIcon, LEADER_ICON)
leaderIcon:Hide()

local restTexture = overlayHolder:CreateTexture(nil, "OVERLAY")
restTexture:SetPoint("TOPLEFT", 59, -1)
restTexture:SetWidth(30)
restTexture:SetHeight(30)
restTexture:Hide()

local healthText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
healthText:SetPoint("CENTER", frame, "TOPLEFT", 85 + 62, -40 - 10)
healthText:Hide()

local powerText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
powerText:SetPoint("CENTER", frame, "TOPLEFT", 85 + 62, -61 - 5)
powerText:Hide()

frame.overlayHolder = overlayHolder
frame.portrait = portrait
frame.healthFill = healthFill
frame.powerFill = powerFill
frame.art = art
frame.threatGlow = threatGlow
frame.nameText = nameText
frame.levelText = levelText
frame.statusTexture = statusTexture
frame.combatIcon = combatIcon
frame.cornerIcon = cornerIcon
frame.leaderIcon = leaderIcon
frame.restTexture = restTexture
frame.healthText = healthText
frame.powerText = powerText

local VEHICLE_ART = "ui-hud-unitframe-player-portraiton-vehicle"
local VEHICLE_HEALTH_WIDTH = 118

-- En vehicule, le cadre du joueur montre le vehicule : c'est ce que fait
-- PlayerFrame_ToVehicleArt en 3.3.5, et le moderne echange en plus l'art du
-- cadre pour la variante vehicule, plus large de quelques pixels.
local function displayedUnit()
	return frame.displayUnit or "player"
end

local function updateVehicleArt()
	local inVehicle = (UnitHasVehicleUI and UnitHasVehicleUI("player") and UnitExists("vehicle")) and true or false
	frame.inVehicle = inVehicle
	frame.displayUnit = inVehicle and "vehicle" or "player"

	art:ClearAllPoints()
	if inVehicle then
		ForeverUI.SetAtlas(art, VEHICLE_ART)
		art:SetPoint("CENTER", -2, 0)
	else
		ForeverUI.SetAtlas(art, ART_NORMAL)
		art:SetPoint("CENTER", 0, 0)
	end
end

local function updateHealth()
	local unit = displayedUnit()
	local maximum = UnitHealthMax(unit)
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitHealth(unit) / maximum
	end
	ForeverUI.SetAtlasFill(healthFill, HEALTH_FILL, fraction,
		frame.inVehicle and VEHICLE_HEALTH_WIDTH or nil)
end

local function updatePower()
	local unit = displayedUnit()
	local powerType, powerToken = UnitPowerType(unit)
	local atlas = POWER_FILL[powerToken or ""] or POWER_FILL.MANA
	local maximum = UnitPowerMax(unit, powerType)
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitPower(unit, powerType) / maximum
	end
	ForeverUI.SetAtlasFill(powerFill, atlas, fraction,
		frame.inVehicle and VEHICLE_HEALTH_WIDTH or nil)
end

local function updateName()
	nameText:SetText(UnitName(displayedUnit()))
end

local function updateLevel()
	levelText:SetText(UnitLevel("player"))
end

local function updatePortrait()
	SetPortraitTexture(portrait, displayedUnit())
end

-- La lueur suit le comportement observe sur camelot, et non la lettre de
-- UnitFrame_UpdateThreatIndicator : le client de reference n'allume la lueur
-- qu'au-dessus de zero et la teinte par GetThreatStatusColor, alors qu'en jeu
-- la lueur est rouge dans les deux cas et ne change que d'intensite --
-- discrete des l'engagement, franche quand un ennemi vous prend pour cible.
-- Les deux niveaux sont ici, a regler d'un chiffre si besoin.
local THREAT_ALPHA_ENGAGED, THREAT_ALPHA_TARGETED = 0.45, 1.0

-- Etre pris pour cible ne peut pas reposer sur la seule table de menace : sur
-- un serveur prive, UnitThreatSituation("player") renvoie souvent rien et
-- UNIT_THREAT_SITUATION_UPDATE ne part jamais. On regarde donc aussi, tout
-- simplement, si l'ennemi en face nous vise.
local function playerIsTargeted()
	local status = UnitThreatSituation and UnitThreatSituation("player")
	if status and status >= 2 then
		return true
	end

	if UnitExists("target") and UnitCanAttack("player", "target")
			and UnitIsUnit("targettarget", "player") then
		return true
	end

	return false
end

local updateThreat
updateThreat = function()
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
		threatGlow:Hide()
		return
	end

	local status = UnitThreatSituation and UnitThreatSituation("player")
	local targeted = playerIsTargeted()
	local engaged = frame.inCombat or frame.onHateList or (status and status > 0)

	if targeted or engaged then
		threatGlow:SetVertexColor(1.0, 0.0, 0.0)
		threatGlow:SetAlpha(targeted and THREAT_ALPHA_TARGETED or THREAT_ALPHA_ENGAGED)
		threatGlow:Show()
	else
		threatGlow:Hide()
	end
end

-- L'ETAT DU JOUEUR, dans l'ordre que le client 3.3.5 applique lui-meme
-- (PlayerFrame_UpdateStatus) : en vehicule rien ne s'affiche, sinon le repos
-- passe avant le combat.
local restElapsed = 0

local function updateStatus()
	if UnitHasVehicleUI and UnitHasVehicleUI("player") then
		statusTexture:Hide()
		combatIcon:Hide()
		restTexture:Hide()
		frame.resting = false
		return
	end

	-- Le client distingue deux choses que UnitAffectingCombat confond :
	--   inCombat   -- PLAYER_ENTER_COMBAT : vous frappez, des le clic droit sur
	--                 un ennemi. Voile rouge et icone de combat, immediatement.
	--   onHateList -- PLAYER_REGEN_DISABLED : quelqu'un vous a sur sa liste de
	--                 haine. L'icone seule.
	-- Le voile n'est pas touche dans la branche onHateList, exactement comme
	-- dans les deux clients : il garde sa couleur tant que le combat dure et ne
	-- s'eteint qu'une fois vraiment sorti.
	if IsResting() then
		statusTexture:SetVertexColor(1.0, 0.88, 0.25)
		statusTexture:Show()
		restTexture:Show()
		combatIcon:Hide()
		cornerIcon:Show()
		frame.resting = true
		restElapsed = 0
	elseif frame.inCombat then
		statusTexture:SetVertexColor(1.0, 0.0, 0.0)
		statusTexture:Show()
		combatIcon:Show()
		cornerIcon:Hide()
		restTexture:Hide()
		frame.resting = false
	elseif frame.onHateList then
		combatIcon:Show()
		cornerIcon:Hide()
		restTexture:Hide()
		frame.resting = false
	else
		statusTexture:Hide()
		combatIcon:Hide()
		cornerIcon:Show()
		restTexture:Hide()
		frame.resting = false
	end
end

local function updateLeader()
	if IsPartyLeader and IsPartyLeader() then
		leaderIcon:Show()
	else
		leaderIcon:Hide()
	end
end

-- Le texte des barres suit le reglage du jeu plutot qu'un reglage a nous :
-- playerStatusText a "1" veut dire "toujours affiche", et statusTextPercentage
-- decide entre un pourcentage et les valeurs brutes. Au survol, il s'affiche
-- quel que soit le reglage.
local function formatValue(value, maximum)
	if not maximum or maximum <= 0 then
		return ""
	end
	if GetCVarBool and GetCVarBool("statusTextPercentage") then
		return tostring(math.ceil(value / maximum * 100)) .. "%"
	end
	return value .. " / " .. maximum
end

local function updateTexts()
	local always = GetCVar and GetCVar("playerStatusText") == "1"
	if not (always or frame.hovered) then
		healthText:Hide()
		powerText:Hide()
		return
	end

	local powerType = UnitPowerType("player")
	healthText:SetText(formatValue(UnitHealth("player"), UnitHealthMax("player")))
	powerText:SetText(formatValue(UnitPower("player", powerType), UnitPowerMax("player", powerType)))
	healthText:Show()
	powerText:Show()
end

ForeverUI.PlayerFrameUpdateThreat = function() updateThreat() end

-- Certaines classes changent l'art du cadre : camelot passe a la variante
-- "ClassResource" quand une ressource de classe s'affiche sous les barres.
ForeverUI.PlayerFrameSetArt = function(normalAtlas)
	if normalAtlas then
		ART_NORMAL = normalAtlas
		updateVehicleArt()
	end
end

-- /fui debug : ce que le client repond vraiment, pour regler la lueur sur des
-- valeurs constatees plutot que supposees.
ForeverUI.PlayerFrameDebug = function()
	local status = UnitThreatSituation and UnitThreatSituation("player")
	local cible = UnitExists("target") and UnitName("target") or "aucune"
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r etat : frappe=%s liste_haine=%s menace=%s cible=%s hostile=%s me_vise=%s lueur=%s alpha=%.2f",
		tostring(frame.inCombat), tostring(frame.onHateList), tostring(status), cible,
		tostring(UnitExists("target") and UnitCanAttack("player", "target") or false),
		tostring(UnitIsUnit("targettarget", "player")),
		tostring(threatGlow:IsShown()), threatGlow:GetAlpha()))
end

frame:SetScript("OnEnter", function(self)
	self.hovered = true
	updateTexts()
end)

frame:SetScript("OnLeave", function(self)
	self.hovered = false
	updateTexts()
end)

-- Deux animations, un seul OnUpdate : le sommeil parcourt sa planche d'images,
-- et le voile d'etat respire comme le fait celui du cadre d'origine.
ForeverUI.SetAtlas(restTexture, REST_ATLAS, true)

frame:SetScript("OnUpdate", function(self, elapsed)
	if self.resting then
		restElapsed = restElapsed + elapsed
		local entry = ForeverUI.AtlasEntry(REST_ATLAS)
		if entry then
			local index = math.floor(restElapsed / (REST_DURATION / REST_FRAMES)) % REST_FRAMES
			local column = index - math.floor(index / REST_COLUMNS) * REST_COLUMNS
			local row = math.floor(index / REST_COLUMNS)
			local du = (entry[3] - entry[2]) / REST_COLUMNS
			local dv = (entry[5] - entry[4]) / REST_ROWS
			restTexture:SetTexCoord(entry[2] + column * du, entry[2] + (column + 1) * du,
				entry[4] + row * dv, entry[4] + (row + 1) * dv)
		end
	end

	if statusTexture:IsShown() then
		local pulse = 0.35 + 0.25 * math.sin(GetTime() * 3)
		statusTexture:SetAlpha(pulse)
	end

	-- La bascule "on me vise" se lit sur la cible, pas sur un evenement :
	-- on la relit trois fois par seconde tant que le joueur est engage.
	self.threatElapsed = (self.threatElapsed or 0) + elapsed
	if self.threatElapsed > 0.3 then
		self.threatElapsed = 0
		if frame.inCombat or frame.onHateList or threatGlow:IsShown() then
			ForeverUI.PlayerFrameUpdateThreat()
		end
	end
end)

-- Le cadre d'origine est desactive plutot que simplement masque : sans cela
-- ses propres evenements le reafficheraient (montures, vehicules, groupe).
local function hideDefaultPlayerFrame()
	if InCombatLockdown() or not PlayerFrame then
		return
	end
	ForeverUI.Suppress(PlayerFrame)
end

local function updateAll()
	updateVehicleArt()
	updateHealth()
	updatePower()
	updateName()
	updateLevel()
	updatePortrait()
	updateThreat()
	updateStatus()
	updateLeader()
	updateTexts()
end

frame:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_ENTERING_WORLD" then
		self.onHateList = UnitAffectingCombat("player")
		hideDefaultPlayerFrame()
		updateAll()
		return
	end

	if event == "PLAYER_ENTER_COMBAT" then
		self.inCombat = true
		updateStatus()
		updateThreat()
		return
	end

	if event == "PLAYER_LEAVE_COMBAT" then
		self.inCombat = false
		updateStatus()
		updateThreat()
		return
	end

	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		self.onHateList = (event == "PLAYER_REGEN_DISABLED")
		updateStatus()
		updateThreat()
		return
	end

	if event == "UNIT_THREAT_SITUATION_UPDATE" or event == "PLAYER_TARGET_CHANGED"
			or event == "UNIT_TARGET" then
		updateThreat()
		return
	end

	if event == "PLAYER_UPDATE_RESTING" then
		updateStatus()
		return
	end

	if event == "PARTY_LEADER_CHANGED" or event == "PARTY_MEMBERS_CHANGED" then
		updateLeader()
		return
	end

	if event == "CVAR_UPDATE" then
		updateTexts()
		return
	end

	if event == "PLAYER_LEVEL_UP" then
		updateLevel()
		return
	end

	if unit ~= "player" then
		return
	end

	if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
		updateVehicleArt()
		updateHealth()
		updatePower()
		updateName()
		updatePortrait()
		updateStatus()
	elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		updateHealth()
		updateTexts()
	elseif event == "UNIT_NAME_UPDATE" then
		updateName()
	elseif event == "UNIT_PORTRAIT_UPDATE" then
		updatePortrait()
	elseif event == "UNIT_LEVEL" then
		updateLevel()
	else
		updatePower()
		updateTexts()
	end
end)

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_ENTER_COMBAT")
frame:RegisterEvent("PLAYER_LEAVE_COMBAT")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")
frame:RegisterEvent("UNIT_NAME_UPDATE")
frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
frame:RegisterEvent("UNIT_LEVEL")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
-- 3.3.5 n'a pas UNIT_POWER : chaque ressource a son propre evenement.
frame:RegisterEvent("UNIT_MANA")
frame:RegisterEvent("UNIT_RAGE")
frame:RegisterEvent("UNIT_FOCUS")
frame:RegisterEvent("UNIT_ENERGY")
frame:RegisterEvent("UNIT_RUNIC_POWER")
frame:RegisterEvent("UNIT_MAXMANA")
frame:RegisterEvent("UNIT_MAXRAGE")
frame:RegisterEvent("UNIT_MAXFOCUS")
frame:RegisterEvent("UNIT_MAXENERGY")
frame:RegisterEvent("UNIT_MAXRUNIC_POWER")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PARTY_LEADER_CHANGED")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("UNIT_ENTERED_VEHICLE")
frame:RegisterEvent("UNIT_EXITED_VEHICLE")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_TARGET")

ForeverUI.PlayerFrame = frame
ForeverUI.Layout.Register(frame, "playerframe", "Cadre joueur", "TOPLEFT", "TOPLEFT", 10, -10)
