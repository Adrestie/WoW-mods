-- ForeverUI: the mail windows (MailFrame inbox and send, OpenMailFrame) with Camelot's layout.
-- The client's frames and logic stay; the layouts it redoes on every update (attachments, bars,
-- text height) are redone after it with Camelot's numbers. Auction invoices keep the 3.3.5
-- layout; the 3.3.5 stationery picker (StationeryPopupFrame) is not used.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates
local L = ForeverUI.L

local C = {}
ForeverUI.Mail = C

local SEP = string.char(92)

local N = {
	window = { 338, 424 },
	portrait = { side = 48, x = 1, y = 1.5 },
	inset = { inbox = { 4, -58, -6, 4 }, sending = { 4, -80, -6, 26 } },
	tab = { x = 14, y = -30, gap = 3 },
	inbox = { background = { 512, 7, -62 }, first = { 13, -70 }, page = { 0, 8, 192 },
		previous = { 14, 10 }, following = { -14, 10 }, tooMuchMail = { 0, -25 },
		openAll = { 120, 24, 0, 26 }, readGray = 0.5 },
	sending = { bar1 = { 2, -337 }, scroll = { 8, -83 }, bar = { 10, -4, 3 },
		name = { 90, -30, 109, 25, edge = -2 }, cost = { -4, -34 }, moneyButton = { 15, 37 },
		choice = { 20, 12 }, moneyInset = { 4, 4, 170, 27 }, moneyBorder = { 7, 6, 166, 25 },
		purse = { 175, 8 }, cancel = { -7, 4 }, attachmentBackground = { -1, 1 } },
	pieces = { sending = { left = 14, right = 0, top = 82, stepX = -2, barX = 2, barY = 96 },
		reading = { left = 14, right = 47, top = 28, stepX = 6, barX = 2, barY = 39 } },
	reading = { position = { 46, 0 }, inset = { 4, -80, -6, 26 }, sender = { 105, -33 },
		subject = { 105, -55 }, spam = { -12, -32 }, senderEnd = { -5, -12 },
		scroll = { 8, -84 }, bar = { 10, -3, 5 }, close = { -6, 4 } },
	openDelay = 0.15,
	-- Letter page: Stationery*1 is 252 wide and Stationery*2's torn edge is opaque up to its
	-- column 49, so the page ends at 302 in the scroll frame, 310 in the window. Without a bar,
	-- its left part stretches by 18 to end 4 from the inset's right edge (332), as on the left;
	-- the scroll frame and its child reach the page end (320), and the text keeps the same margin
	-- on both sides: send (20 from the page) 280, letter (10) 300.
	stationery = { left = 252, noBar = 18, scroll = 320, sending = 280, reading = 300 },
}

local ART = {
	icon = "Interface" .. SEP .. "MailFrame" .. SEP .. "Mail-Icon",
	inboxBackground = "Interface" .. SEP .. "ForeverUI" .. SEP .. "mailframe" .. SEP .. "ui-mailframebg",
	marble = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	money = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	stationery = "Interface" .. SEP .. "Stationery" .. SEP .. "StationeryTest",
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- InsetFrameTemplate: marble and trim as regions of f, anchored to a helper frame
-- that callers re-anchor
local function inset(f)
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	local marble = f:CreateTexture(nil, "BACKGROUND")
	marble:SetTexture(ART.marble, true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(rect)
	rect.marble = marble
	rect.trim = Tpl.NineSlice(f, "InsetFrameTemplate", rect)
	return rect
end

local function placeInset(rect, f, e)
	rect:ClearAllPoints()
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", e[1], e[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", e[3], e[4])
end

-- ThinGoldEdgeTemplate
local function goldBorder(f, rect)
	local function piece(u1, u2, v1, v2)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ART.money)
		t:SetTexCoord(u1, u2, v1, v2)
		return t
	end
	local g = piece(0.953125, 0.9921875, 0, 0.296875)
	g:SetWidth(7)
	g:SetPoint("TOPLEFT", rect, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", rect, "BOTTOMLEFT")
	local d = piece(0, 0.0546875, 0, 0.296875)
	d:SetWidth(7)
	d:SetPoint("TOPRIGHT", rect, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT")
	local m = piece(0, 0.9921875, 0.3125, 0.609375)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	return { g, m, d }
end

-- Hides the UI-Character-ScrollBar background of a scroll frame (two textures, one unnamed)
local function blankBarBackground(sf)
	for _, r in ipairs({ sf:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" and string.find(string.lower(t), "ui-character-scrollbar", 1, true) then
				r:SetAlpha(0)
			end
		end
	end
end

-- ------------------------------------------------------------ tabs

-- After MailFrameTab_OnClick: title, inset, tabs
function C.AfterTab()
	local f = MailFrame
	local h = f.foreverSkin
	if not h then return end
	local sending = f.selectedTab == 2
	h.title:SetText(sending and SENDMAIL or INBOX)
	placeInset(h.inset, f, sending and N.inset.sending or N.inset.inbox)
	local S = ForeverUI.Social
	for i, o in ipairs(C.tabs or {}) do
		S.selectTab(o, f.selectedTab == i, true)
		o:SetWidth(S.tabWidth(o))
	end
end

-- ------------------------------------------------------------ inbox

-- After InboxFrame_Update: quality outline of each letter's first attachment, grayed once read
function C.AfterInbox()
	local page = InboxFrame.pageNum or 1
	for i = 1, INBOXITEMS_TO_DISPLAY do
		local index = (page - 1) * INBOXITEMS_TO_DISPLAY + i
		local b = _G["MailItem" .. i .. "Button"]
		local isRead, piece
		if index <= GetInboxNumItems() then
			local _, _, _, _, _, _, _, hasItem, wasRead = GetInboxHeaderInfo(index)
			isRead = wasRead
			if hasItem then
				for p = 1, ATTACHMENTS_MAX_RECEIVE do
					local name, _, _, q = GetInboxItem(index, p)
					if name then piece = q break end
				end
			end
		end
		Tpl.QualityOutline(b, piece)
		if isRead and piece then
			local g = N.inbox.readGray
			b.foreverOutline:SetVertexColor(g, g, g)
		end
	end
end

-- Open All (camelot OpenAllMailMixin) on 3.3.5 functions: TakeInboxMoney, TakeInboxItem, 0.15 s
-- apart. 3.3.5 does not say which item failed (MAIL_FAILED has no argument), so Camelot's
-- failure tracking is missing.
local open = { mail = 1, piece = ATTACHMENTS_MAX, pending = nil }

local function freeSlots()
	local n = 0
	for bag = 0, NUM_BAG_SLOTS do
		n = n + (GetContainerNumFreeSlots(bag) or 0)
	end
	return n
end

local function stop()
	local b = C.openAll
	open.mail, open.piece, open.pending = 1, ATTACHMENTS_MAX, nil
	b:Enable()
	b:SetText(L.MAIL_OPEN_ALL)
	b:UnregisterEvent("MAIL_INBOX_UPDATE")
end

-- GM letters and COD letters are opened by hand
local function skipLetter(i)
	local _, _, _, _, _, cod, _, _, _, _, _, _, isGM = GetInboxHeaderInfo(i)
	return isGM or (cod and cod > 0)
end

-- Skips empty slot p of letter i, unless the letter carries money
local function skipAttachment(i, p)
	local _, _, _, _, money = GetInboxHeaderInfo(i)
	if money and money > 0 then return false end
	return GetInboxItem(i, p) == nil
end

local function nextLetter()
	open.mail = open.mail + 1
	open.piece = ATTACHMENTS_MAX
	return open.mail <= GetInboxNumItems()
end

-- Moves to the next letter and slot to take; false when none is left
local function nextAttachment()
	while true do
		if open.mail > GetInboxNumItems() then return false end
		if skipLetter(open.mail) then
			if not nextLetter() then return false end
		else
			while open.piece > 0 and skipAttachment(open.mail, open.piece) do
				open.piece = open.piece - 1
			end
			if open.piece > 0 then return true end
			if not nextLetter() then return false end
		end
	end
end

-- Takes the next money or item, then waits openDelay before the next one
local function process()
	if freeSlots() == 0 or not nextAttachment() then
		stop()
		return
	end
	local _, _, _, _, money, _, _, count = GetInboxHeaderInfo(open.mail)
	if money and money > 0 then
		TakeInboxMoney(open.mail)
		open.pending = N.openDelay
	elseif count and count > 0 then
		TakeInboxItem(open.mail, open.piece)
		open.pending = N.openDelay
	else
		process()
	end
end

function C.OpenAll()
	local b = C.openAll
	open.mail, open.piece, open.pending = 1, ATTACHMENTS_MAX, nil
	open.count = GetInboxNumItems()
	b:Disable()
	b:SetText(L.MAIL_OPEN_ALL_OPENING)
	b:RegisterEvent("MAIL_INBOX_UPDATE")
	process()
end

local function buildOpenAllButton()
	local T = N.inbox.openAll
	local b = CreateFrame("Button", "ForeverUIOpenAllMail", InboxFrame, "UIPanelButtonTemplate")
	b:SetWidth(T[1])
	b:SetHeight(T[2])
	b:SetPoint("CENTER", InboxFrame, "BOTTOM", T[3], T[4])
	b:SetText(L.MAIL_OPEN_ALL)
	Tpl.PanelButton(b)
	b:SetScript("OnClick", C.OpenAll)
	b:SetScript("OnHide", stop)
	b:SetScript("OnEvent", function()
		-- A letter is gone: restart from the first
		if open.count ~= GetInboxNumItems() then
			open.mail, open.piece = 1, ATTACHMENTS_MAX
			open.count = GetInboxNumItems()
		end
	end)
	b:SetScript("OnUpdate", function(_, e)
		if open.pending then
			open.pending = open.pending - e
			if open.pending <= 0 then
				open.pending = nil
				process()
			end
		end
	end)
	C.openAll = b
end

local function inbox()
	local R = N.inbox
	local background = InboxFrame:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(ART.inboxBackground)
	background:SetWidth(R.background[1])
	background:SetHeight(R.background[1])
	background:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", R.background[2], R.background[3])
	C.inboxBackground = background
	InboxTitleText:SetAlpha(0)
	place(MailItem1, "TOPLEFT", InboxFrame, "TOPLEFT", R.first[1], R.first[2])
	InboxCurrentPage:SetWidth(R.page[3])
	place(InboxCurrentPage, "BOTTOM", InboxFrame, "BOTTOM", R.page[1], R.page[2])
	place(InboxPrevPageButton, "BOTTOMLEFT", InboxFrame, "BOTTOMLEFT", R.previous[1], R.previous[2])
	place(InboxNextPageButton, "BOTTOMRIGHT", InboxFrame, "BOTTOMRIGHT", R.following[1], R.following[2])
	place(InboxTooMuchMail, "TOP", InboxFrame, "TOP", R.tooMuchMail[1], R.tooMuchMail[2])
	buildOpenAllButton()
	hooksecurefunc("InboxFrame_Update", C.AfterInbox)
end

-- ------------------------------------------------------------ send

-- After SendMailFrame_Update: attachments, bar and text height with Camelot's numbers;
-- the attachments' quality outline
function C.AfterSend()
	local P = N.pieces.sending
	local ranks = SendMailFrame.maxRowsShown or 1
	local first = SendMailAttachment1
	local width = SendMailFrame:GetWidth() - P.left - P.right
	local iconX, iconY = first:GetWidth() + 2, first:GetHeight() + 2
	local gapX1 = math.floor((width - iconX * ATTACHMENTS_PER_ROW_SEND) / (ATTACHMENTS_PER_ROW_SEND - 1))
	local gapX2 = math.floor((width - iconX * ATTACHMENTS_PER_ROW_SEND - gapX1 * (ATTACHMENTS_PER_ROW_SEND - 1)) / 2)
	local gapY1, gapY2 = 5, 6
	local height = gapY2 * 2 + gapY1 * (ranks - 1) + iconY * ranks
	local indentX = P.left + gapX2
	local indentY = P.top + gapY2 + iconY
	local stepX = iconX + gapX1 + P.stepX
	local stepY = iconY + gapY1
	local scroll = 249 - height
	SendMailScrollFrame:SetHeight(scroll)
	SendMailScrollChildFrame:SetHeight(scroll)
	place(SendMailHorizontalBarLeft2, "TOPLEFT", SendMailFrame, "BOTTOMLEFT", P.barX, P.barY + height)
	-- Camelot's stationery, always the same
	SendStationeryBackgroundLeft:SetTexture(ART.stationery .. "1")
	SendStationeryBackgroundRight:SetTexture(ART.stationery .. "2")
	local cx, cy = 0, ranks - 1
	for i = 1, ATTACHMENTS_MAX_SEND do
		local b = _G["SendMailAttachment" .. i]
		if cy >= 0 then
			place(b, "TOPLEFT", SendMailFrame, "BOTTOMLEFT", indentX + stepX * cx, indentY + stepY * cy)
			cx = cx + 1
			if cx >= ATTACHMENTS_PER_ROW_SEND then
				cy, cx = cy - 1, 0
			end
		end
		local name, _, _, q = GetSendMailItem(i)
		Tpl.QualityOutline(b, name and q or nil)
	end
end

local function sending(f)
	local E = N.sending
	local s = SendMailFrame
	SendMailTitleText:SetAlpha(0)
	place(SendMailHorizontalBarLeft, "TOPLEFT", s, "TOPLEFT", E.bar1[1], E.bar1[2])
	place(SendMailScrollFrame, "TOPLEFT", s, "TOPLEFT", E.scroll[1], E.scroll[2])
	blankBarBackground(SendMailScrollFrame)
	Tpl.BarAt(SendMailScrollFrameScrollBar, SendMailScrollFrame, E.bar[1], E.bar[2], E.bar[3])
	-- The bar shows only when needed; the text and the page take its room
	-- (296 / 300 / 270 from the 3.3.5 template)
	local Pp = N.stationery
	Tpl.BarByContent(SendMailScrollFrame, function(hasBar)
		SendMailScrollFrame:SetWidth(hasBar and 296 or Pp.scroll)
		SendMailScrollChildFrame:SetWidth(hasBar and 300 or Pp.scroll)
		SendMailBodyEditBox:SetWidth(hasBar and 270 or Pp.sending)
		SendStationeryBackgroundLeft:SetWidth(Pp.left + (hasBar and 0 or Pp.noBar))
	end)
	local name = SendMailNameEditBox
	name:SetWidth(E.name[3])
	name:SetHeight(E.name[4])
	place(name, "TOPLEFT", s, "TOPLEFT", E.name[1], E.name[2])
	place(SendMailNameEditBoxLeft, "TOPLEFT", name, "TOPLEFT", -8, E.name.edge)
	place(SendMailSubjectEditBox, "TOPLEFT", name, "BOTTOMLEFT", 0, 0)
	place(SendMailCostMoneyFrame, "TOPRIGHT", s, "TOPRIGHT", E.cost[1], E.cost[2])
	place(SendMailMoneyButton, "BOTTOMLEFT", s, "BOTTOMLEFT", E.moneyButton[1], E.moneyButton[2])
	place(SendMailSendMoneyButton, "TOPLEFT", SendMailMoney, "TOPRIGHT", E.choice[1], E.choice[2])
	-- Money: inset and gold border, as regions of the send frame
	local ea = inset(s)
	ea:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", E.moneyInset[1], E.moneyInset[2])
	ea:SetPoint("TOPRIGHT", s, "BOTTOMLEFT", E.moneyInset[3], E.moneyInset[4])
	C.moneyInset = ea
	local edge = CreateFrame("Frame", nil, s)
	edge:EnableMouse(false)
	edge:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", E.moneyBorder[1], E.moneyBorder[2])
	edge:SetPoint("TOPRIGHT", s, "BOTTOMLEFT", E.moneyBorder[3], E.moneyBorder[4])
	C.moneyBorder = edge
	C.goldBorder = goldBorder(s, edge)
	place(SendMailMoneyFrame, "BOTTOMRIGHT", s, "BOTTOMLEFT", E.purse[1], E.purse[2])
	place(SendMailCancelButton, "BOTTOMRIGHT", s, "BOTTOMRIGHT", E.cancel[1], E.cancel[2])
	-- Each attachment's background: UI-Slot-Background at (-1, 1)
	for i = 1, ATTACHMENTS_MAX do
		local b = _G["SendMailAttachment" .. i]
		for _, r in ipairs({ b:GetRegions() }) do
			if r:GetObjectType() == "Texture" and r:GetDrawLayer() == "BACKGROUND" then
				place(r, "TOPLEFT", b, "TOPLEFT", E.attachmentBackground[1], E.attachmentBackground[2])
			end
		end
	end
	hooksecurefunc("SendMailFrame_Update", C.AfterSend)
end

-- ------------------------------------------------------------ open letter

-- After OpenMail_Update: portrait, sender, attachments and bar with Camelot's numbers,
-- quality outline
function C.AfterRead()
	local o = OpenMailFrame
	local h = o.foreverSkin
	local id = InboxFrame.openMailID
	if not h or not id or id == 0 then return end
	local _, stationery = GetInboxHeaderInfo(id)
	h.portrait:SetTexture(stationery or ART.icon)
	local Lc = N.reading
	local fs = OpenMailSender
	fs:ClearAllPoints()
	fs:SetPoint("LEFT", OpenMailSenderLabel, "RIGHT", 5, 0)
	if OpenMailReportSpamButton:IsShown() then
		fs:SetPoint("RIGHT", OpenMailReportSpamButton, "LEFT", Lc.senderEnd[1], 0)
	else
		fs:SetPoint("RIGHT", o, "RIGHT", Lc.senderEnd[2], 0)
	end

	local P = N.pieces.reading
	local ranks = o.activeAttachmentRowPositions and #o.activeAttachmentRowPositions or 0
	local first = OpenMailAttachmentButton1
	local width = o:GetWidth() - P.left - P.right
	local iconX, iconY = first:GetWidth() + 2, first:GetHeight() + 2
	local gapX1 = math.floor((width - iconX * ATTACHMENTS_PER_ROW_RECEIVE) / (ATTACHMENTS_PER_ROW_RECEIVE - 1))
	local gapX2 = math.floor((width - iconX * ATTACHMENTS_PER_ROW_RECEIVE - gapX1 * (ATTACHMENTS_PER_ROW_RECEIVE - 1)) / 2)
	local gapY1, gapY2 = 3, 3
	local text = OpenMailAttachmentText
	local height = gapY2 + text:GetHeight() + gapY2 + iconY * ranks + gapY1 * (ranks - 1) + gapY2
	local indentX = P.left + gapX2
	local indentY = P.top + gapY2
	local stepX = iconX + gapX1 + P.stepX
	local stepY = iconY + gapY1
	local scroll = 305 - height
	if scroll > 256 then
		scroll = 256
		height = 305 - scroll
	end
	OpenMailScrollFrame:SetHeight(scroll)
	OpenMailScrollChildFrame:SetHeight(scroll)
	place(OpenMailHorizontalBarLeft, "TOPLEFT", o, "BOTTOMLEFT", P.barX, P.barY + height)
	if (o.itemButtonCount or 0) > 0 then
		place(text, "TOPLEFT", o, "BOTTOMLEFT", indentX,
			indentY + iconY * ranks + gapY1 * (ranks - 1) + gapY2 + text:GetHeight())
	else
		place(text, "TOPLEFT", o, "BOTTOMLEFT", P.left + (width - text:GetWidth()) / 2,
			indentY + (height - text:GetHeight()) / 2 + text:GetHeight())
	end
	if ranks > 0 and o.activeAttachmentButtons then
		local rank = 1
		local cx = o.activeAttachmentRowPositions[1].cursorxstart
		local cxEnd = o.activeAttachmentRowPositions[1].cursorxend
		local cy = ranks - 1
		for _, b in pairs(o.activeAttachmentButtons) do
			place(b, "TOPLEFT", o, "BOTTOMLEFT", indentX + stepX * cx, indentY + iconY + stepY * cy)
			if b ~= OpenMailLetterButton and b ~= OpenMailMoneyButton then
				local _, _, _, q = GetInboxItem(id, b:GetID())
				Tpl.QualityOutline(b, q)
			else
				Tpl.QualityOutline(b, nil)
			end
			cx = cx + 1
			if cx > cxEnd then
				rank = rank + 1
				cy = cy - 1
				if rank <= ranks then
					cx = o.activeAttachmentRowPositions[rank].cursorxstart
					cxEnd = o.activeAttachmentRowPositions[rank].cursorxend
				end
			end
		end
	end
end

local function reading()
	local o = OpenMailFrame
	local Lc = N.reading
	for _, r in ipairs({ OpenMailFrameIcon, OpenMailFrameTopLeft, OpenMailFrameTopRight, OpenMailFrameBotLeft,
		OpenMailFrameBotRight, OpenMailTitleText }) do
		r:SetAlpha(0)
	end
	o:SetWidth(N.window[1])
	o:SetHeight(N.window[2])
	o:SetHitRectInsets(0, 0, 0, 0)
	place(o, "TOPLEFT", MailFrame, "TOPRIGHT", Lc.position[1], Lc.position[2])
	local skin = Tpl.PortraitWindow(o, {
		portrait = ART.icon, portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = OPENMAIL,
	})
	o.foreverSkin = skin
	skin.inset = inset(o)
	placeInset(skin.inset, o, Lc.inset)
	place(OpenMailSenderLabel, "TOPRIGHT", o, "TOPLEFT", Lc.sender[1], Lc.sender[2])
	place(OpenMailSubjectLabel, "TOPRIGHT", o, "TOPLEFT", Lc.subject[1], Lc.subject[2])
	OpenMailSender:SetJustifyH("LEFT")
	place(OpenMailReportSpamButton, "TOPRIGHT", o, "TOPRIGHT", Lc.spam[1], Lc.spam[2])
	place(OpenMailScrollFrame, "TOPLEFT", o, "TOPLEFT", Lc.scroll[1], Lc.scroll[2])
	blankBarBackground(OpenMailScrollFrame)
	Tpl.BarAt(OpenMailScrollFrameScrollBar, OpenMailScrollFrame, Lc.bar[1], Lc.bar[2], Lc.bar[3])
	-- The bar shows only when needed; the text and the page take its room (296 / 276)
	local Pp = N.stationery
	Tpl.BarByContent(OpenMailScrollFrame, function(hasBar)
		OpenMailScrollFrame:SetWidth(hasBar and 296 or Pp.scroll)
		OpenMailScrollChildFrame:SetWidth(hasBar and 296 or Pp.scroll)
		OpenMailBodyText:SetWidth(hasBar and 276 or Pp.reading)
		OpenStationeryBackgroundLeft:SetWidth(Pp.left + (hasBar and 0 or Pp.noBar))
	end)
	place(OpenMailCancelButton, "BOTTOMRIGHT", o, "BOTTOMRIGHT", Lc.close[1], Lc.close[2])
	Tpl.CloseButton(OpenMailCloseButton, o)
	OpenMailCloseButton:SetFrameLevel(o:GetFrameLevel() + 22)
	hooksecurefunc("OpenMail_Update", C.AfterRead)
end

-- ------------------------------------------------------------ window

local function tabs(f)
	local S = ForeverUI.Social
	local O = N.tab
	C.tabs = {}
	for i, text in ipairs({ INBOX, SENDMAIL }) do
		local o = S.createTab(f, "ForeverUIMailTab" .. i, false)
		o:SetText(text)
		if i == 1 then
			o:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", C.tabs[i - 1], "TOPRIGHT", O.gap, 0)
		end
		-- Does what the client's tab does
		o:SetScript("OnClick", function()
			MailFrameTab_OnClick(_G["MailFrameTab" .. i], i)
		end)
		C.tabs[i] = o
		ForeverUI.Suppress(_G["MailFrameTab" .. i])
	end
end

function C.Skin()
	local f = MailFrame
	if not f or f.foreverSkin then return end
	-- 3.3.5 art: the unnamed icon and the four corner pieces
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			r:SetAlpha(0)
		end
	end
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	local skin = Tpl.PortraitWindow(f, {
		portrait = ART.icon, portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = INBOX,
	})
	f.foreverSkin = skin
	skin.inset = inset(f)
	-- Inbox and send frames fill the window (TOPLEFT / BOTTOMRIGHT)
	for _, c in ipairs({ InboxFrame, SendMailFrame }) do
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
		-- (the size follows the anchors; also set for code that reads it right away)
		c:SetWidth(N.window[1])
		c:SetHeight(N.window[2])
	end
	Tpl.CloseButton(InboxCloseButton, f)
	InboxCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	inbox()
	sending(f)
	reading()
	tabs(f)
	hooksecurefunc("MailFrameTab_OnClick", C.AfterTab)
	C.AfterTab()
end

C.Skin()
