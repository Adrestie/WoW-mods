-- Player unit frame. Geometry from Blizzard_UnitFrame/mainline/PlayerFrame.xml (camelot flavor).
-- The art sits above the square portrait and its ring covers the corners: 3.3.5 has no
-- MaskTexture to make the portrait round.
-- Position is decided and saved by ForeverUI.Layout (see Layout.lua).

local FRAME_WIDTH, FRAME_HEIGHT = 232, 100
local L = ForeverUI.L

local ART_NORMAL = "ui-hud-unitframe-player-portraiton"
-- Threat glow, not an alternate frame art: both clients pass this image to UnitFrame_Initialize
-- as threatIndicator (modern FrameFlash, 3.3.5 PlayerFrameFlash).
local THREAT_GLOW = "ui-hud-unitframe-player-portraiton-incombat"
local HEALTH_FILL = "ui-hud-unitframe-player-portraiton-bar-health"

-- The atlas has one fill per power type: it gives the color, nothing is tinted by hand.
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
-- The clickable area follows the art, not the frame: (232-198)/2 on each side.
frame:SetHitRectInsets(17, 17, 14, 15)

frame.unit = "player"
frame:SetAttribute("unit", "player")
frame:SetAttribute("*type1", "target")
-- 3.3.5 uses "menu", not "togglemenu" as recent clients do:
-- SecureActionButton_OnClick then calls self.menu.
frame:SetAttribute("*type2", "menu")
frame:RegisterForClicks("AnyUp")
frame.menu = function(self)
	ForeverUI.UnitMenu.open(ToggleDropDownMenu, 1, nil, PlayerFrameDropDown, self, 106, 27)
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

-- The level lives in a child frame one level up, not in a layer of the main frame. Textures
-- in one layer are ordered only by creation, and the art is re-set during play, which put it
-- in front of the circle. A child frame does not depend on that order.
local overlayHolder = CreateFrame("Frame", nil, frame)
overlayHolder:SetAllPoints(frame)
overlayHolder:SetFrameLevel(frame:GetFrameLevel() + 1)

local levelCircle = overlayHolder:CreateTexture(nil, "ARTWORK")
levelCircle:SetPoint("BOTTOMLEFT", 13, 7)
ForeverUI.SetAtlas(levelCircle, "ui-hud-unitframe-smallcircle")

local levelText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelText:SetPoint("CENTER", levelCircle, "CENTER", 0, 0)

-- ------------------------------------------------------------- Player states
-- Everything below lives in overlayHolder, above the art, sorted by layer: status veil at the
-- back, icons above, texts last. These textures are never re-set in play (only color and
-- alpha change), so their order cannot drift.

local STATUS_ATLAS = "ui-hud-unitframe-player-portraiton-status"
local COMBAT_ICON = "ui-hud-unitframe-player-combaticon"
local CORNER_ATLAS = "ui-hud-unitframe-player-portraiton-cornerembellishment"
local LEADER_ICON = "ui-hud-unitframe-player-group-leadericon"
local REST_ATLAS = "ui-hud-unitframe-player-rest-flipbook"

-- Rest sprite sheet: 7 rows of 6 cells, 42 frames played in 1.5 s. 3.3.5 has no FlipBook
-- animation, so OnUpdate moves the tex coords by hand.
local REST_COLUMNS, REST_ROWS, REST_FRAMES, REST_DURATION = 6, 7, 42, 1.5

-- ADD blend, as the 3.3.5 PlayerStatusTexture: the light adds up. A normal blend with a red
-- tint at half alpha washes the whole frame pink.
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

-- Unit shown by the frame: the vehicle while in one, as PlayerFrame_ToVehicleArt in 3.3.5.
-- The modern client also swaps the art for the vehicle variant, a few pixels wider.
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

-- The glow follows camelot's observed behavior, not UnitFrame_UpdateThreatIndicator (lit above
-- zero, tinted by GetThreatStatusColor): it is always red and only its alpha changes, faint
-- once engaged, full when an enemy targets you.
local THREAT_ALPHA_ENGAGED, THREAT_ALPHA_TARGETED = 0.45, 1.0

-- Being targeted cannot rely on the threat table alone: on a private server
-- UnitThreatSituation("player") often returns nil and UNIT_THREAT_SITUATION_UPDATE never
-- fires. So also check whether the hostile target targets us.
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

-- Player state, in the order of 3.3.5 PlayerFrame_UpdateStatus: nothing in a vehicle,
-- otherwise rest before combat.
local restElapsed = 0

local function updateStatus()
	if UnitHasVehicleUI and UnitHasVehicleUI("player") then
		statusTexture:Hide()
		combatIcon:Hide()
		restTexture:Hide()
		frame.resting = false
		return
	end

	-- The client separates two states that UnitAffectingCombat merges:
	--   inCombat   -- PLAYER_ENTER_COMBAT: you attack (right-click on an enemy).
	--                 Red veil and combat icon.
	--   onHateList -- PLAYER_REGEN_DISABLED: you are on someone's hate list. Icon only.
	-- The onHateList branch leaves the veil alone, as both clients do: it keeps its color until
	-- combat really ends.
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

-- Bar texts follow the game settings: playerStatusText "1" means always shown, and
-- statusTextPercentage picks a percentage or raw values. On hover they always show.
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

-- Some classes change the frame art: camelot switches to the "ClassResource" variant when a
-- class resource shows under the bars. normalAtlas: atlas used outside a vehicle.
ForeverUI.PlayerFrameSetArt = function(normalAtlas)
	if normalAtlas then
		ART_NORMAL = normalAtlas
		updateVehicleArt()
	end
end

-- /fui debug: prints what the client really returns, to tune the glow on observed values.
ForeverUI.PlayerFrameDebug = function()
	local status = UnitThreatSituation and UnitThreatSituation("player")
	local target = UnitExists("target") and UnitName("target") or L.PLAYERFRAME_DEBUG_NO_TARGET
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r " .. L.PLAYERFRAME_DEBUG,
		tostring(frame.inCombat), tostring(frame.onHateList), tostring(status), target,
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

-- One OnUpdate for two animations: the rest sprite sheet, and the status veil that pulses
-- like the original frame's.
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

	-- "Targeted" is read from the target, not from an event: re-check it three times per second
	-- while engaged.
	self.threatElapsed = (self.threatElapsed or 0) + elapsed
	if self.threatElapsed > 0.3 then
		self.threatElapsed = 0
		if frame.inCombat or frame.onHateList or threatGlow:IsShown() then
			ForeverUI.PlayerFrameUpdateThreat()
		end
	end
end)

-- The default frame is disabled, not just hidden: its own events (mounts, vehicles, group)
-- would show it again.
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
-- 3.3.5 has no UNIT_POWER: each power type has its own event.
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
ForeverUI.Layout.Register(frame, "playerframe", L.PLAYERFRAME_EDIT_LABEL, "TOPLEFT", "TOPLEFT", 10, -10)
