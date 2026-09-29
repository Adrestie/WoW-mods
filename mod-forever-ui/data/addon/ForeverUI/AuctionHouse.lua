-- Auction house (AuctionFrame, load-on-demand Blizzard_AuctionUI) in the Camelot style
-- (blizzard_auctionhouseui). The WotLK structure stays: its three tabs, frames, logic and
-- positions; the camelot window sits on the visible rectangle of the 3.3.5 art, with insets
-- around the lists. Selection is read with GetSelectedAuctionItem. Not reskinned: the
-- dressing room (AuctionDressUpFrame), multi-sell bar (AuctionProgressFrame), StaticPopups.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local H = {}
ForeverUI.AuctionHouse = H

local SEP = string.char(92)

-- Numbers in AuctionFrame coordinates (its tab panels share them)
local N = {
	skin = { 12, -13, -2, 8 },
	portrait = { side = 48, x = 1, y = 1.5 },
	money = { inset = { 2, 27, 167, 3 }, edge = { 5, 6, 158, 19 }, purse = { 166, 8 } },
	tab = { x = 20, y = -28, gap = 3 },
	background = 3,
	-- Insets: top-left and bottom-right
	categories = { 20, -99, 182, -409 },
	results = { 182, -81, 804, -409 },
	bids = { 23, -51, 804, -411 },
	sell = { 15, -68, 214, -411 },
	auctions = { 215, -50, 804, -411 },
	-- Scroll bars (Tpl.BarAt: x, top, bottom from the scroll frame)
	bars = {
		BrowseFilterScrollFrame = { 5, 0, 7 },
		BrowseScrollFrame = { 12, -2, 9 },
		BidScrollFrame = { 11, -3, 5 },
		AuctionsScrollFrame = { 11, -4, 7 },
	},
	-- Rows: width with the bar, highlight width, last column and the inset holding them.
	-- noBar / columnNoBar: what rows and last column gain without a bar, so that their right
	-- margin in the inset (822) matches the left one.
	rows = {
		Browse = { count = 8, width = 600, glow = 562, column = "BrowseCurrentBidSort", columnWidth = 184,
			type = "list", scroll = "BrowseScrollFrame", striped = false, frameBox = "results",
			noBar = 14, columnNoBar = 18 },
		Bid = { count = 9, width = 769, glow = 735, column = "BidBidSort", columnWidth = 145,
			type = "bidder", scroll = "BidScrollFrame", striped = true, frameBox = "bids",
			noBar = 22, columnNoBar = 23 },
		Auctions = { count = 9, width = 576, glow = 543, column = "AuctionsBidSort", columnWidth = 193,
			type = "owner", scroll = "AuctionsScrollFrame", striped = true, frameBox = "auctions",
			noBar = 23, columnNoBar = 19 },
	},
	-- Without a bar the inset extends from 804 to 822: 8 from the window's right edge (830),
	-- like the categories 8 from its left edge
	noBar = 18,
	rowOffset = 2.5,
	icon = { side = 37 },
	-- Categories per level: background / choice / hover (atlas, w, h, point, x, y[, blend])
	category = {
		class = {
			background = { "auctionhouse-nav-button", 136, 32, "TOPLEFT", -2, 0 },
			choice = { "auctionhouse-nav-button-select", 132, 21, "LEFT", 0, 0 },
			hover = { "auctionhouse-nav-button-highlight", 132, 21, "LEFT", 0, 0, "BLEND" },
			text = 8,
		},
		subclass = {
			background = { "auctionhouse-nav-button-secondary", 133, 32, "TOPLEFT", 1, 0 },
			choice = { "auctionhouse-nav-button-secondary-select", 122, 21, "TOPLEFT", 10, 0 },
			hover = { "auctionhouse-nav-button-secondary-highlight", 122, 21, "TOPLEFT", 10, 0, "BLEND" },
			text = 18,
		},
		invtype = {
			choice = { "auctionhouse-ui-row-select", 116, 18, "TOPRIGHT", 0, -2 },
			hover = { "auctionhouse-ui-row-highlight", 116, 18, "TOPRIGHT", 0, -2, "ADD" },
			text = 26,
		},
		width = 132, line = { 18, 3 },
	},
	arrow = { side = 9, x = 3, y = 0 },
	-- Menus: single-line, as tall as the nearby fields (common-search-border: 20), compact
	-- (background clipped to its box, no overflowing shadow); WotLK positions; labels and
	-- check boxes at their 3.3.5 spacing
	menus = {
		height = 20, compact = true,
		-- Rarity 20 from the level fields, centered on their row, its label on the Level Range line;
		-- the two check boxes 19 apart (22 in 3.3.5), the pair centered on the menu
		browse = { width = 132, gap = 20, caption = { 3, 4 }, checkbox = { 10, 9.5 }, cellStep = 19 },
		price = { width = 97, right = { 201, -219 }, caption = { 25, -228 } },
		duration = { width = 97, right = { 201, -330 }, caption = { 25, -339 } },
	},
	-- Check boxes: camelot art at the size of the visible WotLK box (UI-CheckBox: 23 x 21 of 32,
	-- at 24: 17), centered
	checkboxSide = 17,
	sellTab = { x = 42, y = -3, text = 12 },
	object = { left = -8, top = 6, right = 174, down = -6, tip = 20 },
}

local ART = {
	marble = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	money = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	categories = "auctionhouse-background-categories",
	index = "auctionhouse-background-index",
	sell = "auctionhouse-background-sell-left",
	striped = { "auctionhouse-rowstripe-1", "auctionhouse-rowstripe-2" },
	choice = "auctionhouse-ui-row-select",
	hover = "auctionhouse-ui-row-highlight",
	iconBorder = "auctionhouse-itemicon-small-border",
	arrow = "auctionhouse-ui-sortarrow",
	line = "auctionhouse-nav-button-tertiary-filterline",
	emptySlot = "auctionhouse-itemicon-empty",
	header = "auctionhouse-itemheaderframe",
}

local SORT_BUTTONS = {
	"BrowseQualitySort", "BrowseLevelSort", "BrowseDurationSort", "BrowseHighBidderSort", "BrowseCurrentBidSort",
	"BidQualitySort", "BidLevelSort", "BidDurationSort", "BidBuyoutSort", "BidStatusSort", "BidBidSort",
	"AuctionsQualitySort", "AuctionsDurationSort", "AuctionsHighBidderSort", "AuctionsBidSort",
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- Atlas element at a given size; l, h: width and height (optional). The auction house
-- sheets are double density, so the atlas size is not camelot's.
local function atlas(t, name, l, h)
	ForeverUI.SetAtlas(t, name, true)
	if l then t:SetWidth(l) end
	if h then t:SetHeight(h) end
end

-- ------------------------------------------------------------ insets

-- InsetFrameTemplate and its background as regions of the tab panel (below its frames);
-- r = { x1, y1, x2, y2 } from the panel's TOPLEFT
local function frameBox(host, r, background)
	local rect = CreateFrame("Frame", nil, host)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", host, "TOPLEFT", r[1], r[2])
	rect:SetPoint("BOTTOMRIGHT", host, "TOPLEFT", r[3], r[4])
	local t = host:CreateTexture(nil, "BACKGROUND")
	atlas(t, background)
	t:SetPoint("TOPLEFT", rect, "TOPLEFT", N.background, -N.background)
	t:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", -N.background, N.background)
	return { rect = rect, background = t, edge = Tpl.NineSlice(host, "InsetFrameTemplate", rect) }
end

-- ThinGoldEdgeTemplate: Interface\Common\Moneyframe in three pieces
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

-- Money: InsetFrameTemplate (marble and trim), gold border, purse
local function money(skin)
	local A = N.money
	local rect = CreateFrame("Frame", nil, skin)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", skin, "BOTTOMLEFT", A.inset[1], A.inset[2])
	rect:SetPoint("BOTTOMRIGHT", skin, "BOTTOMLEFT", A.inset[3], A.inset[4])
	local marble = skin:CreateTexture(nil, "BACKGROUND")
	marble:SetTexture(ART.marble, true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(rect)
	local edge = CreateFrame("Frame", nil, skin)
	edge:EnableMouse(false)
	edge:SetWidth(A.edge[3])
	edge:SetHeight(A.edge[4])
	edge:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", A.edge[1], A.edge[2])
	place(AuctionFrameMoneyFrame, "BOTTOMRIGHT", skin, "BOTTOMLEFT", A.purse[1], A.purse[2])
	return { inset = rect, marble = marble, frameBox = Tpl.NineSlice(skin, "InsetFrameTemplate", rect),
		edge = edge, gilded = goldBorder(skin, edge) }
end

-- ------------------------------------------------------------ categories

-- After FilterButton_SetType: art for the category level; kind: class, subclass or invtype
function H.PaintCategory(b, kind)
	local c = b.foreverCategory
	local C = N.category[kind]
	if not c or not C then return end
	local plus = (b:GetWidth() or C.width) - N.category.width
	local background = b:GetNormalTexture()
	if background then
		background:ClearAllPoints()
		if C.background then
			atlas(background, C.background[1], C.background[2] + plus, C.background[3])
			background:SetPoint(C.background[4], b, C.background[4], C.background[5], C.background[6])
			background:SetAlpha(1)
		else
			background:SetPoint("TOPLEFT", b, "TOPLEFT", 10, 0)
			background:SetAlpha(0)
		end
	end
	for _, key in ipairs({ "choice", "hover" }) do
		local e, t = C[key], c[key]
		atlas(t, e[1], e[2] + plus, e[3])
		place(t, e[4], b, e[4], e[5], e[6])
		if e[7] then t:SetBlendMode(e[7]) end
	end
	local text = _G[b:GetName() .. "NormalText"]
	if text then place(text, "LEFT", b, "LEFT", C.text, 0) end
	local line = _G[b:GetName() .. "Lines"]
	if line then
		atlas(line, ART.line, 5, 11)
		place(line, "LEFT", b, "LEFT", N.category.line[1], N.category.line[2])
	end
end

local function skinCategory(b)
	local c = {}
	c.hover = b:CreateTexture(nil, "BORDER")
	c.hover:Hide()
	c.choice = b:CreateTexture(nil, "ARTWORK")
	c.choice:SetBlendMode("ADD")
	c.choice:Hide()
	b.foreverCategory = c
	-- The client's highlight, locked on selection, is hidden; camelot's choice and hover
	-- textures replace it
	local h = b:GetHighlightTexture()
	if h then h:SetAlpha(0) end
	hooksecurefunc(b, "LockHighlight", function() c.choice:Show() end)
	hooksecurefunc(b, "UnlockHighlight", function() c.choice:Hide() end)
	b:HookScript("OnEnter", function() c.hover:Show() end)
	b:HookScript("OnLeave", function() c.hover:Hide() end)
	H.PaintCategory(b, b.type or "class")
end

-- ------------------------------------------------------------ rows

local function skinRow(b)
	local name = b:GetName()
	for _, s in ipairs({ "Left", "Right", "Highlight" }) do
		local t = _G[name .. s]
		if t then t:SetAlpha(0) end
	end
	-- Unnamed middle piece of the name frame
	for _, r in ipairs({ b:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then
			local f = r:GetTexture()
			if type(f) == "string" and string.find(string.lower(f), "auctionitemnameframe", 1, true) then
				r:SetAlpha(0)
			end
		end
	end
	local l = {}
	local d = N.rowOffset
	local function fitRow(t)
		t:SetPoint("TOPLEFT", b, "TOPLEFT", 0, d)
		t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, d)
		return t
	end
	l.stripe = fitRow(b:CreateTexture(nil, "BACKGROUND"))
	atlas(l.stripe, ART.striped[1])
	l.stripe:Hide()
	l.choice = fitRow(b:CreateTexture(nil, "OVERLAY"))
	atlas(l.choice, ART.choice)
	l.choice:SetBlendMode("ADD")
	l.choice:Hide()
	l.hover = fitRow(b:CreateTexture(nil, "OVERLAY"))
	atlas(l.hover, ART.hover)
	l.hover:SetBlendMode("ADD")
	l.hover:Hide()
	-- Icon: without the WotLK slot, ringed as in camelot
	local object = _G[name .. "Item"]
	if object then
		for _, read in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
			local t = object[read](object)
			if t then t:SetAlpha(0) end
		end
		l.edge = object:CreateTexture(nil, "OVERLAY")
		atlas(l.edge, ART.iconBorder, N.icon.side, N.icon.side)
		l.edge:SetPoint("CENTER", object, "CENTER", 0, 0)
		object:HookScript("OnEnter", function() l.hover:Show() end)
		object:HookScript("OnLeave", function() l.hover:Hide() end)
	end
	b:HookScript("OnEnter", function() l.hover:Show() end)
	b:HookScript("OnLeave", function() l.hover:Hide() end)
	b.foreverRow = l
end

-- After AuctionFrameBrowse_Update / Bid / Auctions (the client has already shown or hidden
-- the bar): widths by bar, inset, selection, stripes. key: Browse, Bid or Auctions
function H.UpdateRows(key)
	local L = N.rows[key]
	local fx = _G[L.scroll]
	local offset = FauxScrollFrame_GetOffset(fx) or 0
	local selected = GetSelectedAuctionItem(L.type)
	local hasBar = fx:IsShown()
	local skin = AuctionFrame.foreverSkin
	local e, r = skin and skin[L.frameBox], N[L.frameBox]
	if e then
		e.rect:SetPoint("BOTTOMRIGHT", e.rect:GetParent(), "TOPLEFT", r[3] + (hasBar and 0 or N.noBar), r[4])
	end
	local plus = hasBar and 0 or L.noBar
	for i = 1, L.count do
		local b = _G[key .. "Button" .. i]
		local l = b and b.foreverRow
		if l then
			b:SetWidth(L.width + plus)
			local glow = _G[key .. "Button" .. i .. "Highlight"]
			if glow then glow:SetWidth(L.glow + plus) end
			Tpl.SetShown(l.choice, selected ~= nil and selected == offset + i)
			if L.striped then
				atlas(l.stripe, ART.striped[(offset + i) % 2 == 1 and 1 or 2])
				l.stripe:Show()
			end
		end
	end
	local column = _G[L.column]
	if column then column:SetWidth(L.columnWidth + (hasBar and 0 or L.columnNoBar)) end
end

-- ------------------------------------------------------------ headers

local function skinSortButton(name)
	local arrow = _G[name .. "Arrow"]
	if not arrow then return end
	local F = N.arrow
	atlas(arrow, ART.arrow, F.side, F.side)
	local text = _G[name .. "Text"]
	if text then place(arrow, "LEFT", text, "RIGHT", F.x, F.y) end
end

-- After SortButton_UpdateArrow: camelot's arrow, flipped
function H.PaintArrow(button, kind)
	local arrow = button and _G[button:GetName() .. "Arrow"]
	if not arrow then return end
	local e = ForeverUI.AtlasEntry(ART.arrow)
	if not e then return end
	local _, inverse = GetAuctionSort(kind, 1)
	arrow:SetTexture(e[1])
	if inverse then
		arrow:SetTexCoord(e[2], e[3], e[5], e[4])
	else
		arrow:SetTexCoord(e[2], e[3], e[4], e[5])
	end
end

-- ------------------------------------------------------------ menus

-- Unnamed label of a dropdown, found by its text
local function captionOf(dd, text)
	for _, r in ipairs({ dd:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == text then
			return r
		end
	end
end

local function menus()
	local M = N.menus
	-- Browse: menu right of the level fields, its label above, the check boxes
	local P = M.browse
	Tpl.MenuStyle1(BrowseDropDown, P.width, M.height, M.compact)
	place(BrowseDropDown, "LEFT", BrowseMaxLevel, "RIGHT", P.gap, 0)
	place(BrowseDropDownName, "BOTTOMLEFT", BrowseDropDown, "TOPLEFT", P.caption[1], P.caption[2])
	place(IsUsableCheckButton, "LEFT", BrowseDropDown, "RIGHT", P.checkbox[1], P.checkbox[2])
	place(ShowOnPlayerCheckButton, "TOPLEFT", IsUsableCheckButton, "TOPLEFT", 0, -P.cellStep)
	-- Auctions: price and duration, label on the left, menu on the right
	for _, v in ipairs({ { PriceDropDown, AUCTION_PRICE, M.price }, { DurationDropDown, AUCTION_DURATION, M.duration } }) do
		local dd, text, R = v[1], v[2], v[3]
		local caption = captionOf(dd, text)
		Tpl.MenuStyle1(dd, R.width, M.height, M.compact)
		place(dd, "TOPRIGHT", AuctionFrameAuctions, "TOPLEFT", R.right[1], R.right[2])
		if caption then place(caption, "LEFT", AuctionFrameAuctions, "TOPLEFT", R.caption[1], R.caption[2]) end
	end
end

-- ------------------------------------------------------------ selling

-- auctionhouse-itemheaderframe in three pieces: the rounded ends keep their ratio, the
-- middle stretches
local function itemHeader(host, rect)
	local e = ForeverUI.AtlasEntry(ART.header)
	if not e then return end
	local O = N.object
	local height = O.top - O.down + N.icon.side
	local tip = O.tip * height / 72
	local du = (e[3] - e[2]) * O.tip / 342
	local function piece(u1, u2)
		local t = host:CreateTexture(nil, "ARTWORK")
		t:SetTexture(e[1])
		t:SetTexCoord(u1, u2, e[4], e[5])
		return t
	end
	local g = piece(e[2], e[2] + du)
	g:SetWidth(tip)
	g:SetPoint("TOPLEFT", rect, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", rect, "BOTTOMLEFT")
	local d = piece(e[3] - du, e[3])
	d:SetWidth(tip)
	d:SetPoint("TOPRIGHT", rect, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT")
	local m = piece(e[2] + du, e[3] - du)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	return { g, m, d }
end

local function skinSellTab(f)
	local skin = AuctionFrame.foreverSkin
	-- "Create Auction" tab above the panel
	local V = N.sellTab
	local frame = skin.sell.rect
	local g = f:CreateTexture(nil, "ARTWORK")
	atlas(g, "auctionhouse-selltab-left", 9, 23)
	g:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", V.x, V.y)
	AuctionsTabText:SetFontObject(GameFontNormalSmall)
	place(AuctionsTabText, "LEFT", g, "RIGHT", V.text, 0)
	local m = f:CreateTexture(nil, "BORDER")
	atlas(m, "auctionhouse-selltab-middle", nil, 23)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("RIGHT", AuctionsTabText, "RIGHT", V.text, 0)
	local d = f:CreateTexture(nil, "BORDER")
	atlas(d, "auctionhouse-selltab-right", 9, 23)
	d:SetPoint("TOPLEFT", m, "TOPRIGHT", 0, 0)
	skin.sellTab = { g, m, d }
	-- Item: without the WotLK slot, on camelot's item frame
	local b = AuctionsItemButton
	for _, r in ipairs({ b:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local file = r:GetTexture()
			if type(file) == "string" and string.find(string.lower(file), "itemslot", 1, true) then
				r:SetAlpha(0)
			end
		end
	end
	local O = N.object
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", b, "TOPLEFT", O.left, O.top)
	rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", O.right, O.down)
	skin.object = { rect = rect, header = itemHeader(f, rect) }
	local empty = b:CreateTexture(nil, "BACKGROUND")
	atlas(empty, ART.emptySlot)
	empty:SetAllPoints(b)
	skin.object.empty = empty
end

-- ------------------------------------------------------------ tabs

-- Mirrors the client's selected tab on our tabs and the title
function H.UpdateTabs()
	local S = ForeverUI.Social
	for i, o in ipairs(H.tabs or {}) do
		S.selectTab(o, AuctionFrame.selectedTab == i, true)
		o:SetWidth(S.tabWidth(o))
	end
	-- Title: that of the shown client tab
	local skin = AuctionFrame.foreverSkin
	if skin then
		for _, v in ipairs({ { AuctionFrameBrowse, BrowseTitle }, { AuctionFrameBid, BidTitle },
			{ AuctionFrameAuctions, AuctionsTitle } }) do
			if v[1]:IsShown() then skin.title:SetText(v[2]:GetText() or "") end
		end
	end
end

local function tabs(skin)
	local S, O = ForeverUI.Social, N.tab
	H.tabs = {}
	for i, text in ipairs({ BROWSE, BIDS, AUCTIONS }) do
		local o = S.createTab(skin, "ForeverUIAuctionTab" .. i, false)
		o:SetText(text)
		if i == 1 then
			o:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", H.tabs[i - 1], "TOPRIGHT", O.gap, 0)
		end
		o:SetScript("OnClick", function()
			AuctionFrameTab_OnClick(_G["AuctionFrameTab" .. i])
		end)
		H.tabs[i] = o
		ForeverUI.Suppress(_G["AuctionFrameTab" .. i])
	end
end

-- ------------------------------------------------------------ window

function H.Skin()
	local f = AuctionFrame
	if not f or f.foreverSkin then return end

	-- 3.3.5 art and tab titles (the title bar shows the title)
	for _, r in ipairs({ AuctionPortraitTexture, AuctionFrameTopLeft, AuctionFrameTop, AuctionFrameTopRight,
		AuctionFrameBotLeft, AuctionFrameBot, AuctionFrameBotRight, BrowseTitle, BidTitle, AuctionsTitle }) do
		r:SetAlpha(0)
	end

	-- camelot window on the visible rectangle of the 3.3.5 art
	local Sk = N.skin
	local frame = CreateFrame("Frame", nil, f)
	frame:SetFrameLevel(f:GetFrameLevel())
	frame:EnableMouse(false)
	frame:SetPoint("TOPLEFT", f, "TOPLEFT", Sk[1], Sk[2])
	frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", Sk[3], Sk[4])
	local skin = Tpl.PortraitWindow(frame, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = BrowseTitle:GetText(),
	})
	skin.frame = frame
	f.foreverSkin = skin
	f:HookScript("OnShow", function() SetPortraitTexture(skin.portrait, "npc") end)
	Tpl.CloseButton(AuctionFrameCloseButton, frame)
	AuctionFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	skin.money = money(frame)

	-- Insets, as regions of each tab panel
	skin.categories = frameBox(AuctionFrameBrowse, N.categories, ART.categories)
	skin.results = frameBox(AuctionFrameBrowse, N.results, ART.index)
	skin.bids = frameBox(AuctionFrameBid, N.bids, ART.index)
	skin.sell = frameBox(AuctionFrameAuctions, N.sell, ART.sell)
	skin.auctions = frameBox(AuctionFrameAuctions, N.auctions, ART.index)

	-- Scroll bars: the client's, at camelot's place and with its art
	for name, B in pairs(N.bars) do
		local fx = _G[name]
		for _, r in ipairs({ fx:GetRegions() }) do
			if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
		end
		Tpl.BarAt(_G[name .. "ScrollBar"], fx, B[1], B[2], B[3])
	end

	-- Categories, rows, headers.
	-- Each category sits one level above the previous one: its art's shadow (11 below the
	-- button) falls on the next, and two frames on the same level draw in an order that
	-- changes when the list is rebuilt.
	local level = AuctionFilterButton1:GetFrameLevel()
	for i = 1, NUM_FILTERS_TO_DISPLAY do
		local b = _G["AuctionFilterButton" .. i]
		b:SetFrameLevel(level + i - 1)
		skinCategory(b)
	end
	hooksecurefunc("FilterButton_SetType", H.PaintCategory)
	for key, L in pairs(N.rows) do
		for i = 1, L.count do
			skinRow(_G[key .. "Button" .. i])
		end
	end
	hooksecurefunc("AuctionFrameBrowse_Update", function() H.UpdateRows("Browse") end)
	hooksecurefunc("AuctionFrameBid_Update", function() H.UpdateRows("Bid") end)
	hooksecurefunc("AuctionFrameAuctions_Update", function() H.UpdateRows("Auctions") end)
	for key in pairs(N.rows) do H.UpdateRows(key) end
	for _, name in ipairs(SORT_BUTTONS) do skinSortButton(name) end
	hooksecurefunc("SortButton_UpdateArrow", H.PaintArrow)

	-- Fields, check boxes, menus
	local S = ForeverUI.Social
	for _, field in ipairs({ BrowseName, BrowseMinLevel, BrowseMaxLevel, AuctionsStackSizeEntry, AuctionsNumStacksEntry }) do
		S.skinInput(field)
	end
	for _, c in ipairs({ IsUsableCheckButton, ShowOnPlayerCheckButton }) do
		S.skinCell(c)
		for _, read in ipairs({ "GetNormalTexture", "GetCheckedTexture", "GetDisabledCheckedTexture", "GetPushedTexture" }) do
			local t = c[read] and c[read](c)
			if t then
				t:ClearAllPoints()
				t:SetWidth(N.checkboxSide)
				t:SetHeight(N.checkboxSide)
				t:SetPoint("CENTER", c, "CENTER", 0, 0)
			end
		end
	end
	menus()
	skinSellTab(AuctionFrameAuctions)

	-- Bottom tabs, and the title that follows the tab
	tabs(frame)
	hooksecurefunc("AuctionFrameTab_OnClick", H.UpdateTabs)
	H.UpdateTabs()
end

H.Skin()

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_AuctionUI" then
		H.Skin()
	end
end)
