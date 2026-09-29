-- Target frame and target-of-target frame, rebuilt from camelot.
-- Sizes and anchors: mainline/TargetFrame.xml; bars and art: CheckClassification in
-- mainline/TargetFrame.lua; name, level and reaction color: camelot/TargetFrame.lua
-- (TargetFrameMixin:OnLoad, CheckFaction).

local FRAME_WIDTH, FRAME_HEIGHT = 232, 100
local L = ForeverUI.L

local ART = {
	normal = "ui-hud-unitframe-target-portraiton",
	rare = "ui-hud-unitframe-target-rare-portraiton",
	minus = "ui-hud-unitframe-target-minusmob-portraiton",
}
local THREAT_GLOW = {
	normal = "ui-hud-unitframe-target-portraiton-incombat",
	minus = "ui-hud-unitframe-target-minusmob-portraiton-incombat",
}
local HEALTH_FILL = {
	normal = "ui-hud-unitframe-target-portraiton-bar-health",
	minus = "ui-hud-unitframe-target-minusmob-portraiton-bar-health",
}

-- Bar geometry set by CheckClassification (in code, not XML, on every target change):
-- health 126 x 20 at TOPLEFT (23, -40), power 134 x 10 at (23, -61); minus mobs: health
-- 125 x 12 at (23, -39) and no power bar.
local BAR_LAYOUT = {
	normal = { health = { 23, -40, 126, 20 }, power = { 23, -61, 134, 10 }, showPower = true },
	minus = { health = { 23, -39, 125, 12 }, power = nil, showPower = false },
}
local POWER_FILL = {
	normal = {
		MANA = "ui-hud-unitframe-target-portraiton-bar-mana",
		RAGE = "ui-hud-unitframe-target-portraiton-bar-rage",
		FOCUS = "ui-hud-unitframe-target-portraiton-bar-focus",
		ENERGY = "ui-hud-unitframe-target-portraiton-bar-energy",
		RUNIC_POWER = "ui-hud-unitframe-target-portraiton-bar-runicpower",
	},
	minus = {
		MANA = "ui-hud-unitframe-target-minusmob-portraiton-bar-mana",
		RAGE = "ui-hud-unitframe-target-minusmob-portraiton-bar-rage",
		FOCUS = "ui-hud-unitframe-target-minusmob-portraiton-bar-focus",
		ENERGY = "ui-hud-unitframe-target-minusmob-portraiton-bar-energy",
		RUNIC_POWER = "ui-hud-unitframe-target-minusmob-portraiton-bar-runicpower",
	},
}

-- Portrait ring by classification (camelot GetBossPortraitFrameData): gold for elite,
-- silver winged for rare and rare elite, gold winged for world boss, anchored TOPRIGHT with
-- these offsets; no star (ShouldShowStar is always false). Sheet: interface/hud/uiunitframeboss.blp.
-- Boss-Rare-Silver-Winged exists only as c60, so camelot uses the c60 set. The base
-- variants are smaller (80x79 vs 100x100) and, anchored by their top-right, land off.
local CLASS_RING = {
	worldboss = { "ui-hud-unitframe-target-portraiton-boss-gold-winged-c60", 11, -4 },
	rareelite = { "ui-hud-unitframe-target-portraiton-boss-rare-silver-winged-c60", 8, -7 },
	rare = { "ui-hud-unitframe-target-portraiton-boss-rare-silver-winged-c60", 8, -7 },
	elite = { "ui-hud-unitframe-target-portraiton-boss-gold-c60", 0, 1 },
}

local frame = CreateFrame("Button", "ForeverUITargetFrame", UIParent, "SecureUnitButtonTemplate")
frame:SetWidth(FRAME_WIDTH)
frame:SetHeight(FRAME_HEIGHT)
frame:SetFrameStrata("LOW")
frame:SetHitRectInsets(20, 20, 16, 17)

frame.unit = "target"
frame:SetAttribute("unit", "target")
frame:SetAttribute("*type1", "target")
frame:SetAttribute("*type2", "menu")
frame:RegisterForClicks("AnyUp")
frame.menu = function(self)
	ForeverUI.UnitMenu.open(ToggleDropDownMenu, 1, nil, TargetFrameDropDown, self, 120, 10)
end

local portrait = frame:CreateTexture(nil, "BACKGROUND")
portrait:SetWidth(58)
portrait:SetHeight(58)
portrait:SetPoint("TOPRIGHT", -26, -19)

local healthFill = frame:CreateTexture(nil, "BORDER")
healthFill:SetPoint("TOPLEFT", 23, -39)

local powerFill = frame:CreateTexture(nil, "BORDER")
powerFill:SetPoint("TOPLEFT", 23, -60)

local art = frame:CreateTexture(nil, "ARTWORK")
art:SetPoint("CENTER", 0, 0)
ForeverUI.SetAtlas(art, ART.normal)

-- Reputation band: it carries the reaction color, not the health bar.
local reputation = frame:CreateTexture(nil, "BACKGROUND")
reputation:SetPoint("TOPRIGHT", -75, -25)
ForeverUI.SetAtlas(reputation, "ui-hud-unitframe-target-portraiton-type")

-- As on the player frame: whatever must stay above the art lives in a child frame, never
-- in the same layer.
local overlayHolder = CreateFrame("Frame", nil, frame)
overlayHolder:SetAllPoints(frame)
overlayHolder:SetFrameLevel(frame:GetFrameLevel() + 1)

local threatGlow = overlayHolder:CreateTexture(nil, "BACKGROUND")
threatGlow:SetPoint("CENTER", frame, "CENTER", 1.5, 1)
ForeverUI.SetAtlas(threatGlow, THREAT_GLOW.normal)
threatGlow:Hide()

-- Ring: GetBossPortraitFrameData anchors it TOPRIGHT on the container. The source puts it
-- in ARTWORK sublevel 2, above the frame art and threat glow but below the bars, name and
-- level circle. Here: BORDER of the holder, above the glow (BACKGROUND) and below the level
-- circle (ARTWORK) and the text (OVERLAY).
local classRing = overlayHolder:CreateTexture(nil, "BORDER")
classRing:Hide()

local levelCircle = overlayHolder:CreateTexture(nil, "ARTWORK")
levelCircle:SetPoint("BOTTOMRIGHT", -13, 7)
ForeverUI.SetAtlas(levelCircle, "ui-hud-unitframe-smallcircle")

local levelText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelText:SetPoint("CENTER", levelCircle, "CENTER", 0, -0.5)

local nameText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetWidth(117)
nameText:SetHeight(12)
nameText:SetJustifyH("LEFT")
nameText:SetPoint("TOPLEFT", 24, -26)

local healthText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
healthText:SetPoint("CENTER", frame, "TOPLEFT", 23 + 63, -40 - 10)
healthText:Hide()

local powerText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
powerText:SetPoint("CENTER", frame, "TOPLEFT", 23 + 67, -61 - 5)
powerText:Hide()

frame.portrait = portrait
frame.healthFill = healthFill
frame.powerFill = powerFill
frame.art = art
frame.threatGlow = threatGlow
frame.classRing = classRing
frame.reputation = reputation
frame.nameText = nameText
frame.levelText = levelText
frame.healthText = healthText
frame.powerText = powerText
frame.overlayHolder = overlayHolder

-- Target classification. It picks two separate things: the frame art family (normal, rare,
-- minus) and the portrait ring (elite, rare, boss).
local function classification()
	return (UnitClassification and UnitClassification("target")) or "normal"
end

local function artKindFor(class)
	if class == "minus" then
		return "minus"
	end
	if class == "rare" or class == "rareelite" then
		return "rare"
	end
	return "normal"
end

-- camelot CheckFaction: the band takes the selection color; band and portrait turn grey
-- when the target is tapped by someone else. 3.3.5 has no UnitIsTapDenied, so this uses
-- UnitIsTapped and UnitIsTappedByPlayer.
local function updateFaction()
	local tapDenied = UnitIsTapped and UnitIsTapped("target")
		and not UnitIsTappedByPlayer("target") and not UnitPlayerControlled("target")

	if tapDenied then
		reputation:SetVertexColor(0.5, 0.5, 0.5)
		portrait:SetVertexColor(0.5, 0.5, 0.5)
	else
		if UnitSelectionColor then
			reputation:SetVertexColor(UnitSelectionColor("target"))
		end
		portrait:SetVertexColor(1.0, 1.0, 1.0)
	end
end

-- Copy of TargetFrameMixin:CheckClassification: art, glow, and the bars' size and
-- position, which it sets again every time.
local function updateArt()
	local class = classification()
	local artKind = artKindFor(class)
	local barKind = (artKind == "minus") and "minus" or "normal"
	local layout = BAR_LAYOUT[barKind]

	ForeverUI.SetAtlas(art, ART[artKind] or ART.normal)
	ForeverUI.SetAtlas(threatGlow, THREAT_GLOW[barKind] or THREAT_GLOW.normal)

	healthFill:ClearAllPoints()
	healthFill:SetPoint("TOPLEFT", layout.health[1], layout.health[2])

	if layout.showPower then
		powerFill:ClearAllPoints()
		powerFill:SetPoint("TOPLEFT", layout.power[1], layout.power[2])
		powerFill:Show()
		powerText:Show()
	else
		powerFill:Hide()
		powerText:Hide()
	end

	frame.barKind = barKind
	frame.classification = class
	frame.layout = layout

	local ring = CLASS_RING[class]
	if ring and ForeverUI.SetAtlas(classRing, ring[1]) then
		classRing:ClearAllPoints()
		classRing:SetPoint("TOPRIGHT", frame, "TOPRIGHT", ring[2], ring[3])
		classRing:Show()
	else
		classRing:Hide()
	end
end

local function updateHealth()
	local maximum = UnitHealthMax("target")
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitHealth("target") / maximum
	end
	local layout = frame.layout or BAR_LAYOUT.normal
	ForeverUI.SetAtlasFill(healthFill, HEALTH_FILL[frame.barKind or "normal"], fraction, layout.health[3])
end

local function updatePower()
	local layout = frame.layout or BAR_LAYOUT.normal
	if not layout.showPower then
		powerFill:Hide()
		return
	end

	local powerType, powerToken = UnitPowerType("target")
	local set = POWER_FILL[frame.barKind or "normal"]
	local atlas = set[powerToken or ""] or set.MANA
	local maximum = UnitPowerMax("target", powerType)
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitPower("target", powerType) / maximum
	end
	ForeverUI.SetAtlasFill(powerFill, atlas, fraction, layout.power[3])
end

-- Health and power texts: shown with the targetStatusText CVar or on hover.
local function updateTexts()
	local always = GetCVar and GetCVar("targetStatusText") == "1"
	if not (always or frame.hovered) then
		healthText:Hide()
		powerText:Hide()
		return
	end

	local function format(value, maximum)
		if not maximum or maximum <= 0 then
			return ""
		end
		if GetCVarBool and GetCVarBool("statusTextPercentage") then
			return tostring(math.ceil(value / maximum * 100)) .. "%"
		end
		return value .. " / " .. maximum
	end

	local powerType = UnitPowerType("target")
	healthText:SetText(format(UnitHealth("target"), UnitHealthMax("target")))
	powerText:SetText(format(UnitPower("target", powerType), UnitPowerMax("target", powerType)))
	healthText:Show()
	powerText:Show()
end

local function updateName()
	nameText:SetText(UnitName("target"))
end

local function updateLevel()
	local level = UnitLevel("target")
	if level and level > 0 then
		levelText:SetText(level)
	else
		levelText:SetText("??")
	end
end

local function updatePortrait()
	SetPortraitTexture(portrait, "target")
end

-- Threat: whether the target holds aggro on someone. Falls back on UnitAffectingCombat,
-- like the player frame, since threat data is not guaranteed.
local function updateThreat()
	if not UnitExists("target") then
		threatGlow:Hide()
		return
	end

	local status = UnitThreatSituation and UnitThreatSituation("target")
	local engaged = UnitAffectingCombat("target")

	if status and status >= 2 then
		threatGlow:SetVertexColor(1.0, 0.0, 0.0)
		threatGlow:SetAlpha(1.0)
		threatGlow:Show()
	elseif engaged or (status and status > 0) then
		threatGlow:SetVertexColor(1.0, 0.0, 0.0)
		threatGlow:SetAlpha(0.45)
		threatGlow:Show()
	else
		threatGlow:Hide()
	end
end

local function updateAll()
	if not UnitExists("target") then
		return
	end
	updateArt()
	updateFaction()
	updateHealth()
	updatePower()
	updateName()
	updateLevel()
	updatePortrait()
	updateThreat()
	updateTexts()
end

local function hideDefaultTargetFrame()
	if InCombatLockdown() or not TargetFrame then
		return
	end
	ForeverUI.Suppress(TargetFrame)
	ForeverUI.Suppress(ComboFrame)
end

frame:SetScript("OnEnter", function(self)
	self.hovered = true
	updateTexts()
end)

frame:SetScript("OnLeave", function(self)
	self.hovered = false
	updateTexts()
end)

frame:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_ENTERING_WORLD" then
		hideDefaultTargetFrame()
		updateAll()
		return
	end

	if event == "PLAYER_TARGET_CHANGED" then
		updateAll()
		return
	end

	if event == "CVAR_UPDATE" then
		updateTexts()
		return
	end

	if unit ~= "target" then
		return
	end

	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		updateHealth()
		updateTexts()
	elseif event == "UNIT_NAME_UPDATE" then
		updateName()
	elseif event == "UNIT_PORTRAIT_UPDATE" then
		updatePortrait()
	elseif event == "UNIT_LEVEL" then
		updateLevel()
	elseif event == "UNIT_CLASSIFICATION_CHANGED" then
		updateArt()
		updateHealth()
		updatePower()
	elseif event == "UNIT_FACTION" then
		updateFaction()
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
		updateThreat()
	else
		updatePower()
		updateTexts()
	end
end)

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")
frame:RegisterEvent("UNIT_NAME_UPDATE")
frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
frame:RegisterEvent("UNIT_LEVEL")
frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
frame:RegisterEvent("UNIT_FACTION")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
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

-- The frame exists only with a target: the client shows and hides it, like any secure
-- unit frame.
if RegisterUnitWatch then
	RegisterUnitWatch(frame)
end


-- ------------------------------------------------- Target of target
-- mainline/TargetFrame.xml TargetofTargetFrameTemplate: 120 x 49, TOPRIGHT on the target
-- frame's BOTTOMRIGHT at (12, 10), portrait 37 x 37 at (5, -5), name right of the portrait,
-- health bar 70 x 10 BOTTOMRIGHT on the RIGHT point at (-6, -2.5), i.e. TOPLEFT (44, -17).

local tot = CreateFrame("Button", "ForeverUITargetOfTarget", frame, "SecureUnitButtonTemplate")
tot:SetWidth(120)
tot:SetHeight(49)
tot:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 12, 10)
tot:SetAttribute("unit", "targettarget")
tot:SetAttribute("*type1", "target")
tot:RegisterForClicks("AnyUp")
tot.unit = "targettarget"

local totPortrait = tot:CreateTexture(nil, "BACKGROUND")
totPortrait:SetWidth(37)
totPortrait:SetHeight(37)
totPortrait:SetPoint("TOPLEFT", 5, -5)

local totHealth = tot:CreateTexture(nil, "BORDER")
totHealth:SetPoint("TOPLEFT", 44, -17)

local totPower = tot:CreateTexture(nil, "BORDER")
totPower:SetPoint("TOPLEFT", 44, -29)

local totArt = tot:CreateTexture(nil, "ARTWORK")
totArt:SetPoint("CENTER")
ForeverUI.SetAtlas(totArt, "ui-hud-unitframe-targetoftarget-portraiton")

local totName = tot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
totName:SetWidth(68)
totName:SetHeight(10)
totName:SetJustifyH("LEFT")
totName:SetPoint("TOPLEFT", totPortrait, "TOPRIGHT", 2, 0)

local TOT_POWER = {
	MANA = "ui-hud-unitframe-targetoftarget-portraiton-bar-mana",
	RAGE = "ui-hud-unitframe-targetoftarget-portraiton-bar-rage",
	FOCUS = "ui-hud-unitframe-targetoftarget-portraiton-bar-focus",
	ENERGY = "ui-hud-unitframe-targetoftarget-portraiton-bar-energy",
	RUNIC_POWER = "ui-hud-unitframe-targetoftarget-portraiton-bar-runicpower",
}

local function updateTargetOfTarget()
	if not UnitExists("targettarget") then
		return
	end

	local maximum = UnitHealthMax("targettarget")
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitHealth("targettarget") / maximum
	end
	ForeverUI.SetAtlasFill(totHealth, "ui-hud-unitframe-targetoftarget-portraiton-bar-health", fraction)

	local powerType, powerToken = UnitPowerType("targettarget")
	local powerMax = UnitPowerMax("targettarget", powerType)
	local powerFraction = 0
	if powerMax and powerMax > 0 then
		powerFraction = UnitPower("targettarget", powerType) / powerMax
	end
	ForeverUI.SetAtlasFill(totPower, TOT_POWER[powerToken or ""] or TOT_POWER.MANA, powerFraction)

	totName:SetText(UnitName("targettarget"))
	SetPortraitTexture(totPortrait, "targettarget")
end

tot:SetScript("OnEvent", function(_self, event, unit)
	if event == "PLAYER_TARGET_CHANGED" or unit == "target" or unit == "targettarget" then
		updateTargetOfTarget()
	end
end)

tot:RegisterEvent("PLAYER_TARGET_CHANGED")
tot:RegisterEvent("UNIT_TARGET")
tot:RegisterEvent("UNIT_HEALTH")
tot:RegisterEvent("UNIT_MAXHEALTH")

if RegisterUnitWatch then
	RegisterUnitWatch(tot)
end

tot.portrait = totPortrait
tot.healthFill = totHealth
tot.powerFill = totPower
tot.art = totArt
tot.nameText = totName

ForeverUI.TargetFrame = frame
ForeverUI.Layout.Register(frame, "targetframe", L.TARGETFRAME_EDIT_LABEL, "TOPLEFT", "TOPLEFT", 250, -10)
