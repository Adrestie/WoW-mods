-- ForeverUI: the Chat page of the Social window (client tab 4): chat channels.
-- camelot uses a separate window (blizzard_channels); here channels stay a tab, as in WotLK,
-- after the client's ChannelFrame. Voice chat is left out: the client menu gets no voice
-- fields, so it offers no voice lines.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local S = ForeverUI.Social
if not S or not S.registerPage then
	return
end

local C = {}
S.Chat = C

local SEP = string.char(92)
local P = {
	listW = 172, frameBoxY1 = -60, frameBoxBottom = 32, gap = 4,
	rowH = 20, memberH = 15, rosterTitleH = 18,
	addW = 80, buttonBottom = 4, buttonRight = -6,
	leader = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-LeaderIcon",
	assistant = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-AssistantIcon",
	highlight = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight",
	plus = "common-button-list-plus", minus = "common-button-list-minus",
	plate = "common-button-list-collapseexpand",
}

local txt = S.txt

local function selected()
	return GetSelectedDisplayChannel() or 0
end

-- ---------- Channel list

local function createRow(l)
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	l.plate = ForeverUI.CreateNineSlice(l, P.plate, 12, { 0, 0, 0, 0 }, "BACKGROUND") or {}
	l.text = l:CreateFontString(nil, "ARTWORK", "GameFontNormalSmallLeft")
	l.text:SetPoint("LEFT", l, "LEFT", 5, 0)
	l.text:SetPoint("RIGHT", l, "RIGHT", -20, 0)
	l.text:SetHeight(12)
	l.sign = l:CreateTexture(nil, "ARTWORK")
	l.sign:SetPoint("RIGHT", l, "RIGHT", -6, 0)
	l:SetHighlightTexture(P.highlight)
	local s = l:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	l:SetScript("OnClick", function(self, button) C.click(self, button) end)
end

local function populateRow(l, i)
	local name, header, collapsed, number, count, active, category = GetChannelDisplayInfo(i)
	l.channel, l.header, l.active, l.category = nil, header, active, category
	l:UnlockHighlight()
	if header then
		for _, t in ipairs(l.plate) do t:Show() end
		l.text:ClearAllPoints()
		l.text:SetPoint("LEFT", l, "LEFT", 5, 0)
		l.text:SetPoint("RIGHT", l, "RIGHT", -20, 0)
		l.text:SetText((NORMAL_FONT_COLOR_CODE or "|cffffd200") .. (name or "") .. "|r")
		if count then
			ForeverUI.SetAtlas(l.sign, collapsed and P.plus or P.minus, false)
			l.sign:Show()
			l:Enable()
		else
			l.sign:Hide()
			l:Disable()
		end
	else
		for _, t in ipairs(l.plate) do t:Hide() end
		l.sign:Hide()
		l.text:ClearAllPoints()
		l.text:SetPoint("LEFT", l, "LEFT", 10, 0)
		l.text:SetPoint("RIGHT", l, "RIGHT", -4, 0)
		local num = number and (number .. ". ") or ""
		if active then
			local tail = ""
			if category == "CHANNEL_CATEGORY_GROUP" and count then
				tail = " (" .. count .. ")"
			end
			l.text:SetText((HIGHLIGHT_FONT_COLOR_CODE or "|cffffffff") .. num .. (name or "") .. tail .. "|r")
			l:Enable()
		else
			l.text:SetText((GRAY_FONT_COLOR_CODE or "|cff808080") .. num .. (name or "") .. "|r")
			l:Disable()
		end
		l.channel = name
		if i == selected() then l:LockHighlight() end
	end
end

-- Channel menu, as ChannelList_ShowDropdown. Its fields are set here: the client reads them
-- from its own ChannelButtonN rows.
local function channelMenu(id)
	local name, _, _, _, _, active, category = GetChannelDisplayInfo(id)
	HideDropDownMenu(1)
	local d = ChannelListDropDown
	if not d then return end
	d.global = (category == "CHANNEL_CATEGORY_WORLD") and 1 or nil
	d.group = (category == "CHANNEL_CATEGORY_GROUP") and 1 or nil
	d.custom = (category == "CHANNEL_CATEGORY_CUSTOM") and 1 or nil
	d.initialize = ChannelListDropDown_Initialize
	d.displayMode = "MENU"
	d.id = id
	d.voice = nil
	d.voiceActive = nil
	d.active = active
	d.channelName = name
	ToggleDropDownMenu(1, nil, d, "cursor")
end

-- ChannelList_OnClick
function C.click(l, button)
	PlaySound("igMainMenuOptionCheckBoxOn")
	if ChannelListDropDown then ChannelListDropDown.clicked = nil end
	local id = l.index
	if button == "LeftButton" then
		HideDropDownMenu(1)
		if l.header then
			local _, _, collapsed = GetChannelDisplayInfo(id)
			if collapsed then ExpandChannelHeader(id) else CollapseChannelHeader(id) end
		elseif l.active then
			SetSelectedDisplayChannel(id)
			C.update()
		end
	elseif l.channel then
		if l.category == "CHANNEL_CATEGORY_WORLD" then
			channelMenu(id)
		end
		if l.active then
			GetNumChannelMembers(id)
			if ChannelListDropDown then ChannelListDropDown.clicked = id end
			if l.category ~= "CHANNEL_CATEGORY_WORLD" then channelMenu(id) end
		end
	end
end

-- ---------- Members

local function createMember(l)
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	l.rank = l:CreateTexture(nil, "ARTWORK")
	l.rank:SetWidth(12)
	l.rank:SetHeight(12)
	l.rank:SetPoint("LEFT", l, "LEFT", 2, 1)
	l.name = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	l.name:SetJustifyH("LEFT")
	l.name:SetPoint("LEFT", l, "LEFT", 16, 0)
	l.name:SetPoint("RIGHT", l, "RIGHT", -4, 0)
	l:SetHighlightTexture(P.highlight)
	local s = l:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	l:SetScript("OnClick", function(self, button)
		-- ChannelRoster_OnClick: right click only
		if button == "RightButton" and ChannelRosterFrame_ShowDropdown then
			ForeverUI.UnitMenu.open(ChannelRosterFrame_ShowDropdown, self.index)
		end
	end)
end

local function fillMember(l, i)
	local name, owner, moderator = GetChannelRosterInfo(selected(), i)
	l.name:SetText(name)
	if owner then
		l.rank:SetTexture(P.leader)
		l.rank:Show()
	elseif moderator then
		l.rank:SetTexture(P.assistant)
		l.rank:Show()
	else
		l.rank:Hide()
	end
end

-- ---------- Update

function C.update()
	if not C.list then return end
	C.list:Update(GetNumDisplayChannels() or 0)
	-- ChannelRoster_Update
	local id = selected()
	local name, _, _, _, count, _, category = GetChannelDisplayInfo(id)
	if not count then
		C.title:SetText("")
		C.members:Update(0)
	else
		local tail = (category == "CHANNEL_CATEGORY_GROUP") and (" (" .. count .. ")") or ""
		C.title:SetText((name or "") .. tail)
		C.members:Update(count)
	end
end

-- New channel window: our popup holds the fields and buttons of the client dialog
-- (ChannelFrameDaughterFrame). Joining a channel writes DEFAULT_CHAT_FRAME.channelList;
-- written by addon code, that list and every channel message would be tainted. So OK and
-- Enter stay the client's (ChannelFrameDaughterFrame_Okay); fields and buttons are only moved
-- and reskinned, and the dialog shows none of its own art.
local function createNewChannel()
	local a = S.createPopup("ForeverUIChannelNewFrame", 230, 170)
	a.title:SetText(txt("CHANNEL_NEW_CHANNEL"))
	local l1 = a:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	l1:SetPoint("TOPLEFT", a, "TOPLEFT", 22, -36)
	l1:SetText(txt("CHANNEL_CHANNEL_NAME"))

	local daughter = ChannelFrameDaughterFrame
	local name = ChannelFrameDaughterFrameChannelName
	local password = ChannelFrameDaughterFrameChannelPassword
	local ok = ChannelFrameDaughterFrameOkayButton
	local cancel = ChannelFrameDaughterFrameCancelButton
	if not (daughter and name and password and ok and cancel) then
		return a
	end

	-- The client dialog: parented to UIParent (the client's ChannelFrame tab is never shown),
	-- over our popup, above it, without its art.
	daughter:SetParent(UIParent)
	daughter:ClearAllPoints()
	daughter:SetAllPoints(a)
	daughter:SetFrameStrata(a:GetFrameStrata())
	daughter:SetFrameLevel(a:GetFrameLevel() + 10)
	daughter:EnableMouse(false)
	if daughter.SetBackdrop then daughter:SetBackdrop(nil) end
	for _, r in ipairs({ daughter:GetRegions() }) do
		r:SetAlpha(0)
	end
	for _, suffix in ipairs({ "VoiceChat", "DetailCloseButton" }) do
		ForeverUI.Suppress(_G["ChannelFrameDaughterFrame" .. suffix])
	end

	-- Its two edit boxes, at the place and size of ours
	local function field(b)
		b:SetWidth(180)
		b:SetHeight(20)
		b:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
		b:SetTextInsets(6, 6, 0, 0)
		S.skinInput(b)
		local tag = _G[b:GetName() .. "Label"]
		if tag then tag:SetAlpha(0) end
		local optional = _G[b:GetName() .. "Optional"]
		if optional then optional:SetAlpha(0) end
	end
	field(name)
	name:ClearAllPoints()
	name:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 2, -4)
	local l2 = a:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	l2:SetPoint("TOPLEFT", name, "BOTTOMLEFT", -2, -10)
	l2:SetText(txt("PASSWORD") .. " |cffffffff" .. txt("OPTIONAL_PARENS") .. "|r")
	field(password)
	password:ClearAllPoints()
	password:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 2, -4)

	-- Its two buttons, at the place and size of ours
	for _, b in ipairs({ ok, cancel }) do
		b:SetWidth(96)
		b:SetHeight(S.G.buttonH)
		b:SetNormalFontObject(GameFontNormal)
		b:SetHighlightFontObject(GameFontHighlight)
		if b.SetDisabledFontObject then b:SetDisabledFontObject(GameFontDisable) end
		b:ClearAllPoints()
	end
	ok:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 12, 12)
	cancel:SetPoint("LEFT", ok, "RIGHT", 4, 0)

	-- The popup and the dialog open and close together: OK, Enter, Escape and Cancel close the
	-- client dialog, our close button the popup.
	a:HookScript("OnShow", function()
		daughter:Show()
		name:SetText("")
		password:SetText("")
		name:SetFocus()
	end)
	a:HookScript("OnHide", function() daughter:Hide() end)
	daughter:HookScript("OnHide", function() a:Hide() end)
	a.name, a.password, a.ok, a.cancel = name, password, ok, cancel
	return a
end

-- Builds the Chat page. frame: page frame inside the Social window.
local function build(frame)
	local left = ForeverUI.CreateInset(frame, "ForeverUIChannelListInset")
	left:SetPoint("TOPLEFT", S.frame, "TOPLEFT", 4, P.frameBoxY1)
	left:SetPoint("BOTTOMLEFT", S.frame, "BOTTOMLEFT", 4, P.frameBoxBottom)
	left:SetWidth(P.listW)
	local right = ForeverUI.CreateInset(frame, "ForeverUIChannelRosterInset")
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", P.gap, 0)
	right:SetPoint("BOTTOMRIGHT", S.frame, "BOTTOMRIGHT", -6, P.frameBoxBottom)

	C.list = S.createList(left, "ForeverUIChannelList", P.rowH, createRow, populateRow)
	C.list:SetPoint("TOPLEFT", left, "TOPLEFT", 4, -4)
	C.list:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -16, 4)

	C.title = right:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	C.title:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -6)
	C.title:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -6)
	C.title:SetJustifyH("LEFT")
	C.title:SetHeight(13)
	C.members = S.createList(right, "ForeverUIChannelRoster", P.memberH, createMember, fillMember)
	C.members:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -4 - P.rosterTitleH)
	C.members:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -16, 4)

	C.new = createNewChannel()
	C.add = S.button(frame, txt("ADD"), P.addW)
	C.add:SetPoint("BOTTOMRIGHT", S.frame, "BOTTOMRIGHT", P.buttonRight, P.buttonBottom)
	C.add:SetScript("OnClick", function()
		if C.new:IsShown() then C.new:Hide() else C.new:Show() end
	end)
end

S.registerPage(4, {
	build = build,
	title = function() return txt("CHAT_CHANNELS") end,
	update = C.update,
	hide = function() if C.new then C.new:Hide() end end,
})

local listener = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "CHANNEL_UI_UPDATE", "PARTY_MEMBERS_CHANGED",
	"PARTY_LEADER_CHANGED", "RAID_ROSTER_UPDATE", "CHANNEL_COUNT_UPDATE", "CHANNEL_ROSTER_UPDATE",
	"IGNORELIST_UPDATE", "CHANNEL_FLAGS_UPDATED" }) do
	listener:RegisterEvent(ev)
end
listener:SetScript("OnEvent", function()
	if C.list and C.list:IsVisible() then C.update() end
end)
