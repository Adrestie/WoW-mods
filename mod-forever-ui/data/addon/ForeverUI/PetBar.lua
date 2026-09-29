-- Pet action bar: the client's secure PetActionButtons, reskinned as camelot's
-- SmallActionButtonTemplate (shared/PetActionBar.lua UpdateButtonState); never recreated,
-- never resized or moved in combat. 3.3.5 has no HasPetActionHighlightMark: no highlight mark.

local SIZE = 30                       -- SmallActionButtonTemplate
local GAP = 2                         -- minButtonPadding
local STEP = SIZE + GAP              -- 32
local FRAME_W, FRAME_H = 35, 35         -- NormalTexture and PushedTexture
local STATE_W, STATE_H = 31.6, 30.9       -- highlight, checked, border, flash
local NUM_BUTTONS = 10
local ORIGINAL_SIZE = 36               -- the 3.3.5 button
local AUTOCAST_BORDER = 58             -- its autocast border
local L = ForeverUI.L
local GRAYED = 0.4                       -- unusable action
local ATTACK_CHECK_ALPHA = 0.5               -- check mark alpha on the attack action

-- Default place: just above the reputation bar, on the action bar's left edge. When the
-- stance bar is shown, the pet bar goes to its RIGHT, two icons apart.
local LEFT_EDGE = -587.5              -- left edge of the action bar
local ROW_Y = 84                       -- above the reputation bar
local BARS_GAP = 2 * SIZE         -- two icons between the two bars

local ATLAS = {
	normal = "ui-hud-actionbar-iconframe",
	pushed = "ui-hud-actionbar-iconframe-down",
	highlight = "ui-hud-actionbar-iconframe-mouseover",
	flash = "ui-hud-actionbar-iconframe-flash",
	slot = "ui-hud-actionbar-iconframe-slot",
	background = "ui-hud-actionbar-iconframe-background",
}

local buttonCount = NUM_PET_ACTION_SLOTS or NUM_BUTTONS

local carrier = CreateFrame("Frame", "ForeverUIPetBarHolder", UIParent)
carrier:SetWidth(STEP)
carrier:SetHeight(SIZE)
carrier:Hide()

local function hideNormalTexture(button)
	local normalFont = button:GetNormalTexture()
	if normalFont then
		normalFont:SetAlpha(0)
		normalFont:SetVertexColor(1, 1, 1, 0)
	end
end

-- The four states are CENTERED: a 35 frame on a 30 button overflows by 5, and its hole
-- would leave the icon (see StanceBar.lua). add: ADD blend mode.
local function applyState(texture, atlas, width, height, add)
	if not texture then
		return
	end

	ForeverUI.SetAtlas(texture, atlas, true)
	texture:SetWidth(width)
	texture:SetHeight(height)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", 0, 0)
	texture:SetBlendMode(add and "ADD" or "BLEND")
end

local function applySkin(button)
	if not button or button.foreverSkinned then
		return
	end

	local name = button:GetName()
	button:SetWidth(SIZE)
	button:SetHeight(SIZE)
	hideNormalTexture(button)

	local floatingBg = _G[name .. "FloatingBG"]
	if floatingBg then
		floatingBg:SetAlpha(0)
	end

	-- Autocast stays the client's: AutoCastTemplates exists only in mainline/, and only
	-- camelot/ and shared/ count, so camelot keeps the original border and four sparkles. They
	-- are only scaled to the button, from 36 to 30.
	local scale = SIZE / ORIGINAL_SIZE
	local autoCastable = _G[name .. "AutoCastable"]
	if autoCastable then
		autoCastable:SetWidth(AUTOCAST_BORDER * scale)
		autoCastable:SetHeight(AUTOCAST_BORDER * scale)
	end
	-- The sparkles cannot be resized: the client places them at a fixed size and
	-- AutoCastShine_OnUpdate moves them without resizing, so the frame is SCALED instead:
	-- sizes and orbit follow.
	local sparkles = _G[name .. "Shine"]
	if sparkles then
		sparkles:SetScale(scale)
	end

	local background = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, ATLAS.background, true)
	background:SetAllPoints(button)

	local slot = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(slot, ATLAS.slot, true)
	slot:SetAllPoints(button)
	button.foreverBackground = background
	button.foreverSlot = slot

	local icon = _G[name .. "Icon"]
	if icon then
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetDrawLayer("BORDER")
		button.foreverIcon = icon
	end

	local frame = button:CreateTexture(nil, "OVERLAY")
	applyState(frame, ATLAS.normal, FRAME_W, FRAME_H)
	button.foreverFrame = frame

	applyState(button:GetPushedTexture(), ATLAS.pushed, FRAME_W, FRAME_H)
	applyState(button:GetHighlightTexture(), ATLAS.highlight, STATE_W, STATE_H)
	applyState(button:GetCheckedTexture(), ATLAS.highlight, STATE_W, STATE_H, true)
	applyState(_G[name .. "Flash"], ATLAS.flash, STATE_W, STATE_H)

	local cooldown = _G[name .. "Cooldown"]
	if cooldown and icon then
		cooldown:ClearAllPoints()
		cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", 1.7, -1.7)
		cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
		button.foreverCooldown = cooldown
	end

	local hotkey = _G[name .. "HotKey"]
	if hotkey then
		hotkey:ClearAllPoints()
		hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -4)
	end

	local quantity = _G[name .. "Count"]
	if quantity then
		quantity:ClearAllPoints()
		quantity:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 1)
	end

	button.foreverSkinned = true
end

-- Legacy bar art: 3.3.5 frames the pet bar with two sliding pieces (SlidingActionBarTexture0
-- and 1). All the frame's own texture regions are hidden; the buttons are child frames, not
-- regions, so they are untouched.
local function clearLegacyArt()
	local bar = PetActionBarFrame
	if not bar or not bar.GetNumRegions then
		return
	end

	local regions = { bar:GetRegions() }
	for _, region in ipairs(regions) do
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
end

local function skinAll()
	for index = 1, buttonCount do
		applySkin(_G["PetActionButton" .. index])
	end
	clearLegacyArt()
end

-- The bar shows when the pet has an action bar AND is visible.
local function hasPet()
	if not PetHasActionBar or not PetHasActionBar() then
		return false
	end
	return UnitIsVisible and UnitIsVisible("pet") and true or false
end

-- The default place is recomputed: it depends on the stance bar, which comes and goes with
-- shapeshift forms. SetDefaults only moves the frame when the user has not moved it.
local function placeDefault()
	local x = LEFT_EDGE
	local stances = ForeverUI.StanceBar and ForeverUI.StanceBar.Holder
	if stances and stances:IsShown() then
		x = x + stances:GetWidth() + BARS_GAP
	end
	ForeverUI.Layout.SetDefaults("pet", "BOTTOMLEFT", "BOTTOM", x, ROW_Y)
end

local function place()
	if not hasPet() then
		carrier:Hide()
		return
	end

	if InCombatLockdown() then
		return
	end

	carrier:SetWidth(buttonCount * SIZE + (buttonCount - 1) * GAP)
	carrier:SetHeight(SIZE)

	for index = 1, buttonCount do
		local button = _G["PetActionButton" .. index]
		if button then
			button:SetWidth(SIZE)
			button:SetHeight(SIZE)
			button:ClearAllPoints()
			button:SetPoint("LEFT", carrier, "LEFT", (index - 1) * STEP, 0)
			button:Show()
		end
	end

	carrier:Show()
	placeDefault()
end

-- PetActionButtonMixin:UpdateButtonState
local function updateState()
	for index = 1, buttonCount do
		local button = _G["PetActionButton" .. index]
		if button and button.foreverSkinned then
			-- 3.3.5: (name, SUBTEXT, texture, isToken, active, autoCastAllowed, autoCastEnabled).
			-- Camelot has no subtext: copying its code would take the subtext for the texture.
			local _, _, texture, isToken, active =
				GetPetActionInfo(index)
			local icon = button.foreverIcon

			if icon then
				-- isToken: name and texture are KEYS of global variables, not values.
				icon:SetTexture(isToken and _G[texture] or texture)
				if texture then
					local usable = not GetPetActionSlotUsable
						or GetPetActionSlotUsable(index)
					if usable then
						icon:SetVertexColor(1, 1, 1)
					else
						icon:SetVertexColor(GRAYED, GRAYED, GRAYED)
					end
					icon:Show()
				else
					icon:Hide()
				end
			end

			local checkMark = button:GetCheckedTexture()
			if active then
				-- The attack action flashes and its check mark is half transparent: at full alpha it would
				-- look like one more selected ability.
				local isAttack = IsPetAttackAction and IsPetAttackAction(index)
				if checkMark then
					checkMark:SetAlpha(isAttack and ATTACK_CHECK_ALPHA or 1)
				end
				button:SetChecked(1)
			else
				button:SetChecked(nil)
			end

			local cooldown = button.foreverCooldown
			if cooldown and GetPetActionCooldown then
				local start, duration, active = GetPetActionCooldown(index)
				if CooldownFrame_SetTimer then
					CooldownFrame_SetTimer(cooldown, start, duration, active)
				elseif CooldownFrame_Set then
					CooldownFrame_Set(cooldown, start, duration, active)
				end
			end

			hideNormalTexture(button)
		end
	end
end

local function all()
	skinAll()
	place()
	updateState()
end

ForeverUI.PetBar = { Apply = all, Holder = carrier }

if hooksecurefunc then
	for _, funcName in ipairs({ "PetActionBar_Update", "PetActionBar_UpdateCooldowns" }) do
		if type(_G[funcName]) == "function" then
			hooksecurefunc(funcName, function()
				place()
				updateState()
			end)
		end
	end
end

local listener = CreateFrame("Frame", "ForeverUIPetBarWatcher")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("PLAYER_REGEN_ENABLED")
listener:RegisterEvent("UNIT_PET")
listener:RegisterEvent("PET_BAR_UPDATE")
listener:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
listener:RegisterEvent("PET_BAR_UPDATE_USABLE")
listener:RegisterEvent("PET_UI_UPDATE")
listener:RegisterEvent("PLAYER_CONTROL_LOST")
listener:RegisterEvent("PLAYER_CONTROL_GAINED")
-- Forms change the stance bar's width, hence this bar's place. StanceBar.lua loads first:
-- its handler runs first, so the width is already right when read.
listener:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
listener:SetScript("OnEvent", all)

all()

-- No fixed position here, as for the other bars: everything goes through /fui.
-- placeDefault then moves the default right of the stance bar when it is shown.
ForeverUI.Layout.Register(carrier, "pet", L.PETBAR_EDIT_LABEL,
	"BOTTOMLEFT", "BOTTOM", LEFT_EDGE, ROW_Y)
placeDefault()
