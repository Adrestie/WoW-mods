-- WotLK raid browser inside the group finder window (GroupFinder.lua), styled after camelot's
-- group finder: a side tab plus two bottom tabs from the Social window, "List My Group"
-- (camelot LFGListingFrame) and "Join" (LFGBrowseFrame). The active tab is the client's
-- (LFRParentFrame.activeTab), so the raid reopens on the last panel seen.
-- Data and actions come from WotLK (LFRFrame.lua): LFRQueueFrame and LFRBrowseFrame stay shown
-- but transparent under our window; we copy their state and act through their functions.
-- One raid at a time: the server tracks one raid search per player (AzerothCore LFGMgr,
-- RBSearchersStore), and SearchLFGJoin is protected, so it only runs from a click or a key.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local F = ForeverUI.GroupFinder
local R = {}
ForeverUI.GroupFinderRaid = R

if not (F and F.frame and LFRParentFrame and LFRQueueFrame and LFRBrowseFrame) then return end

local SEP = string.char(92)
local G = F.G
local txt, active = F.txt, F.active

local M = {
	-- Sign-up page
	-- The raid list stops 88 + 4 above the view bottom; its categories use the shared list
	-- (GroupFinder.lua, F.LC)
	ruleY = 40 + 80, listBottom = 40 + 88 + 4,
	commentW = 394, commentH = 47, commentY = 40 + 19, maxLetters = 64,
	-- Browse page
	browseY = -80, menuX = 70, menuY = -43, menuW = 300, menuH = 25,
	refresh = 32, refreshX = 9,
	-- Without the bar, at -7 like the left side (G.listX1: 7)
	result = 48, resultsY = -83, resultsX2 = -22, resultsNoBar = -7,
	-- Bottom tabs, as in Social: the first at (5, 2) under the window, the next ones 3 apart
	tabX = 5, tabY = 2, tabGap = 3,
	edge = "Interface" .. SEP .. "Common" .. SEP .. "Common-Input-Border-",
	square = "interface" .. SEP .. "ForeverUI" .. SEP .. "buttons" .. SEP,
	leader = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-LeaderIcon",
	gray = { 0.3, 0.3, 0.3 },
}

-- ---------------------------------------------------------------- Source
-- Raid list (LFRFrame.lua): in a group, a single raid picked by a radio button
-- (LFRQueueFrame.selectedLFM); solo, checkboxes
local SOURCE_LFR = {
	-- camelot checkbox style (GroupFinder.lua)
	style = "camelot",
	collapse = function(id, collapsed) LFRList_SetHeaderCollapsed(id, collapsed) end,
	list = function() return LFRRaidList or {} end,
	empowered = function() return LFR_IsEmpowered() end,
	plus = function(b) LFRQueueFrameExpandOrCollapseButton_OnClick(b) end,
	checkbox = function(c) LFRQueueFrameDungeonChoiceEnableButton_OnClick(c) end,
	multiple = function() return LFR_CanQueueForMultiple() end,
	lock = function(id) return not LFR_CanQueueForLockedInstances() and LFGLockList[id] end,
	state = function(id, mode)
		if mode == "queued" or mode == "listed" then return LFGQueuedForList[id] end
		if not LFR_CanQueueForMultiple() then return id == LFRQueueFrame.selectedLFM end
		return LFGEnabledList[id]
	end,
}
R.SOURCE = SOURCE_LFR

local function textOf(name)
	local r = _G[name]
	return r and r.GetText and r:GetText() or ""
end

-- Copies a client button's text and enabled state to b; keepText: keep b's own text
local function mirror(b, clientName, keepText)
	local c = _G[clientName]
	if not c then return end
	if not keepText then b:SetText(c:GetText() or "") end
	b:Activate(active(c))
end

-- ---------------------------------------------------------------- Sign-up

-- LFRQueueFrame roles, at camelot's positions
local function raidRoles()
	local l = {}
	local clients = { tank = "LFRQueueFrameRoleButtonTank", healer = "LFRQueueFrameRoleButtonHealer",
		damage = "LFRQueueFrameRoleButtonDPS" }
	for _, r in ipairs(F.ROLES) do
		if clients[r.key] then
			table.insert(l, { key = r.key, page = "Raid", client = clients[r.key], id = r.id, x = r.x,
				alpha = r.alpha, icon = r.icon, background = r.background })
		end
	end
	return l
end

-- Comment: camelot's frame around a WotLK edit box. The client's LFRQueueFrameComment stays
-- the one LFRQueueFrame_Join reads, so ours copies its text into it; focus and send rules
-- follow its XML (OnEditFocusGained / OnEditFocusLost). p: parent; level: frame level
local function buildComment(p, level)
	local c = CreateFrame("Frame", "ForeverUIGroupFinderRaidComment", p)
	c:SetWidth(M.commentW)
	c:SetHeight(M.commentH)
	c:SetFrameLevel(level)
	c:EnableMouse(true)
	local function piece(suffix)
		local t = c:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(M.edge .. suffix)
		return t
	end
	local topLeft, topRight, bottomLeft, bottomRight = piece("TL"), piece("TR"), piece("BL"), piece("BR")
	for _, t in ipairs({ topLeft, topRight, bottomLeft, bottomRight }) do t:SetWidth(8) t:SetHeight(8) end
	topLeft:SetPoint("TOPLEFT", c, "TOPLEFT", -5, 5)
	topRight:SetPoint("TOPRIGHT", c, "TOPRIGHT", 5, 5)
	bottomLeft:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", -5, -5)
	bottomRight:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 5, -5)
	local top, down, left, right = piece("T"), piece("B"), piece("L"), piece("R")
	top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 0, 0)
	top:SetPoint("BOTTOMRIGHT", topRight, "BOTTOMLEFT", 0, 0)
	down:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT", 0, 0)
	down:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT", 0, 0)
	left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", bottomLeft, "TOPRIGHT", 0, 0)
	right:SetPoint("TOPLEFT", topRight, "BOTTOMLEFT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT", 0, 0)
	local middle = piece("M")
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

	local e = CreateFrame("EditBox", "ForeverUIGroupFinderRaidCommentEditBox", c)
	e:SetMultiLine(true)
	e:SetAutoFocus(false)
	e:SetMaxLetters(M.maxLetters)
	-- Full width: camelot removes 18 for its scroll bar; this comment does not scroll
	e:SetWidth(M.commentW)
	e:SetHeight(M.commentH)
	e:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	e:SetFontObject(GameFontHighlightSmall)
	local instruction = e:CreateFontString(nil, "BORDER", "GameFontNormalSmall")
	instruction:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
	instruction:SetWidth(M.commentW)
	instruction:SetJustifyH("LEFT")
	instruction:SetJustifyV("TOP")
	instruction:SetTextColor(0.35, 0.35, 0.35)
	instruction:SetText(txt("TYPE_LFR_COMMENT_HERE"))
	e.instruction = instruction
	e:SetScript("OnEditFocusGained", function(self)
		if LFR_IsEmpowered() and LFRRaidList and LFRRaidList[1] then
			self.instruction:Hide()
		else
			self:ClearFocus()
		end
	end)
	e:SetScript("OnEditFocusLost", function(self)
		local t = self:GetText() or ""
		if strtrim(t) == "" then self.instruction:Show() end
		LFRQueueFrameComment:SetText(t)
		SetLFGComment(t)
	end)
	e:SetScript("OnTextChanged", function(self)
		LFRQueueFrameComment:SetText(self:GetText() or "")
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	c:SetScript("OnMouseDown", function() e:SetFocus() end)
	R.input = e
	R.comment = c
end

-- Raid list with categories: the shared list (GroupFinder.lua, F.createCatList: character
-- sheet headers, entries shared with dungeons, source SOURCE_LFR)
function R.updateCategories()
	F.updateCategoryList(R.list)
end

-- "List My Group" panel: camelot's sign-up page
local function buildSignUp(p)
	local f = F.frame
	R.blue, R.roles = F.buildBanner(p, raidRoles())
	local frameBox = F.buildFrameBox(p, "ForeverUIGroupFinderRaidInset", G.frameBoxY1, true)
	R.frameBox = frameBox

	local zone = F.createCatList(p, "ForeverUIGroupFinderRaidList", "ForeverUIGroupFinderRaid", SOURCE_LFR,
		M.listBottom, frameBox)
	R.list = zone
	-- "No raids": LFRQueueFrameSpecificNoRaidsAvailable
	local none = zone:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	none:SetWidth(300)
	none:SetPoint("TOP", zone, "TOP", 0, -40)
	none:SetText(txt("NO_RAIDS_AVAILABLE"))
	none:Hide()
	R.none = none

	-- Rule and comment, above the inset
	local hovered = CreateFrame("Frame", nil, p)
	hovered:SetAllPoints(f)
	hovered:SetFrameLevel(frameBox:GetFrameLevel() + 1)
	local rule = hovered:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(rule, "shop-list-rule", true)
	rule:SetHeight(G.ruleH)
	rule:SetPoint("LEFT", f, "BOTTOMLEFT", G.listX1, M.ruleY)
	rule:SetPoint("RIGHT", f, "BOTTOMRIGHT", G.listX2, M.ruleY)
	R.rule = rule
	buildComment(p, frameBox:GetFrameLevel() + 2)
	R.comment:SetPoint("BOTTOM", f, "BOTTOM", 0, M.commentY)

	-- "No raid while in the dungeon queue": the WotLK veil
	local veil = F.createVeil("ForeverUIGroupFinderNoLFRWhileLFD", 16, p, frameBox)
	veil:SetAllPoints(frameBox)
	veil.quit = ForeverUI.CreatePanelButton(veil, txt("LEAVE_QUEUE"), 153, 22, nil, "GameFontNormal")
	veil.quit:SetPoint("TOP", veil.description, "BOTTOM", 0, -10)
	veil.quit:SetScript("OnClick", function()
		if LFRQueueFrameNoLFRWhileLFDLeaveQueueButton then LFRQueueFrameNoLFRWhileLFDLeaveQueueButton:Click() end
	end)
	R.veil = veil

	-- "Set Comment" and "List Me" drive the client's buttons
	local commentButton = ForeverUI.CreatePanelButton(p, txt("ACCEPT_COMMENT"), G.backL, G.buttonH,
		"ForeverUIGroupFinderRaidCommentButton", "GameFontNormal")
	commentButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.buttonSide, G.buttonBottom)
	-- LFRQueueFrameAcceptCommentButton OnClick: losing focus sends the comment;
	-- without focus, just a sound
	commentButton:SetScript("OnClick", function()
		if R.input:HasFocus() then
			R.input:ClearFocus()
		else
			PlaySound("igMainMenuOptionCheckBoxOn")
		end
	end)
	R.commentButton = commentButton
	local register = ForeverUI.CreatePanelButton(p, txt("LIST_ME"), G.postW, G.buttonH,
		"ForeverUIGroupFinderRaidListButton", "GameFontNormal")
	register:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -G.buttonSide, G.buttonBottom)
	register:SetScript("OnClick", function()
		if R.input:HasFocus() then R.input:ClearFocus() end
		if LFRQueueFrameFindGroupButton and active(LFRQueueFrameFindGroupButton) then
			LFRQueueFrameFindGroupButton:Click()
		end
	end)
	R.register = register
end

local function updateSignUp()
	R.updateCategories()
	if LFRQueueFrameSpecificNoRaidsAvailable and LFRQueueFrameSpecificNoRaidsAvailable:IsShown() then
		R.none:Show()
	else
		R.none:Hide()
	end
	-- The client's comment, while we are not typing
	if not R.input:HasFocus() then
		R.input:SetText(LFRQueueFrameComment:GetText() or "")
		if LFRQueueFrameCommentExplanation and not LFRQueueFrameCommentExplanation:IsShown()
			and strtrim(R.input:GetText() or "") ~= "" then
			R.input.instruction:Hide()
		else
			R.input.instruction:Show()
		end
	end
	local v = LFRQueueFrameNoLFRWhileLFD
	if v and v:IsShown() then
		R.veil.description:SetText(textOf("LFRQueueFrameNoLFRWhileLFDDescription"))
		mirror(R.veil.quit, "LFRQueueFrameNoLFRWhileLFDLeaveQueueButton", true)
		R.veil:Show()
	else
		R.veil:Hide()
	end
	mirror(R.commentButton, "LFRQueueFrameAcceptCommentButton")
	mirror(R.register, "LFRQueueFrameFindGroupButton")
end

-- ---------------------------------------------------------------- Browse

-- WowStyle1DropdownTemplate, as for the map floors: common-dropdown-textholder-c60 in three
-- slices (16 / 19), arrow at RIGHT (1, -3), GameFontHighlight text from (8, -8) to the arrow
local function buildMenu(p)
	local b = CreateFrame("Button", "ForeverUIGroupFinderRaidDropDown", p)
	b:SetWidth(M.menuW)
	b:SetHeight(M.menuH)
	b:SetPoint("TOPLEFT", p, "TOPLEFT", M.menuX, M.menuY)
	local e = ForeverUI.AtlasEntry("common-dropdown-textholder-c60")
	local background = CreateFrame("Frame", nil, b)
	background:SetPoint("TOPLEFT", b, "TOPLEFT", -8, 7)
	background:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 8, -9)
	if e then
		local du = (e[3] - e[2]) / e[6]
		local u1, u2 = e[2] + 16 * du, e[3] - 19 * du
		local function piece(a, z)
			local t = b:CreateTexture(nil, "BACKGROUND")
			t:SetTexture(e[1])
			t:SetTexCoord(a, z, e[4], e[5])
			return t
		end
		local g = piece(e[2], u1)
		g:SetWidth(16)
		g:SetPoint("TOPLEFT", background, "TOPLEFT", 0, 0)
		g:SetPoint("BOTTOMLEFT", background, "BOTTOMLEFT", 0, 0)
		local d = piece(u2, e[3])
		d:SetWidth(19)
		d:SetPoint("TOPRIGHT", background, "TOPRIGHT", 0, 0)
		d:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 0, 0)
		local m = piece(u1, u2)
		m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
		m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	end
	local arrow = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(arrow, "common-dropdown-a-button")
	arrow:SetPoint("RIGHT", b, "RIGHT", 1, -3)
	local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetJustifyH("LEFT")
	text:SetHeight(10)
	text:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -8)
	text:SetPoint("TOPRIGHT", arrow, "LEFT", 0, 0)
	b.text = text
	b.arrow = arrow
	b:SetScript("OnMouseDown", function(self) ForeverUI.SetAtlas(self.arrow, "common-dropdown-a-button-pressed", true) end)
	b:SetScript("OnMouseUp", function(self) ForeverUI.SetAtlas(self.arrow, "common-dropdown-a-button", true) end)
	-- Our menu under our button, built like the client's (LFRBrowseFrameRaidDropDown_Initialize).
	-- With no client button: displayMode "MENU", as wide as its content and at least as wide
	-- as our button (DropDown.lua, foreverMinimum)
	local menu = CreateFrame("Frame", "ForeverUIGroupFinderRaidMenu", p)
	menu.displayMode = "MENU"
	menu.foreverMinimum = M.menuW
	menu.initialize = function(self, level) R.initMenu(level) end
	R.menuList = menu
	b:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		ToggleDropDownMenu(1, nil, menu, self, 0, 0)
	end)
	R.menu = b
end

-- ---------------------------------------------------------------- Search
-- R.search = { name, ids = { raid } }; R.hidden[raid] = the entries collected for that raid
R.hidden = {}

-- LFG type of a dungeon id, as SearchLFGJoin expects
local function typeOf(id)
	local info = LFGGetDungeonInfoByID and LFGGetDungeonInfoByID(id)
	return info and info[2] or 0
end

-- Raid name with its level prefix
local function nameOf(id)
	local info = LFGGetDungeonInfoByID and LFGGetDungeonInfoByID(id)
	if not info then return "" end
	return format(txt("LFD_LEVEL_FORMAT_SINGLE"), info[12] or 0) .. " " .. (info[1] or "")
end

-- Collects the server answer for the searched raid: everything the client tooltip reads
-- (SearchLFGGetResults, GetPartyResults, GetEncounterResults)
function R.collect(raid)
	local l = {}
	local count = SearchLFGGetNumResults() or 0
	for i = 1, count do
		local d = { SearchLFGGetResults(i) }
		local e = { raid = raid, name = d[1], level = d[2], zone = d[3], localizedClass = d[4], comment = d[5],
			members = d[6] or 0, className = d[8], bossTotal = d[9] or 0, bossKilled = d[10] or 0, leader = d[11],
			tank = d[12], healer = d[13], damage = d[14], group = {}, boss = {} }
		for j = 1, e.members do
			local nm, _, link = SearchLFGGetPartyResults(i, j)
			e.group[j] = { name = nm, link = link }
		end
		if e.bossKilled > 0 then
			for j = 1, e.bossTotal do
				local bn, _, killed = SearchLFGGetEncounterResults(i, j)
				e.boss[j] = { name = bn, killed = killed }
			end
		end
		l[i] = e
	end
	R.hidden[raid] = l
end

-- LFRBrowseFrameRaidDropDownButton_OnClick: no raid (nil) or one raid id. Called from the
-- menu line click: SearchLFGJoin is protected and only runs from a click.
function R.choose(value)
	CloseDropDownMenus()
	R.choice = nil
	if value == nil then
		R.search = nil
		SearchLFGLeave()
	else
		R.search = { name = nameOf(value), ids = { value }, fromIndex = GetTime() }
		SearchLFGJoin(typeOf(value), value)
	end
	F.request()
end

-- LFRBrowseFrameRaidDropDown_Initialize; top-level categories have no checkbox
function R.initMenu(level)
	local order, list = GetFullRaidList()
	local r = R.search
	local info = UIDropDownMenu_CreateInfo()
	if not level or level == 1 then
		info.text = txt("NONE")
		info.func = function() R.choose(nil) end
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, 1)
		for _, group in ipairs(order) do
			info = UIDropDownMenu_CreateInfo()
			info.text = LFGGetDungeonInfoByID(group)[1]
			info.value = group
			info.hasArrow = true
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, 1)
		end
	elseif level == 2 then
		for _, id in ipairs(list[UIDROPDOWNMENU_MENU_VALUE] or {}) do
			info = UIDropDownMenu_CreateInfo()
			info.text = nameOf(id)
			info.value = id
			info.func = function() R.choose(id) end
			info.checked = r ~= nil and r.ids[1] == id
			UIDropDownMenu_AddButton(info, 2)
		end
	end
end

-- What the list shows: the entries of the searched raids, in order
function R.collectListed()
	local r = R.search
	local l = {}
	if not r then return l end
	for _, id in ipairs(r.ids) do
		for _, e in ipairs(R.hidden[id] or {}) do table.insert(l, e) end
	end
	return l
end

local function buildRefresh(p)
	local b = CreateFrame("Button", "ForeverUIGroupFinderRaidRefresh", p)
	b:SetWidth(M.refresh)
	b:SetHeight(M.refresh)
	b:SetPoint("LEFT", R.menu, "RIGHT", M.refreshX, 0)
	b:SetNormalTexture(M.square .. "ui-squarebutton-up")
	b:SetPushedTexture(M.square .. "ui-squarebutton-down")
	b:SetHighlightTexture(M.square .. "ui-common-mousehilight")
	local s = b:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(M.square .. "ui-refreshbutton")
	icon:SetWidth(16)
	icon:SetHeight(16)
	icon:SetPoint("CENTER", b, "CENTER", -1, 0)
	b.icon = icon
	b:SetScript("OnMouseDown", function(self)
		self.icon:ClearAllPoints()
		self.icon:SetPoint("CENTER", self, "CENTER", -2, -1)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.icon:ClearAllPoints()
		self.icon:SetPoint("CENTER", self, "CENTER", -1, 0)
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(txt("REFRESH"))
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- Client button: RefreshLFGList
	b:SetScript("OnClick", function()
		if LFRBrowseFrameRefreshButton then LFRBrowseFrameRefreshButton:Click() end
	end)
	R.refresh = b
end

-- LFGBrowseSearchEntryTemplate
local function createResult(l)
	local background = l:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(1, 1, 1, 0.04)
	background:SetPoint("TOPLEFT", l, "TOPLEFT", 3, -2)
	background:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", -3, 0)
	local leader = l:CreateTexture(nil, "ARTWORK")
	leader:SetTexture(M.leader)
	leader:SetWidth(24)
	leader:SetHeight(24)
	leader:SetPoint("TOPLEFT", l, "TOPLEFT", 8, -4)
	l.leader = leader
	local name = l:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	name:SetHeight(14)
	name:SetJustifyH("LEFT")
	l.name = name
	local level = l:CreateFontString(nil, "ARTWORK", "GameFontDisableLeft")
	level:SetHeight(14)
	level:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 4, 0)
	l.level = level
	local className = l:CreateTexture(nil, "ARTWORK")
	className:SetWidth(24)
	className:SetHeight(24)
	className:SetPoint("BOTTOMLEFT", level, "BOTTOMRIGHT", 3, -5)
	l.className = className
	local down = l:CreateFontString(nil, "ARTWORK", "GameFontDisableLeft")
	down:SetHeight(15)
	down:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT", 10, 5)
	down:SetPoint("RIGHT", l, "RIGHT", -120, 0)
	down:SetJustifyH("LEFT")
	l.down = down
	local function bar(atlas)
		local t = l:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetBlendMode("ADD")
		t:SetPoint("TOPLEFT", l, "TOPLEFT", 3, -3)
		t:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", -3, -1)
		t:Hide()
		return t
	end
	l.selected = bar("groupfinder-highlightbar-yellow")
	l.hover = bar("groupfinder-highlightbar-blue")

	-- Right side: a solo player's roles, or a group's size
	local roles = l:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	roles:SetHeight(20)
	roles:SetPoint("RIGHT", l, "RIGHT", -2 - 120, -1)
	roles:SetText(txt("LFG_TOOLTIP_ROLES"))
	l.roles = roles
	l.roleIcons = {}
	for i = 1, 3 do
		local t = l:CreateTexture(nil, "ARTWORK")
		t:SetWidth(20)
		t:SetHeight(20)
		t:SetPoint("LEFT", roles, "RIGHT", 4 + (i - 1) * 24, 0)
		l.roleIcons[i] = t
	end
	local pending = l:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(pending, "groupfinder-waitdot", true)
	pending:SetWidth(18)
	pending:SetHeight(17)
	pending:SetPoint("RIGHT", l, "RIGHT", -2 - 16, -1)
	l.pending = pending
	local count = l:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	count:SetWidth(22)
	count:SetHeight(18)
	count:SetJustifyH("RIGHT")
	count:SetPoint("RIGHT", pending, "LEFT", -1, 0)
	l.count = count

	-- Hover and tooltip (R.tooltip, from the client); click as LFRBrowseButton_OnClick:
	-- select, or clear the current selection
	l:SetScript("OnEnter", function(self)
		if not self.selected:IsShown() then self.hover:Show() end
		if self.record then R.tooltip(self, self.record) end
	end)
	l:SetScript("OnLeave", function(self)
		self.hover:Hide()
		GameTooltip:Hide()
	end)
	l:SetScript("OnClick", function(self)
		local e = self.record
		if self.isMe or not e then return end
		if R.choice and R.choice.name == e.name then
			PlaySound("igMainMenuOptionCheckBoxOff")
			R.choice = nil
		else
			PlaySound("igMainMenuOptionCheckBoxOn")
			R.choice = { name = e.name, group = e.members > 0 }
		end
		F.request()
	end)
end

-- LFRBrowseButton_OnEnter, on the collected data
function R.tooltip(l, e)
	local red = RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }
	local green = GREEN_FONT_COLOR or { r = 0.1, g = 1, b = 0.1 }
	local white = HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
	local role = "Interface" .. SEP .. "LFGFrame" .. SEP .. "LFGRole"
	GameTooltip:SetOwner(l, "ANCHOR_RIGHT", 27, -37)
	if e.members > 0 then
		GameTooltip:AddLine(txt("LOOKING_FOR_RAID"))
		GameTooltip:AddLine(e.name)
		GameTooltip:AddTexture(role, 0, 0.25, 0, 1)
		GameTooltip:AddLine(format(txt("LFM_NUM_RAID_MEMBER_TEMPLATE"), e.members))
		GameTooltip:AddTexture("")
		local title = false
		for _, m in ipairs(e.group) do
			if m.link then
				if not title then
					title = true
					GameTooltip:AddLine("\n" .. txt("IMPORTANT_PEOPLE_IN_GROUP"))
				end
				if m.link == "ignored" then
					GameTooltip:AddDoubleLine(m.name, txt("IGNORED"), red.r, red.g, red.b, red.r, red.g, red.b)
				elseif m.link == "friend" then
					GameTooltip:AddDoubleLine(m.name, txt("FRIEND"), green.r, green.g, green.b, green.r, green.g, green.b)
				end
			end
		end
	else
		GameTooltip:AddLine(e.name)
		GameTooltip:AddLine(format(txt("FRIENDS_LEVEL_TEMPLATE"), e.level or 0, e.localizedClass or ""))
	end
	if e.comment and e.comment ~= "" then
		GameTooltip:AddLine("\n" .. e.comment, white.r, white.g, white.b, 1)
	end
	if e.members == 0 then
		GameTooltip:AddLine("\n" .. txt("LFG_TOOLTIP_ROLES"))
		if e.tank then GameTooltip:AddLine(txt("TANK")) GameTooltip:AddTexture(role, 0.5, 0.75, 0, 1) end
		if e.healer then GameTooltip:AddLine(txt("HEALER")) GameTooltip:AddTexture(role, 0.75, 1, 0, 1) end
		if e.damage then GameTooltip:AddLine(txt("DAMAGER")) GameTooltip:AddTexture(role, 0.25, 0.5, 0, 1) end
	end
	if e.bossKilled > 0 then
		GameTooltip:AddLine("\n" .. txt("BOSSES"))
		for _, b in ipairs(e.boss) do
			if b.killed then
				GameTooltip:AddDoubleLine(b.name, txt("BOSS_DEAD"), red.r, red.g, red.b, red.r, red.g, red.b)
			else
				GameTooltip:AddDoubleLine(b.name, txt("BOSS_ALIVE"), green.r, green.g, green.b, green.r, green.g, green.b)
			end
		end
	elseif e.members > 0 and e.bossTotal > 0 then
		GameTooltip:AddLine("\n" .. txt("ALL_BOSSES_ALIVE"))
	end
	GameTooltip:Show()
end

local MICRO_ROLES = { "groupfinder-icon-role-micro-tank", "groupfinder-icon-role-micro-heal",
	"groupfinder-icon-role-micro-dps" }

-- Sets fs color from c, given as { r, g, b } or { r =, g =, b = }
local function colors(fs, c)
	fs:SetTextColor(c[1] or c.r, c[2] or c.g, c[3] or c.b)
end

-- Fills result row l with R.listed_entries[index]
local function fillResult(l, index)
	local e = R.listed_entries[index]
	l.record = e
	local name, level, class = e.name, e.level, e.className
	l.isMe = name == UnitName("player")
	local group = e.members > 0
	-- The name is anchored on the row, not on the leader icon; at most 228 wide (NameMaxWidth)
	l.name:ClearAllPoints()
	if group then
		l.leader:Show()
		l.name:SetPoint("TOPLEFT", l, "TOPLEFT", 8 + 24, -4 - 5)
		l.level:Hide()
		l.className:Hide()
	else
		l.leader:Hide()
		l.name:SetPoint("TOPLEFT", l, "TOPLEFT", 8 + 1, -4 - 5)
		l.level:SetText(txt("LEVEL_ABBR") .. " " .. (level or ""))
		l.level:Show()
		local a = class and ForeverUI.AtlasEntry("groupfinder-icon-class-" .. string.lower(class))
		if a then
			ForeverUI.SetAtlas(l.className, "groupfinder-icon-class-" .. string.lower(class), true)
			l.className:Show()
		else
			l.className:Hide()
		end
	end
	l.name:SetWidth(0)
	l.name:SetText(name or "")
	if (l.name:GetStringWidth() or 0) > 228 then l.name:SetWidth(228) end
	-- Bottom line: the comment, else the zone
	l.down:SetText((e.comment and e.comment ~= "") and e.comment or (e.zone or ""))
	-- Right side
	if group then
		l.roles:Hide()
		for _, t in ipairs(l.roleIcons) do t:Hide() end
		l.pending:Show()
		l.count:SetText(e.members)
		l.count:Show()
	else
		l.pending:Hide()
		l.count:Hide()
		l.roles:Show()
		local n = 0
		for i, yes in ipairs({ e.tank and true or false, e.healer and true or false, e.damage and true or false }) do
			if yes then
				n = n + 1
				ForeverUI.SetAtlas(l.roleIcons[n], MICRO_ROLES[i], true)
				l.roleIcons[n]:Show()
			end
		end
		for i = n + 1, 3 do l.roleIcons[i]:Hide() end
	end
	-- Colors: class color; the player themself is gray and inactive
	local cc = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
	if l.isMe then
		colors(l.name, M.gray)
		colors(l.level, M.gray)
		colors(l.down, M.gray)
		l.className:SetDesaturated(true)
	else
		colors(l.name, cc)
		local g = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
		colors(l.level, g)
		colors(l.down, g)
		l.className:SetDesaturated(false)
	end
	if R.choice and R.choice.name == name then
		l.selected:Show()
		l.hover:Hide()
	else
		l.selected:Hide()
	end
end

local function buildBrowse(p)
	local f = F.frame
	local frameBox = F.buildFrameBox(p, "ForeverUIGroupFinderBrowseInset", M.browseY, false)
	buildMenu(p)
	buildRefresh(p)
	local S = ForeverUI.Social
	local list = S.createList(p, "ForeverUIGroupFinderBrowseList", M.result, createResult, fillResult)
	list:SetFrameLevel(frameBox:GetFrameLevel() + 1)
	list.bar:SetFrameLevel(frameBox:GetFrameLevel() + 2)
	list:FollowBar({ "TOPLEFT", f, "TOPLEFT", G.listX1, M.resultsY },
		{ "BOTTOMRIGHT", f, "BOTTOMRIGHT", M.resultsX2, G.listY2 }, M.resultsNoBar)
	list.bar:ClearAllPoints()
	list.bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 2, -4)
	list.bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 2, 2)
	R.results = list

	local message = ForeverUI.CreatePanelButton(p, txt("SEND_MESSAGE"), G.backL, G.buttonH,
		"ForeverUIGroupFinderRaidMessageButton", "GameFontNormal")
	message:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.buttonSide, G.buttonBottom)
	-- LFRBrowseFrameSendMessageButton: ChatFrame_SendTell
	message:SetScript("OnClick", function()
		if R.choice then ChatFrame_SendTell(R.choice.name) end
	end)
	R.message = message
	local inviteButton = ForeverUI.CreatePanelButton(p, txt("INVITE"), G.postW, G.buttonH,
		"ForeverUIGroupFinderRaidInviteButton", "GameFontNormal")
	inviteButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -G.buttonSide, G.buttonBottom)
	-- LFRBrowseFrameInviteButton: InviteUnit
	inviteButton:SetScript("OnClick", function()
		if R.choice then InviteUnit(R.choice.name) end
	end)
	R.inviteButton = inviteButton
end

local function updateBrowse()
	-- A search made elsewhere (before us, or left by the client after 40 s): ours follows
	-- the server's
	local searching = SearchLFGGetJoinedID and SearchLFGGetJoinedID()
	-- A search just started waits for the server answer
	local recent = R.search and R.search.fromIndex and GetTime() - R.search.fromIndex < 5
	if not searching and not recent then
		R.search = nil
	elseif searching and not R.search then
		R.search = { name = nameOf(searching), ids = { searching } }
	end
	R.menu.text:SetText(R.search and R.search.name or txt("NONE"))
	R.listed_entries = R.collectListed()
	-- A selection no longer listed is dropped, as in the client
	if R.choice then
		local found = false
		for _, e in ipairs(R.listed_entries) do
			if e.name == R.choice.name then found = true break end
		end
		if not found then R.choice = nil end
	end
	R.results:Update(#R.listed_entries)
	-- LFRBrowse_UpdateButtonStates
	local c = R.choice
	R.message:Activate(c ~= nil and c.name ~= UnitName("player"))
	R.inviteButton:Activate(c ~= nil and c.name ~= UnitName("player") and not c.group and CanGroupInvite() and true or false)
end

-- ---------------------------------------------------------------- Client panel

-- Silences the client panel as for dungeons: its icon, tabs and close button hide;
-- both contents stay shown, transparent, under our window.
local function suppressClient()
	local p = LFRParentFrame
	for _, r in ipairs({ p:GetRegions() }) do r:Hide() end
	for _, c in ipairs({ p:GetChildren() }) do
		if c ~= F.frame and c ~= LFRQueueFrame and c ~= LFRBrowseFrame then c:Hide() end
	end
	p:EnableMouse(false)
	for _, c in ipairs({ LFRQueueFrame, LFRBrowseFrame }) do
		c:SetAlpha(0)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", F.frame, "TOPLEFT", 0, 0)
		c:SetWidth(p:GetWidth())
		c:SetHeight(p:GetHeight())
	end
end

-- ---------------------------------------------------------------- Page

-- Bottom tabs, as in the Social window; each maps to a panel and a client tab
-- (1: sign-up, 2: browse)
local TABS = {
	{ text = "LIST_MY_GROUP", client = 1 },
	{ text = "JOIN", client = 2 },
}

-- Shows the panel of the client's active tab and selects the matching bottom tab
function R.showPanel()
	local n = (LFRParentFrame.activeTab == 2) and 2 or 1
	R.panel = n
	local S = ForeverUI.Social
	for i, o in ipairs(R.tabs) do
		S.selectTab(o, i == n, true)
		o:SetWidth(S.tabWidth(o))
	end
	if n == 1 then
		R.inscription:Show()
		R.browser:Hide()
	else
		R.browser:Show()
		R.inscription:Hide()
	end
end

local function buildPage(f)
	local p = CreateFrame("Frame", "ForeverUIGroupFinderRaid", f)
	p:SetAllPoints(f)
	p:Hide()
	R.page = p
	R.inscription = CreateFrame("Frame", "ForeverUIGroupFinderRaidQueue", p)
	R.inscription:SetAllPoints(f)
	R.browser = CreateFrame("Frame", "ForeverUIGroupFinderRaidBrowse", p)
	R.browser:SetAllPoints(f)
	buildSignUp(R.inscription)
	buildBrowse(R.browser)

	local S = ForeverUI.Social
	R.tabs = {}
	local previous
	for i, def in ipairs(TABS) do
		local o = S.createTab(p, "ForeverUIGroupFinderRaidTab" .. i, false)
		o:SetText(txt(def.text))
		if previous then
			o:SetPoint("TOPLEFT", previous, "TOPRIGHT", M.tabGap, 0)
		else
			o:SetPoint("TOPLEFT", f, "BOTTOMLEFT", M.tabX, M.tabY)
		end
		-- The client tab does the rest: LFRFrame_SetActiveTab
		o:SetScript("OnClick", function()
			PlaySound("igCharacterInfoTab")
			LFRFrame_SetActiveTab(def.client)
		end)
		R.tabs[i] = o
		previous = o
	end
end

local function updatePage()
	if R.panel == 2 then updateBrowse() else updateSignUp() end
end

-- Shows our window over LFRParentFrame when the client opens it
local function open()
	if LFDParentFrame and LFDParentFrame:IsShown() then HideUIPanel(LFDParentFrame) end
	F.attach(LFRParentFrame)
	suppressClient()
	-- Both client contents at once: sign-up and browse
	LFRQueueFrame:Show()
	LFRBrowseFrame:Show()
	F.frame:Show()
	R.showPanel()
	F.show("raid")
end

buildPage(F.frame)
F.registerPage("raid", R.page, updatePage)
LFRParentFrame:HookScript("OnShow", open)
LFRParentFrame:HookScript("OnHide", function()
	if F.frame:GetParent() == LFRParentFrame then F.frame:Hide() end
end)
-- The client shows only one of its two contents: show the other again, and our panel
-- follows its tab
if LFRFrame_SetActiveTab then
	hooksecurefunc("LFRFrame_SetActiveTab", function()
		if LFRParentFrame:IsShown() then
			LFRQueueFrame:Show()
			LFRBrowseFrame:Show()
			if F.frame:GetParent() == LFRParentFrame then
				R.showPanel()
				F.update()
			end
		end
	end)
end
for _, name in ipairs({ "LFRQueueFrameSpecificList_Update", "LFRQueueFrameFindGroupButton_Update",
	"LFRBrowseFrameList_Update", "LFRBrowse_UpdateButtonStates" }) do
	if _G[name] then hooksecurefunc(name, F.request) end
end
-- Server answer: collected for the searched raid
local listener = CreateFrame("Frame")
listener:RegisterEvent("UPDATE_LFG_LIST")
listener:SetScript("OnEvent", function()
	local searching = SearchLFGGetJoinedID and SearchLFGGetJoinedID()
	if searching then R.collect(searching) end
	F.request()
end)
ForeverUI.WindowStack.register("raidFinder", LFRParentFrame, function()
	local z = { F.frame }
	for _, o in ipairs(F.tabs) do z[#z + 1] = o end
	-- The bottom tabs lie outside the window
	for _, o in ipairs(R.tabs) do z[#z + 1] = o end
	return z
end)
