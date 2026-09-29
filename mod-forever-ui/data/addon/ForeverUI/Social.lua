-- Social window skinned like camelot: the frame, its tabs and the Contacts page (friends
-- and ignores). The Who, Guild, Chat and Raid pages are in SocialWho.lua, SocialGuild.lua,
-- SocialChat.lua and SocialRaid.lua and register with S.registerPage. Data, row order,
-- colors, menu, tooltip and button actions follow the client's FriendsFrame.lua.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local S = {}
ForeverUI.Social = S

local SEP = string.char(92)
local L = ForeverUI.L

-- Layout values from camelot friendsframe.xml, shareduipaneltemplates, nineslicelayouts
-- and tabsystemtemplates. A table, because Lua 5.1 limits a function to 60 upvalues.
local G = {
	width = 385, height = 424,
	rock = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock",
	-- battlenet-portrait refined by tools/refine_portrait.py: 128 px, mipmaps, uncompressed;
	-- the original 64 px DXT5 looks pixelated
	portrait = "Interface" .. SEP .. "ForeverUI" .. SEP .. "friendsframe" .. SEP .. "battlenet-portrait-hd",
	portraitSide = 60, portraitX = -5, portraitY = 7,
	titleX1 = 58, titleX2 = -24, titleY = -1, titleH = 20, titleTextY = -5,
	closeButton = 24, closeButtonX = -2, closeButtonY = 1,
	frameBoxX1 = 4, frameBoxY1 = -83, frameBoxX2 = -6, frameBoxY2 = 26,
	listX = 8, listY = -87, listX2 = -22, listY2 = 2, listX2NoBar = -4,
	buttonW = 134, buttonH = 21, buttonBottom = 4, buttonLeft = 4, buttonRight = -6,
	tabH = 32, firstTabX = 5, firstTabY = 2, tabGap = 3, tabMargin = 20,
	subTabX = 18, subTabY = -60, subTabH = 24, subTabMin = 100, subTabMax = 150, subTabGap = 1,
	friendRowH = 34, shortRowH = 16,
	stateSide = 16, stateX = 4, stateY = -3, nameX = 20, nameY = -4, infoY = -3,
	highlight = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestLogTitleHighlight",
	ignoreHighlight = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight",
	highlightTint = { 0.243, 0.570, 1 },
	separator = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "UI-FriendsFrame-OnlineDivider",
	state = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "StatusIcon-",
}

-- PortraitFrameTemplate metal with camelot's fixes (nineslicelayoutoverrides.lua): right
-- corners at x = 2, bottom corners at y = -8.
local METAL = {
	{ key = "topLeft", name = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ key = "topRight", name = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ key = "bottomLeft", name = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ key = "bottomRight", name = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

-- Tab art: active pieces from the base sheet (camelot has no c60 ones), inactive from c60.
local TAB_ART = {
	activeLeft = "uiframe-activetab-left", activeMiddle = "_uiframe-activetab-center", activeRight = "uiframe-activetab-right",
	inactiveLeft = "uiframe-tab-left-c60", inactiveMiddle = "_uiframe-tab-center-c60", inactiveRight = "uiframe-tab-right-c60",
}

-- Bottom tabs: Contacts, then the WotLK ones. id is the client tab's, FriendsFrameTab<id>.
-- 3.3.5 lacks camelot's CONTACTS_* strings, so tabs and titles use FRIENDS, FRIENDS_LIST
-- and IGNORE_LIST.
local TABS = {
	{ id = 1, text = "FRIENDS" },
	{ id = 2, text = "WHO" },
	{ id = 3, text = "GUILD" },
	{ id = 4, text = "CHAT" },
	{ id = 5, text = "RAID" },
}
local SUB_TABS = {
	{ id = 1, text = "FRIENDS", title = "FRIENDS_LIST" },
	{ id = 2, text = "IGNORE", title = "IGNORE_LIST" },
}

-- Client global string, or the key itself when missing.
local function txt(key)
	return _G[key] or key
end

-- r, g, b, a of the client color global name, or of default when missing
local function color(name, default)
	local c = _G[name]
	if type(c) == "table" and c.r then
		return c.r, c.g, c.b, c.a
	end
	return default[1], default[2], default[3], default[4]
end

-- ------------------------------------------------------------------ Frame

-- Builds the window art: rock background, top streaks, metal border, portrait, title
-- and close button.
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

	local portraitFrame = CreateFrame("Frame", nil, f)
	portraitFrame:SetAllPoints(f)
	portraitFrame:SetFrameLevel(f:GetFrameLevel() + 19)
	local portrait = portraitFrame:CreateTexture(nil, "OVERLAY")
	portrait:SetWidth(G.portraitSide)
	portrait:SetHeight(G.portraitSide)
	portrait:SetPoint("TOPLEFT", f, "TOPLEFT", G.portraitX, G.portraitY)
	portrait:SetTexture(G.portrait)
	f.portrait = portrait

	local banner = CreateFrame("Frame", nil, f)
	banner:SetFrameLevel(f:GetFrameLevel() + 21)
	banner:SetHeight(G.titleH)
	banner:SetPoint("TOPLEFT", f, "TOPLEFT", G.titleX1, G.titleY)
	banner:SetPoint("TOPRIGHT", f, "TOPRIGHT", G.titleX2, G.titleY)
	f.title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOP", banner, "TOP", 0, G.titleTextY)
	f.banner = banner

	-- Close button: hides the client panel, like the client's own.
	local closeButton = CreateFrame("Button", "ForeverUISocialCloseButton", f)
	closeButton:SetWidth(G.closeButton)
	closeButton:SetHeight(G.closeButton)
	closeButton:SetFrameLevel(f:GetFrameLevel() + 22)
	closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", G.closeButtonX, G.closeButtonY)
	for _, state in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(state[3])
		closeButton[state[1]](closeButton, e and e[1] or "")
		local t = closeButton[state[2]](closeButton)
		if t then
			ForeverUI.SetAtlas(t, state[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(closeButton)
			if state[3] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
	closeButton:SetScript("OnClick", function() HideUIPanel(FriendsFrame) end)
	f.closeButton = closeButton
end

-- --------------------------------------------------------------- Tabs

-- One tab texture. Top tabs use it flipped: a half turn swaps both edges in width and
-- height (SetRotation would drop the atlas rectangle).
local function tabPiece(b, layer, atlas, flipped)
	local t = b:CreateTexture(nil, layer)
	ForeverUI.SetAtlas(t, atlas)
	if flipped then
		local e = ForeverUI.AtlasEntry(atlas)
		if e then t:SetTexCoord(e[3], e[2], e[5], e[4]) end
	end
	return t
end

-- PanelTabButtonTemplate (bottom) or TabSystemButtonArtTemplate + isTabOnTop (top).
-- Two sets of three pieces, active and inactive, plus the highlight: inactive art in ADD
-- at 0.4. atTop: sub-tab above the list
local function createTab(parent, name, atTop)
	local b = CreateFrame("Button", name, parent)
	b:SetHeight(atTop and G.subTabH or G.tabH)
	local a = {}
	a.activeLeft = tabPiece(b, "BACKGROUND", TAB_ART.activeLeft, atTop)
	a.activeRight = tabPiece(b, "BACKGROUND", TAB_ART.activeRight, atTop)
	a.activeMiddle = tabPiece(b, "BACKGROUND", TAB_ART.activeMiddle, atTop)
	a.g = tabPiece(b, "BACKGROUND", TAB_ART.inactiveLeft, atTop)
	a.d = tabPiece(b, "BACKGROUND", TAB_ART.inactiveRight, atTop)
	a.m = tabPiece(b, "BACKGROUND", TAB_ART.inactiveMiddle, atTop)
	a.sg = tabPiece(b, "HIGHLIGHT", TAB_ART.inactiveLeft, atTop)
	a.sd = tabPiece(b, "HIGHLIGHT", TAB_ART.inactiveRight, atTop)
	a.sm = tabPiece(b, "HIGHLIGHT", TAB_ART.inactiveMiddle, atTop)
	for _, t in ipairs({ a.sg, a.sd, a.sm }) do
		t:SetBlendMode("ADD")
		t:SetAlpha(0.4)
	end
	if atTop then
		-- HandleRotation: the flipped right piece moves to the left; SetTabHeight(24) sets all
		-- heights
		for _, t in pairs(a) do t:SetHeight(G.subTabH) end
		a.activeRight:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -7, 0)
		a.activeLeft:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
		a.d:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -6, 0)
		a.g:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
		a.activeMiddle:SetPoint("TOPLEFT", a.activeRight, "TOPRIGHT", 0, 0)
		a.activeMiddle:SetPoint("BOTTOMRIGHT", a.activeLeft, "BOTTOMLEFT", 0, 0)
		a.m:SetPoint("TOPLEFT", a.d, "TOPRIGHT", 0, 0)
		a.m:SetPoint("BOTTOMRIGHT", a.g, "BOTTOMLEFT", 0, 0)
		a.sg:SetPoint("TOPRIGHT", a.g, "TOPRIGHT", 0, 0)
		a.sd:SetPoint("TOPLEFT", a.d, "TOPLEFT", 0, 0)
		a.sm:SetPoint("TOPLEFT", a.m, "TOPLEFT", 0, 0)
		a.sm:SetPoint("BOTTOMRIGHT", a.m, "BOTTOMRIGHT", 0, 0)
	else
		a.activeLeft:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 0)
		a.activeRight:SetPoint("TOPRIGHT", b, "TOPRIGHT", 8, 0)
		a.g:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 0)
		a.d:SetPoint("TOPRIGHT", b, "TOPRIGHT", 7, 0)
		a.activeMiddle:SetPoint("TOPLEFT", a.activeLeft, "TOPRIGHT", 0, 0)
		a.activeMiddle:SetPoint("BOTTOMRIGHT", a.activeRight, "BOTTOMLEFT", 0, 0)
		a.m:SetPoint("TOPLEFT", a.g, "TOPRIGHT", 0, 0)
		a.m:SetPoint("BOTTOMRIGHT", a.d, "BOTTOMLEFT", 0, 0)
		a.sg:SetPoint("TOPLEFT", a.g, "TOPLEFT", 0, 0)
		a.sd:SetPoint("TOPRIGHT", a.d, "TOPRIGHT", 0, 0)
		a.sm:SetPoint("TOPLEFT", a.m, "TOPLEFT", 0, 0)
		a.sm:SetPoint("BOTTOMRIGHT", a.m, "BOTTOMRIGHT", 0, 0)
	end
	b.art = a
	b.atTop = atTop
	local fs = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fs:SetHeight(10)
	b:SetFontString(fs)
	b.text = fs
	return b
end

-- SetTabSelected / PanelTemplates_SelectTab: active art, highlight font, text lowered
-- (bottom) or raised (top), selected tab disabled.
-- selected: this tab is chosen; active: the tab can be clicked
local function selectTab(b, selected, active)
	local a = b.art
	for _, t in ipairs({ a.activeLeft, a.activeMiddle, a.activeRight }) do
		if selected then t:Show() else t:Hide() end
	end
	for _, t in ipairs({ a.g, a.m, a.d }) do
		if selected then t:Hide() else t:Show() end
	end
	local font = selected and GameFontHighlightSmall or (active and GameFontNormalSmall or GameFontDisableSmall)
	b.text:SetFontObject(font)
	b:SetNormalFontObject(font)
	local y
	if b.atTop then
		y = selected and 0 or -3
	else
		y = selected and -3 or 2
	end
	b.text:ClearAllPoints()
	b.text:SetPoint("CENTER", b, "CENTER", 0, y)
	if selected or not active then b:Disable() else b:Enable() end
end

-- PanelTemplates_TabResize / TabSystemButtonMixin:UpdateTabWidth
local function tabWidth(b)
	local text = b.text:GetStringWidth() or 0
	local g = ForeverUI.AtlasEntry(TAB_ART.inactiveLeft)
	local d = ForeverUI.AtlasEntry(TAB_ART.inactiveRight)
	local sides = (g and g[6] or 35) + (d and d[6] or 37)
	if b.atTop then
		local l = sides + 20
		if l < text then l = text + 10 end
		return math.max(G.subTabMin, math.min(G.subTabMax, l))
	end
	return math.max(sides, text + G.tabMargin)
end

-- bottom tabs, shared with other windows (raid browser)
S.createTab, S.selectTab, S.tabWidth = createTab, selectTab, tabWidth

-- ------------------------------------------------------------------ List

local ROWS = {}                        -- rows created once, then reused

-- Creates list row n, holding the parts of every row kind.
local function createRow(n)
	local l = CreateFrame("Button", "ForeverUISocialRow" .. n, S.list)
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	l.background = l:CreateTexture(nil, "BACKGROUND")
	l.background:SetPoint("TOPLEFT", l, "TOPLEFT", 0, -1)
	l.background:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", 0, 1)
	l.state = l:CreateTexture(nil, "ARTWORK")
	l.state:SetWidth(G.stateSide)
	l.state:SetHeight(G.stateSide)
	l.state:SetPoint("TOPLEFT", l, "TOPLEFT", G.stateX, G.stateY)
	l.name = l:CreateFontString(nil, "ARTWORK", "FriendsFont_Normal")
	l.name:SetJustifyH("LEFT")
	l.name:SetHeight(12)
	l.info = l:CreateFontString(nil, "ARTWORK", "FriendsFont_Small")
	l.info:SetJustifyH("LEFT")
	l.info:SetHeight(10)
	l.info:SetPoint("TOPLEFT", l.name, "BOTTOMLEFT", 0, G.infoY)
	l.info:SetPoint("TOPRIGHT", l.name, "BOTTOMRIGHT", 0, G.infoY)
	l.line = l:CreateTexture(nil, "ARTWORK")
	l.line:SetTexture(G.separator)
	l.line:SetAllPoints(l)
	l.title = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
	l.title:SetPoint("LEFT", l, "LEFT", 5, 1)
	l:SetHighlightTexture(G.highlight)
	local s = l:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", l, "TOPLEFT", 0, -1)
		s:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", 0, 1)
	end
	l:SetScript("OnClick", function(self, button) S.click(self, button) end)
	l:SetScript("OnEnter", function(self)
		if self.kind == "friend" and FriendsFrameTooltip_Show then
			FriendsFrameTooltip_Show(self)
		end
	end)
	l:SetScript("OnLeave", function()
		if FriendsTooltip then
			FriendsTooltip.button = nil
			FriendsTooltip:Hide()
		end
	end)
	return l
end

-- Lays out a row for its entry kind: friend, line, header or ignore. Parts of the other
-- kinds are hidden. l: row; e: entry from entries()
local function layoutRow(l, e)
	l.kind = e.kind
	local isFriend, line, header = e.kind == "friend", e.kind == "line", e.kind == "header"
	local ignore = e.kind == "ignore"
	l:SetHeight(isFriend and G.friendRowH or G.shortRowH)
	if isFriend then l.background:Show() else l.background:Hide() end
	if isFriend then l.state:Show() else l.state:Hide() end
	if isFriend or ignore then l.name:Show() else l.name:Hide() end
	if isFriend then l.info:Show() else l.info:Hide() end
	if line then l.line:Show() else l.line:Hide() end
	if header then l.title:Show() else l.title:Hide() end
	l:EnableMouse(isFriend or ignore)
	l:UnlockHighlight()

	local s = l:GetHighlightTexture()
	l.name:ClearAllPoints()
	if isFriend then
		l.name:SetFontObject(FriendsFont_Normal)
		l.name:SetPoint("TOPLEFT", l, "TOPLEFT", G.nameX, G.nameY)
		l.name:SetPoint("TOPRIGHT", l, "TOPRIGHT", -4, G.nameY)
		if s then
			s:SetTexture(G.highlight)
			s:SetVertexColor(G.highlightTint[1], G.highlightTint[2], G.highlightTint[3])
		end
	elseif ignore then
		-- FriendsFrameIgnoreButtonTemplate: GameFontNormal at (10, 1)
		l.name:SetFontObject(GameFontNormal)
		l.name:SetPoint("LEFT", l, "LEFT", 10, 1)
		l.name:SetPoint("RIGHT", l, "RIGHT", -4, 1)
		if s then
			s:SetTexture(G.ignoreHighlight)
			s:SetVertexColor(1, 1, 1)
		end
	end

	l.id = e.index
	l.squelch = e.squelch
	l.buttonType = isFriend and FRIENDS_BUTTON_TYPE_WOW or nil
	if isFriend then
		-- FriendsFrame_SetButton, for a game friend
		local name, level, className, zone, connected, status = GetFriendInfo(e.index)
		l.friendName, l.connected = name, connected
		if connected then
			l.background:SetTexture(color("FRIENDS_WOW_BACKGROUND_COLOR", { 1.0, 0.824, 0.0, 0.05 }))
			if status == CHAT_FLAG_AFK then
				l.state:SetTexture(G.state .. "Away")
			elseif status == CHAT_FLAG_DND then
				l.state:SetTexture(G.state .. "DnD")
			else
				l.state:SetTexture(G.state .. "Online")
			end
			l.name:SetText((name or "") .. ", " .. string.format(txt("FRIENDS_LEVEL_TEMPLATE"), level or 0, className or ""))
			l.name:SetTextColor(color("FRIENDS_WOW_NAME_COLOR", { 0.996, 0.882, 0.361 }))
		else
			l.background:SetTexture(color("FRIENDS_OFFLINE_BACKGROUND_COLOR", { 0.588, 0.588, 0.588, 0.05 }))
			l.state:SetTexture(G.state .. "Offline")
			l.name:SetText(name or "")
			l.name:SetTextColor(color("FRIENDS_GRAY_COLOR", { 0.486, 0.518, 0.541 }))
		end
		l.info:SetText(zone or "")
		l.info:SetTextColor(color("FRIENDS_GRAY_COLOR", { 0.486, 0.518, 0.541 }))
		if GetSelectedFriend() == e.index then l:LockHighlight() end
	elseif ignore then
		local name = GetIgnoreName(e.index)
		if FriendsFrame.selectedSquelchType == SQUELCH_TYPE_IGNORE and GetSelectedIgnore() == e.index then
			l:LockHighlight()
		end
		l.name:SetText(name or txt("UNKNOWN"))
		l.name:SetTextColor(color("NORMAL_FONT_COLOR", { 1, 0.82, 0 }))
	elseif header then
		l.title:SetText(e.text)
	end
end

-- What the list shows, in WotLK order.
local function entries()
	local list = {}
	if S.subTab() == 2 then
		-- IgnoreList_Update: ignored players
		local ignores = GetNumIgnores() or 0
		if ignores > 0 then
			list[#list + 1] = { kind = "header", text = txt("IGNORED") }
			for i = 1, ignores do
				list[#list + 1] = { kind = "ignore", index = i, squelch = SQUELCH_TYPE_IGNORE }
			end
		end
	else
		-- FriendsList_Update: online, a divider, offline
		local total, online = GetNumFriends()
		total, online = total or 0, online or 0
		for i = 1, online do
			list[#list + 1] = { kind = "friend", index = i }
		end
		if online > 0 and total > online then
			list[#list + 1] = { kind = "line" }
		end
		for i = online + 1, total do
			list[#list + 1] = { kind = "friend", index = i }
		end
	end
	return list
end

local function heightOf(e)
	return e.kind == "friend" and G.friendRowH or G.shortRowH
end

-- Fills the rows that fit, from S.offset (friend rows are taller).
function S.layoutList()
	local list = S.content or {}
	local position = S.list:GetHeight() or 0
	if position <= 0 then
		position = G.height + G.listY - (G.frameBoxY2 + G.listY2)
	end
	local total = #list
	S.offset = math.max(0, math.min(S.offset or 0, total - 1))
	local y, rank, n = 0, 0, S.offset + 1
	while n <= total do
		local h = heightOf(list[n])
		if y + h > position then break end
		rank = rank + 1
		local l = ROWS[rank]
		if not l then
			l = createRow(rank)
			ROWS[rank] = l
		end
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -y)
		l:SetPoint("TOPRIGHT", S.list, "TOPRIGHT", 0, -y)
		layoutRow(l, list[n])
		l:Show()
		y = y + h
		n = n + 1
	end
	for i = rank + 1, #ROWS do
		ROWS[i]:Hide()
	end
	S.visibleCount = rank
	S.bar:Configure(total, rank, S.offset)
end

-- ---------------------------------------------------------------- Buttons

-- 3.3.5 has no SetShown
local function showRegion(x, yes)
	if yes then x:Show() else x:Hide() end
end

-- Enables or disables a button (Activate on ForeverUI panel buttons).
local function active(b, yes)
	if b.Activate then b:Activate(yes) elseif yes then b:Enable() else b:Disable() end
end

local function updateButtons()
	local b = S.buttons
	local ignore = S.subTab() == 2
	showRegion(b.add, not ignore)
	showRegion(b.message, not ignore)
	showRegion(b.ignoreButton, ignore)
	showRegion(b.remove, ignore)
	if not ignore then
		-- FriendsList_Update: Send Message only to an online friend
		local selected = GetSelectedFriend() or 0
		local connected = false
		if selected > 0 then
			connected = select(5, GetFriendInfo(selected)) and true or false
		end
		active(b.message, connected)
	else
		local index = 0
		if FriendsFrame.selectedSquelchType == SQUELCH_TYPE_IGNORE then
			index = GetSelectedIgnore() or 0
		end
		active(b.remove, index > 0)
	end
end

-- ------------------------------------------------------------ Update

-- Selected Contacts sub-tab: 1 friends, 2 ignore.
function S.subTab()
	local n = FriendsTabHeader and FriendsTabHeader.selectedTab or 1
	if n ~= 2 then n = 1 end
	return n
end

-- Default selection, like the client: first friend, first ignored player.
local function selectDefault()
	if S.subTab() == 2 then
		local ok = FriendsFrame.selectedSquelchType == SQUELCH_TYPE_IGNORE and (GetSelectedIgnore() or 0) > 0
		if not ok and (GetNumIgnores() or 0) > 0 then
			FriendsFrame_SelectSquelched(SQUELCH_TYPE_IGNORE, 1)
		end
	else
		local total = GetNumFriends() or 0
		if total > 0 and (GetSelectedFriend() or 0) == 0 then
			FriendsFrame_SelectFriend(FRIENDS_BUTTON_TYPE_WOW, 1)
		end
		FriendsFrame.selectedFriend = GetSelectedFriend()
		FriendsFrame.selectedFriendType = FRIENDS_BUTTON_TYPE_WOW
	end
end

-- Bottom tabs follow the client's selected tab; Guild is disabled outside a guild, like
-- the client's (InGuildCheck).
function S.updateTabs()
	local selected = FriendsFrame.selectedTab or 1
	for _, o in ipairs(S.tabs) do
		local client = _G["FriendsFrameTab" .. o.id]
		local isOpen = true
		if client and client.IsEnabled and o.id ~= selected then
			local e = client:IsEnabled()
			isOpen = (e ~= nil and e ~= false and e ~= 0)
		end
		o.button:SetText(txt(o.text))
		selectTab(o.button, o.id == selected, isOpen)
		o.button:SetWidth(tabWidth(o.button))
	end
end

function S.updateContacts()
	local f = S.frame
	if not f then return end
	local sub = S.subTab()
	f.title:SetText(txt(SUB_TABS[sub].title))

	-- sub-tabs
	for _, o in ipairs(S.subTabs) do
		o.button:SetText(txt(o.text))
		selectTab(o.button, o.id == sub, true)
		o.button:SetWidth(tabWidth(o.button))
	end

	selectDefault()
	S.content = entries()
	S.layoutList()
	updateButtons()
end

-- ------------------------------------------------------------ Clicks

function S.click(l, button)
	if l.kind == "friend" then
		if button == "RightButton" then
			local name, _, _, _, connected = GetFriendInfo(l.id)
			ForeverUI.UnitMenu.open(FriendsFrame_ShowDropdown, name, connected, nil, nil, nil, 1)
		else
			PlaySound("igMainMenuOptionCheckBoxOn")
			FriendsFrame_SelectFriend(FRIENDS_BUTTON_TYPE_WOW, l.id)
			FriendsFrame.selectedFriend = l.id
		end
	elseif l.kind == "ignore" then
		PlaySound("igMainMenuOptionCheckBoxOn")
		FriendsFrame_SelectSquelched(l.squelch, l.id)
	end
	S.update()
end

-- ------------------------------------------------------ WotLK or camelot

-- Client frames our window keeps and borrows: the right-click menu and the tooltip.
local KEPT_FRAMES = { "FriendsDropDown", "FriendsTooltip" }

-- A page can keep a client frame (the raid frame of Blizzard_RaidUI...).
function S.keep(name)
	KEPT_FRAMES[#KEPT_FRAMES + 1] = name
end

-- Hides the client panel's own content, except kept frames, and stops it taking the
-- mouse.
local function suppressWotLK()
	local ff = FriendsFrame
	S.killedRegions = S.killedRegions or {}
	for _, r in ipairs({ ff:GetRegions() }) do
		if r:IsShown() then
			S.killedRegions[r] = true
			r:Hide()
		end
	end
	local keep = { [S.frame] = true }
	for _, n in ipairs(KEPT_FRAMES) do
		local c = type(n) == "string" and _G[n] or n
		if c then keep[c] = true end
	end
	-- A protected frame cannot be hidden in combat: in a raid, RaidFrame holds the secure
	-- buttons of Blizzard_RaidUI. It is faded with alpha, which combat allows, and hidden on
	-- the next pass out of combat.
	local combat = InCombatLockdown and InCombatLockdown()
	for _, c in ipairs({ ff:GetChildren() }) do
		if not keep[c] and c:IsShown() then
			if combat and c.IsProtected and c:IsProtected() then
				c:SetAlpha(0)
			else
				c:Hide()
			end
		end
	end
	if not (combat and ff.IsProtected and ff:IsProtected()) then
		ff:EnableMouse(false)
	end
end

-- Pages: one per client tab. Each registers build(frame), update(), showRegion(firstShow),
-- hide() and title().
S.pages = {}
local registeredPages = {}

function S.registerPage(id, def)
	registeredPages[id] = def
end

-- Returns the page of tab id, building it on first use.
local function page(id)
	local pg = S.pages[id]
	if pg then return pg end
	local def = registeredPages[id]
	if not def then return nil end
	local frame = CreateFrame("Frame", "ForeverUISocialPage" .. id, S.frame)
	frame:SetAllPoints(S.frame)
	frame:Hide()
	pg = { id = id, frame = frame, def = def }
	S.pages[id] = pg
	def.build(frame)
	return pg
end

-- Builds a page ahead of time (the raid page, out of combat).
function S.prepare(id)
	if S.frame then page(id) end
end

-- Refreshes the selected page and the tabs.
function S.update()
	S.updateTabs()
	local pg = S.pages[FriendsFrame.selectedTab or 1]
	if pg and pg.frame:IsShown() then
		if pg.def.title then S.frame.title:SetText(pg.def.title() or "") end
		if pg.def.update then pg.def.update() end
	end
end

-- Runs after FriendsFrame_Update, which has already set up the client screen.
-- FriendsFrame stays the client panel (ToggleFriendsFrame, micro button, Esc, panel slot,
-- selectedTab); our window, its child, hides the WotLK content and shows the page of the
-- selected tab. The page redoes what the client subframe does on show (SetWhoToUI,
-- GuildRoster...).
function S.apply()
	if not S.frame or not FriendsFrame:IsShown() then return end
	local selected = FriendsFrame.selectedTab or 1
	-- page first: while building, it can keep a client frame
	page(selected)
	suppressWotLK()
	S.frame:Show()
	for id, pg in pairs(S.pages) do
		if id ~= selected and pg.frame:IsShown() then
			pg.frame:Hide()
			if pg.def.hide then pg.def.hide() end
		end
	end
	local pg = page(selected)
	if pg then
		local wasShown = pg.frame:IsShown()
		pg.frame:Show()
		if pg.def.showRegion then pg.def.showRegion(not wasShown) end
	end
	S.update()
end

-- On close, the open page does what the client subframe does on hide (SetWhoToUI(0)...).
local function close()
	for _, pg in pairs(S.pages) do
		if pg.frame:IsShown() then
			pg.frame:Hide()
			if pg.def.hide then pg.def.hide() end
		end
	end
	if S.popup then S.popup:Hide() end
end

-- ------------------------------------------------------ Shared parts

S.txt = txt
S.color = color
S.G = G

-- A panel button with the window's button font (GameFontNormal).
function S.button(parent, text, width, name)
	return ForeverUI.CreatePanelButton(parent, text, width, G.buttonH, name, "GameFontNormal")
end

-- Column header: WhoFrameColumnHeaderTemplate, whose WotLK art camelot keeps (mainline):
-- WhoFrame-ColumnTabs in three pieces, UI-Character-Tab-Highlight in ADD.
local COLUMN_TABS = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "WhoFrame-ColumnTabs"
local COLUMN_HIGHLIGHT = "Interface" .. SEP .. "PaperDollInfoFrame" .. SEP .. "UI-Character-Tab-Highlight"
S.COLUMN_H = 24

function S.createHeader(parent, name, width, text, onClick)
	local b = CreateFrame("Button", name, parent)
	b:SetHeight(S.COLUMN_H)
	local g = b:CreateTexture(nil, "BACKGROUND")
	g:SetTexture(COLUMN_TABS)
	g:SetTexCoord(0, 0.078125, 0, 0.75)
	g:SetWidth(5)
	g:SetHeight(S.COLUMN_H)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local d = b:CreateTexture(nil, "BACKGROUND")
	d:SetTexture(COLUMN_TABS)
	d:SetTexCoord(0.90625, 0.96875, 0, 0.75)
	d:SetWidth(4)
	d:SetHeight(S.COLUMN_H)
	d:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	local m = b:CreateTexture(nil, "BACKGROUND")
	m:SetTexture(COLUMN_TABS)
	m:SetTexCoord(0.078125, 0.90625, 0, 0.75)
	m:SetHeight(S.COLUMN_H)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	m:SetPoint("RIGHT", d, "LEFT", 0, 0)
	local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", b, "LEFT", 8, 0)
	fs:SetPoint("RIGHT", b, "RIGHT", -8, 0)
	fs:SetJustifyH("LEFT")
	b:SetFontString(fs)
	b.text = fs
	b:SetText(text or "")
	b:SetHighlightTexture(COLUMN_HIGHLIGHT)
	local s = b:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", g, "TOPLEFT", -2, 5)
		s:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 2, -7)
	end
	b:SetWidth(width)
	if onClick then
		b:SetScript("OnClick", function(self)
			onClick(self)
			PlaySound("igMainMenuOptionCheckBoxOn")
		end)
	end
	return b
end

-- Scrolling list with fixed-height rows: area, rows, camelot scroll bar and mouse wheel.
-- create(row, n) builds a row; populate(row, index) fills it; list:Update(total) redraws.
function S.createList(parent, name, lineHeight, create, populate)
	local zone = CreateFrame("Frame", name, parent)
	zone.rows = {}
	zone.offset = 0
	zone.total = 0
	zone.lineHeight = lineHeight
	zone.bar = ForeverUI.CreateScrollBar(name .. "ScrollBar", parent, zone)
	function zone:VisibleCount()
		local h = self:GetHeight() or 0
		if h <= 0 then h = self.defaultHeight or (lineHeight * 10) end
		return math.max(1, math.floor(h / lineHeight))
	end
	function zone:Update(total)
		self.total = total or self.total
		local visibleCount = self:VisibleCount()
		self.offset = math.max(0, math.min(self.offset, self.total - visibleCount))
		for n = 1, visibleCount do
			local l = self.rows[n]
			if not l then
				l = CreateFrame("Button", name .. "Row" .. n, self)
				l:SetHeight(lineHeight)
				l:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(n - 1) * lineHeight)
				l:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(n - 1) * lineHeight)
				create(l, n)
				self.rows[n] = l
			end
			local index = self.offset + n
			if index <= self.total then
				l.index = index
				populate(l, index)
				l:Show()
			else
				l.index = nil
				l:Hide()
			end
		end
		for n = visibleCount + 1, #self.rows do
			self.rows[n]:Hide()
		end
		self.bar:Configure(self.total, visibleCount, self.offset)
		-- the bar appears or goes: the right edge follows
		local hasBar = self.total > visibleCount
		if hasBar ~= self.hasBar then
			self.hasBar = hasBar
			self:PlaceAnchors()
		end
	end
	-- Right edge follows the bar: with it, the list leaves room for it; without it, the list
	-- (and the rows and headers anchored to it) reaches the edge. topLeft and
	-- bottomRightPoint are { point, relativeTo, relativePoint, x, y }; noBar replaces the
	-- bottom-right x when the bar is hidden.
	function zone:FollowBar(topLeft, bottomRightPoint, noBar)
		self.anchors = { topLeft = topLeft, bottomRightPoint = bottomRightPoint, noBar = noBar }
		self:PlaceAnchors()
	end
	function zone:PlaceAnchors()
		local a = self.anchors
		if not a then return end
		local h, b = a.topLeft, a.bottomRightPoint
		self:ClearAllPoints()
		self:SetPoint(h[1], h[2], h[3], h[4], h[5])
		self:SetPoint(b[1], b[2], b[3], self.hasBar and b[4] or a.noBar, b[5])
	end
	zone.bar.onScroll = function(new)
		zone.offset = new
		zone:Update()
	end
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(self, direction)
		self.offset = math.max(0, math.min(self.offset - direction, self.total - self:VisibleCount()))
		self:Update()
	end)
	return zone
end

-- Camelot border on an edit box, ours or the client's (InputBoxTemplate: its <name>Left,
-- Middle and Right pieces are hidden).
function S.skinInput(b)
	local name = b.GetName and b:GetName()
	if name then
		for _, side in ipairs({ "Left", "Middle", "Right" }) do
			local t = _G[name .. side]
			if t then t:SetAlpha(0) t:Hide() end
		end
	end
	local g = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(g, "common-search-border-left", true)
	g:SetWidth(8) g:SetHeight(20)
	g:SetPoint("LEFT", b, "LEFT", -5, 0)
	local d = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(d, "common-search-border-right", true)
	d:SetWidth(8) d:SetHeight(20)
	d:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	local m = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(m, "common-search-border-middle", true)
	m:SetHeight(20)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	m:SetPoint("RIGHT", d, "LEFT", 0, 0)
	b.camelotBorder = { g, m, d }
end

-- Checkbox: checkbox-minimal and checkmark-minimal, 26 x 26, like the Currency tab boxes.
function S.createCheckbox(parent, name, text)
	local c = CreateFrame("CheckButton", name, parent)
	c:SetWidth(26)
	c:SetHeight(26)
	S.skinCell(c)
	c.text = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	c.text:SetPoint("LEFT", c, "RIGHT", 2, 1)
	c.text:SetText(text or "")
	return c
end

-- Camelot art on a checkbox, ours or the client's: empty box and check, without the WotLK
-- pushed and highlight states.
function S.skinCell(c)
	local function place(setMethod, getMethod, atlas)
		local e = ForeverUI.AtlasEntry(atlas)
		if c[setMethod] then c[setMethod](c, e and e[1] or "") end
		local t = c[getMethod] and c[getMethod](c)
		if t then
			ForeverUI.SetAtlas(t, atlas, true)
			t:ClearAllPoints()
			t:SetAllPoints(c)
		end
		return t
	end
	place("SetNormalTexture", "GetNormalTexture", "checkbox-minimal")
	place("SetCheckedTexture", "GetCheckedTexture", "checkmark-minimal")
	local d = place("SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "checkmark-minimal")
	if d then d:SetDesaturated(true) end
	-- The pushed texture replaces the normal one, so it carries the same box, or the outline
	-- vanishes during the click. Only the check comes and goes.
	place("SetPushedTexture", "GetPushedTexture", "checkbox-minimal")
	if c.SetHighlightTexture then c:SetHighlightTexture("") end
end

-- Side popup: member details, guild info, log, saved instances. One at a time, right of
-- the window, like GuildFramePopup_Show; the same portrait-less frame as arena team
-- details.
function S.createPopup(name, width, height)
	local a = CreateFrame("Frame", name, S.frame)
	a:SetWidth(width)
	a:SetHeight(height)
	a:SetPoint("TOPLEFT", S.frame, "TOPRIGHT", 12, 0)
	a:SetFrameLevel(S.frame:GetFrameLevel() + 30)
	a:EnableMouse(true)
	a:Hide()
	ForeverUI.SetPanelArt(a, { topLeftCorner = "ui-frame-metal-cornertopleft", level = 5 })
	local metal = a.foreverSkinLayer or a
	local banner = CreateFrame("Frame", nil, a)
	banner:SetAllPoints(a)
	banner:SetFrameLevel(metal:GetFrameLevel() + 1)
	a.title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	a.title:SetPoint("TOP", a, "TOP", 0, -6)
	a.title:SetWidth(width - 60)
	local closeButton = CreateFrame("Button", nil, a)
	closeButton:SetWidth(G.closeButton)
	closeButton:SetHeight(G.closeButton)
	closeButton:SetFrameLevel(metal:GetFrameLevel() + 2)
	closeButton:SetPoint("TOPRIGHT", a, "TOPRIGHT", 1, 0)
	for _, state in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(state[3])
		closeButton[state[1]](closeButton, e and e[1] or "")
		local t = closeButton[state[2]](closeButton)
		if t then
			ForeverUI.SetAtlas(t, state[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(closeButton)
			if state[3] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
	closeButton:SetScript("OnClick", function() a:Hide() end)
	a.closeButton = closeButton
	a:HookScript("OnShow", function(self)
		if S.popup and S.popup ~= self then S.popup:Hide() end
		S.popup = self
		PlaySound("igSpellBookOpen")
	end)
	a:HookScript("OnHide", function(self)
		if S.popup == self then S.popup = nil end
		PlaySound("igSpellBookClose")
	end)
	S.annexes = S.annexes or {}
	table.insert(S.annexes, a)
	return a
end

-- ------------------------------------------------------------ Assembly

local function build()
	if S.frame or not FriendsFrame then return end
	local f = CreateFrame("Frame", "ForeverUISocialFrame", FriendsFrame)
	f:SetWidth(G.width)
	f:SetHeight(G.height)
	f:SetPoint("TOPLEFT", FriendsFrame, "TOPLEFT", 0, 0)
	f:SetFrameLevel(FriendsFrame:GetFrameLevel() + 1)
	f:EnableMouse(true)
	S.frame = f
	buildFrame(f)

	-- Contacts page: sub-tabs, inset, list and buttons.
	S.registerPage(1, {
		build = function() end,
		title = function() return txt(SUB_TABS[S.subTab()].title) end,
		update = function() S.updateContacts() end,
	})
	local p1 = page(1)
	local contacts = p1.frame

	local frameBox = ForeverUI.CreateInset(contacts, "ForeverUISocialInset")
	frameBox:SetPoint("TOPLEFT", f, "TOPLEFT", G.frameBoxX1, G.frameBoxY1)
	frameBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.frameBoxX2, G.frameBoxY2)
	S.frameBox = frameBox
	local list = CreateFrame("Frame", "ForeverUISocialList", contacts)
	list:SetPoint("TOPLEFT", f, "TOPLEFT", G.listX, G.listY)
	list:SetPoint("BOTTOMRIGHT", frameBox, "BOTTOMRIGHT", G.listX2, G.listY2)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, direction)
		S.offset = math.max(0, math.min((S.offset or 0) - direction, #(S.content or {}) - (S.visibleCount or 0)))
		S.layoutList()
	end)
	S.list = list
	S.bar = ForeverUI.CreateScrollBar("ForeverUISocialScrollBar", contacts, list)
	S.bar.onScroll = function(new)
		S.offset = new
		S.layoutList()
	end
	-- without the bar the list reaches the inset edge, like the Who and Guild lists; rows,
	-- anchored on both sides, follow
	S.bar.onVisibility = function(hasBar)
		list:SetPoint("BOTTOMRIGHT", frameBox, "BOTTOMRIGHT", hasBar and G.listX2 or G.listX2NoBar, G.listY2)
	end

	-- bottom tabs, on the window
	S.tabs = {}
	local previous
	for i, def in ipairs(TABS) do
		local b = createTab(f, "ForeverUISocialTab" .. i, false)
		if previous then
			b:SetPoint("TOPLEFT", previous, "TOPRIGHT", G.tabGap, 0)
		else
			b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", G.firstTabX, G.firstTabY)
		end
		b:SetScript("OnClick", function()
			-- the client tab does the rest: PanelTemplates_Tab_OnClick, FriendsFrame_OnShow, and
			-- closing the guild frame
			local client = _G["FriendsFrameTab" .. def.id]
			if client and client:GetScript("OnClick") then
				client:GetScript("OnClick")(client, "LeftButton")
			else
				PanelTemplates_SetTab(FriendsFrame, def.id)
				FriendsFrame_OnShow()
			end
			PlaySound("igCharacterInfoTab")
		end)
		S.tabs[i] = { id = def.id, text = def.text, button = b }
		previous = b
	end

	-- sub-tabs: Friends and Ignore, state kept by the client
	S.subTabs = {}
	previous = nil
	for i, def in ipairs(SUB_TABS) do
		local b = createTab(contacts, "ForeverUISocialSubTab" .. i, true)
		b:SetFrameLevel(f:GetFrameLevel() + 2)
		if previous then
			b:SetPoint("TOPLEFT", previous, "TOPRIGHT", G.subTabGap, 0)
		else
			b:SetPoint("TOPLEFT", f, "TOPLEFT", G.subTabX, G.subTabY)
		end
		b:SetScript("OnClick", function()
			PanelTemplates_SetTab(FriendsTabHeader, def.id)
			PlaySound("igMainMenuOptionCheckBoxOn")
			S.offset = 0
			FriendsFrame_Update()
		end)
		S.subTabs[i] = { id = def.id, text = def.text, button = b }
		previous = b
	end

	-- buttons, using the client's handlers
	local b = {}
	local function button(text, width)
		return ForeverUI.CreatePanelButton(contacts, text, width, G.buttonH, nil, "GameFontNormal")
	end
	b.add = button(txt("ADD_FRIEND"), G.buttonW)
	b.add:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.buttonLeft, G.buttonBottom)
	b.add:SetScript("OnClick", function(self) FriendsFrameAddFriendButton_OnClick(self) end)
	b.message = button(txt("SEND_MESSAGE"), G.buttonW)
	b.message:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.buttonRight, G.buttonBottom)
	b.message:SetScript("OnClick", function(self) FriendsFrameSendMessageButton_OnClick(self) end)
	b.ignoreButton = button(txt("IGNORE_PLAYER"), G.buttonW)
	b.ignoreButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", G.buttonLeft, G.buttonBottom)
	b.ignoreButton:SetScript("OnClick", function()
		-- OnClick of FriendsFrameIgnorePlayerButton, from the client XML
		if UnitCanCooperate("player", "target") then
			AddIgnore(UnitName("target"))
		else
			StaticPopup_Show("ADD_IGNORE")
		end
	end)
	b.remove = button(txt("REMOVE_PLAYER"), G.buttonW)
	b.remove:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", G.buttonRight, G.buttonBottom)
	b.remove:SetScript("OnClick", function(self) FriendsFrameUnsquelchButton_OnClick(self) end)
	S.buttons = b

	f:Hide()
end

build()

if S.frame then
	hooksecurefunc("FriendsFrame_Update", S.apply)
	FriendsFrame:HookScript("OnShow", S.apply)
	FriendsFrame:HookScript("OnHide", close)
	-- movable by its title; raised when opened or clicked
	ForeverUI.WindowStack.makeMovable(S.frame, S.frame.banner, "social")
	ForeverUI.WindowStack.register("social", FriendsFrame, function()
		local z = { S.frame }
		for _, a in ipairs(S.annexes or {}) do z[#z + 1] = a end
		return z
	end)
	local listener = CreateFrame("Frame")
	for _, ev in ipairs({ "FRIENDLIST_UPDATE", "IGNORELIST_UPDATE",
		"PARTY_MEMBERS_CHANGED", "PLAYER_GUILD_UPDATE" }) do
		listener:RegisterEvent(ev)
	end
	listener:SetScript("OnEvent", function()
		if S.frame:IsVisible() and (FriendsFrame.selectedTab or 1) == 1 then S.update() end
	end)
end

-- Debug: /fui social
function ForeverUI.SocialDebug()
	local say = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t) end
	if not S.frame then
		say(L.SOCIAL_DEBUG_NOT_BUILT)
		return
	end
	local total, online = GetNumFriends()
	say(string.format(L.SOCIAL_DEBUG_STATE,
		tostring(FriendsFrame.selectedTab), tostring(FriendsTabHeader and FriendsTabHeader.selectedTab),
		tostring(S.frame:IsShown()), tostring(FriendsFrame:IsMouseEnabled())))
	say(string.format(L.SOCIAL_DEBUG_FRIENDS,
		tostring(total), tostring(online), tostring(GetSelectedFriend()), tostring(GetNumIgnores()),
		tostring(GetSelectedIgnore())))
	say(string.format(L.SOCIAL_DEBUG_LIST,
		#(S.content or {}), S.visibleCount or 0, S.offset or 0))
end
