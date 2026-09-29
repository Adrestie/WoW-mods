-- Bottom of the screen: the micro menu and the bags bar, rebuilt from camelot.
-- Sources: camelot/MainMenuBarMicroMenu.xml, MicroMenuContainerOverrides.lua (order),
-- MainMenuBarBagButtons.xml, shared/BagsBar.lua, EditModePresetLayoutConstants.lua (positions).
-- The client's PvP and Help micro buttons are removed; the strip is as wide as its buttons.

-- camelot/MainMenuBarMicroMenu.xml: 32 x 40 buttons, childXPadding = -5 (5 px overlap)
local MICRO_W, MICRO_H = 32, 40
local MICRO_PADDING = -5
local MICRO_PITCH = MICRO_W + MICRO_PADDING

-- Displayed button height: the 40 px strip plus its 8 px frame on each side (56),
-- minus the 5 px bronze edge on each side, leaves a 46 px opening.
-- Camelot's 41 px art is stretched to fill it.
local MICRO_ART_H = 46

-- camelot/MainMenuBarBagButtons.xml: bags 45 x 45, bagPadding = 2, bag frame 46 x 46,
-- keyring 33 wide
local BAG_SIZE = 45
local BAG_PADDING = 2
local BAG_FRAME_W, BAG_FRAME_H = 46, 46
local KEYRING_W = 33


-- camelot/EditModePresetLayoutConstants.lua: micro menu at BOTTOM (116.5, 6); action bar
-- BOTTOMRIGHT on its BOTTOMLEFT (-4.5, -4); bags BOTTOMLEFT on its BOTTOMRIGHT (7, -4)
local MICRO_X, MICRO_Y = 116.5, 6
local BAR_OFFSET_X, BAR_OFFSET_Y = -4.5, -4
local BAGS_OFFSET_X, BAGS_OFFSET_Y = 7, -4

-- Backslash built with string.char, so the path needs no escaped separators.
local SEP = string.char(92)
local BAG_ICON = "Interface" .. SEP .. "ForeverUI" .. SEP .. "icons" .. SEP .. "ui-hud-actionbar-bag"
local PERFORMANCE_IMAGE = "Interface" .. SEP .. "ForeverUI" .. SEP .. "mainmenubar" .. SEP .. "ui-mainmenubar-performancebar"
local L = ForeverUI.L

-- Camelot's order, limited to the buttons this client has.
-- The professions button (camelot ProfessionMicroButton) does not exist in 3.3.5: it is
-- created here and opens ProfessionsBook.lua.
-- create: role of a created button, which picks its tooltip and click (MICRO_ROLES).
-- Other addons add their own buttons with ForeverUI.AddMicroButton (below).
local MICRO = {
	{ name = "CharacterMicroButton", portrait = true },
	{ name = "ForeverUIProfessionMicroButton", atlasSet = "professions", create = "professions" },
	{ name = "SpellbookMicroButton", atlasSet = "spellbookabilities" },
	{ name = "TalentMicroButton", atlasSet = "spectalents" },
	{ name = "AchievementMicroButton", atlasSet = "achievements" },
	{ name = "QuestLogMicroButton", atlasSet = "questlog" },
	{ name = "SocialsMicroButton", atlasSet = "guildcommunities" },
	{ name = "LFDMicroButton", atlasSet = "groupfinder" },
	{ name = "MainMenuMicroButton", atlasSet = "gamemenu" },
}

local MICRO_STATES = {
	up = "GetNormalTexture",
	down = "GetPushedTexture",
	disabled = "GetDisabledTexture",
	mouseover = "GetHighlightTexture",
}

-- Camelot shows the c60 set. The logical atlas name resolves to the base variant (the c60
-- sheet sorts after it), so the c60 name is tried first, with the base one as fallback.
-- The disabled state is -disable on the c60 sheet and -disabled on the base sheet.
local function microAtlas(atlasSet, state)
	local candidates = {
		"ui-hud-micromenu-" .. atlasSet .. "-" .. state .. "-c60-2x",
		"ui-hud-micromenu-" .. atlasSet .. "-" .. state .. "-2x",
	}
	if state == "disabled" then
		table.insert(candidates, 1, "ui-hud-micromenu-" .. atlasSet .. "-disable-c60-2x")
	end
	for _, name in ipairs(candidates) do
		if ForeverUI.AtlasEntry(name) then
			return name
		end
	end
	return nil
end

-- --------------------------------------------------------- Micro menu
local micro = CreateFrame("Frame", "ForeverUIMicroMenu", UIParent)
micro:SetHeight(MICRO_H)

local blockBackground = micro:CreateTexture(nil, "BACKGROUND")
ForeverUI.SetAtlas(blockBackground, "ui-hud-actionbar-iconframe-background", true)

local blockFrame = CreateFrame("Frame", nil, micro)
blockFrame:SetPoint("TOPLEFT", -8, 8)
blockFrame:SetPoint("BOTTOMRIGHT", 8, -8)
blockFrame:SetFrameLevel(micro:GetFrameLevel())
ForeverUI.SetBarFrameArt(blockFrame, "BORDER")

-- The background overflows the frame. The source declares it after the frame but in a
-- lower sublevel, so it draws below; 3.3.5 has no sublevels, so it uses a lower layer.
blockBackground:SetPoint("TOPLEFT", blockFrame, "TOPLEFT", -13, 0)
blockBackground:SetPoint("BOTTOMRIGHT", blockFrame, "BOTTOMRIGHT", 14, 4)

local microButtons = {}

-- Shows the normal or pushed art of a micro button entry, from its button state.
local function applyMicroState(entry)
	local button = entry.button
	local pressed = button:GetButtonState() == "PUSHED"

	if pressed then
		entry.background:Hide()
		entry.pressedBackground:Show()
	else
		entry.background:Show()
		entry.pressedBackground:Hide()
	end

	if entry.pressedShadow then
		if pressed then
			entry.pressedShadow:Show()
		else
			entry.pressedShadow:Hide()
		end
	end


	-- tabard emblem: CENTER (0, 2), pushed (1, 1)
	if entry.emblem then
		for _, t in ipairs({ entry.emblem, entry.emblemHover }) do
			t:ClearAllPoints()
			t:SetPoint("CENTER", button, "CENTER", pressed and 1 or 0, pressed and 1 or 2)
		end
	end

	-- CharacterMicroButton_SetPushed changes the portrait crop; camelot keeps the same crop
	-- in both states.
	if entry.portrait and MicroButtonPortrait then
		MicroButtonPortrait:SetTexCoord(0.2, 0.8, 0.0666, 0.9)
	end

	local highlight = button:GetHighlightTexture()
	if highlight and entry.atlasSet then
		if pressed then
			if ForeverUI.SetAtlas(highlight, microAtlas(entry.atlasSet, "down"), true) then
				highlight:SetBlendMode("ADD")
				highlight:SetAlpha(0.5)
			end
		else
			if ForeverUI.SetAtlas(highlight, microAtlas(entry.atlasSet, "mouseover"), true) then
				highlight:SetBlendMode("BLEND")
				highlight:SetAlpha(1)
			end
		end
	end
end

-- Latency bar of the game menu button. Camelot anchors it at (0, -2); here the strip
-- frame's inner edge covers the button bottom, so it is anchored at (0, 0).
-- The bar's line is rows 58-59 of the 64-row image. The height gives each row 1.5 screen
-- pixels, so the line is 3 pixels thick; the width stays camelot's 19.
-- Pixels come from gxResolution and the button's effective scale.
local LATENCY = { rows = 64, pixelsPerLine = 1.5, width = 19 }
local function pixelsPerUnit(frame)
	local h = tonumber(string.match(GetCVar("gxResolution") or "", "%d+x(%d+)")) or 768
	return h / 768 * frame:GetEffectiveScale()
end

local function placeLatency(button)
	MainMenuBarPerformanceBar:SetWidth(LATENCY.width)
	MainMenuBarPerformanceBar:SetHeight(LATENCY.rows * LATENCY.pixelsPerLine / pixelsPerUnit(button))
	MainMenuBarPerformanceBar:ClearAllPoints()
	MainMenuBarPerformanceBar:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
end

-- Roles of created micro buttons: tooltip and click.
-- ProfessionMicroButtonMixin (mainline/mainmenubarmicrobuttons.lua): tooltip
-- MicroButtonTooltipText(PROFESSIONS_BUTTON, TOGGLEPROFESSIONBOOK); PROFESSIONS_BUTTON is
-- TRADE_SKILLS in 3.3.5, which has no such key binding.
-- Tooltip and textures are set like the client's micro buttons (MainMenuBarMicroButton
-- OnEnter, GameTooltip_AddNewbieTip), then skinMicro re-skins them.
-- A button added by another addon carries its own tooltip (text or function) and click.
local MICRO_ROLES = {
	professions = {
		tooltip = function() return MicroButtonTooltipText(TRADE_SKILLS, "TOGGLEPROFESSIONBOOK") end,
		onClick = function()
			if ForeverUI.ProfessionsBook then ForeverUI.ProfessionsBook.Toggle() end
		end,
	},
}

local function createMicro(definition)
	local role = MICRO_ROLES[definition.create] or definition
	local tooltip = role.tooltip
	if type(tooltip) ~= "function" then
		local text = tooltip
		tooltip = function() return text end
	end
	local parent = (CharacterMicroButton and CharacterMicroButton:GetParent()) or micro
	local button = CreateFrame("Button", definition.name, parent)
	for state, method in pairs(MICRO_STATES) do
		local e = ForeverUI.AtlasEntry(microAtlas(definition.atlasSet, state))
		if e then
			button[string.gsub(method, "^Get", "Set")](button, e[1])
		end
	end
	button:RegisterForClicks("AnyUp")
	button.tooltipText = tooltip()
	button:SetScript("OnEnter", function(self)
		self.tooltipText = tooltip()
		GameTooltip_AddNewbieTip(self, self.tooltipText, 1.0, 1.0, 1.0, self.newbieText)
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetScript("OnClick", role.onClick)
	return button
end

-- Skins a micro button with camelot art and places it in the strip; creates it if needed.
-- index: 1-based slot in the strip
local function skinMicro(definition, index)
	if definition.create and not _G[definition.name] then
		createMicro(definition)
	end
	local button = _G[definition.name]
	if not button then
		return nil
	end

	button:SetWidth(MICRO_W)
	button:SetHeight(MICRO_ART_H)
	-- 3.3.5 makes the top 18 px ignore the mouse (decor of the old button art); undo that.
	button:SetHitRectInsets(0, 0, 0, 0)
	-- Buttons overlap by 5 px: the right one draws on top.
	if MainMenuBarArtFrame then
		button:SetFrameLevel(MainMenuBarArtFrame:GetFrameLevel() + index)
	end

	local entry = { button = button, atlasSet = definition.atlasSet, portrait = definition.portrait, created = definition.create }

	entry.background = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(entry.background, "ui-hud-micromenu-buttonbg-up-c60-2x", true)
	entry.background:SetAllPoints(button)

	entry.pressedBackground = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(entry.pressedBackground, "ui-hud-micromenu-buttonbg-down-c60-2x", true)
	entry.pressedBackground:SetAllPoints(button)
	entry.pressedBackground:Hide()

	if definition.atlasSet then
		for state, method in pairs(MICRO_STATES) do
			local texture = button[method] and button[method](button)
			if texture then
				ForeverUI.SetAtlas(texture, microAtlas(definition.atlasSet, state), true)
				texture:ClearAllPoints()
				texture:SetAllPoints(button)
			end
		end
	else
		-- The portrait button has no icon set: hide the client's textures and let camelot's
		-- background do all the drawing.
		for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
			local texture = button[method] and button[method](button)
			if texture then
				texture:SetAlpha(0)
			end
		end
		local highlight = button:GetHighlightTexture()
		if highlight then
			ForeverUI.SetAtlas(highlight, "ui-hud-micromenu-buttonbg-down-c60-2x", true)
			highlight:ClearAllPoints()
			highlight:SetAllPoints(button)
			highlight:SetBlendMode("ADD")
			highlight:SetAlpha(0.4)
		end
	end

	if definition.portrait then
		local shadow = button:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(shadow, "ui-hud-micromenu-portrait-shadow-2x", true)
		shadow:SetAllPoints(button)
		entry.shadow = shadow

		if MicroButtonPortrait then
			-- The source insets the portrait 7 px on a 32 x 40 button, i.e. 18 x 26. Keep that
			-- size: following the button height would stretch the face.
			MicroButtonPortrait:SetDrawLayer("ARTWORK")
			MicroButtonPortrait:ClearAllPoints()
			MicroButtonPortrait:SetWidth(MICRO_W - 14)
			MicroButtonPortrait:SetHeight(MICRO_H - 14)
			MicroButtonPortrait:SetPoint("CENTER", button, "CENTER", 0, 0)
			MicroButtonPortrait:SetTexCoord(0.2, 0.8, 0.0666, 0.9)
		end

		local pressedShadow = button:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(pressedShadow, "ui-hud-micromenu-portrait-down-2x", true)
		pressedShadow:SetWidth(MICRO_W)
		pressedShadow:SetHeight(MICRO_ART_H)
		pressedShadow:SetPoint("CENTER", button, "CENTER", 1, -4)
		pressedShadow:Hide()
		entry.pressedShadow = pressedShadow
	end

	if definition.name == "MainMenuMicroButton" and MainMenuBarPerformanceBar then
		-- camelot image (32 x 64, a line at the bottom); the 3.3.5 one is a 16 x 8 block
		-- that stretches into a big green square
		MainMenuBarPerformanceBar:SetTexture(PERFORMANCE_IMAGE)
		placeLatency(button)
		-- the pixel size changes with the screen or the scale
		local latencyWatcher = CreateFrame("Frame")
		latencyWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
		latencyWatcher:RegisterEvent("UI_SCALE_CHANGED")
		latencyWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
		latencyWatcher:SetScript("OnEvent", function() placeLatency(button) end)
		-- 3.3.5 re-anchors the bar on every push and release (MainMenuMicroButton_SetPushed /
		-- _SetNormal: SetPoint TOPLEFT (9, -36) / (10, -34), without ClearAllPoints). That
		-- anchor adds to ours and squeezes the image to 12 x 12, so ours is re-applied after
		-- them; camelot does not move the bar when the button is pushed.
		for _, name in ipairs({ "MainMenuMicroButton_SetPushed", "MainMenuMicroButton_SetNormal" }) do
			if _G[name] then
				hooksecurefunc(name, function() placeLatency(button) end)
			end
		end
	end

	button:ClearAllPoints()
	button:SetPoint("LEFT", micro, "LEFT", (index - 1) * MICRO_PITCH, 0)

	return entry
end

local microCount = 0
for index, definition in ipairs(MICRO) do
	local entry = skinMicro(definition, index)
	if entry then
		table.insert(microButtons, entry)
		microCount = index
	end
end
local BUTTONS_WIDTH = microCount * MICRO_W + (microCount - 1) * MICRO_PADDING

-- Guild tabard on the Social button (camelot: GuildMicroButtonMixin:UpdateTabard).
-- With a tabard: the GuildCommunities-GuildColor set tinted with the tabard background,
-- and the 12 x 14 emblem at CENTER (0, 2), (1, 1) pushed, in OVERLAY and HIGHLIGHT, cut
-- from GuildEmblems_01 (SetSmallGuildTabardTextures: 18/256 cells, 14 per row, inset
-- 1/256) and tinted with the emblem color. Without a tabard: the plain GuildCommunities set.
-- 3.3.5 lacks C_GuildInfo.GetGuildTabardInfo; GetGuildTabardFileNames only returns texture
-- names (Background_<bg>_TU_U, Emblem_<motif>_<color>_TU_U). The motif is the cell index on
-- the sheet; colors come from TabardColors.lua (tools/tabard_colors.py).
local EMBLEM_SHEET = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildframe" .. SEP .. "guildemblems_01"
local EMBLEM_CELL, EMBLEM_COLUMNS, EMBLEM_EDGE = 18 / 256, 14, 1 / 256

-- Returns background color, emblem cell index and emblem color; nil without a readable
-- tabard.
local function guildTabard()
	if not (GetGuildTabardFileNames and IsInGuild and IsInGuild()) then return nil end
	local background, _, emblem = GetGuildTabardFileNames()
	if not background or not emblem then return nil end
	local f = tonumber(string.match(string.lower(background), "background_(%d+)"))
	local motif, color = string.match(string.lower(emblem), "emblem_(%d+)_(%d+)")
	local colors = ForeverUI.TabardColors
	if not (f and motif and colors) then return nil end
	local cf, ce = colors.background[f], colors.emblem[tonumber(color)]
	if not (cf and ce) then return nil end
	return cf, tonumber(motif), ce
end

local social
for _, entry in ipairs(microButtons) do
	if entry.button:GetName() == "SocialsMicroButton" then social = entry end
end

if social then
	social.baseSet = social.atlasSet
	social.emblem = social.button:CreateTexture(nil, "OVERLAY")
	social.emblemHover = social.button:CreateTexture(nil, "HIGHLIGHT")
	for _, t in ipairs({ social.emblem, social.emblemHover }) do
		t:SetTexture(EMBLEM_SHEET)
		t:SetWidth(12)
		t:SetHeight(14)
		t:SetPoint("CENTER", social.button, "CENTER", 0, 2)
		t:Hide()
	end
end

-- After an emblem change, GetGuildTabardFileNames returns nothing at GUILDTABARD_UPDATE
-- until the new guild data arrives, and no event follows that arrival. So in a guild an
-- unreadable tabard keeps the current look, and the tabard is re-read every
-- RECHECK_INTERVAL s, RECHECK_COUNT times after each event; the last read decides
-- (no tabard: base set).
local RECHECK_INTERVAL, RECHECK_COUNT = 0.5, 20
local rechecker = CreateFrame("Frame")
rechecker:Hide()
ForeverUI.TabardReread = rechecker

-- Applies the tabard look (values from guildTabard); nil background restores the base set.
local function applyTabard(background, motif, color)
	social.atlasSet = background and (social.baseSet .. "-guildcolor") or social.baseSet
	for state, method in pairs(MICRO_STATES) do
		local texture = social.button[method] and social.button[method](social.button)
		if texture and ForeverUI.SetAtlas(texture, microAtlas(social.atlasSet, state), true) then
			if background then
				texture:SetVertexColor(background[1], background[2], background[3])
			else
				texture:SetVertexColor(1, 1, 1)
			end
		end
	end
	if background then
		local x = (motif % EMBLEM_COLUMNS) * EMBLEM_CELL
		local y = math.floor(motif / EMBLEM_COLUMNS) * EMBLEM_CELL
		for _, t in ipairs({ social.emblem, social.emblemHover }) do
			t:SetTexCoord(x + EMBLEM_EDGE, x + EMBLEM_CELL - EMBLEM_EDGE, y + EMBLEM_EDGE, y + EMBLEM_CELL - EMBLEM_EDGE)
			t:SetVertexColor(color[1], color[2], color[3])
			t:Show()
		end
	else
		social.emblem:Hide()
		social.emblemHover:Hide()
	end
	applyMicroState(social)
end

-- GuildMicroButtonMixin:UpdateTabard; isFinal: last re-read, applies even without a tabard
function ForeverUI.UpdateSocialTabard(isFinal)
	if not social then return end
	local background, motif, color = guildTabard()
	local inGuild = IsInGuild and IsInGuild()
	if background or isFinal or not inGuild then
		applyTabard(background, motif, color)
	end
end

rechecker:SetScript("OnUpdate", function(self, elapsed)
	self.pending = (self.pending or 0) + elapsed
	if self.pending < RECHECK_INTERVAL then return end
	self.pending = 0
	self.remaining = (self.remaining or 0) - 1
	local finish = self.remaining <= 0
	ForeverUI.UpdateSocialTabard(finish)
	if finish then self:Hide() end
end)

local tabardWatcher = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_GUILD_UPDATE", "GUILDTABARD_UPDATE" }) do
	tabardWatcher:RegisterEvent(ev)
end
tabardWatcher:SetScript("OnEvent", function()
	ForeverUI.UpdateSocialTabard()
	rechecker.remaining, rechecker.pending = RECHECK_COUNT, 0
	rechecker:Show()
end)
micro:SetWidth(BUTTONS_WIDTH)

-- Remove the client's PvP button (PvP opens from the character sheet). Hiding is not
-- enough: UpdateMicroButtons and VehicleMenuBar_MoveMicroButtons show it again.
ForeverUI.Suppress(_G["PVPMicroButton"])

-- Remove the client's Help button; Help moves to the Esc menu (camelot: GAMEMENU_SUPPORT),
-- between AddOns and Log Out with a gap on each side. AddOns is ACP (patch-5.mpq), under
-- Macros; it re-anchors Log Out under itself on every show, so we re-place after its
-- OnShow. Without ACP, Help goes under Macros. The gap is the one the client menu leaves
-- before Return to Game (16, GameMenuFrame.xml). A plain button: a secure one would make
-- the whole Esc menu protected.
local MENU_GAP = 16
ForeverUI.Suppress(_G["HelpMicroButton"])
if GameMenuFrame and GameMenuButtonMacros and GameMenuButtonLogout then
	local help = CreateFrame("Button", "ForeverUIGameMenuButtonHelp", GameMenuFrame, "GameMenuButtonTemplate")
	help:SetText(HELP_BUTTON)
	help:SetScript("OnClick", function()
		PlaySound("igMainMenuOption")
		HideUIPanel(GameMenuFrame)
		ToggleHelpFrame()
	end)
	local function place()
		help:ClearAllPoints()
		help:SetPoint("TOP", _G["GameMenuButtonAddOns"] or GameMenuButtonMacros, "BOTTOM", 0, -MENU_GAP)
		GameMenuButtonLogout:SetPoint("TOP", help, "BOTTOM", 0, -MENU_GAP)
	end
	-- ACP loads before us (alphabetical order); if it loads later, hook it as soon as it
	-- arrives, before the menu is first opened
	local hooked = false
	local function attachACP()
		local acp = _G["GameMenuButtonAddOns"]
		if acp and not hooked and acp.HookScript then
			hooked = true
			acp:HookScript("OnShow", place)
		end
		place()
	end
	attachACP()
	local acpWatcher = CreateFrame("Frame")
	acpWatcher:RegisterEvent("ADDON_LOADED")
	acpWatcher:SetScript("OnEvent", function(self)
		attachACP()
		if hooked then self:UnregisterEvent("ADDON_LOADED") end
	end)
	-- The client places Log Out 1 below its neighbour; add Help and two gaps
	GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + help:GetHeight() + 2 * MENU_GAP - 1)
end

-- Buttons run from the strip's LEFT edge (camelot: layoutFramesGoingRight).
-- Re-applied after VehicleMenuBar_MoveMicroButtons, which re-anchors CharacterMicroButton
-- and SocialsMicroButton on every vehicle enter or exit (MainMenuBar_ToPlayerArt /
-- _ToVehicleArt). In a vehicle the client moves its buttons to VehicleMenuBarArtFrame;
-- created buttons follow, with frame levels counted from CharacterMicroButton.
local function layoutMicro()
	for index, entry in ipairs(microButtons) do
		if entry.created and CharacterMicroButton then
			local parent = CharacterMicroButton:GetParent()
			if entry.button:GetParent() ~= parent then
				entry.button:SetParent(parent)
			end
			entry.button:SetFrameLevel(CharacterMicroButton:GetFrameLevel() + index - 1)
		end
		entry.button:ClearAllPoints()
		entry.button:SetPoint("LEFT", micro, "LEFT", (index - 1) * MICRO_PITCH, 0)
	end
end

-- Pushes a created button while its window is open.
-- role: create role, or the button name for one added by another addon
function ForeverUI.UpdateMicro(role, isOpen)
	for _, entry in ipairs(microButtons) do
		if entry.created == role then
			if isOpen then
				entry.button:SetButtonState("PUSHED", 1)
			else
				entry.button:SetButtonState("NORMAL")
			end
			applyMicroState(entry)
		end
	end
end

-- professions button: pushed while the book or the crafting page is open
-- (ProfessionsBook.lua)
function ForeverUI.UpdateProfessionsMicro(isOpen)
	ForeverUI.UpdateMicro("professions", isOpen)
end

layoutMicro()

if hooksecurefunc and type(_G["VehicleMenuBar_MoveMicroButtons"]) == "function" then
	hooksecurefunc("VehicleMenuBar_MoveMicroButtons", layoutMicro)
end

-- ------------------------------------------------------ Bags bar
local bags = CreateFrame("Frame", "ForeverUIBagsBar", UIParent)
bags:SetHeight(BAG_SIZE)
bags:SetWidth(5 * BAG_SIZE + KEYRING_W + 5 * BAG_PADDING)

local bagsFrame = CreateFrame("Frame", nil, bags)
bagsFrame:SetPoint("TOPLEFT", -6, 6)
bagsFrame:SetPoint("BOTTOMRIGHT", 5, -5)
bagsFrame:SetFrameLevel(bags:GetFrameLevel())
ForeverUI.SetBarFrameArt(bagsFrame)

-- Skins a bag slot with a camelot frame.
-- frameAtlas: frame art; frameWidth: art width (KEYRING_W for the keyring)
local function skinBag(button, frameAtlas, frameWidth)
	if not button then
		return false
	end

	button:SetWidth(frameWidth == KEYRING_W and KEYRING_W or BAG_SIZE)
	button:SetHeight(BAG_SIZE)

	local normalFont = button:GetNormalTexture()
	if normalFont then
		ForeverUI.SetAtlas(normalFont, frameAtlas, true)
		normalFont:SetWidth(frameWidth)
		normalFont:SetHeight(BAG_FRAME_H)
		normalFont:ClearAllPoints()
		normalFont:SetPoint("TOPLEFT", button, "TOPLEFT")
	end

	local pushed = button:GetPushedTexture()
	if pushed then
		ForeverUI.SetAtlas(pushed, frameAtlas, true)
		pushed:SetWidth(frameWidth)
		pushed:SetHeight(BAG_FRAME_H)
		pushed:ClearAllPoints()
		pushed:SetPoint("TOPLEFT", button, "TOPLEFT")
	end

	local highlight = button:GetHighlightTexture()
	if highlight then
		ForeverUI.SetAtlas(highlight, frameAtlas, true)
		highlight:ClearAllPoints()
		highlight:SetAllPoints(button)
		highlight:SetBlendMode("ADD")
		highlight:SetAlpha(0.4)
	end

	-- The 3.3.5 green check does not fit this frame: use the same art in ADD, as on the
	-- action buttons.
	local checked = button.GetCheckedTexture and button:GetCheckedTexture()
	if checked then
		ForeverUI.SetAtlas(checked, frameAtlas, true)
		checked:SetWidth(frameWidth)
		checked:SetHeight(BAG_FRAME_H)
		checked:ClearAllPoints()
		checked:SetPoint("TOPLEFT", button, "TOPLEFT")
		checked:SetBlendMode("ADD")
	end

	local icon = _G[button:GetName() .. "IconTexture"]
	if icon then
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
		icon:SetTexCoord(0, 1, 0, 1)
	end

	return true
end

-- Keyring: a narrower button with its own frame and image.
local keyringIcon
local function skinKeyring()
	local button = KeyRingButton
	if not button then
		return
	end

	skinBag(button, "ui-hud-actionbar-iconframe-small", KEYRING_W)

	if not keyringIcon then
		keyringIcon = button:CreateTexture(nil, "BORDER")
		keyringIcon:SetPoint("CENTER")
	end

	-- Deliberate difference: KeyRingMixin:OnBagUpdate shows the keyring image only when the
	-- showKeyring CVar is on (set by a tutorial on the first key looted). In 3.3.5 the
	-- keyring is a permanent part of the bar, so the image is always set.
	-- The -2x variant (54 x 80 texels for 27 x 40 units) stays sharp; the 1x one looks
	-- pixelated because a unit is more than one screen pixel.
	ForeverUI.SetAtlas(keyringIcon, "ui-hud-actionbar-keyring-small-c60-2x")

	-- camelot always keeps this button in the bar; 3.3.5 hides it until the player loots
	-- a key.
	button:Show()
end

-- Keyring fly-in (BaseBagSlotButtonTemplate, mainline/mainmenubarbagbuttontemplates.xml):
-- AnimIcon, OVERLAY, whole button; FlyIn: 1 s, scale 0.125 to 1, alpha 0 to 1, SMOOTH
-- path through (-15, 30) and (-75, 60). KeyRingMixin plays it reversed (FlyIn:Play(true)).
-- 3.3.5 has neither reverse play nor a start scale, so it runs frame by frame. It
-- replaces the 3.3.5 3D animation (KeyRingButtonItemAnim, ForcedBackpackItem.mdx).
local FLIGHT = { duration = 1, scale = 0.125, points = { { 0, 0 }, { -15, 30 }, { -75, 60 } } }

-- Smooth path: Catmull-Rom through the points, end points doubled.
-- q: progress from 0 to 1; returns x, y
local function curve(q)
	local p = FLIGHT.points
	local n = #p - 1
	local s = math.min(n - 1e-9, math.max(0, q * n))
	local i = math.floor(s) + 1
	local u = s - (i - 1)
	local a, b, c, d = p[math.max(1, i - 1)], p[i], p[i + 1], p[math.min(#p, i + 2)]
	local function axis(k)
		return 0.5 * (2 * b[k] + (c[k] - a[k]) * u + (2 * a[k] - 5 * b[k] + 4 * c[k] - d[k]) * u * u
			+ (3 * b[k] - a[k] - 3 * c[k] + d[k]) * u * u * u)
	end
	return axis(1), axis(2)
end

local flight = CreateFrame("Frame")
flight:Hide()
flight:SetScript("OnUpdate", function(self, elapsed)
	self.t = self.t + (elapsed or 0)
	local icon = self.icon
	if self.t >= FLIGHT.duration then
		icon:Hide()
		self:Hide()
		return
	end
	-- reversed: progress goes from 1 to 0
	local q = 1 - self.t / FLIGHT.duration
	local x, y = curve(q)
	local k = FLIGHT.scale + (1 - FLIGHT.scale) * q
	local b = KeyRingButton
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", b, "CENTER", x, y)
	icon:SetWidth(b:GetWidth() * k)
	icon:SetHeight(b:GetHeight() * k)
	icon:SetAlpha(q)
	icon:Show()
end)
flight:RegisterEvent("ITEM_PUSH")
flight:SetScript("OnEvent", function(self, _, bag, texture)
	local b = KeyRingButton
	if not b or bag ~= b:GetID() then
		return
	end
	if not self.icon then
		self.icon = b:CreateTexture(nil, "OVERLAY")
		self.icon:Hide()
	end
	self.icon:SetTexture(texture)
	self.t = 0
	self:Show()
end)
ForeverUI.KeyRingFly = flight
if KeyRingButtonItemAnim then
	KeyRingButtonItemAnim:UnregisterEvent("ITEM_PUSH")
	KeyRingButtonItemAnim:Hide()
end

local BAG_ORDER = {
	"MainMenuBarBackpackButton",
	"CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
}

local cells = {}
local separators = {}

local function layoutBags()
	local previous = nil
	cells = {}

	for _, name in ipairs(BAG_ORDER) do
		local button = _G[name]
		if button then
			skinBag(button, "ui-hud-actionbar-iconframe-bags", BAG_FRAME_W)
			button:ClearAllPoints()
			if previous then
				button:SetPoint("RIGHT", previous, "LEFT", -BAG_PADDING, 0)
			else
				button:SetPoint("RIGHT", bags, "RIGHT", 0, 0)
			end
			previous = button
			table.insert(cells, button)
		end
	end

	skinKeyring()
	if KeyRingButton and previous then
		KeyRingButton:ClearAllPoints()
		KeyRingButton:SetPoint("RIGHT", previous, "LEFT", -BAG_PADDING, 0)
		table.insert(cells, KeyRingButton)
	end

	-- Divider between neighbouring cells: LEFT on the left cell's RIGHT, offset -5, so it
	-- is centred on the 2 px gap.
	for index = 2, #cells do
		if not separators[index] then
			local divider = ForeverUI.CreateDivider(bags, bags:GetFrameLevel() + 2)
			divider:SetPoint("TOP", cells[index], "TOP", 0, 0)
			divider:SetPoint("BOTTOM", cells[index], "BOTTOM", 0, 0)
			divider:SetPoint("LEFT", cells[index], "RIGHT", -5, 0)
			separators[index] = divider
		end
	end
end

-- The backpack uses camelot's icon, a separate file, not an atlas entry
-- (camelot/MainMenuBarBagButtons.xml: bagIcon).
local function setBackpackIcon()
	local icon = MainMenuBarBackpackButtonIconTexture
	if icon then
		icon:SetTexture(BAG_ICON)
		icon:SetTexCoord(0, 1, 0, 1)
	end
end

-- ------------------------------------------------------------ Assembly
-- The row is a chain: the action bar and the bags sit on each side of the micro menu.
-- The chain is turned into screen positions so each element stays movable on its own.
local function applyDefaultPositions()
	local half = micro:GetWidth() / 2
	ForeverUI.Layout.SetDefaults("actionbar", "BOTTOMRIGHT", "BOTTOM",
		MICRO_X - half + BAR_OFFSET_X, MICRO_Y + BAR_OFFSET_Y)
	ForeverUI.Layout.SetDefaults("bags", "BOTTOMLEFT", "BOTTOM",
		MICRO_X + half + BAGS_OFFSET_X, MICRO_Y + BAGS_OFFSET_Y)
end

-- Measures the row for what sits on top of it (status bars).
-- Like the default positions, x counts from the screen centre and y from the bottom.
local function measureRow()
	local half = micro:GetWidth() / 2
	local bar = ForeverUI.ActionBarHolder
	local barRight = MICRO_X - half + BAR_OFFSET_X
	local barLeft = barRight - (bar and bar:GetWidth() or 0)
	local bagsLeft = MICRO_X + half + BAGS_OFFSET_X

	-- Row top is the highest of the three frames: the action bar and bags frames overflow
	-- by 6, the micro menu frame by 8.
	local barTop = MICRO_Y + BAR_OFFSET_Y + BAG_SIZE + 6
	local microTop = MICRO_Y + MICRO_H + 8
	local bagsTop = MICRO_Y + BAGS_OFFSET_Y + BAG_SIZE + 6

	ForeverUI.BottomRow = {
		-- From the action bar's left edge to the bags bar's right edge. The end caps
		-- overflow 30 px on each side, but what sits above aligns on the blocks, not the
		-- griffins.
		left = barLeft,
		right = bagsLeft + bags:GetWidth(),
		top = math.max(barTop, microTop, bagsTop),
	}
end

-- The end caps frame the whole row: left one on the action bar, right one on the bags
-- bar.
local function placeEndCaps()
	local endCaps = ForeverUI.ActionBarEndCaps
	if not endCaps or not endCaps.right then
		return
	end

	endCaps.right:ClearAllPoints()
	-- Same 2 px drop as the left end cap (see ActionBar.lua).
	endCaps.right:SetPoint("BOTTOMLEFT", bags, "BOTTOMRIGHT", -30, -2)
end

local function layoutAll()
	layoutBags()
	setBackpackIcon()
	layoutMicro()
	for _, entry in ipairs(microButtons) do
		applyMicroState(entry)
	end
end

ForeverUI.Layout.Register(micro, "micromenu", L.BOTTOMBAR_EDIT_LABEL_MICROMENU, "BOTTOM", "BOTTOM", MICRO_X, MICRO_Y)
ForeverUI.Layout.Register(bags, "bags", L.BOTTOMBAR_EDIT_LABEL_BAGS, "BOTTOMLEFT", "BOTTOM",
	MICRO_X + micro:GetWidth() / 2 + BAGS_OFFSET_X, MICRO_Y + BAGS_OFFSET_Y)
applyDefaultPositions()
measureRow()
placeEndCaps()
layoutAll()

-- Micro button added by another addon, without ForeverUI knowing that addon.
-- ForeverUI.AddMicroButton(def), def fields:
--   name      global button name; a button already in the strip is returned, never doubled
--   atlasSet  camelot icon set (ui-hud-micromenu-<set>-<state>, c60 first)
--   after     name of the button it follows; default: just before the game menu
--   tooltip   text, or a function returning it (read on hover)
--   onClick   click handler
--   ready     optional, called with the button once placed
-- Returns the button, or nil while waiting for combat to end (the action bar holds
-- secure buttons and cannot move in combat). The strip widens and the action bar and bags
-- move apart (default positions only; a player-chosen position stays); end caps and
-- status bars follow. ForeverUI.UpdateMicro(name, isOpen) pushes or releases it.
local pendingMicro = CreateFrame("Frame")
local queued = {}

local function namedButton(name)
	for _, entry in ipairs(microButtons) do
		if entry.button:GetName() == name then return entry.button end
	end
end

function ForeverUI.AddMicroButton(def)
	if type(def) ~= "table" or type(def.name) ~= "string" then return nil end
	local already = namedButton(def.name)
	if already then return already end
	if InCombatLockdown() then
		queued[def.name] = def
		pendingMicro:RegisterEvent("PLAYER_REGEN_ENABLED")
		return nil
	end
	local definition = { name = def.name, atlasSet = def.atlasSet, create = def.name, tooltip = def.tooltip, onClick = def.onClick }
	local rank, menu
	for index, entry in ipairs(microButtons) do
		local name = entry.button:GetName()
		if def.after and name == def.after then rank = index + 1 end
		if name == "MainMenuMicroButton" then menu = index end
	end
	rank = rank or menu or (#microButtons + 1)
	local entry = skinMicro(definition, rank)
	if not entry then return nil end
	table.insert(microButtons, rank, entry)
	-- following buttons shift one slot: the right one stays on top
	for index = rank + 1, #microButtons do
		local e = microButtons[index]
		if not e.created and MainMenuBarArtFrame then
			e.button:SetFrameLevel(MainMenuBarArtFrame:GetFrameLevel() + index)
		end
	end
	local n = #microButtons
	micro:SetWidth(n * MICRO_W + (n - 1) * MICRO_PADDING)
	applyDefaultPositions()
	measureRow()
	placeEndCaps()
	layoutAll()
	if ForeverUI.StatusBarsLayout then ForeverUI.StatusBarsLayout() end
	if type(def.ready) == "function" then def.ready(entry.button) end
	return entry.button
end

pendingMicro:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	local list = queued
	queued = {}
	for _, def in pairs(list) do ForeverUI.AddMicroButton(def) end
end)

if hooksecurefunc then
	hooksecurefunc("UpdateMicroButtons", function()
		for _, entry in ipairs(microButtons) do
			applyMicroState(entry)
		end
	end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("BAG_UPDATE")
watcher:RegisterEvent("CVAR_UPDATE")
watcher:SetScript("OnEvent", function()
	layoutAll()
end)

-- /fui micro: prints each button's anchor, then for five seconds what the cursor hits.
-- An anchor other than ForeverUIMicroMenu, or an offset that is not a multiple of the
-- pitch, means something moved the buttons (in 3.3.5 only VehicleMenuBar_MoveMicroButtons
-- does, but another addon could). GetMouseFocus shows which frame really gets the click.
function ForeverUI.MicroDebug()
	local say = function(text)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
	end

	say(string.format(L.BOTTOMBAR_MICRO_DEBUG,
		#microButtons, micro:GetWidth() or 0, micro:GetHeight() or 0, MICRO_PITCH))

	for index, entry in ipairs(microButtons) do
		local button = entry.button
		local point, target, _, x, y = button:GetPoint(1)
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"   " .. L.BOTTOMBAR_MICRO_BUTTON,
			index, button:GetName() or "?", tostring(point),
			tostring(target and target.GetName and target:GetName()),
			tostring(x), tostring(y), button:GetWidth() or 0, button:GetHeight() or 0,
			(index - 1) * MICRO_PITCH,
			tostring(button:IsShown()), tostring(button:IsEnabled()),
			button:GetFrameLevel() or 0, button:GetNumPoints() or 0))
	end

	-- For five seconds, report what the cursor really hits.
	local watcher = CreateFrame("Frame")
	local rest, last = 5, nil
	watcher:SetScript("OnUpdate", function(self, elapsed)
		rest = rest - (elapsed or 0)
		local sub = GetMouseFocus and GetMouseFocus()
		local name = sub and sub.GetName and sub:GetName() or L.BOTTOMBAR_NOTHING
		if name ~= last then
			last = name
            DEFAULT_CHAT_FRAME:AddMessage("   " .. L.BOTTOMBAR_UNDER_CURSOR .. name)
		end
		if rest <= 0 then
			self:SetScript("OnUpdate", nil)
		end
	end)
	say(L.BOTTOMBAR_HOVER_PROMPT)
end

-- Pure containers do not take the mouse. MainMenuBar is enableMouse=true and covers the
-- whole bottom of the screen, so it swallows clicks meant for the buttons. Its children
-- (action buttons, micro buttons) keep their mouse.
for _, name in ipairs({ "MainMenuBar", "MainMenuBarArtFrame" }) do
	local frame = _G[name]
	if frame and frame.EnableMouse then
		frame:EnableMouse(false)
	end
end

ForeverUI.MicroButtons = microButtons
ForeverUI.BagsCells = cells
ForeverUI.BagsDividers = separators

ForeverUI.BottomBarDebug = function()
	local point, _, relativePoint, x, y = bags:GetPoint(1)
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccffForeverUI|r " .. L.BOTTOMBAR_DEBUG,
		micro:GetWidth(), micro:GetHeight(), #microButtons,
		bags:GetWidth(), bags:GetHeight(),
		tostring(point), tostring(relativePoint), x or 0, y or 0,
		tostring(KeyRingButton and KeyRingButton:IsShown())))
end
