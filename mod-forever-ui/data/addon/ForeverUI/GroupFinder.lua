-- ForeverUI: WotLK's Dungeon Finder in a movable window styled like camelot's LFGParentFrame
-- (Blizzard_GroupFinder_VanillaStyle; camelot has no dungeon finder), with the raid browser
-- as a second side tab (GroupFinderRaid.lua).
--
-- All data and actions come from WotLK (LFDFrame.lua, LFGFrame.lua). LFDParentFrame stays the
-- client's: the micro button, /lfd, the key binding, the minimap eye, Escape and NPC gossip
-- open and close it. Its content (LFDQueueFrame) stays shown but transparent under our window,
-- so its logic keeps running; we read its state after each update and act through its
-- functions (LFDQueueFrame_SetType, list checkboxes and +/-, role checkboxes, search button).
--
-- Layout from blizzard_lfgvanilla_parentframe.xml, blizzard_lfgvanilla_listing.xml/.lua,
-- lfgvanilla_constants.lua, sharedutils.lua and blizzard_sharedxml (values in G).
-- camelot -> WotLK:
--   categories  the "Type" menu: one button per displayable random dungeon, then
--               "Specific Dungeons"; the chosen type's button shows the selection
--   list        the specific dungeon list, drawn as the category list (F.createCatList)
--   details     text and rewards of the chosen random dungeon, under the buttons
--               (camelot has none)
--   Back, Post  Back returns to the categories (list only); Post clicks the client's
--               search button (Find Group / Join as Party / Leave Queue)
--   veils       WotLK's cooldown, backfill and "no LFD while in LFR" veils, over the
--               details or the whole list
-- Differences: no options button, no comment under the list, WotLK's lock replaces a locked
-- dungeon's checkbox, no heroic icon on headers (their name says it).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local F = {}
ForeverUI.GroupFinder = F

local SEP = string.char(92)
local L = ForeverUI.L
local LFG = "Interface" .. SEP .. "LFGFrame" .. SEP
local BUTTONS = "Interface" .. SEP .. "Buttons" .. SEP

-- Layout values in one table: Lua 5.1 allows a function at most 60 upvalues.
local G = {
	width = 458, height = 535,
	rock = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock",
	portraitSide = 62, portraitX = -5, portraitY = 7,
	titleX1 = 58, titleX2 = -24, titleY = -1, titleH = 20, titleTextY = -5,
	closeButton = 24, closeButtonX = 0, closeButtonY = 0,
	blue = "interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP .. "ui-lfg-bluebg",
	blueX1 = 2, blueY1 = -25, blueX2 = 248, blueY2 = -169,
	role = 64, roleY = -41, roleBackground = 80, roleCheckbox = 24, roleCheckboxX = -5, roleCheckboxY = -5,
	roleIcons = LFG .. "UI-LFG-ICON-ROLES",
	roleBackgrounds = LFG .. "UI-LFG-ICONS-ROLEBACKGROUNDS",
	frameBoxX1 = 4, frameBoxY1 = -118, frameBoxX2 = -4, frameBoxY2 = 37,
	backgroundTop = 0.093,
	catX1 = 8, catY1 = -124, catX2 = -8, catY2 = 40, catFirst = -4, catStep = 50,
	-- rule under the buttons, then the details; the details edges follow the 380-wide buttons
	-- centered in the 442-wide area (8 + (442 - 380) / 2 = 39), left edge 6 further in
	ruleGap = 6, ruleH = 16, detailsGap = 6, detailsPadding = 6, tolerance = 2, detailsX1 = 45, detailsX2 = -39, detailsBottom = 50,
	scrollStep = 20,
	catW = 380, catH = 50, catSelW = 366, catSelH = 40,
	-- image in the button: camelot's (5,-8 / -5,5), scaled to a 50-high button
	catImageTop = -6, catImageBottom = 4,
	mega = "interface" .. SEP .. "ForeverUI" .. SEP .. "pvpframe" .. SEP .. "pvpmegaqueue",
	pieces = "Interface" .. SEP .. "Icons" .. SEP .. "inv_misc_coin_02",
	listX1 = 7, listY1 = -125, listX2 = -7, listY2 = 40, margin = 4, barRight = -28,
	row = 22, plus = 16, checkbox = 30, levelL = 60,
	backL = 111, postW = 109, buttonH = 28, buttonBottom = 6, buttonSide = 4,
	tab = 55, tabY = -60, tabGap = -2, tabIcon = 50, tabIconX = -3, crop = 0.03125,
	veilW = 330, veilH = 257,
}

-- texcoords from sharedutils.lua (GetTexCoordsForRole: 256 x 256, 67 px cells;
-- GetBackgroundTexCoordsForRole: 256 x 128, 75 px cells)
local ROLES = {
	{ key = "tank", client = "LFDQueueFrameRoleButtonTank", id = 2, x = 70, alpha = 0.6,
		icon = { 0, 0.26171875, 0.26171875, 0.5234375 }, background = { 0.29296875, 0.5859375, 0, 0.5859375 } },
	{ key = "healer", client = "LFDQueueFrameRoleButtonHealer", id = 3, x = 174, alpha = 0.4,
		icon = { 0.26171875, 0.5234375, 0, 0.26171875 }, background = { 0, 0.29296875, 0, 0.5859375 } },
	{ key = "damage", client = "LFDQueueFrameRoleButtonDPS", id = 1, x = 278, alpha = 0.6,
		icon = { 0.26171875, 0.5234375, 0.26171875, 0.5234375 }, background = { 0.5859375, 0.87890625, 0, 0.5859375 } },
	-- camelot's fourth slot (TOPRIGHT -20,-41) holds WotLK's leader role, without background
	{ key = "leader", client = "LFDQueueFrameRoleButtonLeader", id = 4, right = -20,
		icon = { 0, 0.26171875, 0, 0.26171875 } },
}
local ROLE_VEIL = { 0, 0.2617, 0.5234, 0.7851 }

-- colors of the fontstyles.xml fonts (LFGActivityHeader, LFGActivityEntry...)
local COLORS = {
	header = { 0.7, 0.7, 0.7 },
	entry = { 1.0, 0.82, 0 },
	easy = { 0.5, 0.5, 0.5 },
	hard = { 1.0, 0.5, 0.25 },
}

-- category button image
local ART = {
	random = "groupfinder-button-dungeons",
	holiday = "groupfinder-button-questing",
	specific = "groupfinder-button-custom-pve",
}

local function txt(key)
	return _G[key] or key
end

-- 3.3.5 returns 1 or nil (the test bench 0 or 1), so compare to 1
local function active(b)
	return b ~= nil and b.IsEnabled ~= nil and b:IsEnabled() == 1
end

-- truly visible: the frame and its parents up to LFDParentFrame are shown
local function display(c)
	while c do
		if not c:IsShown() then return false end
		if c == LFDParentFrame then return true end
		c = c:GetParent()
	end
	return false
end

-- ------------------------------------------------------------------ Frame

local METAL = {
	{ key = "topLeft", name = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ key = "topRight", name = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ key = "bottomLeft", name = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ key = "bottomRight", name = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

local function redCloseButton(b)
	for _, state in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(state[3])
		b[state[1]](b, e and e[1] or "")
		local t = b[state[2]](b)
		if t then
			ForeverUI.SetAtlas(t, state[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
			if state[3] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
end

local function buildFrame(f)
	local rock = f:CreateTexture(nil, "BACKGROUND")
	rock:SetTexture(G.rock, true)
	if rock.SetHorizTile then rock:SetHorizTile(true) rock:SetVertTile(true) end
	rock:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -21)
	rock:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)

	local stripes = f:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(stripes, "_ui-frame-toptilestreaks", true)
	stripes:SetHeight(43)
	stripes:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -21)
	stripes:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)

	local metal = CreateFrame("Frame", nil, f)
	metal:SetAllPoints(f)
	metal:SetFrameLevel(f:GetFrameLevel() + 20)
	local p = {}
	for _, corner in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, corner.name)
		t:SetPoint(corner.point, metal, corner.point, corner.x, corner.y)
		p[corner.key] = t
	end
	local function edge(name, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, name)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	edge("_ui-frame-metal-edgetop", "TOPLEFT", p.topLeft, "TOPRIGHT", "TOPRIGHT", p.topRight, "TOPLEFT")
	edge("_ui-frame-metal-edgebottom", "BOTTOMLEFT", p.bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bottomRight, "BOTTOMLEFT")
	edge("!ui-frame-metal-edgeleft", "TOPLEFT", p.topLeft, "BOTTOMLEFT", "BOTTOMLEFT", p.bottomLeft, "TOPLEFT")
	edge("!ui-frame-metal-edgeright", "TOPRIGHT", p.topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bottomRight, "TOPRIGHT")

	-- portrait: camelot's eye (SetPortraitAtlasRaw, 62 x 62)
	local portraitFrame = CreateFrame("Frame", nil, f)
	portraitFrame:SetAllPoints(f)
	portraitFrame:SetFrameLevel(f:GetFrameLevel() + 19)
	local portrait = portraitFrame:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(portrait, "groupfinder-eye-frame", true)
	portrait:SetWidth(G.portraitSide)
	portrait:SetHeight(G.portraitSide)
	portrait:SetPoint("TOPLEFT", f, "TOPLEFT", G.portraitX, G.portraitY)
	f.portrait = portrait

	local banner = CreateFrame("Frame", nil, f)
	banner:SetFrameLevel(f:GetFrameLevel() + 21)
	banner:SetHeight(G.titleH)
	banner:SetPoint("TOPLEFT", f, "TOPLEFT", G.titleX1, G.titleY)
	banner:SetPoint("TOPRIGHT", f, "TOPRIGHT", G.titleX2, G.titleY)
	f.title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOP", banner, "TOP", 0, G.titleTextY)
	f.title:SetText(txt("LFG_TITLE"))
	f.banner = banner

	-- The close button hides the client panel that holds the window, like the client's own.
	local closeButton = CreateFrame("Button", "ForeverUIGroupFinderCloseButton", f)
	closeButton:SetWidth(G.closeButton)
	closeButton:SetHeight(G.closeButton)
	closeButton:SetFrameLevel(f:GetFrameLevel() + 22)
	closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", G.closeButtonX, G.closeButtonY)
	redCloseButton(closeButton)
	closeButton:SetScript("OnClick", function() HideUIPanel(F.frame:GetParent()) end)
	f.closeButton = closeButton
end

-- ------------------------------------------------------------ Tabs
-- LargeSideTabButtonTemplate, as on the character sheet (CharacterFrame.lua): common-sidetab
-- background, icon baked by tools/bake_masks.py (50 x 50 at (-3, 0), cropped by 0.03125),
-- common-sidetab-selected marker, common-sidetab-hover highlight.
local ICONS = "Interface" .. SEP .. "ForeverUI" .. SEP .. "tabicons" .. SEP
local TABS = {
	{ key = "dungeons", text = "LOOKING_FOR_DUNGEON", icon = ICONS .. "inv_helmet_08" },
	-- a single tab for the raid browser
	{ key = "raid", text = "LOOKING_FOR_RAID", raid = true,
		icon = ICONS .. "achievement_general_stayclassy" },
}

local function createTab(f, def, n)
	local o = CreateFrame("Button", "ForeverUIGroupFinderTab" .. n, f)
	o:SetWidth(G.tab)
	o:SetHeight(G.tab)
	local background = o:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "common-sidetab", true)
	background:SetAllPoints(o)
	local icon = o:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(G.tabIcon)
	icon:SetHeight(G.tabIcon)
	icon:SetPoint("CENTER", o, "CENTER", G.tabIconX, 0)
	icon:SetTexCoord(G.crop, 1 - G.crop, G.crop, 1 - G.crop)
	icon:SetTexture(def.icon)
	o.icon = icon
	local selected = o:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(selected, "common-sidetab-selected", true)
	selected:SetAllPoints(o)
	selected:Hide()
	o.selected = selected
	local hover = o:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(hover, "common-sidetab-hover", true)
	hover:SetAllPoints(o)
	o:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
		GameTooltip:SetText(txt(def.text))
		if def.detail then GameTooltip:AddLine(txt(def.detail), 1, 1, 1) end
		GameTooltip:Show()
	end)
	o:SetScript("OnLeave", function() GameTooltip:Hide() end)
	o:SetScript("OnClick", function()
		PlaySound("igCharacterInfoTab")
		F.goTo(def.key)
	end)
	o.key = def.key
	return o
end

function F.selectTab(key)
	F.tab = key
	for _, o in ipairs(F.tabs or {}) do
		if o.key == key then o.selected:Show() else o.selected:Hide() end
	end
end

-- ------------------------------------------------------------ Roles

-- Role button with its checkbox; r: a ROLES entry (r.page: optional name suffix).
local function createRole(parent, r)
	local b = CreateFrame("Button", "ForeverUIGroupFinderRole" .. (r.page or "") .. r.key, parent)
	b:SetWidth(G.role)
	b:SetHeight(G.role)
	if r.right then
		b:SetPoint("TOPRIGHT", F.frame, "TOPRIGHT", r.right, G.roleY)
	else
		b:SetPoint("TOPLEFT", F.frame, "TOPLEFT", r.x, G.roleY)
	end
	if r.background then
		local background = b:CreateTexture(nil, "BACKGROUND")
		background:SetTexture(G.roleBackgrounds)
		background:SetTexCoord(r.background[1], r.background[2], r.background[3], r.background[4])
		background:SetWidth(G.roleBackground)
		background:SetHeight(G.roleBackground)
		background:SetPoint("CENTER", b, "CENTER", 0, 0)
		background:SetAlpha(r.alpha)
		b.background = background
	end
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(G.roleIcons)
	icon:SetTexCoord(r.icon[1], r.icon[2], r.icon[3], r.icon[4])
	icon:SetAllPoints(b)
	b.icon = icon
	local veil = b:CreateTexture(nil, "OVERLAY")
	veil:SetTexture(G.roleIcons)
	veil:SetTexCoord(ROLE_VEIL[1], ROLE_VEIL[2], ROLE_VEIL[3], ROLE_VEIL[4])
	veil:SetAllPoints(b)
	veil:SetAlpha(0.5)
	veil:Hide()
	b.veil = veil

	local c = CreateFrame("CheckButton", "ForeverUIGroupFinderRole" .. (r.page or "") .. r.key .. "Check", b)
	c:SetWidth(G.roleCheckbox)
	c:SetHeight(G.roleCheckbox)
	c:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", G.roleCheckboxX, G.roleCheckboxY)
	c:SetNormalTexture(BUTTONS .. "UI-CheckBox-Up")
	c:SetPushedTexture(BUTTONS .. "UI-CheckBox-Down")
	c:SetHighlightTexture(BUTTONS .. "UI-CheckBox-Highlight")
	local s = c:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	c:SetCheckedTexture(BUTTONS .. "UI-CheckBox-Check")
	c:SetDisabledCheckedTexture(BUTTONS .. "UI-CheckBox-Check-Disabled")
	b.checkbox = c

	-- The client checkbox does the work: its Click toggles it and runs its OnClick
	-- (sound, LFDQueueFrame_SetRoles). Ours then follows.
	c:SetScript("OnClick", function(self)
		local client = _G[r.client]
		self:SetChecked(not self:GetChecked())
		if client and client.checkButton and active(client.checkButton) then
			client.checkButton:Click()
		end
		F.updateRoles()
	end)
	b:SetScript("OnClick", function()
		if active(c) then c:Click() end
	end)
	b:SetScript("OnEnter", function(self)
		local client = _G[r.client]
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if r.key == "leader" then
			GameTooltip:SetText(txt("GUIDE_TOOLTIP"), nil, nil, nil, nil, 1)
		else
			GameTooltip:SetText(txt("ROLE_DESCRIPTION" .. r.id), nil, nil, nil, nil, 1)
			if client and client.permDisabled then
				local red = RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }
				GameTooltip:AddLine(txt("YOUR_CLASS_MAY_NOT_PERFORM_ROLE"), red.r, red.g, red.b, 1)
			end
		end
		GameTooltip:Show()
		if active(c) then c:LockHighlight() end
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
		c:UnlockHighlight()
	end)
	b.def = r
	return b
end

F.createRole = createRole

-- Copies the state of each client role button to ours (on every page).
function F.updateRoles()
	for _, b in ipairs(F.allRoles or {}) do
		local client = _G[b.def.client]
		if client and client.checkButton then
			b.checkbox:SetChecked(client.checkButton:GetChecked())
			if client.checkButton:IsShown() then b.checkbox:Show() else b.checkbox:Hide() end
			if active(client.checkButton) then b.checkbox:Enable() else b.checkbox:Disable() end
			if client.cover and client.cover:IsShown() then
				b.veil:SetAlpha(client.cover:GetAlpha())
				b.veil:Show()
			else
				b.veil:Hide()
			end
			if b.background then
				if client.background and client.background:IsShown() then b.background:Show() else b.background:Hide() end
			end
			b.icon:SetDesaturated(client.permDisabled and true or false)
		end
	end
end

-- ------------------------------------------------------------ Categories

-- isRandomDungeonDisplayable from LFDFrame.lua (local there)
local function isRandomEligible(id)
	local _, _, minimum, maximum, _, _, _, extension = GetLFGDungeonInfo(id)
	local level = UnitLevel("player")
	local ext = (GetExpansionLevel and GetExpansionLevel()) or 2
	return minimum and level >= minimum and level <= maximum and ext >= (extension or 0)
end

-- LFDQueueFrameTypeDropDown_Initialize: "specific" first, then each displayable random
-- dungeon, joinable or not
function F.categories()
	local l = { { value = "specific", text = txt("SPECIFIC_DUNGEONS"), art = ART.specific, available = true } }
	for i = 1, (GetNumRandomDungeons and GetNumRandomDungeons() or 0) do
		local id, name = GetLFGRandomDungeonInfo(i)
		if id and isRandomEligible(id) then
			local holiday = select(14, GetLFGDungeonInfo(id))
			table.insert(l, { value = id, text = name, art = holiday and ART.holiday or ART.random,
				available = IsLFGDungeonJoinable(id) and true or false })
		end
	end
	return l
end

local function createCategory(row)
	local b = CreateFrame("Button", nil, row)
	b:SetWidth(G.catW)
	b:SetHeight(G.catH)
	b:SetPoint("TOP", row, "TOP", 0, 0)
	local image = b:CreateTexture(nil, "BACKGROUND")
	image:SetPoint("TOPLEFT", b, "TOPLEFT", 5, G.catImageTop)
	image:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, G.catImageBottom)
	b.image = image
	local coverTexture = b:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(coverTexture, "groupfinder-button-cover", true)
	coverTexture:SetAllPoints(b)
	local choice = b:CreateTexture(nil, "OVERLAY")
	choice:SetTexture(G.mega)
	choice:SetTexCoord(0.00195313, 0.63867188, 0.76953125, 0.83007813)
	choice:SetBlendMode("ADD")
	choice:SetWidth(G.catSelW)
	choice:SetHeight(G.catSelH)
	choice:SetPoint("CENTER", b, "CENTER", 0, 0)
	choice:Hide()
	b.choice = choice
	b:SetHighlightTexture(G.mega)
	local s = b:GetHighlightTexture()
	if s then
		s:SetTexCoord(0.00195313, 0.63867188, 0.70703125, 0.76757813)
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetWidth(G.catSelW)
		s:SetHeight(G.catSelH)
		s:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
	local text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("LEFT", b, "LEFT", 20, 0)
	text:SetJustifyH("LEFT")
	b.text = text
	b:SetScript("OnClick", function(self)
		local c = self.category
		if not c or not c.available then return end
		PlaySound("igMainMenuOptionCheckBoxOn")
		LFDQueueFrame_SetType(c.value)
		F.view = (c.value == "specific") and "list" or "categories"
		F.update()
	end)
	b:SetScript("OnEnter", function(self)
		local c = self.category
		if c and not c.available then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(txt("YOU_MAY_NOT_QUEUE_FOR_THIS"), 1, 1, 1)
			local reason = LFDConstructDeclinedMessage and LFDConstructDeclinedMessage(c.value)
			if reason then GameTooltip:AddLine(reason, nil, nil, nil, 1) end
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.button = b
end

local function fillCategory(row, index)
	local c = F.category_list[index]
	local b = row.button
	b.category = c
	ForeverUI.SetAtlas(b.image, c.art, true)
	b.image:SetDesaturated(not c.available)
	b.text:SetText(c.text)
	if c.available then
		b.text:SetTextColor(1, 0.82, 0)
	else
		b.text:SetTextColor(0.5, 0.5, 0.5)
	end
	if LFDQueueFrame.type == c.value then b.choice:Show() else b.choice:Hide() end
end

-- ------------------------------------------------------------ List
-- Dungeon and raid rows are the same; what differs (the list, the client functions, the
-- radio buttons of a raid in a group) comes from the list source (zone.src).

-- LFGSpecificChoiceEnableButton_SetIsRadio (LFGFrame.lua): in a group a raid is chosen with a
-- radio button (UI-RadioButton in four quarters, 17 x 17); solo, with a checkbox.
-- Sources with style "camelot" use checkbox-minimal / checkmark-minimal, as on the character
-- sheet and Social (Social.skinCell), and common-radiobutton-circle / -dot in a group.
-- 20 x 20 in a 22-high row (camelot scales its 30 x 29 box by 0.7); the radio is 16.
local CAMELOT_CHECKBOX, CAMELOT_RADIO = 20, 16

local function skinCamelotCheckbox(c, radio)
	if not radio then
		ForeverUI.Social.skinCell(c)
		return
	end
	local function place(set, get, atlas, grayed)
		local e = ForeverUI.AtlasEntry(atlas)
		c[set](c, e and e[1] or "")
		local t = c[get](c)
		if t then
			ForeverUI.SetAtlas(t, atlas, true)
			t:ClearAllPoints()
			t:SetWidth(CAMELOT_RADIO)
			t:SetHeight(CAMELOT_RADIO)
			t:SetPoint("CENTER", c, "CENTER", 0, 0)
			if grayed then t:SetDesaturated(true) end
		end
	end
	place("SetNormalTexture", "GetNormalTexture", "common-radiobutton-circle")
	place("SetPushedTexture", "GetPushedTexture", "common-radiobutton-circle")
	place("SetCheckedTexture", "GetCheckedTexture", "common-radiobutton-dot")
	place("SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "common-radiobutton-dot", true)
	c:SetHighlightTexture("")
end

-- Switches checkbox c between checkbox and radio art; radio: true for a raid in a group.
local function setRadioStyle(c, radio)
	if c.radio == radio then return end
	c.radio = radio
	if c.style == "camelot" then
		skinCamelotCheckbox(c, radio)
		return
	end
	local states = {
		{ "SetNormalTexture", "GetNormalTexture", "UI-CheckBox-Up", 0, 0.25 },
		{ "SetPushedTexture", "GetPushedTexture", "UI-CheckBox-Down", 0, 0.25 },
		{ "SetHighlightTexture", "GetHighlightTexture", "UI-CheckBox-Highlight", 0.5, 0.75 },
		{ "SetCheckedTexture", "GetCheckedTexture", "UI-CheckBox-Check", 0.25, 0.5 },
	}
	for _, e in ipairs(states) do
		c[e[1]](c, BUTTONS .. (radio and "UI-RadioButton" or e[3]))
		local t = c[e[2]](c)
		if t then
			t:ClearAllPoints()
			if radio then
				t:SetTexCoord(e[4], e[5], 0, 1)
				t:SetWidth(17)
				t:SetHeight(17)
				t:SetPoint("CENTER", c, "CENTER", 0, 0)
			else
				t:SetTexCoord(0, 1, 0, 1)
				t:SetAllPoints(c)
			end
			if e[1] == "SetHighlightTexture" then t:SetBlendMode("ADD") end
		end
	end
end

-- dungeon source (LFDFrame.lua): camelot checkboxes, and headers keep WotLK's
-- "check all" box
local SOURCE_LFD = {
	style = "camelot",
	headerCheckbox = true,
	collapse = function(id, collapsed) LFDList_SetHeaderCollapsed(id, collapsed) end,
	list = function() return LFDDungeonList end,
	empowered = function() return LFD_IsEmpowered() end,
	plus = function(b) LFDQueueFrameExpandOrCollapseButton_OnClick(b) end,
	checkbox = function(c) LFDQueueFrameDungeonChoiceEnableButton_OnClick(c) end,
	multiple = function() return true end,
	lock = function(id) return LFGLockList[id] end,
	state = function(id, mode)
		if mode == "queued" or mode == "listed" then return LFGQueuedForList[id] end
		return LFGEnabledList[id]
	end,
}
F.SOURCE_LFD = SOURCE_LFD

local function createRow(row)
	row.src = row:GetParent().src
	local plus = CreateFrame("Button", nil, row)
	plus:SetWidth(G.plus)
	plus:SetHeight(G.plus)
	plus:SetPoint("LEFT", row, "LEFT", 0, 0)
	plus:SetHitRectInsets(1, -4, -2, -2)
	plus:SetNormalTexture(BUTTONS .. "UI-MinusButton-UP")
	local n = plus:GetNormalTexture()
	if n then
		n:ClearAllPoints()
		n:SetWidth(20)
		n:SetHeight(20)
		n:SetPoint("LEFT", plus, "LEFT", 3, 0)
	end
	plus:SetHighlightTexture(BUTTONS .. "UI-PlusButton-Hilight")
	local s = plus:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetWidth(20)
		s:SetHeight(20)
		s:SetPoint("LEFT", plus, "LEFT", 3, 0)
	end
	-- client +/-: LFDQueueFrameExpandOrCollapseButton_OnClick reads
	-- self:GetParent().id and .isCollapsed
	plus:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		row.src.plus(self)
	end)
	row.plus = plus

	local c = CreateFrame("CheckButton", nil, row)
	c.style = row.src.style
	local side = (c.style == "camelot") and CAMELOT_CHECKBOX or G.checkbox
	c:SetWidth(side)
	c:SetHeight(side)
	c:SetPoint("LEFT", plus, "RIGHT", 4, 0)
	c:SetNormalTexture(BUTTONS .. "UI-CheckBox-Up")
	c:SetPushedTexture(BUTTONS .. "UI-CheckBox-Down")
	c:SetHighlightTexture(BUTTONS .. "UI-CheckBox-Highlight")
	local h = c:GetHighlightTexture()
	if h then h:SetBlendMode("ADD") end
	c:SetCheckedTexture(BUTTONS .. "UI-CheckBox-Check")
	c:SetDisabledCheckedTexture(BUTTONS .. "UI-CheckBox-Check-Disabled")
	-- client handler: LFDQueueFrameDungeonChoiceEnableButton_OnClick reads
	-- self:GetParent().id and self:GetChecked()
	c:SetScript("OnClick", function(self)
		row.src.checkbox(self)
	end)
	row.checkbox = c

	-- WotLK lock, in place of the checkbox
	local lock = row:CreateTexture(nil, "ARTWORK")
	lock:SetTexture(LFG .. "UI-LFG-ICON-LOCK")
	lock:SetTexCoord(0, 0.71875, 0, 0.875)
	lock:SetWidth(12)
	lock:SetHeight(14)
	lock:SetPoint("CENTER", c, "CENTER", 0, 0)
	lock:Hide()
	row.lockedIndicator = lock

	local level = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	level:SetWidth(G.levelL)
	level:SetHeight(G.row)
	level:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	level:SetJustifyH("LEFT")
	row.level = level

	local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	name:SetHeight(G.row)
	name:SetPoint("LEFT", c, "RIGHT", 0, 0)
	name:SetPoint("RIGHT", level, "LEFT", -4, 0)
	name:SetJustifyH("LEFT")
	row.name = name

	-- the name clicks and highlights the checkbox (camelot's NameButton);
	-- the lock tooltip is the client's
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		if active(self.checkbox) and self.checkbox:IsShown() then self.checkbox:LockHighlight() end
		LFDQueueFrameDungeonListButton_OnEnter(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.checkbox:UnlockHighlight()
		GameTooltip:Hide()
	end)
	row:SetScript("OnClick", function(self)
		if self.checkbox:IsShown() and active(self.checkbox) then self.checkbox:Click() end
	end)
end

local function color(fs, c)
	fs:SetTextColor(c[1], c[2], c[3])
end

-- LFDQueueFrameSpecificListButton_SetDungeon (and the raid one), camelot style
local function populateRow(row, index)
	local src = row.src
	local id = src.list()[index]
	local info = LFGDungeonInfo and LFGDungeonInfo[id] or {}
	local mode = GetLFGMode()
	local locked = mode == "rolecheck" or mode == "queued" or mode == "listed" or not src.empowered()
	row.id = id
	row.name:SetText(info[1] or "")
	if id < 0 then
		row.plus:Show()
		row.isCollapsed = LFGCollapseList[id]
		row.plus:SetNormalTexture(BUTTONS .. (row.isCollapsed and "UI-PlusButton-UP" or "UI-MinusButton-UP"))
		local n = row.plus:GetNormalTexture()
		if n then
			n:ClearAllPoints()
			n:SetWidth(20)
			n:SetHeight(20)
			n:SetPoint("LEFT", row.plus, "LEFT", 3, 0)
		end
		row.level:Hide()
		color(row.name, COLORS.header)
	else
		row.plus:Hide()
		row.isCollapsed = false
		local minimum, maximum = info[3] or 0, info[4] or 0
		if minimum == maximum then
			row.level:SetText(format(txt("LFD_LEVEL_FORMAT_SINGLE"), minimum))
		else
			row.level:SetText(format(txt("LFD_LEVEL_FORMAT_RANGE"), minimum, maximum))
		end
		row.level:Show()
		local player = UnitLevel("player")
		local c = COLORS.entry
		if maximum ~= 0 and maximum < player then
			c = COLORS.easy
		elseif minimum ~= 0 and minimum > player then
			c = COLORS.hard
		end
		color(row.level, c)
		color(row.name, locked and COLORS.header or c)
	end

	local multiple = src.multiple()
	if src.lock(id) then
		row.checkbox:Hide()
		row.lockedIndicator:Show()
	else
		-- in a group, a raid header has no button
		if multiple or id >= 0 then row.checkbox:Show() else row.checkbox:Hide() end
		row.lockedIndicator:Hide()
	end
	setRadioStyle(row.checkbox, not multiple)
	local state = src.state(id, mode)
	if multiple and row.checkbox.style == "camelot" then
		row.checkbox:SetChecked(state and state ~= 0)
	elseif multiple then
		if state == 1 then
			row.checkbox:SetCheckedTexture(BUTTONS .. "UI-MultiCheck-Up")
			row.checkbox:SetDisabledCheckedTexture(BUTTONS .. "UI-MultiCheck-Disabled")
		else
			row.checkbox:SetCheckedTexture(BUTTONS .. "UI-CheckBox-Check")
			row.checkbox:SetDisabledCheckedTexture(BUTTONS .. "UI-CheckBox-Check-Disabled")
		end
		row.checkbox:SetChecked(state and state ~= 0)
	else
		row.checkbox:SetChecked(state)
	end
	if locked then row.checkbox:Disable() else row.checkbox:Enable() end
end
F.createRow = createRow
F.populateRow = populateRow

-- ------------------------------------------------------------ Category list
-- Category list, shared by the raid browser (GroupFinderRaid.lua) and the specific dungeons.
-- Headers follow the character sheet (TokensTab.lua, TokenHeaderTemplate): nine-sliced
-- common-button-list-collapseExpand plate, minus / plus arrow on the right, plate in ADD at
-- 0.3 on hover. Entries use camelot checkboxes and the sheet's hover rectangle
-- (charactercreate-customize-dropdown-linemouseover, right side mirrored).
-- Clicking a header collapses or expands it (src.collapse). Rows have two heights, so they
-- are stacked by hand and the scroll offset counts rows.
-- With src.headerCheckbox (dungeons), the header keeps WotLK's "check all" box before the
-- name; partly checked (LFGEnabledList at 1) shows a gray check mark, like the AddOns list.
-- A locked header shows WotLK's lock and its tooltip instead.
local LC = {
	header = 26, entry = 22, gap = 3, indent = 2, margin = 4, corner = 12, nameX = 10, nameH = 15,
	arrowX = -8, arrowY = -1, arrowSpace = 16, checkboxGap = 2, side = 6, selectedItem = 0.20, hover = 0.10,
	plate = "common-button-list-collapseexpand",
	hoverSide = "charactercreate-customize-dropdown-linemouseover-side",
	hoverMiddle = "charactercreate-customize-dropdown-linemouseover-middle",
}
F.LC = LC

local function createCatHeader(zone, n)
	local b = CreateFrame("Button", zone.prefix .. "Header" .. n, zone)
	b:SetHeight(LC.header)
	ForeverUI.CreateNineSlice(b, LC.plate, LC.corner, { 0, 0, 0, 0 }, "BACKGROUND")
	for _, t in ipairs(ForeverUI.CreateNineSlice(b, LC.plate, LC.corner, { 0, 0, 0, 0 }, "HIGHLIGHT") or {}) do
		t:SetBlendMode("ADD")
		t:SetAlpha(0.3)
	end
	local name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
	name:SetHeight(LC.nameH)
	name:SetJustifyH("LEFT")
	name:SetPoint("RIGHT", b, "RIGHT", -LC.arrowSpace, 0)
	b.name = name
	local arrow = b:CreateTexture(nil, "OVERLAY")
	arrow:SetPoint("RIGHT", b, "RIGHT", LC.arrowX, LC.arrowY)
	b.arrow = arrow
	if zone.src.headerCheckbox then
		-- client handler: LFDQueueFrameDungeonChoiceEnableButton_OnClick reads
		-- self:GetParent().id and self:GetChecked()
		local c = CreateFrame("CheckButton", nil, b)
		c.style = "camelot"
		c:SetWidth(CAMELOT_CHECKBOX)
		c:SetHeight(CAMELOT_CHECKBOX)
		c:SetPoint("LEFT", b, "LEFT", LC.nameX, 0)
		skinCamelotCheckbox(c, false)
		c:SetScript("OnClick", function(self) zone.src.checkbox(self) end)
		b.checkbox = c
		local lock = b:CreateTexture(nil, "OVERLAY")
		lock:SetTexture(LFG .. "UI-LFG-ICON-LOCK")
		lock:SetTexCoord(0, 0.71875, 0, 0.875)
		lock:SetWidth(12)
		lock:SetHeight(14)
		lock:SetPoint("CENTER", c, "CENTER", 0, 0)
		lock:Hide()
		b.lockedIndicator = lock
		name:SetPoint("LEFT", c, "RIGHT", LC.checkboxGap, 0)
		b:SetScript("OnEnter", function(self) LFDQueueFrameDungeonListButton_OnEnter(self) end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	else
		name:SetPoint("LEFT", b, "LEFT", LC.nameX, 0)
	end
	b:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		zone.src.collapse(self.id, not LFGCollapseList[self.id])
		F.request()
	end)
	return b
end

local function fillCatHeader(b, id, src)
	local info = LFGDungeonInfo and LFGDungeonInfo[id] or {}
	b.id = id
	b.name:SetText(info[1] or "")
	ForeverUI.SetAtlas(b.arrow, LFGCollapseList[id] and "common-button-list-plus" or "common-button-list-minus", false)
	local c = b.checkbox
	if not c then return end
	local mode = GetLFGMode()
	local locked = mode == "rolecheck" or mode == "queued" or mode == "listed" or not src.empowered()
	if src.lock(id) then
		c:Hide()
		b.lockedIndicator:Show()
	else
		c:Show()
		b.lockedIndicator:Hide()
	end
	local state = src.state(id, mode)
	c:SetChecked(state and state ~= 0)
	local checkMark = c:GetCheckedTexture()
	if checkMark then checkMark:SetDesaturated(state == 1) end
	if locked then c:Disable() else c:Enable() end
end

local function createCatEntry(zone, n)
	local l = CreateFrame("Button", zone.prefix .. "Row" .. n, zone)
	l:SetHeight(LC.entry)
	-- the sheet's hover rectangle, under the row
	local hover = CreateFrame("Frame", nil, l)
	hover:SetAllPoints(l)
	hover:SetAlpha(0)
	local g = hover:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(g, LC.hoverSide, true)
	g:SetWidth(LC.side)
	g:SetPoint("TOPLEFT", hover, "TOPLEFT", 0, 0)
	g:SetPoint("BOTTOMLEFT", hover, "BOTTOMLEFT", 0, 0)
	local d = hover:CreateTexture(nil, "BACKGROUND")
	if ForeverUI.SetAtlas(d, LC.hoverSide, true) then
		local e = ForeverUI.AtlasEntry(LC.hoverSide)
		d:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	d:SetWidth(LC.side)
	d:SetPoint("TOPRIGHT", hover, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", hover, "BOTTOMRIGHT", 0, 0)
	local m = hover:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(m, LC.hoverMiddle, true)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	l.hover = hover
	createRow(l)
	return l
end

-- rectangle opacity: 0.20 checked, 0.10 hovered, 0 otherwise
local function placeCatHover(l)
	local checkMark = l.checkbox:IsShown() and l.checkbox:GetChecked()
	l.hover:SetAlpha((checkMark and LC.selectedItem) or (l:IsMouseOver() and LC.hover) or 0)
end

-- number of rows that fit starting at fromIndex; top: available height
local function countFittingCats(l, fromIndex, top)
	local y, n = LC.margin, 0
	for i = fromIndex, #l do
		local h = (l[i] < 0) and LC.header or LC.entry
		if y + h > top then break end
		y = y + h + LC.gap
		n = n + 1
	end
	return n
end

-- zone: from the top of the list (G.listY1, margin included) to zone.down above the window
-- bottom; the scroll bar takes its room on the right (G.barRight), else it goes to the margin
local function placeCatZone(zone)
	local f = F.frame
	zone:ClearAllPoints()
	zone:SetPoint("TOPLEFT", f, "TOPLEFT", G.listX1 + G.margin, G.listY1 - G.margin)
	zone:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", zone.hasBar and (G.listX2 + G.barRight - G.margin)
		or (G.listX2 - G.margin), zone.down)
end

function F.updateCategoryList(zone)
	local l = zone.src.list() or {}
	local total = #l
	local top = G.height + (G.listY1 - G.margin) - zone.down
	-- the maximum offset: the smallest one at which the end of the list fits
	local maxValue = 0
	for d = 0, total do
		if countFittingCats(l, d + 1, top) >= total - d then
			maxValue = d
			break
		end
	end
	zone.maxValue = maxValue
	zone.offset = math.max(0, math.min(zone.offset or 0, maxValue))
	local hasBar = maxValue > 0
	if hasBar ~= zone.hasBar then
		zone.hasBar = hasBar
		placeCatZone(zone)
	end
	local y = LC.margin
	local ne, nn = 0, 0
	for i = zone.offset + 1, total do
		local id = l[i]
		local h = (id < 0) and LC.header or LC.entry
		if y + h > top then break end
		local row
		if id < 0 then
			ne = ne + 1
			row = zone.headers[ne] or createCatHeader(zone, ne)
			zone.headers[ne] = row
			fillCatHeader(row, id, zone.src)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -y)
			row:SetPoint("TOPRIGHT", zone, "TOPRIGHT", 0, -y)
		else
			nn = nn + 1
			row = zone.entries[nn] or createCatEntry(zone, nn)
			zone.entries[nn] = row
			populateRow(row, i)
			placeCatHover(row)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", zone, "TOPLEFT", LC.indent, -y)
			row:SetPoint("TOPRIGHT", zone, "TOPRIGHT", 0, -y)
		end
		row:Show()
		y = y + h + LC.gap
	end
	for i = ne + 1, #zone.headers do zone.headers[i]:Hide() end
	for i = nn + 1, #zone.entries do zone.entries[i]:Hide() end
	zone.bar:Configure(maxValue + 1, 1, zone.offset)
end

-- Category list in page p. name: zone frame name; prefix: row name prefix; src: list source;
-- down: zone bottom above the window bottom; frameBox: the inset it sits on
function F.createCatList(p, name, prefix, src, down, frameBox)
	local zone = CreateFrame("Frame", name, p)
	zone.src = src
	zone.prefix = prefix
	zone.headers, zone.entries = {}, {}
	zone.offset = 0
	zone.down = down
	zone:SetFrameLevel(frameBox:GetFrameLevel() + 1)
	zone.hasBar = false
	placeCatZone(zone)
	local bar = ForeverUI.CreateScrollBar(name .. "ScrollBar", p, zone)
	bar:SetFrameLevel(frameBox:GetFrameLevel() + 2)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", zone, "TOPRIGHT", 13 + G.margin, 0)
	bar:SetPoint("BOTTOMLEFT", zone, "BOTTOMRIGHT", 13 + G.margin, -2)
	bar.onScroll = function(new)
		zone.offset = new
		F.updateCategoryList(zone)
	end
	zone.bar = bar
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(self, direction)
		self.offset = math.max(0, math.min((self.offset or 0) - direction, self.maxValue or 0))
		F.updateCategoryList(self)
	end)
	-- hover tracked every frame, as on the character sheet (trackHover)
	zone:SetScript("OnUpdate", function(self)
		for _, l in ipairs(self.entries) do
			if l:IsShown() then placeCatHover(l) end
		end
	end)
	return zone
end

-- ------------------------------------------------------------ Rewards


-- Reward item button; i: reward index for the tooltip and link (0 for money).
local function createItem(parent, i)
	local b = CreateFrame("Button", "ForeverUIGroupFinderReward" .. i, parent)
	b:SetWidth(147)
	b:SetHeight(41)
	local icon = b:CreateTexture(nil, "BORDER")
	icon:SetWidth(39)
	icon:SetHeight(39)
	icon:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.icon = icon
	local nameFrame = b:CreateTexture(nil, "BACKGROUND")
	nameFrame:SetTexture("Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestItemNameFrame")
	nameFrame:SetWidth(128)
	nameFrame:SetHeight(64)
	nameFrame:SetPoint("LEFT", icon, "RIGHT", -10, 0)
	local name = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	name:SetWidth(90)
	name:SetHeight(36)
	name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	name:SetJustifyH("LEFT")
	b.name = name
	local count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -5, 2)
	b.count = count
	b:SetID(i)
	-- LFDRandomDungeonLootTemplate
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetLFGDungeonReward(LFDQueueFrame.type, self:GetID())
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		HandleModifiedItemClick(GetLFGDungeonRewardLink(LFDQueueFrame.type, self:GetID()))
	end)
	return b
end

-- Details: a scroll area under the rule. Each piece is placed at its height from the top of
-- the content (not from the previous piece), which gives the total height for the bar.
local function buildRewards(p)
	local view = CreateFrame("ScrollFrame", "ForeverUIGroupFinderDetails", p)
	view.offset = 0
	local r = CreateFrame("Frame", "ForeverUIGroupFinderRewards", view)
	r:SetWidth(G.width + G.detailsX2 - G.detailsX1)
	r:SetHeight(1)
	view:SetScrollChild(r)
	local width = G.width + G.detailsX2 - G.detailsX1
	local function text(font)
		local fs = r:CreateFontString(nil, "ARTWORK", font)
		fs:SetWidth(width)
		fs:SetJustifyH("LEFT")
		return fs
	end
	r.description = text("GameFontHighlight")
	r.tag = text("GameFontNormalLarge")
	r.tag:SetText(txt("LFD_REWARDS"))
	r.explanation = text("GameFontHighlight")
	r.pug = text("GameFontHighlight")
	-- money: an item cell, without tooltip or link
	local money = createItem(r, 0)
	money:SetScript("OnEnter", nil)
	money:SetScript("OnLeave", nil)
	money:SetScript("OnClick", nil)
	money.icon:SetTexture(G.pieces)
	money.count:Hide()
	r.money = money
	r.xp = text("GameFontNormal")
	r.objects = {}
	F.rewards = r

	local bar = ForeverUI.CreateScrollBar("ForeverUIGroupFinderDetailsScrollBar", p, view)
	bar.onScroll = function(new)
		view.offset = new
		view:SetVerticalScroll(math.min(new * G.scrollStep, math.max(0, (view.content or 0) - (view.visible or 0))))
	end
	view:EnableMouseWheel(true)
	view:SetScript("OnMouseWheel", function(self, direction)
		bar:MoveTo(self.offset - direction)
	end)
	view.bar = bar
	F.details = view

	-- Second measure, on the next frame: from the content top to the bottom of its last piece.
	-- Wrapped text can measure short at first; if taller, everything is laid out again.
	local remeasure = CreateFrame("Frame")
	remeasure:Hide()
	remeasure:SetScript("OnUpdate", function(self)
		self:Hide()
		local piece = F.lastPiece
		if not (view:IsShown() and piece and piece:IsShown()) then return end
		local top, down = r:GetTop(), piece:GetBottom()
		if not (top and down) then return end
		local actual = top - down
		if actual > (view.content or 0) + 0.5 then F.layoutContent(actual) end
	end)
	F.remeasure = remeasure
end

-- Rule and details. The details end at the bottom of the frame box; the rule sits just
-- above their content, never higher than F.ruleMax (6 below the last button). Without
-- content it stays there.
local function placeRule(content)
	local y = F.ruleMax or 0
	if content and content > 0 then
		local wanted = -(G.height - G.detailsBottom) + content + G.detailsPadding + G.detailsGap + G.ruleH / 2
		if wanted < y then y = wanted end
	end
	-- visible height of the details, from our own gaps: GetHeight right after re-anchoring
	-- can still return the old height
	F.details.visible = (y - G.ruleH / 2 - G.detailsGap) + (G.height - G.detailsBottom)
	F.rule:ClearAllPoints()
	F.rule:SetPoint("LEFT", F.frame, "TOPLEFT", G.listX1, y)
	F.rule:SetPoint("RIGHT", F.frame, "TOPRIGHT", G.listX2, y)
	F.details:ClearAllPoints()
	F.details:SetPoint("TOPLEFT", F.frame, "TOPLEFT", G.detailsX1, y - G.ruleH / 2 - G.detailsGap)
	F.details:SetPoint("BOTTOMRIGHT", F.frame, "BOTTOMRIGHT", G.detailsX2, G.detailsBottom)
	-- the detail veils start at the rule
	F.detailsTop = y - G.ruleH / 2 - G.frameBoxY1
end

-- height of a wrapped text: GetHeight, as in the client's QuestInfo.lua
local function height(fs)
	local h = fs:GetHeight() or 0
	if h <= 0 and fs.GetStringHeight then h = fs:GetStringHeight() or 0 end
	return h
end

-- LFDQueueFrameRandom_UpdateFrame has set the texts on the client regions; we copy them.
-- The title is skipped: the chosen button already shows it.
local function updateRewards()
	local r = F.rewards
	local view = F.details
	local client = LFDQueueFrameRandomScrollFrameChildFrame
	local id = LFDQueueFrame.type
	if not client or type(id) ~= "number" then
		placeRule(nil)
		view:Hide()
		view.bar:Hide()
		return
	end
	view:Show()
	local y = 0
	local last
	local function place(piece, x, gap)
		piece:ClearAllPoints()
		piece:SetPoint("TOPLEFT", r, "TOPLEFT", x or 0, -(y + (gap or 0)))
		piece:Show()
		y = y + (gap or 0) + height(piece)
		last = piece
	end
	r.description:SetText(client.description:GetText() or "")
	place(r.description)
	if client.rewardsLabel:IsShown() then
		r.explanation:SetText(client.rewardsDescription:GetText() or "")
		place(r.tag, 0, 10)
		place(r.explanation, 0, 6)
	else
		r.tag:Hide()
		r.explanation:Hide()
	end
	local _, baseMoney, moneyVar, baseXp, xpVar, count = GetLFGDungeonRewards(id)
	count = count or 0
	-- money and experience: the LFDQueueFrameRandom_UpdateFrame formula
	local missingMembers = 4 - GetNumPartyMembers()
	local money = (baseMoney or 0) + (moneyVar or 0) * missingMembers
	local xp = (baseXp or 0) + (xpVar or 0) * missingMembers
	local top = y + 8
	local function checkbox(b, i)
		local rank, column = math.floor((i - 1) / 2), (i - 1) % 2
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", r, "TOPLEFT", column * 157, -(top + rank * 44))
		b:Show()
		y = top + rank * 44 + 41
		last = b
	end
	for i = 1, count do
		local b = r.objects[i] or createItem(r, i)
		r.objects[i] = b
		local name, image, quantity = GetLFGDungeonRewardInfo(id, i)
		b.name:SetText(name or "")
		b.icon:SetTexture(image)
		if quantity and quantity > 1 then b.count:SetText(quantity) b.count:Show() else b.count:Hide() end
		checkbox(b, i)
	end
	for i = count + 1, #r.objects do r.objects[i]:Hide() end
	if money > 0 then
		r.money.name:SetText(GetCoinTextureString(money))
		checkbox(r.money, count + 1)
	else
		r.money:Hide()
	end
	if client.pugDescription:IsShown() then
		r.pug:SetText(client.pugDescription:GetText() or "")
		place(r.pug, 0, 5)
	else
		r.pug:Hide()
	end
	if xp > 0 then
		r.xp:SetText(txt("EXPERIENCE_COLON") .. " |cffffffff" .. xp .. "|r")
		place(r.xp, 0, 8)
	else
		r.xp:Hide()
	end
	-- the rule moves down onto the content, then the scroll bar
	F.lastPiece = last
	F.layoutContent(y)
	-- second measure, once the client has set the texts
	F.remeasure:Show()
end

-- Sizes the details content to height y, places the rule and sets up the scroll bar.
function F.layoutContent(y)
	local view = F.details
	F.rewards:SetHeight(math.max(1, y))
	view.content = y
	placeRule(y)
	local visible = view.visible or 0
	if visible <= 0 or y <= visible + G.tolerance then
		view.offset = 0
		view:SetVerticalScroll(0)
		view.bar:Configure(0, 0, 0)
	else
		-- steps of 20: the last step shows the end of the content
		local total, visibleCount = math.ceil((y - visible) / G.scrollStep) + 1, 1
		view.offset = math.min(view.offset, total - visibleCount)
		view.bar:Configure(total, visibleCount, view.offset)
		view.bar.onScroll(view.offset)
	end
end

-- ------------------------------------------------------------ Veils
-- WotLK's veils (330 x 257, black at 0.93), over the frame box in the same order: cooldown
-- (11), party backfill (14), "no LFD while in LFR" (16).

-- WotLK-style veil. level: frame level above the frame box; page, frameBox: default to
-- the dungeon page and its frame box
local function createVeil(name, level, page, frameBox)
	local v = CreateFrame("Frame", name, page or F.dungeonsPage)
	v:SetFrameLevel((frameBox or F.frameBox):GetFrameLevel() + level)
	v:EnableMouse(true)
	local black = v:CreateTexture(nil, "BACKGROUND")
	black:SetTexture(0, 0, 0, 0.93)
	black:SetAllPoints(v)
	v.description = v:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	v.description:SetWidth(300)
	v.description:SetPoint("TOP", v, "TOP", 0, -70)
	v:Hide()
	return v
end
F.createVeil = createVeil

local function buildVeils()
	local pending = createVeil("ForeverUIGroupFinderCooldown", 11)
	pending.clock = pending:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	pending.clock:SetPoint("TOP", pending.description, "BOTTOM", 0, -10)
	pending.names, pending.states = {}, {}
	for i = 1, 4 do
		local n = pending:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		n:SetWidth(120)
		n:SetJustifyH("LEFT")
		if i == 1 then
			n:SetPoint("TOPLEFT", pending.description, "BOTTOMLEFT", 25, -60)
		else
			n:SetPoint("TOP", pending.names[i - 1], "BOTTOM", 0, -5)
		end
		local e = pending:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		e:SetWidth(110)
		e:SetJustifyH("RIGHT")
		e:SetPoint("TOPLEFT", n, "TOPRIGHT", 0, 0)
		pending.names[i], pending.states[i] = n, e
	end
	-- the client updates the remaining time every frame
	pending:SetScript("OnUpdate", function(self)
		local c = LFDQueueFrameCooldownFrame
		if c and c.time then
			self.clock:SetText(c.time:GetText() or "")
		end
	end)
	F.pending = pending

	local backfill = createVeil("ForeverUIGroupFinderBackfill", 14)
	backfill.yes = ForeverUI.CreatePanelButton(backfill, txt("YES"), 153, 22, nil, "GameFontNormal")
	backfill.yes:SetPoint("TOPRIGHT", backfill.description, "BOTTOM", -5, -10)
	backfill.yes:SetScript("OnClick", function()
		if LFDQueueFramePartyBackfillBackfillButton then LFDQueueFramePartyBackfillBackfillButton:Click() end
	end)
	backfill.no = ForeverUI.CreatePanelButton(backfill, txt("HIDE"), 153, 22, nil, "GameFontNormal")
	backfill.no:SetPoint("TOPLEFT", backfill.description, "BOTTOM", 5, -10)
	backfill.no:SetScript("OnClick", function()
		if LFDQueueFramePartyBackfillNoBackfillButton then LFDQueueFramePartyBackfillNoBackfillButton:Click() end
	end)
	F.backfill = backfill

	local raid = createVeil("ForeverUIGroupFinderNoLFDWhileLFR", 16)
	raid.quit = ForeverUI.CreatePanelButton(raid, "", 153, 22, nil, "GameFontNormal")
	raid.quit:SetPoint("TOP", raid.description, "BOTTOM", 0, -10)
	raid.quit:SetScript("OnClick", function()
		if LFDQueueFrameNoLFDWhileLFRLeaveQueueButton then LFDQueueFrameNoLFDWhileLFRLeaveQueueButton:Click() end
	end)
	F.raid = raid
end

local function textOf(name)
	local r = _G[name]
	return r and r.GetText and r:GetText() or ""
end

-- area they cover: the details under the rule, or the whole list
local function placeVeils()
	for _, v in ipairs({ F.pending, F.backfill, F.raid }) do
		v:ClearAllPoints()
		if F.view == "list" then
			v:SetAllPoints(F.frameBox)
		else
			v:SetPoint("TOPLEFT", F.frameBox, "TOPLEFT", 0, F.detailsTop)
			v:SetPoint("BOTTOMRIGHT", F.frameBox, "BOTTOMRIGHT", 0, 0)
		end
	end
end

local function updateVeils()
	placeVeils()
	-- cooldown: shown when visible in the client (its parent depends on deserter state);
	-- texts copied
	local c = LFDQueueFrameCooldownFrame
	if c and display(c) then
		F.pending.description:SetText(c.description and c.description:GetText() or "")
		F.pending.description:ClearAllPoints()
		F.pending.description:SetPoint("TOP", F.pending, "TOP", 0, GetNumPartyMembers() == 0 and -85 or -30)
		F.pending.clock:SetText(c.time and c.time:GetText() or "")
		if c.time and c.time:IsShown() then F.pending.clock:Show() else F.pending.clock:Hide() end
		for i = 1, 4 do
			local n, e = _G["LFDQueueFrameCooldownFrameName" .. i], _G["LFDQueueFrameCooldownFrameStatus" .. i]
			if n and n:IsShown() then
				F.pending.names[i]:SetText(n:GetText() or "")
				F.pending.states[i]:SetText(e and e:GetText() or "")
				F.pending.names[i]:Show()
				F.pending.states[i]:Show()
			else
				F.pending.names[i]:Hide()
				F.pending.states[i]:Hide()
			end
		end
		F.pending:Show()
	else
		F.pending:Hide()
	end

	local b = LFDQueueFramePartyBackfill
	if b and display(b) then
		F.backfill.description:SetText(textOf("LFDQueueFramePartyBackfillDescription"))
		F.backfill.yes:Activate(active(LFDQueueFramePartyBackfillBackfillButton))
		F.backfill:Show()
	else
		F.backfill:Hide()
	end

	local l = LFDQueueFrameNoLFDWhileLFR
	if l and display(l) then
		F.raid.description:SetText(textOf("LFDQueueFrameNoLFDWhileLFRDescription"))
		F.raid.quit:SetText(textOf("LFDQueueFrameNoLFDWhileLFRLeaveQueueButton"))
		F.raid.quit:Activate(active(LFDQueueFrameNoLFDWhileLFRLeaveQueueButton))
		F.raid:Show()
	else
		F.raid:Hide()
	end
end

-- ------------------------------------------------------------ Page

-- Role banner of a page: a child frame above the stripes (camelot's RolesSection),
-- with the blue background and the role buttons
function F.buildBanner(p, roles)
	local f = F.frame
	local banner = CreateFrame("Frame", nil, p)
	banner:SetAllPoints(f)
	banner:SetFrameLevel(f:GetFrameLevel() + 1)
	local blue = banner:CreateTexture(nil, "BACKGROUND")
	blue:SetTexture(G.blue)
	blue:SetPoint("TOPLEFT", f, "TOPLEFT", G.blueX1, G.blueY1)
	blue:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", G.blueX2, G.blueY2)
	local l = {}
	F.allRoles = F.allRoles or {}
	for _, r in ipairs(roles) do
		local b = createRole(banner, r)
		table.insert(l, b)
		table.insert(F.allRoles, b)
	end
	return blue, l
end

-- Frame box of a page, above the banner: no marble, camelot's background 3 px from the
-- edge. top, down: y offsets of its edges; trim: crop the background top (0.093) under a
-- role banner
function F.buildFrameBox(p, name, top, trim, down)
	local f = F.frame
	local frameBox = ForeverUI.CreateInset(p, name)
	frameBox:SetFrameLevel(f:GetFrameLevel() + 2)
	frameBox:SetPoint("TOPLEFT", f, "TOPLEFT", G.frameBoxX1, top)
	frameBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.frameBoxX2, down or G.frameBoxY2)
	frameBox.background:Hide()
	local background = frameBox:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "groupfinder-background", true)
	local e = ForeverUI.AtlasEntry("groupfinder-background")
	if e and trim then
		background:SetTexCoord(e[2], e[3], e[4] + (e[5] - e[4]) * G.backgroundTop, e[5])
	end
	background:SetPoint("TOPLEFT", frameBox, "TOPLEFT", 3, -3)
	background:SetPoint("BOTTOMRIGHT", frameBox, "BOTTOMRIGHT", -3, 3)
	return frameBox
end

local function buildPage(f)
	local p = CreateFrame("Frame", "ForeverUIGroupFinderDungeons", f)
	p:SetAllPoints(f)
	F.dungeonsPage = p

	F.blue, F.roles = F.buildBanner(p, ROLES)
	-- its camelot background covers the bottom of the blue, as in the source
	local frameBox = F.buildFrameBox(p, "ForeverUIGroupFinderInset", G.frameBoxY1, true)
	F.frameBox = frameBox

	-- categories: stacked from the top, no scrolling; the rule and details follow the
	-- last button
	local cats = CreateFrame("Frame", "ForeverUIGroupFinderCategories", p)
	cats:SetFrameLevel(frameBox:GetFrameLevel() + 1)
	cats:SetPoint("TOPLEFT", f, "TOPLEFT", G.catX1, G.catY1)
	cats:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.catX2, G.catY2)
	cats.rows = {}
	F.viewCategories = cats
	local rule = cats:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(rule, "shop-list-rule", true)
	rule:SetHeight(G.ruleH)
	F.rule = rule

	-- specific dungeon list: the category list, down to the frame box bottom margin
	F.listView = F.createCatList(p, "ForeverUIGroupFinderList", "ForeverUIGroupFinder", SOURCE_LFD,
		G.listY2 + G.margin, frameBox)

	buildRewards(p)
	F.details:SetFrameLevel(frameBox:GetFrameLevel() + 1)
	F.details.bar:SetFrameLevel(frameBox:GetFrameLevel() + 2)
	buildVeils()

	-- bottom buttons
	local backButton = ForeverUI.CreatePanelButton(p, txt("BACK"), G.backL, G.buttonH, "ForeverUIGroupFinderBackButton", "GameFontNormal")
	backButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.buttonSide, G.buttonBottom)
	backButton:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		F.view = "categories"
		F.update()
	end)
	F.backButton = backButton
	local find = ForeverUI.CreatePanelButton(p, txt("FIND_A_GROUP"), G.postW, G.buttonH, "ForeverUIGroupFinderFindButton", "GameFontNormal")
	find:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -G.buttonSide, G.buttonBottom)
	-- the client button: its OnClick picks LeaveLFG or LFDQueueFrame_Join
	find:SetScript("OnClick", function()
		if LFDQueueFrameFindGroupButton and active(LFDQueueFrameFindGroupButton) then
			LFDQueueFrameFindGroupButton:Click()
		end
	end)
	F.find = find
end

-- ------------------------------------------------------------ Update

local function isQueued()
	local mode = GetLFGMode()
	return mode == "queued" or mode == "rolecheck" or mode == "proposal"
end

-- category buttons, the rule under the last one, the details below
local function placeCategories()
	local cats = F.viewCategories
	local n = #F.category_list
	for i = 1, n do
		local l = cats.rows[i]
		if not l then
			l = CreateFrame("Frame", nil, cats)
			l:SetHeight(G.catH)
			createCategory(l)
			cats.rows[i] = l
		end
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", cats, "TOPLEFT", 0, G.catFirst - (i - 1) * G.catStep)
		l:SetPoint("TOPRIGHT", cats, "TOPRIGHT", 0, G.catFirst - (i - 1) * G.catStep)
		fillCategory(l, i)
		l:Show()
	end
	for i = n + 1, #cats.rows do cats.rows[i]:Hide() end
	-- bottom of the last button, from the window top
	local down = G.catY1 + G.catFirst - (n - 1) * G.catStep - G.catH
	F.ruleMax = down - G.ruleGap
	placeRule(nil)
end

local function updateDungeons()
	local view = F.view or "categories"
	if view == "list" and LFDQueueFrame.type ~= "specific" then view = "categories" end
	F.view = view

	F.category_list = F.categories()
	placeCategories()
	if view == "categories" then
		F.viewCategories:Show()
		updateRewards()
	else
		F.viewCategories:Hide()
		F.details:Hide()
		F.details.bar:Hide()
	end
	if view == "list" then
		F.listView:Show()
		F.updateCategoryList(F.listView)
	else
		F.listView:Hide()
		F.listView.bar:Hide()
	end
	updateVeils()

	-- Back exists only in the "Specific Dungeons" list
	if view == "list" then F.backButton:Show() else F.backButton:Hide() end
	local client = LFDQueueFrameFindGroupButton
	if client then
		F.find:SetText(client:GetText() or txt("FIND_A_GROUP"))
		F.find:Activate(active(client))
	end
end

-- Pages: one per tab; the dungeon page here, the raid page in GroupFinderRaid.lua
-- (F.registerPage)
F.pages = {}
function F.registerPage(key, frame, update)
	F.pages[key] = { frame = frame, update = update }
end

function F.update()
	if not F.frame then return end
	F.updateRoles()
	local pg = F.pages[F.tab or "dungeons"]
	if pg then pg.update() end
end

-- show a page: select its tab, hide the other pages
function F.show(key)
	F.selectTab(key)
	for k, pg in pairs(F.pages) do
		if k == key then pg.frame:Show() else pg.frame:Hide() end
	end
	F.update()
end

-- several client updates in one frame give a single update here
local waiter = CreateFrame("Frame")
waiter:Hide()
waiter:SetScript("OnUpdate", function(self)
	self:Hide()
	F.update()
end)
F.waiter = waiter
F.G, F.txt, F.active, F.color, F.COLORS, F.ROLES = G, txt, active, color, COLORS, ROLES

-- Schedules one update on the next frame while the window is shown.
function F.request()
	if F.frame and F.frame:IsShown() then waiter:Show() end
end

-- ------------------------------------------------------------ Client panel

-- Silence the client panel: hide its regions and children except its content and our
-- window, and stop it catching the mouse. Its content stays shown (its logic depends on
-- it) but transparent and under our window, so its invisible buttons catch nothing.
local function suppressClient()
	local p = LFDParentFrame
	for _, r in ipairs({ p:GetRegions() }) do r:Hide() end
	for _, c in ipairs({ p:GetChildren() }) do
		if c ~= F.frame and c ~= LFDQueueFrame then c:Hide() end
	end
	p:EnableMouse(false)
	LFDQueueFrame:SetAlpha(0)
	LFDQueueFrame:ClearAllPoints()
	LFDQueueFrame:SetPoint("TOPLEFT", F.frame, "TOPLEFT", 0, 0)
	LFDQueueFrame:SetWidth(p:GetWidth())
	LFDQueueFrame:SetHeight(p:GetHeight())
end

-- Our window moves between client panels: child of the open one, above its content;
-- at its saved position if moved, else at the panel's.
function F.attach(panel)
	local f = F.frame
	if f:GetParent() ~= panel then f:SetParent(panel) end
	f:SetFrameLevel(panel:GetFrameLevel() + 30)
	local pos = ForeverUIDB and ForeverUIDB.positions and ForeverUIDB.positions.finder
	if not pos then
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	end
end

-- A tab opens its client panel and closes the other. Dungeons stay closed below
-- SHOW_LFD_LEVEL, like the micro button.
function F.goTo(key)
	if key == "dungeons" then
		if UnitLevel("player") < (SHOW_LFD_LEVEL or 15) then return end
		if LFRParentFrame and LFRParentFrame:IsShown() then HideUIPanel(LFRParentFrame) end
		if not LFDParentFrame:IsShown() then ShowUIPanel(LFDParentFrame) end
	elseif LFRParentFrame then
		if LFDParentFrame:IsShown() then HideUIPanel(LFDParentFrame) end
		if LFRParentFrame:IsShown() then F.show(key) else ShowUIPanel(LFRParentFrame) end
	end
end

local function open()
	if LFRParentFrame and LFRParentFrame:IsShown() then HideUIPanel(LFRParentFrame) end
	F.attach(LFDParentFrame)
	suppressClient()
	-- on open, the categories; the list when queued for specific dungeons
	if isQueued() and LFDQueueFrame.type == "specific" then
		F.view = "list"
	else
		F.view = "categories"
	end
	F.frame:Show()
	F.show("dungeons")
end

local function build()
	if F.frame or not LFDParentFrame or not LFDQueueFrame then return end
	local f = CreateFrame("Frame", "ForeverUIGroupFinderFrame", LFDParentFrame)
	f:SetWidth(G.width)
	f:SetHeight(G.height)
	f:SetPoint("TOPLEFT", LFDParentFrame, "TOPLEFT", 0, 0)
	-- above all client content (its veils go up to +16)
	f:SetFrameLevel(LFDParentFrame:GetFrameLevel() + 30)
	f:EnableMouse(true)
	F.frame = f
	buildFrame(f)
	buildPage(f)

	F.registerPage("dungeons", F.dungeonsPage, updateDungeons)
	F.tabs = {}
	local previous
	for n, def in ipairs(TABS) do
		if def.raid and not LFRParentFrame then break end
		local o = createTab(f, def, n)
		if previous then
			o:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, G.tabGap)
		else
			o:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, G.tabY)
		end
		F.tabs[n] = o
		previous = o
	end
	f:Hide()
end

build()

if F.frame then
	LFDParentFrame:HookScript("OnShow", open)
	LFDParentFrame:HookScript("OnHide", function()
		if F.frame:GetParent() == LFDParentFrame then F.frame:Hide() end
	end)
	-- each client update and type change (NPC gossip also calls it): the view follows
	-- the chosen type
	for _, name in ipairs({ "LFDQueueFrameSpecificList_Update", "LFDQueueFrameRandom_UpdateFrame",
		"LFDQueueFrameFindGroupButton_Update", "LFG_UpdateRolesChangeable", "LFG_UpdateRoleCheckboxes",
		"LFG_UpdateLockedOutPanels", "LFDFrame_UpdateBackfill", "LFDQueueFrameRandomCooldownFrame_Update" }) do
		if _G[name] then hooksecurefunc(name, F.request) end
	end
	if LFDQueueFrame_SetType then
		hooksecurefunc("LFDQueueFrame_SetType", function(value)
			F.view = (value == "specific") and "list" or "categories"
			F.request()
		end)
	end
	local listener = CreateFrame("Frame")
	for _, ev in ipairs({ "LFG_UPDATE", "LFG_ROLE_UPDATE", "LFG_LOCK_INFO_RECEIVED",
		"LFG_UPDATE_RANDOM_INFO", "PARTY_MEMBERS_CHANGED" }) do
		listener:RegisterEvent(ev)
	end
	listener:SetScript("OnEvent", F.request)
	-- movable by its title; raised when opened or clicked
	ForeverUI.WindowStack.makeMovable(F.frame, F.frame.banner, "finder")
	ForeverUI.WindowStack.register("finder", LFDParentFrame, function()
		local z = { F.frame }
		for _, o in ipairs(F.tabs) do z[#z + 1] = o end
		return z
	end)
end

-- Debug report: /fui finder
function ForeverUI.GroupFinderDebug()
	local say = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t) end
	if not F.frame then
		say(L.GROUPFINDER_DEBUG_NOT_BUILT)
		return
	end
	say(string.format(L.GROUPFINDER_DEBUG_STATE,
		tostring(F.view), tostring(LFDQueueFrame.type), tostring(GetLFGMode()),
		LFDDungeonList and #LFDDungeonList or 0, F.frame:IsShown() and L.GROUPFINDER_DEBUG_SHOWN or L.GROUPFINDER_DEBUG_HIDDEN,
		F.frame:GetFrameLevel(), tostring(LFDQueueFrame:GetAlpha()), LFDQueueFrame:GetFrameLevel()))
	-- raid browser: the current search and what was recorded for each raid (R.hidden)
	local R = ForeverUI.GroupFinderRaid
	if R and R.hidden then
		local r = R.search
		say(string.format(L.GROUPFINDER_DEBUG_RAID,
			r and r.name or L.GROUPFINDER_DEBUG_NONE, tostring(SearchLFGGetJoinedID and SearchLFGGetJoinedID())))
		for _, id in ipairs(r and r.ids or {}) do
			local info = LFGGetDungeonInfoByID and LFGGetDungeonInfoByID(id)
			say(string.format(L.GROUPFINDER_DEBUG_RAID_ENTRY, info and info[1] or "?", id,
				R.hidden[id] and #R.hidden[id] or L.GROUPFINDER_DEBUG_NOTHING))
		end
	end
end
