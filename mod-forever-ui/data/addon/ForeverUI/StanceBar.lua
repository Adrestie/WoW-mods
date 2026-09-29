-- ForeverUI: the stance bar (forms, auras, aspects) with camelot's StanceBar look
-- (SmallActionButtonTemplate, BaseActionButtonMixin:UpdateButtonArt).
-- The client ShapeshiftButtons are secure: we keep and re-skin them, never in combat, when
-- the client forbids resizing, moving or showing a protected frame. /fui moves the bar.

local SIZE = 30                       -- SmallActionButtonTemplate
local GAP = 2                         -- minButtonPadding
local STEP = SIZE + GAP
local FRAME_W, FRAME_H = 35, 35         -- NormalTexture and PushedTexture
local STATE_W, STATE_H = 31.6, 30.9       -- highlight, checked, border, flash
local NUM_BUTTONS = 10                   -- numButtons
local GRAYED = 0.4                       -- icon when not castable
local L = ForeverUI.L

local ATLAS = {
	normal = "ui-hud-actionbar-iconframe",
	pushed = "ui-hud-actionbar-iconframe-down",
	highlight = "ui-hud-actionbar-iconframe-mouseover",
	slot = "ui-hud-actionbar-iconframe-slot",
	background = "ui-hud-actionbar-iconframe-background",
}

local buttonCount = NUM_SHAPESHIFT_SLOTS or NUM_BUTTONS
local buttons = {}

-- The holder moves; the buttons anchor to it without changing parent, since reparenting a
-- secure frame is not allowed in combat.
local carrier = CreateFrame("Frame", "ForeverUIStanceBarHolder", UIParent)
carrier:SetWidth(STEP)
carrier:SetHeight(SIZE)
carrier:Hide()

-- The client rewrites its normal texture on each update: hide it and draw ours instead.
local function hideNormalTexture(button)
	local normalFont = button:GetNormalTexture()
	if normalFont then
		normalFont:SetAlpha(0)
		normalFont:SetVertexColor(1, 1, 1, 0)
	end
end

-- The source anchors the four states TOPLEFT. On the small button that puts a 35 frame on a
-- 30 button and shifts its opening by 2.5 over the icon. Centered, the opening (26.6 at size
-- 35) fits in the 30 icon with 1.7 margin on every side, so the states are CENTERED.
-- add: use ADD blending (checked state)
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

	-- Hide the old art: floating background and gold frame.
	local floatingBg = _G[name .. "FloatingBG"]
	if floatingBg then
		floatingBg:SetAlpha(0)
	end
	hideNormalTexture(button)

	-- Empty slot under the icon: the two pieces from the source.
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

	-- Our own frame, out of the client's reach, where the source puts its NormalTexture:
	-- OVERLAY, 35 x 35, centered (see applyState).
	local frame = button:CreateTexture(nil, "OVERLAY")
	applyState(frame, ATLAS.normal, FRAME_W, FRAME_H)
	button.foreverFrame = frame

	local pressed = button:GetPushedTexture()
	applyState(pressed, ATLAS.pushed, FRAME_W, FRAME_H)
	applyState(button:GetHighlightTexture(), ATLAS.highlight, STATE_W, STATE_H)
	applyState(button:GetCheckedTexture(), ATLAS.highlight, STATE_W, STATE_H, true)

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
	table.insert(buttons, button)
end

local function skinAll()
	for index = 1, buttonCount do
		applySkin(_G["ShapeshiftButton" .. index])
	end

	-- The old bar has its own three-piece art.
	for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
		local texture = _G["ShapeshiftBar" .. suffix]
		if texture then
			texture:SetAlpha(0)
		end
	end
end

-- camelot: StanceBarMixin:Update and ActionBarMixin:UpdateGridLayout. One row, buttons added
-- to the right with minButtonPadding, bar hidden while there is no form.
local function place()
	local numForms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0

	if numForms <= 0 then
		carrier:Hide()
		return
	end

	if InCombatLockdown() then
		return                  -- secure buttons cannot be moved in combat
	end

	carrier:SetWidth(numForms * SIZE + (numForms - 1) * GAP)
	carrier:SetHeight(SIZE)

	for index = 1, buttonCount do
		local button = _G["ShapeshiftButton" .. index]
		if button then
			if index <= numForms then
				button:SetWidth(SIZE)
				button:SetHeight(SIZE)
				button:ClearAllPoints()
				button:SetPoint("LEFT", carrier, "LEFT", (index - 1) * STEP, 0)
				button:Show()
			else
				button:Hide()
			end
		end
	end

	carrier:Show()
end

-- camelot: StanceBarMixin:UpdateState.
local function updateState()
	local numForms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0

	for index = 1, buttonCount do
		local button = _G["ShapeshiftButton" .. index]
		if button and button.foreverSkinned and index <= numForms then
			-- 3.3.5 returns (texture, name, isActive, isCastable), unlike the modern client.
			local texture, _, active, castable = GetShapeshiftFormInfo(index)
			local icon = button.foreverIcon

			if icon then
				icon:SetTexture(texture)
				if castable then
					icon:SetVertexColor(1, 1, 1)
				else
					icon:SetVertexColor(GRAYED, GRAYED, GRAYED)
				end
			end

			local cooldown = button.foreverCooldown
			if cooldown then
				if texture then
					cooldown:Show()
				else
					cooldown:Hide()
				end
				local start, duration, active = GetShapeshiftFormCooldown(index)
				if CooldownFrame_SetTimer then
					CooldownFrame_SetTimer(cooldown, start, duration, active)
				elseif CooldownFrame_Set then
					CooldownFrame_Set(cooldown, start, duration, active)
				end
			end

			button:SetChecked(active and 1 or nil)
			hideNormalTexture(button)
		end
	end
end

local function all()
	skinAll()
	place()
	updateState()
end

ForeverUI.StanceBar = { Apply = all, Holder = carrier }

-- The client re-sets its own pieces on each update.
if hooksecurefunc then
	for _, funcName in ipairs({ "ShapeshiftBar_Update", "ShapeshiftBar_UpdateState",
		"ShapeshiftBar_ChangeForm" }) do
		if type(_G[funcName]) == "function" then
			hooksecurefunc(funcName, function()
				place()
				updateState()
			end)
		end
	end
end

local listener = CreateFrame("Frame", "ForeverUIStanceBarWatcher")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("PLAYER_REGEN_ENABLED")
listener:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
listener:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
listener:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
listener:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN")
listener:SetScript("OnEvent", all)

all()

-- Default: left edge aligned with the action bar (-25.5 - 562 = -587.5 from center), above
-- the experience and reputation bars. /fui moves it.
ForeverUI.Layout.Register(carrier, "stances", L.STANCEBAR_EDIT_LABEL,
	"BOTTOMLEFT", "BOTTOM", -587.5, 84)
