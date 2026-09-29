-- ForeverUI: the pet frame, from Camelot's mainline PetFrame template. The 3.3.5 PetFrame is a
-- child of PlayerFrame, so it goes away with the client's player frame (see PlayerFrame.lua).
-- It uses the target-of-target art on purpose. 3.3.5 has no MaskTexture, so the bars are not
-- clipped to the frame shape. The debuff icons under the frame are left out; buffs stay in the
-- tooltip.

local player = ForeverUI.PlayerFrame

local FRAME_ART = "ui-hud-unitframe-targetoftarget-portraiton"
local THREAT_ART = "ui-hud-unitframe-targetoftarget-portraiton-incombat"
local ATTACK_ART = "ui-hud-unitframe-targetoftarget-portraiton-status"
local HEALTH_FILL = "ui-hud-unitframe-targetoftarget-portraiton-bar-health"
local POWER_FILL = {
	MANA = "ui-hud-unitframe-targetoftarget-portraiton-bar-mana",
	RAGE = "ui-hud-unitframe-targetoftarget-portraiton-bar-rage",
	FOCUS = "ui-hud-unitframe-targetoftarget-portraiton-bar-focus",
	ENERGY = "ui-hud-unitframe-targetoftarget-portraiton-bar-energy",
	RUNIC_POWER = "ui-hud-unitframe-targetoftarget-portraiton-bar-runicpower",
}
local HAPPINESS_FILE = "Interface\\PetPaperDollFrame\\UI-PetHappiness"
local HAPPINESS_COORDS = {
	[1] = { 0.375, 0.5625, 0, 0.359375 },
	[2] = { 0.1875, 0.375, 0, 0.359375 },
	[3] = { 0, 0.1875, 0, 0.359375 },
}

local frame = CreateFrame("Button", "ForeverUIPetFrame", player, "SecureUnitButtonTemplate")
frame:SetWidth(120)
frame:SetHeight(49)
frame:SetFrameStrata("LOW")
frame:SetHitRectInsets(7, 66, 6, 7)

-- Below the runes if any (their container already sits where Camelot's does), 2 apart;
-- otherwise where Camelot's PlayerBottomManagedFrameContainer is, (30, 25), plus 7.5 for the
-- pet's 15 left margin
local runes = _G.ForeverUIClassResourceContainer
if runes then
	frame:SetPoint("TOP", runes, "BOTTOM", 7.5, -2)
else
	frame:SetPoint("TOP", player, "BOTTOM", 30 + 7.5, 25)
end

frame.unit = "pet"
frame:SetAttribute("unit", "pet")
frame:SetAttribute("toggleForVehicle", true)
frame:SetAttribute("*type1", "target")
frame:SetAttribute("*type2", "menu")
frame:RegisterForClicks("AnyUp")
frame.menu = function(self)
	ForeverUI.UnitMenu.open(ToggleDropDownMenu, 1, nil, PetFrameDropDown, self, 44, 8)
end

local portrait = frame:CreateTexture(nil, "BACKGROUND")
portrait:SetWidth(37)
portrait:SetHeight(37)
portrait:SetPoint("TOPLEFT", 5, -5)

local healthFill = frame:CreateTexture(nil, "BORDER")
healthFill:SetPoint("TOPLEFT", 44, -17)

local powerFill = frame:CreateTexture(nil, "BORDER")
powerFill:SetPoint("TOPLEFT", 40, -28)

local art = frame:CreateTexture(nil, "ARTWORK")
art:SetPoint("CENTER")
ForeverUI.SetAtlas(art, FRAME_ART)

local threat = frame:CreateTexture(nil, "OVERLAY")
threat:SetPoint("TOPLEFT", 1, 0)
ForeverUI.SetAtlas(threat, THREAT_ART)
threat:Hide()

local attack = frame:CreateTexture(nil, "OVERLAY")
attack:SetPoint("TOPLEFT", 0, 1)
ForeverUI.SetAtlas(attack, ATTACK_ART)
attack:SetBlendMode("ADD")
attack:Hide()

local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetWidth(68)
nameText:SetHeight(10)
nameText:SetJustifyH("LEFT")
nameText:SetJustifyV("BOTTOM")
nameText:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 2, 0)

local healthText = frame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
healthText:SetPoint("CENTER", frame, "TOPLEFT", 44 + 35, -17 - 5)
healthText:Hide()

local powerText = frame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
powerText:SetPoint("CENTER", frame, "TOPLEFT", 40 + 37 + 2, -28 - 3.5)
powerText:Hide()

local hitText = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
hitText:SetPoint("TOPLEFT", 5, -5)
hitText:Hide()
if CombatFeedback_Initialize then
	CombatFeedback_Initialize(frame, hitText, 30)
end

-- Hunter pet happiness (PetFrameHappinessTemplate)
local happiness = CreateFrame("Frame", "ForeverUIPetFrameHappiness", frame)
happiness:SetWidth(24)
happiness:SetHeight(23)
happiness:SetPoint("LEFT", frame, "RIGHT", 0, -4)
happiness:EnableMouse(true)
local happinessTexture = happiness:CreateTexture(nil, "BACKGROUND")
happinessTexture:SetTexture(HAPPINESS_FILE)
happinessTexture:SetAllPoints(happiness)
happiness:Hide()

-- ------------------------------------------------------------ updates
-- The unit shown: the player when a vehicle takes over the player frame
-- (toggleForVehicle, as in SecureButton_GetModifiedUnit)
local function displayedUnit()
	if UnitHasVehicleUI and UnitHasVehicleUI("player") then
		return "player"
	end
	return "pet"
end

local function updateHealth()
	local unit = displayedUnit()
	local maximum = UnitHealthMax(unit)
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitHealth(unit) / maximum
	end
	ForeverUI.SetAtlasFill(healthFill, HEALTH_FILL, fraction)
end

local function updatePower()
	local unit = displayedUnit()
	local powerType, powerToken = UnitPowerType(unit)
	local maximum = UnitPowerMax(unit, powerType)
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitPower(unit, powerType) / maximum
	end
	ForeverUI.SetAtlasFill(powerFill, POWER_FILL[powerToken or ""] or POWER_FILL.MANA, fraction)
end

-- Bar text follows petStatusText, and shows on hover
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
	local always = GetCVar and GetCVar("petStatusText") == "1"
	if not (always or frame.hovered) then
		healthText:Hide()
		powerText:Hide()
		return
	end
	local unit = displayedUnit()
	local powerType = UnitPowerType(unit)
	healthText:SetText(formatValue(UnitHealth(unit), UnitHealthMax(unit)))
	healthText:Show()
	-- PetFrameMixin:Update: no power text without power
	local powerMax = UnitPowerMax(unit, powerType)
	if powerMax and powerMax > 0 then
		powerText:SetText(formatValue(UnitPower(unit, powerType), powerMax))
		powerText:Show()
	else
		powerText:Hide()
	end
end

-- UnitFrame_UpdateThreatIndicator: shown above zero, tinted by threat level
local function updateThreat()
	local status = UnitThreatSituation and UnitThreatSituation(displayedUnit())
	if status and status > 0 and GetThreatStatusColor then
		threat:SetVertexColor(GetThreatStatusColor(status))
		threat:Show()
	else
		threat:Hide()
	end
end

local function updateHappiness()
	local mood, damage, loyalty = nil, 0, 0
	if GetPetHappiness then
		mood, damage, loyalty = GetPetHappiness()
	end
	local _, isHunterPet = HasPetUI()
	if not mood or not isHunterPet then
		happiness:Hide()
		return
	end
	local c = HAPPINESS_COORDS[mood]
	if c then
		happinessTexture:SetTexCoord(c[1], c[2], c[3], c[4])
	end
	happiness.tooltip = _G["PET_HAPPINESS" .. mood] or NONE
	happiness.tooltipDamage = PET_DAMAGE_PERCENTAGE and format(PET_DAMAGE_PERCENTAGE, damage or 0)
	if (loyalty or 0) < 0 then
		happiness.tooltipLoyalty = LOSING_LOYALTY
	elseif (loyalty or 0) > 0 then
		happiness.tooltipLoyalty = GAINING_LOYALTY
	else
		happiness.tooltipLoyalty = nil
	end
	happiness:Show()
end

local function updateAll()
	local unit = displayedUnit()
	-- The unit read by the tooltip and PartyMemberBuffTooltip_Update
	frame.unit = unit
	updateHealth()
	updatePower()
	nameText:SetText(UnitName(unit))
	SetPortraitTexture(portrait, unit)
	updateTexts()
	updateThreat()
	updateHappiness()
end

happiness:SetScript("OnEnter", function(self)
	if not self.tooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(self.tooltip)
	if self.tooltipDamage then GameTooltip:AddLine(self.tooltipDamage, "", 1, 1, 1) end
	if self.tooltipLoyalty then GameTooltip:AddLine(self.tooltipLoyalty, "", 1, 1, 1) end
	if GetPetFoodTypes and PET_DIET_TEMPLATE then
		local diet = { GetPetFoodTypes() }
		local text = #diet > 0 and table.concat(diet, PET_FOOD_DELIMIT or ", ") or NONE
		GameTooltip:AddLine(format(PET_DIET_TEMPLATE, text), "", 1, 1, 1)
	end
	GameTooltip:Show()
end)
happiness:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- In 3.3.5, PartyMemberBuffTooltip_Update takes the frame (it reads self.unit)
-- and shows or hides the tooltip itself
frame:SetScript("OnEnter", function(self)
	self.hovered = true
	updateTexts()
	if UnitFrame_OnEnter then UnitFrame_OnEnter(self) end
	if PartyMemberBuffTooltip and PartyMemberBuffTooltip_Update then
		PartyMemberBuffTooltip:SetPoint("TOPLEFT", self, "TOPLEFT", 60, -35)
		PartyMemberBuffTooltip_Update(self)
	end
end)

frame:SetScript("OnLeave", function(self)
	self.hovered = false
	updateTexts()
	if UnitFrame_OnLeave then UnitFrame_OnLeave(self) end
	if PartyMemberBuffTooltip then PartyMemberBuffTooltip:Hide() end
end)

frame:SetScript("OnShow", updateAll)

-- Attack pulse (PetFrameMixin:OnUpdate), red between PET_ATTACK_START and PET_ATTACK_STOP,
-- and damage taken
frame.attackCounter, frame.attackSign = 0, -1
frame:SetScript("OnUpdate", function(self, elapsed)
	if attack:IsShown() then
		local counter = self.attackCounter + elapsed
		if counter > 0.5 then
			self.attackSign = -self.attackSign
		end
		counter = math.fmod(counter, 0.5)
		self.attackCounter = counter
		local alpha
		if self.attackSign == 1 then
			alpha = (55 + counter * 400) / 255
		else
			alpha = (255 - counter * 400) / 255
		end
		attack:SetVertexColor(1, 0, 0, alpha)
	end
	if CombatFeedback_OnUpdate then
		CombatFeedback_OnUpdate(self, elapsed)
	end
end)

frame:SetScript("OnEvent", function(self, event, unit, ...)
	if event == "PET_ATTACK_START" then
		attack:SetVertexColor(1, 0, 0, 1)
		attack:Show()
		return
	end
	if event == "PET_ATTACK_STOP" then
		attack:Hide()
		return
	end
	if event == "CVAR_UPDATE" then
		updateTexts()
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "PET_UI_UPDATE" then
		updateAll()
		return
	end
	if event == "UNIT_PET" or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
		if unit == "player" then
			attack:Hide()
			updateAll()
		end
		return
	end
	if unit ~= displayedUnit() then
		return
	end
	if event == "UNIT_COMBAT" then
		if CombatFeedback_OnCombatEvent then
			CombatFeedback_OnCombatEvent(self, ...)
		end
	elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		updateHealth()
		updateTexts()
	elseif event == "UNIT_NAME_UPDATE" then
		nameText:SetText(UnitName(unit))
	elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
		SetPortraitTexture(portrait, unit)
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
		updateThreat()
	elseif event == "UNIT_HAPPINESS" then
		updateHappiness()
	else
		updatePower()
		updateTexts()
	end
end)

for _, event in ipairs({
	"PLAYER_ENTERING_WORLD", "UNIT_PET", "PET_UI_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
	"PET_ATTACK_START", "PET_ATTACK_STOP", "UNIT_COMBAT", "UNIT_HEALTH", "UNIT_MAXHEALTH",
	"UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_THREAT_SITUATION_UPDATE",
	"UNIT_HAPPINESS", "UNIT_DISPLAYPOWER", "UNIT_MANA", "UNIT_RAGE", "UNIT_FOCUS", "UNIT_ENERGY",
	"UNIT_RUNIC_POWER", "UNIT_MAXMANA", "UNIT_MAXRAGE", "UNIT_MAXFOCUS", "UNIT_MAXENERGY",
	"UNIT_MAXRUNIC_POWER", "CVAR_UPDATE",
}) do
	frame:RegisterEvent(event)
end

-- The client shows and hides the frame depending on whether the pet exists
if RegisterUnitWatch then
	RegisterUnitWatch(frame)
end

frame.portrait = portrait
frame.healthFill = healthFill
frame.powerFill = powerFill
frame.art = art
frame.threat = threat
frame.attack = attack
frame.nameText = nameText
frame.healthText = healthText
frame.powerText = powerText
frame.happiness = happiness
frame.happinessTexture = happinessTexture
ForeverUI.PetFrame = frame
ForeverUI.PetFrameUpdate = updateAll
