-- Main action bar: the client's secure action buttons, kept and reskinned (camelot
-- ActionButtonTemplate, MainActionBar), with the bar border, page arrows and gryphon end caps.
-- Recreating the buttons would mean rewriting spells, macros and drag and drop, and risk taint.
-- Nothing is resized or moved in combat, where the client forbids it.

-- camelot ActionButtonTemplate: 45 x 45; shared/ActionBar.lua minButtonPadding = 2
local BUTTON_SIZE = 45
local BUTTON_PADDING = 2
local BUTTON_PITCH = BUTTON_SIZE + BUTTON_PADDING
local FRAME_WIDTH, FRAME_HEIGHT = 46, 45      -- size of the four state textures
local BUTTON_COUNT = 12
local END_CAP_WIDTH, END_CAP_HEIGHT = 154, 95
local END_CAP_DROP = -2      -- measured on screen: the art bottom drops 2 px below the bar
local L = ForeverUI.L

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

-- The frame is not the button's NormalTexture: ActionButton_Update sets UI-Quickslot2 on
-- every refresh and ActionButton_ShowGrid recolors it, erasing any skin. So the client's
-- texture is silenced and we draw our own frame. add: use the ADD blend mode.
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

-- Hide again what the client just rewrote.
local function silenceNormalTexture(button)
	local normal = button:GetNormalTexture()
	if normal then
		normal:SetAlpha(0)
		normal:SetVertexColor(1, 1, 1, 0)
	end
end

-- 3.3.5 trap: ActionButton_HideGrid hides the WHOLE button once its showgrid counter drops
-- to zero, and it only rises during a drag, so empty slots vanish. Keeping the counter at 1
-- makes the client keep empty buttons shown. The fallback Show never runs in combat (secure
-- frame); PLAYER_REGEN_ENABLED brings back anything hidden meanwhile.
local function keepGrid(button)
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

	-- Empty slot, under the icon.
	local background = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, ATLAS.background, true)
	background:SetAllPoints(button)

	local slot = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(slot, ATLAS.slot, true)
	slot:SetAllPoints(button)

	button.foreverBackground = background
	button.foreverSlot = slot

	if icon then
		-- The icon fills the button, as in camelot; 3.3.5 has no MaskTexture, so the frame's
		-- solid corners cover the icon's corners.
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetDrawLayer("BORDER")
	end

	-- Our frame, above the icon and out of the client's reach.
	local frame = button:CreateTexture(nil, "ARTWORK")
	setStateTexture(frame, ATLAS.normal)
	button.foreverFrame = frame

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
		-- The client's equipped border is green and square; camelot uses its own, hidden by default.
		ForeverUI.SetAtlas(border, ATLAS.border)
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", 0, 0)
	end

	if floatingBG then
		floatingBG:SetAlpha(0)
	end

	-- SetFontObject RESETS the justification, so set it AFTER. The number fonts have no
	-- justifyH (client FontStyles.xml), so they are centered by default.
	if hotkey then
		hotkey:SetWidth(32)
		hotkey:SetHeight(10)
		hotkey:ClearAllPoints()
		hotkey:SetPoint("TOPRIGHT", -5, -5)
		hotkey:SetFontObject(NumberFontNormalSmallGray)
		hotkey:SetJustifyH("RIGHT")
	end

	if count then
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", -5, 5)
		count:SetFontObject(NumberFontNormal)
		count:SetJustifyH("RIGHT")
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

	keepGrid(button)
	button.foreverSkinned = true
end

-- ---------- Bar
local holder = CreateFrame("Frame", "ForeverUIActionBarHolder", UIParent)
holder:SetWidth(BUTTON_COUNT * BUTTON_SIZE + (BUTTON_COUNT - 1) * BUTTON_PADDING)
holder:SetHeight(BUTTON_SIZE)

-- Bar border: camelot's UI-HUD-ActionBar-Frame, one octagonal image, from TOPLEFT (-6, 6)
-- to BOTTOMRIGHT (4, -5). Nine-sliced so the corner bevels keep their size.
local border = CreateFrame("Frame", nil, holder)
border:SetPoint("TOPLEFT", -6, 6)
border:SetPoint("BOTTOMRIGHT", 4, -5)
border:SetFrameLevel(holder:GetFrameLevel())
ForeverUI.SetBarFrameArt(border)

-- Page block (mainline/MainActionBar.xml ActionBarPageNumber): BOTTOMRIGHT on the bar's
-- BOTTOMLEFT at (-4, 9); number 17 x 10 centered at -1, two 17 x 14 arrows at +10 and -10;
-- sized by its children: 17 x 34.
local page = CreateFrame("Frame", "ForeverUIActionBarPage", holder)
page:SetWidth(17)
page:SetHeight(34)
page:SetPoint("BOTTOMRIGHT", holder, "BOTTOMLEFT", -4, 9)
page:SetFrameLevel(holder:GetFrameLevel() + 11)

-- Dividers between buttons: RIGHT on the button's LEFT, offset 5.
local dividers = {}

-- End caps (gryphons): two 154 x 95 frames filled by their texture, movable on their own
-- (Customize UI); BottomBar.lua gives their default positions.
local END_CAP_INSET = 30       -- each cap overlaps its bar by 30 px
local function createEndCap(name, atlas)
	local cap = CreateFrame("Frame", name, UIParent)
	cap:SetWidth(END_CAP_WIDTH)
	cap:SetHeight(END_CAP_HEIGHT)
	-- camelot/MainMenuBarEndCaps.xml: frameLevel 100. The end cap is drawn IN FRONT of the
	-- buttons, whose level is the client frame's.
	cap:SetFrameStrata(holder:GetFrameStrata())
	cap:SetFrameLevel(holder:GetFrameLevel() + 10)

	local texture = cap:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints(cap)
	if not ForeverUI.SetAtlas(texture, atlas, true) then
		cap:Hide()
	end
	cap.texture = texture
	return cap
end

-- mainline/EditModePresetLayouts.lua: the left cap sits on the bar's LEFT edge, the right
-- cap on the bag bar's RIGHT edge, each 30 px inward (BottomBar.lua re-anchors it to the
-- bags). Camelot drops the cap 20 px below the bar, off screen for a bar 2 px above the
-- screen bottom, so the art bottom is aligned on the bar bottom, then 2 px lower.
local leftCap = createEndCap("ForeverUIActionBarLeftCap", "ui-hud-actionbar-gryphon-left")
local rightCap = createEndCap("ForeverUIActionBarRightCap", "ui-hud-actionbar-gryphon-right")

-- The bonus bar takes the same place. On a stance change 3.3.5 shows BonusActionBarFrame
-- over the main bar at its own position, so its buttons are anchored like the main ones and
-- follow the holder. Nothing is reparented: buttons follow the client bar's visibility.
-- 3.3.5 slides this bar in, but secure buttons cannot move every frame in combat, where
-- stances change: they are anchored ONCE to a track (our frame), and the track slides.
local PLACED_BARS = { "ActionButton", "BonusActionButton" }

-- The track covers the holder and shifts vertically while sliding. The duration comes from
-- the client when it declares it.
local track = CreateFrame("Frame", "ForeverUIBonusSlide", holder)
local SLIDE_DURATION = BONUS_ACTIONBUTTON_SLIDE_TIME or 0.2
local SLIDE_DISTANCE = BUTTON_SIZE

local function placeTrack(progress)
	local offset = -SLIDE_DISTANCE * (1 - progress)
	track:ClearAllPoints()
	track:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, offset)
	track:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, offset)
end
placeTrack(1)

-- The slide goes both ways. When hiding, the client sets mode = "hide" and keeps the bar
-- shown until the move ends, so the mode is read rather than the visibility alone. Without
-- that field the hide is instant: hidden buttons cannot be animated.
track.progress = 1
track.target = 1
track:SetScript("OnUpdate", function(self, elapse)
	local bar = BonusActionBarFrame
	local visible = bar and bar:IsShown()

	if visible and not self.visible then
		self.progress, self.target = 0, 1      -- shown: slides up
	elseif visible and bar.mode == "hide" then
		self.target = 0                          -- the client is hiding it
	elseif not visible then
		self.progress, self.target = 0, 0      -- ready to slide up again
	end
	self.visible = visible

	if self.progress ~= self.target then
		local step = (elapse or 0) / SLIDE_DURATION
		if self.target > self.progress then
			self.progress = math.min(self.target, self.progress + step)
		else
			self.progress = math.max(self.target, self.progress - step)
		end
		placeTrack(self.progress)
	end
end)
ForeverUI.ActionBarSlide = track

local function layoutButtons()
	if InCombatLockdown() then
		return
	end

	for _, prefix in ipairs(PLACED_BARS) do
		local anchor = (prefix == "BonusActionButton") and track or holder
		for index = 1, BUTTON_COUNT do
			local button = _G[prefix .. index]
			if button then
				button:ClearAllPoints()
				button:SetPoint("LEFT", anchor, "LEFT", (index - 1) * BUTTON_PITCH, 0)

				-- Dividers belong to the holder: one set, placed on the main bar.
				if prefix == "ActionButton" and index > 1 and not dividers[index] then
					local divider = ForeverUI.CreateDivider(holder, holder:GetFrameLevel() + 1)
					divider:SetPoint("TOP", button, "TOP", 0, 0)
					divider:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
					divider:SetPoint("RIGHT", button, "LEFT", 5, 0)
					dividers[index] = divider
				end
			end
		end
	end
end

-- Hide the client's bar art. 3.3.5 MainMenuBar.xml has FOUR sets of pieces, and missing one
-- leaves the old dwarf bar behind ours: MainMenuBarTexture0..3 (bar body),
-- MainMenuXPBarTexture0..3 (XP bar frame), MainMenuMaxLevelBar0..3 (shown at 80), the
-- MainMenuBarLeftEndCap / RightEndCap end caps, and MainMenuBarExpText.
local OLD_ART = {
	"MainMenuBarTexture%d", "MainMenuXPBarTexture%d", "MainMenuMaxLevelBar%d",
}

-- Bonus bar art: all the frame's own texture regions are hidden (buttons are child frames,
-- not regions). The frame also stops taking the mouse: BonusActionBarFrame is 505 x 43, HIGH
-- strata, toplevel, enableMouse; invisible, it would still swallow clicks on the micro-menu
-- below it. Its buttons keep their own mouse, being child frames.
local function clearBonusArt()
	local bar = BonusActionBarFrame
	if not bar or not bar.GetRegions then
		return
	end

	if bar.EnableMouse then
		bar:EnableMouse(false)
	end

	local regions = { bar:GetRegions() }
	for _, region in ipairs(regions) do
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
end

local function hideOldBarArt()
	clearBonusArt()

	for _, model in ipairs(OLD_ART) do
		for index = 0, 3 do
			local texture = _G[string.format(model, index)]
			if texture then
				texture:SetAlpha(0)
			end
		end
	end

	for _, name in ipairs({ "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "MainMenuBarExpText" }) do
		local region = _G[name]
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

	-- Page arrows: camelot has its own in the bar atlas.
	local arrows = {
		{ button = ActionBarUpButton, prefix = "ui-hud-actionbar-pageuparrow", y = 10 },
		{ button = ActionBarDownButton, prefix = "ui-hud-actionbar-pagedownarrow", y = -10 },
	}
	for _, entry in ipairs(arrows) do
		local button = entry.button
		if button and not button.foreverSkinned then
			ForeverUI.SetAtlas(button:GetNormalTexture(), entry.prefix .. "-up")
			ForeverUI.SetAtlas(button:GetPushedTexture(), entry.prefix .. "-down")
			ForeverUI.SetAtlas(button:GetHighlightTexture(), entry.prefix .. "-mouseover")
			if button.GetDisabledTexture and button:GetDisabledTexture() then
				ForeverUI.SetAtlas(button:GetDisabledTexture(), entry.prefix .. "-disabled")
			end
			button:SetWidth(17)
			button:SetHeight(14)
			button:ClearAllPoints()
			button:SetPoint("CENTER", page, "CENTER", 0, entry.y)
			button.foreverSkinned = true
		end
	end
end

local function skinAll()
	for _, prefix in ipairs(BARS) do
		for index = 1, BUTTON_COUNT do
			local button = _G[prefix .. index]
			skinButton(button)
			keepGrid(button)
		end
	end
	hideOldBarArt()
end

-- The client rewrites the normal texture on every button update: silence it again after.
if hooksecurefunc then
	hooksecurefunc("ActionButton_Update", function(self)
		if self and self.foreverSkinned then
			silenceNormalTexture(self)
			keepGrid(self)
		end
	end)

	hooksecurefunc("ActionButton_ShowGrid", function(self)
		if self and self.foreverSkinned then
			silenceNormalTexture(self)
		end
	end)

	-- Here the client hides empty buttons.
	hooksecurefunc("ActionButton_HideGrid", function(self)
		if self and self.foreverSkinned then
			silenceNormalTexture(self)
			keepGrid(self)
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
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r : " .. L.ACTIONBAR_BUTTON1_MISSING)
		return
	end

	local point, relativeTo, _, x, y = button:GetPoint(1)
	local normal = button:GetNormalTexture()
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r " .. L.ACTIONBAR_DEBUG,
		button:GetWidth(), button:GetHeight(),
		tostring(button:GetParent() and button:GetParent():GetName() or "?"),
		tostring(point), tostring(relativeTo and relativeTo:GetName() or "?"), x or 0, y or 0,
		tostring(button:IsShown()),
		tostring(button.foreverFrame and button.foreverFrame:GetTexture() or NONE),
		normal and normal:GetAlpha() or -1))
end

ForeverUI.ActionBarHolder = holder
ForeverUI.ActionBarBorder = border
ForeverUI.ActionBarEndCaps = { left = leftCap, right = rightCap, inset = END_CAP_INSET, drop = END_CAP_DROP }
-- camelot/EditModePresetLayoutConstants.lua: BOTTOMRIGHT on the micro-menu's BOTTOMLEFT at
-- (-4.5, -4); the micro-menu at BOTTOM (116.5, 6), 275 wide, puts the bar's right edge at
-- -25.5 from the screen center, 2 from the bottom. BottomBar.lua redoes this with the real
-- micro-menu width.
ForeverUI.Layout.Register(holder, "actionbar", L.ACTIONBAR_EDIT_LABEL, "BOTTOMRIGHT", "BOTTOM", -25.5, 2)
ForeverUI.Layout.Register(leftCap, "leftgryphon", L.ACTIONBAR_EDIT_LABEL_LEFT_GRYPHON, "BOTTOMRIGHT", "BOTTOM",
	-25.5 - holder:GetWidth() + END_CAP_INSET, 2 + END_CAP_DROP)
ForeverUI.Layout.Register(rightCap, "rightgryphon", L.ACTIONBAR_EDIT_LABEL_RIGHT_GRYPHON, "BOTTOMLEFT", "BOTTOM",
	0, 2 + END_CAP_DROP)
