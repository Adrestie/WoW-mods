-- ForeverUI: bank window (BankFrame) in the camelot style (bankframe.xml, bankframetemplates.xml).
-- The bank and its bags share one 8-column grid, 88 cells per page. The 28 client cells stay;
-- bag cells are ContainerFrameItemButtonTemplate buttons (client clicks, tooltips, stack split).
-- Search and sort follow the bags (Bags.lua, ForeverUI.BagSort). 3.3.5 has no warband bank.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates
local L = ForeverUI.L

local B = { page = 1, carriers = {} }
ForeverUI.Bank = B

local SEP = string.char(92)

local N = {
	width = 480, baseHeight = 460, rowLine = 47, baseRows = 6,
	columns = 8, first = { 47, -63 }, gapX = 13, gapY = 10, cell = 37, perPage = 88,
	background = { 0, -20, 0, 30 },
	shadows = { topLeft = { 2, -22 }, bottomLeft = { 2, 2 }, topRight = { -3, -22 }, bottomRight = { -3, 2 }, thickness = 17,
		slices = { side = { 0.015625, 0.28125 }, down = { 0.015625, 0.28125 }, top = { 0.3125, 0.578125 } } },
	tab = { x = 3, y = -60, gap = -2, side = 55, icon = 50, iconX = -3, crop = 0.03125 },
	search = { -56, -33, 110, 20 }, sort = { 8, -1, 28, 26 },
	money = { box = { -3, 3, 180, 25 }, edge = { 178, 19 } },
	bags = { text = { 43, 80 }, first = { 20, 5 }, step = 50, scale = 0.75 },
	cost = { 101, 45, 8, 0 }, purchase = { 8, 4, 124, 21 },
	rule = { scale = 0.48, y = 220 },
	portrait = { side = 48, x = 1, y = 1.5 },
}

local ART = {
	background = "bank-frame-background",
	emptySlot = "bank-frame-item-slotframe", fullCell = "bank-frame-bag-slotframe",
	cellBackground = "bags-item-bankslot64",
	bagBackground = "bank-frame-bag-slot-bg", lock = "bankslot-icon-lock",
	rule = "bank-divider",
	money = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	tab = "common-sidetab", tabActive = "common-sidetab-selected", tabHover = "common-sidetab-hover",
	pages = {
		"Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP .. "Inv_SideTab_Bank_c60",
		"Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP .. "Achievement_GuildPerk_MobileBanking",
		"Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP .. "Trade_Archaeology_ChestOfTinyGlassAnimals",
		"Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP .. "Ability_Racial_PackHobgoblin",
	},
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- Bank containers: the bank itself, then its seven bags.
local function bankBags()
	local bags = { BANK_CONTAINER }
	for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
		bags[#bags + 1] = bag
	end
	return bags
end

-- ------------------------------------------------------------ Cell

-- CamelotBankItemButtonTemplate: background bags-item-bankslot64, frame at the button size,
-- 3.3.5 art removed.
local function skinCell(b)
	if b.foreverCell then return end
	local background = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, ART.cellBackground)
	background:SetAllPoints(b)
	local e = ForeverUI.AtlasEntry(ART.emptySlot)
	b:SetNormalTexture(e[1])
	local frame = b:GetNormalTexture()
	frame:ClearAllPoints()
	frame:SetAllPoints(b)
	b.foreverCell = { background = background, frame = frame }
end

-- CamelotBankPanelItemButtonMixin:Refresh: full or empty frame
local function setCellFrame(b, full)
	local c = b.foreverCell and b:GetNormalTexture()
	if c then ForeverUI.SetAtlas(c, full and ART.fullCell or ART.emptySlot) end
end

-- Cell i of a bank bag: a ContainerFrameItemButtonTemplate in the bag carrier (the carrier ID
-- is the bag, read by the client scripts).
local function bagCellOf(bag, i)
	local p = B.carriers[bag]
	if not p then
		p = CreateFrame("Frame", "ForeverUIBankBag" .. bag, BankFrame)
		p:SetID(bag)
		p:SetAllPoints(BankFrame)
		p.cells = {}
		B.carriers[bag] = p
	end
	local b = p.cells[i]
	if not b then
		b = CreateFrame("Button", "ForeverUIBankBag" .. bag .. "Item" .. i, p, "ContainerFrameItemButtonTemplate")
		b:SetID(i)
		skinCell(b)
		p.cells[i] = b
	end
	return b
end

local function cellOf(bag, i)
	if bag == BANK_CONTAINER then
		return _G["BankFrameItem" .. i]
	end
	return bagCellOf(bag, i)
end

-- Bag cell: icon, count, lock, quality, cooldown
local function updateCell(b, bag, i)
	local texture, count, lock, quality = GetContainerItemInfo(bag, i)
	SetItemButtonTexture(b, texture)
	SetItemButtonCount(b, count)
	SetItemButtonDesaturated(b, lock, 0.5, 0.5, 0.5)
	b.hasItem = texture and 1 or nil
	Tpl.QualityOutline(b, texture and quality or nil)
	setCellFrame(b, texture ~= nil)
	if ContainerFrame_UpdateCooldown then ContainerFrame_UpdateCooldown(bag, b) end
	B.mark(b, GetContainerItemLink(bag, i))
end

-- Bag search rule (Bags.lua): name, type or subtype contains the text, case-insensitive; the
-- name comes from the link when the item is not in the client cache.
local function linkMatches(link, text)
	if text == "" then return true end
	if not link then return false end
	local name, _, _, _, _, type_, subType = GetItemInfo(link)
	name = name or string.match(link, "%[(.+)%]")
	text = string.lower(text)
	for _, c in ipairs({ name, type_, subType }) do
		if c and string.find(string.lower(c), text, 1, true) then return true end
	end
	return false
end

-- Black veil at 80 % over cells that do not match.
function B.mark(b, link)
	local veil = b.foreverVeil
	if not veil then
		veil = b:CreateTexture(nil, "OVERLAY")
		veil:SetTexture(0, 0, 0, 0.8)
		veil:SetAllPoints(b)
		veil:Hide()
		b.foreverVeil = veil
	end
	local text = B.field and B.field:GetText() or ""
	Tpl.SetShown(veil, text ~= "" and link ~= nil and not linkMatches(link, text))
end

-- ------------------------------------------------------------ Grid

-- All cells in grid order: the bank, then its bags
local function allCells()
	local cells = {}
	for _, bag in ipairs(bankBags()) do
		local n = (bag == BANK_CONTAINER) and NUM_BANKGENERIC_SLOTS or (GetContainerNumSlots(bag) or 0)
		for i = 1, n do
			cells[#cells + 1] = { bag = bag, i = i }
		end
	end
	return cells
end

-- camelot GenerateItemSlotsForSelectedTab: page, window height (460, plus 47 per row beyond
-- six) and cell positions.
function B.Layout()
	local f = BankFrame
	if not f or not f.foreverSkin then return end
	local cells = allCells()
	local pages = math.max(1, math.ceil(#cells / N.perPage))
	B.pages = pages
	if B.page > pages then B.page = pages end
	if B.page < 1 then B.page = 1 end
	local start = (B.page - 1) * N.perPage
	local displayedCount = math.min(N.perPage, #cells - start)
	local ranks = math.ceil(displayedCount / N.columns)
	f:SetHeight(N.baseHeight + math.max(0, ranks - N.baseRows) * N.rowLine)
	-- Hide everything, then lay out the page
	for i = 1, NUM_BANKGENERIC_SLOTS do _G["BankFrameItem" .. i]:Hide() end
	for _, p in pairs(B.carriers) do
		for _, b in pairs(p.cells) do b:Hide() end
	end
	local stepX, stepY = N.cell + N.gapX, N.cell + N.gapY
	for k = start + 1, start + displayedCount do
		local c = cells[k]
		local b = cellOf(c.bag, c.i)
		local n = k - start - 1
		place(b, "TOPLEFT", f, "TOPLEFT", N.first[1] + (n % N.columns) * stepX,
			N.first[2] - math.floor(n / N.columns) * stepY)
		b:Show()
		if c.bag ~= BANK_CONTAINER then
			updateCell(b, c.bag, c.i)
		else
			B.AfterBankCell(b)
		end
	end
	B.UpdateTabs()
end

-- After BankFrameItemButton_Update: quality and frame of a bank cell (bag cells use
-- updateCell).
function B.AfterBankCell(b)
	if not b or b.isBag or not b.foreverCell then return end
	local _, _, _, quality = GetContainerItemInfo(BANK_CONTAINER, b:GetID())
	local link = GetContainerItemLink(BANK_CONTAINER, b:GetID())
	Tpl.QualityOutline(b, link and quality or nil)
	setCellFrame(b, link ~= nil)
	B.mark(b, link)
end

-- ------------------------------------------------------------ Pages

function B.UpdateTabs()
	for i, o in ipairs(B.tabs or {}) do
		Tpl.SetShown(o, (B.pages or 1) >= i)
		Tpl.SetShown(o.active, B.page == i)
	end
end

-- Page tabs (camelot BankPageTabTemplate) down the right side of the window.
local function tabs(f)
	local O = N.tab
	B.tabs = {}
	for i, icon in ipairs(ART.pages) do
		local o = CreateFrame("Button", "ForeverUIBankPageTab" .. i, f)
		o:SetWidth(O.side)
		o:SetHeight(O.side)
		if i == 1 then
			o:SetPoint("TOPLEFT", f, "TOPRIGHT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", B.tabs[i - 1], "BOTTOMLEFT", 0, O.gap)
		end
		local background = o:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(background, ART.tab, true)
		background:SetAllPoints(o)
		local image = o:CreateTexture(nil, "ARTWORK")
		image:SetWidth(O.icon)
		image:SetHeight(O.icon)
		image:SetPoint("CENTER", o, "CENTER", O.iconX, 0)
		image:SetTexCoord(O.crop, 1 - O.crop, O.crop, 1 - O.crop)
		image:SetTexture(icon)
		local active = o:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(active, ART.tabActive, true)
		active:SetAllPoints(o)
		active:Hide()
		local hover = o:CreateTexture(nil, "HIGHLIGHT")
		ForeverUI.SetAtlas(hover, ART.tabHover, true)
		hover:SetAllPoints(o)
		o.icon, o.active = image, active
		o:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(string.format(PAGE_NUMBER, i))
			GameTooltip:Show()
		end)
		o:SetScript("OnLeave", function() GameTooltip:Hide() end)
		o:SetScript("OnClick", function()
			PlaySound("igCharacterInfoTab")
			B.page = i
			B.Layout()
		end)
		o:Hide()
		B.tabs[i] = o
	end
end

-- ------------------------------------------------------------ Bags

-- After UpdateBagSlotStatus: lock icon on unpurchased bags, no red tint (camelot shows the
-- lock).
function B.AfterBags()
	local purchased = GetNumBankSlots()
	for i = 1, NUM_BANKBAGSLOTS do
		local b = _G["BankFrameBag" .. i]
		if b and b.foreverLock then
			SetItemButtonTextureVertexColor(b, 1, 1, 1)
			Tpl.SetShown(b.foreverLock, i > purchased)
		end
	end
end

-- camelot BankItemButtonBagMixin:OnClick: pick up or put the bag, without opening it. 3.3.5
-- has no C_Container.PickupContainerItem: put with PutItemInBag (as
-- BankFrameItemButtonBag_OnClick does), pick up with PickupBagFromSlot.
local function onBagClick(self)
	if self:GetID() - NUM_BAG_SLOTS > GetNumBankSlots() then return end
	local slot = self:GetInventorySlot()
	if CursorHasItem() then
		PutItemInBag(slot)
	else
		PickupBagFromSlot(slot)
	end
end

local function bags(f)
	local S = N.bags
	local text = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	text:SetText(string.format(L.BANK_COLON, BAGSLOTTEXT))
	text:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", S.text[1], S.text[2])
	B.bagsText = text
	for i = 1, NUM_BANKBAGSLOTS do
		local b = _G["BankFrameBag" .. i]
		b:SetScale(S.scale)
		if i == 1 then
			place(b, "TOPLEFT", text, "TOPRIGHT", S.first[1], S.first[2])
		else
			place(b, "TOPLEFT", _G["BankFrameBag" .. (i - 1)], "TOPLEFT", S.step, 0)
		end
		local background = b:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(background, ART.bagBackground)
		background:SetAllPoints(b)
		local e = ForeverUI.AtlasEntry(ART.fullCell)
		b:SetNormalTexture(e[1])
		local frame = b:GetNormalTexture()
		ForeverUI.SetAtlas(frame, ART.fullCell)
		frame:ClearAllPoints()
		frame:SetAllPoints(b)
		local lock = b:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(lock, ART.lock)
		lock:SetAllPoints(b)
		lock:Hide()
		b.foreverLock = lock
		b:SetScript("OnClick", onBagClick)
		-- Dropping a bag on it: same action (the client would open the bag when the cursor is empty).
		b:SetScript("OnReceiveDrag", onBagClick)
	end
	hooksecurefunc("UpdateBagSlotStatus", B.AfterBags)
end

-- After BankFrameItemButton_Update: an empty bag slot has no icon (the slot background shows).
local function afterButtonUpdate(b)
	if not b then return end
	if b.isBag then
		if not b.hasItem then _G[b:GetName() .. "IconTexture"]:Hide() end
	else
		B.AfterBankCell(b)
	end
end

-- ------------------------------------------------------------ Purchase, money, tools

-- Bag price and purchase button: the client's pieces, moved to camelot's places.
local function purchase(f)
	local C, A = N.cost, N.purchase
	for _, r in ipairs({ BankFramePurchaseInfo:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == BANKSLOTPURCHASE_LABEL then
			r:SetAlpha(0)
		end
	end
	place(BankFrameSlotCost, "BOTTOMLEFT", f, "BOTTOMLEFT", C[1], C[2])
	place(BankFrameDetailMoneyFrame, "TOPLEFT", BankFrameSlotCost, "TOPRIGHT", C[3], C[4])
	BankFramePurchaseButton:SetWidth(A[3])
	BankFramePurchaseButton:SetHeight(A[4])
	place(BankFramePurchaseButton, "TOPLEFT", BankFrameDetailMoneyFrame, "TOPRIGHT", A[1], A[2])
	-- Divider at camelot's scale, position included.
	local rule = f:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(rule, ART.rule, true)
	local e = ForeverUI.AtlasEntry(ART.rule)
	rule:SetWidth(e[6] * N.rule.scale)
	rule:SetHeight(e[7] * N.rule.scale)
	rule:SetPoint("BOTTOM", f, "BOTTOM", 0, N.rule.y * N.rule.scale)
	B.rule = rule
end

-- Money frame with the camelot gold border (BankPanelMoneyFrameTemplate, without transfers).
local function money(f)
	local A = N.money
	local box = CreateFrame("Frame", nil, f)
	box:EnableMouse(false)
	box:SetWidth(A.box[3])
	box:SetHeight(A.box[4])
	box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", A.box[1], A.box[2])
	local edge = CreateFrame("Frame", nil, box)
	edge:SetWidth(A.edge[1])
	edge:SetHeight(A.edge[2])
	edge:SetPoint("LEFT", box, "LEFT", 0, 0)
	local function piece(u1, u2, v1, v2)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ART.money)
		t:SetTexCoord(u1, u2, v1, v2)
		return t
	end
	local g = piece(0.953125, 0.9921875, 0, 0.296875)
	g:SetWidth(7)
	g:SetPoint("TOPLEFT", edge, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", edge, "BOTTOMLEFT")
	local d = piece(0, 0.0546875, 0, 0.296875)
	d:SetWidth(7)
	d:SetPoint("TOPRIGHT", edge, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT")
	local m = piece(0, 0.9921875, 0.3125, 0.609375)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	place(BankFrameMoneyFrame, "RIGHT", edge, "RIGHT", 0, 0)
	B.moneyBox, B.moneyBorder = box, edge
end

-- BankItemSearchBox (BagSearchBoxTemplate): the bags search field, rebuilt here, with the sort
-- button on its right.
local function tools(f)
	local R = N.search
	local field = CreateFrame("EditBox", "ForeverUIBankSearchBox", f, "InputBoxTemplate")
	field:SetWidth(R[3])
	field:SetHeight(R[4])
	field:SetAutoFocus(false)
	field:SetMaxLetters(15)
	field:SetTextInsets(16, 20, 0, 0)
	field:SetPoint("TOPRIGHT", f, "TOPRIGHT", R[1], R[2])
	local magnifier = field:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(magnifier, "common-search-magnifyingglass", true)
	magnifier:SetWidth(10)
	magnifier:SetHeight(10)
	magnifier:SetPoint("LEFT", field, "LEFT", 1, -1)
	local placeholder = field:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	placeholder:SetPoint("LEFT", field, "LEFT", 16, 0)
	placeholder:SetText(SEARCH)
	local function update()
		local text = field:GetText() or ""
		Tpl.SetShown(placeholder, text == "" and not field:HasFocus())
		for _, p in pairs(B.carriers) do
			for i, b in pairs(p.cells) do
				if b:IsShown() then B.mark(b, GetContainerItemLink(p:GetID(), i)) end
			end
		end
		for i = 1, NUM_BANKGENERIC_SLOTS do
			B.mark(_G["BankFrameItem" .. i], GetContainerItemLink(BANK_CONTAINER, i))
		end
	end
	field:SetScript("OnTextChanged", update)
	field:SetScript("OnEditFocusGained", update)
	field:SetScript("OnEditFocusLost", update)
	field:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	field:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	field:HookScript("OnHide", function(self) self:SetText("") end)
	B.field = field

	local T = N.sort
	local sort = CreateFrame("Button", "ForeverUIBankSortButton", f)
	sort:SetWidth(T[3])
	sort:SetHeight(T[4])
	sort:SetPoint("LEFT", field, "RIGHT", T[1], T[2])
	for _, v in ipairs({ { "SetNormalTexture", "GetNormalTexture", "bags-button-autosort-up" },
		{ "SetPushedTexture", "GetPushedTexture", "bags-button-autosort-down" } }) do
		local e = ForeverUI.AtlasEntry(v[3])
		if e then
			sort[v[1]](sort, e[1])
			local t = sort[v[2]](sort)
			ForeverUI.SetAtlas(t, v[3])
			t:ClearAllPoints()
			t:SetAllPoints(sort)
		end
	end
	sort:SetHighlightTexture("Interface" .. SEP .. "Buttons" .. SEP .. "ButtonHilight-Square")
	sort:GetHighlightTexture():SetBlendMode("ADD")
	sort:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.BAGS_CLEANUP, 1, 1, 1)
		GameTooltip:Show()
	end)
	sort:SetScript("OnLeave", function() GameTooltip:Hide() end)
	sort:SetScript("OnClick", function()
		ForeverUI.BagSort.Start(bankBags())
	end)
	B.sort = sort
end

-- ------------------------------------------------------------ Window

-- Bank bag events, while the window is open
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event, bag, slot)
	if not BankFrame or not BankFrame:IsShown() then return end
	if event == "BAG_UPDATE" and bag and bag > NUM_BAG_SLOTS then
		local p = B.carriers[bag]
		local n = GetContainerNumSlots(bag) or 0
		if not p or n ~= (p.count or 0) then
			if p then p.count = n end
			B.Layout()
		else
			for i, b in pairs(p.cells) do
				if b:IsShown() then updateCell(b, bag, i) end
			end
		end
	elseif event == "ITEM_LOCK_CHANGED" and bag and bag > NUM_BAG_SLOTS then
		local p = B.carriers[bag]
		local b = p and p.cells[slot]
		if b and b:IsShown() then updateCell(b, bag, slot) end
	elseif event == "PLAYERBANKBAGSLOTS_CHANGED" or event == "BAG_UPDATE_COOLDOWN" then
		B.Layout()
	end
end)
for _, e in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "BAG_UPDATE_COOLDOWN" }) do
	watcher:RegisterEvent(e)
end

function B.Skin()
	local f = BankFrame
	if not f or f.foreverSkin then return end
	-- 3.3.5 art: unnamed textures and texts, portrait, title
	for _, r in ipairs({ f:GetRegions() }) do
		if not r:GetName() then r:SetAlpha(0) end
	end
	BankPortraitTexture:SetAlpha(0)
	BankFrameTitleText:SetAlpha(0)
	f:SetWidth(N.width)
	f:SetHeight(N.baseHeight)
	f:SetHitRectInsets(0, 0, 0, 0)
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y, title = L.BANK_TITLE,
	})
	f.foreverSkin = skin
	-- Background, panel trim and shadows, on the same area
	local F = N.background
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", F[1], F[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", F[3], F[4])
	local background = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, ART.background)
	background:SetAllPoints(rect)
	skin.bankBackground, skin.panel = background, rect
	skin.trim = Tpl.NineSlice(f, "InsetFrameTemplate", rect)
	-- Shadows: corners at atlas size, edges 17 wide cut from a slice of their atlas (camelot
	-- TexCoords, relative to the atlas). Without a size, 3.3.5 draws a texture at its full sheet
	-- size.
	local O = N.shadows
	local corners = {}
	for key, v in pairs({ topLeft = { "TOPLEFT", "cornertopleft" }, bottomLeft = { "BOTTOMLEFT", "cornerbottomleft" },
		topRight = { "TOPRIGHT", "cornertopright" }, bottomRight = { "BOTTOMRIGHT", "cornerbottomright" } }) do
		local t = f:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, "bank-frame-shadow-" .. v[2])
		t:SetPoint(v[1], f, v[1], O[key][1], O[key][2])
		corners[key] = t
	end
	local function edge(atlas, slice, vertical, a1, c1, r1, a2, c2, r2)
		local t = f:CreateTexture(nil, "BORDER")
		local e = ForeverUI.AtlasEntry(atlas)
		t:SetTexture(e[1])
		local du, dv = e[3] - e[2], e[5] - e[4]
		if vertical then
			t:SetTexCoord(e[2] + du * slice[1], e[2] + du * slice[2], e[4], e[5])
			t:SetWidth(O.thickness)
		else
			t:SetTexCoord(e[2], e[3], e[4] + dv * slice[1], e[4] + dv * slice[2])
			t:SetHeight(O.thickness)
		end
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
		return t
	end
	local T = O.slices
	skin.shadows = {
		corners = corners,
		right = edge("!bank-frame-vert-shadow", T.side, true, "TOPRIGHT", corners.topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", corners.bottomRight, "TOPRIGHT"),
		left = edge("!bank-frame-vert-shadow", T.side, true, "TOPLEFT", corners.topLeft, "BOTTOMLEFT", "BOTTOMLEFT", corners.bottomLeft, "TOPLEFT"),
		down = edge("_bank-frame-horiz-shadow", T.down, false, "BOTTOMLEFT", corners.bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", corners.bottomRight, "BOTTOMLEFT"),
		top = edge("_bank-frame-horiz-shadow", T.top, false, "TOPLEFT", corners.topLeft, "TOPRIGHT", "TOPRIGHT", corners.topRight, "TOPLEFT"),
	}
	Tpl.CloseButton(BankCloseButton, f)
	BankCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	-- The 28 client cells, skinned
	for i = 1, NUM_BANKGENERIC_SLOTS do
		skinCell(_G["BankFrameItem" .. i])
	end
	bags(f)
	purchase(f)
	money(f)
	tools(f)
	tabs(f)
	hooksecurefunc("BankFrameItemButton_Update", afterButtonUpdate)
	f:HookScript("OnShow", function()
		SetPortraitTexture(skin.portrait, "npc")
		B.page = 1
		B.Layout()
	end)
end

B.Skin()
