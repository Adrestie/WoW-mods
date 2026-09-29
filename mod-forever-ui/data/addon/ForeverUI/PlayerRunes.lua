-- ForeverUI: death knight runes. Art: mainline/RuneFrame.xml (sheet uideathknightrunes.blp);
-- data: 3.3.5 RuneFrame.lua (GetRuneType: 1 blood, 2 unholy, 3 frost, 4 death).
-- 3.3.5 has no SetSwipeTexture or SetTexCoordRange, so the cooldown swipe stays the client's.
-- Death runes (3.3.5 only) have no art on the modern sheet: they use "default", the neutral skull.

local CLASS = select(2, UnitClass("player"))
if CLASS ~= "DEATHKNIGHT" then
	return
end

local frame = ForeverUI.PlayerFrame

-- mainline/PlayerFrame.xml: PlayerBottomManagedFrameContainer, width 160, TOP on the player
-- frame's BOTTOM at (30, 25). mainline/RuneFrame.xml: RuneFrame 130 x 24, scale 0.95, runes
-- 24 x 24 spaced -1, cooldown 27 x 27 centered.
local RUNE_COUNT = 6
local RUNE_SIZE = 24
local RUNE_SPACING = -1
local COOLDOWN_SIZE = 27
local BAR_WIDTH, BAR_HEIGHT = 130, 24
local BAR_SCALE = 0.95
local CONTAINER_WIDTH = 160

local TYPE_PREFIX = {
	[1] = "blood",
	[2] = "unholy",
	[3] = "frost",
	[4] = "default",
}

-- class resource variant of the player frame: 3 pixels taller, with a strip for the runes
ForeverUI.PlayerFrameSetArt("ui-hud-unitframe-player-portraiton-classresource")

-- RuneFrame shows itself again on every rune update, so it is suppressed, not just hidden
ForeverUI.Suppress(RuneFrame)

-- The container (class resource strip) is not scaled, or its anchor offset would be too;
-- the rune bar carries the source's 0.95 scale.
local container = CreateFrame("Frame", "ForeverUIClassResourceContainer", frame)
container:SetWidth(CONTAINER_WIDTH)
container:SetHeight(BAR_HEIGHT)
container:SetPoint("TOP", frame, "BOTTOM", 30, 25)
container:SetFrameLevel(frame:GetFrameLevel() + 1)

local runeBar = CreateFrame("Frame", "ForeverUIRuneBar", container)
runeBar:SetWidth(BAR_WIDTH)
runeBar:SetHeight(BAR_HEIGHT)
runeBar:SetScale(BAR_SCALE)
runeBar:SetPoint("CENTER", container, "CENTER", 0, 0)

local buttons = {}

-- Layers in XML order, all BLEND. Mid, Eyes, Glow, Glow2 and Smoke only serve transitions
-- and end at alpha 0, so they are not built.
for index = 1, RUNE_COUNT do
	local button = CreateFrame("Frame", nil, runeBar)
	button:SetWidth(RUNE_SIZE)
	button:SetHeight(RUNE_SIZE)
	-- six 24 buttons spaced -1 are 139 wide, centered in the source's 130
	button:SetPoint("LEFT", runeBar, "LEFT",
		(BAR_WIDTH - (RUNE_COUNT * RUNE_SIZE + (RUNE_COUNT - 1) * RUNE_SPACING)) / 2
		+ (index - 1) * (RUNE_SIZE + RUNE_SPACING), 0)

	button.shadow = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(button.shadow, "uf-dkrunes-bgshadow")
	button.shadow:SetPoint("CENTER", 0, -3)

	button.bgInactive = button:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(button.bgInactive, "uf-dkrunes-bgdis")
	button.bgInactive:SetPoint("CENTER")

	button.bgActive = button:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(button.bgActive, "uf-dkrunes-bgactive")
	button.bgActive:SetPoint("CENTER")

	button.runeInactive = button:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(button.runeInactive, "uf-dkrunes-skulldis")
	button.runeInactive:SetPoint("CENTER")

	button.runeGrad = button:CreateTexture(nil, "ARTWORK")
	button.runeGrad:SetPoint("CENTER")

	button.runeLines = button:CreateTexture(nil, "ARTWORK")
	button.runeLines:SetPoint("CENTER")

	button.runeActive = button:CreateTexture(nil, "ARTWORK")
	button.runeActive:SetPoint("CENTER")

	button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldown:SetWidth(COOLDOWN_SIZE)
	button.cooldown:SetHeight(COOLDOWN_SIZE)
	button.cooldown:SetPoint("CENTER")

	buttons[index] = button
end

-- Final alphas of the XML animation groups (setToFinalAlpha):
-- ready (CooldownEndingAnim): BG_Active 1, Rune_Active 1, all else 0 (glows included);
-- empty (EmptyAnim): BG_Inactive 1, Rune_Inactive 0.4, all else 0;
-- cooling down (CooldownFillAnim): empty state plus Rune_Grad 0.3 and Rune_Lines 0.3.
local function updateRune(index)
	local button = buttons[index]
	if not button then
		return
	end

	local start, duration, ready = GetRuneCooldown(index)
	local prefix = TYPE_PREFIX[GetRuneType(index) or 1] or "default"

	ForeverUI.SetAtlas(button.runeGrad, "uf-dkrunes-" .. prefix .. "-skullgrad")
	ForeverUI.SetAtlas(button.runeLines, "uf-dkrunes-" .. prefix .. "-skulllines")
	ForeverUI.SetAtlas(button.runeActive, "uf-dkrunes-" .. prefix .. "-skullactive")

	if ready then
		button.bgActive:SetAlpha(1)
		button.bgInactive:SetAlpha(0)
		button.runeActive:SetAlpha(1)
		button.runeInactive:SetAlpha(0)
		button.runeGrad:SetAlpha(0)
		button.runeLines:SetAlpha(0)
	else
		button.bgActive:SetAlpha(0)
		button.bgInactive:SetAlpha(1)
		button.runeActive:SetAlpha(0)
		button.runeInactive:SetAlpha(0.4)

		local cooldown = (start and duration and duration > 0) and 0.3 or 0
		button.runeGrad:SetAlpha(cooldown)
		button.runeLines:SetAlpha(cooldown)
	end

	if start and duration and duration > 0 and CooldownFrame_SetTimer then
		CooldownFrame_SetTimer(button.cooldown, start, duration, ready and 0 or 1)
	end

	button.ready = ready and true or false
end

local function updateAllRunes()
	for index = 1, RUNE_COUNT do
		updateRune(index)
	end
end

runeBar:RegisterEvent("PLAYER_ENTERING_WORLD")
runeBar:RegisterEvent("RUNE_POWER_UPDATE")
runeBar:RegisterEvent("RUNE_TYPE_UPDATE")

runeBar:SetScript("OnEvent", function(_self, event, rune)
	if event == "PLAYER_ENTERING_WORLD" then
		ForeverUI.Suppress(RuneFrame)
		updateAllRunes()
	elseif rune then
		updateRune(rune)
	else
		updateAllRunes()
	end
end)

-- The end of a cooldown does not always fire an event: while a rune is cooling down,
-- poll ten times a second.
runeBar:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < 0.1 then
		return
	end
	self.elapsed = 0

	for index = 1, RUNE_COUNT do
		if not buttons[index].ready then
			updateAllRunes()
			return
		end
	end
end)

updateAllRunes()

ForeverUI.RuneBar = runeBar
ForeverUI.RuneButtons = buttons
