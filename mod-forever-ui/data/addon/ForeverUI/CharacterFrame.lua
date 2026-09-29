-- ForeverUI: the character sheet in Camelot's layout: metal frame, left pane (model, gear
-- slots), right pane (stats, gear manager, titles) and a column of side tabs on the right.
-- Client frames (slots, tabs, model, stat rows) are resized and moved, never recreated, and
-- never in combat. Debug commands: /fui character, /fui tabs, /fui close, /fui model.

-- camelot: CHARACTER_FRAME_WIDTH/HEIGHT; LeftPaneHost 398 (the collapsed width), RightPaneHost 233
local WIDTH, HEIGHT = 631, 484
local LEFT_PANE, RIGHT_PANE = 398, 233
local L = ForeverUI.L

-- Right pane collapse button (camelot $parentRightPaneToggleButton: 28 x 28 at TOPRIGHT
-- (-6, -6) of the left pane). Collapsed, the window is the left pane's width; the side tabs
-- are anchored to the window edge and stay visible. 3.3.5 has no CVar for the state (kept in
-- ForeverUIDB) and no SOUNDKIT (sounds are named by string).
local COLLAPSE_SIZE = 28
local COLLAPSE_X, COLLAPSE_Y = -6, -6
local COLLAPSE_ART = {
	expanded = { "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
	           "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down" },
	collapsed = { "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
	           "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down" },
}
local COLLAPSE_HOVER = "Interface\\Buttons\\UI-Common-MouseHilight"

local OVERHEAD = 20                       -- panes start below the title bar
local ART_LEVEL = 5                    -- frame level offset of the metal art, above the panes

-- Metal frame corner offsets. The camelot layout (PortraitFrameTemplate plus
-- NineSliceLayoutOverrides.lua) places the image's outer edge, which leaves the inner rim
-- 6 px inside the window. Each offset here is the rim-to-edge distance measured on the art
-- (uiframemetal2xc60, double density): left 18.5, right 8.5, bottom 14. The top keeps 16:
-- the title bar is inside by design. PANEL_RISE lifts the whole frame by 1 px.
local PANEL_RISE = 1
local PANEL_CORNERS = {
	topLeftCorner = { x = -18.5, y = 16 + PANEL_RISE },
	topRightCorner = { x = 8.5, y = 16 + PANEL_RISE },
	bottomLeftCorner = { x = -18.5, y = -14 + PANEL_RISE },
	bottomRightCorner = { x = 8.5, y = -14 + PANEL_RISE },
}

local SLOT_SIZE = 40

-- Slot layout (camelot/PaperDollFrame.xml): columns at (24, -60) and (-20, -60), main hand at
-- BOTTOM (-60, 30), the variant used when a ranged slot is shown (always, in 3.3.5).
-- The source gap is 6 both ways; the columns use 2 px less, the weapon row keeps 6.
local GAP = 6
local VERTICAL_GAP = GAP - 2
local LEFT_X, LEFT_Y = 24, -60
local RIGHT_X, RIGHT_Y = -20, -60
local WEAPON_X, WEAPON_Y = -60, 30
local SMALL_SLOT_SIZE = 27                        -- ammo slot only; camelot: 27, AMMO_GAP 19 after the ranged slot
local AMMO_GAP = 19

-- The ranged slot is full size, unlike camelot's 27 px GearSlotSmall: it holds a ranged weapon
-- or a relic, items of the same rank as the melee weapons.

-- Right pane tabs (camelot PaperDollSidebarTabs: 42 x 42 buttons, bar at TOP (0, -4) of the
-- pane, tabs at (0, -5) of the bar): stats, gear manager and titles (from mainline; camelot
-- has no titles tab). 3.3.5 lacks PaperDollSidebarTabs.blp and the PAPERDOLL_SIDEBAR_* strings:
-- the gear tab uses UI-GearManager-Button, the tooltips CHARACTER_INFO and EQUIPMENT_MANAGER.
local PANE_TAB = 42
local PANE_TAB_Y = -9               -- bar at -4, first tab at -5 inside it

-- Each visible side tab sits at BOTTOMLEFT (0, -2) of the previous visible one
-- (camelot CharacterFrame.lua, UpdateTabLayout).
local TAB_GAP = -2

-- Side tab icons (camelot CHARACTER_MODE_TAB_ICONS and SetupModeTabs), baked with the tab mask.
-- Indexes are the 3.3.5 ones: 1 character, 2 pet, 3 reputation, 4 skills, 5 currency; pvp and
-- stats are tabs we create (CHARACTERFRAME_SUBFRAMES has only five). The PvP icon follows the
-- faction. Some files exist only by FileDataID: tools/simple_files.txt maps them to names.
local TAB_ICONS = {
	[3] = "Interface\\ForeverUI\\TabIcons\\Inv_SideTab_Reputation2_c60",
	[4] = "Interface\\ForeverUI\\TabIcons\\Ability_Racial_JackofAllTrades",
	[5] = "Interface\\ForeverUI\\TabIcons\\Inv_SideTab_Currency_c60",
	pvp = {
		Alliance = "Interface\\ForeverUI\\TabIcons\\Inv_SideTab_Honor_Alliance_c60",
		Horde = "Interface\\ForeverUI\\TabIcons\\Inv_SideTab_Honor_Horde_c60",
	},
	stats = "Interface\\ForeverUI\\TabIcons\\Inv_SideTab_Stats_c60",
}

-- Pet tab icon by class (camelot has no pet tab); the hunter one otherwise, e.g. for a mage
-- with the water elemental glyph
local PET_TAB = {
	HUNTER = "Ability_Hunter_BeastTaming",
	WARLOCK = "Spell_Shadow_SummonImp",
	DEATHKNIGHT = "Spell_Shadow_AnimateDead",
}
TAB_ICONS[2] = "Interface\\ForeverUI\\TabIcons\\"
	.. (PET_TAB[select(2, UnitClass("player")) or ""] or PET_TAB.HUNTER)

-- Column order: camelot's (character, reputation, skills, PvP, currency, stats) with the 3.3.5
-- pet tab second. A number is a client tab, a string one of ours.
local TAB_ORDER = { 1, 2, 3, 4, "pvp", 5, "stats" }

-- Character tab icon: the class icon (camelot uses the player portrait), one baked file per
-- class, named after UnitClass's token (WARRIOR, DEATHKNIGHT). MPQ lookups ignore case.
local CLASS_TAB = "Interface\\ForeverUI\\TabIcons\\ClassIcon_"

-- Screen opened by each client tab (CharacterFrameTab_OnClick); tells which tab is active
local TAB_SCREEN = {
	[1] = "PaperDollFrame",
	[2] = "PetPaperDollFrame",
	[3] = "ReputationFrame",
	[4] = "SkillFrame",
	[5] = "TokenFrame",
}

-- Our two screens, used as ForeverUI.Panes group names; they are not client subframes
local PVP_SCREEN = "ForeverUIPvPPane"
local STATS_SCREEN = "ForeverUIStatsPane"
local TAB_CREATED_SCREENS = { pvp = PVP_SCREEN, stats = STATS_SCREEN }
-- Right pane tab icon: 28 px, the opening of UI-Character-Info-StatTab (metal at 3..6 and
-- 35..38 of 42). A portrait fills its texture and would overflow the rounded frame.
local PANE_TAB_ICON = 28
local ATLAS_PANE_TAB = "ui-character-info-stattab"
local ATLAS_PANE_TAB_SELECTED = "ui-character-info-stattab-selected"
local TAB_PORTRAIT_COORD = { 0.109375, 0.890625, 0.09375, 0.90625 }
local GEAR_MANAGER_ICON = "Interface\\PaperDollInfoFrame\\UI-GearManager-Button"

-- UI-GearManager-Button is opaque only in x 6..58 of 64: crop the central 52 x 52 square
local GEAR_MANAGER_ICON_COORD = { 6 / 64, 58 / 64, 6 / 64, 58 / 64 }

-- Titles tab icon: mainline PAPERDOLL_SIDEBARTAB_TITLES (camelot has no titles tab). The sheet
-- is not in 3.3.5 and ships with ForeverUI; the crop is the sealed scroll.
local TITLES_ICON =
	"Interface\\ForeverUI\\PaperDollInfoFrame\\paperdollsidebartabs"
local TITLES_ICON_COORD = { 0.015625, 0.53125, 0.32421875, 0.46093750 }

local STONE_HEIGHT = 85               -- UI-Character-Info-Stat-StoneBG
local SEPARATOR_WIDTH = 11
local SEPARATOR_CAP = 4             -- cap height; the art is 11 x 50 with a cap at each end

local TABS_W, TABS_H = 64, 384    -- CharacterFrameModeTabs
local TABS_X = 1                     -- 1 px right of the source
local TABS_Y = -30
local TAB_W, TAB_H = 55, 55       -- 55 x 60 minus 5 transparent px
-- Side tab icon (camelot SidePanelTabButtonMixin:UpdateIconInterior, fillToInterior): 50 px,
-- cropped by 0.03125, offset (-3, 0) since the tab art is transparent on the right.
-- 3.3.5 has no MaskTexture: tools/bake_masks.py bakes common-sidetab-mask into the icons
-- (TabIcons/). The bake assumes this size and crop.
local SIDE_TAB_ICON = 50         -- interiorExtent
local TAB_ICON_X = -3               -- GetIconAnchorOffsetsForTabArt
local TAB_PORTRAIT_INSET = 0.03125         -- UpdateIconInterior crop

-- Side tab layers (LargeSideTabButtonTemplate): BACKGROUND common-sidetab, ARTWORK icon,
-- OVERLAY common-sidetab-selected for the active tab, HIGHLIGHT common-sidetab-hover.

local PORTRAIT = 48                     -- see placePortrait

-- The portrait follows the top-left corner image, which carries the ring: the hole's center is
-- at (38, -38.5) from the image's top-left (measured on the double-density art).
local PORTRAIT_HOLE_X, PORTRAIT_HOLE_Y = 38, -38.5
local PORTRAIT_X = PANEL_CORNERS.topLeftCorner.x + PORTRAIT_HOLE_X
local PORTRAIT_Y = PANEL_CORNERS.topLeftCorner.y + PORTRAIT_HOLE_Y

-- Title (TitledPanelMixin:SetTitleOffsets defaults, which CharacterFrame keeps): container at
-- TOPLEFT (58, -1) and TOPRIGHT (-24, -1), text at TOP (0, -5). It is centered between the
-- portrait and the close button, not on the window; one line.
local TITLE_LEFT, TITLE_RIGHT = 58, -24
local TITLE_CONTAINER, TITLE_TEXT = -1, -5
local TITLE_STRIP_HEIGHT = 20

-- The title always shows the character's name and title (camelot shows the open panel's name).

-- Level and class line in the right pane (camelot PaperDollLevelInfo: 220 x 20 at TOP (0, -50)
-- of the tab bar, itself at (0, -4) of the pane).
local LEVEL_Y = -54
local LEVEL_WIDTH, LEVEL_HEIGHT = 220, 20

-- Model rotation arrows, side by side, centered at the top of the left pane. ROTATION_Y is tuned
-- by eye: camelot has three buttons of another size.
local ROTATION_Y = -12
local ROTATION_GAP = 4

-- The model is raised in its pane: camelot's scene fills the pane, but the 3.3.5 camera frames
-- the character lower. Tuned by eye.
local MODEL_Y = 24

-- Camelot frames the character with a model scene; 3.3.5 has none. This client's Model has
-- SetModelScale, SetPosition, SetCamera and SetFacing, but no SetCameraDistance,
-- SetCamDistanceScale or SetPortraitZoom. SetModelScale shrinks the model around its origin
-- (it slides down); SetPosition(depth, side, height) moves it away without reframing.
-- Values tuned by eye (/fui model); a nil scale leaves the client's scale untouched.
local MODEL_SCALE = nil
local MODEL_POSITION = { -6.5, 0, 0 }   -- depth, side, height

-- Resistances panel offset to the right, added to its original anchor
local RESISTANCES_X = 30

-- Statistics: CharacterAttributesFrame holds two groups of six StatFrameTemplate rows (104 x 13),
-- PlayerStatFrameLeft1..6 and Right1..6, each under a category dropdown. They stay the client's
-- (values, tooltips, menus) and are stacked in one column like camelot, widened to the pane.
-- The client's FrameXML is in patch-enUS-2/3 (patch-enUS-9 is disabled).
local STAT_STEP = 13                     -- StatFrameTemplate height
local STAT_MARGIN = 20                   -- on each side of the pane
local STAT_TOP = 10                    -- below the stone band
local STAT_GROUP_GAP = 16
local STAT_PER_GROUP = 6

-- Category selectors (UIDropDownMenuTemplate): their gold art overflows and does not follow
-- the frame size, so it is hidden and camelot's header replaces it
-- (CharacterStatFrameCategoryTemplate: UI-Character-Info-Title, GameFontHighlight label at
-- (0, 1), 5 px wider than the rows on each side). The menu stays the client's.
-- Height 34, not camelot's 40: the 201 x 32 atlas stretches less.
local STAT_HEADER = 34
local STAT_HEADER_OVERHANG = 5

-- UI-Character-Info-Title is stretched, not sliced: its studs sit in the corners (201 x 32 drawn
-- at 203 x 34). SELECTOR_PIECES: the dropdown regions to hide.
local ATLAS_STAT_HEADER = "ui-character-info-title"
local SELECTOR_PIECES = { "Left", "Middle", "Right", "Text" }

-- Alternating stat row bands (neither camelot nor 3.3.5 has them), from paperdollinfopart1c60:
-- dark UI-Character-Info-ItemLevel-Bounce first, then light UI-Character-Info-Line-Bounce;
-- the count restarts at each category. StatFrameTemplate's label is on BACKGROUND and 3.3.5
-- has no sublevels, so the band would draw over it: the label moves up to ARTWORK.
local ATLAS_STAT_DARK = "ui-character-info-itemlevel-bounce"
local ATLAS_STAT_LIGHT = "ui-character-info-line-bounce"
local STAT_GROUPS = {
	{
		selector = "PlayerStatFrameLeftDropDown",
		prefix = "PlayerStatFrameLeft",
		cvar = "playerStatLeftDropdown",
	},
	{
		selector = "PlayerStatFrameRightDropDown",
		prefix = "PlayerStatFrameRight",
		cvar = "playerStatRightDropdown",
	},
}

local CLOSE_SIZE = 24
local CLOSE_X, CLOSE_Y = 1, 0
local CLOSE_ATLAS = {
	{ atlas = "redbutton-exit", method = "GetNormalTexture" },
	{ atlas = "redbutton-exit-pressed", method = "GetPushedTexture" },
	{ atlas = "redbutton-exit-disabled", method = "GetDisabledTexture" },
	{ atlas = "redbutton-highlight", method = "GetHighlightTexture" },
}

local PORTRAIT_CORNER = "ui-frame-portraitmetal-cornertopleft"

local ATLAS = {
	backgroundLeft = "ui-character-info-general-bg",
	backgroundRight = "ui-character-info-stat-bg",
	stone = "ui-character-info-stat-stonebg",
	separator = "common-framedivider",
	slot = "ui-character-info-gearslot",
	smallSlot = "ui-character-info-gearslotsmall",
	tab = "common-sidetab",
	tabHover = "common-sidetab-hover",
	tabActive = "common-sidetab-selected",
}

local LEFT_COLUMN = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
}
local RIGHT_COLUMN = {
	"Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
}
local WEAPON_ROW = { "MainHand", "SecondaryHand", "Ranged" }

-- Weapon row: extra gap per slot, relative to the left neighbor and cumulative along the chain
-- (main hand 0, off hand -2, ranged -4; the ammo slot follows the ranged one). The ammo arrow
-- is a region of CharacterAmmoSlot and moves with it.
local ROW_OFFSET = { 0, -2, -2 }

-- Frames whose old art is hidden: 3.3.5 spreads it over child frames, which a sweep of
-- CharacterFrame alone misses.
local OLD_FRAMES = {
	"CharacterFrame", "PaperDollFrame", "PetPaperDollFrame", "SkillFrame",
	"ReputationFrame", "HonorFrame", "TokenFrame", "PaperDollItemsFrame",
	"CharacterAttributesFrame", "CharacterAttributesFrameer",
	"CharacterResistanceFrame",
}

-- Saved window positions (ForeverUIDB). The client's panel manager re-places the sheet on each
-- show, so the position saved by dragging is re-applied after it.
local function savedPositions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

local leftPane, rightPane, tabBar
local tabs = {}

-- Hides the texture regions of a frame (not those of its children)
local function sweepTextures(frame)
	if not frame or not frame.GetRegions then
		return
	end

	local regions = { frame:GetRegions() }
	for _, region in ipairs(regions) do
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
end

local function clearLegacyArt()
	for _, name in ipairs(OLD_FRAMES) do
		sweepTextures(_G[name])
	end
end

-- A file added to the .toc loads only after a client restart (/reload does not find new
-- files). If Panes.lua is missing, say so in the chat instead of failing.
local missingReported = false

local function libraryPresent()
	if ForeverUI.Panes then
		return true
	end
	if not missingReported then
		missingReported = true
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r : "
			.. L.CHARACTERFRAME_PANES_MISSING)
	end
	return false
end

-- Creates the left and right panes (backgrounds, stone band, divider) as ForeverUI.Panes hosts
local function setupPanes(frame)
	if leftPane then
		return
	end

	leftPane = CreateFrame("Frame", "ForeverUICharacterLeftPane", frame)
	leftPane:SetWidth(LEFT_PANE)
	leftPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -OVERHEAD)
	leftPane:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)

	local backgroundLeft = leftPane:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(backgroundLeft, ATLAS.backgroundLeft)
	backgroundLeft:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 0, 0)

	rightPane = CreateFrame("Frame", "ForeverUICharacterRightPane", frame)
	rightPane:SetWidth(RIGHT_PANE)
	rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", 0, 0)
	rightPane:SetPoint("BOTTOMLEFT", leftPane, "BOTTOMRIGHT", 0, 0)

	-- The source sets no anchor: the background fills the pane (its atlas is 233 x 383).
	local backgroundRight = rightPane:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(backgroundRight, ATLAS.backgroundRight, true)
	backgroundRight:SetAllPoints(rightPane)

	local stone = rightPane:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(stone, ATLAS.stone)
	stone:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 0, 0)
	rightPane.stone = stone

	-- The divider has a cap at each end, so it is drawn in three slices. It sits one level above
	-- the skin layer (ART_LEVEL), else the metal covers it; that layer does not exist yet here,
	-- hence the constant.
	local separator = ForeverUI.CreateVerticalDivider(rightPane, ATLAS.separator,
		SEPARATOR_CAP, frame:GetFrameLevel() + ART_LEVEL + 1)
	separator:SetWidth(SEPARATOR_WIDTH)
	separator:SetPoint("TOPLEFT", rightPane, "TOPLEFT", -6, -1)
	separator:SetPoint("BOTTOMLEFT", rightPane, "BOTTOMLEFT", -6, 0)
	rightPane.separator = separator

	ForeverUI.CharacterPanes = { left = leftPane, right = rightPane }

	-- Both panes are ForeverUI.Panes hosts: what they show is decided in Panes.lua.
	ForeverUI.Panes.NewHost("left", leftPane)
	ForeverUI.Panes.NewHost("right", rightPane)
end

-- Portrait: the ring's hole crops it, as on the bags (camelot masks a 62 px portrait).
-- Ring profile by radius: 0-12 hole, 13-25 gradient, 26-29 opaque, 30-32 fade. A square of
-- side C reaches C/2 on its axes and C/2 x 1.41 in its corners: 48 reaches opaque metal on the
-- axes (24), with corners at 33.9, just past the ring; 46 would keep the corners inside.
local function placePortrait(frame)
	local host = frame.foreverSkinLayer or frame
	if not frame.foreverPortrait then
		local portrait = host:CreateTexture(nil, "BACKGROUND")
		portrait:SetWidth(PORTRAIT)
		portrait:SetHeight(PORTRAIT)
		portrait:SetPoint("CENTER", host, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
		frame.foreverPortrait = portrait
	end

	if SetPortraitTexture then
		SetPortraitTexture(frame.foreverPortrait, "player")
	end
end

-- Title in a child frame above the metal (camelot: TitleContainer at level 510, NineSlice at
-- 400): the metal is OVERLAY on its own frame.
local function placeTitle(frame)
	if not frame.foreverTitleStrip then
		local old = _G["CharacterNameText"]
		if old then
			old:Hide()
		end

		local strip = CreateFrame("Frame", "ForeverUICharacterTitle", frame)
		strip:SetFrameLevel(frame:GetFrameLevel() + ART_LEVEL + 2)
		strip:SetHeight(TITLE_STRIP_HEIGHT)
		strip:SetPoint("TOPLEFT", frame, "TOPLEFT", TITLE_LEFT, TITLE_CONTAINER)
		strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", TITLE_RIGHT, TITLE_CONTAINER)

		local text = strip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("TOP", strip, "TOP", 0, TITLE_TEXT)
		text:SetPoint("LEFT", strip, "LEFT")
		text:SetPoint("RIGHT", strip, "RIGHT")
		text:SetJustifyH("CENTER")
		frame.foreverTitleStrip = strip
		frame.foreverTitle = text

		-- The title bar is the drag handle
		frame:SetMovable(true)
		frame:SetClampedToScreen(true)
		strip:EnableMouse(true)
		strip:RegisterForDrag("LeftButton")
		strip:SetScript("OnDragStart", function()
			if not InCombatLockdown() then
				frame:StartMoving()
			end
		end)
		strip:SetScript("OnDragStop", function()
			frame:StopMovingOrSizing()
			local point, _, relativePoint, x, y = frame:GetPoint(1)
			if point then
				savedPositions()["sheet"] = {
					point = point, relativePoint = relativePoint, x = x, y = y,
				}
			end
		end)
	end

	-- UnitPVPName gives the name with the current title, if any
	local text = frame.foreverTitle
	local name = (UnitPVPName and UnitPVPName("player")) or UnitName("player")
	text:SetText(name or "")
	if HIGHLIGHT_FONT_COLOR then
		text:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g,
			HIGHLIGHT_FONT_COLOR.b)
	end
end

-- Close button: the client's, with the modern red X, at the top right corner
local function placeCloseButton(frame)
	local close = _G["CharacterFrameCloseButton"]
	if not close then
		return
	end

	close:SetWidth(CLOSE_SIZE)
	close:SetHeight(CLOSE_SIZE)
	close:ClearAllPoints()
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", CLOSE_X, CLOSE_Y)
	close:SetFrameLevel(frame:GetFrameLevel() + ART_LEVEL + 2)

	if frame.foreverCloseSkinned then
		return
	end

	for _, entry in ipairs(CLOSE_ATLAS) do
		local texture = close[entry.method] and close[entry.method](close)
		if texture then
			ForeverUI.SetAtlas(texture, entry.atlas, true)
			texture:ClearAllPoints()
			texture:SetAllPoints(close)
			if entry.atlas == "redbutton-highlight" then
				texture:SetBlendMode("ADD")
			end
		end
	end
	frame.foreverCloseSkinned = true
end

-- Resizes a client gear slot and gives it camelot's slot frame.
-- name: slot name part (Head, Ammo); side: size; frameAtlas: frame art
local function skinSlot(name, side, frameAtlas)
	local button = _G["Character" .. name .. "Slot"]
	if not button then
		return nil
	end

	button:SetWidth(side)
	button:SetHeight(side)

	-- Camelot lays the slots over a model that fills the left pane. The model takes the mouse and
	-- shares the slots' frame level (all PaperDollFrame children); at equal levels the model gets
	-- the click, so the slot goes one level above. Raised only when needed: this runs on each pass.
	local model = _G["CharacterModelFrame"]
	if model and model.GetFrameLevel
		and button:GetFrameLevel() <= model:GetFrameLevel() then
		button:SetFrameLevel(model:GetFrameLevel() + 1)
	end

	if not button.foreverFrame then
		local normalFont = button:GetNormalTexture()
		if normalFont then
			normalFont:SetAlpha(0)
		end

		local frame = button:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(frame, frameAtlas)
		frame:SetPoint("CENTER", button, "CENTER", 0, 0)
		button.foreverFrame = frame
	end

	local icon = _G["Character" .. name .. "SlotIconTexture"]
	if icon then
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
		icon:SetTexCoord(0, 1, 0, 1)
	end

	return button
end

local function placeSlots()
	local previous
	for index, name in ipairs(LEFT_COLUMN) do
		local button = skinSlot(name, SLOT_SIZE, ATLAS.slot)
		if button then
			button:ClearAllPoints()
			if index == 1 then
				button:SetPoint("TOPLEFT", leftPane, "TOPLEFT", LEFT_X, LEFT_Y)
			else
				button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -VERTICAL_GAP)
			end
			previous = button
		end
	end

	previous = nil
	for index, name in ipairs(RIGHT_COLUMN) do
		local button = skinSlot(name, SLOT_SIZE, ATLAS.slot)
		if button then
			button:ClearAllPoints()
			if index == 1 then
				button:SetPoint("TOPRIGHT", leftPane, "TOPRIGHT", RIGHT_X, RIGHT_Y)
			else
				button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -VERTICAL_GAP)
			end
			previous = button
		end
	end

	previous = nil
	for index, name in ipairs(WEAPON_ROW) do
		local button = skinSlot(name, SLOT_SIZE, ATLAS.slot)
		if button then
			button:ClearAllPoints()
			if index == 1 then
				button:SetPoint("BOTTOM", leftPane, "BOTTOM", WEAPON_X, WEAPON_Y)
			else
				button:SetPoint("TOPLEFT", previous, "TOPRIGHT",
					GAP + (ROW_OFFSET[index] or 0), 0)
			end
			previous = button
		end
	end

	local ammo = skinSlot("Ammo", SMALL_SLOT_SIZE, ATLAS.smallSlot)
	if ammo and previous then
		ammo:ClearAllPoints()
		ammo:SetPoint("LEFT", previous, "RIGHT", AMMO_GAP, 0)
	end
end

ForeverUI.ModelSetting = { scale = MODEL_SCALE, position = MODEL_POSITION }

-- Mouse drag rotation for the character and pet models (3.3.5 only rotates them with the arrow
-- buttons). Camelot's orbit camera: 0.008 rad per UI unit of horizontal drag, eased at 0.15
-- per frame (OrbitCameraMixin). Here the model turns through model.rotation and SetRotation.
local MOUSE_ROTATION, ROTATION_SMOOTHING = 0.008, 0.15

local function rotateWithMouse(model)
	if not model or model.foreverMouseHooked then
		return
	end
	model.foreverMouseHooked = true
	model:EnableMouse(true)
	model:HookScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			self.foreverCursor = GetCursorPosition()
			self.foreverTarget = self.foreverTarget or self.rotation or 0
		end
	end)
	model:HookScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			self.foreverCursor = nil
		end
	end)
	model:HookScript("OnHide", function(self)
		self.foreverCursor, self.foreverTarget = nil, nil
	end)
	model:HookScript("OnUpdate", function(self, elapsed)
		if self.foreverCursor then
			local x = GetCursorPosition()
			local d = (x - self.foreverCursor) / UIParent:GetEffectiveScale()
			self.foreverCursor = x
			self.foreverTarget = self.foreverTarget + d * MOUSE_ROTATION
		end
		if not self.foreverTarget then
			return
		end
		local r = self.rotation or 0
		local k = 1 - (1 - ROTATION_SMOOTHING) ^ ((elapsed or 0) * 60)
		r = r + (self.foreverTarget - r) * k
		if math.abs(self.foreverTarget - r) < 0.0005 then
			r = self.foreverTarget
			if not self.foreverCursor then
				self.foreverTarget = nil
			end
		end
		self.rotation = r
		self:SetRotation(r)
	end)
end
ForeverUI.RotateWithMouse = rotateWithMouse
rotateWithMouse(_G["CharacterModelFrame"])
rotateWithMouse(_G["PetModelFrame"])

-- The model loads asynchronously after PaperDollFrame_OnShow's SetUnit, and the load resets its
-- transform. The setting is re-applied every frame for 1.5 s after each pass, without
-- comparing: GetPosition may not match what is drawn.
local MODEL_RECHECK_TIME = 1.5

local modelRecheck = CreateFrame("Frame", "ForeverUICharacterModelRecheck")
modelRecheck:Hide()
modelRecheck.rest = 0

local function applyModelSetting()
	local model = _G["CharacterModelFrame"]
	if not model then
		return
	end

	local setting = ForeverUI.ModelSetting
	if model.SetModelScale and setting.scale then
		model:SetModelScale(setting.scale)
	end
	if model.SetPosition and setting.position then
		model:SetPosition(setting.position[1], setting.position[2], setting.position[3])
	end
end

modelRecheck:SetScript("OnUpdate", function(self, elapsed)
	applyModelSetting()
	self.rest = self.rest - (elapsed or 0)
	if self.rest <= 0 then
		self:Hide()
	end
end)


local function placeModel()
	local model = CharacterModelFrame
	if not model then
		return
	end

	model:ClearAllPoints()
	model:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 0, MODEL_Y)
	model:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", 0, MODEL_Y)

	-- Now, then every frame until the model has loaded
	applyModelSetting()
	modelRecheck.rest = MODEL_RECHECK_TIME
	modelRecheck:Show()

	-- Rotation arrows, side by side, centered on the pane
	local left = _G["CharacterModelFrameRotateLeftButton"]
	local right = _G["CharacterModelFrameRotateRightButton"]
	if left and right then
		local half = left:GetWidth() / 2 + ROTATION_GAP / 2

		left:ClearAllPoints()
		left:SetPoint("TOP", leftPane, "TOP", -half, ROTATION_Y)
		left:SetFrameLevel(model:GetFrameLevel() + 2)

		right:ClearAllPoints()
		right:SetPoint("TOP", leftPane, "TOP", half, ROTATION_Y)
		right:SetFrameLevel(model:GetFrameLevel() + 2)
	end
end

-- Resistances panel: always offset from its original anchor, kept aside, so it does not drift
local function placeResistances()
	local frame = _G["CharacterResistanceFrame"]
	if not frame or not frame.GetPoint or frame:GetNumPoints() == 0 then
		return
	end

	if not frame.foreverAnchor then
		local point, target, targetPoint, x, y = frame:GetPoint(1)
		frame.foreverAnchor = { point, target, targetPoint, x or 0, y or 0 }
	end

	local a = frame.foreverAnchor
	frame:ClearAllPoints()
	frame:SetPoint(a[1], a[2], a[3], a[4] + RESISTANCES_X, a[5])
end

-- Forward declaration: skinSelector hooks it before its definition below; without it the name
-- would resolve to a nil global.
local updateSelectorStates

-- Gives a category selector camelot's header art and label; the menu stays the client's
local function skinSelector(selector)
	if selector.foreverLabel then
		return
	end

	local name = selector:GetName()

	-- Hide the dropdown's gold art (it overflows and does not resize) and its text
	for _, piece in ipairs(SELECTOR_PIECES) do
		local region = name and _G[name .. piece]
		if region then
			region:Hide()
		end
	end

	-- camelot CharacterStatFrameCategoryTemplate art, sized by its anchors (third argument: keep
	-- the size)
	local background = selector:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, ATLAS_STAT_HEADER, true)
	background:SetAllPoints(selector)
	selector.foreverBackground = background

	local label = selector:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("CENTER", selector, "CENTER", 0, 1)
	selector.foreverLabel = label

	-- Without an anchor, ToggleDropDownMenu anchors the list to the hidden <name>Left piece.
	-- UIDropDownMenu_SetAnchor puts it right under the button.
	if UIDropDownMenu_SetAnchor then
		UIDropDownMenu_SetAnchor(selector, 0, 0, "TOPLEFT", selector, "BOTTOMLEFT")
	end

	-- Hide the client's arrow: the whole bar opens the menu
	local button = name and _G[name .. "Button"]
	if button then
		button:Hide()
	end

	if not ForeverUI.statListHooked then
		local list = _G["DropDownList1"]
		if list and list.HookScript then
			list:HookScript("OnShow", updateSelectorStates)
			list:HookScript("OnHide", updateSelectorStates)
			ForeverUI.statListHooked = true
		end
	end

	selector:EnableMouse(true)
	selector:SetScript("OnMouseUp", function(self)
		ToggleDropDownMenu(nil, nil, self)
		if PlaySound then
			PlaySound("igMainMenuOptionCheckBoxOn")
		end
		updateSelectorStates()
	end)
end

-- Pressed state of the selectors while their list is open. The list closes through
-- ToggleDropDownMenu or CloseDropDownMenus, so the list's own OnShow and OnHide are hooked.
-- Only selectors with a foreverPress function react.
function updateSelectorStates()
	local list = _G["DropDownList1"]
	for _, group in ipairs(STAT_GROUPS) do
		local selector = _G[group.selector]
		if selector and selector.foreverPress then
			selector.foreverPress(list and list:IsShown()
				and UIDROPDOWNMENU_OPEN_MENU == selector)
		end
	end
end
ForeverUI.CharacterStatTabsState = updateSelectorStates

-- UIDropDownMenu_InitializeHelper sets the selector height to UIDROPDOWNMENU_BUTTON_HEIGHT * 2
-- on each open (40, as ForeverUI sets the constant to 20). The saved size is re-applied after
-- UIDropDownMenu_Initialize, which calls it through securecall.
local function reapplySelectorSize(frame)
	for _, group in ipairs(STAT_GROUPS) do
		local selector = _G[group.selector]
		if selector == frame and selector.foreverSize then
			selector:SetWidth(selector.foreverSize[1])
			selector:SetHeight(selector.foreverSize[2])
			return
		end
	end
end
ForeverUI.CharacterStatTabsSize = reapplySelectorSize

if hooksecurefunc and type(UIDropDownMenu_Initialize) == "function" then
	hooksecurefunc("UIDropDownMenu_Initialize", reapplySelectorSize)
end

-- Category label: the CVar holds a key (PLAYERSTAT_BASE_STATS); the global of that name is the
-- text.
local function writeCategory(selector, key)
	if selector and selector.foreverLabel then
		selector.foreverLabel:SetText((key and _G[key]) or "")
	end
end


-- Background band of a stat row, created once. A child of the row, so it follows its
-- visibility.
local function applyRowBackground(row)
	if row.foreverBackground then
		return row.foreverBackground
	end

	local background = row:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	background:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.foreverBackground = background

	-- The label is on the same layer and created first, and 3.3.5 has no sublevels: move it up so
	-- the band stays behind.
	local name = row:GetName()
	local label = name and _G[name .. "Label"]
	if label and label.SetDrawLayer then
		label:SetDrawLayer("ARTWORK")
	end

	return background
end

-- Stripes the rows of each category, counting only the rows the client shows (it hides some
-- depending on the category).
local function stripeStatistics()
	for _, group in ipairs(STAT_GROUPS) do
		local rank = 0
		for index = 1, STAT_PER_GROUP do
			local row = _G[group.prefix .. index]
			if row and row.foreverBackground and row:IsShown() then
				rank = rank + 1
				ForeverUI.SetAtlas(row.foreverBackground,
					(rank % 2 == 1) and ATLAS_STAT_DARK or ATLAS_STAT_LIGHT,
					true)
			end
		end
	end
end
ForeverUI.CharacterStatStripes = stripeStatistics

-- Moves and widens the client's stat rows and selectors into the right pane. They are not
-- recreated: they carry the tooltips and category menus. Geometry only: ForeverUI.Panes shows
-- and hides them.
local function placeStatistics()
	if not rightPane then
		return
	end

	local width = RIGHT_PANE - 2 * STAT_MARGIN
	local level = rightPane:GetFrameLevel() + 3
	local y = -(STONE_HEIGHT + STAT_TOP)

	for _, group in ipairs(STAT_GROUPS) do
		local selector = _G[group.selector]
		if selector then
			skinSelector(selector)
			writeCategory(selector, GetCVar and GetCVar(group.cvar))

			-- Size kept: the client resets it each time the menu opens
			selector.foreverSize = { width + 2 * STAT_HEADER_OVERHANG, STAT_HEADER }
			selector:SetFrameLevel(level)
			selector:SetWidth(selector.foreverSize[1])
			selector:SetHeight(selector.foreverSize[2])
			selector:ClearAllPoints()
			selector:SetPoint("TOPLEFT", rightPane, "TOPLEFT",
				STAT_MARGIN - STAT_HEADER_OVERHANG, y)
			y = y - STAT_HEADER
		end

		for index = 1, STAT_PER_GROUP do
			local row = _G[group.prefix .. index]
			if row then
				row:SetFrameLevel(level)
				row:SetWidth(width)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", rightPane, "TOPLEFT", STAT_MARGIN, y)
				applyRowBackground(row)
				y = y - STAT_STEP
			end
		end

		y = y - STAT_GROUP_GAP
	end

	stripeStatistics()
end

-- Level and class line. 3.3.5 FontStrings have no SetParent, and the client's line belongs to
-- CharacterFrame, so it would draw under the panes (child frames). It is hidden and our own
-- line in the right pane shows the text.
local function placeLevel()
	local source = _G["CharacterLevelText"]

	if not rightPane.levelRow then
		local row = rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		row:SetPoint("TOP", rightPane, "TOP", 0, LEVEL_Y)
		row:SetWidth(LEVEL_WIDTH)
		row:SetHeight(LEVEL_HEIGHT)
		row:SetJustifyH("CENTER")
		row:SetJustifyV("MIDDLE")
		rightPane.levelRow = row
	end

	if source then
		source:Hide()
	end

	-- No race, like camelot's PLAYER_LEVEL_NO_SPEC, which 3.3.5 lacks (its PLAYER_LEVEL includes
	-- the race): built from UNIT_LEVEL_TEMPLATE and the class name, so it stays localized.
	local level = UnitLevel and UnitLevel("player")
	local className = UnitClass and UnitClass("player")
	local text = ""
	if level and className then
		text = string.format(UNIT_LEVEL_TEMPLATE, level) .. " " .. className
	elseif source then
		text = source:GetText() or ""
	end
	rightPane.levelRow:SetText(text)
end

-- Creates a right pane tab: camelot's frame art, an icon under it and a selection mark.
-- SetCheckedTexture only takes a file path in 3.3.5, not an atlas, so the mark is our own
-- texture.
local function createPaneTab(name, tooltip, onClick)
	local tab = CreateFrame("Button", name, rightPane)
	tab:SetWidth(PANE_TAB)
	tab:SetHeight(PANE_TAB)
	tab:SetFrameLevel(rightPane:GetFrameLevel() + 3)

	local icon = tab:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(PANE_TAB_ICON)
	icon:SetHeight(PANE_TAB_ICON)
	icon:SetPoint("CENTER", tab, "CENTER", 0, 0)
	tab.icon = icon

	local selected = tab:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(selected, ATLAS_PANE_TAB_SELECTED)
	selected:SetPoint("CENTER", tab, "CENTER", 0, 0)
	selected:Hide()
	tab.selected = selected

	local frame = tab:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(frame, ATLAS_PANE_TAB)
	frame:SetPoint("CENTER", tab, "CENTER", 0, 0)

	tab:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(tooltip)
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
	if onClick then
		tab:SetScript("OnClick", onClick)
	end

	return tab
end

-- Creates the three right pane tabs once and refreshes the stats tab portrait. ForeverUI.Panes
-- remembers each host's open page, so collapsing and expanding keeps it.
local function placePaneTabs()
	if not rightPane then
		return
	end

	if not rightPane.statsTab then
		-- The tabs only select the right host's page and move the mark; ForeverUI.Panes shows and
		-- hides. The gear manager stays the client's.

		local function choose(page)
			-- Legacy callers pass a boolean: true is stats, false is equipment
			if page == true then
				page = "stats"
			elseif page == false then
				page = "equipment"
			end

			local markers = {
				stats = rightPane.statsTab,
				equipment = rightPane.equipmentTab,
				titles = rightPane.titlesTab,
			}
			for name, tab in pairs(markers) do
				if tab then
					if name == page then
						tab.selected:Show()
					else
						tab.selected:Hide()
					end
				end
			end
			ForeverUI.Panes.ShowPage("right", page)
		end
		rightPane.selectPage = choose

		rightPane.statsTab = createPaneTab("ForeverUICharacterStatsTab",
			CHARACTER_INFO,
			function() choose("stats") end)
		rightPane.statsTab.selected:Show()

		rightPane.equipmentTab = createPaneTab(
			"ForeverUICharacterGearTab", EQUIPMENT_MANAGER,
			function() choose("equipment") end)
		rightPane.equipmentTab.icon:SetTexture(GEAR_MANAGER_ICON)
		rightPane.equipmentTab.icon:SetTexCoord(
			GEAR_MANAGER_ICON_COORD[1], GEAR_MANAGER_ICON_COORD[2],
			GEAR_MANAGER_ICON_COORD[3], GEAR_MANAGER_ICON_COORD[4])

		rightPane.titlesTab = createPaneTab(
			"ForeverUICharacterTitlesTab", L.CHARACTERFRAME_TITLES,
			function() choose("titles") end)
		rightPane.titlesTab.icon:SetTexture(TITLES_ICON)
		rightPane.titlesTab.icon:SetTexCoord(
			TITLES_ICON_COORD[1], TITLES_ICON_COORD[2],
			TITLES_ICON_COORD[3], TITLES_ICON_COORD[4])

		-- camelot PaperDollFrame_UpdateSidebarTabLayout: the middle tab holds the anchor
		-- at TOP (0, -5) of the bar, the others touch its sides. Stats left, gear manager
		-- middle, titles right.
		rightPane.equipmentTab:SetPoint("TOP", rightPane, "TOP",
			0, PANE_TAB_Y)
		rightPane.statsTab:SetPoint("RIGHT", rightPane.equipmentTab,
			"LEFT", 0, 0)
		rightPane.titlesTab:SetPoint("LEFT", rightPane.equipmentTab,
			"RIGHT", 0, 0)
	end

	-- Portrait cropped as in camelot; re-applied since the client redraws it on appearance changes
	if SetPortraitTexture then
		SetPortraitTexture(rightPane.statsTab.icon, "player")
		rightPane.statsTab.icon:SetTexCoord(TAB_PORTRAIT_COORD[1],
			TAB_PORTRAIT_COORD[2], TAB_PORTRAIT_COORD[3], TAB_PORTRAIT_COORD[4])
	end

	-- The client's gear manager button is hidden: the tab opens the panel
	local old = _G["GearManagerToggleButton"]
	if old then
		old:Hide()
	end
end

-- Side tab screens. 3.3.5 lists its five screens in CHARACTERFRAME_SUBFRAMES and
-- CharacterFrame_ShowSubFrame shows one of them; the screen name is the ForeverUI.Panes group.
-- The right pane stays open on every tab, like camelot (UpdateRightPaneHeader hides only the
-- stone band); the character's stone band, page tabs and level line go with its group.
local CHARACTER_SCREEN = "PaperDollFrame"
local SIMPLE_SCREENS = {
	{ group = "PetPaperDollFrame", id = "pet", module = "PetTab" },
	{ group = "ReputationFrame", id = "reputation", module = "ReputationTab" },
	{ group = "SkillFrame", id = "skills", module = "SkillsTab" },
	{ group = "TokenFrame", id = "currency", module = "TokensTab" },
}

local contentsDeclared = false

-- Registers every screen's left and right content with ForeverUI.Panes, once
local function declareContents()
	if contentsDeclared or not rightPane then
		return
	end
	contentsDeclared = true

	local Panes = ForeverUI.Panes

	-- Left pane, character group: the model, slots and resistances are PaperDollFrame children the
	-- client shows and hides; this entry only marks the left host as used.
	Panes.Register({
		host = "left", group = CHARACTER_SCREEN, id = "character",
		build = function() return nil, {} end,
	})

	-- The four other client screens are sized for the narrower original window: they are anchored
	-- to the left host when built, unless their module lays them out.
	for _, screen in ipairs(SIMPLE_SCREENS) do
		Panes.Register({
			host = "left", group = screen.group, id = screen.id,
			build = function(host)
				-- A screen with its own module (ForeverUI[screen.module]) builds its own content
				local module = ForeverUI[screen.module or ""]
				if module and module.Build then
					return module.Build(host)
				end

				local frame = _G[screen.group]
				if not frame then
					return nil, {}
				end
				frame:ClearAllPoints()
				frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
				return nil, { frame }
			end,
		})
	end

	-- PvP: 3.3.5 has a separate toplevel window (PVPParentFrame, 384 x 512) where camelot has a
	-- sheet tab; ForeverUI.PvPTab moves it into the left pane. Reparenting is safe since it carries
	-- none of our level settings, and needed since a toplevel frame stays above everything.
	Panes.Register({
		host = "left", group = PVP_SCREEN, id = "pvp",
		build = function(host)
			return ForeverUI.PvPTab.Build(host)
		end,
	})

	-- Statistics: camelot's StatisticsFrame (StatisticsTab.lua) on the client's achievement
	-- statistics
	Panes.Register({
		host = "left", group = STATS_SCREEN, id = "stats",
		build = function(host)
			return ForeverUI.StatisticsTab.Build(host)
		end,
	})

	-- The PvP tab shows its rank details on the right; statistics leave the right pane empty
	Panes.Register({
		host = "right", group = PVP_SCREEN, id = PVP_SCREEN .. ".droit",
		build = function(host)
			return ForeverUI.PvPTab.BuildRight(host)
		end,
	})
	Panes.Register({
		host = "right", group = STATS_SCREEN, id = STATS_SCREEN .. ".droit",
		build = function() return nil, {} end,
	})

	-- Right pane furniture of the character group: shown whatever the page, hidden on other tabs
	-- (camelot: UpdateRightPaneHeader, HidePaperDollRightPane).
	Panes.Furniture("right", CHARACTER_SCREEN, {
		rightPane.stone,
		rightPane.statsTab,
		rightPane.equipmentTab,
		rightPane.titlesTab,
		rightPane.levelRow,
	})

	-- The four other client screens keep the right pane: a module may fill it (reputation shows the
	-- selected faction); an empty page still keeps the host open and the window wide.
	for _, screen in ipairs(SIMPLE_SCREENS) do
		Panes.Register({
			host = "right", group = screen.group, id = screen.id .. ".droit",
			build = function(host)
				local module = ForeverUI[screen.module or ""]
				if module and module.BuildRight then
					return module.BuildRight(host)
				end
				return nil, {}
			end,
		})
	end

	-- Right pane pages of the character group; the first registered opens by default
	Panes.Register({
		host = "right", group = CHARACTER_SCREEN, id = "stats",
		build = function()
			local frames = {}
			for _, group in ipairs(STAT_GROUPS) do
				local selector = _G[group.selector]
				if selector then
					frames[#frames + 1] = selector
				end
				for index = 1, STAT_PER_GROUP do
					local row = _G[group.prefix .. index]
					if row then
						frames[#frames + 1] = row
					end
				end
			end
			return nil, frames
		end,
	})

	Panes.Register({
		host = "right", group = CHARACTER_SCREEN, id = "equipment",
		build = function()
			if ForeverUI.EquipmentPane then
				ForeverUI.EquipmentPane.Apply()
			end
			local panel = ForeverUI.EquipmentPane and ForeverUI.EquipmentPane.Frame()
			-- GearManagerDialog is a child of the panel but hidden by default: the page shows it
			return panel, { _G["GearManagerDialog"] }
		end,
	})

	-- Titles page (camelot has no titles tab, see Titles.lua)
	Panes.Register({
		host = "right", group = CHARACTER_SCREEN, id = "titles",
		build = function(host)
			if ForeverUI.TitlesPane and ForeverUI.TitlesPane.Build then
				return ForeverUI.TitlesPane.Build(host)
			end
			return nil, {}
		end,
	})

	-- Open the group of the screen the client currently shows
	local isOpen = CHARACTER_SCREEN
	for _, name in ipairs(CHARACTERFRAME_SUBFRAMES or { CHARACTER_SCREEN }) do
		local frame = _G[name]
		if frame and frame:IsShown() then
			isOpen = name
			break
		end
	end
	Panes.ShowGroup(isOpen)
end

-- Follows the client's tab switch (CharacterFrame_ShowSubFrame): ForeverUI.Panes hides what
-- belongs to the previous screen, including our right pane, which is not a PaperDollFrame child.
local function trackScreen(name)
	if not contentsDeclared then
		return
	end
	ForeverUI.Panes.ShowGroup(name)
	if ForeverUI.CharacterUpdateActiveTab then
		ForeverUI.CharacterUpdateActiveTab()
	end
	if ForeverUI.CharacterApplyPanes then
		ForeverUI.CharacterApplyPanes(CharacterFrame)
	end
end

if hooksecurefunc and type(_G["CharacterFrame_ShowSubFrame"]) == "function" then
	hooksecurefunc("CharacterFrame_ShowSubFrame", trackScreen)
end

-- Shows the active marker on the tab of the open ForeverUI.Panes group; call it whenever the
-- group changes.
local function updateActiveTab()
	local isOpen = ForeverUI.Panes.CurrentGroup()
	for key, tab in pairs(tabs) do
		if tab.foreverActive then
			local ownScreen = TAB_SCREEN[key] or TAB_CREATED_SCREENS[key]
			if ownScreen and ownScreen == isOpen then
				tab.foreverActive:Show()
			else
				tab.foreverActive:Hide()
			end
		end
	end
end
ForeverUI.CharacterUpdateActiveTab = updateActiveTab

-- Opens one of our screens. CharacterFrame_ShowSubFrame only knows its five frames (an unknown
-- name hides them all), so the five are hidden here and our group is shown.
local function openOwnScreen(group)
	for _, name in ipairs(CHARACTERFRAME_SUBFRAMES or {}) do
		local frame = _G[name]
		if frame then
			frame:Hide()
		end
	end

	-- PanelTemplates_SelectTab disables the selected client tab and only PanelTemplates_DeselectTab
	-- (from ToggleCharacter) enables it again. Our screens use neither, so the client tabs are
	-- enabled here; otherwise the previous one stays unclickable.
	for index = 1, (CharacterFrame and CharacterFrame.numTabs) or 5 do
		local tab = _G["CharacterFrameTab" .. index]
		if tab and tab.Enable and not tab.isDisabled then
			tab:Enable()
		end
	end
	ForeverUI.Panes.ShowGroup(group)
	updateActiveTab()
	if ForeverUI.CharacterApplyPanes then
		ForeverUI.CharacterApplyPanes(CharacterFrame)
	end
end

-- The PvP window is a tab now: its key binding and micro button call TogglePVPFrame, whose
-- ToggleFrame(PVPParentFrame) no longer shows anything. Open the sheet on the PvP tab instead.
if hooksecurefunc and type(_G["TogglePVPFrame"]) == "function" then
	hooksecurefunc("TogglePVPFrame", function()
		if not CharacterFrame then
			return
		end
		if not CharacterFrame:IsShown() and ShowUIPanel then
			ShowUIPanel(CharacterFrame)
		end
		openOwnScreen(PVP_SCREEN)
	end)
end

-- Right pane collapse, kept across sessions in ForeverUIDB (camelot uses a CVar).
-- Forward declaration: reapplyPosition is defined below; without it the name would resolve to
-- a nil global when the button is clicked.
local reapplyPosition

local function isPaneCollapsed()
	ForeverUIDB = ForeverUIDB or {}
	return ForeverUIDB.rightPaneCollapsed == true
end

local function updateCollapseButton(frame)
	local button = frame and frame.foreverCollapse
	if not button then
		return
	end

	local collapsed = isPaneCollapsed()
	local art = collapsed and COLLAPSE_ART.collapsed or COLLAPSE_ART.expanded
	button:SetNormalTexture(art[1])
	button:SetPushedTexture(art[2])
	if collapsed then
		button.tooltip = L.CHARACTERFRAME_SHOW_DETAILS
	else
		button.tooltip = L.CHARACTERFRAME_HIDE_DETAILS
	end
end

-- Applies the right pane state and the window width. The right host is shown only when it has
-- a page for the open group and is not collapsed; the window is then WIDTH wide, else
-- LEFT_PANE. The side tabs are anchored to the window's right edge and follow it.
local function applyCollapse(frame)
	if not frame then
		return
	end

	local Panes = ForeverUI.Panes
	local hasContentToShow = Panes.HasContent("right", Panes.CurrentGroup())
	local isOpen = hasContentToShow and not isPaneCollapsed()

	Panes.SetHostShown("right", isOpen)
	frame:SetWidth(isOpen and WIDTH or LEFT_PANE)

	-- No collapse button on a tab without a right pane
	local button = frame.foreverCollapse
	if button then
		if hasContentToShow then button:Show() else button:Hide() end
	end

	updateCollapseButton(frame)
	if ForeverUI.UpdatePanelCorners then
		ForeverUI.UpdatePanelCorners(frame)
	end
end
ForeverUI.CharacterApplyPanes = applyCollapse

local function togglePane()
	local frame = CharacterFrame
	if not frame or InCombatLockdown() then
		return
	end

	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.rightPaneCollapsed = not isPaneCollapsed()

	if PlaySound then
		PlaySound(isPaneCollapsed() and "igCharacterInfoClose" or "igCharacterInfoOpen")
	end

	applyCollapse(frame)
	reapplyPosition(frame)

	-- The tooltip text changed under a still cursor: show it again, like camelot
	local button = frame.foreverCollapse
	if button and GameTooltip:GetOwner() == button then
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(button.tooltip)
		GameTooltip:Show()
	end
end

local function placeCollapseButton(frame)
	if not leftPane then
		return
	end

	local button = frame.foreverCollapse
	if not button then
		button = CreateFrame("Button", "ForeverUICharacterRightPaneToggle", frame)
		button:SetWidth(COLLAPSE_SIZE)
		button:SetHeight(COLLAPSE_SIZE)
		button:SetPoint("TOPRIGHT", leftPane, "TOPRIGHT", COLLAPSE_X, COLLAPSE_Y)
		button:SetHighlightTexture(COLLAPSE_HOVER, "ADD")
		button:SetScript("OnClick", togglePane)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.tooltip)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.foreverCollapse = button
	end

	-- Above the metal and the model: the button sits in the corner the model covers, and at an
	-- equal level the model takes the mouse. Two levels above the model, like the rotation
	-- arrows, and never below the skin layer.
	local level = frame:GetFrameLevel() + ART_LEVEL + 2
	local model = _G["CharacterModelFrame"]
	if model and model.GetFrameLevel then
		local wanted = model:GetFrameLevel() + 2
		if wanted > level then
			level = wanted
		end
	end
	button:SetFrameLevel(level)

	updateCollapseButton(frame)
end

-- Side tabs: a 64 x 384 column right of the frame, 30 px down (camelot CharacterFrameModeTabs).
-- Only visible tabs are stacked, each on the previous visible one: 3.3.5 hides the pet tab
-- without a pet (PetPaperDollFrame_UpdateIsAvailable), which would leave a gap in a column.
-- Restacked each time the client changes that state.
local function stackTabs()
	if not tabBar then
		return
	end

	local previous
	for _, key in ipairs(TAB_ORDER) do
		local tab = tabs[key]
		if tab and tab:IsShown() then
			tab:ClearAllPoints()
			if previous then
				tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, TAB_GAP)
			else
				tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, 0)
			end
			previous = tab
		end
	end
end

if hooksecurefunc and type(_G["PetPaperDollFrame_UpdateIsAvailable"]) == "function" then
	hooksecurefunc("PetPaperDollFrame_UpdateIsAvailable", stackTabs)
end

-- Creates one of our side tabs, skinned like the client's.
-- key: tabs table key; name: frame name; group: ForeverUI.Panes group it opens
local function createSideTab(key, name, icon, tooltip, group)
	if tabs[key] then
		return tabs[key]
	end

	local tab = CreateFrame("Button", name, tabBar)
	tab:SetWidth(TAB_W)
	tab:SetHeight(TAB_H)

	local background = tab:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, ATLAS.tab, true)
	background:SetAllPoints(tab)
	tab.foreverBackground = background

	local image = tab:CreateTexture(nil, "ARTWORK")
	image:SetWidth(SIDE_TAB_ICON)
	image:SetHeight(SIDE_TAB_ICON)
	image:SetPoint("CENTER", tab, "CENTER", TAB_ICON_X, 0)
	image:SetTexCoord(TAB_PORTRAIT_INSET, 1 - TAB_PORTRAIT_INSET,
		TAB_PORTRAIT_INSET, 1 - TAB_PORTRAIT_INSET)
	image:SetTexture(icon)
	tab.foreverIcon = image

	-- Active marker over the icon (camelot OVERLAY); the hover stays on its own HIGHLIGHT layer
	local active = tab:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(active, ATLAS.tabActive, true)
	active:SetAllPoints(tab)
	active:Hide()
	tab.foreverActive = active

	local hover = tab:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(hover, ATLAS.tabHover, true)
	hover:SetAllPoints(tab)

	tab:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(tooltip)
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
	tab:SetScript("OnClick", function()
		if PlaySound then
			PlaySound("igCharacterInfoTab")
		end
		openOwnScreen(group)
	end)

	tab.foreverSkinned = true
	tabs[key] = tab
	return tab
end

-- Creates our PvP and statistics side tabs, sets their level and the faction icon
local function placeCreatedTabs()
	if not tabBar then
		return
	end

	local faction = (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
	createSideTab("pvp", "ForeverUICharacterTabPvP",
		TAB_ICONS.pvp[faction] or TAB_ICONS.pvp.Alliance,
		PVP, PVP_SCREEN)
	createSideTab("stats", "ForeverUICharacterTabStats",
		TAB_ICONS.stats, STATISTICS, STATS_SCREEN)

	-- Same level rule as the client tabs: below the metal
	local tabsLevel = tabBar:GetFrameLevel()
	for _, key in ipairs({ "pvp", "stats" }) do
		if tabs[key] then
			tabs[key]:SetFrameLevel(tabsLevel + 1)
		end
	end

	-- The tab may be created before the client knows the faction: set the icon on each pass
	if tabs.pvp and faction then
		tabs.pvp.foreverIcon:SetTexture(
			TAB_ICONS.pvp[faction] or TAB_ICONS.pvp.Alliance)
	end
end

-- Skins the client side tabs and stacks all side tabs in the column right of the frame
local function layoutTabs(frame)
	if not tabBar then
		tabBar = CreateFrame("Frame", "ForeverUICharacterModeTabs", frame)
		tabBar:SetWidth(TABS_W)
		tabBar:SetHeight(TABS_H)
		tabBar:SetPoint("TOPLEFT", frame, "TOPRIGHT", TABS_X, TABS_Y)
	end

	-- The tab art has a tongue on its left that slides under the window; its hover and active
	-- marker would overlap the right pane's metal. The bar sits at the frame level and the tabs
	-- one level above: over the panel background, below the skin layer (ART_LEVEL).
	local tabsLevel = frame:GetFrameLevel()
	tabBar:SetFrameLevel(tabsLevel)

	local previous
	local index = 1
	while true do
		local tab = _G["CharacterFrameTab" .. index]
		if not tab then
			break
		end

		if not tab.foreverSkinned then
			sweepTextures(tab)
			for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture",
				"GetDisabledTexture", "GetHighlightTexture" }) do
				local texture = tab[method] and tab[method](tab)
				if texture then
					texture:SetAlpha(0)
				end
			end

			local background = tab:CreateTexture(nil, "BACKGROUND")
			ForeverUI.SetAtlas(background, ATLAS.tab, true)
			background:SetAllPoints(tab)
			tab.foreverBackground = background

			local icon = tab:CreateTexture(nil, "ARTWORK")
			icon:SetWidth(SIDE_TAB_ICON)
			icon:SetHeight(SIDE_TAB_ICON)
			icon:SetPoint("CENTER", tab, "CENTER", TAB_ICON_X, 0)
			icon:SetTexCoord(TAB_PORTRAIT_INSET, 1 - TAB_PORTRAIT_INSET,
				TAB_PORTRAIT_INSET, 1 - TAB_PORTRAIT_INSET)
			icon:Hide()
			tab.foreverIcon = icon

			local active = tab:CreateTexture(nil, "OVERLAY")
			ForeverUI.SetAtlas(active, ATLAS.tabActive, true)
			active:SetAllPoints(tab)
			active:Hide()
			tab.foreverActive = active

			local hover = tab:CreateTexture(nil, "HIGHLIGHT")
			ForeverUI.SetAtlas(hover, ATLAS.tabHover, true)
			hover:SetAllPoints(tab)

			-- The icon replaces the text when there is one; otherwise the client text
			-- stays, centered like the icon
			local text = _G["CharacterFrameTab" .. index .. "Text"]
			if text then
				text:ClearAllPoints()
				text:SetPoint("CENTER", tab, "CENTER", TAB_ICON_X, 0)
				text:SetWidth(TAB_W - 10)
			end

			if TAB_ICONS[index] then
				icon:SetTexture(TAB_ICONS[index])
				icon:Show()
				if text then
					text:Hide()
					text:SetText("")
				end
			end

			tab.foreverSkinned = true
		end

		tab:SetWidth(TAB_W)
		tab:SetHeight(TAB_H)
		tab:SetFrameLevel(tabsLevel + 1)
		tabs[index] = tab
		index = index + 1
	end

	placeCreatedTabs()
	stackTabs()
	updateActiveTab()

	-- The character tab shows the class icon
	local first = tabs[1]
	local _, token = UnitClass("player")
	if first and first.foreverIcon and token then
		first.foreverIcon:SetTexture(CLASS_TAB .. token)
		-- Keep the crop: the mask was baked for it
		first.foreverIcon:SetTexCoord(TAB_PORTRAIT_INSET, 1 - TAB_PORTRAIT_INSET,
			TAB_PORTRAIT_INSET, 1 - TAB_PORTRAIT_INSET)
		first.foreverIcon:Show()
		local text = _G["CharacterFrameTab1Text"]
		if text then
			text:Hide()
			text:SetText("")
		end
	end
end

-- The client's panel manager re-places the window on each show: re-apply the saved position
-- after it
function reapplyPosition(frame)
	local position = savedPositions()["sheet"]
	if not position or InCombatLockdown() then
		return
	end

	frame:ClearAllPoints()
	frame:SetPoint(position.point, UIParent, position.relativePoint or position.point,
		position.x or 0, position.y or 0)
end

-- GearManagerDialog's OnShow and OnHide call UpdateUIPanelPositions, which puts the sheet back
-- at its default place. Hook UpdateUIPanelPositions itself, which covers every caller.
if hooksecurefunc and type(UpdateUIPanelPositions) == "function" then
	hooksecurefunc("UpdateUIPanelPositions", function()
		if CharacterFrame and CharacterFrame:IsShown() then
			reapplyPosition(CharacterFrame)
		end
	end)
end

-- Skins and lays out the whole sheet; runs on each show and client update, out of combat
local function applySkin()
	local frame = CharacterFrame
	if not frame or InCombatLockdown() or not libraryPresent() then
		return
	end

	-- The width is set by applyCollapse at the end, after the stats and gear panel are placed;
	-- otherwise they would show again.
	frame:SetHeight(HEIGHT)

	if not frame.foreverSkinned then
		-- Order matters: the panes are child frames and cover their parent's regions, so the panel
		-- art lives in a higher child frame, like camelot's NineSlice.
		clearLegacyArt()
		setupPanes(frame)
		ForeverUI.SetPanelArt(frame, {
			topLeftCorner = PORTRAIT_CORNER,
			corners = PANEL_CORNERS,
			level = ART_LEVEL,
		})
		frame.foreverSkinned = true
		-- Brought to the front when shown or clicked (WindowStack.lua)
		ForeverUI.WindowStack.register("sheet", frame, function()
			-- The arena team details open next to the sheet (PvPArena.lua): a click on
			-- them counts as a click on the sheet
			return { frame, tabBar, _G["ForeverUIArenaTeamDetails"] }
		end)
	end

	clearLegacyArt()
	if ForeverUI.UpdatePanelCorners then
		ForeverUI.UpdatePanelCorners(frame)
	end
	placePortrait(frame)
	placeTitle(frame)
	reapplyPosition(frame)
	placeCloseButton(frame)
	placeModel()
	placeResistances()
	placeStatistics()
	placeLevel()
	placePaneTabs()
	-- The gear manager panel is built with its page by ForeverUI.Panes, not on each pass; its
	-- list updates itself.
	placeSlots()
	layoutTabs(frame)
	placeCollapseButton(frame)
	declareContents()
	applyCollapse(frame)
end

-- The client calls UpdatePaperdollStats(prefix, key) when a category changes: update the
-- matching header label
local function trackCategory(prefix, key)
	for _, group in ipairs(STAT_GROUPS) do
		if group.prefix == prefix then
			writeCategory(_G[group.selector], key)
			-- The client has just shown and hidden rows: restripe the visible ones
			stripeStatistics()

			-- UpdatePaperdollStats shows every row it fills without checking whether the
			-- page is open, so the rows would appear over the gear or titles page.
			-- ForeverUI.Panes re-applies each host's page.
			if ForeverUI.Panes and ForeverUI.Panes.Refresh then
				ForeverUI.Panes.Refresh()
			end
			return
		end
	end
end

ForeverUI.CharacterSheet = { Apply = applySkin, Tabs = tabs }

if hooksecurefunc and type(_G["UpdatePaperdollStats"]) == "function" then
	hooksecurefunc("UpdatePaperdollStats", trackCategory)
end

if hooksecurefunc then
	for _, funcName in ipairs({ "CharacterFrame_ShowSubFrame", "PaperDollFrame_OnShow",
		"PaperDollFrame_SetLevel", "CharacterFrame_Collapse", "CharacterFrame_Expand" }) do
		if type(_G[funcName]) == "function" then
			hooksecurefunc(funcName, applySkin)
		end
	end
end

local listener = CreateFrame("Frame", "ForeverUICharacterWatcher")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("PLAYER_REGEN_ENABLED")
listener:RegisterEvent("UNIT_INVENTORY_CHANGED")
listener:RegisterEvent("UNIT_PORTRAIT_UPDATE")
listener:RegisterEvent("UNIT_MODEL_CHANGED")

-- A title change reaches UnitPVPName only after the server answers (UNIT_NAME_UPDATE). The
-- event fires for every unit: only the title strip is redrawn, and only for the player.
listener:RegisterEvent("UNIT_NAME_UPDATE")
listener:SetScript("OnEvent", function(_self, event, unit)
	if event == "UNIT_NAME_UPDATE" then
		if unit == "player" and CharacterFrame then
			placeTitle(CharacterFrame)
		end
		return
	end
	applySkin()
end)

if CharacterFrame then
	CharacterFrame:HookScript("OnShow", applySkin)
end

applySkin()

-- Debug helpers: find the frames that take the mouse over a point
local function nameOf(frame)
	if not frame then
		return "?"
	end
	return (frame.GetName and frame:GetName()) or L.CHARACTERFRAME_DEBUG_UNNAMED
end

local function containsPoint(frame, x, y)
	if not frame.GetLeft then
		return false
	end
	local g, d, h, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	return g and d and h and b and x >= g and x <= d and y >= b and y <= h
end

-- Collects the visible, mouse-enabled frames containing (x, y) in the subtree of frame
local function browse(frame, x, y, matches, depth)
	if not frame or depth > 6 then
		return
	end

	if frame.IsVisible and frame:IsVisible() and frame.IsMouseEnabled
		and frame:IsMouseEnabled() and containsPoint(frame, x, y) then
		matches[#matches + 1] = frame
	end

	if frame.GetChildren then
		local children = { frame:GetChildren() }
		for _, child in ipairs(children) do
			browse(child, x, y, matches, depth + 1)
		end
	end
end

-- Whether a tab is enabled: IsEnabled returns a number in 3.3.5, and 0 is true in Lua.
local function isActive(tab)
	if not tab or not tab.IsEnabled then
		return true
	end
	local state = tab:IsEnabled()
	return state ~= nil and state ~= false and state ~= 0
end

-- /fui tabs: why a side tab ignores clicks. Prints the client screens shown, then each tab's
-- state and the mouse-enabled frames covering it, then the frame under the cursor for 5 s.
function ForeverUI.CharacterTabsDebug()
	local say = function(text)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
	end

	if not CharacterFrame or not CharacterFrame:IsShown() then
		say(L.CHARACTERFRAME_DEBUG_TABS_OPEN_FIRST)
		return
	end

	-- Client screens still shown: if one is while our screen is open, ToggleCharacter closes the
	-- window instead of switching tabs.
	local shownItems = {}
	for _, name in ipairs(CHARACTERFRAME_SUBFRAMES or {}) do
		local frame = _G[name]
		if frame and frame:IsShown() then
			shownItems[#shownItems + 1] = name
		end
	end
	say(string.format(L.CHARACTERFRAME_DEBUG_SHOWN_SCREENS,
		(#shownItems > 0) and table.concat(shownItems, ", ") or L.CHARACTERFRAME_DEBUG_NONE,
		tostring(ForeverUI.Panes and ForeverUI.Panes.CurrentGroup
			and ForeverUI.Panes.CurrentGroup())))

	local column = {}
	for _, key in ipairs(TAB_ORDER) do
		local tab
		if type(key) == "number" then
			tab = _G["CharacterFrameTab" .. key]
		else
			tab = tabs[key]
		end
		if tab then
			column[#column + 1] = tab
		end
	end

	for _, tab in ipairs(column) do
		local left = tab.GetLeft and tab:GetLeft()
		say(string.format(L.CHARACTERFRAME_DEBUG_TAB_STATE,
			nameOf(tab), tostring(tab:IsVisible()),
			tostring(tab:IsMouseEnabled()),
			tostring(isActive(tab)),
			tostring(tab:GetFrameStrata()), tab:GetFrameLevel(),
			tostring(tab:GetScript("OnClick") ~= nil)))

		if left then
			local x = (tab:GetLeft() + tab:GetRight()) / 2
			local y = (tab:GetTop() + tab:GetBottom()) / 2
			local matches = {}
			-- From UIParent: a covering frame need not be related to the tab
			browse(UIParent, x, y, matches, 0)
			local names = {}
			for _, frame in ipairs(matches) do
				if frame ~= tab then
					names[#names + 1] = string.format("%s(%d)", nameOf(frame),
						frame:GetFrameLevel())
				end
			end
			if #names > 0 then
				DEFAULT_CHAT_FRAME:AddMessage(L.CHARACTERFRAME_DEBUG_COVERED_BY
					.. table.concat(names, ", "))
			end
		end
	end

	local lookout = ForeverUI.mouseLookout
	if lookout and lookout.SetScript then
		lookout.rest = 5
		lookout.last = nil
		lookout:Show()
	end
	say(L.CHARACTERFRAME_DEBUG_HOVER_TABS)
end

-- Close button probe helpers. Edges are compared in screen pixels (edge x effective scale)
-- since frames have different scales. Visibility counts, not the mouse: the metal draws over
-- the button without taking the mouse.
local function containsScreenPoint(frame, x, y)
	if not frame.GetLeft or not frame.GetEffectiveScale then return false end
	local g, d, h, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (g and d and h and b) then return false end
	local s = frame:GetEffectiveScale()
	return x >= g * s and x <= d * s and y >= b * s and y <= h * s
end

local function visibleUnder(frame, x, y, matches, depth)
	if not frame or depth > 10 then return end
	if frame.IsVisible and frame:IsVisible() and containsScreenPoint(frame, x, y) then
		matches[#matches + 1] = frame
	end
	if frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do
			visibleUnder(child, x, y, matches, depth + 1)
		end
	end
end

-- /fui close: records the close button, its textures, the skin and title levels, the highest
-- accepted frame level and every visible frame over its center into
-- ForeverUIDB.closeButtonProbe (written to disk on the next /reload).
function ForeverUI.CharacterCloseDebug()
	local r = {}
	local function note(...)
		local t = {}
		for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
		r[#r + 1] = table.concat(t, " ")
	end
	local c, b = CharacterFrame, _G["CharacterFrameCloseButton"]
	note("feuille shown", c:IsShown(), "level", c:GetFrameLevel(), "strata", c:GetFrameStrata(),
		"alpha", c:GetAlpha())
	if b then
		note("croix shown", b:IsShown(), "visible", b:IsVisible(), "alpha", b:GetAlpha(),
			"level", b:GetFrameLevel(), "strata", b:GetFrameStrata(), "parent", nameOf(b:GetParent()),
			"w", b:GetWidth(), "h", b:GetHeight(), "left", b:GetLeft(), "top", b:GetTop(),
			"scale", b:GetEffectiveScale(), "mouse", b:IsMouseEnabled())
		for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
			local read = b["Get" .. state .. "Texture"]
			local t = read and read(b)
			if t then
				note(state, "tex", t:GetTexture(), "coords", table.concat({ t:GetTexCoord() }, ","),
					"shown", t:IsShown(), "alpha", t:GetAlpha(), "layer", t.GetDrawLayer and t:GetDrawLayer(),
					"w", t:GetWidth(), "h", t:GetHeight(), "left", t:GetLeft(), "top", t:GetTop())
			else
				note(state, "nil")
			end
		end
	end
	local h, title = c.foreverSkinLayer, c.foreverTitleStrip
	note("habillage level", h and h:GetFrameLevel(), "visible", h and h:IsVisible())
	note("titre level", title and title:GetFrameLevel())
	-- highest accepted frame level: probe with a very high value
	local probe = ForeverUI.levelProbe or CreateFrame("Frame")
	ForeverUI.levelProbe = probe
	local ok = pcall(probe.SetFrameLevel, probe, 100000)
	note("niveau-max", ok, probe:GetFrameLevel())
	if b and b:GetLeft() then
		local s = b:GetEffectiveScale()
		local x = (b:GetLeft() + b:GetRight()) / 2 * s
		local y = (b:GetTop() + b:GetBottom()) / 2 * s
		local matches = {}
		visibleUnder(UIParent, x, y, matches, 0)
		for _, f in ipairs(matches) do
			note("containsPoint", nameOf(f), "parent", nameOf(f:GetParent()), "strata", f:GetFrameStrata(),
				"level", f:GetFrameLevel())
		end
	end
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.closeButtonProbe = r
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. L.CHARACTERFRAME_DEBUG_CLOSE_SAVED)
end

-- /fui character: prints the head slot state and every mouse-enabled frame over its center
-- (strata and level decide the click), then the frame under the cursor for 5 s.
function ForeverUI.CharacterSheetDebug()
	-- Each host's content first: most display faults of this window show there
	if ForeverUI.Panes and ForeverUI.Panes.Report then
		for _, row in ipairs(ForeverUI.Panes.Report()) do
			DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. L.CHARACTERFRAME_DEBUG_PANES .. row)
		end
	end

	local say = function(text)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
	end

	local button = _G["CharacterHeadSlot"]
	if not button or not button:GetLeft() then
		say(L.CHARACTERFRAME_DEBUG_SHEET_OPEN_FIRST)
		return
	end

	say(string.format(L.CHARACTERFRAME_DEBUG_HEAD_STATE,
		button:GetWidth(), button:GetHeight(), tostring(button:GetFrameStrata()),
		button:GetFrameLevel(), tostring(button:IsMouseEnabled()),
		tostring(button:IsVisible())))

	-- A button may also have lost its scripts or been disabled
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		L.CHARACTERFRAME_DEBUG_HEAD_SCRIPTS,
		tostring(button:GetScript("OnClick") ~= nil),
		tostring(button:GetScript("OnDragStart") ~= nil),
		tostring(button:GetScript("OnReceiveDrag") ~= nil),
		tostring(not button.IsEnabled or button:IsEnabled() and true or false)))

	local x = (button:GetLeft() + button:GetRight()) / 2
	local y = (button:GetTop() + button:GetBottom()) / 2
	local matches = {}
	browse(CharacterFrame, x, y, matches, 0)

	DEFAULT_CHAT_FRAME:AddMessage(L.CHARACTERFRAME_DEBUG_COVERING)
	for _, frame in ipairs(matches) do
		DEFAULT_CHAT_FRAME:AddMessage(string.format(L.CHARACTERFRAME_DEBUG_COVERING_ROW,
			nameOf(frame), tostring(frame:GetFrameStrata()), frame:GetFrameLevel()))
	end

	local lookout = ForeverUI.mouseLookout
	if not lookout then
		lookout = CreateFrame("Frame", "ForeverUICharacterMouseWatch")
		lookout:Hide()
		ForeverUI.mouseLookout = lookout
	end

	lookout.rest = 5
	lookout.last = nil
	lookout:SetScript("OnUpdate", function(self, elapsed)
		self.rest = self.rest - elapsed
		if self.rest <= 0 then
			self:Hide()
			self:SetScript("OnUpdate", nil)
			DEFAULT_CHAT_FRAME:AddMessage(L.CHARACTERFRAME_DEBUG_WATCH_END)
			return
		end

		local sub = GetMouseFocus and GetMouseFocus()
		local name = nameOf(sub)
		if name ~= self.last then
			self.last = name
			DEFAULT_CHAT_FRAME:AddMessage(L.CHARACTERFRAME_DEBUG_UNDER_CURSOR .. name)
		end
	end)
	lookout:Show()
	say(L.CHARACTERFRAME_DEBUG_HOVER_SLOT)
end

-- /fui model: in-game tuning of the model scale and position (camelot uses a scene, so there
-- is no source value). Sets the values and prints the result, without a reload.
--   /fui model                      current values
--   /fui model scale 0.8            SetModelScale
--   /fui model position -5 0 0      SetPosition(depth, side, height)
--   /fui model position default     back to the client's position
function ForeverUI.CharacterModelTune(argument)
	local say = function(text)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
	end

	local model = _G["CharacterModelFrame"]
	if not model then
		return
	end

	local key, rest = string.match(argument or "", "^(%S*)%s*(.*)$")
	key = string.lower(key or "")
	local setting = ForeverUI.ModelSetting

	if key == "scale" then
		setting.scale = tonumber(rest) or setting.scale
	elseif key == "position" then
		if string.lower(rest) == "default" then
			setting.position = nil
			model:RefreshUnit()
		else
			local x, y, z = string.match(rest, "^(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)$")
			if x then
				setting.position = { tonumber(x), tonumber(y), tonumber(z) }
			else
				say(L.CHARACTERFRAME_MODEL_POSITION_USAGE)
				return
			end
		end
	elseif key ~= "" then
		say(L.CHARACTERFRAME_MODEL_USAGE)
		return
	end

	if ForeverUI.CharacterSheet then
		ForeverUI.CharacterSheet.Apply()
	end

	local scale = model.GetModelScale and model:GetModelScale()
	local x, y, z = nil, nil, nil
	if model.GetPosition then
		x, y, z = model:GetPosition()
	end
	say(string.format(L.CHARACTERFRAME_MODEL_STATE,
		tostring(scale), tostring(x), tostring(y), tostring(z)))
end
