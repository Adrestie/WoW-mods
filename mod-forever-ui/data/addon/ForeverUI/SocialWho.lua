-- ForeverUI: the Who page of the Social window (client tab 2).
-- Input, totals and buttons follow the 3.3.5 WhoFrame (FriendsFrame.lua); the player list
-- uses camelot's LFGWhoListFrame cards (wholist.xml / .lua). SetWhoToUI(1) while the page is
-- shown sends /who results to the window instead of the chat.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local S = ForeverUI.Social
if not S or not S.registerPage then
	return
end

local W = {}
S.Who = W

local P = {
	frameBoxX1 = 4, frameBoxY1 = -60, frameBoxX2 = -6, frameBoxY2 = 74,
	listX = 4, listY = -4, listX2 = -22, listX2NoBar = -4, listBottom = 4,
	cardH = 69, corner = 9, textH = 13, textX = 10, textY = -6, rowGap = 6, wordGap = 10,
	background = "common-button-list-large",
	selectedItem = "common-button-list-large-selected",
	hover = "common-button-list-large-hover",
	totalsY = 58, inputY = 30, inputH = 20, inputX = 12,
	buttonBottom = 4, buttonRight = -6, refreshW = 85, buttonW = 120,
}

local txt = S.txt

-- Enables or disables button b; uses b.Activate when it has one.
local function active(b, yes)
	if b.Activate then b:Activate(yes) elseif yes then b:Enable() else b:Disable() end
end

-- camelot GameFontNormalMed1, which 3.3.5 lacks, built from SystemFont_Med2
local function font()
	if W.font then return W.font end
	local f = CreateFont("ForeverUIFontNormalMed1")
	f:SetFontObject(SystemFont_Med2)
	f:SetShadowOffset(1, -1)
	f:SetShadowColor(0, 0, 0)
	f:SetTextColor(1, 0.82, 0)
	W.font = f
	return f
end

-- IsTruncated, missing in 3.3.5: the text is wider than its fixed-width field
local function isTruncated(fs)
	local l = fs:GetWidth()
	return l and l > 0 and fs:GetStringWidth() > l + 0.5
end

-- 3.3.5 has no LFG_WHO_LEVEL or WHO_LIST_LEVEL_TOOLTIP: UNIT_LEVEL_TEMPLATE instead.
local function levelText(level)
	return string.format(txt("UNIT_LEVEL_TEMPLATE"), level or 0)
end

function W.update()
	if not W.list then return end
	local count, total = GetNumWhoResults()
	count, total = count or 0, total or 0
	local shown = ""
	if total > (MAX_WHOS_FROM_SERVER or 50) then
		shown = string.format(txt("WHO_FRAME_SHOWN_TEMPLATE"), MAX_WHOS_FROM_SERVER or 50)
	end
	W.totals:SetText(string.format(txt("WHO_FRAME_TOTAL_TEMPLATE"), total) .. "  " .. shown)
	if W.selected and W.selected > count then W.selected = nil end
	W.selectedName = W.selected and GetWhoInfo(W.selected) or nil
	active(W.add, W.selected ~= nil)
	active(W.inviteButton, W.selected ~= nil)
	W.list:Update(count)
end

-- -------------------------------------------------------------- cards

local function showRegion(slices, yes)
	for _, t in ipairs(slices) do
		if yes then t:Show() else t:Hide() end
	end
end

-- Card (LFGWhoListButtonTemplate, 69 high). The three images are nine-sliced (corners of 9
-- measured on the 169 x 69 art); stretched whole, their corners distort.
local function createCard(l)
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local edges = { 0, 0, 0, 0 }
	l.background = ForeverUI.CreateNineSlice(l, P.background, P.corner, edges, "BACKGROUND") or {}
	l.selectedItem = ForeverUI.CreateNineSlice(l, P.selectedItem, P.corner, edges, "BORDER") or {}
	showRegion(l.selectedItem, false)
	-- hover: the HIGHLIGHT layer, which the button shows under the mouse
	l.hover = ForeverUI.CreateNineSlice(l, P.hover, P.corner, edges, "HIGHLIGHT") or {}
	for _, t in ipairs(l.hover) do t:SetBlendMode("ADD") end

	local white = HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
	local gray = FRIENDS_GRAY_COLOR or { r = 0.486, g = 0.518, b = 0.541 }
	local function text(color)
		local fs = l:CreateFontString(nil, "ARTWORK")
		fs:SetFontObject(font())
		fs:SetJustifyH("LEFT")
		fs:SetHeight(P.textH)
		if color then fs:SetTextColor(color.r, color.g, color.b) end
		return fs
	end
	-- centres of rows 2 and 3, to bound class and guild to the right edge
	local y2 = P.textY - P.textH - P.rowGap
	local y3 = y2 - P.textH - P.rowGap
	l.name = text()
	l.name:SetPoint("TOPLEFT", l, "TOPLEFT", P.textX, P.textY)
	l.name:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, P.textY)
	l.level = text(white)
	l.level:SetPoint("TOPLEFT", l.name, "BOTTOMLEFT", 0, -P.rowGap)
	l.race = text(white)
	l.race:SetPoint("LEFT", l.level, "RIGHT", P.wordGap, 0)
	l.className = text(white)
	l.className:SetPoint("LEFT", l.race, "RIGHT", P.wordGap, 0)
	l.className:SetPoint("RIGHT", l, "TOPRIGHT", 0, y2 - P.textH / 2)
	l.variable = text(gray)
	l.variable:SetPoint("TOPLEFT", l.level, "BOTTOMLEFT", 0, -P.rowGap)
	l.guild = text(gray)
	l.guild:SetPoint("LEFT", l.variable, "RIGHT", P.wordGap, 0)
	l.guild:SetPoint("RIGHT", l, "TOPRIGHT", 0, y3 - P.textH / 2)

	l:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			if W.selected == self.index then W.selected = nil else W.selected = self.index end
			W.update()
		else
			FriendsFrame_ShowDropdown(GetWhoInfo(self.index), 1)
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	l:SetScript("OnEnter", function(self)
		if self.tooltipFrame then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(self.tooltipFrame[1])
			GameTooltip:AddLine(self.tooltipFrame[2], 1, 1, 1)
			GameTooltip:AddLine(self.tooltipFrame[3], 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	l:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- LFGWhoListButtonMixin:InitButton
local function populateCard(l, index)
	local name, guild, level, race, className, zone, file = GetWhoInfo(index)
	local c = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file] or HIGHLIGHT_FONT_COLOR
	l.name:SetText(name)
	l.level:SetText(levelText(level))
	l.race:SetText(race)
	l.className:SetText(className)
	l.className:SetTextColor(c.r, c.g, c.b)
	l.variable:SetText(zone)
	l.guild:SetText(guild)
	showRegion(l.selectedItem, W.selected == index)
	if isTruncated(l.variable) or isTruncated(l.level) or isTruncated(l.name) then
		l.tooltipFrame = { name, levelText(level), zone }
	else
		l.tooltipFrame = nil
	end
end

local function build(frame)
	local frameBox = ForeverUI.CreateInset(frame, "ForeverUIWhoInset")
	frameBox:SetPoint("TOPLEFT", S.frame, "TOPLEFT", P.frameBoxX1, P.frameBoxY1)
	frameBox:SetPoint("BOTTOMRIGHT", S.frame, "BOTTOMRIGHT", P.frameBoxX2, P.frameBoxY2)

	W.list = S.createList(frameBox, "ForeverUIWhoList", P.cardH, createCard, populateCard)
	W.list:FollowBar({ "TOPLEFT", frameBox, "TOPLEFT", P.listX, P.listY },
		{ "BOTTOMRIGHT", frameBox, "BOTTOMRIGHT", P.listX2, P.listBottom }, P.listX2NoBar)

	W.totals = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	W.totals:SetPoint("BOTTOM", S.frame, "BOTTOM", 0, P.totalsY)

	-- Input: camelot's field (InputBoxVisualTemplate), like the spellbook search
	local b = CreateFrame("EditBox", "ForeverUIWhoEditBox", frame)
	b:SetAutoFocus(false)
	b:SetHeight(P.inputH)
	b:SetPoint("BOTTOMLEFT", S.frame, "BOTTOMLEFT", P.inputX, P.inputY)
	b:SetPoint("BOTTOMRIGHT", S.frame, "BOTTOMRIGHT", -P.inputX, P.inputY)
	b:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
	b:SetTextInsets(6, 6, 0, 0)
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
	b:SetScript("OnEnterPressed", function(self)
		SendWho(self:GetText())
		self:ClearFocus()
	end)
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	W.input = b

	W.inviteButton = S.button(frame, txt("GROUP_INVITE"), P.buttonW)
	W.inviteButton:SetPoint("BOTTOMRIGHT", S.frame, "BOTTOMRIGHT", P.buttonRight, P.buttonBottom)
	W.inviteButton:SetScript("OnClick", function()
		if W.selectedName then InviteUnit(W.selectedName) end
	end)
	W.add = S.button(frame, txt("ADD_FRIEND"), P.buttonW)
	W.add:SetPoint("RIGHT", W.inviteButton, "LEFT", 0, 0)
	W.add:SetScript("OnClick", function()
		if W.selectedName then AddFriend(W.selectedName) end
	end)
	W.refresh = S.button(frame, txt("REFRESH"), P.refreshW)
	W.refresh:SetPoint("RIGHT", W.add, "LEFT", 0, 0)
	W.refresh:SetScript("OnClick", function()
		SendWho(W.input:GetText())
		W.selected = nil
	end)
end

S.registerPage(2, {
	build = build,
	title = function() return txt("WHO_LIST") end,
	update = W.update,
	-- WhoFrame OnShow / OnHide
	showRegion = function() SetWhoToUI(1) end,
	hide = function() SetWhoToUI(0) end,
})

local listener = CreateFrame("Frame")
listener:RegisterEvent("WHO_LIST_UPDATE")
listener:SetScript("OnEvent", function()
	if W.list and W.list:IsVisible() then W.update() end
end)
