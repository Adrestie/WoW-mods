-- Merchant window (MerchantFrame) in camelot style.
-- The client's frames and logic stay, placed and dressed as in camelot's merchantframe.xml /
-- .lua (ButtonFrameTemplate 336 x 444); N holds its offsets. What the client re-places on
-- every update (repair buttons, portrait, title, buyback background) is redone after it.
-- Item names take their quality color and icons a quality outline
-- (MerchantFrameItem_UpdateQuality).
-- Tabs are the Social window's (PanelTabButtonTemplate); they drive the client's tabs, which
-- are hidden. Portrait: the character sheet's, 48 wide, centered in the ring hole (a 60
-- unit portrait overflows the circle).
-- Missing in 3.3.5, so absent: filter by specialization (SetMerchantFilter) and sell all
-- junk (C_MerchantFrame.SellAllJunkItems).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local M = {}
ForeverUI.Merchant = M

local SEP = string.char(92)

local N = {
	window = { 336, 444 },
	portrait = { side = 48, x = 1, y = 1.5 },
	inset = { 4, -60, -6, 26 },
	buybackBackground = { 7, -60, -7, 26, a = 0.2 },
	bottomFrame = { l = 334, h = 61, x = 1, y = 26 },
	first = { 11, -69 },
	page = { x = 0, y = 86, l = 104 },
	previous = { 25, 96 }, following = { 310, 96 },
	repair = { side = 36, background = { 64, -13, 14 }, single = { x = 118, y = 33, gap = -8 },
		guild = { x = 96, y = 33, gap = -9, right = 8 } },
	buyback = { l = 115, h = 37, x = 30, y = -53, nameFrame = { 90, 64 }, name = { 70, 35, -5, 2 },
		arrow = { side = 20, x = 0, y = -1 }, count = 0.65 },
	money = { inset = { -171, 27, -5, 4 }, edge = { -166, 6, -7, 25 }, purse = { -4, 8 } },
	tab = { x = 50, y = -15, gap = 3 },
}

local ART = {
	backgroundBottom = "ui-merchant-botframe",
	repairAll = "spellicon-256x256-repairall",
	repair = "spellicon-256x256-repair",
	guild = "spellicon-256x256-repairallguild",
	cancel = "common-icon-undo",
	cell = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-EmptySlot",
	money = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	marble = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	buyback = "Interface" .. SEP .. "MerchantFrame" .. SEP .. "UI-BuyBack-Icon",
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- InsetFrameTemplate: marble and trim as regions of the window, fitted to a helper frame
-- (camelot's insets are at the window's level). x1, y1: top left offset from f's point p1;
-- x2, y2: bottom right offset from p2. Returns the helper frame, marble and trim.
local function inset(f, x1, y1, p1, x2, y2, p2)
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, p1, x1, y1)
	rect:SetPoint("BOTTOMRIGHT", f, p2, x2, y2)
	local marble = f:CreateTexture(nil, "BACKGROUND")
	marble:SetTexture(ART.marble, true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(rect)
	return rect, marble, Tpl.NineSlice(f, "InsetFrameTemplate", rect)
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

-- Quality color on the name and outline on the icon (Tpl.Quality)
local function quality(name, button, link)
	Tpl.Quality(name, button, link)
end

local outline = Tpl.Outline

-- Repair buttons, re-placed after MerchantFrame_UpdateRepairButtons (which puts them at
-- their 3.3.5 places and shrinks them to 32 when the guild button shows).
function M.PlaceRepair()
	local R = N.repair
	local f = MerchantFrame
	for _, b in ipairs({ MerchantRepairAllButton, MerchantRepairItemButton, MerchantGuildBankRepairButton }) do
		b:SetWidth(R.side)
		b:SetHeight(R.side)
	end
	local guild = MerchantGuildBankRepairButton:IsShown()
	local P = guild and R.guild or R.single
	place(MerchantRepairAllButton, "BOTTOMRIGHT", f, "BOTTOMLEFT", P.x, P.y)
	place(MerchantRepairItemButton, "RIGHT", MerchantRepairAllButton, "LEFT", P.gap, 0)
	place(MerchantGuildBankRepairButton, "LEFT", MerchantRepairAllButton, "RIGHT", R.guild.right, 0)
end

-- Buyback arrow: greyed out when there is nothing to buy back
local function updateArrow()
	local t = M.arrow
	if t then t:SetDesaturated(GetNumBuybackItems() == 0) end
end

-- After the client: merchant tab
function M.AfterMerchant()
	local h = MerchantFrame.foreverSkin
	if not h then return end
	SetPortraitTexture(h.portrait, "npc")
	M.buybackBackground:Hide()
	local number = MerchantFrame.page or 1
	for i = 1, MERCHANT_ITEMS_PER_PAGE do
		local index = (number - 1) * MERCHANT_ITEMS_PER_PAGE + i
		local b = _G["MerchantItem" .. i .. "ItemButton"]
		if index <= GetMerchantNumItems() then
			quality(_G["MerchantItem" .. i .. "Name"], b, GetMerchantItemLink(index))
		else
			outline(b):Hide()
		end
	end
	local n = GetNumBuybackItems()
	quality(MerchantBuyBackItemName, MerchantBuyBackItemItemButton, n > 0 and GetBuybackItemLink(n) or nil)
	updateArrow()
end

-- After the client: buyback tab
function M.AfterBuyback()
	local h = MerchantFrame.foreverSkin
	if not h then return end
	h.portrait:SetTexture(ART.buyback)
	M.buybackBackground:Show()
	local n = GetNumBuybackItems()
	for i = 1, BUYBACK_ITEMS_PER_PAGE do
		local b = _G["MerchantItem" .. i .. "ItemButton"]
		if i <= n then
			quality(_G["MerchantItem" .. i .. "Name"], b, GetBuybackItemLink(i))
		else
			outline(b):Hide()
		end
	end
end

-- Bottom tabs follow the client's selected tab
function M.UpdateTabs()
	local S = ForeverUI.Social
	for i, o in ipairs(M.tabs or {}) do
		S.selectTab(o, MerchantFrame.selectedTab == i, true)
		o:SetWidth(S.tabWidth(o))
	end
end

local function tabs(f)
	local S = ForeverUI.Social
	local O = N.tab
	M.tabs = {}
	for i, text in ipairs({ MERCHANT, BUYBACK }) do
		local o = S.createTab(f, "ForeverUIMerchantTab" .. i, false)
		o:SetText(text)
		if i == 1 then
			o:SetPoint("CENTER", f, "BOTTOMLEFT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", M.tabs[i - 1], "TOPRIGHT", O.gap, 0)
		end
		-- what the client's tab does (MerchantFrameTab<i>, OnClick)
		o:SetScript("OnClick", function()
			PlaySound("igCharacterInfoTab")
			PanelTemplates_SetTab(MerchantFrame, i)
			MerchantFrame_Update()
		end)
		M.tabs[i] = o
		ForeverUI.Suppress(_G["MerchantFrameTab" .. i])
	end
	M.UpdateTabs()
end

-- A camelot repair icon on its slot background. icon: the button's icon texture
local function repair(b, icon, atlas)
	local F = N.repair.background
	local background = b:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(ART.cell)
	background:SetWidth(F[1])
	background:SetHeight(F[1])
	background:SetPoint("TOPLEFT", b, "TOPLEFT", F[2], F[3])
	ForeverUI.SetAtlas(icon, atlas)
	icon:ClearAllPoints()
	icon:SetAllPoints(b)
	b.foreverBackground = background
end

-- MerchantRepairItemButton's icon has no name: find it among the button's BORDER regions
local function unnamedIcon(b)
	for _, r in ipairs({ b:GetRegions() }) do
		if r:GetObjectType() == "Texture" and r ~= b:GetNormalTexture() and r ~= b:GetPushedTexture()
			and r ~= b:GetHighlightTexture() and r:GetDrawLayer() == "BORDER" then
			return r
		end
	end
end

local function buyback()
	local R = N.buyback
	local it = MerchantBuyBackItem
	it:SetWidth(R.l)
	it:SetHeight(R.h)
	place(it, "TOPLEFT", MerchantItem10, "BOTTOMLEFT", R.x, R.y)
	MerchantBuyBackItemNameFrame:SetWidth(R.nameFrame[1])
	MerchantBuyBackItemNameFrame:SetHeight(R.nameFrame[2])
	MerchantBuyBackItemNameFrame:Hide()
	MerchantBuyBackItemName:SetWidth(R.name[1])
	MerchantBuyBackItemName:SetHeight(R.name[2])
	place(MerchantBuyBackItemName, "LEFT", MerchantBuyBackItemSlotTexture, "RIGHT", R.name[3], R.name[4])
	-- SetItemButtonScale(0.65) on the count only: 3.3.5 cannot scale a text, so its font size
	-- is scaled instead
	local count = MerchantBuyBackItemItemButtonCount
	local path, size, flags = count:GetFont()
	if path and size then count:SetFont(path, size * R.count, flags) end
	-- arrow, above the icon
	local veil = CreateFrame("Frame", nil, MerchantBuyBackItemItemButton)
	veil:SetAllPoints(MerchantBuyBackItemItemButton)
	veil:EnableMouse(false)
	local t = veil:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(t, ART.cancel)
	t:SetWidth(R.arrow.side)
	t:SetHeight(R.arrow.side)
	t:SetPoint("CENTER", veil, "CENTER", R.arrow.x, R.arrow.y)
	M.arrow = t
	MerchantBuyBackItemItemButton:HookScript("OnShow", updateArrow)
end

function M.Skin()
	local f = MerchantFrame
	if not f or f.foreverSkin then return end

	-- 3.3.5 art: the four unnamed pieces, portrait, name, repair text, buyback background,
	-- bottom right border
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then
			r:SetAlpha(0)
		end
	end
	for _, r in ipairs({ MerchantFramePortrait, MerchantNameText, MerchantRepairText, BuybackFrameTopLeft,
		BuybackFrameTopRight, BuybackFrameBotLeft, BuybackFrameBotRight, MerchantFrameBottomRightBorder }) do
		r:SetAlpha(0)
	end
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	f:SetHitRectInsets(0, 0, 0, 0)

	-- ButtonFrameTemplate: stone, streaks, metal, portrait, title
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = MerchantNameText:GetText(),
	})
	f.foreverSkin = skin
	hooksecurefunc(MerchantNameText, "SetText", function(_, text)
		skin.title:SetText(text or "")
	end)
	-- inset, then the buyback background (white at 0.2) over it
	local E = N.inset
	skin.inset, skin.marble, skin.frameBox = inset(f, E[1], E[2], "TOPLEFT", E[3], E[4], "BOTTOMRIGHT")
	local RF = N.buybackBackground
	local background = f:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(1, 1, 1, RF.a)
	background:SetPoint("TOPLEFT", f, "TOPLEFT", RF[1], RF[2])
	background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", RF[3], RF[4])
	background:Hide()
	M.buybackBackground = background
	-- bottom background: the client's own texture, which the client shows and hides
	local B = N.bottomFrame
	local down = MerchantFrameBottomLeftBorder
	ForeverUI.SetAtlas(down, ART.backgroundBottom)
	down:SetWidth(B.l)
	down:SetHeight(B.h)
	place(down, "BOTTOMLEFT", f, "BOTTOMLEFT", B.x, B.y)
	-- money: its inset, gold edge and purse
	local A = N.money
	skin.moneyInset = inset(f, A.inset[1], A.inset[2], "BOTTOMRIGHT", A.inset[3], A.inset[4], "BOTTOMRIGHT")
	local edge = CreateFrame("Frame", nil, f)
	edge:EnableMouse(false)
	edge:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", A.edge[1], A.edge[2])
	edge:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", A.edge[3], A.edge[4])
	skin.moneyBorder = edge
	skin.goldBorder = goldBorder(f, edge)
	place(MerchantMoneyFrame, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A.purse[1], A.purse[2])
	-- close button, above the metal
	Tpl.CloseButton(MerchantFrameCloseButton, f)
	MerchantFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)

	-- items and pages
	place(MerchantItem1, "TOPLEFT", f, "TOPLEFT", N.first[1], N.first[2])
	MerchantPageText:SetWidth(N.page.l)
	place(MerchantPageText, "BOTTOM", f, "BOTTOM", N.page.x, N.page.y)
	place(MerchantPrevPageButton, "CENTER", f, "BOTTOMLEFT", N.previous[1], N.previous[2])
	place(MerchantNextPageButton, "CENTER", f, "BOTTOMLEFT", N.following[1], N.following[2])

	-- repair buttons
	repair(MerchantRepairAllButton, MerchantRepairAllIcon, ART.repairAll)
	repair(MerchantRepairItemButton, unnamedIcon(MerchantRepairItemButton), ART.repair)
	repair(MerchantGuildBankRepairButton, MerchantGuildBankRepairButtonIcon, ART.guild)
	hooksecurefunc("MerchantFrame_UpdateRepairButtons", M.PlaceRepair)
	M.PlaceRepair()

	buyback()
	tabs(f)
	hooksecurefunc("MerchantFrame_UpdateMerchantInfo", M.AfterMerchant)
	hooksecurefunc("MerchantFrame_UpdateBuybackInfo", M.AfterBuyback)
	hooksecurefunc("MerchantFrame_Update", M.UpdateTabs)
end

M.Skin()
